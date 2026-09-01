# 1220 - the design walk cannot reach every sheet, and is deliberately blunt on the ones it can

**Filed by** item S6b, 2026-08-31, as the recorded residual of issue 1212's fix.
**Severity** low. Nothing here loses a setting silently; the worst case is a
duplicate cell body, and the case that does lose a setting now says so out loud.

## What a designer sees

Issue 1212 is closed: when a copy on one sheet hand-types a cell name, XSCHEM no
longer invents that same name for a copy on another sheet. It does that by
reading the design's sheet FILES before it mints a name (GUARD AS-HIER,
`auto_spec_scan_design()` in `src/actions.c`). Two things about that reading are
knowingly imperfect, and both are recorded here rather than left to be
re-derived.

### 1. Sheets the walk cannot resolve

The walk skips any `schematic=` value, and any symbol reference, that holds an
`@` or a `(` -- an @-substitution or a generator call. Those are worked out
while the netlist runs and cannot be read off the file beforehand, and running
one during what is only a name-collision test would evaluate Tcl inside it.

For those sheets the invented name can still land on a hand-typed one. XSCHEM no
longer goes quiet about it: GUARD AS-CLASH prints one plain-English line naming
the sheet, the copy, the cell name and the setting that did not reach the
simulator (row AS73). But the setting still does not reach the deck, and the
designer has to act.

**What would close it**: resolve those references the way the netlister itself
does, which means running the substitution -- so the honest fix is to move the
mint later, after `get_additional_symbols()` has resolved every hand-typed name,
rather than to make the pre-scan cleverer. That is a bigger change than item S6b
was scoped for.

### 2. A cross-sheet copy asking for the SAME settings is still refused

A name harvested from a FILE is unconditionally "taken", because a text scan
cannot work a settings key out. So the exemption issue 1215 added -- two copies
asking for the same thing share one cell, and XSCHEM adopts the name the
designer typed -- applies on the sheet being netlisted and NOT across sheets.

Cost: a numeric suffix and one duplicate cell body when a copy one level down
happens to have typed the very name a top-sheet copy asking for the same thing
would be given. The deck simulates and every setting reaches it; it is waste,
which is exactly what 1215 was about, one level up.

**What would close it**: register the sub-sheet's typed name together with
enough of the copy's own property text to compare requests, or defer the whole
decision until the hierarchy is loaded (which is the same fix as 1 above).

## Rows

None new. Row AS73 pins the AS-CLASH line for case 1; case 2 has no row and
would need a three-level fixture whose only difference is a duplicate body.

## Do not confuse with

**1207**, the eight `xschem_library/viewdraw_import/xschem_lib/dti_*` sheets
that segfault on netlist. Unrelated and untouched.

---

## 2026-08-31, item S6b's REPAIR pass: case 2 now has a row, and what the note SAYS is recorded

Case 2 above cost more than "waste": the note a designer reads ends "Any other
copy of this cell on this design that asks for the same settings shares that
one", and across sheets that sentence is measurably FALSE -- two byte-identical
cell bodies, printed under it. That is the same measurement issue 1215 is named
after, one level up, and nothing in the suite could see it.

**Row AS85** now holds case 2. It asserts what is stable whichever way 1220 is
eventually settled -- both copies built with the device they asked for, nothing
silently shared, no clash line accusing a copy of a clash that is not one -- and
records the duplicate body as a measurement, so a later hand that closes 1220
meets this row and updates it rather than closing it by accident.

Still open: the sentence itself. Making it true needs one of the two repairs
already named above; softening it to "on this sheet" would be false in the other
direction, because two copies that both let XSCHEM name the cell DO share one
body across sheets today.
