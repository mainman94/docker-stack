#!/usr/bin/env sh
set -eu

usage() {
  cat >&2 <<'EOF'
Usage: restart-unhealthy-containers.sh [--backup-labeled|backup-label]

Restarts running containers whose Docker health status is unhealthy.

Modes:
  --backup-labeled  only containers with any docker-volume-backup stop label
  backup-label      only containers with docker-volume-backup.stop-during-backup=<backup-label>

Examples:
  restart-unhealthy-containers.sh
  restart-unhealthy-containers.sh --backup-labeled
  restart-unhealthy-containers.sh paperless
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is required" >&2
  exit 1
fi

filter_args="--filter health=unhealthy"
case "${1:-}" in
  --backup-labeled)
    filter_args="$filter_args --filter label=docker-volume-backup.stop-during-backup"
    ;;
  "")
    ;;
  *)
    filter_args="$filter_args --filter label=docker-volume-backup.stop-during-backup=$1"
    ;;
esac

# shellcheck disable=SC2086
containers=$(docker ps -q $filter_args)

if [ -z "$containers" ]; then
  echo "No unhealthy containers found."
  exit 0
fi

for container in $containers; do
  name=$(docker inspect --format '{{.Name}}' "$container" | sed 's#^/##')
  echo "Restarting unhealthy container: $name"
  docker restart "$container" >/dev/null
done
