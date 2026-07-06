# 00 - Belajar Pemrograman Dari Nol Sampai Project Full Stack

Dokumen ini dibuat sebagai pintu masuk untuk orang yang baru pertama belajar pemrograman. Materi lain di repository ini tetap berguna, tetapi sebagian sudah langsung masuk ke istilah seperti modular monolith, RBAC, repository, DTO, dan deployment. Di sini urutannya dibuat lebih pelan: pilih project, buat backend, test API, lalu buat frontend.

Target akhirnya adalah aplikasi kecil bernama `Task Workspace`:

- user bisa melihat daftar task;
- user bisa membuat task baru;
- backend menyimpan data ke database;
- frontend memanggil backend lewat HTTP API;
- struktur file sudah disiapkan agar nanti bisa naik ke materi modular monolith yang lebih lengkap.

## 1. Peta File Di Repository Ini

Setelah membaca struktur repository, materi yang ada bisa dipakai seperti ini:

| Area | Kapan Dibaca | Isi |
| --- | --- | --- |
| [README.md](../../README.md) | Awal | Peta besar repository, branch, command Git, dan kontrak API lintas stack. |
| [docs/tutorials/14-step-by-step-programming-flow.md](14-step-by-step-programming-flow.md) | Setelah dokumen ini | Urutan coding yang lebih lengkap dari database, RBAC, domain, repository, use case, controller/router, sampai frontend. |
| [docs/stacks/typescript-vue-nest/README.md](../stacks/typescript-vue-nest/README.md) | Saat memilih jalur TypeScript terpisah | Backend NestJS, frontend Vue, dan blueprint code. |
| [docs/stacks/modern-saas-t3-next/README.md](../stacks/modern-saas-t3-next/README.md) | Setelah paham dasar backend/frontend | Jalur Next.js/T3 untuk SaaS modern. |
| [docs/stacks/enterprise-dotnet-spring/README.md](../stacks/enterprise-dotnet-spring/README.md) | Setelah paham dasar atau butuh enterprise | Jalur .NET atau Spring Boot. |
| [docs/stacks/shared/README.md](../stacks/shared/README.md) | Saat mulai merapikan API | Response envelope, error, DTO, pagination, module contract, dan RBAC. |
| [docs/kolaborasi-github.md](../kolaborasi-github.md) | Saat mulai commit dan kerja tim | Workflow GitHub, branch, commit, pull request. |
| `mock-history/`, `scripts/mock-history/`, `scripts/mock-history-sh/` | Tidak perlu untuk belajar coding pertama | File generated untuk simulasi aktivitas Git. |

## 2. Pilihan Untuk Memulai Project

Untuk pemula, jangan mulai dari semua stack sekaligus. Pilih satu.

| Pilihan | Backend | Frontend | Cocok Jika |
| --- | --- | --- | --- |
| A. Rekomendasi pemula | NestJS + Prisma + SQLite | Vue 3 + Vite | Ingin belajar backend dan frontend terpisah dengan satu bahasa, yaitu TypeScript. |
| B. Modern SaaS | Next.js/T3 + Prisma/PostgreSQL | Next.js React | Ingin satu project full stack yang cepat, tetapi konsep backend/frontend sedikit bercampur. |
| C. Enterprise | .NET atau Spring Boot | Angular atau React | Ingin jalur perusahaan besar, tetapi ini lebih berat untuk hari pertama belajar. |

Jalur yang dipakai di dokumen ini adalah pilihan A: `NestJS + Prisma + SQLite + Vue 3`. Alasannya:

- backend dan frontend terlihat jelas sebagai dua aplikasi berbeda;
- tetap memakai TypeScript seperti banyak blueprint di repository ini;
- SQLite tidak butuh install database server;
- nanti mudah naik ke PostgreSQL, RBAC, dan struktur modular monolith.

## 3. Yang Perlu Diinstall

Minimal:

```powershell
node -v
npm -v
git --version
```

Jika belum ada:

- install Node.js LTS;
- install Git;
- install Visual Studio Code;
- install ekstensi VS Code untuk TypeScript, Vue, dan Prisma.

## 4. Cara Berpikir Full Stack

Sebelum mengetik code, pahami alur ini:

```text
User membuka website
  -> Vue menampilkan halaman
  -> Vue memanggil API backend dengan fetch
  -> NestJS menerima request
  -> Use case menjalankan aturan bisnis
  -> Repository menyimpan/membaca database
  -> Backend mengirim response JSON
  -> Vue menampilkan hasil
```

Nama file akan mengikuti tanggung jawabnya:

| Jenis File | Tugas |
| --- | --- |
| `schema.prisma` | Mendesain tabel database. |
| `seed.ts` | Mengisi data awal untuk belajar. |
| `controller` | Menerima HTTP request. |
| `use-case` | Menjalankan alur bisnis. |
| `entity` | Menjaga aturan data inti. |
| `repository` | Bicara dengan database. |
| `api client` | Frontend memanggil backend. |
| `composable` | Frontend menyimpan loading, error, dan data. |
| `component` | Frontend menampilkan form dan list. |

## 5. Buat Folder Project

```powershell
mkdir beginner-task-workspace
cd beginner-task-workspace
git init
```

Struktur akhirnya:

```text
beginner-task-workspace/
  workspace-api/
  workspace-web/
```

## 6. Buat Backend NestJS

```powershell
npm i -g @nestjs/cli
nest new workspace-api
cd workspace-api
npm install @prisma/client class-validator class-transformer
npm install -D prisma tsx
npx prisma init --datasource-provider sqlite
```

Edit `.env`:

```env
DATABASE_URL="file:./dev.db"
```

## 7. Backend File 1 - `prisma/schema.prisma`

Ganti isi `prisma/schema.prisma`:

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String
  createdAt DateTime @default(now())

  memberships OrganizationMember[]
  assignedTasks Task[] @relation("TaskAssignee")
}

model Organization {
  id        String   @id @default(cuid())
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
  id             String   @id @default(cuid())
  organizationId String
  name           String
  createdAt      DateTime @default(now())

  organization Organization @relation(fields: [organizationId], references: [id])
  tasks        Task[]
}

model Task {
  id             String   @id @default(cuid())
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
  assignee     User?        @relation("TaskAssignee", fields: [assigneeUserId], references: [id])

  @@index([organizationId])
  @@index([projectId])
  @@index([assigneeUserId])
}
```

Penjelasan singkat:

- `User` adalah pengguna.
- `Organization` adalah workspace/tenant.
- `OrganizationMember` menghubungkan user ke organization dan menyimpan role.
- `Project` adalah tempat task dikelompokkan.
- `Task` adalah fitur utama yang akan dibuat.

Jalankan migration:

```powershell
npx prisma migrate dev --name init
```

## 8. Backend File 2 - `prisma/seed.ts`

Buat `prisma/seed.ts`:

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

  await prisma.project.upsert({
    where: { id: "project_demo" },
    update: {},
    create: {
      id: "project_demo",
      organizationId: "org_demo",
      name: "Belajar Full Stack",
    },
  });
}

main()
  .then(() => {
    console.log("Seed selesai.");
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
```

Jalankan:

```powershell
npx tsx prisma/seed.ts
```

## 9. Backend File 3 - `src/prisma/prisma.service.ts`

Buat folder `src/prisma`, lalu buat `src/prisma/prisma.service.ts`:

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

## 10. Backend File 4 - `src/prisma/prisma.module.ts`

Buat `src/prisma/prisma.module.ts`:

```ts
import { Global, Module } from "@nestjs/common";
import { PrismaService } from "./prisma.service";

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
```

`@Global()` membuat `PrismaService` bisa dipakai module lain tanpa import berulang.

## 11. Backend File 5 - `src/shared/api/api-response.ts`

Buat folder `src/shared/api`, lalu buat file:

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

export function apiSuccess<T>(data: T, status = 200): ApiResponse<T> {
  return { data, error: null, status };
}

export function apiFail(error: ApiError, status: number): ApiResponse<null> {
  return { data: null, error, status };
}
```

Tujuannya agar response backend selalu konsisten.

## 12. Backend File 6 - `src/shared/errors/app-error.ts`

Buat folder `src/shared/errors`, lalu buat file:

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

export class ForbiddenAppError extends AppError {
  constructor(message = "Forbidden") {
    super("FORBIDDEN", message, 403);
  }
}

export class ValidationAppError extends AppError {
  constructor(code: string, message: string, details?: unknown) {
    super(code, message, 400, details);
  }
}
```

`AppError` dipakai untuk error yang memang sudah diprediksi aplikasi.

## 13. Backend File 7 - `src/shared/errors/http-exception.filter.ts`

Buat file:

```ts
import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from "@nestjs/common";
import { Response } from "express";
import { apiFail } from "../api/api-response";
import { AppError } from "./app-error";

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const response = host.switchToHttp().getResponse<Response>();

    if (exception instanceof AppError) {
      response.status(exception.status).json(
        apiFail(
          {
            code: exception.code,
            message: exception.message,
            details: exception.details,
          },
          exception.status
        )
      );
      return;
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      response.status(status).json(
        apiFail(
          {
            code: status === 404 ? "NOT_FOUND" : "HTTP_ERROR",
            message: exception.message,
          },
          status
        )
      );
      return;
    }

    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json(
      apiFail(
        {
          code: "INTERNAL_ERROR",
          message: "Unexpected server error",
        },
        HttpStatus.INTERNAL_SERVER_ERROR
      )
    );
  }
}
```

Filter ini mengubah error menjadi JSON yang bisa dibaca frontend.

## 14. Backend File 8 - `src/shared/interceptors/api-response.interceptor.ts`

Buat folder `src/shared/interceptors`, lalu buat file:

```ts
import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from "@nestjs/common";
import { map } from "rxjs/operators";
import { apiSuccess } from "../api/api-response";

@Injectable()
export class ApiResponseInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler) {
    const status = context.switchToHttp().getResponse().statusCode;
    return next.handle().pipe(map((data) => apiSuccess(data, status)));
  }
}
```

Interceptor ini membungkus semua hasil controller menjadi `{ data, error, status }`.

## 15. Backend File 9 - `src/modules/organizations/application/organization-role.ts`

Buat folder `src/modules/organizations/application`, lalu buat file:

```ts
export type OrganizationRole = "owner" | "admin" | "member" | "viewer";

export type Permission = "task:read" | "task:create";

const rolePermissions: Record<OrganizationRole, Permission[]> = {
  owner: ["task:read", "task:create"],
  admin: ["task:read", "task:create"],
  member: ["task:read", "task:create"],
  viewer: ["task:read"],
};

export function roleCan(role: OrganizationRole, permission: Permission): boolean {
  return rolePermissions[role].includes(permission);
}
```

Ini versi RBAC paling kecil: viewer boleh baca, tetapi tidak boleh membuat task.

## 16. Backend File 10 - `src/modules/organizations/application/organization-access-reader.ts`

Buat file:

```ts
import type { OrganizationRole } from "./organization-role";

export type OrganizationMembership = {
  organizationId: string;
  userId: string;
  role: OrganizationRole;
};

export abstract class OrganizationAccessReader {
  abstract getMembership(input: {
    organizationId: string;
    userId: string;
  }): Promise<OrganizationMembership | null>;
}
```

Use case akan memakai contract ini tanpa peduli database-nya Prisma, TypeORM, atau yang lain.

## 17. Backend File 11 - `src/modules/organizations/infrastructure/prisma-organization-access-reader.ts`

Buat folder `src/modules/organizations/infrastructure`, lalu buat file:

```ts
import { Injectable } from "@nestjs/common";
import { PrismaService } from "../../../prisma/prisma.service";
import {
  OrganizationAccessReader,
  OrganizationMembership,
} from "../application/organization-access-reader";
import type { OrganizationRole } from "../application/organization-role";

@Injectable()
export class PrismaOrganizationAccessReader extends OrganizationAccessReader {
  constructor(private readonly prisma: PrismaService) {
    super();
  }

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

File ini membaca role user dari database.

## 18. Backend File 12 - `src/modules/tasks/domain/task.entity.ts`

Buat folder `src/modules/tasks/domain`, lalu buat file:

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
      input.description?.trim() || null,
      "todo",
      input.assigneeUserId || null,
      new Date()
    );
  }
}
```

Entity menjaga aturan inti: judul task minimal 3 karakter.

## 19. Backend File 13 - `src/modules/tasks/application/task.repository.ts`

Buat folder `src/modules/tasks/application`, lalu buat file:

```ts
import { TaskEntity } from "../domain/task.entity";

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

export abstract class TaskRepository {
  abstract save(task: TaskEntity): Promise<void>;

  abstract listByOrganization(input: {
    organizationId: string;
    page: number;
    pageSize: number;
  }): Promise<TaskDto[]>;
}
```

DTO adalah bentuk data yang aman dikirim ke frontend.

## 20. Backend File 14 - `src/modules/tasks/infrastructure/prisma-task.repository.ts`

Buat folder `src/modules/tasks/infrastructure`, lalu buat file:

```ts
import { Injectable } from "@nestjs/common";
import { PrismaService } from "../../../prisma/prisma.service";
import { TaskRepository, TaskDto } from "../application/task.repository";
import { TaskEntity } from "../domain/task.entity";

@Injectable()
export class PrismaTaskRepository extends TaskRepository {
  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async save(task: TaskEntity): Promise<void> {
    await this.prisma.task.create({
      data: {
        id: task.id,
        organizationId: task.organizationId,
        projectId: task.projectId,
        title: task.title,
        description: task.description,
        status: task.status,
        assigneeUserId: task.assigneeUserId,
        createdAt: task.createdAt,
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

Repository adalah satu-satunya file task yang bicara langsung dengan Prisma.

## 21. Backend File 15 - `src/modules/tasks/application/create-task.use-case.ts`

Buat file:

```ts
import { randomUUID } from "crypto";
import { Injectable } from "@nestjs/common";
import { OrganizationAccessReader } from "../../organizations/application/organization-access-reader";
import { roleCan } from "../../organizations/application/organization-role";
import { ForbiddenAppError } from "../../../shared/errors/app-error";
import { TaskEntity } from "../domain/task.entity";
import { TaskDto, TaskRepository } from "./task.repository";

export type CreateTaskInput = {
  currentUserId: string;
  organizationId: string;
  projectId: string;
  title: string;
  description?: string;
  assigneeUserId?: string;
};

@Injectable()
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

    if (!membership) {
      throw new ForbiddenAppError("You are not a member of this organization.");
    }

    if (!roleCan(membership.role, "task:create")) {
      throw new ForbiddenAppError("You do not have permission to create tasks.");
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
      description: task.description,
      status: task.status,
      assigneeUserId: task.assigneeUserId,
      createdAt: task.createdAt.toISOString(),
    };
  }
}
```

Use case adalah pusat alur: cek membership, cek permission, buat entity, simpan database.

## 22. Backend File 16 - `src/modules/tasks/application/list-tasks.use-case.ts`

Buat file:

```ts
import { Injectable } from "@nestjs/common";
import { OrganizationAccessReader } from "../../organizations/application/organization-access-reader";
import { roleCan } from "../../organizations/application/organization-role";
import { ForbiddenAppError } from "../../../shared/errors/app-error";
import { TaskDto, TaskRepository } from "./task.repository";

export type ListTasksInput = {
  currentUserId: string;
  organizationId: string;
  page: number;
  pageSize: number;
};

@Injectable()
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

    if (!membership) {
      throw new ForbiddenAppError("You are not a member of this organization.");
    }

    if (!roleCan(membership.role, "task:read")) {
      throw new ForbiddenAppError("You do not have permission to read tasks.");
    }

    return this.tasks.listByOrganization({
      organizationId: input.organizationId,
      page: input.page,
      pageSize: input.pageSize,
    });
  }
}
```

List juga tetap cek permission. Frontend tidak boleh menjadi sumber kebenaran izin.

## 23. Backend File 17 - `src/modules/tasks/presentation/create-task.dto.ts`

Buat folder `src/modules/tasks/presentation`, lalu buat file:

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

DTO memvalidasi input dari HTTP request.

## 24. Backend File 18 - `src/modules/tasks/presentation/tasks.controller.ts`

Buat file:

```ts
import { Body, Controller, Get, Headers, Param, Post, Query } from "@nestjs/common";
import { ValidationAppError } from "../../../shared/errors/app-error";
import { CreateTaskUseCase } from "../application/create-task.use-case";
import { ListTasksUseCase } from "../application/list-tasks.use-case";
import { CreateTaskDto } from "./create-task.dto";

@Controller("/api/organizations/:organizationId/tasks")
export class TasksController {
  constructor(
    private readonly createTask: CreateTaskUseCase,
    private readonly listTasks: ListTasksUseCase
  ) {}

  @Post()
  async create(
    @Param("organizationId") organizationId: string,
    @Headers("x-user-id") currentUserId: string | undefined,
    @Body() body: CreateTaskDto
  ) {
    return this.createTask.execute({
      currentUserId: this.requireUserId(currentUserId),
      organizationId,
      projectId: body.projectId,
      title: body.title,
      description: body.description,
      assigneeUserId: body.assigneeUserId,
    });
  }

  @Get()
  async list(
    @Param("organizationId") organizationId: string,
    @Headers("x-user-id") currentUserId: string | undefined,
    @Query("page") page = "1",
    @Query("pageSize") pageSize = "20"
  ) {
    return this.listTasks.execute({
      currentUserId: this.requireUserId(currentUserId),
      organizationId,
      page: Number(page),
      pageSize: Number(pageSize),
    });
  }

  private requireUserId(currentUserId: string | undefined) {
    if (!currentUserId) {
      throw new ValidationAppError(
        "MISSING_USER_ID",
        "Send x-user-id header for this beginner tutorial."
      );
    }

    return currentUserId;
  }
}
```

Untuk tutorial awal, login disederhanakan menjadi header `x-user-id`. Nanti ini bisa diganti JWT/session.

## 25. Backend File 19 - `src/modules/tasks/tasks.module.ts`

Buat file:

```ts
import { Module } from "@nestjs/common";
import { OrganizationAccessReader } from "../organizations/application/organization-access-reader";
import { PrismaOrganizationAccessReader } from "../organizations/infrastructure/prisma-organization-access-reader";
import { CreateTaskUseCase } from "./application/create-task.use-case";
import { ListTasksUseCase } from "./application/list-tasks.use-case";
import { TaskRepository } from "./application/task.repository";
import { PrismaTaskRepository } from "./infrastructure/prisma-task.repository";
import { TasksController } from "./presentation/tasks.controller";

@Module({
  controllers: [TasksController],
  providers: [
    CreateTaskUseCase,
    ListTasksUseCase,
    { provide: TaskRepository, useClass: PrismaTaskRepository },
    { provide: OrganizationAccessReader, useClass: PrismaOrganizationAccessReader },
  ],
})
export class TasksModule {}
```

Module menghubungkan controller, use case, dan repository.

## 26. Backend File 20 - `src/app.module.ts`

Ganti isi `src/app.module.ts`:

```ts
import { Module } from "@nestjs/common";
import { PrismaModule } from "./prisma/prisma.module";
import { TasksModule } from "./modules/tasks/tasks.module";

@Module({
  imports: [PrismaModule, TasksModule],
})
export class AppModule {}
```

## 27. Backend File 21 - `src/main.ts`

Ganti isi `src/main.ts`:

```ts
import { ValidationPipe } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";
import { HttpExceptionFilter } from "./shared/errors/http-exception.filter";
import { ApiResponseInterceptor } from "./shared/interceptors/api-response.interceptor";

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.enableCors({
    origin: "http://localhost:5173",
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
    })
  );

  app.useGlobalFilters(new HttpExceptionFilter());
  app.useGlobalInterceptors(new ApiResponseInterceptor());

  await app.listen(3000);
}

bootstrap();
```

Jalankan backend:

```powershell
npm run start:dev
```

## 28. Test Backend Manual

Buka terminal baru di folder `workspace-api`, lalu test list task:

```powershell
curl.exe "http://localhost:3000/api/organizations/org_demo/tasks" `
  -H "x-user-id: user_owner"
```

Test create task:

```powershell
curl.exe -X POST "http://localhost:3000/api/organizations/org_demo/tasks" `
  -H "Content-Type: application/json" `
  -H "x-user-id: user_owner" `
  --data "{""projectId"":""project_demo"",""title"":""Belajar full stack"",""description"":""Dibuat dari curl""}"
```

Jika berhasil, response kira-kira seperti ini:

```json
{
  "data": {
    "id": "generated-id",
    "organizationId": "org_demo",
    "projectId": "project_demo",
    "title": "Belajar full stack",
    "description": "Dibuat dari curl",
    "status": "todo",
    "assigneeUserId": null,
    "createdAt": "2026-07-06T00:00:00.000Z"
  },
  "error": null,
  "status": 201
}
```

## 29. Buat Frontend Vue

Dari folder `beginner-task-workspace`:

```powershell
npm create vite@latest workspace-web -- --template vue-ts
cd workspace-web
npm install
```

Buat `.env`:

```env
VITE_API_BASE_URL=http://localhost:3000
```

## 30. Frontend File 1 - `src/shared/api/api-response.ts`

Buat folder `src/shared/api`, lalu buat file:

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
```

Frontend harus tahu bentuk response backend.

## 31. Frontend File 2 - `src/features/tasks/api/task-api.ts`

Buat folder `src/features/tasks/api`, lalu buat file:

```ts
import type { ApiResponse } from "../../../shared/api/api-response";

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000";
const DEMO_USER_ID = "user_owner";

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
};

export async function listTasks(
  organizationId: string
): Promise<ApiResponse<TaskDto[]>> {
  const response = await fetch(
    `${API_BASE_URL}/api/organizations/${organizationId}/tasks`,
    {
      headers: {
        "x-user-id": DEMO_USER_ID,
      },
    }
  );

  return response.json();
}

export async function createTask(
  organizationId: string,
  input: CreateTaskInput
): Promise<ApiResponse<TaskDto>> {
  const response = await fetch(
    `${API_BASE_URL}/api/organizations/${organizationId}/tasks`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-user-id": DEMO_USER_ID,
      },
      body: JSON.stringify(input),
    }
  );

  return response.json();
}
```

File ini adalah jembatan frontend ke backend.

## 32. Frontend File 3 - `src/features/tasks/composables/use-tasks.ts`

Buat folder `src/features/tasks/composables`, lalu buat file:

```ts
import { ref } from "vue";
import {
  createTask,
  listTasks,
  type CreateTaskInput,
  type TaskDto,
} from "../api/task-api";

export function useTasks(organizationId: string) {
  const tasks = ref<TaskDto[]>([]);
  const loading = ref(false);
  const error = ref("");

  async function load() {
    loading.value = true;
    error.value = "";

    try {
      const response = await listTasks(organizationId);

      tasks.value = response.data ?? [];
      error.value = response.error?.message ?? "";
    } catch {
      error.value = "Cannot connect to backend.";
    } finally {
      loading.value = false;
    }
  }

  async function create(input: CreateTaskInput) {
    loading.value = true;
    error.value = "";

    try {
      const response = await createTask(organizationId, input);

      if (response.error) {
        error.value = response.error.message;
        return null;
      }

      await load();
      return response.data;
    } catch {
      error.value = "Cannot connect to backend.";
      return null;
    } finally {
      loading.value = false;
    }
  }

  return { tasks, loading, error, load, create };
}
```

Composable menyimpan state yang dibutuhkan UI: data, loading, error, dan function.

## 33. Frontend File 4 - `src/features/tasks/components/CreateTaskForm.vue`

Buat folder `src/features/tasks/components`, lalu buat file:

```vue
<script setup lang="ts">
import { ref } from "vue";
import { useTasks } from "../composables/use-tasks";

const props = defineProps<{
  organizationId: string;
  projectId: string;
}>();

const emit = defineEmits<{
  created: [];
}>();

const title = ref("");
const description = ref("");
const { create, loading, error } = useTasks(props.organizationId);

async function submit() {
  const task = await create({
    projectId: props.projectId,
    title: title.value,
    description: description.value,
  });

  if (!task) return;

  title.value = "";
  description.value = "";
  emit("created");
}
</script>

<template>
  <form class="task-form" @submit.prevent="submit">
    <label>
      Title
      <input v-model="title" placeholder="Contoh: Belajar API" />
    </label>

    <label>
      Description
      <textarea v-model="description" placeholder="Catatan tambahan" />
    </label>

    <p v-if="error" class="error">{{ error }}</p>

    <button type="submit" :disabled="loading">
      {{ loading ? "Saving..." : "Create task" }}
    </button>
  </form>
</template>
```

Form mengambil input user, lalu memanggil composable.

## 34. Frontend File 5 - `src/features/tasks/components/TaskList.vue`

Buat file:

```vue
<script setup lang="ts">
import type { TaskDto } from "../api/task-api";

defineProps<{
  tasks: TaskDto[];
  loading: boolean;
  error: string;
}>();
</script>

<template>
  <section>
    <p v-if="loading">Loading tasks...</p>
    <p v-else-if="error" class="error">{{ error }}</p>
    <p v-else-if="tasks.length === 0">No tasks yet.</p>

    <ul v-else class="task-list">
      <li v-for="task in tasks" :key="task.id">
        <strong>{{ task.title }}</strong>
        <span>{{ task.status }}</span>
        <p v-if="task.description">{{ task.description }}</p>
      </li>
    </ul>
  </section>
</template>
```

List hanya menerima data dan menampilkannya.

## 35. Frontend File 6 - `src/App.vue`

Ganti isi `src/App.vue`:

```vue
<script setup lang="ts">
import { onMounted } from "vue";
import CreateTaskForm from "./features/tasks/components/CreateTaskForm.vue";
import TaskList from "./features/tasks/components/TaskList.vue";
import { useTasks } from "./features/tasks/composables/use-tasks";

const organizationId = "org_demo";
const projectId = "project_demo";
const { tasks, loading, error, load } = useTasks(organizationId);

onMounted(load);
</script>

<template>
  <main class="page">
    <header>
      <p class="eyebrow">Beginner Full Stack</p>
      <h1>Task Workspace</h1>
      <p>Backend NestJS, database SQLite, frontend Vue.</p>
    </header>

    <CreateTaskForm
      :organization-id="organizationId"
      :project-id="projectId"
      @created="load"
    />

    <TaskList :tasks="tasks" :loading="loading" :error="error" />
  </main>
</template>
```

`App.vue` menyatukan form dan list.

## 36. Frontend File 7 - `src/main.ts`

Ganti isi `src/main.ts`:

```ts
import { createApp } from "vue";
import "./style.css";
import App from "./App.vue";

createApp(App).mount("#app");
```

## 37. Frontend File 8 - `src/style.css`

Ganti isi `src/style.css`:

```css
:root {
  font-family: Arial, sans-serif;
  color: #172026;
  background: #f4f7f6;
}

body {
  margin: 0;
}

button,
input,
textarea {
  font: inherit;
}

.page {
  width: min(760px, calc(100% - 32px));
  margin: 40px auto;
}

.eyebrow {
  margin: 0 0 8px;
  color: #2f6f73;
  font-size: 14px;
  font-weight: 700;
  text-transform: uppercase;
}

h1 {
  margin: 0 0 8px;
}

.task-form {
  display: grid;
  gap: 12px;
  margin: 24px 0;
  padding: 16px;
  background: #ffffff;
  border: 1px solid #dce5e2;
  border-radius: 8px;
}

label {
  display: grid;
  gap: 6px;
  font-weight: 700;
}

input,
textarea {
  width: 100%;
  box-sizing: border-box;
  padding: 10px;
  border: 1px solid #b8c7c2;
  border-radius: 6px;
}

textarea {
  min-height: 96px;
  resize: vertical;
}

button {
  justify-self: start;
  padding: 10px 14px;
  color: #ffffff;
  background: #2f6f73;
  border: 0;
  border-radius: 6px;
  cursor: pointer;
}

button:disabled {
  cursor: not-allowed;
  opacity: 0.65;
}

.error {
  color: #a53030;
}

.task-list {
  display: grid;
  gap: 10px;
  padding: 0;
  list-style: none;
}

.task-list li {
  padding: 14px;
  background: #ffffff;
  border: 1px solid #dce5e2;
  border-radius: 8px;
}

.task-list span {
  display: inline-block;
  margin-left: 8px;
  color: #52615d;
  font-size: 13px;
}
```

## 38. Jalankan Full Stack

Terminal 1:

```powershell
cd beginner-task-workspace\workspace-api
npm run start:dev
```

Terminal 2:

```powershell
cd beginner-task-workspace\workspace-web
npm run dev
```

Buka:

```text
http://localhost:5173
```

Coba buat task dari form. Jika backend dan frontend benar, task baru muncul di list.

## 39. Urutan File Yang Baru Saja Dibuat

Backend:

```text
workspace-api/
  prisma/schema.prisma
  prisma/seed.ts
  src/prisma/prisma.service.ts
  src/prisma/prisma.module.ts
  src/shared/api/api-response.ts
  src/shared/errors/app-error.ts
  src/shared/errors/http-exception.filter.ts
  src/shared/interceptors/api-response.interceptor.ts
  src/modules/organizations/application/organization-role.ts
  src/modules/organizations/application/organization-access-reader.ts
  src/modules/organizations/infrastructure/prisma-organization-access-reader.ts
  src/modules/tasks/domain/task.entity.ts
  src/modules/tasks/application/task.repository.ts
  src/modules/tasks/infrastructure/prisma-task.repository.ts
  src/modules/tasks/application/create-task.use-case.ts
  src/modules/tasks/application/list-tasks.use-case.ts
  src/modules/tasks/presentation/create-task.dto.ts
  src/modules/tasks/presentation/tasks.controller.ts
  src/modules/tasks/tasks.module.ts
  src/app.module.ts
  src/main.ts
```

Frontend:

```text
workspace-web/
  .env
  src/shared/api/api-response.ts
  src/features/tasks/api/task-api.ts
  src/features/tasks/composables/use-tasks.ts
  src/features/tasks/components/CreateTaskForm.vue
  src/features/tasks/components/TaskList.vue
  src/App.vue
  src/main.ts
  src/style.css
```

## 40. Setelah Selesai, Belajar Apa Berikutnya

Urutan lanjut yang paling masuk akal:

1. Baca [14-step-by-step-programming-flow.md](14-step-by-step-programming-flow.md) untuk versi yang lebih lengkap.
2. Baca [../stacks/shared/01-api-response-envelope.md](../stacks/shared/01-api-response-envelope.md) untuk response API.
3. Baca [../stacks/shared/06-rbac-tenant-authorization.md](../stacks/shared/06-rbac-tenant-authorization.md) untuk RBAC yang lebih rapi.
4. Baca [../stacks/typescript-vue-nest/backend/07-code-blueprint-task-module.md](../stacks/typescript-vue-nest/backend/07-code-blueprint-task-module.md) untuk blueprint NestJS yang lebih serius.
5. Baca [../stacks/typescript-vue-nest/frontend/04-code-blueprint-vue-composable.md](../stacks/typescript-vue-nest/frontend/04-code-blueprint-vue-composable.md) untuk pola Vue yang lebih lengkap.
6. Baca [../kolaborasi-github.md](../kolaborasi-github.md) sebelum mulai commit rutin dan membuat branch fitur.

## 41. Checklist Pemahaman

Sebelum lanjut ke materi berikutnya, pastikan bisa menjawab:

- Apa bedanya backend dan frontend?
- Kenapa frontend tidak langsung bicara ke database?
- Kenapa `schema.prisma` dibuat sebelum repository?
- Kenapa controller tidak langsung berisi semua logic?
- Kenapa use case perlu mengecek membership user?
- Kenapa response API dibuat konsisten?
- File mana yang menerima input user di frontend?
- File mana yang memanggil API backend di frontend?
- Command apa yang menjalankan backend?
- Command apa yang menjalankan frontend?
