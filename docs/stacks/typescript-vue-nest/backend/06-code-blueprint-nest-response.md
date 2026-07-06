# Backend 06 - Code Blueprint NestJS: Response Dan Error

## Yang Dibuat

Response envelope, exception filter, dan DTO contract untuk NestJS.

## Struktur File

```text
src/shared/api/api-response.ts
src/shared/errors/app-error.ts
src/shared/errors/http-exception.filter.ts
src/shared/interceptors/api-response.interceptor.ts
```

## `api-response.ts`

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
  meta?: {
    requestId?: string;
    pagination?: {
      page: number;
      pageSize: number;
      totalItems: number;
      totalPages: number;
    };
  };
};

export function apiSuccess<T>(data: T, status = 200): ApiResponse<T> {
  return { data, error: null, status };
}

export function apiFail(error: ApiError, status: number): ApiResponse<null> {
  return { data: null, error, status };
}
```

## `app-error.ts`

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

export class ForbiddenAppError extends AppError {
  constructor(message = "Forbidden") {
    super("FORBIDDEN", message, 403);
  }
}

export class ValidationAppError extends AppError {
  constructor(code: string, message: string, details?: unknown) {
    super(code, message, 400, details);
  }
}
```

## Exception Filter

```ts
import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from "@nestjs/common";
import { Response } from "express";
import { apiFail } from "../api/api-response";
import { AppError } from "./app-error";

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const response = host.switchToHttp().getResponse<Response>();

    if (exception instanceof AppError) {
      response.status(exception.status).json(
        apiFail(
          {
            code: exception.code,
            message: exception.message,
            details: exception.details,
          },
          exception.status
        )
      );
      return;
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      response.status(status).json(
        apiFail(
          {
            code: status === 404 ? "NOT_FOUND" : "HTTP_ERROR",
            message: exception.message,
          },
          status
        )
      );
      return;
    }

    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json(
      apiFail(
        {
          code: "INTERNAL_ERROR",
          message: "Unexpected server error",
        },
        HttpStatus.INTERNAL_SERVER_ERROR
      )
    );
  }
}
```

## Response Interceptor

```ts
import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from "@nestjs/common";
import { map } from "rxjs/operators";
import { apiSuccess } from "../api/api-response";

@Injectable()
export class ApiResponseInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler) {
    const status = context.switchToHttp().getResponse().statusCode;
    return next.handle().pipe(map((data) => apiSuccess(data, status)));
  }
}
```

## Register Global

```ts
app.useGlobalFilters(new HttpExceptionFilter());
app.useGlobalInterceptors(new ApiResponseInterceptor());
```

## Output

Semua controller Nest bisa return DTO biasa, lalu interceptor membungkus menjadi:

```ts
{ data, error: null, status }
```
