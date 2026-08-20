# hlay-06 evidence - home workspace label survives a compact

Story: `hlay-06-home-label-survives-compact`.
Feature branch (code only): `fm/hlay-06-home-label-survives-compact`.

## What was wrong

After a session **compaction**, a home's herdr workspace label reverted from the
home name to the cwd-basename `firstmate`, so that home's crews collapsed under a
flat `firstmate` group (observed live: `aimica` -> `firstmate`).

Two root causes, both fixed:

1. `bin/fm-session-start.sh` - the `--reemit` path a `/clear` or compaction takes
   skipped the herdr home labeling, so the label was never re-applied after the
   herdr client reverted it. Fix: re-run `fm-herdr-home-label.sh` on the locked
   `--reemit` path (idempotent, herdr-only, no-op on other backends, only when
   this session holds the lock).
2. `bin/fm-herdr-home-label.sh` - an unset `FM_HOME` silently fell through to the
   code root whose basename is `firstmate`, so any call without `FM_HOME`
   relabeled the workspace to `firstmate`. Fix: refuse with a loud warning rather
   than mislabel when the home is unresolved.

## Files here

- `herdr-workspace-list-live.txt` - real herdr 0.8.0 binary, read-only
  `herdr workspace list` on the captain's live session. Shows home workspaces
  labeled by home name (`distro`, `aimica`, `infina-inside`) with crew task
  workspaces nested (`└ ...`). The healthy reference state the fix keeps stable.
- `before-after-demo.txt` - deterministic before/after against a fake herdr
  mirroring the real 0.8.0 CLI. INVARIANT 1: a resolved home labels `aimica` on
  both OLD and NEW. INVARIANT 2: OLD silently renames the workspace to
  `firstmate` (the bug); NEW warns and refuses, leaving the label untouched.
- `test-fm-herdr-home-label.txt` - the new focused unit test (labels / refuses /
  non-herdr no-op) passing.
- `test-session-start-reemit.txt` - the new session-start E2E proving the
  `--reemit` (compaction) path re-applies the workspace label, plus the full
  suite passing.

## Limitation - the live harness-compact E2E is firstmate's to run

A genuine harness compaction on a live home (`/compact` inside the `aimica`
entrypoint session, then `herdr workspace list` showing `aimica` still labeled
`aimica`) needs the real home's entrypoint session and a real harness compact.
As a crewmate in a disposable worktree I cannot trigger that, and this brief's
hard safety gate forbids me from standing up an isolated herdr session/lab to
synthesize it (that is herdr lifecycle driving). I also must not rename the
captain's live workspaces. So the real-binary artifact here is the read-only
snapshot; the mechanism is proven deterministically by the before/after demo and
the automated tests. The final live-compact confirmation on `aimica` is best run
by firstmate, which owns that home and observed the original revert.
