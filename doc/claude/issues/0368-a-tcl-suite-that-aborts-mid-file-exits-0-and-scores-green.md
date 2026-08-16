# 0368 - a headless Tcl suite that aborts mid-file exits 0 and scores GREEN

Status: FILED (measured, not fixed)
Found by: D4 Verify-B (sabotage), 2026-08-10
Class: harness / test-scoring. Siblings: 0350, 0351, 0354 (full_audit scoring holes).

## What was measured

During the D4 sabotage loop, variant S4 (put `Tcl_ResetResult(interp);` back in
`src/scheduler.c`'s `descend_symbol` branch, so the verb evaluates to `""` again)
made `tests/headless/test_descend_refusal_channel_0251.tcl` **abort in the middle
of the file**:

```
ok:   R27 hi_descend on a type=label instance returns 0
ok:   R27 ... and reports the reason to the CIW (today it echoes NOTHING)
Tcl_AppInit() error: can not execute tests/headless/test_descend_refusal_channel_0251.tcl, please fix:
expected boolean value but got ""
Line No: 315
```

Line 315 is `hi_descend_finish`'s `if {$ok}` (`src/xschem.tcl`, `set ok [xschem
descend_symbol]`) -- see the Implement report's separate finding D.

The abort is not the defect. **The scoring is.** That run:

- exited with **rc = 0**
- printed **zero `FAIL` lines**
- printed **no `OVERALL:` line at all**
- ran 29 of its 34 checks; **R25 and R28 never executed**

So the standard signals a harness greps for -- a trailing `FAIL`, a non-zero exit
status -- all say PASS. A suite that lost 5 checks and died halfway through is
indistinguishable from a suite that passed.

This is the same shape as the item that produced it: a refusal that is
indistinguishable from a success.

## Why the obvious detector does not work

"Require an `OVERALL:` line" is the natural fix, but it cannot be applied
blanket-wide: `tests/headless/test_placement_preview_doors.tcl` emits
`RESULT: ALL PASS (177 checks)` and **no `OVERALL:` line by design** (recorded in
the D4 driver brief and confirmed by D4 Measure). Any global rule has to cope
with both conventions.

## Suggested shape (not implemented)

Two independent options, either of which closes it:

1. **Terminator assertion.** Every headless suite ends with a single line the
   harness requires -- `OVERALL: ok (N checks)` or `RESULT: ...` -- and the
   wrapper treats *absence of any terminator* as FAIL. This needs
   `test_placement_preview_doors.tcl` to grow the line it currently omits.

2. **Expected-check-count.** Each suite declares the number of checks it intends
   to run; the wrapper fails when fewer arrive. This also catches silent
   truncation from a `return` in the wrong branch, which option 1 does not.

Additionally, `Tcl_AppInit() error:` on stdout/stderr should be a hard FAIL token
in the wrapper regardless -- it is already unambiguous and costs one grep.

## Reproduction

```sh
cd /home/analog/dev/xschem-claude
# in src/scheduler.c, in the `descend_symbol` branch, replace
#   Tcl_SetResult(interp, dtoa(ret), TCL_VOLATILE);
# with
#   Tcl_ResetResult(interp);
cd src && make && cd ..
./src/xschem --nogui --pipe -q --nolog \
  --script tests/headless/test_descend_refusal_channel_0251.tcl; echo "rc=$?"
# rc=0, no FAIL, no OVERALL, 29 of 34 checks run
```

## Related

- The proximate trigger is the Implement report's finding D (`set ok [xschem
  descend_symbol]` is not empty-safe). Hardening that one call site would stop
  *this* abort but not the class -- any `error` raised mid-suite scores the same
  way.
- 0350 / 0354: `full_audit.sh` scoring predicates that pass on the wrong evidence.
- 0367: `test_context_menu_log` hangs under X -- a hang is the other end of the
  same gap (no terminator, no verdict).
