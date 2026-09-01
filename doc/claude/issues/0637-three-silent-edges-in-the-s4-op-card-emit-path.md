# 0637 — three silent edges in the S4 OP-card emit path

Status: **OPEN — measured, not fixed.** Filed by the S4 write-up agent,
2026-08-23. Items 1 and 2 found by the S4 adversary (Verify-C) and re-measured
before filing; item 3 is the adversary's unmeasured observation, recorded as
such. Related: 0617, 0633, 0620.

All three share one shape: the emit path does something defensible but does it
**quietly**, in a feature whose entire purpose is that under-delivery must never
be silent.

---

## 1. A truthy-but-not-`1` gate value is silently OFF

Both gate sites compare literally:

* `src/ase.tcl:522` — `if {[ase::state_get $state save_op_params 0] ne {1}}`
* `src/ase.tcl:3368` — `if {[ase::state_get $state save_op_params 0] eq {1}}`

so a state carrying `save_op_params true` (or `yes`, or `on`) — hand-edited, or
written by some future dialog, or copied from another tool's convention — turns
the feature off. MEASURED:

```
C) save_op_params=true -> echoes:
   ASE: device operating-point parameters ... were NOT saved in this deck.
   Tick Outputs > Save All > Save device OP parameters to annotate them.
D) save_op_params=true -> cards in deck: 0   render echoes: 0
```

Note the second-order confusion: the only report is the gate-off nudge, which
tells the user to tick a box they believe they have already ticked.

There is precedent for exactly this class of bug in this subsystem: the S7/S8
notes record that `set annot_show true` silently means *off* because the mask is
an integer. The fix is the same shape — normalise once (`string is true -strict`,
or a single `ase::op_cards_enabled` predicate both sites call) rather than
comparing to `1` in two places. Note the OFF value must remain `{}` and not `0`:
`save_op_params` is in `ase::omit_if_empty`, which is what keeps 104 committed
`.state` files byte-identical.

## 2. The echo's card count assumes an `@`-prefixed devpath

`ase::op_cards_capture` counts what it is about to hand over with

```tcl
foreach l [split $block "\n"] { if {[string match {.save @*} $l]} { incr n } }
```

The **append** loop in `render_deck` is unconditional and verbatim (correctly —
invariant I1 and rule R4 say nothing may rewrite a card on the way through), so a
future descriptor whose `devpath` template does not begin with `@` would have its
cards emitted **and simulated** while the pane reported `0 device OP save card(s)
added to the deck.` Under-reporting, not under-delivery — but in the one channel
a user consults to find out whether the feature did anything.

No shipped descriptor is affected today: sky130, gf180mcu and sg13g2 all produce
`@<letter>.…`. The fix is to count what the loop appends (any non-blank,
non-comment line, or lines matching `^\.save\s`), not what it guesses they look
like.

## 3. A cache HIT is analysis-independent, so OP cards can ride into a TRAN deck

The capture cache is keyed on the **exact netlist text**, which is deliberate and
is what defeats the wrong-basis hazard (see the S4 landing note). But netlist
text does not change when the user switches which analysis is enabled. So:
netlist with the gate on under `op`, switch to a `tran` analysis, press **Run**
(not *Netlist and Run*) → the artifact text is unchanged → cache **hit** → every
OP card is carried into a transient deck, where each becomes a full per-timestep
vector.

Not a correctness break — it is literally what the gate asks for, and ngspice
will save them — but on the user's own 31-FET bench that is 468 extra transient
vectors, and 0620's table projects ~3000 on a 500-device block. **Nobody has
measured the raw-size or runtime cost**, and this item is recorded as an
observation rather than a measurement.

If it is to be handled, the least surprising treatment is a report rather than a
refusal: one `ase::echo` line when the block is carried into a deck whose enabled
analyses do not include `op`.
