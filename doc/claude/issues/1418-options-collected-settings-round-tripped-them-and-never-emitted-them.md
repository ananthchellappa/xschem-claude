# 1418 — Options collected settings, round-tripped them, and never emitted them

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C5** of Stage 3 of `doc/claude/ase_analyses_batch/`.

## The defect, measured end to end

`ase::ui::chana_options` collected free-text name/value pairs, wrote them into the state row,
round-tripped them through the `.state` file and rendered them in the Arguments column — and
**nothing ever emitted them**. Its own header comment said so:

> Extra keys round-trip through the state file and show in the Arguments summary
> (arg_summary's unknown-key arm); DECK emission of extra keys stays deferred (v1 limit,
> documented here).

Measured: type `uic 1`, `tstart 5u`, `tmax 1n` into a tran row, see all three confirmed in the
pane, and the deck says `tran 10n 200u`.

**This is the defect the whole stage is named for**, and it is the exact inverse of the batch's
acceptance criterion: *nothing the window shows may fail to reach the deck.*

## What ships

`ase::analysis_emit_check` gains an **`unknownkey`** offence — a key on the row that is neither
`type`, nor `enabled`, nor a declared field of that type. `ase::ui::chana_x_add` refuses such a name
**at `Add`**, and `ase::ui::chana_x_ok` refuses it again at OK.

⚠ **Refused at `Add`, not only at OK.** A pair the user has already watched land in the list is a
pair they believe they have set; taking it away at OK would be a second surprise on top of the
first. The refusal belongs at the gesture that would have created it.

⚠ **And again at OK, because the editor is seeded from the stored row.** A bench written by an
older ASE-L — or edited by hand — arrives carrying keys `Add` never saw, and writing them straight
back would launder them through a door that now refuses them at the front.

## Refusing is safe, and that was measured before it was written

Across all **104** tracked `.state` files and all **416** analysis rows, the key sets are
`{type enabled}` plus declared field names and **nothing else**. Zero rows carry a key this
rejects. Section **CP** of `test_ase_core.tcl` is that measurement, kept as a row so the claim
cannot rot rather than as a sentence in a commit message.

## The fix is not to make free text emit

It is to stop accepting a name nothing can spend. Every parameter a type genuinely has is now a
**typed field** (issue 1416) offered by the **form** (issue 1417); the honest escape for everything
else is the labelled verbatim `x` hatch, which is a later commit and **actually emits**.

## Suites

`test_ase_core.tcl` **335 → 337** (**GR9**, **GR10**).
`test_ase_dialogs.tcl` display **261 → 265** (**G2i**, **G2j**, **G2k**).

⚠ **G2j exists so a sabotage can tell two things apart.** Without it, "closed the door" and "broke
the editor" produce the same green — a refusal that rejected *every* name would satisfy G2i
perfectly. G2j adds a name the type really does declare and requires it through.

⚠ **G2k plants the key in the state rather than typing it**, because `Add` can no longer create one.
That is the only way to reach the OK arm at all, and it is also the real-world case: a bench that
predates this commit.
