# Kasus Umum dalam Kolaborasi Git

Dokumen ini merangkum situasi yang sering ditemui saat bekerja dengan GitHub
atau GitLab. Untuk semua kasus, biasakan memulai dengan:

```powershell
git status
git branch --show-current
```

Kedua perintah tersebut membantu memastikan kondisi file dan branch sebelum
mengambil tindakan.

## 1. Lupa Membuat Branch dan Sudah Mengubah File di main

Situasi:

```text
Anda mulai mengedit file di main, tetapi perubahan belum di-commit.
```

Jika perubahan belum di-commit, Anda dapat langsung membuat branch baru;
perubahan lokal akan ikut berpindah:

```powershell
git switch -c feat/nama-fitur
git status
git add .
git commit -m "menambahkan fitur"
```

Setelah itu, branch `main` tidak menerima commit fitur tersebut.

## 2. Sudah Commit di Branch yang Salah

Situasi:

```text
Commit fitur terbuat di main lokal, tetapi belum di-push.
```

Simpan commit tersebut pada branch fitur:

```powershell
git switch -c feat/nama-fitur
```

Setelah branch baru menunjuk ke commit Anda, kembalikan `main` ke remote hanya
jika Anda yakin commit belum di-push dan working tree bersih:

```powershell
git switch main
git fetch origin
git reset --hard origin/main
```

`git reset --hard` dapat menghapus perubahan lokal. Periksa `git status`
terlebih dahulu.

## 3. Push Ditolak karena Remote Lebih Baru

Situasi umum:

```text
rejected: updates were rejected because the remote contains work...
```

Artinya ada commit di GitHub atau GitLab yang belum ada pada branch lokal
Anda. Ambil perubahan terlebih dahulu:

```powershell
git pull origin nama-branch
```

Jika muncul conflict, selesaikan file conflict, commit hasil merge, lalu push:

```powershell
git add .
git commit -m "menyelesaikan conflict setelah pull"
git push
```

Jangan langsung memakai `git push --force` hanya untuk melewati penolakan.

## 4. Merge Conflict

Situasi:

```text
Dua branch mengubah baris yang sama pada file yang sama.
```

Git menampilkan marker:

```text
<<<<<<< HEAD
isi dari branch aktif
=======
isi dari branch yang digabungkan
>>>>>>> nama-branch-lain
```

Edit file hingga hanya tersisa isi akhir yang benar, lalu:

```powershell
git add nama-file
git commit -m "menyelesaikan merge conflict"
git push
```

Panduan lengkap dengan Notepad dan contoh `init.txt` tersedia pada
[Penyelesaian Conflict Git](penyelesaian-conflict-git.md).

## 5. Ingin Membatalkan Merge yang Sedang Conflict

Jika merge belum di-commit dan hasilnya ingin dibatalkan:

```powershell
git merge --abort
```

Perintah ini berguna ketika Anda ingin kembali ke kondisi sebelum proses merge
dan mendiskusikan perubahan dengan tim terlebih dahulu.

## 6. File Berubah tetapi Belum Siap Di-commit

Situasi:

```text
Anda perlu pindah branch atau pull, tetapi pekerjaan lokal belum selesai.
```

Pilihan yang paling mudah dipahami adalah membuat commit sementara pada
branch pekerjaan:

```powershell
git add .
git commit -m "WIP: simpan sementara perubahan equipment"
```

Jika tim menghindari commit `WIP` pada riwayat final, commit tersebut dapat
dirapikan sebelum merge sesuai workflow tim.

Alternatif Git adalah `stash`:

```powershell
git stash push -m "sementara pekerjaan equipment"
git stash list
git stash pop
```

Gunakan `stash` dengan hati-hati karena perubahan tersimpan di lokal sampai
Anda memulihkannya kembali.

## 7. Tidak Sengaja Menghapus File

Jika file terhapus tetapi penghapusan belum di-commit:

```powershell
git status
git restore nama-file
```

Jika file memang harus dihapus, lakukan commit penghapusannya secara jelas:

```powershell
git add nama-file
git commit -m "menghapus file yang tidak digunakan"
```

## 8. Perubahan Sudah Di-commit tetapi Perlu Dibatalkan

Pada branch bersama atau commit yang sudah di-push, cara yang aman adalah
membuat commit pembalik:

```powershell
git revert <hash-commit>
git push
```

`git revert` mempertahankan riwayat: commit lama tetap terlihat, lalu dibuat
commit baru yang membatalkan perubahannya.

Hindari memakai `reset` dan force push untuk branch yang digunakan tim kecuali
seluruh pihak telah menyetujui penulisan ulang riwayat.

## 9. Terlanjur Commit File Rahasia

Contoh file atau isi rahasia:

```text
.env berisi password
API key
access token
private key
```

Tindakan pertama bukan hanya menghapus file, melainkan:

1. Cabut atau ganti credential yang bocor.
2. Beritahu maintainer atau tim keamanan bila repository milik organisasi.
3. Hapus credential dari kode dan tambahkan file rahasia ke `.gitignore`.
4. Ikuti prosedur tim untuk membersihkan riwayat jika diperlukan.

Credential yang pernah di-push harus dianggap sudah terekspos, termasuk pada
repository private.

## 10. Branch Sudah Di-merge dan Tidak Diperlukan Lagi

Setelah memastikan perubahan berada pada branch tujuan:

```powershell
git switch main
git pull origin main
git branch -d feat/nama-fitur
git push origin --delete feat/nama-fitur
```

Penghapusan branch tidak menghapus commit yang sudah masuk ke `main`.

## 11. Pull Request atau Merge Request Memiliki Conflict

Jika halaman GitHub atau GitLab menyatakan branch tidak dapat di-merge, Anda
dapat menyelesaikannya pada branch sumber di komputer:

```powershell
git switch feat/nama-fitur
git fetch origin
git merge origin/main
```

Selesaikan conflict, lalu:

```powershell
git add .
git commit -m "menggabungkan main dan menyelesaikan conflict"
git push
```

Pull Request atau Merge Request akan otomatis diperbarui.

## Ringkasan Keputusan Aman

```text
Belum commit, salah branch        -> buat branch baru dari kondisi saat ini
Sudah commit lokal, salah branch  -> buat branch baru, pulihkan branch dasar
Remote lebih baru                 -> pull/merge dahulu, jangan force push
Conflict                          -> edit isi akhir, add, commit, push
Commit buruk sudah dibagikan      -> revert
Rahasia ter-push                  -> rotasi credential segera
Ragu sebelum merge                -> status, komunikasi, atau merge --abort
```

Untuk workflow kolaborasi sehari-hari, lihat
[Kolaborasi Project dengan GitHub](kolaborasi-github.md).
