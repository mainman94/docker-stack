#!/usr/bin/env bash
# Every container image referenced by a stack in this repo, deduplicated.
#
# The compose files never interpolate the image field — tags and digests are
# written literally so Renovate can see them — so a grep is exact here and
# needs neither docker nor the per-stack .env files.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

grep -rhoE '^[[:space:]]+image:[[:space:]]*\S+' \
  eggenberg-services/*/docker-compose.yaml \
  infrastructure/*/docker-compose.yaml |
  sed 's/.*image:[[:space:]]*//' |
  sort -u
