# 0449 — `find_file_first <cell>.sym` returns a stray path under a registry-only PDK config

Status: OPEN, NOT FIXED. Filed by S6 (the PDK-neutral annotator carrier), which
routed AROUND it (decision D2) rather than fixing an out-of-cell defect.
Found: S6 scout/plan measurement on branch `annotate` at 9fe40128.
Related: the shipped caller is src/xschem.tcl:15309, "Add waveform reload launcher".

## What is wrong

`find_file_first` searches by BARE FILENAME across the library search path. In a
PDK workarea that path is empty by design — all three shipped workareas set

    set XSCHEM_LIBRARY_PATH {}
    set library_registry_defs_only 1

(sky130A/cadence_style_rc:27, ihp-sg13g2/cadence_style_rc:27,
gf180mcuD/cadence_style_rc:26) and resolve every library through `library.defs`
instead. Measured under a sky130 registry-only config:

    find_file_first launcher.sym
      -> .../tests/test_sweep_diff/devices/launcher/symbol/launcher.sym   (a stray)
    find_file_first devices/launcher.sym                                  -> {}
    abs_sym_path devices/launcher .sym
      -> .../xschem_libs_newsym/devices/launcher/symbol/launcher.sym      (correct)

So the shipped "Add waveform reload launcher" menu item places the WRONG FILE in
a PDK workarea whenever some other tree happens to hold a same-named cell, and
places nothing at all when nothing matches. Nothing warns.

## Why S6 did not fix it

Out of S6's Files cell, and it is a defect in a neighbouring shipped menu item,
not in the carrier. S6's own menu item instead names the symbol
library-qualified — `devices/annotate_params` — the same spelling the IHP menu
already uses for `devices/code_shown`. That form resolves through library.defs,
which is what every workarea uses.

## Note for whoever fixes it

`abs_sym_path <lib>/<cell> .sym` and the C loader DISAGREE on a
library-qualified name when a matching file also sits on XSCHEM_LIBRARY_PATH:
measured, `abs_sym_path` returned a scratch `devices/annotate_params.sym` while
the loader still printed `l_s_d(): Symbol not found: devices/annotate_params`.
A fix must be validated against the LOADER (`xschem getprop symbol <name> type`
reporting anything but `missing`), not against the resolver.
