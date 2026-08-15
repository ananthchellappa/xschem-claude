# 0222 — the global-net refusal is sheet-local, so a rail declared global on *another* sheet is missed

Status: **OPEN**
Severity: medium (a design-wide short, applied to N objects instead of one, with no warning
and no ERC)
Introduced by: `74ef1aed`, arrived on `fluid-editing` via merge 3 (`958ada03`).
Found by: the merge-3 interaction audit.

## Symptom

`pin_rename_targets()` refuses with `PRR_GLOBAL_OLD` / `PRR_GLOBAL_NEW` when the old or new
name is a global net — precisely because a sheet-local rewrite against a hierarchy-wide net
is a design-wide short that no ERC reports.

But `pin_rename_is_global_name()` (`src/editprop.c:963-981`) resolves globality **sheet-locally**:
it looks for a `vdd.sym`-style global instance *on the current sheet*. On a mid-level sheet
that carries no such instance of its own, the refusal does not fire for a rail that is
declared global elsewhere in the hierarchy.

**Trigger.** Any hierarchical design where `VDD` is declared global by a `vdd.sym` on some
sheet (any `sky130A` / `gf180mcuD` / `ihp-sg13g2` workarea testbench). Open a mid-level sheet
that has no `vdd.sym` instance but does have `iopin lab=EN` plus several `lab_wire lab=EN`.
Select the pin, `q`, rename `EN → VDD`, Apply.

`pin_rename_is_global_name("VDD")` returns 0 → `PRR_GLOBAL_NEW` does not fire → the pin **and
every `EN` label** become `VDD`. The netlister emits `.GLOBAL VDD`, so all of them short to
the power rail design-wide. Nothing warns: the merge warning only fires for `PRR_MERGE`,
which needs a same-sheet `VDD` object.

**The mirror case is equally reachable**: renaming a sheet's `iopin lab=VDD` to `VDDA`
rewrites that sheet's `VDD` labels, silently detaching the block's internal power wiring from
the global rail.

## Corrections the verifier applied

The original claim proposed `record_global_node`'s registry as the design-wide oracle. It is
not one: `xctx->globals[]` is **per-context**, initialised once (`src/xinit.c:884-886`),
populated only as `name_nodes_of_pins_labels_and_propagate()` (`src/netlist.c:1548/1552`)
runs over whatever sheets *that* context has prepared, and cleared at netlist start
(`src/spice_netlist.c:295`, `src/tedax_netlist.c:144`, `src/spectre_netlist.c:181`) and at
`xwin_exit` (`src/xinit.c:952`). In the stated trigger it would typically be empty.

Note also that the **spec-vs-code** lens verified `pin_rename_is_global_name()` faithfully
mirrors the netlister's own two-step (`src/netlist.c:1476-1479` + `:1544-1554`), including the
`"0"` case and the `tok_size` instance-then-symbol fallback. So the function is not *wrong* —
it is as sheet-local as the netlister's own lookup, which is fine for the netlister (it walks
the whole hierarchy) and not fine for a one-sheet editing decision.

## Suggested direction

There is no cheap design-wide oracle available at edit time. Options, cheapest first:

1. **Widen the refusal on name shape**, not on registry lookup — refuse a rename onto/off any
   name matching the configured global-net patterns (`VDD`, `VSS`, `GND`, `0`, whatever the
   PDK's `xschemrc` declares), regardless of what is instantiated on this sheet. Blunt, but
   it fails in the safe direction.
2. Consult the hierarchy the way `sym_vs_sch_pins` does, and accept the cost.
3. Declare the sheet-local limit explicitly in
   `doc/claude/specs/pin_rename_propagation.md` and warn (not refuse) whenever the propagation
   touches more than one label — at least the user sees it.

Needs a ruling before implementation.
