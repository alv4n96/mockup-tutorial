# 12 - Capstone: Dari Kosong Sampai Rilis

Gunakan checklist ini sebagai alur implementasi penuh.

## Fase 1 - Inisialisasi

1. Pilih track: T3/Next.js atau Enterprise.
2. Buat repository.
3. Setup package manager.
4. Setup lint, format, typecheck.
5. Setup Docker Compose untuk PostgreSQL.
6. Setup environment variable validation.
7. Commit baseline.

## Fase 2 - Database

1. Buat migration `users`.
2. Buat migration `organizations`.
3. Buat migration `memberships`.
4. Buat migration modul utama:
   - SaaS: `projects`, `tasks`.
   - E-commerce: `products`, `orders`, `order_items`.
5. Buat seed user admin dan data demo.
6. Jalankan migration dari database kosong.

## Fase 3 - Identity

1. Register user.
2. Login user.
3. Current user endpoint.
4. Logout.
5. Password reset atau external auth callback.
6. Test login sukses dan gagal.

## Fase 4 - Organization/Tenant

1. Create organization.
2. Auto-create owner membership.
3. Invite member.
4. Change member role.
5. List members.
6. Tenant isolation test.

## Fase 5 - Modul Utama SaaS

1. Create project.
2. List project.
3. Create task.
4. List task dengan filter.
5. Assign task.
6. Change task status.
7. Task detail page.
8. Activity log.

## Fase 5 Alternatif - Modul Utama E-Commerce

1. Create product.
2. List product.
3. Product detail.
4. Add to cart.
5. Checkout order.
6. Payment provider abstraction.
7. Payment webhook.
8. Order history.

## Fase 6 - Abstract Factory Provider

1. Buat interface product provider.
2. Buat abstract factory.
3. Buat concrete factory development.
4. Buat concrete factory production.
5. Pilih factory dari config.
6. Tambahkan fake factory untuk test.

Contoh provider:

- Development email factory menulis log.
- Production email factory memakai provider eksternal.
- Stripe billing factory untuk production.
- Fake billing factory untuk test.

## Fase 7 - Frontend

1. Layout auth.
2. Layout dashboard.
3. Navigation.
4. Organization switcher.
5. List page.
6. Detail page.
7. Create/edit form.
8. Empty state.
9. Loading state.
10. Error state.

## Fase 8 - Quality

1. Unit test domain.
2. Use case test.
3. Integration test API.
4. E2E happy path.
5. Typecheck/build.
6. Security review env dan log.

## Fase 9 - Deployment

1. Buat staging database.
2. Set env staging.
3. Deploy staging.
4. Jalankan migration.
5. Smoke test.
6. Buat production database.
7. Set env production.
8. Deploy production.
9. Cek health check.
10. Cek log dan metrics.

## Fase 10 - Iterasi Setelah Rilis

Prioritas berikutnya:

- Billing sungguhan.
- Email invitation.
- Audit log UI.
- Search.
- Export CSV.
- Background job.
- Admin panel.
- Feature flag.
- Webhook retry.

## Syarat Website Utuh

Aplikasi dianggap utuh bila:

- User bisa login.
- User bisa membuat atau memilih organization.
- User bisa membuat data utama.
- Data utama muncul di list dan detail.
- User lain tanpa akses tidak bisa membaca data tersebut.
- Error dan empty state tersedia.
- Database migration berjalan.
- Test penting berjalan.
- Aplikasi berhasil deploy.
