# 1208 - two rows in the new netlister suite pin a fingerprint that carries the checkout's own path

**Branch:** annotate
**Status:** OPEN - measured, not fixed. Found by the verify pass of item S6.
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
