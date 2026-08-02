# IHP SG13G2 migrated workarea (Cadence-style, in-repo)

Status: EXECUTED 2026-08-02. Self-contained IHP SG13G2 (130 nm SiGe BiCMOS) design
workarea at repo-root `ihp-sg13g2/`, built with the repo's flat→lib/cell/view migration
tooling. Third sibling of `sky130A/` and `gf180mcuD/`; ships with the repo.
Launch: `./ihp-sg13g2/run.sh [cell.sch]`, `src/xschem --script ihp-sg13g2/cadence_style_rc`,
or pick it in the GUI launcher (`./pdk_launcher.sh`, see `pdk_launcher.md`).

## Goal

Capture the IHP-Open-PDK xschem tree
(`/home/qflow/dev/IHP-Open-PDK/ihp-sg13g2/libs.tech`, treated as a read-only SYSTEM dir)
into an in-repo workarea, migrated to the Cadence-ish lib/cell/view format, so the
libraries appear in the Library Manager and schematics can be designed + netlisted +
simulated with a Cadence-compatible UX. Same pattern as `sky130A/` and `gf180mcuD/`.

## Shape relative to the siblings

Between the two: the tree is small like gf180 (3.4 MB) but the PDK ships real helper
procs like sky130 (DRC checks, FET/HBT operating-point save + annotate, a menu).

- **Three libraries migrated**: `sg13g2_pr` (41 primitive cells), `sg13g2_stdcells`
  (80), `sg13g2_tests` (49 benches). `sg13g2_tests_xyce` is deliberately NOT migrated —
  it is a cell-for-cell duplicate of `sg13g2_tests` retargeted at Xyce, and this
  workarea is ngspice-only; migrating it would put two cells of each name in the
  registry for no gain.
- **References were already lib-qualified** (`sg13g2_pr/nmos.sym`), unlike gf180's
  `symbols/X.sym`, so no staging pre-normalization was needed — but bare device refs
  (`lab_pin.sym`, `launcher.sym`) still had to resolve, which is why `devices` is passed
  FIRST and index-only.
- **Models are self-contained** (444 KB, `libs.tech/ngspice/models`): every `.lib`
  includes its siblings by bare name, so they vendor verbatim with no
  transitive-closure trim (sky130's corners reach up into `libs.ref` and needed one).

## Layout (`ihp-sg13g2/`)

```
ihp-sg13g2/
├── xschem_libs/
│   ├── library.defs                 # the registry (cds.lib analog)
│   ├── sg13g2_pr/        <cell>/{symbol,schematic}/<cell>.ext   (41)
│   ├── sg13g2_stdcells/  <cell>/{symbol,schematic}/<cell>.ext   (80)
│   └── sg13g2_tests/     <cell>/{symbol,schematic}/<cell>.ext   (49)
├── models/               verbatim copy of libs.tech/ngspice/models (32 files, 436 KB)
├── cadence_style_rc      the launch rc (single --script)
├── sg13g2_procs.tcl      DRC + FET/BIP annotate + IHP menu, ported from the PDK
├── run.sh
└── README.md
```

`devices` and the five general libs are NOT copied: `library.defs` registers them
repo-relative against the repo's already-migrated newsym tree
(`DEFINE devices ../../xschem_libs_newsym/devices`, etc.), so the Library Manager lists
**9 libraries**. Repo-relative links are valid while `ihp-sg13g2/` lives inside the repo.

## Regeneration

`tools/migrate/build_ihp_sg13g2.sh [PDK_SRC]` replays the whole recipe. It rebuilds
`xschem_libs/` and `models/` and never touches the hand-written files
(`cadence_style_rc`, `sg13g2_procs.tcl`, `run.sh`, `README.md`).

Three steps in it are load-bearing and were each driven by a concrete failure:

### 1. Proc namespacing

The PDK defines bare `fet_drc`, `res_drc`, `mim_drc`, `hbt_drc`, `diode_drc`,
`svaricap_drc`, `save_params`, `display_fet_params`, `display_bip_params` straight into
the global interpreter, and its symbols call them by those names
(`drc="fet_drc @name ..."`, `tcleval([display_fet_params @ref])`, `[save_params]`).
Those names are far too generic for a workarea where the sky130 and gf180 procs may also
be loaded. The build renames the CALL SITES in the staged sources to `sg13g2_*` and
`sg13g2_procs.tcl` defines the matching prefixed names. **The two halves must be renamed
together** — a bare `drc="fet_drc` would silently disable every DRC check, since only the
prefixed name is ever defined. `test_ihp_sg13g2_libmgr.tcl` asserts no bare `*_drc` call
survives.

### 2. Model-path normalization (`tools/migrate/ihp_model_paths.py`)

27 of the 42 model-bearing benches referenced the corner libraries by BARE filename
(`.lib cornerMOSlv.lib mos_tt`). That only resolves because the PDK ships a `.spiceinit`
adding `$PDK_ROOT/$PDK/libs.tech/ngspice/models` to ngspice's `sourcepath` — i.e. it
depends on `PDK_ROOT`/`PDK` being exported. An in-repo workarea has no such guarantee, so
those benches would netlist cleanly and then fail to simulate. The build rewrites them to
`$::MODELS_NGSPICE/<file>`, the portable form the other 15 already used; the variable is
expanded at netlist time by the owning symbol's `tcleval` format, so no absolute path is
ever written into a `.sch`.

Two traps inside that rewrite:

- Only names that exist in `models/` are rewritten. Benches also carry
  `.include <cell>.save` lines which are **netlist_dir-relative and must stay bare**; a
  blanket regex would break them.
- The rewrite only pays off if the owning symbol's value is `tcleval`'d with `$`
  substitution live. `devices/code_shown`'s default format is a plain `@value` (no
  tcleval), and `devices/simulator_commands_shown` DOES tcleval but emits the payload as
  `return {@value}` — inside Tcl braces, where `$` is not substituted, so the variable
  would reach the netlist as literal text. Both cases get an instance-level
  `format="tcleval( @value )"`. For simulator_commands_shown that drops its
  per-simulator gate, which is acceptable here (ngspice-only workarea, and every affected
  instance is already `simulator=ngspice`).

### 3. The menu hook (applies to ALL THREE workareas)

`user_startup_commands` alone does not work for an rc loaded with `--script`: xinit.c
runs `eval_user_startup_commands` (xinit.c:3789) **before** it sources the `--script`
file (xinit.c:3793). Appending to that variable in the rc therefore only affects windows
created LATER — the first window came up with no PDK menu at all.

This was a **pre-existing bug in sky130A and gf180mcuD too**, found while probing the IHP
menu and confirmed by probing sky130A (`.menubar index SKY130` → `bad menu entry index`).
All three rcs now also call their menu builder directly under `after idle`, and all three
`*_menupdk` procs got an idempotence guard (`if {[winfo exists $topwin.menubar.<x>]}
{return}`) because the later hook still fires for the same window.

Verified after the fix, by querying the live menubar: SKY130 at index 12 (3 entries),
GF180MCU at 12 (2), IHP at 12 (4) — each inserted before `Netlist` as intended.

## The launch rc (`ihp-sg13g2/cadence_style_rc`)

- sources the repo `src/cadence_style_rc` (Cadence UX, keybindings, find_helper
  Ctrl+Shift+G, instance_update Ctrl+Shift+I), then OVERRIDES the registry to this
  workarea (`XSCHEM_LIBRARY_DEFS`, `library_registry_defs_only 1`,
  `XSCHEM_LIBRARY_PATH {}`, `library_default_layout nested`, `launch_library_manager 1`);
- sets `::MODELS_NGSPICE` — **this is what makes a bench simulate** (27 references) — and
  `::SG13G2_MODELS` as the PDK's own alias for the same path, so a schematic written
  against either name resolves;
- sets `::ASE_DEFAULT_MODELS` to the typical MOS corners in the portable `$::VAR` form;
- sources `sg13g2_procs.tcl` and wires `sg13g2_menupdk` (see §3 above).

## Validation (2026-08-02)

- Registry: headless `library_list` = exactly the 9 intended libs; the general libs
  resolve outside `ihp-sg13g2/`, the three PDK libs inside it.
- Netlist: all **49** benches netlist with **0** unresolved symbols, and no bare model
  `.lib` and no un-expanded `$::MODELS_NGSPICE` remain in any output.
- GUI: launches, Library Manager opens, IHP menu present with its 4 entries.
- Regression smoke: `tests/headless/test_ihp_sg13g2_libmgr.tcl` (57 checks, registered in
  `run_regression.tcl` hcases). Sabotage-verified twice: drop a DEFINE → 3 FAILED;
  un-prefix one `drc=` call → 1 FAILED.

### ngspice: 22 of 49 benches simulate; the rest need OSDI

**This is a limitation of the PDK checkout, not of the workarea.** SG13G2's MOS models
are `psp103va` / `pspnqs103va` — Verilog-A, loaded by ngspice as compiled **OSDI**
modules. The PDK's `.spiceinit` expects them at
`$PDK_ROOT/$PDK/libs.tech/ngspice/osdi/*.osdi`, but **no `osdi/` directory exists in this
checkout** and no `.osdi` file exists anywhere on this machine; `openvaf` is not
installed either. Only the Verilog-A sources ship (`libs.tech/verilog-a/`, with
`openvaf-compile-va.sh`).

Measured over all 49 benches:

| outcome | count | what |
|---|---|---|
| simulate clean | 22 | HBT, diodes, MiM/parasitic caps, taps, schottky, isolbox |
| blocked on OSDI | 25 | everything with a MOS, varicap, or r3_cmc resistor |
| other | 2 | `IHP_testcases` (the gallery index, not a bench) and `dc_esd_diodes` (a vector-name bug in the bench's own `.control` block) — both upstream quirks |

To unlock the remaining 25: build the OSDI modules with `openvaf` from
`libs.tech/verilog-a/`, then load them (an `osdi <file>` line in the ngspice `.spiceinit`
used for the run). Nothing in this workarea needs to change.

The PDK's `.spiceinit` is deliberately NOT vendored: it hard-codes `$PDK_ROOT/$PDK` paths
and loads those non-existent OSDI files. Step 2 above removes the need for it.

## Related

[[sky130_workarea]], [[gf180mcud_workarea]], [[pdk_launcher]],
`doc/claude/code_analysis/library_manager_design.md`.
