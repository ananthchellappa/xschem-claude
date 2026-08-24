# 0663 — a Tcl error in any file sourced late by `xschem.tcl` SEGFAULTS startup

Status: PARTIALLY FIXED for `ciw.tcl` only (issue 0658). The CLASS is open.
Filed by: the 0658 crew, 2026-08-24.

## Measured

Build a throw-away `XSCHEM_SHAREDIR` (a symlink farm over `src/`, with one file
replaced — `XSCHEM_SHAREDIR` is priority 1 in the share-dir search,
`src/xinit.c:2985`) whose `ciw.tcl` is a one-line `error {...}`. Then launch
`./src/xschem --nogui --pipe -q --logdir <d> --script <t>.tcl`:

```
error at the TOP of ciw.tcl          -> SIGSEGV, exit 139, the script never runs
error at the END of ciw.tcl          -> SIGSEGV, exit 139
ciw.tcl ABSENT (the pure 0424 shape) -> SIGSEGV, exit 139
```

preceded on stderr by `can't read "line_width": no such variable` … `can't read
"cairo_font_scale": no such variable`.

## Mechanism

`src/xschem.tcl` sources its helpers with a BARE `source`. A Tcl error inside a
helper propagates OUT of `xschem.tcl`, so the remaining lines of `xschem.tcl`
never run — the statusbar widgets, `build_widgets`, `ciw_create`, the colour
setup. `source_tcl_file()` (`src/xinit.c:1513`) merely prints the error and
RETURNS; `Tcl_AppInit` ignores the return value (`src/xinit.c:3406`) and walks
on into `tclgetdoublevar("cairo_font_line_spacing")` against variables that were
never set. That is the crash.

⚠ This REFUTES a sentence in issue 0658 — "any Tcl error anywhere in
`src/ciw.tcl` kills the whole file, and `xschem.tcl` continues past a failed
source". It is `Tcl_AppInit` that continues past a failed source of
*`xschem.tcl`*, NOT `xschem.tcl` past a failed source of a helper.

It is also the 0423/0424 signature: 0424 lost `op_annot.tcl` from the install
list and the INSTALLED binary segfaulted at startup while all 275 in-tree checks
stayed green.

## What 0658 fixed, and what it did not

0658 wrapped exactly ONE of these sources — `source $XSCHEM_SHAREDIR/ciw.tcl`
(`src/xschem.tcl:14854`) — plus the one startup call into that file
(`ciw_create`, `src/xschem.tcl:16919`), and made the catch ANNOUNCE rather than
continue silently (`xschem::notify_degraded_once`, which answers 0423's standing
objection to catching a source). Measured after: exit 0, the session runs
degraded, every notice still reaches the durable log.

Every OTHER late `source` in `xschem.tcl` — `op_annot.tcl`, `cmdmode.tcl`,
`ase.tcl`, `ase_window.tcl`, `wave_viewer.tcl`, `calculator.tcl`,
`property_form.tcl`, `alt2_toggle_view.tcl`, `library_*.tcl`,
`create_instance.tcl`, `save_as_form.tcl`, `action_registry.tcl` … — is still
bare and still has this failure mode.

## Probable fix

Either (a) catch each helper source the way `ciw.tcl` now is, announcing the
failure once and continuing, or (b) fix the real hole in
`Tcl_AppInit`/`source_tcl_file` so a failed source of `xschem.tcl` does not walk
on into unset variables — the C-side half, which is where 0423 already points.
(b) is the smaller blast radius per file but the larger one overall, and it is a
C change; (a) is pure Tcl and is what 0658 could afford.

## Still open

Everything except `ciw.tcl`.
