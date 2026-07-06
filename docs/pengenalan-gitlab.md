# Pengenalan dan Penggunaan GitLab

GitLab adalah platform untuk menyimpan repository Git dan mengelola proses
pengembangan software bersama tim. Selain menyimpan kode, sebuah project
GitLab dapat digunakan untuk mengelola issue, melakukan review perubahan,
menjalankan pipeline CI/CD, dan melacak pekerjaan hingga siap dirilis.

## Git, GitHub, dan GitLab

```text
Git    = alat version control yang berjalan di komputer
GitHub = layanan hosting repository dan kolaborasi berbasis Git
GitLab = layanan hosting repository dan platform lifecycle pengembangan berbasis Git
```

GitHub dan GitLab sama-sama dapat menjadi remote untuk repository Git. Perintah
dasar Git pada komputer Anda umumnya tetap sama:

```powershell
git clone <url-repository>
git add .
git commit -m "pesan perubahan"
git push
git pull
```

Perbedaannya lebih terasa pada tampilan web, istilah fitur kolaborasi,
pengaturan permission, dan pipeline otomatis yang dipakai oleh tim.

## Istilah Utama di GitLab

```text
Project       = tempat repository, issue, anggota, pipeline, dan pengaturan
Repository    = penyimpanan file dan riwayat Git
Issue         = catatan tugas, bug, atau diskusi pekerjaan
Branch        = jalur perubahan yang terpisah
Merge Request = permintaan untuk mereview dan menggabungkan branch
Pipeline      = rangkaian proses otomatis, misalnya test atau deployment
Runner        = mesin/agent yang menjalankan job pipeline
Milestone     = pengelompokan issue atau target pekerjaan pada periode tertentu
```

Di GitHub istilah yang sering digunakan adalah **Pull Request (PR)**. Di
GitLab fitur yang sepadan disebut **Merge Request (MR)**.

## Workflow Dasar Menggunakan GitLab

### 1. Membuat atau Mengambil Project

Jika project sudah ada di GitLab, ambil repository ke komputer:

```powershell
git clone https://gitlab.com/nama-user/nama-project.git
cd nama-project
```

Jika repository lokal sudah ada dan ingin dihubungkan ke GitLab:

```powershell
git remote add origin https://gitlab.com/nama-user/nama-project.git
git push -u origin main
```

Pastikan nama remote `origin` belum digunakan. Jika repository sebelumnya
sudah terhubung ke GitHub, gunakan nama remote berbeda, misalnya `gitlab`:

```powershell
git remote add gitlab https://gitlab.com/nama-user/nama-project.git
git push -u gitlab main
```

### 2. Membuat Branch Pekerjaan

Mulai dari branch dasar yang sudah terbaru:

```powershell
git switch main
git pull origin main
git switch -c feat/equipment-form
```

Kerjakan file, lalu commit dan push branch:

```powershell
git status
git add .
git commit -m "menambahkan form equipment"
git push -u origin feat/equipment-form
```

### 3. Membuat Merge Request

Setelah branch di-push, buka project di GitLab dan buat Merge Request:

```text
source branch: feat/equipment-form
target branch: main
```

Merge Request digunakan untuk:

```text
menjelaskan perubahan yang dibuat
meminta review dari anggota tim
mendiskusikan baris kode tertentu
melihat hasil pipeline CI/CD
melakukan merge setelah perubahan disetujui
```

Pada GitLab, MR juga dapat ditautkan ke issue sehingga tugas dapat ditutup
ketika perubahan berhasil di-merge.

### 4. Menanggapi Review

Jika reviewer meminta perbaikan, ubah file pada branch yang sama:

```powershell
git add .
git commit -m "memperbaiki hasil review form equipment"
git push
```

Merge Request akan memperbarui perubahan dan pipeline sesuai konfigurasi
project.

## Issue untuk Mengatur Pekerjaan

Issue biasa dipakai untuk mendeskripsikan kebutuhan sebelum kode dibuat:

```text
Judul: Tambahkan validasi serial number equipment
Tujuan: Form menolak serial number kosong
Kriteria selesai:
- pesan error tampil saat input kosong
- data tidak disimpan jika tidak valid
```

Alur kerja yang rapi:

```text
Issue dibuat -> branch dikerjakan -> Merge Request direview -> merge -> issue selesai
```

Nama branch dapat menyertakan nomor issue jika kebijakan tim menggunakannya:

```text
42-feat-equipment-validation
```

## CI/CD di GitLab

CI/CD adalah proses otomatis yang dapat berjalan setelah push atau saat Merge
Request dibuat.

```text
CI = Continuous Integration, misalnya build dan test otomatis
CD = Continuous Delivery/Deployment, misalnya menyiapkan atau merilis aplikasi
```

Konfigurasi pipeline GitLab umumnya disimpan pada file:

```text
.gitlab-ci.yml
```

Contoh sederhana:

```yaml
stages:
  - test

test:
  stage: test
  script:
    - echo "menjalankan test"
```

Dalam project aplikasi nyata, perintah pada `script` biasanya diganti dengan
perintah test sesuai teknologi project, misalnya `npm test` atau `dotnet test`.

Jangan menggabungkan MR jika pipeline wajib masih gagal, kecuali tim telah
menentukan alasan dan prosedur khusus.

## Permission dan Branch Protection

Tim biasanya melindungi branch penting seperti `main` agar tidak semua orang
dapat langsung push atau force push. Dengan protected branch, perubahan perlu
melewati Merge Request, review, dan pipeline yang disyaratkan.

Kebiasaan aman:

- gunakan branch sendiri untuk pekerjaan baru;
- minta review melalui Merge Request;
- jangan force push ke branch bersama tanpa kesepakatan;
- jangan memasukkan password, token, atau credential ke repository;
- pastikan pipeline lulus sebelum merge apabila pipeline diwajibkan.

## GitHub dan GitLab: Pilih yang Mana?

Keduanya dapat dipakai untuk kerja tim berbasis Git. Pilihan biasanya
ditentukan oleh organisasi, integrasi yang diperlukan, kebijakan hosting, dan
pipeline yang telah tersedia. Jika project Anda sudah berada di GitHub, tidak
ada keharusan memindahkannya hanya untuk mempelajari GitLab.

Perbandingan istilah paling penting:

```text
GitHub Pull Request = GitLab Merge Request
GitHub Actions      = salah satu padanan fungsi GitLab CI/CD
```

## Referensi Resmi

- [GitLab: Get started managing code](https://docs.gitlab.com/user/get_started/get_started_managing_code/)
- [GitLab: Merge requests](https://docs.gitlab.com/user/project/merge_requests/)
- [GitLab: CI/CD pipelines](https://docs.gitlab.com/ci/pipelines/)
