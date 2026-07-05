# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

XSCHEM is a hierarchical schematic capture and netlisting EDA tool for VLSI/analog
custom design. It draws schematics and symbols and generates SPICE, Spectre, VHDL,
Verilog and tEDAx netlists. The drawing engine is plain C on top of Xlib primitives
(optionally Cairo for text/anti-aliasing); the GUI and the extension/scripting
language are Tcl/Tk.

## Build & run

```sh
./configure          # wraps scconfig; run from repo root. See ./configure --help
make                 # builds src/, xschem_library/, doc/, src/utile/
make install         # installs (honors DESTDIR=/tmp/pkg and PREFIX)
cd src && ./xschem   # run directly from the source tree, no install needed
```

- Build is **scconfig**-based (a self-contained ./configure system under `scconfig/`),
  not autotools. `configure` regenerates `Makefile.conf` and `config.h` from the
  `.in` templates — edit the `.in` files, not the generated ones (they carry a
  "DO NOT EDIT" header).
- Requires a C89 compiler, awk (mawk/gawk), Tcl/Tk 8.4–8.6, Xlib, Xpm, bison, flex.
  Optional: cairo, xcb, xrender.
- `src/Makefile` lists object files explicitly in `OBJ` — adding a new `.c` file
  means adding it to `OBJ` and adding an explicit compile rule (or regenerate from
  `Makefile.in`).
- A `CMakeLists.txt` exists as an alternative build but the Makefile path is canonical.

### Generated parsers (do not hand-edit the .c)
- `expandlabel.c`/`expandlabel.h` ← bison from `expandlabel.y` (bus/label expansion)
- `eval_expr.c` ← bison from `eval_expr.y`, prefix `kk` (expression evaluator)
- `parselabel.c` ← flex from `parselabel.l`

## Tests

Regression tests live in `tests/` and are driven by Tcl, comparing generated output
against golden files.

```sh
cd tests
tclsh run_regression.tcl        # runs all cases: create_save, open_close, netlisting
```

- Each case is a `<name>.tcl` script; `run_regression.tcl` execs them and greps
  `results.log` for `FAIL` / `GOLD?` / `FATAL`. To run one case, source its script
  directly (e.g. `tclsh netlisting.tcl`).
- Tests invoke the built binary headless via `xschem ... --pipe -q --script <file>`.
- `xschemtest.tcl` is a broader functional/perf harness, run as
  `xschem --script xschemtest.tcl` then calling `xschemtest`. Use `-d 3 -l log` to
  log allocations for leak checking.

## Architecture

### The `xctx` global context
Almost all program state hangs off a single global `Xschem_ctx *xctx` (defined in
`xschem.h`, ~`Xschem_ctx` struct). It holds the current schematic's object arrays
(`wire`, `inst`, `sym`, `rect[layer]`, `line[layer]`, `poly`, `arc`, `text`),
the hierarchy stack (`sch[CADMAXHIER]`, `sch_path[]`, `currsch`), zoom/pan state,
selection (`sel_array`), spatial hash tables, undo slots, highlight/node tables, and
the drawing GCs/colors. When reading or modifying behavior, the relevant fields are
usually grouped in the struct with comments pointing to the owning `.c` file
(e.g. `/* move.c */`, `/* callback.c */`). Multiple open windows/tabs each have their
own context — see `get_save_xctx()` / `get_old_xctx()` and the tabbed-interface logic
in `xinit.c`.

Core object types (`xWire`, `xRect`, `xLine`, `xPoly`, `xArc`, `xText`, `xInstance`,
`xSymbol`) are all defined together near the top of `xschem.h`.

### The `xschem` Tcl command — central dispatcher
The C core exposes essentially all functionality through one Tcl command, `xschem`,
registered in `xinit.c` (`Tcl_CreateCommand(interp, "xschem", ...)`) and implemented
by the giant dispatcher `scheduler()` in `scheduler.c` (function `xschem(...)`). Tcl
scripts, menus, keybindings and tests all drive the editor by calling
`xschem <subcommand> ...` (e.g. `xschem load`, `xschem netlist`, `xschem hilight`,
`xschem get xorigin`, `xschem callback ...`). **When adding a new user-facing
operation, you add a branch in `scheduler.c` and usually wire it up from Tcl** rather
than inventing a new C entry point. GUI events are funneled in as
`xschem callback <win> <event> ...` → `callback()` in `callback.c`.

### Layering: C engine ↔ Tcl GUI
- `src/xschem.tcl` (~12k lines) is the Tcl GUI: menus, dialogs, simulation launchers,
  preferences. Many config variables are deliberately **mirrored between C and Tcl**
  (search `MIRRORED IN TCL` in `xschem.h`) — keep both sides in sync when changing one.
- Other `.tcl` files are loadable helpers (`mouse_bindings.tcl`, `place_pins.tcl`,
  `create_graph.tcl`, `*_backannotate.tcl`, custom menu/button hooks).
- The C side reads/writes Tcl variables via helpers like `tclgetvar`,
  `tclgetboolvar`, `tcleval`.

### Drawing
`draw.c` is the rendering core over Xlib (with `#if HAS_CAIRO` paths for text/images;
`svgdraw.c` and `psprint.c` produce SVG and PostScript/PDF output). `font.c` holds the
vector font. Spatial hash tables in `xctx` (`*_spatial_table[NBOXES][NBOXES]`)
accelerate hit-testing and selection.

### Netlisting
`netlist.c` is the shared hierarchy traversal and node-naming machinery; per-format
backends are separate files: `spice_netlist.c`, `spectre_netlist.c`,
`vhdl_netlist.c`, `verilog_netlist.c`, `tedax_netlist.c`. Label/bus expansion goes
through the bison/flex parsers. Highlighting and node tracing live in `hilight.c`,
`findnet.c`, `node_hash.c`.

### Editing pipeline
`actions.c` (largest file — high-level edit ops), `move.c`, `paste.c`, `clip.c`,
`select.c`, `editprop.c` (property/attribute editing), `store.c` (object allocation),
`save.c` (the `.sch`/`.sym` file format I/O), `check.c` (ERC/symbol consistency),
`in_memory_undo.c` (undo can be on-disk or in-memory; chosen via the `push_undo`/
`pop_undo` function pointers in `xctx`).

### awk scripts
The many `*.awk` scripts in `src/` are import/convert/flatten utilities (e.g.
`gschemtoxschem.awk`, `make_sym_from_spice.awk`, `flatten.awk`). They are part of the
shipped toolchain, invoked from Tcl, not build-time codegen.

## Symbol & schematic libraries
`xschem_library/` holds the standard device symbols (`devices/`) plus example
designs and generators. The library search path is configured in `Makefile.conf`
(`xschem_library_path`) and overridable in `~/.xschem/xschemrc` or a `./.xschemrc`.
`.sym` (symbol) and `.sch` (schematic) share the same text record format handled by
`save.c`; the format version is `XSCHEM_FILE_VERSION` in `xschem.h`.

## Conventions
- C89 throughout; the codebase targets both Unix and Windows (`XSchemWin/` holds the
  Windows config). Guard platform code with `__unix__`.
- Memory tracking: allocations use id-tagged wrappers (`my_malloc`, `my_realloc`,
  `my_strdup`, etc.) whose first arg is the placeholder macro `_ALLOC_ID_`. The
  `create_alloc_ids*.awk` / `get_malloc_id.awk` scripts rewrite those placeholders
  into unique numeric ids for leak tracing — write `_ALLOC_ID_`, don't hand-number.
  Debug logging via `dbg(level, ...)`.

## AI / planning docs
Design and working notes live under `doc/claude/` (not installed — `doc/Makefile`
ships only `*.svg/*.html/*.css/*.png`): `doc/claude/specs/` (feature specs),
`doc/claude/issues/` (numbered issue tracker, `NNNN-*.md`), `doc/claude/code_analysis/`
(analysis & decision write-ups), `doc/claude/suggestions/` (session prompts, plans), and
`doc/claude/FAQ.md` (a running design Q&A, newest entries on top).
Source comments reference these by their full path (e.g. `see doc/claude/specs/foo.md`).
