# Backend 07 - Shared Kernel

File ini memperdalam standar `SharedKernel` untuk backend .NET Modular Monolith dengan Layered Architecture. Shared Kernel sudah dikenalkan di [02-modular-monolith-layers.md](02-modular-monolith-layers.md), tetapi file ini membuat versi yang lebih lengkap dan konsisten untuk dipakai module `Identity`, `Organizations`, `Projects`, `Tasks`, dan module berikutnya.

Shared Kernel adalah kode bersama yang boleh dipakai banyak module. Karena dipakai banyak tempat, Shared Kernel harus kecil, stabil, dan generic. Ia tidak boleh menjadi tempat menaruh semua helper, semua repository, atau semua business rule.

Tujuan file ini:

- membuat struktur `SharedKernel` yang jelas;
- menyiapkan base entity dan audit fields;
- menyiapkan `Result` dan `Error` pattern;
- menyiapkan response envelope dan paged response;
- menyiapkan pagination request/metadata;
- menyiapkan exception generic;
- menyiapkan abstraction untuk domain event dan waktu;
- menjaga agar Shared Kernel tidak bergantung ke module bisnis tertentu.

## Apa Itu Shared Kernel

Shared Kernel adalah bagian kode yang digunakan bersama oleh banyak module. Contoh: `Result<T>`, `ApiResponse<T>`, `BaseEntity`, atau `PaginationRequest`.

Shared Kernel bukan tempat semua helper. Jika sebuah helper hanya dipakai module `Projects`, taruh di module `Projects`. Jika class hanya dipakai module `Tasks`, taruh di module `Tasks`.

Shared Kernel tidak boleh tahu detail `Identity`, `Organizations`, `Projects`, atau `Tasks`. Artinya, Shared Kernel tidak boleh punya class seperti `UserRepository`, `ProjectPolicy`, `OrganizationAccessChecker`, atau `TaskStatusTransitionStrategy`.

Shared Kernel boleh berisi:

- abstraction umum;
- base entity;
- result pattern;
- response envelope;
- exception generic;
- pagination model;
- domain event generic.

## Kenapa Shared Kernel Harus Kecil

Karena semua module bisa bergantung ke Shared Kernel. Jika Shared Kernel terlalu besar, semua module ikut membawa dependency yang tidak perlu.

Masalah jika Shared Kernel menjadi terlalu gemuk:

- module jadi saling terikat secara tidak langsung;
- perubahan kecil bisa memicu build banyak module;
- business rule module bocor ke module lain;
- sulit memisahkan module di masa depan;
- developer mulai menaruh helper random karena folder shared terasa praktis.

Aturan praktis:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/07-shared-kernel.md
Jika konsep berlaku untuk semua module dan stabil, boleh masuk Shared Kernel.
Jika konsep hanya milik satu module, jangan masuk Shared Kernel.
Jika konsep masih sering berubah, jangan buru-buru masuk Shared Kernel.
```

## Yang Boleh Masuk Shared Kernel

### BaseEntity

Base entity menyimpan `Id` dan domain event list. Ini generic untuk semua entity.

### AuditableEntity

Auditable entity menambahkan `CreatedAt`, `CreatedBy`, `UpdatedAt`, dan `UpdatedBy`. Ini umum dipakai entity enterprise.

### Result Dan Error

`Result` dan `Error` dipakai use case untuk mengembalikan success/failure tanpa selalu melempar exception.

### ApiResponse

`ApiResponse<T>` menjaga bentuk response API tetap konsisten lintas module.

### PagedResponse

`PagedResponse<T>` dipakai endpoint list yang punya pagination.

### PaginationRequest Dan PaginationMetadata

Model pagination yang generic, misalnya `page`, `pageSize`, dan `total`.

### Exception Generic

Exception seperti `DomainException`, `ValidationException`, dan `NotFoundException` boleh masuk karena sifatnya umum.

### Domain Event Generic

`IDomainEvent` dan `DomainEvent` boleh masuk sebagai abstraction event. Event spesifik seperti `ProjectCreatedEvent` tetap berada di module `Projects`.

### IDateTimeProvider

Abstraction waktu membuat kode lebih testable. Module tidak perlu langsung memanggil `DateTimeOffset.UtcNow` di semua tempat.

### ICurrentUserContext Generic

Boleh masuk jika bentuknya benar-benar generic, misalnya hanya `UserId`, `Email`, dan `IsAuthenticated`. Jangan isi permission atau role spesifik module di Shared Kernel.

## Yang Tidak Boleh Masuk Shared Kernel

Contoh yang tidak boleh:

- `UserRepository` karena milik module Identity.
- `ProjectRepository` karena milik module Projects.
- `OrganizationAccessChecker` karena berisi aturan access organization.
- `TaskStatusTransitionStrategy` karena business rule task.
- JWT service detail karena bagian infrastructure Identity/Auth.
- EF Core `DbContext` spesifik module.
- DTO spesifik fitur seperti `CreateProjectRequest` atau `LoginResponse`.
- Business rule seperti `Owner boleh add member`.
- Helper random yang hanya dipakai satu module.

Jika ragu, mulai dari module lokal dulu. Pindahkan ke Shared Kernel hanya setelah terbukti generic dan stabil.

## Struktur Folder SharedKernel

```txt
# File: docs/stacks/enterprise-dotnet-spring/backend/07-shared-kernel.md
src/
└── SharedKernel/
    ├── Abstractions/
    │   ├── IDateTimeProvider.cs
    │   └── IDomainEvent.cs
    │
    ├── Entities/
    │   ├── BaseEntity.cs
    │   └── AuditableEntity.cs
    │
    ├── Events/
    │   └── DomainEvent.cs
    │
    ├── Results/
    │   ├── Error.cs
    │   ├── Result.cs
    │   └── ResultT.cs
    │
    ├── Responses/
    │   ├── ApiResponse.cs
    │   └── PagedResponse.cs
    │
    ├── Pagination/
    │   ├── PaginationRequest.cs
    │   └── PaginationMetadata.cs
    │
    ├── Exceptions/
    │   ├── DomainException.cs
    │   ├── ValidationException.cs
    │   └── NotFoundException.cs
    │
    └── DependencyInjection.cs
```

## Command Membuat Folder

Jalankan dari root backend.

```powershell
# File: ProjectManagement.Backend/commands/72-create-shared-kernel-folders.ps1
mkdir src/SharedKernel/Abstractions
mkdir src/SharedKernel/Entities
mkdir src/SharedKernel/Events
mkdir src/SharedKernel/Results
mkdir src/SharedKernel/Responses
mkdir src/SharedKernel/Pagination
mkdir src/SharedKernel/Exceptions
```

Penjelasan:

- `Abstractions` berisi interface generic.
- `Entities` berisi base entity.
- `Events` berisi base domain event.
- `Results` berisi result pattern.
- `Responses` berisi response envelope.
- `Pagination` berisi model pagination.
- `Exceptions` berisi exception generic.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Directory structure created without errors.
```

## Abstractions

### IDateTimeProvider

Gunakan abstraction waktu agar test tidak bergantung pada waktu real.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Abstractions/IDateTimeProvider.cs
namespace App.SharedKernel.Abstractions;

public interface IDateTimeProvider
{
    DateTimeOffset UtcNow { get; }
}
```

Implementasi default bisa diletakkan di infrastructure umum atau Shared Kernel jika tidak membawa dependency eksternal.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Abstractions/SystemDateTimeProvider.cs
namespace App.SharedKernel.Abstractions;

public sealed class SystemDateTimeProvider : IDateTimeProvider
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}
```

### IDomainEvent

Domain event generic tidak tahu module spesifik.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Abstractions/IDomainEvent.cs
namespace App.SharedKernel.Abstractions;

public interface IDomainEvent
{
    Guid Id { get; }
    DateTimeOffset OccurredAt { get; }
}
```

### ICurrentUserContext

Abstraction current user boleh masuk Shared Kernel jika benar-benar generic.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Abstractions/ICurrentUserContext.cs
namespace App.SharedKernel.Abstractions;

public interface ICurrentUserContext
{
    bool IsAuthenticated { get; }
    Guid UserId { get; }
    string Email { get; }
}
```

Jangan tambahkan `OrganizationRole`, `ProjectPermission`, atau `TaskPermission` ke interface ini. Itu sudah domain-specific.

## Entities

### BaseEntity

Base entity menyimpan id dan domain events. Event disimpan di entity, lalu nanti bisa dipublish oleh application/infrastructure layer.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Entities/BaseEntity.cs
using App.SharedKernel.Abstractions;

namespace App.SharedKernel.Entities;

public abstract class BaseEntity
{
    private readonly List<IDomainEvent> _domainEvents = new();

    protected BaseEntity(Guid id)
    {
        if (id == Guid.Empty)
            throw new ArgumentException("Entity id tidak boleh kosong.");

        Id = id;
    }

    public Guid Id { get; protected set; }

    public IReadOnlyCollection<IDomainEvent> DomainEvents => _domainEvents.AsReadOnly();

    protected void AddDomainEvent(IDomainEvent domainEvent)
    {
        _domainEvents.Add(domainEvent);
    }

    public void ClearDomainEvents()
    {
        _domainEvents.Clear();
    }
}
```

### AuditableEntity

Auditable entity dipakai saat entity perlu menyimpan audit fields.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Entities/AuditableEntity.cs
namespace App.SharedKernel.Entities;

public abstract class AuditableEntity : BaseEntity
{
    protected AuditableEntity(Guid id) : base(id)
    {
    }

    public DateTimeOffset CreatedAt { get; protected set; }
    public Guid? CreatedByUserId { get; protected set; }
    public DateTimeOffset? UpdatedAt { get; protected set; }
    public Guid? UpdatedByUserId { get; protected set; }

    public void MarkCreated(DateTimeOffset createdAt, Guid? createdByUserId)
    {
        CreatedAt = createdAt;
        CreatedByUserId = createdByUserId;
    }

    public void MarkUpdated(DateTimeOffset updatedAt, Guid? updatedByUserId)
    {
        UpdatedAt = updatedAt;
        UpdatedByUserId = updatedByUserId;
    }
}
```

Catatan: audit fields generic boleh di Shared Kernel. Tetapi audit log spesifik seperti `ProjectArchivedAuditLog` tidak boleh masuk Shared Kernel.

## Events

`DomainEvent` adalah base record untuk event domain. Event spesifik tetap dibuat di module masing-masing.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Events/DomainEvent.cs
using App.SharedKernel.Abstractions;

namespace App.SharedKernel.Events;

public abstract record DomainEvent : IDomainEvent
{
    protected DomainEvent(DateTimeOffset occurredAt)
    {
        Id = Guid.NewGuid();
        OccurredAt = occurredAt;
    }

    public Guid Id { get; init; }
    public DateTimeOffset OccurredAt { get; init; }
}
```

Contoh event spesifik yang tidak ditaruh di Shared Kernel:

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Domain/Events/ProjectCreatedEvent.cs
using App.SharedKernel.Events;

namespace App.Modules.Projects.Domain.Events;

public sealed record ProjectCreatedEvent(
    Guid ProjectId,
    Guid OrganizationId,
    Guid CreatedByUserId,
    DateTimeOffset OccurredAt) : DomainEvent(OccurredAt);
```

## Results

### Error

`Error` adalah model error generic untuk use case.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Results/Error.cs
namespace App.SharedKernel.Results;

public sealed record Error(
    string Code,
    string Message,
    object? Details = null)
{
    public static readonly Error None = new(string.Empty, string.Empty);

    public static Error Validation(string code, string message, object? details = null)
    {
        return new Error(code, message, details);
    }

    public static Error NotFound(string code, string message)
    {
        return new Error(code, message);
    }

    public static Error Forbidden(string code, string message)
    {
        return new Error(code, message);
    }
}
```

### Result

`Result` dipakai untuk operasi tanpa return value khusus.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Results/Result.cs
namespace App.SharedKernel.Results;

public class Result
{
    protected Result(bool isSuccess, Error error)
    {
        if (isSuccess && error != Error.None)
            throw new InvalidOperationException("Success result tidak boleh punya error.");

        if (!isSuccess && error == Error.None)
            throw new InvalidOperationException("Failure result wajib punya error.");

        IsSuccess = isSuccess;
        Error = error;
    }

    public bool IsSuccess { get; }
    public bool IsFailure => !IsSuccess;
    public Error Error { get; }

    public static Result Success()
    {
        return new Result(true, Error.None);
    }

    public static Result Failure(Error error)
    {
        return new Result(false, error);
    }
}
```

### ResultT

`Result<T>` dipakai untuk operasi yang mengembalikan value.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Results/ResultT.cs
namespace App.SharedKernel.Results;

public sealed class Result<TValue> : Result
{
    private readonly TValue? _value;

    private Result(TValue value) : base(true, Error.None)
    {
        _value = value;
    }

    private Result(Error error) : base(false, error)
    {
        _value = default;
    }

    public TValue Value => IsSuccess
        ? _value!
        : throw new InvalidOperationException("Failure result tidak punya value.");

    public static Result<TValue> Success(TValue value)
    {
        return new Result<TValue>(value);
    }

    public static new Result<TValue> Failure(Error error)
    {
        return new Result<TValue>(error);
    }
}
```

## Responses

### ApiResponse

`ApiResponse<T>` dipakai oleh Presentation layer untuk response konsisten.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Responses/ApiResponse.cs
namespace App.SharedKernel.Responses;

public sealed record ApiResponse<TData>(
    bool Success,
    TData? Data,
    ApiErrorResponse? Error,
    ResponseMeta? Meta = null)
{
    public static ApiResponse<TData> Ok(TData data, ResponseMeta? meta = null)
    {
        return new ApiResponse<TData>(true, data, null, meta);
    }

    public static ApiResponse<TData> Fail(ApiErrorResponse error, ResponseMeta? meta = null)
    {
        return new ApiResponse<TData>(false, default, error, meta);
    }
}

public sealed record ApiErrorResponse(
    string Code,
    string Message,
    object? Details = null);

public sealed record ResponseMeta(
    string? RequestId = null);
```

### PagedResponse

Paged response untuk list data.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Responses/PagedResponse.cs
using App.SharedKernel.Pagination;

namespace App.SharedKernel.Responses;

public sealed record PagedResponse<TItem>(
    IReadOnlyCollection<TItem> Items,
    PaginationMetadata Pagination);
```

## Pagination

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Pagination/PaginationRequest.cs
namespace App.SharedKernel.Pagination;

public sealed record PaginationRequest(int Page = 1, int PageSize = 20)
{
    public int SafePage => Page < 1 ? 1 : Page;
    public int SafePageSize => PageSize is < 1 or > 100 ? 20 : PageSize;
    public int Skip => (SafePage - 1) * SafePageSize;
}
```

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Pagination/PaginationMetadata.cs
namespace App.SharedKernel.Pagination;

public sealed record PaginationMetadata(
    int Page,
    int PageSize,
    int TotalItems,
    int TotalPages)
{
    public static PaginationMetadata Create(int page, int pageSize, int totalItems)
    {
        var totalPages = pageSize <= 0
            ? 0
            : (int)Math.Ceiling(totalItems / (double)pageSize);

        return new PaginationMetadata(page, pageSize, totalItems, totalPages);
    }
}
```

## Exceptions

Exception generic boleh masuk Shared Kernel. Gunakan exception untuk kondisi yang benar-benar exceptional. Untuk validasi request umum, lebih sering gunakan `Result<T>`.

### DomainException

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Exceptions/DomainException.cs
namespace App.SharedKernel.Exceptions;

public class DomainException : Exception
{
    public DomainException(string code, string message) : base(message)
    {
        Code = code;
    }

    public string Code { get; }
}
```

### ValidationException

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Exceptions/ValidationException.cs
namespace App.SharedKernel.Exceptions;

public sealed class ValidationException : DomainException
{
    public ValidationException(string code, string message, IReadOnlyDictionary<string, string[]>? errors = null)
        : base(code, message)
    {
        Errors = errors ?? new Dictionary<string, string[]>();
    }

    public IReadOnlyDictionary<string, string[]> Errors { get; }
}
```

### NotFoundException

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Exceptions/NotFoundException.cs
namespace App.SharedKernel.Exceptions;

public sealed class NotFoundException : DomainException
{
    public NotFoundException(string resourceName, object resourceId)
        : base("NOT_FOUND", $"{resourceName} dengan id '{resourceId}' tidak ditemukan.")
    {
        ResourceName = resourceName;
        ResourceId = resourceId;
    }

    public string ResourceName { get; }
    public object ResourceId { get; }
}
```

Catatan: exception ini generic. Jangan membuat `ProjectNotFoundException` di Shared Kernel. Jika perlu exception spesifik project, taruh di module `Projects`.

## Dependency Injection

Shared Kernel biasanya tidak punya banyak service. Tetapi `IDateTimeProvider` boleh didaftarkan di sini karena generic.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/DependencyInjection.cs
using App.SharedKernel.Abstractions;
using Microsoft.Extensions.DependencyInjection;

namespace App.SharedKernel;

public static class DependencyInjection
{
    public static IServiceCollection AddSharedKernel(this IServiceCollection services)
    {
        services.AddSingleton<IDateTimeProvider, SystemDateTimeProvider>();
        return services;
    }
}
```

Panggil di API host:

```csharp
// File: ProjectManagement.Backend/src/ProjectManagement.Api/Program.cs
using App.SharedKernel;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSharedKernel();
```

## Contoh Pemakaian Di Module

### Menggunakan Result Dan Error

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/CreateProject/CreateProjectHandler.cs
using App.SharedKernel.Results;

namespace App.Modules.Projects.Application.CreateProject;

public sealed class CreateProjectHandler
{
    public Result<string> ValidateName(string name)
    {
        if (string.IsNullOrWhiteSpace(name) || name.Trim().Length < 3)
        {
            return Result<string>.Failure(Error.Validation(
                "PROJECT_NAME_INVALID",
                "Nama project minimal 3 karakter."));
        }

        return Result<string>.Success(name.Trim());
    }
}
```

### Menggunakan ApiResponse

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Presentation/ProjectEndpointResultMapper.cs
using App.SharedKernel.Responses;
using App.SharedKernel.Results;
using Microsoft.AspNetCore.Http;

namespace App.Modules.Projects.Presentation;

public static class ProjectEndpointResultMapper
{
    public static IResult ToHttpResult<T>(Result<T> result)
    {
        if (result.IsFailure)
        {
            return Results.BadRequest(ApiResponse<T>.Fail(new ApiErrorResponse(
                result.Error.Code,
                result.Error.Message,
                result.Error.Details)));
        }

        return Results.Ok(ApiResponse<T>.Ok(result.Value));
    }
}
```

### Menggunakan Pagination

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/GetProjects/GetProjectsHandler.cs
using App.SharedKernel.Pagination;
using App.SharedKernel.Responses;

namespace App.Modules.Projects.Application.GetProjects;

public sealed class GetProjectsHandler
{
    public PagedResponse<string> BuildResponse(IReadOnlyCollection<string> items, int page, int pageSize, int total)
    {
        var metadata = PaginationMetadata.Create(page, pageSize, total);
        return new PagedResponse<string>(items, metadata);
    }
}
```

### Menggunakan BaseEntity Dan DomainEvent

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Domain/Project.cs
using App.SharedKernel.Entities;
using App.Modules.Projects.Domain.Events;

namespace App.Modules.Projects.Domain;

public sealed class Project : AuditableEntity
{
    private Project(Guid id, Guid organizationId, string name, DateTimeOffset now, Guid createdByUserId)
        : base(id)
    {
        OrganizationId = organizationId;
        Name = name;
        MarkCreated(now, createdByUserId);
        AddDomainEvent(new ProjectCreatedEvent(id, organizationId, createdByUserId, now));
    }

    public Guid OrganizationId { get; private set; }
    public string Name { get; private set; }

    public static Project Create(Guid organizationId, string name, DateTimeOffset now, Guid createdByUserId)
    {
        return new Project(Guid.NewGuid(), organizationId, name.Trim(), now, createdByUserId);
    }
}
```

## Dependency Rule Shared Kernel

Shared Kernel boleh direferensikan oleh module lain:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/07-shared-kernel.md
Identity -> SharedKernel
Organizations -> SharedKernel
Projects -> SharedKernel
Tasks -> SharedKernel
App.Api -> SharedKernel
```

Shared Kernel tidak boleh mereferensikan module lain:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/07-shared-kernel.md
SharedKernel -> Identity       tidak boleh
SharedKernel -> Organizations  tidak boleh
SharedKernel -> Projects       tidak boleh
SharedKernel -> Tasks          tidak boleh
```

Command reference contoh:

```powershell
# File: ProjectManagement.Backend/commands/73-reference-shared-kernel.ps1
dotnet add src/Modules/Projects/ProjectManagement.Projects.Application/ProjectManagement.Projects.Application.csproj reference src/Shared/ProjectManagement.SharedKernel/ProjectManagement.SharedKernel.csproj
dotnet add src/Modules/Tasks/ProjectManagement.Tasks.Application/ProjectManagement.Tasks.Application.csproj reference src/Shared/ProjectManagement.SharedKernel/ProjectManagement.SharedKernel.csproj
dotnet add src/ProjectManagement.Api/ProjectManagement.Api.csproj reference src/Shared/ProjectManagement.SharedKernel/ProjectManagement.SharedKernel.csproj
```

Jangan jalankan reference terbalik:

```powershell
# File: ProjectManagement.Backend/commands/do-not-run-shared-kernel-invalid-reference.ps1
# Jangan jalankan command ini.
dotnet add src/Shared/ProjectManagement.SharedKernel/ProjectManagement.SharedKernel.csproj reference src/Modules/Projects/ProjectManagement.Projects.Domain/ProjectManagement.Projects.Domain.csproj
```

## Build Dan Verifikasi

Build solution setelah Shared Kernel dibuat.

```powershell
# File: ProjectManagement.Backend/commands/74-build-shared-kernel.ps1
dotnet build
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

Cek reference Shared Kernel. Shared Kernel seharusnya tidak punya project reference ke module bisnis.

```powershell
# File: ProjectManagement.Backend/commands/75-check-shared-kernel-reference.ps1
dotnet list src/Shared/ProjectManagement.SharedKernel/ProjectManagement.SharedKernel.csproj reference
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
There are no Project to Project references in project ProjectManagement.SharedKernel.
```

## Troubleshooting

### Shared Kernel Mulai Terlalu Banyak Isi

Gejala:

- banyak helper unrelated;
- ada DTO fitur spesifik;
- ada repository module;
- ada business rule tenant/project/task;
- module jadi sulit dipisahkan.

Solusi:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/07-shared-kernel.md
Pindahkan class spesifik ke module pemiliknya.
Biarkan Shared Kernel hanya berisi primitive generic yang stabil.
```

### Circular Reference

Contoh masalah:

```text
# File: ProjectManagement.Backend/commands/circular-reference-example.txt
ProjectManagement.SharedKernel -> ProjectManagement.Projects.Domain
ProjectManagement.Projects.Domain -> ProjectManagement.SharedKernel
```

Solusi:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/07-shared-kernel.md
Hapus reference dari SharedKernel ke module bisnis.
Jika SharedKernel butuh konsep dari module bisnis, berarti konsep itu tidak generic.
```

### Result Dan Exception Dipakai Campur Aduk

Aturan sederhana:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/07-shared-kernel.md
Gunakan Result untuk flow bisnis yang bisa diprediksi.
Gunakan exception untuk kondisi tidak normal atau invariant domain rusak.
Jangan gunakan exception sebagai validasi request rutin.
```

### ApiResponse Dipakai Di Application Layer

`ApiResponse<T>` sebaiknya dipakai di Presentation/API layer. Application layer cukup mengembalikan `Result<T>` dan DTO.

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/07-shared-kernel.md
Application: Result<ProjectDto>
Presentation: ApiResponse<ProjectDto>
```

## Checklist Shared Kernel

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/07-shared-kernel.md
[ ] SharedKernel tidak reference module bisnis.
[ ] SharedKernel tidak punya repository spesifik module.
[ ] SharedKernel tidak punya DTO request/response fitur spesifik.
[ ] SharedKernel tidak punya business rule Identity/Organizations/Projects/Tasks.
[ ] BaseEntity dan AuditableEntity generic.
[ ] Result dan Error bisa dipakai lintas module.
[ ] ApiResponse hanya response envelope generic.
[ ] PaginationRequest dan PaginationMetadata generic.
[ ] Exception generic tidak menyebut module tertentu.
[ ] Domain event abstraction generic.
[ ] IDateTimeProvider tersedia untuk testability.
```

## Ringkasan

Shared Kernel adalah kontrak kecil yang membantu semua module berbicara dengan pola yang sama. Ia berguna untuk consistency, tetapi berbahaya jika dijadikan tempat semua kode umum.

Gunakan aturan ini:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/07-shared-kernel.md
Shared Kernel kecil.
Shared Kernel stabil.
Shared Kernel generic.
Shared Kernel tidak tahu module bisnis.
```

Dengan Shared Kernel yang sehat, module `Identity`, `Organizations`, `Projects`, dan `Tasks` bisa tetap konsisten tanpa kehilangan boundary masing-masing.
