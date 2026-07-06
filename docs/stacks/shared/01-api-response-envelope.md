# 01 - API Response Envelope

## Tujuan

Semua output API dibuat konsisten agar frontend tidak menebak-nebak bentuk response.

## Bentuk Umum

Gunakan envelope:

```ts
type ApiResponse<TData, TError = ApiError> = {
  data: TData | null;
  error: TError | null;
  status: HttpStatusCode;
  meta?: ResponseMeta;
};
```

Untuk sukses:

```json
{
  "data": {
    "id": "task_123",
    "title": "Setup project"
  },
  "error": null,
  "status": 200
}
```

Untuk gagal:

```json
{
  "data": null,
  "error": {
    "code": "FORBIDDEN",
    "message": "You do not have access to this organization.",
    "details": null
  },
  "status": 403
}
```

## Response Meta

Tambahkan `meta` hanya jika perlu.

```ts
type ResponseMeta = {
  requestId?: string;
  pagination?: PaginationMeta;
};
```

Contoh list:

```json
{
  "data": [
    { "id": "task_1", "title": "Design database" }
  ],
  "error": null,
  "status": 200,
  "meta": {
    "pagination": {
      "page": 1,
      "pageSize": 20,
      "totalItems": 42,
      "totalPages": 3
    }
  }
}
```

## Kapan Tidak Perlu Envelope

Untuk tRPC, library sudah punya error transport sendiri. Namun DTO output tetap sebaiknya konsisten:

```ts
type ProcedureResult<T> = {
  data: T;
};
```

Jika ingin response tRPC sama seperti REST, tetap boleh pakai `ApiResponse<T>`, tetapi jangan dobel membungkus error tRPC. Pilih salah satu:

- REST memakai `ApiResponse<T>`.
- tRPC memakai return data langsung dan `TRPCError`.
- Jika ingin uniform lintas REST/tRPC, gunakan `Result<T>` di application layer, lalu adapter mengubahnya.

## Best Practice

- `status` memakai HTTP status code angka.
- `error.code` memakai enum/string stabil, bukan pesan bebas.
- `message` boleh diterjemahkan di frontend.
- `details` hanya berisi informasi aman.
- Jangan kirim stack trace ke client.
- Jangan kirim password, token, atau secret di `data` maupun `error.details`.
