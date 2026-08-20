#!/usr/bin/env bash
# evidence/epflow-08/demo.sh - runnable proof for "one story = one repo = one
# dispatchable unit" detection in fm-epic-lint (epflow-08).
#
# Builds a throwaway fixture home whose registry holds TWO repos (insurtech and
# webapp), mirroring the aimica incident (report G-multirepo): a story that
# bundled an insurtech backend flag with a webapp consumer could not dispatch (a
# crewmate gets ONE worktree) and had to be hand-split into insurtech + webapp
# stories linked by depends:. This demo shows the lint catching that shape at
# AUTHORING time, and the DoD cases:
#   1. a clean single-repo story passes;
#   2. a BENIGN cross-repo mention (names webapp with no deliverable verb) WARNS
#      but the epic still passes - the author may reference a dependency;
#   3. a story that clearly ASSIGNS work to a second repo ("Also touches webapp:
#      update ...") FAILS the lint (exit 1) with the exact reason - split it;
#   4. FM_EPIC_LINT_MULTIREPO tunes strictness: `off` disables the scan, `warn`
#      downgrades even a deliverable finding to a warning, `strict` fails even a
#      bare mention.
#
# Run:  evidence/epflow-08/demo.sh
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/epflow08-demo.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
HOME_DIR="$TMP/home"
EPIC_DIR="$HOME_DIR/data/plans/epic-flag/stories"
mkdir -p "$EPIC_DIR"

cat > "$HOME_DIR/data/projects.md" <<'EOF'
# Projects
- insurtech [no-mistakes production=main] - backend fixture (added 2026-01-01)
- webapp    [no-mistakes production=main] - web consumer fixture (added 2026-01-01)
EOF

cat > "$HOME_DIR/data/plans/epic-flag/epic.md" <<'EOF'
---
epic: flag
title: Feature flag epic
repos: [insurtech, webapp]
status: active
signed_off: 2026-01-02
---
# Feature flag epic
EOF

# story <file> <id> <repo> <depends> <gate> <body-line...>
story() {
  local file=$1 id=$2 repo=$3 depends=$4 gate=$5; shift 5
  {
    printf -- '---\n'
    printf 'id: %s\nepic: flag\nrepo: %s\npr_base: %s\ndepends: [%s]\nkind: ship\ngate: %s\n' \
      "$id" "$repo" "$([ "$gate" = true ] && echo main || echo epic/flag)" "$depends" "$gate"
    printf -- '---\n'
    printf '# %s\n\n' "$id"
    for line in "$@"; do printf '%s\n' "$line"; done
  } > "$EPIC_DIR/$file"
}

# The gate story: the shared contract (the flag itself) lands first, in insurtech.
story flag-01.md flag-01 insurtech "" true \
  "Add the feature flag to the insurtech backend and expose it on the profile API."

# A CLEAN single-repo consumer split out the aimica way: it names only its own
# repo body-side; the cross-repo link is expressed through depends:, not prose.
story flag-02.md flag-02 webapp flag-01 false \
  "Read the flag in the webapp client and gate the new banner behind it."

# A BENIGN cross-repo mention: names insurtech with no deliverable verb (it is
# just describing the dependency it consumes). WARNS, does not fail.
story flag-03.md flag-03 webapp flag-01 false \
  "Context: this consumes the flag that the insurtech backend exposes upstream."

LINT="$ROOT/bin/fm-epic-lint.sh"
export FM_HOME="$HOME_DIR"
EPIC="$HOME_DIR/data/plans/epic-flag"

echo "==================== 1+2. clean single-repo passes; a benign mention WARNS ===================="
if OUT="$("$LINT" "$EPIC" 2>&1)"; then
  echo "-> lint EXIT 0 (the epic passes)."
  printf '%s\n' "$OUT" | grep -E 'WARNINGS|references repo "insurtech"|epic lint OK' | sed 's/^/   /'
else
  echo "FAIL: a clean + benignly-mentioning epic must pass"; printf '%s\n' "$OUT"; exit 1
fi

echo ""
echo "==================== 3. a story ASSIGNING work to a second repo FAILS ===================="
# The exact aimica shape: a webapp story that also smuggles an insurtech change.
story flag-04.md flag-04 webapp flag-01 false \
  "Read the flag in the webapp banner." \
  "Also touches insurtech: update the flag default and add a migration."
if "$LINT" "$EPIC" >/tmp/epflow08-fail.out 2>&1; then
  echo "FAIL: a two-repo story must fail the lint"; cat /tmp/epflow08-fail.out; exit 1
else
  echo "-> lint EXIT 1 as expected. Reason:"
  grep 'assigns work to a second repo' /tmp/epflow08-fail.out | sed 's/^/   /'
fi

echo ""
echo "==================== 4a. FM_EPIC_LINT_MULTIREPO=off disables the scan ===================="
if FM_EPIC_LINT_MULTIREPO=off "$LINT" "$EPIC" >/tmp/epflow08-off.out 2>&1; then
  echo "-> lint EXIT 0 (scan disabled)."
  case "$(cat /tmp/epflow08-off.out)" in
    *"second repo"*) echo "FAIL: off must produce no cross-repo finding"; exit 1 ;;
    *) echo "   (no cross-repo finding with the scan off)" ;;
  esac
else
  echo "FAIL: off must let the epic pass"; cat /tmp/epflow08-off.out; exit 1
fi

echo ""
echo "==================== 4b. FM_EPIC_LINT_MULTIREPO=warn downgrades the FAIL to a warning ===================="
if OUT="$(FM_EPIC_LINT_MULTIREPO=warn "$LINT" "$EPIC" 2>&1)"; then
  echo "-> lint EXIT 0 (warn mode never fails)."
  printf '%s\n' "$OUT" | grep -E 'WARNINGS|references repo "insurtech"' | sed 's/^/   /'
else
  echo "FAIL: warn mode must not fail"; printf '%s\n' "$OUT"; exit 1
fi

echo ""
echo "==================== 4c. FM_EPIC_LINT_MULTIREPO=strict fails even the benign mention ===================="
rm -f "$EPIC_DIR/flag-04.md"   # back to clean + benign only
if FM_EPIC_LINT_MULTIREPO=strict "$LINT" "$EPIC" >/tmp/epflow08-strict.out 2>&1; then
  echo "FAIL: strict must fail on any cross-repo mention"; cat /tmp/epflow08-strict.out; exit 1
else
  echo "-> lint EXIT 1 as expected. Reason:"
  grep 'assigns work to a second repo' /tmp/epflow08-strict.out | sed 's/^/   /'
fi

echo ""
echo "OK - clean passes, benign warns, a two-repo deliverable fails, and off/warn/strict tune it."
