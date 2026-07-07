# Backend 06 - Billing & Abstract Factory

File ini menjelaskan cara membuat Billing Module untuk modern SaaS task workspace di stack `modern-saas-t3-next` menggunakan TypeScript, tRPC, Prisma, PostgreSQL, Zod, dan modular layered architecture.

SaaS app butuh billing module karena produk biasanya punya paket harga, subscription, limit fitur, invoice, trial, dan customer portal. Tanpa module billing yang jelas, logic seperti "organization ini boleh membuat berapa project/task/member" akan tersebar di banyak file.

Billing berhubungan langsung dengan Organization/Tenant dari file `04-organization-tenancy.md`. Di SaaS B2B atau workspace-based SaaS, subscription biasanya melekat ke organization, bukan user pribadi. Satu user bisa berada di beberapa organization dengan subscription berbeda. Karena itu semua data billing di file ini memakai `organizationId` sebagai tenant boundary.

Billing provider sebaiknya dibuat abstraction karena provider bisa berubah. Local development butuh mock provider, production bisa memakai Stripe, dan beberapa produk mungkin memilih Lemon Squeezy atau Paddle. Application service tidak seharusnya hardcode Stripe di semua use case.

## Konsep Dasar Billing SaaS

### Plan

Plan adalah paket produk yang bisa dipilih customer. Contoh:

- `FREE`
- `PRO`
- `BUSINESS`

Plan menentukan harga, limit fitur, limit seat, dan akses capability tertentu.

### Subscription

Subscription adalah status langganan organization terhadap plan tertentu. Subscription menyimpan plan aktif, status, periode aktif, provider id, dan kapan subscription berakhir.

### Billing Customer

Billing customer adalah representasi customer di payment provider. Di Stripe namanya customer. Di provider lain namanya bisa berbeda. Dalam aplikasi kita, billing customer terikat ke `organizationId`.

### Checkout Session

Checkout session adalah URL atau session dari provider untuk memulai pembayaran atau upgrade plan. Frontend biasanya redirect user ke URL checkout yang dibuat backend.

### Customer Portal

Customer portal adalah URL dari provider untuk customer mengelola subscription, invoice, payment method, atau cancel subscription.

### Payment Provider

Payment provider adalah layanan pembayaran seperti Stripe, Lemon Squeezy, atau Paddle. Provider punya API, webhook format, event type, dan customer model yang berbeda.

### Webhook

Webhook adalah request dari payment provider ke backend kita saat terjadi event billing. Contoh event:

- checkout selesai;
- subscription aktif;
- invoice dibayar;
- subscription canceled;
- payment gagal.

Webhook harus diverifikasi. Jangan percaya request webhook tanpa signature verification.

### Invoice

Invoice adalah tagihan untuk subscription. Dalam module awal ini invoice tidak dibuat detail, tetapi status subscription bisa berubah karena event invoice.

### Trial

Trial adalah masa percobaan sebelum customer mulai membayar. Trial biasanya punya tanggal selesai dan status khusus seperti `TRIALING`.

### Subscription Status

Status subscription menjelaskan keadaan langganan. Status awal yang dipakai di file ini:

- `NONE`
- `TRIALING`
- `ACTIVE`
- `PAST_DUE`
- `CANCELED`

### Feature Limit

Feature limit adalah batas penggunaan fitur berdasarkan plan. Contoh:

- Free: maksimal 3 project;
- Pro: maksimal 50 project;
- Business: unlimited project.

### Seat / User Limit

Seat limit adalah batas jumlah member dalam organization. Contoh Free hanya 3 member, Pro 10 member, Business 100 member.

### Tenant Billing

Tenant billing berarti billing dihitung per organization. User yang sama bisa memakai Free plan di organization A dan Business plan di organization B.

### Idempotency

Idempotency berarti event yang sama bisa diproses lebih dari sekali tanpa membuat data rusak atau duplikat. Webhook provider bisa dikirim ulang, jadi handler harus menyimpan event id dan mengabaikan event yang sudah diproses.

## Kenapa Abstract Factory Pattern

Abstract Factory Pattern menyelesaikan masalah pembuatan keluarga object yang saling terkait tanpa application layer tahu class konkret yang dipakai.

Dalam billing, provider bisa berbeda-beda:

- MockBilling untuk local development;
- Stripe untuk production;
- Lemon Squeezy atau Paddle sebagai alternatif;
- provider lokal untuk negara tertentu.

Masalah jika hardcode Stripe di seluruh service:

- use case checkout import Stripe SDK langsung;
- webhook handler tahu detail Stripe;
- test lokal harus mock banyak bagian Stripe;
- pindah provider menyentuh banyak file;
- application layer tergantung detail infrastructure.

Local development butuh `MockBillingProvider` agar developer bisa membuat checkout dan webhook tanpa akun Stripe atau koneksi internet. Production bisa memakai `StripeBillingProvider` dengan signature verification dan API provider asli.

Abstract Factory cocok karena billing provider bukan hanya satu object. Satu provider biasanya punya keluarga object terkait:

- customer service;
- checkout service;
- subscription service;
- portal service;
- webhook verifier.

Dengan factory, application layer cukup meminta `BillingProviderClient` dari `BillingProviderFactory`. Factory konkret menentukan apakah client yang dibuat adalah mock, Stripe, Lemon Squeezy, atau Paddle.

Konsep ini sejalan dengan referensi umum seperti Refactoring Guru: fokusnya membuat keluarga object terkait melalui interface, bukan mengikat code ke class konkret. Di file ini kita memakai konsep tersebut tanpa menyalin kode dari referensi.

## Scope Fitur

Fitur yang dibahas:

- get available plans;
- get current organization subscription;
- create checkout session;
- create customer portal session;
- handle billing webhook;
- sync subscription status;
- check feature limit sederhana;
- support Mock provider dan Stripe provider sebagai contoh;
- protected tRPC procedures untuk billing query/action;
- route handler untuk webhook;
- Zod validation;
- Prisma repository;
- result pattern;
- error handling.

Yang tidak dibahas terlalu dalam:

- UI pricing page;
- pajak/VAT;
- coupon/promotion code;
- proration kompleks;
- metered billing;
- payment dispute;
- implementasi production Stripe penuh.

## Struktur Folder Billing

Gunakan struktur:

```txt
src/server/modules/billing/
├── domain/
│   ├── billing-plan.entity.ts
│   ├── subscription.entity.ts
│   ├── billing-provider.ts
│   └── subscription-status.ts
│
├── application/
│   ├── billing.service.ts
│   ├── billing.repository.ts
│   ├── billing-provider.factory.ts
│   ├── billing-provider-client.ts
│   ├── feature-limit.service.ts
│   └── organization-billing-access-checker.ts
│
├── infrastructure/
│   ├── prisma-billing.repository.ts
│   ├── mock/
│   │   ├── mock-billing-provider.factory.ts
│   │   └── mock-billing-provider-client.ts
│   └── stripe/
│       ├── stripe-billing-provider.factory.ts
│       ├── stripe-billing-provider-client.ts
│       └── stripe-webhook-verifier.ts
│
└── presentation/
    ├── billing.input.ts
    ├── billing.router.ts
    └── billing-webhook.route.ts
```

Penjelasan:

- `domain`: plan, subscription, provider enum, status.
- `application`: use case billing dan interface provider.
- `infrastructure`: implementasi Prisma, Mock provider, dan Stripe provider.
- `presentation`: Zod input, tRPC router, dan route handler webhook.

## Prisma Schema

Billing harus terikat ke organization. Tambahkan model berikut ke `prisma/schema.prisma`.

```prisma
// prisma/schema.prisma
enum BillingProvider {
  MOCK
  STRIPE
  LEMON_SQUEEZY
  PADDLE
}

enum SubscriptionStatus {
  NONE
  TRIALING
  ACTIVE
  PAST_DUE
  CANCELED
}

model BillingSubscription {
  id                     String             @id @default(cuid())
  organizationId         String             @unique
  provider               BillingProvider
  providerCustomerId     String?
  providerSubscriptionId String?
  planKey                String
  status                 SubscriptionStatus @default(NONE)
  currentPeriodStart     DateTime?
  currentPeriodEnd       DateTime?
  trialEndsAt            DateTime?
  cancelAtPeriodEnd      Boolean            @default(false)
  createdAt              DateTime           @default(now())
  updatedAt              DateTime           @updatedAt

  organization Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)

  @@index([provider])
  @@index([providerCustomerId])
  @@index([providerSubscriptionId])
  @@index([status])
}

model BillingWebhookEvent {
  id          String          @id @default(cuid())
  provider    BillingProvider
  eventId     String
  eventType   String
  processedAt DateTime        @default(now())
  payload     Json

  @@unique([provider, eventId])
  @@index([provider])
  @@index([eventType])
}
```

Tambahkan relation di model `Organization`:

```prisma
// prisma/schema.prisma
model Organization {
  id        String   @id @default(cuid())
  name      String
  slug      String   @unique
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  billingSubscription BillingSubscription?

  members   OrganizationMember[]
  projects  Project[]
  tasks     Task[]
  auditLogs AuditLog[]
}
```

Jalankan migration:

```bash
npx prisma migrate dev --name add_billing_module
```

Penjelasan:

- `BillingSubscription.organizationId` unik karena satu organization punya satu subscription aktif utama.
- `BillingWebhookEvent` menyimpan event id untuk idempotency.
- `providerCustomerId` dan `providerSubscriptionId` menyimpan id dari payment provider.
- `payload` menyimpan event mentah untuk debugging dan audit ringan.

## Environment Variable Billing

Tambahkan env berikut:

```dotenv
# .env
BILLING_PROVIDER="mock"
APP_BILLING_SUCCESS_URL="http://localhost:3000/billing/success"
APP_BILLING_CANCEL_URL="http://localhost:3000/billing/cancel"
STRIPE_SECRET_KEY=""
STRIPE_WEBHOOK_SECRET=""
```

Update env validation:

```ts
// src/env.ts
import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  NEXT_PUBLIC_APP_URL: z.string().url(),
  AUTH_TOKEN_SECRET: z.string().min(32),
  AUTH_TOKEN_EXPIRES_IN: z.string().default("7d"),
  BILLING_PROVIDER: z.enum(["mock", "stripe"]).default("mock"),
  APP_BILLING_SUCCESS_URL: z.string().url(),
  APP_BILLING_CANCEL_URL: z.string().url(),
  STRIPE_SECRET_KEY: z.string().optional(),
  STRIPE_WEBHOOK_SECRET: z.string().optional(),
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
});

export const env = envSchema.parse({
  DATABASE_URL: process.env.DATABASE_URL,
  NEXT_PUBLIC_APP_URL: process.env.NEXT_PUBLIC_APP_URL,
  AUTH_TOKEN_SECRET: process.env.AUTH_TOKEN_SECRET,
  AUTH_TOKEN_EXPIRES_IN: process.env.AUTH_TOKEN_EXPIRES_IN,
  BILLING_PROVIDER: process.env.BILLING_PROVIDER,
  APP_BILLING_SUCCESS_URL: process.env.APP_BILLING_SUCCESS_URL,
  APP_BILLING_CANCEL_URL: process.env.APP_BILLING_CANCEL_URL,
  STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY,
  STRIPE_WEBHOOK_SECRET: process.env.STRIPE_WEBHOOK_SECRET,
  NODE_ENV: process.env.NODE_ENV,
});
```

Penjelasan:

- `BILLING_PROVIDER="mock"` dipakai untuk local development.
- `STRIPE_SECRET_KEY` dan `STRIPE_WEBHOOK_SECRET` boleh kosong saat provider mock.
- Production dengan Stripe wajib mengisi secret lewat Vercel environment variable.

## Domain Layer

### Billing Provider

Buat file `src/server/modules/billing/domain/billing-provider.ts`:

```ts
// src/server/modules/billing/domain/billing-provider.ts
export const billingProviders = [
  "MOCK",
  "STRIPE",
  "LEMON_SQUEEZY",
  "PADDLE",
] as const;

export type BillingProvider = (typeof billingProviders)[number];

export function isBillingProvider(value: string): value is BillingProvider {
  return billingProviders.includes(value as BillingProvider);
}
```

### Subscription Status

Buat file `src/server/modules/billing/domain/subscription-status.ts`:

```ts
// src/server/modules/billing/domain/subscription-status.ts
export const subscriptionStatuses = [
  "NONE",
  "TRIALING",
  "ACTIVE",
  "PAST_DUE",
  "CANCELED",
] as const;

export type SubscriptionStatus = (typeof subscriptionStatuses)[number];

export function isSubscriptionStatus(value: string): value is SubscriptionStatus {
  return subscriptionStatuses.includes(value as SubscriptionStatus);
}

export function hasActiveAccess(status: SubscriptionStatus) {
  return status === "TRIALING" || status === "ACTIVE";
}
```

### Billing Plan Entity

Buat file `src/server/modules/billing/domain/billing-plan.entity.ts`:

```ts
// src/server/modules/billing/domain/billing-plan.entity.ts
export type BillingPlanKey = "FREE" | "PRO" | "BUSINESS";

export type BillingPlan = {
  key: BillingPlanKey;
  name: string;
  monthlyPriceCents: number;
  maxMembers: number;
  maxProjects: number;
  maxTasks: number;
  providerPriceId?: string;
};

export const billingPlans: BillingPlan[] = [
  {
    key: "FREE",
    name: "Free",
    monthlyPriceCents: 0,
    maxMembers: 3,
    maxProjects: 3,
    maxTasks: 100,
  },
  {
    key: "PRO",
    name: "Pro",
    monthlyPriceCents: 1900,
    maxMembers: 10,
    maxProjects: 50,
    maxTasks: 5000,
    providerPriceId: "price_pro_monthly",
  },
  {
    key: "BUSINESS",
    name: "Business",
    monthlyPriceCents: 4900,
    maxMembers: 100,
    maxProjects: 500,
    maxTasks: 50000,
    providerPriceId: "price_business_monthly",
  },
];

export function findBillingPlan(planKey: string) {
  return billingPlans.find((plan) => plan.key === planKey) ?? null;
}
```

Catatan penting: jangan percaya plan atau price dari frontend. Frontend cukup mengirim `planKey`, lalu backend mengambil harga/provider price id dari daftar plan yang dipercaya.

### Subscription Entity

Buat file `src/server/modules/billing/domain/subscription.entity.ts`:

```ts
// src/server/modules/billing/domain/subscription.entity.ts
import type { BillingProvider } from "./billing-provider";
import type { BillingPlanKey } from "./billing-plan.entity";
import type { SubscriptionStatus } from "./subscription-status";

export type BillingSubscriptionEntity = {
  id: string;
  organizationId: string;
  provider: BillingProvider;
  providerCustomerId: string | null;
  providerSubscriptionId: string | null;
  planKey: BillingPlanKey;
  status: SubscriptionStatus;
  currentPeriodStart: Date | null;
  currentPeriodEnd: Date | null;
  trialEndsAt: Date | null;
  cancelAtPeriodEnd: boolean;
  createdAt: Date;
  updatedAt: Date;
};
```

## Application Interfaces

### Billing Repository

Buat file `src/server/modules/billing/application/billing.repository.ts`:

```ts
// src/server/modules/billing/application/billing.repository.ts
import type { BillingProvider } from "../domain/billing-provider";
import type { BillingPlanKey } from "../domain/billing-plan.entity";
import type { BillingSubscriptionEntity } from "../domain/subscription.entity";
import type { SubscriptionStatus } from "../domain/subscription-status";

export type UpsertSubscriptionData = {
  organizationId: string;
  provider: BillingProvider;
  providerCustomerId?: string | null;
  providerSubscriptionId?: string | null;
  planKey: BillingPlanKey;
  status: SubscriptionStatus;
  currentPeriodStart?: Date | null;
  currentPeriodEnd?: Date | null;
  trialEndsAt?: Date | null;
  cancelAtPeriodEnd?: boolean;
};

export interface BillingRepository {
  findSubscriptionByOrganizationId(
    organizationId: string,
  ): Promise<BillingSubscriptionEntity | null>;
  upsertSubscription(
    data: UpsertSubscriptionData,
  ): Promise<BillingSubscriptionEntity>;
  hasProcessedWebhookEvent(params: {
    provider: BillingProvider;
    eventId: string;
  }): Promise<boolean>;
  markWebhookEventProcessed(params: {
    provider: BillingProvider;
    eventId: string;
    eventType: string;
    payload: unknown;
  }): Promise<void>;
  countOrganizationMembers(organizationId: string): Promise<number>;
  countOrganizationProjects(organizationId: string): Promise<number>;
  countOrganizationTasks(organizationId: string): Promise<number>;
}
```

### Billing Provider Client

Buat file `src/server/modules/billing/application/billing-provider-client.ts`:

```ts
// src/server/modules/billing/application/billing-provider-client.ts
import type { BillingProvider } from "../domain/billing-provider";
import type { BillingPlan } from "../domain/billing-plan.entity";
import type { SubscriptionStatus } from "../domain/subscription-status";

export type BillingCheckoutSession = {
  url: string;
  providerSessionId: string;
};

export type BillingPortalSession = {
  url: string;
};

export type BillingWebhookEvent = {
  provider: BillingProvider;
  eventId: string;
  eventType: string;
  organizationId: string;
  providerCustomerId?: string | null;
  providerSubscriptionId?: string | null;
  planKey: string;
  status: SubscriptionStatus;
  currentPeriodStart?: Date | null;
  currentPeriodEnd?: Date | null;
  trialEndsAt?: Date | null;
  cancelAtPeriodEnd?: boolean;
  rawPayload: unknown;
};

export interface BillingProviderClient {
  createCheckoutSession(params: {
    organizationId: string;
    organizationName: string;
    plan: BillingPlan;
    successUrl: string;
    cancelUrl: string;
  }): Promise<BillingCheckoutSession>;

  createCustomerPortalSession(params: {
    organizationId: string;
    providerCustomerId: string;
    returnUrl: string;
  }): Promise<BillingPortalSession>;

  verifyWebhook(params: {
    rawBody: string;
    signature: string | null;
  }): Promise<BillingWebhookEvent>;
}
```

Interface ini menjadi keluarga operasi provider billing. Mock dan Stripe akan mengimplementasikan interface yang sama.

### Billing Provider Factory

Buat file `src/server/modules/billing/application/billing-provider.factory.ts`:

```ts
// src/server/modules/billing/application/billing-provider.factory.ts
import type { BillingProvider } from "../domain/billing-provider";
import type { BillingProviderClient } from "./billing-provider-client";

export interface BillingProviderFactory {
  provider: BillingProvider;
  createClient(): BillingProviderClient;
}
```

Inilah titik Abstract Factory. Application service tidak perlu tahu apakah client dibuat oleh Mock factory atau Stripe factory.

### Organization Billing Access Checker

Buat file `src/server/modules/billing/application/organization-billing-access-checker.ts`:

```ts
// src/server/modules/billing/application/organization-billing-access-checker.ts
export type OrganizationBillingAccess = {
  organizationId: string;
  organizationName: string;
  actorRole: "OWNER" | "ADMIN" | "MEMBER";
};

export interface OrganizationBillingAccessChecker {
  getAccess(params: {
    organizationId: string;
    actorUserId: string;
  }): Promise<OrganizationBillingAccess | null>;
}

export function canManageBilling(role: OrganizationBillingAccess["actorRole"]) {
  return role === "OWNER" || role === "ADMIN";
}
```

Billing action seperti checkout dan portal hanya boleh untuk owner/admin organization.

### Feature Limit Service

Buat file `src/server/modules/billing/application/feature-limit.service.ts`:

```ts
// src/server/modules/billing/application/feature-limit.service.ts
import { findBillingPlan } from "../domain/billing-plan.entity";
import { hasActiveAccess } from "../domain/subscription-status";
import type { BillingRepository } from "./billing.repository";

export type FeatureLimitResult = {
  allowed: boolean;
  reason?: string;
  current: number;
  limit: number;
};

export class FeatureLimitService {
  constructor(private readonly billingRepository: BillingRepository) {}

  async canCreateProject(organizationId: string): Promise<FeatureLimitResult> {
    const subscription =
      await this.billingRepository.findSubscriptionByOrganizationId(
        organizationId,
      );

    const plan = findBillingPlan(subscription?.planKey ?? "FREE");
    const current = await this.billingRepository.countOrganizationProjects(
      organizationId,
    );

    if (!plan) {
      return {
        allowed: false,
        reason: "Plan was not found.",
        current,
        limit: 0,
      };
    }

    if (subscription && !hasActiveAccess(subscription.status)) {
      return {
        allowed: false,
        reason: "Subscription is not active.",
        current,
        limit: plan.maxProjects,
      };
    }

    return {
      allowed: current < plan.maxProjects,
      reason: current < plan.maxProjects ? undefined : "Project limit reached.",
      current,
      limit: plan.maxProjects,
    };
  }

  async canInviteMember(organizationId: string): Promise<FeatureLimitResult> {
    const subscription =
      await this.billingRepository.findSubscriptionByOrganizationId(
        organizationId,
      );

    const plan = findBillingPlan(subscription?.planKey ?? "FREE");
    const current = await this.billingRepository.countOrganizationMembers(
      organizationId,
    );

    if (!plan) {
      return {
        allowed: false,
        reason: "Plan was not found.",
        current,
        limit: 0,
      };
    }

    return {
      allowed: current < plan.maxMembers,
      reason: current < plan.maxMembers ? undefined : "Seat limit reached.",
      current,
      limit: plan.maxMembers,
    };
  }
}
```

Feature limit service bisa dipakai module Organization dan Project sebelum membuat member/project baru. Ini menjaga billing rule tidak tersebar di router lain.

## Infrastructure Repository

Buat file `src/server/modules/billing/infrastructure/prisma-billing.repository.ts`:

```ts
// src/server/modules/billing/infrastructure/prisma-billing.repository.ts
import type { PrismaClient } from "@prisma/client";
import type {
  BillingRepository,
  UpsertSubscriptionData,
} from "../application/billing.repository";
import { isBillingProvider } from "../domain/billing-provider";
import { isSubscriptionStatus } from "../domain/subscription-status";
import type { BillingSubscriptionEntity } from "../domain/subscription.entity";

function mapSubscription(subscription: {
  id: string;
  organizationId: string;
  provider: string;
  providerCustomerId: string | null;
  providerSubscriptionId: string | null;
  planKey: string;
  status: string;
  currentPeriodStart: Date | null;
  currentPeriodEnd: Date | null;
  trialEndsAt: Date | null;
  cancelAtPeriodEnd: boolean;
  createdAt: Date;
  updatedAt: Date;
}): BillingSubscriptionEntity {
  if (!isBillingProvider(subscription.provider)) {
    throw new Error(`Invalid billing provider: ${subscription.provider}`);
  }

  if (!isSubscriptionStatus(subscription.status)) {
    throw new Error(`Invalid subscription status: ${subscription.status}`);
  }

  return {
    id: subscription.id,
    organizationId: subscription.organizationId,
    provider: subscription.provider,
    providerCustomerId: subscription.providerCustomerId,
    providerSubscriptionId: subscription.providerSubscriptionId,
    planKey: subscription.planKey as BillingSubscriptionEntity["planKey"],
    status: subscription.status,
    currentPeriodStart: subscription.currentPeriodStart,
    currentPeriodEnd: subscription.currentPeriodEnd,
    trialEndsAt: subscription.trialEndsAt,
    cancelAtPeriodEnd: subscription.cancelAtPeriodEnd,
    createdAt: subscription.createdAt,
    updatedAt: subscription.updatedAt,
  };
}

export class PrismaBillingRepository implements BillingRepository {
  constructor(private readonly db: PrismaClient) {}

  async findSubscriptionByOrganizationId(
    organizationId: string,
  ): Promise<BillingSubscriptionEntity | null> {
    const subscription = await this.db.billingSubscription.findUnique({
      where: {
        organizationId,
      },
    });

    return subscription ? mapSubscription(subscription) : null;
  }

  async upsertSubscription(
    data: UpsertSubscriptionData,
  ): Promise<BillingSubscriptionEntity> {
    const subscription = await this.db.billingSubscription.upsert({
      where: {
        organizationId: data.organizationId,
      },
      update: {
        provider: data.provider,
        providerCustomerId: data.providerCustomerId,
        providerSubscriptionId: data.providerSubscriptionId,
        planKey: data.planKey,
        status: data.status,
        currentPeriodStart: data.currentPeriodStart,
        currentPeriodEnd: data.currentPeriodEnd,
        trialEndsAt: data.trialEndsAt,
        cancelAtPeriodEnd: data.cancelAtPeriodEnd,
      },
      create: {
        organizationId: data.organizationId,
        provider: data.provider,
        providerCustomerId: data.providerCustomerId,
        providerSubscriptionId: data.providerSubscriptionId,
        planKey: data.planKey,
        status: data.status,
        currentPeriodStart: data.currentPeriodStart,
        currentPeriodEnd: data.currentPeriodEnd,
        trialEndsAt: data.trialEndsAt,
        cancelAtPeriodEnd: data.cancelAtPeriodEnd ?? false,
      },
    });

    return mapSubscription(subscription);
  }

  async hasProcessedWebhookEvent(params: {
    provider: BillingSubscriptionEntity["provider"];
    eventId: string;
  }): Promise<boolean> {
    const count = await this.db.billingWebhookEvent.count({
      where: {
        provider: params.provider,
        eventId: params.eventId,
      },
    });

    return count > 0;
  }

  async markWebhookEventProcessed(params: {
    provider: BillingSubscriptionEntity["provider"];
    eventId: string;
    eventType: string;
    payload: unknown;
  }): Promise<void> {
    await this.db.billingWebhookEvent.create({
      data: {
        provider: params.provider,
        eventId: params.eventId,
        eventType: params.eventType,
        payload: params.payload,
      },
    });
  }

  async countOrganizationMembers(organizationId: string): Promise<number> {
    return this.db.organizationMember.count({ where: { organizationId } });
  }

  async countOrganizationProjects(organizationId: string): Promise<number> {
    return this.db.project.count({ where: { organizationId } });
  }

  async countOrganizationTasks(organizationId: string): Promise<number> {
    return this.db.task.count({ where: { organizationId } });
  }
}
```

## Mock Billing Provider

Mock provider dipakai local development. Ia tidak memanggil API eksternal.

Buat file `src/server/modules/billing/infrastructure/mock/mock-billing-provider-client.ts`:

```ts
// src/server/modules/billing/infrastructure/mock/mock-billing-provider-client.ts
import type {
  BillingProviderClient,
  BillingWebhookEvent,
} from "../../application/billing-provider-client";

export class MockBillingProviderClient implements BillingProviderClient {
  async createCheckoutSession(params: Parameters<BillingProviderClient["createCheckoutSession"]>[0]) {
    return {
      url: `http://localhost:3000/mock-billing/checkout?organizationId=${params.organizationId}&plan=${params.plan.key}`,
      providerSessionId: `mock_checkout_${Date.now()}`,
    };
  }

  async createCustomerPortalSession(params: Parameters<BillingProviderClient["createCustomerPortalSession"]>[0]) {
    return {
      url: `http://localhost:3000/mock-billing/portal?organizationId=${params.organizationId}`,
    };
  }

  async verifyWebhook(params: Parameters<BillingProviderClient["verifyWebhook"]>[0]): Promise<BillingWebhookEvent> {
    const payload = JSON.parse(params.rawBody) as BillingWebhookEvent;

    return {
      ...payload,
      provider: "MOCK",
      rawPayload: payload,
    };
  }
}
```

Buat file `src/server/modules/billing/infrastructure/mock/mock-billing-provider.factory.ts`:

```ts
// src/server/modules/billing/infrastructure/mock/mock-billing-provider.factory.ts
import type { BillingProviderFactory } from "../../application/billing-provider.factory";
import { MockBillingProviderClient } from "./mock-billing-provider-client";

export class MockBillingProviderFactory implements BillingProviderFactory {
  provider = "MOCK" as const;

  createClient() {
    return new MockBillingProviderClient();
  }
}
```

## Stripe Billing Provider Concept

Install Stripe SDK jika ingin mencoba provider Stripe:

```bash
npm install stripe
```

Penjelasan:

- `stripe` adalah SDK resmi Stripe untuk Node.js.
- Local development tetap bisa memakai mock provider tanpa package ini jika belum butuh Stripe.

Buat file `src/server/modules/billing/infrastructure/stripe/stripe-billing-provider-client.ts`:

```ts
// src/server/modules/billing/infrastructure/stripe/stripe-billing-provider-client.ts
import Stripe from "stripe";
import { env } from "@/env";
import type {
  BillingProviderClient,
  BillingWebhookEvent,
} from "../../application/billing-provider-client";

export class StripeBillingProviderClient implements BillingProviderClient {
  private readonly stripe = new Stripe(env.STRIPE_SECRET_KEY ?? "", {
    apiVersion: "2024-06-20",
  });

  async createCheckoutSession(params: Parameters<BillingProviderClient["createCheckoutSession"]>[0]) {
    if (!params.plan.providerPriceId) {
      throw new Error("PLAN_HAS_NO_PROVIDER_PRICE_ID");
    }

    const session = await this.stripe.checkout.sessions.create({
      mode: "subscription",
      line_items: [
        {
          price: params.plan.providerPriceId,
          quantity: 1,
        },
      ],
      success_url: params.successUrl,
      cancel_url: params.cancelUrl,
      client_reference_id: params.organizationId,
      metadata: {
        organizationId: params.organizationId,
        planKey: params.plan.key,
      },
    });

    if (!session.url) {
      throw new Error("STRIPE_CHECKOUT_SESSION_URL_MISSING");
    }

    return {
      url: session.url,
      providerSessionId: session.id,
    };
  }

  async createCustomerPortalSession(params: Parameters<BillingProviderClient["createCustomerPortalSession"]>[0]) {
    const session = await this.stripe.billingPortal.sessions.create({
      customer: params.providerCustomerId,
      return_url: params.returnUrl,
    });

    return {
      url: session.url,
    };
  }

  async verifyWebhook(params: Parameters<BillingProviderClient["verifyWebhook"]>[0]): Promise<BillingWebhookEvent> {
    if (!params.signature || !env.STRIPE_WEBHOOK_SECRET) {
      throw new Error("STRIPE_WEBHOOK_SIGNATURE_MISSING");
    }

    const event = this.stripe.webhooks.constructEvent(
      params.rawBody,
      params.signature,
      env.STRIPE_WEBHOOK_SECRET,
    );

    const data = event.data.object as {
      id?: string;
      customer?: string;
      subscription?: string;
      metadata?: Record<string, string>;
      current_period_start?: number;
      current_period_end?: number;
      cancel_at_period_end?: boolean;
      status?: string;
    };

    return {
      provider: "STRIPE",
      eventId: event.id,
      eventType: event.type,
      organizationId: data.metadata?.organizationId ?? "",
      providerCustomerId: typeof data.customer === "string" ? data.customer : null,
      providerSubscriptionId:
        typeof data.subscription === "string" ? data.subscription : data.id ?? null,
      planKey: data.metadata?.planKey ?? "FREE",
      status: data.status === "trialing" ? "TRIALING" : data.status === "active" ? "ACTIVE" : data.status === "past_due" ? "PAST_DUE" : data.status === "canceled" ? "CANCELED" : "NONE",
      currentPeriodStart: data.current_period_start
        ? new Date(data.current_period_start * 1000)
        : null,
      currentPeriodEnd: data.current_period_end
        ? new Date(data.current_period_end * 1000)
        : null,
      cancelAtPeriodEnd: data.cancel_at_period_end ?? false,
      rawPayload: event,
    };
  }
}
```

Buat file `src/server/modules/billing/infrastructure/stripe/stripe-billing-provider.factory.ts`:

```ts
// src/server/modules/billing/infrastructure/stripe/stripe-billing-provider.factory.ts
import type { BillingProviderFactory } from "../../application/billing-provider.factory";
import { StripeBillingProviderClient } from "./stripe-billing-provider-client";

export class StripeBillingProviderFactory implements BillingProviderFactory {
  provider = "STRIPE" as const;

  createClient() {
    return new StripeBillingProviderClient();
  }
}
```

Buat file `src/server/modules/billing/infrastructure/stripe/stripe-webhook-verifier.ts` jika ingin memisahkan verifier dari client:

```ts
// src/server/modules/billing/infrastructure/stripe/stripe-webhook-verifier.ts
import { StripeBillingProviderClient } from "./stripe-billing-provider-client";

export class StripeWebhookVerifier {
  private readonly client = new StripeBillingProviderClient();

  verify(rawBody: string, signature: string | null) {
    return this.client.verifyWebhook({ rawBody, signature });
  }
}
```

Catatan: mapping event Stripe di atas sengaja disederhanakan. Production perlu handle event khusus seperti `checkout.session.completed`, `customer.subscription.updated`, dan `customer.subscription.deleted` dengan payload type yang lebih presisi.

## Factory Selector

Buat helper untuk memilih factory berdasarkan env.

```ts
// src/server/modules/billing/infrastructure/create-billing-provider.factory.ts
import { env } from "@/env";
import type { BillingProviderFactory } from "../application/billing-provider.factory";
import { MockBillingProviderFactory } from "./mock/mock-billing-provider.factory";
import { StripeBillingProviderFactory } from "./stripe/stripe-billing-provider.factory";

export function createBillingProviderFactory(): BillingProviderFactory {
  if (env.BILLING_PROVIDER === "stripe") {
    return new StripeBillingProviderFactory();
  }

  return new MockBillingProviderFactory();
}
```

Application service menerima factory interface. Infrastructure memilih implementasi konkret.

## Organization Billing Access Checker

Buat file `src/server/modules/billing/infrastructure/prisma-organization-billing-access-checker.ts`:

```ts
// src/server/modules/billing/infrastructure/prisma-organization-billing-access-checker.ts
import type { PrismaClient } from "@prisma/client";
import type {
  OrganizationBillingAccess,
  OrganizationBillingAccessChecker,
} from "../application/organization-billing-access-checker";

export class PrismaOrganizationBillingAccessChecker
  implements OrganizationBillingAccessChecker
{
  constructor(private readonly db: PrismaClient) {}

  async getAccess(params: {
    organizationId: string;
    actorUserId: string;
  }): Promise<OrganizationBillingAccess | null> {
    const membership = await this.db.organizationMember.findUnique({
      where: {
        userId_organizationId: {
          userId: params.actorUserId,
          organizationId: params.organizationId,
        },
      },
      include: {
        organization: true,
      },
    });

    if (!membership) {
      return null;
    }

    return {
      organizationId: membership.organizationId,
      organizationName: membership.organization.name,
      actorRole: membership.role,
    };
  }
}
```

Billing tetap memakai tenant boundary yang sama dengan module organization.

## Billing Service

Buat file `src/server/modules/billing/application/billing.service.ts`:

```ts
// src/server/modules/billing/application/billing.service.ts
import { env } from "@/env";
import { err, ok, type AppResult } from "@/shared/result/result";
import { billingPlans, findBillingPlan } from "../domain/billing-plan.entity";
import type { BillingSubscriptionEntity } from "../domain/subscription.entity";
import type { BillingProviderFactory } from "./billing-provider.factory";
import type { BillingRepository } from "./billing.repository";
import {
  canManageBilling,
  type OrganizationBillingAccessChecker,
} from "./organization-billing-access-checker";

export type BillingError =
  | "ORGANIZATION_ACCESS_REQUIRED"
  | "BILLING_MANAGE_FORBIDDEN"
  | "PLAN_NOT_FOUND"
  | "CHECKOUT_NOT_AVAILABLE_FOR_FREE_PLAN"
  | "SUBSCRIPTION_NOT_FOUND"
  | "WEBHOOK_ALREADY_PROCESSED"
  | "WEBHOOK_INVALID";

export class BillingService {
  constructor(
    private readonly billingRepository: BillingRepository,
    private readonly accessChecker: OrganizationBillingAccessChecker,
    private readonly providerFactory: BillingProviderFactory,
  ) {}

  getAvailablePlans() {
    return billingPlans;
  }

  async getCurrentSubscription(params: {
    actorUserId: string;
    organizationId: string;
  }): Promise<AppResult<BillingSubscriptionEntity | null, BillingError>> {
    const access = await this.accessChecker.getAccess(params);

    if (!access) {
      return err("ORGANIZATION_ACCESS_REQUIRED", "Organization access is required.");
    }

    const subscription =
      await this.billingRepository.findSubscriptionByOrganizationId(
        params.organizationId,
      );

    return ok(subscription);
  }

  async createCheckoutSession(params: {
    actorUserId: string;
    organizationId: string;
    planKey: string;
  }) {
    const access = await this.accessChecker.getAccess(params);

    if (!access) {
      return err("ORGANIZATION_ACCESS_REQUIRED", "Organization access is required.");
    }

    if (!canManageBilling(access.actorRole)) {
      return err("BILLING_MANAGE_FORBIDDEN", "You cannot manage billing.");
    }

    const plan = findBillingPlan(params.planKey);

    if (!plan) {
      return err("PLAN_NOT_FOUND", "Billing plan was not found.");
    }

    if (plan.key === "FREE") {
      return err(
        "CHECKOUT_NOT_AVAILABLE_FOR_FREE_PLAN",
        "Free plan does not need checkout.",
      );
    }

    const providerClient = this.providerFactory.createClient();
    const checkout = await providerClient.createCheckoutSession({
      organizationId: params.organizationId,
      organizationName: access.organizationName,
      plan,
      successUrl: env.APP_BILLING_SUCCESS_URL,
      cancelUrl: env.APP_BILLING_CANCEL_URL,
    });

    return ok(checkout);
  }

  async createCustomerPortalSession(params: {
    actorUserId: string;
    organizationId: string;
  }) {
    const access = await this.accessChecker.getAccess(params);

    if (!access) {
      return err("ORGANIZATION_ACCESS_REQUIRED", "Organization access is required.");
    }

    if (!canManageBilling(access.actorRole)) {
      return err("BILLING_MANAGE_FORBIDDEN", "You cannot manage billing.");
    }

    const subscription =
      await this.billingRepository.findSubscriptionByOrganizationId(
        params.organizationId,
      );

    if (!subscription?.providerCustomerId) {
      return err("SUBSCRIPTION_NOT_FOUND", "Billing customer was not found.");
    }

    const providerClient = this.providerFactory.createClient();
    const portal = await providerClient.createCustomerPortalSession({
      organizationId: params.organizationId,
      providerCustomerId: subscription.providerCustomerId,
      returnUrl: env.NEXT_PUBLIC_APP_URL,
    });

    return ok(portal);
  }

  async handleWebhook(params: { rawBody: string; signature: string | null }) {
    const providerClient = this.providerFactory.createClient();
    const event = await providerClient.verifyWebhook(params);

    if (!event.organizationId) {
      return err("WEBHOOK_INVALID", "Webhook does not include organization id.");
    }

    const alreadyProcessed = await this.billingRepository.hasProcessedWebhookEvent({
      provider: event.provider,
      eventId: event.eventId,
    });

    if (alreadyProcessed) {
      return err("WEBHOOK_ALREADY_PROCESSED", "Webhook event already processed.");
    }

    const plan = findBillingPlan(event.planKey);

    if (!plan) {
      return err("PLAN_NOT_FOUND", "Webhook plan was not found.");
    }

    await this.billingRepository.upsertSubscription({
      organizationId: event.organizationId,
      provider: event.provider,
      providerCustomerId: event.providerCustomerId,
      providerSubscriptionId: event.providerSubscriptionId,
      planKey: plan.key,
      status: event.status,
      currentPeriodStart: event.currentPeriodStart,
      currentPeriodEnd: event.currentPeriodEnd,
      trialEndsAt: event.trialEndsAt,
      cancelAtPeriodEnd: event.cancelAtPeriodEnd,
    });

    await this.billingRepository.markWebhookEventProcessed({
      provider: event.provider,
      eventId: event.eventId,
      eventType: event.eventType,
      payload: event.rawPayload,
    });

    return ok({ processed: true });
  }
}
```

Penjelasan:

- `getAvailablePlans` tidak butuh provider.
- Checkout dan portal butuh owner/admin organization.
- Plan dari frontend divalidasi dengan `findBillingPlan`.
- Webhook diverifikasi oleh provider client dari factory.
- Webhook id disimpan agar idempotent.

## Presentation Input

Buat file `src/server/modules/billing/presentation/billing.input.ts`:

```ts
// src/server/modules/billing/presentation/billing.input.ts
import { z } from "zod";

export const organizationBillingInputSchema = z.object({
  organizationId: z.string().min(1),
});

export const createCheckoutInputSchema = z.object({
  organizationId: z.string().min(1),
  planKey: z.enum(["PRO", "BUSINESS"]),
});

export type OrganizationBillingInput = z.infer<
  typeof organizationBillingInputSchema
>;
export type CreateCheckoutInput = z.infer<typeof createCheckoutInputSchema>;
```

Penjelasan:

- Frontend hanya boleh mengirim `planKey`, bukan price.
- `FREE` tidak masuk checkout karena tidak perlu payment provider.
- `organizationId` tetap dicek di service lewat membership.

## tRPC Billing Router

Buat file `src/server/modules/billing/presentation/billing.router.ts`:

```ts
// src/server/modules/billing/presentation/billing.router.ts
import { TRPCError } from "@trpc/server";
import { createTRPCRouter, protectedProcedure, publicProcedure } from "@/server/api/trpc";
import { db } from "@/server/db";
import { BillingService } from "../application/billing.service";
import { PrismaBillingRepository } from "../infrastructure/prisma-billing.repository";
import { PrismaOrganizationBillingAccessChecker } from "../infrastructure/prisma-organization-billing-access-checker";
import { createBillingProviderFactory } from "../infrastructure/create-billing-provider.factory";
import {
  createCheckoutInputSchema,
  organizationBillingInputSchema,
} from "./billing.input";

function createBillingService() {
  return new BillingService(
    new PrismaBillingRepository(db),
    new PrismaOrganizationBillingAccessChecker(db),
    createBillingProviderFactory(),
  );
}

function throwBillingError(error: string, message?: string): never {
  if (error === "ORGANIZATION_ACCESS_REQUIRED") {
    throw new TRPCError({
      code: "FORBIDDEN",
      message: message ?? "Organization access is required.",
    });
  }

  if (error === "BILLING_MANAGE_FORBIDDEN") {
    throw new TRPCError({
      code: "FORBIDDEN",
      message: message ?? "You cannot manage billing.",
    });
  }

  if (error === "PLAN_NOT_FOUND" || error === "SUBSCRIPTION_NOT_FOUND") {
    throw new TRPCError({
      code: "NOT_FOUND",
      message: message ?? "Billing resource was not found.",
    });
  }

  throw new TRPCError({
    code: "BAD_REQUEST",
    message: message ?? error,
  });
}

export const billingModuleRouter = createTRPCRouter({
  plans: publicProcedure.query(() => {
    const billingService = createBillingService();
    return billingService.getAvailablePlans();
  }),

  current: protectedProcedure
    .input(organizationBillingInputSchema)
    .query(async ({ ctx, input }) => {
      const billingService = createBillingService();
      const result = await billingService.getCurrentSubscription({
        actorUserId: ctx.user.id,
        organizationId: input.organizationId,
      });

      if (!result.ok) {
        throwBillingError(result.error, result.message);
      }

      return result.value;
    }),

  createCheckout: protectedProcedure
    .input(createCheckoutInputSchema)
    .mutation(async ({ ctx, input }) => {
      const billingService = createBillingService();
      const result = await billingService.createCheckoutSession({
        actorUserId: ctx.user.id,
        organizationId: input.organizationId,
        planKey: input.planKey,
      });

      if (!result.ok) {
        throwBillingError(result.error, result.message);
      }

      return result.value;
    }),

  createPortal: protectedProcedure
    .input(organizationBillingInputSchema)
    .mutation(async ({ ctx, input }) => {
      const billingService = createBillingService();
      const result = await billingService.createCustomerPortalSession({
        actorUserId: ctx.user.id,
        organizationId: input.organizationId,
      });

      if (!result.ok) {
        throwBillingError(result.error, result.message);
      }

      return result.value;
    }),
});
```

Penjelasan:

- `plans` public karena pricing boleh dilihat tanpa login.
- `current`, `createCheckout`, dan `createPortal` protected.
- Actor user selalu dari `ctx.user.id`.
- Billing action dicek owner/admin di service.

## Webhook Route Handler

Webhook tidak memakai `protectedProcedure` karena dipanggil provider, bukan user login. Webhook harus memakai signature verification provider.

Buat file `src/server/modules/billing/presentation/billing-webhook.route.ts`:

```ts
// src/server/modules/billing/presentation/billing-webhook.route.ts
import { NextResponse } from "next/server";
import { db } from "@/server/db";
import { BillingService } from "../application/billing.service";
import { PrismaBillingRepository } from "../infrastructure/prisma-billing.repository";
import { PrismaOrganizationBillingAccessChecker } from "../infrastructure/prisma-organization-billing-access-checker";
import { createBillingProviderFactory } from "../infrastructure/create-billing-provider.factory";

function createBillingService() {
  return new BillingService(
    new PrismaBillingRepository(db),
    new PrismaOrganizationBillingAccessChecker(db),
    createBillingProviderFactory(),
  );
}

export async function POST(request: Request) {
  const rawBody = await request.text();
  const signature = request.headers.get("stripe-signature");

  const billingService = createBillingService();
  const result = await billingService.handleWebhook({
    rawBody,
    signature,
  });

  if (!result.ok && result.error !== "WEBHOOK_ALREADY_PROCESSED") {
    return NextResponse.json(
      {
        error: result.error,
        message: result.message,
      },
      {
        status: 400,
      },
    );
  }

  return NextResponse.json({ received: true });
}
```

Expose route handler di App Router:

```ts
// src/app/api/billing/webhook/route.ts
export { POST } from "@/server/modules/billing/presentation/billing-webhook.route";
```

Penjelasan:

- Webhook membaca raw body dengan `request.text()`.
- Signature header untuk Stripe adalah `stripe-signature`.
- Mock provider bisa mengabaikan signature.
- Event yang sudah diproses tetap return sukses agar provider tidak retry terus.

## Expose Billing Router

Buat file `src/server/api/routers/billing.router.ts`:

```ts
// src/server/api/routers/billing.router.ts
export { billingModuleRouter as billingRouter } from "@/server/modules/billing/presentation/billing.router";
```

Update root router:

```ts
// src/server/api/root.ts
import { createTRPCRouter } from "@/server/api/trpc";
import { billingRouter } from "@/server/api/routers/billing.router";
import { healthRouter } from "@/server/api/routers/health";
import { identityRouter } from "@/server/api/routers/identity.router";
import { organizationsRouter } from "@/server/api/routers/organizations.router";
import { tasksRouter } from "@/server/api/routers/tasks.router";

export const appRouter = createTRPCRouter({
  health: healthRouter,
  identity: identityRouter,
  organizations: organizationsRouter,
  tasks: tasksRouter,
  billing: billingRouter,
});

export type AppRouter = typeof appRouter;
```

## Request Flow

Flow checkout:

```txt
Client sends organizationId + planKey
  |
  v
protectedProcedure verifies ctx.user
  |
  v
BillingService checks organization access
  |
  v
BillingService validates plan from backend list
  |
  v
BillingProviderFactory creates provider client
  |
  v
provider creates checkout session
  |
  v
response { url, providerSessionId }
```

Flow webhook:

```txt
Payment provider sends webhook
  |
  v
Route Handler reads raw body + signature
  |
  v
BillingProviderClient.verifyWebhook
  |
  v
BillingService checks idempotency
  |
  v
BillingRepository.upsertSubscription
  |
  v
BillingRepository.markWebhookEventProcessed
```

Flow feature limit:

```txt
Project/Organization service wants to create resource
  |
  v
FeatureLimitService loads subscription by organizationId
  |
  v
find plan limits from backend config
  |
  v
count current usage
  |
  v
allow or reject action
```

## Cara Test Secara Konsep

Jalankan development server:

```bash
npm run dev
```

Penjelasan:

- `npm run dev` menjalankan Next.js development server.
- Gunakan `BILLING_PROVIDER="mock"` untuk local development.
- Procedure checkout/portal butuh token login dan organization membership.

Ambil daftar plan:

```txt
billing.plans
```

Ambil subscription current:

```txt
billing.current
```

Input:

```json
{
  "organizationId": "org_id"
}
```

Buat checkout session:

```txt
billing.createCheckout
```

Input:

```json
{
  "organizationId": "org_id",
  "planKey": "PRO"
}
```

Expected response mock:

```json
{
  "url": "http://localhost:3000/mock-billing/checkout?organizationId=org_id&plan=PRO",
  "providerSessionId": "mock_checkout_123"
}
```

Buat customer portal:

```txt
billing.createPortal
```

Input:

```json
{
  "organizationId": "org_id"
}
```

Webhook mock secara konsep mengirim payload:

```json
{
  "provider": "MOCK",
  "eventId": "evt_mock_1",
  "eventType": "subscription.updated",
  "organizationId": "org_id",
  "providerCustomerId": "cus_mock_1",
  "providerSubscriptionId": "sub_mock_1",
  "planKey": "PRO",
  "status": "ACTIVE",
  "rawPayload": {}
}
```

Endpoint webhook:

```txt
POST /api/billing/webhook
```

## Error Handling

Mapping error yang disarankan:

| Domain error | tRPC/HTTP code | Arti |
| --- | --- | --- |
| `ORGANIZATION_ACCESS_REQUIRED` | `FORBIDDEN` | User bukan member organization. |
| `BILLING_MANAGE_FORBIDDEN` | `FORBIDDEN` | User tidak boleh mengelola billing. |
| `PLAN_NOT_FOUND` | `NOT_FOUND` | Plan tidak valid. |
| `SUBSCRIPTION_NOT_FOUND` | `NOT_FOUND` | Subscription/customer belum ada. |
| `CHECKOUT_NOT_AVAILABLE_FOR_FREE_PLAN` | `BAD_REQUEST` | Free plan tidak perlu checkout. |
| `WEBHOOK_INVALID` | `400` | Webhook tidak valid. |
| `WEBHOOK_ALREADY_PROCESSED` | `200` | Event sudah diproses dan aman diabaikan. |

Jangan mengembalikan provider secret atau raw error yang berisi data sensitif ke client.

## Security Notes

- Billing selalu terikat ke `organizationId`, bukan hanya user.
- Checkout harus memvalidasi plan di backend.
- Jangan percaya price dari frontend.
- Billing action harus cek owner/admin organization.
- Webhook wajib signature verification untuk provider production.
- Webhook harus idempotent.
- Jangan log secret key atau webhook secret.
- Customer portal URL dibuat backend, bukan hardcode frontend.
- Mock provider hanya untuk development.
- Stripe implementation di file ini adalah blueprint sederhana, bukan implementasi production penuh.

## Troubleshooting

### Checkout Membuat Plan Salah

Pastikan frontend hanya mengirim `planKey`. Backend harus mengambil price dari `billingPlans`, bukan dari input frontend.

### `BILLING_MANAGE_FORBIDDEN`

User bukan owner/admin organization. Cek membership role di `OrganizationMember`.

### Webhook Selalu Gagal Signature

Cek:

- raw body dibaca dengan `request.text()`;
- header `stripe-signature` diteruskan;
- `STRIPE_WEBHOOK_SECRET` sesuai endpoint webhook Stripe;
- jangan parse JSON sebelum signature verification Stripe.

### Webhook Diproses Berkali-kali

Pastikan `BillingWebhookEvent` punya unique constraint:

```prisma
// prisma/schema.prisma
@@unique([provider, eventId])
```

### Customer Portal Gagal

Pastikan subscription punya `providerCustomerId`. Customer portal tidak bisa dibuat tanpa customer id provider.

### Local Development Tidak Punya Stripe

Gunakan:

```dotenv
# .env
BILLING_PROVIDER="mock"
```

Mock provider tidak butuh Stripe secret.

## Checklist Review Billing

Gunakan checklist ini saat menambah billing feature:

- Apakah billing data memakai `organizationId`?
- Apakah plan/price divalidasi di backend?
- Apakah billing action memakai protected procedure?
- Apakah owner/admin organization dicek sebelum checkout/portal?
- Apakah webhook diverifikasi provider?
- Apakah webhook idempotent?
- Apakah application service tidak import Stripe SDK langsung?
- Apakah provider dibuat lewat Abstract Factory?
- Apakah mock provider bisa dipakai di local development?
- Apakah feature limit berada di service, bukan tersebar di router?

## Output Akhir File Ini

Setelah mengikuti file ini, pembaca harus memahami:

- konsep billing SaaS;
- kenapa subscription melekat ke organization;
- kenapa billing provider perlu abstraction;
- cara memakai Abstract Factory Pattern untuk billing provider;
- cara membuat mock provider dan Stripe provider blueprint;
- cara membuat checkout session dan customer portal session;
- cara handle webhook secara idempotent;
- cara menyimpan subscription di Prisma;
- cara mengecek feature limit sederhana;
- cara expose billing via protected tRPC dan route handler webhook.

## Checklist Berhasil

- [ ] Prisma `BillingSubscription` siap.
- [ ] Prisma `BillingWebhookEvent` siap untuk idempotency.
- [ ] Env billing siap.
- [ ] Domain plan, provider, dan subscription status siap.
- [ ] Billing repository siap.
- [ ] Billing provider client interface siap.
- [ ] Billing provider factory interface siap.
- [ ] Mock billing provider siap.
- [ ] Stripe provider blueprint siap.
- [ ] Billing service memakai factory, bukan Stripe langsung.
- [ ] Checkout session divalidasi by backend plan.
- [ ] Customer portal session siap.
- [ ] Webhook route handler siap.
- [ ] Feature limit service siap.
- [ ] Root router mengekspos `billing`.
- [ ] Siap lanjut ke `07-testing-deployment.md`.
