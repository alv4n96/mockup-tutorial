# Backend 05 - Project Module

File ini melanjutkan [01-solution-setup.md](01-solution-setup.md), [02-modular-monolith-layers.md](02-modular-monolith-layers.md), [03-identity-auth.md](03-identity-auth.md), dan [04-organization-tenancy.md](04-organization-tenancy.md). Setelah backend punya identity, JWT, organization, membership, dan tenant isolation, file ini membuat module `Projects`.

Tujuan file ini adalah membangun CRUD project yang selalu terikat ke `OrganizationId`. Project tidak boleh berdiri sendiri karena project adalah data tenant. Setiap create, list, detail, update, dan delete/archive project harus mengecek membership organization sebelum mengakses data.

Database masih memakai in-memory repository agar pembaca fokus pada alur module. EF Core migration dan seed database akan dibahas di `08-database-migration-seed.md`.

## Hubungan Projects Dengan Organizations

Module `Organizations` menentukan tenant dan membership. Module `Projects` menyimpan data kerja di dalam tenant tersebut.

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/05-project-module.md
Organization: Acme Studio
  -> Project: Website Redesign
  -> Project: Internal CRM

Organization: Beta Team
  -> Project: Mobile App
```

`Project.OrganizationId` wajib ada. Tanpa `OrganizationId`, backend tidak bisa memastikan project milik tenant mana.

Tenant isolation wajib dicek sebelum akses data project:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/05-project-module.md
Request
  -> ambil current user dari JWT
  -> cek membership user di organizationId
  -> query project dengan organizationId
  -> return response
```

## Konsep Dasar Project Module

### Project

Project adalah ruang kerja untuk mengelompokkan task. Contoh project: `Website Redesign`, `CRM Internal`, atau `Mobile App Launch`.

### Project Owner

Project owner adalah user yang membuat atau bertanggung jawab atas project. Di file ini, `OwnerUserId` disimpan di entity `Project`. Owner project berbeda dari owner organization.

### Project Member

Project member adalah user yang terlibat di project. File ini belum membuat tabel member project khusus agar fokus pada CRUD project. Untuk tahap ini, akses project mengikuti membership organization.

### Project Status

Status project membantu lifecycle project. Di file ini status sederhana:

- `Active`: project sedang berjalan.
- `Archived`: project tidak aktif tetapi masih disimpan.

Delete di file ini memakai soft delete/archive, bukan hard delete.

### Project Visibility Dalam Organization

Project hanya terlihat bagi member organization. User dari organization lain tidak boleh melihat detail project walaupun tahu `projectId`.

### Organization Role vs Project Permission

Organization role seperti `Owner`, `Admin`, dan `Member` menentukan akses umum di tenant. Project permission lebih spesifik, misalnya `project:create`, `project:update`, atau `project:delete`.

File ini memakai authorization sederhana:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/05-project-module.md
Owner/Admin/Member -> boleh read project
Owner/Admin/Member -> boleh create project
Owner/Admin -> boleh update project
Owner/Admin -> boleh archive project
```

Permission detail yang lebih granular bisa dibuat setelah pola ini stabil.

### Kenapa Project Tidak Boleh Berdiri Sendiri

Project tanpa organization membuat data tenant bocor. Contoh kesalahan umum:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/05-project-module.md
GET /api/projects/{projectId}
  -> query by projectId saja
  -> user dari tenant lain bisa menebak projectId
```

Pola yang benar:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/05-project-module.md
GET /api/organizations/{organizationId}/projects/{projectId}
  -> cek membership organizationId
  -> query project by organizationId + projectId
```

## Scope Fitur Di File Ini

Fitur yang dibuat:

- create project;
- get project list by organization;
- get project detail;
- update project;
- delete/archive project;
- pagination;
- search sederhana by name;
- filter by status;
- authorization sederhana berdasarkan membership organization;
- `ApiResponse` envelope;
- validation request sederhana;
- error response sederhana;
- in-memory repository.

Yang belum dibuat:

- EF Core table dan migration;
- audit log project;
- project member khusus;
- project-level permission granular;
- hard delete;
- frontend project UI.

## Struktur Folder Module Projects

```txt
# File: docs/stacks/enterprise-dotnet-spring/backend/05-project-module.md
src/
└── Modules/
    └── Projects/
        ├── Domain/
        │   ├── Project.cs
        │   └── ProjectStatus.cs
        │
        ├── Application/
        │   ├── Abstractions/
        │   │   ├── IProjectRepository.cs
        │   │   ├── IOrganizationAccessChecker.cs
        │   │   └── ICurrentUserService.cs
        │   │
        │   ├── CreateProject/
        │   │   ├── CreateProjectRequest.cs
        │   │   ├── CreateProjectResponse.cs
        │   │   └── CreateProjectHandler.cs
        │   │
        │   ├── GetProjects/
        │   │   ├── GetProjectsQuery.cs
        │   │   ├── ProjectListItemResponse.cs
        │   │   └── GetProjectsHandler.cs
        │   │
        │   ├── GetProjectDetail/
        │   │   ├── ProjectDetailResponse.cs
        │   │   └── GetProjectDetailHandler.cs
        │   │
        │   ├── UpdateProject/
        │   │   ├── UpdateProjectRequest.cs
        │   │   └── UpdateProjectHandler.cs
        │   │
        │   └── DeleteProject/
        │       └── DeleteProjectHandler.cs
        │
        ├── Infrastructure/
        │   ├── InMemoryProjectRepository.cs
        │   └── OrganizationAccessChecker.cs
        │
        ├── Presentation/
        │   └── ProjectEndpoints.cs
        │
        └── ProjectsModule.cs
```

## Command Membuat Folder

Jalankan dari root backend.

```powershell
# File: ProjectManagement.Backend/commands/52-create-project-folders.ps1
mkdir src/Modules/Projects/Domain
mkdir src/Modules/Projects/Application
mkdir src/Modules/Projects/Application/Abstractions
mkdir src/Modules/Projects/Application/CreateProject
mkdir src/Modules/Projects/Application/GetProjects
mkdir src/Modules/Projects/Application/GetProjectDetail
mkdir src/Modules/Projects/Application/UpdateProject
mkdir src/Modules/Projects/Application/DeleteProject
mkdir src/Modules/Projects/Infrastructure
mkdir src/Modules/Projects/Presentation
```

Penjelasan:

- `Domain` menyimpan entity dan status project.
- `Application` menyimpan use case CRUD project.
- `Abstractions` menyimpan repository, access checker, dan current user abstraction.
- `Infrastructure` menyimpan repository in-memory dan organization access checker.
- `Presentation` menyimpan endpoint HTTP project.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Directory structure created without errors.
```

## Domain Layer

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Domain/ProjectStatus.cs
namespace App.Modules.Projects.Domain;

public enum ProjectStatus
{
    Active = 1,
    Archived = 2
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Domain/Project.cs
namespace App.Modules.Projects.Domain;

public sealed class Project
{
    private Project(
        Guid id,
        Guid organizationId,
        Guid ownerUserId,
        string name,
        string? description)
    {
        Id = id;
        OrganizationId = organizationId;
        OwnerUserId = ownerUserId;
        Name = name;
        Description = description;
        Status = ProjectStatus.Active;
        CreatedAt = DateTimeOffset.UtcNow;
    }

    public Guid Id { get; private set; }
    public Guid OrganizationId { get; private set; }
    public Guid OwnerUserId { get; private set; }
    public string Name { get; private set; }
    public string? Description { get; private set; }
    public ProjectStatus Status { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset? UpdatedAt { get; private set; }

    public static Project Create(
        Guid organizationId,
        Guid ownerUserId,
        string name,
        string? description)
    {
        if (organizationId == Guid.Empty)
            throw new ArgumentException("OrganizationId wajib diisi.");

        if (ownerUserId == Guid.Empty)
            throw new ArgumentException("OwnerUserId wajib diisi.");

        if (string.IsNullOrWhiteSpace(name) || name.Trim().Length < 3)
            throw new ArgumentException("Nama project minimal 3 karakter.");

        return new Project(
            Guid.NewGuid(),
            organizationId,
            ownerUserId,
            name.Trim(),
            string.IsNullOrWhiteSpace(description) ? null : description.Trim());
    }

    public void Update(string name, string? description)
    {
        if (Status == ProjectStatus.Archived)
            throw new InvalidOperationException("Project archived tidak boleh diubah.");

        if (string.IsNullOrWhiteSpace(name) || name.Trim().Length < 3)
            throw new ArgumentException("Nama project minimal 3 karakter.");

        Name = name.Trim();
        Description = string.IsNullOrWhiteSpace(description) ? null : description.Trim();
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    public void Archive()
    {
        if (Status == ProjectStatus.Archived)
            return;

        Status = ProjectStatus.Archived;
        UpdatedAt = DateTimeOffset.UtcNow;
    }
}
```

## Application Abstractions

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/Abstractions/IProjectRepository.cs
using App.Modules.Projects.Domain;

namespace App.Modules.Projects.Application.Abstractions;

public interface IProjectRepository
{
    Task AddAsync(Project project, CancellationToken cancellationToken);
    Task<Project?> GetByIdAsync(Guid organizationId, Guid projectId, CancellationToken cancellationToken);
    Task<ProjectListResult> GetListAsync(ProjectListQuery query, CancellationToken cancellationToken);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}

public sealed record ProjectListQuery(
    Guid OrganizationId,
    int Page,
    int PageSize,
    string? Search,
    ProjectStatus? Status);

public sealed record ProjectListResult(
    IReadOnlyCollection<Project> Items,
    int Page,
    int PageSize,
    int Total);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/Abstractions/IOrganizationAccessChecker.cs
namespace App.Modules.Projects.Application.Abstractions;

public interface IOrganizationAccessChecker
{
    Task<OrganizationAccess?> GetAccessAsync(
        Guid organizationId,
        Guid userId,
        CancellationToken cancellationToken);
}

public sealed record OrganizationAccess(
    Guid OrganizationId,
    Guid UserId,
    string Role)
{
    public bool CanReadProjects => Role is "Owner" or "Admin" or "Member";
    public bool CanCreateProject => Role is "Owner" or "Admin" or "Member";
    public bool CanUpdateProject => Role is "Owner" or "Admin";
    public bool CanArchiveProject => Role is "Owner" or "Admin";
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/Abstractions/ICurrentUserService.cs
namespace App.Modules.Projects.Application.Abstractions;

public interface ICurrentUserService
{
    Guid UserId { get; }
    string Email { get; }
    bool IsAuthenticated { get; }
}
```

Catatan:

- `IOrganizationAccessChecker` sengaja berada di Application layer Projects.
- Implementasinya bisa membaca module Organizations atau adapter sementara.
- Handler Projects tidak boleh query tabel membership langsung.

## Create Project

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/CreateProject/CreateProjectRequest.cs
namespace App.Modules.Projects.Application.CreateProject;

public sealed record CreateProjectRequest(
    string Name,
    string? Description);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/CreateProject/CreateProjectResponse.cs
namespace App.Modules.Projects.Application.CreateProject;

public sealed record CreateProjectResponse(
    Guid Id,
    Guid OrganizationId,
    string Name,
    string? Description,
    string Status,
    Guid OwnerUserId,
    DateTimeOffset CreatedAt);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/CreateProject/CreateProjectHandler.cs
using App.Modules.Projects.Application.Abstractions;
using App.Modules.Projects.Domain;
using App.SharedKernel.Results;

namespace App.Modules.Projects.Application.CreateProject;

public sealed class CreateProjectHandler
{
    private readonly IProjectRepository _projects;
    private readonly IOrganizationAccessChecker _accessChecker;
    private readonly ICurrentUserService _currentUser;

    public CreateProjectHandler(
        IProjectRepository projects,
        IOrganizationAccessChecker accessChecker,
        ICurrentUserService currentUser)
    {
        _projects = projects;
        _accessChecker = accessChecker;
        _currentUser = currentUser;
    }

    public async Task<Result<CreateProjectResponse>> HandleAsync(
        Guid organizationId,
        CreateProjectRequest request,
        CancellationToken cancellationToken)
    {
        if (!_currentUser.IsAuthenticated)
            return Result<CreateProjectResponse>.Failure(new AppError("AUTH_REQUIRED", "User harus login."));

        if (string.IsNullOrWhiteSpace(request.Name) || request.Name.Trim().Length < 3)
            return Result<CreateProjectResponse>.Failure(new AppError("PROJECT_NAME_INVALID", "Nama project minimal 3 karakter."));

        var access = await _accessChecker.GetAccessAsync(organizationId, _currentUser.UserId, cancellationToken);

        if (access is null || !access.CanCreateProject)
            return Result<CreateProjectResponse>.Failure(new AppError("PROJECT_CREATE_FORBIDDEN", "User tidak punya akses membuat project."));

        var project = Project.Create(
            organizationId,
            _currentUser.UserId,
            request.Name,
            request.Description);

        await _projects.AddAsync(project, cancellationToken);

        return Result<CreateProjectResponse>.Success(new CreateProjectResponse(
            project.Id,
            project.OrganizationId,
            project.Name,
            project.Description,
            project.Status.ToString(),
            project.OwnerUserId,
            project.CreatedAt));
    }
}
```

## Get Projects Dengan Pagination, Search, Dan Filter

Query list project selalu menerima `organizationId` dari route. `Page` dan `PageSize` diberi default agar endpoint tetap aman untuk dipanggil tanpa query string.

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/GetProjects/GetProjectsQuery.cs
using App.Modules.Projects.Domain;

namespace App.Modules.Projects.Application.GetProjects;

public sealed record GetProjectsQuery(
    Guid OrganizationId,
    int Page = 1,
    int PageSize = 20,
    string? Search = null,
    ProjectStatus? Status = null);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/GetProjects/ProjectListItemResponse.cs
namespace App.Modules.Projects.Application.GetProjects;

public sealed record ProjectListItemResponse(
    Guid Id,
    Guid OrganizationId,
    string Name,
    string? Description,
    string Status,
    Guid OwnerUserId,
    DateTimeOffset CreatedAt,
    DateTimeOffset? UpdatedAt);

public sealed record ProjectListResponse(
    IReadOnlyCollection<ProjectListItemResponse> Items,
    int Page,
    int PageSize,
    int Total);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/GetProjects/GetProjectsHandler.cs
using App.Modules.Projects.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Projects.Application.GetProjects;

public sealed class GetProjectsHandler
{
    private readonly IProjectRepository _projects;
    private readonly IOrganizationAccessChecker _accessChecker;
    private readonly ICurrentUserService _currentUser;

    public GetProjectsHandler(
        IProjectRepository projects,
        IOrganizationAccessChecker accessChecker,
        ICurrentUserService currentUser)
    {
        _projects = projects;
        _accessChecker = accessChecker;
        _currentUser = currentUser;
    }

    public async Task<Result<ProjectListResponse>> HandleAsync(
        GetProjectsQuery query,
        CancellationToken cancellationToken)
    {
        var page = query.Page < 1 ? 1 : query.Page;
        var pageSize = query.PageSize is < 1 or > 100 ? 20 : query.PageSize;

        var access = await _accessChecker.GetAccessAsync(query.OrganizationId, _currentUser.UserId, cancellationToken);

        if (access is null || !access.CanReadProjects)
            return Result<ProjectListResponse>.Failure(new AppError("PROJECT_READ_FORBIDDEN", "User tidak punya akses membaca project."));

        var result = await _projects.GetListAsync(new ProjectListQuery(
            query.OrganizationId,
            page,
            pageSize,
            query.Search,
            query.Status), cancellationToken);

        var items = result.Items
            .Select(project => new ProjectListItemResponse(
                project.Id,
                project.OrganizationId,
                project.Name,
                project.Description,
                project.Status.ToString(),
                project.OwnerUserId,
                project.CreatedAt,
                project.UpdatedAt))
            .ToArray();

        return Result<ProjectListResponse>.Success(new ProjectListResponse(
            items,
            result.Page,
            result.PageSize,
            result.Total));
    }
}
```

## Get Project Detail

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/GetProjectDetail/ProjectDetailResponse.cs
namespace App.Modules.Projects.Application.GetProjectDetail;

public sealed record ProjectDetailResponse(
    Guid Id,
    Guid OrganizationId,
    string Name,
    string? Description,
    string Status,
    Guid OwnerUserId,
    DateTimeOffset CreatedAt,
    DateTimeOffset? UpdatedAt);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/GetProjectDetail/GetProjectDetailHandler.cs
using App.Modules.Projects.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Projects.Application.GetProjectDetail;

public sealed class GetProjectDetailHandler
{
    private readonly IProjectRepository _projects;
    private readonly IOrganizationAccessChecker _accessChecker;
    private readonly ICurrentUserService _currentUser;

    public GetProjectDetailHandler(
        IProjectRepository projects,
        IOrganizationAccessChecker accessChecker,
        ICurrentUserService currentUser)
    {
        _projects = projects;
        _accessChecker = accessChecker;
        _currentUser = currentUser;
    }

    public async Task<Result<ProjectDetailResponse>> HandleAsync(
        Guid organizationId,
        Guid projectId,
        CancellationToken cancellationToken)
    {
        var access = await _accessChecker.GetAccessAsync(organizationId, _currentUser.UserId, cancellationToken);

        if (access is null || !access.CanReadProjects)
            return Result<ProjectDetailResponse>.Failure(new AppError("PROJECT_READ_FORBIDDEN", "User tidak punya akses membaca project."));

        var project = await _projects.GetByIdAsync(organizationId, projectId, cancellationToken);

        if (project is null)
            return Result<ProjectDetailResponse>.Failure(new AppError("PROJECT_NOT_FOUND", "Project tidak ditemukan."));

        return Result<ProjectDetailResponse>.Success(new ProjectDetailResponse(
            project.Id,
            project.OrganizationId,
            project.Name,
            project.Description,
            project.Status.ToString(),
            project.OwnerUserId,
            project.CreatedAt,
            project.UpdatedAt));
    }
}
```

## Update Project

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/UpdateProject/UpdateProjectRequest.cs
namespace App.Modules.Projects.Application.UpdateProject;

public sealed record UpdateProjectRequest(
    string Name,
    string? Description);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/UpdateProject/UpdateProjectHandler.cs
using App.Modules.Projects.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Projects.Application.UpdateProject;

public sealed class UpdateProjectHandler
{
    private readonly IProjectRepository _projects;
    private readonly IOrganizationAccessChecker _accessChecker;
    private readonly ICurrentUserService _currentUser;

    public UpdateProjectHandler(
        IProjectRepository projects,
        IOrganizationAccessChecker accessChecker,
        ICurrentUserService currentUser)
    {
        _projects = projects;
        _accessChecker = accessChecker;
        _currentUser = currentUser;
    }

    public async Task<Result<string>> HandleAsync(
        Guid organizationId,
        Guid projectId,
        UpdateProjectRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Name) || request.Name.Trim().Length < 3)
            return Result<string>.Failure(new AppError("PROJECT_NAME_INVALID", "Nama project minimal 3 karakter."));

        var access = await _accessChecker.GetAccessAsync(organizationId, _currentUser.UserId, cancellationToken);

        if (access is null || !access.CanUpdateProject)
            return Result<string>.Failure(new AppError("PROJECT_UPDATE_FORBIDDEN", "User tidak punya akses mengubah project."));

        var project = await _projects.GetByIdAsync(organizationId, projectId, cancellationToken);

        if (project is null)
            return Result<string>.Failure(new AppError("PROJECT_NOT_FOUND", "Project tidak ditemukan."));

        try
        {
            project.Update(request.Name, request.Description);
            await _projects.SaveChangesAsync(cancellationToken);
            return Result<string>.Success("Project berhasil diubah.");
        }
        catch (InvalidOperationException exception)
        {
            return Result<string>.Failure(new AppError("PROJECT_UPDATE_FAILED", exception.Message));
        }
    }
}
```

## Delete/Archive Project

Delete di file ini berarti archive. Data tidak dihapus dari repository agar aman untuk audit dan restore.

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Application/DeleteProject/DeleteProjectHandler.cs
using App.Modules.Projects.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Projects.Application.DeleteProject;

public sealed class DeleteProjectHandler
{
    private readonly IProjectRepository _projects;
    private readonly IOrganizationAccessChecker _accessChecker;
    private readonly ICurrentUserService _currentUser;

    public DeleteProjectHandler(
        IProjectRepository projects,
        IOrganizationAccessChecker accessChecker,
        ICurrentUserService currentUser)
    {
        _projects = projects;
        _accessChecker = accessChecker;
        _currentUser = currentUser;
    }

    public async Task<Result<string>> HandleAsync(
        Guid organizationId,
        Guid projectId,
        CancellationToken cancellationToken)
    {
        var access = await _accessChecker.GetAccessAsync(organizationId, _currentUser.UserId, cancellationToken);

        if (access is null || !access.CanArchiveProject)
            return Result<string>.Failure(new AppError("PROJECT_ARCHIVE_FORBIDDEN", "User tidak punya akses archive project."));

        var project = await _projects.GetByIdAsync(organizationId, projectId, cancellationToken);

        if (project is null)
            return Result<string>.Failure(new AppError("PROJECT_NOT_FOUND", "Project tidak ditemukan."));

        project.Archive();
        await _projects.SaveChangesAsync(cancellationToken);

        return Result<string>.Success("Project berhasil di-archive.");
    }
}
```

## Infrastructure Layer

### In-memory Project Repository

Repository ini menyimpan project di memory aplikasi. Semua query selalu memakai `OrganizationId` untuk menjaga tenant isolation.

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Infrastructure/InMemoryProjectRepository.cs
using App.Modules.Projects.Application.Abstractions;
using App.Modules.Projects.Domain;

namespace App.Modules.Projects.Infrastructure;

public sealed class InMemoryProjectRepository : IProjectRepository
{
    private static readonly List<Project> Projects = new();

    public Task AddAsync(Project project, CancellationToken cancellationToken)
    {
        Projects.Add(project);
        return Task.CompletedTask;
    }

    public Task<Project?> GetByIdAsync(Guid organizationId, Guid projectId, CancellationToken cancellationToken)
    {
        var project = Projects.FirstOrDefault(item =>
            item.OrganizationId == organizationId &&
            item.Id == projectId);

        return Task.FromResult(project);
    }

    public Task<ProjectListResult> GetListAsync(ProjectListQuery query, CancellationToken cancellationToken)
    {
        var filtered = Projects
            .Where(project => project.OrganizationId == query.OrganizationId);

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            filtered = filtered.Where(project =>
                project.Name.Contains(search, StringComparison.OrdinalIgnoreCase));
        }

        if (query.Status is not null)
        {
            filtered = filtered.Where(project => project.Status == query.Status.Value);
        }

        var total = filtered.Count();
        var items = filtered
            .OrderByDescending(project => project.CreatedAt)
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToArray();

        var result = new ProjectListResult(items, query.Page, query.PageSize, total);
        return Task.FromResult(result);
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }
}
```

### Organization Access Checker

Untuk tutorial ini, checker dibuat sederhana. Di aplikasi nyata, implementasi ini membaca membership dari module Organizations.

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Infrastructure/OrganizationAccessChecker.cs
using App.Modules.Projects.Application.Abstractions;

namespace App.Modules.Projects.Infrastructure;

public sealed class OrganizationAccessChecker : IOrganizationAccessChecker
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
            "Owner");

        return Task.FromResult<OrganizationAccess?>(access);
    }
}
```

Catatan:

- `OrganizationAccessChecker` sementara selalu menganggap user sebagai `Owner` jika `organizationId` dan `userId` valid.
- Di implementasi lanjut, checker harus membaca repository Organizations atau public contract membership.
- Handler Projects tidak berubah saat implementasi checker diganti.

### Current User Service

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Infrastructure/CurrentUserService.cs
using System.Security.Claims;
using App.Modules.Projects.Application.Abstractions;
using Microsoft.AspNetCore.Http;

namespace App.Modules.Projects.Infrastructure;

public sealed class CurrentUserService : ICurrentUserService
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CurrentUserService(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public bool IsAuthenticated =>
        _httpContextAccessor.HttpContext?.User.Identity?.IsAuthenticated == true;

    public Guid UserId
    {
        get
        {
            var value = _httpContextAccessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier);
            return Guid.TryParse(value, out var userId) ? userId : Guid.Empty;
        }
    }

    public string Email =>
        _httpContextAccessor.HttpContext?.User.FindFirstValue(ClaimTypes.Email) ?? string.Empty;
}
```

## Projects Module DI

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/ProjectsModule.cs
using App.Modules.Projects.Application.Abstractions;
using App.Modules.Projects.Application.CreateProject;
using App.Modules.Projects.Application.DeleteProject;
using App.Modules.Projects.Application.GetProjectDetail;
using App.Modules.Projects.Application.GetProjects;
using App.Modules.Projects.Application.UpdateProject;
using App.Modules.Projects.Infrastructure;
using App.Modules.Projects.Presentation;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

namespace App.Modules.Projects;

public static class ProjectsModule
{
    public static IServiceCollection AddProjectsModule(this IServiceCollection services)
    {
        services.AddHttpContextAccessor();
        services.AddSingleton<IProjectRepository, InMemoryProjectRepository>();
        services.AddScoped<IOrganizationAccessChecker, OrganizationAccessChecker>();
        services.AddScoped<ICurrentUserService, CurrentUserService>();

        services.AddScoped<CreateProjectHandler>();
        services.AddScoped<GetProjectsHandler>();
        services.AddScoped<GetProjectDetailHandler>();
        services.AddScoped<UpdateProjectHandler>();
        services.AddScoped<DeleteProjectHandler>();

        return services;
    }

    public static IEndpointRouteBuilder MapProjectsModule(this IEndpointRouteBuilder app)
    {
        app.MapProjectEndpoints();
        return app;
    }
}
```

## Presentation Layer

Endpoint Projects selalu berada di bawah route organization.

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Presentation/ProjectEndpoints.cs
using App.Modules.Projects.Application.CreateProject;
using App.Modules.Projects.Application.DeleteProject;
using App.Modules.Projects.Application.GetProjectDetail;
using App.Modules.Projects.Application.GetProjects;
using App.Modules.Projects.Application.UpdateProject;
using App.Modules.Projects.Domain;
using App.SharedKernel.Responses;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace App.Modules.Projects.Presentation;

public static class ProjectEndpoints
{
    public static IEndpointRouteBuilder MapProjectEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/organizations/{organizationId:guid}/projects")
            .WithTags("Projects")
            .RequireAuthorization();

        group.MapPost("/", CreateAsync);
        group.MapGet("/", GetListAsync);
        group.MapGet("/{projectId:guid}", GetDetailAsync);
        group.MapPut("/{projectId:guid}", UpdateAsync);
        group.MapDelete("/{projectId:guid}", ArchiveAsync);

        return app;
    }

    private static async Task<IResult> CreateAsync(
        Guid organizationId,
        CreateProjectRequest request,
        CreateProjectHandler handler,
        CancellationToken cancellationToken)
    {
        var result = await handler.HandleAsync(organizationId, request, cancellationToken);
        return ToHttpResult(result, StatusCodes.Status201Created);
    }

    private static async Task<IResult> GetListAsync(
        Guid organizationId,
        int page,
        int pageSize,
        string? search,
        ProjectStatus? status,
        GetProjectsHandler handler,
        CancellationToken cancellationToken)
    {
        var result = await handler.HandleAsync(new GetProjectsQuery(
            organizationId,
            page == 0 ? 1 : page,
            pageSize == 0 ? 20 : pageSize,
            search,
            status), cancellationToken);

        return ToHttpResult(result);
    }

    private static async Task<IResult> GetDetailAsync(
        Guid organizationId,
        Guid projectId,
        GetProjectDetailHandler handler,
        CancellationToken cancellationToken)
    {
        var result = await handler.HandleAsync(organizationId, projectId, cancellationToken);
        return ToHttpResult(result);
    }

    private static async Task<IResult> UpdateAsync(
        Guid organizationId,
        Guid projectId,
        UpdateProjectRequest request,
        UpdateProjectHandler handler,
        CancellationToken cancellationToken)
    {
        var result = await handler.HandleAsync(organizationId, projectId, request, cancellationToken);
        return ToHttpResult(result);
    }

    private static async Task<IResult> ArchiveAsync(
        Guid organizationId,
        Guid projectId,
        DeleteProjectHandler handler,
        CancellationToken cancellationToken)
    {
        var result = await handler.HandleAsync(organizationId, projectId, cancellationToken);
        return ToHttpResult(result);
    }

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

Tambahkan module Projects ke API host setelah Identity dan Organizations.

```csharp
// File: ProjectManagement.Backend/src/ProjectManagement.Api/Program.cs
using App.Modules.Identity;
using App.Modules.Organizations;
using App.Modules.Projects;
using App.SharedKernel.Responses;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddIdentityModule(builder.Configuration);
builder.Services.AddOrganizationsModule();
builder.Services.AddProjectsModule();

builder.Services.AddAuthentication();
builder.Services.AddAuthorization();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", () => Results.Ok(ApiResponse<object>.Ok(new
{
    service = "ProjectManagement.Api",
    status = "Healthy",
    checkedAt = DateTimeOffset.UtcNow
})));

app.MapIdentityModule();
app.MapOrganizationsModule();
app.MapProjectsModule();

app.Run();
```

Catatan:

- Konfigurasi JWT lengkap tetap mengikuti file `03-identity-auth.md`.
- `MapProjectsModule()` boleh dipanggil setelah middleware authentication/authorization.
- Semua endpoint Projects memakai `.RequireAuthorization()`.

## Test Manual Dengan Curl

Sebelum test Projects:

1. Register dan login user dari file `03`.
2. Simpan `<access-token>`.
3. Create organization dari file `04`.
4. Simpan `<organization-id>`.

### Create Project

```powershell
# File: ProjectManagement.Backend/commands/53-test-create-project.ps1
curl -X POST http://localhost:5000/api/organizations/<organization-id>/projects `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer <access-token>" `
  -d '{"name":"Website Redesign","description":"Redesign company profile website"}'
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-create-project-response.json
{
  "success": true,
  "data": {
    "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    "organizationId": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
    "name": "Website Redesign",
    "description": "Redesign company profile website",
    "status": "Active",
    "ownerUserId": "cccccccc-cccc-cccc-cccc-cccccccccccc",
    "createdAt": "2026-07-07T10:00:00.0000000+00:00"
  },
  "error": null,
  "meta": null
}
```

### Get Project List

```powershell
# File: ProjectManagement.Backend/commands/54-test-project-list.ps1
curl "http://localhost:5000/api/organizations/<organization-id>/projects?page=1&pageSize=10" `
  -H "Authorization: Bearer <access-token>"
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-project-list-response.json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "organizationId": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
        "name": "Website Redesign",
        "description": "Redesign company profile website",
        "status": "Active",
        "ownerUserId": "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "createdAt": "2026-07-07T10:00:00.0000000+00:00",
        "updatedAt": null
      }
    ],
    "page": 1,
    "pageSize": 10,
    "total": 1
  },
  "error": null,
  "meta": null
}
```

### Search Project By Name

```powershell
# File: ProjectManagement.Backend/commands/55-test-project-search.ps1
curl "http://localhost:5000/api/organizations/<organization-id>/projects?page=1&pageSize=10&search=website" `
  -H "Authorization: Bearer <access-token>"
```

Search dilakukan di repository berdasarkan `Name.Contains(search, StringComparison.OrdinalIgnoreCase)`.

### Filter Project By Status

```powershell
# File: ProjectManagement.Backend/commands/56-test-project-filter-status.ps1
curl "http://localhost:5000/api/organizations/<organization-id>/projects?page=1&pageSize=10&status=Active" `
  -H "Authorization: Bearer <access-token>"
```

### Get Project Detail

```powershell
# File: ProjectManagement.Backend/commands/57-test-project-detail.ps1
curl http://localhost:5000/api/organizations/<organization-id>/projects/<project-id> `
  -H "Authorization: Bearer <access-token>"
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-project-detail-response.json
{
  "success": true,
  "data": {
    "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    "organizationId": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
    "name": "Website Redesign",
    "description": "Redesign company profile website",
    "status": "Active",
    "ownerUserId": "cccccccc-cccc-cccc-cccc-cccccccccccc",
    "createdAt": "2026-07-07T10:00:00.0000000+00:00",
    "updatedAt": null
  },
  "error": null,
  "meta": null
}
```

### Update Project

```powershell
# File: ProjectManagement.Backend/commands/58-test-update-project.ps1
curl -X PUT http://localhost:5000/api/organizations/<organization-id>/projects/<project-id> `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer <access-token>" `
  -d '{"name":"Website Redesign Phase 2","description":"Update homepage and dashboard pages"}'
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-update-project-response.json
{
  "success": true,
  "data": "Project berhasil diubah.",
  "error": null,
  "meta": null
}
```

### Archive Project

```powershell
# File: ProjectManagement.Backend/commands/59-test-archive-project.ps1
curl -X DELETE http://localhost:5000/api/organizations/<organization-id>/projects/<project-id> `
  -H "Authorization: Bearer <access-token>"
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-archive-project-response.json
{
  "success": true,
  "data": "Project berhasil di-archive.",
  "error": null,
  "meta": null
}
```

Setelah archive, list dengan filter `status=Archived` akan menampilkan project tersebut.

## Error Response Sederhana

Project name invalid:

```json
// File: ProjectManagement.Backend/commands/expected-project-invalid-name-response.json
{
  "success": false,
  "data": null,
  "error": {
    "code": "PROJECT_NAME_INVALID",
    "message": "Nama project minimal 3 karakter.",
    "details": null
  },
  "meta": null
}
```

Project tidak ditemukan:

```json
// File: ProjectManagement.Backend/commands/expected-project-not-found-response.json
{
  "success": false,
  "data": null,
  "error": {
    "code": "PROJECT_NOT_FOUND",
    "message": "Project tidak ditemukan.",
    "details": null
  },
  "meta": null
}
```

User tidak punya akses:

```json
// File: ProjectManagement.Backend/commands/expected-project-forbidden-response.json
{
  "success": false,
  "data": null,
  "error": {
    "code": "PROJECT_READ_FORBIDDEN",
    "message": "User tidak punya akses membaca project.",
    "details": null
  },
  "meta": null
}
```

## Tenant Isolation Checklist

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/05-project-module.md
[ ] Route project selalu punya organizationId.
[ ] Entity Project selalu punya OrganizationId.
[ ] Repository GetByIdAsync menerima organizationId dan projectId.
[ ] Repository list filter berdasarkan OrganizationId.
[ ] Handler mengecek membership organization sebelum query project.
[ ] Update dan archive memakai organizationId + projectId.
[ ] Endpoint /api/projects global tidak dibuat.
```

## Build Dan Verifikasi

```powershell
# File: ProjectManagement.Backend/commands/60-build-projects.ps1
dotnet build
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

Cek reference jika namespace module tidak terbaca.

```powershell
# File: ProjectManagement.Backend/commands/61-check-projects-reference.ps1
dotnet sln list
dotnet list src/ProjectManagement.Api/ProjectManagement.Api.csproj reference
```

## Troubleshooting

### Endpoint Projects Selalu 401

Penyebab:

- token tidak dikirim;
- token salah format;
- middleware authentication belum aktif;
- endpoint memakai `.RequireAuthorization()`.

Solusi:

```powershell
# File: ProjectManagement.Backend/commands/troubleshoot-project-auth-header.ps1
curl http://localhost:5000/api/organizations/<organization-id>/projects `
  -H "Authorization: Bearer <access-token>"
```

### Project Tidak Muncul Di List

Penyebab umum:

- `organizationId` route berbeda dari `Project.OrganizationId`;
- project sudah archived tetapi filter `status=Active`;
- repository masih in-memory dan aplikasi restart;
- search tidak cocok dengan nama project.

Solusi cek URL:

```text
# File: ProjectManagement.Backend/commands/troubleshoot-project-list-url.txt
/api/organizations/<organization-id-yang-benar>/projects?page=1&pageSize=10
```

### User Dari Organization Lain Bisa Akses Project

Ini bug tenant isolation. Penyebabnya biasanya:

- query detail hanya memakai `projectId`;
- handler tidak memanggil `IOrganizationAccessChecker`;
- repository tidak memfilter `OrganizationId`.

Pola wajib:

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Infrastructure/InMemoryProjectRepository.cs
var project = Projects.FirstOrDefault(item =>
    item.OrganizationId == organizationId &&
    item.Id == projectId);
```

### Project Hilang Setelah Restart

Penyebab:

- repository masih in-memory.

Solusi sementara:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/05-project-module.md
Buat ulang project setelah restart.
Persistence database akan dibuat di 08-database-migration-seed.md.
```

## Checklist Selesai

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/05-project-module.md
[ ] Project domain punya OrganizationId.
[ ] Project domain punya status Active/Archived.
[ ] Create project mengecek membership organization.
[ ] List project filter OrganizationId, pagination, search, dan status.
[ ] Detail project memakai organizationId + projectId.
[ ] Update project mengecek Owner/Admin.
[ ] Delete project memakai archive.
[ ] Repository tidak punya query project global lintas tenant.
[ ] Endpoint Projects protected dengan RequireAuthorization().
[ ] Response sukses dan error memakai ApiResponse envelope.
```

## Ringkasan

Alur create project:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/05-project-module.md
POST /api/organizations/{organizationId}/projects
  -> ProjectEndpoints
  -> CreateProjectHandler
  -> CurrentUserService membaca claim JWT
  -> OrganizationAccessChecker cek membership organization
  -> Project.Create(organizationId, currentUserId, ...)
  -> IProjectRepository.AddAsync
  -> ApiResponse<CreateProjectResponse>
```

Alur list project:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/05-project-module.md
GET /api/organizations/{organizationId}/projects?page=1&pageSize=20&search=web&status=Active
  -> ProjectEndpoints
  -> GetProjectsHandler
  -> cek membership organization
  -> repository filter OrganizationId + search + status
  -> pagination
  -> ApiResponse<ProjectListResponse>
```

Dengan module Projects ini, backend sudah punya fitur bisnis tenant-aware pertama. Module `Tasks` berikutnya wajib mengikuti pola yang sama: selalu bawa `OrganizationId`, cek membership, dan jangan akses data lintas tenant.
