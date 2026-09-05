#!/usr/bin/env bash
# Run `docker compose config` over each Compose file handed in.
#
# Two things make this less trivial than it looks:
#
#   * A service-level `env_file:` does NOT satisfy compose-level ${VAR}
#     interpolation (AGENTS.md), so the stack's env file has to be passed
#     explicitly with --env-file.
#   * The real env files (.env, infrastructure/volume-backup/backup.env) are
#     host-only and never committed, so on a checkout the compose file
#     references files that do not exist.
#
# So each stack is validated in a scratch copy holding only the compose file
# and its env files, with every committed `<name>.example` materialised as
# `<name>` when the real one is absent. Nothing is written into the worktree.
#
# Used by pre-commit and by `make validate`.
set -uo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "compose-config: docker not on PATH — skipped." >&2
  echo "  Install Docker, or open the repo in .devcontainer, to get this check." >&2
  exit 0
fi

status=0
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

for file in "$@"; do
  [ -f "$file" ] || continue
  dir=$(dirname -- "$file")
  base=$(basename -- "$file")

  work="$scratch/$(printf '%s' "$dir" | tr '/' '_')"
  rm -rf "$work"
  mkdir -p "$work"
  cp "$file" "$work/$base"

  # Copy env files only — never the stack's data directories, which on a
  # deploy host hold the live bind mounts and can be enormous.
  for env_src in "$dir"/*.env "$dir"/.env "$dir"/*.env.example "$dir"/.env.example; do
    [ -f "$env_src" ] && cp "$env_src" "$work/"
  done

  # `backup.env.example` -> `backup.env`, `.env.example` -> `.env`.
  for example in "$work"/*.example "$work"/.*.example; do
    [ -f "$example" ] || continue
    real="${example%.example}"
    [ -e "$real" ] || cp "$example" "$real"
  done

  # Compose-level interpolation source: whichever env file the stack ships.
  env_file=""
  for candidate in .env backup.env; do
    if [ -f "$work/$candidate" ]; then
      env_file="$work/$candidate"
      break
    fi
  done

  if [ -n "$env_file" ]; then
    args=(--env-file "$env_file" -f "$work/$base" config --quiet)
  else
    args=(-f "$work/$base" config --quiet)
  fi

  if ! err=$(docker compose "${args[@]}" 2>&1); then
    printf 'invalid compose file: %s\n' "$file" >&2
    printf '%s\n' "$err" | grep -v 'level=warning' | sed "s|$work|$dir|g; s/^/  /" >&2
    status=1
  fi
done

exit "$status"
