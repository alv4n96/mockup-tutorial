# 01 - Roadmap Produk Dan Stack

## Tujuan Akhir

Pada akhir tutorial, aplikasi sudah memiliki:

- Landing sederhana atau halaman login.
- Registrasi dan login user.
- Dashboard setelah login.
- Modul organisasi atau workspace.
- Modul utama: task untuk SaaS produktivitas, atau product dan order untuk e-commerce.
- Role dasar: owner, admin, member, customer.
- CRUD lengkap dengan validasi.
- Database migration dan seed.
- Test penting untuk domain, API, dan UI flow.
- Deployment production.

## Dua Track Utama

### Track A: Modern SaaS & Startup Stack

Track ini cocok untuk prototyping cepat, produk SaaS tahap awal, internal tool, marketplace sederhana, dan aplikasi yang membutuhkan end-to-end type safety.

- Frontend: Next.js App Router, React 19, Tailwind CSS.
- Backend: Next.js server layer, tRPC, Node.js atau Bun.
- Database: PostgreSQL dengan Prisma atau Drizzle.
- Hosting: Vercel atau Cloudflare.
- Auth: Auth.js, Clerk, atau Supabase Auth.
- Payment opsional: Stripe.

### Track B: Enterprise & Scalable Stack

Track ini cocok untuk aplikasi mission-critical, sistem internal besar, e-commerce kompleks, dan backend yang membutuhkan reliability, security, audit, dan maintainability tinggi.

- Frontend: Angular atau React dengan TypeScript.
- Backend: .NET atau Spring Boot.
- Database: PostgreSQL atau SQL Server.
- Hosting: container, VM, Kubernetes, Azure, AWS, atau private cloud.
- Auth: OpenID Connect, JWT, IdentityServer, Keycloak, Microsoft Entra ID, atau Spring Security.
- Messaging opsional: RabbitMQ, Azure Service Bus, Kafka.

## Kenapa Modular Monolith

Modular monolith adalah satu aplikasi deployable yang dipecah menjadi modul domain dengan boundary jelas. Ini cocok untuk pembelajaran dan produk awal karena:

- Lebih mudah dipahami daripada microservices.
- Deploy lebih sederhana.
- Transaksi database lebih mudah.
- Refactor antar modul masih murah.
- Struktur bisa berkembang menjadi service terpisah bila produk sudah benar-benar membutuhkan.

## Produk Contoh

Gunakan satu dari dua contoh ini.

### SaaS Task Workspace

Modul:

- Identity: user, login, session.
- Organization: tenant, member, role.
- Task: project, task, assignment, status.
- Billing: plan, subscription, invoice.
- Notification: email, in-app notification.

### E-Commerce Admin

Modul:

- Identity: user, login, session.
- Catalog: product, category, inventory.
- Cart: cart, cart item.
- Order: order, order item, payment status.
- Fulfillment: shipment, tracking.
- Notification: email, order updates.

## Urutan Pengerjaan

1. Tentukan scope MVP.
2. Buat struktur project.
3. Buat database dan migration awal.
4. Bangun modul Identity.
5. Bangun Organization atau Tenant.
6. Bangun modul utama, misalnya Task atau Product.
7. Hubungkan modul utama ke User dan Organization.
8. Tambahkan role dan permission.
9. Tambahkan UI list, detail, create, edit, delete.
10. Tambahkan testing.
11. Tambahkan logging, error handling, dan audit.
12. Deploy.

## Definition Of Done

Sebuah tutorial dianggap selesai jika pembaca bisa:

- Menjalankan aplikasi lokal dari nol.
- Membuat akun.
- Membuat workspace atau organization.
- Membuat task atau product.
- Melihat data hanya sesuai tenant/user yang berhak.
- Menjalankan migration dan seed.
- Menjalankan test.
- Melakukan deploy dengan environment variable production.
