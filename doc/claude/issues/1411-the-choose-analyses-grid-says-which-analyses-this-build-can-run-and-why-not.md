# 1411 — the Choose Analyses grid says which analyses this build can run, and why not

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C6** of Stage 2 of `doc/claude/ase_analyses_batch/` (plan item **2c**, the
widget half)

## What ships

`$w.types` becomes a **wrapping grid, four per row**, one cell per analysis this simulator
describes — **eleven** for ngspice, not four. Each cell carries its state as a **glyph** on the
label; the status line carries the selected cell's sentence; a **Detect** button appears where a
cold measurement could change an answer.

⚠ **Eleven, not twelve.** The plan's *"twelve grid rows"* counts the options sheet, which is
`$w.opts` and is **not** an analysis type — registering it would put it in
`ase::analysis_offered`, in the seed and in the radio variable.

## Three things that are forced, not chosen

**1. State is a glyph, never a colour.** `ase::ui::_theme_widget`'s Radiobutton arm rewrites
`-background` and `-foreground`, and `ase::ui::populate` ends in `apply_theme $top`, which recurses
into this child toplevel on **every** state mutation. A per-cell colour is wiped the first time
anything changes. Row **GG4** proves it by setting one, repainting, and showing it gone — so nobody
re-proposes colour-coded cells. A glyph is also theme-proof and needs no tenth key in the locked
nine-key `ase::palette`. **`ok` gets no glyph**: marking the normal case is how a grid becomes
noise.

**2. Every cell stays selectable, including `blocked` and `absent` ones.** `invoke` on a
`-state disabled` radiobutton is a **silent no-op** — rc 0, the variable unchanged, `-command` never
fired. Disabling the cell would make a `.state` file carrying `{type pss enabled 1}` impossible to
turn **off** in the dialog, and would make a future row written as `$top.chana.types.pss invoke`
pass while doing nothing at all. What is disabled is the **Enable** checkbutton — the control that
would actually commit. Selecting a blocked cell is how its reason becomes readable.

⚠ **And a row already switched on must still be turnable off** (row **GG8**). A bench can carry
`{type pss enabled 1}` from a hand-edited file; `ase::preflight_gate` refuses the run, and if the
dialog also refused to let it be cleared the user would have no way out but editing the file by
hand.

**3. `$w.types.<type>` does not move.** Four committed rows in three suites drive those paths.
`pack` became `grid` inside the **same** frame, so the children keep their names — issue **1405** is
what that lesson cost.

## Detect

⚠ **It paints before it blocks, and the order is the whole point.** The measurement can take up to
**31.2 s** against a binary that exists, is executable and never answers, with Tk frozen throughout.
Setting the sentence and calling `update idletasks` **before** the blocking call is what puts it on
screen; the other order shows the user nothing until after the wait is over, which is the same as
not saying it. Row **GG10** is structural, because the only behavioural way to see it is to own a
binary that hangs.

⚠ **It is offered only where it could change an answer** — a cell resting on an assumption
(`unmeasured` **or** `baseline`; a baseline cell is offered *because every build of this simulator
has it*, which is a source-verified invariant and still not a measurement of the binary in front of
the user). A **`noprobe`** cell is one Detect can never help, which is why that token exists apart
from `unmeasured`: offering the button there is the button that lies.

## Three bugs of mine in the test rows

- `grid info`'s key order is not guaranteed; `lindex 3` / `lindex 5` gave `{row column}`
  **transposed**. The row would have passed or failed on Tk's option order, not on layout. Read by
  name.
- `expr {[$w invoke] ; [update] ; …}` — a `;` inside `expr` is invalid, and it aborted the suite.
- A helper I assumed existed (`d_nocomment`) did not.

## Verification

`test_ase_dialogs` **display 224 → 236** (section **GG**, 12 rows); headless 37 unmoved — every GG
row is a widget row.

**Five sabotage passes:** disabling the blocked cells (GG5, GG6, GG7); no wrap (GG1); dropping the
glyph (GG3); Detect blocking before painting (GG10); Enable staying live for a blocked cell (GG7).

⚠ `run_regression.tcl` runs this file on **neither** arm, so a T1 zero exercises none of these rows.
The resolver's own contract is in `test_ase_core.tcl` section AG for exactly that reason.

## Related

* **1410** — the resolver whose states this paints.
* **1408** — the status line and `chana_sim`, which this builds on.
* **1405** — the widget-path lesson.
* ⚖ **R9** — the cell sentences and `analyses_measuring`; rule debt **1411**.
