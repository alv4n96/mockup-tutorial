# Backend 02 - Modular Monolith Layers

Dokumen ini melanjutkan `backend/01-project-setup.md`. Di file sebelumnya, backend NestJS + GraphQL + Prisma + PostgreSQL sudah disiapkan sampai health query berjalan. Di file ini, kita menyusun struktur backend agar siap tumbuh menjadi aplikasi Project Management App / SaaS Task Workspace yang lebih besar.

Fokus utama:

- Memahami Modular Monolith.
- Memahami Layered Architecture di NestJS GraphQL.
- Membuat batas module untuk Identity, Organizations, Projects, dan Tasks.
- Membuat template module Projects dari domain sampai resolver.
- Menjaga GraphQL resolver tetap tipis dan tidak berisi semua business logic.

NestJS cocok untuk modular monolith karena framework ini sudah punya konsep module, provider, dependency injection, resolver, guard, dan service. Struktur ini membuat aplikasi bisa tetap satu deployment, tetapi kode tetap dipisahkan berdasarkan domain.

GraphQL resolver tidak boleh berisi semua business logic karena resolver adalah presentation layer. Tugas resolver adalah menerima input API, memanggil service, dan mengubah hasil service menjadi response GraphQL. Jika resolver langsung query Prisma, memvalidasi semua business rule, dan mengatur transaksi, maka resolver akan sulit dites, sulit dipakai ulang, dan cepat menjadi file besar.

## Apa Itu Modular Monolith

Modular Monolith adalah aplikasi yang dideploy sebagai satu unit, tetapi kode di dalamnya dipisahkan menjadi module yang jelas. Dalam stack ini, backend NestJS tetap satu aplikasi, satu proses Node.js, dan satu deployment. Namun folder dan dependency dipisahkan menjadi module seperti `identity`, `organizations`, `projects`, dan `tasks`.

Monolith biasa adalah aplikasi satu deployment yang sering kali semua logic-nya bercampur. Misalnya resolver project langsung query user, task, audit log, dan organization tanpa aturan. Ini cepat di awal, tetapi sulit dirawat saat fitur bertambah.

Microservices adalah pendekatan memecah aplikasi menjadi banyak service terpisah. Setiap service punya deployment, database, observability, scaling, dan komunikasi sendiri. Microservices berguna pada organisasi besar, tetapi menambah kompleksitas tinggi.

Modular monolith cocok untuk awal enterprise/SaaS karena:

- Deployment masih sederhana.
- Database bisa tetap satu PostgreSQL.
- Refactor lebih murah dibanding service terpisah.
- Boundary domain tetap dilatih sejak awal.
- Tim kecil bisa bergerak cepat tanpa overhead network antar service.
- Testing end-to-end lebih mudah.

Modular monolith mulai tidak cukup saat:

- Satu module butuh scaling sangat berbeda dari module lain.
- Tim berbeda sering deploy module yang sama-sama besar dan saling menghambat.
- Kegagalan satu area harus benar-benar diisolasi.
- Beban background job, realtime, billing, atau analytics sudah mengganggu API utama.
- Boundary domain sudah matang dan stabil untuk dipisah.

Jangan langsung microservices di awal project karena:

- Boundary domain biasanya belum jelas.
- Data ownership sering berubah.
- Debugging lintas service lebih sulit.
- Deployment dan observability lebih mahal.
- Transaksi data lintas service menjadi kompleks.
- Tim bisa sibuk mengurus infrastruktur sebelum product flow stabil.

Prinsip praktis: mulai dengan modular monolith yang disiplin. Jika nanti perlu dipisah, module yang boundary-nya sudah rapi lebih mudah diekstrak.

## Apa Itu Layered Architecture Di NestJS

Layered Architecture membagi kode berdasarkan tanggung jawab. Setiap layer punya tugas jelas dan aturan dependency.

### Presentation Layer: GraphQL Resolver

Tanggung jawab:

- Mendefinisikan query dan mutation.
- Menerima GraphQL input.
- Memanggil application service.
- Mengembalikan object response ke GraphQL.

Tidak boleh:

- Menulis business rule berat.
- Query Prisma langsung.
- Mengatur transaksi database.
- Mengambil data lintas module tanpa service/contract.

### Application Layer: Service / Use Case

Tanggung jawab:

- Menjalankan use case seperti `createProject`, `updateProject`, dan `archiveProject`.
- Mengatur flow bisnis.
- Memanggil domain entity.
- Memanggil repository interface.
- Mengembalikan `Result`.

Tidak boleh:

- Bergantung ke GraphQL decorator.
- Bergantung langsung ke request HTTP.
- Bergantung ke detail database jika repository interface sudah tersedia.
- Menyimpan logic presentasi seperti label UI.

### Domain Layer: Entity, Value Object, Business Rule

Tanggung jawab:

- Menyimpan business rule inti.
- Menjaga state transition valid.
- Membuat entity dari data yang valid.
- Menyediakan method domain seperti `activate`, `complete`, dan `archive`.

Tidak boleh:

- Import NestJS.
- Import GraphQL.
- Import Prisma.
- Membaca environment variable.
- Memanggil external provider.

Domain harus tetap bersih agar bisa dites tanpa menjalankan NestJS atau database.

### Infrastructure Layer: Prisma Repository, External Provider

Tanggung jawab:

- Implement repository interface.
- Query database memakai Prisma.
- Membungkus external provider seperti email, storage, payment, atau JWT provider.
- Mengubah data database menjadi domain entity.

Tidak boleh:

- Menjadi tempat business rule utama.
- Mengizinkan query tenant tanpa filter `organizationId`.
- Dipanggil langsung dari resolver jika service sudah tersedia.

### Common/Shared Layer: Result, Error, Pagination, Guards, Filters

Tanggung jawab:

- Menyimpan helper generik yang dipakai lintas module.
- Menyediakan result type.
- Menyediakan app error.
- Menyediakan pagination input/response.
- Menyediakan guard dan filter umum.

Tidak boleh:

- Menyimpan business rule project.
- Menyimpan rule status task.
- Menyimpan repository spesifik module.
- Menjadi tempat semua helper acak.

### Database Layer: Prisma + PostgreSQL

Tanggung jawab:

- Menyimpan data.
- Menjaga constraint relasi.
- Menjalankan migration.
- Menjalankan query melalui Prisma Client.

Database boleh punya foreign key lintas tabel. Namun logic akses tetap harus mengikuti boundary module.

## Kenapa Resolver Jangan Langsung Query Prisma

Resolver langsung query Prisma terlihat cepat:

```ts path=backend/src/modules/projects/presentation/projects.resolver.ts
// Contoh buruk: jangan dipakai sebagai pola utama.
const project = await this.prisma.project.findUnique({ where: { id } });
```

Masalahnya:

- Resolver jadi tahu detail database.
- Query tenant bisa lupa filter `organizationId`.
- Business rule tersebar di banyak resolver.
- Unit test resolver butuh mock database.
- Perubahan database berdampak langsung ke API layer.

Lebih baik:

```txt
ProjectsResolver -> ProjectService -> ProjectRepository -> PrismaProjectRepository -> PrismaService
```

## Struktur Folder Target

Struktur target:

```txt
backend/
└── src/
    ├── main.ts
    ├── app.module.ts
    │
    ├── common/
    │   ├── errors/
    │   │   └── app-error.ts
    │   ├── result/
    │   │   └── result.ts
    │   ├── pagination/
    │   │   ├── pagination.input.ts
    │   │   └── pagination.response.ts
    │   ├── filters/
    │   │   └── graphql-exception.filter.ts
    │   └── guards/
    │       └── gql-auth.guard.ts
    │
    ├── infrastructure/
    │   ├── prisma/
    │   │   ├── prisma.module.ts
    │   │   └── prisma.service.ts
    │   └── config/
    │       └── env.validation.ts
    │
    └── modules/
        ├── identity/
        │   ├── domain/
        │   ├── application/
        │   ├── infrastructure/
        │   └── presentation/
        │
        ├── organizations/
        │   ├── domain/
        │   ├── application/
        │   ├── infrastructure/
        │   └── presentation/
        │
        ├── projects/
        │   ├── domain/
        │   ├── application/
        │   ├── infrastructure/
        │   └── presentation/
        │
        └── tasks/
            ├── domain/
            ├── application/
            ├── infrastructure/
            └── presentation/
```

Fungsi folder:

- `common/errors`: error generic seperti `AppError`.
- `common/result`: result type untuk sukses/gagal.
- `common/pagination`: input dan metadata pagination reusable.
- `common/filters`: GraphQL exception filter umum.
- `common/guards`: guard umum seperti auth guard.
- `infrastructure/prisma`: koneksi Prisma dan module Prisma.
- `infrastructure/config`: validasi environment variable.
- `modules/*/domain`: entity, enum, value object, business rule.
- `modules/*/application`: service use case dan repository interface.
- `modules/*/infrastructure`: repository implementation dan adapter external.
- `modules/*/presentation`: resolver, GraphQL input, GraphQL object type, module registration.

## Command Membuat Folder

Versi macOS/Linux/Git Bash:

```bash
mkdir -p src/modules/projects/domain
mkdir -p src/modules/projects/application
mkdir -p src/modules/projects/infrastructure
mkdir -p src/modules/projects/presentation/dto
mkdir -p src/common/result
mkdir -p src/common/errors
mkdir -p src/common/pagination
```

Penjelasan:

- `mkdir`: membuat folder.
- `-p`: membuat parent folder jika belum ada dan tidak error jika folder sudah ada.

Versi PowerShell:

```powershell
New-Item -ItemType Directory -Force src/modules/projects/domain
New-Item -ItemType Directory -Force src/modules/projects/application
New-Item -ItemType Directory -Force src/modules/projects/infrastructure
New-Item -ItemType Directory -Force src/modules/projects/presentation/dto
New-Item -ItemType Directory -Force src/common/result
New-Item -ItemType Directory -Force src/common/errors
New-Item -ItemType Directory -Force src/common/pagination
```

Penjelasan:

- `New-Item`: membuat item baru.
- `-ItemType Directory`: item yang dibuat adalah folder.
- `-Force`: tidak error jika folder sudah ada.

## Dependency Rule

Aturan dependency:

- Resolver boleh memanggil Application Service.
- Application Service boleh memanggil Domain dan interface Repository.
- Domain tidak boleh import NestJS, GraphQL, Prisma, atau Config.
- Infrastructure boleh import Prisma dan implement Repository interface.
- Common boleh dipakai semua module.
- Common tidak boleh tahu detail Identity, Organizations, Projects, atau Tasks.
- Module tidak boleh akses table module lain sembarangan.
- Akses antar-module harus lewat service, interface, atau contract.

Diagram dependency:

```txt
GraphQL Resolver
      |
      v
Application Service -----> Domain Entity / Business Rule
      |
      v
Repository Interface
      ^
      |
Prisma Repository Implementation
      |
      v
PrismaService
      |
      v
PostgreSQL

Common dapat dipakai oleh semua layer, tetapi tidak boleh bergantung ke module domain.
```

Aturan penting:

```txt
Domain tidak boleh menunjuk keluar.
Infrastructure boleh tahu detail luar.
Application mengatur use case.
Presentation hanya API boundary.
```

## Module Boundary

Module boundary adalah batas kepemilikan logic dan data access. Dalam aplikasi ini:

- `identity` memiliki logic user account, password, login, token, dan current user.
- `organizations` memiliki tenant, membership, dan role dalam organization.
- `projects` memiliki project dalam organization.
- `tasks` memiliki task dalam project.

Yang boleh dishare antar module:

- ID entity seperti `userId`, `organizationId`, `projectId`.
- Contract/interface yang memang dirancang untuk dipakai module lain.
- DTO internal yang stabil jika benar-benar perlu.
- Common utility generic seperti `Result`, `AppError`, dan pagination.

Yang tidak boleh dishare sembarangan:

- Repository implementation module lain.
- Prisma query module lain.
- Business rule private module lain.
- Internal entity jika membuat coupling terlalu kuat.

Prisma schema boleh tetap satu database karena ini modular monolith. Satu database memudahkan transaksi dan join. Namun akses logic tetap harus lewat boundary agar service tidak saling menembus domain.

Direct join masih masuk akal saat:

- Query read-only untuk halaman dashboard.
- Query butuh performa dan tidak mengubah state.
- Query tetap menjaga tenant filter.
- Query berada di repository atau read model yang jelas.

Direct access antar-module menjadi masalah saat:

- Module Projects langsung mengubah membership organization.
- Module Tasks langsung mengubah password user.
- Service satu module memanggil Prisma table module lain tanpa kontrak.
- Business rule lintas module tersebar di banyak tempat.

## Contoh Module Projects Sebagai Template

Struktur module Projects:

```txt
src/modules/projects/
├── domain/
│   ├── project.entity.ts
│   └── project-status.enum.ts
│
├── application/
│   ├── project.service.ts
│   └── project.repository.ts
│
├── infrastructure/
│   └── prisma-project.repository.ts
│
└── presentation/
    ├── dto/
    │   ├── create-project.input.ts
    │   ├── update-project.input.ts
    │   └── project.object.ts
    ├── projects.resolver.ts
    └── projects.module.ts
```

Fungsi file:

- `project-status.enum.ts`: status domain project.
- `project.entity.ts`: entity domain dan business rule project.
- `project.repository.ts`: interface repository yang dibutuhkan service.
- `project.service.ts`: use case project.
- `prisma-project.repository.ts`: implementasi repository memakai Prisma.
- `create-project.input.ts`: input GraphQL untuk create project.
- `update-project.input.ts`: input GraphQL untuk update project.
- `project.object.ts`: object type GraphQL untuk response project.
- `projects.resolver.ts`: query/mutation GraphQL.
- `projects.module.ts`: registrasi provider module Projects.

## Domain Layer Projects

Domain tidak import Prisma, NestJS, atau GraphQL decorator.

```ts path=backend/src/modules/projects/domain/project-status.enum.ts
export enum ProjectStatus {
  DRAFT = 'DRAFT',
  ACTIVE = 'ACTIVE',
  COMPLETED = 'COMPLETED',
  ARCHIVED = 'ARCHIVED',
}
```

```ts path=backend/src/modules/projects/domain/project.entity.ts
import { AppError } from '../../../common/errors/app-error';
import { Result } from '../../../common/result/result';
import { ProjectStatus } from './project-status.enum';

export type ProjectProps = {
  id: string;
  organizationId: string;
  name: string;
  description?: string | null;
  status: ProjectStatus;
  createdByUserId: string;
  createdAt: Date;
  updatedAt: Date;
};

export type CreateProjectProps = {
  id: string;
  organizationId: string;
  name: string;
  description?: string | null;
  createdByUserId: string;
};

export type UpdateProjectProps = {
  name?: string;
  description?: string | null;
};

export class Project {
  private constructor(private readonly props: ProjectProps) {}

  static create(input: CreateProjectProps): Result<Project> {
    const name = input.name.trim();

    if (!name) {
      return Result.fail(AppError.validation('PROJECT_NAME_REQUIRED', 'Project name is required.'));
    }

    if (name.length > 120) {
      return Result.fail(AppError.validation('PROJECT_NAME_TOO_LONG', 'Project name must be 120 characters or fewer.'));
    }

    const now = new Date();

    return Result.ok(
      new Project({
        id: input.id,
        organizationId: input.organizationId,
        name,
        description: input.description?.trim() || null,
        status: ProjectStatus.DRAFT,
        createdByUserId: input.createdByUserId,
        createdAt: now,
        updatedAt: now,
      }),
    );
  }

  static fromPersistence(props: ProjectProps): Project {
    return new Project(props);
  }

  update(input: UpdateProjectProps): Result<Project> {
    if (this.props.status === ProjectStatus.ARCHIVED) {
      return Result.fail(AppError.conflict('PROJECT_ARCHIVED', 'Archived project cannot be updated.'));
    }

    if (input.name !== undefined) {
      const name = input.name.trim();

      if (!name) {
        return Result.fail(AppError.validation('PROJECT_NAME_REQUIRED', 'Project name is required.'));
      }

      if (name.length > 120) {
        return Result.fail(AppError.validation('PROJECT_NAME_TOO_LONG', 'Project name must be 120 characters or fewer.'));
      }

      this.props.name = name;
    }

    if (input.description !== undefined) {
      this.props.description = input.description?.trim() || null;
    }

    this.touch();
    return Result.ok(this);
  }

  activate(): Result<Project> {
    if (this.props.status === ProjectStatus.ARCHIVED) {
      return Result.fail(AppError.conflict('PROJECT_ARCHIVED', 'Archived project cannot be activated.'));
    }

    if (this.props.status === ProjectStatus.COMPLETED) {
      return Result.fail(AppError.conflict('PROJECT_COMPLETED', 'Completed project cannot be activated.'));
    }

    this.props.status = ProjectStatus.ACTIVE;
    this.touch();
    return Result.ok(this);
  }

  complete(): Result<Project> {
    if (this.props.status === ProjectStatus.ARCHIVED) {
      return Result.fail(AppError.conflict('PROJECT_ARCHIVED', 'Archived project cannot be completed.'));
    }

    this.props.status = ProjectStatus.COMPLETED;
    this.touch();
    return Result.ok(this);
  }

  archive(): Result<Project> {
    if (this.props.status === ProjectStatus.ARCHIVED) {
      return Result.ok(this);
    }

    this.props.status = ProjectStatus.ARCHIVED;
    this.touch();
    return Result.ok(this);
  }

  toProps(): ProjectProps {
    return { ...this.props };
  }

  private touch(): void {
    this.props.updatedAt = new Date();
  }
}
```

Catatan:

- Entity menyimpan rule status transition.
- Entity return `Result`, bukan throw exception untuk business error normal.
- Entity tidak tahu database, GraphQL, atau NestJS.

## Common Result Pattern

Result Pattern berguna untuk membedakan sukses dan gagal tanpa selalu memakai exception. Business error seperti project tidak ditemukan, nama tidak valid, atau project sudah archived bisa dikembalikan sebagai `Result.fail`.

Exception tetap boleh dipakai untuk:

- Error yang benar-benar tidak terduga.
- Kegagalan dependency eksternal.
- Bug program.
- Error framework atau infrastructure yang akan ditangani filter global.

```ts path=backend/src/common/errors/app-error.ts
export type AppErrorType = 'VALIDATION' | 'NOT_FOUND' | 'CONFLICT' | 'FORBIDDEN' | 'UNAUTHORIZED' | 'INTERNAL';

export class AppError {
  private constructor(
    public readonly type: AppErrorType,
    public readonly code: string,
    public readonly message: string,
    public readonly details?: Record<string, unknown>,
  ) {}

  static validation(code: string, message: string, details?: Record<string, unknown>): AppError {
    return new AppError('VALIDATION', code, message, details);
  }

  static notFound(code: string, message: string, details?: Record<string, unknown>): AppError {
    return new AppError('NOT_FOUND', code, message, details);
  }

  static conflict(code: string, message: string, details?: Record<string, unknown>): AppError {
    return new AppError('CONFLICT', code, message, details);
  }

  static forbidden(code: string, message: string, details?: Record<string, unknown>): AppError {
    return new AppError('FORBIDDEN', code, message, details);
  }

  static unauthorized(code: string, message: string, details?: Record<string, unknown>): AppError {
    return new AppError('UNAUTHORIZED', code, message, details);
  }

  static internal(code: string, message: string, details?: Record<string, unknown>): AppError {
    return new AppError('INTERNAL', code, message, details);
  }
}
```

```ts path=backend/src/common/result/result.ts
import { AppError } from '../errors/app-error';

export class Result<T> {
  private constructor(
    private readonly success: boolean,
    private readonly value?: T,
    private readonly error?: AppError,
  ) {}

  static ok<T>(value: T): Result<T> {
    return new Result<T>(true, value);
  }

  static fail<T = never>(error: AppError): Result<T> {
    return new Result<T>(false, undefined, error);
  }

  isOk(): boolean {
    return this.success;
  }

  isFail(): boolean {
    return !this.success;
  }

  unwrap(): T {
    if (!this.success || this.value === undefined) {
      throw new Error('Cannot unwrap failed result.');
    }

    return this.value;
  }

  unwrapError(): AppError {
    if (this.success || !this.error) {
      throw new Error('Cannot unwrap error from successful result.');
    }

    return this.error;
  }
}
```

## Application Layer Projects

Repository interface berada di application layer karena service butuh kontrak data access, bukan implementasi Prisma.

```ts path=backend/src/modules/projects/application/project.repository.ts
import { PaginationInput } from '../../../common/pagination/pagination.input';
import { Project } from '../domain/project.entity';

export type ProjectListFilter = {
  organizationId: string;
  pagination: PaginationInput;
};

export type ProjectListResult = {
  items: Project[];
  total: number;
};

export const PROJECT_REPOSITORY = Symbol('PROJECT_REPOSITORY');

export interface ProjectRepository {
  create(project: Project): Promise<Project>;
  findById(organizationId: string, projectId: string): Promise<Project | null>;
  findMany(filter: ProjectListFilter): Promise<ProjectListResult>;
  update(project: Project): Promise<Project>;
}
```

```ts path=backend/src/modules/projects/application/project.service.ts
import { Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { AppError } from '../../../common/errors/app-error';
import { PaginationInput } from '../../../common/pagination/pagination.input';
import { Result } from '../../../common/result/result';
import { Project } from '../domain/project.entity';
import {
  PROJECT_REPOSITORY,
  ProjectListResult,
  ProjectRepository,
} from './project.repository';

export type CreateProjectCommand = {
  organizationId: string;
  createdByUserId: string;
  name: string;
  description?: string | null;
};

export type UpdateProjectCommand = {
  organizationId: string;
  projectId: string;
  name?: string;
  description?: string | null;
};

@Injectable()
export class ProjectService {
  constructor(
    @Inject(PROJECT_REPOSITORY)
    private readonly projectRepository: ProjectRepository,
  ) {}

  async createProject(command: CreateProjectCommand): Promise<Result<Project>> {
    if (!command.organizationId) {
      return Result.fail(AppError.validation('ORGANIZATION_ID_REQUIRED', 'Organization id is required.'));
    }

    const projectOrError = Project.create({
      id: randomUUID(),
      organizationId: command.organizationId,
      createdByUserId: command.createdByUserId,
      name: command.name,
      description: command.description,
    });

    if (projectOrError.isFail()) {
      return Result.fail(projectOrError.unwrapError());
    }

    const project = await this.projectRepository.create(projectOrError.unwrap());
    return Result.ok(project);
  }

  async getProjectById(organizationId: string, projectId: string): Promise<Result<Project>> {
    if (!organizationId) {
      return Result.fail(AppError.validation('ORGANIZATION_ID_REQUIRED', 'Organization id is required.'));
    }

    const project = await this.projectRepository.findById(organizationId, projectId);

    if (!project) {
      return Result.fail(AppError.notFound('PROJECT_NOT_FOUND', 'Project was not found.'));
    }

    return Result.ok(project);
  }

  async listProjects(organizationId: string, pagination: PaginationInput): Promise<Result<ProjectListResult>> {
    if (!organizationId) {
      return Result.fail(AppError.validation('ORGANIZATION_ID_REQUIRED', 'Organization id is required.'));
    }

    const result = await this.projectRepository.findMany({
      organizationId,
      pagination,
    });

    return Result.ok(result);
  }

  async updateProject(command: UpdateProjectCommand): Promise<Result<Project>> {
    const projectOrError = await this.getProjectById(command.organizationId, command.projectId);

    if (projectOrError.isFail()) {
      return Result.fail(projectOrError.unwrapError());
    }

    const project = projectOrError.unwrap();
    const updatedOrError = project.update({
      name: command.name,
      description: command.description,
    });

    if (updatedOrError.isFail()) {
      return Result.fail(updatedOrError.unwrapError());
    }

    const saved = await this.projectRepository.update(updatedOrError.unwrap());
    return Result.ok(saved);
  }

  async archiveProject(organizationId: string, projectId: string): Promise<Result<Project>> {
    const projectOrError = await this.getProjectById(organizationId, projectId);

    if (projectOrError.isFail()) {
      return Result.fail(projectOrError.unwrapError());
    }

    const archivedOrError = projectOrError.unwrap().archive();

    if (archivedOrError.isFail()) {
      return Result.fail(archivedOrError.unwrapError());
    }

    const saved = await this.projectRepository.update(archivedOrError.unwrap());
    return Result.ok(saved);
  }
}
```

Business orchestration berada di service karena service adalah tempat use case. Resolver tidak perlu tahu cara membuat entity, memanggil repository, atau menangani rule archive.

## Infrastructure Layer Projects

Repository ini masuk infrastructure layer karena memakai PrismaService dan detail database. Query project selalu filter `organizationId`. Jangan query hanya berdasarkan `projectId`, karena dalam aplikasi tenant-aware, project harus selalu dibatasi oleh organization aktif.

```ts path=backend/src/modules/projects/infrastructure/prisma-project.repository.ts
import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import {
  ProjectListFilter,
  ProjectListResult,
  ProjectRepository,
} from '../application/project.repository';
import { Project, ProjectProps } from '../domain/project.entity';
import { ProjectStatus } from '../domain/project-status.enum';

type PrismaProjectRecord = {
  id: string;
  organizationId: string;
  name: string;
  description: string | null;
  status: string;
  createdByUserId: string;
  createdAt: Date;
  updatedAt: Date;
};

@Injectable()
export class PrismaProjectRepository implements ProjectRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(project: Project): Promise<Project> {
    const props = project.toProps();

    const created = await this.prisma.project.create({
      data: {
        id: props.id,
        organizationId: props.organizationId,
        name: props.name,
        description: props.description,
        status: props.status,
        createdByUserId: props.createdByUserId,
        createdAt: props.createdAt,
        updatedAt: props.updatedAt,
      },
    });

    return this.toDomain(created);
  }

  async findById(organizationId: string, projectId: string): Promise<Project | null> {
    const project = await this.prisma.project.findFirst({
      where: {
        id: projectId,
        organizationId,
      },
    });

    return project ? this.toDomain(project) : null;
  }

  async findMany(filter: ProjectListFilter): Promise<ProjectListResult> {
    const page = filter.pagination.page ?? 1;
    const pageSize = Math.min(filter.pagination.pageSize ?? 20, 100);
    const skip = (page - 1) * pageSize;

    const where: Prisma.ProjectWhereInput = {
      organizationId: filter.organizationId,
      ...(filter.pagination.search
        ? {
            OR: [
              { name: { contains: filter.pagination.search, mode: 'insensitive' } },
              { description: { contains: filter.pagination.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.project.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: pageSize,
      }),
      this.prisma.project.count({ where }),
    ]);

    return {
      items: items.map((item) => this.toDomain(item)),
      total,
    };
  }

  async update(project: Project): Promise<Project> {
    const props = project.toProps();

    const updated = await this.prisma.project.update({
      where: {
        id: props.id,
      },
      data: {
        name: props.name,
        description: props.description,
        status: props.status,
        updatedAt: props.updatedAt,
      },
    });

    return this.toDomain(updated);
  }

  private toDomain(record: PrismaProjectRecord): Project {
    const props: ProjectProps = {
      id: record.id,
      organizationId: record.organizationId,
      name: record.name,
      description: record.description,
      status: record.status as ProjectStatus,
      createdByUserId: record.createdByUserId,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };

    return Project.fromPersistence(props);
  }
}
```

Catatan penting:

- `findById` memakai `id` dan `organizationId`.
- `findMany` selalu filter `organizationId`.
- `$transaction` dipakai agar data list dan count konsisten.
- Prisma type dipakai di infrastructure, bukan domain.

## Presentation Layer Projects

Presentation layer memakai GraphQL decorators NestJS. Resolver hanya handle input/output dan memanggil service.

```ts path=backend/src/modules/projects/presentation/dto/create-project.input.ts
import { Field, InputType } from '@nestjs/graphql';
import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

@InputType()
export class CreateProjectInput {
  @Field()
  @IsString()
  @IsNotEmpty()
  organizationId: string;

  @Field()
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  name: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;
}
```

```ts path=backend/src/modules/projects/presentation/dto/update-project.input.ts
import { Field, InputType } from '@nestjs/graphql';
import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

@InputType()
export class UpdateProjectInput {
  @Field()
  @IsString()
  @IsNotEmpty()
  organizationId: string;

  @Field()
  @IsString()
  @IsNotEmpty()
  projectId: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  name?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;
}
```

```ts path=backend/src/modules/projects/presentation/dto/project.object.ts
import { Field, ObjectType } from '@nestjs/graphql';
import { Project } from '../../domain/project.entity';
import { ProjectStatus } from '../../domain/project-status.enum';

@ObjectType()
export class ProjectObject {
  @Field()
  id: string;

  @Field()
  organizationId: string;

  @Field()
  name: string;

  @Field({ nullable: true })
  description?: string | null;

  @Field(() => String)
  status: ProjectStatus;

  @Field()
  createdByUserId: string;

  @Field()
  createdAt: Date;

  @Field()
  updatedAt: Date;

  static fromDomain(project: Project): ProjectObject {
    const props = project.toProps();
    const object = new ProjectObject();

    object.id = props.id;
    object.organizationId = props.organizationId;
    object.name = props.name;
    object.description = props.description;
    object.status = props.status;
    object.createdByUserId = props.createdByUserId;
    object.createdAt = props.createdAt;
    object.updatedAt = props.updatedAt;

    return object;
  }
}
```

```ts path=backend/src/modules/projects/presentation/projects.resolver.ts
import { Args, Mutation, Query, Resolver } from '@nestjs/graphql';
import { GraphQLError } from 'graphql';
import { PaginationInput } from '../../../common/pagination/pagination.input';
import { ProjectService } from '../application/project.service';
import { CreateProjectInput } from './dto/create-project.input';
import { ProjectObject } from './dto/project.object';
import { UpdateProjectInput } from './dto/update-project.input';

@Resolver(() => ProjectObject)
export class ProjectsResolver {
  constructor(private readonly projectService: ProjectService) {}

  @Mutation(() => ProjectObject)
  async createProject(@Args('input') input: CreateProjectInput): Promise<ProjectObject> {
    const result = await this.projectService.createProject({
      organizationId: input.organizationId,
      createdByUserId: 'current-user-placeholder',
      name: input.name,
      description: input.description,
    });

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return ProjectObject.fromDomain(result.unwrap());
  }

  @Query(() => [ProjectObject])
  async projects(
    @Args('organizationId') organizationId: string,
    @Args('pagination', { nullable: true }) pagination?: PaginationInput,
  ): Promise<ProjectObject[]> {
    const result = await this.projectService.listProjects(organizationId, pagination ?? new PaginationInput());

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return result.unwrap().items.map(ProjectObject.fromDomain);
  }

  @Query(() => ProjectObject)
  async project(
    @Args('organizationId') organizationId: string,
    @Args('projectId') projectId: string,
  ): Promise<ProjectObject> {
    const result = await this.projectService.getProjectById(organizationId, projectId);

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return ProjectObject.fromDomain(result.unwrap());
  }

  @Mutation(() => ProjectObject)
  async updateProject(@Args('input') input: UpdateProjectInput): Promise<ProjectObject> {
    const result = await this.projectService.updateProject({
      organizationId: input.organizationId,
      projectId: input.projectId,
      name: input.name,
      description: input.description,
    });

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return ProjectObject.fromDomain(result.unwrap());
  }

  @Mutation(() => ProjectObject)
  async archiveProject(
    @Args('organizationId') organizationId: string,
    @Args('projectId') projectId: string,
  ): Promise<ProjectObject> {
    const result = await this.projectService.archiveProject(organizationId, projectId);

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return ProjectObject.fromDomain(result.unwrap());
  }

  private toGraphQLError(error: { code: string; message: string; type: string; details?: Record<string, unknown> }): GraphQLError {
    return new GraphQLError(error.message, {
      extensions: {
        code: error.code,
        type: error.type,
        details: error.details,
      },
    });
  }
}
```

```ts path=backend/src/modules/projects/presentation/projects.module.ts
import { Module } from '@nestjs/common';
import { PROJECT_REPOSITORY } from '../application/project.repository';
import { ProjectService } from '../application/project.service';
import { PrismaProjectRepository } from '../infrastructure/prisma-project.repository';
import { ProjectsResolver } from './projects.resolver';

@Module({
  providers: [
    ProjectsResolver,
    ProjectService,
    {
      provide: PROJECT_REPOSITORY,
      useClass: PrismaProjectRepository,
    },
  ],
  exports: [ProjectService],
})
export class ProjectsModule {}
```

Catatan:

- `createdByUserId` masih placeholder karena auth detail dibahas di `03-identity-auth.md`.
- Error mapping sederhana di resolver akan dirapikan pada dokumen GraphQL API pattern.
- Untuk list project, contoh resolver mengembalikan array agar sederhana. Metadata pagination dijelaskan di bagian common.

## Common Layer Pagination

Pagination harus reusable dan dibatasi agar client tidak bisa meminta data terlalu besar.

```ts path=backend/src/common/pagination/pagination.input.ts
import { Field, InputType, Int } from '@nestjs/graphql';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

@InputType()
export class PaginationInput {
  @Field(() => Int, { defaultValue: 1 })
  @IsOptional()
  @IsInt()
  @Min(1)
  page?: number = 1;

  @Field(() => Int, { defaultValue: 20 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize?: number = 20;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  search?: string;
}
```

```ts path=backend/src/common/pagination/pagination.response.ts
import { Field, Int, ObjectType } from '@nestjs/graphql';

@ObjectType()
export class PaginationMeta {
  @Field(() => Int)
  page: number;

  @Field(() => Int)
  pageSize: number;

  @Field(() => Int)
  total: number;

  @Field(() => Int)
  totalPages: number;

  @Field()
  hasNextPage: boolean;

  @Field()
  hasPreviousPage: boolean;

  static create(page: number, pageSize: number, total: number): PaginationMeta {
    const meta = new PaginationMeta();
    const safePageSize = Math.min(pageSize, 100);

    meta.page = page;
    meta.pageSize = safePageSize;
    meta.total = total;
    meta.totalPages = Math.ceil(total / safePageSize);
    meta.hasNextPage = page < meta.totalPages;
    meta.hasPreviousPage = page > 1;

    return meta;
  }
}
```

## App Module Integration

`AppModule` adalah root module. Feature module seperti `ProjectsModule` mendaftarkan resolver, service, dan repository sendiri.

```ts path=backend/src/app.module.ts
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { GraphQLModule } from '@nestjs/graphql';
import { join } from 'path';
import { PrismaModule } from './infrastructure/prisma/prisma.module';
import { HealthModule } from './modules/health/health.module';
import { ProjectsModule } from './modules/projects/presentation/projects.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      autoSchemaFile: join(process.cwd(), 'src/schema.gql'),
      sortSchema: true,
      playground: process.env.NODE_ENV !== 'production',
    }),
    PrismaModule,
    HealthModule,
    ProjectsModule,
  ],
})
export class AppModule {}
```

Placeholder module lain seperti `IdentityModule`, `OrganizationsModule`, dan `TasksModule` nanti akan ditambahkan saat file implementasinya dibuat.

## Module Registration Di NestJS

`@Module` adalah decorator untuk mendefinisikan module NestJS.

- `imports`: module lain yang dibutuhkan.
- `providers`: class atau provider token yang dibuat oleh dependency injection container.
- `exports`: provider yang boleh dipakai module lain.

Repository implementation didaftarkan sebagai provider karena service membutuhkan interface, sementara NestJS runtime butuh class konkret.

Contoh:

```ts path=backend/src/modules/projects/presentation/projects.module.ts
{
  provide: PROJECT_REPOSITORY,
  useClass: PrismaProjectRepository,
}
```

Artinya:

- Saat ada class meminta `PROJECT_REPOSITORY`, NestJS memberi instance `PrismaProjectRepository`.
- `ProjectService` tidak tahu Prisma repository secara langsung.
- Implementasi bisa diganti di test dengan repository palsu.

## GraphQL Schema Flow

Stack ini memakai code-first GraphQL di NestJS.

- `@InputType()` membuat input GraphQL.
- `@ObjectType()` membuat output GraphQL.
- `@Resolver()` membuat resolver GraphQL.
- `@Query()` membuat query.
- `@Mutation()` membuat mutation.

NestJS membaca decorator tersebut lalu menghasilkan schema GraphQL otomatis ke `src/schema.gql` sesuai konfigurasi `autoSchemaFile`.

Flow schema:

```txt
TypeScript class + GraphQL decorator
        |
        v
NestJS GraphQL metadata
        |
        v
Generated GraphQL schema
        |
        v
Apollo GraphQL endpoint /graphql
```

## Prisma Dan Layer Boundary

Aturan utama:

- `PrismaService` hanya berada di infrastructure.
- Jangan inject `PrismaService` langsung ke resolver.
- Jangan import Prisma type ke domain entity jika ingin domain tetap bersih.
- Repository implementation boleh memakai Prisma type karena dia infrastructure.

Kapan memakai Prisma type masih acceptable:

- Pada project kecil yang butuh cepat.
- Pada read model sederhana.
- Pada mapping infrastructure.
- Pada internal admin tool dengan risiko domain rendah.

Trade-off:

- Clean architecture lebih rapi dan mudah dites, tetapi file lebih banyak.
- Development cepat dengan Prisma langsung lebih ringkas, tetapi coupling lebih kuat.
- Untuk stack enterprise mockup ini, kita pilih boundary yang cukup bersih tanpa membuat abstraksi berlebihan.

## Common Layer

Isi common yang tepat:

- `Result`
- `AppError`
- `PaginationInput`
- `PaginationMeta`
- Guards umum
- Filters umum
- Constants benar-benar generic

Yang tidak boleh masuk common:

- Business rule project.
- Task status transition rule.
- Organization membership rule.
- JWT provider detail.
- Repository spesifik module.
- Helper random yang hanya dipakai satu file.

Jika sebuah helper hanya dipakai oleh module Projects, simpan di module Projects. Jangan masukkan ke common hanya karena ingin terlihat reusable.

## Request Flow

Flow mutation `createProject`:

```txt
React Client
    |
    v
Apollo Client
    |
    v
GraphQL Mutation createProject
    |
    v
ProjectsResolver
    |
    v
ProjectService
    |
    v
ProjectRepository interface
    |
    v
PrismaProjectRepository
    |
    v
PrismaService
    |
    v
PostgreSQL
    |
    v
Result<Project>
    |
    v
GraphQL response
```

Di flow ini:

- Client tidak tahu Prisma.
- Resolver tidak tahu SQL.
- Service tidak tahu detail Prisma.
- Domain tidak tahu NestJS.
- Repository memastikan tenant filter.

## Design Pattern Yang Relevan

Konsep pattern berikut memakai inspirasi umum dari katalog design pattern seperti Refactoring Guru, tetapi contoh dan penjelasan dibuat untuk stack ini.

### Repository Pattern

Masalah yang diselesaikan:

Service butuh data project, tetapi tidak perlu tahu detail Prisma query.

Kenapa dipakai:

Repository membuat data access terpusat, mudah dites, dan menjaga filter `organizationId`.

File yang memakai:

- `backend/src/modules/projects/application/project.repository.ts`
- `backend/src/modules/projects/infrastructure/prisma-project.repository.ts`

Alternatif:

- Service langsung memanggil Prisma. Lebih cepat di awal, tetapi query tersebar.

### Adapter Pattern Melalui Prisma Repository

Masalah yang diselesaikan:

Application layer butuh kontrak repository, sementara Prisma punya API sendiri.

Kenapa dipakai:

`PrismaProjectRepository` mengadaptasi Prisma Client menjadi `ProjectRepository`.

File yang memakai:

- `backend/src/modules/projects/infrastructure/prisma-project.repository.ts`

Alternatif:

- Membiarkan semua layer memakai Prisma Client langsung.

### Facade Pattern Melalui Feature Module / Resolver

Masalah yang diselesaikan:

Client GraphQL tidak perlu tahu banyak service internal.

Kenapa dipakai:

Resolver memberi pintu API sederhana seperti `createProject`, `projects`, dan `archiveProject`.

File yang memakai:

- `backend/src/modules/projects/presentation/projects.resolver.ts`
- `backend/src/modules/projects/presentation/projects.module.ts`

Alternatif:

- Membuka banyak operasi internal langsung ke API. Ini membuat API sulit stabil.

### Result Pattern

Masalah yang diselesaikan:

Business error normal tidak harus selalu menjadi exception.

Kenapa dipakai:

Use case bisa mengembalikan sukses/gagal secara eksplisit.

File yang memakai:

- `backend/src/common/result/result.ts`
- `backend/src/common/errors/app-error.ts`
- `backend/src/modules/projects/domain/project.entity.ts`
- `backend/src/modules/projects/application/project.service.ts`

Alternatif:

- Throw exception untuk semua error. Ini lebih sederhana, tetapi flow business error kurang eksplisit.

### Module Pattern NestJS

Masalah yang diselesaikan:

Aplikasi perlu mengelompokkan provider dan dependency per feature.

Kenapa dipakai:

NestJS module system membantu modular monolith tetap terstruktur.

File yang memakai:

- `backend/src/app.module.ts`
- `backend/src/modules/projects/presentation/projects.module.ts`

Alternatif:

- Semua provider didaftarkan di `AppModule`. Ini cepat menjadi sulit dirawat.

### Dependency Injection

Masalah yang diselesaikan:

Class tidak perlu membuat dependency sendiri.

Kenapa dipakai:

NestJS otomatis menyediakan dependency, sehingga testing dan penggantian implementasi lebih mudah.

File yang memakai:

- `backend/src/modules/projects/application/project.service.ts`
- `backend/src/modules/projects/infrastructure/prisma-project.repository.ts`
- `backend/src/modules/projects/presentation/projects.resolver.ts`

Alternatif:

- Membuat instance manual dengan `new`. Ini mengikat class ke implementasi konkret.

### Strategy Pattern Sebagai Preview Untuk Task Workflow

Masalah yang diselesaikan:

Workflow task bisa berbeda berdasarkan role, status, atau tipe project.

Kenapa dipakai nanti:

Strategy bisa memisahkan aturan perubahan status task, misalnya siapa yang boleh move task dari `TODO` ke `DONE`.

File yang akan memakai:

- `backend/src/modules/tasks/domain/`
- `backend/src/modules/tasks/application/`

Alternatif:

- Banyak `if/else` di service task. Ini masih boleh saat rule sedikit, tetapi membesar saat workflow bertambah.

## Anti-pattern / Kesalahan Umum

Hindari:

- Semua logic ditaruh di resolver.
- Prisma query menyebar di semua file.
- Domain entity import `PrismaService`.
- Common folder menjadi tempat sampah.
- Module saling query data tanpa boundary.
- Semua DTO ditaruh di satu file besar.
- Tidak ada validation.
- Pagination tidak dibatasi.
- Error handling tidak konsisten.
- Resolver mengubah banyak table langsung.
- Repository mencari data tenant hanya dengan `projectId`.
- Service mencampur response GraphQL dan business logic.

## Cara Cek Berhasil

Jalankan backend:

```bash
npm run start:dev
```

Penjelasan:

- `npm run`: menjalankan script dari `package.json`.
- `start:dev`: menjalankan NestJS dengan watch mode.

Buka:

```txt
http://localhost:3000/graphql
```

Contoh mutation:

```graphql
mutation {
  createProject(input: {
    organizationId: "org_123"
    name: "Website Redesign"
    description: "Redesign company website"
  }) {
    id
    name
    status
  }
}
```

Expected result jika database dan schema sudah mendukung field yang dipakai:

```json
{
  "data": {
    "createProject": {
      "id": "generated-id",
      "name": "Website Redesign",
      "status": "DRAFT"
    }
  }
}
```

Catatan penting:

- Contoh ini membutuhkan model Prisma `Project` punya field `createdByUserId` dan status `DRAFT`.
- Jika schema dari `01-project-setup.md` belum disesuaikan dengan field ini, migration akan perlu diperbarui pada dokumen database berikutnya.
- Auth user masih placeholder. Detail current user akan dibahas di `03-identity-auth.md`.

## Troubleshooting

### Resolver tidak muncul di GraphQL schema

Penyebab:

- Resolver belum didaftarkan di module.
- Module belum diimport di `AppModule`.
- Decorator `@Resolver`, `@Query`, atau `@Mutation` salah import.

Solusi:

- Pastikan `ProjectsResolver` ada di `providers`.
- Pastikan `ProjectsModule` diimport di `AppModule`.
- Import decorator dari `@nestjs/graphql`.

### Provider repository tidak terdaftar

Gejala:

- Error dependency untuk `PROJECT_REPOSITORY`.

Solusi:

Pastikan provider ini ada:

```ts path=backend/src/modules/projects/presentation/projects.module.ts
{
  provide: PROJECT_REPOSITORY,
  useClass: PrismaProjectRepository,
}
```

### Nest cannot resolve dependency

Penyebab:

- Provider belum didaftarkan.
- Module yang menyediakan provider belum diimport.
- Token injection berbeda antara service dan module.

Solusi:

- Cek constructor service.
- Cek provider di module.
- Cek import path token `PROJECT_REPOSITORY`.

### PrismaService undefined

Penyebab:

- `PrismaModule` belum diimport.
- `PrismaService` belum diexport.
- Path import salah.

Solusi:

- Pastikan `PrismaModule` diimport di `AppModule`.
- Pastikan `PrismaModule` export `PrismaService`.

### Circular dependency antar module

Penyebab:

- Projects import Tasks, Tasks import Projects.
- Service saling memanggil langsung.

Solusi:

- Buat contract yang lebih kecil.
- Pindahkan orchestration ke application service yang tepat.
- Hindari module saling bergantung dua arah.

### GraphQL decorator salah import

Penyebab:

- Import `Field` atau `Resolver` dari package yang salah.

Solusi:

Gunakan:

```ts path=backend/src/modules/projects/presentation/dto/project.object.ts
import { Field, ObjectType } from '@nestjs/graphql';
```

### class-validator tidak jalan

Penyebab:

- `ValidationPipe` belum dipasang global.
- DTO tidak memakai decorator validator.
- Input tidak berbentuk class.

Solusi:

Pastikan `main.ts` punya:

```ts path=backend/src/main.ts
app.useGlobalPipes(
  new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  }),
);
```

### Path alias error

Penyebab:

- Menggunakan path alias seperti `@modules/projects` tetapi `tsconfig.json` belum disiapkan.

Solusi:

- Untuk awal, gunakan relative import dulu.
- Jika ingin alias, konfigurasi `paths` di `tsconfig.json` dan pastikan build tool mendukungnya.

### Common folder terlalu besar

Gejala:

- Banyak helper tidak berhubungan.
- Common import module domain.
- Common berisi rule project/task.

Solusi:

- Pindahkan helper spesifik ke module terkait.
- Common hanya untuk konsep generic.

### Business logic bocor ke resolver

Gejala:

- Resolver punya banyak `if/else`.
- Resolver query Prisma.
- Resolver mengatur state transition.

Solusi:

- Pindahkan use case ke service.
- Pindahkan business rule ke domain entity.
- Pindahkan query ke repository.

## Checklist Berhasil

- Struktur module Projects dibuat jelas.
- Domain tidak import Prisma, NestJS, atau GraphQL.
- Resolver hanya presentation layer.
- Service berisi use case.
- Repository interface ada di application.
- Prisma repository ada di infrastructure.
- Query project selalu filter `organizationId`.
- Common hanya berisi hal generic.
- AppModule import `ProjectsModule`.
- Tidak ada business logic berat di resolver.

## Langkah Berikutnya

Lanjutkan ke `backend/03-identity-auth.md` untuk membangun register, login, password hashing, JWT, guard, dan current user. Setelah auth selesai, placeholder `createdByUserId` di resolver Projects bisa diganti dengan user id dari token.

