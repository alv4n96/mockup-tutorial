# 02 - Modular Monolith Dan Layered Architecture

## Bentuk Umum

Modular monolith memisahkan aplikasi berdasarkan domain, bukan berdasarkan jenis file teknis saja. Contoh modul:

- `Identity`
- `Organizations`
- `Tasks`
- `Catalog`
- `Orders`
- `Billing`
- `Notifications`

Setiap modul boleh punya controller/router, service/use case, domain model, repository, dan mapper sendiri. Shared code tetap sedikit dan hanya untuk hal lintas domain.

## Layer Yang Dipakai

### Presentation Layer

Tanggung jawab:

- Menerima request HTTP, tRPC call, GraphQL call, atau UI event.
- Validasi input format.
- Memanggil application service.
- Mengubah response menjadi DTO atau view model.

Tidak boleh:

- Menulis query database langsung.
- Memuat aturan bisnis utama.
- Mengambil keputusan domain seperti status order berikutnya.

### Application Layer

Tanggung jawab:

- Menjalankan use case.
- Mengatur transaksi.
- Mengorkestrasi domain service, repository, dan integration service.
- Mengecek authorization use case.
- Menghasilkan DTO output.

Contoh:

- `CreateTaskUseCase`
- `InviteMemberUseCase`
- `CheckoutOrderUseCase`
- `ChangeSubscriptionPlanUseCase`

### Domain Layer

Tanggung jawab:

- Menyimpan aturan bisnis inti.
- Entity, value object, enum, domain event.
- Domain service untuk aturan yang melibatkan lebih dari satu entity.

Tidak boleh:

- Bergantung pada framework web.
- Bergantung pada ORM.
- Bergantung pada provider eksternal.

### Infrastructure Layer

Tanggung jawab:

- Implementasi repository.
- ORM schema.
- Email provider.
- Payment provider.
- File storage.
- Queue dan background job.

Layer ini boleh bergantung pada library teknis, tetapi domain tidak boleh bergantung balik ke infrastructure.

## Struktur Folder TypeScript/Next.js

```text
src/
  app/
    (auth)/
    (dashboard)/
    api/
  modules/
    identity/
      application/
      domain/
      infrastructure/
      presentation/
    organizations/
    tasks/
    billing/
  shared/
    auth/
    db/
    errors/
    events/
    result/
    validation/
```

## Struktur Folder .NET

```text
src/
  Web/
  Modules/
    Identity/
      Identity.Api/
      Identity.Application/
      Identity.Domain/
      Identity.Infrastructure/
    Organizations/
    Tasks/
    Billing/
  Shared/
    SharedKernel/
    Infrastructure/
tests/
```

## Struktur Folder Spring Boot

```text
src/main/java/com/example/app/
  web/
  modules/
    identity/
      application/
      domain/
      infrastructure/
      presentation/
    organizations/
    tasks/
    billing/
  shared/
```

## Aturan Dependency

Dependency harus mengarah ke dalam:

```text
Presentation -> Application -> Domain
Infrastructure -> Application/Domain interfaces
Domain -> tidak bergantung ke layer luar
```

Prinsip praktis:

- Controller memanggil use case.
- Use case memakai repository interface.
- Infrastructure mengimplementasikan repository interface.
- Domain tidak tahu database.
- Modul lain tidak boleh mengambil tabel modul tetangga secara sembarangan.

## Komunikasi Antar Modul

Gunakan salah satu:

- Public application service, misalnya `OrganizationsAccessService`.
- Contract interface, misalnya `MemberLookup`.
- Domain event atau integration event, misalnya `OrderPaid`.
- Database read model khusus bila query lintas modul memang dibutuhkan.

Hindari:

- Modul `Orders` mengubah tabel `Users` langsung.
- Modul `Tasks` membaca semua detail billing langsung.
- Shared folder menjadi tempat semua logic.

## Modul Minimal Untuk Pembelajaran

Untuk SaaS:

- `Identity`
- `Organizations`
- `Tasks`
- `Billing`
- `Notifications`

Untuk e-commerce:

- `Identity`
- `Catalog`
- `Cart`
- `Orders`
- `Payments`
- `Notifications`

## Checklist Arsitektur

- Setiap modul punya boundary jelas.
- Setiap use case punya input dan output jelas.
- Validasi format ada di presentation/application.
- Aturan bisnis ada di domain.
- Query database ada di infrastructure.
- Error ditangani konsisten.
- Transaksi tidak bocor ke controller.
- Test domain tidak butuh database.
