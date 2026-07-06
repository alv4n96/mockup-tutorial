# 04 - Infra AI, Redis, Kafka, Monitoring

Target file ini: menambah adapter infrastructure tanpa mencampurnya ke UI.

## Redis Adapter

Buat `src/server/infra/redis.ts`.

```ts
import Redis from "ioredis";

export const redis = process.env.REDIS_URL ? new Redis(process.env.REDIS_URL) : null;

export async function cacheGet<T>(key: string): Promise<T | null> {
  const value = await redis?.get(key);
  return value ? (JSON.parse(value) as T) : null;
}

export async function cacheSet(key: string, value: unknown, seconds = 30) {
  await redis?.set(key, JSON.stringify(value), "EX", seconds);
}

export async function cacheDelete(key: string) {
  await redis?.del(key);
}
```

Adapter baru karena Redis adalah dependency eksternal.

## Kafka Adapter

Buat `src/server/infra/event-publisher.ts`.

```ts
import { Kafka } from "kafkajs";

const brokers = process.env.KAFKA_BROKERS?.split(",").filter(Boolean) ?? [];
const kafka = brokers.length ? new Kafka({ clientId: "next-mockup", brokers }) : null;

export async function publishEvent(topic: string, payload: unknown) {
  if (!kafka) return;

  const producer = kafka.producer();
  try {
    await producer.connect();
    await producer.send({
      topic,
      messages: [{ value: JSON.stringify(payload) }],
    });
  } finally {
    await producer.disconnect().catch(() => undefined);
  }
}
```

Use case boleh memanggil `publishEvent`, tapi UI tidak.

## AI Adapter

Buat `src/server/infra/ai-assistant.ts`.

```ts
export async function summarizeTasks(tasks: Array<{ title: string; status: string }>) {
  const total = tasks.length;
  const done = tasks.filter((task) => task.status === "done").length;

  return {
    summary: `Ada ${total} task. ${done} sudah selesai.`,
    suggestions: ["Kerjakan task kecil dulu.", "Tambahkan deskripsi pada task ambigu."],
  };
}
```

Ini Strategy sederhana: nanti isi fungsi bisa diganti provider AI sungguhan.

## MCP Tool Registry

Buat `src/server/infra/mcp-tools.ts`.

```ts
import { db } from "./db";

export const tools = [
  {
    name: "task.list",
    description: "List task by active organization.",
    inputSchema: {
      type: "object",
      properties: { organizationId: { type: "string" } },
      required: ["organizationId"],
    },
    handler(input: { organizationId: string }) {
      return db.task.findMany({ where: { organizationId: input.organizationId } });
    },
  },
];
```

## Monitoring Routes

Buat:

```text
src/app/api/health/route.ts
src/app/api/ready/route.ts
src/app/api/metrics/route.ts
```

`health`:

```ts
import { NextResponse } from "next/server";

export function GET() {
  return NextResponse.json({ status: "ok" });
}
```

`metrics`:

```ts
export function GET() {
  return new Response("app_mockup_info 1\n", {
    headers: { "Content-Type": "text/plain" },
  });
}
```

`ready` mengecek database dan Redis. Tambahkan check lain saat adapter baru dibuat.
