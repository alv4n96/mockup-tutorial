# Backend 04 - Tenant Dan Authorization

## Yang Dibuat

Organization tenant, membership, role, permission, dan audit.

## Alur

1. Buat tabel `organizations`.
2. Buat tabel `memberships`.
3. Buat role `owner`, `admin`, `member`, `viewer`.
4. Buat policy authorization per use case.
5. Buat `TenantContext`.
6. Buat audit log untuk role changes.
7. Tambahkan test user lintas tenant.

## Output

Data antar tenant tidak bocor dan semua aksi penting bisa diaudit.
