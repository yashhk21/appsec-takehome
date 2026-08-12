#!/usr/bin/env bash
# Ensures a working `bandit` binary is available and prints its path on
# stdout. Resolution order:
#   1. BANDIT_BIN env var, if set and executable.
#   2. `bandit` already on $PATH.
#   3. A pinned version installed into an isolated venv at
#      .tools/bandit-venv/ - cached, so repeat runs are offline, and
#      isolated so this never touches global/system Python packages (and
#      sidesteps PEP 668 "externally managed environment" restrictions on
#      modern Debian/Homebrew Python installs).
set -euo pipefail

BANDIT_VERSION="1.9.4"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.tools/bandit-venv"
BIN_PATH="${VENV_DIR}/bin/bandit"

log() { echo "[install_bandit] $*" >&2; }

# 1. Explicit override.
if [[ -n "${BANDIT_BIN:-}" && -x "${BANDIT_BIN}" ]]; then
    echo "${BANDIT_BIN}"
    exit 0
fi

# 2. Already on PATH.
if command -v bandit >/dev/null 2>&1; then
    log "using bandit already on PATH: $(command -v bandit)"
    command -v bandit
    exit 0
fi

# 3. Cached pinned install.
if [[ -x "${BIN_PATH}" ]]; then
    echo "${BIN_PATH}"
    exit 0
fi

log "bandit not found; installing pinned v${BANDIT_VERSION} into a local venv ..."

if ! command -v python3 >/dev/null 2>&1; then
    log "ERROR: python3 not found. Install Python 3, or install bandit yourself and set BANDIT_BIN."
    exit 2
fi

mkdir -p "${ROOT_DIR}/.tools"
python3 -m venv "${VENV_DIR}"
"${VENV_DIR}/bin/pip" install --quiet --upgrade pip
"${VENV_DIR}/bin/pip" install --quiet "bandit==${BANDIT_VERSION}"

log "installed bandit v${BANDIT_VERSION} -> ${BIN_PATH}"
echo "${BIN_PATH}"
