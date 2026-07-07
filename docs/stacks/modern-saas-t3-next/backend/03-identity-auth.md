# Backend 03 - Identity & Authentication

File ini menjelaskan cara membuat module Identity/Auth untuk backend modern SaaS task workspace di stack `modern-saas-t3-next`.

File `01-project-setup.md` sudah menyiapkan Next.js App Router, TypeScript, tRPC, Prisma, PostgreSQL, Zod, env, seed, dan health endpoint. File `02-modular-monolith-layers.md` sudah menjelaskan modular monolith dan layered architecture. File ini memakai struktur tersebut untuk module `identity`.

Identity/Auth adalah fondasi SaaS karena hampir semua fitur butuh tahu siapa user aktif, apakah request valid, dan apakah user boleh melakukan aksi tertentu. Task workspace tidak boleh menerima `userId` mentah dari frontend untuk menentukan user aktif. Backend harus membaca identity dari session/token yang valid.

Auth sebaiknya menjadi module sendiri karena:

- auth dipakai banyak module seperti organizations, projects, tasks, billing, dan audit log;
- logic login/register/current user punya aturan sendiri;
- keamanan auth harus mudah diaudit;
- perubahan provider auth tidak boleh merusak module business lain;
- tRPC context perlu satu sumber kebenaran untuk user aktif.

## Konsep Dasar

### Authentication

Authentication adalah proses membuktikan identitas user. Contoh: user memasukkan email dan password, backend memverifikasi password, lalu backend membuat session/token.

Pertanyaan authentication: user ini siapa?

### Authorization

Authorization adalah proses menentukan apakah user boleh melakukan aksi tertentu. Contoh: user sudah login, tetapi hanya `ADMIN` yang boleh mengundang member.

Pertanyaan authorization: user ini boleh melakukan apa?

File ini fokus pada authentication dan role sederhana. Authorization organization yang lebih detail akan dibahas di file berikutnya.

### User

User adalah identitas akun di sistem. Untuk awal, user punya `id`, `email`, `name`, `passwordHash`, `role`, `createdAt`, dan `updatedAt`.

Jangan menyimpan password asli. Simpan hanya hash password.

### Session

Session adalah status login user. Dalam pendekatan sederhana, setelah login berhasil backend membuat token. Token itu dikirim di request berikutnya untuk membuktikan user masih login.

Session bisa disimpan di database atau dibuat stateless dengan JWT. File ini memakai token JWT sederhana agar alur backend mudah terlihat.

### Password Hashing

Password hashing adalah proses mengubah password menjadi nilai hash satu arah. Saat login, backend membandingkan password input dengan hash yang tersimpan.

Gunakan library hashing seperti `bcryptjs` atau `bcrypt`. Jangan membuat algoritma hashing sendiri.

### JWT / Session Token

JWT atau JSON Web Token adalah token bertanda tangan yang membawa claim seperti `userId`, `email`, dan `role`. Backend bisa memverifikasi signature token untuk memastikan token valid.

Session token adalah istilah umum untuk token login. Token bisa berupa JWT atau opaque random token yang disimpan di database.

### Claim / User Context

Claim adalah data identity yang ada di token atau session. Contoh claim:

- `sub`: subject atau user id;
- `email`: email user;
- `role`: role user.

User context adalah data user aktif yang ditempel ke tRPC context agar procedure bisa tahu user yang sedang melakukan request.

### Protected Procedure Di tRPC

Protected procedure adalah procedure tRPC yang hanya bisa dipanggil user login. Jika request tidak punya token valid, backend menolak request.

Contoh use case:

- `identity.me`;
- `tasks.create`;
- `projects.list`;
- `organizations.members`.

### Public Procedure Di tRPC

Public procedure adalah procedure tRPC yang bisa dipanggil tanpa login.

Contoh use case:

- `identity.register`;
- `identity.login`;
- `health.check`.

### Role Sederhana: ADMIN Dan MEMBER

Untuk awal, gunakan dua role global sederhana:

- `ADMIN`: boleh mengakses fitur administratif dasar.
- `MEMBER`: user biasa.

Role organization yang lebih detail seperti owner/admin/member per workspace akan dibahas di file organization tenancy.

### Zod Validation

Zod dipakai untuk validasi input register, login, dan request identity. TypeScript hanya mengecek saat compile, sedangkan Zod mengecek data runtime dari request.

### Prisma Model Untuk User

Prisma model menyimpan data user di PostgreSQL. Untuk auth custom, model user perlu field `passwordHash` dan `role`.

## Pilihan Pendekatan Auth

### Custom Auth Sederhana Dengan Password Hash Dan Session Token

Pendekatan ini membuat backend auth sendiri:

1. User register dengan email, name, dan password.
2. Backend hash password.
3. Backend simpan user ke database.
4. User login dengan email dan password.
5. Backend verify password.
6. Backend membuat token.
7. Request berikutnya mengirim token.
8. tRPC context membaca token dan membuat `currentUser`.

Keunggulan:

- alur backend mudah dipahami;
- cocok untuk belajar fondasi auth;
- seluruh layer terlihat jelas.

Kekurangan:

- production auth butuh banyak detail tambahan;
- perlu handle reset password, email verification, MFA, session revoke, rate limit, dan audit log.

### NextAuth/Auth.js

NextAuth/Auth.js adalah solusi auth populer untuk Next.js. Cocok jika ingin OAuth provider, session strategy, adapter database, dan integrasi Next.js yang lebih matang.

Gunakan NextAuth/Auth.js untuk production jika ingin mengurangi risiko implementasi auth sendiri.

### JWT Stateless

JWT stateless tidak perlu lookup session database untuk setiap request. Backend cukup verify token signature. Kelemahannya, revoke token lebih sulit kecuali memakai expiry pendek atau denylist.

### Session Database

Session database menyimpan session di table. Token yang dikirim user biasanya opaque token. Backend lookup session setiap request. Keunggulannya session mudah direvoke. Kekurangannya ada query tambahan.

### Pilihan File Ini

Dokumentasi ini memakai custom auth sederhana dengan password hash dan JWT token agar alur backend terlihat jelas. NextAuth/Auth.js tetap direkomendasikan sebagai alternatif production-ready.

## Struktur Folder Identity

Gunakan struktur:

```txt
src/server/modules/identity/
├── domain/
│   ├── user.entity.ts
│   └── user-role.ts
│
├── application/
│   ├── identity.service.ts
│   ├── user.repository.ts
│   ├── password-hasher.ts
│   └── token.service.ts
│
├── infrastructure/
│   ├── prisma-user.repository.ts
│   ├── bcrypt-password-hasher.ts
│   └── jwt-token.service.ts
│
└── presentation/
    ├── identity.input.ts
    └── identity.router.ts
```

Penjelasan:

- `domain`: bentuk user dan role murni tanpa Prisma/tRPC.
- `application`: use case register, login, dan current user.
- `infrastructure`: implementasi database, hashing, dan token.
- `presentation`: Zod input schema dan tRPC router.

## Install Dependency Auth

Jalankan dari root project:

```bash
npm install bcryptjs jsonwebtoken
```

Penjelasan:

- `bcryptjs`: hash dan compare password.
- `jsonwebtoken`: membuat dan memverifikasi JWT.

Install type untuk `jsonwebtoken`:

```bash
npm install -D @types/jsonwebtoken
```

Penjelasan:

- `@types/jsonwebtoken` menyediakan TypeScript type untuk package `jsonwebtoken`.

Jika memilih `bcrypt` native, setup bisa berbeda karena package native kadang butuh build tool. Untuk dokumentasi pemula, `bcryptjs` lebih mudah.

## Environment Variable Auth

Tambahkan variable berikut ke `.env`:

```dotenv
# .env
AUTH_TOKEN_SECRET="replace-this-with-a-long-random-secret"
AUTH_TOKEN_EXPIRES_IN="7d"
```

Penjelasan:

- `AUTH_TOKEN_SECRET` dipakai untuk sign dan verify JWT.
- Gunakan secret panjang dan random untuk production.
- `AUTH_TOKEN_EXPIRES_IN` menentukan masa berlaku token.
- Jangan commit secret production.

Update env validation:

```ts
// src/env.ts
import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  NEXT_PUBLIC_APP_URL: z.string().url(),
  AUTH_TOKEN_SECRET: z.string().min(32),
  AUTH_TOKEN_EXPIRES_IN: z.string().default("7d"),
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
});

export const env = envSchema.parse({
  DATABASE_URL: process.env.DATABASE_URL,
  NEXT_PUBLIC_APP_URL: process.env.NEXT_PUBLIC_APP_URL,
  AUTH_TOKEN_SECRET: process.env.AUTH_TOKEN_SECRET,
  AUTH_TOKEN_EXPIRES_IN: process.env.AUTH_TOKEN_EXPIRES_IN,
  NODE_ENV: process.env.NODE_ENV,
});
```

Env validation membuat error konfigurasi auth ketahuan saat aplikasi start, bukan saat user mencoba login.

## Update Prisma Schema

File `01-project-setup.md` sudah membuat model `User`. Untuk auth custom, tambahkan `passwordHash`, `role`, dan enum `UserRole`.

Update bagian terkait di `prisma/schema.prisma`:

```prisma
// prisma/schema.prisma
enum UserRole {
  ADMIN
  MEMBER
}

model User {
  id           String   @id @default(cuid())
  email        String   @unique
  name         String?
  passwordHash String
  role         UserRole @default(MEMBER)
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

  organizationMembers OrganizationMember[]
  auditLogs           AuditLog[]

  @@index([role])
}
```

Penjelasan:

- `passwordHash` menyimpan hash password, bukan password asli.
- `role` menyimpan role global sederhana.
- `@@index([role])` membantu query berdasarkan role jika nanti dibutuhkan.

Jika ingin session database, tambahkan model berikut. Bagian ini opsional karena contoh utama memakai JWT stateless.

```prisma
// prisma/schema.prisma
model Session {
  id        String   @id @default(cuid())
  userId    String
  tokenHash String   @unique
  expiresAt DateTime
  createdAt DateTime @default(now())

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@index([expiresAt])
}
```

Jika menambahkan `Session`, tambahkan juga relation di model `User`:

```prisma
// prisma/schema.prisma
model User {
  id           String   @id @default(cuid())
  email        String   @unique
  name         String?
  passwordHash String
  role         UserRole @default(MEMBER)
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

  sessions            Session[]
  organizationMembers OrganizationMember[]
  auditLogs           AuditLog[]

  @@index([role])
}
```

Untuk dokumentasi utama, cukup gunakan `UserRole` dan `passwordHash`. Session database bisa dipakai nanti jika butuh revoke token yang lebih kuat.

## Migration Auth

Setelah schema diupdate, jalankan:

```bash
npx prisma migrate dev --name add_identity_auth
```

Penjelasan:

- `prisma migrate dev` membuat migration baru berdasarkan perubahan schema.
- `--name add_identity_auth` memberi nama migration agar riwayat database mudah dibaca.
- Prisma juga akan generate Prisma Client baru setelah migration berhasil.

Jika database sudah berisi data user dari seed lama tanpa `passwordHash`, migration bisa gagal karena field baru wajib diisi. Untuk project belajar, database bisa di-reset. Untuk project nyata, gunakan migration bertahap: tambah field nullable, isi data, lalu ubah menjadi required.

Untuk reset database lokal development:

```bash
npx prisma migrate reset
```

Penjelasan:

- Command ini menghapus data lokal dan menjalankan ulang semua migration.
- Gunakan hanya untuk development.
- Jangan jalankan di production.

## Domain Layer

### User Role

Buat file `src/server/modules/identity/domain/user-role.ts`:

```ts
// src/server/modules/identity/domain/user-role.ts
export const userRoles = ["ADMIN", "MEMBER"] as const;

export type UserRole = (typeof userRoles)[number];

export function isUserRole(value: string): value is UserRole {
  return userRoles.includes(value as UserRole);
}
```

File ini mendefinisikan role domain tanpa import Prisma. Nilainya sengaja sama dengan enum Prisma, tetapi domain tetap tidak bergantung pada database.

### User Entity

Buat file `src/server/modules/identity/domain/user.entity.ts`:

```ts
// src/server/modules/identity/domain/user.entity.ts
import type { UserRole } from "./user-role";

export type UserEntity = {
  id: string;
  email: string;
  name: string | null;
  passwordHash: string;
  role: UserRole;
  createdAt: Date;
  updatedAt: Date;
};

export type PublicUser = {
  id: string;
  email: string;
  name: string | null;
  role: UserRole;
};

export function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

export function toPublicUser(user: UserEntity): PublicUser {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
  };
}
```

Penjelasan:

- `UserEntity` dipakai internal backend dan masih punya `passwordHash`.
- `PublicUser` aman dikirim sebagai response karena tidak punya `passwordHash`.
- `normalizeEmail` memastikan email disimpan dalam bentuk konsisten.
- `toPublicUser` mencegah password hash bocor ke client.

## Application Layer Contracts

Application layer memakai interface agar service tidak bergantung langsung pada Prisma, bcrypt, atau JWT.

### User Repository Interface

Buat file `src/server/modules/identity/application/user.repository.ts`:

```ts
// src/server/modules/identity/application/user.repository.ts
import type { UserEntity } from "../domain/user.entity";
import type { UserRole } from "../domain/user-role";

export type CreateUserData = {
  email: string;
  name?: string | null;
  passwordHash: string;
  role?: UserRole;
};

export interface UserRepository {
  findById(id: string): Promise<UserEntity | null>;
  findByEmail(email: string): Promise<UserEntity | null>;
  create(data: CreateUserData): Promise<UserEntity>;
}
```

Service hanya mengenal `UserRepository`, bukan Prisma Client.

### Password Hasher Interface

Buat file `src/server/modules/identity/application/password-hasher.ts`:

```ts
// src/server/modules/identity/application/password-hasher.ts
export interface PasswordHasher {
  hash(password: string): Promise<string>;
  verify(password: string, passwordHash: string): Promise<boolean>;
}
```

Interface ini membuat service tidak bergantung langsung ke `bcryptjs`.

### Token Service Interface

Buat file `src/server/modules/identity/application/token.service.ts`:

```ts
// src/server/modules/identity/application/token.service.ts
import type { UserRole } from "../domain/user-role";

export type AuthTokenPayload = {
  userId: string;
  email: string;
  role: UserRole;
};

export interface TokenService {
  sign(payload: AuthTokenPayload): Promise<string>;
  verify(token: string): Promise<AuthTokenPayload | null>;
}
```

Token payload sengaja kecil. Jangan masukkan data sensitif ke JWT.

## Identity Service

Buat file `src/server/modules/identity/application/identity.service.ts`:

```ts
// src/server/modules/identity/application/identity.service.ts
import { err, ok, type AppResult } from "@/shared/result/result";
import { normalizeEmail, toPublicUser, type PublicUser } from "../domain/user.entity";
import type { PasswordHasher } from "./password-hasher";
import type { TokenService } from "./token.service";
import type { UserRepository } from "./user.repository";

export type RegisterParams = {
  email: string;
  name?: string | null;
  password: string;
};

export type LoginParams = {
  email: string;
  password: string;
};

export type AuthResponse = {
  user: PublicUser;
  token: string;
};

export class IdentityService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly passwordHasher: PasswordHasher,
    private readonly tokenService: TokenService,
  ) {}

  async register(
    params: RegisterParams,
  ): Promise<AppResult<AuthResponse, "EMAIL_ALREADY_REGISTERED">> {
    const email = normalizeEmail(params.email);
    const existingUser = await this.userRepository.findByEmail(email);

    if (existingUser) {
      return err("EMAIL_ALREADY_REGISTERED", "Email is already registered.");
    }

    const passwordHash = await this.passwordHasher.hash(params.password);

    const user = await this.userRepository.create({
      email,
      name: params.name ?? null,
      passwordHash,
      role: "MEMBER",
    });

    const token = await this.tokenService.sign({
      userId: user.id,
      email: user.email,
      role: user.role,
    });

    return ok({
      user: toPublicUser(user),
      token,
    });
  }

  async login(
    params: LoginParams,
  ): Promise<AppResult<AuthResponse, "INVALID_CREDENTIALS">> {
    const email = normalizeEmail(params.email);
    const user = await this.userRepository.findByEmail(email);

    if (!user) {
      return err("INVALID_CREDENTIALS", "Invalid email or password.");
    }

    const passwordValid = await this.passwordHasher.verify(
      params.password,
      user.passwordHash,
    );

    if (!passwordValid) {
      return err("INVALID_CREDENTIALS", "Invalid email or password.");
    }

    const token = await this.tokenService.sign({
      userId: user.id,
      email: user.email,
      role: user.role,
    });

    return ok({
      user: toPublicUser(user),
      token,
    });
  }

  async getCurrentUser(userId: string): Promise<PublicUser | null> {
    const user = await this.userRepository.findById(userId);

    if (!user) {
      return null;
    }

    return toPublicUser(user);
  }
}
```

Penjelasan:

- `register` mengecek email, hash password, simpan user, lalu buat token.
- `login` memakai pesan error generik agar tidak membocorkan apakah email terdaftar.
- `getCurrentUser` mengembalikan user aman tanpa `passwordHash`.
- Service tidak import tRPC, Prisma, bcrypt, JWT, atau Next.js.

## Infrastructure Layer

### Prisma User Repository

Buat file `src/server/modules/identity/infrastructure/prisma-user.repository.ts`:

```ts
// src/server/modules/identity/infrastructure/prisma-user.repository.ts
import type { PrismaClient } from "@prisma/client";
import type {
  CreateUserData,
  UserRepository,
} from "../application/user.repository";
import type { UserEntity } from "../domain/user.entity";
import { isUserRole } from "../domain/user-role";

function mapUser(user: {
  id: string;
  email: string;
  name: string | null;
  passwordHash: string;
  role: string;
  createdAt: Date;
  updatedAt: Date;
}): UserEntity {
  if (!isUserRole(user.role)) {
    throw new Error(`Invalid user role from database: ${user.role}`);
  }

  return {
    id: user.id,
    email: user.email,
    name: user.name,
    passwordHash: user.passwordHash,
    role: user.role,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

export class PrismaUserRepository implements UserRepository {
  constructor(private readonly db: PrismaClient) {}

  async findById(id: string): Promise<UserEntity | null> {
    const user = await this.db.user.findUnique({
      where: {
        id,
      },
    });

    return user ? mapUser(user) : null;
  }

  async findByEmail(email: string): Promise<UserEntity | null> {
    const user = await this.db.user.findUnique({
      where: {
        email,
      },
    });

    return user ? mapUser(user) : null;
  }

  async create(data: CreateUserData): Promise<UserEntity> {
    const user = await this.db.user.create({
      data: {
        email: data.email,
        name: data.name ?? null,
        passwordHash: data.passwordHash,
        role: data.role ?? "MEMBER",
      },
    });

    return mapUser(user);
  }
}
```

Repository ini adalah adapter Prisma. Application service tidak perlu tahu cara Prisma menyimpan user.

### Bcrypt Password Hasher

Buat file `src/server/modules/identity/infrastructure/bcrypt-password-hasher.ts`:

```ts
// src/server/modules/identity/infrastructure/bcrypt-password-hasher.ts
import bcrypt from "bcryptjs";
import type { PasswordHasher } from "../application/password-hasher";

const SALT_ROUNDS = 12;

export class BcryptPasswordHasher implements PasswordHasher {
  async hash(password: string): Promise<string> {
    return bcrypt.hash(password, SALT_ROUNDS);
  }

  async verify(password: string, passwordHash: string): Promise<boolean> {
    return bcrypt.compare(password, passwordHash);
  }
}
```

Penjelasan:

- `SALT_ROUNDS = 12` adalah nilai awal yang umum untuk development dan production ringan.
- Nilai lebih tinggi lebih berat untuk CPU.
- Jangan log password asli.

### JWT Token Service

Buat file `src/server/modules/identity/infrastructure/jwt-token.service.ts`:

```ts
// src/server/modules/identity/infrastructure/jwt-token.service.ts
import jwt from "jsonwebtoken";
import type { SignOptions } from "jsonwebtoken";
import { env } from "@/env";
import type {
  AuthTokenPayload,
  TokenService,
} from "../application/token.service";
import { isUserRole } from "../domain/user-role";

type JwtPayload = {
  sub: string;
  email: string;
  role: string;
};

export class JwtTokenService implements TokenService {
  async sign(payload: AuthTokenPayload): Promise<string> {
    return jwt.sign(
      {
        email: payload.email,
        role: payload.role,
      },
      env.AUTH_TOKEN_SECRET,
      {
        subject: payload.userId,
        expiresIn: env.AUTH_TOKEN_EXPIRES_IN as SignOptions["expiresIn"],
      },
    );
  }

  async verify(token: string): Promise<AuthTokenPayload | null> {
    try {
      const decoded = jwt.verify(token, env.AUTH_TOKEN_SECRET) as JwtPayload;

      if (!decoded.sub || !decoded.email || !isUserRole(decoded.role)) {
        return null;
      }

      return {
        userId: decoded.sub,
        email: decoded.email,
        role: decoded.role,
      };
    } catch {
      return null;
    }
  }
}
```

Penjelasan:

- `sub` dipakai untuk user id.
- Token menyimpan email dan role sebagai claim ringan.
- `verify` mengembalikan `null` jika token invalid atau expired.
- Jangan simpan password, secret, atau data sensitif di JWT.

## Presentation Layer

### Input Schema

Buat file `src/server/modules/identity/presentation/identity.input.ts`:

```ts
// src/server/modules/identity/presentation/identity.input.ts
import { z } from "zod";

export const registerInputSchema = z.object({
  email: z.string().email().max(255),
  name: z.string().min(1).max(120).optional(),
  password: z.string().min(8).max(128),
});

export const loginInputSchema = z.object({
  email: z.string().email().max(255),
  password: z.string().min(1).max(128),
});

export type RegisterInput = z.infer<typeof registerInputSchema>;
export type LoginInput = z.infer<typeof loginInputSchema>;
```

Penjelasan:

- Register password minimal 8 karakter.
- Login password hanya dicek tidak kosong agar error login tetap generik.
- Validasi password kuat seperti uppercase/symbol bisa ditambahkan sesuai policy produk.

### Identity Service Factory

Agar router tidak mengulang instansiasi dependency, buat factory.

Buat file `src/server/modules/identity/presentation/identity-service.factory.ts`:

```ts
// src/server/modules/identity/presentation/identity-service.factory.ts
import { db } from "@/server/db";
import { IdentityService } from "../application/identity.service";
import { BcryptPasswordHasher } from "../infrastructure/bcrypt-password-hasher";
import { JwtTokenService } from "../infrastructure/jwt-token.service";
import { PrismaUserRepository } from "../infrastructure/prisma-user.repository";

export function createIdentityService() {
  const userRepository = new PrismaUserRepository(db);
  const passwordHasher = new BcryptPasswordHasher();
  const tokenService = new JwtTokenService();

  return new IdentityService(userRepository, passwordHasher, tokenService);
}
```

Factory adalah composition kecil. Untuk awal, ini lebih sederhana daripada dependency injection container.

### Identity Router

Buat file `src/server/modules/identity/presentation/identity.router.ts`:

```ts
// src/server/modules/identity/presentation/identity.router.ts
import { TRPCError } from "@trpc/server";
import { createTRPCRouter, protectedProcedure, publicProcedure } from "@/server/api/trpc";
import { createIdentityService } from "./identity-service.factory";
import { loginInputSchema, registerInputSchema } from "./identity.input";

export const identityModuleRouter = createTRPCRouter({
  register: publicProcedure
    .input(registerInputSchema)
    .mutation(async ({ input }) => {
      const identityService = createIdentityService();
      const result = await identityService.register(input);

      if (!result.ok) {
        throw new TRPCError({
          code: "BAD_REQUEST",
          message: result.message ?? result.error,
        });
      }

      return result.value;
    }),

  login: publicProcedure.input(loginInputSchema).mutation(async ({ input }) => {
    const identityService = createIdentityService();
    const result = await identityService.login(input);

    if (!result.ok) {
      throw new TRPCError({
        code: "UNAUTHORIZED",
        message: result.message ?? result.error,
      });
    }

    return result.value;
  }),

  me: protectedProcedure.query(async ({ ctx }) => {
    const identityService = createIdentityService();
    const user = await identityService.getCurrentUser(ctx.user.id);

    if (!user) {
      throw new TRPCError({
        code: "UNAUTHORIZED",
        message: "User session is no longer valid.",
      });
    }

    return user;
  }),
});
```

Penjelasan:

- `register` dan `login` memakai `publicProcedure`.
- `me` memakai `protectedProcedure` karena harus login.
- Router tidak hash password sendiri dan tidak query Prisma langsung.
- Response register/login berisi `user` dan `token`.

## Hubungkan Identity Ke tRPC Context

Agar `protectedProcedure` bisa bekerja, context tRPC harus membaca token dari request.

Update file `src/server/api/trpc.ts`:

```ts
// src/server/api/trpc.ts
import { TRPCError, initTRPC } from "@trpc/server";
import superjson from "superjson";
import { JwtTokenService } from "@/server/modules/identity/infrastructure/jwt-token.service";
import type { PublicUser } from "@/server/modules/identity/domain/user.entity";

function getBearerToken(headers: Headers) {
  const authorization = headers.get("authorization");

  if (!authorization?.startsWith("Bearer ")) {
    return null;
  }

  return authorization.slice("Bearer ".length);
}

export const createTRPCContext = async (opts: { headers: Headers }) => {
  const token = getBearerToken(opts.headers);
  const tokenService = new JwtTokenService();
  const tokenPayload = token ? await tokenService.verify(token) : null;

  const user: PublicUser | null = tokenPayload
    ? {
        id: tokenPayload.userId,
        email: tokenPayload.email,
        name: null,
        role: tokenPayload.role,
      }
    : null;

  return {
    user,
  };
};

export type TRPCContext = Awaited<ReturnType<typeof createTRPCContext>>;

const t = initTRPC.context<TRPCContext>().create({
  transformer: superjson,
});

export const createTRPCRouter = t.router;
export const publicProcedure = t.procedure;

export const protectedProcedure = t.procedure.use(({ ctx, next }) => {
  if (!ctx.user) {
    throw new TRPCError({
      code: "UNAUTHORIZED",
      message: "Authentication is required.",
    });
  }

  return next({
    ctx: {
      ...ctx,
      user: ctx.user,
    },
  });
});
```

Penjelasan:

- Token dibaca dari header `Authorization: Bearer <token>`.
- `publicProcedure` tidak mewajibkan login.
- `protectedProcedure` menolak request tanpa user.
- Context awal hanya mengambil user dari token claim. Jika butuh memastikan user masih ada di database setiap request, panggil repository di context atau di service `me`.

## Update Route Handler tRPC

Pastikan route handler mengirim headers ke context.

Update file `src/app/api/trpc/[trpc]/route.ts`:

```ts
// src/app/api/trpc/[trpc]/route.ts
import { fetchRequestHandler } from "@trpc/server/adapters/fetch";
import { appRouter } from "@/server/api/root";
import { createTRPCContext } from "@/server/api/trpc";

const handler = (request: Request) =>
  fetchRequestHandler({
    endpoint: "/api/trpc",
    req: request,
    router: appRouter,
    createContext: () =>
      createTRPCContext({
        headers: request.headers,
      }),
  });

export { handler as GET, handler as POST };
```

Route handler tetap tipis. Ia hanya meneruskan request dan headers ke tRPC.

## Expose Identity Router Ke App Router

Buat file `src/server/api/routers/identity.router.ts`:

```ts
// src/server/api/routers/identity.router.ts
export { identityModuleRouter as identityRouter } from "@/server/modules/identity/presentation/identity.router";
```

Update root router:

```ts
// src/server/api/root.ts
import { createTRPCRouter } from "@/server/api/trpc";
import { healthRouter } from "@/server/api/routers/health";
import { identityRouter } from "@/server/api/routers/identity.router";

export const appRouter = createTRPCRouter({
  health: healthRouter,
  identity: identityRouter,
});

export type AppRouter = typeof appRouter;
```

Jika file `02-modular-monolith-layers.md` sudah menambahkan `tasksRouter`, root router menjadi:

```ts
// src/server/api/root.ts
import { createTRPCRouter } from "@/server/api/trpc";
import { healthRouter } from "@/server/api/routers/health";
import { identityRouter } from "@/server/api/routers/identity.router";
import { tasksRouter } from "@/server/api/routers/tasks.router";

export const appRouter = createTRPCRouter({
  health: healthRouter,
  identity: identityRouter,
  tasks: tasksRouter,
});

export type AppRouter = typeof appRouter;
```

Root router tetap menjadi facade API utama. Detail identity tetap berada di module `identity`.

## Cara Test Secara Konsep

Jalankan development server:

```bash
npm run dev
```

Penjelasan:

- `npm run dev` menjalankan Next.js development server.
- Default URL adalah `http://localhost:3000`.

Register user lewat tRPC client atau tool HTTP yang mendukung request POST ke endpoint tRPC.

Secara konsep, procedure yang dipanggil:

```txt
identity.register
```

Input:

```json
{
  "email": "owner@example.com",
  "name": "Owner Example",
  "password": "password123"
}
```

Expected response secara konsep:

```json
{
  "user": {
    "id": "user_id",
    "email": "owner@example.com",
    "name": "Owner Example",
    "role": "MEMBER"
  },
  "token": "jwt_token"
}
```

Login:

```txt
identity.login
```

Input:

```json
{
  "email": "owner@example.com",
  "password": "password123"
}
```

Untuk request protected, kirim header:

```txt
Authorization: Bearer jwt_token
```

Lalu panggil:

```txt
identity.me
```

Expected response:

```json
{
  "id": "user_id",
  "email": "owner@example.com",
  "name": "Owner Example",
  "role": "MEMBER"
}
```

## Request Flow Identity

Flow register:

```txt
Client
  |
  v
identity.register tRPC procedure
  |
  v
registerInputSchema Zod validation
  |
  v
IdentityService.register
  |
  v
UserRepository.findByEmail
  |
  v
PasswordHasher.hash
  |
  v
UserRepository.create
  |
  v
TokenService.sign
  |
  v
response { user, token }
```

Flow protected request:

```txt
Client sends Authorization header
  |
  v
src/app/api/trpc/[trpc]/route.ts
  |
  v
createTRPCContext reads Bearer token
  |
  v
JwtTokenService.verify
  |
  v
ctx.user available
  |
  v
protectedProcedure allows request
  |
  v
procedure calls service
```

## Public vs Protected Procedure

Gunakan `publicProcedure` untuk endpoint yang memang boleh dipanggil tanpa login:

- register;
- login;
- health check;
- callback provider auth jika memakai Auth.js.

Gunakan `protectedProcedure` untuk endpoint yang membutuhkan user aktif:

- `identity.me`;
- create/list project;
- create/update task;
- organization settings;
- billing action.

Jangan menerima `userId` dari input frontend untuk operasi yang harus memakai user aktif. Ambil user dari `ctx.user`.

Contoh buruk:

```ts
// src/server/modules/tasks/presentation/bad-task.router.ts
create: protectedProcedure
  .input(z.object({ userId: z.string(), title: z.string() }))
  .mutation(async ({ input }) => {
    return createTaskForUser(input.userId, input.title);
  });
```

Masalahnya: user bisa mengirim `userId` milik orang lain.

Contoh lebih aman:

```ts
// src/server/modules/tasks/presentation/good-task.router.ts
create: protectedProcedure
  .input(z.object({ title: z.string() }))
  .mutation(async ({ ctx, input }) => {
    return createTaskForUser(ctx.user.id, input.title);
  });
```

User aktif selalu berasal dari context yang sudah diverifikasi.

## Role ADMIN Dan MEMBER

Untuk awal, role global cukup sederhana:

```ts
// src/server/modules/identity/domain/user-role.ts
export const userRoles = ["ADMIN", "MEMBER"] as const;
export type UserRole = (typeof userRoles)[number];
```

Contoh helper role sederhana:

```ts
// src/server/modules/identity/application/role-policy.ts
import type { UserRole } from "../domain/user-role";

export function canAccessAdminFeature(role: UserRole) {
  return role === "ADMIN";
}
```

Contoh pemakaian di router:

```ts
// src/server/modules/identity/presentation/admin.router.ts
import { TRPCError } from "@trpc/server";
import { createTRPCRouter, protectedProcedure } from "@/server/api/trpc";
import { canAccessAdminFeature } from "../application/role-policy";

export const adminRouter = createTRPCRouter({
  stats: protectedProcedure.query(({ ctx }) => {
    if (!canAccessAdminFeature(ctx.user.role)) {
      throw new TRPCError({
        code: "FORBIDDEN",
        message: "Admin access is required.",
      });
    }

    return {
      status: "ok",
    };
  }),
});
```

Catatan: role global ini hanya preview. Untuk SaaS multi-tenant, authorization biasanya memakai membership role per organization, bukan hanya role global user.

## Seed User Dengan Password

Jika seed dari file `01-project-setup.md` masih membuat user tanpa password, update seed agar memakai password hash.

Contoh seed minimal:

```ts
// prisma/seed.ts
import bcrypt from "bcryptjs";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash("password123", 12);

  await prisma.user.upsert({
    where: {
      email: "owner@example.com",
    },
    update: {
      name: "Owner Example",
      passwordHash,
      role: "ADMIN",
    },
    create: {
      email: "owner@example.com",
      name: "Owner Example",
      passwordHash,
      role: "ADMIN",
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
- Password contoh hanya untuk development.
- Jangan gunakan password contoh untuk production.

## Security Notes

- Jangan simpan password asli.
- Jangan log password, token, atau `AUTH_TOKEN_SECRET`.
- Gunakan secret panjang dan random untuk JWT.
- Gunakan HTTPS di production.
- Token di local storage rawan XSS. Untuk production, pertimbangkan httpOnly cookie.
- JWT stateless sulit direvoke sebelum expired. Gunakan expiry pendek atau session database jika butuh revoke.
- Login perlu rate limiting agar tidak mudah brute force.
- Register sebaiknya punya email verification untuk production.
- Reset password tidak dibahas di file ini.
- OAuth dan provider external lebih baik memakai Auth.js jika ingin production-ready lebih cepat.
- Authorization organization-level akan dibahas di file berikutnya.

## Troubleshooting

### `AUTH_TOKEN_SECRET` Tidak Valid

Jika app gagal start karena env validation, pastikan `.env` punya secret minimal 32 karakter:

```dotenv
# .env
AUTH_TOKEN_SECRET="replace-this-with-a-long-random-secret"
AUTH_TOKEN_EXPIRES_IN="7d"
```

Restart dev server setelah mengubah `.env`.

### Login Selalu `INVALID_CREDENTIALS`

Cek hal berikut:

- email dinormalisasi ke lowercase;
- user ada di database;
- `passwordHash` terisi;
- seed memakai hash bcrypt, bukan password plain text;
- password input sama dengan password seed.

### `protectedProcedure` Selalu `UNAUTHORIZED`

Cek hal berikut:

- request mengirim header `Authorization: Bearer <token>`;
- token belum expired;
- `AUTH_TOKEN_SECRET` sama dengan secret saat token dibuat;
- route handler meneruskan `request.headers` ke `createTRPCContext`.

### Prisma Error Karena `passwordHash` Required

Jika database lama punya user tanpa `passwordHash`, migration bisa gagal. Untuk development, jalankan:

```bash
npx prisma migrate reset
```

Penjelasan:

- Reset menghapus data lokal.
- Aman untuk development jika data tidak penting.
- Jangan gunakan di production.

### TypeScript Error Pada `jsonwebtoken`

Pastikan type package sudah diinstall:

```bash
npm install -D @types/jsonwebtoken
```

### Password Hashing Lambat

`SALT_ROUNDS` terlalu tinggi bisa membuat register/login lambat. Mulai dari `12`, ukur performa, lalu sesuaikan.

## Output Akhir File Ini

Setelah mengikuti file ini, pembaca harus memahami:

- perbedaan authentication dan authorization;
- konsep user, session, token, claim, dan user context;
- public procedure dan protected procedure di tRPC;
- struktur module `identity` dengan layer domain, application, infrastructure, dan presentation;
- cara membuat register, login, dan current user;
- cara hash password dengan bcrypt;
- cara sign dan verify JWT;
- cara menempelkan user aktif ke tRPC context;
- batasan custom auth sederhana;
- kapan mempertimbangkan NextAuth/Auth.js.

## Checklist Berhasil

- [ ] Dependency auth terinstall.
- [ ] Env `AUTH_TOKEN_SECRET` dan `AUTH_TOKEN_EXPIRES_IN` siap.
- [ ] Prisma `User` punya `passwordHash` dan `role`.
- [ ] Migration auth berhasil.
- [ ] Domain `UserEntity` dan `UserRole` siap.
- [ ] Interface `UserRepository`, `PasswordHasher`, dan `TokenService` siap.
- [ ] Prisma repository siap.
- [ ] Bcrypt password hasher siap.
- [ ] JWT token service siap.
- [ ] Zod input register/login siap.
- [ ] Identity router punya `register`, `login`, dan `me`.
- [ ] tRPC context membaca token.
- [ ] `protectedProcedure` menolak request tanpa token valid.
- [ ] Root router mengekspos `identity`.
- [ ] Siap lanjut ke `04-organization-tenancy.md`.
