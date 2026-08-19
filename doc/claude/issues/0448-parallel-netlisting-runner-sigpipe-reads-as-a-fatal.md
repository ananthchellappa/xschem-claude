# 0448 — the parallel netlisting runner intermittently loses a worker to SIGPIPE, and results.log reads it as FATAL

STATUS: open, measured, not fixed. Observed by the S5 IMPLEMENT agent of the
operating-point annotation run; unrelated to that step's subject.
NOT REPRODUCIBLE ON DEMAND — load-dependent.

## Symptom

A full `cd tests && tclsh run_regression.tcl` occasionally emits one leading `FATAL` line
that a rerun of the same tree does not. The cause is one parallel netlisting worker exiting
141 (128 + 13 = SIGPIPE), not a netlist difference.

Observed once in ~4 full runs across the S5 crew:

    netlisting job 502: or_ngspice.sch ... -q --nogui -r -t   -> exit 141

one job out of 748 dispatched across 8 parallel workers.

## Why it matters more than a normal flake

`run_regression.tcl` SCORES a leading `FATAL`. The documented reading of results.log — "a
FAIL ending a line, GOLD?, RESULT? or a leading FATAL counts" — therefore turns this into
an apparent regression for anyone diffing tier counts between a baseline and a change.
The S5 crew hit exactly that: the Implement agent's first T1 read 3 FAIL + 1 FATAL against
a 3 FAIL + 0 FATAL baseline, which looks like a new failure and is not.

## Evidence that it is not a real netlist failure

* the exact failing command, rerun standalone with the change live: rc=0, 5 times out of 5;
* `tclsh netlisting.tcl` alone: 0 FATAL;
* a second full `run_regression.tcl`: 0 FATAL, 3 FAIL — identical to baseline;
* the S5 VERIFY-A agent's independent full run: 0 FATAL, 3 FAIL, and 1496 netlisting result
  files, exactly the baseline count.

## A second, related instability in the same runner

The netlisting result-file COUNT is not stable run to run: baseline 1496, the Implement
agent's two runs 1494 and 1476, Verify-A's run 1496 again. `netlisting` is NOGOLD and
verifies nothing, so no comparison currently depends on that count — but anyone who later
promotes a netlisting baseline will inherit this instability and should fix the runner
first.

## Fix sketch

Find where the parallel dispatcher closes a pipe to a worker that is still writing, and
either keep the read end open until the child exits or ignore SIGPIPE in the child. Then
make `run_regression.tcl` distinguish "a worker died" from "a case reported FATAL", so a
runner defect can never again be read as a test regression.

## Guard owed

A row that runs the netlisting suite and asserts every dispatched job exited 0, separately
from the golden comparison, so the runner's own health is measured rather than inferred
from the absence of a FATAL line.
