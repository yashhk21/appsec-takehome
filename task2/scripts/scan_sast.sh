#!/usr/bin/env bash
# scan_sast.sh - SAST scan wrapper around bandit with scope control,
# severity threshold, and noise reduction.
#
# Usage:
#   scripts/scan_sast.sh [TARGET_DIR]
#
#   TARGET_DIR    Path to scan. Defaults to ./sast_target (the bundled demo
#                 target). Can also be set via the TARGET_DIR env var.
#
#   MIN_SEVERITY  Severity threshold. One of INFO, LOW, MEDIUM, HIGH
#                 (case-insensitive). Defaults to MEDIUM. Maps onto
#                 bandit's own --severity-level flag:
#                   INFO   -> --severity-level all     (most sensitive -
#                             bandit has no level below LOW, so INFO simply
#                             means "don't filter anything out")
#                   LOW    -> --severity-level low
#                   MEDIUM -> --severity-level medium
#                   HIGH   -> --severity-level high     (least sensitive)
#
# Outputs (always both, regardless of findings):
#   artifacts/sast.raw.json   - every finding within the bounded rule set
#                                and after path excludes, at ANY severity
#                                (i.e. noise reduction applied, severity
#                                threshold NOT applied).
#   artifacts/sast.json       - the same scan additionally filtered to
#                                MIN_SEVERITY and above. This is the file
#                                the exit code is based on.
#
# Exit codes:
#   0  - no findings at/above MIN_SEVERITY after noise reduction
#   1  - at least one finding at/above MIN_SEVERITY
#   2  - the wrapper itself failed (bad config, bandit missing, bad target
#        path, bandit itself errored, etc.)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_PATH="${ROOT_DIR}/config/bandit.yaml"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"
RAW_REPORT="${ARTIFACTS_DIR}/sast.raw.json"
FINAL_REPORT="${ARTIFACTS_DIR}/sast.json"

log() { echo "[scan_sast] $*" >&2; }

# This script depends on python3 from here on (path math below, JSON parsing
# later) - check it explicitly up front rather than letting an unguarded
# `python3 ...` call fail with bash's raw, undocumented "command not found"
# (exit 127) partway through. install_bandit.sh has its own copy of this
# same check, but that only guards bandit's own dependency on python3, not
# this script's - each script's python3 usage needs its own guard.
if ! command -v python3 >/dev/null 2>&1; then
    log "ERROR: python3 not found. This wrapper requires python3."
    exit 2
fi

# --- Resolve target dir, same relative-to-root normalization as Task 1 -----
TARGET_DIR_INPUT="${1:-${TARGET_DIR:-sast_target}}"
case "${TARGET_DIR_INPUT}" in
    /*) TARGET_DIR_ABS="${TARGET_DIR_INPUT}" ;;
    *)  TARGET_DIR_ABS="$(pwd)/${TARGET_DIR_INPUT}" ;;
esac
if [[ ! -d "${TARGET_DIR_ABS}" ]]; then
    log "ERROR: target directory '${TARGET_DIR_INPUT}' does not exist."
    exit 2
fi
TARGET_DIR_ABS="$(cd "${TARGET_DIR_ABS}" && pwd)"
TARGET_DIR="$(python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "${TARGET_DIR_ABS}" "${ROOT_DIR}")"
log "target (relative to repo root): ${TARGET_DIR}"

cd "${ROOT_DIR}"

if [[ ! -f "${CONFIG_PATH}" ]]; then
    log "ERROR: config not found at ${CONFIG_PATH}"
    exit 2
fi
mkdir -p "${ARTIFACTS_DIR}"

# --- Resolve MIN_SEVERITY -> bandit's --severity-level -----------------
MIN_SEVERITY="$(echo "${MIN_SEVERITY:-MEDIUM}" | tr '[:lower:]' '[:upper:]')"
case "${MIN_SEVERITY}" in
    INFO)   BANDIT_LEVEL="all" ;;
    LOW)    BANDIT_LEVEL="low" ;;
    MEDIUM) BANDIT_LEVEL="medium" ;;
    HIGH)   BANDIT_LEVEL="high" ;;
    *)
        log "ERROR: invalid MIN_SEVERITY '${MIN_SEVERITY}' (expected INFO, LOW, MEDIUM, or HIGH)"
        exit 2
        ;;
esac
log "MIN_SEVERITY=${MIN_SEVERITY} -> bandit --severity-level ${BANDIT_LEVEL}"

BANDIT_BIN="$("${ROOT_DIR}/scripts/install_bandit.sh")"
log "bandit binary: ${BANDIT_BIN}"
log "bandit version: $("${BANDIT_BIN}" --version 2>&1 | head -1)"

# bandit has no built-in ASCII-art banner (unlike gitleaks) - print our own,
# to stderr like everything else, purely for a consistent "scan is running"
# visual signal.
print_banner() {
    cat >&2 <<'EOF'

   _                    _ _ _
  | |__   __ _ _ __   __| (_) |_
  | '_ \ / _` | '_ \ / _` | | __|
  | |_) | (_| | | | | (_| | | |_
  |_.__/ \__,_|_| |_|\__,_|_|\__|   SAST scan

EOF
}
print_banner

# --- Pass 1: raw scan - bounded ruleset + noise reduction, no severity -----
# filter. bandit exits 1 whenever it finds ANYTHING, which is expected here,
# not an error - capture the code explicitly instead of letting it trip
# `set -e`.
log "running raw scan (bounded rule set + noise reduction, all severities) -> ${RAW_REPORT}"
set +e
"${BANDIT_BIN}" -r "${TARGET_DIR}" \
    -c "${CONFIG_PATH}" \
    --severity-level all \
    -f json \
    -o "${RAW_REPORT}"
RAW_STATUS=$?
set -e
if [[ ${RAW_STATUS} -ne 0 && ${RAW_STATUS} -ne 1 ]]; then
    log "ERROR: raw bandit scan failed unexpectedly (exit ${RAW_STATUS})"
    exit 2
fi
RAW_COUNT="$(python3 -c "import json; print(len(json.load(open('${RAW_REPORT}'))['results']))")"
log "raw findings (bounded ruleset, noise reduction applied, any severity): ${RAW_COUNT}"

# --- Pass 2: severity-filtered scan - gates our exit code ------------------
log "running severity-filtered scan (MIN_SEVERITY=${MIN_SEVERITY}) -> ${FINAL_REPORT}"
set +e
"${BANDIT_BIN}" -r "${TARGET_DIR}" \
    -c "${CONFIG_PATH}" \
    --severity-level "${BANDIT_LEVEL}" \
    -f json \
    -o "${FINAL_REPORT}"
FINAL_STATUS=$?
set -e

if [[ ${FINAL_STATUS} -ne 0 && ${FINAL_STATUS} -ne 1 ]]; then
    log "ERROR: severity-filtered bandit scan failed unexpectedly (exit ${FINAL_STATUS})"
    exit 2
fi

FINAL_COUNT="$(python3 -c "import json; print(len(json.load(open('${FINAL_REPORT}'))['results']))")"
log "findings at/above ${MIN_SEVERITY}: ${FINAL_COUNT}"

if [[ ${FINAL_STATUS} -eq 0 ]]; then
    log "RESULT: PASS - no findings at/above ${MIN_SEVERITY}"
else
    log "RESULT: FAIL - ${FINAL_COUNT} finding(s) at/above ${MIN_SEVERITY}, see ${FINAL_REPORT}"
fi

exit "${FINAL_STATUS}"
