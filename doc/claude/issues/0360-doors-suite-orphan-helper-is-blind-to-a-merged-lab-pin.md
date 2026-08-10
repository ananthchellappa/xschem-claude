# 0360 — the placement-doors suite's `orphans` helper cannot see a merged `lab_pin`, so a "no orphan" check can pass for the wrong reason

Status: **OPEN — measured, not fixed** (worked around in one section). Filed 2026-08-09 by the
issue-**0263** write-up agent, item D2 of the unattended backlog run.
**Test-integrity defect**: a green check that proves nothing. It already produced two false greens.
Area: `tests/headless/test_placement_preview_doors.tcl`, proc `orphans`.
Related: **0263** (found while adding its section G), **0265** (the merge teardown whose rows this
would silently under-test), **0242**, **0354** (the same class one level up — an audit predicate
that does not assert the shape it names).

## The defect

`orphans` counts leftover label previews by matching the instance's cell name **exactly**:

```tcl
if {[xschem getprop instance $i cell::name] eq "lab_pin.sym"} { incr n }
```

A **placed** `lab_pin` reports exactly `lab_pin.sym`, so every row in sections A–F is counted
correctly. A **merged** `lab_pin` reports the *path* form the merge source wrote —
`devices/lab_pin` — and the exact match therefore counts it as **zero**.

## How it bit

Issue 0263's section G added the first rows in this file that merge a `lab_pin` rather than placing
one. The original G9 row asserted `orphans == 0` after a netlist with a merge co-armed. That check
**passed before the fix as well as after**, because the merged orphan it was supposed to catch was
invisible to the counter. The red-first report for the item recorded G9 as red on its instance-count
rows only; its two "no orphan" rows were false greens and were never red at any point.

Reproduce the blindness directly:

```tcl
# a merge source containing:  C {devices/lab_pin} 100 0 0 0 {name=lb lab=BAR}
xschem merge $onelab
xschem getprop instance [expr {[xschem get instances]-1}] cell::name
#  -> devices/lab_pin      (not lab_pin.sym)
```

## What was done instead (and why that is not the fix)

A second helper was added beside `orphans` for section G only:

```tcl
proc labpins {} { ... [string match *lab_pin* [xschem getprop instance $i cell::name]] ... }
```

`orphans` itself was **left alone deliberately**: sections A–F only ever *place* their lab_pins, so
changing the predicate there is scope creep inside a fix whose blast radius was two gate calls, and
a loosened glob in a 115-row door suite is exactly the kind of change that should not ride along
with an unrelated C fix.

The consequence is a live trap: **any future row that merges a `lab_pin` and asserts `orphans` will
be silently green.**

## Options

1. Make `orphans` glob (`*lab_pin*`) and re-baseline the suite. One line; the risk is that a row
   somewhere in A–F is relying on the exact match to *exclude* something (nothing found on
   inspection, but it has not been proved).
2. Normalise at the source: have the suite's fixture writers emit `lab_pin.sym` consistently, and
   assert the normalisation. Narrower, but leaves the helper wrong for any externally-authored
   merge source.
3. Give `xschem getprop instance N cell::name` a documented normal form and fix the helper against
   *that*. The real fix, much wider than this suite — several other tests exact-match cell names.

Recommendation: **1**, with a comment naming this issue, at the next time the suite is opened for
its own reasons.

## Not fixed here

Out of item D2's scope. The blindness is documented in a comment above `labpins` in the suite
itself, so the next reader of that file meets it immediately.
