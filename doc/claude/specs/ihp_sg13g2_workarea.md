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
│   ├── sg13g2_tests/     <cell>/{symbol,schematic}/<cell>.ext   (49)
│   └── sg13g2_tests_ase/ <cell>/{symbol,schematic,ngspice_state1}/  (49)
│                         # the migrated ASE-L testbench library (c69b88de)
├── models/               verbatim copy of libs.tech/ngspice/models (32 files, 436 KB)
├── osdi/                 compiled Verilog-A modules (4 files, ~2 MB)
├── cadence_style_rc      the launch rc (single --script)
├── sg13g2_procs.tcl      DRC + FET/BIP annotate + IHP menu, ported from the PDK
├── run.sh
└── README.md
```

`devices` and the five general libs are NOT copied: `library.defs` registers them
repo-relative against the repo's already-migrated newsym tree
(`DEFINE devices ../../xschem_libs_newsym/devices`, etc.), so the Library Manager lists
**10 libraries**. Repo-relative links are valid while `ihp-sg13g2/` lives inside the repo.

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

The same script also injects the OSDI registration preamble — see
"ngspice: 47 of 49 benches simulate" below for why, and for the gating mistake it hides.

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
- sets `::SG13G2_OSDI` to `ihp-sg13g2/osdi`, which the benches' `pre_osdi` preamble
  expands — without it the Verilog-A devices have no model definitions;
- sets `::ASE_DEFAULT_MODELS` to the typical MOS corners in the portable `$::VAR` form;
- sources `sg13g2_procs.tcl` and wires `sg13g2_menupdk` (see §3 above).

## Validation (2026-08-02)

- Registry: headless `library_list` = exactly the 10 intended libs; the general libs
  resolve outside `ihp-sg13g2/`, the **four** PDK libs inside it (`sg13g2_pr`,
  `sg13g2_stdcells`, `sg13g2_tests`, `sg13g2_tests_ase` — the tenth joined in
  c69b88de and the golden caught up only in the 0689+0690 commit, issue 0690).
- Netlist: all **49** benches netlist with **0** unresolved symbols, and no bare model
  `.lib` and no un-expanded `$::MODELS_NGSPICE` remain in any output.
- GUI: launches, Library Manager opens, IHP menu present with its 4 entries.
- Regression smoke: `tests/headless/test_ihp_sg13g2_libmgr.tcl` (67 checks, registered in
  `run_regression.tcl` hcases). Sabotage-verified twice: drop a DEFINE → 3 FAILED;
  un-prefix one `drc=` call → 1 FAILED.

### ngspice: 47 of 49 benches simulate

SG13G2's MOS devices are `psp103va`, its resistors `r3_cmc` and its varicaps `mosvar` —
all Verilog-A, which ngspice loads as compiled **OSDI** modules. The PDK checkout ships
only the Verilog-A sources (`libs.tech/verilog-a/`), no compiled modules and no `osdi/`
directory, so before these were built 25 of 49 benches netlisted cleanly and then died at
`could not find a valid modelname`.

`tools/migrate/build_ihp_osdi.sh` compiles the four modules into `ihp-sg13g2/osdi/`
(psp103, psp103_nqs, r3_cmc, mosvar; ~2 MB, openvaf-r preferred, openvaf accepted). It
deliberately does not use the PDK's own `openvaf-compile-va.sh`, which writes into
`../ngspice/osdi` inside the read-only PDK tree.

**How the modules get registered.** Three mechanisms were tried against ngspice 46:

| mechanism | result |
|---|---|
| `.osdi <file>` dot-card | `unimplemented dot command '.osdi'` |
| `osdi <file>` in `.control` | accepted, but runs AFTER the deck is parsed — too late |
| `pre_osdi <file>` in `.control` | works; `pre_`-prefixed control commands run before parsing |

So each bench carries a `.control / pre_osdi ×4 / .endc` preamble at the head of its
models block, emitted through `$::SG13G2_OSDI` (set by the rc). Putting this in the
NETLIST rather than in a `.spiceinit` is what makes a bench portable: `.spiceinit` is only
read from the cwd or `$HOME`, and the directory ngspice runs in is the user's
`netlist_dir`, which this workarea does not control.

**The trigger for injecting it is "this block references a model library", not "a path had
to be rewritten."** Gating on the rewrite is the obvious-looking choice and it is wrong:
the 15 benches that already used `$::MODELS_NGSPICE` needed no path fix, so they got no
preamble, and every r3_cmc resistor and mosvar varicap bench among them failed with
*Unable to find definition of model* — a different error from the original one, which is
what made it easy to mistake for an upstream problem. Caught by re-running the full sweep
and noticing 5 of the 7 survivors had zero `pre_osdi` lines.

Measured over all 49 benches with ngspice 46:

| outcome | count |
|---|---|
| simulate clean | **47** |
| model resolution failures | **0** |
| upstream bench quirks | 2 — `IHP_testcases` (the gallery index, not a bench) and `dc_esd_diodes` (a vector-name bug in its own `.control`) |

Physical sanity check: `sg13_lv_nmos` W=1 µm, L=0.45 µm, Vgs=1.2 V, Vds=1.5 V →
**Id ≈ 259 µA**.

The `osdi/*.osdi` files are compiled binaries for this host's architecture. Re-run
`build_ihp_osdi.sh` after changing machine/architecture or after an ngspice upgrade that
bumps the OSDI ABI. The IHP menu's *Add Ngspice models symbol* places a block carrying the
same preamble, so new designs get it too.

The PDK's `.spiceinit` is still deliberately NOT vendored: it hard-codes `$PDK_ROOT/$PDK`
paths, and the netlist-embedded preamble removes the need for it.

## Related

[[sky130_workarea]], [[gf180mcud_workarea]], [[pdk_launcher]],
`doc/claude/code_analysis/library_manager_design.md`.
