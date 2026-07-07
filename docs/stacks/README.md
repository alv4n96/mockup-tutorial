# Dokumentasi Per Tech Stack

Folder ini adalah struktur utama pembelajaran. Setiap tech stack punya folder sendiri, lalu dipecah menjadi `backend/` dan `frontend/`.

## Tech Stack

| Tech Stack | Backend | Frontend | Cocok Untuk |
| --- | --- | --- | --- |
| [shared](shared/README.md) | Response envelope, error code, DTO, pagination, module contract, RBAC tenant authorization | Berlaku untuk semua frontend | Aturan umum lintas stack |
| [modern-saas-t3-next](modern-saas-t3-next/README.md) | Next.js server layer, tRPC, Node.js/Bun, PostgreSQL | Next.js App Router, React 19, Tailwind CSS | SaaS cepat, startup, prototype type-safe |
| [enterprise-dotnet-spring](enterprise-dotnet-spring/README.md) | .NET atau Spring Boot, PostgreSQL/SQL Server | Angular atau React + TypeScript | Enterprise, sistem besar, audit dan reliability |
| [typescript-vue-nest](typescript-vue-nest/README.md) | NestJS modular monolith, PostgreSQL | Vue 3, Vite, Vuetify | Pembanding TypeScript di luar React |

## Cara Membaca

1. Pilih folder tech stack.
2. Baca `backend/` dari `01` sampai selesai.
3. Lanjutkan ke `frontend/` dari `01` sampai selesai.
4. Gunakan file `full-flow.md` di setiap tech stack untuk melihat alur end-to-end dari database sampai halaman UI.

## Definisi Modular Monolith

Semua stack di folder ini disebut modular monolith jika memenuhi aturan berikut:

- Satu aplikasi backend deployable.
- Backend dipisah menjadi modul domain seperti `Identity`, `Organizations`, `Tasks`, `Catalog`, `Orders`, dan `Billing`.
- Setiap modul punya layer sendiri: presentation, application, domain, infrastructure.
- Domain layer tidak bergantung pada framework web, ORM, atau provider eksternal.
- Controller/router hanya adapter, bukan tempat business logic.
- Query database berada di repository/infrastructure, bukan di UI atau controller.
- Modul saling berkomunikasi lewat public contract, application service, atau event, bukan akses tabel sembarang.
- Shared code tetap kecil dan hanya untuk cross-cutting concern.



## Blueprint Kode

File `code-blueprint` berisi contoh implementasi yang lebih dekat ke coding nyata: input request, DTO, role/permission RBAC, policy, use case, repository, controller/router, service frontend, dan state UI. Mulai dari [shared/06-rbac-tenant-authorization.md](shared/06-rbac-tenant-authorization.md), lalu lanjut ke blueprint stack yang dipilih.

## Mockup Siap Jalan

Jika ingin tutorial step-by-step yang dipecah kecil dan menjelaskan file mana yang dibuat atau diubah, mulai dari folder berikut:

- [modern-saas-t3-next/mockup-flow/README.md](modern-saas-t3-next/mockup-flow/README.md)
- [typescript-vue-nest/mockup-flow/README.md](typescript-vue-nest/mockup-flow/README.md)
- [enterprise-dotnet-spring/mockup-flow/README.md](enterprise-dotnet-spring/mockup-flow/README.md)
- [shared/07-mockup-auth-observability-ai-messaging.md](shared/07-mockup-auth-observability-ai-messaging.md) untuk convention auth, audit, monitoring, Redis, Kafka, Grafana, AI, dan MCP.

## Note :
- yang enterprise-dotnet-spring udah sampai ke nomor 08 untuk backend nya
- yang modern-saas-t3-next udah sampai ke nomor 07 untuk backend nya
- yang reac

