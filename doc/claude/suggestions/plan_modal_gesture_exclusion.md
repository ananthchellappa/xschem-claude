# Roadmap — one modal gesture at a time

Status: **phases 0 done, 1–4 open.** Owner: `open_pdk`. Last measured 2026-08-07 at `465223be`.

## The invariant

**Starting a modal gesture cancels whatever modal gesture is already live.**

Three gesture families exist and any two of them jam when co-armed:

| family | bits | armed by |
|---|---|---|
| wire/line **draw** | `STARTWIRE`, `STARTLINE`, or `MENUSTART`+`MENUSTARTWIRE/LINE/SNAPWIRE`, or the RESTING mode (`last_command` alone) | `w`, `W`/`s`, `Shift+L`, ctx-menu 2/3, menu/toolbar, `xschem wire\|line gui` |
| shape **draw** | `STARTRECT`, `STARTPOLYGON`, `STARTARC`, or `MENUSTART`+`MENUSTARTRECT/POLYGON/ARC/CIRCLE` | `r`, `P`, `C`/`Ctrl+C`, ctx-menu 4/5/19/20, `xschem rect\|polygon\|arc [gui]` |
| **placement** preview | `START_SYMPIN` / `PLACE_SYMBOL` / `PLACE_TEXT` (+`STARTMOVE`), or `STARTMERGE` | `l`, `p` (both views), component insert, `Ctrl+P`, `Alt+Shift+L`, `t`, `add_graph`, `add_image`, ctx-menu 1/6, `Ctrl+V` merge, screen-grab |

Why they cannot coexist: `end_place_move_copy_zoom()` tests `STARTWIRE` **before** the placement
arm, and under `persistent_command` (cadence rc) the Button-1 handler seizes the click one step
earlier still. Whichever gesture is armed second can never be completed, and ESC is the only exit.
Rejected alternative: reorder those branches — `WIRING.md` §8 class **H**, and it does not fix the
symptom (issue 0233 measured it).

Cadence mode is not special. It makes the jam louder (`persistent_command` claims every click) but
infix mode has the identical dead end with two rubber bands on screen.

## Machinery already in the tree

- `abort_wire_line_command()` — `src/callback.c`. Abandons a wire/line draw in **all three** of its
  states. Delete-free, no undo baseline stranded.
- `leave_wire_draw_for(const char *what)` — `src/scheduler.c:68`. The above + a statusbar line.
- `abort_placement_preview()` — `src/callback.c`. Tears down a cursor placement preview. Keeps the
  `delete(0)`/`delete(1)` undo discriminator verbatim.
- `leave_placement_for(const char *what)` — `src/callback.c`. The above + statusbar + the issue
  **0231** decline guard (returns 0 while a multiple selection is live; the caller must then not arm).
- `clear_orphan_gesture_bits()` — `src/callback.c`. What every early return in `abort_operation()`
  owes the terminal `ui_state = 0`.

**Nothing exists yet for abandoning a SHAPE draw** — phase 3 needs an `abort_shape_draw()` sibling
(clear the bits, erase the band with the `RUBBER|CLEAR` idiom).

## Phases

### Phase 0 — done

- [x] `l` (Add Wire Label) cancels a live wire/line draw — issue **0230**, ratified 2026-08-06
- [x] the RESTING wire command mode counts as "live" — 0230 follow-up
- [x] `p` (both views) and component insert cancel a live wire/line — issue **0233 F1**, ratified 2026-08-07
- [x] every wire/line verb cancels a live placement preview — issue **0233 F2**, ratified 2026-08-07
- [x] ESC cleans up after all of them; all three early returns in `abort_operation()` clear the
      orphan gesture bits — issue **0233 F3**
- [x] 86-check headless suite (`tests/headless/test_placement_wire_gate.tcl`) + 8 sabotage variants

### Phase 1 — shape draws cancel a live wire/line draw

Effort: ~8 one-line call sites, low risk (the call is a no-op unless a draw is live, and it is
delete-free so issue 0231 is not in play).

- [ ] fix issue **0238** first — every gate message is wiped by the coordinate readout before a
      user can read it, so the feedback these verbs depend on does not currently reach the screen
- [ ] ratify the policy with the user (see *Ratification* below)
- [ ] `case 'r'` (`src/callback.c:6916`) — both the infix and the `MENUSTART` branch
- [ ] `case 'P'` (`:6862`) — both branches
- [ ] `case 'C'` / `Ctrl+C` arc+circle (`:6310`) — both branches
- [ ] ctx-menu picks 4, 5 (`:4427`, `:4433`) and 19, 20 (`:4510`, `:4516`)
- [ ] `xschem rect` (`src/scheduler.c:9958`) — the `gui` and bare ARM forms only
- [ ] `xschem polygon` (`:9044`) — same
- [ ] `xschem arc` (`:2126`) — same
- [ ] leave every coordinate/commit form ungated (replay seams)
- [ ] new test section, RED-first, with disjoint sabotage
- [ ] docs: `WIRING.md` class D, `FAQ.md`, issue **0237**

### Phase 2 — the remaining placements cancel a live wire/line draw

Effort: ~7 call sites, same pattern as `p`. **Breaks `test_add_wire_label.tcl` G2** — see *Landmines*.

- [ ] `place_net_label()` (`src/actions.c:2477`) — covers `Alt+Shift+L`, `Ctrl+P`, `Ctrl+Shift+P`, `xschem net_label 0/2/3`
- [ ] `add_graph` (`src/scheduler.c:1924`)
- [ ] `add_image` (`:1963`)
- [ ] `place_text` (`:8982`) and `case 't'` (`src/callback.c:7088`)
- [ ] ctx-menu 1 Insert symbol (`start_place_symbol()`, `src/callback.c:478`) and 6 Insert text (`:4439`)
- [ ] screen-grab image (`src/draw.c:305`) — GUI-only, prove by code
- [ ] rebuild `test_add_wire_label.tcl` G2 on whatever constructor survives (landmine 1)
- [ ] issue **0237** → FIXED or narrowed to merge only

### Phase 3 — wire/line and placements cancel a live SHAPE draw

The reverse of phase 1; needs the new `abort_shape_draw()` helper.

- [ ] write `abort_shape_draw()` + `leave_shape_draw_for()` mirroring the wire/line pair
- [ ] call from every wire/line verb (the 11 sites `leave_placement_for()` already uses)
- [ ] call from every placement verb (the sites `leave_wire_draw_for()` already uses)
- [ ] decide what an in-progress polygon does — `abort_operation()` currently **commits** it
      (`new_polygon(END, …)` runs before the teardown); abandoning it instead is a behaviour change
- [ ] tests + sabotage

### Phase 4 — merge / paste (`Ctrl+V`), both directions

**Blocked** on issues **0232** (shared teardown for the merge/paste arms) and **0234** (aborted
paste marks a dirty schematic clean). A merge preview carries `STARTMERGE`, not the placement bits,
so `abort_placement_preview()` deliberately does not see it.

- [ ] wait for 0232/0234
- [ ] then: merge cancels a live draw, and a draw cancels a live merge

## Cross-cutting blockers

- **Issue 0231** — `abort_placement_preview()` tears the preview down with `delete()`, which removes
  the **selection**, not the preview object. Measured: 2 wires + preview + `select_all` + `w` → 0
  wires. `leave_placement_for()` therefore declines while a multiple selection is live. **Delete
  that guard when 0231 lands**, and until then do not add any new caller that could reach the
  delete with a foreign selection. Phases 1–2 are safe: they only cancel *draws*, which is
  delete-free.
- **Issue 0236** — `wirelabel_preview` has no `xschem get` seam, so its teardown is unassertable.
- **Issue 0238** — gate messages reach `.statusbar.1` but the coordinate readout overwrites them on
  the next 8-pixel mouse move, so every "X abandoned" line since 2026-08-06 has been invisible.
  Fix it before adding verbs that discard work silently.
- **`xschem callback …` segfaults under `--nogui`**, so no click path is drivable headlessly. Arm
  with `xschem <verb> gui` / `::infix_interface`, assert on flags, confirm pixels by eye.

## Landmines

1. **`test_add_wire_label.tcl` G2 needs the co-armed state to be constructible.** It is the only
   coverage of `abort_operation()`'s co-armed teardown. Its constructor has already been rebuilt
   twice (`wire gui` + `add_wire_label -place` → `add_graph` → `net_label 0`). **Phase 2 closes the
   last constructor**, so that phase must first give the tests a direct seam (there is no
   `xschem set ui_state` today) or move G2's intent into a differently-driven check. Decide this
   *before* writing the phase-2 gates, not after.
2. **Never gate a pure-commit form.** `add_wire_label -drop`, `add_symbol_pin <x> <y> …`,
   `xschem wire x1 y1 x2 y2`, `xschem rect x1 y1 x2 y2` commit outright and are the replay/test
   seams. `test_placement_wire_gate.tcl` C2 and E5 pin this in both directions.
3. **Arg-form quirk.** Truncated forms (`xschem wire 10 20`, `xschem line gui extra`) fall into the
   ARM branch, not the commit branch. Gate placement is by branch, not by verb name.
4. **One undo baseline per gesture.** A form's `-place` runs on every keystroke; a teardown that
   clears `sympin_preview` makes the next `-place` push a second baseline
   (`specs/add_wire_label.md`, `cadence_pin_name_text.md` item #3). Prove with a check.
5. **Test both interface modes.** `infix_interface 1` arms at the keystroke; `0` arms `MENUSTART`
   and the first click starts the gesture. Cadence rc uses 0 with `persistent_command 1`. A gate
   that only covers the infix branch looks green and does nothing for cadence users.

## Ratification

Each verb's policy has been ratified individually so far. Phases 1–2 are one question:

> Any new draw or placement command cancels the one in progress — for **all** remaining verbs
> (`r`, `P`, arc/circle, `Ctrl+P`, `Alt+Shift+L`, `t`, `add_graph`, `add_image`, ctx-menu inserts) —
> yes or no?

The alternative the code already supports is *decline* (`leave_placement_for()` returns 0 and the
caller does not arm) with a statusbar hint. Mixing the two per family is possible but would be the
first inconsistency in the rule, so decide once.
