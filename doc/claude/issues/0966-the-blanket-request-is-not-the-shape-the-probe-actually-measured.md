# 0966 — the blanket request is not the shape the probe actually measured

**FIXED 2026-08-30** (the S4a repair pass), together with issue **0968** —
they were one shape and one change. Filed by the tier work of issue 0963, which
shipped over it.

The capability probe asks the simulator whether it can do `save @<device>[*]` —
ONE request per device, with a wildcard over that device's parameters. The
blanket tier emits `.options saveopparams` — no device named at all — because
that is the shape `doc/claude/ngspice_enhancement_request_op_parameter_saving.md`
section 4 asks ngspice for, and the shape the S4 item requires.

Choosing the second on the strength of the first is precisely the optimistic
guess the item forbids elsewhere. The clean fix is a second probe question, and
"do not change the probe" blocks it.

Harmless in practice, measured: `.options saveopparams` is silently ignored by
ngspice-46+ — exit 0, a normal results file, no warning — and no released build
answers yes to the probe anyway.


## The fix: make the emitted shape BE the probed shape

The blanket arm of `ase::backend::ngspice::render_deck` now emits, inside
`.control` and immediately before `op`:

    save all @m.xz1.mzmod[*] @m.xz2.mzmod[*] …

`.options saveopparams` is **deleted**. It is not what was probed, no released
ngspice honours it, and a dot-card cannot be scoped to one analysis — which is
issue **0968**, fixed by the same change, because filling `optier_ctl` is also
what turns on issue 0964's reorder that keeps `op` last.

⚠ **THE WILDCARD IS ONE LITERAL, `ase::cap_param_wildcard`, AND BOTH SIDES READ
IT.** The probe deck B interpolates it and the emitter appends it, so the shape
the simulator is TESTED with and the shape the deck ASKS with cannot drift apart
again. It is named `cap_` and not `op_` because row C3 of
`test_ase_simcaps_0948` unions the `ase::cap_*` family's bodies and requires the
wildcard to be findable there. Row **E15** counts the literal in the
comment-stripped file and expects exactly one.

The alternative — a second probe question — was rejected: it measures the same
capability twice and leaves two answers that can disagree, which is the defect
in a different costume.

## What a YES answer now buys, and what it costs

One request per DEVICE covering every parameter that device has, rather than one
request per device per parameter: on the shipped tb_bandgap bench, 78 entries
instead of 468 cards. Still the cheapest of the three shapes, and no longer
O(1) in the deck — which is why rows E1 and E2 were reshaped rather than left
asserting the old claim. `ase::sim_why`'s `op_tier_blanket` sentence changed
with the shape; it used to tell the user "the deck names no devices at all",
which is now false (row S12).

⚠ **xschem no longer emits the line
`doc/claude/ngspice_enhancement_request_op_parameter_saving.md` section 4 asks
ngspice for.** That request stands as a request; this tree stops emitting a
dot-card no build honours and that it cannot scope to one analysis. **On the
user's ruling queue** (`owed.sh add rule 0966`).

## Rows

`test_ase_optier_0963`: **E14** (the emitted shape is the probed shape, per
device, inside the run, immediately before the operating point, nothing left
above it), **E15** (structural: one literal), **E18** (structural: no whole-run
setting anywhere), **E1**/**E2**/**A1** reshaped, **S12** (the sentence no
longer claims the deck names no devices).
