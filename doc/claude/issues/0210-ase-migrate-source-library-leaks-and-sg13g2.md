# 0210 — ase_migrate: the migrated tree still pointed at the source library

Status: **FIXED** (this round) — with a named residue list at the bottom.

## Reported

> the ngspice_state1 created for each migrated test in a starting library would
> store as its schematic reference, the schematic from the starting library
> instead of the migrated library.

## What was actually true

There are **three** places a migrated cell can name a library, and only one of
them had been fixed.

1. **the state's `design {lib …}`** — fixed by c31fad1d (0167). Verified still
   correct: regenerating `sky130_tests_ase` at HEAD gives
   `design {lib sky130_tests_ase …}` in all 48 states.

2. **`C {<srclib>/<cell>}` symrefs on the migrated schematic** — **still broken.**
   `_reconstruct()` re-emits each kept record as a verbatim byte slice of the
   source text and `classify()` calls every non-corner/embed/launcher `C` record
   "circuit", so nothing ever rewrote field 0. The migrated `sky130_tests_ase`
   tree carries 134 `sky130_tests/…` symrefs across 19 of its 48 cells, and in
   **10 of those the referenced cell is itself migrated** — e.g. the clean
   `sky130_tests_ase/tb_bandgap` instantiates `sky130_tests/bandgap`, the
   *cluttered* original. ASE opens the clean bench and then netlists the
   cluttered sibling one level down. This is the reported bug, one level down
   from where it was looked for.

3. **no `symbol/<cell>.sym` in the destination** — `write()` emitted exactly two
   files per cell. `cellview_resolve` (src/library_defs.tcl) needs
   `<libpath>/<cell>/symbol/<cell>.sym`, so even a correctly rebound
   `sky130_tests_ase/<cell>` would have resolved to nothing.

Plus: **no library registration**. The tool wrote no `library.tag` and no
`DEFINE`. `sky130A/xschem_libs/sky130_tests_ase/library.tag` exists only because
commit 15bb25ef hand-wrote it. A Cadence-style workarea sets
`library_registry_defs_only 1`, so without a `DEFINE` the destination library is
invisible and the c31fad1d `design=` value is dead on arrival.

## Fix

`tools/migrate/ase_migrate.py`:

- `_rebind_ref` / `_rebind_text`: `C {…}` symrefs and lib-qualified
  `schematic=` overrides are rewritten `<srclib>/<cell>` → `<dstlib>/<cell>`
  **when `<cell>` is itself migrated**. A reference to a clutter-free sibling
  (no `_ase` counterpart) keeps naming the source library, which stays
  registered beside the destination. Rewrites happen *after* reconstruction —
  `_reconstruct` slices the source text by absolute record offsets. The rebind
  set is the whole scan result, computed before the first write, so an
  A-instantiates-B pair cannot be rebound inconsistently.
- `write()` copies `symbol/<cell>.sym`, rebound the same way.
- `migrate_all()` writes `<out_root>/library.tag`; the CLI prints the exact
  `DEFINE` line it cannot write itself.
- report line `rebound N ref(s): a->b, …`.

Measured on `sky130_tests` → a scratch `sky130_tests_ase`: 56 refs rebound, 78
correctly left at the source library, 0 migrated cells still pointing at the
cluttered tree, 44 symbol views written.

## sg13g2 migration (the other half of the request)

`--pdk sg13g2` added (`Pdk("sg13g2", "MODELS_NGSPICE")` — gf180-shaped: a
`code_shown` block in portable `$::VAR` form, no corner symbol), plus:

- **`pre_commands` state field** (`src/ase.tcl` `schema_keys` / `state_default` /
  `render_deck`, seeded by `::ASE_DEFAULT_PRE_COMMANDS`). ngspice's `pre_*`
  family runs before the netlist is parsed and is the only way to load a
  compiled Verilog-A module — `pre_osdi <file>.osdi`; there is no `.osdi`
  dot-card. All 48 IHP benches carry four of them (192 lines). They used to land
  in the report-only `raw_control` bin, which would have made **every** migrated
  IHP bench die at `could not find a valid modelname`.
- **`+` continuation folding** in the deck parser — without it a continued card
  (`pre_set auto_bridge_d_out =` + two `+ ( ".model …" )` lines) migrated as a
  head with no tail.
- **unresolvable relative `.include` dropped**: 12 IHP benches (and 8
  already-shipped sky130 states) `.include <cell>.save`, a file *generated* by
  the bench's own launcher button — which migration drops. ngspice aborts the
  whole deck on it. Now removed with a loud warning, and `save_all_i` turned on
  to stand in.
- **control-shell `$var` exprs rejected**: the six MC benches end with
  `print {$scratch}.vg`; `.save {$scratch}.vg` is `Syntax error: letter [$]`.
- **an unmappable analysis no longer falls back to a fabricated `op`**: the
  `sp_*` benches used to migrate to a healthy-looking operating point in place
  of their S-parameter sweep. They now migrate with every analysis disabled and
  say so.

Result — `ihp-sg13g2/xschem_libs/sg13g2_tests_ase`, 48 of 49 cells
(`IHP_testcases` is the gallery index, correctly skipped):

- 48/48 render a deck that runs to completion under ngspice-46; 45 write a raw
  (the 3 `sp_*` correctly have no enabled analysis);
- all 48 `design {lib …}` resolve through `xschem cellview_path` into the
  **migrated** tree; 43 symbol views resolve;
- of the 10 cells whose cluttered original also runs headless, the migrated raw
  is **bit-identical** — the two `res_typ_stat` cells differ only by their own
  model-level Monte-Carlo draw (proven: re-running the *same* migrated state
  differs by more than the before/after gap).

## Residue — confirmed by audit, NOT fixed here

Named so they are not rediscovered from scratch. Each was reproduced and
adversarially verified.

- **`embedded-nondot-lines-silently-dropped`** — a line in an embedded code
  block that does not start with `.` falls off the end of `_parse_top_line` with
  no destination and *no warning*; `.model`/`.ic`/`.nodeset` return silently.
  16 of the 48 sky130 cells lose 68 lines (test_jfet loses its `.MODEL 2N3459`,
  stdcells_xspice loses all 13 XSPICE A-devices). Violates LOSSLESS-OR-LOUD.
- **`analyses-dangling-dc-source`** — 6 sky130 states ship `dc source vd` naming
  a source the migration itself deleted (a consequence of the above); ngspice
  hard-fatals. Needs a post-reconstruction cross-check of `analyses.source`
  against the surviving `C` record `name=` values.
- **`dc-second-sweep-dropped`** — `dc <s1> … <s2> …` loses its second source in
  13 cells across two libraries: one curve instead of a family. Genuine ASE
  schema gap (`src/ase.tcl` dc render emits exactly four fields).
- **`temperature-overrides-options-temp`** — `.option temp=<expr>` lands in
  `options` while `temperature` stays 27; render_deck emits `.temp 27` last and
  ngspice lets `.temp` win.
- **`nonvector-output-exprs`** — a `print`ed name defined by a dropped
  `let`/`meas` still becomes an output with `save 1`.
- **`gettok-quote-truncation`** — `migrate_pin_names.get_tok` ends a quoted value
  at the first inner `"`, where `src/token.c` *toggles* a quote flag. Two IHP
  benches carry balanced inner quotes and are silently truncated.
- **`library-verify-silently-ignored`** — `--library --verify` is accepted and
  does nothing; the `--library` branch returns before the verify block.
- **`drop-only-cells-skipped`** — the scan trigger tests three of the four
  clutter categories, so a cell whose only clutter is a launcher is skipped.
`sky130_tests_ase` **has since been regenerated** (a3c0e2f1): 56 refs rebound,
78 correctly left at the source library, 44 symbol views added, 8 dangling
includes dropped; tb_bandgap's hand-added viewer layout and `save_all_v 1`
lifted off the pre-regeneration file through `ase::state_load`/`state_save` and
preserved byte-for-byte. Old vs new under identical conditions: 22 → 29 passing,
zero regressions. The 19 that still fail fail identically in both trees and are
exactly the residue above.
