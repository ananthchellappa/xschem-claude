# 0968 — the blanket request is emitted where it applies to every analysis, and no row renders it with a transient

**FILED, NOT FIXED.** Found by item S4's verification pass, reproduced
first-hand by the write-up before filing. Status: **OPEN**, and **COLD** — no
released ngspice can reach the arm it is in, which is exactly why it needs to be
written down rather than trusted.

Design of record: `doc/claude/specs/op_annotation.md` §4.3b. Sibling of issue
**0966** (the same arm, a different defect: the *shape* is not the shape the
probe measured).

## What the item asked for

> Three tiers for getting device operating-point data into the raw … and applied
> to the **OPERATING-POINT write ONLY, never to a transient**.

Form **c** honours that: issue **0964** moved its requests inside `.control`,
immediately before an `op` that now runs last, so the transient carries none of
them. Form **b** honours it too: the device names ride the operating-point
`write` line and the transient's `write` line carries none.

**Form a does not, and cannot in the shape it is emitted in.**

## Measured, on this tree, today

Rendering the same op+tran state three times, once per form (`.control` lines
indented, deck-level lines flush):

    ===== FORCED FORM a =====        ===== FORCED FORM c =====
      .save all                        .save all
      .options saveopparams            .control
      .control                           set appendwrite
        set appendwrite                  tran 1n 5n
        op                               write <raw>
        write <raw>                      save all @m.xz1.mzmod[id] …
        tran 1n 5n                       op
        write <raw>                      write <raw>
      .endc                            .endc

`.options` is a **deck-level** statement: whatever it asks for, it asks for it
of the whole run, not of one analysis. And the blanket arm does not get 0964's
reorder — that is keyed on the in-`.control` request list being non-empty, which
form a never fills — so `op` still runs first and the transient still runs after
it with the option in force.

So on the day a simulator honours `.options saveopparams`, a user with an
operating point and a transient enabled gets **issue 0964's defect back**, in
the form that was supposed to be the cheapest of the three: every device's
operating-point numbers recorded at every time point of the transient. On the
user's own `tb_bandgap` that cost was measured at **+74.9 MB and +4.08 s**.

## Why no test can see it

Every committed row that renders the blanket form does so on an
**operating-point-only** state (`AN_OP`):
`tests/headless/test_ase_optier_0963.tcl` rows **E1** (counts `@` characters —
there are none either way), **E2** (counts deck lines — a deck-level `.options`
is one line whatever else runs) and **A1** (the `/bin/sh` stand-in, which
returns a canned results file regardless of what analyses the deck asks for).
Nothing renders form a with a transient enabled, and nothing could judge the
result if it did: there is no simulator anywhere that implements the option, so
a behavioural row would be asserting against a semantics nobody has written
down.

## The enhancement request already knows about this, and asks for the cure SECOND

`doc/claude/ngspice_enhancement_request_op_parameter_saving.md` is the only
specification this option has, and it is not silent on the point — §5.3 measures
exactly this cost, on 500 devices × 6 parameters:

    .op,   1 point         +0.03 s     +107 KB
    .tran, 10,068 points   +8.6 s      +242 MB

and then asks for per-analysis scoping as a **secondary** item: *"If a blanket
option could apply to the operating-point analysis only … that whole cost would
disappear."* So the primary ask, as written, is a deck-level option that applies
to every analysis — which is precisely what form a emits, and precisely what
issue 0964 has just finished removing from form c.

That is the reason this is filed rather than guessed at. Until the request's
secondary item is answered, there is no scoped spelling to emit, and inventing
semantics for an option no build implements would be the optimistic guess the S4
item forbids elsewhere.

## Three fix shapes, none taken here

1. **Refuse form a when more than one analysis is enabled** — a seventh guard in
   `ase::op_save_tier`, `{c reason multianalysis}`, so the blanket is used only
   where a deck-level option can do no harm. Cheapest, testable today with no
   simulator, and it costs a blanket-capable build nothing it cares about (a
   one-analysis run is where the blanket wins anyway).
2. **Ask the enhancement request for a `.control`-scoped spelling** — a command
   rather than an option, so it can be placed exactly where forms b and c place
   theirs. That is the shape that would let form a inherit 0964's reorder.
3. **Accept it and say so**, in the same sentence that already tells the user
   which form the run used.

Option 1 is the recommendation; it is a guard, not a redesign, and it turns a
cold arm into one a row can hold. It is out of scope here because it is a
behaviour choice on a surface the user has an unratified ruling open against
already (rule debt **0963**).

## Ready-made rows for whoever takes it

* render form a with `AN_BOTH` and assert the deck carries no request that
  outlives the operating point — under option 1, that the form demotes to c
  with reason `multianalysis` and the sentence says so.
* the control: form a with `AN_OP` still renders exactly as it does today
  (E1/E2 unchanged), so the fix cannot be "switch the blanket off".
