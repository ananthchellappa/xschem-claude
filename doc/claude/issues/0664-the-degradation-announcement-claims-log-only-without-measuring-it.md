# 0664 — the degradation announcement claims LOG-ONLY without measuring it

Status: OPEN (measured twice, NOT fixed — introduced by issue 0658's fix)
Filed by: the 0658 crew, 2026-08-24. Found by the adversary leg, independently
reproduced by the write-up pass.

## Measured

`xschem::notify_degraded_once` (`src/xschem.tcl`) hard-codes its consequence
clause, and the `ciw.tcl` source-catch (`src/xschem.tcl:14854`) fires it whenever
the source fails at **any** point — including *after* the whole notify family and
`ciw_create` have already been defined.

Share farm whose `ciw.tcl` is the real file plus a trailing
`error {WU-C deliberate failure at the END of ciw.tcl}`, child launched
`--nogui --pipe -q --logdir`:

```
child status              : 0
CHILD notify-is-bootstrap : 0        <- the FULL four-sink channel is live
CHILD ciw_echo present    : 1
CHILD unknown opt raises  : 1        <- ciw.tcl:257's strict switch is live
CHILD sinks reached       : ciw log  <- the notice reached the pane AND the file
LOG| #! NOTICE CHANNEL DEGRADED: notices are LOG-ONLY from here on (no CIW pane,
     no status field, no popup, no remedy). Cause: src/ciw.tcl failed to source:
     WU-C deliberate failure at the END of ciw.tcl
LOG| #! WU-C a notice in a session whose channel is FULLY ALIVE
```

The adversary measured the same thing on `:99` with a real `.ciw` present.

## Why it matters

The claim is false and it is **permanent**: it is written into `Xschem.log`, the
one artifact issue 0658 exists to protect, and stderr. `notify_degraded_once`
asserts a consequence it never measures. That is precisely 0652's class — a
report that lies — and 0657 is the same defect one layer down (`sinks` claimed
`log` with no log open).

A second-order effect: `::xschem::notify_degraded` **latches** on this false
positive, so a genuinely degraded state later in the same session announces
**nothing**. Issue 0658's acceptance row R4 ("the announcement fires ONCE, not
per notice") passes either way — it cannot distinguish a true announcement from
a spurious one.

## Probable fix

Measure before claiming. The discriminator is already used by 0658's own tests:

```tcl
if {[string match {*notify_bootstrap*} [info body ::xschem::notify]]} { ... }
```

If the live `::xschem::notify` is still the bootstrap wrapper, the LOG-ONLY
sentence is true; otherwise announce the **source failure alone** ("a startup
step failed; the notice channel itself is live") and do **not** burn the
one-shot latch. Keep the literal marker `NOTICE CHANNEL DEGRADED` for the truly
degraded case — `test_ase_core` NTD4/NTD6 and `test_ase_log_seam_0207` PS23/PS27
grep for it.

## Still open

All of it.
