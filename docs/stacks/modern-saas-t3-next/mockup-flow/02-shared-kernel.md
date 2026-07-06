# 02 - Shared Kernel

Target file ini: membuat kontrak umum yang akan dipakai backend dan frontend.

## Buat `src/server/shared/api-response.ts`

```ts
export type ApiError = {
  code: string;
  message: string;
  details?: unknown;
};

export type ApiResponse<T> = {
  data: T | null;
  error: ApiError | null;
  status: number;
};

export function ok<T>(data: T, status = 200): ApiResponse<T> {
  return { data, error: null, status };
}

export function fail(error: ApiError, status: number): ApiResponse<null> {
  return { data: null, error, status };
}
```

Tambahkan file baru karena response dipakai lintas endpoint.

## Buat `src/server/shared/app-error.ts`

```ts
export class AppError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly status: number,
    public readonly details?: unknown
  ) {
    super(message);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = "Forbidden") {
    super("FORBIDDEN", message, 403);
  }
}
```

Tambahkan file baru karena error type dipakai banyak module.

## Buat `src/server/shared/current-user.ts`

```ts
export type CurrentUser = {
  id: string;
  organizationId: string;
};
```

Kenapa file sendiri: `CurrentUser` adalah contract lintas feature, bukan milik task.

## Buat `src/server/shared/domain-event.ts`

```ts
export type DomainEvent = {
  id: string;
  type: string;
  organizationId: string;
  actorUserId: string;
  payload: Record<string, unknown>;
  occurredAt: string;
};
```

Ini dipakai audit log dan Kafka event. Jangan taruh di `tasks/` karena event juga bisa dipakai billing/order/member.

## Aturan Penambahan Fungsi

Jika fungsi hanya dipakai task, jangan tambahkan ke shared. Contoh:

- `canCreateTask()` masuk `server/modules/tasks`;
- `parsePagination()` boleh masuk shared karena dipakai banyak list endpoint;
- `publishTaskCreated()` masuk task/infrastructure atau use case, bukan shared.
