# Backend 08 - Code Blueprint: Response, Error, Result

## Yang Dibuat

Fondasi kode untuk output masuk/keluar yang konsisten.

## File

```text
src/shared/http/http-status.ts
src/shared/api/api-response.ts
src/shared/result/result.ts
src/shared/errors/app-error.ts
src/shared/errors/error-mapper.ts
```

## `http-status.ts`

```ts
export const HttpStatusCode = {
  OK: 200,
  CREATED: 201,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  TOO_MANY_REQUESTS: 429,
  INTERNAL_SERVER_ERROR: 500,
  SERVICE_UNAVAILABLE: 503,
} as const;

export type HttpStatusCode =
  (typeof HttpStatusCode)[keyof typeof HttpStatusCode];
```

## `api-response.ts`

```ts
import type { HttpStatusCode } from "@/shared/http/http-status";

export type ApiError = {
  code: string;
  message: string;
  details?: unknown;
};

export type PaginationMeta = {
  page: number;
  pageSize: number;
  totalItems: number;
  totalPages: number;
};

export type ResponseMeta = {
  requestId?: string;
  pagination?: PaginationMeta;
};

export type ApiResponse<TData> = {
  data: TData | null;
  error: ApiError | null;
  status: HttpStatusCode;
  meta?: ResponseMeta;
};

export function ok<TData>(
  data: TData,
  status: HttpStatusCode = 200
): ApiResponse<TData> {
  return { data, error: null, status };
}

export function fail<TData = never>(
  error: ApiError,
  status: HttpStatusCode
): ApiResponse<TData> {
  return { data: null, error, status };
}
```

## `result.ts`

Application layer sebaiknya tidak tahu HTTP. Gunakan `Result`.

```ts
export type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

export const success = <T>(value: T): Result<T, never> => ({
  ok: true,
  value,
});

export const failure = <E>(error: E): Result<never, E> => ({
  ok: false,
  error,
});
```

## `app-error.ts`

```ts
export class AppError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly details?: unknown
  ) {
    super(message);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = "Forbidden") {
    super("FORBIDDEN", message);
  }
}

export class NotFoundError extends AppError {
  constructor(message = "Resource not found") {
    super("NOT_FOUND", message);
  }
}

export class ConflictError extends AppError {
  constructor(code: string, message: string) {
    super(code, message);
  }
}
```

## `error-mapper.ts`

```ts
import { TRPCError } from "@trpc/server";
import { AppError } from "./app-error";

export function toTRPCError(error: unknown): TRPCError {
  if (error instanceof AppError) {
    if (error.code === "FORBIDDEN") {
      return new TRPCError({ code: "FORBIDDEN", message: error.message });
    }

    if (error.code === "NOT_FOUND") {
      return new TRPCError({ code: "NOT_FOUND", message: error.message });
    }

    if (error.code.includes("CONFLICT") || error.code.includes("TAKEN")) {
      return new TRPCError({ code: "CONFLICT", message: error.message });
    }

    return new TRPCError({ code: "BAD_REQUEST", message: error.message });
  }

  return new TRPCError({
    code: "INTERNAL_SERVER_ERROR",
    message: "Unexpected server error",
  });
}
```

## Cara Pakai Di tRPC Router

```ts
create: protectedProcedure
  .input(createTaskSchema)
  .mutation(async ({ ctx, input }) => {
    const result = await createTaskUseCase.execute({
      currentUserId: ctx.user.id,
      ...input,
    });

    if (!result.ok) {
      throw toTRPCError(result.error);
    }

    return { data: result.value };
  });
```

## Output

Dengan pola ini:

- Application layer return `Result<T>`.
- tRPC adapter mengubah error menjadi `TRPCError`.
- REST adapter bisa mengubah error menjadi `{ data, error, status }`.
- Frontend selalu punya kontrak yang mudah diprediksi.
