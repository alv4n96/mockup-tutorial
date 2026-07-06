# 09 - API, Frontend Flow, Dan UI Pages

## Prinsip API

API harus:

- Validasi input.
- Menggunakan current user dari session/token.
- Memanggil use case.
- Mengembalikan response konsisten.
- Tidak membocorkan stack trace ke client.

## Response Shape

Gunakan format konsisten:

```json
{
  "data": {},
  "error": null
}
```

Atau untuk error:

```json
{
  "data": null,
  "error": {
    "code": "FORBIDDEN",
    "message": "You do not have access to this organization."
  }
}
```

tRPC boleh memakai error handling bawaan, tetapi error code tetap harus rapi.

## Flow SaaS

```text
Sign up
  -> create user
  -> create first organization
  -> redirect dashboard

Dashboard
  -> load current organization
  -> load task summary
  -> load recent activity

Create task
  -> validate form
  -> call create task API
  -> use case checks membership
  -> save task
  -> redirect task detail
```

## Flow E-Commerce

```text
Browse products
  -> list active products
  -> open product detail
  -> add to cart

Checkout
  -> validate cart
  -> reserve inventory
  -> create order
  -> create payment session
  -> redirect payment

Payment webhook
  -> verify signature
  -> mark order paid
  -> emit order paid event
  -> send email
```

## Pages Minimal

Auth:

- Sign in.
- Sign up.
- Forgot password.

Dashboard:

- Overview.
- Activity.
- Quick actions.

SaaS task:

- Organization switcher.
- Project list.
- Task board/list.
- Task detail.
- Member settings.

E-commerce:

- Product list.
- Product detail.
- Cart.
- Checkout.
- Order history.
- Admin orders.

## Form Pattern

Setiap form punya:

- Schema validasi.
- Default values.
- Loading state.
- Error per field.
- Submit disabled saat request berjalan.
- Success redirect atau toast.

## Pagination Dan Filtering

List page harus memakai:

- `page` atau cursor.
- `pageSize`.
- `search`.
- `status`.
- `sort`.

Jangan ambil seluruh data lalu filter di frontend untuk data bisnis yang bisa membesar.

## Empty State

Setiap list punya empty state:

- Belum ada task: tampilkan tombol create task.
- Belum ada product: tampilkan tombol create product.
- Belum ada order: tampilkan pesan order akan muncul setelah checkout.

## Error State

Bedakan:

- Unauthorized: redirect login.
- Forbidden: tampilkan akses ditolak.
- Not found: tampilkan halaman tidak ditemukan.
- Validation error: tampilkan error field.
- Server error: tampilkan pesan umum dan log detail di server.
