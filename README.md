# Tutorial Full Stack C#: ASP.NET Core Modular Monolith + Blazor + Bootstrap

Branch ini adalah mockup tutorial lengkap untuk membangun aplikasi helpdesk dari backend sampai frontend memakai ekosistem .NET yang populer. Backend memakai pola modular monolith agar mudah dikembangkan tanpa kompleksitas microservices sejak awal.

Stack utama:
- Backend: ASP.NET Core Web API modular monolith
- Frontend: Blazor WebAssembly
- Database: PostgreSQL, Entity Framework Core
- UI framework: Bootstrap 5
- Validation: FluentValidation
- Testing: xUnit, WebApplicationFactory, bUnit

Contoh fitur akhir:
- CRUD ticket helpdesk
- Status workflow: Open, InProgress, Resolved, Closed
- Assignment ticket ke agent
- API REST dengan DTO dan validation
- Blazor dashboard, tabel ticket, form create, dan detail page

## 1. Prasyarat

```bash
dotnet --info
docker --version
```

Versi yang disarankan:
- .NET SDK 9 atau versi LTS terbaru yang dipakai tim
- Docker Desktop
- PostgreSQL 16

Install tool EF Core:

```bash
dotnet tool install --global dotnet-ef
```

## 2. Buat Solution

```bash
mkdir blazor-helpdesk
cd blazor-helpdesk
dotnet new sln -n Helpdesk
mkdir src tests
```

Buat project:

```bash
dotnet new webapi -n Helpdesk.Api -o src/Helpdesk.Api
dotnet new classlib -n Helpdesk.Modules.Tickets -o src/Helpdesk.Modules.Tickets
dotnet new classlib -n Helpdesk.SharedKernel -o src/Helpdesk.SharedKernel
dotnet new blazorwasm -n Helpdesk.Web -o src/Helpdesk.Web
dotnet new xunit -n Helpdesk.Tests -o tests/Helpdesk.Tests
```

Tambahkan ke solution:

```bash
dotnet sln add src/Helpdesk.Api src/Helpdesk.Modules.Tickets src/Helpdesk.SharedKernel src/Helpdesk.Web tests/Helpdesk.Tests
```

Reference:

```bash
dotnet add src/Helpdesk.Api reference src/Helpdesk.Modules.Tickets src/Helpdesk.SharedKernel
dotnet add src/Helpdesk.Modules.Tickets reference src/Helpdesk.SharedKernel
dotnet add tests/Helpdesk.Tests reference src/Helpdesk.Api src/Helpdesk.Modules.Tickets
```

## 3. Database PostgreSQL

Buat `docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: blazor_helpdesk_db
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app_secret
      POSTGRES_DB: helpdesk_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d helpdesk_db"]
      interval: 5s
      timeout: 3s
      retries: 10

volumes:
  postgres_data:
```

Jalankan:

```bash
docker compose up -d
```

Praktik database yang baik:
- Simpan status ticket sebagai enum yang jelas dan tervalidasi di aplikasi.
- Gunakan migration EF Core, jangan ubah tabel manual tanpa migration.
- Tambahkan index untuk `Status`, `AssigneeId`, dan `CreatedAt`.
- Gunakan optimistic concurrency untuk mencegah update ticket saling menimpa.
- Simpan event penting seperti perubahan status ke tabel audit bila butuh compliance.
- Pisahkan read model hanya jika query dashboard mulai berat.

## 4. Paket NuGet

Backend:

```bash
dotnet add src/Helpdesk.Api package Microsoft.EntityFrameworkCore.Design
dotnet add src/Helpdesk.Modules.Tickets package Microsoft.EntityFrameworkCore
dotnet add src/Helpdesk.Modules.Tickets package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add src/Helpdesk.Modules.Tickets package FluentValidation
dotnet add src/Helpdesk.Api package FluentValidation.AspNetCore
```

Frontend:

```bash
dotnet add src/Helpdesk.Web package Microsoft.AspNetCore.Components.WebAssembly.Http
```

Testing:

```bash
dotnet add tests/Helpdesk.Tests package Microsoft.AspNetCore.Mvc.Testing
dotnet add tests/Helpdesk.Tests package bunit
```

## 5. Backend Modular Monolith

Modular monolith berarti backend tetap satu aplikasi deployable, tetapi setiap fitur besar dipisah sebagai modul. Untuk tutorial ini modul utama adalah `Tickets`.

Struktur target:

```text
src/
  Helpdesk.Api/
    Program.cs
    Endpoints/
  Helpdesk.Modules.Tickets/
    Application/
      CreateTicket/
      AssignTicket/
      ResolveTicket/
    Domain/
      Ticket.cs
      TicketStatus.cs
      TicketPriority.cs
    Infrastructure/
      TicketsDbContext.cs
      TicketRepository.cs
    Contracts/
      TicketResponse.cs
      CreateTicketRequest.cs
    TicketsModule.cs
  Helpdesk.SharedKernel/
    Entity.cs
    Result.cs
    Clock.cs
```

Aturan modular monolith:
- `Domain` tidak bergantung ke EF Core, API, atau Blazor.
- `Application` berisi use case dan validasi bisnis.
- `Infrastructure` berisi EF Core DbContext dan repository.
- `Contracts` berisi request dan response yang aman dipakai API.
- `Helpdesk.Api` hanya composition root: register service dan map endpoint.
- Modul lain tidak boleh mengakses DbContext Tickets secara langsung.

Entity domain `Ticket.cs`:

```csharp
namespace Helpdesk.Modules.Tickets.Domain;

public sealed class Ticket
{
    public Guid Id { get; private set; } = Guid.NewGuid();
    public string Title { get; private set; } = string.Empty;
    public string Description { get; private set; } = string.Empty;
    public TicketStatus Status { get; private set; } = TicketStatus.Open;
    public TicketPriority Priority { get; private set; } = TicketPriority.Medium;
    public Guid? AssigneeId { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; private set; } = DateTimeOffset.UtcNow;

    private Ticket() { }

    public static Ticket Create(string title, string description, TicketPriority priority)
    {
        if (string.IsNullOrWhiteSpace(title)) throw new ArgumentException("Title is required");
        return new Ticket { Title = title.Trim(), Description = description.Trim(), Priority = priority };
    }

    public void AssignTo(Guid agentId)
    {
        AssigneeId = agentId;
        Status = TicketStatus.InProgress;
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    public void Resolve()
    {
        Status = TicketStatus.Resolved;
        UpdatedAt = DateTimeOffset.UtcNow;
    }
}
```

DbContext:

```csharp
using Helpdesk.Modules.Tickets.Domain;
using Microsoft.EntityFrameworkCore;

namespace Helpdesk.Modules.Tickets.Infrastructure;

public sealed class TicketsDbContext(DbContextOptions<TicketsDbContext> options) : DbContext(options)
{
    public DbSet<Ticket> Tickets => Set<Ticket>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Ticket>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Title).HasMaxLength(160).IsRequired();
            entity.Property(x => x.Description).HasMaxLength(4000).IsRequired();
            entity.Property(x => x.Status).HasConversion<string>().HasMaxLength(32);
            entity.Property(x => x.Priority).HasConversion<string>().HasMaxLength(32);
            entity.HasIndex(x => x.Status);
            entity.HasIndex(x => x.AssigneeId);
            entity.HasIndex(x => x.CreatedAt);
        });
    }
}
```

Module registration:

```csharp
using Helpdesk.Modules.Tickets.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Helpdesk.Modules.Tickets;

public static class TicketsModule
{
    public static IServiceCollection AddTicketsModule(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<TicketsDbContext>(options =>
            options.UseNpgsql(configuration.GetConnectionString("Helpdesk")));

        services.AddScoped<TicketRepository>();
        services.AddScoped<CreateTicketHandler>();
        return services;
    }
}
```

`appsettings.Development.json`:

```json
{
  "ConnectionStrings": {
    "Helpdesk": "Host=localhost;Port=5432;Database=helpdesk_db;Username=app;Password=app_secret"
  }
}
```

Migration:

```bash
dotnet ef migrations add InitTickets --project src/Helpdesk.Modules.Tickets --startup-project src/Helpdesk.Api --context TicketsDbContext
dotnet ef database update --project src/Helpdesk.Modules.Tickets --startup-project src/Helpdesk.Api --context TicketsDbContext
```

Log yang diharapkan:

```text
Build succeeded.
Applying migration '20260706090000_InitTickets'.
Done.
```

## 6. API Endpoints

Di `Program.cs`:

```csharp
using Helpdesk.Modules.Tickets;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddTicketsModule(builder.Configuration);
builder.Services.AddCors(options => options.AddDefaultPolicy(policy =>
    policy.WithOrigins("https://localhost:7162", "http://localhost:5162")
          .AllowAnyHeader()
          .AllowAnyMethod()));

var app = builder.Build();

app.UseCors();
app.MapTicketEndpoints();
app.Run();

public partial class Program { }
```

Endpoint extension:

```csharp
public static class TicketEndpoints
{
    public static IEndpointRouteBuilder MapTicketEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/tickets").WithTags("Tickets");

        group.MapGet("/", async (TicketRepository repository) =>
            Results.Ok(await repository.ListAsync()));

        group.MapPost("/", async (CreateTicketRequest request, CreateTicketHandler handler) =>
        {
            var result = await handler.HandleAsync(request);
            return Results.Created($"/api/tickets/{result.Id}", result);
        });

        return app;
    }
}
```

## 7. Frontend Blazor WebAssembly

Struktur frontend:

```text
src/Helpdesk.Web/
  Pages/
    Tickets.razor
    TicketDetail.razor
  Services/
    TicketsApiClient.cs
  Models/
    TicketDto.cs
```

API client:

```csharp
using System.Net.Http.Json;

namespace Helpdesk.Web.Services;

public sealed class TicketsApiClient(HttpClient httpClient)
{
    public async Task<IReadOnlyList<TicketDto>> GetTicketsAsync()
    {
        return await httpClient.GetFromJsonAsync<IReadOnlyList<TicketDto>>("api/tickets") ?? [];
    }

    public async Task<TicketDto?> CreateTicketAsync(CreateTicketRequest request)
    {
        var response = await httpClient.PostAsJsonAsync("api/tickets", request);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<TicketDto>();
    }
}
```

Register di `Program.cs` Blazor:

```csharp
builder.Services.AddScoped(sp => new HttpClient { BaseAddress = new Uri("https://localhost:7050/") });
builder.Services.AddScoped<TicketsApiClient>();
```

Halaman `Tickets.razor` dengan Bootstrap:

```razor
@page "/tickets"
@inject TicketsApiClient TicketsApi

<div class="container py-4">
    <div class="d-flex align-items-center justify-content-between mb-3">
        <h1 class="h3 mb-0">Tickets</h1>
        <button class="btn btn-primary">New Ticket</button>
    </div>

    <div class="card">
        <div class="table-responsive">
            <table class="table table-hover align-middle mb-0">
                <thead class="table-light">
                    <tr>
                        <th>Title</th>
                        <th>Status</th>
                        <th>Priority</th>
                        <th>Created</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach (var ticket in tickets)
                    {
                        <tr>
                            <td>@ticket.Title</td>
                            <td><span class="badge text-bg-secondary">@ticket.Status</span></td>
                            <td>@ticket.Priority</td>
                            <td>@ticket.CreatedAt.ToLocalTime().ToString("yyyy-MM-dd HH:mm")</td>
                        </tr>
                    }
                </tbody>
            </table>
        </div>
    </div>
</div>

@code {
    private IReadOnlyList<TicketDto> tickets = [];

    protected override async Task OnInitializedAsync()
    {
        tickets = await TicketsApi.GetTicketsAsync();
    }
}
```

## 8. Test

Unit test domain:

```csharp
public sealed class TicketTests
{
    [Fact]
    public void Create_Should_Open_Ticket()
    {
        var ticket = Ticket.Create("Cannot login", "User cannot login", TicketPriority.High);

        Assert.Equal(TicketStatus.Open, ticket.Status);
        Assert.Equal(TicketPriority.High, ticket.Priority);
    }
}
```

API integration test:

```csharp
public sealed class TicketApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public TicketApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetTickets_Should_ReturnSuccess()
    {
        var response = await _client.GetAsync("/api/tickets");
        response.EnsureSuccessStatusCode();
    }
}
```

Run:

```bash
dotnet test
```

Log sukses contoh:

```text
Passed!  - Failed: 0, Passed: 6, Skipped: 0
```

## 9. Run Full Stack

Terminal 1:

```bash
docker compose up -d
```

Terminal 2:

```bash
dotnet run --project src/Helpdesk.Api
```

Terminal 3:

```bash
dotnet run --project src/Helpdesk.Web
```

URL:
- API: https://localhost:7050/api/tickets
- Web: https://localhost:7162/tickets

## 10. Checklist Produksi

- Tambahkan authentication dan authorization policy.
- Tambahkan audit trail untuk assignment dan status change.
- Gunakan migration bundle atau pipeline migration saat deploy.
- Tambahkan health check untuk database.
- Tambahkan structured logging dengan Serilog.
- Tambahkan OpenAPI dan versioning jika API dipakai banyak client.
- Pisahkan module database schema bila domain bertambah besar.

## 11. Commit Log Mockup

```bash
git commit -m "docs: scaffold blazor modular monolith tutorial"
git commit -m "docs: add ef core postgres setup"
git commit -m "docs: add ticket module backend flow"
git commit -m "docs: add blazor bootstrap frontend flow"
git commit -m "docs: add testing and production checklist"
```
