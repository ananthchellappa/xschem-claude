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

---

# ✅ FIXED 2026-08-24 — the 0664+0665+0666 crew

Status: **FIXED**. Also: **this issue's own reachability sentence was wrong and
is corrected below.**

## BEFORE

```
0666 ase::echo    rc=1 'invalid command name "::xschem::notify_safe"'
0666 wviewer::echo rc=1 'invalid command name "::xschem::notify_safe"'
```

## AFTER

```
0666 ase::echo    rc=0 ret='0'
0666 wviewer::echo rc=0 ret='0'
```

and, through the reachable runtime path (`namespace delete ::xschem` in a child,
`NTD10`): child exits **0**, both delegates `{0 0}`, and the merged output
carries `notice channel unavailable`.

## ⚠ CORRECTION TO THIS ISSUE'S OWN TEXT — MEASURED, NOT ARGUED

This issue says the path is *"unreachable outside a test's own sabotage"*. **That
sentence is too strong and is hereby withdrawn.** The Measure agent checked it
two ways, because the brief warned it may have changed under us:

* **The FILE-LOAD path IS closed**, by issue 0663 (`src/xinit.c:3571`). A share
  farm whose `ase.tcl` carries a trailing `error` — i.e. `ase::echo` defined and
  then `xschem.tcl` aborts — now yields `CHILDSTATUS 1`, one durable
  `STARTUP ABORTED: … Failing file: …/ase.tcl line 3831`, and the child's script
  never runs. Ordering cannot help either: `notify_safe` is defined at
  `xschem.tcl:14786` and the two delegates are sourced at `:14802`/`:14806`, and
  `xschemrc` is sourced *before* `xschem.tcl`, so a user rc cannot clobber it.
* **A RUNTIME path is real.** `namespace delete ::xschem` succeeds at runtime and
  takes `::xschem` from **13 procs to 0** (the namespace holds exactly the notify
  family, zero child namespaces). Both delegates then raise, and **the C `xschem`
  command survives it** — `xschem get current_name` returns rc=0 — so the session
  keeps running normally while 108 `ase::echo` and 52 `wviewer::echo` call sites
  can raise into a pick or a netlist. It is reachable from `ciw_exec`'s
  `uplevel #0 $cmd` (`src/ciw.tcl:557`, arbitrary Tcl at global scope) and from
  any `--script`.

**So the fix was scaled to what is real: a small inline guard per delegate. A
loader-level guard is NOT warranted** and was not built.

## The fix, and why the return value is TRUE

Each delegate is now four lines, duplicated **on purpose**:

```tcl
proc ase::echo {msg {tag {}}} {
  if {[catch {::xschem::notify_safe $msg $tag} r]} {
    catch {puts stderr "xschem: notice channel unavailable: $r" ; flush stderr}
    return 0
  }
  return $r
}
```

`return 0` is a **measurement, not a shrug**: when `notify_safe` itself is
unreachable, nothing reached any sink, and `stderr` is not a sink (0658's D9 —
`ihp-sg13g2/sg13g2_procs.tcl:811` is the standing example of a `puts stderr` no
GUI user ever sees). `NT27` asserts the return is true by checking
`::xschem::notify_last` is **byte-identical before and after**.

## Decisions

| # | rung | taken | rejected, and why |
|---|---|---|---|
| D9 | L1 (I1) | the guard is INLINE in each delegate, duplicated | extracting it to a shared proc — it would live in the very namespace whose absence it exists to survive (this issue's own words: "a guard is not a builder"); having the delegates write the durable log themselves via `xschem log_action` — re-creates the second durable-log builder 0658's D2 deleted, and G1 is scoped to a missing `::xschem::notify`, not a missing `notify_safe` |

## Sabotage

| variant | predicted | observed |
|---|---|---|
| SAB-C delegates restored to HEAD's bare one-liner | 3 | **3 red, exact match** (NT27, NT28, NTD10) |

SAB-C is a declared **exception to the rename-the-callee rule**, and is reported
as such: the thing being neutralised is the delegates' own `catch`, which has no
callee to rename.

## Still open

* `ase::echo`'s return is now **three-valued** — `1` from the healthy channel,
  `[llength $record]` (2, 3, 4…) from the completion path, `0` from the guard.
  No product caller reads it today (checked across `src/*.tcl`), but "the honest
  sink count" and "delivered" are now different numbers for the same successful
  notice.
* `notify_degraded_once` is called **uncaught** inside `notify_safe`'s completion
  branch, *after* the durable line has landed — so a raise there turns a
  delivered 2-sink notice into `return 0` from the delegate. That is 0652's class
  inside this issue's own fix. Filed as **issue 0677**.
* Direct `::xschem::notify` call sites carrying `-short`/`-menu`/`-command`
  cannot use `notify_safe` at all (it drops those fields) — **issue 0674**.
