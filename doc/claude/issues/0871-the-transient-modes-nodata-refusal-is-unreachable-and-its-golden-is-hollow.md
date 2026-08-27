# 0871 — the transient mode's `nodata` refusal is unreachable, and its byte-exact golden tests a string no program state can produce

**Status:** 🔴 **OPEN — measured, NOT fixed.** Filed by the A3 write-up, 2026-08-27,
from the adversary leg of the 0868 run. Class: **dead code + a hollow golden.**

Owner: issue **0868**; `cadence::annot_tran` in `utils/annot_mode.tcl` (~:596), row
**V17** in `tests/headless/test_op_annot.tcl` (~:11630).

## The measurement

`cadence::annot_tran` refuses in four states before it publishes. The third gate and
the fourth ask the SAME question:

* `annot_tran` returns `noraw` when `xschem raw loaded` is `< 0`, and
  `src/scheduler.c:10567` is literally
  `Tcl_SetResult(interp, my_itoa(sch_waves_loaded()), TCL_VOLATILE);`
* `backannotate_at_time()` (`src/callback.c:1758`) returns 0 — the only way
  `xschem annotate_at` can answer 0 — on exactly `if(!xctx || sch_waves_loaded() < 0)`.

So by the time `annot_tran` calls the verb it has already proved the verb cannot
answer 0. **The `nodata` arm is unreachable.**

Probed on the one state that could plausibly separate them — a raw whose `schname` no
longer matches the open sheet:

```
Z2 after loading a DIFFERENT sheet: raw loaded=-1
Z2 annot_tran -> noraw
```

## What it costs

1. Row **V17**'s fifth byte-exact golden
   (`cadence::_annot_tran_msg nodata 3e-09 B`) pins a sentence no user can ever be
   shown. It is a real string test of a real proc, so it is not wrong — it is
   **hollow**, and it makes the mode look better covered than it is.
2. Issue 0868's write-up and `doc/claude/specs/op_annotation.md` §4.9 both say "four
   refusal states and one success state". There are **three** refusal states the user
   can reach.

## Options

1. **Delete the arm and the sentence**, and say in the spec that the engine's
   "nothing to annotate against" answer is unreachable from this path because the
   caller has already proved a database is attached. Cheapest; loses nothing a user
   can see.
2. **Keep it as a belt-and-braces arm** and mark it explicitly unreachable-by-design
   in both the proc and row V17, so the next reader does not go looking for the state
   that produces it.
3. **Make it reachable** by moving the `noraw` test to a narrower predicate than
   `sch_waves_loaded()` — but no measured user state wants that, and issue **0684**
   is already open on exactly which predicate "are THIS session's results attached"
   should be. Do not pre-empt it here.

Recommended: **2** now (one comment, no behaviour change), folded into **1** or **3**
whenever 0684 is ruled.
