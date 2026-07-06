# Backend 02 - Modular Monolith Layers

## Yang Dibuat

Layer untuk setiap module enterprise.

## Struktur .NET

```text
Modules/
  Tasks/
    Tasks.Api/
    Tasks.Application/
    Tasks.Domain/
    Tasks.Infrastructure/
```

## Struktur Spring

```text
modules/tasks/
  presentation/
  application/
  domain/
  infrastructure/
```

## Aturan

- API/presentation menerima request.
- Application menjalankan use case dan transaksi.
- Domain menyimpan aturan bisnis.
- Infrastructure menyimpan EF Core/JPA, provider, dan adapter.

## Output

Setiap module bisa dikembangkan tanpa merusak module lain.
