# 0353 — test_placement_wire_gate and test_instance_update leak `untitled-NN.sch` into the repo root

Status: MEASURED, NOT FIXED (discovered by the item-D1 crew while verifying 0350/0351)
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
