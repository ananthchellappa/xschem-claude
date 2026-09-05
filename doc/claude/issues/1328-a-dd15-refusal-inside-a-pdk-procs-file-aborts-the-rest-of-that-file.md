# 1328 — a DD-15 refusal raised inside a PDK `_procs.tcl` aborts the rest of that file

**Status: FILED, NOT FIXED.** Found and measured by item **B5-3** while
implementing ruling **DD-15**; it is a consequence of that ruling, not of the
button column.

## What DD-15 changed

Ruling DD-15 (issue 1326) makes `op_annot::register` **refuse** a declaration
carrying two triples that share a display label, `return -code error`, once,
where the ambiguity is introduced (`op_annot::_dup_declared_label`,
`src/op_annot.tcl`). The ruling states the cost as *"a PDK author — or a user's
own rc — gets an error at load time instead of silence. That is the point."*

## The consequence the ruling did not name

**All four shipped PDK register sites are uncaught**, and Tcl's `source`
unwinds on the first raise. So a refusal does not merely reject the one bad
declaration — it **abandons every line of that PDK file after it**, silently
from the user's point of view except for one Tcl error.

| file | register site |
|---|---|
| `sky130A/sky130_procs.tcl` | `:449` (inside a `foreach {nmos pmos}`) |
| `gf180mcuD/gf180_procs.tcl` | `:155` (same shape) |
| `ihp-sg13g2/sg13g2_procs.tcl` | `:806` (`foreach {nmos pmos}`) and `:856` (`vertical_npn`) |

`sg13g2_procs.tcl` is the sharpest of the four: `:806` runs **before** `:856`,
so a duplicate label in the MOS declaration would also cost the site's
`vertical_npn` descriptor — a device the author never touched.

## Measured (2026-09-04, item B5-3, on this binary, with DD-15 live)

A fixture `_procs.tcl` holding two ordinary uncaught `op_annot::register`
calls, the FIRST carrying a duplicate label:

```
SOURCE_RC   = 1
FIRST_TYPE  = 0
SECOND_TYPE = 0     <- the rest of the PDK file never ran
```

The second registration is a perfectly good declaration of an unrelated type
and it is gone.

## Why it is FILED and not FIXED here

The fix wraps three files — `sky130A/sky130_procs.tcl`,
`gf180mcuD/gf180_procs.tcl`, `ihp-sg13g2/sg13g2_procs.tcl` — none of which is in
item B5-3's Files cell, on the batch's **last** item, for a case **no shipped
PDK hits**: all four shipped declarations carry distinct labels, quoted by value
and measured as accepted in store row **DL3**. Editing three PDK files outside
the item's scope to harden a path nothing reaches is precisely the scope creep
that cost item B4 a whole run.

## Recommended option

**(a) — wrap each shipped register site in a `catch` that reports and
continues.** One `catch` per site, `puts stderr` naming the type and the
message, so one bad declaration costs one descriptor rather than the rest of the
file. It keeps DD-15's "told once, at load time" and drops the collateral.

*Rejected — (b) make `register` report and return instead of raising:* that
undoes DD-15 itself. The ruling chose a loud failure deliberately, and
`register` already has two other loud failures of the same shape (empty symbol
type, malformed dict) which have the same blast radius today.

*Rejected — (c) leave it:* the case is reachable exactly through invariant I5,
a user writing their own `op_annot::register` in an rc, which is the case this
feature exists to serve. A user who mistypes one label and loses an unrelated
descriptor has no way to see why.

## Acceptance, when it is fixed

* a fixture `_procs.tcl` whose FIRST register is refused still registers its
  SECOND type, and the refusal is reported once on stderr naming the type and
  the repeated label;
* all four shipped PDK files still register every type they register today;
* `test_op_annot` stays at **485** / **492** and store section **DL** stays green.
