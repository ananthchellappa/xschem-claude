# 1653 — the Calculator answers confidently where the answer is meaningless: `dBm` of zero, and `groupDelay` of a magnitude

**STAMP:** `v1 claim=open tree=81cd51db stamped=2026-10-04 fix=none open=2`

Status: **OPEN**, found 2026-10-04 by the crew that first checked the four C-route compositions'
numbers against independent arithmetic (PLAN 5.3). Both items were found *while* establishing that
all four compositions are numerically correct — they are not errors in the arithmetic, they are
places where a correct computation is handed an operand it cannot check and returns a number anyway.
Area: `calc::catalogue`'s route-C rows in `src/calculator.tcl`; `case LOG10` and `case AVG` in
`plot_raw_custom_data()` and `mylog10()` in `src/editprop.c`.

Neither item is a regression and neither was introduced by the Calculator: both are properties of
shipped engine helpers that the Calculator is about to make reachable by one click (PLAN 5.1 wires
all 60 route-P and route-C catalogue rows to the expression buffer). That is why they are worth a
decision now rather than later — today a user has to type the expression by hand, and after 5.1 the
same result is one click from the function browser.

## Item 1 — `dBm` of any non-positive sample is exactly `-320`, with nothing said

`dBm`'s composition is `log10() 10 * 30 +`. The `LOG10` opcode calls `mylog10()`, which is four
lines in `src/editprop.c`:

```c
double mylog10(double x)
{
  if(x > 0) return log10(x);
  else return -35;
}
```

So any sample that is zero or negative leaves the composition at `-35 * 10 + 30`, i.e. **exactly
`-320`**, and an undriven `ac` column that reads back the magnitude floor of `1e-35` gives
`-319.9999999218161`. Nothing distinguishes either from a genuine `-320 dBm` reading, which is a
value an instrument could legitimately report. A node whose power touches zero therefore puts an
unflagged cliff in the user's wave, and a reader who scales the Y axis to it sees a plausible floor
rather than a missing measurement.

⚠ **`mylog10()` is NOT Calculator-local and must not be changed as though it were.** It is the
helper the graph's own logarithmic axes use — `src/callback.c` calls it for the marker readout, the
cursor readouts and the log-axis transforms, at ten sites — so the `-35` floor is what keeps a log
plot of a signal that touches zero from running off to negative infinity. **Raising, lowering or
`nan`-ing that floor changes what every existing log-axis plot draws**, which is a far larger
surface than one catalogue row. Any fix that touches `mylog10()` needs the same door-by-door
treatment issue 1650 needed, and the cheap shapes that do not touch it are: refuse in the
Calculator when the operand reaches the floor, or say so on the status line, or leave it and
document the sentinel.

**What is already pinned:** two rows of band `CE14` in `tests/headless/test_calc_engine.tcl` (in
`hcases`, so on the counted arm) assert the `-320` behaviour as it stands, so whichever way this is
ruled, a silent drift is visible.

## Item 2 — `groupDelay` and `rmsNoise` name their method but not their operand

The one-line help text a user reads on hover comes from the catalogue's sixth field.
`groupDelay`'s says the phase slope in degrees per Hz, negated; its composition is
`cph() deriv() -360 /`. But `cph()` is a one-argument operator over whatever is on the stack, and it
cannot tell a phase column from a magnitude column. So selecting a magnitude and clicking
`groupDelay` returns **a plausible number from nonsense input, with no refusal** — measured on the
committed fixture at `5.148010370184515e-07`, which is the right order of magnitude for a group
delay and is meaningless.

`rmsNoise`'s help has the same gap: *"Noise integrated over a frequency band"* does not say that the
operand must be a noise density in V/√Hz. Its composition computes `sqrt(∫y² dx)`, which is correct
for a density operand and wrong by a square for a V²/Hz one.

⚠ **`dBm`'s own help text does NOT have this gap** — it names its operand as power in watts — so the
house style already distinguishes the two, and this is an inconsistency among four sibling rows
rather than a missing convention.

Three shapes, with what each costs:

* **(a) Name the operand in the help text**, as `dBm` already does. Cheapest, consistent with the
  sibling row, and makes a sentence a user already reads true instead of merely incomplete. It does
  not stop the nonsense answer; it tells the user what the function is for.
* **(b) Refuse when the operand does not look like the required quantity.** The engine cannot know
  this — a column of numbers carries no units — so any test would be a heuristic on the column's
  *name*, which breaks the moment a user computes a phase into a temporary. A heuristic refusal that
  is sometimes wrong is worse than no refusal, because it blocks correct work.
* **(c) Leave both.** Defensible on the grounds that a measurement tool trusts the operator, which
  is how the reference tools behave.

**Recommendation: (a) for both rows, and explicitly not (b).** The wording is user-facing, so the
new sentences are collected for ratification rather than shipped unreviewed; the house style for
this surface is terse, with acronyms in uppercase.

## Why these are filed together

One shape, twice: a correct computation handed an operand it cannot validate, returning a number
that looks like a measurement. The remedies differ — item 1 is a sentinel value that may want a
refusal or a sentence, item 2 is a sentence that may want to name an operand — but the decision in
both cases is *how honest should the tool be when it cannot tell*, which is one conversation and not
two.

## Outstanding

1. **Item 1 — what should happen when `dBm` (or any `log10()` composition) reaches the `-35`
   floor?** A Calculator-side refusal, a status-line note, or a documented sentinel. ⚠ Whatever is
   chosen must not change `mylog10()` itself without treating the graph's ten log-axis call sites as
   part of the surface.
2. **Item 2 — should `groupDelay`'s and `rmsNoise`'s help text name their operands?** If yes, the
   two new sentences need ratifying alongside the stage's other user-facing copy.

## Related

* Issue **1650** — the same `plot_raw_custom_data()` point loop, and the same lesson that a shared
  engine helper's behaviour is a property of every door that reads it, not of one caller.
* `doc/claude/calculator_batch/PLAN.md` phase 5 rows 5.1 and 5.3; the numbers behind both items are
  band `CE14` of `tests/headless/test_calc_engine.tcl`.
