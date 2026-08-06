# 0230 — `l` (Add Wire Label) pressed *during* a wire draw armed two modal gestures, and one ESC then orphaned the preview forever

Status: **FIXED** — two independent defects, two disjoint fixes, 23 new headless checks.
Area: `src/callback.c` `abort_operation()` (`:350-378`), new `abort_wire_line_command()` (`:494-534`);
`src/scheduler.c` `add_wire_label` branch (`:1831-1848`)
Tests: `tests/headless/test_add_wire_label.tcl` section **G** (59 → 88 checks)
Found: 2026-08-06 (user report, `cadence_style_rc` session). Evidence: `doc/claude/evidence/0230/`
Related: **0123** (the `sympin_preview`-without-`STARTMOVE` desync this reproduces), **0122** E1
(`sympin_drops` witness), `doc/claude/specs/add_wire_label.md`, `doc/claude/specs/wire_stub_netlabel.md`
§5 B6 (the SPACE self-gate precedent), `WIRING.md` §8 class **D**.

## The report

> For add-wire-then-exit-wire-draw-command-mode and then add-wire-label, all works as expected.
>
> Problem seen when going into add-label mode (`l` key) WITHOUT exiting wire-draw command mode, the
> result is absolute chaos. It's impossible to recover from this situation. You want to place the
> label, but XSCHEM wants to keep drawing wire. When you do place the label, it's not on a wire, but
> exists. Nothing works properly after this — there are grey lines of the same dimensions as the wire
> drawn. Zoom doesn't work properly.

Every clause of that report is one of the two defects below. Nothing else was wrong.

## Measured repro (headless, no X)

`xschem wire gui` with `::infix_interface 1` reaches the identical armed state as a first canvas
click: `start_wire()` sets `xctx->last_command = STARTWIRE` (`callback.c:478`) and `new_wire(PLACE)`
sets `ui_state |= STARTWIRE` (`actions.c:4494`). (`xschem callback .drw 4/6 …` is *not* usable
headlessly — the press path segfaults with no mapped window.)

```tcl
set ::infix_interface 1
set ::label_new_name FOO
xschem clear force
xschem wire 0 0 100 0
xschem unselect_all
xschem wire gui              ;# wire draw LIVE: ui_state=1 [STARTWIRE], last_command=1
xschem add_wire_label -place ;# the `l` key path -> label preview armed ON TOP
xschem abort_operation       ;# ESC
```

| step | BEFORE the fix | clean control (no live wire) |
|---|---|---|
| 2 `-place` armed | `ui=16425` `[STARTWIRE\|SELECTION\|STARTMOVE\|START_SYMPIN]` `lc=1` `inst=1` | `ui=16424` `lc=0` `inst=1` |
| 3 ESC | `ui=0` `ui2=0` `lc=1` **`inst=1`** **`lastsel=1`**, leftover `lab_pin.sym lab=FOO` | `ui=0` `lc=0` `inst=0` |
| 4 witness | **`sympin_preview=1`** + the fluid single-free tripwire fires | `sympin_preview=0`, no tripwire |
| 5 `-drop 50 0` on copper | **`0` = refused, permanently** | `0` |
| 6/7 two more `l` re-arms | `inst 1 → 2 → 2` (a second undo baseline each) | `inst 1 → 1 → 1` |
| 8 final ESC | **`inst=1`** — one stray net label kept forever | `inst=0` |

Full traces, the original user-session action log and the `FLTRACE` capture are in
`doc/claude/evidence/0230/` (`Xschem.log.2`, `xschem_fltrace_217801.log`) — 13 of the 16 trace lines
are the terminal state, which is why "nothing works properly after this".

## Defect 1 — you could never drop the label, even before any ESC

`end_place_move_copy_zoom()` tests **`STARTWIRE` (`callback.c:2809`) before the placement arm
(`:2864`)**. While a wire draw is live, every canvas click is consumed by `new_wire(PLACE…)` and
returns 0; the label's own commit arm (`if(xctx->wirelabel_preview) { wire_label_try_commit(); … }`,
`:2869-2872`) is unreachable. That is literally *"you want to place the label, but XSCHEM wants to
keep drawing wire"*. Reordering those branches is a `WIRING.md` §8 class **H** change with a blast
radius over zoom/rect/arc/polygon/copy — not the fix. The two gestures must not co-exist.

Nothing gated the arm: `edit.add_wire_label` is **Tcl-backed**, and `dispatch_input_action()` runs
`Tcl_GlobalEval` and unconditionally `return 1` for Tcl-backed actions (`callback.c:5186-5203`) — it
*cannot* decline the way `act_add_pin_stubs()` (`:4653`) does. `l` is registered
`set_input_binding_idle`, but "idle" there means *`semaphore >= 2`* (a modal dialog / re-entrant
event), **not** "a gesture is armed", so the keypress dispatches mid-draw. And
`unselect_all(1)` inside the `-place` arm (`scheduler.c:1854`) zeroes `ui_state` only when
`(ui_state & SELECTION) || lastsel` (`select.c:1066-1068`) — with nothing selected, the common
mid-draw case, `STARTWIRE` survives it.

## Defect 2 — one ESC then orphaned the preview (the unrecoverable part)

`abort_operation()`'s wire/line arm did:

```c
if(xctx->last_command && xctx->ui_state & (STARTWIRE | STARTLINE)) {
  … RUBBER|CLEAR …
  xctx->ui_state = 0;
  return;                     /* jumped over :357-398 */
}
```

`git blame` attributes it to `a797bc59` (2023-12-01, *"a first escape clear the ongoing placement, a
second escape clears the wiring or line-ing command"*). The diff inserts the block immediately above
the pre-existing `xctx->last_command=0;` and changes nothing else of substance: **the `return`
exists for exactly one reason — to skip `last_command=0` so persistent wire/line COMMAND mode
survives the first ESC.** It was never meant to skip a teardown.

But it skipped all of it. With a placement preview co-armed, `ui_state = 0` dropped `START_SYMPIN`
**before** the block at `:359-386` could run, so:

- `delete()` (`:372`) never removed the preview instance → a `lab_pin` the user never dropped stays
  in the schematic, still `SELECTED`, netlistable, with `set_modify()` left set by a *cancelled*
  gesture and the undo baseline from `scheduler.c:1850` rolled back onto nothing;
- `xctx->sympin_preview` / `xctx->wirelabel_preview` (`:377-378`) stayed **1**. `callback.c:354` was
  the only site in the tree that cleared `START_SYMPIN` without clearing them and without running
  `delete()`;
- `move_objects(ABORT)` never ran → the fluid gesture snapshot leaked (the `move.c:2830` single-free
  tripwire fires on the next move START);
- `xctx->last_command` stayed `STARTWIRE`, so with `persistent_command` the next press re-armed the
  wire *under* the still-live preview and the clash re-formed with no keystroke.

**Why it was terminal:** the entire Button-1 click-select/grab block is guarded by
`… && !xctx->sympin_preview` (`callback.c:7814-7815`), which is now false forever; and
`wire_label_try_commit()` bails at `:2780` because `START_SYMPIN` is gone, so `-drop` on copper
returns 0 forever. No press could select, grab, drop or cancel anything. Issue **0123**'s FLTRACE
witness at `:7795-7797` names this exact desync — 13 of the 16 captured lines are it.

**The grey lines and the dead zoom are this, not a third defect.**
`redraw_w_a_l_r_p_z_rubbers()` re-strokes/erases the wire rubber only while `STARTWIRE` is set and
the zoom rubber only under `STARTZOOM` (`callback.c:248-257`); once `ui_state` was zeroed, the band
stroked with `gctiled`/`drawtempline` (window-only, never in `save_pixmap`) had no owner left to
clear it. The five `zoom_out`s in the user's action log are the attempt to shake it loose. Both
disappear with defect 2 — they were verified as a consequence, not fixed separately
(`WIRING.md` §8 classes **I**/**K**: the visual half does not reproduce headlessly, because a
scripted END's full `draw()` flushes over the stroke).

**Class: `WIRING.md` §8 D (decline residue)** — cleanup that accreted shape-by-shape, with one exit
path that skips it.

## The fix

**(A) `abort_operation()` — stop skipping the teardown, keep skipping `last_command`.**
`callback.c:350-378`. The early `return` now happens only when there is nothing below to tear down;
otherwise `STARTWIRE|STARTLINE` are cleared, a local `keep_last_command` is latched and control
falls through to the existing block:

```c
if(!(xctx->ui_state & (STARTMOVE | STARTCOPY | STARTMERGE))) {
  xctx->ui_state = 0;
  return;
}
xctx->ui_state &= ~(STARTWIRE | STARTLINE);
keep_last_command = 1;
…
if(!keep_last_command) xctx->last_command=0;
```

A bare wire/line draw takes the identical old path, so the two-stage ESC of `a797bc59` is intact
(asserted by three checks in G3). The rubber `CLEAR` stays **first**: it erases by tiling from
`save_pixmap` (`xinit.c:2870`, `draw.c:1825`), which `delete()`'s trailing full `draw()`
(`select.c:790`) regenerates — CLEAR → `move_objects(ABORT)` → `delete()` → flags is the only order
in which each step still sees the world it assumes.

**(B) `abort_wire_line_command()` — entering Add-Wire-Label abandons the in-progress wire.**
New helper at `callback.c:494`, called from the `add_wire_label` branch (`scheduler.c:1831-1848`)
for the bare and `-place` forms, **not** `-drop`. Policy is the user's call (2026-08-06): *abort the
wire, then label* — nothing is committed, and since `new_wire()` pushes undo and stores only at
`PLACE`, an abandoned draw strands no baseline and no copper. It also drops a **menu-armed but
unclicked** wire/line (`MENUSTART` + `MENUSTARTWIRE|MENUSTARTSNAPWIRE|MENUSTARTLINE`), which would
otherwise start a wire under the fresh preview on the next press, and clears `last_command` for the
same reason. A `statusmsg()` says so when something was actually abandoned.

It is deliberately **surgical, not `abort_operation()`**: the form calls `-place` on *every
keystroke*, and on a re-arm a preview is already live — tearing that down would clear
`sympin_preview` and make the next `-place` take the fresh-arm branch and push a **second** undo
baseline for one gesture (`add_wire_label.md`: one baseline per gesture).

Placing the gate in the **scheduler branch** (not the dispatcher) covers the key, the menu
accelerator, the form's re-arm and a scripted `xschem add_wire_label` in one place — and avoids
`TRAP 7`: had `edit.add_wire_label` been made C-backed and allowed to *decline*, dispatch would fall
through to the legacy `case 'l'` (`callback.c:6383`) and silently start a graphic **line**.

### Follow-up 2026-08-06 — the gate missed the RESTING command mode (user-reported, fixed)

The first cut gated on `ui_state & (STARTWIRE|STARTLINE)` plus the menu arms, and that is only
*half* of "wire-draw mode". After ending a segment with a **double-click** the user is still in
wire mode — the diamond snap cursor is up — but `ui_state` has **no** `STARTWIRE`; only
`xctx->last_command` is armed. `cadence_style_rc:60` sets `persistent_command 1`, and the press
handler at `callback.c:7843` tests `last_command` **alone**:

```c
if(!xctx->readonly && tclgetboolvar("persistent_command") && xctx->last_command) {
  … start_wire(xctx->mousex_snap, xctx->mousey_snap); …
  return;                                   /* the placement is never offered the click */
}
```

So `l` armed the label, the gate found nothing to abort, and every click started a **new wire**
while the preview rode the cursor — exactly the original symptom, one state to the left. The user's
own report distinguishes the two precisely: *"If one vertex of a wire has been placed and the
command is waiting for the next vertex, then the abort-when-entering-label-command works
properly."* Their trace confirms it: `FLTRACE move: fluid_gesture_arm ui=SELECTION|STARTMOVE
sympin_preview=1` — **no `STARTWIRE`** at the moment the preview was live.

`abort_wire_line_command()` now also treats a non-zero `last_command` as live (it only ever holds
`0`/`STARTWIRE`/`STARTLINE`, `callback.c:541`/`:476`) and erases the stale snap cursor. Check
`0230 resting: arm label leaves mode` in section **G4**; sabotaging that one predicate reddens
exactly it.

**Two read-only getters** were added so the invariant is directly assertable rather than inferred
from a fluid trace: `xschem get last_command` (`scheduler.c:4239`) and `xschem get sympin_preview`
(`scheduler.c:4513`). `sympin_preview` must never outlive `START_SYMPIN`.

## Tests

`tests/headless/test_add_wire_label.tcl` section **G**, 29 checks, 59 → **88**. RED-first: 11 failed
before the fix. Placed before section F because F loads a `.sym` view (where `add_wire_label`
short-circuits) and never returns to a schematic.

- **G1** (10) — wire draw live, then `-place`: `STARTWIRE` and `last_command` cleared, preview armed,
  no wire committed, and the label still drops on copper and leaves `sympin_preview` 0.
- **G2** (8) — both armed (reachable *after* the fix via the menu-wire path on top of a live preview,
  which fix B does not gate): one ESC clears `sympin_preview`, clears `START_SYMPIN`, **deletes** the
  preview instance, clears `STARTWIRE`, leaves nothing selected, and *keeps* wire command mode; the
  second ESC leaves it.
- **G3** (5) — the plain wire draw is untouched: two-stage ESC, nothing committed.
- **G4** (6) — the **resting** command mode (`ui_state` clear, `last_command` armed — the state
  after a double-click ends a segment): arming the label leaves wire mode, the preview arms, and
  the drop commits. See the follow-up above.

**Sabotage variants** (`WIRING.md` §10), red sets disjoint as required:

| sabotage | red checks |
|---|---|
| `if(0 && …)` on the (B) gate call | exactly 2: `arm label clears STARTWIRE`, `arm label clears last_command` |
| `if(0 && xctx->last_command)` on the resting-mode predicate | exactly 1: `resting: arm label leaves mode` |
| `if(1)` on the (A) fall-through guard | exactly 3: `ESC clears sympin_preview`, `ESC deletes preview instance`, `ESC leaves nothing selected` |

Green tiers after the fix: `test_add_wire_label` **88**, `test_label_ride` **157**,
`test_label_strand_oracle` **32**, `test_wire_split` **119**, `wireedit/run_wireedit.sh` **58/58**,
`headless/run.sh` 6/6 goldens, `tclsh run_regression.tcl` → the same **3 FAIL lines from the one
pre-existing `test_ihp_sg13g2_libmgr` defect** (expects 9 libs, tree has 10) and nothing else. The 20
headless tests that touch `abort_operation` plus the 5 known-red ones were run against the pre-fix
and post-fix binaries and the per-test failure counts are **byte-identical**.

## Still open — now filed as their own issues

All four were verified independently on 2026-08-06 (measured headless repros, one agent per item)
and filed. Two of the verdicts below changed under measurement.

1. **`p` (Add Pin) has the identical clash** → issue **0233**. The census came back much wider than
   this note assumed: the gate exists at **1 of 13** placement arm sites, and the reverse direction
   (`w` on top of a live preview) is open too. 0233 also found an ESC hole this fix does not close —
   arms that zero `last_command` while leaving `STARTWIRE` set (`r`, `P`, `t`, bare `place_symbol`)
   leave `ui=3 [STARTWIRE|STARTRECT]` after ESC, i.e. **the "grey lines" symptom survives**.
2. **Three more callers reach `abort_operation` with both live** and are correct by (A). The
   `.load` dialog Cancel/Escape (`xschem.tcl:7160`, `:7317`) is still ungated by `ui_state`; no
   separate issue, it is covered by 0233's F1/F3.
3. **ESC does not reach C while the form is open** → issue **0235**. **The "harmless now" verdict
   above is wrong** and 0235 supersedes it: Tk picks the most specific binding *per bindtag*, and
   both the grab and the dispatcher are on `.drw`, so `<Key-Escape>` wins regardless of `break`.
   With the form **idle** the Escape aborts *nothing* — a menu-armed wire, a keyboard move and a
   live wire draw all survive, and the next canvas click acts on them.
4. **`::sympin_place` is a write-only Tcl owner latch** → issue **0236**, with a measured A/B: a
   stale latch makes the two forms swap identities at the shared `sympin_drops` witness (Add-Pin
   drains a name it never placed and re-arms an `iopin.sym` port on a user who is placing labels).

## Pre-existing defects found while reviewing this fix (NOT introduced by it)

A 4-lens adversarial review of the diff (21 findings raised, **0 survived refutation** as
regressions) surfaced these. All were verified to exist at `aabf354e` too, on code paths this
change does not touch. All four have since been reproduced independently and filed:

1. **`Ctrl+A` then `ESC` with a preview armed deletes the whole schematic** → issue **0231**.
   `select_all` makes the teardown's `delete(0)` (`callback.c:393`) operate on the *entire*
   selection. Correction to the note as first written: `undo` *does* restore the simple case (the
   arm pushed a baseline), but recovery is lossy or wrong on three of four doors — and
   `set_modify(save)` then reports the emptied document **clean**, so nothing prompts. The shortest
   route contains no ESC at all: arm the form, `Ctrl+A`, close the form.
2. **Any other placement armed on top of a live preview orphans it** → issue **0232**, which also
   closes issue **0123**'s open residual (*"desync ROOT open — no headless repro"*). 17 doors
   measured; 6 leave the terminal desync, 9 commit a label the user never dropped.
3. **The clash is gated in one direction only** → folded into issue **0233** (see above).
4. **`abort_operation()`'s merge/paste arms clobber the document dirty flag** → issue **0234**. Note
   the obvious fix is wrong: `merge_file()` already `set_modify(1)`s, so the pre-merge value has to
   be latched, not read at abort time.
