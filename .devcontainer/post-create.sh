#!/usr/bin/env bash
# Provision the dev container. Every tool the repo needs is pinned in
# mise.toml — python, pre-commit, trivy, jq, actionlint, shellcheck — so this
# only installs mise and lets it do the rest, then wires up the git hook and
# warms the hook environments so the first commit is not a five-minute wait.
# CI installs from the same file.
set -euo pipefail

echo "==> installing mise"
curl -fsSL https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"

# Activate for interactive shells so the pinned binaries are on PATH.
for shell in bash zsh; do
  rc="$HOME/.${shell}rc"
  [ -f "$rc" ] || continue
  grep -q "mise activate" "$rc" || echo "eval \"\$(mise activate $shell)\"" >> "$rc"
done

echo "==> installing the pinned toolchain (python, pre-commit, trivy, jq, actionlint, shellcheck)"
cd "$(dirname "${BASH_SOURCE[0]}")/.."
mise trust
mise install
eval "$(mise activate bash --shims)" 2>/dev/null || export PATH="$HOME/.local/share/mise/shims:$PATH"

echo "==> installing the git hook"
mise exec -- pre-commit install

echo "==> warming hook environments (first run downloads yamlfmt, shfmt, gitleaks)"
mise exec -- pre-commit install-hooks

cat <<'MSG'

docker-stack dev container ready.

  make help          list every target
  make check         lint + compose validate + convention check
  make up STACK=...  start one stack against this container's own daemon

Tool versions come from mise.toml — the same file CI installs from.

The real per-stack .env files live on the deploy host and are not in the repo;
read-only targets fall back to each stack's .env.example.
MSG
