# 0965 — two devices on the bandgap bench get a name ngspice cannot resolve

**FILED, NOT FIXED — the tier work of issue 0963 shipped over it, 2026-08-30.**

Status: OPEN. Out of scope for the tier work; it is the reason the one-write-line
form cannot be chosen for anyone automatically, and that refusal is guard G4 of
`ase::op_save_tier` (`doc/claude/specs/op_annotation.md` §4.3b).

## Measured on sky130_tests_ase/tb_bandgap

Of the 78 device names this tree emits, two cannot be resolved:

    Error: no such device or model name m.x1.x5.xm2.msky130_fd_pr__pfet_01v8_lvt
    Error: no such device or model name m.x1.x6.xm2.msky130_fd_pr__pfet_01v8_lvt

Both are passgate `pfet_01v8_lvt` instances at `W_P=0.6 / L_P=0.35`. The SAME
subcircuit at `W_P=0.5 / L_P=0.15` resolves fine, so this is a device-path
defect and not a missing device.

## What it costs, by form

* per-device requests: **12 silently blank rows out of 468**; the operating
  point survives with 456 device vectors.
* one write line: **the entire operating point**, at exit 0 —
  `Error during 'write': no writable vector found.`, and no results file at all.

Minimal reproduction is 12 lines of SPICE: an `op`, then
`write onebad.raw all @m.xi1.m1 @m.xi1.mNOPE`. Exit 0, no file.

