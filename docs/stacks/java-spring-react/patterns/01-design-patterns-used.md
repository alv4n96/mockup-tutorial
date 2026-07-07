# Patterns 01 - Design Patterns Yang Dipakai

## Tujuan File

Menjelaskan design pattern yang dipakai di SpringReact Modular SaaS Mockup dan pattern yang tidak dipakai.

## Problem Yang Diselesaikan

Pattern sering dipakai berlebihan. File ini membantu memakai pattern sebagai alat, bukan tujuan.

## Konsep Utama

Design pattern adalah nama umum untuk solusi berulang terhadap problem desain software. Refactoring.Guru membagi pattern menjadi creational, structural, dan behavioral.

## Pilihan Teknologi Yang Tersedia

- Tanpa pattern eksplisit.
- Pattern secukupnya mengikuti kebutuhan.
- Pattern-heavy architecture.

## Pilihan Yang Dipakai Di Tutorial Ini

Pattern secukupnya. Kita memakai pattern yang natural muncul dari Spring, JPA, REST DTO, dan React.

## Struktur Folder Yang Akan Dibuat

```text
patterns/
  01-design-patterns-used.md
  02-refactoring-guru-mapping.md
```

## Command Yang Harus Dijalankan

Tidak ada command.

## Full Source Code Untuk Setiap File Yang Dibuat

Repository Pattern:

```java
// backend/src/main/java/com/example/springreact/modules/project/infrastructure/ProjectRepository.java
package com.example.springreact.modules.project.infrastructure;

import com.example.springreact.modules.project.domain.Project;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProjectRepository extends JpaRepository<Project, UUID> {
  List<Project> findByOrganizationIdOrderByCreatedAtDesc(UUID organizationId);
  Optional<Project> findByIdAndOrganizationId(UUID id, UUID organizationId);
}
```

DTO Pattern:

```java
// backend/src/main/java/com/example/springreact/modules/project/presentation/ProjectDtos.java
package com.example.springreact.modules.project.presentation;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public final class ProjectDtos {
  private ProjectDtos() {}
  public record UpsertProjectRequest(@NotBlank @Size(max = 160) String name, @Size(max = 2000) String description) {}
  public record ProjectResponse(UUID id, UUID organizationId, String name, String description) {}
}
```

Simple Factory:

```java
// backend/src/main/java/com/example/springreact/modules/project/domain/Project.java
public static Project create(UUID organizationId, String name, String description) {
  Project project = new Project();
  project.id = UUID.randomUUID();
  project.organizationId = organizationId;
  project.name = name;
  project.description = description;
  project.createdAt = OffsetDateTime.now();
  project.updatedAt = project.createdAt;
  return project;
}
```

Strategy Pattern:

```java
// backend/src/main/java/com/example/springreact/modules/organization/application/OrganizationAccessChecker.java
public void requireRole(UUID organizationId, UUID userId, Set<OrganizationRole> allowedRoles) {
  OrganizationRole role = members.findByOrganizationIdAndUserId(organizationId, userId)
      .orElseThrow(() -> new ForbiddenException("You are not a member of this organization"))
      .getRole();
  if (!allowedRoles.contains(role)) {
    throw new ForbiddenException("Your organization role cannot perform this action");
  }
}
```

Frontend Custom Hook:

```ts
// frontend/src/features/auth/useRequireAuth.ts
export function useRequireAuth() {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  useEffect(() => {
    if (!tokenStore.getAccessToken()) router.replace("/login");
    else setReady(true);
  }, [router]);
  return ready;
}
```

Frontend Adapter API client:

```ts
// frontend/src/lib/api/apiClient.ts
export async function apiClient<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const response = await fetch(`${baseUrl}${path}`, {
    method: options.method ?? "GET",
    headers,
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });
  return unwrapResponse((await response.json()) as ApiResponse<T>, response.status);
}
```

## Penjelasan Kode Penting

- Repository menyelesaikan problem akses persistence.
- DTO memisahkan API contract dari entity.
- Factory method menyatukan aturan pembuatan domain object.
- Strategy cocok untuk variasi authorization rule.
- Adapter membungkus API HTTP agar feature tidak bergantung ke detail `fetch`.
- Facade dipakai di `AuthService` dan feature API agar flow lintas detail lebih sederhana.
- Builder dipakai di test data saat object makin kompleks.
- Template Method tidak dipaksakan; baru relevan jika banyak validation flow seragam.

Pattern yang tidak dipakai:

- Singleton manual: Spring bean sudah mengelola lifecycle.
- Abstract Factory: belum ada keluarga object kompleks.
- Observer: belum ada event realtime.
- Command Pattern penuh: CRUD sederhana belum butuh command bus.
- Decorator: belum ada kebutuhan membungkus behavior runtime.

## Cara Menjalankan

Tidak ada command. Baca file ini saat menulis kode agar pattern tidak dipakai berlebihan.

## Cara Test Manual

Review code: jika sebuah pattern tidak menyelesaikan problem nyata, hapus abstraksinya.

## Troubleshooting

- Jika service penuh if permission, ekstrak strategy access checker.
- Jika controller mengembalikan entity, buat DTO.
- Jika frontend banyak copy-paste fetch, pakai API adapter.

## Checklist Akhir

- [ ] Repository dipakai untuk persistence.
- [ ] DTO dipakai untuk API.
- [ ] Factory method dipakai untuk create domain object.
- [ ] Strategy dipakai untuk tenant/permission rule.
- [ ] Pattern yang belum perlu tidak dipaksakan.

## File Lanjutan Berikutnya

Lanjut ke [02-refactoring-guru-mapping.md](02-refactoring-guru-mapping.md).


