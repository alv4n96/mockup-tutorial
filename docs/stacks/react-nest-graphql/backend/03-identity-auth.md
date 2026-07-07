# Backend 03 - Identity & Authentication

Dokumen ini melanjutkan `backend/02-modular-monolith-layers.md`. Di file sebelumnya, kita membahas Modular Monolith, Layered Architecture, dan contoh module Projects. Sekarang kita membuat module Identity/Auth untuk backend NestJS + GraphQL + Prisma + PostgreSQL.

Dalam SaaS Task Workspace, Identity/Auth adalah fondasi. Sebelum user membuat organization, project, atau task, aplikasi harus tahu siapa user tersebut, apakah kredensialnya valid, dan data apa yang boleh dia akses.

Auth sebaiknya menjadi module sendiri karena:

- Register, login, hashing password, JWT, dan current user adalah domain yang jelas.
- Resolver lain seperti Projects dan Tasks cukup memakai guard/current user, bukan mengulang logic login.
- Implementasi teknis seperti bcrypt dan JWT bisa dibungkus di infrastructure layer.
- Security rule lebih mudah diaudit jika tidak tersebar di semua module.

Dokumen ini memakai aturan layer dari `02-modular-monolith-layers.md`:

```txt
GraphQL Resolver -> IdentityService -> UserRepository interface -> PrismaUserRepository -> PrismaService -> PostgreSQL
```

## Konsep Dasar Identity/Auth

Authentication adalah proses membuktikan identitas user. Contoh: user mengirim email dan password, lalu backend memeriksa apakah kombinasi itu benar.

Authorization adalah proses menentukan apakah user yang sudah login boleh melakukan aksi tertentu. Contoh: hanya `ADMIN` yang boleh membuka halaman admin. Authorization dasar akan dikenalkan di file ini melalui role global `ADMIN` dan `MEMBER`, tetapi permission tenant detail akan dibahas di file organization.

User adalah akun yang bisa login ke aplikasi. User punya email, nama, password hash, role, dan timestamp.

Role adalah label sederhana untuk membedakan hak akses. Di file ini role global hanya:

- `ADMIN`: role global untuk admin aplikasi.
- `MEMBER`: user biasa.

Password hashing adalah proses mengubah password asli menjadi string hash yang tidak bisa dikembalikan ke password asli. Database menyimpan `passwordHash`, bukan password plain text.

JWT access token adalah token bertanda tangan yang diberikan setelah register/login sukses. Client mengirim token ini pada request berikutnya.

Claims atau payload token adalah data di dalam JWT, misalnya:

```json
{
  "sub": "user_id",
  "email": "admin@example.com",
  "role": "ADMIN"
}
```

GraphQL Resolver adalah presentation layer untuk query dan mutation. Auth module akan punya mutation `register`, mutation `login`, dan query `me`.

Mutation login/register adalah operasi GraphQL untuk membuat akun dan mengambil token.

Query `me` atau current user adalah operasi GraphQL untuk mengambil user yang sedang login berdasarkan token.

Guard adalah komponen NestJS yang memutuskan apakah sebuah resolver boleh dijalankan. Untuk `me`, guard akan membaca JWT dari header.

Decorator current user adalah helper agar resolver bisa mengambil user payload dari GraphQL context dengan rapi.

Public resolver adalah resolver yang bisa dipanggil tanpa token, seperti `register` dan `login`.

Protected resolver adalah resolver yang wajib memakai token valid, seperti `me`.

## Scope Fitur

Fitur yang dibuat:

- Register user.
- Login user.
- Query current user `me`.
- Password hashing dengan `bcryptjs`.
- JWT generation.
- JWT verification.
- GraphQL auth guard.
- Current user decorator.
- Role sederhana: `ADMIN` dan `MEMBER`.
- Validation input.
- Error handling.
- Result pattern.
- Prisma repository.

Yang belum dibahas detail:

- Organization membership.
- Tenant role.
- Permission per project/task.
- Refresh token.
- Email verification.
- Rate limiting.

## Struktur Folder Identity

Struktur module:

```txt
backend/src/modules/identity/
├── domain/
│   ├── user.entity.ts
│   └── user-role.enum.ts
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
    ├── dto/
    │   ├── register.input.ts
    │   ├── login.input.ts
    │   ├── auth-payload.object.ts
    │   └── user.object.ts
    ├── identity.resolver.ts
    └── identity.module.ts
```

Common auth helper:

```txt
backend/src/common/
├── decorators/
│   └── current-user.decorator.ts
└── guards/
    └── gql-auth.guard.ts
```

Fungsi file:

- `user-role.enum.ts`: enum role global user.
- `user.entity.ts`: entity domain user tanpa dependency Prisma/NestJS/GraphQL.
- `user.repository.ts`: kontrak data access user.
- `password-hasher.ts`: kontrak hashing password.
- `token.service.ts`: kontrak sign/verify token.
- `identity.service.ts`: use case register, login, dan get current user.
- `prisma-user.repository.ts`: implementasi repository memakai Prisma.
- `bcrypt-password-hasher.ts`: implementasi hashing memakai bcryptjs.
- `jwt-token.service.ts`: implementasi JWT memakai NestJS JwtService.
- `register.input.ts`: input GraphQL register.
- `login.input.ts`: input GraphQL login.
- `auth-payload.object.ts`: response GraphQL berisi token dan user.
- `user.object.ts`: response GraphQL user tanpa `passwordHash`.
- `identity.resolver.ts`: mutation/query auth.
- `identity.module.ts`: registrasi provider module Identity.
- `current-user.decorator.ts`: mengambil user payload dari context.
- `gql-auth.guard.ts`: membaca dan memverifikasi token dari GraphQL context.

## Install Dependency Auth

Jalankan dari folder `backend`:

```bash
npm install @nestjs/jwt @nestjs/passport passport passport-jwt bcryptjs
```

Penjelasan:

- `@nestjs/jwt`: wrapper NestJS untuk membuat dan memverifikasi JWT.
- `@nestjs/passport`: integrasi Passport dengan NestJS, berguna jika nanti memakai strategy Passport.
- `passport`: library authentication middleware.
- `passport-jwt`: strategy Passport untuk JWT.
- `bcryptjs`: library hashing password berbasis JavaScript.

Install type package:

```bash
npm install -D @types/passport-jwt @types/bcryptjs
```

Penjelasan:

- `-D`: dependency hanya untuk development.
- `@types/passport-jwt`: type TypeScript untuk passport-jwt.
- `@types/bcryptjs`: type TypeScript untuk bcryptjs jika diperlukan oleh versi package yang dipakai.

Catatan: guard di dokumen ini dibuat manual untuk GraphQL context. Package Passport tetap disiapkan karena umum dipakai di aplikasi NestJS dan bisa dipakai untuk pengembangan auth berikutnya.

## Environment Variable

Update file `.env`:

```dotenv path=backend/.env
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/react_nest_graphql?schema=public"
JWT_SECRET="change-this-local-secret-minimum-32-characters"
JWT_EXPIRES_IN="7d"
```

Penjelasan:

- `JWT_SECRET` dipakai backend untuk menandatangani dan memverifikasi token.
- `JWT_EXPIRES_IN` menentukan masa berlaku token.
- `JWT_SECRET` jangan dipakai di frontend.
- `JWT_SECRET` production tidak boleh dicommit.
- Untuk local learning, `.env` lokal boleh dipakai.
- Untuk production, gunakan secret manager seperti Kubernetes Secret, AWS Secrets Manager, GCP Secret Manager, Azure Key Vault, Doppler, atau Vault.

## Prisma Schema Identity

Update bagian identity pada `schema.prisma`:

```prisma path=backend/prisma/schema.prisma
enum UserRole {
  ADMIN
  MEMBER
}

model User {
  id           String   @id @default(cuid())
  email        String   @unique
  name         String
  passwordHash String
  role         UserRole @default(MEMBER)
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
}
```

Jalankan migration:

```bash
npx prisma migrate dev --name add_identity_auth
```

Penjelasan:

- `npx`: menjalankan binary dari dependency project.
- `prisma migrate dev`: membuat dan menerapkan migration untuk development.
- `--name add_identity_auth`: nama migration agar riwayat database mudah dibaca.

Generate Prisma Client:

```bash
npx prisma generate
```

Penjelasan:

- Prisma Client harus digenerate ulang setelah schema berubah.
- TypeScript akan mengenali model dan enum terbaru.

Kenapa email harus unique:

- Email dipakai sebagai login identifier.
- Dua user dengan email sama membuat login ambigu.
- Constraint unique menjaga data di level database.

Kenapa menyimpan `passwordHash`, bukan password asli:

- Jika database bocor, password asli user tidak langsung terbaca.
- Hash satu arah lebih aman.
- Backend cukup membandingkan password input dengan hash.

Kenapa role global berbeda dari organization role nanti:

- Role global berlaku di level aplikasi, misalnya `ADMIN`.
- Organization role berlaku di tenant tertentu, misalnya owner/admin/member dalam organization.
- User bisa `MEMBER` secara global, tetapi `OWNER` di organization tertentu.

## Domain Layer

Domain layer tidak import Prisma, NestJS, atau GraphQL decorator.

```ts path=backend/src/modules/identity/domain/user-role.enum.ts
export enum UserRole {
  ADMIN = 'ADMIN',
  MEMBER = 'MEMBER',
}
```

```ts path=backend/src/modules/identity/domain/user.entity.ts
import { AppError } from '../../../common/errors/app-error';
import { Result } from '../../../common/result/result';
import { UserRole } from './user-role.enum';

export type UserProps = {
  id: string;
  email: string;
  name: string;
  passwordHash: string;
  role: UserRole;
  createdAt: Date;
  updatedAt: Date;
};

export type CreateUserProps = {
  id: string;
  email: string;
  name: string;
  passwordHash: string;
  role?: UserRole;
};

export type UpdateUserProfileProps = {
  name?: string;
};

export class User {
  private constructor(private readonly props: UserProps) {}

  static create(input: CreateUserProps): Result<User> {
    const email = input.email.trim().toLowerCase();
    const name = input.name.trim();

    if (!email) {
      return Result.fail(AppError.validation('EMAIL_REQUIRED', 'Email is required.'));
    }

    if (!name || name.length < 3) {
      return Result.fail(AppError.validation('NAME_TOO_SHORT', 'Name must be at least 3 characters.'));
    }

    if (!input.passwordHash) {
      return Result.fail(AppError.validation('PASSWORD_HASH_REQUIRED', 'Password hash is required.'));
    }

    const now = new Date();

    return Result.ok(
      new User({
        id: input.id,
        email,
        name,
        passwordHash: input.passwordHash,
        role: input.role ?? UserRole.MEMBER,
        createdAt: now,
        updatedAt: now,
      }),
    );
  }

  static fromPersistence(props: UserProps): User {
    return new User({
      ...props,
      email: props.email.toLowerCase(),
    });
  }

  updateProfile(input: UpdateUserProfileProps): Result<User> {
    if (input.name !== undefined) {
      const name = input.name.trim();

      if (!name || name.length < 3) {
        return Result.fail(AppError.validation('NAME_TOO_SHORT', 'Name must be at least 3 characters.'));
      }

      this.props.name = name;
    }

    this.props.updatedAt = new Date();
    return Result.ok(this);
  }

  toProps(): UserProps {
    return { ...this.props };
  }

  toSafeProps(): Omit<UserProps, 'passwordHash'> {
    const { passwordHash, ...safeProps } = this.props;
    return safeProps;
  }
}
```

Catatan:

- `passwordHash` boleh ada di entity karena dibutuhkan untuk login.
- `passwordHash` tidak boleh keluar ke GraphQL response.
- Method `toSafeProps()` membantu mapping response tanpa password hash.

## Application Layer

Application layer berisi interface dan use case. `IdentityService` tidak tahu detail Prisma, bcrypt, atau library JWT.

```ts path=backend/src/modules/identity/application/user.repository.ts
import { User } from '../domain/user.entity';

export const USER_REPOSITORY = Symbol('USER_REPOSITORY');

export interface UserRepository {
  create(user: User): Promise<User>;
  findById(userId: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  update(user: User): Promise<User>;
}
```

```ts path=backend/src/modules/identity/application/password-hasher.ts
export const PASSWORD_HASHER = Symbol('PASSWORD_HASHER');

export interface PasswordHasher {
  hash(plainTextPassword: string): Promise<string>;
  compare(plainTextPassword: string, passwordHash: string): Promise<boolean>;
}
```

```ts path=backend/src/modules/identity/application/token.service.ts
import { UserRole } from '../domain/user-role.enum';

export type AuthTokenPayload = {
  sub: string;
  email: string;
  role: UserRole;
};

export const TOKEN_SERVICE = Symbol('TOKEN_SERVICE');

export interface TokenService {
  sign(payload: AuthTokenPayload): Promise<string>;
  verify(token: string): Promise<AuthTokenPayload>;
}
```

```ts path=backend/src/modules/identity/application/identity.service.ts
import { Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { AppError } from '../../../common/errors/app-error';
import { Result } from '../../../common/result/result';
import { User } from '../domain/user.entity';
import {
  PASSWORD_HASHER,
  PasswordHasher,
} from './password-hasher';
import {
  TOKEN_SERVICE,
  TokenService,
} from './token.service';
import {
  USER_REPOSITORY,
  UserRepository,
} from './user.repository';

export type AuthResult = {
  accessToken: string;
  user: User;
};

export type RegisterCommand = {
  email: string;
  name: string;
  password: string;
};

export type LoginCommand = {
  email: string;
  password: string;
};

@Injectable()
export class IdentityService {
  constructor(
    @Inject(USER_REPOSITORY)
    private readonly userRepository: UserRepository,
    @Inject(PASSWORD_HASHER)
    private readonly passwordHasher: PasswordHasher,
    @Inject(TOKEN_SERVICE)
    private readonly tokenService: TokenService,
  ) {}

  async register(command: RegisterCommand): Promise<Result<AuthResult>> {
    const email = command.email.trim().toLowerCase();

    const existingUser = await this.userRepository.findByEmail(email);
    if (existingUser) {
      return Result.fail(AppError.conflict('EMAIL_ALREADY_USED', 'Email is already used.'));
    }

    if (command.password.length < 8) {
      return Result.fail(AppError.validation('PASSWORD_TOO_SHORT', 'Password must be at least 8 characters.'));
    }

    const passwordHash = await this.passwordHasher.hash(command.password);

    const userOrError = User.create({
      id: randomUUID(),
      email,
      name: command.name,
      passwordHash,
    });

    if (userOrError.isFail()) {
      return Result.fail(userOrError.unwrapError());
    }

    const user = await this.userRepository.create(userOrError.unwrap());
    const accessToken = await this.tokenService.sign({
      sub: user.toProps().id,
      email: user.toProps().email,
      role: user.toProps().role,
    });

    return Result.ok({ accessToken, user });
  }

  async login(command: LoginCommand): Promise<Result<AuthResult>> {
    const email = command.email.trim().toLowerCase();
    const user = await this.userRepository.findByEmail(email);

    if (!user) {
      return Result.fail(AppError.unauthorized('INVALID_CREDENTIALS', 'Email or password is incorrect.'));
    }

    const isPasswordValid = await this.passwordHasher.compare(
      command.password,
      user.toProps().passwordHash,
    );

    if (!isPasswordValid) {
      return Result.fail(AppError.unauthorized('INVALID_CREDENTIALS', 'Email or password is incorrect.'));
    }

    const accessToken = await this.tokenService.sign({
      sub: user.toProps().id,
      email: user.toProps().email,
      role: user.toProps().role,
    });

    return Result.ok({ accessToken, user });
  }

  async getCurrentUser(userId: string): Promise<Result<User>> {
    const user = await this.userRepository.findById(userId);

    if (!user) {
      return Result.fail(AppError.notFound('USER_NOT_FOUND', 'User was not found.'));
    }

    return Result.ok(user);
  }
}
```

Ketentuan yang dijaga:

- Email dicek unique sebelum create.
- Password plain text tidak disimpan.
- Service return `Result`.
- Service memakai interface, bukan implementasi teknis.
- Password hash tidak pernah menjadi output resolver.

## Infrastructure Layer

Implementation teknis masuk infrastructure karena bergantung pada library dan framework eksternal: Prisma, bcryptjs, JWT, dan ConfigService.

```ts path=backend/src/modules/identity/infrastructure/prisma-user.repository.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import { UserRepository } from '../application/user.repository';
import { User, UserProps } from '../domain/user.entity';
import { UserRole } from '../domain/user-role.enum';

type PrismaUserRecord = {
  id: string;
  email: string;
  name: string;
  passwordHash: string;
  role: string;
  createdAt: Date;
  updatedAt: Date;
};

@Injectable()
export class PrismaUserRepository implements UserRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(user: User): Promise<User> {
    const props = user.toProps();

    const created = await this.prisma.user.create({
      data: {
        id: props.id,
        email: props.email,
        name: props.name,
        passwordHash: props.passwordHash,
        role: props.role,
        createdAt: props.createdAt,
        updatedAt: props.updatedAt,
      },
    });

    return this.toDomain(created);
  }

  async findById(userId: string): Promise<User | null> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    return user ? this.toDomain(user) : null;
  }

  async findByEmail(email: string): Promise<User | null> {
    const user = await this.prisma.user.findUnique({
      where: { email: email.trim().toLowerCase() },
    });

    return user ? this.toDomain(user) : null;
  }

  async update(user: User): Promise<User> {
    const props = user.toProps();

    const updated = await this.prisma.user.update({
      where: { id: props.id },
      data: {
        name: props.name,
        passwordHash: props.passwordHash,
        role: props.role,
        updatedAt: props.updatedAt,
      },
    });

    return this.toDomain(updated);
  }

  private toDomain(record: PrismaUserRecord): User {
    const props: UserProps = {
      id: record.id,
      email: record.email,
      name: record.name,
      passwordHash: record.passwordHash,
      role: record.role as UserRole,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };

    return User.fromPersistence(props);
  }
}
```

```ts path=backend/src/modules/identity/infrastructure/bcrypt-password-hasher.ts
import { Injectable } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { PasswordHasher } from '../application/password-hasher';

@Injectable()
export class BcryptPasswordHasher implements PasswordHasher {
  private readonly saltRounds = 12;

  async hash(plainTextPassword: string): Promise<string> {
    return bcrypt.hash(plainTextPassword, this.saltRounds);
  }

  async compare(plainTextPassword: string, passwordHash: string): Promise<boolean> {
    return bcrypt.compare(plainTextPassword, passwordHash);
  }
}
```

```ts path=backend/src/modules/identity/infrastructure/jwt-token.service.ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  AuthTokenPayload,
  TokenService,
} from '../application/token.service';

@Injectable()
export class JwtTokenService implements TokenService {
  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async sign(payload: AuthTokenPayload): Promise<string> {
    const secret = this.getSecret();
    const expiresIn = this.configService.get<string>('JWT_EXPIRES_IN') ?? '7d';

    return this.jwtService.signAsync(payload, {
      secret,
      expiresIn,
    });
  }

  async verify(token: string): Promise<AuthTokenPayload> {
    try {
      const secret = this.getSecret();
      return await this.jwtService.verifyAsync<AuthTokenPayload>(token, {
        secret,
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired token.');
    }
  }

  private getSecret(): string {
    const secret = this.configService.get<string>('JWT_SECRET');

    if (!secret) {
      throw new Error('JWT_SECRET is not configured.');
    }

    return secret;
  }
}
```

## Presentation Layer - DTO/Object

DTO dan object GraphQL memakai decorator NestJS GraphQL dan class-validator.

```ts path=backend/src/modules/identity/presentation/dto/register.input.ts
import { Field, InputType } from '@nestjs/graphql';
import { IsEmail, IsNotEmpty, IsString, MinLength } from 'class-validator';

@InputType()
export class RegisterInput {
  @Field()
  @IsEmail()
  email: string;

  @Field()
  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  name: string;

  @Field()
  @IsString()
  @MinLength(8)
  password: string;
}
```

```ts path=backend/src/modules/identity/presentation/dto/login.input.ts
import { Field, InputType } from '@nestjs/graphql';
import { IsEmail, IsString, MinLength } from 'class-validator';

@InputType()
export class LoginInput {
  @Field()
  @IsEmail()
  email: string;

  @Field()
  @IsString()
  @MinLength(8)
  password: string;
}
```

```ts path=backend/src/modules/identity/presentation/dto/user.object.ts
import { Field, ObjectType } from '@nestjs/graphql';
import { User } from '../../domain/user.entity';
import { UserRole } from '../../domain/user-role.enum';

@ObjectType()
export class UserObject {
  @Field()
  id: string;

  @Field()
  email: string;

  @Field()
  name: string;

  @Field(() => String)
  role: UserRole;

  @Field()
  createdAt: Date;

  @Field()
  updatedAt: Date;

  static fromDomain(user: User): UserObject {
    const props = user.toSafeProps();
    const object = new UserObject();

    object.id = props.id;
    object.email = props.email;
    object.name = props.name;
    object.role = props.role;
    object.createdAt = props.createdAt;
    object.updatedAt = props.updatedAt;

    return object;
  }
}
```

```ts path=backend/src/modules/identity/presentation/dto/auth-payload.object.ts
import { Field, ObjectType } from '@nestjs/graphql';
import { UserObject } from './user.object';

@ObjectType()
export class AuthPayload {
  @Field()
  accessToken: string;

  @Field(() => UserObject)
  user: UserObject;
}
```

Poin penting:

- `UserObject` tidak punya `passwordHash`.
- `AuthPayload` mengembalikan token dan user aman.
- Validation input berjalan jika `ValidationPipe` sudah aktif di `main.ts`.

## GraphQL Auth Guard

Guard REST biasa biasanya membaca request langsung dari HTTP context. Pada GraphQL, request berada di GraphQL context, sehingga guard perlu memakai `GqlExecutionContext`.

```ts path=backend/src/common/guards/gql-auth.guard.ts
import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { GqlExecutionContext } from '@nestjs/graphql';

export type CurrentUserPayload = {
  sub: string;
  email: string;
  role: string;
};

@Injectable()
export class GqlAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const gqlContext = GqlExecutionContext.create(context);
    const ctx = gqlContext.getContext<{ req?: { headers?: Record<string, string>; user?: CurrentUserPayload } }>();
    const authorization = ctx.req?.headers?.authorization ?? ctx.req?.headers?.Authorization;

    if (!authorization) {
      throw new UnauthorizedException('Authorization header is required.');
    }

    const [type, token] = authorization.split(' ');

    if (type !== 'Bearer' || !token) {
      throw new UnauthorizedException('Authorization header must use Bearer token.');
    }

    const secret = this.configService.get<string>('JWT_SECRET');
    if (!secret) {
      throw new UnauthorizedException('JWT secret is not configured.');
    }

    try {
      const payload = await this.jwtService.verifyAsync<CurrentUserPayload>(token, {
        secret,
      });

      if (!ctx.req) {
        ctx.req = {};
      }

      ctx.req.user = payload;
      return true;
    } catch {
      throw new UnauthorizedException('Invalid or expired token.');
    }
  }
}
```

Ketentuan:

- Header harus berbentuk `Bearer <token>`.
- Token kosong, invalid, atau expired menghasilkan `UnauthorizedException`.
- Payload ditempel ke `req.user`.

## Current User Decorator

Decorator membuat resolver lebih bersih karena resolver tidak perlu tahu detail GraphQL context.

```ts path=backend/src/common/decorators/current-user.decorator.ts
import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { GqlExecutionContext } from '@nestjs/graphql';
import { CurrentUserPayload } from '../guards/gql-auth.guard';

export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): CurrentUserPayload => {
    const gqlContext = GqlExecutionContext.create(context);
    const ctx = gqlContext.getContext<{ req?: { user?: CurrentUserPayload } }>();

    if (!ctx.req?.user) {
      throw new Error('Current user is not available in GraphQL context.');
    }

    return ctx.req.user;
  },
);
```

Contoh pemakaian:

```ts path=backend/src/modules/identity/presentation/identity.resolver.ts
@UseGuards(GqlAuthGuard)
@Query(() => UserObject)
async me(@CurrentUser() currentUser: CurrentUserPayload): Promise<UserObject> {
  return this.identityService.getCurrentUser(currentUser.sub);
}
```

## Presentation Layer - Resolver

`register` dan `login` public. `me` protected dengan `GqlAuthGuard`.

```ts path=backend/src/modules/identity/presentation/identity.resolver.ts
import { UseGuards } from '@nestjs/common';
import { Args, Mutation, Query, Resolver } from '@nestjs/graphql';
import { GraphQLError } from 'graphql';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import {
  CurrentUserPayload,
  GqlAuthGuard,
} from '../../../common/guards/gql-auth.guard';
import { IdentityService } from '../application/identity.service';
import { AuthPayload } from './dto/auth-payload.object';
import { LoginInput } from './dto/login.input';
import { RegisterInput } from './dto/register.input';
import { UserObject } from './dto/user.object';

@Resolver(() => UserObject)
export class IdentityResolver {
  constructor(private readonly identityService: IdentityService) {}

  @Mutation(() => AuthPayload)
  async register(@Args('input') input: RegisterInput): Promise<AuthPayload> {
    const result = await this.identityService.register(input);

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    const authResult = result.unwrap();
    return {
      accessToken: authResult.accessToken,
      user: UserObject.fromDomain(authResult.user),
    };
  }

  @Mutation(() => AuthPayload)
  async login(@Args('input') input: LoginInput): Promise<AuthPayload> {
    const result = await this.identityService.login(input);

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    const authResult = result.unwrap();
    return {
      accessToken: authResult.accessToken,
      user: UserObject.fromDomain(authResult.user),
    };
  }

  @UseGuards(GqlAuthGuard)
  @Query(() => UserObject)
  async me(@CurrentUser() currentUser: CurrentUserPayload): Promise<UserObject> {
    const result = await this.identityService.getCurrentUser(currentUser.sub);

    if (result.isFail()) {
      throw this.toGraphQLError(result.unwrapError());
    }

    return UserObject.fromDomain(result.unwrap());
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

Resolver tidak melakukan hashing password dan tidak query Prisma langsung. Semua logic itu ada di service dan infrastructure.

## Identity Module

Module mendaftarkan resolver, service, repository implementation, password hasher, dan token service.

```ts path=backend/src/modules/identity/presentation/identity.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PrismaModule } from '../../../infrastructure/prisma/prisma.module';
import { IdentityService } from '../application/identity.service';
import { PASSWORD_HASHER } from '../application/password-hasher';
import { TOKEN_SERVICE } from '../application/token.service';
import { USER_REPOSITORY } from '../application/user.repository';
import { BcryptPasswordHasher } from '../infrastructure/bcrypt-password-hasher';
import { JwtTokenService } from '../infrastructure/jwt-token.service';
import { PrismaUserRepository } from '../infrastructure/prisma-user.repository';
import { IdentityResolver } from './identity.resolver';

@Module({
  imports: [PrismaModule, ConfigModule, JwtModule.register({})],
  providers: [
    IdentityResolver,
    IdentityService,
    {
      provide: USER_REPOSITORY,
      useClass: PrismaUserRepository,
    },
    {
      provide: PASSWORD_HASHER,
      useClass: BcryptPasswordHasher,
    },
    {
      provide: TOKEN_SERVICE,
      useClass: JwtTokenService,
    },
  ],
  exports: [IdentityService],
})
export class IdentityModule {}
```

Dependency injection bekerja seperti ini:

- `IdentityService` meminta `USER_REPOSITORY`, `PASSWORD_HASHER`, dan `TOKEN_SERVICE`.
- `IdentityModule` memetakan token tersebut ke class konkret.
- Resolver cukup memakai `IdentityService`.
- Resolver tidak perlu tahu repository konkret, bcrypt, atau JWT library.
- Module mendaftarkan dependency sendiri agar boundary Identity tetap jelas.

## GraphQL Context Update

GraphQL auth guard butuh request object dari GraphQL context agar bisa membaca header.

Update `AppModule`:

```ts path=backend/src/app.module.ts
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { GraphQLModule } from '@nestjs/graphql';
import { join } from 'path';
import { PrismaModule } from './infrastructure/prisma/prisma.module';
import { HealthModule } from './modules/health/health.module';
import { IdentityModule } from './modules/identity/presentation/identity.module';

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
  ],
})
export class AppModule {}
```

Kenapa context penting:

- Header `Authorization` berasal dari HTTP request.
- Resolver GraphQL tidak memakai REST controller context biasa.
- Guard membaca header dari `context.req.headers`.
- Decorator `CurrentUser` membaca payload dari `context.req.user`.

## Error Handling

Error yang perlu ditangani:

- Email sudah dipakai: return `EMAIL_ALREADY_USED`.
- Email/password salah: return `INVALID_CREDENTIALS`.
- Password terlalu pendek: return `PASSWORD_TOO_SHORT`.
- Token kosong: throw `UnauthorizedException`.
- Token invalid: throw `UnauthorizedException`.
- Token expired: throw `UnauthorizedException`.
- User tidak ditemukan: return `USER_NOT_FOUND`.
- `JWT_SECRET` belum diset: throw error saat sign/verify.
- `passwordHash` tidak boleh keluar response: jangan taruh field ini di `UserObject`.

Contoh error GraphQL:

```json
{
  "errors": [
    {
      "message": "Email is already used.",
      "extensions": {
        "code": "EMAIL_ALREADY_USED",
        "type": "CONFLICT"
      }
    }
  ],
  "data": null
}
```

Pada file berikutnya, error handling bisa dirapikan dengan GraphQL exception filter agar semua format error konsisten.

## GraphQL Query/Mutation Example

Register:

```graphql
mutation {
  register(input: {
    email: "admin@example.com"
    name: "Admin User"
    password: "Password123!"
  }) {
    accessToken
    user {
      id
      email
      name
      role
    }
  }
}
```

Login:

```graphql
mutation {
  login(input: {
    email: "admin@example.com"
    password: "Password123!"
  }) {
    accessToken
    user {
      id
      email
      name
      role
    }
  }
}
```

Me:

```graphql
query {
  me {
    id
    email
    name
    role
  }
}
```

Query `me` harus memakai header:

```json
{
  "Authorization": "Bearer YOUR_ACCESS_TOKEN"
}
```

## Cara Test Di GraphQL Playground/Sandbox

1. Jalankan backend:

```bash
npm run start:dev
```

Penjelasan:

- `npm run start:dev` menjalankan NestJS dalam mode watch.

2. Buka GraphQL:

```txt
http://localhost:3000/graphql
```

3. Jalankan mutation `register`.
4. Copy `accessToken`.
5. Set HTTP header:

```json
{
  "Authorization": "Bearer YOUR_ACCESS_TOKEN"
}
```

6. Jalankan query `me`.

Expected result:

```json
{
  "data": {
    "me": {
      "id": "user-id",
      "email": "admin@example.com",
      "name": "Admin User",
      "role": "MEMBER"
    }
  }
}
```

## Seed User

Seed harus idempotent, artinya aman dijalankan berkali-kali tanpa membuat duplikat.

```ts path=backend/prisma/seed.ts
import { PrismaClient, UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash('Password123!', 12);

  await prisma.user.upsert({
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

  await prisma.user.upsert({
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

Jalankan seed:

```bash
npm run db:seed
```

Penjelasan:

- `npm run db:seed` menjalankan script `db:seed` dari `package.json`.
- Script ini biasanya berisi `prisma db seed`.
- `upsert` membuat data jika belum ada, atau update jika sudah ada.

Jika belum ada konfigurasi seed di `package.json`, tambahkan:

```json path=backend/package.json
{
  "prisma": {
    "seed": "ts-node prisma/seed.ts"
  }
}
```

Jika memakai TypeScript seed, pastikan dependency runner tersedia sesuai setup project. Alternatif sederhana adalah memakai `tsx`.

## Request Flow

Flow register:

```txt
GraphQL Client
    |
    v
IdentityResolver.register
    |
    v
IdentityService.register
    |
    v
PasswordHasher.hash
    |
    v
UserRepository.create
    |
    v
Prisma
    |
    v
PostgreSQL
    |
    v
TokenService.sign
    |
    v
AuthPayload
```

Flow login:

```txt
GraphQL Client
    |
    v
IdentityResolver.login
    |
    v
IdentityService.login
    |
    v
UserRepository.findByEmail
    |
    v
PasswordHasher.compare
    |
    v
TokenService.sign
    |
    v
AuthPayload
```

Flow me:

```txt
GraphQL Client
    |
    v
GqlAuthGuard
    |
    v
Verify token
    |
    v
CurrentUser decorator
    |
    v
IdentityResolver.me
    |
    v
IdentityService.getCurrentUser
    |
    v
UserObject
```

## Security Notes

- Jangan simpan password plain text.
- Jangan return `passwordHash`.
- `JWT_SECRET` harus kuat dan panjang.
- `JWT_SECRET` jangan diekspos ke frontend.
- Token di localStorage rentan XSS.
- HttpOnly cookie bisa lebih aman untuk production.
- Rate limiting login perlu untuk production.
- Audit log login/register adalah improvement penting.
- Email verification adalah improvement penting.
- Refresh token sebaiknya ditambahkan untuk sesi yang lebih baik.
- HTTPS wajib di production.
- Pesan error login jangan membedakan email salah atau password salah.

## Design Pattern Yang Relevan

Konsep pattern berikut memakai inspirasi umum dari katalog design pattern seperti Refactoring Guru, tetapi penjelasan dan contoh kode dibuat untuk stack ini.

### Repository Pattern

Masalah yang diselesaikan:

`IdentityService` butuh akses user, tetapi tidak perlu tahu detail Prisma.

Kenapa dipakai:

Data access user menjadi terpusat dan mudah diganti saat testing.

File yang memakai:

- `backend/src/modules/identity/application/user.repository.ts`
- `backend/src/modules/identity/infrastructure/prisma-user.repository.ts`

Alternatif:

- Service langsung memanggil Prisma. Lebih cepat di awal, tetapi coupling lebih kuat.

### Adapter Pattern Melalui BcryptPasswordHasher Dan JwtTokenService

Masalah yang diselesaikan:

Application layer tidak perlu bergantung langsung pada bcryptjs atau JWT library.

Kenapa dipakai:

Library teknis dibungkus sebagai interface yang stabil.

File yang memakai:

- `backend/src/modules/identity/application/password-hasher.ts`
- `backend/src/modules/identity/infrastructure/bcrypt-password-hasher.ts`
- `backend/src/modules/identity/application/token.service.ts`
- `backend/src/modules/identity/infrastructure/jwt-token.service.ts`

Alternatif:

- Memanggil `bcrypt.hash` dan `jwtService.sign` langsung di service.

### Facade Pattern Melalui IdentityService Dan IdentityResolver

Masalah yang diselesaikan:

Client tidak perlu tahu detail hashing, repository, dan token generation.

Kenapa dipakai:

`IdentityResolver` menyediakan API sederhana, sedangkan `IdentityService` menyatukan use case auth.

File yang memakai:

- `backend/src/modules/identity/application/identity.service.ts`
- `backend/src/modules/identity/presentation/identity.resolver.ts`

Alternatif:

- Logic auth tersebar di banyak resolver.

### Strategy-like Abstraction Untuk PasswordHasher Dan TokenService

Masalah yang diselesaikan:

Algoritma hashing atau format token bisa berubah.

Kenapa dipakai:

Interface membuat implementasi bisa diganti, misalnya dari bcrypt ke argon2, atau dari JWT ke opaque token.

File yang memakai:

- `backend/src/modules/identity/application/password-hasher.ts`
- `backend/src/modules/identity/application/token.service.ts`

Alternatif:

- Mengunci aplikasi pada satu library langsung di use case.

### Result Pattern

Masalah yang diselesaikan:

Business error seperti email sudah dipakai tidak harus selalu menjadi exception.

Kenapa dipakai:

Use case mengembalikan sukses/gagal secara eksplisit.

File yang memakai:

- `backend/src/modules/identity/application/identity.service.ts`
- `backend/src/modules/identity/domain/user.entity.ts`

Alternatif:

- Throw exception untuk semua business error.

### Dependency Injection NestJS

Masalah yang diselesaikan:

Class tidak membuat dependency sendiri.

Kenapa dipakai:

Testing lebih mudah dan implementasi teknis bisa diganti di module.

File yang memakai:

- `backend/src/modules/identity/presentation/identity.module.ts`
- `backend/src/modules/identity/application/identity.service.ts`
- `backend/src/common/guards/gql-auth.guard.ts`

Alternatif:

- Membuat instance manual dengan `new`.

### Guard Pattern Untuk Protected Resolver

Masalah yang diselesaikan:

Resolver protected butuh pemeriksaan token sebelum logic dijalankan.

Kenapa dipakai:

Guard memisahkan auth check dari resolver.

File yang memakai:

- `backend/src/common/guards/gql-auth.guard.ts`
- `backend/src/modules/identity/presentation/identity.resolver.ts`

Alternatif:

- Mengecek token manual di setiap resolver. Ini rawan duplikasi dan tidak konsisten.

## Troubleshooting

### Nest cannot resolve dependency

Penyebab:

- Provider token belum didaftarkan.
- Module belum import dependency.
- Token `Symbol` yang di-inject berbeda dari yang didaftarkan.

Solusi:

- Cek `IdentityModule`.
- Pastikan `USER_REPOSITORY`, `PASSWORD_HASHER`, dan `TOKEN_SERVICE` didaftarkan.
- Pastikan `JwtModule.register({})`, `ConfigModule`, dan `PrismaModule` tersedia.

### JWT_SECRET undefined

Penyebab:

- `.env` belum berisi `JWT_SECRET`.
- `ConfigModule.forRoot()` belum aktif.
- Aplikasi dijalankan dari folder yang salah.

Solusi:

- Cek `.env`.
- Cek `AppModule`.
- Restart `npm run start:dev`.

### Authorization header tidak terbaca di GraphQL

Penyebab:

- GraphQL context belum membawa `req`.

Solusi:

Pastikan konfigurasi ini ada:

```ts path=backend/src/app.module.ts
context: ({ req }) => ({ req }),
```

### Guard selalu Unauthorized

Penyebab:

- Header tidak dikirim.
- Format bukan `Bearer <token>`.
- Secret saat sign berbeda dari secret saat verify.
- Token expired.

Solusi:

- Cek HTTP headers di Playground/Sandbox.
- Pastikan token hasil login terbaru.
- Pastikan `JWT_SECRET` sama.

### Token expired

Penyebab:

- `JWT_EXPIRES_IN` sudah lewat.

Solusi:

- Login ulang.
- Untuk production, tambahkan refresh token pada implementasi lanjutan.

### bcrypt compare selalu false

Penyebab:

- Password hash tidak berasal dari bcrypt.
- Password input berbeda.
- Yang disimpan adalah password plain text dari seed lama.

Solusi:

- Jalankan seed ulang dengan hashing.
- Cek bahwa register menyimpan `passwordHash`, bukan `password`.

### Prisma unique constraint email

Penyebab:

- Email sudah ada.
- Check unique di service terlewat karena race condition.

Solusi:

- Service tetap cek `findByEmail`.
- Tangani error unique constraint Prisma di repository atau filter global untuk production.

### UserObject tidak muncul di schema

Penyebab:

- Resolver/module belum didaftarkan.
- Decorator GraphQL tidak lengkap.

Solusi:

- Pastikan `IdentityModule` diimport di `AppModule`.
- Pastikan `@ObjectType()` dan `@Field()` ada.

### Decorator GraphQL salah import

Penyebab:

- `Field`, `ObjectType`, `InputType`, atau `Resolver` diimport dari package yang salah.

Solusi:

Gunakan `@nestjs/graphql`.

### class-validator tidak jalan

Penyebab:

- Global `ValidationPipe` belum dipasang.

Solusi:

Pastikan `main.ts` punya:

```ts path=backend/src/main.ts
app.useGlobalPipes(
  new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  }),
);
```

### Password hash muncul di response

Penyebab:

- `UserObject` berisi field `passwordHash`.
- Resolver return domain props penuh.

Solusi:

- Hapus `passwordHash` dari `UserObject`.
- Gunakan `UserObject.fromDomain()`.
- Gunakan `user.toSafeProps()`.

### GraphQL context belum membawa req

Penyebab:

- Konfigurasi `context` belum ditambahkan di `GraphQLModule`.

Solusi:

Tambahkan:

```ts path=backend/src/app.module.ts
context: ({ req }) => ({ req }),
```

## Checklist Berhasil

- User model tersedia di Prisma.
- Migration auth berhasil.
- Register berhasil.
- Login berhasil.
- Password tersimpan sebagai hash.
- Access token berhasil dibuat.
- Query `me` gagal tanpa token.
- Query `me` berhasil dengan token valid.
- `UserObject` tidak punya `passwordHash`.
- Resolver tidak query Prisma langsung.
- `IdentityService` tidak tahu detail bcrypt/JWT library.
- `IdentityModule` mendaftarkan provider dengan benar.

## Langkah Berikutnya

Lanjutkan ke `backend/04-organization-tenancy.md` untuk membuat organization/tenant, membership, dan role dalam organization. Setelah itu, `organizationId` pada project dan task bisa dihubungkan ke user yang sedang login.

