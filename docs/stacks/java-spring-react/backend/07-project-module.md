# Backend 07 - Project Module

## Tujuan File

Membuat CRUD project yang selalu milik organization.

## Problem Yang Diselesaikan

Project adalah data tenant. Hanya member organization yang boleh melihat atau mengubah project di organization tersebut.

## Konsep Utama

Setiap query project harus memfilter `organizationId` dan memanggil tenant access check.

## Pilihan Teknologi Yang Tersedia

- Letakkan check di controller.
- Letakkan check di repository.
- Letakkan check di application service.

## Pilihan Yang Dipakai Di Tutorial Ini

Check dilakukan di application service agar controller tetap tipis dan repository tetap fokus data access.

## Struktur Folder Yang Akan Dibuat

```text
modules/project/
  domain/Project.java
  application/ProjectService.java
  infrastructure/ProjectRepository.java
  presentation/ProjectController.java
  presentation/ProjectDtos.java
```

## Command Yang Harus Dijalankan

```bash
cd backend
mkdir -p src/main/java/com/example/springreact/modules/project/{domain,application,infrastructure,presentation}
```

## Full Source Code Untuk Setiap File Yang Dibuat

```java
// backend/src/main/java/com/example/springreact/modules/project/domain/Project.java
package com.example.springreact.modules.project.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "projects")
@NoArgsConstructor
public class Project {
  @Id private UUID id;
  @Column(name = "organization_id", nullable = false) private UUID organizationId;
  @Column(nullable = false) private String name;
  @Column private String description;
  @Column(name = "created_at", nullable = false) private OffsetDateTime createdAt;
  @Column(name = "updated_at", nullable = false) private OffsetDateTime updatedAt;

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

  public void update(String name, String description) {
    this.name = name;
    this.description = description;
    this.updatedAt = OffsetDateTime.now();
  }
}
```

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

```java
// backend/src/main/java/com/example/springreact/modules/project/application/ProjectService.java
package com.example.springreact.modules.project.application;

import com.example.springreact.common.error.NotFoundException;
import com.example.springreact.modules.organization.application.OrganizationAccessChecker;
import com.example.springreact.modules.project.domain.Project;
import com.example.springreact.modules.project.infrastructure.ProjectRepository;
import com.example.springreact.modules.project.presentation.ProjectDtos.ProjectResponse;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProjectService {
  private final ProjectRepository projects;
  private final OrganizationAccessChecker accessChecker;

  public ProjectService(ProjectRepository projects, OrganizationAccessChecker accessChecker) {
    this.projects = projects;
    this.accessChecker = accessChecker;
  }

  @Transactional(readOnly = true)
  public List<ProjectResponse> list(UUID userId, UUID organizationId) {
    accessChecker.requireMember(organizationId, userId);
    return projects.findByOrganizationIdOrderByCreatedAtDesc(organizationId).stream().map(this::toResponse).toList();
  }

  @Transactional
  public ProjectResponse create(UUID userId, UUID organizationId, String name, String description) {
    accessChecker.requireMember(organizationId, userId);
    return toResponse(projects.save(Project.create(organizationId, name, description)));
  }

  @Transactional
  public ProjectResponse update(UUID userId, UUID organizationId, UUID projectId, String name, String description) {
    accessChecker.requireMember(organizationId, userId);
    Project project = projects.findByIdAndOrganizationId(projectId, organizationId)
        .orElseThrow(() -> new NotFoundException("Project not found"));
    project.update(name, description);
    return toResponse(project);
  }

  @Transactional
  public void delete(UUID userId, UUID organizationId, UUID projectId) {
    accessChecker.requireMember(organizationId, userId);
    Project project = projects.findByIdAndOrganizationId(projectId, organizationId)
        .orElseThrow(() -> new NotFoundException("Project not found"));
    projects.delete(project);
  }

  private ProjectResponse toResponse(Project project) {
    return new ProjectResponse(project.getId(), project.getOrganizationId(), project.getName(), project.getDescription());
  }
}
```

```java
// backend/src/main/java/com/example/springreact/modules/project/presentation/ProjectController.java
package com.example.springreact.modules.project.presentation;

import com.example.springreact.common.response.ApiResponse;
import com.example.springreact.common.security.CurrentUser;
import com.example.springreact.modules.project.application.ProjectService;
import com.example.springreact.modules.project.presentation.ProjectDtos.ProjectResponse;
import com.example.springreact.modules.project.presentation.ProjectDtos.UpsertProjectRequest;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/projects")
public class ProjectController {
  private final ProjectService service;

  public ProjectController(ProjectService service) {
    this.service = service;
  }

  @GetMapping
  public ApiResponse<List<ProjectResponse>> list(@AuthenticationPrincipal CurrentUser user, @RequestParam UUID organizationId) {
    return ApiResponse.success(service.list(user.id(), organizationId));
  }

  @PostMapping
  public ApiResponse<ProjectResponse> create(@AuthenticationPrincipal CurrentUser user, @RequestParam UUID organizationId,
      @Valid @RequestBody UpsertProjectRequest request) {
    return ApiResponse.success(service.create(user.id(), organizationId, request.name(), request.description()));
  }

  @PutMapping("/{projectId}")
  public ApiResponse<ProjectResponse> update(@AuthenticationPrincipal CurrentUser user, @RequestParam UUID organizationId,
      @PathVariable UUID projectId, @Valid @RequestBody UpsertProjectRequest request) {
    return ApiResponse.success(service.update(user.id(), organizationId, projectId, request.name(), request.description()));
  }

  @DeleteMapping("/{projectId}")
  public ApiResponse<Void> delete(@AuthenticationPrincipal CurrentUser user, @RequestParam UUID organizationId,
      @PathVariable UUID projectId) {
    service.delete(user.id(), organizationId, projectId);
    return ApiResponse.ok();
  }
}
```

## Penjelasan Kode Penting

Repository punya `findByIdAndOrganizationId`. Ini mencegah bug membaca project dari organization lain hanya berdasarkan `projectId`.

## Cara Menjalankan

```bash
cd backend
./mvnw spring-boot:run
```

## Cara Test Manual

```bash
curl "http://localhost:8080/api/projects?organizationId=10000000-0000-0000-0000-000000000001" \\
  -H "Authorization: Bearer ACCESS_TOKEN"
```

## Troubleshooting

- Jika project tidak ditemukan padahal ada, cek `organizationId` path.
- Jika user non-member bisa akses, cek `requireMember` dipanggil.
- Jika delete gagal karena task masih ada, pastikan foreign key `on delete cascade`.

## Checklist Akhir

- [ ] CRUD project tersedia.
- [ ] Project selalu punya `organizationId`.
- [ ] Query by ID tetap memfilter tenant.

## File Lanjutan Berikutnya

Lanjut ke [08-task-module.md](08-task-module.md).





