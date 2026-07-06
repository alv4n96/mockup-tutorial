# 04 - Auth, Audit, Infra, Monitoring

Target: menambahkan bagian mockup yang membuat project terasa seperti sistem nyata.

## Prisma Service

Buat `workspace-api/src/prisma.service.ts`.

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

## Redis Service

Buat `workspace-api/src/infra/redis.service.ts`.

```ts
import { Injectable } from "@nestjs/common";
import Redis from "ioredis";

@Injectable()
export class RedisService {
  private readonly client = process.env.REDIS_URL ? new Redis(process.env.REDIS_URL) : null;

  async get<T>(key: string): Promise<T | null> {
    const value = await this.client?.get(key);
    return value ? (JSON.parse(value) as T) : null;
  }

  async set(key: string, value: unknown) {
    await this.client?.set(key, JSON.stringify(value), "EX", 30);
  }

  async del(key: string) {
    await this.client?.del(key);
  }
}
```

## Kafka Service

Buat `workspace-api/src/infra/kafka.service.ts`.

```ts
import { Injectable } from "@nestjs/common";
import { Kafka } from "kafkajs";

@Injectable()
export class KafkaService {
  async publish(topic: string, event: unknown) {
    const brokers = process.env.KAFKA_BROKERS?.split(",").filter(Boolean) ?? [];
    if (!brokers.length) return;

    const kafka = new Kafka({ clientId: "workspace-api", brokers });
    const producer = kafka.producer();

    try {
      await producer.connect();
      await producer.send({ topic, messages: [{ value: JSON.stringify(event) }] });
    } finally {
      await producer.disconnect().catch(() => undefined);
    }
  }
}
```

## Audit Service

Buat `workspace-api/src/audit/audit.service.ts`.

```ts
import { Injectable } from "@nestjs/common";
import { randomUUID } from "crypto";
import { KafkaService } from "../infra/kafka.service";

@Injectable()
export class AuditService {
  constructor(private readonly kafka: KafkaService) {}

  async write(input: {
    organizationId: string;
    actorUserId: string;
    action: string;
    entityType: string;
    entityId: string;
  }) {
    const audit = { id: randomUUID(), ...input, createdAt: new Date().toISOString() };
    await this.kafka.publish("audit.events", audit);
    return audit;
  }
}
```

Saat ingin menyimpan audit ke database, buat table `AuditLog` dan inject `PrismaService` ke file ini. Jangan tulis audit langsung di controller.

## AI Service

Buat `workspace-api/src/ai/ai.service.ts`.

```ts
import { Injectable } from "@nestjs/common";

@Injectable()
export class AiService {
  summarize(tasks: Array<{ title: string; status: string }>) {
    return {
      summary: `Ada ${tasks.length} task.`,
      suggestions: ["Kerjakan task todo yang paling kecil."],
    };
  }
}
```

## Ops Controller

Buat `workspace-api/src/ops.controller.ts`.

```ts
import { Controller, Get } from "@nestjs/common";

@Controller()
export class OpsController {
  @Get("/health")
  health() {
    return { status: "ok" };
  }

  @Get("/ready")
  ready() {
    return { status: "ok" };
  }

  @Get("/metrics")
  metrics() {
    return "app_mockup_info 1\n";
  }
}
```

## Kapan Function Ditambahkan Ke Mana

- publish event baru: tambahkan method di `KafkaService` hanya jika formatnya umum.
- audit action baru: panggil `AuditService.write()` dari use case.
- AI capability baru: method baru di `AiService`, endpoint baru di controller AI.
- monitoring check baru: tambahkan ke `OpsController.ready()`.
