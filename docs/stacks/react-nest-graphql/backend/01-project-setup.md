# Backend 01 - Project Setup

Dokumen ini memandu setup backend NestJS + GraphQL + Prisma + PostgreSQL dari folder kosong. Target akhirnya adalah backend minimal yang bisa menjalankan GraphQL query:

```graphql
query {
  health
}
```

Response yang diharapkan:

```json
{
  "data": {
    "health": "ok"
  }
}
```

## Target Yang Dibangun

Pada akhir langkah ini, backend memiliki:

- Project NestJS baru.
- GraphQL API dengan Apollo.
- Prisma terhubung ke PostgreSQL.
- Docker Compose untuk database lokal.
- Prisma schema awal untuk User, Organization, OrganizationMember, Project, Task, dan AuditLog.
- Migration database pertama.
- PrismaService sebagai provider NestJS.
- HealthModule dengan GraphQL resolver.
- Script package.json untuk development, build, Prisma, dan seed.

## Konsep Dasar

### Apa Itu Node.js

Node.js adalah runtime JavaScript di sisi server. Dengan Node.js, kode JavaScript atau TypeScript bisa berjalan sebagai backend API, worker, CLI tool, atau service. Pada stack ini, Node.js menjalankan aplikasi NestJS.

### Apa Itu NestJS

NestJS adalah framework backend Node.js berbasis TypeScript. NestJS memberi struktur aplikasi melalui module, controller/resolver, service, provider, guard, pipe, dan dependency injection.

Untuk aplikasi enterprise, NestJS membantu karena:

- Struktur folder lebih konsisten.
- Dependency antar class lebih mudah dikelola.
- Cocok untuk layered architecture.
- Mendukung REST, GraphQL, WebSocket, microservice, dan background job.

### Apa Itu GraphQL

GraphQL adalah query language untuk API. Client bisa meminta field yang dibutuhkan, bukan selalu menerima response tetap seperti REST endpoint tradisional.

Contoh query:

```graphql
query {
  health
}
```

Dalam aplikasi project management, GraphQL berguna karena dashboard sering membutuhkan gabungan data seperti current user, organization aktif, project aktif, dan task terbaru.

### Apa Itu Apollo GraphQL

Apollo adalah ekosistem GraphQL. Di backend NestJS, Apollo dipakai sebagai GraphQL server driver. Package NestJS GraphQL akan menghubungkan resolver NestJS ke Apollo server.

Pada stack ini, Apollo dipakai untuk:

- Menjalankan endpoint GraphQL.
- Membuka GraphQL Sandbox atau Playground untuk local development.
- Mengelola query dan mutation.
- Menyediakan format error GraphQL yang bisa dikustomisasi.

### Apa Itu Prisma

Prisma adalah ORM untuk Node.js dan TypeScript. Prisma membaca file `schema.prisma`, lalu menghasilkan Prisma Client yang type-safe.

Prisma dipakai untuk:

- Mendefinisikan model database.
- Membuat migration.
- Menjalankan query database.
- Generate TypeScript client.
- Menjalankan seed.

### Apa Itu PostgreSQL

PostgreSQL adalah relational database. Data seperti user, organization, project, task, dan audit log cocok disimpan di PostgreSQL karena relasinya jelas.

Contoh relasi:

- Satu organization memiliki banyak member.
- Satu organization memiliki banyak project.
- Satu project memiliki banyak task.
- Satu task bisa memiliki assignee user.

### Apa Itu Docker Compose

Docker Compose adalah tool untuk menjalankan beberapa container lokal dengan satu file konfigurasi. Pada langkah ini, Docker Compose dipakai untuk menjalankan PostgreSQL lokal.

Command utama:

```bash
docker compose up -d
```

Artinya:

- `docker`: menjalankan Docker CLI.
- `compose`: memakai fitur Docker Compose.
- `up`: membuat dan menjalankan service dari file `docker-compose.yml`.
- `-d`: berjalan di background.

### Apa Itu Module Di NestJS

Module adalah unit organisasi di NestJS. Module mengelompokkan provider, resolver, controller, dan import module lain.

Contoh:

- `AppModule`: root module aplikasi.
- `PrismaModule`: menyediakan `PrismaService`.
- `HealthModule`: menyediakan `HealthResolver`.
- `IdentityModule`: nanti berisi register/login.
- `ProjectsModule`: nanti berisi fitur project.

### Apa Itu Resolver

Resolver adalah class yang menangani GraphQL query atau mutation. Jika REST memakai controller dan route, GraphQL memakai resolver dan field.

Contoh:

```graphql
query {
  health
}
```

Query di atas ditangani oleh method `health()` pada `HealthResolver`.

### Apa Itu Service

Service adalah class untuk logic aplikasi. Resolver sebaiknya tipis: menerima input, memanggil service, lalu mengembalikan output.

Contoh di tahap awal:

- `HealthResolver` langsung return `"ok"` karena belum ada logic.
- Pada tahap lanjut, `ProjectResolver` akan memanggil `ProjectService`.

### Apa Itu Provider

Provider adalah class atau value yang dikelola oleh NestJS dependency injection container. Service, repository, guard, dan PrismaService biasanya adalah provider.

Jika provider didaftarkan di module, class lain bisa memakainya melalui constructor injection.

### Apa Itu DTO/Input Type

DTO adalah Data Transfer Object. Pada GraphQL code-first NestJS, input biasanya dibuat sebagai class dengan decorator `@InputType()` dan field `@Field()`.

Contoh nanti:

```ts path=backend/src/modules/projects/dto/create-project.input.ts
import { Field, InputType } from '@nestjs/graphql';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

@InputType()
export class CreateProjectInput {
  @Field()
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  name: string;
}
```

DTO membantu validasi input sebelum masuk ke service.

### Apa Itu Entity/Model

Dalam konteks Prisma, model adalah representasi tabel database di file `schema.prisma`. Dalam konteks GraphQL, object type adalah bentuk data yang dikembalikan API.

Pada tahap awal, model database didefinisikan di Prisma. GraphQL object type akan dibuat pada dokumen module berikutnya.

### Apa Itu Migration

Migration adalah riwayat perubahan schema database. Saat kita menambah model `User` atau field `email`, Prisma membuat SQL migration agar database PostgreSQL berubah sesuai schema.

Command:

```bash
npx prisma migrate dev --name init
```

Artinya:

- `npx`: menjalankan binary dari dependency project.
- `prisma`: menjalankan Prisma CLI.
- `migrate dev`: membuat dan menerapkan migration untuk development.
- `--name init`: memberi nama migration `init`.

### Apa Itu Dependency Injection

Dependency Injection adalah cara memberi dependency ke class dari luar class tersebut. NestJS otomatis membuat instance provider dan menyuntikkannya lewat constructor.

Contoh:

```ts path=backend/src/example/example.service.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../infrastructure/prisma/prisma.service';

@Injectable()
export class ExampleService {
  constructor(private readonly prisma: PrismaService) {}
}
```

Manfaatnya:

- Class lebih mudah dites.
- Dependency lebih eksplisit.
- Implementasi bisa diganti, misalnya repository mock saat unit test.

## Pattern Yang Sudah Muncul Di Setup Ini

### Dependency Injection

Masalah yang diselesaikan:

Service dan resolver membutuhkan dependency seperti PrismaService. Jika dibuat manual dengan `new PrismaService()`, kode menjadi sulit dites dan sulit diganti.

Kenapa dipilih:

NestJS memang dibangun di atas dependency injection. Ini pattern paling natural untuk aplikasi NestJS.

File yang memakai:

- `backend/src/app.module.ts`
- `backend/src/infrastructure/prisma/prisma.module.ts`
- `backend/src/infrastructure/prisma/prisma.service.ts`
- `backend/src/modules/health/health.module.ts`
- `backend/src/modules/health/health.resolver.ts`

Alternatif jika tidak dipakai:

- Membuat instance class manual. Ini lebih sederhana untuk script kecil, tetapi buruk untuk aplikasi enterprise karena dependency tersebar dan testing lebih sulit.

### Facade Sederhana Pada PrismaService

Masalah yang diselesaikan:

Aplikasi perlu satu pintu untuk mengakses Prisma Client dan mengatur lifecycle koneksi database.

Kenapa dipilih:

`PrismaService` membungkus Prisma Client agar bisa dikelola sebagai provider NestJS.

File yang memakai:

- `backend/src/infrastructure/prisma/prisma.service.ts`

Alternatif jika tidak dipakai:

- Import Prisma Client langsung di setiap service. Ini cepat di awal, tetapi membuat koneksi dan dependency database tersebar.

### Repository Pattern Nanti Di Module Domain

Masalah yang diselesaikan:

Service domain tidak perlu tahu detail query Prisma.

Kenapa dipilih:

Project, task, organization, dan identity akan punya query yang makin kompleks. Repository membuat query terpusat dan mudah dites.

File yang akan memakai:

- `backend/src/modules/projects/repositories/project.repository.ts`
- `backend/src/modules/tasks/repositories/task.repository.ts`
- `backend/src/modules/organizations/repositories/organization.repository.ts`
- `backend/src/modules/identity/repositories/user.repository.ts`

Alternatif jika tidak dipakai:

- Service langsung memanggil `this.prisma.project.findMany()`. Ini boleh untuk prototype kecil, tetapi service cepat menjadi terlalu besar.

## Prasyarat

Pastikan sudah terinstall:

- Node.js versi LTS.
- npm, yarn, atau pnpm.
- Docker Desktop atau Docker Engine.
- Git.
- Code editor seperti VS Code.

Cek versi:

```bash
node -v
npm -v
docker --version
docker compose version
```

## Package Manager

Pilihan umum:

- npm: tersedia otomatis saat install Node.js, paling aman untuk pemula.
- yarn: populer di banyak project lama, tetapi perlu install tambahan.
- pnpm: cepat dan hemat disk, cocok untuk monorepo atau project besar.

Rekomendasi:

- Gunakan npm jika ingin setup paling mudah dan minim asumsi.
- Gunakan pnpm jika tim sudah nyaman dengan pnpm dan ingin install dependency lebih cepat.

Dokumen ini memakai npm agar command bisa langsung diikuti oleh pembaca junior.

Jika memakai pnpm, contoh konversinya:

```bash
npm install
pnpm install
```

```bash
npm run start:dev
pnpm start:dev
```

## Membuat Project NestJS

Install Nest CLI secara global:

```bash
npm i -g @nestjs/cli
```

Fungsi command:

- `npm i`: install package.
- `-g`: install global agar command `nest` tersedia dari terminal.
- `@nestjs/cli`: CLI resmi NestJS untuk membuat dan mengelola project.

Buat project backend:

```bash
nest new backend
```

Saat ditanya package manager, pilih `npm` untuk mengikuti panduan ini.

Masuk ke folder backend:

```bash
cd backend
```

## Install Dependency Backend

Install GraphQL dan Apollo:

```bash
npm install @nestjs/graphql @nestjs/apollo graphql apollo-server-express
```

Fungsi package:

- `@nestjs/graphql`: integrasi GraphQL dengan NestJS.
- `@nestjs/apollo`: driver Apollo untuk NestJS GraphQL.
- `graphql`: implementasi inti GraphQL.
- `apollo-server-express`: server Apollo berbasis Express yang dipakai oleh NestJS versi tertentu.

Install Prisma Client:

```bash
npm install @prisma/client
```

Fungsi package:

- `@prisma/client`: client TypeScript untuk query database setelah digenerate dari schema Prisma.

Install validation:

```bash
npm install class-validator class-transformer
```

Fungsi package:

- `class-validator`: validasi class DTO/input, misalnya `@IsEmail()` dan `@MinLength(8)`.
- `class-transformer`: transformasi plain object menjadi class instance agar validasi berjalan baik.

Install auth helper:

```bash
npm install bcryptjs jsonwebtoken
```

Fungsi package:

- `bcryptjs`: hashing password.
- `jsonwebtoken`: membuat dan memverifikasi JWT.

Install config:

```bash
npm install @nestjs/config
```

Fungsi package:

- `@nestjs/config`: membaca `.env` dan menyediakan ConfigService.

Install development dependency Prisma:

```bash
npm install -D prisma
```

Fungsi package:

- `prisma`: CLI Prisma untuk init, migrate, generate, studio, dan seed.

Install type definition untuk package auth:

```bash
npm install -D @types/bcryptjs @types/jsonwebtoken
```

Fungsi package:

- `@types/bcryptjs`: type TypeScript untuk bcryptjs jika dibutuhkan.
- `@types/jsonwebtoken`: type TypeScript untuk jsonwebtoken.

Catatan kompatibilitas:

Jika install GraphQL gagal karena versi Apollo atau NestJS tidak cocok, cek versi NestJS di `package.json`. Project NestJS baru biasanya lebih cocok dengan versi terbaru `@nestjs/graphql` dan `@nestjs/apollo`. Jika ada error peer dependency, gunakan versi package yang selaras dengan major version NestJS project.

## Setup Prisma

Jalankan:

```bash
npx prisma init
```

Command ini membuat:

- Folder `prisma/`.
- File `prisma/schema.prisma`.
- File `.env`.

Isi `.env`:

```dotenv path=backend/.env
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/react_nest_graphql?schema=public"
JWT_SECRET="change-this-local-secret"
JWT_EXPIRES_IN="7d"
```

Penjelasan:

- `DATABASE_URL`: connection string PostgreSQL.
- `postgresql://`: protocol database.
- `postgres:postgres`: username dan password.
- `localhost:5432`: host dan port PostgreSQL lokal.
- `react_nest_graphql`: nama database.
- `schema=public`: schema PostgreSQL yang dipakai.
- `JWT_SECRET`: secret lokal untuk menandatangani token.
- `JWT_EXPIRES_IN`: masa berlaku token.

Jangan gunakan `JWT_SECRET` di atas untuk production.

## Docker Compose PostgreSQL

Buat file `docker-compose.yml` di root folder backend.

```yaml path=backend/docker-compose.yml
services:
  postgres:
    image: postgres:16
    container_name: react_nest_graphql_postgres
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: react_nest_graphql
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

Penjelasan:

- `services.postgres`: nama service database.
- `image: postgres:16`: memakai image PostgreSQL versi 16.
- `container_name`: nama container agar mudah dikenali.
- `restart: unless-stopped`: container restart otomatis kecuali dihentikan manual.
- `ports`: membuka PostgreSQL container ke host di port `5432`.
- `POSTGRES_DB`: database awal yang dibuat.
- `POSTGRES_USER`: username.
- `POSTGRES_PASSWORD`: password.
- `volumes`: menyimpan data database agar tidak hilang saat container dimatikan.

Jalankan database:

```bash
docker compose up -d
```

Cek status:

```bash
docker compose ps
```

Jika status `postgres` sudah `running`, database siap dipakai.

## Prisma Schema Awal

Ganti isi `prisma/schema.prisma` menjadi:

```prisma path=backend/prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum UserRole {
  USER
  ADMIN
}

enum OrganizationRole {
  OWNER
  ADMIN
  MEMBER
}

enum ProjectStatus {
  ACTIVE
  ARCHIVED
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
  id                  String               @id @default(cuid())
  email               String               @unique
  name                String
  passwordHash        String
  role                UserRole             @default(USER)
  createdAt           DateTime             @default(now())
  updatedAt           DateTime             @updatedAt
  memberships         OrganizationMember[]
  assignedTasks       Task[]               @relation("TaskAssignee")
  createdTasks        Task[]               @relation("TaskCreator")
  auditLogs           AuditLog[]
}

model Organization {
  id          String               @id @default(cuid())
  name        String
  slug        String               @unique
  createdAt   DateTime             @default(now())
  updatedAt   DateTime             @updatedAt
  members     OrganizationMember[]
  projects    Project[]
  auditLogs   AuditLog[]
}

model OrganizationMember {
  id             String           @id @default(cuid())
  userId         String
  organizationId String
  role           OrganizationRole @default(MEMBER)
  createdAt      DateTime         @default(now())
  updatedAt      DateTime         @updatedAt
  user           User             @relation(fields: [userId], references: [id], onDelete: Cascade)
  organization   Organization     @relation(fields: [organizationId], references: [id], onDelete: Cascade)

  @@unique([userId, organizationId])
  @@index([organizationId])
}

model Project {
  id             String        @id @default(cuid())
  organizationId String
  name           String
  description    String?
  status         ProjectStatus @default(ACTIVE)
  createdAt      DateTime      @default(now())
  updatedAt      DateTime      @updatedAt
  organization   Organization  @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  tasks          Task[]

  @@index([organizationId])
  @@index([status])
}

model Task {
  id          String       @id @default(cuid())
  projectId   String
  title       String
  description String?
  status      TaskStatus   @default(TODO)
  priority    TaskPriority @default(MEDIUM)
  assigneeId  String?
  createdById String
  dueDate     DateTime?
  createdAt   DateTime     @default(now())
  updatedAt   DateTime     @updatedAt
  project     Project      @relation(fields: [projectId], references: [id], onDelete: Cascade)
  assignee    User?        @relation("TaskAssignee", fields: [assigneeId], references: [id], onDelete: SetNull)
  createdBy   User         @relation("TaskCreator", fields: [createdById], references: [id], onDelete: Restrict)

  @@index([projectId])
  @@index([assigneeId])
  @@index([status])
  @@index([priority])
}

model AuditLog {
  id             String        @id @default(cuid())
  organizationId String?
  actorUserId    String?
  action         String
  entityType     String
  entityId       String?
  metadata       Json?
  createdAt      DateTime      @default(now())
  organization   Organization? @relation(fields: [organizationId], references: [id], onDelete: SetNull)
  actorUser      User?         @relation(fields: [actorUserId], references: [id], onDelete: SetNull)

  @@index([organizationId])
  @@index([actorUserId])
  @@index([entityType, entityId])
  @@index([createdAt])
}
```

Catatan desain:

- `User` menyimpan akun dan password hash.
- `Organization` adalah tenant.
- `OrganizationMember` menghubungkan user dan tenant dengan role.
- `Project` selalu berada dalam organization.
- `Task` selalu berada dalam project.
- `AuditLog` menyimpan aktivitas penting.
- `@@index` ditambahkan untuk query yang sering dipakai.
- `onDelete` dibuat eksplisit agar behavior relasi lebih jelas.

## Migration Dan Generate Prisma Client

Jalankan migration pertama:

```bash
npx prisma migrate dev --name init
```

Command ini akan:

- Membaca `prisma/schema.prisma`.
- Membuat file migration SQL.
- Menerapkan migration ke PostgreSQL.
- Menjalankan Prisma generate jika berhasil.

Generate Prisma Client manual:

```bash
npx prisma generate
```

Command ini membuat client TypeScript berdasarkan schema terbaru. Jalankan lagi setiap ada perubahan schema jika diperlukan.

## Struktur Folder Backend Target

Target struktur backend:

```txt
backend/
├── src/
│   ├── main.ts
│   ├── app.module.ts
│   ├── common/
│   │   ├── errors/
│   │   ├── filters/
│   │   ├── guards/
│   │   ├── pagination/
│   │   └── result/
│   │
│   ├── infrastructure/
│   │   ├── prisma/
│   │   │   ├── prisma.module.ts
│   │   │   └── prisma.service.ts
│   │   └── config/
│   │       └── env.validation.ts
│   │
│   └── modules/
│       ├── health/
│       ├── identity/
│       ├── organizations/
│       ├── projects/
│       └── tasks/
│
├── prisma/
│   ├── schema.prisma
│   └── seed.ts
│
├── test/
├── Dockerfile
├── docker-compose.yml
└── package.json
```

Buat folder yang belum ada:

```bash
mkdir src/common
mkdir src/common/errors
mkdir src/common/filters
mkdir src/common/guards
mkdir src/common/pagination
mkdir src/common/result
mkdir src/infrastructure
mkdir src/infrastructure/prisma
mkdir src/infrastructure/config
mkdir src/modules
mkdir src/modules/health
mkdir src/modules/identity
mkdir src/modules/organizations
mkdir src/modules/projects
mkdir src/modules/tasks
```

Di Windows PowerShell, command `mkdir` juga bisa dipakai. Jika folder sudah ada, lanjutkan saja.

## Kode Awal Backend

### main.ts

File ini adalah entry point aplikasi NestJS.

```ts path=backend/src/main.ts
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.enableCors({
    origin: true,
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  const port = process.env.PORT ? Number(process.env.PORT) : 3000;
  await app.listen(port);
}

bootstrap();
```

Penjelasan penting:

- `NestFactory.create(AppModule)`: membuat aplikasi dari root module.
- `enableCors`: mengizinkan frontend lokal memanggil backend.
- `ValidationPipe`: menjalankan validasi DTO/input.
- `whitelist`: hanya field yang didefinisikan di DTO yang diterima.
- `forbidNonWhitelisted`: request gagal jika ada field asing.
- `transform`: mengubah plain object menjadi instance class DTO.
- `PORT`: membuat port bisa dikonfigurasi dari environment.

### app.module.ts

File ini adalah root module backend.

```ts path=backend/src/app.module.ts
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { GraphQLModule } from '@nestjs/graphql';
import { join } from 'path';
import { PrismaModule } from './infrastructure/prisma/prisma.module';
import { HealthModule } from './modules/health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      autoSchemaFile: join(process.cwd(), 'src/schema.gql'),
      sortSchema: true,
      playground: process.env.NODE_ENV !== 'production',
    }),
    PrismaModule,
    HealthModule,
  ],
})
export class AppModule {}
```

Penjelasan penting:

- `ConfigModule.forRoot`: membaca `.env`.
- `isGlobal: true`: ConfigModule bisa dipakai tanpa import ulang di setiap module.
- `GraphQLModule.forRoot`: mengaktifkan GraphQL.
- `ApolloDriver`: memakai Apollo sebagai GraphQL server.
- `autoSchemaFile`: NestJS membuat schema GraphQL dari resolver dan object type.
- `sortSchema`: schema lebih stabil dan mudah dibaca.
- `playground`: aktif hanya saat bukan production.
- `PrismaModule`: menyediakan PrismaService.
- `HealthModule`: menyediakan query `health`.

Catatan:

Pada beberapa versi Apollo/NestJS baru, UI yang muncul bisa berupa Apollo Sandbox, bukan GraphQL Playground klasik. Untuk local development, yang penting endpoint GraphQL bisa dibuka dan query bisa dijalankan.

### prisma.module.ts

File ini mendaftarkan PrismaService sebagai provider.

```ts path=backend/src/infrastructure/prisma/prisma.module.ts
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
```

Penjelasan penting:

- `@Global()`: PrismaModule tersedia global setelah diimport di AppModule.
- `providers`: mendaftarkan PrismaService ke NestJS DI container.
- `exports`: module lain bisa memakai PrismaService.

Untuk project besar, `@Global()` perlu dipakai hati-hati. Di panduan ini digunakan agar setup awal lebih sederhana. Alternatifnya adalah import `PrismaModule` secara eksplisit di setiap feature module.

### prisma.service.ts

File ini membungkus Prisma Client sebagai NestJS provider.

```ts path=backend/src/infrastructure/prisma/prisma.service.ts
import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
```

Penjelasan penting:

- `extends PrismaClient`: PrismaService punya semua method Prisma Client.
- `OnModuleInit`: koneksi database dibuka saat module siap.
- `OnModuleDestroy`: koneksi database ditutup saat aplikasi berhenti.
- `@Injectable()`: class bisa disuntikkan lewat dependency injection.

### health.module.ts

Module kecil untuk health check GraphQL.

```ts path=backend/src/modules/health/health.module.ts
import { Module } from '@nestjs/common';
import { HealthResolver } from './health.resolver';

@Module({
  providers: [HealthResolver],
})
export class HealthModule {}
```

Penjelasan:

- `HealthResolver` didaftarkan sebagai provider.
- Karena resolver adalah provider, NestJS bisa membuat instance-nya.

### health.resolver.ts

Resolver untuk query `health`.

```ts path=backend/src/modules/health/health.resolver.ts
import { Query, Resolver } from '@nestjs/graphql';

@Resolver()
export class HealthResolver {
  @Query(() => String)
  health(): string {
    return 'ok';
  }
}
```

Penjelasan:

- `@Resolver()`: class ini berisi resolver GraphQL.
- `@Query(() => String)`: method ini menjadi GraphQL query dengan return type String.
- Nama method `health` menjadi nama field query.

## Update package.json Scripts

Pastikan bagian `scripts` di `package.json` memiliki script berikut.

```json path=backend/package.json
{
  "scripts": {
    "build": "nest build",
    "start": "nest start",
    "start:dev": "nest start --watch",
    "start:debug": "nest start --debug --watch",
    "start:prod": "node dist/main",
    "lint": "eslint \"{src,apps,libs,test}/**/*.ts\" --fix",
    "test": "jest",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate dev",
    "prisma:studio": "prisma studio",
    "db:seed": "prisma db seed"
  }
}
```

Jika `package.json` sudah punya script bawaan dari NestJS, gabungkan script Prisma tanpa menghapus script lain yang masih dipakai.

Penjelasan script:

- `start:dev`: menjalankan backend dengan watch mode.
- `build`: compile TypeScript ke folder `dist`.
- `start:prod`: menjalankan hasil build.
- `lint`: menjalankan ESLint.
- `test`: menjalankan Jest.
- `prisma:generate`: generate Prisma Client.
- `prisma:migrate`: menjalankan migration development.
- `prisma:studio`: membuka Prisma Studio untuk melihat data.
- `db:seed`: menjalankan seed database.

## Menjalankan Backend

Pastikan PostgreSQL sudah berjalan:

```bash
docker compose ps
```

Jalankan backend:

```bash
npm run start:dev
```

Jika berhasil, terminal akan menunjukkan aplikasi berjalan di port `3000`.

Buka GraphQL di browser:

```txt
http://localhost:3000/graphql
```

Jalankan query:

```graphql
query {
  health
}
```

Response:

```json
{
  "data": {
    "health": "ok"
  }
}
```

## Urutan Command Lengkap

Jika diringkas, urutan command dari folder kosong:

```bash
npm i -g @nestjs/cli
nest new backend
cd backend
npm install @nestjs/graphql @nestjs/apollo graphql apollo-server-express
npm install @prisma/client
npm install class-validator class-transformer
npm install bcryptjs jsonwebtoken
npm install @nestjs/config
npm install -D prisma
npm install -D @types/bcryptjs @types/jsonwebtoken
npx prisma init
docker compose up -d
docker compose ps
npx prisma migrate dev --name init
npx prisma generate
npm run start:dev
```

Catatan:

File `.env`, `docker-compose.yml`, dan `prisma/schema.prisma` harus dibuat atau diubah sebelum menjalankan migration.

## Troubleshooting

### nest command tidak dikenali

Penyebab umum:

- `@nestjs/cli` belum terinstall global.
- Folder global npm belum masuk PATH.

Solusi:

```bash
npm i -g @nestjs/cli
nest --version
```

Jika masih gagal, jalankan tanpa global:

```bash
npx @nestjs/cli new backend
```

### npm install gagal

Penyebab umum:

- Koneksi internet bermasalah.
- Versi Node.js terlalu lama.
- Peer dependency conflict.

Solusi:

```bash
node -v
npm -v
npm cache verify
npm install
```

Jika peer dependency conflict muncul, baca pesan error dan cocokkan major version `@nestjs/*`. Jangan langsung memakai `--force` kecuali paham risikonya.

### Port 3000 dipakai

Penyebab:

- Ada aplikasi lain berjalan di port 3000.

Solusi sementara:

```bash
PORT=3001 npm run start:dev
```

Di Windows PowerShell:

```powershell
$env:PORT=3001
npm run start:dev
```

Buka:

```txt
http://localhost:3001/graphql
```

### Docker tidak jalan

Penyebab umum:

- Docker Desktop belum dibuka.
- Docker service mati.
- Virtualization belum aktif.

Solusi:

```bash
docker --version
docker compose version
docker ps
```

Jika command gagal, buka Docker Desktop dan tunggu sampai statusnya running.

### PostgreSQL port 5432 dipakai

Penyebab:

- Ada PostgreSQL lokal lain sudah memakai port 5432.

Solusi:

Ubah port host di `docker-compose.yml`:

```yaml path=backend/docker-compose.yml
services:
  postgres:
    image: postgres:16
    ports:
      - "5433:5432"
```

Lalu ubah `.env`:

```dotenv path=backend/.env
DATABASE_URL="postgresql://postgres:postgres@localhost:5433/react_nest_graphql?schema=public"
```

Jalankan ulang:

```bash
docker compose up -d
npx prisma migrate dev --name init
```

### DATABASE_URL salah

Gejala:

- Prisma gagal connect.
- Error authentication failed.
- Error database does not exist.

Cek:

```dotenv path=backend/.env
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/react_nest_graphql?schema=public"
```

Pastikan nilainya sama dengan `docker-compose.yml`:

```yaml path=backend/docker-compose.yml
environment:
  POSTGRES_DB: react_nest_graphql
  POSTGRES_USER: postgres
  POSTGRES_PASSWORD: postgres
```

### Prisma migrate gagal

Penyebab umum:

- PostgreSQL belum running.
- `.env` salah.
- Schema Prisma tidak valid.
- Database sudah punya tabel konflik dari percobaan sebelumnya.

Solusi awal:

```bash
docker compose ps
npx prisma validate
npx prisma migrate dev --name init
```

Jika ini project lokal baru dan data boleh hilang:

```bash
npx prisma migrate reset
```

Command `migrate reset` menghapus dan membuat ulang database schema. Jangan gunakan pada production.

### GraphQL Playground tidak muncul

Penyebab umum:

- Aplikasi belum jalan.
- URL salah.
- Versi Apollo menampilkan Sandbox, bukan Playground.
- `NODE_ENV=production`, sehingga playground dimatikan.

Solusi:

```txt
http://localhost:3000/graphql
```

Pastikan `playground` aktif untuk local:

```ts path=backend/src/app.module.ts
GraphQLModule.forRoot<ApolloDriverConfig>({
  driver: ApolloDriver,
  autoSchemaFile: join(process.cwd(), 'src/schema.gql'),
  sortSchema: true,
  playground: process.env.NODE_ENV !== 'production',
})
```

### Dependency Apollo/Nest GraphQL tidak cocok

Gejala:

- Error peer dependency saat install.
- Error driver Apollo saat start.
- Error package GraphQL version.

Solusi:

1. Cek versi NestJS:

```bash
npm list @nestjs/core @nestjs/graphql @nestjs/apollo graphql
```

2. Pastikan package `@nestjs/core`, `@nestjs/graphql`, dan `@nestjs/apollo` memakai major version yang kompatibel.
3. Jika project baru, lebih aman install package terbaru secara bersamaan:

```bash
npm install @nestjs/graphql@latest @nestjs/apollo@latest graphql@latest
```

Jika organisasi mengunci versi NestJS tertentu, ikuti matrix kompatibilitas dari dokumentasi resmi NestJS.

### PrismaClient belum generated

Gejala:

- TypeScript tidak menemukan model Prisma.
- Error `@prisma/client did not initialize yet`.

Solusi:

```bash
npx prisma generate
npm run start:dev
```

Jalankan generate lagi setelah mengubah `prisma/schema.prisma`.

## Langkah Berikutnya

Setelah health query berhasil, lanjutkan ke dokumen berikutnya:

- `backend/02-modular-monolith-layers.md`: memecah backend menjadi layer dan module boundary.
- `backend/03-identity-auth.md`: register, login, password hashing, JWT, guard, dan current user.
- `backend/04-organization-tenancy.md`: tenant, membership, dan role dalam organization.

