# Backend 05 - Task Module

File ini menjelaskan cara membuat Task Module untuk backend modern SaaS task workspace di stack `modern-saas-t3-next`.

File sebelumnya sudah menyiapkan fondasi project, modular monolith, Identity/Auth, dan Organization/Tenancy. File ini memakai semua fondasi itu: task hanya boleh diakses oleh user login, user harus menjadi member organization, dan query task harus selalu dibatasi oleh `organizationId` dan `projectId`.

Task berhubungan langsung dengan Organization dan Project:

- Organization adalah tenant/workspace.
- Project adalah container pekerjaan di dalam organization.
- Task adalah unit pekerjaan di dalam project.

Karena itu Task wajib punya `organizationId` dan `projectId`. `organizationId` menjaga tenant isolation, sedangkan `projectId` menjaga task berada di ruang kerja project yang benar. Query task tidak boleh hanya berdasarkan `taskId`, karena id task saja tidak cukup untuk membuktikan user berhak membaca data tersebut.

Tenant isolation wajib dicek sebelum akses task. Backend harus memastikan `ctx.user.id` adalah member dari `organizationId`, lalu memastikan project berada di organization yang sama, baru boleh membaca atau mengubah task.

## Konsep Dasar Task Module

### Task

Task adalah pekerjaan yang perlu dilakukan. Contoh: `Create login endpoint`, `Review billing copy`, atau `Fix project filter bug`.

Task biasanya punya title, description, status, priority, due date, assignee, reporter, dan metadata audit.

### Project

Project adalah container task di dalam organization. Satu organization bisa punya banyak project, dan satu project bisa punya banyak task.

Task tidak boleh dibuat tanpa project karena project membantu grouping pekerjaan dan membuat query lebih terarah.

### Assignee

Assignee adalah user yang bertanggung jawab mengerjakan task. Assignee harus member organization yang sama. Jangan izinkan assign task ke user dari tenant lain.

### Reporter / Creator

Reporter atau creator adalah user yang membuat task. Field ini penting untuk audit dan filtering. Reporter juga harus berasal dari `ctx.user.id`, bukan input frontend.

### Task Status

Task status menunjukkan posisi workflow task. Contoh status awal:

- `TODO`
- `IN_PROGRESS`
- `DONE`
- `CANCELED`
- `ARCHIVED`

Status transition sebaiknya punya aturan. Contoh: task yang sudah `ARCHIVED` tidak boleh langsung diubah kembali lewat endpoint biasa.

### Task Priority

Task priority menunjukkan tingkat kepentingan task. Contoh:

- `LOW`
- `MEDIUM`
- `HIGH`
- `URGENT`

Priority berguna untuk filter, sorting, dan dashboard.

### Due Date

Due date adalah tanggal target penyelesaian task. Due date bersifat opsional karena tidak semua task punya deadline.

### Tenant Isolation

Tenant isolation berarti task milik organization A tidak boleh terlihat oleh user organization B. Semua query task wajib memakai `organizationId`.

### Project Access

Project access berarti backend memastikan project yang dipakai benar-benar milik organization yang sedang diakses. Jangan membuat task dengan `projectId` tanpa cek `organizationId`.

### Kenapa Task Difilter Berdasarkan `organizationId` Dan `projectId`

Filter `organizationId` melindungi batas tenant. Filter `projectId` memastikan task berada di project yang benar.

Contoh buruk:

```ts
// src/server/modules/tasks/infrastructure/bad-task.repository.ts
export async function findTaskById(taskId: string) {
  return db.task.findUnique({
    where: {
      id: taskId,
    },
  });
}
```

Contoh aman:

```ts
// src/server/modules/tasks/infrastructure/task.repository.ts
export async function findTaskById(params: {
  organizationId: string;
  projectId: string;
  taskId: string;
}) {
  return db.task.findFirst({
    where: {
      id: params.taskId,
      organizationId: params.organizationId,
      projectId: params.projectId,
    },
  });
}
```

### Kenapa Status Workflow Tidak Ditaruh Langsung Di Router

Router tRPC adalah boundary transport. Jika aturan status ditaruh langsung di router, logic akan sulit dites dan mudah terduplikasi.

Status workflow sebaiknya dipisah ke Strategy Pattern agar aturan transition bisa diganti atau diperluas tanpa mengubah router. Misalnya versi awal memakai workflow sederhana, nanti paket enterprise bisa memakai workflow custom per organization.

## Scope Fitur

Fitur yang dibuat di dokumentasi ini:

- create task;
- get task list by organization + project;
- get task detail;
- update task;
- assign task ke user;
- change task status;
- archive task;
- pagination;
- search by title;
- filter by status;
- filter by priority;
- filter by assignee;
- protected tRPC procedures;
- Zod validation;
- Prisma repository;
- result pattern;
- Strategy Pattern untuk status transition;
- error handling.

Yang tidak dibahas mendalam:

- UI task board;
- drag and drop;
- billing;
- notification;
- audit log detail;
- custom workflow per organization.

## Struktur Folder Tasks

Gunakan struktur:

```txt
src/server/modules/tasks/
├── domain/
│   ├── task.entity.ts
│   ├── task-status.ts
│   └── task-priority.ts
│
├── application/
│   ├── task.service.ts
│   ├── task.repository.ts
│   ├── project-access-checker.ts
│   └── task-status-transition.strategy.ts
│
├── infrastructure/
│   ├── prisma-task.repository.ts
│   ├── prisma-project-access-checker.ts
│   └── default-task-status-transition.strategy.ts
│
└── presentation/
    ├── task.input.ts
    └── task.router.ts
```

Penjelasan:

- `domain`: entity, status, priority, dan rule kecil yang tidak bergantung framework.
- `application`: use case task dan kontrak dependency.
- `infrastructure`: Prisma repository, project access checker, dan strategy implementasi default.
- `presentation`: Zod schema dan tRPC router.

## Prisma Schema

Pastikan model `Project` dan `Task` mendukung tenant isolation, assignee, reporter, status, priority, dan archive.

```prisma
// prisma/schema.prisma
enum TaskStatus {
  TODO
  IN_PROGRESS
  DONE
  CANCELED
  ARCHIVED
}

enum TaskPriority {
  LOW
  MEDIUM
  HIGH
  URGENT
}

model Project {
  id             String   @id @default(cuid())
  organizationId String
  name           String
  slug           String
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt

  organization Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  tasks        Task[]

  @@unique([organizationId, slug])
  @@index([organizationId])
}

model Task {
  id             String       @id @default(cuid())
  organizationId String
  projectId      String
  title          String
  description    String?
  status         TaskStatus   @default(TODO)
  priority       TaskPriority @default(MEDIUM)
  assigneeId     String?
  reporterId     String
  dueDate        DateTime?
  archivedAt     DateTime?
  createdAt      DateTime     @default(now())
  updatedAt      DateTime     @updatedAt

  organization Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  project      Project      @relation(fields: [projectId], references: [id], onDelete: Cascade)
  assignee     User?        @relation("TaskAssignee", fields: [assigneeId], references: [id], onDelete: SetNull)
  reporter     User         @relation("TaskReporter", fields: [reporterId], references: [id], onDelete: Restrict)

  @@index([organizationId])
  @@index([projectId])
  @@index([organizationId, projectId])
  @@index([status])
  @@index([priority])
  @@index([assigneeId])
  @@index([reporterId])
}
```

Jika menambahkan relation `TaskAssignee` dan `TaskReporter`, model `User` juga perlu relation balik:

```prisma
// prisma/schema.prisma
model User {
  id           String   @id @default(cuid())
  email        String   @unique
  name         String?
  passwordHash String
  role         UserRole @default(MEMBER)
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

  assignedTasks Task[] @relation("TaskAssignee")
  reportedTasks Task[] @relation("TaskReporter")

  organizationMembers OrganizationMember[]
  auditLogs           AuditLog[]

  @@index([role])
}
```

Jalankan migration:

```bash
npx prisma migrate dev --name add_task_module
```

Penjelasan:

- `prisma migrate dev` membuat dan menjalankan migration development.
- `--name add_task_module` memberi nama migration agar mudah dibaca.
- Prisma Client akan digenerate ulang setelah migration berhasil.

## Domain Layer

### Task Status

Buat file `src/server/modules/tasks/domain/task-status.ts`:

```ts
// src/server/modules/tasks/domain/task-status.ts
export const taskStatuses = [
  "TODO",
  "IN_PROGRESS",
  "DONE",
  "CANCELED",
  "ARCHIVED",
] as const;

export type TaskStatus = (typeof taskStatuses)[number];

export function isTaskStatus(value: string): value is TaskStatus {
  return taskStatuses.includes(value as TaskStatus);
}
```

### Task Priority

Buat file `src/server/modules/tasks/domain/task-priority.ts`:

```ts
// src/server/modules/tasks/domain/task-priority.ts
export const taskPriorities = ["LOW", "MEDIUM", "HIGH", "URGENT"] as const;

export type TaskPriority = (typeof taskPriorities)[number];

export function isTaskPriority(value: string): value is TaskPriority {
  return taskPriorities.includes(value as TaskPriority);
}
```

### Task Entity

Buat file `src/server/modules/tasks/domain/task.entity.ts`:

```ts
// src/server/modules/tasks/domain/task.entity.ts
import type { TaskPriority } from "./task-priority";
import type { TaskStatus } from "./task-status";

export type TaskEntity = {
  id: string;
  organizationId: string;
  projectId: string;
  title: string;
  description: string | null;
  status: TaskStatus;
  priority: TaskPriority;
  assigneeId: string | null;
  reporterId: string;
  dueDate: Date | null;
  archivedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

export type TaskWithUsers = TaskEntity & {
  assignee: {
    id: string;
    email: string;
    name: string | null;
  } | null;
  reporter: {
    id: string;
    email: string;
    name: string | null;
  };
};

export function normalizeTaskTitle(title: string) {
  return title.trim();
}

export function assertValidTaskTitle(title: string) {
  const normalizedTitle = normalizeTaskTitle(title);

  if (normalizedTitle.length < 3) {
    throw new Error("TASK_TITLE_TOO_SHORT");
  }

  if (normalizedTitle.length > 160) {
    throw new Error("TASK_TITLE_TOO_LONG");
  }

  return normalizedTitle;
}

export function isArchivedTask(task: TaskEntity) {
  return task.status === "ARCHIVED" || task.archivedAt !== null;
}
```

Penjelasan:

- `TaskEntity` selalu membawa `organizationId` dan `projectId`.
- `TaskWithUsers` aman untuk response karena hanya mengambil field user publik.
- `assertValidTaskTitle` adalah rule domain sederhana.
- `isArchivedTask` memudahkan service menolak update task yang sudah diarsipkan.

## Application Contracts

### Task Repository

Buat file `src/server/modules/tasks/application/task.repository.ts`:

```ts
// src/server/modules/tasks/application/task.repository.ts
import type { TaskEntity, TaskWithUsers } from "../domain/task.entity";
import type { TaskPriority } from "../domain/task-priority";
import type { TaskStatus } from "../domain/task-status";

export type TaskListFilter = {
  organizationId: string;
  projectId: string;
  search?: string;
  status?: TaskStatus;
  priority?: TaskPriority;
  assigneeId?: string;
  includeArchived?: boolean;
  skip: number;
  take: number;
};

export type CreateTaskData = {
  organizationId: string;
  projectId: string;
  title: string;
  description?: string | null;
  priority: TaskPriority;
  assigneeId?: string | null;
  reporterId: string;
  dueDate?: Date | null;
};

export type UpdateTaskData = {
  organizationId: string;
  projectId: string;
  taskId: string;
  title?: string;
  description?: string | null;
  priority?: TaskPriority;
  dueDate?: Date | null;
};

export interface TaskRepository {
  list(filter: TaskListFilter): Promise<TaskWithUsers[]>;
  count(filter: Omit<TaskListFilter, "skip" | "take">): Promise<number>;
  findById(params: {
    organizationId: string;
    projectId: string;
    taskId: string;
  }): Promise<TaskWithUsers | null>;
  create(data: CreateTaskData): Promise<TaskWithUsers>;
  update(data: UpdateTaskData): Promise<TaskWithUsers>;
  assign(params: {
    organizationId: string;
    projectId: string;
    taskId: string;
    assigneeId: string | null;
  }): Promise<TaskWithUsers>;
  changeStatus(params: {
    organizationId: string;
    projectId: string;
    taskId: string;
    status: TaskStatus;
  }): Promise<TaskWithUsers>;
  archive(params: {
    organizationId: string;
    projectId: string;
    taskId: string;
  }): Promise<TaskWithUsers>;
}
```

Penjelasan:

- Semua method detail/mutation memakai `organizationId`, `projectId`, dan `taskId`.
- Tidak ada method `findById(taskId)` karena itu rawan bocor antar tenant.
- Repository bertanggung jawab pada query Prisma, bukan permission.

### Project Access Checker

Buat file `src/server/modules/tasks/application/project-access-checker.ts`:

```ts
// src/server/modules/tasks/application/project-access-checker.ts
export type ProjectAccess = {
  organizationId: string;
  projectId: string;
};

export interface ProjectAccessChecker {
  ensureProjectInOrganization(params: ProjectAccess): Promise<boolean>;
  ensureUserIsOrganizationMember(params: {
    organizationId: string;
    userId: string;
  }): Promise<boolean>;
}
```

Penjelasan:

- `ensureProjectInOrganization` mencegah project tenant lain dipakai untuk task.
- `ensureUserIsOrganizationMember` dipakai untuk actor dan assignee.
- Interface ini bisa memakai repository organization dari file 04 atau query Prisma langsung di infrastructure.

### Status Transition Strategy

Buat file `src/server/modules/tasks/application/task-status-transition.strategy.ts`:

```ts
// src/server/modules/tasks/application/task-status-transition.strategy.ts
import type { TaskEntity } from "../domain/task.entity";
import type { TaskStatus } from "../domain/task-status";

export type TaskStatusTransitionDecision = {
  allowed: boolean;
  reason?: string;
};

export interface TaskStatusTransitionStrategy {
  canTransition(params: {
    task: TaskEntity;
    nextStatus: TaskStatus;
  }): TaskStatusTransitionDecision;
}
```

Strategy Pattern dipakai agar aturan perubahan status tidak dikunci di router atau service. Nanti jika tiap organization punya workflow berbeda, implementasi strategy bisa diganti.

## Infrastructure Layer

### Default Status Transition Strategy

Buat file `src/server/modules/tasks/infrastructure/default-task-status-transition.strategy.ts`:

```ts
// src/server/modules/tasks/infrastructure/default-task-status-transition.strategy.ts
import type { TaskStatusTransitionStrategy } from "../application/task-status-transition.strategy";
import type { TaskStatus } from "../domain/task-status";

const allowedTransitions: Record<TaskStatus, TaskStatus[]> = {
  TODO: ["IN_PROGRESS", "CANCELED", "ARCHIVED"],
  IN_PROGRESS: ["TODO", "DONE", "CANCELED", "ARCHIVED"],
  DONE: ["IN_PROGRESS", "ARCHIVED"],
  CANCELED: ["TODO", "ARCHIVED"],
  ARCHIVED: [],
};

export class DefaultTaskStatusTransitionStrategy
  implements TaskStatusTransitionStrategy
{
  canTransition(params: Parameters<TaskStatusTransitionStrategy["canTransition"]>[0]) {
    if (params.task.status === params.nextStatus) {
      return {
        allowed: true,
      };
    }

    const allowedNextStatuses = allowedTransitions[params.task.status];

    if (!allowedNextStatuses.includes(params.nextStatus)) {
      return {
        allowed: false,
        reason: `Cannot transition task from ${params.task.status} to ${params.nextStatus}.`,
      };
    }

    return {
      allowed: true,
    };
  }
}
```

Penjelasan:

- `ARCHIVED` tidak bisa keluar lewat normal status transition.
- Archive punya use case sendiri.
- Rule ini mudah diganti tanpa mengubah tRPC router.

### Prisma Project Access Checker

Buat file `src/server/modules/tasks/infrastructure/prisma-project-access-checker.ts`:

```ts
// src/server/modules/tasks/infrastructure/prisma-project-access-checker.ts
import type { PrismaClient } from "@prisma/client";
import type { ProjectAccessChecker } from "../application/project-access-checker";

export class PrismaProjectAccessChecker implements ProjectAccessChecker {
  constructor(private readonly db: PrismaClient) {}

  async ensureProjectInOrganization(params: {
    organizationId: string;
    projectId: string;
  }): Promise<boolean> {
    const count = await this.db.project.count({
      where: {
        id: params.projectId,
        organizationId: params.organizationId,
      },
    });

    return count > 0;
  }

  async ensureUserIsOrganizationMember(params: {
    organizationId: string;
    userId: string;
  }): Promise<boolean> {
    const count = await this.db.organizationMember.count({
      where: {
        organizationId: params.organizationId,
        userId: params.userId,
      },
    });

    return count > 0;
  }
}
```

Penjelasan:

- Checker memastikan project dan member berada di organization yang sama.
- Ini adalah bagian tenant isolation untuk Task Module.

### Prisma Task Repository

Buat file `src/server/modules/tasks/infrastructure/prisma-task.repository.ts`:

```ts
// src/server/modules/tasks/infrastructure/prisma-task.repository.ts
import type { PrismaClient } from "@prisma/client";
import type {
  CreateTaskData,
  TaskListFilter,
  TaskRepository,
  UpdateTaskData,
} from "../application/task.repository";
import type { TaskWithUsers } from "../domain/task.entity";
import { isTaskPriority } from "../domain/task-priority";
import { isTaskStatus } from "../domain/task-status";

const taskInclude = {
  assignee: {
    select: {
      id: true,
      email: true,
      name: true,
    },
  },
  reporter: {
    select: {
      id: true,
      email: true,
      name: true,
    },
  },
} as const;

function mapTask(task: {
  id: string;
  organizationId: string;
  projectId: string;
  title: string;
  description: string | null;
  status: string;
  priority: string;
  assigneeId: string | null;
  reporterId: string;
  dueDate: Date | null;
  archivedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  assignee: { id: string; email: string; name: string | null } | null;
  reporter: { id: string; email: string; name: string | null };
}): TaskWithUsers {
  if (!isTaskStatus(task.status)) {
    throw new Error(`Invalid task status from database: ${task.status}`);
  }

  if (!isTaskPriority(task.priority)) {
    throw new Error(`Invalid task priority from database: ${task.priority}`);
  }

  return {
    id: task.id,
    organizationId: task.organizationId,
    projectId: task.projectId,
    title: task.title,
    description: task.description,
    status: task.status,
    priority: task.priority,
    assigneeId: task.assigneeId,
    reporterId: task.reporterId,
    dueDate: task.dueDate,
    archivedAt: task.archivedAt,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
    assignee: task.assignee,
    reporter: task.reporter,
  };
}

function buildWhere(filter: Omit<TaskListFilter, "skip" | "take">) {
  return {
    organizationId: filter.organizationId,
    projectId: filter.projectId,
    status: filter.status,
    priority: filter.priority,
    assigneeId: filter.assigneeId,
    archivedAt: filter.includeArchived ? undefined : null,
    title: filter.search
      ? {
          contains: filter.search,
          mode: "insensitive" as const,
        }
      : undefined,
  };
}

export class PrismaTaskRepository implements TaskRepository {
  constructor(private readonly db: PrismaClient) {}

  async list(filter: TaskListFilter): Promise<TaskWithUsers[]> {
    const tasks = await this.db.task.findMany({
      where: buildWhere(filter),
      include: taskInclude,
      orderBy: {
        createdAt: "desc",
      },
      skip: filter.skip,
      take: filter.take,
    });

    return tasks.map(mapTask);
  }

  async count(filter: Omit<TaskListFilter, "skip" | "take">): Promise<number> {
    return this.db.task.count({
      where: buildWhere(filter),
    });
  }

  async findById(params: {
    organizationId: string;
    projectId: string;
    taskId: string;
  }): Promise<TaskWithUsers | null> {
    const task = await this.db.task.findFirst({
      where: {
        id: params.taskId,
        organizationId: params.organizationId,
        projectId: params.projectId,
      },
      include: taskInclude,
    });

    return task ? mapTask(task) : null;
  }

  async create(data: CreateTaskData): Promise<TaskWithUsers> {
    const task = await this.db.task.create({
      data: {
        organizationId: data.organizationId,
        projectId: data.projectId,
        title: data.title,
        description: data.description ?? null,
        priority: data.priority,
        assigneeId: data.assigneeId ?? null,
        reporterId: data.reporterId,
        dueDate: data.dueDate ?? null,
      },
      include: taskInclude,
    });

    return mapTask(task);
  }

  async update(data: UpdateTaskData): Promise<TaskWithUsers> {
    const task = await this.db.task.update({
      where: {
        id: data.taskId,
        organizationId: data.organizationId,
        projectId: data.projectId,
      },
      data: {
        title: data.title,
        description: data.description,
        priority: data.priority,
        dueDate: data.dueDate,
      },
      include: taskInclude,
    });

    return mapTask(task);
  }

  async assign(params: {
    organizationId: string;
    projectId: string;
    taskId: string;
    assigneeId: string | null;
  }): Promise<TaskWithUsers> {
    const task = await this.db.task.update({
      where: {
        id: params.taskId,
        organizationId: params.organizationId,
        projectId: params.projectId,
      },
      data: {
        assigneeId: params.assigneeId,
      },
      include: taskInclude,
    });

    return mapTask(task);
  }

  async changeStatus(params: {
    organizationId: string;
    projectId: string;
    taskId: string;
    status: TaskWithUsers["status"];
  }): Promise<TaskWithUsers> {
    const task = await this.db.task.update({
      where: {
        id: params.taskId,
        organizationId: params.organizationId,
        projectId: params.projectId,
      },
      data: {
        status: params.status,
      },
      include: taskInclude,
    });

    return mapTask(task);
  }

  async archive(params: {
    organizationId: string;
    projectId: string;
    taskId: string;
  }): Promise<TaskWithUsers> {
    const task = await this.db.task.update({
      where: {
        id: params.taskId,
        organizationId: params.organizationId,
        projectId: params.projectId,
      },
      data: {
        status: "ARCHIVED",
        archivedAt: new Date(),
      },
      include: taskInclude,
    });

    return mapTask(task);
  }
}
```

Penjelasan:

- `findById`, `update`, `assign`, `changeStatus`, dan `archive` selalu memakai `organizationId`, `projectId`, dan `taskId`.
- List task mendukung search, filter status, filter priority, filter assignee, dan exclude archived default.
- Field user yang diambil hanya `id`, `email`, dan `name`.
- Repository tidak mengecek permission. Permission dilakukan di service.

Catatan Prisma: contoh `where` dengan composite field di `update` membutuhkan Prisma mendukung extended unique where. Jika versi Prisma project tidak mendukung filter tambahan di `update.where`, gunakan `updateMany` dengan `id + organizationId + projectId`, lalu fetch ulang dengan `findById`.

Contoh fallback:

```ts
// src/server/modules/tasks/infrastructure/prisma-task.repository.ts
await this.db.task.updateMany({
  where: {
    id: params.taskId,
    organizationId: params.organizationId,
    projectId: params.projectId,
  },
  data: {
    status: params.status,
  },
});

const task = await this.findById(params);

if (!task) {
  throw new Error("TASK_NOT_FOUND_AFTER_UPDATE");
}

return task;
```

## Shared Pagination

Jika file `02-modular-monolith-layers.md` sudah membuat helper pagination, gunakan kembali.

```ts
// src/shared/pagination/pagination.ts
export type PaginationInput = {
  page: number;
  pageSize: number;
};

export type PaginationMeta = {
  page: number;
  pageSize: number;
  totalItems: number;
  totalPages: number;
};

export function getPagination(input: PaginationInput) {
  const page = Math.max(input.page, 1);
  const pageSize = Math.min(Math.max(input.pageSize, 1), 100);

  return {
    page,
    pageSize,
    skip: (page - 1) * pageSize,
    take: pageSize,
  };
}

export function createPaginationMeta(params: {
  page: number;
  pageSize: number;
  totalItems: number;
}): PaginationMeta {
  return {
    page: params.page,
    pageSize: params.pageSize,
    totalItems: params.totalItems,
    totalPages: Math.ceil(params.totalItems / params.pageSize),
  };
}
```

## Application Service

Buat file `src/server/modules/tasks/application/task.service.ts`:

```ts
// src/server/modules/tasks/application/task.service.ts
import { createPaginationMeta, getPagination } from "@/shared/pagination/pagination";
import { err, ok, type AppResult } from "@/shared/result/result";
import {
  assertValidTaskTitle,
  isArchivedTask,
  type TaskWithUsers,
} from "../domain/task.entity";
import type { TaskPriority } from "../domain/task-priority";
import type { TaskStatus } from "../domain/task-status";
import type { ProjectAccessChecker } from "./project-access-checker";
import type { TaskRepository } from "./task.repository";
import type { TaskStatusTransitionStrategy } from "./task-status-transition.strategy";

export type TaskError =
  | "PROJECT_NOT_FOUND"
  | "MEMBERSHIP_REQUIRED"
  | "ASSIGNEE_NOT_MEMBER"
  | "TASK_NOT_FOUND"
  | "TASK_ARCHIVED"
  | "TASK_TITLE_INVALID"
  | "TASK_STATUS_TRANSITION_INVALID";

export type ListTasksParams = {
  actorUserId: string;
  organizationId: string;
  projectId: string;
  search?: string;
  status?: TaskStatus;
  priority?: TaskPriority;
  assigneeId?: string;
  includeArchived?: boolean;
  page: number;
  pageSize: number;
};

export type CreateTaskParams = {
  actorUserId: string;
  organizationId: string;
  projectId: string;
  title: string;
  description?: string | null;
  priority: TaskPriority;
  assigneeId?: string | null;
  dueDate?: Date | null;
};

export type UpdateTaskParams = {
  actorUserId: string;
  organizationId: string;
  projectId: string;
  taskId: string;
  title?: string;
  description?: string | null;
  priority?: TaskPriority;
  dueDate?: Date | null;
};

export class TaskService {
  constructor(
    private readonly taskRepository: TaskRepository,
    private readonly projectAccessChecker: ProjectAccessChecker,
    private readonly statusTransitionStrategy: TaskStatusTransitionStrategy,
  ) {}

  private async ensureProjectAccess(params: {
    actorUserId: string;
    organizationId: string;
    projectId: string;
  }): Promise<AppResult<{ allowed: true }, TaskError>> {
    const isMember = await this.projectAccessChecker.ensureUserIsOrganizationMember({
      organizationId: params.organizationId,
      userId: params.actorUserId,
    });

    if (!isMember) {
      return err("MEMBERSHIP_REQUIRED", "Organization membership is required.");
    }

    const projectExists = await this.projectAccessChecker.ensureProjectInOrganization({
      organizationId: params.organizationId,
      projectId: params.projectId,
    });

    if (!projectExists) {
      return err("PROJECT_NOT_FOUND", "Project was not found in this organization.");
    }

    return ok({ allowed: true });
  }

  private async ensureAssigneeIsMember(params: {
    organizationId: string;
    assigneeId: string | null | undefined;
  }): Promise<AppResult<{ allowed: true }, TaskError>> {
    if (!params.assigneeId) {
      return ok({ allowed: true });
    }

    const isMember = await this.projectAccessChecker.ensureUserIsOrganizationMember({
      organizationId: params.organizationId,
      userId: params.assigneeId,
    });

    if (!isMember) {
      return err("ASSIGNEE_NOT_MEMBER", "Assignee must be organization member.");
    }

    return ok({ allowed: true });
  }

  async listTasks(params: ListTasksParams) {
    const accessResult = await this.ensureProjectAccess(params);

    if (!accessResult.ok) {
      return accessResult;
    }

    const pagination = getPagination({
      page: params.page,
      pageSize: params.pageSize,
    });

    const filter = {
      organizationId: params.organizationId,
      projectId: params.projectId,
      search: params.search,
      status: params.status,
      priority: params.priority,
      assigneeId: params.assigneeId,
      includeArchived: params.includeArchived,
    };

    const [items, totalItems] = await Promise.all([
      this.taskRepository.list({
        ...filter,
        skip: pagination.skip,
        take: pagination.take,
      }),
      this.taskRepository.count(filter),
    ]);

    return ok({
      items,
      meta: createPaginationMeta({
        page: pagination.page,
        pageSize: pagination.pageSize,
        totalItems,
      }),
    });
  }

  async getTaskDetail(params: {
    actorUserId: string;
    organizationId: string;
    projectId: string;
    taskId: string;
  }): Promise<AppResult<TaskWithUsers, TaskError>> {
    const accessResult = await this.ensureProjectAccess(params);

    if (!accessResult.ok) {
      return accessResult;
    }

    const task = await this.taskRepository.findById(params);

    if (!task) {
      return err("TASK_NOT_FOUND", "Task was not found.");
    }

    return ok(task);
  }

  async createTask(
    params: CreateTaskParams,
  ): Promise<AppResult<TaskWithUsers, TaskError>> {
    const accessResult = await this.ensureProjectAccess(params);

    if (!accessResult.ok) {
      return accessResult;
    }

    const assigneeResult = await this.ensureAssigneeIsMember({
      organizationId: params.organizationId,
      assigneeId: params.assigneeId,
    });

    if (!assigneeResult.ok) {
      return assigneeResult;
    }

    try {
      const title = assertValidTaskTitle(params.title);

      const task = await this.taskRepository.create({
        organizationId: params.organizationId,
        projectId: params.projectId,
        title,
        description: params.description,
        priority: params.priority,
        assigneeId: params.assigneeId,
        reporterId: params.actorUserId,
        dueDate: params.dueDate,
      });

      return ok(task);
    } catch (error) {
      if (error instanceof Error && error.message.startsWith("TASK_TITLE_")) {
        return err("TASK_TITLE_INVALID", "Task title is invalid.");
      }

      throw error;
    }
  }

  async updateTask(
    params: UpdateTaskParams,
  ): Promise<AppResult<TaskWithUsers, TaskError>> {
    const existingTaskResult = await this.getTaskDetail(params);

    if (!existingTaskResult.ok) {
      return existingTaskResult;
    }

    if (isArchivedTask(existingTaskResult.value)) {
      return err("TASK_ARCHIVED", "Archived task cannot be updated.");
    }

    try {
      const title = params.title ? assertValidTaskTitle(params.title) : undefined;

      const task = await this.taskRepository.update({
        organizationId: params.organizationId,
        projectId: params.projectId,
        taskId: params.taskId,
        title,
        description: params.description,
        priority: params.priority,
        dueDate: params.dueDate,
      });

      return ok(task);
    } catch (error) {
      if (error instanceof Error && error.message.startsWith("TASK_TITLE_")) {
        return err("TASK_TITLE_INVALID", "Task title is invalid.");
      }

      throw error;
    }
  }

  async assignTask(params: {
    actorUserId: string;
    organizationId: string;
    projectId: string;
    taskId: string;
    assigneeId: string | null;
  }): Promise<AppResult<TaskWithUsers, TaskError>> {
    const existingTaskResult = await this.getTaskDetail(params);

    if (!existingTaskResult.ok) {
      return existingTaskResult;
    }

    if (isArchivedTask(existingTaskResult.value)) {
      return err("TASK_ARCHIVED", "Archived task cannot be assigned.");
    }

    const assigneeResult = await this.ensureAssigneeIsMember({
      organizationId: params.organizationId,
      assigneeId: params.assigneeId,
    });

    if (!assigneeResult.ok) {
      return assigneeResult;
    }

    const task = await this.taskRepository.assign(params);
    return ok(task);
  }

  async changeTaskStatus(params: {
    actorUserId: string;
    organizationId: string;
    projectId: string;
    taskId: string;
    status: TaskStatus;
  }): Promise<AppResult<TaskWithUsers, TaskError>> {
    const existingTaskResult = await this.getTaskDetail(params);

    if (!existingTaskResult.ok) {
      return existingTaskResult;
    }

    const decision = this.statusTransitionStrategy.canTransition({
      task: existingTaskResult.value,
      nextStatus: params.status,
    });

    if (!decision.allowed) {
      return err(
        "TASK_STATUS_TRANSITION_INVALID",
        decision.reason ?? "Task status transition is not allowed.",
      );
    }

    const task = await this.taskRepository.changeStatus(params);
    return ok(task);
  }

  async archiveTask(params: {
    actorUserId: string;
    organizationId: string;
    projectId: string;
    taskId: string;
  }): Promise<AppResult<TaskWithUsers, TaskError>> {
    const existingTaskResult = await this.getTaskDetail(params);

    if (!existingTaskResult.ok) {
      return existingTaskResult;
    }

    if (isArchivedTask(existingTaskResult.value)) {
      return ok(existingTaskResult.value);
    }

    const task = await this.taskRepository.archive(params);
    return ok(task);
  }
}
```

Penjelasan:

- `getTaskDetail` tetap memakai `organizationId + projectId + taskId`.
- `updateTask` menolak task archived.
- `assignTask` memastikan assignee adalah member organization.
- `changeTaskStatus` memakai strategy, bukan rule langsung di router.
- `archiveTask` memakai use case khusus agar archive tidak bercampur dengan status transition normal.

## Presentation Input

Buat file `src/server/modules/tasks/presentation/task.input.ts`:

```ts
// src/server/modules/tasks/presentation/task.input.ts
import { z } from "zod";
import { taskPriorities } from "../domain/task-priority";
import { taskStatuses } from "../domain/task-status";

const scopedTaskSchema = z.object({
  organizationId: z.string().min(1),
  projectId: z.string().min(1),
});

const taskIdSchema = scopedTaskSchema.extend({
  taskId: z.string().min(1),
});

export const listTasksInputSchema = scopedTaskSchema.extend({
  search: z.string().trim().min(1).max(120).optional(),
  status: z.enum(taskStatuses).optional(),
  priority: z.enum(taskPriorities).optional(),
  assigneeId: z.string().min(1).optional(),
  includeArchived: z.boolean().default(false),
  page: z.number().int().min(1).default(1),
  pageSize: z.number().int().min(1).max(100).default(20),
});

export const getTaskDetailInputSchema = taskIdSchema;

export const createTaskInputSchema = scopedTaskSchema.extend({
  title: z.string().min(3).max(160),
  description: z.string().max(4000).optional(),
  priority: z.enum(taskPriorities).default("MEDIUM"),
  assigneeId: z.string().min(1).nullable().optional(),
  dueDate: z.coerce.date().nullable().optional(),
});

export const updateTaskInputSchema = taskIdSchema.extend({
  title: z.string().min(3).max(160).optional(),
  description: z.string().max(4000).nullable().optional(),
  priority: z.enum(taskPriorities).optional(),
  dueDate: z.coerce.date().nullable().optional(),
});

export const assignTaskInputSchema = taskIdSchema.extend({
  assigneeId: z.string().min(1).nullable(),
});

export const changeTaskStatusInputSchema = taskIdSchema.extend({
  status: z.enum(taskStatuses),
});

export const archiveTaskInputSchema = taskIdSchema;
```

Penjelasan:

- Semua schema task membawa `organizationId` dan `projectId`.
- Detail/update/assign/status/archive juga membawa `taskId`.
- Tidak ada input yang hanya menerima `taskId`.
- `assigneeId: null` berarti unassign task.

## Presentation Router

Buat file `src/server/modules/tasks/presentation/task.router.ts`:

```ts
// src/server/modules/tasks/presentation/task.router.ts
import { TRPCError } from "@trpc/server";
import { createTRPCRouter, protectedProcedure } from "@/server/api/trpc";
import { db } from "@/server/db";
import { TaskService } from "../application/task.service";
import { DefaultTaskStatusTransitionStrategy } from "../infrastructure/default-task-status-transition.strategy";
import { PrismaProjectAccessChecker } from "../infrastructure/prisma-project-access-checker";
import { PrismaTaskRepository } from "../infrastructure/prisma-task.repository";
import {
  archiveTaskInputSchema,
  assignTaskInputSchema,
  changeTaskStatusInputSchema,
  createTaskInputSchema,
  getTaskDetailInputSchema,
  listTasksInputSchema,
  updateTaskInputSchema,
} from "./task.input";

function createTaskService() {
  return new TaskService(
    new PrismaTaskRepository(db),
    new PrismaProjectAccessChecker(db),
    new DefaultTaskStatusTransitionStrategy(),
  );
}

function throwTaskError(error: string, message?: string): never {
  if (error === "MEMBERSHIP_REQUIRED") {
    throw new TRPCError({
      code: "FORBIDDEN",
      message: message ?? "Organization membership is required.",
    });
  }

  if (error === "PROJECT_NOT_FOUND" || error === "TASK_NOT_FOUND") {
    throw new TRPCError({
      code: "NOT_FOUND",
      message: message ?? "Task resource was not found.",
    });
  }

  if (error === "ASSIGNEE_NOT_MEMBER") {
    throw new TRPCError({
      code: "BAD_REQUEST",
      message: message ?? "Assignee must be organization member.",
    });
  }

  if (error === "TASK_ARCHIVED") {
    throw new TRPCError({
      code: "BAD_REQUEST",
      message: message ?? "Archived task cannot be modified.",
    });
  }

  if (error === "TASK_STATUS_TRANSITION_INVALID") {
    throw new TRPCError({
      code: "BAD_REQUEST",
      message: message ?? "Task status transition is not allowed.",
    });
  }

  throw new TRPCError({
    code: "BAD_REQUEST",
    message: message ?? error,
  });
}

export const tasksModuleRouter = createTRPCRouter({
  list: protectedProcedure.input(listTasksInputSchema).query(async ({ ctx, input }) => {
    const taskService = createTaskService();
    const result = await taskService.listTasks({
      actorUserId: ctx.user.id,
      ...input,
    });

    if (!result.ok) {
      throwTaskError(result.error, result.message);
    }

    return result.value;
  }),

  detail: protectedProcedure
    .input(getTaskDetailInputSchema)
    .query(async ({ ctx, input }) => {
      const taskService = createTaskService();
      const result = await taskService.getTaskDetail({
        actorUserId: ctx.user.id,
        ...input,
      });

      if (!result.ok) {
        throwTaskError(result.error, result.message);
      }

      return result.value;
    }),

  create: protectedProcedure
    .input(createTaskInputSchema)
    .mutation(async ({ ctx, input }) => {
      const taskService = createTaskService();
      const result = await taskService.createTask({
        actorUserId: ctx.user.id,
        ...input,
      });

      if (!result.ok) {
        throwTaskError(result.error, result.message);
      }

      return result.value;
    }),

  update: protectedProcedure
    .input(updateTaskInputSchema)
    .mutation(async ({ ctx, input }) => {
      const taskService = createTaskService();
      const result = await taskService.updateTask({
        actorUserId: ctx.user.id,
        ...input,
      });

      if (!result.ok) {
        throwTaskError(result.error, result.message);
      }

      return result.value;
    }),

  assign: protectedProcedure
    .input(assignTaskInputSchema)
    .mutation(async ({ ctx, input }) => {
      const taskService = createTaskService();
      const result = await taskService.assignTask({
        actorUserId: ctx.user.id,
        ...input,
      });

      if (!result.ok) {
        throwTaskError(result.error, result.message);
      }

      return result.value;
    }),

  changeStatus: protectedProcedure
    .input(changeTaskStatusInputSchema)
    .mutation(async ({ ctx, input }) => {
      const taskService = createTaskService();
      const result = await taskService.changeTaskStatus({
        actorUserId: ctx.user.id,
        ...input,
      });

      if (!result.ok) {
        throwTaskError(result.error, result.message);
      }

      return result.value;
    }),

  archive: protectedProcedure
    .input(archiveTaskInputSchema)
    .mutation(async ({ ctx, input }) => {
      const taskService = createTaskService();
      const result = await taskService.archiveTask({
        actorUserId: ctx.user.id,
        ...input,
      });

      if (!result.ok) {
        throwTaskError(result.error, result.message);
      }

      return result.value;
    }),
});
```

Penjelasan:

- Semua procedure memakai `protectedProcedure`.
- Actor selalu berasal dari `ctx.user.id`.
- Router tidak menerima `actorUserId` dari frontend.
- Router tidak berisi Prisma query atau status workflow.

## Expose Router Ke App Router

Buat file `src/server/api/routers/tasks.router.ts`:

```ts
// src/server/api/routers/tasks.router.ts
export { tasksModuleRouter as tasksRouter } from "@/server/modules/tasks/presentation/task.router";
```

Update root router:

```ts
// src/server/api/root.ts
import { createTRPCRouter } from "@/server/api/trpc";
import { healthRouter } from "@/server/api/routers/health";
import { identityRouter } from "@/server/api/routers/identity.router";
import { organizationsRouter } from "@/server/api/routers/organizations.router";
import { tasksRouter } from "@/server/api/routers/tasks.router";

export const appRouter = createTRPCRouter({
  health: healthRouter,
  identity: identityRouter,
  organizations: organizationsRouter,
  tasks: tasksRouter,
});

export type AppRouter = typeof appRouter;
```

## Request Flow

Flow create task:

```txt
Client sends token + organizationId + projectId
  |
  v
protectedProcedure verifies ctx.user
  |
  v
Zod validates input
  |
  v
TaskService.ensureProjectAccess
  |
  v
check actor membership + project belongs to organization
  |
  v
optional check assignee membership
  |
  v
TaskRepository.create with organizationId + projectId
```

Flow task detail:

```txt
ctx.user.id
  |
  v
organizationId + projectId + taskId
  |
  v
membership check
  |
  v
project-in-organization check
  |
  v
find task by organizationId + projectId + taskId
```

Flow status change:

```txt
TaskService.getTaskDetail
  |
  v
DefaultTaskStatusTransitionStrategy.canTransition
  |
  v
TaskRepository.changeStatus
```

## Cara Test Secara Konsep

Jalankan development server:

```bash
npm run dev
```

Penjelasan:

- `npm run dev` menjalankan Next.js development server.
- Semua task procedure butuh token dari `identity.login`.
- Header request protected: `Authorization: Bearer <token>`.

Create task:

```txt
tasks.create
```

Input:

```json
{
  "organizationId": "org_id",
  "projectId": "project_id",
  "title": "Prepare launch checklist",
  "description": "Write backend launch checklist.",
  "priority": "HIGH",
  "assigneeId": null,
  "dueDate": "2026-08-01T00:00:00.000Z"
}
```

List task:

```txt
tasks.list
```

Input:

```json
{
  "organizationId": "org_id",
  "projectId": "project_id",
  "search": "launch",
  "status": "TODO",
  "priority": "HIGH",
  "page": 1,
  "pageSize": 20
}
```

Detail task:

```txt
tasks.detail
```

Input:

```json
{
  "organizationId": "org_id",
  "projectId": "project_id",
  "taskId": "task_id"
}
```

Assign task:

```txt
tasks.assign
```

Input:

```json
{
  "organizationId": "org_id",
  "projectId": "project_id",
  "taskId": "task_id",
  "assigneeId": "user_id"
}
```

Change status:

```txt
tasks.changeStatus
```

Input:

```json
{
  "organizationId": "org_id",
  "projectId": "project_id",
  "taskId": "task_id",
  "status": "IN_PROGRESS"
}
```

Archive task:

```txt
tasks.archive
```

Input:

```json
{
  "organizationId": "org_id",
  "projectId": "project_id",
  "taskId": "task_id"
}
```

## Error Handling

Mapping error yang disarankan:

| Domain error | tRPC code | Arti |
| --- | --- | --- |
| `MEMBERSHIP_REQUIRED` | `FORBIDDEN` | User bukan member organization. |
| `PROJECT_NOT_FOUND` | `NOT_FOUND` | Project tidak ada di organization tersebut. |
| `TASK_NOT_FOUND` | `NOT_FOUND` | Task tidak ditemukan dalam organization + project. |
| `ASSIGNEE_NOT_MEMBER` | `BAD_REQUEST` | Assignee bukan member organization. |
| `TASK_ARCHIVED` | `BAD_REQUEST` | Task archived tidak boleh diubah. |
| `TASK_TITLE_INVALID` | `BAD_REQUEST` | Title tidak valid. |
| `TASK_STATUS_TRANSITION_INVALID` | `BAD_REQUEST` | Perubahan status tidak mengikuti workflow. |

Untuk keamanan tenant, `TASK_NOT_FOUND` lebih aman daripada memberi tahu bahwa task ada tetapi berada di tenant lain.

## Security Notes

- Semua task procedure wajib `protectedProcedure`.
- Jangan menerima `actorUserId` dari frontend.
- Jangan query task hanya dengan `taskId`.
- Selalu gunakan `organizationId + projectId + taskId` untuk detail dan mutation.
- Pastikan project berada dalam organization yang sama.
- Pastikan assignee adalah member organization yang sama.
- Default list sebaiknya tidak menampilkan archived task.
- Status transition harus melewati strategy.
- Billing tidak dibahas di file ini; limit task per plan dibahas di file billing.

## Troubleshooting

### `MEMBERSHIP_REQUIRED`

Cek user login sudah menjadi member organization. Pastikan token valid dan `organizationId` benar.

### `PROJECT_NOT_FOUND`

Project tidak berada di organization tersebut, atau `projectId` salah. Jangan lanjutkan query task jika project check gagal.

### `ASSIGNEE_NOT_MEMBER`

User target belum menjadi member organization. Tambahkan member melalui module organization lebih dulu.

### `TASK_NOT_FOUND`

Cek kombinasi `organizationId`, `projectId`, dan `taskId`. Jangan hanya cek `taskId`.

### Status Transition Ditolak

Cek rule di `DefaultTaskStatusTransitionStrategy`. Misalnya `ARCHIVED` tidak boleh berubah ke status lain lewat endpoint normal.

### Prisma Update Error Pada `where`

Jika Prisma project tidak mendukung filter tambahan di `update.where`, gunakan fallback `updateMany`, lalu fetch ulang task dengan `findById`.

## Checklist Review Task Module

Gunakan checklist ini setiap membuat query task:

- Apakah procedure memakai `protectedProcedure`?
- Apakah actor berasal dari `ctx.user.id`?
- Apakah input membawa `organizationId` dan `projectId`?
- Apakah detail/mutation membawa `organizationId + projectId + taskId`?
- Apakah membership dicek sebelum query task?
- Apakah project dicek berada dalam organization?
- Apakah assignee dicek sebagai member organization?
- Apakah status transition memakai strategy?
- Apakah archived task dikecualikan dari list default?
- Apakah repository tidak punya method `findById(taskId)` saja?

## Output Akhir File Ini

Setelah mengikuti file ini, pembaca harus memahami:

- hubungan Task, Project, dan Organization;
- kenapa task wajib punya `organizationId` dan `projectId`;
- cara menjaga tenant isolation untuk task;
- cara membuat task list dengan pagination dan filter;
- cara create, detail, update, assign, change status, dan archive task;
- cara memakai Strategy Pattern untuk status transition;
- cara membuat protected tRPC router untuk task;
- kenapa query task tidak boleh hanya berdasarkan `taskId`.

## Checklist Berhasil

- [ ] Prisma `Task` punya `organizationId` dan `projectId`.
- [ ] Task punya `assigneeId`, `reporterId`, `status`, `priority`, `dueDate`, dan `archivedAt`.
- [ ] Domain `TaskStatus` dan `TaskPriority` siap.
- [ ] Task repository contract siap.
- [ ] Project access checker siap.
- [ ] Status transition strategy siap.
- [ ] Prisma task repository selalu query dengan `organizationId + projectId`.
- [ ] Task service mengecek membership dan project access.
- [ ] Assignee harus member organization.
- [ ] tRPC router memakai `protectedProcedure`.
- [ ] Semua detail/mutation memakai `organizationId + projectId + taskId`.
- [ ] Pagination, search, status filter, priority filter, dan assignee filter siap.
- [ ] Siap lanjut ke `06-billing-abstract-factory.md`.
