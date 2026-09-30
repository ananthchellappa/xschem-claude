# 1621 — replaying an action log creates one undo slot per command, not one for the macro

**STAMP:** `v1 claim=open tree=f8c53fdb stamped=2026-09-29 fix=untried open=3`

Status: **OPEN**, filed 2026-09-29 as a follow-on from issue **1619**, which made this reachable.
Measured on this tree at `1041a87f` · Branch: `fluid-editing`
Related: issue **1619** (the replay door) and its open item 1; `doc/claude/specs/wish_list.txt`
old-list item **3**; batch `doc/claude/replay_door_batch/`, receipt `receipts/A-door.md`.

## The defect

Issue 1619 gave the action log a user-reachable door (Tools ▸ `Replay action log...`), so a recorded
log is now a playable macro. Replay works — it round-trips byte-identically — but **it is not
atomic**: each replayed command pushes its own undo slot.

Measured, row `R2` of `tests/headless/test_replay_door_1619.tcl`: a log that creates **two wires**,
replayed, then **one** undo — and **one wire remains**. A user who replays a forty-command macro and
dislikes the result has to press undo forty times, and has no way to know it was forty.

That is a straightforward violation of what a user means by "run my macro": the macro is one action
to the person who ran it, so it should be one action to undo.

## Why it is not fixable from Tcl, which is the whole reason this is a separate issue

`replay_action_log` wraps `source`, and every verb the sourced log invokes pushes its own undo slot
on the way through the C core. **`xschem push_undo` adds a slot rather than merging or opening a
transaction**, so there is no Tcl-side call that says "treat everything until further notice as one
undo unit". Wrapping the replay in a Tcl `catch`, a suppress push/pop, or another `push_undo` does
not change the count.

The shape a fix needs already exists in C and is the obvious model: **`add_pin_stubs()` in
`src/actions.c` drops N labels and N stubs under a single `push_undo`**. So the fix is a C-side undo
barrier — something a Tcl caller can open and close around a batch of verbs — and that is a change to
the undo machinery rather than to the replay door. It was correctly declared out of scope for 1619
(batch decision **D4** forbade a C change in that stage), which is why it is filed here instead of
being quietly carried.

## ⚠ The interaction that makes this worse than it first reads

Issue 1619's open item 2 records that **a malformed log leaves the schematic half-changed**: `source`
executes commands one at a time, so a syntax error on line 3 has already applied lines 1 and 2 (row
`R5b`: 2 of 4 applied; `R6b`: 1 of 3 for a runtime error). A log recorded against a different
schematic aborts at the first absent referent with the same partial state (`R7b`).

**Those two defects compound.** A partial replay is exactly the case where a user most wants a single
undo, and it is exactly the case where they get N of them with no way to learn what N was. Fixing
the atomicity would also give the failure path something to roll back to, so this issue is the
natural home for both.

## What is NOT wrong here

* The replay itself is correct and idempotent — Stage A proved a recorded log replayed in a fresh
  process produces a byte-identical log, and the suppress seam keeps a replay from re-logging.
* This is **not** a regression. Nothing worked better before; before 1619 there was no user-reachable
  replay at all, so the undo behaviour was unreachable rather than right.
* `xschem push_undo`'s add-rather-than-merge behaviour is presumably correct for every existing
  caller. The gap is the absence of a *barrier* API, not a bug in the existing one.

## Still open (open=3)

1. **A C-side undo barrier** a Tcl caller can open and close around a batch of verbs, modelled on
   `add_pin_stubs()`'s single `push_undo`. This is the fix.
2. **What a partial replay should do once the barrier exists** — roll back to the barrier, or stop
   and leave the partial state with a message naming how far it got. That is a user-visible product
   choice and is the user's to make, not to be decided in the implementation.
3. **Whether the undo slot should be named** in whatever UI shows undo history, so a user can see
   "replay of <file>" rather than the last command the macro happened to run. Depends on (1).

⚠ No fence exists for the fixed behaviour yet, deliberately. Row `R2` of
`tests/headless/test_replay_door_1619.tcl` currently asserts the **present** N-slot behaviour, which
means **it will redden when this issue is fixed** — that is intended, and it is the row to update
rather than a failure to diagnose. It is written that way because CLAUDE.md warns that a fence keyed
to a symptom dies quietly when something else cures the symptom; asserting the real current count
makes the cure visible instead of silent.
