# Mixed-signal debug — digital internals in the Signal Browser

Status: SPEC / PLAN (no code yet)
Owner branch: fluid-editing
Related: `doc/claude/specs/ase_l.md`, `doc/claude/code_analysis/signal_browser_reference.md`,
`doc/claude/code_analysis/signal_browser_teardown_scoping.md`,
`xschem_library/ngspice_verilog_cosim/` (upstream's working d_cosim example)

## Goal

Select an instance whose cell has **no schematic view** — its only implementation is
Verilog (or Verilog-A) source — press **Ctrl-Alt-V**, and the Signal Browser's signal
pane scopes to that instance and lists **its internal digital signals**, on the same
time axis as the analog waveforms read from the ngspice `.raw`.

This is the debug case the Signal Browser exists for and cannot currently serve.
Descending into the cell is not the answer and never will be: there is nothing to
descend into. The instance itself has to become a browsable scope.

Concretely, for the reference testbench (§G):

```
tb_counter          v(clk) v(dac_out) v(filt)        <- analog, from .raw
 └ x1 (dig_top)     v(x1.count0..3)                  <- bridged digital, from .raw
    └ a1 (counter)  a1.cnt[3:0] a1.tc a1.phase ...   <- INTERNAL, from the digital sim
```

Today the third line is empty. Selecting `a1` scopes the browser to `x1.a1.` and finds
zero vectors, because ngspice holds no internal nodes for a code-model instance.

## Measured constraints (why this is four subsystems, not one)

All measured on this machine, ngspice-46 (build 2026-08-02), 2026-08-08. These are the
facts that shape every decision below.

| # | Fact | Evidence |
|---|------|----------|
| M1 | **XSPICE event nodes never enter the `.raw` file.** Not with `save all`, not with an explicit `save <node>`. | 2-node digital chain; `save all dclk dq` → raw Variables = `time i(abr2) v(aq) v(clk) i(vclk)`. Both event nodes absent. |
| M2 | `eprvcd <nodes> > f.vcd` **does** emit them — as VCD. | Same deck; produced a valid VCD with `$var wire 1 ! dclk`. |
| M3 | **xschem has no VCD reader.** `src/rawtovcd.c` is an *exporter* (`src/rawtovcd` is built by `src/Makefile:14`). `raw_read` (`src/save.c:1002`) reads spice raw only. | Source read. |
| M4 | A digital node **bridged to analog** does land in the raw, hierarchically named. | Bridged an internal subckt node → `v(x1.nq0_int)` appeared in the raw. |
| M5 | An auto-bridge fires from **any** analog load — a plain resistor in a code block, no symbol needed. | `robs dnq0 0 1meg` inside a `.subckt` → `v(x1.dnq0)` in the raw, `auto_bridge2` inserted. |
| M6 | Under `d_cosim`, **only module ports cross the shim boundary.** Internal Verilog signals never reach ngspice in any form. | `/usr/local/share/ngspice/scripts/src/verilator_shim.cpp` — `accept_input`/`step` walk `inputs.h`/`outputs.h`/`inouts.h` only. |
| M7 | Verilator↔ngspice is **genuine lockstep**, ngspice as master. ngspice sets `pinfo->vtime` and calls `step()`; the shim advances the Verilog model to that target, and on an output change calls `out_fn()`, stops early, and writes the true event time back into `vtime`. | `cosim.h`; `verilator_shim.cpp` `step()`, `if (next < target) pinfo->vtime = next * tick;` |
| M8 | The co-simulation is **two-state**. `accept_input()` does `if (val == UNKNOWN) return;` — an X from the SPICE side is dropped, the input holds its previous value. | `verilator_shim.cpp` |
| M9 | **No rollback.** Verilator cannot un-step when ngspice rejects a timestep and backs up. | `digital.cm` carries the diagnostic string `"XSPICE time is behind vtime:"` |
| M10 | The shipped shim **never creates a trace object** — no `VerilatedVcdC`, no `open()`, no `dump()`. `--trace` alone produces nothing. | `verilator_shim.cpp`, whole file |
| M11 | `vlnggen`'s final link is a hardcoded object list that **omits `verilated_vcd_c.o`**. | `/usr/local/share/ngspice/scripts/vlnggen:~318` |
| M12 | Ubuntu's `iverilog` 12.0-2build2 deb **ships no `libvvp.so`** (only `/usr/bin/vvp`, `libvpi.a`). `ivlng.so` dlopens `libvvp`. The apt package cannot drive `d_cosim`. | `dpkg -c` on the downloaded deb; `strings ivlng.so` |
| M13 | Installed and working: ngspice-46 with XSPICE (`digital.cm` exposing `d_cosim`, `d_process`, `d_dff`…), `ivlng.so`+`ivlng.vpi`, `vlnggen`, `ghnggen`, `openvaf`, `g++ 13.3`, **`verilator 5.020`**. | `ls /usr/local/lib/ngspice/`, `verilator --version` |
| M14 | **ngspice-46 lowercases every literal token in script-file mode**, including `setcs` values. Interactive input is unaffected. This makes the shipped `vlnggen` unusable — it depends on case in `--Mdir`, `--prefix Vlng`, the `VL_IN`/`VL_OUT`/`VL_INOUT` scan, and the `VL_DATA(...)` lines it echoes. | `printf '*ng_script\necho BARE_UPPER\nsetcs v="X_UPPER"\necho $v\n' > s; ngspice s` → `bare_upper` / `x_upper`. Real failure: `%Error: Invalid option: --mdir... Suggested alternative: '-Mdir'` |
| M15 | **`verilator_shim.cpp` has a use-after-free.** `Cosim_setup()` holds the `VerilatedContext` in a function-local `const std::unique_ptr` while the model keeps a raw pointer; the `--timing` `step()` then calls `topp->contextp()` on freed memory. Latent today only because the non-timing path never touches the context. | source read; patched in `tools/cosim/src/` |
| M16 | **`pinfo->cleanup` is not reliably reached** in ngspice-46 batch mode. The first trace build ended with a half-written `#197` where `#1975796` belonged. Periodic `flush()` + `atexit()` fixes it. | measured, then re-measured clean: `truncated: False`, span `0..2000000 ps` |
| M17 | **A trace dump happens on every SPICE timestep, not every signal change.** The reference run produced **200,344 VCD timestamps carrying ~40 real transitions** — one `#t` line per ngspice step. VerilatedVcd dedups *values* but still emits the time header. | `xcheck.py`: 200,344 timestamps vs 10 LSB edges. **Directly sizes decision C2.** |

**M1 + M3 + M6 together are the whole problem.** The data exists only inside the
digital simulator, the only way out is VCD, and xschem cannot read VCD.

## What already exists (the seams to build on)

The good news: three of the four subsystems already have the right shape.

| need | existing primitive | where |
|------|--------------------|-------|
| a cell's views enumerated, extension-agnostic | `cell_views` globs `<lib>/<cell>/<view>/<cell>.*` | `src/library_defs.tcl:261` |
| a view's datafile resolved, any extension | `cellview_resolve` — exact `.sch`/`.sym` first, then generic `glob $cell.*` fallback | `src/library_defs.tcl:209` |
| view TYPE is extension-derived, by written doctrine | `copyform::view_type`; the doctrine note | `src/copy_form.tcl:22,52` |
| an existing dispatch seam for non-editor views | `libmgr::view_handler` — built once already for `.state` | `src/library_manager.tcl:437` |
| selected instance → `{lib cell view}` | `library_inst_lcv` | `src/library_defs.tcl:350` |
| **many datasets held at once** | `xctx->extra_raw_arr[]` / `extra_idx` / `extra_raw_n`; `extra_rawfile(what, …)` read/switch/switch-back | `src/xschem.h:1882-1888`, `src/save.c:1225` |
| Tcl surface over that registry | `xschem raw info` → `{cur <i> dbs {{idx path type}…}}`; `raw switch <idx>`; `raw list`; `raw index <name>`; `raw clear` | `src/scheduler.c:9577+`, `src/save.c:1456` |
| **the Signal Browser already reads across ALL DBs** — switches to each registry slot, snapshots names, restores | `wviewer` PLAN item 14, the all-DBs registry reader | `src/wave_viewer.tcl:2000-2130` |
| a graph widget can name its own DB and the drawing code switches to it and back | `extra_rawfile(2, rawfile, sim_type, …)` … `extra_rawfile(5, …)` | `src/callback.c:2047,2068` |
| the shape a dataset must have | `Raw` — `names[] values[][] nvars npoints[] datasets table sim_type schname level sweep1/2` | `src/xschem.h:1122-1145` |
| ASE-L's raw artifact + attach path | `ase::raw_file` → `<rundir>/<cell>_ase.raw`; `ase::last_rawfile`; the `attach_raw` path does `xschem raw clear` then reads | `src/ase.tcl:1367,600` |
| Ctrl-Alt-V today | `wave.show_in_signal_browser` → `ase::show_in_browser_for_current` — builds hierarchical segments from the design position, appends the selected instance name, scopes the lower pane to that prefix | `src/keybindings.csv:66`, `src/ase.tcl:1098` |

**The single most important consequence:** a VCD loaded as another entry in
`extra_raw_arr[]` is a DB the Signal Browser *already* enumerates. The browser needs
far less work than the layers under it.

---

## Work items

### A — Simulation: make the digital data exist

| id | item | notes |
|----|------|-------|
| A1 | ~~Install `verilator`~~ | **DONE.** 5.020 at `/usr/bin/verilator`. |
| A2 | ~~Trace-enabled cosim shim~~ | **DONE.** `tools/cosim/src/verilator_shim.cpp`, hunks marked `XSCHEM PATCH`: trace object + `traceEverOn` + depth 99 + `open()` from `sim_args`; `dump()` in **both** `step()` variants (the `--timing` one dumps at each Verilog event time `next * tick`, not at the SPICE target, or several internal events inside one timestep collapse); a monotonicity clamp (M16/M9); `flush()`+`atexit()` (M16); the context-lifetime fix (M15). |
| A3 | ~~Fix the link~~ | **DONE**, in `tools/cosim/build_cosim_so.sh` — adds `verilated_vcd_c.o` when present. |
| A4 | ~~Package the override~~ | **DONE, but not the way this spec first proposed.** The `sourcepath` trick is moot: `vlnggen` cannot run at all on ngspice-46 (M14). `tools/cosim/build_cosim_so.sh` replaces it outright, doing the same four steps in `sh`. `-V` selects the patched in-repo shim; without `-V` the system copy is used, so a stale vendored tree cannot silently affect a non-trace build. `NGSPICE_COSIM_SRC` overrides. See `tools/cosim/README.md`. |
| A5 | ~~VCD path as a model parameter~~ | **DONE.** `.model counter d_cosim simulation="./counter.so" sim_args=["counter.vcd"] delay=0`; the shim reads `pinfo->sim_argv[0]`, defaulting to `cosim.vcd`. |
| A6 | ~~Pin the time-base contract~~ | **DONE and measured.** `tick = pow(10, contextp->timeprecision())`; `` `timescale 1ps/1ps `` → VCD `$timescale 1ps`, span `0..2000000 ps` for a `tran 10p 2u`. Cross-check: counter LSB first rising edge at **50.0120 ns (VCD)** vs **50.0219 ns (raw)** — the ~10 ps offset is exactly the `dac_bridge t_rise=1e-11` plus the 0.9 V analog threshold crossing, i.e. physical, not a units error. Still owed a regression test (H3). |
| A9 | **Throttle the trace dump** (new, from M17). 200,344 timestamps for ~40 transitions is ~1.7 MB per 2 µs and sets the floor for any reader's memory. Only dump when something changed, or subsample. | Not blocking; changes C2's arithmetic by ~4 orders of magnitude. |
| A7 | *(optional, alternative)* Build Icarus from source with shared `libvvp` to unlock the `ivlng` route and plain `$dumpvars`. | M12. Only if a `.v` feature Verilator lacks is needed. |
| A8 | *(optional, alternative)* `d_process` route — digital block as any external executable over pipes. Zero Verilog toolchain. | Worth a note in the spec; not on the critical path. |

### B — View model: `verilog` and `veriloga` become view types

Enumeration and resolution already work (`cell_views`, `cellview_resolve` — a
`counter/verilog/counter.v` on disk *already* lists as view `verilog` and
`cellview_path` already returns its path). What is missing is typing, creation,
routing, and the loose-file convention.

| id | item | site |
|----|------|------|
| B1 | **Extension→type map.** Add `.v`,`.sv`→`verilog`; `.va`,`.vams`→`veriloga`. Today they fall to `default { return data }`. | `copyform::view_type`, `src/copy_form.tcl:52` |
| B2 | **Creation.** `library_new_view` hardcodes `$type eq "symbol" ? "sym" : "sch"` — every non-state type writes a `.sch`. Needs a real type→ext table. | `src/library_defs.tcl:703` |
| B3 | **New-View dialog.** `-values {schematic symbol ngspice_state1}` must gain the new types. | `src/library_manager.tcl:1268` |
| B4 | **Seed template.** An empty `.v` is useless. When a symbol view exists, seed `module <cell>(<pins>); endmodule` from its pin list. `.va` gets the Verilog-A equivalent. | new, near B2 |
| B5 | **Open routing.** `libmgr::view_handler` returns `editor` for everything non-`.state`, and `editor` means `xschem load` — which would try to parse `.v` as a schematic. Add `.v`/`.va` → text editor. Thin: `edit_file` already exists. | `src/library_manager.tcl:437` |
| B6 | **Ref resolution.** `lib_qualified_abs` switches `.sch`→schematic, `default`→symbol, so `SANDBOX/counter.v` silently resolves to the *symbol* view. | `src/library_defs.tcl:278` |
| B7 | **Alt-2.** `alt2::other_ext` is a hard binary (`*.sym ? ".sch" : ".sym"`), and `default_view`/`views_of_ext` filter on one ext. With four types "the other one" stops being well-defined. Mitigated: `alt2::choose_dialog` already handles N candidates — this is widening the candidate model, not new UI. | `src/alt2_toggle_view.tcl:22,27,45` |
| B8 | **Convention change: the `.v` moves into a view.** Upstream keeps `counter.v` at the library root, named by hand in each symbol (`tclcommand="edit_file [abs_sym_path counter.v]"`). As a view it lives at `<cell>/verilog/<cell>.v`, and the instance→source link becomes *derivable* instead of hand-written. This is what makes §F possible at all. | convention + `abs_sym_path` |
| B9 | **`veriloga` is a different animal — decide separately.** OSDI/Verilog-A modules are analog; their nodes *do* reach the raw. That branch may need recognition only (B1-B6) and none of §C/§D. Do not let it ride along unexamined on the digital design. | analysis |

### C — Waveform Viewer: read a VCD into a `Raw` DB

The deliverable is a second *producer* for the same consumer. Nothing downstream should
learn what a VCD is.

| id | item | notes |
|----|------|-------|
| C1 | **`vcd_read()` → a populated `Raw`.** New `src/vcd_read.c` (add to `OBJ` **and** an explicit compile rule in `src/Makefile` — per CLAUDE.md). Parse `$timescale $scope $var $upscope $enddefinitions $dumpvars`, value-change body, `b<bits> <id>` vectors, `r<real> <id>`. | Fill `names/values/nvars/npoints/datasets/table/sim_type/schname/level`. |
| C2 | **Event stream → sampled columns.** A `Raw` is columnar: every vector shares one point index. VCD is sparse per-signal events. Decide the materialization: (a) union of all event times, each signal held at its last value — exact, memory ~`nsignals × nevents`; (b) resample onto a fixed grid — bounded memory, loses exact edge times. **(a)** preserves the edges that make digital debug worth doing. Size it against the reference TB before committing. | The main engineering risk in §C. |
| C3 | **X and Z.** `SPICE_DATA` is numeric; VCD has four states. Either a sentinel value with renderer support, or a parallel state array in `Raw`. M8 says the *co-simulation* is two-state, but a VCD from a `--timing` build or from `eprvcd` is not. | Do not silently map X→0. |
| C4 | **Buses.** VCD `$var wire 4 ! cnt [3:0]` is one vector. The viewer's existing bus display is the `node="bus; b3,b2,b1,b0"` composition of scalars. Either explode buses into bits at read time (fits the existing renderer, loses the natural grouping) or teach the renderer a native bus vector. | Affects what the browser tree shows. |
| C5 | **Scheduler surface.** A `vcd_read` arm alongside `raw_read`, landing the result in `extra_raw_arr[]` through `extra_rawfile()` so it is a first-class DB. Letter-dispatch rules apply (`doc/claude/` scheduler notes). | `src/scheduler.c` |
| C6 | **`sim_type` for a digital DB.** Pick and document the token (`"vcd"`? `"tran"` so existing X-axis code just works?). Several call sites compare `sim_type` literally — e.g. `!strcmp(xctx->raw->sim_type, "op")` at `src/scheduler.c:2183,9751,9764`. Choosing `"tran"` avoids touching them; choosing `"vcd"` means auditing every one. | Decide once, write it down. |
| C7 | **Digital rendering already half-exists.** Graph widgets have `digital=1`. Confirm it renders a 0/1 `SPICE_DATA` trace the way this needs, and extend for X/Z and bus-value text if C3/C4 demand. | `src/draw.c` graph path |

### D — Two DBs, one time axis

The registry is a **switch** model — one current DB at a time — and per-graph selection
(`callback.c:2047`) works by switching, drawing, switching back. Plotting analog and
digital *together* is the new requirement.

| id | item | notes |
|----|------|-------|
| D1 | **Per-trace DB resolution.** Today a graph's `node=` list resolves against the current DB. A mixed strip needs each trace to name its DB, or a documented search order across DBs. | The core §D change. |
| D2 | **Joint X domain.** Two DBs have independent time vectors, extents, and point counts. Zoom, pan, `x1/x2`, and the shared-X strip logic must span the union. | Silent-wrong-answer risk if one DB's extent is used as the whole. |
| D3 | **Time-unit reconciliation.** ngspice raw time is seconds (double); VCD time is integer ticks × `$timescale`. Convert once at read (C1), store seconds, and assert against A6. | Off-by-1e3 here looks like a plausible waveform. |
| D4 | **Cursors, markers, annotation across DBs.** `annot_p`/`annot_x`/`annot_sweep_idx` are per-`Raw`. A cursor at time *t* must resolve in both — with the nearest-sample-before rule differing between a dense analog sweep and a sparse event stream. | `Raw` fields, `src/xschem.h:1129-1137` |
| D5 | **Backannotation.** `annotate_op` and the schematic voltage overlay read the current DB. Define what a digital DB contributes (probably: nothing, explicitly). | `src/scheduler.c:2145` |

### E — ASE-L: recognize a mixed-signal run

| id | item | notes |
|----|------|-------|
| E1 | **Detect.** A run is mixed-signal iff the netlist contains ≥1 `d_cosim` instance — i.e. ≥1 instance whose cell has a `verilog` view (§B). Decide detection at netlist time (authoritative) vs. state-dict declaration (explicit, user-editable). | |
| E2 | **Emit both artifacts.** `ase::raw_file` gives `<rundir>/<cell>_ase.raw` (written by an in-`.control` `write`). Add the digital artifact path(s), one per `d_cosim` instance, and pass each to its `.model` card as A5's parameter so the shim writes into the run dir. | `src/ase.tcl:1367` |
| E3 | **Attach both.** The `attach_raw` path does `xschem raw clear` then reads one file. It must read the raw *and* every VCD, leaving N DBs in the registry with the analog one current. | |
| E4 | **State-dict fields.** New keys for the digital artifacts and the mixed-signal flag. Versioning: an old `ngspice_state1` file must still load. | `ase::state_default` |
| E5 | **Deck emission for the digital side.** The `pre_set auto_bridge_d_in/d_out` block, and the observation taps (§G3), are simulation config — they belong in the ASE-L state, not hand-written into every testbench's `code_shown` symbol. | This is the ADE-L premise applied to mixed-signal. |
| E6 | **Build orchestration.** The `.so` must be rebuilt when the `.v` changes, before the deck runs. ASE-L already has a `pre_commands` mechanism (see `ase-migrate-srclib-leaks-0210`); a stale `.so` silently simulating last week's Verilog is the failure to prevent. | |
| E7 | **Report M9 honestly.** If ngspice emits `"XSPICE time is behind vtime:"` the co-simulation has desynchronized and the waveforms are wrong. ASE-L must surface that from the log, not let it scroll past. | Correctness, not polish. |
| E8 | **There is no `post_commands` slot.** `pre_commands` exists (`src/ase.tcl:30`, and the migrator populated it correctly with both `auto_bridge` `pre_set`s), but nothing runs *after* the analysis — so `eprvcd`, which must follow `tran`, has no home in the state. Needed if the boundary-event VCD is ever wanted alongside the shim's internal VCD. | schema addition, mirrors `pre_commands` |
| E9 | **`render_deck` emits `print <expr>` per output — catastrophic for a transient.** The reference run's log is **49.9 MB** and the `print` flood dominates wall-clock (the raw was written ~4 min after the VCD finished). `print` on a 200k-point vector dumps every point. Fine for the `op` case `result_probe` was built for; wrong for `tran`. | Independent ASE-L defect, worth its own issue. |
| E10 | **Migration leaves junk outputs.** `ase_migrate` turned the graph widget's two `----` separator lines into outputs `{name o2 expr ----}` and `{name o7 expr ---}`, which render as `.save ----`. Hand-fixed in the reference state; the migrator should skip non-vector graph node lines. | Independent `ase_migrate.py` defect. |

### F — Signal Browser: Ctrl-Alt-V on a code block

| id | item | notes |
|----|------|-------|
| F1 | **The branch.** `ase::show_in_browser_for_current` (`src/ase.tcl:1098`) appends the selected instance name to the hierarchy segments and scopes the pane to that prefix. Add: if the selected instance's cell has a `verilog` view (§B + `library_inst_lcv`), scope to its **digital DB** instead of the analog one. | The `⚠` comments at `src/ase.tcl:1130-1143` are load-bearing — the selection and hierarchy must still be read in the DESIGN context, before any viewer raise. Preserve that ordering. |
| F2 | **Scope-path mapping — the hard one.** The schematic path is `x1.a1`. The VCD's internal path is whatever Verilator named the top module and its sub-scopes (`TOP.counter.cnt`, module-name based, subject to inlining). These two namespaces have **no inherent relationship**. Something must record, per `d_cosim` instance, "instance `x1.a1` ↔ VCD file F, scope S". Most likely produced at netlist time (§E2 already walks exactly these instances) and carried in the DB's metadata. | Without this, the browser can show the digital signals but cannot tell you *whose* they are. This is the item most likely to be underestimated. |
| F3 | **Multi-DB display.** The all-DBs reader (`src/wave_viewer.tcl:2000-2130`) already enumerates every registry slot and labels them (`wviewer::db_label`). Confirm a digital DB labels sensibly and that per-DB grouping in the tree reads well when analog and digital scopes interleave. | Mostly free. Verify, don't assume. |
| F4 | **Classification.** The `class`-field and hide-internals rulings (`signal-browser-declass-rulings`, issue 0217) were settled for raw vector names. Digital signals are a new class of name — decide whether they get their own class or reuse an existing one. | Consistency with settled work. |
| F5 | **Empty-pane notice.** Selecting a code-block instance in a run that produced no digital output must say *why* (no VCD / shim not trace-enabled / no scope mapping), not show an empty pane. The `ase::echo … error` pattern at `src/ase.tcl:1125` is the model. | The failure mode users will actually hit. |

### G — The reference testbench and the schematic side

**BUILT AND RUNNING** — `xschem_libraries_oa/ngspice_verilog_cosim_ase/`, produced by
`ase_migrate.py --library xschem_libraries_oa/ngspice_verilog_cosim --pdk sky130`
(the `_ase` suffix is the migrator's own default `--out`). Safe from
`tools/migrate/regen_oa.sh`, whose `rm -rf` list covers the 12 source libraries but not
`*_ase`. Registered with `DEFINE ngspice_verilog_cosim_ase …` in
`xschem_libraries_oa/library.defs` — note that line **will be lost** if `regen_oa.sh`
runs, since it rewrites `library.defs` from its own `LIBS`.

```
xschem_libraries_oa/ngspice_verilog_cosim_ase/
  counter/symbol/counter.sym                        <- symbol only, no schematic view
  counter/verilog/counter.v                         <- THE CODE VIEW (§B8)
  tb_counter_wrapper/schematic/tb_counter_wrapper.sch
  tb_counter_wrapper/ngspice_state1/…state          <- migrated ASE-L setup
  tb_sar_adc/…                                      <- migrated too, not yet exercised
```

`cell_views ngspice_verilog_cosim_ase counter` already answers **`symbol verilog`**, and
`cellview_path … verilog` already returns the `.v` — confirming §B's finding that
enumeration and resolution needed no code change. What is still missing is everything
that *types* that view (B1–B7).

Reference run, both artifacts from one `ase::run` (rundir `~/.xschem/simulations`):

| artifact | size | content |
|---|---|---|
| `tb_counter_wrapper_ase.raw` | 20.8 MB, 200,386 pts | `v(clk) v(count_out0..3) v(sum) i(vamm) i(auto_bridge3)` |
| `counter.vcd` | 1.7 MB, 200,344 stamps | `TOP.clk`, `TOP.count`, and `TOP.counter.{clk,count,phase,half,prev,next_count,tc,carry}` |

Six of those — `phase half prev next_count tc carry` — appear **nowhere in the raw**.
That is the payload the Signal Browser work exists to reach.

Verified (`xcheck.py`): VCD monotonic, not truncated, span 0..2.0000 µs; 10 counter-LSB
rising edges on **both** sides; `TOP.counter.tc` rises at 1450 ns = the 15th clock edge
(50 ns + 14×100 ns), i.e. exactly when `count` first reaches 15.

The original plan below (a `dig_top` wrapper, R-2R + RC + comparator feedback, and
`dbg_*` ports) is **superseded for first light** — the shim gives real internals, so the
`dbg_*` port workaround is not needed. Keep the wrapper/feedback ideas for when a
deeper hierarchy and a genuine analog→digital loop are wanted:

```
  dig_top/schematic/dig_top.sch        <- wrapper: gives the x1. hierarchy level
  tb_counter/schematic/tb_counter.sch  <- analog stimulus, R-2R, RC, comparator
```

| id | item | notes |
|----|------|-------|
| G1 | ~~`counter.v` with genuine internals~~ | **DONE.** Ports unchanged (`clk` in, `count[3:0]` out) so the symbol view needed no edit — that is the point: adding an INTERNAL costs nothing, adding a PORT costs a symbol edit. Internals: `phase half prev next_count tc carry`. The header comment states the port/symbol contract explicitly. |
| G2 | **Analog side that closes a loop.** R-2R ladder → RC lowpass → comparator → back into a digital input via an auto `adc_bridge`. The migrated TB is still one-way (analog clock in, weighted-R ladder out); a true analog→digital→analog loop is what makes it a mixed-signal test rather than digital-with-bridges. | **Still open.** Deferred: first light did not need it. |
| G3 | **Observation taps cost no symbols.** M5: a text line `robs <net> 0 1meg` in a code block gives the analog load that fires the auto-bridge, with nothing on the canvas. Upstream's `parax_cap` per net is avoidable. | **Still open**, and now lower value — the shim reaches internals directly, so taps are only for signals wanted in the *raw*. |
| G4 | ~~Symbol format for a code block~~ | **DONE / unchanged upstream form.** `type=primitive`, `format="@name [ @@clk ] [ @@count[3..0] ] @model"`, `device_model=".model counter d_cosim simulation=\"./counter.so\" sim_args=[\"counter.vcd\"] delay=0"`. The Verilator arm is now the active one (upstream shipped Icarus active; M12 rules that out here). Generating the symbol from the `verilog` view's port list stays a §B follow-on. |
| G5 | ~~Library path~~ | **DONE for headless.** Scripts set `::XSCHEM_LIBRARY_DEFS` to `xschem_libraries_oa/library.defs` and append the OA root to `XSCHEM_LIBRARY_PATH` — **unqualified**, or the write trace that rebuilds `pathlist` never fires. An interactive `./src/xschem` still needs the same two lines in `~/.xschem/xschemrc`. |
| G6 | **`counter/verilog/counter.v` is referenced by absolute-ish lookup.** The symbol's display text and `tclcommand` now use `[xschem cellview_path ngspice_verilog_cosim_ase/counter verilog]` instead of upstream's `[abs_sym_path counter.v]`, since the `.v` is no longer a loose file at the library root. That hardcodes the library name into the symbol — acceptable for a demo cell, but §B8 should provide a self-referential helper (`this cell's verilog view`). | new, from the build |

### H — Tests

| id | item |
|----|------|
| H1 | Headless VCD-reader unit tests: `$timescale` variants, buses, X/Z, `$dumpvars` initial block, missing `$enddefinitions`, truncated file (a killed simulator leaves one). |
| H2 | Golden mixed-signal run end-to-end: build `.so`, run ngspice, assert both artifacts exist, assert a known internal signal's edge times. Guard on `verilator` being present — skip cleanly, never fail, on a machine without it. |
| H3 | Time-base regression: an edge at a known SPICE time must land at the same time in both DBs (A6/D3). |
| H4 | Scope-mapping test for F2: `x1.a1` resolves to the right VCD scope with two `d_cosim` instances in one deck (the case A5 also guards). |
| H5 | View-model tests: `cell_views`/`view_type`/`view_handler`/`library_new_view` over `verilog` and `veriloga` views, both layouts. |
| H6 | Per CLAUDE.md, the trustworthy signal is `tests/headless/` (which has `gold/`). `create_save`/`open_close`/`netlisting` have no baseline and can only report `NOGOLD`. |

### I — Docs

| id | item |
|----|------|
| I1 | Keep this spec current as items land. |
| I2 | `doc/claude/FAQ.md` entry: why a digital signal must be bridged to be plottable (M1), and why that stops being true once §C lands. |
| I3 | Update the Signal Browser reference/explained docs once the browser is multi-source. |
| I4 | A user-facing note on the mixed-signal flow in the reference TB. |

---

## Open decisions

1. **Signal-name source for a `verilog` view: parse the `.v`, or read the VCD header?**
   Recommendation: **the VCD `$scope`/`$var` header.** No Verilog parser to write, and the
   names are what the simulator actually elaborated rather than a guess at what survived
   Verilator's inlining. Cost: names exist only after a run. Collapses C1's parsing and
   F1's name source into one piece of work.
2. **C2's materialization** — union-of-event-times vs. fixed grid. Measure against the
   reference TB before committing.
3. **C6's `sim_type` token** — `"tran"` (free compatibility) vs. `"vcd"` (honest, costs an
   audit of every literal `sim_type` comparison).
4. **C4's buses** — explode to bits at read time, or a native bus vector in `Raw`.
5. **F2's mapping ownership** — netlist-time emission (authoritative, automatic) vs. a
   symbol attribute (explicit, hand-maintained, wrong the moment someone renames a module).
6. **B9** — does `veriloga` need any of §C/§D at all, or is recognition sufficient?

## Dependency order

```
A2,A3,A4,A6  ──►  digital data exists on disk
      │
B1..B8       ──►  xschem knows the cell has a verilog view
      │
      ├──► C1..C7  ──►  a VCD is a Raw DB in the registry
      │        │
      │        └──► D1..D5  ──►  both DBs plot on one time axis
      │                 │
      └──► E1..E7  ─────┤  ASE-L produces and attaches both
                        │
                        └──► F1..F5  ──►  Ctrl-Alt-V on a code block works
```

§G is buildable immediately and should be, in the port-workaround form (internals promoted
to `dbg_*` output ports) — it validates A2/A3 and the whole simulation flow before any
xschem C code is written, and it becomes the golden case for H2. The `dbg_*` ports are
declared scaffolding: they disappear when §C lands.

§B is independently useful and independently testable — it can land and be reviewed on its
own merits without any of §C.

## Out of scope

- gtkwave as a viewer. Useful only as a **debug oracle** — `eprvcd` + gtkwave shows what the
  event nodes really did, independent of whether the bridges fired. It reads no spice raw,
  cross-probes nothing, and `src/rawtovcd.c` prints reals at `r%.3g` (3 significant digits)
  on a re-gridded time axis, so routing analog through it is a lossy re-render of data the
  viewer already reads natively.
- Xyce. Not installed; a second simulator backend is a separate decision.
- GHDL/VHDL co-simulation. `ghnggen` and `ghdl_shim.c` ship with ngspice, so the route
  exists, but nothing here depends on it.
- Writing VCD *from* xschem. `src/rawtovcd` already does that and is unrelated.
