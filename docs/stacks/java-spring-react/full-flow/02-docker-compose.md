# Full Flow 02 - Docker Compose

## Tujuan File

Membuat Docker Compose untuk PostgreSQL, backend Spring Boot, dan frontend React Vite.

## Problem Yang Diselesaikan

Menjalankan tiga service manual bisa merepotkan. Docker Compose memberi satu command untuk seluruh stack lokal.

## Konsep Utama

Compose membuat network internal. Backend mengakses database lewat host service `postgres`, bukan `localhost`. Frontend Vite dibuild menjadi static asset di folder `dist`, lalu dijalankan dengan `vite preview` untuk mockup lokal.

## Pilihan Teknologi Yang Tersedia

- Docker Compose.
- Dev Containers.
- Kubernetes lokal.
- Manual service.
- Nginx untuk serve static asset frontend.

## Pilihan Yang Dipakai Di Tutorial Ini

Docker Compose untuk local deployment. Frontend container expose port `3000` lewat `pnpm preview`, sedangkan development manual tetap memakai Vite port `5173`.

## Struktur Folder Yang Akan Dibuat

```text
docker-compose.yml
backend/Dockerfile
frontend/Dockerfile
.env.example
```

## Command Yang Harus Dijalankan

```bash
docker compose up -d
docker compose logs -f
docker compose down
```

## Full Source Code Untuk Setiap File Yang Dibuat

```yaml
# springreact-modular-saas-mockup/docker-compose.yml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-springreact}
      POSTGRES_USER: ${POSTGRES_USER:-springreact}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-springreact}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U springreact -d springreact"]
      interval: 5s
      timeout: 5s
      retries: 10

  backend:
    build:
      context: ./backend
    environment:
      SPRING_PROFILES_ACTIVE: dev
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/springreact
      SPRING_DATASOURCE_USERNAME: ${POSTGRES_USER:-springreact}
      SPRING_DATASOURCE_PASSWORD: ${POSTGRES_PASSWORD:-springreact}
      JWT_SECRET: ${JWT_SECRET:-replace-with-a-long-random-secret-at-least-32-characters}
      CORS_ALLOWED_ORIGINS: http://localhost:5173,http://localhost:3000
    ports:
      - "8080:8080"
    depends_on:
      postgres:
        condition: service_healthy

  frontend:
    build:
      context: ./frontend
      args:
        VITE_API_BASE_URL: http://localhost:8080/api
    ports:
      - "3000:3000"
    depends_on:
      - backend

volumes:
  postgres_data:
```

```dockerfile
# backend/Dockerfile
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN ./mvnw -q dependency:go-offline
COPY src src
RUN ./mvnw -q clean package -DskipTests

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

```dockerfile
# frontend/Dockerfile
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile

FROM node:22-alpine AS build
WORKDIR /app
ARG VITE_API_BASE_URL
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
COPY --from=deps /app/node_modules node_modules
COPY . .
RUN corepack enable && pnpm build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps /app/node_modules node_modules
COPY --from=build /app/dist dist
COPY --from=build /app/package.json package.json
EXPOSE 3000
CMD ["pnpm", "preview", "--host", "0.0.0.0", "--port", "3000"]
```

```dotenv
# springreact-modular-saas-mockup/.env.example
POSTGRES_DB=springreact
POSTGRES_USER=springreact
POSTGRES_PASSWORD=springreact
JWT_SECRET=replace-with-a-long-random-secret-at-least-32-characters
```

## Penjelasan Kode Penting

`depends_on.condition: service_healthy` memastikan backend menunggu PostgreSQL siap. Untuk Vite, `VITE_API_BASE_URL` dibaca saat build, jadi Compose mengirimnya sebagai build arg, bukan hanya runtime environment.

## Cara Menjalankan

```bash
docker compose up -d
docker compose logs -f
```

## Cara Test Manual

Buka `http://localhost:3000/login`, login seed user, lalu cek dashboard.

## Troubleshooting

- Jika build backend gagal karena `mvnw` tidak executable di Linux, jalankan `chmod +x backend/mvnw`.
- Jika frontend Docker gagal karena lockfile tidak ada, jalankan `pnpm install` dulu.
- Jika frontend masih memakai API URL lama, rebuild image dengan `docker compose build --no-cache frontend`.
- Jika database data lama membuat seed bentrok, jalankan `docker compose down -v`.

## Checklist Akhir

- [ ] PostgreSQL container punya healthcheck.
- [ ] Backend container expose `8080`.
- [ ] Frontend container expose `3000` untuk preview Docker.
- [ ] Compose bisa naik dan turun.

## File Lanjutan Berikutnya

Lanjut ke [03-end-to-end-flow.md](03-end-to-end-flow.md).



