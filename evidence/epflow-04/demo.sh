#!/usr/bin/env bash
# evidence/epflow-04/demo.sh - captain-reviewable proof for epflow-04.
#
# Builds a self-contained fixture (a project registry + a standard epic dir with
# seven-key story frontmatter) and runs bin/fm-epic-lint.sh against it TWICE:
#   1. a standard, contract-correct epic            -> PASS (exit 0)
#   2. a copy doctored to the real incident shape    -> FAIL (exit 1), naming
#      the exact reasons: `story:`/`phase:` keys, an uppercase id that does not
#      match its filename, a mismatched epic, an unregistered repo, a bad
#      pr_base, a bad kind, and the resulting broken dependency + gate count.
#
# Everything is a throwaway temp dir: no home, no backlog, nothing mutated.
# Re-run: evidence/epflow-04/demo.sh   (regenerate the captured transcript with
#         evidence/epflow-04/demo.sh > evidence/epflow-04/transcript.txt 2>&1).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINT="$ROOT/bin/fm-epic-lint.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# A registry that registers `svc` (and nothing else).
cat > "$T/projects.md" <<'EOF'
# Projects
- svc [direct-PR production=main] - fixture repo (added 260101)
EOF

# --- a standard, valid epic -------------------------------------------------
mkdir -p "$T/good/stories"
cat > "$T/good/epic.md" <<'EOF'
---
epic: things
title: Things epic
repos: [svc]
---
# Epic things
EOF
write_story() {  # <dir> <id> <gate> <depends>
  cat > "$1/stories/$2.md" <<EOF
---
id: $2
epic: things
repo: svc
pr_base: main
depends: $4
kind: ship
gate: $3
---
# Story $2 heading
EOF
}
write_story "$T/good" svc-01 true '[]'
write_story "$T/good" svc-02 false '[svc-01]'
write_story "$T/good" svc-03 false '[svc-01]'

echo "============================================================"
echo "1. A STANDARD epic (seven-key frontmatter, one gate story)"
echo "   \$ fm-epic-lint.sh <good-epic>"
echo "------------------------------------------------------------"
FM_PROJECTS_REG="$T/projects.md" "$LINT" "$T/good"
echo "   exit: $?  (expected 0 - PASS)"
echo

# --- the same epic, doctored to the real incident shape ---------------------
cp -R "$T/good" "$T/bad"
# Replace svc-02 with an out-of-pipeline story exactly like the aimica LH-01:
# uppercase id, `story:`/`phase:` keys, wrong epic/repo/pr_base/kind.
rm -f "$T/bad/stories/svc-02.md"
cat > "$T/bad/stories/LH-01.md" <<'EOF'
---
story: LH-01
phase: 1
epic: aimica-learning-hub
repo: ghost-repo
pr_base: refs/bad~~name
depends: []
kind: frobnicate
gate: true
---
# Story LH-01
EOF

echo "============================================================"
echo "2. The SAME epic with one story authored the wrong way"
echo "   (story: LH-01 - uppercase id, story:/phase: keys, mismatch)"
echo "   \$ fm-epic-lint.sh <doctored-epic>"
echo "------------------------------------------------------------"
FM_PROJECTS_REG="$T/projects.md" "$LINT" "$T/bad"
echo "   exit: $?  (expected 1 - FAIL, with the numbered reasons above)"
echo
echo "Done. The same lint is the epic-review gate AND the promote-validate check."
