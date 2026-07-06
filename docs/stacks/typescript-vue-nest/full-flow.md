# Full Flow - TypeScript Vue/Nest

## Alur Dari Belakang Sampai Depan

1. Buat NestJS backend.
2. Buat module `Identity`, `Organizations`, dan `Tasks` atau `Catalog/Orders`.
3. Buat PostgreSQL migration.
4. Buat service application dan repository.
5. Buat REST endpoint.
6. Buat Vue app.
7. Buat Vuetify layout.
8. Buat auth flow.
9. Buat dashboard.
10. Buat CRUD modul utama.
11. Tambahkan test.
12. Deploy API dan web.

## Kenapa Ini Modular Monolith

NestJS sudah punya konsep module, tetapi modular monolith bukan sekadar membuat banyak module Nest. Kodenya disebut modular monolith jika setiap module punya boundary bisnis, service tidak saling akses database sembarangan, dan business rule tetap berada di application/domain layer.
