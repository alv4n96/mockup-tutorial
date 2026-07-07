# Backend 07 - Testing & Deployment

File ini menjelaskan strategi testing dan deployment untuk backend modern SaaS task workspace di stack `modern-saas-t3-next`.

Testing dan deployment penting untuk SaaS karena aplikasi menyimpan data user, organization, task, subscription, dan billing. Bug kecil di tenant isolation, auth, migration, atau webhook bisa menyebabkan data bocor, pembayaran salah, atau downtime.

Modular monolith dari file `02-modular-monolith-layers.md` membuat testing lebih mudah karena logic dipisah ke layer yang jelas. Domain bisa dites tanpa database, service bisa dites dengan fake repository, repository bisa dites dengan database test, dan tRPC router bisa dites sebagai kontrak API backend.

Testing backend harus mencakup:

- domain layer;
- service/use case layer;
- repository/infrastructure layer;
- tRPC router/presentation layer;
- shared helper;
- integration flow penting seperti auth, tenancy, task, dan billing webhook.

## Jenis Testing

### Unit Test

Unit test mengetes bagian kecil secara terisolasi. Contoh: rule status task, helper pagination, atau service dengan fake repository.

Unit test harus cepat dan tidak bergantung ke database asli.

### Integration Test

Integration test mengetes beberapa bagian yang bekerja bersama. Contoh: Prisma repository dengan database test, atau tRPC router dengan context test.

Integration test lebih lambat dari unit test, tetapi penting untuk memastikan query dan wiring benar.

### End-to-end Test Backend/API

E2E backend/API mengetes flow dari request API sampai database. Contoh: login, create organization, create project, create task, lalu list task.

Untuk file ini, E2E dibahas sebagai konsep ringan agar fokus tetap pada backend layer.

### Repository Test

Repository test memastikan query Prisma benar. Ini penting untuk tenant isolation karena banyak bug data bocor berasal dari query yang lupa filter `organizationId`.

### Service / Use Case Test

Service test memastikan workflow dan business rule benar. Contoh: member biasa tidak boleh add member, assignee harus member organization, webhook duplicate tidak memproses ulang subscription.

### Contract Test Sederhana Untuk tRPC

Contract test memastikan procedure tRPC menerima input yang benar, menolak input invalid, dan memakai protected procedure.

### Smoke Test

Smoke test adalah test singkat setelah deploy untuk memastikan aplikasi hidup. Contoh: cek `/api/health`, login staging user, create organization, create task.

### Regression Test

Regression test memastikan bug lama tidak muncul lagi. Jika pernah ada bug tenant leakage, buat test khusus untuk kasus itu.

### Migration Test

Migration test memastikan migration Prisma bisa dijalankan pada database test dan schema hasilnya bisa dipakai aplikasi.

### Seed Test

Seed test memastikan script seed bisa dijalankan ulang tanpa membuat data duplikat dan tanpa error.

## Testing Strategy Per Layer

### Domain Layer

Test domain layer untuk entity method dan business rule. Domain test tidak butuh database.

Contoh:

- validasi title task;
- status transition task;
- role policy organization;
- plan limit billing.

### Application Layer

Test service/use case dengan fake repository, fake provider, dan fake token service.

Contoh:

- `IdentityService.register`;
- `OrganizationService.addMember`;
- `TaskService.changeTaskStatus`;
- `BillingService.createCheckoutSession`.

### Infrastructure Layer

Test Prisma repository dengan database test. Jangan pakai production database.

Contoh:

- project list harus filter `organizationId`;
- task detail harus match `organizationId + projectId + taskId`;
- billing webhook event idempotency.

### Presentation Layer

Test tRPC router/procedure untuk validasi input Zod, protected procedure, dan mapping error.

Contoh:

- request tanpa user ditolak;
- input invalid menghasilkan error Zod;
- procedure valid memanggil service flow.

### Shared Layer

Test helper umum seperti Result, pagination, dan error helper. Shared layer sering dipakai banyak module, jadi bug kecil bisa menyebar luas.

## Install Testing Dependency

Install Vitest dan coverage:

```bash
npm install -D vitest @vitest/coverage-v8
```

Penjelasan:

- `vitest`: test runner untuk TypeScript/JavaScript.
- `@vitest/coverage-v8`: coverage provider berbasis V8 untuk melihat bagian code yang sudah dites.

Install `tsx` jika belum ada:

```bash
npm install -D tsx
```

Penjelasan:

- `tsx`: menjalankan script TypeScript langsung, berguna untuk seed/test helper.

Jika butuh API/e2e HTTP test, install Supertest:

```bash
npm install -D supertest
```

```bash
npm install -D @types/supertest
```

Penjelasan:

- `supertest`: helper untuk mengetes HTTP server.
- `@types/supertest`: type definition untuk TypeScript.

Untuk tRPC caller test, Supertest tidak selalu dibutuhkan karena `appRouter.createCaller(...)` bisa mengetes procedure langsung.

## Konfigurasi Vitest

Buat file `vitest.config.ts`:

```ts
// vitest.config.ts
import { defineConfig } from "vitest/config";
import path from "node:path";

export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts", "src/**/*.test.ts"],
    globals: true,
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html"],
      include: ["src/server/**/*.ts", "src/shared/**/*.ts"],
      exclude: [
        "src/**/*.d.ts",
        "src/app/**",
        "src/**/presentation/**/*.ts",
      ],
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "src"),
    },
  },
});
```

Penjelasan:

- `environment: "node"` cocok untuk backend/server layer.
- `include` mencari file test di `tests/` dan dekat source jika dibutuhkan.
- `alias @` mengikuti import alias dari Next.js.
- Coverage fokus pada `src/server` dan `src/shared`.
- Presentation layer bisa dites lewat integration tRPC, jadi boleh dikecualikan dari coverage unit jika ingin realistis.

## Update `package.json` Scripts

Tambahkan script berikut:

```json
// package.json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "test:unit": "vitest run tests/unit",
    "test:integration": "vitest run tests/integration",
    "db:migrate": "prisma migrate dev",
    "db:seed": "tsx prisma/seed.ts"
  }
}
```

Fungsi script:

- `test`: menjalankan semua test satu kali.
- `test:watch`: menjalankan test mode watch saat development.
- `test:coverage`: menjalankan test dengan laporan coverage.
- `test:unit`: menjalankan unit test.
- `test:integration`: menjalankan integration test.
- `typecheck`: memastikan TypeScript valid.
- `lint`: menjalankan lint.
- `build`: memastikan production build berhasil.
- `db:migrate`: menjalankan migration development.
- `db:seed`: menjalankan seed awal.

## Struktur Folder Testing

Gunakan struktur:

```txt
tests/
├── unit/
│   ├── shared/
│   ├── identity/
│   ├── organizations/
│   ├── projects/
│   ├── tasks/
│   └── billing/
│
├── integration/
│   ├── repositories/
│   ├── trpc/
│   └── database/
│
├── fixtures/
│   ├── users.fixture.ts
│   ├── organizations.fixture.ts
│   └── tasks.fixture.ts
│
└── helpers/
    ├── test-db.ts
    ├── test-context.ts
    └── test-factory.ts
```

Fungsi folder:

- `tests/unit`: test cepat tanpa database asli.
- `tests/integration/repositories`: test Prisma repository dengan database test.
- `tests/integration/trpc`: test tRPC caller dan protected procedure.
- `tests/integration/database`: test migration, seed, dan database helper.
- `tests/fixtures`: data contoh reusable.
- `tests/helpers`: helper database, context, dan factory test data.

## Unit Test Shared Result

Buat file `tests/unit/shared/result.test.ts`:

```ts
// tests/unit/shared/result.test.ts
import { describe, expect, it } from "vitest";
import { err, ok } from "@/shared/result/result";

describe("AppResult", () => {
  it("creates success result", () => {
    const result = ok({ id: "task_1" });

    expect(result.ok).toBe(true);
    expect(result.value).toEqual({ id: "task_1" });
  });

  it("creates failure result", () => {
    const result = err("VALIDATION_ERROR", "Title is required.");

    expect(result.ok).toBe(false);
    expect(result.error).toBe("VALIDATION_ERROR");
    expect(result.message).toBe("Title is required.");
  });

  it("keeps error code and message", () => {
    const result = err("FORBIDDEN", "Access denied.");

    expect(result).toEqual({
      ok: false,
      error: "FORBIDDEN",
      message: "Access denied.",
    });
  });
});
```

## Unit Test Domain Task Status Strategy

Buat file `tests/unit/tasks/task-status-transition.strategy.test.ts`:

```ts
// tests/unit/tasks/task-status-transition.strategy.test.ts
import { describe, expect, it } from "vitest";
import { DefaultTaskStatusTransitionStrategy } from "@/server/modules/tasks/infrastructure/default-task-status-transition.strategy";
import type { TaskEntity } from "@/server/modules/tasks/domain/task.entity";

function createTask(status: TaskEntity["status"]): TaskEntity {
  return {
    id: "task_1",
    organizationId: "org_1",
    projectId: "project_1",
    title: "Prepare release",
    description: null,
    status,
    priority: "MEDIUM",
    assigneeId: null,
    reporterId: "user_1",
    dueDate: null,
    archivedAt: status === "ARCHIVED" ? new Date("2026-01-01") : null,
    createdAt: new Date("2026-01-01"),
    updatedAt: new Date("2026-01-01"),
  };
}

describe("DefaultTaskStatusTransitionStrategy", () => {
  const strategy = new DefaultTaskStatusTransitionStrategy();

  it("allows TODO to IN_PROGRESS", () => {
    const result = strategy.canTransition({
      task: createTask("TODO"),
      nextStatus: "IN_PROGRESS",
    });

    expect(result.allowed).toBe(true);
  });

  it("rejects TODO to DONE", () => {
    const result = strategy.canTransition({
      task: createTask("TODO"),
      nextStatus: "DONE",
    });

    expect(result.allowed).toBe(false);
  });

  it("allows DONE to ARCHIVED", () => {
    const result = strategy.canTransition({
      task: createTask("DONE"),
      nextStatus: "ARCHIVED",
    });

    expect(result.allowed).toBe(true);
  });

  it("rejects ARCHIVED to TODO", () => {
    const result = strategy.canTransition({
      task: createTask("ARCHIVED"),
      nextStatus: "TODO",
    });

    expect(result.allowed).toBe(false);
  });
});
```

## Unit Test Project Domain

Jika module `projects` punya entity sederhana, test domain rule-nya seperti ini.

Buat file `tests/unit/projects/project.entity.test.ts`:

```ts
// tests/unit/projects/project.entity.test.ts
import { describe, expect, it } from "vitest";

type ProjectStatus = "ACTIVE" | "ARCHIVED" | "COMPLETED";

type ProjectEntity = {
  id: string;
  organizationId: string;
  name: string;
  status: ProjectStatus;
  archivedAt: Date | null;
};

function createProject(params?: Partial<ProjectEntity>): ProjectEntity {
  return {
    id: "project_1",
    organizationId: "org_1",
    name: "Launch Plan",
    status: "ACTIVE",
    archivedAt: null,
    ...params,
  };
}

function renameProject(project: ProjectEntity, name: string): ProjectEntity {
  if (project.status === "COMPLETED") {
    throw new Error("COMPLETED_PROJECT_CANNOT_BE_CHANGED");
  }

  return {
    ...project,
    name: name.trim(),
  };
}

function archiveProject(project: ProjectEntity): ProjectEntity {
  return {
    ...project,
    status: "ARCHIVED",
    archivedAt: new Date("2026-01-01"),
  };
}

describe("Project entity rules", () => {
  it("creates project", () => {
    const project = createProject();

    expect(project.name).toBe("Launch Plan");
    expect(project.organizationId).toBe("org_1");
  });

  it("updates project", () => {
    const project = renameProject(createProject(), " New Name ");

    expect(project.name).toBe("New Name");
  });

  it("archives project", () => {
    const project = archiveProject(createProject());

    expect(project.status).toBe("ARCHIVED");
    expect(project.archivedAt).toBeInstanceOf(Date);
  });

  it("rejects changing completed project", () => {
    expect(() =>
      renameProject(createProject({ status: "COMPLETED" }), "New Name"),
    ).toThrow("COMPLETED_PROJECT_CANNOT_BE_CHANGED");
  });
});
```

Catatan: jika project entity sudah ada di `src/server/modules/projects/domain`, import entity asli. Contoh di atas dibuat self-contained agar pembaca paham bentuk test domain.

## Unit Test Identity Service

Buat file `tests/unit/identity/identity.service.test.ts`:

```ts
// tests/unit/identity/identity.service.test.ts
import { describe, expect, it } from "vitest";
import { IdentityService } from "@/server/modules/identity/application/identity.service";
import type { PasswordHasher } from "@/server/modules/identity/application/password-hasher";
import type { TokenService } from "@/server/modules/identity/application/token.service";
import type {
  CreateUserData,
  UserRepository,
} from "@/server/modules/identity/application/user.repository";
import type { UserEntity } from "@/server/modules/identity/domain/user.entity";

class FakeUserRepository implements UserRepository {
  users = new Map<string, UserEntity>();

  async findById(id: string) {
    return [...this.users.values()].find((user) => user.id === id) ?? null;
  }

  async findByEmail(email: string) {
    return this.users.get(email) ?? null;
  }

  async create(data: CreateUserData) {
    const user: UserEntity = {
      id: `user_${this.users.size + 1}`,
      email: data.email,
      name: data.name ?? null,
      passwordHash: data.passwordHash,
      role: data.role ?? "MEMBER",
      createdAt: new Date("2026-01-01"),
      updatedAt: new Date("2026-01-01"),
    };

    this.users.set(user.email, user);
    return user;
  }
}

class FakePasswordHasher implements PasswordHasher {
  async hash(password: string) {
    return `hashed:${password}`;
  }

  async verify(password: string, passwordHash: string) {
    return passwordHash === `hashed:${password}`;
  }
}

class FakeTokenService implements TokenService {
  async sign() {
    return "fake-token";
  }

  async verify() {
    return null;
  }
}

function createService(repository = new FakeUserRepository()) {
  return {
    repository,
    service: new IdentityService(
      repository,
      new FakePasswordHasher(),
      new FakeTokenService(),
    ),
  };
}

describe("IdentityService", () => {
  it("registers user successfully", async () => {
    const { service } = createService();

    const result = await service.register({
      email: "Owner@Example.com",
      name: "Owner",
      password: "password123",
    });

    expect(result.ok).toBe(true);
    expect(result.value.user.email).toBe("owner@example.com");
    expect(result.value.token).toBe("fake-token");
  });

  it("rejects duplicate email", async () => {
    const { service } = createService();

    await service.register({
      email: "owner@example.com",
      password: "password123",
    });

    const result = await service.register({
      email: "owner@example.com",
      password: "password123",
    });

    expect(result.ok).toBe(false);
    expect(result.error).toBe("EMAIL_ALREADY_REGISTERED");
  });

  it("logs in successfully", async () => {
    const { service } = createService();

    await service.register({
      email: "owner@example.com",
      password: "password123",
    });

    const result = await service.login({
      email: "owner@example.com",
      password: "password123",
    });

    expect(result.ok).toBe(true);
    expect(result.value.token).toBe("fake-token");
  });

  it("rejects wrong password", async () => {
    const { service } = createService();

    await service.register({
      email: "owner@example.com",
      password: "password123",
    });

    const result = await service.login({
      email: "owner@example.com",
      password: "wrong-password",
    });

    expect(result.ok).toBe(false);
    expect(result.error).toBe("INVALID_CREDENTIALS");
  });

  it("does not expose plain password in response", async () => {
    const { service } = createService();

    const result = await service.register({
      email: "owner@example.com",
      password: "password123",
    });

    expect(JSON.stringify(result)).not.toContain("password123");
    expect(JSON.stringify(result)).not.toContain("passwordHash");
  });
});
```

## Unit Test Organization Service

Buat file `tests/unit/organizations/organization.service.test.ts`:

```ts
// tests/unit/organizations/organization.service.test.ts
import { describe, expect, it } from "vitest";
import { OrganizationService } from "@/server/modules/organizations/application/organization.service";
import type {
  CreateOrganizationData,
  OrganizationRepository,
  OrganizationWithMembership,
} from "@/server/modules/organizations/application/organization.repository";
import type { OrganizationEntity } from "@/server/modules/organizations/domain/organization.entity";
import type { OrganizationMemberEntity } from "@/server/modules/organizations/domain/organization-member.entity";
import type { OrganizationRole } from "@/server/modules/organizations/domain/organization-role";

class FakeOrganizationRepository implements OrganizationRepository {
  organizations = new Map<string, OrganizationEntity>();
  members = new Map<string, OrganizationMemberEntity>();
  users = new Set(["owner_1", "member_1", "target_1"]);

  private key(userId: string, organizationId: string) {
    return `${userId}:${organizationId}`;
  }

  async create(data: CreateOrganizationData): Promise<OrganizationWithMembership> {
    const organization: OrganizationEntity = {
      id: "org_1",
      name: data.name,
      slug: data.slug,
      createdAt: new Date("2026-01-01"),
      updatedAt: new Date("2026-01-01"),
    };

    const membership: OrganizationMemberEntity = {
      id: "member_owner",
      userId: data.ownerUserId,
      organizationId: organization.id,
      role: "OWNER",
      createdAt: new Date("2026-01-01"),
      updatedAt: new Date("2026-01-01"),
    };

    this.organizations.set(organization.id, organization);
    this.members.set(this.key(data.ownerUserId, organization.id), membership);

    return { ...organization, membership };
  }

  async findById(id: string) {
    return this.organizations.get(id) ?? null;
  }

  async findBySlug(slug: string) {
    return [...this.organizations.values()].find((org) => org.slug === slug) ?? null;
  }

  async findManyByUserId(userId: string) {
    return [...this.members.values()]
      .filter((member) => member.userId === userId)
      .map((membership) => ({
        ...this.organizations.get(membership.organizationId)!,
        membership,
      }));
  }

  async findMember(params: { organizationId: string; userId: string }) {
    return this.members.get(this.key(params.userId, params.organizationId)) ?? null;
  }

  async findMembers() {
    return [];
  }

  async addMember(params: {
    organizationId: string;
    userId: string;
    role: OrganizationRole;
  }) {
    const member: OrganizationMemberEntity = {
      id: `member_${params.userId}`,
      userId: params.userId,
      organizationId: params.organizationId,
      role: params.role,
      createdAt: new Date("2026-01-01"),
      updatedAt: new Date("2026-01-01"),
    };

    this.members.set(this.key(params.userId, params.organizationId), member);
    return member;
  }

  async updateMemberRole(params: {
    organizationId: string;
    userId: string;
    role: OrganizationRole;
  }) {
    const member = this.members.get(this.key(params.userId, params.organizationId));

    if (!member) {
      throw new Error("MEMBER_NOT_FOUND");
    }

    member.role = params.role;
    return member;
  }

  async removeMember(params: { organizationId: string; userId: string }) {
    this.members.delete(this.key(params.userId, params.organizationId));
  }

  async countOwners(organizationId: string) {
    return [...this.members.values()].filter(
      (member) => member.organizationId === organizationId && member.role === "OWNER",
    ).length;
  }

  async userExists(userId: string) {
    return this.users.has(userId);
  }
}

describe("OrganizationService", () => {
  it("creates organization with OWNER", async () => {
    const service = new OrganizationService(new FakeOrganizationRepository());

    const result = await service.createOrganization({
      actorUserId: "owner_1",
      name: "Acme Studio",
    });

    expect(result.ok).toBe(true);
    expect(result.value.membership.role).toBe("OWNER");
  });

  it("listMine returns only user organizations", async () => {
    const repository = new FakeOrganizationRepository();
    const service = new OrganizationService(repository);

    await service.createOrganization({ actorUserId: "owner_1", name: "Acme" });

    const organizations = await service.getMyOrganizations("owner_1");

    expect(organizations).toHaveLength(1);
  });

  it("rejects member add member", async () => {
    const repository = new FakeOrganizationRepository();
    const service = new OrganizationService(repository);

    await service.createOrganization({ actorUserId: "owner_1", name: "Acme" });
    await repository.addMember({ organizationId: "org_1", userId: "member_1", role: "MEMBER" });

    const result = await service.addMember({
      actorUserId: "member_1",
      organizationId: "org_1",
      targetUserId: "target_1",
      role: "MEMBER",
    });

    expect(result.ok).toBe(false);
    expect(result.error).toBe("MANAGE_MEMBERS_FORBIDDEN");
  });

  it("does not remove last owner", async () => {
    const repository = new FakeOrganizationRepository();
    const service = new OrganizationService(repository);

    await service.createOrganization({ actorUserId: "owner_1", name: "Acme" });

    const result = await service.removeMember({
      actorUserId: "owner_1",
      organizationId: "org_1",
      targetUserId: "owner_1",
    });

    expect(result.ok).toBe(false);
    expect(result.error).toBe("OWNER_REQUIRED");
  });
});
```

## Unit Test Billing Service Dengan Mock Factory

Buat file `tests/unit/billing/billing.service.test.ts`:

```ts
// tests/unit/billing/billing.service.test.ts
import { describe, expect, it } from "vitest";
import { BillingService } from "@/server/modules/billing/application/billing.service";
import { FeatureLimitService } from "@/server/modules/billing/application/feature-limit.service";
import type { BillingProviderFactory } from "@/server/modules/billing/application/billing-provider.factory";
import type { BillingProviderClient } from "@/server/modules/billing/application/billing-provider-client";
import type {
  BillingRepository,
  UpsertSubscriptionData,
} from "@/server/modules/billing/application/billing.repository";
import type { OrganizationBillingAccessChecker } from "@/server/modules/billing/application/organization-billing-access-checker";
import type { BillingSubscriptionEntity } from "@/server/modules/billing/domain/subscription.entity";

class FakeBillingRepository implements BillingRepository {
  subscription: BillingSubscriptionEntity | null = null;
  processedEvents = new Set<string>();
  projectCount = 0;
  memberCount = 0;
  taskCount = 0;

  async findSubscriptionByOrganizationId() {
    return this.subscription;
  }

  async upsertSubscription(data: UpsertSubscriptionData) {
    this.subscription = {
      id: "sub_1",
      organizationId: data.organizationId,
      provider: data.provider,
      providerCustomerId: data.providerCustomerId ?? null,
      providerSubscriptionId: data.providerSubscriptionId ?? null,
      planKey: data.planKey,
      status: data.status,
      currentPeriodStart: data.currentPeriodStart ?? null,
      currentPeriodEnd: data.currentPeriodEnd ?? null,
      trialEndsAt: data.trialEndsAt ?? null,
      cancelAtPeriodEnd: data.cancelAtPeriodEnd ?? false,
      createdAt: new Date("2026-01-01"),
      updatedAt: new Date("2026-01-01"),
    };

    return this.subscription;
  }

  async hasProcessedWebhookEvent(params: { eventId: string }) {
    return this.processedEvents.has(params.eventId);
  }

  async markWebhookEventProcessed(params: { eventId: string }) {
    this.processedEvents.add(params.eventId);
  }

  async countOrganizationMembers() {
    return this.memberCount;
  }

  async countOrganizationProjects() {
    return this.projectCount;
  }

  async countOrganizationTasks() {
    return this.taskCount;
  }
}

class FakeAccessChecker implements OrganizationBillingAccessChecker {
  constructor(private readonly role: "OWNER" | "ADMIN" | "MEMBER" | null = "OWNER") {}

  async getAccess() {
    if (!this.role) {
      return null;
    }

    return {
      organizationId: "org_1",
      organizationName: "Acme",
      actorRole: this.role,
    };
  }
}

class FakeBillingProviderClient implements BillingProviderClient {
  async createCheckoutSession() {
    return {
      url: "http://localhost:3000/mock-checkout",
      providerSessionId: "checkout_1",
    };
  }

  async createCustomerPortalSession() {
    return {
      url: "http://localhost:3000/mock-portal",
    };
  }

  async verifyWebhook() {
    return {
      provider: "MOCK" as const,
      eventId: "evt_1",
      eventType: "subscription.updated",
      organizationId: "org_1",
      providerCustomerId: "cus_1",
      providerSubscriptionId: "sub_1",
      planKey: "PRO",
      status: "ACTIVE" as const,
      rawPayload: {},
    };
  }
}

class FakeBillingProviderFactory implements BillingProviderFactory {
  provider = "MOCK" as const;

  createClient() {
    return new FakeBillingProviderClient();
  }
}

function createService(params?: { role?: "OWNER" | "ADMIN" | "MEMBER" | null }) {
  const repository = new FakeBillingRepository();
  const service = new BillingService(
    repository,
    new FakeAccessChecker(params?.role ?? "OWNER"),
    new FakeBillingProviderFactory(),
  );

  return { repository, service };
}

describe("BillingService", () => {
  it("returns plans", () => {
    const { service } = createService();

    expect(service.getAvailablePlans().length).toBeGreaterThan(0);
  });

  it("creates checkout session with mock provider", async () => {
    const { service } = createService();

    const result = await service.createCheckoutSession({
      actorUserId: "user_1",
      organizationId: "org_1",
      planKey: "PRO",
    });

    expect(result.ok).toBe(true);
    expect(result.value.url).toContain("mock-checkout");
  });

  it("rejects non-admin billing action", async () => {
    const { service } = createService({ role: "MEMBER" });

    const result = await service.createCheckoutSession({
      actorUserId: "user_1",
      organizationId: "org_1",
      planKey: "PRO",
    });

    expect(result.ok).toBe(false);
    expect(result.error).toBe("BILLING_MANAGE_FORBIDDEN");
  });

  it("handles webhook idempotency", async () => {
    const { service } = createService();

    const first = await service.handleWebhook({ rawBody: "{}", signature: null });
    const second = await service.handleWebhook({ rawBody: "{}", signature: null });

    expect(first.ok).toBe(true);
    expect(second.ok).toBe(false);
    expect(second.error).toBe("WEBHOOK_ALREADY_PROCESSED");
  });

  it("detects feature limit exceeded", async () => {
    const repository = new FakeBillingRepository();
    repository.projectCount = 3;

    const featureLimitService = new FeatureLimitService(repository);
    const result = await featureLimitService.canCreateProject("org_1");

    expect(result.allowed).toBe(false);
    expect(result.reason).toBe("Project limit reached.");
  });
});
```

## Integration Test Database Prisma

Untuk repository integration test, gunakan database test terpisah. Pilihan yang disarankan:

- PostgreSQL test database: paling mirip production.
- SQLite test database: lebih sederhana, tetapi tidak selalu sama dengan PostgreSQL.

Untuk stack SaaS ini, gunakan PostgreSQL test database agar behavior index, relation, dan query lebih representatif.

Buat contoh env test:

```dotenv
# .env.test
DATABASE_URL_TEST="postgresql://postgres:postgres@localhost:5432/modern_saas_t3_next_test?schema=public"
AUTH_TOKEN_SECRET="test-secret-at-least-32-characters"
AUTH_TOKEN_EXPIRES_IN="7d"
BILLING_PROVIDER="mock"
```

Jangan pakai production database untuk test.

## Test Database Helper

Buat file `tests/helpers/test-db.ts`:

```ts
// tests/helpers/test-db.ts
import { PrismaClient } from "@prisma/client";

const databaseUrl = process.env.DATABASE_URL_TEST;

if (!databaseUrl) {
  throw new Error("DATABASE_URL_TEST is required for integration tests.");
}

export const testDb = new PrismaClient({
  datasources: {
    db: {
      url: databaseUrl,
    },
  },
});

export async function cleanupTestDb() {
  await testDb.billingWebhookEvent.deleteMany();
  await testDb.billingSubscription.deleteMany();
  await testDb.task.deleteMany();
  await testDb.project.deleteMany();
  await testDb.organizationMember.deleteMany();
  await testDb.organization.deleteMany();
  await testDb.user.deleteMany();
}

export async function disconnectTestDb() {
  await testDb.$disconnect();
}
```

Migration test database bisa dilakukan sebelum test integration:

```bash
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/modern_saas_t3_next_test?schema=public" npx prisma migrate deploy
```

Di Windows PowerShell:

```powershell
$env:DATABASE_URL="postgresql://postgres:postgres@localhost:5432/modern_saas_t3_next_test?schema=public"; npx prisma migrate deploy
```

Penjelasan:

- Prisma migrate membaca `DATABASE_URL`, jadi untuk test DB sementara set `DATABASE_URL` ke test database.
- `migrate deploy` menjalankan migration yang sudah ada.
- Jangan jalankan migration test ke production database.

## Repository Integration Test Projects

Buat file `tests/integration/repositories/project.repository.test.ts`:

```ts
// tests/integration/repositories/project.repository.test.ts
import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { cleanupTestDb, disconnectTestDb, testDb } from "@/../tests/helpers/test-db";

async function seedProjectData() {
  const user = await testDb.user.create({
    data: {
      email: "owner@example.com",
      passwordHash: "hashed-password",
      role: "MEMBER",
    },
  });

  const orgA = await testDb.organization.create({
    data: {
      name: "Org A",
      slug: "org-a",
      members: {
        create: {
          userId: user.id,
          role: "OWNER",
        },
      },
    },
  });

  const orgB = await testDb.organization.create({
    data: {
      name: "Org B",
      slug: "org-b",
    },
  });

  const projectA = await testDb.project.create({
    data: {
      organizationId: orgA.id,
      name: "Project A",
      slug: "project-a",
    },
  });

  const projectB = await testDb.project.create({
    data: {
      organizationId: orgB.id,
      name: "Project B",
      slug: "project-b",
    },
  });

  return { orgA, orgB, projectA, projectB, user };
}

describe("Project repository query rules", () => {
  beforeEach(async () => {
    await cleanupTestDb();
  });

  afterAll(async () => {
    await disconnectTestDb();
  });

  it("creates project", async () => {
    const { orgA } = await seedProjectData();

    const project = await testDb.project.create({
      data: {
        organizationId: orgA.id,
        name: "New Project",
        slug: "new-project",
      },
    });

    expect(project.organizationId).toBe(orgA.id);
  });

  it("lists project filtered by organizationId", async () => {
    const { orgA } = await seedProjectData();

    const projects = await testDb.project.findMany({
      where: {
        organizationId: orgA.id,
      },
    });

    expect(projects).toHaveLength(1);
    expect(projects[0].name).toBe("Project A");
  });

  it("does not return project from another organization", async () => {
    const { orgA, projectB } = await seedProjectData();

    const project = await testDb.project.findFirst({
      where: {
        id: projectB.id,
        organizationId: orgA.id,
      },
    });

    expect(project).toBeNull();
  });

  it("detail must match organizationId and projectId", async () => {
    const { orgA, projectA } = await seedProjectData();

    const project = await testDb.project.findFirst({
      where: {
        id: projectA.id,
        organizationId: orgA.id,
      },
    });

    expect(project?.id).toBe(projectA.id);
  });
});
```

## Repository Integration Test Tasks

Buat file `tests/integration/repositories/task.repository.test.ts`:

```ts
// tests/integration/repositories/task.repository.test.ts
import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { cleanupTestDb, disconnectTestDb, testDb } from "@/../tests/helpers/test-db";

async function seedTaskData() {
  const user = await testDb.user.create({
    data: {
      email: "owner@example.com",
      passwordHash: "hashed-password",
      role: "MEMBER",
    },
  });

  const orgA = await testDb.organization.create({ data: { name: "Org A", slug: "org-a" } });
  const orgB = await testDb.organization.create({ data: { name: "Org B", slug: "org-b" } });

  const projectA = await testDb.project.create({
    data: { organizationId: orgA.id, name: "Project A", slug: "project-a" },
  });

  const projectB = await testDb.project.create({
    data: { organizationId: orgB.id, name: "Project B", slug: "project-b" },
  });

  const taskA = await testDb.task.create({
    data: {
      organizationId: orgA.id,
      projectId: projectA.id,
      title: "Task A",
      status: "TODO",
      priority: "HIGH",
      assigneeId: user.id,
      reporterId: user.id,
    },
  });

  const taskB = await testDb.task.create({
    data: {
      organizationId: orgB.id,
      projectId: projectB.id,
      title: "Task B",
      status: "DONE",
      priority: "LOW",
      reporterId: user.id,
    },
  });

  return { orgA, orgB, projectA, projectB, taskA, taskB, user };
}

describe("Task repository query rules", () => {
  beforeEach(async () => {
    await cleanupTestDb();
  });

  afterAll(async () => {
    await disconnectTestDb();
  });

  it("creates task", async () => {
    const { orgA, projectA, user } = await seedTaskData();

    const task = await testDb.task.create({
      data: {
        organizationId: orgA.id,
        projectId: projectA.id,
        title: "New Task",
        reporterId: user.id,
      },
    });

    expect(task.organizationId).toBe(orgA.id);
    expect(task.projectId).toBe(projectA.id);
  });

  it("lists task filtered by organizationId and projectId", async () => {
    const { orgA, projectA } = await seedTaskData();

    const tasks = await testDb.task.findMany({
      where: {
        organizationId: orgA.id,
        projectId: projectA.id,
      },
    });

    expect(tasks).toHaveLength(1);
    expect(tasks[0].title).toBe("Task A");
  });

  it("does not return task from another project", async () => {
    const { orgA, projectA, taskB } = await seedTaskData();

    const task = await testDb.task.findFirst({
      where: {
        id: taskB.id,
        organizationId: orgA.id,
        projectId: projectA.id,
      },
    });

    expect(task).toBeNull();
  });

  it("detail must match organizationId + projectId + taskId", async () => {
    const { orgA, projectA, taskA } = await seedTaskData();

    const task = await testDb.task.findFirst({
      where: {
        id: taskA.id,
        organizationId: orgA.id,
        projectId: projectA.id,
      },
    });

    expect(task?.id).toBe(taskA.id);
  });

  it("filters by status", async () => {
    const { orgA, projectA } = await seedTaskData();

    const tasks = await testDb.task.findMany({
      where: { organizationId: orgA.id, projectId: projectA.id, status: "TODO" },
    });

    expect(tasks).toHaveLength(1);
  });

  it("filters by assignee", async () => {
    const { orgA, projectA, user } = await seedTaskData();

    const tasks = await testDb.task.findMany({
      where: { organizationId: orgA.id, projectId: projectA.id, assigneeId: user.id },
    });

    expect(tasks).toHaveLength(1);
  });
});
```

## tRPC Router Test

Buat file `tests/helpers/test-context.ts`:

```ts
// tests/helpers/test-context.ts
import type { TRPCContext } from "@/server/api/trpc";

export function createTestContext(params?: {
  user?: TRPCContext["user"];
}): TRPCContext {
  return {
    user: params?.user ?? null,
  };
}
```

Buat file `tests/integration/trpc/tasks.router.test.ts`:

```ts
// tests/integration/trpc/tasks.router.test.ts
import { describe, expect, it } from "vitest";
import { appRouter } from "@/server/api/root";
import { createTestContext } from "@/../tests/helpers/test-context";

describe("tasks router", () => {
  it("rejects protected procedure unauthorized", async () => {
    const caller = appRouter.createCaller(createTestContext());

    await expect(
      caller.tasks.list({
        organizationId: "org_1",
        projectId: "project_1",
        page: 1,
        pageSize: 20,
      }),
    ).rejects.toThrow();
  });

  it("accepts valid tasks.create input shape", async () => {
    const caller = appRouter.createCaller(
      createTestContext({
        user: {
          id: "user_1",
          email: "owner@example.com",
          name: "Owner",
          role: "MEMBER",
        },
      }),
    );

    await expect(
      caller.tasks.create({
        organizationId: "org_1",
        projectId: "project_1",
        title: "Prepare release",
        priority: "HIGH",
      }),
    ).rejects.toThrow();
  });

  it("returns Zod validation error for invalid input", async () => {
    const caller = appRouter.createCaller(
      createTestContext({
        user: {
          id: "user_1",
          email: "owner@example.com",
          name: "Owner",
          role: "MEMBER",
        },
      }),
    );

    await expect(
      caller.tasks.create({
        organizationId: "org_1",
        projectId: "project_1",
        title: "x",
        priority: "HIGH",
      }),
    ).rejects.toThrow();
  });
});
```

Catatan:

- `appRouter.createCaller(...)` mengetes procedure tanpa HTTP server.
- Test valid input bisa tetap reject jika database fixture belum dibuat. Pisahkan test shape/Zod dari test integration penuh.
- Untuk test sukses penuh, siapkan database fixture organization, membership, project, lalu panggil procedure.

## Testing Env Dan Secret

Aturan env test:

- Jangan pakai production database untuk test.
- Jangan pakai production billing provider untuk test.
- Gunakan `BILLING_PROVIDER="mock"`.
- Test secret boleh dummy asal memenuhi validasi panjang minimal.
- Jangan commit secret production.
- Pisahkan `.env.test` dari `.env.production`.

## Running Test

Jalankan semua test:

```bash
npm run test
```

Jalankan coverage:

```bash
npm run test:coverage
```

Jalankan typecheck:

```bash
npm run typecheck
```

Jalankan lint:

```bash
npm run lint
```

Expected output secara konsep:

```txt
Test Files  12 passed
Tests       48 passed
Typecheck   passed
Lint        passed
```

Jika test integration membutuhkan database, pastikan database test sudah running dan migration sudah dijalankan.

## Coverage Guideline

Target coverage realistis:

- Domain dan service: tinggi, karena business rule paling penting.
- Repository: integration test lebih penting daripada line coverage tinggi.
- Router: test flow penting, terutama protected procedure dan Zod validation.
- Jangan mengejar 100% jika tidak bernilai.
- Fokus ke business rule, tenant isolation, auth, billing webhook, dan status workflow.

Coverage bagus bukan jaminan aplikasi aman. Test yang tepat lebih penting daripada angka coverage yang tinggi.

## Testing Tenant Isolation

Test wajib untuk tenant isolation:

- user A tidak bisa lihat organization user B;
- user A tidak bisa lihat project organization B;
- user A tidak bisa lihat task project B;
- query project selalu filter `organizationId`;
- query task selalu filter `organizationId + projectId`;
- billing hanya untuk organization yang bisa diakses;
- assignee task harus member organization yang sama;
- member biasa tidak boleh manage member/billing.

Jika pernah menemukan bug tenant leakage, buat regression test permanen.

## Testing Billing Webhook

Webhook billing wajib dites karena provider bisa retry event.

Test yang disarankan:

- webhook valid membuat atau update subscription;
- duplicate event tidak double update;
- signature invalid ditolak;
- event tanpa `organizationId` ditolak;
- `planKey` invalid ditolak;
- mock provider dipakai untuk local test;
- Stripe test mode dipakai untuk integration manual.

Jangan memakai Stripe live mode untuk automated test lokal/CI.

## Production Readiness Checklist

Sebelum production, cek:

- env production valid;
- `DATABASE_URL` production aman;
- `AUTH_TOKEN_SECRET` kuat;
- billing secret tidak terekspos;
- CORS dikonfigurasi jika frontend external;
- rate limiting auth dan billing;
- logging tersedia;
- error monitoring tersedia;
- audit log untuk aksi penting;
- database backup aktif;
- migration strategy jelas;
- health check endpoint aktif;
- smoke test setelah deploy.

## Deployment Target

### Vercel

Vercel cocok untuk Next.js fullstack. App Router, route handler, dan serverless function berjalan natural di Vercel.

Pilih Vercel jika:

- aplikasi berbasis Next.js;
- ingin deploy cepat;
- database memakai external Postgres seperti Neon, Supabase, Railway, atau managed PostgreSQL lain.

### Railway / Fly.io / Render

Platform ini cocok jika ingin menjalankan app lebih seperti server/container. Pilih ini jika butuh long-running process, background worker sederhana, atau kontrol runtime lebih besar.

### Supabase / Neon / Railway Postgres

Gunakan provider database managed agar tidak mengurus backup, storage, dan maintenance sendiri dari awal.

### Docker Deployment

Docker cocok jika deploy ke VPS, Fly.io, Render, Kubernetes, atau environment internal. Docker memberi runtime konsisten, tetapi operasional lebih banyak daripada Vercel.

## Vercel Deployment

Vercel cocok untuk Next.js. Langkah utama:

1. Connect repository ke Vercel.
2. Set environment variables di Vercel dashboard.
3. Pastikan database external PostgreSQL tersedia.
4. Jalankan build.
5. Jalankan smoke test setelah deploy.

Build lokal sebelum deploy:

```bash
npm run build
```

Penjelasan:

- `npm run build` menjalankan production build Next.js.
- Build akan mendeteksi error TypeScript/Next.js yang tidak muncul di dev server.
- Jika Prisma Client belum generated, build bisa gagal.

Vercel setting umum:

```txt
Install Command: npm ci
Build Command: npm run build
Output: .next
```

Migration jangan asal otomatis di production. Untuk production, jalankan migration secara eksplisit dengan `prisma migrate deploy` di pipeline atau release step.

## Production Env Example

Buat file `.env.production.example`:

```dotenv
# .env.production.example
DATABASE_URL=""
NEXT_PUBLIC_APP_URL=""
AUTH_SECRET=""
AUTH_TOKEN_EXPIRES_IN="7d"
BILLING_PROVIDER="stripe"
STRIPE_SECRET_KEY=""
STRIPE_WEBHOOK_SECRET=""
```

File ini hanya template. Jangan isi secret asli di repository.

Catatan: jika codebase memakai `AUTH_TOKEN_SECRET` dari file `03-identity-auth.md`, gunakan nama yang konsisten. Jangan punya dua nama secret berbeda tanpa alasan.

## Migration Production

Local development memakai:

```bash
npx prisma migrate dev
```

Production memakai:

```bash
npx prisma migrate deploy
```

Penjelasan:

- `migrate dev` membuat migration baru dan cocok untuk lokal.
- `migrate deploy` menjalankan migration yang sudah ada dan cocok untuk production.
- Jangan pakai `prisma db push` untuk production.
- Backup database sebelum migration besar.
- Test migration di staging sebelum production.

## Dockerfile Optional

Buat file `Dockerfile`:

```dockerfile
# Dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npx prisma generate
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/prisma ./prisma
EXPOSE 3000
CMD ["npm", "run", "start"]
```

Penjelasan:

- `deps` install dependency bersih.
- `builder` generate Prisma Client dan build Next.js.
- `runner` menjalankan hasil build.
- Dockerfile ini opsional jika tidak deploy ke Vercel.

## Docker Compose Production-like Optional

Buat file `docker-compose.prod.yml`:

```yaml
# docker-compose.prod.yml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: production
      DATABASE_URL: postgresql://postgres:postgres@postgres:5432/modern_saas_t3_next?schema=public
      NEXT_PUBLIC_APP_URL: http://localhost:3000
      AUTH_TOKEN_SECRET: replace-this-with-a-long-random-secret
      AUTH_TOKEN_EXPIRES_IN: 7d
      BILLING_PROVIDER: mock
    depends_on:
      - postgres
    networks:
      - app_network

  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: modern_saas_t3_next
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app_network

volumes:
  postgres_data:

networks:
  app_network:
```

Penjelasan:

- File ini contoh production-like lokal, bukan final production security.
- Secret masih contoh dan harus diganti.
- Production nyata sebaiknya memakai managed database, secret manager, backup, dan TLS.

## CI Pipeline GitHub Actions

Buat file `.github/workflows/ci.yml`:

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
  push:
    branches:
      - main

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Generate Prisma Client
        run: npx prisma generate

      - name: Typecheck
        run: npm run typecheck

      - name: Lint
        run: npm run lint

      - name: Test
        run: npm run test
        env:
          AUTH_TOKEN_SECRET: test-secret-at-least-32-characters
          AUTH_TOKEN_EXPIRES_IN: 7d
          BILLING_PROVIDER: mock
          NEXT_PUBLIC_APP_URL: http://localhost:3000

      - name: Build
        run: npm run build
        env:
          AUTH_TOKEN_SECRET: test-secret-at-least-32-characters
          AUTH_TOKEN_EXPIRES_IN: 7d
          BILLING_PROVIDER: mock
          NEXT_PUBLIC_APP_URL: http://localhost:3000
```

CI penting karena setiap pull request menjalankan quality gate yang sama: install, Prisma generate, typecheck, lint, test, dan build.

Jika integration test butuh PostgreSQL, tambahkan service Postgres di workflow dan set `DATABASE_URL_TEST`.

## Smoke Test Setelah Deploy

Setelah deploy staging/production, lakukan smoke test:

- cek `/api/health`;
- login test user jika staging;
- create organization di staging;
- create task di staging;
- cek billing mock atau Stripe test mode;
- cek log error;
- cek webhook endpoint menerima event test;
- cek migration sudah diterapkan.

Smoke test harus cepat dan fokus memastikan aplikasi hidup.

## Observability Basic

Minimal production observability:

- structured logging untuk event penting;
- error monitoring seperti Sentry atau provider serupa;
- request id untuk melacak request;
- audit log untuk aksi sensitif seperti add member, change role, billing event;
- database slow query monitoring;
- billing webhook logging;
- alert untuk error rate tinggi.

Logging jangan berisi password, token, secret, atau full payment payload sensitif.

## Security Deployment Notes

Catatan security saat deploy:

- Jangan expose secret ke browser.
- Jangan log password atau token.
- Jangan return stack trace ke user.
- HTTPS wajib di production.
- Gunakan secure cookie jika auth memakai cookie.
- Rate limit login, register, dan webhook.
- Validasi webhook signature.
- Gunakan principle of least privilege untuk database user.
- Pisahkan staging dan production environment.
- Rotasi secret jika pernah bocor.

## Design Pattern Yang Relevan

Bagian ini memakai konsep umum design pattern yang juga dikenal dari referensi seperti Refactoring Guru, tetapi contoh dan penjelasan disesuaikan untuk stack ini.

### Test Double / Fake

Fake dipakai untuk unit test service tanpa database/provider asli. Contoh: `FakeUserRepository`, `FakeBillingProviderFactory`, dan `FakePasswordHasher`.

Masalah yang diselesaikan: test cepat dan deterministic.

### Repository Pattern

Repository memudahkan mocking karena service bergantung pada interface, bukan Prisma Client langsung.

Masalah yang diselesaikan: service test tidak perlu database.

### Factory Pattern Untuk Test Data

Factory test data membuat fixture konsisten. Contoh: `createUserFixture`, `createOrganizationFixture`, `createTaskFixture`.

Masalah yang diselesaikan: setup test tidak duplikatif.

### Abstract Factory Dari Billing

Billing provider dibuat lewat factory sehingga unit test bisa memakai mock provider tanpa Stripe.

Masalah yang diselesaikan: application service tidak hardcode provider production.

### Facade Melalui appRouter

`appRouter` menjadi facade untuk integration test tRPC. Test bisa membuat caller dari satu root router.

Masalah yang diselesaikan: contract API bisa dites dari pintu masuk yang sama dengan aplikasi.

### Adapter Pattern Pada Repository / Provider

Prisma repository dan billing provider client adalah adapter antara application layer dan sistem eksternal.

Masalah yang diselesaikan: detail Prisma/Stripe tidak bocor ke service.

### Strategy Pattern Pada Task Status Workflow

Status workflow task memakai strategy agar rule transition bisa dites dan diganti.

Masalah yang diselesaikan: business rule status tidak menumpuk di router.

## Troubleshooting

### Test Gagal Karena Env Belum Load

Pastikan env test tersedia. Jika perlu, load `.env.test` di setup test atau export env sebelum menjalankan test.

### Test Pakai Database Production

Cek `DATABASE_URL_TEST`. Jangan fallback ke `DATABASE_URL` production untuk integration test.

### Prisma Client Belum Generate

Jalankan:

```bash
npx prisma generate
```

### Migration Test Gagal

Cek database test running, `DATABASE_URL_TEST` benar, dan migration belum rusak.

### Port Database Dipakai

Jika Postgres lokal memakai port 5432, gunakan port lain untuk database test, misalnya 5433.

### CI Gagal Karena Env Missing

Tambahkan env dummy untuk test/build di GitHub Actions. Jangan tambahkan secret production ke pull request dari fork.

### Build Gagal Di Vercel Karena Prisma

Pastikan `prisma generate` berjalan. Beberapa project menambahkan `postinstall`:

```json
// package.json
{
  "scripts": {
    "postinstall": "prisma generate"
  }
}
```

### `prisma migrate dev` Dipakai Di Production

Ganti dengan:

```bash
npx prisma migrate deploy
```

### Stripe Webhook Beda Secret

Pastikan `STRIPE_WEBHOOK_SECRET` berasal dari endpoint webhook yang sama. Secret CLI Stripe dan dashboard endpoint bisa berbeda.

### Docker Image Terlalu Besar

Gunakan multi-stage build, `.dockerignore`, dan hindari copy file yang tidak perlu.

### Path Alias Error Di Vitest

Pastikan `vitest.config.ts` punya alias:

```ts
// vitest.config.ts
resolve: {
  alias: {
    "@": path.resolve(__dirname, "src"),
  },
}
```

## Checklist Berhasil

- [ ] Vitest terpasang.
- [ ] Unit test domain berjalan.
- [ ] Unit test service berjalan.
- [ ] Repository integration test berjalan.
- [ ] tRPC router test berjalan.
- [ ] Tenant isolation punya test.
- [ ] Billing webhook idempotency punya test.
- [ ] Coverage report bisa dibuat.
- [ ] Typecheck berhasil.
- [ ] Lint berhasil.
- [ ] Build berhasil.
- [ ] Production env example tersedia.
- [ ] Migration production memakai `prisma migrate deploy`.
- [ ] CI pipeline tersedia.
- [ ] Health check siap.
- [ ] Deployment target dipahami.
- [ ] Siap lanjut ke `08-code-blueprint-response-error.md`.
