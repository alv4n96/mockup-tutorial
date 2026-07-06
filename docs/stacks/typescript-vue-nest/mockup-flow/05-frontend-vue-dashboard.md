# 05 - Frontend Vue Dashboard

Target: membuat UI yang memanggil backend.

## API Client

Buat `workspace-web/src/features/tasks/task-api.ts`.

```ts
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000";

const headers = {
  "Content-Type": "application/json",
  "x-demo-user-id": "user_owner",
  "x-demo-organization-id": "org_demo",
};

export async function listTasks() {
  return fetch(`${API_BASE_URL}/api/tasks`, { headers }).then((res) => res.json());
}

export async function createTask(input: { title: string; description?: string }) {
  return fetch(`${API_BASE_URL}/api/tasks`, {
    method: "POST",
    headers,
    body: JSON.stringify(input),
  }).then((res) => res.json());
}
```

File baru karena API call tidak boleh tersebar di component.

## Composable

Buat `workspace-web/src/features/tasks/use-tasks.ts`.

```ts
import { ref } from "vue";
import { createTask, listTasks } from "./task-api";

export function useTasks() {
  const tasks = ref<any[]>([]);
  const loading = ref(false);
  const error = ref("");

  async function load() {
    loading.value = true;
    try {
      tasks.value = await listTasks();
    } catch {
      error.value = "Cannot load tasks.";
    } finally {
      loading.value = false;
    }
  }

  async function create(input: { title: string; description?: string }) {
    await createTask(input);
    await load();
  }

  return { tasks, loading, error, load, create };
}
```

Composable dibuat karena state loading/error tidak boleh ditaruh di API client.

## App

Edit `workspace-web/src/App.vue`.

```vue
<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useTasks } from "./features/tasks/use-tasks";

const title = ref("");
const description = ref("");
const { tasks, loading, error, load, create } = useTasks();

async function submit() {
  await create({ title: title.value, description: description.value });
  title.value = "";
  description.value = "";
}

onMounted(load);
</script>

<template>
  <main>
    <h1>Task Workspace</h1>

    <form @submit.prevent="submit">
      <input v-model="title" placeholder="Task title" />
      <textarea v-model="description" placeholder="Description" />
      <button :disabled="loading">Save</button>
    </form>

    <p v-if="error">{{ error }}</p>

    <ul>
      <li v-for="task in tasks" :key="task.id">
        {{ task.title }}
      </li>
    </ul>
  </main>
</template>
```

## Pecah Component Saat Membesar

Jika file `App.vue` mulai panjang, buat:

```text
src/features/tasks/components/CreateTaskForm.vue
src/features/tasks/components/TaskList.vue
src/features/tasks/components/AiSummaryPanel.vue
src/features/audit/AuditLogPanel.vue
```

Aturannya: satu component untuk satu bagian UI yang punya data dan event jelas.
