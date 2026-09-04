# 1320 — with both class lists owned and EMPTY, `params` now becomes the full declaration, and `_claims` flips 0 → 1

**Filed by item B2e's Verify-C (adversary) pass, 2026-09-04; re-measured
independently by the write-up agent before filing. Measured, NOT fixed.**
Status: **open — a deliberate consequence of ruling DD-4, deck-only, no pixel
moves; filed because it is stated NOWHERE in the change and because it
falsifies a note the batch was carrying.**

---

## 1. What was measured

Two `type=` tokens of one class, registered with the three-row PDK list, then
**both** class lists owned and set EMPTY, then `apply`:

```
pre_params    = {id ids 0} {gm gm 1} {gds gds 1}
   set_list class mos annotation {}
   set_list class mos summary    {}
   apply
post_params   = {id ids 0} {gm gm 1} {gds gds 1}     <- HEAD gave {}
post_shown    =                                       <- empty, as HEAD
post_declared = {id ids 0} {gm gm 1} {gds gds 1}
```

Driver: `/tmp/claude-1000/-home-analog-dev-xschem-claude/scratch_B2e_wu/wu.tcl`.

Because `op_annot::_claims` gates the hierarchy walk on a non-empty `params`, it
flips **0 → 1** for these types, and `op_annot::_cards_for` emits **three**
`.save` cards where HEAD emitted none.

## 2. Why it is correct

It is ruling **DD-4**, stated in DD-4's own words: *"Delete removes a parameter
from what is DRAWN. It never changes what the simulator is asked to save,"* with
its price stated in the same ruling — *"a user who deletes a row to make the
deck smaller does not get a smaller deck."* B2e's `_merge_declared` makes that
guarantee hold for **every** ownership shape, including this one. Saving an
operating-point parameter is measured free (spec §3.3).

**No pixel moves.** Traced into the C: the D-6 declutter gate is
`annot_instance_annotated` = `annot_overlay_gate` **AND**
`annot_block_has_value`, and `op_annot::text` returns the empty string in this
state (`shown` is present and empty, which is *not* absent — it draws no rows).
So the instance is not decluttered and nothing on the sheet changes. The effect
is confined to the deck.

## 3. What it falsifies, and why that matters

Item B2e's scout carried this risk note:

> *"AFTER THE FIX, `params` IS STILL DERIVED FROM THE TWO LISTS, so a settings
> file that owns BOTH lists EMPTY still yields zero `.save` cards."*

**That is now false.** The note was written before the DD-4 third input to the
union existed, and it is the exact shape an adversary was told to attack. It is
recorded here so the next reader does not re-derive it from the stale sentence.

## 4. The adjacent case, also measured, also unstated

A **hand-written** `declared {}` beside a non-empty `params` — reachable only by
writing the key by hand, since `op_annot::_declare` never produces that pairing
— makes `apply` shrink `params` to the owned lists, dropping the PDK's rows and
their `.save` cards. Issue **1315 §4** records the *neighbouring* case (a
non-empty descriptor registered with no `params` at all is stamped with the
empty declaration, deliberately, so a later apply cannot get its own union
recorded as the type's declaration) but not this one.

## 5. How it is reached

From `op_param_lists::set_list` and from a settings file, **not** from the UI:
ruling **DD-10** makes Delete refuse to remove the last row, and that refusal
lives in `src/rdw.tcl` (currently reverted), not in `set_list`, which accepts an
empty list — store-suite row **W3** golds that round trip.

## 6. Options

1. **Say it and leave it.** Add the sentence to the three PDK `_procs.tcl`
   paragraphs and to spec §4: *an empty owned list narrows the sheet to
   nothing and leaves the deck at the PDK's declaration.* **Recommended** — it
   is DD-4 behaving as ruled, and the only defect is that nobody wrote it down.
2. Treat *both lists owned and empty* as a special case that empties `params`
   too. Contradicts DD-4 for the one input shape where the user was most
   explicit, and re-opens the Add-cannot-put-it-back hole for it.
3. Refuse the state in `set_list`. Moves DD-10's UI refusal into the store,
   which is where a later caller of `apply` cannot inherit the defect — but it
   is a ruling change (DD-10 is about a *button*), not an implementation choice.

## 7. Still open

Whether option 1's sentence lands with the next PDK-file edit, and whether §4's
hand-written `declared {}` deserves a guard at all. Nobody is assigned.
