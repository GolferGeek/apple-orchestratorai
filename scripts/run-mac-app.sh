#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export APPLE_ORCHESTRATOR_ROOT="$ROOT_DIR"

cd "$ROOT_DIR"
swift run AppleOrchestratorAI
