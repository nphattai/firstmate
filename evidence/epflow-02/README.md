# evidence/epflow-02 - handoff freshness guards (stale-sign + design-freeze)

Stops `bin/fm-umbrella-promote.sh` from seeding a backlog from a design that is not frozen or whose sign-off is stale.
Closes incident root causes R1 (promote-before-frozen) and R6 (no stale-sign guard): the 08-18 aimica promote ran while the design still had two days of heavy redesign ahead, and `signed_off: 2026-08-18` stayed stale through all of it with nothing to catch it.

The contract is now sign-THEN-promote.
Two guards run after the `fm-epic-lint` contract check and before any mutation, so a refusal writes nothing:

- **Design-freeze.** `epic.md status` must be `active`; a draft (or any non-active) status is refused with a sign-first message. This is the same "signed = active + signed_off" definition `bin/fm-epic-status.sh` already reports.
- **Stale-sign.** `signed_off` must be no older than the newest of `epic.md`, every `stories/*.md`, and the umbrella's `DESIGN.md`, compared at DAY resolution (signed_off is a UTC date, and writing it touches `epic.md` the same day it is signed, so a same-day edit is treated as covered). A later edit is refused, naming the offending file; `--allow-stale-sign` downgrades that refusal to a loud warning.

## Run

- `evidence/epflow-02/demo.sh` - a hermetic fixture umbrella driving the full captain repro, each case on a fresh throwaway home: draft refuses -> sign and promote passes -> edit a story after sign-off refuses (naming `svc-02.md`) -> `--allow-stale-sign` proceeds with a loud warning -> re-sign passes cleanly. Every refusal is checked to have written nothing to `data/plans` or the backlog. File mtimes are pinned in UTC so the day-resolution comparison is deterministic regardless of the wall clock.
- `transcript.txt` - the captured demo output.

## What the transcript proves matches the story

- **Draft refuses, writes nothing.** Section 1: a `status: draft` epic is refused with "not \"active\" ... SIGN the epic", and `data/plans` + backlog stay empty.
- **Signed design promotes.** Section 2: after `status: active` + `signed_off: <today>`, promote moves the epic and seeds `svc-01..03`.
- **A post-sign edit is stale and names the file.** Section 3: `signed_off: 2026-08-18` with `svc-02.md` edited on `2026-08-20` refuses - "sign-off is stale: umbrellas/u/plans/ep/stories/svc-02.md was modified 2026-08-20, AFTER signed_off: 2026-08-18" - and writes nothing.
- **The override is loud, not silent.** Section 4: `--allow-stale-sign` proceeds but prints the same message as a `warning:` naming the file, then seeds.
- **Re-signing passes cleanly (idempotent).** Section 5: bumping `signed_off` to `2026-08-20` (covering the newest file) promotes with no refusal.
- **The epilogue is coherent with the guard.** The post-promote steps no longer tell the captain to sign AFTER promote (the flow R1 fixes); they confirm the frozen sign-off and point at re-signing on revision.

## Test

`tests/fm-umbrella-promote.test.sh` proves the same guards against fixture homes: `test_refuses_draft_status`, `test_stale_sign_guard` (refuse naming the file, then pass after re-sign), and `test_allow_stale_sign_override`.
The shared `make_home` fixture now signs the epic by default so the existing 16 promote tests exercise a frozen, current design; the guard tests re-sign it to the draft/stale states.
mtimes are pinned in UTC (`TZ=UTC touch -t`) so the day-resolution comparison is deterministic in CI.
