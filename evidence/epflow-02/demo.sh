#!/usr/bin/env bash
# evidence/epflow-02/demo.sh - runnable proof for the handoff freshness guards in
# bin/fm-umbrella-promote.sh (incident root causes R1 promote-before-frozen and
# R6 no stale-sign guard).
#
# Drives the captain repro end to end, each case on a fresh throwaway umbrella:
#   1. DRAFT status          -> promote REFUSES with a sign-first message.
#   2. sign (status active + signed_off today) -> promote PASSES, seeds the backlog.
#   3. touch a story AFTER the sign-off -> promote REFUSES, NAMING that story.
#   4. --allow-stale-sign    -> promote proceeds with a LOUD warning naming the file.
#   5. re-sign the current design -> promote PASSES cleanly.
# Every refusal is checked to have written NOTHING into data/plans or the backlog.
# File mtimes are pinned in UTC so the day-resolution comparison is deterministic.
#
# Run:  evidence/epflow-02/demo.sh
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROMOTE="$ROOT/bin/fm-umbrella-promote.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/epflow02-demo.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# make_home <name> <status> <signed_off> : a fresh umbrella `u` with a `things`
# epic (stories svc-01..03) at the given status + sign-off. Echoes the home path.
make_home() {
  local home="$TMP/$1" status=$2 signed=$3 ep
  ep="$home/umbrellas/u/plans/ep"
  mkdir -p "$ep/stories" "$home/data"
  cat > "$home/data/projects.md" <<'EOF'
# Projects
- svc [local-only production=main] - fixture repo (added 2026-01-01)
EOF
  printf '## In flight\n\n## Queued\n## Done\n' > "$home/data/backlog.md"
  printf '# DESIGN\n' > "$home/umbrellas/u/DESIGN.md"
  cat > "$ep/epic.md" <<EOF
---
epic: things
title: Things epic
repos: [svc]
status: $status
signed_off: $signed
---
# Epic things
EOF
  local id gate
  for id in svc-01 svc-02 svc-03; do
    gate=false; [ "$id" = svc-01 ] && gate=true
    cat > "$ep/stories/$id.md" <<EOF
---
id: $id
epic: things
repo: svc
pr_base: main
depends: []
kind: ship
gate: $gate
---
# $id heading
EOF
  done
  printf '%s\n' "$home"
}

# pin_day <home> <YYYYMMDD> [file...] : pin the given files' mtime to that UTC day
# (defaults to all design files) so the day-resolution guard is deterministic.
pin_day() {
  local home=$1 day=$2; shift 2
  local ep="$home/umbrellas/u/plans/ep"
  if [ "$#" -eq 0 ]; then set -- "$ep/epic.md" "$ep/stories"/*.md "$home/umbrellas/u/DESIGN.md"; fi
  TZ=UTC touch -t "${day}0000" "$@"
}
wrote_nothing() { # <home> : assert a refusal left no trace
  [ ! -e "$1/data/plans/ep" ] || { echo "FAIL: refusal wrote into data/plans"; exit 1; }
  grep -q 'svc-01' "$1/data/backlog.md" && { echo "FAIL: refusal seeded the backlog"; exit 1; }
  echo "  (verified: nothing written to data/plans or the backlog)"
}

echo "==================== 1. DRAFT status refuses ===================="
H=$(make_home draft draft 2026-08-18)
if FM_HOME="$H" "$PROMOTE" u; then echo "FAIL: a draft epic promoted"; exit 1; fi
wrote_nothing "$H"

echo ""
echo "============= 2. sign (freeze), then promote passes ============="
H=$(make_home signed active "$(date -u +%Y-%m-%d)")
pin_day "$H" "$(date -u +%Y%m%d)"   # a just-signed design shares the sign-off day
FM_HOME="$H" "$PROMOTE" u
echo "  seeded backlog:"; grep -- '- \[ \] svc-' "$H/data/backlog.md" | sed 's/^/    /'

echo ""
echo "======= 3. edit a story AFTER sign-off -> stale, refuses ========"
H=$(make_home stale active 2026-08-18)
pin_day "$H" 20260818                                   # design pinned to the sign day
pin_day "$H" 20260820 "$H/umbrellas/u/plans/ep/stories/svc-02.md"   # captain's later edit
if FM_HOME="$H" "$PROMOTE" u; then echo "FAIL: a stale sign-off promoted"; exit 1; fi
wrote_nothing "$H"

echo ""
echo "======== 4. --allow-stale-sign proceeds with a WARNING ========="
FM_HOME="$H" "$PROMOTE" --allow-stale-sign u
echo "  seeded despite the stale sign-off (override), backlog:"
grep -- '- \[ \] svc-' "$H/data/backlog.md" | sed 's/^/    /'

echo ""
echo "============ 5. re-sign the current design -> passes ==========="
H=$(make_home resigned active 2026-08-20)   # sign-off now covers the later edit
pin_day "$H" 20260818
pin_day "$H" 20260820 "$H/umbrellas/u/plans/ep/stories/svc-02.md"
FM_HOME="$H" "$PROMOTE" u | sed -n '1,4p'

echo ""
echo "OK - draft and stale-sign are refused (naming the file); signing and re-signing pass; the override warns."
