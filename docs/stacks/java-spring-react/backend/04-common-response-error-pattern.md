# Backend 04 - Common Response Dan Error Pattern

## Tujuan File

Membuat response envelope standar dan global error handler.

## Problem Yang Diselesaikan

Tanpa format response yang konsisten, frontend harus menebak bentuk sukses dan gagal untuk setiap endpoint.

## Konsep Utama

Success:

```jsonc
// backend response success example
{
  "success": true,
  "data": {},
  "errors": []
}
```

Error:

```jsonc
// backend response error example
{
  "success": false,
  "data": null,
  "errors": []
}
```

Catatan: contoh bentuk error di atas menunjukkan shape dasar. Pada error nyata, array `errors` diisi object `ApiError` seperti `VALIDATION_ERROR`, `UNAUTHORIZED`, atau `FORBIDDEN`.

## Pilihan Teknologi Yang Tersedia

- Return DTO langsung dari controller.
- Pakai `ResponseEntity` manual di setiap endpoint.
- Pakai response envelope dengan helper.

## Pilihan Yang Dipakai Di Tutorial Ini

Response envelope eksplisit memakai `ApiResponse<T>` dan `GlobalExceptionHandler`.

## Struktur Folder Yang Akan Dibuat

```text
common/
  response/
    ApiResponse.java
    ApiError.java
  error/
    ErrorCode.java
    BusinessException.java
    NotFoundException.java
    ForbiddenException.java
    GlobalExceptionHandler.java
```

## Command Yang Harus Dijalankan

```bash
cd backend
mkdir -p src/main/java/com/example/springreact/common/response
mkdir -p src/main/java/com/example/springreact/common/error
```

## Full Source Code Untuk Setiap File Yang Dibuat

```java
// backend/src/main/java/com/example/springreact/common/response/ApiError.java
package com.example.springreact.common.response;

public record ApiError(
    String code,
    String message,
    String field
) {
  public static ApiError of(String code, String message) {
    return new ApiError(code, message, null);
  }

  public static ApiError field(String code, String message, String field) {
    return new ApiError(code, message, field);
  }
}
```

```java
// backend/src/main/java/com/example/springreact/common/response/ApiResponse.java
package com.example.springreact.common.response;

import java.util.List;

public record ApiResponse<T>(
    boolean success,
    T data,
    List<ApiError> errors
) {
  public static <T> ApiResponse<T> success(T data) {
    return new ApiResponse<>(true, data, List.of());
  }

  public static ApiResponse<Void> ok() {
    return new ApiResponse<>(true, null, List.of());
  }

  public static <T> ApiResponse<T> fail(List<ApiError> errors) {
    return new ApiResponse<>(false, null, errors);
  }

  public static <T> ApiResponse<T> fail(ApiError error) {
    return new ApiResponse<>(false, null, List.of(error));
  }
}
```

```java
// backend/src/main/java/com/example/springreact/common/error/ErrorCode.java
package com.example.springreact.common.error;

public enum ErrorCode {
  VALIDATION_ERROR,
  UNAUTHORIZED,
  FORBIDDEN,
  NOT_FOUND,
  CONFLICT,
  INTERNAL_SERVER_ERROR
}
```

```java
// backend/src/main/java/com/example/springreact/common/error/BusinessException.java
package com.example.springreact.common.error;

public class BusinessException extends RuntimeException {
  private final ErrorCode code;

  public BusinessException(ErrorCode code, String message) {
    super(message);
    this.code = code;
  }

  public ErrorCode code() {
    return code;
  }
}
```

```java
// backend/src/main/java/com/example/springreact/common/error/NotFoundException.java
package com.example.springreact.common.error;

public class NotFoundException extends BusinessException {
  public NotFoundException(String message) {
    super(ErrorCode.NOT_FOUND, message);
  }
}
```

```java
// backend/src/main/java/com/example/springreact/common/error/ForbiddenException.java
package com.example.springreact.common.error;

public class ForbiddenException extends BusinessException {
  public ForbiddenException(String message) {
    super(ErrorCode.FORBIDDEN, message);
  }
}
```

```java
// backend/src/main/java/com/example/springreact/common/error/ConflictException.java
package com.example.springreact.common.error;

public class ConflictException extends BusinessException {
  public ConflictException(String message) {
    super(ErrorCode.CONFLICT, message);
  }
}
```

```java
// backend/src/main/java/com/example/springreact/common/error/GlobalExceptionHandler.java
package com.example.springreact.common.error;

import com.example.springreact.common.response.ApiError;
import com.example.springreact.common.response.ApiResponse;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {
  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<ApiResponse<Void>> handleValidation(MethodArgumentNotValidException exception) {
    List<ApiError> errors = exception.getBindingResult().getFieldErrors().stream()
        .map(error -> ApiError.field(
            ErrorCode.VALIDATION_ERROR.name(),
            error.getDefaultMessage() == null ? "Field is invalid" : error.getDefaultMessage(),
            error.getField()
        ))
        .toList();

    return ResponseEntity.badRequest().body(ApiResponse.fail(errors));
  }

  @ExceptionHandler(BusinessException.class)
  public ResponseEntity<ApiResponse<Void>> handleBusiness(BusinessException exception) {
    HttpStatus status = switch (exception.code()) {
      case FORBIDDEN -> HttpStatus.FORBIDDEN;
      case NOT_FOUND -> HttpStatus.NOT_FOUND;
      case CONFLICT -> HttpStatus.CONFLICT;
      case UNAUTHORIZED -> HttpStatus.UNAUTHORIZED;
      case VALIDATION_ERROR -> HttpStatus.BAD_REQUEST;
      case INTERNAL_SERVER_ERROR -> HttpStatus.INTERNAL_SERVER_ERROR;
    };

    return ResponseEntity
        .status(status)
        .body(ApiResponse.fail(ApiError.of(exception.code().name(), exception.getMessage())));
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<ApiResponse<Void>> handleUnexpected(Exception exception) {
    return ResponseEntity
        .status(HttpStatus.INTERNAL_SERVER_ERROR)
        .body(ApiResponse.fail(ApiError.of(
            ErrorCode.INTERNAL_SERVER_ERROR.name(),
            "Unexpected server error"
        )));
  }
}
```

## Penjelasan Kode Penting

- `ApiResponse<T>` membuat frontend selalu membaca `success`, `data`, dan `errors`.
- Helper tanpa data diberi nama `ok()`, bukan `success()`, karena record component `boolean success` otomatis membuat accessor instance bernama `success()`. Static method `success()` tanpa parameter akan bentrok dengan accessor record tersebut.
- `BusinessException` dipakai untuk error bisnis, bukan bug sistem.
- `GlobalExceptionHandler` mengubah exception menjadi HTTP status dan body yang konsisten.

## Cara Menjalankan

```bash
cd backend
./mvnw spring-boot:run
```

## Cara Test Manual

Nanti saat endpoint register tersedia, kirim email kosong. Response harus berisi `VALIDATION_ERROR`.

## Troubleshooting

- Jika response error masih HTML, pastikan controller adalah REST controller dan exception tidak ditangkap filter lain.
- Jika field validation tidak muncul, pastikan request DTO memakai annotation `jakarta.validation`.
- Jika muncul error method `success()` sudah ada di `ApiResponse`, pastikan helper response kosong memakai `ApiResponse.ok()`.
- Jika status selalu 500, cek mapping `BusinessException`.

## Checklist Akhir

- [ ] `ApiResponse<T>` tersedia.
- [ ] `ApiError` tersedia.
- [ ] Error code minimum tersedia.
- [ ] Global exception handler aktif.
- [ ] Validation error punya field.

## File Lanjutan Berikutnya

Lanjut ke [05-identity-auth-module.md](05-identity-auth-module.md).







