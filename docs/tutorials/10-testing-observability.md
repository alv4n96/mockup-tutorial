# 10 - Testing, Observability, Dan Quality Gate

## Testing Pyramid

Mulai dari:

- Unit test untuk domain.
- Use case test dengan repository fake.
- Integration test untuk database dan API.
- E2E test untuk flow utama.

Jangan hanya mengandalkan E2E karena lambat dan sulit debug.

## Unit Test Domain

Test aturan seperti:

- Email invalid ditolak.
- Task tidak bisa pindah dari `done` ke `todo` bila workflow melarang.
- Order total dihitung dari item.
- Stok tidak boleh negatif.

## Use Case Test

Test:

- User non-member tidak bisa membuat task.
- Admin bisa invite member.
- Checkout gagal bila stok kurang.
- Payment webhook idempotent.

Use case test idealnya tidak butuh HTTP.

## Integration Test

Test:

- Migration database berhasil.
- Repository menyimpan dan membaca data benar.
- API auth membaca current user.
- Tenant isolation benar di database query.

Untuk .NET dan Spring, gunakan database test container bila memungkinkan.

## E2E Test

Flow minimal SaaS:

1. Register.
2. Create organization.
3. Create task.
4. Assign task.
5. Logout.

Flow minimal e-commerce:

1. Register/login.
2. Browse product.
3. Add to cart.
4. Checkout.
5. Lihat order history.

## Quality Gate

Sebelum merge:

- Typecheck/build berhasil.
- Lint berhasil.
- Unit test berhasil.
- Integration test penting berhasil.
- Migration diuji dari database kosong.
- Tidak ada secret di repository.
- Error log tidak membocorkan token/password.

## Observability

Tambahkan:

- Structured logs.
- Request id.
- User id dan organization id di log context bila aman.
- Error tracking.
- Metrics request duration.
- Health check.

Jangan log:

- Password.
- Token.
- Payment card data.
- Secret API key.
- Full request body untuk endpoint sensitif.

## Production Debugging Checklist

Saat ada bug:

1. Cari request id.
2. Buka log server.
3. Cek user dan organization terkait.
4. Cek database record.
5. Cek external provider log.
6. Reproduksi di staging.
7. Buat test yang menangkap bug.
8. Fix dan deploy.
