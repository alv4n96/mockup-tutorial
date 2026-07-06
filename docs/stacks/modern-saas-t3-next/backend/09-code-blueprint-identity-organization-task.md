# Backend 09 - Code Blueprint: Identity, Organization, Task

## Yang Dibuat

Contoh bentuk kode module utama.

## Struktur File

```text
src/modules/tasks/
  domain/task.ts
  domain/task-status.ts
  domain/task-errors.ts
  application/create-task.ts
  application/list-tasks.ts
  application/assign-task.ts
  infrastructure/prisma-task-repository.ts
  presentation/task-router.ts
```

## Domain: `task-status.ts`

```ts
export const TaskStatus = {
  TODO: "todo",
  IN_PROGRESS: "in_progress",
  DONE: "done",
} as const;

export type TaskStatus = (typeof TaskStatus)[keyof typeof TaskStatus];

export function canMoveTaskStatus(from: TaskStatus, to: TaskStatus): boolean {
  if (from === to) return true;
  if (from === TaskStatus.TODO && to === TaskStatus.IN_PROGRESS) return true;
  if (from === TaskStatus.IN_PROGRESS && to === TaskStatus.DONE) return true;
  return false;
}
```

## Domain: `task.ts`

```ts
import { TaskStatus } from "./task-status";

export type TaskProps = {
  id: string;
  organizationId: string;
  projectId: string;
  title: string;
  description: string | null;
  status: TaskStatus;
  assigneeUserId: string | null;
  createdAt: Date;
  updatedAt: Date;
};

export class Task {
  private constructor(private readonly props: TaskProps) {}

  static rehydrate(props: TaskProps): Task {
    return new Task(props);
  }

  static create(input: {
    id: string;
    organizationId: string;
    projectId: string;
    title: string;
    description?: string;
    assigneeUserId?: string;
  }): Task {
    if (input.title.trim().length < 3) {
      throw new Error("Task title must be at least 3 characters.");
    }

    const now = new Date();

    return new Task({
      id: input.id,
      organizationId: input.organizationId,
      projectId: input.projectId,
      title: input.title.trim(),
      description: input.description?.trim() ?? null,
      status: TaskStatus.TODO,
      assigneeUserId: input.assigneeUserId ?? null,
      createdAt: now,
      updatedAt: now,
    });
  }

  toSnapshot(): TaskProps {
    return { ...this.props };
  }
}
```

## Application: `create-task.ts`

```ts
import { randomUUID } from "crypto";
import { failure, success, type Result } from "@/shared/result/result";
import { ForbiddenError } from "@/shared/errors/app-error";
import { Task } from "../domain/task";
import { TaskAssigneeNotMemberError } from "../domain/task-errors";

export type CreateTaskInput = {
  currentUserId: string;
  organizationId: string;
  projectId: string;
  title: string;
  description?: string;
  assigneeUserId?: string;
};

export type TaskDTO = {
  id: string;
  organizationId: string;
  projectId: string;
  title: string;
  description: string | null;
  status: string;
  assigneeUserId: string | null;
  createdAt: string;
};

export interface TaskRepository {
  save(task: Task): Promise<void>;
}

export interface OrganizationAccessReader {
  isMember(input: { organizationId: string; userId: string }): Promise<boolean>;
}

export class CreateTaskUseCase {
  constructor(
    private readonly tasks: TaskRepository,
    private readonly organizationAccess: OrganizationAccessReader
  ) {}

  async execute(input: CreateTaskInput): Promise<Result<TaskDTO>> {
    const currentUserIsMember = await this.organizationAccess.isMember({
      organizationId: input.organizationId,
      userId: input.currentUserId,
    });

    if (!currentUserIsMember) {
      return failure(new ForbiddenError("You are not a member of this organization."));
    }

    if (input.assigneeUserId) {
      const assigneeIsMember = await this.organizationAccess.isMember({
        organizationId: input.organizationId,
        userId: input.assigneeUserId,
      });

      if (!assigneeIsMember) {
        return failure(new TaskAssigneeNotMemberError());
      }
    }

    const task = Task.create({
      id: randomUUID(),
      organizationId: input.organizationId,
      projectId: input.projectId,
      title: input.title,
      description: input.description,
      assigneeUserId: input.assigneeUserId,
    });

    await this.tasks.save(task);

    const saved = task.toSnapshot();

    return success({
      id: saved.id,
      organizationId: saved.organizationId,
      projectId: saved.projectId,
      title: saved.title,
      description: saved.description,
      status: saved.status,
      assigneeUserId: saved.assigneeUserId,
      createdAt: saved.createdAt.toISOString(),
    });
  }
}
```

## Infrastructure: `prisma-task-repository.ts`

```ts
import type { PrismaClient } from "@prisma/client";
import type { TaskRepository } from "../application/create-task";
import { Task } from "../domain/task";

export class PrismaTaskRepository implements TaskRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async save(task: Task): Promise<void> {
    const data = task.toSnapshot();

    await this.prisma.task.create({
      data: {
        id: data.id,
        organizationId: data.organizationId,
        projectId: data.projectId,
        title: data.title,
        description: data.description,
        status: data.status,
        assigneeUserId: data.assigneeUserId,
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
      },
    });
  }
}
```

## Presentation: `task-router.ts`

```ts
import { z } from "zod";
import { createTRPCRouter, protectedProcedure } from "@/server/api/trpc";
import { toTRPCError } from "@/shared/errors/error-mapper";

const createTaskSchema = z.object({
  organizationId: z.string().min(1),
  projectId: z.string().min(1),
  title: z.string().min(3).max(120),
  description: z.string().max(2000).optional(),
  assigneeUserId: z.string().optional(),
});

export const taskRouter = createTRPCRouter({
  create: protectedProcedure
    .input(createTaskSchema)
    .mutation(async ({ ctx, input }) => {
      const result = await ctx.useCases.createTask.execute({
        currentUserId: ctx.user.id,
        ...input,
      });

      if (!result.ok) {
        throw toTRPCError(result.error);
      }

      return { data: result.value };
    }),
});
```

## Output

File ini menunjukkan pola lengkap dari:

```text
tRPC input -> use case -> domain -> repository -> DTO output
```

Ini modular monolith karena semua berjalan dalam satu app, tetapi setiap tanggung jawab tetap di layer yang benar.

## RBAC: Dari Request Sampai Repository

Bagian ini memperluas flow sebelumnya. Permission tidak dikirim dari frontend. Backend mengambil `currentUserId` dari session, membaca membership dari module `Organizations`, lalu mengecek permission sebelum membuat task.

```text
createTaskForm
  -> taskRouter.create protectedProcedure
  -> ctx.user.id dari session
  -> CreateTaskUseCase
  -> OrganizationAccessReader.getMembership
  -> OrganizationPolicy.requirePermission("task:create")
  -> jika ada assignee, cek "task:assign"
  -> Task.create
  -> PrismaTaskRepository.save
```

### `organization-role.ts`

```ts
export const OrganizationRole = {
  OWNER: "owner",
  ADMIN: "admin",
  MEMBER: "member",
  VIEWER: "viewer",
} as const;

export type OrganizationRole =
  (typeof OrganizationRole)[keyof typeof OrganizationRole];

export type Permission =
  | "task:read"
  | "task:create"
  | "task:assign"
  | "task:update"
  | "task:delete"
  | "member:invite"
  | "billing:manage";

const rolePermissions: Record<OrganizationRole, Permission[]> = {
  owner: [
    "task:read",
    "task:create",
    "task:assign",
    "task:update",
    "task:delete",
    "member:invite",
    "billing:manage",
  ],
  admin: [
    "task:read",
    "task:create",
    "task:assign",
    "task:update",
    "task:delete",
    "member:invite",
  ],
  member: ["task:read", "task:create", "task:update"],
  viewer: ["task:read"],
};

export function roleCan(role: OrganizationRole, permission: Permission): boolean {
  return rolePermissions[role].includes(permission);
}
```

### `organization-access-reader.ts`

```ts
import type { OrganizationRole } from "./organization-role";

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

### `organization-policy.ts`

```ts
import { ForbiddenError } from "@/shared/errors/app-error";
import { roleCan, type Permission } from "./organization-role";
import type { OrganizationMembership } from "./organization-access-reader";

export class OrganizationPolicy {
  static requirePermission(input: {
    membership: OrganizationMembership | null;
    permission: Permission;
  }): OrganizationMembership {
    if (!input.membership) {
      throw new ForbiddenError("You are not a member of this organization.");
    }

    if (!roleCan(input.membership.role, input.permission)) {
      throw new ForbiddenError("You do not have permission for this action.");
    }

    return input.membership;
  }
}
```

### Prisma Reader Di Module Organizations

```ts
import type { PrismaClient } from "@prisma/client";
import type {
  OrganizationAccessReader,
  OrganizationMembership,
} from "../application/organization-access-reader";
import type { OrganizationRole } from "../application/organization-role";

export class PrismaOrganizationAccessReader implements OrganizationAccessReader {
  constructor(private readonly prisma: PrismaClient) {}

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

### `create-task.ts` Dengan RBAC

```ts
export class CreateTaskUseCase {
  constructor(
    private readonly tasks: TaskRepository,
    private readonly organizationAccess: OrganizationAccessReader
  ) {}

  async execute(input: CreateTaskInput): Promise<Result<TaskDTO>> {
    const membership = await this.organizationAccess.getMembership({
      organizationId: input.organizationId,
      userId: input.currentUserId,
    });

    try {
      OrganizationPolicy.requirePermission({
        membership,
        permission: "task:create",
      });
    } catch (error) {
      return failure(error as ForbiddenError);
    }

    if (input.assigneeUserId && !roleCan(membership.role, "task:assign")) {
      return failure(new ForbiddenError("You cannot assign tasks."));
    }

    if (input.assigneeUserId) {
      const assigneeMembership = await this.organizationAccess.getMembership({
        organizationId: input.organizationId,
        userId: input.assigneeUserId,
      });

      if (!assigneeMembership) {
        return failure(new TaskAssigneeNotMemberError());
      }
    }

    const task = Task.create({
      id: randomUUID(),
      organizationId: input.organizationId,
      projectId: input.projectId,
      title: input.title,
      description: input.description,
      assigneeUserId: input.assigneeUserId,
    });

    await this.tasks.save(task);

    return success(toTaskDTO(task));
  }
}
```

### Input Dari Frontend

```ts
await api.task.create.mutateAsync({
  organizationId: "org_01",
  projectId: "project_01",
  title: "Membuat RBAC task module",
  description: "Tambahkan role owner, admin, member, viewer",
  assigneeUserId: "user_02",
});
```

Router tetap menambahkan `currentUserId` dari session:

```ts
const result = await ctx.useCases.createTask.execute({
  currentUserId: ctx.user.id,
  ...input,
});
```