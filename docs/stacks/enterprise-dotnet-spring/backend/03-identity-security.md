# Backend 03 - Identity Dan Security

## Yang Dibuat

Identity enterprise untuk user, token/session, password policy, dan SSO bila diperlukan.

## Alur

1. Buat tabel `users`.
2. Buat tabel `sessions` atau integrasi OpenID Connect.
3. Tambahkan password hashing bila self-managed auth.
4. Tambahkan JWT/session middleware.
5. Buat endpoint current user.
6. Tambahkan rate limit login.
7. Tambahkan audit untuk login gagal.

## Security Baseline

- Token punya expiration.
- Secret tidak masuk repository.
- Password tidak pernah di-log.
- Endpoint sensitif punya rate limit.
- Authorization tetap dicek di use case.

## Output

Backend punya identity yang cukup kuat untuk aplikasi bisnis serius.
