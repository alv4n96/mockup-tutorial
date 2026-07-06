# 02 - Error Code Dan HTTP Status

## Error Shape

```ts
type ApiError = {
  code: ErrorCode;
  message: string;
  details?: unknown;
};
```

## Error Code Umum

| Code | HTTP | Kapan Dipakai |
| --- | --- | --- |
| `VALIDATION_ERROR` | 400 | Input format salah |
| `UNAUTHENTICATED` | 401 | User belum login/token invalid |
| `FORBIDDEN` | 403 | User login tetapi tidak punya akses |
| `NOT_FOUND` | 404 | Resource tidak ditemukan |
| `CONFLICT` | 409 | Duplicate email, duplicate slug, state conflict |
| `RATE_LIMITED` | 429 | Terlalu banyak request |
| `INTERNAL_ERROR` | 500 | Error server tidak terduga |
| `SERVICE_UNAVAILABLE` | 503 | Provider/database sementara tidak tersedia |

## Domain Error

Domain boleh punya error lebih spesifik:

| Code | HTTP | Contoh |
| --- | --- | --- |
| `EMAIL_ALREADY_REGISTERED` | 409 | Register email yang sudah ada |
| `ORGANIZATION_SLUG_TAKEN` | 409 | Slug sudah dipakai |
| `MEMBER_NOT_FOUND` | 404 | User bukan member organization |
| `TASK_ASSIGNEE_NOT_MEMBER` | 400 | Assignee bukan member tenant |
| `ORDER_STOCK_NOT_ENOUGH` | 409 | Checkout stok kurang |
| `PAYMENT_SIGNATURE_INVALID` | 400 | Webhook signature salah |

## Mapping Rule

Application/domain error jangan langsung bergantung pada HTTP. Buat mapping di presentation layer:

```text
Domain/Application Error -> HTTP status + ApiError
```

Contoh:

```text
TaskAssigneeNotMember -> 400 TASK_ASSIGNEE_NOT_MEMBER
MembershipNotFound -> 403 FORBIDDEN
TaskNotFound -> 404 NOT_FOUND
```

## Logging

- 4xx biasa cukup info/warn.
- 5xx harus error log dengan stack trace di server.
- Tambahkan `requestId`, `userId`, dan `organizationId` jika aman.
- Jangan log password, token, card number, atau secret provider.
