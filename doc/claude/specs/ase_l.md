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
```

- `variables` become `.param` lines; schematic references them symbolically
  (`W=Wn`) — plain ngspice resolves `.param` at netlist level.
- `analyses` render into one `.control` block (op → `op`, dc → `dc V2 0 1.8
  0.01`, …) in a fixed order; only `enabled 1` entries emit.
- `models` render `.lib <file> <section>` lines (corner.sym's job today).
- Loader/saver in `ase.tcl`; unknown keys preserved round-trip (forward compat).

## Deck assembly (no C changes)

1. `xschem netlist` the **clean** schematic → `<rundir>/<cell>.spice`
   (devices + `.GLOBAL` + `.end` only, since the schematic carries no
   `netlist_commands` instances — verified spice_netlist.c:214-591).
2. ASE post-processes: strip trailing `.end`, append in order:
   `.lib` models, `.param` variables, `.options`, `.save` outputs,
   `.control` analyses block, `.end`.
3. Write `<rundir>/<cell>_ase.spice` (schematic netlist artifact stays
   untouched); run `ngspice -b <cell>_ase.spice -o <cell>_ase.log`.

Per-simulator seam: step 2+3 live behind `ase::backend::<sim>::render_deck` /
`run_cmd` table; v1 registers `ngspice` only.

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

## UI sketch (single toplevel per session, Tk)

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
