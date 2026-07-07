# Mock Flow 00 - Mockup Ready Fullstack

## Tujuan File

Memberi versi ringkas menjalankan SpringReact Modular SaaS Mockup dari nol sampai bisa dicoba.

## Problem Yang Diselesaikan

Setelah membaca banyak file step-by-step, developer butuh checklist eksekusi cepat.

## Konsep Utama

Mockup ready berarti aplikasi cukup lengkap untuk demo flow utama: auth, organization, project, task board, dan logout.

## Pilihan Teknologi Yang Tersedia

- Jalankan manual.
- Jalankan dengan Docker Compose.
- Deploy ke cloud.

## Pilihan Yang Dipakai Di Tutorial Ini

Docker Compose untuk demo cepat, manual command untuk development.

## Struktur Folder Yang Akan Dibuat

```text
springreact-modular-saas-mockup/
  backend/
  frontend/
  docker-compose.yml
  .env.example
```

## Command Yang Harus Dijalankan

Clone atau buat folder:

```bash
mkdir springreact-modular-saas-mockup
cd springreact-modular-saas-mockup
mkdir backend frontend
```

Install tools:

```bash
java -version
mvn -version
node -v
pnpm -v
docker version
```

Run semua service:

```bash
docker compose up -d
docker compose logs -f
```

Run manual:

```bash
cd backend
./mvnw spring-boot:run
```

```bash
cd frontend
pnpm dev
```

## Full Source Code Untuk Setiap File Yang Dibuat

Gunakan source code dari file berikut:

```text
backend/01-project-setup.md
backend/03-database-flyway-jpa.md
backend/04-common-response-error-pattern.md
backend/05-identity-auth-module.md
backend/06-organization-tenancy-module.md
backend/07-project-module.md
backend/08-task-module.md
frontend/01-project-setup-vite-react.md
frontend/04-api-client-response-error.md
frontend/05-auth-pages.md
frontend/06-dashboard-organization-project-task.md
full-flow/02-docker-compose.md
```

Seed user:

```text
owner@example.com  / Password123!
admin@example.com  / Password123!
member@example.com / Password123!
```

## Penjelasan Kode Penting

Auth menghasilkan access token dan refresh token. Organization menjadi tenant. Project selalu milik organization. Task selalu milik project. Dashboard memakai typed API client agar kontrak backend/frontend konsisten.

## Cara Menjalankan

1. Setup backend dari [../backend/01-project-setup.md](../backend/01-project-setup.md).
2. Setup frontend dari [../frontend/01-project-setup-vite-react.md](../frontend/01-project-setup-vite-react.md).
3. Setup database dari [../backend/03-database-flyway-jpa.md](../backend/03-database-flyway-jpa.md).
4. Run migration dengan menjalankan backend.
5. Run frontend.

## Cara Test Manual

Flow demo:

1. Buka `http://localhost:3000/login` jika memakai Docker Compose, atau `http://localhost:5173/login` jika menjalankan frontend manual.
2. Login `owner@example.com / Password123!`.
3. Buka dashboard.
4. Create organization.
5. Create project.
6. Create task.
7. Update task status.
8. Logout.
9. Register user baru.
10. Login user baru.

## Troubleshooting

- Jika login seed gagal, cek hash BCrypt di `V5__seed_mock_data.sql`.
- Jika dashboard kosong, buat organization baru.
- Jika project atau task forbidden, cek membership organization.
- Jika Docker tidak bisa build frontend, jalankan `pnpm install` untuk membuat lockfile.
- Jika backend tidak bisa connect database, cek host `postgres` di Compose dan `localhost` untuk manual.

## Checklist Akhir

- [ ] Tools terinstall.
- [ ] Backend dibuat.
- [ ] Frontend dibuat.
- [ ] Database PostgreSQL berjalan.
- [ ] Flyway migration berjalan.
- [ ] Backend berjalan.
- [ ] Frontend berjalan.
- [ ] Login seed user berhasil.
- [ ] Register berhasil.
- [ ] Create organization berhasil.
- [ ] Create project berhasil.
- [ ] Create task berhasil.
- [ ] Update task status berhasil.
- [ ] Logout berhasil.

## File Lanjutan Berikutnya

Kembali ke [../README.md](../README.md) atau lanjut memperdalam pattern di [../patterns/01-design-patterns-used.md](../patterns/01-design-patterns-used.md).





