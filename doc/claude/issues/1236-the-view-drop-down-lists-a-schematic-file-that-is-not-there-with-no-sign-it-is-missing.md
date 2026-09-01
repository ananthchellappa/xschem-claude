# 1236 — The View drop-down lists a schematic file that is not there, with no sign it is missing

**Status:** OPEN. Measured 2026-08-31 by item S7's adversary pass, re-measured
independently by the write-up agent before filing. **New user-visible ink from item
S7** — before S7 the row did not exist at all, so this is a presentation question the
item created and did not answer.

## What a person sees

Item 1228 made the `E`-key chooser offer the schematic file a copy is set to open.
That is the fix. But it offers it whether or not the file is there, and the list gives
no sign of the difference. Measured on the shipped
`xschem_library/inst_sch_select/inst_sch_select.sch`:

```
ROWS FOR x2:
    name=schematic      type=schematic  file=comp3.sch              EXISTS=1
    name=comp3_parax    type=schematic  file=comp3_parax.sch        EXISTS=1
    name=symbol         type=symbol     file=comp3.sym              EXISTS=1
ROWS FOR x3:
    name=schematic      type=schematic  file=comp3.sch              EXISTS=1
    name=comp3_pex      type=schematic  file=comp3_pex              EXISTS=0
    name=symbol         type=symbol     file=comp3.sym              EXISTS=1
```

The two lists read identically to a person. `comp3_pex` is a file that does not exist;
it sits in the drop-down looking exactly like `comp3_parax`, which does.

## Why it is not simply a bug

It degrades gracefully: choosing that row now raises the plain-English question item S7
minted, and answering No leaves the person where they were (issue 1230). And there is a
real argument that a person **should** see what their copy is set to open, precisely
because it is broken — hiding it would hide the problem.

So this is a presentation choice, not a defect with one obvious answer. The options,
cheapest first:

1. Leave it. The question catches it one click later.
2. Mark the row — append something a person can read, e.g. `comp3_pex (file missing)`.
3. Sort missing rows last.
4. Do not offer a row whose file is not there — which would hide a real misconfiguration
   and is the option this issue recommends against.

## Owed

A **look** debt is on the ledger for the drop-down (issue 1228) but it names only x2 —
the copy whose file exists. A person ruling on this needs to see **x3**, where the row
is a file that is not there. Recorded as its own look debt against this issue.
