# 00 - Mockup Ready Full Stack Next.js

Dokumen ini adalah jalur cepat untuk membuat mockup SaaS task workspace yang sudah bisa jalan dari backend sampai frontend. Fokusnya bukan production perfect, tetapi project lokal yang lengkap: auth mock, task CRUD sederhana, audit log, monitoring endpoint, Redis cache, Kafka/Redpanda event, Grafana, AI summary mock, dan MCP-style tool registry.

## Hasil Akhir

```text
Next.js App Router
  -> API route /api/tasks
  -> Prisma + PostgreSQL
  -> Redis cache
  -> Redpanda Kafka event
  -> Audit log table
  -> AI summary endpoint
  -> MCP tool registry
  -> Dashboard React
```

URL lokal:

```text
App      http://localhost:3000
Grafana  http://localhost:3001
Redis    localhost:6379
Kafka    localhost:9092
Postgres localhost:5432
```

## 1. Buat Project

```powershell
npx create-next-app@latest task-workspace-next --ts --tailwind --eslint --app --src-dir
cd task-workspace-next
npm install prisma @prisma/client zod ioredis kafkajs
npm install -D tsx
npx prisma init
```

## 2. Docker Services

Buat `docker-compose.yml`:

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

Buat `ops/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: next-app
    metrics_path: /api/metrics
    static_configs:
      - targets:
          - host.docker.internal:3000
```

Jalankan:

```powershell
docker compose up -d
```

## 3. Environment

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

## 4. Database - `prisma/schema.prisma`

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id
  email     String   @unique
  name      String
  createdAt DateTime @default(now())

  memberships OrganizationMember[]
  tasksCreated Task[] @relation("TaskCreator")
}

model Organization {
  id        String   @id
  name      String
  createdAt DateTime @default(now())

  members   OrganizationMember[]
  tasks     Task[]
  auditLogs AuditLog[]
}

model OrganizationMember {
  organizationId String
  userId         String
  role           String
  createdAt      DateTime @default(now())

  organization Organization @relation(fields: [organizationId], references: [id])
  user         User         @relation(fields: [userId], references: [id])

  @@id([organizationId, userId])
}

model Task {
  id             String   @id
  organizationId String
  title          String
  description    String?
  status         String   @default("todo")
  createdById    String
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt

  organization Organization @relation(fields: [organizationId], references: [id])
  createdBy    User         @relation("TaskCreator", fields: [createdById], references: [id])

  @@index([organizationId])
}

model AuditLog {
  id             String   @id
  organizationId String
  actorUserId    String
  action         String
  entityType     String
  entityId       String
  metadata       Json?
  createdAt      DateTime @default(now())

  organization Organization @relation(fields: [organizationId], references: [id])

  @@index([organizationId, createdAt])
}
```

## 5. Seed - `prisma/seed.ts`

```ts
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  await prisma.user.upsert({
    where: { id: "user_owner" },
    update: {},
    create: {
      id: "user_owner",
      email: "owner@example.com",
      name: "Owner User",
    },
  });

  await prisma.organization.upsert({
    where: { id: "org_demo" },
    update: {},
    create: {
      id: "org_demo",
      name: "Demo Workspace",
    },
  });

  await prisma.organizationMember.upsert({
    where: {
      organizationId_userId: {
        organizationId: "org_demo",
        userId: "user_owner",
      },
    },
    update: { role: "owner" },
    create: {
      organizationId: "org_demo",
      userId: "user_owner",
      role: "owner",
    },
  });
}

main().finally(async () => prisma.$disconnect());
```

Jalankan:

```powershell
npx prisma migrate dev --name init_mockup
npx tsx prisma/seed.ts
```

## 6. Prisma Client - `src/server/db.ts`

```ts
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as {
  prisma?: PrismaClient;
};

export const db =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: ["error", "warn"],
  });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = db;
}
```

## 7. Auth Mock - `src/server/auth.ts`

```ts
import { headers } from "next/headers";

export type CurrentUser = {
  id: string;
  organizationId: string;
};

export async function getCurrentUser(): Promise<CurrentUser> {
  const requestHeaders = await headers();

  return {
    id: requestHeaders.get("x-demo-user-id") ?? process.env.DEMO_USER_ID ?? "user_owner",
    organizationId:
      requestHeaders.get("x-demo-organization-id") ??
      process.env.DEMO_ORGANIZATION_ID ??
      "org_demo",
  };
}
```

## 8. Redis - `src/server/redis.ts`

```ts
import Redis from "ioredis";

const redisUrl = process.env.REDIS_URL;

export const redis = redisUrl ? new Redis(redisUrl) : null;

export async function cacheGet<T>(key: string): Promise<T | null> {
  if (!redis) return null;
  const value = await redis.get(key);
  return value ? (JSON.parse(value) as T) : null;
}

export async function cacheSet(key: string, value: unknown, seconds = 30) {
  if (!redis) return;
  await redis.set(key, JSON.stringify(value), "EX", seconds);
}

export async function cacheDelete(key: string) {
  if (!redis) return;
  await redis.del(key);
}
```

## 9. Kafka - `src/server/kafka.ts`

```ts
import { Kafka } from "kafkajs";

const brokers = process.env.KAFKA_BROKERS?.split(",").filter(Boolean) ?? [];

const kafka = brokers.length
  ? new Kafka({ clientId: "task-workspace-next", brokers })
  : null;

export async function publishEvent(topic: string, event: unknown) {
  if (!kafka) return;

  const producer = kafka.producer();

  try {
    await producer.connect();
    await producer.send({
      topic,
      messages: [{ value: JSON.stringify(event) }],
    });
  } catch (error) {
    console.warn("Kafka publish skipped", error);
  } finally {
    await producer.disconnect().catch(() => undefined);
  }
}
```

## 10. Audit Log - `src/server/audit.ts`

```ts
import { randomUUID } from "crypto";
import { db } from "./db";
import { publishEvent } from "./kafka";

export async function writeAuditLog(input: {
  organizationId: string;
  actorUserId: string;
  action: string;
  entityType: string;
  entityId: string;
  metadata?: Record<string, unknown>;
}) {
  const audit = await db.auditLog.create({
    data: {
      id: randomUUID(),
      organizationId: input.organizationId,
      actorUserId: input.actorUserId,
      action: input.action,
      entityType: input.entityType,
      entityId: input.entityId,
      metadata: input.metadata ?? {},
    },
  });

  await publishEvent("audit.events", audit);

  return audit;
}
```

## 11. AI Adapter - `src/server/ai.ts`

```ts
export type AiTaskSummary = {
  summary: string;
  suggestions: string[];
};

export async function summarizeTasks(input: {
  tasks: Array<{ title: string; status: string }>;
}): Promise<AiTaskSummary> {
  const total = input.tasks.length;
  const done = input.tasks.filter((task) => task.status === "done").length;

  return {
    summary: `Ada ${total} task. ${done} task sudah selesai.`,
    suggestions: [
      "Kerjakan task todo yang paling kecil terlebih dahulu.",
      "Tambahkan deskripsi pada task yang masih ambigu.",
    ],
  };
}
```

## 12. MCP Tool Registry - `src/server/mcp-tools.ts`

```ts
import { db } from "./db";

export const mcpTools = [
  {
    name: "task.list",
    description: "List tasks for active organization.",
    inputSchema: {
      type: "object",
      properties: {
        organizationId: { type: "string" },
      },
      required: ["organizationId"],
    },
    async handler(input: { organizationId: string }) {
      return db.task.findMany({
        where: { organizationId: input.organizationId },
        orderBy: { createdAt: "desc" },
      });
    },
  },
];
```

## 13. Tasks API - `src/app/api/tasks/route.ts`

```ts
import { randomUUID } from "crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getCurrentUser } from "@/server/auth";
import { cacheDelete, cacheGet, cacheSet } from "@/server/redis";
import { db } from "@/server/db";
import { publishEvent } from "@/server/kafka";
import { writeAuditLog } from "@/server/audit";

const createTaskSchema = z.object({
  title: z.string().min(3),
  description: z.string().optional(),
});

export async function GET() {
  const user = await getCurrentUser();
  const cacheKey = `task:list:${user.organizationId}`;
  const cached = await cacheGet(cacheKey);

  if (cached) {
    return NextResponse.json({ data: cached, error: null, status: 200 });
  }

  const tasks = await db.task.findMany({
    where: { organizationId: user.organizationId },
    orderBy: { createdAt: "desc" },
  });

  await cacheSet(cacheKey, tasks);

  return NextResponse.json({ data: tasks, error: null, status: 200 });
}

export async function POST(request: Request) {
  const user = await getCurrentUser();
  const body = createTaskSchema.parse(await request.json());

  const membership = await db.organizationMember.findUnique({
    where: {
      organizationId_userId: {
        organizationId: user.organizationId,
        userId: user.id,
      },
    },
  });

  if (!membership) {
    return NextResponse.json(
      { data: null, error: { code: "FORBIDDEN", message: "Not a member." }, status: 403 },
      { status: 403 }
    );
  }

  const task = await db.task.create({
    data: {
      id: randomUUID(),
      organizationId: user.organizationId,
      title: body.title,
      description: body.description,
      createdById: user.id,
    },
  });

  await writeAuditLog({
    organizationId: user.organizationId,
    actorUserId: user.id,
    action: "task.created",
    entityType: "task",
    entityId: task.id,
    metadata: { title: task.title },
  });

  await publishEvent("task.events", { type: "task.created", taskId: task.id });
  await cacheDelete(`task:list:${user.organizationId}`);

  return NextResponse.json({ data: task, error: null, status: 201 }, { status: 201 });
}
```

## 14. AI API - `src/app/api/ai/task-summary/route.ts`

```ts
import { NextResponse } from "next/server";
import { getCurrentUser } from "@/server/auth";
import { db } from "@/server/db";
import { summarizeTasks } from "@/server/ai";

export async function GET() {
  const user = await getCurrentUser();
  const tasks = await db.task.findMany({
    where: { organizationId: user.organizationId },
    select: { title: true, status: true },
  });

  const summary = await summarizeTasks({ tasks });

  return NextResponse.json({ data: summary, error: null, status: 200 });
}
```

## 15. Audit API - `src/app/api/audit-logs/route.ts`

```ts
import { NextResponse } from "next/server";
import { getCurrentUser } from "@/server/auth";
import { db } from "@/server/db";

export async function GET() {
  const user = await getCurrentUser();
  const logs = await db.auditLog.findMany({
    where: { organizationId: user.organizationId },
    orderBy: { createdAt: "desc" },
    take: 20,
  });

  return NextResponse.json({ data: logs, error: null, status: 200 });
}
```

## 16. Health, Ready, Metrics

Buat `src/app/api/health/route.ts`:

```ts
import { NextResponse } from "next/server";

export function GET() {
  return NextResponse.json({ status: "ok" });
}
```

Buat `src/app/api/ready/route.ts`:

```ts
import { NextResponse } from "next/server";
import { db } from "@/server/db";
import { redis } from "@/server/redis";

export async function GET() {
  const checks: Record<string, string> = {};

  try {
    await db.$queryRaw`select 1`;
    checks.database = "ok";
  } catch {
    checks.database = "down";
  }

  try {
    checks.redis = redis ? await redis.ping() : "disabled";
  } catch {
    checks.redis = "down";
  }

  return NextResponse.json({ status: "ok", checks });
}
```

Buat `src/app/api/metrics/route.ts`:

```ts
export function GET() {
  return new Response("app_mockup_info 1\n", {
    headers: { "Content-Type": "text/plain" },
  });
}
```

## 17. Frontend - `src/app/page.tsx`

```tsx
import { TasksClient } from "./tasks-client";

export default function Page() {
  return <TasksClient />;
}
```

## 18. Frontend - `src/app/tasks-client.tsx`

```tsx
"use client";

import { useEffect, useState } from "react";

type Task = {
  id: string;
  title: string;
  description: string | null;
  status: string;
};

type AuditLog = {
  id: string;
  action: string;
  entityType: string;
  entityId: string;
  createdAt: string;
};

export function TasksClient() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [summary, setSummary] = useState("");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");

  async function load() {
    const [tasksResponse, logsResponse, aiResponse] = await Promise.all([
      fetch("/api/tasks").then((res) => res.json()),
      fetch("/api/audit-logs").then((res) => res.json()),
      fetch("/api/ai/task-summary").then((res) => res.json()),
    ]);

    setTasks(tasksResponse.data ?? []);
    setLogs(logsResponse.data ?? []);
    setSummary(aiResponse.data?.summary ?? "");
  }

  async function createTask(event: React.FormEvent) {
    event.preventDefault();

    await fetch("/api/tasks", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title, description }),
    });

    setTitle("");
    setDescription("");
    await load();
  }

  useEffect(() => {
    void load();
  }, []);

  return (
    <main className="mx-auto grid min-h-screen max-w-5xl gap-6 p-8">
      <header>
        <p className="text-sm font-semibold uppercase text-teal-700">Mockup SaaS</p>
        <h1 className="text-3xl font-bold">Task Workspace</h1>
        <p className="text-gray-600">
          Auth mock, audit log, Redis, Kafka, AI summary, MCP registry, Grafana.
        </p>
      </header>

      <section className="rounded border bg-white p-4">
        <h2 className="font-semibold">Create Task</h2>
        <form className="mt-3 grid gap-3" onSubmit={createTask}>
          <input
            className="rounded border p-2"
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            placeholder="Task title"
          />
          <textarea
            className="rounded border p-2"
            value={description}
            onChange={(event) => setDescription(event.target.value)}
            placeholder="Description"
          />
          <button className="w-fit rounded bg-teal-700 px-4 py-2 text-white">
            Save
          </button>
        </form>
      </section>

      <section className="rounded border bg-white p-4">
        <h2 className="font-semibold">AI Summary</h2>
        <p className="mt-2 text-gray-700">{summary || "No summary yet."}</p>
      </section>

      <section className="rounded border bg-white p-4">
        <h2 className="font-semibold">Tasks</h2>
        <ul className="mt-3 grid gap-2">
          {tasks.map((task) => (
            <li key={task.id} className="rounded border p-3">
              <strong>{task.title}</strong>
              <span className="ml-2 text-sm text-gray-500">{task.status}</span>
              {task.description ? <p>{task.description}</p> : null}
            </li>
          ))}
        </ul>
      </section>

      <section className="rounded border bg-white p-4">
        <h2 className="font-semibold">Audit Logs</h2>
        <ul className="mt-3 grid gap-2 text-sm">
          {logs.map((log) => (
            <li key={log.id}>
              {log.action} - {log.entityType}/{log.entityId}
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
```

## 19. Run

```powershell
docker compose up -d
npx prisma migrate dev --name init_mockup
npx tsx prisma/seed.ts
npm run dev
```

Checklist:

- buka `http://localhost:3000`;
- buat task baru;
- task muncul di list;
- audit log bertambah;
- buka `http://localhost:3000/api/ready`;
- buka Grafana `http://localhost:3001` dengan `admin/admin`.

## 20. Naik Level Setelah Mockup

Setelah mockup jalan:

- ganti auth mock menjadi Auth.js atau provider internal;
- tambah role/permission dari [../../shared/06-rbac-tenant-authorization.md](../../shared/06-rbac-tenant-authorization.md);
- ubah AI mock menjadi provider sungguhan di `src/server/ai.ts`;
- ubah MCP registry menjadi MCP server ketika tool perlu dipakai agent eksternal;
- tambah dashboard Grafana dari metrics yang lebih detail.
