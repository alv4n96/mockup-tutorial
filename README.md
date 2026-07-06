# Tutorial Full Stack TypeScript: Vue 3 + NestJS + Vuetify

Branch ini adalah mockup tutorial lengkap untuk membangun aplikasi manajemen produk dari backend sampai frontend menggunakan stack yang umum dipakai di ekosistem TypeScript.

Stack utama:
- Backend: NestJS modular monolith, Prisma, PostgreSQL
- Frontend: Vue 3, Vite, TypeScript, Pinia, Vue Router
- UI framework: Vuetify
- Testing: Vitest, Supertest
- Tooling: pnpm, ESLint, Prettier

Contoh fitur akhir:
- CRUD produk
- Validasi input
- Pencarian dan pagination sederhana
- API REST terdokumentasi
- UI dashboard dengan tabel, dialog form, snackbar, dan loading state

## 1. Prasyarat

Install tool berikut:

```bash
node --version
pnpm --version
docker --version
```

Versi yang disarankan:
- Node.js 22 LTS
- pnpm 9 atau lebih baru
- Docker Desktop
- PostgreSQL 16

Jika pnpm belum ada:

```bash
corepack enable
corepack prepare pnpm@latest --activate
```

## 2. Buat Workspace

```bash
mkdir vue-nest-products
cd vue-nest-products
pnpm init
mkdir apps packages
```

Struktur target:

```text
vue-nest-products/
  apps/
    api/
    web/
  packages/
    shared/
  docker-compose.yml
  pnpm-workspace.yaml
```

Buat `pnpm-workspace.yaml`:

```yaml
packages:
  - "apps/*"
  - "packages/*"
```

## 3. Database PostgreSQL

Buat `docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: vue_nest_products_db
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app_secret
      POSTGRES_DB: products_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d products_db"]
      interval: 5s
      timeout: 3s
      retries: 10

volumes:
  postgres_data:
```

Jalankan:

```bash
docker compose up -d
```

Log yang diharapkan:

```text
[+] Running 2/2
Network vue-nest-products_default Created
Container vue_nest_products_db Started
```

Praktik database yang baik:
- Gunakan migration, jangan edit schema produksi secara manual.
- Tambahkan index untuk kolom yang sering dipakai filter atau search.
- Simpan uang sebagai integer minor unit, bukan floating point.
- Gunakan constraint database untuk aturan penting seperti unique SKU.
- Pisahkan data audit seperti `createdAt` dan `updatedAt`.
- Backup database sebelum migration besar.

## 4. Backend NestJS Modular Monolith

Backend dibuat sebagai modular monolith: satu aplikasi dan satu database utama, tetapi domain dipisah menjadi modul yang punya boundary jelas. Pola ini lebih sederhana daripada microservices untuk tahap awal, namun tetap rapi saat fitur bertambah.

Boundary yang disarankan:

```text
src/
  modules/
    products/
      products.controller.ts
      products.service.ts
      products.repository.ts
      dto/
    inventory/
      inventory.service.ts
    identity/
      users.service.ts
  shared/
    prisma/
    filters/
    interceptors/
```

Aturan modular monolith:
- Controller hanya menerima request dan memanggil service modul sendiri.
- Service antar modul berkomunikasi lewat public service, bukan langsung membaca repository modul lain.
- Repository menyimpan query Prisma agar service tetap fokus pada aturan bisnis.
- Shared module hanya berisi hal lintas domain seperti database, config, logging, dan error filter.
- Jangan membuat import melingkar antar modul.

## 5. Implementasi API NestJS

Buat aplikasi API:

```bash
pnpm dlx @nestjs/cli new apps/api --package-manager pnpm
```

Install dependency:

```bash
cd apps/api
pnpm add @nestjs/config @prisma/client class-validator class-transformer
pnpm add -D prisma
pnpm prisma init
```

Isi `.env`:

```env
DATABASE_URL="postgresql://app:app_secret@localhost:5432/products_db?schema=public"
PORT=3000
```

Model Prisma `prisma/schema.prisma`:

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Product {
  id          String   @id @default(uuid())
  name        String
  sku         String   @unique
  description String?
  priceCents  Int
  stock       Int      @default(0)
  isActive    Boolean  @default(true)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@index([name])
  @@index([isActive])
}
```

Migration:

```bash
pnpm prisma migrate dev --name init_products
pnpm prisma generate
```

Log yang diharapkan:

```text
Applying migration `20260706090000_init_products`
The following migration(s) have been created and applied
Generated Prisma Client
```

Buat Prisma service:

```bash
nest g module prisma
nest g service prisma
```

`src/prisma/prisma.service.ts`:

```ts
import { Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  async onModuleInit() {
    await this.$connect();
  }
}
```

Product module:

```bash
nest g resource products --no-spec
```

DTO utama:

```ts
import { IsBoolean, IsInt, IsOptional, IsString, Min } from 'class-validator';

export class CreateProductDto {
  @IsString()
  name!: string;

  @IsString()
  sku!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsInt()
  @Min(0)
  priceCents!: number;

  @IsInt()
  @Min(0)
  stock!: number;
}

export class UpdateProductDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  priceCents?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  stock?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
```

Service pattern:

```ts
@Injectable()
export class ProductsService {
  constructor(private readonly prisma: PrismaService) {}

  findAll(search = '', page = 1, limit = 10) {
    return this.prisma.product.findMany({
      where: search ? { name: { contains: search, mode: 'insensitive' } } : {},
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit,
    });
  }
}
```

Enable validation dan CORS di `main.ts`:

```ts
app.enableCors({ origin: 'http://localhost:5173' });
app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
```

Jalankan API:

```bash
pnpm start:dev
```

Cek endpoint:

```bash
curl http://localhost:3000/products
```

## 6. Frontend Vue 3

Buat app:

```bash
cd ../../
pnpm create vue@latest apps/web
```

Pilih:

```text
TypeScript: Yes
JSX: No
Vue Router: Yes
Pinia: Yes
Vitest: Yes
ESLint: Yes
Prettier: Yes
```

Install Vuetify dan axios:

```bash
cd apps/web
pnpm add vuetify @mdi/font axios
pnpm add -D vite-plugin-vuetify
```

Setup Vuetify `src/plugins/vuetify.ts`:

```ts
import '@mdi/font/css/materialdesignicons.css';
import 'vuetify/styles';
import { createVuetify } from 'vuetify';

export default createVuetify({
  theme: {
    defaultTheme: 'light',
  },
});
```

Register di `src/main.ts`:

```ts
import { createApp } from 'vue';
import { createPinia } from 'pinia';
import App from './App.vue';
import router from './router';
import vuetify from './plugins/vuetify';

createApp(App).use(createPinia()).use(router).use(vuetify).mount('#app');
```

API client `src/lib/api.ts`:

```ts
import axios from 'axios';

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL ?? 'http://localhost:3000',
  timeout: 10000,
});
```

Store Pinia `src/stores/products.ts`:

```ts
import { defineStore } from 'pinia';
import { api } from '@/lib/api';

export interface Product {
  id: string;
  name: string;
  sku: string;
  priceCents: number;
  stock: number;
  isActive: boolean;
}

export const useProductsStore = defineStore('products', {
  state: () => ({ items: [] as Product[], loading: false }),
  actions: {
    async fetchProducts(search = '') {
      this.loading = true;
      try {
        const response = await api.get('/products', { params: { search } });
        this.items = response.data;
      } finally {
        this.loading = false;
      }
    },
  },
});
```

Halaman utama memakai Vuetify:

```vue
<template>
  <v-container fluid>
    <v-toolbar color="white" density="comfortable">
      <v-toolbar-title>Products</v-toolbar-title>
      <v-spacer />
      <v-btn color="primary" prepend-icon="mdi-plus">New Product</v-btn>
    </v-toolbar>

    <v-text-field v-model="search" label="Search" prepend-inner-icon="mdi-magnify" />

    <v-data-table :items="store.items" :loading="store.loading" :headers="headers" />
  </v-container>
</template>
```

## 7. Test

Backend:

```bash
cd apps/api
pnpm test
pnpm test:e2e
```

Frontend:

```bash
cd apps/web
pnpm test:unit
pnpm build
```

Log sukses contoh:

```text
Test Suites: 3 passed, 3 total
? built in 2.41s
```

## 8. Run Full Stack

Terminal 1:

```bash
docker compose up -d
```

Terminal 2:

```bash
cd apps/api
pnpm start:dev
```

Terminal 3:

```bash
cd apps/web
pnpm dev
```

URL:
- API: http://localhost:3000
- Web: http://localhost:5173

## 9. Checklist Produksi

- Tambahkan `.env.example` tanpa secret asli.
- Aktifkan request logging dan error tracking.
- Tambahkan pagination metadata.
- Tambahkan seed database untuk data demo.
- Gunakan migration di CI sebelum deploy.
- Tambahkan rate limit untuk endpoint publik.
- Tambahkan Dockerfile untuk API dan web.

## 10. Commit Log Mockup

Contoh alur commit yang masuk akal:

```bash
git commit -m "docs: scaffold vue nest tutorial"
git commit -m "docs: add postgres and prisma setup"
git commit -m "docs: add nestjs product api flow"
git commit -m "docs: add vue vuetify frontend flow"
git commit -m "docs: add testing and production checklist"
```


