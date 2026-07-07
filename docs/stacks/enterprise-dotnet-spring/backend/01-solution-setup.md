# Backend 01 - .NET Solution Setup

File ini menjelaskan cara membuat fondasi backend .NET dari folder kosong untuk Project Management App. Fokusnya adalah setup awal yang siap dikembangkan menjadi modular monolith dengan layered architecture.

Backend yang dibuat di tahap ini:

- Satu .NET solution sebagai workspace backend.
- Satu Web API project sebagai host aplikasi.
- Satu Shared Kernel class library.
- Beberapa module awal sebagai class library: `Identity`, `Organizations`, `Projects`, `Tasks`, dan `Audit`.
- Endpoint awal `/health` untuk memastikan aplikasi bisa dijalankan.

## Target Struktur Awal

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/01-solution-setup.md
ProjectManagement.Backend/
  ProjectManagement.Backend.sln
  src/
    ProjectManagement.Api/
      ProjectManagement.Api.csproj
      Program.cs
    Shared/
      ProjectManagement.SharedKernel/
        ProjectManagement.SharedKernel.csproj
        Api/
          ApiResponse.cs
    Modules/
      Identity/
        ProjectManagement.Identity.Domain/
        ProjectManagement.Identity.Application/
        ProjectManagement.Identity.Infrastructure/
        ProjectManagement.Identity.Api/
      Organizations/
        ProjectManagement.Organizations.Domain/
        ProjectManagement.Organizations.Application/
        ProjectManagement.Organizations.Infrastructure/
        ProjectManagement.Organizations.Api/
      Projects/
        ProjectManagement.Projects.Domain/
        ProjectManagement.Projects.Application/
        ProjectManagement.Projects.Infrastructure/
        ProjectManagement.Projects.Api/
      Tasks/
        ProjectManagement.Tasks.Domain/
        ProjectManagement.Tasks.Application/
        ProjectManagement.Tasks.Infrastructure/
        ProjectManagement.Tasks.Api/
      Audit/
        ProjectManagement.Audit.Domain/
        ProjectManagement.Audit.Application/
        ProjectManagement.Audit.Infrastructure/
        ProjectManagement.Audit.Api/
```

## Konsep Dasar

### Apa Itu .NET Solution

.NET solution adalah file `.sln` yang menjadi wadah beberapa project .NET. Solution bukan tempat menulis kode aplikasi. Ia berfungsi sebagai workspace agar command seperti `dotnet restore`, `dotnet build`, dan `dotnet test` bisa dijalankan dari satu root.

Di backend enterprise, solution membantu kita melihat batas antar project: API host, shared kernel, domain, application, infrastructure, dan test.

### Apa Itu Project

Project adalah unit build di .NET. Setiap project punya file `.csproj` yang menjelaskan target framework, package NuGet, project reference, dan cara project tersebut di-build.

Contoh project:

- `ProjectManagement.Api`: Web API yang dijalankan.
- `ProjectManagement.Tasks.Domain`: aturan bisnis task.
- `ProjectManagement.Tasks.Application`: use case task.
- `ProjectManagement.Tasks.Infrastructure`: database dan implementasi repository task.
- `ProjectManagement.Tasks.Api`: endpoint HTTP milik module task.

### Apa Itu Class Library

Class library adalah project yang menghasilkan DLL, bukan aplikasi yang dijalankan langsung. Class library cocok untuk domain, application, infrastructure, shared kernel, dan module API.

Dengan class library, dependency rule bisa dibuat lebih tegas. Misalnya domain tidak diberi reference ke infrastructure, sehingga domain tidak bisa memanggil database secara langsung.

### Apa Itu Web API Project

Web API project adalah project ASP.NET Core yang menjalankan HTTP server. Di tutorial ini, `ProjectManagement.Api` adalah host utama. Host ini membaca konfigurasi, mendaftarkan dependency injection, memasang middleware, dan memetakan endpoint dari module.

Walaupun module dipisah menjadi banyak class library, deployable app tetap satu. Itulah modular monolith.

### Apa Itu Module

Module adalah batas fitur bisnis. Untuk Project Management App, module awalnya:

- `Identity`: register, login, user, token.
- `Organizations`: tenant, membership, role, permission.
- `Projects`: CRUD project.
- `Tasks`: CRUD task, assign task, status task.
- `Audit`: audit log sederhana.

Module bukan sekadar folder. Module punya boundary sendiri: domain, use case, endpoint, data access, dan public contract jika perlu dipakai module lain.

### Apa Itu Package Dan NuGet

NuGet adalah package manager untuk .NET. Package adalah dependency eksternal, misalnya:

- `Microsoft.EntityFrameworkCore` untuk ORM.
- `Npgsql.EntityFrameworkCore.PostgreSQL` untuk PostgreSQL.
- `FluentValidation.DependencyInjectionExtensions` untuk validation.
- `Serilog.AspNetCore` untuk logging.
- `Microsoft.AspNetCore.Authentication.JwtBearer` untuk JWT.

Package ditambahkan ke project tertentu. EF Core dipasang di infrastructure, bukan domain. JWT middleware dipasang di API host, bukan domain.

## Kenapa Enterprise Backend Tidak Dibuat Hanya 1 Project

Satu project cukup untuk demo kecil. Untuk enterprise backend, satu project cepat membuat controller, DTO, query database, validation, authorization, dan business rule bercampur.

Masalah yang biasanya muncul:

- business logic bocor ke controller;
- domain entity bergantung ke ORM atau framework web;
- module task bisa mengakses data organization secara sembarang;
- perubahan kecil di satu fitur mudah merusak fitur lain;
- unit test sulit karena semua kode menempel ke web host dan database;
- developer baru sulit memahami alur request.

Karena itu, tutorial ini memakai banyak project class library. Struktur memang lebih panjang di awal, tetapi boundary lebih jelas dan cocok untuk aplikasi yang akan berkembang.

## Modular Monolith Dan Layered Architecture

Layer yang dipakai:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/01-solution-setup.md
Presentation/API layer
  -> Application layer
  -> Domain layer

Infrastructure layer
  -> Application layer
  -> Domain layer
```

Aturan dependency:

- API layer menerima HTTP request dan memanggil application use case.
- Application layer menjalankan workflow, validation, authorization, dan transaksi.
- Domain layer menyimpan aturan bisnis murni dan tidak bergantung ke framework.
- Infrastructure layer berisi database, repository implementation, email, storage, dan provider eksternal.
- Shared Kernel hanya berisi tipe lintas module yang kecil dan stabil.

## Membuat Solution Dari Folder Kosong

Mulai dari folder kosong bernama `ProjectManagement.Backend`.

```powershell
# File: ProjectManagement.Backend/commands/01-create-folder.ps1
mkdir ProjectManagement.Backend
cd ProjectManagement.Backend
```

Penjelasan:

- `mkdir ProjectManagement.Backend` membuat folder root backend.
- `cd ProjectManagement.Backend` masuk ke folder tersebut.
- Semua command berikutnya dijalankan dari folder root ini.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Directory: ...

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----                                      ProjectManagement.Backend
```

## Command `dotnet new sln`

```powershell
# File: ProjectManagement.Backend/commands/02-new-solution.ps1
dotnet new sln -n ProjectManagement.Backend
```

Penjelasan:

- `dotnet new sln` membuat file solution.
- `-n ProjectManagement.Backend` menentukan nama solution.
- Outputnya adalah `ProjectManagement.Backend.sln`.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
The template "Solution File" was created successfully.
```

Verifikasi:

```powershell
# File: ProjectManagement.Backend/commands/03-verify-solution.ps1
dir
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
ProjectManagement.Backend.sln
```

## Command `dotnet new webapi`

Buat folder `src`, lalu buat Web API project.

```powershell
# File: ProjectManagement.Backend/commands/04-new-webapi.ps1
mkdir src
dotnet new webapi -n ProjectManagement.Api -o src/ProjectManagement.Api
```

Penjelasan:

- `dotnet new webapi` membuat ASP.NET Core Web API project.
- `-n ProjectManagement.Api` menentukan nama project dan namespace default.
- `-o src/ProjectManagement.Api` menentukan folder output.

Jika CLI menanyakan pilihan:

- Framework: pilih versi LTS yang tersedia, misalnya `.NET 8`.
- Authentication: pilih `None` untuk setup awal. Auth dibuat bertahap di file berikutnya.
- HTTPS: boleh aktif, tetapi contoh test awal memakai HTTP agar sederhana.
- OpenAPI/Swagger: aktifkan karena membantu test endpoint.
- Controllers: tutorial ini memakai minimal API, jadi controller belum diperlukan.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
The template "ASP.NET Core Web API" was created successfully.
Processing post-creation actions...
Restore succeeded.
```

## Command `dotnet new classlib`

Buat Shared Kernel sebagai class library.

```powershell
# File: ProjectManagement.Backend/commands/05-new-shared-kernel.ps1
mkdir src/Shared
dotnet new classlib -n ProjectManagement.SharedKernel -o src/Shared/ProjectManagement.SharedKernel
```

Penjelasan:

- `dotnet new classlib` membuat project class library.
- `ProjectManagement.SharedKernel` tidak dijalankan langsung, tetapi dipakai oleh project lain.
- Shared Kernel berisi tipe lintas module seperti response envelope, result, dan error model.

Buat module awal sebagai class library.

```powershell
# File: ProjectManagement.Backend/commands/06-new-modules.ps1
mkdir src/Modules
mkdir src/Modules/Identity
mkdir src/Modules/Organizations
mkdir src/Modules/Projects
mkdir src/Modules/Tasks
mkdir src/Modules/Audit

dotnet new classlib -n ProjectManagement.Identity.Domain -o src/Modules/Identity/ProjectManagement.Identity.Domain
dotnet new classlib -n ProjectManagement.Identity.Application -o src/Modules/Identity/ProjectManagement.Identity.Application
dotnet new classlib -n ProjectManagement.Identity.Infrastructure -o src/Modules/Identity/ProjectManagement.Identity.Infrastructure
dotnet new classlib -n ProjectManagement.Identity.Api -o src/Modules/Identity/ProjectManagement.Identity.Api

dotnet new classlib -n ProjectManagement.Organizations.Domain -o src/Modules/Organizations/ProjectManagement.Organizations.Domain
dotnet new classlib -n ProjectManagement.Organizations.Application -o src/Modules/Organizations/ProjectManagement.Organizations.Application
dotnet new classlib -n ProjectManagement.Organizations.Infrastructure -o src/Modules/Organizations/ProjectManagement.Organizations.Infrastructure
dotnet new classlib -n ProjectManagement.Organizations.Api -o src/Modules/Organizations/ProjectManagement.Organizations.Api

dotnet new classlib -n ProjectManagement.Projects.Domain -o src/Modules/Projects/ProjectManagement.Projects.Domain
dotnet new classlib -n ProjectManagement.Projects.Application -o src/Modules/Projects/ProjectManagement.Projects.Application
dotnet new classlib -n ProjectManagement.Projects.Infrastructure -o src/Modules/Projects/ProjectManagement.Projects.Infrastructure
dotnet new classlib -n ProjectManagement.Projects.Api -o src/Modules/Projects/ProjectManagement.Projects.Api

dotnet new classlib -n ProjectManagement.Tasks.Domain -o src/Modules/Tasks/ProjectManagement.Tasks.Domain
dotnet new classlib -n ProjectManagement.Tasks.Application -o src/Modules/Tasks/ProjectManagement.Tasks.Application
dotnet new classlib -n ProjectManagement.Tasks.Infrastructure -o src/Modules/Tasks/ProjectManagement.Tasks.Infrastructure
dotnet new classlib -n ProjectManagement.Tasks.Api -o src/Modules/Tasks/ProjectManagement.Tasks.Api

dotnet new classlib -n ProjectManagement.Audit.Domain -o src/Modules/Audit/ProjectManagement.Audit.Domain
dotnet new classlib -n ProjectManagement.Audit.Application -o src/Modules/Audit/ProjectManagement.Audit.Application
dotnet new classlib -n ProjectManagement.Audit.Infrastructure -o src/Modules/Audit/ProjectManagement.Audit.Infrastructure
dotnet new classlib -n ProjectManagement.Audit.Api -o src/Modules/Audit/ProjectManagement.Audit.Api
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
The template "Class Library" was created successfully.
Restore succeeded.
```

## Command `dotnet sln add`

Project yang sudah dibuat perlu didaftarkan ke solution.

```powershell
# File: ProjectManagement.Backend/commands/07-add-projects-to-solution.ps1
dotnet sln add src/ProjectManagement.Api/ProjectManagement.Api.csproj
dotnet sln add src/Shared/ProjectManagement.SharedKernel/ProjectManagement.SharedKernel.csproj

dotnet sln add src/Modules/Identity/ProjectManagement.Identity.Domain/ProjectManagement.Identity.Domain.csproj
dotnet sln add src/Modules/Identity/ProjectManagement.Identity.Application/ProjectManagement.Identity.Application.csproj
dotnet sln add src/Modules/Identity/ProjectManagement.Identity.Infrastructure/ProjectManagement.Identity.Infrastructure.csproj
dotnet sln add src/Modules/Identity/ProjectManagement.Identity.Api/ProjectManagement.Identity.Api.csproj

dotnet sln add src/Modules/Organizations/ProjectManagement.Organizations.Domain/ProjectManagement.Organizations.Domain.csproj
dotnet sln add src/Modules/Organizations/ProjectManagement.Organizations.Application/ProjectManagement.Organizations.Application.csproj
dotnet sln add src/Modules/Organizations/ProjectManagement.Organizations.Infrastructure/ProjectManagement.Organizations.Infrastructure.csproj
dotnet sln add src/Modules/Organizations/ProjectManagement.Organizations.Api/ProjectManagement.Organizations.Api.csproj

dotnet sln add src/Modules/Projects/ProjectManagement.Projects.Domain/ProjectManagement.Projects.Domain.csproj
dotnet sln add src/Modules/Projects/ProjectManagement.Projects.Application/ProjectManagement.Projects.Application.csproj
dotnet sln add src/Modules/Projects/ProjectManagement.Projects.Infrastructure/ProjectManagement.Projects.Infrastructure.csproj
dotnet sln add src/Modules/Projects/ProjectManagement.Projects.Api/ProjectManagement.Projects.Api.csproj

dotnet sln add src/Modules/Tasks/ProjectManagement.Tasks.Domain/ProjectManagement.Tasks.Domain.csproj
dotnet sln add src/Modules/Tasks/ProjectManagement.Tasks.Application/ProjectManagement.Tasks.Application.csproj
dotnet sln add src/Modules/Tasks/ProjectManagement.Tasks.Infrastructure/ProjectManagement.Tasks.Infrastructure.csproj
dotnet sln add src/Modules/Tasks/ProjectManagement.Tasks.Api/ProjectManagement.Tasks.Api.csproj

dotnet sln add src/Modules/Audit/ProjectManagement.Audit.Domain/ProjectManagement.Audit.Domain.csproj
dotnet sln add src/Modules/Audit/ProjectManagement.Audit.Application/ProjectManagement.Audit.Application.csproj
dotnet sln add src/Modules/Audit/ProjectManagement.Audit.Infrastructure/ProjectManagement.Audit.Infrastructure.csproj
dotnet sln add src/Modules/Audit/ProjectManagement.Audit.Api/ProjectManagement.Audit.Api.csproj
```

Penjelasan:

- `dotnet sln add` menambahkan project ke solution.
- Project yang tidak masuk solution tidak ikut build saat menjalankan `dotnet build` dari root.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Project `src/ProjectManagement.Api/ProjectManagement.Api.csproj` added to the solution.
```

## Command `dotnet add reference`

Project reference menentukan arah dependency antar project.

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/01-solution-setup.md
Module.Api -> Module.Application -> Module.Domain
Module.Infrastructure -> Module.Application -> Module.Domain
ProjectManagement.Api -> Module.Api + Module.Infrastructure + SharedKernel
```

Tambahkan reference shared kernel ke API host.

```powershell
# File: ProjectManagement.Backend/commands/08-reference-shared.ps1
dotnet add src/ProjectManagement.Api/ProjectManagement.Api.csproj reference src/Shared/ProjectManagement.SharedKernel/ProjectManagement.SharedKernel.csproj
```

Contoh reference lengkap untuk module `Tasks`.

```powershell
# File: ProjectManagement.Backend/commands/09-reference-task-module.ps1
dotnet add src/Modules/Tasks/ProjectManagement.Tasks.Application/ProjectManagement.Tasks.Application.csproj reference src/Modules/Tasks/ProjectManagement.Tasks.Domain/ProjectManagement.Tasks.Domain.csproj
dotnet add src/Modules/Tasks/ProjectManagement.Tasks.Application/ProjectManagement.Tasks.Application.csproj reference src/Shared/ProjectManagement.SharedKernel/ProjectManagement.SharedKernel.csproj

dotnet add src/Modules/Tasks/ProjectManagement.Tasks.Infrastructure/ProjectManagement.Tasks.Infrastructure.csproj reference src/Modules/Tasks/ProjectManagement.Tasks.Application/ProjectManagement.Tasks.Application.csproj
dotnet add src/Modules/Tasks/ProjectManagement.Tasks.Infrastructure/ProjectManagement.Tasks.Infrastructure.csproj reference src/Modules/Tasks/ProjectManagement.Tasks.Domain/ProjectManagement.Tasks.Domain.csproj
dotnet add src/Modules/Tasks/ProjectManagement.Tasks.Infrastructure/ProjectManagement.Tasks.Infrastructure.csproj reference src/Shared/ProjectManagement.SharedKernel/ProjectManagement.SharedKernel.csproj

dotnet add src/Modules/Tasks/ProjectManagement.Tasks.Api/ProjectManagement.Tasks.Api.csproj reference src/Modules/Tasks/ProjectManagement.Tasks.Application/ProjectManagement.Tasks.Application.csproj
dotnet add src/Modules/Tasks/ProjectManagement.Tasks.Api/ProjectManagement.Tasks.Api.csproj reference src/Shared/ProjectManagement.SharedKernel/ProjectManagement.SharedKernel.csproj

dotnet add src/ProjectManagement.Api/ProjectManagement.Api.csproj reference src/Modules/Tasks/ProjectManagement.Tasks.Api/ProjectManagement.Tasks.Api.csproj
dotnet add src/ProjectManagement.Api/ProjectManagement.Api.csproj reference src/Modules/Tasks/ProjectManagement.Tasks.Infrastructure/ProjectManagement.Tasks.Infrastructure.csproj
```

Gunakan pola yang sama untuk module lain. Domain sengaja tidak diberi reference ke API atau infrastructure.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Reference `..\ProjectManagement.Tasks.Domain.csproj` added to the project.
```

## Command `dotnet add package`

NuGet package ditambahkan ke project yang membutuhkan, bukan ke seluruh solution.

```powershell
# File: ProjectManagement.Backend/commands/10-add-packages.ps1
dotnet add src/ProjectManagement.Api/ProjectManagement.Api.csproj package Serilog.AspNetCore
dotnet add src/ProjectManagement.Api/ProjectManagement.Api.csproj package Microsoft.AspNetCore.Authentication.JwtBearer

dotnet add src/Modules/Tasks/ProjectManagement.Tasks.Infrastructure/ProjectManagement.Tasks.Infrastructure.csproj package Microsoft.EntityFrameworkCore
dotnet add src/Modules/Tasks/ProjectManagement.Tasks.Infrastructure/ProjectManagement.Tasks.Infrastructure.csproj package Npgsql.EntityFrameworkCore.PostgreSQL

dotnet add src/Modules/Tasks/ProjectManagement.Tasks.Application/ProjectManagement.Tasks.Application.csproj package FluentValidation.DependencyInjectionExtensions
```

Penjelasan:

- `Serilog.AspNetCore` dipasang di API host karena logging berjalan di aplikasi utama.
- `Microsoft.AspNetCore.Authentication.JwtBearer` dipasang di API host karena middleware auth ada di host.
- `Microsoft.EntityFrameworkCore` dan `Npgsql.EntityFrameworkCore.PostgreSQL` dipasang di infrastructure karena database adalah detail teknis.
- `FluentValidation.DependencyInjectionExtensions` dipasang di application layer karena validasi input use case berada di application.

Jangan memasang EF Core di domain layer. Domain harus tetap bebas dari detail database.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
info : PackageReference for package 'Serilog.AspNetCore' added to file ...
info : Restored ...
```

## Minimal Shared Kernel

Buat folder `Api`, lalu buat file `ApiResponse.cs`.

```csharp
// File: ProjectManagement.Backend/src/Shared/ProjectManagement.SharedKernel/Api/ApiResponse.cs
namespace ProjectManagement.SharedKernel.Api;

public sealed record ApiResponse<TData>(
    bool Success,
    TData? Data,
    ApiError? Error,
    ResponseMeta? Meta = null)
{
    public static ApiResponse<TData> Ok(TData data, ResponseMeta? meta = null)
    {
        return new ApiResponse<TData>(
            Success: true,
            Data: data,
            Error: null,
            Meta: meta);
    }

    public static ApiResponse<TData> Fail(ApiError error, ResponseMeta? meta = null)
    {
        return new ApiResponse<TData>(
            Success: false,
            Data: default,
            Error: error,
            Meta: meta);
    }
}

public sealed record ApiError(
    string Code,
    string Message,
    object? Details = null);

public sealed record ResponseMeta(
    string? RequestId = null);
```

Penjelasan:

- `ApiResponse<TData>` memberi bentuk response yang konsisten.
- `Ok` dipakai untuk success response.
- `Fail` dipakai untuk error response.
- `ResponseMeta.RequestId` disiapkan untuk tracing request.

## Minimal `Program.cs`

Ganti isi `Program.cs` di project API dengan kode berikut.

```csharp
// File: ProjectManagement.Backend/src/ProjectManagement.Api/Program.cs
using ProjectManagement.SharedKernel.Api;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

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

app.Run();
```

Penjelasan:

- `WebApplication.CreateBuilder(args)` membuat builder untuk service, konfigurasi, dan logging.
- `AddEndpointsApiExplorer()` membuat minimal API bisa dibaca Swagger.
- `AddSwaggerGen()` mendaftarkan generator Swagger.
- `app.MapGet("/health", ...)` membuat endpoint health check sederhana.
- `ApiResponse<object>.Ok(...)` memakai response envelope dari Shared Kernel.
- `app.Run()` menjalankan server.

Endpoint `/health` hanya mengecek apakah host API, reference ke Shared Kernel, dan build sudah benar.

## Contoh Isi `.csproj`

File `.csproj` API kurang lebih akan terlihat seperti ini setelah package dan reference ditambahkan.

```xml
<!-- File: ProjectManagement.Backend/src/ProjectManagement.Api/ProjectManagement.Api.csproj -->
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="8.0.0" />
    <PackageReference Include="Serilog.AspNetCore" Version="8.0.0" />
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.6.2" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\Shared\ProjectManagement.SharedKernel\ProjectManagement.SharedKernel.csproj" />
    <ProjectReference Include="..\Modules\Tasks\ProjectManagement.Tasks.Api\ProjectManagement.Tasks.Api.csproj" />
    <ProjectReference Include="..\Modules\Tasks\ProjectManagement.Tasks.Infrastructure\ProjectManagement.Tasks.Infrastructure.csproj" />
  </ItemGroup>
</Project>
```

Catatan:

- Versi package bisa berbeda tergantung SDK dan waktu instalasi.
- Lebih aman menambah package lewat `dotnet add package` daripada mengedit `.csproj` manual.
- `.csproj` ditampilkan agar pembaca paham hasil dari command.

## Restore, Build, Dan Run

Restore dependency:

```powershell
# File: ProjectManagement.Backend/commands/11-restore.ps1
dotnet restore
```

Penjelasan:

- `dotnet restore` mengunduh package NuGet yang dibutuhkan semua project di solution.
- Command ini biasanya otomatis dipanggil oleh `dotnet build`, tetapi baik untuk verifikasi awal.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Determining projects to restore...
Restored ... ProjectManagement.Api.csproj
Restore succeeded.
```

Build solution:

```powershell
# File: ProjectManagement.Backend/commands/12-build.ps1
dotnet build
```

Penjelasan:

- `dotnet build` meng-compile semua project di solution.
- Jika project reference salah, namespace tidak cocok, atau package hilang, error muncul di tahap ini.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

Run API:

```powershell
# File: ProjectManagement.Backend/commands/13-run-api.ps1
dotnet run --project src/ProjectManagement.Api/ProjectManagement.Api.csproj
```

Penjelasan:

- `dotnet run --project` menjalankan project tertentu.
- Solution berisi banyak class library, jadi kita harus menunjuk Web API project yang menjadi host.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://localhost:5000
info: Microsoft.Hosting.Lifetime[0]
      Application started. Press Ctrl+C to shut down.
```

Port bisa berbeda, misalnya `http://localhost:5142` atau `https://localhost:7142`. Gunakan port yang muncul di terminal.

## Test Dengan Browser

Buka URL berikut di browser:

```text
# File: ProjectManagement.Backend/commands/14-test-browser.txt
http://localhost:5000/health
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-health-response.json
{
  "success": true,
  "data": {
    "service": "ProjectManagement.Api",
    "status": "Healthy",
    "checkedAt": "2026-07-07T10:00:00.0000000+00:00"
  },
  "error": null,
  "meta": null
}
```

Nilai `checkedAt` akan berbeda di mesin masing-masing.

## Test Dengan Curl

```powershell
# File: ProjectManagement.Backend/commands/15-test-health-curl.ps1
curl http://localhost:5000/health
```

Jika port dari `dotnet run` bukan `5000`, ganti URL sesuai port yang muncul di terminal.

Expected output:

```json
// File: ProjectManagement.Backend/commands/expected-health-response.json
{
  "success": true,
  "data": {
    "service": "ProjectManagement.Api",
    "status": "Healthy",
    "checkedAt": "2026-07-07T10:00:00.0000000+00:00"
  },
  "error": null,
  "meta": null
}
```

## Command Verifikasi

Lihat daftar project di solution.

```powershell
# File: ProjectManagement.Backend/commands/16-verify-solution-projects.ps1
dotnet sln list
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Project(s)
----------
src/ProjectManagement.Api/ProjectManagement.Api.csproj
src/Shared/ProjectManagement.SharedKernel/ProjectManagement.SharedKernel.csproj
src/Modules/Tasks/ProjectManagement.Tasks.Domain/ProjectManagement.Tasks.Domain.csproj
src/Modules/Tasks/ProjectManagement.Tasks.Application/ProjectManagement.Tasks.Application.csproj
src/Modules/Tasks/ProjectManagement.Tasks.Infrastructure/ProjectManagement.Tasks.Infrastructure.csproj
src/Modules/Tasks/ProjectManagement.Tasks.Api/ProjectManagement.Tasks.Api.csproj
```

Lihat reference project API.

```powershell
# File: ProjectManagement.Backend/commands/17-verify-api-references.ps1
dotnet list src/ProjectManagement.Api/ProjectManagement.Api.csproj reference
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Project reference(s)
--------------------
..\Shared\ProjectManagement.SharedKernel\ProjectManagement.SharedKernel.csproj
..\Modules\Tasks\ProjectManagement.Tasks.Api\ProjectManagement.Tasks.Api.csproj
..\Modules\Tasks\ProjectManagement.Tasks.Infrastructure\ProjectManagement.Tasks.Infrastructure.csproj
```

Lihat package project API.

```powershell
# File: ProjectManagement.Backend/commands/18-verify-api-packages.ps1
dotnet list src/ProjectManagement.Api/ProjectManagement.Api.csproj package
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Project 'ProjectManagement.Api' has the following package references
   [net8.0]:
   Top-level Package                                  Requested   Resolved
   > Microsoft.AspNetCore.Authentication.JwtBearer    8.0.0       8.0.0
   > Serilog.AspNetCore                               8.0.0       8.0.0
```

## Troubleshooting Umum

### `dotnet` Tidak Dikenali

Penyebab:

- .NET SDK belum terinstall.
- PATH belum mengenali lokasi SDK.

Cek dengan command berikut.

```powershell
# File: ProjectManagement.Backend/commands/troubleshoot-01-dotnet-info.ps1
dotnet --info
```

Jika command gagal, install .NET SDK LTS, lalu buka terminal baru.

### Project File Tidak Ditemukan

Contoh error:

```text
# File: ProjectManagement.Backend/commands/troubleshoot-project-not-found.txt
MSBUILD : error MSB1009: Project file does not exist.
```

Penyebab umum:

- path `.csproj` salah;
- command dijalankan dari folder yang berbeda;
- project belum dibuat.

Cek struktur dan daftar project.

```powershell
# File: ProjectManagement.Backend/commands/troubleshoot-02-project-path.ps1
dir src/ProjectManagement.Api
dotnet sln list
```

### Package Tidak Bisa Diunduh

Penyebab umum:

- koneksi internet bermasalah;
- NuGet source tidak aktif;
- nama package salah.

Cek source NuGet dan restore ulang.

```powershell
# File: ProjectManagement.Backend/commands/troubleshoot-03-nuget.ps1
dotnet nuget list source
dotnet restore
```

Pastikan source `nuget.org` aktif.

### Namespace Tidak Ditemukan

Contoh error:

```text
# File: ProjectManagement.Backend/commands/troubleshoot-namespace-error.txt
error CS0246: The type or namespace name 'ProjectManagement' could not be found
```

Penyebab umum:

- project reference belum ditambahkan;
- namespace di `using` tidak sesuai;
- file belum disimpan;
- project belum masuk solution.

Cek reference dan build ulang.

```powershell
# File: ProjectManagement.Backend/commands/troubleshoot-04-reference.ps1
dotnet list src/ProjectManagement.Api/ProjectManagement.Api.csproj reference
dotnet build
```

### Port Sudah Dipakai

Contoh error:

```text
# File: ProjectManagement.Backend/commands/troubleshoot-port-error.txt
Failed to bind to address http://127.0.0.1:5000: address already in use.
```

Jalankan API di port lain.

```powershell
# File: ProjectManagement.Backend/commands/troubleshoot-05-custom-port.ps1
dotnet run --project src/ProjectManagement.Api/ProjectManagement.Api.csproj --urls http://localhost:5010
```

Lalu test:

```powershell
# File: ProjectManagement.Backend/commands/troubleshoot-06-test-custom-port.ps1
curl http://localhost:5010/health
```

### HTTPS Certificate Error

Untuk tutorial awal, gunakan HTTP dulu.

```powershell
# File: ProjectManagement.Backend/commands/troubleshoot-07-http-only.ps1
dotnet run --project src/ProjectManagement.Api/ProjectManagement.Api.csproj --urls http://localhost:5000
```

Jika ingin memakai HTTPS development certificate:

```powershell
# File: ProjectManagement.Backend/commands/troubleshoot-08-dev-cert.ps1
dotnet dev-certs https --trust
```

### Swagger Tidak Muncul

Penyebab umum:

- environment bukan `Development`;
- package Swagger belum ada;
- `UseSwagger()` belum dipanggil.

Jalankan dengan environment development.

```powershell
# File: ProjectManagement.Backend/commands/troubleshoot-09-swagger.ps1
$env:ASPNETCORE_ENVIRONMENT = "Development"
dotnet run --project src/ProjectManagement.Api/ProjectManagement.Api.csproj
```

Buka Swagger:

```text
# File: ProjectManagement.Backend/commands/troubleshoot-swagger-url.txt
http://localhost:5000/swagger
```

## Checklist Selesai

Setup dianggap selesai jika:

- `ProjectManagement.Backend.sln` sudah ada.
- `ProjectManagement.Api` sudah masuk solution.
- `ProjectManagement.SharedKernel` sudah masuk solution.
- Module awal sudah dibuat sebagai class library.
- Project reference mengikuti dependency rule.
- Package NuGet ditambahkan ke project yang tepat.
- `dotnet restore` berhasil.
- `dotnet build` berhasil.
- `dotnet run --project src/ProjectManagement.Api/ProjectManagement.Api.csproj` berhasil.
- `GET /health` mengembalikan `success: true`.

Setelah fondasi ini selesai, file berikutnya bisa masuk ke detail modular monolith dan layer per module.
