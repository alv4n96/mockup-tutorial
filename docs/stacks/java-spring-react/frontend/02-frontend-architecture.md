# Frontend 02 - Frontend Architecture React Vite

## Tujuan File

Membuat struktur frontend Vite yang memisahkan route, UI shadcn, layout, feature, API client, auth helper, dan type.

## Problem Yang Diselesaikan

Tanpa struktur feature, component dashboard, auth, API, dan state akan bercampur di route. Vite memberi entry point `src/main.tsx`, sementara React Router memetakan halaman dari folder `src/routes`.

## Konsep Utama

- `routes`: halaman yang dipasang ke React Router.
- `components/ui`: komponen shadcn/ui yang digenerate ke project.
- `components/layout`: layout reusable seperti dashboard shell.
- `features`: logic per business feature.
- `lib`: API, auth, error mapper, utility.
- `types`: type lintas feature.

## Pilihan Teknologi Yang Tersedia

- Folder by route.
- Folder by component type.
- Folder by feature.
- Atomic design.

## Pilihan Yang Dipakai Di Tutorial Ini

Hybrid: route di `routes`, business logic di `features`, komponen dasar dari shadcn di `components/ui`.

## Struktur Folder Yang Akan Dibuat

```text
src/components/ui/button.tsx
src/components/ui/input.tsx
src/components/ui/card.tsx
src/components/ui/EmptyState.tsx
src/components/ui/LoadingState.tsx
src/components/layout/DashboardShell.tsx
src/lib/utils.ts
src/types/domain.ts
src/routes/
```

## Command Yang Harus Dijalankan

```bash
cd frontend
mkdir -p src/components/ui src/components/layout src/lib src/types src/routes
pnpm dlx shadcn@latest add button input label card textarea select alert
```

## Full Source Code Untuk Setiap File Yang Dibuat

```ts
// frontend/src/lib/utils.ts
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

```tsx
// frontend/src/components/ui/LoadingState.tsx
import { Card, CardContent } from "@/components/ui/card";

export function LoadingState({ label = "Memuat data..." }: { label?: string }) {
  return (
    <Card>
      <CardContent className="p-4 text-sm text-muted-foreground">{label}</CardContent>
    </Card>
  );
}
```

```tsx
// frontend/src/components/ui/EmptyState.tsx
import { Card, CardContent } from "@/components/ui/card";

export function EmptyState({ title, description }: { title: string; description: string }) {
  return (
    <Card className="border-dashed">
      <CardContent className="p-6">
        <h3 className="text-sm font-semibold text-foreground">{title}</h3>
        <p className="mt-1 text-sm text-muted-foreground">{description}</p>
      </CardContent>
    </Card>
  );
}
```

```tsx
// frontend/src/components/layout/DashboardShell.tsx
import { Button } from "@/components/ui/button";
import { tokenStore } from "@/lib/auth/tokenStore";
import { Link, useNavigate } from "react-router-dom";

export function DashboardShell({ children }: { children: React.ReactNode }) {
  const navigate = useNavigate();

  function logout() {
    tokenStore.clear();
    navigate("/login", { replace: true });
  }

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b bg-card">
        <div className="mx-auto flex h-14 max-w-6xl items-center justify-between px-4">
          <Link to="/dashboard" className="text-sm font-semibold text-foreground">
            SpringReact Modular SaaS Mockup
          </Link>
          <nav className="flex items-center gap-3 text-sm text-muted-foreground">
            <Link to="/dashboard">Dashboard</Link>
            <Button type="button" variant="outline" size="sm" onClick={logout}>Logout</Button>
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-4 py-6">{children}</main>
    </div>
  );
}
```

```ts
// frontend/src/types/domain.ts
export type OrganizationRole = "OWNER" | "ADMIN" | "MEMBER";
export type TaskStatus = "TODO" | "IN_PROGRESS" | "DONE";
export type TaskPriority = "LOW" | "MEDIUM" | "HIGH";

export type User = {
  id: string;
  email: string;
  name: string;
};

export type Organization = {
  id: string;
  name: string;
  slug: string;
};

export type Project = {
  id: string;
  organizationId: string;
  name: string;
  description: string | null;
};

export type Task = {
  id: string;
  projectId: string;
  title: string;
  description: string | null;
  status: TaskStatus;
  priority: TaskPriority;
  dueDate: string | null;
};
```

## Penjelasan Kode Penting

`DashboardShell` hanya layout, bukan pengambil data. Ini menjaga Container/Presentational pattern: route atau feature container mengurus data, component UI mengurus tampilan. `Button`, `Card`, dan input lain berasal dari shadcn/ui agar styling konsisten.

## Cara Menjalankan

```bash
cd frontend
pnpm dev
```

## Cara Test Manual

Import `DashboardShell` ke route sementara dan pastikan tombol shadcn tampil dengan styling Tailwind.

## Troubleshooting

- Jika alias `@/*` gagal, cek `vite.config.ts` dan `tsconfig.json`.
- Jika class Tailwind tidak muncul, cek `content` di `tailwind.config.ts`.
- Jika komponen shadcn tidak ditemukan, jalankan ulang `pnpm dlx shadcn@latest add button card input`.

## Checklist Akhir

- [ ] Komponen shadcn tersedia.
- [ ] Layout dashboard tersedia.
- [ ] Type domain tersedia.
- [ ] Folder feature dan route siap diisi.

## File Lanjutan Berikutnya

Lanjut ke [03-layout-routing-auth.md](03-layout-routing-auth.md).

