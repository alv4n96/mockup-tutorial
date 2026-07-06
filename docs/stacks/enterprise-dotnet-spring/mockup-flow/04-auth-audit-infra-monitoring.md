# 04 - Auth, Audit, Infra, Monitoring

Target: menambah service mock yang umum di enterprise.

## Auth Mock

Buat `src/Workspace.Api/CurrentUser.cs`.

```csharp
namespace Workspace.Api;

public sealed record CurrentUser(string UserId, string OrganizationId)
{
    public static CurrentUser From(HttpContext context)
    {
        return new CurrentUser(
            context.Request.Headers["x-demo-user-id"].FirstOrDefault() ?? "user_owner",
            context.Request.Headers["x-demo-organization-id"].FirstOrDefault() ?? "org_demo"
        );
    }
}
```

Nanti jika memakai JWT, ganti isi `From()`, endpoint tidak perlu berubah banyak.

## Kafka Publisher

Buat `src/Workspace.Api/KafkaEventPublisher.cs`.

```csharp
using Confluent.Kafka;
using System.Text.Json;
using Workspace.SharedKernel;

namespace Workspace.Api;

public sealed class KafkaEventPublisher : IEventPublisher
{
    private readonly IProducer<string, string> producer;

    public KafkaEventPublisher(IProducer<string, string> producer)
    {
        this.producer = producer;
    }

    public async Task PublishAsync(string topic, object payload, CancellationToken cancellationToken)
    {
        await producer.ProduceAsync(
            topic,
            new Message<string, string> { Value = JsonSerializer.Serialize(payload) },
            cancellationToken
        );
    }
}
```

Ini Adapter pattern: aplikasi bicara ke `IEventPublisher`, bukan langsung ke Kafka.

## AI Assistant

Buat `src/Workspace.Api/AiAssistant.cs`.

```csharp
namespace Workspace.Api;

public sealed class AiAssistant
{
    public object SummarizeTasks(IReadOnlyCollection<object> tasks)
    {
        return new
        {
            summary = $"Ada {tasks.Count} task.",
            suggestions = new[] { "Kerjakan task paling kecil terlebih dahulu." }
        };
    }
}
```

Ini Strategy sederhana. Nanti bisa diganti `OpenAiAssistant`.

## MCP Tool Registry

Buat `src/Workspace.Api/McpToolRegistry.cs`.

```csharp
namespace Workspace.Api;

public static class McpToolRegistry
{
    public static object[] Tools => new object[]
    {
        new
        {
            name = "task.list",
            description = "List tasks by organization.",
            inputSchema = new
            {
                type = "object",
                required = new[] { "organizationId" }
            }
        }
    };
}
```

MCP registry dibuat terpisah karena bukan business logic task.

## Monitoring

Tambahkan di `Program.cs`:

```csharp
app.MapGet("/health", () => Results.Ok(new { status = "ok" }));
app.MapGet("/ready", () => Results.Ok(new { status = "ok" }));
app.MapGet("/metrics", () => Results.Text("app_mockup_info 1\n", "text/plain"));
app.MapGet("/api/mcp/tools", () => Results.Ok(McpToolRegistry.Tools));
```

## Redis

Redis dipakai di endpoint list atau repository decorator. Untuk awal, tambahkan di API:

```csharp
builder.Services.AddSingleton(
    StackExchange.Redis.ConnectionMultiplexer.Connect("localhost:6379")
);
```

Jika cache mulai dipakai banyak endpoint, buat file baru `RedisCache.cs`. Jangan copy paste `StringGetAsync` di semua endpoint.
