# Backend 05 - Identity Dan Auth Module

## Tujuan File

Membuat module identity untuk register, login, refresh token, logout, dan current user `/me`.

## Problem Yang Diselesaikan

Aplikasi SaaS butuh identitas user, password hashing, access token pendek, refresh token yang bisa dicabut, dan helper current user untuk endpoint lain.

## Konsep Utama

- Password disimpan sebagai BCrypt hash.
- Access token JWT berumur pendek.
- Refresh token disimpan di database dalam bentuk hash.
- `JwtAuthenticationFilter` membaca Bearer token dan mengisi Spring Security context.

## Pilihan Teknologi Yang Tersedia

- Session cookie server-side.
- JWT di localStorage.
- JWT access token + refresh token.
- OAuth/OIDC lewat provider eksternal.

## Pilihan Yang Dipakai Di Tutorial Ini

JWT access token + refresh token database. Untuk mockup, frontend boleh menyimpan access token di memory/localStorage dengan catatan risiko XSS. Produksi lebih aman memakai httpOnly cookie.

## Struktur Folder Yang Akan Dibuat

```text
common/security/
  CurrentUser.java
  JwtService.java
  JwtAuthenticationFilter.java
  SecurityConfig.java
modules/identity/
  domain/User.java
  domain/RefreshToken.java
  application/AuthService.java
  infrastructure/UserRepository.java
  infrastructure/RefreshTokenRepository.java
  presentation/AuthController.java
  presentation/AuthDtos.java
```

## Command Yang Harus Dijalankan

```bash
cd backend
mkdir -p src/main/java/com/example/springreact/common/security
mkdir -p src/main/java/com/example/springreact/modules/identity/{domain,application,infrastructure,presentation}
```

## Full Source Code Untuk Setiap File Yang Dibuat

```java
// backend/src/main/java/com/example/springreact/modules/identity/domain/User.java
package com.example.springreact.modules.identity.domain;

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
@Table(name = "users")
@NoArgsConstructor
public class User {
  @Id
  private UUID id;

  @Column(nullable = false, unique = true)
  private String email;

  @Column(nullable = false)
  private String name;

  @Column(name = "password_hash", nullable = false)
  private String passwordHash;

  @Column(name = "created_at", nullable = false)
  private OffsetDateTime createdAt;

  @Column(name = "updated_at", nullable = false)
  private OffsetDateTime updatedAt;

  public static User register(String email, String name, String passwordHash) {
    User user = new User();
    user.id = UUID.randomUUID();
    user.email = email.toLowerCase();
    user.name = name;
    user.passwordHash = passwordHash;
    user.createdAt = OffsetDateTime.now();
    user.updatedAt = user.createdAt;
    return user;
  }
}
```

```java
// backend/src/main/java/com/example/springreact/modules/identity/domain/RefreshToken.java
package com.example.springreact.modules.identity.domain;

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
@Table(name = "refresh_tokens")
@NoArgsConstructor
public class RefreshToken {
  @Id
  private UUID id;

  @Column(name = "user_id", nullable = false)
  private UUID userId;

  @Column(name = "token_hash", nullable = false, unique = true)
  private String tokenHash;

  @Column(name = "expires_at", nullable = false)
  private OffsetDateTime expiresAt;

  @Column(name = "revoked_at")
  private OffsetDateTime revokedAt;

  @Column(name = "created_at", nullable = false)
  private OffsetDateTime createdAt;

  public static RefreshToken create(UUID userId, String tokenHash, OffsetDateTime expiresAt) {
    RefreshToken token = new RefreshToken();
    token.id = UUID.randomUUID();
    token.userId = userId;
    token.tokenHash = tokenHash;
    token.expiresAt = expiresAt;
    token.createdAt = OffsetDateTime.now();
    return token;
  }

  public boolean isActive() {
    return revokedAt == null && expiresAt.isAfter(OffsetDateTime.now());
  }

  public void revoke() {
    this.revokedAt = OffsetDateTime.now();
  }
}
```

```java
// backend/src/main/java/com/example/springreact/modules/identity/infrastructure/UserRepository.java
package com.example.springreact.modules.identity.infrastructure;

import com.example.springreact.modules.identity.domain.User;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<User, UUID> {
  Optional<User> findByEmail(String email);
  boolean existsByEmail(String email);
}
```

```java
// backend/src/main/java/com/example/springreact/modules/identity/infrastructure/RefreshTokenRepository.java
package com.example.springreact.modules.identity.infrastructure;

import com.example.springreact.modules.identity.domain.RefreshToken;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {
  Optional<RefreshToken> findByTokenHash(String tokenHash);
}
```

```java
// backend/src/main/java/com/example/springreact/common/security/CurrentUser.java
package com.example.springreact.common.security;

import java.util.UUID;

public record CurrentUser(UUID id, String email) {
}
```

Catatan dependency JWT: class `Keys` berasal dari JJWT, bukan dari Spring Security. Dependency ini tidak otomatis ada dari Spring Boot quickstart/Initializr. Jika project dibuat dari quickstart, tambahkan JJWT manual di `backend/pom.xml`: property `jjwt.version` masuk ke blok `<properties>`, lalu `jjwt-api`, `jjwt-impl`, dan `jjwt-jackson` masuk ke blok `<dependencies>`. Contoh lengkapnya ada di `01-project-setup.md`. Import yang benar untuk file ini adalah `io.jsonwebtoken.security.Keys`.

```java
// backend/src/main/java/com/example/springreact/common/security/JwtService.java
package com.example.springreact.common.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;
import javax.crypto.SecretKey;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class JwtService {
  private final String issuer;
  private final long accessTokenMinutes;
  private final SecretKey key;

  public JwtService(
      @Value("${app.jwt.issuer}") String issuer,
      @Value("${app.jwt.secret}") String secret,
      @Value("${app.jwt.access-token-minutes}") long accessTokenMinutes
  ) {
    this.issuer = issuer;
    this.accessTokenMinutes = accessTokenMinutes;
    this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
  }

  public String createAccessToken(UUID userId, String email) {
    Instant now = Instant.now();
    return Jwts.builder()
        .issuer(issuer)
        .subject(userId.toString())
        .claim("email", email)
        .issuedAt(Date.from(now))
        .expiration(Date.from(now.plusSeconds(accessTokenMinutes * 60)))
        .signWith(key)
        .compact();
  }

  public CurrentUser parse(String token) {
    Claims claims = Jwts.parser()
        .verifyWith(key)
        .build()
        .parseSignedClaims(token)
        .getPayload();
    return new CurrentUser(UUID.fromString(claims.getSubject()), claims.get("email", String.class));
  }
}
```

```java
// backend/src/main/java/com/example/springreact/modules/identity/presentation/AuthDtos.java
package com.example.springreact.modules.identity.presentation;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public final class AuthDtos {
  private AuthDtos() {}

  public record RegisterRequest(
      @Email @NotBlank String email,
      @NotBlank @Size(min = 2, max = 120) String name,
      @NotBlank @Size(min = 8, max = 80) String password
  ) {}

  public record LoginRequest(@Email @NotBlank String email, @NotBlank String password) {}

  public record RefreshRequest(@NotBlank String refreshToken) {}

  public record LogoutRequest(@NotBlank String refreshToken) {}

  public record AuthResponse(UUID userId, String email, String name, String accessToken, String refreshToken) {}

  public record MeResponse(UUID id, String email, String name) {}
}
```

Catatan `PasswordEncoder`: interface ini berasal dari Spring Security (`org.springframework.security.crypto.password.PasswordEncoder`). Pastikan dependency `spring-boot-starter-security` sudah ada dari setup awal. Bean-nya dibuat di `SecurityConfig` lewat `@Bean public PasswordEncoder passwordEncoder()`. Jika mengetik file secara berurutan, buat `SecurityConfig` dulu atau lanjutkan sampai bagian `SecurityConfig` selesai agar warning IDE/autowire hilang.

```java
// backend/src/main/java/com/example/springreact/modules/identity/application/AuthService.java
package com.example.springreact.modules.identity.application;

import com.example.springreact.common.error.BusinessException;
import com.example.springreact.common.error.ConflictException;
import com.example.springreact.common.error.ErrorCode;
import com.example.springreact.common.security.JwtService;
import com.example.springreact.modules.identity.domain.RefreshToken;
import com.example.springreact.modules.identity.domain.User;
import com.example.springreact.modules.identity.infrastructure.RefreshTokenRepository;
import com.example.springreact.modules.identity.infrastructure.UserRepository;
import com.example.springreact.modules.identity.presentation.AuthDtos.AuthResponse;
import com.example.springreact.modules.identity.presentation.AuthDtos.MeResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.OffsetDateTime;
import java.util.Base64;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
  private final UserRepository users;
  private final RefreshTokenRepository refreshTokens;
  private final PasswordEncoder passwordEncoder;
  private final JwtService jwtService;
  private final long refreshTokenDays;

  public AuthService(UserRepository users, RefreshTokenRepository refreshTokens, PasswordEncoder passwordEncoder,
      JwtService jwtService, @Value("${app.jwt.refresh-token-days}") long refreshTokenDays) {
    this.users = users;
    this.refreshTokens = refreshTokens;
    this.passwordEncoder = passwordEncoder;
    this.jwtService = jwtService;
    this.refreshTokenDays = refreshTokenDays;
  }

  @Transactional
  public AuthResponse register(String email, String name, String password) {
    String normalizedEmail = email.toLowerCase();
    if (users.existsByEmail(normalizedEmail)) {
      throw new ConflictException("Email already registered");
    }
    User user = users.save(User.register(normalizedEmail, name, passwordEncoder.encode(password)));
    return issueTokens(user);
  }

  @Transactional
  public AuthResponse login(String email, String password) {
    User user = users.findByEmail(email.toLowerCase())
        .orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHORIZED, "Invalid email or password"));
    if (!passwordEncoder.matches(password, user.getPasswordHash())) {
      throw new BusinessException(ErrorCode.UNAUTHORIZED, "Invalid email or password");
    }
    return issueTokens(user);
  }

  @Transactional
  public AuthResponse refresh(String rawRefreshToken) {
    String hash = hash(rawRefreshToken);
    RefreshToken token = refreshTokens.findByTokenHash(hash)
        .orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHORIZED, "Invalid refresh token"));
    if (!token.isActive()) {
      throw new BusinessException(ErrorCode.UNAUTHORIZED, "Refresh token expired or revoked");
    }
    token.revoke();
    User user = users.findById(token.getUserId())
        .orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHORIZED, "User not found"));
    return issueTokens(user);
  }

  @Transactional
  public void logout(String rawRefreshToken) {
    refreshTokens.findByTokenHash(hash(rawRefreshToken)).ifPresent(RefreshToken::revoke);
  }

  @Transactional(readOnly = true)
  public MeResponse me(UUID userId) {
    User user = users.findById(userId)
        .orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHORIZED, "User not found"));
    return new MeResponse(user.getId(), user.getEmail(), user.getName());
  }

  private AuthResponse issueTokens(User user) {
    String accessToken = jwtService.createAccessToken(user.getId(), user.getEmail());
    String rawRefreshToken = UUID.randomUUID() + "." + UUID.randomUUID();
    RefreshToken refreshToken = RefreshToken.create(
        user.getId(),
        hash(rawRefreshToken),
        OffsetDateTime.now().plusDays(refreshTokenDays)
    );
    refreshTokens.save(refreshToken);
    return new AuthResponse(user.getId(), user.getEmail(), user.getName(), accessToken, rawRefreshToken);
  }

  private String hash(String value) {
    try {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      return Base64.getEncoder().encodeToString(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
    } catch (Exception exception) {
      throw new IllegalStateException("Unable to hash token", exception);
    }
  }
}
```

```java
// backend/src/main/java/com/example/springreact/common/security/JwtAuthenticationFilter.java
package com.example.springreact.common.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
  private final JwtService jwtService;

  public JwtAuthenticationFilter(JwtService jwtService) {
    this.jwtService = jwtService;
  }

  @Override
  protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
      throws ServletException, IOException {
    String header = request.getHeader("Authorization");
    if (header != null && header.startsWith("Bearer ")) {
      CurrentUser currentUser = jwtService.parse(header.substring(7));
      UsernamePasswordAuthenticationToken authentication =
          new UsernamePasswordAuthenticationToken(currentUser, null, List.of());
      SecurityContextHolder.getContext().setAuthentication(authentication);
    }
    chain.doFilter(request, response);
  }
}
```

```java
// backend/src/main/java/com/example/springreact/common/security/SecurityConfig.java
package com.example.springreact.common.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
public class SecurityConfig {
  @Bean
  public SecurityFilterChain securityFilterChain(HttpSecurity http, JwtAuthenticationFilter jwtFilter) throws Exception {
    return http
        .csrf(csrf -> csrf.disable())
        .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/auth/register", "/api/auth/login", "/api/auth/refresh").permitAll()
            .anyRequest().authenticated()
        )
        .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
        .build();
  }

  @Bean
  public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder();
  }
}
```

```java
// backend/src/main/java/com/example/springreact/modules/identity/presentation/AuthController.java
package com.example.springreact.modules.identity.presentation;

import com.example.springreact.common.response.ApiResponse;
import com.example.springreact.common.security.CurrentUser;
import com.example.springreact.modules.identity.application.AuthService;
import com.example.springreact.modules.identity.presentation.AuthDtos.AuthResponse;
import com.example.springreact.modules.identity.presentation.AuthDtos.LoginRequest;
import com.example.springreact.modules.identity.presentation.AuthDtos.LogoutRequest;
import com.example.springreact.modules.identity.presentation.AuthDtos.MeResponse;
import com.example.springreact.modules.identity.presentation.AuthDtos.RefreshRequest;
import com.example.springreact.modules.identity.presentation.AuthDtos.RegisterRequest;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
  private final AuthService authService;

  public AuthController(AuthService authService) {
    this.authService = authService;
  }

  @PostMapping("/register")
  public ApiResponse<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
    return ApiResponse.success(authService.register(request.email(), request.name(), request.password()));
  }

  @PostMapping("/login")
  public ApiResponse<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
    return ApiResponse.success(authService.login(request.email(), request.password()));
  }

  @PostMapping("/refresh")
  public ApiResponse<AuthResponse> refresh(@Valid @RequestBody RefreshRequest request) {
    return ApiResponse.success(authService.refresh(request.refreshToken()));
  }

  @PostMapping("/logout")
  public ApiResponse<Void> logout(@Valid @RequestBody LogoutRequest request) {
    authService.logout(request.refreshToken());
    return ApiResponse.ok();
  }

  @GetMapping("/me")
  public ApiResponse<MeResponse> me(@AuthenticationPrincipal CurrentUser currentUser) {
    return ApiResponse.success(authService.me(currentUser.id()));
  }
}
```

## Penjelasan Kode Penting

Auth service adalah facade untuk flow identity: validasi user, password check, issue JWT, simpan refresh token, dan revoke token.

## Cara Menjalankan

```bash
cd backend
./mvnw spring-boot:run
```

## Cara Test Manual

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"owner@example.com","password":"Password123!"}'
```

## Troubleshooting

- Jika JWT parse error membuat semua request gagal, tangkap exception filter dengan response `UNAUTHORIZED`.
- Jika `import io.jsonwebtoken.security.Keys` tidak ditemukan, cek apakah `jjwt.version` sudah ada di `<properties>` dan `jjwt-api` sudah ada di `<dependencies>` pada `pom.xml`, lalu reload Maven project.
- Jika `PasswordEncoder` tidak ditemukan, cek dependency `spring-boot-starter-security` dan import `org.springframework.security.crypto.password.PasswordEncoder`. Jika hanya muncul warning bean/autowire, pastikan `SecurityConfig` sudah dibuat dan memiliki `@Bean public PasswordEncoder passwordEncoder()`.
- Jika login seed gagal, hash password di seed tidak cocok.
- Jika `@AuthenticationPrincipal` null, cek `JwtAuthenticationFilter`.

## Checklist Akhir

- [ ] Register tersedia.
- [ ] Login tersedia.
- [ ] Refresh token disimpan di database.
- [ ] Logout revoke refresh token.
- [ ] `/api/auth/me` memakai current user.

## File Lanjutan Berikutnya

Lanjut ke [06-organization-tenancy-module.md](06-organization-tenancy-module.md).


