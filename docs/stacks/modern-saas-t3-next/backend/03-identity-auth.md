# Backend 03 - Identity Dan Auth

## Yang Dibuat

Module `identity` untuk user, login, session, dan current user.

## Alur

1. Buat tabel `users`.
2. Buat entity `User`.
3. Buat value object `Email`.
4. Buat use case `RegisterUser`.
5. Buat use case `LoginUser` jika auth dikelola sendiri.
6. Buat `GetCurrentUser`.
7. Hubungkan session ke tRPC context.
8. Buat protected procedure.

## File Yang Disarankan

```text
src/modules/identity/
  domain/user.ts
  domain/email.ts
  application/register-user.ts
  application/get-current-user.ts
  infrastructure/user-repository.ts
  presentation/identity-router.ts
```

## Output

Setiap request backend bisa mengetahui user aktif tanpa frontend mengirim `userId` mentah.
