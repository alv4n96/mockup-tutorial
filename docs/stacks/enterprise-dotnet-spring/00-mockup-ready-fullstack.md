# 00 - Mockup Ready Full Stack .NET + React

Dokumen ini membuat mockup enterprise task workspace yang bisa jalan lokal. Jalur runnable yang dipilih adalah `.NET Minimal API + PostgreSQL + React`. Spring Boot tetap didokumentasikan di blueprint lain, tetapi untuk mockup cepat satu dokumen ini memakai .NET agar backend bisa dibuat ringkas tanpa mengurangi pola enterprise: auth mock, audit log, monitoring, Redis, Kafka/Redpanda, Grafana, AI summary mock, dan MCP-style tool registry.

## Hasil Akhir

```text
Workspace.Api
  .NET Minimal API
  EF Core + PostgreSQL
  Redis cache
  Kafka/Redpanda event publisher
  Audit log table
  Health/ready/metrics
  AI summary mock
  MCP-style tool registry

workspace-web
  React + Vite
  Task form
  Task list
  AI summary
  Audit log panel
```

## 1. Buat Project

```powershell
mkdir enterprise-task-workspace
cd enterprise-task-workspace
dotnet new webapi -n Workspace.Api
npm create vite@latest workspace-web -- --template react-ts
```

Install package backend:

```powershell
cd Workspace.Api
dotnet add package Microsoft.EntityFrameworkCore.Design
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add package StackExchange.Redis
dotnet add package Confluent.Kafka
```

## 2. Docker Services

Buat `docker-compose.yml` di root `enterprise-task-workspace`:

```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app
      POSTGRES_DB: task_workspace
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7
    ports:
      - "6379:6379"

  redpanda:
    image: redpandadata/redpanda:v24.1.7
    command:
      - redpanda
      - start
      - --overprovisioned
      - --smp
      - "1"
      - --memory
      - 512M
      - --reserve-memory
      - 0M
      - --node-id
      - "0"
      - --check=false
      - --kafka-addr
      - PLAINTEXT://0.0.0.0:9092
      - --advertise-kafka-addr
      - PLAINTEXT://localhost:9092
    ports:
      - "9092:9092"
      - "9644:9644"

  prometheus:
    image: prom/prometheus:v2.53.0
    ports:
      - "9090:9090"
    volumes:
      - ./ops/prometheus.yml:/etc/prometheus/prometheus.yml:ro

  grafana:
    image: grafana/grafana:11.1.0
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
    ports:
      - "3001:3000"
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  postgres_data:
  grafana_data:
```

Buat `ops/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: dotnet-api
    metrics_path: /metrics
    static_configs:
      - targets:
          - host.docker.internal:8080
```

Jalankan:

```powershell
docker compose up -d
```

## 3. Backend Config - `Workspace.Api/appsettings.Development.json`

```json
{
  "ConnectionStrings": {
    "Default": "Host=localhost;Port=5432;Database=task_workspace;Username=app;Password=app"
  },
  "Redis": {
    "Url": "localhost:6379"
  },
  "Kafka": {
    "BootstrapServers": "localhost:9092"
  },
  "Demo": {
    "UserId": "user_owner",
    "OrganizationId": "org_demo"
  }
}
```

## 4. Backend - `Workspace.Api/Program.cs`

Ganti isi `Program.cs`:

```csharp
using System.Text.Json;
using Confluent.Kafka;
using Microsoft.EntityFrameworkCore;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.WithOrigins("http://localhost:5173")
            .AllowAnyHeader()
            .AllowAnyMethod());
});

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddSingleton(sp =>
{
    var redisUrl = builder.Configuration["Redis:Url"];
    return string.IsNullOrWhiteSpace(redisUrl)
        ? null
        : ConnectionMultiplexer.Connect(redisUrl);
});

builder.Services.AddSingleton(sp =>
{
    var bootstrapServers = builder.Configuration["Kafka:BootstrapServers"];
    if (string.IsNullOrWhiteSpace(bootstrapServers)) return null;

    return new ProducerBuilder<string, string>(
        new ProducerConfig { BootstrapServers = bootstrapServers }
    ).Build();
});

builder.Services.AddScoped<AuditWriter>();
builder.Services.AddScoped<AiAssistant>();

var app = builder.Build();

app.UseCors();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();
    SeedData.EnsureSeeded(db);
}

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

app.MapGet("/ready", async (AppDbContext db, ConnectionMultiplexer? redis) =>
{
    var checks = new Dictionary<string, string>();

    try
    {
        await db.Database.ExecuteSqlRawAsync("select 1");
        checks["database"] = "ok";
    }
    catch
    {
        checks["database"] = "down";
    }

    try
    {
        checks["redis"] = redis is null
            ? "disabled"
            : (await redis.GetDatabase().PingAsync()).TotalMilliseconds >= 0
                ? "ok"
                : "down";
    }
    catch
    {
        checks["redis"] = "down";
    }

    return Results.Ok(new { status = "ok", checks });
});

app.MapGet("/metrics", () => Results.Text("app_mockup_info 1\n", "text/plain"));

app.MapGet("/api/tasks", async (
    HttpRequest request,
    AppDbContext db,
    ConnectionMultiplexer? redis) =>
{
    var user = DemoUser.FromRequest(request, app.Configuration);
    var cacheKey = $"task:list:{user.OrganizationId}";

    if (redis is not null)
    {
        var cached = await redis.GetDatabase().StringGetAsync(cacheKey);
        if (cached.HasValue)
        {
            return Results.Ok(JsonSerializer.Deserialize<List<TaskItem>>(cached.ToString()));
        }
    }

    var tasks = await db.Tasks
        .Where(task => task.OrganizationId == user.OrganizationId)
        .OrderByDescending(task => task.CreatedAt)
        .ToListAsync();

    if (redis is not null)
    {
        await redis.GetDatabase().StringSetAsync(
            cacheKey,
            JsonSerializer.Serialize(tasks),
            TimeSpan.FromSeconds(30)
        );
    }

    return Results.Ok(tasks);
});

app.MapPost("/api/tasks", async (
    HttpRequest request,
    CreateTaskRequest body,
    AppDbContext db,
    ConnectionMultiplexer? redis,
    IProducer<string, string>? producer,
    AuditWriter audit) =>
{
    var user = DemoUser.FromRequest(request, app.Configuration);

    var membership = await db.OrganizationMembers.FindAsync(user.OrganizationId, user.UserId);
    if (membership is null)
    {
        return Results.Forbid();
    }

    if (string.IsNullOrWhiteSpace(body.Title) || body.Title.Trim().Length < 3)
    {
        return Results.BadRequest(new { code = "TASK_TITLE_INVALID" });
    }

    var task = new TaskItem
    {
        Id = Guid.NewGuid().ToString("N"),
        OrganizationId = user.OrganizationId,
        Title = body.Title.Trim(),
        Description = string.IsNullOrWhiteSpace(body.Description) ? null : body.Description.Trim(),
        Status = "todo",
        CreatedById = user.UserId,
        CreatedAt = DateTimeOffset.UtcNow,
        UpdatedAt = DateTimeOffset.UtcNow
    };

    db.Tasks.Add(task);
    await db.SaveChangesAsync();

    await audit.Write(new AuditInput(
        user.OrganizationId,
        user.UserId,
        "task.created",
        "task",
        task.Id,
        new Dictionary<string, object?> { ["title"] = task.Title }
    ));

    if (producer is not null)
    {
        try
        {
            await producer.ProduceAsync(
                "task.events",
                new Message<string, string>
                {
                    Key = task.Id,
                    Value = JsonSerializer.Serialize(new { type = "task.created", taskId = task.Id })
                }
            );
        }
        catch
        {
            Console.WriteLine("Kafka publish skipped.");
        }
    }

    if (redis is not null)
    {
        await redis.GetDatabase().KeyDeleteAsync($"task:list:{user.OrganizationId}");
    }

    return Results.Created($"/api/tasks/{task.Id}", task);
});

app.MapGet("/api/audit-logs", async (HttpRequest request, AppDbContext db) =>
{
    var user = DemoUser.FromRequest(request, app.Configuration);

    var logs = await db.AuditLogs
        .Where(log => log.OrganizationId == user.OrganizationId)
        .OrderByDescending(log => log.CreatedAt)
        .Take(20)
        .ToListAsync();

    return Results.Ok(logs);
});

app.MapGet("/api/ai/task-summary", async (
    HttpRequest request,
    AppDbContext db,
    AiAssistant ai) =>
{
    var user = DemoUser.FromRequest(request, app.Configuration);

    var tasks = await db.Tasks
        .Where(task => task.OrganizationId == user.OrganizationId)
        .Select(task => new AiTask(task.Title, task.Status))
        .ToListAsync();

    return Results.Ok(ai.Summarize(tasks));
});

app.MapGet("/api/mcp/tools", () => Results.Ok(McpToolRegistry.Tools));

app.Run("http://localhost:8080");

public sealed record CreateTaskRequest(string Title, string? Description);

public sealed record DemoUser(string UserId, string OrganizationId)
{
    public static DemoUser FromRequest(HttpRequest request, IConfiguration configuration)
    {
        var userId = request.Headers["x-demo-user-id"].FirstOrDefault()
            ?? configuration["Demo:UserId"]
            ?? "user_owner";

        var organizationId = request.Headers["x-demo-organization-id"].FirstOrDefault()
            ?? configuration["Demo:OrganizationId"]
            ?? "org_demo";

        return new DemoUser(userId, organizationId);
    }
}

public sealed class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) {}

    public DbSet<UserAccount> Users => Set<UserAccount>();
    public DbSet<Organization> Organizations => Set<Organization>();
    public DbSet<OrganizationMember> OrganizationMembers => Set<OrganizationMember>();
    public DbSet<TaskItem> Tasks => Set<TaskItem>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<OrganizationMember>()
            .HasKey(member => new { member.OrganizationId, member.UserId });

        modelBuilder.Entity<TaskItem>()
            .HasIndex(task => task.OrganizationId);

        modelBuilder.Entity<AuditLog>()
            .HasIndex(log => new { log.OrganizationId, log.CreatedAt });
    }
}

public sealed class UserAccount
{
    public string Id { get; set; } = "";
    public string Email { get; set; } = "";
    public string Name { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public sealed class Organization
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public sealed class OrganizationMember
{
    public string OrganizationId { get; set; } = "";
    public string UserId { get; set; } = "";
    public string Role { get; set; } = "owner";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public sealed class TaskItem
{
    public string Id { get; set; } = "";
    public string OrganizationId { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Description { get; set; }
    public string Status { get; set; } = "todo";
    public string CreatedById { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public sealed class AuditLog
{
    public string Id { get; set; } = "";
    public string OrganizationId { get; set; } = "";
    public string ActorUserId { get; set; } = "";
    public string Action { get; set; } = "";
    public string EntityType { get; set; } = "";
    public string EntityId { get; set; } = "";
    public string MetadataJson { get; set; } = "{}";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public sealed record AuditInput(
    string OrganizationId,
    string ActorUserId,
    string Action,
    string EntityType,
    string EntityId,
    Dictionary<string, object?> Metadata
);

public sealed class AuditWriter
{
    private readonly AppDbContext db;
    private readonly IProducer<string, string>? producer;

    public AuditWriter(AppDbContext db, IProducer<string, string>? producer)
    {
        this.db = db;
        this.producer = producer;
    }

    public async Task Write(AuditInput input)
    {
        var log = new AuditLog
        {
            Id = Guid.NewGuid().ToString("N"),
            OrganizationId = input.OrganizationId,
            ActorUserId = input.ActorUserId,
            Action = input.Action,
            EntityType = input.EntityType,
            EntityId = input.EntityId,
            MetadataJson = JsonSerializer.Serialize(input.Metadata),
            CreatedAt = DateTimeOffset.UtcNow
        };

        db.AuditLogs.Add(log);
        await db.SaveChangesAsync();

        if (producer is not null)
        {
            try
            {
                await producer.ProduceAsync(
                    "audit.events",
                    new Message<string, string>
                    {
                        Key = log.Id,
                        Value = JsonSerializer.Serialize(log)
                    }
                );
            }
            catch
            {
                Console.WriteLine("Kafka audit publish skipped.");
            }
        }
    }
}

public sealed record AiTask(string Title, string Status);

public sealed class AiAssistant
{
    public object Summarize(IReadOnlyCollection<AiTask> tasks)
    {
        var total = tasks.Count;
        var done = tasks.Count(task => task.Status == "done");

        return new
        {
            summary = $"Ada {total} task. {done} task sudah selesai.",
            suggestions = new[]
            {
                "Prioritaskan task todo yang paling kecil.",
                "Gunakan audit log untuk mengecek aktivitas user."
            }
        };
    }
}

public static class McpToolRegistry
{
    public static object[] Tools =>
        new object[]
        {
        new
        {
            name = "task.list",
            description = "List tasks by organization.",
            inputSchema = new
            {
                type = "object",
                properties = new
                {
                    organizationId = new { type = "string" }
                },
                required = new[] { "organizationId" }
            }
        }
    };
}

public static class SeedData
{
    public static void EnsureSeeded(AppDbContext db)
    {
        if (!db.Users.Any(user => user.Id == "user_owner"))
        {
            db.Users.Add(new UserAccount
            {
                Id = "user_owner",
                Email = "owner@example.com",
                Name = "Owner User"
            });
        }

        if (!db.Organizations.Any(org => org.Id == "org_demo"))
        {
            db.Organizations.Add(new Organization
            {
                Id = "org_demo",
                Name = "Demo Workspace"
            });
        }

        if (!db.OrganizationMembers.Any(member =>
                member.OrganizationId == "org_demo" && member.UserId == "user_owner"))
        {
            db.OrganizationMembers.Add(new OrganizationMember
            {
                OrganizationId = "org_demo",
                UserId = "user_owner",
                Role = "owner"
            });
        }

        db.SaveChanges();
    }
}
```

Run backend:

```powershell
dotnet run --project Workspace.Api --urls http://localhost:8080
```

## 5. Frontend Install

```powershell
cd ..\workspace-web
npm install
```

Buat `workspace-web/.env`:

```env
VITE_API_BASE_URL=http://localhost:8080
```

## 6. Frontend API - `workspace-web/src/api.ts`

```ts
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8080";

const headers = {
  "Content-Type": "application/json",
  "x-demo-user-id": "user_owner",
  "x-demo-organization-id": "org_demo",
};

export type Task = {
  id: string;
  title: string;
  description: string | null;
  status: string;
};

export type AuditLog = {
  id: string;
  action: string;
  entityType: string;
  entityId: string;
  createdAt: string;
};

export async function listTasks(): Promise<Task[]> {
  return fetch(`${API_BASE_URL}/api/tasks`, { headers }).then((res) => res.json());
}

export async function createTask(input: { title: string; description?: string }) {
  return fetch(`${API_BASE_URL}/api/tasks`, {
    method: "POST",
    headers,
    body: JSON.stringify(input),
  }).then((res) => res.json());
}

export async function getAuditLogs(): Promise<AuditLog[]> {
  return fetch(`${API_BASE_URL}/api/audit-logs`, { headers }).then((res) => res.json());
}

export async function getAiSummary(): Promise<{ summary: string; suggestions: string[] }> {
  return fetch(`${API_BASE_URL}/api/ai/task-summary`, { headers }).then((res) =>
    res.json()
  );
}
```

## 7. Frontend App - `workspace-web/src/App.tsx`

```tsx
import { FormEvent, useEffect, useState } from "react";
import {
  createTask,
  getAiSummary,
  getAuditLogs,
  listTasks,
  type AuditLog,
  type Task,
} from "./api";
import "./App.css";

export default function App() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [summary, setSummary] = useState("");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");

  async function load() {
    const [taskData, logData, summaryData] = await Promise.all([
      listTasks(),
      getAuditLogs(),
      getAiSummary(),
    ]);

    setTasks(taskData);
    setLogs(logData);
    setSummary(summaryData.summary);
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    await createTask({ title, description });
    setTitle("");
    setDescription("");
    await load();
  }

  useEffect(() => {
    void load();
  }, []);

  return (
    <main className="page">
      <header>
        <p className="eyebrow">Enterprise Mockup</p>
        <h1>Task Workspace</h1>
        <p>.NET API, React UI, auth mock, audit, Redis, Kafka, AI, MCP, Grafana.</p>
      </header>

      <form className="panel" onSubmit={submit}>
        <h2>Create Task</h2>
        <input
          value={title}
          onChange={(event) => setTitle(event.target.value)}
          placeholder="Task title"
        />
        <textarea
          value={description}
          onChange={(event) => setDescription(event.target.value)}
          placeholder="Description"
        />
        <button>Save</button>
      </form>

      <section className="panel">
        <h2>AI Summary</h2>
        <p>{summary || "No summary yet."}</p>
      </section>

      <section className="panel">
        <h2>Tasks</h2>
        <ul>
          {tasks.map((task) => (
            <li key={task.id}>
              <strong>{task.title}</strong>
              <span>{task.status}</span>
              {task.description ? <p>{task.description}</p> : null}
            </li>
          ))}
        </ul>
      </section>

      <section className="panel">
        <h2>Audit Logs</h2>
        <ul>
          {logs.map((log) => (
            <li key={log.id}>
              {log.action} - {log.entityType}/{log.entityId}
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
```

## 8. Frontend Style - `workspace-web/src/App.css`

```css
:root {
  font-family: Arial, sans-serif;
  color: #182321;
  background: #f4f7f6;
}

body {
  margin: 0;
}

.page {
  width: min(920px, calc(100% - 32px));
  margin: 40px auto;
}

.eyebrow {
  color: #2f6f73;
  font-weight: 700;
  text-transform: uppercase;
}

.panel {
  display: grid;
  gap: 12px;
  margin-top: 18px;
  padding: 16px;
  background: white;
  border: 1px solid #d8e2df;
  border-radius: 8px;
}

input,
textarea,
button {
  font: inherit;
}

input,
textarea {
  padding: 10px;
  border: 1px solid #b8c7c2;
  border-radius: 6px;
}

button {
  width: fit-content;
  padding: 10px 14px;
  color: white;
  background: #2f6f73;
  border: 0;
  border-radius: 6px;
}

span {
  margin-left: 8px;
  color: #5d6b67;
  font-size: 13px;
}
```

## 9. Run Semua

Terminal root:

```powershell
docker compose up -d
```

Terminal backend:

```powershell
dotnet run --project Workspace.Api --urls http://localhost:8080
```

Terminal frontend:

```powershell
cd workspace-web
npm run dev
```

Cek:

```text
Frontend http://localhost:5173
Backend  http://localhost:8080/health
Ready    http://localhost:8080/ready
Metrics  http://localhost:8080/metrics
Grafana  http://localhost:3001
```

## 10. Checklist

- React bisa membuat task.
- .NET API menyimpan task ke PostgreSQL.
- Audit log bertambah setelah create task.
- Redis cache list task invalidated setelah create.
- Kafka publish event berjalan best-effort.
- AI summary mock bisa dipanggil.
- MCP tool registry tersedia di `/api/mcp/tools`.
- Grafana lokal bisa dibuka dengan `admin/admin`.

## 11. Jika Ingin Versi Spring

Gunakan file berikut sebagai padanan konsep:

- [backend/09-code-blueprint-spring.md](backend/09-code-blueprint-spring.md)
- [frontend/06-code-blueprint-angular-react.md](frontend/06-code-blueprint-angular-react.md)

Struktur service tetap sama: controller, use case, repository, audit writer, Redis cache, Kafka producer, AI adapter, dan MCP tool registry.
