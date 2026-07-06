# 01 - Create Workspace

Target: membuat dua project yang jelas batasnya.

```powershell
mkdir task-workspace-vue-nest
cd task-workspace-vue-nest
npm i -g @nestjs/cli
nest new workspace-api
npm create vite@latest workspace-web -- --template vue-ts
```

Struktur:

```text
task-workspace-vue-nest/
  workspace-api/
  workspace-web/
  docker-compose.yml
  ops/
    prometheus.yml
```

## Docker

Buat `docker-compose.yml`.

```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app
      POSTGRES_DB: task_workspace
    ports:
      - "5432:5432"

  redis:
    image: redis:7
    ports:
      - "6379:6379"

  redpanda:
    image: redpandadata/redpanda:v24.1.7
    command:
      - redpanda
      - start
      - --overprovisioned
      - --smp
      - "1"
      - --memory
      - 512M
      - --reserve-memory
      - 0M
      - --node-id
      - "0"
      - --check=false
      - --kafka-addr
      - PLAINTEXT://0.0.0.0:9092
      - --advertise-kafka-addr
      - PLAINTEXT://localhost:9092
    ports:
      - "9092:9092"

  grafana:
    image: grafana/grafana:11.1.0
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
    ports:
      - "3001:3000"
```

Jalankan:

```powershell
docker compose up -d
```

## Backend Install

```powershell
cd workspace-api
npm install @nestjs/config @prisma/client class-transformer class-validator ioredis kafkajs
npm install -D prisma tsx
npx prisma init
```

`.env`:

```env
DATABASE_URL="postgresql://app:app@localhost:5432/task_workspace"
REDIS_URL="redis://localhost:6379"
KAFKA_BROKERS="localhost:9092"
DEMO_USER_ID="user_owner"
DEMO_ORGANIZATION_ID="org_demo"
```

## Kenapa Dipisah

- NestJS menjadi backend deployable.
- Vue menjadi frontend deployable.
- Kontrak API menjadi batas komunikasi.
- Ini lebih mudah dipahami pemula dibanding mencampur semua file.
