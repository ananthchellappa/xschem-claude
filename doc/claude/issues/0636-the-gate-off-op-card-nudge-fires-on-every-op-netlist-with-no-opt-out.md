# 0636 — the gate-off OP-card nudge fires on EVERY `op` netlist, for everyone, with no opt-out

Status: **OPEN — measured, not fixed. A ratification is arguably owed.**
Filed by the S4 write-up agent, 2026-08-23. Found by the S4 adversary (Verify-C),
re-measured independently before filing.
Related: **0617** (the nudge is 0617's emit-side channel), 0620 (deck cost), 0633.

## What S4 shipped

The `save_op_params` gate defaults **off** (deliberately — 468 cards on the
user's 31-FET bench, ~3000 on a 500-device block per 0620, and two committed
byte-exact deck goldens). A gate that defaults off has to be discoverable, so
`ase::op_cards_capture` echoes one line when the gate is off **and** an `op`
analysis is enabled:

```
ASE: device operating-point parameters (gm, gds, vth, ...) were NOT saved in
this deck. Tick Outputs > Save All > Save device OP parameters to annotate them
(issue 0617).
```

That is pinned green by `test_ase_final` row **F19**, and it is the right idea:
it is exactly the configuration the user reported 0617 from.

## The defect

**The condition it is gated on is always true.** `$have` is
`[info commands ::op_annot::save_cards] ne {}`, and `src/xschem.tcl:14600`
sources `op_annot.tcl` **unconditionally** at startup — so `have` is 1 in every
session, including sessions with no PDK descriptor registered and designs with
nothing annotatable anywhere in them.

MEASURED (binary md5 `fce30432968d678ab24640729569317f`, `src/ase.tcl` md5
`b82f5ba3b26d5159a2fa0ab21c7b82cc`): a bare session, a synthetic two-line
netlist artifact, a state whose design is a non-existent cell — nothing in the
picture is annotatable and no descriptor is registered —

```
A) op_annot::save_cards present in a bare session: 1
B) gate-off nudge lines: 1
   ASE: device operating-point parameters (gm, gds, vth, ...) were NOT saved in
   this deck. Tick Outputs > Save All > Save device OP parameters to annotate
   them (issue 0617).
```

So for every existing ASE user who runs an `op` analysis, **every netlist from
now on** adds one line to the ASE pane and one `#=` line to `Xschem.log`,
advertising an opt-in feature that may deliver nothing on their design — and
there is **no way to turn it off**. It is not an `error`-tagged line, but it is
still a new line in a log people diff and a pane people read.

## Why this is worth a ruling and not just a tidy

The trade is real in both directions and S4 chose one side without the user:

* **Nudging always** guarantees no user re-lives 0617 in silence — which is
  precisely the failure this feature exists to delete.
* **Not nudging** keeps every existing user's pane and log exactly as it was.

The middle grounds nobody has measured: nudge only when the design actually
contains a device with a registered descriptor (costs a walk, which is the
expensive thing the gate exists to avoid); nudge once per session; nudge once
per design; or give it a `::ase_op_card_nudge` off switch in `xschemrc`.

## The cheapest defensible fix

An `xschemrc` variable (`::ase_op_card_nudge`, default 1) plus a once-per-session
latch keyed on the design cell. Roughly six lines, and it owes a `test_ase_final`
row beside F19: *the nudge fires once, and not at all when the variable is 0*.

Not applied by the write-up agent because it changes user-visible behaviour that
Verify-A/B/C measured as shipped, and because which way to go is genuinely the
user's call.
