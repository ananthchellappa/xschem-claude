# 1289 — DD-6's display narrowing blanks a `derived` row whose operand it removed

**Filed by:** item **B2a-2**, 2026-09-03. Found by the Implement agent while
building DD-6, confirmed on a live fixture by B2a-2's adversary. **FILED, NOT
FIXED — it needs a ruling, not a guess.**

**Status:** open. **A property of ruling DD-6 itself**, not of any one
implementation, so it survives B2a-2's revert and **binds whoever re-does DD-6**.

---

## 1. The seam

`op_annot::text` builds its `vars` dict **inside the params loop**. Ruling
**DD-6** makes that loop iterate the new display key (`shown`) instead of
`params`. So a `derived` row — whose expression is evaluated over `vars` — can
name an operand that the display list no longer contains, and the variable is
simply **not there**.

Measured by the Implement agent on this binary:

```
op_annot::_evalrow {$gm/$id} with vars={id 1e-5}  -> "" , _finite 0   (renders BLANK)
op_annot::_evalrow {$gm/$id} with both present    -> 20.0
```

Confirmed by the adversary on a live one-instance fixture:

```
params  {{id ids 0} {gm gm 1}}   shown {{id ids 0}}   derived {{gm_id {$gm/$id}}}
-> the sheet draws `id` and `gm_id`, and `gm_id` can never carry a value
```

while the deck **still saves `gm`**, because `_cards_for` correctly stays on
`params`.

## 2. Why it matters and who hits it

**IHP registers exactly such rows** (`gm/id`, `ft`) in
`ihp-sg13g2/sg13g2_procs.tcl`. So the first user to delete `gm` from the
annotation list in item **B5**'s dialog gets a `gm_id` row that is permanently
blank — on a run where `gm` was saved and *is* in the raw.

The behaviour is **honest** under invariant **I3** (blank, never a plausible
wrong number, never a raise), which is why it is filed rather than treated as an
emergency. But it is a real user-visible seam: *deleting one row silently
disables another*, with nothing on screen saying so.

## 3. The three options, none of them ratified

1. **Leave it.** A derived row whose operand is hidden goes blank. Honest,
   surprising, and invisible.
2. **Evaluate `vars` over `params` (the union) and *display* over `shown`.**
   The derived row keeps working when its operand is merely hidden. Costs one
   extra loop at draw time, in a proc that runs **per instance per redraw** from
   C (`src/actions.c:2088`).
3. **Narrow `derived` too**: a derived row whose operands are not all shown is
   itself not drawn. Nothing blank, nothing surprising, but Delete on `gm` now
   silently removes `gm_id` from the sheet as well.

**Recommendation: option 2.** `derived` is a *display* concept already — it
appears in no `.save` card — so its operands are naturally read from what the
run computed rather than from what the sheet draws, and it is the only option
under which the sheet never shows a row that cannot carry a value. Option 3 is
defensible and needs the user's word, because it makes one Delete remove two
rows.

**This is a `rule` debt on the user's queue.**

## 4. Acceptance for whoever takes it

* A `derived` row whose operand is in `params` but not in `shown` behaves as the
  ruling says, with a row that names the ruling.
* IHP's `gm/id` and `ft` rows are the fixture — they are the shipped case.
* Whatever is chosen, `op_annot::text` gains **no** new `xschem` call and **no**
  new raise site at draw time (issue **0447**).
