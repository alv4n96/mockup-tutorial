# TypeScript Vue/Nest Stack

Stack ini menjadi pembanding untuk pembelajaran modular monolith TypeScript di luar ekosistem Next.js.

## Komponen

- Frontend: Vue 3, Vite, Vuetify.
- Backend: NestJS modular monolith.
- Database: PostgreSQL dengan Prisma atau TypeORM.
- Produk contoh: task workspace atau e-commerce admin.

## Struktur Materi

Backend:

1. [backend/01-nest-project-setup.md](backend/01-nest-project-setup.md)
2. [backend/02-module-boundaries.md](backend/02-module-boundaries.md)
3. [backend/03-identity-organization.md](backend/03-identity-organization.md)
4. [backend/04-business-module.md](backend/04-business-module.md)
5. [backend/05-testing-deployment.md](backend/05-testing-deployment.md)
6. [backend/06-code-blueprint-nest-response.md](backend/06-code-blueprint-nest-response.md)
7. [backend/07-code-blueprint-task-module.md](backend/07-code-blueprint-task-module.md)

Frontend:

1. [frontend/01-vue-app-shell.md](frontend/01-vue-app-shell.md)
2. [frontend/02-auth-flow.md](frontend/02-auth-flow.md)
3. [frontend/03-dashboard-and-crud.md](frontend/03-dashboard-and-crud.md)
4. [frontend/04-code-blueprint-vue-composable.md](frontend/04-code-blueprint-vue-composable.md)

End-to-end:

- [full-flow.md](full-flow.md)

## Code Blueprint Praktis

Untuk implementasi langsung, baca:

1. [backend/06-code-blueprint-nest-response.md](backend/06-code-blueprint-nest-response.md) untuk response envelope, exception filter, dan interceptor.
2. [backend/07-code-blueprint-task-module.md](backend/07-code-blueprint-task-module.md) untuk NestJS module, DTO, domain entity, repository, use case, controller, RBAC role/permission, dan contoh input.
3. [frontend/04-code-blueprint-vue-composable.md](frontend/04-code-blueprint-vue-composable.md) untuk API client, composable, form, permission-aware UI, dan handling `FORBIDDEN`.