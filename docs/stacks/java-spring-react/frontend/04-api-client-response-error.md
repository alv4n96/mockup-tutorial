# Frontend 04 - API Client, Response, Dan Error

## Tujuan File

Membuat typed API client yang memahami response envelope backend.

## Problem Yang Diselesaikan

Frontend tidak boleh mengulang `fetch`, header Authorization, parse JSON, dan error mapper di setiap component.

## Konsep Utama

API client adalah Adapter. Ia menyembunyikan detail HTTP agar feature hanya memanggil function typed.

## Pilihan Teknologi Yang Tersedia

- `fetch` manual.
- Axios.
- OpenAPI generated client.
- tRPC.

## Pilihan Yang Dipakai Di Tutorial Ini

Wrapper `fetch` typed sederhana.

## Struktur Folder Yang Akan Dibuat

```text
src/lib/api/types.ts
src/lib/api/apiClient.ts
src/lib/api/unwrapResponse.ts
src/lib/errors/errorMapper.ts
```

## Command Yang Harus Dijalankan

```bash
cd frontend
mkdir -p src/lib/api src/lib/errors
```

## Full Source Code Untuk Setiap File Yang Dibuat

```ts
// frontend/src/lib/api/types.ts
export type ApiError = {
  code: "VALIDATION_ERROR" | "UNAUTHORIZED" | "FORBIDDEN" | "NOT_FOUND" | "CONFLICT" | "INTERNAL_SERVER_ERROR" | string;
  message: string;
  field?: string | null;
};

export type ApiResponse<T> = {
  success: boolean;
  data: T | null;
  errors: ApiError[];
};
```

```ts
// frontend/src/lib/api/unwrapResponse.ts
import type { ApiResponse } from "./types";

export class ApiClientError extends Error {
  constructor(public readonly response: ApiResponse<unknown>, public readonly status: number) {
    super(response.errors[0]?.message ?? "Request failed");
  }
}

export function unwrapResponse<T>(response: ApiResponse<T>, status = 200): T {
  if (!response.success || response.data === null) {
    throw new ApiClientError(response as ApiResponse<unknown>, status);
  }
  return response.data;
}
```

```ts
// frontend/src/lib/api/apiClient.ts
import { tokenStore } from "@/lib/auth/tokenStore";
import type { ApiResponse } from "./types";
import { unwrapResponse } from "./unwrapResponse";

const baseUrl = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8080/api";

type RequestOptions = {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  body?: unknown;
  auth?: boolean;
};

export async function apiClient<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (options.auth !== false) {
    const token = tokenStore.getAccessToken();
    if (token) headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(`${baseUrl}${path}`, {
    method: options.method ?? "GET",
    headers,
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });

  const payload = (await response.json()) as ApiResponse<T>;
  return unwrapResponse(payload, response.status);
}
```

```ts
// frontend/src/lib/errors/errorMapper.ts
import { ApiClientError } from "@/lib/api/unwrapResponse";

export function toUserMessage(error: unknown) {
  if (error instanceof ApiClientError) {
    const first = error.response.errors[0];
    if (!first) return "Request gagal.";
    if (first.code === "UNAUTHORIZED") return "Sesi tidak valid. Silakan login lagi.";
    if (first.code === "FORBIDDEN") return "Kamu tidak punya akses untuk aksi ini.";
    if (first.code === "VALIDATION_ERROR") return first.field ? `${first.field}: ${first.message}` : first.message;
    return first.message;
  }
  return "Terjadi kesalahan tidak terduga.";
}
```

`	sx
// frontend/src/components/ui/ToastExample.tsx
import { toUserMessage } from "@/lib/errors/errorMapper";

export function showToastError(error: unknown) {
  window.alert(toUserMessage(error));
}
```

## Penjelasan Kode Penting

`apiClient<T>` menerima generic type sehingga caller tahu bentuk `data`. `unwrapResponse` melempar error jika `success=false`, sehingga component bisa memakai `try/catch`.

## Cara Menjalankan

```bash
cd frontend
pnpm dev
```

## Cara Test Manual

Panggil endpoint protected tanpa token dari component sementara. Error mapper harus mengubah error menjadi pesan user-friendly.

## Troubleshooting

- Jika CORS error, cek backend `CORS_ALLOWED_ORIGINS`.
- Jika `response.json()` gagal, backend mungkin mengirim HTML error.
- Jika token tidak terkirim, cek `tokenStore.getAccessToken()`.

## Checklist Akhir

- [ ] `ApiResponse<T>` frontend sesuai backend.
- [ ] `ApiError` tersedia.
- [ ] `apiClient` mengirim bearer token.
- [ ] Error mapper tersedia.
- [ ] Contoh toast error tersedia.

## File Lanjutan Berikutnya

Lanjut ke [05-auth-pages.md](05-auth-pages.md).




