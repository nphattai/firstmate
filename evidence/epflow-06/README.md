# epflow-06 evidence - ship completeness + no-mistakes-green gate

Proof that `bin/fm-epic-ship.sh` now refuses to open a ship PR for an incomplete
or unvalidated epic (kills G-ship-1 and G-ship-2).

## What to run

```
evidence/epflow-06/demo.sh
```

Self-contained: builds a real fixture epic (git clone + bare origin + an epic
dir with story frontmatter and a `no-mistakes-green` surface) and runs the gated
ship `--dry-run` through each state. No live remote, no PR is created.

`transcript.txt` is a captured run (tmp paths differ per run).

## What it shows

| State | Situation | Expected | Result |
|---|---|---|---|
| 1 | story `demo-02` not yet on `epic/demo` | refuse, naming `demo-02` | `error: ... INCOMPLETE ... references story: demo-02`, exit 1 |
| 2 | all stories landed, no green evidence | refuse, fail-closed | `error: ... no no-mistakes-green evidence ...`, exit 1 |
| 3 | green recorded at the epic tip | PR opens (dry-run) | `production PR (epic/demo -> main)`, exit 0 |
| 3b | epic advances past the green run | refuse (green is sha-bound) | `error: ... no no-mistakes-green evidence for ... tip <new-sha>`, exit 1 |
| 4 | `--allow-incomplete` | single logged bypass ships | `warn: --allow-incomplete ...` + `BYPASS ...` ships.md line, exit 0 |

## Portable regression

The same behavior is pinned in `tests/fm-epic-ship.test.sh` (runs in CI with no
harness): refuse-incomplete, refuse-not-green, stale-green refuses, complete+green
opens, repo-scoped completeness, and the `--allow-incomplete` bypass+log.
