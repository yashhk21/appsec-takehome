# appsec-takehome - SAST scan wrapper (bandit)

Wrapper around [bandit](https://github.com/PyCQA/bandit) with a bounded rule
set, an explicit noise-reduction mechanism, and a configurable severity
threshold.

## Run it

```bash
chmod +x run.sh scripts/scan_sast.sh scripts/install_bandit.sh
./run.sh
```

First run installs a pinned bandit into an isolated venv at
`.tools/bandit-venv/` (cached, offline after that). No Docker, no cloud
accounts.

bandit has no built-in banner (unlike gitleaks), so the wrapper prints its
own small ASCII banner at the start of each run - purely cosmetic, doesn't
affect `artifacts/*.json` or the exit code.

## Commands

| Command | What it does |
|---|---|
| `./run.sh` | scan `sast_target/` (bundled demo target) at the default threshold |
| `./run.sh /path/to/repo` | scan a specific directory |
| `TARGET_DIR=/path/to/repo ./run.sh` | same, via env var |
| `MIN_SEVERITY=HIGH ./run.sh` | override the severity threshold (default `MEDIUM`) |
| `make scan` | same as `./run.sh` |
| `make scan TARGET_DIR=path MIN_SEVERITY=HIGH` | same, with overrides |
| `make clean` | remove generated `artifacts/*.json` |

`MIN_SEVERITY` accepts `INFO`, `LOW`, `MEDIUM`, or `HIGH` (case-insensitive).

## Outputs

- `artifacts/sast.raw.json` - every finding from the bounded rule set, after
  noise reduction, at **any** severity
- `artifacts/sast.json` - the same scan, additionally filtered to
  `MIN_SEVERITY` and above - this is what the exit code is based on

## Expected exit codes

| Code | Meaning |
|---|---|
| `0` | no findings at/above `MIN_SEVERITY` |
| `1` | at least one finding at/above `MIN_SEVERITY` |
| `2` | wrapper failed (missing bandit/config, bad target path, bandit itself errored) |

```bash
./run.sh; echo $?
```

Note: `make` reports a failed recipe with its own generic non-zero exit
status (usually `2`), not the script's exact code - use `./run.sh` directly
if you need to branch on `0`/`1`/`2` precisely.

## Expected result on the bundled `sast_target/` target

```bash
./run.sh
echo $?   # 1
```

`artifacts/sast.raw.json` -> 5 findings, all severities:

| Rule | File | Severity |
|---|---|---|
| B307 (`eval` used) | `app/exec_utils.py` | MEDIUM |
| B602 (`shell=True`, attacker-controlled) | `app/exec_utils.py` | HIGH |
| B602 (`shell=True`, hardcoded literal) | `app/exec_utils.py` | LOW |
| B608 (SQL built via string formatting) | `app/db.py` | MEDIUM |
| B324 (insecure hash - md5) | `app/crypto_utils.py` | HIGH |

Documented severity-threshold examples on this exact target:

```bash
MIN_SEVERITY=INFO   ./run.sh; echo $?   # 5 findings, exit 1
MIN_SEVERITY=LOW    ./run.sh; echo $?   # 5 findings, exit 1
MIN_SEVERITY=MEDIUM ./run.sh; echo $?   # 4 findings, exit 1  (default)
MIN_SEVERITY=HIGH   ./run.sh; echo $?   # 2 findings, exit 1
```

`INFO` is more sensitive than `HIGH` (5 findings vs. 2) - bandit has no
severity below `LOW`, so `INFO` and `LOW` are equivalent here; that's
expected, not a bug (see `scripts/scan_sast.sh` header comment for the
mapping).

Two more things visible in the fixtures themselves:
- `sast_target/legacy/old_report.py` has the exact same SQL-injection
  pattern as `app/db.py`, but produces **zero** findings - excluded by the
  `exclude_dirs` path exclude in `config/bandit.yaml`.
- `app/exec_utils.py` calls `eval()` twice; only one shows up as a finding -
  the other is suppressed inline with `# nosec B307` (see that file).

To see the clean (exit `0`) path, point it at any file with none of the 4
selected rule patterns, e.g.:

```bash
echo "print('hello')" > /tmp/clean.py
./run.sh /tmp
echo $?   # 0
```

## Scope control

Two layered mechanisms decide what actually gets analyzed:

**`TARGET_DIR`** (positional arg / env var, `scripts/scan_sast.sh`) - the
coarse control. Whatever directory you point it at is the entire universe
bandit looks at; nothing outside it is ever read. Verified directly:
pointing at an unrelated directory with no matching patterns returns 0
findings, and narrowing from `sast_target` down to `sast_target/app`
produces identical results (since `legacy/` is excluded either way - see
below).

**`exclude_dirs` in `config/bandit.yaml`** - the fine control. Carves a
specific subtree back out of whatever `TARGET_DIR` defined. In this repo
that's `sast_target/legacy/`, which doubles as our noise-reduction example
below - the same mechanism serves both purposes here (a narrower analyzed
surface *is* how you reduce noise from code you don't want findings on),
but conceptually they answer different questions: "what code exists to
analyze" (scope) vs. "which real findings within that code are worth
surfacing" (noise reduction, rule selection, severity).

## Config choices

(Also explained inline in `config/bandit.yaml`.)

**Bounded rule set** - `tests: [B307, B602, B608, B324]`, 4 of bandit's ~70+
built-in checks: `eval()` usage, shell-injection-prone `subprocess` calls,
string-built SQL, and insecure hashing. A cohesive "dangerous
function/injection/weak crypto" group, not the full default set.

**Noise-reduction mechanism (path exclude)** - `exclude_dirs:
['sast_target/legacy']`. That directory holds frozen, unmaintained code with
the same SQLi pattern as `app/db.py` - excluding the path keeps the report
focused on code that's actually still being touched. (A second, code-level
mechanism - inline `# nosec` suppression - is also demonstrated in
`app/exec_utils.py`, though the deliverable's required mechanism is the
config-level path exclude above.)

## Determinism note

Given the same target and config, the **findings** (`results` array) are
byte-identical run to run - verified directly. bandit's JSON report does
embed its own `generated_at` scan timestamp in the report metadata, which
necessarily differs between runs; that's bandit's own output, not something
the wrapper adds, and it doesn't affect which findings are reported.

## Requirements

bash, python3 (used both by the wrapper for JSON/path handling, and to run
bandit itself, which is a Python tool). Network only needed on first run (to
`pip install` the pinned bandit version into `.tools/bandit-venv/`);
afterwards fully offline. No network at all? Install bandit yourself and set
`BANDIT_BIN=/path/to/bandit`, or just have `bandit` on `$PATH` -
`install_bandit.sh` checks both before installing anything.

## Security notes

- bandit is installed into an isolated venv (`.tools/bandit-venv/`), not the
  system/global Python environment - no risk of clobbering unrelated
  packages, and sidesteps PEP 668 "externally managed environment"
  restrictions on modern Debian/Homebrew Python.
- `artifacts/sast*.json` can contain source snippets and file paths from
  whatever repo you scan - gitignored for this reason. Treat them as
  sensitive if run against a real, non-demo codebase.
- All wrapper/bandit log output goes to stderr - stdout is reserved for
  nothing but the report files on disk.
- `set -euo pipefail` in every script; the only place errors are allowed to
  pass through is narrowly around the two `bandit` calls, since bandit
  exiting 1 (findings present) is expected output, not a wrapper failure.
  Anything other than 0/1 from bandit is treated as a real error (exit `2`).
