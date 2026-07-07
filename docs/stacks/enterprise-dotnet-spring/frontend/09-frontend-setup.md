# Frontend 09 - Next.js Setup

File ini memulai dokumentasi frontend untuk stack .NET Backend + Next.js Frontend. Backend sudah disiapkan sebagai modular monolith dengan Identity/Auth, Organizations/Tenancy, Projects, Tasks, Shared Kernel, dan EF Core database. Sekarang frontend dibuat sebagai aplikasi Next.js yang memanggil REST API backend tersebut.

Tujuan file ini adalah membuat panduan setup frontend dari folder kosong sampai siap terhubung ke backend .NET. Fokusnya adalah struktur project, pilihan `create-next-app`, environment variable, API client awal, auth storage awal, dan layout dasar. Fitur login/register/dashboard lengkap akan dilanjutkan di file berikutnya.

## Posisi Frontend Dalam Full Web App

Dalam arsitektur full web app ini:

```text
# File: docs/stacks/enterprise-dotnet-spring/frontend/09-frontend-setup.md
Browser user
  -> Next.js frontend
  -> API client frontend
  -> .NET Backend REST API
  -> EF Core database
```

Next.js bertanggung jawab untuk:

- routing halaman;
- layout dashboard;
- form login/register;
- state loading/error/success;
- menyimpan token secara lokal untuk mockup;
- memanggil endpoint backend;
- menampilkan data organizations, projects, dan tasks.

Backend .NET tetap menjadi sumber kebenaran untuk authentication, authorization, tenant isolation, validation, dan data persistence.

## Konsep Dasar Next.js

### React

React adalah library UI untuk membuat tampilan berbasis component. Component adalah potongan UI yang bisa dipakai ulang, misalnya button, input, table, sidebar, atau form.

### Next.js

Next.js adalah framework di atas React. Next.js menyediakan routing, layout, build system, optimasi, dan pola server/client component.

### App Router

App Router adalah sistem routing Next.js modern yang memakai folder `src/app`. File `page.tsx` menjadi halaman, dan `layout.tsx` menjadi layout.

### Page

Page adalah halaman yang bisa diakses lewat URL. Contoh: `src/app/login/page.tsx` menjadi `/login`.

### Layout

Layout adalah wrapper UI untuk halaman. Contoh: dashboard layout berisi sidebar dan topbar, lalu halaman dashboard dirender di dalamnya.

### Component

Component adalah bagian UI reusable. Contoh: `Button`, `Input`, `AppSidebar`, `ErrorMessage`.

### Server Component

Server Component dirender di server. Secara default, component di App Router adalah Server Component. Cocok untuk UI yang tidak butuh event browser.

### Client Component

Client Component berjalan di browser dan bisa memakai state, event handler, `localStorage`, dan hook React. File Client Component harus diawali dengan directive:

```tsx
// File: frontend/src/components/example/client-component-example.tsx
"use client";

export function ClientComponentExample() {
  return <button type="button">Klik</button>;
}
```

### Route Group

Route group adalah folder dengan nama dalam kurung, misalnya `(auth)` atau `(dashboard)`, untuk mengelompokkan route tanpa menambah segment URL. File ini belum memakai route group agar struktur awal lebih mudah dibaca.

### API Client

API client adalah wrapper untuk memanggil backend. Dengan API client, semua fetch ke backend punya format yang konsisten.

### Environment Variable

Environment variable menyimpan konfigurasi berbeda per environment. Contoh: URL backend disimpan di `NEXT_PUBLIC_API_BASE_URL`.

### Hydration

Hydration adalah proses saat React di browser membuat halaman yang dikirim server menjadi interaktif. Jika component memakai `localStorage`, component tersebut harus menjadi Client Component.

### Protected Route

Protected route adalah halaman yang hanya boleh dibuka user login. Di setup awal, protected route akan disiapkan dengan layout dashboard dan token check sederhana. Implementasi lebih lengkap ada di file auth/dashboard berikutnya.

## Kenapa Memilih Next.js

Next.js cocok untuk frontend enterprise mockup karena:

- cocok untuk dashboard/admin app;
- punya routing bawaan;
- mendukung Server Component dan Client Component;
- mendukung TypeScript;
- mudah integrasi dengan REST API backend .NET;
- struktur folder App Router cocok untuk memisahkan auth, dashboard, project, dan task;
- mudah dibuat menjadi mockup web app yang benar-benar bisa dijalankan.

## Struktur Folder Frontend Target

```txt
# File: docs/stacks/enterprise-dotnet-spring/frontend/09-frontend-setup.md
frontend/
├── .env.local
├── package.json
├── next.config.ts
├── tsconfig.json
├── eslint.config.mjs
├── postcss.config.mjs
├── tailwind.config.ts
├── public/
└── src/
    ├── app/
    │   ├── layout.tsx
    │   ├── page.tsx
    │   ├── globals.css
    │   ├── login/
    │   │   └── page.tsx
    │   ├── register/
    │   │   └── page.tsx
    │   └── dashboard/
    │       ├── layout.tsx
    │       └── page.tsx
    │
    ├── components/
    │   ├── ui/
    │   ├── layout/
    │   └── feedback/
    │
    ├── config/
    │   └── env.ts
    │
    ├── features/
    │   ├── auth/
    │   ├── organizations/
    │   ├── projects/
    │   └── tasks/
    │
    ├── hooks/
    │   └── useAuth.ts
    │
    ├── lib/
    │   ├── api-client.ts
    │   ├── auth-storage.ts
    │   └── routes.ts
    │
    ├── services/
    │   └── auth-service.ts
    │
    └── types/
        ├── api.ts
        └── auth.ts
```

## Membuat Next.js Dari Folder Kosong

Dari root workspace, buat folder frontend dengan `create-next-app`.

```powershell
# File: frontend/commands/01-create-next-app.ps1
npx create-next-app@latest frontend
```

Saat CLI bertanya, pilih:

```text
# File: frontend/commands/create-next-app-answers.txt
Would you like to use TypeScript? Yes
Would you like to use ESLint? Yes
Would you like to use Tailwind CSS? Yes
Would you like your code inside a `src/` directory? Yes
Would you like to use App Router? Yes
Would you like to use Turbopack? Yes
Would you like to customize the import alias? Yes
What import alias would you like configured? @/*
```

Penjelasan pilihan:

- TypeScript: membuat contract API dan props lebih aman.
- ESLint: membantu menjaga kualitas code.
- Tailwind CSS: cepat untuk membuat dashboard mockup.
- `src/` directory: memisahkan source code dari config root.
- App Router: routing modern Next.js.
- Turbopack: dev server lebih cepat untuk project baru.
- Import alias `@/*`: import file lebih rapi, misalnya `@/lib/api-client`.

Masuk ke folder frontend:

```powershell
# File: frontend/commands/02-enter-frontend.ps1
cd frontend
```

Install dependency jika belum otomatis:

```powershell
# File: frontend/commands/03-install-dependencies.ps1
npm install
```

Run dev server:

```powershell
# File: frontend/commands/04-run-dev.ps1
npm run dev
```

Expected output:

```text
# File: frontend/commands/expected-dev-output.txt
Local:   http://localhost:3000
```

Buka browser:

```text
# File: frontend/commands/open-local-url.txt
http://localhost:3000
```

## Verifikasi Setup Awal

Build untuk memastikan setup awal valid.

```powershell
# File: frontend/commands/05-build.ps1
npm run build
```

Lint:

```powershell
# File: frontend/commands/06-lint.ps1
npm run lint
```

Jika `npm run lint` tidak tersedia di versi Next.js yang dipakai, gunakan command yang ada di `package.json`.


## Membuat Struktur Folder Aplikasi

Setelah `create-next-app` selesai, buat folder aplikasi yang akan dipakai oleh dokumentasi frontend berikutnya.

```powershell
# File: frontend/commands/07-create-folders.ps1
mkdir src\components\ui
mkdir src\components\layout
mkdir src\components\feedback
mkdir src\config
mkdir src\features\auth
mkdir src\features\organizations
mkdir src\features\projects
mkdir src\features\tasks
mkdir src\hooks
mkdir src\lib
mkdir src\services
mkdir src\types
mkdir src\app\login
mkdir src\app\register
mkdir src\app\dashboard
```

Penjelasan folder:

- `src/app`: route, page, dan layout Next.js.
- `src/components`: component UI reusable yang tidak terikat ke satu fitur.
- `src/config`: pembacaan konfigurasi environment.
- `src/features`: tempat code spesifik fitur seperti auth, projects, dan tasks.
- `src/hooks`: React hook reusable.
- `src/lib`: utility aplikasi seperti API client, route constant, dan storage.
- `src/services`: wrapper call ke endpoint backend.
- `src/types`: type TypeScript yang dipakai lintas fitur.

## Konfigurasi Environment

Frontend perlu tahu URL backend .NET. Untuk development lokal, backend biasanya berjalan di `http://localhost:5000` atau `https://localhost:5001`. Sesuaikan dengan output `dotnet run` di backend.

```dotenv
# File: frontend/.env.local
NEXT_PUBLIC_API_BASE_URL=http://localhost:5000
```

Prefix `NEXT_PUBLIC_` berarti variable boleh dibaca dari browser. Jangan menaruh secret di variable dengan prefix ini.

Buat wrapper konfigurasi agar code lain tidak membaca `process.env` secara tersebar.

```ts
// File: frontend/src/config/env.ts
export const env = {
  apiBaseUrl: process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:5000",
};
```

Kenapa dibuat file `env.ts`:

- satu tempat untuk membaca environment variable;
- mudah divalidasi nanti jika config bertambah;
- service dan API client tidak perlu tahu detail `process.env`.

## Type API Bersama

Backend dari dokumentasi sebelumnya memakai API response envelope. Frontend perlu type yang mengikuti bentuk response tersebut.

```ts
// File: frontend/src/types/api.ts
export type ApiError = {
  code: string;
  message: string;
  details?: Record<string, string[]>;
};

export type ApiResponse<T> = {
  success: boolean;
  message: string;
  data: T | null;
  error: ApiError | null;
};

export type PaginationMetadata = {
  page: number;
  pageSize: number;
  totalItems: number;
  totalPages: number;
};

export type PagedResponse<T> = {
  items: T[];
  pagination: PaginationMetadata;
};
```

Type auth awal mengikuti endpoint Identity/Auth dari backend: register, login, dan `/auth/me`.

```ts
// File: frontend/src/types/auth.ts
export type RegisterRequest = {
  name: string;
  email: string;
  password: string;
};

export type RegisterResponse = {
  userId: string;
  name: string;
  email: string;
  role: "Admin" | "Member";
};

export type LoginRequest = {
  email: string;
  password: string;
};

export type LoginResponse = {
  accessToken: string;
  tokenType: "Bearer";
  expiresInSeconds: number;
  user: CurrentUser;
};

export type CurrentUser = {
  id: string;
  name: string;
  email: string;
  roles: string[];
};
```

## Route Constant

Route constant mencegah string URL tersebar di banyak file.

```ts
// File: frontend/src/lib/routes.ts
export const routes = {
  home: "/",
  login: "/login",
  register: "/register",
  dashboard: "/dashboard",
  projects: "/dashboard/projects",
  tasks: "/dashboard/tasks",
};
```

## Auth Storage Awal

Untuk mockup belajar, token disimpan di `localStorage`. Ini sederhana dan mudah dipahami. Untuk production, pertimbangkan session dengan cookie `HttpOnly`, `Secure`, dan `SameSite` agar token tidak mudah dibaca JavaScript.

```ts
// File: frontend/src/lib/auth-storage.ts
const ACCESS_TOKEN_KEY = "pm_access_token";

export const authStorage = {
  getAccessToken(): string | null {
    if (typeof window === "undefined") {
      return null;
    }

    return window.localStorage.getItem(ACCESS_TOKEN_KEY);
  },

  setAccessToken(token: string): void {
    if (typeof window === "undefined") {
      return;
    }

    window.localStorage.setItem(ACCESS_TOKEN_KEY, token);
  },

  clear(): void {
    if (typeof window === "undefined") {
      return;
    }

    window.localStorage.removeItem(ACCESS_TOKEN_KEY);
  },
};
```

Guard `typeof window === "undefined"` penting karena file Next.js bisa dievaluasi di server. `localStorage` hanya tersedia di browser.

## API Client Frontend

API client menyatukan cara frontend memanggil backend. Semua request akan:

- memakai base URL dari `.env.local`;
- mengirim `Content-Type: application/json`;
- menambahkan bearer token jika ada;
- membaca response sebagai `ApiResponse<T>`;
- mengubah error network menjadi response yang konsisten.

```ts
// File: frontend/src/lib/api-client.ts
import { env } from "@/config/env";
import { authStorage } from "@/lib/auth-storage";
import type { ApiResponse } from "@/types/api";

type RequestOptions = Omit<RequestInit, "body"> & {
  body?: unknown;
};

function buildUrl(path: string): string {
  const normalizedBaseUrl = env.apiBaseUrl.replace(/\/$/, "");
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;

  return `${normalizedBaseUrl}${normalizedPath}`;
}

export async function apiClient<T>(
  path: string,
  options: RequestOptions = {},
): Promise<ApiResponse<T>> {
  const token = authStorage.getAccessToken();

  const headers = new Headers(options.headers);
  headers.set("Content-Type", "application/json");

  if (token) {
    headers.set("Authorization", `Bearer ${token}`);
  }

  try {
    const response = await fetch(buildUrl(path), {
      ...options,
      headers,
      body: options.body ? JSON.stringify(options.body) : undefined,
    });

    const json = (await response.json()) as ApiResponse<T>;

    if (!response.ok && json.error === null) {
      return {
        success: false,
        message: "Request gagal.",
        data: null,
        error: {
          code: `HTTP_${response.status}`,
          message: json.message || "Backend mengembalikan error.",
        },
      };
    }

    return json;
  } catch {
    return {
      success: false,
      message: "Tidak bisa terhubung ke backend.",
      data: null,
      error: {
        code: "NETWORK_ERROR",
        message: "Pastikan backend .NET sedang berjalan dan URL API benar.",
      },
    };
  }
}
```

Endpoint backend yang dipakai setup awal:

```text
# File: frontend/docs/backend-endpoints-used.txt
POST /auth/register
POST /auth/login
GET  /auth/me
GET  /health
```

## Auth Service

Service menyembunyikan detail path endpoint backend dari page atau component. Page cukup memanggil `authService.login`, bukan langsung `fetch`.

```ts
// File: frontend/src/services/auth-service.ts
import { apiClient } from "@/lib/api-client";
import type {
  CurrentUser,
  LoginRequest,
  LoginResponse,
  RegisterRequest,
  RegisterResponse,
} from "@/types/auth";

export const authService = {
  register(request: RegisterRequest) {
    return apiClient<RegisterResponse>("/auth/register", {
      method: "POST",
      body: request,
    });
  },

  login(request: LoginRequest) {
    return apiClient<LoginResponse>("/auth/login", {
      method: "POST",
      body: request,
    });
  },

  me() {
    return apiClient<CurrentUser>("/auth/me", {
      method: "GET",
    });
  },
};
```

## Hook Auth Awal

Hook `useAuth` dipakai oleh Client Component untuk login, register, logout, dan membaca user saat ini.

```tsx
// File: frontend/src/hooks/useAuth.ts
"use client";

import { useCallback, useState } from "react";
import { useRouter } from "next/navigation";
import { authStorage } from "@/lib/auth-storage";
import { routes } from "@/lib/routes";
import { authService } from "@/services/auth-service";
import type { CurrentUser, LoginRequest, RegisterRequest } from "@/types/auth";

export function useAuth() {
  const router = useRouter();
  const [user, setUser] = useState<CurrentUser | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const loadCurrentUser = useCallback(async () => {
    setIsLoading(true);
    setErrorMessage(null);

    const response = await authService.me();

    if (!response.success || !response.data) {
      setUser(null);
      setErrorMessage(response.error?.message ?? "Gagal membaca user saat ini.");
      setIsLoading(false);
      return null;
    }

    setUser(response.data);
    setIsLoading(false);
    return response.data;
  }, []);

  const login = useCallback(
    async (request: LoginRequest) => {
      setIsLoading(true);
      setErrorMessage(null);

      const response = await authService.login(request);

      if (!response.success || !response.data) {
        setErrorMessage(response.error?.message ?? "Login gagal.");
        setIsLoading(false);
        return false;
      }

      authStorage.setAccessToken(response.data.accessToken);
      setUser(response.data.user);
      setIsLoading(false);
      router.push(routes.dashboard);
      return true;
    },
    [router],
  );

  const register = useCallback(
    async (request: RegisterRequest) => {
      setIsLoading(true);
      setErrorMessage(null);

      const response = await authService.register(request);

      if (!response.success) {
        setErrorMessage(response.error?.message ?? "Register gagal.");
        setIsLoading(false);
        return false;
      }

      setIsLoading(false);
      router.push(routes.login);
      return true;
    },
    [router],
  );

  const logout = useCallback(() => {
    authStorage.clear();
    setUser(null);
    router.push(routes.login);
  }, [router]);

  return {
    user,
    isLoading,
    errorMessage,
    login,
    register,
    logout,
    loadCurrentUser,
  };
}
```

## Component Feedback Dasar

Component kecil ini dipakai agar halaman awal tidak mengulang markup error dan loading.

```tsx
// File: frontend/src/components/feedback/ErrorMessage.tsx
type ErrorMessageProps = {
  message: string | null;
};

export function ErrorMessage({ message }: ErrorMessageProps) {
  if (!message) {
    return null;
  }

  return (
    <div className="rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
      {message}
    </div>
  );
}
```

```tsx
// File: frontend/src/components/feedback/LoadingState.tsx
type LoadingStateProps = {
  label?: string;
};

export function LoadingState({ label = "Memuat data..." }: LoadingStateProps) {
  return <p className="text-sm text-slate-500">{label}</p>;
}
```

## Styling Global

`create-next-app` dengan Tailwind biasanya sudah membuat `globals.css`. Rapikan menjadi baseline dashboard sederhana.

```css
/* File: frontend/src/app/globals.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  color-scheme: light;
}

* {
  box-sizing: border-box;
}

html,
body {
  margin: 0;
  min-height: 100%;
  background: #f8fafc;
  color: #0f172a;
}

body {
  font-family: Arial, Helvetica, sans-serif;
}

a {
  color: inherit;
  text-decoration: none;
}

button,
input,
textarea,
select {
  font: inherit;
}
```

## Root Layout

Root layout adalah wrapper paling atas untuk semua halaman.

```tsx
// File: frontend/src/app/layout.tsx
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Project Management App",
  description: "Mockup enterprise web app dengan .NET Backend dan Next.js Frontend.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="id">
      <body>{children}</body>
    </html>
  );
}
```

## Halaman Home Awal

Halaman awal dibuat sebagai pintu masuk aplikasi, bukan landing page marketing.

```tsx
// File: frontend/src/app/page.tsx
import Link from "next/link";
import { routes } from "@/lib/routes";

export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-5xl flex-col justify-center px-6 py-10">
      <div className="max-w-2xl">
        <p className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">
          Project Management App
        </p>
        <h1 className="text-4xl font-semibold text-slate-950">Frontend Next.js siap terhubung ke backend .NET.</h1>
        <p className="mt-4 text-base leading-7 text-slate-600">
          Gunakan halaman login untuk masuk ke dashboard. Data auth, organization, project, dan task akan
          dipanggil dari REST API backend.
        </p>
        <div className="mt-8 flex flex-wrap gap-3">
          <Link className="rounded-md bg-slate-950 px-4 py-2 text-sm font-medium text-white" href={routes.login}>
            Login
          </Link>
          <Link className="rounded-md border border-slate-300 px-4 py-2 text-sm font-medium" href={routes.register}>
            Register
          </Link>
        </div>
      </div>
    </main>
  );
}
```

## Login Page Awal

Halaman ini sudah memanggil backend `POST /auth/login`. Validasi masih sederhana agar fokus setup tetap jelas.

```tsx
// File: frontend/src/app/login/page.tsx
"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";
import { ErrorMessage } from "@/components/feedback/ErrorMessage";
import { routes } from "@/lib/routes";
import { useAuth } from "@/hooks/useAuth";

export default function LoginPage() {
  const { login, isLoading, errorMessage } = useAuth();
  const [email, setEmail] = useState("admin@example.com");
  const [password, setPassword] = useState("Password123!");

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await login({ email, password });
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-6 py-10">
      <h1 className="text-2xl font-semibold text-slate-950">Login</h1>
      <p className="mt-2 text-sm text-slate-600">Masuk untuk membuka dashboard project management.</p>

      <form className="mt-6 space-y-4" onSubmit={handleSubmit}>
        <ErrorMessage message={errorMessage} />

        <label className="block text-sm font-medium text-slate-700">
          Email
          <input
            className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2"
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
          />
        </label>

        <label className="block text-sm font-medium text-slate-700">
          Password
          <input
            className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            required
          />
        </label>

        <button
          className="w-full rounded-md bg-slate-950 px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
          type="submit"
          disabled={isLoading}
        >
          {isLoading ? "Masuk..." : "Login"}
        </button>
      </form>

      <p className="mt-6 text-sm text-slate-600">
        Belum punya akun? <Link className="font-medium text-slate-950" href={routes.register}>Register</Link>
      </p>
    </main>
  );
}
```

## Register Page Awal

Register page memanggil backend `POST /auth/register`. Setelah sukses, user diarahkan ke login.

```tsx
// File: frontend/src/app/register/page.tsx
"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";
import { ErrorMessage } from "@/components/feedback/ErrorMessage";
import { routes } from "@/lib/routes";
import { useAuth } from "@/hooks/useAuth";

export default function RegisterPage() {
  const { register, isLoading, errorMessage } = useAuth();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await register({ name, email, password });
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-6 py-10">
      <h1 className="text-2xl font-semibold text-slate-950">Register</h1>
      <p className="mt-2 text-sm text-slate-600">Buat akun awal untuk mencoba aplikasi.</p>

      <form className="mt-6 space-y-4" onSubmit={handleSubmit}>
        <ErrorMessage message={errorMessage} />

        <label className="block text-sm font-medium text-slate-700">
          Nama
          <input
            className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2"
            value={name}
            onChange={(event) => setName(event.target.value)}
            required
          />
        </label>

        <label className="block text-sm font-medium text-slate-700">
          Email
          <input
            className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2"
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
          />
        </label>

        <label className="block text-sm font-medium text-slate-700">
          Password
          <input
            className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            required
          />
        </label>

        <button
          className="w-full rounded-md bg-slate-950 px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
          type="submit"
          disabled={isLoading}
        >
          {isLoading ? "Membuat akun..." : "Register"}
        </button>
      </form>

      <p className="mt-6 text-sm text-slate-600">
        Sudah punya akun? <Link className="font-medium text-slate-950" href={routes.login}>Login</Link>
      </p>
    </main>
  );
}
```

## Dashboard Shell dan Protected Route Sederhana

Protected route awal dilakukan di Client Component karena token disimpan di `localStorage`. Jika token tidak ada, user diarahkan ke `/login`.

```tsx
// File: frontend/src/components/layout/DashboardShell.tsx
"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { LoadingState } from "@/components/feedback/LoadingState";
import { authStorage } from "@/lib/auth-storage";
import { routes } from "@/lib/routes";
import { useAuth } from "@/hooks/useAuth";

type DashboardShellProps = {
  children: React.ReactNode;
};

export function DashboardShell({ children }: DashboardShellProps) {
  const router = useRouter();
  const { logout } = useAuth();
  const [isChecking, setIsChecking] = useState(true);

  useEffect(() => {
    const token = authStorage.getAccessToken();

    if (!token) {
      router.replace(routes.login);
      return;
    }

    setIsChecking(false);
  }, [router]);

  if (isChecking) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <LoadingState label="Memeriksa sesi..." />
      </main>
    );
  }

  return (
    <div className="min-h-screen bg-slate-100">
      <aside className="fixed inset-y-0 left-0 hidden w-64 border-r border-slate-200 bg-white p-6 md:block">
        <h2 className="text-lg font-semibold text-slate-950">PM App</h2>
        <nav className="mt-8 grid gap-2 text-sm">
          <Link className="rounded-md px-3 py-2 hover:bg-slate-100" href={routes.dashboard}>Dashboard</Link>
          <Link className="rounded-md px-3 py-2 hover:bg-slate-100" href={routes.projects}>Projects</Link>
          <Link className="rounded-md px-3 py-2 hover:bg-slate-100" href={routes.tasks}>Tasks</Link>
        </nav>
      </aside>

      <div className="md:pl-64">
        <header className="flex h-16 items-center justify-between border-b border-slate-200 bg-white px-6">
          <p className="text-sm font-medium text-slate-700">Project Management</p>
          <button className="rounded-md border border-slate-300 px-3 py-2 text-sm" type="button" onClick={logout}>
            Logout
          </button>
        </header>
        <main className="p-6">{children}</main>
      </div>
    </div>
  );
}
```

```tsx
// File: frontend/src/app/dashboard/layout.tsx
import { DashboardShell } from "@/components/layout/DashboardShell";

export default function DashboardLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <DashboardShell>{children}</DashboardShell>;
}
```

```tsx
// File: frontend/src/app/dashboard/page.tsx
export default function DashboardPage() {
  return (
    <div>
      <h1 className="text-2xl font-semibold text-slate-950">Dashboard</h1>
      <p className="mt-2 text-sm text-slate-600">
        Ringkasan organization, project, dan task akan ditambahkan di dokumentasi berikutnya.
      </p>

      <div className="mt-6 grid gap-4 md:grid-cols-3">
        <section className="rounded-md border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">Organizations</p>
          <p className="mt-2 text-2xl font-semibold">0</p>
        </section>
        <section className="rounded-md border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">Projects</p>
          <p className="mt-2 text-2xl font-semibold">0</p>
        </section>
        <section className="rounded-md border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">Tasks</p>
          <p className="mt-2 text-2xl font-semibold">0</p>
        </section>
      </div>
    </div>
  );
}
```

## Konfigurasi Next.js dan Tailwind

`create-next-app` biasanya sudah membuat file config. Pastikan bentuk minimalnya seperti ini.

```ts
// File: frontend/next.config.ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {};

export default nextConfig;
```

Jika project memakai Tailwind v3 dan file `tailwind.config.ts` dibuat manual, gunakan konfigurasi berikut.

```ts
// File: frontend/tailwind.config.ts
import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/features/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
};

export default config;
```

Untuk Tailwind v4, `tailwind.config.ts` bisa tidak ada karena konfigurasi banyak berpindah ke CSS. Ikuti hasil bawaan `create-next-app` yang terpasang di project.

## Package Script Yang Dipakai

Pastikan `package.json` punya script dasar berikut. Versi dependency boleh mengikuti hasil terbaru dari `create-next-app`.

```jsonc
// File: frontend/package.json
{
  "scripts": {
    "dev": "next dev --turbopack",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  }
}
```

Penjelasan script:

- `dev`: menjalankan Next.js untuk development lokal.
- `build`: membuat production build dan mendeteksi error TypeScript/build.
- `start`: menjalankan hasil build production.
- `lint`: menjalankan lint jika tersedia di versi Next.js yang digunakan.

## Cara Menjalankan Frontend dan Backend Bersamaan

Jalankan backend .NET dari folder backend sesuai dokumentasi `01-solution-setup.md` dan `08-database-migration-seed.md`.

```powershell
# File: backend/commands/run-backend.ps1
dotnet run --project src\App.Api\App.Api.csproj
```

Pastikan backend health check bisa diakses.

```powershell
# File: backend/commands/test-health.ps1
curl http://localhost:5000/health
```

Expected output menyesuaikan implementasi backend, tetapi minimal response harus menunjukkan service hidup.

```json
// File: backend/commands/expected-health-output.json
{
  "status": "Healthy"
}
```

Lalu jalankan frontend.

```powershell
# File: frontend/commands/08-run-frontend.ps1
npm run dev
```

Buka halaman berikut:

```text
# File: frontend/commands/frontend-urls.txt
http://localhost:3000
http://localhost:3000/login
http://localhost:3000/register
http://localhost:3000/dashboard
```

## Cara Test Dengan Browser

Urutan test manual:

1. Buka `http://localhost:3000`.
2. Klik `Register`.
3. Buat user baru.
4. Setelah redirect ke login, login memakai email dan password yang sama.
5. Jika token diterima, browser diarahkan ke `/dashboard`.
6. Klik `Logout` untuk menghapus token.
7. Buka `/dashboard` lagi dan pastikan diarahkan ke `/login`.

## Cara Test Dengan Curl

Curl dipakai untuk memastikan backend benar sebelum menyalahkan frontend.

```powershell
# File: frontend/commands/09-test-backend-register.ps1
curl -X POST http://localhost:5000/auth/register `
  -H "Content-Type: application/json" `
  -d "{\"name\":\"Admin User\",\"email\":\"admin@example.com\",\"password\":\"Password123!\"}"
```

```powershell
# File: frontend/commands/10-test-backend-login.ps1
curl -X POST http://localhost:5000/auth/login `
  -H "Content-Type: application/json" `
  -d "{\"email\":\"admin@example.com\",\"password\":\"Password123!\"}"
```

Expected login response berisi token.

```json
// File: frontend/commands/expected-login-output.json
{
  "success": true,
  "message": "Login berhasil.",
  "data": {
    "accessToken": "jwt-token-di-sini",
    "tokenType": "Bearer",
    "expiresInSeconds": 3600,
    "user": {
      "id": "user-id",
      "name": "Admin User",
      "email": "admin@example.com",
      "roles": ["Admin"]
    }
  },
  "error": null
}
```

Gunakan token untuk test `/auth/me`.

```powershell
# File: frontend/commands/11-test-backend-me.ps1
curl http://localhost:5000/auth/me `
  -H "Authorization: Bearer jwt-token-di-sini"
```

## Troubleshooting Umum

### `NEXT_PUBLIC_API_BASE_URL` Salah

Gejala:

- login selalu gagal;
- browser console menampilkan `NETWORK_ERROR`;
- request menuju port yang salah.

Solusi:

```dotenv
# File: frontend/.env.local
NEXT_PUBLIC_API_BASE_URL=http://localhost:5000
```

Restart `npm run dev` setelah mengubah `.env.local`.

### Backend Belum Jalan

Gejala:

- `curl http://localhost:5000/health` gagal;
- frontend menampilkan tidak bisa terhubung ke backend.

Solusi:

```powershell
# File: backend/commands/run-backend.ps1
dotnet run --project src\App.Api\App.Api.csproj
```

### CORS Error

Gejala di browser console:

```text
# File: frontend/troubleshooting/cors-error.txt
Access to fetch at 'http://localhost:5000/auth/login' from origin 'http://localhost:3000' has been blocked by CORS policy.
```

Solusi ada di backend: izinkan origin frontend development.

```csharp
// File: backend/src/App.Api/Program.cs
builder.Services.AddCors(options =>
{
    options.AddPolicy("Frontend", policy =>
    {
        policy
            .WithOrigins("http://localhost:3000")
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();

app.UseCors("Frontend");
```

### Port 3000 Sudah Dipakai

Gejala:

```text
# File: frontend/troubleshooting/port-conflict.txt
Port 3000 is in use.
```

Solusi jalankan Next.js di port lain.

```powershell
# File: frontend/commands/12-run-frontend-port-3001.ps1
npm run dev -- -p 3001
```

Jika port frontend berubah menjadi `3001`, backend CORS juga harus mengizinkan `http://localhost:3001`.

### Hydration atau `localStorage is not defined`

Gejala:

```text
# File: frontend/troubleshooting/localstorage-error.txt
ReferenceError: localStorage is not defined
```

Penyebab: code memakai `localStorage` di Server Component atau saat render server.

Solusi:

- tambahkan `"use client"` di component yang memakai browser API;
- akses token lewat `authStorage` yang sudah memakai guard `typeof window`;
- jangan membaca `localStorage` langsung di root layout server.

### Token 401 Unauthorized

Gejala:

- login berhasil tetapi `/auth/me` gagal;
- dashboard redirect ke login;
- backend mengembalikan status `401`.

Solusi:

- pastikan `Authorization` dikirim dengan format `Bearer token`;
- pastikan token belum expired;
- pastikan secret JWT backend sama dengan config yang dipakai saat generate dan validate token;
- hapus token lama dari browser local storage lalu login ulang.

## Checklist Akhir

Setelah file ini selesai diikuti, kondisi frontend seharusnya:

- Next.js berhasil dibuat dari folder kosong;
- TypeScript, ESLint, Tailwind, `src/`, App Router, Turbopack, dan alias `@/*` aktif;
- `.env.local` mengarah ke backend .NET;
- API client siap memanggil backend;
- auth service punya register, login, dan me;
- login/register page sudah bisa memanggil endpoint backend;
- dashboard punya protected route sederhana;
- struktur folder siap untuk dokumentasi auth dashboard, projects, dan tasks berikutnya.

File berikutnya dapat memperdalam login/register/dashboard, token handling, dan state auth agar lebih rapi untuk alur aplikasi enterprise.
