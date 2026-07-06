# 02 - Shared Kernel

Target: membuat code umum yang dipakai semua module.

## `src/Workspace.SharedKernel/Result.cs`

```csharp
namespace Workspace.SharedKernel;

public sealed class Result<T>
{
    private Result(T? value, AppError? error)
    {
        Value = value;
        Error = error;
    }

    public T? Value { get; }
    public AppError? Error { get; }
    public bool IsSuccess => Error is null;

    public static Result<T> Ok(T value) => new(value, null);
    public static Result<T> Fail(AppError error) => new(default, error);
}
```

File baru karena use case tidak boleh langsung return HTTP response.

## `src/Workspace.SharedKernel/AppError.cs`

```csharp
namespace Workspace.SharedKernel;

public sealed record AppError(string Code, string Message, int Status);
```

## `src/Workspace.SharedKernel/ApiResponse.cs`

```csharp
namespace Workspace.SharedKernel;

public sealed record ApiResponse<T>(T? Data, AppError? Error, int Status)
{
    public static ApiResponse<T> Ok(T data, int status = 200) =>
        new(data, null, status);

    public static ApiResponse<T> Fail(AppError error) =>
        new(default, error, error.Status);
}
```

## `src/Workspace.SharedKernel/AuditEvent.cs`

```csharp
namespace Workspace.SharedKernel;

public sealed record AuditEvent(
    string Id,
    string OrganizationId,
    string ActorUserId,
    string Action,
    string EntityType,
    string EntityId,
    IReadOnlyDictionary<string, object?> Metadata,
    DateTimeOffset OccurredAt
);
```

## `src/Workspace.SharedKernel/IEventPublisher.cs`

```csharp
namespace Workspace.SharedKernel;

public interface IEventPublisher
{
    Task PublishAsync(string topic, object payload, CancellationToken cancellationToken);
}
```

## Kapan Menambah File Ke SharedKernel

Tambah ke SharedKernel jika:

- dipakai lebih dari satu module;
- tidak punya dependency ke EF Core, ASP.NET, Redis, Kafka;
- konsepnya stabil.

Jangan tambahkan ke SharedKernel jika hanya dipakai Tasks.
