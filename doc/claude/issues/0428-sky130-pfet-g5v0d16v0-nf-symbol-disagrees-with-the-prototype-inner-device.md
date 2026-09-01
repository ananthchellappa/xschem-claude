# 0428 — `pfet_g5v0d16v0_nf.sym` spells its inner device differently from every sibling and from `sky130_write_save_lines`

**Status**: open, measured, NOT fixed. Filed by the S2 RED agent (branch `annotate`,
2026-08-16) while writing the sky130 symbol-text cross-check row of
`tests/headless/test_op_annot.tcl`.

**Severity**: low blast radius today (one symbol, and no schematic in `sky130A/`
instantiates it), but it is a *silent wrong number* class defect — see landmine 9.

## What was measured

Forty `sky130A/xschem_libs/sky130_fd_pr/*fet*/symbol/*.sym` files carry an OP
annotation text of the form

```
T {gm=@spice_get_node \\@m.@path@spiceprefix@name\\.<inner-device>[gm]} ...
```

Comparing each symbol's `<inner-device>` against what `sky130_write_save_lines`
(`sky130A/sky130_procs.tcl:75-78`) builds for that symbol's own `model=`:

```
symbols compared = 40
disagreements    = 1   ->  pfet_g5v0d16v0_nf.sym
```

The single disagreement:

| source | inner device for `model=pfet_g5v0d16v0` |
|---|---|
| `sky130_procs.tcl:76` (`g5v0d16` arm) | `xsky130_fd_pr__pfet_g5v0d16v0.msky130_fd_pr__pfet_g5v0d16v0_base` |
| `pfet_g5v0d16v0_nf/symbol/pfet_g5v0d16v0_nf.sym:71-72` | `msky130_fd_pr__pfet_g5v0d16v0_base` |

`pfet_g5v0d16v0_nf.sym` is the lone outlier: its own non-`_nf` sibling
`pfet_g5v0d16v0.sym:67` uses the `xsky130_fd_pr__…` form, and so does the
n-channel twin `nfet_g5v0d16v0_nf.sym:71`. The spelling it uses instead is the
one the `20v0_(iso|nvt)` arm produces, which reads like a copy-paste from that
arm.

Reproduce:

```sh
grep -n 'model=\|gm=@spice_get_node' \
  sky130A/xschem_libs/sky130_fd_pr/pfet_g5v0d16v0_nf/symbol/pfet_g5v0d16v0_nf.sym \
  sky130A/xschem_libs/sky130_fd_pr/pfet_g5v0d16v0/symbol/pfet_g5v0d16v0.sym \
  sky130A/xschem_libs/sky130_fd_pr/nfet_g5v0d16v0_nf/symbol/nfet_g5v0d16v0_nf.sym
```

## Why it matters

Per spec §6 landmine 9 (re-measured for S1, `src/op_annot.tcl:63-66`): a `.save`
card naming a device that is not in the netlist still writes a full column under
exactly the requested name, holding **0.0**, with only
`Warning: unrecognized variable` on stderr. So whichever of the two spellings is
wrong does not render blank — it renders a plausible `0.0`, which invariant I3
cannot catch.

## Why it is NOT fixed here

S2 is a data step and the brief forbids later-step work. Deciding which spelling
is correct needs an ngspice round trip against the real `sky130_fd_pr` models
(the `_nf` variant's subcircuit structure) — that is S4's raw-header assertion,
and doing it here would be inventing S4's measurement early. The device is not
instantiated by any schematic in `sky130A/`, so nothing in-tree reads a wrong
number today.

## What the test does about it in the meantime

`tests/headless/test_op_annot.tcl` row **P7** asserts the scan result is exactly

```
{40 pfet_g5v0d16v0_nf.sym}
```

i.e. forty symbols compared and *this one named disagreement*. The row therefore
still guards the other 39 spellings byte-for-byte, and it goes red the moment
either the symbol or the descriptor's `devproc` changes — including when this
issue is eventually fixed, at which point the golden becomes `{40 {}}`.

## Next step

S4 (the ngspice round trip) should resolve it: netlist a cell holding a
`pfet_g5v0d16v0_nf`, `.save` both spellings, and see which one produces a
non-zero column and no `unrecognized variable` warning. Then fix the losing side
and flip row P7's golden to `{40 {}}`.
