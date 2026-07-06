# Frontend 04 - Code Blueprint Vue: API Client, Composable, Form

## Yang Dibuat

Frontend Vue membaca response envelope dari NestJS.

## Struktur File

```text
src/shared/api/api-response.ts
src/shared/api/http-client.ts
src/features/tasks/api/task-api.ts
src/features/tasks/composables/use-tasks.ts
src/features/tasks/components/CreateTaskForm.vue
```

## `api-response.ts`

```ts
export type ApiError = {
  code: string;
  message: string;
  details?: unknown;
};

export type ApiResponse<T> = {
  data: T | null;
  error: ApiError | null;
  status: number;
  meta?: {
    pagination?: {
      page: number;
      pageSize: number;
      totalItems: number;
      totalPages: number;
    };
  };
};
```

## `task-api.ts`

```ts
import type { ApiResponse } from "@/shared/api/api-response";

export type TaskDto = {
  id: string;
  organizationId: string;
  projectId: string;
  title: string;
  status: string;
  assigneeUserId: string | null;
  createdAt: string;
};

export type CreateTaskInput = {
  projectId: string;
  title: string;
  description?: string;
  assigneeUserId?: string;
};

export async function createTask(
  organizationId: string,
  input: CreateTaskInput
): Promise<ApiResponse<TaskDto>> {
  const response = await fetch(`/api/organizations/${organizationId}/tasks`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });

  return response.json();
}

export async function listTasks(
  organizationId: string
): Promise<ApiResponse<TaskDto[]>> {
  const response = await fetch(`/api/organizations/${organizationId}/tasks`);
  return response.json();
}
```

## `use-tasks.ts`

```ts
import { ref } from "vue";
import { createTask, listTasks, type TaskDto } from "../api/task-api";

export function useTasks(organizationId: string) {
  const tasks = ref<TaskDto[]>([]);
  const loading = ref(false);
  const error = ref("");

  async function load() {
    loading.value = true;
    error.value = "";

    const response = await listTasks(organizationId);

    tasks.value = response.data ?? [];
    error.value = response.error?.message ?? "";
    loading.value = false;
  }

  async function create(input: {
    projectId: string;
    title: string;
    description?: string;
  }) {
    loading.value = true;
    error.value = "";

    const response = await createTask(organizationId, input);

    loading.value = false;

    if (response.error) {
      error.value = response.error.message;
      return null;
    }

    await load();
    return response.data;
  }

  return { tasks, loading, error, load, create };
}
```

## `CreateTaskForm.vue`

```vue
<script setup lang="ts">
import { ref } from "vue";
import { useRouter } from "vue-router";
import { useTasks } from "../composables/use-tasks";

const props = defineProps<{
  organizationId: string;
  projectId: string;
}>();

const router = useRouter();
const title = ref("");
const description = ref("");
const { create, loading, error } = useTasks(props.organizationId);

async function submit() {
  const task = await create({
    projectId: props.projectId,
    title: title.value,
    description: description.value,
  });

  if (task) {
    router.push(`/tasks/${task.id}`);
  }
}
</script>

<template>
  <form @submit.prevent="submit">
    <v-text-field v-model="title" label="Title" />
    <v-textarea v-model="description" label="Description" />

    <v-alert v-if="error" type="error">{{ error }}</v-alert>

    <v-btn type="submit" :loading="loading">
      Create task
    </v-btn>
  </form>
</template>
```

## Output

Vue frontend punya flow:

```text
form -> API client -> ApiResponse<T> -> composable state -> redirect/detail
```

## Permission-Aware UI

Vue boleh menyembunyikan tombol berdasarkan permission dari active organization. Backend NestJS tetap mengecek permission di use case.

### Contract Permission

```ts
export type Permission =
  | "task:read"
  | "task:create"
  | "task:assign"
  | "task:update"
  | "task:delete";

export type ActiveOrganizationDto = {
  id: string;
  name: string;
  role: "owner" | "admin" | "member" | "viewer";
  permissions: Permission[];
};

export function can(
  organization: ActiveOrganizationDto,
  permission: Permission
): boolean {
  return organization.permissions.includes(permission);
}
```

### Composable Active Organization

```ts
import { computed, ref } from "vue";
import { can, type ActiveOrganizationDto, type Permission } from "./permissions";

export function useActiveOrganization() {
  const organization = ref<ActiveOrganizationDto | null>(null);

  async function load() {
    const response = await fetch("/api/me/active-organization");
    const body = await response.json();
    organization.value = body.data;
  }

  function has(permission: Permission) {
    return computed(() => {
      if (!organization.value) return false;
      return can(organization.value, permission);
    });
  }

  return { organization, load, has };
}
```

### Button Berdasarkan Permission

```vue
<script setup lang="ts">
import { onMounted } from "vue";
import { useRouter } from "vue-router";
import { useActiveOrganization } from "../composables/use-active-organization";

const router = useRouter();
const { load, has } = useActiveOrganization();
const canCreateTask = has("task:create");

onMounted(load);
</script>

<template>
  <v-btn
    v-if="canCreateTask"
    type="button"
    @click="router.push('/tasks/new')"
  >
    Create task
  </v-btn>

  <v-alert v-else type="info">
    You do not have permission to create tasks.
  </v-alert>
</template>
```

### Handle 403 Dari NestJS

```ts
async function create(input: CreateTaskInput) {
  loading.value = true;
  error.value = "";

  const response = await createTask(organizationId, input);
  loading.value = false;

  if (response.error) {
    error.value =
      response.error.code === "FORBIDDEN"
        ? "You do not have permission for this action."
        : response.error.message;
    return null;
  }

  await load();
  return response.data;
}
```

Input dari form:

```json
{
  "projectId": "project_01",
  "title": "Create task dari Vue",
  "description": "Permission hanya untuk UI state",
  "assigneeUserId": "user_02"
}
```