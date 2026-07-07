# Backend 06 - Task Module

Dokumen ini melanjutkan `backend/05-project-module.md`. Setelah Project Module siap dengan `organizationId`, access checker, pagination, filtering, dan resolver protected, sekarang kita membuat Task Module.

Task adalah unit kerja di dalam project. Dalam SaaS Task Workspace, task tidak boleh berdiri sendiri. Setiap task wajib punya:

- `organizationId`: batas tenant.
- `projectId`: project tempat task berada.

Tenant isolation wajib dicek sebelum akses task karena task adalah data operasional yang sensitif. Query task tidak boleh hanya berdasarkan `taskId`; semua detail/update/assign/change status/archive harus memakai kombinasi:

```txt
organizationId + projectId + taskId
```

Hubungan utama:

```txt
Organization -> Project -> Task
User -> OrganizationMember -> akses Project/Task
```

## Konsep Dasar Task Module

Task adalah pekerjaan yang perlu diselesaikan dalam project. Contoh: `Design login page`, `Implement project API`, atau `Review deployment manifest`.

Project adalah wadah task. Task selalu berada di dalam satu project.

Assignee adalah user yang ditugaskan mengerjakan task. Field yang dipakai adalah `assignedToUserId`.

Reporter/creator adalah user yang membuat task. Field yang dipakai adalah `createdByUserId`. Backend mengambil nilai ini dari current user, bukan dari input frontend.

Task status adalah state pekerjaan. Status minimal:

- `TODO`
- `IN_PROGRESS`
- `IN_REVIEW`
- `DONE`
- `ARCHIVED`

Task priority adalah tingkat kepentingan task:

- `LOW`
- `MEDIUM`
- `HIGH`
- `CRITICAL`

Due date adalah tanggal target penyelesaian task.

Tenant isolation berarti task hanya bisa diakses oleh user yang menjadi member organization terkait.

Project access berarti user harus punya akses ke project yang berada di organization tersebut.

Task harus difilter berdasarkan `organizationId` dan `projectId` agar data organization/project lain tidak bocor. Status workflow juga jangan ditaruh langsung di resolver karena rule transisi status bisa berubah, bertambah, atau berbeda antar tipe bisnis. Resolver harus tetap tipis.

## Scope Fitur

Fitur yang dibuat:

- Create task.
- Get task list by organization + project.
- Get task detail.
- Update task.
- Assign task ke user.
- Change task status.
- Archive task.
- Pagination.
- Search by title.
- Filter by status.
- Filter by priority.
- Filter by assignee.
- Protected GraphQL resolver.
- Current user dari GraphQL auth guard.
- Authorization sederhana berdasarkan access organization/project.
- Validation input.
- Error handling.
- Result pattern.
- Prisma repository.
- Strategy Pattern untuk status transition.

## Struktur Folder Tasks

```txt
backend/src/modules/tasks/
├── domain/
│   ├── task.entity.ts
│   ├── task-status.enum.ts
│   └── task-priority.enum.ts
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
    ├── dto/
    │   ├── create-task.input.ts
    │   ├── update-task.input.ts
    │   ├── assign-task.input.ts
    │   ├── change-task-status.input.ts
    │   ├── task-filter.input.ts
    │   ├── task.object.ts
    │   └── paged-task.response.ts
    ├── tasks.resolver.ts
    └── tasks.module.ts
```

Fungsi file:

- `task-status.enum.ts`: enum status task.
- `task-priority.enum.ts`: enum priority task.
- `task.entity.ts`: entity domain dan rule task.
- `task.repository.ts`: kontrak data access task.
- `project-access-checker.ts`: kontrak pengecekan akses project.
- `task-status-transition.strategy.ts`: kontrak Strategy untuk perubahan status.
- `task.service.ts`: use case task.
- `prisma-task.repository.ts`: implementasi repository memakai Prisma.
- `prisma-project-access-checker.ts`: implementasi cek akses project memakai Prisma.
- `default-task-status-transition.strategy.ts`: rule status transition default.
- `dto/*`: GraphQL input/output.
- `tasks.resolver.ts`: query/mutation GraphQL.
- `tasks.module.ts`: registrasi provider module.

## Prisma Schema Task

Update `schema.prisma`:

```prisma path=backend/prisma/schema.prisma
enum TaskStatus {
  TODO
  IN_PROGRESS
  IN_REVIEW
  DONE
  ARCHIVED
}

enum TaskPriority {
  LOW
  MEDIUM
  HIGH
  CRITICAL
}

model Task {
  id               String       @id @default(cuid())
  organizationId   String
  projectId        String
  title            String
  description      String?
  status           TaskStatus   @default(TODO)
  priority         TaskPriority @default(MEDIUM)
  assignedToUserId String?
  createdByUserId  String
  dueDate          DateTime?
  createdAt        DateTime     @default(now())
  updatedAt        DateTime     @updatedAt
  archivedAt       DateTime?
  organization     Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  project          Project      @relation(fields: [projectId], references: [id], onDelete: Cascade)
  createdBy        User         @relation("TaskCreator", fields: [createdByUserId], references: [id], onDelete: Restrict)
  assignedTo       User?        @relation("TaskAssignee", fields: [assignedToUserId], references: [id], onDelete: SetNull)

  @@index([organizationId, projectId])
  @@index([organizationId, projectId, status])
  @@index([organizationId, projectId, priority])
  @@index([assignedToUserId])
  @@index([dueDate])
}
```

Tambahkan relasi balik:

```prisma path=backend/prisma/schema.prisma
model Organization {
  id        String               @id @default(cuid())
  name      String
  slug      String               @unique
  createdAt DateTime             @default(now())
  updatedAt DateTime             @updatedAt
  members   OrganizationMember[]
  projects  Project[]
  tasks     Task[]
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
  tasks           Task[]
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
  createdTasks    Task[]               @relation("TaskCreator")
  assignedTasks   Task[]               @relation("TaskAssignee")
}
```

Jalankan migration:

```bash
npx prisma migrate dev --name add_task_module
```

Generate Prisma Client:

```bash
npx prisma generate
```

Index penting untuk list task:

- `organizationId + projectId`: filter utama tenant dan project.
- `organizationId + projectId + status`: list task by status.
- `organizationId + projectId + priority`: list task by priority.
- `assignedToUserId`: halaman task yang ditugaskan ke user.
- `dueDate`: sorting/filter due date nanti.

## Domain Layer

```ts path=backend/src/modules/tasks/domain/task-status.enum.ts
export enum TaskStatus {
  TODO = 'TODO',
  IN_PROGRESS = 'IN_PROGRESS',
  IN_REVIEW = 'IN_REVIEW',
  DONE = 'DONE',
  ARCHIVED = 'ARCHIVED',
}
```

```ts path=backend/src/modules/tasks/domain/task-priority.enum.ts
export enum TaskPriority {
  LOW = 'LOW',
  MEDIUM = 'MEDIUM',
  HIGH = 'HIGH',
  CRITICAL = 'CRITICAL',
}
```

```ts path=backend/src/modules/tasks/domain/task.entity.ts
import { AppError } from '../../../common/errors/app-error';
import { Result } from '../../../common/result/result';
import { TaskPriority } from './task-priority.enum';
import { TaskStatus } from './task-status.enum';

export type TaskProps = {
  id: string;
  organizationId: string;
  projectId: string;
  title: string;
  description?: string | null;
  status: TaskStatus;
  priority: TaskPriority;
  assignedToUserId?: string | null;
  createdByUserId: string;
  dueDate?: Date | null;
  createdAt: Date;
  updatedAt: Date;
  archivedAt?: Date | null;
};

export type CreateTaskProps = {
  id: string;
  organizationId: string;
  projectId: string;
  title: string;
  description?: string | null;
  priority?: TaskPriority;
  assignedToUserId?: string | null;
  createdByUserId: string;
  dueDate?: Date | null;
};

export type UpdateTaskProps = {
  title?: string;
  description?: string | null;
  priority?: TaskPriority;
  dueDate?: Date | null;
};

export class Task {
  private constructor(private readonly props: TaskProps) {}

  static create(input: CreateTaskProps): Result<Task> {
    const title = input.title.trim();

    if (!input.organizationId || !input.projectId) {
      return Result.fail(AppError.validation('TASK_SCOPE_REQUIRED', 'Organization id and project id are required.'));
    }

    if (title.length < 3) {
      return Result.fail(AppError.validation('TASK_TITLE_TOO_SHORT', 'Task title must be at least 3 characters.'));
    }

    const now = new Date();

    return Result.ok(
      new Task({
        id: input.id,
        organizationId: input.organizationId,
        projectId: input.projectId,
        title,
        description: input.description?.trim() || null,
        status: TaskStatus.TODO,
        priority: input.priority ?? TaskPriority.MEDIUM,
        assignedToUserId: input.assignedToUserId ?? null,
        createdByUserId: input.createdByUserId,
        dueDate: input.dueDate ?? null,
        createdAt: now,
        updatedAt: now,
        archivedAt: null,
      }),
    );
  }

  static fromPersistence(props: TaskProps): Task {
    return new Task(props);
  }

  update(input: UpdateTaskProps): Result<Task> {
    if (this.props.status === TaskStatus.ARCHIVED) {
      return Result.fail(AppError.conflict('TASK_ARCHIVED', 'Archived task cannot be updated.'));
    }

    if (input.title !== undefined) {
      const title = input.title.trim();
      if (title.length < 3) {
        return Result.fail(AppError.validation('TASK_TITLE_TOO_SHORT', 'Task title must be at least 3 characters.'));
      }
      this.props.title = title;
    }

    if (input.description !== undefined) {
      this.props.description = input.description?.trim() || null;
    }

    if (input.priority !== undefined) {
      this.props.priority = input.priority;
    }

    if (input.dueDate !== undefined) {
      this.props.dueDate = input.dueDate;
    }

    this.touch();
    return Result.ok(this);
  }

  assignTo(userId: string | null): Result<Task> {
    if (this.props.status === TaskStatus.ARCHIVED) {
      return Result.fail(AppError.conflict('TASK_ARCHIVED', 'Archived task cannot be assigned.'));
    }

    this.props.assignedToUserId = userId;
    this.touch();
    return Result.ok(this);
  }

  changeStatus(status: TaskStatus): Result<Task> {
    if (this.props.status === TaskStatus.ARCHIVED) {
      return Result.fail(AppError.conflict('TASK_ARCHIVED', 'Archived task cannot change status.'));
    }

    this.props.status = status;
    this.touch();
    return Result.ok(this);
  }

  archive(): Result<Task> {
    if (this.props.status === TaskStatus.ARCHIVED) {
      return Result.ok(this);
    }

    this.props.status = TaskStatus.ARCHIVED;
    this.props.archivedAt = new Date();
    this.touch();
    return Result.ok(this);
  }

  toProps(): TaskProps {
    return { ...this.props };
  }

  private touch(): void {
    this.props.updatedAt = new Date();
  }
}
```

Business rule yang cocok di domain entity:

- Title minimal 3 karakter.
- Archived task tidak boleh di-update atau di-assign.
- Archive mengisi `archivedAt`.
- Domain entity tidak query database; cek akses dan existence dilakukan service/repository.

## Application Layer

```ts path=backend/src/modules/tasks/application/task.repository.ts
import { Task } from '../domain/task.entity';
import { TaskPriority } from '../domain/task-priority.enum';
import { TaskStatus } from '../domain/task-status.enum';

export const TASK_REPOSITORY = Symbol('TASK_REPOSITORY');

export type TaskListFilter = {
  organizationId: string;
  projectId: string;
  page: number;
  pageSize: number;
  search?: string;
  status?: TaskStatus;
  priority?: TaskPriority;
  assignedToUserId?: string;
};

export type TaskListResult = {
  items: Task[];
  totalItems: number;
};

export interface TaskRepository {
  create(task: Task): Promise<Task>;
  findById(organizationId: string, projectId: string, taskId: string): Promise<Task | null>;
  findManyByProject(filter: TaskListFilter): Promise<TaskListResult>;
  update(task: Task): Promise<Task>;
  archive(task: Task): Promise<Task>;
}
```

```ts path=backend/src/modules/tasks/application/project-access-checker.ts
export const PROJECT_ACCESS_CHECKER = Symbol('PROJECT_ACCESS_CHECKER');

export type ProjectAccessResult = {
  allowed: boolean;
  reason?: string;
};

export interface ProjectAccessChecker {
  canViewProject(userId: string, organizationId: string, projectId: string): Promise<ProjectAccessResult>;
  canCreateTask(userId: string, organizationId: string, projectId: string): Promise<ProjectAccessResult>;
  canUpdateTask(userId: string, organizationId: string, projectId: string): Promise<ProjectAccessResult>;
  canAssignTask(userId: string, organizationId: string, projectId: string): Promise<ProjectAccessResult>;
  canChangeTaskStatus(userId: string, organizationId: string, projectId: string, assignedToUserId?: string | null): Promise<ProjectAccessResult>;
  canArchiveTask(userId: string, organizationId: string, projectId: string): Promise<ProjectAccessResult>;
}
```

```ts path=backend/src/modules/tasks/application/task-status-transition.strategy.ts
import { AppError } from '../../../common/errors/app-error';
import { Result } from '../../../common/result/result';
import { TaskStatus } from '../domain/task-status.enum';

export const TASK_STATUS_TRANSITION_STRATEGY = Symbol('TASK_STATUS_TRANSITION_STRATEGY');

export interface TaskStatusTransitionStrategy {
  canTransition(from: TaskStatus, to: TaskStatus): boolean;
  assertCanTransition(from: TaskStatus, to: TaskStatus): Result<void>;
}
```

```ts path=backend/src/modules/tasks/application/task.service.ts
import { Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { AppError } from '../../../common/errors/app-error';
import { Result } from '../../../common/result/result';
import { Task } from '../domain/task.entity';
import { TaskPriority } from '../domain/task-priority.enum';
import { TaskStatus } from '../domain/task-status.enum';
import {
  PROJECT_ACCESS_CHECKER,
  ProjectAccessChecker,
} from './project-access-checker';
import {
  TASK_REPOSITORY,
  TaskListResult,
  TaskRepository,
} from './task.repository';
import {
  TASK_STATUS_TRANSITION_STRATEGY,
  TaskStatusTransitionStrategy,
} from './task-status-transition.strategy';

export type CreateTaskCommand = {
  currentUserId: string;
  organizationId: string;
  projectId: string;
  title: string;
  description?: string | null;
  priority?: TaskPriority;
  assignedToUserId?: string | null;
  dueDate?: Date | null;
};

export type UpdateTaskCommand = {
  currentUserId: string;
  organizationId: string;
  projectId: string;
  taskId: string;
  title?: string;
  description?: string | null;
  priority?: TaskPriority;
  dueDate?: Date | null;
};

export type GetTasksQuery = {
  currentUserId: string;
  organizationId: string;
  projectId: string;
  page: number;
  pageSize: number;
  search?: string;
  status?: TaskStatus;
  priority?: TaskPriority;
  assignedToUserId?: string;
};

@Injectable()
export class TaskService {
  constructor(
    @Inject(TASK_REPOSITORY)
    private readonly taskRepository: TaskRepository,
    @Inject(PROJECT_ACCESS_CHECKER)
    private readonly projectAccessChecker: ProjectAccessChecker,
    @Inject(TASK_STATUS_TRANSITION_STRATEGY)
    private readonly statusTransitionStrategy: TaskStatusTransitionStrategy,
  ) {}

  async createTask(command: CreateTaskCommand): Promise<Result<Task>> {
    const access = await this.projectAccessChecker.canCreateTask(command.currentUserId, command.organizationId, command.projectId);
    if (!access.allowed) {
      return Result.fail(AppError.forbidden('CANNOT_CREATE_TASK', access.reason ?? 'You cannot create task in this project.'));
    }

    const taskOrError = Task.create({
      id: randomUUID(),
      organizationId: command.organizationId,
      projectId: command.projectId,
      title: command.title,
      description: command.description,
      priority: command.priority,
      assignedToUserId: command.assignedToUserId,
      createdByUserId: command.currentUserId,
      dueDate: command.dueDate,
    });

    if (taskOrError.isFail()) {
      return Result.fail(taskOrError.unwrapError());
    }

    return Result.ok(await this.taskRepository.create(taskOrError.unwrap()));
  }

  async getTasks(query: GetTasksQuery): Promise<Result<TaskListResult>> {
    const access = await this.projectAccessChecker.canViewProject(query.currentUserId, query.organizationId, query.projectId);
    if (!access.allowed) {
      return Result.fail(AppError.forbidden('CANNOT_VIEW_TASKS', access.reason ?? 'You cannot view tasks in this project.'));
    }

    return Result.ok(
      await this.taskRepository.findManyByProject({
        ...query,
        page: Math.max(query.page || 1, 1),
        pageSize: Math.min(Math.max(query.pageSize || 20, 1), 100),
      }),
    );
  }

  async getTaskDetail(currentUserId: string, organizationId: string, projectId: string, taskId: string): Promise<Result<Task>> {
    const access = await this.projectAccessChecker.canViewProject(currentUserId, organizationId, projectId);
    if (!access.allowed) {
      return Result.fail(AppError.forbidden('CANNOT_VIEW_TASK', access.reason ?? 'You cannot view this task.'));
    }

    const task = await this.taskRepository.findById(organizationId, projectId, taskId);
    if (!task) {
      return Result.fail(AppError.notFound('TASK_NOT_FOUND', 'Task was not found.'));
    }

    return Result.ok(task);
  }

  async updateTask(command: UpdateTaskCommand): Promise<Result<Task>> {
    const access = await this.projectAccessChecker.canUpdateTask(command.currentUserId, command.organizationId, command.projectId);
    if (!access.allowed) {
      return Result.fail(AppError.forbidden('CANNOT_UPDATE_TASK', access.reason ?? 'You cannot update this task.'));
    }

    const taskOrError = await this.getTaskDetail(command.currentUserId, command.organizationId, command.projectId, command.taskId);
    if (taskOrError.isFail()) {
      return Result.fail(taskOrError.unwrapError());
    }

    const updatedOrError = taskOrError.unwrap().update(command);
    if (updatedOrError.isFail()) {
      return Result.fail(updatedOrError.unwrapError());
    }

    return Result.ok(await this.taskRepository.update(updatedOrError.unwrap()));
  }

  async assignTask(currentUserId: string, organizationId: string, projectId: string, taskId: string, assignedToUserId: string | null): Promise<Result<Task>> {
    const access = await this.projectAccessChecker.canAssignTask(currentUserId, organizationId, projectId);
    if (!access.allowed) {
      return Result.fail(AppError.forbidden('CANNOT_ASSIGN_TASK', access.reason ?? 'You cannot assign this task.'));
    }

    const taskOrError = await this.getTaskDetail(currentUserId, organizationId, projectId, taskId);
    if (taskOrError.isFail()) {
      return Result.fail(taskOrError.unwrapError());
    }

    const assignedOrError = taskOrError.unwrap().assignTo(assignedToUserId);
    if (assignedOrError.isFail()) {
      return Result.fail(assignedOrError.unwrapError());
    }

    return Result.ok(await this.taskRepository.update(assignedOrError.unwrap()));
  }

  async changeTaskStatus(currentUserId: string, organizationId: string, projectId: string, taskId: string, status: TaskStatus): Promise<Result<Task>> {
    const taskOrError = await this.getTaskDetail(currentUserId, organizationId, projectId, taskId);
    if (taskOrError.isFail()) {
      return Result.fail(taskOrError.unwrapError());
    }

    const task = taskOrError.unwrap();
    const props = task.toProps();
    const access = await this.projectAccessChecker.canChangeTaskStatus(currentUserId, organizationId, projectId, props.assignedToUserId);
    if (!access.allowed) {
      return Result.fail(AppError.forbidden('CANNOT_CHANGE_TASK_STATUS', access.reason ?? 'You cannot change this task status.'));
    }

    const transition = this.statusTransitionStrategy.assertCanTransition(props.status, status);
    if (transition.isFail()) {
      return Result.fail(transition.unwrapError());
    }

    const changedOrError = task.changeStatus(status);
    if (changedOrError.isFail()) {
      return Result.fail(changedOrError.unwrapError());
    }

    return Result.ok(await this.taskRepository.update(changedOrError.unwrap()));
  }

  async archiveTask(currentUserId: string, organizationId: string, projectId: string, taskId: string): Promise<Result<boolean>> {
    const access = await this.projectAccessChecker.canArchiveTask(currentUserId, organizationId, projectId);
    if (!access.allowed) {
      return Result.fail(AppError.forbidden('CANNOT_ARCHIVE_TASK', access.reason ?? 'You cannot archive this task.'));
    }

    const taskOrError = await this.getTaskDetail(currentUserId, organizationId, projectId, taskId);
    if (taskOrError.isFail()) {
      return Result.fail(taskOrError.unwrapError());
    }

    const archivedOrError = taskOrError.unwrap().archive();
    if (archivedOrError.isFail()) {
      return Result.fail(archivedOrError.unwrapError());
    }

    await this.taskRepository.archive(archivedOrError.unwrap());
    return Result.ok(true);
  }
}
```

Orchestration ada di service karena service mengatur urutan: cek akses project, ambil task dengan scope tenant, jalankan Strategy status, jalankan domain method, lalu simpan.

## Strategy Pattern Untuk Task Status

Strategy Pattern menyelesaikan masalah rule status transition yang bisa berubah. Jika semua rule ditaruh di resolver, resolver akan penuh `if/else`, sulit dites, dan sulit diganti.

Workflow task sering berubah tergantung bisnis. Misalnya saat QA ditambahkan, status `IN_REVIEW` bisa punya aturan baru. Strategy cocok karena rule dipindah ke class khusus dan di-inject lewat interface.

Rule status:

```txt
TODO -> IN_PROGRESS, ARCHIVED
IN_PROGRESS -> IN_REVIEW, DONE, ARCHIVED
IN_REVIEW -> IN_PROGRESS, DONE, ARCHIVED
DONE -> ARCHIVED
ARCHIVED -> tidak boleh pindah
```

```ts path=backend/src/modules/tasks/infrastructure/default-task-status-transition.strategy.ts
import { Injectable } from '@nestjs/common';
import { AppError } from '../../../common/errors/app-error';
import { Result } from '../../../common/result/result';
import { TaskStatusTransitionStrategy } from '../application/task-status-transition.strategy';
import { TaskStatus } from '../domain/task-status.enum';

@Injectable()
export class DefaultTaskStatusTransitionStrategy implements TaskStatusTransitionStrategy {
  private readonly allowedTransitions: Record<TaskStatus, TaskStatus[]> = {
    [TaskStatus.TODO]: [TaskStatus.IN_PROGRESS, TaskStatus.ARCHIVED],
    [TaskStatus.IN_PROGRESS]: [TaskStatus.IN_REVIEW, TaskStatus.DONE, TaskStatus.ARCHIVED],
    [TaskStatus.IN_REVIEW]: [TaskStatus.IN_PROGRESS, TaskStatus.DONE, TaskStatus.ARCHIVED],
    [TaskStatus.DONE]: [TaskStatus.ARCHIVED],
    [TaskStatus.ARCHIVED]: [],
  };

  canTransition(from: TaskStatus, to: TaskStatus): boolean {
    if (from === to) {
      return true;
    }

    return this.allowedTransitions[from].includes(to);
  }

  assertCanTransition(from: TaskStatus, to: TaskStatus): Result<void> {
    if (!this.canTransition(from, to)) {
      return Result.fail(
        AppError.conflict(
          'INVALID_TASK_STATUS_TRANSITION',
          `Task status cannot transition from ${from} to ${to}.`,
        ),
      );
    }

    return Result.ok(undefined);
  }
}
```

## Infrastructure Layer

```ts path=backend/src/modules/tasks/infrastructure/prisma-task.repository.ts
import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import {
  TaskListFilter,
  TaskListResult,
  TaskRepository,
} from '../application/task.repository';
import { Task, TaskProps } from '../domain/task.entity';
import { TaskPriority } from '../domain/task-priority.enum';
import { TaskStatus } from '../domain/task-status.enum';

type TaskRecord = {
  id: string;
  organizationId: string;
  projectId: string;
  title: string;
  description: string | null;
  status: string;
  priority: string;
  assignedToUserId: string | null;
  createdByUserId: string;
  dueDate: Date | null;
  createdAt: Date;
  updatedAt: Date;
  archivedAt: Date | null;
};

@Injectable()
export class PrismaTaskRepository implements TaskRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(task: Task): Promise<Task> {
    const props = task.toProps();

    const created = await this.prisma.task.create({
      data: {
        id: props.id,
        organizationId: props.organizationId,
        projectId: props.projectId,
        title: props.title,
        description: props.description,
        status: props.status,
        priority: props.priority,
        assignedToUserId: props.assignedToUserId,
        createdByUserId: props.createdByUserId,
        dueDate: props.dueDate,
        createdAt: props.createdAt,
        updatedAt: props.updatedAt,
        archivedAt: props.archivedAt,
      },
    });

    return this.toDomain(created);
  }

  async findById(organizationId: string, projectId: string, taskId: string): Promise<Task | null> {
    const task = await this.prisma.task.findFirst({
      where: {
        id: taskId,
        organizationId,
        projectId,
      },
    });

    return task ? this.toDomain(task) : null;
  }

  async findManyByProject(filter: TaskListFilter): Promise<TaskListResult> {
    const page = Math.max(filter.page, 1);
    const pageSize = Math.min(Math.max(filter.pageSize, 1), 100);
    const skip = (page - 1) * pageSize;

    const where: Prisma.TaskWhereInput = {
      organizationId: filter.organizationId,
      projectId: filter.projectId,
      ...(filter.status ? { status: filter.status } : {}),
      ...(filter.priority ? { priority: filter.priority } : {}),
      ...(filter.assignedToUserId ? { assignedToUserId: filter.assignedToUserId } : {}),
      ...(filter.search
        ? {
            title: {
              contains: filter.search,
              mode: 'insensitive',
            },
          }
        : {}),
    };

    const [items, totalItems] = await this.prisma.$transaction([
      this.prisma.task.findMany({
        where,
        orderBy: { updatedAt: 'desc' },
        skip,
        take: pageSize,
      }),
      this.prisma.task.count({ where }),
    ]);

    return {
      items: items.map((item) => this.toDomain(item)),
      totalItems,
    };
  }

  async update(task: Task): Promise<Task> {
    const props = task.toProps();

    const updated = await this.prisma.task.update({
      where: { id: props.id },
      data: {
        title: props.title,
        description: props.description,
        status: props.status,
        priority: props.priority,
        assignedToUserId: props.assignedToUserId,
        dueDate: props.dueDate,
        updatedAt: props.updatedAt,
        archivedAt: props.archivedAt,
      },
    });

    return this.toDomain(updated);
  }

  async archive(task: Task): Promise<Task> {
    return this.update(task);
  }

  private toDomain(record: TaskRecord): Task {
    const props: TaskProps = {
      id: record.id,
      organizationId: record.organizationId,
      projectId: record.projectId,
      title: record.title,
      description: record.description,
      status: record.status as TaskStatus,
      priority: record.priority as TaskPriority,
      assignedToUserId: record.assignedToUserId,
      createdByUserId: record.createdByUserId,
      dueDate: record.dueDate,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      archivedAt: record.archivedAt,
    };

    return Task.fromPersistence(props);
  }
}
```

```ts path=backend/src/modules/tasks/infrastructure/prisma-project-access-checker.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import {
  ProjectAccessChecker,
  ProjectAccessResult,
} from '../application/project-access-checker';

@Injectable()
export class PrismaProjectAccessChecker implements ProjectAccessChecker {
  constructor(private readonly prisma: PrismaService) {}

  async canViewProject(userId: string, organizationId: string, projectId: string): Promise<ProjectAccessResult> {
    const hasAccess = await this.hasProjectMembership(userId, organizationId, projectId);
    return hasAccess.allowed ? { allowed: true } : hasAccess;
  }

  async canCreateTask(userId: string, organizationId: string, projectId: string): Promise<ProjectAccessResult> {
    return this.canManageTask(userId, organizationId, projectId);
  }

  async canUpdateTask(userId: string, organizationId: string, projectId: string): Promise<ProjectAccessResult> {
    return this.canManageTask(userId, organizationId, projectId);
  }

  async canAssignTask(userId: string, organizationId: string, projectId: string): Promise<ProjectAccessResult> {
    return this.canManageTask(userId, organizationId, projectId);
  }

  async canChangeTaskStatus(userId: string, organizationId: string, projectId: string, assignedToUserId?: string | null): Promise<ProjectAccessResult> {
    const member = await this.findMember(userId, organizationId);
    if (!member) {
      return { allowed: false, reason: 'You are not a member of this organization.' };
    }

    const projectExists = await this.projectExists(organizationId, projectId);
    if (!projectExists) {
      return { allowed: false, reason: 'Project was not found.' };
    }

    if (member.role === 'OWNER' || member.role === 'ADMIN' || assignedToUserId === userId) {
      return { allowed: true };
    }

    return { allowed: false, reason: 'You cannot change this task status.' };
  }

  async canArchiveTask(userId: string, organizationId: string, projectId: string): Promise<ProjectAccessResult> {
    return this.canManageTask(userId, organizationId, projectId);
  }

  private async canManageTask(userId: string, organizationId: string, projectId: string): Promise<ProjectAccessResult> {
    const member = await this.findMember(userId, organizationId);
    if (!member) {
      return { allowed: false, reason: 'You are not a member of this organization.' };
    }

    const projectExists = await this.projectExists(organizationId, projectId);
    if (!projectExists) {
      return { allowed: false, reason: 'Project was not found.' };
    }

    if (member.role !== 'OWNER' && member.role !== 'ADMIN') {
      return { allowed: false, reason: 'Only organization owner or admin can manage tasks.' };
    }

    return { allowed: true };
  }

  private async hasProjectMembership(userId: string, organizationId: string, projectId: string): Promise<ProjectAccessResult> {
    const member = await this.findMember(userId, organizationId);
    if (!member) {
      return { allowed: false, reason: 'You are not a member of this organization.' };
    }

    const projectExists = await this.projectExists(organizationId, projectId);
    if (!projectExists) {
      return { allowed: false, reason: 'Project was not found.' };
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

  private async projectExists(organizationId: string, projectId: string): Promise<boolean> {
    const project = await this.prisma.project.findFirst({
      where: {
        id: projectId,
        organizationId,
      },
      select: { id: true },
    });

    return Boolean(project);
  }
}
```

Repository dan checker berada di infrastructure karena memakai Prisma. Keduanya mengadaptasi interface application ke database.

## Presentation Layer - DTO/Object

```ts path=backend/src/modules/tasks/presentation/dto/create-task.input.ts
import { Field, InputType } from '@nestjs/graphql';
import { IsDateString, IsEnum, IsNotEmpty, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { TaskPriority } from '../../domain/task-priority.enum';

@InputType()
export class CreateTaskInput {
  @Field()
  @IsString()
  @IsNotEmpty()
  organizationId: string;

  @Field()
  @IsString()
  @IsNotEmpty()
  projectId: string;

  @Field()
  @IsString()
  @MinLength(3)
  @MaxLength(160)
  title: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @Field(() => TaskPriority, { defaultValue: TaskPriority.MEDIUM })
  @IsOptional()
  @IsEnum(TaskPriority)
  priority?: TaskPriority;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  assignedToUserId?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsDateString()
  dueDate?: string;
}
```

```ts path=backend/src/modules/tasks/presentation/dto/update-task.input.ts
import { Field, InputType } from '@nestjs/graphql';
import { IsDateString, IsEnum, IsNotEmpty, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { TaskPriority } from '../../domain/task-priority.enum';

@InputType()
export class UpdateTaskInput {
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
  @MinLength(3)
  @MaxLength(160)
  title?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @Field(() => TaskPriority, { nullable: true })
  @IsOptional()
  @IsEnum(TaskPriority)
  priority?: TaskPriority;

  @Field({ nullable: true })
  @IsOptional()
  @IsDateString()
  dueDate?: string;
}
```

```ts path=backend/src/modules/tasks/presentation/dto/assign-task.input.ts
import { Field, InputType } from '@nestjs/graphql';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

@InputType()
export class AssignTaskInput {
  @Field()
  @IsString()
  @IsNotEmpty()
  organizationId: string;

  @Field()
  @IsString()
  @IsNotEmpty()
  projectId: string;

  @Field()
  @IsString()
  @IsNotEmpty()
  taskId: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  assignedToUserId?: string;
}
```

```ts path=backend/src/modules/tasks/presentation/dto/change-task-status.input.ts
import { Field, InputType } from '@nestjs/graphql';
import { IsEnum, IsNotEmpty, IsString } from 'class-validator';
import { TaskStatus } from '../../domain/task-status.enum';

@InputType()
export class ChangeTaskStatusInput {
  @Field()
  @IsString()
  @IsNotEmpty()
  organizationId: string;

  @Field()
  @IsString()
  @IsNotEmpty()
  projectId: string;

  @Field()
  @IsString()
  @IsNotEmpty()
  taskId: string;

  @Field(() => TaskStatus)
  @IsEnum(TaskStatus)
  status: TaskStatus;
}
```

```ts path=backend/src/modules/tasks/presentation/dto/task-filter.input.ts
import { Field, InputType, Int, registerEnumType } from '@nestjs/graphql';
import { IsEnum, IsInt, IsNotEmpty, IsOptional, IsString, Max, Min } from 'class-validator';
import { TaskPriority } from '../../domain/task-priority.enum';
import { TaskStatus } from '../../domain/task-status.enum';

registerEnumType(TaskStatus, { name: 'TaskStatus' });
registerEnumType(TaskPriority, { name: 'TaskPriority' });

@InputType()
export class TaskFilterInput {
  @Field()
  @IsString()
  @IsNotEmpty()
  organizationId: string;

  @Field()
  @IsString()
  @IsNotEmpty()
  projectId: string;

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

  @Field(() => TaskStatus, { nullable: true })
  @IsOptional()
  @IsEnum(TaskStatus)
  status?: TaskStatus;

  @Field(() => TaskPriority, { nullable: true })
  @IsOptional()
  @IsEnum(TaskPriority)
  priority?: TaskPriority;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  assignedToUserId?: string;
}
```

```ts path=backend/src/modules/tasks/presentation/dto/task.object.ts
import { Field, ObjectType } from '@nestjs/graphql';
import { Task } from '../../domain/task.entity';
import { TaskPriority } from '../../domain/task-priority.enum';
import { TaskStatus } from '../../domain/task-status.enum';

@ObjectType()
export class TaskObject {
  @Field()
  id: string;

  @Field()
  organizationId: string;

  @Field()
  projectId: string;

  @Field()
  title: string;

  @Field({ nullable: true })
  description?: string | null;

  @Field(() => TaskStatus)
  status: TaskStatus;

  @Field(() => TaskPriority)
  priority: TaskPriority;

  @Field({ nullable: true })
  assignedToUserId?: string | null;

  @Field()
  createdByUserId: string;

  @Field({ nullable: true })
  dueDate?: Date | null;

  @Field()
  createdAt: Date;

  @Field()
  updatedAt: Date;

  @Field({ nullable: true })
  archivedAt?: Date | null;

  static fromDomain(task: Task): TaskObject {
    const props = task.toProps();
    const object = new TaskObject();

    object.id = props.id;
    object.organizationId = props.organizationId;
    object.projectId = props.projectId;
    object.title = props.title;
    object.description = props.description;
    object.status = props.status;
    object.priority = props.priority;
    object.assignedToUserId = props.assignedToUserId;
    object.createdByUserId = props.createdByUserId;
    object.dueDate = props.dueDate;
    object.createdAt = props.createdAt;
    object.updatedAt = props.updatedAt;
    object.archivedAt = props.archivedAt;

    return object;
  }
}
```

```ts path=backend/src/modules/tasks/presentation/dto/paged-task.response.ts
import { Field, Int, ObjectType } from '@nestjs/graphql';
import { TaskObject } from './task.object';

@ObjectType()
export class TaskPaginationMetadata {
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
export class PagedTaskResponse {
  @Field(() => [TaskObject])
  items: TaskObject[];

  @Field(() => TaskPaginationMetadata)
  metadata: TaskPaginationMetadata;

  static create(items: TaskObject[], page: number, pageSize: number, totalItems: number): PagedTaskResponse {
    const response = new PagedTaskResponse();
    const metadata = new TaskPaginationMetadata();

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

`TaskObject` hanya mengembalikan task yang sudah lolos access check, sehingga tidak expose data tenant lain.

## Presentation Layer - Resolver

```ts path=backend/src/modules/tasks/presentation/tasks.resolver.ts
import { UseGuards } from '@nestjs/common';
import { Args, Mutation, Query, Resolver } from '@nestjs/graphql';
import { GraphQLError } from 'graphql';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import {
  CurrentUserPayload,
  GqlAuthGuard,
} from '../../../common/guards/gql-auth.guard';
import { TaskService } from '../application/task.service';
import { AssignTaskInput } from './dto/assign-task.input';
import { ChangeTaskStatusInput } from './dto/change-task-status.input';
import { CreateTaskInput } from './dto/create-task.input';
import { PagedTaskResponse } from './dto/paged-task.response';
import { TaskFilterInput } from './dto/task-filter.input';
import { TaskObject } from './dto/task.object';
import { UpdateTaskInput } from './dto/update-task.input';

@UseGuards(GqlAuthGuard)
@Resolver(() => TaskObject)
export class TasksResolver {
  constructor(private readonly taskService: TaskService) {}

  @Mutation(() => TaskObject)
  async createTask(@CurrentUser() currentUser: CurrentUserPayload, @Args('input') input: CreateTaskInput): Promise<TaskObject> {
    const result = await this.taskService.createTask({
      currentUserId: currentUser.sub,
      organizationId: input.organizationId,
      projectId: input.projectId,
      title: input.title,
      description: input.description,
      priority: input.priority,
      assignedToUserId: input.assignedToUserId,
      dueDate: input.dueDate ? new Date(input.dueDate) : null,
    });

    if (result.isFail()) throw this.toGraphQLError(result.unwrapError());
    return TaskObject.fromDomain(result.unwrap());
  }

  @Query(() => PagedTaskResponse)
  async tasks(@CurrentUser() currentUser: CurrentUserPayload, @Args('filter') filter: TaskFilterInput): Promise<PagedTaskResponse> {
    const page = filter.page ?? 1;
    const pageSize = filter.pageSize ?? 20;
    const result = await this.taskService.getTasks({
      currentUserId: currentUser.sub,
      organizationId: filter.organizationId,
      projectId: filter.projectId,
      page,
      pageSize,
      search: filter.search,
      status: filter.status,
      priority: filter.priority,
      assignedToUserId: filter.assignedToUserId,
    });

    if (result.isFail()) throw this.toGraphQLError(result.unwrapError());
    const list = result.unwrap();
    return PagedTaskResponse.create(list.items.map(TaskObject.fromDomain), page, pageSize, list.totalItems);
  }

  @Query(() => TaskObject)
  async task(
    @CurrentUser() currentUser: CurrentUserPayload,
    @Args('organizationId') organizationId: string,
    @Args('projectId') projectId: string,
    @Args('taskId') taskId: string,
  ): Promise<TaskObject> {
    const result = await this.taskService.getTaskDetail(currentUser.sub, organizationId, projectId, taskId);
    if (result.isFail()) throw this.toGraphQLError(result.unwrapError());
    return TaskObject.fromDomain(result.unwrap());
  }

  @Mutation(() => TaskObject)
  async updateTask(
    @CurrentUser() currentUser: CurrentUserPayload,
    @Args('taskId') taskId: string,
    @Args('input') input: UpdateTaskInput,
  ): Promise<TaskObject> {
    const result = await this.taskService.updateTask({
      currentUserId: currentUser.sub,
      organizationId: input.organizationId,
      projectId: input.projectId,
      taskId,
      title: input.title,
      description: input.description,
      priority: input.priority,
      dueDate: input.dueDate ? new Date(input.dueDate) : undefined,
    });

    if (result.isFail()) throw this.toGraphQLError(result.unwrapError());
    return TaskObject.fromDomain(result.unwrap());
  }

  @Mutation(() => TaskObject)
  async assignTask(@CurrentUser() currentUser: CurrentUserPayload, @Args('input') input: AssignTaskInput): Promise<TaskObject> {
    const result = await this.taskService.assignTask(
      currentUser.sub,
      input.organizationId,
      input.projectId,
      input.taskId,
      input.assignedToUserId ?? null,
    );

    if (result.isFail()) throw this.toGraphQLError(result.unwrapError());
    return TaskObject.fromDomain(result.unwrap());
  }

  @Mutation(() => TaskObject)
  async changeTaskStatus(@CurrentUser() currentUser: CurrentUserPayload, @Args('input') input: ChangeTaskStatusInput): Promise<TaskObject> {
    const result = await this.taskService.changeTaskStatus(
      currentUser.sub,
      input.organizationId,
      input.projectId,
      input.taskId,
      input.status,
    );

    if (result.isFail()) throw this.toGraphQLError(result.unwrapError());
    return TaskObject.fromDomain(result.unwrap());
  }

  @Mutation(() => Boolean)
  async archiveTask(
    @CurrentUser() currentUser: CurrentUserPayload,
    @Args('organizationId') organizationId: string,
    @Args('projectId') projectId: string,
    @Args('taskId') taskId: string,
  ): Promise<boolean> {
    const result = await this.taskService.archiveTask(currentUser.sub, organizationId, projectId, taskId);
    if (result.isFail()) throw this.toGraphQLError(result.unwrapError());
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

Resolver hanya handle input/output dan call service. Semua operasi membawa `organizationId` dan `projectId`.

## Tasks Module

```ts path=backend/src/modules/tasks/presentation/tasks.module.ts
import { Module } from '@nestjs/common';
import { PrismaModule } from '../../../infrastructure/prisma/prisma.module';
import { PROJECT_ACCESS_CHECKER } from '../application/project-access-checker';
import { TASK_REPOSITORY } from '../application/task.repository';
import { TaskService } from '../application/task.service';
import { TASK_STATUS_TRANSITION_STRATEGY } from '../application/task-status-transition.strategy';
import { DefaultTaskStatusTransitionStrategy } from '../infrastructure/default-task-status-transition.strategy';
import { PrismaProjectAccessChecker } from '../infrastructure/prisma-project-access-checker';
import { PrismaTaskRepository } from '../infrastructure/prisma-task.repository';
import { TasksResolver } from './tasks.resolver';

@Module({
  imports: [PrismaModule],
  providers: [
    TasksResolver,
    TaskService,
    {
      provide: TASK_REPOSITORY,
      useClass: PrismaTaskRepository,
    },
    {
      provide: PROJECT_ACCESS_CHECKER,
      useClass: PrismaProjectAccessChecker,
    },
    {
      provide: TASK_STATUS_TRANSITION_STRATEGY,
      useClass: DefaultTaskStatusTransitionStrategy,
    },
  ],
  exports: [TaskService],
})
export class TasksModule {}
```

Dependency injection bekerja seperti ini:

- `TaskService` meminta repository, project access checker, dan status transition strategy lewat token.
- Module memetakan token ke implementation.
- Resolver tidak tahu concrete repository.
- Strategy implementation didaftarkan sebagai provider agar bisa diganti nanti.

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
import { TasksModule } from './modules/tasks/presentation/tasks.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
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
    TasksModule,
  ],
})
export class AppModule {}
```

`AppModule` adalah root module. Feature module dipasang di root module, lalu resolver task masuk GraphQL schema otomatis.

## Tenant Isolation Rules

Aturan:

- User hanya boleh melihat task dari organization tempat dia menjadi member.
- User hanya boleh melihat task dari project di organization tersebut.
- Query list task harus selalu filter `organizationId + projectId`.
- Detail/update/assign/change status/archive harus selalu cocokkan `organizationId + projectId + taskId`.
- OWNER/ADMIN organization boleh create/update/assign/archive task.
- MEMBER minimal boleh view task.
- Assignee boleh change status task miliknya jika rule bisnis mengizinkan.

Contoh rule:

```txt
canViewTask:
  user member organization
  project.organizationId sesuai organizationId
  task.organizationId + task.projectId sesuai input

canCreateTask:
  user OWNER atau ADMIN organization

canUpdateTask:
  user OWNER atau ADMIN organization

canAssignTask:
  user OWNER atau ADMIN organization

canChangeTaskStatus:
  user OWNER/ADMIN atau assignee task
  status transition valid

canArchiveTask:
  user OWNER atau ADMIN organization
```

## Pagination Dan Filtering

List task perlu pagination karena project aktif bisa punya ratusan atau ribuan task.

Parameter:

- `page`: halaman, minimal 1.
- `pageSize`: jumlah item, minimal 1 dan maksimal 100.
- `search`: search by task title.
- `status`: filter by task status.
- `priority`: filter by priority.
- `assignedToUserId`: filter by assignee.

Sorting default:

```txt
updatedAt desc
```

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

Create task:

```graphql
mutation {
  createTask(input: {
    organizationId: "org_123"
    projectId: "project_123"
    title: "Design login page"
    description: "Create login page wireframe"
    priority: HIGH
    assignedToUserId: "user_456"
  }) {
    id
    title
    status
    priority
  }
}
```

List tasks:

```graphql
query {
  tasks(filter: {
    organizationId: "org_123"
    projectId: "project_123"
    page: 1
    pageSize: 10
    search: "login"
    status: IN_PROGRESS
    priority: HIGH
  }) {
    items {
      id
      title
      status
      priority
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

Detail task:

```graphql
query {
  task(
    organizationId: "org_123"
    projectId: "project_123"
    taskId: "task_123"
  ) {
    id
    title
    description
    status
    priority
  }
}
```

Assign task:

```graphql
mutation {
  assignTask(input: {
    organizationId: "org_123"
    projectId: "project_123"
    taskId: "task_123"
    assignedToUserId: "user_456"
  }) {
    id
    assignedToUserId
  }
}
```

Change status:

```graphql
mutation {
  changeTaskStatus(input: {
    organizationId: "org_123"
    projectId: "project_123"
    taskId: "task_123"
    status: IN_REVIEW
  }) {
    id
    status
  }
}
```

Archive task:

```graphql
mutation {
  archiveTask(
    organizationId: "org_123"
    projectId: "project_123"
    taskId: "task_123"
  )
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
5. Create project dari file sebelumnya.
6. Jalankan `createTask`.
7. Jalankan `tasks`.
8. Jalankan detail `task`.
9. Jalankan `updateTask`.
10. Jalankan `assignTask`.
11. Jalankan `changeTaskStatus`.
12. Jalankan `archiveTask`.

## Seed Task

```ts path=backend/prisma/seed.ts
import {
  OrganizationRole,
  PrismaClient,
  ProjectStatus,
  TaskPriority,
  TaskStatus,
  UserRole,
} from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash('Password123!', 12);

  const admin = await prisma.user.upsert({
    where: { email: 'admin@example.com' },
    update: { name: 'Admin User', role: UserRole.ADMIN, passwordHash },
    create: { email: 'admin@example.com', name: 'Admin User', role: UserRole.ADMIN, passwordHash },
  });

  const member = await prisma.user.upsert({
    where: { email: 'member@example.com' },
    update: { name: 'Member User', role: UserRole.MEMBER, passwordHash },
    create: { email: 'member@example.com', name: 'Member User', role: UserRole.MEMBER, passwordHash },
  });

  const organization = await prisma.organization.upsert({
    where: { slug: 'acme-corp' },
    update: { name: 'Acme Corp' },
    create: { name: 'Acme Corp', slug: 'acme-corp' },
  });

  await prisma.organizationMember.upsert({
    where: { organizationId_userId: { organizationId: organization.id, userId: admin.id } },
    update: { role: OrganizationRole.OWNER },
    create: { organizationId: organization.id, userId: admin.id, role: OrganizationRole.OWNER },
  });

  await prisma.organizationMember.upsert({
    where: { organizationId_userId: { organizationId: organization.id, userId: member.id } },
    update: { role: OrganizationRole.MEMBER },
    create: { organizationId: organization.id, userId: member.id, role: OrganizationRole.MEMBER },
  });

  let project = await prisma.project.findFirst({
    where: { organizationId: organization.id, name: 'Website Redesign' },
  });

  if (!project) {
    project = await prisma.project.create({
      data: {
        organizationId: organization.id,
        name: 'Website Redesign',
        description: 'Redesign company website',
        status: ProjectStatus.ACTIVE,
        createdByUserId: admin.id,
      },
    });
  }

  const tasks = [
    { title: 'Design login page', status: TaskStatus.TODO, priority: TaskPriority.HIGH },
    { title: 'Implement GraphQL auth', status: TaskStatus.IN_PROGRESS, priority: TaskPriority.CRITICAL },
    { title: 'Review dashboard layout', status: TaskStatus.IN_REVIEW, priority: TaskPriority.MEDIUM },
  ];

  for (const task of tasks) {
    const existing = await prisma.task.findFirst({
      where: {
        organizationId: organization.id,
        projectId: project.id,
        title: task.title,
      },
    });

    if (existing) {
      await prisma.task.update({
        where: { id: existing.id },
        data: { status: task.status, priority: task.priority, assignedToUserId: member.id },
      });
      continue;
    }

    await prisma.task.create({
      data: {
        organizationId: organization.id,
        projectId: project.id,
        title: task.title,
        status: task.status,
        priority: task.priority,
        assignedToUserId: member.id,
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

Seed idempotent karena user, organization, membership, project, dan task dicek sebelum dibuat.

## Request Flow

Flow create task:

```txt
GraphQL Client
    |
    v
TasksResolver.createTask
    |
    v
GqlAuthGuard
    |
    v
CurrentUser
    |
    v
TaskService.createTask
    |
    v
ProjectAccessChecker
    |
    v
Task domain
    |
    v
TaskRepository.create
    |
    v
Prisma
    |
    v
PostgreSQL
    |
    v
TaskObject
```

Flow change status:

```txt
GraphQL Client
    |
    v
TasksResolver.changeTaskStatus
    |
    v
TaskService.changeTaskStatus
    |
    v
TaskRepository.findById
    |
    v
ProjectAccessChecker
    |
    v
TaskStatusTransitionStrategy
    |
    v
Task.changeStatus
    |
    v
TaskRepository.update
    |
    v
TaskObject
```

## Error Handling

Error yang perlu ditangani:

- Organization tidak ditemukan.
- Project tidak ditemukan.
- User bukan member organization.
- User tidak punya permission create/update/assign/change/archive task.
- Task tidak ditemukan.
- Task bukan milik project tersebut.
- Title kosong atau terlalu pendek.
- Priority invalid.
- Status invalid.
- Status transition invalid.
- Assignee tidak valid.
- Due date invalid.
- Page/pageSize invalid.
- Token kosong/invalid.

## Security Notes

- Jangan percaya `organizationId`/`projectId` dari frontend tanpa cek access.
- Jangan query task hanya berdasarkan `taskId`.
- Jangan percaya `createdByUserId` dari frontend.
- Jangan expose task project/organization lain.
- Role dan permission harus dicek di backend.
- Audit log create/update/assign/status/archive task adalah improvement penting.
- Soft delete/archive lebih aman daripada hard delete.
- Rate limiting endpoint sensitif adalah improvement penting.

## Design Pattern Yang Relevan

Konsep pattern berikut memakai inspirasi umum dari katalog design pattern seperti Refactoring Guru, tetapi penjelasan dan contoh kode dibuat untuk stack ini.

### Repository Pattern

Masalah yang diselesaikan: service butuh akses task tanpa tahu detail Prisma.

Kenapa dipakai: query task tenant-aware menjadi terpusat.

File yang memakai:

- `backend/src/modules/tasks/application/task.repository.ts`
- `backend/src/modules/tasks/infrastructure/prisma-task.repository.ts`

Alternatif: service langsung memakai Prisma, tetapi tenant filter mudah bocor.

### Adapter Pattern Melalui PrismaTaskRepository

Masalah yang diselesaikan: application layer punya interface, database memakai Prisma.

Kenapa dipakai: repository mengadaptasi Prisma Client ke kontrak application.

File yang memakai:

- `backend/src/modules/tasks/infrastructure/prisma-task.repository.ts`

Alternatif: Prisma dipakai langsung di resolver/service.

### Strategy Pattern Melalui TaskStatusTransitionStrategy

Masalah yang diselesaikan: rule status transition tidak stabil dan bisa berubah.

Kenapa dipakai: workflow dipisah dari resolver/service dan mudah diganti.

File yang memakai:

- `backend/src/modules/tasks/application/task-status-transition.strategy.ts`
- `backend/src/modules/tasks/infrastructure/default-task-status-transition.strategy.ts`

Alternatif: `if/else` besar di resolver atau service.

### Facade Pattern Melalui TasksResolver Dan TaskService

Masalah yang diselesaikan: client tidak perlu tahu detail access checker, strategy, repository, dan domain.

Kenapa dipakai: API terlihat sederhana.

File yang memakai:

- `backend/src/modules/tasks/presentation/tasks.resolver.ts`
- `backend/src/modules/tasks/application/task.service.ts`

Alternatif: detail internal bocor ke API layer.

### Result Pattern

Masalah yang diselesaikan: business error seperti invalid transition tidak harus menjadi exception teknis.

Kenapa dipakai: use case mengembalikan sukses/gagal secara eksplisit.

File yang memakai:

- `backend/src/modules/tasks/domain/task.entity.ts`
- `backend/src/modules/tasks/application/task.service.ts`
- `backend/src/modules/tasks/infrastructure/default-task-status-transition.strategy.ts`

Alternatif: throw exception untuk semua error.

### Specification-like Filtering

Masalah yang diselesaikan: list task perlu search/status/priority/assignee.

Kenapa dipakai: filter dikumpulkan dalam object.

File yang memakai:

- `backend/src/modules/tasks/application/task.repository.ts`
- `backend/src/modules/tasks/presentation/dto/task-filter.input.ts`
- `backend/src/modules/tasks/infrastructure/prisma-task.repository.ts`

Alternatif: method repository punya terlalu banyak parameter terpisah.

### Policy/Strategy Preview Untuk Permission Rule

Masalah yang diselesaikan: permission task bisa makin kompleks.

Kenapa dipakai: `ProjectAccessChecker` bisa berkembang menjadi policy class.

File yang memakai:

- `backend/src/modules/tasks/application/project-access-checker.ts`
- `backend/src/modules/tasks/infrastructure/prisma-project-access-checker.ts`

Alternatif: permission tersebar di resolver.

### Module Pattern NestJS

Masalah yang diselesaikan: provider task perlu dikelompokkan.

Kenapa dipakai: dependency registration tetap jelas.

File yang memakai:

- `backend/src/modules/tasks/presentation/tasks.module.ts`

Alternatif: semua provider didaftarkan di `AppModule`.

### Dependency Injection

Masalah yang diselesaikan: service tidak membuat dependency sendiri.

Kenapa dipakai: repository/checker/strategy bisa diganti di module.

File yang memakai:

- `backend/src/modules/tasks/application/task.service.ts`
- `backend/src/modules/tasks/presentation/tasks.module.ts`

Alternatif: membuat instance manual dengan `new`.

## Troubleshooting

### GqlAuthGuard unauthorized

Token kosong, invalid, expired, atau header bukan `Bearer <token>`. Login ulang dan set header Authorization.

### CurrentUser undefined

Resolver belum memakai guard atau GraphQL context belum membawa `req`. Pastikan `@UseGuards(GqlAuthGuard)` dan `context: ({ req }) => ({ req })`.

### Task tidak muncul karena organizationId/projectId salah

Task list selalu filter `organizationId + projectId`. Cek project dan organization yang dipakai.

### Task detail 404 padahal task ada

Task mungkin berada di project/organization lain. Jangan query hanya dengan `taskId`.

### User tidak bisa create task padahal owner

Cek token payload, membership role, dan project existence.

### Status transition ditolak

Cek rule `DefaultTaskStatusTransitionStrategy`. Contoh `DONE` hanya boleh ke `ARCHIVED`.

### Enum Prisma dan enum domain tidak sinkron

Pastikan nilai enum di Prisma sama dengan enum TypeScript domain.

### GraphQL enum TaskStatus/TaskPriority tidak muncul

Pastikan `registerEnumType(TaskStatus, ...)` dan `registerEnumType(TaskPriority, ...)` dipanggil.

### Nest cannot resolve dependency

Cek provider mapping untuk `TASK_REPOSITORY`, `PROJECT_ACCESS_CHECKER`, dan `TASK_STATUS_TRANSITION_STRATEGY`.

### Resolver tidak muncul di schema

Pastikan `TasksModule` diimport di `AppModule` dan `TasksResolver` ada di providers.

### Pagination tidak benar

Pastikan `skip = (page - 1) * pageSize`, `pageSize` maksimal 100, dan `count` memakai filter yang sama.

### Query lambat karena index belum dibuat

Pastikan index Prisma untuk `organizationId + projectId`, status, priority, assignee, dan due date sudah dimigrasi.

## Checklist Berhasil

- Prisma model `Task` tersedia.
- Migration task berhasil.
- User login bisa create task.
- Task selalu punya `organizationId` dan `projectId`.
- List task hanya menampilkan task dari project terkait.
- Detail task tidak bisa diakses dari organization/project lain.
- Search task by title berhasil.
- Filter task by status berhasil.
- Filter task by priority berhasil.
- Filter task by assignee berhasil.
- Assign task berhasil.
- Change status mengikuti Strategy Pattern.
- Status transition invalid ditolak.
- Archive task berhasil.
- `TasksResolver` protected dengan `GqlAuthGuard`.
- `TasksModule` terdaftar di `AppModule`.
- Tidak ada business logic berat di resolver.
- Query selalu memperhatikan tenant isolation.

## Langkah Berikutnya

Lanjutkan ke `backend/07-graphql-api-pattern.md` untuk merapikan GraphQL response, error handling, validation, pagination, dan pola API yang konsisten.

