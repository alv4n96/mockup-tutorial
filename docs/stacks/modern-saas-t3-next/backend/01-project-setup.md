# Backend 01 - Project Setup

File ini menjelaskan setup awal backend untuk stack `modern-saas-t3-next` dari folder kosong sampai fondasi backend SaaS task workspace siap dipakai.

Target akhirnya bukan sekadar project Next.js bisa jalan, tetapi project sudah punya server layer, tRPC router, ORM database, environment validation, health check, script development, dan struktur folder yang siap menerima module `identity`, `organizations`, `projects`, dan `tasks`.

Stack `modern-saas-t3-next` cocok untuk modern SaaS task workspace karena fokus pada type safety dari API sampai database access, iterasi cepat untuk startup/SaaS, struktur modular, deployment mudah ke Vercel, dan PostgreSQL sebagai database utama.

Next.js sering dianggap frontend framework. Di stack ini, Next.js juga menjadi backend melalui server layer, Route Handler, API route, tRPC, Prisma atau Drizzle, dan database. UI frontend tetap akan dibahas di folder `frontend/`, sedangkan file ini fokus ke fondasi backend.

## Konsep Dasar

### Next.js

Next.js adalah framework React untuk membuat aplikasi web. Selain page dan UI, Next.js punya fitur backend seperti Route Handler, Server Component, middleware, dan server-side runtime. Di stack ini, Next.js menjadi tempat API backend berjalan.

### T3 Stack

T3 Stack adalah gaya stack TypeScript fullstack yang biasanya memakai Next.js, TypeScript, tRPC, ORM seperti Prisma atau Drizzle, dan authentication. Di dokumentasi ini kita memakai istilah T3-style, artinya tidak harus memakai generator T3 resmi, tetapi mengikuti prinsip TypeScript dari awal, API type-safe, database schema jelas, validation eksplisit, dan folder backend rapi.

### TypeScript

TypeScript adalah JavaScript dengan tipe. TypeScript membantu mendeteksi salah pemanggilan function, salah nama field, atau salah bentuk data sebelum aplikasi dijalankan. TypeScript bukan pengganti validation runtime. Data dari request HTTP, form, database, dan environment variable tetap perlu divalidasi.

### tRPC

tRPC adalah library untuk membuat API type-safe tanpa perlu menulis schema REST/OpenAPI manual. Router backend dapat dipanggil dari client dengan tipe otomatis. Jika procedure backend berubah, TypeScript membantu menemukan caller yang perlu diperbaiki.

### Prisma

Prisma adalah ORM untuk Node.js/TypeScript. Prisma menyediakan schema database, migration, dan Prisma Client untuk query database dengan API TypeScript. Dokumentasi utama file ini memakai Prisma karena lebih mudah dipahami pemula dan migration workflow-nya jelas.

### Drizzle

Drizzle adalah ORM TypeScript yang lebih dekat ke SQL. Drizzle ringan, eksplisit, dan cocok untuk developer yang ingin kontrol lebih dekat terhadap query. Drizzle dibahas sebagai alternatif. File ini tetap memakai Prisma untuk jalur utama.

### PostgreSQL

PostgreSQL adalah database relasional yang kuat dan umum dipakai untuk SaaS production. PostgreSQL cocok untuk data user, organization, membership, project, task, audit log, billing, dan permission.

### SQLite

SQLite adalah database file lokal. SQLite relevan untuk belajar cepat karena tidak perlu container database. Namun untuk SaaS multi-user dan deployment production, PostgreSQL lebih representatif.

### ORM

ORM atau Object Relational Mapper adalah layer untuk mengakses database memakai object/function di code. ORM membantu mapping table database ke model aplikasi. Contohnya table `users` di database menjadi model `User` di Prisma dan dipanggil dengan `prisma.user.findUnique(...)`.

### Schema Validation

Schema validation adalah proses memastikan data sesuai bentuk yang diharapkan saat runtime. Contohnya email wajib valid, task title tidak boleh kosong, dan priority hanya boleh nilai tertentu.

### Zod

Zod adalah library validation TypeScript-first. Zod sering dipakai bersama tRPC untuk validasi input procedure.

### Module

Module adalah pemisahan fitur berdasarkan domain. Untuk SaaS task workspace, module awalnya `identity`, `organizations`, `projects`, dan `tasks`. Tujuannya agar business logic tidak menumpuk di route handler.

### Server Layer

Server layer adalah bagian code yang hanya berjalan di server. Isinya bisa berupa tRPC router, service, repository, database client, auth helper, dan integration.

### Route Handler

Route Handler adalah file `route.ts` di App Router Next.js. File ini menerima request HTTP seperti `GET`, `POST`, `PUT`, dan `DELETE`.

```text
src/app/api/health/route.ts
```

### API Route

API route adalah endpoint backend yang bisa dipanggil melalui HTTP. Di App Router, API route dibuat dengan Route Handler.

```text
GET /api/health
POST /api/trpc/tasks.create
```

### Environment Variable

Environment variable adalah konfigurasi yang dibaca dari environment, misalnya database URL, secret auth, dan base URL aplikasi.

```text
DATABASE_URL="postgresql://..."
```

## Pilihan Stack

Pilihan utama untuk file ini:

- Next.js App Router sebagai runtime fullstack.
- TypeScript untuk type safety.
- tRPC untuk API type-safe.
- Prisma untuk database access jalur utama.
- PostgreSQL untuk database utama.
- Zod untuk validation.
- NextAuth/Auth.js sebagai preview untuk file auth berikutnya.
- Vercel sebagai target deployment natural untuk Next.js.

### Prisma vs Drizzle

Gunakan Prisma jika tim masih junior/middle, ingin migration workflow yang jelas, ingin Prisma Studio untuk cek data, dan ingin query API yang mudah dibaca.

Gunakan Drizzle jika tim nyaman dengan SQL, ingin query yang lebih eksplisit, ingin library lebih ringan, dan ingin kontrol lebih dekat ke struktur SQL.

Untuk dokumentasi utama file ini, gunakan Prisma dulu agar fondasinya mudah diikuti.

### PostgreSQL vs SQLite

Gunakan PostgreSQL jika ingin setup yang mirip production, butuh relational constraint yang kuat, akan deploy ke provider seperti Neon, Supabase, Railway, atau database managed lain, dan aplikasi punya banyak user serta organization.

Gunakan SQLite jika hanya belajar lokal, ingin setup sangat cepat, dan belum perlu container database. File ini memakai PostgreSQL karena targetnya modern SaaS task workspace.

### tRPC vs REST API

Gunakan tRPC jika frontend dan backend berada dalam repo TypeScript yang sama, ingin type-safe API tanpa generator tambahan, dan ingin integrasi natural dengan React Query.

Gunakan REST API jika API akan dipakai banyak client non-TypeScript, perlu kontrak publik yang stabil, atau perlu dokumentasi OpenAPI. Di stack ini, tRPC menjadi API utama. REST tetap dipakai untuk endpoint sederhana seperti health check.

### Next.js Fullstack vs Backend Terpisah

Next.js fullstack cocok jika tim kecil, ingin development cepat, produk masih startup/MVP, dan backend masih cukup berjalan sebagai server layer dalam satu aplikasi.

Backend terpisah cocok jika banyak service dengan skala berbeda, banyak consumer eksternal, perlu runtime khusus, atau organisasi engineering sudah besar. Untuk file ini, kita mulai dengan Next.js fullstack supaya fondasi SaaS bisa dibuat cepat dan tetap rapi.

## Output Akhir File Ini

Setelah mengikuti file ini, pembaca harus punya:

- project Next.js/T3-style siap jalan;
- TypeScript aktif;
- struktur folder backend/server rapi;
- tRPC basic router siap;
- database ORM siap;
- environment variable siap;
- validation package siap;
- script `dev`, `typecheck`, `lint`, `db:migrate`, dan `db:seed` siap;
- health check endpoint sederhana;
- fondasi yang bisa dilanjutkan ke `02-modular-monolith-layers.md`.

## Setup Dari Folder Kosong

Jalankan command berikut dari folder parent tempat project akan dibuat:

```bash
npx create-next-app@latest modern-saas-t3-next
```

Penjelasan:

- `npx` menjalankan package npm tanpa harus install global.
- `create-next-app` adalah generator resmi untuk membuat project Next.js.
- `@latest` memastikan generator yang dipakai versi terbaru.
- `modern-saas-t3-next` adalah nama folder project agar sesuai dengan struktur stack dokumentasi ini.

Jika folder sudah ada karena repo dokumentasi ini sudah dibuat, command ini dipakai sebagai referensi saat membuat aplikasi nyata di workspace terpisah.

## Pilihan `create-next-app`

Saat menjalankan `create-next-app`, CLI akan bertanya beberapa hal. Rekomendasi untuk stack ini:

| Prompt | Pilihan | Alasan |
| --- | --- | --- |
| TypeScript | Yes | Backend dan API akan type-safe. |
| ESLint | Yes | Membantu menjaga kualitas code. |
| Tailwind CSS | Yes | Dipakai nanti untuk frontend, walau file ini tidak fokus ke UI. |
| `src/` directory | Yes | Struktur project lebih rapi. |
| App Router | Yes | Route Handler dan server layer modern Next.js memakai App Router. |
| Turbopack | Yes untuk dev cepat, No jika ingin lebih stabil | Turbopack cepat, tetapi jika ada issue package, gunakan bundler stabil. |
| Import alias | Yes | Import lebih rapi. |
| Import alias value | `@/*` | Standar umum untuk menunjuk ke `src/*`. |

Konsekuensi pilihan:

- Jika TypeScript `No`, type safety tRPC dan Prisma tidak maksimal.
- Jika ESLint `No`, error style dan potensi bug lebih mudah lolos.
- Jika Tailwind `No`, tidak masalah untuk backend, tetapi frontend nanti perlu setup manual.
- Jika `src/` directory `No`, struktur file akan berada langsung di root project.
- Jika App Router `No`, dokumentasi Route Handler di file ini tidak cocok.
- Jika Turbopack bermasalah, jalankan dev tanpa Turbopack sesuai kebutuhan project.
- Jika import alias berbeda dari `@/*`, semua contoh import di dokumentasi ini harus disesuaikan.

## Install Dependency Backend

Masuk ke folder project:

```bash
cd modern-saas-t3-next
```

Install tRPC:

```bash
npm install @trpc/server @trpc/client @trpc/react-query @trpc/next
```

Install React Query:

```bash
npm install @tanstack/react-query
```

Install validation dan serializer:

```bash
npm install zod superjson
```

Install Prisma:

```bash
npm install prisma @prisma/client
```

Install `tsx` untuk menjalankan TypeScript script seperti seed:

```bash
npm install -D tsx
```

Fungsi package:

- `@trpc/server`: membuat router dan procedure backend.
- `@trpc/client`: client dasar untuk memanggil tRPC API.
- `@trpc/react-query`: integrasi tRPC dengan React Query.
- `@trpc/next`: helper tRPC untuk Next.js.
- `@tanstack/react-query`: caching dan request state untuk client.
- `zod`: validasi runtime.
- `superjson`: serializer agar tipe seperti `Date` lebih aman dikirim lewat API.
- `prisma`: CLI Prisma untuk init, generate, migrate, dan studio.
- `@prisma/client`: client runtime untuk query database.
- `tsx`: menjalankan file TypeScript langsung tanpa compile manual.

## Alternatif Drizzle

Bagian ini opsional. Jika memilih Drizzle, install:

```bash
npm install drizzle-orm postgres
```

```bash
npm install -D drizzle-kit
```

Pilih Drizzle jika tim ingin query lebih dekat ke SQL, library lebih ringan, dan kontrol schema lebih eksplisit.

Pilih Prisma jika tim ingin onboarding lebih mudah, migration command jelas, Prisma Studio, dan dokumentasi pemula yang lebih banyak.

Untuk file ini, lanjutkan dengan Prisma.

## Setup Prisma

Jalankan:

```bash
npx prisma init
```

Command ini membuat:

- `prisma/schema.prisma`: file schema Prisma untuk datasource, generator, model, enum, dan relation.
- `.env`: file environment variable lokal.

Fungsi penting:

- `prisma/schema.prisma` mendeskripsikan struktur database dan model TypeScript yang akan dibuat.
- `.env` menyimpan `DATABASE_URL` lokal.
- Prisma Client dibuat dari schema dan dipakai oleh aplikasi untuk query database.

## Environment Variable

Buat atau update file `.env`:

```dotenv
# .env
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/modern_saas_t3_next?schema=public"
NEXT_PUBLIC_APP_URL="http://localhost:3000"
```

Penjelasan:

- `DATABASE_URL` dipakai server untuk koneksi ke PostgreSQL.
- `DATABASE_URL` tidak boleh diekspos ke browser karena berisi credential database.
- Variable tanpa prefix `NEXT_PUBLIC_` hanya boleh dipakai di server.
- Variable dengan prefix `NEXT_PUBLIC_` bisa ikut dibundle ke browser.
- `NEXT_PUBLIC_APP_URL` aman untuk browser karena hanya berisi URL aplikasi.
- Jangan commit secret production ke repository.

Untuk production di Vercel, isi environment variable lewat dashboard Vercel, bukan hardcode di file.

## Docker Compose PostgreSQL Lokal

Buat file `docker-compose.yml` di root project:

```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:16-alpine
    container_name: modern-saas-t3-next-postgres
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: modern_saas_t3_next
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

Jalankan database:

```bash
docker compose up -d
```

Cek container:

```bash
docker compose ps
```

Expected output secara konsep:

```text
NAME                           IMAGE                STATUS          PORTS
modern-saas-t3-next-postgres   postgres:16-alpine   Up              0.0.0.0:5432->5432/tcp
```

Jika port `5432` sudah dipakai, ubah mapping port kiri, misalnya `"5433:5432"`, lalu sesuaikan `DATABASE_URL` menjadi `localhost:5433`.

## Prisma Schema Awal

Update file `prisma/schema.prisma`:

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum OrganizationRole {
  OWNER
  ADMIN
  MEMBER
}

enum TaskStatus {
  TODO
  IN_PROGRESS
  DONE
  CANCELED
}

enum TaskPriority {
  LOW
  MEDIUM
  HIGH
  URGENT
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  organizationMembers OrganizationMember[]
  auditLogs           AuditLog[]
}

model Organization {
  id        String   @id @default(cuid())
  name      String
  slug      String   @unique
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  members   OrganizationMember[]
  projects  Project[]
  tasks     Task[]
  auditLogs AuditLog[]
}

model OrganizationMember {
  id             String           @id @default(cuid())
  userId         String
  organizationId String
  role           OrganizationRole @default(MEMBER)
  createdAt      DateTime         @default(now())
  updatedAt      DateTime         @updatedAt

  user         User         @relation(fields: [userId], references: [id], onDelete: Cascade)
  organization Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)

  @@unique([userId, organizationId])
  @@index([organizationId])
}

model Project {
  id             String   @id @default(cuid())
  organizationId String
  name           String
  slug           String
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt

  organization Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  tasks        Task[]

  @@unique([organizationId, slug])
  @@index([organizationId])
}

model Task {
  id             String       @id @default(cuid())
  organizationId String
  projectId      String
  title          String
  description    String?
  status         TaskStatus   @default(TODO)
  priority       TaskPriority @default(MEDIUM)
  dueDate        DateTime?
  createdAt      DateTime     @default(now())
  updatedAt      DateTime     @updatedAt

  organization Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  project      Project      @relation(fields: [projectId], references: [id], onDelete: Cascade)

  @@index([organizationId])
  @@index([projectId])
  @@index([status])
}

model AuditLog {
  id             String   @id @default(cuid())
  organizationId String
  actorUserId    String?
  action         String
  entityType     String
  entityId       String?
  metadata       Json?
  createdAt      DateTime @default(now())

  organization Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  actor        User?        @relation(fields: [actorUserId], references: [id], onDelete: SetNull)

  @@index([organizationId])
  @@index([actorUserId])
  @@index([entityType, entityId])
}
```

Schema ini masih fondasi. Detail auth, organization tenancy, project, task workflow, permission, dan audit behavior akan dibahas di file berikutnya.

## Migration Pertama

Jalankan:

```bash
npx prisma migrate dev --name init
```

Migration adalah riwayat perubahan schema database. Prisma akan membaca `prisma/schema.prisma`, membuat file SQL migration di `prisma/migrations/...`, menjalankan migration ke database lokal, dan generate Prisma Client.

Expected output secara konsep:

```text
Applying migration `20260707000000_init`

The following migration(s) have been created and applied from new schema changes:

prisma/migrations/20260707000000_init/migration.sql

Your database is now in sync with your schema.
Generated Prisma Client
```

Cara cek database:

```bash
npx prisma studio
```

Prisma Studio membuka UI lokal untuk melihat table dan data.

## Prisma Client Singleton

Buat file `src/server/db.ts`:

```ts
// src/server/db.ts
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const db =
  globalForPrisma.prisma ??
  new PrismaClient({
    log:
      process.env.NODE_ENV === "development"
        ? ["query", "error", "warn"]
        : ["error"],
  });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = db;
}
```

Next.js development mode memakai hot reload. Tanpa singleton, setiap reload bisa membuat instance PrismaClient baru. Singleton membantu menghindari terlalu banyak connection saat development.

Di production, runtime biasanya membuat process baru sesuai platform deployment. Untuk Vercel serverless, tetap perhatikan connection pooling dari provider database seperti Neon, Supabase, atau Railway.

## Setup tRPC Basic

Buat file `src/server/api/trpc.ts`:

```ts
// src/server/api/trpc.ts
import { initTRPC } from "@trpc/server";
import superjson from "superjson";

export const createTRPCContext = async () => {
  return {};
};

const t = initTRPC.context<typeof createTRPCContext>().create({
  transformer: superjson,
});

export const createTRPCRouter = t.router;
export const publicProcedure = t.procedure;
```

Buat file `src/server/api/routers/health.ts`:

```ts
// src/server/api/routers/health.ts
import { createTRPCRouter, publicProcedure } from "@/server/api/trpc";

export const healthRouter = createTRPCRouter({
  check: publicProcedure.query(() => {
    return {
      status: "ok",
    };
  }),
});
```

Buat file `src/server/api/root.ts`:

```ts
// src/server/api/root.ts
import { createTRPCRouter } from "@/server/api/trpc";
import { healthRouter } from "@/server/api/routers/health";

export const appRouter = createTRPCRouter({
  health: healthRouter,
});

export type AppRouter = typeof appRouter;
```

Penjelasan:

- `createTRPCContext` nanti berisi session, user, organization, request metadata, dan dependency server.
- `initTRPC` membuat factory router/procedure.
- `publicProcedure` adalah procedure yang belum butuh login.
- `createTRPCRouter` menyatukan procedure per module.
- `health.check` mengembalikan `{ status: "ok" }`.

## Route Handler tRPC

Buat file `src/app/api/trpc/[trpc]/route.ts`:

```ts
// src/app/api/trpc/[trpc]/route.ts
import { fetchRequestHandler } from "@trpc/server/adapters/fetch";
import { appRouter } from "@/server/api/root";
import { createTRPCContext } from "@/server/api/trpc";

const handler = (request: Request) =>
  fetchRequestHandler({
    endpoint: "/api/trpc",
    req: request,
    router: appRouter,
    createContext: createTRPCContext,
  });

export { handler as GET, handler as POST };
```

Route `/api/trpc` menjadi entry point API type-safe. Next.js menerima request HTTP lewat Route Handler, lalu tRPC meneruskannya ke `appRouter`.

Path `[trpc]` adalah dynamic segment agar procedure seperti `health.check` bisa dipanggil melalui endpoint tRPC.

## Health Check REST Endpoint Opsional

Walaupun API utama memakai tRPC, endpoint REST sederhana tetap berguna untuk monitoring dan deployment check.

Buat file `src/app/api/health/route.ts`:

```ts
// src/app/api/health/route.ts
import { NextResponse } from "next/server";

export function GET() {
  return NextResponse.json({
    status: "ok",
  });
}
```

Endpoint ini bisa dipakai oleh Vercel, uptime monitor, load balancer, atau script deployment untuk memastikan aplikasi merespons request dasar.

## Struktur Folder Target

Target struktur setelah setup:

```text
src/
├── app/
│   └── api/
│       ├── health/
│       │   └── route.ts
│       └── trpc/
│           └── [trpc]/
│               └── route.ts
│
├── server/
│   ├── api/
│   │   ├── root.ts
│   │   ├── trpc.ts
│   │   └── routers/
│   │       └── health.ts
│   │
│   ├── db.ts
│   └── modules/
│       ├── identity/
│       ├── organizations/
│       ├── projects/
│       └── tasks/
│
├── shared/
│   ├── constants/
│   ├── types/
│   └── validation/
│
└── env.ts
```

Fungsi folder:

- `src/app/api`: Route Handler Next.js.
- `src/app/api/health`: endpoint REST health check.
- `src/app/api/trpc/[trpc]`: entry point tRPC.
- `src/server/api`: root router, context, dan router tRPC.
- `src/server/db.ts`: Prisma Client singleton.
- `src/server/modules`: business module backend.
- `src/server/modules/identity`: user, auth identity, profile.
- `src/server/modules/organizations`: tenant, membership, role.
- `src/server/modules/projects`: project dalam organization.
- `src/server/modules/tasks`: task workflow.
- `src/shared/constants`: constant yang aman dipakai lintas layer.
- `src/shared/types`: type umum yang tidak bergantung ke server secret.
- `src/shared/validation`: schema Zod reusable.
- `src/env.ts`: validasi environment variable.

## Environment Validation

Buat file `src/env.ts`:

```ts
// src/env.ts
import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  NEXT_PUBLIC_APP_URL: z.string().url(),
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
});

export const env = envSchema.parse({
  DATABASE_URL: process.env.DATABASE_URL,
  NEXT_PUBLIC_APP_URL: process.env.NEXT_PUBLIC_APP_URL,
  NODE_ENV: process.env.NODE_ENV,
});
```

Env validation penting karena error konfigurasi lebih cepat ketahuan saat app start. Tanpa validation, aplikasi bisa gagal jauh di tengah request dengan error yang sulit dilacak.

Untuk production di Vercel, pastikan semua variable yang dibutuhkan sudah diisi di Project Settings sebelum deploy.

## Update `package.json` Scripts

Update bagian `scripts` di `package.json`:

```json
// package.json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "typecheck": "tsc --noEmit",
    "db:generate": "prisma generate",
    "db:migrate": "prisma migrate dev",
    "db:push": "prisma db push",
    "db:studio": "prisma studio",
    "db:seed": "tsx prisma/seed.ts"
  }
}
```

Fungsi script:

- `dev`: menjalankan Next.js development server.
- `build`: membuat production build.
- `start`: menjalankan hasil production build.
- `lint`: menjalankan ESLint.
- `typecheck`: cek TypeScript tanpa membuat output file.
- `db:generate`: generate Prisma Client.
- `db:migrate`: membuat dan menjalankan migration development.
- `db:push`: sinkron schema ke database tanpa migration file, berguna untuk prototyping.
- `db:studio`: membuka Prisma Studio.
- `db:seed`: menjalankan seed data awal.

Jika Next.js versi yang dipakai tidak lagi menyediakan `next lint`, gunakan script lint sesuai konfigurasi ESLint project.

## Seed Script Awal

Buat file `prisma/seed.ts`:

```ts
// prisma/seed.ts
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const user = await prisma.user.upsert({
    where: {
      email: "owner@example.com",
    },
    update: {
      name: "Owner Example",
    },
    create: {
      email: "owner@example.com",
      name: "Owner Example",
    },
  });

  const organization = await prisma.organization.upsert({
    where: {
      slug: "example-workspace",
    },
    update: {
      name: "Example Workspace",
    },
    create: {
      name: "Example Workspace",
      slug: "example-workspace",
    },
  });

  await prisma.organizationMember.upsert({
    where: {
      userId_organizationId: {
        userId: user.id,
        organizationId: organization.id,
      },
    },
    update: {
      role: "OWNER",
    },
    create: {
      userId: user.id,
      organizationId: organization.id,
      role: "OWNER",
    },
  });

  const project = await prisma.project.upsert({
    where: {
      organizationId_slug: {
        organizationId: organization.id,
        slug: "launch-plan",
      },
    },
    update: {
      name: "Launch Plan",
    },
    create: {
      organizationId: organization.id,
      name: "Launch Plan",
      slug: "launch-plan",
    },
  });

  const existingTask = await prisma.task.findFirst({
    where: {
      organizationId: organization.id,
      projectId: project.id,
      title: "Prepare project foundation",
    },
  });

  if (!existingTask) {
    await prisma.task.create({
      data: {
        organizationId: organization.id,
        projectId: project.id,
        title: "Prepare project foundation",
        description: "Set up backend foundation for the SaaS task workspace.",
        status: "TODO",
        priority: "HIGH",
      },
    });
  }
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
```

Script ini idempotent untuk user, organization, membership, dan project karena memakai `upsert`. Untuk task, script mengecek task dengan title yang sama agar tidak membuat duplikat saat dijalankan ulang.

Jalankan:

```bash
npm run db:seed
```

## Cara Run Project

Jalankan development server:

```bash
npm run dev
```

Default port Next.js adalah `3000`.

Buka browser:

```text
http://localhost:3000
```

Test health REST:

```text
http://localhost:3000/api/health
```

Expected response:

```json
{
  "status": "ok"
}
```

Test tRPC health secara konsep:

- endpoint tRPC berada di `/api/trpc`;
- router bernama `health`;
- procedure bernama `check`;
- caller tRPC nanti memanggil `health.check`.

Client tRPC akan dibahas lebih detail di file frontend dan module berikutnya.

## Cara Cek Berhasil

Checklist verifikasi:

- Next.js berhasil jalan dengan `npm run dev`.
- PostgreSQL container running dengan `docker compose ps`.
- Prisma migrate berhasil dengan `npx prisma migrate dev --name init`.
- Prisma Client generated.
- Seed berhasil dengan `npm run db:seed`.
- `/api/health` return `{ "status": "ok" }`.
- tRPC router `health.check` tersedia.
- TypeScript check berhasil dengan `npm run typecheck`.
- Lint berhasil dengan `npm run lint`.

## Troubleshooting

### `npm` atau `npx` tidak dikenali

Node.js belum terinstall atau PATH belum benar. Install Node.js LTS, lalu buka terminal baru dan cek:

```bash
node -v
npm -v
npx -v
```

### Docker tidak jalan

Pastikan Docker Desktop aktif. Cek:

```bash
docker version
```

Jika command gagal, buka Docker Desktop dan tunggu sampai status engine running.

### Port `3000` dipakai

Next.js biasanya menawarkan port lain otomatis. Bisa juga jalankan:

```bash
npm run dev -- -p 3001
```

Lalu buka:

```text
http://localhost:3001
```

### Port `5432` dipakai

Ubah `docker-compose.yml`:

```yaml
# docker-compose.yml
ports:
  - "5433:5432"
```

Lalu ubah `.env`:

```dotenv
# .env
DATABASE_URL="postgresql://postgres:postgres@localhost:5433/modern_saas_t3_next?schema=public"
```

### `DATABASE_URL` salah

Gejala umum: Prisma tidak bisa connect, migration gagal, timeout, atau password authentication failed. Cek database name, username, password, host, dan port harus sama dengan `docker-compose.yml`.

### Prisma migrate gagal

Pastikan database running:

```bash
docker compose ps
```

Lalu coba:

```bash
npx prisma validate
npx prisma migrate dev --name init
```

Jika schema salah, Prisma biasanya menunjukkan baris yang bermasalah.

### Prisma Client belum generated

Jalankan:

```bash
npm run db:generate
```

Atau:

```bash
npx prisma generate
```

### tRPC route `404`

Cek file berikut:

```text
src/app/api/trpc/[trpc]/route.ts
src/server/api/root.ts
src/server/api/trpc.ts
src/server/api/routers/health.ts
```

Pastikan App Router aktif dan folder berada di dalam `src/app`.

### Env validation gagal

Pastikan `.env` punya:

```dotenv
# .env
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/modern_saas_t3_next?schema=public"
NEXT_PUBLIC_APP_URL="http://localhost:3000"
```

Restart dev server setelah mengubah `.env`.

### TypeScript path alias error

Pastikan `tsconfig.json` punya alias `@/*` ke `src/*`.

```json
// tsconfig.json
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

## Request Flow

Flow tRPC dalam stack ini:

```text
Client Component / Server caller
        |
        v
tRPC client/caller
        |
        v
src/app/api/trpc/[trpc]/route.ts
        |
        v
appRouter
        |
        v
procedure
        |
        v
module service/repository
        |
        v
Prisma
        |
        v
PostgreSQL
        |
        v
response type-safe
```

Route Handler hanya menjadi pintu masuk. Business logic sebaiknya tetap berada di module service/repository agar tidak bercampur dengan transport layer.

## Design Pattern Yang Relevan

Bagian ini memakai konsep umum design pattern yang juga dikenal dari referensi seperti Refactoring Guru, tetapi contoh dan penjelasan disesuaikan untuk stack ini.

### Facade

Masalah yang diselesaikan: caller tidak perlu tahu semua router internal dan API punya satu pintu masuk yang jelas.

Kenapa dipakai: `appRouter` menyatukan router `health`, nanti `identity`, `organizations`, `projects`, dan `tasks`.

File yang memakai:

```text
src/server/api/root.ts
```

Alternatif jika tidak dipakai: setiap module expose endpoint sendiri-sendiri tanpa root router, tetapi struktur API lebih sulit dipahami.

### Adapter

Masalah yang diselesaikan: business logic tidak perlu bergantung langsung ke detail Prisma query.

Kenapa dipakai: nanti repository bisa menjadi adapter antara module service dan Prisma.

File yang akan memakai:

```text
src/server/modules/*/repositories/*.ts
```

Alternatif jika tidak dipakai: service langsung memanggil Prisma. Ini cepat untuk awal, tetapi makin sulit diuji saat domain membesar.

### Singleton

Masalah yang diselesaikan: terlalu banyak instance PrismaClient saat hot reload development.

Kenapa dipakai: Next.js dev mode bisa reload module berkali-kali.

File yang memakai:

```text
src/server/db.ts
```

Alternatif jika tidak dipakai: membuat `new PrismaClient()` langsung di banyak file. Ini berisiko membuat connection berlebih.

### Module Pattern

Masalah yang diselesaikan: business logic tidak tercampur dalam satu folder besar.

Kenapa dipakai: domain SaaS seperti identity, organization, project, dan task punya aturan masing-masing.

Folder yang memakai:

```text
src/server/modules/identity
src/server/modules/organizations
src/server/modules/projects
src/server/modules/tasks
```

Alternatif jika tidak dipakai: semua logic ditaruh di router. Ini cepat di awal, tetapi susah dirawat.

### Result/Response Pattern

Masalah yang diselesaikan: response sukses dan error perlu konsisten.

Kenapa dipakai: API SaaS butuh error yang mudah dibaca client, seperti `FORBIDDEN`, `NOT_FOUND`, atau `VALIDATION_ERROR`.

File lanjutan:

```text
docs/stacks/modern-saas-t3-next/backend/08-code-blueprint-response-error.md
```

Alternatif jika tidak dipakai: throw error langsung di banyak tempat. Ini bisa bekerja, tetapi format error mudah tidak konsisten.

## Security Notes

- Jangan expose `DATABASE_URL` ke browser.
- Jangan commit secret production.
- Variable dengan prefix `NEXT_PUBLIC_` bisa dilihat browser.
- Validasi input tetap wajib walaupun TypeScript aktif.
- Authentication belum dibahas di file ini.
- Database local password `postgres` hanya untuk development.
- Rate limiting akan dibahas di file lanjutan.
- Audit log detail akan dibahas di file lanjutan.
- Untuk Vercel production, gunakan environment variable dashboard dan database managed yang mendukung connection pooling.

## Checklist Berhasil

- [ ] Project Next.js/T3-style dibuat.
- [ ] Dependency backend terinstall.
- [ ] Prisma siap.
- [ ] PostgreSQL lokal siap.
- [ ] Migration awal berhasil.
- [ ] Seed awal berhasil.
- [ ] tRPC basic siap.
- [ ] Health endpoint siap.
- [ ] Struktur folder `server/modules/shared` siap.
- [ ] Script `package.json` siap.
- [ ] Siap lanjut ke `02-modular-monolith-layers.md`.
