#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.runtime/hermes-env.sh"
MODEL="${1:-qwen3.6:35b-a3b-nvfp4}"
PROMPT="${SMOKE_PROMPT:-Reply with exactly: OK}"
EXPECT_JSON="${SMOKE_EXPECT_JSON:-0}"
POLL_COUNT="${SMOKE_POLL_COUNT:-90}"

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
  log_file="${ROOT_DIR}/.runtime/hermes-home/logs/gateway-smoke-$(date +%Y%m%d-%H%M%S).log"
  mkdir -p "$(dirname "${log_file}")"
  echo "Starting Hermes gateway at ${BASE_URL}"
  HERMES_YOLO_MODE=1 hermes --yolo gateway >"${log_file}" 2>&1 &
  STARTED_HERMES_PID="$!"

  for _ in {1..60}; do
    if curl -fsS "${BASE_URL}/health" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

echo "Hermes health:"
curl -fsS "${BASE_URL}/health"
echo

echo "Hermes models:"
curl -fsS -H "Authorization: Bearer ${API_SERVER_KEY}" "${BASE_URL}/v1/models"
echo

payload="$(python3 - "${PROMPT}" "${MODEL}" <<'PY'
import json
import sys

prompt = sys.argv[1]
model = sys.argv[2]
print(json.dumps({
    "input": prompt,
    "instructions": "This is a local runtime smoke test. Do not call external providers. Return the requested token only.",
    "session_id": "apple-orchestratorai-smoke",
    "model": model,
}))
PY
)"

run_response="$(curl -fsS \
  -H "Authorization: Bearer ${API_SERVER_KEY}" \
  -H "Content-Type: application/json" \
  -d "${payload}" \
  "${BASE_URL}/v1/runs")"
echo "Run response:"
echo "${run_response}"

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

echo "Final run status:"
echo "${final_response}"

if [[ "${final_status}" != "completed" ]]; then
  echo "Smoke run did not complete successfully: ${final_status}" >&2
  exit 1
fi

if [[ "${EXPECT_JSON}" == "1" ]]; then
  python3 - "${final_response}" <<'PY'
import json
import sys

response = json.loads(sys.argv[1])
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
    raise SystemExit(f"Smoke run output was not JSON: {exc}")

required = {
    "status",
    "workflowId",
    "client",
    "matter",
    "stages",
    "humanReviewRequired",
    "markdownSummary",
    "outputs",
}
missing = sorted(required - set(parsed))
if missing:
    raise SystemExit(f"Smoke run JSON output missing keys: {', '.join(missing)}")

outputs = parsed.get("outputs")
if not isinstance(outputs, list):
    raise SystemExit("Smoke run JSON output field 'outputs' must be a list")
for index, item in enumerate(outputs):
    if not isinstance(item, dict):
        raise SystemExit(f"Smoke run output item {index} must be an object")
    if not isinstance(item.get("content"), str):
        raise SystemExit(f"Smoke run output item {index} content must be a string")

print("json-ok: smoke output matched the workflow display envelope")
PY
fi

echo "smoke-ok: Hermes + shared Ollama completed a local run with ${MODEL}"
