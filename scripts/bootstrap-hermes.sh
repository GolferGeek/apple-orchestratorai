#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="${ROOT_DIR}/.runtime"
HERMES_SRC_DIR="${RUNTIME_DIR}/hermes-agent"
HERMES_HOME_DIR="${RUNTIME_DIR}/hermes-home"
HERMES_VENV_DIR="${RUNTIME_DIR}/venvs/hermes-dev"
HERMES_REPO_URL="${HERMES_REPO_URL:-https://github.com/NousResearch/hermes-agent.git}"
HERMES_EXTRAS="${HERMES_EXTRAS:-all}"
API_SERVER_KEY="${API_SERVER_KEY:-apple-orchestratorai-local-dev}"
API_SERVER_HOST="${API_SERVER_HOST:-127.0.0.1}"
API_SERVER_PORT="${API_SERVER_PORT:-8642}"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required but was not found on PATH" >&2
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required but was not found on PATH" >&2
  echo "Install uv from https://docs.astral.sh/uv/ or run: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  exit 1
fi
UV_BIN="$(command -v uv)"

mkdir -p "${RUNTIME_DIR}" "${HERMES_HOME_DIR}" "$(dirname "${HERMES_VENV_DIR}")"

if [[ -d "${HERMES_SRC_DIR}/.git" ]]; then
  echo "Updating Hermes checkout at ${HERMES_SRC_DIR}"
  git -C "${HERMES_SRC_DIR}" fetch --depth 1 origin
  git -C "${HERMES_SRC_DIR}" checkout main
  git -C "${HERMES_SRC_DIR}" pull --ff-only origin main
else
  echo "Cloning Hermes into ${HERMES_SRC_DIR}"
  rm -rf "${HERMES_SRC_DIR}"
  git clone --depth 1 "${HERMES_REPO_URL}" "${HERMES_SRC_DIR}"
fi

echo "Creating/updating Hermes venv at ${HERMES_VENV_DIR}"
"${UV_BIN}" venv "${HERMES_VENV_DIR}" --python 3.11

echo "Installing Hermes editable package with extras: ${HERMES_EXTRAS}"
(
  cd "${HERMES_SRC_DIR}"
  VIRTUAL_ENV="${HERMES_VENV_DIR}" "${UV_BIN}" pip install -e ".[${HERMES_EXTRAS}]"
)

cat > "${HERMES_HOME_DIR}/.env" <<EOF
API_SERVER_ENABLED=true
API_SERVER_HOST=${API_SERVER_HOST}
API_SERVER_PORT=${API_SERVER_PORT}
API_SERVER_KEY=${API_SERVER_KEY}
EOF
chmod 600 "${HERMES_HOME_DIR}/.env"

cat > "${RUNTIME_DIR}/hermes-env.sh" <<EOF
#!/usr/bin/env bash
export HERMES_HOME="${HERMES_HOME_DIR}"
export PATH="${HERMES_VENV_DIR}/bin:\$PATH"
export API_SERVER_ENABLED=true
export API_SERVER_HOST="${API_SERVER_HOST}"
export API_SERVER_PORT="${API_SERVER_PORT}"
export API_SERVER_KEY="${API_SERVER_KEY}"
EOF
chmod 700 "${RUNTIME_DIR}/hermes-env.sh"

echo
echo "Hermes bootstrap complete."
echo "Source env: source ${RUNTIME_DIR}/hermes-env.sh"
echo "Check CLI:  HERMES_HOME=${HERMES_HOME_DIR} ${HERMES_VENV_DIR}/bin/hermes --help"
echo "Start API:  source ${RUNTIME_DIR}/hermes-env.sh && hermes gateway"
echo "Probe API:  scripts/probe-hermes-api.sh"
