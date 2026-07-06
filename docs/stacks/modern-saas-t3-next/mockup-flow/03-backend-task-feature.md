# 03 - Backend Task Feature

Target file ini: database, seed, task module, API route, dan audit log.

## Prisma Schema

Edit `prisma/schema.prisma`.

```prisma
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
}
```

## Prisma Client

Buat `src/server/infra/db.ts`.

```ts
import { PrismaClient } from "@prisma/client";

export const db = new PrismaClient();
```

File baru karena Prisma adalah infrastructure.

## Task DTO

Buat `src/server/modules/tasks/task-dto.ts`.

```ts
export type TaskDto = {
  id: string;
  title: string;
  description: string | null;
  status: string;
  createdAt: string;
};
```

DTO dibuat terpisah agar output API stabil walau database berubah.

## Use Case

Buat `src/server/modules/tasks/create-task.use-case.ts`.

```ts
import { randomUUID } from "crypto";
import { db } from "@/server/infra/db";
import { ForbiddenError } from "@/server/shared/app-error";
import type { CurrentUser } from "@/server/shared/current-user";

export async function createTask(input: {
  currentUser: CurrentUser;
  title: string;
  description?: string;
}) {
  const membership = await db.organizationMember.findUnique({
    where: {
      organizationId_userId: {
        organizationId: input.currentUser.organizationId,
        userId: input.currentUser.id,
      },
    },
  });

  if (!membership) {
    throw new ForbiddenError("User is not a member of this organization.");
  }

  return db.task.create({
    data: {
      id: randomUUID(),
      organizationId: input.currentUser.organizationId,
      title: input.title.trim(),
      description: input.description?.trim() || null,
      createdById: input.currentUser.id,
    },
  });
}
```

Use case dibuat file baru karena ini workflow bisnis. Jangan taruh di API route.

## API Route

Buat `src/app/api/tasks/route.ts`.

```ts
import { NextResponse } from "next/server";
import { z } from "zod";
import { db } from "@/server/infra/db";
import { createTask } from "@/server/modules/tasks/create-task.use-case";
import { ok, fail } from "@/server/shared/api-response";
import { AppError } from "@/server/shared/app-error";

const schema = z.object({
  title: z.string().min(3),
  description: z.string().optional(),
});

function currentUser() {
  return {
    id: process.env.DEMO_USER_ID ?? "user_owner",
    organizationId: process.env.DEMO_ORGANIZATION_ID ?? "org_demo",
  };
}

export async function GET() {
  const user = currentUser();
  const tasks = await db.task.findMany({
    where: { organizationId: user.organizationId },
    orderBy: { createdAt: "desc" },
  });

  return NextResponse.json(ok(tasks));
}

export async function POST(request: Request) {
  try {
    const body = schema.parse(await request.json());
    const task = await createTask({ currentUser: currentUser(), ...body });
    return NextResponse.json(ok(task, 201), { status: 201 });
  } catch (error) {
    if (error instanceof AppError) {
      return NextResponse.json(fail(error, error.status), { status: error.status });
    }

    return NextResponse.json(
      fail({ code: "INTERNAL_ERROR", message: "Unexpected error" }, 500),
      { status: 500 }
    );
  }
}
```

API route hanya menerima request, validasi, memanggil use case, lalu mengubah response.

## Audit Log

Tambahkan setelah `db.task.create()` di use case atau buat helper `src/server/modules/tasks/write-task-audit.ts` jika audit mulai dipakai banyak action.

Untuk mockup awal, buat helper terpisah agar mudah dipakai ulang di `completeTask`.
