# epflow-04 evidence - fm-epic-lint (one executable epic/story contract)

Proof that `bin/fm-epic-lint.sh` is the single runnable check for "is this epic
valid", green on a standard epic and red (naming every reason) on the exact
incident shape that started this epic - a story authored out of pipeline with
`story: LH-01` (uppercase id, `story:`/`phase:` keys, id/filename mismatch).
The same lint is now the epic-review gate AND the `fm-umbrella-promote.sh`
validate check, so the contract is enforced at authoring time, not only too
late at promote (kills R5).

## What to run

```
evidence/epflow-04/demo.sh
```

Self-contained: builds a throwaway registry + a standard epic dir with seven-key
story frontmatter, runs the lint on it (PASS), then on a copy doctored to the
incident shape (FAIL). Nothing outside the temp dir is touched.

`transcript.txt` is a captured run (tmp paths differ per run).

## What it shows

| Case | Epic | Expected | Result |
|---|---|---|---|
| 1 | standard, seven-key frontmatter, one gate story | PASS | `epic lint OK: "things" - 3 stories`, exit 0 |
| 2 | one story authored as `story: LH-01` (uppercase, `story:`/`phase:` keys, wrong epic/repo/pr_base/kind, second gate) | FAIL, numbered reasons | 8 problems incl. `unexpected frontmatter key "story:"`, `missing frontmatter key "id:"`, exit 1 |

## Portable regression

The full good/bad table is pinned in `tests/fm-epic-lint.test.sh` (runs in CI,
no harness): green standard epic; resolvable vs templated plan pointer; and RED
on each of the incident case, uppercase id, id/filename mismatch, duplicate id,
epic mismatch, bad pr_base, unregistered story repo, unregistered epic repo,
missing key, bad kind, zero gate, many gate, unknown depends, dependency cycle,
unresolvable plan pointer, and missing epic slug - plus the exit-2 structural
errors.

`tests/fm-umbrella-promote.test.sh` proves promote now delegates validation to
the same lint (its fixtures are lint-valid, and its refusals surface the lint's
messages), so promote and review share ONE implementation with no duplicated
frontmatter parsing left in the promote script.
