# 0490 — `has_included_subcircuit` pops a modal `alert_` that no netlist flag reaches

**Status:** open.
**Filed by:** step S3d of `doc/claude/specs/op_annotation.md`.

## What

`src/xschem.tcl:2200` and `:2239`, inside `has_included_subcircuit`:

```tcl
puts "has_included_subcircuit: $symname: no matching .subckt found in spice_sym_def. Ignore"
if { [info exists has_x] } {
  alert_ "has_included_subcircuit: $symname: no matching .subckt found in spice_sym_def. Ignore"
}
```

Gated on `has_x` only. `xschem netlist -noalert` does not reach it: `-noalert`
threads the netlister's own `alert` flag through the C (spice_netlist.c:695 down
to load_schematic()'s modal at save.c:4451) and has no effect on this Tcl-side
helper.

## Why it matters now

S3's save-card generator runs `xschem netlist -keep_symbols -noalert` as a
read-only ORACLE behind a menu click the user never associates with netlisting.
A symbol carrying a `spice_sym_def` whose text has no matching `.subckt` —
ordinary during authoring — therefore pops a modal dialog for an operation the
user did not ask for, and **blocks an unattended X run forever**.

The same reasoning applies to `set_netlist_dir`'s `tk_messageBox` at
`src/xschem.tcl:9001` / `:9039`; S3 avoids that one by pre-checking the oracle
directory (`op_annot::_oracle_dir_ready`) before issuing the netlist. There is
no equivalent pre-check available for this one — the condition is inside the
symbol data.

## Worked around, not fixed

S3's own test fixture gives its `spice_sym_def` symbol a `.subckt` port name
that MATCHES the symbol pin, precisely so the xvfb leg of
`tests/headless/test_op_annot.tcl` cannot hang. That is a fixture accommodation
of the defect, not a fix.

## Suggested fix

Thread the netlister's `alert` flag into the Tcl helper — the netlist branch
already knows it (`scheduler.c:8757`) — or gate the `alert_` on the same
variable `-noalert` sets, leaving the `puts` unconditional.
