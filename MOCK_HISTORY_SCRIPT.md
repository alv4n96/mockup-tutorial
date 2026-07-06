# Mock History Script Tutorial

Branch ini berisi contoh script untuk membuat jadwal command `git commit --date=<date> -m <Message>` sebagai materi tutorial.

Script utama:

```text
scripts/generate-mock-history.ps1
```

Default script sekarang membuat/update file `mock-history/*.md`, menulis `mock-history/RUN_LOG.md`, dan mencetak command. Script tetap tidak menjalankan commit kecuali memakai `-Execute`:

```powershell
./scripts/generate-mock-history.ps1
```

Rentang default:
- Mulai: `2026-02-13`
- Selesai: `2026-07-06`
- Skip: Sabtu dan Minggu
- Jumlah command: 3 sampai 6 per hari kerja

Untuk membuat perubahan file nyata tanpa menjalankan commit backdated, gunakan mode berikut:

```powershell
./scripts/generate-mock-history.ps1 -GenerateFiles
```

Mode ini membuat file `mock-history/YYYY-MM-DD.md` berisi aktivitas simulasi per hari kerja.

Contoh custom range:

```powershell
./scripts/generate-mock-history.ps1 -StartDate 2026-03-01 -EndDate 2026-03-31
```

Script juga punya switch `-Execute` untuk menunjukkan bentuk eksekusi dalam tutorial. Gunakan hanya pada repository sandbox/demo karena mode ini membuat file `mock-history/*.md` dan menjalankan `git commit --date=...`.

```powershell
./scripts/generate-mock-history.ps1 -Execute
```

Untuk repository ini, output jadwal command lengkap sudah tersedia di `MOCK_ACTIVITY_LOG.md` pada branch `main`.

## Output Directory

Script selalu menulis ke folder mock-history/ di root repository, meskipun command dijalankan dari folder scripts atau folder lain. Kalau ingin lokasi berbeda, pakai parameter -OutputDirectory.

`powershell
.\scripts\generate-mock-history.ps1 -OutputDirectory .\mock-history
`

