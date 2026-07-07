# Frontend 03 - Layout, Routing, Dan Protected Dashboard

## Tujuan File

Membuat routing login, register, dashboard, dan guard sederhana untuk protected route di React Vite.

## Problem Yang Diselesaikan

User yang belum login tidak boleh masuk dashboard. Karena Vite SPA berjalan di browser, guard dibuat dengan React Router dan localStorage untuk mockup.

## Konsep Utama

Untuk mockup, access token disimpan di localStorage. Ini mudah dipahami, tetapi rentan XSS. Produksi lebih aman memakai httpOnly secure cookie dan backend session/refresh endpoint yang dikontrol ketat.

## Pilihan Teknologi Yang Tersedia

- Client-side guard dengan React Router.
- Server-side session lewat BFF.
- httpOnly cookie dengan refresh endpoint.
- Auth library khusus.

## Pilihan Yang Dipakai Di Tutorial Ini

Client-side guard untuk mockup, karena access token ada di browser.

## Struktur Folder Yang Akan Dibuat

```text
src/lib/auth/tokenStore.ts
src/features/auth/useRequireAuth.ts
src/routes/DashboardRoute.tsx
src/RootApp.tsx
```

## Command Yang Harus Dijalankan

```bash
cd frontend
mkdir -p src/lib/auth src/features/auth src/routes
pnpm add react-router-dom
```

## Full Source Code Untuk Setiap File Yang Dibuat

```ts
// frontend/src/lib/auth/tokenStore.ts
const ACCESS_TOKEN_KEY = "springreact.accessToken";
const REFRESH_TOKEN_KEY = "springreact.refreshToken";

export const tokenStore = {
  getAccessToken() {
    return window.localStorage.getItem(ACCESS_TOKEN_KEY);
  },
  setTokens(accessToken: string, refreshToken: string) {
    window.localStorage.setItem(ACCESS_TOKEN_KEY, accessToken);
    window.localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
  },
  getRefreshToken() {
    return window.localStorage.getItem(REFRESH_TOKEN_KEY);
  },
  clear() {
    window.localStorage.removeItem(ACCESS_TOKEN_KEY);
    window.localStorage.removeItem(REFRESH_TOKEN_KEY);
  },
};
```

```ts
// frontend/src/features/auth/useRequireAuth.ts
import { tokenStore } from "@/lib/auth/tokenStore";
import { useNavigate } from "react-router-dom";
import { useEffect, useState } from "react";

export function useRequireAuth() {
  const navigate = useNavigate();
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!tokenStore.getAccessToken()) {
      navigate("/login", { replace: true });
      return;
    }
    setReady(true);
  }, [navigate]);

  return ready;
}
```

```tsx
// frontend/src/routes/DashboardRoute.tsx
import { DashboardShell } from "@/components/layout/DashboardShell";
import { LoadingState } from "@/components/ui/LoadingState";
import { useRequireAuth } from "@/features/auth/useRequireAuth";

export function DashboardRoute() {
  const ready = useRequireAuth();
  if (!ready) return <LoadingState label="Memeriksa sesi..." />;

  return (
    <DashboardShell>
      <section className="space-y-4">
        <div>
          <h1 className="text-2xl font-semibold text-foreground">Dashboard</h1>
          <p className="text-sm text-muted-foreground">Kelola organization, project, dan task.</p>
        </div>
      </section>
    </DashboardShell>
  );
}
```

```tsx
// frontend/src/RootApp.tsx
import { Navigate, Route, Routes } from "react-router-dom";
import { DashboardRoute } from "@/routes/DashboardRoute";
import { LoginRoute } from "@/routes/LoginRoute";
import { RegisterRoute } from "@/routes/RegisterRoute";

export function App() {
  return (
    <Routes>
      <Route path="/" element={<Navigate to="/dashboard" replace />} />
      <Route path="/login" element={<LoginRoute />} />
      <Route path="/register" element={<RegisterRoute />} />
      <Route path="/dashboard" element={<DashboardRoute />} />
    </Routes>
  );
}
```

## Penjelasan Kode Penting

Guard ini berjalan di client karena localStorage hanya tersedia di browser. Kalau nanti auth dipindah ke httpOnly cookie, guard bisa membaca endpoint `/api/auth/me` atau memakai BFF, bukan membaca token langsung.

## Cara Menjalankan

```bash
cd frontend
pnpm dev
```

## Cara Test Manual

Buka `/dashboard` tanpa token. Browser harus pindah ke `/login` setelah halaman login dibuat.

## Troubleshooting

- Jika redirect loop, pastikan route login tidak memanggil `useRequireAuth`.
- Jika localStorage error di test, pakai environment `jsdom`.
- Jika token expired, API client dapat diperluas untuk memanggil refresh endpoint.

## Checklist Akhir

- [ ] Token store tersedia.
- [ ] Dashboard protected.
- [ ] React Router digunakan.
- [ ] Risiko localStorage dijelaskan.

## File Lanjutan Berikutnya

Lanjut ke [04-api-client-response-error.md](04-api-client-response-error.md).


