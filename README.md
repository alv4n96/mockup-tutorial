# Pemisahan Branch Fitur ESOT-ESS-JF2

Dokumen ini menjelaskan cara mempertahankan versi fitur yang lebih awal pada
branch `feat/ESOT-ESS-JF2`, sambil menyimpan pengembangan terbaru pada branch
terpisah bernama `feat/ESOT-ESS-JF2-develop`.

## Penamaan Branch

Git tidak dapat memiliki kedua branch berikut secara bersamaan:

```text
feat/ESOT-ESS-JF2
feat/ESOT-ESS-JF2/develop
```

Branch pertama sudah menggunakan nama `feat/ESOT-ESS-JF2`, sehingga Git tidak
dapat menggunakan nama tersebut sekaligus sebagai jalur menuju `/develop`.

Gunakan nama dengan tanda hubung:

```text
feat/ESOT-ESS-JF2
feat/ESOT-ESS-JF2-develop
```

Maknanya:

```text
feat/ESOT-ESS-JF2         = versi fitur yang dipertahankan sebagai baseline
feat/ESOT-ESS-JF2-develop = pengembangan lanjutan dari fitur tersebut
```

## Riwayat Awal Branch

Saat rencana pemisahan dibuat, riwayat branch adalah:

```text
ac4a973  front end version 2            <- HEAD, origin/feat/ESOT-ESS-JF2
f39a525  backend version 2
db54655  memasukkan wcf untuk equipment <- baseline yang ingin dipertahankan
0952012  memasukkan assets gambar
4920d24  memasukan logic frontend
a98db71  memasukkan logic backend
```

Target akhirnya:

```text
feat/ESOT-ESS-JF2-develop -> ac4a973  menyimpan update pengembangan terbaru
feat/ESOT-ESS-JF2         -> db54655  kembali ke "memasukkan wcf untuk equipment"
```

## Sebelum Menjalankan Langkah Git

Periksa status repository terlebih dahulu:

```powershell
git fetch origin
git status
```

Jangan menjalankan `git reset --hard` saat masih ada perubahan lokal yang
belum disimpan. Contohnya, jika perubahan dokumentasi `README.md` ini masih
terlihat pada `git status`, commit atau stash perubahan tersebut terlebih
dahulu sesuai kebutuhan.

## Langkah Aman Memisahkan Branch

### 1. Buat Branch Pengembangan dari Update Terbaru

Jalankan langkah ini saat posisi branch masih berada pada commit `ac4a973`:

```powershell
git switch feat/ESOT-ESS-JF2
git switch -c feat/ESOT-ESS-JF2-develop
git push -u origin feat/ESOT-ESS-JF2-develop
```

Dengan langkah ini, commit `backend version 2` dan `front end version 2`
tersimpan pada branch pengembangan, termasuk di GitHub.

Periksa posisinya:

```powershell
git log --oneline --decorate -5
```

Hasilnya seharusnya menunjukkan:

```text
ac4a973 (HEAD -> feat/ESOT-ESS-JF2-develop, origin/feat/ESOT-ESS-JF2-develop)
```

### 2. Kembali ke Branch Baseline

```powershell
git switch feat/ESOT-ESS-JF2
```

### 3. Kembalikan Baseline ke Commit yang Diinginkan

```powershell
git reset --hard db546552ca81ad87d2fffea6e0a899c2c37c3da7
```

Branch lokal `feat/ESOT-ESS-JF2` sekarang kembali ke:

```text
db54655 memasukkan wcf untuk equipment
```

Periksa kembali sebelum memperbarui GitHub:

```powershell
git log --oneline --decorate -5
```

### 4. Perbarui Branch Baseline di GitHub

Branch remote semula masih menunjuk ke `ac4a973`. Karena riwayat branch
baseline diubah mundur, pembaruan remote memerlukan force push yang aman:

```powershell
git push --force-with-lease origin feat/ESOT-ESS-JF2
```

Gunakan `--force-with-lease`, bukan `--force`, agar push ditolak jika ternyata
branch remote sudah berubah sejak terakhir diambil.

## Hasil Setelah Pemisahan

Di GitHub, branch akan menjadi:

```text
feat/ESOT-ESS-JF2-develop -> ac4a973 front end version 2
feat/ESOT-ESS-JF2         -> db54655 memasukkan wcf untuk equipment
```

Untuk melanjutkan pekerjaan terbaru:

```powershell
git switch feat/ESOT-ESS-JF2-develop
```

## Menggabungkan Develop Kembali ke Baseline

Branch `feat/ESOT-ESS-JF2-develop` tetap dapat digabungkan kembali ke
`feat/ESOT-ESS-JF2` saat pengembangan sudah siap.

Setelah pemisahan awal, bentuk riwayatnya:

```text
db54655  <- feat/ESOT-ESS-JF2
   |
f39a525
   |
ac4a973  <- feat/ESOT-ESS-JF2-develop
```

Untuk melakukan merge:

```powershell
git switch feat/ESOT-ESS-JF2
git pull origin feat/ESOT-ESS-JF2
git merge feat/ESOT-ESS-JF2-develop
git push origin feat/ESOT-ESS-JF2
```

Jika branch baseline belum memperoleh commit baru setelah kembali ke
`db54655`, merge biasanya menjadi `fast-forward`, sehingga branch baseline
langsung maju kembali hingga commit terbaru:

```text
feat/ESOT-ESS-JF2 -> ac4a973
```

Jika kedua branch sudah sama-sama memiliki commit baru, Git tetap dapat
melakukan merge, tetapi conflict mungkin perlu diselesaikan.

## Hubungannya dengan Staging dan Production

Konsep pemisahan ini mirip dengan menjaga versi stabil dan versi yang sedang
dikembangkan:

```text
feat/ESOT-ESS-JF2         = baseline fitur yang dipertahankan
feat/ESOT-ESS-JF2-develop = pengembangan berikutnya yang sedang dikerjakan
```

Namun, kedua branch tersebut tetap merupakan branch pada level fitur, bukan
branch deployment proyek.

Dalam workflow proyek secara umum:

```text
main        = versi rilis atau production
develop     = integrasi pengembangan, jika digunakan tim
staging     = kandidat rilis untuk pengujian, jika digunakan untuk deployment
feature/... = pekerjaan untuk fitur individual
```

Dengan demikian, `feat/ESOT-ESS-JF2-develop` dapat dianggap sebagai area
pengembangan untuk fitur ini, tetapi bukan pengganti branch `staging` proyek
secara keseluruhan.

## Catatan Keamanan

`git reset --hard` hanya aman dilakukan setelah semua pekerjaan yang perlu
dipertahankan sudah disimpan pada commit atau branch lain dan sudah di-push
jika diperlukan.

`git push --force-with-lease` menulis ulang riwayat branch
`feat/ESOT-ESS-JF2` di GitHub. Jika branch tersebut juga digunakan oleh anggota
tim lain, koordinasikan terlebih dahulu. Commit `f39a525` dan `ac4a973` akan
hilang dari branch baseline, tetapi tetap tersedia pada branch
`feat/ESOT-ESS-JF2-develop`.
