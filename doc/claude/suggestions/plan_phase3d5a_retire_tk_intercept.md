# Phase 3d.5a — retire the Phase-2 Tk keyboard intercept (one mechanism per key)

**Status:** DONE (commit `07c1d4d9`). **Branch:** `feature/action-registry`.
**Predecessor:** d4 (`7cb366f1`/`99564587`): csv single-source + file loader.

## Why

Phase 2 (pre-pivot) Tk-binds four chords on `.drw` via `migrated_action_ids` /
`bind_accelerators_from_table`: `u` (undo), `Shift+U` (redo), `Shift+Z` (zoom in),
`Ctrl+z` (zoom out). A Tk binding with a key detail **pre-empts** the generic
`<KeyPress>` binding, so in the real GUI these chords never reach the C dispatch:

- `u`/`U` already have C rows (sem-gated batch 1, **idle_only**) — shadowed. Worse,
  the Tk path runs `xschem undo` unconditionally, so at `semaphore>=2` the GUI key
  undoes where the old C switch (and the C row) would do nothing. **A real behavior
  divergence between the two mechanisms, fixed by retiring the shadow.**
- `Shift+Z`/`Ctrl+z` have no C rows yet — d4a's finding (`view_zoom(0.0)` defaults
  to `CADZOOMSTEP`, actions.c:3028) proves the csv ids `view.zoom_in`/`view.zoom_out`
  (C acts) are identical to the switch behaviors, so rows can be seeded with the
  existing ids.

## The chords (verified against callback.c as it is NOW)

| Chord | switch today | guard | fate |
|---|---|---|---|
| `Z` (90) plain | `case 'Z'`: `rstate==0` → `view_zoom(0.0)` | none (no sem, no waves) | row `key 90 0 canvas → view.zoom_in` (non-idle); **case 'Z' deleted whole** (single exact branch; modified-Z was already a no-op and stays one) |
| `z` (122) Ctrl | `case 'z'` 2nd branch: `rstate==ControlMask` → `view_unzoom(0.0)` | none | row `key 122 ctrl canvas → view.zoom_out` (non-idle); **branch deleted**, case kept |
| `z` plain | `rstate==0 && !(ui_state & START*)` → `zoom_rectangle(START)` | **modal** (ui_state) | stays in C — the table can't express the ui_state condition |
| `z` Alt | `EQUAL_MODMASK && cadence_compat` → snap-cursor toggle | **mode** (cadence_compat) | stays in C |
| `u`/`U` | already C rows (idle_only) | — | nothing to do in C; un-shadowed by (3) below |

Remainder analysis for the deletes: `Ctrl+Shift+Z`, `Alt+Z` etc. hit no branch
today (letters strip Shift, so e.g. physical Ctrl+Shift+Z = keysym 90 rstate=Ctrl →
`rstate==0` false → no-op) and find no row after — still no-ops. `Ctrl+Alt+z`
matched nothing before and matches nothing after. Both deletes behavior-preserving.

## Steps

1. **callback.c**: seed the two canvas rows (non-idle, canvas-only — neither chord
   ever had a waves guard); delete `case 'Z'` (tombstone comment, like `B`) and the
   `Ctrl` branch of `case 'z'`. Build.
2. **Regenerate `src/keybindings.csv`** (`save_input_bindings_file`) — the
   test_bindings_file drift guard fails until this is done; that's it working.
3. **action_registry.tcl**: `migrated_action_ids` → empty list; comment explains the
   retirement (machinery procs kept: tested, no-ops over an empty list, available
   for a future genuinely-Tcl-only accel).
4. **Rewrite the Phase-2 test pair** (their *invariant* flips):
   - `test_accelerators.tcl`: the four sequences now have **NO** Tk binding (plus
     the original f/s/w checks); the same four physical chords still produce the
     same effects via `event generate` (zoom ratio ÷/×, wire undo/redo) — now
     through generic `<KeyPress>` → C dispatch; **new:** `u` at `semaphore=2` does
     NOT undo (the GUI key regained the idle gate the Tk path lacked).
   - `test_remap.tcl`: runtime remap now via `xschem bind` — rebind `key 90 0
     canvas → view.zoom_out`, the physical key's effect flips (zoom multiplies),
     restore, effect restored. (File-based remap is covered by test_bindings_file.)
5. Full suite: engine 6/6 + all smokes; narrow any older assertion the new rows
   trip.

## Risks

- `event generate` proved reliable in these two tests (unlike test_palette's
  focus-dependent toplevel check) — keep `focus -force .drw`.
- The cheat-sheet gains two rows (`Z` Zoom In, `Ctrl+z` Zoom Out) — labels exist in
  the csv already; no test asserts their absence.
