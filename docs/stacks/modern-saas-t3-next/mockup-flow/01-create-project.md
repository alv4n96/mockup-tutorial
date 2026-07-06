# 01 - Create Project

Target file ini: membuat project Next.js dan dependency dasar sampai siap dikoding.

## Command

```powershell
npx create-next-app@latest task-workspace-next --ts --tailwind --eslint --app --src-dir
cd task-workspace-next
npm install prisma @prisma/client zod ioredis kafkajs
npm install -D tsx
npx prisma init
```

## Docker

Buat `docker-compose.yml` di root project.

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

  grafana:
    image: grafana/grafana:11.1.0
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
    ports:
      - "3001:3000"
```

Jalankan:

```powershell
docker compose up -d
```

## Environment

Isi `.env`:

```env
DATABASE_URL="postgresql://app:app@localhost:5432/task_workspace"
REDIS_URL="redis://localhost:6379"
KAFKA_BROKERS="localhost:9092"
AI_PROVIDER="mock"
MCP_ENABLED="true"
DEMO_USER_ID="user_owner"
DEMO_ORGANIZATION_ID="org_demo"
```

## Folder Yang Dibuat

```text
src/
  app/
  server/
    shared/
    modules/
      tasks/
    infra/
```

Penjelasan:

- `app/` untuk page dan API route Next.js.
- `server/shared/` seperti SharedKernel: response, error, auth context, event contract.
- `server/modules/tasks/` untuk logic task.
- `server/infra/` untuk Prisma, Redis, Kafka, AI, MCP.

## Kenapa Begini

Next.js sering membuat backend dan frontend tercampur. Struktur ini menjaga Clean Code:

- API route tetap tipis;
- use case berada di `server/modules`;
- provider eksternal berada di `server/infra`;
- shared contract tidak dicampur dengan business logic.
