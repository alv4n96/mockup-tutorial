# Backend 04 - Organization Dan Tenancy

## Yang Dibuat

Module `organizations` sebagai tenant SaaS.

## Alur

1. Buat tabel `organizations`.
2. Buat tabel `memberships`.
3. Saat user register, buat organization pertama.
4. Buat use case `CreateOrganization`.
5. Buat use case `InviteMember`.
6. Buat use case `ChangeMemberRole`.
7. Buat policy `CanManageMembers`.
8. Buat service `MembershipAccess` untuk module lain.

## Tenant Isolation

Setiap query data bisnis harus melalui membership:

```text
currentUser -> membership -> organizationId -> query data
```

Jangan percaya `organizationId` dari frontend sebelum mengecek membership.

## Output

User hanya bisa melihat dan mengubah data dalam organization yang dia punya akses.
