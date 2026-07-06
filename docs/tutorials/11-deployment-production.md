# 11 - Deployment, Production Checklist, Dan Operasi

## Environment

Pisahkan:

- Local.
- Test.
- Staging.
- Production.

Setiap environment punya:

- Database sendiri.
- Secret sendiri.
- URL aplikasi sendiri.
- Provider key sendiri.

## Environment Variables

Minimal:

```text
DATABASE_URL
AUTH_SECRET
APP_URL
EMAIL_PROVIDER_API_KEY
PAYMENT_PROVIDER_SECRET
STORAGE_ACCESS_KEY
```

Jangan commit `.env` production.

## Deployment T3/Next.js

Vercel:

1. Connect repository.
2. Set build command.
3. Set env.
4. Set PostgreSQL provider.
5. Jalankan migration.
6. Test auth callback URL.
7. Test webhook URL.

Cloudflare:

1. Pastikan runtime kompatibel.
2. Hindari library Node-only bila memakai edge.
3. Set secret.
4. Deploy preview.
5. Test route dinamis dan API.

## Deployment Enterprise

Pilihan:

- Docker container.
- VM dengan reverse proxy.
- Kubernetes.
- Azure App Service.
- AWS ECS/EKS.

Checklist:

- Build artifact immutable.
- Migration strategy jelas.
- Health check aktif.
- Rollback tersedia.
- Log dikirim ke centralized logging.
- Metrics dikirim ke monitoring.

## Migration Production

Aturan:

- Backup sebelum migration berisiko.
- Jangan rename/drop kolom besar tanpa strategi bertahap.
- Gunakan expand-contract untuk perubahan besar.
- Migration harus idempotent atau dijalankan oleh pipeline yang terkontrol.

Contoh expand-contract:

1. Tambah kolom baru nullable.
2. Deploy app yang menulis kolom lama dan baru.
3. Backfill data.
4. Deploy app yang membaca kolom baru.
5. Drop kolom lama setelah aman.

## Security Checklist

- HTTPS aktif.
- Cookie secure.
- CORS ketat.
- Rate limiting login.
- Secret rotation plan.
- Dependency vulnerability scan.
- Backup database.
- Principle of least privilege untuk database user.
- Admin endpoint terlindungi.

## Backup Dan Restore

Backup tidak cukup. Harus pernah mencoba restore.

Checklist:

- Backup otomatis harian.
- Retention jelas.
- Restore test bulanan.
- Dokumentasi restore tersedia.
- Akses backup terbatas.

## Release Checklist

Sebelum release:

- Changelog singkat.
- Migration review.
- Feature flag bila fitur berisiko.
- Smoke test staging.
- Rollback plan.
- Monitoring dashboard siap.

Setelah release:

- Cek error rate.
- Cek latency.
- Cek log auth dan payment.
- Cek background job.
- Cek feedback user.
