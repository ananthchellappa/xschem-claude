# 0635 — every OP-card REFUSAL reports two sentences, and the second contradicts the first

Status: **OPEN — measured, not fixed.** Filed by the S4 write-up agent, 2026-08-23.
Found by the S4 adversary (Verify-C) and re-measured independently before filing.
Related: **0617** (the report channel this defect is *in*), **0633** (the refusal
whose message it contradicts), 0632.

## The defect in one line

When `ase::op_cards_capture` **refuses** to build the cards, it leaves the cache
empty; `render_deck` then also fires its *stale artifact* arm, so the user is
told "save the schematic and netlist again" and, on the very next line, "use
*Netlist and Run* to regenerate both together" — i.e. do the thing they just did.

## MEASURED, verbatim

Driver: a default state with `save_op_params 1`, an `op` analysis enabled and
`ase::design_is_dirty` forced to 1 (the 0633 refusal path), then
`ase::op_cards_capture` followed by `ase::backend::ngspice::render_deck` on the
same netlist text, with `::ciw_echo` renamed to collect the pane copy.
Binary `src/xschem` md5 `fce30432968d678ab24640729569317f`, `src/ase.tcl`
md5 `b82f5ba3b26d5159a2fa0ab21c7b82cc`.

```
CAPTURE ECHOES:
   [error] ASE: no device OP save cards were added — this schematic has unsaved
   edits, and walking a dirty sheet rewrites the `~` autosave backups of ancestor
   cells you never touched (issue 0632, ruling pending). Save the schematic, then
   netlist again.
RENDER ECHOES:
   [error] ASE: this deck was rendered from a netlist artifact that carries no
   captured OP save cards, so device operating-point parameters were NOT saved.
   Use Simulation > Netlist and Run to regenerate both together.
CARDS IN DECK: 0
HIT AFTER REFUSAL: 0
```

`HIT AFTER REFUSAL: 0` is the mechanism: `op_cards_hit` is what tells the two
situations apart, and a refusal leaves no record for it to find.

## Why it happens

`ase::op_cards_capture` (src/ase.tcl) calls `ase::op_cards_clear` first and then
returns early on **three** paths without storing a record:

1. `op_annot::save_cards` not available in this session;
2. `ase::design_is_dirty` — the provisional 0633 refusal;
3. `catch {::op_annot::save_cards}` raised.

The **empty-block** case was deliberately handled the other way — the record is
stored *before* the emptiness test precisely so `op_cards_hit` stays 1 and
`render_deck` does not misreport "nothing annotatable here" as "stale artifact"
(that is what test_ase_core row **C10** pins). The three refusal paths were not
given the same treatment.

## Blast radius

Reporting only. No card is emitted that should not be, none is withheld that
should not be, and no deck content changes. But it is a defect *inside* 0617's
report-what-was-not-delivered channel, which is the one thing this whole feature
added to stop silent under-delivery — a channel that gives contradictory advice
is only marginally better than one that says nothing.

Reachable on the everyday GUI path: edit a sheet, press *Netlist and Run* with
the gate on, and both lines land in the ASE pane and in `Xschem.log`.

## The fix, and why the write-up agent did not apply it

One line: store a record on the refusal paths too (`ase::op_cards_put $text {}`
after reading the artifact), or suppress `render_deck`'s stale arm when capture
already spoke during this pass. Either makes `op_cards_hit` 1 and silences the
second sentence.

Not applied because it arrived **after** Verify-A/B/C had signed off on the
shipped tree, and an unverified one-line edit to the seam they certified is
worth less than an honest issue. Whoever fixes it owes a new `test_ase_core` row
beside C10: *a refusal reports exactly one sentence*, driven through
`ase::design_is_dirty` overridden to 1 (C12's existing idiom), asserting the
render-time stale sentence is **absent**.
