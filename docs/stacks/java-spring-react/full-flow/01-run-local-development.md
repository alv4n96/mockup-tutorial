# Full Flow 01 - Run Local Development

## Tujuan File

Menjalankan PostgreSQL, backend Spring Boot, dan frontend React Vite secara manual untuk development.

## Problem Yang Diselesaikan

Sebelum Docker Compose, developer perlu tahu cara menjalankan tiap service satu per satu agar debugging mudah.

## Konsep Utama

Local development memisahkan terminal database, backend, dan frontend. Jika ada error, sumber masalah lebih cepat ditemukan.

## Pilihan Teknologi Yang Tersedia

- Semua service manual.
- Database Docker, app manual.
- Semua service Docker Compose.

## Pilihan Yang Dipakai Di Tutorial Ini

Database boleh Docker, backend/frontend manual.

## Struktur Folder Yang Akan Dibuat

```text
springreact-modular-saas-mockup/
  backend/
  frontend/
  .env.example
```

## Command Yang Harus Dijalankan

```bash
docker run --name springreact-postgres \
  -e POSTGRES_DB=springreact \
  -e POSTGRES_USER=springreact \
  -e POSTGRES_PASSWORD=springreact \
  -p 5432:5432 \
  -d postgres:16-alpine
```

Terminal backend:

```bash
cd backend
./mvnw spring-boot:run
```

Terminal frontend:

```bash
cd frontend
pnpm dev
```

## Full Source Code Untuk Setiap File Yang Dibuat

```dotenv
# springreact-modular-saas-mockup/.env.example
POSTGRES_DB=springreact
POSTGRES_USER=springreact
POSTGRES_PASSWORD=springreact
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/springreact
SPRING_DATASOURCE_USERNAME=springreact
SPRING_DATASOURCE_PASSWORD=springreact
JWT_SECRET=replace-with-a-long-random-secret-at-least-32-characters
VITE_API_BASE_URL=http://localhost:8080/api
```

## Penjelasan Kode Penting

Environment root dipakai sebagai referensi lintas service. Backend tetap punya `.env.example` sendiri, tetapi nilai utamanya sama.

## Cara Menjalankan

Ikuti command database, backend, frontend di atas.

## Cara Test Manual

1. Buka `http://localhost:5173/login`.
2. Login `owner@example.com / Password123!`.
3. Buka dashboard.

## Troubleshooting

- Port 5432 bentrok: ubah port host menjadi `5433:5432`.
- Backend gagal migration: cek log Flyway.
- Frontend gagal call backend: cek `VITE_API_BASE_URL`.

## Checklist Akhir

- [ ] PostgreSQL berjalan.
- [ ] Backend berjalan di `8080`.
- [ ] Frontend berjalan di `5173` untuk Vite dev server.
- [ ] Login seed user bisa dicoba.

## File Lanjutan Berikutnya

Lanjut ke [02-docker-compose.md](02-docker-compose.md).






