# Frontend 07 - Testing Frontend

## Tujuan File

Menambahkan contoh test untuk API client dan LoginForm di React Vite.

## Problem Yang Diselesaikan

API client dan auth flow adalah jalur kritis. Jika rusak, seluruh dashboard tidak bisa dipakai.

## Konsep Utama

- API client test memalsukan `fetch`.
- Component test merender form dan mensimulasikan input user.
- React Router test memakai `MemoryRouter`.
- Dashboard rendering test memastikan loading dan empty state tidak hilang.

## Pilihan Teknologi Yang Tersedia

- Vitest.
- Jest.
- Testing Library.
- Playwright.

## Pilihan Yang Dipakai Di Tutorial Ini

Vitest + Testing Library untuk unit/component test. Playwright bisa ditambahkan untuk E2E.

## Struktur Folder Yang Akan Dibuat

```text
src/test/setup.ts
src/lib/api/apiClient.test.ts
src/features/auth/LoginForm.test.tsx
vitest.config.ts
```

## Command Yang Harus Dijalankan

```bash
cd frontend
pnpm test
```

## Full Source Code Untuk Setiap File Yang Dibuat

```ts
// frontend/vitest.config.ts
import path from "node:path";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  test: {
    environment: "jsdom",
    setupFiles: ["./src/test/setup.ts"],
  },
});
```

```ts
// frontend/src/test/setup.ts
import "@testing-library/jest-dom/vitest";
```

```ts
// frontend/src/lib/api/apiClient.test.ts
import { describe, expect, it, vi } from "vitest";
import { apiClient } from "./apiClient";

describe("apiClient", () => {
  it("unwraps successful response", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => ({
      status: 200,
      json: async () => ({ success: true, data: { id: "1" }, errors: [] }),
    })));

    await expect(apiClient<{ id: string }>("/test", { auth: false })).resolves.toEqual({ id: "1" });
  });

  it("throws on error response", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => ({
      status: 401,
      json: async () => ({ success: false, data: null, errors: [{ code: "UNAUTHORIZED", message: "No token" }] }),
    })));

    await expect(apiClient("/test", { auth: false })).rejects.toThrow("No token");
  });
});
```

```tsx
// frontend/src/features/auth/LoginForm.test.tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it } from "vitest";
import { LoginForm } from "./LoginForm";

describe("LoginForm", () => {
  it("renders seed login form", () => {
    render(<LoginForm />, { wrapper: MemoryRouter });
    expect(screen.getByRole("heading", { name: "Login" })).toBeInTheDocument();
    expect(screen.getByDisplayValue("owner@example.com")).toBeInTheDocument();
  });

  it("allows changing email", async () => {
    render(<LoginForm />, { wrapper: MemoryRouter });
    const input = screen.getByDisplayValue("owner@example.com");
    await userEvent.clear(input);
    await userEvent.type(input, "admin@example.com");
    expect(screen.getByDisplayValue("admin@example.com")).toBeInTheDocument();
  });
});
```

## Penjelasan Kode Penting

`fetch` di-stub agar test tidak memanggil backend sungguhan. `LoginForm` dibungkus `MemoryRouter` karena component memakai `useNavigate` dan `Link` dari React Router.

## Cara Menjalankan

```bash
cd frontend
pnpm test
```

## Cara Test Manual

Selain automated test, buka browser dan jalankan login seed user.

## Troubleshooting

- Jika `userEvent` belum ada, install `@testing-library/user-event`.
- Jika `window.localStorage` error, pastikan environment `jsdom`.
- Jika alias `@/` error di Vitest, pastikan `resolve.alias` ada di `vitest.config.ts`.
- Jika shadcn component gagal import, pastikan command `shadcn add` sudah dijalankan.

## Checklist Akhir

- [ ] `apiClient.test.ts` tersedia.
- [ ] `LoginForm.test.tsx` tersedia.
- [ ] Component test berjalan di jsdom.
- [ ] React Router diuji dengan `MemoryRouter`.
- [ ] Manual auth flow tetap diuji di browser.

## File Lanjutan Berikutnya

Lanjut ke [../full-flow/01-run-local-development.md](../full-flow/01-run-local-development.md).

