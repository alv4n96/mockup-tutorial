# Mock History Script Tutorial

Branch ini berisi script untuk membuat file aktivitas simulasi dari jadwal command `git commit --date=<date> -m <Message>`.

Script utama:

```text
scripts/generate-mock-history.ps1
```

## Cara Pakai Default

Jalankan dari root repo:

```powershell
.\scripts\generate-mock-history.ps1
```

Default script akan:
- Membuat atau memperbarui file `mock-history/YYYY-MM-DD.md`.
- Menulis log ke `mock-history/RUN_LOG.md`.
- Mencetak command `git commit --date=...`.
- Menjalankan `git add` untuk folder `mock-history/`.

Setelah itu cek:

```powershell
git status
```

File sudah staged. Agar muncul di GitHub, lanjutkan:

```powershell
git commit -m "docs: update generated mock history"
git push origin HEAD
```

## Commit dan Push dari Script

Kalau ingin script juga membuat commit normal dan push branch aktif:

```powershell
.\scripts\generate-mock-history.ps1 -CommitGenerated -Push
```

Mode ini tidak membuat commit backdated. Commit yang dibuat adalah commit normal dengan tanggal saat command dijalankan.

## Custom Range

```powershell
.\scripts\generate-mock-history.ps1 -StartDate 2026-03-01 -EndDate 2026-03-31
```

## Output Directory

Script selalu menulis ke folder `mock-history/` di root repository secara default, meskipun command dijalankan dari folder `scripts` atau folder lain. Kalau ingin lokasi berbeda, pakai parameter `-OutputDirectory`.

```powershell
.\scripts\generate-mock-history.ps1 -OutputDirectory .\mock-history
```

## Rentang Default

- Mulai: `2026-02-13`
- Selesai: `2026-07-06`
- Skip: Sabtu dan Minggu
- Jumlah command: 3 sampai 6 per hari kerja

Untuk repository ini, output jadwal command lengkap juga tersedia di `MOCK_ACTIVITY_LOG.md` pada branch `main`.
