# deleted-soon

Repository ini digunakan sebagai contoh sederhana untuk mempelajari workflow
Git dan GitHub pada sebuah perubahan fitur. File `init.txt` menjadi contoh
riwayat perubahan bertahap, mulai dari logic backend, logic frontend, assets,
hingga revisi versi berikutnya.

## Fungsi Repository

Repository ini dapat digunakan untuk memahami:

- cara menyimpan versi fitur pada branch terpisah;
- cara mempertahankan branch baseline sambil melanjutkan pengembangan;
- cara menggabungkan kembali branch pengembangan dengan `merge`;
- cara membaca dan menyelesaikan merge conflict secara manual;
- cara bekerja bersama tim melalui branch dan Pull Request di GitHub;
- cara menggunakan GitLab, menangani kasus umum, serta menandai versi rilis.

## File Utama

```text
init.txt = data contoh yang berubah pada setiap tahap pengembangan
```

Contoh isi saat ini:

```text
1 ayam goreng
2 memasukkan logic back end
3 memasukkan logic front end
4 memasukkan assets gambar
5 finishing untuk WCF equipment
6 revisi bagian backend versi 2
7 revisi bagian frontend versi 2
```

## Dokumentasi

- [Pemisahan Branch Fitur](docs/pemisahan-branch-fitur.md) menjelaskan
  pemisahan baseline `feat/ESOT-ESS-JF2` dan pengembangan
  `feat/ESOT-JF2-develop`, termasuk cara menggabungkannya kembali.
- [Penyelesaian Conflict Git](docs/penyelesaian-conflict-git.md) menjelaskan
  cara menangani conflict saat merge menggunakan Notepad dan contoh
  `init.txt`.
- [Kolaborasi Project dengan GitHub](docs/kolaborasi-github.md) menjelaskan
  workflow harian, branch, commit, push, Pull Request, review, dan kebiasaan
  aman ketika bekerja dalam tim.
- [Pengenalan dan Penggunaan GitLab](docs/pengenalan-gitlab.md) menjelaskan
  fungsi GitLab, perbedaannya dengan GitHub, Merge Request, issue, dan CI/CD.
- [Kasus Umum dalam Kolaborasi Git](docs/kasus-umum-git.md) menjelaskan
  masalah yang sering terjadi beserta cara aman menanganinya.
- [Tag dan Versioning di Git](docs/tag-dan-versioning-git.md) menjelaskan
  tag, release, Semantic Versioning, dan contoh membuat versi rilis.

## Branch yang Digunakan

```text
feat/ESOT-ESS-JF2     = baseline fitur
feat/ESOT-JF2-develop = pengembangan lanjutan
```

Repository ini bersifat contoh workflow pada level fitur. Branch tersebut
tidak otomatis mewakili environment `staging` atau `production` sebuah
aplikasi.
