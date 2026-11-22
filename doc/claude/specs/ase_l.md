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

## The analyses subsystem (batch Stages 1–6, 2026-09)

`doc/claude/ase_analyses_batch/` is the plan; this section is what has actually
shipped and is the part a reader should trust. Stages 1–6 are landed; 7–16 are
still a plan. Every claim below was measured on **two** ngspice binaries —
`/usr/bin/ngspice` (apt, 45.2) and the fork
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (46+) — because a fact that
holds only on the developer's build is not a fact about the feature.

### The one architectural rule: ASE-L owns the SCHEMA, an adapter owns the CONTENT

Recorded as **D34–D37**, and it is the rule every later decision is measured
against. A core `ase::` proc may know that an analysis type has plots, that a
plot has a `select` pattern and a `role`, and that a precondition has a tier. It
may not know a single ngspice sentence. Everything simulator-specific lives in
`ase::backend::<name>` and reaches the core only through a registry entry or a
named hook.

Two consequences worth stating because they are easy to erode:

* **A backend with no hook gets NO fallback content.** Not a default, not a
  best guess, not ngspice's answer borrowed. A missing hook is a missing
  capability, and the surface says so.
* **Capabilities are PROBED, never inferred from a version string.** Issue 0948
  is the machinery; the rule is in `no-guessing-simulator-capabilities` terms —
  offer a feature only where the simulator itself declares support.

### The registry, and the eleven types

`op`, `dc`, `ac`, `tran`, `noise`, `tf`, `pz`, `sens`, `disto`, `pss`, `sp`.
Each carries a label, a card template, its form fields, its `needs` list, its
`plots` list, an emit order and a view rank.

⚠ **`op` is emitted LAST** among the analyses that produce a plot the reader
walks back to (issue 0964), and **a `sim_status` guard AND a `remzerovec` follow
EVERY analysis**. Those three placements are load-bearing and are asserted by
name in `test_ase_core.tcl` (rows WK7, CK15, CK21) precisely so that a tidy-up
reddens a row rather than shipping.

**Only four types are seeded.** `ase::state_default` produces exactly `op`,
`dc`, `ac` and `tran`, and all **104** committed `.state` files carry those four
and nothing else. Discoverability of the other seven is the four-state grid's
job, not the state file's: the grid shows all eleven whether or not the file
mentions them. (⚖ R4 is the ruling that makes this a decision rather than an
accident.)

**The schema refuses rather than guesses.** `ase::analysis_schema_errors` is the
gate, and its vocabulary is the list of ways a registry entry can be wrong:
`nocard`, `noslotfield`, `fieldunused`, `baddepends`, `noplots`,
`noplotselect`, `noplotrole`, `noplotresults`, `badplotroute`, `badplotwhen`,
`badplotwhenfield`, `badplotwhenhook`, `badsalvage`, `nosalvagepoints`,
`badsalvagepoints`, `nosalvagevector`, `badresultvecs`. An entry that trips any
of them does not render a deck — it is reported.

### Preconditions: what will be wrong, said BEFORE the run

Stage 4's subject. `ase::netlist_facts` reads the SPICE netlist **xschem itself
emits**; `ase::analysis_needs` and `ase::analysis_precheck` evaluate the
schema's `needs` vocabulary over those facts. The vocabulary is twenty ids:
`ac_source`, `cider_klu`, `disto_f1src`, `disto_f2src`, `disto_saves`,
`noise_insrc`, `noise_klu`, `noise_out`, `pz_devices`, `pz_klu`, `pz_nodes`,
`pz_shorted`, `saves_resolve`, `sens_filters`, `sens_klu`, `sens_out`,
`sweep_target`, `tf_insrc`, `tf_out`, `vecsaves`.

**Three tiers, and the tier is the decision — not the detection.** `fatal`
refuses the run; `caution` advises and lets it proceed; silence means nothing is
known to be wrong. The evaluator is ASE-L's; each *reason* is the adapter's
sentence.

⚠ **`netlist_facts` answers `exact 0`.** A hierarchical node inside an
`.include`d subcircuit is unresolvable here and perfectly resolvable in ngspice.
That blind spot is why `saves_resolve` is `caution` and not `fatal`: **a false
refusal is worse than a missed one**, and the only precondition that pays the
false-refusal risk anyway is `disto_saves`, because the alternative there is a
SIGSEGV that leaves no log to read.

### The writer: one results file, many plots, and a sidecar that says which is which

Stage 6's subject, and the least obvious part of the system.

ngspice writes every plot into one rawfile, and `write` emits **the current
plot**. An analysis that produces several plots therefore needs the deck to walk
`setplot previous` back to each one. `render_deck` emits that walk, and emits

```
echo "PLOT <type> <idx> |$curplotname|" >> <cell>_ase.plotmap
```

per `write`, so the mapping from an analysis row to a plot in the file is
**recorded by the run itself** rather than reconstructed afterwards.

⚠ **THE WALK LENGTH COMES FROM `ase::analysis_captures`, NOT `analysis_plots`,
AND AN OVER-WALK IS SILENT.** Walking too far saturates on ngspice's built-in
`constants` plot and appends twelve mathematical constants at rc 0, with every
count agreeing and only a stderr warning — which is nowhere anything in this
tree looks. Row **WK8** of `test_ase_core.tcl` is the production guard and is
written without a stub for exactly that reason.

`ase::reconcile_plots` is the post-run safety net: it compares what the registry
predicted against what the file actually holds and names the disagreement
(`mislabel`, and its siblings) rather than letting a wrong number reach the
Value column. A sidecar record is compared with the results file **position by
position** (the record sits immediately above its `write`) and with the registry
**by the row it carries** — the first record of a row with the first plot that
row declares — so the order the deck runs the rows in does not matter **to the
reconciliation**. It does vary: a deck that asks for the per-device
operating-point numbers inside `.control` runs the operating point last (issue
0964), and while the registry leg compared in a fixed operating-point-first
order every such run was told its rows had recorded each other's plots (issue
1657).

⚠ **A reader that picks a plot by its TYPE, asked for `op`, is given the
operating point wherever the deck wrote it.** The engine's raw reader
(`read_dataset()` in `src/save.c`, behind `xschem raw read <file> op`, `xschem
annotate_op`, `ase::attach_dbs <file> op` and the Calculator's operating-point
read) takes, in file order, the plots whose name reads as the type asked for,
and two of ngspice's plot names read as `op`: the operating point's and
`Integrated Noise`, the totals of a noise row. A caller that ASKS for `op` is
given the `Operating Point` plot; the totals answer `op` only when the file
holds no operating point, so a noise-only run still annotates its totals.
**Measured** 2026-11-20 on apt 45.2 and on a copy of `ver_53`, an `op` and a
`noise` row with device requests held: the file is written `Integrated Noise`,
`Noise Spectral Density Curves`, `Operating Point`; the reader asked for `op`
lists the node voltages, the annotation publishes them and an Outputs row
`vdc(out)*2` evaluates, exactly as with the operating point first. Until that
rule (issue 1657) the totals won by standing first: no node voltage was
annotated and such a row could not be evaluated. What the rule leaves alone: a
read that names no type takes the type of the file's first plot, and a read
asking for `noise` is given whichever noise plot stands first, which in this
deck's files is the totals and not the spectrum. Band M of
`tests/headless/test_raw_ascii_point_bounds.tcl`. **Where the totals are still
what such a caller is shown**, each case measured and each in issue 1657's
list: a results file whose blocks are ascii with CRLF line ends and whose totals
stand first, because the reader cannot step over such a block (issue 0300; this
deck writes binary blocks, which it steps over whatever the line ends); and a
table of the file that is already loaded under `op` because a read that named no
type stored the totals there, when the reader asks for NO read. The registry
switches to a table it holds instead of reading the file, and until 2026-11-22
such a table answered `xschem raw read <file> op` and (unless it was the current
one) `xschem annotate_op <file>` with the totals. It is now marked when it is
stored (`xschem raw totals_as_op`), and a request whose own words name `op` --
those two verbs, `xschem raw select <file> op`, the annotate chord of the
Cadence profile, the Calculator's `vdc()` -- reads the file again, in the same
slot, and is given the operating point (the user's ruling of 2026-11-21; issue
1657). What still shows the marked table as it stands, because nothing is
read: `xschem raw switch`, `xschem raw switch_back`, a select that names no
type, `results::select` with no type, and a graph that loads its own file.
`ase::attach_dbs <file> op` and the Calculator's read through
`calc::eval_texts` were given the operating point all along.

⚠ **`opinfo` plots are predicted and DECLINED.** `src/save.c`'s `read_dataset()`
matches `strstr(lowerline,"operating point")` **above** its AC arm, so `AC
Operating Point`, `Distortion Operating Point` and `NOISE Operating Point` all
read back as a plain `op`. Capturing one would make Annotate Operating Point
publish the wrong numbers, so the registry marks them and the walk skips them.

### Where one output row's number comes from (⚖ R3, ANSWERED 2026-09-12; log half SUPERSEDED 2026-10-11)

As answered on 2026-09-12, both readers shipped and one proc stated the rule:

> **a row whose expression names exactly one vector reads the results file;
> anything else reads the `print` log.**

⚠ **The log half is gone** (next section): the deck carries no `print` line,
and "anything else" is now **evaluated by the Calculator on the results file**.
`ase::result_source` still draws the line and is still the single place it
lives; the rule is still **stated on screen**, once per run. Issue **1243**'s
substance — the Value column is a scalar column and shows the operating point
when the run has one — is kept by R-OUT4 below rather than by a print anchor.

### Outputs are computed after the run, never in the netlist (ruling 2026-10-11)

The user, verbatim: *"Why would expressions in the outputs pane of ASE-L go to
the netlist? They are computations made using the result of the simulation!
They should not influence the input to the simulator."* ADE-L is the floor
(`doc/claude/code_analysis/ade_parity_gaps_2026_10_11.md`).

- **R-OUT1 — nothing derived from an output expression enters the deck.**
  `render_deck` emits no `print` line for any output, in any analysis shape (it
  used to place one per ticked row at the operating point, issues 0967/1243).
  `ase::backend::ngspice::print_arg` and `result_probe_log` are deleted. Rows:
  `test_ase_outputs_eval` OE1/OE5, `test_ase_optier_0963` P1–P4/E17,
  `test_ase_core` WK4/D1, `test_ase_meas_1443` DK2/DK2c.
- **R-OUT2 — every row is answered from the run's results file.** The
  registered `result_probe` hook (`ase::backend::ngspice::result_probe`) sends a
  row naming one vector (`ase::result_source` = `raw`) to `result_probe_raw`,
  which reads its single-point value exactly as before, and every other row to
  `result_probe_calc`, which evaluates the text — postfix or infix — with **`calc::eval_texts`** —
  the Calculator's pure evaluator (calculator.md R609): no window, no buffer, no
  viewer, the raw registry put back byte-identical. The same hook runs on run
  finish (`ase::run_done` → `ase::ui::run_finished`), on window open and on
  Load State (`ase::ui::results_from_disk` / `results_refill`), so all three
  re-evaluate. The log is never read for a value. A loaded slot of the same
  results file (OP annotation, the Calculator) is never read in the new run's
  place: R609 reads the file on disk (`calc::et_alias`), so the plain and the
  expression rows of one Value column always show one run. Rows: OE3, OE5, OE8;
  `test_ase_core` P1, RS1–RS4b, RD10–RD14; `test_ase_result_case` NCR1–NCR3.
- **R-OUT3 — the save list is the only netlist effect.** `ase::output_save_cards`
  is the one body: every Save-ticked **plain** row (ONE signal, optionally
  negated: a wrapper call with no nested parenthesis such as `v(out)`/`v(a,b)`,
  a device parameter `@m1[gm]`, or a bare vector name, and not a measurement
  call — `ase::output_is_plain` / `ase::output_is_signal`) emits `.save
  <signal>` exactly as before (R208c qualifiers and Cadence quotes stripped,
  `ase::output_signal`); **then, only if those narrowed the deck**, every signal
  any expression row reads (`calc::eval_text_signals`), ticked or not, each
  once — and only a read that is itself one signal, out of a text the Calculator
  accepts before any read (`calc::et_check`): a text it refuses (`v(a) v(b)`,
  `foo(v(a))`, `cross(v(a), 0.5)`) makes no card at all. An expression's tick never narrows a deck: a bench whose only ticked
  rows are expressions gets no card and ngspice keeps everything.
  `ase::saves_narrowed` reads the same body. **Measured 2026-10-11** on the
  registry's ngspice-46+ (`build-ver_50`), a divider with `op` + `tran` and an
  explicit `write`: no `.save` → every plot holds every node voltage and source
  current; `.save v(out)` → the operating point holds **v(out) alone** and the
  transient **time + v(out)** — ANY `.save` keeps only what is listed;
  `.save v(out)` + `.save v(mid)` → those two; `.save all` + `.save v(out)` →
  everything. ⚖ **Superseded by R-OUT8 (2026-10-13): every deck with a card now
  carries `.save all`, so nothing below narrows any more.** ASE-L emitted `.save all` only for the Save-All-Voltages tick, a
  6g-1 widening, the 6g-3 phantom guard, or the operating-point tier's own
  leader (guard G-LEADER, issue 0964: `op_annot::save_cards` puts `.save all`
  above its device cards whenever its block is non-empty), so a default bench
  with one ticked row and no device cards IS narrowed — which is why the
  expressions' signals ride along. `.save
  -i(v1)` is accepted and saves `i(v1)` (measured), so a negated row's card
  stays verbatim. Rows: OE1, OE2, OE7.
  ⚖ **Since issue 1724 (2026-11-19) one signal is never a card: a terminal
  current**, `i(<path>:<tname>)`, as a plain row's own signal or as a read of
  an expression. `ase::output_card_sources` skips it in both roles and the
  deck carries a `.probe` term for it instead — R-OUT17.
  ⚖ **And an expression's read of a name holding `=`, `'`, `{` or `}` makes no
  card** (issue 1724, 2026-11-19), whatever its shape: a node, a
  terminal-shaped current, a device parameter (`@m1[g=m]`). **Measured
  2026-11-19** on the fork's `ver_53` build and on apt 45.2, with hand-written
  decks: a `.save` of a name holding an equals sign, a single quote or an
  opening brace stops the simulator with a netlist error before any analysis
  (exit 1, no results file); a closing brace is harmless and leaves with the
  opening one. One such read in one expression row therefore cost a narrowed
  bench its whole run. With no card the run goes on and the row's Value says
  what it says for any read the results lack (*"Cannot evaluate: unknown token
  'vdc(a=b)' (not an operator/function, number or raw variable)."*). A read of
  a name holding `;` or `$` keeps its card: both were measured harmless on a
  `.save` card. Only the `read` role is held to this: a Save-ticked plain row
  of such a name is still a card, and the pre-flight refuses it by name before
  the run (R-OUT3a). Rows PX7, PR11d, PN12 and PN12b of
  `tests/headless/test_ase_probe_deck_1724.tcl`.
  ⚠ **An ngspice INFIX row is an expression, not a plain signal (fix round
  2026-10-11).** `Vcc/I(Vr)` is one whitespace-free token, and the first cut
  emitted it as `.save Vcc/I(Vr)`. Measured on the same ngspice: `.save
  out/i(v1)` keeps **only `i(v1)`** (the infix half silently dropped) and `.save
  (in-out)/i(v1)` keeps **everything** (the card is ignored). Either way the
  text was in the deck, contradicting R-OUT1. Nine committed bench rows have
  this shape (`dc_ntap1`, `dc_ptap1`, `dc_res_temp`, `iso_dc_res`, and one
  nested `db(i(vd)/i(vg))`). Since the Calculator reads infix (calculator.md
  R610) each is an expression whose READS are cards (`Vcc`, `I(Vr)`), its text
  never one, and its Value is a number again — **equal to what the former
  `print` path gave**, measured on the registry ngspice for every one of them
  on a synthetic circuit built from the row's own reads with its bench's own
  analyses (row OE13; the benches themselves need PDK models this machine does
  not have). Row OE11 derives the card shape over every committed `.state` file.
- **R-OUT3a — the pre-flight checks the plain cards and nothing else; an
  output EXPRESSION can never block or refuse a run.**
  `ase::preflight_scan`, which `ase::preflight_gate` reads, walks
  `ase::output_card_sources` — the same body as the deck's cards, each with the
  row it came from and its role, `plain` or `read` — and checks the **plain**
  cards only (a ticked plain row's signal; a ticked `vt(x)` is checked as
  `v(x)`). An expression, ticked or not, is a computation on the results: the
  signals it reads still become `read` cards on a narrowed deck (all but a
  read whose name holds `=`, `'` or a brace, which makes no card: R-OUT3), but
  they are **not** checked, and one the circuit lacks is reported in that
  row's Value after the run. Fix round 2026-10-11: an UNTICKED expression's absent signal
  used to be checked once the deck was narrowed, and refused the whole
  simulation. **Measured 2026-10-11** on the registry's ngspice-46+: `.save
  v(out)` + `.save v(nosuch)` (likewise `i(vnosuch)` or a bare `nosuch`) runs at
  rc 0 and writes `v(out)` alone, in the operating point and the transient both
  — so an absent read card is left in the deck, harmless. ⚠ Declared: on the
  apt ngspice whose lone-op save grows a phantom `i(all)`, an absent read card
  makes R-OUT3b count two cards where one vector exists, so the `.save all`
  leader is not emitted for it. The repair offer still rewrites the row's own
  text. Row OE9. **No output text raises** either (third fix round,
  2026-10-11): an unticked `v(out)*09` (Tcl's octal `09`) or a 400-deep
  nesting used to raise out of the deck render and the scan, so the simulator
  never started; both are now ordinary texts (calculator.md R610). Row OE14.
  A **terminal-current row** is not among the cards (R-OUT3, R-OUT17), so the
  pre-flight does not see it: the netlist map it checks against holds no
  terminal, and a ticked `i(x1.xm1:d)` used to be refused as *"names something
  this circuit does not have"*. A mistyped terminal is therefore reported
  after the run (R-OUT17), not before it. One exception: a name holding a `;`,
  a `$`, an `=`, a `'` or a brace is not a terminal (R-OUT17's predicate), so
  with Save ticked it is a `.save` card again and the pre-flight refuses it
  before the run.
- **R-OUT3b — the op phantom guard counts the deck's vectors.**
  `ase::saves_op_phantom_risk` asks whether `ase::output_save_cards` holds
  exactly one card, not whether one row is ticked: a ticked plain row plus a
  ticked expression reading the same signal is ONE vector (the risk), a ticked
  plain row plus an unticked expression reading another is TWO (no `.save all`
  leader needed). Row OE10.
- **R-OUT4 — what a row reads.** A plain signal with a single-point value shows
  the operating point, the number `print` used to give: **measured equal on a
  real run** (OE7) — a voltage string for string (`%.6e`), a current to the
  print's own precision (ngspice prints a current with one digit fewer,
  `-3.33333e-04` beside the file's `-3.333333e-04`). ⚠ **Since R-OUT4a (2026-10-12) an
  expression that reads an unqualified signal is refused** — the default below now governs
  only a text reading no unqualified signal (a device parameter, the sweep scale) and the
  plain signal rows ASE-L hands over qualified. An unqualified expression
  reads the operating point when the run has one; otherwise, and always for an
  unqualified **measurement call**, the run's ONE analysis besides the
  operating point — and when the run has two or more (op+AC+tran) the row is
  **refused** with *"Cannot evaluate: this result has TRAN and AC; write
  vt(...) or vf(...)"* instead of guessing (calculator.md R609; it used to read
  the first and showed an AC frequency for a `cross` meant for the transient);
  `vt()`/`vf()`/`vdc()`/`vs()` read their own (R208c). **A run with no
  operating point** shows `wave` for a plain signal (it was blank under the
  prints) and still answers measurements. The expression field speaks the
  Calculator's language: postfix, measurement calls, and — since R610 — ADE-L's
  **infix** (`Vcc/I(Vr)`, `db(i(vd)/i(vg))`, `bandwidth(vf(out),3,magnitude,
  low,0)*2`). The negated single signal (`-i(v1)`) is still handed over as
  `i(v1) -1 *` (`ase::output_calc_text`), the same postfix the translator
  gives it. Names match as the Calculator matches them (its own
  case-folding, refusing an ambiguous one); the casemode ladder still governs
  the single-vector reader.
- **R-OUT4a — an unqualified EXPRESSION is refused; a SIGNAL row is not (2026-10-12).** The
  user: *"in Cadence ADE, there is no such thing as v(signal_name). It always has to be VT,
  VF, etc. … For now, in ASE-L, v(something) will be meaningless. … If it's obvious the user
  means operating point, just convert v(blah) to vdc(blah)."* So an Outputs **expression**
  (anything `ase::output_is_plain` is not: infix, postfix, a measurement call) that reads
  `v()`, `i()` or a bare node with no analysis of its own shows the Calculator's refusal in
  its Value cell, offering the spellings this run holds — *"Cannot evaluate: v(out) names no
  analysis; write vt(out) or vdc(out)"* (calculator.md R208d). It is never read at the
  operating point by default any more. Its reads still ride as save cards (R-OUT3), so the run
  keeps what the row names.
  - **A plain SIGNAL row keeps R-OUT4's reading, by decision.** One name, optionally negated
    (`v(out)`, `out`, `-i(v1)`, `vdc(out)`), is ADE-L's *signal* output — a name to save and
    plot, which ADE-L shows as a wave or a value without an analysis call around it — not an
    expression. It still saves (`.save <signal>`), still plots (the waveform viewer keeps plain
    `v()`, and a qualified row is plotted as the raw's own name **only when it is qualified for
    the analysis the viewer shows**: a row qualified for another one — `vf(g)` or
    `db(if(vd)/if(vg))` on a run whose viewer shows the transient — is refused at auto-plot with
    *"ase: cannot auto-plot 'vf(g)': Cannot plot vf(): the waveform viewer shows transient"*,
    never drawn from the shown analysis's columns (`ase::ui::plot_row_refusal`, row OE18; an
    infix row reaches the viewer as the Calculator's postfix), and its Value is still the
    single-point (operating-point) number, or `wave` when the run has none: the
    single-vector reader is unchanged, and a row the Calculator answers is handed over
    **qualified by R-OUT4's own reading** (`calc::uq_qualify` with `calc::et_default`: the
    operating point when the run has one, else its one other analysis). Where that would be a
    guess (no operating point and two or more other analyses) the cell reads R208d's
    sentence. This keeps every existing bench's plain rows working unchanged; the committed
    benches' **obvious** rows were migrated to their qualified spelling anyway (the operating
    point bench's `x1.F1` → `vdc(x1.F1)`, a transient bench's `out` → `vt(out)`, a DC-sweep bench's `i(vr1)` → `is(vr1)`; see
    `doc/claude/code_analysis/ade_parity_gaps_2026_10_11.md`), and the ambiguous ones were
    left for the user.
    ⚖ **2026-10-13 (R-OUT7): the migrated rows whose WHOLE text was one unsigned qualified
    signal were put back as saves** — the user: *"A 'save' will always be v("netname")"*; the
    batch driver's record of that resync (`doc/claude/calc_feedback_batch/BATCH.md` item 13, a
    summary, not the user's words) asks for the migration's bare qualified single-signal rows
    to go back to `v()`/`i()` in Saves — **1284 rows** (sky130A 1233, of
    which `test_carry_lookahead` 1089; ihp-sg13g2 25; xschem_libraries_oa 21;
    xschem_libs_newsym 5; gf180mcuD 0), derived from git by
    `tools/migrate/r208d_saves_revert.tcl`: the pre-migration text where it was already a save
    (42 rows, `I(Vmda)`), else `v(<x>)`/`i(<x>)` by the qualifier's family (1242 rows that were
    bare names). The three signed rows (`-idc(v1)`, from `-i(v1)`) and the nine composed ones
    stay migrated (the driver's summary also named `-idc(v1)`; a save has no sign, so those
    stay measures); `tests/headless/data/r208d_migration.txt` keeps those twelve for OE17, and
    `tests/headless/data/r208d_saves_revert.txt` (the tool's `--from 416051cd^ --table`) holds
    every reverted row's `{state index name pre migrated reverted}`: band TR of
    `test_ase_outputs_tabs` holds each committed row to it and re-reads `pre` from git.
  - **A device parameter (`@m1[gm]`) has no qualified spelling** (Cadence's `OP("inst"
    "param")` is not built) and is read as before, in a plain row or an expression.
  - Rows: OE16 of `test_ase_outputs_eval`; OE3/OE4/OE7/OE8/OE15 restated with qualified
    expressions; ET16 of `test_calc_eval_text`.
- **R-OUT5 — what the Value cell shows.** A scalar: `%.6e`, then
  `ase::format_value` (engineering notation). A waveform (a plain expression on
  a multi-point analysis, or a verb answering a wave): the word **`wave`** —
  never a last point. The on-screen "no single-point value" note names only the
  rows still without a value after the Calculator was asked, so a row whose
  cell reads `wave` is never also reported as having none (row OE12). It also
  leaves out a terminal-current row whose vector is in no plot of the results
  file (`ase::backend::ngspice::missing_spoken`, issue 1724): neither of the
  note's reasons holds for it, and R-OUT17's report speaks for it. The typed
  record of such a row carries its own sentence (`missing_row_note`): *"ase:
  result -- the results file holds no vector for the terminal current <row>,
  so that row has no value: the simulator makes that vector only for a .probe
  card it accepts."* A refusal: the Calculator's sentence. No results file: no
  value at all, as before. Plotting a verb-valued wave from Outputs is **not
  built**; the Plot tick keeps plotting plain RPN rows as before. Row OE6.
- **R-OUT6 — declared limits.** Sweeps, corners and Monte Carlo: **dataset 0
  only**. The Measurements dialog (`.meas`) and campaigns are unchanged. The
  Value cell is painted by `ase::ui::refresh_output_values` writing
  `[ase::format_value $val]`; its Tk half is covered by `test_ase_window`, which
  is not registered. Old state files load unchanged (no field added); their
  values are now computed rather than printed. **A scalar that divided by zero,
  or took `ln`/`log10`/`db` of a value <= 0, shows no value**: the Value cell
  reads `Cannot evaluate: division by zero` or `Cannot evaluate: log of zero or
  a negative value` (calculator.md R610; band ET14 of `test_calc_eval_text`),
  as the old ngspice print path refused it; the engine's own DIVIS 0 and log
  floor (issue 1628) are never shown. A wave is not refused for a zero at some
  or all of its points. Malformed one-token
  infix (`2(Vcc-Vss)`, `1..2*Vcc`, a whole `2M`) is refused with a sentence in
  the Value cell, never evaluated as a leading number (row ET12 `MALFORMED`).
- **R-OUT7 — two tabs, Measures and Saves (user rulings 2026-10-13).** The user:
  *"A 'save' will always be v("netname") - because 'save' of a net would apply to any
  analysis."* *"v() is only a save of a node - it can be in the Saves tab and do no harm."*
  *"vt(netname) is NOT a save! It's a fetch of the time-domain waveform. All the user can do
  with it is plot it."* *"an expression, created by user, can be in the Measures tab."* The
  Outputs pane is two tabs over the ONE `outputs` list; **Measures is shown on open and after a
  state loads** (Load State, Revert). A row's tab is a pure function of its TEXT,
  `ase::output_tab` (no Tk; counted arm): **Saves** = a plain `v(<node>)`, `v(<a>,<b>)` or
  `i(<source>)`, either case, Cadence quotes allowed, no sign (`ase::output_is_save`; a
  terminal current `i(<path>:<tname>)` has that shape and sorts here too, R-OUT17);
  **Measures** = everything else — an analysis-qualified fetch (`vt(out)`, `vdc(out)`,
  `idc(v1)`), a signed signal (`-i(v1)`, `-idc(v1)`: a save has no sign, and the author's sign
  flip is a number they meant to read), a bare name, a device quantity (`@m1[gm]`), a
  measurement call (`value(vt("net"),120u)`, `cross`, `dutyCycle`), an expression in either
  syntax, wave-valued ones included (`db(vf(out))`, `vt(a)-vt(b)`). **The state format is
  unchanged** and an old state sorts itself on load. Judgement calls, recorded: a **bare name**
  is a Measure because on the committed benches it is as often a `.meas`/`let` result (`GBW`,
  `Ctot`, `avg`; `GBW` is a `let` in its original testbench) as a node (`TEMPERAT`, `VBG`), and text cannot tell them
  apart; a **device quantity** is a Measure because it is a number the user reads (and its
  Save tick still emits its `.save @dev[param]` card, R-OUT3). A Saves row shows **no Value**
  (columns Name, Plot, Save, Save Options); its Plot tick still auto-plots as a plain signal
  row always has, in the viewer's analysis — ⚖ **pending the user's ruling** (owed rule
  `ase_saves_autoplot`): the batch brief said Saves "never auto-plot", which is not among the
  user's quoted words, and 1282 of the 1284 put-back rows carry their author's Plot tick. Only
  the SHOWN tab's tree can carry a selection: switching tabs clears the hidden one's, and the
  strip's delete never reaches it (TW6). The tree item id is the row's index in the state
  list in both tabs, so a click, an edit or a delete addresses the state whatever the view
  order. Suite `test_ase_outputs_tabs` (TC, TW1).
- **R-OUT8 — a save ADDS and never narrows (2026-10-13: a driver default stated to the user and
  unobjected, BATCH.md item 13; the batch brief restates it among the rulings).** In
  ngspice one plain `.save` keeps only what is listed (R-OUT3's measurement), so a deck with any
  output card now carries **`.save all` ahead of it** — exactly one: when the operating-point
  tier's block is coming it carries that leader instead (`render_deck`). `ase::saves_narrowed`
  answers 0 for every state and `ase::saves_all_forced` is 1 whenever there is a card, so the
  6g-1 widening and its `vecsaves` caution, `saves_resolve`, the 6g-3 phantom guard and
  `disto_saves` stand down on every real bench; their code and sentences are kept, pinned in
  the DORMANT world of `test_ase_preflight`'s `pf_narrowed`. Save-All Voltages/Currents keep
  their meaning. **Measured 2026-10-13** on the registry ngspice (`build-ver_50`), real sky130
  benches through ASE-L's own netlister and deck: as committed (op tier on) `charge_pump`,
  `test_mos_binning`, `bandgap`, `montecarlo_mismatch_sim` keep 184/19/880/124 op vectors
  before and after (the tier's leader already saved everything; the deck gains one line where
  the outputs need their own); with device-parameter saving off, the narrowed decks of
  `test_mos_binning` and `charge_pump` held **2 and 25** op vectors before and hold **14 and
  100** after. Rows TD, OE1, OE7, WD2–WD6 (`test_ase_core`), PF*0-REAL.
  A **terminal-current row is not a card** (R-OUT17), **but a Save-ticked one is a save and
  brings the leader** (`ase::output_saves_any`, the one body `ase::saves_all_forced` and
  `render_deck`'s leader arm read). A plot-only terminal row brings none, like a plot-only
  voltage row. Why it has to: a netlist can carry a `.save` of its own (every stock ammeter
  writes `.save i(vmeas)`), and that card narrows the results to what it lists. **Measured
  2026-11-19** on `ver_53` over such a netlist, transient only: with the terminal row
  Save-ticked the results hold the terminal, `i(vmeas)` and the node voltages; plot-only, the
  terminal and `i(vmeas)` and no voltage; with no row, `i(vmeas)` alone. A netlist with no
  `.save` of its own keeps every usual vector beside the probed ones either way.
- **R-OUT9 — the Value header sorts the Measures VIEW.** The user: *"click on the 'Value'
  header to push the 'waves' to the bottom - since user really only wants to SEE the values -
  real numbers"*. A click orders numbers first (a list of numbers counts as numbers), then
  rows with no value yet or a refusal's sentence, then `wave`, each group in the user's own
  order (`ase::ui::value_rank`, `ase::ui::measures_order`, pure); the heading reads
  `Value ▾` while sorted; a second click restores the user's order. It never reorders the
  state's list (which is also the evaluation order); new values from a run re-sort a sorted
  view without dropping the selection. The sort survives a state load (a view preference).
  Rows TO, TW2, TW3, TW5 (Load State, the dialog's `load_state_commit`, Revert, the kept
  selection).
- **R-OUT10 — each tab keeps its door.** A save typed under Measures is refused with
  *"ase: v(out) is a save -- add it under Saves"*; anything that is not a save typed under
  Saves is refused with *"ase: vt(out) is not a save -- add it under Measures"*; the dialog
  stays open (`ase::output_admit`, CIW error line, the editor's existing refusal style). A
  **bare node typed under Saves is admitted as `v(<node>)`**. A **bare name typed under
  Measures** is refused with *"ase: out is a node -- add it under Saves"* when the design's
  current netlist names it a top-level node or global (`ase::output_known_nodes`, read from
  `ase::netlist_facts_cached`, which never netlists); a name the netlist does not know — a
  `.meas`/`let` result such as `GBW` — is admitted, and with no netlist in hand the text alone
  cannot tell the two apart, so it is admitted too. Committed bare rows stay where their text
  puts them (Measures): of the 112 on the benches, the 32 with Save off are `.meas`/`let`
  results (`GBW`, `Ctot`, `rseries`, none a net label of its schematic), and d2d25b1c measured
  that a `v()` around a name the circuit lacks turns a running bench into one pre-flight
  refuses. The door judges the text the user TYPED: an **edit** of a committed bare-node row
  that leaves its text unchanged (unticking Plot, renaming it) is admitted, and only a changed
  text is judged afresh (`output_admit`'s `orig`). Every other door that adds a row routes by the same classifier because the tab IS
  the text, and **shows the tab the row landed in**: Select On Design writes
  `v(<net>)`, a source's `i(<inst>)` or a terminal's `i(<path>:<tname>)` (all Saves), the
  two-port matrix picker writes `S_1_1 db20()` (Measures),
  and R608's Export (not built) will. Rows TA, TN, TW4, TW7, TW8.
- **R-OUT11 — a committed plain row whose author meant the operating point is a measure
  (user ruling 2026-10-13).** The user: *"Yes, proceed with vdc(vbg) and analogues of that in
  all test-benches where there is an operating point analysis and it is obvious that the
  intention was to display operating point information."* The rule, for a committed bench's
  row whose whole text is a save (`v(x)`, `i(x)`) or a bare name, on a bench whose operating
  point is enabled:
  - **Obvious** means either the bench's **only** enabled analysis is the operating point
    **and the cell is a test bench** — its schematic places no port pin (`ipin`, `opin`,
    `iopin`) — or the bench it was migrated from (`<pdk>/xschem_libs/<lib less _ase>/<cell>`) has a `print`
    in its `.control` block, with `op` the last analysis before it, naming the row's **exact**
    text — the author printed it at the operating point (IHP `ac_hbt_13g2`'s
    `print Vc Vb I(Vce)` after `op`). A bench with other analyses whose row came only from a
    graph, a `plot`, a `save` or a `wrdata` is **not** obvious and the row stays: `tb_bandgap`'s
    `VBG` is read from a transient graph, so it stays a bare name. A cell with ports is a
    circuit a bench instantiates (`bandgap`, `bandgap_opamp`, `charge_pump`, `charge_pump2`,
    placed by `tb_bandgap`, `bandgap` and `tb_charge_pump`): run alone its inputs float, and
    its op-only state is the migration's default rather than the author's choice — the
    original has no `.control` block, and `ase_migrate.py` enables op when it extracts
    nothing — so its rows stay saves. Where op-only IS the author's choice, the original's
    `.control` runs `op` and no other analysis: `sky130_mismatch` (a Monte Carlo loop of op
    points) and `test_sweep_res_l` (an `alterparam` loop of op points) — those authors
    plotted the loop, and the migrated state runs one op, so the Value is that one point.
    This is why the user's own example is not converted anywhere: `bandgap_opamp` is such a
    cell and holds no `vbg` net, and `tb_bandgap`'s `VBG` is the transient row above. ⚖ The
    test-bench condition narrows the user's *Yes* (14 of the 20 rows the ruling was asked
    about stay saves) and is owed to the user as rule `R-OUT11_test_bench_cells`.
  - **The row becomes `vdc(<x>)` / `idc(<x>)`**, keeping the author's spelling and case of the
    signal (`v(CLK)` → `vdc(CLK)`, `I(Vce)` → `idc(Vce)`, `Vc` → `vdc(Vc)`), so it sorts into
    Measures (R-OUT7) and its Value is the operating-point number. Every other field of the
    row is unchanged.
  - **Only where the number is real.** An obvious row stays as it is when the signal is not in
    the bench's operating point (`vdc()` of such a name shows the Calculator's *unknown
    token* refusal; `sky130_mismatch`'s `run`, `f1`, `f2` are `let`/`meas` names), when it is the two-node form (`montecarlo_mismatch_sim`'s
    `v(vm,vcm)`: the Calculator reads no `vdc(a,b)`), or when the bench does not run here
    (`test_mos_binning` is refused by ASE-L's pre-flight before it runs, because its stale
    `i(curr)` row names nothing in the circuit).
  - Derived by `tools/migrate/op_measures.tcl` from the states at `2e1e4ccb`, the original
    benches, and each bench's real operating point (`tools/migrate/op_measures_vars.tcl`, the
    registry ngspice). `tests/headless/data/op_measures.txt` holds every candidate row as
    `{state index name old new why}` — the converted ones with their evidence, the ones that
    stay with their reason — and `tests/headless/test_ase_op_measures.tcl` holds the tree to
    it: OM2 the committed rows, OM3 the spelling, OM4 the coverage and OM5 the evidence
    re-derived by its own scan (the port pins counted by xschem's own symbol types, and
    the original's `.control` running op alone on a converted row and absent on a kept
    cell), OM6 only the `expr` fields moved (git), OM7 each converted
    bench run on the registry ngspice with every converted row in the Measures tree
    (ase::ui::measures_order) and the Value it shows a number equal to the
    results file's own vector and to ngspice's own `print` of the author's text. Bands TM and
    TR of `test_ase_outputs_tabs` exempt these rows at exactly the table's text.

- **R-OUT12 — the `~` strip button updates the Values and plots the ticked waveforms
  (user 2026-10-14).** The user: *"if there are outputs that are waveforms that are chosen to
  be plotted, then, if Waveform Viewer is not already up, it will be launched and those
  signals will be plotted. More importantly, measures will be calculated and updated values
  displayed in the Outputs pane (Measures tab)."* `ase::ui::plot_outputs`:
  - **Values first.** Every row is evaluated against the session's current results file by
    the same reader the open and Load State paths use (`ase::ui::results_refill`, R-OUT2), so a
    row added or edited after the run gets its number, `wave` or refusal sentence. Before
    this, the Value column was written only at run end, open and Load State, and the button
    only raised the viewer: a row added after the run stayed blank.
  - **Then the plot**, through the after-run auto-plot and its refusal rules: the viewer is
    opened if it is not up, the results attached, and the auto graph rebuilt from the ticked
    rows (`ase::ui::plot_targets`). A ticked **expression whose Value is a number** (a scalar
    measure such as `settlingTime(...)`) is not a trace and is not handed to the viewer, after
    a run either — it used to be, and the viewer answered *unknown token*. Nor is **any
    ticked row whose Value is a refusal sentence**: the Value cell is the one place that is
    said, and the viewer only repeated it as an error. A ticked plain signal valued a number
    is plotted (an op+tran bench's `VBG` reads the operating point and plots the transient);
    a row with no Value yet is offered. On an operating-point-only view nothing is filtered,
    and the auto-plot says that view has no sweep.
  - **No results** (`ase::has_results` false): it says *no results; run a simulation first*
    and changes nothing. Ticked waveforms none: it says *no waveform output has Plot ticked*,
    opens no viewer, and an open viewer's auto graph is emptied (the after-run
    always-replace rule). A second press with the viewer up replaces the auto graph's
    traces; it never adds a second copy.
  - **An edited expression's Value is dropped** on the editor's OK
    (`ase::ui::output_editor_ok`, `ase::ui::results_drop_edited`): the cell is blank until
    `~` or the next run, never the old expression's number — under the old name as well as
    the new one when a rename and a new expression arrive together.
  - **After a failed run** it says the run failed instead (R-OUT13).
  - The Measurements dialog is not repainted by `~`: its Values are the simulator's own
    measurement output, which only a run changes.
  - The tip reads **Plot outputs and update values (Ctrl-click: values only)** (R-OUT16); `Tools > Waveform Viewer` stays the
    raise-or-open door that plots nothing.
  - The Value and the Calculator window's Eval of the same text are the same double
    (`calc::eval_texts` and `calc::meas_in_ctx`), shown `%.6e`.
  - `tests/headless/test_ase_plot_outputs.tcl` (both arms; PR rows on the real `tb_bandgap`
    bench with the registry ngspice, pinned to its nominal corner: the shipped Monte Carlo
    draw stops some transients with *Timestep too small*).

- **R-OUT13 — a failed run says so (2026-10-14).** The shipped `tb_bandgap` draws VCC with
  `agauss`, and some draws stop its transient (*Timestep too small*, rc 1; measured
  2026-10-14 on the registry ngspice: `.options seed=` 35 and 37 of 1–60). ngspice still `write`s the operating point, so
  the results file is newer than the deck and `ase::has_results` answers 1. Before this the
  status segment turned red and nothing else changed: the Measures Values went on showing
  the PREVIOUS run's numbers, and `~` then filled every expression with *Cannot evaluate:
  this result has no transient analysis*, as though the circuit had none.
  - **`ase::run_failed`** answers `{exit N log <path>}` from the run log's own footer
    (`=== exit N after T s ===`, written by every run), so it holds across a restart; no
    log, no footer (a run in flight) or exit 0 answer `{}`.
  - **A Stop is not a failure**: `ase::ui::do_stop` marks the session `stopped` before it
    kills, and `run_started` clears it. In memory only: after a restart a stopped run's log
    reads as a failed one.
  - **At run end** (`ase::ui::run_finished`, nonzero exit, not stopped) the CIW says
    *ase: simulation failed (exit N); log: <path>* at error severity, beside the red
    *Status: Error*, and every Value cell reads **Run failed (exit N); see the log**.
    That is the run's ONLY end line: `ase::run_done` leaves its *ase: simulation finished
    (exit N), log: <path>* pending for the after-run callback (`ase::run_finish_note_take`),
    which says the failure sentence in its place. A Stop says the finish line as before; so
    do a clean run, a run with no callback and a callback that does not take the line (a
    campaign).
  - **The results reader** (`ase::ui::results_from_disk`, so open, Load State and `~`)
    answers that same sentence for every row and reads nothing from the file.
  - **`~`** says the failure sentence, refills the Values with it, and plots nothing.
  - Fenced by bands PO8, PO12 (one end line), PO13 (a run after a Stop clears the mark; both
    arms) and PF1 (display arm: the shipped draw at `.options seed=35`, run for real) of
    `tests/headless/test_ase_plot_outputs.tcl`.

- **R-OUT14 — `~` and the run-end auto-plot follow the viewer's plot mode (user
  2026-10-15).** The user: *"The plot button (~) functionality ignores the multi/single plot
  mode of the already-up Waveform Viewer and does a single plot mode - dumping all signals
  onto a single strip."* `ase::ui::auto_plot` (both the `~` press and the after-run
  `auto_plot_idle`) now asks `wviewer::auto_plot_strips` where each ticked row goes:
  - **Single-plot**: every row in ONE auto strip (the `auto 1` marker), exactly as before.
  - **Multi-plot**: one auto strip PER row, newest on top — the last row topmost, which is
    `wviewer::plan_plot`'s multi rule for any other batch, so `~` and a Direct Plot of the same
    signals stack them alike. Missing strips are inserted above the first auto strip (at the
    top when there is none, claiming a lone empty strip as before); surplus ones from a longer
    earlier batch are removed, never left as blank bands. The target strip and the trace
    highlights follow any index that moves.
  - **The mode** is the viewer window's (`wviewer::plot_mode`); a viewer `~` opens is seeded
    with the viewer's own default (`wviewer_plot_mode`, shipped `single`), as any new viewer is.
  - **Replace is unchanged**: every auto strip is cleared before a press or a run adds, so a
    second `~` or a second run never adds a second copy; nothing ticked leaves one empty auto
    strip; a strip without the marker (Direct Plot, a hand-built strip) is never touched.
    ⚠ **Amended by R-OUT15 (2026-10-15):** under the default Replace the TARGET SUBWINDOW is
    emptied first, hand-built strips in it included (Cadence's Replace); a strip in another
    subwindow or another tab is never touched, and Append touches nothing.
  - **A Direct Plot never lands in any auto strip**: `wviewer::empty_graph_indices` skips every
    strip carrying the marker, and `wviewer::plot_signals` treats a target on any of them as
    unusable. For the same reason Delete Empty Strips (`e`) never deletes an auto strip, any of
    them: `wviewer::empty_strips_to_delete` reads the same `empty_graph_indices`.
  - The ADE-L-style destination selector for `~` and the run-end plot is R-OUT15 below.
  - Fenced by bands PO14 (both arms; the real `auto_plot` against the viewer model, its Tk doors
    stood in for), PO15 (both arms; `auto_plot_strips` and `plot_signals` on layouts where the
    target and the highlights moving, the top insert and the any-auto-strip guard each have an
    answer only they give) and PR11 (display arm: a real click on `~` and a real `tb_bandgap` run in
    multi-plot, then back to single) of `tests/headless/test_ase_plot_outputs.tcl`.

- **R-OUT15 — the plot destination drop-down (user 2026-10-15; BUILT 2026-10-15).** A
  read-only drop-down at the right end of the status bar — `Append`, `Replace`, `New SubWin`,
  `New Win` — used by `~` and the run-end auto-plot, and by nothing else: **Direct Plot does
  not read it** (user 2026-11-16; it did from 2026-10-16 until then, see its bullet below). It
  lands in the active viewer tab's TARGET subwindow. It is ASE-L's OWN setting: the viewer has
  no destination setting (user ruling 2026-10-16: *"ViVA doesn't"*), and the Calculator's W13
  is a separate one; none moves another. The authority is `doc/claude/specs/waveform_viewer_subwindows.md` (SW7-SW11, SW18,
  §8, and §15 for what was built). R-OUT14's strip order (last row on top) is unchanged by it.
  - **The control** is `$top.status.dest`, packed first at the right so a narrow window clips
    the text segments and never it, driven by `<<ComboboxSelected>>` →
    `ase::ui::plot_dest_picked` → `ase::ui::set_plot_dest <key> <code>`, which writes the
    session state, moves the control and logs that one line on a change only. Load State and
    Revert move it with the state (`ase::ui::refresh_status`).
  - **The state key** is `plot_dest`, the tenth member of `ase::omit_if_empty`: `{}` (absent)
    means the default (the rc's `ase_plot_dest`, **Replace** when unset), and a choice equal
    to that default is stored as `{}` too, so choosing it back leaves a saved session clean.
    Any other value is `append`, `replace`, `newsubwin` or `newtab` (`ase::plot_dest_of`;
    anything unknown reads the default). No committed `.state` file changes.
  - **Replace**: the target subwindow is emptied (`wviewer::clear_subwin`, one undo step; the
    survivor keeps the run's strip view, so a zoom survives a re-run), then R-OUT14's auto
    strips. **Append**: the viewer's append rule in the target subwindow
    (`wviewer::plot_sites`, the batch may land in an auto strip); nothing is cleared, so a
    second press adds a second copy. **New SubWin** / **New Win**: a new subwindow / viewer tab
    holds the run's auto strips and the previous plot stays where it was; a viewer the press
    had to OPEN is already new, so nothing more is made in it.
  - **Nothing ticked**: under Replace an open viewer's target subwindow is emptied to one
    empty auto strip, but only when it holds an auto strip (a subwindow `~` never plotted into
    is not emptied by a press that plots nothing); under the other three nothing changes.
  - Failed runs, refusals and the op-only notice are unchanged (R-OUT12/R-OUT13), under every
    choice.
  - **Direct Plot ALWAYS APPENDS** (user 2026-11-16, reversing the 2026-10-16 ruling of issue
    1663 from option (a) to option (c)): *"The Direct Plot, which is same as Ctrl-4 should
    always Append to the destination. The destination drop down is only for the ~ plot button
    and automatic plot of results when simulation finishes."* `ase::ui::dp_finish` passes
    `append` to `wviewer::plot_signals` for each batch (one per ESC), from Results > Direct
    Plot and from Ctrl-4 alike, whatever the drop-down says. So nothing is emptied and no
    subwindow or tab is made; within the target subwindow the viewer's plot mode and its
    append rule decide (the run's auto strip is left as it is and the picks go beside it).
    The tooltip reads "Where ~ and the run-end plot go". Band PO16k of
    `test_ase_plot_outputs` (the hand-off, and the landing through the real
    `plot_signals` chain under every choice), `test_ase_plot` P4 and `test_wave_modes` MG12
    (the real Direct Plot under the default Replace).
    Between 2026-10-16 and 2026-11-16 Direct Plot followed the drop-down (*"Direct Plot
    follows the drop-down; default is Replace"*), so under the default each batch emptied the
    target subwindow first.
  - **The rc default** (user 2026-10-16, issue 1663): `ase_plot_dest` (`set_ne` in
    `src/xschem.tcl`) = `append` | `replace` | `newsubwin` | `newwin` (labels and any case
    accepted); empty = Replace; anything else = Replace with ONE CIW warning per bad value
    (`ase::plot_dest_default`). A session that saved no choice starts on it; a saved choice
    wins. A choice equal to the rc default is stored as `{}`; any other is written out.
  - **The CIW line** (user 2026-10-16: *"ensure there is logging in CIW so user knows what to
    put in the rc file"*): a user change of the drop-down (`ase::ui::plot_dest_picked`) prints
    one line, `ase: plot destination = <label> (<rc>: set ase_plot_dest <word>)`, where `<rc>`
    names the rc this launch read (`xschem::rc_name`): the `--script` file's name -- the PDK
    launcher's `cadence_style_rc`, since run from the source tree xschem sources neither
    `./xschemrc` nor `~/.xschem/xschemrc` -- else `xschemrc`. C mirrors `--script` as
    `::cli_opt_script` (rows RC7/RC8).
    `ase::ui::set_plot_dest` itself (a replayed log, a script), Load State and Revert print
    none. Band RC of `tests/headless/test_ase_persist.tcl`, rows PD4/PD5 of
    `tests/headless/test_ase_window.tcl`.
  - Fenced by band PO16 (both arms) and PR12 (display arm, the real `tb_bandgap` bench, each
    choice picked by a real `<<ComboboxSelected>>` and `~` pressed by a real click) of
    `tests/headless/test_ase_plot_outputs.tcl`, and rows PD1-PD6 of
    `tests/headless/test_ase_window.tcl`.
- **R-OUT16 — Ctrl-click on `~` evaluates only (user 2026-10-15; BUILT 2026-10-15).** "We
  want Ctrl-click (LMB) to only evaluate and display measures, not do any plotting action."
  - A Ctrl+LMB click re-evaluates every Outputs row from the session's current results and
    fills the Value cells exactly as `~` does (R-OUT12's evaluation, `ase::ui::results_refill`),
    with the same sentences for no results and for a failed run (R-OUT13). It does NO plotting:
    no viewer is opened, no strip, subwindow or tab is touched, whatever the plot destination
    (R-OUT15) says. A plain click is unchanged.
  - Built as `ase::ui::evaluate_outputs <key>` (the first half of `ase::ui::plot_outputs`,
    which now calls it), reached by an instance binding `<Control-Button-1>` on
    `$top.strip.plot` that `break`s, so the Button class never arms the button and the release
    invokes nothing.
  - The tip names both: **Plot outputs and update values (Ctrl-click: values only)**.
  - Fenced by band PO17 (both arms) and PR13 (display arm: a real Ctrl-click with the viewer up
    leaves its layout, tabs and target byte-identical and never reaches `ase::ui::auto_plot`;
    with the viewer closed it opens none; a plain click is the control) of
    `tests/headless/test_ase_plot_outputs.tcl`.
- **R-OUT17 — a terminal current is probed, never saved (issue 1724; BUILT 2026-11-19).** The
  current into ONE terminal of a device or of a subcircuit instance is a row spelled as the
  simulator names the vector, `i(<path>:<tname>)` — `i(x1.xm1:d)`, `i(r9:n1)`, `i(x1:in)`.
  Select On Design writes it for a click on a device pin (*A click on a device pin queues its
  terminal current*, in the UI section), and it can be typed like any other row. ngspice makes
  that vector for a `.probe I(<path>,<pin>)` card at the deck's top level and for nothing else:
  **measured 2026-11-19** on the fork's `ver_53` build, `.save i(x1.xm1:g)` with no probe
  behind it runs at rc 0 and writes no such vector and no message.
  - **One predicate, asked of a SIGNAL and never of a row's text.** `ase::probe_split` answers
    `{<path> <tname>}` for one `i(…)` wrapper in either case, with or without the Cadence
    quotes, holding exactly one `:` with something on each side and no whitespace, comma,
    parenthesis, `;`, `$`, `=`, `'` or brace. Measured on `ver_53`, each between two good
    terms on one `.probe` card: a `;` starts a comment and cuts the card there, so the terms
    behind it are lost; a `$` opening the pin (`I(rt,$n1)`) does the same at rc 0; an `=`
    (`I(=rt,1)`, `I(rt,1=)`), a `'` (`I(rt,1')`) and an opening brace stop the simulator with
    a netlist error before any analysis; a closing brace is harmless and leaves with the
    opening one. A row holding one of them is therefore the `.save` card it was before
    R-OUT17: Save-ticked, the pre-flight refuses it by name (R-OUT3a); plot-only, it writes
    nothing. Names the netlister does write still split: `i(xm1[3]:d)`, `i(x1.xm<2>:d)`,
    `i(x1:in+)`, `i(x1:in-)`. A plain row
    is read as `ase::output_is_plain` reads it (one leading `-` off,
    then `ase::output_signal`) and an expression row through `calc::eval_text_signals`
    (`ase::output_probes`), so `-i(x1.xm1:d)`, `it(x1.xm1:d)` and both reads of
    `db(if(a:d)/if(b:d))` are terminals. A source's `i(v1)` and `i(v.x1.vp)` are not.
  - **No `.save` card and no pre-flight row; the leader is R-OUT8's.**
    `ase::output_card_sources` skips a terminal in both roles (R-OUT3, R-OUT3a). A
    Save-ticked terminal row still brings the `.save all` leader (R-OUT8,
    `ase::output_saves_any`). `ase::saves_unresolved` does not count a plain terminal row
    (`ase::output_is_probe` is the one body the two share), which keeps its two numbers
    true. As a bench stands, `saves_resolve` and `disto_saves` stand down through
    `ase::saves_all_forced` before they read that count; the skip is what would keep a
    terminal-only bench from being cautioned on every analysis and refused on `disto` if the
    leader were ever switched off. Measured: a deck with `.probe`, no `.save` card at all and
    `disto` runs at rc 0, and the plot holds the probed vectors.
  - **The probe plan.** `ase::probe_plan {state netlist_text {mode fold}}`: one record per
    asked name, the Outputs rows' in pane order and then the measurement rows', each as
    `ase::probe_card`'s record `{signal path pin card why nohdr}`. Which rows ask is one
    body, `ase::probe_asked {state {but {}}}`, read by the plan and by the report (which
    hands it the rows another sentence already speaks for, to pass over). Asked means:
    - a **Saves-tab** row (`ase::output_is_save`) with Save OR Plot ticked. A plotted terminal
      has no vector unless it is probed. With neither box ticked it asks for nothing, like
      any save that is switched off;
    - every terminal a **Measures-tab** row reads, ticked or not, whether the row is one
      signal (`idc(xm1:d)`, `-i(rt:n1)`, `it(xm1:d)`) or an expression. Its Value is computed
      from the results whether or not it is saved, and the Add Output dialog
      (`ase::ui::output_editor`) opens with both boxes off;
    - every terminal an **enabled measurement row** reads (`ase::meas_probes`): the rows
      whose `ase::meas_verdict` is `ok` or `caution`, their fields of kind `vecexpr`, each
      `i(…)` token `ase::probe_split` takes. A `param` measurement's `expr` field is not
      such a field and asks for nothing.

    Two spellings that differ only in case are one terminal unless the run requests
    `distinguish`. Two names for one terminal (`i(x1.m2:b)` and `i(x1.m2:b_tj)`) are two
    records with one card, so that the report can speak about each row. There is no Tk in
    it, and it reads no file except for one kind of terminal: a numbered port of a
    subcircuit instance whose `.subckt` header the netlist text does not hold (below). It
    is ONE body for the deck writer and for `ase::run_deck`, which carries the plan to the
    report as the `probes` key of its run record.
  - **The card is not the row's text** (`ase::probe_card`; measured on `ver_53`). A
    subcircuit instance (leaf `x…`) takes its port by name, `I(<path>,<tname>)`, unless the
    name is a number (next item). Any other
    leaf takes `n<k>` as the position `<k>` and `b_tj` as `b`: the simulator answers with
    those two names and refuses them in a card. A device's own letters go as they stand. A
    TOP-LEVEL instance that is not a subcircuit instance is written in lower case unless the
    run requests `distinguish`: spelled in upper case, a simulator that is not folding case
    names both pins of `Rtop` `i(Rtop:nn)`.
  - **A subcircuit port whose name is a number goes into the card as its position.**
    Measured on `ver_53`: a word of digits in a card is a POSITION, also where a port has
    that number as its name. Over `.subckt blk 3 2 7`, `I(x1,3)` is the third port and comes
    back as `i(x1:7)`, and `I(x1,7)` is refused (*"x1 has 3 terminals"*). Vendor macro-models
    name their ports this way (`.SUBCKT LM741 1 2 99 50 28`). So for a leaf `x…` with an
    all-digit terminal `ase::probe_x_ports` walks the instance path through the netlist text
    (the top-level card of its first component, the subcircuit that card calls, and for each
    further component the card of that name inside that subcircuit's body) and takes the last
    subcircuit's `.subckt` header from the netlist text or, when the text has none, from the
    model files the deck names (`ase::subckt_model_cards`, read through `ase::subckt_lib`).
    Then: the number names exactly one port of that header, and the card carries that port's
    1-based position; it names no port, or two, and it is written as it stands (a position
    typed by hand); no header, or no card for the instance, is found, and it is written as it
    stands with the record's `nohdr` set to `{header <subcircuit>}` or `{call <instance
    path>}`, which the report reads. A body is only ever walked in the netlist text. A name
    that is not all digits triggers none of this: no netlist is walked and no file is read
    for it. `ase::probe_refusals` is not taught the simulator's *"is taken as a position"*
    line: a correct positional card prints it whenever the number is also another port's
    name.
  - **One `.subckt` header reader.** `ase::subckt_scan` (the headers and the
    `.include`/`.lib` cards of one text, section-aware), `ase::subckt_walk` (every header
    reachable from a list of files, each file's own cards followed relative to its
    directory) and `ase::subckt_lib` (that walk, remembered until a file it read changes).
    The pin pick's `ase::ui::sod_subckt_scan`, `sod_subckt_walk` and `sod_subckt_lib` forward
    to them, so the click that names a port and the card that carries its position cannot
    read a header differently.
  - **Withheld: no card is written, and the report says why.** Any `K` coupling. A top-level
    `E` whose card, `+` lines joined (`ase::probe_top_card`), has fewer than six words, and
    pin 3 or 4 of one that carries `vol=` or `value=`: each stops the simulator before any
    analysis, on `ver_53` and on apt 45.2 alike, while the six-word
    `E5 TEMPERAT VSS VOL=' temper '` that xschem's `vsource_arith` symbol netlists is probed
    without harm. And, under `distinguish`, a top-level device with a capital in its name:
    its lower-case spelling is refused there (*"differs only in case"*) and its upper-case
    one is mis-named.
  - **Where the cards go** (`ase::backend::ngspice::render_deck`). `.probe I(…) I(…)` cards
    of space-separated terms (a comma between two terms drops the second), a card closed
    when the next term would carry it past a hundred characters, directly after the output
    `.save` cards and above the operating-point tier's block. Each distinct term is written
    once (`ase::probe_terms`), also when two records carry it. A bench that asks for no
    terminal renders the deck it rendered before, byte for byte.
  - **A term the netlist already asks for is not written again**
    (`ase::probe_netlist_terms`, `ase::probe_terms_new`; the card writer loops over the
    filtered terms). A schematic written for this simulator can carry a `.probe` card of its
    own in a code block. **Measured** on `ver_53` and on apt 45.2: the same term twice in a
    deck makes the vector of a top-level device twice, under one name, and on `ver_53` a
    second probe node stands in series with the first; for a device inside a subcircuit
    `ver_53` kept one vector. What is read of the netlist text: the card word without case;
    a card's `+` lines joined on, a comment line between them skipped; a card inside a
    `.subckt` body like one at the top level, because the simulator does not read a `.probe`
    relative to the subcircuit it stands in; nothing behind a `;`, or behind a `$` that
    follows a blank or a comma (both measured to be comments); and only the spelling ASE-L
    itself writes, with no blank inside the parentheses. How two terms are compared follows
    the case mode the run requests: under `fold` without case (a netlist's `.PROBE
    I(RTOP,1)` and ASE-L's `I(rtop,1)` made the one vector twice); under `preserve` and
    `distinguish` only an identical spelling counts, because under `preserve` a netlist's
    `.probe I(Rtop,1)` makes `i(Rtop:nn)` while ASE-L's `I(rtop,1)` makes the row's own
    `i(Rtop:n1)`, and dropping ASE-L's term there would cost the row its vector. The plan,
    the run record and the capability echo are keyed on the unfiltered list and are
    unchanged. Declared: it is a comparison of text, so `I(m1,d)` beside `I(m1,1)` is still
    written twice.
  - **The marker.** A deck that carries a `.probe` card echoes
    `ASE-PROBE-VERSION $?probe_version` (`ase::probe_marker`) in its `.control` block, below
    the pre-commands and bridges and above `set appendwrite`, so before the first analysis:
    a failed analysis quits where it stands. The simulator answers 1 when the terminal-probe
    extension is built in (`ver_53`) and 0 otherwise (apt 45.2, `ver_50`, `ver_52`). The
    report after the run reads this line of the run's own log (`ase::probe_marker_answer`).
  - **The capability key `hier_probes`** asks the same question of a program BEFORE any
    run. The capability probe's deck C carries, as the first line of its control block,
    `echo ASE-PROBE-VERSION $?probe_version > probe_h.txt`
    (`ase::backend::ngspice::cap_hier_lines`), and the adapter's `capabilities` publishes
    `hier_probes` 0 or 1 from that file, never from the exit code, under
    `altshow_op_dump`'s contract: a run of deck C cut by the budget records the key as
    unmeasured (`timeout`), and one that finished and left no 0 or 1 publishes neither.
    **Measured** 2026-11-20 through the real probe: 0 on apt 45.2, `ver_50`, `ver_52`
    and stock 47, 1 on `ver_53`; every other key of the four answers taken that day was
    unchanged. The adapter's `variant_notes` names the gap as *"terminal currents of
    subcircuit pins or of devices inside subcircuits"* (unmeasured: *"whether it saves
    terminal currents inside subcircuits"*), after the fast dump's clause and before the
    asides, so apt 45.2 reads *"… can do everything ASE-L offers except case-sensitive net
    names, the fast operating-point dump and terminal currents of subcircuit pins or of
    devices inside subcircuits. …"* and `ver_53` still reads *"… can do everything ASE-L
    offers."* The run is never refused on the key.
  - **Which terminals need such a program** is one predicate, `ase::probe_needs_hier
    <path>`: the path holds a `.` (a device inside a subcircuit) or its last word begins
    with `x` or `X` (a pin of a subcircuit instance). `ase::probe_plan_hier <plan>` gives
    the plan's terminals of that kind whose card was written.
  - **The cure**, `ase::probe_cure {state {mode ask} {tail again}}`, is the words every
    sentence about a program that cannot ends with: which REGISTERED simulator can, and
    where it is picked. It walks the entries that can serve the session's backend
    (`ase::sim_list`), in registry order, leaving none out
    (`ase::probe_cure_entries`), and says, the first of these that applies:
    - an entry is known able: *"<A> can — pick it under Setup > Simulators… and run
      again."*; *"<A> and <B> can — pick one under Setup > Simulators… and run again."*
      (three or more: *"A, B and C"*);
    - none is, and an entry has not been tried: *"<C> has not been tried yet — the next
      run finds out whether it can, or select it under Setup > Simulators…, press Edit…
      and then Detect."* (several: *"<C> and <D> have not been tried yet — the next run
      finds out which of them can, or select each under Setup > Simulators…, press Edit…
      and then Detect."*). The steps are spelled out because the Simulators window has
      no Detect button of its own: Detect is in the row editor that window's `Edit…`
      button opens for the entry selected in its list;
    - none is, none is untried, and an entry's answer is not known: *"None of the
      simulators you have registered is known to. Register an ngspice build that saves
      terminal currents inside subcircuits under Setup > Simulators… and run again, or
      place an ammeter (ammeter.sym) in series with the pin."*;
    - every entry was measured unable: the same with *"None of the simulators you have
      registered can."*;
    - nothing is registered: the same without its first sentence.

    `tail before` ends each sentence that ends *"and run again"* with *"before you run"*
    instead. The door is the Setup menu's `Simulators…` entry
    (`ase::ui::simulators_dialog`), spelled as the menu spells it.

    **The verdicts about an entry** (`ase::probe_cure_peek`, `ase::probe_cure_verdict`):
    `can` and `cannot` are measured answers (`can` only for a program also measured to
    simulate, `usable`); `unknown` is an entry that was asked and gave no answer to the
    question, one the cure held to be slow, or one the cure does not ask (registered as
    not runnable, no program at its file, a backend with no probe: row PH12c of
    `test_ase_probe_deck_1724` reads each at a peek, and row TPV6b of
    `test_ase_terminal_pick_1724` the first two at a click); `untried` is an entry
    that the cure can ask and has not. "Registered as not runnable" is read from what
    registering recorded, not from the file as it is now: an entry whose file was
    repaired afterwards stays `unknown` to the cure until it is registered again (OK in
    the row editor), although Detect measures it and a run on it starts it by then --
    **measured** 2026-11-20 on a copy of `ver_53`; issue 1724's Limits has the run. An entry that is not `can` is never recommended,
    and one that is not `cannot` is never ruled out. `untried` exists so that "nobody has
    asked yet" does not send the user to register another build: **measured** 2026-11-20
    on a copy of the user's registry and bench, a pick made after a run that had asked for
    no such current read *"None of the simulators you have registered is known to.
    Register …"* and the run one gesture later read *"ng_w_stb and ver_53 can"*.

    **`mode peek` starts nothing**: an entry's answer is read from the capability store
    (`ase::sim_caps_have`) or from the cure's own record, and every other entry is
    `unknown` or `untried`. It is what a click uses. **`mode ask` may start a registered
    program** that is `untried`, and is what a run uses. It is bounded
    (`ase::probe_cure_entries`): one call spends at most `ase::probe_cure_ms` starting
    programs; a program with entries still to be asked behind it is not given all of what
    is left -- `ase::probe_cure_each_ms` is kept back for each of them, up to half of
    what is left -- so that one program that never answers does not cost the entries
    behind it their turn; an entry whose share would be under `ase::probe_cure_min_ms`
    is left `untried` for the next call; a program that did not answer in a fair share of
    the call (`ase::probe_cure_fair`) is not started again by the cure until the
    capability store is cleared, the registry is edited or its file changes, and one cut
    after less than that is asked again by the next call; and an answer the lowered
    budget cut short is not left in the capability store, where a run would read it. The
    shipped figures are held by row PH13b of `test_ase_probe_deck_1724`.

    **What the cure knows is kept under the program, and over an edit of the registry.**
    Its own record (`ase::probe_cure_seen`) is keyed on the program file's stamp and the
    words the program is started with (`ase::probe_cure_key`), so two entries for one
    program share an answer and a program rebuilt in place is asked again.
    `ase::sim_register` and `ase::sim_unregister` still empty the capability store (issue
    0950) and carry the answers `can` and `cannot` over the edit
    (`ase::probe_cure_carry`); `slow` is not carried. So a click made after the user has
    added an entry still names the one that can.
  - **How a sentence names the program of a run**: `ase::sim_run_name <backend>` -- the
    file when no registered entry is in force (`/usr/bin/ngspice`), `<entry> (<file>)`
    when one is, the backend's own word for a backend whose run command does not start
    what the registry holds. `ase::run_deck` resolves it once and carries it in the run
    record (`simname`), so the report names what the run started.
  - **Before the run.** `ase::probe_start_report`, called from `ase::run_deck` directly
    under the sentence that says which registered simulator the run is starting: when the
    capability answer for the program in force is MEASURED `hier_probes` 0 (read from the
    peek `ase::cap_report` has just filled) and the deck's plan holds a terminal that needs
    the hierarchy, *"ase: <program>, the simulator this run is starting, cannot save the
    terminal current i(x1.xm1:d): it saves terminal currents only on top-level devices
    that are not subcircuit instances. <cure> This run goes on without that current."*
    (several: *"the terminal currents A, B and C"*, *"without those currents"*). Said as
    an error on every such run. The run is not refused. An unmeasured program is not told
    it cannot. **A run on a program measured unable whose plan holds NO such terminal
    says nothing and asks the registered entries all the same** (`ase::probe_cure_entries`
    in `ask` mode, bounded as above, and starting nothing once each has been asked): a
    click starts no program, so it can name the entry that can only if a run found out.
  - **After the run.** `ase::probe_report {state meta data {exitcode 0}}`, called from
    `ase::run_done` directly under the operating-point report and caught like it, says at
    most one sentence per asked terminal, the first of these that applies:
    - *withheld*: *"ase: no probe was written for the terminal current i(k1:n1): k1 is a
      coupling between inductors and has no terminal. To measure it, place an ammeter
      (ammeter.sym) in series."*
    - *refused*: *"ase: the simulator refused the terminal current i(x1.nope:d) (.probe
      I(x1.nope,d)): no instance named x1.nope."* The reason is the simulator's own. A
      refusal is matched by CONTENT on the card's path and pin, without case, `,` or `:`
      (`ase::probe_refusals`), in both shapes the simulator prints:
      `probe: I(<path>:<pin>) not inserted: <reason>`, and `.probe i(<dev>,<pin>) will be
      ignored` with its `Warning:` line directly above. Each refusal is said once, however
      often a reloading deck reprints it. It is NOT said when the judged results hold a
      vector of the row's own name: over `.subckt blk 3 2 7` with no header in reach, the
      card `I(x1,3)` makes `i(x1:7)` while `I(x1,7)` is refused, and calling the row
      `i(x1:7)` refused would contradict the results beside it.
    - *missing*, when the judged results hold other terminal currents of the same instance:
      *"ase: the terminal current i(x1.m2:b) is not in this run's results under that name:
      the deck asked for it (.probe I(x1.m2,b)), and for x1.m2 the results hold
      i(x1.m2:b_tj). Name the row after the one meant."* The card was taken and the
      simulator called the vector something else.
    - *missing*, when they hold none: *"ase: the terminal current i(x1.xm1:d) is not in this
      run's results: the deck asked for it (.probe I(x1.xm1,d)) and the simulator neither
      made the vector nor said why."*

    A refused or missing **numbered port whose position could not be looked up** says why
    (`ase::probe_nohdr_note`; behind the refused sentence, and in a missing one after *"…
    the deck asked for it as .probe <card>."*): *"The simulator reads a number in a .probe card as a
    position, not as the port of that name, and ASE-L did not find one .subckt header for
    <subcircuit>, in this run's netlist or in the model files it names, to turn the port
    named <n> into its position. Name the model file that holds that header under Setup >
    Model Files and run again."* Where it is the instance's card that was not found, the
    sentence ends *"… found no card for the instance <path> in this run's netlist, so it
    could not turn the port named <n> into its position. To measure it, place an ammeter
    (ammeter.sym) in series."*

    **A simulator that answered 0 saves no terminal below the top level**, and its own
    words for that (*"Could not find the instance line for x1.xm1"*) read like a mistyped
    name. So when the run's log shows `ASE-PROBE-VERSION 0`, the terminals that need the
    hierarchy (`ase::probe_needs_hier`) and were refused or are missing are reported
    TOGETHER, in ONE record of kind `hier` whose second word is the list of them, in place
    of their own records and at the place of the first of them: *"ase: <program>, the
    simulator this run started, cannot save the terminal current i(x1.xm1:d): it saves
    terminal currents only on top-level devices that are not subcircuit instances.
    <cure>"* (several: *"the terminal currents A, B and C"*). `<program>` is the run
    record's `simname`; `<cure>` is `ase::probe_cure` in `ask` mode. The sentence is minted
    in `ase::sim_why` (kind `probe_hier`) and said through `ase::sim_say`. A terminal of a
    top-level device that is no subcircuit instance keeps its *refused* or *missing*
    sentence on such a build too, and nothing is added for it: such a build probes it, so
    the build is not the cause. (Until 2026-11-20 each such terminal kept its refusal and
    one note, *"this simulator probes only top-level devices …"*, record kind `oldbuild`,
    stood behind them; that note is gone.)

    What the report said is kept for Direct Plot (`ase::probe_said_keep`, the variable
    `ase::last_probes` beside `last_run`): the results file it is about, the run's name
    for its program, the plan's terminals, those of the `hier` record, the reason given
    for every other one, and the session that asked for the run (`session`, from the run
    record: `ase::run_deck` takes it with `ase::session_holding` -- two state views of one
    bench can write one results file). It is taken when the run STARTS and read from the
    record, not asked again when the report is made: a session edited while its
    simulator runs no longer holds the state the run was handed, and is still the session
    whose run it was (row PH37 of `test_ase_probe_deck_1724`, through `ase::run_deck`;
    row TPV13 of `test_ase_terminal_pick_1724` for what Direct Plot then says). A run
    that starts empties it when it is about the results that run replaces
    (`ase::probe_said_clear`).

    Behind those, at most one note:
    - when the exit code is not 0, the plan wrote at least one term and the log holds a
      convergence failure (`timestep too small`, `DC solution failed`, `no convergence` or
      `operating point could not be simulated`, in any case): *"ase: this run did not
      converge, and its deck asked for <N> terminal
      current(s). Each one puts a zero-volt source in series with its pin, and that alone
      can stop a run that finishes without it. Switching those rows off -- unticking Save
      and Plot on a Saves row, removing or disabling a Measures or measurement row that
      reads a terminal -- may let the run finish."* (record kind `note`). **Measured** on
      `ver_53` and on apt 45.2, sky130 `tb_ft_test_2`: one terminal row on M1's drain turned
      an exit-0 transient into `Timestep too small`, and a hand-placed 0 V source at the same
      pin fails the same way. Any other failed run has another cause and gets no such note.
      The simulator's `singular matrix` line is not in the key: it is a warning that is
      printed on the way to a solution too. **Measured** on both binaries: a bench with a
      capacitively coupled node prints it and finishes at exit 0. So a healthy run that the
      user stopped, or that failed later for another reason, is not told it did not
      converge; a real unsolvable operating point always prints `Error: The operating
      point could not be simulated successfully.` -- with `timestep too small` beside it
      only when the transient-op rung was tried, and `DC solution failed` only from the
      `op` analysis -- and still is, also when the Convergence form has switched that rung
      off (deck line `optran 1 1 1 0 10u 0`). **Measured** on `ver_53` and on apt 45.2 for
      ac, tran, a dc sweep, noise, pz and sens: with the rung off the log holds that line
      and none of the other three. `iteration limit reached` is not in the key either:
      the pole-zero search prints it in a warning (`Pole-zero iteration limit reached;
      giving up after N trials`) and the run goes on to exit 0, on both binaries;
    - when the exit code is 0, the plot sidecar and the results file are there, no plot was
      judged (next item), at least one noise, tf, pz or sens analysis is enabled and EVERY
      other enabled analysis is one of those four or a sweep of a design variable
      (`ase::probe_row_swept`, the `dcvar_plan` hook):
      *"ase: the terminal current i(r1:n1) is not in this run's results: the run made only
      noise, transfer-function, pole-zero or sensitivity analyses, and none of those keeps a
      terminal current. Enable an operating point, a dc sweep of a source, an ac or a
      transient analysis and run again."* (record kind `note`; several rows: *"the terminal
      currents <a>, <b> are not …"*). With a sweep among them the sentence names it: *"…
      or sensitivity analyses beside a sweep of a design variable, and none of those keeps
      a terminal current. …"* (two or more: *"beside sweeps of design variables"*); with no
      sweep enabled the sentence is unchanged. It names each terminal whose card was
      written and not refused and whose vector no plot of the file holds under any wrapper.
      Those are the rows the "no single-point value" note leaves out (R-OUT5), so each row
      is spoken for once: a sens-only run lists `v(r1:n1)`, that older note names the row,
      and this one does not. Without it such a row had an empty Value and no sentence
      anywhere.
      **Beside a sweep, a row that reads the sweep by its qualifier is left to the sweep's
      own advice.** Measured on the real road: beside a noise analysis
      `ase::backend::ngspice::dcvar_output_refusals` still speaks, before the run and in
      the row's Value, for a row such as `is(r1:n1)`, alone or inside an expression. A
      terminal that only such rows ask for is not named in the note; one that any other
      row asks for is (`ase::probe_asked` with those rows passed over), under the spelling
      asked first. The sweep's qualifier is `is(…)`; `idc(…)` reads the operating point.
      **Not said:** with an `sp` analysis enabled (its plot holds the probed vector), with
      a `dc` sweep of a source or an operating point enabled (the row then has a value),
      and for a sweep of a design variable that is the bench's only analysis, which keeps
      its own advice.
  - **Which plots can say a vector is missing.** Measured on `ver_53`: a probed vector is in
    the op, dc, ac, tran, disto and sp plots and in none of the noise, tf, pz and sens plots,
    and a design-variable sweep's plot holds only what its loop copies. So the vector is
    looked for only in the plots of rows whose result vectors are netlist names
    (`ase::analysis_resultvecs`) and that are not a `dcvar_plan` sweep, and it is missing
    when none of those holds it. A run that wrote no such plot says nothing about missing
    vectors, and so does a run that failed or left no results file. The one thing said for
    a run with no such plot is the note above, for a bench of only noise, tf, pz and sens
    analyses, with or without sweeps of a design variable beside them.
  - **An older simulator is not refused a run.** The card is written for every build. A
    build answering 0 probes a top-level device that is not a subcircuit instance, by
    position and under the same vector name, and refuses every other probe with a warning at
    rc 0; the report then names each one.
  - **Reading the row back.** xschem's raw reader stores every `:` of a variable name as
    `.`, so the vector is `i(x1.xm1.d)` in the viewer, the Calculator and `xschem raw …`. The
    row's colon spelling resolves through rung 5 of the lookup ladder
    (`doc/claude/specs/raw_case_mode.md` §9). ASE-L's own file readers
    (`ase::raw_vectors_present`, `ase::raw_scalars`) keep the colon.
  - **Declared limits.** The pre-flight does not check a terminal row. A hand-typed bus
    range `i(xb[1:0]:out)` holds two colons, is not a terminal, and stays an inert `.save`
    card. A typed row with a signed number for the terminal, `i(rt:-1)`, is taken as a
    terminal: its card `I(rt,-1)` made the operating point fail to converge on `ver_53`,
    and the convergence note is then said. A bench whose ONLY enabled analyses are two or
    more sweeps of a design variable leaves an unqualified terminal row with an empty Value
    and no sentence: none of the sweeps is the bench's one analysis, so
    `dcvar_output_refusals` judges no unqualified row, and none of the four kinds is there
    to bring the note (row PL15f pins that silence; measured on the real road with states
    written by hand). Beside a sweep the note was run on the simulator for a noise analysis
    (row PA8h); for tf, pz, sens and two sweeps it is fenced from written files (rows
    PL15e, PL15e2). Under `distinguish` two rows that differ only in case count as one when
    the note decides which terminals are still asked for. The netlist's own `.probe`
    terms are compared as text. An `sp` plot holds probed vectors but is not asked about a
    missing one. A numbered
    port of an instance below a subcircuit whose BODY is in a model file is not followed
    (`nohdr {call …}`, the ammeter sentence). A probe's source is a device to a `sens`
    analysis: each probed terminal adds entries to that plot, and nothing in ASE-L lists a
    sensitivity result today. Under `preserve`, no card spelling gives the two terminals of
    a top-level expression source (`vol=`): the lower-case card ASE-L writes is refused and
    the report relays the simulator's reason. A run that requests `distinguish` (its plan
    and its deck are fenced, the run is not), an older build (its report sentences are
    fenced from synthetic log text) and the cards beside the operating-point tier's block
    are run by no row. The convergence note is fenced from log text, and against a run
    that really fails to converge by one real-simulator row: an operating point that
    fails with the transient-op rung off (PN13b). The transient's `Timestep too small`
    form of it is run by no row (the failure lines were measured on both binaries by
    hand). A `tf` analysis goes on after a failed operating point. Where the failed solve
    leaves no singular matrix (**measured**: a comparator loop, with the transient-op rung
    on and off, both binaries) the run ends at exit 0, so a bench whose only analysis is
    `tf` gets no convergence note there: it gets the note for a bench of only noise, tf,
    pz or sens analyses. Where it does leave one (**measured** with the rung off: an
    inductor loop, a node with no dc path) the simulator aborts in the `tf` solve at a
    nonzero exit and the note is said. No row pins either case.
  - Suite `tests/headless/test_ase_probe_deck_1724.tcl`: bands PS (the predicate), PX (no
    card and no pre-flight row; the leader), PU (`ase::saves_unresolved`), PP (the plan:
    Saves rows by their ticks, Measures rows and measurement rows always), PQ (a port whose
    name is a number, and the header reader), PR (the rendered deck), PL (the report, from
    synthetic logs), PW (the plan carried and the report called), PA (the other readers of
    an output row), PN (real runs) and PE (from a click on the sheet, through the rendered
    deck and a real run, to the vector in the results). PN, PE and rows PA8g and PA8h are
    announced by a `skip:` line where no ngspice answers `$?probe_version` = 1. Rows by
    subject: PS1d, PR11b and PR11c (the characters that are no terminal); PX7, PR11d, PN12
    and PN12b (an expression's read of a name no `.save` card can carry: no card, the deck
    equal to the bench without the rows, a real run that ends at exit 0, and the control
    that each such card written back by hand stops the simulator); PR15 to PR18 and PN10,
    PN10b, PN10c (a term the netlist already holds, also under `preserve`); PL28, PL28b,
    PL29 and PL29b (the convergence key with the transient-op rung on and off, and the
    `singular matrix`, `stepping failed` and pole-zero `iteration limit reached` warnings
    that are not in it); PN13 and PN13b (a bench that converges only on the transient-op
    rung, and the same bench failing with that rung off, on the real simulator; the other
    failure lines these two and PL28b look for are read out of the key of
    `ase::probe_report` itself, and a PD0 fixture row goes red when that key cannot be
    read); PL15,
    PL15b to PL15d and PA8g (the note for a bench of only noise, tf, pz or sens; PA8g on
    the real simulator); PL15e, PL15e2, PL15f, PL15g, PL15h and PA8h (that note beside sweeps of a
    design variable: said, in the plural, when not, which rows it leaves to the sweep's
    advice, the asking body, and PA8h on the real simulator); PN11 (`i(v1)` equals
    `i(v1:n1)` and is the negative of `i(v1:n2)`).

### A Stop keeps what the run had (⚖ R1's always-salvage requirement)

Stage 6f. A long transient is checkpointed so that stopping it yields the points
already computed instead of nothing: `stop after <points>`, never `stop when
time` — which hands the integrator a breakpoint, changes both the grid and the
byte count, and is **not disarmed when it fires**. Eligibility floor: **100,000
points**; below it the deck is byte-identical to one rendered with checkpointing
off.

**What a stopped run is told** (`ase::ckpt_report`, once, as a note that opens
*"ase: salvage -- "*), the first of these that applies:

- its checkpointed analysis had already been written — the sidecar holds that
  row's record and the results file lists the plot at the record's place
  (`ase::ckpt_finished`): *"this run was stopped after its 'Transient Analysis'
  plot was written: the results file holds it at <N> points, with every analysis
  that finished before it. The op analysis in row 0 did not finish."* (the last
  sentence names every enabled row that left no record, and is left out when
  there is none). A deck that runs its operating point last runs it behind the
  transient, so a Stop under it lands here (issue 1657);
- no checkpoint is on disk: *"this run was stopped before its first checkpoint,
  so the analysis that was running kept nothing. The analyses that had already
  finished are in the results file."*;
- otherwise: *"this run was stopped: the analyses that finished are in the
  results file, and the '<plot>' plot the simulator was still filling was kept
  at <N> points of an estimated <M>, in <file>."*

⚠ **AN EMITTED LOOP'S EXIT MUST BE THE FALSE BRANCH.** `.control`'s `if` takes
the **false** branch for an *unevaluable* condition — measured on both binaries,
for `<`, `>` and `>=`. A loop whose *continuation* was the true branch spins
forever at **rc 0**, with nothing on either stream, the moment the analysis it
tests never ran.

### The save list, and the four analyses one ticked output used to stop

Stage 6g, issue **1434**, and the sharpest measured behaviour in the subsystem.

ASE-L emits one `.save <signal>` card per ticked plain row of the Outputs pane
(since 2026-10-11 an expression row contributes the signals it reads instead,
R-OUT3), and one ticked output is the shape of every committed bench here. Measured on both
binaries, identically:

| deck | result |
|---|---|
| a narrowed save + `noise` / `tf` / `sens` | rc 1, `$sim_status` 1 — the guard fires |
| a narrowed save + **`pz`** | **rc 0, `$sim_status` 0** — ⚠ the guard NEVER fires |
| a narrowed save + `op` / `dc` / `ac` / `tran` / `disto` | rc 0 — not in the class |
| a save list resolving to **nothing**, any of `op`/`dc`/`ac`/`tran` | rc 1 |
| a save list resolving to **nothing**, `disto` | **rc 139, SIGSEGV** |

**Two classes, and they are not the same defect.** Class A is "these analyses
answer in vectors that are not netlist names, so they cannot run under a save
list made of them" — `noise`, `tf`, `pz`, `sens`. Class B is "the save list
resolves to nothing", which starves *everything*.

⚠ **`pz` IS IN CLASS A AND IS ITS QUIET MEMBER.** Three documents in the batch
recorded it as the exception that survives. It does not, and on an ordinary
bench — where an `op` row precedes it — the second `write` emits **the operating
point again** while the sidecar labels it as the `pz` row's plot. A wrong answer
wearing a right answer's label, at rc 0, with no guard to catch it.

The mitigation is one deck line. `render_deck` forces a `.save all` leader, with
**three separate grounds** that are not interchangeable: the user's own Save-All
tick; class A's correctness need (unconditional — the run does not happen
without it); and the phantom duplicate column some builds write beside a lone op
save (gated on a measured capability, never a version).

⚠ **AND SO `vecsaves` ADVISES RATHER THAN REFUSES.** It shipped as `fatal` in
issue 1432 and was demoted to `caution` in 1434. Once the emitter makes the run
correct, a refusal on the same condition is a **false** refusal. It is not
deleted, because it is the only thing that tells the user their narrowing was
overridden — *nothing the deck contains may be unshowable in the window*.

### What binds anyone working here

* **A row whose fixtures never disagree cannot fail.** Seven separate sections
  of this batch shipped a green row that asserted nothing, and each was found by
  a sabotage that should have reddened it and did not. Check a new row's
  fixtures actually differ **before** the campaign, not after.
* **Measure the exception before the rule.** The exception is what makes a rule
  feel finished, so it is the claim nobody re-takes — and `pz` was both wrong
  and the worst case in its set.
* **Read a precondition's stand-down list as a specification for the emitter.**
  `vecsaves` stood down three ways, and every one of them was *"…because
  something else emitted the leader"*. The fix sat inside the refusal, written
  out, for a whole commit.
* **Before adding a filter to a reader, list its CALLERS and ask which of them
  is measuring something.** A filter added to the capability probe's own reader
  makes the probe answer wrong about the very defect it detects — and the deck
  goldens stay green, because the emitter it feeds has been switched off.
* **Check the quiet member of every set.** A fix that only moves an error code
  is not finished.

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
  before the first run. Since 2026-10-11 every row is computed after the run
  from the results file (R-OUT1..R-OUT6): a number, `wave`, or the
  Calculator's refusal sentence. Name shows the user-given name if named, else as
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
            wires → voltage / device pins → terminal current /
            source bodies → source current; ESC ends)
- `X`     → Delete current selection (noun-verb, single-pane selections)
- `N&>`   → Netlist and Run
- `>`     → Run (existing netlist)
- `!`     → Stop
- `~`     → Plot outputs and update values (Ctrl-click: values only) (R-OUT12, R-OUT16)

**Select On Design v1 scope** (item 08; applies to the `-->` choose-from-
design flow, both Outputs > To Be Saved/Plotted > Select On Design and
Results > Direct Plot; the pin arm is issue 1724, 2026-11-19). One click,
`ase::ui::sod_click`. A click in a window that shows neither the session's
design nor a sheet below it queues nothing and says so (T12); otherwise it
is classified in this order, first match wins:

1. **a device pin under the cursor** queues the current into that terminal,
   `i(<path>:<tname>)` — see *A click on a device pin queues its terminal
   current*, below. A click on a wire, off the pin's own square, is not on
   the pin (T3) and goes on down this list;
2. **the body of a SOURCE-class instance** (symbol `type` ∈ {vsource,
   ammeter}, `ase::ui::sod_source_at`) queues the source-current output
   `i(<instname>)` — a source has exactly one branch current, so a click
   anywhere on its body is exact;
3. **a wire, a net label or anything else that resolves to a net**
   (`ase::ui::sod_net_at`) queues the voltage output `v(<net>)`;
4. **anything else that was hit** queues nothing and reports
   *"ase: nothing to queue there — click a wire or a net label for a voltage,
   an instance pin for its terminal current, or a voltage source/ammeter for
   its current"*;
5. **empty canvas** queues nothing and says nothing.

Generated tokens are lowercased unless the session's simulator is asked to
keep case (`ase::ui::sod_expr`, `ase::ui::sod_case_mode`). Queueing dedupes
on the exact expression string: an existing row gets the flavor's plot/save
flags ORed in, an identical re-queue writes nothing. The mode's entry echo
names all three picks (`ase::ui::sod_entry_notice`): *"… click wires/net
labels for voltages, pins for terminal currents, sources for currents; ESC
ends"*, and for Direct Plot *"… for voltage traces, pins for terminal
currents, sources for current traces; ESC plots"*.

**A click on a device pin queues its terminal current** (issue 1724,
BUILT 2026-11-19; reviewed twice and repaired after each review the same
day, then repaired a third time for what the second repair had measured and
handed back, reviewed a third time and repaired a fourth time; that repair
was verified, and a closing pass built what the verifiers listed; that
pass was verified too, and a last build built what was ruled in of its
verifiers' list; the
marker of T11 and the mode rules of T12 came with the repairs). The
user: *"when I'm not in any mode, if I put
the cursor on a terminal (such as instance pin) and click, it selects the
pin. So, why am I unable to save a terminal current in ASE-L"*. The deck
half is R-OUT17.

- **T1 — the pin test runs first and in its own proc.**
  `ase::ui::sod_terminal_at {key x y}` answers the pin or nothing;
  `sod_click` only calls it, ahead of the source rule. It reads only
  (`xschem pin_at -all`, `doc/claude/specs/pin_selection.md` §4.6, and
  `xschem object_at`, `wire_coord`, `pinlist`, `instance_pin_coord`,
  `instance_bbox` and `instance_coord`) and does not depend on
  `en_pin_select`. Called without coordinates (the canvas
  binding) the pin test uses the RAW cursor (`xschem get mousex`/`mousey`);
  the rest of the click keeps the snapped pair. With the snapped pair any
  click within half a grid step of an on-grid pin would be that pin, and no
  wire end near a pin could be picked for its voltage. A pin test that raises
  is announced and the click goes on as a wire or source pick.
- **T2 — in range.** A pin counts when the pin-select click would reach it
  AND it is within 10 schematic units. The first is `xschem pin_at -all`'s own
  test: the cursor is within `12 * zoom * tk scaling` of the pin's point (a
  fixed distance on screen, so it grows in schematic units as the view zooms
  out), or inside the pin's own drawn rectangle. The rectangle keeps the
  whole square the pin when the sheet is zoomed in until the radius is
  smaller than the square (`point_in_inst_pin_rect()`, pin_selection.md
  §4.2). The second bound keeps the body of a source pickable from far away,
  where the on-screen radius alone reaches from a source's pin to the middle
  of its body. A wire is kept by T3's wire rule, not by this bound. Beyond
  the square the device's lead is the terminal only as far as the radius
  reaches: zoomed far in, a point a few units down the lead is not the
  terminal (declared; row TPR26).
- **T3 — which pin, and when a wire wins.** Pins in range are ordered by
  distance. A pin of something that is not a device, strictly nearer than
  every device pin, makes the click the ordinary voltage pick. At equal
  distance the device wins: a `lab_pin` placed ON a device pin gives the
  terminal at the shared point and into the label's text as far as the range
  of T2 reaches, and the net's voltage beyond it. Among device pins the
  nearest wins.
  - **A net label's box near a device pin** (declared; row TPR23). A label
    that is not on the pin, but whose box reaches within the range of T2, is
    the terminal's there, except within the wire tolerance below of a wire:
    a point in the label's box beside the wire queues the terminal, the same
    point on the wire queues the voltage. For the net's voltage the user
    clicks the wire, or the label farther from the pin.
  - **A click on a wire is the wire.** The nearest device pin does not take a
    click when the cursor is outside the pin's own box (2.5 units either side
    of its point, the square the stock symbols draw) and one of two tests
    says it is on a wire; either is enough.
    - `ase::ui::sod_wire_wins`: `xschem object_at` there is a wire, and the
      cursor's foot on that wire lies on the wire, not past either end, and
      outside the box. The last test keeps the lead: a wire's pick tolerance
      reaches past its end onto the lead of the device it ends on, and there
      the foot is beyond the wire's end.
    - `ase::ui::sod_wire_near`: some wire's nearest point to the cursor,
      taken ON THE WIRE (at one of its ends when the foot falls past it), is
      within 2.5 units or one and a half screen pixels, whichever is more,
      and outside the box. This test does not trust `xschem object_at`, which
      scores an instance by the distance to the EDGE of its box: a net label
      whose box lies along a wire, or the device's own box near its edge, is
      then the answer for a cursor a fraction of a unit off the wire, which
      is where a pixel's centre usually is. Held to the wire's ends, the
      nearest point of a wire that ends on the pin is the pin's point past
      that end, inside the box, so the lead stays the terminal. It reads
      every wire of the sheet (`xschem wire_coord`), so it is asked only once
      a device pin is in range and the first test has said no.

    So the pin's square is the pin and the wire is the net, at any zoom.
    **Measured** on scratch copies of the shipped `sky130_tests_ase` sheets
    at their fit view: without a wire rule a short wire between two device
    pins had no point left on it that picked its net; with the first test
    every net that a wire click picked at HEAD has a wire point that picks it
    again, and every device pin keeps a pixel of its own.
    **Measured 2026-11-19 with real pointer motion** on such sheet copies,
    over wire points near a device pin that queue a voltage at HEAD (the
    counts are in the review's scratch and are not written here: no row
    re-checks them): with the first test alone a share of those points became
    a terminal, at the nearest pixel and one pixel to either side; with both
    tests a handful were left, all on sheets whose fit view is so far out
    that the pixel's centre or the wire's nearest point is inside the pin's
    own box. No device pin lost every pixel, and the points up a device's
    lead that were the terminal still are.
    Declared: two pixels off a wire, inside a label's box, a click within
    range of a device pin is still the terminal's when two pixels are more
    than 2.5 units.
  - **Several device pins on the very same point** (two abutting devices) are
    equally near wherever the cursor stands. The device on whose SIDE of the
    point the cursor stands is taken. The side is the cursor's offset from
    the point, projected on a direction from the point, and there are two
    such directions:
    - *to the middle of that instance's pins* (`ase::ui::sod_term_toward`);
    - *to the middle of the instance's box* (`ase::ui::sod_term_toward_box`).
      The box is the SYMBOL's, without its texts: the `Symbol:` line of
      `xschem instance_bbox`, put on the sheet by the origin, rotation and
      flip that `xschem instance_coord` prints
      (`ase::ui::sod_term_box_centre`). The `Instance:` box is not used: it
      holds the symbol's texts, and a title that reaches over a neighbour
      moves its middle to the neighbour's side. The placement arithmetic is
      held against the engine's own `Instance:` box in all eight placements
      (four rotations, plain and flipped) of a symbol with no text, where
      the two boxes have the same middle (row TPR4s).

    **The two are never compared with each other.** A symbol with every pin
    on ONE edge has the middle of its pins on that edge, and a one-pin symbol
    has it on the pin: towards it is along the edge, or nowhere, and says
    nothing about the side the body is on. `ase::ui::sod_term_edge_on {n px
    py}` answers 1 for such an instance at that point: the middle of its pins
    is the point, or every pin lies on one line through the point while the
    middle of its box is more than 5 units off that line (5 units is the side
    of the square the stock symbols draw for a pin). A resistor answers 0:
    its two pins and the middle of its box are on one line. A two-pin symbol
    whose drawing is lopsided by more than 5 units (the stock `led.sym`)
    answers 1 as well; the box measure still takes the device whose lead the
    cursor is on (**measured** by the fourth repair's verifier on the LED's
    junctions; row TPR4r holds that the LED answers 1). **An instance whose
    symbol uses one pin name twice answers 0** (the shipped
    `examples/xcross.sym`): the proc places pins by name, with `xschem
    instance_pin_coord <n> name <name>`, and for a name used twice the engine
    answers the first pin of that name, so such a symbol's pins cannot be
    placed and nothing is claimed about them. **Measured** before that guard
    (the closing pass; a regression of the fourth repair): on the shipped
    `examples/test_doublepin.sch` shared points were read as edge-on that are
    not, and the device taken changed at points off the leads; with it every
    junction of that sheet answers as before the fourth repair (the closing
    pass's sweep; row TPR4u holds the shape on two instances of that symbol).
    **A pin name that ends in a backslash is read like any other** (the last
    build; symbols of the gschem import library have such pins). Both
    measures ask one reader for the names (`ase::ui::sod_term_pin_names
    {n}`) and read each pin's point off the end of `xschem
    instance_pin_coord`'s answer as text (`ase::ui::sod_term_pin_xy {n
    name}`): for such a name neither `xschem pinlist <n> name` nor that
    verb answers a list (each writes the name between braces as it stands).
    The reader asks `xschem pinlist <n> name` first and keeps its answer
    when it is a list whose every row is a list of two words; when it is
    not, it reads each name off the pin's own attribute string (`xschem
    pinlist <n>` and the attribute reader). The order matters: the list of
    the attribute strings is itself no list when one of them ends in a
    backslash, so a symbol with plain pin names and such an attribute
    beside them is read by its names (row TPR4x; a reader that asked the
    attribute strings alone took its pins for unreadable and measured it by
    its box). It raises only when neither answer can be read.
    No name is expanded as a bus there, which `ase::ui::sod_term_pins` does:
    on a display the engine answers a name it cannot expand with a message
    box that waits, and the prompt asks the pin rule at every hover.
    **Measured** before it: both measures raised on such a symbol, and a
    click on a point it shares with another device queued nothing and said
    *"ase: the pin test of this click failed …"*. Row TPR4w (scratch symbols:
    a two-pin device, a one-pin device and a block).
    **When any
    instance sharing the point answers 1, every sharer is measured by its
    box; otherwise by its pins, with the box deciding between two that the
    pins measure the same.** "Any" is held by row TPR4v, against "the first
    sharer" and against "the last": a one-pin capacitor placed later on the
    sheet than the resistor it shares a point with, and (the last build) a
    second pair whose capacitor is placed earlier.
    **Measured** before this (real presses in the
    mode, several views): with a three-pin block against a five-pin block
    the two pin measures differed at two of the three shared pins, the box
    was never asked, and every press on one block's lead there took the
    other block's pin. With the cursor exactly on the point, or no more
    on one device's side than on another's by the measure in use,
    `pin_at`'s order decides (the lowest instance index, then the lowest pin
    index). Declared: exactly beside a shared point, on neither device's
    lead, where the pins measure the same, it is now the text-free box and
    then the index that decide, where the symbols' texts used to. On the
    shipped sheets that were swept (the examples and the sky130 ASE test
    benches), at shared points with no edge-on instance on them, that
    changed the device taken only at points exactly on an axis through the
    point, where the lowest index is taken now, and at no point on a lead or
    half a unit beside one. At a shared point WITH an edge-on instance on
    it, points on a lead did change, as they were meant to: on sky130
    `test_carry_lookahead` a one-pin capacitor sits on a block's pin, and a
    point on the capacitor's own lead now takes the capacitor, where it took
    the block (measured 2026-11-19 by the fourth repair's verifier, with the
    sky130 libraries registered and the pins listed by index; the counts are
    in the repairs' scratch). The other shipped sheets were swept afterwards
    by the closing pass's verifier: the same two classes, with points shared
    with an edge-on instance on sheets of `sky130_tests` as well (issue 1724,
    Limits, names them) and no lead point lost or gained. Declared too: a block that has every pin on
    one edge AND repeats a pin name is measured by its pins (one shipped
    symbol has that shape, the PCB connector
    `gschem_import/sym/31-71043-1.sym`); and the pin
    measure itself aims at a middle built from the first pin of each name.
    An engine verb that gives a pin's coordinates by index would lift both
    (issue 1724, open items). Declared since the last build: a block whose
    PORT name ends in a backslash is chosen by this rule and then refused at
    the click by T10's sentence for a name a terminal row cannot hold, which
    shows a blank where the backslash is and names a blank as the character
    (`ase::ui::sod_bits` reads the engine's expansion of such a name as a
    list; issue 1724, Limits). The click says
    which one it took (*"ase: that point is also R2 pin P — the click took R1
    pin M"*). The side is not asked of `xschem object_at`: where two symbols'
    boxes overlap, as the pin squares of abutting devices always do, the
    editor's hit test answers the instance whose box edge is nearest, which
    within that band is the device on the far side.

  One click never queues two terminals.
- **T4 — what a device is** (`ase::ui::sod_inst_is_device`), by the
  netlister's own tests: the symbol `type` is none of `label ipin opin iopin
  show_label scope bus_tap noconn probe`; the instance is not ignored
  (`spice_ignore` on the instance or the symbol is `short`, `open` or
  boolean-true as `strboolcmp()` reads it, and the same for `lvs_ignore`
  while that switch is on; `0`, `false` and an absent attribute are not
  ignored, which is what every stock ammeter carries); it is not an
  `only_toplevel` instance on a sheet below the session's design; and its
  netlist format is not empty and does not open with `*` or `.`.
- **T5 — sources.** A pin of a voltage source or an ammeter is a terminal
  like any other (`i(v1:n1)`); a click on its body is unchanged (`i(v1)`).
  Direct Plot has an exception for that pin (T9).
- **T6 — the row is the simulator's name for the vector**,
  `i(<path>:<tname>)`, built by `ase::ui::sod_term_name` without netlisting:
  - *element and position* come off the instance's own netlist line. The
    format is resolved as `resolve_netlist_format()` resolves it
    (`ase::ui::sod_term_format`), each pin token (`@pinlist`, `@@<name>`,
    `@#<n>`) is replaced by a marker, `xschem translate` expands the rest,
    and the pin's position is one plus the widths of the words ahead of its
    marker. The element is the line's first word, never
    `@spiceprefix@name`. A pin left out by its own `spice_ignore` takes no
    position; a pin sharing its name with an earlier one stands where that
    one does;
  - *path* is `ase::ui::sod_rel_path` from `ase::ui::sod_base_level`, then
    the element. The token is already hierarchy-qualified and does not go
    through `ase::ui::sod_qualify`;
  - *`<tname>`* by the element's first letter (`ase::ui::sod_term_letter_name`):
    `m` → `d g s b_tj tc n6 n7`; `q` → `c b e s t`; `j`, `z` → `d g s`;
    `d` → `a c`; any other letter but `x` → `n<position>`;
  - *for `x`* it is the callee's port at that position: the symbol's own pin
    when xschem writes the callee's body from that symbol
    (`ase::ui::sod_term_own_block`); else the `.subckt` header
    `ase::ui::sod_term_ports` finds, asking these places in this order:
    1. the netlist ASE-L last made, while it is current
       (`ase::facts_netlist_text`): that is where an xschem-netlisted block's
       header is;
    2. the `device_model` text the instance puts into the deck, with its
       tokens expanded, and the files that text includes
       (`ase::ui::sod_term_device_model`: the instance's own when it is not
       empty, otherwise the symbol's, as `spice_netlist()` writes it), so a
       header that lives there is known before anything has been netlisted;
    3. the model files the deck will name (`ase::subckt_model_cards`, the
       list the deck side reads a numbered port's position from): the
       session's `includes` and `models` rows and the `.include`/`.lib`
       cards of that netlist. Those cards are still followed after the
       netlist has gone stale (`ase::ui::sod_term_stale_cards`, which asks
       `ase::facts_netlist_file` for the file): a model file does not move
       with a sheet edit, while a `.subckt` written IN a stale netlist
       describes a sheet that has changed since and is not read.

    Files are followed section-aware and relative to the file that names
    them, and remembered until one of them changes (the core's reader,
    R-OUT17). The three places are `ase::ui::sod_term_port_lists`, which
    answers the place that has the name and every DIFFERENT port list there;
    `ase::ui::sod_term_ports` is its one list, and the empty list when it has
    none or several. Two different headers for one callee in the place that
    answers are therefore no answer: which of them the simulator would use is
    not guessed. Failing all of them, the symbol's pin name, with a caution
    that says WHY no header names the port and ends with what to do about
    that (`ase::ui::sod_term_header_gap`, three cases):
    - none is known: *"… no .subckt header for 'fake_res' is known, so the
      terminal is named as the symbol's pin; that is right only if the
      subcircuit names its ports the same way; to be sure, netlist the design
      from ASE-L (or run), or name the model file under Setup > Model Files,
      then pick again"* (the remedy clause is
      `ase::ui::sod_term_header_remedy`);
    - several differ: *"… the session's model files hold more than one
      .subckt header for 'fake_res' and their ports differ, so the terminal
      is named as the symbol's pin; that is right only if the subcircuit the
      simulator uses names its ports the same way; to be sure, leave one
      definition of 'fake_res' in the model files (Setup > Model Files), then
      pick again"*. For the other two places: *"the design's netlist holds
      more than one … leave one definition of '<callee>' in the design,
      netlist it from ASE-L (or run), then pick again"* and *"its
      device_model holds more than one … leave one definition of '<callee>'
      in that device_model, then pick again"*;
    - the one header known is too short: *"… the .subckt header known for
      'fake_res' has 1 port, too few for that pin, which is node 2 of the
      call, so the terminal is named as the symbol's pin; …"*, with the first
      case's remedy.

    A call line written from the INSTANCE's own format, or a `spice_sym_def`,
    never takes the symbol's pin name on trust: it needs a header and is
    refused without one that names the port, in the same three cases and
    with the same remedies (*"… it has a netlist format of its own, and the
    session's model files hold more than one .subckt header for 'fake_rel'
    and their ports differ, so the port at that position is not known; to
    name it, leave one definition …"*; for a `spice_sym_def` header that is
    too short: *"… give the .subckt header in its spice_sym_def a port for
    every node of the call, then pick again"*).
    A port whose NAME is a number is named like any other (`i(x1:3)` for the
    port called 3, wherever it stands): the row is the vector's own name, and
    the card's position is the deck writer's to work out (R-OUT17). A `spice_sym_def` whose format writes its pins with
    `@pinlist` and nothing else follows the netlister
    (`has_included_subcircuit()`): when every port of the definition's
    header, up to the symbol's pin count, is a pin of the symbol, the nets go
    out in the HEADER's order, so the terminal is the header port named as
    the pin. In every other case the symbol's order stands and the port is
    the one at the position.
- **T7 — several vectors open the bit dialog.** A bus instance, a bus pin or
  both give one token per instance bit and pin bit; `ase::ui::bus_dialog`
  lists the final `<path>:<tname>` tokens and Cancel queues nothing.
- **T8 — Outputs flavours** queue the row through `ase::ui::sod_queue`; it
  sorts into Saves (R-OUT7).
- **T9 — Direct Plot queues a terminal only when the last run saved it.**
  The plot flavour writes no session row, so the next deck would carry no
  probe for the pick. The trace is queued when the session's results file
  lists the vector (`ase::raw_vectors_present` on `ase::last_rawfile`; no
  viewer and no loaded database needed) and otherwise the click says why the
  results do not hold it, where that is known, and what to do next
  (`ase::probe_absent_groups`), each sentence opening *"ase: terminal current
  'i(x1.xm1:d)' is not in this session's results"* (several vectors of one
  click that share a reason: *"terminal currents 'a', 'b' are not …"*):
  1. the last run's report said its simulator cannot save it (the `hier`
     record of R-OUT17, kept in `ase::last_probes` for these results): *"…:
     <program>, the simulator of the last run, cannot save it. <cure>"* -- the
     cure of `ase::probe_cure` in `peek` mode, so the click starts no program.
     `<program>` is the name that run gave its program. Where the program
     THIS session starts is already known able (`ase::probe_session_verdict`)
     the cure has been taken and the sentence ends *"<entry> is picked now —
     run again."* (a session that starts no registered entry: *"<file>, which
     this session starts now, can — run again."*);
  2. that report gave another reason (withheld, refused, missing, an analysis
     that keeps no terminal current): the report's own reason as a clause,
     one sentence per terminal -- *"…: in the last run the simulator refused
     it (.probe I(r5,3)): Node zz is not available for device r5."*, *"…: in
     the last run no probe was written for it: <reason>. To measure it, place
     an ammeter (ammeter.sym) in series."*, *"…: in the last run the deck
     asked for it (.probe <card>) and the simulator neither made the vector
     nor said why."*, *"…: the last run made only noise, transfer-function,
     pole-zero or sensitivity analyses, and none of those keeps a terminal
     current. Enable an operating point, a dc sweep of a source, an ac or a
     transient analysis and run again."*;
  3. the session asks for the terminal now (`ase::probe_asked`) and the last
     run said nothing about it. What is said of the results depends on what
     is known. The session has no results in view, *"…: it is set to be saved,
     and this session has no results yet — run."*; the last run's report is
     about these results, the run was THIS session's and its plan did not
     hold the terminal, *"…: it is set to be saved, and these results are from
     before that — run again."*; otherwise (the run on these results was
     another session's, it did ask and said nothing of it, or nothing is
     remembered about these results: a saved result in view, a restart),
     *"…: it is set to be saved, but these results do not hold it — run
     again."*. **A terminal that needs the hierarchy is not sent into a run
     that cannot save it**: when the program this session starts is already
     known unable, each of them ends instead *"…, but <program>, the
     simulator this session starts, cannot save it. <cure>"* (after *"do not
     hold it"*: *"…, and <program>, …"*; with no results the cure ends
     *"before you run"*);
  4. otherwise *"… — pick it under Outputs > To Be Saved > Select On Design
     and run again"*. A session with no results yet is this case when the
     row is not set, and case 3 when it is.

  Cases 1 and 2 are tried before 3: what the last run said about a terminal
  is the reason also for a row that is set, and the simulator's sentence is
  said ahead of any other.
  **The row flavours say one thing at the pick** (`ase::probe_pick_report`):
  when the simulator this session starts is ALREADY KNOWN unable -- the
  capability store's measured `hier_probes` 0 for it, or, where the store
  holds nothing about that program, the cure's own record -- and the pick
  queued a terminal that needs the hierarchy, *"ase: <program>, the simulator
  this session starts, cannot save that current: it saves terminal currents
  only on top-level devices that are not subcircuit instances. <cure ending
  "before you run">"* (a bus pick: *"those currents"*), once for the click, as
  an error. The click starts no program; the row is queued and the pin marked
  all the same.
  **The program is the clicking session's own.** `ase::sim_use` is one choice
  for the whole process and holds what the last run of ANY session left
  there, so a click reads the program through `ase::sim_session_view`: the
  session's choice put in force as a run of it does, read, and the old
  choice put back.
  **Except on the pin of a voltage source or an ammeter**
  (`ase::ui::sod_terminal_as_source`). When that pin's terminal cannot be
  plotted — none of its vectors is in the results, or T10 refuses it a name —
  the click queues the source's branch current through the steps a click on
  the body takes (kind `current`, the instance coloured): that is what the
  same click plotted before pins were picked, and every run holds it. On the
  source's first pin, alone on its point, nothing more is said. Where the
  trace is not what the click was aimed at, the click says so
  (`ase::ui::sod_source_standin_notes`), in up to two sentences:
  - *other device pins share the point*: *"ase: that point is also RE pin M
    — the click took the current of Vef"*;
  - *the pin is the source's second terminal*: *"ase: V1 pin m — the
    trace is the source's own current 'i(v1)', which is the current into its
    first pin, so the current into V1 pin m is the negative of that trace; to
    plot the pin's own current, pick it under Outputs > To Be Saved > Select
    On Design and run again"*. The last clause is left out when T10 refuses
    the pin a name. **Measured** on `ver_53` (R-OUT17, row PN11): `i(v1)`
    equals `i(v1:n1)` and is the negative of `i(v1:n2)`;
  - *the pin is neither its first nor its second terminal*: *"ase: E1 pin cp
    — the trace is the source's own current 'i(e1)', which is not the
    current into E1 pin cp; to plot that pin's current, place an ammeter
    (ammeter.sym) in series with it"*. When the pin can be named the last
    clause is the Outputs advice of the sentence above instead. Nothing is
    said about a sign. **Measured** on a copy of `ver_53` by the third
    review: for a four-node `E` element the current into nodes 3 and 4 is
    zero while `i(e1)` is the current into node 1. Driven on the two
    controlling pins of the stock `vsource_pwl.sym` and on both pins of
    `filesource.sym`, whose netlist line places neither (its first pin
    stands behind a word that may not be a node, its second is not on the
    line).

  **Which terminal the pin is** is one proc's answer,
  `ase::ui::sod_term_pin_place {term nm}`: `first`, `second` or `other`. It
  is the position in the row's own name when that is `n<position>`;
  otherwise the pin's place on the instance's netlist line
  (`ase::ui::sod_term_line_pos {n j}`, the walk `ase::ui::sod_term_name`
  opens with, so a pin that proc names by position has the same position
  here). A pin the line does not carry, carries more than once, or carries
  behind a word that may not be a node (on any element but a subcircuit
  call) is `other`, and so is a pin of an instance that cannot be read. It
  never raises. The Calculator asks the same proc (calculator.md R208f).
  `ase::ui::sod_term_first_pin {term nm}` is kept, with its answers
  unchanged.

  A source pick is one token whatever the instance's width, so the stand-in
  queues one trace for a bus instance of a source too, as a click on its body
  does. When some vector of the pick is held (a bus source with one bit in
  the results) the held one is plotted and the others get the sentence. The
  three flavours that write rows are not touched by this.
- **T10 — refused at the click**, one sentence naming the instance and the
  pin and ending with the way that always works: *"ase: cannot name the
  terminal current of R1 pin P — <why>; place an ammeter (ammeter.sym) in
  series"*. The refusals are ONE proc's, `ase::ui::sod_terminal_resolve {key
  term}`, which answers `{ok 1 tokens <list> label <text> caution <text>}`
  or `{ok 0 why <reason>}`, never raises, queues nothing and says nothing;
  `ase::ui::sod_terminal_pick` adds one test of its own (the name the deck
  cannot carry, below), and the Calculator's current selectors ask the same
  proc (calculator.md R208f).
  The reasons: `flat_netlist` is on; a block instance between the session's
  design and the current sheet carries a `spiceprefix` in force (issue 0488:
  `sch_path` spells that level by the instance's name, the deck by the
  prefixed element, `ase::ui::sod_term_prefixed_ancestor`); the pin is not
  on the netlist line; *"its netlist format writes that pin N times"*; an
  untagged word stands ahead of the pin on a line that is not a subcircuit
  call; the line starts with a `#` form other than the two `src/spice.awk`
  expands; an instance format or a `spice_sym_def` with no header that names
  the port (none in hand, several that differ, or one too short: T6); a
  naming step that raised.
  **A name the deck cannot carry is refused too**, by
  `ase::ui::sod_terminal_pick` itself, after the resolver and before the bit
  dialog: `ase::ui::sod_term_unwritable {toks cmode}` wraps each token as the
  click would queue it and puts it to the deck side's own predicate,
  `ase::probe_split` (R-OUT17). When a row would not be a terminal row the
  click queues nothing, marks nothing and says *"ase: nothing queued for x1
  pin Y=1 — its current would be the row 'i(x1:y=1)', and a terminal-current
  row cannot hold an equals sign; rename the instance or the port, or place
  an ammeter (ammeter.sym) in series"*. The class is the predicate's whole
  class: a dollar sign, an equals sign, a single quote, a brace, a semicolon,
  a comma, a parenthesis, a double quote, a blank or a second colon; the
  sentence names the ones found. **Measured**: such names reach the pick (a
  block port `Y=1`; instances named `R=9`, `R$8`, `R'7`), while an instance
  written `R;6` reads back as `R`, so a semicolon cannot arrive through an
  instance name. In Direct Plot the pin of a SOURCE with such a name still
  plots the source's own current (T9's stand-in), as for any pin that cannot
  be plotted. A bus instance named `R=B[1:0]` is named `R:n1` by the
  resolver, one token with the equals sign and the bus range gone, so the
  token test is handed an ordinary token (measured 2026-11-19 beside a control
  `RB[1:0]`; the cause was not looked into). The click therefore also puts the
  instance's own name to the same words (`ase::ui::sod_term_odd_inst`, which
  judges no comma, colon or bracket: bus syntax in an instance name) and
  refuses with *"... the instance's name holds an equals sign, which a
  terminal-current row cannot hold; rename the instance, or place an ammeter
  (ammeter.sym) in series"*. Rows TPU0 to TPU6.
  **Declared: a block whose port name ends in a backslash** (measured by the
  last build of issue 1724) is refused by this sentence too, with the right
  remedy and the wrong reason. `xschem expandlabel` answers the name and a
  count, `ase::ui::sod_bits` reads that as a list, and for the port `A\` the
  one element it finds is `A 1`: the row shown is *'i(xw:a 1)'* and the
  character named is a blank. Nothing is queued or marked (a leg of row
  TPR4w). Not built: reading the expansion as text, or naming the backslash.
- **T11 — a pick that queued marks its pin.** One ellipse on the pin the
  click took, however many vectors it queued (`xschem pin_marker`,
  `doc/claude/specs/pin_selection.md` §4.7).
  - *The three flavours that write rows*: layer 16, tag `save`
    (`ase::ui::sod_mark_pin`), also when every row of the pick was already
    in the table. So a pin picked under To Be Plotted has the same
    light-green ellipse as a saved one, and its waveform, which
    `ase::ui::auto_plot` plots after the run, has the viewer's next colour
    and not the ellipse's. Only Direct Plot's ellipse has its trace's
    colour (declared).
  - *Direct Plot*: the pick hands the plot queue the PIN, `{<instance index>
    <pin index>}` of the sheet shown, with the first vector the results
    hold, and `ase::ui::dp_hilight terminal <pin> <layer>` runs `xschem
    pin_marker add -layer <layer> -tag plot` and answers 1. Any other token
    under kind `terminal` answers 0 and asks the engine nothing. The layer
    is the one `ase::ui::dp_queue` takes from `wviewer::predict_colors` and
    hands the viewer, so the ellipse and the trace have one colour. A vector
    that is queued already puts the marker back in the colour its trace has
    (`xschem unhilight_all` may have taken it since); a net or a source
    queued again still colours nothing. Declared: the ellipse keeps that
    colour until the highlights are cleared, so after a run whose plot
    replaces the viewer's traces (a row with Plot ticked, destination
    Replace) it shows the colour of a trace that is gone, or that another
    signal now has. Direct Plot's net and source colours do the same (issue
    0153's persistence).
  - *Nothing is marked* by a refused pick, a cancelled bit dialog, a Direct
    Plot pick none of whose vectors the results hold, a click on a wire
    beside a pin, a click T12 refuses, or the source stand-in of T9 (the
    source's body is coloured instead).
  - *Lifetime.* `ase::ui::sod_end`, `ase::ui::sod_drop` (the window the mode
    was on is gone: T12, and the window-gone arm of `ase::ui::sod_resume`)
    call `ase::ui::sod_marks_clear` (`xschem pin_marker clear -tag save
    -all`): the row flavours' markers go when the mode ends, in every window
    and tab. Markers tagged `plot` stay, as Direct Plot's net and source
    colours do. `xschem unhilight_all` clears both kinds in the window it is
    given in and in the windows and tabs linked to that one by a descend
    (pin_selection.md §4.7), also while the mode is up; a later click on the
    same pin puts the marker back. Given while that window is in the middle
    of a gesture it clears that window only, and the linked ones keep their
    markers with their net colours until it is given again (rows PV1 and PV2
    of `tests/headless/test_pin_marker_1724.tcl`).
  - *Below the top.* A pick made on a sheet below, after a descend with the
    mode up, is marked on that sheet (the marker is keyed by the hierarchy
    path of the sheet shown), and the mode's end from any sheet sweeps it.
  - Every engine call is `catch`-guarded: a marker never breaks the pick.
- **T12 — the mode: what it holds, and how it ends.**
  - *Six slots* on the design canvas, one table (`ase::ui::sod_slots {key}`),
    taken by `ase::ui::sod_seize {key cv}` for the entry
    (`ase::ui::select_on_design`) and for the resume after a descend
    (`ase::ui::sod_resume`), and handed back by `ase::ui::sod_release`, each
    from its own record: `<ButtonPress-1>` and `<Double-Button-1>` (the
    pick), `<ButtonRelease-1>` and `<B1-Motion>` (swallowed), `<Key-Escape>`
    (ends the mode) and `<Destroy>` (below). The previous bindings are read
    from the canvas being seized and handed back verbatim; on a design canvas
    the double click's is the editor's own script (`set_bindings`). A slot
    that already holds one of the mode's own scripts is never kept as the
    previous binding (`ase::ui::sod_own_script`; the bare `break` of the
    release and of the held motion is judged by the press slot beside it):
    kept, the release would put the seize straight back (issue 1305's
    shape). Such a slot keeps the record it has; with none it is taken to
    have held nothing, except the double click, which falls back to the
    editor's script, read from the middle button's double click
    (`ase::ui::sod_dbl_editor`): handing back nothing there would take the
    editor's double click away from that window. The `<Destroy>` hook is
    added behind a handler the canvas already has, not put in its place.
  - *A drag in the mode is one pick* (issue 1304). The held motion is
    swallowed, so a hand that moves with the button down starts no selection
    rectangle; the selection made before the mode is kept and nothing is
    drawn. **Measured** with real events before the slot was taken: a click
    whose pointer moved two pixels with the button down queued its pick,
    cleared the selection and left the editor's rectangle up past the mode's
    own ESC.
  - *The press hands its own position to the engine first.* The script bound
    on the press and on the double click is `xschem callback %W 6 %x %y 0 0 0
    %s; ase::ui::sod_click <key>; break` (`ase::ui::sod_press_script`).
    `sod_click` reads the pointer the engine last heard of, and the engine
    takes the position of every event it is sent; a `<Configure>` of the
    canvas carries the canvas's place in its window, and one can arrive
    between the last pointer motion and the press (issue 1659). **Measured
    2026-11-19**: after a real motion onto a pin, a `<Configure>` delivered to
    the canvas, generated or from a real resize of the window, left the
    engine's pointer far from the pin, and a press there with the earlier
    script queued nothing and said nothing. `sod_click`'s signature and its
    scripted default (no coordinates: the engine's pointer) are unchanged.
  - *The canvas is looked up, not assumed* (`ase::ui::sod_canvas {{ctx
    {}}}`). `xschem get current_win_path` names a context, which is a widget
    only for a window: with the tabbed interface a schematic in a tab that is
    not the first answers a name no widget has, while the canvas that shows
    it is the main window's, which the tabs share. The canvas is taken from
    `xschem windows`, as `calc::pick_canvas` takes it. **Measured** before
    this: with the design in the second tab neither the session's menu
    entries nor Ctrl-4 could enter the mode (*"ase: no design canvas to select
    on (.x1.drw)"*). `ase::ui::sod_resume` resolves the context it is handed
    the same way.
  - *What the mode holds is reported to `cmdmode`* (`ase::ui::sod_held`, the
    fourth argument of the mode's `cmdmode::register` line): for each slot
    the canvas, the sequence, the script bound and the script the slot held
    before; for `<Destroy>` the whole bound script and the canvas's own
    handler. Empty with no mode up and while the mode is paused.
    `clone_canvas_bindings` asks `cmdmode::pristine`, which reads it, so a
    window made while the mode is up (`xschem new_schematic create_window`,
    which the Cadence-style profile's Ctrl-N runs) gets the bindings it would
    have got with no mode up. Clicks there are the editor's, while the mode
    is up and after it, and so is ESC: the mode ends by ESC in the window it
    is on.
  - *A double click is two picks.* Tk hands the second and every further
    press of a multiple click to the most specific binding, and the canvas
    binds the double click itself, so with only the press seized that press
    went to the editor. **Measured** with real events before the change: the
    pick ran once, then the editor's modal property dialog opened and the
    object was selected (stock bindings), or the object was selected with no
    dialog (Cadence-style profile). Now both presses, and the third of a triple
    click, reach the pick; nothing is selected and no dialog opens. A second
    press on something already queued says *"already queued"*.
  - *One click mode on the canvas at a time.* `select_on_design` ends a live
    Calculator pick as its first act (`calc::pick_end cancel` when
    `calc::pick_running`), before the previous mode is ended and before any
    binding is read; `calc::pick_arm` ends a live Select On Design before it
    seizes (calculator.md R307). Both seize the same slots and keep one set
    of previous bindings each, so stacked and ended out of order they left a
    canvas that took no left click (issue 0202). The Results Display
    Window's pick mode is not ended by either and still nests (declared).
    Declared on the Calculator's side: a pick that resolved is one-shot and
    has ended by the second press of a double click, which is then the
    editor's (calculator.md R307).
  - *The Results Display Window's mode, entered on top of the mode that is
    ended, takes the canvas again.* The mode `select_on_design` ends (the
    Calculator's pick, or a Select On Design that is still up) hands the
    canvas what it held before it, the editor's scripts, over the Results
    window's live ones. So after each of the two ends the entry runs `catch
    {rdw::pick_reseat}`, and `calc::pick_end_sod` does the same after
    `ase::ui::sod_end`. That proc (`src/rdw.tcl`) seizes again only when its
    mode is recorded up, is not paused, its canvas is a live widget and the
    press slot holds neither one of its own scripts nor the script of
    another mode that is up; in every other state it does nothing, so the
    call that follows an end that did not happen is harmless. The Results
    window's mode stays up, the new mode stacks on it, and ESC, ESC unwinds
    the two to a free canvas. **Measured** before it, with real events:
    Select On Design, key 1 with nothing selected, a selector (and the two
    other orders) left the Results window's mode recorded as up with nothing
    bound, its sentence on the status bar, clicks selecting and its key
    arming nothing. Rows TPL1c (the order of the calls, with stand-ins) and
    band PG27 of `tests/headless/test_calc_pick.tcl` (the three orders and a
    control, real events).
    **The session window's close is such a door too** (the closing pass).
    `ase::ui::close` ends the session's Select On Design with
    `ase::ui::sod_end` and then runs `catch {rdw::pick_reseat}`. **Measured**
    before it, by the fourth repair's verifiers: Select On Design, the
    Results window's key, the session window closed left that mode recorded
    as up with nothing bound, through ESC and ESC again. Now it holds the
    canvas after the close and one ESC ends it. Row I11 of
    `tests/headless/test_ase_interact.tcl` (the window's own close script on
    a session with nothing unsaved, a real ESC). The Calculator's own doors
    ask the same (calculator.md R307).
  - *This mode, entered on top of the Results Display Window's mode, takes
    the canvas again when that mode is ended first* (the last build of issue
    1724). Escape pressed in the Results window ends that window's mode from
    underneath, and its release hands the canvas the editor's scripts over
    this mode's live ones. So `rdw::pick_end`, once its own record is gone
    and when its release released a mode, runs `catch {::ase::ui::sod_reseat}`
    (and the Calculator's counterpart beside it). `ase::ui::sod_reseat {}`
    seizes again through `ase::ui::sod_seize` only when a mode is up, is not
    paused, its canvas is a live widget and the press slot holds neither one
    of this mode's own scripts (`ase::ui::sod_own_script`) nor the script of
    another mode that is up (`ase::ui::sod_overlaid {cv script}`, which asks
    `cmdmode::pristine`); in every other state it does nothing and answers 0.
    What the mode has on record as the canvas's own is then what the canvas
    holds now, the `<Destroy>` hook is not added a second time, and the
    queue, its count, the pin markers, the prompt and its one timer are as
    they were. The canvas is given the keyboard, as the entry and the resume
    give it: the mode's ESC is bound there. **Measured** before it: Select On
    Design stayed recorded as up with nothing bound, its prompt on the bar,
    through four ESC on the canvas, and entered again and ended it left the
    Results window's dead scripts on a canvas that took no left click
    (issue 0202's sequence A2). Now one ESC on the canvas ends the mode and
    every binding is as before any mode. Rows TPL13 (the states it acts in
    and does not, with the canvas stood in for), I12 of
    `tests/headless/test_ase_interact.tcl` (the mode entered by its menu
    entry, a real press that still queues, a real ESC) and E6 of
    `tests/headless/test_rdw_keys_1245.tcl` (the real Escape in the Results
    window's text pane; the keyboard on the canvas afterwards).
  - *The prompt is not written while another click mode sits on top* (the
    same build). The Results Display Window's mode keeps its own sentence on
    the same slot with a timer of its own, and with the two modes stacked
    the slot showed the two sentences in turn (**measured**: changing many
    times a second in either order). `ase::ui::sod_prompt_pump` now writes
    only while `ase::ui::sod_covered {cv}` answers 0: the press slot of the
    mode's canvas holds no script that is not this mode's own and that a
    mode that is up declares. The timer keeps running, so the prompt is back
    within one tick of the mode on top ending. With `cmdmode` out of reach,
    a canvas that is no widget, the editor's script or a script no mode
    declares in the slot, or an emptied slot, the pump writes as before. Row
    TPL14, and band PG28 of `tests/headless/test_calc_pick.tcl` for the real
    slot.
  - *Stacked modes keep their order across a descend.* `cmdmode::suspend_all`
    releases the top of a stack first (`cmdmode::release_order`, read from
    what the modes say they hold) and `cmdmode::resume_all` puts the stack
    back bottom first, so while a descend has the modes paused the canvas
    holds the editor's bindings, and the modes come up where the descend
    lands stacked as they were (issue 0202 has the measurements; leg DS8 of
    `tests/headless/test_cmdmode_descend_0201.tcl`, across a descend into a
    new window and, in rows DS8j to DS8q, across a descend in the same
    window).
  - *A mode ended while a descend has it paused writes nothing on the
    canvas.* The descend command given with nothing selected pauses the
    modes and waits for a click on an instance. A paused mode has handed
    the canvas back and still has on record what the canvas held when it
    took it; entered over the Results Display Window's mode, that is that
    mode's scripts. `ase::ui::sod_release {key}` therefore writes nothing
    for a mode marked paused and answers 1: `ase::ui::sod_end` goes on as
    for any other end (the records dropped, the row flavours' pin markers
    taken off, the one sentence, Direct Plot's plot), and the canvas keeps
    the editor's bindings, so the click on an instance still descends and
    the Results window's mode comes up alone where the descend lands. The
    doors that end a paused mode: the session window closed, the mode
    entered again, a Calculator selector pressed. `calc::pick_release` and
    `rdw::pick_release` do the same for their modes. **Measured** before
    it: with this mode over the Results window's mode and both paused,
    closing the session window put that mode's scripts on the canvas: the
    click on the instance was that mode's, and nothing descended. Row TPL15 (the three releases, the canvas stood in
    for), row I13 of `tests/headless/test_ase_interact.tcl` (the session
    window), leg DS9 of `tests/headless/test_cmdmode_descend_0201.tcl`
    (Escape in the Results window, and this mode entered again) and band
    PG29 of `tests/headless/test_calc_pick.tcl` (a selector).
  - *A click in a window that does not show the session's design is
    refused.* The bindings sit on a canvas, and with tabs every tab shares
    it, so the mode stays armed while another design is shown.
    `ase::ui::sod_design_shown {key}` answers 1 when the session's design is
    the sheet shown or one of the sheets above it in this window's hierarchy,
    and also whenever the question cannot be asked (a key with no resolvable
    design, such as a scripted pick with no session; a window whose hierarchy
    cannot be read). On 0 the click queues nothing, marks nothing, leaves the
    mode armed and says (`ase::ui::sod_elsewhere_notice`): *"ase: nothing
    queued — this window shows neither the session's design '<lib>/<cell>'
    nor a sheet below it; switch to that design's window or tab and click
    there"*. A block opened from the design in a new window or a new tab
    still picks.
  - *The prompt names the pin.* `ase::ui::sod_prompt_text {key x y}` (pure:
    it writes nothing) is the mode's words and, when a click at that point
    would take a device pin, that pin: *"select outputs on design — pin R1:P
    (terminal current)"*, in Direct Plot *"select signals to plot — pin R1:P
    (terminal current)"*. It asks `ase::ui::sod_terminal_at` at the raw
    pointer behind the same window test, so the prompt and the click cannot
    disagree. `ase::ui::sod_prompt_pump` writes it every period of its timer,
    under `catch`, except while another click mode sits on top of this one
    (above); `ase::ui::sod_prompt_now` keeps the answer with
    the pointer, the zoom, the window, the hierarchy path, the instance
    and wire counts and the canvas the mode is on, and works it out again
    only when one of them has changed, because the pin test can walk every
    wire of the sheet. In a window that does not show the session's design
    no pin is named. The editor's hover outline cannot say this: on a pin
    with a wire ending on it the outline is the wire.
  - *It names a pin only while the pointer is in the window the mode is on.*
    The engine's pointer is that of the current context, which is the window
    the pointer was last in, while the mode's bindings sit on ONE canvas: in
    another window of the same design (the sheet above a block that was
    opened in a window of its own, or that block's window) a click is the
    editor's. `ase::ui::sod_pointer_elsewhere {key}` answers 1 when the
    canvas the mode has on record is a live widget, the current context has
    a canvas (`ase::ui::sod_canvas`) and the two are different widgets;
    `sod_prompt_now` then answers the mode's own words
    (`ase::ui::sod_prompt_words {key}`) and does not ask the pin rule. It
    answers 0 wherever that cannot be asked (no Tk, a mode whose recorded
    canvas is no widget), and there the prompt is worked out from the
    pointer as before. Tabs share one canvas and are told apart by the
    design they show. **Measured** before it: with the mode carried into a
    block's own window and the pointer back on a pin of the first window,
    that window's prompt named the pin, and a press there selected the pin
    in the editor and queued nothing. Rows TPM12 (stand-ins) and group PE of
    `tests/headless/test_pin_marker_1724.tcl` (real `<Enter>` and
    `<Motion>` after a descend into a new window).
  - *Closing the window the mode is on ends the mode.* The canvas's
    `<Destroy>` binding (`ase::ui::sod_canvas_gone {key w}`) only schedules
    `ase::ui::sod_drop_gone` for when the event loop is idle: while a window
    is being torn down the engine has no schematic to ask, and a marker sweep
    made then clears nothing. Once idle, if the mode is still the one on that
    canvas, is not paused and the canvas is really gone, `ase::ui::sod_drop`
    removes the records, sweeps the row flavours' markers from every window
    that is left and says *"ase: the design window the pick mode was on is
    gone — mode dropped"*. Nothing queued in Direct Plot is plotted, and
    with traces queued there the sentence goes on: *"…; 2 queued traces
    were not plotted, and the colours their picks left on the schematic
    stay until the highlights are cleared (Highlight > Un-highlight all
    net/pins, or its key)"* (one trace: *"1 queued trace was not plotted,
    and the colours its pick left …"*). It names the menu entry because the
    key differs by profile. The drop clears no Direct Plot colour: `xschem
    pin_marker clear -tag plot -all` would also take the ellipses of earlier
    plots whose traces are still in the viewer (**measured** by the third
    review), and the net colours would stay. With nothing queued, and in the
    three row flavours, the sentence ends at *"mode dropped"*. Rows TPL6 and
    TPL6b, and group PF of `test_pin_marker_1724.tcl`. With
    tabs the canvas is shared, so closing a tab does not end the mode.
- **Declared limits.** The pin of a `lock=true` instance is not offered, and
  no pin is while the pin layer is hidden (`find_closest_pin()`'s rule).
  Rows already in the Outputs table when the mode is entered are not marked.
  A pin that carries a Direct Plot marker and is then picked in a row flavour
  takes that flavour's marker, which the mode's end removes (the engine keeps
  one marker per pin). When xschem runs with 16 layers or fewer no
  row-flavour marker is drawn and nothing is said. A window made while the
  mode is up gets the editor's bindings only where the mode's script is the
  exact string the canvas holds: a script appended to a slot the mode holds
  is copied whole. With the tabbed interface a new tab is not a new canvas,
  so nothing is copied and the shared canvas keeps the mode's bindings; a
  click in a tab showing another design is refused by T12's window test. The
  Results Display Window's pick mode nests under and over this mode. No door
  of the product that was found leaves the canvas on a mode's dead scripts
  any more, in either order: a mode ended underneath that mode no longer
  strands it (the closing pass), and that mode ended first, by Escape in the
  Results window, no longer strands the mode on top of it (the last build,
  T12). A canvas put into such a state by hand is still freed by entering
  and ending the mode whose scripts were left (issue 0202). What is left is
  the user's to rule on: whether that mode should nest at all, a real stack,
  and the keyboard, which is on the schematic after a mode has taken the
  canvas again (after a pick is ended from the Calculator window:
  calculator.md R307; after Escape in the Results window: T12). While the
  Results window's mode is under this mode, the tooltip it arms on the
  status slot keeps its own sentence, though the slot shows this mode's
  prompt. The Results window's real Escape was pressed with this mode on
  top in one shape (row E6: the first tab, the mode entered by the proc its
  menu entries call); Direct Plot's flavour on top of that mode was not
  driven. A mode ended while a descend has it paused leaves the canvas
  alone (T12): driven in the first tab, with the descend's wait ended by a
  click on an instance the suite gives no views or by Escape on the
  schematic; the chooser's own path into a new window was driven in the
  order bench only, with the modal chooser stood in for, and a second tab
  and a new-tab descend after such an end were not driven. Row
  I11 drove the session window's close in one shape: the design in the
  first tab, the stock bindings, a session with nothing unsaved. With the
  design in a tab other than the
  first and a second real window on the screen, the main window can end
  with the first tab in front while the mode is armed: the engine takes an
  event on the shared canvas for the first tab once a real window has been
  current (issue 1713, older than this work); the click on the wrong sheet
  is refused by the window test and the mode stays armed. The prompt's
  window rule was driven with real events in one shape, the mode carried
  into a new window and the pointer back on the first; the other shape is
  row TPM12's, with stand-ins. A paused mode coming
  back up with a tab current, after having been on a window of its own, is
  fenced with a stood-in window list (row TPL12) and not with real windows.
  A press with Shift or Control held hands that state to the engine with the
  press's position; it was not driven. The real bit dialog is not driven by
  a suite (the rows stub `bus_dialog`), and nobody has looked at the pick,
  the prompt or the marker on a real screen.
- Suite `tests/headless/test_ase_terminal_pick_1724.tcl`, on three sheets:
  bands TPC (what a device pin is), TPR (range and winner: the bound, the
  label on a pin, the side of a shared point and its box tie-break, blocks
  with unequal pin sets and a title that reaches over the neighbour in rows
  TPR4n to TPR4t, a symbol with two pins of one name in row TPR4u, a one-pin
  device placed after the device it shares a point with, and one placed
  before it, in row TPR4v, pin names that end in a backslash in row TPR4w,
  plain pin names beside another pin attribute that ends in a backslash in
  row TPR4x, on a small sheet of its own,
  both wire tests, the label's box, the pin's own square at
  a radius pinned below it), TPD (the click with no coordinates, one row at a zoom and
  origin where no pixel centre is on the wire), TPN (primitive elements and
  their refusals), TPX (subcircuit calls: the header in the netlist, in a
  `device_model`, in the model files, the stale netlist's cards, the caution
  in its three cases and their remedies, numbered ports, the bit dialog),
  TPH (below the top, the 0488 refusal, the window test of T12 and the
  descends into a new window and a new tab), TPP (Direct Plot, the source's
  current that stands in and what it says; the place of a pin on its element
  in rows TPP13 to TPP14b), TPM (the notices and the prompt; the pointer in
  another window in row TPM12), TPK (call shapes, the cue on the pin, the
  resolver), TPU (a name the deck cannot carry, on a scratch sheet with a
  scratch symbol) and TPL (the mode's lifecycle with the canvas stood in
  for: the Calculator pick ended first and the Results Display Window's mode
  asked to take the canvas again in rows TPL1 and TPL1c, the slots taken and
  handed back, the double-click fallback in row TPL4b, what the mode reports
  it holds in rows TPL9 and TPL9b, the bound press script run after the
  pointer was overwritten in row TPL10, the canvas of a tab in rows TPL11
  and TPL12, the drop when the canvas goes and what it says in Direct Plot
  in rows TPL6 and TPL6b, the mode taking the canvas again after another
  mode was ended underneath it in row TPL13, the prompt's timer under
  another mode in row TPL14, the release of a paused mode writing nothing,
  for this mode, the Calculator's pick and the Results Display Window's
  mode, in row TPL15).
  It runs no simulator and never netlists, and it runs on both arms and is
  in both gate lists (`hcases` and, since the closing pass, `dcases`): a
  recorder stands in for `tk_messageBox`, because on a display the engine
  raises a modal box about the fixture instance `R=B[1:0]` the first time
  one of its pins is named (row TPU6 says what the engine asked for, and the
  last row, TPZ1, names any box asked for elsewhere). The real events are on the
  display arm of registered suites: `tests/headless/test_ase_interact.tcl`
  (a real double and triple click, row I2b; the slots handed back, rows I7
  and I10; the session window closed with the Results Display Window's mode
  on top, row I11; that mode ended first from under this one, row I12; the
  mode entered from the session's menu with the design in a
  second tab, rows IT0 to IT3) and `tests/headless/test_pin_marker_1724.tcl`,
  which fences the marker: band G through the real `ase::ui::sod_click` on
  both arms, and on a display a real click, a real ESC, the real viewer, the
  window closed under the mode (group PC), the prompt naming the pin (group
  PN), a drag in the mode (group PD, and row P8d under the Cadence-style
  profile), a press after the pointer was overwritten (group PS), a window
  made while the mode is up (group PW), the design in a second tab (group
  PT), the prompt with the pointer in another window of the design (group
  PE) and Direct Plot's window closed with traces queued (group PF). The run
  from a click to the vector in the results is band PE of
  `tests/headless/test_ase_probe_deck_1724.tcl` (R-OUT17).

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
  system finds on the PATH); Run Directory… (modeless dialog: path,
  Browse…, Use Default, OK/Cancel; empty = shared default; session state,
  dirties, saved by Save State; refused while a run or campaign is live —
  issue 1704, see "Run directory" below).
- **Analyses** — Choose… (Choose Analyses dialog).
- **Variables** — Edit… (variables editor).
- **Outputs** — To Be Saved > Select On Design; To Be Plotted > Select On
  Design; Save All… (dialog: save all voltages?, all terminal currents?,
  levels, etc. — ngspice mapping v1: allv → `.save all`, alli →
  `.options savecurrents`).
- **Simulation** — Netlist > Recreate; Netlist > Display; Netlist and Run;
  Run (uses EXISTING netlist — supports hand-edited decks); Stop; Log
  (reopen log window); Options… (the options sheet: a finder over the
  simulator's option catalogue, the bench's own rows, and a live deck preview
  -- see "The Options sheet's deck preview" below. This line read "minimal for
  now" until 2026-11-22, long after the sheet of issues 1441 and 1442
  shipped).
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
  never gets two viewer windows; it plots nothing, where the `~` strip button
  evaluates and plots, R-OUT12);
  Calculator (**LIVE since the calculator batch's item 13** — `calc::open`,
  with no session key: the Calculator is per-PROCESS idempotent, one window per
  xschem, `doc/claude/specs/calculator.md` R101. It was a disabled placeholder
  only until the window existed).

### Run directory (issue 1704)
The state's `rundir` key names where the deck, raw, log and every other run
artifact go; empty means the shared fallback (`set_netlist_dir`'s
`$USER_CONF_DIR/simulations`), one directory every bench shares. Setup > Run
Directory… is its door. The decisions are pure engine procs in `src/ase.tcl`
(`ase::rundir_validate`, `ase::rundir_set`, `ase::rundir_busy`,
`ase::rundir_default_preview`); the dialog and `ase::ui::set_rundir` are the act.

- **Storage form: absolute.** Every reader resolves a relative key against the
  process cwd, so a typed relative path is resolved once against `[pwd]` and
  stored absolute. `$VAR`/`${VAR}` and `~` are expanded first. A legacy
  relative value in an old .state file is shown verbatim and keeps working as
  before.
- **Validation classes.** Empty clears (never refused), and so does a path
  that IS the shared fallback (typed or browsed to): it is stored as `{}`, so
  the bench stays shared and the shared-directory refusals still apply.
  Browse… starts at the entry's directory or HOME, never the shared one.
  Refused: a character
  the backend's own `path_quoted`/`shell_word` probes reject (control
  characters, `$`, backquote, braces, `"`, `\`), an existing file, an
  unwritable directory, or a path whose nearest existing ancestor is not
  writable. Accepted with a note: upper case, spaces or other symbols (the
  fast OP dump falls back to its slower route), and relative model/include
  paths in the bench (they resolve against the run directory). Nothing is
  created by the check; `ase::rundir` creates the directory on first use.
- **Session state.** OK writes the key, the session goes dirty, the close and
  quit prompts follow, Save State persists it. OK on the directory already
  stored (however spelled) changes nothing and stays clean. OK is refused
  while a run or a campaign is live, because the window's run predicates
  re-derive the lock key from the current state; the refusal names the stop
  control, and OK stays enabled, so it works once the run ends. Reopening the
  open dialog raises it and keeps what was typed.
- **Rawfile rebase.** A stored `viewer.rawfile` relative to the old directory
  is rebased so it keeps naming the same file: relative to the new directory
  if it sits under it, absolute otherwise (one predicate,
  `ase::rawfile_relative`, shared with R602's relativiser). A relative value
  under an empty old key is left alone (R602e).
- **Stale results.** Nothing is deleted or moved. The panes re-read from disk,
  so a fresh directory shows no results; waves already plotted stay attached.
  Run (existing netlist) in a fresh directory fails with its own message;
  Netlist and Run works.

### The Options sheet's deck preview (issues 1441, 1442, 1657)

Simulation > Options… opens the options sheet: a window of its own, not modal. Below its
rows it carries a **deck preview**, which is the point of the sheet: every line the next
deck will carry for an option, in the place the deck will carry it.

**Four slots**, named in ASE-L's own words (`ase::opt_door_phrase` returns the same four):

| slot | pane heading | what stands in it |
|---|---|---|
| `deck` | `above the analysis block` | the bench's global option cards, then the run's default seed when nothing else sets one |
| `control` | `inside the analysis block` | the lines written around an analysis: an option stored against that analysis and the line that puts it back, and the lines ASE-L adds itself around an analysis that cannot run under an option |
| `cmdline` | `on the command line` | options that go to the simulator's command line |
| `prefile` | `in the run-directory start-up file` | options that go to the start-up file |

and a **notes** block, headed `not delivered`: one line per option that will not arrive, or
arrives somewhere the user did not expect. The answer is `ase::opt_preview`'s; the pane's
text is built from it by the pure proc `ase::ui::optsheet_preview_text`.

**The line shapes.** A slot heading stands at the margin. Under a slot heading a deck line
stands four spaces in, and every line shown that way is in the deck, byte for byte -- with
one exception, the placeholder `(nothing)` an empty slot says in its place. The lines under
`not delivered` stand four spaces in as well and are not deck lines: an option's name, a
dash, and why it does not arrive as set. (Until 2026-11-22 this paragraph said nothing but
a deck line stands four spaces in, which those two kinds of line made untrue.)

**The in-block slot is in the deck's order, in labelled groups** (the user's ruling of
2026-11-21, issue 1657).

- One group per enabled analysis type. A group is headed `<TYPE> BLOCK`, two spaces in --
  the words the sheet's Written column uses for an option stored against an analysis.
- The groups stand in the order the deck will run its analyses, and the lines of a group in
  the order the deck writes them around that analysis: the scoped options' set lines, the
  lines ASE-L adds, then the restore lines, last set first (rows DK10e and DK10f of
  `test_ase_effective_1442.tcl` compare both with the deck).
- **The order question is the backend's.** The registry ranks the operating point first. The
  ngspice deck runs it behind the other analyses when the per-device operating-point
  requests go inside its command block (issue 0964), and whether they do is decided from the
  netlist of the run. Core asks `ase::op_run_order`, which asks the adapter's optional
  `op_run_order` hook: `first`, `last` or `unknown`. The window hands that question the
  netlist file as the run will read it (`ase::ui::optsheet_netlist_full`), separately from
  the reduced copy the seed rule reads.
- When the deck moves the operating point, its heading says so: `OP BLOCK -- runs last in
  this deck`, or `runs after <analyses> in this deck` where an analysis ranked behind it
  (`sp`) still follows.
- **When the order is not settled** -- the switch that saves device operating-point numbers
  is on, the operating point and another analysis are enabled, and there is no netlist of
  this session yet (or the one on disk is not the one device requests are held for, or it
  is and was written while no operating point was enabled, so that nothing was asked of the
  design, or the run would read another file than the window) -- the groups keep the
  registry's order and the slot says so once, six spaces in and in parentheses: *the op
  analysis runs after tran when device operating-point numbers are saved; that is settled
  when the netlist is written*. It is said only when it can matter: two groups have lines,
  or an option is left in force. On the pane this sentence wraps at a word when it is
  longer than the pane is wide (the pane has no horizontal scrollbar); a deck line and a
  heading never wrap.
- **An option that is set and not put back** has a note. Once the order is known the note
  names the analyses that run after the one it is set for, or says none does; while the
  order is not settled it says "every analysis after it".

**The open sheet follows the bench.** A new netlist, the tick that saves device
operating-point numbers, an analysis switched on or off and a forced shape of the device
requests each repaint the preview of an open sheet (`ase::ui::session_changed` for a state
write, the `order_notify` seam of `src/ase.tcl` for the rest). Those are ASE-L's own
writers. A netlist changed on disk by something else (the schematic window's own Netlist
command, which writes the same file when the bench names no run directory; an edit by
hand) fires none of them, so the preview is also repainted each time the sheet gets the
keyboard focus (`ase::ui::optsheet_focus`). A repaint replaces the pane's text only when
it moved.

**The order question is a pure read.** The hook and the preview reach neither proc that
picks the shape of the device requests nor the capability measurement, which would start
the user's simulator when nothing is measured yet (row RO17 of `test_ase_core.tcl`).

Rows: `tests/headless/test_ase_optsheet_1441.tcl` (sections PV and UI),
`test_ase_effective_1442.tcl` (DK10 to DK10f, SP7b), `test_ase_core.tcl` (RO12 to RO18),
`test_ase_run_seed.tcl` (RS9 to RS12).

### Log window (not a pane)
Kicking off a run opens a NEW toplevel showing the live log (existing
live-follow machinery from v1 moves here). Ctrl-W closes it;
Simulation > Log reopens on the current log file.

### Choose Analyses dialog — SUPERSEDED by the analyses batch (Stages 2–3)
⚠ **The sketch below is the 2026-07-21 one and is kept for history only.** What
shipped is a **four-state grid** over all eleven registered types plus a
per-type form, in `ase::ui::chana_*` (`chana_show`, `chana_row`, `chana_form`,
`chana_fields`, `chana_glyph`, `chana_committable`, `chana_options`, …). The
grid's four states are the precondition tiers, not an enable checkbox: a type
can be enabled, available, `caution` with a reason, or `blocked` **carrying its
fix** rather than only its reason. See *The analyses subsystem* above.

The superseded sketch: two vertical sections: top = analysis types with radio
buttons (selects which analysis the bottom shows); bottom = per-analysis form:
Enable checkbox + quick fields (e.g. DC: source/start/stop/step; TRAN:
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

⚠ **P1–P5 are the pre-batch phasing and are complete or superseded.** The live
plan is `doc/claude/ase_analyses_batch/PLAN.md`, seventeen stages, of which 1–6
are landed; `LEDGER.md` in that directory is the account and carries the resume
point. Read the ledger before the plan — the plan is what was intended and the
ledger records where it was measured wrong, which has happened in every stage so
far.

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
