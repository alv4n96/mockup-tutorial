# Backend 04 - Organization & Tenancy

File ini menjelaskan cara membuat module Organization/Tenancy untuk backend modern SaaS task workspace di stack `modern-saas-t3-next`.

File `01-project-setup.md` sudah menyiapkan fondasi Next.js/T3-style, TypeScript, tRPC, Prisma, PostgreSQL, Zod, env, seed, dan health endpoint. File `02-modular-monolith-layers.md` sudah menjelaskan modular monolith dan layered architecture. File `03-identity-auth.md` sudah menyiapkan Identity/Auth, `register`, `login`, `me`, JWT, bcrypt, `User`, `publicProcedure`, `protectedProcedure`, dan `ctx.user`.

Organization/Tenancy adalah layer berikutnya setelah identity. Identity menjawab "siapa user aktif?", sedangkan organization menjawab "user ini sedang bekerja di workspace/tenant mana, dan role-nya apa di tenant tersebut?"

SaaS hampir selalu butuh organization atau tenant karena satu aplikasi biasanya dipakai banyak customer, team, workspace, atau company. Data antar customer harus terpisah. User A dari organization A tidak boleh membaca atau mengubah data organization B.

Di stack task workspace ini, `Project` dan `Task` nanti wajib punya `organizationId`. Setiap query project/task harus memfilter dan memverifikasi `organizationId`, bukan hanya percaya input dari frontend.

## Konsep Dasar

### Organization

Organization adalah workspace atau company tempat user bekerja. Dalam SaaS task workspace, organization menjadi container untuk member, project, task, audit log, billing, dan setting.

### Tenant

Tenant adalah customer atau ruang data yang terisolasi di aplikasi multi-tenant. Dalam dokumentasi ini, satu organization diperlakukan sebagai satu tenant.

Istilah sederhana:

- organization: nama domain di aplikasi;
- tenant: istilah arsitektur untuk boundary data.

### Multi-tenancy

Multi-tenancy berarti satu aplikasi melayani banyak tenant. Semua tenant memakai codebase dan deployment yang sama, tetapi data mereka harus tetap terpisah.

```txt
Satu aplikasi Next.js
  ├── Organization A
  │   ├── Project A1
  │   └── Task A1
  └── Organization B
      ├── Project B1
      └── Task B1
```

Organization A tidak boleh melihat project dan task Organization B.

### Tenant Isolation

Tenant isolation adalah aturan bahwa data tenant harus difilter dan diverifikasi berdasarkan tenant aktif.

Aturan penting:

- jangan percaya `organizationId` hanya karena dikirim frontend;
- cek user login adalah member organization tersebut;
- semua query data bisnis wajib memakai `organizationId`;
- mutation wajib memastikan user punya permission yang sesuai.

Flow dasar:

```txt
ctx.user
  |
  v
check membership by userId + organizationId
  |
  v
check role/permission
  |
  v
query/mutate data with organizationId filter
```

### Organization Member

Organization member adalah relasi antara user dan organization. Satu user bisa menjadi member di banyak organization.

```txt
user@example.com
  ├── Owner di Acme Studio
  └── Member di Client Workspace
```

Relasi ini disimpan di table `OrganizationMember`.

### Organization Role

Organization role adalah role user di organization tertentu. Role ini berbeda dari global role di Identity.

Role yang dipakai di file ini:

- `OWNER`
- `ADMIN`
- `MEMBER`

### Owner

Owner adalah pemilik organization. Owner punya permission paling tinggi di organization tersebut.

Owner bisa melihat detail organization, menambah member, mengubah role member, menghapus member, dan mengelola setting penting.

Untuk keamanan, owner terakhir sebaiknya tidak bisa dihapus atau diturunkan role-nya. File ini memberi rule dasar untuk mencegah organization tanpa owner.

### Admin

Admin adalah member yang boleh mengelola sebagian besar hal operasional di organization.

Admin bisa menambah member, mengubah role member biasa, menghapus member biasa, dan mengelola project/task sesuai policy. Admin tidak boleh menghapus owner terakhir.

### Member

Member adalah user biasa di organization. Member biasanya bisa melihat organization tempat ia tergabung dan mengakses project/task sesuai policy, tetapi tidak bisa mengelola member.

### Global Role User vs Organization Role

Global role dari Identity berada di model `User`:

```txt
User.role = ADMIN | MEMBER
```

Role ini berlaku secara global di aplikasi. Contohnya untuk admin internal platform.

Organization role berada di membership:

```txt
OrganizationMember.role = OWNER | ADMIN | MEMBER
```

Role ini berlaku hanya untuk organization tertentu. User yang sama bisa `OWNER` di organization A dan `MEMBER` di organization B.

Untuk SaaS multi-tenant, permission fitur bisnis sebaiknya memakai organization role, bukan hanya global user role.

### Current Organization Context

Current organization context adalah organization yang sedang dipakai user untuk request tertentu.

Di backend, context ini biasanya berasal dari `organizationId` di input tRPC, slug organization di route, header khusus seperti `x-organization-id`, atau pilihan workspace aktif di frontend.

File ini memakai `organizationId` di input procedure agar alurnya eksplisit untuk pemula. Apa pun sumbernya, backend tetap wajib mengecek membership.

## Scope Fitur

Fitur yang dibuat di dokumentasi ini:

- create organization;
- get my organizations;
- get organization detail;
- add member;
- change member role;
- remove member;
- check membership;
- check permission manage members;
- protected tRPC procedures;
- Zod validation;
- Prisma repository;
- result pattern;
- error handling.

Yang tidak dibahas mendalam di file ini:

- UI switch workspace;
- invitation email;
- billing;
- project/task workflow;
- audit log detail;
- role/permission matrix yang kompleks.

## Struktur Folder Organizations

Gunakan struktur:

```txt
src/server/modules/organizations/
├── domain/
│   ├── organization.entity.ts
│   ├── organization-member.entity.ts
│   └── organization-role.ts
│
├── application/
│   ├── organization.service.ts
│   └── organization.repository.ts
│
├── infrastructure/
│   └── prisma-organization.repository.ts
│
└── presentation/
    ├── organization.input.ts
    └── organization.router.ts
```

Penjelasan:

- `domain`: entity, role, dan policy murni tanpa Prisma/tRPC.
- `application`: use case organization dan membership.
- `infrastructure`: implementasi repository dengan Prisma.
- `presentation`: input schema Zod dan tRPC router.

## Prisma Schema

File `01-project-setup.md` sudah mengenalkan model `Organization` dan `OrganizationMember`. Untuk module ini, pastikan schema minimalnya seperti berikut.

```prisma
// prisma/schema.prisma
enum OrganizationRole {
  OWNER
  ADMIN
  MEMBER
}

model Organization {
  id        String   @id @default(cuid())
  name      String
  slug      String   @unique
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  members   OrganizationMember[]
  projects  Project[]
  tasks     Task[]
  auditLogs AuditLog[]
}

model OrganizationMember {
  id             String           @id @default(cuid())
  userId         String
  organizationId String
  role           OrganizationRole @default(MEMBER)
  createdAt      DateTime         @default(now())
  updatedAt      DateTime         @updatedAt

  user         User         @relation(fields: [userId], references: [id], onDelete: Cascade)
  organization Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)

  @@unique([userId, organizationId])
  @@index([organizationId])
  @@index([userId])
  @@index([role])
}
```

Penjelasan:

- `Organization.slug` unik agar workspace bisa punya identifier stabil.
- `OrganizationMember` menghubungkan user dengan organization.
- `@@unique([userId, organizationId])` mencegah user yang sama masuk dua kali ke organization yang sama.
- `role` menyimpan role user di organization tersebut.

Jika schema berubah, jalankan migration:

```bash
npx prisma migrate dev --name add_organization_tenancy
```

Penjelasan:

- `prisma migrate dev` membuat dan menjalankan migration development.
- `--name add_organization_tenancy` membuat nama migration mudah dibaca.
- Command ini juga generate Prisma Client setelah migration berhasil.

## Domain Layer

### Organization Role

Buat file `src/server/modules/organizations/domain/organization-role.ts`:

```ts
// src/server/modules/organizations/domain/organization-role.ts
export const organizationRoles = ["OWNER", "ADMIN", "MEMBER"] as const;

export type OrganizationRole = (typeof organizationRoles)[number];

export function isOrganizationRole(value: string): value is OrganizationRole {
  return organizationRoles.includes(value as OrganizationRole);
}

export function canManageMembers(role: OrganizationRole) {
  return role === "OWNER" || role === "ADMIN";
}

export function canManageRole(params: {
  actorRole: OrganizationRole;
  targetRole: OrganizationRole;
  nextRole?: OrganizationRole;
}) {
  if (params.actorRole === "OWNER") {
    return true;
  }

  if (params.actorRole !== "ADMIN") {
    return false;
  }

  if (params.targetRole === "OWNER") {
    return false;
  }

  if (params.nextRole === "OWNER") {
    return false;
  }

  return true;
}
```

Penjelasan:

- `OWNER` dan `ADMIN` bisa manage member.
- `ADMIN` tidak boleh mengubah owner.
- `ADMIN` tidak boleh menaikkan user menjadi owner.
- Rule ini masih sederhana dan bisa diperluas nanti.

### Organization Entity

Buat file `src/server/modules/organizations/domain/organization.entity.ts`:

```ts
// src/server/modules/organizations/domain/organization.entity.ts
export type OrganizationEntity = {
  id: string;
  name: string;
  slug: string;
  createdAt: Date;
  updatedAt: Date;
};

export function normalizeOrganizationName(name: string) {
  return name.trim();
}

export function createOrganizationSlug(name: string) {
  return normalizeOrganizationName(name)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 64);
}

export function assertValidOrganizationName(name: string) {
  const normalizedName = normalizeOrganizationName(name);

  if (normalizedName.length < 2) {
    throw new Error("ORGANIZATION_NAME_TOO_SHORT");
  }

  if (normalizedName.length > 120) {
    throw new Error("ORGANIZATION_NAME_TOO_LONG");
  }

  return normalizedName;
}
```

Penjelasan:

- Domain membuat name dan slug konsisten.
- Slug dibuat dari name sebagai default.
- Jika produk butuh custom slug, tambahkan validation terpisah.

### Organization Member Entity

Buat file `src/server/modules/organizations/domain/organization-member.entity.ts`:

```ts
// src/server/modules/organizations/domain/organization-member.entity.ts
import type { OrganizationRole } from "./organization-role";

export type OrganizationMemberEntity = {
  id: string;
  userId: string;
  organizationId: string;
  role: OrganizationRole;
  createdAt: Date;
  updatedAt: Date;
};

export type OrganizationMemberWithUser = OrganizationMemberEntity & {
  user: {
    id: string;
    email: string;
    name: string | null;
  };
};
```

Penjelasan:

- Entity membership menyimpan relasi user dan organization.
- `OrganizationMemberWithUser` dipakai untuk response daftar member.
- Jangan masukkan `passwordHash` user ke response member.

## Application Repository Contract

Buat file `src/server/modules/organizations/application/organization.repository.ts`:

```ts
// src/server/modules/organizations/application/organization.repository.ts
import type { OrganizationEntity } from "../domain/organization.entity";
import type {
  OrganizationMemberEntity,
  OrganizationMemberWithUser,
} from "../domain/organization-member.entity";
import type { OrganizationRole } from "../domain/organization-role";

export type CreateOrganizationData = {
  name: string;
  slug: string;
  ownerUserId: string;
};

export type OrganizationWithMembership = OrganizationEntity & {
  membership: OrganizationMemberEntity;
};

export interface OrganizationRepository {
  create(data: CreateOrganizationData): Promise<OrganizationWithMembership>;
  findById(id: string): Promise<OrganizationEntity | null>;
  findBySlug(slug: string): Promise<OrganizationEntity | null>;
  findManyByUserId(userId: string): Promise<OrganizationWithMembership[]>;
  findMember(params: {
    organizationId: string;
    userId: string;
  }): Promise<OrganizationMemberEntity | null>;
  findMembers(organizationId: string): Promise<OrganizationMemberWithUser[]>;
  addMember(params: {
    organizationId: string;
    userId: string;
    role: OrganizationRole;
  }): Promise<OrganizationMemberEntity>;
  updateMemberRole(params: {
    organizationId: string;
    userId: string;
    role: OrganizationRole;
  }): Promise<OrganizationMemberEntity>;
  removeMember(params: {
    organizationId: string;
    userId: string;
  }): Promise<void>;
  countOwners(organizationId: string): Promise<number>;
  userExists(userId: string): Promise<boolean>;
}
```

Penjelasan:

- Service bergantung pada interface ini, bukan langsung ke Prisma.
- Repository menyediakan query membership yang dibutuhkan untuk tenant isolation.
- `userExists` dipakai saat add member agar error lebih jelas.

## Application Service

Buat file `src/server/modules/organizations/application/organization.service.ts`:

```ts
// src/server/modules/organizations/application/organization.service.ts
import { err, ok, type AppResult } from "@/shared/result/result";
import {
  assertValidOrganizationName,
  createOrganizationSlug,
  type OrganizationEntity,
} from "../domain/organization.entity";
import type {
  OrganizationMemberEntity,
  OrganizationMemberWithUser,
} from "../domain/organization-member.entity";
import {
  canManageMembers,
  canManageRole,
  type OrganizationRole,
} from "../domain/organization-role";
import type {
  OrganizationRepository,
  OrganizationWithMembership,
} from "./organization.repository";

export type OrganizationError =
  | "ORGANIZATION_NOT_FOUND"
  | "ORGANIZATION_SLUG_TAKEN"
  | "MEMBERSHIP_REQUIRED"
  | "MANAGE_MEMBERS_FORBIDDEN"
  | "USER_NOT_FOUND"
  | "MEMBER_ALREADY_EXISTS"
  | "MEMBER_NOT_FOUND"
  | "OWNER_REQUIRED"
  | "ROLE_CHANGE_FORBIDDEN";

export class OrganizationService {
  constructor(private readonly organizationRepository: OrganizationRepository) {}

  async createOrganization(params: {
    actorUserId: string;
    name: string;
  }): Promise<AppResult<OrganizationWithMembership, OrganizationError>> {
    const name = assertValidOrganizationName(params.name);
    const baseSlug = createOrganizationSlug(name);
    const slug = baseSlug || `org-${Date.now()}`;

    const existingOrganization =
      await this.organizationRepository.findBySlug(slug);

    if (existingOrganization) {
      return err("ORGANIZATION_SLUG_TAKEN", "Organization slug is already used.");
    }

    const organization = await this.organizationRepository.create({
      name,
      slug,
      ownerUserId: params.actorUserId,
    });

    return ok(organization);
  }

  async getMyOrganizations(userId: string) {
    return this.organizationRepository.findManyByUserId(userId);
  }

  async getOrganizationDetail(params: {
    actorUserId: string;
    organizationId: string;
  }): Promise<AppResult<OrganizationEntity, OrganizationError>> {
    const membership = await this.organizationRepository.findMember({
      organizationId: params.organizationId,
      userId: params.actorUserId,
    });

    if (!membership) {
      return err("MEMBERSHIP_REQUIRED", "You are not a member of this organization.");
    }

    const organization = await this.organizationRepository.findById(
      params.organizationId,
    );

    if (!organization) {
      return err("ORGANIZATION_NOT_FOUND", "Organization was not found.");
    }

    return ok(organization);
  }

  async checkMembership(params: {
    actorUserId: string;
    organizationId: string;
  }): Promise<AppResult<OrganizationMemberEntity, OrganizationError>> {
    const membership = await this.organizationRepository.findMember({
      organizationId: params.organizationId,
      userId: params.actorUserId,
    });

    if (!membership) {
      return err("MEMBERSHIP_REQUIRED", "Organization membership is required.");
    }

    return ok(membership);
  }

  async listMembers(params: {
    actorUserId: string;
    organizationId: string;
  }): Promise<AppResult<OrganizationMemberWithUser[], OrganizationError>> {
    const membershipResult = await this.checkMembership(params);

    if (!membershipResult.ok) {
      return membershipResult;
    }

    const members = await this.organizationRepository.findMembers(
      params.organizationId,
    );

    return ok(members);
  }

  async addMember(params: {
    actorUserId: string;
    organizationId: string;
    targetUserId: string;
    role: OrganizationRole;
  }): Promise<AppResult<OrganizationMemberEntity, OrganizationError>> {
    const actorMembershipResult = await this.checkMembership({
      actorUserId: params.actorUserId,
      organizationId: params.organizationId,
    });

    if (!actorMembershipResult.ok) {
      return actorMembershipResult;
    }

    if (!canManageMembers(actorMembershipResult.value.role)) {
      return err("MANAGE_MEMBERS_FORBIDDEN", "You cannot manage members.");
    }

    if (params.role === "OWNER" && actorMembershipResult.value.role !== "OWNER") {
      return err("ROLE_CHANGE_FORBIDDEN", "Only owner can add another owner.");
    }

    const targetUserExists = await this.organizationRepository.userExists(
      params.targetUserId,
    );

    if (!targetUserExists) {
      return err("USER_NOT_FOUND", "Target user was not found.");
    }

    const existingMember = await this.organizationRepository.findMember({
      organizationId: params.organizationId,
      userId: params.targetUserId,
    });

    if (existingMember) {
      return err("MEMBER_ALREADY_EXISTS", "User is already a member.");
    }

    const member = await this.organizationRepository.addMember({
      organizationId: params.organizationId,
      userId: params.targetUserId,
      role: params.role,
    });

    return ok(member);
  }

  async changeMemberRole(params: {
    actorUserId: string;
    organizationId: string;
    targetUserId: string;
    role: OrganizationRole;
  }): Promise<AppResult<OrganizationMemberEntity, OrganizationError>> {
    const actorMembershipResult = await this.checkMembership({
      actorUserId: params.actorUserId,
      organizationId: params.organizationId,
    });

    if (!actorMembershipResult.ok) {
      return actorMembershipResult;
    }

    const targetMembership = await this.organizationRepository.findMember({
      organizationId: params.organizationId,
      userId: params.targetUserId,
    });

    if (!targetMembership) {
      return err("MEMBER_NOT_FOUND", "Target member was not found.");
    }

    if (
      !canManageRole({
        actorRole: actorMembershipResult.value.role,
        targetRole: targetMembership.role,
        nextRole: params.role,
      })
    ) {
      return err("ROLE_CHANGE_FORBIDDEN", "You cannot change this member role.");
    }

    if (targetMembership.role === "OWNER" && params.role !== "OWNER") {
      const ownerCount = await this.organizationRepository.countOwners(
        params.organizationId,
      );

      if (ownerCount <= 1) {
        return err("OWNER_REQUIRED", "Organization must have at least one owner.");
      }
    }

    const updatedMember = await this.organizationRepository.updateMemberRole({
      organizationId: params.organizationId,
      userId: params.targetUserId,
      role: params.role,
    });

    return ok(updatedMember);
  }

  async removeMember(params: {
    actorUserId: string;
    organizationId: string;
    targetUserId: string;
  }): Promise<AppResult<{ removed: true }, OrganizationError>> {
    const actorMembershipResult = await this.checkMembership({
      actorUserId: params.actorUserId,
      organizationId: params.organizationId,
    });

    if (!actorMembershipResult.ok) {
      return actorMembershipResult;
    }

    const targetMembership = await this.organizationRepository.findMember({
      organizationId: params.organizationId,
      userId: params.targetUserId,
    });

    if (!targetMembership) {
      return err("MEMBER_NOT_FOUND", "Target member was not found.");
    }

    if (
      !canManageRole({
        actorRole: actorMembershipResult.value.role,
        targetRole: targetMembership.role,
      })
    ) {
      return err("MANAGE_MEMBERS_FORBIDDEN", "You cannot remove this member.");
    }

    if (targetMembership.role === "OWNER") {
      const ownerCount = await this.organizationRepository.countOwners(
        params.organizationId,
      );

      if (ownerCount <= 1) {
        return err("OWNER_REQUIRED", "Organization must have at least one owner.");
      }
    }

    await this.organizationRepository.removeMember({
      organizationId: params.organizationId,
      userId: params.targetUserId,
    });

    return ok({ removed: true });
  }
}
```

Penjelasan:

- Semua use case menerima `actorUserId` dari `ctx.user.id`.
- Service selalu mengecek membership sebelum membuka data organization.
- Manage member hanya boleh untuk `OWNER` dan `ADMIN`.
- Rule owner terakhir dicek agar organization tidak kehilangan owner.
- Service mengembalikan `AppResult`, bukan langsung melempar `TRPCError`.

## Infrastructure Layer

Buat file `src/server/modules/organizations/infrastructure/prisma-organization.repository.ts`:

```ts
// src/server/modules/organizations/infrastructure/prisma-organization.repository.ts
import type { PrismaClient } from "@prisma/client";
import type { OrganizationEntity } from "../domain/organization.entity";
import type {
  OrganizationMemberEntity,
  OrganizationMemberWithUser,
} from "../domain/organization-member.entity";
import {
  isOrganizationRole,
  type OrganizationRole,
} from "../domain/organization-role";
import type {
  CreateOrganizationData,
  OrganizationRepository,
  OrganizationWithMembership,
} from "../application/organization.repository";

function mapOrganization(organization: OrganizationEntity): OrganizationEntity {
  return organization;
}

function mapMember(member: {
  id: string;
  userId: string;
  organizationId: string;
  role: string;
  createdAt: Date;
  updatedAt: Date;
}): OrganizationMemberEntity {
  if (!isOrganizationRole(member.role)) {
    throw new Error(`Invalid organization role from database: ${member.role}`);
  }

  return {
    id: member.id,
    userId: member.userId,
    organizationId: member.organizationId,
    role: member.role,
    createdAt: member.createdAt,
    updatedAt: member.updatedAt,
  };
}

export class PrismaOrganizationRepository implements OrganizationRepository {
  constructor(private readonly db: PrismaClient) {}

  async create(
    data: CreateOrganizationData,
  ): Promise<OrganizationWithMembership> {
    const organization = await this.db.organization.create({
      data: {
        name: data.name,
        slug: data.slug,
        members: {
          create: {
            userId: data.ownerUserId,
            role: "OWNER",
          },
        },
      },
      include: {
        members: {
          where: {
            userId: data.ownerUserId,
          },
        },
      },
    });

    const membership = organization.members[0];

    if (!membership) {
      throw new Error("OWNER_MEMBERSHIP_NOT_CREATED");
    }

    return {
      id: organization.id,
      name: organization.name,
      slug: organization.slug,
      createdAt: organization.createdAt,
      updatedAt: organization.updatedAt,
      membership: mapMember(membership),
    };
  }

  async findById(id: string): Promise<OrganizationEntity | null> {
    const organization = await this.db.organization.findUnique({
      where: {
        id,
      },
    });

    return organization ? mapOrganization(organization) : null;
  }

  async findBySlug(slug: string): Promise<OrganizationEntity | null> {
    const organization = await this.db.organization.findUnique({
      where: {
        slug,
      },
    });

    return organization ? mapOrganization(organization) : null;
  }

  async findManyByUserId(userId: string): Promise<OrganizationWithMembership[]> {
    const memberships = await this.db.organizationMember.findMany({
      where: {
        userId,
      },
      include: {
        organization: true,
      },
      orderBy: {
        createdAt: "asc",
      },
    });

    return memberships.map((membership) => ({
      id: membership.organization.id,
      name: membership.organization.name,
      slug: membership.organization.slug,
      createdAt: membership.organization.createdAt,
      updatedAt: membership.organization.updatedAt,
      membership: mapMember(membership),
    }));
  }

  async findMember(params: {
    organizationId: string;
    userId: string;
  }): Promise<OrganizationMemberEntity | null> {
    const member = await this.db.organizationMember.findUnique({
      where: {
        userId_organizationId: {
          userId: params.userId,
          organizationId: params.organizationId,
        },
      },
    });

    return member ? mapMember(member) : null;
  }

  async findMembers(
    organizationId: string,
  ): Promise<OrganizationMemberWithUser[]> {
    const members = await this.db.organizationMember.findMany({
      where: {
        organizationId,
      },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            name: true,
          },
        },
      },
      orderBy: {
        createdAt: "asc",
      },
    });

    return members.map((member) => ({
      ...mapMember(member),
      user: member.user,
    }));
  }

  async addMember(params: {
    organizationId: string;
    userId: string;
    role: OrganizationRole;
  }): Promise<OrganizationMemberEntity> {
    const member = await this.db.organizationMember.create({
      data: params,
    });

    return mapMember(member);
  }

  async updateMemberRole(params: {
    organizationId: string;
    userId: string;
    role: OrganizationRole;
  }): Promise<OrganizationMemberEntity> {
    const member = await this.db.organizationMember.update({
      where: {
        userId_organizationId: {
          userId: params.userId,
          organizationId: params.organizationId,
        },
      },
      data: {
        role: params.role,
      },
    });

    return mapMember(member);
  }

  async removeMember(params: {
    organizationId: string;
    userId: string;
  }): Promise<void> {
    await this.db.organizationMember.delete({
      where: {
        userId_organizationId: {
          userId: params.userId,
          organizationId: params.organizationId,
        },
      },
    });
  }

  async countOwners(organizationId: string): Promise<number> {
    return this.db.organizationMember.count({
      where: {
        organizationId,
        role: "OWNER",
      },
    });
  }

  async userExists(userId: string): Promise<boolean> {
    const count = await this.db.user.count({
      where: {
        id: userId,
      },
    });

    return count > 0;
  }
}
```

Penjelasan:

- Semua Prisma query organization terkumpul di repository.
- Repository melakukan mapping role string dari database ke domain role.
- Query member memakai composite unique `userId_organizationId`.
- Response member memilih field user aman dan tidak mengambil `passwordHash`.

## Presentation Input

Buat file `src/server/modules/organizations/presentation/organization.input.ts`:

```ts
// src/server/modules/organizations/presentation/organization.input.ts
import { z } from "zod";
import { organizationRoles } from "../domain/organization-role";

export const createOrganizationInputSchema = z.object({
  name: z.string().min(2).max(120),
});

export const organizationIdInputSchema = z.object({
  organizationId: z.string().min(1),
});

export const addMemberInputSchema = z.object({
  organizationId: z.string().min(1),
  userId: z.string().min(1),
  role: z.enum(organizationRoles).default("MEMBER"),
});

export const changeMemberRoleInputSchema = z.object({
  organizationId: z.string().min(1),
  userId: z.string().min(1),
  role: z.enum(organizationRoles),
});

export const removeMemberInputSchema = z.object({
  organizationId: z.string().min(1),
  userId: z.string().min(1),
});

export type CreateOrganizationInput = z.infer<
  typeof createOrganizationInputSchema
>;
export type OrganizationIdInput = z.infer<typeof organizationIdInputSchema>;
export type AddMemberInput = z.infer<typeof addMemberInputSchema>;
export type ChangeMemberRoleInput = z.infer<
  typeof changeMemberRoleInputSchema
>;
export type RemoveMemberInput = z.infer<typeof removeMemberInputSchema>;
```

Penjelasan:

- Semua procedure organization adalah protected, tetapi input tetap wajib divalidasi.
- `organizationId` dari frontend hanya identifier awal. Membership tetap dicek di service.
- Role input dibatasi oleh enum domain.

## Presentation Router

Buat file `src/server/modules/organizations/presentation/organization.router.ts`:

```ts
// src/server/modules/organizations/presentation/organization.router.ts
import { TRPCError } from "@trpc/server";
import { createTRPCRouter, protectedProcedure } from "@/server/api/trpc";
import { db } from "@/server/db";
import { OrganizationService } from "../application/organization.service";
import { PrismaOrganizationRepository } from "../infrastructure/prisma-organization.repository";
import {
  addMemberInputSchema,
  changeMemberRoleInputSchema,
  createOrganizationInputSchema,
  organizationIdInputSchema,
  removeMemberInputSchema,
} from "./organization.input";

function createOrganizationService() {
  const organizationRepository = new PrismaOrganizationRepository(db);
  return new OrganizationService(organizationRepository);
}

function throwOrganizationError(error: string, message?: string): never {
  if (error === "MEMBERSHIP_REQUIRED") {
    throw new TRPCError({
      code: "FORBIDDEN",
      message: message ?? "Organization membership is required.",
    });
  }

  if (
    error === "MANAGE_MEMBERS_FORBIDDEN" ||
    error === "ROLE_CHANGE_FORBIDDEN"
  ) {
    throw new TRPCError({
      code: "FORBIDDEN",
      message: message ?? "You do not have permission for this action.",
    });
  }

  if (
    error === "ORGANIZATION_NOT_FOUND" ||
    error === "USER_NOT_FOUND" ||
    error === "MEMBER_NOT_FOUND"
  ) {
    throw new TRPCError({
      code: "NOT_FOUND",
      message: message ?? "Resource was not found.",
    });
  }

  throw new TRPCError({
    code: "BAD_REQUEST",
    message: message ?? error,
  });
}

export const organizationsModuleRouter = createTRPCRouter({
  create: protectedProcedure
    .input(createOrganizationInputSchema)
    .mutation(async ({ ctx, input }) => {
      const organizationService = createOrganizationService();
      const result = await organizationService.createOrganization({
        actorUserId: ctx.user.id,
        name: input.name,
      });

      if (!result.ok) {
        throwOrganizationError(result.error, result.message);
      }

      return result.value;
    }),

  mine: protectedProcedure.query(async ({ ctx }) => {
    const organizationService = createOrganizationService();
    return organizationService.getMyOrganizations(ctx.user.id);
  }),

  detail: protectedProcedure
    .input(organizationIdInputSchema)
    .query(async ({ ctx, input }) => {
      const organizationService = createOrganizationService();
      const result = await organizationService.getOrganizationDetail({
        actorUserId: ctx.user.id,
        organizationId: input.organizationId,
      });

      if (!result.ok) {
        throwOrganizationError(result.error, result.message);
      }

      return result.value;
    }),

  members: protectedProcedure
    .input(organizationIdInputSchema)
    .query(async ({ ctx, input }) => {
      const organizationService = createOrganizationService();
      const result = await organizationService.listMembers({
        actorUserId: ctx.user.id,
        organizationId: input.organizationId,
      });

      if (!result.ok) {
        throwOrganizationError(result.error, result.message);
      }

      return result.value;
    }),

  addMember: protectedProcedure
    .input(addMemberInputSchema)
    .mutation(async ({ ctx, input }) => {
      const organizationService = createOrganizationService();
      const result = await organizationService.addMember({
        actorUserId: ctx.user.id,
        organizationId: input.organizationId,
        targetUserId: input.userId,
        role: input.role,
      });

      if (!result.ok) {
        throwOrganizationError(result.error, result.message);
      }

      return result.value;
    }),

  changeMemberRole: protectedProcedure
    .input(changeMemberRoleInputSchema)
    .mutation(async ({ ctx, input }) => {
      const organizationService = createOrganizationService();
      const result = await organizationService.changeMemberRole({
        actorUserId: ctx.user.id,
        organizationId: input.organizationId,
        targetUserId: input.userId,
        role: input.role,
      });

      if (!result.ok) {
        throwOrganizationError(result.error, result.message);
      }

      return result.value;
    }),

  removeMember: protectedProcedure
    .input(removeMemberInputSchema)
    .mutation(async ({ ctx, input }) => {
      const organizationService = createOrganizationService();
      const result = await organizationService.removeMember({
        actorUserId: ctx.user.id,
        organizationId: input.organizationId,
        targetUserId: input.userId,
      });

      if (!result.ok) {
        throwOrganizationError(result.error, result.message);
      }

      return result.value;
    }),
});
```

Penjelasan:

- Semua procedure memakai `protectedProcedure`.
- `ctx.user.id` berasal dari Identity/Auth file 03.
- Router tidak query Prisma langsung.
- Router hanya validasi input, memanggil service, dan mapping error ke `TRPCError`.

## Expose Router Ke App Router

Buat file `src/server/api/routers/organizations.router.ts`:

```ts
// src/server/api/routers/organizations.router.ts
export { organizationsModuleRouter as organizationsRouter } from "@/server/modules/organizations/presentation/organization.router";
```

Update root router:

```ts
// src/server/api/root.ts
import { createTRPCRouter } from "@/server/api/trpc";
import { healthRouter } from "@/server/api/routers/health";
import { identityRouter } from "@/server/api/routers/identity.router";
import { organizationsRouter } from "@/server/api/routers/organizations.router";

export const appRouter = createTRPCRouter({
  health: healthRouter,
  identity: identityRouter,
  organizations: organizationsRouter,
});

export type AppRouter = typeof appRouter;
```

Jika router `tasks` dari file sebelumnya sudah ada, root router menjadi:

```ts
// src/server/api/root.ts
import { createTRPCRouter } from "@/server/api/trpc";
import { healthRouter } from "@/server/api/routers/health";
import { identityRouter } from "@/server/api/routers/identity.router";
import { organizationsRouter } from "@/server/api/routers/organizations.router";
import { tasksRouter } from "@/server/api/routers/tasks.router";

export const appRouter = createTRPCRouter({
  health: healthRouter,
  identity: identityRouter,
  organizations: organizationsRouter,
  tasks: tasksRouter,
});

export type AppRouter = typeof appRouter;
```

Root router tetap menjadi facade API. Detail tenancy tetap berada di module `organizations`.

## Tenant Isolation Untuk Module Lain

Project dan Task nanti wajib membawa `organizationId`.

Contoh query yang buruk:

```ts
// src/server/modules/projects/infrastructure/bad-project.repository.ts
export async function findProjectById(projectId: string) {
  return db.project.findUnique({
    where: {
      id: projectId,
    },
  });
}
```

Masalahnya:

- query hanya memakai `projectId`;
- jika user mengetahui id project tenant lain, data bisa bocor;
- tidak ada cek membership.

Contoh yang lebih aman:

```ts
// src/server/modules/projects/infrastructure/project.repository.ts
export async function findProjectById(params: {
  organizationId: string;
  projectId: string;
}) {
  return db.project.findFirst({
    where: {
      id: params.projectId,
      organizationId: params.organizationId,
    },
  });
}
```

Contoh service yang mengecek membership dulu:

```ts
// src/server/modules/projects/application/project-access.service.ts
import type { OrganizationService } from "@/server/modules/organizations/application/organization.service";

export async function assertProjectAccess(params: {
  organizationService: OrganizationService;
  actorUserId: string;
  organizationId: string;
}) {
  const membershipResult = await params.organizationService.checkMembership({
    actorUserId: params.actorUserId,
    organizationId: params.organizationId,
  });

  if (!membershipResult.ok) {
    throw new Error("MEMBERSHIP_REQUIRED");
  }

  return membershipResult.value;
}
```

Prinsipnya:

- cek membership di boundary use case;
- query data bisnis selalu filter by `organizationId`;
- jangan menerima `userId` dari frontend untuk authorization;
- pakai `ctx.user.id`.

## Request Flow

Flow create organization:

```txt
Client sends token
  |
  v
protectedProcedure verifies ctx.user
  |
  v
organizations.create
  |
  v
Zod validates name
  |
  v
OrganizationService.createOrganization
  |
  v
create organization + OWNER membership
  |
  v
response organization with membership
```

Flow add member:

```txt
Client sends organizationId + target userId
  |
  v
protectedProcedure verifies ctx.user
  |
  v
OrganizationService.addMember
  |
  v
check actor membership
  |
  v
check actor can manage members
  |
  v
check target user exists
  |
  v
check target is not already member
  |
  v
create OrganizationMember
```

Flow tenant data access:

```txt
ctx.user.id
  |
  v
organizationId from input/current context
  |
  v
OrganizationService.checkMembership
  |
  v
Project/Task service query with organizationId
  |
  v
tenant-safe response
```

## Cara Test Secara Konsep

Jalankan development server:

```bash
npm run dev
```

Penjelasan:

- `npm run dev` menjalankan Next.js development server.
- Default URL adalah `http://localhost:3000`.
- Semua procedure organization butuh header `Authorization: Bearer <token>`.

Register/login dulu lewat `identity.login`, lalu simpan token.

Header request protected:

```txt
Authorization: Bearer jwt_token
```

Create organization:

```txt
organizations.create
```

Input:

```json
{
  "name": "Acme Studio"
}
```

Get my organizations:

```txt
organizations.mine
```

Get detail:

```txt
organizations.detail
```

Input:

```json
{
  "organizationId": "org_id"
}
```

Add member:

```txt
organizations.addMember
```

Input:

```json
{
  "organizationId": "org_id",
  "userId": "target_user_id",
  "role": "MEMBER"
}
```

Change member role:

```txt
organizations.changeMemberRole
```

Input:

```json
{
  "organizationId": "org_id",
  "userId": "target_user_id",
  "role": "ADMIN"
}
```

Remove member:

```txt
organizations.removeMember
```

Input:

```json
{
  "organizationId": "org_id",
  "userId": "target_user_id"
}
```

## Error Handling

Service mengembalikan `AppResult`. Router mengubah error domain menjadi `TRPCError`.

Mapping yang disarankan:

| Domain error | tRPC code | Arti |
| --- | --- | --- |
| `MEMBERSHIP_REQUIRED` | `FORBIDDEN` | User bukan member organization. |
| `MANAGE_MEMBERS_FORBIDDEN` | `FORBIDDEN` | User tidak boleh manage member. |
| `ROLE_CHANGE_FORBIDDEN` | `FORBIDDEN` | User tidak boleh mengubah role target. |
| `ORGANIZATION_NOT_FOUND` | `NOT_FOUND` | Organization tidak ditemukan. |
| `USER_NOT_FOUND` | `NOT_FOUND` | Target user tidak ditemukan. |
| `MEMBER_NOT_FOUND` | `NOT_FOUND` | Target member tidak ditemukan. |
| `ORGANIZATION_SLUG_TAKEN` | `BAD_REQUEST` | Slug sudah dipakai. |
| `MEMBER_ALREADY_EXISTS` | `BAD_REQUEST` | User sudah menjadi member. |
| `OWNER_REQUIRED` | `BAD_REQUEST` | Organization harus punya minimal satu owner. |

Jangan membocorkan data tenant lain. Untuk beberapa produk, `MEMBERSHIP_REQUIRED` bisa dikembalikan sebagai `NOT_FOUND` agar attacker tidak tahu organization id valid atau tidak.

## Security Notes

- Jangan percaya `organizationId` dari frontend tanpa cek membership.
- Semua data bisnis seperti project dan task wajib difilter by `organizationId`.
- Jangan menerima `userId` dari frontend untuk actor. Pakai `ctx.user.id`.
- Jangan biarkan organization tanpa owner.
- Batasi siapa yang boleh mengubah role owner.
- Admin organization tidak sama dengan global admin platform.
- Audit log untuk add/remove/change role sebaiknya ditambahkan di file lanjutan.
- Invite email sebaiknya memakai token undangan, bukan langsung add member hanya berdasarkan email.
- Rate limit endpoint add member dan invite member jika dibuka ke production.

## Troubleshooting

### Selalu `UNAUTHORIZED`

Request belum melewati Identity/Auth.

Cek:

- token dikirim dengan header `Authorization: Bearer <token>`;
- token belum expired;
- `protectedProcedure` dari file `03-identity-auth.md` sudah dipakai;
- route handler meneruskan headers ke `createTRPCContext`.

### Selalu `MEMBERSHIP_REQUIRED`

Cek:

- `organizationId` benar;
- user login adalah member organization tersebut;
- table `OrganizationMember` punya row `userId + organizationId`;
- create organization berhasil membuat owner membership.

### `MEMBER_ALREADY_EXISTS`

User yang ditambahkan sudah menjadi member organization. Gunakan `changeMemberRole` jika hanya ingin mengubah role.

### Tidak Bisa Menghapus Owner

Service mencegah organization kehilangan owner terakhir. Tambahkan owner lain dulu, baru turunkan atau hapus owner lama.

### Slug Sudah Dipakai

Contoh service di file ini membuat slug dari name. Jika nama organization sama, slug bisa bentrok.

Solusi production:

- minta user memilih slug;
- tambahkan suffix random pendek;
- cek slug dan retry dengan suffix.

### Prisma Composite Unique Error

Pastikan schema punya:

```prisma
// prisma/schema.prisma
@@unique([userId, organizationId])
```

Lalu jalankan migration:

```bash
npx prisma migrate dev --name add_organization_member_unique
```

## Checklist Review Tenancy

Gunakan checklist ini saat membuat module baru:

- Apakah procedure memakai `protectedProcedure`?
- Apakah actor user berasal dari `ctx.user.id`?
- Apakah `organizationId` selalu dicek lewat membership?
- Apakah query data bisnis memakai filter `organizationId`?
- Apakah repository tidak mengambil data user sensitif seperti `passwordHash`?
- Apakah role organization dipakai untuk permission tenant?
- Apakah owner terakhir dilindungi?
- Apakah error tidak membocorkan data tenant lain secara berlebihan?

## Output Akhir File Ini

Setelah mengikuti file ini, pembaca harus memahami:

- konsep organization dan tenant;
- multi-tenancy dan tenant isolation;
- organization member dan role;
- beda global role user dengan organization role;
- current organization context;
- cara membuat organization;
- cara membaca organization milik user;
- cara add, change role, dan remove member;
- cara check membership dan manage member permission;
- cara menghubungkan organization router ke tRPC;
- cara menjaga project/task nanti tetap tenant-safe.

## Checklist Berhasil

- [ ] Struktur module `organizations` siap.
- [ ] Prisma `Organization` dan `OrganizationMember` siap.
- [ ] Migration organization tenancy berhasil.
- [ ] Domain `OrganizationRole` siap.
- [ ] Domain entity organization dan member siap.
- [ ] Repository contract siap.
- [ ] Prisma organization repository siap.
- [ ] Organization service punya create, mine, detail, members, add, change role, remove.
- [ ] Zod input organization siap.
- [ ] tRPC router organization memakai `protectedProcedure`.
- [ ] Root router mengekspos `organizations`.
- [ ] Membership selalu dicek sebelum akses data tenant.
- [ ] Project dan Task berikutnya siap memakai `organizationId`.
- [ ] Siap lanjut ke `05-task-module.md`.
