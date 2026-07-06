# 08 - Clean Code, Refactoring Guru, Dan Cara Memecah Pekerjaan

Dokumen ini dipakai oleh semua stack. Tujuannya membuat tutorial tidak hanya berisi teori, tetapi juga menjawab pertanyaan praktis:

- file baru dibuat di mana;
- fungsi baru ditambahkan ke file yang sudah ada atau dibuat file baru;
- folder backend dan frontend sebaiknya seperti apa;
- kapan memakai SharedKernel/shared layer;
- pattern mana yang dipakai dan kenapa.

## Prinsip Utama

Tutorial mockup di repository ini memakai prinsip umum dari Clean Code dan design pattern Refactoring Guru, tetapi disederhanakan agar cocok untuk belajar:

- fungsi kecil, satu tujuan;
- nama file dan fungsi menjelaskan maksud;
- controller/router tipis;
- business rule berada di use case/domain;
- akses database berada di repository/infrastructure;
- integrasi eksternal memakai adapter;
- object creation untuk provider memakai factory jika ada beberapa variasi;
- shared code tidak boleh menjadi tempat menaruh semua logic.

## Aturan Membuat File Baru Atau Menambah File Lama

Gunakan aturan ini setiap kali menambah fitur.

| Situasi | Aksi |
| --- | --- |
| Menambah endpoint baru untuk fitur yang sama | Tambahkan method baru di controller/router fitur itu. |
| Menambah workflow bisnis baru | Buat use case baru, misalnya `create-task.use-case.ts`, `invite-member.use-case.ts`, atau `CreateTaskHandler.cs`. |
| Menambah validasi input endpoint | Buat atau update DTO/schema request. |
| Menambah aturan bisnis entity | Tambahkan method di domain entity jika aturan melekat pada entity. |
| Menambah query database baru | Tambahkan method di repository contract dan implementation. |
| Menambah provider eksternal baru | Buat adapter baru di infrastructure, jangan panggil langsung dari use case. |
| Menambah response/error umum lintas fitur | Tambah ke SharedKernel/shared folder. |
| Menambah UI form/list untuk fitur baru | Buat folder feature frontend baru. |

## SharedKernel Atau Shared Layer

SharedKernel hanya untuk aturan lintas fitur yang kecil dan stabil.

Masuk SharedKernel:

- `Result<T>`;
- `ApiResponse<T>`;
- `AppError`;
- pagination contract;
- audit event contract;
- base entity atau audit fields;
- date/id helper yang benar-benar umum;
- interface provider umum seperti `Clock`, `EventPublisher`, `AiAssistant`.

Tidak masuk SharedKernel:

- business rule task;
- query task;
- logic billing;
- logic organization membership yang spesifik;
- UI component khusus satu halaman;
- function yang baru dipakai satu kali.

## Alur Menambah Satu Fitur Baru

Urutan kerja yang dipakai semua stack:

```text
1. Tulis use case dalam bahasa manusia.
2. Tentukan input dan output.
3. Buat DTO/schema request.
4. Buat domain/entity rule jika ada aturan bisnis.
5. Buat repository contract.
6. Buat repository implementation.
7. Buat use case/handler.
8. Tambahkan controller/router endpoint.
9. Tambahkan audit log dan event publisher.
10. Tambahkan API client frontend.
11. Tambahkan state/composable/hook.
12. Tambahkan page/component.
13. Test manual dari UI dan API.
```

## Pola Refactoring Guru Yang Dipakai

| Pattern | Dipakai Untuk | Contoh |
| --- | --- | --- |
| Repository | Memisahkan use case dari database | `TaskRepository`, `PrismaTaskRepository`, `EfTaskRepository` |
| Factory Method | Membuat object/provider berdasarkan config | `createAiAssistant(provider)` |
| Abstract Factory | Satu keluarga provider yang saling berkaitan | `ProviderFactory.payment()`, `ProviderFactory.notification()` |
| Adapter | Membungkus library eksternal | Redis adapter, Kafka adapter, OpenAI adapter |
| Strategy | Mengganti algoritma berdasarkan kebutuhan | AI mock vs AI provider sungguhan |
| Decorator | Menambah behavior tanpa mengubah use case | logging, metrics, caching wrapper |

## Format Folder Umum

Backend modular:

```text
src/
  SharedKernel/
  Modules/
    Tasks/
      Domain/
      Application/
      Infrastructure/
      Presentation/
```

Frontend feature-based:

```text
src/
  shared/
  features/
    tasks/
      api/
      components/
      hooks-or-composables/
      pages/
```

## Contoh Keputusan: Menambah Fungsi `completeTask`

Yang dibuat:

```text
Application:
  CompleteTaskUseCase atau complete-task.use-case.ts

Domain:
  Tambah method `complete()` di Task entity jika status transition punya aturan.

Repository:
  Tambah `findById()` dan `save()` atau `updateStatus()`.

Presentation:
  Tambah endpoint PATCH /api/tasks/{id}/complete.

Frontend:
  Tambah function `completeTask()` di task API client.
  Tambah button Complete di TaskList component.
```

Yang tidak dilakukan:

- menaruh SQL langsung di controller;
- membuat `utils.ts` besar untuk semua logic;
- frontend mengubah status tanpa backend;
- membuat provider AI/Redis/Kafka langsung dipanggil dari component.

## Checklist Review

Sebelum lanjut ke fitur berikutnya:

- controller/router hanya mapping request dan response;
- use case bisa dibaca sebagai workflow bisnis;
- domain tidak import framework web atau ORM;
- repository implementation satu-satunya yang tahu database;
- audit log ditulis setelah action berhasil;
- event Kafka bersifat best-effort untuk mockup;
- Redis cache dihapus saat data berubah;
- frontend punya loading/error/empty state;
- nama file menjelaskan tanggung jawabnya.
