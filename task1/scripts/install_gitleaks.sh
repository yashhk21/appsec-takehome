#!/usr/bin/env bash
# Ensures a working `gitleaks` binary is available and prints its path on
# stdout. Resolution order:
#   1. GITLEAKS_BIN env var, if set and executable.
#   2. `gitleaks` already on $PATH.
#   3. A pinned release downloaded (with checksum verification) into
#      .tools/gitleaks-<version>/ - cached, so repeat runs are offline.
#
# This keeps the wrapper self-contained (no manual install step required) but
# never silently uses an unverified binary.
set -euo pipefail

GITLEAKS_VERSION="8.30.1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${ROOT_DIR}/.tools"
BIN_DIR="${TOOLS_DIR}/gitleaks-${GITLEAKS_VERSION}"
BIN_PATH="${BIN_DIR}/gitleaks"

log() { echo "[install_gitleaks] $*" >&2; }

# 1. Explicit override.
if [[ -n "${GITLEAKS_BIN:-}" && -x "${GITLEAKS_BIN}" ]]; then
    echo "${GITLEAKS_BIN}"
    exit 0
fi

# 2. Already on PATH.
if command -v gitleaks >/dev/null 2>&1; then
    log "using gitleaks already on PATH: $(command -v gitleaks)"
    command -v gitleaks
    exit 0
fi

# 3. Cached pinned download.
if [[ -x "${BIN_PATH}" ]]; then
    echo "${BIN_PATH}"
    exit 0
fi

log "gitleaks not found; downloading pinned v${GITLEAKS_VERSION} ..."

OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}" in
    Linux)  GOOS="linux" ;;
    Darwin) GOOS="darwin" ;;
    *)      log "ERROR: unsupported OS '${OS}'. Install gitleaks manually and re-run, or set GITLEAKS_BIN."; exit 2 ;;
esac

case "${ARCH}" in
    x86_64|amd64) GOARCH="x64" ;;
    arm64|aarch64) GOARCH="arm64" ;;
    *) log "ERROR: unsupported arch '${ARCH}'. Install gitleaks manually and re-run, or set GITLEAKS_BIN."; exit 2 ;;
esac

ASSET="gitleaks_${GITLEAKS_VERSION}_${GOOS}_${GOARCH}.tar.gz"
BASE_URL="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}"

mkdir -p "${BIN_DIR}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

log "downloading ${ASSET} ..."
if ! curl -sSfL "${BASE_URL}/${ASSET}" -o "${TMP_DIR}/${ASSET}"; then
    log "ERROR: failed to download ${ASSET} from ${BASE_URL} (network issue or asset not found)"
    exit 2
fi
if ! curl -sSfL "${BASE_URL}/gitleaks_${GITLEAKS_VERSION}_checksums.txt" -o "${TMP_DIR}/checksums.txt"; then
    log "ERROR: failed to download checksums file from ${BASE_URL}"
    exit 2
fi

log "verifying checksum ..."
EXPECTED="$(grep " ${ASSET}\$" "${TMP_DIR}/checksums.txt" | awk '{print $1}')"
if [[ -z "${EXPECTED}" ]]; then
    log "ERROR: could not find checksum entry for ${ASSET}"
    exit 2
fi

if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL="$(sha256sum "${TMP_DIR}/${ASSET}" | awk '{print $1}')"
else
    ACTUAL="$(shasum -a 256 "${TMP_DIR}/${ASSET}" | awk '{print $1}')"
fi

if [[ "${EXPECTED}" != "${ACTUAL}" ]]; then
    log "ERROR: checksum mismatch for ${ASSET} (expected ${EXPECTED}, got ${ACTUAL})"
    exit 2
fi

tar -xzf "${TMP_DIR}/${ASSET}" -C "${BIN_DIR}" gitleaks
chmod +x "${BIN_PATH}"

log "installed gitleaks v${GITLEAKS_VERSION} -> ${BIN_PATH}"
echo "${BIN_PATH}"
