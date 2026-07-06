# 04 - Database, Migration, Seed, Dan Transaksi

## Pilihan Database

Gunakan PostgreSQL sebagai default karena cocok untuk SaaS dan e-commerce:

- Constraint kuat.
- Index fleksibel.
- Transaction support matang.
- JSONB tersedia bila perlu konfigurasi dinamis.
- Mudah dijalankan lokal dengan Docker.

Untuk enterprise Microsoft-heavy, SQL Server juga valid terutama bila organisasi memakai Azure, .NET, dan tooling Microsoft.

## Migration Awal

Urutan migration:

1. `users`
2. `organizations`
3. `memberships`
4. `projects` dan `tasks`, atau `products` dan `orders`
5. `audit_logs`
6. `subscriptions` atau `payments`

## Constraint Minimal

SaaS:

```sql
unique users(email)
unique organizations(slug)
unique memberships(organization_id, user_id)
foreign key memberships.user_id -> users.id
foreign key tasks.organization_id -> organizations.id
foreign key tasks.assignee_user_id -> users.id
```

E-commerce:

```sql
unique products(sku)
unique orders(order_number)
foreign key orders.user_id -> users.id
foreign key order_items.order_id -> orders.id
foreign key order_items.product_id -> products.id
check order_items.quantity > 0
check products.price >= 0
```

## Index Awal

SaaS:

- `users(email)`
- `organizations(slug)`
- `memberships(user_id)`
- `tasks(organization_id, status)`
- `tasks(organization_id, assignee_user_id)`
- `tasks(project_id, created_at)`

E-commerce:

- `products(status)`
- `products(sku)`
- `orders(user_id, created_at)`
- `orders(status)`
- `order_items(product_id)`

## Soft Delete Atau Hard Delete

Gunakan hard delete untuk data latihan yang tidak penting. Gunakan soft delete untuk:

- Organization.
- Product.
- Order.
- Subscription.

Kolom umum:

```text
deletedAt nullable
deletedBy nullable
```

Jangan soft delete tanpa filter global atau query convention. Data yang terhapus bisa bocor kembali ke UI bila query lupa memfilter.

## Audit Field

Minimal:

```text
createdAt
createdBy
updatedAt
updatedBy
```

Untuk enterprise tambahkan `audit_logs`:

```text
id
actorUserId
organizationId nullable
action
entityType
entityId
oldValue json
newValue json
createdAt
```

## Seed Data

Seed harus membuat:

- Admin user.
- Demo user.
- Demo organization.
- Membership owner/admin/member.
- Beberapa project dan task, atau product dan order.

Seed tidak boleh bergantung pada data production.

## Transaksi

Gunakan transaksi untuk:

- Register user sekaligus membuat organization pertama.
- Checkout order sekaligus membuat order item dan mengurangi stok.
- Invite member sekaligus membuat notification.
- Payment success sekaligus mengubah order/subscription status.

Contoh batas transaksi:

```text
CheckoutOrderUseCase
  begin transaction
  validate cart
  reserve inventory
  create order
  create order items
  clear cart
  commit
```

## Outbox Pattern Opsional

Jika ada event penting seperti `OrderPaid` atau `MemberInvited`, simpan event ke tabel `outbox_messages` dalam transaksi yang sama. Worker akan mengirim email atau publish event setelah commit.

Ini mencegah kasus data berhasil disimpan tetapi email/payment notification gagal diam-diam.

## Checklist Database

- Migration bisa dijalankan dari database kosong.
- Migration bisa rollback atau setidaknya punya strategi forward fix.
- Constraint bisnis penting ada di database.
- Query list memakai pagination.
- Index sesuai query utama.
- Seed lokal berjalan tanpa secret production.
- Transaksi dipakai untuk operasi multi-tabel.
