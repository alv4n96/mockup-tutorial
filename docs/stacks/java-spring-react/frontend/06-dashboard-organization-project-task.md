# Frontend 06 - Dashboard Organization, Project, Dan Task

## Tujuan File

Membuat dashboard React Vite yang menampilkan organization list, project list, task board, create form, loading state, empty state, dan error handling.

## Problem Yang Diselesaikan

User butuh layar utama untuk menjalankan flow SaaS: pilih organization, buat project, buat task, ubah status task.

## Konsep Utama

Dashboard memakai feature API sebagai Facade. Component route tidak perlu tahu detail endpoint nested backend selain memanggil function feature.

## Pilihan Teknologi Yang Tersedia

- React state manual.
- TanStack Query.
- SWR.
- Zustand untuk client state.

## Pilihan Yang Dipakai Di Tutorial Ini

React state manual untuk memudahkan pemula membaca flow. Komponen UI memakai shadcn/ui. Pada app production, TanStack Query lebih nyaman untuk cache dan refetch.

## Struktur Folder Yang Akan Dibuat

```text
src/features/organizations/organizationApi.ts
src/features/projects/projectApi.ts
src/features/tasks/taskApi.ts
src/features/tasks/TaskBoard.tsx
src/routes/DashboardRoute.tsx
```

## Command Yang Harus Dijalankan

```bash
cd frontend
mkdir -p src/features/organizations src/features/projects src/features/tasks src/routes
pnpm dlx shadcn@latest add button input card alert select textarea
```

## Full Source Code Untuk Setiap File Yang Dibuat

```ts
// frontend/src/features/organizations/organizationApi.ts
import { apiClient } from "@/lib/api/apiClient";
import type { Organization } from "@/types/domain";

export function listOrganizations() {
  return apiClient<Organization[]>("/organizations");
}

export function createOrganization(input: { name: string }) {
  return apiClient<Organization>("/organizations", { method: "POST", body: input });
}
```

```ts
// frontend/src/features/projects/projectApi.ts
import { apiClient } from "@/lib/api/apiClient";
import type { Project } from "@/types/domain";

export function listProjects(organizationId: string) {
  return apiClient<Project[]>(`/projects?organizationId=${organizationId}`);
}

export function createProject(organizationId: string, input: { name: string; description: string }) {
  return apiClient<Project>(`/projects?organizationId=${organizationId}`, { method: "POST", body: input });
}
```

```ts
// frontend/src/features/tasks/taskApi.ts
import { apiClient } from "@/lib/api/apiClient";
import type { Task, TaskPriority, TaskStatus } from "@/types/domain";

export function listTasks(organizationId: string, projectId: string) {
  return apiClient<Task[]>(`/tasks?organizationId=${organizationId}&projectId=${projectId}`);
}

export function createTask(organizationId: string, projectId: string, input: { title: string; description: string; priority: TaskPriority; dueDate: string | null }) {
  return apiClient<Task>(`/tasks?organizationId=${organizationId}&projectId=${projectId}`, { method: "POST", body: input });
}

export function changeTaskStatus(organizationId: string, projectId: string, taskId: string, status: TaskStatus) {
  return apiClient<Task>(`/tasks/${taskId}/status?organizationId=${organizationId}&projectId=${projectId}`, { method: "PATCH", body: { status } });
}
```

```tsx
// frontend/src/features/tasks/TaskBoard.tsx
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { Task, TaskStatus } from "@/types/domain";

const columns: TaskStatus[] = ["TODO", "IN_PROGRESS", "DONE"];

export function TaskBoard({ tasks, onMove }: { tasks: Task[]; onMove: (task: Task, status: TaskStatus) => void }) {
  return (
    <div className="grid gap-4 md:grid-cols-3">
      {columns.map((status) => (
        <Card key={status}>
          <CardHeader className="pb-3">
            <CardTitle className="text-sm">{status}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {tasks.filter((task) => task.status === status).map((task) => (
              <article key={task.id} className="rounded-md border p-3">
                <div className="text-sm font-medium text-foreground">{task.title}</div>
                <div className="mt-1 text-xs text-muted-foreground">Priority: {task.priority}</div>
                <div className="mt-3 flex flex-wrap gap-2">
                  {columns.filter((next) => next !== task.status).map((next) => (
                    <Button key={next} type="button" variant="outline" size="sm" onClick={() => onMove(task, next)}>
                      {next}
                    </Button>
                  ))}
                </div>
              </article>
            ))}
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
```

```tsx
// frontend/src/routes/DashboardRoute.tsx
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/EmptyState";
import { Input } from "@/components/ui/input";
import { LoadingState } from "@/components/ui/LoadingState";
import { DashboardShell } from "@/components/layout/DashboardShell";
import { useRequireAuth } from "@/features/auth/useRequireAuth";
import { createOrganization, listOrganizations } from "@/features/organizations/organizationApi";
import { createProject, listProjects } from "@/features/projects/projectApi";
import { changeTaskStatus, createTask, listTasks } from "@/features/tasks/taskApi";
import { TaskBoard } from "@/features/tasks/TaskBoard";
import { toUserMessage } from "@/lib/errors/errorMapper";
import type { Organization, Project, Task, TaskStatus } from "@/types/domain";
import { FormEvent, useEffect, useState } from "react";

export function DashboardRoute() {
  const ready = useRequireAuth();
  const [organizations, setOrganizations] = useState<Organization[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [tasks, setTasks] = useState<Task[]>([]);
  const [selectedOrg, setSelectedOrg] = useState("");
  const [selectedProject, setSelectedProject] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  async function load() {
    setLoading(true);
    try {
      const orgs = await listOrganizations();
      setOrganizations(orgs);
      const orgId = orgs[0]?.id ?? "";
      setSelectedOrg(orgId);
      if (orgId) {
        const projectList = await listProjects(orgId);
        setProjects(projectList);
        const projectId = projectList[0]?.id ?? "";
        setSelectedProject(projectId);
        setTasks(projectId ? await listTasks(orgId, projectId) : []);
      }
    } catch (err) {
      setError(toUserMessage(err));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (ready) void load();
  }, [ready]);

  async function addOrganization(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    await createOrganization({ name: String(form.get("name")) });
    event.currentTarget.reset();
    await load();
  }

  async function addProject(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    await createProject(selectedOrg, { name: String(form.get("name")), description: String(form.get("description")) });
    event.currentTarget.reset();
    await load();
  }

  async function addTask(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    await createTask(selectedOrg, selectedProject, {
      title: String(form.get("title")),
      description: String(form.get("description")),
      priority: "MEDIUM",
      dueDate: null,
    });
    event.currentTarget.reset();
    setTasks(await listTasks(selectedOrg, selectedProject));
  }

  async function moveTask(task: Task, status: TaskStatus) {
    await changeTaskStatus(selectedOrg, selectedProject, task.id, status);
    setTasks(await listTasks(selectedOrg, selectedProject));
  }

  if (!ready || loading) return <LoadingState />;

  return (
    <DashboardShell>
      <section className="space-y-6">
        <div>
          <h1 className="text-2xl font-semibold text-foreground">Dashboard</h1>
          <p className="text-sm text-muted-foreground">Kelola organization, project, dan task.</p>
        </div>
        {error ? <Alert variant="destructive"><AlertDescription>{error}</AlertDescription></Alert> : null}
        <Card>
          <CardHeader><CardTitle className="text-base">Organization</CardTitle></CardHeader>
          <CardContent className="space-y-3">
            <form onSubmit={addOrganization} className="flex gap-2">
              <Input name="name" placeholder="Nama organization" />
              <Button>Buat Organization</Button>
            </form>
            {organizations.length === 0 ? <EmptyState title="Belum ada organization" description="Buat organization pertama untuk mulai." /> : null}
          </CardContent>
        </Card>
        <Card>
          <CardHeader><CardTitle className="text-base">Project</CardTitle></CardHeader>
          <CardContent className="space-y-3">
            <form onSubmit={addProject} className="grid gap-2 md:grid-cols-[1fr_1fr_auto]">
              <Input name="name" placeholder="Nama project" />
              <Input name="description" placeholder="Deskripsi" />
              <Button disabled={!selectedOrg}>Buat Project</Button>
            </form>
            {projects.length === 0 ? <EmptyState title="Belum ada project" description="Buat project untuk menampung task." /> : null}
          </CardContent>
        </Card>
        <Card>
          <CardHeader><CardTitle className="text-base">Task</CardTitle></CardHeader>
          <CardContent className="space-y-4">
            <form onSubmit={addTask} className="grid gap-2 md:grid-cols-[1fr_1fr_auto]">
              <Input name="title" placeholder="Judul task" />
              <Input name="description" placeholder="Deskripsi task" />
              <Button disabled={!selectedProject}>Buat Task</Button>
            </form>
            <TaskBoard tasks={tasks} onMove={moveTask} />
          </CardContent>
        </Card>
      </section>
    </DashboardShell>
  );
}
```

## Penjelasan Kode Penting

Dashboard ini sengaja masih satu route container agar flow mudah dipahami. Setelah stabil, pecah menjadi `OrganizationPanel`, `ProjectPanel`, dan `TaskPanel`. Komponen shadcn/ui dipakai untuk `Card`, `Input`, `Button`, dan `Alert` supaya tampilan konsisten tanpa membuat design system sendiri dari nol.

## Cara Menjalankan

```bash
cd frontend
pnpm dev
```

## Cara Test Manual

Login, buka dashboard, buat organization, buat project, buat task, lalu pindahkan status task.

## Troubleshooting

- Jika create project gagal, pastikan `selectedOrg` terisi.
- Jika task tidak tampil, pastikan `selectedProject` terisi.
- Jika refresh data terasa boros, gunakan TanStack Query.
- Jika styling shadcn tidak muncul, cek `src/index.css` dan Tailwind config.

## Checklist Akhir

- [ ] Organization list tampil.
- [ ] Project list/create tersedia.
- [ ] Task board tampil.
- [ ] Loading, empty, dan error state tersedia.
- [ ] Dashboard memakai shadcn/ui.

## File Lanjutan Berikutnya

Lanjut ke [07-testing-frontend.md](07-testing-frontend.md).


