# Full Flow 03 - End To End Flow

## Tujuan File

Menjalankan flow lengkap dari register/login sampai create task dan update status.

## Problem Yang Diselesaikan

Setelah backend dan frontend dibuat, kita perlu memastikan semua module tersambung.

## Konsep Utama

End-to-end flow menguji kontrak antar layer: frontend form, API client, controller, service, repository, database, lalu response balik ke UI.

## Pilihan Teknologi Yang Tersedia

- Manual browser test.
- Curl/API client test.
- Playwright E2E.

## Pilihan Yang Dipakai Di Tutorial Ini

Manual browser test dan curl smoke test.

## Struktur Folder Yang Akan Dibuat

Tidak ada folder baru. File ini memakai aplikasi yang sudah dibuat.

## Command Yang Harus Dijalankan

```bash
docker compose up -d
```

Smoke login:

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"owner@example.com","password":"Password123!"}'
```

## Full Source Code Untuk Setiap File Yang Dibuat

Tidak ada source code baru. Flow memakai endpoint berikut:

```text
POST /api/auth/register
POST /api/auth/login
POST /api/auth/refresh
POST /api/auth/logout
GET  /api/auth/me
GET  /api/organizations
POST /api/organizations
GET  /api/projects?organizationId={organizationId}
POST /api/projects?organizationId={organizationId}
GET  /api/tasks?organizationId={organizationId}&projectId={projectId}
POST /api/tasks?organizationId={organizationId}&projectId={projectId}
PATCH /api/tasks/{taskId}/status?organizationId={organizationId}&projectId={projectId}
```

## Penjelasan Kode Penting

Endpoint project dan task memakai nested route agar tenant context selalu eksplisit di URL.

## Cara Menjalankan

1. `docker compose up -d`
2. Buka `http://localhost:3000/login` untuk Docker Compose, atau `http://localhost:5173/login` untuk Vite dev server manual
3. Login dengan seed user.

## Cara Test Manual

Flow wajib:

1. Register user baru.
2. Login.
3. Create organization.
4. Create project.
5. Create task.
6. Update task status.
7. Logout.

## Troubleshooting

- Jika register user baru tidak punya organization, buat organization dari dashboard.
- Jika refresh token gagal, login ulang dan cek table `refresh_tokens`.
- Jika task update forbidden, cek organization membership.

## Checklist Akhir

- [ ] Auth flow berjalan.
- [ ] Organization dibuat.
- [ ] Project dibuat di organization.
- [ ] Task dibuat di project.
- [ ] Status task bisa diubah.
- [ ] Logout revoke token.

## File Lanjutan Berikutnya

Lanjut ke [04-deployment-notes.md](04-deployment-notes.md).






