# 0673 — `test_wave_markers` litters a GITIGNORED `untitled~.sch` in the repo root, and it reddens `test_ase_core` later

Status: OPEN. Filed by the 0663 crew, 2026-08-24. Measured by Verify-A during a
50-suite broad sweep; the write-up agent confirmed the `.gitignore` half but did
not re-run the 977-check suite.

## Measured

Verify-A ran `tests/headless/test_wave_markers.tcl` with the repo root clean and
counted `untitled*` files before and after: **pre = 0, post = 1** — the file is
`untitled~.sch`, in the **repository root**.

`.gitignore:75` is:

```
*~.sch
```

so `git status --short` **never shows it**.

## Why that combination is worse than either half

1. The project's standing rule is that untracked `untitled*.sch` in the repo root
   turns three tests red (`save_as_cellview`, `untitled_reuse`,
   `descend_untitled_preserve`), and every crew is told to check
   `git status --short` before and after. **That check is structurally blind to
   this litter class**, because the autosave-twin rule hides it.
2. The consequence is delayed and lands on an innocent suite: with
   `untitled~.sch` present, `tests/headless/test_ase_core.tcl` fails its **C11**
   row (the issue-0609 guard). Verify-A saw exactly that in the sweep, and
   `test_ase_core` went back to **159 ALL PASS** the moment the root was cleared.

So the observable symptom is "`test_ase_core` is flaky", and the cause is a
different suite, several runs earlier, leaving a file `git status` refuses to
mention.

## Prior art

Commit `301c7a31` ("stop five suites littering") addressed this class but did
**not** cover `test_wave_markers`.

## The fix

1. Make `test_wave_markers` clean up after itself (or not create the autosave
   twin — it is a side effect of an unnamed buffer being autosaved, not something
   the suite wants).
2. Widen the tree-hygiene check crews are told to run so it can see this class,
   e.g. `git status --porcelain --ignored=matching -- ':(glob)untitled*'` — the
   same shape `.gitignore:50` already documents for the tracked untitled rules.

## Acceptance

Running `test_wave_markers` from a clean root leaves the root clean, verified
with an `--ignored=matching` status, and `test_ase_core` reports 159 immediately
afterwards in the same tree.

## Still open

All of it. The file itself was removed by Verify-A; the tree is clean as of this
commit.
