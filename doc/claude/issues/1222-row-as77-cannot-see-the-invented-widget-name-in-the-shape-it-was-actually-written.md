# 1222 - row AS77 cannot see the invented widget name in the shape it was actually written

**Filed by** item S6b's sabotage pass, 2026-08-31. **Severity** low (comments only).
**Area** row AS77, tests/headless/test_auto_specialize_1201.tcl.

## What is wrong

Issue 1218 was two code comments naming a tick box this build does not have. The fix
removed them, and row **AS77** was minted to keep them out. It counts the phrase on a
*flattened* copy of each file, and its own prose explains why:

> Counted on the flattened text, because all three sites wrap the phrase across a
> line break and counting raw bytes finds none of them

**Both halves of that sentence are false, and the row is blind to the shape the
defect actually had.**

The flattener strips a leading Tcl `#` and a trailing backslash. It does **not** strip
the ` * ` that continues a C block comment. So two comment lines join as

```
... the netlist current * schematic only box ...
```

and the phrase is not found.

## Measured, both directions

Put the phrase back in `src/actions.c` on **one** comment line -> AS77 goes red.
Put the same phrase back **wrapped across two comment lines**, which is how anyone
writes a comment -> `RESULT: ALL PASS (77 checks)`, exit 0. The invented widget name
is sitting in the file and the suite does not see it.

Against the pre-fix sources (`git show HEAD:src/actions.c`, `HEAD:src/spice_netlist.c`)
the flattener buys exactly nothing:

| file | raw count | flattened count |
|---|---|---|
| actions.c | 1 | 1 |
| spice_netlist.c | 1 | 1 |

And `actions.c` held the phrase **twice** -- `:4205` contiguous, `:4471` wrapped. Raw
counting finds 2 of the 3 sites; flattening adds none; the wrapped one at `:4471` was
never counted by either.

## The repair

Strip a C comment continuation in `as_flat`, beside the Tcl hash it already strips:

```tcl
regsub {^\s*\*+} $l { } l
```

Then re-measure against the pre-fix sources and expect 3, not 1 -- that number is the
row's own acceptance test, and it is the check that was never run.

## Related

**1217** is this defect class named; **1221** is the third instance, all three in rows
minted in one pass.

---

## CLOSED 2026-08-31 by item S6b's REPAIR pass

`as_flat` in `tests/headless/test_auto_specialize_1201.tcl` now drops a C block
comment's opening `/*` and its ` * ` continuation as well as a Tcl `#`, so two
comment lines join as a reader reads them. Verified both directions on a
throwaway fixture: the phrase wrapped across two C comment lines is found (1),
the phrase on one line is found (1), and the Tcl-wrapped shape still is (1).
Row AS77 is unchanged apart from that; it now sees the shape all three original
sites were actually written in.
