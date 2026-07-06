# Enterprise & Scalable Stack - .NET Atau Spring Boot

Stack ini fokus pada backend besar yang aman, reliable, mudah diaudit, dan cocok untuk organisasi enterprise.

## Komponen

- Frontend: Angular atau React + TypeScript.
- Backend: .NET atau Spring Boot.
- Database: PostgreSQL atau SQL Server.
- Produk contoh: SaaS task workspace atau e-commerce admin.

## Struktur Materi

Backend:

1. [backend/01-solution-setup.md](backend/01-solution-setup.md)
2. [backend/02-modular-monolith-layers.md](backend/02-modular-monolith-layers.md)
3. [backend/03-identity-security.md](backend/03-identity-security.md)
4. [backend/04-tenant-and-authorization.md](backend/04-tenant-and-authorization.md)
5. [backend/05-business-module.md](backend/05-business-module.md)
6. [backend/06-provider-abstract-factory.md](backend/06-provider-abstract-factory.md)
7. [backend/07-observability-deployment.md](backend/07-observability-deployment.md)
8. [backend/08-code-blueprint-dotnet.md](backend/08-code-blueprint-dotnet.md)
9. [backend/09-code-blueprint-spring.md](backend/09-code-blueprint-spring.md)

Frontend:

1. [frontend/01-app-shell.md](frontend/01-app-shell.md)
2. [frontend/02-auth-and-guards.md](frontend/02-auth-and-guards.md)
3. [frontend/03-admin-dashboard.md](frontend/03-admin-dashboard.md)
4. [frontend/04-business-workflow-ui.md](frontend/04-business-workflow-ui.md)
5. [frontend/05-audit-and-operations-ui.md](frontend/05-audit-and-operations-ui.md)
6. [frontend/06-code-blueprint-angular-react.md](frontend/06-code-blueprint-angular-react.md)

End-to-end:

- [full-flow.md](full-flow.md)

## Code Blueprint Praktis

Untuk implementasi langsung, baca:

1. [backend/08-code-blueprint-dotnet.md](backend/08-code-blueprint-dotnet.md) untuk .NET response, result, domain, handler, endpoint, RBAC role/permission, dan contoh input.
2. [backend/09-code-blueprint-spring.md](backend/09-code-blueprint-spring.md) untuk Spring controller, use case, policy RBAC, dan request body.
3. [frontend/06-code-blueprint-angular-react.md](frontend/06-code-blueprint-angular-react.md) untuk Angular/React service, component, permission-aware UI, dan handling `403`.