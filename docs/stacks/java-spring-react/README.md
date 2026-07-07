# Java Spring React Stack - SpringReact Modular SaaS Mockup

## Tujuan File

File ini adalah index utama untuk seri dokumentasi `java-spring-react`. Seri ini membangun mockup full web app bernama **SpringReact Modular SaaS Mockup** dari nol sampai bisa berjalan lokal dengan Spring Boot, React Vite SPA, PostgreSQL, Flyway, JPA/Hibernate, JWT auth, dan Docker Compose.

## Problem Yang Diselesaikan

Pemula sering bingung menyambungkan backend enterprise-style dengan frontend modern. Tutorial ini memecah proses menjadi langkah kecil: setup project, arsitektur modular monolith, database migration, auth, tenancy, CRUD project/task, frontend dashboard, testing, Docker, dan flow end-to-end.

## Konsep Utama

- Backend memakai **modular monolith**: satu aplikasi deployable, tetapi dipisah per business module.
- Tiap module backend memakai **layered architecture**: `domain`, `application`, `infrastructure`, `presentation`.
- Frontend memakai **feature-based architecture** di React Vite SPA.
- API selalu memakai response envelope:

`jsonc
// docs/stacks/java-spring-react/README.md response success example
{
  "success": true,
  "data": {},
  "errors": []
}
```

## Pilihan Teknologi Yang Tersedia

- Backend: Spring Boot, NestJS, ASP.NET Core, Laravel, Django.
- Frontend: React Vite SPA, framework rendering server-side React, Vue, Angular, SvelteKit.
- Database: PostgreSQL, MySQL, SQL Server, SQLite.
- Migration: Flyway, Liquibase, Prisma migrate.
- Auth: JWT, session cookie, OAuth/OIDC.
- Deployment lokal: Docker Compose, dev server manual, Kubernetes lokal.

## Pilihan Yang Dipakai Di Tutorial Ini

- Java 21
- Spring Boot stable terbaru
- Maven
- Spring Web
- Spring Security
- Spring Data JPA / Hibernate
- PostgreSQL
- Flyway
- JWT access token + refresh token database
- React Vite SPA + TypeScript
- Tailwind CSS + shadcn/ui
- Typed API client
- Docker Compose

## Struktur Folder Yang Akan Dibuat

```text
springreact-modular-saas-mockup/
  backend/
  frontend/
  docker-compose.yml
  .env.example
  docs/
    stacks/
      java-spring-react/
```

Struktur dokumentasi:

```text
docs/stacks/java-spring-react/
  README.md
  backend/
  frontend/
  full-flow/
  patterns/
  mock-flow/
```

## Command Yang Harus Dijalankan

```bash
# dari root repository dokumentasi ini
cd docs/stacks/java-spring-react
```

Command di file ini hanya untuk membaca dokumentasi. Command pembuatan aplikasi ada di file backend, frontend, dan full-flow.

## Full Source Code Untuk File Yang Dibuat

File ini tidak membuat source code aplikasi. Source code lengkap ditulis bertahap di file berikut:

- [backend/01-project-setup.md](backend/01-project-setup.md)
- [backend/03-database-flyway-jpa.md](backend/03-database-flyway-jpa.md)
- [backend/04-common-response-error-pattern.md](backend/04-common-response-error-pattern.md)
- [backend/05-identity-auth-module.md](backend/05-identity-auth-module.md)
- [frontend/04-api-client-response-error.md](frontend/04-api-client-response-error.md)
- [mock-flow/00-mockup-ready-fullstack.md](mock-flow/00-mockup-ready-fullstack.md)

## Penjelasan Kode Penting

Kode aplikasi tidak ditaruh di README agar jalur belajar tetap mudah diikuti. README berfungsi seperti daftar isi. Untuk implementasi, ikuti file secara berurutan.

## Cara Menjalankan

Untuk menjalankan keseluruhan mockup:

```bash
cd springreact-modular-saas-mockup
docker compose up -d
```

Versi lengkap ada di [full-flow/02-docker-compose.md](full-flow/02-docker-compose.md).

## Cara Test Manual

Setelah semua langkah selesai:

1. Jika memakai Docker Compose, buka frontend di `http://localhost:3000`. Jika menjalankan manual dengan `pnpm dev`, buka `http://localhost:5173`.
2. Login dengan `owner@example.com / Password123!`.
3. Buat organization.
4. Buat project.
5. Buat task.
6. Ubah status task dari `TODO` ke `IN_PROGRESS`, lalu `DONE`.
7. Logout.

## Troubleshooting

- Jika backend gagal connect database, cek `SPRING_DATASOURCE_URL`.
- Jika frontend mendapat `UNAUTHORIZED`, cek access token di storage dan endpoint refresh token.
- Jika migration gagal, cek urutan file `V1` sampai `V5`.
- Jika Docker port bentrok, ubah port host di `docker-compose.yml`.

## Checklist Akhir

- [ ] Backend Spring Boot dibuat.
- [ ] PostgreSQL dan Flyway migration berjalan.
- [ ] Auth JWT access + refresh token tersedia.
- [ ] Organization tenant isolation berjalan.
- [ ] Project dan task CRUD tersedia.
- [ ] Frontend React Vite punya login, register, dashboard, project list, task board.
- [ ] Docker Compose bisa menjalankan PostgreSQL, backend, dan frontend.

## File Lanjutan Berikutnya

Mulai dari [backend/01-project-setup.md](backend/01-project-setup.md).

## Struktur Materi

Backend:

1. [backend/01-project-setup.md](backend/01-project-setup.md)
2. [backend/02-modular-monolith-layered-architecture.md](backend/02-modular-monolith-layered-architecture.md)
3. [backend/03-database-flyway-jpa.md](backend/03-database-flyway-jpa.md)
4. [backend/04-common-response-error-pattern.md](backend/04-common-response-error-pattern.md)
5. [backend/05-identity-auth-module.md](backend/05-identity-auth-module.md)
6. [backend/06-organization-tenancy-module.md](backend/06-organization-tenancy-module.md)
7. [backend/07-project-module.md](backend/07-project-module.md)
8. [backend/08-task-module.md](backend/08-task-module.md)
9. [backend/09-testing-backend.md](backend/09-testing-backend.md)

Frontend:

1. [frontend/01-project-setup-vite-react.md](frontend/01-project-setup-vite-react.md)
2. [frontend/02-frontend-architecture.md](frontend/02-frontend-architecture.md)
3. [frontend/03-layout-routing-auth.md](frontend/03-layout-routing-auth.md)
4. [frontend/04-api-client-response-error.md](frontend/04-api-client-response-error.md)
5. [frontend/05-auth-pages.md](frontend/05-auth-pages.md)
6. [frontend/06-dashboard-organization-project-task.md](frontend/06-dashboard-organization-project-task.md)
7. [frontend/07-testing-frontend.md](frontend/07-testing-frontend.md)

Full flow:

1. [full-flow/01-run-local-development.md](full-flow/01-run-local-development.md)
2. [full-flow/02-docker-compose.md](full-flow/02-docker-compose.md)
3. [full-flow/03-end-to-end-flow.md](full-flow/03-end-to-end-flow.md)
4. [full-flow/04-deployment-notes.md](full-flow/04-deployment-notes.md)

Patterns:

1. [patterns/01-design-patterns-used.md](patterns/01-design-patterns-used.md)
2. [patterns/02-refactoring-guru-mapping.md](patterns/02-refactoring-guru-mapping.md)

Mock flow:

1. [mock-flow/00-mockup-ready-fullstack.md](mock-flow/00-mockup-ready-fullstack.md)












