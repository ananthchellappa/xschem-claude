# Item 01 — ase-core (P1 of doc/claude/specs/ase_l.md)

You are the IMPLEMENTER. Execute this prompt end-to-end: code, tests,
sabotage-verify, ONE commit with the explicit file list at the bottom.
Repo: /home/qflow/dev/xschem/claude_1/xschem, branch fluid-editing. Work from
repo root. Do NOT write any report/summary .md files — your receipt is the
commit + your final text output.

## Scope

New pure-Tcl file `src/ase.tcl` (namespace `ase::`): state-file I/O, backend
registry with an `ngspice` entry, deck rendering, headless-safe netlist +
batch simulation run via the `execute` infra, result parsing. Plus its
headless test `tests/headless/test_ase_core.tcl`. NO Tk calls anywhere in
these paths (must run under `--nogui`). No C changes. Items 02/03/04 build on
this — keep proc names exactly as specified (they are contracts).

## RUNBOOK policies (verbatim, non-negotiable)

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

Pre-existing dirty tracked files (NEVER stage): doc/claude/specs/sky130_workarea.md,
sky130A/xschem_libs/library.defs, src/ciw.tcl, tests/headless/test_sky130a_libmgr.tcl,
tests/run_regression.tcl, xschem_libs_newsym/SANDBOX/solar_ctl/symbol/solar_ctl.sym,
xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch.
`sky130A/xschem_libs/sky130_tests/nfet_test_claude/` is UNTRACKED and belongs
to item 04 — do not add it, do not depend on it (embed the circuit, see below).

Baseline full_audit fails (pre-existing, tolerated, compare LIST EQUALITY —
any NEW fail is yours): test_altf5_ciw, test_cadence_descend_newwin_ro,
test_cadence_drag, test_cadence_window_hop_log, test_ciw, test_crossview_paste,
test_fluid_editing, test_hi_descend, test_launch_context, test_lib_manager_gui,
test_lib_sweep, test_palette, test_phase3_mints, test_pin_type_edit,
test_reopen_readonly, test_select_at, test_selflog_output,
test_verb_noun_copy_move, test_wire_split, test_wire_vertex_grab;
TIMEOUT: test_key_graph_context. SKIPs are fine.

## Verified anchors (re-checked from source 2026-07-20 by scout)

- `spice_netlist.c:591` — `if( !top_sub && !split_f) fprintf(fd, ".end\n");`
  CONFIRMED: `.end` is the last line of a top-level .spice netlist.
- `src/xschem.tcl:352` proc `execute` (pipe open, `execute(data,$id)` init,
  `execute(callback)` → `execute(callback,$id)` copy, fileevent register).
  `execute_fileevent` :242 (appends 1024-byte reads to `execute(data,$id)`;
  on EOF sets `execute(exitcode,$id)`, copies `data/exitcode/cmd/error/status`
  to `*,last`, runs `execute(callback,$id)` BEFORE unsetting
  `pipe/data/status/cmd/win_path` for the id; `execute(exitcode,$id)` is NOT
  unset and survives). `execute_wait` :328 (starts + `vwait execute(pipe,$id)`
  — vwait fires on the unset). `viewdata` :11680 is a Tk toplevel and is
  called on EOF only when the status string contains `1` → ase must pass
  status `0`. `simulate` :4011 is the callback + `cd $netlist_dir` precedent.
  `set_sim_defaults` :2899; batch template `sim(spice,2,cmd)`
  `{ngspice -b -r "$n.raw" "$N"}` at ≈:2946.
- `src/library_defs.tcl` — `library_resolve` :199, `cellview_resolve` :209,
  `cellview_path` :235, `library_cells` :243, `cell_views` :261. C dispatch
  `xschem cellview_path` at `src/scheduler.c:2256` (routes to the Tcl proc).
- `src/scheduler.c:7152` — `xschem netlist [flags] [fname]`: if fname has path
  components it netlists there (set_netlist_dir(1,path)) and RESTORES the
  previous netlist dir afterwards; `-noalert` suppresses alerts. `:5938` —
  `xschem load` flags (`-gui`, `-noundoreset`, `-nofullzoom`, ...).
- `src/xschem.tcl:8592` proc `set_netlist_dir` — `set_netlist_dir 0` returns
  netlist_dir, defaulting to `$USER_CONF_DIR/simulations` (mkdir), headless
  safe (tk_messageBox gated on `has_x`).
- Load/ship precedent (commit cf9a8675, alt2_toggle_view.tcl): source site
  `src/xschem.tcl:14071` (`source $XSCHEM_SHAREDIR/library_manager.tcl`;
  peers create_instance.tcl :14073, save_as_form.tcl :14075); ship list
  `src/Makefile.in` `put /local/install_shares { ... }` block (lines ~12-24;
  library_manager.tcl on line 21). `src/Makefile` is GENERATED and UNTRACKED
  (`git ls-files` confirms) — never commit it, never hand-edit; do not run
  ./configure as part of this item (running from the source tree uses
  XSCHEM_SHAREDIR=src directly). Root `CMakeLists.txt` ships NO tcl files —
  no CMake change.
- `src/ciw.tcl:113` proc `ciw_echo` — ciw.tcl is pre-batch DIRTY; do not edit.
- `tests/headless/full_audit.sh` — discovers `ls tests/headless/test_*.tcl`
  (≈:101); default invocation `--pipe -q --nolog --script`; `nogui_tests`
  list at ≈:75 (`test_nogui test_sweep_diff test_make_symbol_dialog`) runs
  with `--nogui`; PASS banner `RESULT: ALL PASS`, skip banner `RESULT: SKIP`.
- Test precedents: `tests/headless/test_cellview_resolve.tcl` (scratch
  library.defs + `set ::XSCHEM_LIBRARY_DEFS`), `test_sky130a_libmgr.tcl`
  (registry-only env: `::library_registry_defs_only 1`,
  `::XSCHEM_LIBRARY_PATH {}`), `test_sweep_diff.tcl` (--nogui discipline).
- Models file (tracked): `sky130A/models/libs.tech/combined/sky130.lib.spice`.

## Scout live-probe results (reproduced 2026-07-20, ngspice 42 at /usr/bin/ngspice)

A clean nfet fixture (nfet_test_claude minus corner + simulator_commands_shown)
placed in a scratch lib/cell/view, registered via a scratch library.defs
(`DEFINE aselib <scratch>/aselib`, `DEFINE sky130_fd_pr
<repo>/sky130A/xschem_libs/sky130_fd_pr`, `DEFINE devices
<repo>/xschem_libs_newsym/devices`) with `::library_registry_defs_only 1`,
`::XSCHEM_LIBRARY_PATH {}`, resolves via `xschem cellview_path
aselib/nfet_clean schematic`, loads and netlists under
`--nogui --pipe -q --nolog --script`. Netlist produced (verbatim):

```
** sch_path: <abs path>/aselib/nfet_clean/schematic/nfet_clean.sch
**.subckt nfet_clean
XM1 D G GND GND sky130_fd_pr__nfet_01v8 L=0.15 W=1 nf=1 ad=0.29 as=0.29 pd=2.58 ps=2.58 nrd=0.29 nrs=0.29 sa=0 sb=0 sd=0 mult=1
V1 D GND 1
V2 G GND 1.8
**.ends
.GLOBAL GND
.end
```

Deck = netlist minus `.end`, then `.lib <models> tt`, `.param Vgs=1.8`,
`.param Vds=1.0`, `.options savecurrents`, `.save -i(v1)`, `.control` {`op`,
`print -i(v1)`} `.endc`, `.end` → `ngspice -b` exits 0 and stdout contains
EXACTLY the line `-i(v1) = 4.096837e-04` (plus `No. of Data Rows : 1`).
Both `.save i(v1)` and `.save -i(v1)` were probed: identical result, exit 0.

## Scout decisions (binding)

1. **Load/ship**: replicate the alt2/create_instance precedent — add `ase.tcl`
   to the Makefile.in install_shares list and an unconditional
   `source $XSCHEM_SHAREDIR/ase.tcl` in xschem.tcl right after the
   `source $XSCHEM_SHAREDIR/save_as_form.tcl` line (:14075), with a comment
   `# ASE-L analog simulation environment core (doc/claude/specs/ase_l.md)`.
   ase.tcl must define procs only at source time (no side effects, no Tk) —
   it is sourced in --nogui too (probe-confirmed the peer files are).
2. **ase::netlist context handling**: explicit guard, NOT save/restore —
   reloading the previous file to "restore" would destroy unsaved edits (the
   real clobber), and no Tcl-visible scratch context can netlist. Rule:
   (a) if `[xschem get schname]` == resolved design path → netlist in place;
   (b) else if `![info exists ::has_x]` (headless) → `xschem load <path>` then
   netlist; (c) else raise a clean Tcl error telling the caller to open the
   design window first (item 03's Design Window flow guarantees (a)).
3. **rundir defaulting**: state `rundir` non-empty → `file normalize` + mkdir
   if missing; empty → `[set_netlist_dir 0]` (xschem.tcl:8592 — defaults to
   `$USER_CONF_DIR/simulations`, headless-safe). Expose as `ase::rundir
   <state>`.
4. **Log capture**: run ngspice WITHOUT `-o` (stdout must flow into
   `execute(data,$id)`); backend run_cmd appends `2>@1` (Tcl pipeline syntax,
   cross-platform) so warnings land in the log; call `execute` with status
   `0` (a `1` status triggers `viewdata` = Tk toplevel on EOF — forbidden
   headless); flush `execute(data,last)` to `<rundir>/<cell>_ase.log` inside
   the `execute(callback)` — `data,last`/`exitcode,last` are written
   immediately before the callback in the same event dispatch (no event-loop
   reentry between), so reading them there is race-free.
5. **`.save` renders the output expr literally** (`.save -i(v1)`): probed
   working; no minus-stripping magic.
6. **`.control` content**: enabled analyses in fixed order op, dc, ac, tran;
   then one `print <expr>` per output with `save 1`; NO `write` line in v1
   (raw-file plotting is P5-deferred and a relative `write` path would land in
   the process cwd, not rundir). Result probing is log-based.
7. **options render**: `value` 0 → omit line; 1 → `.options <name>` (flag
   form, matches ngspice `savecurrents` idiom and the spec's `value 1`);
   anything else → `.options <name>=<value>`.
8. **State file format**: one `key value` per line written as
   `puts $f "$k [list $v]"`; canonical key order = schema order (version
   simulator design rundir models variables analyses outputs options
   includes) followed by unknown keys in `lsort` order; loader
   `dict create {*}<file content>` merged OVER defaults via
   `dict merge [ase::state_default] $loaded`. Byte-stability contract:
   for any file produced by state_save, load→save reproduces it byte-for-byte
   (deterministic ordering + `list` quoting gives this for free). Files may
   NOT contain Tcl comments (they would parse as list elements) — the saver
   never writes any; on a malformed (odd-length list) file raise a clean
   error.
9. **Test fixture**: embed the clean schematic text verbatim in the test
   (nfet_test_claude is untracked until item 04 — it must not be a
   dependency); build a scratch lib/cell/view + scratch library.defs exactly
   as the probe did. Model path = repo-relative
   `sky130A/models/libs.tech/combined/sky130.lib.spice` resolved from
   `[info script]`, injected via the STATE FILE (never hardcoded in ase.tcl).
10. **full_audit wiring**: add `test_ase_core` to the `nogui_tests` list in
    tests/headless/full_audit.sh (one word, clean file) so the audit runs it
    with `--nogui` — structurally enforcing the no-Tk constraint.
11. **Analysis arg renders** (beyond op, for schema completeness; only op is
    end-to-end tested): dc → `dc $source $start $stop $step`;
    ac → `ac dec $points $start $stop`; tran → `tran $step $stop`.
12. **`ase::state_default`**: version 1, simulator ngspice, design {},
    rundir {}, models {}, variables {}, analyses `{{type op enabled 1}
    {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}`,
    outputs {}, options {}, includes {}. (`simulator ngspice` in defaults is
    the one permitted ngspice literal outside the backend namespace.)

## Deliverables

### A. `src/ase.tcl` (new)

Namespace `ase::` (TIP-278: `variable` declarations, `::`-qualified globals).
No Tk anywhere. Errors via `return -code error "ase: ..."`. Optional
user-facing notices only as
`if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {ciw_echo ...}`.

State I/O:
- `ase::state_default` → dict per decision 12.
- `ase::state_load <path>` → dict: read file, `dict create {*}$content`
  (clean error on missing file / odd list), `dict merge` over defaults
  (unknown keys PRESERVED).
- `ase::state_save <path> <dict>` → write per decision 8, return the path.

Backend seam:
- `variable backends` dict + `ase::register_backend <name> <hooksdict>` +
  `ase::backend_hook <sim> <hook>` (clean error on unknown simulator/hook).
  Hooks: `render_deck`, `run_cmd`, `log_file`, `result_probe` (proc names).
- `namespace eval ase::backend::ngspice` providing the four procs; register
  `ngspice` at source time. NO ngspice literals outside this namespace except
  the state_default `simulator ngspice`.

ngspice backend:
- `ase::backend::ngspice::render_deck <state> <netlistText>` → deck string:
  strip ONE trailing `.end` line (plus trailing blank lines) if present, keep
  the rest verbatim; append `.lib <file> <section>` per models entry, `.param
  <name>=<value>` per variables entry, options per decision 7, `.save <expr>`
  per save==1 output, the `.control` block per decision 6, final `.end`,
  trailing newline.
- `run_cmd <state> <deckpath>` → arg list `ngspice -b <deckpath> 2>@1`.
- `log_file <state>` → `<rundir>/<cell>_ase.log` (cell from the design dict).
- `result_probe <state> <logtext>` → dict name→value for each output whose
  `<expr> = <float>` line appears (regexp the escaped expr; probe format:
  `-i(v1) = 4.096837e-04`).

Netlist + run:
- `ase::rundir <state>` per decision 3.
- `ase::netlist <state>` → resolve design (`lib`/`cell`/`view` sub-dict; view
  defaults to schematic; error if empty or `xschem cellview_path
  $lib/$cell $view` returns ""), apply the decision-2 guard, then
  `xschem netlist -noalert <rundir>/<cell>.spice`; error if the file wasn't
  produced; return the netlist path. (The netlist artifact itself stays a
  clean circuit netlist — deck additions never touch it.)
- `ase::run <state> ?callback?` → `ase::netlist`, read the netlist text,
  render_deck, write `<rundir>/<cell>_ase.spice`, set `::execute(callback)`
  to an `ase::` completion proc invocation carrying the log path + state +
  user callback, `cd` to rundir around `eval execute 0 <run_cmd args>`
  (simulate-proc precedent, restore cwd), error cleanly if execute returns
  -1; return the execute id. Completion proc: snapshot
  `::execute(data,last)` + `::execute(exitcode,last)`, write the log file,
  run result_probe, store results + exitcode + log path in a namespace
  variable, then eval the user callback (if any) at global level.
- `ase::wait <id>` → if `::execute(pipe,$id)` exists `vwait` it (fires on
  unset, execute_wait precedent); return `::execute(exitcode,$id)`.
- `ase::last_result` → the stored results dict of the most recent completed
  run (empty dict if none).

### B. `src/xschem.tcl` — one `source` line + comment per decision 1.

### C. `src/Makefile.in` — add `ase.tcl` to the `/local/install_shares` list
(filename only; it's a tmpasm list — do not touch anything else).

### D. `tests/headless/test_ase_core.tcl` (new) — named checks

Header comment + run line
(`./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_core.tcl`,
repo-root cwd). Use the check/RESULT pattern of test_sky130a_libmgr.tcl; final
banner `RESULT: ALL PASS (N checks)` / `RESULT: <n> FAILED`. Scratch under
`[pwd]/_ase_core_[pid]`, `file delete -force` at start and end. Fixture per
decision 9 (embed the sch text from the probe section, scratch defs file,
registry vars). R2/R4 must use schema-only states; R3 alone owns unknown keys
(keeps sabotage S3 surgical).

- R1 `state_default` has exactly the 10 schema keys, version 1, analyses list
  the four types with only op enabled.
- R2 save→load dict round-trip: every key of a schema-only nfet state equal
  after `state_save` + `state_load`.
- R3 unknown-key preservation: hand-written file with `custom_key {hello
  world}` + a few known keys → load → save → saved file contains
  `custom_key {hello world}` AND the known values survive (merge over
  defaults, not under).
- R4 byte-stability: `state_save` f1 → `state_load` f1 → `state_save` f2 →
  f1 and f2 byte-identical (binary read compare).
- B1 backend registry: `ngspice` registered; all four hooks resolve to
  existing commands (`info commands`).
- D1 golden deck: `render_deck` on the literal netlistText below + the nfet
  state (models file literally `/models/sky130.lib.spice` section tt;
  variables Vgs 1.8, Vds 1.0; analyses op enabled 1 dc/ac/tran 0; outputs
  `{name id expr -i(v1) save 1 plot 0}`; options `{name savecurrents value
  1}`) `string equal` to the literal expected deck below. netlistText:

  ```
  ** sch_path: /fixture/nfet_clean.sch
  **.subckt nfet_clean
  XM1 D G GND GND sky130_fd_pr__nfet_01v8 L=0.15 W=1 nf=1 ad=0.29 as=0.29 pd=2.58 ps=2.58 nrd=0.29 nrs=0.29 sa=0 sb=0 sd=0 mult=1
  V1 D GND 1
  V2 G GND 1.8
  **.ends
  .GLOBAL GND
  .end
  ```

  expected deck:

  ```
  ** sch_path: /fixture/nfet_clean.sch
  **.subckt nfet_clean
  XM1 D G GND GND sky130_fd_pr__nfet_01v8 L=0.15 W=1 nf=1 ad=0.29 as=0.29 pd=2.58 ps=2.58 nrd=0.29 nrs=0.29 sa=0 sb=0 sd=0 mult=1
  V1 D GND 1
  V2 G GND 1.8
  **.ends
  .GLOBAL GND
  .lib /models/sky130.lib.spice tt
  .param Vgs=1.8
  .param Vds=1.0
  .options savecurrents
  .save -i(v1)
  .control
  op
  print -i(v1)
  .endc
  .end
  ```

- D2 disabled analyses absent + order: with dc still disabled no `dc ` line
  anywhere; enabling tran (`step 1n stop 1u`) yields `op` before `tran 1n 1u`
  inside `.control`.
- D3 strip robustness: netlistText without a trailing `.end` renders a deck
  with exactly one `.end`, at the end.
- N1 `ase::netlist` on the scratch fixture state returns
  `<rundir>/nfet_clean.spice`; file exists, contains `XM1`, contains NO
  `.control` and NO `.lib`, last non-blank line `.end`.
- N2 rundir defaulting: state with `rundir {}` + `set ::netlist_dir
  <scratch>/simdefault` → `ase::rundir` returns it (created).
- E1 end-to-end (leg guarded: if `[auto_execok ngspice] eq {}` print the leg
  as SKIPPED and don't count it): full nfet state (real models path, rundir
  scratch) → `ase::run` + `ase::wait` → E1a exit 0 and deck file
  `<rundir>/nfet_clean_ase.spice` exists; E1b log file
  `<rundir>/nfet_clean_ase.log` exists, non-empty, contains `No. of Data
  Rows`; E1c `ase::last_result` id value within rel tol 1e-3 of 4.096837e-04.
- E2 clean error path via the public seam: `ase::register_backend fakesim`
  reusing the ngspice hooks but run_cmd → `ase_definitely_missing_binary_xyz`;
  state simulator fakesim → `ase::run` raises a clean Tcl error (execute
  returns -1), no hang, no crash.
- E3 unknown simulator: state simulator `nosuchsim` → `ase::run` (or
  backend_hook) errors mentioning the simulator name.

### E. `tests/headless/full_audit.sh` — add `test_ase_core` to `nogui_tests`.

## Verification (in order)

1. `tests/headless/full_audit.sh test_ase_core` → PASS (this runs it --nogui).
2. Full `tests/headless/full_audit.sh` → fail list must equal the baseline
   list above (list equality; SKIPs fine).
3. Commit (file list below), then sabotage-verify, then confirm clean.

## Sabotage plan (run AFTER the commit so `git checkout -- src/ase.tcl` reverts; ≥2 mandatory, S3 recommended)

- S1 render_deck: swap the `.param` block before `.lib` → re-run: EXACTLY D1
  fails (E1 stays green — params are order-insensitive — proving D1 is the
  ordering guard). `git diff src/ase.tcl` shows only the swap; revert.
- S2 result_probe: regexp ` = ` → ` == ` → re-run: EXACTLY E1c fails (D1,
  E1a, E1b green). Revert.
- S3 state_save: skip keys not in the canonical list → EXACTLY R3 fails
  (R2/R4 use schema-only states and stay green). Revert.
- After each revert: clean re-run green before the next sabotage; finish with
  a final green `full_audit.sh test_ase_core`.

## Commit — exactly these files, staged explicitly

```
git add src/ase.tcl src/xschem.tcl src/Makefile.in \
        tests/headless/test_ase_core.tcl tests/headless/full_audit.sh
```

Nothing else — especially not src/Makefile (generated, untracked), not any
`_ase_core_*` scratch leftovers (delete them), none of the pre-batch dirty
files. Commit message: prose, e.g. "feat(ase): ASE-L core — state I/O,
ngspice backend, deck render, batch run (doc/claude/specs/ase_l.md P1)" with a
body describing state format, seam, guard decision, test + sabotage results;
end with the Co-Authored-By trailer per repo convention.
