# 0353 — test_placement_wire_gate and test_instance_update leak `untitled-NN.sch` into the repo root

Status: PARTIAL 2026-08-09 — DETECTOR half landed for the non-backup shape only; EMITTER half
still open, and `*~.sch` stays invisible (see 0356). Section at the end.
Area: tests/headless/test_placement_wire_gate.tcl, tests/headless/test_instance_update.tcl,
      tests/headless/full_audit.sh (scratch detector)
Found: 2026-08-09
Related: 0148 (the scratch-leak class), 0352 (the same detector blind spot)

## Symptom

Running the CI headless gate list leaves new files in the **repo root**:

    $ snap() { find . -name 'untitled*.sch' -not -path './.git/*' | sort; }
    $ B=$(snap); tests/headless/full_audit.sh <the 15 gated suites> >/dev/null 2>&1
    $ comm -13 <(printf '%s\n' "$B") <(snap)
    ./untitled-62.sch
    ./untitled-63~.sch

Isolated per suite by re-running each of the 15 individually with the same snapshot:

    test_placement_wire_gate    LEAKED: ./untitled-63.sch ./untitled-64~.sch
    test_instance_update        LEAKED: ./untitled-64~.sch

The other 13 gated suites leak nothing.

## Why nothing caught it

Same blind spot as issue 0352. `scratch_snapshot()` (full_audit.sh:146-149) globs
`_*_[0-9]*` only, and `.gitignore:64` ignores `_*_[0-9]*/` — neither matches
`untitled-63.sch`. The audit reports `SCRATCH: 0 leaked dir(s)` while the working tree
grows a file per run. The name is xschem's default for an unsaved buffer, so the leak is
a `save` (or an autosave `~` write) on a buffer that was never given a filename, landing
in the audit's cwd, which `full_audit.sh:37` pins to the repo root.

This has been accumulating for a long time: 85 `untitled*.sch` files were present across
the repo root, `src/` and `tests/` at the time of writing (the scout counted 76 earlier
the same day, so ~9 accrued during one crew's test runs).

## Why it was not fixed here

Outside item D1's blast radius: both suites are on the driver's tier list
(test_placement_wire_gate = 171 checks, test_instance_update = 95), so changing where
they write needs its own before/after measurement, and one of them is now a CI hard gate.

**Do not** "fix" this by adding `untitled*.sch` to `.gitignore` or by widening
`scratch_snapshot`'s glob — hiding a leak is the issue-0148 anti-pattern. The fix is for
the offending suite to name its buffer (or run under `tests/headless/scratch.tcl`), and
for the scratch detector to grow a file-level arm.

## Cleanup

The accumulated files were deliberately **not** deleted: `untitled-NN.sch` is exactly the
shape of unsaved user work, and the loss would be unrecoverable and invisible. Recipe for
a human who has confirmed none of it matters (dry run first — read the list):

    cd /home/analog/dev/xschem-claude
    git clean -nd -- 'untitled*.sch' 'untitled*~.sch' \
        'src/untitled*.sch' 'tests/untitled*.sch'     # -nd = DRY RUN
    # re-run with -fd once the list looks right

---

## Detector half landed (2026-08-09, in the 0354 item) — emitter half STILL OPEN

`full_audit.sh` grew a second, report-only leak arm (`tree_delta_snapshot()`, a
`git status --porcelain --untracked-files=all` diff around the run). It reported this leak
live, on the very first verified run, while the pre-existing directory glob stayed blind:

    TREEADD | ?? untitled-62.sch
    SCRATCH:  0 leaked dir(s)

**It sees only the non-backup half of this issue.** `git status` honours `.gitignore`, and
`.gitignore:55,:56` hide `*~.sch` / `*~.sym` — so `untitled-NN.sch` is reported and
`untitled-NN~.sch` is not. Measured in a controlled synthetic repo carrying this repo's own
`.gitignore`; locked by C39b/C39c in `test_audit_classifier.tcl`. See 0356 for the open
decision on widening.

The arm is report-only by construction and deletes nothing: `full_audit.sh`'s cleanup loop
`rm -rf`s whatever the *scratch* snapshot reports, and `untitled-NN.sch` is shaped exactly
like unsaved user work, which this issue refuses to let the audit delete.

**Emitter half deliberately not fixed here.** Renaming the buffers in
`test_placement_wire_gate` (171 checks) and `test_instance_update` (95 checks) touches two
driver tiers plus a CI hard gate and needs its own before/after; with the new arm report-only,
nothing forces the coupling.
