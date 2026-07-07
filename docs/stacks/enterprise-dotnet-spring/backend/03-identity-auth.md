# Backend 03 - Identity & Authentication

File ini melanjutkan fondasi dari [01-solution-setup.md](01-solution-setup.md) dan [02-modular-monolith-layers.md](02-modular-monolith-layers.md). File `01` menyiapkan solution dan project. File `02` menjelaskan modular monolith, layered architecture, Shared Kernel, dependency rule, dan contoh module `Projects`.

File ini membuat module `Identity` untuk Project Management App. Fokusnya adalah register user, login user, password hashing, JWT access token, current user endpoint, protected endpoint sederhana, response envelope, validation sederhana, dan error response sederhana.

Database di file ini memakai in-memory repository agar pembaca fokus pada alur Identity/Auth. EF Core migration dan seed database dibahas khusus di `08-database-migration-seed.md`.

## Identity/Auth Dalam Modular Monolith

Authentication biasanya menjadi module sendiri karena hampir semua fitur membutuhkan identitas user. Module `Projects`, `Tasks`, dan `Organizations` perlu tahu siapa user yang sedang login, tetapi tidak boleh mengurus password, hashing, atau pembuatan token sendiri.

Dalam modular monolith, module `Identity` bertanggung jawab untuk:

- menyimpan user;
- membuat password hash;
- memverifikasi password saat login;
- membuat JWT access token;
- menyediakan data current user;
- menjadi sumber identity claim seperti `userId`, `email`, dan `role`.

Module lain cukup memakai hasil authentication, misalnya `ClaimsPrincipal` atau abstraction seperti `ICurrentUser`. Dengan cara ini, aturan login tidak tersebar di semua module.

## Konsep Dasar Identity

### Authentication

Authentication adalah proses membuktikan siapa user. Contoh: user mengirim email dan password, lalu backend memeriksa apakah email ada dan password benar.

Jika berhasil, backend mengembalikan token. Token ini dipakai di request berikutnya.

### Authorization

Authorization adalah proses memeriksa apakah user yang sudah login boleh melakukan aksi tertentu. Contoh: user sudah login, tetapi belum tentu boleh menghapus project.

Authentication menjawab: siapa kamu?

Authorization menjawab: kamu boleh melakukan apa?

### User

User adalah akun aplikasi. Di Project Management App, user punya `Id`, `Name`, `Email`, `PasswordHash`, dan role sederhana.

### Role

Role adalah label posisi user. Di file ini role dibuat sederhana:

- `Admin`: punya akses lebih luas.
- `Member`: user biasa.

Role detail per organization akan dibahas di file tenancy/authorization. Di sini role masih global agar alur auth mudah dipahami.

### Permission

Permission adalah izin aksi yang lebih spesifik, misalnya `project:create`, `project:update`, atau `task:assign`. File ini belum membuat permission detail. Permission akan muncul lebih kuat di module organization/tenant dan project/task.

### Password Hashing

Password tidak boleh disimpan sebagai plain text. Backend harus menyimpan hash password. Saat login, password input di-hash ulang dan dibandingkan dengan hash yang tersimpan.

File ini memakai PBKDF2 dari .NET standard library untuk membuat hash sederhana yang layak untuk tutorial. Di production, konfigurasi iteration, salt length, dan migration hash policy perlu dikaji lebih serius.

### JWT Access Token

JWT access token adalah token yang dikirim client ke backend melalui header:

```text
# File: ProjectManagement.Backend/commands/auth-header-example.txt
Authorization: Bearer <access-token>
```

Token berisi claim seperti user id, email, dan role. Backend memverifikasi signature token sebelum menganggap user login.

### Refresh Token

Refresh token dipakai untuk meminta access token baru saat access token expired. File ini hanya memberi preview konsep. Implementasi refresh token disimpan untuk tahap lanjutan karena butuh penyimpanan token, revoke token, expiry, rotation, dan audit.

### Claim

Claim adalah data kecil di dalam identity user, misalnya:

- `sub`: user id;
- `email`: email user;
- `name`: nama user;
- `role`: role user.

Endpoint protected membaca claim dari token yang sudah divalidasi middleware.

### Middleware Authentication

Middleware authentication adalah bagian ASP.NET Core yang membaca header `Authorization`, memvalidasi JWT, lalu mengisi `HttpContext.User`.

Jika token tidak valid, request dianggap anonymous.

### Protected Endpoint

Protected endpoint adalah endpoint yang hanya bisa diakses user login. Di ASP.NET Core minimal API, endpoint bisa diberi `.RequireAuthorization()`.

## Scope Fitur Di File Ini

Fitur yang dibuat:

- register user;
- login user;
- get current user `GET /auth/me`;
- protected endpoint sederhana `GET /auth/protected`;
- password hashing;
- JWT generation;
- role sederhana `Admin` dan `Member`;
- `ApiResponse` envelope;
- validation request sederhana;
- error response sederhana;
- in-memory repository.

Yang belum dibuat di file ini:

- EF Core database table;
- database migration;
- seed admin user;
- refresh token persistence;
- tenant membership;
- permission detail per organization;
- audit log login.

## Struktur Folder Module Identity

```txt
# File: docs/stacks/enterprise-dotnet-spring/backend/03-identity-auth.md
src/
└── Modules/
    └── Identity/
        ├── Domain/
        │   ├── User.cs
        │   ├── Role.cs
        │   └── UserRole.cs
        │
        ├── Application/
        │   ├── Abstractions/
        │   │   ├── IUserRepository.cs
        │   │   ├── IPasswordHasher.cs
        │   │   └── IJwtTokenService.cs
        │   │
        │   ├── Register/
        │   │   ├── RegisterRequest.cs
        │   │   ├── RegisterResponse.cs
        │   │   └── RegisterHandler.cs
        │   │
        │   ├── Login/
        │   │   ├── LoginRequest.cs
        │   │   ├── LoginResponse.cs
        │   │   └── LoginHandler.cs
        │   │
        │   └── Me/
        │       ├── CurrentUserResponse.cs
        │       └── GetCurrentUserHandler.cs
        │
        ├── Infrastructure/
        │   ├── InMemoryUserRepository.cs
        │   ├── PasswordHasher.cs
        │   ├── JwtOptions.cs
        │   └── JwtTokenService.cs
        │
        ├── Presentation/
        │   └── IdentityEndpoints.cs
        │
        └── IdentityModule.cs
```

## Command Membuat Folder

Jalankan dari root backend.

```powershell
# File: ProjectManagement.Backend/commands/31-create-identity-folders.ps1
mkdir src/Modules/Identity/Domain
mkdir src/Modules/Identity/Application
mkdir src/Modules/Identity/Application/Abstractions
mkdir src/Modules/Identity/Application/Register
mkdir src/Modules/Identity/Application/Login
mkdir src/Modules/Identity/Application/Me
mkdir src/Modules/Identity/Infrastructure
mkdir src/Modules/Identity/Presentation
```

Penjelasan:

- `Domain` berisi entity dan enum identity.
- `Application` berisi use case register, login, dan current user.
- `Application/Abstractions` berisi interface yang dibutuhkan use case.
- `Infrastructure` berisi implementasi hashing, token, dan repository in-memory.
- `Presentation` berisi endpoint HTTP.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Directory structure created without errors.
```

## Package JWT

Tambahkan package JWT ke API host atau infrastructure identity, tergantung struktur project yang dipakai. Untuk setup sederhana, pasang di host API dan module infrastructure identity.

```powershell
# File: ProjectManagement.Backend/commands/32-add-jwt-package.ps1
dotnet add src/ProjectManagement.Api/ProjectManagement.Api.csproj package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add src/Modules/Identity/ProjectManagement.Identity.Infrastructure/ProjectManagement.Identity.Infrastructure.csproj package System.IdentityModel.Tokens.Jwt
```

Penjelasan:

- `Microsoft.AspNetCore.Authentication.JwtBearer` dipakai middleware ASP.NET Core untuk membaca token dari header.
- `System.IdentityModel.Tokens.Jwt` dipakai service token untuk membuat JWT.

Jika memakai struktur folder tunggal `src/Modules/Identity/Infrastructure` tanpa class library terpisah, pasang package pada project yang berisi file `JwtTokenService.cs`.

## Domain Layer

Domain layer menyimpan aturan dasar user dan role. Domain tidak tahu JWT, HTTP, atau database.

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Domain/Role.cs
namespace App.Modules.Identity.Domain;

public enum Role
{
    Admin = 1,
    Member = 2
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Domain/UserRole.cs
namespace App.Modules.Identity.Domain;

public sealed class UserRole
{
    public UserRole(Guid userId, Role role)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("UserId wajib diisi.");

        UserId = userId;
        Role = role;
    }

    public Guid UserId { get; }
    public Role Role { get; }
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Domain/User.cs
namespace App.Modules.Identity.Domain;

public sealed class User
{
    private readonly List<UserRole> _roles = new();

    private User(
        Guid id,
        string name,
        string email,
        string passwordHash,
        Role initialRole)
    {
        Id = id;
        Name = name;
        Email = email;
        PasswordHash = passwordHash;
        CreatedAt = DateTimeOffset.UtcNow;
        _roles.Add(new UserRole(id, initialRole));
    }

    public Guid Id { get; private set; }
    public string Name { get; private set; }
    public string Email { get; private set; }
    public string PasswordHash { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public IReadOnlyCollection<UserRole> Roles => _roles.AsReadOnly();

    public static User Register(
        string name,
        string email,
        string passwordHash,
        Role role)
    {
        if (string.IsNullOrWhiteSpace(name) || name.Trim().Length < 2)
            throw new ArgumentException("Nama minimal 2 karakter.");

        if (string.IsNullOrWhiteSpace(email) || !email.Contains('@'))
            throw new ArgumentException("Email tidak valid.");

        if (string.IsNullOrWhiteSpace(passwordHash))
            throw new ArgumentException("Password hash wajib diisi.");

        return new User(
            Guid.NewGuid(),
            name.Trim(),
            email.Trim().ToLowerInvariant(),
            passwordHash,
            role);
    }

    public bool HasRole(Role role)
    {
        return _roles.Any(userRole => userRole.Role == role);
    }

    public string PrimaryRoleName()
    {
        return _roles.FirstOrDefault()?.Role.ToString() ?? Role.Member.ToString();
    }
}
```

## Application Abstractions

Application layer tidak membuat hash dan token sendiri. Ia bergantung pada interface agar implementasi teknis bisa diganti.

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Application/Abstractions/IUserRepository.cs
using App.Modules.Identity.Domain;

namespace App.Modules.Identity.Application.Abstractions;

public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid userId, CancellationToken cancellationToken);
    Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken);
    Task<bool> EmailExistsAsync(string email, CancellationToken cancellationToken);
    Task AddAsync(User user, CancellationToken cancellationToken);
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Application/Abstractions/IPasswordHasher.cs
namespace App.Modules.Identity.Application.Abstractions;

public interface IPasswordHasher
{
    string Hash(string password);
    bool Verify(string password, string passwordHash);
}
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Application/Abstractions/IJwtTokenService.cs
using App.Modules.Identity.Domain;

namespace App.Modules.Identity.Application.Abstractions;

public interface IJwtTokenService
{
    string GenerateAccessToken(User user);
}
```

## Register Use Case

Register menerima nama, email, dan password. Password di-hash sebelum user disimpan.

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Application/Register/RegisterRequest.cs
namespace App.Modules.Identity.Application.Register;

public sealed record RegisterRequest(
    string Name,
    string Email,
    string Password);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Application/Register/RegisterResponse.cs
namespace App.Modules.Identity.Application.Register;

public sealed record RegisterResponse(
    Guid UserId,
    string Name,
    string Email,
    string Role,
    DateTimeOffset CreatedAt);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Application/Register/RegisterHandler.cs
using App.Modules.Identity.Application.Abstractions;
using App.Modules.Identity.Domain;
using App.SharedKernel.Results;

namespace App.Modules.Identity.Application.Register;

public sealed class RegisterHandler
{
    private readonly IUserRepository _users;
    private readonly IPasswordHasher _passwordHasher;

    public RegisterHandler(
        IUserRepository users,
        IPasswordHasher passwordHasher)
    {
        _users = users;
        _passwordHasher = passwordHasher;
    }

    public async Task<Result<RegisterResponse>> HandleAsync(
        RegisterRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Name) || request.Name.Trim().Length < 2)
        {
            return Result<RegisterResponse>.Failure(new AppError(
                "IDENTITY_NAME_INVALID",
                "Nama minimal 2 karakter."));
        }

        if (string.IsNullOrWhiteSpace(request.Email) || !request.Email.Contains('@'))
        {
            return Result<RegisterResponse>.Failure(new AppError(
                "IDENTITY_EMAIL_INVALID",
                "Email tidak valid."));
        }

        if (string.IsNullOrWhiteSpace(request.Password) || request.Password.Length < 8)
        {
            return Result<RegisterResponse>.Failure(new AppError(
                "IDENTITY_PASSWORD_WEAK",
                "Password minimal 8 karakter."));
        }

        var normalizedEmail = request.Email.Trim().ToLowerInvariant();
        var emailExists = await _users.EmailExistsAsync(normalizedEmail, cancellationToken);

        if (emailExists)
        {
            return Result<RegisterResponse>.Failure(new AppError(
                "IDENTITY_EMAIL_ALREADY_REGISTERED",
                "Email sudah terdaftar."));
        }

        var passwordHash = _passwordHasher.Hash(request.Password);
        var user = User.Register(
            request.Name,
            normalizedEmail,
            passwordHash,
            Role.Member);

        await _users.AddAsync(user, cancellationToken);

        return Result<RegisterResponse>.Success(new RegisterResponse(
            user.Id,
            user.Name,
            user.Email,
            user.PrimaryRoleName(),
            user.CreatedAt));
    }
}
```

## Login Use Case

Login memeriksa email dan password. Jika benar, backend membuat JWT access token.

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Application/Login/LoginRequest.cs
namespace App.Modules.Identity.Application.Login;

public sealed record LoginRequest(
    string Email,
    string Password);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Application/Login/LoginResponse.cs
namespace App.Modules.Identity.Application.Login;

public sealed record LoginResponse(
    string AccessToken,
    string TokenType,
    int ExpiresInSeconds,
    LoginUserResponse User);

public sealed record LoginUserResponse(
    Guid Id,
    string Name,
    string Email,
    string Role);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Application/Login/LoginHandler.cs
using App.Modules.Identity.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Identity.Application.Login;

public sealed class LoginHandler
{
    private readonly IUserRepository _users;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IJwtTokenService _jwtTokenService;

    public LoginHandler(
        IUserRepository users,
        IPasswordHasher passwordHasher,
        IJwtTokenService jwtTokenService)
    {
        _users = users;
        _passwordHasher = passwordHasher;
        _jwtTokenService = jwtTokenService;
    }

    public async Task<Result<LoginResponse>> HandleAsync(
        LoginRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
        {
            return Result<LoginResponse>.Failure(new AppError(
                "IDENTITY_LOGIN_INVALID",
                "Email dan password wajib diisi."));
        }

        var normalizedEmail = request.Email.Trim().ToLowerInvariant();
        var user = await _users.GetByEmailAsync(normalizedEmail, cancellationToken);

        if (user is null)
        {
            return Result<LoginResponse>.Failure(new AppError(
                "IDENTITY_INVALID_CREDENTIALS",
                "Email atau password salah."));
        }

        var passwordValid = _passwordHasher.Verify(request.Password, user.PasswordHash);

        if (!passwordValid)
        {
            return Result<LoginResponse>.Failure(new AppError(
                "IDENTITY_INVALID_CREDENTIALS",
                "Email atau password salah."));
        }

        var accessToken = _jwtTokenService.GenerateAccessToken(user);

        return Result<LoginResponse>.Success(new LoginResponse(
            accessToken,
            "Bearer",
            3600,
            new LoginUserResponse(
                user.Id,
                user.Name,
                user.Email,
                user.PrimaryRoleName())));
    }
}
```

## Current User Use Case

`/auth/me` membaca user id dari claim token, lalu mengambil user dari repository.

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Application/Me/CurrentUserResponse.cs
namespace App.Modules.Identity.Application.Me;

public sealed record CurrentUserResponse(
    Guid Id,
    string Name,
    string Email,
    string Role);
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Application/Me/GetCurrentUserHandler.cs
using App.Modules.Identity.Application.Abstractions;
using App.SharedKernel.Results;

namespace App.Modules.Identity.Application.Me;

public sealed class GetCurrentUserHandler
{
    private readonly IUserRepository _users;

    public GetCurrentUserHandler(IUserRepository users)
    {
        _users = users;
    }

    public async Task<Result<CurrentUserResponse>> HandleAsync(
        Guid currentUserId,
        CancellationToken cancellationToken)
    {
        if (currentUserId == Guid.Empty)
        {
            return Result<CurrentUserResponse>.Failure(new AppError(
                "IDENTITY_CURRENT_USER_INVALID",
                "Current user tidak valid."));
        }

        var user = await _users.GetByIdAsync(currentUserId, cancellationToken);

        if (user is null)
        {
            return Result<CurrentUserResponse>.Failure(new AppError(
                "IDENTITY_CURRENT_USER_NOT_FOUND",
                "User tidak ditemukan."));
        }

        return Result<CurrentUserResponse>.Success(new CurrentUserResponse(
            user.Id,
            user.Name,
            user.Email,
            user.PrimaryRoleName()));
    }
}
```

## Infrastructure Layer

Infrastructure berisi implementasi repository, password hasher, dan JWT token service.

### In-memory Repository

Repository ini menyimpan user di memory aplikasi. Data akan hilang saat aplikasi restart. Ini cukup untuk memahami alur register/login sebelum masuk database.

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Infrastructure/InMemoryUserRepository.cs
using App.Modules.Identity.Application.Abstractions;
using App.Modules.Identity.Domain;

namespace App.Modules.Identity.Infrastructure;

public sealed class InMemoryUserRepository : IUserRepository
{
    private static readonly List<User> Users = new();

    public Task<User?> GetByIdAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = Users.FirstOrDefault(item => item.Id == userId);
        return Task.FromResult(user);
    }

    public Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken)
    {
        var normalizedEmail = email.Trim().ToLowerInvariant();
        var user = Users.FirstOrDefault(item => item.Email == normalizedEmail);
        return Task.FromResult(user);
    }

    public Task<bool> EmailExistsAsync(string email, CancellationToken cancellationToken)
    {
        var normalizedEmail = email.Trim().ToLowerInvariant();
        var exists = Users.Any(item => item.Email == normalizedEmail);
        return Task.FromResult(exists);
    }

    public Task AddAsync(User user, CancellationToken cancellationToken)
    {
        Users.Add(user);
        return Task.CompletedTask;
    }
}
```

### Password Hasher

Password hasher memakai PBKDF2. Format hash yang disimpan:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/03-identity-auth.md
<iterations>.<salt-base64>.<hash-base64>
```

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Infrastructure/PasswordHasher.cs
using System.Security.Cryptography;
using App.Modules.Identity.Application.Abstractions;

namespace App.Modules.Identity.Infrastructure;

public sealed class PasswordHasher : IPasswordHasher
{
    private const int SaltSize = 16;
    private const int KeySize = 32;
    private const int Iterations = 100_000;

    public string Hash(string password)
    {
        if (string.IsNullOrWhiteSpace(password))
            throw new ArgumentException("Password wajib diisi.");

        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var hash = Rfc2898DeriveBytes.Pbkdf2(
            password,
            salt,
            Iterations,
            HashAlgorithmName.SHA256,
            KeySize);

        return string.Join('.',
            Iterations,
            Convert.ToBase64String(salt),
            Convert.ToBase64String(hash));
    }

    public bool Verify(string password, string passwordHash)
    {
        if (string.IsNullOrWhiteSpace(password) || string.IsNullOrWhiteSpace(passwordHash))
            return false;

        var parts = passwordHash.Split('.', 3);

        if (parts.Length != 3)
            return false;

        if (!int.TryParse(parts[0], out var iterations))
            return false;

        var salt = Convert.FromBase64String(parts[1]);
        var expectedHash = Convert.FromBase64String(parts[2]);

        var actualHash = Rfc2898DeriveBytes.Pbkdf2(
            password,
            salt,
            iterations,
            HashAlgorithmName.SHA256,
            expectedHash.Length);

        return CryptographicOperations.FixedTimeEquals(actualHash, expectedHash);
    }
}
```

### JWT Options

JWT options dibaca dari `appsettings.json`.

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Infrastructure/JwtOptions.cs
namespace App.Modules.Identity.Infrastructure;

public sealed class JwtOptions
{
    public const string SectionName = "Jwt";

    public string Issuer { get; init; } = string.Empty;
    public string Audience { get; init; } = string.Empty;
    public string SecretKey { get; init; } = string.Empty;
    public int AccessTokenExpirationMinutes { get; init; } = 60;
}
```

### JWT Token Service

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Infrastructure/JwtTokenService.cs
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using App.Modules.Identity.Application.Abstractions;
using App.Modules.Identity.Domain;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace App.Modules.Identity.Infrastructure;

public sealed class JwtTokenService : IJwtTokenService
{
    private readonly JwtOptions _options;

    public JwtTokenService(IOptions<JwtOptions> options)
    {
        _options = options.Value;
    }

    public string GenerateAccessToken(User user)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Email, user.Email),
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Name, user.Name),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Role, user.PrimaryRoleName())
        };

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SecretKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(_options.AccessTokenExpirationMinutes),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
```

## Identity Module DI

`IdentityModule` menjadi pintu registrasi dependency Identity. API host cukup memanggil `AddIdentityModule()` dan `MapIdentityEndpoints()`.

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/IdentityModule.cs
using App.Modules.Identity.Application.Abstractions;
using App.Modules.Identity.Application.Login;
using App.Modules.Identity.Application.Me;
using App.Modules.Identity.Application.Register;
using App.Modules.Identity.Infrastructure;
using App.Modules.Identity.Presentation;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace App.Modules.Identity;

public static class IdentityModule
{
    public static IServiceCollection AddIdentityModule(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.Configure<JwtOptions>(configuration.GetSection(JwtOptions.SectionName));

        services.AddSingleton<IUserRepository, InMemoryUserRepository>();
        services.AddSingleton<IPasswordHasher, PasswordHasher>();
        services.AddSingleton<IJwtTokenService, JwtTokenService>();

        services.AddScoped<RegisterHandler>();
        services.AddScoped<LoginHandler>();
        services.AddScoped<GetCurrentUserHandler>();

        return services;
    }

    public static IEndpointRouteBuilder MapIdentityModule(this IEndpointRouteBuilder app)
    {
        app.MapIdentityEndpoints();
        return app;
    }
}
```

## Presentation Layer

Endpoint yang dibuat:

- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`
- `GET /auth/protected`

```csharp
// File: ProjectManagement.Backend/src/Modules/Identity/Presentation/IdentityEndpoints.cs
using System.Security.Claims;
using App.Modules.Identity.Application.Login;
using App.Modules.Identity.Application.Me;
using App.Modules.Identity.Application.Register;
using App.SharedKernel.Responses;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace App.Modules.Identity.Presentation;

public static class IdentityEndpoints
{
    public static IEndpointRouteBuilder MapIdentityEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/auth")
            .WithTags("Identity");

        group.MapPost("/register", RegisterAsync);
        group.MapPost("/login", LoginAsync);
        group.MapGet("/me", GetMeAsync).RequireAuthorization();
        group.MapGet("/protected", GetProtectedAsync).RequireAuthorization();

        return app;
    }

    private static async Task<IResult> RegisterAsync(
        RegisterRequest request,
        RegisterHandler handler,
        CancellationToken cancellationToken)
    {
        var result = await handler.HandleAsync(request, cancellationToken);

        if (result.IsFailure)
        {
            return Results.BadRequest(ApiResponse<RegisterResponse>.Fail(new ApiErrorResponse(
                result.Error!.Code,
                result.Error.Message,
                result.Error.Details)));
        }

        return Results.Created(
            $"/users/{result.Value!.UserId}",
            ApiResponse<RegisterResponse>.Ok(result.Value));
    }

    private static async Task<IResult> LoginAsync(
        LoginRequest request,
        LoginHandler handler,
        CancellationToken cancellationToken)
    {
        var result = await handler.HandleAsync(request, cancellationToken);

        if (result.IsFailure)
        {
            return Results.BadRequest(ApiResponse<LoginResponse>.Fail(new ApiErrorResponse(
                result.Error!.Code,
                result.Error.Message,
                result.Error.Details)));
        }

        return Results.Ok(ApiResponse<LoginResponse>.Ok(result.Value!));
    }

    private static async Task<IResult> GetMeAsync(
        ClaimsPrincipal user,
        GetCurrentUserHandler handler,
        CancellationToken cancellationToken)
    {
        var userIdValue = user.FindFirstValue(ClaimTypes.NameIdentifier);

        if (!Guid.TryParse(userIdValue, out var currentUserId))
        {
            return Results.Unauthorized();
        }

        var result = await handler.HandleAsync(currentUserId, cancellationToken);

        if (result.IsFailure)
        {
            return Results.NotFound(ApiResponse<CurrentUserResponse>.Fail(new ApiErrorResponse(
                result.Error!.Code,
                result.Error.Message,
                result.Error.Details)));
        }

        return Results.Ok(ApiResponse<CurrentUserResponse>.Ok(result.Value!));
    }

    private static IResult GetProtectedAsync(ClaimsPrincipal user)
    {
        var response = new
        {
            message = "Endpoint ini hanya bisa diakses user yang login.",
            userId = user.FindFirstValue(ClaimTypes.NameIdentifier),
            email = user.FindFirstValue(ClaimTypes.Email),
            role = user.FindFirstValue(ClaimTypes.Role)
        };

        return Results.Ok(ApiResponse<object>.Ok(response));
    }
}
```

## App Settings

Gunakan secret key panjang untuk JWT. Untuk tutorial lokal, simpan di `appsettings.Development.json`. Untuk production, gunakan environment variable atau secret manager.

```json
// File: ProjectManagement.Backend/src/ProjectManagement.Api/appsettings.Development.json
{
  "Jwt": {
    "Issuer": "ProjectManagement.Api",
    "Audience": "ProjectManagement.Web",
    "SecretKey": "dev-only-secret-key-minimum-32-characters-change-me",
    "AccessTokenExpirationMinutes": 60
  }
}
```

## Program.cs

Tambahkan authentication middleware, authorization middleware, dan module Identity.

```csharp
// File: ProjectManagement.Backend/src/ProjectManagement.Api/Program.cs
using System.Text;
using App.Modules.Identity;
using App.Modules.Identity.Infrastructure;
using App.SharedKernel.Responses;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddIdentityModule(builder.Configuration);

var jwtOptions = builder.Configuration
    .GetSection(JwtOptions.SectionName)
    .Get<JwtOptions>() ?? throw new InvalidOperationException("Jwt options belum dikonfigurasi.");

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateIssuerSigningKey = true,
            ValidateLifetime = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidAudience = jwtOptions.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.SecretKey)),
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", () =>
{
    var response = ApiResponse<object>.Ok(new
    {
        service = "ProjectManagement.Api",
        status = "Healthy",
        checkedAt = DateTimeOffset.UtcNow
    });

    return Results.Ok(response);
});

app.MapIdentityModule();

app.Run();
```

Urutan middleware penting:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/03-identity-auth.md
app.UseAuthentication();
app.UseAuthorization();
app.MapIdentityModule();
```

`UseAuthentication()` membaca token dan mengisi `HttpContext.User`. `UseAuthorization()` memeriksa apakah endpoint boleh diakses user tersebut.

## Run Dan Test Manual

Jalankan backend.

```powershell
# File: ProjectManagement.Backend/commands/33-run-api-identity.ps1
dotnet run --project src/ProjectManagement.Api/ProjectManagement.Api.csproj
```

Penjelasan:

- `dotnet run --project` menjalankan host API.
- Endpoint Identity aktif jika `app.MapIdentityModule()` sudah dipanggil.
- Protected endpoint aktif jika `UseAuthentication()` dan `UseAuthorization()` sudah dipasang.

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Now listening on: http://localhost:5000
Application started. Press Ctrl+C to shut down.
```

## Test Register

```powershell
# File: ProjectManagement.Backend/commands/34-test-register.ps1
curl -X POST http://localhost:5000/auth/register `
  -H "Content-Type: application/json" `
  -d '{"name":"Budi Developer","email":"budi@example.com","password":"password123"}'
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-register-response.json
{
  "success": true,
  "data": {
    "userId": "11111111-1111-1111-1111-111111111111",
    "name": "Budi Developer",
    "email": "budi@example.com",
    "role": "Member",
    "createdAt": "2026-07-07T10:00:00.0000000+00:00"
  },
  "error": null,
  "meta": null
}
```

Nilai `userId` dan `createdAt` akan berbeda di mesin masing-masing.

## Test Register Email Duplikat

Jalankan command register yang sama dua kali.

```powershell
# File: ProjectManagement.Backend/commands/35-test-register-duplicate.ps1
curl -X POST http://localhost:5000/auth/register `
  -H "Content-Type: application/json" `
  -d '{"name":"Budi Developer","email":"budi@example.com","password":"password123"}'
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-register-duplicate-response.json
{
  "success": false,
  "data": null,
  "error": {
    "code": "IDENTITY_EMAIL_ALREADY_REGISTERED",
    "message": "Email sudah terdaftar.",
    "details": null
  },
  "meta": null
}
```

## Test Login

```powershell
# File: ProjectManagement.Backend/commands/36-test-login.ps1
curl -X POST http://localhost:5000/auth/login `
  -H "Content-Type: application/json" `
  -d '{"email":"budi@example.com","password":"password123"}'
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-login-response.json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "tokenType": "Bearer",
    "expiresInSeconds": 3600,
    "user": {
      "id": "11111111-1111-1111-1111-111111111111",
      "name": "Budi Developer",
      "email": "budi@example.com",
      "role": "Member"
    }
  },
  "error": null,
  "meta": null
}
```

Simpan `accessToken` untuk test endpoint protected.

## Test Login Password Salah

```powershell
# File: ProjectManagement.Backend/commands/37-test-login-invalid.ps1
curl -X POST http://localhost:5000/auth/login `
  -H "Content-Type: application/json" `
  -d '{"email":"budi@example.com","password":"salah-password"}'
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-login-invalid-response.json
{
  "success": false,
  "data": null,
  "error": {
    "code": "IDENTITY_INVALID_CREDENTIALS",
    "message": "Email atau password salah.",
    "details": null
  },
  "meta": null
}
```

## Test Protected Endpoint Tanpa Token

```powershell
# File: ProjectManagement.Backend/commands/38-test-protected-without-token.ps1
curl http://localhost:5000/auth/protected
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-protected-without-token.txt
HTTP/1.1 401 Unauthorized
```

Endpoint mengembalikan `401` karena `.RequireAuthorization()` membutuhkan user login.

## Test Current User `/auth/me`

Ganti `<access-token>` dengan token dari response login.

```powershell
# File: ProjectManagement.Backend/commands/39-test-auth-me.ps1
curl http://localhost:5000/auth/me `
  -H "Authorization: Bearer <access-token>"
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-auth-me-response.json
{
  "success": true,
  "data": {
    "id": "11111111-1111-1111-1111-111111111111",
    "name": "Budi Developer",
    "email": "budi@example.com",
    "role": "Member"
  },
  "error": null,
  "meta": null
}
```

## Test Protected Endpoint Dengan Token

```powershell
# File: ProjectManagement.Backend/commands/40-test-protected-with-token.ps1
curl http://localhost:5000/auth/protected `
  -H "Authorization: Bearer <access-token>"
```

Expected response:

```json
// File: ProjectManagement.Backend/commands/expected-protected-with-token-response.json
{
  "success": true,
  "data": {
    "message": "Endpoint ini hanya bisa diakses user yang login.",
    "userId": "11111111-1111-1111-1111-111111111111",
    "email": "budi@example.com",
    "role": "Member"
  },
  "error": null,
  "meta": null
}
```

## Build Dan Verifikasi

Build solution.

```powershell
# File: ProjectManagement.Backend/commands/41-build-identity.ps1
dotnet build
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

Cek package JWT.

```powershell
# File: ProjectManagement.Backend/commands/42-check-jwt-package.ps1
dotnet list src/ProjectManagement.Api/ProjectManagement.Api.csproj package
```

Expected output:

```text
# File: ProjectManagement.Backend/commands/expected-output.txt
> Microsoft.AspNetCore.Authentication.JwtBearer
```

## Troubleshooting

### Error: `Jwt options belum dikonfigurasi`

Penyebab:

- section `Jwt` belum ada di `appsettings.Development.json`;
- nama key salah;
- aplikasi berjalan dengan environment selain `Development` dan config tidak tersedia.

Solusi:

```json
// File: ProjectManagement.Backend/src/ProjectManagement.Api/appsettings.Development.json
{
  "Jwt": {
    "Issuer": "ProjectManagement.Api",
    "Audience": "ProjectManagement.Web",
    "SecretKey": "dev-only-secret-key-minimum-32-characters-change-me",
    "AccessTokenExpirationMinutes": 60
  }
}
```

### Error: `Unable to resolve service for type RegisterHandler`

Penyebab:

- `AddIdentityModule(builder.Configuration)` belum dipanggil di `Program.cs`.

Solusi:

```csharp
// File: ProjectManagement.Backend/src/ProjectManagement.Api/Program.cs
builder.Services.AddIdentityModule(builder.Configuration);
```

### Protected Endpoint Selalu 401

Penyebab umum:

- header `Authorization` tidak dikirim;
- token tidak diawali `Bearer `;
- issuer/audience/secret key tidak sama antara generate token dan validation middleware;
- token expired;
- `UseAuthentication()` belum dipasang sebelum `UseAuthorization()`.

Solusi cek urutan middleware:

```csharp
// File: ProjectManagement.Backend/src/ProjectManagement.Api/Program.cs
app.UseAuthentication();
app.UseAuthorization();
app.MapIdentityModule();
```

### Login Berhasil, Tetapi `/auth/me` User Tidak Ditemukan

Penyebab pada tutorial ini:

- repository masih in-memory;
- aplikasi restart setelah login;
- data user hilang karena belum memakai database.

Solusi sementara:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/03-identity-auth.md
Register ulang user setelah aplikasi restart.
Database persistence akan dibuat di 08-database-migration-seed.md.
```

### Secret Key Terlalu Pendek

JWT HMAC membutuhkan secret key yang cukup panjang. Gunakan minimal 32 karakter untuk tutorial.

```json
// File: ProjectManagement.Backend/src/ProjectManagement.Api/appsettings.Development.json
{
  "Jwt": {
    "SecretKey": "dev-only-secret-key-minimum-32-characters-change-me"
  }
}
```

## Checklist Selesai

Identity/Auth dianggap selesai jika:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/03-identity-auth.md
[ ] User domain dibuat.
[ ] Role Admin dan Member tersedia.
[ ] RegisterHandler melakukan validation, hash password, dan simpan user.
[ ] LoginHandler memverifikasi password dan membuat JWT.
[ ] GetCurrentUserHandler membaca user dari repository.
[ ] PasswordHasher tidak menyimpan plain password.
[ ] JwtTokenService membuat claim user id, email, name, dan role.
[ ] IdentityEndpoints punya /auth/register, /auth/login, /auth/me, dan /auth/protected.
[ ] /auth/me dan /auth/protected memakai RequireAuthorization().
[ ] Program.cs memanggil AddAuthentication(), AddAuthorization(), UseAuthentication(), dan UseAuthorization().
[ ] Response sukses dan error memakai ApiResponse envelope.
[ ] curl register, login, /auth/me, dan /auth/protected berhasil.
```

## Ringkasan

Alur register:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/03-identity-auth.md
POST /auth/register
  -> IdentityEndpoints
  -> RegisterHandler
  -> PasswordHasher.Hash
  -> User.Register
  -> IUserRepository.AddAsync
  -> ApiResponse<RegisterResponse>
```

Alur login:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/03-identity-auth.md
POST /auth/login
  -> IdentityEndpoints
  -> LoginHandler
  -> IUserRepository.GetByEmailAsync
  -> PasswordHasher.Verify
  -> JwtTokenService.GenerateAccessToken
  -> ApiResponse<LoginResponse>
```

Alur protected endpoint:

```text
# File: docs/stacks/enterprise-dotnet-spring/backend/03-identity-auth.md
GET /auth/me
  -> JWT middleware membaca Authorization header
  -> HttpContext.User berisi claim
  -> IdentityEndpoints membaca ClaimTypes.NameIdentifier
  -> GetCurrentUserHandler
  -> ApiResponse<CurrentUserResponse>
```

Dengan module Identity ini, file berikutnya bisa mulai membangun organization/tenant dan authorization berbasis membership tanpa mencampur password dan token logic ke module bisnis lain.
