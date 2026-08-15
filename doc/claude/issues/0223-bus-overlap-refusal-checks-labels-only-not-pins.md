# 0223 — the bus-overlap refusal is applied to labels only; a bus-overlapping *pin* slips through unwarned

Status: **OPEN**
Severity: low (asymmetric refusal — the same hazard is loud on one side, silent on the other)
Introduced by: `74ef1aed`, arrived on `fluid-editing` via merge 3 (`958ada03`).
Found by: the merge-3 interaction audit.

## Symptom

`PRR_BUSOVERLAP` (`src/editprop.c:1027`) refuses when a **label** bit-overlaps the renamed pin
without matching it exactly. The same test is never applied to another **pin**.

Sheet with `ipin lab=A[3:0]`, `ipin lab=A[2]`, and a `lab_pin lab=A[3:0]`. Rename the first
port:

```
xschem setprop instance p1 lab {D[3:0]}
```

The label follows to `D[3:0]` with status `PRR_OK` and **no warning**, while port `A[2]`
keeps the old name. Port `A[2]`'s connection to that conductor is silently broken — the
bus-bit sharing `bus_node_hash_lookup` established via the expanded `A[2]` entry is lost on
the `A[2]` port side alone.

Swap `A[2]` for a `lab_pin` instead of a port and the identical situation **refuses loudly**
(test `P5d` in `tests/headless/test_pin_rename_propagate.tcl`).

## Scope

Not specific to the `setprop instance` arm in the trigger above: the same
`PRR_OK`-without-warning result comes out of the other hook,
`if(ntargets == 1) propagate_pin_rename(*ii, old_lab);` at `src/editprop.c:1246` — so the
slick Edit Properties form, the vim property editor and scripted `apply_properties` reach it
too. Only scope `all`/`selected` and `setprop -fast` are excluded.

## Suggested fix

Run the bus-overlap test over pins as well as labels in the same scan
(`src/editprop.c:1002-1030` already walks every instance), and raise `PRR_BUSOVERLAP` either
way. That makes the refusal symmetric with `PRR_AMBIGUOUS`, which *does* look at other pins.
