# 05 - Track Modern SaaS & Startup Stack: T3 / Next.js

## Target Track

Bangun SaaS task workspace atau e-commerce admin dengan stack:

- Next.js App Router.
- React 19.
- Tailwind CSS.
- tRPC untuk API type-safe.
- PostgreSQL.
- Prisma atau Drizzle.
- Node.js atau Bun.
- Vercel atau Cloudflare.

## Struktur Project

```text
src/
  app/
    (auth)/
      sign-in/
      sign-up/
    (dashboard)/
      dashboard/
      organizations/
      tasks/
      products/
      settings/
    api/
      trpc/[trpc]/
  modules/
    identity/
      application/
      domain/
      infrastructure/
      presentation/
    organizations/
    tasks/
    catalog/
    orders/
  server/
    api/
      root.ts
      trpc.ts
  shared/
    db/
    auth/
    env/
    errors/
    validation/
```

## Setup Awal

1. Buat project Next.js.
2. Tambahkan Tailwind.
3. Tambahkan tRPC.
4. Tambahkan ORM.
5. Tambahkan PostgreSQL lokal.
6. Tambahkan env validation.
7. Tambahkan lint, format, dan typecheck.

Command umum:

```bash
npm create t3-app@latest
npm run dev
npm run typecheck
npm run lint
```

Jika memakai Bun:

```bash
bun create t3-app
bun dev
```

## Layer Di Next.js

Next.js sering membuat developer mencampur UI, query, dan bisnis logic. Untuk tutorial ini, pisahkan:

- `app/`: routing dan page composition.
- `modules/*/presentation`: tRPC router, server action adapter, request DTO.
- `modules/*/application`: use case.
- `modules/*/domain`: entity, value object, policy.
- `modules/*/infrastructure`: Prisma/Drizzle repository.

## tRPC Router

Contoh bentuk router:

```ts
export const taskRouter = createTRPCRouter({
  create: protectedProcedure
    .input(createTaskSchema)
    .mutation(({ ctx, input }) => createTaskUseCase.execute(ctx.user, input)),
  list: protectedProcedure
    .input(listTasksSchema)
    .query(({ ctx, input }) => listTasksUseCase.execute(ctx.user, input)),
});
```

Router hanya menjadi adapter. Authorization use case tetap berada di application layer.

## Auth

Pilihan:

- Auth.js jika ingin kontrol penuh dan tetap open source.
- Clerk jika ingin cepat untuk SaaS.
- Supabase Auth jika database dan auth ingin dekat.

Minimal flow:

1. Sign up.
2. Verify email opsional.
3. Sign in.
4. Session tersedia di server.
5. User membuat organization pertama.
6. Semua query dashboard memfilter berdasarkan membership.

## Database Dengan Prisma

Model minimal:

```prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
  memberships Membership[]
}

model Organization {
  id        String   @id @default(cuid())
  name      String
  slug      String   @unique
  createdAt DateTime @default(now())
  memberships Membership[]
  tasks     Task[]
}

model Membership {
  id             String @id @default(cuid())
  organizationId String
  userId         String
  role           String
  organization   Organization @relation(fields: [organizationId], references: [id])
  user           User @relation(fields: [userId], references: [id])

  @@unique([organizationId, userId])
}

model Task {
  id             String   @id @default(cuid())
  organizationId String
  title          String
  status         String
  assigneeUserId String?
  createdAt      DateTime @default(now())
  organization   Organization @relation(fields: [organizationId], references: [id])
}
```

## UI Pages

Wajib ada:

- `/sign-in`
- `/sign-up`
- `/dashboard`
- `/organizations/new`
- `/tasks`
- `/tasks/new`
- `/tasks/[id]`
- `/settings/members`
- `/settings/billing`

Untuk e-commerce ganti tasks dengan:

- `/products`
- `/products/new`
- `/orders`
- `/orders/[id]`

## State Management

Mulai dengan:

- Server Components untuk data awal.
- tRPC client query untuk interaksi dinamis.
- URL search params untuk filter dan pagination.
- React Hook Form dan Zod untuk form.

Jangan menambah global state sebelum ada kebutuhan nyata.

## SaaS Feature Set

MVP:

- Register/login.
- Create organization.
- Invite member.
- Create project.
- Create task.
- Assign task.
- Filter task by status dan assignee.
- Billing page placeholder.

Next:

- Stripe checkout.
- Webhook subscription.
- Email invitation.
- Activity log.
- Notification.

## Deployment

Vercel:

- Set env.
- Set database connection.
- Jalankan migration saat release.
- Pastikan route webhook tidak memakai body parser yang mengubah signature.

Cloudflare:

- Cocok jika memakai edge runtime.
- Perhatikan kompatibilitas library Node.
- Gunakan database provider yang dekat dengan edge bila latency penting.

## Checklist Track T3

- `npm run typecheck` bersih.
- Semua tRPC procedure protected sesuai kebutuhan.
- Query tenant memakai `organizationId` dari membership, bukan dari input mentah.
- Form memakai Zod schema.
- Migration tersimpan.
- Seed lokal tersedia.
- Error user-friendly, log tetap detail di server.
