#!/usr/bin/env bash
# evidence/epflow-06/demo.sh - captain-reviewable proof for epflow-06.
#
# Builds a real fixture epic (a git clone with a bare origin, plus an epic dir
# with story frontmatter and a no-mistakes-green surface) and runs the gated
# bin/fm-epic-ship.sh --dry-run through three states, showing the two refusals
# and the pass:
#   1. a kind:ship story is unmerged            -> REFUSE, naming the story
#   2. all stories merged but no green evidence -> REFUSE, fail-closed
#   3. green recorded at the epic tip           -> the ship PR opens (dry-run)
#
# Everything is dry-run and self-contained: no live remote, no PR is created.
# Re-run: evidence/epflow-06/demo.sh   (regenerate the captured transcript with
#         evidence/epflow-06/demo.sh > evidence/epflow-06/transcript.txt 2>&1).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHIP="$ROOT/bin/fm-epic-ship.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# --- stubs: fm-project-mode.sh --branches (no staging) and gh-axi -----------
STUB="$T/stub"; mkdir -p "$STUB"
cat > "$STUB/fm-project-mode.sh" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = --branches ] && { printf '%s\n' "${FM_STUB_BRANCHES:-}"; exit 0; }
exit 0
SH
cat > "$STUB/gh-axi" <<'SH'
#!/usr/bin/env bash
case "$1 ${2:-}" in
  "pr list")   exit 0 ;;                                   # no PR open
  "pr create") printf 'https://github.com/acme/proj/pull/1\n'; exit 0 ;;
esac
exit 0
SH
chmod +x "$STUB"/*

git_c() { git -C "$C" -c user.name=t -c user.email=t@t.invalid "$@"; }

# --- fixture: a repo with an epic/demo branch carrying one story's commit ----
src="$T/proj.src"
git init -q "$src"
git -C "$src" -c user.name=t -c user.email=t@t.invalid commit -q --allow-empty -m init
git -C "$src" branch -m main
git clone -q --bare "$src" "$T/proj.git"
git clone -q "$T/proj.git" "$T/proj"
C="$T/proj"
git_c checkout -q -B epic/demo
printf 'feature one\n' > "$C/one.txt"; git_c add one.txt
git_c commit -qm "feat(demo): first slice (demo-01)"   # references story short-id demo-01
git_c push -q origin epic/demo

# --- epic dir under FM_HOME, read by the ship gates -------------------------
H="$T/home"; D="$H/data/plans/260820-1203-epic-demo"; mkdir -p "$D/stories"
printf -- '---\nepic: demo\ntitle: demo epic\n---\n' > "$D/epic.md"
story() { printf -- '---\nid: %s\nepic: demo\nrepo: %s\nkind: ship\ngate: false\n---\n' "$1" "$C" > "$D/stories/$1.md"; }
story demo-01-first     # landed: its (demo-01) commit is on epic/demo
story demo-02-second    # NOT landed yet: no demo-02 commit on epic/demo

ship() { FM_HOME="$H" FM_PROJECT_MODE_BIN="$STUB/fm-project-mode.sh" FM_GH_BIN="$STUB/gh-axi" \
  FM_STUB_BRANCHES=main "$SHIP" demo "$C" --dry-run; }

hr() { printf '\n========================================================================\n%s\n========================================================================\n' "$1"; }

hr "STATE 1 - story demo-02 unmerged: expect REFUSE naming demo-02"
ship; echo "[exit $?]"

hr "STATE 2 - land demo-02, still no green evidence: expect REFUSE (fail-closed)"
git_c checkout -q epic/demo
printf 'feature two\n' > "$C/two.txt"; git_c add two.txt
git_c commit -qm "feat(demo): second slice (demo-02)"
git_c push -q origin epic/demo
ship; echo "[exit $?]"

hr "STATE 3 - record no-mistakes-green at the epic tip: expect the PR to open"
printf '%s  # demo whole-epic green\n' "$(git -C "$C" rev-parse epic/demo)" > "$D/no-mistakes-green"
ship; echo "[exit $?]"

hr "STATE 3b - epic advances past the green run: green is sha-bound, expect REFUSE"
git_c checkout -q epic/demo
printf 'feature three\n' > "$C/three.txt"; git_c add three.txt
git_c commit -qm "feat(demo): third slice (demo-03)"
git_c push -q origin epic/demo
story demo-03-third
ship; echo "[exit $?]"

hr "STATE 4 - --allow-incomplete: single logged bypass ships despite incomplete+stale-green"
FM_HOME="$H" FM_PROJECT_MODE_BIN="$STUB/fm-project-mode.sh" FM_GH_BIN="$STUB/gh-axi" \
  FM_STUB_BRANCHES=main "$SHIP" demo "$C" --allow-incomplete --dry-run; echo "[exit $?]"
