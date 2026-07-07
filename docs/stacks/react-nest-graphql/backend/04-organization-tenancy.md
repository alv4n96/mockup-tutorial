# Backend 04 - Organization & Tenancy

Dokumen ini melanjutkan `backend/03-identity-auth.md`. Setelah backend punya register, login, JWT, GraphQL guard, dan current user decorator, sekarang kita membuat module Organization/Tenancy.

Dalam SaaS Task Workspace, organization adalah tenant. User bisa menjadi member di satu atau banyak organization. Project dan task nanti wajib punya `organizationId` agar data antar tenant tidak bercampur.

Organization harus terhubung ke Identity/Auth karena:

- Organization dibuat oleh user yang sedang login.
- Membership menghubungkan user ke organization.
- Permission seperti manage member bergantung pada role user di organization.
- Resolver organization harus protected dengan `GqlAuthGuard`.

File ini memakai aturan layered architecture dari `02-modular-monolith-layers.md`:

```txt
OrganizationsResolver -> OrganizationService -> OrganizationRepository interface -> PrismaOrganizationRepository -> PrismaService -> PostgreSQL
```

## Konsep Dasar Organization/Tenancy

Organization adalah ruang kerja atau perusahaan dalam aplikasi. Contoh: `Acme Corp`, `Internal IT Team`, atau `Design Agency`.

Tenant adalah batas kepemilikan data. Dalam stack ini, satu organization adalah satu tenant.

Multi-tenancy adalah kemampuan satu aplikasi melayani banyak tenant. Semua tenant memakai aplikasi yang sama, tetapi datanya harus terisolasi.

Tenant isolation adalah aturan agar user hanya bisa melihat dan mengubah data tenant tempat dia menjadi member.

Organization member adalah hubungan antara user dan organization.

Organization role adalah role user di dalam organization tertentu:

- `OWNER`: pemilik organization, boleh manage member dan biasanya punya akses penuh.
- `ADMIN`: admin organization, boleh manage member.
- `MEMBER`: member biasa, boleh melihat organization tetapi tidak boleh manage member.

Perbedaan global role User dan organization role:

- Global role User berasal dari Identity module, misalnya `ADMIN` atau `MEMBER` untuk level aplikasi.
- Organization role berlaku hanya di organization tertentu.
- User bisa global `MEMBER`, tetapi menjadi `OWNER` di organization `Acme Corp`.

Current organization context adalah organization aktif yang sedang dipakai user. Di backend, context ini biasanya berasal dari `organizationId` pada input/query dan harus selalu diverifikasi membership-nya.

Data SaaS harus difilter berdasarkan tenant karena:

- User tidak boleh melihat data organization lain.
- Bug filter tenant bisa menjadi kebocoran data serius.
- Project dan task harus selalu query dengan `organizationId`.

## Scope Fitur

Fitur yang dibuat:

- Create organization.
- Get my organizations.
- Get organization detail.
- Add member.
- Change member role.
- Remove member.
- Check membership.
- Check permission manage members.
- Protected GraphQL resolver.
- Current user dari GraphQL auth guard.
- Validation input.
- Error handling.
- Result pattern.
- Prisma repository.

Yang belum dibahas detail:

- Invitation by email.
- Billing tenant.
- Project dan task implementation.
- Audit log organization.
- Soft delete organization.

## Struktur Folder Organizations

```txt
backend/src/modules/organizations/
├── domain/
│   ├── organization.entity.ts
│   ├── organization-member.entity.ts
│   └── organization-role.enum.ts
│
├── application/
│   ├── organization.service.ts
│   └── organization.repository.ts
│
├── infrastructure/
│   └── prisma-organization.repository.ts
│
└── presentation/
    ├── dto/
    │   ├── create-organization.input.ts
    │   ├── add-member.input.ts
    │   ├── change-member-role.input.ts
    │   ├── organization.object.ts
    │   └── organization-member.object.ts
    ├── organizations.resolver.ts
    └── organizations.module.ts
```

Fungsi file:

- `organization-role.enum.ts`: enum role member dalam organization.
- `organization-member.entity.ts`: entity membership user di organization.
- `organization.entity.ts`: entity organization dan business rule member.
- `organization.repository.ts`: kontrak repository untuk service.
- `organization.service.ts`: use case organization dan membership.
- `prisma-organization.repository.ts`: implementasi repository memakai Prisma.
- `create-organization.input.ts`: input GraphQL untuk create organization.
- `add-member.input.ts`: input GraphQL untuk add member.
- `change-member-role.input.ts`: input GraphQL untuk change role.
- `organization.object.ts`: response GraphQL organization.
- `organization-member.object.ts`: response GraphQL membership.
- `organizations.resolver.ts`: query/mutation GraphQL.
- `organizations.module.ts`: registrasi provider module.

## Prisma Schema Organization

Update `schema.prisma`:

```prisma path=backend/prisma/schema.prisma
enum OrganizationRole {
  OWNER
  ADMIN
  MEMBER
}

model User {
  id           String               @id @default(cuid())
  email        String               @unique
  name         String
  passwordHash String
  role         UserRole             @default(MEMBER)
  createdAt    DateTime             @default(now())
  updatedAt    DateTime             @updatedAt
  memberships  OrganizationMember[]
}

model Organization {
  id        String               @id @default(cuid())
  name      String
  slug      String               @unique
  createdAt DateTime             @default(now())
  updatedAt DateTime             @updatedAt
  members   OrganizationMember[]
}

model OrganizationMember {
  id             String           @id @default(cuid())
  organizationId String
  userId         String
  role           OrganizationRole @default(MEMBER)
  joinedAt       DateTime         @default(now())
  organization   Organization     @relation(fields: [organizationId], references: [id], onDelete: Cascade)
  user           User             @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([organizationId, userId])
  @@index([userId])
  @@index([organizationId])
}
```

Jalankan migration:

```bash
npx prisma migrate dev --name add_organization_tenancy
```

Penjelasan:

- `prisma migrate dev`: membuat dan menerapkan perubahan schema untuk development.
- `--name add_organization_tenancy`: nama migration agar riwayat database mudah dipahami.

Generate Prisma Client:

```bash
npx prisma generate
```

Kenapa unique constraint penting:

- `slug @unique`: URL identifier organization tidak boleh duplikat.
- `@@unique([organizationId, userId])`: user tidak boleh menjadi member dua kali di organization yang sama.
- Constraint database tetap melindungi data walaupun service punya bug.

## Domain Layer

Domain tidak import Prisma, NestJS, atau GraphQL decorator.

```ts path=backend/src/modules/organizations/domain/organization-role.enum.ts
export enum OrganizationRole {
  OWNER = 'OWNER',
  ADMIN = 'ADMIN',
  MEMBER = 'MEMBER',
}
```

```ts path=backend/src/modules/organizations/domain/organization-member.entity.ts
import { OrganizationRole } from './organization-role.enum';

export type OrganizationMemberProps = {
  id: string;
  organizationId: string;
  userId: string;
  role: OrganizationRole;
  joinedAt: Date;
};

export class OrganizationMember {
  private constructor(private readonly props: OrganizationMemberProps) {}

  static create(props: OrganizationMemberProps): OrganizationMember {
    return new OrganizationMember(props);
  }

  changeRole(role: OrganizationRole): OrganizationMember {
    this.props.role = role;
    return this;
  }

  toProps(): OrganizationMemberProps {
    return { ...this.props };
  }
}
```

```ts path=backend/src/modules/organizations/domain/organization.entity.ts
import { AppError } from '../../../common/errors/app-error';
import { Result } from '../../../common/result/result';
import { OrganizationMember } from './organization-member.entity';
import { OrganizationRole } from './organization-role.enum';

export type OrganizationProps = {
  id: string;
  name: string;
  slug: string;
  createdAt: Date;
  updatedAt: Date;
  members: OrganizationMember[];
};

export type CreateOrganizationProps = {
  id: string;
  name: string;
  slug: string;
  ownerMemberId: string;
  ownerUserId: string;
};

export class Organization {
  private constructor(private readonly props: OrganizationProps) {}

  static create(input: CreateOrganizationProps): Result<Organization> {
    const name = input.name.trim();
    const slug = input.slug.trim().toLowerCase();

    if (name.length < 3) {
      return Result.fail(AppError.validation('ORGANIZATION_NAME_TOO_SHORT', 'Organization name must be at least 3 characters.'));
    }

    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug)) {
      return Result.fail(AppError.validation('ORGANIZATION_SLUG_INVALID', 'Organization slug must be URL-friendly.'));
    }

    const now = new Date();
    const owner = OrganizationMember.create({
      id: input.ownerMemberId,
      organizationId: input.id,
      userId: input.ownerUserId,
      role: OrganizationRole.OWNER,
      joinedAt: now,
    });

    return Result.ok(
      new Organization({
        id: input.id,
        name,
        slug,
        createdAt: now,
        updatedAt: now,
        members: [owner],
      }),
    );
  }

  static fromPersistence(props: OrganizationProps): Organization {
    return new Organization(props);
  }

  addMember(member: OrganizationMember, actorRole: OrganizationRole): Result<OrganizationMember> {
    if (!this.canManageMembers(actorRole)) {
      return Result.fail(AppError.forbidden('CANNOT_MANAGE_MEMBERS', 'You cannot manage members in this organization.'));
    }

    const exists = this.props.members.some((item) => item.toProps().userId === member.toProps().userId);
    if (exists) {
      return Result.fail(AppError.conflict('MEMBER_ALREADY_EXISTS', 'User is already a member.'));
    }

    this.props.members.push(member);
    this.touch();
    return Result.ok(member);
  }

  changeMemberRole(userId: string, role: OrganizationRole, actorRole: OrganizationRole): Result<OrganizationMember> {
    if (!this.canManageMembers(actorRole)) {
      return Result.fail(AppError.forbidden('CANNOT_MANAGE_MEMBERS', 'You cannot manage members in this organization.'));
    }

    const member = this.props.members.find((item) => item.toProps().userId === userId);
    if (!member) {
      return Result.fail(AppError.notFound('MEMBER_NOT_FOUND', 'Organization member was not found.'));
    }

    if (member.toProps().role === OrganizationRole.OWNER && role !== OrganizationRole.OWNER && this.countOwners() <= 1) {
      return Result.fail(AppError.conflict('LAST_OWNER_REQUIRED', 'Organization must keep at least one owner.'));
    }

    member.changeRole(role);
    this.touch();
    return Result.ok(member);
  }

  removeMember(userId: string, actorRole: OrganizationRole): Result<boolean> {
    if (!this.canManageMembers(actorRole)) {
      return Result.fail(AppError.forbidden('CANNOT_MANAGE_MEMBERS', 'You cannot manage members in this organization.'));
    }

    const member = this.props.members.find((item) => item.toProps().userId === userId);
    if (!member) {
      return Result.fail(AppError.notFound('MEMBER_NOT_FOUND', 'Organization member was not found.'));
    }

    if (member.toProps().role === OrganizationRole.OWNER && this.countOwners() <= 1) {
      return Result.fail(AppError.conflict('LAST_OWNER_REQUIRED', 'Organization must keep at least one owner.'));
    }

    this.props.members = this.props.members.filter((item) => item.toProps().userId !== userId);
    this.touch();
    return Result.ok(true);
  }

  canManageMembers(role: OrganizationRole): boolean {
    return role === OrganizationRole.OWNER || role === OrganizationRole.ADMIN;
  }

  toProps(): OrganizationProps {
    return {
      ...this.props,
      members: [...this.props.members],
    };
  }

  private countOwners(): number {
    return this.props.members.filter((member) => member.toProps().role === OrganizationRole.OWNER).length;
  }

  private touch(): void {
    this.props.updatedAt = new Date();
  }
}
```

Business rule yang cocok di domain:

- Nama organization harus valid.
- Slug harus URL-friendly.
- OWNER/ADMIN boleh manage member.
- Member tidak boleh duplikat.
- Owner terakhir tidak boleh dihapus atau diturunkan role-nya.

## Application Layer

Repository interface:

```ts path=backend/src/modules/organizations/application/organization.repository.ts
import { Organization } from '../domain/organization.entity';
import { OrganizationMember } from '../domain/organization-member.entity';
import { OrganizationRole } from '../domain/organization-role.enum';

export const ORGANIZATION_REPOSITORY = Symbol('ORGANIZATION_REPOSITORY');

export interface OrganizationRepository {
  create(organization: Organization): Promise<Organization>;
  findById(organizationId: string): Promise<Organization | null>;
  findBySlug(slug: string): Promise<Organization | null>;
  findManyByUserId(userId: string): Promise<Organization[]>;
  findMember(organizationId: string, userId: string): Promise<OrganizationMember | null>;
  addMember(member: OrganizationMember): Promise<OrganizationMember>;
  updateMemberRole(organizationId: string, userId: string, role: OrganizationRole): Promise<OrganizationMember>;
  removeMember(organizationId: string, userId: string): Promise<void>;
  countOwners(organizationId: string): Promise<number>;
}
```

Service use case:

```ts path=backend/src/modules/organizations/application/organization.service.ts
import { Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { AppError } from '../../../common/errors/app-error';
import { Result } from '../../../common/result/result';
import { Organization } from '../domain/organization.entity';
import { OrganizationMember } from '../domain/organization-member.entity';
import { OrganizationRole } from '../domain/organization-role.enum';
import {
  ORGANIZATION_REPOSITORY,
  OrganizationRepository,
} from './organization.repository';

export type CreateOrganizationCommand = {
  currentUserId: string;
  name: string;
  slug?: string;
};

export type AddMemberCommand = {
  actorUserId: string;
  organizationId: string;
  userId: string;
  role: OrganizationRole;
};

export type ChangeMemberRoleCommand = AddMemberCommand;

@Injectable()
export class OrganizationService {
  constructor(
    @Inject(ORGANIZATION_REPOSITORY)
    private readonly organizationRepository: OrganizationRepository,
  ) {}

  async createOrganization(command: CreateOrganizationCommand): Promise<Result<Organization>> {
    const slug = command.slug?.trim() || this.slugify(command.name);
    const existing = await this.organizationRepository.findBySlug(slug);

    if (existing) {
      return Result.fail(AppError.conflict('ORGANIZATION_SLUG_ALREADY_USED', 'Organization slug is already used.'));
    }

    const organizationOrError = Organization.create({
      id: randomUUID(),
      name: command.name,
      slug,
      ownerMemberId: randomUUID(),
      ownerUserId: command.currentUserId,
    });

    if (organizationOrError.isFail()) {
      return Result.fail(organizationOrError.unwrapError());
    }

    const organization = await this.organizationRepository.create(organizationOrError.unwrap());
    return Result.ok(organization);
  }

  async getMyOrganizations(currentUserId: string): Promise<Result<Organization[]>> {
    const organizations = await this.organizationRepository.findManyByUserId(currentUserId);
    return Result.ok(organizations);
  }

  async getOrganizationDetail(currentUserId: string, organizationId: string): Promise<Result<Organization>> {
    const memberOrError = await this.ensureMember(currentUserId, organizationId);
    if (memberOrError.isFail()) {
      return Result.fail(memberOrError.unwrapError());
    }

    const organization = await this.organizationRepository.findById(organizationId);
    if (!organization) {
      return Result.fail(AppError.notFound('ORGANIZATION_NOT_FOUND', 'Organization was not found.'));
    }

    return Result.ok(organization);
  }

  async addMember(command: AddMemberCommand): Promise<Result<OrganizationMember>> {
    const canManage = await this.ensureCanManageMembers(command.actorUserId, command.organizationId);
    if (canManage.isFail()) {
      return Result.fail(canManage.unwrapError());
    }

    const organization = await this.organizationRepository.findById(command.organizationId);
    if (!organization) {
      return Result.fail(AppError.notFound('ORGANIZATION_NOT_FOUND', 'Organization was not found.'));
    }

    const member = OrganizationMember.create({
      id: randomUUID(),
      organizationId: command.organizationId,
      userId: command.userId,
      role: command.role,
      joinedAt: new Date(),
    });

    const addedOrError = organization.addMember(member, canManage.unwrap().toProps().role);
    if (addedOrError.isFail()) {
      return Result.fail(addedOrError.unwrapError());
    }

    const added = await this.organizationRepository.addMember(addedOrError.unwrap());
    return Result.ok(added);
  }

  async changeMemberRole(command: ChangeMemberRoleCommand): Promise<Result<OrganizationMember>> {
    const canManage = await this.ensureCanManageMembers(command.actorUserId, command.organizationId);
    if (canManage.isFail()) {
      return Result.fail(canManage.unwrapError());
    }

    const organization = await this.organizationRepository.findById(command.organizationId);
    if (!organization) {
      return Result.fail(AppError.notFound('ORGANIZATION_NOT_FOUND', 'Organization was not found.'));
    }

    const changedOrError = organization.changeMemberRole(command.userId, command.role, canManage.unwrap().toProps().role);
    if (changedOrError.isFail()) {
      return Result.fail(changedOrError.unwrapError());
    }

    const updated = await this.organizationRepository.updateMemberRole(command.organizationId, command.userId, command.role);
    return Result.ok(updated);
  }

  async removeMember(actorUserId: string, organizationId: string, userId: string): Promise<Result<boolean>> {
    const canManage = await this.ensureCanManageMembers(actorUserId, organizationId);
    if (canManage.isFail()) {
      return Result.fail(canManage.unwrapError());
    }

    const organization = await this.organizationRepository.findById(organizationId);
    if (!organization) {
      return Result.fail(AppError.notFound('ORGANIZATION_NOT_FOUND', 'Organization was not found.'));
    }

    const removedOrError = organization.removeMember(userId, canManage.unwrap().toProps().role);
    if (removedOrError.isFail()) {
      return Result.fail(removedOrError.unwrapError());
    }

    await this.organizationRepository.removeMember(organizationId, userId);
    return Result.ok(true);
  }

  async ensureMember(userId: string, organizationId: string): Promise<Result<OrganizationMember>> {
    const member = await this.organizationRepository.findMember(organizationId, userId);
    if (!member) {
      return Result.fail(AppError.forbidden('ORGANIZATION_MEMBER_REQUIRED', 'You are not a member of this organization.'));
    }

    return Result.ok(member);
  }

  async ensureCanManageMembers(userId: string, organizationId: string): Promise<Result<OrganizationMember>> {
    const memberOrError = await this.ensureMember(userId, organizationId);
    if (memberOrError.isFail()) {
      return Result.fail(memberOrError.unwrapError());
    }

    const role = memberOrError.unwrap().toProps().role;
    if (role !== OrganizationRole.OWNER && role !== OrganizationRole.ADMIN) {
      return Result.fail(AppError.forbidden('CANNOT_MANAGE_MEMBERS', 'You cannot manage members in this organization.'));
    }

    return memberOrError;
  }

  private slugify(value: string): string {
    return value
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
  }
}
```

Organizations cukup menyimpan `userId` dan membership. Service tidak perlu query Identity langsung untuk semua detail user. Validasi apakah user target benar-benar ada bisa ditambahkan nanti melalui contract dari Identity module atau database foreign key.

## Infrastructure Layer

Prisma repository adalah Adapter dari interface application ke database. Application layer berbicara dengan `OrganizationRepository`, sedangkan implementation menerjemahkan operasi itu ke query Prisma.

```ts path=backend/src/modules/organizations/infrastructure/prisma-organization.repository.ts
import { Injectable } from '@nestjs/common';
import { PrismaClientKnownRequestError } from '@prisma/client/runtime/library';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import { OrganizationRepository } from '../application/organization.repository';
import { Organization } from '../domain/organization.entity';
import { OrganizationMember } from '../domain/organization-member.entity';
import { OrganizationRole } from '../domain/organization-role.enum';

type OrganizationRecord = {
  id: string;
  name: string;
  slug: string;
  createdAt: Date;
  updatedAt: Date;
  members: MemberRecord[];
};

type MemberRecord = {
  id: string;
  organizationId: string;
  userId: string;
  role: string;
  joinedAt: Date;
};

@Injectable()
export class PrismaOrganizationRepository implements OrganizationRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(organization: Organization): Promise<Organization> {
    const props = organization.toProps();
    const owner = props.members[0].toProps();

    const created = await this.prisma.organization.create({
      data: {
        id: props.id,
        name: props.name,
        slug: props.slug,
        createdAt: props.createdAt,
        updatedAt: props.updatedAt,
        members: {
          create: {
            id: owner.id,
            userId: owner.userId,
            role: owner.role,
            joinedAt: owner.joinedAt,
          },
        },
      },
      include: { members: true },
    });

    return this.toDomain(created);
  }

  async findById(organizationId: string): Promise<Organization | null> {
    const organization = await this.prisma.organization.findUnique({
      where: { id: organizationId },
      include: { members: true },
    });

    return organization ? this.toDomain(organization) : null;
  }

  async findBySlug(slug: string): Promise<Organization | null> {
    const organization = await this.prisma.organization.findUnique({
      where: { slug: slug.trim().toLowerCase() },
      include: { members: true },
    });

    return organization ? this.toDomain(organization) : null;
  }

  async findManyByUserId(userId: string): Promise<Organization[]> {
    const organizations = await this.prisma.organization.findMany({
      where: {
        members: {
          some: { userId },
        },
      },
      include: { members: true },
      orderBy: { createdAt: 'desc' },
    });

    return organizations.map((organization) => this.toDomain(organization));
  }

  async findMember(organizationId: string, userId: string): Promise<OrganizationMember | null> {
    const member = await this.prisma.organizationMember.findUnique({
      where: {
        organizationId_userId: {
          organizationId,
          userId,
        },
      },
    });

    return member ? this.toMemberDomain(member) : null;
  }

  async addMember(member: OrganizationMember): Promise<OrganizationMember> {
    const props = member.toProps();

    try {
      const created = await this.prisma.organizationMember.create({
        data: {
          id: props.id,
          organizationId: props.organizationId,
          userId: props.userId,
          role: props.role,
          joinedAt: props.joinedAt,
        },
      });

      return this.toMemberDomain(created);
    } catch (error) {
      if (error instanceof PrismaClientKnownRequestError && error.code === 'P2002') {
        const existing = await this.findMember(props.organizationId, props.userId);
        if (existing) {
          return existing;
        }
      }

      throw error;
    }
  }

  async updateMemberRole(organizationId: string, userId: string, role: OrganizationRole): Promise<OrganizationMember> {
    const updated = await this.prisma.organizationMember.update({
      where: {
        organizationId_userId: {
          organizationId,
          userId,
        },
      },
      data: { role },
    });

    return this.toMemberDomain(updated);
  }

  async removeMember(organizationId: string, userId: string): Promise<void> {
    await this.prisma.organizationMember.delete({
      where: {
        organizationId_userId: {
          organizationId,
          userId,
        },
      },
    });
  }

  async countOwners(organizationId: string): Promise<number> {
    return this.prisma.organizationMember.count({
      where: {
        organizationId,
        role: OrganizationRole.OWNER,
      },
    });
  }

  private toDomain(record: OrganizationRecord): Organization {
    return Organization.fromPersistence({
      id: record.id,
      name: record.name,
      slug: record.slug,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      members: record.members.map((member) => this.toMemberDomain(member)),
    });
  }

  private toMemberDomain(record: MemberRecord): OrganizationMember {
    return OrganizationMember.create({
      id: record.id,
      organizationId: record.organizationId,
      userId: record.userId,
      role: record.role as OrganizationRole,
      joinedAt: record.joinedAt,
    });
  }
}
```

Query detail organization di service harus diawali membership check. Query list organization memakai `findManyByUserId`, sehingga user hanya melihat tenant miliknya.

## Presentation Layer - DTO/Object

```ts path=backend/src/modules/organizations/presentation/dto/create-organization.input.ts
import { Field, InputType } from '@nestjs/graphql';
import { IsOptional, IsString, Matches, MinLength } from 'class-validator';

@InputType()
export class CreateOrganizationInput {
  @Field()
  @IsString()
  @MinLength(3)
  name: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  @Matches(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
  slug?: string;
}
```

```ts path=backend/src/modules/organizations/presentation/dto/add-member.input.ts
import { Field, InputType, registerEnumType } from '@nestjs/graphql';
import { IsEnum, IsNotEmpty, IsString } from 'class-validator';
import { OrganizationRole } from '../../domain/organization-role.enum';

registerEnumType(OrganizationRole, {
  name: 'OrganizationRole',
});

@InputType()
export class AddMemberInput {
  @Field()
  @IsString()
  @IsNotEmpty()
  organizationId: string;

  @Field()
  @IsString()
  @IsNotEmpty()
  userId: string;

  @Field(() => OrganizationRole)
  @IsEnum(OrganizationRole)
  role: OrganizationRole;
}
```

```ts path=backend/src/modules/organizations/presentation/dto/change-member-role.input.ts
import { Field, InputType } from '@nestjs/graphql';
import { IsEnum, IsNotEmpty, IsString } from 'class-validator';
import { OrganizationRole } from '../../domain/organization-role.enum';

@InputType()
export class ChangeMemberRoleInput {
  @Field()
  @IsString()
  @IsNotEmpty()
  organizationId: string;

  @Field()
  @IsString()
  @IsNotEmpty()
  userId: string;

  @Field(() => OrganizationRole)
  @IsEnum(OrganizationRole)
  role: OrganizationRole;
}
```

```ts path=backend/src/modules/organizations/presentation/dto/organization-member.object.ts
import { Field, ObjectType } from '@nestjs/graphql';
import { OrganizationMember } from '../../domain/organization-member.entity';
import { OrganizationRole } from '../../domain/organization-role.enum';

@ObjectType()
export class OrganizationMemberObject {
  @Field()
  id: string;

  @Field()
  organizationId: string;

  @Field()
  userId: string;

  @Field(() => OrganizationRole)
  role: OrganizationRole;

  @Field()
  joinedAt: Date;

  static fromDomain(member: OrganizationMember): OrganizationMemberObject {
    const props = member.toProps();
    const object = new OrganizationMemberObject();

    object.id = props.id;
    object.organizationId = props.organizationId;
    object.userId = props.userId;
    object.role = props.role;
    object.joinedAt = props.joinedAt;

    return object;
  }
}
```

```ts path=backend/src/modules/organizations/presentation/dto/organization.object.ts
import { Field, ObjectType } from '@nestjs/graphql';
import { Organization } from '../../domain/organization.entity';
import { OrganizationMemberObject } from './organization-member.object';

@ObjectType()
export class OrganizationObject {
  @Field()
  id: string;

  @Field()
  name: string;

  @Field()
  slug: string;

  @Field()
  createdAt: Date;

  @Field()
  updatedAt: Date;

  @Field(() => [OrganizationMemberObject])
  members: OrganizationMemberObject[];

  static fromDomain(organization: Organization): OrganizationObject {
    const props = organization.toProps();
    const object = new OrganizationObject();

    object.id = props.id;
    object.name = props.name;
    object.slug = props.slug;
    object.createdAt = props.createdAt;
    object.updatedAt = props.updatedAt;
    object.members = props.members.map(OrganizationMemberObject.fromDomain);

    return object;
  }
}
```

`OrganizationObject` tidak mengekspos data user detail seperti email. Untuk detail user member, module Organizations sebaiknya memakai contract dari Identity atau read model khusus.

## Presentation Layer - Resolver

Semua resolver protected dengan `GqlAuthGuard`. Current user berasal dari token, bukan dari input frontend.

```ts path=backend/src/modules/organizations/presentation/organizations.resolver.ts
import { UseGuards } from '@nestjs/common';
import { Args, Mutation, Query, Resolver } from '@nestjs/graphql';
import { GraphQLError } from 'graphql';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import {
  CurrentUserPayload,
  GqlAuthGuard,
} from '../../../common/guards/gql-auth.guard';
import { OrganizationService } from '../application/organization.service';
import { AddMemberInput } from './dto/add-member.input';
import { ChangeMemberRoleInput } from './dto/change-member-role.input';
import { CreateOrganizationInput } from './dto/create-organization.input';
import { OrganizationMemberObject } from './dto/organization-member.object';
import { OrganizationObject } from './dto/organization.object';

@UseGuards(GqlAuthGuard)
@Resolver(() => OrganizationObject)
export class OrganizationsResolver {
  constructor(private readonly organizationService: OrganizationService) {}

  @Mutation(() => OrganizationObject)
  async createOrganization(
    @CurrentUser() currentUser: CurrentUserPayload,
    @Args('input') input: CreateOrganizationInput,
  ): Promise<OrganizationObject> {
    const result = await this.organizationService.createOrganization({
      currentUserId: currentUser.sub,
      name: input.name,
      slug: input.slug,
    });

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return OrganizationObject.fromDomain(result.unwrap());
  }

  @Query(() => [OrganizationObject])
  async myOrganizations(@CurrentUser() currentUser: CurrentUserPayload): Promise<OrganizationObject[]> {
    const result = await this.organizationService.getMyOrganizations(currentUser.sub);

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return result.unwrap().map(OrganizationObject.fromDomain);
  }

  @Query(() => OrganizationObject)
  async organization(
    @CurrentUser() currentUser: CurrentUserPayload,
    @Args('id') id: string,
  ): Promise<OrganizationObject> {
    const result = await this.organizationService.getOrganizationDetail(currentUser.sub, id);

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return OrganizationObject.fromDomain(result.unwrap());
  }

  @Mutation(() => OrganizationMemberObject)
  async addOrganizationMember(
    @CurrentUser() currentUser: CurrentUserPayload,
    @Args('input') input: AddMemberInput,
  ): Promise<OrganizationMemberObject> {
    const result = await this.organizationService.addMember({
      actorUserId: currentUser.sub,
      organizationId: input.organizationId,
      userId: input.userId,
      role: input.role,
    });

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return OrganizationMemberObject.fromDomain(result.unwrap());
  }

  @Mutation(() => OrganizationMemberObject)
  async changeOrganizationMemberRole(
    @CurrentUser() currentUser: CurrentUserPayload,
    @Args('input') input: ChangeMemberRoleInput,
  ): Promise<OrganizationMemberObject> {
    const result = await this.organizationService.changeMemberRole({
      actorUserId: currentUser.sub,
      organizationId: input.organizationId,
      userId: input.userId,
      role: input.role,
    });

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return OrganizationMemberObject.fromDomain(result.unwrap());
  }

  @Mutation(() => Boolean)
  async removeOrganizationMember(
    @CurrentUser() currentUser: CurrentUserPayload,
    @Args('organizationId') organizationId: string,
    @Args('userId') userId: string,
  ): Promise<boolean> {
    const result = await this.organizationService.removeMember(currentUser.sub, organizationId, userId);

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return result.unwrap();
  }

  private toGraphQLError(error: { code: string; message: string; type: string; details?: Record<string, unknown> }): GraphQLError {
    return new GraphQLError(error.message, {
      extensions: {
        code: error.code,
        type: error.type,
        details: error.details,
      },
    });
  }
}
```

Resolver hanya handle input/output dan call service. Tidak ada Prisma query atau business rule berat di resolver.

## Organizations Module

```ts path=backend/src/modules/organizations/presentation/organizations.module.ts
import { Module } from '@nestjs/common';
import { PrismaModule } from '../../../infrastructure/prisma/prisma.module';
import { ORGANIZATION_REPOSITORY } from '../application/organization.repository';
import { OrganizationService } from '../application/organization.service';
import { PrismaOrganizationRepository } from '../infrastructure/prisma-organization.repository';
import { OrganizationsResolver } from './organizations.resolver';

@Module({
  imports: [PrismaModule],
  providers: [
    OrganizationsResolver,
    OrganizationService,
    {
      provide: ORGANIZATION_REPOSITORY,
      useClass: PrismaOrganizationRepository,
    },
  ],
  exports: [OrganizationService],
})
export class OrganizationsModule {}
```

Dependency injection bekerja seperti ini:

- `OrganizationService` meminta `ORGANIZATION_REPOSITORY`.
- `OrganizationsModule` memetakan token itu ke `PrismaOrganizationRepository`.
- Resolver hanya tahu `OrganizationService`.
- Resolver tidak tahu concrete repository.
- Module mendaftarkan dependency sendiri agar boundary tetap jelas.

`OrganizationsModule` perlu export service jika module lain seperti Projects/Tasks perlu memanggil `ensureMember` atau `ensureCanManageMembers`.

## AppModule Integration

```ts path=backend/src/app.module.ts
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { GraphQLModule } from '@nestjs/graphql';
import { join } from 'path';
import { PrismaModule } from './infrastructure/prisma/prisma.module';
import { HealthModule } from './modules/health/health.module';
import { IdentityModule } from './modules/identity/presentation/identity.module';
import { OrganizationsModule } from './modules/organizations/presentation/organizations.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      autoSchemaFile: join(process.cwd(), 'src/schema.gql'),
      sortSchema: true,
      playground: process.env.NODE_ENV !== 'production',
      context: ({ req }) => ({ req }),
    }),
    PrismaModule,
    HealthModule,
    IdentityModule,
    OrganizationsModule,
  ],
})
export class AppModule {}
```

`AppModule` adalah root module. Feature module dipasang di root module, lalu resolver organization masuk GraphQL schema otomatis dari decorator `@Resolver`, `@Query`, dan `@Mutation`.

## Current User Dari GraphQL Auth Guard

Organization resolver mengambil user dari `CurrentUser` decorator:

```ts path=backend/src/modules/organizations/presentation/organizations.resolver.ts
@CurrentUser() currentUser: CurrentUserPayload
```

Aturan:

- `currentUser.sub` dipakai sebagai actor/current user id.
- Jangan percaya `userId` dari frontend sebagai current user.
- `userId` dari input hanya boleh menjadi target member yang akan ditambahkan, diubah role-nya, atau dihapus.

## Tenant Isolation Rules

Aturan utama:

- User hanya boleh melihat organization tempat dia menjadi member.
- User tidak boleh akses organization lain.
- OWNER/ADMIN boleh manage members.
- MEMBER biasa tidak boleh manage members.
- Tidak boleh remove owner terakhir.
- Project dan Task nanti wajib filter berdasarkan `organizationId`.

Contoh rule:

```txt
canViewOrganization:
  user harus menjadi member organization

canManageMembers:
  user harus OWNER atau ADMIN di organization

canCreateProject:
  user harus member organization

canViewProject:
  user harus member organization dan project.organizationId harus sama

canViewTask:
  user harus member organization dan task.project.organizationId harus sama
```

## GraphQL Query/Mutation Examples

Semua query/mutation wajib memakai header:

```json
{
  "Authorization": "Bearer YOUR_ACCESS_TOKEN"
}
```

Create organization:

```graphql
mutation {
  createOrganization(input: {
    name: "Acme Corp"
    slug: "acme-corp"
  }) {
    id
    name
    slug
  }
}
```

My organizations:

```graphql
query {
  myOrganizations {
    id
    name
    slug
  }
}
```

Detail organization:

```graphql
query {
  organization(id: "org_123") {
    id
    name
    slug
    members {
      userId
      role
    }
  }
}
```

Add member:

```graphql
mutation {
  addOrganizationMember(input: {
    organizationId: "org_123"
    userId: "user_456"
    role: MEMBER
  }) {
    userId
    role
  }
}
```

## Cara Test Di GraphQL Playground/Sandbox

1. Login dulu dari file auth.
2. Copy `accessToken`.
3. Set HTTP header:

```json
{
  "Authorization": "Bearer YOUR_ACCESS_TOKEN"
}
```

4. Jalankan `createOrganization`.
5. Jalankan `myOrganizations`.
6. Jalankan detail `organization`.
7. Jalankan `addOrganizationMember`.
8. Jalankan `changeOrganizationMemberRole`.
9. Jalankan `removeOrganizationMember`.

Jika token kosong atau invalid, resolver akan gagal di `GqlAuthGuard`.

## Seed Organization

Contoh seed idempotent:

```ts path=backend/prisma/seed.ts
import { OrganizationRole, PrismaClient, UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash('Password123!', 12);

  const admin = await prisma.user.upsert({
    where: { email: 'admin@example.com' },
    update: {
      name: 'Admin User',
      role: UserRole.ADMIN,
      passwordHash,
    },
    create: {
      email: 'admin@example.com',
      name: 'Admin User',
      role: UserRole.ADMIN,
      passwordHash,
    },
  });

  const member = await prisma.user.upsert({
    where: { email: 'member@example.com' },
    update: {
      name: 'Member User',
      role: UserRole.MEMBER,
      passwordHash,
    },
    create: {
      email: 'member@example.com',
      name: 'Member User',
      role: UserRole.MEMBER,
      passwordHash,
    },
  });

  const organization = await prisma.organization.upsert({
    where: { slug: 'acme-corp' },
    update: {
      name: 'Acme Corp',
    },
    create: {
      name: 'Acme Corp',
      slug: 'acme-corp',
    },
  });

  await prisma.organizationMember.upsert({
    where: {
      organizationId_userId: {
        organizationId: organization.id,
        userId: admin.id,
      },
    },
    update: {
      role: OrganizationRole.OWNER,
    },
    create: {
      organizationId: organization.id,
      userId: admin.id,
      role: OrganizationRole.OWNER,
    },
  });

  await prisma.organizationMember.upsert({
    where: {
      organizationId_userId: {
        organizationId: organization.id,
        userId: member.id,
      },
    },
    update: {
      role: OrganizationRole.MEMBER,
    },
    create: {
      organizationId: organization.id,
      userId: member.id,
      role: OrganizationRole.MEMBER,
    },
  });
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
```

Jalankan:

```bash
npm run db:seed
```

Penjelasan:

- `npm run db:seed` menjalankan script seed dari `package.json`.
- `upsert` membuat seed aman dijalankan ulang.
- Tidak ada duplicate user, organization, atau membership.

## Request Flow

Flow create organization:

```txt
GraphQL Client
    |
    v
OrganizationsResolver.createOrganization
    |
    v
GqlAuthGuard
    |
    v
CurrentUser
    |
    v
OrganizationService.createOrganization
    |
    v
Organization domain
    |
    v
OrganizationRepository.create
    |
    v
Prisma
    |
    v
PostgreSQL
    |
    v
OrganizationObject
```

Flow add member:

```txt
GraphQL Client
    |
    v
OrganizationsResolver.addOrganizationMember
    |
    v
OrganizationService.ensureCanManageMembers
    |
    v
OrganizationRepository.addMember
    |
    v
Prisma
    |
    v
PostgreSQL
    |
    v
OrganizationMemberObject
```

## Error Handling

Error yang perlu ditangani:

- Organization name kosong atau terlalu pendek: `ORGANIZATION_NAME_TOO_SHORT`.
- Slug sudah dipakai: `ORGANIZATION_SLUG_ALREADY_USED`.
- Organization tidak ditemukan: `ORGANIZATION_NOT_FOUND`.
- User bukan member: `ORGANIZATION_MEMBER_REQUIRED`.
- User tidak punya permission manage member: `CANNOT_MANAGE_MEMBERS`.
- Member sudah ada: `MEMBER_ALREADY_EXISTS`.
- Member tidak ditemukan: `MEMBER_NOT_FOUND`.
- Role invalid: ditangani class-validator dan GraphQL enum.
- Tidak boleh remove owner terakhir: `LAST_OWNER_REQUIRED`.
- Token kosong/invalid: ditangani `GqlAuthGuard`.

## Security Notes

- Jangan percaya `organizationId` dari frontend tanpa cek membership.
- Jangan percaya `userId` dari frontend sebagai current user.
- Jangan expose organization lain.
- Role management harus dicek di backend.
- Audit log add/remove/change member adalah improvement penting.
- Rate limiting endpoint sensitif adalah improvement penting.
- Invitation by email bisa dibuat nanti.
- Soft delete organization bisa dibuat nanti.
- Project dan Task harus selalu filter `organizationId`.

## Design Pattern Yang Relevan

Konsep pattern berikut memakai inspirasi umum dari katalog design pattern seperti Refactoring Guru, tetapi penjelasan dan contoh kode dibuat untuk stack ini.

### Repository Pattern

Masalah yang diselesaikan:

Service butuh akses organization dan membership tanpa tahu detail Prisma.

Kenapa dipakai:

Data access tenant menjadi terpusat dan query membership lebih konsisten.

File yang memakai:

- `backend/src/modules/organizations/application/organization.repository.ts`
- `backend/src/modules/organizations/infrastructure/prisma-organization.repository.ts`

Alternatif:

- Service langsung memakai Prisma. Lebih cepat, tetapi tenant filter mudah bocor.

### Adapter Pattern Melalui PrismaOrganizationRepository

Masalah yang diselesaikan:

Application layer punya interface repository, sedangkan database diakses lewat Prisma.

Kenapa dipakai:

Repository mengadaptasi Prisma Client menjadi kontrak application layer.

File yang memakai:

- `backend/src/modules/organizations/infrastructure/prisma-organization.repository.ts`

Alternatif:

- Memakai Prisma langsung di application service.

### Facade Pattern Melalui OrganizationsResolver Dan OrganizationService

Masalah yang diselesaikan:

Client GraphQL tidak perlu tahu detail rule membership.

Kenapa dipakai:

Resolver dan service menyediakan operasi sederhana seperti create organization dan add member.

File yang memakai:

- `backend/src/modules/organizations/presentation/organizations.resolver.ts`
- `backend/src/modules/organizations/application/organization.service.ts`

Alternatif:

- Banyak operasi kecil dibuka langsung ke API dan rule tersebar.

### Result Pattern

Masalah yang diselesaikan:

Business error seperti member bukan owner tidak harus menjadi exception teknis.

Kenapa dipakai:

Use case mengembalikan sukses/gagal secara eksplisit.

File yang memakai:

- `backend/src/modules/organizations/domain/organization.entity.ts`
- `backend/src/modules/organizations/application/organization.service.ts`

Alternatif:

- Throw exception untuk semua business error.

### Policy/Strategy Preview Untuk Permission Rule

Masalah yang diselesaikan:

Permission bisa bertambah kompleks saat ada project/task permission.

Kenapa dipakai nanti:

Rule seperti `canCreateProject` dan `canViewTask` bisa dipindah ke policy/strategy class.

File yang bisa memakai nanti:

- `backend/src/modules/organizations/application/`
- `backend/src/modules/projects/application/`
- `backend/src/modules/tasks/application/`

Alternatif:

- Banyak `if/else` di service.

### Module Pattern NestJS

Masalah yang diselesaikan:

Provider Organizations perlu dikelompokkan dalam satu module.

Kenapa dipakai:

NestJS module menjaga boundary dan dependency registration.

File yang memakai:

- `backend/src/modules/organizations/presentation/organizations.module.ts`

Alternatif:

- Semua provider didaftarkan di `AppModule`.

### Dependency Injection

Masalah yang diselesaikan:

Service tidak membuat repository sendiri.

Kenapa dipakai:

Implementation repository bisa diganti tanpa mengubah service.

File yang memakai:

- `backend/src/modules/organizations/application/organization.service.ts`
- `backend/src/modules/organizations/presentation/organizations.module.ts`

Alternatif:

- Membuat instance manual dengan `new PrismaOrganizationRepository()`.

## Troubleshooting

### GqlAuthGuard unauthorized

Penyebab:

- Header kosong.
- Format header bukan `Bearer <token>`.
- Token expired atau invalid.

Solusi:

- Login ulang.
- Set header Authorization di Playground/Sandbox.

### CurrentUser undefined

Penyebab:

- Guard tidak berjalan.
- GraphQL context belum membawa `req`.

Solusi:

- Pastikan resolver memakai `@UseGuards(GqlAuthGuard)`.
- Pastikan `context: ({ req }) => ({ req })` ada di `AppModule`.

### Organization tidak muncul di myOrganizations

Penyebab:

- User belum menjadi member.
- Query repository tidak filter membership dengan benar.

Solusi:

- Cek table `OrganizationMember`.
- Pastikan `findManyByUserId` memakai `members.some.userId`.

### Slug unique constraint error

Penyebab:

- Slug sudah dipakai organization lain.

Solusi:

- Cek `findBySlug` sebelum create.
- Tangani error unique constraint Prisma untuk race condition.

### User tidak bisa add member padahal owner

Penyebab:

- Current user id salah.
- Membership owner belum ada.
- Role enum tidak cocok.

Solusi:

- Cek token payload `sub`.
- Cek record `OrganizationMember`.

### Member duplicate

Penyebab:

- User sudah menjadi member.

Solusi:

- Domain check member existing.
- Database constraint `@@unique([organizationId, userId])`.

### Owner terakhir terhapus

Penyebab:

- Remove member tidak mengecek jumlah owner.

Solusi:

- Pastikan domain rule `LAST_OWNER_REQUIRED` berjalan.
- Tambahkan test untuk remove owner terakhir.

### Prisma relation error

Penyebab:

- `userId` tidak ada.
- `organizationId` tidak ada.

Solusi:

- Pastikan user dan organization ada.
- Pastikan relation schema benar.

### GraphQL enum role tidak muncul

Penyebab:

- Enum belum diregistrasi dengan `registerEnumType`.

Solusi:

- Pastikan `registerEnumType(OrganizationRole, { name: 'OrganizationRole' })` dipanggil.

### Nest cannot resolve dependency

Penyebab:

- `ORGANIZATION_REPOSITORY` belum didaftarkan.
- `PrismaModule` belum diimport.

Solusi:

- Cek `OrganizationsModule`.
- Cek provider mapping.

### Resolver tidak muncul di schema

Penyebab:

- `OrganizationsModule` belum diimport di `AppModule`.
- Resolver belum masuk `providers`.

Solusi:

- Import `OrganizationsModule` di `AppModule`.
- Tambahkan `OrganizationsResolver` ke providers.

## Checklist Berhasil

- Prisma model `Organization` dan `OrganizationMember` tersedia.
- Migration organization berhasil.
- User login bisa create organization.
- Pembuat organization otomatis menjadi `OWNER`.
- `myOrganizations` hanya menampilkan organization milik user.
- Detail organization tidak bisa diakses non-member.
- `OWNER`/`ADMIN` bisa add member.
- `MEMBER` tidak bisa manage member.
- Tidak bisa remove owner terakhir.
- `OrganizationsResolver` protected dengan `GqlAuthGuard`.
- `OrganizationsModule` terdaftar di `AppModule`.
- Tidak ada business logic berat di resolver.
- Query selalu memperhatikan membership.

## Langkah Berikutnya

Lanjutkan ke `backend/05-project-module.md` untuk menghubungkan Project dengan organization. Di sana semua query project wajib memakai `organizationId` dan membership check dari `OrganizationService`.

