#!/usr/bin/env bash
# Single entrypoint: runs the SAST scan end-to-end and surfaces bandit's own
# exit code (0 = clean, 1 = findings at/above MIN_SEVERITY).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${ROOT_DIR}/scripts/scan_sast.sh" "$@"
