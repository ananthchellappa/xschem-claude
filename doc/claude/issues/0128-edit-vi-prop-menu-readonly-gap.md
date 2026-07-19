# 0128 — menu "Edit with editor" edits a read-only cell (`edit_vi_prop` branch ungated)

**Status: FIXED** (2026-07-18, fluid-editing, commit `fix(readonly): reject scripted/menu
edit_vi_prop on read-only buffer (issue 0128)` — bug-fix batch item 2; found
2026-07-18 by the Refactor B batch item-29 scout while DEFERring the `edit_vi_prop`
migration; standalone gate fix, independent of any boundary work).

## What changed

One-line gate in the scheduler `edit_vi_prop` branch (src/scheduler.c, `xschem_cmds_e`
letter-dispatch group — placed AFTER the `!xctx` check, BEFORE `edit_property(1)`):

```c
if(scheduler_readonly_reject(interp, "edit_vi_prop")) return TCL_ERROR;
```

LIVE-repro facts closed by the gate (re-confirmed on the unfixed binary, DISPLAY=:0):
`xschem set readonly 1; xschem edit_vi_prop` returned rc=0 with no refusal, the editor
Tcl proc WAS invoked, and `xctx->schprop` WAS MUTATED on the read-only buffer — with
`modified` still 0 (`set_modify`'s ro_suppress hid the flag, the same silent-corruption
aggravator as 0126) and a spurious `push_undo` slot (the global arm pushes before the
strdup). Both raw keyboard entries (legacy `Q` key and verb-noun numeric case 11) were
already gated via `readonly_block()` in callback.c — only the menu/scripted verb leaked;
the asymmetry is now closed. The refusal logs nothing (the core's `set sch<X>prop` /
setprop self-logs fire only on an applied edit, which the gate prevents).

Tests: NEW tests/headless/test_edit_vi_prop_readonly.tcl (EVP1-EVP5: editable control +
undo control, readonly refusal message, no editor launch / no mutation, no spurious undo
slot; editor exec fully stubbed via the `edit_vi_prop` Tcl proc seam) + `edit_vi_prop`
added to the tests/headless/test_readonly_guard.tcl cmds list (with an inert editor stub
so a red/sabotaged binary can never exec a real editor). Red-first + 4 sabotages
(SB-A over-reject, SB-B swallowed refusal, SB-C gate-after-edit, SB-D stray push_undo)
each failed exactly their target check.

Residual: none — the boundary migration stays DEFERRED per receipt 29, independent of
this gate.

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
