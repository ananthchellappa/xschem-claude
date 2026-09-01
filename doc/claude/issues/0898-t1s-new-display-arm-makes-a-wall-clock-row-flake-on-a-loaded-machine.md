# 0898 — T1's new display arm makes a wall-clock row flake on a loaded machine

**Status:** **OPEN**, low severity, recorded at the moment it was incurred
(backlog item A12, 2026-08-28). Not a product defect — a cost of the arm that
issue 0891 required, written down so the next person who sees the red knows what
it is.

## What changed

`tests/run_regression.tcl` now runs `headless/test_op_annot` **twice**: once
headless in the `hcases` loop, and once more on the persistent dev display
through `tests/headless/devdisplay.sh exec`. That second run is what closes
issue 0891 — the arm the user actually has is now the arm the everyday runner
exercises.

## The cost

`test_op_annot` carries a wall-clock row, **W33**, bounded at 3000 ms:

    note: W33 save_cards on 0_examples_top = 5010 ms (bound 3000 ms)

Measured 1089 ms in a clean run and 5010 ms during item A12's sabotage pass,
with several agents live on the box. So T1 can now go red for a reason that has
nothing to do with the annotation feature — and it has two chances to, not one.

Three runs of T1 alone (write-up, verify, sabotage) were all clean: **zero**
counted failures across 38 case blocks. It takes a loaded machine.

## The options, none taken

* Raise W33's bound. Cheap; weakens a row that exists to catch a real slowdown.
* Make W33 self-skip when the machine is loaded (`getloadavg`, or a calibration
  press timed at suite start). Honest, and it must **announce** the skip.
* Exclude wall-clock rows from the display arm specifically, since the headless
  arm already measures them and the display arm's subject is windows.
* Leave it, and let a reader who knows recognise it.

The third looks best — the display arm was added for `winfo`, not for
stopwatches — but it is a judgement about what T1 should cost, so it is recorded
rather than decided.
