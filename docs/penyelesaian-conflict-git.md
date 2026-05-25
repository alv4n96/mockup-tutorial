# Menyelesaikan Conflict Git dengan Notepad

Conflict terjadi jika dua branch mengubah bagian file yang sama dan Git tidak
dapat menentukan isi akhir secara otomatis. Git menghentikan proses merge
sementara agar pengguna dapat memilih hasil yang benar.

## Contoh dengan init.txt

Isi awal `init.txt`:

```text
1 ayam goreng
2 memasukkan logic back end
3 memasukkan logic front end
4 memasukkan assets gambar
5 finishing untuk WCF equipment
6 revisi bagian backend versi 2
7 revisi bagian frontend versi 2
```

Misalnya branch baseline mengubah baris nomor 5 menjadi:

```text
5 finishing WCF equipment sudah stabil
```

Pada saat yang sama, branch develop mengubah baris yang sama menjadi:

```text
5 finishing WCF equipment dengan validasi tambahan
```

## Memulai Merge

Untuk memasukkan branch develop ke baseline:

```powershell
git switch feat/ESOT-ESS-JF2
git pull origin feat/ESOT-ESS-JF2
git merge feat/ESOT-JF2-develop
```

Jika isi `init.txt` bertentangan, Git dapat menampilkan:

```text
CONFLICT (content): Merge conflict in init.txt
Automatic merge failed; fix conflicts and then commit the result.
```

Periksa file yang conflict:

```powershell
git status
```

## Membuka Conflict dengan Notepad

Buka file yang conflict:

```powershell
notepad init.txt
```

Git akan menambahkan penanda pada isi file:

```text
1 ayam goreng
2 memasukkan logic back end
3 memasukkan logic front end
4 memasukkan assets gambar
<<<<<<< HEAD
5 finishing WCF equipment sudah stabil
=======
5 finishing WCF equipment dengan validasi tambahan
>>>>>>> feat/ESOT-JF2-develop
6 revisi bagian backend versi 2
7 revisi bagian frontend versi 2
```

Penanda tersebut berarti:

```text
<<<<<<< HEAD                   = isi dari branch aktif, yaitu baseline
=======                        = pemisah dua versi isi file
>>>>>>> feat/ESOT-JF2-develop = isi dari branch yang sedang di-merge
```

## Memilih Isi Akhir

Di Notepad, pilih salah satu perubahan atau gabungkan keduanya. Misalnya isi
akhir yang diinginkan adalah:

```text
1 ayam goreng
2 memasukkan logic back end
3 memasukkan logic front end
4 memasukkan assets gambar
5 finishing WCF equipment sudah stabil dengan validasi tambahan
6 revisi bagian backend versi 2
7 revisi bagian frontend versi 2
```

Hapus semua penanda `<<<<<<<`, `=======`, dan `>>>>>>>`, kemudian simpan
`init.txt`.

## Menyelesaikan Merge

Setelah file disimpan, tandai conflict sebagai selesai dan commit hasil merge:

```powershell
git add init.txt
git status
git commit -m "merge develop dan selesaikan conflict init.txt"
git push origin feat/ESOT-ESS-JF2
```

Sebelum menjalankan `git commit`, pastikan `git status` tidak lagi
menampilkan `both modified` atau `unmerged paths`.

## Membatalkan Merge

Jika hasil penggabungan belum yakin untuk diteruskan dan merge belum
di-commit, batalkan proses merge dengan:

```powershell
git merge --abort
```

Perintah tersebut mengembalikan file ke kondisi sebelum proses merge dimulai.

Kembali ke panduan alur branch:
[Pemisahan Branch Fitur](pemisahan-branch-fitur.md).
