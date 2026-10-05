# `riseTime`, `delay`, `dutyCycle` — the implementation contract

**Written by the driver 2026-10-02**, before any 7.3 code exists. PLAN row 7.3. Companion to
`CROSS_CONTRACT.md`, which stays in force — every rule there (D1–D12) applies to these verbs too,
and where this file and the spec differ, **the spec wins and this file is the bug**.

The user asked for these three by name (*"Proceed with riseTime, delay, dutyCycle"*), out of the
seven the spec layers on `cross`.

## 1. What the user ruled, and what each ruling removed

Two questions were put to the user one at a time. Both answers **simplified the code** rather than
complicating it, and both are behaviour to match rather than design choices of ours.

### R415 — `riseTime`'s reference levels are SUPPLIED, never derived

> *"Cadence makes you supply them."*

So there is **no** waveform-derived default: no min/max search, no first/last-sample rule, no
settled-value estimator. **Omitting them is a REFUSAL**, which lands on the disposition `cross`
already has (D7) — a malformed request is refused, a well-formed one with no answer reports absent.

What this removed, and it was going to be the most delicate part of the verb: picking 100% off a
ringing edge. With the swing supplied, the thresholds are simply percentages **of that supplied
swing**, and the verb becomes arithmetic over `cross`. Recon confirmed the engine could not have
helped anyway — `min()`/`max()` are two-argument clamps and `avg()` is a running mean, so a
percent-of-own-swing verb would have had to evaluate into its own column and scan in Tcl.

### R416 — `dutyCycle` returns a WAVE, one value per cycle

> *"A wave — one value per cycle."*

Not the first period, not the mean. The faithful answer, and it has a consequence worth stating:
**`dutyCycle`'s default now needs the waveform destination that `cross`'s `nth = 0` is already
waiting on** (`CROSS_CONTRACT.md` D8), and `frequency` will want it too. Three verbs behind one
missing piece makes that destination the measurement layer's critical path.

> ⚠⚠ **BOTH SENTENCES ABOVE ARE REFUTED — SUPERSEDED, NOT DELETED (R419/R420, 2026-10-02).**
>
> **The clause is wrong.** `cross`'s `nth = 0` was never waiting on a waveform destination: the user
> ruled it answers *"just a list of crossing times like cadence does"* (**R419**), so it waits on a
> **list** surface (spec R606's `Table`). `dutyCycle`'s default does need a waveform destination, but
> not *that* one. The claim it rested on — that the reference tool returns a waveform for `nth = 0` —
> began as an unasked parenthetical in `CROSS_CONTRACT.md` D8 and is corrected there.
>
> **The count is wrong twice over**, and the driver's first correction of it ("two verbs instead of
> three") was wrong too. There are **two destinations**: **three** callers behind the waveform one —
> `calc::dutyCycle_scalar`'s default cycle, **`calc::delay` with `nth = 0` on either side**, and the
> unbuilt `frequency` — and **one** behind the list one, `calc::cross_scalar`. The verb the driver
> dropped was `delay`. The real set was established by enumerating the enclosing proc of every
> `listdefer` call site mechanically, which is the only method that has been right about this number;
> `calc::riseTime` with `nth = 0` **raises** rather than deferring and is issue **1639**, open.
>
> ⚠ **1639 IS NOW FIXED (2026-10-03) AND THE WAVEFORM SET IS FOUR, NOT THREE.** `calc::riseTime`
> defers behind the same shared sentence, so the callers behind the waveform destination are
> `calc::dutyCycle_scalar`'s default cycle, `calc::delay` with `nth = 0` on either side,
> `calc::riseTime` with `nth = 0`, and the unbuilt `frequency`. The count is left wrong above on
> purpose — the paragraph is about a count having been wrong twice, and correcting it in place would
> delete the evidence. **Do not quote any number here; band `WD9` of
> `tests/headless/test_calc_wave_dest.tcl` derives the set every run, which is the only method that
> has been right about it.**
>
> **And "critical path" no longer describes anything**: `calc::wave_dest` shipped with R419/R420, so
> what the three waveform callers are still waiting on is the **click** (R410/R412, phase 5), not a
> destination.

**How 7.3 ships without being blocked on it**: the proc returns the full per-cycle series; naming a
cycle gives a scalar end-to-end today; the default wave case returns its data with the **UI surface
deferred behind the same message `cross` uses**. When the destination lands, the callers behind it
light up rather than needing rework.

⚠ **R420 then made the X axis an ARGUMENT**, which this file could not have anticipated and which the
driver should have proposed rather than asked: *"Make it an option to the function. Default can be
time the cycle started. Other choices you gave can be supported with non default values to this
argument."* `calc::dutyCycle` takes `?<xaxis>?` — `start` (the default), `number`, `mid` — and its
answer carries a parallel `sweep` series. Full reasoning in `DESTINATION_CONTRACT.md` §6.

## 2. Decisions the driver makes, and what each rests on

### T1. All three are PURE DELEGATES on `calc::cross`. No evaluate-once helper.

This reverses the driver's own plan, on measurement. The intent was a shared "evaluate once, scan
many" helper so a verb needing two levels would not evaluate twice. Recon measured where the time
actually goes, on a 100 000-point column:

```
raw add + raw del            0.21 ms
one bulk raw values read    10.3  ms
ONE nth=0 scan             296    ms      <- 27x a read
```

So hoisting the evaluation saves ~20 ms out of ~300. On the committed 101-point fixture the whole
question is 191 µs against 106 µs. **The optimisation buys almost nothing and the simple shape is
correct**, which recon established four independent ways: 92 level/nth/edge combinations
bit-identical through both routes; the engine deterministic even when the vector array grew between
the two adds; 340 mint/add/read/delete cycles leaving `xschem raw list` byte-identical with no
`__calc_tmp*` leaked; and two independent evaluations yielding bit-identical X columns.

⚠ **And the clever shapes break a registered fence.** Recon characterised ten candidate shapes
against row **SR5** of `test_calc_scratch_reuse`: shapes A, B, E, I and J′ keep it green; **C, C2,
D, F, H′ and G redden it**. The trap is a verb reading a named vector it did not itself create.
Delegating to `cross` is shape A — the simplest one, and green.

**This is the second performance intuition this batch has had refuted by measurement** (the first
was D10, where the faster per-point read turned out to be `%.8g` and could not meet the fixture's
own tolerance). The rule that keeps falling out: *a performance number is not a reason on its own,
and the shape you were going to optimise may not be where the time is.*

### T2. `riseTime` anchors the high crossing AFTER the low one

A ringing edge can cross the low threshold three times before crossing the high one once, so "first
rising crossing at each level" can straddle two different transitions and report a rise time that
never happened. **Find the low crossing for the requested occurrence, then take the first high
crossing strictly after it.** Correct on a clean edge, safe on a ringing one. If this turns out to
be something the reference tool specifies differently, it becomes the next single question to the
user rather than a silent difference.

> **CORRECTION, 2026-10-04 — the rule above is narrower than its own purpose, and the
> implementation now follows the purpose.** "The first high crossing strictly after it" guards the
> shape this paragraph describes — the start level crossed several times before the end level once
> — and is blind to the complementary one: a transition that reaches the start level, **fails** to
> reach the end level and falls back. There the first end crossing after it belongs to a **later
> transition**, and both `riseTime` and `slewRate` answered a confident number with `ok=1` for a
> transition that never happened, which is exactly what this paragraph says must not occur.
> Measured on the committed fixture, `{v(sq) v(ramp) *}` with `lo` 0 and `hi` 10: the unbounded
> pairing returned a rise time **longer than the whole edge** for the first occurrence and kept a
> point in the series for a transition that never happened. `calc::transition_end` now requires the
> end crossing to fall **before the next start crossing**, at one site for every caller — a count
> row `MT18/H` re-derives from the interpreter's own parsed bodies rather than a number stated
> here. Band `MT18` of `tests/headless/test_calc_measure.tcl` drives it and builds the sabotage.
>
> ⚠ **The change is LARGEST at the default percentages, which is the spelling a user reaches by
> opening the argument dialog and pressing go** — and the first publication of this correction named
> a hand-picked pair where it is smallest. At `pctlo`/`pcthi`'s own defaults on the same column one
> excursion only reaches the end level, so the series collapses to a **single point** and every
> ordinal naming a transition that does not reach the end level turns from a measured number into
> an **absence**. No figure for either pair is given here: row `MT18/E` drives both — the second read off the verb with `info default` — and
> asserts the two against each other every run, which is the only form in which a number of this
> kind survives.
>
> ⚠ This necessarily changes the worked example above: on a trace that wobbles across the start
> level, the earlier wobble crossings now answer an **absence** and the measurement is anchored on
> the last start crossing before the end one. The two situations are the **same data** — several
> start crossings then one end crossing — so no rule reading only the crossing lists can separate
> them, and reading the samples is forbidden to these verbs by T1. That disposition is unruled and
> is recorded as hole `H12` of the suite; it is the single question this paragraph already said
> would arise.

### T3. `delay` takes a full edge specification PER SIDE, and a negative answer is legitimate

Level, direction and occurrence are each independent per side — not one shared level, not one shared
`nth`. And when the second edge precedes the first, **the answer is negative and is returned**, not
refused.

That follows from a standing project rule rather than taste: ADE-L is a **floor**, so a restriction
ADE-L does not have is a defect. Refusing a negative delay would be exactly such a restriction.

### T4. `dutyCycle` reports a FRACTION, never a percent

The shipped catalogue help already promises *"Fraction of a period the signal spends high"*.
Returning `30` against that text would make shipped user-visible prose false, which is this batch's
most-repeated failure. `0.3`, and the fixture's own deck confirms it independently: a PULSE of 1 ms
width plus 0.2 ms edges is 1.2 ms high in a 4 ms period, and recon measured `0.3000000000000002`.

A period is **rising crossing to the next rising crossing** at the given level; the high time is the
falling crossing inside it minus the opening rising one. A trailing partial period is **not** a
period and is excluded — and that exclusion is a row, because silently including it would report a
duty cycle for a cycle that never completed.

### T5. The sharp edge 7.3 owns: `nth = 0` on a level nothing crosses

`calc::cross_scan`'s `nth = 0` arm returns success with an **empty list** for a level no sample
reaches — `ok 1 absent 0 value {}`. That is **declared and fenced**, not a defect: row `CX8` pins it
by name. But `dutyCycle` is its first real caller, and an empty crossing list reaching the period
arithmetic is exactly how that contract turns into a raise. **Guard it at the point of use**, and
make the guard a row rather than a comment.

### T6. A new suite, `tests/headless/test_calc_measure.tcl`, in `hcases`

PLAN row 7.7 names it. It re-derives the fixture deck's values independently rather than sharing
`test_calc_cross.tcl`'s helpers, and it does **not** introduce a `calc_common.tcl` — a shared
fixture helper would mean one wrong derivation reddens nothing in both suites. Registered in the
**same commit** as the code, per the standing rule. Trailer delta derived from `summarize_all`'s own
arms over a real capture, never reasoned from registration shape.

### T7. Scope boundary

**In**: the three measurement procs, their refusals, the per-cycle series, the catalogue rows going
live, and the suite. **Out**: `slewRate`, `settlingTime`, `overshoot`, `frequency` (PLAN 7.3's other
half); the waveform destination (R416's dependency); and the UI wiring — `calc::fn_click` has no
route for a T-route verb, so **a shipped `riseTime` is not clickable**, exactly as `cross` is not.
Phase 5 owns R410/R411/R412. A green 7.3 is a working measurement layer, not a reachable feature,
and must not be reported as one.

## 3. Prose this stage owes

**Spec §7.2's `settlingTime` and `overshoot` rows carry route `T`, not `T (on cross)`**, while the
same section's implementation-order sentence and `CROSS_CONTRACT.md`'s opening both list all seven
as layered on `cross`. A table disagreeing with the prose beside it, in the one artefact nothing
re-runs. Harmless for 7.3 — `riseTime`, `slewRate`, `delay`, `dutyCycle`, `frequency` and `freq` are
all explicitly `T (on cross)` — but it will mislead whoever picks up the other two.
