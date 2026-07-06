# 07 - Mockup Auth, Observability, AI, MCP, Redis, Kafka, Grafana

Dokumen ini adalah convention lintas stack untuk mockup yang tetap terlihat seperti project nyata. Semua stack boleh memakai versi sederhana dari pola ini, lalu mengganti implementasinya saat masuk production.

## Target Mockup

Setiap mockup full stack minimal punya:

- auth sederhana agar request punya `currentUserId`;
- audit log untuk mencatat action penting;
- monitoring endpoint untuk health check;
- Redis untuk cache/session/rate limit mock;
- Kafka atau Redpanda untuk event stream mock;
- Grafana untuk melihat dashboard lokal;
- AI adapter untuk ringkasan/rekomendasi task;
- MCP-style tool registry agar AI bisa memanggil tool aplikasi secara terstruktur.

## Docker Compose Lokal

Gunakan service lokal ini untuk semua stack. Simpan sebagai `docker-compose.yml` di root project mockup.

```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app
      POSTGRES_DB: task_workspace
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7
    ports:
      - "6379:6379"

  redpanda:
    image: redpandadata/redpanda:v24.1.7
    command:
      - redpanda
      - start
      - --overprovisioned
      - --smp
      - "1"
      - --memory
      - 512M
      - --reserve-memory
      - 0M
      - --node-id
      - "0"
      - --check=false
      - --kafka-addr
      - PLAINTEXT://0.0.0.0:9092
      - --advertise-kafka-addr
      - PLAINTEXT://localhost:9092
    ports:
      - "9092:9092"
      - "9644:9644"

  prometheus:
    image: prom/prometheus:v2.53.0
    ports:
      - "9090:9090"
    volumes:
      - ./ops/prometheus.yml:/etc/prometheus/prometheus.yml:ro

  grafana:
    image: grafana/grafana:11.1.0
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
    ports:
      - "3001:3000"
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  postgres_data:
  grafana_data:
```

Prometheus config minimal di `ops/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: app
    metrics_path: /metrics
    static_configs:
      - targets:
          - host.docker.internal:3000
          - host.docker.internal:8080
```

## Environment

Gunakan env ini sebagai baseline:

```env
DATABASE_URL=postgresql://app:app@localhost:5432/task_workspace
REDIS_URL=redis://localhost:6379
KAFKA_BROKERS=localhost:9092
AI_PROVIDER=mock
AI_API_KEY=
MCP_ENABLED=true
DEMO_USER_ID=user_owner
DEMO_ORGANIZATION_ID=org_demo
```

## Auth Mock

Auth mock tidak menggantikan auth production. Tujuannya hanya agar semua layer sudah terbiasa membaca user dari request.

```text
Request header
  x-demo-user-id: user_owner
  x-demo-organization-id: org_demo

Backend
  -> baca header
  -> fallback ke env DEMO_USER_ID
  -> attach currentUser ke request/context
  -> use case tetap cek membership/permission
```

Aturan:

- frontend boleh mengirim `x-demo-user-id` untuk mock;
- backend tetap membaca role dari database atau seed;
- frontend tidak boleh mengirim `role` atau `permissions` sebagai sumber kebenaran.

## Audit Log

Audit log mencatat kejadian bisnis, bukan semua log teknis.

Contoh event:

```json
{
  "id": "audit_01",
  "actorUserId": "user_owner",
  "organizationId": "org_demo",
  "action": "task.created",
  "entityType": "task",
  "entityId": "task_01",
  "metadata": {
    "title": "Belajar full stack"
  },
  "createdAt": "2026-07-06T00:00:00.000Z"
}
```

Simpan audit di database untuk halaman admin, lalu publish event ke Kafka/Redpanda untuk simulasi async processing.

## Redis

Redis mock dipakai untuk:

- cache list task per organization selama 30 detik;
- rate limit endpoint create task;
- menyimpan session token sederhana jika stack membutuhkan.

Key naming:

```text
task:list:{organizationId}
rate:create-task:{userId}
session:{token}
```

## Kafka / Redpanda

Topik minimal:

```text
audit.events
task.events
ai.events
```

Producer dipanggil setelah action berhasil:

```text
CreateTaskUseCase
  -> save task
  -> save audit log
  -> publish task.created
  -> invalidate Redis cache
```

Consumer boleh dibuat belakangan. Untuk mockup awal, cukup producer dan log console.

## Monitoring

Endpoint minimal:

```text
GET /health
GET /ready
GET /metrics
GET /api/audit-logs
```

Makna:

- `/health`: aplikasi hidup.
- `/ready`: database/Redis/Kafka bisa diakses atau statusnya degraded.
- `/metrics`: counter sederhana untuk Prometheus.
- `/api/audit-logs`: UI admin melihat aktivitas.

## AI Adapter

AI tidak boleh langsung dipanggil dari component frontend. Buat adapter di backend.

Interface:

```ts
export type AiTaskSummaryInput = {
  organizationId: string;
  tasks: Array<{
    title: string;
    status: string;
  }>;
};

export type AiTaskSummary = {
  summary: string;
  suggestions: string[];
};

export interface AiAssistant {
  summarizeTasks(input: AiTaskSummaryInput): Promise<AiTaskSummary>;
}
```

Mock implementation:

```ts
export class MockAiAssistant implements AiAssistant {
  async summarizeTasks(input: AiTaskSummaryInput): Promise<AiTaskSummary> {
    const total = input.tasks.length;
    const done = input.tasks.filter((task) => task.status === "done").length;

    return {
      summary: `Ada ${total} task, ${done} sudah selesai.`,
      suggestions: [
        "Prioritaskan task yang belum selesai.",
        "Tambahkan assignee untuk task yang penting.",
      ],
    };
  }
}
```

## MCP-Style Tool Registry

Untuk mockup, MCP cukup direpresentasikan sebagai daftar tool yang punya name, description, input schema, dan handler. Nanti registry ini bisa dipetakan ke MCP server sungguhan.

```ts
export type ToolDefinition<TInput, TOutput> = {
  name: string;
  description: string;
  inputSchema: unknown;
  handler(input: TInput): Promise<TOutput>;
};
```

Contoh tool:

```ts
export const listTasksTool = {
  name: "task.list",
  description: "List tasks for an organization.",
  inputSchema: {
    type: "object",
    properties: {
      organizationId: { type: "string" },
    },
    required: ["organizationId"],
  },
};
```

## Halaman Frontend Minimal

Frontend mockup minimal punya:

- login demo atau banner user aktif;
- dashboard task list;
- form create task;
- panel AI summary;
- audit log table;
- status service: API, Redis, Kafka;
- link Grafana `http://localhost:3001`.

## Checklist

- `docker compose up -d` menjalankan Postgres, Redis, Redpanda, Prometheus, Grafana.
- Backend bisa menjalankan `/health`, `/ready`, `/metrics`.
- Frontend bisa membuat task dan melihat list.
- Audit log tersimpan setelah create task.
- Redis cache tidak membuat data stale setelah create task.
- Kafka publish event tidak membuat request gagal jika broker mati.
- AI summary tetap berjalan dalam mode mock tanpa API key.
- MCP registry tersedia sebagai contract tool internal.
