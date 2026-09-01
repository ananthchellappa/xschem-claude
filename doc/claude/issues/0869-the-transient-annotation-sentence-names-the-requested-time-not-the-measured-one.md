# 0869 — the transient annotation sentence names the time the user ASKED for, not the time the number was measured at

**Status:** ✅ **FIXED 2026-08-27** by the A3h hardening pass — Tcl only, no C change.
See *The fix* at the foot of this file, and note that **option 1 below, this issue's
own recommendation, is measurably WRONG and was NOT taken**.
Originally filed by the A3 write-up, 2026-08-27,
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


---

# The fix (A3h, 2026-08-27) — option 2, against the EFFECTIVE time

## Option 1 — this issue's own recommendation — is measurably wrong

Option 1 says *"resolve the annotated point's own x (`annot_p` indexes it) and render
that"*. Measured over the whole sweep on the 5-point fixture, that column is the last
one below:

```
requested | annot_p annot_x sweep | v(d) | EFFECTIVE t | the sample's own x (option 1)
-5e-9     | 0 -5e-09 0            | 0    | 0           | 0
5e-10     | 0 5e-10 0             | 0.5  | 5e-10       | 0
2.5e-9    | 2 2.5e-09 0           | 2.5  | 2.5e-09     | 2e-09
3e-9      | 2 3e-09 0             | 3    | 3e-09       | 2e-09
4e-9      | 3 4e-09 0             | 4    | 4e-09       | 3e-09
4.5e-9    | 4 4.5e-09 0           | 4    | 4e-09       | 4e-09
99e-9     | 4 9.9e-08 0           | 4    | 4e-09       | 4e-09
```

At a requested **3e-09** the painted number is **3**, which genuinely IS the
interpolated value at 3e-09 — row V2 measures exactly that. Option 1 would caption it
*"t = 2e-09"*: **a fresh D5-1 breach in the opposite direction**, and it reds row V2's
premise. In range the shipped arithmetic returns the value AT the requested time; the
sentence is dishonest ONLY out of range.

## What landed instead

**Option 2 — name both, only when they differ**, against the *effective* time (the
`EFFECTIVE t` column above), which needs no C change.

* `cadence::_annot_tran_msg` gains a **sixth state**, `okclamped`, and an optional
  fourth parameter `req`. The five shipped sentences are byte-identical and the five
  shipped callers still pass three arguments.

  > `Transient annotation at t = 4e-09 (cursor B at 4.5e-09, outside the data -- holding the boundary sample)`

  It names the MEASURED time first — that is the number's provenance — then the
  cursor letter, then where the cursor actually is, then why the two differ. RULING
  D4-4 made visible instead of hidden.
* New `cadence::_annot_tran_efft` reads the effective time through **three already
  shipped calls**: `xschem raw annot` → `{annot_p annot_x annot_sweep_idx}`,
  `xschem raw list` → the column names, `xschem raw value <sweep> -1` → the sweep's
  own value at the annotated point. Every step caught; a failure returns `{}` and the
  caller mints today's shipped `ok` sentence rather than inventing a time.
* `cadence::annot_tran` picks the wording with a **relative** comparison,
  `abs(te - t) > 1e-6 * (abs(t) + abs(te) + 1e-30)`. **Never exact float equality**:
  the effective time is read back through the single-precision `cursor_b_val[]` array,
  so an in-range request returns a few ULPs away and `==` would caption every ordinary
  annotation as clamped.
* The state name returned is still **`ok`** in both cases — `okclamped` is a wording
  of the same success, not a different outcome. Rows V11/V12/V13 read that return.

## The rows

* **V26** — the composing row this issue said was missing. Cursor B at 4.5e-09
  against a last sample of 4e-09; **one** check asserting the state, the PAINT (SVG
  export, FAQ Q52), the effective time, and the sentence byte for byte.
* **V26b** — the in-range control at 3e-09. Reds a clause appended unconditionally,
  and reds option 1.
* **V27** — the sixth golden beside V17's five, plus all five re-asserted through the
  widened signature. V17 itself untouched.

Tcl sabotage, run 2026-08-27, no build needed:

| variant | mutation | reds |
|---|---|---|
| S15 | `annot_tran` always mints the shipped `ok` | **V26** |
| S15b | the tolerance comparison inverted | **V26b**, and also V26, V11, V12, V13, V28, V31 — see 0876's table |

## Debt

The clamped sentence is **new user-facing wording the user has not ratified** — owed
as `rule 0869` in `tests/headless/owed.sh`, with the two rejected alternatives
(option 1 above; and naming only the effective time, which loses where the cursor is)
recorded there.
