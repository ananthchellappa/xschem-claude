# 1228 — Pressing E opens the cell's own schematic, not the one the instance is set to open

**Status:** FIXED (2026-08-31, item S7).

## What a person sees
A symbol placed on a sheet can be told, one copy at a time, which schematic file
that copy opens — its `schematic` setting. On the shipped sheet
`xschem_library/inst_sch_select/inst_sch_select.sch`, copy **x2** is set to open
`comp3_parax.sch`, which is on disk and has 8 copies on it.

Pressing **E**, or **Edit > Push schematic**, on x2 opens **`comp3.sch`** — the
cell's own schematic, 54 copies — instead. There is no prompt, no message and no
error: the command answers 1, `descend_error` is empty and the status line is
untouched. Every channel reports success. The toolbar button, on the same copy in
the same session, opens the right file. Two controls, one sheet, two answers.

Unlike issue 0979 this one does not even look broken.

## Measured cause
`hi_descend_enum_views` (`src/xschem.tcl:6085`) builds the list of choices with the
**symbol** form of the resolver, `xschem get_sch_from_sym -1 $sym`. That form never
reaches the instance arm in `src/actions.c`, so the copy's own bound view is not
one of the choices at all. Measured for x2, the choices offered are only
`{schematic .../comp3.sch}` and `{symbol .../comp3.sym}`.
`hi_descend_pick_view` then returns the row named `schematic`,
`hi_descend_is_default_sch` compares it against the **instance** form, finds them
different, and forces the base sheet through the one-shot override.

This is a literal deviation from the tool's own spec:
`doc/claude/specs/hi_descend.md:132-134` says the enumeration must use
`xschem get_sch_from_sym <inst>`.

## Rows
`tests/headless/test_descend_doors_1228.tcl` A2, A3, B1, B3, B5, E7, and
`tests/headless/test_hi_descend.tcl` INSTVIEW-OFFER / INSTVIEW-LAND.


## What landed

`hi_descend_enum_views` now also emits the copy's own bound view, found with the
**instance** form of the resolver through the new helper `hi_descend_inst_defsch`
(`xschem get_sch_from_sym $instname`). The symbol-form row is still emitted under
the name `schematic`, so every existing fixture keeps the row it had and the cell's
own sheet is still one of the choices.

The new row is named after its own file. If that name is already taken by a row
with a different path — a copy bound to a file literally called `schematic.sch` —
it is named `instance` instead: every picker here is name-keyed and would otherwise
return whichever row came first.

`hi_descend_pick_view` grew an **optional** 4th argument, the copy's own bound
path, and prefers the row that matches it when the caller named no view and no
type. Optional so no existing caller or test stub breaks. `hi_descend_do_body`
passes it, and the `E` dialog preselects the same row in its View drop-down.

`hi_descend_inst_defsch` saves and restores the one-shot view override around its
lookup. The instance form of the resolver **reads and clears** that override, and a
reader would reasonably assume a lookup has no side effects.

Rows: `tests/headless/test_descend_doors_1228.tcl` A2, A3, A4, B1..B6, E7 and
`tests/headless/test_hi_descend.tcl` INSTVIEW-OFFER / INSTVIEW-LAND. Spec updated:
`doc/claude/specs/hi_descend.md` §5.

## Addendum — three guards the suite could not see (repair pass, 2026-08-31)

A sabotage pass neutralized thirteen mutations against this item. Ten were caught.
Three were not: the suite scored `RESULT: ALL PASS (29 checks)` / `OVERALL: ok`
with real, user-visible behaviour broken. The rule is that an unseen guard is
answered by ADDING THE ROW, not by deleting the guard, so all three now have one.
The suite is 31 checks.

**1. The sentence a person reads could stop mid-word, and nothing noticed.**
`xctx->statusmsg_text` is a fixed 256 bytes (`src/xschem.h`). The fix names the two
schematic files by file NAME so the sentence fits; put the full paths back and it
runs to 255 characters and truncates — measured, ending `... Opened the c`. The
person is told a file is missing and never told what was opened instead, which is a
straight PLAIN ENGLISH violation. Row C3 asks only whether the words `x3`,
`comp3_pex` and `comp3.sch` APPEAR; all three still do.

New row **C4** asserts the last clause whole and adds a length ceiling of 240, not
256: a 256-byte buffer TRUNCATES rather than overflows, so "under 256" is true even
of the cut-off message and a row asserting it could never go red. The sentence is
190 characters and does not vary with where the repo is checked out. Under the
mutation C4 reads `{0 0}`.

**2. Five of the seven controls a person presses could quietly stop asking for the
fallback.** Row E6 is the only witness for six of the seven (only the `E` key has a
behavioural row). E6 counts text, and the suite's comment stripper dropped only
lines whose FIRST non-blank character is a hash — so a TRAILING `;#` comment
survived and its text was counted. Stripping the flag from the toolbar
`Push schematic` button, the Alt-E new-window path and all three Cadence chords,
then restoring the literal text as five trailing `;#` comments, left the suite
fully green while row A7 independently proves those five controls would strand
people one level down on a blank page again.

`dd_nocomment_tcl` now also truncates a trailing comment at its semicolon, tracking
double-quote parity because a `;#` inside a string is real code — `src/xschem.tcl`
line 2489 writes a settings file whose CONTENT is a commented Tcl line. The text
before the semicolon is kept byte for byte, trailing blanks included, because
`dd_block` finds the end of a proc with `^\}$` and trimming would turn a
`} ;# note` line into a bare closing brace and cut a proc short. Under the mutation
E6 now reads `{1 0 1 0 0 0 1 1}` against `{3 3 1 0 0 0 1 1}`. Row **F1** had the
same hole and worse — it slurped its source with no stripping at all — and now
reads the comment-stripped copy for its "it asks for the fallback" half and the raw
copy for its "it no longer hand-arms the override" half. F2 stays raw on purpose:
it is about stale line numbers, which live only in comments.

**3. Looking at the list of schematics ate a view someone else had armed.**
`hi_descend_inst_defsch` saves and restores `::hi_descend_view_path` because the
instance form of the resolver reads and clears it. Delete those two lines and this
suite, `test_hi_descend` and `test_ase_view` all stay fully green.

New row **B7** is behavioural rather than a variable read: arm the override at
`comp3_empty.sch`, enumerate copy x2's choices, then descend. With the guard the
person lands on the view they picked, `comp3_empty.sch` with 7 copies; without it
the enumeration eats the override and they land on `comp3_parax.sch` with 8. Under
the mutation B7 reads `{0 1 comp3_parax.sch 8}`.

**Also fixed: the suite hung for ten minutes when run with a display.** Row A5
descends into the copy whose file is missing, which with a screen pops the question
and waits for a person; Tcl buffers to a pipe, so there was no output and no clue.
Every runner drives this file with `--nogui`, so nothing was affected, but the trap
was live for anyone reaching for the dev-display arm out of habit. It now refuses in
one second and names the right command. That choice — a loud refusal rather than a
silent self-skip — is unratified and is on the ledger as rule debt 1228.

## What is still open (write-up pass, 2026-08-31)

The adversary pass measured four things this item did not fix. All four were
re-measured independently before filing; none was fixed silently.

* **1234 — the bar in this item's own brief is not met for the wider class.** The
  brief said *"a GUI control must never leave a person one level down on a blank page
  with no prompt."* That now holds for a copy whose own `schematic` setting names a
  missing file. It does **not** hold when the CELL has no schematic file at all: copy
  x7 on the same shipped sheet places a `type=subcircuit` symbol with no `.sch`
  anywhere, and all three doors — including the one that now asks for the fallback —
  land on `currsch=1`, 0 instances, no question asked. Pre-existing, not a regression,
  and outside the per-copy class this item measured. `get_sch_from_sym()` stats the
  file it REFUSES and never stats the file it OFFERS.
* **1235 — the sentence this item minted blames the copy for a setting that lives on
  the cell.** A `schematic` setting in a symbol's K block applies to every copy;
  the sentence still says *"The copy named xA on this sheet is set to open …"* when
  xA is set to nothing, and the closing advice sends the person to edit the copy,
  which masks the cell's setting for that copy alone and leaves the rest broken.
  Rulings D5-1 and PLAIN ENGLISH.
* **1236 — the new drop-down row is offered whether or not its file exists**, and
  reads identically either way. A presentation choice this item created and did not
  make; the existing `look` debt names only x2, whose file is there.
* **1237 — `-fallback` in any position but the first is swallowed in silence**, and a
  misspelled flag becomes an instance number. No shipped caller trips it; filed
  because the failure is silent and its consequence is the stranding the flag exists
  to prevent.

Unchanged and still open from the red phase: **1232** (a descend suite registered in
no runner) and **1233** (the five scripted walks left on the bare verb).
