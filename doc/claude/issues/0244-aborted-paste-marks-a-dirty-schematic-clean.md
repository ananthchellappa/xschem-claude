# 0244 — ESC-ing a paste/merge marks an already-dirty schematic **clean**, so the save prompts stop firing and File ▸ New then deletes the autosave backup

Status: **OPEN** — 5-line headless repro + 4 controls + a measured consequence chain, fix drafted
(the obvious fix is wrong — see below), not implemented. **Major**: silent loss of real edits, no
prompt anywhere.
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
