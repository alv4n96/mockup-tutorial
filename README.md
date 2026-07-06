# Tutorial Full Stack TypeScript: Next.js + Prisma + shadcn/ui

Branch ini adalah mockup tutorial lengkap untuk membangun aplikasi manajemen order memakai Next.js sebagai full stack framework. Backend dibuat dengan pola modular monolith agar domain tetap rapi walaupun deploy-nya satu aplikasi.

Stack utama:
- Full stack: Next.js App Router, TypeScript
- Backend: Route Handler dan Server Action berbasis modular monolith
- Database: PostgreSQL, Prisma
- UI framework: shadcn/ui, Tailwind CSS, Radix UI
- Form dan validasi: React Hook Form, Zod
- Testing: Vitest, Playwright

Contoh fitur akhir:
- CRUD customer dan order
- Validasi form di client dan server
- Data table dengan filter status
- Dashboard ringkas revenue dan order aktif
- Struktur domain modular monolith

## 1. Prasyarat

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

Aktifkan pnpm:

```bash
corepack enable
corepack prepare pnpm@latest --activate
```

## 2. Buat Project Next.js

```bash
pnpm create next-app@latest next-orders
cd next-orders
```

Pilihan scaffold:

```text
TypeScript: Yes
ESLint: Yes
Tailwind CSS: Yes
src directory: Yes
App Router: Yes
Turbopack: Yes
Import alias: @/*
```

Install dependency tambahan:

```bash
pnpm add @prisma/client zod react-hook-form @hookform/resolvers
pnpm add -D prisma vitest @vitejs/plugin-react playwright
```

## 3. Database PostgreSQL

Buat `docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: next_orders_db
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app_secret
      POSTGRES_DB: orders_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d orders_db"]
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
Container next_orders_db Started
```

Praktik database yang baik:
- Normalisasi data transaksi seperti customer, order, dan order item.
- Denormalisasi hanya untuk kebutuhan baca yang jelas dan terukur.
- Gunakan transaksi database ketika membuat order beserta item-nya.
- Buat unique constraint untuk email customer dan nomor order.
- Tambahkan index pada `status`, `createdAt`, dan foreign key.
- Hindari menghapus data transaksi; gunakan status cancel atau soft delete bila perlu audit.

## 4. Prisma Schema

```bash
pnpm prisma init
```

Isi `.env`:

```env
DATABASE_URL="postgresql://app:app_secret@localhost:5432/orders_db?schema=public"
```

`prisma/schema.prisma`:

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum OrderStatus {
  DRAFT
  PAID
  FULFILLED
  CANCELLED
}

model Customer {
  id        String   @id @default(uuid())
  name      String
  email     String   @unique
  orders    Order[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([name])
}

model Order {
  id          String      @id @default(uuid())
  orderNumber String      @unique
  customerId  String
  customer    Customer    @relation(fields: [customerId], references: [id])
  status      OrderStatus @default(DRAFT)
  totalCents  Int         @default(0)
  items       OrderItem[]
  createdAt   DateTime    @default(now())
  updatedAt   DateTime    @updatedAt

  @@index([customerId])
  @@index([status])
  @@index([createdAt])
}

model OrderItem {
  id          String @id @default(uuid())
  orderId     String
  order       Order  @relation(fields: [orderId], references: [id])
  productName String
  quantity    Int
  priceCents  Int

  @@index([orderId])
}
```

Migration:

```bash
pnpm prisma migrate dev --name init_orders
pnpm prisma generate
```

## 5. Backend Modular Monolith di Next.js

Gunakan satu deployable Next.js app, tetapi pisahkan domain server agar tidak menjadi campuran route dan query.

Struktur yang disarankan:

```text
src/
  app/
    orders/
      page.tsx
      actions.ts
    api/
      orders/
        route.ts
  server/
    db/
      prisma.ts
    modules/
      customers/
        customer.repository.ts
        customer.service.ts
        customer.schema.ts
      orders/
        order.repository.ts
        order.service.ts
        order.schema.ts
      shared/
        money.ts
        pagination.ts
```

Aturan modular monolith:
- `app/*` hanya untuk routing, rendering, dan pemanggilan action.
- Logika bisnis berada di `server/modules/*/service.ts`.
- Query Prisma berada di repository, bukan di komponen React.
- Modul boleh memanggil service modul lain lewat public function, bukan langsung import repository-nya.
- Validasi input disimpan dekat domain memakai Zod schema.
- Semua mutation penting memakai transaksi Prisma.

Prisma client `src/server/db/prisma.ts`:

```ts
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma = globalForPrisma.prisma ?? new PrismaClient();

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}
```

Schema order `src/server/modules/orders/order.schema.ts`:

```ts
import { z } from 'zod';

export const createOrderSchema = z.object({
  customerId: z.string().uuid(),
  items: z.array(
    z.object({
      productName: z.string().min(2),
      quantity: z.number().int().positive(),
      priceCents: z.number().int().nonnegative(),
    }),
  ).min(1),
});
```

Service order:

```ts
import { prisma } from '@/server/db/prisma';
import { createOrderSchema } from './order.schema';

export async function createOrder(input: unknown) {
  const data = createOrderSchema.parse(input);
  const totalCents = data.items.reduce((sum, item) => sum + item.quantity * item.priceCents, 0);

  return prisma.$transaction(async (tx) => {
    return tx.order.create({
      data: {
        orderNumber: `ORD-${Date.now()}`,
        customerId: data.customerId,
        totalCents,
        items: { create: data.items },
      },
      include: { items: true, customer: true },
    });
  });
}
```

Route handler `src/app/api/orders/route.ts`:

```ts
import { NextResponse } from 'next/server';
import { createOrder, listOrders } from '@/server/modules/orders/order.service';

export async function GET() {
  const orders = await listOrders();
  return NextResponse.json(orders);
}

export async function POST(request: Request) {
  const body = await request.json();
  const order = await createOrder(body);
  return NextResponse.json(order, { status: 201 });
}
```

## 6. shadcn/ui Setup

```bash
pnpm dlx shadcn@latest init
```

Pilihan umum:

```text
Style: New York
Base color: Neutral
CSS variables: Yes
```

Tambah komponen:

```bash
pnpm dlx shadcn@latest add button card dialog form input select table badge
```

UI order page memakai komponen yang umum:

```tsx
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { listOrders } from '@/server/modules/orders/order.service';

export default async function OrdersPage() {
  const orders = await listOrders();

  return (
    <main className="space-y-4 p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Orders</h1>
        <Button>New Order</Button>
      </div>
      <Card>
        <CardHeader>
          <CardTitle>Recent Orders</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Order</TableHead>
                <TableHead>Customer</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="text-right">Total</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {orders.map((order) => (
                <TableRow key={order.id}>
                  <TableCell>{order.orderNumber}</TableCell>
                  <TableCell>{order.customer.name}</TableCell>
                  <TableCell>{order.status}</TableCell>
                  <TableCell className="text-right">{order.totalCents}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </main>
  );
}
```

## 7. Seed Data

`prisma/seed.ts`:

```ts
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const customer = await prisma.customer.upsert({
    where: { email: 'demo@example.com' },
    update: {},
    create: { name: 'Demo Customer', email: 'demo@example.com' },
  });

  await prisma.order.create({
    data: {
      orderNumber: `ORD-SEED-001`,
      customerId: customer.id,
      totalCents: 150000,
      status: 'PAID',
      items: { create: [{ productName: 'Keyboard', quantity: 1, priceCents: 150000 }] },
    },
  });
}

main().finally(() => prisma.$disconnect());
```

Jalankan:

```bash
pnpm tsx prisma/seed.ts
```

## 8. Test dan Run

Development:

```bash
docker compose up -d
pnpm dev
```

Build:

```bash
pnpm lint
pnpm build
```

Playwright:

```bash
pnpm exec playwright install
pnpm exec playwright test
```

Log sukses contoh:

```text
? Compiled successfully
? Linting and checking validity of types
? 3 passed
```

## 9. Checklist Produksi

- Tambahkan auth sebelum endpoint mutation dipakai publik.
- Tambahkan role untuk admin, sales, dan viewer.
- Gunakan transaksi saat update order dan order item.
- Tambahkan audit log untuk perubahan status order.
- Tambahkan pagination cursor untuk tabel besar.
- Jalankan `prisma migrate deploy` di pipeline deploy.
- Simpan secret di secret manager, bukan `.env` repository.

## 10. Commit Log Mockup

```bash
git commit -m "docs: scaffold next modular monolith tutorial"
git commit -m "docs: add prisma order database design"
git commit -m "docs: add next server module flow"
git commit -m "docs: add shadcn ui frontend flow"
git commit -m "docs: add seed testing and production checklist"
```
