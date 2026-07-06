# Backend 02 - Modular Monolith Layers

## Yang Dibuat

Struktur layered architecture untuk setiap module.

## Struktur

```text
src/modules/tasks/
  domain/
  application/
  infrastructure/
  presentation/
```

## Tanggung Jawab

- `domain`: entity, value object, policy, domain event.
- `application`: use case, authorization use case, transaction orchestration.
- `infrastructure`: Prisma/Drizzle repository, provider eksternal.
- `presentation`: tRPC router, input schema, response mapper.

## Aturan Dependency

```text
presentation -> application -> domain
infrastructure -> domain/application interfaces
domain -> tidak bergantung ke luar
```

## Kenapa Modular Monolith

Backend tetap satu aplikasi, tetapi setiap domain punya folder dan boundary sendiri. Jika nanti `Tasks` perlu dipisah menjadi service, kontrak dan use case sudah jelas.
