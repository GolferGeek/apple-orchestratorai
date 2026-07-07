#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

python3 -m json.tool config/apps.json >/dev/null
python3 -m json.tool templates/effort/effort.json >/dev/null
python3 -m json.tool templates/effort/questions.json >/dev/null

required_dirs=(inbox current future archive)
required_files=(
  effort.json
  intention.md
  plan.md
  shared-notes.md
  next-actions.md
  later.md
  questions.json
  run-log.jsonl
  result.md
  artifacts
)

app_roots=$(python3 - <<'PY'
import json
with open("config/apps.json", "r", encoding="utf-8") as f:
    data = json.load(f)
for app in data.get("apps", []):
    print(f'{app["id"]}\t{app["effortsRoot"]}')
PY
)

while IFS=$'\t' read -r app_id root; do
  [[ -n "$app_id" ]] || continue
  if [[ ! -d "$root" ]]; then
    echo "missing efforts root: $root" >&2
    exit 1
  fi

  for dir_name in "${required_dirs[@]}"; do
    if [[ ! -d "$root/$dir_name" ]]; then
      echo "missing efforts directory: $root/$dir_name" >&2
      exit 1
    fi
  done

  for state in current future archive; do
    while IFS= read -r -d '' effort_dir; do
      for file_name in "${required_files[@]}"; do
        if [[ ! -e "$effort_dir/$file_name" ]]; then
          echo "missing $file_name in $effort_dir" >&2
          exit 1
        fi
      done
      python3 -m json.tool "$effort_dir/effort.json" >/dev/null
      python3 -m json.tool "$effort_dir/questions.json" >/dev/null
    done < <(find "$root/$state" -mindepth 1 -maxdepth 1 -type d -print0)
  done
done <<< "$app_roots"

echo "effort structure ok"
