# 04 - Pagination, Filter, Dan Sort

## Query Contract

Gunakan query standar:

```ts
type ListQuery = {
  page?: number;
  pageSize?: number;
  search?: string;
  sortBy?: string;
  sortDirection?: "asc" | "desc";
};
```

Untuk task:

```ts
type ListTasksQuery = ListQuery & {
  organizationId: string;
  status?: "todo" | "in_progress" | "done";
  assigneeUserId?: string;
};
```

## Default

- `page`: 1
- `pageSize`: 20
- max `pageSize`: 100
- default `sortBy`: `createdAt`
- default `sortDirection`: `desc`

## Response Meta

```ts
type PaginationMeta = {
  page: number;
  pageSize: number;
  totalItems: number;
  totalPages: number;
};
```

## Best Practice

- Jangan ambil semua data lalu filter di frontend.
- Batasi field sort yang diperbolehkan.
- Search harus memakai index bila data besar.
- Untuk data real-time atau sangat besar, pertimbangkan cursor pagination.
