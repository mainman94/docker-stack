#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "${1:-}" ]; then
  case "$1" in
    /*) env_file=$1 ;;
    *) env_file=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1") ;;
  esac
else
  env_file=$script_dir/.env
fi

cd "$script_dir"
compose_file=docker-compose.yaml

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 1
fi

config_file=$(mktemp)
mounts_file=$(mktemp)
trap 'rm -f "$config_file" "$mounts_file"' EXIT

docker compose --env-file "$env_file" -f "$compose_file" config --format json > "$config_file"

jq -r '
      .services
      | to_entries[]
      | .key as $service
      | .value.volumes[]?
      | select(.type == "bind" and (.target | startswith("/backup/")))
      | [$service, .target, .source]
      | @tsv
    ' "$config_file" > "$mounts_file"

missing=0
empty=0

while IFS="$(printf '\t')" read -r service target source; do
  if [ ! -e "$source" ]; then
    echo "ERROR: $service $target source is missing: $source" >&2
    missing=$((missing + 1))
    continue
  fi

  if [ ! -d "$source" ]; then
    echo "ERROR: $service $target source is not a directory: $source" >&2
    missing=$((missing + 1))
    continue
  fi

  if [ -z "$(find "$source" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    echo "WARN:  $service $target source is empty: $source" >&2
    empty=$((empty + 1))
    continue
  fi

  echo "OK:    $service $target <- $source"
done < "$mounts_file"

if [ "$missing" -gt 0 ]; then
  echo "Backup preflight failed: $missing missing or invalid source path(s)." >&2
  exit 1
fi

if [ "$empty" -gt 0 ]; then
  echo "Backup preflight passed with $empty empty source path warning(s)." >&2
else
  echo "Backup preflight passed."
fi
