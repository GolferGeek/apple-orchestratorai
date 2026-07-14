#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${APPLE_ORCHESTRATOR_STATE_DIR:-${HOME}/Library/Application Support/Apple Orchestrator AI}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE_DIR="${STATE_DIR}-archive-${STAMP}"

if [[ ! -d "${STATE_DIR}" ]]; then
  mkdir -p "${STATE_DIR}"
else
  mv "${STATE_DIR}" "${ARCHIVE_DIR}"
fi

mkdir -p \
  "${STATE_DIR}/agent-specs" \
  "${STATE_DIR}/artifacts" \
  "${STATE_DIR}/documents" \
  "${STATE_DIR}/display-envelopes" \
  "${STATE_DIR}/events" \
  "${STATE_DIR}/human-reviews" \
  "${STATE_DIR}/raw-pi-events" \
  "${STATE_DIR}/runs" \
  "${STATE_DIR}/stage-results"

echo "state-dir: ${STATE_DIR}"
if [[ -d "${ARCHIVE_DIR}" ]]; then
  echo "archive-dir: ${ARCHIVE_DIR}"
else
  echo "archive-dir: none"
fi
