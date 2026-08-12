#!/usr/bin/env bash
# Single entrypoint: runs the secrets scan end-to-end and surfaces gitleaks'
# own exit code (0 = clean, 1 = new findings).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${ROOT_DIR}/scripts/scan_secrets.sh" "$@"
