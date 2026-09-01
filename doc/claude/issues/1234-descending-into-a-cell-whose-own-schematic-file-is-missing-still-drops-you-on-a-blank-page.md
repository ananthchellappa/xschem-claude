# 1234 — Descending into a cell whose own schematic file is missing still drops you on a blank page

**Status:** OPEN. Measured 2026-08-31 by item S7's adversary pass, re-measured
independently by the write-up agent before filing. **Pre-existing, not a regression:**
all three controls behaved this way before item S7 as well.

**Why it is filed against item S7.** S7's brief set the bar in one sentence — *"a GUI
control must never leave a person one level down on a blank page with no prompt"* —
and S7 met it for the class it measured: a copy whose own `schematic` setting names a
file that is not there. It does **not** meet it for the wider class below, which is the
more common shape. Filing rather than widening the item.

## Case A — a cell with no schematic file at all, and no question is ever asked

Shipped, git-tracked, `make install`-ed data. `xschem_library/inst_sch_select/` copy
**x7** places `comp3_read.sym`, whose K block says `type=subcircuit`. There is no
`comp3_read.sch` anywhere and x7 carries no `schematic` setting of its own. Measured
on the built binary (`./src/xschem --nogui --pipe -q --nolog`):

```
BARE-VERB       x7 rc=0 currsch=1 sheet=comp3_read.sch instances=0 wires=0 err=load-failed
    msg=Descend: could not load /home/.../inst_sch_select/comp3_read.sch
TOOLBAR(-fb)    x7 rc=0 currsch=1 sheet=comp3_read.sch instances=0 wires=0 err=load-failed
    msg=Descend: could not load /home/.../inst_sch_select/comp3_read.sch
E-KEY           x7 rc=0 currsch=1 sheet=comp3_read.sch instances=0 wires=0 err=load-failed
    msg=Descend: could not load /home/.../inst_sch_select/comp3_read.sch
```

All three doors, including the one that now asks for the fallback, put the person one
level down (`currsch` 0 → 1) on an empty page named after a file that does not exist.
No question is asked. The status line names a file the person never mentioned, in the
old cryptic wording — the plain-English sentence item S7 minted is never reached on
this path.

The chooser agrees, and offers nothing else:

```
ENUM x7: {schematic schematic .../comp3_read.sch} {symbol symbol .../comp3_read.sym}
```

**Measured cause.** In `get_sch_from_sym()` (`src/actions.c`) the whole fallback block
opens `if(fallback && !is_gen && filename[0])`. `filename` is only populated from a
`schematic` setting on the copy or on the cell. x7 has neither, so `filename` is still
empty there and the entire block — the existence test, the question, the sentence — is
skipped. Control falls to the `!str_tmp[0]` arm, which calls `get_base_sch_from_sym()`
and hands back `comp3_read.sch` **without ever calling `stat` on it**.

This shape is not exotic. It is any symbol backed by a SPICE netlist rather than a
schematic — exactly what `comp3_read.sym` is, and what a vendor PDK cell usually is.

## Case B — the question offers a file nobody checked, and Yes strands you anyway

Fixture: a symbol whose K block carries `schematic=nosuchfile.sch`, one copy `xA`, and
the cell's own `cellbound.sch` **removed**. Headless, fallback asked for:

```
DESCEND rc=0 sheet=cellbound.sch currsch=1 instances=0 err=load-failed
STATUS: Descend: could not load /tmp/.../f2lib/cellbound.sch
```

Two things are wrong at once. The person is one level down on a blank page again; and
the plain-English sentence item S7 minted **was emitted and then destroyed** —
`descend_speak()` runs first, then `descend_schematic()`'s load-failed arm overwrites
the status line with the old cryptic wording. The person is left with a sentence about
a file they did not name and no trace of the explanation.

With a display it is worse, because consent is involved. The adversary pass captured
the question on the dev display; it says, verbatim,
`This cell's own schematic file:\n    /.../cellbound.sch` and `Yes opens it.` The
person is asked a yes/no question, says Yes, and is stranded. `get_base_sch_from_sym()`
does not stat what it returns — one of its own branches is commented
*"symbol exists. pretend schematic exists too"*.

## Same cause, one line

`get_sch_from_sym()` stats the file it is **refusing** and never stats the file it is
**offering or opening**. Both cases close together: call `stat` on the result of
`get_base_sch_from_sym()` and (a) refuse before incrementing the hierarchy level rather
than after, (b) do not offer, in the question, a file that is not there.

The refusal wording must be minted the same way item S7 minted the other one — one
place, rendered by the question and the status line — and must survive
`descend_schematic()`'s load-failed arm, which today overwrites it.

## Why no row catches this

`tests/headless/test_descend_doors_1228.tcl` has no row for x7 and no fixture whose
cell's own schematic file is missing. Every one of its rows uses a cell whose base
sheet is on disk. Row A7 pins the bare verb's stranding as a deliberate invariant for a
**dangling per-copy setting**; nothing anywhere pins what should happen when the cell
itself has no sheet.

## What is owed

A ruling is owed on Case A specifically: refusing before the level is incremented is a
behaviour change on the bare verb, which item S7 deliberately froze (row A7), and three
scripted hierarchy walks read that answer — see issue **1233**. The Cadence answer is
not ambiguous about the outcome (Virtuoso prompts or refuses; it never drops you on an
untitled blank cellview), only about the mechanism.
