# 02 - Shared Kernel And Modules

Target: membuat folder yang menjelaskan batas tanggung jawab.

## Struktur Backend

Buat folder:

```text
workspace-api/src/
  shared/
    api/
    errors/
  auth/
  infra/
  audit/
  ai/
  tasks/
    domain/
    application/
    infrastructure/
    presentation/
```

## Shared API Response

Buat `workspace-api/src/shared/api/api-response.ts`.

```ts
export type ApiResponse<T> = {
  data: T | null;
  error: { code: string; message: string; details?: unknown } | null;
  status: number;
};

export function ok<T>(data: T, status = 200): ApiResponse<T> {
  return { data, error: null, status };
}
```

File baru karena semua controller memakai response shape sama.

## Shared Error

Buat `workspace-api/src/shared/errors/app-error.ts`.

```ts
export class AppError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly status: number
  ) {
    super(message);
  }
}
```

## Current User

Buat `workspace-api/src/auth/current-user.ts`.

```ts
import { createParamDecorator, ExecutionContext } from "@nestjs/common";

export type CurrentUserDto = {
  id: string;
  organizationId: string;
};

export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): CurrentUserDto => {
    const request = context.switchToHttp().getRequest();

    return {
      id: String(request.headers["x-demo-user-id"] ?? "user_owner"),
      organizationId: String(request.headers["x-demo-organization-id"] ?? "org_demo"),
    };
  }
);
```

Ini mock auth. Saat production, decorator tetap bisa dipakai tetapi isinya membaca JWT/session.

## Module Boundary

Aturan:

- `presentation` menerima HTTP request;
- `application` berisi use case;
- `domain` berisi entity/rule;
- `infrastructure` berisi Prisma/Redis/Kafka implementation;
- `shared` hanya untuk hal lintas module.

Jika membuat fungsi baru:

- endpoint baru masuk `presentation`;
- workflow baru masuk `application`;
- database query baru masuk `infrastructure`;
- rule entity masuk `domain`.
