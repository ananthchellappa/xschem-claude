# 0356 — a headless suite DELETED an untracked file from the repo tree

**Status:** OPEN (detector landed; emitter unidentified)
**Filed:** 2026-08-09, during the 0354 item (number claimed as a stub so a later crew in the
same run could not collide).
**Class:** same family as 0352 / 0353 — tests mutating the developer's working tree — but the
opposite direction. 0352/0353 are about files a run *creates*; this one is about a file a run
*removes*.

## What was measured

During this item's baseline tier sweep the pre-existing untracked backup file
`./tests/untitled-16~.sch` (an 89-byte empty schematic) was present in a `find . -name
'untitled*.sch'` snapshot taken *before* the sweep and absent from the snapshot taken *after*
it. It was not one of the four files the sweeping agent's own cleanup loop consumed
(`./untitled-60.sch`, `./untitled-61~.sch`, `./tests/untitled-16.sch`,
`./tests/untitled-17~.sch`). So a shipped suite deleted it.

Nothing of value was lost — it was untracked scratch left behind by an earlier run of the same
class of suite (0353). The defect is that a test reached outside its own scratch directory and
removed a file it did not create, in a tree the developer is looking at.

## Which suite

Not yet identified. The two suites known to write `untitled-NN.sch` into the repo root are
`test_placement_wire_gate` and `test_instance_update` (issue 0353); a save/backup path that
rotates `<name>~.sch` is the obvious suspect, but that has NOT been measured. Do not guess —
the whole point of the 0354 item is that name-guessing is what produced this class.

## What landed for it in the 0354 item — and why it does NOT close this issue

`tests/headless/full_audit.sh` grew a second, report-only leak arm — `tree_delta_snapshot()`,
a `git status --porcelain --untracked-files=all` diff taken before and after the run — which
reports BOTH directions as `TREEADD | …` / `TREEDEL | …` plus a `TREE:` summary line. It is
deliberately **report only**: it feeds no removal and no exit path, and is not wired into
`AUDIT_STRICT_SCRATCH`.

**That arm cannot detect this issue's emitter.** The 0354 item's adversary pass caught the
write-up overclaiming here, and it was corroborated in a controlled synthetic repo carrying
this repo's own `.gitignore`:

    $ git check-ignore -v untitled-61~.sch
    .gitignore:55:*~.sch    untitled-61~.sch

`git status` honours `.gitignore`, and `.gitignore:55,:56` hide `*~.sch` / `*~.sym`. This
issue's ONLY measured instance is `tests/untitled-16~.sch` — a `*~.sch`. So the deletion that
defines the issue is invisible to the arm in both directions. Creating `untitled-61~.sch` and
deleting `untitled-16~.sch` in the synthetic repo produced **no `TREEADD` and no `TREEDEL`**,
while the non-ignored `untitled-60.sch` and `undo_link_child/drive.tcl` were reported
correctly.

Locked, as a LIMIT rather than a capability, by **C39b / C39c** in
`tests/headless/test_audit_classifier.tcl` — the probe now copies this repo's real
`.gitignore` into its synthetic tree and asserts that a leaked and a deleted `*~.sch` are
both unreported. (C39a keeps the real capability: a NON-ignored deletion is seen.) Negative
control: with the `.gitignore` copy disabled, both rows go red, proving they measure the
ignore rule and not a typo.

## What remains

1. **Decide whether to widen the arm — this is the open question, deliberately not settled
   by the 0354 item.** Widening means `--ignored=matching` filtered to `*~.sch` / `*~.sym`,
   which re-introduces exactly the name-guessing that the 0354 item exists to remove; the
   alternative is a `find`-based arm, which sees everything but must then decide what is
   noise. Either way it is a design choice with a real tradeoff, not an improvisation for an
   unattended crew.
2. Identify the emitting suite. Until (1) lands, the `TREEDEL` lines will not name it — use a
   `find . -name 'untitled*~.sch'` snapshot around a run instead, which is how it was found.
3. Fix that suite to confine itself to `tests/headless/scratch.tcl`.
4. Only then consider making the tree delta fatal; doing so before 0352/0353/0356 are all
   fixed would redden a hard gate on the first honest report.

## Live recurrence during the 0354 item

The post-fix CI-gate verification run deleted `./untitled-60~.sch` from the repo root and
created `untitled-61~.sch`, while the arm reported `TREE: 1 appeared 0 vanished` — a second
independent sighting of this class, and the measurement that exposed the `.gitignore` gap.
The vanished file was not recreated: fabricating a file to restore state would be dishonest,
and it was gitignored empty scratch.
