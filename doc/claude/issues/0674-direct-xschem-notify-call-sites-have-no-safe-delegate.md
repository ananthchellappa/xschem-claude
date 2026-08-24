# 0674 — direct `::xschem::notify` call sites have no safe delegate

Status: OPEN (measured, NOT fixed — a declared coverage hole of the 0664/0665/0666 fix)
Filed by: the 0664+0665+0666 crew, 2026-08-24 (Implement agent claimed the
number as a stub before the work; the Write-up agent owns the final text).

## The class

`xschem::notify_safe` is the ONE guarded delegate body, and `ase::echo` /
`wviewer::echo` are its two callers. But a notice that carries a **remedy** —
`-short`, `-menu`, `-command`, the R-0653-d distinct fields — cannot go through
it: `notify_safe`'s signature is `{msg {tag {}}}` and it drops every one of
them. So those sites call `::xschem::notify` **directly**, and nothing guards
them.

Measured on this tree (2026-08-24, HEAD bb0ec866):

```
$ grep -n '::xschem::notify ' src/*.tcl
src/ase.tcl:692    the 0617 gate-off nudge  (-short, -menu, -command)  UNCAUGHT at HEAD
```

`src/ase.tcl:802`'s `catch {ase::op_cards_capture $state $nl}` swallows a raise
from :692 **together with the entire OP-card block** — no message, no log line,
and the user's actually-reported 0617 nudge silently dead.

## Why it is filed now rather than fixed now

The 0664/0665 fix adds a statement (`xschem::notify_mark_reset`) to the
channel's **entry**, i.e. in front of every option-parsing raise that site could
ever hit. That makes the hazard one this change *creates*, so :692 got a `catch`
in this step (decision D10, `src/ase.tcl`).

**DECLARED COVERAGE HOLE, in the 0648 SAB-H style: no committed row falsifies
that catch.** Building the row means driving `op_cards_capture` behind a raising
channel and asserting the nudge still reaches the user — a later step's work,
and larger than the one-line guard it would fence.

## What the class fix looks like

A `notify_safe`-shaped delegate that FORWARDS the remedy fields
(`xschem::notify_safe_args {msg args}`), so a site carrying `-short/-menu/
-command` has something to call, and every direct `::xschem::notify` in the
product moves to it. Then the coverage row is one row, not one per site.

## Acceptance

* every `::xschem::notify` call outside `src/ciw.tcl` and `src/xschem.tcl` goes
  through a guarded delegate that preserves `-short/-menu/-command`;
* a committed row proves the 0617 nudge still reaches the user when the channel
  raises — i.e. `ase.tcl:802`'s catch no longer eats the OP-card block;
* `grep -n '::xschem::notify ' src/*.tcl` outside those two files is empty.
