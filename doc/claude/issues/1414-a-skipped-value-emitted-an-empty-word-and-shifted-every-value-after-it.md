# 1414 — a skipped value would have emitted an empty word and shifted every value after it

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C1** of Stage 3 of `doc/claude/ase_analyses_batch/` — the slot grammar and the
expander.

## Why Stage 3 needs a grammar before it needs fields

Stage 3's subject is that **the form lies**: `ase::ui::chana_options` collects free-text name/value
pairs, round-trips them through the state file, renders them in the Arguments column, and **never
emits them**. Measured on the tree as it stands:

```
THE PANE SHOWS : tran 10n 200u
THE DECK SAYS  : tran 10n 200u
deck mentions uic / tstart / tmax : 0 0 0
```

The fix is to make those values real fields. But every field Stage 3 adds is **optional** — `tstart`,
`tmax`, `uic` — and the expander had no way to express one. This commit is that grammar.

## The defect a naive optional slot would have shipped

⚠ **Joining an empty element produces `tran 1n 10u  0.2n` — a DOUBLE SPACE — and ngspice reads the
next number as `tstart` rather than as `tmax`: rc 0, no message, and a different simulation.** A
skipped slot must therefore contribute **nothing at all**, not an empty word. Row **EM1** fences it.

⚠ **And EM1 only works because its fixture puts a literal AFTER the optional slot.** With the
optional slot trailing, a body that emits an empty word and then trims produces a **byte-identical**
answer — the sabotage changes neither the string nor its length. The adversary caught that; the
fixture emits `tran 1n 10u END`.

## `kind bool`, and why the word belongs to the adapter

⚠ **MEASURED on both binaries: `uic 0` and `uic=0` both turn `uic` ON, silently.** The token's
*presence* is the truth and its value is ignored. A bool that emitted its stored `0` would switch
the feature **on** while the form showed it **off** — this stage's own defect, inverted.

So a bool slot emits the adapter's `when_true` word when the row says exactly `1`, its `when_false`
word otherwise (usually nothing), and **never the stored value**. ⚠ **The word is the adapter's, not
the field's name**: a schema that hard-coded *"present means on"* could not express a simulator whose
off-state needs a word of its own, and the word a simulator wants is **content**.

## Two contracts kept that a tidier signature would have broken

⚠ **The two-argument form still raises on a missing required slot.** Row **Q2** of
`test_ase_simcaps_0948` calls `ase::analysis_expand` with **two** arguments against each shipped
template and asserts `{ok RAISES RAISES RAISES}` — it is the row that proves a row-free reader was
needed at all. Making the field table a mandatory third argument turns its `ok` into a raise and
reds the suite that owns the seam, for a reason unrelated to its subject. The field table is
therefore an **optional** third argument.

⚠ **`ase::analysis_cards` passes `fields` behind a `dict exists` guard, and the guard is not
decoration.** Measured: **seven of the eleven** shipped entries — `noise tf pz sens disto sp pss` —
carry **no `fields` key at all**, because Stage 2 registered them probe-only. A bare
`[dict get $e fields]` raises for every one, and `ase::ui::arg_summary`'s catch (row D8j) would
swallow that into a silently degraded pane — **the exact failure this stage exists to delete,
re-created by the fix for it.**

## `ase::analysis_schema_errors` — a pure reader, never called at load

It answers every way a simulator's registry contradicts itself: a slot a template consumes and the
entry never describes (so the user can never fill it), and a field the form offers that no template
consumes (**Stage 3's defect, stated as a property of the registry** rather than found by running a
bench).

⚠ **It never raises and is never called at load time.** `ase.tcl` is sourced from inside
`Tcl_AppInit()`, so a raise there does not surface in a dialog — it **aborts xschem at startup**
with no layers, colours, menus or undo set up (issue **0663**'s arm). A registry validator that runs
at load is the one shape this must not take.

The shipped ngspice registry answers `{}` — it is self-consistent today.

## Verification

`test_ase_core` **289 → 298** (section **EM**, 9 rows).

⚠ **Every EM fixture registers its own backend**, so the shipped registry, the 104 committed
`.state` files and every deck golden are unmoved **by construction** rather than by hope. Row
**EM8** asserts the four shipped deck lines are byte-identical.

**Six sabotage passes:** an empty word for a skipped optional (EM1, EM2, EM3); a bool emitting its
stored value (EM2, EM3); the bool word hardcoded to the field name (EM3); the default never applied
(EM5); the `fields` guard dropped (aborts a block — the raise fires before EM7 reaches it, which is
itself the defect being shown); `analysis_slots` not stripping sigils (EM6, EM9).

## Related

* **1406** — `ase::analysis_cache_clear`, which is why a fixture registry is live immediately. ⚠ A
  sabotage that mutates ngspice's own entry **in place** must call it explicitly, or it silently does
  nothing.
* **0663** — startup aborts on an unsourceable file.
* **1401** — the registry these slots belong to.
