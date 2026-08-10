# 0365 — after `go_back`, a descended child's live `~` backup drops out of `hierarchy_modified()`'s scan entirely

Status: **OPEN — filed, not fixed** (found by the adversary pass of item D3 / issue **0264**,
2026-08-09 backlog run). Stub claimed at write-up time.
Area: `src/save.c` — `hierarchy_modified()`; `src/actions.c` — `go_back()`;
`src/scheduler.c:7293` (`if(undo_reset) xctx->currsch = 0;`).
Related: **0264** (the same blind spot one position over — attempt 1 reverted), **0362**.

## What it is

`hierarchy_modified()` scans `xctx->sch[0 .. currsch-1]` (ancestors). Issue 0264's attempt-1
patch would have added `xctx->sch[currsch]` (the current level). Neither covers a cell that
used to be *below* you.

After `go_back()` ascends, `currsch` decrements, so the child you just left is neither the
current level nor an ancestor: its index is now `> currsch`. If that child's `~` still holds
unsaved work — which `xschem reload` and an in-place `xschem load` both arrange, since they
clear `xctx->modified` without calling `remove_backup()` (issue 0264's measured mechanism) —
**no predicate anywhere can see it again**. The Close/Quit prompt does not lie; it is silent.

`scheduler.c:7293`'s `if(undo_reset) xctx->currsch = 0;` orphans the whole stack the same way,
in one step.

## Evidence

Measured by the adversary pass against the (now reverted) 0264 fix, attack A8:

```
A8 DESCEND/ASCEND: parent -> descend -> edit child -> `xschem reload` -> `xschem go_back`
   -> `xschem clear` at the parent. child~.sch survives with 2 wires vs 1 on disk.
   BUT after ascending, hierarchy_modified()==0 while that child~ holds the only copy:
   go_back drops currsch so the child is neither current nor an ancestor.
```

No data loss was measured on that path (the parent-level `clear` did not touch the child's
`~`), which is why the adversary did not count it as the refutation.

**Not independently re-measured.** The write-up agent's own attempt used a hand-built
`C {child.sch}` instance record rather than a real symbol, so `descend` never fired
(`currsch` stayed 0 and no `child~.sch` was ever written) — that run is not evidence and its
"CONFIRMED" line is a fixture artifact, recorded here so nobody cites it. A proper witness
needs the `tests/headless/test_hier_walkup.tcl` / `test_descend_preserve.tcl` fixture shape,
which builds a real `.sym`. Anyone picking this up should re-measure first.

## Why it is not just "0264 with a bigger loop"

Widening the loop to `0 .. CADMAXHIER` is not obviously right: the entries above `currsch`
are stale strings from a previous descend, not a live stack, so scanning them would warn about
cells the user has genuinely left and saved. This is the same missing question as **0362** —
the `~` has no identity, so "is this file someone's unsaved work?" cannot be answered from the
filename plus a stack index. Fix 0362 first, or accept that the predicate is stack-shaped and
say so in the spec.
