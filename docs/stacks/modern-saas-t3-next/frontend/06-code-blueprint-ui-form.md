# Frontend 06 - Code Blueprint: UI, Form, API State

## Yang Dibuat

Contoh code frontend untuk membaca dan membuat task.

## Struktur File

```text
src/app/(dashboard)/tasks/page.tsx
src/app/(dashboard)/tasks/new/page.tsx
src/features/tasks/components/create-task-form.tsx
src/features/tasks/components/task-list.tsx
src/features/tasks/task-form-schema.ts
```

## `task-form-schema.ts`

```ts
import { z } from "zod";

export const createTaskFormSchema = z.object({
  organizationId: z.string().min(1),
  projectId: z.string().min(1),
  title: z.string().min(3).max(120),
  description: z.string().max(2000).optional(),
  assigneeUserId: z.string().optional(),
});

export type CreateTaskFormValues = z.infer<typeof createTaskFormSchema>;
```

## `create-task-form.tsx`

```tsx
"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import {
  createTaskFormSchema,
  type CreateTaskFormValues,
} from "../task-form-schema";
import { api } from "@/trpc/react";

type Props = {
  organizationId: string;
  projectId: string;
};

export function CreateTaskForm({ organizationId, projectId }: Props) {
  const router = useRouter();
  const createTask = api.task.create.useMutation();

  const form = useForm<CreateTaskFormValues>({
    resolver: zodResolver(createTaskFormSchema),
    defaultValues: {
      organizationId,
      projectId,
      title: "",
      description: "",
      assigneeUserId: "",
    },
  });

  async function onSubmit(values: CreateTaskFormValues) {
    const result = await createTask.mutateAsync(values);
    router.push(`/tasks/${result.data.id}`);
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <label>
        Title
        <input {...form.register("title")} />
      </label>

      {form.formState.errors.title ? (
        <p>{form.formState.errors.title.message}</p>
      ) : null}

      <label>
        Description
        <textarea {...form.register("description")} />
      </label>

      {createTask.error ? <p>{createTask.error.message}</p> : null}

      <button type="submit" disabled={createTask.isPending}>
        {createTask.isPending ? "Saving..." : "Create task"}
      </button>
    </form>
  );
}
```

## `task-list.tsx`

```tsx
"use client";

import Link from "next/link";
import { api } from "@/trpc/react";

type Props = {
  organizationId: string;
};

export function TaskList({ organizationId }: Props) {
  const tasks = api.task.list.useQuery({
    organizationId,
    page: 1,
    pageSize: 20,
  });

  if (tasks.isLoading) {
    return <p>Loading tasks...</p>;
  }

  if (tasks.error) {
    return <p>{tasks.error.message}</p>;
  }

  if (!tasks.data?.data.length) {
    return (
      <div>
        <p>No tasks yet.</p>
        <Link href="/tasks/new">Create task</Link>
      </div>
    );
  }

  return (
    <ul>
      {tasks.data.data.map((task) => (
        <li key={task.id}>
          <Link href={`/tasks/${task.id}`}>{task.title}</Link>
        </li>
      ))}
    </ul>
  );
}
```

## Page Flow

```tsx
export default async function TasksPage() {
  const organizationId = await getActiveOrganizationId();
  return <TaskList organizationId={organizationId} />;
}
```

## Best Practice

- Form schema frontend sama dengan schema backend secara konsep.
- Error backend ditampilkan dari tRPC error.
- Empty state wajib ada.
- Loading state wajib ada.
- URL detail memakai id hasil response backend, bukan id buatan frontend.

## Permission-Aware UI

Frontend boleh menyembunyikan tombol berdasarkan permission, tetapi backend tetap sumber kebenaran. Permission biasanya dikirim dari endpoint/session active organization.

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

### Page Mengirim Permission Ke Komponen

```tsx
export default async function TasksPage() {
  const organization = await getActiveOrganization();

  return (
    <TaskList
      organizationId={organization.id}
      canCreateTask={can(organization, "task:create")}
    />
  );
}
```

### Tombol Berdasarkan Permission

```tsx
type Props = {
  organizationId: string;
  canCreateTask: boolean;
};

export function TaskList({ organizationId, canCreateTask }: Props) {
  const tasks = api.task.list.useQuery({
    organizationId,
    page: 1,
    pageSize: 20,
  });

  return (
    <div>
      {canCreateTask ? <Link href="/tasks/new">Create task</Link> : null}

      {tasks.data?.data.map((task) => (
        <Link key={task.id} href={`/tasks/${task.id}`}>
          {task.title}
        </Link>
      ))}
    </div>
  );
}
```

### Error Forbidden Dari Backend

```tsx
async function onSubmit(values: CreateTaskFormValues) {
  try {
    const result = await createTask.mutateAsync(values);
    router.push(`/tasks/${result.data.id}`);
  } catch (error) {
    form.setError("root", {
      message:
        error instanceof Error
          ? error.message
          : "You do not have permission for this action.",
    });
  }
}
```

Input form tetap data bisnis saja:

```json
{
  "organizationId": "org_01",
  "projectId": "project_01",
  "title": "Create task dari UI",
  "description": "Frontend tidak mengirim role",
  "assigneeUserId": "user_02"
}
```