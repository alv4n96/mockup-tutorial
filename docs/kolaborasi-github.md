# Kolaborasi Project dengan GitHub

Dokumen ini berisi dasar yang sering digunakan saat mengerjakan project
bersama tim. Tujuannya adalah menjaga pekerjaan setiap orang tetap terpisah,
mudah diperiksa, dan aman untuk digabungkan.

## Git dan GitHub

```text
Git    = alat untuk mencatat perubahan kode di komputer
GitHub = tempat repository online untuk berbagi dan berkolaborasi
```

Perintah dasar:

```text
git commit = menyimpan catatan perubahan di repository lokal
git push   = mengirim commit lokal ke GitHub
git pull   = mengambil sekaligus menggabungkan update dari GitHub
git fetch  = mengambil informasi terbaru tanpa langsung menggabungkannya
```

## Pola Branch dalam Tim

Umumnya perubahan baru dikerjakan pada branch terpisah:

```text
main
  |
  +-- feat/login
  +-- feat/equipment
  +-- fix/validation-error
```

Peran branch biasanya:

```text
main     = kode utama yang relatif stabil atau siap dirilis
feat/... = pekerjaan fitur baru
fix/...  = perbaikan bug
```

Jangan langsung mengerjakan fitur pada `main` jika workflow tim menggunakan
Pull Request. Branch terpisah memudahkan review dan mencegah perubahan yang
belum siap langsung masuk ke kode utama.

## Memulai Pekerjaan Baru

Ambil versi terbaru branch utama, lalu buat branch tugas:

```powershell
git switch main
git pull origin main
git switch -c feat/nama-fitur
```

Contoh:

```powershell
git switch -c feat/equipment-form
```

Gunakan satu branch untuk satu tugas atau satu fitur yang jelas. Hindari
mencampurkan perbaikan yang tidak berkaitan dalam branch yang sama.

## Memeriksa Perubahan

Gunakan perintah ini sesering mungkin:

```powershell
git status
```

`git status` membantu mengetahui:

```text
branch yang sedang aktif
file yang berubah
file yang belum masuk commit
file yang sedang conflict
```

Sebelum commit, Anda juga dapat melihat perubahan isi file:

```powershell
git diff
```

## Membuat Commit

Setelah perubahan siap disimpan:

```powershell
git add .
git commit -m "menambahkan form equipment"
```

Commit sebaiknya kecil dan memiliki tujuan yang jelas. Contoh pesan commit
yang mudah dipahami:

```text
menambahkan validasi form equipment
memperbaiki tampilan tabel equipment
menyelesaikan conflict pada init.txt
```

Hindari pesan terlalu umum:

```text
update
fix
coba lagi
```

Jika ingin lebih berhati-hati sebelum memasukkan semua file, tambahkan file
secara khusus:

```powershell
git add init.txt
git add README.md
```

## Mengirim Branch ke GitHub

Untuk push pertama pada branch baru:

```powershell
git push -u origin feat/nama-fitur
```

Opsi `-u` menghubungkan branch lokal dengan branch remote. Push berikutnya
umumnya cukup dengan:

```powershell
git push
```

## Pull Request dan Review

Setelah branch berada di GitHub, buat Pull Request (PR), misalnya:

```text
feat/equipment-form -> main
```

Pull Request digunakan untuk:

```text
meminta perubahan diperiksa oleh tim
mendiskusikan kode yang dibuat
menjalankan test atau pemeriksaan otomatis
memeriksa conflict sebelum merge
mendapat approval sebelum perubahan digabungkan
```

Jika reviewer meminta perbaikan, lanjutkan mengedit branch yang sama:

```powershell
git add .
git commit -m "memperbaiki hasil review equipment"
git push
```

Pull Request akan otomatis menampilkan commit terbaru tersebut.

## Mengambil Update dari Tim

Sebelum memulai tugas, pastikan branch dasar sudah terbaru:

```powershell
git switch main
git pull origin main
```

Jika Anda sudah bekerja pada branch fitur dan perlu memasukkan update terbaru
dari `main`:

```powershell
git switch main
git pull origin main
git switch feat/nama-fitur
git merge main
```

Merge dapat berjalan otomatis atau menghasilkan conflict bila perubahan Anda
dan perubahan tim mengenai bagian file yang sama. Cara menyelesaikan conflict
dijelaskan pada [Penyelesaian Conflict Git](penyelesaian-conflict-git.md).

Beberapa tim menggunakan `rebase` sebagai pengganti `merge`. Ikuti aturan tim
jika workflow sudah ditentukan.

## Sesudah Branch Selesai Di-merge

Setelah Pull Request telah masuk ke branch tujuan, branch fitur yang tidak
lagi dibutuhkan dapat dihapus:

```powershell
git branch -d feat/nama-fitur
git push origin --delete feat/nama-fitur
```

Hapus branch hanya setelah memastikan perubahan memang sudah berhasil masuk
ke branch tujuan.

## Hal yang Harus Dihindari

### Force Push pada Branch Bersama

Perintah berikut dapat mengganti riwayat remote dan menghilangkan commit
anggota tim lain dari branch tersebut:

```powershell
git push --force
```

Apabila perubahan riwayat memang dibutuhkan, komunikasikan dengan tim dan
gunakan bentuk yang lebih aman:

```powershell
git push --force-with-lease
```

### Reset Hard saat Masih Ada Perubahan Lokal

Perintah berikut dapat membuang perubahan file yang belum disimpan:

```powershell
git reset --hard
```

Periksa dahulu:

```powershell
git status
```

Commit atau stash perubahan yang perlu dipertahankan sebelum melakukan reset.

### Menggabungkan Conflict tanpa Memeriksa Isi

Jangan sekadar menghapus marker conflict. Tentukan versi yang benar atau
gabungkan dua perubahan dengan hati-hati sebelum menjalankan `git add`.

### Menyimpan Data Rahasia

Jangan commit informasi seperti:

```text
password
API key
access token
private key
file konfigurasi rahasia
```

Jika data rahasia sudah terlanjur di-push, menghapusnya dari file pada commit
berikutnya saja tidak cukup; token atau key tersebut juga harus segera diganti.

## Istilah yang Sering Digunakan

```text
clone       = mengambil repository dari GitHub pertama kali
branch      = jalur pekerjaan terpisah
commit      = rekaman perubahan
push        = mengirim commit lokal ke GitHub
pull        = mengambil dan menggabungkan update remote
fetch       = mengambil informasi remote tanpa langsung merge
merge       = menggabungkan riwayat branch
conflict    = perubahan bertabrakan dan perlu dipilih manual
PR          = Pull Request, permintaan penggabungan perubahan
review      = pemeriksaan kode oleh anggota tim
issue       = catatan tugas, bug, atau diskusi
tag/release = penanda versi rilis, misalnya `v1.0.0`
```

## Contoh Alur Harian yang Aman

Mulai tugas:

```powershell
git switch main
git pull origin main
git switch -c feat/equipment-form
```

Kerjakan perubahan, lalu simpan dan kirim branch:

```powershell
git status
git add .
git commit -m "menambahkan form equipment"
git push -u origin feat/equipment-form
```

Setelah itu, buat Pull Request di GitHub, minta review, lakukan perbaikan
jika diperlukan, dan merge setelah perubahan disetujui.

## Kebiasaan Baik

- Jalankan `git status` sebelum commit, pull, merge, atau reset.
- Ambil update terbaru sebelum mulai tugas baru.
- Beri nama branch yang menjelaskan pekerjaan, seperti
  `feat/equipment-form` atau `fix/equipment-validation`.
- Simpan satu pekerjaan yang berkaitan dalam satu branch.
- Buat commit kecil dengan pesan yang jelas.
- Gunakan Pull Request agar perubahan dapat direview.
- Diskusikan sebelum mengubah riwayat branch remote bersama.
- Jaga credential dan file rahasia agar tidak masuk repository.

Untuk contoh pemisahan branch pada repository ini, lihat
[Pemisahan Branch Fitur](pemisahan-branch-fitur.md).
