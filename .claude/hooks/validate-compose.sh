#!/usr/bin/env sh
# PostToolUse hook: validate a Compose stack after its docker-compose.yaml is edited.
# Uses the stack's .env.example (or .env) so ${VAR} interpolation resolves,
# per the --env-file rule documented in AGENTS.md.
set -eu

file=$(jq -r '.tool_input.file_path // empty')

# Only act on real stack compose files; skip skill/template scaffolding.
case "$file" in
  */.claude/*) exit 0 ;;
esac
case "$file" in
  */docker-compose.yaml|*/docker-compose.yml) ;;
  *) exit 0 ;;
esac

[ -f "$file" ] || exit 0
command -v docker >/dev/null 2>&1 || exit 0

dir=$(dirname -- "$file")
if [ -f "$dir/.env" ]; then
  env_file="$dir/.env"
elif [ -f "$dir/.env.example" ]; then
  env_file="$dir/.env.example"
else
  env_file=""
fi

if [ -n "$env_file" ]; then
  set -- --env-file "$env_file" -f "$file" config -q
else
  set -- -f "$file" config -q
fi

if ! err=$(docker compose "$@" 2>&1); then
  echo "compose config invalid for $file:" >&2
  echo "$err" >&2
  exit 2
fi
