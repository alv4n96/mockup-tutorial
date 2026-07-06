# Frontend 06 - Code Blueprint Angular Atau React

## Yang Dibuat

Contoh service dan komponen untuk membaca `ApiResponse<T>`.

## TypeScript Contract

```ts
export type ApiError = {
  code: string;
  message: string;
  details?: unknown;
};

export type ApiResponse<T> = {
  data: T | null;
  error: ApiError | null;
  status: number;
  meta?: {
    requestId?: string;
    pagination?: {
      page: number;
      pageSize: number;
      totalItems: number;
      totalPages: number;
    };
  };
};

export type TaskDto = {
  id: string;
  organizationId: string;
  projectId: string;
  title: string;
  status: string;
  assigneeUserId: string | null;
  createdAt: string;
};
```

## Angular Service

```ts
@Injectable({ providedIn: "root" })
export class TaskApi {
  constructor(private readonly http: HttpClient) {}

  createTask(
    organizationId: string,
    input: {
      projectId: string;
      title: string;
      description?: string;
      assigneeUserId?: string;
    }
  ): Observable<ApiResponse<TaskDto>> {
    return this.http.post<ApiResponse<TaskDto>>(
      `/api/organizations/${organizationId}/tasks`,
      input
    );
  }

  listTasks(organizationId: string): Observable<ApiResponse<TaskDto[]>> {
    return this.http.get<ApiResponse<TaskDto[]>>(
      `/api/organizations/${organizationId}/tasks`
    );
  }
}
```

## Angular Component

```ts
@Component({
  selector: "app-task-list",
  template: `
    <p *ngIf="loading">Loading tasks...</p>
    <p *ngIf="error">{{ error }}</p>

    <a routerLink="/tasks/new">Create task</a>

    <ul *ngIf="tasks.length">
      <li *ngFor="let task of tasks">
        <a [routerLink]="['/tasks', task.id]">{{ task.title }}</a>
      </li>
    </ul>

    <p *ngIf="!loading && !tasks.length">No tasks yet.</p>
  `,
})
export class TaskListComponent implements OnInit {
  tasks: TaskDto[] = [];
  loading = false;
  error = "";

  constructor(private readonly taskApi: TaskApi) {}

  ngOnInit(): void {
    this.loading = true;

    this.taskApi.listTasks("active-organization-id").subscribe({
      next: (response) => {
        this.tasks = response.data ?? [];
        this.error = response.error?.message ?? "";
        this.loading = false;
      },
      error: () => {
        this.error = "Failed to load tasks.";
        this.loading = false;
      },
    });
  }
}
```

## React Service

```ts
export async function createTask(
  organizationId: string,
  input: CreateTaskInput
): Promise<ApiResponse<TaskDto>> {
  const response = await fetch(`/api/organizations/${organizationId}/tasks`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });

  return response.json();
}
```

## React Component

```tsx
export function CreateTaskForm({ organizationId }: { organizationId: string }) {
  const [title, setTitle] = useState("");
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setSaving(true);
    setError("");

    const response = await createTask(organizationId, {
      projectId: "active-project-id",
      title,
    });

    setSaving(false);

    if (response.error) {
      setError(response.error.message);
      return;
    }

    window.location.href = `/tasks/${response.data!.id}`;
  }

  return (
    <form onSubmit={onSubmit}>
      <label>
        Title
        <input value={title} onChange={(event) => setTitle(event.target.value)} />
      </label>

      {error ? <p>{error}</p> : null}

      <button disabled={saving}>{saving ? "Saving..." : "Create task"}</button>
    </form>
  );
}
```

## Output

Frontend enterprise membaca response yang sama dari .NET atau Spring:

```ts
{ data: T | null, error: ApiError | null, status: number }
```

## Permission-Aware UI

UI enterprise biasanya menerima active organization beserta permission dari endpoint `/api/me/active-organization`. UI memakai permission untuk menampilkan action, tetapi server tetap mengecek RBAC di handler/use case.

### Contract Permission

```ts
export type Permission =
  | "task:read"
  | "task:create"
  | "task:assign"
  | "task:update"
  | "task:delete"
  | "member:invite"
  | "billing:manage";

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

### Angular: Disable Action Tanpa Permission

```ts
@Component({
  selector: "app-task-toolbar",
  template: `
    <button
      type="button"
      [disabled]="!canCreate"
      routerLink="/tasks/new"
    >
      Create task
    </button>

    <p *ngIf="!canCreate">You do not have permission to create tasks.</p>
  `,
})
export class TaskToolbarComponent {
  @Input({ required: true }) organization!: ActiveOrganizationDto;

  get canCreate(): boolean {
    return can(this.organization, "task:create");
  }
}
```

### Angular: Handle 403 Dari API

```ts
this.taskApi.createTask(this.organization.id, formValue).subscribe({
  next: (response) => {
    if (response.error) {
      this.error = response.error.message;
      return;
    }

    this.router.navigate(["/tasks", response.data!.id]);
  },
  error: (error: HttpErrorResponse) => {
    this.error =
      error.status === 403
        ? "You do not have permission for this action."
        : "Failed to create task.";
  },
});
```

### React: Guard Action Dari Permission

```tsx
export function TaskToolbar({
  organization,
}: {
  organization: ActiveOrganizationDto;
}) {
  if (!can(organization, "task:create")) {
    return <p>You do not have permission to create tasks.</p>;
  }

  return <a href="/tasks/new">Create task</a>;
}
```

Request body tetap tidak membawa role:

```json
{
  "projectId": "6ad0fd06-07fc-4a80-a413-2abf34f66b3a",
  "title": "Create task dari enterprise UI",
  "description": "Role dibaca backend dari membership",
  "assigneeUserId": "7dd30f42-4663-44e7-8455-44b71ed4927a"
}
```