# 00 - Mockup Ready Full Stack NestJS + Vue

Dokumen ini membuat mockup `Task Workspace` dengan backend NestJS dan frontend Vue. Satu file ini cukup untuk membuat project lokal yang bisa jalan: auth mock, API task, audit log, Redis cache, Kafka/Redpanda event, monitoring endpoint, AI summary mock, MCP-style tool registry, dan dashboard Vue.

## Hasil Akhir

```text
workspace-api/
  NestJS
  Prisma PostgreSQL
  Redis cache
  Kafka event publisher
  Audit log
  Health/ready/metrics
  AI mock
  MCP tool registry

workspace-web/
  Vue 3 + Vite
  Task form
  Task list
  AI summary panel
  Audit log panel
```

## 1. Buat Project

```powershell
mkdir task-workspace-vue-nest
cd task-workspace-vue-nest
npm i -g @nestjs/cli
nest new workspace-api
npm create vite@latest workspace-web -- --template vue-ts
```

## 2. Docker Services

Buat `docker-compose.yml` di root `task-workspace-vue-nest`:

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
  - job_name: nest-api
    metrics_path: /metrics
    static_configs:
      - targets:
          - host.docker.internal:3000
```

Jalankan:

```powershell
docker compose up -d
```

## 3. Backend Install

```powershell
cd workspace-api
npm install @nestjs/config @prisma/client class-transformer class-validator ioredis kafkajs
npm install -D prisma tsx
npx prisma init
```

Isi `workspace-api/.env`:

```env
DATABASE_URL="postgresql://app:app@localhost:5432/task_workspace"
REDIS_URL="redis://localhost:6379"
KAFKA_BROKERS="localhost:9092"
AI_PROVIDER="mock"
MCP_ENABLED="true"
DEMO_USER_ID="user_owner"
DEMO_ORGANIZATION_ID="org_demo"
```

## 4. Backend Database - `workspace-api/prisma/schema.prisma`

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

## 5. Backend Seed - `workspace-api/prisma/seed.ts`

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

## 6. Backend Prisma - `workspace-api/src/prisma.service.ts`

```ts
import { Injectable, OnModuleInit } from "@nestjs/common";
import { PrismaClient } from "@prisma/client";

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  async onModuleInit() {
    await this.$connect();
  }
}
```

## 7. Backend Auth Mock - `workspace-api/src/auth/current-user.ts`

```ts
import { createParamDecorator, ExecutionContext } from "@nestjs/common";

export type CurrentUserDto = {
  id: string;
  organizationId: string;
};

export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): CurrentUserDto => {
    const request = context.switchToHttp().getRequest();

    return {
      id: String(request.headers["x-demo-user-id"] ?? process.env.DEMO_USER_ID ?? "user_owner"),
      organizationId: String(
        request.headers["x-demo-organization-id"] ??
        process.env.DEMO_ORGANIZATION_ID ??
        "org_demo"
      ),
    };
  }
);
```

## 8. Backend Redis - `workspace-api/src/infra/redis.service.ts`

```ts
import { Injectable, OnModuleDestroy } from "@nestjs/common";
import Redis from "ioredis";

@Injectable()
export class RedisService implements OnModuleDestroy {
  private readonly client = process.env.REDIS_URL
    ? new Redis(process.env.REDIS_URL)
    : null;

  async get<T>(key: string): Promise<T | null> {
    const value = await this.client?.get(key);
    return value ? (JSON.parse(value) as T) : null;
  }

  async set(key: string, value: unknown, seconds = 30) {
    await this.client?.set(key, JSON.stringify(value), "EX", seconds);
  }

  async del(key: string) {
    await this.client?.del(key);
  }

  async ping() {
    return this.client ? this.client.ping() : "disabled";
  }

  async onModuleDestroy() {
    await this.client?.quit();
  }
}
```

## 9. Backend Kafka - `workspace-api/src/infra/kafka.service.ts`

```ts
import { Injectable } from "@nestjs/common";
import { Kafka } from "kafkajs";

@Injectable()
export class KafkaService {
  private readonly brokers = process.env.KAFKA_BROKERS?.split(",").filter(Boolean) ?? [];
  private readonly kafka = this.brokers.length
    ? new Kafka({ clientId: "workspace-api", brokers: this.brokers })
    : null;

  async publish(topic: string, event: unknown) {
    if (!this.kafka) return;

    const producer = this.kafka.producer();

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
}
```

## 10. Backend Audit - `workspace-api/src/audit/audit.service.ts`

```ts
import { Injectable } from "@nestjs/common";
import { randomUUID } from "crypto";
import { PrismaService } from "../prisma.service";
import { KafkaService } from "../infra/kafka.service";

@Injectable()
export class AuditService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly kafka: KafkaService
  ) {}

  async write(input: {
    organizationId: string;
    actorUserId: string;
    action: string;
    entityType: string;
    entityId: string;
    metadata?: Record<string, unknown>;
  }) {
    const audit = await this.prisma.auditLog.create({
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

    await this.kafka.publish("audit.events", audit);

    return audit;
  }
}
```

## 11. Backend AI - `workspace-api/src/ai/ai.service.ts`

```ts
import { Injectable } from "@nestjs/common";

@Injectable()
export class AiService {
  async summarizeTasks(input: {
    tasks: Array<{ title: string; status: string }>;
  }) {
    const total = input.tasks.length;
    const done = input.tasks.filter((task) => task.status === "done").length;

    return {
      summary: `Ada ${total} task. ${done} task sudah selesai.`,
      suggestions: [
        "Pilih satu task kecil untuk dikerjakan lebih dulu.",
        "Gunakan audit log untuk melihat aktivitas terbaru.",
      ],
    };
  }
}
```

## 12. Backend MCP - `workspace-api/src/ai/mcp-tools.ts`

```ts
import { PrismaService } from "../prisma.service";

export function createMcpTools(prisma: PrismaService) {
  return [
    {
      name: "task.list",
      description: "List tasks by organization.",
      inputSchema: {
        type: "object",
        properties: {
          organizationId: { type: "string" },
        },
        required: ["organizationId"],
      },
      handler(input: { organizationId: string }) {
        return prisma.task.findMany({
          where: { organizationId: input.organizationId },
          orderBy: { createdAt: "desc" },
        });
      },
    },
  ];
}
```

## 13. Backend DTO - `workspace-api/src/tasks/create-task.dto.ts`

```ts
import { IsOptional, IsString, MinLength } from "class-validator";

export class CreateTaskDto {
  @IsString()
  @MinLength(3)
  title!: string;

  @IsOptional()
  @IsString()
  description?: string;
}
```

## 14. Backend Tasks - `workspace-api/src/tasks/tasks.service.ts`

```ts
import { ForbiddenException, Injectable } from "@nestjs/common";
import { randomUUID } from "crypto";
import { PrismaService } from "../prisma.service";
import { RedisService } from "../infra/redis.service";
import { KafkaService } from "../infra/kafka.service";
import { AuditService } from "../audit/audit.service";

@Injectable()
export class TasksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly kafka: KafkaService,
    private readonly audit: AuditService
  ) {}

  async list(input: { organizationId: string }) {
    const cacheKey = `task:list:${input.organizationId}`;
    const cached = await this.redis.get(cacheKey);
    if (cached) return cached;

    const tasks = await this.prisma.task.findMany({
      where: { organizationId: input.organizationId },
      orderBy: { createdAt: "desc" },
    });

    await this.redis.set(cacheKey, tasks);
    return tasks;
  }

  async create(input: {
    organizationId: string;
    currentUserId: string;
    title: string;
    description?: string;
  }) {
    const membership = await this.prisma.organizationMember.findUnique({
      where: {
        organizationId_userId: {
          organizationId: input.organizationId,
          userId: input.currentUserId,
        },
      },
    });

    if (!membership) {
      throw new ForbiddenException("You are not a member of this organization.");
    }

    const task = await this.prisma.task.create({
      data: {
        id: randomUUID(),
        organizationId: input.organizationId,
        title: input.title,
        description: input.description,
        createdById: input.currentUserId,
      },
    });

    await this.audit.write({
      organizationId: input.organizationId,
      actorUserId: input.currentUserId,
      action: "task.created",
      entityType: "task",
      entityId: task.id,
      metadata: { title: task.title },
    });

    await this.kafka.publish("task.events", { type: "task.created", taskId: task.id });
    await this.redis.del(`task:list:${input.organizationId}`);

    return task;
  }
}
```

## 15. Backend Controller - `workspace-api/src/tasks/tasks.controller.ts`

```ts
import { Body, Controller, Get, Post } from "@nestjs/common";
import { CurrentUser, CurrentUserDto } from "../auth/current-user";
import { AiService } from "../ai/ai.service";
import { PrismaService } from "../prisma.service";
import { CreateTaskDto } from "./create-task.dto";
import { TasksService } from "./tasks.service";

@Controller()
export class TasksController {
  constructor(
    private readonly tasks: TasksService,
    private readonly ai: AiService,
    private readonly prisma: PrismaService
  ) {}

  @Get("/api/tasks")
  async list(@CurrentUser() user: CurrentUserDto) {
    return this.tasks.list({ organizationId: user.organizationId });
  }

  @Post("/api/tasks")
  async create(@CurrentUser() user: CurrentUserDto, @Body() body: CreateTaskDto) {
    return this.tasks.create({
      organizationId: user.organizationId,
      currentUserId: user.id,
      title: body.title,
      description: body.description,
    });
  }

  @Get("/api/audit-logs")
  async auditLogs(@CurrentUser() user: CurrentUserDto) {
    return this.prisma.auditLog.findMany({
      where: { organizationId: user.organizationId },
      orderBy: { createdAt: "desc" },
      take: 20,
    });
  }

  @Get("/api/ai/task-summary")
  async summary(@CurrentUser() user: CurrentUserDto) {
    const tasks = await this.prisma.task.findMany({
      where: { organizationId: user.organizationId },
      select: { title: true, status: true },
    });

    return this.ai.summarizeTasks({ tasks });
  }
}
```

## 16. Backend Ops - `workspace-api/src/ops.controller.ts`

```ts
import { Controller, Get } from "@nestjs/common";
import { PrismaService } from "./prisma.service";
import { RedisService } from "./infra/redis.service";

@Controller()
export class OpsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService
  ) {}

  @Get("/health")
  health() {
    return { status: "ok" };
  }

  @Get("/ready")
  async ready() {
    const checks: Record<string, string> = {};

    try {
      await this.prisma.$queryRaw`select 1`;
      checks.database = "ok";
    } catch {
      checks.database = "down";
    }

    try {
      checks.redis = await this.redis.ping();
    } catch {
      checks.redis = "down";
    }

    return { status: "ok", checks };
  }

  @Get("/metrics")
  metrics() {
    return "app_mockup_info 1\n";
  }
}
```

## 17. Backend Module - `workspace-api/src/app.module.ts`

```ts
import { Module } from "@nestjs/common";
import { AuditService } from "./audit/audit.service";
import { AiService } from "./ai/ai.service";
import { KafkaService } from "./infra/kafka.service";
import { RedisService } from "./infra/redis.service";
import { OpsController } from "./ops.controller";
import { PrismaService } from "./prisma.service";
import { TasksController } from "./tasks/tasks.controller";
import { TasksService } from "./tasks/tasks.service";

@Module({
  controllers: [TasksController, OpsController],
  providers: [
    PrismaService,
    RedisService,
    KafkaService,
    AuditService,
    AiService,
    TasksService,
  ],
})
export class AppModule {}
```

## 18. Backend Main - `workspace-api/src/main.ts`

```ts
import { ValidationPipe } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.enableCors({ origin: "http://localhost:5173" });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  await app.listen(3000);
}

bootstrap();
```

Run backend:

```powershell
npm run start:dev
```

## 19. Frontend Install

```powershell
cd ..\workspace-web
npm install
```

Buat `workspace-web/.env`:

```env
VITE_API_BASE_URL=http://localhost:3000
```

## 20. Frontend API - `workspace-web/src/api.ts`

```ts
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000";

const headers = {
  "Content-Type": "application/json",
  "x-demo-user-id": "user_owner",
  "x-demo-organization-id": "org_demo",
};

export type Task = {
  id: string;
  title: string;
  description: string | null;
  status: string;
};

export type AuditLog = {
  id: string;
  action: string;
  entityType: string;
  entityId: string;
  createdAt: string;
};

export async function listTasks(): Promise<Task[]> {
  return fetch(`${API_BASE_URL}/api/tasks`, { headers }).then((res) => res.json());
}

export async function createTask(input: { title: string; description?: string }) {
  return fetch(`${API_BASE_URL}/api/tasks`, {
    method: "POST",
    headers,
    body: JSON.stringify(input),
  }).then((res) => res.json());
}

export async function getAuditLogs(): Promise<AuditLog[]> {
  return fetch(`${API_BASE_URL}/api/audit-logs`, { headers }).then((res) => res.json());
}

export async function getAiSummary(): Promise<{ summary: string; suggestions: string[] }> {
  return fetch(`${API_BASE_URL}/api/ai/task-summary`, { headers }).then((res) =>
    res.json()
  );
}
```

## 21. Frontend App - `workspace-web/src/App.vue`

```vue
<script setup lang="ts">
import { onMounted, ref } from "vue";
import {
  createTask,
  getAiSummary,
  getAuditLogs,
  listTasks,
  type AuditLog,
  type Task,
} from "./api";

const tasks = ref<Task[]>([]);
const logs = ref<AuditLog[]>([]);
const summary = ref("");
const title = ref("");
const description = ref("");
const loading = ref(false);

async function load() {
  loading.value = true;
  const [taskData, logData, summaryData] = await Promise.all([
    listTasks(),
    getAuditLogs(),
    getAiSummary(),
  ]);

  tasks.value = taskData;
  logs.value = logData;
  summary.value = summaryData.summary;
  loading.value = false;
}

async function submit() {
  await createTask({ title: title.value, description: description.value });
  title.value = "";
  description.value = "";
  await load();
}

onMounted(load);
</script>

<template>
  <main class="page">
    <header>
      <p class="eyebrow">NestJS + Vue Mockup</p>
      <h1>Task Workspace</h1>
      <p>Auth mock, audit log, Redis, Kafka, AI, MCP, Grafana.</p>
    </header>

    <form class="panel" @submit.prevent="submit">
      <h2>Create Task</h2>
      <input v-model="title" placeholder="Task title" />
      <textarea v-model="description" placeholder="Description" />
      <button :disabled="loading">{{ loading ? "Saving..." : "Save" }}</button>
    </form>

    <section class="panel">
      <h2>AI Summary</h2>
      <p>{{ summary || "No summary yet." }}</p>
    </section>

    <section class="panel">
      <h2>Tasks</h2>
      <ul>
        <li v-for="task in tasks" :key="task.id">
          <strong>{{ task.title }}</strong>
          <span>{{ task.status }}</span>
          <p v-if="task.description">{{ task.description }}</p>
        </li>
      </ul>
    </section>

    <section class="panel">
      <h2>Audit Logs</h2>
      <ul>
        <li v-for="log in logs" :key="log.id">
          {{ log.action }} - {{ log.entityType }}/{{ log.entityId }}
        </li>
      </ul>
    </section>
  </main>
</template>
```

## 22. Frontend Style - `workspace-web/src/style.css`

```css
:root {
  font-family: Arial, sans-serif;
  color: #182321;
  background: #f4f7f6;
}

body {
  margin: 0;
}

.page {
  width: min(920px, calc(100% - 32px));
  margin: 40px auto;
}

.eyebrow {
  color: #2f6f73;
  font-weight: 700;
  text-transform: uppercase;
}

.panel {
  display: grid;
  gap: 12px;
  margin-top: 18px;
  padding: 16px;
  background: white;
  border: 1px solid #d8e2df;
  border-radius: 8px;
}

input,
textarea,
button {
  font: inherit;
}

input,
textarea {
  padding: 10px;
  border: 1px solid #b8c7c2;
  border-radius: 6px;
}

button {
  width: fit-content;
  padding: 10px 14px;
  color: white;
  background: #2f6f73;
  border: 0;
  border-radius: 6px;
}

li {
  margin-bottom: 10px;
}

span {
  margin-left: 8px;
  color: #5d6b67;
  font-size: 13px;
}
```

## 23. Run Semua

Terminal root:

```powershell
docker compose up -d
```

Terminal backend:

```powershell
cd workspace-api
npx prisma migrate dev --name init_mockup
npx tsx prisma/seed.ts
npm run start:dev
```

Terminal frontend:

```powershell
cd workspace-web
npm run dev
```

Cek:

```text
Frontend http://localhost:5173
Backend  http://localhost:3000/health
Ready    http://localhost:3000/ready
Metrics  http://localhost:3000/metrics
Grafana  http://localhost:3001
```

## 24. Checklist

- Vue bisa create task.
- Nest menyimpan task ke PostgreSQL.
- Audit log bertambah setelah task dibuat.
- Redis cache list task dihapus setelah create.
- Kafka publish event tidak memutus request jika broker belum siap.
- AI summary tetap berjalan dengan provider mock.
- MCP tool registry tersedia di backend sebagai contract.
- Grafana lokal bisa dibuka dengan `admin/admin`.
