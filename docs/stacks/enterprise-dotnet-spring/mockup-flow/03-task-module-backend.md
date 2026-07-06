# 03 - Task Module Backend

Target: membuat module Tasks dari domain sampai endpoint.

## Domain Entity

Buat `src/Modules/Tasks/Tasks.Domain/TaskItem.cs`.

```csharp
namespace Tasks.Domain;

public sealed class TaskItem
{
    private TaskItem() {}

    public string Id { get; private set; } = "";
    public string OrganizationId { get; private set; } = "";
    public string Title { get; private set; } = "";
    public string? Description { get; private set; }
    public string Status { get; private set; } = "todo";
    public string CreatedById { get; private set; } = "";
    public DateTimeOffset CreatedAt { get; private set; }

    public static TaskItem Create(
        string organizationId,
        string title,
        string? description,
        string createdById)
    {
        if (title.Trim().Length < 3)
        {
            throw new InvalidOperationException("Task title must be at least 3 characters.");
        }

        return new TaskItem
        {
            Id = Guid.NewGuid().ToString("N"),
            OrganizationId = organizationId,
            Title = title.Trim(),
            Description = string.IsNullOrWhiteSpace(description) ? null : description.Trim(),
            CreatedById = createdById,
            CreatedAt = DateTimeOffset.UtcNow
        };
    }
}
```

Domain entity dibuat di Domain karena aturan judul task melekat ke task.

## Repository Contract

Buat `src/Modules/Tasks/Tasks.Application/ITaskRepository.cs`.

```csharp
using Tasks.Domain;

namespace Tasks.Application;

public interface ITaskRepository
{
    Task AddAsync(TaskItem task, CancellationToken cancellationToken);
    Task<IReadOnlyList<TaskItem>> ListAsync(string organizationId, CancellationToken cancellationToken);
}
```

Application hanya tahu contract, bukan EF Core.

## Use Case

Buat `src/Modules/Tasks/Tasks.Application/CreateTaskHandler.cs`.

```csharp
using Tasks.Domain;
using Workspace.SharedKernel;

namespace Tasks.Application;

public sealed record CreateTaskCommand(
    string OrganizationId,
    string CurrentUserId,
    string Title,
    string? Description
);

public sealed class CreateTaskHandler
{
    private readonly ITaskRepository tasks;

    public CreateTaskHandler(ITaskRepository tasks)
    {
        this.tasks = tasks;
    }

    public async Task<Result<TaskItem>> Handle(
        CreateTaskCommand command,
        CancellationToken cancellationToken)
    {
        var task = TaskItem.Create(
            command.OrganizationId,
            command.Title,
            command.Description,
            command.CurrentUserId
        );

        await tasks.AddAsync(task, cancellationToken);

        return Result<TaskItem>.Ok(task);
    }
}
```

Handler dibuat file baru karena ini workflow bisnis.

## EF Core DbContext

Buat `src/Modules/Tasks/Tasks.Infrastructure/TasksDbContext.cs`.

```csharp
using Microsoft.EntityFrameworkCore;
using Tasks.Domain;

namespace Tasks.Infrastructure;

public sealed class TasksDbContext : DbContext
{
    public TasksDbContext(DbContextOptions<TasksDbContext> options) : base(options) {}

    public DbSet<TaskItem> Tasks => Set<TaskItem>();
}
```

## Repository Implementation

Buat `src/Modules/Tasks/Tasks.Infrastructure/EfTaskRepository.cs`.

```csharp
using Microsoft.EntityFrameworkCore;
using Tasks.Application;
using Tasks.Domain;

namespace Tasks.Infrastructure;

public sealed class EfTaskRepository : ITaskRepository
{
    private readonly TasksDbContext db;

    public EfTaskRepository(TasksDbContext db)
    {
        this.db = db;
    }

    public async Task AddAsync(TaskItem task, CancellationToken cancellationToken)
    {
        db.Tasks.Add(task);
        await db.SaveChangesAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<TaskItem>> ListAsync(
        string organizationId,
        CancellationToken cancellationToken)
    {
        return await db.Tasks
            .Where(task => task.OrganizationId == organizationId)
            .OrderByDescending(task => task.CreatedAt)
            .ToListAsync(cancellationToken);
    }
}
```

## Endpoint

Buat `src/Workspace.Api/TaskEndpoints.cs`.

```csharp
using Tasks.Application;
using Workspace.SharedKernel;

namespace Workspace.Api;

public static class TaskEndpoints
{
    public static void MapTaskEndpoints(this WebApplication app)
    {
        app.MapGet("/api/tasks", async (
            HttpContext context,
            ITaskRepository tasks,
            CancellationToken cancellationToken) =>
        {
            var organizationId = context.Request.Headers["x-demo-organization-id"].FirstOrDefault()
                ?? "org_demo";

            var result = await tasks.ListAsync(organizationId, cancellationToken);
            return Results.Ok(ApiResponse<IReadOnlyList<object>>.Ok(result.Cast<object>().ToList()));
        });

        app.MapPost("/api/tasks", async (
            HttpContext context,
            CreateTaskRequest request,
            CreateTaskHandler handler,
            CancellationToken cancellationToken) =>
        {
            var userId = context.Request.Headers["x-demo-user-id"].FirstOrDefault()
                ?? "user_owner";
            var organizationId = context.Request.Headers["x-demo-organization-id"].FirstOrDefault()
                ?? "org_demo";

            var result = await handler.Handle(
                new CreateTaskCommand(organizationId, userId, request.Title, request.Description),
                cancellationToken
            );

            return Results.Ok(ApiResponse<object>.Ok(result.Value!));
        });
    }
}

public sealed record CreateTaskRequest(string Title, string? Description);
```

Endpoint berada di Api karena ini adapter HTTP.
