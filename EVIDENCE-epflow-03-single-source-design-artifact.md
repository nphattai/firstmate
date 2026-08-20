# Evidence: epflow-03 single-source design artifact

Throwaway-umbrella proof that the epic-dir design artifact is a symlink to the
ONE canonical umbrella-root `DESIGN.md`, so an edit to the canonical shows
through the reference and `realpath` dedups every reachable `DESIGN.md` for the
epic to a single file. Kills R4 (the drifting epic-dir copy).

Reproduce (against this branch's `bin/fm-umbrella.sh`):

    T=$(mktemp -d); mkdir -p "$T/projects/svc"; git -C "$T/projects/svc" init -q
    git -C "$T/projects/svc" -c user.email=a@b -c user.name=a commit -q --allow-empty -m init
    FM_HOME="$T" bin/fm-umbrella.sh create demo --repos svc
    mkdir -p "$T/umbrellas/demo/plans/260820-epic-demo/stories"
    printf -- '---\nepic: demo\n---\n# epic\n' > "$T/umbrellas/demo/plans/260820-epic-demo/epic.md"
    FM_HOME="$T" bin/fm-umbrella.sh link-design demo 260820-epic-demo
    printf '\n## Decided contract\nlocked.\n' >> "$T/umbrellas/demo/DESIGN.md"
    realpath "$T/umbrellas/demo/DESIGN.md" \
             "$T/umbrellas/demo/plans/260820-epic-demo/DESIGN.md" | sort -u | wc -l   # -> 1

## Captured run
### 1. Stand up a throwaway umbrella
```
created umbrella demo
  repos: svc
  lab:   umbrellas/demo/  (cd there and drive your coding agent)
  design: umbrellas/demo/DESIGN.md
```
### 2. Scaffold an epic dir + link the design
```
linked DESIGN.md  (umbrellas/demo/plans/260820-epic-demo/DESIGN.md -> ../../DESIGN.md)
```
### 3. Edit the umbrella-root canonical, read it back through the epic-dir reference
```
epic-dir DESIGN.md symlink target: ../../DESIGN.md
tail read through the link:
## Decided contract
OpenAPI v3 shape locked 2026-08-20.
```
### 4. realpath-dedup and same-inode proof
```
distinct real files: 1  (DoD: exactly 1)
test -ef: TRUE (same inode) - single source of truth
```
