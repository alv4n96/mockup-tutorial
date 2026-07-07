# Backend 05 - Project Module

Dokumen ini melanjutkan `backend/04-organization-tenancy.md`. Setelah aplikasi memiliki Identity/Auth dan Organization/Tenancy, sekarang kita membuat Project Module untuk SaaS Task Workspace.

Project selalu berada di dalam organization. Artinya setiap project wajib punya `organizationId`. Tanpa `organizationId`, backend tidak bisa memastikan tenant isolation, dan user dari organization lain bisa berisiko mengakses data yang bukan miliknya.

Hubungan utama:

```txt
User -> OrganizationMember -> Organization -> Project
```

Tenant isolation wajib dicek sebelum akses project karena:

- User hanya boleh melihat project dari organization tempat dia menjadi member.
- Project detail tidak boleh dicari hanya berdasarkan `projectId`.
- Update/archive project harus memastikan `organizationId` cocok.
- Project dan Task nanti akan memakai `organizationId` sebagai batas tenant.

## Konsep Dasar Project Module

Project adalah wadah pekerjaan di dalam organization. Contoh: `Website Redesign`, `Mobile App Launch`, atau `Internal Automation`.

Project owner/creator adalah user yang membuat project. Pada model awal, kita menyimpan `createdByUserId`. Ini bukan berarti hanya creator yang boleh mengakses project. Akses utama tetap berdasarkan membership organization.

Project status adalah state project. Status minimal:

- `DRAFT`: project baru dibuat dan belum aktif.
- `ACTIVE`: project sedang berjalan.
- `COMPLETED`: project selesai.
- `ARCHIVED`: project diarsipkan.

Project visibility dalam organization berarti semua member organization minimal bisa melihat project, selama rule business mengizinkan.

Organization membership adalah syarat dasar untuk melihat project. Jika user bukan member organization, dia tidak boleh melihat list, detail, update, atau archive project.

Perbedaan organization role dan project permission:

- Organization role: `OWNER`, `ADMIN`, `MEMBER`.
- Project permission: izin melakukan aksi project seperti view, create, update, archive.
- Di panduan ini, project permission diturunkan dari organization role.

Tenant isolation untuk project berarti semua query project wajib dibatasi oleh `organizationId`.

Project tidak boleh berdiri sendiri tanpa organization karena aplikasi SaaS membutuhkan batas tenant yang jelas. Project tanpa tenant membuat data sulit diamankan dan sulit ditagih per organization.

## Scope Fitur

Fitur yang dibuat:

- Create project.
- Get project list by organization.
- Get project detail.
- Update project.
- Archive project.
- Pagination.
- Search by name.
- Filter by status.
- Protected GraphQL resolver.
- Current user dari GraphQL auth guard.
- Authorization sederhana berdasarkan membership organization.
- Validation input.
- Error handling.
- Result pattern.
- Prisma repository.

Yang belum dibahas:

- Task CRUD.
- Assignee task.
- Project-level custom permission.
- Audit log project.

## Struktur Folder Projects

```txt
backend/src/modules/projects/
├── domain/
│   ├── project.entity.ts
│   └── project-status.enum.ts
│
├── application/
│   ├── project.service.ts
│   ├── project.repository.ts
│   └── organization-access-checker.ts
│
├── infrastructure/
│   ├── prisma-project.repository.ts
│   └── prisma-organization-access-checker.ts
│
└── presentation/
    ├── dto/
    │   ├── create-project.input.ts
    │   ├── update-project.input.ts
    │   ├── project-filter.input.ts
    │   ├── project.object.ts
    │   └── paged-project.response.ts
    ├── projects.resolver.ts
    └── projects.module.ts
```

Fungsi file:

- `project-status.enum.ts`: enum status project.
- `project.entity.ts`: entity domain dan business rule project.
- `project.repository.ts`: kontrak data access project.
- `organization-access-checker.ts`: kontrak pengecekan akses organization.
- `project.service.ts`: use case project.
- `prisma-project.repository.ts`: implementasi repository memakai Prisma.
- `prisma-organization-access-checker.ts`: implementasi cek membership memakai Prisma.
- `create-project.input.ts`: input GraphQL create project.
- `update-project.input.ts`: input GraphQL update project.
- `project-filter.input.ts`: input GraphQL list project, pagination, search, status.
- `project.object.ts`: response GraphQL project.
- `paged-project.response.ts`: response list project dengan metadata pagination.
- `projects.resolver.ts`: query/mutation GraphQL.
- `projects.module.ts`: registrasi provider module.

## Prisma Schema Project

Update `schema.prisma`:

```prisma path=backend/prisma/schema.prisma
enum ProjectStatus {
  DRAFT
  ACTIVE
  COMPLETED
  ARCHIVED
}

model Project {
  id              String        @id @default(cuid())
  organizationId  String
  name            String
  description     String?
  status          ProjectStatus @default(DRAFT)
  createdByUserId String
  createdAt       DateTime      @default(now())
  updatedAt       DateTime      @updatedAt
  archivedAt      DateTime?
  organization    Organization  @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  createdBy       User          @relation(fields: [createdByUserId], references: [id], onDelete: Restrict)

  @@index([organizationId])
  @@index([organizationId, status])
  @@index([organizationId, name])
}
```

Pastikan relasi balik ada di model `Organization` dan `User`:

```prisma path=backend/prisma/schema.prisma
model Organization {
  id        String               @id @default(cuid())
  name      String
  slug      String               @unique
  createdAt DateTime             @default(now())
  updatedAt DateTime             @updatedAt
  members   OrganizationMember[]
  projects  Project[]
}

model User {
  id              String               @id @default(cuid())
  email           String               @unique
  name            String
  passwordHash    String
  role            UserRole             @default(MEMBER)
  createdAt       DateTime             @default(now())
  updatedAt       DateTime             @updatedAt
  memberships     OrganizationMember[]
  createdProjects Project[]
}
```

Jalankan migration:

```bash
npx prisma migrate dev --name add_project_module
```

Penjelasan:

- `prisma migrate dev`: membuat dan menerapkan migration development.
- `--name add_project_module`: memberi nama migration agar mudah dilacak.

Generate Prisma Client:

```bash
npx prisma generate
```

Index penting untuk list project:

- `organizationId`: hampir semua query project memakai tenant filter.
- `organizationId + status`: list project sering difilter berdasarkan status.
- `organizationId + name`: search/sort sederhana by name dalam tenant lebih efisien.

Tanpa index, list project bisa lambat saat data tenant sudah besar.

## Domain Layer

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
  archivedAt?: Date | null;
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

    if (!input.organizationId) {
      return Result.fail(AppError.validation('ORGANIZATION_ID_REQUIRED', 'Organization id is required.'));
    }

    if (name.length < 3) {
      return Result.fail(AppError.validation('PROJECT_NAME_TOO_SHORT', 'Project name must be at least 3 characters.'));
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
        archivedAt: null,
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

      if (name.length < 3) {
        return Result.fail(AppError.validation('PROJECT_NAME_TOO_SHORT', 'Project name must be at least 3 characters.'));
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
    this.props.archivedAt = new Date();
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

Business rule yang cocok berada di domain:

- Nama project tidak boleh kosong/terlalu pendek.
- Archived project tidak boleh di-update.
- Project status transition seperti activate, complete, archive.
- `archivedAt` diisi saat project diarsipkan.

## Application Layer

Repository interface:

```ts path=backend/src/modules/projects/application/project.repository.ts
import { Project } from '../domain/project.entity';
import { ProjectStatus } from '../domain/project-status.enum';

export const PROJECT_REPOSITORY = Symbol('PROJECT_REPOSITORY');

export type ProjectListFilter = {
  organizationId: string;
  page: number;
  pageSize: number;
  search?: string;
  status?: ProjectStatus;
};

export type ProjectListResult = {
  items: Project[];
  totalItems: number;
};

export interface ProjectRepository {
  create(project: Project): Promise<Project>;
  findById(organizationId: string, projectId: string): Promise<Project | null>;
  findManyByOrganization(filter: ProjectListFilter): Promise<ProjectListResult>;
  update(project: Project): Promise<Project>;
  archive(project: Project): Promise<Project>;
}
```

Organization access checker:

```ts path=backend/src/modules/projects/application/organization-access-checker.ts
export const ORGANIZATION_ACCESS_CHECKER = Symbol('ORGANIZATION_ACCESS_CHECKER');

export type OrganizationAccessResult = {
  allowed: boolean;
  reason?: string;
};

export interface OrganizationAccessChecker {
  canViewOrganization(userId: string, organizationId: string): Promise<OrganizationAccessResult>;
  canCreateProject(userId: string, organizationId: string): Promise<OrganizationAccessResult>;
  canUpdateProject(userId: string, organizationId: string): Promise<OrganizationAccessResult>;
  canArchiveProject(userId: string, organizationId: string): Promise<OrganizationAccessResult>;
}
```

Service use case:

```ts path=backend/src/modules/projects/application/project.service.ts
import { Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { AppError } from '../../../common/errors/app-error';
import { Result } from '../../../common/result/result';
import { Project } from '../domain/project.entity';
import { ProjectStatus } from '../domain/project-status.enum';
import {
  ORGANIZATION_ACCESS_CHECKER,
  OrganizationAccessChecker,
} from './organization-access-checker';
import {
  PROJECT_REPOSITORY,
  ProjectListResult,
  ProjectRepository,
} from './project.repository';

export type CreateProjectCommand = {
  currentUserId: string;
  organizationId: string;
  name: string;
  description?: string | null;
};

export type UpdateProjectCommand = {
  currentUserId: string;
  organizationId: string;
  projectId: string;
  name?: string;
  description?: string | null;
};

export type GetProjectsQuery = {
  currentUserId: string;
  organizationId: string;
  page: number;
  pageSize: number;
  search?: string;
  status?: ProjectStatus;
};

@Injectable()
export class ProjectService {
  constructor(
    @Inject(PROJECT_REPOSITORY)
    private readonly projectRepository: ProjectRepository,
    @Inject(ORGANIZATION_ACCESS_CHECKER)
    private readonly organizationAccessChecker: OrganizationAccessChecker,
  ) {}

  async createProject(command: CreateProjectCommand): Promise<Result<Project>> {
    const access = await this.organizationAccessChecker.canCreateProject(command.currentUserId, command.organizationId);
    if (!access.allowed) {
      return Result.fail(AppError.forbidden('CANNOT_CREATE_PROJECT', access.reason ?? 'You cannot create project in this organization.'));
    }

    const projectOrError = Project.create({
      id: randomUUID(),
      organizationId: command.organizationId,
      name: command.name,
      description: command.description,
      createdByUserId: command.currentUserId,
    });

    if (projectOrError.isFail()) {
      return Result.fail(projectOrError.unwrapError());
    }

    const project = await this.projectRepository.create(projectOrError.unwrap());
    return Result.ok(project);
  }

  async getProjects(query: GetProjectsQuery): Promise<Result<ProjectListResult>> {
    const access = await this.organizationAccessChecker.canViewOrganization(query.currentUserId, query.organizationId);
    if (!access.allowed) {
      return Result.fail(AppError.forbidden('CANNOT_VIEW_ORGANIZATION', access.reason ?? 'You cannot view this organization.'));
    }

    const page = Math.max(query.page || 1, 1);
    const pageSize = Math.min(Math.max(query.pageSize || 20, 1), 100);

    const result = await this.projectRepository.findManyByOrganization({
      organizationId: query.organizationId,
      page,
      pageSize,
      search: query.search,
      status: query.status,
    });

    return Result.ok(result);
  }

  async getProjectDetail(currentUserId: string, organizationId: string, projectId: string): Promise<Result<Project>> {
    const access = await this.organizationAccessChecker.canViewOrganization(currentUserId, organizationId);
    if (!access.allowed) {
      return Result.fail(AppError.forbidden('CANNOT_VIEW_PROJECT', access.reason ?? 'You cannot view this project.'));
    }

    const project = await this.projectRepository.findById(organizationId, projectId);
    if (!project) {
      return Result.fail(AppError.notFound('PROJECT_NOT_FOUND', 'Project was not found.'));
    }

    return Result.ok(project);
  }

  async updateProject(command: UpdateProjectCommand): Promise<Result<Project>> {
    const access = await this.organizationAccessChecker.canUpdateProject(command.currentUserId, command.organizationId);
    if (!access.allowed) {
      return Result.fail(AppError.forbidden('CANNOT_UPDATE_PROJECT', access.reason ?? 'You cannot update project in this organization.'));
    }

    const projectOrError = await this.getProjectDetail(command.currentUserId, command.organizationId, command.projectId);
    if (projectOrError.isFail()) {
      return Result.fail(projectOrError.unwrapError());
    }

    const updatedOrError = projectOrError.unwrap().update({
      name: command.name,
      description: command.description,
    });

    if (updatedOrError.isFail()) {
      return Result.fail(updatedOrError.unwrapError());
    }

    const updated = await this.projectRepository.update(updatedOrError.unwrap());
    return Result.ok(updated);
  }

  async archiveProject(currentUserId: string, organizationId: string, projectId: string): Promise<Result<boolean>> {
    const access = await this.organizationAccessChecker.canArchiveProject(currentUserId, organizationId);
    if (!access.allowed) {
      return Result.fail(AppError.forbidden('CANNOT_ARCHIVE_PROJECT', access.reason ?? 'You cannot archive project in this organization.'));
    }

    const projectOrError = await this.getProjectDetail(currentUserId, organizationId, projectId);
    if (projectOrError.isFail()) {
      return Result.fail(projectOrError.unwrapError());
    }

    const archivedOrError = projectOrError.unwrap().archive();
    if (archivedOrError.isFail()) {
      return Result.fail(archivedOrError.unwrapError());
    }

    await this.projectRepository.archive(archivedOrError.unwrap());
    return Result.ok(true);
  }
}
```

Orchestration ada di service karena service tahu urutan use case: cek akses organization, load project dengan `organizationId + projectId`, jalankan domain rule, lalu simpan lewat repository. Resolver cukup meneruskan input dan mengembalikan output.

## Infrastructure Layer

Repository ini adalah Adapter dari interface application ke database. Semua query harus membawa `organizationId`.

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

type ProjectRecord = {
  id: string;
  organizationId: string;
  name: string;
  description: string | null;
  status: string;
  createdByUserId: string;
  createdAt: Date;
  updatedAt: Date;
  archivedAt: Date | null;
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
        archivedAt: props.archivedAt,
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

  async findManyByOrganization(filter: ProjectListFilter): Promise<ProjectListResult> {
    const page = Math.max(filter.page, 1);
    const pageSize = Math.min(Math.max(filter.pageSize, 1), 100);
    const skip = (page - 1) * pageSize;

    const where: Prisma.ProjectWhereInput = {
      organizationId: filter.organizationId,
      ...(filter.status ? { status: filter.status } : {}),
      ...(filter.search
        ? {
            name: {
              contains: filter.search,
              mode: 'insensitive',
            },
          }
        : {}),
    };

    const [items, totalItems] = await this.prisma.$transaction([
      this.prisma.project.findMany({
        where,
        orderBy: { updatedAt: 'desc' },
        skip,
        take: pageSize,
      }),
      this.prisma.project.count({ where }),
    ]);

    return {
      items: items.map((item) => this.toDomain(item)),
      totalItems,
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
        archivedAt: props.archivedAt,
      },
    });

    return this.toDomain(updated);
  }

  async archive(project: Project): Promise<Project> {
    return this.update(project);
  }

  private toDomain(record: ProjectRecord): Project {
    const props: ProjectProps = {
      id: record.id,
      organizationId: record.organizationId,
      name: record.name,
      description: record.description,
      status: record.status as ProjectStatus,
      createdByUserId: record.createdByUserId,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      archivedAt: record.archivedAt,
    };

    return Project.fromPersistence(props);
  }
}
```

Catatan penting: `update` memakai `id` karena project sudah diambil sebelumnya dengan `organizationId + projectId`. Jika ingin lebih ketat, gunakan `updateMany` dengan `where: { id, organizationId }`.

Organization access checker:

```ts path=backend/src/modules/projects/infrastructure/prisma-organization-access-checker.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import {
  OrganizationAccessChecker,
  OrganizationAccessResult,
} from '../application/organization-access-checker';

@Injectable()
export class PrismaOrganizationAccessChecker implements OrganizationAccessChecker {
  constructor(private readonly prisma: PrismaService) {}

  async canViewOrganization(userId: string, organizationId: string): Promise<OrganizationAccessResult> {
    const member = await this.findMember(userId, organizationId);

    if (!member) {
      return {
        allowed: false,
        reason: 'You are not a member of this organization.',
      };
    }

    return { allowed: true };
  }

  async canCreateProject(userId: string, organizationId: string): Promise<OrganizationAccessResult> {
    return this.canManageProject(userId, organizationId);
  }

  async canUpdateProject(userId: string, organizationId: string): Promise<OrganizationAccessResult> {
    return this.canManageProject(userId, organizationId);
  }

  async canArchiveProject(userId: string, organizationId: string): Promise<OrganizationAccessResult> {
    return this.canManageProject(userId, organizationId);
  }

  private async canManageProject(userId: string, organizationId: string): Promise<OrganizationAccessResult> {
    const member = await this.findMember(userId, organizationId);

    if (!member) {
      return {
        allowed: false,
        reason: 'You are not a member of this organization.',
      };
    }

    if (member.role !== 'OWNER' && member.role !== 'ADMIN') {
      return {
        allowed: false,
        reason: 'Only organization owner or admin can manage projects.',
      };
    }

    return { allowed: true };
  }

  private async findMember(userId: string, organizationId: string) {
    return this.prisma.organizationMember.findUnique({
      where: {
        organizationId_userId: {
          organizationId,
          userId,
        },
      },
    });
  }
}
```

## Presentation Layer - DTO/Object

```ts path=backend/src/modules/projects/presentation/dto/create-project.input.ts
import { Field, InputType } from '@nestjs/graphql';
import { IsNotEmpty, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

@InputType()
export class CreateProjectInput {
  @Field()
  @IsString()
  @IsNotEmpty()
  organizationId: string;

  @Field()
  @IsString()
  @MinLength(3)
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
import { IsNotEmpty, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

@InputType()
export class UpdateProjectInput {
  @Field()
  @IsString()
  @IsNotEmpty()
  organizationId: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(120)
  name?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;
}
```

```ts path=backend/src/modules/projects/presentation/dto/project-filter.input.ts
import { Field, InputType, Int, registerEnumType } from '@nestjs/graphql';
import { IsEnum, IsInt, IsNotEmpty, IsOptional, IsString, Max, Min } from 'class-validator';
import { ProjectStatus } from '../../domain/project-status.enum';

registerEnumType(ProjectStatus, {
  name: 'ProjectStatus',
});

@InputType()
export class ProjectFilterInput {
  @Field()
  @IsString()
  @IsNotEmpty()
  organizationId: string;

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

  @Field(() => ProjectStatus, { nullable: true })
  @IsOptional()
  @IsEnum(ProjectStatus)
  status?: ProjectStatus;
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

  @Field(() => ProjectStatus)
  status: ProjectStatus;

  @Field()
  createdByUserId: string;

  @Field()
  createdAt: Date;

  @Field()
  updatedAt: Date;

  @Field({ nullable: true })
  archivedAt?: Date | null;

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
    object.archivedAt = props.archivedAt;

    return object;
  }
}
```

```ts path=backend/src/modules/projects/presentation/dto/paged-project.response.ts
import { Field, Int, ObjectType } from '@nestjs/graphql';
import { ProjectObject } from './project.object';

@ObjectType()
export class ProjectPaginationMetadata {
  @Field(() => Int)
  page: number;

  @Field(() => Int)
  pageSize: number;

  @Field(() => Int)
  totalItems: number;

  @Field(() => Int)
  totalPages: number;
}

@ObjectType()
export class PagedProjectResponse {
  @Field(() => [ProjectObject])
  items: ProjectObject[];

  @Field(() => ProjectPaginationMetadata)
  metadata: ProjectPaginationMetadata;

  static create(items: ProjectObject[], page: number, pageSize: number, totalItems: number): PagedProjectResponse {
    const response = new PagedProjectResponse();
    const metadata = new ProjectPaginationMetadata();

    metadata.page = page;
    metadata.pageSize = pageSize;
    metadata.totalItems = totalItems;
    metadata.totalPages = Math.ceil(totalItems / pageSize);

    response.items = items;
    response.metadata = metadata;

    return response;
  }
}
```

`ProjectObject` tidak mengekspos data tenant lain. Semua field berasal dari project yang sudah melewati membership check.

## Presentation Layer - Resolver

Semua resolver protected dengan `GqlAuthGuard`. Semua operasi membawa `organizationId`.

```ts path=backend/src/modules/projects/presentation/projects.resolver.ts
import { UseGuards } from '@nestjs/common';
import { Args, Mutation, Query, Resolver } from '@nestjs/graphql';
import { GraphQLError } from 'graphql';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import {
  CurrentUserPayload,
  GqlAuthGuard,
} from '../../../common/guards/gql-auth.guard';
import { ProjectService } from '../application/project.service';
import { CreateProjectInput } from './dto/create-project.input';
import { PagedProjectResponse } from './dto/paged-project.response';
import { ProjectFilterInput } from './dto/project-filter.input';
import { ProjectObject } from './dto/project.object';
import { UpdateProjectInput } from './dto/update-project.input';

@UseGuards(GqlAuthGuard)
@Resolver(() => ProjectObject)
export class ProjectsResolver {
  constructor(private readonly projectService: ProjectService) {}

  @Mutation(() => ProjectObject)
  async createProject(
    @CurrentUser() currentUser: CurrentUserPayload,
    @Args('input') input: CreateProjectInput,
  ): Promise<ProjectObject> {
    const result = await this.projectService.createProject({
      currentUserId: currentUser.sub,
      organizationId: input.organizationId,
      name: input.name,
      description: input.description,
    });

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return ProjectObject.fromDomain(result.unwrap());
  }

  @Query(() => PagedProjectResponse)
  async projects(
    @CurrentUser() currentUser: CurrentUserPayload,
    @Args('filter') filter: ProjectFilterInput,
  ): Promise<PagedProjectResponse> {
    const page = filter.page ?? 1;
    const pageSize = filter.pageSize ?? 20;

    const result = await this.projectService.getProjects({
      currentUserId: currentUser.sub,
      organizationId: filter.organizationId,
      page,
      pageSize,
      search: filter.search,
      status: filter.status,
    });

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    const list = result.unwrap();
    return PagedProjectResponse.create(
      list.items.map(ProjectObject.fromDomain),
      page,
      pageSize,
      list.totalItems,
    );
  }

  @Query(() => ProjectObject)
  async project(
    @CurrentUser() currentUser: CurrentUserPayload,
    @Args('organizationId') organizationId: string,
    @Args('projectId') projectId: string,
  ): Promise<ProjectObject> {
    const result = await this.projectService.getProjectDetail(currentUser.sub, organizationId, projectId);

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return ProjectObject.fromDomain(result.unwrap());
  }

  @Mutation(() => ProjectObject)
  async updateProject(
    @CurrentUser() currentUser: CurrentUserPayload,
    @Args('projectId') projectId: string,
    @Args('input') input: UpdateProjectInput,
  ): Promise<ProjectObject> {
    const result = await this.projectService.updateProject({
      currentUserId: currentUser.sub,
      organizationId: input.organizationId,
      projectId,
      name: input.name,
      description: input.description,
    });

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return ProjectObject.fromDomain(result.unwrap());
  }

  @Mutation(() => Boolean)
  async archiveProject(
    @CurrentUser() currentUser: CurrentUserPayload,
    @Args('organizationId') organizationId: string,
    @Args('projectId') projectId: string,
  ): Promise<boolean> {
    const result = await this.projectService.archiveProject(currentUser.sub, organizationId, projectId);

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return result.unwrap();
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

Resolver tidak query Prisma langsung dan tidak menaruh business logic berat.

## Projects Module

```ts path=backend/src/modules/projects/presentation/projects.module.ts
import { Module } from '@nestjs/common';
import { PrismaModule } from '../../../infrastructure/prisma/prisma.module';
import { ORGANIZATION_ACCESS_CHECKER } from '../application/organization-access-checker';
import { PROJECT_REPOSITORY } from '../application/project.repository';
import { ProjectService } from '../application/project.service';
import { PrismaOrganizationAccessChecker } from '../infrastructure/prisma-organization-access-checker';
import { PrismaProjectRepository } from '../infrastructure/prisma-project.repository';
import { ProjectsResolver } from './projects.resolver';

@Module({
  imports: [PrismaModule],
  providers: [
    ProjectsResolver,
    ProjectService,
    {
      provide: PROJECT_REPOSITORY,
      useClass: PrismaProjectRepository,
    },
    {
      provide: ORGANIZATION_ACCESS_CHECKER,
      useClass: PrismaOrganizationAccessChecker,
    },
  ],
  exports: [ProjectService, ORGANIZATION_ACCESS_CHECKER],
})
export class ProjectsModule {}
```

Dependency injection bekerja seperti ini:

- `ProjectService` meminta `PROJECT_REPOSITORY` dan `ORGANIZATION_ACCESS_CHECKER`.
- `ProjectsModule` memetakan token ke class konkret.
- Resolver hanya tahu `ProjectService`.
- Resolver tidak perlu tahu concrete repository.

`ProjectsModule` perlu export service/checker jika module lain seperti Tasks butuh validasi project atau akses organization.

## AppModule Integration

```ts path=backend/src/app.module.ts
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { GraphQLModule } from '@nestjs/graphql';
import { join } from 'path';
import { PrismaModule } from './infrastructure/prisma/prisma.module';
import { HealthModule } from './modules/health/health.module';
import { IdentityModule } from './modules/identity/presentation/identity.module';
import { OrganizationsModule } from './modules/organizations/presentation/organizations.module';
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
      context: ({ req }) => ({ req }),
    }),
    PrismaModule,
    HealthModule,
    IdentityModule,
    OrganizationsModule,
    ProjectsModule,
  ],
})
export class AppModule {}
```

`AppModule` adalah root module. Feature module dipasang di root module, lalu resolver project masuk GraphQL schema otomatis.

## Tenant Isolation Rules

Aturan:

- User hanya boleh melihat project dari organization tempat dia menjadi member.
- User tidak boleh akses project dari organization lain.
- OWNER/ADMIN organization boleh create/update/archive project.
- MEMBER minimal boleh view project.
- Query project harus selalu filter `organizationId`.
- Detail/update/archive harus selalu cocokkan `organizationId + projectId`.

Contoh rule:

```txt
canViewProject:
  user adalah member organization
  project.organizationId sama dengan organizationId input

canCreateProject:
  user adalah OWNER atau ADMIN organization

canUpdateProject:
  user adalah OWNER atau ADMIN organization
  project.organizationId sama dengan organizationId input

canArchiveProject:
  user adalah OWNER atau ADMIN organization
  project.organizationId sama dengan organizationId input
```

## Pagination Dan Filtering

List project perlu pagination karena jumlah project bisa besar. Tanpa pagination, satu query bisa mengambil ribuan row dan membuat API lambat.

Parameter:

- `page`: halaman yang diminta, minimal 1.
- `pageSize`: jumlah item per halaman, minimal 1 dan maksimal 100.
- `search`: pencarian berdasarkan nama project.
- `status`: filter status project.

Batas maksimum `pageSize` mencegah client mengambil data terlalu besar dalam satu request.

Sorting default:

```txt
updatedAt desc
```

Artinya project yang terakhir berubah muncul lebih dulu. Alternatifnya `createdAt desc` jika ingin project terbaru muncul lebih dulu.

Response memakai metadata:

- `page`
- `pageSize`
- `totalItems`
- `totalPages`

## GraphQL Query/Mutation Examples

Semua query/mutation wajib memakai header:

```json
{
  "Authorization": "Bearer YOUR_ACCESS_TOKEN"
}
```

Create project:

```graphql
mutation {
  createProject(input: {
    organizationId: "org_123"
    name: "Website Redesign"
    description: "Redesign company website"
  }) {
    id
    organizationId
    name
    status
  }
}
```

List projects:

```graphql
query {
  projects(filter: {
    organizationId: "org_123"
    page: 1
    pageSize: 10
    search: "website"
    status: ACTIVE
  }) {
    items {
      id
      name
      status
    }
    metadata {
      page
      pageSize
      totalItems
      totalPages
    }
  }
}
```

Detail project:

```graphql
query {
  project(organizationId: "org_123", projectId: "project_123") {
    id
    name
    description
    status
  }
}
```

Update project:

```graphql
mutation {
  updateProject(
    projectId: "project_123"
    input: {
      organizationId: "org_123"
      name: "Website Redesign Phase 2"
      description: "Updated project description"
    }
  ) {
    id
    name
    description
  }
}
```

Archive project:

```graphql
mutation {
  archiveProject(organizationId: "org_123", projectId: "project_123")
}
```

## Cara Test Di GraphQL Playground/Sandbox

1. Login dulu dari file auth.
2. Copy `accessToken`.
3. Set HTTP header:

```json
{
  "Authorization": "Bearer YOUR_ACCESS_TOKEN"
}
```

4. Create organization dari file sebelumnya.
5. Jalankan `createProject`.
6. Jalankan `projects`.
7. Jalankan detail `project`.
8. Jalankan `updateProject`.
9. Jalankan `archiveProject`.

Jika user bukan member organization, query harus gagal. Jika user hanya `MEMBER`, create/update/archive harus gagal.

## Seed Project

Contoh seed idempotent:

```ts path=backend/prisma/seed.ts
import {
  OrganizationRole,
  PrismaClient,
  ProjectStatus,
  UserRole,
} from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash('Password123!', 12);

  const admin = await prisma.user.upsert({
    where: { email: 'admin@example.com' },
    update: {
      name: 'Admin User',
      role: UserRole.ADMIN,
      passwordHash,
    },
    create: {
      email: 'admin@example.com',
      name: 'Admin User',
      role: UserRole.ADMIN,
      passwordHash,
    },
  });

  const organization = await prisma.organization.upsert({
    where: { slug: 'acme-corp' },
    update: { name: 'Acme Corp' },
    create: {
      name: 'Acme Corp',
      slug: 'acme-corp',
    },
  });

  await prisma.organizationMember.upsert({
    where: {
      organizationId_userId: {
        organizationId: organization.id,
        userId: admin.id,
      },
    },
    update: { role: OrganizationRole.OWNER },
    create: {
      organizationId: organization.id,
      userId: admin.id,
      role: OrganizationRole.OWNER,
    },
  });

  const projects = [
    {
      name: 'Website Redesign',
      description: 'Redesign company website',
      status: ProjectStatus.ACTIVE,
    },
    {
      name: 'Mobile App Launch',
      description: 'Prepare mobile app launch',
      status: ProjectStatus.DRAFT,
    },
    {
      name: 'Internal Automation',
      description: 'Automate recurring operations tasks',
      status: ProjectStatus.COMPLETED,
    },
  ];

  for (const project of projects) {
    const existing = await prisma.project.findFirst({
      where: {
        organizationId: organization.id,
        name: project.name,
      },
    });

    if (existing) {
      await prisma.project.update({
        where: { id: existing.id },
        data: {
          description: project.description,
          status: project.status,
        },
      });
      continue;
    }

    await prisma.project.create({
      data: {
        organizationId: organization.id,
        name: project.name,
        description: project.description,
        status: project.status,
        createdByUserId: admin.id,
      },
    });
  }
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
```

Jalankan:

```bash
npm run db:seed
```

Penjelasan:

- `npm run db:seed` menjalankan seed dari `package.json`.
- Seed membuat admin user, sample organization, owner membership, dan sample projects.
- Seed idempotent karena mengecek project berdasarkan `organizationId + name`.

## Request Flow

Flow create project:

```txt
GraphQL Client
    |
    v
ProjectsResolver.createProject
    |
    v
GqlAuthGuard
    |
    v
CurrentUser
    |
    v
ProjectService.createProject
    |
    v
OrganizationAccessChecker
    |
    v
Project domain
    |
    v
ProjectRepository.create
    |
    v
Prisma
    |
    v
PostgreSQL
    |
    v
ProjectObject
```

Flow list project:

```txt
GraphQL Client
    |
    v
ProjectsResolver.projects
    |
    v
ProjectService.getProjects
    |
    v
OrganizationAccessChecker
    |
    v
ProjectRepository.findManyByOrganization
    |
    v
Prisma filter organizationId
    |
    v
PagedProjectResponse
```

## Error Handling

Error yang perlu ditangani:

- Organization tidak ditemukan: checker mengembalikan forbidden/not allowed.
- User bukan member organization: `CANNOT_VIEW_ORGANIZATION`.
- User tidak punya permission create/update/archive project: `CANNOT_CREATE_PROJECT`, `CANNOT_UPDATE_PROJECT`, `CANNOT_ARCHIVE_PROJECT`.
- Project tidak ditemukan: `PROJECT_NOT_FOUND`.
- Project bukan milik organization tersebut: dianggap `PROJECT_NOT_FOUND` karena query memakai `organizationId + projectId`.
- Name kosong/terlalu pendek: `PROJECT_NAME_TOO_SHORT`.
- Status invalid: ditangani GraphQL enum dan class-validator.
- Page/pageSize invalid: ditangani class-validator.
- Token kosong/invalid: ditangani `GqlAuthGuard`.

## Security Notes

- Jangan percaya `organizationId` dari frontend tanpa cek membership.
- Jangan query project hanya berdasarkan `projectId`.
- Jangan expose project organization lain.
- Role dan permission harus dicek di backend.
- Audit log create/update/archive project adalah improvement penting.
- Soft delete/archive lebih aman daripada hard delete.
- Rate limiting endpoint sensitif adalah improvement penting.
- Untuk project sensitif, tambahkan project-level permission nanti.

## Design Pattern Yang Relevan

Konsep pattern berikut memakai inspirasi umum dari katalog design pattern seperti Refactoring Guru, tetapi penjelasan dan contoh kode dibuat untuk stack ini.

### Repository Pattern

Masalah yang diselesaikan:

Service butuh akses project tanpa tahu detail Prisma.

Kenapa dipakai:

Query tenant project menjadi terpusat dan mudah dites.

File yang memakai:

- `backend/src/modules/projects/application/project.repository.ts`
- `backend/src/modules/projects/infrastructure/prisma-project.repository.ts`

Alternatif:

- Service langsung memakai Prisma. Lebih singkat, tetapi tenant filter mudah bocor.

### Adapter Pattern Melalui PrismaProjectRepository

Masalah yang diselesaikan:

Application layer punya interface repository, sedangkan database memakai Prisma.

Kenapa dipakai:

`PrismaProjectRepository` mengadaptasi Prisma Client menjadi kontrak application layer.

File yang memakai:

- `backend/src/modules/projects/infrastructure/prisma-project.repository.ts`

Alternatif:

- Memakai Prisma langsung di resolver/service.

### Facade Pattern Melalui ProjectsResolver Dan ProjectService

Masalah yang diselesaikan:

Client tidak perlu tahu detail access checker, repository, dan domain rule.

Kenapa dipakai:

Resolver dan service menyediakan operasi sederhana seperti create, list, update, archive.

File yang memakai:

- `backend/src/modules/projects/presentation/projects.resolver.ts`
- `backend/src/modules/projects/application/project.service.ts`

Alternatif:

- Banyak detail internal bocor ke API layer.

### Result Pattern

Masalah yang diselesaikan:

Business error seperti tidak punya permission atau project archived tidak harus menjadi exception teknis.

Kenapa dipakai:

Use case mengembalikan sukses/gagal secara eksplisit.

File yang memakai:

- `backend/src/modules/projects/domain/project.entity.ts`
- `backend/src/modules/projects/application/project.service.ts`

Alternatif:

- Throw exception untuk semua business error.

### Specification-like Filtering Untuk Search/Status

Masalah yang diselesaikan:

List project perlu filter yang bisa berkembang.

Kenapa dipakai:

Filter `organizationId`, `search`, dan `status` dikumpulkan dalam object filter.

File yang memakai:

- `backend/src/modules/projects/application/project.repository.ts`
- `backend/src/modules/projects/infrastructure/prisma-project.repository.ts`
- `backend/src/modules/projects/presentation/dto/project-filter.input.ts`

Alternatif:

- Banyak parameter method yang makin panjang.

### Policy/Strategy Preview Untuk Permission Rule

Masalah yang diselesaikan:

Permission project bisa bertambah kompleks.

Kenapa dipakai:

`OrganizationAccessChecker` bisa berkembang menjadi policy/strategy terpisah.

File yang memakai:

- `backend/src/modules/projects/application/organization-access-checker.ts`
- `backend/src/modules/projects/infrastructure/prisma-organization-access-checker.ts`

Alternatif:

- Banyak `if/else` permission langsung di resolver.

### Module Pattern NestJS

Masalah yang diselesaikan:

Provider project perlu dikelompokkan dalam module.

Kenapa dipakai:

NestJS module menjaga dependency registration tetap jelas.

File yang memakai:

- `backend/src/modules/projects/presentation/projects.module.ts`

Alternatif:

- Semua provider didaftarkan di `AppModule`.

### Dependency Injection

Masalah yang diselesaikan:

Service tidak membuat repository/checker sendiri.

Kenapa dipakai:

Implementation bisa diganti tanpa mengubah service.

File yang memakai:

- `backend/src/modules/projects/application/project.service.ts`
- `backend/src/modules/projects/presentation/projects.module.ts`

Alternatif:

- Membuat instance manual dengan `new`.

## Troubleshooting

### GqlAuthGuard unauthorized

Penyebab:

- Header kosong.
- Token invalid.
- Token expired.

Solusi:

- Login ulang.
- Set header `Authorization: Bearer YOUR_ACCESS_TOKEN`.

### CurrentUser undefined

Penyebab:

- Resolver tidak memakai guard.
- GraphQL context belum membawa `req`.

Solusi:

- Pastikan `@UseGuards(GqlAuthGuard)` ada.
- Pastikan `context: ({ req }) => ({ req })` ada di `GraphQLModule`.

### Project tidak muncul di list

Penyebab:

- `organizationId` salah.
- User bukan member organization.
- Filter status/search terlalu ketat.

Solusi:

- Cek membership.
- Cek data project.
- Jalankan list tanpa `search` dan `status`.

### Project detail 404 padahal project ada

Penyebab:

- Project ada di organization lain.
- Query memakai `organizationId` yang salah.

Solusi:

- Cek `project.organizationId`.
- Jangan query hanya dengan `projectId`.

### User tidak bisa create project padahal owner

Penyebab:

- Membership role tidak benar.
- Token user berbeda.
- Access checker membaca organizationId yang salah.

Solusi:

- Cek `OrganizationMember`.
- Cek token payload `sub`.

### Prisma relation error

Penyebab:

- `organizationId` tidak ada.
- `createdByUserId` tidak ada.

Solusi:

- Pastikan organization dibuat.
- Pastikan user login/seed ada.

### GraphQL enum ProjectStatus tidak muncul

Penyebab:

- Enum belum diregistrasi dengan `registerEnumType`.

Solusi:

- Pastikan `registerEnumType(ProjectStatus, { name: 'ProjectStatus' })` dipanggil.

### Nest cannot resolve dependency

Penyebab:

- Provider token belum didaftarkan.
- `PrismaModule` belum diimport.

Solusi:

- Cek `ProjectsModule`.
- Pastikan `PROJECT_REPOSITORY` dan `ORGANIZATION_ACCESS_CHECKER` punya provider mapping.

### Resolver tidak muncul di schema

Penyebab:

- `ProjectsModule` belum diimport di `AppModule`.
- `ProjectsResolver` belum masuk providers.

Solusi:

- Import `ProjectsModule`.
- Tambahkan resolver ke providers.

### Pagination tidak benar

Penyebab:

- `skip` salah hitung.
- `pageSize` tidak dibatasi.
- `totalItems` tidak memakai filter yang sama.

Solusi:

- Pakai `skip = (page - 1) * pageSize`.
- Batasi `pageSize` maksimal 100.
- Pakai `where` yang sama untuk `findMany` dan `count`.

### Query lambat karena index belum dibuat

Penyebab:

- Table project besar dan query filter `organizationId/status/name` tanpa index.

Solusi:

- Tambahkan index di Prisma schema.
- Jalankan migration.

## Checklist Berhasil

- Prisma model `Project` tersedia.
- Migration project berhasil.
- User login bisa create project.
- Project selalu punya `organizationId`.
- List project hanya menampilkan project dari organization terkait.
- Detail project tidak bisa diakses dari organization lain.
- Search project by name berhasil.
- Filter project by status berhasil.
- Update project berhasil.
- Archive project berhasil.
- `ProjectsResolver` protected dengan `GqlAuthGuard`.
- `ProjectsModule` terdaftar di `AppModule`.
- Tidak ada business logic berat di resolver.
- Query selalu memperhatikan tenant isolation.

## Langkah Berikutnya

Lanjutkan ke `backend/06-task-module.md` untuk membuat Task Module. Task wajib terhubung ke Project dan tetap menjaga tenant isolation melalui `organizationId` dan project membership.

