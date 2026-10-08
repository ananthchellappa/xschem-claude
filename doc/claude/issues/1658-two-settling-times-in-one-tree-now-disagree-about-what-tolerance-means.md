# 1658 — Two settling times in one tree now disagree about what "tolerance" means

**STAMP:** `v1 claim=open tree=223cd46a stamped=2026-10-07 fix=untried open=1`

## The disagreement

| surface | field | band |
|---|---|---|
| the Calculator's `settlingTime` | `Tolerance %` | `final ± (tol/100)·abs(final − initial)` |
| ASE-L's `ts` measure template (`ase::meas_templates`) | `tol` | `vlo = final − tol`, `vhi = final + tol` |

The Calculator's reading is the **user's own ruling**, 2026-10-07: *"Tolerance is not clear if that
means % or absolute, etc. It should always be % percent."* Asked percent of what, they chose the
**step**.

ASE-L's `ts` template was **commissioned by the same user** and still computes an absolute band. So
typing `1` into one surface and `1` into the other now asks two different questions of the same
waveform.

## Why this is filed and not fixed

**Spec R418b predicted it in its own words**, as the reason it chose absolute in the first place:

> `ase::meas_templates`' `ts` template in `src/ase.tcl` — commissioned by the same user — already
> asks for the final value and the tolerance as two required real fields and computes `final ± tol`.
> **Two settling times in one tree disagreeing about that would read as a bug.**

That reasoning is still valid; only its conclusion was overruled. Which means the disagreement is
now real and known, and the one thing that must not happen is for it to be discovered later as a
mystery.

**It is not fixed here because it is a different surface and the user did not mention it.** Three
things make it their call rather than internal engineering:

1. **ASE-L's `ts` becomes a `.meas` statement in a deck**, not a Tcl computation — the band is
   handed to the simulator. Whether a percent belongs in a deck-level measure is a question about
   what the simulator and the user's own scripts expect, not about the Calculator.
2. **The template asks for `final` and `tol` and has no `initial`**, so percent-of-step would need
   the same fourth field there, on a form that is part of a saved session state. That is a state
   migration, however small.
3. Percent-**of-the-final-value** is a third possible answer for a deck template specifically, since
   a `.meas` has no cheap way to read a step.

## The question for the user

> You've ruled that the Calculator's settling tolerance is a percent of the step. **ASE-L's own
> settling measurement still takes an absolute tolerance.** Do you want them to match — which costs
> ASE-L's form the same extra *Initial value* field and changes what a saved session's `tol` means —
> or do you want the deck-level one to stay absolute, because it becomes a `.meas` card the simulator
> reads?

My recommendation is **leave ASE-L absolute for now and label both** — the Calculator's field is
already `Tolerance %` and ASE-L's can read `Tolerance (absolute)`, which removes the ambiguity
without a state migration. Matching them is right if you'd rather have one meaning; it is just not
free.

## Where to look

- `calc::settlingTime` and its `calc::fn_argspec` arm in `src/calculator.tcl`
- `ase::meas_templates`' `ts` arm in `src/ase.tcl` (the `switch` setting `vlo`/`vhi`)
- spec R418b in `doc/claude/specs/calculator.md`, which carries both the ruling and the retracted
  reasoning
