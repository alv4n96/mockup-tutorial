# Backend 07 - Testing Dan Deployment

## Yang Dibuat

Quality gate backend sebelum deploy.

## Alur Test

1. Unit test value object dan entity.
2. Use case test dengan fake repository.
3. Integration test repository dengan database test.
4. tRPC procedure test untuk protected route.
5. Tenant isolation test.
6. Webhook idempotency test.

## Deployment

1. Set env production.
2. Jalankan migration.
3. Deploy ke Vercel atau Cloudflare.
4. Test auth callback.
5. Test webhook.
6. Cek log error.

## Output

Backend siap production dengan migration, test penting, dan deployment checklist.
