# 06 - Add New Function

Contoh fungsi baru: `completeTask`.

## Backend Domain

Jika ada aturan status transition, tambahkan method ke entity lama:

```ts
complete() {
  if (this.status === "done") {
    throw new Error("Task already completed.");
  }
}
```

Jika entity belum menyimpan mutable state, cukup validasi di use case dulu untuk mockup.

## Backend Use Case

Buat file baru:

```text
workspace-api/src/tasks/application/complete-task.use-case.ts
```

Kenapa file baru: workflow complete berbeda dari create.

## Backend Controller

Tambahkan method ke controller lama karena masih endpoint task:

```ts
@Patch(":id/complete")
complete(@Param("id") id: string, @CurrentUser() user: CurrentUserDto) {
  return this.completeTask.execute({
    taskId: id,
    organizationId: user.organizationId,
    currentUserId: user.id,
  });
}
```

## Backend Repository

Tambahkan method di contract:

```ts
abstract complete(input: { taskId: string; organizationId: string }): Promise<void>;
```

Lalu implementasikan di Prisma repository. Jangan query Prisma langsung dari controller.

## Frontend API

Tambahkan function ke `task-api.ts`:

```ts
export async function completeTask(taskId: string) {
  return fetch(`${API_BASE_URL}/api/tasks/${taskId}/complete`, {
    method: "PATCH",
    headers,
  }).then((res) => res.json());
}
```

## Frontend UI

Jika list masih sederhana, tambahkan button di `TaskList.vue`. Jika mulai kompleks, buat `TaskListItem.vue`.

Checklist:

- use case baru;
- repository contract bertambah;
- repository implementation bertambah;
- controller method bertambah;
- audit log `task.completed`;
- Redis key `task:list:{organizationId}` dihapus;
- Kafka event `task.completed`;
- frontend API function bertambah;
- button UI memanggil API function.
