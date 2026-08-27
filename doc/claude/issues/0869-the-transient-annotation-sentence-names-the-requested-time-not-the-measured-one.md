# 0869 — the transient annotation sentence names the time the user ASKED for, not the time the number was measured at

**Status:** 🔴 **OPEN — measured, NOT fixed.** Filed by the A3 write-up, 2026-08-27,
from the adversary leg of the 0868 run. Class: **RULING D5-1** — a number that was
not measured for the thing it is displayed next to.

Owner of the code: issue **0868**, `cadence::_annot_tran_msg` in
`utils/annot_mode.tcl` (~:545) and `cadence::annot_tran` (~:596).

## The claim the design leans on

0868 holds a **snapshot**: after the user asks (Alt-Shift-6, or
*Results > Annotate > Transient Node Voltages (at cursor)*), the number stays on the
sheet while the cursor moves on. The only thing that was argued to keep that honest
under RULING D5-1 is that the user is TOLD what it was measured at. `src/xschem.h`
says so in its own words — *"a held snapshot is honest only because the user was told
what it was measured at"* — and `tests/headless/test_op_annot.tcl` repeats it above
row V17: *"the only thing keeping it honest under RULING D5-1 is that the user was
told what it was measured at"*.

The sentence does not carry that. It renders `$t` — the **requested** cursor
position — and RULING D4-4 makes the engine hold the boundary sample for an
out-of-range request, correctly, without telling the sentence.

## Measured, 2026-08-27, on the shipped binary at `5500ad59` + the 0868 tree

Fixture: `/tmp/a3m/lib/g.sch` (one `lab_pin` `d`) with the 5-point transient
`/tmp/a3m/tran.raw`, whose LAST SAMPLE IS t = 4e-09, inside a graph whose x-range
runs to 5e-9 — so cursor B at 4.5 ns is visibly on screen, inside the plot, and past
the end of the data. Paint read by SVG export (FAQ Q52), never `xschem translate`:

```
WU1 state=ok SENTENCE = Transient annotation at t = 4.5e-09 (cursor B)
WU1 PAINTED = d 4   annot = 4 4.5e-09 0
WU2 state=ok SENTENCE = Transient annotation at t = 9.9e-08 (cursor B)
WU2 PAINTED = d 4   annot = 4 9.9e-08 0
```

`4` was measured at **4e-09**. The user is told **4.5e-09**, and then **99e-09**.

## Why it is reachable, not a lab curiosity

Any time the plotted x-range outruns the data: an interrupted run, a raw still being
written by a live ngspice, a graph left at a previous longer run's x-range, a `.tran`
that stopped early. The cursor is a screen object; it does not know where the samples
end.

## The suite is structurally blind to it, and that is the second half of the defect

* Row **V4** exercises the out-of-range paint (`opa_v_at 99e-9`, expects `{4 0}`) and
  **never looks at the sentence**.
* Row **V17** exercises the sentence at an **in-range** time
  (`cadence::_annot_tran_msg ok 1e-09 A`) as a **pure string test**, never against
  real data.

No row composes the two, which is exactly where D5-1 bites. A fix must add the
composing row, not only change the wording.

## What is NOT this issue

The ENGINE stamping the requested x into `annot_x` is pre-existing and not 0868's
doing — `xschem set cursor2_x 99e-9` yields `annot=4 9.9e-08 0` and
`xschem annotate_at 99e-9` yields the identical `annot=4 9.9e-08 0` — and `annot_x`
is painted nowhere (its only reader is the `xschem raw annot` query,
`src/scheduler.c:10590`). What 0868 minted, and what this issue owns, is **showing
that requested time to the user as the measurement time**.

## Options

1. **Name the sample.** Resolve the annotated point's own x (`annot_p` indexes it)
   and render that, e.g. *"Transient annotation at t = 4e-09 (cursor B at 4.5e-09)"*.
   Honest, and it makes the D4-4 hold visible instead of hiding it.
2. **Name both only when they differ**, one clause instead of two in the common case.
3. **Refuse an out-of-range request** and say so — a sixth state. Rejected on sight:
   D4-4 deliberately holds, and a refusal would contradict a landed ruling.

Recommended: **1**, with the composing row (out-of-range paint AND the sentence in
one check) as its acceptance.
