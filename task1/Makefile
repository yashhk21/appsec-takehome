.PHONY: scan clean help

TARGET_DIR ?= fixtures

help:
	@echo "make scan                          - run the secrets scan against TARGET_DIR (default: fixtures)"
	@echo "make scan TARGET_DIR=path/to/repo  - run against a different target"
	@echo "make clean                         - remove generated artifacts"

scan:
	./run.sh $(TARGET_DIR)

clean:
	rm -rf artifacts/secrets.raw.json artifacts/secrets.filtered.json
