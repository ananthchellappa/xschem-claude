# 0285 — `xschem load` on a non-schematic file succeeds, empty, and arms a save that overwrites it

Status: **OPEN** — measured, not fixed. The Tcl-side routing that made this reachable from the UI
is closed (§B of `doc/claude/specs/mixed_signal_signal_browser.md`, commit on `fluid-editing`);
this issue is the primitive underneath, which is still there for any direct caller.
Area: the ASCII loader, `src/save.c` (`load_ascii_file` / the record dispatch that prints
`SKIP RECORD`), reached from `xschem load` in `src/scheduler.c`.
Tests: `tests/headless/test_verilog_view_model.tcl` covers the ROUTING (no UI path hands a `.v`
to the loader any more). Nothing covers the loader itself refusing one.
Found: 2026-08-08, building §B of the mixed-signal spec.
Related: `doc/claude/specs/mixed_signal_signal_browser.md` §B (B1/B5/B6 — the routing fix).
Numbered 0285 to leave a gap above the local maximum 0279 (`github/open_pdk` is at 0263).

## Measured

```
$ ./src/xschem --nogui --pipe -q --script p.tcl
#   xschem load .../ngspice_verilog_cosim_ase/counter/verilog/counter.v
SKIP RECORD
`timescale 1ps/1ps // needed for Icarus
END SKIP RECORD
...                                     <- every line of the Verilog, skipped
load returned OK                        <- no error, no non-zero status
schname : .../counter/verilog/counter.v
wires=0 instances=0 texts=0 modified=0
```

The loader treats an unrecognized leading token as a record to skip — forward-compatibility
behaviour that is right for an unknown *schematic* record and wrong for a file that is not a
schematic at all. The result is an **empty schematic whose `schname` is the source file**, marked
unmodified. Ctrl-S then writes an empty `.sch` over the Verilog. The source survived the probe
only because nothing saved.

The same applies to any text file: a `.v`, `.va`, a README, a netlist.

## Why the §B fix is not the whole fix

§B removed every *UI* route to this: `libmgr::view_handler` sends `.v`/`.va` to `edit_file`,
`libmgr::open_view` / `open_view_ro` dispatch the resolved handler, `alt2_toggle_view` opens a
source candidate as text, and `lib_qualified_abs` no longer resolves `lib/cell.v` to the symbol.
What remains reachable:

- `xschem load <file>` typed in the CIW, or from a user script / action log;
- any future caller that resolves a path and loads it without consulting the view type;
- the file-open dialog, if a user selects a `.v` through the "all files" filter.

## Fix sketch

Refuse in the loader, do not silently empty-load. Two candidates, in preference order:

1. **Count what was understood.** If a file yields zero recognized records but non-zero skipped
   ones, that is not a schematic — fail the load and leave the previous context intact. This is
   extension-independent, so it also catches a `.sch` that is actually a netlist.
2. **Check the extension up front** against the same table §B introduced on the Tcl side
   (`view_type_of_ext` in `src/library_defs.tcl`). Cheap, but duplicates the table in C and
   says nothing about a mis-named file.

Whichever is chosen, the failure must be a real error return (so `catch` in Tcl sees it), not a
message on stdout — the measured behaviour above already prints plenty and still "returned OK".

A regression test belongs in `tests/headless/`: load a `.v`, assert the load fails AND that the
previously-loaded schematic is still current (the second half matters — a refusal that still
clears the context is its own data-loss bug).
