# 0269 — nothing tears down a live SHAPE draw: `r`, `P`, arc, circle and the zoom box stay armed under every other gesture

Status: **FIXED 2026-08-09** on `open_pdk` — `abort_shape_draw()` + `leave_shape_draw_for()`
(`src/callback.c`), `RUBBER|CLEAR` support added to `new_rect` / `new_arc` / `new_polygon` /
`zoom_rectangle` (`src/actions.c`), and the gate called from **41** arms. New suite
`tests/headless/test_shape_draw_gate.tcl`, **421 checks**, plus 2 rebuilt constructors in
`test_placement_wire_gate.tcl`. Closes phase 3 of
`doc/claude/suggestions/plan_modal_gesture_exclusion.md`, the last open phase. Issues **0268**,
**0270**, **0271** and **0272** were found by its census and are filed separately; 0268, 0270 and
0272 are fixed here, 0271 is fixed here.
Area: `src/callback.c` (the teardown/gate pair, `abort_operation()`, the key and context-menu
arms), `src/actions.c` (the four RUBBER branches), `src/scheduler.c` (the shape verbs, undo/redo,
the two test seams), `src/paste.c`, `src/draw.c`.
Tests: `tests/headless/test_shape_draw_gate.tcl` (421 checks). Was: **none** — the shape family had
no gate suite at all; phase 1 (issue 0247) tested only the direction *a shape arm cancels a wire
draw*.
Found: measured 2026-08-08 in the phase-3 session prompt, re-measured on the post-0265 tree
2026-08-09.
Related: **0240** / **0243** (the wire/line half), **0242** / **0241** (the placement half),
**0265** / **0267** (the merge half), `WIRING.md` §8 class **D**.

## The claim

Three teardown/gate pairs existed and covered each other in every direction. The shape draws had
**neither half**. `STARTRECT` (2), `STARTPOLYGON` (2048), `STARTARC` (4096) and `STARTZOOM` (128)
were set by `actions.c` and cleared only by their own completion, by `unselect_all()`'s wholesale
`ui_state = 0`, or by `clear_orphan_gesture_bits()` on the ESC path — which was a **residue sweep**
added by 0243 F3, not a teardown: it cleared bits and left the painted band behind.

So every other gesture armed straight on top of a live shape, in both interface branches.

## Measured, 2026-08-09, on the post-0265 binary (`6e7f1c55`), `--nogui`

```
                          before            after
rect armed                ui=2              ui=2
  rect + wire gui         ui=3        <--   ui=1        STARTRECT|STARTWIRE  ->  wire only
  rect + place_symbol     ui=8234     <--   ui=8232
  rect + add_wire_label   ui=16426    <--   ui=16424
  rect + merge            ui=298      <--   ui=296
  rect + undo             ui=2        <--   ui=0        STARTRECT survived the pop
polygon armed             ui=2048           ui=2048
  polygon + wire gui      ui=2049     <--   ui=1
  polygon + place_symbol  ui=10280    <--   ui=8232
  polygon + merge         ui=2344     <--   ui=296
arc/circle/zoom armed     ui=65536 ui2=64/128/8         (MENUSTART + discriminator, BOTH branches)
  + wire gui              ui=65537    <--   ui=1        MENUSTART survived under a fresh draw
  + place_symbol          ui=73768    <--   ui=8232
  + merge                 ui=65832    <--   ui=296
rect gui + rect 10 20     ui=65538    <--   ui=65536    a shape armed over a shape, ui2=4
```

`arc`, `circle` and `zoom_box` are a **different arm** and do not behave like `rect`: they set
`MENUSTART` in `ui_state` plus a discriminator in **`ui_state2`** in *both* interface branches
(`xschem arc|circle|zoom_box` have no infix branch at all — `scheduler.c`), and `STARTARC` /
`STARTZOOM` appear only on the first click. A gate written against `ui_state` alone would look
green and do nothing for a cadence user (plan landmine 5).

## Why the co-arm is fatal rather than untidy

`handle_button_press()` (`callback.c`) runs `check_menu_start_commands()` **before**
`end_place_move_copy_zoom()`, and inside the latter the branch order is
`STARTZOOM → STARTWIRE → STARTARC → STARTLINE → STARTRECT → STARTPOLYGON → STARTMOVE (the
placement commit) → STARTCOPY`. All four shape bits are tested before the placement arm, so **no
click can drop a preview while any shape bit is set**. `STARTRECT` and `STARTZOOM` self-terminate
after two clicks (committing a stray rectangle, or actually zooming) and `STARTARC` after three;
**`STARTPOLYGON` is unbounded** — `new_polygon(ADD)` never clears it — so a polygon draw plus a
placement preview is the issue 0240 dead end exactly: every click adds a polygon point, the preview
rides the cursor forever, and ESC is the only exit.

The click-select fall-through cannot rescue it either: its guard requires `!excl`, and `excl`
(`callback.c`) is `ui_state & (STARTWIRE|STARTRECT|STARTLINE|STARTPOLYGON|STARTARC)`.

# THE FIX

## The shape: two functions, as with the other three

- **`abort_shape_draw(void)`** — the teardown. Erase the band, clear the four `ui_state` bits,
  clear the `MENUSTARTSHAPE` bits of `ui_state2`, clear `MENUSTART` *only* when the bit qualifying
  it is a shape, free the polygon point buffers. Returns 1 if something went.
- **`leave_shape_draw_for(const char *what)`** — the gate every ARM calls: `gate_bypass` seam, then
  the teardown, then `statusmsg_hold("<what>: in-progress shape abandoned")`.

`abort_operation()` calls the **teardown** directly, never the gate — ESC is not a competing
gesture, so there is no `what` to name and no 5-second statusbar hold to raise over the coordinate
readout. Same split, same reason, as the placement and merge pairs.

### What it does NOT do, decided rather than inherited

- **No `delete()`, no undo baseline, no selection stamp.** A shape draw owns no objects:
  `new_rect`/`new_arc`/`new_polygon` push undo and store only when the gesture *completes*, and
  `zoom_rectangle()` never touches the document. This is why the teardown is delete-free where the
  placement and merge ones are not, and why issue 0241's scoping problem does not arise.
- **No `readonly` refusal**, unlike `leave_placement_for()` / `leave_merge_for()`, whose refusal
  exists because their teardown *is* a `delete()`. That asymmetry is load-bearing: the zoom box is
  a VIEW gesture with no readonly reject of its own, so it is the one shape a read-only window can
  arm, and a refusal here would leave exactly that case ungated. Pinned by test **E3**, which also
  pins the other half — every *edit* shape verb is refused at the verb by
  `scheduler_readonly_reject` (`circle`'s was missing; see issue 0272).
- **`void`, not `int`.** It can never decline, so there is no refusal to express. `leave_wire_draw_for()`
  is `void` for the same reason.

### What it DOES owe: the band

Clearing the bit only stops `redraw_w_a_l_r_p_z_rubbers()` re-stroking on the next motion; **the
last stroke stays on screen**. None of `new_rect` / `new_arc` / `new_polygon` / `zoom_rectangle`
honoured `CLEAR` — `grep "what & CLEAR" actions.c` returned only the two `new_wire` / `new_line`
sites — so the `RUBBER|CLEAR` idiom `abort_wire_line_command()` uses did not exist for shapes.
Two options were weighed:

- **(a) add `if(!(what & CLEAR))` around the repaint half of each RUBBER branch**, mirroring
  `new_line`. Chosen. `CLEAR` is 4096 and is passed by exactly five call sites, all to
  `new_wire`/`new_line`; none of the four functions tests any bit above `SET` (256), so this is a
  **strict no-op for every existing caller**.
- (b) call `drawtemprect`/`drawtempline`/`drawtemparc`/`drawtemppolygon` with `gctiled` from the
  teardown. Rejected: `restore_selection()` is file-static in `actions.c`, so a caller in
  `callback.c` cannot restore the SELLAYER highlight the tiled erase wipes without duplicating the
  bbox/`draw_selection` block, and it would have to re-derive `nl_state` and the `nl_points+1`
  convention.

The erase runs **first**, before the bits go and before any caller's `draw()`: `gctiled` is
`FillTiled` with `save_pixmap` as the tile, which a full `draw()` regenerates. Same ordering rule
`abort_operation()` already documents for the wire/line CLEAR. For the polygon the free of
`nl_polyx`/`nl_polyy` must come **after** the erase, which reads them — freeing first is a
use-after-free plus a lost erase.

## Where it is called: enumerated from the state, not from the verbs

0242's lesson, 0265's sharpening. **41 call sites**, in three blocks:

| block | how enumerated | sites |
|---|---|---|
| **N** the non-shape arms | exactly `leave_merge_for()`'s list | 24 |
| **S** the shape arms | every verb/key/pick that arms a shape | 15 |
| **U** `undo` / `redo` | the perform_action boundary | 2 |

Cross-check against the other three gates: `leave_wire_draw_for()` 24, `leave_placement_for()` 23,
`leave_merge_for()` 24. The deltas and their reasons:

- **+15 vs all three: the shape arms themselves.** A shape armed over another shape is a co-arm
  (measured 65538), because the MENUSTART branches only `|= MENUSTART` and *assign* `ui_state2`,
  never touching a live `STARTRECT`.
- **+3 vs `leave_placement_for()`: the three modeless form `-place` arms** (`add_symbol_pin`,
  `add_sch_pin`, `add_wire_label`). They carry no placement gate because they handle a previous
  *placement* themselves with the undo-clean per-keystroke re-arm dance; that dance is scoped to
  `sympin_preview` and knows nothing about the shape bits. They already carry `leave_merge_for()`
  for the identical reason.
- **+2 vs `leave_merge_for()`: `undo`/`redo`.** The shape draw lands on the **placement** side of
  this question. The merge gate is excluded from undo/redo because a pending merge is undo-covered
  and a `delete()`+`push_undo` in front of the pop would make undo *restore* the paste; none of
  that applies to a teardown that deletes nothing and pushes nothing. Positively it is needed:
  `pop_undo_keep_selection()` ends in an unconditional `unselect_all(0)` whose `ui_state = 0` drops
  the bits with the band still stroked, and when *nothing* is selected the bits survive the pop
  intact (measured: `rect gui` + `undo` → `ui_state` still 2), so the anchor `nl_x1`/`nl_y1`
  outlives a reloaded document and the next click commits geometry measured against a drawing that
  no longer exists.

Also **+3 gates at the 15 shape arms in the other direction**: they carried `leave_wire_draw_for()`
and nothing else, so they now call `leave_placement_for()` and `leave_merge_for()` too. That is the
plan's "call from every placement verb" box, and it is what makes `rect gui` on an Add-Pin preview
(ui 16426) or on a pending paste (298) stop being a co-arm.

**Never gated** (plan landmine 2, the replay/test seams): `xschem rect x1 y1 x2 y2`,
`xschem polygon x y …`, `xschem arc x y r a b layer`, `xschem zoom_box x1 y1 x2 y2`,
`xschem wire x1 y1 x2 y2`, `add_wire_label -drop`, `add_symbol_pin <x> <y> …`, `xschem paste dx dy`.
Gate by BRANCH, not by verb: a truncated form (`xschem rect 10 20`) falls into the ARM branch and
IS gated. Pinned by **E1** (five commit forms) and **C4** (the truncated form).
`act_zoom_rect_start()` (the Button-3 press that also opens the context menu) is deliberately not
gated: it is a per-*click* path, and gating it would repeat the mistake `leave_placement_for()`
avoids by staying out of `start_wire()`/`start_line()`.

## Ordering at a multi-gate arm

`leave_wire_draw_for` → `leave_shape_draw_for` → `leave_placement_for` → `leave_merge_for`. The two
band-erasing gates go first because their erase tiles from `save_pixmap` and both of the others can
reach a full `draw()`; placement stays before merge for the shared `preview_sel` slot (issue 0265).

## The polygon question, ratified 2026-08-09

**A competing gesture ABANDONS an in-progress polygon; ESC keeps COMMITTING it.**

`abort_operation()` still calls `new_polygon(END, …)`, which `push_undo` + `store_poly` + self-logs
`xschem polygon …` — unchanged. The two are not inconsistent: ESC is the gesture's own terminal and
closing the polygon is its documented meaning (the comment above `abort_operation()` records that a
blanket log-suppress there was an empirically confirmed MAJOR), whereas a second gesture is the
ratified "whatever you just pressed is what you meant" rule. Silently committing a half-drawn
polygon because the user pressed `w` is precisely the issue 0265 defect class. Pinned by **F1**
(gate abandons: `polygons == 0`, document still clean) and **F2** (ESC still commits, and the
commit still dirties).

Abandoning also owes the point buffers, which only the commit branch frees — **F4** pins that the
next polygon does not inherit the abandoned one's vertices, by counting `P` records on disk.

## The zoom box, ratified the same day: included

It stores nothing, dirties nothing and needs no viewport restore (`zoom_rectangle()` writes
`xorigin`/`zoom` only inside its END branch), so the teardown is a pure bit-clear plus band erase.
It is included because it jams identically — it owns the next click, so a placement armed on top of
it can never be dropped, and leaving it armed under a fresh gesture steals that click. The `z` key
carried a **decline** instead (`if(rstate == 0 && !(ui_state & (STARTRECT|STARTLINE|STARTWIRE|
STARTPOLYGON|STARTARC)))` — with another draw live, `z` did nothing and said nothing); the gates now
run first and that guard is a backstop that is always true by the time it is reached.

## Tests

New file `tests/headless/test_shape_draw_gate.tcl`, **421 checks**, true-headless, registered in
`tests/headless/full_audit.sh` `nogui_tests` and `tests/run_regression.tcl` `hcases`.

| section | what it pins |
|---|---|
| **A** | the five arms in both interface branches, and the `xschem test_shape_click` seam: each menu arm reaches the `ui_state` bit its gesture really uses (a circle is `new_arc(PLACE, 360.)`, so it lands on `STARTARC`) |
| **B** | the phase-3 direction: 5 shapes × 13 competing verbs in the CLICKED state, + 5 × 5 in the MENU state, each asserting the shape went **and** that one ESC leaves the fixture whole; **B3** that an abandoned shape stored nothing and left a clean document clean |
| **C** | the reverse: each shape arm cancels a live wire draw (C1, the phase-1 control), a live placement (C2), a pending paste (C3), another live shape (C4) and — C5 — the truncated coordinate form, which is an ARM (`rect gui` + `rect 10 20` was `ui_state` 65538) |
| **D** | both interface branches for arc / circle / zoom, menu-armed and clicked (landmine 5) |
| **E** | six controls: **1** five pure-commit forms are NOT gated; **2** `test_gate_bypass` really disables this gate; **3** read-only; **4** undo is gated and still undoes; **5** the teardown consumes no undo slot; **6** the statusbar message; **7** a non-shape `MENUSTART` arm (a pending descend pick) survives the shape teardown |
| **F** | the polygon decision, both ways, plus issue 0270 and the point buffers |
| **G** | issue 0268, both states, plus the wire-family residue reported as still-present |
| **H** | issues 0271 and 0272 |

`test_placement_wire_gate.tcl` **D1** and **D2** needed rebuilt constructors: they built a
co-armed placement+rect with `add_sch_pin -place` + `rect gui`, a door this phase closes. They now
bracket the constructor with `xschem test_gate_bypass`, exactly as D3 has since phase 2 — 171
checks, unchanged count.

### The new test seam, and why it had to exist

`xschem test_shape_click` (`scheduler.c`) runs, for a menu-armed shape, exactly what the first
canvas click runs: the matching arm of `check_menu_start_commands()` plus the release-side
`ui_state &= ~MENUSTART`. `xschem arc|circle|zoom_box` only ever reach the MENU state, and
`xschem callback …` **segfaults** under `--nogui`, so the CLICKED state of three of the five shapes
had no headless construction at all. Shipping `abort_shape_draw()`'s `STARTARC` / `STARTZOOM` paths
without an oracle is the issue 0246 residue class. It is a stand-in for the click, not a bypass: it
touches no gate.

### Sabotage table

Every predicate has a variant. Measured against the final suite, with the restored baseline
re-asserted green (421/421) at the end of the run — see the harness note below for why that
assertion exists.

| # | sabotage | **measured** |
|---|---|---|
| S1 | the gate neutralized at the 26 non-shape arms (block N + undo/redo) | **111 red** — section B across all five shapes and both states, plus the D and G rows that depend on a teardown having happened |
| S2 | the gate neutralized at the 15 shape arms only | **7 red** — C4 ×5 (each shape over a live rectangle), C5 (the truncated form), E3 |
| S3 | `leave_placement_for`/`leave_merge_for` neutralized at the 15 shape arms (phase 3's other half) | **33 red** — C2 and C3 across all five shapes, and H2's placement/paste rows |
| S4 | the teardown sees only `ui_state`: the MENU-armed half goes blind (plan landmine 5) | **30 red** — every B2 row, the D menu rows, the G menu rows. This is the detector for "looks green, does nothing for cadence users" |
| S5 | the `ui_state2 &= ~MENUSTARTSHAPE` clear dropped | **13 red** — section G in both states, plus D's `ui2 clean` rows |
| S6 | issue 0270 reverted (polygon `set_modify` back at the arm) | **3 red** — B3 polygon, F1, F3 |
| S7 | issue 0271 reverted (`leave_wire_draw_for` out of `merge_file()`) | **5 red** — all of H1: `merge`, `line`, RESTING mode, clipboard `paste` |
| S8 | issue 0272 reverted (`circle`/`zoom_box` verb gates removed) | **29 red** — H2 entirely, plus the circle/zoom rows of C1–C4 |

**The red sets are NOT all disjoint, and that is structural rather than sloppy.** Reported instead
of claimed:

- **S8 ⊂ S2 ∪ S3.** `circle` and `zoom_box` are two of the fifteen shape arms, so removing *their*
  four gates necessarily reddens a subset of what removing the gate at *all* shape arms reddens
  (3 rows shared with S2, 18 with S3). S8 is kept because it is the only variant that isolates the
  two verbs issue 0272 is about.
- **S1 ∩ S4 = 29, S1 ∩ S5 = 9, S4 ∩ S5 = 6.** These three break the same predicate from different
  sides: "a menu-armed shape does not survive a competing arm" fails whether the call is missing
  (S1), the state test is blind to it (S4) or the state is only half-cleared (S5). A shape that is
  never torn down also never has its `ui_state2` cleared, which is where S5's share comes from.
- **`E3 readonly: teardown ran anyway` appears in S2, S4 and S8** — one row, and by construction:
  its constructor is a shape arm (`zoom_box` twice), so it is sensitive to all three.
- **S6 and S7 are disjoint from everything**, which is the useful statement about them: issues 0270
  and 0271 each have a detector that nothing else can trip.

### Harness note, because this driver lied once

The first sabotage run reported S1 = S2 = S3 = **0 red** and a "restored baseline" of 50 red. Both
numbers were harness artefacts, and both are the class `WIRING.md` §10 names:

1. `shutil.copy2` **preserves mtime**, so restoring the sources left them older than the sabotaged
   object files and `make` had nothing to do — every subsequent run was measured against the
   *previous* sabotage's binary, and the reds accumulated monotonically. This is "sabotage runs lie
   if `make` did not rebuild" wearing a different hat: `make` ran, and correctly did nothing.
2. `/* SABOTAGE */ ` prefixed to a line **does not disable the call on it** — it is a comment in
   front of a statement that still executes. S1–S3 patched nothing at all.

The driver now restores with `copy` + `utime`, neutralizes a call by renaming it to a no-op macro
(which also survives ternary arguments and multi-line trailing comments), and **asserts the restored
baseline is green** at the end of the run, so a repeat of either failure aborts instead of
publishing a number.

## Two things the RED-first pass found that the design did not predict

1. **The `ui_state2` residue survives the click, not just ESC.** The first version cleared the
   `MENUSTARTSHAPE` bits only on the menu path (`MENUSTART` still set). But the click consumes
   `MENUSTART` and leaves the discriminator, so a clicked-then-abandoned arc kept
   `ui_state2 = MENUSTARTARC` with `ui_state = 0` — the same issue-0268 lie one step further along.
   Section **G** caught it in 7 rows; the clear now runs on both paths.
2. **The wire family has the identical residue and this fix does not close it.** Under
   `infix_interface 0`, `xschem wire gui` assigns `ui_state2 = MENUSTARTWIRE` and ESC leaves it
   there, because `abort_operation()` never calls `abort_wire_line_command()` — the only thing that
   zeroes the word. Inert by the same domination argument (issue 0268), out of this teardown's
   ownership, and **asserted as still-present** in **G2** rather than papered over, so the day it
   changes something says so.

## User-visible behaviour change

Starting a rectangle, polygon, arc, circle or zoom box and then pressing anything else now
**abandons the shape** instead of leaving it armed under the new gesture. The status bar says so
(`<verb>: in-progress shape abandoned`, held 5 s per issue 0248). Nothing is lost that was ever
stored — a shape draw stores nothing until it completes — with one exception worth stating: a
half-drawn **polygon** is now discarded by a competing gesture, where before it was left armed (and
would have been committed by the ESC that eventually followed). Pressing **ESC** on a half-drawn
polygon still closes and commits it, unchanged. The `z` zoom-box key, which used to do nothing at
all while another draw was live, now cancels that draw and starts the zoom box.
