# Backend 02 - Module Boundaries

## Yang Dibuat

Boundary module agar NestJS tidak berubah menjadi service campur aduk.

## Alur

1. Buat folder `modules`.
2. Buat `identity`.
3. Buat `organizations`.
4. Buat `tasks` atau `catalog/orders`.
5. Pisahkan controller, application service, domain model, dan repository.
6. Export hanya public service yang memang dibutuhkan module lain.

## Output

Module Nest punya kontrak yang jelas dan tidak saling bergantung langsung ke implementation detail.
