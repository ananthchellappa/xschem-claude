# 1760 — Calculator: a number argument takes a measurement, and six verbs anchored on an event

**STAMP:** `v1 claim=fixed tree=2c2c2093a stamped=2026-11-24 fix=taken open=3 by=driver-1760`

Asked for by the user on 2026-11-24, as a hand-off written by the session that works in
their design workarea (dated 2026-11-21, with an addendum of 2026-11-22), and built the
same day on a private Xvfb with openbox. Three things are open, listed under "Open".

## What was asked

The user: *"Can you use [the hand-off document], with the fixture beside it [...], to
implement the suggested enhancements to calculator's repertoire?"*

The hand-off's case: dissecting an enable overshoot needed three numbers off one
transient, the time a comparator tripped, a drive voltage at that instant, and the charge
that still flowed into the drive node after it. ngspice `meas` rows give all three (`WHEN`,
`FIND ... WHEN`, `INTEG FROM TO`). The Calculator gave the first two only with the anchor
time typed in by hand, and the third wrong by a factor of two. It proposed:

- **A.** a number argument accepts a nested measurement: `value(w, cross(...))`;
- **B.** `integBetween(wave, from, to)`, the area between two X values with the wave
  interpolated at both;
- **C.** `valueWhen(wave, trigger, level, edge, nth)`;
- **D.** (addendum) `ymax`, `ymin`, `xmax`, `xmin`, with an optional window.

All four are built.

## The two gaps, as measured before the change

On the hand-off's results file (a transient of 4107 points), with this tree's Calculator at
`2c2c2093a`, through `calc::eval_texts`:

| expression | before | now | ngspice's own row |
|---|---|---|---|
| `cross(trigger, 0.6, 1, falling)` | 2.0195113e-6 | the same | 2.01951e-06 |
| `value(node, 2.01951e-6)` (anchor typed by hand) | 1.98603 | the same | |
| `value(node, cross(trigger, 0.6, 1, falling))` | refused: *value: X point must be a finite number (...)* | 1.98630 | 1.98630 |
| the same on the output node | refused | 0.92402 | 0.92402 |
| `integ(i*(time>2.01951e-6)*(time<2.1e-6))` | 4.7727e-14 | the same | |
| `integBetween(i, 2.01951e-6, 2.1e-6)` | unknown function | 9.38168e-14 | 9.38168e-14 |
| `integBetween(i, cross(trigger, ...), 2.1e-6)` | | 9.3626e-14 | (its limit is the rounded 2.01951e-6) |
| `valueWhen(node, trigger, 0.6, falling, 1)` | unknown function | 1.98630 | 1.98630 |
| `ymin(out, 10u, 12u)` / `xmin(...)` | unknown function | 0.951350 at 1.00135e-5 | 9.51350e-01 at 1.00135e-05 |
| `ymax(out, 12u, 14.9u)` / `xmax(...)` | | 1.35352 at 1.20525e-5 | 1.35352e+00 at 1.20525e-05 |
| `ymax(i, 2u, 2.5u)` / `xmax(...)` | | 2.66787e-4 at 2.01781e-6 | 2.66787e-04 at 2.01781e-06 |

The nested `value` lands on ngspice's `FIND ... WHEN` number where the hand-typed anchor
was 0.3 mV off: the anchor is no longer rounded to six digits on the way.

An independent pass over the same file (Python: its own reader, a trapezoid over the list
of points with the two interpolated ends) gave the crossing, both values, both charges and
the four extrema to twelve digits or better.

**Why the gated integral is half.** The gate `(time>t0)` zeroes every sample at or before
`t0`, so the interval that straddles the limit is counted as a triangle from zero. At a
sharp event that interval carries most of the area. The method is the defect, not the
sampling, and every `integ()` of a gated product shares it. `integ` itself is unchanged: its
catalogue help now points at `integBetween`.

## What was built

### A number argument may hold a measurement (spec R423)

A number argument of a measurement verb takes, besides a number: a measurement call, or
arithmetic that holds at least one (`cross(...) + 80n`, `value(w, 5.9u)*0.9`), nested up to
eight calls deep. It works in the argument dialog's field, in a call typed in the buffer and
evaluated with Eval, in an ASE-L Outputs row, and in a call that is an operand of an
expression. Examples the hand-off named, now answering on its bench:
`overshoot(out, 0, value(out, 5.9u), 0)` and a `settlingTime` whose start is a `cross`.

- The shape is checked before any read by the one predicate both doors share
  (`calc::arg_field_bad` → `calc::nest_plan`). A text that was a number is read first and
  by the reader it always had, so nothing that was accepted changed.
- The value is measured at the head of `calc::aq_arg_invoke`, the one place every
  measurement of every door is invoked from, inside that call's database bracket
  (`calc::nest_resolve`). The nested call therefore reads the same database as the call
  around it, and its full-precision number replaces its text.
- A refusal from inside names the outer verb and the field: *"value: X point: cross takes 4
  arguments."* before a read, *"value: X point: Cross: there is no 1st falling crossing of
  that level in this sweep."* after one.
- R208d's refusal of a signal with no analysis, and ASE-L's save list, both descend into
  the nested calls (`calc::nest_calls`): a run saves what the row will read.

### `integBetween`, `valueWhen`, `ymax`, `ymin`, `xmax`, `xmin` (spec R424 to R427)

Six catalogue rows (Special Functions, route T, scalar), six procs, three argument specs.
All six read their samples through the one shared series door (`calc::series_of`, now also
asked for a DC sweep) by way of `calc::span_read`; none opens an engine door of its own.

- `integBetween(wave, from, to ?, dataset?)`: the trapezoid of every interval, each cut at
  the limits with the wave's interpolated value there (`calc::area_between`, pure).
- `valueWhen(wave, trigger, level, edge, nth ?, dataset?)`: `cross` on the trigger, then
  `value`'s interpolation on the wave. Identical, to the last digit, to
  `value(wave, cross(trigger, level, nth, edge))`.
- `ymax` / `ymin` / `xmax` / `xmin` `(wave ?, from ?, to??)`: over the whole sweep, or a
  window either end of which may be left out or left empty (`ymax(w, , 3m)`).
- A typed call may leave out the trailing arguments `calc::meas_typed_defaults` names (the
  dataset, the window) and no others: `cross(w, 0.5)` is still *"cross takes 4 arguments."*

### Found on the way and repaired

1. **A limit a rounding hair past the end of the sweep was refused.** The committed test
   fixture is a linearized transient that ends at 0.009999999999999995 s, not 0.01, so
   `integBetween(w, 0, 10m)` and equally the existing `value(w, 10m)` answered *"outside
   the sweep"*. A limit within a billionth of the sweep's span of either end is now that end
   (`calc::span_snap`). ngspice's own transient ends on its stop time, so this bites
   resampled data. Row EVB6.
2. **The function list's wheel step over its scrollbar was "identical to Tk's own" only
   because the list was too short to tell.** Six more entries gave the list an eleventh row
   and row S25 of `test_calc_skeleton` went red: one notch read 0.2108 (the product's 3
   units) against 0.2870 (Tk's 5). With the old list both stopped at the end of its 2.9 units
   of travel and read 0.2206. The vertical step is now Tk's own 5 units, so the two are the
   same command; the spec's R112a carries the correction beside the struck sentence.

## Builder's choices, for the user to rule on

Each is user-visible and none was in the request's own words.

1. **Arithmetic is accepted only around a measurement.** `cross(...) + 80n` is taken; `+3u`
   or `2*1u` alone is still *"must be a finite number"*. Reason: every text that was refused
   before stays refused, so no existing row or habit moves. Taking plain arithmetic too is a
   one-line change.
2. **Only the six new verbs have arguments that can be left out.** The older verbs keep one
   arity each, by the earlier decision that a short call would hand the verb a default the
   user never saw.
3. **An empty argument means "that end of the sweep"**: `ymax(w, , 3m)`. It is what the
   dialog writes when To is filled and From is not.
4. **An extremum over a window counts the wave's value at the window's own limits**,
   interpolated. ngspice's `MAX ... FROM TO` reads the samples inside only. The two differ
   when the wave is still climbing at a limit that falls between samples; on the hand-off's
   bench they agree on every row above.
5. **`integBetween` refuses rather than adjusts**: `from` not below `to`, a limit outside the
   sweep, a sweep that turns back on itself. The hand-off asked for the first two.
6. **The forgiven rounding hair also applies to `value`**, an existing verb.
7. **The function list scrolls 5 units a notch vertically, where it scrolled 3.**
8. **Wording and labels**: the refusals open *Integral:*, *Value when:*, *Extremum:*; the
   dialog fields are *From (X)*, *To (X)*, *Trigger (RPN)*, *Trigger level*; `valueWhen`
   takes its wave from the buffer and asks for the trigger; its argument order is the
   hand-off's (level, edge, nth), not `cross`'s (level, nth, edge).

## Evidence

- `tests/headless/test_calc_event_verbs_1760.tcl`, new, registered in `hcases`: 55 checks on
  both arms, on the committed ngspice-written fixture (every expected number derived by hand
  from its deck) and on a DC sweep that runs downward, written by the suite.
- Band PG14E of `tests/headless/test_calc_pick.tcl` (display arm): a real press on Eval with
  a nested call in the buffer, in a real Calculator window on a real viewer.
- The suites that enumerate verbs took the six on by their own derivations and went red until
  each was enlisted: `test_calc_measure` (bands MT10, MT11, MT13, MT21, MT28; MT10's
  partition of "who reads samples how" gained a fifth class, with its own refusing-stub row),
  `test_calc_skeleton` (S23, S24, S25, S28), `test_calc_widgets` (CW14),
  `test_calc_scratch_reuse` (SR5: the engine step the arithmetic uses is reached only from
  inside a bracket, by three asserted hops).
- Two tip-of-the-day questions, topic *Measurements* (the Calculator topic is full).

### Breaks, measured 2026-11-24

Each line of the change that alters behaviour, removed or inverted alone in a copy of the
tree, and the new suite run on it (the wheel step against `test_calc_skeleton` on a
display). Every one turns at least one row red; with the file restored the suite is green
and its checksum is the good one's.

| break | rows red |
|---|---|
| nested text handed to the verb unevaluated | EVA1 EVA2 EVA3 EVA4 EVA5 EVA8 EVA11 EVA12 EVB3 EVC2 EVD5 |
| the shape check does not ask the plan | EVA1 to EVA11, EVA13, EVB3 EVC2 EVD5 |
| the unqualified-signal descent removed | EVA9 |
| the save-list descent removed | EVA10 |
| the depth bound removed | EVA11 |
| arithmetic with no measurement accepted | EVA7 |
| the translator's opening words not dropped | EVA6 |
| the nested number rounded to 8 digits | EVA2 EVA3 EVC2 |
| arithmetic read back at 8 digits | EVA2 |
| compose refuses any comma in a number argument | EVA13 |
| integBetween: the limits not interpolated | EVB1 EVB11 |
| the sweep's direction check removed | EVB11 |
| interval ends not ordered (a downward sweep) | EVB11 EVB12 |
| integBetween: the order of the limits not checked | EVB9 |
| integBetween: a limit outside the sweep not refused, upper / lower | EVB6 / EVB6 |
| integBetween reads dataset 0 | EVB5 EVB10 |
| the rounding hair not forgiven | EVA5 EVB5 EVB6 |
| the DC sweep not read | EVB12 EVD8 |
| valueWhen ignores the edge | EVC1 EVC2 EVC4 |
| valueWhen reads the wave in dataset 0 | EVC3 |
| valueWhen: nth 0 not refused | EVC5 EVC6 |
| extremum: the lower limit, the upper limit not a candidate | EVD2 EVD4 EVD8 EVD11 / EVD2 EVD4 EVD11 |
| extremum: the last of equal values wins | EVD8 EVD11 |
| extremum: value and place swapped | EVB6 EVD1 to EVD8 |
| extremum: the order of the limits not checked | EVD9 EVD10 |
| extremum: a limit outside the sweep not refused, lower / upper | EVD9 / EVD9 |
| an older verb (`cross`) given arguments that can be left out | EVA6 EVA13 EVE1 EVE2 |
| a dataset may not be left out | EVB1 to EVB8, EVB12, EVC1 to EVC5, EVC7, EVE1 EVE3 EVE6 |
| a blank limit refused | EVD1 EVD3 EVD4 EVD7 EVD8 EVD9 EVE4 EVE5 |
| the wheel step back to 3 units | S25 of `test_calc_skeleton` |

Two breaks left every row green on the first pass and each got a row: a lower limit outside
the sweep (rows EVB6 and EVD9 had driven the upper end only), and the dropped opening words
(row EVA6 had compared against the product's own stripper).

## Not checked

- The user's own screen: the dialog of the six verbs and the function list's eleventh row
  were seen only by suites on a hidden display.
- The hand-off's addendum quotes `ymax` of a difference of two nets as 3.033 V at 2.008e-6 on
  a results file of that day. That file is gone. On today's file of the same bench the
  Calculator and the Python pass agree to the last digit: 2.9275 V at 2.0079e-6.

## Open

1. **The user's ruling** on the eight builder's choices above (owed-ledger rule `1760`).
2. **A measurement inside a measurement's WAVE argument is still refused**
   (*"a measurement inside value's argument is not supported"*). The gated idiom is not
   needed for a window any more, but `ymax(w*(time>cross(...)))` does not parse. Not built.
3. **A `.meas` sidecar value cannot feed an Outputs row** (the hand-off's "noticed, out of
   scope": a `MEAS("name")` reader). With nesting, `cross(...)` stands in for the sidecar's
   time in the case that prompted it. Not built.
