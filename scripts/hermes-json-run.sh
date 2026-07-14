#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.runtime/hermes-env.sh"
MODEL="${MODEL:-qwen3.6:35b-a3b-nvfp4}"
PROMPT="${HERMES_JSON_PROMPT:?Set HERMES_JSON_PROMPT}"
OUTPUT_FILE="${HERMES_JSON_OUTPUT_FILE:?Set HERMES_JSON_OUTPUT_FILE}"
POLL_COUNT="${HERMES_JSON_POLL_COUNT:-90}"
REQUIRED_KEYS="${HERMES_JSON_REQUIRED_KEYS:-}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Hermes is not bootstrapped yet. Run scripts/bootstrap-hermes.sh first." >&2
  exit 1
fi

"${ROOT_DIR}/scripts/start-shared-ollama.sh"
"${ROOT_DIR}/scripts/configure-hermes-ollama.sh" "${MODEL}"

# shellcheck disable=SC1090
source "${ENV_FILE}"

API_SERVER_HOST="${API_SERVER_HOST:-127.0.0.1}"
API_SERVER_PORT="${API_SERVER_PORT:-8642}"
API_SERVER_KEY="${API_SERVER_KEY:-apple-orchestratorai-local-dev}"
BASE_URL="http://${API_SERVER_HOST}:${API_SERVER_PORT}"
STARTED_HERMES_PID=""

cleanup() {
  if [[ -n "${STARTED_HERMES_PID}" ]] && kill -0 "${STARTED_HERMES_PID}" 2>/dev/null; then
    kill "${STARTED_HERMES_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if ! curl -fsS "${BASE_URL}/health" >/dev/null 2>&1; then
  log_file="${ROOT_DIR}/.runtime/hermes-home/logs/gateway-json-$(date +%Y%m%d-%H%M%S).log"
  mkdir -p "$(dirname "${log_file}")"
  HERMES_YOLO_MODE=1 hermes --yolo gateway >"${log_file}" 2>&1 &
  STARTED_HERMES_PID="$!"

  for _ in {1..60}; do
    if curl -fsS "${BASE_URL}/health" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

payload="$(python3 - "${PROMPT}" "${MODEL}" <<'PY'
import json
import sys

prompt = sys.argv[1]
model = sys.argv[2]
print(json.dumps({
    "input": prompt,
    "instructions": "Return only valid JSON. Do not call external providers.",
    "session_id": "apple-orchestratorai-json",
    "model": model,
}))
PY
)"

run_response="$(curl -fsS \
  -H "Authorization: Bearer ${API_SERVER_KEY}" \
  -H "Content-Type: application/json" \
  -d "${payload}" \
  "${BASE_URL}/v1/runs")"

run_id="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["run_id"])' <<<"${run_response}")"

final_status=""
final_response=""
for ((attempt = 1; attempt <= POLL_COUNT; attempt++)); do
  final_response="$(curl -fsS -H "Authorization: Bearer ${API_SERVER_KEY}" "${BASE_URL}/v1/runs/${run_id}")"
  final_status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status", ""))' <<<"${final_response}")"
  case "${final_status}" in
    completed|failed|cancelled|stopped)
      break
      ;;
  esac
  sleep 2
done

if [[ "${final_status}" != "completed" ]]; then
  echo "Hermes JSON run did not complete successfully: ${final_status}" >&2
  echo "${final_response}" >&2
  exit 1
fi

python3 - "${final_response}" "${OUTPUT_FILE}" "${REQUIRED_KEYS}" "${run_id}" <<'PY'
import json
from pathlib import Path
import sys

response = json.loads(sys.argv[1])
output_file = Path(sys.argv[2])
required = [key for key in sys.argv[3].split(",") if key]
run_id = sys.argv[4]

output = response.get("output", "").strip()
if output.startswith("```"):
    lines = output.splitlines()
    if lines and lines[0].startswith("```"):
        lines = lines[1:]
    if lines and lines[-1].startswith("```"):
        lines = lines[:-1]
    output = "\n".join(lines).strip()

try:
    parsed = json.loads(output)
except json.JSONDecodeError as exc:
    raise SystemExit(f"Hermes output was not JSON: {exc}")

missing = [key for key in required if key not in parsed]
if missing:
    raise SystemExit(f"Hermes JSON output missing keys: {', '.join(missing)}")

parsed["_rawHermesRunId"] = run_id
output_file.parent.mkdir(parents=True, exist_ok=True)
output_file.write_text(json.dumps(parsed, indent=2) + "\n")
print(f"json-ok: {output_file}")
PY
