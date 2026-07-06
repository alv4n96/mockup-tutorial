# 05 - React Web Dashboard

Target: membuat frontend yang memanggil API .NET.

## Environment

Buat `web/workspace-web/.env`.

```env
VITE_API_BASE_URL=http://localhost:8080
```

## API Client

Buat `web/workspace-web/src/features/tasks/task-api.ts`.

```ts
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8080";

const headers = {
  "Content-Type": "application/json",
  "x-demo-user-id": "user_owner",
  "x-demo-organization-id": "org_demo",
};

export async function listTasks() {
  const response = await fetch(`${API_BASE_URL}/api/tasks`, { headers });
  return response.json();
}

export async function createTask(input: { title: string; description?: string }) {
  const response = await fetch(`${API_BASE_URL}/api/tasks`, {
    method: "POST",
    headers,
    body: JSON.stringify(input),
  });

  return response.json();
}
```

API client dibuat file baru karena component tidak boleh tahu detail URL dan header.

## Hook

Buat `web/workspace-web/src/features/tasks/use-tasks.ts`.

```ts
import { useEffect, useState } from "react";
import { createTask, listTasks } from "./task-api";

export function useTasks() {
  const [tasks, setTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);

  async function load() {
    setLoading(true);
    const response = await listTasks();
    setTasks(response.data ?? response);
    setLoading(false);
  }

  async function create(input: { title: string; description?: string }) {
    await createTask(input);
    await load();
  }

  useEffect(() => {
    void load();
  }, []);

  return { tasks, loading, create };
}
```

Hook dibuat karena state UI tidak masuk API client.

## Component

Edit `web/workspace-web/src/App.tsx`.

```tsx
import { FormEvent, useState } from "react";
import { useTasks } from "./features/tasks/use-tasks";

export default function App() {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const { tasks, loading, create } = useTasks();

  async function submit(event: FormEvent) {
    event.preventDefault();
    await create({ title, description });
    setTitle("");
    setDescription("");
  }

  return (
    <main>
      <h1>Enterprise Task Workspace</h1>

      <form onSubmit={submit}>
        <input value={title} onChange={(event) => setTitle(event.target.value)} />
        <textarea
          value={description}
          onChange={(event) => setDescription(event.target.value)}
        />
        <button disabled={loading}>Save</button>
      </form>

      <ul>
        {tasks.map((task) => (
          <li key={task.id}>{task.title}</li>
        ))}
      </ul>
    </main>
  );
}
```

## Kapan Membuat File Baru

- API function baru: tambah ke `task-api.ts`.
- State baru: tambah ke `use-tasks.ts` jika masih fitur task.
- UI makin panjang: pecah `CreateTaskForm.tsx`, `TaskList.tsx`, `AuditLogPanel.tsx`.
- UI audit: buat folder `features/audit`.
