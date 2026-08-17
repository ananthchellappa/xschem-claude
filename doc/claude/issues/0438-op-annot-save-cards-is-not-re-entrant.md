# 0438 — `op_annot::save_cards` is not re-entrant: a second walk started from inside one silently discards the first walk's cards

Status: OPEN, measured by inspection, not fixed. STUB filed by the S3b implement
agent (op-annotation crew, branch `annotate`) so the number cannot collide.

⚠ **THE CODE THIS DESCRIBES IS NOT IN THE TREE.** S3b was refuted (issue 0442)
and reverted; `op_annot::save_cards` is preserved in
`doc/claude/issues/0442-attempt-2-reverted.patch`. This issue is a **standing
requirement on whoever re-lands the walk**, not a description of shipped code —
apply it to the retry rather than looking for the defect in `src/op_annot.tcl`.

Related: spec §5 I1/I6, issue 0431 (the leak on the error path), 0432
(`no_undo` has no getter, so the restore can only write 0).

## What it is

`op_annot::save_cards` (src/op_annot.tcl) accumulates into ONE piece of
namespace state:

```tcl
namespace eval op_annot {
  variable _acc
  variable warnings
}
proc op_annot::save_cards {} {
  variable _acc
  set _acc {}          ;# <- unconditional reset
  ...
}
```

so a second `save_cards` entered while a first one is still running — from a
`devproc`, from a `tclcommand=` launcher symbol the walk descends past, or from
S4's `render_deck` calling it inside a walk of its own — resets `_acc` and the
outer call returns only whatever the inner walk collected. There is no
recursion guard and no error.

Two more pieces of shared state have the same shape and a worse blast radius:
the walk sets `no_undo 1` and the restore can only put back `0` (issue 0432), so
an outer caller's own `no_undo 1` scope is silently disarmed by the inner
restore; and the log-suppress push/pop pair is a depth counter
(`scheduler.c:7795`), so nesting is safe there but only by luck of that
counter's design.

## Why it was not fixed in S3b

Not reachable from anything S3b ships: the menu item is the only caller, and
`_walk` calls nothing that can re-enter. It becomes reachable the moment S4's
`render_deck` wraps this, which is the step that should decide between an
explicit guard (`return -code error` on re-entry) and making the accumulator a
local threaded through `_walk`.

## What would settle it

A row that calls `save_cards` from inside a `devproc` the walk invokes and
asserts the OUTER block is complete.
