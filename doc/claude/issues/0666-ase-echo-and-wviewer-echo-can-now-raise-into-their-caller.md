# 0666 — `ase::echo` and `wviewer::echo` can now raise into their caller

Status: OPEN (measured twice, NOT fixed — introduced by issue 0658's fix)
Filed by: the 0658 crew, 2026-08-24. Found by the adversary leg, independently
reproduced by the write-up pass.

## Measured

Issue 0658's driver brief said, in as many words:

> Do NOT simply delete the catch: a notice must never break its caller.

The catch was not deleted — it **moved into the callee**
(`xschem::notify_safe`, `src/xschem.tcl`), leaving the delegates as bare
one-liners:

```tcl
proc ase::echo    {msg {tag {}}} { return [::xschem::notify_safe $msg $tag] }
proc wviewer::echo {msg {tag {}}} { return [::xschem::notify_safe $msg $tag] }
```

Headless, `--nogui --pipe -q --logdir` (write-up pass):

```
notify_safe present               : 1
ase::echo    notify_safe gone     : rc=1 res/err='invalid command name "::xschem::notify_safe"'
wviewer::echo notify_safe gone    : rc=1 res/err='invalid command name "::xschem::notify_safe"'
ase::echo after namespace delete ::xschem: rc=1 res/err='invalid command name "::xschem::notify_safe"'
```

At HEAD both returned `rc=0 res=0` in all three configurations.

## Reachability — narrow, but the shape is the point

`notify_safe` is defined in `src/xschem.tcl` at `:14595`, **before** `ase.tcl`
(`:14802`) and `wave_viewer.tcl` (`:14806`) are sourced. If the bootstrap block
itself failed, `xschem.tcl` would abort before sourcing those files at all and
neither delegate would exist. So in a shipped configuration the only way to
reach this is a deliberate `rename` or `namespace delete ::xschem` — which is
exactly what a test does, and exactly how the driver reproduced 0658 itself.

What is **not** narrow is the shape. 0658 was filed about a cross-file
dependency in a notice path. The dependency chain is now one link **longer**
(`ase.tcl` → `xschem.tcl` `notify_safe` → `ciw.tcl` `notify`) and the outermost
link is the uncaught one. That is 0658's own defect, moved up one file.

## Probable fix

Two lines, and it does **not** re-create the I1 breach 0658's D3 was protecting:
a *guard* is not a *builder*, and the notice-building body stays in
`notify_safe`. For each delegate:

```tcl
proc ase::echo {msg {tag {}}} {
  if {[catch {::xschem::notify_safe $msg $tag} r]} {
    catch {puts stderr "xschem: notice channel unavailable: $r"}
    return 0                       ;# TRUE: nothing was delivered
  }
  return $r
}
```

The returned 0 is honest here (0652): nothing reached any sink. Note this must
**not** become the silent `return 0` HEAD shipped — the stderr line is what
stops it being the same defect again.

## Why the 0658 crew did not fix it

The write-up pass is the last agent in the run and no verification leg follows
it. Changing `src/` after Verify-A/B/C had signed off would have shipped an
unverified edit, and the configuration is unreachable outside a test's own
sabotage. Filed instead, with the fix written out.

## Still open

All of it.
