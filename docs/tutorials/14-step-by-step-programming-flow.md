# 14 - Step By Step Programming Flow Dari Database Sampai Frontend

Dokumen ini adalah jalur praktik untuk pemula. Tujuannya bukan hanya menjelaskan konsep, tetapi menunjukkan urutan file yang dibuat, command yang diketik, dan contoh kode minimal yang bisa dipindahkan ke project.

Contoh fitur yang dibuat: `Create Task` dengan tenant `Organization` dan RBAC.

Flow besar:

```text
Database
  -> ORM model / migration
  -> shared API response dan error
  -> RBAC role dan permission
  -> domain entity Task
  -> repository contract
  -> repository database
  -> use case CreateTask
  -> controller/router
  -> frontend API client
  -> frontend state/composable/hook
  -> form input
  -> list/detail UI
```

## 0. Pilih Stack

Pilih salah satu stack. Contoh command di dokumen ini memakai TypeScript karena paling mudah dibaca lintas stack.

Untuk Next.js/T3:

```powershell
npm create t3-app@latest saas-workspace
cd saas-workspace
npm install
npm run dev
```

Untuk NestJS + Vue:

```powershell
npm i -g @nestjs/cli
nest new workspace-api
cd workspace-api
npm run start:dev
```

Frontend Vue:

```powershell
npm create vite@latest workspace-web -- --template vue-ts
cd workspace-web
npm install
npm run dev
```

Untuk .NET:

```powershell
dotnet new sln -n EnterpriseWorkspace
dotnet new webapi -n EnterpriseWorkspace.Api
dotnet build
```

## 1. Buat Database Dari Belakang

Mulai dari tabel yang dibutuhkan. Fitur task butuh user, organization, membership, project, dan task.

SQL minimal:

```sql
create table users (
  id uuid primary key,
  email text not null unique,
  name text not null,
  created_at timestamptz not null default now()
);

create table organizations (
  id uuid primary key,
  name text not null,
  created_at timestamptz not null default now()
);

create table organization_members (
  organization_id uuid not null references organizations(id),
  user_id uuid not null references users(id),
  role text not null check (role in ('owner', 'admin', 'member', 'viewer')),
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

create table projects (
  id uuid primary key,
  organization_id uuid not null references organizations(id),
  name text not null,
  created_at timestamptz not null default now()
);

create table tasks (
  id uuid primary key,
  organization_id uuid not null references organizations(id),
  project_id uuid not null references projects(id),
  title text not null,
  description text,
  status text not null check (status in ('todo', 'in_progress', 'done')),
  assignee_user_id uuid references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_tasks_organization_id on tasks(organization_id);
create index idx_tasks_project_id on tasks(project_id);
create index idx_tasks_assignee_user_id on tasks(assignee_user_id);
```

Jika memakai Prisma, buat model seperti ini di `prisma/schema.prisma`:

```prisma
model User {
  id        String   @id @default(uuid())
  email     String   @unique
  name      String
  createdAt DateTime @default(now())

  memberships OrganizationMember[]
  assignedTasks Task[]
}

model Organization {
  id        String   @id @default(uuid())
  name      String
  createdAt DateTime @default(now())

  members OrganizationMember[]
  projects Project[]
  tasks    Task[]
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

model Project {
  id             String   @id @default(uuid())
  organizationId String
  name           String
  createdAt      DateTime @default(now())

  organization Organization @relation(fields: [organizationId], references: [id])
  tasks        Task[]
}

model Task {
  id             String   @id @default(uuid())
  organizationId String
  projectId      String
  title          String
  description    String?
  status         String
  assigneeUserId String?
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt

  organization Organization @relation(fields: [organizationId], references: [id])
  project      Project      @relation(fields: [projectId], references: [id])
  assignee     User?        @relation(fields: [assigneeUserId], references: [id])

  @@index([organizationId])
  @@index([projectId])
  @@index([assigneeUserId])
}
```

Jalankan migration:

```powershell
npx prisma migrate dev --name init_task_workspace
npx prisma generate
```

## 2. Buat Seed Data Untuk Belajar

Buat `prisma/seed.ts`:

```ts
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const user = await prisma.user.upsert({
    where: { email: "owner@example.com" },
    update: {},
    create: {
      email: "owner@example.com",
      name: "Owner User",
    },
  });

  const organization = await prisma.organization.create({
    data: { name: "Acme Workspace" },
  });

  await prisma.organizationMember.create({
    data: {
      organizationId: organization.id,
      userId: user.id,
      role: "owner",
    },
  });

  await prisma.project.create({
    data: {
      organizationId: organization.id,
      name: "Learning Project",
    },
  });
}

main()
  .finally(async () => {
    await prisma.$disconnect();
  });
```

Jalankan seed:

```powershell
npx tsx prisma/seed.ts
```

## 3. Buat Shared Response Dan Error

Buat file `src/shared/api/api-response.ts`:

```ts
export type ApiError = {
  code: string;
  message: string;
  details?: unknown;
};

export type ApiResponse<T> = {
  data: T | null;
  error: ApiError | null;
  status: number;
};

export function ok<T>(data: T, status = 200): ApiResponse<T> {
  return { data, error: null, status };
}

export function fail(error: ApiError, status: number): ApiResponse<null> {
  return { data: null, error, status };
}
```

Buat file `src/shared/errors/app-error.ts`:

```ts
export class AppError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly status: number,
    public readonly details?: unknown
  ) {
    super(message);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = "Forbidden") {
    super("FORBIDDEN", message, 403);
  }
}

export class ValidationError extends AppError {
  constructor(code: string, message: string, details?: unknown) {
    super(code, message, 400, details);
  }
}
```

## 4. Buat RBAC Role Dan Permission

Buat file `src/modules/organizations/application/organization-role.ts`:

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

export function roleCan(role: OrganizationRole, permission: Permission): boolean {
  return rolePermissions[role].includes(permission);
}
```

Buat file `src/modules/organizations/application/organization-access-reader.ts`:

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

Buat file `src/modules/organizations/application/organization-policy.ts`:

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

Buat database reader `src/modules/organizations/infrastructure/prisma-organization-access-reader.ts`:

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

## 5. Buat Domain Task

Buat file `src/modules/tasks/domain/task.ts`:

```ts
export type TaskStatus = "todo" | "in_progress" | "done";

export type TaskSnapshot = {
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
  private constructor(private readonly props: TaskSnapshot) {}

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
      description: input.description?.trim() || null,
      status: "todo",
      assigneeUserId: input.assigneeUserId || null,
      createdAt: now,
      updatedAt: now,
    });
  }

  toSnapshot(): TaskSnapshot {
    return { ...this.props };
  }
}
```

## 6. Buat Repository Contract

Buat file `src/modules/tasks/application/task-repository.ts`:

```ts
import type { Task } from "../domain/task";

export type TaskDto = {
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
  listByOrganization(input: {
    organizationId: string;
    page: number;
    pageSize: number;
  }): Promise<TaskDto[]>;
}
```

## 7. Buat Repository Database

Buat file `src/modules/tasks/infrastructure/prisma-task-repository.ts`:

```ts
import type { PrismaClient } from "@prisma/client";
import type { TaskRepository, TaskDto } from "../application/task-repository";
import type { Task } from "../domain/task";

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

  async listByOrganization(input: {
    organizationId: string;
    page: number;
    pageSize: number;
  }): Promise<TaskDto[]> {
    const rows = await this.prisma.task.findMany({
      where: { organizationId: input.organizationId },
      orderBy: { createdAt: "desc" },
      skip: (input.page - 1) * input.pageSize,
      take: input.pageSize,
    });

    return rows.map((row) => ({
      id: row.id,
      organizationId: row.organizationId,
      projectId: row.projectId,
      title: row.title,
      description: row.description,
      status: row.status,
      assigneeUserId: row.assigneeUserId,
      createdAt: row.createdAt.toISOString(),
    }));
  }
}
```

## 8. Buat Use Case Create Task

Buat file `src/modules/tasks/application/create-task.ts`:

```ts
import { randomUUID } from "crypto";
import { ForbiddenError, ValidationError } from "@/shared/errors/app-error";
import type { OrganizationAccessReader } from "@/modules/organizations/application/organization-access-reader";
import { OrganizationPolicy } from "@/modules/organizations/application/organization-policy";
import { roleCan } from "@/modules/organizations/application/organization-role";
import { Task } from "../domain/task";
import type { TaskDto, TaskRepository } from "./task-repository";

export type CreateTaskInput = {
  currentUserId: string;
  organizationId: string;
  projectId: string;
  title: string;
  description?: string;
  assigneeUserId?: string;
};

export class CreateTaskUseCase {
  constructor(
    private readonly tasks: TaskRepository,
    private readonly organizationAccess: OrganizationAccessReader
  ) {}

  async execute(input: CreateTaskInput): Promise<TaskDto> {
    const membership = await this.organizationAccess.getMembership({
      organizationId: input.organizationId,
      userId: input.currentUserId,
    });

    const currentMembership = OrganizationPolicy.requirePermission({
      membership,
      permission: "task:create",
    });

    if (input.assigneeUserId && !roleCan(currentMembership.role, "task:assign")) {
      throw new ForbiddenError("You cannot assign tasks.");
    }

    if (input.assigneeUserId) {
      const assigneeMembership = await this.organizationAccess.getMembership({
        organizationId: input.organizationId,
        userId: input.assigneeUserId,
      });

      if (!assigneeMembership) {
        throw new ValidationError(
          "TASK_ASSIGNEE_NOT_MEMBER",
          "Assignee is not a member."
        );
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

    return {
      id: saved.id,
      organizationId: saved.organizationId,
      projectId: saved.projectId,
      title: saved.title,
      description: saved.description,
      status: saved.status,
      assigneeUserId: saved.assigneeUserId,
      createdAt: saved.createdAt.toISOString(),
    };
  }
}
```

## 9. Buat Use Case List Task

Buat file `src/modules/tasks/application/list-tasks.ts`:

```ts
import type { OrganizationAccessReader } from "@/modules/organizations/application/organization-access-reader";
import { OrganizationPolicy } from "@/modules/organizations/application/organization-policy";
import type { TaskDto, TaskRepository } from "./task-repository";

export type ListTasksInput = {
  currentUserId: string;
  organizationId: string;
  page: number;
  pageSize: number;
};

export class ListTasksUseCase {
  constructor(
    private readonly tasks: TaskRepository,
    private readonly organizationAccess: OrganizationAccessReader
  ) {}

  async execute(input: ListTasksInput): Promise<TaskDto[]> {
    const membership = await this.organizationAccess.getMembership({
      organizationId: input.organizationId,
      userId: input.currentUserId,
    });

    OrganizationPolicy.requirePermission({
      membership,
      permission: "task:read",
    });

    return this.tasks.listByOrganization({
      organizationId: input.organizationId,
      page: input.page,
      pageSize: input.pageSize,
    });
  }
}
```

## 10. Buat Controller Atau Router

### Contoh REST Controller

Buat file `src/modules/tasks/presentation/task-controller.ts`:

```ts
import { fail, ok } from "@/shared/api/api-response";
import { AppError } from "@/shared/errors/app-error";
import type { CreateTaskUseCase } from "../application/create-task";
import type { ListTasksUseCase } from "../application/list-tasks";

export class TaskController {
  constructor(
    private readonly createTask: CreateTaskUseCase,
    private readonly listTasks: ListTasksUseCase
  ) {}

  async create(request: {
    currentUserId: string;
    params: { organizationId: string };
    body: {
      projectId: string;
      title: string;
      description?: string;
      assigneeUserId?: string;
    };
  }) {
    try {
      const task = await this.createTask.execute({
        currentUserId: request.currentUserId,
        organizationId: request.params.organizationId,
        ...request.body,
      });

      return ok(task, 201);
    } catch (error) {
      if (error instanceof AppError) {
        return fail(
          { code: error.code, message: error.message, details: error.details },
          error.status
        );
      }

      return fail({ code: "INTERNAL_ERROR", message: "Unexpected server error" }, 500);
    }
  }

  async list(request: {
    currentUserId: string;
    params: { organizationId: string };
    query: { page?: string; pageSize?: string };
  }) {
    try {
      const tasks = await this.listTasks.execute({
        currentUserId: request.currentUserId,
        organizationId: request.params.organizationId,
        page: Number(request.query.page ?? 1),
        pageSize: Number(request.query.pageSize ?? 20),
      });

      return ok(tasks);
    } catch (error) {
      if (error instanceof AppError) {
        return fail({ code: error.code, message: error.message }, error.status);
      }

      return fail({ code: "INTERNAL_ERROR", message: "Unexpected server error" }, 500);
    }
  }
}
```

### Contoh tRPC Router

```ts
import { z } from "zod";
import { createTRPCRouter, protectedProcedure } from "@/server/api/trpc";

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
      return ctx.useCases.createTask.execute({
        currentUserId: ctx.user.id,
        organizationId: input.organizationId,
        projectId: input.projectId,
        title: input.title,
        description: input.description,
        assigneeUserId: input.assigneeUserId,
      });
    }),

  list: protectedProcedure
    .input(
      z.object({
        organizationId: z.string().min(1),
        page: z.number().default(1),
        pageSize: z.number().default(20),
      })
    )
    .query(async ({ ctx, input }) => {
      return ctx.useCases.listTasks.execute({
        currentUserId: ctx.user.id,
        organizationId: input.organizationId,
        page: input.page,
        pageSize: input.pageSize,
      });
    }),
});
```

## 11. Test Manual Backend

Contoh request create task:

```powershell
curl -X POST http://localhost:3000/api/organizations/org_01/tasks `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer <token>" `
  -d '{"projectId":"project_01","title":"Belajar create task","description":"Dari database sampai frontend","assigneeUserId":"user_02"}'
```

Expected success:

```json
{
  "data": {
    "id": "task_01",
    "organizationId": "org_01",
    "projectId": "project_01",
    "title": "Belajar create task",
    "description": "Dari database sampai frontend",
    "status": "todo",
    "assigneeUserId": "user_02",
    "createdAt": "2026-07-06T00:00:00.000Z"
  },
  "error": null,
  "status": 201
}
```

Expected forbidden:

```json
{
  "data": null,
  "error": {
    "code": "FORBIDDEN",
    "message": "You do not have permission for this action."
  },
  "status": 403
}
```

## 12. Buat Frontend API Client

Buat file `src/features/tasks/api/task-api.ts`:

```ts
export type ApiResponse<T> = {
  data: T | null;
  error: { code: string; message: string; details?: unknown } | null;
  status: number;
};

export type TaskDto = {
  id: string;
  organizationId: string;
  projectId: string;
  title: string;
  description: string | null;
  status: string;
  assigneeUserId: string | null;
  createdAt: string;
};

export type CreateTaskInput = {
  projectId: string;
  title: string;
  description?: string;
  assigneeUserId?: string;
};

export async function createTask(
  organizationId: string,
  input: CreateTaskInput
): Promise<ApiResponse<TaskDto>> {
  const response = await fetch(`/api/organizations/${organizationId}/tasks`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });

  return response.json();
}

export async function listTasks(
  organizationId: string
): Promise<ApiResponse<TaskDto[]>> {
  const response = await fetch(`/api/organizations/${organizationId}/tasks`);
  return response.json();
}
```

## 13. Buat Frontend State

Contoh React hook `src/features/tasks/use-tasks.ts`:

```ts
import { useEffect, useState } from "react";
import { createTask, listTasks, type CreateTaskInput, type TaskDto } from "./api/task-api";

export function useTasks(organizationId: string) {
  const [tasks, setTasks] = useState<TaskDto[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function load() {
    setLoading(true);
    setError("");

    const response = await listTasks(organizationId);

    setTasks(response.data ?? []);
    setError(response.error?.message ?? "");
    setLoading(false);
  }

  async function create(input: CreateTaskInput) {
    setLoading(true);
    setError("");

    const response = await createTask(organizationId, input);

    setLoading(false);

    if (response.error) {
      setError(response.error.message);
      return null;
    }

    await load();
    return response.data;
  }

  useEffect(() => {
    void load();
  }, [organizationId]);

  return { tasks, loading, error, load, create };
}
```

Contoh Vue composable sama idenya:

```ts
import { ref } from "vue";
import { createTask, listTasks, type CreateTaskInput, type TaskDto } from "./api/task-api";

export function useTasks(organizationId: string) {
  const tasks = ref<TaskDto[]>([]);
  const loading = ref(false);
  const error = ref("");

  async function load() {
    loading.value = true;
    error.value = "";

    const response = await listTasks(organizationId);

    tasks.value = response.data ?? [];
    error.value = response.error?.message ?? "";
    loading.value = false;
  }

  async function create(input: CreateTaskInput) {
    loading.value = true;
    error.value = "";

    const response = await createTask(organizationId, input);
    loading.value = false;

    if (response.error) {
      error.value = response.error.message;
      return null;
    }

    await load();
    return response.data;
  }

  return { tasks, loading, error, load, create };
}
```

## 14. Buat Form Frontend

React form minimal:

```tsx
import { useState } from "react";
import { useTasks } from "../use-tasks";

export function CreateTaskForm({
  organizationId,
  projectId,
}: {
  organizationId: string;
  projectId: string;
}) {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const { create, loading, error } = useTasks(organizationId);

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();

    const task = await create({
      projectId,
      title,
      description,
    });

    if (task) {
      window.location.href = `/tasks/${task.id}`;
    }
  }

  return (
    <form onSubmit={onSubmit}>
      <label>
        Title
        <input value={title} onChange={(event) => setTitle(event.target.value)} />
      </label>

      <label>
        Description
        <textarea
          value={description}
          onChange={(event) => setDescription(event.target.value)}
        />
      </label>

      {error ? <p>{error}</p> : null}

      <button type="submit" disabled={loading}>
        {loading ? "Saving..." : "Create task"}
      </button>
    </form>
  );
}
```

Vue form minimal:

```vue
<script setup lang="ts">
import { ref } from "vue";
import { useRouter } from "vue-router";
import { useTasks } from "../use-tasks";

const props = defineProps<{
  organizationId: string;
  projectId: string;
}>();

const router = useRouter();
const title = ref("");
const description = ref("");
const { create, loading, error } = useTasks(props.organizationId);

async function submit() {
  const task = await create({
    projectId: props.projectId,
    title: title.value,
    description: description.value,
  });

  if (task) {
    router.push(`/tasks/${task.id}`);
  }
}
</script>

<template>
  <form @submit.prevent="submit">
    <label>
      Title
      <input v-model="title" />
    </label>

    <label>
      Description
      <textarea v-model="description" />
    </label>

    <p v-if="error">{{ error }}</p>

    <button type="submit" :disabled="loading">
      {{ loading ? "Saving..." : "Create task" }}
    </button>
  </form>
</template>
```

## 15. Buat List Frontend

React list minimal:

```tsx
import { useTasks } from "../use-tasks";

export function TaskList({ organizationId }: { organizationId: string }) {
  const { tasks, loading, error } = useTasks(organizationId);

  if (loading) return <p>Loading tasks...</p>;
  if (error) return <p>{error}</p>;
  if (!tasks.length) return <p>No tasks yet.</p>;

  return (
    <ul>
      {tasks.map((task) => (
        <li key={task.id}>
          <a href={`/tasks/${task.id}`}>{task.title}</a>
        </li>
      ))}
    </ul>
  );
}
```

Vue list minimal:

```vue
<script setup lang="ts">
import { onMounted } from "vue";
import { useTasks } from "../use-tasks";

const props = defineProps<{ organizationId: string }>();
const { tasks, loading, error, load } = useTasks(props.organizationId);

onMounted(load);
</script>

<template>
  <p v-if="loading">Loading tasks...</p>
  <p v-else-if="error">{{ error }}</p>
  <p v-else-if="!tasks.length">No tasks yet.</p>

  <ul v-else>
    <li v-for="task in tasks" :key="task.id">
      <RouterLink :to="`/tasks/${task.id}`">
        {{ task.title }}
      </RouterLink>
    </li>
  </ul>
</template>
```

## 16. Tambahkan Permission-Aware UI

Frontend boleh menyembunyikan tombol, tetapi backend tetap wajib mengecek permission.

Buat contract `src/features/organizations/permissions.ts`:

```ts
export type Permission =
  | "task:read"
  | "task:create"
  | "task:assign"
  | "task:update"
  | "task:delete";

export type ActiveOrganizationDto = {
  id: string;
  name: string;
  role: "owner" | "admin" | "member" | "viewer";
  permissions: Permission[];
};

export function can(organization: ActiveOrganizationDto, permission: Permission) {
  return organization.permissions.includes(permission);
}
```

React usage:

```tsx
import { can, type ActiveOrganizationDto } from "@/features/organizations/permissions";

export function TaskToolbar({ organization }: { organization: ActiveOrganizationDto }) {
  if (!can(organization, "task:create")) {
    return <p>You do not have permission to create tasks.</p>;
  }

  return <a href="/tasks/new">Create task</a>;
}
```

Vue usage:

```vue
<template>
  <RouterLink v-if="canCreateTask" to="/tasks/new">
    Create task
  </RouterLink>

  <p v-else>You do not have permission to create tasks.</p>
</template>
```

## 17. Urutan File Yang Dibuat

Backend:

```text
prisma/schema.prisma
prisma/seed.ts
src/shared/api/api-response.ts
src/shared/errors/app-error.ts
src/modules/organizations/application/organization-role.ts
src/modules/organizations/application/organization-access-reader.ts
src/modules/organizations/application/organization-policy.ts
src/modules/organizations/infrastructure/prisma-organization-access-reader.ts
src/modules/tasks/domain/task.ts
src/modules/tasks/application/task-repository.ts
src/modules/tasks/infrastructure/prisma-task-repository.ts
src/modules/tasks/application/create-task.ts
src/modules/tasks/application/list-tasks.ts
src/modules/tasks/presentation/task-controller.ts
```

Frontend:

```text
src/features/tasks/api/task-api.ts
src/features/tasks/use-tasks.ts
src/features/tasks/components/CreateTaskForm.tsx
src/features/tasks/components/TaskList.tsx
src/features/organizations/permissions.ts
```

## 18. Checklist Belajar

- Bisa menjelaskan kenapa tabel `tasks` punya `organization_id`.
- Bisa menjelaskan kenapa frontend tidak boleh mengirim role sebagai sumber kebenaran.
- Bisa menjalankan migration dan seed.
- Bisa membuat task lewat API.
- Bisa melihat error `FORBIDDEN` saat role tidak punya permission.
- Bisa menampilkan list task di frontend.
- Bisa menyembunyikan tombol create berdasarkan permission, tetapi tetap paham backend yang menentukan izin final.