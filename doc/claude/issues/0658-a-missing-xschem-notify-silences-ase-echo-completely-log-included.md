# 0658 — a missing `xschem::notify` silences `ase::echo` completely, the durable log included

Status: OPEN (measured, NOT fixed — see "Why it was not fixed here")
Filed by: the 0650 write-up pass, 2026-08-23, from the adversary leg's finding.

## Measured (headless, current tree)

```
D-b ase::echo rc/result with channel gone      0 / 0
D-b sinks reached with channel gone            ''
```

Method: `rename ::xschem::notify ::wu_saved_notify`, then
`::ase::echo "ASE: a refusal the user must see" error` with `::ciw_echo` spied.
The call **raised nothing**, returned 0, and reached **zero** sinks.

## Why this is a regression and not merely a limitation

Before issue 0650, `ase::echo`'s `xschem log_action -error` was **inline**. It had
no cross-file dependency, so the durable file line — 0650's own sink table calls
it the one that *"survives a shut window"* — was written even with no Tk, no CIW
and no display. After the rewire, one unavailable proc in a *different file* turns
all 61+ ASE call sites and every `wviewer::echo` message into a silent no-op, and
the `catch` in each delegate is what hides it.

Reachable the issue-0424 way: any Tcl error anywhere in `src/ciw.tcl` kills the
whole file, and `xschem.tcl` continues past a failed `source`.

## Why it was not fixed here

The obvious fix — inline the log write in each delegate as a fallback — puts the
same five lines (trimright, the trailing-backslash pad, the empty guard, the
tag→`-error`/`-result` mapping) back into **two** files. That re-creates precisely
the two-byte-identical-builders situation invariant **I1** forbids and that issue
0650 had just deleted (`ase::echo` and `wviewer::echo` were the same eight lines).
Trading a remote silent failure for a live I1 breach is the wrong trade, and
making that call at write-up time with no red-first test would be worse.

Rejected alternative #2: `puts stderr` on the catch path. Strictly better than
nothing, but it is the same invisible-to-a-GUI-user silence this whole feature
exists to delete (`ihp-sg13g2/sg13g2_procs.tcl:811` is the standing example), and
it is a behaviour change with no coverage.

## What the fix probably looks like

A single shared degraded-mode writer that does **not** live in `ciw.tcl` — the
smallest home is `src/action_registry.tcl` (sourced at `src/xschem.tcl:14568`,
before every consumer) — with `ase::echo` / `wviewer::echo` falling back to it,
plus one row that renames the channel away and asserts the log file still grew.

## Still open

All of it.
