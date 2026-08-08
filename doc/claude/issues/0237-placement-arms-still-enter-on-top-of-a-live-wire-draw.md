# 0237 — every remaining verb that arms a second modal gesture on top of a live wire draw

(filename kept for its issue number; the original title said "eight placement arms", which was
wrong twice over — the shape draws `r` / `P` / arc / circle belong in the same set, and counting
"placements" alone missed them. What this issue actually tracks: **every verb that can arm a second
modal gesture while a wire/line draw is live**.)

Status: **FIXED** 2026-08-08 — phases 1 and 2 of
`doc/claude/suggestions/plan_modal_gesture_exclusion.md` landed together, user-ratified the same
day (option **(a) cancel**, consistent with issues 0230 and 0233). Carved out of issue **0233**
when its F2 and F3 landed (2026-08-07): 0233 closed the *ESC hole* (F3), the *reverse* door (F2,
`w`/`L`/snap-wire/menu Wire abandon a live placement) and gated four *forward* doors (F1: `l`, `p`
in both views, component insert). Everything else is closed here. **Still open, deliberately:
`Ctrl+V` merge, both directions** — its preview carries `STARTMERGE`, not the placement bits, and
tearing it down needs the `delete(1)` + `set_modify` handling issues **0232** and **0234** own
(roadmap phase 4).

Area: the draw and placement arms that did not call `leave_wire_draw_for()` (`src/scheduler.c`)
Tests: `tests/headless/test_placement_wire_gate.tcl` sections **F** (shape draws) and **G**
(placements) — 86 → **169** checks; `tests/headless/test_statusmsg_hold_0238.tcl` (GUI) for the
message these gates depend on
Found: 2026-08-06 (as 0233's forward census), re-scoped 2026-08-07, fixed 2026-08-08
Related: **0233** (parent, FIXED), **0230** (the original `l` ratification), **0238** (the gate
messages were invisible until this session), **0232**, **0234**, `WIRING.md` §8 class **D**

## The doors

Each is a live wire draw (`xschem wire gui` with `infix_interface 1`) followed by the arm. Measured
at `465223be`; `lc` is `last_command`. The **after** column is the state since this fix.

### Group 1 — shape draws (phase 1)

Not a "much milder" clash, which is what this file used to claim. The user demonstrated the
identical dead end in the GUI on 2026-08-07 under `src/cadence_style_rc`: `w`, click, `r`, and the
editor stayed in wire mode — `r` armed `MENUSTART|MENUSTARTRECT` (measured `ui=65537`,
`last_command=1`) while the wire kept claiming every click, so the rectangle could never start and
ESC was the only exit. Infix mode is the same dead end with both rubber bands on screen
(`ui=3 [STARTWIRE|STARTRECT]`).

| arm (GUI route) | site | before | after |
|---|---|---|---|
| `r` rectangle | `callback.c` `case 'r'`, `scheduler.c` `xschem rect` gui/ARM | `ui=3` `STARTWIRE\|STARTRECT`, or `65537` in cadence mode | `ui=2` / `MENUSTART\|MENUSTARTRECT`, wire gone |
| `P` polygon | `scheduler.c` `xschem polygon` gui/ARM (the `P` key IS the registry action `tools.insert_polygon` = `xschem polygon gui`) | `ui=2049` `STARTWIRE\|STARTPOLYGON` | `ui=2048`, wire gone |
| `C` arc, `Ctrl+C` circle | `callback.c` `case 'C'` (both branches), `scheduler.c` `xschem arc` ARM | `STARTWIRE` + `MENUSTARTARC/CIRCLE` | wire gone |
| ctx-menu 4, 5, 19, 20 | `callback.c` context-menu picks | same | same |

### Group 2 — placements (phase 2)

| arm (GUI route) | site | `ui_state` before | `lc` | after |
|---|---|---|---|---|
| `net_label 0/2/3` (**Alt+Shift+L**, **Ctrl+P**, **Ctrl+Shift+P**) | `actions.c` `place_net_label()` | 16425 | 1 | 16424, no `STARTWIRE`, `lc=0` |
| `add_graph` (Graphs ▸ Add graph) | `scheduler.c` `add_graph` | 16425 | 1 | 16424 |
| `add_image` (Graphs ▸ Add image) | `scheduler.c` `add_image` | shares the arm body | 1 | 16424 |
| `place_text` / `t` / ctx-menu 6 Insert text | `scheduler.c` `place_text`, `callback.c` `case 't'` and pick 6 | `lc` 1→0, `STARTWIRE` intact | 0 | `STARTWIRE` cleared |
| ctx-menu 1 Insert symbol, `I`, Insert key | `callback.c` `start_place_symbol()` | `PLACE_SYMBOL`, `STARTWIRE` intact | 0 | `STARTWIRE` cleared |
| screen-grab image | `draw.c` grabscreen release | — | — | gated at the arm (GUI-only, prove-by-code) |
| `merge` (**Ctrl+V**, Edit ▸ Merge) | `paste.c` | 297 `STARTWIRE\|SEL\|STARTMOVE\|STARTMERGE` | 1 | **unchanged — phase 4** |

`xschem place_symbol` was already gated by 0233 F1; `start_place_symbol()` is the *other* route to
the same operation and was not.

## What the fix is

One line per arm: `leave_wire_draw_for("<verb>")`, the helper 0230/0233 F1 already used — now
non-static (`src/xschem.h`) because the arms live in four files. It abandons wire/line mode in all
three of its states (live draw / menu-armed / RESTING command mode), is delete-free (nothing is
committed until `new_wire(PLACE)`, so no copper and no stranded undo baseline), and writes the
statusbar line `<verb>: in-progress wire abandoned`.

Two rules the call sites follow:

- **Gate both interface modes at every key.** `infix_interface 1` arms the gesture at the
  keystroke; `0` arms `MENUSTART` and the first click starts it. Cadence users run `0`, so a gate
  placed inside the infix branch alone would test green and do nothing for the person who filed
  this. Section F2/F3 of the test drives exactly that state.
- **Gate by BRANCH, not by verb name.** The coordinate/commit forms (`xschem rect x1 y1 x2 y2`,
  `xschem polygon ...`, `xschem arc x y r a b layer`, `add_wire_label -drop`,
  `add_symbol_pin <x> <y> ...`) commit outright, arm no gesture and are the replay/test seams —
  they are NOT gated (checks F7, C2, E5). A *truncated* form (`xschem rect 10 20`) falls into the
  ARM branch and IS gated (check F8).

## Consequences worth stating

- **A cancelled follow-up dialog does not bring the wire back.** `add_image` opens a file chooser
  and `t` / `place_text` open the text dialog *after* the gate has run. This matches
  `place_symbol` (gated since 0233 F1, ahead of the symbol chooser): the gate fires on the
  keystroke, which is what the user actually pressed, not on whether they confirm the dialog.
- **Persistent (cadence) wire mode ends too.** The gate clears `last_command` — that is the
  ratified 0230 policy, extended to these verbs on 2026-08-08.
- **The user-visible half only started working this session.** Every one of these messages was
  wiped before it could be read — issue **0238**, fixed first for that reason.

## Tests

`tests/headless/test_placement_wire_gate.tcl` 86 → **169** checks: section **F** (phase 1, incl.
the cadence-mode reproduction of the report and the commit-form controls), section **G** (phase 2),
section **H** (issue 0238's flags + the test seam). Sabotage runs, each with its own witness:

| sabotage | red set | size |
|---|---|---|
| `rect gui` gate removed | `F1`×2, `F2`×3, `H2`×2, `H5 gate live again` | 8 |
| `rect` bare-ARM gate removed | `F8 truncated form arms` | 1 |
| `polygon gui` gate removed | `F3`×3, `F6 line: P clears STARTLINE` | 4 |
| `arc` ARM gate removed | `F4`×3 | 3 |
| `place_net_label()` gate removed | `G1`×3, `G2`, `G5`, `G6`, `G7`, `H3`×2 | 9 |
| `add_graph` gate removed | `G3`×3, `G5 menu: add_graph` | 4 |
| `place_text` gate removed | `G4`×2 | 2 |
| gate applied to the rect COMMIT form | `F7 control`×3 | 3 |
| `statusmsg()` ignores the hold (0238) | `G1 statusbar says why`, `H3 select info line dropped` | 2 |
| hold never armed (0238) | the two above + `H2 gate message is held`, `H3 hold survived` | 4 |
| `gate_bypass` ignored (the test seam) | `D3`, `H5`×2, and `test_add_wire_label.tcl` `0230 both gestures armed` + `ESC keeps wire command mode` | 5 |

Deliberately NOT asserted: `r` on a **menu-armed** wire (first click not landed). The shape arm
ASSIGNS `ui_state2` wholesale, so that arm is replaced with or without a gate — a check there is
green either way, and was removed once measured. The live-draw-in-cadence-mode case (F2/F3) is the
real one.

## Landmines

- **The co-armed state is no longer constructible from any verb** — which is the point, and it
  broke the two tests that need it: `test_add_wire_label.tcl` **G2** (the only coverage of
  `abort_operation()`'s co-armed teardown) and `test_placement_wire_gate.tcl` **D3** (the dropped
  `last_command &&` conjunct, issue 0233 F3). Their constructors had already been rebuilt twice on
  doors that later closed. **Resolved with a test-only seam**: `xschem test_gate_bypass 0|1`
  (`scheduler.c`, `xctx->gate_bypass`), which disables `leave_wire_draw_for()` /
  `leave_placement_for()` for the length of a constructor. Both tests bracket only the ARM with it;
  the ESC under test runs with the gates live. Section H pins that the seam defaults to off and
  that flipping it really does disable a gate, so a suite that forgot to switch it back cannot pass
  silently.
- **Merge (`Ctrl+V`) is still an open door in both directions** and is the one remaining
  constructor for a co-armed state from a real verb. Do not build tests on it: issue **0234**
  (aborted paste marks a dirty schematic clean) and **0232** (shared teardown) own that site.
- **The `delete(0)` vs `delete(1)` discriminator** (`abort_placement_preview()`) is untouched:
  `add_graph` / `add_image` / merge arm `START_SYMPIN` with `sympin_preview == 0` and rely on
  `delete(1)` pushing undo. `tests/pin_name_text.tcl` regression 11 sabotage-checks it.
- **`xschem callback …` segfaults under `--nogui`**, so no click path and no context-menu pick is
  drivable headlessly. The ctx-menu picks (1, 4, 5, 6, 19, 20), the `C`/`Ctrl+C`/`r`/`t` key
  branches and the screen grab are prove-by-code; their scheduler twins (`rect`, `polygon`, `arc`,
  `place_text`, `place_symbol`, `net_label`) carry the assertions.
