# 0363 — `xschem exit`'s NON-tabbed arm has no `has_x` guard, so an unforced headless quit errors on `tk_messageBox` and silently does not exit

Status: **OPEN — filed, not fixed** (measured while working issue **0264**, item D3 of the
2026-08-09 backlog run). Pre-existing at HEAD; not introduced or changed by anything in that run.
Area: `src/scheduler.c` — the `exit` branch, non-tabbed arm (`:3386`, `:3391`, `:3399`, `:3404`).
Related: **0264** (whose attempt-1 predicate widening made this arm reachable in far more
states — one of the reasons that attempt was reverted).

## What it is

The tabbed arm reads

```c
if(has_x && !force && hierarchy_modified()) { ...tk_messageBox... }
if(!has_x || force || !hierarchy_modified() || !strcmp(tclresult(), "ok")) { ...exit... }
```

the non-tabbed arm, twenty lines above, reads the same two lines **without** `has_x &&` and
**without** `!has_x ||`. With `tabbed_interface 0`, no display, an unsaved buffer and no
`force`, `tk_messageBox` errors, `tclresult()` is the error text, the proceed test is false, and
`xschem exit` is a **silent no-op** — the script keeps running and the process never dies.

## Why it was NOT fixed under 0264

Mirroring the tabbed arm (`!has_x ||`) would make that same headless quit *proceed* into
`clear_schematic(0, 0)`, which — for a buffer that really is dirty — drops its `~` backup. That
converts a loud, harmless no-op into silent data loss, which is the opposite of what item D3
exists to do. The right shape (exit without destroying, or refuse loudly with a diagnostic
instead of a Tcl error) is a decision of its own.

Every test in `tests/headless/` quits with `force`, so no tier is red today.

## Why it matters more than "a headless edge case"

Measured against 0264's attempt-1 build, before it was reverted: with that predicate widened, an
ordinary **draw → `Save As` → `File > New`** session left `hierarchy_modified()` stuck at 1 (see
0264's refutation), and the unforced non-tabbed `xschem exit closewindow` then became a **silent
no-op** — the process stayed alive and the script kept running, while the control run in a clean
directory exited normally. So this arm is not merely "reachable in more states": it is the point
where a false-positive predicate turns into *an application that will not quit*. Any future
widening of `hierarchy_modified()` must fix this arm first, or it ships a hang.
