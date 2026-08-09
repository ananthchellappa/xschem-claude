# Next session — issue 0265: nothing tears down a pending paste, so a second `Ctrl+V` silently commits the first

Paste everything below the line as the opening prompt of a fresh session.

Every anchor and every measurement below was derived on the **post-0244 working tree** (branch
`open_pdk`, `7da044ff` + the uncommitted 0244 fix). If the 0244 work has been committed since,
re-grep the quoted statements — do not trust the line numbers.

---

Work on **issue 0265** — `doc/claude/issues/0265-nothing-tears-down-a-pending-merge.md`.
Read that file first, in full, plus:

- `doc/claude/issues/0244-aborted-paste-marks-a-dirty-schematic-clean.md` section **THE FIX** —
  you are factoring out the teardown it built, and its "shared slot" riders are load-bearing here;
- `doc/claude/issues/0267-pre-merge-modified-latch-is-consumed-at-an-arbitrarily-later-esc.md` —
  it **falls out of this work**, do not fix it separately;
- `doc/claude/issues/0242-any-second-arm-orphans-a-live-placement-preview.md` — the same class,
  one dimension over, and the source of `leave_placement_for()`, which you are cloning;
- `doc/claude/WIRING.md` §8 class **D** and §10 (traps first).

Branch is `open_pdk`. Number any new issues from **0268** (0264-0267 were filed closing 0244).

## What it is

`STARTMERGE` has exactly **one** setter (`merge_file()`, `src/paste.c:749`) and three
teardown-bearing clears: the commit tail (`src/move.c`, in the `if(!commit_now)` block) and
`abort_operation()`'s two arms (`src/callback.c:420` nested, `:492` bare). Every **other** way the
bit disappears is `unselect_all()`'s wholesale `xctx->ui_state = 0` (`src/select.c`), which fires
whenever anything is selected — and a pending paste is *always* selected, because that selection is
what the drag carries.

So the pending paste is never cancelled by a second gesture; it is silently **accepted**.
`leave_placement_for()` (`src/callback.c:777`) — which `merge_file()` already calls at `paste.c:563`
— is gated purely on `START_SYMPIN|PLACE_SYMBOL|PLACE_TEXT` and never inspects `STARTMERGE`, so
0242 closed only the *placement-then-merge* direction.

## Reproduce first — both doors, measured on the post-0244 tree

`doc` = 1 wire (dirty); `src.sch` = 1 wire.

```
A  merge twice, then ESC
   before        wires=1 ui=0
   merge #1      wires=2 ui=296   (STARTMERGE|STARTMOVE|SELECTION)
   merge #2      wires=3 ui=296   <-- paste #1 still in the drawing, no longer pending
   after ESC     wires=2          <-- only paste #2 removed; paste #1 is COMMITTED

B  merge, then a placement arm, then ESC
   merge armed   wires=2 inst=0 ui=296
   place_symbol  wires=2 inst=1 ui=8232   <-- STARTMERGE gone, merged wire committed
   after ESC     wires=2 inst=0           <-- only the placement torn down; the paste stays
```

Both runs also print, from the fluid layer:

```
fluid_editing: fluid_gesture_arm() re-armed while a prior gesture was still armed -- it leaked its
snapshot (WIRING risk #11.10 mid-STARTMOVE abandon); recovering
```

That message is a free second oracle: a correct fix should silence it on these sequences.

Constructors: `xschem merge <file>` and bare `xschem paste` are both `merge_file()`;
`xschem place_symbol devices/lab_pin.sym` arms a placement; **commit is
`xschem move_objects end 0 0`** — see landmine 2.

## Part A — `leave_merge_for()` (mandatory)

**Factor the teardown, do not copy it a third time.** The duplication between
`abort_operation()`'s two `STARTMERGE` arms is *literally how issue 0244 was born* — the 2022 fix
for the placement arm was never carried across to the copies (0244's root-cause section). Three
call sites of the same four statements is where that starts again.

New `int leave_merge_for(const char *what)` in `src/callback.c`, immediately beside
`leave_placement_for()` (`:777`), same shape:

```
  if(!xctx) return 1;
  if(xctx->gate_bypass) return 1;            /* test-only seam, xschem.h gate_bypass */
  if(!(xctx->ui_state & STARTMERGE)) return 1;
  if(xctx->readonly) return 1;               /* the teardown IS a delete() */
  ... the teardown ...
  statusmsg_hold("<what>: pending paste abandoned", 1);
  return 1;
```

The teardown body is the nested arm's, verbatim (`callback.c:445-467`): the pending move must be
dropped first (`move_objects(ABORT)` — `abort_operation()` has already done that when *it* calls;
a fresh caller has not), then

```
  if(select_placement_preview() > 0) delete(1); else draw();
  clear_placement_preview();
  xctx->ui_state &= ~STARTMERGE;
  if(!xctx->pre_merge_modified) set_modify(0);
```

**Decide, and say why in a comment: does `leave_merge_for()` own the `draw()`?** In
`abort_operation()` that `draw()` pays a repaint debt created by `select_placement_preview()`'s
`dr=0` unselect on an arm that returns early; a caller that redraws anyway (`merge_file()` is about
to load and draw) does not need it. A `dr` parameter is acceptable; a silently-wrong repaint is not.

Then call it:

1. **`merge_file()` (`src/paste.c`), before `xctx->push_undo()` at `:582`** — i.e. beside the
   existing `leave_placement_for()` at `:563`, and necessarily **before** the `unselect_all(1)` at
   `:583` that currently destroys the bit. Ordering is the whole point: the previous paste's
   `delete(1)` must land before the new merge's undo baseline is taken, exactly as the 0242 comment
   at `paste.c:546-562` argues for the placement teardown.
2. **Every placement arm** — the twelve `stamp_placement_preview()` sites
   (`grep -n 'stamp_placement_preview()' src/*.c`: actions.c 1, callback.c 4, draw.c 1,
   scheduler.c 7; the select.c hit is the definition). Enumerate them from the state the teardown
   owns, not from the verbs the bug report named — that is 0242's coverage lesson, and its census
   was still five arms short.

**0267 closes as a byproduct**, and that is not a coincidence: with the pending merge torn down at
the next gesture, the `pre_merge_modified` latch is always consumed by the ESC that immediately
follows its own arm, so it can never describe a document several edits stale. Assert it (a row where
a real edit happens between the arm and the ESC).

## Part B — plan phase 4's remaining direction (recommended, same session)

`doc/claude/suggestions/plan_modal_gesture_exclusion.md` phase 4 is now unblocked and half done:
*merge cancels a live draw* already works (`merge_file()` calls `leave_placement_for()`, which is
the wire/line teardown too). The missing direction is *a draw cancels a live merge* — call
`leave_merge_for()` from the same sites `leave_placement_for()` is called from
(`callback.c:4552`, `:4561`, `:6801`, `:7248`, `:7504`, `:7536`, and the text arms `:4587`/`:7323`).

Do it unless it goes wrong, and say plainly if you drop it. Tick the phase-4 boxes in the plan.

## Landmines / traps

1. **Do NOT put the teardown inside `unselect_all()`.** 87 C call sites and 817 scripted ones,
   several inside netlisting and live fluid passes; it would make a *deselect* silently delete
   objects. That is issue 0123's stated reason, re-ratified by 0262 for the bare `unselect_all`
   verb — which is deliberately left ungated. Gate the **arms**.
2. **`xschem move_objects END` is a silent no-op** (issue **0266**): the sub-verbs are compared
   lowercase, so `END` falls through to the one-shot form's `else` and merely arms a deferred menu
   move (`ui_state |= MENUSTART`, measured `296 → 65832`) while the paste stays pending. Commit with
   `xschem move_objects end 0 0` / `xschem paste <dx> <dy>` (both measured `→ ui_state 8`).
3. **The bare `STARTMERGE` arm is constructible**: `xschem merge f` + `xschem move_objects abort`
   leaves `ui_state 264` (STARTMERGE|SELECTION, no STARTMOVE). Any teardown you add must be correct
   from that state too.
4. **`xschem saveas` zeroes `modified`** — a "clean" fixture must be built by save+load and the flag
   read *after* the load, never after a `saveas` taken mid-measurement.
5. **The shared `preview_sel` slot.** Read the riders at `callback.c:429-444` before writing any
   teardown: the merge and the placement stamps live in the same slot, and that is safe only
   because every arm stamps and `abort_placement_preview()` is *gated*. A `leave_merge_for()` that
   runs while a placement is armed must not eat the placement's stamp — and vice versa. This is the
   single most likely way to introduce a silent whole-document delete here.
6. **WIRING.md §7 landmine 17** — any new stamping code filters on the `sel` VALUE, not on
   membership in `sel_array`.
7. **Test seams that do NOT exist**, learned the hard way in the 0244 session: there is no
   `xschem get fluid_editing`, and `xschem set fluid_editing <v>` is a **silent no-op** (not a
   C-mirrored name). Write the Tcl global directly (`set ::fluid_editing 1`) and **assert** it —
   a section that silently runs with fluid editing off is a hollow pass.
8. **The clipboard is process-global and not redirectable from a script.** `clip_file` is a C
   snapshot of `$USER_CONF_DIR/.clipboard.sch` taken in `Tcl_AppInit`; running any paste test
   overwrites the developer's real clipboard, and a concurrent `Ctrl+C` reddens the run. Re-prime
   immediately before each paste row (`primed_doc` in the 0244 test is the worked example).
9. **Sabotage runs lie if `make` did not rebuild** — `rm` the object file, do not trust mtimes, and
   re-run the clean baseline after every restore (WIRING §10).
10. **GUI gate**: press **Allow 30m / Allow 2h** once on the panel rather than Proceed per run.
11. **`xschem callback …` segfaults under `--nogui`** — arm with verbs, not clicks.

## Tests

RED-first. **Extend `tests/headless/test_paste_modify_flag_0244.tcl`** rather than starting a new
file: its fixture (2 wires + 1 instance + 1 text + 1 line, a merged file with one of each, the
`primed_doc`/`rec0244`/`labcount`/`textcount` helpers and the 129 green checks) is exactly what
these rows need, and a sibling file would duplicate all of it. Add a section **E**:

- **E1** merge, merge again → paste #1 is **gone**, not committed; `wires` back to 2 before the
  second paste lands; the fluid re-arm warning does not appear;
- **E2** merge, then each placement arm (`place_symbol`, `add_wire_label -place`,
  `add_sch_pin -place`, `add_symbol_pin -place`, `net_label 0`, `place_text`) → the paste is gone,
  the placement is live, and one ESC leaves the fixture intact;
- **E3** the reverse (already passing — a control): placement armed, then merge → the placement is
  torn down, no orphan, `sympin_preview == 0`;
- **E4** the **0267 row**: clean doc, merge, `move_objects abort`, a real edit
  (`xschem wire 2000 2000 2100 2000` + a text), ESC → the edit survives **and `modified == 1`**.
  Pre-fix this measures `wires=3 inst=1 texts=1 modified=0`;
- **E5** part B: wire/line verb on a live paste → paste gone, draw armed, fixture intact;
- **E6** controls that must **not** move: an ordinary merge+ESC still removes exactly the paste
  (the whole of sections A/C/D must stay green), and a merge in a **readonly** window arms nothing.

Every new predicate gets a sabotage variant with a named red check, and the red sets must be
**disjoint** from 0244's existing three (S1 15 flag rows / S2 23 geometry rows / S5 5 D8 rows).
**Report what the sabotage actually did, including when a predicted red does not appear** — in the
0244 session two predicted detectors turned out not to exist, and saying so was worth more than the
prediction.

Record the table in issue 0265 the way 0244, 0242 and 0241 do.

## Tiers that must stay green (all measured 2026-08-08, post-0244)

| tier | today |
|---|---|
| `test_paste_modify_flag_0244.tcl` (`--nogui`) | 129 |
| `test_add_wire_label.tcl` | 178 |
| `test_placement_preview_doors.tcl` (`--nogui`) | 115 |
| `test_placement_wire_gate.tcl` (`--nogui`) | 171 |
| `test_sch_add_pin.tcl` | 21 |
| `test_label_ride.tcl` | 157 |
| `test_label_strand_oracle.tcl` | 32 |
| `test_wire_split` / `test_crossview_paste` / `test_instance_update` | `OVERALL: ok` |
| the replay/log group (`run_suites.sh --logdir`): `test_paste_at_log`, `test_sympin_drop_log`, `test_gesture_end_log`, `test_delete_cut_selflog`, `test_rotmove_drop_log`, `test_action_log_dispatch`, `test_actionlog_suppress_gate`, `test_perform_action_undo`, `test_perform_action_redo` | 9/9 |
| `tests/headless/wireedit/run_wireedit.sh` | `WIREEDIT: ALL PASS` |
| `tests/headless/run.sh` | 6 goldens, `HARNESS: PASS` |
| `cd tests && tclsh run_regression.tcl` | 3 pre-existing FAIL lines |

**Known-red before you start — not yours, do not chase.**

Verified in the 2026-08-08 0244 session, by stashing `src/` and rebuilding:
- `run_regression.tcl`: 3 lines from one defect — `test_ihp_sg13g2_libmgr` expects 9 libs and the
  tree has 10 (`sg13g2_tests_ase`), which also fails `test_pdk_launcher`.
- **`test_fluid_editing` under X**: `FAIL: FE8 drag-and-return changed the arc AND left buffer
  MODIFIED (no false-clean) (mod=1 a=30)`. It **self-SKIPs under `--nogui`**, which is why the
  regression run never sees it — so run it as `run_suites.sh test_fluid_editing` if you touch
  `move.c`, and expect this one line.

Carried from the previous session prompt, **not re-verified** — confirm before blaming yourself:
- `tests/headless/test_action_replay.sh`: "log missing placed instance";
- `test_selflog_output`: 6 transform-key checks (§3e runs against an empty schematic — test rot);
- `test_ciw`: "no result/error text in file" (spec decision 7, superseded by issue 0070 D1).

## Mechanics

- Build: `cd src && make`. Single case:
  `./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl`
  (drop `--nogui` and add `--logdir $(mktemp -d)` for the log group; `test_placement_wire_gate.tcl`
  has `callback` calls yet **hangs** under X and must run `--nogui`, so wrap runs in `timeout`).
- `run_suites.sh` scores only the last `^RESULT` line and passes `--nolog`, so `*_log` tests come
  back `RESULT: SKIP (no log)` → FAIL there; `full_audit.sh` accepts `RESULT: ALL PASS` **or**
  `OVERALL: ok` and auto-discovers `tests/headless/test_*.tcl` (only the `nogui_tests` /
  `logdir_tests` / `nolog_tests` arrays need an entry, space-padded).
- ~7.8 GB box: do not rebuild while a multi-agent fan-out is live.
- Commit when I ask, not before. No push.

## Deliverables

- The code: `leave_merge_for()`, its call sites, and the two `abort_operation()` arms reduced to
  calling it — with comments that name the issue and explain the ordering constraint in
  `merge_file()` rather than restating what the code does.
- The new test section, with the sabotage runs and their red sets, and the disjointness statement.
- Issue **0265** → FIXED: anchors corrected, sabotage table recorded, explicit statement of which
  arms were gated and how you enumerated them.
- Issue **0267** → FIXED (or an explicit statement of why it did not fall out).
- `plan_modal_gesture_exclusion.md` phase 4: tick what landed; if part B is complete, close the
  phase and say whether anything downstream is now unblocked.
- `WIRING.md` §8 class **D**: 0265 is the merge dimension of that class — mark it, and say whether
  the class is now closed or what is left (**0262**, **0263** are the known residues; do not touch
  them).
- Tell me plainly what changed for the user: pressing `Ctrl+V` twice, or starting any other
  placement/draw while a paste is riding the cursor, now **abandons** the pending paste instead of
  silently dropping it into the schematic. Someone who relied on "paste, then click a menu, and it
  lands" will see a behaviour change; it is the ratified rule (*whatever you just pressed is what
  you meant*), the same one 0240/0242/0243 applied everywhere else.
