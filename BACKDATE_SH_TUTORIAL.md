# Backdate Command Plan Script

Script shell ini membuat file mock dan menghasilkan file command plan berisi urutan:

```bash
git add -- <file>
git commit --date=<date> -m <message>
```

Script utama:

```bash
scripts/generate-backdate-command-plan.sh
```

Jalankan di Git Bash, WSL, Linux, atau macOS:

```bash
bash scripts/generate-backdate-command-plan.sh
```

Output:
- `mock-history-sh/`: file mock per tanggal kerja.
- `BACKDATE_COMMANDS.sh`: command plan yang berisi `git add`, `git commit --date`, dan `git push origin HEAD`.

Custom range:

```bash
START_DATE=2026-02-13 END_DATE=2026-07-06 bash scripts/generate-backdate-command-plan.sh
```

Catatan: review isi `BACKDATE_COMMANDS.sh` sebelum menjalankan command apa pun.
