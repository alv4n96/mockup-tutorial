# Backend 03 - Database PostgreSQL, Flyway, Dan JPA

## Tujuan File

Membuat schema PostgreSQL dengan Flyway dan entity JPA untuk user, refresh token, organization, project, dan task.

## Problem Yang Diselesaikan

Database harus punya struktur yang konsisten di semua mesin developer. Jangan mengandalkan Hibernate membuat tabel otomatis untuk aplikasi serius.

## Konsep Utama

- Flyway menyimpan perubahan database sebagai file migration.
- JPA/Hibernate memetakan table ke entity Java.
- Tenant isolation disimpan lewat `organization_id` di `projects`; task mengikuti tenant lewat `project_id`.

## Pilihan Teknologi Yang Tersedia

- Hibernate `ddl-auto=create`: cepat untuk eksperimen, rawan drift.
- Flyway: migration SQL sederhana dan eksplisit.
- Liquibase: migration lebih kaya, tetapi lebih verbose.

## Pilihan Yang Dipakai Di Tutorial Ini

Flyway SQL migration + JPA entity + Spring Data repository.

## Struktur Folder Yang Akan Dibuat

```text
backend/src/main/resources/db/migration/
  V1__init_identity.sql
  V2__init_organization.sql
  V3__init_project.sql
  V4__init_task.sql
  V5__seed_mock_data.sql
```

## Command Yang Harus Dijalankan

```bash
cd backend
mkdir -p src/main/resources/db/migration
./mvnw spring-boot:run
```

Flyway otomatis menjalankan migration saat aplikasi start.

## Full Source Code Untuk Setiap File Yang Dibuat

```sql
-- backend/src/main/resources/db/migration/V1__init_identity.sql
create table users (
  id uuid primary key,
  email varchar(255) not null unique,
  name varchar(120) not null,
  password_hash varchar(255) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table refresh_tokens (
  id uuid primary key,
  user_id uuid not null references users(id) on delete cascade,
  token_hash varchar(255) not null unique,
  expires_at timestamptz not null,
  revoked_at timestamptz null,
  created_at timestamptz not null default now()
);

create index idx_refresh_tokens_user_id on refresh_tokens(user_id);
```

```sql
-- backend/src/main/resources/db/migration/V2__init_organization.sql
create table organizations (
  id uuid primary key,
  name varchar(160) not null,
  slug varchar(180) not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table organization_members (
  id uuid primary key,
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  role varchar(30) not null,
  created_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create index idx_org_members_user_id on organization_members(user_id);
create index idx_org_members_org_id on organization_members(organization_id);
```

```sql
-- backend/src/main/resources/db/migration/V3__init_project.sql
create table projects (
  id uuid primary key,
  organization_id uuid not null references organizations(id) on delete cascade,
  name varchar(160) not null,
  description text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_projects_organization_id on projects(organization_id);
```

```sql
-- backend/src/main/resources/db/migration/V4__init_task.sql
create table tasks (
  id uuid primary key,
  project_id uuid not null references projects(id) on delete cascade,
  title varchar(200) not null,
  description text null,
  status varchar(30) not null,
  priority varchar(30) not null,
  due_date date null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_tasks_project_id on tasks(project_id);
create index idx_tasks_status on tasks(status);
```

```sql
-- backend/src/main/resources/db/migration/V5__seed_mock_data.sql
insert into users (id, email, name, password_hash, created_at, updated_at) values
('00000000-0000-0000-0000-000000000001', 'owner@example.com', 'Owner User', '$2a$10$7EqJtq98hPqEX7fNZaFWoOQGL5FLO7hYkQj5uNnY5gT0YV2KqL7i.', now(), now()),
('00000000-0000-0000-0000-000000000002', 'admin@example.com', 'Admin User', '$2a$10$7EqJtq98hPqEX7fNZaFWoOQGL5FLO7hYkQj5uNnY5gT0YV2KqL7i.', now(), now()),
('00000000-0000-0000-0000-000000000003', 'member@example.com', 'Member User', '$2a$10$7EqJtq98hPqEX7fNZaFWoOQGL5FLO7hYkQj5uNnY5gT0YV2KqL7i.', now(), now());

insert into organizations (id, name, slug, created_at, updated_at) values
('10000000-0000-0000-0000-000000000001', 'Acme Workspace', 'acme-workspace', now(), now());

insert into organization_members (id, organization_id, user_id, role, created_at) values
('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'OWNER', now()),
('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'ADMIN', now()),
('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'MEMBER', now());

insert into projects (id, organization_id, name, description, created_at, updated_at) values
('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Website Launch', 'Mock project untuk dashboard awal.', now(), now());

insert into tasks (id, project_id, title, description, status, priority, due_date, created_at, updated_at) values
('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'Setup backend', 'Membuat Spring Boot API.', 'DONE', 'HIGH', null, now(), now()),
('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 'Build dashboard', 'Membuat task board sederhana.', 'IN_PROGRESS', 'MEDIUM', null, now(), now()),
('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000001', 'Write tests', 'Menambahkan test minimum.', 'TODO', 'LOW', null, now(), now());
```

```java
// backend/src/main/java/com/example/springreact/modules/task/domain/TaskStatus.java
package com.example.springreact.modules.task.domain;

public enum TaskStatus {
  TODO,
  IN_PROGRESS,
  DONE
}
```

```java
// backend/src/main/java/com/example/springreact/modules/task/domain/TaskPriority.java
package com.example.springreact.modules.task.domain;

public enum TaskPriority {
  LOW,
  MEDIUM,
  HIGH
}
```

```java
// backend/src/main/java/com/example/springreact/modules/organization/domain/OrganizationRole.java
package com.example.springreact.modules.organization.domain;

public enum OrganizationRole {
  OWNER,
  ADMIN,
  MEMBER
}
```

## Penjelasan Kode Penting

- `organization_members` menghubungkan user dan organization. Role tenant disimpan di sini.
- `projects.organization_id` adalah kolom tenant utama.
- `tasks.project_id` membuat task mengikuti tenant project.
- Seed user memakai BCrypt hash. Dalam implementasi lokal, pastikan hash sesuai `Password123!`.

## Cara Menjalankan

```bash
cd backend
./mvnw spring-boot:run
```

## Cara Test Manual

```bash
psql postgresql://springreact:springreact@localhost:5432/springreact
\dt
select email from users;
select name from organizations;
```

## Troubleshooting

- Jika `relation already exists`, database pernah dipakai. Buat database baru atau bersihkan schema dev.
- Jika seed login gagal, generate ulang BCrypt hash untuk `Password123!`.
- Jika migration tidak jalan, cek `spring.flyway.locations`.

## Checklist Akhir

- [ ] Semua migration `V1` sampai `V5` tersedia.
- [ ] Tabel `users`, `refresh_tokens`, `organizations`, `organization_members`, `projects`, dan `tasks` dibuat.
- [ ] Relasi tenant jelas.
- [ ] Enum role, status, dan priority tersedia.

## File Lanjutan Berikutnya

Lanjut ke [04-common-response-error-pattern.md](04-common-response-error-pattern.md).


