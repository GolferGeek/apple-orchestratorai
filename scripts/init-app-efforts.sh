#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: scripts/init-app-efforts.sh <app-id> [repo-root]" >&2
  exit 2
fi

app_id="$1"
repo_root="${2:-.}"
efforts_root="${repo_root%/}/apps/${app_id}/efforts"

mkdir -p \
  "$efforts_root/inbox" \
  "$efforts_root/current" \
  "$efforts_root/future" \
  "$efforts_root/archive"

touch \
  "$efforts_root/inbox/.gitkeep" \
  "$efforts_root/current/.gitkeep" \
  "$efforts_root/future/.gitkeep" \
  "$efforts_root/archive/.gitkeep"

echo "initialized $efforts_root"
