# 1207 - netlisting eight shipped viewdraw_import sheets segfaults, in every backend

**Branch:** annotate
**Status:** OPEN - measured, not fixed. PRE-EXISTING; not caused by [[1201]].
**Filed by:** item S6, write-up pass, 2026-08-31

## What the user sees

They open one of the shipped `xschem_library/viewdraw_import/xschem_lib/dti_*`
sheets with the viewdraw symbols on the library path, and press netlist. XSCHEM
dies:

```
EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_dti_28hc_6p5t_40_nand2x1_...
FATAL: signal 11
while editing: dti_28hc_6p5t_40_nand2x1
```

## Measured

Found by item S6's verify pass while sweeping every shipped schematic under
`sky130A/`, `gf180mcuD/`, `ihp-sg13g2/`, `xschem_library/` and
`xschem_libs_newsym/`: 646 of 654 netlisted cleanly, and these 8 could not be
netlisted at all.

Family: `xschem_library/viewdraw_import/xschem_lib/dti_28hc_6p5t_40_nand2x1.sch`,
`...nor2x1.sch` and the rest of that directory.

It needs the viewdraw symbols to RESOLVE. With the stock library path they are
not found and the sheet netlists fine, which is presumably why nobody has hit
it.

## PROOF IT IS NOT [[1201]]

It reproduces in all five netlist types, including the ones [[1201]] never
touches. Backtrace under tEDAx, where `auto_spec_begin()` is never called:

```
__strcmp_avx2
  <- instcheck                 (src/netlist.c:1444)
  <- name_attached_inst_to_net (src/netlist.c:1105)
  <- wirecheck
  <- set_unnamed_net           (src/netlist.c:1655)
  <- prepare_netlist_structs   (src/netlist.c:1851)
  <- tedax_netlist             (src/tedax_netlist.c:33)
  <- global_tedax_netlist
```

Neither `src/netlist.c` nor `src/tedax_netlist.c` is in item S6's diff.

## What is owed

A repro with the library path that makes the symbols resolve, then a look at
what `instcheck()` is handed a NULL for. Per the house rule for crash-prone
subjects, the row belongs in a SPAWNED CHILD - xschem installs its own SIGSEGV
handler, so a crash exits 1, not 139.

## Rows

None anywhere.
