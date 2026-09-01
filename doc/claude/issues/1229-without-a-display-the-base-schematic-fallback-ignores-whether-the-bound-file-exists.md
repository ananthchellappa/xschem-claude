# 1229 — Without a display, the base-schematic fallback ignores whether the bound file is there

**Status:** FIXED (2026-08-31, item S7), in the same pass as 0979 and 1228.

`src/actions.c` `get_sch_from_sym()`: `file_exists` is declared `= 0` and assigned
in exactly one place, inside `if(has_x && fallback && !is_gen && filename[0])`. So
with no display and the fallback asked for, the flag stays 0 and the
base-schematic arm fires **even when the file the copy is bound to is right there**.

Latent today — the only callers that pass fallback=1 are in `src/callback.c`, and
`xschem callback` cannot be driven under `--nogui` (it dies with signal 11 on
entry; generic and pre-existing, not descend-specific).

**It is a trap for the fix, not a curiosity.** The obvious repair for 0979 — letting
`xschem descend` ask for the fallback — makes every headless descend into a copy
with a *valid* `schematic` setting open the cell's own sheet instead. That is 1228
arriving through the other door. Both must land in the same pass.

Rows: `tests/headless/test_descend_doors_1228.tcl` C1, C2, E2. Every
dangling-binding row passes either way, which is why C1/C2 use a binding that
resolves.


## What landed

The block now opens `if(fallback && !is_gen && filename[0])`, the `stat` runs
unconditionally inside it, and only the *question* is guarded by `has_x`. With no
display and the fallback asked for, a copy whose `schematic` setting names a file
that **is** there opens that file, and the status line says nothing; a copy whose
file is missing opens the cell's own sheet and says so in one plain sentence.

Rows C1 and C2 are the only two in the suite that can see this — they use bindings
that resolve, so they fail if the existence test drifts back behind the display
test. Row E2 pins the shape.
