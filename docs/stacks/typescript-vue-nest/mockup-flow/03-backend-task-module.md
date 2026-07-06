# 03 - Backend Task Module

Target: membuat task feature secara bertahap.

## Database

Edit `workspace-api/prisma/schema.prisma` dengan model minimal:

```prisma
model User {
  id        String @id
  email     String @unique
  name      String
  memberships OrganizationMember[]
}

model Organization {
  id      String @id
  name    String
  members OrganizationMember[]
  tasks   Task[]
}

model OrganizationMember {
  organizationId String
  userId String
  role String

  organization Organization @relation(fields: [organizationId], references: [id])
  user User @relation(fields: [userId], references: [id])

  @@id([organizationId, userId])
}

model Task {
  id String @id
  organizationId String
  title String
  description String?
  status String @default("todo")
  createdById String
  createdAt DateTime @default(now())

  organization Organization @relation(fields: [organizationId], references: [id])
}
```

## Domain

Buat `workspace-api/src/tasks/domain/task.entity.ts`.

```ts
export class TaskEntity {
  private constructor(
    public readonly id: string,
    public readonly organizationId: string,
    public readonly title: string,
    public readonly description: string | null,
    public readonly status: string,
    public readonly createdById: string
  ) {}

  static create(input: {
    id: string;
    organizationId: string;
    title: string;
    description?: string;
    createdById: string;
  }) {
    if (input.title.trim().length < 3) {
      throw new Error("Task title must be at least 3 characters.");
    }

    return new TaskEntity(
      input.id,
      input.organizationId,
      input.title.trim(),
      input.description?.trim() || null,
      "todo",
      input.createdById
    );
  }
}
```

Domain dibuat file baru karena ini aturan inti task.

## DTO

Buat `workspace-api/src/tasks/presentation/create-task.dto.ts`.

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

## Repository Contract

Buat `workspace-api/src/tasks/application/task.repository.ts`.

```ts
import { TaskEntity } from "../domain/task.entity";

export abstract class TaskRepository {
  abstract save(task: TaskEntity): Promise<void>;
  abstract listByOrganization(organizationId: string): Promise<unknown[]>;
}
```

Contract dibuat agar use case tidak bergantung langsung pada Prisma.

## Use Case

Buat `workspace-api/src/tasks/application/create-task.use-case.ts`.

```ts
import { ForbiddenException, Injectable } from "@nestjs/common";
import { randomUUID } from "crypto";
import { PrismaService } from "../../prisma.service";
import { TaskEntity } from "../domain/task.entity";
import { TaskRepository } from "./task.repository";

@Injectable()
export class CreateTaskUseCase {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tasks: TaskRepository
  ) {}

  async execute(input: {
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
      throw new ForbiddenException("Not a member.");
    }

    const task = TaskEntity.create({
      id: randomUUID(),
      organizationId: input.organizationId,
      title: input.title,
      description: input.description,
      createdById: input.currentUserId,
    });

    await this.tasks.save(task);
    return task;
  }
}
```

## Controller

Buat `workspace-api/src/tasks/presentation/tasks.controller.ts`.

```ts
import { Body, Controller, Get, Post } from "@nestjs/common";
import { CurrentUser, CurrentUserDto } from "../../auth/current-user";
import { TaskRepository } from "../application/task.repository";
import { CreateTaskUseCase } from "../application/create-task.use-case";
import { CreateTaskDto } from "./create-task.dto";

@Controller("/api/tasks")
export class TasksController {
  constructor(
    private readonly createTask: CreateTaskUseCase,
    private readonly tasks: TaskRepository
  ) {}

  @Get()
  list(@CurrentUser() user: CurrentUserDto) {
    return this.tasks.listByOrganization(user.organizationId);
  }

  @Post()
  create(@CurrentUser() user: CurrentUserDto, @Body() body: CreateTaskDto) {
    return this.createTask.execute({
      organizationId: user.organizationId,
      currentUserId: user.id,
      title: body.title,
      description: body.description,
    });
  }
}
```

Controller tidak berisi logic membership. Itu tugas use case.
