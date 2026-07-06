# 06 - Add New Function

Contoh fungsi baru: `completeTask`.

## Domain

Tambahkan method ke `TaskItem.cs` karena status transition adalah aturan task.

```csharp
public void Complete()
{
    if (Status == "done")
    {
        throw new InvalidOperationException("Task already completed.");
    }

    Status = "done";
}
```

Jika setter `Status` masih private, method ini tetap bisa mengubah dari dalam entity.

## Application

Buat file baru:

```text
src/Modules/Tasks/Tasks.Application/CompleteTaskHandler.cs
```

Isi handler:

```csharp
namespace Tasks.Application;

public sealed record CompleteTaskCommand(
    string OrganizationId,
    string CurrentUserId,
    string TaskId
);

public sealed class CompleteTaskHandler
{
    private readonly ITaskRepository tasks;

    public CompleteTaskHandler(ITaskRepository tasks)
    {
        this.tasks = tasks;
    }

    public async Task Handle(CompleteTaskCommand command, CancellationToken cancellationToken)
    {
        var task = await tasks.GetByIdAsync(command.TaskId, command.OrganizationId, cancellationToken);
        task.Complete();
        await tasks.SaveAsync(task, cancellationToken);
    }
}
```

## Repository Contract

Tambahkan ke `ITaskRepository.cs`:

```csharp
Task<TaskItem> GetByIdAsync(string taskId, string organizationId, CancellationToken cancellationToken);
Task SaveAsync(TaskItem task, CancellationToken cancellationToken);
```

Kenapa menambah file lama: ini contract repository yang sama.

## Infrastructure

Implementasikan method baru di `EfTaskRepository.cs`. Jangan buat repository baru hanya untuk complete task.

## API

Tambahkan endpoint di `TaskEndpoints.cs`:

```csharp
app.MapPatch("/api/tasks/{id}/complete", async (
    string id,
    HttpContext context,
    CompleteTaskHandler handler,
    CancellationToken cancellationToken) =>
{
    var user = CurrentUser.From(context);
    await handler.Handle(
        new CompleteTaskCommand(user.OrganizationId, user.UserId, id),
        cancellationToken
    );

    return Results.NoContent();
});
```

## Frontend

Tambahkan function ke `task-api.ts`:

```ts
export async function completeTask(taskId: string) {
  return fetch(`${API_BASE_URL}/api/tasks/${taskId}/complete`, {
    method: "PATCH",
    headers,
  });
}
```

Tambahkan button di list. Jika list item mulai punya banyak logic, buat `TaskListItem.tsx`.

## Checklist

- entity punya method `Complete`;
- handler baru dibuat;
- repository contract ditambah;
- EF repository ditambah;
- endpoint ditambah;
- audit event `task.completed` ditulis;
- Kafka event dipublish;
- Redis cache dihapus;
- frontend API function ditambah;
- UI button ditambah.
