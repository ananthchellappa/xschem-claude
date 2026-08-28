# 0882 - `wviewer::hier_origin_ok` short-circuits on a raw the DESIGN window now holds

**Status:** OPEN. Claimed 2026-08-27 by item A10's red phase, measured not read,
and filed BEFORE the 0881 fix landed because the fix is what makes it reachable.
**The fix has now landed** and row V44 is green in both directions, so the premise
quoted below is false in the shipped tree as of this date.

## The claim

`wviewer::hier_origin_ok` (`src/wave_viewer.tcl:11137`) returns 1 the moment the
CURRENT context holds a database, and never consults the base level at all:

    set lv -1
    catch {set lv [xschem raw loaded]}
    if {[string is integer -strict $lv] && $lv >= 0} { return 1 }
    ... ase::ui::sod_base_level ...

Its own header states the premise that short-circuit rests on, verbatim:

> ASE reads the raw into the VIEWER context only (the `raw read` sites in this
> file), so in the DESIGN window `sch_waves_loaded()` is -1

Issue 0881's fix makes that sentence false. Once **Alt-Shift-6** / **Results >
Annotate > Transient Node Voltages (at cursor)** supplies the run's results to
the schematic window itself, the design window DOES hold a raw, and a base-level
mismatch that used to REFUSE now silently passes.

## Measured

With `ase::ui::sod_base_level` forced to a refusing value (3), and the ONLY
change being whether the design window holds results:

    empty design window   -> hier_origin_ok = 0   (refuse)
    after the annotation  -> hier_origin_ok = 1   (allow)

Pinned as a WITNESS row: **V44** of `tests/headless/test_op_annot.tcl`. That row
guards nothing — it records the changed premise so a later crew has to confront
it rather than rediscover it.

## Not fixed here, deliberately

`src/wave_viewer.tcl` is outside item A10's blast radius and touching it puts the
signal-browser suites in play. What the guard should do instead — ask whether the
raw in the current context is the SESSION's raw, rather than merely whether one
is present — needs its own measurement.


## Sibling filed alongside it

**0883** is the same class one call further on: `ase::browser_show_current`
(`src/ase.tcl:3582`) reads `xschem raw loaded` **in the design window** to decide
how many hierarchy segments to drop when mapping the schematic position onto the
Signal Browser. That read was always -1 for the same reason this one was, and item
A10 makes it a real level.
