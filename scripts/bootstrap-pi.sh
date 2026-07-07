#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="${ROOT_DIR}/.runtime"
PI_SRC_DIR="${RUNTIME_DIR}/pi"
PI_HOME_DIR="${RUNTIME_DIR}/pi-home"
PI_REPO_URL="${PI_REPO_URL:-https://github.com/earendil-works/pi.git}"
PI_REF="${PI_REF:-main}"
MIN_NODE_VERSION="${MIN_NODE_VERSION:-22.19.0}"

version_ge() {
  python3 - "$1" "$2" <<'PY'
import sys

def parse(value):
    return tuple(int(part) for part in value.lstrip("v").split("."))

sys.exit(0 if parse(sys.argv[1]) >= parse(sys.argv[2]) else 1)
PY
}

if ! command -v git >/dev/null 2>&1; then
  echo "git is required but was not found on PATH" >&2
  exit 1
fi

if [[ -x "/opt/homebrew/bin/node" ]]; then
  NODE_BIN="${NODE_BIN:-/opt/homebrew/bin/node}"
else
  NODE_BIN="${NODE_BIN:-$(command -v node || true)}"
fi

if [[ -x "/opt/homebrew/bin/npm" ]]; then
  NPM_BIN="${NPM_BIN:-/opt/homebrew/bin/npm}"
else
  NPM_BIN="${NPM_BIN:-$(command -v npm || true)}"
fi

if [[ -z "${NODE_BIN}" || ! -x "${NODE_BIN}" ]]; then
  echo "node is required but was not found on PATH" >&2
  exit 1
fi

if [[ -z "${NPM_BIN}" || ! -x "${NPM_BIN}" ]]; then
  echo "npm is required but was not found on PATH" >&2
  exit 1
fi

node_version="$("${NODE_BIN}" --version)"
if ! version_ge "${node_version}" "${MIN_NODE_VERSION}"; then
  echo "Node ${node_version} is below Pi's required baseline ${MIN_NODE_VERSION}." >&2
  echo "Upgrade Node, then rerun scripts/bootstrap-pi.sh." >&2
  exit 1
fi

mkdir -p "${RUNTIME_DIR}" "${PI_HOME_DIR}/agent" "${PI_HOME_DIR}/sessions"

if [[ -d "${PI_SRC_DIR}/.git" ]]; then
  echo "Updating Pi checkout at ${PI_SRC_DIR}"
  git -C "${PI_SRC_DIR}" fetch --depth 1 origin "${PI_REF}"
  git -C "${PI_SRC_DIR}" checkout "${PI_REF}"
  git -C "${PI_SRC_DIR}" pull --ff-only origin "${PI_REF}"
else
  echo "Cloning Pi into ${PI_SRC_DIR}"
  rm -rf "${PI_SRC_DIR}"
  git clone --depth 1 --branch "${PI_REF}" "${PI_REPO_URL}" "${PI_SRC_DIR}"
fi

echo "Installing Pi dependencies"
(
  cd "${PI_SRC_DIR}"
  "${NPM_BIN}" install --ignore-scripts
  "${NPM_BIN}" run build
  git restore .
)

if [[ ! -f "${PI_HOME_DIR}/agent/models.json" ]]; then
  cat > "${PI_HOME_DIR}/agent/models.json" <<'EOF'
{
  "providers": {
    "ollama": {
      "baseUrl": "http://127.0.0.1:11435/v1",
      "api": "openai-completions",
      "apiKey": "ollama",
      "compat": {
        "supportsDeveloperRole": false,
        "supportsReasoningEffort": false
      },
      "models": [
        { "id": "qwen3.6:latest", "name": "Qwen 3.6 Local", "reasoning": true, "input": ["text"] },
        { "id": "qwen3.6:27b-mlx", "name": "Qwen 3.6 27B MLX", "reasoning": true, "input": ["text"] },
        { "id": "qwen3.6:35b-mlx", "name": "Qwen 3.6 35B MLX", "reasoning": true, "input": ["text"] },
        { "id": "gemma4:e2b", "name": "Gemma 4 E2B Local", "reasoning": false, "input": ["text"] },
        { "id": "gemma4:e4b", "name": "Gemma 4 E4B Local", "reasoning": false, "input": ["text"] },
        { "id": "gemma4:e2b-mlx", "name": "Gemma 4 E2B MLX", "reasoning": false, "input": ["text"] },
        { "id": "gemma4:e4b-mlx", "name": "Gemma 4 E4B MLX", "reasoning": false, "input": ["text"] },
        { "id": "gemma4:12b-mlx", "name": "Gemma 4 12B MLX", "reasoning": false, "input": ["text"] },
        { "id": "gemma4:26b-mlx", "name": "Gemma 4 26B MLX", "reasoning": false, "input": ["text"] },
        { "id": "gemma4:31b-mlx", "name": "Gemma 4 31B MLX", "reasoning": false, "input": ["text"] }
      ]
    }
  }
}
EOF
  chmod 600 "${PI_HOME_DIR}/agent/models.json"
fi

cat > "${RUNTIME_DIR}/pi-env.sh" <<EOF
#!/usr/bin/env bash
export PI_HOME="${PI_HOME_DIR}"
export PI_CODING_AGENT_DIR="${PI_HOME_DIR}/agent"
export PI_CODING_AGENT_SESSION_DIR="${PI_HOME_DIR}/sessions"
export PI_SRC_DIR="${PI_SRC_DIR}"
export PI_BIN="${PI_SRC_DIR}/packages/coding-agent/dist/cli.js"
export PI_NODE_BIN="${NODE_BIN}"
export PI_NPM_BIN="${NPM_BIN}"
export PATH="${PI_SRC_DIR}/packages/coding-agent/dist:\$PATH"
export PI_TELEMETRY="\${PI_TELEMETRY:-0}"
EOF
chmod 700 "${RUNTIME_DIR}/pi-env.sh"

echo
echo "Pi bootstrap complete."
echo "Source env: source ${RUNTIME_DIR}/pi-env.sh"
echo "Check CLI:  scripts/probe-pi.sh"
echo "RPC mode:   ${NODE_BIN} ${PI_SRC_DIR}/packages/coding-agent/dist/cli.js --mode rpc --no-session"
