# 1235 — The "that file is not there" sentence blames the copy for a setting that lives on the cell, and tells you to edit the wrong thing

**Status:** OPEN. Measured 2026-08-31 by item S7's adversary pass, re-measured
independently by the write-up agent before filing. **Introduced by item S7** — the
sentence is new in that item, so this is a defect in wording S7 shipped.

Rulings engaged: **PLAIN ENGLISH** (*"say what happened AND what the user can do about
it"*) and **D5-1** (a statement that was not measured for the thing it is displayed
next to is the defect).

## What a person reads, and why it is false

A `schematic` setting can live in **two** places: on one copy of a symbol, or on the
**cell** — the symbol's own K block, where it applies to every copy of that cell
everywhere. The new sentence only ever describes the first.

Fixture: a symbol whose K block carries `schematic=nosuchfile.sch`, one copy `xA` which
carries **no setting of its own**, and the cell's own `cellbound.sch` present. Measured
on the built binary:

```
copy xA's OWN schematic setting = <>
DESCEND rc=1 sheet=cellbound.sch currsch=1
STATUS: The copy named xA on this sheet is set to open the schematic file
        nosuchfile.sch, but that file is not there. This cell's own schematic file
        is cellbound.sch. Opened the cell's own schematic instead.
```

`xA` is set to nothing. The **cell** is. The first clause of the sentence is a
statement about the copy that was never measured for the copy.

## The advice is worse than the sentence

Captured from the question on the dev display, the closing line reads:

> To change which schematic file this copy opens, edit the copy's 'schematic' setting.

A person who follows that advice adds a per-copy override on `xA`. That masks the
cell's setting **for that one copy** and leaves every other copy of the same cell
pointing at the same missing file — so the advice makes the design worse and hides the
real cause. The right advice for this case is to edit the cell's own setting, in the
symbol.

## Measured cause

`descend_view_missing_sentence()` (`src/actions.c`) takes `instname` and unconditionally
writes *"The copy named %s on this sheet is set to"*. Its caller passes
`xctx->inst[inst].instname` whether the value came from the instance branch or from the
symbol fallback. The two are consecutive lines in `get_sch_from_sym()`:

```c
if(inst >= 0) { ... my_strdup2(..., get_tok_value(xctx->inst[inst].prop_ptr, "schematic", 6)); }
if(!str_tmp || !str_tmp[0]) my_strdup2(..., get_tok_value(sym->prop_ptr, "schematic", 6));
```

The information needed to tell the two apart is right there and is simply not recorded.

## The repair

Record which of the two branches supplied the value, pass that to the mint, and give
the mint a second shape — cell-level rather than copy-level — with matching advice. It
stays one mint with two renderings, which is what ruling D5-4 asks for; it is the FACTS
that need a second case, not a second mint.

Note the sentence's own length budget: `xctx->statusmsg_text` is 256 bytes and the
current sentence is 190. Row C4 in `tests/headless/test_descend_doors_1228.tcl` holds a
ceiling of 240, so a cell-level shape must fit under it or move the ceiling
deliberately.

## Why no row catches this

Every fixture in `tests/headless/test_descend_doors_1228.tcl` puts the `schematic`
setting on the **copy**. Nothing in the tree exercises a cell-level (symbol K block)
`schematic` setting through the fallback, so the sentence has only ever been rendered
for the case it happens to describe correctly.
