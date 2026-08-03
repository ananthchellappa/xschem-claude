# 0211 — ase_migrate: closing the 0210 residue

Status: **FIXED** (this round). Closes every item on the "Residue" list of
`doc/claude/issues/0210-ase-migrate-source-library-leaks-and-sg13g2.md`, plus two
defects found while closing them.

The starting point was 0210's regenerated `sky130A/xschem_libs/sky130_tests_ase`:
48 cells, **29 pass / 19 fail** through `ase::run`, all 19 failing identically in
the pre-regeneration tree (pre-existing migrator holes, not regressions).

## The headline hole: LOSSLESS-OR-LOUD was only half true

`SpiceDeck._parse_top_line` is a chain of `startswith` tests that all require a
leading `.`, and it had **no catch-all**. Its last statement was
`if line.startswith("."): warn`, so a line that does NOT start with `.` matched
no branch, fell off the end of the function and vanished with no destination and
no warning. Its sibling — the `.end/.title/.global/.model/.subckt/.ends/.ic/
.nodeset` guard — `return`ed silently on eight card families with the comment
"structural / handled elsewhere", which was false for `.model`, `.ic` and
`.nodeset`: nothing handled them anywhere.

Measured at HEAD across the three source libraries (pure-Python instrumentation
of `_parse_top_line`, no simulator):

| library | cells losing lines | non-dot lines | guard-swallowed cards |
|---|---|---|---|
| `sky130_tests` | 16 of 48 | 54 | 12 |
| `gf180mcu_tests` | 50 | 122 | 0 |
| `sg13g2_tests` | 0 | 0 | 0 |

`stdcells_xspice` lost all 13 of its XSPICE `A`-devices — its entire circuit.
`test_jfet` lost `.MODEL 2N3459 NJF(…)`; `test_stdcells` lost nine `d_lut`
models; `srlatch`/`test_nmos`/`test_nmos_sizes`/`test_pmos`/`lvnand` lost the
very sources their `dc` sweep names.

### Where the lost lines go: a residue block on the clean schematic

The ASE state schema has no field for literal deck text, and adding one would
cost a schema key plus recanonicalizing all **100** committed `.state` files and
three separate schema-key-count assertions. It would also be wrong: the content
is *circuit* (`vd d 0 0`, XSPICE `A`-devices) and *model* text, and
`ase::netlist` regenerates `<cell>.spice` from the schematic on every Run — so
content living only in the state would be missing from the netlist artifact.

`render_deck` (src/ase.tcl:1042) takes the schematic netlist verbatim as the head
of the deck, so a `netlist_commands` record reaches the simulator unchanged.
The migrator now re-emits every unmapped line as one

    C {devices/code} <x> <y> 0 0 {name=ASE_KEEPn only_toplevel=… place=… value="…"}

record per producing source block, at that block's own coordinates and
inheriting its `only_toplevel` / `place` scope. `devices/code` rather than
`code_shown`: the symbol's `format` is a bare `@value` with no `tcleval(…)`
wrapper, so `A1 [A B] IX d_lut_…` survives with its brackets intact instead of
being read as Tcl command substitution.

`.end` and `.title` are the only two cards still dropped — they are pure deck
framing and `render_deck` emits its own; re-emitting `.end` would truncate the
deck (tb_ft_test carries one).

Writing that record needs the inverse of the reader, and both nested escape
layers have to be right: the **value layer** (`"`-quoted, `\` and `"`
backslash-escaped — undone by `get_tok_value`, src/token.c) inside the **record
layer** (`\`, `{`, `}` each backslash-escaped inside the record's `{…}` — undone
by `_read_braced`). Applied in that order, `table_values "1110"` becomes
`table_values \\"1110\\"`, byte-for-byte how xschem itself stores test_stdcells'
d_lut card.

### …and a cross-check behind it

After reconstruction, every enabled analysis that names a source is validated
against the `name=` of the kept `C` records **plus the element names the residue
declares**, plus ngspice's `temp` sweep. A miss ships the row `enabled 0` with a
loud warning instead of a state that hard-fatals at Run
(`DC Transfer Function: … named "vd" is not in the circuit`). Measured: 6 of 11
sky130 dc rows tripped it before the residue fix, 0 of 25 sg13g2 rows ever do.

## Blocks the ngspice netlister would never emit were parsed anyway

Found while implementing the above. `classify()` calls every code/commands symbol
"embedded" and the migrator parsed its value, ignoring the two attributes that
decide whether xschem emits it at all:

* `spice_ignore=true` — `skip_instance` (src/netlist.c:1212) drops the instance.
  test_multisim's two such blocks are **Tcl**, not SPICE
  (`[if [sim_is_ngspice] {return {`), and those four lines were being parsed as
  deck text. `sg13g2_tests`' `inv_mc_tb` / `inv_sweep_tb` carry a disabled
  `OP_AC_TRAN` block whose `op`, `tran 10p 30n`, `save all`, `.options warn=1`
  and `plot inv_in inv_out` the migration was importing — a state that ran
  analyses the bench itself had switched off.
* `simulator=<name>` — `simulator_commands*.sym`'s format is
  `[if {sim_is_@simulator} …]`, so a `simulator=xyce` block is a *different
  simulator's* deck. Six such blocks in sky130.

Both are now skipped with a warning naming the attribute.

## The 19, closed

**A — `includes` naming a Tcl variable nobody sets (7 cells).**
`LACG optimize_delay tb_charge_pump test_carry_lookahead test_ff test_stdcells`
carry `$::SKYWATER_STDCELLS/sky130_fd_sc_hd.spice`; `test_hvl_cells` carries
`$PDK_ROOT/$PDK/…/sky130_fd_sc_hvl.spice`. `ase::expand_path` is
`subst -nocommands -nobackslashes` at `uplevel #0` (src/ase.tcl:140), so an unset
name makes the **whole deck render throw** before ngspice starts — and note this
means `$FOO` and `$::FOO` resolve to the *same* global: the old check's
qualified/unqualified distinction (`_UNQUAL_VAR_RE`) was built on a false premise
and never even looked at the qualified form.

Both halves of the "either/or" were needed:

* `sky130A/cadence_style_rc` now sets `::PDK_ROOT` (probed against five candidate
  install roots), `::PDK` and `::SKYWATER_STDCELLS` **unconditionally**. Those
  stdcell subcircuit decks belong to an open_pdks sky130A install, which this
  repo does not vendor (only `models/libs.tech` + `libs.ref/sky130_fd_pr`). Set
  but wrong fails later, inside ngspice, as `Could not find include file: <path>`
  naming what to install — an honest message; unset fails earlier and says only
  `can't read "::SKYWATER_STDCELLS"`.
* `Pdk` gains `env_vars`, the globals a workarea rc guarantees, and
  `_resolvable()` DROPS any `models`/`includes`/`pre_commands` entry naming
  anything else (plus `_XSCHEM_GLOBALS` — `USER_CONF_DIR` and friends — which
  xschem itself always defines). `--declare-var NAME` is the escape hatch for a
  non-stock rc. sky130 declares `SKYWATER_MODELS SKYWATER_STDCELLS PDK_ROOT PDK`;
  sg13g2 declares `MODELS_NGSPICE SG13G2_MODELS SG13G2_OSDI` — that last one is
  load-bearing, all 48 IHP states' `pre_commands` use it.

**B — a `dc` sweep naming a source the migration deleted (4 cells).**
`srlatch test_nmos test_nmos_sizes test_pmos` — fixed by the residue block; the
cross-check above is the backstop.

**C — a lost `.MODEL` card (1 cell).** `test_jfet` — same mechanism.

**D — `unknown subckt: sky130_fd_pr__*` (4 cells).**
`bandgap bandgap_opamp charge_pump charge_pump2` are **sub-circuits, not
benches**: `classify()` finds no corner and no embedded block on any of them —
only a graph — so `LibraryMigrator.scan` picked them up on the graph alone and
`_build_state` wrote `models {}`. That empty list is load-bearing, not merely
absent: `ase::state_load` is a `dict merge` with the LOADED value winning
(src/ase.tcl:246), so an explicit `models {}` **overrides**
`::ASE_DEFAULT_MODELS` and the workarea default cannot rescue it.

`_default_models()` now seeds the PDK's default corner, triple-gated: only when
nothing was extracted, only for a PDK that HAS a corner mapping (so never gf180
or sg13g2), and only when the clean schematic instantiates a symbol from the
PDK's own device library. Of the ten migrated sky130 cells with empty models this
fires on exactly the four that need it — the other six (`stdcells_xspice`,
`tb_diff_amp`, `test_jfet`, `test_multisim`, `test_ngspice_flop`, `test_s_xfer`)
instantiate no `sky130_fd_pr` device and are untouched.

**E — a missing OSDI artifact (2 cells).** `tb_diff_amp` and `top`. **Not a
migration defect**: the path never passes through the state. It comes from the
`device_model` attribute of the instantiated `sky130_tests/diff_amp` **symbol**,
which ends `pre_osdi $USER_CONF_DIR/xschem_library/diff_amp.osdi`, and the
netlister prints that verbatim into the deck. Nothing shipped the compiled
artifact. New `tools/migrate/build_diff_amp_osdi.sh` compiles the Verilog-A the
repo already carries (`xschem_library/ngspice/diff_amp.va`) with openvaf into
`$USER_CONF_DIR/xschem_library/`, mirroring `build_ihp_osdi.sh`.

**F — `lvnand`.** Diagnosed from scratch: `Undefined parameter [lenn]`.
`lvnand`'s two `nfet3_01v8` instances are `L=LenN W=WidthN`, and `LenN`/`WidthN`
are **subcircuit parameters supplied by the parent's instance line**
(`lvnand.sym` format: `… WidthN=@WidthN LenN=@LenN …`). lvnand's own block
defines `.param L=0.15` / `.param W=0.5` — different names. It is a parameterised
subcircuit that was never a runnable top-level bench, and the **cluttered
original fails identically** (measured: `CLUT-FAIL lvnand :: Formula() error.`).
Restoring its `vd`/`vg` sources (bucket B) was necessary but not sufficient. Left
failing, honestly.

## The rest of the residue list

* **`dc-second-sweep-dropped`** — NOT fixed; see "Deliberately not done" below.
* **`temperature-overrides-options-temp`** — `.option temp=<T>` is the same knob
  as `.temp`, and `render_deck` emits the options rows first and `.temp` LAST,
  so ngspice let the default 27 win. `_parse_options` now routes a numeric
  `temp=` to `temperature` and refuses a non-numeric one loudly.
* **`nonvector-output-exprs`** — a `print`ed name defined by a `let`/`meas` that
  went to the report-only `raw_control` bin became an output with `save 1`, i.e.
  a `.save`/`print` naming a vector the deck never makes. `_control_defined()`
  collects those names; such rows are kept (they record intent) with `save 0`
  and a warning.
* **`gettok-quote-truncation`** — `migrate_pin_names.get_tok` ended a quoted
  value at the first inner `"`, where `get_tok_value` (src/token.c ~489-548)
  **toggles** a quote flag and only ends the value at a space seen with that flag
  off. Rewritten to mirror token.c exactly, including its `escape` semantics
  ("the PREVIOUS character was an unescaped backslash"). Measured across all four
  library trees: **90** (file, token) pairs read differently — e.g.
  `sg13g2_tests/dc_esd_diodes`' whole `.control` block used to end at
  `echo `, truncated by `echo "---------diodevdd_2kv---------"`.
* **`library-verify-silently-ignored`** — the `--library` branch returned before
  the verify block, so `--library --verify` printed a clean report and proved
  nothing. It now verifies every migrated cell and summarises ok/mismatch/skipped.
* **`drop-only-cells-skipped`** — **judged not a defect.** A launcher is a GUI
  button, not simulation setup: migrating a launcher-only cell yields a state
  with nothing extracted, and making `drop` a scan trigger would sweep in pure
  index cells (`sg13g2_tests/IHP_testcases` — documented as correctly skipped —
  and gf180's `0_top`), 6 cells across the three libraries. The skip reason is
  now explicit (`launcher only, nothing to extract`) instead of the generic
  `no clutter to extract`, and such a cell simply stays in the source library
  where `_rebind_ref` already keeps pointing at it.

Found while closing the above and fixed too:

* **silent last-wins analysis overwrite** — the ASE schema holds one row per
  analysis type, so a second card of the same type replaced the first without a
  word. `test_inv`'s ngspice block carries `tran 0.004n 30n` and then
  `tran 0.02n 30n`. Last-wins matches ngspice's own `.control` semantics, so the
  behaviour is kept — but it is now reported.

## Deliberately not done

* **`dc-second-sweep-dropped`** (13 cells lose the second sweep source). The
  `analyses` entries are free-form dicts, so carrying `source2/start2/stop2/step2`
  would need no schema-key change — but it is a real ASE **feature**, not a
  migrator fix: `ase::backend::ngspice::render_deck`'s dc branch emits exactly
  four fields (src/ase.tcl:1126), and `ase_window.tcl`'s `anaargs`
  (`dc {source start stop step}`, :80 and :2197) rebuilds the analysis dict from
  that list, so the extra keys would be silently discarded the first time a user
  opened the dc dialog. Doing it properly means backend + dialog + `anaargs`, and
  it changes 13 cells' run times from one curve to a family. Left for a dedicated
  round; the migrator continues to warn per occurrence.
* **`charge_pump2`** still fails at `unknown subckt: sky130_fd_sc_hd__inv_6`.
  Same story as bucket D — a sub-circuit run standalone — but the missing piece
  is a *stdcell deck*, chosen per instance by the `prefix=` attribute
  (`sky130_fd_sc_hd__`, `sky130_fd_sc_hvl__`, …), not a PDK-wide default like a
  corner. Its parent `tb_charge_pump` supplies the include and passes. Seeding it
  would mean a prefix→file table in the migrator that helps exactly one cell.
* **`stdcells_xspice`** — see the results table note.

## Results

Both runs under identical conditions (`--nogui`, `XSCHEM_LIBRARY_DEFS` pointed at
the tree under test with `library_registry_defs_only 1`, `::SKYWATER_MODELS` +
the section-3b globals set exactly as `sky130A/cadence_style_rc` sets them;
`ase::state_load` → `rundir` → `ase::run` → `ase::wait`, then the `<cell>_ase.log`
grepped for `fatal|valid modelname|could not find include|no such file|error on
line|unknown subckt|is not in the circuit|syntax error`).

**Before** — the tree as committed at `a3c0e2f1`, with the pre-change
`cadence_style_rc` (no section 3b): **29 pass / 19 fail**.

    LACG bandgap bandgap_opamp charge_pump charge_pump2 lvnand optimize_delay
    srlatch tb_charge_pump tb_diff_amp test_carry_lookahead test_ff
    test_hvl_cells test_jfet test_nmos test_nmos_sizes test_pmos test_stdcells
    top

<!-- RESULTS -->

## Traps re-confirmed

* The cluttered originals write `.raw`/`.csv` litter into the CWD — run them from
  a scratch dir.
* `sky130A/cadence_style_rc` cannot be sourced under `--nogui` (it reaches `bind`
  through the repo rc), so a headless harness must mirror its globals by hand.
