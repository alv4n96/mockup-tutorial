# Backend 07 - Code Blueprint NestJS: Task Module

## Yang Dibuat

Contoh module `tasks` lengkap dari controller sampai repository.

## Struktur File

```text
src/modules/tasks/
  tasks.module.ts
  presentation/tasks.controller.ts
  presentation/create-task.dto.ts
  application/create-task.use-case.ts
  application/task.repository.ts
  domain/task.entity.ts
  infrastructure/prisma-task.repository.ts
```

## DTO

```ts
import { IsOptional, IsString, MinLength } from "class-validator";

export class CreateTaskDto {
  @IsString()
  projectId!: string;

  @IsString()
  @MinLength(3)
  title!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  assigneeUserId?: string;
}
```

## Domain Entity

```ts
export type TaskStatus = "todo" | "in_progress" | "done";

export class TaskEntity {
  private constructor(
    public readonly id: string,
    public readonly organizationId: string,
    public readonly projectId: string,
    public readonly title: string,
    public readonly description: string | null,
    public readonly status: TaskStatus,
    public readonly assigneeUserId: string | null,
    public readonly createdAt: Date
  ) {}

  static create(input: {
    id: string;
    organizationId: string;
    projectId: string;
    title: string;
    description?: string;
    assigneeUserId?: string;
  }) {
    if (input.title.trim().length < 3) {
      throw new Error("Task title must be at least 3 characters.");
    }

    return new TaskEntity(
      input.id,
      input.organizationId,
      input.projectId,
      input.title.trim(),
      input.description?.trim() ?? null,
      "todo",
      input.assigneeUserId ?? null,
      new Date()
    );
  }
}
```

## Repository Contract

```ts
export type TaskDto = {
  id: string;
  organizationId: string;
  projectId: string;
  title: string;
  status: string;
  assigneeUserId: string | null;
  createdAt: string;
};

export interface TaskRepository {
  save(task: TaskEntity): Promise<void>;
  listByOrganization(organizationId: string): Promise<TaskDto[]>;
}
```

## Use Case

```ts
import { randomUUID } from "crypto";
import { Injectable } from "@nestjs/common";
import { ForbiddenAppError, ValidationAppError } from "@/shared/errors/app-error";
import { TaskEntity } from "../domain/task.entity";
import { TaskRepository } from "./task.repository";

export interface OrganizationAccessReader {
  isMember(organizationId: string, userId: string): Promise<boolean>;
}

@Injectable()
export class CreateTaskUseCase {
  constructor(
    private readonly tasks: TaskRepository,
    private readonly organizationAccess: OrganizationAccessReader
  ) {}

  async execute(input: {
    currentUserId: string;
    organizationId: string;
    projectId: string;
    title: string;
    description?: string;
    assigneeUserId?: string;
  }) {
    const isMember = await this.organizationAccess.isMember(
      input.organizationId,
      input.currentUserId
    );

    if (!isMember) {
      throw new ForbiddenAppError("You are not a member of this organization.");
    }

    if (input.assigneeUserId) {
      const assigneeIsMember = await this.organizationAccess.isMember(
        input.organizationId,
        input.assigneeUserId
      );

      if (!assigneeIsMember) {
        throw new ValidationAppError(
          "TASK_ASSIGNEE_NOT_MEMBER",
          "Assignee is not a member."
        );
      }
    }

    const task = TaskEntity.create({
      id: randomUUID(),
      organizationId: input.organizationId,
      projectId: input.projectId,
      title: input.title,
      description: input.description,
      assigneeUserId: input.assigneeUserId,
    });

    await this.tasks.save(task);

    return {
      id: task.id,
      organizationId: task.organizationId,
      projectId: task.projectId,
      title: task.title,
      status: task.status,
      assigneeUserId: task.assigneeUserId,
      createdAt: task.createdAt.toISOString(),
    };
  }
}
```

## Controller

```ts
@Controller("/api/organizations/:organizationId/tasks")
export class TasksController {
  constructor(private readonly createTask: CreateTaskUseCase) {}

  @Post()
  async create(
    @Param("organizationId") organizationId: string,
    @Body() body: CreateTaskDto,
    @CurrentUser() user: CurrentUserDto
  ) {
    return this.createTask.execute({
      currentUserId: user.id,
      organizationId,
      ...body,
    });
  }
}
```

## Output

Controller mengembalikan DTO biasa, interceptor membungkus response, dan use case tetap menjaga tenant rule.

## RBAC: Guard, Policy, Dan Use Case

NestJS tetap memakai guard untuk memastikan user sudah login. Permission tenant tetap dicek di use case, karena permission adalah aturan bisnis aplikasi.

```text
JwtAuthGuard
  -> @CurrentUser() user
  -> TasksController.create
  -> CreateTaskUseCase
  -> OrganizationAccessReader.getMembership
  -> TaskPolicy.require("task:create")
  -> TaskEntity.create
  -> PrismaTaskRepository.save
```

### Role Dan Permission

```ts
export type OrganizationRole = "owner" | "admin" | "member" | "viewer";

export type Permission =
  | "task:read"
  | "task:create"
  | "task:assign"
  | "task:update"
  | "task:delete";

const rolePermissions: Record<OrganizationRole, Permission[]> = {
  owner: ["task:read", "task:create", "task:assign", "task:update", "task:delete"],
  admin: ["task:read", "task:create", "task:assign", "task:update", "task:delete"],
  member: ["task:read", "task:create", "task:update"],
  viewer: ["task:read"],
};

export function roleCan(role: OrganizationRole, permission: Permission) {
  return rolePermissions[role].includes(permission);
}
```

### Organization Access Contract

```ts
export type OrganizationMembership = {
  organizationId: string;
  userId: string;
  role: OrganizationRole;
};

export interface OrganizationAccessReader {
  getMembership(input: {
    organizationId: string;
    userId: string;
  }): Promise<OrganizationMembership | null>;
}
```

### Prisma Implementation

```ts
@Injectable()
export class PrismaOrganizationAccessReader implements OrganizationAccessReader {
  constructor(private readonly prisma: PrismaService) {}

  async getMembership(input: {
    organizationId: string;
    userId: string;
  }): Promise<OrganizationMembership | null> {
    const membership = await this.prisma.organizationMember.findUnique({
      where: {
        organizationId_userId: {
          organizationId: input.organizationId,
          userId: input.userId,
        },
      },
      select: {
        organizationId: true,
        userId: true,
        role: true,
      },
    });

    if (!membership) return null;

    return {
      organizationId: membership.organizationId,
      userId: membership.userId,
      role: membership.role as OrganizationRole,
    };
  }
}
```

### Policy Helper

```ts
export class TaskPolicy {
  static require(input: {
    membership: OrganizationMembership | null;
    permission: Permission;
  }): OrganizationMembership {
    if (!input.membership) {
      throw new ForbiddenAppError("You are not a member of this organization.");
    }

    if (!roleCan(input.membership.role, input.permission)) {
      throw new ForbiddenAppError("You do not have permission for this action.");
    }

    return input.membership;
  }
}
```

### Use Case Dengan RBAC

```ts
@Injectable()
export class CreateTaskUseCase {
  constructor(
    private readonly tasks: TaskRepository,
    private readonly organizationAccess: OrganizationAccessReader
  ) {}

  async execute(input: {
    currentUserId: string;
    organizationId: string;
    projectId: string;
    title: string;
    description?: string;
    assigneeUserId?: string;
  }): Promise<TaskDto> {
    const membership = await this.organizationAccess.getMembership({
      organizationId: input.organizationId,
      userId: input.currentUserId,
    });

    TaskPolicy.require({ membership, permission: "task:create" });

    if (input.assigneeUserId && !roleCan(membership.role, "task:assign")) {
      throw new ForbiddenAppError("You cannot assign tasks.");
    }

    if (input.assigneeUserId) {
      const assigneeMembership = await this.organizationAccess.getMembership({
        organizationId: input.organizationId,
        userId: input.assigneeUserId,
      });

      if (!assigneeMembership) {
        throw new ValidationAppError(
          "TASK_ASSIGNEE_NOT_MEMBER",
          "Assignee is not a member."
        );
      }
    }

    const task = TaskEntity.create({
      id: randomUUID(),
      organizationId: input.organizationId,
      projectId: input.projectId,
      title: input.title,
      description: input.description,
      assigneeUserId: input.assigneeUserId,
    });

    await this.tasks.save(task);

    return {
      id: task.id,
      organizationId: task.organizationId,
      projectId: task.projectId,
      title: task.title,
      status: task.status,
      assigneeUserId: task.assigneeUserId,
      createdAt: task.createdAt.toISOString(),
    };
  }
}
```

### Controller Input

```ts
@UseGuards(JwtAuthGuard)
@Post()
async create(
  @Param("organizationId") organizationId: string,
  @Body() body: CreateTaskDto,
  @CurrentUser() user: CurrentUserDto
) {
  return this.createTask.execute({
    currentUserId: user.id,
    organizationId,
    projectId: body.projectId,
    title: body.title,
    description: body.description,
    assigneeUserId: body.assigneeUserId,
  });
}
```

Request dari frontend:

```json
{
  "projectId": "project_01",
  "title": "Implement RBAC NestJS",
  "description": "Policy dicek di use case",
  "assigneeUserId": "user_02"
}
```