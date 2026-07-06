#!/usr/bin/env bash
set -euo pipefail

START_DATE="${START_DATE:-2026-02-13}"
END_DATE="${END_DATE:-2026-07-06}"
OUTPUT_DIR="${OUTPUT_DIR:-mock-history-sh}"
PLAN_FILE="${PLAN_FILE:-BACKDATE_COMMANDS.sh}"
TZ_OFFSET="${TZ_OFFSET:-+0700}"

messages=(
  "docs: prepare tutorial outline"
  "docs: add backend module notes"
  "docs: add database design notes"
  "docs: add frontend setup notes"
  "docs: add ui component notes"
  "docs: add testing checklist"
  "docs: refine production checklist"
  "docs: add troubleshooting notes"
)

mkdir -p "$OUTPUT_DIR"

cat > "$PLAN_FILE" <<'PLAN_HEADER'
#!/usr/bin/env bash
set -euo pipefail

# Generated command plan for tutorial use.
# Review every command before running.

PLAN_HEADER

current="$START_DATE"
index=0

while [[ "$current" < "$END_DATE" || "$current" == "$END_DATE" ]]; do
  day_name=$(date -d "$current" +%A)

  if [[ "$day_name" != "Saturday" && "$day_name" != "Sunday" ]]; then
    day_of_year=$(date -d "$current" +%j)
    month=$(date -d "$current" +%-m)
    count=$((3 + (10#$day_of_year + month) % 4))

    for ((n=0; n<count; n++)); do
      hour=$((9 + (n * 2 + $(date -d "$current" +%-d)) % 8))
      minute=$(((10#$day_of_year + n * 11) % 60))
      message="${messages[$(((10#$day_of_year + n) % ${#messages[@]}))]}"
      timestamp=$(printf "%sT%02d:%02d:00%s" "$current" "$hour" "$minute" "$TZ_OFFSET")
      file=$(printf "%s/%s-%03d.md" "$OUTPUT_DIR" "$current" "$n")

      cat > "$file" <<ENTRY
# $message

Generated file: $file
Mock timestamp: $timestamp
ENTRY

      printf 'git add -- %q\n' "$file" >> "$PLAN_FILE"
      printf 'git commit --date=%q -m %q\n\n' "$timestamp" "$message" >> "$PLAN_FILE"
    done
  fi

  current=$(date -I -d "$current + 1 day")
  index=$((index + 1))
done

cat >> "$PLAN_FILE" <<'PLAN_FOOTER'
git push origin HEAD
PLAN_FOOTER

chmod +x "$PLAN_FILE"

printf 'Generated files in: %s\n' "$OUTPUT_DIR"
printf 'Generated command plan: %s\n' "$PLAN_FILE"
printf 'Review the plan, then run it manually only in a demo repository.\n'
