#!/usr/bin/env bash
# CVE sweep across every image the stacks run.
#
# Advisory by default: it reports and exits 0, because a new upstream CVE in
# somebody else's image is not a reason to block a commit here. Pass --strict
# to exit non-zero when anything CRITICAL is found — that is what a gating CI
# job would use.
#
# --ignore-unfixed throughout: an unfixed CVE is not actionable from this repo,
# and burying the fixable ones under them is how a report stops being read.
#
# Used by `make scan` and .github/workflows/scan.yml.
set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 1

strict=0
[ "${1:-}" = "--strict" ] && strict=1

if ! command -v trivy >/dev/null 2>&1; then
  echo "scan-images: trivy not on PATH — skipped." >&2
  echo "  Install trivy, or open the repo in .devcontainer, to run this." >&2
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "scan-images: jq not on PATH — skipped." >&2
  exit 0
fi

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

total_critical=0
total_high=0
affected=0
report="$scratch/report.md"

printf '| Image | Critical | High |\n|---|--:|--:|\n' >"$report"

while IFS= read -r image; do
  out="$scratch/scan.json"
  if ! trivy image --quiet --scanners vuln --ignore-unfixed \
    --severity CRITICAL,HIGH --format json --output "$out" "$image" 2>"$scratch/err"; then
    printf '  ! %-70s scan failed\n' "$image" >&2
    sed 's/^/      /' "$scratch/err" >&2
    printf '| `%s` | — | — |\n' "$image" >>"$report"
    continue
  fi

  critical=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "$out")
  high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "$out")

  total_critical=$((total_critical + critical))
  total_high=$((total_high + high))

  if [ "$critical" -gt 0 ] || [ "$high" -gt 0 ]; then
    affected=$((affected + 1))
    printf '  %-70s C:%-4s H:%s\n' "${image%%@*}" "$critical" "$high"
    printf '| `%s` | %s | %s |\n' "${image%%@*}" "$critical" "$high" >>"$report"
  fi
done < <(scripts/list-images.sh)

printf '\n%d image(s) with fixable CRITICAL/HIGH findings — %d critical, %d high in total\n' \
  "$affected" "$total_critical" "$total_high"

# In CI, put the table in the run summary rather than making someone read logs.
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    printf '## Image CVE sweep\n\n'
    printf '%d image(s) affected — **%d critical**, **%d high** (fixable only).\n\n' \
      "$affected" "$total_critical" "$total_high"
    if [ "$affected" -gt 0 ]; then cat "$report"; else printf 'No fixable CRITICAL or HIGH findings.\n'; fi
  } >>"$GITHUB_STEP_SUMMARY"
fi

if [ "$strict" -eq 1 ] && [ "$total_critical" -gt 0 ]; then
  exit 1
fi
exit 0
