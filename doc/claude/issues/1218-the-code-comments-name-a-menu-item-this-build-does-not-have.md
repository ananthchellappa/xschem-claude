# 1218 - the code comments name a menu item this build does not have

**Branch:** annotate
**Status:** OPEN - measured, not fixed. Comment/prose accuracy only; no
behaviour is wrong.
**Filed by:** item S6a, write-up pass, 2026-08-31. Measured by that item's verify
pass; re-checked here.

## What is wrong

Two comments written by item S6a describe the single-sheet netlist as something
the designer **ticks**:

```
src/spice_netlist.c:420:  * when the user ticked "netlist current schematic only" (also the Shift-N key
src/actions.c:4205:      * whole design", 0 for "netlist current schematic only". It decides GUARD
```

There is no such checkbutton. `grep -n "current schematic only" src/xschem.tcl`
is empty and no menu entry carries that label. The real doors are:

* the **Shift-N** key, whose own long-standing comment in `src/callback.c` calls
  it *"current level only netlist"*; and
* `xschem netlist -nohier` (`src/scheduler.c`).

The fix for [[1204]] is complete and correct - both doors funnel through the one
`global_spice_netlist(0, ...)` call - so only the *name* is invented.

## Why it is worth a number

The house rule is to speak in nouns the user can actually see on their screen.
A comment that invents a widget sends the next reader looking for a tick box
that does not exist, and it is the kind of wrong that survives every green
suite. The same phrase has spread into the suite's own row prose (rows AS44-AS46
and the `as_netlist_nh` helper comment).

## What would fix it

Say what the user really does: *"pressed Shift-N (netlist this sheet only), or
ran `xschem netlist -nohier`"*. Three comment sites in `src/` and the suite's
prose beside them.

---

## FIXED, item S6b (2026-08-31)

The invented label is gone from `src/spice_netlist.c` and `src/actions.c` and
from this suite's own row prose, replaced everywhere by the doors the user can
actually reach: "a netlist of just the sheet on screen -- Shift-N, or `xschem
netlist -nohier`". Row AS77 counts it at zero in all three places.

**The row was blind when it was first written and had to be fixed before it
could be trusted**: all three sites wrap the phrase across a line break (a
continuing C comment, a Tcl row title with a trailing backslash, a `##` comment
line), so counting raw bytes found nothing and the row passed having measured
nothing. It now flattens the text first.
