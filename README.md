# appsec-takehome

Two independent, self-contained deliverables. Each folder has its own
`run.sh`, `Makefile`, config, fixtures, and README - `cd` into either one
and follow its own instructions.

| Folder | What it is | Docs |
|---|---|---|
| [`task1/`](task1/) | Secrets scan wrapper around [gitleaks](https://github.com/gitleaks/gitleaks) - config tuning, baseline suppression, CI-friendly exit codes | [task1/README.md](task1/README.md) |
| [`task2/`](task2/) | SAST scan wrapper around [bandit](https://github.com/PyCQA/bandit) - scope control, bounded rule set, noise reduction, severity threshold | [task2/README.md](task2/README.md) |

## Quick start

```bash
cd task1 && chmod +x run.sh scripts/*.sh && ./run.sh
cd ../task2 && chmod +x run.sh scripts/*.sh && ./run.sh
```

Each task installs its own scanner on first run (gitleaks binary for task1,
bandit into an isolated venv for task2), cached locally afterward. No
Docker, no cloud accounts, no shared state between the two - either can be
run, modified, or deleted independently of the other.
