# ASE-L — Analog Simulation Environment (Cadence ADE-L work-alike)

Status: SPEC / PLAN (no code yet)
Owner branch: fluid-editing
Related: doc/claude/specs/sky130_workarea.md, src/library_manager.tcl, src/ciw.tcl

## Goal

Give xschem a Cadence-ADE-style simulation cockpit so testbench schematics stop
carrying simulation clutter. Today `sky130_tests/nfet_test_claude` embeds a
`simulator_commands_shown` control deck and a `corner.sym` model include in the
schematic; the target cell `sky130_tests/test_nfet_final` will contain **only
the circuit** (device, sources, net labels) while everything else lives in a new
**`ngspice_state1` view** opened by ASE-L:

- run directory, simulator choice
- model libraries / corner
- analyses (op / dc / ac / tran)
- design variables
- outputs to be saved
- netlist viewer, simulation log viewer
- Session > Design Window (raise/open the schematic tied to the session)

ngspice runs as a **subprocess** with output streamed into a Tk log viewer —
no xterm dependency.

Decisions locked with the user (2026-07-20):
1. v1 scope = full de-clutter set (analyses, corner, variables, outputs,
   sim/run-dir, netlist viewer, log viewer, Design Window). Plotting via
   existing graphs/gaw wiring deferred to a later phase.
2. State = **single Tcl-dict text file** per view:
   `<lib>/<cell>/ngspice_state1/<cell>.state`.
3. v1 simulator = **ngspice only**, but state schema + deck generation behind a
   per-simulator table so others can slot in.
4. Implementation = **pure Tcl** (`src/ase.tcl`), like LibMgr/CIW; C touched
   only if view dispatch/netlisting force it.

## State file schema (v1)

Tcl dict, human-readable, git-friendly. One `key value` per line via
`dict`-formatted text; read with `dict create {*}[read $f]`-style loading
(exact loader below). All keys optional except `version`, `simulator`,
`design`.

```tcl
version     1
simulator   ngspice
sim_entry   {}                 ;# empty -> no choice of its own; see below
design      {lib sky130_tests cell test_nfet_final view schematic}
rundir      {}                 ;# empty -> $netlist_dir default
models      {{file $::SKYWATER_MODELS/sky130.lib.spice section tt}}
variables   {{name Vgs value 1.8} {name Vds value 1.0}}
analyses    {{type op enabled 1}
             {type dc enabled 0 source V2 start 0 stop 1.8 step 0.01}
             {type ac enabled 0 points 10 start 1 stop 1e9 dec 1}
             {type tran enabled 0 step 1n stop 1u}}
outputs     {{name id expr -i(v1) save 1 plot 0}}
options     {{name savecurrents value 1}}
includes    {}
pre_commands {{cmd {pre_osdi $::SG13G2_OSDI/psp103.osdi}}}
```

- `sim_entry` is **which registered simulator this test bench runs** — the
  registry entry, not the backend. `simulator` above is the BACKEND
  (`ngspice`): which `ase::backend::<sim>::` table renders and runs the deck.
  `sim_entry` is one level down: which program on this machine, with which
  `-args`, case mode and `--no-spiceinit`. Three values:

  | value | meaning |
  |---|---|
  | absent or `{}` | this state makes no choice of its own; run `ase::sim_default` |
  | `none` | deliberately the program the system finds on the `PATH` |
  | `{name <entry>}` | that registry entry |

  The two-word form exists so no registry name has to be reserved. A reader
  meeting a bare one-word value that is not `none` takes it as an entry name —
  a hand-written file is forgiving — and `{name none}` is how an entry actually
  called `none` is spelled. `ase::sim_default` holds the SAME three values, so
  one decoder (`ase::sim_choice_decode`) reads both and neither store has to
  know how the other spells "the program on the PATH". It is in
  `omit_if_empty` with `cosim` and `save_op_params`, and its default is `{}`,
  so the 104 committed `.state` files never gain the key and keep
  round-tripping byte-identically. Changing it
  DIRTIES the session like any other key: explicit save, and a prompt on
  shutdown. Issue 1395; ordering here follows `ase::schema_keys`.
- `variables` become `.param` lines; schematic references them symbolically
  (`W=Wn`) — plain ngspice resolves `.param` at netlist level.
- `analyses` render into one `.control` block (op → `op`, dc → `dc V2 0 1.8
  0.01`, …) in a fixed order; only `enabled 1` entries emit. **The emit loop
  walks the enabled ROWS and ranks them; it does not walk a list of types**
  (issue 1401). An enabled row whose `type` this backend has no rank for is a
  **refusal**, named — `ase: analysis type '<t>' is not one this simulator
  backend can render` — raised from `ase::preflight_gate` before the deck is
  written and again from `render_deck`. It used to be skipped in silence: the
  run completed, produced nothing, and left the row ticked in the pane.
- `models` render `.lib <file> <section>` lines (corner.sym's job today).
- `includes` render top-level `.include <file>` lines, emitted **before** the
  `.lib` models so any global `.param`s they define are in scope when the models
  evaluate. Each entry is a `{file <portable-path>}` dict with the same
  `$::VAR`-expansion contract as `models` (a bare-string entry is taken verbatim
  as the path). Needed for PDKs whose corner section is not self-contained —
  e.g. gf180's `sm141064` `typical` references `design.ngspice`'s switch params
  (`sw_stat_global`, `mc_skew`, `fnoicor`, …); see `gf180mcuD/README.md`.
- `pre_commands` render at the **head of the `.control` block**, ahead of the
  analyses. ngspice runs its `pre_*` family before the netlist is parsed, which
  is the only way to load a compiled Verilog-A module — `pre_osdi <file>.osdi`;
  there is no `.osdi` dot-card. IHP SG13G2 needs four of them (psp103,
  psp103_nqs, r3_cmc, mosvar) or every bench with a MOS, varicap or `r3_cmc`
  resistor netlists fine and then dies at `could not find a valid modelname`.
  Same entry shape and `$::VAR`-expansion contract as `includes`: a
  `{cmd <text>}` dict, or a bare string taken verbatim. `::ASE_DEFAULT_PRE_COMMANDS`
  seeds it for a fresh session (ihp-sg13g2/cadence_style_rc), mirroring
  `::ASE_DEFAULT_MODELS`/`::ASE_DEFAULT_INCLUDES`. Position inside the block does
  not matter to ngspice (probed, ngspice-46); first is where it reads honestly.
- Loader/saver in `ase.tcl`; unknown keys preserved round-trip (forward compat).

## Deck assembly (no C changes)

1. `xschem netlist` the **clean** schematic → `<rundir>/<cell>.spice`
   (devices + `.GLOBAL` + `.end` only, since the schematic carries no
   `netlist_commands` instances — verified spice_netlist.c:214-591).
2. ASE post-processes: strip trailing `.end`, append in order:
   `.include` includes, `.lib` models, `.param` variables, `.options`,
   `.save` outputs, `.control` analyses block, `.end`.
3. Write `<rundir>/<cell>_ase.spice` (schematic netlist artifact stays
   untouched); run `<simulator> -b <cell>_ase.spice 2>@1` from the run
   directory. **There is no `-o`**: stdout must flow into `execute(data,$id)`
   so the session window can show it live, and `2>@1` folds the simulator's
   warnings into the same stream. The log file is written by ASE itself
   (`ase::run_log_write`), framed with the command, directory, deck and
   elapsed time. This paragraph used to describe an `-o` redirect that the
   code had not emitted for a long time.

Per-simulator seam: step 2+3 live behind `ase::backend::<sim>::render_deck` /
`run_cmd` table; v1 registers `ngspice` only.

### Which simulator program actually starts (issue 0931)

`ase::sim_status <backend>` is the **one** resolver, and every caller renders
what it says — `run_cmd` builds the command from it, `ase::sim_exe` raises its
sentence, and a caller asking merely "is a simulator available" reads its
`resolved` field. Registering nothing leaves the answer exactly as it always
was: the bare backend name, `auto_execok`'s file, and a byte-identical command.

* **Registry entries** are `{name <label> path <program> args <extra argv>
  backend <name or empty>}`. `ase::sim_register` / `ase::sim_unregister` /
  `ase::sim_select` / `ase::sim_list` drive them; the path is expanded
  (`$::VAR` form, as `models` paths are) and normalised to absolute at
  registration, because `ase::run_deck` `cd`s into the run directory before it
  launches anything.
* **A path that is missing, is a folder, or is not marked executable is
  reported out loud** and the entry is kept, flagged unusable, so the user can
  fix it. Every sentence is minted once in `ase::sim_why`.
* **A path that names a setting this session does not have** (`$::PDK_ROOT/...`
  with `PDK_ROOT` unset) gets its own sentence, because "there is no such file"
  would send the user to look at a disk when the thing to fix is a setting.
* **Layers**: `::ASE_SIMULATORS` / `::ASE_SIMULATOR` from an rc
  (`xschemrc`/`cadence_style_rc`, same idiom as `::ASE_DEFAULT_MODELS`), then
  `$USER_CONF_DIR/ase_simulators` (written by `ase::sim_write_conf`, read at
  startup by `xschem.tcl` beside the other loaders), then the session. rc
  entries are never copied into the user file, and removing one from inside
  xschem says so — it is back at the next start until the rc itself is edited.
* **A mistake in the rc costs a sentence, never the editor.** The seed's
  `foreach` header is itself inside the catch: `foreach x $v` parses `$v` as a
  list *before* the body runs once, so an unbalanced brace in `::ASE_SIMULATORS`
  used to raise out of reach of the body's own catch and abort the source of
  `ase.tcl` — xschem exited with no schematic editor at all, where the identical
  typo in `::ASE_DEFAULT_MODELS` starts normally. Row E12 of
  `tests/headless/test_ase_simreg_0931.tcl` measures the two side by side.
* **The door is `Setup > Simulators…` (issue 0937).** One dialog, listing
  every registered simulator with the reason any one of them cannot be started
  in a Problem column, Add / Edit / Remove, and a "use this one" control whose
  first line is *(none — use the program my system finds on the PATH)*. It
  drives the procs above and saves through `ase::sim_write_conf` — one writer,
  two front doors — and it re-words nothing: every sentence it shows is
  `ase::sim_why`'s, read back through `ase::sim_said` when it is reporting what
  a gesture just did. Feedback lands IN the dialog (`.status`) and in the row
  editor (`.simrow.status`), not only in the CIW, because silence is this
  area's failure mode. The Name field is read-only in Edit, so a rename is a
  Remove plus an Add.
* **The row editor shows four fields (issue 1371): Name, Program, Case and
  `-n`.** It carries the extra arguments and the backend through untouched;
  every field it *does* show is written on OK, and that is not a detail — until
  1371 the editor rebuilt the entry from `args` and `backend` alone, so opening
  Edit… on an entry carrying `casemode preserve` and pressing OK without typing
  anything ERASED the case mode and the `-n` flag and saved the erasure.
  `Case:` is a read-only chooser whose values are **the global-default line plus
  exactly `ase::sim_casemode_selectable_*` for the program named in the Program
  field, and nothing else** — rule A1, never offer a mode the binary was not
  measured to deliver. It is keyed on the program in the FIELD, not on the
  simulator in force and not on the entry's stored path, **and it is rebuilt
  every time that field changes** — through the entry's own validation, so
  typing and `Browse…` are covered by one mechanism. The rebuild is the half
  1371 shipped without: the chooser was keyed on the field but BUILT only at
  editor-open and by Detect, so retyping the Program field left the previous
  program's modes on offer and OK saved one of them (measured: `-D
  casemode=preserve` emitted for a build measured to deliver `fold` alone).
  A mode outside the offer is shown MARKED rather than dropped — `preserve
  (not tried yet)` when nothing has measured that program, `preserve (NOT
  supported)` when it WAS measured and does not deliver it, which are two
  different statements and used to share one wording. Hand-editing the saved
  list was the only way to ask for a mode before this item existed, and opening
  the dialog must not silently rewrite what the user wrote; a marked mode the
  user leaves selected is still saved, exactly as a hand-written one is.
* **Opening the row editor never starts the user's simulator.** The chooser is
  built from CACHED measurements only (`ase::sim_caps_have_path`, a peek), and
  `Detect` is the one control in the dialog that may launch anything. Measured:
  447 ms cold on the user's own build, 0 ms warm, and **31.2 s** for a program
  that exists, is executable and never answers (`ase::cap_budget_ms` is 30 s),
  with Tk frozen throughout — and a licensed tool would check out a licence.
  Detect paints its sentence and flushes the display *before* it blocks. Which
  of cached-first-plus-Detect, probe-on-open, and probe-on-open-when-in-force is
  wanted is the user's ruling, filed on the owed ledger under 1371; the code
  implements the first and the other two are one line in
  `ase::ui::simdlg_case_values`.
* **The editor says what is known about the program it is showing, before
  anything is tried** (`ase::casemode_status`, painted at open, when the Program
  field is left, and after `Browse…`; silent on an empty Add form). Without it
  a cold session shows `fold` alone with no explanation, which is
  indistinguishable from the bug this door was built to fix. `Detect` then
  reports what actually happened (`ase::casemode_report`), and it has an arm per
  measured state — answered but said nothing about spellings, tried and delivers
  none of them, no file there, not a program, no probe for that backend, still
  running when the budget ran out, nowhere to write a test result, no location
  given. Every one of those used to print "has not been tried yet … press Detect
  to try it", after Detect.
* **What was measured is remembered about a program AND the argv it was started
  with** (`ase::cap_key`). The probe has always run the program with the entry's
  own extra arguments; the cache was keyed on the resolved path alone, so the
  row editor's Detect — a second writer, asking about a location the user typed
  — could answer for the run. Measured on a stub that reports no case-mode
  feature under `-q` and all three without it: one dialog-side measurement made
  `ase::sim_casemode_selectable` answer `fold preserve distinguish` for an
  in-force entry that really delivers `fold`.
* **Removing the simulator in force says what happens next.** Either the one
  survivor is named as the one that will start now, or the user is told nothing
  of theirs is picked and the program on the `PATH` takes over. Both sentences
  are minted in `ase::sim_why`; the "it will be back at the next start" one for
  an rc entry is always said LAST.
* **"None of mine" is a choice and is saved as one (issue 0932).** The saved
  list carries `ase::sim_select {}`, so a cleared choice survives a restart
  instead of the first entry being put silently back in force — and it
  therefore overrides an rc's own `::ASE_SIMULATOR` at the next start.
  ⚠ **Amended by issue 1395**: what that line records is now
  `ase::sim_default`, the installation default, and never the choice a session
  has made for itself. The property 0932 was written to protect is unchanged —
  a deliberately cleared default is still a line in the file and still not the
  absence of one.
* **The saved list is written beside itself and moved into place.** A failed
  write used to truncate the user's list before the first line was written and
  then raise out of a proc that promises not to; now the file they have keeps
  what it had until a complete new one is ready.
* **The suite is hermetic about the user's own saved list.** A machine whose
  user has registered a simulator has a real `$USER_CONF_DIR/ase_simulators`,
  which xschem reads at startup, so "nothing is registered" is false in the
  test process too: the in-process rows clear the registry first and every
  fresh-start claim is measured in a child with `HOME` redirected into the
  suite's scratch tree.

### The registry is environment; the choice is state (issue 1395)

The user's ruling, 2026-09-08: *registering* a simulator so future xschems can
see it may reach disk the moment it is done, and is **not** part of the state
that accompanies a test bench; *which* registered simulator is assigned as the
one to use **is** part of that state — it dirties, it must be saved explicitly,
and an xschem shutdown with it unsaved must warn and prompt.

That draws one line through this section:

| | environment | state |
|---|---|---|
| **what** | the registry: every entry's name, program, `-args`, backend, case mode, `-n` — and `ase::sim_default`, what a session with no choice of its own runs | `sim_entry`: which entry THIS test bench runs |
| **lives in** | `$USER_CONF_DIR/ase_simulators`, plus the rc layer | the `.state` file beside the test bench |
| **when it is written** | at the mutation, immediately, unasked | on an explicit Session > Save State |
| **dirties a session** | no | yes |

Three consequences, and each of them was a defect before 1395:

* **Persistence hangs off the MUTATION, not the gesture.** `ase::sim_register`
  and `ase::sim_unregister` save; the Simulators dialog does not save *for*
  them. Both doors — the dialog and `ase::sim_register` typed into the CIW —
  therefore persist, which is what `src/xschem.tcl`'s Configure-simulators help
  has always promised. Gated on `ase::sim_origin eq session`, because
  `ase::sim_load_conf` **sources** the saved list and every line in it is a real
  `sim_register` call: without the gate the reader rewrites the file it is
  reading.
* **`ase::sim_clear` does NOT save.** It is teardown — "forget every registered
  simulator and every choice" — and a teardown that autosaved would let a test
  or a stray script blank the user's list. The rule, in one line: *a mutation
  that expresses a user's choice persists; a teardown does not.*
* **`ase::sim_use` is a cache, not a store of record.** It still means "what is
  in force right now" and every `ase::sim_status` caller reads it unchanged; the
  store of record is the running session's `sim_entry`, and `sim_write_body`
  writes `ase::sim_default` in its place.

**Known limitation.** Two ASE-L windows open on different test benches share one
`ase::sim_use`. The run applies the running session's `sim_entry`, so "the
window you clicked in wins" for the run — the half that decides which program
actually starts — but a status bar in the other window may momentarily name the
other choice, because the bar renders from the process-global cache. Recorded,
not fixed; closing it means a per-window registry view.

### What that program can actually do (issue 0948)

`ase::sim_capabilities <backend>` answers what the build that will ACTUALLY
start can do — resolved through `ase::sim_status`, never a bare name. The
answer is a dict: `{known 0}`, `{known 0 unmeasured <reason> ...}`, or
`{known 1 usable 0|1 appendwrite 0|1 blanket_op_save 0|1 hier_op_names 0|1}`.
When `known` is 0 the capability keys are **absent, not 0**; absent means
nobody measured, 0 means measured-and-no. `unmeasured` is a REASON, never a
capability: `timeout` (the program had not finished inside the budget, and
`secs` says how long the user waited) or `noplace` (there was nowhere for the
probe to work). A `noplace` answer carries **`noplace_why`** — `occupied` (a
file is sitting where `.ase_probe` has to be), `readonly` (the simulation
folder **will not take a new entry**, established by TRYING to make one) or
`other` (the folder DID take a new entry and the probe place still could not
be made or used: a dangling `.ase_probe` symlink, which `file exists` follows
and so cannot see, a `.ase_probe` directory with no write permission, or 64
name collisions in a row) — and **`noplace_at`**,
the file or folder that is in the way: the probe place for `occupied` and
`other`, the simulation folder for `readonly`. The say-site reads the
diagnosis rather than working out a second time what only `ase::cap_workdir`
was in a position to know (issue 0960).

  ⚠ **`readonly` is decided by `ase::cap_dir_takes_entry`, which MAKES an
  entry and removes it — never by `file writable`.** `file writable` on a
  DIRECTORY is POSIX `access(W_OK)`: it answers about the write bit and says
  nothing about the SEARCH (x) bit, and a create needs both. Measured, one
  `tclsh`, both modes: a folder at **0600** and one at **0200** each answer
  `file writable` **1** and refuse `mkdir` and `open …w` alike with
  `permission denied`. For one round the test was `file writable` and those two
  shapes fell into `other`, where the sentence told the user their simulation
  folder could be written into and offered them a `.ase_probe` to delete that
  did not exist — **both clauses false**. Rows **N14** and **N15** of
  `test_ase_simcaps_0948` are those two modes through the real seam, **N16**
  guards the trial against leaving litter in the user's folder, and **N6** now
  takes all three sentences apart rather than two.

* **The method is a PROBE RUN, never a version string.** Measured: a stock
  ngspice and one patched to ignore the add-each-analysis line print the
  byte-identical `** ngspice-46+ : Circuit level simulation program`. The probe
  is two tiny PDK-free decks (a level-1 MOS two subcircuits deep, op + tran),
  and it runs **lazily on first use** — never at startup. Cost measured
  2026-09-06 on the user's own `build-ver_50`: **447 ms** cold for the whole
  answer including the three case-mode legs (an older note here said ~10 ms,
  which predates those legs), 0 ms warm, and 31.2 s for a program that never
  answers.
* **The verdict is the RESULT, never the exit code and never the log.**
  Measured: a blanket device save exits 0, writes a results file, and logs no
  warning and no error, while holding a `constants` plot and no operating point
  at all. Every answer is read out of the results file the probe's own deck
  asked for, by `ase::cap_raw_plots` — the probe's own reader, so it never
  touches the results database the waveform viewer has attached (ruling 0881).
* **The cache key is the resolved absolute path; the stamp is path + mtime +
  size.** A user who rebuilds their simulator in place is re-measured with
  nothing to do on their part, which is the whole point. `ase::sim_caps_clear`
  forces a re-measure. Nothing is ever cached under an empty `resolved`, which
  is what two unrunnable backends both answer (issue 0935).
* **An answer nobody worked out is NEVER remembered (issue 0950).** Only a
  `known 1` answer is cached. Before that rule, a failure of the RUN — a folder
  that could not be written into, a program that did not answer in time — was
  stored as if it were a fact about the PROGRAM and served for the rest of the
  session, in an ordinary folder, with nothing in the GUI able to clear it.
  `ase::sim_register` and `ase::sim_unregister` also clear the whole cache, so
  adding, editing or removing an entry makes the tree look again. **That call
  sits on the registry writer, not on the dialog**: Setup > Simulators and the
  Command window are two doors onto the same writer, and putting it in the
  dialog would leave the other door broken. It is deliberately NOT in
  `ase::sim_select` — switching back to a simulator already measured is not a
  statement that anything about a program changed.
* **The probe works in a directory of its own, per measurement (issue 0951).**
  `ase::cap_workdir` answers a fresh, empty
  `<simulation folder>/.ase_probe/p<pid>_<n>` that no other probe is using, or
  EMPTY when no such place can be made — which `ase::sim_capabilities` turns
  into `{known 0 unmeasured noplace}` rather than into an accusation about the
  user's program. `ase::cap_workdir_done` removes it on every path out,
  including the one where the probe raised (and then re-raises, so a defect in a
  probe stays loud); it deletes the shared `.ase_probe` parent WITHOUT `-force`,
  so the parent goes when it is empty and survives when another process's probe
  is still using it. **And no verdict is taken from a results file this run did
  not see appear**: `ase::cap_claim` / `ase::cap_result` are the second guard,
  for the collision a private name cannot cover — a recycled process number, a
  predecessor that died without tidying up, a caller that hands the probe a
  directory of its own. The probe never deletes a results file it did not
  create. Before all that, a program that wrote not one byte measured
  `usable 1 appendwrite 1 hier_op_names 1` because a separate process dropped
  its own results at the one fixed name.
* **The program is run with the probe's directory under it, and its deck names
  its results with a BARE FILE NAME (issue 0949).** Not a quoting fix, and the
  distinction is load-bearing: measured on ngspice-46+, an absolute path with a
  space in it is read as a file name followed by a VECTOR name, no such vector
  is found, and nothing is written anywhere. Six write forms were measured
  against five hostile folder names and none of the in-deck forms — bare,
  double-quoted, backslash-escaped, `.control`-level `cd`, or an indirection
  through a variable — survives a folder called `do$llar`, because the program
  expands `$` inside `.control` regardless of quoting. Giving the process the
  target folder as its own current directory is the only form that survived a
  space, a dollar, a bracket, a single quote and a semicolon alike.
  `ase::cap_run` resolves a RELATIVE program location before the move, so a user
  who registered `./build/ngspice` keeps working; a name with **no separator in
  it at all** is left alone, because that one is a PATH lookup the move cannot
  affect. The test is the separator, not the dirname (**issue 0961**, fixed):
  it used to read `[file dirname $prog] ne {.}`, and `./ng` has dirname `.` too,
  so a single-segment relative location was left alone and then failed while
  `bin/ng` ran. Rows **K5b**, **K5c** and **K5d** of `test_ase_simcaps_0948`.
  **A relative name reaches the runner by an ordinary route, not only from a
  direct caller.** With nothing in force, `ase::sim_status` puts
  `[lindex [auto_execok $backend] 0]` in `resolved` and `ase::sim_capabilities`
  hands that to the probe; `auto_execok` answers `./ngspice` whenever `$PATH`
  carries an empty element — a leading, doubled or trailing `:` — or a literal
  `.`, and the program is in the current directory (measured, tcl 8.6.17). Row
  **K5e** drives that route end to end. The backslash counts **only on
  Windows**; on Unix it is an ordinary character in a file name, and that
  platform gate — defended in a write-up and guarded by nothing until the repair
  round — is held by row **K5h** behaviourally and row **K5i** structurally.
* **`appendwrite` means the writes ADDED UP, and nothing else (issue 0952).**
  Deck A asks for two analyses and two writes into one file; two plots coming
  back in that one file is the answer, whatever the plots are called. It used to
  be decided by whether the vectors the probe expected turned up under the names
  it expected, so a build that appends perfectly but spells device parameters
  differently — whose operating point therefore degenerates to a `constants`
  plot — was told it keeps only the last analysis and advised to run one
  analysis at a time, which is a wrong diagnosis AND advice that changes
  nothing. Whether an operating point holds device numbers this tree can read is
  `hier_op_names`, which is where the "at least one data point" requirement now
  lives; the two questions must never be able to fail each other.
* **`capabilities` is an OPTIONAL sixth backend hook**, beside `render_deck`,
  `run_cmd`, `log_file`, `result_probe` and `raw_file`. A backend that declares
  none is answered `known 0` — never a guessed yes.
* **`ase::cap_report`, called once from `ase::run_deck`,** is the only say-site:
  a program that produced nothing is reported whatever the run looks like, and a
  build that keeps only the last analysis is reported when the run has more than
  one. **A place the probe could not use is reported too (issue 0960)** — in
  the FOLDER's or the FILE's words, never the program's, in **three** sentences,
  one per `noplace_why`, and **once per place AND per reason**
  (`ase::cap_noplace_once`, keyed on `{at why}`, forgotten by
  `ase::sim_caps_clear` with every measured answer), because nothing about that
  state clears itself and a sentence per Run would be a sentence per Run for the
  rest of the session. **The key carries the reason as well as the place** and
  that is not tidiness: two reasons can answer with one path, and a key that is
  only the path withholds the second fact from a user who has just fixed the
  first -- issue 0960's own defect, reached through its own fix (rows N12 and
  N13 of `test_ase_simcaps_0948`).
  Every sentence is minted in `ase::sim_why` like every other one here.
  **The run, not the command builder** — building a command line happens in
  places that must stay silent, and `test_ase_simcaps_0948` row F8 pins both
  ends of that so the report cannot be refactored out of the one place the user
  meets it.
* **Four belts around the probe run, each pinned by its own row.** The program
  is given nothing to read (`< /dev/null`, row G3) so a build that drops into
  its own prompt cannot hang the user's Run; it is given a bounded number of
  seconds (row G5) so one that never returns for any other reason cannot
  either; the extra arguments the user registered are handed to it when
  it is measured (row G6), so what was measured is the program they will
  actually get; and `ase::cap_raw_plots` reads a results file written as raw
  numbers as well as one written as text (rows B7/B8), stepping over each
  payload by its own length so a run of numbers that happens to spell a plot
  header is never mistaken for one.
* **ONE budget for the whole measurement, not one cap per run (issue 0953).**
  `ase::cap_budget_ms` is 30000 and `ase::cap_left` hands each run what is left
  of it; once a run has been cut off the second is not attempted. The measured
  20.0 s freeze of the user's Run gesture was two runs each paying a literal
  ten-second cap that nothing could ask to be smaller. Thirty seconds is
  deliberately generous — a healthy probe is 0.014 s cold and nothing warm, and
  a tighter bound would cut off exactly the slow-to-start build 0953 is about.
  `ase::cap_run` returns `{exitcode output was-it-cut-off elapsed-ms}`, and
  **was-it-cut-off needs all three of** a cap actually applied, child status
  124, and elapsed time that reached the cap — so a simulator that exits 124 of
  its own accord is not called a timeout and a cap that was never applied cannot
  manufacture one. The cap is `timeout -k 2 <secs>` where the box has it:
  measured, the plain form lets a stop-ignoring program run its full thirty
  seconds. A cut-off answers `{known 0 unmeasured timeout secs N}`, which is
  never cached, and `ase::cap_report` says the `cap_no_answer` sentence — which
  claims only what was established, that the program had not finished, and never
  that it is not a circuit simulator.
  ⚠ **All of that is conditional on the box having `timeout(1)`, and nothing
  says so when it does not.** With no cap the run is unbounded, the answer falls
  through to the ordinary `usable 0` verdict, that verdict is `known 1`, and
  `known 1` is cached — so the bound, the honest sentence and the never-cache
  rule fail together and silently. Measured on this box with the prefix emptied:
  16.0 s unbounded, `cap_not_a_simulator` said, remembered. Filed as
  **issue 0959**.
* **`ase::cap_run` belongs to no one simulator (issue 0954).** Everything after
  the program name comes from the caller: the arguments the user registered, the
  backend's own flags, and the deck. It used to append ngspice's `-b` itself,
  against this file's own seam rule (`src/ase.tcl:24`).

* **Where the shipped code does not yet meet this contract.** Issues 0949 (the
  probe half), 0950, 0951, 0952, 0953 (the bound and the sentence) and 0954 were
  all fixed on 2026-08-30 and are described above. What is still genuinely open:
  * **0957** — the REAL deck's own `write [raw_file $state]` line
    (`src/ase.tcl:5613`) is still absolute and unquoted, so a user running from
    a folder whose name has a space in it gets a run that writes its results
    nowhere. This is 0949's older half and it is deck emission, not the probe.
    The measured mitigation is on the issue: `ase::run_deck` already cd's into
    the very folder `raw_file` joins, so a bare basename resolves to the same
    file.
  * **0953's other half** — the probe is still paid inside the user's Run
    gesture, so a program that never answers still costs a bounded pause.
    Getting the measurement off that path is the larger fix and is not done.
  * **0958** — and that pause is paid on EVERY press of Run, not once. A
    cut-off answers `known 0`, `known 0` is correctly never remembered, so the
    next press measures again from scratch: measured 3004 / 3003 / 3005 ms at a
    lowered budget, and 30.0 s x 3 at the shipped one. Before this contract
    existed the same user paid 20 s once and nothing after.
  * **0959** — the bound, the honest sentence and the never-cache rule all
    depend on `timeout(1)` being on the box, and evaporate together in silence
    when it is not.
  * **0960 — FIXED 2026-09-07, in its first shape only; REPAIRED, then
    REPAIRED AGAIN, the same day.** The states that answer
    `{known 0 unmeasured noplace}` used to say NOTHING, on every Run, for good,
    which switched off every warning this section exists to give — the one
    about a build that keeps only the last analysis included. They now say
    which folder or which file is in the way and what to do about it, once per
    place and per reason (rows N1–N16 of `test_ase_simcaps_0948`). **Both
    repair rounds are part of the record.** Round one: the first landing
    shipped THREE sentences while its own write-ups said two, and the third —
    the catch-all — had no row on it, named the simulation folder and told the
    user to check that they could write into it; the once-per-place key also
    fused two arms, so a user who fixed the read-only folder and then met the
    catch-all was told nothing. Round two (the close-out): **that repair
    shipped a regression and a false invariant.** It justified the catch-all's
    new sentence with "`ase::cap_noplace_at` tests read-only first, so this arm
    is only ever reached when the folder IS writable" — and the test it meant
    was `file writable`, which on a DIRECTORY is `access(W_OK)` and ignores the
    search bit. A folder at mode **0600** or **0200** answers `file writable` 1
    and refuses every create, so both landed in the catch-all and were told
    their folder could be written into and offered a `.ase_probe` to delete
    that does not exist — **both clauses false, and worse than what stood
    before the repair**, whose sentence at least named the folder. The folder
    test now MAKES an entry and removes it (`ase::cap_dir_takes_entry`), those
    two modes land in the folder's own arm, and that arm's advice changed from
    "Make it writable" to "Give it write and search permission, or pick another
    folder" because `chmod u+w` on a 0600 folder changes nothing. Rows N14–N16;
    N6 now takes all three sentences apart rather than two. **What is still
    open is the issue's fix shape 2:** falling back to a place the tree can
    always write, and measuring there anyway, which would make the state
    unreachable rather than merely audible. That is a product call and is on
    the user's queue as rule debt `0960`; the catch-all and folder sentences
    are rule debt `0960_catchall_sentence`.
  * **0961** — FIXED 2026-09-07. A program location written `./name` was not
    made absolute before the folder change and could not then be started, and
    the comment in `ase::cap_run` stated the opposite rule as fact. Carve-out is
    now "no separator in it at all". **⚠ THE FIRST WRITE-UP CALLED IT LATENT
    AND THAT WAS WRONG**, corrected the same day: registration does normalize,
    but the nothing-in-force route hands the probe `auto_execok`'s own answer,
    which is a relative `./ngspice` on an ordinary `$PATH`. Measured on the
    pre-fix predicate, that gesture answered `known 1 usable 0` with the program
    started **zero** times — a verdict about a simulator nobody ran. Row **K5e**.
  * **0962** — a coverage gap, not a behaviour one: no committed row reproduces
    the CONCURRENT write that issue 0951 is actually about. Row I4's headline
    half passes on the defective tree, because the old delete-at-top destroyed a
    file planted beforehand; the race itself was staged by hand and the fix does
    hold against it.
  * **0952's other half** — a build whose device parameter names this tree
    cannot read is MEASURED (`hier_op_names 0`) and still says nothing about it.
    Giving that its own sentence belongs with deck emission, which is what would
    have to do something different about it.

## Migration tool (cluttered testbench → clean + state view)

`tools/migrate/ase_migrate.py` (stdlib-only, OO; tests `test_ase_migrate.py`)
mechanically de-clutters an existing testbench into this form: it scans the
`.sch` (reusing `migrate_pin_names`'s save.c-faithful record scanner),
classifies each record, keeps the circuit (devices/wires/labels/gnd/sources) on
a clean `.sch`, and routes the rest into a byte-canonical `ngspice_state1`
`.state` view — a `corner` symbol or `code_shown`/`simulator_commands` block →
`models`/`includes`/`variables`/`options`/`analyses`; a `.control` block →
`analyses` + `outputs` (unmappable commands like `let`/`meas` are preserved in
the report, never dropped); a `flags=graph` block → plotted `outputs`; a
`launcher` → dropped. The state serializer reproduces `ase::state_serialize`'s
Tcl-list quoting in pure Python (byte-identical to a loader round-trip, verified
against the committed gf180 golden). Per-PDK profiles (`sky130`, `gf180`) supply
the corner→model map and the `$::<var>` model path. `--verify` runs the cluttered
cell and the migrated state view through xschem+ngspice and asserts the operating
point matches (fixtures: the `nfet_test_claude`→`test_nfet_final` pairs;
409.7 µA sky130 / 484.35 µA gf180). `--library` migrates a whole `*_tests` lib.

## Integration points (filled from code recon)

### View machinery (library_manager.tcl / library_defs.tcl)

Recon (2026-07-20):

- **Enumeration/resolution already generic — zero C changes.**
  `cell_views` (src/library_defs.tcl:261) globs view subdirs holding
  `<cell>.*` with no extension filter; `cellview_path`
  (library_defs.tcl:235, C dispatcher scheduler.c:2256 just routes here) →
  `cellview_resolve` (library_defs.tcl:209) tries `.sch`/`.sym` then
  falls back to any `<cell>.*` (line 222). So
  `ngspice_state1/<cell>.state` is discovered in the LibMgr View pane and
  resolves to its file as-is.
- **Open dispatch — 3 choke points, all Tcl:**
  1. `libmgr::open_view` (library_manager.tcl:432) — double-click (:136),
     both context-menu Opens (:183,:199) and `open_view_ro` (:558) all
     funnel here; today it calls `xschem load` unconditionally. Add a
     **view-type dispatch table** before the load: `schematic|symbol` →
     editor (status quo), `ngspice_state*` → `ase::open $lib $cell $view`.
  2. `hi_descend_finish` (xschem.tcl:5764) — binary
     symbol→`descend_symbol` / else→`descend`; must learn to skip or
     route state views (state views never descended into as schematics).
  3. View-type inference `hi_descend_enum_views` (xschem.tcl:5697)
     `.sch→schematic else→symbol` — extend: `.state→ngspice_state`.
- **View creation:** `newview_dialog` combobox hardcoded
  `{schematic symbol}` (library_manager.tcl:1204/1214) →
  `do_new_view` (:1154) → `library_new_view` (library_defs.tcl:701/709,
  creates empty `<cell>.<ext>`); Save-As form type mapping
  save_as_form.tcl:47/71. Extend all three: type `ngspice_state1` →
  `.state` seeded with the default state dict (not empty — must parse).

### The simulation log file is FRAMED (issue 0618, 2026-08-23)

The log on disk is no longer the simulator's stdout and nothing else. `ase::run_deck`
writes a **header** at launch (mode `w`, immediately before `eval execute`) and
`ase::run_done` rewrites the whole file as header + delimiter + output + **footer**:

```
=== ase run <cell> <timestamp> ===
simulator : <backend>
command   : <the exact argument list handed to execute, 2>@1 included>
directory : <rundir>
deck      : <deckpath>
--- simulator output ---
<the simulator's stdout, byte for byte>
=== exit <N> after <X.XX> s ===
```

**Binding constraints on anyone touching this**:

* **The output region is byte-identical to `$::execute(data,last)`, and must stay so.**
  `$data` is never mutated. `ase::run_done`'s result parsing, the `result_probe`
  backend hook (an anchored per-line regexp, `ase.tcl:3510`) and `ase::run_diagnostics`
  all read `$data` **in memory**, not the file — the framing is added to the FILE only.
  Row `E1g` in `test_ase_core` pins it.
* **`ase::run_done {logpath state callback {meta {}}}` — the 4th parameter is
  DEFAULTED and must stay defaulted.** `test_ase_cosim` calls it with three arguments
  at six sites (`:1019 :1036 :1049 :1056 :1061 :1067`); a required parameter kills 341
  checks with `wrong # args`. With an empty `meta` the file is written unframed,
  byte-identical to the pre-0618 behaviour.
* **The framing owns the newline before the footer.** Relying on `$data`'s trailing
  newline breaks for a simulator whose last line has none, and cannot express an empty
  output region.
* **Elapsed time is stamped in `run_deck` and carried**, never recomputed in the
  callback — `run_done` fires from `execute_fileevent` on EOF, which measures the wrong
  interval. Do **not** guard a `clock milliseconds` value with
  `string is integer -strict`: it is a wide integer and that test answers 0, which
  silently prints `0.00 s` forever.
* Known cost, filed as **0641**: the launch-time header truncates the previous run's
  log, and `ase::ui::show_log` shows a header-only file mid-run when it has no run_id.

### Netlist and Run must not RE-MAP the design window (issue 0616, 2026-08-23)

*(The guard described in this paragraph was REPLACED on 2026-09-08 — issue 0643,
`descend_run_batch`. See "Netlist and Run works from any level of the design"
below for the contract in force. 0616's own reasoning, and the whole `raise_mode`
table, are unchanged and still load-bearing.)*

`do_run`'s guard `[file normalize [xschem get schname]] ne $dpath` asked whether the
design is the **current xschem context**, because that is what `ase::netlist`'s own
guard required. It did **not** ask whether the design window is visible — and the
two are routinely different: a session whose state carries `viewer {open 1 …}` has
`viewer_restore` leave the context on the viewer canvas while the design window is
fully visible and front. So the guard fires on a window that needs nothing.

Routing that through `ase::ui::design_window` reached `raise_activate_toplevel`
(`src/xschem.tcl`), whose WSLg-safe raise is **`wm withdraw` + `wm deiconify`** — a
re-MAP of the whole main toplevel (`tabbed_interface` defaults to 1, so the "design
window" is a tab of `.`). That WM is documented to **drop** a re-map outright and to
cost ~32px of NW creep per raise, which is the user's report: *"when I press Netlist
and Run, the schematic window disappears; I have to do Session > Design window to get
it back"*.

**The contract now:** `design_window` → `raise_design_editor` → `raise_window_entry`
take an optional trailing `raise_mode`.

| `raise_mode` | context switch (`new_schematic switch`) | `raise` + `activate_window` | `wm withdraw`+`wm deiconify` re-map |
|---|---|---|---|
| `always` (default — Session menu, `select_on_design`/`direct_plot`, `browser_descend_to`, the post-load re-scan) | yes | yes | yes |
| `ifhidden` (`do_run` only) | yes | yes | **only when the toplevel is not mapped** |

Three things are load-bearing and must not be "simplified":

* **The context switch stays unconditional.** Drop it and `ase::netlist`'s
  design-unreachable refusal comes back — since 0643 that sentence reads
  *"design `<lib/cell>` is not open in this window"* (`ase::design_unreachable_msg`),
  and it is reached for a design sitting on **another window's** stack, which is
  exactly what the context switch exists to repair. It is also the *only* half covered by
  a test anywhere in the tree (`test_ase_window` W6m2/W6m3) — `test_ase_plot` P9 and
  `test_ase_hier_plot_0168` HL23-HL25 all stay green with it no-op'd.
* **The cheap half of the raise stays in the `ifhidden` arm.** Dropping it was the
  first cut and it was refuted by measurement: the restored viewer opens
  pixel-coincident *over* the design (issue **0647**), so "still mapped" left the
  schematic still invisible — the reported symptom with a new mechanism. A bare
  `raise` costs 0 unmaps and is an inert no-op on WSLg (issue 0054), so it cannot
  bring the vanish back.
* **Anything that is not literally `ifhidden` means `always`.** A typo must degrade
  to raising, never to silently disabling every raise in the program.

`raise_activate_toplevel` itself is **not** to be changed for this: 11 call sites, and
issue 0054 records that the user ratified raise-with-creep as the price of a working
WSLg raise. Fix the caller.

### Netlist and Run works from any level of the design (issue 0643, 2026-09-08)

**The old contract, and why it was wrong.** Pressed while the user was *descended*
into the design, the equality guard fired; `raise_design_editor`'s issue-0168 stack
loop matched the descended window and returned 1 **without ascending**; `do_run`'s
post-check re-tested the same equality, it was still true, and the run was refused —
`Status: Error`, red, `run_id` empty, no simulation, and the sentence *"ase: design
is not the current schematic; open it via Session > Design Window first"*, which
told the user to do the thing they had just done. That is exactly where the
OP-annotation *run → descend → press 6* workflow stands, and the user's report was
blunt: *"Where does this inane restriction come from? There is no such limitation in
Cadence's ADE-L, which we want be better than."* ADE-L parity is the standard.

**The contract now.**

| the design is… | what happens |
|---|---|
| the current schematic | netlisted in place, exactly as before |
| **anywhere on THIS window's hierarchy stack** | `ase::netlist` ascends to it, netlists, and puts the user back — **no refusal** |
| on another window's stack | `ase::ui::design_window` routes to that window (0616, unchanged), then as above |
| nowhere on this window's stack | **refused**, in new words |

* **The door asks reachability, not currency.** `ase::ui::do_run`
  (`src/ase_window.tcl:7228`) tests `[ase::stack_level $dpath] < 0` in place of the
  equality, in the pre-check and again in the post-routing re-check. `ifhidden` and
  the whole `raise_mode` table above are untouched; the new predicate makes the
  route fire **less often**, not in different places.
* **The walk belongs to `ase::netlist`, not to the door.** `ase::netlist`
  (`src/ase.tcl:6390`) gained a third arm over `ase::with_design_current`
  (`src/ase.tcl:6175`), which ascends with `xschem go_back 2`, evaluates the body
  with `uplevel #0`, and re-descends by replaying `ase::hier_instnames` through
  `xschem descend -fallback -inst`. A door that ascended would have to unwind on
  every error arm below it.
* **Why a round trip and not a relaxed guard.** `global_spice_netlist()` netlists
  `xctx->sch[xctx->currsch]` — the level you are standing on
  (`src/spice_netlist.c:359-373`). Simply dropping the guard would silently
  netlist and simulate the sub-block alone: measured, 4685 bytes of op-amp against
  the testbench's 14862, with a results file that looks healthy. The guard was a
  symptom; the fix is to make the design current for the duration.
* **It costs nothing the button was not already paying.** The trip is already made
  twice per press — `xschem netlist` (66 ms) and `op_annot::save_cards` (177 ms).
  The added walk measures **28–30 ms** over five two-level trips, one repaint, and
  the resulting deck is **byte-identical** (`cmp`) to one taken at the top.
* **The `~` safety doctrine is carried, not re-derived.** `go_back` calls
  `load_backup_as()` whenever a `<cell>~.sch` exists, ending in `set_modify(1)`.
  A clean entry buffer therefore has `autosave_backup` parked at 0 for the trip; a
  modified one with `autosave_backup` **on** is carried and restored afterwards
  with `xschem load_backup` (`descend` uses plain `load_schematic()` and would drop
  the edit); a modified one with `autosave_backup` **off** is **REFUSED** before
  anything moves, naming the cell and both remedies (issue 0626). The entry
  `readonly` state is snapshotted and restored too — `descend_readonly` is 1 in
  `cadence_style_rc`, and a restored buffer that no longer reports itself modified
  is one close-without-prompt from losing the edit again.
* **`Simulation > Run` (`ase::ui::do_run_existing`) needed no change at all** and
  got none: it never re-netlists, so it never needed a current-schematic guard.
  Confirmed by reading the whole chain and pinned as row R12.

**The surviving refusal — one minted head, two truthful tails (DECISIONS D6).**
The head is minted once, `ase::design_unreachable_msg {design {remedy {}}}`
(`src/ase.tcl:6139`) → *"ase: design `<X>` is not open in this window"*. The tail
is the caller's, because the two doors are reached from different places:

| door | tail | why it is true there |
|---|---|---|
| `ase::netlist` (`src/ase.tcl:6420`) | `; open it via Session > Design Window first` | a CIW or script caller has **not** tried that route |
| `ase::ui::do_run` (`src/ase_window.tcl:7307`) | `; Session > Design Window did not open it` | this arm runs **only after** `design_window ifhidden` has already tried and failed |

Forcing one sentence on both doors would make one of them lie. The *fact* is one
fact and is spelled in one place; only the remedy differs. The words *"is not the
current schematic"* are gone from both doors, asserted as an absence by rows R8 and
RT12.

Pinned by `test_ase_core` **RT0–RT12** (203 → 216, `--nogui` and `:99`) and
`test_ase_window`'s **R block** R1–R14 (32 → 49 headless, 245 → 267 on `:99`).
Both refusal tails are **unratified UI copy** and carry a `rule` debt on 0643.

### Window numbering

`notify_window_active`: CIW=1 (src/ciw.tcl:106), LibMgr=2
(library_manager.tcl:79), editors use `xschem get window_number`
(xschem.tcl:13724,13730). ASE toplevels register the same way with an
allocated number so Cadence-style window titles/activation logging hold
("ASE-L (N)").

### Subprocess + log streaming (execute infra)

Recon (2026-07-20):

- `execute` (src/xschem.tcl:352) opens a `|cmd` pipe, registers
  `execute_fileevent` (xschem.tcl:242) which reads 1024-byte chunks and
  **appends incrementally** to `execute(data,$id)`; on EOF sets
  `execute(status,$id)` / exitcode and (if `st==1`) shows the whole buffer
  once via static `viewdata` (xschem.tcl:11680). `execute_wait`
  (xschem.tcl:328) = vwait wrapper. So output IS available live in a Tcl
  var — only the display layer is EOF-batch today.
- **ASE live log**: `trace add variable execute(data,$id) write` → append
  delta into the ASE log text widget. No change to `execute` itself.
  (Fallback if trace granularity is awkward: ASE opens its own pipe +
  fileevent clone — 30 lines, still pure Tcl.)
- `sim()` schema (`set_sim_defaults`, xschem.tcl:2899-3044):
  `sim(TOOL,N,cmd|name|fg|st)`, `sim(TOOL,n)`, `sim(TOOL,default)`.
  Spice entries: 0 = interactive `$terminal` (the xterm dependency),
  1 = control-mode, **2 = batch `ngspice -b -r "$n.raw" "$N"`** — ASE uses
  the batch shape (with `-o` log) and never touches `$terminal`.
- Button status plumbing reusable: `simulate` (xschem.tcl:4011) +
  `set_simulate_button` (xschem.tcl:13633) orange/green/red via
  `execute(callback)`; ASE Run button mirrors the same pattern.
- Results: `ngspice::read_raw` / `read_raw_dataset`
  (src/ngspice_backannotate.tcl:64/:24) parse binary `.raw` op data into
  `ngspice_data(node)` — P5 plotting/annotation hook, already compatible
  with the `-r $n.raw` batch template.
- No existing live/tail log viewer anywhere (`textwindow` static too) —
  ASE's follow-viewer is new, self-contained widget code.

### Window numbering
TBD-AGENT-A2

## UI v2 — ADE-L parity rework (2026-07-21; supersedes the v1 sketch below)

User reviewed shipped v1 against a real ADE-L screenshot; functionality OK,
UI wrong. Contract below is authoritative. Known v1 BUG carried in: Session >
Design Window does not raise/open the schematic — fix in this rework.

### Window chrome
- Title: `Analog Sim Environment <design cell name>` (e.g.
  `Analog Sim Environment test_nfet_final`).
- Below the menubar: toolbar row with a numeric entry for **simulation
  temperature** (default 27) followed by label `°C`. Temperature emits
  `.temp <T>` in the deck (state key `temperature`, default 27).
- Bottom status bar: simulator name + state name (e.g.
  `Simulator: ngspice-ver50 | State: ngspice_state1`) + status
  (Ready/Running/…).
  - **The simulator segment names WHAT WILL RUN, not the kind of simulator**
    (issue **1370**, the user's own request). It is `ase::sim_label` and
    nothing else: the **registered name** in force — the very name "Use this
    one:" shows — falling back to the backend word when the user has
    registered nothing. It never names an entry nobody registered: a choice
    naming a missing entry shows the backend word, and the Simulators dialog's
    status line is what names the typo.
  - When that simulator **cannot start** — the program was deleted or lost its
    executable bit, the entry was registered for another kind of run, the
    choice names nothing, the state asks for a kind of simulator this program
    has no machinery for, **the entry answers for a backend that starts its own
    binary and reads no registry**, or nothing at all can be located — the name
    carries a marker (`Simulator: ngspice-ver50 — will not run`). A false name
    is worse than the backend word. *The marker's wording is a USER RULING
    still on the queue (issue 1370); the arms it applies to are not.*
  - The test is **four** terms, all four required: `ok`, a non-empty
    `resolved`, the backend being one `ase::backend_names` knows, and
    `ase::run_composes_registry` answering yes for it. The fourth was added by
    1370's repair and closes a latent false name — a generic entry
    (`-backend {}`) plus a second backend with its own hardcoded `run_cmd`
    passes the first three about a run that starts the other binary.
  - **A name is always printed.** With nothing registered and no backend word
    either, the segment says `(none) — will not run` — the spelling
    `ase::ui::simdlg_none_label` already uses — never the marker with a blank
    and a double space in front of it.
  - It follows the Simulators dialog **immediately**, in **every** open session
    window, because the registry is process-global while the dialog is
    per-session — `ase::ui::refresh_status_all`, called from the last line of
    `ase::ui::simdlg_fill`.
  - **And it follows the registry's other door too.** `ase::sim_register` /
    `ase::sim_select` / `ase::sim_unregister` / `ase::sim_clear` are reachable
    from the Command window (the pre-0937 path, and how this user's own entry
    was first created) and each fires `ase::sim_notify` — a single-slot,
    argument-less, `catch`-guarded seam that `ase_window.tcl` points at
    `ase::ui::refresh_status_all`, exactly as it points `ase::session_notify`
    at `ase::ui::session_changed`. Without it the bar went stale on that path
    until the run it was supposed to predict actually started (1370's repair).
- **The run says which registered simulator it is starting**, once, in the CIW
  and the action log (`ase::run_using_report`, mint kind `run_using`), and the
  run log carries it as a `using :` field beside `simulator :` and above
  `command :`. The say sits in `ase::run_deck` **below `ase::preflight_gate`
  and below the line that composes the command** — a run that is refused must
  never say it is starting (1370's repair; it first sat above both and said so
  for refusals that generated no deck, no raw and no log).
- **Brighter palette than stock Tk** (stock = #d9d9d9 grey). USER-LOCKED
  2026-07-21: ADE-like light grey/white — panels #f2f2f2, tables/entries
  white, header strips #e8e8e8, dark-red accent for pane titles.
- **Fonts**: named-font pattern from references/copy_current_cell_dialog.tcl —
  create once, apply to every widget: `AseLabelFont` Arial 10 bold (labels,
  table headers), `AseEntryFont` Arial 13 (entries, table rows, combos —
  incl. `option add *TCombobox*Listbox.font`), `AseMonoFont` Courier 13
  (netlist/log/preview text). No widget left on Tk defaults.

### Panes (ONLY these three; log pane REMOVED)
- **Design Variables** (left): columns Name, Value.
- **Analyses** (right top): columns Type, Enable (checkbox), Arguments
  (view-only). One row per chosen analysis, row-numbered.
  ⚠ **The Arguments column is THE LINE THE DECK WILL CARRY, not a summary of
  it.** It used to render the row's fields as a `key=value` dump — a dc row read
  `source=V2 start=0 stop=1.8 step=0.01`; it now reads `dc V2 0 1.8 0.01`,
  because `ase::ui::arg_summary` calls `ase::analysis_line`, the same proc
  `render_deck` emits. That is what makes it structurally impossible for this
  pane to show a setting the deck does not carry — the drift that let `ac`'s
  sweep-mode field be advertised in the pane, omitted from the dialog and
  hardwired in the deck, all at once. The `key=value` dump survives only as the
  fallback for a simulator backend that declares no analysis registry. A row
  that is not yet complete — the three empty rows every new bench opens with —
  renders blank rather than raising. See
  `doc/claude/ase_analyses_batch/PLAN.md` Stage 1.
- **Outputs** (right bottom): columns Name, Value, Plot (checkbox), Save
  (checkbox), Save Options. Value column USER-LOCKED 2026-07-21: filled
  after a successful run (op/scalar results evaluated per row), blank
  before the first run. Name shows the user-given name if named, else as
  much of the expression as fits. Save Options auto-displays `allv` (item is
  a voltage and blanket save-all-voltages is on) or `alli` (terminal current
  + save-all-currents on); blank otherwise.
- Interaction model (all panes): NO inline +/- buttons. Add via right-click
  context menu, menu bar, or action strip. **Double-click a row → edit
  dialog for that item.** Multi-select within ONE pane at a time; global
  Delete (action strip `X`) is noun-verb on the current selection.
- **Value display — engineering notation (2026-07-21, item 09):** the
  Variables and Outputs Value columns render numeric values in engineering
  notation (SPICE SI suffixes f p n u m k Meg G T, ~4 significant digits:
  `1.04e-4` → `104u`, `4.096837e-4` → `409.7u`); |v| ≥ 1e15 or nonzero
  < 1e-18 falls back to %g; non-numeric strings (expressions) verbatim.
  Display-only: state files and edit dialogs always carry raw values.
  Gated by the Tcl global `ase_eng_notation` (default 1; rc may preset 0
  to recover plain scientific display). Formatter: `ase::format_value`.

### Action strip (right vertical panel; text placeholders for now — real
icons welcome where Tk can do them, e.g. unicode ▶ ■)
- `OP,TR` → Choose Analyses dialog
- `=`     → Add Variable dialog (fields: name, value)
- `-->`   → Setup Outputs dialog (name optional + expression, or
            choose-from-design: raises/opens the schematic, user clicks
            wires → voltage / terminals → current; ESC ends)
- `X`     → Delete current selection (noun-verb, single-pane selections)
- `N&>`   → Netlist and Run
- `>`     → Run (existing netlist)
- `!`     → Stop
- `~`     → Plot waveforms (functionality deferred; button present)

**Select On Design v1 scope** (item 08; applies to the `-->` choose-from-
design flow and both Outputs > To Be Saved/Plotted > Select On Design):
a click on a wire, a net label or anything else that resolves to a net
queues the voltage output `v(<net>)`; a click on a SOURCE-class instance
(symbol `type` ∈ {vsource, ammeter}) queues the source-current output
`i(<instname>)` — a source has exactly one branch current, so instance-
level click granularity is exact for the supported class. Generated tokens
are lowercased (ngspice echoes `print` expressions lowercased and
result_probe matches the expr literally). Per-terminal currents of OTHER
devices are deferred: ngspice needs `.options savecurrents` plus
`@m.x<inst>.<subdev>[id]`-style names that depend on subcircuit internals
invisible to the schematic click. Clicks that resolve to neither report a
one-line notice and queue nothing. Queueing dedupes on the exact expression
string: an existing row gets the flavor's plot/save flags ORed in, an
identical re-queue writes nothing.

**Picking works from a DESCENDED schematic** (issue 0168). Run, descend into an
instance, and Direct Plot (Ctrl-4 or Results > Direct Plot) probes its internals:
the session is resolved by walking the hierarchy stack from the current level up
to the top and taking the NEAREST ancestor that owns one, so the parent's session
— the one that ran the simulation — is found even though the descended cell has
none of its own (`ase::session_for_current`). Queued names are measured from the
level of THAT session's design, so they match its deck: `v(x1.x2.mid)` under a
top-level session, `v(x2.mid)` under a session bound to the mid cell. Results >
Direct Plot also raises the window that is descended into the design instead of
re-opening the top elsewhere. Two limits ride along: the node must be in the raw
(Direct Plot deliberately writes no `.save` rows, so probe internals with no
explicit outputs or with Save-All-Voltages on). ⚠ **This paragraph used to end
*"and RUNNING is still top-only — `ase::netlist` requires the design to be the
current schematic, so ascend before Run"*. That has been false since issue
0643** (see *Netlist and Run works from any level of the design*, below): the
equality guard is gone and Netlist and Run works descended, through
`ase::with_design_current`. Corrected 2026-09-10 with issue 1401; the sentence
had outlived its own fix by two days in two places. `Tools > Launch ASE-L` is deliberately NOT hierarchy-aware: it binds a
session to the cellview actually on screen.

**A locked object is READ-able** (issue 0160). `lock=true` makes an object
unselectable, and since every edit acts on the selection, selection *is* the
lock — there is no lock check in `move.c`/`actions.c`/any delete path. A
read-only probe therefore resolves the net WITHOUT selecting: a click whose
`xschem select_at` comes back empty still goes through classification (the
`xschem flylines at` resolver already uses `override_lock=1`), and only ends
the click if that finds nothing too. So a locked wire queues its net normally
while staying unselected, and an empty-canvas miss-click stays silent. Do NOT
"fix" this by giving `select_at` an override-lock switch — that would make
locked objects deletable.

**Bus picks open a bit-selection dialog** (issue 0159). A net with more than
one bit is not one signal, and wrapping it whole produced an invalid vector —
`A[1:0]` → `v(a[1:0])` — which src/ase.tcl interpolates verbatim into the
deck's `.save`/`print` cards. Measured with ngspice-42: as the ONLY `.save`
in the deck that card aborts the entire analysis (`no data saved for
Transient analysis; analysis not run`); alongside any other valid `.save` it
is silently dropped and the trace simply never appears.

So a click resolving to a multi-bit net (bracket range or comma list) opens
**Select Bus Bits**, listing the bits in `xschem expandlabel` order —
MSB-first for a descending range. Contract:
- **nothing is selected when it opens**, so OK with an empty selection is a
  no-op, the same as Cancel;
- **All** selects every bit; **Ctrl-click** toggles one (Tk `extended`
  selectmode, which also gives Shift-click ranges);
- **Reverse** flips the *displayed* order and carries the selection with the
  items — the display order IS the order the bits are queued in, which is
  what makes the button meaningful;
- **OK** queues one row per selected bit, in display order; **Cancel**
  queues nothing.

It applies to BOTH pick paths — Direct Plot and the persisted Outputs list —
since both wrote the same broken expr. In Direct Plot the 0153 schematic
colour cue is painted ONCE, in the first bit's colour: the bus is a single
wire, so N cues would just repaint it and end on the last bit's colour.

Saved states from before this carry a `v(a[1:0])` row; `ase::state_load`
expands it per bit on load. That migration is restricted to the **bracket**
form on purpose — a stored expr is opaque, and `v(a,b)` is also ngspice's
differential voltage, which a user can legitimately have typed into the
Add-Output dialog. The comma form is left alone, which costs nothing:
`.save v(d,e)` does not abort a run (measured). A comma bus picked on the
*schematic* still splits, because there the token is known to be a net.

**A pick while DESCENDED is hierarchy-qualified** (issue 0161). Picking is
allowed at any depth — and so, since issue 0643, is the **run**. ⚠ This
sentence used to read *"only the RUN is top-only (`ase::netlist` compares
`xschem get schname` against the design path …)"*; that comparison is the guard
0643 removed, and the claim was stale. Corrected 2026-09-10 with issue 1401. The queued expression
is always **top-relative**, so a pick made while descended stays correct
after ascending to run.

The qualification happens in `ase::ui::sod_qualify`, called from `sod_click`
per picked bit; `ase::ui::sod_expr` stays a PURE string wrap (it is called
with no design loaded). At `currsch == 0` it is the identity, so every
top-level expression is unchanged byte for byte. Voltages go through
`xschem resolved_net` rather than a path string-prefix, because a port
resolves UP to the parent's net (`A` → `TOPNET`), a dangling port stops at
the level that names it (`B` → `x1.net1`), and a global stays flat
(`0` → `0`) — none of which a prefix can express. Currents mirror
`send_current_to_graph()`: `i(v.<path>.<name>)` descended, `i(<name>)` at
the top, which is how ngspice names a nested branch (`v.x1.x2.v1#branch`).
The 0153 colour cue keeps the RAW schematic token — `hilight_netname` wants
the schematic's name, not the simulator's.

### Menu tree (v2)
- **Launch** — placeholder menu, ignore for now.
- **Session** — Design Window (raise-or-open the attached schematic window —
  FIX the v1 bug); Load State (library browser like Create Instance,
  filtered to simulation-state views, **opening defaulted to the session's
  own Library and Cell** — the states worth loading are nearly always the
  other states of the cell being simulated, so the View column is the only
  pick left; the View itself is left unselected on purpose, since a default
  pick would put "discard this session for a state nobody chose" one OK
  press away. Focus lands on the View list so no mouse trip is needed —
  though Tk's listbox moves `active` before selecting, so the first Down
  lands on the SECOND view and Home reaches the first. Degrades one column
  at a time: an unknown library leaves the browser as it was before the
  defaulting, a known library with an unknown cell keeps the library chosen
  and its Cell column filled); Save State (always Save-As: Library
  dropdown + editable Cell/View text fields prefilled with current; OK
  **confirms before it overwrites an existing state**, title `Overwrite
  State`, and the two reasons are answered by two mutually-exclusive
  predicates, never one flag with two meanings —
  `ase::ui::save_as_needs_confirm` (D8: the target IS my own file **and** that
  file is effectively read-only — `readonly` attr, or unwritable) says *"The
  state `<lib>/<cell>/<view>` was opened read-only. / Overwrite it?"*, and
  `ase::ui::save_as_overwrites_other` (the target EXISTS and is **not** my own
  file) says *"State `<lib>/<cell>/<view>` exists. Overwrite?"*. Both sentences
  are minted in the `ase::ui::lbl_*` family (`src/ase_window.tcl:5578`), not
  typed at the call site. Saving onto your own state is silent — that is what
  Save means; a target that does not exist is not an overwrite and is created
  silently (D9). An **untitled** session owns no file, so every existing target
  is somebody else's and every one of them asks. Cancel writes nothing.);
  Close.
- **Setup** — Design (L/C/V dropdown dialog; after Cell chosen, View
  dropdown lists ONLY schematic views); Model Files (dialog: one row per
  model file + corner/section entry per row, e.g. `tt`); Simulators…
  (the simulator-registry dialog, issue 0937: the registered simulators with
  the reason any one of them cannot be started, Add / Edit / Remove, and
  which one is in force — or none of them, which means the program the
  system finds on the PATH).
- **Analyses** — Choose… (Choose Analyses dialog).
- **Variables** — Edit… (variables editor).
- **Outputs** — To Be Saved > Select On Design; To Be Plotted > Select On
  Design; Save All… (dialog: save all voltages?, all terminal currents?,
  levels, etc. — ngspice mapping v1: allv → `.save all`, alli →
  `.options savecurrents`).
- **Simulation** — Netlist > Recreate; Netlist > Display; Netlist and Run;
  Run (uses EXISTING netlist — supports hand-edited decks); Stop; Log
  (reopen log window); Options… (simulator-specific options dialog,
  minimal for now).
- **Results** — Direct Plot (**LIVE since item 13**: command mode, click
  signals on schematic, queue, ESC → plot); Annotate > Operating Point info
  and Annotate > DC Node Voltages (**LIVE since issue 0682**, and this menu is
  now the ONLY annotation visibility control in the program — the user reversed
  0457(b)'s `View > Show / Hide` placement on a real sky130 bench: "We want to
  be like Cadence. It needs to ONLY be in ASE-L > Results > Annotate >
  Operating Point Info"). Two **checkbuttons** over the two `annot_show` bits,
  session-keyed, **greyed by `ase::has_results`** — an entry is live only while
  this session has a raw on disk, because "results only make sense when there is
  a result loaded". The submenu carries a `-postcommand` PULL (the three cadence
  chords and both `Annotate Operating Point` menu items write the mask without
  telling any menu), the PUSH reaches the design through a **verified**
  `new_schematic switch` (landmine 17 — a blind one lands the mask in a foreign
  schematic), and ticking a bit ON attaches the session's raw when the design
  context has none — **but that last arm is measured wrong and is filed as issue
  0684**: it guards on `xschem raw loaded`, so a second run's numbers never reach
  the screen and an unrelated waveform-graph raw blocks it silently. See
  `doc/claude/issues/0682-*.md` and `0684-*.md`.
- **Tools** — Waveform Viewer (raise-or-open THE waveform viewer bound to
  this ASE-L session — `wviewer::open` is per-token idempotent, so a session
  never gets two viewer windows; same seam as the `~` strip button);
  Calculator (**LIVE since the calculator batch's item 13** — `calc::open`,
  with no session key: the Calculator is per-PROCESS idempotent, one window per
  xschem, `doc/claude/specs/calculator.md` R101. It was a disabled placeholder
  only until the window existed).

### Log window (not a pane)
Kicking off a run opens a NEW toplevel showing the live log (existing
live-follow machinery from v1 moves here). Ctrl-W closes it;
Simulation > Log reopens on the current log file.

### Choose Analyses dialog
Two vertical sections: top = analysis types with radio buttons (selects
which analysis the bottom shows); bottom = per-analysis form: Enable
checkbox + quick fields (e.g. DC: source/start/stop/step; TRAN:
step/stop; AC: points/start/stop) + an Options button for nuanced options.

### Dialog style
All dialogs follow references/copy_current_cell_dialog.tcl idioms: named
fonts, ttk::combobox with type-to-filter where a library/cell list appears,
Return = proceed, per-window state arrays cleaned on destroy. Every dialog
dismisses on ESC through the same cancel path as its Cancel button; the ASE
main window and the log window are exempt (2026-07-21, item 10).

## UI sketch v1 (single toplevel per session, Tk) — SUPERSEDED, kept for history

```
+--------------------------------------------------------------+
| ASE-L (3) — sky130_tests/test_nfet_final  [ngspice_state1]   |
| Session  Setup  Analyses  Variables  Outputs  Simulation  ...|
+----------------------+---------------------------------------+
| Design Variables     |  Analyses                             |
|  name     value      |   type  enabled  args                 |
|  Vgs      1.8        |   op    yes                           |
|  Vds      1.0        |   dc    no      V2 0 1.8 0.01         |
+----------------------+---------------------------------------+
| Outputs              |  Model libs: sky130.lib.spice tt      |
|  id  -i(v1)  save    |  Rundir: <netlist_dir>                |
+----------------------+---------------------------------------+
| [Netlist] [Run] [Stop]   status: idle|running|ok|fail        |
+--------------------------------------------------------------+
```

- Session menu: Save State / Load State / Design Window (raise or open the
  schematic cellview via existing load routing) / Close.
  - **Untitled adopt (issue 0141).** A Launch-ASE session is *untitled* (no
    file, title `… (unsaved) *` once edited). Its **first** successful Save State
    ADOPTS the target as the session's real identity (`ase::session_adopt`):
    path set, `saved <- state` so the dirty ` *` clears, the `untitled` attr
    dropped so `(unsaved)` disappears, and the status `State:` shows the saved
    view. Gated on the untitled marker (`own eq {}`), so a **titled** session
    saving-as to a *different* existing view deliberately stays dirty (item 14
    D5) and the own-view save is unchanged. The session key is NOT re-homed
    (opaque handle; ~91 build() bindings bake it in) — see issue 0141.
  - **⚠ D13 is RETIRED — the user overruled it on 2026-09-09.** D13 read
    *"overwriting a DIFFERENT existing view needs NO confirm in v1 — the spec's
    only confirm trigger is read-only + same-target"*, and it shipped: measured
    that day with session `ngspice_state1` open and the sibling view
    `debug_st1` present and writable, `ase::ui::save_as_needs_confirm` answered
    **0** for `debug_st1`, so typing an existing sibling view into the Save-As
    form destroyed it with no warning. The user's ruling was *"Just confirm if
    overwriting an existing state"*; **undo was explicitly not asked for**, a
    confirm was. `save_as_needs_confirm` keeps its D8 contract unchanged (five
    pinned rows, `tests/headless/test_ase_dialogs.tcl` section H2); the new
    case is the separate predicate `ase::ui::save_as_overwrites_other`
    (`src/ase_window.tcl:6471`). D13's *other* half — that a titled save-as to
    a different view writes through plain `ase::state_save` and stays dirty —
    is unchanged. Decisions S-1…S-9,
    `doc/claude/ase_l_ux_batch/DECISIONS.md`.
- Simulation menu: Netlist, Run, Stop, View Netlist, View Log.
- Netlist/log viewers: read-only text windows; log follows live output.
- Double-click `ngspice_state1` view in LibMgr → opens ASE-L on that state.

## Phases

- **P1 — state + backend core (headless-testable).** `src/ase.tcl`:
  state load/save round-trip, deck render, subprocess run via `execute`,
  log capture to file. Headless tests drive `ase::*` procs directly.
- **P2 — view type + LibMgr dispatch.** `ngspice_state1` view enumerated,
  resolvable, double-click opens ASE-L; view creation hook (LibMgr context
  menu "New ngspice state view" + Save-As form option).
- **P3 — ASE-L window.** Panes, menus, window number, Design Window raise,
  netlist/log viewers, run/stop with button status.
- **P4 — de-clutter proof.** Create `sky130_tests/test_nfet_final`
  (schematic = M1 + V1 + V2 + gnd + labels ONLY) + `ngspice_state1` view
  reproducing Id ≈ 409.7 µA through ASE-L end-to-end; headless regression
  test in tests/headless/ + registered in run_regression.tcl.
- **P5 (deferred) — results.** Plot outputs via create_graph/gaw; op
  back-annotation onto schematic via ngspice_backannotate.tcl.

## Testing

- Headless: state round-trip; deck render golden; run ngspice batch, assert
  `-i(v1) = 4.096e-04`-class result parsed from log; view resolution via
  `cellview_path`; LibMgr smoke extension.
- Sabotage-verify each headless test (green-but-hollow discipline).
- GUI: scripted Tk walk (open state → edit variable → run → log shows Id;
  Design Window raises schematic window).

## Risks / open questions

- `cellview_path` may filter unknown view types in C (agent recon pending) —
  if so, minimal C touch in the resolver, keep dispatch in Tcl.
- Live log streaming depends on `execute` exposing incremental pipe reads —
  if it buffers to completion, add a fileevent-based `ase::run` variant
  instead of touching `execute`.
- Windows (`__unix__` guards): subprocess + fileevent path must not regress
  the Windows build; v1 may gate live-follow on unix and fall back to
  on-completion load.
- Concurrent sessions: one ASE toplevel per state view; state file collisions
  guarded by LibMgr git checkout discipline (no extra locking in v1).
