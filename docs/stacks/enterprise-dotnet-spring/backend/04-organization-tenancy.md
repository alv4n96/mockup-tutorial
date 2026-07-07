# Backend 04 - Organization & Tenancy

File ini melanjutkan [01-solution-setup.md](01-solution-setup.md), [02-modular-monolith-layers.md](02-modular-monolith-layers.md), dan [03-identity-auth.md](03-identity-auth.md). File sebelumnya sudah menyiapkan solution, modular monolith, layered architecture, module `Projects`, dan module `Identity` untuk register, login, JWT, password hashing, serta `/auth/me`.

File ini membuat module `Organizations` untuk Project Management App. Fokusnya adalah organization/tenant, membership, role di dalam organization, current organization context sederhana, dan authorization berdasarkan membership.

Database di file ini masih memakai in-memory repository agar pembaca fokus ke model tenancy. EF Core migration dan seed database dibahas di `08-database-migration-seed.md`.

## Hubungan Organizations Dengan Identity

Module `Identity` menjawab pertanyaan: user ini siapa?

Module `Organizations` menjawab pertanyaan: user ini anggota organization mana, dan perannya apa di organization itu?

Contoh:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/04-organization-tenancy.md
Identity
  User: Budi, budi@example.com, global role Member

Organizations
  Organization: Acme Studio
  Membership: Budi adalah Owner di Acme Studio
```

Role global dari Identity tidak cukup untuk aplikasi enterprise multi-tenant. User yang sama bisa menjadi `Owner` di organization miliknya, tetapi hanya `Member` di organization lain.

## Kenapa Aplikasi Enterprise Butuh Organization/Tenant

Aplikasi enterprise biasanya dipakai oleh banyak perusahaan, tim, atau unit kerja. Setiap perusahaan ingin datanya terpisah dari perusahaan lain.

Tanpa organization/tenant:

- semua project bisa tercampur;
- user bisa melihat data tim lain;
- role dan permission sulit dibatasi per organisasi;
- audit log sulit dibaca;
- billing dan subscription sulit dipisah.

Dengan organization/tenant:

- project dan task selalu punya `OrganizationId`;
- membership user jelas;
- role bisa berbeda per organization;
- query data bisa difilter berdasarkan tenant;
- fitur billing, audit, dan permission lebih mudah dikembangkan.

## Konsep Dasar

### Organization

Organization adalah grup kerja atau perusahaan di dalam aplikasi. Contoh: `Acme Studio`, `PT Sinar Digital`, atau `Team Internal IT`.

### Tenant

Tenant adalah boundary data. Dalam tutorial ini, satu organization dianggap satu tenant. Jadi `OrganizationId` dipakai sebagai tenant id.

### Multi-tenancy

Multi-tenancy berarti satu aplikasi melayani banyak tenant. Semua tenant memakai backend yang sama, tetapi datanya harus tetap terpisah.

### Tenant Isolation

Tenant isolation adalah aturan agar data tenant A tidak bocor ke tenant B. Contoh: query list project harus selalu memfilter berdasarkan `OrganizationId`.

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/04-organization-tenancy.md
Benar:
GET /api/organizations/{organizationId}/projects
  -> query project WHERE OrganizationId = organizationId

Salah:
GET /api/projects
  -> mengembalikan semua project dari semua organization
```

### Organization Member

Organization member adalah relasi antara user dan organization. User tidak otomatis bisa mengakses semua organization. User harus punya membership.

### Organization Role

Role di organization:

- `Owner`: pemilik organization, bisa mengelola member dan role.
- `Admin`: bisa mengelola data organization, project, dan task, tetapi tidak sekuat owner.
- `Member`: anggota biasa, bisa mengakses fitur kerja sesuai permission dasar.

### Global Role Identity vs Organization Role

Global role dari Identity berlaku untuk aplikasi secara umum. Organization role berlaku hanya di satu organization.

Contoh:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/04-organization-tenancy.md
User Budi
  Global role: Member
  Role di Acme Studio: Owner
  Role di Beta Team: Member
```

Karena itu, authorization project/task nanti tidak cukup membaca global role. Backend harus membaca membership berdasarkan `OrganizationId`.

### Kenapa Project Dan Task Harus Terikat Ke OrganizationId

Project dan task adalah data tenant. Jika project/task tidak punya `OrganizationId`, backend sulit memastikan data tersebut milik tenant mana.

Aturan praktis:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/04-organization-tenancy.md
Project.OrganizationId wajib ada.
Task.OrganizationId wajib ada.
Semua query list/detail/update/delete harus mengecek OrganizationId.
```

## Scope Fitur Di File Ini

Fitur yang dibuat:

- create organization;
- get current user's organizations;
- get organization detail;
- add member by email/user id sederhana;
- change member role sederhana;
- remove member sederhana;
- current organization context sederhana;
- authorization sederhana berdasarkan membership;
- `ApiResponse` envelope;
- validation request sederhana;
- error response sederhana;
- in-memory repository.

Yang belum dibuat di file ini:

- EF Core table dan migration;
- seed organization/member;
- invitation email;
- billing/subscription tenant;
- permission matrix detail;
- audit log membership;
- frontend organization switcher.

## Struktur Folder Module Organizations

```txt
# File: docs/stacks/enterprise-dotnet-spring/backend/04-organization-tenancy.md
src/
└── Modules/
    └── Organizations/
        ├── Domain/
        │   ├── Organization.cs
        │   ├── OrganizationMember.cs
        │   └── OrganizationRole.cs
        │
        ├── Application/
        │   ├── Abstractions/
        │   │   ├── IOrganizationRepository.cs
        │   │   └── ICurrentUserService.cs
        │   │
        │   ├── CreateOrganization/
        │   │   ├── CreateOrganizationRequest.cs
        │   │   ├── CreateOrganizationResponse.cs
        │   │   └── CreateOrganizationHandler.cs
        │   │
        │   ├── GetMyOrganizations/
        │   │   ├── MyOrganizationResponse.cs
        │   │   └── GetMyOrganizationsHandler.cs
        │   │
        │   ├── GetOrganizationDetail/
        │   │   ├── OrganizationDetailResponse.cs
        │   │   └── GetOrganizationDetailHandler.cs
        │   │
        │   ├── AddMember/
        │   │   ├── AddOrganizationMemberRequest.cs
        │   │   └── AddOrganizationMemberHandler.cs
        │   │
        │   ├── ChangeMemberRole/
        │   │   ├── ChangeMemberRoleRequest.cs
        │   │   └── ChangeMemberRoleHandler.cs
        │   │
        │   └── RemoveMember/
        │       └── RemoveOrganizationMemberHandler.cs
        │
        ├── Infrastructure/
        │   ├── InMemoryOrganizationRepository.cs
        │   └── CurrentUserService.cs
        │
        ├── Presentation/
        │   └── OrganizationEndpoints.cs
        │
        └── OrganizationsModule.cs
```

## Command Membuat Folder

Jalankan dari root backend.

```powershell
# File: ProjectManagement.Backend/commands/43-create-organization-folders.ps1
mkdir src/Modules/Organizations/Domain
mkdir src/Modules/Organizations/Application
mkdir src/Modules/Organizations/Application/Abstractions
mkdir src/Modules/Organizations/Application/CreateOrganization
mkdir src/Modules/Organizations/Application/GetMyOrganizations
mkdir src/Modules/Organizations/Application/GetOrganizationDetail
mkdir src/Modules/Organizations/Application/AddMember
mkdir src/Modules/Organizations/Application/ChangeMemberRole
mkdir src/Modules/Organizations/Application/RemoveMember
mkdir src/Modules/Organizations/Infrastructure
mkdir src/Modules/Organizations/Presentation
```

Penjelasan:

- `Domain` berisi entity organization, member, dan role.
- `Application` berisi use case organization.
- `Application/Abstractions` berisi repository dan current user abstraction.
- `Infrastructure` berisi in-memory repository dan pembaca current user dari claim.
- `Presentation` berisi endpoint HTTP.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Directory structure created without errors.
```

## Domain Layer

Domain layer menyimpan aturan membership dan role. Domain tidak tahu HTTP, JWT, atau database.

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Domain/OrganizationRole.cs
namespace App.Modules.Organizations.Domain;

public enum OrganizationRole
{
    Owner = 1,
    Admin = 2,
    Member = 3
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Domain/OrganizationMember.cs
namespace App.Modules.Organizations.Domain;

public sealed class OrganizationMember
{
    public OrganizationMember(
        Guid organizationId,
        Guid userId,
        string email,
        OrganizationRole role)
    {
        if (organizationId == Guid.Empty)
            throw new ArgumentException("OrganizationId wajib diisi.");

        if (userId == Guid.Empty)
            throw new ArgumentException("UserId wajib diisi.");

        if (string.IsNullOrWhiteSpace(email) || !email.Contains('@'))
            throw new ArgumentException("Email member tidak valid.");

        OrganizationId = organizationId;
        UserId = userId;
        Email = email.Trim().ToLowerInvariant();
        Role = role;
        JoinedAt = DateTimeOffset.UtcNow;
    }

    public Guid OrganizationId { get; }
    public Guid UserId { get; }
    public string Email { get; }
    public OrganizationRole Role { get; private set; }
    public DateTimeOffset JoinedAt { get; }

    public void ChangeRole(OrganizationRole role)
    {
        Role = role;
    }
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Domain/Organization.cs
namespace App.Modules.Organizations.Domain;

public sealed class Organization
{
    private readonly List<OrganizationMember> _members = new();

    private Organization(Guid id, string name, Guid ownerUserId, string ownerEmail)
    {
        Id = id;
        Name = name;
        CreatedAt = DateTimeOffset.UtcNow;
        _members.Add(new OrganizationMember(id, ownerUserId, ownerEmail, OrganizationRole.Owner));
    }

    public Guid Id { get; private set; }
    public string Name { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public IReadOnlyCollection<OrganizationMember> Members => _members.AsReadOnly();

    public static Organization Create(string name, Guid ownerUserId, string ownerEmail)
    {
        if (string.IsNullOrWhiteSpace(name) || name.Trim().Length < 2)
            throw new ArgumentException("Nama organization minimal 2 karakter.");

        if (ownerUserId == Guid.Empty)
            throw new ArgumentException("OwnerUserId wajib diisi.");

        if (string.IsNullOrWhiteSpace(ownerEmail) || !ownerEmail.Contains('@'))
            throw new ArgumentException("Owner email tidak valid.");

        return new Organization(Guid.NewGuid(), name.Trim(), ownerUserId, ownerEmail);
    }

    public OrganizationMember? GetMember(Guid userId)
    {
        return _members.FirstOrDefault(member => member.UserId == userId);
    }

    public bool IsMember(Guid userId)
    {
        return GetMember(userId) is not null;
    }

    public void AddMember(Guid actorUserId, Guid userId, string email, OrganizationRole role)
    {
        EnsureCanManageMembers(actorUserId);

        if (role == OrganizationRole.Owner)
            throw new InvalidOperationException("Owner baru tidak boleh ditambahkan lewat AddMember sederhana.");

        if (_members.Any(member => member.UserId == userId))
            throw new InvalidOperationException("User sudah menjadi member organization.");

        _members.Add(new OrganizationMember(Id, userId, email, role));
    }

    public void ChangeMemberRole(Guid actorUserId, Guid targetUserId, OrganizationRole role)
    {
        EnsureCanManageMembers(actorUserId);

        var target = GetMember(targetUserId)
            ?? throw new InvalidOperationException("Member tidak ditemukan.");

        if (target.Role == OrganizationRole.Owner)
            throw new InvalidOperationException("Role owner tidak boleh diubah lewat flow sederhana ini.");

        if (role == OrganizationRole.Owner)
            throw new InvalidOperationException("Promote owner tidak dibahas di file ini.");

        target.ChangeRole(role);
    }

    public void RemoveMember(Guid actorUserId, Guid targetUserId)
    {
        EnsureCanManageMembers(actorUserId);

        var target = GetMember(targetUserId)
            ?? throw new InvalidOperationException("Member tidak ditemukan.");

        if (target.Role == OrganizationRole.Owner)
            throw new InvalidOperationException("Owner tidak boleh dihapus lewat flow sederhana ini.");

        _members.Remove(target);
    }

    private void EnsureCanManageMembers(Guid actorUserId)
    {
        var actor = GetMember(actorUserId)
            ?? throw new InvalidOperationException("User bukan member organization.");

        if (actor.Role is not OrganizationRole.Owner and not OrganizationRole.Admin)
            throw new InvalidOperationException("User tidak punya akses mengelola member.");
    }
}
```

## Application Abstractions

Application layer memakai repository dan current user abstraction. Endpoint tidak perlu mengirim `currentUserId` dari body karena user id diambil dari JWT claim.

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Application/Abstractions/IOrganizationRepository.cs
using App.Modules.Organizations.Domain;

namespace App.Modules.Organizations.Application.Abstractions;

public interface IOrganizationRepository
{
    Task AddAsync(Organization organization, CancellationToken cancellationToken);
    Task<Organization?> GetByIdAsync(Guid organizationId, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<Organization>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Application/Abstractions/ICurrentUserService.cs
namespace App.Modules.Organizations.Application.Abstractions;

public interface ICurrentUserService
{
    Guid UserId { get; }
    string Email { get; }
    bool IsAuthenticated { get; }
}
```

## Create Organization

User yang membuat organization otomatis menjadi `Owner`.

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Application/CreateOrganization/CreateOrganizationRequest.cs
namespace App.Modules.Organizations.Application.CreateOrganization;

public sealed record CreateOrganizationRequest(string Name);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Application/CreateOrganization/CreateOrganizationResponse.cs
namespace App.Modules.Organizations.Application.CreateOrganization;

public sealed record CreateOrganizationResponse(
    Guid Id,
    string Name,
    string CurrentUserRole,
    DateTimeOffset CreatedAt);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Application/CreateOrganization/CreateOrganizationHandler.cs
using App.Modules.Organizations.Application.Abstractions;
using App.Modules.Organizations.Domain;
using App.SharedKernel.Results;

namespace App.Modules.Organizations.Application.CreateOrganization;

public sealed class CreateOrganizationHandler
{
    private readonly IOrganizationRepository _organizations;
    private readonly ICurrentUserService _currentUser;

    public CreateOrganizationHandler(
        IOrganizationRepository organizations,
        ICurrentUserService currentUser)
    {
        _organizations = organizations;
        _currentUser = currentUser;
    }

    public async Task<Result<CreateOrganizationResponse>> HandleAsync(
        CreateOrganizationRequest request,
        CancellationToken cancellationToken)
    {
        if (!_currentUser.IsAuthenticated)
        {
            return Result<CreateOrganizationResponse>.Failure(new AppError(
                "AUTH_REQUIRED",
                "User harus login."));
        }

        if (string.IsNullOrWhiteSpace(request.Name) || request.Name.Trim().Length < 2)
        {
            return Result<CreateOrganizationResponse>.Failure(new AppError(
                "ORGANIZATION_NAME_INVALID",
                "Nama organization minimal 2 karakter."));
        }

        var organization = Organization.Create(
            request.Name,
            _currentUser.UserId,
            _currentUser.Email);

        await _organizations.AddAsync(organization, cancellationToken);

        return Result<CreateOrganizationResponse>.Success(new CreateOrganizationResponse(
            organization.Id,
            organization.Name,
            OrganizationRole.Owner.ToString(),
            organization.CreatedAt));
    }
}
```

## Get My Organizations

Endpoint ini mengembalikan semua organization yang dimiliki user login sebagai member.

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Application/GetMyOrganizations/MyOrganizationResponse.cs
namespace App.Modules.Organizations.Application.GetMyOrganizations;

public sealed record MyOrganizationResponse(
    Guid Id,
    string Name,
    string Role,
    DateTimeOffset CreatedAt);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Application/GetMyOrganizations/GetMyOrganizationsHandler.cs
using App.Modules.Organizations.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Organizations.Application.GetMyOrganizations;

public sealed class GetMyOrganizationsHandler
{
    private readonly IOrganizationRepository _organizations;
    private readonly ICurrentUserService _currentUser;

    public GetMyOrganizationsHandler(
        IOrganizationRepository organizations,
        ICurrentUserService currentUser)
    {
        _organizations = organizations;
        _currentUser = currentUser;
    }

    public async Task<Result<IReadOnlyCollection<MyOrganizationResponse>>> HandleAsync(
        CancellationToken cancellationToken)
    {
        if (!_currentUser.IsAuthenticated)
        {
            return Result<IReadOnlyCollection<MyOrganizationResponse>>.Failure(new AppError(
                "AUTH_REQUIRED",
                "User harus login."));
        }

        var organizations = await _organizations.GetByUserIdAsync(
            _currentUser.UserId,
            cancellationToken);

        var response = organizations
            .Select(organization =>
            {
                var member = organization.GetMember(_currentUser.UserId)!;
                return new MyOrganizationResponse(
                    organization.Id,
                    organization.Name,
                    member.Role.ToString(),
                    organization.CreatedAt);
            })
            .ToArray();

        return Result<IReadOnlyCollection<MyOrganizationResponse>>.Success(response);
    }
}
```

## Get Organization Detail

Detail organization hanya bisa dibaca member organization tersebut.

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Application/GetOrganizationDetail/OrganizationDetailResponse.cs
namespace App.Modules.Organizations.Application.GetOrganizationDetail;

public sealed record OrganizationDetailResponse(
    Guid Id,
    string Name,
    string CurrentUserRole,
    DateTimeOffset CreatedAt,
    IReadOnlyCollection<OrganizationMemberResponse> Members);

public sealed record OrganizationMemberResponse(
    Guid UserId,
    string Email,
    string Role,
    DateTimeOffset JoinedAt);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Application/GetOrganizationDetail/GetOrganizationDetailHandler.cs
using App.Modules.Organizations.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Organizations.Application.GetOrganizationDetail;

public sealed class GetOrganizationDetailHandler
{
    private readonly IOrganizationRepository _organizations;
    private readonly ICurrentUserService _currentUser;

    public GetOrganizationDetailHandler(
        IOrganizationRepository organizations,
        ICurrentUserService currentUser)
    {
        _organizations = organizations;
        _currentUser = currentUser;
    }

    public async Task<Result<OrganizationDetailResponse>> HandleAsync(
        Guid organizationId,
        CancellationToken cancellationToken)
    {
        var organization = await _organizations.GetByIdAsync(organizationId, cancellationToken);

        if (organization is null)
            return Result<OrganizationDetailResponse>.Failure(new AppError("ORGANIZATION_NOT_FOUND", "Organization tidak ditemukan."));

        var currentMember = organization.GetMember(_currentUser.UserId);

        if (currentMember is null)
            return Result<OrganizationDetailResponse>.Failure(new AppError("ORGANIZATION_FORBIDDEN", "User bukan member organization ini."));

        var members = organization.Members
            .Select(member => new OrganizationMemberResponse(
                member.UserId,
                member.Email,
                member.Role.ToString(),
                member.JoinedAt))
            .ToArray();

        return Result<OrganizationDetailResponse>.Success(new OrganizationDetailResponse(
            organization.Id,
            organization.Name,
            currentMember.Role.ToString(),
            organization.CreatedAt,
            members));
    }
}
```

## Add Member

Untuk tutorial ini, add member menerima `UserId` dan `Email` langsung. Di aplikasi production, biasanya flow-nya memakai invitation email atau pencarian user dari module Identity.

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Application/AddMember/AddOrganizationMemberRequest.cs
using App.Modules.Organizations.Domain;

namespace App.Modules.Organizations.Application.AddMember;

public sealed record AddOrganizationMemberRequest(
    Guid UserId,
    string Email,
    OrganizationRole Role);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Application/AddMember/AddOrganizationMemberHandler.cs
using App.Modules.Organizations.Application.Abstractions;
using App.Modules.Organizations.Domain;
using App.SharedKernel.Results;

namespace App.Modules.Organizations.Application.AddMember;

public sealed class AddOrganizationMemberHandler
{
    private readonly IOrganizationRepository _organizations;
    private readonly ICurrentUserService _currentUser;

    public AddOrganizationMemberHandler(
        IOrganizationRepository organizations,
        ICurrentUserService currentUser)
    {
        _organizations = organizations;
        _currentUser = currentUser;
    }

    public async Task<Result<string>> HandleAsync(
        Guid organizationId,
        AddOrganizationMemberRequest request,
        CancellationToken cancellationToken)
    {
        if (request.UserId == Guid.Empty)
            return Result<string>.Failure(new AppError("ORGANIZATION_MEMBER_USER_INVALID", "UserId member wajib diisi."));

        if (string.IsNullOrWhiteSpace(request.Email) || !request.Email.Contains('@'))
            return Result<string>.Failure(new AppError("ORGANIZATION_MEMBER_EMAIL_INVALID", "Email member tidak valid."));

        if (request.Role == OrganizationRole.Owner)
            return Result<string>.Failure(new AppError("ORGANIZATION_OWNER_ADD_NOT_ALLOWED", "Owner tidak boleh ditambahkan lewat endpoint ini."));

        var organization = await _organizations.GetByIdAsync(organizationId, cancellationToken);

        if (organization is null)
            return Result<string>.Failure(new AppError("ORGANIZATION_NOT_FOUND", "Organization tidak ditemukan."));

        try
        {
            organization.AddMember(_currentUser.UserId, request.UserId, request.Email, request.Role);
            await _organizations.SaveChangesAsync(cancellationToken);
            return Result<string>.Success("Member berhasil ditambahkan.");
        }
        catch (InvalidOperationException exception)
        {
            return Result<string>.Failure(new AppError("ORGANIZATION_MEMBER_ADD_FAILED", exception.Message));
        }
    }
}
```

## Change Member Role

Hanya `Owner` atau `Admin` yang boleh mengubah role member. Owner tidak diubah lewat flow sederhana ini.

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Application/ChangeMemberRole/ChangeMemberRoleRequest.cs
using App.Modules.Organizations.Domain;

namespace App.Modules.Organizations.Application.ChangeMemberRole;

public sealed record ChangeMemberRoleRequest(OrganizationRole Role);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Application/ChangeMemberRole/ChangeMemberRoleHandler.cs
using App.Modules.Organizations.Application.Abstractions;
using App.Modules.Organizations.Domain;
using App.SharedKernel.Results;

namespace App.Modules.Organizations.Application.ChangeMemberRole;

public sealed class ChangeMemberRoleHandler
{
    private readonly IOrganizationRepository _organizations;
    private readonly ICurrentUserService _currentUser;

    public ChangeMemberRoleHandler(
        IOrganizationRepository organizations,
        ICurrentUserService currentUser)
    {
        _organizations = organizations;
        _currentUser = currentUser;
    }

    public async Task<Result<string>> HandleAsync(
        Guid organizationId,
        Guid memberUserId,
        ChangeMemberRoleRequest request,
        CancellationToken cancellationToken)
    {
        if (memberUserId == Guid.Empty)
            return Result<string>.Failure(new AppError("ORGANIZATION_MEMBER_USER_INVALID", "MemberUserId wajib diisi."));

        if (request.Role == OrganizationRole.Owner)
            return Result<string>.Failure(new AppError("ORGANIZATION_OWNER_PROMOTE_NOT_ALLOWED", "Promote owner tidak dibahas di file ini."));

        var organization = await _organizations.GetByIdAsync(organizationId, cancellationToken);

        if (organization is null)
            return Result<string>.Failure(new AppError("ORGANIZATION_NOT_FOUND", "Organization tidak ditemukan."));

        try
        {
            organization.ChangeMemberRole(_currentUser.UserId, memberUserId, request.Role);
            await _organizations.SaveChangesAsync(cancellationToken);
            return Result<string>.Success("Role member berhasil diubah.");
        }
        catch (InvalidOperationException exception)
        {
            return Result<string>.Failure(new AppError("ORGANIZATION_MEMBER_ROLE_CHANGE_FAILED", exception.Message));
        }
    }
}
```

## Remove Member

Owner atau admin bisa menghapus member biasa. Owner tidak bisa dihapus lewat flow sederhana ini.

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Application/RemoveMember/RemoveOrganizationMemberHandler.cs
using App.Modules.Organizations.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Organizations.Application.RemoveMember;

public sealed class RemoveOrganizationMemberHandler
{
    private readonly IOrganizationRepository _organizations;
    private readonly ICurrentUserService _currentUser;

    public RemoveOrganizationMemberHandler(
        IOrganizationRepository organizations,
        ICurrentUserService currentUser)
    {
        _organizations = organizations;
        _currentUser = currentUser;
    }

    public async Task<Result<string>> HandleAsync(
        Guid organizationId,
        Guid memberUserId,
        CancellationToken cancellationToken)
    {
        if (memberUserId == Guid.Empty)
            return Result<string>.Failure(new AppError("ORGANIZATION_MEMBER_USER_INVALID", "MemberUserId wajib diisi."));

        var organization = await _organizations.GetByIdAsync(organizationId, cancellationToken);

        if (organization is null)
            return Result<string>.Failure(new AppError("ORGANIZATION_NOT_FOUND", "Organization tidak ditemukan."));

        try
        {
            organization.RemoveMember(_currentUser.UserId, memberUserId);
            await _organizations.SaveChangesAsync(cancellationToken);
            return Result<string>.Success("Member berhasil dihapus.");
        }
        catch (InvalidOperationException exception)
        {
            return Result<string>.Failure(new AppError("ORGANIZATION_MEMBER_REMOVE_FAILED", exception.Message));
        }
    }
}
```

## Infrastructure Layer

### In-memory Repository

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Infrastructure/InMemoryOrganizationRepository.cs
using App.Modules.Organizations.Application.Abstractions;
using App.Modules.Organizations.Domain;

namespace App.Modules.Organizations.Infrastructure;

public sealed class InMemoryOrganizationRepository : IOrganizationRepository
{
    private static readonly List<Organization> Organizations = new();

    public Task AddAsync(Organization organization, CancellationToken cancellationToken)
    {
        Organizations.Add(organization);
        return Task.CompletedTask;
    }

    public Task<Organization?> GetByIdAsync(Guid organizationId, CancellationToken cancellationToken)
    {
        var organization = Organizations.FirstOrDefault(item => item.Id == organizationId);
        return Task.FromResult(organization);
    }

    public Task<IReadOnlyCollection<Organization>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken)
    {
        IReadOnlyCollection<Organization> result = Organizations
            .Where(organization => organization.IsMember(userId))
            .ToArray();

        return Task.FromResult(result);
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }
}
```

### Current User Service

Service ini membaca user id dan email dari JWT claim yang sudah diisi middleware authentication.

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Infrastructure/CurrentUserService.cs
using System.Security.Claims;
using App.Modules.Organizations.Application.Abstractions;
using Microsoft.AspNetCore.Http;

namespace App.Modules.Organizations.Infrastructure;

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

## Organizations Module DI

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/OrganizationsModule.cs
using App.Modules.Organizations.Application.Abstractions;
using App.Modules.Organizations.Application.AddMember;
using App.Modules.Organizations.Application.ChangeMemberRole;
using App.Modules.Organizations.Application.CreateOrganization;
using App.Modules.Organizations.Application.GetMyOrganizations;
using App.Modules.Organizations.Application.GetOrganizationDetail;
using App.Modules.Organizations.Application.RemoveMember;
using App.Modules.Organizations.Infrastructure;
using App.Modules.Organizations.Presentation;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

namespace App.Modules.Organizations;

public static class OrganizationsModule
{
    public static IServiceCollection AddOrganizationsModule(this IServiceCollection services)
    {
        services.AddHttpContextAccessor();
        services.AddSingleton<IOrganizationRepository, InMemoryOrganizationRepository>();
        services.AddScoped<ICurrentUserService, CurrentUserService>();

        services.AddScoped<CreateOrganizationHandler>();
        services.AddScoped<GetMyOrganizationsHandler>();
        services.AddScoped<GetOrganizationDetailHandler>();
        services.AddScoped<AddOrganizationMemberHandler>();
        services.AddScoped<ChangeMemberRoleHandler>();
        services.AddScoped<RemoveOrganizationMemberHandler>();

        return services;
    }

    public static IEndpointRouteBuilder MapOrganizationsModule(this IEndpointRouteBuilder app)
    {
        app.MapOrganizationEndpoints();
        return app;
    }
}
```

## Presentation Layer

Semua endpoint di module ini protected karena organization hanya bisa diakses user login.

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Presentation/OrganizationEndpoints.cs
using App.Modules.Organizations.Application.AddMember;
using App.Modules.Organizations.Application.ChangeMemberRole;
using App.Modules.Organizations.Application.CreateOrganization;
using App.Modules.Organizations.Application.GetMyOrganizations;
using App.Modules.Organizations.Application.GetOrganizationDetail;
using App.Modules.Organizations.Application.RemoveMember;
using App.SharedKernel.Responses;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace App.Modules.Organizations.Presentation;

public static class OrganizationEndpoints
{
    public static IEndpointRouteBuilder MapOrganizationEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/organizations")
            .WithTags("Organizations")
            .RequireAuthorization();

        group.MapPost("/", CreateAsync);
        group.MapGet("/my", GetMyOrganizationsAsync);
        group.MapGet("/{organizationId:guid}", GetDetailAsync);
        group.MapPost("/{organizationId:guid}/members", AddMemberAsync);
        group.MapPut("/{organizationId:guid}/members/{memberUserId:guid}/role", ChangeMemberRoleAsync);
        group.MapDelete("/{organizationId:guid}/members/{memberUserId:guid}", RemoveMemberAsync);

        return app;
    }

    private static async Task<IResult> CreateAsync(
        CreateOrganizationRequest request,
        CreateOrganizationHandler handler,
        CancellationToken cancellationToken)
    {
        var result = await handler.HandleAsync(request, cancellationToken);
        return ToHttpResult(result, StatusCodes.Status201Created);
    }

    private static async Task<IResult> GetMyOrganizationsAsync(
        GetMyOrganizationsHandler handler,
        CancellationToken cancellationToken)
    {
        var result = await handler.HandleAsync(cancellationToken);
        return ToHttpResult(result);
    }

    private static async Task<IResult> GetDetailAsync(
        Guid organizationId,
        GetOrganizationDetailHandler handler,
        CancellationToken cancellationToken)
    {
        var result = await handler.HandleAsync(organizationId, cancellationToken);
        return ToHttpResult(result);
    }

    private static async Task<IResult> AddMemberAsync(
        Guid organizationId,
        AddOrganizationMemberRequest request,
        AddOrganizationMemberHandler handler,
        CancellationToken cancellationToken)
    {
        var result = await handler.HandleAsync(organizationId, request, cancellationToken);
        return ToHttpResult(result);
    }

    private static async Task<IResult> ChangeMemberRoleAsync(
        Guid organizationId,
        Guid memberUserId,
        ChangeMemberRoleRequest request,
        ChangeMemberRoleHandler handler,
        CancellationToken cancellationToken)
    {
        var result = await handler.HandleAsync(organizationId, memberUserId, request, cancellationToken);
        return ToHttpResult(result);
    }

    private static async Task<IResult> RemoveMemberAsync(
        Guid organizationId,
        Guid memberUserId,
        RemoveOrganizationMemberHandler handler,
        CancellationToken cancellationToken)
    {
        var result = await handler.HandleAsync(organizationId, memberUserId, cancellationToken);
        return ToHttpResult(result);
    }

    private static IResult ToHttpResult<T>(App.SharedKernel.Results.Result<T> result, int successStatusCode = StatusCodes.Status200OK)
    {
        if (result.IsFailure)
        {
            var error = new ApiErrorResponse(result.Error!.Code, result.Error.Message, result.Error.Details);
            var response = ApiResponse<T>.Fail(error);
            return Results.BadRequest(response);
        }

        var success = ApiResponse<T>.Ok(result.Value!);
        return successStatusCode == StatusCodes.Status201Created
            ? Results.Json(success, statusCode: StatusCodes.Status201Created)
            : Results.Ok(success);
    }
}
```

## Program.cs

Tambahkan module Organizations setelah authentication dan authorization disiapkan dari file `03`.

```csharp
// File: ProjectManagement.Backend/src/ProjectManagement.Api/Program.cs
using App.Modules.Identity;
using App.Modules.Organizations;
using App.SharedKernel.Responses;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddIdentityModule(builder.Configuration);
builder.Services.AddOrganizationsModule();

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

app.MapGet("/health", () =>
{
    return Results.Ok(ApiResponse<object>.Ok(new
    {
        service = "ProjectManagement.Api",
        status = "Healthy",
        checkedAt = DateTimeOffset.UtcNow
    }));
});

app.MapIdentityModule();
app.MapOrganizationsModule();

app.Run();
```

Catatan:

- Contoh di atas hanya menunjukkan wiring module Organizations.
- Konfigurasi JWT lengkap tetap mengikuti file `03-identity-auth.md`.
- `app.UseAuthentication()` harus dipanggil sebelum `app.UseAuthorization()`.
- `MapOrganizationsModule()` boleh dipanggil setelah middleware authentication/authorization.

## Current Organization Context Sederhana

Current organization context adalah cara backend mengetahui organization mana yang sedang diakses request.

Di file ini, context diambil dari route:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/04-organization-tenancy.md
GET /api/organizations/{organizationId}
POST /api/organizations/{organizationId}/members
PUT /api/organizations/{organizationId}/members/{memberUserId}/role
DELETE /api/organizations/{organizationId}/members/{memberUserId}
```

`organizationId` dari route menjadi tenant context. Handler kemudian mengecek apakah current user adalah member organization tersebut.

Untuk module `Projects` dan `Tasks`, pola route sebaiknya seperti ini:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/04-organization-tenancy.md
GET /api/organizations/{organizationId}/projects
POST /api/organizations/{organizationId}/projects
GET /api/organizations/{organizationId}/tasks
POST /api/organizations/{organizationId}/tasks
```

Dengan pola ini, tenant context eksplisit dan mudah divalidasi.

## Test Manual Dengan Curl

Sebelum test organization, register dan login dulu mengikuti file `03`. Simpan access token dari login.

### Create Organization

```powershell
# File: ProjectManagement.Backend/commands/44-test-create-organization.ps1
curl -X POST http://localhost:5000/api/organizations `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer <access-token>" `
  -d '{"name":"Acme Studio"}'
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-create-organization-response.json
{
  "success": true,
  "data": {
    "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    "name": "Acme Studio",
    "currentUserRole": "Owner",
    "createdAt": "2026-07-07T10:00:00.0000000+00:00"
  },
  "error": null,
  "meta": null
}
```

Simpan `id` organization untuk request berikutnya.

### Get My Organizations

```powershell
# File: ProjectManagement.Backend/commands/45-test-my-organizations.ps1
curl http://localhost:5000/api/organizations/my `
  -H "Authorization: Bearer <access-token>"
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-my-organizations-response.json
{
  "success": true,
  "data": [
    {
      "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "name": "Acme Studio",
      "role": "Owner",
      "createdAt": "2026-07-07T10:00:00.0000000+00:00"
    }
  ],
  "error": null,
  "meta": null
}
```

### Get Organization Detail

```powershell
# File: ProjectManagement.Backend/commands/46-test-organization-detail.ps1
curl http://localhost:5000/api/organizations/<organization-id> `
  -H "Authorization: Bearer <access-token>"
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-organization-detail-response.json
{
  "success": true,
  "data": {
    "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    "name": "Acme Studio",
    "currentUserRole": "Owner",
    "createdAt": "2026-07-07T10:00:00.0000000+00:00",
    "members": [
      {
        "userId": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
        "email": "budi@example.com",
        "role": "Owner",
        "joinedAt": "2026-07-07T10:00:00.0000000+00:00"
      }
    ]
  },
  "error": null,
  "meta": null
}
```

### Add Member

Untuk tutorial ini, `userId` member diisi manual. Nanti flow yang lebih realistis bisa membaca user dari module Identity atau invitation.

```powershell
# File: ProjectManagement.Backend/commands/47-test-add-organization-member.ps1
curl -X POST http://localhost:5000/api/organizations/<organization-id>/members `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer <access-token>" `
  -d '{"userId":"cccccccc-cccc-cccc-cccc-cccccccccccc","email":"member@example.com","role":"Member"}'
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-add-member-response.json
{
  "success": true,
  "data": "Member berhasil ditambahkan.",
  "error": null,
  "meta": null
}
```

### Change Member Role

```powershell
# File: ProjectManagement.Backend/commands/48-test-change-member-role.ps1
curl -X PUT http://localhost:5000/api/organizations/<organization-id>/members/cccccccc-cccc-cccc-cccc-cccccccccccc/role `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer <access-token>" `
  -d '{"role":"Admin"}'
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-change-member-role-response.json
{
  "success": true,
  "data": "Role member berhasil diubah.",
  "error": null,
  "meta": null
}
```

### Remove Member

```powershell
# File: ProjectManagement.Backend/commands/49-test-remove-member.ps1
curl -X DELETE http://localhost:5000/api/organizations/<organization-id>/members/cccccccc-cccc-cccc-cccc-cccccccccccc `
  -H "Authorization: Bearer <access-token>"
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-remove-member-response.json
{
  "success": true,
  "data": "Member berhasil dihapus.",
  "error": null,
  "meta": null
}
```

## Error Response Sederhana

Contoh jika user bukan member organization:

```json
// File: ProjectManagement.Backend/commands/expected-organization-forbidden-response.json
{
  "success": false,
  "data": null,
  "error": {
    "code": "ORGANIZATION_FORBIDDEN",
    "message": "User bukan member organization ini.",
    "details": null
  },
  "meta": null
}
```

Contoh jika nama organization tidak valid:

```json
// File: ProjectManagement.Backend/commands/expected-organization-invalid-name-response.json
{
  "success": false,
  "data": null,
  "error": {
    "code": "ORGANIZATION_NAME_INVALID",
    "message": "Nama organization minimal 2 karakter.",
    "details": null
  },
  "meta": null
}
```

## Tenant Isolation Untuk Module Berikutnya

Setelah module Organizations ada, module `Projects` dan `Tasks` wajib mengikuti aturan ini:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/04-organization-tenancy.md
[ ] Semua table tenant data punya OrganizationId.
[ ] Semua endpoint tenant data punya organizationId di route.
[ ] Semua query filter berdasarkan OrganizationId.
[ ] Semua command mengecek membership current user.
[ ] Role Owner/Admin/Member dicek di Application layer.
[ ] UI tidak boleh menjadi sumber kebenaran role/permission.
```

Contoh flow create project nanti:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/04-organization-tenancy.md
POST /api/organizations/{organizationId}/projects
  -> Projects.Presentation
  -> Projects.Application CreateProjectHandler
  -> Organizations.Application/IOrganizationAccessReader
  -> cek current user membership
  -> Project.Create(organizationId, ...)
  -> ProjectRepository.AddAsync
```

## Build Dan Verifikasi

Build solution.

```powershell
# File: ProjectManagement.Backend/commands/50-build-organizations.ps1
dotnet build
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

Cek package/project reference jika namespace module tidak terbaca.

```powershell
# File: ProjectManagement.Backend/commands/51-check-organizations-reference.ps1
dotnet sln list
dotnet list src/ProjectManagement.Api/ProjectManagement.Api.csproj reference
```

## Troubleshooting

### Endpoint Organizations Selalu 401

Penyebab umum:

- token tidak dikirim;
- token salah format;
- middleware authentication belum dipasang;
- endpoint memakai `.RequireAuthorization()`.

Solusi:

```powershell
# File: ProjectManagement.Backend/commands/troubleshoot-organization-auth-header.ps1
curl http://localhost:5000/api/organizations/my `
  -H "Authorization: Bearer <access-token>"
```

Pastikan urutan middleware benar:

```csharp
// File: ProjectManagement.Backend/src/ProjectManagement.Api/Program.cs
app.UseAuthentication();
app.UseAuthorization();
app.MapOrganizationsModule();
```

### Current User Kosong

Penyebab:

- `AddHttpContextAccessor()` belum dipanggil;
- claim `ClaimTypes.NameIdentifier` tidak ada di token;
- `CurrentUserService` belum didaftarkan.

Solusi:

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/OrganizationsModule.cs
services.AddHttpContextAccessor();
services.AddScoped<ICurrentUserService, CurrentUserService>();
```

### Organization Hilang Setelah Restart

Penyebab:

- repository masih in-memory;
- aplikasi restart menghapus data.

Solusi sementara:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/04-organization-tenancy.md
Buat ulang organization setelah restart.
Persistence database akan dibuat di 08-database-migration-seed.md.
```

### Member Tidak Bisa Ditambahkan

Penyebab umum:

- current user bukan owner/admin;
- target user sudah menjadi member;
- request memakai role `Owner`;
- email target tidak valid.

Solusi:

```json
// File: ProjectManagement.Backend/commands/add-member-valid-body.json
{
  "userId": "cccccccc-cccc-cccc-cccc-cccccccccccc",
  "email": "member@example.com",
  "role": "Member"
}
```

## Checklist Selesai

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/04-organization-tenancy.md
[ ] Organization domain dibuat.
[ ] OrganizationMember domain dibuat.
[ ] OrganizationRole Owner/Admin/Member tersedia.
[ ] Create organization otomatis membuat owner membership.
[ ] Get my organizations membaca organization berdasarkan current user.
[ ] Get detail organization mengecek membership.
[ ] Add member hanya bisa dilakukan owner/admin.
[ ] Change member role hanya bisa dilakukan owner/admin.
[ ] Remove member hanya bisa dilakukan owner/admin.
[ ] CurrentUserService membaca user id dan email dari JWT claim.
[ ] Endpoint Organizations memakai RequireAuthorization().
[ ] Response sukses dan error memakai ApiResponse envelope.
[ ] Project/task berikutnya wajib memakai OrganizationId.
```

## Ringkasan

Alur create organization:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/04-organization-tenancy.md
POST /api/organizations
  -> OrganizationEndpoints
  -> CreateOrganizationHandler
  -> CurrentUserService membaca claim JWT
  -> Organization.Create
  -> owner membership dibuat otomatis
  -> IOrganizationRepository.AddAsync
  -> ApiResponse<CreateOrganizationResponse>
```

Alur tenant authorization:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/04-organization-tenancy.md
Request dengan organizationId
  -> ambil current user dari JWT
  -> load organization
  -> cek membership current user
  -> cek role Owner/Admin/Member
  -> jalankan use case
```

Dengan module Organizations ini, backend sudah punya fondasi tenancy. File berikutnya bisa memakai `OrganizationId` sebagai tenant boundary untuk CRUD project dan task tanpa mencampur data antar organization.
