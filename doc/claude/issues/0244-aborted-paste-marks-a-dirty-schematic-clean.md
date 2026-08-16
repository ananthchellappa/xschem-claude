# 0244 — ESC-ing a paste/merge marks an already-dirty schematic **clean**, so the save prompts stop firing and File ▸ New then deletes the autosave backup

Status: **FIXED** 2026-08-08 — both halves (part A the flag, part B the scope of the delete).
129 checks in `tests/headless/test_paste_modify_flag_0244.tcl`; three sabotage runs with disjoint
red sets (15 / 23 / 5) and two more that produced no red at all, reported as such. See **THE FIX** at the bottom. **Major**: silent loss of real edits, no prompt anywhere.
Area: `src/callback.c:401-405` and `:413-416` — two `set_modify(0);` calls in `abort_operation()`'s
merge arms, where the placement arm eight lines above uses save/restore
Tests: none — `grep -rn 'get modified' tests/` has 30 hits, **none** in a test that also pastes or
merges. The measurable regression surface in the suite is empty.
Found: 2026-08-06, verifying issue **0240**'s out-of-scope list (its pre-existing item 4)
Related: **0240** (parent), **0241** (`Ctrl+A` amplifies this into whole-document loss reported
clean), **0242** (the same abort path's other half), `doc/claude/issues/0235` (a different
modified-flag blind spot).

## Repro

```tcl
set ::autosave_backup 0
xschem clear force
xschem wire 0 0 100 0      ;# one real edit -> modified=1
xschem unselect_all
puts "before paste: modified=[xschem get modified]"
xschem merge <any .sym>    ;# == Ctrl+V; both are merge_file()
puts "paste armed : modified=[xschem get modified] ui=[xschem get ui_state]"
xschem abort_operation     ;# ESC
puts "after  ESC  : modified=[xschem get modified] wires=[xschem get wires]  <-- MUST be 1"
```

```
before paste: modified=1
paste armed : modified=1 ui=296        ;# STARTMERGE|STARTMOVE|SELECTION
after  ESC  : modified=0 wires=1       <-- the wire is still there; only the flag is a lie
```

Ctrl+C / Ctrl+V form is identical (`1 → 1 → 0`). Controls:

| control | result |
|---|---|
| real edit, ESC with nothing pending | `1 → 1` correct |
| **clean** doc, merge, ESC | `0 → 1 → 0` correct — the only case the comment contemplates |
| real edit, merge, **commit** the drop | `1` correct |
| placement arm (`add_wire_label -place`) + ESC on a dirty doc | `1 → 1` correct — this arm got the save/restore idiom |

## Consequence chain (measured, real named cell, `autosave_backup 1`)

```
0 loaded clean   modified=0 hier_mod=0 wires=1
1 REAL EDIT      modified=1 hier_mod=1 wires=2   backup exists=1
2 merged         modified=1 hier_mod=1 wires=3
3 after ESC      modified=0 hier_mod=0 wires=2   backup exists=1
     backup holds the CORRECT post-abort content; the on-disk cell does NOT
=== xschem clear  (File > New) ===
     backup exists=0        <-- recovery file destroyed, no prompt was ever shown
```

`hierarchy_modified()` → 0 (`save.c:3585-3590`) kills every gate: the exit / close prompts
(`scheduler.c:3126`, `:3139`, `:3169`, `:3181`), `save()`'s `if(force || xctx->modified)`
(`actions.c:628`), and `go_back()`'s ascend prompt (`actions.c:3797`). `clear_schematic()` then runs
`if(cancel == 1) cancel=save(1, 0);` followed by `remove_backup()` (`actions.c:3895-3904`) — the
save returns silently because the flag says clean, and the recovery file is deleted.

**Do not write "autosave covers it" in a fix.** The `~` file is correct only until the next
File ▸ New / cell open, which is exactly the gesture that destroys it.

Amplifier: `Ctrl+A` while the paste is pending, then ESC → `wires 3 → 0` **and** `modified=0` —
the whole schematic deleted and reported clean (that deletion is issue **0241**; this issue is why
nothing prompts). Geometry is recoverable by `undo` here — this arm's `delete(1)` does push undo —
but nothing tells the user to press it.

Post-0240 widening: with a live wire draw on top of the pending paste, one ESC now also reaches the
clobber. Before 0240 that path took the old early `return` and the flag survived — while orphaning
the preview instead (0240 defect 2). The trade is strictly better, but this issue is what is left.

## Root cause

```c
src/callback.c:401-405            /* nested in the STARTMOVE arm -- the repro hits this one */
   if(xctx->ui_state & STARTMERGE) {
     delete(1/* to_push_undo */);
     xctx->ui_state &= ~STARTMERGE;
     set_modify(0); /* aborted merge: no change, so reset modify flag set by delete() */
   }
```

`:413-416` is the same three lines for `STARTMERGE` without `STARTMOVE`. The comment is true only
for a document that was clean before the paste. `delete()` set the flag at `select.c:788`
(`if(deleted) set_modify(1);`), but the *pre-merge* value need not be 0, and `set_modify(0)` writes
it flat (`actions.c:193`).

The correct idiom is eight lines above, in the placement arm (`callback.c:383-394`), and it was
introduced **for exactly this bug in the placement case** — `0bb4c9f2` (2022-09-26, *"Aborted place
symbol operation will no more set schematic status to modified"*). The merge arms never got it:
`:413-416` predates it (`f5f6b681`, 2021-11-04) and `:401-405` is a verbatim copy made in `48968f0e`
(2025-08-25) — the shape was duplicated, the 2022 fix was not carried across.

The abort is otherwise a faithful restore, which is why this is a flag-only bug: `merge_file()` does
`push_undo()` (`paste.c:546`) then `unselect_all(1)` (`:547`) *before* loading, so the merge
selection is exactly the merged objects and `delete(1)` removes exactly them (measured
`wires 2 → 3 → 2`). No trim/weld happens at merge time.

## Fix — the obvious one is wrong

**The placement idiom cannot be copy-pasted.** `merge_file()` ends with an unconditional
`set_modify(1)` (`paste.c:704`), so by the time `abort_operation()` runs `xctx->modified` is
*always* 1 and `save = xctx->modified` would read the already-clobbered value — leaving a clean
document dirty after every Ctrl+V/ESC (breaking control B). The placement arm is safe only because
*arming* a placement does not dirty the flag (measured: `add_wire_label -place` on a clean doc →
`modified=0`). So the pre-merge value must be **latched**.

Three edits:

1. `src/xschem.h`, beside the existing pending-merge state at `:1561`
   (`char merge_source[PATH_MAX];`):
   `int pre_merge_modified;  /* paste.c: xctx->modified BEFORE the pending STARTMERGE */`
2. `src/paste.c`, inside `if(fd) {`, beside the `merge_source` latch at `:540` and **before** the
   first mutation (`push_undo()` at `:546`): `xctx->pre_merge_modified = xctx->modified;`
3. `src/callback.c:404` and `:415` — replace `set_modify(0);` with
   `if(!xctx->pre_merge_modified) set_modify(0);`

Using the `if(!…)` form rather than `set_modify(xctx->pre_merge_modified)` avoids a redundant second
`write_backup()` on the dirty path — `delete()`'s `set_modify(1)` (`select.c:788`) already wrote the
`~` file with the correct restored content.

Staleness is a non-issue: both arms run only under `STARTMERGE`, which only `merge_file()` sets, and
it always latches first. The empty-merge early clear (`paste.c:698`) leaves the latch set but
`STARTMERGE` cleared, so it is never read.

**Fix both arms.** `:413-416` is not reachable in the repro (a merge always leaves
`STARTMOVE|STARTMERGE` together, `paste.c:686`), but it is reachable by code inspection:
`move_objects(ABORT)` (`move.c:8954`) and the zero-delta early return (`:9064-9085`) both clear
`STARTMOVE` and return *without* clearing `STARTMERGE` (that clear is at `:10089`, past the early
return), so a click-without-drag release on a pending paste followed by ESC lands there. Do not
assume it is dead code.

## Tests to add (RED-first)

New section in `tests/headless/` (append to `test_paste_at_log.tcl` or a new file): the four control
rows above — dirty+paste+ESC → 1, clean+paste+ESC → 0, dirty+ESC-with-nothing-pending → 1,
dirty+paste+commit → 1 — plus `hierarchy_modified` on the first row. Sabotage (`if(1)` on the new
guard) must turn exactly the dirty rows red.

## Landmines

- **User-visible behaviour change:** after ESC-ing a paste on a dirty document the title keeps its
  `*` and Close / Quit / File ▸ New / ascend now prompt. That is the intent, but someone used to
  "ESC cleans the star" could report it. `set_modify(0)`'s `mod==0 && prev_set_modify` branch
  (`actions.c:203`) also does the Netlist/Simulate/Waves button recolor; the `if(!pre_merge_modified)`
  form keeps that call on exactly the paths that had it.
- **`hierarchy_modified()` has a related blind spot** that makes this worse than it looks: at top
  level its backup loop (`save.c:3591-3595`) walks only *ancestors*, so the current cell's own `~`
  file — which at that moment holds the unsaved truth — is not treated as evidence of unsaved work.
  Arguably its own (much smaller) issue; it is what turns a flag lie into a missing prompt with a
  perfectly good recovery file on disk.
- **Verified NOT part of this bug:** the `STARTCOPY` arm (`callback.c:408-412`) calls only
  `copy_objects(ABORT)` (`move.c:706-722`), which contains no `set_modify()` at all; its
  `pop_undo(0, 0)` passes `set_modify_status = 0` (`in_memory_undo.c:587`), i.e. it errs dirty.
  The other `set_modify(0)` sites in the tree are legitimate (`actions.c:3940` fresh untitled
  buffer, `save.c:3661/3828/3837/3873/3891` load/save, `scheduler.c:3134` post-swap destroy).
- Scripted flows that quit after an aborted paste and relied on no prompt need `force`; the headless
  tests already use `xschem clear force` / `--nogui`, which bypass it.

---

# THE FIX (2026-08-08)

Landed on `open_pdk`. Two independent defects on the same two arms, fixed together because the
second is only *visible* once the first is fixed (part A makes the flag correctly say "dirty" after
a `Ctrl+V` + `Ctrl+A` + ESC — while the drawing is still gone).

All anchors below were re-derived at `7da044ff`; the line numbers in the sections above are the
pre-fix ones and were already stale by ~20 lines when this was implemented.

## Part A — the flag

1. **`int pre_merge_modified;`** on `Xschem_ctx` (`src/xschem.h`, beside `merge_source`, which is
   the other per-window "pending merge" field).
2. **The latch** in `merge_file()` (`src/paste.c`), after `leave_placement_for()` and before
   `xctx->push_undo()` — i.e. after the 0242 placement teardown and before the merge's first
   mutation. It **must** be latched: `merge_file()` ends with an unconditional `set_modify(1)`, so
   the save/restore idiom the placement arm uses (`save = xctx->modified` at abort time) would read
   the already-clobbered value and leave a **clean** document dirty after every `Ctrl+V`/ESC.
3. **Both arms** of `abort_operation()` (`src/callback.c`): `set_modify(0);` →
   `if(!xctx->pre_merge_modified) set_modify(0);`. The `if(!…)` form rather than
   `set_modify(xctx->pre_merge_modified)` avoids a second, redundant `write_backup()` on the dirty
   path (`delete()`'s own `set_modify(1)` already wrote the `~` file with the restored content) and
   keeps `set_modify(0)`'s `mod==0 && prev_set_modify` button-recolor branch on exactly the paths
   that had it.

## Part B — the scope (issue 0241's machinery, reused)

4. **`stamp_placement_preview()`** in `merge_file()` immediately before `ui_state |= STARTMERGE`.
   The stamp is the selection, which on this path is exactly the merged objects (`push_undo()` +
   `unselect_all(1)` run *before* the load) plus the pin name views `synth_pin_views()` just added.
5. **Both arms** wrap the bare `delete(1)` in `if(select_placement_preview() > 0)`, with 0241's
   backstop (resolves to nothing → delete nothing) and, on the nested arm, 0241's `else { draw(); }`
   repaint debt (that arm returns before the function's own `draw()`; the bare arm falls through to
   it and owes nothing).
6. **The stamp is cleared** where the gesture ends: both arms after their delete, the commit tail
   (`move.c`, inside the `if(ui_state & STARTMERGE)` that already existed there — this is also the
   door for the scripted `xschem paste dx dy` / `move_objects end dx dy` forms, which reach
   `move_objects(END)` without passing `end_place_move_copy_zoom()`'s clear), and the empty-merge
   early clear (`paste.c`).

### The slot-sharing decision — SHARE, and why

The merge stamp lives in the **same** `xctx->preview_sel` slot as the placement preview. This was
verified rather than assumed, and the census **refuted the premise the plan offered** ("0242
guarantees a merge and a placement are never co-armed"): 0242 closed only *placement-then-merge*
(`merge_file()` calls `leave_placement_for()`). **Nothing tears down a pending `STARTMERGE`**, so
merge-then-placement is reachable. Sharing is still correct, on two properties, both now stated in
comments at the reader (`callback.c`) because nothing enforces them:

- `abort_placement_preview()` is **gated** — it returns at its first line unless a placement bit is
  set, and its `clear_placement_preview()` is its **last** statement. Making that teardown
  unconditional, or hoisting the clear above the gate, would make the merge delete silently resolve
  0 objects while `set_modify()` still ran: **this issue, restored**.
- Of the twelve placement arms, eight run `unselect_all(1)`, which zeroes `ui_state` wholesale and
  therefore destroys `STARTMERGE` before writing their stamp. The four that do not (ctx-menu text,
  `t`, the screen grab, `place_net_label()`'s failed-`place_symbol` path) leave the merged objects
  **selected**, so their stamp is a **superset** and their teardown removes the paste along with the
  placement — after which the merge arm resolving 0 is the *correct* answer, not a lost stamp.

A separate `merge_sel` field would behave identically in every reachable sequence.

## Both arms are reachable, and the second one is testable

The issue predicted the bare `STARTMERGE` arm (the one **not** nested in `STARTMOVE`) would have no
headless constructor. It does: `move_objects(ABORT)` clears `STARTMOVE` and returns **without**
clearing `STARTMERGE` (that clear lives in the END tail, past the return), and the
`xschem move_objects abort` verb reaches it directly:

```
xschem merge <f>            ui_state 296   (STARTMERGE|STARTMOVE|SELECTION)
xschem move_objects abort   ui_state 264   (STARTMERGE|SELECTION)      <-- the bare arm's state
xschem abort_operation      -> pre-fix: modified 1 -> 0, and +Ctrl+A wiped the document
```

Section **C** of the test covers it with the same rows as the nested arm. In the GUI the same state
is a click-without-drag release on a pending paste.

## Measured, at `7da044ff` (pre-fix) → post-fix

```
A dirty + merge + ESC   modified 1 -> 1 -> 0     BUG      now 1 -> 1 -> 1
B clean + merge + ESC   modified 0 -> 1 -> 0     correct  unchanged (the control)
C dirty + bare ESC      1                        correct  unchanged
D dirty + merge + commit 1                       correct  unchanged
E dirty + merge + Ctrl+A + ESC   wires 2 -> 0, modified 0   now wires 2, modified 1
F clipboard `xschem paste` form: identical to A in every row
```

## Tests

**New file `tests/headless/test_paste_modify_flag_0244.tcl`** — 129 checks, true-headless
(`--nogui`, no `xschem callback`). Registered in `tests/run_regression.tcl`'s `hcases` (so it prints
`OVERALL: ok` as well as `RESULT: ALL PASS`) and in `tests/headless/full_audit.sh`'s `nogui_tests`.

Sections: **A** the four control rows × both doors (`xschem merge <file>` and the clipboard
`xschem paste`), plus A5/A6 which alternate dirty and clean rows so a latch that is never refreshed
(or stuck at either value) cannot pass; **B** `hierarchy_modified` on the dirty and the clean row;
**C** the bare-`STARTMERGE` arm; **D1–D7** part B — the `select_all` wipe, an **under-delete
control** (the paste really is removed, every type), `select_dangling_nets` as the second grower, a
**partial-selection** row with its own plain-`delete()`-is-a-no-op control (WIRING.md §7 landmine
17), the committed-paste row, the empty-merge row, and a drag row (`move_objects step`) that pins
the stamp surviving `move_objects(RUBBER)`.

Not hollow: the fixture holds 2 wires + 1 instance + 1 text + 1 line and the pasted file carries one
of each, so every survivor check has a survivor of the merged object's own type; `rec0244` counts
saved object records for the line (no `xschem get` counter exists for line/rect/poly/arc).

### Sabotage table

| # | sabotage | predicted | **measured** |
|---|---|---|---|
| S1 | `if(1) set_modify(0);` on both arms (the pre-fix flat form) | the dirty rows red, control B green | **15 red**, all flag rows: A1/A5/A6 × both doors, B `hier_mod survives ESC`, C `dirty flag survives`, C-scope/D1/D3/D4/D7 flag rows. A2 and every clean-row control stayed green. |
| S2 | drop the narrowing (`delete(1)` unconditional on both arms) | the survival rows red | **23 red**, all geometry rows: C-scope ×4, D1 ×4 per door, D2 ×2 per door, D3 ×2 per door, D7 ×3. **No flag row moved** — part A keeps `modified` at 1 even while the document is being wiped, which is precisely why part A alone makes the bug *worse-looking*. |
| S3 | remove `clear_placement_preview()` from the commit tail (`move.c`) | D5 red | **no red at all.** |
| S4 | remove `clear_placement_preview()` from the empty-merge early clear (`paste.c`) | D6 red | **no red at all.** |

S1 and S2's red sets are **disjoint** — 15 flag rows vs 23 geometry rows, zero overlap.

**S3 and S4 have no detector, and that is reported rather than papered over.** Both clears are
belt-and-braces: every reader of the stamp is gated on a bit whose *only* writer stamps first
(`merge_file()` is the sole writer of `STARTMERGE`; all twelve placement arms stamp immediately
before setting their bit), so no stale stamp can be read today. They are kept because "the stamp
dies with the gesture it named" is the invariant 0241 established, and because ids survive an undo —
a resurrected paste must not become deletable by a later, unrelated abort. But no test proves it,
and no test can, without a reader that runs without a fresh stamp.

## Defects the adversarial review of this fix found (one HIGH, fixed before landing)

A 3-lens review (behavioural-regression / state-lifecycle / test-quality) over the diff, with every
finding handed to an independent refuter, raised 10 candidates: 6 refuted, 4 confirmed. Two of the
confirmed four were the same defect seen from two lenses.

### 1. HIGH — a fluid rollback wiped the merge stamp while `STARTMERGE` stayed live

`fluid_reroute_restore()` (`move.c`) and the five sibling "restore rituals" around
`mem_restore_slot()` preserve `ui_state` **verbatim** — that is their whole point, so the gesture
survives a per-step rollback. But `mem_restore_slot()` → `clear_drawing()` (`actions.c`) calls
`clear_placement_preview()`. So the bracket preserved the gesture BIT while destroying the stamp the
bit authorises the teardown to act on: `select_placement_preview()` then resolved 0,
`if(select_placement_preview() > 0) delete(1)` deleted **nothing**, and the flag line still ran — the
paste left in the drawing and, on a clean document, the buffer reporting itself saved. **Strictly
worse than pre-fix**, which deleted the (still selected) merged objects.

Reachable at stock preferences, GUI, no seam: `Ctrl+m` (move with attached nets) sets
`stretch_select` via `select_attached_nets()`; `stretch_select` **leaks** across `merge_file()`'s
`unselect_all(1)`, so `Ctrl+V` on top of it re-arms a fluid snapshot for the paste's own
`move_objects(START)` (the tree even prints its own tripwire, *"fluid_gesture_arm() re-armed while a
prior gesture was still armed"*); the first pointer motion is a RUBBER step, and ESC then deletes
nothing. Measured headlessly:

```
select_all; move_objects start 100 30 stretch; merge src.sch; move_objects step 20 20; abort_operation
  -> inst=2 wires=2 modified=0, MERGED still present     (fluid_editing 1)
  -> inst=1 wires=1,           MERGED gone               (fluid_editing 0 -- isolates the cause)
```

**Fix:** all six restore rituals now put `xctx->preview_sel_n` back beside `ui_state` and the four
id counters they already restore — the restored objects carry their snapshot ids and those counters
are reset on the next lines, so the stamp is still valid; only the COUNT needs saving, because
`clear_placement_preview()` zeroes the count and never touches the array. The canonical note is in
`fluid_reroute_restore()`; the other five point at it.

**Section D8** pins it (both the geometry half and, on a clean document, the flag half), and it
opens by ASSERTING `fluid_editing` is really 1 — the flag is a plain Tcl global, `xschem set
fluid_editing <v>` is a silent no-op (not a C-mirrored name), and with fluid editing off the whole
section degrades into D7 and passes without testing anything.
**D7 did not catch it** and was never going to: a plain `merge` + `move_objects step` never arms a
fluid snapshot, because that is gated on `fluid_editing && stretch_select` and a bare merge sets
neither. The review's own refuter said so explicitly while confirming the defect — a good example of
a row that looks like coverage and is not.

### 2. MEDIUM — the latch is consumed at an arbitrarily later ESC → filed as **0267**

`pre_merge_modified` describes the document before the paste, and `STARTMERGE` has an unbounded
lifetime (issue 0265), so edits made *while a paste is still pending* are declared clean by the ESC
that removes the paste. Measured. **Not a regression** — the pre-fix code wrote `modified = 0`
unconditionally, i.e. in this case and every other — and the honest fix is 0265's `leave_merge_for()`,
not a second latch. Filed rather than bolted on.

### 3. LOW — the clipboard is process-global and the test clobbers the developer's

`xschem copy` / bare `xschem paste` use `clip_file`, a C snapshot of
`$USER_CONF_DIR/.clipboard.sch` taken in `Tcl_AppInit` before the script runs — no Tcl variable or
`xschem set` can move it, so a run of this test overwrites the developer's real clipboard, and a
concurrent `Ctrl+C` between our copy and our paste would redden ~40 checks. Shared with
`test_crossview_paste.tcl` and `test_paste_at_log.tcl`, both already registered. Mitigated the way
the sibling does: the clipboard is re-primed immediately before each paste row (`primed_doc`), which
narrows the window to milliseconds and cannot close it, and the constraint is documented at the top
of the test. Closing it properly means launching under a redirected `$HOME` — a runner change.

### Refuted, for the record

Six findings did not survive: *D4 is vacuous* (it is a guard, not a witness — the comment now says
so in the test itself), *the aggregate record count is satisfied by the inverse outcome* (the
per-type counters pin the inverse), *the fixture has no rect/poly/arc so three stamp arms never run*
(true of the fixture, but those arms are `stamp_placement_preview()`'s, covered by 0241's own
tests), *D5/D6 cannot fail*, *D7's named hazard is unreachable on a merge drag* (correct, and it is
what produced finding 1 — the hazard is real on a drag that carries a fluid snapshot), and *the
shared-slot invariant has zero coverage*.

### Sabotage S5 (added with the fix for finding 1)

| # | sabotage | predicted | **measured** |
|---|---|---|---|
| S5 | drop `preview_sel_n` from all six `move.c` restore rituals | D8 red | **5 red, exactly the D8 rows** (`paste removed`, `merged text removed`, `survivors kept`, and both clean-row survivors). Disjoint from S1's 15 and S2's 23. |

## Trap found while building the fixture — `xschem move_objects END` does not commit

The session plan (and the "Reproduce first" block above) names `xschem move_objects END` as the
commit constructor. It is not one. `scheduler.c` compares `argv[2]` against the **lowercase**
`"end"`, so `END` matches nothing and falls into the one-shot form's `else`, which merely arms a
**deferred menu move**: `ui_state |= MENUSTART`, nothing committed. Measured `ui_state 296 → 65832`
(`MENUSTART|STARTMERGE|STARTMOVE|SELECTION`), with the paste still pending and a following ESC still
deleting it. The real commit verbs are `xschem move_objects end <dx> <dy>`,
`xschem move_objects <dx> <dy>` and `xschem paste <dx> <dy>` (all measured `ui_state → 8`). The
control-D row of the original repro was still *right* about `modified`, by accident — it never
committed anything.

## Regression tiers, and one known-red not on the session's list

Every tier named in the session plan matched its expected count after the fix: `test_add_wire_label`
178, `test_placement_preview_doors` 115, `test_placement_wire_gate` 171, `test_sch_add_pin` 21,
`test_label_ride` 157, `test_label_strand_oracle` 32, `test_wire_split` / `test_crossview_paste` /
`test_instance_update` `OVERALL: ok`, the nine replay/log tests 9/9 under `--logdir`,
`WIREEDIT: ALL PASS`, `run.sh` 6 goldens `HARNESS: PASS`, and `run_regression.tcl` at its 3
pre-existing FAIL lines (the `sg13g2_tests_ase` 10-vs-9 libs defect).

**`test_fluid_editing` FE8 fails under X and is NOT on the session's known-red list.** It
self-SKIPs under `--nogui` (the CI hole WIRING.md §10 names), which is why the regression run does
not see it:

```
FAIL: FE8 drag-and-return changed the arc AND left buffer MODIFIED (no false-clean) (mod=1 a=30)
```

Attributed, not assumed: `git stash push -- src/`, rebuild, re-run → **byte-identical failure** on
the untouched tree. Pre-existing, unrelated to this fix (it is about an arc under a drag-and-return,
which touches neither the merge arms nor the stamp).

## What this does NOT cover

- **`hierarchy_modified()`'s backup blind spot** (landmine 2 above): at top level its loop walks
  only *ancestors*, so the current cell's own `~` file is not evidence of unsaved work. Filed
  separately as **0264**.
- **Nothing tears down a pending `STARTMERGE`.** `Ctrl+V` twice, or `Ctrl+V` then any placement arm
  that goes through `unselect_all()`, drops `STARTMERGE` via the wholesale `ui_state = 0` and leaves
  the *first* paste's objects committed in the drawing with no teardown — the 0242 orphan class, in
  the dimension `leave_placement_for()` does not cover. Filed as **0265**. Part B does not make it
  worse (the stamp is inert once the bit is gone) and does not fix it.
- The `xschem move_objects END` case-sensitivity trap above: filed as **0266**.
- **The latch is consumed at an arbitrarily later ESC** (issue **0267**) — a consequence of 0265's
  unbounded `STARTMERGE` lifetime, not of the latch. Not a regression: the pre-fix code wrote
  `modified = 0` on that path and every other.
