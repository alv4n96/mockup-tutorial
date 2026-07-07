# Frontend 05 - Auth Pages

## Tujuan File

Membuat halaman login dan register Vite React yang terhubung ke backend auth.

## Problem Yang Diselesaikan

User perlu masuk ke aplikasi, menyimpan token untuk mockup, dan diarahkan ke dashboard.

## Konsep Utama

Form auth adalah container component: ia memegang state input, loading, error, dan pemanggilan API. Route page hanya memasang form ke URL React Router.

## Pilihan Teknologi Yang Tersedia

- Controlled form React.
- React Hook Form.
- TanStack Form.
- Auth library.

## Pilihan Yang Dipakai Di Tutorial Ini

Controlled form sederhana dengan komponen shadcn/ui agar pemula mudah membaca flow.

## Struktur Folder Yang Akan Dibuat

```text
src/features/auth/authApi.ts
src/features/auth/LoginForm.tsx
src/features/auth/RegisterForm.tsx
src/routes/LoginRoute.tsx
src/routes/RegisterRoute.tsx
```

## Command Yang Harus Dijalankan

```bash
cd frontend
mkdir -p src/features/auth src/routes
pnpm dlx shadcn@latest add button input label card alert
```

## Full Source Code Untuk Setiap File Yang Dibuat

```ts
// frontend/src/features/auth/authApi.ts
import { apiClient } from "@/lib/api/apiClient";
import type { User } from "@/types/domain";

export type AuthResponse = User & {
  userId: string;
  accessToken: string;
  refreshToken: string;
};

export function login(input: { email: string; password: string }) {
  return apiClient<AuthResponse>("/auth/login", { method: "POST", body: input, auth: false });
}

export function register(input: { email: string; name: string; password: string }) {
  return apiClient<AuthResponse>("/auth/register", { method: "POST", body: input, auth: false });
}

export function me() {
  return apiClient<User>("/auth/me");
}

export function logout(refreshToken: string) {
  return apiClient<void>("/auth/logout", { method: "POST", body: { refreshToken } });
}
```

```tsx
// frontend/src/features/auth/LoginForm.tsx
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { tokenStore } from "@/lib/auth/tokenStore";
import { toUserMessage } from "@/lib/errors/errorMapper";
import { FormEvent, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { login } from "./authApi";

export function LoginForm() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("owner@example.com");
  const [password, setPassword] = useState("Password123!");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError("");
    try {
      const result = await login({ email, password });
      tokenStore.setTokens(result.accessToken, result.refreshToken);
      navigate("/dashboard", { replace: true });
    } catch (err) {
      setError(toUserMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-4">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Login</CardTitle>
          <p className="text-sm text-muted-foreground">Masuk ke SpringReact Modular SaaS Mockup.</p>
        </CardHeader>
        <CardContent>
          <form onSubmit={onSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email">Email</Label>
              <Input id="email" value={email} onChange={(event) => setEmail(event.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password">Password</Label>
              <Input id="password" type="password" value={password} onChange={(event) => setPassword(event.target.value)} />
            </div>
            {error ? <Alert variant="destructive"><AlertDescription>{error}</AlertDescription></Alert> : null}
            <Button disabled={loading} className="w-full">{loading ? "Memproses..." : "Login"}</Button>
            <p className="text-center text-sm text-muted-foreground">
              Belum punya akun? <Link className="font-medium text-foreground" to="/register">Register</Link>
            </p>
          </form>
        </CardContent>
      </Card>
    </main>
  );
}
```

```tsx
// frontend/src/features/auth/RegisterForm.tsx
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { tokenStore } from "@/lib/auth/tokenStore";
import { toUserMessage } from "@/lib/errors/errorMapper";
import { FormEvent, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { register } from "./authApi";

export function RegisterForm() {
  const navigate = useNavigate();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError("");
    try {
      const result = await register({ name, email, password });
      tokenStore.setTokens(result.accessToken, result.refreshToken);
      navigate("/dashboard", { replace: true });
    } catch (err) {
      setError(toUserMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-4">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Register</CardTitle>
          <p className="text-sm text-muted-foreground">Buat akun baru.</p>
        </CardHeader>
        <CardContent>
          <form onSubmit={onSubmit} className="space-y-4">
            <div className="space-y-2"><Label htmlFor="name">Nama</Label><Input id="name" value={name} onChange={(event) => setName(event.target.value)} /></div>
            <div className="space-y-2"><Label htmlFor="email">Email</Label><Input id="email" value={email} onChange={(event) => setEmail(event.target.value)} /></div>
            <div className="space-y-2"><Label htmlFor="password">Password</Label><Input id="password" type="password" value={password} onChange={(event) => setPassword(event.target.value)} /></div>
            {error ? <Alert variant="destructive"><AlertDescription>{error}</AlertDescription></Alert> : null}
            <Button disabled={loading} className="w-full">{loading ? "Memproses..." : "Register"}</Button>
            <p className="text-center text-sm text-muted-foreground">
              Sudah punya akun? <Link className="font-medium text-foreground" to="/login">Login</Link>
            </p>
          </form>
        </CardContent>
      </Card>
    </main>
  );
}
```

```tsx
// frontend/src/routes/LoginRoute.tsx
import { LoginForm } from "@/features/auth/LoginForm";

export function LoginRoute() {
  return <LoginForm />;
}
```

```tsx
// frontend/src/routes/RegisterRoute.tsx
import { RegisterForm } from "@/features/auth/RegisterForm";

export function RegisterRoute() {
  return <RegisterForm />;
}
```

## Penjelasan Kode Penting

Login form menyimpan access token dan refresh token setelah backend mengembalikan auth response. Ini cukup untuk mockup, tetapi httpOnly cookie lebih aman untuk production. shadcn/ui dipakai untuk `Card`, `Input`, `Label`, `Button`, dan `Alert` agar tampilan form konsisten.

## Cara Menjalankan

```bash
cd frontend
pnpm dev
```

## Cara Test Manual

Buka `/login`, gunakan `owner@example.com / Password123!`, lalu pastikan redirect ke `/dashboard`.

## Troubleshooting

- Jika CORS error, cek backend config dan pastikan `http://localhost:5173` diizinkan.
- Jika login berhasil tapi dashboard redirect balik, token gagal disimpan.
- Jika komponen shadcn tidak ditemukan, jalankan `pnpm dlx shadcn@latest add button input label card alert`.

## Checklist Akhir

- [ ] Login route tersedia.
- [ ] Register route tersedia.
- [ ] Token disimpan untuk mockup.
- [ ] Error handling tampil di form.
- [ ] Komponen form memakai shadcn/ui.

## File Lanjutan Berikutnya

Lanjut ke [06-dashboard-organization-project-task.md](06-dashboard-organization-project-task.md).

