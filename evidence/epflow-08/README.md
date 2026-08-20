# evidence/epflow-08 - one story = one repo = one dispatchable unit

Catch a story that bundles more than one repo BEFORE dispatch, so it is split into per-repo stories with a dependency edge at authoring time - not discovered when a crewmate cannot be spawned (report G-multirepo).
A crewmate spawns in ONE worktree, so a story whose body assigns work to a second repo can never dispatch as a single unit.
`fm-epic-lint` now scans each story body and surfaces the second repo at scaffold/review time.

## The incident this kills

Story frontmatter has ONE `repo:`, but a story could smuggle a second repo in prose ("Also touches webapp").
aimica hit this on `lh-10` (an insurtech backend flag plus a webapp consumer) and the firstmate had to split it by hand into `lh-12` (insurtech, dep-free) plus `lh-10` (webapp, blocked-by lh-12); `lh-05/06/09` were latent two-repo stories headed for the same wall.
The split shape - producer story lands the shared contract, consumer story `depends:` on it - is exactly what the lint now points the author toward.

## What changed

- **Detection (`bin/fm-epic-lint.sh`, `bin/fm-epic-lint-lib.sh`).** A new `fm_registered_repos` helper enumerates the home's registered repos; the lint scans each story body against them and flags any repo other than the story's own `repo:`. The match is case-insensitive and word-bounded (`svc` does not match `service`, and a story id like `svc-01` does not match the `svc` repo). A **bare mention** is a WARNING (the author may reference a dependency benignly). A mention on a line that **also carries a deliverable verb** (`touch`, `change`, `modify`, `update`, `edit`, `add`, `wire`, `implement`, `build`, `ship`, `patch`, `create`) is a hard **FAIL** - that body is assigning work to a second repo. `consume`/`depend`/`produce` are deliberately excluded so a well-split consumer story can name the repo it depends on without failing. `FM_EPIC_LINT_MULTIREPO` tunes strictness: `off` disables the scan, `warn` downgrades every finding to a warning, `strict` fails on any mention, and the default layers as above. epflow-04's and epflow-07's checks are untouched - this is a new layer.
- **Docs (`skills/epic-scaffold`, `skills/epic-review`).** Both carry the byte-identical "one story = one repo = one dispatchable unit" note and the per-repo-stories-linked-by-`depends:` split pattern. epic-scaffold's self-check adds the one-repo rule; epic-review names the detection in its executable-gate check and calls out any multi-repo story as a **FAIL-to-split before handoff** - including the judgment that a lint WARNING may still be a bundled cross-repo unit hiding behind prose.

Heuristic + human judgment, NOT an auto-splitter: the lint/review surfaces the multi-repo story; the author splits it. No `fm-epic-split-story` machinery.

`docs/epic-convention.md` is a per-home doc seeded by the gflow epic, not tracked in this repo, so the tracked owners of the frontmatter contract - the two skills - carry the documentation here (same as epflow-07).

## Run

- `evidence/epflow-08/demo.sh` - a hermetic fixture epic (insurtech + webapp registered) that proves each Definition-of-done case end to end.
- `transcript.txt` - the demo output.

## What the transcript proves matches the DoD

- **Clean single-repo passes.** `flag-02` (repo `webapp`, cross-repo link via `depends: [flag-01]`, no second repo in its body) produces no finding.
- **Benign mention WARNS, does not fail.** `flag-03` names `insurtech` with no deliverable verb (it consumes the flag); the lint WARNS and still exits 0.
- **A two-repo deliverable FAILS.** `flag-04` says "Also touches insurtech: update the flag default and add a migration" - the exact aimica shape - and the lint exits 1 with `body assigns work to a second repo "insurtech"`.
- **Strictness tunes it.** `off` produces no finding; `warn` keeps `flag-04` as a warning at exit 0; `strict` fails even `flag-03`'s bare mention.

## Tests

`tests/fm-epic-lint.test.sh` adds seven cases: a clean single-repo pass, a benign cross-repo WARN that still passes, a deliverable-verb FAIL, a word-boundary no-false-positive, and the `off` / `strict` / `warn` strictness modes.
The existing epflow-04 and epflow-07 cases in the same file stay green, and `tests/fm-umbrella-promote.test.sh` (which runs the same lint at promote-validate) stays green.
