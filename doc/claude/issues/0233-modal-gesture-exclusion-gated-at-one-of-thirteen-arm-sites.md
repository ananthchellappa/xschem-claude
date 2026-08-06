# 0233 — the wire-draw ↔ placement mutual exclusion is enforced at 1 of 13 arm sites, in one direction only, and ESC cannot always clean up after the other 12

Status: **OPEN** — measured headless repro + 9-door forward census + 4-door reverse census, fix
sketched in three independent pieces, not implemented. **Major**: the reported issue-0230 gesture is
still fully reachable through `p`, `t`, `r`, component insert, `Alt+L`, `Ctrl+P`, `Ctrl+V` and the
graph/image menus; on one sub-family ESC leaves the wire rubber band armed, which is 0230's "grey
lines" symptom surviving the fix.
Area: the single call site of `abort_wire_line_command()` (`src/scheduler.c:1846`) vs the twelve
ungated placement arms; `start_wire()`/`start_line()` (`src/callback.c:536`, `:473`) have no
placement gate; the `xctx->last_command &&` conjunct at `src/callback.c:351`
Tests: **0230's section G2 depends on this state being reachable** — see *Landmines*
Found: 2026-08-06, verifying issue **0230**'s out-of-scope list
Related: **0230** (parent — this is its "Still open" items 1 and 3, verified and widened), **0231**,
**0232**, `doc/claude/specs/add_wire_label.md`, `WIRING.md` §8 classes **D** and **H**.

## Repro

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
| `add_sch_pin -place` (**`p`**) | 16425 `STARTWIRE\|SEL\|STARTMOVE\|START_SYMPIN` | 1 | clean |
| `place_symbol` (component insert) | 8233 `STARTWIRE\|SEL\|STARTMOVE\|PLACE_SYMBOL` | 1 | clean |
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

### Reverse census — preview armed first, then the draw

| door | `ui_state` after the draw arms | recoverable without losing the preview? |
|---|---|---|
| `w` on a **label** preview | 16425 | only by typing another character in the form — that `-place` re-arm hits the 0230 gate (`ui 16425→16424`, `lc 1→0`, preview intact) |
| menu Wire (`infix_interface 0`) | 81960 + `MENUSTART`, `ui2=1` | same |
| `L` / `line gui` on a label preview | 16428 `STARTLINE\|…`, `lc=4` | same |
| `w` on an **Add-Pin** preview | 16425 | **no** — `addpin`'s own `-place` re-arm leaves `ui=16425`, `lc=1`. ESC is the only exit and it deletes the preview. |

## Root cause

**One gate, thirteen arm sites.** `abort_wire_line_command()` (`callback.c:507`) has exactly one
caller:

```
$ grep -n "abort_wire_line_command()" src/*.c
src/scheduler.c:1846:        if(abort_wire_line_command() && has_x)
```

The other twelve arms are ungated: `paste.c:683` (merge), `actions.c:2477` (`net_label 0/1/2/3`),
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

**Why the reverse direction is open:** `start_wire()` (`:536`) and `start_line()` (`:473`) do
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

Rejected: reordering `end_place_move_copy_zoom()`'s branches (`STARTMOVE` before `STARTWIRE`) —
`WIRING.md` §8 class **H**, and it does not even fix the symptom. Measured proof: the `-drop` path
*is* branch-reordering by another name (it bypasses the chain), and it leaves
`ui=9 [STARTWIRE|SELECTION] last_command=1` — the wire gesture and its rubber band ride on into
whatever the user does next.

## Landmines

- **0230's section G2 constructs this very state on purpose** (`test_add_wire_label.tcl:203-219`,
  8 checks; its constructor is `add_wire_label -place` then `wire gui` = reverse door 1). F2 makes
  that unreachable and `check "0230 both gestures armed" … 1` goes red. G2 must be rebuilt on a
  different constructor or replaced by this issue's tests. 0230 flags the dependency itself.
- **G3 is the guard for F3** — it pins the `a797bc59` two-stage ESC. Sabotage F3 with `if(1)` on the
  new inner `if(xctx->last_command)` and exactly those 3 checks must go red.
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
