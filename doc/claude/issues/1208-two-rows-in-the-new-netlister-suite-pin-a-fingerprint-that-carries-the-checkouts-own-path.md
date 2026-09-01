# 1208 - two rows in the new netlister suite pin a fingerprint that carries the checkout's own path

**Branch:** annotate
**Status:** FIXED 2026-08-31 by item S6a. Verified by row AS56.
**Filed by:** item S6, write-up pass, 2026-08-31

## What happens

`tests/headless/test_auto_specialize_1201.tcl` rows **AS6** and **AS26** pin
whole-deck FNV-1a fingerprints - `4b48fcb4` and a six-element list - as the
proof that no shipped deck moved. They are honest today and they are the right
kind of row. But every SPICE deck XSCHEM writes carries its own source path in
a header line:

```c
src/spice_netlist.c:332:  fprintf(fd, "** sch_path: %s\n", xctx->sch[xctx->currsch]);
src/spice_netlist.c:719:  fprintf(fd, "** sch_path: %s\n", sanitized_abs_sym_path(filename, ""));
```

`as_fnv` fingerprints the deck text with nothing stripped. Measured by the
verify pass: netlisting the committed `sky130_tests/bandgap` sheet from two
different paths in one process gives decks that differ in **exactly one line**,
the `** sch_path:` header.

So a clone of this repository at any other absolute path reds both rows, for a
reason with nothing to do with the change they were written to protect. That is
a manufactured standing red waiting to happen, and a standing red is a defect,
not furniture.

It is NOT the scratch directory: the suite was re-run with `XSCHEM_TEST_SCRATCH`
pointed elsewhere and still passed 44/44. It is the checkout root.

## What would fix it

Strip the `** sch_path:` / `** sym_path:` header lines before fingerprinting.
`src/actions.c:51` already documents that exact skip for the schematic-diff
reader, so the shape is established. Every bit of the two rows' strength
survives - what they are about is the 4 000-odd lines of deck BELOW the header.

## Why it was not fixed here

It is a live change to two rows that currently pin the whole [[1201]]
no-shipped-deck-moves promise, and re-pinning them means re-deriving both
constants against a fresh run. Recorded rather than changed inside a commit
whose subject is something else.

## Rows

AS6 and AS26 themselves.

---

## Fixed, 2026-08-31, item S6a

New helper `as_stripsym` in `tests/headless/test_auto_specialize_1201.tcl` drops
whole `** sch_path:` and `** sym_path:` lines before the fingerprint is taken.
Rows **AS6** and **AS26** fingerprint the stripped text and carry re-derived
constants.

**The strip covers those two header shapes and nothing else, and that was
measured.** Of the 15 lines in the shipped bandgap deck that carry this
checkout's root, all 15 are those headers. No `.include` line and no other line
in any of the six decks those two rows pin carries the root. A wider strip would
start hiding circuit from the very rows whose job is to notice it moving.

New row **AS56** proves the strip is doing something rather than that two decks
happened to agree: the same deck rewritten to a different repository root must
fingerprint the SAME once the headers are dropped, and must fingerprint
DIFFERENTLY while they are still in.

The constants were re-derived from a run of the **shipped** binary before any C
change (`ef8229a9` for AS6; `ef8229a9 6d587df9 ac4eacfe 63ff78b7 561e2e30
64c14554` for AS26) and re-confirmed after, so the re-pin is measured, not
adopted.

**One caveat on AS56, filed as [[1217]].** The row COMPUTES both numbers -
lines carrying the checkout root, and lines matching the two header shapes -
and prints them, but it asserts only that the header count is at least one. The
claim above that all 15 are headers is printed, not pinned. No live gap today;
one `expr` short of proving its own sentence.
