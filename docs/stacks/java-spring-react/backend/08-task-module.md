# Backend 08 - Task Module

## Tujuan File

Membuat CRUD task dengan status `TODO`, `IN_PROGRESS`, `DONE` dan priority `LOW`, `MEDIUM`, `HIGH`.

## Problem Yang Diselesaikan

Task berada di bawah project. User hanya boleh mengakses task jika ia member organization pemilik project.

## Konsep Utama

Task tidak menyimpan `organization_id` langsung. Tenant diturunkan dari `project.organization_id`.

## Pilihan Teknologi Yang Tersedia

- Simpan `organization_id` di task agar query cepat.
- Turunkan organization dari project agar normalisasi data lebih bersih.
- Pakai ACL per task untuk permission granular.

## Pilihan Yang Dipakai Di Tutorial Ini

Task mengikuti tenant dari project.

## Struktur Folder Yang Akan Dibuat

```text
modules/task/
  domain/Task.java
  domain/TaskStatus.java
  domain/TaskPriority.java
  application/TaskService.java
  infrastructure/TaskRepository.java
  presentation/TaskController.java
  presentation/TaskDtos.java
```

## Command Yang Harus Dijalankan

```bash
cd backend
mkdir -p src/main/java/com/example/springreact/modules/task/{domain,application,infrastructure,presentation}
```

## Full Source Code Untuk Setiap File Yang Dibuat

```java
// backend/src/main/java/com/example/springreact/modules/task/domain/Task.java
package com.example.springreact.modules.task.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "tasks")
@NoArgsConstructor
public class Task {
  @Id private UUID id;
  @Column(name = "project_id", nullable = false) private UUID projectId;
  @Column(nullable = false) private String title;
  @Column private String description;
  @Enumerated(EnumType.STRING) @Column(nullable = false) private TaskStatus status;
  @Enumerated(EnumType.STRING) @Column(nullable = false) private TaskPriority priority;
  @Column(name = "due_date") private LocalDate dueDate;
  @Column(name = "created_at", nullable = false) private OffsetDateTime createdAt;
  @Column(name = "updated_at", nullable = false) private OffsetDateTime updatedAt;

  public static Task create(UUID projectId, String title, String description, TaskPriority priority, LocalDate dueDate) {
    Task task = new Task();
    task.id = UUID.randomUUID();
    task.projectId = projectId;
    task.title = title;
    task.description = description;
    task.status = TaskStatus.TODO;
    task.priority = priority;
    task.dueDate = dueDate;
    task.createdAt = OffsetDateTime.now();
    task.updatedAt = task.createdAt;
    return task;
  }

  public void update(String title, String description, TaskPriority priority, LocalDate dueDate) {
    this.title = title;
    this.description = description;
    this.priority = priority;
    this.dueDate = dueDate;
    this.updatedAt = OffsetDateTime.now();
  }

  public void changeStatus(TaskStatus status) {
    this.status = status;
    this.updatedAt = OffsetDateTime.now();
  }
}
```

```java
// backend/src/main/java/com/example/springreact/modules/task/infrastructure/TaskRepository.java
package com.example.springreact.modules.task.infrastructure;

import com.example.springreact.modules.task.domain.Task;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TaskRepository extends JpaRepository<Task, UUID> {
  List<Task> findByProjectIdOrderByCreatedAtDesc(UUID projectId);
  Optional<Task> findByIdAndProjectId(UUID id, UUID projectId);
}
```

```java
// backend/src/main/java/com/example/springreact/modules/task/presentation/TaskDtos.java
package com.example.springreact.modules.task.presentation;

import com.example.springreact.modules.task.domain.TaskPriority;
import com.example.springreact.modules.task.domain.TaskStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.UUID;

public final class TaskDtos {
  private TaskDtos() {}
  public record UpsertTaskRequest(@NotBlank @Size(max = 200) String title, String description,
      @NotNull TaskPriority priority, LocalDate dueDate) {}
  public record ChangeStatusRequest(@NotNull TaskStatus status) {}
  public record TaskResponse(UUID id, UUID projectId, String title, String description,
      TaskStatus status, TaskPriority priority, LocalDate dueDate) {}
}
```

```java
// backend/src/main/java/com/example/springreact/modules/task/application/TaskService.java
package com.example.springreact.modules.task.application;

import com.example.springreact.common.error.NotFoundException;
import com.example.springreact.modules.organization.application.OrganizationAccessChecker;
import com.example.springreact.modules.project.domain.Project;
import com.example.springreact.modules.project.infrastructure.ProjectRepository;
import com.example.springreact.modules.task.domain.Task;
import com.example.springreact.modules.task.domain.TaskPriority;
import com.example.springreact.modules.task.domain.TaskStatus;
import com.example.springreact.modules.task.infrastructure.TaskRepository;
import com.example.springreact.modules.task.presentation.TaskDtos.TaskResponse;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TaskService {
  private final TaskRepository tasks;
  private final ProjectRepository projects;
  private final OrganizationAccessChecker accessChecker;

  public TaskService(TaskRepository tasks, ProjectRepository projects, OrganizationAccessChecker accessChecker) {
    this.tasks = tasks;
    this.projects = projects;
    this.accessChecker = accessChecker;
  }

  @Transactional(readOnly = true)
  public List<TaskResponse> list(UUID userId, UUID organizationId, UUID projectId) {
    requireProjectAccess(userId, organizationId, projectId);
    return tasks.findByProjectIdOrderByCreatedAtDesc(projectId).stream().map(this::toResponse).toList();
  }

  @Transactional
  public TaskResponse create(UUID userId, UUID organizationId, UUID projectId, String title, String description,
      TaskPriority priority, LocalDate dueDate) {
    requireProjectAccess(userId, organizationId, projectId);
    return toResponse(tasks.save(Task.create(projectId, title, description, priority, dueDate)));
  }

  @Transactional
  public TaskResponse update(UUID userId, UUID organizationId, UUID projectId, UUID taskId, String title,
      String description, TaskPriority priority, LocalDate dueDate) {
    requireProjectAccess(userId, organizationId, projectId);
    Task task = tasks.findByIdAndProjectId(taskId, projectId).orElseThrow(() -> new NotFoundException("Task not found"));
    task.update(title, description, priority, dueDate);
    return toResponse(task);
  }

  @Transactional
  public TaskResponse changeStatus(UUID userId, UUID organizationId, UUID projectId, UUID taskId, TaskStatus status) {
    requireProjectAccess(userId, organizationId, projectId);
    Task task = tasks.findByIdAndProjectId(taskId, projectId).orElseThrow(() -> new NotFoundException("Task not found"));
    task.changeStatus(status);
    return toResponse(task);
  }

  @Transactional
  public void delete(UUID userId, UUID organizationId, UUID projectId, UUID taskId) {
    requireProjectAccess(userId, organizationId, projectId);
    Task task = tasks.findByIdAndProjectId(taskId, projectId).orElseThrow(() -> new NotFoundException("Task not found"));
    tasks.delete(task);
  }

  private void requireProjectAccess(UUID userId, UUID organizationId, UUID projectId) {
    Project project = projects.findByIdAndOrganizationId(projectId, organizationId)
        .orElseThrow(() -> new NotFoundException("Project not found"));
    accessChecker.requireMember(project.getOrganizationId(), userId);
  }

  private TaskResponse toResponse(Task task) {
    return new TaskResponse(task.getId(), task.getProjectId(), task.getTitle(), task.getDescription(),
        task.getStatus(), task.getPriority(), task.getDueDate());
  }
}
```

```java
// backend/src/main/java/com/example/springreact/modules/task/presentation/TaskController.java
package com.example.springreact.modules.task.presentation;

import com.example.springreact.common.response.ApiResponse;
import com.example.springreact.common.security.CurrentUser;
import com.example.springreact.modules.task.application.TaskService;
import com.example.springreact.modules.task.presentation.TaskDtos.ChangeStatusRequest;
import com.example.springreact.modules.task.presentation.TaskDtos.TaskResponse;
import com.example.springreact.modules.task.presentation.TaskDtos.UpsertTaskRequest;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/tasks")
public class TaskController {
  private final TaskService service;

  public TaskController(TaskService service) {
    this.service = service;
  }

  @GetMapping
  public ApiResponse<List<TaskResponse>> list(@AuthenticationPrincipal CurrentUser user, @RequestParam UUID organizationId,
      @RequestParam UUID projectId) {
    return ApiResponse.success(service.list(user.id(), organizationId, projectId));
  }

  @PostMapping
  public ApiResponse<TaskResponse> create(@AuthenticationPrincipal CurrentUser user, @RequestParam UUID organizationId,
      @RequestParam UUID projectId, @Valid @RequestBody UpsertTaskRequest request) {
    return ApiResponse.success(service.create(user.id(), organizationId, projectId, request.title(),
        request.description(), request.priority(), request.dueDate()));
  }

  @PutMapping("/{taskId}")
  public ApiResponse<TaskResponse> update(@AuthenticationPrincipal CurrentUser user, @RequestParam UUID organizationId,
      @RequestParam UUID projectId, @PathVariable UUID taskId, @Valid @RequestBody UpsertTaskRequest request) {
    return ApiResponse.success(service.update(user.id(), organizationId, projectId, taskId, request.title(),
        request.description(), request.priority(), request.dueDate()));
  }

  @PatchMapping("/{taskId}/status")
  public ApiResponse<TaskResponse> changeStatus(@AuthenticationPrincipal CurrentUser user, @RequestParam UUID organizationId,
      @RequestParam UUID projectId, @PathVariable UUID taskId, @Valid @RequestBody ChangeStatusRequest request) {
    return ApiResponse.success(service.changeStatus(user.id(), organizationId, projectId, taskId, request.status()));
  }

  @DeleteMapping("/{taskId}")
  public ApiResponse<Void> delete(@AuthenticationPrincipal CurrentUser user, @RequestParam UUID organizationId,
      @RequestParam UUID projectId, @PathVariable UUID taskId) {
    service.delete(user.id(), organizationId, projectId, taskId);
    return ApiResponse.ok();
  }
}
```

## Penjelasan Kode Penting

`requireProjectAccess` adalah gerbang tenant. Ia memastikan project memang milik organization pada path dan user adalah member organization tersebut.

## Cara Menjalankan

```bash
cd backend
./mvnw spring-boot:run
```

## Cara Test Manual

```bash
curl "http://localhost:8080/api/tasks?organizationId=10000000-0000-0000-0000-000000000001&projectId=30000000-0000-0000-0000-000000000001" \\
  -H "Authorization: Bearer ACCESS_TOKEN"
```

## Troubleshooting

- Jika enum gagal parse, kirim string persis `LOW`, `MEDIUM`, `HIGH`.
- Jika task tenant bocor, pastikan tidak ada endpoint hanya memakai `taskId`.
- Jika status update tidak persist, method harus berjalan dalam `@Transactional`.

## Checklist Akhir

- [ ] CRUD task tersedia.
- [ ] Status update tersedia.
- [ ] Tenant check mengikuti project.
- [ ] Task board frontend bisa membaca data.

## File Lanjutan Berikutnya

Lanjut ke [09-testing-backend.md](09-testing-backend.md).





