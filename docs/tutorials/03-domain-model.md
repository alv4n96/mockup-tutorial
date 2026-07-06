# 03 - Domain Model: User Dan Modul Penghubung

## Core Model

Setiap tutorial memakai `User` sebagai pusat identitas, tetapi user tidak boleh menjadi tempat semua data ditempel. Hubungkan user ke konteks bisnis melalui entity lain.

## SaaS Task Workspace

```text
User
  id
  email
  name
  passwordHash atau externalAuthId
  createdAt

Organization
  id
  name
  slug
  ownerUserId
  createdAt

Membership
  id
  organizationId
  userId
  role
  status
  joinedAt

Project
  id
  organizationId
  name
  key

Task
  id
  organizationId
  projectId
  title
  description
  status
  priority
  assigneeUserId
  dueDate
```

Relasi penting:

- User bisa menjadi member banyak organization.
- Organization punya banyak project.
- Project punya banyak task.
- Task bisa ditugaskan ke user yang menjadi member organization.

## E-Commerce

```text
User
  id
  email
  name
  role

Product
  id
  sku
  name
  description
  price
  status

Inventory
  id
  productId
  availableQty
  reservedQty

Order
  id
  userId
  orderNumber
  status
  totalAmount

OrderItem
  id
  orderId
  productId
  quantity
  unitPrice
```

Relasi penting:

- User customer punya order.
- Order punya banyak order item.
- Product bisa ada di banyak order item.
- Inventory dipisah dari product agar stok punya aturan sendiri.

## Value Object

Gunakan value object untuk konsep yang punya validasi kuat:

- `Email`
- `Money`
- `Slug`
- `OrderNumber`
- `TaskStatus`
- `Role`

Contoh aturan:

- Email harus valid dan lowercase.
- Money tidak boleh negatif.
- Slug hanya huruf kecil, angka, dan dash.
- Task status hanya boleh berpindah sesuai workflow.

## Aggregate Boundary

Mulai dengan aggregate sederhana.

SaaS:

- `Organization` aggregate: organization dan membership.
- `Project` aggregate: project.
- `Task` aggregate: task dan activity.

E-commerce:

- `Product` aggregate: product dan inventory.
- `Order` aggregate: order dan order item.
- `Payment` aggregate: payment attempt.

Jangan membuat satu aggregate raksasa yang memuat semua relasi. Itu membuat transaksi dan aturan bisnis sulit dipelihara.

## Use Case Awal

Identity:

- Register user.
- Login user.
- Get current user.

Organization:

- Create organization.
- Invite member.
- Change member role.
- Remove member.

Task:

- Create project.
- Create task.
- Assign task.
- Change task status.
- List tasks by organization.

Catalog dan Order:

- Create product.
- Update product price.
- Add product to cart.
- Checkout order.
- Mark order as paid.

## Invariant Penting

SaaS:

- Hanya owner/admin yang bisa mengundang member.
- Task hanya bisa ditugaskan ke member organization yang sama.
- User tidak boleh membaca task dari tenant lain.

E-commerce:

- Order total dihitung dari order item, bukan input frontend.
- Product inactive tidak bisa dibeli.
- Stok harus cukup saat checkout.
- Payment success tidak boleh diproses dua kali.

## Kesalahan Yang Harus Dihindari

- Menganggap `User` sebagai semua hal: customer, admin, owner, assignee, dan billing account tanpa konteks.
- Menaruh `organizationId` di semua tabel tanpa authorization query yang konsisten.
- Mengubah status order atau task dari controller langsung.
- Menerima harga dari frontend saat checkout.
- Menyimpan role global padahal permission sebenarnya per organization.
