# 05 - Frontend Task Dashboard

Target file ini: membuat halaman yang memakai API, bukan mock data hardcoded.

## API Client

Buat `src/app/task-api.ts`.

```ts
export async function listTasks() {
  const response = await fetch("/api/tasks");
  return response.json();
}

export async function createTask(input: { title: string; description?: string }) {
  const response = await fetch("/api/tasks", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });

  return response.json();
}
```

File baru karena API client adalah boundary frontend ke backend.

## Component Client

Buat `src/app/tasks-client.tsx`.

```tsx
"use client";

import { useEffect, useState } from "react";
import { createTask, listTasks } from "./task-api";

type Task = {
  id: string;
  title: string;
  description: string | null;
  status: string;
};

export function TasksClient() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");

  async function load() {
    const response = await listTasks();
    setTasks(response.data ?? []);
  }

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    await createTask({ title, description });
    setTitle("");
    setDescription("");
    await load();
  }

  useEffect(() => {
    void load();
  }, []);

  return (
    <main>
      <form onSubmit={submit}>
        <input value={title} onChange={(event) => setTitle(event.target.value)} />
        <textarea
          value={description}
          onChange={(event) => setDescription(event.target.value)}
        />
        <button>Save</button>
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

## Page

Edit `src/app/page.tsx`.

```tsx
import { TasksClient } from "./tasks-client";

export default function Page() {
  return <TasksClient />;
}
```

## Kapan Membuat Component Baru

Buat component baru jika JSX mulai punya tanggung jawab berbeda:

- `CreateTaskForm.tsx` untuk form;
- `TaskList.tsx` untuk list;
- `AuditLogPanel.tsx` untuk audit;
- `AiSummaryPanel.tsx` untuk AI summary.

Jika masih kecil, boleh tetap di `tasks-client.tsx`. Saat file sulit dibaca, pecah.
