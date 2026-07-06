# Tutorial Modular Monolith Untuk SaaS Dan E-Commerce

Folder ini memecah materi pembelajaran menjadi beberapa file agar setiap branch tidak hanya bergantung pada `README.md`. Urutannya dibuat dari awal sampai akhir sehingga bisa dipakai sebagai panduan membangun website utuh.

## Jalur Belajar

| Urutan | Materi | File |
| --- | --- | --- |
| 01 | Peta produk, stack, dan hasil akhir | [01-roadmap.md](01-roadmap.md) |
| 02 | Prinsip modular monolith dan layered architecture | [02-architecture.md](02-architecture.md) |
| 03 | Model domain: user dan modul penghubung | [03-domain-model.md](03-domain-model.md) |
| 04 | Database, migration, seed, dan transaksi | [04-database.md](04-database.md) |
| 05 | Track Modern SaaS T3/Next.js | [05-modern-saas-t3-next.md](05-modern-saas-t3-next.md) |
| 06 | Track Enterprise .NET atau Spring Boot | [06-enterprise-scalable-stack.md](06-enterprise-scalable-stack.md) |
| 07 | Abstract Factory untuk provider dan variasi fitur | [07-abstract-factory-provider.md](07-abstract-factory-provider.md) |
| 08 | Auth, tenancy, roles, dan audit | [08-auth-tenancy.md](08-auth-tenancy.md) |
| 09 | API, frontend flow, dan UI pages | [09-api-frontend-flow.md](09-api-frontend-flow.md) |
| 10 | Testing, observability, dan quality gate | [10-testing-observability.md](10-testing-observability.md) |
| 11 | Deployment, production checklist, dan operasi | [11-deployment-production.md](11-deployment-production.md) |
| 12 | Capstone: dari kosong sampai rilis | [12-capstone-end-to-end.md](12-capstone-end-to-end.md) |
| 13 | Pemetaan materi per branch pembelajaran | [13-branch-implementation-map.md](13-branch-implementation-map.md) |

## Branch Yang Relevan

- `tutorial/typescript-next-shadcn`: jalur Modern SaaS & Startup Stack berbasis Next.js, React, Tailwind, tRPC, PostgreSQL.
- `tutorial/csharp-blazor-bootstrap`: jalur Enterprise & Scalable Stack berbasis .NET, layered architecture, PostgreSQL atau SQL Server.
- `tutorial/typescript-vue-vuetify`: jalur tambahan untuk membandingkan modular monolith TypeScript di luar React ecosystem.

## Target Aplikasi

Semua tutorial memakai pola produk yang sama agar konsepnya mudah dibandingkan antar stack:

- Selalu ada `User`.
- Selalu ada organisasi atau tenant sebagai konteks SaaS.
- Selalu ada satu modul penghubung yang bisa diganti sesuai kebutuhan belajar:
  - `Task` untuk project management SaaS.
  - `Product` dan `Order` untuk e-commerce.
  - `Subscription` untuk billing SaaS.
- Backend memakai modular monolith, bukan microservices.
- Frontend tetap menjadi website utuh: dashboard, auth, list, detail, form, settings, dan halaman admin.

## Cara Memakai

1. Baca `01-roadmap.md`.
2. Pilih track teknologi di file `05` atau `06`.
3. Ikuti `12-capstone-end-to-end.md` sebagai checklist implementasi berurutan.
4. Saat membuat branch baru, salin folder ini atau pertahankan struktur file yang sama supaya materi tetap konsisten.


