# Shared Engineering Conventions

Folder ini berisi aturan umum yang dipakai oleh semua tech stack.

## Materi

1. [01-api-response-envelope.md](01-api-response-envelope.md)
2. [02-error-code-and-http-status.md](02-error-code-and-http-status.md)
3. [03-validation-and-dto.md](03-validation-and-dto.md)
4. [04-pagination-filter-sort.md](04-pagination-filter-sort.md)
5. [05-module-contracts.md](05-module-contracts.md)
6. [06-rbac-tenant-authorization.md](06-rbac-tenant-authorization.md)

## Prinsip

- Semua response API punya bentuk konsisten.
- Error code stabil dan bisa dipakai frontend.
- DTO tidak bocor dari ORM/entity database.
- Pagination, filter, dan sort punya kontrak yang sama.
- Modul berkomunikasi lewat contract, bukan akses internal module lain.
- RBAC dan tenant authorization dicek di application layer, bukan hanya di UI.
