# Backend 02 - Modular Monolith Dan Layered Architecture

## Tujuan File

Membuat struktur package backend agar setiap business module terpisah tetapi tetap berada dalam satu aplikasi Spring Boot.

## Problem Yang Diselesaikan

Project kecil sering dimulai dengan package `controller`, `service`, `repository` global. Saat fitur bertambah, boundary bisnis menjadi kabur. Modular monolith menjaga boundary sejak awal tanpa kompleksitas microservices.

## Konsep Utama

Modular monolith:

- Masih satu deployable JAR.
- Lebih sederhana dari microservices.
- Tetap rapi karena dipisah per business module.
- Cocok untuk app awal yang perlu scale secara struktur.

Layer per module:

- `domain`: entity, enum, domain rule, domain exception.
- `application`: use case, command/query, orchestration.
- `infrastructure`: JPA repository, persistence adapter, external implementation.
- `presentation`: REST controller, request DTO, response DTO.

## Pilihan Teknologi Yang Tersedia

- Package by layer global: cepat, tetapi boundary bisnis lemah.
- Package by feature: rapi untuk modular monolith.
- Hexagonal architecture penuh: kuat, tetapi lebih banyak interface.
- Microservices: boundary kuat, tetapi deployment dan observability lebih kompleks.

## Pilihan Yang Dipakai Di Tutorial Ini

Package by business module dengan layered architecture internal.

## Struktur Folder Yang Akan Dibuat

```text
src/main/java/com/example/springreact/
  common/
    response/
    error/
    security/
    config/
    pagination/
  modules/
    identity/
      domain/
      application/
      infrastructure/
      presentation/
    organization/
      domain/
      application/
      infrastructure/
      presentation/
    project/
      domain/
      application/
      infrastructure/
      presentation/
    task/
      domain/
      application/
      infrastructure/
      presentation/
```

## Command Yang Harus Dijalankan

```bash
cd backend
mkdir -p src/main/java/com/example/springreact/common/{response,error,security,config,pagination}
mkdir -p src/main/java/com/example/springreact/modules/{identity,organization,project,task}/{domain,application,infrastructure,presentation}
```

PowerShell:

```powershell
cd backend
New-Item -ItemType Directory -Force `
  src/main/java/com/example/springreact/common/response, `
  src/main/java/com/example/springreact/common/error, `
  src/main/java/com/example/springreact/common/security, `
  src/main/java/com/example/springreact/common/config, `
  src/main/java/com/example/springreact/common/pagination
```

## Full Source Code Untuk Setiap File Yang Dibuat

```java
// backend/src/main/java/com/example/springreact/common/pagination/PageRequestParams.java
package com.example.springreact.common.pagination;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

public record PageRequestParams(
    @Min(0) int page,
    @Min(1) @Max(100) int size
) {
  public PageRequestParams {
    if (size == 0) {
      size = 20;
    }
  }
}
```

```java
// backend/src/main/java/com/example/springreact/common/pagination/PageResponse.java
package com.example.springreact.common.pagination;

import java.util.List;

public record PageResponse<T>(
    List<T> items,
    int page,
    int size,
    long totalItems,
    int totalPages
) {
}
```

```java
// backend/src/main/java/com/example/springreact/modules/identity/domain/package-info.java
@org.springframework.lang.NonNullApi
package com.example.springreact.modules.identity.domain;
```

```java
// backend/src/main/java/com/example/springreact/modules/organization/domain/package-info.java
@org.springframework.lang.NonNullApi
package com.example.springreact.modules.organization.domain;
```

```java
// backend/src/main/java/com/example/springreact/modules/project/domain/package-info.java
@org.springframework.lang.NonNullApi
package com.example.springreact.modules.project.domain;
```

```java
// backend/src/main/java/com/example/springreact/modules/task/domain/package-info.java
@org.springframework.lang.NonNullApi
package com.example.springreact.modules.task.domain;
```

## Penjelasan Kode Penting

`PageRequestParams` dan `PageResponse` diletakkan di `common` karena pagination adalah kontrak lintas module. Sebaliknya, entity seperti `Project` dan `Task` tidak boleh diletakkan di `common` karena itu milik business module tertentu.

Pada deklarasi record, setiap komponen wajib memiliki tipe data. Jadi parameter pagination harus ditulis seperti `@Min(0) int page`, bukan `@Min(0) page`. Jika tipe `int` hilang, compiler gagal membaca sintaks record sebelum masuk ke blok compact constructor.

Kondisi `if (size == 0)` dipakai untuk memberi default `20` saat request tidak mengirim `size` dan binding primitive `int` menghasilkan nilai awal `0`. Setelah constructor selesai, nilai `size` yang tersimpan tetap `20`, sehingga aturan `@Min(1)` masih selaras dengan nilai final yang divalidasi.

## Cara Menjalankan

Belum ada behavior baru. Pastikan compile:

```bash
cd backend
mvn test
```

## Cara Test Manual

Cek struktur package di IDE. Pastikan tidak ada controller atau service global yang mencampur semua domain.

## Troubleshooting

- Jika package tidak terbaca, cek path `src/main/java/com/example/springreact`.
- Jika command `mkdir -p` gagal di Windows, pakai command PowerShell.
- Jika `PageRequestParams` gagal compile pada deklarasi record, cek apakah setiap komponen sudah punya tipe data. Contoh benar: `@Min(0) int page`.
- Jika ada circular dependency antar module, pindahkan kontrak lintas module ke `application` service atau `common` hanya jika benar-benar reusable.

## Checklist Akhir

- [ ] `common` dibuat untuk concern lintas module.
- [ ] `identity`, `organization`, `project`, dan `task` punya 4 layer.
- [ ] Domain tidak bergantung ke Spring Web.
- [ ] Infrastructure boleh bergantung ke Spring Data JPA.

## File Lanjutan Berikutnya

Lanjut ke [03-database-flyway-jpa.md](03-database-flyway-jpa.md).


