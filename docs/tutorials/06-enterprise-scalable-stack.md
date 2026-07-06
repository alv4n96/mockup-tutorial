# 06 - Track Enterprise & Scalable Stack

## Target Track

Bangun backend modular monolith yang siap untuk aplikasi besar:

- Frontend: Angular atau React + TypeScript.
- Backend: .NET atau Spring Boot.
- Database: PostgreSQL atau SQL Server.
- Fokus: security, maintainability, audit, reliability.

## Pilihan Backend

### .NET

Cocok bila:

- Tim memakai C#.
- Infrastruktur dekat dengan Azure.
- Butuh tooling enterprise kuat.
- Butuh API high-performance dan typed.

Paket umum:

- ASP.NET Core Web API.
- Entity Framework Core.
- FluentValidation.
- MediatR atau vertical slice ringan.
- Serilog.
- OpenTelemetry.

### Spring Boot

Cocok bila:

- Tim memakai Java/Kotlin.
- Ekosistem perusahaan sudah JVM.
- Butuh Spring Security, Spring Data, dan integrasi enterprise.

Paket umum:

- Spring Web.
- Spring Data JPA.
- Spring Security.
- Bean Validation.
- Flyway atau Liquibase.
- Micrometer dan OpenTelemetry.

## Struktur .NET

```text
src/
  Web/
    Program.cs
    Endpoints/
  Modules/
    Identity/
      Identity.Domain/
      Identity.Application/
      Identity.Infrastructure/
      Identity.Api/
    Organizations/
    Tasks/
    Catalog/
    Orders/
  Shared/
    SharedKernel/
    Infrastructure/
tests/
  UnitTests/
  IntegrationTests/
```

Aturan:

- `Domain` tidak referensi EF Core.
- `Application` berisi command/query/use case.
- `Infrastructure` berisi repository, DbContext, provider.
- `Api` berisi endpoint/controller.
- `Web` menjadi composition root.

## Struktur Spring Boot

```text
src/main/java/com/company/app/
  AppApplication.java
  modules/
    identity/
      domain/
      application/
      infrastructure/
      presentation/
    organizations/
    tasks/
    catalog/
    orders/
  shared/
```

Aturan:

- Domain tidak memakai annotation JPA bila ingin domain murni.
- Jika memilih pragmatic Spring, entity JPA boleh dipakai tetapi aturan bisnis tetap jangan bocor ke controller.
- Service application mengatur transaksi.
- Repository interface ditempatkan dekat application/domain, implementasi di infrastructure.

## API Style

Mulai dengan REST:

```text
POST /api/auth/register
POST /api/auth/login
GET  /api/me
POST /api/organizations
GET  /api/organizations/{id}/members
POST /api/organizations/{id}/members/invite
GET  /api/organizations/{id}/tasks
POST /api/organizations/{id}/tasks
PATCH /api/tasks/{id}
```

Untuk e-commerce:

```text
GET  /api/products
POST /api/products
GET  /api/orders
POST /api/orders/checkout
POST /api/payments/webhook
```

## Security Baseline

Wajib:

- Password hashing kuat jika menyimpan password sendiri.
- JWT atau session dengan expiration jelas.
- Role-based access control.
- Authorization di use case, bukan hanya middleware.
- Rate limiting untuk login dan register.
- Audit log untuk perubahan penting.
- Secret disimpan di secret manager atau environment variable.

Enterprise tambahan:

- OpenID Connect.
- SSO.
- MFA.
- IP allowlist untuk admin.
- Field-level audit untuk data sensitif.
- Data retention policy.

## Database

PostgreSQL cocok untuk cross-platform. SQL Server cocok bila:

- Infrastruktur Microsoft.
- Reporting dan BI sudah memakai SQL Server.
- Tim DBA kuat di SQL Server.

Gunakan Flyway/Liquibase untuk Spring Boot. Gunakan EF Core migration atau FluentMigrator untuk .NET.

## Background Job

Gunakan background job untuk:

- Email invitation.
- Invoice generation.
- Payment reconciliation.
- Export report.
- Cleanup expired session.

.NET:

- HostedService untuk sederhana.
- Hangfire atau Quartz.NET untuk job terjadwal.

Spring:

- `@Scheduled` untuk sederhana.
- Quartz atau Spring Batch untuk proses besar.

## Observability

Minimal:

- Structured logging.
- Request correlation id.
- Health check endpoint.
- Metrics HTTP duration dan error rate.
- Trace untuk call database dan provider eksternal.

Endpoint:

```text
GET /health
GET /ready
```

## Frontend Enterprise

Angular cocok bila:

- Tim ingin framework opinionated.
- Banyak form kompleks.
- Enterprise UI pattern kuat.

React cocok bila:

- Tim ingin fleksibilitas.
- Ekosistem UI dan product iteration lebih cepat.

Halaman minimal:

- Login.
- Dashboard.
- Organization switcher.
- Task/product list.
- Detail page.
- Create/edit form.
- Admin members.
- Audit log.

## Checklist Track Enterprise

- Layer dependency benar.
- Endpoint punya validation dan authorization.
- Migration repeatable di CI.
- Integration test memakai database test.
- Log tidak membocorkan password/token.
- Health check tersedia.
- Deployment punya rollback strategy.
- Audit log untuk aksi penting.
