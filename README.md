# Full Stack Tutorial Branches

Repository ini berisi materi pembelajaran full stack yang dipisahkan per branch, per tech stack, lalu per layer backend/frontend. Fokus utamanya adalah modular monolith untuk aplikasi SaaS dan e-commerce, mulai dari database, backend, contract API, sampai UI.

README ini bukan hanya ringkasan. Di bawah ini ada urutan baca, command yang biasa dijalankan, contoh input request, dan contoh code contract yang dipakai lintas stack.

## Isi Repository

| Area | Path | Isi |
| --- | --- | --- |
| Indeks dokumentasi | [docs/README.md](docs/README.md) | Pintu masuk semua materi |
| Materi per stack | [docs/stacks/README.md](docs/stacks/README.md) | Shared convention, T3/Next.js, .NET/Spring, Vue/Nest |
| Tutorial umum | [docs/tutorials/README.md](docs/tutorials/README.md) | Roadmap modular monolith, database, auth, testing, deployment |
| Referensi Git | [docs/kolaborasi-github.md](docs/kolaborasi-github.md), [docs/kasus-umum-git.md](docs/kasus-umum-git.md), [docs/tag-dan-versioning-git.md](docs/tag-dan-versioning-git.md) | Workflow branch, conflict, tag, kasus umum |
| Mock history | [MOCK_ACTIVITY_LOG.md](MOCK_ACTIVITY_LOG.md), [mock-history/](mock-history/), [scripts/mock-history/](scripts/mock-history/) | Timeline simulasi aktivitas |
| Script pembantu | [scripts/generate-mock-history.ps1](scripts/generate-mock-history.ps1), [scripts/generate-backdate-command-plan.sh](scripts/generate-backdate-command-plan.sh) | Generate file mock dan command backdate |

## Struktur Utama

```text
docs/
  stacks/
    shared/
      01-api-response-envelope.md
      02-error-code-and-http-status.md
      03-validation-and-dto.md
      04-pagination-filter-sort.md
      05-module-contracts.md
    modern-saas-t3-next/
      backend/
      frontend/
      full-flow.md
    enterprise-dotnet-spring/
      backend/
      frontend/
      full-flow.md
    typescript-vue-nest/
      backend/
      frontend/
      full-flow.md
  tutorials/
    01-roadmap.md
    02-architecture.md
    ...
    13-branch-implementation-map.md
```

## Daftar Branch Pembelajaran

| Branch | Folder Materi | Backend | Frontend | Fokus |
| --- | --- | --- | --- | --- |
| `tutorial/typescript-next-shadcn` | [docs/stacks/modern-saas-t3-next](docs/stacks/modern-saas-t3-next/README.md) | Next.js server layer, Node.js/Bun, tRPC, PostgreSQL | Next.js App Router, React 19, Tailwind CSS | Modern SaaS, startup, type-safe prototype |
| `tutorial/csharp-blazor-bootstrap` | [docs/stacks/enterprise-dotnet-spring](docs/stacks/enterprise-dotnet-spring/README.md) | .NET atau Spring Boot, PostgreSQL/SQL Server | Angular atau React + TypeScript | Enterprise, secure, reliable, audit-ready |
| `tutorial/typescript-vue-vuetify` | [docs/stacks/typescript-vue-nest](docs/stacks/typescript-vue-nest/README.md) | NestJS modular monolith, PostgreSQL | Vue 3, Vite, Vuetify | Pembanding TypeScript di luar React |

## Tutorial Coding Dari Dasar

Jika targetnya belajar pemrograman dari nol sampai fitur jadi, mulai dari [docs/tutorials/00-belajar-pemrograman-dari-nol.md](docs/tutorials/00-belajar-pemrograman-dari-nol.md). Setelah itu lanjut ke [docs/tutorials/14-step-by-step-programming-flow.md](docs/tutorials/14-step-by-step-programming-flow.md) untuk urutan praktik yang lebih lengkap dari database, migration, seed, shared response, RBAC, domain, repository, use case, controller/router, API client frontend, state, form, list, sampai test manual.
## Cara Membaca Materi

1. Baca shared convention di [docs/stacks/shared/README.md](docs/stacks/shared/README.md).
2. Pilih salah satu stack di [docs/stacks/README.md](docs/stacks/README.md).
3. Baca folder `backend/` dari file `01` sampai selesai.
4. Baca folder `frontend/` dari file `01` sampai selesai.
5. Buka `full-flow.md` di stack tersebut untuk melihat hubungan database, backend, API contract, dan UI.
6. Gunakan [docs/tutorials/](docs/tutorials/README.md) sebagai referensi umum modular monolith lintas stack.

## Command Git Dasar

Ambil update branch remote:

```powershell
git fetch origin
git status
git branch --show-current
```

Buka branch pembelajaran T3/Next.js:

```powershell
git switch tutorial/typescript-next-shadcn
```

Buka branch enterprise:

```powershell
git switch tutorial/csharp-blazor-bootstrap
```

Buka branch Vue/Nest:

```powershell
git switch tutorial/typescript-vue-vuetify
```

Membuat branch fitur baru:

```powershell
git switch main
git pull origin main
git switch -c feat/nama-fitur
```

Commit dan push perubahan:

```powershell
git status
git add .
git commit -m "menambahkan fitur"
git push -u origin feat/nama-fitur
```

Update branch fitur dari `main`:

```powershell
git switch main
git pull origin main
git switch feat/nama-fitur
git merge main
```

Selesaikan merge conflict setelah file diperbaiki:

```powershell
git status
git add nama-file
git commit -m "menyelesaikan merge conflict"
git push
```

Batalkan merge yang sedang conflict:

```powershell
git merge --abort
```

## Command Setup Per Stack

Contoh setup Modern SaaS T3/Next.js:

```powershell
npm create t3-app@latest saas-workspace
cd saas-workspace
npm install
npm run dev
```

Alternatif dengan Bun:

```powershell
bun create t3-app saas-workspace
cd saas-workspace
bun install
bun dev
```

Contoh setup .NET:

```powershell
dotnet new sln -n EnterpriseWorkspace
dotnet new webapi -n EnterpriseWorkspace.Api
dotnet new classlib -n EnterpriseWorkspace.Modules.Tasks
dotnet sln add EnterpriseWorkspace.Api
dotnet sln add EnterpriseWorkspace.Modules.Tasks
dotnet build
dotnet run --project EnterpriseWorkspace.Api
```

Contoh setup Spring Boot:

```powershell
mkdir enterprise-workspace
cd enterprise-workspace
curl https://start.spring.io/starter.zip -o app.zip
```

Contoh setup NestJS:

```powershell
npm i -g @nestjs/cli
nest new workspace-api
cd workspace-api
npm run start:dev
```

Contoh setup Vue 3 + Vite:

```powershell
npm create vite@latest workspace-web -- --template vue-ts
cd workspace-web
npm install
npm run dev
```

## Contract API Lintas Stack

Semua stack memakai response envelope yang sama supaya frontend tidak perlu menebak bentuk response.

Success response:

```json
{
  "success": true,
  "data": {
    "id": "task_01",
    "title": "Membuat modul task",
    "status": "TODO"
  },
  "meta": {
    "requestId": "req_01"
  }
}
```

Error response:

```json
{
  "success": false,
  "error": {
    "code": "TASK_NOT_FOUND",
    "message": "Task tidak ditemukan"
  },
  "meta": {
    "requestId": "req_01"
  }
}
```

TypeScript contract:

```ts
export type ApiResponse<T> =
  | {
      success: true;
      data: T;
      meta?: ResponseMeta;
    }
  | {
      success: false;
      error: AppError;
      meta?: ResponseMeta;
    };

export type ResponseMeta = {
  requestId?: string;
  page?: number;
  pageSize?: number;
  total?: number;
};

export type AppError = {
  code: string;
  message: string;
  details?: unknown;
};
```

DTO input untuk membuat task:

```ts
export type CreateTaskInput = {
  organizationId: string;
  title: string;
  description?: string;
  assigneeId?: string;
};
```

Contoh request JSON:

```json
{
  "organizationId": "org_01",
  "title": "Menyiapkan dashboard task",
  "description": "Buat list, filter, dan form create task",
  "assigneeId": "user_01"
}
```

Query list dengan pagination, filter, dan sort:

```text
GET /api/tasks?page=1&pageSize=20&status=TODO&sort=createdAt:desc
```

## Alur Modular Monolith

Alur implementasi yang dipakai di semua blueprint:

```text
Frontend form input
  -> API client / tRPC client
  -> Controller / router
  -> Auth mengambil currentUserId
  -> Application use case
  -> OrganizationAccessReader membaca role tenant
  -> Policy mengecek permission RBAC
  -> Domain entity menjalankan invariant bisnis
  -> Repository menyimpan atau membaca data scoped organizationId
  -> DTO output
  -> ApiResponse<T>
  -> UI loading/error/success state
```

Contoh input yang dikirim UI:

```json
{
  "organizationId": "org_01",
  "projectId": "project_01",
  "title": "Membuat RBAC task module",
  "description": "User role dicek backend dari membership",
  "assigneeUserId": "user_02"
}
```

Yang tidak boleh dikirim UI sebagai sumber kebenaran:

```json
{
  "role": "owner",
  "permissions": ["task:create", "task:assign"]
}
```

Role dan permission harus dibaca backend dari membership organization. Detail code ada di [docs/stacks/shared/06-rbac-tenant-authorization.md](docs/stacks/shared/06-rbac-tenant-authorization.md) dan blueprint per stack.

Sebuah backend di tutorial ini disebut modular monolith jika:

- Satu aplikasi backend deployable.
- Modul bisnis dipisah jelas, misalnya `Identity`, `Organizations`, `Tasks`, `Catalog`, `Orders`, `Billing`, dan `Audit`.
- Setiap modul punya layer presentation, application, domain, dan infrastructure.
- Domain tidak bergantung pada framework web, ORM, atau provider eksternal.
- Controller/router hanya menerima request dan memanggil use case.
- Application layer menjalankan workflow, authorization, dan transaksi.
- Infrastructure layer menangani database, email, payment, storage, dan provider eksternal.
- Modul lain tidak mengakses tabel atau repository internal module tetangga secara sembarangan.
- Integrasi antar modul memakai public service, contract, atau event.

Contoh flow create task:

```text
UI Form
  -> API Client
  -> Controller / tRPC Router
  -> CreateTask Use Case
  -> Task Domain Entity
  -> Task Repository
  -> Database
  -> ApiResponse<TaskDto>
```

## Domain Pembelajaran

Semua stack memakai pola domain yang sama agar mudah dibandingkan:

- `User` untuk identity.
- `Organization` atau tenant untuk isolasi data.
- `Task` untuk SaaS/project management.
- `Product` dan `Order` untuk e-commerce.
- `Subscription` untuk billing SaaS.

Contoh entity sederhana:

```ts
type TaskStatus = "TODO" | "IN_PROGRESS" | "DONE";

type Task = {
  id: string;
  organizationId: string;
  title: string;
  description?: string;
  status: TaskStatus;
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
};
```

## Referensi Materi Code Blueprint

| Stack | Backend Blueprint | Frontend Blueprint |
| --- | --- | --- |
| Shared | [API response](docs/stacks/shared/01-api-response-envelope.md), [error code](docs/stacks/shared/02-error-code-and-http-status.md), [DTO](docs/stacks/shared/03-validation-and-dto.md), [pagination](docs/stacks/shared/04-pagination-filter-sort.md), [module contract](docs/stacks/shared/05-module-contracts.md), [RBAC tenant authorization](docs/stacks/shared/06-rbac-tenant-authorization.md) | Berlaku untuk semua frontend |
| T3/Next.js | [response dan error](docs/stacks/modern-saas-t3-next/backend/08-code-blueprint-response-error.md), [identity organization task](docs/stacks/modern-saas-t3-next/backend/09-code-blueprint-identity-organization-task.md) | [UI form dan API state](docs/stacks/modern-saas-t3-next/frontend/06-code-blueprint-ui-form.md) |
| .NET/Spring | [.NET blueprint](docs/stacks/enterprise-dotnet-spring/backend/08-code-blueprint-dotnet.md), [Spring blueprint](docs/stacks/enterprise-dotnet-spring/backend/09-code-blueprint-spring.md) | [Angular atau React blueprint](docs/stacks/enterprise-dotnet-spring/frontend/06-code-blueprint-angular-react.md) |
| Vue/Nest | [Nest response](docs/stacks/typescript-vue-nest/backend/06-code-blueprint-nest-response.md), [Nest task module](docs/stacks/typescript-vue-nest/backend/07-code-blueprint-task-module.md) | [Vue composable dan form](docs/stacks/typescript-vue-nest/frontend/04-code-blueprint-vue-composable.md) |

## Abstract Factory Provider

Provider abstraction memakai Abstract Factory dari Refactoring Guru:

- [docs/stacks/modern-saas-t3-next/backend/06-billing-abstract-factory.md](docs/stacks/modern-saas-t3-next/backend/06-billing-abstract-factory.md)
- [docs/stacks/enterprise-dotnet-spring/backend/06-provider-abstract-factory.md](docs/stacks/enterprise-dotnet-spring/backend/06-provider-abstract-factory.md)
- https://refactoring.guru/design-patterns/abstract-factory

Contoh contract provider:

```ts
export interface PaymentProvider {
  createCheckout(input: CreateCheckoutInput): Promise<CheckoutSession>;
  cancelSubscription(subscriptionId: string): Promise<void>;
}

export interface NotificationProvider {
  sendEmail(input: SendEmailInput): Promise<void>;
}

export interface ProviderFactory {
  payment(): PaymentProvider;
  notification(): NotificationProvider;
}
```

## Testing Dan Quality Gate

Checklist test minimal:

```powershell
npm test
npm run lint
npm run typecheck
```

Untuk .NET:

```powershell
dotnet test
dotnet build -c Release
```

Untuk deployment/migration, baca:

- [docs/tutorials/10-testing-observability.md](docs/tutorials/10-testing-observability.md)
- [docs/tutorials/11-deployment-production.md](docs/tutorials/11-deployment-production.md)
- [docs/stacks/modern-saas-t3-next/backend/07-testing-deployment.md](docs/stacks/modern-saas-t3-next/backend/07-testing-deployment.md)
- [docs/stacks/enterprise-dotnet-spring/backend/07-observability-deployment.md](docs/stacks/enterprise-dotnet-spring/backend/07-observability-deployment.md)

## Mock Activity Log

Lihat [MOCK_ACTIVITY_LOG.md](MOCK_ACTIVITY_LOG.md) untuk simulasi timeline aktivitas dari 2026-02-13 sampai 2026-07-06. File tersebut berisi contoh command `git commit --date=<date> -m <message>` dengan Sabtu dan Minggu dilewati. Ini adalah dokumentasi simulasi, bukan riwayat Git aktual.

Generate file mock history default:

```powershell
.\scripts\generate-mock-history.ps1
```

Generate untuk rentang tanggal tertentu:

```powershell
.\scripts\generate-mock-history.ps1 -StartDate 2026-03-01 -EndDate 2026-03-31
```

Generate ke folder output tertentu:

```powershell
.\scripts\generate-mock-history.ps1 -OutputDirectory .\mock-history
```

Generate, commit, dan push hasilnya:

```powershell
.\scripts\generate-mock-history.ps1 -CommitGenerated -Push
```

Generate command plan backdate shell:

```bash
bash scripts/generate-backdate-command-plan.sh
```

Format command backdate yang dihasilkan:

```bash
git add -- <file>
git commit --date=<date> -m <message>
```

## Tag Dan Release

Membuat tag release:

```powershell
git switch main
git pull origin main
git tag -a v1.0.0 -m "rilis versi 1.0.0"
git push origin v1.0.0
```

Melihat tag:

```powershell
git tag
git show v1.0.0
```

Membuat branch hotfix dari tag:

```powershell
git switch -c fix/v1.0.0-hotfix v1.0.0
```

## Catatan Aman

- Periksa `git status` sebelum commit, merge, reset, atau force push.
- Hindari `git reset --hard` jika masih ada perubahan lokal yang belum disimpan.
- Gunakan `git revert <hash-commit>` untuk membatalkan commit yang sudah dipush agar riwayat tetap aman.
- Jangan commit secret seperti token, password, private key, atau `.env` production.
- Untuk konflik Git, ikuti [docs/penyelesaian-conflict-git.md](docs/penyelesaian-conflict-git.md).
