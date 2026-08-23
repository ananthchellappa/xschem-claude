# 0636 — the gate-off OP-card nudge fires on EVERY `op` netlist, for everyone, with no opt-out

Status: **FIXED 2026-08-23** by the 0617+0618 crew — **status E, a ratification is
owed** (the question is at the bottom of this section).

## BEFORE (Measure agent, verbatim)

```
[] ASE: device operating-point parameters (gm, gds, vth, ...) were NOT saved in this
   deck. Tick Outputs > Save All > Save device OP parameters to annotate them (issue 0617).
have op_annot::save_cards in a bare session: 1
nudge #1 / nudge #2 / nudge #3  ->  TOTAL NUDGES IN ONE SESSION, SAME CELL: 3
```

## AFTER

`TOTAL NUDGES IN ONE SESSION, SAME CELL: 1`.

## Decision D6 (L3 — user-visible, ratification owed)

Implemented as this issue's own "cheapest defensible fix": `set_ne
ase_op_card_nudge 1` beside the `ase_eng_notation` precedent, a once-per-session latch
keyed on the design `lib/cell/view` via `ase::op_cards_nudge_ok`, and
`ase::op_cards_nudge_reset` as the test seam.

Two shapes matter and are pinned by tests:

* the latch is consulted **last and only** where the nudge is about to be echoed, so a
  state that fails the `op`-analysis gate does not silently consume its cellview's one
  turn (the two gates are **nested**, not `&&`-ed) — row **F19e**;
* it is keyed **per cellview**, not globally — a different cell still nudges.

`test_ase_final`'s F19 had to be reshaped: measured, `ase::netlist` fires three times
in one session on that cell (F6, F9's `ase::run`, and F19's own call) and F19 armed its
collector around the **third**. It now resets the latch first. F19b (a second netlist
nudges 0), F19c (`::ase_op_card_nudge 0` nudges 0), F19d (the default is 1) and F19e
are new siblings. Sabotage: forcing `op_cards_nudge_ok` to return 1 reds exactly F19b
and F19c, as predicted.

*Rejected:* every-netlist (shipped — no opt-out, advertising an opt-in feature the user
may have deliberately declined). *Rejected:* removing it (re-opens 0617 in silence).

### ⚠ THE QUESTION OWED TO A HUMAN

> Should the gate-off OP-card nudge fire **once per session per cellview** (what now
> ships), on **every netlist** (what shipped before — measured at three identical lines
> in one session about one cell, into a pane and a log people diff), or **not at all**
> unless asked?

---

## Original filing follows

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
