.PHONY: scan clean help

TARGET_DIR ?= sast_target
MIN_SEVERITY ?= MEDIUM
export MIN_SEVERITY

help:
	@echo "make scan                          - run the SAST scan against TARGET_DIR (default: sast_target)"
	@echo "make scan TARGET_DIR=path/to/repo  - run against a different target"
	@echo "make scan MIN_SEVERITY=HIGH        - override the severity threshold (default: MEDIUM)"
	@echo "make clean                         - remove generated artifacts"

scan:
	./run.sh $(TARGET_DIR)

clean:
	rm -rf artifacts/sast.raw.json artifacts/sast.json
