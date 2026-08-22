# 0610 — `traversal_setlabels` writes the parent schematic during a read-only-looking browse

STATUS: **OPEN — found by reading, 2026-08-22**, while designing the 0600 fix.
Not measured end to end. Related: 0600 (same proc family).

---

`src/xschem.tcl:3515-3532` — `traversal_setlabels` takes its **write** branch
whenever `$inst_sch ne [$w get]`, and `hier_traversal` fills that entry only for
**subcircuits** (`src/xschem.tcl:3678`).

So with `only_subckts=0`, a non-subcircuit instance reaches `:3518-3525` with an
**empty** entry, the comparison is unequal, and the walk performs

```
xschem load … ; xschem setprop … ; xschem save fast
```

i.e. a hierarchy *browse* — which reads as read-only from the menu — writes the
parent schematic to disk.

## Why it has not bitten

No menu wiring for `traversal` was found on this tree (recorded in 0600); it is
reachable by name from any rc or script. `only_subckts` defaults to `1`, which is
the branch that fills the entry, so the default call is safe.

## What is owed

A measurement: call `traversal 0 1` on a schematic holding a non-subcircuit
instance and diff the parent `.sch` before and after. If it writes, the guard is
to skip the write branch when the entry is empty, rather than to treat empty as
"differs".
