#!/usr/bin/env bash
# Provision the dev container: install pre-commit, wire up the git hook, and
# warm the hook environments so the first commit is not a five-minute wait.
set -euo pipefail

echo "==> installing pre-commit"
pipx install pre-commit 2>/dev/null || pip install --user --break-system-packages pre-commit

export PATH="$HOME/.local/bin:$PATH"

echo "==> installing trivy and jq (for make scan)"
sudo apt-get update -qq
sudo apt-get install -y -qq wget gnupg jq
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null
sudo apt-get update -qq
sudo apt-get install -y -qq trivy

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
