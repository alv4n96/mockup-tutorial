# 08 - Auth, Tenancy, Roles, Dan Audit

## Authentication

Authentication menjawab: user ini siapa?

Flow minimal:

1. User register.
2. Password di-hash atau user dibuat dari external auth provider.
3. User login.
4. Server membuat session atau token.
5. Request berikutnya membawa session/token.
6. Backend membaca current user.

## Authorization

Authorization menjawab: user ini boleh melakukan aksi apa?

Jangan berhenti di middleware seperti `isAuthenticated`. Setiap use case penting harus mengecek permission.

Contoh:

```text
CreateTaskUseCase
  currentUser harus member organization
  role harus owner/admin/member
  assignee harus member organization yang sama
```

## Tenancy

Untuk SaaS, tenancy menentukan data milik siapa.

Model sederhana:

- `Organization` sebagai tenant.
- `Membership` menghubungkan user ke organization.
- Semua data bisnis memiliki `organizationId`.

Query list harus selalu memfilter organization yang user punya akses.

Salah:

```text
list tasks where organizationId = input.organizationId
```

Benar:

```text
cek membership currentUser pada input.organizationId
list tasks where organizationId = membership.organizationId
```

## Role

Mulai dari role sederhana:

- `owner`
- `admin`
- `member`
- `viewer`

Untuk e-commerce:

- `admin`
- `staff`
- `customer`

Permission contoh:

| Aksi | Owner | Admin | Member | Viewer |
| --- | --- | --- | --- | --- |
| Invite member | Ya | Ya | Tidak | Tidak |
| Create task | Ya | Ya | Ya | Tidak |
| Delete organization | Ya | Tidak | Tidak | Tidak |
| View task | Ya | Ya | Ya | Ya |

## Audit Log

Audit log harus dibuat untuk aksi penting:

- Login gagal berulang.
- Invite member.
- Change role.
- Create/update/delete product.
- Checkout order.
- Payment status changed.
- Subscription changed.

Field minimal:

```text
actorUserId
organizationId
action
entityType
entityId
metadata
createdAt
```

## Session Security

Checklist:

- Session punya expiration.
- Refresh token disimpan aman.
- Cookie memakai `HttpOnly`, `Secure`, dan `SameSite`.
- Logout menghapus session.
- Password reset token sekali pakai.
- Login rate limit aktif.

## Multi-Tenant Data Leak Test

Buat test:

1. User A punya organization A.
2. User B punya organization B.
3. User A membuat task A.
4. User B mencoba membaca task A.
5. Response harus forbidden atau not found.

Test ini wajib untuk SaaS karena bug tenancy sering lebih berbahaya daripada bug UI.
