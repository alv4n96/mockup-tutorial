# Backend 06 - Task Module

File ini melanjutkan [05-project-module.md](05-project-module.md). Setelah module `Projects` punya tenant boundary lewat `OrganizationId`, module `Tasks` menambahkan unit kerja paling kecil di dalam project.

Task wajib punya `OrganizationId` dan `ProjectId`. `OrganizationId` menjaga tenant isolation. `ProjectId` memastikan task berada di project yang benar. Task tidak boleh diakses hanya berdasarkan `taskId` karena user dari tenant lain bisa saja menebak id.

Aturan akses task:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/06-task-module.md
Request task
  -> ambil current user dari JWT
  -> cek akses organization/project
  -> query task by OrganizationId + ProjectId + TaskId
  -> return ApiResponse
```

Database masih memakai in-memory repository agar fokus ke module boundary, use case, dan Strategy Pattern. EF Core migration dan seed database dibahas di `08-database-migration-seed.md`.

## Hubungan Tasks Dengan Projects

Project adalah container pekerjaan. Task adalah item pekerjaan di dalam project.

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/06-task-module.md
Organization: Acme Studio
  Project: Website Redesign
    Task: Setup landing page
    Task: Review design system
```

Karena itu endpoint task memakai pola route:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/06-task-module.md
/api/organizations/{organizationId}/projects/{projectId}/tasks
```

Route ini membuat tenant dan project context eksplisit.

## Konsep Dasar Task Module

### Task

Task adalah pekerjaan spesifik yang bisa dibuat, ditugaskan, diprioritaskan, diberi deadline, dan diubah statusnya.

### Assignee

Assignee adalah user yang ditugaskan mengerjakan task. Di file ini assignee disimpan sebagai `AssigneeUserId`.

### Reporter/Creator

Reporter atau creator adalah user yang membuat task. Di file ini disimpan sebagai `CreatedByUserId`.

### Task Status

Status menunjukkan posisi task dalam workflow:

- `Todo`: belum dikerjakan.
- `InProgress`: sedang dikerjakan.
- `Done`: selesai.
- `Archived`: diarsipkan.

### Task Priority

Priority membantu menentukan urgensi:

- `Low`
- `Medium`
- `High`

### Due Date

Due date adalah batas waktu task. Due date boleh kosong karena tidak semua task punya deadline.

### Task Dalam Project

Task tidak berdiri sendiri. Task selalu milik satu project dan satu organization. Semua query task wajib memfilter `OrganizationId` dan `ProjectId`.

### Kenapa Status Change Pakai Strategy Pattern

Aturan perubahan status sering berubah. Contoh:

- dari `Todo` boleh ke `InProgress`;
- dari `InProgress` boleh ke `Done`;
- dari `Done` tidak boleh balik ke `Todo` kecuali ada policy khusus;
- task archived tidak boleh diubah.

Jika aturan ini ditaruh langsung di handler, handler cepat penuh logic bercabang. Strategy Pattern memisahkan aturan transisi status ke class khusus sehingga handler tetap fokus pada workflow.

## Scope Fitur Di File Ini

Fitur yang dibuat:

- create task;
- get task list by organization + project;
- get task detail;
- update task;
- change task status;
- assign task ke user;
- delete/archive task;
- pagination;
- search by title;
- filter by status;
- filter by assignee;
- authorization sederhana berdasarkan akses organization/project;
- `ApiResponse` envelope;
- validation request sederhana;
- error response sederhana;
- Strategy Pattern untuk perubahan status;
- in-memory repository.

## Struktur Folder Module Tasks

```txt
# File: docs/stacks/enterprise-dotnet-spring/backend/06-task-module.md
src/
└── Modules/
    └── Tasks/
        ├── Domain/
        │   ├── TaskItem.cs
        │   ├── TaskStatus.cs
        │   └── TaskPriority.cs
        │
        ├── Application/
        │   ├── Abstractions/
        │   │   ├── ITaskRepository.cs
        │   │   ├── IProjectAccessChecker.cs
        │   │   ├── ICurrentUserService.cs
        │   │   └── ITaskStatusTransitionStrategy.cs
        │   │
        │   ├── CreateTask/
        │   │   ├── CreateTaskRequest.cs
        │   │   ├── CreateTaskResponse.cs
        │   │   └── CreateTaskHandler.cs
        │   │
        │   ├── GetTasks/
        │   │   ├── GetTasksQuery.cs
        │   │   ├── TaskListItemResponse.cs
        │   │   └── GetTasksHandler.cs
        │   │
        │   ├── GetTaskDetail/
        │   │   ├── TaskDetailResponse.cs
        │   │   └── GetTaskDetailHandler.cs
        │   │
        │   ├── UpdateTask/
        │   │   ├── UpdateTaskRequest.cs
        │   │   └── UpdateTaskHandler.cs
        │   │
        │   ├── ChangeTaskStatus/
        │   │   ├── ChangeTaskStatusRequest.cs
        │   │   └── ChangeTaskStatusHandler.cs
        │   │
        │   ├── AssignTask/
        │   │   ├── AssignTaskRequest.cs
        │   │   └── AssignTaskHandler.cs
        │   │
        │   └── DeleteTask/
        │       └── DeleteTaskHandler.cs
        │
        ├── Infrastructure/
        │   ├── InMemoryTaskRepository.cs
        │   ├── ProjectAccessChecker.cs
        │   └── TaskStatusTransitionStrategy.cs
        │
        ├── Presentation/
        │   └── TaskEndpoints.cs
        │
        └── TasksModule.cs
```

## Command Membuat Folder

```powershell
# File: ProjectManagement.Backend/commands/62-create-task-folders.ps1
mkdir src/Modules/Tasks/Domain
mkdir src/Modules/Tasks/Application
mkdir src/Modules/Tasks/Application/Abstractions
mkdir src/Modules/Tasks/Application/CreateTask
mkdir src/Modules/Tasks/Application/GetTasks
mkdir src/Modules/Tasks/Application/GetTaskDetail
mkdir src/Modules/Tasks/Application/UpdateTask
mkdir src/Modules/Tasks/Application/ChangeTaskStatus
mkdir src/Modules/Tasks/Application/AssignTask
mkdir src/Modules/Tasks/Application/DeleteTask
mkdir src/Modules/Tasks/Infrastructure
mkdir src/Modules/Tasks/Presentation
```

Penjelasan:

- `Domain` menyimpan entity dan enum task.
- `Application` menyimpan use case task.
- `Abstractions` menyimpan repository, access checker, current user, dan strategy contract.
- `Infrastructure` menyimpan repository in-memory, access checker, dan strategy implementation.
- `Presentation` menyimpan endpoint HTTP.

## Domain Layer

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Domain/TaskStatus.cs
namespace App.Modules.Tasks.Domain;

public enum TaskStatus
{
    Todo = 1,
    InProgress = 2,
    Done = 3,
    Archived = 4
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Domain/TaskPriority.cs
namespace App.Modules.Tasks.Domain;

public enum TaskPriority
{
    Low = 1,
    Medium = 2,
    High = 3
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Domain/TaskItem.cs
namespace App.Modules.Tasks.Domain;

public sealed class TaskItem
{
    private TaskItem(
        Guid id,
        Guid organizationId,
        Guid projectId,
        Guid createdByUserId,
        string title,
        string? description,
        TaskPriority priority,
        DateTimeOffset? dueDate)
    {
        Id = id;
        OrganizationId = organizationId;
        ProjectId = projectId;
        CreatedByUserId = createdByUserId;
        Title = title;
        Description = description;
        Priority = priority;
        DueDate = dueDate;
        Status = TaskStatus.Todo;
        CreatedAt = DateTimeOffset.UtcNow;
    }

    public Guid Id { get; private set; }
    public Guid OrganizationId { get; private set; }
    public Guid ProjectId { get; private set; }
    public Guid CreatedByUserId { get; private set; }
    public Guid? AssigneeUserId { get; private set; }
    public string Title { get; private set; }
    public string? Description { get; private set; }
    public TaskStatus Status { get; private set; }
    public TaskPriority Priority { get; private set; }
    public DateTimeOffset? DueDate { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset? UpdatedAt { get; private set; }

    public static TaskItem Create(
        Guid organizationId,
        Guid projectId,
        Guid createdByUserId,
        string title,
        string? description,
        TaskPriority priority,
        DateTimeOffset? dueDate)
    {
        if (organizationId == Guid.Empty) throw new ArgumentException("OrganizationId wajib diisi.");
        if (projectId == Guid.Empty) throw new ArgumentException("ProjectId wajib diisi.");
        if (createdByUserId == Guid.Empty) throw new ArgumentException("CreatedByUserId wajib diisi.");
        if (string.IsNullOrWhiteSpace(title) || title.Trim().Length < 3) throw new ArgumentException("Judul task minimal 3 karakter.");

        return new TaskItem(Guid.NewGuid(), organizationId, projectId, createdByUserId, title.Trim(), Normalize(description), priority, dueDate);
    }

    public void Update(string title, string? description, TaskPriority priority, DateTimeOffset? dueDate)
    {
        EnsureNotArchived();
        if (string.IsNullOrWhiteSpace(title) || title.Trim().Length < 3) throw new ArgumentException("Judul task minimal 3 karakter.");

        Title = title.Trim();
        Description = Normalize(description);
        Priority = priority;
        DueDate = dueDate;
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    public void ChangeStatus(TaskStatus status)
    {
        Status = status;
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    public void AssignTo(Guid assigneeUserId)
    {
        EnsureNotArchived();
        if (assigneeUserId == Guid.Empty) throw new ArgumentException("AssigneeUserId wajib diisi.");
        AssigneeUserId = assigneeUserId;
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    public void Archive()
    {
        Status = TaskStatus.Archived;
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    private void EnsureNotArchived()
    {
        if (Status == TaskStatus.Archived) throw new InvalidOperationException("Task archived tidak boleh diubah.");
    }

    private static string? Normalize(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
```

## Application Abstractions

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/Abstractions/ITaskRepository.cs
using App.Modules.Tasks.Domain;

namespace App.Modules.Tasks.Application.Abstractions;

public interface ITaskRepository
{
    Task AddAsync(TaskItem task, CancellationToken cancellationToken);
    Task<TaskItem?> GetByIdAsync(Guid organizationId, Guid projectId, Guid taskId, CancellationToken cancellationToken);
    Task<TaskListResult> GetListAsync(TaskListQuery query, CancellationToken cancellationToken);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}

public sealed record TaskListQuery(
    Guid OrganizationId,
    Guid ProjectId,
    int Page,
    int PageSize,
    string? Search,
    TaskStatus? Status,
    Guid? AssigneeUserId);

public sealed record TaskListResult(
    IReadOnlyCollection<TaskItem> Items,
    int Page,
    int PageSize,
    int Total);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/Abstractions/IProjectAccessChecker.cs
namespace App.Modules.Tasks.Application.Abstractions;

public interface IProjectAccessChecker
{
    Task<ProjectAccess?> GetAccessAsync(Guid organizationId, Guid projectId, Guid userId, CancellationToken cancellationToken);
}

public sealed record ProjectAccess(Guid OrganizationId, Guid ProjectId, Guid UserId, string OrganizationRole)
{
    public bool CanReadTasks => OrganizationRole is "Owner" or "Admin" or "Member";
    public bool CanCreateTask => OrganizationRole is "Owner" or "Admin" or "Member";
    public bool CanUpdateTask => OrganizationRole is "Owner" or "Admin";
    public bool CanAssignTask => OrganizationRole is "Owner" or "Admin";
    public bool CanArchiveTask => OrganizationRole is "Owner" or "Admin";
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/Abstractions/ICurrentUserService.cs
namespace App.Modules.Tasks.Application.Abstractions;

public interface ICurrentUserService
{
    Guid UserId { get; }
    string Email { get; }
    bool IsAuthenticated { get; }
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/Abstractions/ITaskStatusTransitionStrategy.cs
using App.Modules.Tasks.Domain;

namespace App.Modules.Tasks.Application.Abstractions;

public interface ITaskStatusTransitionStrategy
{
    bool CanTransition(TaskStatus currentStatus, TaskStatus nextStatus);
    string ErrorMessage(TaskStatus currentStatus, TaskStatus nextStatus);
}
```

## Create Task

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/CreateTask/CreateTaskRequest.cs
using App.Modules.Tasks.Domain;

namespace App.Modules.Tasks.Application.CreateTask;

public sealed record CreateTaskRequest(
    string Title,
    string? Description,
    TaskPriority Priority,
    DateTimeOffset? DueDate,
    Guid? AssigneeUserId);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/CreateTask/CreateTaskResponse.cs
namespace App.Modules.Tasks.Application.CreateTask;

public sealed record CreateTaskResponse(
    Guid Id,
    Guid OrganizationId,
    Guid ProjectId,
    string Title,
    string? Description,
    string Status,
    string Priority,
    Guid CreatedByUserId,
    Guid? AssigneeUserId,
    DateTimeOffset? DueDate,
    DateTimeOffset CreatedAt);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/CreateTask/CreateTaskHandler.cs
using App.Modules.Tasks.Application.Abstractions;
using App.Modules.Tasks.Domain;
using App.SharedKernel.Results;

namespace App.Modules.Tasks.Application.CreateTask;

public sealed class CreateTaskHandler
{
    private readonly ITaskRepository _tasks;
    private readonly IProjectAccessChecker _accessChecker;
    private readonly ICurrentUserService _currentUser;

    public CreateTaskHandler(ITaskRepository tasks, IProjectAccessChecker accessChecker, ICurrentUserService currentUser)
    {
        _tasks = tasks;
        _accessChecker = accessChecker;
        _currentUser = currentUser;
    }

    public async Task<Result<CreateTaskResponse>> HandleAsync(Guid organizationId, Guid projectId, CreateTaskRequest request, CancellationToken cancellationToken)
    {
        if (!_currentUser.IsAuthenticated) return Result<CreateTaskResponse>.Failure(new AppError("AUTH_REQUIRED", "User harus login."));
        if (string.IsNullOrWhiteSpace(request.Title) || request.Title.Trim().Length < 3) return Result<CreateTaskResponse>.Failure(new AppError("TASK_TITLE_INVALID", "Judul task minimal 3 karakter."));

        var access = await _accessChecker.GetAccessAsync(organizationId, projectId, _currentUser.UserId, cancellationToken);
        if (access is null || !access.CanCreateTask) return Result<CreateTaskResponse>.Failure(new AppError("TASK_CREATE_FORBIDDEN", "User tidak punya akses membuat task."));
        if (request.AssigneeUserId is not null && !access.CanAssignTask) return Result<CreateTaskResponse>.Failure(new AppError("TASK_ASSIGN_FORBIDDEN", "User tidak punya akses assign task."));

        var task = TaskItem.Create(organizationId, projectId, _currentUser.UserId, request.Title, request.Description, request.Priority, request.DueDate);
        if (request.AssigneeUserId is not null) task.AssignTo(request.AssigneeUserId.Value);

        await _tasks.AddAsync(task, cancellationToken);

        return Result<CreateTaskResponse>.Success(new CreateTaskResponse(
            task.Id, task.OrganizationId, task.ProjectId, task.Title, task.Description, task.Status.ToString(), task.Priority.ToString(), task.CreatedByUserId, task.AssigneeUserId, task.DueDate, task.CreatedAt));
    }
}
```

## Get Tasks Dengan Pagination Dan Filter

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/GetTasks/GetTasksQuery.cs
using App.Modules.Tasks.Domain;

namespace App.Modules.Tasks.Application.GetTasks;

public sealed record GetTasksQuery(
    Guid OrganizationId,
    Guid ProjectId,
    int Page = 1,
    int PageSize = 20,
    string? Search = null,
    TaskStatus? Status = null,
    Guid? AssigneeUserId = null);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/GetTasks/TaskListItemResponse.cs
namespace App.Modules.Tasks.Application.GetTasks;

public sealed record TaskListItemResponse(
    Guid Id,
    Guid OrganizationId,
    Guid ProjectId,
    string Title,
    string? Description,
    string Status,
    string Priority,
    Guid CreatedByUserId,
    Guid? AssigneeUserId,
    DateTimeOffset? DueDate,
    DateTimeOffset CreatedAt,
    DateTimeOffset? UpdatedAt);

public sealed record TaskListResponse(IReadOnlyCollection<TaskListItemResponse> Items, int Page, int PageSize, int Total);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/GetTasks/GetTasksHandler.cs
using App.Modules.Tasks.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Tasks.Application.GetTasks;

public sealed class GetTasksHandler
{
    private readonly ITaskRepository _tasks;
    private readonly IProjectAccessChecker _accessChecker;
    private readonly ICurrentUserService _currentUser;

    public GetTasksHandler(ITaskRepository tasks, IProjectAccessChecker accessChecker, ICurrentUserService currentUser)
    {
        _tasks = tasks;
        _accessChecker = accessChecker;
        _currentUser = currentUser;
    }

    public async Task<Result<TaskListResponse>> HandleAsync(GetTasksQuery query, CancellationToken cancellationToken)
    {
        var page = query.Page < 1 ? 1 : query.Page;
        var pageSize = query.PageSize is < 1 or > 100 ? 20 : query.PageSize;

        var access = await _accessChecker.GetAccessAsync(query.OrganizationId, query.ProjectId, _currentUser.UserId, cancellationToken);
        if (access is null || !access.CanReadTasks) return Result<TaskListResponse>.Failure(new AppError("TASK_READ_FORBIDDEN", "User tidak punya akses membaca task."));

        var result = await _tasks.GetListAsync(new TaskListQuery(query.OrganizationId, query.ProjectId, page, pageSize, query.Search, query.Status, query.AssigneeUserId), cancellationToken);
        var items = result.Items.Select(ToItem).ToArray();

        return Result<TaskListResponse>.Success(new TaskListResponse(items, result.Page, result.PageSize, result.Total));
    }

    private static TaskListItemResponse ToItem(Domain.TaskItem task) => new(
        task.Id, task.OrganizationId, task.ProjectId, task.Title, task.Description, task.Status.ToString(), task.Priority.ToString(), task.CreatedByUserId, task.AssigneeUserId, task.DueDate, task.CreatedAt, task.UpdatedAt);
}
```

## Get Task Detail

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/GetTaskDetail/TaskDetailResponse.cs
namespace App.Modules.Tasks.Application.GetTaskDetail;

public sealed record TaskDetailResponse(
    Guid Id,
    Guid OrganizationId,
    Guid ProjectId,
    string Title,
    string? Description,
    string Status,
    string Priority,
    Guid CreatedByUserId,
    Guid? AssigneeUserId,
    DateTimeOffset? DueDate,
    DateTimeOffset CreatedAt,
    DateTimeOffset? UpdatedAt);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/GetTaskDetail/GetTaskDetailHandler.cs
using App.Modules.Tasks.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Tasks.Application.GetTaskDetail;

public sealed class GetTaskDetailHandler
{
    private readonly ITaskRepository _tasks;
    private readonly IProjectAccessChecker _accessChecker;
    private readonly ICurrentUserService _currentUser;

    public GetTaskDetailHandler(ITaskRepository tasks, IProjectAccessChecker accessChecker, ICurrentUserService currentUser)
    {
        _tasks = tasks;
        _accessChecker = accessChecker;
        _currentUser = currentUser;
    }

    public async Task<Result<TaskDetailResponse>> HandleAsync(Guid organizationId, Guid projectId, Guid taskId, CancellationToken cancellationToken)
    {
        var access = await _accessChecker.GetAccessAsync(organizationId, projectId, _currentUser.UserId, cancellationToken);
        if (access is null || !access.CanReadTasks) return Result<TaskDetailResponse>.Failure(new AppError("TASK_READ_FORBIDDEN", "User tidak punya akses membaca task."));

        var task = await _tasks.GetByIdAsync(organizationId, projectId, taskId, cancellationToken);
        if (task is null) return Result<TaskDetailResponse>.Failure(new AppError("TASK_NOT_FOUND", "Task tidak ditemukan."));

        return Result<TaskDetailResponse>.Success(new TaskDetailResponse(task.Id, task.OrganizationId, task.ProjectId, task.Title, task.Description, task.Status.ToString(), task.Priority.ToString(), task.CreatedByUserId, task.AssigneeUserId, task.DueDate, task.CreatedAt, task.UpdatedAt));
    }
}
```

## Update Task

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/UpdateTask/UpdateTaskRequest.cs
using App.Modules.Tasks.Domain;

namespace App.Modules.Tasks.Application.UpdateTask;

public sealed record UpdateTaskRequest(string Title, string? Description, TaskPriority Priority, DateTimeOffset? DueDate);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/UpdateTask/UpdateTaskHandler.cs
using App.Modules.Tasks.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Tasks.Application.UpdateTask;

public sealed class UpdateTaskHandler
{
    private readonly ITaskRepository _tasks;
    private readonly IProjectAccessChecker _accessChecker;
    private readonly ICurrentUserService _currentUser;

    public UpdateTaskHandler(ITaskRepository tasks, IProjectAccessChecker accessChecker, ICurrentUserService currentUser)
    {
        _tasks = tasks;
        _accessChecker = accessChecker;
        _currentUser = currentUser;
    }

    public async Task<Result<string>> HandleAsync(Guid organizationId, Guid projectId, Guid taskId, UpdateTaskRequest request, CancellationToken cancellationToken)
    {
        var access = await _accessChecker.GetAccessAsync(organizationId, projectId, _currentUser.UserId, cancellationToken);
        if (access is null || !access.CanUpdateTask) return Result<string>.Failure(new AppError("TASK_UPDATE_FORBIDDEN", "User tidak punya akses mengubah task."));

        var task = await _tasks.GetByIdAsync(organizationId, projectId, taskId, cancellationToken);
        if (task is null) return Result<string>.Failure(new AppError("TASK_NOT_FOUND", "Task tidak ditemukan."));

        try
        {
            task.Update(request.Title, request.Description, request.Priority, request.DueDate);
            await _tasks.SaveChangesAsync(cancellationToken);
            return Result<string>.Success("Task berhasil diubah.");
        }
        catch (Exception exception) when (exception is ArgumentException or InvalidOperationException)
        {
            return Result<string>.Failure(new AppError("TASK_UPDATE_FAILED", exception.Message));
        }
    }
}
```

## Change Task Status Dengan Strategy Pattern

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/ChangeTaskStatus/ChangeTaskStatusRequest.cs
using App.Modules.Tasks.Domain;

namespace App.Modules.Tasks.Application.ChangeTaskStatus;

public sealed record ChangeTaskStatusRequest(TaskStatus Status);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/ChangeTaskStatus/ChangeTaskStatusHandler.cs
using App.Modules.Tasks.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Tasks.Application.ChangeTaskStatus;

public sealed class ChangeTaskStatusHandler
{
    private readonly ITaskRepository _tasks;
    private readonly IProjectAccessChecker _accessChecker;
    private readonly ICurrentUserService _currentUser;
    private readonly ITaskStatusTransitionStrategy _strategy;

    public ChangeTaskStatusHandler(ITaskRepository tasks, IProjectAccessChecker accessChecker, ICurrentUserService currentUser, ITaskStatusTransitionStrategy strategy)
    {
        _tasks = tasks;
        _accessChecker = accessChecker;
        _currentUser = currentUser;
        _strategy = strategy;
    }

    public async Task<Result<string>> HandleAsync(Guid organizationId, Guid projectId, Guid taskId, ChangeTaskStatusRequest request, CancellationToken cancellationToken)
    {
        var access = await _accessChecker.GetAccessAsync(organizationId, projectId, _currentUser.UserId, cancellationToken);
        if (access is null || !access.CanUpdateTask) return Result<string>.Failure(new AppError("TASK_STATUS_FORBIDDEN", "User tidak punya akses mengubah status task."));

        var task = await _tasks.GetByIdAsync(organizationId, projectId, taskId, cancellationToken);
        if (task is null) return Result<string>.Failure(new AppError("TASK_NOT_FOUND", "Task tidak ditemukan."));

        if (!_strategy.CanTransition(task.Status, request.Status))
        {
            return Result<string>.Failure(new AppError("TASK_STATUS_TRANSITION_INVALID", _strategy.ErrorMessage(task.Status, request.Status)));
        }

        task.ChangeStatus(request.Status);
        await _tasks.SaveChangesAsync(cancellationToken);
        return Result<string>.Success("Status task berhasil diubah.");
    }
}
```

## Assign Task

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/AssignTask/AssignTaskRequest.cs
namespace App.Modules.Tasks.Application.AssignTask;

public sealed record AssignTaskRequest(Guid AssigneeUserId);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/AssignTask/AssignTaskHandler.cs
using App.Modules.Tasks.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Tasks.Application.AssignTask;

public sealed class AssignTaskHandler
{
    private readonly ITaskRepository _tasks;
    private readonly IProjectAccessChecker _accessChecker;
    private readonly ICurrentUserService _currentUser;

    public AssignTaskHandler(ITaskRepository tasks, IProjectAccessChecker accessChecker, ICurrentUserService currentUser)
    {
        _tasks = tasks;
        _accessChecker = accessChecker;
        _currentUser = currentUser;
    }

    public async Task<Result<string>> HandleAsync(Guid organizationId, Guid projectId, Guid taskId, AssignTaskRequest request, CancellationToken cancellationToken)
    {
        if (request.AssigneeUserId == Guid.Empty) return Result<string>.Failure(new AppError("TASK_ASSIGNEE_INVALID", "AssigneeUserId wajib diisi."));

        var access = await _accessChecker.GetAccessAsync(organizationId, projectId, _currentUser.UserId, cancellationToken);
        if (access is null || !access.CanAssignTask) return Result<string>.Failure(new AppError("TASK_ASSIGN_FORBIDDEN", "User tidak punya akses assign task."));

        var task = await _tasks.GetByIdAsync(organizationId, projectId, taskId, cancellationToken);
        if (task is null) return Result<string>.Failure(new AppError("TASK_NOT_FOUND", "Task tidak ditemukan."));

        task.AssignTo(request.AssigneeUserId);
        await _tasks.SaveChangesAsync(cancellationToken);
        return Result<string>.Success("Task berhasil di-assign.");
    }
}
```

## Delete/Archive Task

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Application/DeleteTask/DeleteTaskHandler.cs
using App.Modules.Tasks.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Tasks.Application.DeleteTask;

public sealed class DeleteTaskHandler
{
    private readonly ITaskRepository _tasks;
    private readonly IProjectAccessChecker _accessChecker;
    private readonly ICurrentUserService _currentUser;

    public DeleteTaskHandler(ITaskRepository tasks, IProjectAccessChecker accessChecker, ICurrentUserService currentUser)
    {
        _tasks = tasks;
        _accessChecker = accessChecker;
        _currentUser = currentUser;
    }

    public async Task<Result<string>> HandleAsync(Guid organizationId, Guid projectId, Guid taskId, CancellationToken cancellationToken)
    {
        var access = await _accessChecker.GetAccessAsync(organizationId, projectId, _currentUser.UserId, cancellationToken);
        if (access is null || !access.CanArchiveTask) return Result<string>.Failure(new AppError("TASK_ARCHIVE_FORBIDDEN", "User tidak punya akses archive task."));

        var task = await _tasks.GetByIdAsync(organizationId, projectId, taskId, cancellationToken);
        if (task is null) return Result<string>.Failure(new AppError("TASK_NOT_FOUND", "Task tidak ditemukan."));

        task.Archive();
        await _tasks.SaveChangesAsync(cancellationToken);
        return Result<string>.Success("Task berhasil di-archive.");
    }
}
```

## Infrastructure Layer

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Infrastructure/InMemoryTaskRepository.cs
using App.Modules.Tasks.Application.Abstractions;
using App.Modules.Tasks.Domain;

namespace App.Modules.Tasks.Infrastructure;

public sealed class InMemoryTaskRepository : ITaskRepository
{
    private static readonly List<TaskItem> Tasks = new();

    public Task AddAsync(TaskItem task, CancellationToken cancellationToken)
    {
        Tasks.Add(task);
        return Task.CompletedTask;
    }

    public Task<TaskItem?> GetByIdAsync(Guid organizationId, Guid projectId, Guid taskId, CancellationToken cancellationToken)
    {
        var task = Tasks.FirstOrDefault(item => item.OrganizationId == organizationId && item.ProjectId == projectId && item.Id == taskId);
        return Task.FromResult(task);
    }

    public Task<TaskListResult> GetListAsync(TaskListQuery query, CancellationToken cancellationToken)
    {
        var filtered = Tasks.Where(task => task.OrganizationId == query.OrganizationId && task.ProjectId == query.ProjectId);
        if (!string.IsNullOrWhiteSpace(query.Search)) filtered = filtered.Where(task => task.Title.Contains(query.Search.Trim(), StringComparison.OrdinalIgnoreCase));
        if (query.Status is not null) filtered = filtered.Where(task => task.Status == query.Status.Value);
        if (query.AssigneeUserId is not null) filtered = filtered.Where(task => task.AssigneeUserId == query.AssigneeUserId.Value);

        var total = filtered.Count();
        var items = filtered.OrderByDescending(task => task.CreatedAt).Skip((query.Page - 1) * query.PageSize).Take(query.PageSize).ToArray();
        return Task.FromResult(new TaskListResult(items, query.Page, query.PageSize, total));
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Infrastructure/ProjectAccessChecker.cs
using App.Modules.Tasks.Application.Abstractions;

namespace App.Modules.Tasks.Infrastructure;

public sealed class ProjectAccessChecker : IProjectAccessChecker
{
    public Task<ProjectAccess?> GetAccessAsync(Guid organizationId, Guid projectId, Guid userId, CancellationToken cancellationToken)
    {
        if (organizationId == Guid.Empty || projectId == Guid.Empty || userId == Guid.Empty) return Task.FromResult<ProjectAccess?>(null);
        return Task.FromResult<ProjectAccess?>(new ProjectAccess(organizationId, projectId, userId, "Owner"));
    }
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Infrastructure/TaskStatusTransitionStrategy.cs
using App.Modules.Tasks.Application.Abstractions;
using App.Modules.Tasks.Domain;

namespace App.Modules.Tasks.Infrastructure;

public sealed class TaskStatusTransitionStrategy : ITaskStatusTransitionStrategy
{
    public bool CanTransition(TaskStatus currentStatus, TaskStatus nextStatus)
    {
        if (currentStatus == nextStatus) return true;

        return currentStatus switch
        {
            TaskStatus.Todo => nextStatus is TaskStatus.InProgress or TaskStatus.Archived,
            TaskStatus.InProgress => nextStatus is TaskStatus.Done or TaskStatus.Archived,
            TaskStatus.Done => nextStatus is TaskStatus.Archived,
            TaskStatus.Archived => false,
            _ => false
        };
    }

    public string ErrorMessage(TaskStatus currentStatus, TaskStatus nextStatus)
    {
        return $"Status task tidak boleh berubah dari {currentStatus} ke {nextStatus}.";
    }
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Infrastructure/CurrentUserService.cs
using System.Security.Claims;
using App.Modules.Tasks.Application.Abstractions;
using Microsoft.AspNetCore.Http;

namespace App.Modules.Tasks.Infrastructure;

public sealed class CurrentUserService : ICurrentUserService
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CurrentUserService(IHttpContextAccessor httpContextAccessor) => _httpContextAccessor = httpContextAccessor;

    public bool IsAuthenticated => _httpContextAccessor.HttpContext?.User.Identity?.IsAuthenticated == true;
    public Guid UserId => Guid.TryParse(_httpContextAccessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : Guid.Empty;
    public string Email => _httpContextAccessor.HttpContext?.User.FindFirstValue(ClaimTypes.Email) ?? string.Empty;
}
```

## Tasks Module DI

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/TasksModule.cs
using App.Modules.Tasks.Application.Abstractions;
using App.Modules.Tasks.Application.AssignTask;
using App.Modules.Tasks.Application.ChangeTaskStatus;
using App.Modules.Tasks.Application.CreateTask;
using App.Modules.Tasks.Application.DeleteTask;
using App.Modules.Tasks.Application.GetTaskDetail;
using App.Modules.Tasks.Application.GetTasks;
using App.Modules.Tasks.Application.UpdateTask;
using App.Modules.Tasks.Infrastructure;
using App.Modules.Tasks.Presentation;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

namespace App.Modules.Tasks;

public static class TasksModule
{
    public static IServiceCollection AddTasksModule(this IServiceCollection services)
    {
        services.AddHttpContextAccessor();
        services.AddSingleton<ITaskRepository, InMemoryTaskRepository>();
        services.AddScoped<IProjectAccessChecker, ProjectAccessChecker>();
        services.AddScoped<ICurrentUserService, CurrentUserService>();
        services.AddScoped<ITaskStatusTransitionStrategy, TaskStatusTransitionStrategy>();

        services.AddScoped<CreateTaskHandler>();
        services.AddScoped<GetTasksHandler>();
        services.AddScoped<GetTaskDetailHandler>();
        services.AddScoped<UpdateTaskHandler>();
        services.AddScoped<ChangeTaskStatusHandler>();
        services.AddScoped<AssignTaskHandler>();
        services.AddScoped<DeleteTaskHandler>();

        return services;
    }

    public static IEndpointRouteBuilder MapTasksModule(this IEndpointRouteBuilder app)
    {
        app.MapTaskEndpoints();
        return app;
    }
}
```

## Presentation Layer

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Presentation/TaskEndpoints.cs
using App.Modules.Tasks.Application.AssignTask;
using App.Modules.Tasks.Application.ChangeTaskStatus;
using App.Modules.Tasks.Application.CreateTask;
using App.Modules.Tasks.Application.DeleteTask;
using App.Modules.Tasks.Application.GetTaskDetail;
using App.Modules.Tasks.Application.GetTasks;
using App.Modules.Tasks.Application.UpdateTask;
using App.Modules.Tasks.Domain;
using App.SharedKernel.Responses;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace App.Modules.Tasks.Presentation;

public static class TaskEndpoints
{
    public static IEndpointRouteBuilder MapTaskEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/organizations/{organizationId:guid}/projects/{projectId:guid}/tasks")
            .WithTags("Tasks")
            .RequireAuthorization();

        group.MapPost("/", CreateAsync);
        group.MapGet("/", GetListAsync);
        group.MapGet("/{taskId:guid}", GetDetailAsync);
        group.MapPut("/{taskId:guid}", UpdateAsync);
        group.MapPatch("/{taskId:guid}/status", ChangeStatusAsync);
        group.MapPatch("/{taskId:guid}/assignee", AssignAsync);
        group.MapDelete("/{taskId:guid}", ArchiveAsync);

        return app;
    }

    private static async Task<IResult> CreateAsync(Guid organizationId, Guid projectId, CreateTaskRequest request, CreateTaskHandler handler, CancellationToken ct)
        => ToHttpResult(await handler.HandleAsync(organizationId, projectId, request, ct), StatusCodes.Status201Created);

    private static async Task<IResult> GetListAsync(Guid organizationId, Guid projectId, int page, int pageSize, string? search, TaskStatus? status, Guid? assigneeUserId, GetTasksHandler handler, CancellationToken ct)
        => ToHttpResult(await handler.HandleAsync(new GetTasksQuery(organizationId, projectId, page == 0 ? 1 : page, pageSize == 0 ? 20 : pageSize, search, status, assigneeUserId), ct));

    private static async Task<IResult> GetDetailAsync(Guid organizationId, Guid projectId, Guid taskId, GetTaskDetailHandler handler, CancellationToken ct)
        => ToHttpResult(await handler.HandleAsync(organizationId, projectId, taskId, ct));

    private static async Task<IResult> UpdateAsync(Guid organizationId, Guid projectId, Guid taskId, UpdateTaskRequest request, UpdateTaskHandler handler, CancellationToken ct)
        => ToHttpResult(await handler.HandleAsync(organizationId, projectId, taskId, request, ct));

    private static async Task<IResult> ChangeStatusAsync(Guid organizationId, Guid projectId, Guid taskId, ChangeTaskStatusRequest request, ChangeTaskStatusHandler handler, CancellationToken ct)
        => ToHttpResult(await handler.HandleAsync(organizationId, projectId, taskId, request, ct));

    private static async Task<IResult> AssignAsync(Guid organizationId, Guid projectId, Guid taskId, AssignTaskRequest request, AssignTaskHandler handler, CancellationToken ct)
        => ToHttpResult(await handler.HandleAsync(organizationId, projectId, taskId, request, ct));

    private static async Task<IResult> ArchiveAsync(Guid organizationId, Guid projectId, Guid taskId, DeleteTaskHandler handler, CancellationToken ct)
        => ToHttpResult(await handler.HandleAsync(organizationId, projectId, taskId, ct));

    private static IResult ToHttpResult<T>(App.SharedKernel.Results.Result<T> result, int successStatusCode = StatusCodes.Status200OK)
    {
        if (result.IsFailure)
        {
            var error = new ApiErrorResponse(result.Error!.Code, result.Error.Message, result.Error.Details);
            return Results.BadRequest(ApiResponse<T>.Fail(error));
        }

        var response = ApiResponse<T>.Ok(result.Value!);
        return successStatusCode == StatusCodes.Status201Created
            ? Results.Json(response, statusCode: StatusCodes.Status201Created)
            : Results.Ok(response);
    }
}
```

## Program.cs

```csharp
// File: ProjectManagement.Backend/src/ProjectManagement.Api/Program.cs
using App.Modules.Identity;
using App.Modules.Organizations;
using App.Modules.Projects;
using App.Modules.Tasks;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddIdentityModule(builder.Configuration);
builder.Services.AddOrganizationsModule();
builder.Services.AddProjectsModule();
builder.Services.AddTasksModule();
builder.Services.AddAuthentication();
builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapIdentityModule();
app.MapOrganizationsModule();
app.MapProjectsModule();
app.MapTasksModule();

app.Run();
```

## Test Manual Dengan Curl

Sebelum test Tasks, register/login, buat organization, lalu buat project. Simpan `<access-token>`, `<organization-id>`, dan `<project-id>`.

### Create Task

```powershell
# File: ProjectManagement.Backend/commands/63-test-create-task.ps1
curl -X POST http://localhost:5000/api/organizations/<organization-id>/projects/<project-id>/tasks `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer <access-token>" `
  -d '{"title":"Setup landing page","description":"Create hero and CTA sections","priority":"High","dueDate":"2026-07-30T00:00:00+00:00","assigneeUserId":null}'
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-create-task-response.json
{
  "success": true,
  "data": {
    "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    "organizationId": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
    "projectId": "cccccccc-cccc-cccc-cccc-cccccccccccc",
    "title": "Setup landing page",
    "description": "Create hero and CTA sections",
    "status": "Todo",
    "priority": "High",
    "createdByUserId": "dddddddd-dddd-dddd-dddd-dddddddddddd",
    "assigneeUserId": null,
    "dueDate": "2026-07-30T00:00:00+00:00",
    "createdAt": "2026-07-07T10:00:00.0000000+00:00"
  },
  "error": null,
  "meta": null
}
```

### List, Search, Filter

```powershell
# File: ProjectManagement.Backend/commands/64-test-task-list.ps1
curl "http://localhost:5000/api/organizations/<organization-id>/projects/<project-id>/tasks?page=1&pageSize=10&search=landing&status=Todo" `
  -H "Authorization: Bearer <access-token>"
```

Filter assignee:

```powershell
# File: ProjectManagement.Backend/commands/65-test-task-filter-assignee.ps1
curl "http://localhost:5000/api/organizations/<organization-id>/projects/<project-id>/tasks?assigneeUserId=<user-id>" `
  -H "Authorization: Bearer <access-token>"
```

### Detail, Update, Status, Assign, Archive

```powershell
# File: ProjectManagement.Backend/commands/66-test-task-detail.ps1
curl http://localhost:5000/api/organizations/<organization-id>/projects/<project-id>/tasks/<task-id> `
  -H "Authorization: Bearer <access-token>"
```

```powershell
# File: ProjectManagement.Backend/commands/67-test-update-task.ps1
curl -X PUT http://localhost:5000/api/organizations/<organization-id>/projects/<project-id>/tasks/<task-id> `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer <access-token>" `
  -d '{"title":"Setup landing page v2","description":"Add responsive layout","priority":"Medium","dueDate":null}'
```

```powershell
# File: ProjectManagement.Backend/commands/68-test-change-task-status.ps1
curl -X PATCH http://localhost:5000/api/organizations/<organization-id>/projects/<project-id>/tasks/<task-id>/status `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer <access-token>" `
  -d '{"status":"InProgress"}'
```

```powershell
# File: ProjectManagement.Backend/commands/69-test-assign-task.ps1
curl -X PATCH http://localhost:5000/api/organizations/<organization-id>/projects/<project-id>/tasks/<task-id>/assignee `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer <access-token>" `
  -d '{"assigneeUserId":"eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"}'
```

```powershell
# File: ProjectManagement.Backend/commands/70-test-archive-task.ps1
curl -X DELETE http://localhost:5000/api/organizations/<organization-id>/projects/<project-id>/tasks/<task-id> `
  -H "Authorization: Bearer <access-token>"
```

## Error Response Sederhana

```json
// File: ProjectManagement.Backend/commands/expected-task-status-invalid-response.json
{
  "success": false,
  "data": null,
  "error": {
    "code": "TASK_STATUS_TRANSITION_INVALID",
    "message": "Status task tidak boleh berubah dari Done ke Todo.",
    "details": null
  },
  "meta": null
}
```

## Build Dan Verifikasi

```powershell
# File: ProjectManagement.Backend/commands/71-build-tasks.ps1
dotnet build
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

## Troubleshooting

### Task Tidak Muncul Di List

Penyebab umum:

- `organizationId` salah;
- `projectId` salah;
- task sudah `Archived` tetapi filter status berbeda;
- search tidak cocok;
- repository in-memory hilang setelah restart.

### User Dari Project Lain Bisa Membaca Task

Ini bug tenant isolation. Pastikan repository memakai tiga kunci:

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Infrastructure/InMemoryTaskRepository.cs
item.OrganizationId == organizationId &&
item.ProjectId == projectId &&
item.Id == taskId
```

### Status Tidak Bisa Berubah

Cek aturan di strategy:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/06-task-module.md
Todo -> InProgress atau Archived
InProgress -> Done atau Archived
Done -> Archived
Archived -> tidak bisa berubah
```

## Checklist Selesai

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/06-task-module.md
[ ] TaskItem punya OrganizationId dan ProjectId.
[ ] Endpoint task berada di bawah organization dan project route.
[ ] Repository query memakai OrganizationId + ProjectId.
[ ] Create/list/detail/update/status/assign/archive tersedia.
[ ] Pagination, search, filter status, dan filter assignee tersedia.
[ ] Status transition memakai ITaskStatusTransitionStrategy.
[ ] Handler mengecek akses project sebelum akses task.
[ ] Response memakai ApiResponse envelope.
```

## Ringkasan

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/06-task-module.md
POST /api/organizations/{organizationId}/projects/{projectId}/tasks
  -> TaskEndpoints
  -> CreateTaskHandler
  -> ProjectAccessChecker cek tenant + project access
  -> TaskItem.Create
  -> ITaskRepository.AddAsync
  -> ApiResponse<CreateTaskResponse>
```

Strategy Pattern dipakai agar aturan perubahan status task bisa diganti tanpa membuat handler penuh percabangan bisnis.
