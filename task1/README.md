# Task 1: secrets scan wrapper (gitleaks)

Wrapper around [gitleaks](https://github.com/gitleaks/gitleaks) with config
tuning, baseline suppression, and CI-friendly exit codes.

## Run it

```bash
chmod +x run.sh scripts/scan_secrets.sh scripts/install_gitleaks.sh
./run.sh
```

The `chmod +x` step is only needed once (e.g. right after cloning/unzipping -
some zip/tar extraction and file-transfer methods drop the executable bit).
If you skip it you'll get `Permission denied`.

First run downloads a pinned, checksum-verified gitleaks binary into
`.tools/` (cached, offline after that). No Docker, no cloud accounts.

## Commands

| Command | What it does |
|---|---|
| `./run.sh` | scan `fixtures/` (bundled demo target) |
| `./run.sh /path/to/repo` | scan a specific directory or git repo |
| `TARGET_DIR=/path/to/repo ./run.sh` | same, via env var |
| `make scan` | same as `./run.sh` |
| `make scan TARGET_DIR=/path/to/repo` | same as `./run.sh /path/to/repo` |
| `make clean` | remove `artifacts/*.json` |

If the target has a `.git` folder, gitleaks scans full commit history;
otherwise it scans the working tree only (`--no-git`, auto-detected).

## Outputs

- `artifacts/secrets.raw.json` - every finding, unfiltered
- `artifacts/secrets.filtered.json` - findings minus `baseline.json` entries (i.e. only "new" ones)

## Expected exit codes

| Code | Meaning |
|---|---|
| `0` | no new (non-baseline) findings |
| `1` | at least one new finding |
| `2` | wrapper failed (missing gitleaks/config, bad target path, etc.) |

```bash
./run.sh; echo $?
```

Note: through `make`, a failed recipe reports `make`'s own exit status
(usually `2`), not the script's exact code - use `./run.sh` directly if you
need to branch on `0`/`1`/`2` precisely.

## Expected result on the bundled `fixtures/` target

```bash
./run.sh
echo $?   # 1
```

- `artifacts/secrets.raw.json` -> 2 findings (AWS key, Slack webhook)
- `artifacts/secrets.filtered.json` -> 1 finding (AWS key - Slack webhook is baselined)
- `fixtures/app/payments.py` has a hardcoded key too, but it's not detected at
  all - the only rule that would catch it (`generic-api-key`) is disabled in
  `config/gitleaks.toml`. See that file for why.

To see the clean (exit `0`) path:

```bash
cp artifacts/secrets.raw.json baseline.json   # accept everything currently found
./run.sh; echo $?                             # 0
git checkout baseline.json                    # restore the real baseline
```

## Baseline mechanism - explicit and inspectable

`baseline.json` is plain, human-readable JSON at the repo root - not hashed,
encoded, or hidden. Open it and you see exactly what's suppressed: rule ID,
file, line/column, and the actual matched secret text (findings are scanned
with `--redact=0` specifically so this stays readable). To accept a new
finding, copy its full object from `secrets.raw.json` into `baseline.json`
verbatim - gitleaks matches on several fields together (rule, file, line
range, the secret text itself), not just an ID, so don't hand-edit
individual fields.

## Requirements

bash, curl, tar, python3, sha256sum/shasum - all standard on Linux/macOS.
Network only needed on first run (to fetch gitleaks); afterwards it's
cached in `.tools/` and fully offline. No network at all? Install gitleaks
yourself and set `GITLEAKS_BIN=/path/to/gitleaks`, or just have it on
`$PATH` - `install_gitleaks.sh` checks both before downloading anything.

## Security notes

- gitleaks binary is downloaded over HTTPS from a pinned release and
  SHA-256-verified against gitleaks' own checksums file before use - no
  `curl | bash`, no unverified execution path.
- `artifacts/*.json` and `baseline.json` can contain real secret text if run
  against a real repo - treat them as sensitive. `artifacts/*.json` is
  gitignored for this reason; `baseline.json` is intentionally tracked since
  it's meant to be reviewed like any other config.
- **`--redact` matters:** gitleaks redacts secret values from its report by
  default - the right default for a real scan, so a findings file isn't
  itself a leak of every secret it found. This demo runs with `--redact=0`
  (off) only so `secrets.raw.json`/`secrets.filtered.json` can be diffed
  byte-for-byte and `baseline.json` stays human-inspectable end to end for
  this walkthrough. Scanning a real repo? Drop `--redact=0` from
  `scripts/scan_secrets.sh` and redact, or make sure the unredacted reports
  never leave the machine/pipeline that generated them.
- All wrapper/gitleaks log output goes to stderr - stdout is reserved for
  nothing but the report files on disk.
- `set -euo pipefail` in every script; the only place errors are allowed to
  pass through is narrowly around the two `gitleaks detect` calls, since
  gitleaks exiting 1 (leaks found) is expected output, not a wrapper failure.

