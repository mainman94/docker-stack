#!/usr/bin/env bash
# Enforce the two Compose conventions from AGENTS.md that are cheap to check
# statically and expensive to notice later:
#
#   1. Every stack declares an explicit default network named
#      <stack>_network (hyphens in the directory name become underscores).
#      Without it Compose derives a name from the directory, which differs
#      between a repo checkout and the deploy host.
#
#   2. Every *mandatory* ${VAR} the compose file interpolates has a key in
#      that stack's .env.example. A missing key means the stack silently
#      starts with an empty value — usually an empty bind-mount path.
#      ${VAR:-default} is deliberately optional and is not required to appear.
#
# Accepts either a compose file or a .env.example; both map to their stack.
set -uo pipefail

status=0

# Stacks whose live network name predates this rule. Renaming one recreates
# the network on the deploy host and restarts everything attached to it, so
# they are grandfathered rather than silently rewritten. New stacks must
# follow the rule.
network_exception() {
  case "$1" in
    paperless-ngx) echo "paperless_network" ;;
    pocket-id) echo "pocket-id_network" ;;
    *) echo "" ;;
  esac
}

# Variables the compose file requires a value for: the bare ${VAR} form and
# the ${VAR:?msg} "fail if unset" form. `$$FOO` is an escape meaning a literal
# `$FOO` inside the container, so strip `$$` pairs before scanning.
compose_required_vars() {
  sed -e 's/^[[:space:]]*#.*$//' -e 's/\$\$//g' "$1" |
    grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*(\}|:\?)' |
    sed -e 's/^\${//' -e 's/[}:?]*$//' |
    sort -u
}

env_keys() {
  grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=' "$1" |
    tr -d ' \t=' |
    sort -u
}

# Reduce the changed files to the set of stack directories they belong to.
stacks=$(for f in "$@"; do dirname -- "$f"; done | sort -u)

for dir in $stacks; do
  stack=$(basename -- "$dir")
  compose=""
  for candidate in "$dir/docker-compose.yaml" "$dir/docker-compose.yml"; do
    if [ -f "$candidate" ]; then
      compose="$candidate"
      break
    fi
  done
  [ -n "$compose" ] || continue

  expected_network=$(network_exception "$stack")
  [ -n "$expected_network" ] || expected_network="${stack//-/_}_network"

  if ! grep -qE "^[[:space:]]*name:[[:space:]]*${expected_network}[[:space:]]*$" "$compose"; then
    printf '%s: default network is not named %s\n' "$compose" "$expected_network" >&2
    printf '  add:\n    networks:\n      default:\n        name: %s\n' "$expected_network" >&2
    status=1
  fi

  vars=$(compose_required_vars "$compose")
  [ -n "$vars" ] || continue

  example="$dir/.env.example"
  if [ ! -f "$example" ]; then
    printf '%s: interpolates ${VAR} but the stack has no .env.example\n' "$compose" >&2
    status=1
    continue
  fi

  missing=$(comm -23 <(printf '%s\n' "$vars") <(env_keys "$example"))
  if [ -n "$missing" ]; then
    printf '%s: required by %s but absent from the file:\n' "$example" "$compose" >&2
    printf '%s\n' "$missing" | sed 's/^/  /' >&2
    printf '  (use ${VAR:-default} in the compose file if the value is optional)\n' >&2
    status=1
  fi
done

exit "$status"
