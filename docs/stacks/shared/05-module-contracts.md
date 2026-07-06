# 05 - Module Contracts

## Tujuan

Modular monolith butuh aturan komunikasi antar modul. Modul tidak boleh bebas membaca atau menulis internal module lain.

## Bentuk Contract

Contract bisa berupa:

- Public application service.
- Interface lookup.
- Domain/integration event.
- Read model khusus.

## Contoh

Module `Tasks` butuh memastikan assignee adalah member organization. Jangan query tabel `memberships` langsung dari repository `Tasks`.

Gunakan contract:

```ts
interface OrganizationAccessReader {
  isMember(input: {
    organizationId: string;
    userId: string;
  }): Promise<boolean>;
}
```

Application use case:

```ts
class AssignTaskUseCase {
  constructor(
    private readonly tasks: TaskRepository,
    private readonly organizationAccess: OrganizationAccessReader
  ) {}

  async execute(input: AssignTaskInput) {
    const isMember = await this.organizationAccess.isMember({
      organizationId: input.organizationId,
      userId: input.assigneeUserId
    });

    if (!isMember) {
      throw new TaskAssigneeNotMemberError();
    }

    return this.tasks.assign(input.taskId, input.assigneeUserId);
  }
}
```

## Aturan

- Module owner mengatur data internalnya sendiri.
- Module lain hanya mengakses contract publik.
- Contract harus kecil dan stabil.
- Jangan membuat `shared` menjadi tempat semua business logic.
