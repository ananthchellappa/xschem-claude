# 0513 — `raw switch`'s operating-point publish gate reads the PREVIOUS database, so switching into an OP usually does not annotate

**Status:** FIXED 2026-09-01, on `fluid-editing` after the `annotate` merge.
Both arms (`switch` and `switch_back`) now ask `xctx->raw` for BOTH halves —
`allpoints` and `sim_type` — which is the shape the neighbouring `select` arm
has always had.

**Found again by a user, from the other end.** They reported that after using
Alt-Shift-6 (transient annotation at the waveform cursor) there was no way back
to annotating the operating point. The immediate cause was on the Tcl side
(issue 1242's second half), but the reason `xschem raw switch` could not be
leaned on to do the job was this: switching from a 20500-point transient into
the 1-point operating point behind it in the same file published nothing.

**Three rows had been waiting for this.** `test_results_select`'s SEL195 carried
the note *"⚠ WHEN 0513 IS FIXED, SEL195 INVERTS — it will publish. Update it
there; it is written as a measurement of today's engine, not as a rule."* It has
been updated there. `test_zero_point_raw_0836` row 7 was built on this straddle
as its THIRD DOOR into `update_op()` with a zero-point database — that door is
now shut, since a zero-point database has `allpoints == 0`; 0836's own guard
stays as defence in depth for the two doors that remain. `test_op_annot` N10b
and `test_annot_stale_0684` F21 were pinning a sentence this defect made the
tool say, and both inverted; see below.

**A false sentence went with it.** With the publish gate broken, pressing `6` on
a loaded operating point produced *"The loaded results do not include an
operating point, so there are no device values to show. Load a different results
file from Waves > Op Annotate, then press again."* — about a file that **is** an
operating point and that the editor already had open. Measured on N10b's own
fixture: before the press `annot_p` is -1 with an empty array; after it,
`annot_p` is 0, the array holds 5 entries and `@m.xmzz1.mzz[gm]` reads `0.0001`,
the value in the file.

Regression rows: `tests/headless/test_annot_op_behind_tran_1242.tcl` R10/R10b
drive `xschem raw switch` DIRECTLY — not through the Tcl rungs, which publish
for themselves and would go green over this defect. Sabotage-verified: restoring
the straddle reddens R10b and nothing else.

---

*Original report follows.*

**Status when filed:** OPEN. Measured on branch `fluid-editing` at `226302f9`
(the results batch base) with a **pristine** binary — this predates the batch and
is not caused by it.
**Area:** the `switch` and `switch_back` arms of `xschem raw`,
`src/scheduler.c` (`grep -n 'only update_op() if switching into a 1-point OP or DC' src/scheduler.c`).
**Found:** 2026-08-19, results batch item 3, while giving `xschem raw select`
the same follow-up (spec `results_selection.md` R301d).
**Severity:** silent wrong-looking result — the schematic keeps the *previous*
operating point on it, or none, after the user switches to an OP database.

---

## What

Both arms are written like this:

```c
Raw *raw = xctx->raw;                       /* captured at the TOP of the arm */
...
} else if(argc > 2 && !strcmp(argv[2], "switch")) {
  ...
  ret = extra_rawfile(2, ...);              /* xctx->raw now points ELSEWHERE */
  /* only update_op() if switching into a 1-point OP or DC */
  if(ret && raw && raw->rawfile && raw->allpoints == 1 &&
     (!strcmp(xctx->raw->sim_type, "op") || !strcmp(xctx->raw->sim_type, "dc"))) {
    update_op();
  }
```

`raw` is the database that was current **before** the switch. `xctx->raw` is the
one after. So the gate asks *"did the database I am leaving have one point?"*
and *"is the database I am arriving at an op or a dc?"* — two halves of two
different questions. The comment says what was meant, and the code does not do
it.

Consequence: switching from any multi-point database into a one-point operating
point does not publish it. Switching from a one-point database into a
multi-point `dc` publishes *that*, which `update_op()` then has to refuse on its
own.

## Reproducer

A one-point op raw and a three-point transient raw, both read under the same
cell:

```tcl
xschem raw read op.raw op          ;# ngspice::get_voltage o1 -> ?  (read never publishes)
xschem raw read an.raw tran        ;# 3 points, now current
xschem raw switch op.raw op        ;# rc=1, and the gate does not fire
puts [ngspice::get_voltage o1]     ;# -> ?      EXPECTED: 1.5
```

Measured 2026-08-19 on the pristine binary, and pinned as
`SEL195-X-switch-does-not-publish-here-0513` in
`tests/headless/test_results_select.tcl`.

**The corrected gate was measured too, in the same state**: `xschem raw select
op.raw op` from that same 3-point transient publishes `1.5`
(`SEL194-X-select-publishes`), because the `select` arm tests `xctx->raw` after
the call. Replacing its gate with the `switch` arm's expression verbatim — one
sabotage, one rebuild — turns SEL194 red and nothing else. So the difference is
the expression, not the verb.

## Why it was not fixed on the spot

Results batch item 3 owns `xschem raw select`, not `raw switch`. **R111** is
binding for that batch — `raw switch` keeps its behaviour — and changing what a
shipped verb publishes to the schematic is its own change with its own audit.
The new `select` arm therefore gates on `xctx->raw` **after** the call (spec
R301d) and this arm was left exactly as found.

## Fix sketch

Test the arriving database in both halves, in all three arms that carry the
expression (`switch`, `switch_back`, and any future one):

```c
if(ret && xctx->raw && xctx->raw->rawfile && xctx->raw->allpoints == 1 &&
   xctx->raw->sim_type &&
   (!strcmp(xctx->raw->sim_type, "op") || !strcmp(xctx->raw->sim_type, "dc"))) {
  update_op();
}
```

Note the extra `xctx->raw->sim_type` NULL guard: the shipped expression
dereferences it without one, and a slot with a NULL `sim_type` is reachable by
index (landmine L6 of `doc/claude/specs/results_selection.md`).

A check belongs beside `test_results_select.tcl`'s SEL193/SEL194, which pin the
same behaviour for `select`.
