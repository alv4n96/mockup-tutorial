# Backend 09 - Testing Backend

## Tujuan File

Menambahkan contoh test untuk service, controller, repository, auth, dan tenant isolation.

## Problem Yang Diselesaikan

Auth dan tenant isolation mudah rusak jika hanya diuji manual. Test memastikan user non-member tidak bisa membaca project organization lain.

## Konsep Utama

- Unit test service memakai mock repository.
- Controller test memakai MockMvc.
- Repository test memakai Testcontainers PostgreSQL.
- Tenant isolation test menguji negative path.

## Pilihan Teknologi Yang Tersedia

- JUnit 5.
- Mockito.
- MockMvc.
- Testcontainers.
- RestAssured.

## Pilihan Yang Dipakai Di Tutorial Ini

JUnit 5, Mockito, MockMvc, dan Testcontainers.

## Struktur Folder Yang Akan Dibuat

```text
backend/src/test/java/com/example/springreact/
  modules/identity/application/AuthServiceTest.java
  modules/project/application/ProjectServiceTest.java
```

## Command Yang Harus Dijalankan

```bash
cd backend
mvn test
```

## Full Source Code Untuk Setiap File Yang Dibuat

```java
// backend/src/test/java/com/example/springreact/modules/identity/application/AuthServiceTest.java
package com.example.springreact.modules.identity.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import com.example.springreact.common.error.BusinessException;
import com.example.springreact.common.security.JwtService;
import com.example.springreact.modules.identity.domain.User;
import com.example.springreact.modules.identity.infrastructure.RefreshTokenRepository;
import com.example.springreact.modules.identity.infrastructure.UserRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

class AuthServiceTest {
  private final UserRepository users = org.mockito.Mockito.mock(UserRepository.class);
  private final RefreshTokenRepository refreshTokens = org.mockito.Mockito.mock(RefreshTokenRepository.class);
  private final JwtService jwtService = org.mockito.Mockito.mock(JwtService.class);
  private final AuthService service = new AuthService(users, refreshTokens, new BCryptPasswordEncoder(), jwtService, 7);

  @Test
  void registerCreatesUserAndTokens() {
    when(users.existsByEmail("new@example.com")).thenReturn(false);
    when(users.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));
    when(refreshTokens.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
    when(jwtService.createAccessToken(any(), any())).thenReturn("access-token");

    var response = service.register("new@example.com", "New User", "Password123!");

    assertThat(response.email()).isEqualTo("new@example.com");
    assertThat(response.accessToken()).isEqualTo("access-token");
    assertThat(response.refreshToken()).isNotBlank();
  }

  @Test
  void loginRejectsWrongPassword() {
    User user = User.register("owner@example.com", "Owner", new BCryptPasswordEncoder().encode("Password123!"));
    when(users.findByEmail("owner@example.com")).thenReturn(Optional.of(user));

    assertThatThrownBy(() -> service.login("owner@example.com", "wrong"))
        .isInstanceOf(BusinessException.class);
  }
}
```

```java
// backend/src/test/java/com/example/springreact/modules/project/application/ProjectServiceTest.java
package com.example.springreact.modules.project.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.when;

import com.example.springreact.common.error.ForbiddenException;
import com.example.springreact.modules.organization.application.OrganizationAccessChecker;
import com.example.springreact.modules.project.domain.Project;
import com.example.springreact.modules.project.infrastructure.ProjectRepository;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class ProjectServiceTest {
  private final ProjectRepository projects = org.mockito.Mockito.mock(ProjectRepository.class);
  private final OrganizationAccessChecker accessChecker = org.mockito.Mockito.mock(OrganizationAccessChecker.class);
  private final ProjectService service = new ProjectService(projects, accessChecker);

  @Test
  void listReturnsProjectsForOrganizationMember() {
    UUID userId = UUID.randomUUID();
    UUID organizationId = UUID.randomUUID();
    when(projects.findByOrganizationIdOrderByCreatedAtDesc(organizationId))
        .thenReturn(List.of(Project.create(organizationId, "Website", "Launch")));

    var result = service.list(userId, organizationId);

    assertThat(result).hasSize(1);
    assertThat(result.getFirst().organizationId()).isEqualTo(organizationId);
  }

  @Test
  void listRejectsNonMember() {
    UUID userId = UUID.randomUUID();
    UUID organizationId = UUID.randomUUID();
    doThrow(new ForbiddenException("Not member")).when(accessChecker).requireMember(organizationId, userId);

    assertThatThrownBy(() -> service.list(userId, organizationId))
        .isInstanceOf(ForbiddenException.class);
  }
}
```

## Penjelasan Kode Penting

`ProjectServiceTest` tidak perlu database karena yang diuji adalah aturan application layer: service harus memanggil tenant access checker sebelum data dikembalikan.

## Cara Menjalankan

```bash
cd backend
mvn test
```

## Cara Test Manual

Login sebagai user dari organization A, lalu panggil endpoint organization B. Response harus `FORBIDDEN`.

## Troubleshooting

- Jika Mockito tidak mengenali final class, pastikan versi Mockito dari Spring Boot Starter Test aktif.
- Jika Testcontainers gagal, pastikan Docker Desktop berjalan.
- Jika test seed bergantung ke database lokal, pindahkan ke Testcontainers.

## Checklist Akhir

- [ ] AuthServiceTest tersedia.
- [ ] ProjectServiceTest tersedia.
- [ ] Tenant isolation negative path diuji.
- [ ] Command `mvn test` dipakai sebelum merge.

## File Lanjutan Berikutnya

Lanjut ke [../frontend/01-project-setup-vite-react.md](../frontend/01-project-setup-vite-react.md).




