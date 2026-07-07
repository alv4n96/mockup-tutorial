# Backend 02 - Modular Monolith Layers

File ini menjelaskan cara menyusun backend modern SaaS task workspace dengan konsep Modular Monolith dan Layered Architecture di dalam stack `modern-saas-t3-next`.

File sebelumnya, `01-project-setup.md`, sudah menyiapkan fondasi: Next.js App Router, TypeScript, tRPC, Prisma, PostgreSQL, Zod, SuperJSON, TanStack Query, `src/server/api`, `src/server/modules`, `src/server/db.ts`, `src/shared`, dan `src/env.ts`. File ini melanjutkan dari fondasi tersebut dan menjawab pertanyaan berikut: setelah project bisa jalan, bagaimana cara menaruh business logic agar tidak berantakan?

Next.js memungkinkan kita membuat API sangat cepat di satu folder, misalnya langsung menulis query Prisma di `route.ts` atau tRPC router. Itu berguna untuk eksperimen kecil. Namun untuk SaaS enterprise atau SaaS yang akan tumbuh, pola tersebut cepat menjadi sulit dirawat. Semakin banyak fitur seperti identity, organization, project, task, billing, audit log, dan permission, semakin penting boundary antar module dan layer.

Tujuan file ini adalah membuat struktur backend yang tetap praktis untuk startup, tetapi cukup rapi untuk berkembang.

## Apa Itu Modular Monolith

### Monolith Biasa

Monolith biasa adalah aplikasi yang semua fiturnya berjalan dalam satu aplikasi dan satu deployment. Masalahnya bukan pada kata monolith. Masalah muncul ketika semua logic bercampur tanpa batas yang jelas.

Contoh monolith yang mulai bermasalah:

- tRPC router berisi query Prisma, validasi, permission, dan business rule sekaligus.
- Logic task mengambil data organization langsung dari banyak tempat.
- File `route.ts` atau router menjadi terlalu panjang.
- Perubahan kecil di satu fitur mudah merusak fitur lain.
- Testing sulit karena tidak jelas logic utama ada di mana.

### Modular Monolith

Modular Monolith tetap satu aplikasi dan satu deployment, tetapi code di dalamnya dipisah berdasarkan module domain.

Untuk SaaS task workspace, contoh module awal:

- `identity`: user dan identitas akun.
- `organizations`: workspace, membership, role.
- `projects`: project dalam organization.
- `tasks`: task dalam project dan organization.

Setiap module punya folder sendiri, layer sendiri, dan boundary sendiri. Module boleh berkomunikasi, tetapi tidak boleh saling menembus detail internal sembarangan.

### Microservices

Microservices memecah sistem menjadi beberapa service terpisah yang bisa punya deployment, database, dan runtime masing-masing. Microservices berguna untuk organisasi besar atau domain yang benar-benar perlu skala independen.

Namun microservices membawa biaya:

- komunikasi antar service lebih kompleks;
- observability wajib lebih matang;
- debugging lintas service lebih sulit;
- transaksi data lebih rumit;
- deployment dan CI/CD lebih banyak;
- kontrak API antar service harus dijaga ketat.

### Kenapa Modular Monolith Cocok Untuk Awal SaaS

Modular Monolith cocok untuk awal SaaS karena development tetap cepat, deployment tetap sederhana, semua code masih dalam satu repo, boundary domain mulai terbentuk sejak awal, testing lebih mudah, dan jika nanti perlu dipisah, module sudah punya kontrak yang jelas.

Untuk startup dan produk baru, masalah utama biasanya bukan skala service, tetapi mencari product-market fit, membangun fitur dengan cepat, dan menjaga code tetap bisa dirawat.

### Kapan Modular Monolith Mulai Tidak Cukup

Modular Monolith mulai tidak cukup jika satu module punya traffic jauh lebih besar dari module lain, tim berbeda perlu release module secara independen, satu domain butuh runtime khusus, job background berat mengganggu request utama, batas data/compliance mengharuskan pemisahan service, atau deploy satu aplikasi mulai terlalu lambat dan terlalu berisiko.

Saat tanda tersebut muncul, module yang sudah rapi bisa menjadi kandidat service terpisah. Jangan mulai dari microservices sebelum masalahnya nyata.

### Kenapa Jangan Langsung Microservices

Untuk project awal, microservices sering membuat tim membayar kompleksitas terlalu cepat. SaaS task workspace awal lebih membutuhkan model data yang benar, API yang jelas, permission yang aman, dan workflow yang mudah diubah.

Mulai dari Modular Monolith memberi jalur tengah: sederhana untuk dijalankan, tetapi tetap punya disiplin arsitektur.

## Apa Itu Layered Architecture Di Next.js/T3

Layered Architecture adalah cara membagi tanggung jawab code berdasarkan lapisan. Di stack Next.js/T3-style, layer yang dipakai adalah:

- API layer atau tRPC router.
- Application layer atau service use case.
- Domain layer atau entity, value object, dan business rule.
- Infrastructure layer atau Prisma repository dan external service.
- Shared layer atau validation, response, constants, types, dan helper umum.

### API Layer / tRPC Router

API layer adalah pintu masuk request dari client. Di stack ini, API layer biasanya berada di tRPC router.

Tanggung jawab API layer:

- menerima input dari tRPC;
- menjalankan Zod schema validation;
- mengambil context request;
- memanggil service use case;
- mapping hasil service menjadi response API;
- melempar error tRPC jika perlu.

Yang tidak boleh dilakukan di API layer:

- menaruh semua business logic;
- menulis query Prisma panjang;
- menghitung rule domain kompleks;
- mengatur transaksi lintas use case tanpa alasan jelas;
- memanggil provider eksternal langsung jika logic-nya milik module.

Router tRPC sebaiknya tipis. Router adalah adapter transport, bukan tempat utama business logic.

### Application Layer / Service Use Case

Application layer berisi use case aplikasi. Layer ini menjawab pertanyaan: user ingin melakukan apa?

Contoh use case: membuat task, mengubah status task, mengambil daftar task dalam organization, memastikan user boleh mengakses project, dan mencatat audit log setelah aksi penting.

Tanggung jawab application layer:

- mengorkestrasi workflow;
- memanggil repository;
- memanggil domain rule;
- memutuskan urutan operasi;
- mengatur transaction boundary jika dibutuhkan;
- mengembalikan hasil yang stabil ke API layer.

Yang tidak boleh dilakukan di application layer:

- bergantung ke detail HTTP;
- membaca `Request` atau `Response` langsung;
- membuat response tRPC langsung;
- menyebar query Prisma mentah di banyak service;
- menaruh schema input yang spesifik transport jika schema itu hanya untuk tRPC.

### Domain Layer / Entity, Value Object, Business Rule

Domain layer berisi aturan bisnis inti. Layer ini sebaiknya paling sedikit bergantung ke framework.

Contoh domain rule: title task tidak boleh kosong, priority hanya boleh nilai tertentu, atau perubahan status task harus mengikuti policy produk.

Tanggung jawab domain layer:

- menyimpan type domain;
- menyimpan entity atau factory domain;
- menyimpan value object;
- menyimpan business rule murni;
- menjaga invariant domain.

Yang tidak boleh dilakukan di domain layer:

- import Prisma Client;
- import tRPC;
- import Next.js;
- membaca environment variable;
- memanggil API eksternal;
- melakukan query database.

Domain layer harus mudah dites tanpa database dan tanpa server Next.js.

### Infrastructure Layer / Prisma Repository, External Service

Infrastructure layer berisi detail teknis yang menghubungkan aplikasi ke dunia luar.

Contoh: Prisma repository, email provider, payment provider, file storage, analytics, queue, dan cache.

Tanggung jawab infrastructure layer:

- menjalankan query Prisma;
- mapping data database ke bentuk yang dibutuhkan service;
- menyembunyikan detail provider eksternal;
- menyediakan implementasi repository.

Yang tidak boleh dilakukan di infrastructure layer:

- membuat keputusan business rule utama;
- membaca input tRPC langsung;
- membuat error response transport;
- mengandung workflow use case yang panjang.

Prisma query sebaiknya tidak menyebar ke semua file. Jika query tersebar, perubahan schema akan memaksa banyak file berubah dan testing menjadi lebih sulit.

### Shared Layer

Shared layer berisi code yang boleh dipakai lintas module, tetapi harus dijaga agar tidak menjadi tempat buangan semua hal.

Isi shared layer yang masuk akal:

- constants umum;
- error code umum;
- result type;
- pagination helper;
- validation primitive;
- type umum yang tidak bergantung pada detail module.

Yang tidak boleh masuk shared layer:

- business logic spesifik task;
- business logic spesifik organization;
- query Prisma;
- dependency ke tRPC router;
- code yang hanya dipakai satu module tanpa alasan kuat.

## Struktur Folder Target

Struktur target untuk backend:

```txt
src/
├── app/
│   └── api/
│       ├── health/
│       │   └── route.ts
│       └── trpc/
│           └── [trpc]/
│               └── route.ts
│
├── server/
│   ├── api/
│   │   ├── root.ts
│   │   ├── trpc.ts
│   │   └── routers/
│   │       ├── identity.router.ts
│   │       ├── organizations.router.ts
│   │       ├── projects.router.ts
│   │       └── tasks.router.ts
│   │
│   ├── db.ts
│   │
│   └── modules/
│       ├── identity/
│       │   ├── domain/
│       │   ├── application/
│       │   ├── infrastructure/
│       │   └── presentation/
│       │
│       ├── organizations/
│       │   ├── domain/
│       │   ├── application/
│       │   ├── infrastructure/
│       │   └── presentation/
│       │
│       ├── projects/
│       │   ├── domain/
│       │   ├── application/
│       │   ├── infrastructure/
│       │   └── presentation/
│       │
│       └── tasks/
│           ├── domain/
│           ├── application/
│           ├── infrastructure/
│           └── presentation/
│
├── shared/
│   ├── constants/
│   ├── errors/
│   ├── result/
│   ├── pagination/
│   ├── types/
│   └── validation/
│
└── env.ts
```

Penjelasan singkat:

- `src/app/api`: entry point HTTP dari Next.js App Router.
- `src/server/api`: tRPC setup, context, root router, dan router yang diekspos ke API.
- `src/server/modules`: implementasi module domain.
- `domain`: type, entity, value object, dan business rule.
- `application`: service use case.
- `infrastructure`: Prisma repository dan integrasi luar.
- `presentation`: schema input/output dan mapper khusus module.
- `src/shared`: helper lintas module yang benar-benar umum.

## Command Membuat Folder

Jika project baru mengikuti file `01-project-setup.md`, buat folder dengan command berikut dari root project:

```bash
mkdir -p src/server/api/routers
mkdir -p src/server/modules/identity/domain src/server/modules/identity/application src/server/modules/identity/infrastructure src/server/modules/identity/presentation
mkdir -p src/server/modules/organizations/domain src/server/modules/organizations/application src/server/modules/organizations/infrastructure src/server/modules/organizations/presentation
mkdir -p src/server/modules/projects/domain src/server/modules/projects/application src/server/modules/projects/infrastructure src/server/modules/projects/presentation
mkdir -p src/server/modules/tasks/domain src/server/modules/tasks/application src/server/modules/tasks/infrastructure src/server/modules/tasks/presentation
mkdir -p src/shared/constants src/shared/errors src/shared/result src/shared/pagination src/shared/types src/shared/validation
```

Penjelasan command:

- `mkdir` membuat folder.
- `-p` membuat parent folder otomatis dan tidak error jika folder sudah ada.
- Folder dibuat per module agar boundary domain terlihat sejak awal.

Jika memakai PowerShell dan `mkdir -p` tidak tersedia, gunakan:

```powershell
New-Item -ItemType Directory -Force -Path src/server/api/routers
New-Item -ItemType Directory -Force -Path src/server/modules/tasks/domain,src/server/modules/tasks/application,src/server/modules/tasks/infrastructure,src/server/modules/tasks/presentation
New-Item -ItemType Directory -Force -Path src/shared/constants,src/shared/errors,src/shared/result,src/shared/pagination,src/shared/types,src/shared/validation
```

Penjelasan command PowerShell:

- `New-Item -ItemType Directory` membuat folder.
- `-Force` membuat command aman dijalankan ulang jika folder sudah ada.
- Contoh PowerShell di atas menampilkan pola; ulangi untuk module lain jika belum dibuat.

## Aturan Dependency Antar Layer

Aturan dependency yang disarankan:

```txt
Route Handler Next.js
        |
        v
tRPC root/router
        |
        v
module presentation
        |
        v
module application
        |
        v
module domain

module infrastructure -> Prisma/external provider
module application -> infrastructure interface/implementation
shared -> boleh dipakai layer lain jika benar-benar umum
```

Aturan praktis:

- `domain` tidak import `application`, `infrastructure`, `presentation`, tRPC, Prisma, atau Next.js.
- `application` boleh import `domain` dan repository dari `infrastructure`.
- `infrastructure` boleh import Prisma dan `domain` type.
- `presentation` boleh import Zod schema, service, dan tRPC helper.
- `server/api/routers/*.router.ts` hanya menghubungkan root API ke router module.
- `shared` tidak boleh import module spesifik.

## Contoh Implementasi Module Tasks

Bagian ini memakai module `tasks` sebagai contoh lengkap. Module lain mengikuti pola yang sama, tetapi detail auth dan identity akan dibahas di `03-identity-auth.md`.

### Domain: Task Status Dan Priority

Buat file `src/server/modules/tasks/domain/task.enums.ts`:

```ts
// src/server/modules/tasks/domain/task.enums.ts
export const taskStatuses = ["TODO", "IN_PROGRESS", "DONE", "CANCELED"] as const;
export type TaskStatus = (typeof taskStatuses)[number];

export const taskPriorities = ["LOW", "MEDIUM", "HIGH", "URGENT"] as const;
export type TaskPriority = (typeof taskPriorities)[number];
```

File ini berisi enum domain dalam bentuk TypeScript. Nilainya sengaja sama dengan enum Prisma dari file `01-project-setup.md`, tetapi domain tidak import Prisma agar tetap bersih dari detail database.

### Domain: Entity Task

Buat file `src/server/modules/tasks/domain/task.entity.ts`:

```ts
// src/server/modules/tasks/domain/task.entity.ts
import type { TaskPriority, TaskStatus } from "./task.enums";

export type TaskEntity = {
  id: string;
  organizationId: string;
  projectId: string;
  title: string;
  description: string | null;
  status: TaskStatus;
  priority: TaskPriority;
  dueDate: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

export type CreateTaskData = {
  organizationId: string;
  projectId: string;
  title: string;
  description?: string | null;
  priority?: TaskPriority;
  dueDate?: Date | null;
};

export function normalizeTaskTitle(title: string) {
  return title.trim();
}

export function assertValidTaskTitle(title: string) {
  const normalizedTitle = normalizeTaskTitle(title);

  if (normalizedTitle.length < 3) {
    throw new Error("TASK_TITLE_TOO_SHORT");
  }

  if (normalizedTitle.length > 120) {
    throw new Error("TASK_TITLE_TOO_LONG");
  }

  return normalizedTitle;
}
```

Penjelasan:

- `TaskEntity` adalah bentuk task yang dipakai di domain/application.
- `CreateTaskData` adalah data minimal untuk membuat task.
- `assertValidTaskTitle` adalah business rule sederhana.
- Domain boleh throw error domain sederhana, tetapi mapping ke error tRPC dilakukan di layer presentation.

### Presentation: Schema Validation

Buat file `src/server/modules/tasks/presentation/task.schemas.ts`:

```ts
// src/server/modules/tasks/presentation/task.schemas.ts
import { z } from "zod";
import { taskPriorities, taskStatuses } from "../domain/task.enums";

export const listTasksInputSchema = z.object({
  organizationId: z.string().min(1),
  projectId: z.string().min(1).optional(),
  status: z.enum(taskStatuses).optional(),
  page: z.number().int().min(1).default(1),
  pageSize: z.number().int().min(1).max(100).default(20),
});

export const createTaskInputSchema = z.object({
  organizationId: z.string().min(1),
  projectId: z.string().min(1),
  title: z.string().min(3).max(120),
  description: z.string().max(2000).optional(),
  priority: z.enum(taskPriorities).default("MEDIUM"),
  dueDate: z.coerce.date().optional(),
});

export const updateTaskStatusInputSchema = z.object({
  organizationId: z.string().min(1),
  taskId: z.string().min(1),
  status: z.enum(taskStatuses),
});

export type ListTasksInput = z.infer<typeof listTasksInputSchema>;
export type CreateTaskInput = z.infer<typeof createTaskInputSchema>;
export type UpdateTaskStatusInput = z.infer<typeof updateTaskStatusInputSchema>;
```

Schema ini berada di `presentation` karena bentuk input mengikuti kebutuhan API. Untuk schema yang benar-benar umum lintas module, letakkan di `src/shared/validation`.

### Infrastructure: Prisma Repository

Buat file `src/server/modules/tasks/infrastructure/task.repository.ts`:

```ts
// src/server/modules/tasks/infrastructure/task.repository.ts
import type { PrismaClient } from "@prisma/client";
import type { CreateTaskData, TaskEntity } from "../domain/task.entity";
import type { TaskStatus } from "../domain/task.enums";

export type ListTasksQuery = {
  organizationId: string;
  projectId?: string;
  status?: TaskStatus;
  skip: number;
  take: number;
};

export class TaskRepository {
  constructor(private readonly db: PrismaClient) {}

  async list(query: ListTasksQuery): Promise<TaskEntity[]> {
    return this.db.task.findMany({
      where: {
        organizationId: query.organizationId,
        projectId: query.projectId,
        status: query.status,
      },
      orderBy: {
        createdAt: "desc",
      },
      skip: query.skip,
      take: query.take,
    });
  }

  async count(query: Omit<ListTasksQuery, "skip" | "take">): Promise<number> {
    return this.db.task.count({
      where: {
        organizationId: query.organizationId,
        projectId: query.projectId,
        status: query.status,
      },
    });
  }

  async create(data: CreateTaskData): Promise<TaskEntity> {
    return this.db.task.create({
      data: {
        organizationId: data.organizationId,
        projectId: data.projectId,
        title: data.title,
        description: data.description ?? null,
        priority: data.priority ?? "MEDIUM",
        dueDate: data.dueDate ?? null,
      },
    });
  }

  async updateStatus(params: {
    organizationId: string;
    taskId: string;
    status: TaskStatus;
  }): Promise<TaskEntity> {
    return this.db.task.update({
      where: {
        id: params.taskId,
        organizationId: params.organizationId,
      },
      data: {
        status: params.status,
      },
    });
  }
}
```

Repository menyembunyikan Prisma query dari service. Jika nanti schema database berubah, perubahan lebih banyak terjadi di repository, bukan menyebar ke router.

### Shared: Pagination Helper

Buat file `src/shared/pagination/pagination.ts`:

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

Pagination helper layak masuk `shared` karena bisa dipakai banyak module.

### Shared: Result Type

Buat file `src/shared/result/result.ts`:

```ts
// src/shared/result/result.ts
export type AppResult<TValue, TError extends string = string> =
  | {
      ok: true;
      value: TValue;
    }
  | {
      ok: false;
      error: TError;
      message?: string;
    };

export function ok<TValue>(value: TValue): AppResult<TValue, never> {
  return {
    ok: true,
    value,
  };
}

export function err<TError extends string>(
  error: TError,
  message?: string,
): AppResult<never, TError> {
  return {
    ok: false,
    error,
    message,
  };
}
```

Result type membantu service mengembalikan hasil yang konsisten tanpa selalu throw exception. Detail response/error pattern akan dibahas lebih lengkap di `08-code-blueprint-response-error.md`.

### Shared: Error Code

Buat file `src/shared/errors/error-codes.ts`:

```ts
// src/shared/errors/error-codes.ts
export const sharedErrorCodes = {
  NOT_FOUND: "NOT_FOUND",
  FORBIDDEN: "FORBIDDEN",
  VALIDATION_ERROR: "VALIDATION_ERROR",
  INTERNAL_SERVER_ERROR: "INTERNAL_SERVER_ERROR",
} as const;

export type SharedErrorCode =
  (typeof sharedErrorCodes)[keyof typeof sharedErrorCodes];
```

Error code umum boleh masuk shared. Error yang sangat spesifik untuk module bisa tetap berada di module tersebut.

### Application: Task Service

Buat file `src/server/modules/tasks/application/task.service.ts`:

```ts
// src/server/modules/tasks/application/task.service.ts
import { createPaginationMeta, getPagination } from "@/shared/pagination/pagination";
import { err, ok, type AppResult } from "@/shared/result/result";
import { assertValidTaskTitle } from "../domain/task.entity";
import type { TaskEntity } from "../domain/task.entity";
import type { TaskPriority, TaskStatus } from "../domain/task.enums";
import type { TaskRepository } from "../infrastructure/task.repository";

export type ListTasksParams = {
  organizationId: string;
  projectId?: string;
  status?: TaskStatus;
  page: number;
  pageSize: number;
};

export type CreateTaskParams = {
  organizationId: string;
  projectId: string;
  title: string;
  description?: string | null;
  priority?: TaskPriority;
  dueDate?: Date | null;
};

export type UpdateTaskStatusParams = {
  organizationId: string;
  taskId: string;
  status: TaskStatus;
};

export class TaskService {
  constructor(private readonly taskRepository: TaskRepository) {}

  async listTasks(params: ListTasksParams) {
    const pagination = getPagination({
      page: params.page,
      pageSize: params.pageSize,
    });

    const [items, totalItems] = await Promise.all([
      this.taskRepository.list({
        organizationId: params.organizationId,
        projectId: params.projectId,
        status: params.status,
        skip: pagination.skip,
        take: pagination.take,
      }),
      this.taskRepository.count({
        organizationId: params.organizationId,
        projectId: params.projectId,
        status: params.status,
      }),
    ]);

    return {
      items,
      meta: createPaginationMeta({
        page: pagination.page,
        pageSize: pagination.pageSize,
        totalItems,
      }),
    };
  }

  async createTask(
    params: CreateTaskParams,
  ): Promise<AppResult<TaskEntity, "TASK_TITLE_INVALID">> {
    try {
      const title = assertValidTaskTitle(params.title);

      const task = await this.taskRepository.create({
        organizationId: params.organizationId,
        projectId: params.projectId,
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

  async updateTaskStatus(params: UpdateTaskStatusParams) {
    return this.taskRepository.updateStatus(params);
  }
}
```

Service berisi workflow use case. Service tidak tahu request datang dari tRPC, REST, queue, atau test. Ini membuat service lebih mudah dites dan lebih fleksibel.

### Presentation: Factory Service

Buat file `src/server/modules/tasks/presentation/task-service.factory.ts`:

```ts
// src/server/modules/tasks/presentation/task-service.factory.ts
import { db } from "@/server/db";
import { TaskService } from "../application/task.service";
import { TaskRepository } from "../infrastructure/task.repository";

export function createTaskService() {
  const taskRepository = new TaskRepository(db);
  return new TaskService(taskRepository);
}
```

Factory seperti ini sederhana dan cukup untuk awal. Jangan langsung memakai dependency injection container jika belum ada kebutuhan nyata.

### Presentation: tRPC Router Module

Buat file `src/server/modules/tasks/presentation/tasks.router.ts`:

```ts
// src/server/modules/tasks/presentation/tasks.router.ts
import { TRPCError } from "@trpc/server";
import { createTRPCRouter, publicProcedure } from "@/server/api/trpc";
import { createTaskService } from "./task-service.factory";
import {
  createTaskInputSchema,
  listTasksInputSchema,
  updateTaskStatusInputSchema,
} from "./task.schemas";

export const tasksModuleRouter = createTRPCRouter({
  list: publicProcedure.input(listTasksInputSchema).query(async ({ input }) => {
    const taskService = createTaskService();
    return taskService.listTasks(input);
  }),

  create: publicProcedure.input(createTaskInputSchema).mutation(async ({ input }) => {
    const taskService = createTaskService();
    const result = await taskService.createTask(input);

    if (!result.ok) {
      throw new TRPCError({
        code: "BAD_REQUEST",
        message: result.message ?? result.error,
      });
    }

    return result.value;
  }),

  updateStatus: publicProcedure
    .input(updateTaskStatusInputSchema)
    .mutation(async ({ input }) => {
      const taskService = createTaskService();
      return taskService.updateTaskStatus(input);
    }),
});
```

Catatan penting:

- Contoh ini masih memakai `publicProcedure` agar tidak membahas auth terlalu jauh.
- Di file `03-identity-auth.md`, procedure akan dipisah menjadi public/protected procedure.
- Router hanya validasi input, memanggil service, dan mapping error.
- Query Prisma tetap berada di repository.

### API Router Re-export

Buat file `src/server/api/routers/tasks.router.ts`:

```ts
// src/server/api/routers/tasks.router.ts
export { tasksModuleRouter as tasksRouter } from "@/server/modules/tasks/presentation/tasks.router";
```

File ini membuat `src/server/api/routers` menjadi daftar router publik yang diekspos ke `appRouter`. Ini juga menjaga root router tetap pendek.

### Root Router

Update file `src/server/api/root.ts`:

```ts
// src/server/api/root.ts
import { createTRPCRouter } from "@/server/api/trpc";
import { healthRouter } from "@/server/api/routers/health";
import { tasksRouter } from "@/server/api/routers/tasks.router";

export const appRouter = createTRPCRouter({
  health: healthRouter,
  tasks: tasksRouter,
});

export type AppRouter = typeof appRouter;
```

Root router bertindak seperti facade. Client cukup mengenal `appRouter`, sementara detail module tetap berada di folder masing-masing.

## Pola Untuk Module Lain

Module lain mengikuti pola yang sama.

### Identity

Folder:

```txt
src/server/modules/identity/
├── domain/
├── application/
├── infrastructure/
└── presentation/
```

Isi awal yang nanti dibahas di `03-identity-auth.md`:

- domain: user identity type, auth provider type;
- application: get current user, sync user profile;
- infrastructure: repository user, adapter Auth.js;
- presentation: router identity dan schema input.

Jangan bahas password, session, OAuth, dan protected route terlalu dalam di file ini karena itu bagian auth.

### Organizations

Isi awal:

- domain: organization role, membership rule;
- application: create organization, invite member, switch workspace;
- infrastructure: organization repository;
- presentation: organization router dan schema.

Organizations penting karena hampir semua data SaaS task workspace akan punya `organizationId`.

### Projects

Isi awal:

- domain: project entity dan project slug rule;
- application: create project, list project, rename project;
- infrastructure: project repository;
- presentation: project router dan schema.

Project berada di dalam organization.

### Tasks

Isi awal sudah dicontohkan di atas:

- domain: task status, priority, title rule;
- application: create task, list task, update status;
- infrastructure: Prisma task repository;
- presentation: tRPC router dan Zod schema.

## Boundary Antar Module

Boundary adalah aturan agar module tidak saling merusak.

Aturan praktis:

- Module `tasks` boleh menerima `organizationId` dan `projectId`, tetapi tidak boleh mengambil detail auth langsung dari provider.
- Module `projects` tidak boleh mengubah data task langsung tanpa use case yang jelas.
- Module `identity` tidak boleh tahu detail workflow task.
- Module `organizations` menjadi sumber aturan membership dan role.
- Jika satu module membutuhkan data module lain, gunakan service/use case yang jelas, bukan import repository internal sembarangan.

Contoh yang buruk:

```ts
// src/server/modules/tasks/application/bad-example.ts
import { db } from "@/server/db";

export async function createTaskAndUpdateOrganizationName() {
  await db.organization.update({
    where: { id: "org_1" },
    data: { name: "Changed from task module" },
  });
}
```

Masalah contoh buruk:

- task module mengubah organization tanpa boundary;
- business rule organization dilewati;
- sulit diaudit;
- sulit dites.

Contoh yang lebih baik adalah membuat use case di module `organizations`, lalu module lain memanggil contract yang jelas jika memang dibutuhkan.

## tRPC Router Jangan Menjadi God Object

Router tRPC yang buruk biasanya terlihat seperti ini:

```ts
// src/server/modules/tasks/presentation/bad-tasks.router.ts
import { createTRPCRouter, publicProcedure } from "@/server/api/trpc";
import { db } from "@/server/db";

export const badTasksRouter = createTRPCRouter({
  create: publicProcedure.mutation(async () => {
    const project = await db.project.findFirst();

    if (!project) {
      throw new Error("Project not found");
    }

    const task = await db.task.create({
      data: {
        organizationId: project.organizationId,
        projectId: project.id,
        title: "New task",
      },
    });

    await db.auditLog.create({
      data: {
        organizationId: project.organizationId,
        action: "TASK_CREATED",
        entityType: "Task",
        entityId: task.id,
      },
    });

    return task;
  }),
});
```

Masalahnya:

- router melakukan terlalu banyak hal;
- query Prisma menyebar;
- audit logic bercampur dengan API;
- validasi input tidak jelas;
- use case sulit dites tanpa tRPC.

Router yang baik tipis:

```ts
// src/server/modules/tasks/presentation/good-tasks.router.ts
import { createTRPCRouter, publicProcedure } from "@/server/api/trpc";
import { createTaskInputSchema } from "./task.schemas";
import { createTaskService } from "./task-service.factory";

export const goodTasksRouter = createTRPCRouter({
  create: publicProcedure.input(createTaskInputSchema).mutation(async ({ input }) => {
    const taskService = createTaskService();
    return taskService.createTask(input);
  }),
});
```

Di contoh baik, router hanya menerima input, validasi, lalu delegasi ke service.

## Shared Layer Yang Sehat

Shared layer sebaiknya kecil dan stabil. Gunakan shared untuk hal yang benar-benar dipakai lintas module.

Contoh isi `src/shared/constants/app.ts`:

```ts
// src/shared/constants/app.ts
export const appConfig = {
  defaultPageSize: 20,
  maxPageSize: 100,
} as const;
```

Contoh validation primitive di `src/shared/validation/id.ts`:

```ts
// src/shared/validation/id.ts
import { z } from "zod";

export const idSchema = z.string().min(1);
```

Contoh pemakaian di module:

```ts
// src/server/modules/tasks/presentation/task.schemas.ts
import { z } from "zod";
import { idSchema } from "@/shared/validation/id";
import { taskPriorities, taskStatuses } from "../domain/task.enums";

export const createTaskInputSchema = z.object({
  organizationId: idSchema,
  projectId: idSchema,
  title: z.string().min(3).max(120),
  description: z.string().max(2000).optional(),
  priority: z.enum(taskPriorities).default("MEDIUM"),
  dueDate: z.coerce.date().optional(),
});
```

Jangan memasukkan semua schema module ke shared. Jika hanya dipakai task module, tetap simpan di task module.

## Transaction Boundary

Beberapa use case butuh transaction, misalnya membuat task sekaligus audit log. Transaction sebaiknya berada di application layer karena application layer tahu workflow.

Contoh sederhana:

```ts
// src/server/modules/tasks/application/create-task-with-audit.service.ts
import type { PrismaClient } from "@prisma/client";
import { assertValidTaskTitle } from "../domain/task.entity";

export async function createTaskWithAudit(params: {
  db: PrismaClient;
  organizationId: string;
  projectId: string;
  actorUserId?: string;
  title: string;
}) {
  const title = assertValidTaskTitle(params.title);

  return params.db.$transaction(async (tx) => {
    const task = await tx.task.create({
      data: {
        organizationId: params.organizationId,
        projectId: params.projectId,
        title,
      },
    });

    await tx.auditLog.create({
      data: {
        organizationId: params.organizationId,
        actorUserId: params.actorUserId,
        action: "TASK_CREATED",
        entityType: "Task",
        entityId: task.id,
      },
    });

    return task;
  });
}
```

Catatan:

- Contoh ini menunjukkan konsep transaction.
- Untuk codebase besar, transaction bisa tetap dibungkus repository/unit-of-work.
- Audit log detail akan dibahas di file lanjutan.

## Testing Layer

Dokumentasi testing detail ada di file deployment/testing, tetapi struktur layer ini membuat testing lebih mudah.

Prioritas test:

- domain: test business rule murni;
- application: test use case dengan repository mock;
- infrastructure: test repository dengan database test jika diperlukan;
- presentation: test router untuk validasi input dan mapping error.

Contoh domain test secara konsep:

```ts
// src/server/modules/tasks/domain/task.entity.test.ts
import { describe, expect, it } from "vitest";
import { assertValidTaskTitle } from "./task.entity";

describe("assertValidTaskTitle", () => {
  it("trims valid title", () => {
    expect(assertValidTaskTitle("  Prepare release  ")).toBe("Prepare release");
  });

  it("rejects short title", () => {
    expect(() => assertValidTaskTitle("a")).toThrow("TASK_TITLE_TOO_SHORT");
  });
});
```

Jika test package belum dipasang, jangan tambahkan dulu di file ini. Testing setup detail akan dibahas di file khusus.

## Checklist Review Arsitektur

Gunakan checklist ini saat menambah feature baru:

- Apakah tRPC router hanya berisi input validation, context, service call, dan error mapping?
- Apakah business logic utama berada di application/domain layer?
- Apakah Prisma query terkumpul di infrastructure repository?
- Apakah domain layer bebas dari import Prisma, tRPC, dan Next.js?
- Apakah schema Zod berada dekat dengan boundary input?
- Apakah shared layer hanya berisi hal yang benar-benar umum?
- Apakah module lain tidak mengubah data internal module ini sembarangan?
- Apakah nama folder dan file membuat tanggung jawab mudah ditebak?

## Kesalahan Umum

### Semua Logic Di Router

Gejala:

- file router ratusan baris;
- banyak `db.*` langsung di procedure;
- sulit menulis unit test.

Solusi:

- pindahkan workflow ke service;
- pindahkan query ke repository;
- router cukup menjadi adapter tRPC.

### Shared Menjadi Folder Sampah

Gejala:

- semua helper masuk shared;
- shared import module spesifik;
- perubahan satu module merusak module lain.

Solusi:

- simpan logic spesifik di module;
- shared hanya untuk primitive umum;
- pindahkan helper kembali ke module jika hanya dipakai satu module.

### Domain Import Prisma

Gejala:

- domain entity import `@prisma/client`;
- domain test butuh database;
- business rule sulit dipakai ulang.

Solusi:

- buat type domain sendiri;
- mapping Prisma dilakukan di repository;
- domain tetap framework-agnostic.

### Repository Berisi Business Logic Berat

Gejala:

- repository menentukan user boleh melakukan aksi atau tidak;
- repository mengatur workflow panjang;
- repository memanggil banyak module lain.

Solusi:

- repository hanya data access;
- permission dan workflow pindah ke application service;
- domain rule pindah ke domain layer.

## Output Akhir File Ini

Setelah mengikuti file ini, pembaca harus memahami:

- apa itu Modular Monolith;
- beda monolith biasa, modular monolith, dan microservices;
- kenapa Modular Monolith cocok untuk awal SaaS;
- layer yang dipakai di Next.js/T3-style backend;
- tanggung jawab API, application, domain, infrastructure, dan shared layer;
- struktur folder target untuk `identity`, `organizations`, `projects`, dan `tasks`;
- cara membuat pola module `tasks` dengan router, schema, service, repository, dan domain rule;
- kenapa tRPC router harus tipis;
- kenapa Prisma query sebaiknya tidak menyebar;
- cara menjaga shared layer tetap sehat.

## Checklist Berhasil

- [ ] Struktur folder module sudah jelas.
- [ ] Setiap module punya `domain`, `application`, `infrastructure`, dan `presentation`.
- [ ] `src/server/api/routers` hanya mengekspos router module.
- [ ] `appRouter` menjadi facade API utama.
- [ ] tRPC router tidak berisi business logic berat.
- [ ] Service berisi use case aplikasi.
- [ ] Repository berisi Prisma query.
- [ ] Domain layer bebas dari Next.js, tRPC, dan Prisma.
- [ ] Shared layer hanya berisi helper lintas module.
- [ ] Siap lanjut ke `03-identity-auth.md`.
