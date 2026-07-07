# Backend 08 - Database, Migration, dan Seed

File ini melanjutkan module yang sebelumnya masih memakai in-memory repository: `Identity`, `Organizations`, `Projects`, dan `Tasks`. In-memory repository bagus untuk belajar alur use case tanpa terganggu setup database. Namun data in-memory hilang setiap aplikasi restart dan tidak cukup untuk aplikasi enterprise.

Tujuan file ini adalah mengganti penyimpanan sementara menjadi database persistence menggunakan Entity Framework Core. Contoh utama memakai SQLite agar mudah dijalankan pemula tanpa install database server. Setelah konsepnya jelas, pola yang sama bisa diarahkan ke PostgreSQL atau SQL Server.

Dalam modular monolith, database tetap boleh satu database fisik. Yang penting adalah boundary module tetap dijaga di kode:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/08-database-migration-seed.md
Satu deployable backend
  -> satu database aplikasi
  -> tabel dipetakan per module
  -> repository module hanya mengakses data milik module/context yang tepat
```

## Kenapa Sebelumnya In-memory Repository

File `03` sampai `06` memakai in-memory repository supaya pembaca fokus pada:

- alur request ke handler;
- validation;
- tenant isolation;
- authorization sederhana;
- response envelope;
- module boundary;
- Strategy Pattern untuk task status.

Jika database dimasukkan terlalu awal, pembaca junior sering terdistraksi oleh migration, connection string, provider database, dan mapping EF Core.

## Kenapa Sekarang Perlu Database Asli

Database asli diperlukan karena:

- data harus tetap ada setelah aplikasi restart;
- user, organization, project, dan task saling terhubung;
- butuh constraint seperti primary key, foreign key, dan unique index;
- butuh migration agar perubahan schema bisa dilacak;
- butuh seed data untuk admin/sample data;
- testing end-to-end butuh data realistis.

## Konsep Dasar Database Di .NET

### Database

Database adalah tempat menyimpan data aplikasi secara permanen.

### Table

Table adalah struktur penyimpanan untuk satu jenis data. Contoh: `Users`, `Organizations`, `Projects`, `Tasks`.

### Row

Row adalah satu record di table. Contoh: satu user bernama Budi adalah satu row di table `Users`.

### Primary Key

Primary key adalah id unik untuk row. Di tutorial ini primary key memakai `Guid`.

### Foreign Key

Foreign key menghubungkan table. Contoh: `Projects.OrganizationId` menunjuk ke `Organizations.Id`.

### Index

Index mempercepat pencarian. Contoh: index unik pada `Users.Email` agar email tidak duplikat.

### Migration

Migration adalah riwayat perubahan schema database. EF Core bisa membuat file migration dari perubahan model/configuration.

### Seed Data

Seed data adalah data awal yang dimasukkan otomatis, misalnya admin user, sample organization, sample project, dan sample task.

### ORM

ORM atau Object Relational Mapper membantu mapping class C# ke table database.

### Entity Framework Core

Entity Framework Core atau EF Core adalah ORM resmi dari Microsoft untuk .NET.

### DbContext

`DbContext` adalah class utama EF Core untuk mengakses database. Ia berisi `DbSet`, konfigurasi model, dan unit of work.

### DbSet

`DbSet<T>` merepresentasikan table untuk entity tertentu. Contoh: `DbSet<User> Users`.

### Repository

Repository adalah abstraction untuk membaca/menulis data. Application layer memanggil interface repository, infrastructure menyediakan implementasi EF Core.

### Unit of Work

Unit of Work mengumpulkan perubahan lalu menyimpannya dalam satu operasi. Di EF Core, `DbContext.SaveChangesAsync()` berperan sebagai unit of work.

### Connection String

Connection string adalah konfigurasi lokasi database. Contoh SQLite: `Data Source=app.db`.

## Pilihan Database

### SQLite

SQLite cocok untuk belajar lokal karena:

- file-based;
- tidak perlu install database server;
- setup cepat;
- mudah dihapus/reset.

Gunakan SQLite untuk tutorial awal dan mockup lokal.

### PostgreSQL

PostgreSQL cocok untuk production modern karena:

- open-source;
- kuat untuk aplikasi web;
- umum dipakai di cloud;
- fitur indexing dan JSON cukup matang.

Gunakan PostgreSQL jika target production cloud atau SaaS modern.

### SQL Server

SQL Server cocok untuk enterprise Microsoft stack karena:

- umum di perusahaan besar;
- integrasi kuat dengan ekosistem Microsoft;
- tooling enterprise matang;
- cocok untuk organisasi yang sudah memakai SQL Server.

Gunakan SQL Server jika perusahaan atau client sudah berada di ekosistem Microsoft.

## Struktur Folder Database

```txt
# File: docs/stacks/enterprise-dotnet-spring/backend/08-database-migration-seed.md
src/
├── App.Api/
│   ├── appsettings.json
│   └── Program.cs
│
├── Infrastructure/
│   ├── Database/
│   │   ├── AppDbContext.cs
│   │   ├── AppDbContextFactory.cs
│   │   ├── DatabaseSeeder.cs
│   │   └── EntityConfigurations/
│   │       ├── Identity/
│   │       │   ├── UserConfiguration.cs
│   │       │   ├── RoleConfiguration.cs
│   │       │   └── UserRoleConfiguration.cs
│   │       ├── Organizations/
│   │       │   ├── OrganizationConfiguration.cs
│   │       │   └── OrganizationMemberConfiguration.cs
│   │       ├── Projects/
│   │       │   └── ProjectConfiguration.cs
│   │       └── Tasks/
│   │           └── TaskItemConfiguration.cs
│   │
│   └── DependencyInjection.cs
│
└── Modules/
    ├── Identity/
    │   └── Infrastructure/
    │       └── EfUserRepository.cs
    ├── Organizations/
    │   └── Infrastructure/
    │       └── EfOrganizationRepository.cs
    ├── Projects/
    │   └── Infrastructure/
    │       └── EfProjectRepository.cs
    └── Tasks/
        └── Infrastructure/
            └── EfTaskRepository.cs
```

## Command Membuat Folder

```powershell
# File: ProjectManagement.Backend/commands/76-create-database-folders.ps1
mkdir src/Infrastructure/Database
mkdir src/Infrastructure/Database/EntityConfigurations
mkdir src/Infrastructure/Database/EntityConfigurations/Identity
mkdir src/Infrastructure/Database/EntityConfigurations/Organizations
mkdir src/Infrastructure/Database/EntityConfigurations/Projects
mkdir src/Infrastructure/Database/EntityConfigurations/Tasks
```

Penjelasan:

- `Database` berisi `DbContext`, factory, seeder, dan mapping EF Core.
- `EntityConfigurations` memisahkan mapping per module agar `AppDbContext` tidak terlalu besar.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Directory structure created without errors.
```

## Install Package EF Core

Untuk SQLite:

```powershell
# File: ProjectManagement.Backend/commands/77-add-efcore-sqlite-packages.ps1
dotnet add src/ProjectManagement.Api/ProjectManagement.Api.csproj package Microsoft.EntityFrameworkCore.Design
dotnet add src/ProjectManagement.Api/ProjectManagement.Api.csproj package Microsoft.EntityFrameworkCore.Sqlite
dotnet add src/ProjectManagement.Api/ProjectManagement.Api.csproj package Microsoft.EntityFrameworkCore.Tools
```

Penjelasan:

- `Microsoft.EntityFrameworkCore.Sqlite` adalah provider SQLite.
- `Microsoft.EntityFrameworkCore.Design` dibutuhkan tooling migration.
- `Microsoft.EntityFrameworkCore.Tools` membantu command migration di beberapa environment.

Install tool EF Core CLI jika belum ada:

```powershell
# File: ProjectManagement.Backend/commands/78-install-ef-tool.ps1
dotnet tool install --global dotnet-ef
```

Jika sudah pernah install, update:

```powershell
# File: ProjectManagement.Backend/commands/79-update-ef-tool.ps1
dotnet tool update --global dotnet-ef
```

Verifikasi:

```powershell
# File: ProjectManagement.Backend/commands/80-check-ef-tool.ps1
dotnet ef --version
```

## Connection String

Untuk contoh utama, gunakan SQLite.

```json
// File: ProjectManagement.Backend/src/ProjectManagement.Api/appsettings.json
{
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=project-management.db"
  }
}
```

Alternatif PostgreSQL:

```json
// File: ProjectManagement.Backend/src/ProjectManagement.Api/appsettings.PostgreSql.example.json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=project_management;Username=postgres;Password=postgres"
  }
}
```

Alternatif SQL Server:

```json
// File: ProjectManagement.Backend/src/ProjectManagement.Api/appsettings.SqlServer.example.json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=ProjectManagement;User Id=sa;Password=Your_password123;TrustServerCertificate=True"
  }
}
```

## Entity Yang Disimpan

Agar fokus ke database, contoh entity di file ini dibuat ringkas dan konsisten dengan module sebelumnya.

Entity utama:

- `User`
- `UserRole`
- `Organization`
- `OrganizationMember`
- `Project`
- `TaskItem`

Jika kode domain di module sudah memakai private constructor atau backing field, mapping EF Core bisa disesuaikan. Untuk pembelajaran awal, contoh ini dibuat eksplisit agar mudah dipahami.

## AppDbContext

`AppDbContext` menyatukan table lintas module dalam satu database aplikasi.

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/Database/AppDbContext.cs
using App.Modules.Identity.Domain;
using App.Modules.Organizations.Domain;
using App.Modules.Projects.Domain;
using App.Modules.Tasks.Domain;
using Microsoft.EntityFrameworkCore;

namespace App.Infrastructure.Database;

public sealed class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<UserRole> UserRoles => Set<UserRole>();
    public DbSet<Organization> Organizations => Set<Organization>();
    public DbSet<OrganizationMember> OrganizationMembers => Set<OrganizationMember>();
    public DbSet<Project> Projects => Set<Project>();
    public DbSet<TaskItem> Tasks => Set<TaskItem>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }
}
```

Penjelasan:

- `DbSet<User>` menjadi table `Users`.
- `DbSet<Project>` menjadi table `Projects`.
- `ApplyConfigurationsFromAssembly` membaca semua class mapping `IEntityTypeConfiguration<T>`.

## Design-time DbContext Factory

Factory dibutuhkan agar `dotnet ef migrations add` bisa membuat `AppDbContext` tanpa menjalankan seluruh aplikasi.

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/Database/AppDbContextFactory.cs
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace App.Infrastructure.Database;

public sealed class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
        optionsBuilder.UseSqlite("Data Source=project-management.db");

        return new AppDbContext(optionsBuilder.Options);
    }
}
```

## Entity Configurations Identity

### UserConfiguration

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/Database/EntityConfigurations/Identity/UserConfiguration.cs
using App.Modules.Identity.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace App.Infrastructure.Database.EntityConfigurations.Identity;

public sealed class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("Users");
        builder.HasKey(user => user.Id);

        builder.Property(user => user.Name)
            .HasMaxLength(150)
            .IsRequired();

        builder.Property(user => user.Email)
            .HasMaxLength(250)
            .IsRequired();

        builder.HasIndex(user => user.Email)
            .IsUnique();

        builder.Property(user => user.PasswordHash)
            .HasMaxLength(500)
            .IsRequired();

        builder.Property(user => user.CreatedAt)
            .IsRequired();
    }
}
```

### RoleConfiguration

Jika role disimpan sebagai enum saja, table `Roles` tidak wajib. Namun untuk seed dan relasi yang mudah dibaca, table role bisa dibuat.

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/Database/EntityConfigurations/Identity/RoleConfiguration.cs
using App.Modules.Identity.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace App.Infrastructure.Database.EntityConfigurations.Identity;

public sealed class RoleConfiguration : IEntityTypeConfiguration<UserRole>
{
    public void Configure(EntityTypeBuilder<UserRole> builder)
    {
        builder.ToTable("UserRoles");
        builder.HasKey(role => new { role.UserId, role.Role });

        builder.Property(role => role.Role)
            .HasConversion<string>()
            .HasMaxLength(50)
            .IsRequired();
    }
}
```

### UserRoleConfiguration

Jika ingin memisahkan konfigurasi role dan user role, gunakan file ini. Untuk contoh sederhana, file ini menunjukkan relasi user role ke user.

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/Database/EntityConfigurations/Identity/UserRoleConfiguration.cs
using App.Modules.Identity.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace App.Infrastructure.Database.EntityConfigurations.Identity;

public sealed class UserRoleConfiguration : IEntityTypeConfiguration<UserRole>
{
    public void Configure(EntityTypeBuilder<UserRole> builder)
    {
        builder.ToTable("UserRoles");
        builder.HasKey(userRole => new { userRole.UserId, userRole.Role });

        builder.Property(userRole => userRole.Role)
            .HasConversion<string>()
            .HasMaxLength(50)
            .IsRequired();
    }
}
```

Catatan: jangan punya dua configuration yang mengatur entity sama secara bertentangan. Jika memakai `UserRoleConfiguration`, `RoleConfiguration` bisa dihapus atau diubah menjadi konfigurasi table role terpisah.

## Entity Configurations Organizations

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/Database/EntityConfigurations/Organizations/OrganizationConfiguration.cs
using App.Modules.Organizations.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace App.Infrastructure.Database.EntityConfigurations.Organizations;

public sealed class OrganizationConfiguration : IEntityTypeConfiguration<Organization>
{
    public void Configure(EntityTypeBuilder<Organization> builder)
    {
        builder.ToTable("Organizations");
        builder.HasKey(organization => organization.Id);

        builder.Property(organization => organization.Name)
            .HasMaxLength(200)
            .IsRequired();

        builder.Property(organization => organization.CreatedAt)
            .IsRequired();
    }
}
```

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/Database/EntityConfigurations/Organizations/OrganizationMemberConfiguration.cs
using App.Modules.Organizations.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace App.Infrastructure.Database.EntityConfigurations.Organizations;

public sealed class OrganizationMemberConfiguration : IEntityTypeConfiguration<OrganizationMember>
{
    public void Configure(EntityTypeBuilder<OrganizationMember> builder)
    {
        builder.ToTable("OrganizationMembers");
        builder.HasKey(member => new { member.OrganizationId, member.UserId });

        builder.Property(member => member.Email)
            .HasMaxLength(250)
            .IsRequired();

        builder.Property(member => member.Role)
            .HasConversion<string>()
            .HasMaxLength(50)
            .IsRequired();

        builder.Property(member => member.JoinedAt)
            .IsRequired();

        builder.HasIndex(member => member.UserId);
    }
}
```

## Entity Configurations Projects Dan Tasks

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/Database/EntityConfigurations/Projects/ProjectConfiguration.cs
using App.Modules.Projects.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace App.Infrastructure.Database.EntityConfigurations.Projects;

public sealed class ProjectConfiguration : IEntityTypeConfiguration<Project>
{
    public void Configure(EntityTypeBuilder<Project> builder)
    {
        builder.ToTable("Projects");
        builder.HasKey(project => project.Id);

        builder.Property(project => project.OrganizationId).IsRequired();
        builder.Property(project => project.OwnerUserId).IsRequired();

        builder.Property(project => project.Name)
            .HasMaxLength(200)
            .IsRequired();

        builder.Property(project => project.Description)
            .HasMaxLength(2000);

        builder.Property(project => project.Status)
            .HasConversion<string>()
            .HasMaxLength(50)
            .IsRequired();

        builder.HasIndex(project => project.OrganizationId);
        builder.HasIndex(project => new { project.OrganizationId, project.Name });
    }
}
```

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/Database/EntityConfigurations/Tasks/TaskItemConfiguration.cs
using App.Modules.Tasks.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace App.Infrastructure.Database.EntityConfigurations.Tasks;

public sealed class TaskItemConfiguration : IEntityTypeConfiguration<TaskItem>
{
    public void Configure(EntityTypeBuilder<TaskItem> builder)
    {
        builder.ToTable("Tasks");
        builder.HasKey(task => task.Id);

        builder.Property(task => task.OrganizationId).IsRequired();
        builder.Property(task => task.ProjectId).IsRequired();
        builder.Property(task => task.CreatedByUserId).IsRequired();

        builder.Property(task => task.Title)
            .HasMaxLength(250)
            .IsRequired();

        builder.Property(task => task.Description)
            .HasMaxLength(4000);

        builder.Property(task => task.Status)
            .HasConversion<string>()
            .HasMaxLength(50)
            .IsRequired();

        builder.Property(task => task.Priority)
            .HasConversion<string>()
            .HasMaxLength(50)
            .IsRequired();

        builder.HasIndex(task => new { task.OrganizationId, task.ProjectId });
        builder.HasIndex(task => task.AssigneeUserId);
    }
}
```

## EF Core Repositories

Repository EF Core menggantikan in-memory repository. Interface tetap sama, sehingga Application layer tidak perlu berubah.

### EfUserRepository

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Infrastructure/EfUserRepository.cs
using App.Infrastructure.Database;
using App.Modules.Identity.Application.Abstractions;
using App.Modules.Identity.Domain;
using Microsoft.EntityFrameworkCore;

namespace App.Modules.Identity.Infrastructure;

public sealed class EfUserRepository : IUserRepository
{
    private readonly AppDbContext _dbContext;

    public EfUserRepository(AppDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public Task<User?> GetByIdAsync(Guid userId, CancellationToken cancellationToken)
    {
        return _dbContext.Users.FirstOrDefaultAsync(user => user.Id == userId, cancellationToken);
    }

    public Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken)
    {
        var normalizedEmail = email.Trim().ToLowerInvariant();
        return _dbContext.Users.FirstOrDefaultAsync(user => user.Email == normalizedEmail, cancellationToken);
    }

    public Task<bool> EmailExistsAsync(string email, CancellationToken cancellationToken)
    {
        var normalizedEmail = email.Trim().ToLowerInvariant();
        return _dbContext.Users.AnyAsync(user => user.Email == normalizedEmail, cancellationToken);
    }

    public async Task AddAsync(User user, CancellationToken cancellationToken)
    {
        await _dbContext.Users.AddAsync(user, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }
}
```

### EfOrganizationRepository

```csharp
// File: ProjectManagement.Backend/src/Modules/Organizations/Infrastructure/EfOrganizationRepository.cs
using App.Infrastructure.Database;
using App.Modules.Organizations.Application.Abstractions;
using App.Modules.Organizations.Domain;
using Microsoft.EntityFrameworkCore;

namespace App.Modules.Organizations.Infrastructure;

public sealed class EfOrganizationRepository : IOrganizationRepository
{
    private readonly AppDbContext _dbContext;

    public EfOrganizationRepository(AppDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task AddAsync(Organization organization, CancellationToken cancellationToken)
    {
        await _dbContext.Organizations.AddAsync(organization, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public Task<Organization?> GetByIdAsync(Guid organizationId, CancellationToken cancellationToken)
    {
        return _dbContext.Organizations.FirstOrDefaultAsync(organization => organization.Id == organizationId, cancellationToken);
    }

    public async Task<IReadOnlyCollection<Organization>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken)
    {
        return await _dbContext.Organizations
            .Where(organization => organization.Members.Any(member => member.UserId == userId))
            .ToArrayAsync(cancellationToken);
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        return _dbContext.SaveChangesAsync(cancellationToken);
    }
}
```

### EfProjectRepository

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Infrastructure/EfProjectRepository.cs
using App.Infrastructure.Database;
using App.Modules.Projects.Application.Abstractions;
using App.Modules.Projects.Domain;
using Microsoft.EntityFrameworkCore;

namespace App.Modules.Projects.Infrastructure;

public sealed class EfProjectRepository : IProjectRepository
{
    private readonly AppDbContext _dbContext;

    public EfProjectRepository(AppDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task AddAsync(Project project, CancellationToken cancellationToken)
    {
        await _dbContext.Projects.AddAsync(project, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public Task<Project?> GetByIdAsync(Guid organizationId, Guid projectId, CancellationToken cancellationToken)
    {
        return _dbContext.Projects.FirstOrDefaultAsync(project =>
            project.OrganizationId == organizationId && project.Id == projectId,
            cancellationToken);
    }

    public async Task<ProjectListResult> GetListAsync(ProjectListQuery query, CancellationToken cancellationToken)
    {
        var projects = _dbContext.Projects.Where(project => project.OrganizationId == query.OrganizationId);

        if (!string.IsNullOrWhiteSpace(query.Search))
            projects = projects.Where(project => project.Name.Contains(query.Search));

        if (query.Status is not null)
            projects = projects.Where(project => project.Status == query.Status.Value);

        var total = await projects.CountAsync(cancellationToken);
        var items = await projects
            .OrderByDescending(project => project.CreatedAt)
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToArrayAsync(cancellationToken);

        return new ProjectListResult(items, query.Page, query.PageSize, total);
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        return _dbContext.SaveChangesAsync(cancellationToken);
    }
}
```

### EfTaskRepository

```csharp
// File: ProjectManagement.Backend/src/Modules/Tasks/Infrastructure/EfTaskRepository.cs
using App.Infrastructure.Database;
using App.Modules.Tasks.Application.Abstractions;
using App.Modules.Tasks.Domain;
using Microsoft.EntityFrameworkCore;

namespace App.Modules.Tasks.Infrastructure;

public sealed class EfTaskRepository : ITaskRepository
{
    private readonly AppDbContext _dbContext;

    public EfTaskRepository(AppDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task AddAsync(TaskItem task, CancellationToken cancellationToken)
    {
        await _dbContext.Tasks.AddAsync(task, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public Task<TaskItem?> GetByIdAsync(Guid organizationId, Guid projectId, Guid taskId, CancellationToken cancellationToken)
    {
        return _dbContext.Tasks.FirstOrDefaultAsync(task =>
            task.OrganizationId == organizationId &&
            task.ProjectId == projectId &&
            task.Id == taskId,
            cancellationToken);
    }

    public async Task<TaskListResult> GetListAsync(TaskListQuery query, CancellationToken cancellationToken)
    {
        var tasks = _dbContext.Tasks.Where(task =>
            task.OrganizationId == query.OrganizationId &&
            task.ProjectId == query.ProjectId);

        if (!string.IsNullOrWhiteSpace(query.Search))
            tasks = tasks.Where(task => task.Title.Contains(query.Search));

        if (query.Status is not null)
            tasks = tasks.Where(task => task.Status == query.Status.Value);

        if (query.AssigneeUserId is not null)
            tasks = tasks.Where(task => task.AssigneeUserId == query.AssigneeUserId.Value);

        var total = await tasks.CountAsync(cancellationToken);
        var items = await tasks
            .OrderByDescending(task => task.CreatedAt)
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToArrayAsync(cancellationToken);

        return new TaskListResult(items, query.Page, query.PageSize, total);
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        return _dbContext.SaveChangesAsync(cancellationToken);
    }
}
```

## Infrastructure Dependency Injection

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/DependencyInjection.cs
using App.Infrastructure.Database;
using App.Modules.Identity.Application.Abstractions;
using App.Modules.Identity.Infrastructure;
using App.Modules.Organizations.Application.Abstractions;
using App.Modules.Organizations.Infrastructure;
using App.Modules.Projects.Application.Abstractions;
using App.Modules.Projects.Infrastructure;
using App.Modules.Tasks.Application.Abstractions;
using App.Modules.Tasks.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace App.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddAppInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string DefaultConnection belum dikonfigurasi.");

        services.AddDbContext<AppDbContext>(options =>
        {
            options.UseSqlite(connectionString);
        });

        services.AddScoped<IUserRepository, EfUserRepository>();
        services.AddScoped<IOrganizationRepository, EfOrganizationRepository>();
        services.AddScoped<IProjectRepository, EfProjectRepository>();
        services.AddScoped<ITaskRepository, EfTaskRepository>();

        return services;
    }
}
```

Panggil di API host:

```csharp
// File: ProjectManagement.Backend/src/ProjectManagement.Api/Program.cs
using App.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAppInfrastructure(builder.Configuration);
```

Catatan penting:

- Jika module sebelumnya masih mendaftarkan `InMemoryUserRepository`, ganti dengan repository EF Core.
- Jangan daftarkan dua implementasi untuk interface yang sama tanpa sengaja.

## Membuat Migration

Command migration:

```powershell
# File: ProjectManagement.Backend/commands/81-create-initial-migration.ps1
dotnet ef migrations add InitialCreate --project src/ProjectManagement.Api/ProjectManagement.Api.csproj --startup-project src/ProjectManagement.Api/ProjectManagement.Api.csproj --output-dir Infrastructure/Database/Migrations
```

Penjelasan:

- `migrations add InitialCreate` membuat migration pertama.
- `--project` menunjuk project tempat migration dibuat.
- `--startup-project` menunjuk project yang dipakai untuk membaca konfigurasi aplikasi.
- `--output-dir` menentukan folder output migration.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Build started...
Build succeeded.
Done. To undo this action, use 'ef migrations remove'
```

Apply migration ke database:

```powershell
# File: ProjectManagement.Backend/commands/82-update-database.ps1
dotnet ef database update --project src/ProjectManagement.Api/ProjectManagement.Api.csproj --startup-project src/ProjectManagement.Api/ProjectManagement.Api.csproj
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Applying migration 'InitialCreate'.
Done.
```

Setelah command ini, file SQLite `project-management.db` dibuat di working directory aplikasi.

## Database Seeder

Seeder membuat data awal untuk belajar.

Data yang dibuat:

- admin user;
- sample organization;
- owner membership;
- sample project;
- sample task.

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/Database/DatabaseSeeder.cs
using App.Modules.Identity.Domain;
using App.Modules.Organizations.Domain;
using App.Modules.Projects.Domain;
using App.Modules.Tasks.Domain;
using Microsoft.EntityFrameworkCore;

namespace App.Infrastructure.Database;

public sealed class DatabaseSeeder
{
    private readonly AppDbContext _dbContext;

    public DatabaseSeeder(AppDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task SeedAsync(CancellationToken cancellationToken = default)
    {
        if (await _dbContext.Users.AnyAsync(cancellationToken))
            return;

        var adminUserId = Guid.Parse("11111111-1111-1111-1111-111111111111");
        var organizationId = Guid.Parse("22222222-2222-2222-2222-222222222222");
        var projectId = Guid.Parse("33333333-3333-3333-3333-333333333333");

        var admin = User.Register(
            "Admin User",
            "admin@example.com",
            "seed-password-hash-change-after-password-hasher-integration",
            Role.Admin);

        var organization = Organization.Create(
            "Acme Studio",
            admin.Id,
            admin.Email);

        var project = Project.Create(
            organization.Id,
            admin.Id,
            "Website Redesign",
            "Sample project dari database seed.");

        var task = TaskItem.Create(
            organization.Id,
            project.Id,
            admin.Id,
            "Setup landing page",
            "Sample task dari database seed.",
            TaskPriority.High,
            DateTimeOffset.UtcNow.AddDays(14));

        await _dbContext.Users.AddAsync(admin, cancellationToken);
        await _dbContext.Organizations.AddAsync(organization, cancellationToken);
        await _dbContext.Projects.AddAsync(project, cancellationToken);
        await _dbContext.Tasks.AddAsync(task, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }
}
```

Catatan:

- Contoh di atas memakai `User.Register`, `Organization.Create`, `Project.Create`, dan `TaskItem.Create` agar seed tetap melewati domain rule.
- Password hash di seed harus disesuaikan dengan `PasswordHasher` dari file `03` jika ingin bisa login sebagai admin seed.

Daftarkan seeder:

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/DependencyInjection.cs
services.AddScoped<DatabaseSeeder>();
```

Jalankan seed saat development:

```csharp
// File: ProjectManagement.Backend/src/ProjectManagement.Api/Program.cs
using App.Infrastructure.Database;

if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var seeder = scope.ServiceProvider.GetRequiredService<DatabaseSeeder>();
    await seeder.SeedAsync();
}
```

## Reset Database Lokal

Untuk SQLite lokal, reset paling sederhana adalah hapus file database lalu apply migration ulang.

```powershell
# File: ProjectManagement.Backend/commands/83-reset-sqlite-database.ps1
Remove-Item project-management.db
dotnet ef database update --project src/ProjectManagement.Api/ProjectManagement.Api.csproj --startup-project src/ProjectManagement.Api/ProjectManagement.Api.csproj
```

Penjelasan:

- `Remove-Item project-management.db` menghapus file database SQLite.
- `dotnet ef database update` membuat ulang schema dari migration.
- Seeder akan mengisi ulang data saat aplikasi dijalankan di environment development.

Jika file database sedang dipakai, stop aplikasi dulu.

## Alternatif PostgreSQL

Install package PostgreSQL provider:

```powershell
# File: ProjectManagement.Backend/commands/84-add-postgresql-provider.ps1
dotnet add src/ProjectManagement.Api/ProjectManagement.Api.csproj package Npgsql.EntityFrameworkCore.PostgreSQL
```

Ganti provider di DI:

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/DependencyInjection.PostgreSql.example.cs
services.AddDbContext<AppDbContext>(options =>
{
    options.UseNpgsql(connectionString);
});
```

Connection string:

```json
// File: ProjectManagement.Backend/src/ProjectManagement.Api/appsettings.PostgreSql.example.json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=project_management;Username=postgres;Password=postgres"
  }
}
```

Gunakan PostgreSQL jika targetnya cloud/SaaS modern atau butuh database server production-friendly.

## Alternatif SQL Server

Install package SQL Server provider:

```powershell
# File: ProjectManagement.Backend/commands/85-add-sqlserver-provider.ps1
dotnet add src/ProjectManagement.Api/ProjectManagement.Api.csproj package Microsoft.EntityFrameworkCore.SqlServer
```

Ganti provider di DI:

```csharp
// File: ProjectManagement.Backend/src/Infrastructure/DependencyInjection.SqlServer.example.cs
services.AddDbContext<AppDbContext>(options =>
{
    options.UseSqlServer(connectionString);
});
```

Connection string:

```json
// File: ProjectManagement.Backend/src/ProjectManagement.Api/appsettings.SqlServer.example.json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=ProjectManagement;User Id=sa;Password=Your_password123;TrustServerCertificate=True"
  }
}
```

Gunakan SQL Server jika target enterprise Microsoft stack atau perusahaan sudah memakai SQL Server.

## Migration Workflow Harian

Saat entity/configuration berubah:

```powershell
# File: ProjectManagement.Backend/commands/86-add-new-migration.ps1
dotnet ef migrations add NamaPerubahanSchema --project src/ProjectManagement.Api/ProjectManagement.Api.csproj --startup-project src/ProjectManagement.Api/ProjectManagement.Api.csproj --output-dir Infrastructure/Database/Migrations
```

Lalu apply:

```powershell
# File: ProjectManagement.Backend/commands/87-apply-new-migration.ps1
dotnet ef database update --project src/ProjectManagement.Api/ProjectManagement.Api.csproj --startup-project src/ProjectManagement.Api/ProjectManagement.Api.csproj
```

Jika migration terakhir salah dan belum dipush:

```powershell
# File: ProjectManagement.Backend/commands/88-remove-last-migration.ps1
dotnet ef migrations remove --project src/ProjectManagement.Api/ProjectManagement.Api.csproj --startup-project src/ProjectManagement.Api/ProjectManagement.Api.csproj
```

Jangan sembarang menghapus migration yang sudah dipakai orang lain atau sudah jalan di environment bersama.

## Verifikasi Database

Build:

```powershell
# File: ProjectManagement.Backend/commands/89-build-database-setup.ps1
dotnet build
```

Lihat migration:

```powershell
# File: ProjectManagement.Backend/commands/90-list-migrations.ps1
dotnet ef migrations list --project src/ProjectManagement.Api/ProjectManagement.Api.csproj --startup-project src/ProjectManagement.Api/ProjectManagement.Api.csproj
```

Run aplikasi:

```powershell
# File: ProjectManagement.Backend/commands/91-run-api-with-database.ps1
dotnet run --project src/ProjectManagement.Api/ProjectManagement.Api.csproj
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Now listening on: http://localhost:5000
Application started. Press Ctrl+C to shut down.
```

## Tenant Isolation Di Database

Query tenant data wajib memfilter `OrganizationId`.

Contoh benar:

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Infrastructure/EfProjectRepository.cs
return _dbContext.Projects.FirstOrDefaultAsync(project =>
    project.OrganizationId == organizationId &&
    project.Id == projectId,
    cancellationToken);
```

Contoh salah:

```csharp
// File: ProjectManagement.Backend/src/Modules/Projects/Infrastructure/DoNotUseProjectQueryExample.cs
return _dbContext.Projects.FirstOrDefaultAsync(project =>
    project.Id == projectId,
    cancellationToken);
```

Contoh salah bisa membuat user dari organization lain membaca data hanya dengan menebak `projectId`.

## Troubleshooting

### `dotnet ef` Tidak Dikenali

Penyebab:

- EF tool belum diinstall;
- global tools path belum masuk PATH.

Solusi:

```powershell
# File: ProjectManagement.Backend/commands/troubleshoot-ef-tool.ps1
dotnet tool install --global dotnet-ef
dotnet ef --version
```

### `No DbContext was found`

Penyebab:

- `AppDbContext` belum dibuat;
- factory belum dibuat;
- command `--project` salah;
- project belum build.

Solusi:

```powershell
# File: ProjectManagement.Backend/commands/troubleshoot-no-dbcontext.ps1
dotnet build
dotnet ef dbcontext list --project src/ProjectManagement.Api/ProjectManagement.Api.csproj --startup-project src/ProjectManagement.Api/ProjectManagement.Api.csproj
```

### SQLite Database Locked

Penyebab:

- aplikasi masih berjalan;
- file database sedang dibuka tool lain.

Solusi:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/08-database-migration-seed.md
Stop aplikasi, tutup DB browser, lalu jalankan ulang migration/update database.
```

### Migration Berhasil Tapi Table Tidak Ada

Penyebab:

- connection string berbeda antara migration dan run app;
- database file dibuat di folder berbeda;
- provider berbeda.

Solusi:

```powershell
# File: ProjectManagement.Backend/commands/troubleshoot-database-location.ps1
dir *.db
dotnet ef database update --project src/ProjectManagement.Api/ProjectManagement.Api.csproj --startup-project src/ProjectManagement.Api/ProjectManagement.Api.csproj
```

### Entity Dengan Private Constructor Gagal Dimapping

Penyebab:

- EF Core tidak bisa materialize entity karena constructor/property terlalu tertutup;
- backing field belum dikonfigurasi.

Solusi awal untuk tutorial:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/08-database-migration-seed.md
Tambahkan private parameterless constructor pada entity, atau konfigurasi backing field dengan Fluent API.
Untuk pembelajaran awal, jaga entity tetap mudah dimapping dulu.
```

### Duplicate Configuration Untuk Entity Yang Sama

Penyebab:

- dua class configuration mengatur entity yang sama, misalnya `RoleConfiguration` dan `UserRoleConfiguration` sama-sama untuk `UserRole`.

Solusi:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/08-database-migration-seed.md
Pastikan satu entity hanya punya satu konfigurasi utama.
Jika butuh table Roles terpisah, buat entity RoleRecord khusus.
```

## Checklist Selesai

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/08-database-migration-seed.md
[ ] Package EF Core SQLite terinstall.
[ ] Connection string DefaultConnection tersedia.
[ ] AppDbContext dibuat.
[ ] AppDbContextFactory dibuat.
[ ] Entity configuration dibuat per module.
[ ] Repository EF menggantikan in-memory repository.
[ ] AddAppInfrastructure mendaftarkan DbContext dan repository EF.
[ ] Migration InitialCreate berhasil dibuat.
[ ] Database update berhasil dijalankan.
[ ] Seeder membuat admin/sample organization/project/task.
[ ] Query Projects dan Tasks selalu filter OrganizationId.
[ ] Reset database lokal terdokumentasi.
```

## Ringkasan

Alur persistence setelah EF Core:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/08-database-migration-seed.md
Endpoint
  -> Handler
  -> Repository interface
  -> EF Repository implementation
  -> AppDbContext
  -> SQLite/PostgreSQL/SQL Server
```

Migration flow:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/08-database-migration-seed.md
Ubah entity/configuration
  -> dotnet ef migrations add NamaMigration
  -> dotnet ef database update
  -> database schema berubah
```

Dengan file ini, module yang sebelumnya in-memory sudah punya jalur menuju database persistence tanpa mengorbankan boundary modular monolith.
