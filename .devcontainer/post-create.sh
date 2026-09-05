#!/usr/bin/env bash
# Provision the dev container: install pre-commit, wire up the git hook, and
# warm the hook environments so the first commit is not a five-minute wait.
set -euo pipefail

echo "==> installing pre-commit"
pipx install pre-commit 2>/dev/null || pip install --user --break-system-packages pre-commit

export PATH="$HOME/.local/bin:$PATH"

echo "==> installing the git hook"
pre-commit install

echo "==> warming hook environments (first run downloads yamlfmt, shellcheck, shfmt, gitleaks)"
pre-commit install-hooks

cat <<'MSG'

docker-stack dev container ready.

  make help          list every target
  make check         lint + compose validate + convention check
  make up STACK=...  start one stack against this container's own daemon

The real per-stack .env files live on the deploy host and are not in the repo;
read-only targets fall back to each stack's .env.example.
MSG
