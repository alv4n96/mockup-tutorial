# Dokumentasi Per Tech Stack

Folder ini adalah struktur utama pembelajaran. Setiap tech stack punya folder sendiri, lalu dipecah menjadi `backend/` dan `frontend/`.

## Tech Stack

| Tech Stack | Backend | Frontend | Cocok Untuk |
| --- | --- | --- | --- |
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
