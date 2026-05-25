# Tag dan Versioning di Git

Tag digunakan untuk memberi nama tetap pada suatu titik dalam riwayat Git.
Tag paling sering dipakai untuk menandai versi aplikasi yang dirilis, misalnya
`v1.0.0` atau `v2.1.3`.

## Branch dan Tag

Branch bergerak ketika commit baru ditambahkan:

```text
main:  A -- B -- C -- D
                    ^
                    main terus bergerak
```

Tag tetap menunjuk pada commit yang ditandai:

```text
main:  A -- B -- C -- D
               ^
               v1.0.0 tetap menunjuk ke C
```

Karena sifatnya tetap, tag cocok untuk menjawab pertanyaan:

```text
commit mana yang menjadi versi 1.0.0?
kode yang dirilis bulan lalu berada pada kondisi apa?
```

## Jenis Tag

Git menyediakan dua jenis tag utama:

```text
lightweight tag = penunjuk sederhana ke sebuah commit
annotated tag   = tag dengan informasi pembuat, tanggal, pesan, dan opsi signature
```

Untuk rilis project, gunakan **annotated tag** karena menyimpan informasi
lebih lengkap mengenai versi tersebut.

## Semantic Versioning

Pola versi yang umum digunakan adalah:

```text
MAJOR.MINOR.PATCH
```

Contoh:

```text
v1.0.0
```

Maknanya secara umum:

```text
MAJOR = perubahan besar yang tidak kompatibel dengan penggunaan sebelumnya
MINOR = fitur baru yang tetap kompatibel
PATCH = perbaikan bug yang tetap kompatibel
```

Contoh perubahan versi:

```text
v1.0.0 -> v1.0.1 = memperbaiki bug tanpa fitur baru
v1.0.1 -> v1.1.0 = menambahkan fitur baru yang kompatibel
v1.1.0 -> v2.0.0 = perubahan besar yang dapat memerlukan penyesuaian pengguna
```

Versi pengembangan atau kandidat rilis dapat menggunakan label tambahan:

```text
v2.0.0-alpha.1
v2.0.0-beta.1
v2.0.0-rc.1
```

## Kapan Membuat Tag

Tag biasanya dibuat ketika:

- fitur yang direncanakan untuk sebuah versi sudah selesai;
- test dan review telah lulus;
- commit yang akan dirilis sudah berada pada branch rilis atau `main`;
- tim sudah sepakat bahwa commit tersebut adalah versi tertentu.

Jangan membuat tag rilis pada commit yang masih berubah-ubah hanya karena
branch pekerjaan sudah di-push.

## Membuat Annotated Tag

Pastikan Anda berada pada branch dan commit yang akan ditandai:

```powershell
git switch main
git pull origin main
git log --oneline --decorate -5
```

Buat tag:

```powershell
git tag -a v1.0.0 -m "rilis versi 1.0.0"
```

Periksa tag:

```powershell
git tag
git show v1.0.0
```

Tag yang dibuat secara lokal belum otomatis tersedia di GitHub atau GitLab.
Kirim tag ke remote:

```powershell
git push origin v1.0.0
```

## Menandai Commit Tertentu

Jika tag harus menunjuk commit tertentu, bukan `HEAD` saat ini:

```powershell
git tag -a v1.0.0 db546552ca81ad87d2fffea6e0a899c2c37c3da7 -m "rilis baseline equipment"
git show v1.0.0
git push origin v1.0.0
```

Pada repository contoh ini, perintah tersebut akan menandai commit
`memasukkan wcf untuk equipment`. Jalankan hanya jika Anda memang menetapkan
commit itu sebagai rilis.

## Melihat atau Menggunakan Versi Bertag

Menampilkan daftar tag:

```powershell
git tag --list
```

Melihat rincian versi:

```powershell
git show v1.0.0
```

Membuka kode pada versi tersebut untuk pemeriksaan:

```powershell
git switch --detach v1.0.0
```

Mode `detached HEAD` cocok untuk melihat kode lama, bukan untuk langsung
mengembangkan fitur. Jika perlu membuat perbaikan dari versi tersebut, buat
branch baru:

```powershell
git switch -c fix/v1.0.0-hotfix v1.0.0
```

## Memperbaiki Kesalahan Tag

Tag rilis sebaiknya dianggap tetap. Jika sebuah versi sudah digunakan tim atau
pengguna, lebih jelas membuat versi baru, misalnya `v1.0.1`, daripada
memindahkan `v1.0.0`.

Jika tag baru saja dibuat secara salah dan belum dipakai siapa pun, hapus tag
lokal:

```powershell
git tag -d v1.0.0
```

Jika sudah ter-push dan tim menyepakati penghapusannya:

```powershell
git push origin --delete v1.0.0
```

Setelah itu Anda dapat membuat tag yang benar dan mendorongnya kembali. Selalu
komunikasikan perubahan tag yang sudah dibagikan.

## Tag dan Release di GitHub atau GitLab

Tag adalah referensi Git terhadap commit. Release adalah halaman publikasi di
platform hosting yang biasanya menggunakan sebuah tag dan dapat berisi:

```text
judul versi
release notes
daftar perubahan
file build atau artefak unduhan
```

Alur rilis yang sederhana:

```powershell
git switch main
git pull origin main
git tag -a v1.0.0 -m "rilis versi 1.0.0"
git push origin v1.0.0
```

Kemudian buat Release pada GitHub atau GitLab berdasarkan tag `v1.0.0`, dan
tuliskan perubahan penting untuk pengguna.

## Contoh Release Notes

```markdown
# v1.0.0

## Fitur

- Menambahkan form equipment.
- Menambahkan validasi serial number.

## Perbaikan

- Memperbaiki tampilan daftar equipment.
```

## Kebiasaan Baik

- Pakai pola nama versi yang konsisten, misalnya `v1.0.0`.
- Gunakan annotated tag untuk rilis resmi.
- Buat tag dari commit yang sudah direview dan diuji.
- Push tag agar tersedia untuk tim dan server deployment.
- Hindari memindahkan tag versi yang sudah diumumkan.
- Sertakan release notes agar perubahan versi dapat dipahami.

## Referensi Resmi

- [Git: Tagging](https://git-scm.com/book/en/v2/Git-Basics-Tagging.html)
- [Git: git-tag Documentation](https://git-scm.com/docs/git-tag.html)
- [Semantic Versioning 2.0.0](https://semver.org/)
