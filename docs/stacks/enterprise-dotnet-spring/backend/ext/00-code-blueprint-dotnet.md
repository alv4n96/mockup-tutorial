# Backend 08 - Code Blueprint .NET: Response, Use Case, Controller

## Yang Dibuat

Contoh struktur kode .NET untuk modular monolith.

## Struktur File

```text
src/Shared/SharedKernel/Api/ApiResponse.cs
src/Shared/SharedKernel/Errors/AppError.cs
src/Modules/Tasks/Tasks.Domain/TaskItem.cs
src/Modules/Tasks/Tasks.Application/CreateTask/CreateTaskCommand.cs
src/Modules/Tasks/Tasks.Application/CreateTask/CreateTaskHandler.cs
src/Modules/Tasks/Tasks.Infrastructure/PrismaEquivalent/TaskRepository.cs
src/Modules/Tasks/Tasks.Api/TaskEndpoints.cs
```

## `ApiResponse.cs`

```csharp
namespace SharedKernel.Api;

public sealed record ApiResponse<TData>(
    TData? Data,
    ApiError? Error,
    int Status,
    ResponseMeta? Meta = null
);

public sealed record ApiError(
    string Code,
    string Message,
    object? Details = null
);

public sealed record ResponseMeta(
    string? RequestId = null,
    PaginationMeta? Pagination = null
);

public sealed record PaginationMeta(
    int Page,
    int PageSize,
    int TotalItems,
    int TotalPages
);
```

## `AppError.cs`

```csharp
namespace SharedKernel.Errors;

public abstract class AppError
{
    protected AppError(string code, string message)
    {
        Code = code;
        Message = message;
    }

    public string Code { get; }
    public string Message { get; }
}

public sealed class ForbiddenError : AppError
{
    public ForbiddenError(string message = "Forbidden") : base("FORBIDDEN", message) {}
}

public sealed class NotFoundError : AppError
{
    public NotFoundError(string message = "Resource not found") : base("NOT_FOUND", message) {}
}
```

## Result Type

```csharp
namespace SharedKernel.Results;

public sealed class Result<T>
{
    private Result(T? value, AppError? error, bool isSuccess)
    {
        Value = value;
        Error = error;
        IsSuccess = isSuccess;
    }

    public T? Value { get; }
    public AppError? Error { get; }
    public bool IsSuccess { get; }

    public static Result<T> Success(T value) => new(value, null, true);
    public static Result<T> Failure(AppError error) => new(default, error, false);
}
```

## Domain Entity

```csharp
namespace Tasks.Domain;

public enum TaskStatus
{
    Todo,
    InProgress,
    Done
}

public sealed class TaskItem
{
    private TaskItem() {}

    public Guid Id { get; private set; }
    public Guid OrganizationId { get; private set; }
    public Guid ProjectId { get; private set; }
    public string Title { get; private set; } = string.Empty;
    public string? Description { get; private set; }
    public TaskStatus Status { get; private set; }
    public Guid? AssigneeUserId { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }

    public static TaskItem Create(
        Guid organizationId,
        Guid projectId,
        string title,
        string? description,
        Guid? assigneeUserId)
    {
        if (string.IsNullOrWhiteSpace(title) || title.Length < 3)
            throw new ArgumentException("Task title must be at least 3 characters.");

        return new TaskItem
        {
            Id = Guid.NewGuid(),
            OrganizationId = organizationId,
            ProjectId = projectId,
            Title = title.Trim(),
            Description = string.IsNullOrWhiteSpace(description) ? null : description.Trim(),
            Status = TaskStatus.Todo,
            AssigneeUserId = assigneeUserId,
            CreatedAt = DateTimeOffset.UtcNow
        };
    }
}
```

## Command Dan Handler

```csharp
namespace Tasks.Application.CreateTask;

public sealed record CreateTaskCommand(
    Guid CurrentUserId,
    Guid OrganizationId,
    Guid ProjectId,
    string Title,
    string? Description,
    Guid? AssigneeUserId
);

public sealed record TaskDto(
    Guid Id,
    Guid OrganizationId,
    Guid ProjectId,
    string Title,
    string Status,
    Guid? AssigneeUserId,
    DateTimeOffset CreatedAt
);
```

```csharp
public interface ITaskRepository
{
    Task AddAsync(TaskItem task, CancellationToken ct);
}

public interface IOrganizationAccessReader
{
    Task<bool> IsMemberAsync(Guid organizationId, Guid userId, CancellationToken ct);
}

public sealed class CreateTaskHandler
{
    private readonly ITaskRepository _tasks;
    private readonly IOrganizationAccessReader _organizationAccess;

    public CreateTaskHandler(
        ITaskRepository tasks,
        IOrganizationAccessReader organizationAccess)
    {
        _tasks = tasks;
        _organizationAccess = organizationAccess;
    }

    public async Task<Result<TaskDto>> Handle(CreateTaskCommand command, CancellationToken ct)
    {
        var isMember = await _organizationAccess.IsMemberAsync(
            command.OrganizationId,
            command.CurrentUserId,
            ct);

        if (!isMember)
            return Result<TaskDto>.Failure(new ForbiddenError("You are not a member of this organization."));

        if (command.AssigneeUserId is not null)
        {
            var assigneeIsMember = await _organizationAccess.IsMemberAsync(
                command.OrganizationId,
                command.AssigneeUserId.Value,
                ct);

            if (!assigneeIsMember)
                return Result<TaskDto>.Failure(new ValidationError("TASK_ASSIGNEE_NOT_MEMBER", "Assignee is not a member."));
        }

        var task = TaskItem.Create(
            command.OrganizationId,
            command.ProjectId,
            command.Title,
            command.Description,
            command.AssigneeUserId);

        await _tasks.AddAsync(task, ct);

        return Result<TaskDto>.Success(new TaskDto(
            task.Id,
            task.OrganizationId,
            task.ProjectId,
            task.Title,
            task.Status.ToString(),
            task.AssigneeUserId,
            task.CreatedAt));
    }
}
```

## Minimal API Endpoint

```csharp
public static class TaskEndpoints
{
    public static IEndpointRouteBuilder MapTaskEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/organizations/{organizationId:guid}/tasks", CreateTask)
            .RequireAuthorization();

        return app;
    }

    private static async Task<IResult> CreateTask(
        Guid organizationId,
        CreateTaskRequest request,
        ClaimsPrincipal user,
        CreateTaskHandler handler,
        CancellationToken ct)
    {
        var currentUserId = Guid.Parse(user.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var result = await handler.Handle(new CreateTaskCommand(
            currentUserId,
            organizationId,
            request.ProjectId,
            request.Title,
            request.Description,
            request.AssigneeUserId), ct);

        if (!result.IsSuccess)
            return ErrorResults.From(result.Error!);

        return Results.Created(
            $"/api/tasks/{result.Value!.Id}",
            new ApiResponse<TaskDto>(result.Value, null, StatusCodes.Status201Created));
    }
}

public sealed record CreateTaskRequest(
    Guid ProjectId,
    string Title,
    string? Description,
    Guid? AssigneeUserId
);
```

## Output

Kode ini memperlihatkan:

```text
HTTP endpoint -> command -> handler -> domain -> repository -> ApiResponse
```

Ini modular monolith karena endpoint tetap satu deployable app, tetapi task logic berada dalam module `Tasks`.

## RBAC: Authorization Tenant Di Application Layer

`RequireAuthorization()` hanya memastikan user login. Permission organization tetap dicek di handler supaya aturan tenant tidak bergantung pada controller.

```text
JWT Bearer Auth
  -> ClaimsPrincipal user
  -> TaskEndpoints.CreateTask
  -> CreateTaskHandler
  -> IOrganizationAccessReader.GetMembershipAsync
  -> OrganizationPolicy.RequirePermission(TaskCreate)
  -> TaskItem.Create
  -> ITaskRepository.AddAsync
```

### Role Dan Permission

```csharp
namespace Organizations.Application.Authorization;

public enum OrganizationRole
{
    Owner,
    Admin,
    Member,
    Viewer
}

public enum Permission
{
    TaskRead,
    TaskCreate,
    TaskAssign,
    TaskUpdate,
    TaskDelete,
    MemberInvite,
    BillingManage
}

public static class RolePermissions
{
    private static readonly IReadOnlyDictionary<OrganizationRole, Permission[]> Map =
        new Dictionary<OrganizationRole, Permission[]>
        {
            [OrganizationRole.Owner] = new[]
            {
                Permission.TaskRead,
                Permission.TaskCreate,
                Permission.TaskAssign,
                Permission.TaskUpdate,
                Permission.TaskDelete,
                Permission.MemberInvite,
                Permission.BillingManage
            },
            [OrganizationRole.Admin] = new[]
            {
                Permission.TaskRead,
                Permission.TaskCreate,
                Permission.TaskAssign,
                Permission.TaskUpdate,
                Permission.TaskDelete,
                Permission.MemberInvite
            },
            [OrganizationRole.Member] = new[]
            {
                Permission.TaskRead,
                Permission.TaskCreate,
                Permission.TaskUpdate
            },
            [OrganizationRole.Viewer] = new[] { Permission.TaskRead }
        };

    public static bool Can(OrganizationRole role, Permission permission) =>
        Map.TryGetValue(role, out var permissions) && permissions.Contains(permission);
}
```

### Membership Contract

```csharp
public sealed record OrganizationMembership(
    Guid OrganizationId,
    Guid UserId,
    OrganizationRole Role
);

public interface IOrganizationAccessReader
{
    Task<OrganizationMembership?> GetMembershipAsync(
        Guid organizationId,
        Guid userId,
        CancellationToken ct);
}
```

### Policy

```csharp
public static class OrganizationPolicy
{
    public static Result<OrganizationMembership> RequirePermission(
        OrganizationMembership? membership,
        Permission permission)
    {
        if (membership is null)
        {
            return Result<OrganizationMembership>.Failure(
                new ForbiddenError("You are not a member of this organization."));
        }

        if (!RolePermissions.Can(membership.Role, permission))
        {
            return Result<OrganizationMembership>.Failure(
                new ForbiddenError("You do not have permission for this action."));
        }

        return Result<OrganizationMembership>.Success(membership);
    }
}
```

### Handler Dengan RBAC

```csharp
public sealed class CreateTaskHandler
{
    private readonly ITaskRepository _tasks;
    private readonly IOrganizationAccessReader _organizationAccess;

    public CreateTaskHandler(
        ITaskRepository tasks,
        IOrganizationAccessReader organizationAccess)
    {
        _tasks = tasks;
        _organizationAccess = organizationAccess;
    }

    public async Task<Result<TaskDto>> Handle(CreateTaskCommand command, CancellationToken ct)
    {
        var membership = await _organizationAccess.GetMembershipAsync(
            command.OrganizationId,
            command.CurrentUserId,
            ct);

        var permission = OrganizationPolicy.RequirePermission(
            membership,
            Permission.TaskCreate);

        if (!permission.IsSuccess)
            return Result<TaskDto>.Failure(permission.Error!);

        if (command.AssigneeUserId is not null &&
            !RolePermissions.Can(permission.Value!.Role, Permission.TaskAssign))
        {
            return Result<TaskDto>.Failure(
                new ForbiddenError("You cannot assign tasks."));
        }

        if (command.AssigneeUserId is not null)
        {
            var assigneeMembership = await _organizationAccess.GetMembershipAsync(
                command.OrganizationId,
                command.AssigneeUserId.Value,
                ct);

            if (assigneeMembership is null)
            {
                return Result<TaskDto>.Failure(
                    new ValidationError("TASK_ASSIGNEE_NOT_MEMBER", "Assignee is not a member."));
            }
        }

        var task = TaskItem.Create(
            command.OrganizationId,
            command.ProjectId,
            command.Title,
            command.Description,
            command.AssigneeUserId);

        await _tasks.AddAsync(task, ct);

        return Result<TaskDto>.Success(new TaskDto(
            task.Id,
            task.OrganizationId,
            task.ProjectId,
            task.Title,
            task.Status.ToString(),
            task.AssigneeUserId,
            task.CreatedAt));
    }
}
```

### Request Body

```json
{
  "projectId": "6ad0fd06-07fc-4a80-a413-2abf34f66b3a",
  "title": "Implement RBAC .NET",
  "description": "Handler membaca membership dan mengecek permission",
  "assigneeUserId": "7dd30f42-4663-44e7-8455-44b71ed4927a"
}
```

Endpoint mengambil user dari claim, bukan dari body:

```csharp
var currentUserId = Guid.Parse(user.FindFirstValue(ClaimTypes.NameIdentifier)!);
```