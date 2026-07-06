# Backend 09 - Code Blueprint Spring Boot

## Yang Dibuat

Versi Spring Boot untuk pola yang sama.

## Struktur File

```text
modules/tasks/domain/TaskItem.java
modules/tasks/application/CreateTaskCommand.java
modules/tasks/application/CreateTaskUseCase.java
modules/tasks/infrastructure/JpaTaskRepository.java
modules/tasks/presentation/TaskController.java
shared/api/ApiResponse.java
shared/error/AppError.java
```

## `ApiResponse.java`

```java
package com.example.shared.api;

public record ApiResponse<T>(
    T data,
    ApiError error,
    int status,
    ResponseMeta meta
) {
    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(data, null, 200, null);
    }

    public static <T> ApiResponse<T> created(T data) {
        return new ApiResponse<>(data, null, 201, null);
    }

    public static <T> ApiResponse<T> fail(ApiError error, int status) {
        return new ApiResponse<>(null, error, status, null);
    }
}

public record ApiError(String code, String message, Object details) {}
public record ResponseMeta(String requestId, PaginationMeta pagination) {}
public record PaginationMeta(int page, int pageSize, long totalItems, int totalPages) {}
```

## Domain

```java
package com.example.modules.tasks.domain;

import java.time.Instant;
import java.util.UUID;

public class TaskItem {
    private final UUID id;
    private final UUID organizationId;
    private final UUID projectId;
    private final String title;
    private final String description;
    private final TaskStatus status;
    private final UUID assigneeUserId;
    private final Instant createdAt;

    private TaskItem(
        UUID id,
        UUID organizationId,
        UUID projectId,
        String title,
        String description,
        TaskStatus status,
        UUID assigneeUserId,
        Instant createdAt
    ) {
        this.id = id;
        this.organizationId = organizationId;
        this.projectId = projectId;
        this.title = title;
        this.description = description;
        this.status = status;
        this.assigneeUserId = assigneeUserId;
        this.createdAt = createdAt;
    }

    public static TaskItem create(
        UUID organizationId,
        UUID projectId,
        String title,
        String description,
        UUID assigneeUserId
    ) {
        if (title == null || title.trim().length() < 3) {
            throw new IllegalArgumentException("Task title must be at least 3 characters.");
        }

        return new TaskItem(
            UUID.randomUUID(),
            organizationId,
            projectId,
            title.trim(),
            description == null ? null : description.trim(),
            TaskStatus.TODO,
            assigneeUserId,
            Instant.now()
        );
    }

    public UUID id() { return id; }
    public UUID organizationId() { return organizationId; }
    public UUID projectId() { return projectId; }
    public String title() { return title; }
    public TaskStatus status() { return status; }
    public UUID assigneeUserId() { return assigneeUserId; }
    public Instant createdAt() { return createdAt; }
}
```

## Use Case

```java
package com.example.modules.tasks.application;

import java.util.UUID;

public record CreateTaskCommand(
    UUID currentUserId,
    UUID organizationId,
    UUID projectId,
    String title,
    String description,
    UUID assigneeUserId
) {}
```

```java
public class CreateTaskUseCase {
    private final TaskRepository tasks;
    private final OrganizationAccessReader organizationAccess;

    public CreateTaskUseCase(
        TaskRepository tasks,
        OrganizationAccessReader organizationAccess
    ) {
        this.tasks = tasks;
        this.organizationAccess = organizationAccess;
    }

    public TaskDto execute(CreateTaskCommand command) {
        boolean isMember = organizationAccess.isMember(
            command.organizationId(),
            command.currentUserId()
        );

        if (!isMember) {
            throw new ForbiddenException("You are not a member of this organization.");
        }

        if (command.assigneeUserId() != null) {
            boolean assigneeIsMember = organizationAccess.isMember(
                command.organizationId(),
                command.assigneeUserId()
            );

            if (!assigneeIsMember) {
                throw new ValidationException("TASK_ASSIGNEE_NOT_MEMBER", "Assignee is not a member.");
            }
        }

        TaskItem task = TaskItem.create(
            command.organizationId(),
            command.projectId(),
            command.title(),
            command.description(),
            command.assigneeUserId()
        );

        tasks.save(task);

        return TaskDto.from(task);
    }
}
```

## Controller

```java
@RestController
@RequestMapping("/api/organizations/{organizationId}/tasks")
public class TaskController {
    private final CreateTaskUseCase createTask;

    public TaskController(CreateTaskUseCase createTask) {
        this.createTask = createTask;
    }

    @PostMapping
    public ResponseEntity<ApiResponse<TaskDto>> create(
        @PathVariable UUID organizationId,
        @Valid @RequestBody CreateTaskRequest request,
        Authentication authentication
    ) {
        UUID currentUserId = UUID.fromString(authentication.getName());

        TaskDto task = createTask.execute(new CreateTaskCommand(
            currentUserId,
            organizationId,
            request.projectId(),
            request.title(),
            request.description(),
            request.assigneeUserId()
        ));

        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(ApiResponse.created(task));
    }
}
```

## Output

Pola Spring sama dengan .NET:

```text
Controller -> use case -> domain -> repository -> ApiResponse
```

## RBAC: SecurityContext Ke Policy

Spring Security memastikan request punya `Authentication`. Use case tetap membaca membership dan mengecek permission supaya role tenant tidak bergantung pada annotation controller.

```text
Spring Security Filter
  -> Authentication.getName()
  -> TaskController.create
  -> CreateTaskUseCase
  -> OrganizationAccessReader.getMembership
  -> OrganizationPolicy.requirePermission(TASK_CREATE)
  -> TaskItem.create
  -> TaskRepository.save
```

### Role Dan Permission

```java
package com.example.modules.organizations.application;

import java.util.Map;
import java.util.Set;

public enum OrganizationRole {
    OWNER,
    ADMIN,
    MEMBER,
    VIEWER
}

public enum Permission {
    TASK_READ,
    TASK_CREATE,
    TASK_ASSIGN,
    TASK_UPDATE,
    TASK_DELETE,
    MEMBER_INVITE,
    BILLING_MANAGE
}

public final class RolePermissions {
    private static final Map<OrganizationRole, Set<Permission>> MAP = Map.of(
        OrganizationRole.OWNER,
        Set.of(
            Permission.TASK_READ,
            Permission.TASK_CREATE,
            Permission.TASK_ASSIGN,
            Permission.TASK_UPDATE,
            Permission.TASK_DELETE,
            Permission.MEMBER_INVITE,
            Permission.BILLING_MANAGE
        ),
        OrganizationRole.ADMIN,
        Set.of(
            Permission.TASK_READ,
            Permission.TASK_CREATE,
            Permission.TASK_ASSIGN,
            Permission.TASK_UPDATE,
            Permission.TASK_DELETE,
            Permission.MEMBER_INVITE
        ),
        OrganizationRole.MEMBER,
        Set.of(Permission.TASK_READ, Permission.TASK_CREATE, Permission.TASK_UPDATE),
        OrganizationRole.VIEWER,
        Set.of(Permission.TASK_READ)
    );

    private RolePermissions() {}

    public static boolean can(OrganizationRole role, Permission permission) {
        return MAP.getOrDefault(role, Set.of()).contains(permission);
    }
}
```

### Membership Contract

```java
public record OrganizationMembership(
    UUID organizationId,
    UUID userId,
    OrganizationRole role
) {}

public interface OrganizationAccessReader {
    Optional<OrganizationMembership> getMembership(UUID organizationId, UUID userId);
}
```

### Policy

```java
public final class OrganizationPolicy {
    private OrganizationPolicy() {}

    public static OrganizationMembership requirePermission(
        Optional<OrganizationMembership> membership,
        Permission permission
    ) {
        OrganizationMembership value = membership.orElseThrow(
            () -> new ForbiddenException("You are not a member of this organization.")
        );

        if (!RolePermissions.can(value.role(), permission)) {
            throw new ForbiddenException("You do not have permission for this action.");
        }

        return value;
    }
}
```

### Use Case Dengan RBAC

```java
public class CreateTaskUseCase {
    private final TaskRepository tasks;
    private final OrganizationAccessReader organizationAccess;

    public CreateTaskUseCase(
        TaskRepository tasks,
        OrganizationAccessReader organizationAccess
    ) {
        this.tasks = tasks;
        this.organizationAccess = organizationAccess;
    }

    public TaskDto execute(CreateTaskCommand command) {
        OrganizationMembership membership = OrganizationPolicy.requirePermission(
            organizationAccess.getMembership(command.organizationId(), command.currentUserId()),
            Permission.TASK_CREATE
        );

        if (command.assigneeUserId() != null &&
            !RolePermissions.can(membership.role(), Permission.TASK_ASSIGN)) {
            throw new ForbiddenException("You cannot assign tasks.");
        }

        if (command.assigneeUserId() != null) {
            boolean assigneeIsMember = organizationAccess
                .getMembership(command.organizationId(), command.assigneeUserId())
                .isPresent();

            if (!assigneeIsMember) {
                throw new ValidationException(
                    "TASK_ASSIGNEE_NOT_MEMBER",
                    "Assignee is not a member."
                );
            }
        }

        TaskItem task = TaskItem.create(
            command.organizationId(),
            command.projectId(),
            command.title(),
            command.description(),
            command.assigneeUserId()
        );

        tasks.save(task);
        return TaskDto.from(task);
    }
}
```

### Controller Input

```java
@PostMapping
public ResponseEntity<ApiResponse<TaskDto>> create(
    @PathVariable UUID organizationId,
    @Valid @RequestBody CreateTaskRequest request,
    Authentication authentication
) {
    UUID currentUserId = UUID.fromString(authentication.getName());

    TaskDto task = createTask.execute(new CreateTaskCommand(
        currentUserId,
        organizationId,
        request.projectId(),
        request.title(),
        request.description(),
        request.assigneeUserId()
    ));

    return ResponseEntity
        .status(HttpStatus.CREATED)
        .body(ApiResponse.created(task));
}
```

Request body:

```json
{
  "projectId": "6ad0fd06-07fc-4a80-a413-2abf34f66b3a",
  "title": "Implement RBAC Spring",
  "description": "Use case mengecek tenant role",
  "assigneeUserId": "7dd30f42-4663-44e7-8455-44b71ed4927a"
}
```