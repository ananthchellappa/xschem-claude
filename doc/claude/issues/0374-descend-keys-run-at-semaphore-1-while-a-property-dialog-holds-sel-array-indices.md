# 0374 — the `e` / `i` keys descend at semaphore==1 while a property dialog is holding `sel_array` indices across `tkwait`

Status: **OPEN — STUB, claimed by item D5 (descend census part 2), deliberately NOT fixed there.**
Source-read only; no transcript yet. Split out of
[0253](0253-descend-semaphore-thresholds-disagree-and-a-zero-is-misread.md) so that D5 could
close 0253's *reporting* half without spending a second R3 ratification on a threshold move.

Area:
- `src/callback.c:6856` `case 'e'` and `src/callback.c:6993` `case 'i'` gate on `semaphore >= 2`.
- `src/scheduler.c:3082` / `:3138` / `:5620` gate `descend`, `descend_symbol` and `go_back` on
  `semaphore == 0`.
- `src/editprop.c:279-283` and `:395-397` do `xctx->semaphore++; tcleval("text_line ...");
  xctx->semaphore--;` — a **non-grabbing** dialog with a nested `tkwait`. `semaphore == 1`
  for its whole lifetime, and the code *after* it writes back through
  `xctx->sel_array[0].col` / `.n` and loops `for(i = 0; i < xctx->lastsel; ++i)` against the
  arrays as they are *then*.

## The suspected defect

At `semaphore == 1` the C key handler still descends. A descend calls `load_schematic()`,
which `clear_drawing()`s and rebuilds `xctx`'s object arrays for the CHILD. The property
dialog's captured indices then name objects in the child, so pressing OK writes the parent's
edited property onto whatever now occupies that index — silent cross-level data corruption,
with no undo entry that names it.

The `semaphore == 0` gate on the Tcl verbs closes this by accident. The C keys are the hole.

## Why it was not fixed in D5

Both repairs are user-visible and neither is settled by prior ratification:
- lowering `case 'e'` / `case 'i'` to `== 0` removes a working escape hatch (navigating while a
  non-modal dialog or a foreground simulation is up);
- raising the Tcl verbs to `>= 2` widens exactly the window described above.

D5 instead made every gate REPORT (`busy` now speaks on `descend`, `descend_symbol` and
`go_back`) and wrote the threshold semantics down at `int semaphore;` in `src/xschem.h`.

## What a fix needs first

1. A measurement: open `text_line` on a selected object (semaphore goes to 1), descend with
   `e`, answer the dialog, and dump the child object that got written. Headless is hard —
   `text_line` needs Tk — so this is an `xvfb-run` case.
2. A decision on the escape hatch, recorded here.
3. Re-resolving (or invalidating) the dialog's selection snapshot on a hierarchy change is the
   third option and the only one that costs no capability.

## Coverage

None. Every headless test that touches the semaphore sets it to 2; nothing sets 1 except
`tests/headless/test_descend_refusal_channel_0251.tcl` section G (added by D5), which covers
the *reporting*, not the corruption.
