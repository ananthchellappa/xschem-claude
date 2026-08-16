# 0394 — ASE's seized canvas Escape never reaches the C Escape terminal either (0245, second family)

Status: **OPEN** — measured during D7 (issue 0245), explicitly out of that item's scope.
Area: `src/ase_window.tcl:1597` / `:1602` / `:1652` (`ase::ui` select-on-design seize:
`sod($key,prevesc)` save, the `<Key-Escape>` install, the verbatim restore) → `sod_end`.
Found: 2026-08-10, D7 scout for **0245**.
Related: **0245** (the three placement forms, fixed), **0202** (canvas gesture seize has no stack),
**0201** / `tests/headless/test_cmdmode_descend_0201.tcl` legs CS3a–CS3c.

## The claim

ASE's select-on-design mode seizes `.drw <Key-Escape>` the same way the placement forms did. It
**composes correctly** — it saves the predecessor binding at `:1597` and restores it verbatim at
`:1652`, which is why CS3c passes and why 0245's fix is compatible with it — but its own Escape
script ends at `ase::ui::sod_end`, which never reaches `escape_terminal()` (`src/callback.c`).

So while a Direct-Plot / save-on-design mode is armed, canvas Escape still cannot:

- abort a co-armed canvas gesture (`MENUSTART`, `STARTMOVE`, a live wire draw),
- clear `MENUSTARTWIRE` from `ui_state2`,
- set `tclstop = 1` (the only break-out of the `propagate_logic` loop, `hilight.c:2301`),
- erase the snap cursor, or run the cadence `last_command & STARTWIRE` fixup.

Identical shape to 0245, different owner.

## Why 0245 did not fix it

0245's fix sketch listed it as item 5, "Separate decision". ASE's seize is a *mode*, not a modeless
form: unlike Add-Pin/Add-Wire-Label/Create-Instance, ESC there is the mode's own cancel and it is
not obvious that it should also stop a running simulation. The forms' case was settled by the fact
that the C terminal was reachable before the grab existed; ASE's mode has to answer the question on
its own merits.

## The seam now exists

After 0245 the terminal is a verb: `xschem escape` (`src/scheduler.c`, group `xschem_cmds_e`).
Fixing this is a one-line `catch {xschem escape}` at the end of the seized Escape script or of
`sod_end`, plus a check in `tests/headless/test_cmdmode_descend_0201.tcl`.
