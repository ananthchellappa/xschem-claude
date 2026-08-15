# 0411 — in cadence mode, `e` on a selected instance should offer descending into its SYMBOL

Status: **OPEN — FILED, NOT BUILT. BLOCKED.** Requested by the human during the D1–D10 eyeball
verification, 2026-08-15; filed by crew item **D11**, whose scope was explicitly *ship the Ctrl-Y
binding, FILE the chooser half, do not build the chooser*.
Area: `src/xschem.tcl` — `hi_descend_enum_views()`, `hi_descend_pick_view()`,
`hi_descend_dialog_body()`, `hi_descend_finish()`; the `e` key bind (`src/xschem.tcl:14354`).
Vehicle: [0252](0252-non-subcircuit-symbols-refused-silently-after-the-chooser-offered-the-view.md).
Blocker: [0379](0379-get-sym-type-returns-empty-while-an-instance-is-selected.md) — **see the
caveat below; 0379's headline claim did not reproduce on re-measurement and must be re-measured
before anyone builds on it.**
Related: [0410](0410-descend-into-symbol-has-no-key-in-cadence-mode.md) (the keyboard half,
shipped), [0251](0251-a-refused-descend-has-no-return-channel.md).
Spec: `doc/claude/specs/hi_descend.md`.

## The request

In cadence mode, with an instance selected, `e` should offer the option of descending into the
**symbol**, not only into a schematic view. Today `e` (`hi_descend`) offers the symbol row but
defaults to a schematic row that, for a non-descendable master, cannot exist — so the working
route is one drop-down click away behind a default that always fails.

## What `e` does today (measured)

`e` is bound to `hi_descend` at `src/xschem.tcl:14354`; `cadence_style_rc` does **not** steal it.
For a `devices/res.sym` (`type=resistor`) instance `R1`:

- `hi_descend_enum_views R1` returns **two** rows — `{schematic schematic …/devices/res.sch}`
  with `exists=0`, and `{symbol symbol …/devices/res.sym}` with `exists=1`. The symbol view *is*
  already in the drop-down.
- `hi_descend_pick_view` with no explicit view returns the **schematic** row, and
  `hi_descend_dialog_body` forces `schematic` as the drop-down default.
- `hi_descend inst=R1` therefore returns `0`, `descend_error` = `not-descendable:resistor`,
  `ciw_echo` = `hi_descend: cannot descend into R1 (not-descendable:resistor)` — D4 already gave
  this arm a voice.
- `hi_descend inst=R1 view=symbol` returns `1` and lands on `res.sym`.

So the ask reduces to: **the offered-and-defaulted view for a non-descendable master is a
schematic that cannot exist**, while the working symbol row sits behind it.

## Why this is blocked and was not built here

D5 (`504e38c7`) built exactly this filter, measured it green, and then **reverted it in full**.
The stated reason was 0379: with an instance selected, `xschem get_sym_type` returns empty
(`src/scheduler.c:5635`), which collapses the filter to a bare file-exists test and deletes the
create-the-child-by-descending workflow — a user who means to author the missing child schematic
loses the route to it. The revert is complete in the current tree: no `hi_descend_row_offerable`,
no `hi_descend_no_view_msg` anywhere in `src/`, no type filter in the chooser, and the schematic
row is still offered unconditionally and made the default.

**CAVEAT — do not treat 0379 as settled.** Two independent D11 agents failed to reproduce
0379's headline claim on the current post-`dd5ca7b8` binary: the scout ran five probe shapes
(flat-dir `subcircuit`, flat-dir `resistor`, absolute-path reference so the loaded-symbol-cache
branch is taken, the OA lib/cell/view hidlib fixture, and the real `xschem_library/devices/res.sym`
with a live selection and after a refused descend), and the measure agent re-ran 0379's own
verbatim 7-step sequence; in **every** case `get_sym_type <abs path>` answered the correct type
at every step, including with the instance selected. A *different*, selection-independent failure
was reproduced instead: `get_sym_type` answers `""` for a name it cannot resolve through the
library path (`get_sym_type leaf.sym` → `''` while `get_sym_type hidlib/leaf` → `'subcircuit'`
for the identical symbol), and `""` is also what an untyped symbol returns, so *unresolvable* and
*no type token* are indistinguishable — a plausible alternative explanation for D5's collapse
(the filter fed a row-shaped path), with the selection as a confound.

Two failures to reproduce are not a refutation — D5 measured it live in a different session —
so 0379 stays **OPEN**. But whoever picks this up must **re-measure 0379 first** and must not
inherit it as established fact.

## Order of work when this is unblocked

1. Re-measure 0379 deliberately (its own item): is the emptiness selection-dependent, or is it
   path-resolution failure plus an ambiguous empty return?
2. Fix whatever that measurement finds, and give `get_sym_type` a way to distinguish
   *unresolvable* from *untyped*.
3. Only then re-attempt the 0252 filter — and preserve the create-the-child-by-descending
   workflow, which is what sank the D5 attempt.

Rejected here: re-attempting the D5 filter (out of D11's scope, and D5 already measured it green
while broken); restating 0379's selection-dependence as fact (hands the next crew an unverified
blocker); closing 0379 as not-reproducible (see above).
