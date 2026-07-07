# Full Flow 04 - Deployment Notes

## Tujuan File

Memberi catatan deployment setelah mockup lokal berjalan.

## Problem Yang Diselesaikan

Mockup lokal tidak otomatis aman untuk production. Ada konfigurasi security, database, secret, dan observability yang harus diperbaiki.

## Konsep Utama

Deployment production harus memisahkan build artifact, secret, database migration, logging, monitoring, dan TLS.

## Pilihan Teknologi Yang Tersedia

- VPS + Docker Compose.
- Platform container seperti Fly.io, Render, Railway.
- Kubernetes.
- Backend di container dan frontend di Vercel.

## Pilihan Yang Dipakai Di Tutorial Ini

Catatan netral: Docker image untuk backend/frontend dan PostgreSQL managed database untuk production.

## Struktur Folder Yang Akan Dibuat

Tidak ada folder baru.

## Command Yang Harus Dijalankan

Build image lokal:

```bash
docker compose build
```

Run:

```bash
docker compose up -d
```

## Full Source Code Untuk Setiap File Yang Dibuat

Tambahkan contoh env production:

```dotenv
# springreact-modular-saas-mockup/.env.production.example
POSTGRES_DB=springreact
POSTGRES_USER=springreact_app
POSTGRES_PASSWORD=replace-with-strong-password
JWT_SECRET=replace-with-64-char-random-secret
CORS_ALLOWED_ORIGINS=https://app.example.com
VITE_API_BASE_URL=https://api.example.com/api
```

## Penjelasan Kode Penting

`JWT_SECRET` tidak boleh default. `CORS_ALLOWED_ORIGINS` harus spesifik domain frontend. Jangan pakai wildcard untuk app auth.

## Cara Menjalankan

Untuk production kecil:

```bash
docker compose --env-file .env.production up -d
```

## Cara Test Manual

1. Buka frontend domain production.
2. Register user baru.
3. Buat organization.
4. Cek log backend tidak mengandung secret.

## Troubleshooting

- Jika migration production gagal, jangan edit migration lama. Buat migration baru.
- Jika token invalid setelah deploy, cek `JWT_SECRET` konsisten.
- Jika CORS gagal, cek origin browser persis termasuk protokol `https`.

## Checklist Akhir

- [ ] Secret production bukan default.
- [ ] Database production backup aktif.
- [ ] TLS aktif.
- [ ] CORS origin spesifik.
- [ ] Log tidak mencetak password/token.

## File Lanjutan Berikutnya

Lanjut ke [../patterns/01-design-patterns-used.md](../patterns/01-design-patterns-used.md).





