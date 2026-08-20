# Evidence - epflow-01 promote full-reconcile + verify

Reproduces R2 (the aimica 10-stale-brief incident) on a throwaway epic and shows
`verify` red on the doctored state, green after promote converges it.
Captured with the epflow-01 feature build of bin/fm-umbrella-promote.sh.

## 1. First promote (stories authored as UPPERCASE `LH-01`/`LH-02`)
```
moved epic dir -> data/plans/lh-epic (umbrella keeps a back-symlink to it)
seeded LH-01  [aimica-learning-hub]  (repo: insurtech-service, kind: ship)
seeded LH-02  [aimica-learning-hub]  (repo: insurtech-service, kind: ship)

Promoted umbrella "aimica" -> epic "aimica-learning-hub" (data/plans/lh-epic).
  seeded: 2    reconciled: 0    renamed: 0    already correct: 0    total: 2

STOP - the remaining steps are human/firstmate-owned (this script never signs, branches, or dispatches):
  1. Review umbrellas/aimica/DESIGN.md, then SIGN the epic:
     set epic.md status pending -> active and add 'signed_off: <DATE>' in data/plans/lh-epic/epic.md
  2. Cut one epic branch per involved repo:
     bin/fm-epic-branch.sh create aimica-learning-hub insurtech-service
  3. Firstmate dispatches the queued stories (each anchored to its epic branch).
  4. When the epic has landed, tear down the umbrella:
     bin/fm-umbrella.sh teardown aimica
```

### backlog after first promote
```
## In flight

## Queued
- [ ] LH-01 - [aimica-learning-hub] SSO gateway (repo: insurtech-service) (kind: ship) (since 2026-08-20)

- [ ] LH-02 - [aimica-learning-hub] Enrollment API (repo: insurtech-service) (kind: ship) (since 2026-08-20)
## Done
```

## 2. After redesign: story files renamed `LH-01`->`lh-01` + title changed
The backlog still carries the stale UPPERCASE ids/titles - drift.

### `verify` is RED (names the exact drift)
```
verify FAILED for umbrella "aimica" (epic "aimica-learning-hub", data/plans/lh-epic):
  - (d) story "lh-01" has only a stale case-variant backlog entry "LH-01" (id not reconciled)
  - (d) story "lh-02" has only a stale case-variant backlog entry "LH-02" (id not reconciled)
  - (e) backlog "LH-01" carries tag [aimica-learning-hub] but no story file has that id (orphan)
  - (e) backlog "LH-02" carries tag [aimica-learning-hub] but no story file has that id (orphan)
exit=1
```

## 3. Re-run promote - CONVERGES the backlog to the canonical epic
```
epic dir already promoted to data/plans/lh-epic (reconciling backlog only).
renamed backlog id LH-01 -> lh-01 and refreshed its fields  [aimica-learning-hub]
renamed backlog id LH-02 -> lh-02 and refreshed its fields  [aimica-learning-hub]

Promoted umbrella "aimica" -> epic "aimica-learning-hub" (data/plans/lh-epic).
  seeded: 0    reconciled: 0    renamed: 2    already correct: 0    total: 2

STOP - the remaining steps are human/firstmate-owned (this script never signs, branches, or dispatches):
  1. Review umbrellas/aimica/DESIGN.md, then SIGN the epic:
     set epic.md status pending -> active and add 'signed_off: <DATE>' in data/plans/lh-epic/epic.md
  2. Cut one epic branch per involved repo:
     bin/fm-epic-branch.sh create aimica-learning-hub insurtech-service
  3. Firstmate dispatches the queued stories (each anchored to its epic branch).
  4. When the epic has landed, tear down the umbrella:
     bin/fm-umbrella.sh teardown aimica
```

### backlog after reconcile (ids + titles now match the renamed story files)
```
## In flight

## Queued
- [ ] lh-01 - [aimica-learning-hub] SSO gateway (redesigned: shared insurtech DB) (repo: insurtech-service) (kind: ship) (since 2026-08-20)
- [ ] lh-02 - [aimica-learning-hub] Enrollment API (repo: insurtech-service) (kind: ship) (since 2026-08-20)
## Done
```

### `verify` is now GREEN
```
verify OK: epic "aimica-learning-hub" is canonical at data/plans/lh-epic, the umbrella back-symlink resolves, the .promoted marker is correct, and every story has a matching queued brief.
exit=0
```
