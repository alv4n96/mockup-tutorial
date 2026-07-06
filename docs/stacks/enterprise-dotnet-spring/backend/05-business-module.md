# Backend 05 - Business Module

## Yang Dibuat

Module utama: `Tasks` untuk SaaS atau `Catalog/Orders` untuk e-commerce.

## Alur SaaS Task

1. Buat `Project`.
2. Buat `Task`.
3. Buat command `CreateTask`.
4. Buat command `AssignTask`.
5. Buat command `ChangeTaskStatus`.
6. Buat query `ListTasks`.
7. Tambahkan tenant authorization.

## Alur E-Commerce

1. Buat `Product`.
2. Buat `Inventory`.
3. Buat `Order`.
4. Buat `OrderItem`.
5. Buat command `CheckoutOrder`.
6. Tambahkan transaksi stok dan order.
7. Tambahkan idempotency untuk payment.

## Output

Backend punya workflow bisnis nyata yang menghubungkan user ke data utama aplikasi.
