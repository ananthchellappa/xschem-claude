# 0872 — the two node-voltage bits share one render class, so the mode the user picked no longer describes the number on the sheet

**Status:** 🔴 **OPEN — measured, NOT fixed.** Filed by the A3 write-up, 2026-08-27,
from the adversary leg of the 0868 run. Class: **RULING 0856** reopens on the road
issue **0868** built, plus a status line that describes a state that is not the one
shown.

Owner: `annot_class_mask()` and `text_hidden()` in `src/actions.c` (~:1520/:1541),
`cadence::_annot_msg` in `utils/annot_mode.tcl` (~:266).

## The user's ruling this is measured against

> **0856 (user, verbatim)** — *"if OP is part of the run, then plot from OP. We
> haven't yet built anything for annotating from TRAN results, so it should do
> nothing silently. Why complicate things?"*

0868 built the on-request transient road correctly. But it wired bit2
(`ANNOT_SHOW_TRAN`) onto the SAME content class as bit1 (`ANNOT_SHOW_VOLTAGE`) —
`annot_class_mask()` returns `ANNOT_SHOW_VOLTAGE | ANNOT_SHOW_TRAN` — so the two
bits are two switches onto ONE store. Which is why a bare bit2 paints at all, and
also why the mode no longer tells the user where the number came from.

## Measured, 2026-08-27, shipped binary + the 0868 tree, paint by SVG export

**Direction 1 — a transient's numbers relabelled as operating-point node voltages.**
Fixture `/tmp/a3m` (lab_pin `d`, 5-point transient, graph, cursor B at 3 ns). Three
keystrokes after using the new mode:

```
WU3 state=ok mask=4 PAINTED=d 3                                   <- Alt-Shift-6, correct
WU4 after Ctrl-6: mask=0 PAINTED=d
WU5 after Alt-6:  mask=2 PAINTED=d 3 sim_type=tran
WU5 status line = OP annotation ON (node voltages) -- loaded
```

`Alt-6` on a database whose `sim_type` is `tran` does **not** "do nothing silently".
It turns the transient numbers back on and labels them operating-point node voltages.

**Direction 2 — an operating point's number rendered by the TRANSIENT bit.**

```
WUA sim_type=op  annot=0 0 -1
WUA mask 1 over an OP database: PAINTED=d
WUA mask 2 over an OP database: PAINTED=d 1.234
WUA mask 4 over an OP database: PAINTED=d 1.234       <- the transient bit
WUA mask 6 over an OP database: PAINTED=d 1.234
```

**And the combined sentence describes two kinds of number when the sheet only ever
shows one:**

```
WU6 mask 6 line = OP annotation ON (node voltages + transient node voltages) -- loaded
WU9 status line (mask 4, op database) = OP annotation ON (transient node voltages) -- loaded
```

## How much of this is 0868's

Partly pre-existing: with the deliberately-ungated `xschem set cursor2_x`
(0868's Part-0 deviation, itself owed a ruling), a transient number could already be
published and then shown by `Alt-6`. What 0868 added is the **most convenient way to
load that state** — one chord — and a **third label** that now names a provenance the
render path cannot honour.

## Options

1. **One store, one provenance stamp.** Record which analysis published the current
   annotation (the engine already knows: `xctx->raw->sim_type`) and let each bit
   render only its own kind, blanking otherwise (invariant I3's blank, not a
   fabricated number). Honest; costs a stamp and a test per bit.
2. **Collapse the two bits into one** and drop the third menu entry, keeping only the
   ACTION (annotate at the cursor) as a command rather than a mode. Smallest code;
   contradicts 0868's shipped menu, which the user has not yet seen.
3. **Leave the render shared and fix only the WORDS** — one label, "Node voltages",
   with the source named in the sentence the mode mints. Cheapest; leaves `Alt-6`
   re-enabling transient numbers, which is the 0856 breach.

Recommended: **1**, and it wants the user's ruling because option 2 removes a menu
entry they asked for. ⚠ Rule debt `0868` already asks the user about the neighbouring
deviation; ask both together.
