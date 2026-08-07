# 0233 — the wire-draw ↔ placement mutual exclusion is enforced at 1 of 13 arm sites, in one direction only, and ESC cannot always clean up after the other 12

Status: **FIXED** 2026-08-07 — **F3 (the ESC hole)** and **F2 (the reverse door)** landed together;
**F1** landed earlier the same day for `l`, `p` (both views) and component insert. The eight
remaining forward doors are re-scoped into issue **0237** (they are now a *jam*, not a *residue* —
F3 made ESC clean up after every one of them).

What landed:

- **F1** (earlier, 2026-08-07): a shared `leave_wire_draw_for(const char *what)` in
  `src/scheduler.c:68` wrapping `abort_wire_line_command()` + a statusbar line, called from the
  `add_wire_label -place`/bare, `add_sch_pin -place`, `add_symbol_pin -place` and `place_symbol`
  branches. It leaves wire/line mode in **all three** of its states (live / menu-armed / resting —
  the resting one was itself a 0230 follow-up bug). The scripted coordinate forms
  (`add_wire_label -drop`, `add_symbol_pin <x> <y> …`) are deliberately NOT gated: they commit
  outright, arm no cursor placement, and are the replay/test seams.
- **F3**: the `xctx->last_command &&` conjunct is gone from the wire/line teardown guard in
  `abort_operation()`, the two-stage-ESC `return` inside it is now conditional on `last_command`,
  and **all three** of the function's early returns (`DESEL_MODE`, `STARTMOVE`, `STARTCOPY`) call a
  shared `clear_orphan_gesture_bits()` for the bits whose only sink was the `ui_state = 0` they
  skip — `STARTRECT | STARTPOLYGON | STARTARC | STARTZOOM | MENUSTART`. `MENUSTART` was **not** in
  the fix sketch below and leaked measurably (`ui=65536` after ESC). Covering the sibling returns
  came out of adversarial review: `STARTCOPY` is textually identical to `STARTMOVE`
  (`copy_objects(ABORT)` clears only `STARTCOPY`, runs no `draw()`), and `DESEL_MODE` leaked too
  (measured `ui=10` after `deselect_mode` + `rect gui` + ESC). Left unfixed, the next canvas click
  is eaten by the orphan gesture and `new_rect(PLACE|END)` commits a stray rectangle.
- **F2**: `abort_placement_preview()` (factored out of `abort_operation()`, the helper issue
  **0232** also wants) plus `leave_placement_for(const char *what)`, the mirror of
  `leave_wire_draw_for()`. Called from every wire/line **verb**: `w`, `W`/`s` (snap wire), the `l`
  line fallback, context-menu Insert wire / Insert line, and the `wire gui` / bare `wire` /
  `line gui` / bare `line` / `snap_wire` scheduler arms. **Not** from `start_wire()`/`start_line()`
  as the sketch proposed — see *Where the fix diverged from the sketch*.
- **F2's issue-0231 carve-out** (also from review): `abort_placement_preview()` tears the preview
  down with `delete()`, which removes the **selection**, not the preview object — that is issue
  **0231**, open, and out of scope here. On the ESC path it misfires only for someone who pressed a
  cancel key; wiring it to `w` would hand it to the commonest drawing keys, and one `Ctrl+A` under a
  live preview (the forms are modeless) would wipe the drawing on the next `w`. **Measured before
  the guard: 2 wires + preview + `select_all` + `w` → 0 wires.** So `leave_placement_for()` returns
  0 and DECLINES while a multiple selection is live, the statusbar says *"finish or ESC the pending
  placement first"*, and every caller skips arming the draw (declining without that would just
  rebuild the jam). Delete the guard when 0231 lands.

User-ratified 2026-08-07 for F2: `w` **abandons the pending placement preview** and starts drawing
(option (a)), symmetric with what `l`/`p` do to a live wire and with 0230's ratified rule *"whatever
you just pressed is what you meant"*.

Tests: `tests/headless/test_placement_wire_gate.tcl` grew 29 → **86 checks** (section **D** = F3,
section **E** = F2), registered in `run_regression.tcl`. Eight sabotage runs, each with its own
witness:

| sabotage | red set | size |
|---|---|---|
| restore the `last_command &&` conjunct | `D3 ESC clears STARTWIRE` | 1 |
| empty `clear_orphan_gesture_bits()` | `D1 STARTRECT`, `D1 ui_state`, `D2 MENUSTART`, `D2 ui_state`, `D7 STARTRECT` | 5 |
| drop the call from the `STARTMOVE` return only | the same four `D1`/`D2` checks (`D7` stays green) | 4 |
| make the two-stage-ESC return unconditional (`if(1)`) | `D6 ESC still deselects` | 1 |
| disable the `leave_placement_for()` call sites | `E1`×3, `E2`×2, `E3`, `E4`, `E7 wire NOT armed`, `E7 no wire mode` | 9 |
| remove the 0231 decline guard (`if(0)`) | `E7`×5 | 5 |
| apply the gate to the scripted coordinate commit form | `E5 control` ×2 | 2 |
| break the `delete(0)`/`delete(1)` undo discriminator | `E6 undo lands pre-gesture` | 1 |

(the three F1 sabotage runs — `p` 4, insert 4, symbol-view `p` 2 — are unchanged. `E7`'s two
"draw not armed" checks are the deliberate overlap between the call-site and guard sabotages: both
must stop the draw arming, for different reasons.)

Area: the call sites of `abort_wire_line_command()` / `abort_placement_preview()` vs the placement
and wire/line arms; the `xctx->last_command &&` conjunct and the `STARTMOVE` `return` in
`abort_operation()` (`src/callback.c`)
Tests: `tests/headless/test_placement_wire_gate.tcl` (86); **0230's section G2 was rebuilt** on
`net_label 0`, one of the constructors issue 0237 keeps alive — see *Landmines*
Found: 2026-08-06, verifying issue **0230**'s out-of-scope list
Related: **0230** (parent — this is its "Still open" items 1 and 3, verified and widened), **0231**,
**0232**, `doc/claude/specs/add_wire_label.md`, `WIRING.md` §8 classes **D** and **H**.

## Repro

**Historical — this is the pre-fix measurement.** Replayed on a post-F1/F2/F3 binary the script
below no longer reproduces: `p` is gated (so `after p` gives `ui=16424`, no `STARTWIRE`) and the
ESC leaves `ui=0`. The residues quoted are what the tree did on 2026-08-06.

```tcl
set ::infix_interface 1        ;# `xschem wire gui` == a real first canvas click (start_wire)
proc fresh {} { xschem clear force; xschem wire 0 0 100 0; xschem unselect_all
                xschem abort_operation; xschem abort_operation }

fresh ; xschem wire gui              ;# `w`
xschem add_sch_pin -place            ;# `p` -- NOT gated (only `l` is)
xschem rect gui                      ;# `r` -- zeroes last_command, keeps STARTWIRE
xschem abort_operation               ;# ESC
```

```
A. FORWARD door: 'p' (Add Pin) during a live wire draw
  after w        ui=1     [STARTWIRE]                                     last_command=1 inst=0
  after p        ui=16425 [STARTWIRE|SELECTION|STARTMOVE|START_SYMPIN]    last_command=1 inst=1
B. ...then one more arm that zeroes last_command, and ESC can no longer clear the wire
  after r        ui=16427 [STARTWIRE|STARTRECT|SELECTION|STARTMOVE|START_SYMPIN] last_command=0
  after ESC      ui=3     [STARTWIRE|STARTRECT]                           <-- wire gesture SURVIVES
  after ESC #2   ui=0     []
C. REVERSE door: 'w' on top of a live Add-Wire-Label preview
  after l        ui=16424 [SELECTION|STARTMOVE|START_SYMPIN]              last_command=0 inst=1
  after w        ui=16425 [STARTWIRE|SELECTION|STARTMOVE|START_SYMPIN]    last_command=1 inst=1
D. CONTROL -- `l`, the ONE gated arm site (0230, scheduler.c:1846)
  after w        ui=1     [STARTWIRE]                                     last_command=1 inst=0
  after l        ui=16424 [SELECTION|STARTMOVE|START_SYMPIN]              last_command=0 inst=1
```

D is the clean control. A/B/C are the same keystroke shape with a different verb.

### Forward census — each door is `xschem wire gui` then the arm

| arm (GUI route) | `ui_state` after the arm | `lc` | ESC #1 |
|---|---|---|---|
| `add_sch_pin -place` (**`p`**) — **GATED 2026-08-07** | 16424 (no `STARTWIRE`) | 0 | clean |
| `place_symbol` (component insert) — **GATED 2026-08-07** | 8232 (no `STARTWIRE`) | 0 | clean |
| `add_graph` (menu) | 16425 | 1 | clean |
| `net_label 0` (**Alt+L**) | 16425 | 1 | clean |
| `net_label 2` (**Ctrl+P**) | 16425 | 1 | clean |
| `merge` (**Ctrl+V** / Edit ▸ Merge) | 297 `STARTWIRE\|SEL\|STARTMOVE\|STARTMERGE` | 1 | clean, but `modified` 1→0 (issue **0234**) |
| `rect gui` (**`r`**) | 3 `STARTWIRE\|STARTRECT` | **0** | **leaves `ui=3`** |
| `polygon gui` (**`P`**) | 2049 `STARTWIRE\|STARTPOLYGON` | **0** | **leaves residue** |
| `add_wire_label -place` (**`l`**) — **gated** | 16424 (no `STARTWIRE`) | 0 | clean |

8 of 9 leave both gestures armed. `add_image` shares the arm body (`scheduler.c:1963`) and `t`
(place text) needs a Tk toplevel, but its pre-arm effect — `last_command 1 → 0` with `ui=1
[STARTWIRE]` intact — is already measurable headlessly.

**Post-F3 status of this table:** the `ESC #1` column is now **clean for every row** — that was
F3's job, and the "leaves `ui=3`" / "leaves residue" entries are historical. What remains is the
jam while both are armed, re-scoped to issue **0237**.

### Reverse census — preview armed first, then the draw

**All four rows below are CLOSED by F2** (2026-08-07): the wire/line verb tears the preview down
and starts drawing, and the statusbar says `<verb>: pending placement abandoned`. The table is the
pre-fix measurement, kept as the record of the jam.

| door | `ui_state` after the draw arms | recoverable without losing the preview? |
|---|---|---|
| `w` on a **label** preview | 16425 | only by typing another character in the form — that `-place` re-arm hits the 0230 gate (`ui 16425→16424`, `lc 1→0`, preview intact) |
| menu Wire (`infix_interface 0`) | 81960 + `MENUSTART`, `ui2=1` | same |
| `L` / `line gui` on a label preview | 16428 `STARTLINE\|…`, `lc=4` | same |
| `w` on an **Add-Pin** preview | 16425 | **no** — `addpin`'s own `-place` re-arm leaves `ui=16425`, `lc=1`. ESC is the only exit and it deletes the preview. |

## Root cause

**One gate, thirteen arm sites** — as measured at filing (2026-08-06). `abort_wire_line_command()`
(`callback.c:507`) then had exactly one caller; since 2026-08-07 it has four, all through
`leave_wire_draw_for()` (`p` in both views, component insert, and the original `l`). The census
below is the pre-fix measurement and is kept as the record of what the other nine still do:

```
$ grep -n "abort_wire_line_command()" src/*.c
src/scheduler.c:1846:        if(abort_wire_line_command() && has_x)
```

The other twelve arms were ungated (nine still are; `add_symbol_pin -place`, `add_sch_pin -place`
and `place_symbol` have since been gated): `paste.c:683` (merge), `actions.c:2477` (`net_label 0/1/2/3`),
`draw.c:305` (screen-grab image), `callback.c:469` (`start_place_symbol` / ctx-menu 1), `:4319`
(ctx-menu Insert text), `:6968` (`t`), `scheduler.c:1753` (`add_symbol_pin -place`), `:1802`
(`add_sch_pin -place` = the `p` key), `:1932` (`add_graph`), `:1963` (`add_image`), `:8940`
(`place_symbol`), `:8960` (`place_text`).

**Why the co-armed state is unusable** (prove-by-code — `xschem callback` segfaults headlessly, so
the click path cannot be driven): the Button-1 press reaches the placement only past three earlier
exits — `callback.c:7828` (`persistent_command && last_command` → `start_wire()` and `return`),
`:7845` (`check_menu_start_commands` seizes a MENUSTART-armed wire), and `:7863`
(`end_place_move_copy_zoom()` takes its `STARTWIRE` arm at `:2872`, before the placement arm at
`:2927`, returns 0), after which the click-select fall-through is declined by its own guard at
`:7877-7878`. The release-side call at `:8311` re-enters the same branch. No press and no release
can commit the preview while `STARTWIRE` is set. That is 0230's Defect 1, verbatim, on twelve
ungated verbs.

**Why the reverse direction was open** (CLOSED by F2, 2026-08-07 — the four callers named below
are exactly the sites the gate now sits at): `start_wire()` (`:536`) and `start_line()` (`:473`) do
nothing but `readonly_block()` + `last_command = …` + `new_wire(PLACE, …)`. No test of
`START_SYMPIN` / `PLACE_SYMBOL` / `PLACE_TEXT` / `sympin_preview`. Callers are equally ungated
(`case 'w'` `:7135`, ctx-menu `:4285`/`:4293`, `scheduler.c:13007`).

**Why ESC does not always clean up — the `last_command == 0` hole.** 0230's fix (A) is nested
inside `callback.c:351`:

```c
if(xctx->last_command && xctx->ui_state & (STARTWIRE | STARTLINE)) {
```

That conjunct predates 0230 (`a797bc59`) and exists only to protect the two-stage ESC. But three
arm families zero `last_command` while leaving `STARTWIRE` set — `case 't'` (`:6961`) and ctx-menu
Insert text (`:4312`); `rect gui` (`scheduler.c:9960`) and `polygon gui` (`:9049`); bare
`place_symbol` / `start_place_symbol` (`scheduler.c:8933`, `callback.c:457`). With
`last_command == 0` the guard is false, so neither the rubber `new_wire(RUBBER|CLEAR)` (`:352`) nor
`ui_state &= ~(STARTWIRE|STARTLINE)` (`:375`) runs; control drops into the STARTMOVE branch, tears
the preview down, and `return`s at **`:406`** — never clearing the shape bits and never reaching
`ui_state = 0` (`:417`) or `draw()` (`:419`). Measured: `ui=3 [STARTWIRE|STARTRECT]`.

Since `redraw_w_a_l_r_p_z_rubbers()` re-strokes the band whenever `STARTWIRE` is set
(`callback.c:248-257`) and the CLEAR never ran, **this is the "grey lines of the same dimensions as
the wire drawn" of the 0230 report, surviving ESC on a path 0230 did not close.**

It is not wire-specific: `p` → `r` → ESC leaves `ui=2 [STARTRECT]` with no wire anywhere. The
`return` at `:406` leaks *every* shape-draw bit.

Class: `WIRING.md` §8 **D** for the ESC hole; the gating asymmetry is the same "cleanup accreted
shape-by-shape" pattern, one verb at a time.

## Fix sketch — three independent pieces, F3 first

**F3 — the ESC hole (smallest, ship first, no policy question).** Split the conjunct so the
*teardown* runs on any live wire/line while the *two-stage ESC latch* keeps its `last_command`
condition:

```c
if(xctx->ui_state & (STARTWIRE | STARTLINE)) {
  … RUBBER|CLEAR + crosshair …                              /* unchanged, :352-354 */
  if(!(xctx->ui_state & (STARTMOVE | STARTCOPY | STARTMERGE))) {
    if(xctx->last_command) { xctx->ui_state = 0; return; }   /* a797bc59, unchanged */
  }
  xctx->ui_state &= ~(STARTWIRE | STARTLINE);
  if(xctx->last_command) keep_last_command = 1;
}
```

plus `ui_state &= ~(STARTRECT | STARTPOLYGON | STARTARC)` before the `return` at `:406` (or let that
branch fall through to `:417`, which is the bigger change).

**F1 — forward gate.** `abort_wire_line_command()` at the twelve ungated arms. The six scheduler
arms sit in one dispatcher, so a single call behind a shared `is_placement_verb(argv[1])` test
covers them; `actions.c:2477`, `paste.c:683`, `callback.c:457`/`:4319`/`:6968` need their own. Keep
0230's `-drop`-style exclusion wherever a verb has a pure-commit sub-form.

**F2 — reverse gate.** A `abort_placement_preview()` (the same helper issue **0232** needs — factor
`callback.c:380-400` once, use it three times) called from `start_wire()` and `start_line()`.
**Not** `abort_operation()`, for 0230's stated reason (`callback.c:502-505`).

**Policy question for the user, mirroring 0230's ratification:** does `w` on a live preview
*abandon the preview* (symmetric with `l` abandoning the wire), or *decline to start the wire*?
0230's precedent says abandon; a silent decline would be a TRAP-7-shaped surprise.
→ **Ratified 2026-08-07: abandon.**

## Where the fix diverged from the sketch

1. **F2's gate is at the VERBS, not inside `start_wire()`/`start_line()`.** The sketch above (and
   the session prompt) proposed the two primitives as the choke point. They are not one: they are
   also the per-**click** continuation of a running draw. A press reaches `start_wire()` at
   `callback.c` `persistent_command` (`&& xctx->last_command`, before
   `end_place_move_copy_zoom()` ever sees the click) and again from `check_menu_start_commands()`'s
   `MENUSTARTWIRE` arm — neither of which consults `START_SYMPIN`/`PLACE_SYMBOL`/`PLACE_TEXT`/
   `sympin_preview`. A teardown there would delete a user's pending placement on an ordinary mouse
   click, one event *after* the keystroke that armed the wire. `leave_placement_for()` is therefore
   called from each wire/line verb (key, menu, toolbar, context menu, scripted `gui` form) exactly
   the way `leave_wire_draw_for()` is called from each placement verb — and the pure-commit
   coordinate forms (`xschem wire x1 y1 x2 y2`) are excluded, same rule as `-drop`.
2. **The F3 mask needed `MENUSTART` and `STARTZOOM`,** not just the three shape bits named above.
   Measured leak on `add_sch_pin -place` + menu `rect` + ESC: `ui=65536 [MENUSTART]`. The principled
   set is *every bit `redraw_w_a_l_r_p_z_rubbers()` re-strokes, plus the menu arm* —
   `STARTWIRE|STARTLINE` excluded because the block above owns them.
3. **`STARTPOLYGON` never leaked.** `new_polygon(END, …)` at the top of `abort_operation()` consumes
   the bit *and commits a real polygon* before the guard is reached (`p` → `P` → ESC ends at `ui=0`
   with a stray polygon on layer 4 — a different defect, not fixed here, not claimed). It stays in
   the mask as defence only.
4. **Fall through, don't return, when `last_command == 0`.** With the conjunct dropped, a bare
   `STARTWIRE` draw with no command mode now enters the block. It must NOT take the two-stage-ESC
   `return`: that return exists only to jump over `last_command = 0`, and with `last_command`
   already 0 it would merely skip `unselect_all()` and the `draw()` the rubber CLEAR depends on.
   Pinned by check `D6`.
5. **The `STARTMOVE` branch keeps its `return`** rather than falling through to `ui_state = 0`.
   An aborted move must KEEP its selection (`move_objects(ABORT)` never unselects;
   `tests/headless/test_drag_keeps_selection.tcl` case 7 asserts it by name), which falling through
   to `unselect_all(1)` would break.
6. **`ui_state2` is still never cleared by `abort_operation()`** — deliberately left as-is rather
   than fixed on one path only. Landmine below stands.

Rejected: reordering `end_place_move_copy_zoom()`'s branches (`STARTMOVE` before `STARTWIRE`) —
`WIRING.md` §8 class **H**, and it does not even fix the symptom. Measured proof: the `-drop` path
*is* branch-reordering by another name (it bypasses the chain), and it leaves
`ui=9 [STARTWIRE|SELECTION] last_command=1` — the wire gesture and its rubber band ride on into
whatever the user does next.

## Known gaps left by F2/F3 (measured, deliberate)

Found by the adversarial review of the fix itself; each is either another issue's territory or has
no seam to close it here.

- **Merge / paste is not covered by F2.** `abort_placement_preview()` keys on
  `START_SYMPIN|PLACE_SYMBOL|PLACE_TEXT`; a `Ctrl+V` merge preview carries `STARTMERGE`, so `w`
  over one still jams. Tearing a merge down needs the `delete(1)` + `set_modify` handling issues
  **0232** and **0234** own. Tracked in **0237**.
- **A non-sympin preview abandoned with `w` can be resurrected by one undo.** The
  `delete(0)/delete(1)` discriminator (kept verbatim, see *Landmines*) sends `PLACE_SYMBOL` /
  `PLACE_TEXT` / graph previews down `delete(1)`, which snapshots the drawing *including* the
  preview before removing it. Pre-existing on the ESC path; F2 gives it a second entry point.
  Add-Pin / Add-Wire-Label previews (the `sympin_preview` ones) take `delete(0)` and are clean —
  that is what check `E6` pins.
- **`wirelabel_preview` has no `xschem get` seam**, so its clear inside
  `abort_placement_preview()` is unasserted (only `sympin_preview` is checked). Issue **0236** owns
  that flag's hygiene.
- **The `STARTCOPY` early return is fixed but not headlessly pinned.** `copy_objects(START)` has no
  scriptable seam (`xschem copy_objects dx dy` runs START and END back to back), so `D7` pins the
  shared `clear_orphan_gesture_bits()` through the `DESEL_MODE` return instead; the `STARTCOPY`
  call site is code-shared with it.
- **Truncated arg forms arm rather than commit.** `xschem wire 10 20` (argc ≤ 5) falls into the
  ARM branch, not the coordinate-commit branch, so it now also runs the F2 gate. Pre-existing
  dispatcher quirk; the *documented* commit form is `xschem wire x1 y1 x2 y2`, which is excluded
  (check `E5`).

## Landmines

- **0230's section G2 constructs this very state on purpose** (`test_add_wire_label.tcl`, 8 checks;
  its constructor was `add_wire_label -place` then `wire gui` = reverse door 1). F2 made that
  unreachable. **Resolved 2026-08-07:** G2 was rebuilt on `xschem wire gui` + `xschem net_label 0`
  — one of the forward doors now tracked by issue **0237**. Those doors (`net_label 0/2/3`,
  `add_graph`, `add_image`, merge, …) are the remaining ways to reach the co-armed state;
  `net_label` was picked because its preview is a real INSTANCE, so G2's "ESC deletes preview
  instance" check stays falsifiable (`add_graph`'s preview is a rect, which made it vacuous —
  caught in review). `net_label` sets no `sympin_preview`, so G2's now-vacuous check on that flag
  was dropped and the flag is asserted where it is real: section E of
  `test_placement_wire_gate.tcl`, on the F2 path. **Closing the last 0237 door makes G2 unreachable
  again** — 0237 carries the warning.
- **G3 pins the `a797bc59` two-stage ESC** (5 checks). **Corrected 2026-08-07:** it is NOT the
  sabotage witness for the new inner `if(xctx->last_command)` — G3's constructor is a plain
  `xschem wire gui`, which always leaves `last_command == 1`, so `if(1)` is equivalent there and
  every G3 check stays green. The measured witness is `D6 ESC still deselects` in
  `test_placement_wire_gate.tcl` (see the sabotage table at the top). G3 remains the guard that the
  two-stage ESC still *works*.
- **15 headless tests call `abort_operation`** and are F3's blast radius, led by
  `test_create_instance.tcl` (12 calls — the `place_symbol` door) and `test_add_wire_label.tcl` (9).
- **`persistent_command` wire mode.** F1 clears `last_command`, so arming a placement mid-draw drops
  persistent wire mode. That is the ratified 0230 policy for `l`; extending it to `p`/`t`/component
  placement changes commands the 0230 report did not name and needs the same explicit ratification.
- **Preserve the `delete(0)` vs `delete(1)` discriminator.** `add_graph`/`add_image`/merge arm
  `START_SYMPIN` with `sympin_preview == 0`, so their abort takes `delete(1)` and pushes undo. A
  shared helper must keep that verbatim (`callback.c:393`) or aborted graph/image placements start
  eating undo entries.
- **`ui_state2` is never cleared by `abort_operation`** — measured `ui_state == 0` with
  `ui_state2 == MENUSTARTWIRE` after ESC on the menu-wire reverse door. Inert today (only
  `MENUSTART` in `ui_state` gates `check_menu_start_commands`), live landmine for any future reader
  of `ui_state2` alone. `abort_wire_line_command()` does clear it (`callback.c:523`).
- **`xschem add_wire_label -drop` is not a faithful model of a GUI click and hides this bug.** It
  calls `wire_label_try_commit()` directly (`scheduler.c:1889`), bypassing
  `end_place_move_copy_zoom()`, so headlessly a label *does* drop while `STARTWIRE` is live — in the
  GUI the same drop is impossible. Assert on the **flags**, never on `-drop`'s return value, and add
  the caveat to `add_wire_label.md`.
- **The two sibling forms now behave differently under the same user error**: from the stuck reverse
  state, one more character in `.addlabel` re-issues `-place`, hits the 0230 gate and frees the wire
  while keeping the preview; the identical keystroke in `.addpin` does nothing. That asymmetry is
  the strongest argument for F1.
- **A second-order harm that could not be measured headlessly** (`new_wire(RUBBER)` has no Tcl
  seam): committing a wire *under* a live preview runs `new_wire(PLACE)` → `push_undo()`
  (`actions.c:4425`) with the undropped preview sitting in `xctx->inst[]`, then
  `maintain_wire_segments()` (`:4489`) — so a phantom label can split the fresh copper. Needs a
  `DISPLAY`-gated test in the fix.
