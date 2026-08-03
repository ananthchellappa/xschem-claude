# Next session — close the ase_migrate residue (issue 0210)

Paste everything below the line into a fresh session.

---

Read `doc/claude/issues/0210-ase-migrate-source-library-leaks-and-sg13g2.md`
first — it is the audit write-up for the work that just landed (`c69b88de`,
`a3c0e2f1`, `031ed5dc` on branch `fluid-editing`, all UNPUSHED). Its "Residue"
section lists confirmed, adversarially-verified defects that were deliberately
left unfixed. Your job is to close them, starting with the ones that keep real
benches from simulating.

## The state of play

`sky130A/xschem_libs/sky130_tests_ase` (48 cells) is freshly regenerated. Run
through `ase::run`, **29 pass and 19 fail**. All 19 fail identically in the
pre-regeneration tree, so none is a regression — they are pre-existing migrator
holes. `ihp-sg13g2/xschem_libs/sg13g2_tests_ase` is 48/48 passing and should
stay that way.

Reproduce the 19 with a harness like
`/tmp/.../scratchpad/sky_sim.tcl` from the prior session, or roll your own: for
each cell, `ase::state_load` its `ngspice_state1` view, `dict set ... rundir`
to a scratch dir, `ase::run` + `ase::wait`, then grep the `<cell>_ase.log` for
`fatal|valid modelname|could not find include|no such file|error on line|unknown
subckt|is not in the circuit|syntax error`. Register the tree by pointing
`XSCHEM_LIBRARY_DEFS` at `sky130A/xschem_libs/library.defs` with
`library_registry_defs_only 1`, and set `::SKYWATER_MODELS` to
`sky130A/models/libs.tech/combined`. Run under `--nogui` (sourcing
`sky130A/cadence_style_rc` dies with `invalid command name "bind"` without Tk).

## The 19, bucketed by ACTUAL cause

The prior session's summary blamed all of these on one bug. That was wrong —
here is the measured breakdown. Fix them as separate items.

**A — `includes` naming a Tcl variable nobody sets (7 cells).**
`LACG optimize_delay tb_charge_pump test_carry_lookahead test_ff test_stdcells`
carry `includes {{file {$::SKYWATER_STDCELLS/sky130_fd_sc_hd.spice}}}`;
`test_hvl_cells` carries `$PDK_ROOT/$PDK/...`. `ase::run` throws
`ase: cannot expand model path ... can't read "::SKYWATER_STDCELLS"` before
ngspice ever starts. `::SKYWATER_STDCELLS` is never `set` anywhere (it only
appears in a variable-NAME list at `src/xschem.tcl:13705`), `::PDK_ROOT`/`::PDK`
are never set as Tcl globals either (`sky130A/cadence_style_rc` sets
`::env(PDK)` only), and `sky130_fd_sc_hd.spice` does not exist anywhere in the
repo. This is finding `includes-unresolvable-vars`.
Decide and implement: either `sky130A/cadence_style_rc` sets the variable at a
real path, or the migrator treats an unresolvable QUALIFIED `$::VAR` the same
way it now treats an unresolvable relative include (drop + loud warning). The
migrator's existing check (`_UNQUAL_VAR_RE`, `ase_migrate.py` `_build_state`)
only catches UNqualified `$VAR` — extend it. Whichever you pick, the 7 cells
must either run or fail with an honest message at MIGRATION time, not at Run.

**B — a `dc` sweep naming a source the migration deleted (4 cells).**
`srlatch test_nmos test_nmos_sizes test_pmos` →
`Fatal error: DC Transfer Function: Voltage source, current source, or resistor
named "vd" is not in the circuit`.
Root cause is the headline hole, **`embedded-nondot-lines-silently-dropped`**:
`SpiceDeck._parse_top_line` maps dot-cards and its LAST statement is
`if line.startswith("."): warn`. A line that does not start with `.` falls off
the end of the function with no destination and **no warning**. The swept source
is declared as exactly such a line (`vd d 0 0`) inside the same
`code_shown`/`simulator_commands` block, so it is deleted while
`_parse_analysis` copies its name into `analyses`. Measured at HEAD:
**54 non-dot lines silently dropped across 15 of the 48 sky130 cells**
(`stdcells_xspice` alone loses 13 XSPICE `A`-devices — its entire circuit;
`test_inv`, `test_mos_binning`, `sky130_oscillator` lose their sources too).
`sg13g2_tests` loses 0, so this is sky130-shaped, not universal.
Fix the root cause — give the fall-through a destination and a warning, same
LOSSLESS-OR-LOUD contract as `_parse_control_line`'s catch-all — and then add
the cross-check the audit asked for: after `_reconstruct`, validate every
`analyses` entry that names a source against the `name=` values of the `C`
records kept on the clean schematic, plus ngspice's special sweeps (`temp` is
legitimate — `test_res` uses it). On a miss, warn loudly and set `enabled 0`
rather than ship a state that detonates at Run.

**C — a lost `.MODEL` card (1 cell).**
`test_jfet` → `Unable to find definition of model 2n3459`. Its
`.MODEL 2N3459 NJF(...)` hits the silent `return` at `_parse_top_line`'s
`.end/.title/.global/.model/.subckt/.ends/.ic/.nodeset` guard. `.model`, `.ic`
and `.nodeset` are real simulation setup, not structure — they must not be
silently swallowed. 11 such cards are dropped across the sky130 tree.

**D — `unknown subckt: sky130_fd_pr__*` (4 cells).**
`bandgap bandgap_opamp charge_pump charge_pump2`. The device subcircuits are not
defined by whatever the state's `models` entry pulls in. NOT yet diagnosed —
work out whether the corner→`.lib`/section mapping picks the wrong section, or
whether an `.include`/`.lib` line was lost by bucket B. Do this one by reading
the cluttered original's embedded block against the migrated `models`/`includes`
before changing any code.

**E — a missing OSDI artifact (2 cells).**
`tb_diff_amp` and `top` →
`Error opening osdi lib ".../.xschem/xschem_library/diff_amp.osdi"`. A
user-tree artifact that does not exist. Decide whether the migrator should
resolve/validate `osdi` paths the way it now validates relative includes.

**F — `lvnand` (1 cell).**
`Error in netlist line no. 1959 ... Formula() error.` Diagnose from scratch; it
also loses `vd d 0 0`/`vg g 0 0` to bucket B, so re-check it AFTER B is fixed —
it may fall out for free.

## Also in the residue, not blocking a bench

Lower priority, all named and reproduced in 0210:
`dc-second-sweep-dropped` (13 cells lose the second sweep source — a genuine ASE
schema gap: `src/ase.tcl`'s dc render emits exactly four fields),
`temperature-overrides-options-temp`, `nonvector-output-exprs`,
`gettok-quote-truncation` (`migrate_pin_names.get_tok` ends a quoted value at
the first inner `"` where `src/token.c:506-507` TOGGLES a quote flag),
`library-verify-silently-ignored` (`--library --verify` is accepted and does
nothing), `drop-only-cells-skipped` (the scan trigger tests 3 of the 4 clutter
categories).

## Acceptance

- `python3 tools/migrate/test_ase_migrate.py` — currently 110 checks, ALL PASS.
  Add a check per fix, and **sabotage-verify each new path** (break it, confirm
  a named check goes red, restore). A green suite is not evidence the changed
  code ran.
- `./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_core.tcl`
  and `test_ase_persist`, `test_ase_final`, `test_ase_final_gf180` — all green.
- sky130 `sky130_tests_ase`: **more than 29 of 48 passing, and zero regressions**
  against the current tree. Report the exact before/after failure SETS, not just
  counts.
- sg13g2 `sg13g2_tests_ase`: still **48/48**.
- Regenerate both trees when the migrator changes. **`sky130_tests_ase/tb_bandgap`
  carries a hand-added 2-graph waveform-viewer layout and `save_all_v 1`** —
  lift them off the pre-regeneration file with `ase::state_load`/`ase::state_save`
  and re-apply, NEVER by text-munging the state line (the outer list braces come
  along and corrupt the dict). Diff the regenerated tree field-by-field and
  justify every delta before committing.

## Traps

- Any change to the ASE state schema means canonicalizing **every committed
  `.state`** (52 today) through `ase::state_save`, and updating THREE separate
  schema-key-count assertions: `test_ase_core` R1, `test_ase_persist` R1, and
  the Python golden in `tools/migrate/test_ase_migrate.py`.
- The cluttered originals write `.raw`/`.csv` litter into the CWD when you run
  them for comparison. Run them from a scratch dir or clean up — the prior
  session had to move 31 stray files back out of the repo root.
- `--nogui` marks ~67 GUI suites NORESULT and ~68 more as SKIP-shaped FAILs.
  Five suites (`test_context_menu_descend_edit`, `test_lib_sweep`,
  `test_load_window_routing`, `test_nh_angle_clamp`, `test_reopen_readonly`)
  fail under `--nogui` at HEAD — verify against HEAD before blaming a change.
- Commit when the suites are green; do NOT push unless asked.
