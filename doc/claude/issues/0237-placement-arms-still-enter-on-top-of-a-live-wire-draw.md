# 0237 — eight placement arms still enter on top of a live wire draw (the forward doors 0233 F1 left ungated)

Status: **OPEN** — carved out of issue **0233** when its F2 and F3 landed (2026-08-07). 0233 closed
the *ESC hole* (F3), the *reverse* door (F2, `w`/`L`/snap-wire/menu Wire abandon a live placement)
and gated four *forward* doors (F1: `l`, `p` in both views, component insert). The remaining
forward doors — eight, after 0233's census of thirteen is re-counted against what actually arms a
PLACEMENT (see the note under the table) — are unchanged and are tracked here so 0233 can close.

Area: the placement arms that do **not** call `leave_wire_draw_for()` (`src/scheduler.c:68`)
Tests: `tests/headless/test_placement_wire_gate.tcl` sections A–C (three of the four gated verbs;
`l` is covered by `test_add_wire_label.tcl` G1);
`test_add_wire_label.tcl` G2 **depends on one of these doors staying open** — see *Landmines*
Found: 2026-08-06 (as 0233's forward census), re-scoped 2026-08-07
Related: **0233** (parent, FIXED), **0230** (the original `l` ratification), **0232**, **0234**,
`WIRING.md` §8 class **D**

## The doors

Each is `xschem wire gui` (a live draw, `infix_interface 1`) followed by the arm. Measured at
`bd61efed` + the 0233 F2/F3 commit; `lc` is `last_command`.

| arm (GUI route) | site | `ui_state` after the arm | `lc` | ESC #1 |
|---|---|---|---|---|
| `add_graph` (Graphs ▸ Add graph) | `scheduler.c:1932` | 16425 | 1 | clean |
| `add_image` (Graphs ▸ Add image) | `scheduler.c:1963` | shares the `add_graph` body | 1 | clean |
| `net_label 0` (**Alt+Shift+L**) | `actions.c:2477` | 16425 | 1 | clean |
| `net_label 2` / `3` (**Ctrl+P**, **Ctrl+Shift+P**) | `actions.c:2477` | 16425 | 1 | clean |
| `merge` (**Ctrl+V**, Edit ▸ Merge) | `paste.c:683` | 297 `STARTWIRE\|SEL\|STARTMOVE\|STARTMERGE` | 1 | clean, but `modified` 1→0 (issue **0234**) |
| `place_text` / `t` / ctx-menu 6 Insert text | `scheduler.c` `place_text`, `callback.c` `case 't'`, ctx-menu **6** | `lc` 1→0, `STARTWIRE` intact | **0** | clean **since 0233 F3** |
| `start_place_symbol()` (ctx-menu 1 Insert symbol) | `callback.c:466` | `PLACE_SYMBOL`, `STARTWIRE` intact | **0** | clean since F3 |
| screen-grab image | `draw.c:305` | — | — | — |

Not in this set, though 0233's forward census listed them: **`rect gui` (`r`) and `polygon gui`
(`P`)** arm `STARTRECT`/`STARTPOLYGON` and no placement bit at all (measured `ui=3` and `ui=2049`),
so they are a *shape* draw on top of a wire draw, not a placement — a different (and much milder)
clash. `polygon gui` has its own oddity: ESC commits the polygon (`new_polygon(END, …)` runs before
the teardown), so "clean" there is true of the flags and false of the drawing.

**What F3 changed here:** ESC now cleans up after every one of them (that was the user-visible
half). What is left is the *jam itself* — while both are armed, `end_place_move_copy_zoom()` takes
its `STARTWIRE` arm before the placement arm, so every click feeds the wire and the placement can
never be dropped. The user's only exit is ESC, which throws the pending placement away.

## Why this is not urgent, and why it is not nothing

Two of the four ratified verbs (`l`, `p`) are the ones a user actually reaches for mid-wire; the
ones here are rarer mid-draw. But the jam is identical, and for `add_graph` / `add_image` / merge
there is no form to re-trigger, so ESC is the only exit — the same trap 0233 F2 fixed on the
reverse side.

## Fix

Mechanical, and the pattern is already in the tree: call `leave_wire_draw_for("<verb>")` at each
arm, exactly as `add_wire_label` / `add_sch_pin` / `add_symbol_pin` / `place_symbol` do. The
scheduler arms sit in one dispatcher and could share a single `is_placement_verb(argv[1])` test;
`actions.c:2477`, `paste.c:683`, `draw.c:305` and the `callback.c` sites (`case 't'`,
`start_place_symbol()`, ctx-menu picks 1 and 6) need their own call.

**Each verb needs the same user ratification `l` and `p` got** (0230, 0233 F1): arming the
placement *cancels* the in-progress wire. Do not ship it as a batch without asking.

## Landmines

- **`test_add_wire_label.tcl` G2 is built on `net_label 0`** precisely because it is still an open
  door: the doors listed here are the only remaining constructors for the co-armed state, which is
  what G2 exists to test (`abort_operation()`'s co-armed teardown). `net_label` was chosen over
  `add_graph` because its preview is a real INSTANCE — `add_graph`'s is a rect, which makes G2's
  "ESC deletes preview instance" check vacuous. Gating the last of these doors makes that section
  unreachable: rebuild it on a direct flag-setting seam first. There is no `xschem set ui_state`
  seam today.
- **The F2 gate does not cover merge/paste.** `abort_placement_preview()` keys on
  `START_SYMPIN|PLACE_SYMBOL|PLACE_TEXT`; a `Ctrl+V` merge preview carries `STARTMERGE` instead, so
  pressing `w` over one still produces the co-armed jam. Deliberate: tearing a merge down needs the
  `delete(1)` + `set_modify` handling that issues **0232** and **0234** own.
- **The `delete(0)` vs `delete(1)` discriminator** (`abort_placement_preview()`, `callback.c`):
  `add_graph` / `add_image` / merge arm `START_SYMPIN` with `sympin_preview == 0` and rely on
  `delete(1)` pushing undo. `tests/pin_name_text.tcl` regression 11 sabotage-checks it.
- **Merge (`Ctrl+V`) also has issue 0234** (aborted paste marks a dirty schematic clean) and
  **0232** wants its own teardown helper at the same site. Coordinate, or the three fixes will
  collide in `paste.c`.
