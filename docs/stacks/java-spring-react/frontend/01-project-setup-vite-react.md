# Frontend 01 - Project Setup React Vite, Tailwind, Dan shadcn/ui

## Tujuan File

Membuat frontend React dengan Vite, TypeScript, Tailwind CSS, React Router, dan shadcn/ui.

## Problem Yang Diselesaikan

Frontend untuk mockup dashboard SaaS ini adalah aplikasi client-side. Kita butuh setup yang ringan, cepat untuk development, mudah dipahami pemula, dan siap memakai komponen UI konsisten dari shadcn/ui.

## Konsep Utama

React adalah library UI berbasis component. Vite adalah build tool dan dev server modern yang cepat untuk aplikasi React SPA. React Router mengurus route seperti `/login`, `/register`, dan `/dashboard`. Tailwind memberi utility CSS, sementara shadcn/ui memberi komponen siap pakai yang tetap bisa dimodifikasi karena source component disalin ke project.

## Pilihan Teknologi Yang Tersedia

- React Vite SPA: cocok untuk dashboard internal dan aplikasi client-side.
- Framework SSR React: cocok jika butuh rendering server-side, SEO kuat, dan routing server-first.`r`n- Remix atau TanStack Start: alternatif full-stack React.
- Package manager: npm, yarn, pnpm, bun.
- UI kit: shadcn/ui, MUI, Chakra UI, Mantine, atau komponen custom.

## Pilihan Yang Dipakai Di Tutorial Ini

- React Vite SPA.
- TypeScript.
- Tailwind CSS.
- shadcn/ui.
- React Router.
- pnpm.

## Struktur Folder Yang Akan Dibuat

```text
frontend/
  index.html
  package.json
  vite.config.ts
  tailwind.config.ts
  postcss.config.js
  components.json
  src/
    main.tsx
    App.tsx
    routes/
      LoginRoute.tsx
      RegisterRoute.tsx
      DashboardRoute.tsx
    components/
      ui/
      layout/
      forms/
    features/
      auth/
      organizations/
      projects/
      tasks/
    lib/
      api/
      auth/
      errors/
      utils/
    types/
```

## Command Yang Harus Dijalankan

```bash
pnpm create vite frontend --template react-ts
cd frontend
pnpm install
pnpm add react-router-dom @tanstack/react-query lucide-react class-variance-authority clsx tailwind-merge
pnpm add -D tailwindcss postcss autoprefixer tailwindcss-animate
pnpm exec tailwindcss init -p
pnpm dlx shadcn@latest init
pnpm dlx shadcn@latest add button input label card textarea select alert
pnpm add -D vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom
```

Pilihan prompt shadcn/ui:

- Style: Default
- Base color: Slate
- CSS variables: Yes
- `tailwind.config.ts`: `tailwind.config.ts`
- Global CSS: `src/index.css`
- Components alias: `@/components`
- Utils alias: `@/lib/utils`

## Full Source Code Untuk Setiap File Yang Dibuat

```dotenv
# frontend/.env.example
VITE_API_BASE_URL=http://localhost:8080/api
```

```html
<!-- frontend/index.html -->
<!doctype html>
<html lang="id">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>SpringReact Modular SaaS Mockup</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

```ts
// frontend/vite.config.ts
import path from "node:path";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  server: {
    port: 5173,
  },
  preview: {
    host: "0.0.0.0",
    port: 3000,
  },
});
```

```ts
// frontend/tailwind.config.ts
import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: ["class"],
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
      colors: {
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};

export default config;
```

```json
// frontend/components.json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "default",
  "rsc": false,
  "tsx": true,
  "tailwind": {
    "config": "tailwind.config.ts",
    "css": "src/index.css",
    "baseColor": "slate",
    "cssVariables": true,
    "prefix": ""
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  }
}
```

```css
/* frontend/src/index.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 210 40% 98%;
    --foreground: 222.2 84% 4.9%;
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    --primary: 222.2 47.4% 11.2%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96.1%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 222.2 84% 4.9%;
    --radius: 0.5rem;
  }

  * {
    @apply border-border;
  }

  body {
    @apply bg-background text-foreground;
  }
}
```

```tsx
// frontend/src/main.tsx
import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import "./index.css";
import { App } from "./RootApp";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </React.StrictMode>,
);
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

```json
// frontend/package.json
{
  "scripts": {
    "dev": "vite --host 0.0.0.0",
    "build": "tsc -b && vite build",
    "preview": "vite preview --host 0.0.0.0 --port 3000",
    "lint": "eslint .",
    "test": "vitest"
  },
  "dependencies": {
    "@tanstack/react-query": "latest",
    "class-variance-authority": "latest",
    "clsx": "latest",
    "lucide-react": "latest",
    "react": "latest",
    "react-dom": "latest",
    "react-router-dom": "latest",
    "tailwind-merge": "latest"
  },
  "devDependencies": {
    "@testing-library/jest-dom": "latest",
    "@testing-library/react": "latest",
    "@testing-library/user-event": "latest",
    "@types/node": "latest",
    "@types/react": "latest",
    "@types/react-dom": "latest",
    "@vitejs/plugin-react": "latest",
    "autoprefixer": "latest",
    "eslint": "latest",
    "jsdom": "latest",
    "postcss": "latest",
    "tailwindcss": "latest",
    "tailwindcss-animate": "latest",
    "typescript": "latest",
    "vite": "latest",
    "vitest": "latest"
  }
}
```

## Penjelasan Kode Penting

- `VITE_API_BASE_URL` boleh dibaca browser karena prefix `VITE_`. Jangan taruh secret di env frontend.
- shadcn/ui menyalin source component ke `src/components/ui`, jadi komponen bisa disesuaikan dengan kebutuhan project.
- Vite dev berjalan di `5173`, sedangkan Docker preview diset ke `3000` agar URL demo tetap mudah.

## Cara Menjalankan

```bash
cd frontend
pnpm dev
pnpm build
pnpm preview
```

## Cara Test Manual

Untuk development, buka `http://localhost:5173` setelah `pnpm dev`. Untuk preview hasil build, buka `http://localhost:3000` setelah `pnpm build` lalu `pnpm preview`. Route `/` akan redirect ke `/dashboard`, lalu guard auth akan mengarahkan user ke `/login` setelah file auth dibuat.

## Troubleshooting

- Jika `pnpm` belum ada, aktifkan Corepack: `corepack enable`.
- Jika shadcn gagal membaca alias `@`, cek `vite.config.ts` dan `tsconfig.json`.
- Jika Tailwind tidak aktif, cek `content` di `tailwind.config.ts`.
- Jika port 5173 bentrok, ubah `server.port`.

## Checklist Akhir

- [ ] React Vite dibuat.
- [ ] TypeScript aktif.
- [ ] Tailwind aktif.
- [ ] shadcn/ui diinisialisasi.
- [ ] React Router tersedia.
- [ ] Struktur folder feature tersedia.

## File Lanjutan Berikutnya

Lanjut ke [02-frontend-architecture.md](02-frontend-architecture.md).




