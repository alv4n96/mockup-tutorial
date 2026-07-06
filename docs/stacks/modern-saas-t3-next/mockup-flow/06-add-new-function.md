# 06 - Add New Function

Contoh fungsi baru: `completeTask`.

## Backend

Tambah file baru:

```text
src/server/modules/tasks/complete-task.use-case.ts
```

Isi:

```ts
import { db } from "@/server/infra/db";
import { ForbiddenError } from "@/server/shared/app-error";
import type { CurrentUser } from "@/server/shared/current-user";

export async function completeTask(input: { currentUser: CurrentUser; taskId: string }) {
  const task = await db.task.findFirst({
    where: {
      id: input.taskId,
      organizationId: input.currentUser.organizationId,
    },
  });

  if (!task) {
    throw new ForbiddenError("Task not found in active organization.");
  }

  return db.task.update({
    where: { id: task.id },
    data: { status: "done" },
  });
}
```

Kenapa file baru: workflow `complete task` berbeda dari `create task`.

## API Route

Jika memakai route per id, buat:

```text
src/app/api/tasks/[id]/complete/route.ts
```

Jangan tambahkan semua action ke `src/app/api/tasks/route.ts` karena file itu akan membesar.

## Frontend API

Tambahkan function di file lama `src/app/task-api.ts` karena masih satu API client task:

```ts
export async function completeTask(taskId: string) {
  const response = await fetch(`/api/tasks/${taskId}/complete`, {
    method: "PATCH",
  });

  return response.json();
}
```

## Frontend Component

Tambahkan button di `TaskList` atau `tasks-client.tsx`:

```tsx
<button onClick={() => completeTask(task.id)}>Complete</button>
```

Jika button butuh loading per item, pecah menjadi `TaskListItem.tsx`.

## Checklist

- use case baru dibuat;
- endpoint baru dibuat;
- API client ditambah;
- UI memanggil function API;
- audit log `task.completed` ditulis;
- Redis cache task list dihapus;
- Kafka event `task.completed` dipublish.
