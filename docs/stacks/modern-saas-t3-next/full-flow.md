# Full Flow - Modern SaaS T3 / Next.js

## Alur Dari Belakang Sampai Depan

1. Siapkan PostgreSQL.
2. Buat schema `users`, `organizations`, `memberships`, `projects`, `tasks`, `subscriptions`.
3. Buat module backend: `identity`, `organizations`, `tasks`, `billing`.
4. Setiap module punya `domain`, `application`, `infrastructure`, dan `presentation`.
5. Buat tRPC router sebagai presentation adapter.
6. Buat use case di application layer.
7. Buat repository interface dan implementasi Prisma/Drizzle.
8. Buat auth/session.
9. Buat UI auth.
10. Buat dashboard dan organization switcher.
11. Buat task list, form, detail, dan status update.
12. Buat billing placeholder memakai Abstract Factory untuk provider.
13. Tambahkan test domain, use case, tRPC procedure, dan UI flow.
14. Deploy ke Vercel atau Cloudflare.

## Kenapa Ini Modular Monolith

Ini modular monolith karena semua modul berjalan dalam satu aplikasi Next.js deployable, tetapi boundary bisnis tetap dipisah:

- `Identity` mengelola user dan session.
- `Organizations` mengelola tenant, membership, dan role.
- `Tasks` mengelola project dan task.
- `Billing` mengelola plan, checkout, webhook, dan subscription.

Monolith-nya ada pada deployment: satu aplikasi. Modular-nya ada pada boundary kode dan aturan dependency.
