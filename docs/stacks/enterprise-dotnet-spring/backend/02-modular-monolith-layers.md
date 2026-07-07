# Backend 02 - Modular Monolith Layers

File ini melanjutkan [01-solution-setup.md](01-solution-setup.md). File sebelumnya menyiapkan solution, Web API project, class library, project reference, package NuGet, endpoint `/health`, dan cara menjalankan backend.

File ini menjelaskan cara menata backend .NET enterprise sebagai modular monolith dengan layered architecture. Fokusnya adalah struktur folder, aturan dependency, batas antar module, dan contoh skeleton kode supaya pembaca junior/middle paham di mana harus menaruh controller, use case, entity, repository, dan shared code.

Catatan penamaan:

- Di file `01`, contoh project memakai nama `ProjectManagement.Api` dan `ProjectManagement.SharedKernel`.
- Di file ini, struktur final ditulis dengan nama ringkas `App.Api`, `SharedKernel`, dan `Infrastructure` agar mudah dibaca.
- Jika project sudah dibuat dengan nama `ProjectManagement.Api`, tidak perlu rename. Anggap `App.Api` di dokumen ini setara dengan host API utama.

## Apa Itu Modular Monolith

Modular monolith adalah satu aplikasi backend yang di-deploy sebagai satu unit, tetapi kode di dalamnya dipisahkan menjadi module yang jelas. Dalam Project Management App, contoh module adalah `Identity`, `Organizations`, `Projects`, dan `Audit`.

Sederhananya:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/02-modular-monolith-layers.md
Satu aplikasi backend
  berisi banyak module bisnis
  setiap module punya layer sendiri
  semua module berjalan dalam satu proses aplikasi
```

### Bedanya Dengan Monolith Biasa

Monolith biasa sering hanya dipisah berdasarkan tipe teknis:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/02-modular-monolith-layers.md
Controllers/
Services/
Repositories/
Entities/
```

Struktur seperti itu terlihat sederhana di awal, tetapi saat aplikasi membesar, fitur `Identity`, `Projects`, dan `Organizations` mudah bercampur. Controller project bisa memanggil repository organization secara langsung, service project bisa mengubah tabel project tanpa aturan jelas, dan perubahan satu fitur bisa merusak fitur lain.

Modular monolith memisahkan berdasarkan fitur bisnis:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/02-modular-monolith-layers.md
Modules/
  Projects/
    Domain/
    Application/
    Infrastructure/
    Presentation/
  Audit/
    Domain/
    Application/
    Infrastructure/
    Presentation/
```

Setiap module punya batas. Kode project tinggal di module `Projects`. Kode audit tinggal di module `Audit`.

### Bedanya Dengan Microservices

Microservices memecah aplikasi menjadi banyak service yang berjalan terpisah. Misalnya:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/02-modular-monolith-layers.md
identity-service
organization-service
project-service
project-service
```

Setiap service biasanya punya database, deployment, monitoring, logging, versioning API, dan failure handling sendiri. Ini berguna untuk organisasi besar, tetapi berat untuk project awal.

Modular monolith tetap satu aplikasi dan biasanya satu database, tetapi struktur kodenya sudah rapi. Kalau suatu hari module tertentu perlu dipisah menjadi service, boundary-nya sudah lebih siap.

### Kenapa Cocok Untuk Project Awal Enterprise

Modular monolith cocok untuk tahap awal enterprise karena:

- deployment masih sederhana karena hanya satu backend;
- transaksi database masih lebih mudah karena masih satu proses aplikasi;
- debugging lebih mudah untuk tim kecil;
- boundary module sudah dilatih sejak awal;
- testing use case bisa fokus per module;
- biaya operasional lebih rendah daripada microservices.

Untuk Project Management App, `Projects` mungkin sering membaca membership dari `Organizations`. Dalam modular monolith, komunikasi itu bisa lewat application contract atau reader interface tanpa HTTP call antar service.

### Kapan Modular Monolith Mulai Kurang Cocok

Modular monolith mulai terasa kurang cocok jika:

- satu module punya traffic jauh lebih tinggi dari module lain dan perlu scale terpisah;
- tim sudah sangat besar dan sering conflict di satu deployable app;
- release cadence antar module sangat berbeda;
- satu module butuh teknologi database yang sangat berbeda;
- failure satu module harus benar-benar tidak boleh memengaruhi module lain;
- batas domain sudah stabil dan biaya operasional microservices bisa ditanggung.

Pada tahap belajar dan tahap awal produk enterprise, modular monolith biasanya pilihan yang lebih masuk akal daripada langsung microservices.

## Apa Itu Layered Architecture

Layered architecture adalah cara memisahkan kode berdasarkan tanggung jawab. Di backend ini, setiap module punya layer berikut:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/02-modular-monolith-layers.md
Presentation/API Layer
  -> Application Layer
  -> Domain Layer

Infrastructure Layer
  -> Application Layer
  -> Domain Layer
```

### API / Presentation Layer

Tanggung jawab:

- menerima HTTP request;
- membaca route, query string, body, dan user claim;
- memanggil use case di application layer;
- mengubah result menjadi HTTP response;
- memasang authorization attribute atau policy di level endpoint.

Yang tidak boleh dilakukan:

- menulis business rule utama;
- query database langsung;
- menghitung permission tenant secara manual;
- memanggil repository infrastructure langsung dari endpoint;
- mengembalikan entity database mentah ke client.

### Application Layer

Tanggung jawab:

- menjalankan use case, command, query, dan handler;
- validasi input use case;
- menjalankan authorization berbasis tenant/role;
- mengatur transaksi;
- memanggil repository interface;
- mengembalikan DTO atau result.

Yang tidak boleh dilakukan:

- bergantung ke ASP.NET Core `HttpContext`;
- memakai EF Core `DbContext` langsung jika ingin application tetap testable;
- mengandung detail SQL/provider database;
- mengubah response HTTP langsung;
- menyimpan logic domain kompleks yang seharusnya ada di entity/value object.

### Domain Layer

Tanggung jawab:

- menyimpan entity, value object, enum, domain service, dan invariant bisnis;
- memastikan object selalu valid;
- menyimpan aturan seperti transisi status project;
- tidak peduli apakah aplikasi dipanggil dari REST API, worker, atau test.

Yang tidak boleh dilakukan:

- memakai ASP.NET Core;
- memakai EF Core attribute jika bisa dihindari;
- membaca environment variable;
- memanggil API eksternal;
- mengirim email;
- menulis log teknis;
- melakukan query database.

### Infrastructure Layer

Tanggung jawab:

- implementasi repository;
- EF Core `DbContext` dan entity mapping;
- migration database;
- adapter email, storage, payment, message broker;
- implementasi JWT, password hashing, dan provider teknis lain;
- dependency injection untuk implementasi teknis.

Yang tidak boleh dilakukan:

- membuat endpoint HTTP;
- menaruh business rule utama;
- mengubah entity domain tanpa melalui method domain yang valid;
- membuat module lain bergantung langsung ke detail database internalnya.

### Shared Kernel

Tanggung jawab:

- tipe kecil yang stabil dan dipakai lintas module;
- `Result` pattern;
- `ApiResponse` envelope;
- base entity dan audit fields;
- exception model umum;
- interface ringan yang benar-benar cross-cutting.

Yang tidak boleh dilakukan:

- menjadi tempat semua helper random;
- menyimpan business rule module tertentu;
- menyimpan repository khusus module;
- menjadi dependency besar yang membuat semua module saling terikat.

## Struktur Folder Final Backend

Struktur final yang ingin dicapai:

```txt
# File: docs/stacks/enterprise-dotnet-spring/backend/02-modular-monolith-layers.md
src/
├── App.Api/
│   ├── Program.cs
│   ├── appsettings.json
│   ├── Endpoints/
│   └── Middlewares/
│
├── SharedKernel/
│   ├── Abstractions/
│   ├── Results/
│   ├── Responses/
│   ├── Exceptions/
│   └── Entities/
│
├── Infrastructure/
│   ├── Database/
│   ├── Authentication/
│   ├── Logging/
│   └── DependencyInjection.cs
│
└── Modules/
    ├── Identity/
    │   ├── Domain/
    │   ├── Application/
    │   ├── Infrastructure/
    │   └── Presentation/
    │
    ├── Organizations/
    │   ├── Domain/
    │   ├── Application/
    │   ├── Infrastructure/
    │   └── Presentation/
    │
    ├── Projects/
    │   ├── Domain/
    │   ├── Application/
    │   ├── Infrastructure/
    │   └── Presentation/
    │
    └── Audit/
        ├── Domain/
        ├── Application/
        ├── Infrastructure/
        └── Presentation/
tests/
└── App.Tests/
```

## Fungsi Setiap Folder

### `src/App.Api`

`App.Api` adalah host aplikasi. Di sinilah aplikasi ASP.NET Core dijalankan.

Isi utama:

- `Program.cs`: composition root, registrasi service, middleware, dan endpoint.
- `appsettings.json`: konfigurasi aplikasi.
- `Endpoints/`: endpoint umum yang bukan milik module tertentu, misalnya `/health`.
- `Middlewares/`: middleware global seperti error handling dan request logging.

`App.Api` boleh reference module presentation dan infrastructure karena host bertugas merangkai semua bagian aplikasi.

### `src/SharedKernel`

`SharedKernel` berisi building block kecil yang dipakai lintas module.

Isi utama:

- `Abstractions/`: interface umum seperti `IDateTimeProvider` atau `ICurrentUser`.
- `Results/`: result pattern untuk success/failure use case.
- `Responses/`: API response envelope.
- `Exceptions/`: exception umum aplikasi.
- `Entities/`: base entity dan audit fields.

Shared Kernel harus kecil. Jika sebuah class hanya dipakai module `Projects`, taruh di module `Projects`, bukan di Shared Kernel.

### `src/Infrastructure`

`Infrastructure` root berisi cross-cutting infrastructure yang dipakai host atau banyak module.

Isi utama:

- `Database/`: konfigurasi database umum, connection, migration assembly, atau unit of work global jika dipakai.
- `Authentication/`: JWT, password hashing, current user accessor.
- `Logging/`: konfigurasi logging.
- `DependencyInjection.cs`: extension method untuk mendaftarkan service infrastructure global.

Jika infrastructure hanya milik module tertentu, taruh di `Modules/<Module>/Infrastructure`, bukan di root `Infrastructure`.

### `src/Modules/<Module>/Domain`

Domain berisi model bisnis inti module.

Contoh untuk `Projects`:

- `ProjectItem`
- `ProjectStatus`
- `ProjectStatusTransitionPolicy`
- domain error seperti `InvalidProjectStatusTransitionException`

Domain tidak boleh tahu tentang HTTP, EF Core, JWT, atau database.

### `src/Modules/<Module>/Application`

Application berisi use case module.

Contoh untuk `Projects`:

- `CreateProjectCommand`
- `CreateProjectHandler`
- `GetProjectsQuery`
- `IProjectRepository`
- `ProjectDto`
- validator request use case

Application boleh mendefinisikan interface repository, tetapi implementasinya ada di Infrastructure.

### `src/Modules/<Module>/Infrastructure`

Infrastructure module berisi implementasi teknis untuk module tersebut.

Contoh untuk `Projects`:

- `ProjectRepository`
- EF Core mapping untuk project
- query database project
- migration spesifik project jika dipisah per module
- dependency injection module project

Infrastructure boleh memakai EF Core, Npgsql, Redis, file storage, atau provider eksternal.

### `src/Modules/<Module>/Presentation`

Presentation module berisi endpoint HTTP module.

Contoh untuk `Projects`:

- `ProjectEndpoints`
- request DTO untuk HTTP body
- mapping dari HTTP request ke command/query
- mapping result ke `IResult`

Presentation tidak menyimpan business logic. Ia hanya adapter dari HTTP ke application layer.

### `tests/App.Tests`

Folder test berisi unit test dan integration test.

Contoh isi:

- unit test domain `ProjectItemTests`;
- unit test handler `CreateProjectHandlerTests`;
- integration test endpoint `/health` atau endpoint project;
- test authorization tenant.

## Command Membuat Struktur Folder

Jika memulai dari folder root backend, buat folder struktur final dengan command berikut.

```powershell
# File: ProjectManagement.Backend/commands/19-create-layer-folders.ps1
mkdir src/App.Api/Endpoints
mkdir src/App.Api/Middlewares

mkdir src/SharedKernel/Abstractions
mkdir src/SharedKernel/Results
mkdir src/SharedKernel/Responses
mkdir src/SharedKernel/Exceptions
mkdir src/SharedKernel/Entities

mkdir src/Infrastructure/Database
mkdir src/Infrastructure/Authentication
mkdir src/Infrastructure/Logging

mkdir src/Modules/Identity/Domain
mkdir src/Modules/Identity/Application
mkdir src/Modules/Identity/Infrastructure
mkdir src/Modules/Identity/Presentation

mkdir src/Modules/Organizations/Domain
mkdir src/Modules/Organizations/Application
mkdir src/Modules/Organizations/Infrastructure
mkdir src/Modules/Organizations/Presentation

mkdir src/Modules/Projects/Domain
mkdir src/Modules/Projects/Application
mkdir src/Modules/Projects/Infrastructure
mkdir src/Modules/Projects/Presentation

mkdir src/Modules/Audit/Domain
mkdir src/Modules/Audit/Application
mkdir src/Modules/Audit/Infrastructure
mkdir src/Modules/Audit/Presentation

mkdir tests/App.Tests
```

Penjelasan:

- `src/App.Api` adalah host API.
- `src/SharedKernel` berisi tipe umum lintas module.
- `src/Infrastructure` berisi infrastructure global.
- `src/Modules/<Module>` berisi module bisnis.
- `tests/App.Tests` berisi test project.

Jika mengikuti struktur project-per-layer dari `01-solution-setup.md`, command folder di atas bisa dipakai sebagai panduan logical folder di dalam masing-masing class library. Jangan memaksa rename project yang sudah dibuat jika belum diperlukan.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Directory structure created without errors.
```

Verifikasi struktur:

```powershell
# File: ProjectManagement.Backend/commands/20-verify-layer-folders.ps1
dir src
dir src/Modules
dir src/Modules/Projects
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Domain
Application
Infrastructure
Presentation
```

## Dependency Rule Antar Layer

Dependency rule adalah aturan arah reference. Tujuannya agar kode tidak saling menempel sembarangan.

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/02-modular-monolith-layers.md
App.Api
  -> SharedKernel
  -> Infrastructure
  -> Modules.*.Presentation
  -> Modules.*.Infrastructure

Modules.Projects.Presentation
  -> Modules.Projects.Application
  -> SharedKernel

Modules.Projects.Application
  -> Modules.Projects.Domain
  -> SharedKernel

Modules.Projects.Infrastructure
  -> Modules.Projects.Application
  -> Modules.Projects.Domain
  -> SharedKernel

Modules.Projects.Domain
  -> no web framework
  -> no database framework
  -> no other module internals
```

Aturan praktis:

- `Domain` tidak reference `Application`, `Infrastructure`, atau `Presentation`.
- `Application` tidak reference `Presentation` atau `Infrastructure` implementation.
- `Infrastructure` boleh reference `Application` karena ia mengimplementasikan interface dari application.
- `Presentation` boleh reference `Application` untuk memanggil handler.
- `App.Api` boleh reference semua layer yang perlu dirangkai karena ia composition root.

## Command Project Reference Sesuai Layer

Contoh untuk module `Projects` jika memakai class library terpisah seperti di file `01`.

```powershell
# File: ProjectManagement.Backend/commands/21-reference-projects-layer-rule.ps1
dotnet add src/Modules/Projects/ProjectManagement.Projects.Application/ProjectManagement.Projects.Application.csproj reference src/Modules/Projects/ProjectManagement.Projects.Domain/ProjectManagement.Projects.Domain.csproj
dotnet add src/Modules/Projects/ProjectManagement.Projects.Application/ProjectManagement.Projects.Application.csproj reference src/Shared/ProjectManagement.SharedKernel/ProjectManagement.SharedKernel.csproj

dotnet add src/Modules/Projects/ProjectManagement.Projects.Infrastructure/ProjectManagement.Projects.Infrastructure.csproj reference src/Modules/Projects/ProjectManagement.Projects.Application/ProjectManagement.Projects.Application.csproj
dotnet add src/Modules/Projects/ProjectManagement.Projects.Infrastructure/ProjectManagement.Projects.Infrastructure.csproj reference src/Modules/Projects/ProjectManagement.Projects.Domain/ProjectManagement.Projects.Domain.csproj

dotnet add src/Modules/Projects/ProjectManagement.Projects.Api/ProjectManagement.Projects.Api.csproj reference src/Modules/Projects/ProjectManagement.Projects.Application/ProjectManagement.Projects.Application.csproj

dotnet add src/ProjectManagement.Api/ProjectManagement.Api.csproj reference src/Modules/Projects/ProjectManagement.Projects.Api/ProjectManagement.Projects.Api.csproj
dotnet add src/ProjectManagement.Api/ProjectManagement.Api.csproj reference src/Modules/Projects/ProjectManagement.Projects.Infrastructure/ProjectManagement.Projects.Infrastructure.csproj
```

Penjelasan:

- Application mengenal Domain karena use case membuat dan membaca entity domain.
- Infrastructure mengenal Application karena repository implementation memenuhi interface dari Application.
- Presentation mengenal Application karena endpoint memanggil handler.
- API host mengenal Presentation dan Infrastructure agar semua endpoint dan dependency bisa didaftarkan.

Yang tidak boleh dibuat:

```powershell
# File: ProjectManagement.Backend/commands/do-not-run-invalid-references.ps1
# Jangan jalankan command ini.
dotnet add src/Modules/Projects/ProjectManagement.Projects.Domain/ProjectManagement.Projects.Domain.csproj reference src/Modules/Projects/ProjectManagement.Projects.Infrastructure/ProjectManagement.Projects.Infrastructure.csproj
```

Kenapa tidak boleh:

- Domain akan tahu detail database.
- Entity domain bisa mulai bergantung ke EF Core.
- Unit test domain menjadi lebih berat.
- Boundary bisnis menjadi lemah.

## Module Boundary

Module boundary adalah batas kepemilikan kode dan data. Dalam Project Management App:

- `Identity` memiliki data user dan credential.
- `Organizations` memiliki tenant, membership, role, dan permission.
- `Projects` memiliki project.
- `Projects` memiliki project.

Module boleh mengekspos contract kecil untuk dibaca module lain. Misalnya module `Projects` perlu tahu apakah user adalah member organization. `Projects` tidak boleh query tabel membership langsung. Lebih baik `Projects.Application` bergantung pada interface seperti `IOrganizationAccessReader`.

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/Authorization/IOrganizationAccessReader.cs
namespace App.Modules.Projects.Application.Authorization;

public interface IOrganizationAccessReader
{
    Task<OrganizationAccess?> GetAccessAsync(
        Guid organizationId,
        Guid userId,
        CancellationToken cancellationToken);
}

public sealed record OrganizationAccess(
    Guid OrganizationId,
    Guid UserId,
    string Role,
    IReadOnlyCollection<string> Permissions);
```

Implementasinya boleh berada di module `Organizations.Infrastructure` atau adapter khusus di composition root. Yang penting, `Projects.Application` tidak tahu tabel internal `Organizations`.

## Yang Boleh Dan Tidak Boleh Antar Module

Yang boleh:

- module memanggil public application contract module lain;
- module memakai shared DTO/contract yang memang disiapkan untuk integrasi;
- module menerbitkan domain event sederhana;
- module membaca data module lain lewat reader interface yang eksplisit;
- module memakai Shared Kernel untuk result, response, base entity, dan exception umum.

Yang tidak boleh:

- module `Projects` memakai repository internal `Organizations` secara langsung;
- module `Projects` mengubah tabel project langsung tanpa use case project;
- module lain memakai entity domain internal module tetangga sebagai model input/output utama;
- module saling reference dua arah tanpa alasan kuat;
- semua helper dimasukkan ke Shared Kernel hanya karena dipakai sekali.

Contoh alur yang benar saat membuat project:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/02-modular-monolith-layers.md
HTTP POST /api/organizations/{organizationId}/projects
  -> Projects.Presentation ProjectEndpoints
  -> Projects.Application CreateProjectHandler
  -> Projects.Application IOrganizationAccessReader
  -> Organizations.Infrastructure OrganizationAccessReader
  -> Projects.Domain ProjectItem.Create
  -> Projects.Application IProjectRepository
  -> Projects.Infrastructure ProjectRepository
  -> Database
```

## Skeleton Shared Kernel

### Result Pattern

`Result<T>` membantu use case mengembalikan success atau failure tanpa selalu melempar exception.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Results/Result.cs
namespace App.SharedKernel.Results;

public sealed class Result<TValue>
{
    private Result(TValue? value, AppError? error, bool isSuccess)
    {
        Value = value;
        Error = error;
        IsSuccess = isSuccess;
    }

    public TValue? Value { get; }
    public AppError? Error { get; }
    public bool IsSuccess { get; }
    public bool IsFailure => !IsSuccess;

    public static Result<TValue> Success(TValue value)
    {
        return new Result<TValue>(value, null, true);
    }

    public static Result<TValue> Failure(AppError error)
    {
        return new Result<TValue>(default, error, false);
    }
}

public sealed record AppError(
    string Code,
    string Message,
    object? Details = null);
```

### API Response Envelope

`ApiResponse<T>` memastikan response API konsisten untuk semua module.

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
    string? RequestId = null,
    int? Page = null,
    int? PageSize = null,
    int? Total = null);
```

### Base Entity Dan Audit Fields

Base entity menyimpan field umum yang hampir selalu ada di entity enterprise.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Entities/Entity.cs
namespace App.SharedKernel.Entities;

public abstract class Entity
{
    protected Entity(Guid id)
    {
        Id = id;
    }

    public Guid Id { get; protected set; }
    public DateTimeOffset CreatedAt { get; protected set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? UpdatedAt { get; protected set; }

    public void MarkUpdated(DateTimeOffset updatedAt)
    {
        UpdatedAt = updatedAt;
    }
}
```

### Exception Model

Exception dipakai untuk kondisi tidak normal. Untuk validasi bisnis biasa, gunakan `Result<T>` agar flow lebih eksplisit.

```csharp
// File: ProjectManagement.Backend/src/SharedKernel/Exceptions/AppException.cs
namespace App.SharedKernel.Exceptions;

public abstract class AppException : Exception
{
    protected AppException(string code, string message) : base(message)
    {
        Code = code;
    }

    public string Code { get; }
}

public sealed class NotFoundAppException : AppException
{
    public NotFoundAppException(string message) : base("NOT_FOUND", message)
    {
    }
}

public sealed class ForbiddenAppException : AppException
{
    public ForbiddenAppException(string message) : base("FORBIDDEN", message)
    {
    }
}
```

## Skeleton Module Projects

Module `Projects` dipakai sebagai contoh karena nanti akan punya CRUD project dan status project sederhana.

### Domain Layer

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Domain/ProjectStatus.cs
namespace App.Modules.Projects.Domain;

public enum ProjectStatus
{
    Todo = 1,
    InProgress = 2,
    Done = 3,
    Cancelled = 4
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Domain/ProjectItem.cs
using App.SharedKernel.Entities;

namespace App.Modules.Projects.Domain;

public sealed class ProjectItem : Entity
{
    private ProjectItem(
        Guid id,
        Guid organizationId,
        Guid projectId,
        string title,
        string? description,
        Guid createdByUserId) : base(id)
    {
        OrganizationId = organizationId;
        ProjectId = projectId;
        Title = title;
        Description = description;
        CreatedByUserId = createdByUserId;
        Status = ProjectStatus.Todo;
    }

    public Guid OrganizationId { get; private set; }
    public Guid ProjectId { get; private set; }
    public string Title { get; private set; }
    public string? Description { get; private set; }
    public ProjectStatus Status { get; private set; }
    public Guid? AssigneeUserId { get; private set; }
    public Guid CreatedByUserId { get; private set; }

    public static ProjectItem Create(
        Guid organizationId,
        Guid projectId,
        string title,
        string? description,
        Guid createdByUserId)
    {
        if (organizationId == Guid.Empty)
            throw new ArgumentException("OrganizationId wajib diisi.");

        if (projectId == Guid.Empty)
            throw new ArgumentException("ProjectId wajib diisi.");

        if (createdByUserId == Guid.Empty)
            throw new ArgumentException("CreatedByUserId wajib diisi.");

        if (string.IsNullOrWhiteSpace(title) || title.Trim().Length < 3)
            throw new ArgumentException("Judul project minimal 3 karakter.");

        return new ProjectItem(
            Guid.NewGuid(),
            organizationId,
            projectId,
            title.Trim(),
            string.IsNullOrWhiteSpace(description) ? null : description.Trim(),
            createdByUserId);
    }

    public void AssignTo(Guid assigneeUserId)
    {
        if (assigneeUserId == Guid.Empty)
            throw new ArgumentException("AssigneeUserId wajib diisi.");

        AssigneeUserId = assigneeUserId;
        MarkUpdated(DateTimeOffset.UtcNow);
    }

    public void ChangeStatus(ProjectStatus nextStatus)
    {
        if (!ProjectStatusRules.CanMove(Status, nextStatus))
            throw new InvalidOperationException($"Project tidak bisa berubah dari {Status} ke {nextStatus}.");

        Status = nextStatus;
        MarkUpdated(DateTimeOffset.UtcNow);
    }
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Domain/ProjectStatusRules.cs
namespace App.Modules.Projects.Domain;

public static class ProjectStatusRules
{
    public static bool CanMove(ProjectStatus current, ProjectStatus next)
    {
        if (current == next)
            return true;

        return current switch
        {
            ProjectStatus.Todo => next is ProjectStatus.InProgress or ProjectStatus.Cancelled,
            ProjectStatus.InProgress => next is ProjectStatus.Done or ProjectStatus.Cancelled,
            ProjectStatus.Done => false,
            ProjectStatus.Cancelled => false,
            _ => false
        };
    }
}
```

### Application Layer

Application layer menerima input use case dan mengembalikan DTO. Ia tidak mengembalikan entity domain langsung ke API.

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/CreateProject/CreateProjectCommand.cs
namespace App.Modules.Projects.Application.CreateProject;

public sealed record CreateProjectCommand(
    Guid CurrentUserId,
    Guid OrganizationId,
    Guid ProjectId,
    string Title,
    string? Description,
    Guid? AssigneeUserId);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/ProjectDto.cs
namespace App.Modules.Projects.Application;

public sealed record ProjectDto(
    Guid Id,
    Guid OrganizationId,
    Guid ProjectId,
    string Title,
    string? Description,
    string Status,
    Guid? AssigneeUserId,
    Guid CreatedByUserId,
    DateTimeOffset CreatedAt);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/Repositories/IProjectRepository.cs
using App.Modules.Projects.Domain;

namespace App.Modules.Projects.Application.Repositories;

public interface IProjectRepository
{
    Project AddAsync(ProjectItem project, CancellationToken cancellationToken);
    Task<ProjectItem?> GetByIdAsync(Guid projectId, CancellationToken cancellationToken);
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/CreateProject/CreateProjectHandler.cs
using App.Modules.Projects.Application.Authorization;
using App.Modules.Projects.Application.Repositories;
using App.Modules.Projects.Domain;
using App.SharedKernel.Results;

namespace App.Modules.Projects.Application.CreateProject;

public sealed class CreateProjectHandler
{
    private readonly IProjectRepository _projectRepository;
    private readonly IOrganizationAccessReader _organizationAccessReader;

    public CreateProjectHandler(
        IProjectRepository projectRepository,
        IOrganizationAccessReader organizationAccessReader)
    {
        _projectRepository = projectRepository;
        _organizationAccessReader = organizationAccessReader;
    }

    public async Task<Result<ProjectDto>> HandleAsync(
        CreateProjectCommand command,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(command.Title))
        {
            return Result<ProjectDto>.Failure(new AppError(
                "PROJECT_TITLE_REQUIRED",
                "Judul project wajib diisi."));
        }

        var access = await _organizationAccessReader.GetAccessAsync(
            command.OrganizationId,
            command.CurrentUserId,
            cancellationToken);

        if (access is null || !access.Permissions.Contains("project:create"))
        {
            return Result<ProjectDto>.Failure(new AppError(
                "PROJECT_CREATE_FORBIDDEN",
                "User tidak punya akses untuk membuat project di organization ini."));
        }

        if (command.AssigneeUserId is not null && !access.Permissions.Contains("project:assign"))
        {
            return Result<ProjectDto>.Failure(new AppError(
                "PROJECT_ASSIGN_FORBIDDEN",
                "User tidak punya akses untuk assign project."));
        }

        var project = ProjectItem.Create(
            command.OrganizationId,
            command.ProjectId,
            command.Title,
            command.Description,
            command.CurrentUserId);

        if (command.AssigneeUserId is not null)
            project.AssignTo(command.AssigneeUserId.Value);

        await _projectRepository.AddAsync(project, cancellationToken);

        var dto = new ProjectDto(
            project.Id,
            project.OrganizationId,
            project.ProjectId,
            project.Title,
            project.Description,
            project.Status.ToString(),
            project.AssigneeUserId,
            project.CreatedByUserId,
            project.CreatedAt);

        return Result<ProjectDto>.Success(dto);
    }
}
```

Penjelasan:

- Handler memvalidasi input yang datang dari luar.
- Handler mengecek permission tenant lewat `IOrganizationAccessReader`.
- Handler membuat entity lewat `ProjectItem.Create`.
- Handler menyimpan lewat `IProjectRepository`, bukan EF Core langsung.
- Handler mengembalikan `Result<ProjectDto>` agar API layer bisa menentukan response HTTP.

### Infrastructure Layer

Untuk tahap layer, repository dibuat in-memory agar pembaca fokus pada boundary. Nanti repository ini diganti EF Core di file database/migration.

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Infrastructure/InMemoryProjectRepository.cs
using App.Modules.Projects.Application.Repositories;
using App.Modules.Projects.Domain;

namespace App.Modules.Projects.Infrastructure;

public sealed class InMemoryProjectRepository : IProjectRepository
{
    private static readonly List<ProjectItem> Projects = new();

    public Task AddAsync(ProjectItem project, CancellationToken cancellationToken)
    {
        Projects.Add(project);
        return Task.CompletedTask;
    }

    public Task<ProjectItem?> GetByIdAsync(Guid projectId, CancellationToken cancellationToken)
    {
        var project = Projects.FirstOrDefault(item => item.Id == projectId);
        return Task.FromResult(project);
    }
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Infrastructure/ProjectModuleInfrastructure.cs
using App.Modules.Projects.Application.Authorization;
using App.Modules.Projects.Application.Repositories;
using Microsoft.Extensions.DependencyInjection;

namespace App.Modules.Projects.Infrastructure;

public static class ProjectModuleInfrastructure
{
    public static IServiceCollection AddProjectInfrastructure(this IServiceCollection services)
    {
        services.AddSingleton<IProjectRepository, InMemoryProjectRepository>();
        services.AddSingleton<IOrganizationAccessReader, FakeOrganizationAccessReader>();

        return services;
    }
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Infrastructure/FakeOrganizationAccessReader.cs
using App.Modules.Projects.Application.Authorization;

namespace App.Modules.Projects.Infrastructure;

public sealed class FakeOrganizationAccessReader : IOrganizationAccessReader
{
    public Task<OrganizationAccess?> GetAccessAsync(
        Guid organizationId,
        Guid userId,
        CancellationToken cancellationToken)
    {
        if (organizationId == Guid.Empty || userId == Guid.Empty)
            return Task.FromResult<OrganizationAccess?>(null);

        var access = new OrganizationAccess(
            organizationId,
            userId,
            "Owner",
            new[] { "project:create", "project:assign", "project:read", "project:update", "project:delete" });

        return Task.FromResult<OrganizationAccess?>(access);
    }
}
```

Catatan:

- `FakeOrganizationAccessReader` hanya untuk skeleton awal.
- Di implementasi nyata, akses organization dibaca dari module `Organizations`.
- Interface tetap berada di application layer agar handler mudah dites.

### Presentation Layer

Presentation layer mengubah HTTP request menjadi command, lalu mengubah result menjadi response.

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Presentation/ProjectEndpoints.cs
using App.Modules.Projects.Application;
using App.Modules.Projects.Application.CreateProject;
using App.SharedKernel.Responses;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace App.Modules.Projects.Presentation;

public static class ProjectEndpoints
{
    public static IEndpointRouteBuilder MapProjectEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/organizations/{organizationId:guid}/projects")
            .WithTags("Projects");

        group.MapPost("/", CreateProjectAsync);

        return app;
    }

    private static async Task<IResult> CreateProjectAsync(
        Guid organizationId,
        CreateProjectRequest request,
        CreateProjectHandler handler,
        CancellationToken cancellationToken)
    {
        var currentUserId = request.CurrentUserId;

        var result = await handler.HandleAsync(new CreateProjectCommand(
            currentUserId,
            organizationId,
            request.ProjectId,
            request.Title,
            request.Description,
            request.AssigneeUserId), cancellationToken);

        if (result.IsFailure)
        {
            return Results.BadRequest(ApiResponse<ProjectDto>.Fail(new ApiErrorResponse(
                result.Error!.Code,
                result.Error.Message,
                result.Error.Details)));
        }

        return Results.Created(
            $"/api/projects/{result.Value!.Id}",
            ApiResponse<ProjectDto>.Ok(result.Value));
    }
}

public sealed record CreateProjectRequest(
    Guid CurrentUserId,
    Guid ProjectId,
    string Title,
    string? Description,
    Guid? AssigneeUserId);
```

Catatan penting:

- `CurrentUserId` dikirim dari body hanya untuk skeleton awal agar mudah dites dengan curl.
- Setelah auth JWT dibuat, `CurrentUserId` harus diambil dari claim token, bukan dari body.
- Endpoint tidak membuat `ProjectItem` langsung. Endpoint hanya memanggil handler.

### Dependency Injection Application Layer

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/ProjectModuleApplication.cs
using App.Modules.Projects.Application.CreateProject;
using Microsoft.Extensions.DependencyInjection;

namespace App.Modules.Projects.Application;

public static class ProjectModuleApplication
{
    public static IServiceCollection AddProjectApplication(this IServiceCollection services)
    {
        services.AddScoped<CreateProjectHandler>();
        return services;
    }
}
```

### Root Infrastructure Dependency Injection

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/DependencyInjection.cs
using Microsoft.Extensions.DependencyInjection;

namespace App.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddAppInfrastructure(this IServiceCollection services)
    {
        return services;
    }
}
```

### Program.cs Setelah Layer Dirangkai

```csharp
// File: ProjectManagement.Backend/src/App.Api/Program.cs
using App.Infrastructure;
using App.Modules.Projects.Application;
using App.Modules.Projects.Infrastructure;
using App.Modules.Projects.Presentation;
using App.SharedKernel.Responses;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddAppInfrastructure();
builder.Services.AddProjectApplication();
builder.Services.AddProjectInfrastructure();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.MapGet("/health", () =>
{
    var response = ApiResponse<object>.Ok(new
    {
        service = "App.Api",
        status = "Healthy",
        checkedAt = DateTimeOffset.UtcNow
    });

    return Results.Ok(response);
});

app.MapProjectEndpoints();

app.Run();
```

Jika masih memakai nama project dari file `01`, path-nya menjadi:

```csharp
// File: ProjectManagement.Backend/src/ProjectManagement.Api/Program.cs
using App.Infrastructure;
using App.Modules.Projects.Application;
using App.Modules.Projects.Infrastructure;
using App.Modules.Projects.Presentation;
using App.SharedKernel.Responses;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddAppInfrastructure();
builder.Services.AddProjectApplication();
builder.Services.AddProjectInfrastructure();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.MapGet("/health", () =>
{
    var response = ApiResponse<object>.Ok(new
    {
        service = "ProjectManagement.Api",
        status = "Healthy",
        checkedAt = DateTimeOffset.UtcNow
    });

    return Results.Ok(response);
});

app.MapProjectEndpoints();

app.Run();
```

## Test Manual Endpoint Project

Jalankan backend.

```powershell
# File: ProjectManagement.Backend/commands/22-run-api-after-layers.ps1
dotnet run --project src/ProjectManagement.Api/ProjectManagement.Api.csproj
```

Penjelasan:

- `dotnet run --project` menjalankan host API.
- Jika memakai nama `App.Api`, ganti path menjadi `src/App.Api/App.Api.csproj`.
- Endpoint project akan aktif jika `app.MapProjectEndpoints()` sudah dipanggil di `Program.cs`.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Now listening on: http://localhost:5000
Application started. Press Ctrl+C to shut down.
```

Test create project dengan curl.

```powershell
# File: ProjectManagement.Backend/commands/23-test-create-project.ps1
curl -X POST http://localhost:5000/api/organizations/11111111-1111-1111-1111-111111111111/projects `
  -H "Content-Type: application/json" `
  -d '{"currentUserId":"22222222-2222-2222-2222-222222222222","projectId":"33333333-3333-3333-3333-333333333333","title":"Membuat struktur modular monolith","description":"Pisahkan API, application, domain, dan infrastructure","assigneeUserId":"22222222-2222-2222-2222-222222222222"}'
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-create-project-response.json
{
  "success": true,
  "data": {
    "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    "organizationId": "11111111-1111-1111-1111-111111111111",
    "projectId": "33333333-3333-3333-3333-333333333333",
    "title": "Membuat struktur modular monolith",
    "description": "Pisahkan API, application, domain, dan infrastructure",
    "status": "Todo",
    "assigneeUserId": "22222222-2222-2222-2222-222222222222",
    "createdByUserId": "22222222-2222-2222-2222-222222222222",
    "createdAt": "2026-07-07T10:00:00.0000000+00:00"
  },
  "error": null,
  "meta": null
}
```

Nilai `id` dan `createdAt` akan berbeda di mesin masing-masing.

Test validasi title kosong.

```powershell
# File: ProjectManagement.Backend/commands/24-test-create-project-invalid-title.ps1
curl -X POST http://localhost:5000/api/organizations/11111111-1111-1111-1111-111111111111/projects `
  -H "Content-Type: application/json" `
  -d '{"currentUserId":"22222222-2222-2222-2222-222222222222","projectId":"33333333-3333-3333-3333-333333333333","title":"","description":null,"assigneeUserId":null}'
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-create-project-invalid-response.json
{
  "success": false,
  "data": null,
  "error": {
    "code": "PROJECT_TITLE_REQUIRED",
    "message": "Judul project wajib diisi.",
    "details": null
  },
  "meta": null
}
```

## Build Dan Verifikasi Dependency

Build solution setelah layer dirangkai.

```powershell
# File: ProjectManagement.Backend/commands/25-build-after-layers.ps1
dotnet build
```

Penjelasan:

- `dotnet build` memastikan semua namespace, project reference, dan package sudah benar.
- Jika ada layer yang reference-nya salah, error akan muncul di sini.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

Cek reference project domain. Domain seharusnya tidak punya reference ke infrastructure atau presentation.

```powershell
# File: ProjectManagement.Backend/commands/26-check-domain-reference.ps1
dotnet list src/Modules/Projects/ProjectManagement.Projects.Domain/ProjectManagement.Projects.Domain.csproj reference
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
There are no Project to Project references in project ProjectManagement.Projects.Domain.
```

Cek reference application.

```powershell
# File: ProjectManagement.Backend/commands/27-check-application-reference.ps1
dotnet list src/Modules/Projects/ProjectManagement.Projects.Application/ProjectManagement.Projects.Application.csproj reference
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Project reference(s)
--------------------
..\ProjectManagement.Projects.Domain\ProjectManagement.Projects.Domain.csproj
..\..\..\Shared\ProjectManagement.SharedKernel\ProjectManagement.SharedKernel.csproj
```

## Testing Boundary Dengan Unit Test

Buat test project jika belum ada.

```powershell
# File: ProjectManagement.Backend/commands/28-create-test-project.ps1
dotnet new xunit -n App.Tests -o tests/App.Tests
dotnet sln add tests/App.Tests/App.Tests.csproj
dotnet add tests/App.Tests/App.Tests.csproj reference src/Modules/Projects/ProjectManagement.Projects.Domain/ProjectManagement.Projects.Domain.csproj
```

Penjelasan:

- `dotnet new xunit` membuat project test.
- Test domain hanya perlu reference ke domain project.
- Test domain tidak perlu web host atau database.

Contoh test domain status project.

```csharp
// File: ProjectManagement.Backend/tests/App.Tests/ProjectStatusRulesTests.cs
using App.Modules.Projects.Domain;
using Xunit;

namespace App.Tests;

public sealed class ProjectStatusRulesTests
{
    [Fact]
    public void Todo_Can_Move_To_InProgress()
    {
        var canMove = ProjectStatusRules.CanMove(ProjectStatus.Todo, ProjectStatus.InProgress);

        Assert.True(canMove);
    }

    [Fact]
    public void Done_Cannot_Move_To_InProgress()
    {
        var canMove = ProjectStatusRules.CanMove(ProjectStatus.Done, ProjectStatus.InProgress);

        Assert.False(canMove);
    }
}
```

Run test.

```powershell
# File: ProjectManagement.Backend/commands/29-run-tests.ps1
dotnet test
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Passed!  - Failed: 0, Passed: 2, Skipped: 0
```

## Checklist Layer Per Module

Gunakan checklist ini setiap membuat module baru.

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/02-modular-monolith-layers.md
[ ] Domain berisi entity, enum, value object, dan business rule.
[ ] Application berisi command, query, handler, DTO, validator, dan interface repository.
[ ] Infrastructure berisi implementasi repository, DbContext, mapping, dan provider teknis.
[ ] Presentation berisi endpoint HTTP dan request DTO.
[ ] API host memanggil Map<Module>Endpoints().
[ ] API host mendaftarkan Add<Module>Application().
[ ] API host mendaftarkan Add<Module>Infrastructure().
[ ] Module tidak query tabel module lain secara langsung.
[ ] Domain tidak reference ASP.NET Core atau EF Core.
[ ] Response API memakai envelope yang konsisten.
```

## Troubleshooting Layer

### Error: Handler Tidak Bisa Di-resolve Dari Dependency Injection

Contoh error:

```text
# File: ProjectManagement.Backend/commands/troubleshoot-di-handler.txt
InvalidOperationException: Unable to resolve service for type 'CreateProjectHandler'
```

Penyebab:

- `CreateProjectHandler` belum didaftarkan ke DI.
- `AddProjectApplication()` belum dipanggil di `Program.cs`.

Solusi:

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/ProjectModuleApplication.cs
using App.Modules.Projects.Application.CreateProject;
using Microsoft.Extensions.DependencyInjection;

namespace App.Modules.Projects.Application;

public static class ProjectModuleApplication
{
    public static IServiceCollection AddProjectApplication(this IServiceCollection services)
    {
        services.AddScoped<CreateProjectHandler>();
        return services;
    }
}
```

Lalu pastikan dipanggil:

```csharp
// File: ProjectManagement.Backend/src/App.Api/Program.cs
builder.Services.AddProjectApplication();
```

### Error: Repository Tidak Bisa Di-resolve

Contoh error:

```text
# File: ProjectManagement.Backend/commands/troubleshoot-di-repository.txt
InvalidOperationException: Unable to resolve service for type 'IProjectRepository'
```

Penyebab:

- interface `IProjectRepository` sudah dipakai handler;
- implementasi `InMemoryProjectRepository` belum didaftarkan;
- `AddProjectInfrastructure()` belum dipanggil.

Solusi:

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Infrastructure/ProjectModuleInfrastructure.cs
using App.Modules.Projects.Application.Repositories;
using Microsoft.Extensions.DependencyInjection;

namespace App.Modules.Projects.Infrastructure;

public static class ProjectModuleInfrastructure
{
    public static IServiceCollection AddProjectInfrastructure(this IServiceCollection services)
    {
        services.AddSingleton<IProjectRepository, InMemoryProjectRepository>();
        return services;
    }
}
```

Lalu pastikan dipanggil:

```csharp
// File: ProjectManagement.Backend/src/App.Api/Program.cs
builder.Services.AddProjectInfrastructure();
```

### Error: Namespace Tidak Ditemukan

Contoh error:

```text
# File: ProjectManagement.Backend/commands/troubleshoot-namespace.txt
error CS0246: The type or namespace name 'App.Modules.Projects.Application' could not be found
```

Penyebab:

- project reference belum ditambahkan;
- namespace di file tidak sama dengan `using`;
- project belum masuk solution.

Solusi:

```powershell
# File: ProjectManagement.Backend/commands/30-fix-namespace-reference.ps1
dotnet sln list
dotnet list src/ProjectManagement.Api/ProjectManagement.Api.csproj reference
dotnet build
```

Tambahkan reference yang hilang dengan `dotnet add reference`.

### Error: Domain Mengandung Dependency Infrastructure

Gejala:

- domain perlu package EF Core;
- domain memakai `DbContext`;
- domain memakai attribute mapping database;
- test domain harus setup database.

Solusi arsitektur:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/02-modular-monolith-layers.md
Pindahkan DbContext, repository implementation, dan mapping database ke Infrastructure.
Biarkan Domain hanya berisi business rule murni.
Application cukup mengenal interface repository.
```

## Ringkasan

Modular monolith bukan berarti semua kode ada di satu folder besar. Backend tetap satu deployable app, tetapi module dan layer dipisah jelas.

Alur yang perlu diingat:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/02-modular-monolith-layers.md
HTTP request
  -> Presentation endpoint
  -> Application handler
  -> Domain entity/business rule
  -> Application repository interface
  -> Infrastructure repository implementation
  -> Database
  -> ApiResponse
```

Jika aturan ini dijaga sejak awal, fitur berikutnya seperti auth, organization tenancy, project CRUD, task CRUD, audit log, pagination, dan validation bisa ditambahkan tanpa membuat kode cepat berantakan.
