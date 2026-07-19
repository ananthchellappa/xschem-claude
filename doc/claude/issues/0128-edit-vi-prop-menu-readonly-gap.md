# 0128 — menu "Edit with editor" edits a read-only cell (`edit_vi_prop` branch ungated)

**Status: OPEN** (found 2026-07-18 by the Refactor B batch item-29 scout while DEFERring the
`edit_vi_prop` migration; standalone gate fix, independent of any boundary work).

## Symptom

Properties > "Edit with editor" (menu xschem.tcl:14363, actions.csv:111) on a read-only cell
opens the external editor and APPLIES the edit — including push_undo — because the scheduler
`edit_vi_prop` branch (scheduler.c:3002-3008, in xschem_cmds_e) carries only the `!xctx` guard.

Asymmetry: both raw entries are correctly gated — legacy `Q` key (callback.c:5654-5658,
readonly_block; comment at 5634 states the edit-with-editor gate is intended) and verb-noun
numeric case 11 (callback.c:3264 via readonly_block at 3196). Only the menu/scripted path leaks.

## Fix

One line: `scheduler_readonly_reject(interp, "edit_vi_prop")` at the top of the branch
(setprop-style precedent at scheduler.c:10259). No query form exists, so no split needed.

## Non-issue clarified while here

The old "no log_action on this path" claim is FALSE — the core self-logs the resulting edit
(0063 atom 10): editprop.c:1682-1684 emits replayable `xschem setprop <type> <ref> allprops
{...}` lines, and global edits log `xschem set sch<X>prop {str}` (editprop.c:1536-1547). Only
the gesture line is unlogged, by design.

## Cross-refs

- Batch scout receipt: doc/claude/refactor_b_batch/receipts/29_edit_vi_prop.md
- Sibling readonly-gap issue: 0126 (scripted apply_properties)
- Readonly-gate-as-correctness-fix precedents: audit §30/§38/§42
