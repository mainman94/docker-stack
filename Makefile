# docker-stack — Compose stacks for the eggenberg host.
#
# Targets that only read the worktree (lint, validate, conventions) run
# anywhere. Targets that touch a stack (up, down, logs, backup-check) assume
# you are on the deploy host, where the real .env files and bind mounts exist.

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

SERVICES_DIR := eggenberg-services
BACKUP_DIR   := infrastructure/volume-backup
COMPOSE_FILES := $(wildcard $(SERVICES_DIR)/*/docker-compose.yaml) $(BACKUP_DIR)/docker-compose.yaml

# `make up STACK=jellyfin`
STACK ?=
STACK_DIR = $(SERVICES_DIR)/$(STACK)
# A stack's real .env is host-only; fall back to the committed example so the
# read-only targets still work on a fresh checkout.
STACK_ENV = $(if $(wildcard $(STACK_DIR)/.env),$(STACK_DIR)/.env,$(STACK_DIR)/.env.example)
DC = docker compose --env-file $(STACK_ENV) -f $(STACK_DIR)/docker-compose.yaml

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "  Stack targets take STACK=<name>, e.g. make up STACK=jellyfin"

# --- local checks ------------------------------------------------------------

.PHONY: tools
tools: ## Install the pinned toolchain from mise.toml
	@command -v mise >/dev/null || { echo "mise not on PATH — see https://mise.jdx.dev or .devcontainer" >&2; exit 1; }
	mise install

.PHONY: hooks
hooks: ## Install the git pre-commit hooks
	pre-commit install

.PHONY: lint
lint: ## Run every pre-commit hook over the whole tree
	pre-commit run --all-files

.PHONY: fmt
fmt: ## Format YAML and shell in place
	pre-commit run yamlfmt --all-files || true
	pre-commit run shfmt-src --all-files || true

.PHONY: validate
validate: ## docker compose config every stack
	scripts/validate-compose.sh $(COMPOSE_FILES)

.PHONY: conventions
conventions: ## Check network naming and .env.example coverage for every stack
	scripts/check-stack-conventions.sh $(wildcard $(SERVICES_DIR)/*/docker-compose.yaml)

.PHONY: check
check: lint validate conventions ## Everything a PR needs to pass

.PHONY: images
images: ## List every container image the stacks reference
	@scripts/list-images.sh

.PHONY: scan
scan: ## CVE sweep across every referenced image (advisory)
	scripts/scan-images.sh

.PHONY: scan-strict
scan-strict: ## Same sweep, but fail if anything CRITICAL is fixable
	scripts/scan-images.sh --strict

.PHONY: update-hooks
update-hooks: ## Bump pinned hook revisions
	pre-commit autoupdate

# --- deploy host -------------------------------------------------------------

.PHONY: backup-check
backup-check: ## Verify every backup bind-mount source exists (run on the host)
	sh $(BACKUP_DIR)/check-backup-paths.sh \
		$(if $(wildcard $(BACKUP_DIR)/backup.env),$(BACKUP_DIR)/backup.env,$(BACKUP_DIR)/backup.env.example)

.PHONY: up
up: guard-STACK ## Start a stack
	$(DC) up -d

.PHONY: down
down: guard-STACK ## Stop a stack
	$(DC) down

.PHONY: restart
restart: guard-STACK ## Recreate a stack after a compose change
	$(DC) up -d --force-recreate

.PHONY: pull
pull: guard-STACK ## Pull a stack's images
	$(DC) pull

.PHONY: logs
logs: guard-STACK ## Follow a stack's logs
	$(DC) logs -f --tail=100

.PHONY: config
config: guard-STACK ## Print a stack's fully resolved compose config
	$(DC) config

.PHONY: stacks
stacks: ## List every stack in the repo
	@ls -1 $(SERVICES_DIR)

guard-%:
	@if [ -z "$($*)" ]; then \
		echo "error: $* is not set — e.g. make $(MAKECMDGOALS) $*=jellyfin" >&2; \
		exit 1; \
	fi
