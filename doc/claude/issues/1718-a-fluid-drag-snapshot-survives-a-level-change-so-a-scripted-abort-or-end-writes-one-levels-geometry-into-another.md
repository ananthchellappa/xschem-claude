# 1718 — a fluid drag's snapshot survives a change of hierarchy level, so a scripted `move_objects abort` or `end` after `descend 1 0` or `go_back 0|2` writes one level's geometry into the other

**STAMP:** `v1 claim=open tree=e6b38ba83 stamped=2026-11-15 fix=untried open=1 scope=scripted by=drag_perf-D3`

Found by the drag-performance batch's verifier (finding G3 of
`doc/claude/drag_perf_batch/receipts/D2-verify.md`) and re-measured while filing, headless, on the
base build `e6b38ba83`, on stage D (`e6b38ba83` + `receipts/D-combined.patch`) and on stage D3's fix
tree. **Present on the base build.** Reached only by scripts (see "Who can reach it"). Filed, not
fixed.

## Measured while filing

The `sky130_tests_ase` testbench `tb_bandgap` (34 instances, 11 wires) and its cell `bandgap`
(115 instances, 58 wires), on a scratch copy. A fluid stretch was started with `xschem
move_objects start … stretch` and given two `step`s (on `x1` at the top, or on a selection in the
child), then the level was changed and the gesture closed with a scripted `abort` or `end`:

| sequence | base `e6b38ba83` | stage D | D3 fix |
|---|---|---|---|
| top, `xschem descend`, then `abort` | the CHILD's buffer becomes 34 inst / 11 wires | same | **gone**: the child keeps 115 / 58 (the titled descend ends the drag first) |
| top, `xschem descend 1 0`, then `abort` | child becomes 34 / 11 | same | same |
| child, `xschem go_back`, then `abort` | the parent shows the child's 115 / 58 | same | **gone**: the parent keeps 34 / 11 |
| child, `xschem go_back`, then `end` | parent modified, `tb_bandgap~.sch` holds 115 / 58 | same | **gone**: the parent keeps 34 / 11 (the `end` finds no live gesture; it still marks the parent modified, and its `~` holds the parent's own sheet) |
| child, `xschem go_back 0`, then `end` | parent modified, `tb_bandgap~.sch` holds 115 / 58 | same | same |
| child, `xschem go_back 2`, then `end` | parent modified, `tb_bandgap~.sch` holds 115 / 58 | same | same |
| child, `xschem go_back 2`, then `abort` | the parent shows 115 / 58 | same | same |

A save after any of the "holds 115 / 58" rows writes the child's contents into the testbench
file.

## Cause (by reading code)

The snapshot `move_objects(START)` takes for a fluid stretch (`xctx->fluid_reroute_snap`,
`fluid_reroute_active`, `fluid_reroute_dirty`; `src/move.c`) belongs to the context, not to a
level. `descend_schematic()` and `go_back()` (`src/actions.c`) replace the buffer without
dropping it; only `clear_schematic()` calls `fluid_reroute_discard()`. A later `ABORT` restores the
snapshot into whatever level is now loaded, and an `END` rolls back to it before applying the
delta.

Stage D3 of the drag-performance batch ends a live fluid drag at the start of the titled descend
and the confirming go_back (`end_live_fluid_drag()`, `src/callback.c`), which is why three rows are
gone there. It deliberately left the no-title forms (`descend 1 0`, `go_back 0|2`) as they were.

## Who can reach it

Every real-input `move_objects(ABORT)` site in `src/callback.c` and `src/scheduler.c` is gated on
`STARTMOVE`, which descend and go_back clear, and the `END` sites read are gated on `STARTMOVE`
or `START_SYMPIN` or close a gesture their own `START` opened. No Tcl under `src/` calls `xschem
move_objects abort|end`. So only scripts and tests reach it, as far as that reading goes.

## Open item

1. Drop the snapshot (`fluid_reroute_discard()`) whenever the buffer is replaced by a level
   change, or refuse a scripted `abort`/`end` whose gesture started on another level (stage D
   already records the starting level and file in `fluid_reroute_level` / `fluid_reroute_sch`).
   Not built.

## Addendum: the orphan route (2026-11-16)

Finding G4 of `doc/claude/drag_perf_batch/receipts/D3-verify.md`. One more route, which stage D3
cannot close because `unselect_all` has already cleared STARTMOVE, so `end_live_fluid_drag()`
returns 0 at the verb. Identical at the base, after D and after D3 (scripted only):

| sequence | result |
|---|---|
| drag in a child, `unselect_all`, `go_back`, `move_objects abort` | the parent shows the child's instances and wires, modified 0 |
| the same, then `move_objects end` instead of abort | the parent is modified and its `~` holds the child's geometry |
| drag at the top, `unselect_all`, select the instance, `descend`, `move_objects abort` | the child shows the parent's geometry |

Dropping the snapshot on any level change (this issue's open item) covers all three.
