# 1224 - the design walk may run once per copy instead of once per run, and no row would know

**Filed by** item S6b's sabotage pass, 2026-08-31. **Severity** low (speed, not
correctness). **Area** `auto_spec_scan_design()`, src/actions.c.

## What is wrong

Reading the design's sheet files is meant to happen **once per netlist run**, lazily.
The latch that makes it so:

```c
  if(auto_spec_scanned) return;
  auto_spec_scanned = 1;
```

Row **AS74** claims to require this -- its title ends "and the walk is required to
happen once per netlist run and not once per copy". Its assertions count **call sites**
(`auto_spec_scan_design();` appears once), never **calls**.

## Measured

Delete the two latch lines and rebuild: `test_auto_specialize_1201` **77 checks all
pass**, `test_unused_attr_0970` 67. Nothing goes red.

## Why it matters, and why it is only low

The walk is idempotent -- the visited set is created fresh per call -- so no answer
changes. The cost is that a design with N copies needing a name re-reads **every sheet
file N times**. On the shipped trees nothing qualifies, so nothing is read at all;
the exposure is a real design that specialises many copies.

## The repair

Count the walk rather than the call site. The cheapest honest version is a row that
netlists a two-copy fixture and asserts the sheet was opened once -- or, if that is
awkward to observe, a structural element pinning the latch text itself:

```tcl
[as_count $AS_SCAND {if(auto_spec_scanned) return;}]
```

expected 1. The second is weaker but it is not zero, which is what is there now.

## Related

**1221** is the other half of AS74 that its prose claims and its elements do not check.

---

## CLOSED 2026-08-31 by item S6b's REPAIR pass

Row **AS74** now reads `auto_spec_scan_design()`'s own body and requires
`auto_spec_scanned` to appear **2** times in it -- the test and the set.
Measured: deleting `if(auto_spec_scanned) return; auto_spec_scanned = 1;`
reddens AS74 and nothing else.
