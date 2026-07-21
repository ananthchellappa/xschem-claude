# Item 04 — proof-final (P4 of doc/claude/specs/ase_l.md) — BATCH ACCEPTANCE GATE

Implementation prompt, written by the item-04 scout (2026-07-20). All anchors
below re-verified from source this day. Repo:
`/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`. NEVER push.

Read first: doc/claude/ase_l_batch/RUNBOOK.md, doc/claude/specs/ase_l.md,
receipts 01–03 in doc/claude/ase_l_batch/receipts/, and `src/ase.tcl`
(the public API you drive; procs listed under "Corrected anchors").

## Mission

Prove the whole ASE-L arc end-to-end: a new cell
`sky130A/xschem_libs/sky130_tests/test_nfet_final/` whose schematic carries
ONLY the circuit (no corner, no simulator_commands, no netlist_commands-type
instances, no `.control` anywhere), plus an `ngspice_state1` state view that
reproduces **Id ≈ 409.7 µA** through the PUBLIC `ase::` API, headless from the
repo root. This item is the acceptance gate for the batch: if Id mismatches or
the schematic needs any sim clutter to pass, the item FAILS — no workarounds
inside the test.

The scout ran the complete flow as a probe (scratch replica of the exact
deliverables below, real ngspice, `--nogui` from repo root): netlist clean,
`V1 D GND Vds` / `V2 G GND Vgs` emitted, plain ngspice resolves the bare
`.param` names, and `last_result` returned `id 4.096837e-04`
(409.6837 µA, |delta| = 0.0037 < 1.0). The item is achievable exactly as
specced; your job is to land it with tests + sabotages.

## Corrected anchors (re-verified 2026-07-20)

- `src/ase.tcl` public API (items 01–03, stable contracts):
  `ase::state_load` :68, `ase::state_serialize` :89, `ase::state_save` :108,
  `ase::backend_hook` :132, `ase::rundir` :154, `ase::netlist` :174,
  `ase::run` :219, `ase::wait` :288, `ase::last_result` :301,
  `ase::open_state` :445. ngspice backend: `render_deck` :482 (the `.lib`
  emission loop is :490–492 — **this is the one code change you make**, see
  Decision D1), `run_cmd` :538, `log_file` :543, `result_probe` :554.
- `src/library_defs.tcl`: `cellview_resolve` :209, `cellview_path` :235,
  `cell_views` :261 — Tcl-side; invoked as `xschem cell_views <lib> <cell>`
  (test_ase_view.tcl:53 precedent; scout probe confirmed it lists
  `ngspice_state1 schematic` for the planned cell).
- `src/spice_netlist.c:591` — `if( !top_sub && !split_f) fprintf(fd, ".end\n");`
  confirmed: `.end` is emitted last for top `.spice` netlists (basis of the
  strip-then-append deck render and of the "last non-blank line is .end" check).
- `tests/headless/full_audit.sh:69` —
  `nogui_tests=" test_nogui test_sweep_diff test_make_symbol_dialog test_ase_core "`
  → append ` test_ase_final` (keep the surrounding spaces). nogui invocation
  is :125–126 (`--pipe -q --nolog --nogui --script`). Classification:
  `is_pass` default arm :87 needs `RESULT: ALL PASS` in the output;
  `is_skip` :92 matches only `RESULT: SKIP` / `skipped: no X` — a per-leg
  `SKIPPED: ...` banner (test_ase_core.tcl:217 precedent) does NOT skip the
  whole test.
- `sky130A/cadence_style_rc:31` —
  `set ::SKYWATER_MODELS [file join $_ws models libs.tech combined]` (the GUI
  workarea sets the variable; models file is
  `sky130A/models/libs.tech/combined/sky130.lib.spice`, tracked).
- Item-01's model resolution precedent: `tests/headless/test_ase_core.tcl:33`
  computes `[file join $repo sky130A models libs.tech combined sky130.lib.spice]`
  from the script location and injects it via the state. Stay consistent
  (Decision D1 below).
- `sky130A/xschem_libs/library.defs:10` — `DEFINE sky130_tests sky130_tests`:
  the library is registered at LIB level, so the new cell dir is discovered
  with **zero registry changes**. This file is PRE-BATCH DIRTY — NEVER stage it.
- Starting-point cell (untracked, preflight):
  `sky130A/xschem_libs/sky130_tests/nfet_test_claude/schematic/nfet_test_claude.sch`
  — commit it AS-IS (byte-identical; it is the "before" exhibit). Do not edit.
- `sky130A/README.md` — tracked and CLEAN (scout verified
  `git status --porcelain sky130A/README.md` empty; re-verify yourself before
  staging). Insert the ASE-L section after the `## Design flow` section
  (currently ends at line 60, before `## Validation`).
- Prior tests that must stay green: `tests/headless/test_ase_core.tcl`
  (33/33 — you are touching ase.tcl), `test_ase_view.tcl` (32/32 headless,
  36/36 under DISPLAY), `test_ase_window.tcl` (19 headless legs; 53 under
  DISPLAY + ngspice).

## Scout decisions (resolved micro-decisions)

- **D1 — model path is the VARIABLE form + a small render seam in ase.tcl.**
  The committed state file stores the literal string
  `$::SKYWATER_MODELS/sky130.lib.spice` (the spec's own schema example and the
  workarea corner.sym convention; a literal absolute path would break other
  checkouts, a repo-relative one is cwd-dependent). `render_deck` today emits
  the raw string (ase.tcl:490–492), which ngspice cannot resolve — so extend
  the `.lib` emission to expand the model `file` field with
  `subst -nocommands -nobackslashes` (variables-only; no command execution
  from state files, backslashes kept for Windows paths), wrapped in `catch`
  and rethrown as a clean `ase: cannot expand model path '<raw>': <err>`
  error. A small `proc ase::expand_path {p}` helper used from the ngspice
  `render_deck` is the recommended shape (no ngspice literal in it, so the
  backend-seam invariant holds). Item-01's golden deck D1 uses
  `/models/sky130.lib.spice` (no `$`, no `[`) → unchanged by subst →
  test_ase_core stays 33/33. Putting the subst in the TEST instead was
  rejected: the committed state view must also work from the GUI Run button
  (rc sets `::SKYWATER_MODELS`), and a test-side expansion would be exactly
  the kind of workaround item 04 forbids.
- **D2 — test sets `::SKYWATER_MODELS` from the repo root**
  (`[file join $repo sky130A models libs.tech combined]`), mirroring what
  cadence_style_rc does and matching item-01's repo-derived model path. This
  is what "works headless from repo root" means here.
- **D3 — the headless test registers libraries via its own scratch
  `library.defs`** (item-01/02 idiom): `DEFINE sky130_tests
  <repo>/sky130A/xschem_libs/sky130_tests`, `DEFINE sky130_fd_pr
  <repo>/sky130A/xschem_libs/sky130_fd_pr`, `DEFINE devices
  <repo>/xschem_libs_newsym/devices`; then `set ::XSCHEM_LIBRARY_DEFS <file>`,
  `set ::library_registry_defs_only 1`, `set ::XSCHEM_LIBRARY_PATH {}`.
  Never touches the pre-batch-dirty workarea library.defs, and — unlike the
  scratch-cell tests of items 01–03 — points at the REAL committed cell.
- **D4 — audit registration**: add `test_ase_final` to full_audit.sh
  `nogui_tests` (line 69). Without it the audit runs the test in GUI mode and
  `ase::netlist`'s context guard (arm (c), ase.tcl:196-199) errors by design.
  `tests/run_regression.tcl` is pre-batch dirty → NOT touched (full_audit
  auto-discovers).
- **D5 — symbolic sources verified**: `devices/vsource` with `value=Vds` /
  `value=Vgs` netlists as `V1 D GND Vds` / `V2 G GND Vgs`, and plain ngspice
  resolves bare `.param` names in that position (scout ran it: Id exactly
  `4.096837e-04` with `.param Vgs=1.8` / `.param Vds=1.0`). Note the swap vs
  nfet_test_claude: there V1(drain)=1, V2(gate)=1.8; here V1=Vds(=1.0),
  V2=Vgs(=1.8) — same operating point.
- **D6 — the state file is committed in `ase::state_save` canonical bytes**
  (exact content below, trailing newline included), so the round-trip check
  can assert byte-identity. Generate it via `ase::state_save` or Write the
  bytes verbatim — either way the F3 check will catch any drift.
- **D7 — the test overrides `rundir`** on the loaded state (dict set into its
  scratch dir) so the run is hermetic instead of writing into the user's
  `$netlist_dir` default. This is run-location config through the public state
  schema, not sim clutter; the committed file keeps `rundir {}` (GUI default).

## Deliverables

### 1. `sky130A/xschem_libs/sky130_tests/test_nfet_final/schematic/test_nfet_final.sch`

Exactly this content (nfet_test_claude geometry minus the corner +
simulator_commands_shown instances, sources made symbolic; trailing newline):

```
v {xschem version=3.4.7RC file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 420 -330 600 -330 {}
N 380 -300 380 -330 {}
N 380 -330 250 -330 {}
N 250 -270 600 -270 {}
N 420 -300 420 -270 {}
C {sky130_fd_pr/nfet_01v8} 400 -300 0 0 {name=M1 W=1 L=0.15 nf=1}
C {devices/vsource} 600 -300 0 0 {name=V1 value=Vds}
C {devices/vsource} 250 -300 0 0 {name=V2 value=Vgs}
C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}
C {devices/lab_wire} 500 -330 0 0 {name=lD lab=D}
C {devices/lab_wire} 300 -330 0 0 {name=lG lab=G}
```

### 2. `sky130A/xschem_libs/sky130_tests/test_nfet_final/ngspice_state1/test_nfet_final.state`

Exactly these canonical `ase::state_save` bytes (scout-generated; trailing
newline after the `includes {}` line):

```
version 1
simulator ngspice
design {lib sky130_tests cell test_nfet_final view schematic}
rundir {}
models {{file $::SKYWATER_MODELS/sky130.lib.spice section tt}}
variables {{name Vgs value 1.8} {name Vds value 1.0}}
analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}
outputs {{name id expr -i(v1) save 1 plot 0}}
options {{name savecurrents value 1}}
includes {}
```

### 3. `src/ase.tcl` — model-path expansion (Decision D1)

Variables-only `subst` of each model's `file` field at the `.lib` emission in
`ase::backend::ngspice::render_deck` (:490–492), clean `ase:` error on
expansion failure. Keep the file's header comment honest if you add a helper.
No other ase.tcl changes. No Tk. TIP-278 discipline.

### 4. `tests/headless/test_ase_final.tcl` — end-to-end proof (checks below)

Model on test_ase_core.tcl: `check`/`check_true` procs, cwd-independent paths
from `[info script]`, scratch dir `_ase_final_[pid]` under `[pwd]`, cleanup
with `file delete -force`, final banner `RESULT: ALL PASS (N checks)` /
`RESULT: <n> FAILED`, exit code 0/1. True headless (no Tk anywhere). Drive the
PUBLIC ase API only: `ase::state_load` → `xschem cell_views` →
`ase::netlist` → `ase::backend_hook ngspice render_deck` → `ase::run` →
`ase::wait` → `ase::last_result`.

### 5. `tests/headless/full_audit.sh` — `test_ase_final` added to `nogui_tests` (:69)

### 6. `sky130A/README.md` — "ASE-L" section

Insert after the `## Design flow` section (before `## Validation`). Suggested
text (adapt freely, keep the substance):

> ## ASE-L (Analog Simulation Environment)
>
> `sky130_tests/test_nfet_final` is the ASE-L reference cell: its schematic
> carries **only the circuit** (`nfet_01v8` M1, Vds/Vgs sources, gnd, net
> labels — no `corner`, no `simulator_commands_shown`), while models/corner
> (`tt`), `.param` design variables (Vgs 1.8, Vds 1.0), analyses (`op`),
> options and saved outputs live in its `ngspice_state1/test_nfet_final.state`
> view (spec: `doc/claude/specs/ase_l.md`). Double-click the `ngspice_state1`
> view in the Library Manager to open the ASE-L session window
> (Session > Design Window raises the schematic; Simulation > Netlist / Run
> with a live log). The model path resolves through `$::SKYWATER_MODELS`
> (set by `cadence_style_rc`). End-to-end proof:
> `tests/headless/test_ase_final.tcl` reproduces **Id ≈ 409.7 µA** through the
> public `ase::` API, headless from the repo root. `nfet_test_claude` is the
> pre-ASE "before" exhibit — the same circuit with in-schematic sim clutter.

### 7. `sky130A/xschem_libs/sky130_tests/nfet_test_claude/schematic/nfet_test_claude.sch`

Committed byte-identical as it sits in the tree today (untracked preflight
cell; the "before" exhibit). Do not modify it.

## Test — named checks (tests/headless/test_ase_final.tcl)

Setup: scratch defs per D3; `set ::SKYWATER_MODELS` per D2; load the COMMITTED
state file; `dict set` rundir → scratch (D7).

- **F1** state file loads via `ase::state_load`; `version` == 1, `simulator`
  == ngspice.
- **F2** `design` == `{lib sky130_tests cell test_nfet_final view schematic}`.
- **F3** round-trip byte-stability: `ase::state_save` of the loaded dict to a
  scratch file → binary-compare EQUAL to the committed state file (proves the
  committed file is canonical).
- **F4** `xschem cell_views sky130_tests test_nfet_final` contains
  `ngspice_state1` (and `schematic`).
- **F5** de-clutter at source: the committed `.sch` file contains no
  `simulator_commands`, no `corner`, no `.control` substrings.
- **F6** `ase::netlist` returns `<rundir>/test_nfet_final.spice`, file exists;
  netlist contains `XM1`, a `V1 D GND Vds` line and a `V2 G GND Vgs` line
  (order of D/GND per netlister; assert with a regexp tolerant of node order
  if needed — scout's probe got exactly these strings).
- **F7** THE DE-CLUTTER PROOF, on the netlist artifact BEFORE any deck append:
  no `^\.control` line, no `^\.lib ` line, last non-blank line is `.end`.
- **F8** deck render (public hook on the loaded state + netlist text):
  contains `.lib <repo>/sky130A/models/libs.tech/combined/sky130.lib.spice tt`
  (the EXPANDED absolute path) and does NOT contain `$::SKYWATER_MODELS`;
  contains `.param Vgs=1.8`, `.param Vds=1.0`, `.options savecurrents`,
  `.save -i(v1)`, and an `op` line inside the `.control` block.
- **F9** (guarded: `auto_execok ngspice`, else print
  `SKIPPED: F9/F10 run leg (ngspice not found)` — never `RESULT: SKIP`)
  `ase::run` + `ase::wait` → exit code 0; `test_nfet_final_ase.spice` and
  `test_nfet_final_ase.log` written; log contains `No. of Data Rows`.
- **F10** THE ACCEPTANCE GATE (same guard as F9): `ase::last_result` has key
  `id` and `abs($id*1e6 - 409.68) < 1.0` (expected exact value
  `4.096837e-04`). On this machine ngspice IS installed — F9/F10 must
  actually RUN in your verification, not skip; a skipped gate is not
  acceptance.

## Sabotage plan (≥2; run AFTER the single commit, per item-02/03 precedent)

For each: apply, confirm with `git diff` the file holds NOTHING but the
sabotage, run the test, record the exact fail set, revert via targeted
`git checkout -- <file>`, clean re-run green. Record actual fail sets in your
report; explain any delta from the declared targets.

- **S1** — committed state file: `variables` value `1.8` → `0.9`
  (canonical form preserved). Declared targets: **F8** (`.param Vgs=1.8`
  absent) + **F10** (Id gate; wrong bias point). F3 must STAY green
  (round-trip is content-agnostic) — that staying green is part of the proof.
- **S2** — `src/ase.tcl`: neuter the D1 expansion (emit the raw model path).
  Declared targets: **F8** (expanded-path + no-`$::` checks) + **F9/F10**
  (ngspice cannot open `$::SKYWATER_MODELS/...`). Also re-run
  `test_ase_core` under the sabotage: must stay 33/33 (proves no collateral
  and that F8 specifically exercises the NEW seam).
- **S3** — committed `.sch`: re-append the nfet_test_claude
  `simulator_commands_shown` instance line. Declared targets: **F5** + **F7**
  (netlist gains `.control`). F9/F10 may additionally fail (double `.control`
  in the deck) — record what actually happens and attribute it.

## Verification (before reporting)

1. `cd src && make` — expect "Nothing to be done" (pure Tcl + data item).
2. Run the new test from the REPO ROOT:
   `./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_final.tcl`
   → `RESULT: ALL PASS`, with F9/F10 RUN (not skipped).
3. Prior ASE tests: `test_ase_core` 33/33 (--nogui), `test_ase_view` (32
   headless; 36 under DISPLAY if available), `test_ase_window` (19 headless;
   GUI legs under DISPLAY if available).
4. Full `tests/headless/full_audit.sh` — fail set must be a subset of the
   baseline below; `test_ase_final` PASS inside the audit (this also proves
   the nogui_tests registration). Re-run any transient WSLg flake in
   isolation before calling it new.
5. Sabotage table per the plan above.

Baseline full_audit fail list (pre-existing, tolerated, NOT yours to fix):
FAIL: test_altf5_ciw, test_cadence_descend_newwin_ro, test_cadence_drag,
test_cadence_window_hop_log, test_ciw, test_crossview_paste,
test_fluid_editing, test_hi_descend, test_launch_context,
test_lib_manager_gui, test_lib_sweep, test_palette, test_phase3_mints,
test_pin_type_edit, test_reopen_readonly, test_select_at,
test_selflog_output, test_verb_noun_copy_move, test_wire_split,
test_wire_vertex_grab. TIMEOUT: test_key_graph_context. SKIPs are fine.

## Commit — ONE commit, stage EXACTLY these 7 paths

```
sky130A/xschem_libs/sky130_tests/nfet_test_claude/schematic/nfet_test_claude.sch
sky130A/xschem_libs/sky130_tests/test_nfet_final/schematic/test_nfet_final.sch
sky130A/xschem_libs/sky130_tests/test_nfet_final/ngspice_state1/test_nfet_final.state
sky130A/README.md
src/ase.tcl
tests/headless/test_ase_final.tcl
tests/headless/full_audit.sh
```

Before staging README.md, verify `git status --porcelain sky130A/README.md`
shows it clean-tracked (it is NOT in the pre-batch dirty list; scout
confirmed). Suggested message:
`feat(ase): de-clutter proof — sky130_tests/test_nfet_final + ngspice_state1 view, end-to-end Id test`
with the repo's Co-Authored-By trailer
(`Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`). NEVER push.

NEVER stage (pre-batch dirty tracked files):
`doc/claude/specs/sky130_workarea.md`, `sky130A/xschem_libs/library.defs`,
`src/ciw.tcl`, `tests/headless/test_sky130a_libmgr.tcl`,
`tests/run_regression.tcl`,
`xschem_libs_newsym/SANDBOX/solar_ctl/symbol/solar_ctl.sym`,
`xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch`.
Also never stage generated files (`src/Makefile`, `src/xschem_subcommands.txt`)
or any `_nhangle_*`/`_allm_*`/scratch junk.

## Failure rule (acceptance gate)

If Id misses the |Id·1e6 − 409.68| < 1.0 window, or the schematic cannot pass
without sim clutter, or the committed state view cannot drive the run without
test-side patching beyond D7's rundir override — the item FAILS. Report it;
do not work around it.

## RUNBOOK policy block (verbatim from doc/claude/ase_l_batch/RUNBOOK.md)

```
## Policies (non-negotiable)

- Git: NEVER `git reset --hard`, NEVER `git add -A`/`commit -a`, NEVER push.
  Stage explicit file lists only. Pre-existing dirty tracked files at batch
  start (listed in PLAN.md preflight) must NEVER be staged; in particular
  `tests/run_regression.tcl` is dirty pre-batch → this batch does NOT register
  tests there; tests/headless/full_audit.sh auto-discovers `test_*.tcl`.
- A green suite ≠ the changed code ran: sabotage-verify (each sabotage fails
  EXACTLY its target check, revert via targeted `git checkout -- <file>` only
  after `git diff` confirms the file holds nothing but the sabotage, clean
  re-run green).
- Headless traps: each test its own process; repo-root cwd for relative paths;
  script error idles rather than hangs; `--nogui --pipe -q --nolog --script`.
- GUI tests: DISPLAY-guarded self-SKIP (`winfo exists .` guard pattern from
  full_audit.sh); replay WHOLE Tk event sequences in the shipping rc profile.
- User-facing messages via `ciw_echo`, not puts/statusbar.
- Tcl: TIP-278 (`variable`/absolute names in namespaces); C (if any): C89,
  `_ALLOC_ID_` placeholders. Windows: guard unix-only subprocess paths.
- Do not touch `_nhangle_*`/`_allm_*`/junk dirs or anything outside declared
  scope. Do not edit generated files (Makefile from Makefile.in — tmpasm, no
  `$@`/`$<`, `@` is the delimiter).
- Commit messages: normal prose, Co-Authored-By trailer per repo convention.
```
