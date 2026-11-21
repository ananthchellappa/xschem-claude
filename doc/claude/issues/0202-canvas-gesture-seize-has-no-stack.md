# 0202 — canvas Button-1 and Escape are single ownership slots with no stack, so no pick mode can nest inside another

Status: **OPEN**, and **no longer a blocker** — see "0201 shipped without it" below.
Filed 2026-08-01, spawned by [0201](0201-no-command-suspend-resume-contract.md) on the
reasoning that it was 0201's mechanical blocker. Established by reading; the hand-back
invariant it rests on was measured with 0201 (same section). **The LIFO violation itself
was measured on 2026-11-19**, with a user-visible symptom, and one pair of owners was taken
out of it — see "Measured, and partly closed, 2026-11-19" at the end, "After the third
repair" below it for what a second pass the same day changed, "After the fourth
repair" for a stack across a descend and a third mode entered over a stack, "After
the closing pass" for the doors that ended a mode underneath the Results Display Window's
mode, "After the last build" for the other order (that mode ended first, from under
another) and for the status bar under two stacked modes, and "After the build that
followed" for a mode ended while a descend has the stack paused.
Area: `src/ase_window.tcl` (`select_on_design` 1595-1602, `sod_end` 1644-1646),
`src/xschem.tcl` (`addpin::grab_esc` / `release_esc` 10817-10820,
`addlabel::grab_esc` / `release_esc` 11159-11162, the `<ButtonRelease>` drop hooks
10704-10709 / 11072, `set_bindings` 13892), `src/create_instance.tcl` (56-61),
`src/callback.c` (`abort_operation` 246, `case XK_Escape` 6918).
Tests: none for a stack. For what the last section changed: bands PG20, PG21 and PG23 of
`tests/headless/test_calc_pick.tcl`, band PK14 of
`tests/headless/test_calc_selector_names.tcl`, band TPL of
`tests/headless/test_ase_terminal_pick_1724.tcl`, rows I2b, I7 and I10 of
`tests/headless/test_ase_interact.tcl`. For what the third repair changed: bands PG24 to
PG26 of `test_calc_pick.tcl`, band PK15 of `test_calc_selector_names.tcl`, rows TPL4b, TPL9
and TPL9b of `test_ase_terminal_pick_1724.tcl`, groups PD and PW of
`tests/headless/test_pin_marker_1724.tcl`, section XP of
`tests/headless/test_rdw_keys_1245.tcl`, rows K19 to K21 of
`tests/headless/test_rdw_window_1245.tcl` and legs CR4 to CR9 of
`tests/headless/test_cmdmode_0201.tcl`. For what the fourth repair changed: band CR6 of
`test_cmdmode_0201.tcl` (the release order, against stub modes), leg DS8 of
`tests/headless/test_cmdmode_descend_0201.tcl` (two real modes stacked, across a descend
into a new window), band PG27 of `test_calc_pick.tcl`, rows XP7 and XP8 of
`test_rdw_keys_1245.tcl` and row TPL1c of `test_ase_terminal_pick_1724.tcl`. For what
the closing pass changed: the rows of band PG27 about the Calculator's own doors and
about a descend, row I11 of `test_ase_interact.tcl`, rows DS8j to DS8q of
`test_cmdmode_descend_0201.tcl`, rows CR6i and CR6s of `test_cmdmode_0201.tcl` and new
legs of rows XP7 and XP8. For what the last build changed: band PG26 (restated as one
row), the rows of band PG27 about the Results Display Window's mode ended first, and
band PG28 (the status bar) of `test_calc_pick.tcl`; row E6 of `test_rdw_keys_1245.tcl`;
row I12 of `test_ase_interact.tcl`; rows TPL13 and TPL14 of
`test_ase_terminal_pick_1724.tcl`. For what the build that followed changed: leg DS9 of
`test_cmdmode_descend_0201.tcl`, band PG29 of `test_calc_pick.tcl`, row I13 of
`test_ase_interact.tcl` and row TPL15 of `test_ase_terminal_pick_1724.tcl`.
Related: [0200](0200-descend-has-no-verb-noun-pick.md),
[0201](0201-no-command-suspend-resume-contract.md), 0122 E2/F3 (the ESC-slot hand-back that
established the current scheme).

## The defect

Three different subsystems arbitrate the same handful of canvas binding slots, and every
one of them arbitrates by **overwrite + remember one predecessor**:

```tcl
# src/ase_window.tcl:1595-1602 — ASE Select-On-Design
set sod($key,prevpress) [bind $cv <ButtonPress-1>]
set sod($key,prevrel)   [bind $cv <ButtonRelease-1>]
set sod($key,prevesc)   [bind $cv <Key-Escape>]
bind $cv <ButtonPress-1>   "[list ase::ui::sod_click $key]; break"
bind $cv <ButtonRelease-1> {break}
bind $cv <Key-Escape>      "[list ase::ui::sod_end $key]; break"
```

```tcl
# src/xschem.tcl:10817-10820 — the Add-Pin / Add-Wire-Label ESC slot (issue 0122 E2)
proc addpin::grab_esc    {} { bind .drw <Key-Escape> {if {[winfo exists .addpin]} {addpin::escape; break}} }
proc addpin::release_esc {} { if {[winfo exists .addlabel]} { addlabel::grab_esc } else { bind .drw <Key-Escape> {} } }
```

(Since 2026-11-19 the first snippet's three binds are `ase::ui::sod_seize`, which takes
the six slots of `ase::ui::sod_slots`; the mechanism, one predecessor per slot, is the
same.)

Each stores **one** predecessor. Two consequences:

1. **Nesting is unsafe.** If B seizes while A holds the slot, B records A's script as its
   predecessor. If A then ends first, A restores *its* remembered predecessor over B's
   live binding — B is silently disarmed, and B's teardown later restores A's script over
   whatever is current. LIFO is assumed but never enforced.
2. **A mode cannot be paused.** There is no "hold the slot for me and give it back" — only
   "take it" and "put back the one thing I remember". This is exactly what
   [0201](0201-no-command-suspend-resume-contract.md) needs and cannot have.

`addpin`/`addlabel` avoid (1) by hand: `release_esc` explicitly hands the slot to the
sibling form if it still exists. That is a two-party special case written out longhand, not
a mechanism, and ASE is not party to it.

## Two aggravating facts

**The slot is `.drw` only.** The Add-Pin/Add-Label mechanism targets the main canvas by
name and says so:

```tcl
# src/xschem.tcl:10813-10816
# SCOPE (0122-F3): like the whole form mechanism ... this targets the MAIN window canvas `.drw` only --
# not a detached window / non-first tab (`.xN.drw`). Pre-existing single-canvas assumption.
```

ASE, by contrast, seizes `[xschem get current_win_path]` — whichever canvas is current
*at arm time*. Two subsystems, two different notions of "the canvas", and a descend into a
new window/tab changes which one is current.

**`break` is load-bearing.** Every seized script ends in `break` so the generic
`bind $topwin <ButtonPress>` / `<KeyPress>` → `xschem callback` route
(`xschem.tcl:13944-13953`) never fires. A seize that forgets `break` double-dispatches; a
restore that loses the `break` silently re-enables the C path underneath a live mode. The
correctness of the whole scheme rides on string-identical restore.

## Decisions

### D1 — a real stack, keyed per (canvas, sequence) — proposed, not decided
`gestures::push <canvas> <seq> <script> <token>` / `gestures::pop <token>`, where `pop`
of a non-top token is either an error or reorders explicitly. Small, new file, no
behaviour change for a single owner. The existing three call sites migrate one at a time.

### D2 — scope: `.drw`-only or per-canvas? → **per-canvas**
Keying on the widget path costs nothing and removes the 0122-F3 single-canvas assumption
for free. `addpin`/`addlabel` can keep passing `.drw` until someone fixes them.

### D3 — does this need C? → **no** … ~~and Tk seizes do not displace the C ESC arm~~ **WRONG**
Pure Tcl. The C side already has its own mode teardown (`abort_operation()`,
`callback.c:246`) and its own ESC arm (`callback.c:6918`), ~~and neither is displaced by
Tk-level seizes — the `break` is what keeps them apart.~~

**CORRECTED 2026-08-11 (issue 0245).** The struck sentence is exactly backwards and the `break`
is not what keeps them apart. Tk fires the **most specific** binding for a bindtag: with both
`<KeyPress>` and `<Key-Escape>` bound on `.drw`, Escape runs *only* the `<Key-Escape>` script —
**with or without `break`** — so a Tk-level seize **does** displace the C ESC arm, completely.
Worse, Tk routes a key to `[focus]`, so a seize on a *form's own toplevel* displaces it just as
effectively as one on `.drw`. Measured under xvfb: an armed `xschem wire` (`ui_state` 65536,
`ui_state2` 1) survived a real canvas Escape **byte-identically** while a placement form was
open. 0245 fixed it by giving the C terminal a name (`escape_terminal()`) and a verb
(`xschem escape`) that every seizing handler forwards to. The D3 verdict itself still stands —
the *stack* is pure Tcl — but "needs no C" was true only by accident.

### D4 — is this worth fixing on its own merits? — OPEN, and now the *only* question
Standalone, it is a latent hazard with no known user-visible symptom (nobody has reported
ASE and Add-Pin fighting). The claim that it "becomes mandatory the moment 0201 is
attempted" was **wrong**, and 0201 shipping without it is the proof — see below. So this
issue now stands or falls purely on its own merits, which is the honest place for it.

## 0201 shipped without it (2026-08-01)

The blocker reasoning was: a descend pick would have to **nest** above ASE's live Button-1
seize, and the slots hold one predecessor each.

The pick does not nest. `hi_descend_pick_arm` calls `cmdmode::suspend_all` **before**
`xschem descend_pick`, so SOD has already handed the canvas back by the time the pick is
armed. The two owners are strictly sequential; each slot still only ever has one occupant.
A stack would have been dead weight on that path.

Two things this changes for *this* issue:

**The hand-back invariant is now measured.** `tests/headless/test_cmdmode_descend_0201.tcl`
legs `CS3a`-`CS3c` assert that suspending a seized mode restores all three slots
**string-identically**, trailing `break` included — the exact property the "`break` is
load-bearing" section says the whole scheme rides on, previously asserted by nobody. Any
future stack must keep those legs green.

**A third aggravating fact, found while doing 0201.** `clone_canvas_bindings`
(`xschem.tcl:13897`) copies `.drw`'s bindings verbatim onto every new canvas at creation
(`xinit.c:2036`, `2252`), and `set_bindings` binds only the *generic* `<ButtonPress>` /
`<ButtonRelease>` / `<KeyPress>` — never `<ButtonPress-1>`, `<ButtonRelease-1>` or
`<Key-Escape>`. So a seize that is live when a window or tab is created is **cloned onto
the child with the owner's key already substituted**: clicks there queue into the parent's
mode, but the child's ESC calls a `sod_end` that restores bindings on the *parent* canvas
only, leaving the child permanently seized with dead scripts. 0201 dodges this by
suspending before any window is created (leg `DS6d` pins it), but a per-canvas stack (D2)
has to handle it head-on: `push` must not inherit a cloned foreign script as its
"predecessor". (Since 2026-11-19 a mode that tells `cmdmode` what it holds is no longer
cloned onto a new canvas: see "After the third repair" at the end, and issue 1307.)

## Merge note

Everything proposed here is a new file plus three small call-site swaps. `ase_window.tcl`
(12 touches in the last 80 `fluid-editing` commits) and `xschem.tcl` (9) are both active;
keeping the mechanism out of them and the edits to three-line replacements is the whole
point.

## Cross-references

* `doc/claude/issues/0201-no-command-suspend-resume-contract.md` — the consumer.
* `doc/claude/issues/0200-descend-has-no-verb-noun-pick.md` — the pick that must nest.
* `doc/claude/specs/ase_l.md` — Select-On-Design's seize/restore.

## Measured, and partly closed, 2026-11-19 (issue 1724)

Issue 1724 gave the Calculator's current selectors a sentence that sent an armed user into
ASE-L's Select On Design, and its second review then drove the stack this file describes.
Everything below was measured on a private Xvfb with openbox, one sequence per fresh
process, with real button, menu, canvas and Escape events, on a real ASE-L session with real
runs. "Free" means the seized slots are absent and an ordinary click on a device selects it.

### The LIFO violation, reproduced (the tree before the change)

Two owners, each with one predecessor per slot: the Calculator's pick (`calc::_pick_seize`,
`calc::pick_release`) and Select On Design (the three binds quoted above).

| sequence | what was done | how the canvas ended |
|---|---|---|
| N | Calculator `it` armed and a miss; Select On Design entered on top and a click; ESC on the canvas; a run; the click again under the still-armed selector; one more ESC | free |
| J | the same stack; then `it` un-pressed in the Calculator while Select On Design was up | all slots empty with Select On Design still recorded as active: its prompt stays, ESC does nothing, its pin marker stays. Select On Design entered again and ended with ESC then installs `calc::pick_click; break` with no pick running: a click selects nothing. Arming `vt` and pressing ESC frees it |
| Q | the same stack; then another selector (`vt`) pressed and a net picked with it | the same orphan; after Select On Design + ESC the canvas is dead. Arming `vt` and pressing ESC frees it |
| C | the same stack; then the Calculator closed | the same orphan; after Select On Design + ESC the canvas is dead. Arming `vt` and pressing ESC frees it |
| K | sequence J with the voltage selector `vt` | dead, as J: the stack does not need the pin pick, and the mechanism is older than issue 1724 |
| W | Select On Design first; `it` armed on top and a miss; Select On Design entered from the menu again; a click, ESC; `it` pressed again | the press slot holds a dead `ase::ui::sod_click …; break`. ESC, Select On Design + ESC, arming `vt` + ESC, closing the Calculator and closing the ASE-L window all left it dead. Only `bind .drw <sequence> {}` typed by hand freed it |

So consequence 1 above ("B is silently disarmed, and B's teardown later restores A's script
over whatever is current") is what happens, and in one order nothing inside the session
recovers: with the tabbed interface every tab shares that canvas.

### What was changed

Not a stack. For this one pair the nesting was removed instead:

- **Select On Design and a Calculator pick end each other.** `ase::ui::select_on_design`
  ends a live Calculator pick as its first act (`calc::pick_end cancel`), before the
  previous mode is ended and before any binding is read; `calc::pick_arm`, once it has
  decided to arm and before it raises the design window, ends a live Select On Design the
  way its ESC does (`calc::pick_end_sod`). The order inside `select_on_design` matters for
  sequence W: the Calculator's release must put the old Select On Design scripts back
  before `ase::ui::sod_end` restores the editor's. On the changed tree J, Q, C, W, K and N
  all end free.
- **Select On Design's seize is one proc**, `ase::ui::sod_seize`, shared by the entry and
  by the resume after a descend. A slot that already holds one of that mode's own scripts
  is never kept as the previous binding (`ase::ui::sod_own_script`): that is "the third
  aggravating fact" above, a seize copied onto a canvas by `clone_canvas_bindings`, and
  issue 1305's permanent seize.
- **All three click modes hold `<Double-Button-1>` as well.** Tk gives the second press of
  a double click to the most specific binding, and `set_bindings` binds that sequence on
  every design canvas, so with only the press seized the second press went to the editor in
  the middle of a mode (its property dialog, modal on an empty sheet; connected-select
  under the Cadence-style profile). Select On Design and the Calculator give the slot the
  press's script; the Results Display Window swallows it. Its predecessor is the first
  seized slot whose predecessor is NOT empty on a design canvas, which matters to any
  future stack: "nothing on record" and "nothing was there" are no longer the same thing
  to hand back (`calc::pick_dbl_editor`).
- **Select On Design holds the canvas's `<Destroy>`**, added behind whatever handler is
  there, so that closing the window the mode is on ends the mode
  (`ase::ui::sod_canvas_gone`, `ase::ui::sod_drop_gone`).

### What still nests: the Results Display Window's pick mode

`rdw::pick_start` is not ended by either of the other two, and ends neither: by its own
rulings ESC is its only exit and keys 1 to 4 are always live. Measured on the tree after
the second repair, nine sequences (the recoveries in this table are the ones of that tree;
"After the third repair" below has them measured again; C2 and D2 by the product's own
doors are closed since the closing pass, and A2 and B2 since the last build: the two
last sections):

| sequence | stack, and the order it was ended in | how the canvas ended |
|---|---|---|
| A1 | RDW, Select On Design on top; ESC, ESC | free |
| B1 | RDW, Calculator pick on top; ESC, ESC | free |
| B3 | RDW, a Calculator pick that resolves, then ESC | free |
| C1 | Select On Design, RDW on top; last-entered first | free |
| D1 | Calculator pick, RDW on top; last-entered first | free |
| A2 | RDW, Select On Design on top; the RDW ended first (Escape in the results window) | Select On Design stays active with no binding and its marker. Entered again and ended, the canvas holds the RDW's dead scripts and a click selects nothing. Arming a selector + ESC, Select On Design + ESC and the RDW key + ESC do not free it |
| B2 | RDW, Calculator pick on top; the RDW ended first | the canvas is free and a click selects, but the pick is still recorded as armed with no binding. Pressing that selector again hands the RDW's dead scripts back to the canvas, and the other two recoveries do not free it |
| C2 | Select On Design, RDW on top; Select On Design ended first, as its session window closing does | the RDW is recorded up with no press binding and a click selects. Escape in the results window then leaves Select On Design's dead scripts on the canvas. Select On Design + ESC makes clicks select again but leaves the double-click slot EMPTY: the editor's double click is gone from that window |
| D2 | Calculator pick, RDW on top; the selector pressed again | the RDW is recorded up with no binding; Escape in the results window leaves the Calculator's dead scripts. Arming any selector + ESC frees the canvas completely |

The recoveries were tried in one fixed order, each from the state the one before left. Two
things these showed beyond D1's proposal, both cured since:

- A2 and B2 could not be recovered because `rdw::_pick_seize` latched whatever the slots
  held, its own dead scripts included: its guard was one level up, in `rdw::pick_start`,
  and covered only a mode that was still recorded as live.
- C2's empty double-click slot was the "nothing on record" fallback of
  `ase::ui::sod_seize`, which handed back nothing for a slot it had no record for. The
  Calculator's seize fell back to the editor's script for that slot.

### Three smaller members of the family, as measured after the second repair

Two of the three are cured since (next section); they stand here as they were measured.

- **The held motion.** Select On Design did not hold `<B1-Motion>` (the Calculator's pick
  and the RDW's do, issue 1304). A click whose hand drifted two pixels with the button down
  queued its pick, cleared a selection made before the mode, and left the editor's rubber
  band up past the mode's own ESC until a second ESC.
- **A window created while Select On Design was up, other than by a descend** (`xschem
  new_schematic create_window`; Ctrl-N under the Cadence-style profile). Its canvas got the
  mode's press, release, Escape and destroy scripts copied; its double click stayed the
  editor's. After the mode ended that window took no left click until a mode was entered
  and ended in it.
- **The second press of a double click after a mode has ended.** A Calculator pick that
  resolves is one-shot and ends on the first release, so the second press is the editor's:
  its property dialog on the wire or device under the cursor, or connected-select under the
  Cadence-style profile. Seizing cannot cure it; a time window after the end could. This
  one is unchanged.

### What this does to the decisions above

- **D4** asked whether the issue is worth fixing on its own merits and called it "a latent
  hazard with no known user-visible symptom". It has one now: a schematic window that takes
  no left click, with nothing saying why. The pair that produced it by the product's own
  advice no longer stacks; the Results Display Window still does, with both.
- **D1**'s stack would have to hold the double click and a `<Destroy>` hook per canvas as
  well as the press, the release, Escape and the held motion, and to tell a slot that was
  empty from one it has no record for.
- **D2** (per canvas) stands, and the cloned-window measurement is its case.

## After the third repair, 2026-11-19 (issue 1724)

A third, short repair of issue 1724 built what the section above had measured and handed
back. Still not a stack: the nesting is as it was. Same display, same probes, same real
events.

### What was changed

- **Select On Design holds the motion with the left button held.** `<B1-Motion>` is the
  sixth slot of `ase::ui::sod_slots`, bound to `break` and handed back by
  `ase::ui::sod_release`. A drag in the mode is one pick, made at the press: the selection
  made before the mode stays, the editor's state does not move and nothing is drawn
  (issue 1304).
- **No seize keeps its own scripts as the predecessors any more.** `rdw::_pick_seize` got
  the guard its two siblings had (`rdw::pick_own_script`: a press or Escape slot found
  holding the mode's own script is not recorded, and the three bare-`break` slots are
  judged by the press slot beside them). With no record the first four slots fall back to
  nothing and the double click to the editor's script, read from the middle button's
  double click (`rdw::pick_dbl_editor`).
- **A lost record no longer deletes the editor's double click.** `ase::ui::sod_seize`
  falls back to the editor's script for a double-click slot it has no record for
  (`ase::ui::sod_dbl_editor`), as `calc::_pick_seize` already did.
- **A window made while a mode is up is not seized.** Each of the three modes tells
  `cmdmode` what it holds on a canvas now (`ase::ui::sod_held`, `calc::pick_held`,
  `rdw::pick_held`, the fourth argument of `cmdmode::register`), and
  `clone_canvas_bindings` asks `cmdmode::pristine` for the script each slot holds
  underneath the modes before it copies one onto a new canvas. This is the "third
  aggravating fact" above; issue 1307 is its own file and has the detail and the limits.
- **A click is resolved where the button was pressed.** The press script of all three
  modes first hands the engine the press's own position. This is not a stack matter; it
  is here because a mode's own dump can lay the windows out again between two presses
  (issue 1659).

### The nine sequences, measured again

The recoveries were tried in the same fixed order, each from the state the one before
left: a Calculator selector armed then ESC; Select On Design then ESC; the results
window's key then ESC.

| sequence | how the canvas ended | what frees it |
|---|---|---|
| A1, B1, B3, C1, D1 (ended last-entered first) | free; a click on a device selects it (C1 and D1 only while nothing descends, as the fourth repair found: next section) | nothing needed |
| A2 | seized on the RDW's dead scripts, as before | the results window's key then ESC. A selector then ESC, and Select On Design then ESC, do not |
| B2 | free, with the Calculator pick still recorded as armed, as before; pressing that selector again hands the RDW's scripts back to the canvas | the results window's key then ESC. Select On Design then ESC does not |
| C2 | seized on Select On Design's dead scripts, as before | Select On Design then ESC, with the editor's double-click script back in its slot. A selector then ESC does not |
| D2 | seized on the Calculator's dead scripts, as before | any selector then ESC |

So the end states of the out-of-order sequences are unchanged, and each can now be left
from inside the session by entering and ending the mode whose scripts were left. Before
this repair nothing freed A2 and B2, and C2's recovery left the double-click slot empty.
Gone through in the order above, the three recoveries left the canvas free in all four,
with the editor's double click in its slot. Other orders were not tried. (None of the
four is reached by a door of the product any more: C2 and D2 since the closing pass, A2
and B2 since the last build. The recoveries are what frees a canvas put into such a
state by hand.)

### What was left of this issue after the third repair

(The last section has what is left now. The first item's "ended out of order the canvas
is still left seized" no longer holds for any door of the product that was found.)

- **The Results Display Window's mode still nests** with Select On Design and with a
  Calculator pick, and ended out of order the canvas is still left seized, or a pick is
  left recorded as armed with no binding. Whether that mode should end, and be ended by,
  the other two (which its own rulings forbid: ESC is its only exit, keys 1 to 4 are always
  live), or whether a stack (D1) is wanted, is unruled.
- **The second press of a double click after a one-shot Calculator pick has ended** is the
  editor's (above).
- **`addpin` / `addlabel`** still hand the ESC slot to each other by name and are party to
  none of this.

## After the fourth repair, 2026-11-19 (issue 1724)

The third review of issue 1724 drove two things the sections above had not: a stack taken
through a descend, and a third mode entered while the Results Display Window's mode sits
on top of another. Both left a canvas that took no left click, or a mode recorded as up
with nothing bound. Both are repaired, and it is still not a stack (D1): the modes nest as
they did. Same display as above (a private Xvfb with openbox), one sequence per fresh
process, a real session, real menu, button, key and Escape events.

### What was changed

- **A descend releases the top of a stack first.** `cmdmode::suspend_all` used to release
  the modes in the order they were registered (Select On Design, the Calculator's pick, the
  Results Display Window's mode). With the Results window's mode ON TOP of one of the other
  two, the lower mode was released first, and the Results window's release then handed the
  lower mode's scripts back to the canvas. `cmdmode::release_order` now reads the order
  from what the modes declare they hold (`<held_cb>`, by canvas and script, with no Tk: a
  mode goes before every mode whose script it names as what its slot held before), and
  `cmdmode::resume_all`, unchanged, puts the stack back bottom first. So a stack keeps its
  order across a descend, and while the modes are paused the canvas holds the editor's
  bindings.
- **The Results Display Window's mode takes the canvas again when a mode is ended
  underneath it.** Select On Design and a Calculator pick end each other wherever the
  other sits. Under the Results window's mode that release wrote the editor's scripts
  over the Results window's live ones. `rdw::pick_reseat` seizes again in exactly that
  state (recorded up, not paused, canvas alive, the press slot holding neither its own
  script nor that of another mode that is up) and is called by `ase::ui::select_on_design`
  after each mode it ends and by `calc::pick_end_sod`. The Results window's mode is not
  ended; the new mode stacks on it. (Those were the callers the fourth repair built; the
  closing pass added `calc::pick_end` and `ase::ui::close`, last section.)
- **A tab's name is resolved to the canvas that shows it** by the Results window's mode
  and by the Calculator's pick (`rdw::_pick_canvas`, `calc::pick_canvas`), at their
  resumes and at the Results window's key. This is "The slot is `.drw` only" above, seen
  from the other side: a context name is not always a widget (issue 1387).

### A stack across a descend

Measured with the release order before the repair put back in memory, and with the
repaired one. Stacks of real modes; the hop is `hi_descend` on a block; then real ESC for
each mode and a real click on a device in each window.

| stack, last-entered on top | the hop | before | after |
|---|---|---|---|
| C1: Select On Design, the Results window's mode on top | a descend in the same window; into a new tab; into a new window | the canvas left on Select On Design's scripts while both modes were paused; the two modes brought back upside down; after ESC, ESC no left click taken (after a descend into a new window: in neither window) | free: both modes come up where the descend lands, stacked as they were; ESC ends them from the top down; a click on a device selects it in every window |
| D1: a Calculator pick, the Results window's mode on top | the same three | as C1, on the Calculator's scripts | free |
| C1, D1 | the descend's own pick (`E` with nothing selected), then a click on the block | the pick never got its click and the modes stayed paused | the click reaches the pick and the modes come back |
| A1: the Results window's mode, Select On Design on top; B1: the same with a Calculator pick on top | all of the above | free | free, unchanged |

So the third repair's row "A1, B1, B3, C1, D1 (ended last-entered first): free" held for
C1 and D1 only while nothing descended. The defect was in `cmdmode`, not in the three
modes, and is as old as two modes registered with it.

A mode whose place cannot be read (it was registered without a `<held_cb>`, or its
`<held_cb>` raises) is neither over nor under any other. It is released as soon as it is
the earliest-registered mode not known to be under another, which can be ahead of an
earlier-registered mode that is waiting for the mode over it (registered low, plain, top
with top over low: plain, top, low). Two such modes go in registration order, and so do
two modes that each name the other's script as what the canvas held before. A stack of
two whose order cannot be read is therefore released top first only when its upper mode
was registered first. The three click modes all declare what they hold. (Reworded by the
closing pass: this paragraph used to say such a stack "is still released in registration
order", which is not what `cmdmode::release_order` does among three modes. No code
changed; row CR6i holds the three-mode case.)

What the table rests on. C1, D1, A1 and B1 are the four stacks the product's own doors
can make (Select On Design and a Calculator pick end each other). They were measured
through a descend into a new window, a `cmdmode::rehome` onto a second window and an
in-place suspend and resume, with the three modes' files frozen at the state the repair
began from and again on the tree as it then stood; the descend into a new tab, the
descend in the same window and the descend's own pick were measured on the tree as it
then stood only. Stacks that hold both Select On Design and a Calculator pick, and
stacks of three, were measured too, by holding the other mode's end off: they show the
order on the real seize, release and resume code, not a state a user can reach. The
probes were not run again after the last edits of the other three modes' files that
day; the registered suites were. Leg DS8 is the display fence for Select On Design under
the Results window's mode: a descend into a new window and, in its second pass (rows
DS8j to DS8q, added by the closing pass), a descend in the same window. A row of band
PG27 of `test_calc_pick.tcl`, added by the same pass, holds a Calculator pick under that
mode across a descend in the same window. Each goes red with the release order of
before the fourth repair put back.

### A third mode entered over the Results Display Window's mode

| order of entry | before | after |
|---|---|---|
| Select On Design, the Results window's key, a Calculator selector | the selector ended Select On Design underneath; the Results window's mode stayed recorded as up with nothing bound: its sentence on the status bar, clicks selecting, its key arming nothing | free after one ESC for each of the two modes that are up |
| a Calculator selector, the key, Select On Design | the same, with the pick ended underneath | free |
| Select On Design, the key, Select On Design again | the same (on the tree before the second repair too) | free |
| the key, Select On Design, Select On Design again; the key, Select On Design, a selector (the Results window's mode at the bottom) | free | free, unchanged |
| the key, a selector, Select On Design (the same) | not measured | free |
| a Calculator selector, the key, ANOTHER selector or the SAME selector again | the Results window's mode stranded as in the first row | after the fourth repair: still stranded. **After the closing pass: free** (next section) |

The first two orders had been clean before the second repair made the two modes end each
other; that repair made them reachable by a selector press or a menu entry. The last row
is the Calculator's own doors: `calc::pick_end`, reached by a selector press, had no call
of `rdw::pick_reseat` after it when the fourth repair ended. The closing pass built it.

### What was left after the fourth repair, and what became of it

- **Ended out of order by something other than ESC**, the end states of A2, B2, C2 and D2
  above stand, with their recoveries. One door of C2 was named here as not measured:
  Select On Design ended by its session window closing while the Results window's mode
  sits on top. Measured by the fourth repair's verifiers (stranded) and built by the
  closing pass (next section).
- **The Calculator's selector doors under the Results window's mode** (the last row of
  the table above): built by the closing pass.
- **The Results Display Window's mode still nests.** Whether it should end and be ended
  by the other two, or whether a stack (D1) is wanted, is unruled, as before.
- **In a tab other than the first** the keyboard stayed in the Results window after a
  dump made in its mode (`rdw::_focus_canvas` tested the context's name as a widget):
  built by the closing pass, it goes back to the schematic.

## After the closing pass, 2026-11-19 (issue 1724)

Four verifiers checked the fourth repair. None refuted it; between them they found the
same defect behind doors nobody had ruled on, and the closing pass built those. Same
display as above, one order per fresh process, real presses and real Escape.

### What was changed

- **Every door that ends a Calculator pick asks the Results window's mode to take the
  canvas again.** `calc::pick_end` runs `catch {rdw::pick_reseat}` directly after its
  release, when the release released a pick. That covers the armed selector pressed
  again, another selector pressed, the Calculator window closed or destroyed, and
  Select On Design entered.
- **So does the ASE-L session window's close.** `ase::ui::close` runs the same call
  directly after `ase::ui::sod_end`.
- **`rdw::_focus_canvas` resolves a tab's name** through `rdw::_pick_canvas`, as
  `rdw::pick_start` and `rdw::pick_resume` have since the fourth repair, so after a dump
  made in a tab other than the first the keyboard goes back to the schematic.
- Nothing changed in `src/cmdmode.tcl` but its comments (the release order of a mode
  whose place cannot be read, above).

### The orders, measured again

The fourth repair's verifier had driven, through the product's own doors, the orders its
bench lists of Select On Design (S), a Calculator selector (C is `vt`, I is `it`, D is
`vf`, which the bench's transient-only result cannot serve) and the Results window's key
(R), two to four steps long, some ending with the Calculator window closed (Q) or the
session window closed (X). It found these not free: C,R,C / C,R,I / I,R,C (a selector
pressed again, or another one), C,R,D, C,R,Q, S,R,X, and C,R,C,I and C,R,C,R, which
stayed stranded whatever was pressed next. The closing pass ran the same bench from a
copy, every order again, on the tree as it now stands.

| order | after the fourth repair | after the closing pass |
|---|---|---|
| C,R,C / C,R,I / I,R,C (the armed selector again; another selector) | the Results window's mode recorded as up, nothing bound | free |
| C,R,Q (the Calculator window closed) | the same | free |
| S,R,X (the session window closed) | the same | free |
| C,R,C,I / C,R,C,R | still stranded | free |
| C,R,D (a selector the result cannot serve, pressed over the stack) | the same, and the `vf` radio lit | no mode recorded, the canvas as the editor has it, a click selects; the `vf` radio still lit |
| C,D / R,C,D (the same press with nothing stranded) | canvas free, the `vf` radio lit | the same, unchanged |
| every order that was free before | free | free, unchanged |

With the new line taken out of `calc::pick_end` in memory, C,R,C, C,R,I, I,R,C and C,R,Q
are not free again, so the cure is that line. The lit radio is not a seize: a selector
the result cannot serve refuses to arm after it has ended the armed pick, and Tk has
already lit its radio (the selector's own rule, in the header of `calc::sel_click`). It
is older than this work and was observed, not judged.

**One consequence, measured.** When the pick is ended by a press in the Calculator
window with the Results window's mode on top, that mode's seize takes the keyboard with
the canvas (`rdw::_pick_seize` forces the focus onto the canvas, where its Escape is
bound): the focus goes from the Calculator's buffer to the design canvas. Keys typed
next go to the schematic until the buffer is clicked. Not changed, and the user's to
rule on.

**Not driven:** Direct Plot's flavour of Select On Design in these orders (they used To
Be Saved, and To Be Plotted once); the design in a tab other than the first; the
non-tabbed interface; the user's X server (every run was a private Xvfb with openbox).
The keyboard after a dump in a tab was measured apart from these orders, in the second
tab only (row XP8 of `tests/headless/test_rdw_keys_1245.tcl`).

### What was left after the closing pass, and what became of it

- **The Results Display Window's mode still nests.** Whether it should end and be ended
  by the other two, or whether a stack (D1) is wanted, is unruled, as before.
- **The Results window's mode ended first from under another mode** (Escape pressed in
  the Results window while Select On Design or a Calculator pick sits on top of its
  mode): after the closing pass the end states of A2 and B2 above stood, with their
  recoveries; that pass did not touch that door. Both were measured again on the tree
  as it then stood, with the bench of the orders above and the mode ended by
  `rdw::pick_end`, the command the Results window's own Escape binding runs (the window
  itself was not opened): after A2 Select On Design was recorded as on with nothing
  bound, its prompt on the bar, ESC on the canvas doing nothing and clicks selecting;
  after B2 the pick was recorded as armed the same way. From either, the three
  recoveries in the order of the third-repair table (a selector then ESC, Select On
  Design then ESC, the Results window's key then ESC) left no mode recorded and the
  canvas as the editor has it. On the way through them the press slot held the Results
  window's script while that mode was not up, the state the tables above call seized on
  its dead scripts. **Built by the last build** (next section): neither state is
  reached any more.
- **C2 and D2 by the product's own doors are closed.** As the nine-sequence table drove
  them (Select On Design ended first, "as its session window closing does"; the
  selector pressed again) they are the orders S,R,X and C,R,C above: free now. Every
  caller of `ase::ui::sod_end` and of `calc::pick_end` in the product that can end a
  mode under the Results window's mode is followed by the reseat. A direct call of
  `ase::ui::sod_end` by name, which no door of the product makes, is not.
- **The keyboard after a pick is ended under the Results window's mode** (above).
- **`rdw::pick_reseat` is called by the doors that were found.** A new door that ends
  Select On Design or a Calculator pick has to call it too; nothing enforces that.
- **The second press of a double click after a one-shot Calculator pick has ended**,
  and **`addpin` / `addlabel`**, as after the third repair.

## After the last build, 2026-11-19 (issue 1724)

Two verifiers checked the closing pass. Neither refuted it. Their list of what was left
held the sibling the section above ends on (the Results window's mode ended first from
under another mode) and a second thing, as old as two modes on one status slot: the
slot changing text on every tick. Both were ruled in, and a last build built them. Same
display as above (a private Xvfb with openbox), one order per fresh process, real
presses and real Escape. It is still not a stack (D1): the modes nest as they did.

### What was changed

- **The mode on top takes the canvas again when the Results window's mode is ended
  underneath it.** `rdw::pick_end`, once its own record is gone and when its release
  released a mode, runs `catch {::ase::ui::sod_reseat}` and `catch
  {::calc::pick_reseat}`. Each is the counterpart of `rdw::pick_reseat` for its own
  mode. It seizes again only when its mode is recorded up, is not paused, its canvas is
  a live widget and the press slot of that canvas holds neither one of the mode's own
  scripts nor the script of another mode that is up; in every other state it does
  nothing, so the call is harmless when nothing was ended underneath. What the mode
  then has on record as the canvas's own is what the canvas holds now, the editor's,
  and its ESC leaves an unseized canvas. Nothing else of the mode moves: its one prompt
  timer, the rows it queued and their count, its pin markers, the armed selector. A
  Calculator pick whose click has resolved, and that is waiting for its release, keeps
  its end on the release slot.
- **A mode writes the status slot only while no other mode that is up is seized over
  it.** `ase::ui::sod_prompt_pump`, `calc::pick_pump` and `rdw::_hint_sync` each ask
  first (`ase::ui::sod_covered`, `calc::pick_covered`, `rdw::_pick_covered`): does the
  press slot of the mode's canvas hold a script that is not the mode's own and that
  `cmdmode::pristine` knows a mode to hold. Each timer keeps running, so the lower
  mode's sentence is back within one tick of the upper mode ending. Where the question
  cannot be asked, or the slot holds anything else (a canvas that is no widget,
  `cmdmode` not there, the editor's script, a script no mode declares, an emptied
  slot), the mode writes as it did before.
- `src/cmdmode.tcl` is unchanged.

### The two orders, measured again

R is the Results window's key with nothing selected, S is Select On Design, C is a
Calculator selector, and "ended" is `rdw::pick_end`, the command the Results window's own
Escape binding runs.

| order | after the closing pass | after the last build |
|---|---|---|
| R, S, then the Results window's mode ended (A2) | Select On Design recorded as on with nothing bound, its prompt on the bar, unchanged through four ESC on the canvas | Select On Design holds the canvas with the editor's own on record; one ESC ends it; free |
| R, C, then the same (B2) | the pick recorded as armed with nothing bound, its selector lit | the pick holds the canvas; one ESC ends it; free, the selector no longer lit |
| either, followed by the three recoveries | free | free, unchanged |
| either, with the design in a second tab | not measured | free (the tab put back in front after every step: issue 1713) |
| every order of the table in the section above | as that table has it | unchanged: free, and C,D / R,C,D / C,R,D with the `vf` radio lit and the canvas free |

The real key was pressed too: Escape in the Results window's text pane, with Select On
Design on top of that window's mode, leaves Select On Design on the canvas, and one
real ESC sent to the canvas then leaves every binding as it was before any mode (row
E6 of `tests/headless/test_rdw_keys_1245.tcl`). The two orders were run once more from
a copy of the bench for this file, on the tree as it stands: free after one ESC.

### The status slot under two stacked modes

Sampled every 20 ms for two seconds with no event sent.

| stack | before the last build | after it |
|---|---|---|
| Select On Design with the Results window's mode on top; the same two the other way round; a Calculator pick with that mode on top | two sentences in turn, the text changing many times a second | one sentence, the top mode's; after one ESC the lower mode's is the only one |
| the Results window's mode with a Calculator pick on top | the same, and a blank | a blank for an instant and then the pick's prompt, as a selector armed with no other mode up shows it; after one ESC the Results window's sentence alone |

Issue 1387 (its section 3) had the two writers down as unarbitrated. This arbitrates the
label, not the canvas: the click was already the top mode's.

### One consequence, measured

Taking the canvas again takes the keyboard with it. `ase::ui::sod_reseat` gives the
canvas the focus as the mode's entry and its resume do, and `calc::_pick_seize` does at
every seize, because each mode's ESC is bound on the canvas. So after Escape pressed in
the Results window's text pane the keyboard is on the schematic (row E6: from the text
pane to the canvas, with a window manager and without one), and with a Calculator pick
on top it moves from the Calculator's buffer to the canvas. The next key typed goes to
the schematic. Not changed, and the user's to rule on.

### What is left of this issue

- **The Results Display Window's mode still nests.** Whether it should end and be ended
  by the other two, or whether a stack (D1) is wanted, is unruled, as before. No door of
  the product that was found leaves a canvas seized any more, in either order; what the
  three modes have in place of a stack is a call behind each door that was found.
- **Those calls are per door.** `rdw::pick_reseat` is called by the doors that end
  Select On Design or a Calculator pick, and `ase::ui::sod_reseat` and
  `calc::pick_reseat` by `rdw::pick_end`. A new door that ends one of the three modes
  without going through those has to make the call too; nothing enforces that.
- **The keyboard after a mode has taken the canvas again** (above, and the closing
  pass's consequence in the section before).
- **The tooltip of the status slot.** While the Results window's mode is under another
  mode, `rdw::_hint_sync` still arms its tooltip on the slot with its own sentence, so
  resting the pointer on the slot can show that sentence over the top mode's text. Read
  off the slot's binding; left as it is by ruling.
- **Not driven:** the real Escape of the Results window with a Calculator pick on top
  (the rows end that mode by `rdw::pick_end`); Direct Plot's flavour on top of that
  mode; the non-tabbed interface; the user's X server. (A mode ended while a descend
  has it paused was on this list. It has been built and driven since: the next
  section.)
- **The second press of a double click after a one-shot Calculator pick has ended**,
  and **`addpin` / `addlabel`**, as after the third repair.

## After the build that followed, 2026-11-20 (issue 1724)

The verifier of the last build drove the order this file had listed as not driven, and
found the last out-of-order hand-back that a door of the product could reach.

### A mode ended while a descend has the stack paused

The descend command given with nothing selected pauses every click mode
(`cmdmode::suspend_all`, the top of a stack first) and waits in the event loop for a
click on an instance. While it waits the canvas holds the editor's bindings and each
paused mode still has on record what the canvas held when it took it. For the upper
mode of a stack that is the lower mode's scripts.

A mode can be ended during that wait: the Results Display Window's mode by Escape
pressed in the Results window; Select On Design by its session window being closed, by
being entered again, or by a Calculator selector being pressed; a Calculator pick by its
selector pressed again, by another selector pressed, by Select On Design being entered,
or by the Calculator window closed. Each end went through the mode's
release, and the release wrote the record back a second time. For the upper mode of a
stack that put the scripts of the lower mode on the canvas while that mode was paused:
the click on the instance was that mode's and nothing descended, and the canvas's Escape
was that mode's too, so it ended the paused mode instead of dropping the descend.
Measured in the order S, R, the descend, Escape in the Results window (the click then
said `ase: nothing to queue there …`), and with a Calculator pick underneath (`selector
vt: xb is not a net`). One ESC on the schematic and a second click completed the
descend, so nothing was left seized; the hand-back was out of order all the same.

### What was changed

`rdw::pick_release`, `calc::pick_release` and `ase::ui::sod_release` write nothing for a
mode that is marked paused, and answer that there was a mode to end. The ends go on as
before: the record is dropped, Select On Design says what it queued and Direct Plot
plots it, the armed selector goes out. The three suspend arms are not reached by the
change: each tests for a paused mode before it calls the release and answers 0 for one
(Select On Design's arm was given that test with this build; before, asked a second
time, it answered 1). `src/cmdmode.tcl` is unchanged: it still holds the name
of the ended mode to put back, and that mode's resume arm answers 0.

### Measured after it

In both stack orders and through every door named above that enters no mode (Escape in
the Results window, the session window closed, the armed selector pressed again, the
Calculator window closed), read straight after the end:
the canvas has the bindings it has with no mode up; the mode that was ended has no
record, no timer and no sentence on the status slot; the other mode is still paused
and the descend still waits. The first click on the instance then descends, and the
mode that is left comes up alone on the canvas the descend lands on, over what that
canvas has of its own; one ESC ends it. Where the descend is dropped instead (Escape on
the schematic, or a chooser that finds no views), that mode comes back in place. With
each release's test taken out again in memory the canvas is back on the paused mode's
scripts in each of those orders.

With the ended mode UNDER the other one its record is the editor's own, so writing it
again changed no binding; the only thing the change does there is that the status slot
is not blanked for an instant under the other mode's sentence.

A mode ENTERED during the wait (the Results window's key, Select On Design, a selector)
is up at once on the canvas and takes the clicks until its ESC, the click on an instance
among them. That is the user's own key and was not changed.

The orders this file has tables for were driven again after the change and end as they
did: every order of the three modes, the two orders of the last build with their
recoveries in the first tab and in a second tab, the descend orders in the same window
and into a new window, and the stack matrix.

### What is left of this issue

As after the last build, less the order above: the Results Display Window's mode still
nests, the calls that stand in for a stack are per door, the keyboard goes to the
schematic when a mode takes the canvas again, and the tooltip of the status slot.

- **Not driven:** a descend into a new tab after a mode was ended during the wait; the
  design in a second tab or in the non-tabbed interface for these orders; the modal
  chooser itself (the order bench stands in for it with its success path, and the suite
  rows end the wait by a door that opens no chooser); the user's X server.
