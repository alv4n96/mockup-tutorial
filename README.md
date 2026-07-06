# Full Stack Tutorial Branches

Repository ini berisi materi pembelajaran full stack yang dipisahkan per branch, per tech stack, lalu per layer backend/frontend. Fokus utamanya adalah backend modular monolith untuk aplikasi SaaS dan e-commerce, dengan alur dari database sampai UI.

## Struktur Utama

Materi utama ada di [docs/stacks/README.md](docs/stacks/README.md).

```text
docs/
  stacks/
    modern-saas-t3-next/
      backend/
      frontend/
      full-flow.md
    enterprise-dotnet-spring/
      backend/
      frontend/
      full-flow.md
    typescript-vue-nest/
      backend/
      frontend/
      full-flow.md
```

## Daftar Branch Pembelajaran

| Branch | Folder Materi | Backend | Frontend | Fokus |
| --- | --- | --- | --- | --- |
| `tutorial/typescript-next-shadcn` | [docs/stacks/modern-saas-t3-next](docs/stacks/modern-saas-t3-next/README.md) | Next.js server layer, Node.js/Bun, tRPC, PostgreSQL | Next.js App Router, React 19, Tailwind CSS | Modern SaaS, startup, type-safe prototype |
| `tutorial/csharp-blazor-bootstrap` | [docs/stacks/enterprise-dotnet-spring](docs/stacks/enterprise-dotnet-spring/README.md) | .NET atau Spring Boot, PostgreSQL/SQL Server | Angular atau React + TypeScript | Enterprise, secure, reliable, audit-ready |
| `tutorial/typescript-vue-vuetify` | [docs/stacks/typescript-vue-nest](docs/stacks/typescript-vue-nest/README.md) | NestJS modular monolith, PostgreSQL | Vue 3, Vite, Vuetify | Pembanding TypeScript di luar React |

## Cara Membaca

1. Pilih tech stack di `docs/stacks`.
2. Baca folder `backend/` dari file `01` sampai selesai.
3. Lanjutkan folder `frontend/` dari file `01` sampai selesai.
4. Baca `full-flow.md` untuk melihat hubungan dari backend ke frontend.
5. Gunakan `docs/tutorials/` sebagai referensi umum tambahan.

## Definisi Modular Monolith Di Repository Ini

Sebuah backend di tutorial ini disebut modular monolith jika:

- Satu aplikasi backend deployable.
- Modul bisnis dipisah jelas, misalnya `Identity`, `Organizations`, `Tasks`, `Catalog`, `Orders`, `Billing`, dan `Audit`.
- Setiap modul punya layer presentation, application, domain, dan infrastructure.
- Domain tidak bergantung pada framework web, ORM, atau provider eksternal.
- Controller/router hanya menerima request dan memanggil use case.
- Application layer menjalankan workflow, authorization, dan transaksi.
- Infrastructure layer menangani database, email, payment, storage, dan provider eksternal.
- Modul lain tidak mengakses tabel atau repository internal module tetangga secara sembarangan.
- Integrasi antar modul memakai public service, contract, atau event.

## Domain Pembelajaran

Semua stack memakai pola yang sama agar mudah dibandingkan:

- Selalu ada `User`.
- Selalu ada `Organization` atau tenant.
- Selalu ada modul penghubung:
  - `Task` untuk SaaS/project management.
  - `Product` dan `Order` untuk e-commerce.
  - `Subscription` untuk billing SaaS.

## Referensi Design Pattern

Provider abstraction memakai Abstract Factory dari Refactoring Guru:

- [docs/stacks/modern-saas-t3-next/backend/06-billing-abstract-factory.md](docs/stacks/modern-saas-t3-next/backend/06-billing-abstract-factory.md)
- [docs/stacks/enterprise-dotnet-spring/backend/06-provider-abstract-factory.md](docs/stacks/enterprise-dotnet-spring/backend/06-provider-abstract-factory.md)
- https://refactoring.guru/design-patterns/abstract-factory

## Cara Membuka Branch

```bash
git fetch origin
git switch tutorial/typescript-next-shadcn
```

Untuk jalur enterprise:

```bash
git switch tutorial/csharp-blazor-bootstrap
```

## Mock Activity Log

Lihat `MOCK_ACTIVITY_LOG.md` untuk simulasi timeline aktivitas dari 2026-02-13 sampai 2026-07-06. File tersebut berisi contoh command `git commit --date=<date> -m <Message>` dengan Sabtu dan Minggu dilewati. Ini adalah dokumentasi simulasi, bukan riwayat Git aktual.
