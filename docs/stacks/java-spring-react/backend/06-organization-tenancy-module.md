# Backend 06 - Organization Dan Tenancy Module

## Tujuan File

Membuat organization, membership, role, dan tenant access check.

## Problem Yang Diselesaikan

Project dan task tidak boleh bocor antar organization. Setiap access harus dicek berdasarkan membership organization.

## Konsep Utama

Tenant di tutorial ini adalah organization. User bisa menjadi member banyak organization dengan role `OWNER`, `ADMIN`, atau `MEMBER`.

## Pilihan Teknologi Yang Tersedia

- Tenant isolation lewat schema per tenant.
- Tenant isolation lewat database per tenant.
- Tenant isolation lewat `organization_id` di tabel bisnis.

## Pilihan Yang Dipakai Di Tutorial Ini

`organization_id` di tabel project dan membership check di application service.

## Struktur Folder Yang Akan Dibuat

```text
modules/organization/
  domain/Organization.java
  domain/OrganizationMember.java
  application/OrganizationAccessChecker.java
  application/OrganizationService.java
  infrastructure/OrganizationRepository.java
  infrastructure/OrganizationMemberRepository.java
  presentation/OrganizationController.java
  presentation/OrganizationDtos.java
```

## Command Yang Harus Dijalankan

```bash
cd backend
mkdir -p src/main/java/com/example/springreact/modules/organization/{domain,application,infrastructure,presentation}
```

## Full Source Code Untuk Setiap File Yang Dibuat

```java
// backend/src/main/java/com/example/springreact/modules/organization/domain/Organization.java
package com.example.springreact.modules.organization.domain;

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
@Table(name = "organizations")
@NoArgsConstructor
public class Organization {
  @Id private UUID id;
  @Column(nullable = false) private String name;
  @Column(nullable = false, unique = true) private String slug;
  @Column(name = "created_at", nullable = false) private OffsetDateTime createdAt;
  @Column(name = "updated_at", nullable = false) private OffsetDateTime updatedAt;

  public static Organization create(String name) {
    Organization organization = new Organization();
    organization.id = UUID.randomUUID();
    organization.name = name;
    organization.slug = name.toLowerCase().replaceAll("[^a-z0-9]+", "-").replaceAll("(^-|-$)", "");
    organization.createdAt = OffsetDateTime.now();
    organization.updatedAt = organization.createdAt;
    return organization;
  }
}
```

```java
// backend/src/main/java/com/example/springreact/modules/organization/domain/OrganizationMember.java
package com.example.springreact.modules.organization.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "organization_members")
@NoArgsConstructor
public class OrganizationMember {
  @Id private UUID id;
  @Column(name = "organization_id", nullable = false) private UUID organizationId;
  @Column(name = "user_id", nullable = false) private UUID userId;
  @Enumerated(EnumType.STRING) @Column(nullable = false) private OrganizationRole role;
  @Column(name = "created_at", nullable = false) private OffsetDateTime createdAt;

  public static OrganizationMember owner(UUID organizationId, UUID userId) {
    OrganizationMember member = new OrganizationMember();
    member.id = UUID.randomUUID();
    member.organizationId = organizationId;
    member.userId = userId;
    member.role = OrganizationRole.OWNER;
    member.createdAt = OffsetDateTime.now();
    return member;
  }
}
```

```java
// backend/src/main/java/com/example/springreact/modules/organization/infrastructure/OrganizationRepository.java
package com.example.springreact.modules.organization.infrastructure;

import com.example.springreact.modules.organization.domain.Organization;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OrganizationRepository extends JpaRepository<Organization, UUID> {
  boolean existsBySlug(String slug);
}
```

```java
// backend/src/main/java/com/example/springreact/modules/organization/infrastructure/OrganizationMemberRepository.java
package com.example.springreact.modules.organization.infrastructure;

import com.example.springreact.modules.organization.domain.OrganizationMember;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OrganizationMemberRepository extends JpaRepository<OrganizationMember, UUID> {
  boolean existsByOrganizationIdAndUserId(UUID organizationId, UUID userId);
  Optional<OrganizationMember> findByOrganizationIdAndUserId(UUID organizationId, UUID userId);
  List<OrganizationMember> findByUserId(UUID userId);
}
```

```java
// backend/src/main/java/com/example/springreact/modules/organization/application/OrganizationAccessChecker.java
package com.example.springreact.modules.organization.application;

import com.example.springreact.common.error.ForbiddenException;
import com.example.springreact.modules.organization.domain.OrganizationRole;
import com.example.springreact.modules.organization.infrastructure.OrganizationMemberRepository;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
public class OrganizationAccessChecker {
  private final OrganizationMemberRepository members;

  public OrganizationAccessChecker(OrganizationMemberRepository members) {
    this.members = members;
  }

  public void requireMember(UUID organizationId, UUID userId) {
    if (!members.existsByOrganizationIdAndUserId(organizationId, userId)) {
      throw new ForbiddenException("You are not a member of this organization");
    }
  }

  public void requireRole(UUID organizationId, UUID userId, Set<OrganizationRole> allowedRoles) {
    OrganizationRole role = members.findByOrganizationIdAndUserId(organizationId, userId)
        .orElseThrow(() -> new ForbiddenException("You are not a member of this organization"))
        .getRole();
    if (!allowedRoles.contains(role)) {
      throw new ForbiddenException("Your organization role cannot perform this action");
    }
  }
}
```

```java
// backend/src/main/java/com/example/springreact/modules/organization/presentation/OrganizationDtos.java
package com.example.springreact.modules.organization.presentation;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public final class OrganizationDtos {
  private OrganizationDtos() {}
  public record CreateOrganizationRequest(@NotBlank @Size(max = 160) String name) {}
  public record OrganizationResponse(UUID id, String name, String slug) {}
}
```

```java
// backend/src/main/java/com/example/springreact/modules/organization/application/OrganizationService.java
package com.example.springreact.modules.organization.application;

import com.example.springreact.modules.organization.domain.Organization;
import com.example.springreact.modules.organization.domain.OrganizationMember;
import com.example.springreact.modules.organization.infrastructure.OrganizationMemberRepository;
import com.example.springreact.modules.organization.infrastructure.OrganizationRepository;
import com.example.springreact.modules.organization.presentation.OrganizationDtos.OrganizationResponse;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OrganizationService {
  private final OrganizationRepository organizations;
  private final OrganizationMemberRepository members;

  public OrganizationService(OrganizationRepository organizations, OrganizationMemberRepository members) {
    this.organizations = organizations;
    this.members = members;
  }

  @Transactional
  public OrganizationResponse create(UUID userId, String name) {
    Organization organization = organizations.save(Organization.create(name));
    members.save(OrganizationMember.owner(organization.getId(), userId));
    return toResponse(organization);
  }

  @Transactional(readOnly = true)
  public List<OrganizationResponse> listMine(UUID userId) {
    return members.findByUserId(userId).stream()
        .map(member -> organizations.findById(member.getOrganizationId()).orElseThrow())
        .map(this::toResponse)
        .toList();
  }

  private OrganizationResponse toResponse(Organization organization) {
    return new OrganizationResponse(organization.getId(), organization.getName(), organization.getSlug());
  }
}
```

```java
// backend/src/main/java/com/example/springreact/modules/organization/presentation/OrganizationController.java
package com.example.springreact.modules.organization.presentation;

import com.example.springreact.common.response.ApiResponse;
import com.example.springreact.common.security.CurrentUser;
import com.example.springreact.modules.organization.application.OrganizationService;
import com.example.springreact.modules.organization.presentation.OrganizationDtos.CreateOrganizationRequest;
import com.example.springreact.modules.organization.presentation.OrganizationDtos.OrganizationResponse;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/organizations")
public class OrganizationController {
  private final OrganizationService service;

  public OrganizationController(OrganizationService service) {
    this.service = service;
  }

  @GetMapping
  public ApiResponse<List<OrganizationResponse>> list(@AuthenticationPrincipal CurrentUser user) {
    return ApiResponse.success(service.listMine(user.id()));
  }

  @PostMapping
  public ApiResponse<OrganizationResponse> create(@AuthenticationPrincipal CurrentUser user,
      @Valid @RequestBody CreateOrganizationRequest request) {
    return ApiResponse.success(service.create(user.id(), request.name()));
  }
}
```

## Penjelasan Kode Penting

`OrganizationAccessChecker` adalah Strategy-like authorization component. Service lain memanggil `requireMember` atau `requireRole` sebelum membaca data tenant.

## Cara Menjalankan

```bash
cd backend
./mvnw spring-boot:run
```

## Cara Test Manual

Login, ambil access token, lalu:

```bash
curl http://localhost:8080/api/organizations -H "Authorization: Bearer ACCESS_TOKEN"
```

## Troubleshooting

- Jika organization kosong, cek seed membership.
- Jika semua request forbidden, cek user ID dari JWT sama dengan `organization_members.user_id`.
- Jika slug bentrok, tambahkan suffix angka pada domain factory.

## Checklist Akhir

- [ ] User bisa list organization miliknya.
- [ ] User bisa create organization dan otomatis jadi OWNER.
- [ ] Tenant access checker tersedia.

## File Lanjutan Berikutnya

Lanjut ke [07-project-module.md](07-project-module.md).


