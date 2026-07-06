# 01 - Create Solution And Projects

Target: membuat solution yang punya batas project jelas.

## Command

```powershell
mkdir enterprise-task-workspace
cd enterprise-task-workspace
dotnet new sln -n EnterpriseTaskWorkspace

dotnet new webapi -n src/Workspace.Api
dotnet new classlib -n src/Workspace.SharedKernel
dotnet new classlib -n src/Modules/Tasks/Tasks.Domain
dotnet new classlib -n src/Modules/Tasks/Tasks.Application
dotnet new classlib -n src/Modules/Tasks/Tasks.Infrastructure

dotnet sln add src/Workspace.Api
dotnet sln add src/Workspace.SharedKernel
dotnet sln add src/Modules/Tasks/Tasks.Domain
dotnet sln add src/Modules/Tasks/Tasks.Application
dotnet sln add src/Modules/Tasks/Tasks.Infrastructure
```

## Reference Project

```powershell
dotnet add src/Modules/Tasks/Tasks.Domain reference src/Workspace.SharedKernel
dotnet add src/Modules/Tasks/Tasks.Application reference src/Workspace.SharedKernel
dotnet add src/Modules/Tasks/Tasks.Application reference src/Modules/Tasks/Tasks.Domain
dotnet add src/Modules/Tasks/Tasks.Infrastructure reference src/Workspace.SharedKernel
dotnet add src/Modules/Tasks/Tasks.Infrastructure reference src/Modules/Tasks/Tasks.Application
dotnet add src/Workspace.Api reference src/Workspace.SharedKernel
dotnet add src/Workspace.Api reference src/Modules/Tasks/Tasks.Application
dotnet add src/Workspace.Api reference src/Modules/Tasks/Tasks.Infrastructure
```

Aturan dependency:

```text
Api -> Application -> Domain -> SharedKernel
Api -> Infrastructure -> Application
Domain tidak boleh reference Infrastructure atau Api
```

## Package

```powershell
dotnet add src/Workspace.Api package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add src/Workspace.Api package Microsoft.EntityFrameworkCore.Design
dotnet add src/Workspace.Api package StackExchange.Redis
dotnet add src/Workspace.Api package Confluent.Kafka
dotnet add src/Modules/Tasks/Tasks.Infrastructure package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add src/Modules/Tasks/Tasks.Infrastructure package Microsoft.EntityFrameworkCore
```

## Project Web

```powershell
npm create vite@latest web/workspace-web -- --template react-ts
cd web/workspace-web
npm install
```

## Struktur Akhir

```text
enterprise-task-workspace/
  EnterpriseTaskWorkspace.sln
  src/
    Workspace.Api/
    Workspace.SharedKernel/
    Modules/
      Tasks/
        Tasks.Domain/
        Tasks.Application/
        Tasks.Infrastructure/
  web/
    workspace-web/
```

## Kenapa Perlu SharedKernel

SharedKernel adalah project kecil untuk contract lintas module:

- `Result<T>`;
- `ApiResponse<T>`;
- `AppError`;
- audit event;
- interface `IClock`, `IEventPublisher`.

SharedKernel bukan tempat menaruh logic task. Logic task tetap di module Tasks.
