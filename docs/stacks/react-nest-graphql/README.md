# React Nest GraphQL Stack

Stack ini adalah panduan membangun web app mockup enterprise dengan React + TypeScript di frontend, NestJS + GraphQL di backend, PostgreSQL sebagai database, Prisma sebagai ORM, Docker Compose untuk local development, dan Kubernetes sebagai blueprint deployment.

Contoh domain aplikasi yang dipakai adalah Project Management App atau SaaS Task Workspace. Aplikasi akhir akan memiliki authentication, tenant/organization, project, task, role sederhana, audit log, validasi, pagination, error handling GraphQL, dashboard frontend, dan deployment blueprint.

## Ringkasan Stack

Komponen utama:

- Frontend: React + TypeScript dengan Vite.
- Backend: Node.js dengan NestJS.
- API layer: GraphQL menggunakan package NestJS GraphQL dan Apollo.
- Database: PostgreSQL.
- ORM: Prisma.
- Local infra: Docker Compose.
- Deployment blueprint: Kubernetes manifests.
- Arsitektur: Modular Monolith, Layered Architecture, dan domain-driven module boundary sederhana.

Flow utama:

```txt
React Frontend -> GraphQL API NestJS -> Service Layer -> Repository -> Prisma -> PostgreSQL
```

## Kapan Stack Ini Cocok Dipakai

Stack ini cocok dipakai saat:

- Tim ingin membangun aplikasi SaaS internal atau enterprise dengan struktur module yang jelas.
- Frontend dan backend dipisah, tetapi tetap berada dalam satu repository atau satu workspace.
- Data aplikasi cukup relasional, misalnya user, organization, project, task, role, dan audit log.
- API membutuhkan query fleksibel dari frontend, sehingga GraphQL lebih nyaman dibanding REST untuk beberapa layar dashboard.
- Tim ingin type safety yang baik dari database sampai GraphQL schema dan frontend.
- Aplikasi masih cocok sebagai modular monolith sebelum dipisah menjadi microservices.

Stack ini kurang cocok jika:

- Produk sangat sederhana dan REST CRUD biasa sudah cukup.
- Tim belum siap memelihara GraphQL schema, resolver, input type, dan query client.
- Domain sudah sangat besar dan butuh deployment service terpisah sejak awal.
- Tim ingin serverless-first architecture tanpa proses backend Node.js yang berjalan terus.

## Kelebihan dan Trade-off

Kelebihan:

- Modular monolith menjaga deployment tetap sederhana, tetapi kode tetap terpisah per domain.
- NestJS module system membantu struktur backend lebih rapi untuk tim junior sampai senior.
- GraphQL membuat frontend bisa mengambil data sesuai kebutuhan layar.
- Prisma mempercepat schema modeling, migration, query, dan type-safe database access.
- PostgreSQL kuat untuk data enterprise yang relasional.
- Docker Compose membuat local development lebih konsisten.
- Kubernetes manifests memberi gambaran deployment produksi tanpa mengunci ke vendor tertentu.

Trade-off:

- GraphQL menambah konsep baru: schema, resolver, input type, object type, query, mutation, dan error shape.
- Prisma migration harus disiplin agar schema database tidak menyimpang dari kode.
- Modular monolith tetap butuh aturan dependency antar module agar tidak berubah menjadi kode campur aduk.
- Kubernetes memberi fleksibilitas deployment, tetapi lebih kompleks dibanding platform managed sederhana.
- Role/permission sederhana cukup untuk mockup enterprise awal, tetapi produk nyata biasanya butuh authorization policy yang lebih detail.

## Arsitektur High-level

Stack ini memakai Modular Monolith. Artinya satu backend NestJS tetap dideploy sebagai satu aplikasi, tetapi kode dipecah menjadi module domain:

- Identity: register, login, password hashing, JWT, current user.
- Organizations: tenant, membership, role user dalam organization.
- Projects: project workspace, status project, ownership organization.
- Tasks: task, assignee, priority, status, due date.
- Audit Log: catatan aktivitas penting seperti login, create project, update task.

Layer utama backend:

- GraphQL Resolver: menerima query/mutation dari frontend.
- Service/Application Layer: menjalankan use case dan validasi bisnis.
- Repository Layer: menyembunyikan detail query database.
- Prisma Infrastructure: koneksi database dan transaction.
- PostgreSQL: penyimpanan data.

Diagram sederhana:

```txt
+--------------------+
| React + TypeScript |
| Vite Frontend      |
+---------+----------+
          |
          | GraphQL query/mutation
          v
+---------+----------+
| NestJS GraphQL API |
| Resolver Layer     |
+---------+----------+
          |
          v
+---------+----------+
| Service Layer      |
| Use Case Logic     |
+---------+----------+
          |
          v
+---------+----------+
| Repository Layer   |
| Domain Data Access |
+---------+----------+
          |
          v
+---------+----------+
| Prisma Client      |
+---------+----------+
          |
          v
+---------+----------+
| PostgreSQL         |
+--------------------+
```

## Design Pattern Yang Dipakai

Dokumentasi stack ini menggunakan beberapa pattern praktis. Konsepnya terinspirasi dari katalog design pattern umum seperti Refactoring Guru, tetapi penjelasan dan contoh kode dibuat ulang untuk kebutuhan stack ini.

Pattern utama:

- Dependency Injection: dipakai oleh NestJS untuk memasukkan service, repository, PrismaService, guard, dan provider lain.
- Repository Pattern: dipakai agar service tidak langsung bergantung pada detail query Prisma.
- Result Pattern: dipakai untuk membedakan sukses dan gagal pada use case tanpa menyebar exception secara liar.
- Unit of Work via Prisma transaction: dipakai saat satu use case perlu menulis beberapa tabel secara atomik.
- Strategy Pattern: dipakai untuk variasi authorization atau policy sederhana bila role bertambah.
- Factory Method: dipakai untuk membuat error atau audit event secara konsisten.
- Adapter: dipakai saat membungkus library eksternal seperti bcrypt, JWT, atau Prisma agar domain tidak terlalu melekat ke library.
- Facade: dipakai untuk menyederhanakan akses beberapa operasi infra, misalnya PrismaService atau AuthService.
- Specification-like filtering: dipakai untuk filter list project/task berdasarkan status, assignee, search, dan tenant.

Setiap file backend lanjutan akan menjelaskan:

- Masalah yang diselesaikan pattern.
- Kenapa pattern dipilih.
- File mana yang memakai pattern.
- Alternatif jika pattern tidak dipakai.

## Struktur Dokumentasi

Target struktur lengkap:

```txt
docs/stacks/react-nest-graphql/
├── README.md
├── backend/
│   ├── 01-project-setup.md
│   ├── 02-modular-monolith-layers.md
│   ├── 03-identity-auth.md
│   ├── 04-organization-tenancy.md
│   ├── 05-project-module.md
│   ├── 06-task-module.md
│   ├── 07-graphql-api-pattern.md
│   ├── 08-database-migration-seed.md
│   └── 09-testing-deployment.md
│
├── frontend/
│   ├── 10-frontend-setup.md
│   ├── 11-frontend-auth-dashboard.md
│   ├── 12-frontend-graphql-client.md
│   └── 13-frontend-project-task.md
│
├── infra/
│   ├── 14-docker-compose.md
│   ├── 15-kubernetes-deployment.md
│   └── 16-production-readiness.md
│
└── mockup-flow/
    ├── 01-user-flow.md
    ├── 02-api-flow.md
    └── 03-deployment-flow.md
```

Dokumen yang sudah dimulai:

1. [backend/01-project-setup.md](backend/01-project-setup.md)

Dokumen lanjutan akan dibuat bertahap agar setiap bagian bisa menjadi panduan implementasi nyata, bukan hanya daftar teori.

## Urutan Belajar

Ikuti urutan ini:

1. Baca README ini untuk memahami gambaran stack.
2. Bangun backend kosong dengan [backend/01-project-setup.md](backend/01-project-setup.md).
3. Lanjutkan ke module boundary dan layered architecture.
4. Implementasikan identity/auth.
5. Implementasikan organization/tenant.
6. Implementasikan project dan task.
7. Rapikan GraphQL response, error handling, validation, pagination, dan audit log.
8. Buat seed database.
9. Bangun frontend React dashboard, protected route, dan GraphQL client.
10. Jalankan local dengan Docker Compose.
11. Siapkan blueprint Kubernetes.

## Target Akhir Aplikasi

Target akhir mockup:

- User bisa register dan login.
- User bisa membuat atau bergabung ke organization.
- User memiliki role sederhana dalam organization.
- User bisa membuat project dalam organization.
- User bisa membuat, mengubah, memfilter, dan menyelesaikan task.
- Dashboard frontend menampilkan ringkasan project dan task.
- Backend menyimpan audit log untuk aksi penting.
- API menggunakan GraphQL query dan mutation.
- Validasi input berjalan di backend.
- Error GraphQL memiliki format yang konsisten.
- Pagination tersedia untuk list project, task, dan audit log.
- Database bisa dimigrasi dan di-seed.
- Local development berjalan dengan Docker Compose.
- Deployment production memiliki blueprint Kubernetes.

## Catatan Infra

Local development:

- PostgreSQL dijalankan dengan Docker Compose.
- Backend NestJS berjalan di mesin developer dengan `npm run start:dev`.
- Frontend Vite berjalan di mesin developer dengan `npm run dev`.
- Database URL mengarah ke PostgreSQL container di `localhost:5432`.

Deployment blueprint:

- Backend dibungkus menjadi Docker image.
- Frontend dibuild menjadi static assets atau image web server.
- PostgreSQL production sebaiknya memakai managed database atau StatefulSet dengan backup yang jelas.
- Kubernetes manifests akan mencakup Deployment, Service, ConfigMap, Secret, dan Ingress blueprint.

