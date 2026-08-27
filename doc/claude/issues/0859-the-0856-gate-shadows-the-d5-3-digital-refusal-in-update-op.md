# 0859 - the 0856 gate SHADOWS the D5-3 digital refusal in `update_op()`, so four rows stopped being able to see it

**Status:** **WRITTEN AND MITIGATED**, 2026-08-27, in the same commit that landed
the [0856](0856-annotate-op-shows-a-transient-s-t-0-as-the-operating-point-silently.md)
gate. The shadowing is real and is NOT fixed — it is *witnessed*, by `BA37`. The
one open question is at the bottom.

## The measurement

`src/save.c` `raw_reader_table[]` has exactly ONE digital entry —
`{"vcd", vcd_read, 1}` — so `raw_is_digital()` is true for `sim_type` `"vcd"`
and for nothing else. `"vcd"` is neither `"op"` nor `"dc"`, so the ISSUE 0856
gate lower down in the SAME function refuses a VCD too, with the **identical
observable**: `return 0`, `ngspice::ngspice_data` left unset, nothing on the
schematic.

`backannot_refuse_digital()`'s only distinguishing output is a CIW echo behind
`if(has_x)` plus a `dbg(0)` line on stderr, neither of which an in-process
headless row can read.

**Consequence:** rows BA32, BA33, BA34 and BA35 of
`tests/headless/test_backannotate_digital.tcl` — whose whole job was to catch
the D5-3 digital refusal being deleted — stay **GREEN** with that refusal gone.

## What was done about it in the landing

`BA37`, a SOURCE witness modelled on the existing BA98: it scans `int update_op()`
in `src/save.c` with string ops only, skipping comment lines, and asserts that
`raw_is_digital(` and `backannot_refuse_digital(` are present as CODE and appear
**BEFORE** the 0856 gate's `sim_type, "op")`. Golden `{1 2 1 digital}`.

⚠ **`BA37` IS SENSITIVE TO BOTH GUARDS, NOT ONLY THE DIGITAL ONE**, and a
sabotage crew must read its *got* value rather than only its colour. Measured
2026-08-27: deleting the 0856 gate reds BA37 at `{1 2 0 digital}` (third term
falls), while deleting the D5-3 digital refusal would red it at `{1 0 1 gate}`
(second and fourth terms fall). The two sabotages are therefore still
distinguishable, but "BA37 is red" alone does not name which guard went. An
earlier prediction table listed BA37 as staying green under the 0856-gate
sabotage; that prediction was wrong and this note replaces it.

The **order** term is the load-bearing half: the digital refusal is what MINTS
the user-facing sentence (RULING D5-4, one place, rendered by callers). Reorder
the two guards and the 0856 gate answers first, the sentence is never minted, and
a user who points **Op Annotate** at a `.vcd` gets silence instead of an
explanation. Nothing else in the tree would notice.

## The same shadowing hits 0836 — and the mechanism is a BACKSTOP, not an earlier catch

Fixture `L` of `tests/headless/test_zero_point_raw_0836.tcl` is a zero-point
**TRANSIENT**, so rows R4d-R4g and R4l no longer isolate the 0836 zero-point
guard. The rows that DO isolate it are the zero-point **OPERATING POINT** ones —
R2\*, R5a-R5j, R7\* — which the 0856 gate lets through. No coverage was lost;
the attribution changed.

⚠ **AN EARLIER DRAFT OF THIS SECTION HAD THE ORDER BACKWARDS**, and so did the
comment on those rows. Both said a zero-point transient is *"turned away one
guard earlier, before the zero-point test it was written for is ever reached"*.
That is wrong, and it matters, because this issue's whole product is a
**DO-NOT-REORDER** rule on these guards — a reader who trusts an inverted
description could "fix" the order and silently cost the user the digital CIW
sentence.

Source order in `update_op()`, measured 2026-08-27:

    save.c:2096   digital refusal   (D5-3)
    save.c:2154   zero-point refusal (0836)
    save.c:2240   op/dc gate         (0856)

The zero-point guard is **FIRST**. Proved empirically rather than read off the
line numbers, since the two refusals mint different sentences — a zero-point
transient emits 0836's own text and the 0856 line never appears for it:

    points=0, vars=2, datasets=1 sim_type=tran
    backannotation: '.../zp_tran.raw' holds no simulation points yet -- ...
      update_op=0

So the correct statement is: **0836 catches fixture L first, and the 0856 gate is
a LATER BACKSTOP** that keeps R4d-R4g and R4l green when the 0836 guard is
deleted, because it answers with the same observable one guard further down.
Same conclusion, opposite mechanism.

## Open

Whether the digital CIW sentence deserves a real behavioural row on the display
arm (which needs child/display machinery `test_backannotate_digital` does not
have), or whether the source witness is the right level of evidence here.
