# Pemisahan Branch Fitur ESOT-ESS-JF2

Dokumen ini menjelaskan cara mempertahankan versi fitur yang lebih awal pada
branch `feat/ESOT-ESS-JF2`, sambil menyimpan pengembangan terbaru pada branch
terpisah bernama `feat/ESOT-JF2-develop`.

## Penamaan Branch

Git tidak dapat memiliki kedua branch berikut secara bersamaan:

```text
feat/ESOT-ESS-JF2
feat/ESOT-ESS-JF2/develop
```

Branch pertama sudah menggunakan nama `feat/ESOT-ESS-JF2`, sehingga Git tidak
dapat menggunakan nama tersebut sekaligus sebagai jalur menuju `/develop`.

Branch yang digunakan di repository ini adalah:

```text
feat/ESOT-ESS-JF2     = versi fitur yang dipertahankan sebagai baseline
feat/ESOT-JF2-develop = pengembangan lanjutan dari fitur tersebut
```

## Riwayat Awal Branch

Saat pemisahan direncanakan, riwayat branch adalah:

```text
ac4a973  front end version 2            <- HEAD, origin/feat/ESOT-ESS-JF2
f39a525  backend version 2
db54655  memasukkan wcf untuk equipment <- baseline yang ingin dipertahankan
0952012  memasukkan assets gambar
4920d24  memasukan logic frontend
a98db71  memasukkan logic backend
```

Target pemisahan:

```text
feat/ESOT-JF2-develop -> ac4a973  menyimpan update pengembangan terbaru
feat/ESOT-ESS-JF2     -> db54655  kembali ke "memasukkan wcf untuk equipment"
```

## Referensi Proses Pemisahan

Proses berikut sudah dilakukan pada repository ini. Jangan menjalankan
perintah pembuatan branch lagi karena `feat/ESOT-JF2-develop` sudah tersedia.

### 1. Memeriksa Repository

Sebelum memindahkan branch atau mengubah riwayat, periksa status repository:

```powershell
git fetch origin
git status
```

Jangan menjalankan `git reset --hard` jika masih ada perubahan lokal penting
yang belum disimpan dalam commit atau stash.

### 2. Menyimpan Update Terbaru pada Branch Develop

Saat branch semula masih berada pada commit `ac4a973`, branch pengembangan
dibuat dan dikirim ke GitHub:

```powershell
git switch feat/ESOT-ESS-JF2
git switch -c feat/ESOT-JF2-develop
git push -u origin feat/ESOT-JF2-develop
```

Dengan langkah tersebut, commit `backend version 2` dan `front end version 2`
tetap aman pada branch pengembangan.

### 3. Mengembalikan Branch Baseline

Branch baseline kemudian dikembalikan ke commit yang ingin dipertahankan:

```powershell
git switch feat/ESOT-ESS-JF2
git reset --hard db546552ca81ad87d2fffea6e0a899c2c37c3da7
git push --force-with-lease origin feat/ESOT-ESS-JF2
```

Gunakan `--force-with-lease`, bukan `--force`, agar push ditolak apabila
branch remote sudah diubah oleh pihak lain sejak terakhir diambil.

## Hasil Pemisahan

Setelah proses tersebut, kedua branch memiliki peran berikut:

```text
feat/ESOT-JF2-develop -> menyimpan front end dan backend version 2
feat/ESOT-ESS-JF2     -> menyimpan baseline pada commit db54655
```

Untuk melanjutkan pekerjaan terbaru:

```powershell
git switch feat/ESOT-JF2-develop
```

## Menggabungkan Develop Kembali ke Baseline

Branch pengembangan dapat digabungkan kembali ketika perubahan sudah siap:

```powershell
git switch feat/ESOT-ESS-JF2
git pull origin feat/ESOT-ESS-JF2
git merge feat/ESOT-JF2-develop
git push origin feat/ESOT-ESS-JF2
```

Jika branch baseline belum mendapat commit baru setelah kembali ke `db54655`,
merge biasanya berupa `fast-forward`. Jika kedua branch sudah memiliki
perubahan baru pada bagian yang sama, merge dapat menghasilkan conflict.

Panduan menangani conflict tersedia pada
[Penyelesaian Conflict Git](penyelesaian-conflict-git.md).

## Hubungannya dengan Staging dan Production

Pola ini mirip dengan menjaga versi stabil dan versi yang sedang dikembangkan:

```text
feat/ESOT-ESS-JF2     = baseline fitur yang dipertahankan
feat/ESOT-JF2-develop = pengembangan berikutnya yang sedang dikerjakan
```

Namun, branch ini berada pada level fitur, bukan deployment proyek. Pada
workflow proyek yang lebih lengkap, `main`, `develop`, atau `staging` dapat
memiliki peran tersendiri untuk rilis dan pengujian.

## Catatan Keamanan

`git reset --hard` hanya aman setelah pekerjaan yang ingin dipertahankan sudah
disimpan pada branch atau commit lain.

`git push --force-with-lease` menulis ulang riwayat branch
`feat/ESOT-ESS-JF2` di GitHub. Apabila branch tersebut dipakai anggota tim
lain, koordinasikan sebelum menjalankannya.
