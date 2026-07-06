# Backend 01 - Project Setup

## Yang Dibuat

Membuat fondasi backend untuk SaaS task workspace.

## Langkah

1. Buat project Next.js/T3.
2. Pilih TypeScript.
3. Aktifkan tRPC.
4. Tambahkan Prisma atau Drizzle.
5. Jalankan PostgreSQL lokal.
6. Buat file env validation.
7. Tambahkan script `dev`, `typecheck`, `lint`, `db:migrate`, dan `db:seed`.

## Struktur Awal

```text
src/
  app/
  modules/
  server/
  shared/
```

## Output

Backend siap menerima module domain tanpa mencampur business logic ke route Next.js.
