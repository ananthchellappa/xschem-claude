# 0432 — `xschem get no_undo` does not exist; it returns `{}` with rc 0 whether the flag is set or clear

Status: OPEN, measured, not fixed. Filed by the S3 write-up agent
(op-annotation crew, branch `annotate`).

Related: spec §5 I6, issue 0431 (the prototype walks that leak the flag), 0435
(the neighbouring `xschem set` silent-accept hole).

## What was measured

`xschem set no_undo` exists (`scheduler.c:11958`). There is **no matching
getter** — `scheduler.c:4898` has one for `no_draw` and nothing for `no_undo`.
The `get` dispatcher does not error on the unknown name either; it answers the
empty string.

Measure agent's BEFORE transcript, verbatim:

```
$ ./src/xschem --nogui --pipe -q --nolog --script scratch_S3/s3_state.tcl
save_cards=||
no_undo-getter=||
PROBE-6 get no_draw     = |0|
PROBE-7 get no_undo     = ||
PROBE-8 get no_undo after 'set no_undo 1' = ||
PROBE-9 keep_symbols    = |0|
```

PROBE-7 and PROBE-8 are the finding: identical output before and after
`xschem set no_undo 1`. `get no_draw` on the same line returns a real `0`, so
this is specific to `no_undo` and not a property of the probe.

## Why it cost a step

Spec **I6** requires the hierarchy walk to restore `no_draw`, `no_undo`,
`keep_symbols` and `sch_path` on every exit path, and S3's stated acceptance was
a test asserting all four are back to **their entry values**. For `no_undo` that
test is **unwritable in Tcl against this binary**:

* written as `check {...} [xschem get no_undo] 0` it **fails** (`{}` ne `0`);
* written as "equals the entry value" it **passes vacuously**, `{}` against `{}`,
  and would keep passing if the restore were deleted outright.

A quarter of an acceptance row that cannot fail is worse than no row, because it
reads green.

## The workaround used, and its measured residual

The reverted S3 implementation restored `no_undo` to **0** — the only value that
can be restored when the entry value is unobservable — and its test probed the
flag's *effect* instead of its value: `push_undo` → select instance → delete →
`undo`, asserting the instance count round-trips.

The probe provably discriminates (it is not vacuous):

```
undo live  ->  {2 1 2}      (2 instances, 1 after delete, 2 after undo)
no_undo 1  ->  {2 1 1}      (undo does nothing)
```

**Residual the probe cannot see, and it is the reason this issue is filed rather
than shrugged off:** a caller that wraps the walk inside its *own* `no_undo 1`
scope has that scope silently disarmed. Measured directly:

```
caller sets no_undo 1;  undo probe BEFORE walk = {3 2 2}   (undo dead, as the caller intends)
op_annot::save_cards;   undo probe AFTER  walk = {3 2 3}   (undo LIVE — the caller's scope is gone)
```

**S4's `render_deck` is exactly such a caller**, so this is on the next step's
path, not hypothetical.

## Decision taken, with ladder rung and rejected alternative

**Rung L2** (no invariant settles it; pick the smallest blast radius and record
the rejected option).

* **Chosen:** restore to 0, probe the effect, file this issue.
* **Rejected:** add a four-line getter beside `scheduler.c:4898`. The blast
  radius is genuinely tiny and it is the *correct* long-term fix — but it turns
  a pure-Tcl step into a C build step, which breaks the plan's "S1–S6 need no
  rebuild" contract and would have put the step behind the crew's single build
  lock (this box OOMs on concurrent builds, ~7.8 GB).

## The fix

Add the getter next to `no_draw`'s at `scheduler.c:4898`:

```c
else if(!strcmp(argv[2], "no_undo")) {
  Tcl_SetResult(interp, my_itoa(xctx->no_undo), TCL_VOLATILE);
}
```

(field name to be confirmed against the setter at `:11958`). Then I6's
`no_undo` clause becomes assertable as a plain flag read, the walk can restore
the entry value instead of 0, and the residual above disappears.

## Still open

* The getter is unwritten; whoever next touches `scheduler.c` for this feature
  should add it, and the S3 retry should then assert the real entry value.
* Unmeasured: whether any *other* `xschem set` flag has the same asymmetry.
  Issue 0435 shows the `set` side of this dispatcher is already known to be
  under-guarded, so a sweep of setter/getter pairs is worth one session.
