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

- `variables` become `.param` lines; schematic references them symbolically
  (`W=Wn`) — plain ngspice resolves `.param` at netlist level.
- `analyses` render into one `.control` block (op → `op`, dc → `dc V2 0 1.8
  0.01`, …) in a fixed order; only `enabled 1` entries emit.
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
  area's failure mode. Edit shows Name and Program only and carries the extra
  arguments and the backend through untouched; the Name field is read-only,
  so a rename is a Remove plus an Add.
* **Removing the simulator in force says what happens next.** Either the one
  survivor is named as the one that will start now, or the user is told nothing
  of theirs is picked and the program on the `PATH` takes over. Both sentences
  are minted in `ase::sim_why`; the "it will be back at the next start" one for
  an rc entry is always said LAST.
* **"None of mine" is a choice and is saved as one (issue 0932).** The saved
  list carries `ase::sim_select {}`, so a cleared choice survives a restart
  instead of the first entry being put silently back in force — and it
  therefore overrides an rc's own `::ASE_SIMULATOR` at the next start.
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

### What that program can actually do (issue 0948)

`ase::sim_capabilities <backend>` answers what the build that will ACTUALLY
start can do — resolved through `ase::sim_status`, never a bare name. The
answer is a dict: `{known 0}`, or
`{known 1 usable 0|1 appendwrite 0|1 blanket_op_save 0|1 hier_op_names 0|1}`.
When `known` is 0 the capability keys are **absent, not 0**; absent means
nobody measured, 0 means measured-and-no.

* **The method is a PROBE RUN, never a version string.** Measured: a stock
  ngspice and one patched to ignore the add-each-analysis line print the
  byte-identical `** ngspice-46+ : Circuit level simulation program`. The probe
  is two tiny PDK-free decks (a level-1 MOS two subcircuits deep, op + tran),
  and it runs **lazily on first use** — measured at ~10 ms, never at startup.
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
* **`capabilities` is an OPTIONAL sixth backend hook**, beside `render_deck`,
  `run_cmd`, `log_file`, `result_probe` and `raw_file`. A backend that declares
  none is answered `known 0` — never a guessed yes.
* **`ase::cap_report`, called once from `ase::run_deck`,** is the only say-site:
  a program that produced nothing is reported whatever the run looks like, and a
  build that keeps only the last analysis is reported when the run has more than
  one. Both sentences are minted in `ase::sim_why` like every other one here.
  **The run, not the command builder** — building a command line happens in
  places that must stay silent, and `test_ase_simcaps_0948` row F8 pins both
  ends of that so the report cannot be refactored out of the one place the user
  meets it.
* **Four belts around the probe run, each pinned by its own row.** The program
  is given nothing to read (`< /dev/null`, row G3) so a build that drops into
  its own prompt cannot hang the user's Run; it is given a fixed number of
  seconds (`timeout`, row G5) so one that never returns for any other reason
  cannot either; the extra arguments the user registered are handed to it when
  it is measured (row G6), so what was measured is the program they will
  actually get; and `ase::cap_raw_plots` reads a results file written as raw
  numbers as well as one written as text (rows B7/B8), stepping over each
  payload by its own length so a run of numbers that happens to spell a plot
  header is never mistaken for one.

* **Where the shipped code does not yet meet this contract**, all measured and
  filed, none fixed at the time of writing. Read these before relying on an
  answer from this surface:
  * **0951** — the probe's scratch files are per simulation-folder, not
    per-process, under fixed names, so a second xschem window's results can
    answer for the program being measured. Reproduced: a program that wrote
    nothing at all measured `usable 1 appendwrite 1 hier_op_names 1`.
  * **0949** — the probe deck's `write` line is unquoted, so a simulation
    folder whose name contains a space or a dollar sign makes a healthy build
    measure `usable 0` and be told, on every Run, that it is not a circuit
    simulator. (`render_deck`'s own `write` line is unquoted the same way, and
    older.)
  * **0952** — `appendwrite` is decided by the presence of an operating-point
    plot, so it reads 0 for a build that appends perfectly but names device
    parameters differently. That build is then given advice that changes
    nothing; `hier_op_names` already holds the true answer and is not read.
  * **0953** — the two probe runs are paid synchronously inside `run_deck`, so
    a slow-to-start simulator freezes the editor for a measured 20.0 s, and
    "cut off by its own clock" is reported as "produced nothing".
  * **0950** — a wrong answer is remembered for the session; the stamp only
    notices the program file changing, and no GUI door calls
    `ase::sim_caps_clear`.
  * **0954** — `ase::cap_run` appends ngspice's `-b` from the generic
    namespace, against this file's own seam rule (`src/ase.tcl:24`).

  Three of those — 0949, 0950, 0953 — are one mistake in three places: **a
  measurement that did not happen, reported as a fact about the user's
  program.** The `known 0` contract at the top of this section is what they
  should be answering.

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

`do_run`'s guard `[file normalize [xschem get schname]] ne $dpath` asks whether the
design is the **current xschem context**, because that is what `ase::netlist`'s own
guard requires. It does **not** ask whether the design window is visible — and the
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

* **The context switch stays unconditional.** Drop it and `ase::netlist`'s "design is
  not the current schematic" error comes back. It is also the *only* half covered by
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

**Still broken on this button, filed not fixed:** issue **0643** — pressed while the
user is *descended* into the design, the guard fires, `raise_design_editor`'s
issue-0168 stack loop matches the descended window and returns 1 **without
ascending**, so `do_run`'s post-check refuses the run: `Status: Error`, red, `run_id`
empty, no simulation. That is exactly where the OP-annotation *run → descend → press
6* workflow stands.

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
  `Simulator: ngspice | State: ngspice_state1`) + status (Ready/Running/…).
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
  (view-only one-line summary). One row per chosen analysis, row-numbered.
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
explicit outputs or with Save-All-Voltages on), and RUNNING is still top-only —
`ase::netlist` requires the design to be the current schematic, so ascend before
Run. `Tools > Launch ASE-L` is deliberately NOT hierarchy-aware: it binds a
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
allowed at any depth; only the RUN is top-only (`ase::netlist` compares
`xschem get schname` against the design path, and descending changes
`schname` to the child — there is no `currsch` guard). The queued expression
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
  dropdown + editable Cell/View text fields prefilled with current; if
  current view was opened read-only and target = same view, Overwrite needs
  a confirmation popup); Close.
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
