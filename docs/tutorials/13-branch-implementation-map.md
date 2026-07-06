# 13 - Pemetaan Materi Per Branch Pembelajaran

File ini menjelaskan bagaimana materi di folder ini dipakai pada setiap branch tutorial.

## Branch `tutorial/typescript-next-shadcn`

Jalur:

- Modern SaaS & Startup Stack.
- Next.js App Router, React 19, Tailwind CSS.
- Node.js atau Bun.
- tRPC.
- PostgreSQL.
- Vercel atau Cloudflare.

Materi wajib:

1. `01-roadmap.md`
2. `02-architecture.md`
3. `03-domain-model.md`
4. `04-database.md`
5. `05-modern-saas-t3-next.md`
6. `07-abstract-factory-provider.md`
7. `08-auth-tenancy.md`
8. `09-api-frontend-flow.md`
9. `10-testing-observability.md`
10. `11-deployment-production.md`
11. `12-capstone-end-to-end.md`

Target implementasi:

- SaaS task workspace.
- User register/login.
- Organization sebagai tenant.
- Membership dan role.
- Task sebagai modul penghubung utama.
- Billing provider abstraction dengan Abstract Factory.
- Dashboard, task list, task detail, settings members, billing placeholder.

Struktur branch yang disarankan:

```text
README.md
docs/
  tutorials/
src/
  app/
  modules/
    identity/
    organizations/
    tasks/
    billing/
  shared/
prisma/ atau drizzle/
tests/
```

Definition of done:

- `npm run typecheck` berhasil.
- Auth dan protected route berjalan.
- Tenant isolation test tersedia.
- CRUD task berjalan end-to-end.
- Deployment preview berhasil.

## Branch `tutorial/csharp-blazor-bootstrap`

Jalur:

- Enterprise & Scalable Stack.
- ASP.NET Core modular monolith.
- Blazor WebAssembly, React, atau Angular untuk frontend.
- PostgreSQL atau SQL Server.

Materi wajib:

1. `01-roadmap.md`
2. `02-architecture.md`
3. `03-domain-model.md`
4. `04-database.md`
5. `06-enterprise-scalable-stack.md`
6. `07-abstract-factory-provider.md`
7. `08-auth-tenancy.md`
8. `09-api-frontend-flow.md`
9. `10-testing-observability.md`
10. `11-deployment-production.md`
11. `12-capstone-end-to-end.md`

Target implementasi:

- Backend modular monolith dengan module boundary jelas.
- Identity, Organizations, Tasks atau Catalog/Orders.
- Role-based authorization.
- Audit log.
- Health check.
- Integration test dengan database test.
- Provider abstraction untuk email/payment.

Struktur branch yang disarankan:

```text
README.md
docs/
  tutorials/
src/
  Web/
  Modules/
    Identity/
    Organizations/
    Tasks/
    Billing/
  Shared/
tests/
```

Definition of done:

- `dotnet build` berhasil.
- Unit dan integration test penting berjalan.
- Migration bisa membuat database dari nol.
- Endpoint protected punya authorization.
- Health check tersedia.

## Branch `tutorial/typescript-vue-vuetify`

Jalur:

- Pembanding TypeScript modular monolith.
- NestJS atau backend TypeScript modular.
- Vue 3 + Vite + Vuetify.
- PostgreSQL.

Materi wajib:

1. `01-roadmap.md`
2. `02-architecture.md`
3. `03-domain-model.md`
4. `04-database.md`
5. `08-auth-tenancy.md`
6. `09-api-frontend-flow.md`
7. `10-testing-observability.md`
8. `11-deployment-production.md`
9. `12-capstone-end-to-end.md`

Target implementasi:

- Membandingkan arsitektur modular TypeScript selain Next.js.
- Backend tetap modular monolith.
- Frontend fokus pada dashboard operasional.
- Modul utama boleh memakai task atau product.

Struktur branch yang disarankan:

```text
README.md
docs/
  tutorials/
apps/
  api/
  web/
packages/
  shared/
```

Definition of done:

- API dan web bisa dijalankan lokal.
- Auth flow berjalan.
- CRUD modul utama berjalan.
- Database migration tersedia.
- Dokumentasi per modul tidak hanya di README.

## Aturan Dokumentasi Per Branch

Setiap branch pembelajaran sebaiknya memiliki:

- `README.md` sebagai index singkat.
- `docs/tutorials/` untuk alur belajar umum.
- `docs/modules/identity.md`
- `docs/modules/organizations.md`
- `docs/modules/tasks.md` atau `docs/modules/catalog-orders.md`
- `docs/architecture/layers.md`
- `docs/operations/deployment.md`
- `docs/testing/checklist.md`

README tidak boleh menjadi satu-satunya tempat materi. Jika sebuah topik mulai lebih dari beberapa paragraf, pecah menjadi file sendiri.
