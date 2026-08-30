# 0968 — the blanket request is emitted where it applies to every analysis, and no row renders it with a transient

**FIXED 2026-08-30** (the S4a repair pass), by the same change that fixed issue
**0966** — the two were one shape and one defect wearing two names. Found by
item S4's verification pass, reproduced first-hand by the write-up before
filing. Still **COLD** on every released ngspice, which is exactly why it needed
to be written down rather than trusted.

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

## THE FIX TAKEN: shape 2's placement, without waiting for shape 2's spelling

None of the three shapes below was taken as written. What the repair pass did
instead is simpler and settles 0966 at the same time: the blanket arm stopped
emitting a **dot-card** at all. It now emits the shape the capability probe
actually measures —

    save all @m.xz1.mzmod[*] @m.xz2.mzmod[*] …

— as a **command inside `.control`, immediately before `op`**, which is exactly
where forms b and c place theirs. `.options saveopparams` is deleted from the
tree.

That removes the deck-level problem at its root rather than guarding around it:

* the request is now scoped by POSITION, the way ngspice's save list actually
  works (sticky forward-only; `unsave` does not exist and a later `save all`
  does not reset it — both measured, ngspice-46+);
* filling `optier_ctl` is what **turns on issue 0964's reorder**, so `op` runs
  LAST in the blanket form too and nothing after it re-records the device
  numbers. Form a inherits 0964 instead of undoing it;
* it needs no new semantics from ngspice and no seventh guard, so nothing here
  is invented for an option no build implements.

The enhancement request's §4 blanket option is no longer emitted by this tree.
That is recorded on issue **0966** and is on the user's ruling queue.

**Row E16** is the row that was missing: form a rendered with a transient AND an
operating point in the same run, asserting `op` is last, that the requests sit
inside `.control` immediately before it, and that nothing device-related sits
above `.control`. **Row E18** is its structural half: no whole-run setting
anywhere in the arm. Row **E17** pins that this did not move the Outputs Value
column (issue 0967, still the user's to settle).

## Three fix shapes considered and NOT taken (kept for the record)


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

Option 1 was rejected because it makes the cheapest form unavailable in the one
configuration a real user runs, to work around a placement this tree controls.
Option 3 was rejected because a sentence about a defect is not a fix for it.
Option 2's *placement* is what shipped; only its dependency on ngspice growing a
new spelling was dropped, because the per-device wildcard the probe already
measures is a `save` COMMAND and needs nothing new.
