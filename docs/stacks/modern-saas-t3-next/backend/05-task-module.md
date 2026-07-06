# Backend 05 - Task Module

## Yang Dibuat

Module utama `tasks` sebagai penghubung antara user, organization, dan project.

## Alur

1. Buat tabel `projects`.
2. Buat tabel `tasks`.
3. Buat entity `Project`.
4. Buat entity `Task`.
5. Buat enum `TaskStatus`.
6. Buat use case `CreateTask`.
7. Buat use case `AssignTask`.
8. Buat use case `ChangeTaskStatus`.
9. Buat use case `ListTasks`.
10. Buat tRPC router `taskRouter`.

## Aturan Bisnis

- Task wajib berada dalam organization.
- Assignee harus member organization yang sama.
- User non-member tidak boleh membaca task.
- Status task hanya boleh berubah mengikuti workflow.

## Output

Backend punya CRUD task lengkap yang aman untuk multi-tenant SaaS.
