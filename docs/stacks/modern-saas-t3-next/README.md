# Modern SaaS & Startup Stack - T3 / Next.js

Stack ini fokus pada pembuatan SaaS cepat dengan type safety dari frontend sampai backend.

## Komponen

- Frontend: Next.js App Router, React 19, Tailwind CSS.
- Backend: Next.js server layer, tRPC, Node.js atau Bun.
- Database: PostgreSQL dengan Prisma atau Drizzle.
- Hosting: Vercel atau Cloudflare.
- Produk contoh: SaaS task workspace.

## Struktur Materi

Backend:

1. [backend/01-project-setup.md](backend/01-project-setup.md)
2. [backend/02-modular-monolith-layers.md](backend/02-modular-monolith-layers.md)
3. [backend/03-identity-auth.md](backend/03-identity-auth.md)
4. [backend/04-organization-tenancy.md](backend/04-organization-tenancy.md)
5. [backend/05-task-module.md](backend/05-task-module.md)
6. [backend/06-billing-abstract-factory.md](backend/06-billing-abstract-factory.md)
7. [backend/07-testing-deployment.md](backend/07-testing-deployment.md)
8. [backend/08-code-blueprint-response-error.md](backend/08-code-blueprint-response-error.md)
9. [backend/09-code-blueprint-identity-organization-task.md](backend/09-code-blueprint-identity-organization-task.md)

Frontend:

1. [frontend/01-app-router-layout.md](frontend/01-app-router-layout.md)
2. [frontend/02-auth-pages.md](frontend/02-auth-pages.md)
3. [frontend/03-dashboard-organization.md](frontend/03-dashboard-organization.md)
4. [frontend/04-task-ui-flow.md](frontend/04-task-ui-flow.md)
5. [frontend/05-settings-billing.md](frontend/05-settings-billing.md)
6. [frontend/06-code-blueprint-ui-form.md](frontend/06-code-blueprint-ui-form.md)

End-to-end:

- [full-flow.md](full-flow.md)

## Code Blueprint Praktis

Untuk implementasi langsung, baca:

1. [backend/08-code-blueprint-response-error.md](backend/08-code-blueprint-response-error.md) untuk response, error, dan result.
2. [backend/09-code-blueprint-identity-organization-task.md](backend/09-code-blueprint-identity-organization-task.md) untuk domain task, use case, repository, tRPC router, RBAC role/permission, dan contoh input.
3. [frontend/06-code-blueprint-ui-form.md](frontend/06-code-blueprint-ui-form.md) untuk form, API state, permission-aware UI, dan handling error `FORBIDDEN`.