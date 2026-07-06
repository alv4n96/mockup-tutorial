# 06 - RBAC, Tenant Authorization, Dan Permission Flow

## Tujuan

RBAC di tutorial ini dipakai untuk menjawab pertanyaan: user ini boleh melakukan aksi apa di organization tertentu? Pengecekan dilakukan di application layer, bukan di UI dan bukan di repository.

Flow standar:

```text
HTTP request / tRPC call
  -> Auth middleware mengambil currentUserId
  -> Controller/router menerima organizationId dan input
  -> Use case meminta role user ke Organization module
  -> Policy mengecek permission
  -> Domain menjalankan aturan bisnis
  -> Repository membaca/menulis data tenant tersebut
  -> Response envelope dikembalikan ke frontend
```

## Role Dan Permission

Role adalah label bisnis. Permission adalah aksi teknis yang dicek kode.

```ts
export const OrganizationRole = {
  OWNER: "owner",
  ADMIN: "admin",
  MEMBER: "member",
  VIEWER: "viewer",
} as const;

export type OrganizationRole =
  (typeof OrganizationRole)[keyof typeof OrganizationRole];

export const Permission = {
  TASK_READ: "task:read",
  TASK_CREATE: "task:create",
  TASK_ASSIGN: "task:assign",
  TASK_UPDATE: "task:update",
  TASK_DELETE: "task:delete",
  MEMBER_INVITE: "member:invite",
  BILLING_MANAGE: "billing:manage",
} as const;

export type Permission = (typeof Permission)[keyof typeof Permission];
```

Mapping role ke permission:

```ts
export const rolePermissions: Record<OrganizationRole, Permission[]> = {
  owner: [
    "task:read",
    "task:create",
    "task:assign",
    "task:update",
    "task:delete",
    "member:invite",
    "billing:manage",
  ],
  admin: [
    "task:read",
    "task:create",
    "task:assign",
    "task:update",
    "task:delete",
    "member:invite",
  ],
  member: ["task:read", "task:create", "task:update"],
  viewer: ["task:read"],
};

export function roleCan(role: OrganizationRole, permission: Permission): boolean {
  return rolePermissions[role].includes(permission);
}
```

## Contract Dari Organization Module

Module `Tasks` tidak boleh query tabel membership langsung. Ia harus memakai contract milik module `Organizations`.

```ts
export type OrganizationMembership = {
  organizationId: string;
  userId: string;
  role: OrganizationRole;
};

export interface OrganizationAccessReader {
  getMembership(input: {
    organizationId: string;
    userId: string;
  }): Promise<OrganizationMembership | null>;
}
```

Contoh implementasi dengan Prisma di module `Organizations`:

```ts
export class PrismaOrganizationAccessReader implements OrganizationAccessReader {
  constructor(private readonly prisma: PrismaClient) {}

  async getMembership(input: {
    organizationId: string;
    userId: string;
  }): Promise<OrganizationMembership | null> {
    const membership = await this.prisma.organizationMember.findUnique({
      where: {
        organizationId_userId: {
          organizationId: input.organizationId,
          userId: input.userId,
        },
      },
      select: {
        organizationId: true,
        userId: true,
        role: true,
      },
    });

    if (!membership) return null;

    return {
      organizationId: membership.organizationId,
      userId: membership.userId,
      role: membership.role as OrganizationRole,
    };
  }
}
```

## Policy Service

Policy service kecil dan pure. Ia tidak membaca database.

```ts
import { ForbiddenError } from "@/shared/errors/app-error";

export class OrganizationPolicy {
  static requirePermission(input: {
    membership: OrganizationMembership | null;
    permission: Permission;
  }): OrganizationMembership {
    if (!input.membership) {
      throw new ForbiddenError("You are not a member of this organization.");
    }

    if (!roleCan(input.membership.role, input.permission)) {
      throw new ForbiddenError("You do not have permission for this action.");
    }

    return input.membership;
  }
}
```

## Use Case Dengan RBAC

Use case menerima `currentUserId`, bukan role dari frontend. Role harus dibaca dari backend supaya user tidak bisa memalsukan permission.

```ts
export class CreateTaskUseCase {
  constructor(
    private readonly tasks: TaskRepository,
    private readonly organizationAccess: OrganizationAccessReader
  ) {}

  async execute(input: CreateTaskInput): Promise<Result<TaskDto>> {
    const membership = await this.organizationAccess.getMembership({
      organizationId: input.organizationId,
      userId: input.currentUserId,
    });

    try {
      OrganizationPolicy.requirePermission({
        membership,
        permission: "task:create",
      });
    } catch (error) {
      return failure(error as ForbiddenError);
    }

    if (input.assigneeUserId) {
      const canAssign = membership && roleCan(membership.role, "task:assign");
      if (!canAssign) {
        return failure(new ForbiddenError("You cannot assign tasks."));
      }
    }

    const task = Task.create({
      id: randomUUID(),
      organizationId: input.organizationId,
      projectId: input.projectId,
      title: input.title,
      description: input.description,
      assigneeUserId: input.assigneeUserId,
    });

    await this.tasks.save(task);
    return success(TaskDto.from(task));
  }
}
```

## Request Input

Frontend hanya mengirim data bisnis. Ia tidak mengirim role.

```json
{
  "projectId": "project_01",
  "title": "Membuat halaman task",
  "description": "List, create form, dan detail task",
  "assigneeUserId": "user_02"
}
```

Backend mengambil `currentUserId` dari session/JWT:

```ts
const result = await createTask.execute({
  currentUserId: ctx.user.id,
  organizationId: input.organizationId,
  projectId: input.projectId,
  title: input.title,
  description: input.description,
  assigneeUserId: input.assigneeUserId,
});
```

## Response Error RBAC

Jika user bukan member:

```json
{
  "data": null,
  "error": {
    "code": "FORBIDDEN",
    "message": "You are not a member of this organization."
  },
  "status": 403
}
```

Jika user member tapi role tidak cukup:

```json
{
  "data": null,
  "error": {
    "code": "FORBIDDEN",
    "message": "You do not have permission for this action."
  },
  "status": 403
}
```

## Database Minimal

```sql
create table organization_members (
  organization_id uuid not null,
  user_id uuid not null,
  role text not null check (role in ('owner', 'admin', 'member', 'viewer')),
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

create index idx_organization_members_user_id
  on organization_members(user_id);
```

## Aturan Implementasi

- UI boleh menyembunyikan tombol berdasarkan permission, tetapi backend tetap wajib mengecek permission.
- Role tidak boleh dikirim dari frontend sebagai sumber kebenaran.
- Repository task tetap menerima `organizationId` supaya query selalu tenant-scoped.
- Cross-module access harus lewat `OrganizationAccessReader`.
- Policy harus mudah dites tanpa database.