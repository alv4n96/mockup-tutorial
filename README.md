# Full Stack Tutorial Branches

Repository ini berisi mockup tutorial full stack yang dipisahkan per branch. Setiap branch memakai satu stack populer, mencakup backend modular monolith, frontend, UI framework, database, log command, dan checklist produksi.

## Daftar Branch

| Branch | Bahasa | Backend | Frontend | UI Framework | Database |
| --- | --- | --- | --- | --- | --- |
| `tutorial/typescript-vue-vuetify` | TypeScript | NestJS modular monolith | Vue 3 + Vite | Vuetify | PostgreSQL + Prisma |
| `tutorial/typescript-next-shadcn` | TypeScript | Next.js modular monolith | Next.js App Router | shadcn/ui + Tailwind CSS | PostgreSQL + Prisma |
| `tutorial/csharp-blazor-bootstrap` | C# | ASP.NET Core modular monolith | Blazor WebAssembly | Bootstrap 5 | PostgreSQL + EF Core |

## Cara Membaca

Ambil branch sesuai stack yang ingin dipelajari:

```bash
git fetch origin
git switch tutorial/typescript-vue-vuetify
```

Lalu baca `README.md` di branch tersebut dari awal sampai akhir.

## Standar Arsitektur Backend

Semua branch backend memakai pendekatan modular monolith:
- Satu aplikasi deployable.
- Domain dipisah menjadi modul yang punya boundary jelas.
- Query database tidak diletakkan langsung di controller atau komponen UI.
- Modul berkomunikasi lewat service atau contract publik.
- Shared code hanya untuk hal lintas domain seperti config, database, logging, result, dan error handling.

Pendekatan ini cocok untuk tutorial dan produk tahap awal karena lebih sederhana daripada microservices, tetapi masih menjaga struktur agar mudah berkembang.

## Catatan Database

Semua tutorial menggunakan PostgreSQL karena stabil, populer, mudah dijalankan dengan Docker, dan cocok untuk aplikasi bisnis. Prinsip desain database yang konsisten di semua branch:
- Gunakan migration.
- Pakai constraint untuk aturan penting.
- Tambahkan index berdasarkan pola query.
- Simpan audit field seperti `createdAt` dan `updatedAt`.
- Gunakan transaksi untuk operasi yang mengubah lebih dari satu tabel.
- Jangan menyimpan secret database ke repository.
