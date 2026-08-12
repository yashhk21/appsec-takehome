#!/usr/bin/env bash
# scan_secrets.sh - secrets scan wrapper around gitleaks with baselining.
#
# Usage:
#   scripts/scan_secrets.sh [TARGET_DIR]
#
#   TARGET_DIR   Path to scan. Defaults to ./fixtures (the bundled demo
#                target). Can also be set via the TARGET_DIR env var.
#                If TARGET_DIR contains a .git directory, gitleaks scans the
#                full commit history (git mode). Otherwise it scans the
#                working tree only (--no-git / directory mode).
#
# Outputs (always both, regardless of findings):
#   artifacts/secrets.raw.json       - every finding gitleaks reports, no
#                                       baseline applied.
#   artifacts/secrets.filtered.json  - findings with baseline.json entries
#                                       subtracted out (i.e. only "new" leaks).
#
# Exit codes:
#   0  - no new (non-baseline) findings
#   1  - at least one new finding
#   2  - the wrapper itself failed (bad config, gitleaks missing, etc.)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_PATH="${ROOT_DIR}/config/gitleaks.toml"
BASELINE_PATH="${ROOT_DIR}/baseline.json"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"
RAW_REPORT="${ARTIFACTS_DIR}/secrets.raw.json"
FILTERED_REPORT="${ARTIFACTS_DIR}/secrets.filtered.json"

TARGET_DIR_INPUT="${1:-${TARGET_DIR:-fixtures}}"

log() { echo "[scan_secrets] $*" >&2; }

# This script depends on python3 from here on (path math below, JSON parsing
# later) - check it explicitly up front rather than letting an unguarded
# `python3 ...` call fail with bash's raw, undocumented "command not found"
# (exit 127) partway through. install_gitleaks.sh has no python3 dependency
# of its own, so this check only needs to live here.
if ! command -v python3 >/dev/null 2>&1; then
    log "ERROR: python3 not found. This wrapper requires python3."
    exit 2
fi

# Resolve to an absolute path first (for existence checks), then re-express
# relative to ROOT_DIR. gitleaks records --source verbatim in each finding's
# "File" field, and baseline matching compares that field exactly - so the
# path we pass MUST be stable across invocation directories, or a valid
# baseline entry will silently stop matching (looks like a "new" finding).
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

# Everything below runs with ROOT_DIR as cwd so --source is always expressed
# the same way, regardless of where scan_secrets.sh was invoked from.
cd "${ROOT_DIR}"

if [[ ! -f "${CONFIG_PATH}" ]]; then
    log "ERROR: config not found at ${CONFIG_PATH}"
    exit 2
fi

mkdir -p "${ARTIFACTS_DIR}"

GITLEAKS_BIN="$("${ROOT_DIR}/scripts/install_gitleaks.sh")"
log "gitleaks binary: ${GITLEAKS_BIN}"
log "gitleaks version: $("${GITLEAKS_BIN}" version)"

# Detect scan mode: full git-history scan if TARGET_DIR is a git repo,
# otherwise a plain working-tree scan.
GIT_MODE_ARGS=()
if [[ -d "${TARGET_DIR}/.git" ]]; then
    log "target '${TARGET_DIR}' is a git repo -> scanning full commit history"
else
    log "target '${TARGET_DIR}' is a plain directory -> scanning working tree only (--no-git)"
    GIT_MODE_ARGS=(--no-git)
fi

# --- Pass 1: raw scan, no baseline, always produces a report ---------------
# gitleaks exits 1 when it finds leaks, which would trip `set -e` here, so we
# capture its exit code explicitly instead of letting the raw pass gate us.
log "running raw scan -> ${RAW_REPORT}"
set +e
"${GITLEAKS_BIN}" detect \
    --source "${TARGET_DIR}" \
    --config "${CONFIG_PATH}" \
    "${GIT_MODE_ARGS[@]}" \
    --report-format json \
    --report-path "${RAW_REPORT}" \
    --exit-code 0 \
    --redact=0
RAW_STATUS=$?
set -e
if [[ ${RAW_STATUS} -ne 0 ]]; then
    log "ERROR: raw gitleaks scan failed unexpectedly (exit ${RAW_STATUS})"
    exit 2
fi
[[ -f "${RAW_REPORT}" ]] || echo "[]" > "${RAW_REPORT}"

RAW_COUNT="$(python3 -c "import json; print(len(json.load(open('${RAW_REPORT}'))))")"
log "raw findings: ${RAW_COUNT}"

# --- Pass 2: baseline-filtered scan, gates our exit code --------------------
if [[ ! -f "${BASELINE_PATH}" ]]; then
    log "WARNING: no baseline.json found at ${BASELINE_PATH}; treating baseline as empty"
    echo "[]" > "${BASELINE_PATH}"
fi

log "running baseline-filtered scan -> ${FILTERED_REPORT}"
set +e
"${GITLEAKS_BIN}" detect \
    --source "${TARGET_DIR}" \
    --config "${CONFIG_PATH}" \
    "${GIT_MODE_ARGS[@]}" \
    --baseline-path "${BASELINE_PATH}" \
    --report-format json \
    --report-path "${FILTERED_REPORT}" \
    --redact=0
FILTERED_STATUS=$?
set -e
[[ -f "${FILTERED_REPORT}" ]] || echo "[]" > "${FILTERED_REPORT}"

FILTERED_COUNT="$(python3 -c "import json; print(len(json.load(open('${FILTERED_REPORT}'))))")"
log "new (non-baseline) findings: ${FILTERED_COUNT}"

if [[ ${FILTERED_STATUS} -eq 0 ]]; then
    log "RESULT: PASS - no new findings"
elif [[ ${FILTERED_STATUS} -eq 1 ]]; then
    log "RESULT: FAIL - ${FILTERED_COUNT} new finding(s), see ${FILTERED_REPORT}"
else
    log "ERROR: baseline-filtered gitleaks scan failed unexpectedly (exit ${FILTERED_STATUS})"
    exit 2
fi

exit "${FILTERED_STATUS}"
