# Backend 01 - Project Setup Spring Boot

## Tujuan File

Membuat backend Spring Boot dari nol untuk **SpringReact Modular SaaS Mockup**.

## Problem Yang Diselesaikan

Kita butuh backend yang punya struktur jelas sebelum masuk auth, tenancy, project, dan task. Di Java tidak ada file `.sln` seperti .NET. Yang dibuat adalah **root workspace** atau monorepo folder.

## Konsep Utama

Root workspace adalah folder payung:

```text
springreact-modular-saas-mockup/
  backend/
  frontend/
  docker/
  docs/
  docker-compose.yml
  .env.example
```

Backend Spring Boot berada di `backend/`. Frontend React Vite berada di `frontend/`.

## Pilihan Teknologi Yang Tersedia

- Cara membuat project: Spring Initializr web, IntelliJ IDEA, Spring Boot CLI, manual Maven.
- Build tool: Maven atau Gradle.
- Java runtime: 17 atau 21.
- Packaging: JAR atau WAR.

## Pilihan Yang Dipakai Di Tutorial Ini

- Manual Maven dengan wrapper.
- Java 21.
- Spring Boot stable terbaru.
- Packaging JAR.
- Dependencies dari Spring Initializr: Spring Web, Spring Security, Spring Data JPA, PostgreSQL Driver, Flyway, Validation, Lombok, DevTools, Spring Boot Starter Test. Dependency JWT memakai JJWT dan ditambahkan manual di `pom.xml` setelah project dibuat.

## Struktur Folder Yang Akan Dibuat

```text
backend/
  pom.xml
  .env.example
  src/
    main/
      java/com/example/springreact/SpringReactApplication.java
      resources/
        application.yml
        application-dev.yml
    test/
      resources/application-test.yml
```

## Command Yang Harus Dijalankan

```bash
mkdir springreact-modular-saas-mockup
cd springreact-modular-saas-mockup
mkdir backend frontend docker docs
cd backend
```

Jika memakai Spring Initializr:

```bash
curl https://start.spring.io/starter.zip \
  -d type=maven-project \
  -d language=java \
  -d bootVersion=3.3.5 \
  -d baseDir=backend \
  -d groupId=com.example \
  -d artifactId=springreact \
  -d name=springreact \
  -d packageName=com.example.springreact \
  -d packaging=jar \
  -d javaVersion=21 \
  -d dependencies=web,security,data-jpa,postgresql,flyway,validation,lombok,devtools \
  -o backend.zip
```

Catatan: dependency `web,security,data-jpa,postgresql,flyway,validation,lombok,devtools` adalah dependency yang bisa dipilih dari Spring Initializr. Library JWT `io.jsonwebtoken` tidak otomatis ikut dari quickstart ini, jadi tambahkan manual di `backend/pom.xml` seperti contoh full source `pom.xml` di bawah.

Command menjalankan backend:

sebelum jalankan, jangan lupa buat database, dan juga atur di appication.properties
example :

```dotenv
spring.application.name=backend

spring.datasource.url=jdbc:postgresql://localhost:5432/tumbas_app
spring.datasource.username=postgres
spring.datasource.password=postgres
spring.datasource.driver-class-name=org.postgresql.Driver

spring.jpa.hibernate.ddl-auto=validate
spring.jpa.show-sql=true

spring.flyway.enabled=true
```



```bash
cd backend
./mvnw spring-boot:run
mvn test
mvn clean package
```

Di Windows PowerShell:

```powershell
cd backend
.\mvnw spring-boot:run
mvn test
mvn clean package
```

## Full Source Code Untuk Setiap File Yang Dibuat

```xml
<!-- backend/pom.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.3.5</version>
    <relativePath/>
  </parent>

  <groupId>com.example</groupId>
  <artifactId>springreact</artifactId>
  <version>0.0.1-SNAPSHOT</version>
  <name>springreact</name>
  <description>SpringReact Modular SaaS Mockup</description>

  <properties>
    <java.version>21</java.version>
    <jjwt.version>0.12.6</jjwt.version>
    <testcontainers.version>1.20.2</testcontainers.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-security</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-validation</artifactId>
    </dependency>
    <dependency>
      <groupId>org.flywaydb</groupId>
      <artifactId>flyway-core</artifactId>
    </dependency>
    <dependency>
      <groupId>org.flywaydb</groupId>
      <artifactId>flyway-database-postgresql</artifactId>
    </dependency>
    <dependency>
      <groupId>org.postgresql</groupId>
      <artifactId>postgresql</artifactId>
      <scope>runtime</scope>
    </dependency>
    <dependency>
      <groupId>io.jsonwebtoken</groupId>
      <artifactId>jjwt-api</artifactId>
      <version>${jjwt.version}</version>
    </dependency>
    <dependency>
      <groupId>io.jsonwebtoken</groupId>
      <artifactId>jjwt-impl</artifactId>
      <version>${jjwt.version}</version>
      <scope>runtime</scope>
    </dependency>
    <dependency>
      <groupId>io.jsonwebtoken</groupId>
      <artifactId>jjwt-jackson</artifactId>
      <version>${jjwt.version}</version>
      <scope>runtime</scope>
    </dependency>
    <dependency>
      <groupId>org.projectlombok</groupId>
      <artifactId>lombok</artifactId>
      <optional>true</optional>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-devtools</artifactId>
      <scope>runtime</scope>
      <optional>true</optional>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.springframework.security</groupId>
      <artifactId>spring-security-test</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.testcontainers</groupId>
      <artifactId>junit-jupiter</artifactId>
      <version>${testcontainers.version}</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.testcontainers</groupId>
      <artifactId>postgresql</artifactId>
      <version>${testcontainers.version}</version>
      <scope>test</scope>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
        <configuration>
          <excludes>
            <exclude>
              <groupId>org.projectlombok</groupId>
              <artifactId>lombok</artifactId>
            </exclude>
          </excludes>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
```

```yaml
# backend/src/main/resources/application.yml
spring:
  application:
    name: springreact
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:dev}

server:
  port: ${SERVER_PORT:8080}

app:
  jwt:
    issuer: springreact
    secret: ${JWT_SECRET:change-this-secret-to-at-least-32-characters}
    access-token-minutes: ${JWT_ACCESS_TOKEN_MINUTES:15}
    refresh-token-days: ${JWT_REFRESH_TOKEN_DAYS:7}
  cors:
    allowed-origins: ${CORS_ALLOWED_ORIGINS:http://localhost:5173,http://localhost:3000}
```

```yaml
# backend/src/main/resources/application-dev.yml
spring:
  datasource:
    url: ${SPRING_DATASOURCE_URL:jdbc:postgresql://localhost:5432/springreact}
    username: ${SPRING_DATASOURCE_USERNAME:springreact}
    password: ${SPRING_DATASOURCE_PASSWORD:springreact}
  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false
    properties:
      hibernate:
        format_sql: true
  flyway:
    enabled: true
    locations: classpath:db/migration

logging:
  level:
    org.hibernate.SQL: debug
```

```yaml
# backend/src/test/resources/application-test.yml
spring:
  datasource:
    url: jdbc:tc:postgresql:16-alpine:///springreact_test
    driver-class-name: org.testcontainers.jdbc.ContainerDatabaseDriver
  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false
  flyway:
    enabled: true
```

```java
// backend/src/main/java/com/example/springreact/SpringReactApplication.java
package com.example.springreact;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class SpringReactApplication {
  public static void main(String[] args) {
    SpringApplication.run(SpringReactApplication.class, args);
  }
}
```

```dotenv
# backend/.env.example
SPRING_PROFILES_ACTIVE=dev
SERVER_PORT=8080
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/springreact
SPRING_DATASOURCE_USERNAME=springreact
SPRING_DATASOURCE_PASSWORD=springreact
JWT_SECRET=replace-with-a-long-random-secret-at-least-32-characters
JWT_ACCESS_TOKEN_MINUTES=15
JWT_REFRESH_TOKEN_DAYS=7
CORS_ALLOWED_ORIGINS=http://localhost:5173,http://localhost:3000
```

## Penjelasan Kode Penting

- `ddl-auto: validate` membuat Hibernate memvalidasi schema, bukan membuat tabel otomatis. Struktur tabel dipegang Flyway.
- `open-in-view: false` mencegah query database tidak sengaja terjadi dari layer presentation.
- `JWT_SECRET` wajib panjang karena dipakai untuk signing access token.
- Testcontainers dipakai agar repository test memakai PostgreSQL sungguhan, bukan database berbeda seperti H2.

## Cara Menjalankan

Jalankan PostgreSQL dulu, lalu:

```bash
cd backend
./mvnw spring-boot:run
```

## Cara Test Manual

```bash
curl http://localhost:8080/actuator/health
```

Jika actuator belum dipasang, endpoint ini belum tersedia. Untuk tahap awal cukup pastikan log Spring Boot menampilkan `Started SpringReactApplication`.

## Troubleshooting

- `Unsupported class file major version`: pastikan Java 21 aktif.
- `Connection refused`: PostgreSQL belum berjalan.
- `FlywayValidateException`: schema database lama tidak cocok, buat database baru untuk tutorial.
- Lombok error di IDE: aktifkan annotation processing.

## Checklist Akhir

- [ ] Root workspace dipahami sebagai pengganti `.sln`.
- [ ] Backend Spring Boot memakai Maven.
- [ ] Java 21 aktif.
- [ ] Config `dev` dan `test` tersedia.
- [ ] App bisa start.

## File Lanjutan Berikutnya

Lanjut ke [02-modular-monolith-layered-architecture.md](02-modular-monolith-layered-architecture.md).




