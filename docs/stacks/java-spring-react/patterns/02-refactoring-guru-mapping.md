# Patterns 02 - Mapping Ke Refactoring.Guru

## Tujuan File

Memetakan pattern di project ini ke konsep Refactoring.Guru tanpa memaksakan semua pattern.

## Problem Yang Diselesaikan

Developer sering membaca katalog pattern lalu mencoba memasukkan semuanya. Mapping ini menjelaskan mana yang relevan.

## Konsep Utama

Refactoring.Guru adalah referensi konsep pattern. Kita memakai konsepnya sebagai bahasa desain, bukan checklist wajib.

## Pilihan Teknologi Yang Tersedia

- Mengikuti katalog pattern lengkap.
- Memakai pattern hanya saat problem muncul.
- Menghindari pattern sama sekali.

## Pilihan Yang Dipakai Di Tutorial Ini

Memakai pattern saat membantu readability, boundary, dan testability.

## Struktur Folder Yang Akan Dibuat

Tidak ada folder baru.

## Command Yang Harus Dijalankan

Tidak ada command.

## Full Source Code Untuk Setiap File Yang Dibuat

Builder test data:

```java
// backend/src/test/java/com/example/springreact/TestProjectBuilder.java
package com.example.springreact;

import com.example.springreact.modules.project.domain.Project;
import java.util.UUID;

public class TestProjectBuilder {
  private UUID organizationId = UUID.randomUUID();
  private String name = "Test Project";
  private String description = "Test Description";

  public TestProjectBuilder organizationId(UUID organizationId) {
    this.organizationId = organizationId;
    return this;
  }

  public TestProjectBuilder name(String name) {
    this.name = name;
    return this;
  }

  public Project build() {
    return Project.create(organizationId, name, description);
  }
}
```

Facade service:

```java
// backend/src/main/java/com/example/springreact/modules/identity/application/AuthService.java
public AuthResponse login(String email, String password) {
  User user = users.findByEmail(email.toLowerCase())
      .orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHORIZED, "Invalid email or password"));
  if (!passwordEncoder.matches(password, user.getPasswordHash())) {
    throw new BusinessException(ErrorCode.UNAUTHORIZED, "Invalid email or password");
  }
  return issueTokens(user);
}
```

Container / Presentational:

```tsx
// frontend/src/features/tasks/TaskBoard.tsx
export function TaskBoard({ tasks, onMove }: { tasks: Task[]; onMove: (task: Task, status: TaskStatus) => void }) {
  return <div>{tasks.map((task) => <button key={task.id} onClick={() => onMove(task, "DONE")}>{task.title}</button>)}</div>;
}
```

Provider Pattern:

`	sx
// frontend/src/providers.tsx
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";

export function Providers({ children }: { children: React.ReactNode }) {
  const [client] = useState(() => new QueryClient());
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}
```

Strategy render status:

```ts
// frontend/src/features/tasks/taskStatusView.ts
import type { TaskStatus } from "@/types/domain";

export const taskStatusLabel: Record<TaskStatus, string> = {
  TODO: "Todo",
  IN_PROGRESS: "In Progress",
  DONE: "Done",
};
```

## Penjelasan Kode Penting

Mapping:

- Repository Pattern: `ProjectRepository`, `TaskRepository`.
- DTO Pattern: `AuthDtos`, `ProjectDtos`, `TaskDtos`.
- Factory Method / Simple Factory: `User.register`, `Project.create`, `Task.create`.
- Strategy Pattern: `OrganizationAccessChecker`, status rendering map.
- Builder Pattern: `TestProjectBuilder`.
- Adapter Pattern: `apiClient`, JPA repository adapter.
- Facade Pattern: `AuthService`, feature API modules.
- Template Method: belum wajib; pakai jika validation flow antar service mulai sama.
- Container/Presentational: `DashboardRoute` sebagai container, `TaskBoard` sebagai presentational.
- Custom Hook: `useRequireAuth`.
- Provider: `Providers` untuk React Query.

Kesalahan umum:

- Membuat interface repository berlapis tanpa kebutuhan.
- Memakai entity sebagai response DTO.
- Menaruh business rule di controller.
- Membuat provider global untuk state yang hanya dipakai satu component.

## Cara Menjalankan

Tidak ada command.

## Cara Test Manual

Saat review PR, tanyakan: pattern ini mengurangi kompleksitas atau hanya menambah nama?

## Troubleshooting

- Jika pattern membuat file terlalu banyak untuk CRUD kecil, sederhanakan.
- Jika logic tenant tersebar, satukan di strategy/facade access checker.
- Jika test setup rumit, gunakan builder test data.

## Checklist Akhir

- [ ] Semua pattern punya problem nyata.
- [ ] Pattern backend dan frontend dipetakan.
- [ ] Refactoring.Guru dipakai sebagai referensi konsep.
- [ ] Pattern yang tidak relevan ditolak dengan alasan.

## File Lanjutan Berikutnya

Lanjut ke [../mock-flow/00-mockup-ready-fullstack.md](../mock-flow/00-mockup-ready-fullstack.md).





