# 03 - Validation Dan DTO

## Prinsip

Input dari frontend tidak boleh langsung masuk entity/domain tanpa validasi.

Alur:

```text
Request body/query
  -> input schema/DTO validation
  -> application command/query
  -> domain entity/value object
  -> repository
```

## DTO Layer

Gunakan DTO terpisah untuk:

- Request input.
- Application command/query.
- Response output.

Jangan expose ORM model langsung ke frontend.

## Contoh DTO

```ts
type CreateTaskRequest = {
  organizationId: string;
  projectId: string;
  title: string;
  description?: string;
  assigneeUserId?: string;
};

type TaskResponse = {
  id: string;
  organizationId: string;
  projectId: string;
  title: string;
  status: "todo" | "in_progress" | "done";
  assigneeUserId: string | null;
  createdAt: string;
};
```

## Validasi

Validasi format:

- Required field.
- String length.
- UUID/CUID format.
- Enum.
- Email.
- Date.
- Number min/max.

Validasi bisnis:

- Assignee harus member organization.
- Product harus active untuk dibeli.
- Stok harus cukup.
- Role harus punya permission.

Validasi format dilakukan di presentation/application boundary. Validasi bisnis dilakukan di application/domain.
