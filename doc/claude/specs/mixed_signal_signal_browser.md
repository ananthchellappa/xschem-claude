# Mixed-signal debug — digital internals in the Signal Browser

Status: §A (simulation), §B (view model), §C (VCD → Raw DB) and §E (ASE-L) DONE; §D and §F open
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
| M18 | **ngspice lower-cases the strings inside a device card**, not just in script-file mode (M14). A path with any upper case in it is opened under a different name, and for `sim_args` **there is no error at all** — the run exits 0, the analog raw is perfect, the VCD simply never exists. | Measured 2026-08-08, ngspice-46: `sim_args=["/tmp/vcdprobe/Ecap/x.vcd"]` wrote nothing; pre-creating `/tmp/vcdprobe/ecap/` made the file appear **there**. `simulation="./CounterUP.so"` → `d_cosim failed to load simulation binary ./counterup.so.` (that one at least reports). **Forces E2 to write a bare, lower-cased basename** resolved against the run directory ngspice is already `cd`-ed into. Found only by running §E end to end — 141 green headless checks did not see it. |

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
| Ctrl-Alt-V today | `wave.show_in_signal_browser` → `ase::show_in_browser_for_current` — builds hierarchical segments from the design position, appends the selected instance name, scopes the lower pane to that prefix | `src/keybindings.csv:66`, `src/ase.tcl:2427` |

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
| A6 | ~~Pin the time-base contract~~ | **DONE, measured, and now REGRESSION-TESTED (H3/D3).** `tick = pow(10, contextp->timeprecision())`; `` `timescale 1ps/1ps `` → VCD `$timescale 1ps`, span `0..2000000 ps` for a `tran 10p 2u`. Cross-check: counter LSB first rising edge at **50.0120 ns (VCD)** vs **50.0219 ns (raw)** — the ~10 ps offset is exactly the `dac_bridge t_rise=1e-11` plus the 0.9 V analog threshold crossing, i.e. physical, not a units error. Re-measured 2026-08-09 against the artifacts still on disk and pinned to 0.1 ps by `tests/headless/test_vcd_time_base.tcl` group REF: 50.0120 ns vs **50.021883 ns**, skew **9.883 ps**. One thing the original figure left implicit and the test now states: the raw number is the first SAMPLE at or above 0.9 V, not an interpolated crossing — linearly interpolating the same crossing gives 50.01750 ns and a 5.5 ps skew. Both readings are well inside the test's tolerance, so the choice of rule is not what the regression is sensitive to. |
| A9 | **Throttle the trace dump** (new, from M17). 200,344 timestamps for ~40 transitions is ~1.7 MB per 2 µs and sets the floor for any reader's memory. Only dump when something changed, or subsample. | Not blocking; changes C2's arithmetic by ~4 orders of magnitude. |
| A7 | *(optional, alternative)* Build Icarus from source with shared `libvvp` to unlock the `ivlng` route and plain `$dumpvars`. | M12. Only if a `.v` feature Verilator lacks is needed. |
| A8 | *(optional, alternative)* `d_process` route — digital block as any external executable over pipes. Zero Verilog toolchain. | Worth a note in the spec; not on the critical path. |

### B — View model: `verilog` and `veriloga` become view types

Enumeration and resolution already work (`cell_views`, `cellview_resolve` — a
`counter/verilog/counter.v` on disk *already* lists as view `verilog` and
`cellview_path` already returns its path). What is missing is typing, creation,
routing, and the loose-file convention.

**STATUS: §B IS DONE** (2026-08-08, `fluid-editing`). B1–B9 all landed; the data-loss hole
described below is closed and regression-tested by `tests/headless/test_verilog_view_model.tcl`
(109 checks, 10 sabotages verified). The one residual is filed as **issue 0285**: `xschem load`
itself still empty-loads any non-schematic file, so the primitive under the bug survives for a
direct caller even though no UI path reaches it. See "What landed" at the end of this section.

**⚠ THIS WAS NOT PREP WORK — IT WAS A DATA-LOSS BUG.** Measured 2026-08-08 against the
reference cell, now that a `verilog` view exists on disk:

```
views        : symbol verilog                       <- enumerates fine
view_type    : 'data'                               <- should be 'verilog'
view_handler : 'editor'                             <- routes a .v to `xschem load`
lib_qualified_abs {…_ase/counter.v} -> …/counter/symbol/counter.sym   <- resolves to the SYMBOL

xschem load …/counter/verilog/counter.v
  SKIP RECORD / `timescale 1ps/1ps … / END SKIP RECORD   (every line)
  load returned OK (no error)
  schname : …/counter/verilog/counter.v
  wires=0 instances=0 texts=0   modified=0
```

`xschem load` on a `.v` **does not fail**. It skips every line and leaves an **empty schematic
whose `schname` is the Verilog source**, marked unmodified. Opening the verilog view from the
Library Manager therefore arms a save that writes an empty `.sch` over `counter.v`. The source
file survived this probe only because nothing saved.

So B1/B5/B6 are a fix, not scaffolding, and B5 (`view_handler`) is the one that closes the
hole.

| id | item | site |
|----|------|------|
| B1 | ~~**Extension→type map.**~~ **DONE.** `.v`,`.sv`→`verilog`; `.va`,`.vams`→`veriloga`, case-insensitive. `copyform::view_type` no longer carries its own switch — it defers to `view_type_of_ext`. The type flows into copyform's filter language for free (`type:verilog` selects the view). | `copyform::view_type`, `src/copy_form.tcl:52` |
| B2 | ~~**Creation.**~~ **DONE.** `library_new_view` uses `view_ext_of_type`, and **errors on an unknown type** instead of quietly writing a `.sch` — the old `$type eq "symbol" ? "sym" : "sch"` meant a `verilog` view was created as an empty SCHEMATIC. `library_new_cell` carried the same drift and got the same fix. | `src/library_defs.tcl:703` |
| B3 | ~~**New-View dialog.**~~ **DONE.** `-values {schematic symbol verilog veriloga ngspice_state1}`. B2's error turns an entry added here without a table row into a visible failure rather than a silent `.sch`. | `src/library_manager.tcl:1268` |
| B4 | ~~**Seed template.**~~ **DONE.** `library_symbol_pins` reads the `B` records out of the `.sym` **by text** (loading the symbol to count its pins would clobber the user's open schematic). Ports are emitted inputs → outputs → inouts, the order a `d_cosim` `format` string declares its bracket groups, and a bus `count[3..0]` becomes `output [3:0] count`. The seed carries a `` `timescale `` (A6's VCD time base) and states that the symbol owns the ports. No symbol view → a valid portless module that says so. `.va` gets the Verilog-A form (name list in the header, `input`/`electrical` statements, `analog begin`). | new, near B2 |
| B5 | ~~**Open routing.**~~ **DONE — this is the hunk that closed the hole.** `libmgr::view_handler` returns the new `libmgr::open_text_view` for `verilog`/`veriloga`, resolved from the datafile extension (view NAME only as the fallback). `libmgr::open_view_ro` had `ase::open_state` **hardcoded** behind its `ne {editor}` test — it now dispatches `$handler`, or a Verilog file would have been opened as a broken ASE state. `open_text_view` logs no action line (an external editor is not a replayable xschem operation) and reports honestly that it cannot be forced read-only. | `src/library_manager.tcl:437` |
| B6 | ~~**Ref resolution.**~~ **DONE.** `lib_qualified_abs` routes `.v`/`.va` through the new `cellview_resolve_typed`; a bare, extension-less `lib/cell` still means "the symbol to instantiate", which is why the default arm could not simply become `view_type_of_ext`'s answer. **`cellview_resolve_typed` exists because of a second door onto the same bug**: `cellview_resolve` ends in a legacy flat-layout fallback returning `<lib>/<cell>.sym` for any view name but `schematic`, so asking a *flat* library for its `verilog` view handed back the SYMBOL. It now takes that answer only when the extension reads back as the requested type, else looks for the loose `<lib>/<cell>.v`. `cellview_resolve` itself is untouched. | `src/library_defs.tcl:278` |
| B7 | ~~**Alt-2.**~~ **DONE.** The candidate model widened from "views of the other ext" to "views of any type in `alt2::toggle_types` that differs from the current type", with the classic partner type ordered first so the chooser default stays on top. `toggle_types` is `{schematic symbol verilog veriloga}` — `state` and `data` are deliberately out (a state view has its own window and Alt-2 never offered it). A candidate row is now `{view path type}`, and a `text`-typed candidate goes to `edit_file`, never `xschem load`. Registered-but-flat libraries get an extra probe: `cell_views` only knows `.sym`/`.sch` there, so a loose `<cell>.v` enumerates as no view at all. | `src/alt2_toggle_view.tcl:22,27,45` |
| B8 | ~~**Convention change + the self-referential helper.**~~ **DONE.** `cellview_sibling_path <ref> <view>` answers "this cell's `<view>` view" from any reference to another of its views — lib-qualified, `lib/cell.sym`, or an absolute path — and falls back to the loose sibling for the flat/unregistered layout, which is exactly upstream's `abs_sym_path counter.v`. The reference symbol now reads `tcleval([read_data [cellview_sibling_path @symref verilog]])`, with **no library name in it** (G6's hardcoded `[xschem cellview_path ngspice_verilog_cosim_ase/counter verilog]` is gone). Verified end to end through the real token substitution on the real instance: `@symref` → `ngspice_verilog_cosim_ase/counter` → 1962 chars of Verilog. **Landmine:** the `.sym` T-record parser does not accept nested braces, so `{@symref}` truncates the record at the inner `}` — write `@symref` bare. | convention + `abs_sym_path` |
| B9 | ~~**`veriloga` — decide separately.**~~ **DECIDED: recognition only, and nothing more.** A Verilog-A module is analog. Its nodes reach the ngspice raw file directly through OSDI, so the M1+M3+M6 chain that forces the whole of §C/§D on the digital side simply does not apply to it: there is no event-node barrier to cross, no VCD to read, no second DB to reconcile onto one time axis. What `veriloga` needs is exactly B1–B6 — that a `.va` **types** as its own thing, **creates** as a `.va` with a Verilog-A seed, **routes** to a text editor instead of the schematic loader, and **resolves** as itself rather than as the symbol. All four are asserted (B9a/B9b in the test), including that `.va`/`.vams` never type as `verilog`. §C, §D and §F stay digital-only. Revisit only if a Verilog-A flow appears whose internals do *not* reach the raw. | analysis |

**What landed** — one table, five files:

`view_type_of_ext` / `view_exts_of_type` / `view_ext_of_type` / `view_type_opener` /
`view_default_name` in `src/library_defs.tcl` are the single view-type model. The rule was
previously spelled out four times, each with a private extension switch, and they had **drifted**:
`.v` was type `data` to copyform, opened with `xschem load` by `libmgr::view_handler`, and
resolved to the symbol view by `lib_qualified_abs`. Consumers are `copyform::view_type`,
`library_new_view`/`library_new_cell`, `libmgr::view_handler`, `lib_qualified_abs` /
`cellview_resolve_typed` / `cellview_sibling_path`, and `alt2::*`.

Test: `tests/headless/test_verilog_view_model.tcl` — 109 checks over `verilog` **and** `veriloga`,
in **both** the nested `lib/cell/view` layout and the legacy flat layout, plus a `REF` block that
re-runs the original measured repro against the real reference cell and skips cleanly when
`xschem_libraries_oa/` is absent. Pinned to the `--nogui` arm in `full_audit.sh`. Ten sabotages
were injected and every one was caught by the checks that should catch it.

Not covered by §B, filed instead: **issue 0285** — `xschem load` on a `.v` still returns OK,
skips every line, and leaves an empty schematic named after the source. No UI path reaches it any
more, but the primitive is unchanged for a direct caller (CIW, script, action log).

### C — Waveform Viewer: read a VCD into a `Raw` DB

The deliverable is a second *producer* for the same consumer. Nothing downstream should
learn what a VCD is.

**STATUS: §C IS DONE** (2026-08-08, `fluid-editing`). C1–C7 all landed in `src/vcd_read.c`
(+ four wiring hunks). `xschem raw vcd_read <f>` / `xschem raw read <f> vcd` puts a VCD in
`extra_raw_arr[]` as an ordinary DB that `xschem raw info` lists; the reference
`counter.vcd` reads as **29 vectors × 20 points**. Regression-tested by
`tests/headless/test_vcd_read.tcl` (187 checks, 22 sabotages verified). One residue filed
as **issue 0290**: `xschem raw_read <f> table` still bypasses the reader dispatch — the
same defect one file format over, fixed here for `vcd` only.

**The re-measurement that shaped C1 and C2.** The spec's recorded artifact was stale. On the
current `~/.xschem/simulations/counter.vcd` (390 KB, span 0..500,000 ps):

| measured | value |
|---|---|
| `#t` timestamp lines | **50,088** |
| value-change lines | **36** |
| distinct timestamps carrying any change | **10** |
| `$var` lines / distinct id codes | **10 / 8** |

M17 is real and worse than recorded: **5,009** timestamp headers per timestamp that means
anything. And the id codes are **not 1:1 with signals** — `clk` and `count` are declared in
both `TOP` and `TOP.counter` with the *same* code (`&`, `'`).

| id | item | outcome |
|----|------|---------|
| C1 | ~~`vcd_read()` → a populated `Raw`~~ | **DONE.** `src/vcd_read.c`, added to `/local/src` in `src/Makefile.in` (scconfig generates both the `OBJ` entry and the explicit compile rule — `./configure` regenerates `src/Makefile`). Header and body are parsed as ONE whitespace-token stream, which is what the VCD grammar actually is; that is what makes a truncated file and a missing `$enddefinitions` non-fatal rather than special cases. |
| C1b | **Aliasing — one id, many vectors** (new, from the measurement) | An id is not a signal, it is a shared value cell. `Vcd_id` holds a LIST of variable indices and one change writes every column bound to it. `nvars` follows the `$var` count, never the id count. A 1:1 assumption would have silently dropped one of the two `count` vectors — precisely the payload this feature exists to surface. |
| C2 | ~~Event stream → sampled columns~~ | **DONE — change times, as a STEP.** Neither of the spec's options: (a) "union of event times" was ambiguous and the ambiguity was the whole decision. Columns come from times where a value *actually changes* (10), not from `#t` headers (50,088) — 29 × 50,088 × 8 B = **11.6 MB** versus **4.6 KB**, ~2,500×. Each change emits TWO columns, `(t-1, old)` and `(t, new)`, because `draw_graph_points()` renders with `XDrawLines()` in the `digital=1` path too — it **interpolates**, so one column per change would draw a 50 ns ramp where a clock edge belongs. Plus the first and last `#t` so the trace spans the run. Reference file → **20 columns**: `0 50011 50012 … 450011 450012 500000`. |
| C3 | ~~X and Z~~ | **DONE — four distinct doubles, no struct change.** `0→0.0  1→1.0  X→0.5  Z→0.3`. Not arbitrary: `get_bus_value()` already prints `'X'` for a bit inside its `vthl..vthh` undefined band, which is **0.2..0.8** on a 0..1 digital strip, so both sentinels render as `X` through the *existing* renderer — C7 needed no code. They differ from each other so `xschem raw value` distinguishes them. A vector with any `x` bit is X as a whole; any `z` and no `x` is Z; bits keep their own state. A parallel state array in `Raw` was rejected: it changes a struct every consumer touches and buys nothing until a renderer reads it. |
| C4 | ~~Buses~~ | **DONE — explode to bits AND keep the composite.** `$var wire 4 ' count [3:0]` → five columns: `count` (0..15) plus `count[3]`..`count[0]`. The composite is the honest name and the value `xschem raw value` returns; the bits are what the only working bus display can actually draw (`node="bus; b3,b2,b1,b0"` → `get_bus_idx_array()`). Both are cheap — 10 `$var` lines cost 29 columns. Declared bit direction is honoured, so `[0:2]` names bits the other way round. |
| C5 | ~~Scheduler surface~~ | **DONE.** `extra_rawfile()`'s `what==1` table arm generalised to `table`\|`vcd` (it already had the whole registry protocol); `xschem raw vcd_read <f>` in `xschem_cmds_r` beside `raw table_read`; top-level `xschem vcd_read` in `xschem_cmds_v` beside `table_read`'s in `_t`. `xschem raw read <f> vcd` works for free. **`raw_read` also had to be patched**: it bypasses `extra_rawfile()` entirely, and `open_sub_schematic`/`hi_descend` carry a DB across windows with `xschem raw_read $rawfile [xschem raw_query sim_type]` — so a VCD would have been handed to the spice parser. Issue **0290** is the untouched `table` twin. |
| C6 | ~~`sim_type` token~~ | **DECIDED: `"vcd"`, and it is not merely the honest choice — it is forced.** The audit found **17** `raw->sim_type`-vs-literal sites (the spec said 3, the work order said 10), and **all 17 behave identically for `"vcd"` and `"tran"`**: every one is an is-it-`op` or is-it-`dc` test. `"tran"` therefore buys ZERO compatibility. Meanwhile `save.c`'s `extra_rawfile()` uses the type string as the **reader dispatch key**, so claiming `"tran"` would route the `.vcd` into `read_dataset()`. Precedent already exists: `"table"` is a non-analysis token. (`scheduler.c:9860`, in the work order's list, is dead code inside `#if 0`.) |
| C7 | ~~Digital rendering~~ | **CONFIRMED, no change needed.** `digital=1` draws a 0/1 `SPICE_DATA` trace via `draw_graph_points()`; the C3 encoding makes X/Z render inside `get_bus_value()`'s existing undefined band. The one thing the render path *forced* was C2's step materialization (it interpolates). |

**Not fixed, by design:** names are stored **verbatim**, unlike `read_dataset()` which
`strtolower()`s every spice node name. Verilog is case-sensitive — `Count` and `count` are
two signals — so folding would merge columns. The cost is that `get_raw_index()`'s
verbatim→upper→lower probe ladder will not find a mixed-case VCD name from a lower-case
query. Mapping a schematic path onto a VCD scope path is F2's job and is not a case-folding
problem.

**Carried into §D:** a graph rect tagged `sim_type=vcd` will *not* X-follow a rect tagged
`sim_type=tran` — `callback.c` and `draw.c` gate pan/zoom propagation on the two rects'
`sim_type=` **property tokens** matching. That is D2's problem (joint X domain) and the fix
is a real one, not lying about the type.

### D — Two DBs, one time axis

The registry is a **switch** model — one current DB at a time — and per-graph selection
(`callback.c:2047`) works by switching, drawing, switching back. Plotting analog and
digital *together* is the new requirement.

| id | item | notes |
|----|------|-------|
| D1 | ~~**Per-trace DB resolution.**~~ **DONE (2026-08-09) — the shortcut was already in C; the missing half was all Tcl.** Reviewed adversarially and **three defects it created were fixed in the same round** (see "the review round" below). `tests/headless/test_wave_crossdb_trace.tcl`, **109 checks (51 headless), 8 + 21 sabotages injected, all caught.** See the write-up below the table. | The core §D change. |
| D2 | **Joint X domain.** Two DBs have independent time vectors, extents, and point counts. Zoom, pan, `x1/x2`, and the shared-X strip logic must span the union. | Silent-wrong-answer risk if one DB's extent is used as the whole. |
| D3 | ~~**Time-unit reconciliation.**~~ **DONE — converted once at read (C1, `vcd_read()` stores seconds) and now ASSERTED against A6.** `tests/headless/test_vcd_time_base.tcl`, **124 checks** (112 when the reference artifacts are absent), pinned to the `--nogui` arm. The gate is a stated number, not a feeling: **100 ps**, which is 10.1× above the measured 9.883 ps physical skew and at minimum ~500× below the smallest 1e3 error the file can produce (the ÷1000 direction on the earliest edge used, 50 ns → 49.95 ns of displacement; the ×1000 direction is 499,500×). A zero tolerance would be wrong — the two DBs record different events, a Verilog value change versus an analog threshold crossing after a finite `dac_bridge t_rise`, sampled on ngspice's timestep grid. Coverage: six `$timescale` units including the two-token `10 ns` form, the whole fs→ps→ns→µs→ms→s ladder (**every rung of which IS the 1e3 factor**), the multiplier forms, seconds-not-ticks, and the symmetric "rescale the raw instead" error. The 1e3 rejection is **proved, not asserted**: nine negative-control VCDs that are deliberately 1e3 wrong — perfectly valid files, which is the whole point — go through the *same* `agree` proc the real checks use and must be rejected. **19 sabotages injected, all 19 caught; every one of the 124 checks is caught by at least one.** | Off-by-1e3 here looks like a plausible waveform. |
| D4 | **Cursors, markers, annotation across DBs.** `annot_p`/`annot_x`/`annot_sweep_idx` are per-`Raw`. A cursor at time *t* must resolve in both — with the nearest-sample-before rule differing between a dense analog sweep and a sparse event stream. | `Raw` fields, `src/xschem.h:1129-1137` |
| D5 | **Backannotation.** `annotate_op` and the schematic voltage overlay read the current DB. Define what a digital DB contributes (probably: nothing, explicitly). | `src/scheduler.c:2145` |

#### D1 — what was already there, and what was missing

**The C shortcut is real.** One `node=` entry is

```
[alias;]<vec-or-RPN> [ '%' [<dataset-digits> ] <rawfile> [ <sim_type> ] ]
```

and `draw_graph()` (`src/draw.c:8185-8215`) reacts to the `%` part by calling
`extra_rawfile(<autoload>, <rawfile>, <sim_type>, …)`, drawing that ONE trace against
that database, and switching back at the end of that node's iteration
(`draw.c:8438`). `autoload` absent maps to **what-code 2, switch-only**
(`draw.c:8133-8135`), so the database must ALREADY be in the registry and the `%`
value must byte-match the stored path — `extra_rawfile()`'s switch arm is a bare
`strcmp` on path AND `sim_type` (`save.c:1653-1655`).

**Everything above the renderer was missing.** `wviewer::add_trace` validated against
`xschem raw list` — the CURRENT database only — so a VCD signal was refused unless the
user made the VCD current, which then broke every analog trace in the window. And
`wviewer::graph_props` never emitted a `%` at all, while `wviewer::regenerate` rebuilds
every rect from `graph_props` — on a window RESIZE, on `add_trace`, on `attach_raw`. A
`%` poked onto a rect with `xschem setprop` therefore survived exactly until the next
repaint. **Carrying the database in the trace dict and emitting it in `graph_props` is
the whole feature**; setting a rect once is a demo that dies on resize.

Landed in `src/wave_viewer.tcl`:

* `wviewer::db_path_safe` — the `%` grammar's hazard list, one place. Both fields pass
  through Tcl `subst {…}` **twice** (`draw.c:8191/8193`, then `save.c:1649`) and the
  sub-field separator set is `"\n "`, so whitespace, `%`, `"`, `\`, `$`, `[`, `]`, `{`
  and `}` are all refused. `~` is **not** expanded by `subst` and is not a hazard.
* `wviewer::db_suffix` — `{}` for an ordinary current-DB trace (so every existing model
  dict, state file and emitted `node=` string is byte-identical to pre-§D1), else
  `%<rawfile> <sim_type>`. **Never a half suffix**: with no type, `draw_graph()`
  substitutes the CURRENT database's `sim_type` (`draw.c:8194-8195`) and the switch fails
  silently.
* `wviewer::resolve_signal_db` — searches EVERY registered database through the existing
  all-DBs reader `signal_list_all`, which yields the current DB first, so a name present
  in both resolves to the current one and earns no suffix.
* `graph_props` emits the **alias** form `"<display>;<vec>%<path> <type>"` whenever a
  suffix is present. Not cosmetic: `draw_graph()` hands the WHOLE token to
  `draw_graph_variables()` for the legend (`draw.c:8247`), so a bare `vec%path type`
  legends as the absolute path — MEASURED, the legend read
  `TOP.m.siga%/home/qflow/dev/xschem/claude_1/…`.

**Proof, measured not inferred.** `tests/headless/test_wave_crossdb_trace.tcl` renders a
real PNG of a viewer strip and pixel-probes it. The probe is self-calibrating: the VCD's
square wave supplies both axes (its two logic levels are value 0 and 1, its rising edges
are t = T/4 and 3T/4) and the analog sine is then required to land where that calibration
predicts — a sine on a different time base could not put its peak on the VCD's first
rising edge. The reference co-sim pair renders too: `v(clk)` from
`tb_counter_wrapper_ase.raw` and `TOP.counter.clk` + `TOP.counter.count` from
`counter.vcd`, in one strip, the analog clock's edges aligned with the Verilog clock's.

#### D1 — the review round (2026-08-09)

A three-lens adversarial review of the change above found **three defects, all created
by it** — at its parent commit a cross-DB trace cannot be created at all, so none of
them predates it. All three are fixed; the full list of what they leave behind lives in
`doc/claude/issues/0305-*.md`'s addendum.

1. **A saved cross-DB trace came back SILENTLY BLANK.** `ase::ui::viewer_restore` handed
   `wviewer::restore` the primary analog raw alone, and `restore` did `raw clear` + ONE
   `raw read` — so the database a trace's `%` suffix named was not in the registry when
   `draw_graph()` tried to switch to it. `extra_rawfile()`'s switch failure is `dbg(1)`,
   and the strip still LISTS the signal in its legend, so the symptom read as "that
   signal is flat" rather than "the data is gone". `restore` now takes the extra
   databases as a fifth argument (filled from `ase::last_vcdfiles`, the same list
   `dp_finish` and `auto_plot` already pass to `attach_raw`) UNIONED with the databases
   its own restored traces name (`wviewer::trace_dbs`) — neither list is a superset of
   the other. A database it still cannot attach is reported once, naming the traces that
   will draw nothing; the session opens anyway. **Proved across two processes**: a state
   file carrying a cross-DB trace, reopened in a fresh xschem, pixel-probed — 145 red
   columns (legend text alone) before, 510 after, with the legend-only floor measured in
   the same process by detaching the VCD and re-rendering.
2. **The signal browser plotted the WRONG database, silently.** The tree row id already
   carries the database (`d:1|s:TOP.m.sig` vs `d:2|s:TOP.m.sig`); `browser_leaf_names`
   dropped it and handed `add_trace` a bare name, which `resolve_signal_db` resolved to
   the LOWEST-index match. A double-click under blockB's header therefore drew blockA's
   waveform, and selecting both rows and pressing Plot produced ONE trace (the dedupe was
   on the name). **This is exactly the shape §E produces when two `d_cosim` blocks
   instantiate the same Verilog module.** `browser_leaf_specs` now answers `{name db}`
   pairs, the dedupe is on the pair, and the database is carried to `add_trace`'s new
   `db` argument, where it OVERRIDES the name search entirely. Decision 4 ("the current
   DB wins") still governs every caller that has only a name.
3. A comment cited a **nonexistent issue 0301** and four stale `draw.c` line numbers.
   Every citation in the §D1 comment block, in issue 0305, in this write-up and in the
   test header was re-verified against the tree.

**What §D1 does NOT buy** (issue 0305): only three of the six functions that walk `node=`
honour `%rawfile`. `graph_point_at()`, `wave_hilight_envelope()` and
`graph_wave_resolve()` parsed the `%` for the dataset digits only and dropped the
rawfile, so a cross-DB trace **rendered but was not pickable, not boldable and not
markable**. ~~That is issue 0305~~ — **FIXED 2026-08-09, batch F item 1: see the
`node_token_split()` write-up immediately below.** `graph_fullxzoom()` (`draw.c:3284`)
still never parses `%` at all, so the auto X window spans the CURRENT database's extent
only — that is D2 below, and it is visible with the reference pair (raw 0..2 µs, VCD
0..500 ns: the VCD trace occupies the left quarter and stops).

#### D1 — `node_token_split()`, the one `%` parser (issue 0305, 2026-08-09)

All six `node=` walkers in `src/draw.c` now call ONE parser,

```c
static void node_token_split(const char *ntok, char **expr, int *dataset,
                             char **rawfile, char **sim_type,
                             const char *dflt_sim_type);
```

which splits an entry into its expression half and its optional `%[digits] [rawfile]
[sim_type]` half, Tcl-`subst`s both fields exactly as `draw_graph()` always did, and
**switches nothing** — the switch, and the restore that must pair with it, stay at the
call site where the unwind point is known.

**RULING — the restore is an ABSOLUTE INDEX, never `extra_rawfile()`'s mode-5 swap.**
Mode 5 swaps `extra_idx` with `extra_prev_idx` (`save.c`); it is not a stack pop. Issue
0305 introduces a SECOND, per-trace switch nested inside the graph-level `rawfile=`
switch that `graph_point_at()`, `wave_hilight_envelope()` and `graph_marker_sample()`
already made, and a swap cannot unwind two levels — it lands the session on the inner
database. Both levels therefore restore through `node_db_restore(idx)`, which is
`extra_rawfile(2, "<idx>", …)`, and absolute restores compose. **Evidence:** with the
per-node restore deleted (sabotages S4/S8) a bare HOVER over a strip whose own
`rawfile=` does not resolve leaves the whole session pointing at the VCD, and 19 later
checks of `tests/headless/test_node_token_split.tcl` go red in cascade. The graph-level
restore alone hid this in the common case only because a rect with no `rawfile=` token
inherits `xctx->raw->rawfile` and "switches to itself", which happens to re-anchor the
index; the moment the graph-level switch fails, nothing else is holding the place.

**RULING — the helper goes to ALL SIX walkers, including the three that already
honoured `%rawfile`.** Batch F item 2 owns the residual defects in
`find_closest_wave()` (its single mode-5 restore outside the loop) and
`graph_fullyzoom()` (two `return 0` paths that skip the restore and leak
`ntok_copy`/`express`); those are untouched here. But leaving their hand-rolled `%`
parse in place would have left two of the seven copies the issue's own diagnosis names
as the drift mechanism, and item 2 has to touch exactly those functions anyway.
Extraction without behaviour change there, defect repair in item 2.

**RULING — a per-trace switch re-resolves the SWEEP COLUMN by NAME, on every entry that
took the switch.** (Added 2026-08-09 in review of this item; the first cut of it
re-resolved the column only when the entry carried its *own* `sweep=` token, and that
was a **segfault**, not a cosmetic bug.) The `sweep=` list may be shorter than the
`node=` list — the documented carry-forward case, `draw.c:6004` and `test_wave_markers.tcl`
MF1 — in which case an entry inherits the sweep variable of the entry before it. What it
must inherit is the variable's **name**: a column *number* was resolved in the previous
database and means nothing in this one. A three-column VCD indexed with a five-column
analog raw's `values[4]` reads off the end of the array, and pick, bold and marker each
die on it. Every one of the three walkers therefore keeps the last non-empty sweep token
(`sweep_name`, which points into the `sweep=` buffer `my_strtok_r` split in place) and
calls `get_raw_index()` again after the switch; each then clamps the result against the
switched-in `xctx->raw->nvars` as a second line of defence. **Evidence:** with the
re-resolution reverted to "only when this entry has its own token", the strip built by
the `NDS` leg of `tests/headless/test_node_token_split.tcl` — graph-level `rawfile=` to a
five-column raw, one `sweep=` token for three `node=` entries, entry 2 cross-DB into a
VCD — makes each of `graph_point_at()`, `wave_hilight_envelope()` and
`graph_wave_resolve()` `FATAL: signal 11` in turn (sabotages S1/S3/S5 of §5 of the
receipt). The parent commit `96f7678a` does not crash there **only** because it never
switched database at all.

**RULING — an unresolvable per-trace database REFUSES the trace.** It does not fall
back to the current database. Falling back plots a *different signal under the trace's
name*, which is the silent-wrong-answer class this spec's D2 row also warns about. This
was measurable before the fix: an entry naming a nonexistent `.raw` was pickable,
boldable and markable, answering with whatever the current database held (checks
NDG5/NDG7/NDG8, red at the parent commit).

Pinned by `tests/headless/test_node_token_split.tcl` (**91 checks, true headless**, in
`full_audit.sh`'s `nogui_tests`): 19 of them red at the parent commit `96f7678a`, and
thirty-one sabotages injected across the two rounds, every one caught. Three of those
checks (`NDX1`–`NDX3`) are **structural, not behavioural**: they read `src/draw.c` and
assert that the `%` field is parsed in exactly two places, both inside
`node_token_split()`, and that the parser has exactly six call sites. Nothing
behavioural can see a seventh hand-rolled copy appear — which is precisely how this
drifted to three-of-six in the first place. Two source-level checks in
`tests/headless/test_wave_hilight.tcl` (WH9h, landmine 40) were **restated, not
deleted**: the unwind mechanism and the switch count both genuinely changed, and the
restated pair now demands two switches, two restores and zero mode-5 swaps in
`wave_hilight_envelope()`.

~~`find_closest_wave()` is reachable only from `callback.c`'s graph motion handler, i.e.
a real DISPLAY, and was therefore NOT exercised behaviourally by that test.~~ It is now,
through the query verb added in item 2 — see immediately below.

#### D1b — the residual brackets and the sweep column (issue 0305, batch F item 2, 2026-08-09)

Item 1 moved the `%` parse of all six walkers into `node_token_split()` and deliberately
left three defects standing. They are fixed here, and the rulings behind them are the
same shape: **a walker that switches the session's database owes a restore on every exit
path, and an index resolved in one database means nothing in another.**

**RULING — `find_closest_wave()` gets `graph_point_at()`'s two-level bracket, not a
swap.** Its graph-level `rawfile=`/`sim_type=` switch was made once per NODE, inside the
walk, and unwound by ONE `extra_rawfile(5, …)` after it. Both halves were wrong. Mode 5
swaps `extra_idx` with `extra_prev_idx`; with the per-trace switch of D1 nested inside the
graph-level one it lands the session on whichever database the last switch came from. And
the swap ran whether or not the switch had TAKEN, so a graph whose `rawfile=` does not
resolve had an unpaired restore repoint the session's raw on every call — and this
function runs on a graph gesture. It now switches ONCE above the loop behind a `switched`
flag, restores per node at the bottom of the body and once at the end, both by absolute
index (`node_db_restore`). **Evidence:** reinstating the swap alone (sabotage S2) turns
`NDC1 NDC2 NDC3 NDC4 NDC5 NDC6` of `tests/headless/test_node_token_split.tcl` red — a
single hover on the nested strip, entered on slot 3, leaves the session on the VCD;
deleting the per-node half alone (S1) reddens `NDC3`, because the entry AFTER a cross-DB
one is then resolved in the cross-DB database.

**RULING — one epilogue, reached by `goto`; a refusal never hand-copies the cleanup.**
`graph_fullyzoom()`'s two refusals were bare `return 0`s that each hand-copied a SUBSET
of the function's frees — and each got the subset wrong. The corrected inventory: they
leaked `ntok_copy` (**13 bytes per refused fullyzoom, measured** — see below), and
neither restored the database the graph-level switch had just made, so a strip whose
graph database resolves and whose per-trace `%<rawfile>` does not left the whole SESSION
pointing at the graph's database. **The addendum's claim that `express` also leaked is
wrong**: `express` is scoped inside the `if(!bus_msb)` block and freed unconditionally
before either refusal is reachable. Both refusals are now `goto fullyzoom_done`, the
function's single exit; a third one added later inherits the restore and the frees by
construction. **Evidence:** the leak is a differential `-d 3 -l log` +
`src/track_memory.awk` measurement, 5 vs 205 refusals in one process: **fixed 830 → 830
bytes (slope 0), the pre-item bypass restored 895 → 3495 (slope 13 B/refusal, exactly
`strlen("bad;v(wonly)") + 1`)**. The restore is `NDL1`–`NDL4`.

**RULING — the "re-resolve the sweep column BY NAME" rule of D1 covers ALL SIX walkers,
not the three that had a per-trace switch when it was written.** `draw_graph()` — the
REFERENCE walker — and `graph_fullyzoom()` both resolve the column after their switch but
only for entries carrying their own `sweep=` token, and a `sweep=` list shorter than the
`node=` list carries the previous entry's token forward. So the wide raw's `v(wsw)`
(column 4) was carried into a three-column VCD and used as `values[4]`. This is not
latent: **on a real display the renderer SIGSEGVs.** Evidence, both measured:
* reverting `graph_fullyzoom()`'s re-resolve (S4) makes the headless file die with
  `FATAL: signal 11` after 106 of its 118 checks;
* reverting `draw_graph()`'s (S5) makes the on-display probe SIGSEGV inside the
  `zoom_full` redraw, before the strip is ever drawn once; with the fix the same probe
  survives 25 explicit `xschem draw_graph` calls.
All six now keep `sweep_name`, re-`get_raw_index()` it after the switch and clamp the
result against the switched-in `xctx->raw->nvars` (`NDR2`/`NDR3` count both, six each).

**RULING — a function reachable only from a gesture gets a read-only query verb.**
`find_closest_wave()`'s sole caller is `callback.c`'s graph `t` key arm, so no check in
the tree could reach it — which is exactly why its restore was the one that drifted.
`xschem get graph_closest_wave <graph_idx> <px> <py>` (scheduler.c, wrapping the new
`graph_closest_wave()` in draw.c) answers `"<dataset> <node_index>"` at a canvas pixel. It
is not a duplicate of `graph_trace_at`: that is `graph_point_at()`, a different walker
with a tolerance and a segment metric. It sets up the transform, moves the C mouse mirror
for the duration of the call and puts it back, and fails soft (`-1 -1`) on every refusal.
**Evidence that the seam is load-bearing and not a stub:** dropping its
canvas→schematic transform (S9) turns four NDC checks into `-1`.

Item 2's legs take `tests/headless/test_node_token_split.tcl` from 91 checks to **118**
(`NDC` bracket, `NDL` epilogue, `NDW` sweep column, `NDR` structural, plus three `NDF`
premise checks); **fifteen sabotages, thirteen caught**. The two uncaught ones are named
in the receipt and are both "this line is masked by another that already enforces it",
not gaps in the item.

**Not fixed, and not this item's:** `graph_fullxzoom()` still never parses `%` (that is
D2); `graph_fullyzoom()`'s `save_npoints` is never reset to `-1` after the first
OP→dc-sweep restore, so a later entry re-applies the first entry's counts to whatever
database is current — pre-existing, untouched, and unrelated to the `%` field.

##### D1b fix round — what adversarial review found still open (2026-08-09)

Five findings, each raised with a reproducer. Three of them were the same shape as the
item itself: *the contract claims more than any check watches.*

**RULING — "the session's current database" means the WHOLE registry cursor, not the
current slot.** `extra_idx` says which database is current; `extra_prev_idx` says where
`xschem raw switch_back` will GO, and that idiom is real — `xschem.tcl:4743` and shipped
schematics' `tcleval()` blocks both do `raw switch <f> … switch_back`. Every
`extra_rawfile()` switch overwrites the second half, and in READ mode so does a FAILED one
(`save.c`: `xctx->raw = save; xctx->extra_prev_idx = xctx->extra_idx;`). So a walker that
unwinds only `extra_idx` has still moved the session, and a *read-only getter* could do
it: measured with prev=1 / current=3, ONE call to `graph_closest_wave`, `graph_trace_at`,
`wave_hilight_points` or a refused `fullyzoom` made the next `switch_back` land on slot 2.
This is a FAMILY property (two of those four are unchanged HEAD code), so the fix is
family-wide: `node_db_prev_restore()` (draw.c), called once per walker at its graph-level
unwind and AFTER it, in ALL SIX. Deliberately NOT called by the per-node unwinds inside a
walk — those are intermediate; the entry value is what the session is owed.
**Evidence:** `NDU0` (control, no walker) plus `NDU1`–`NDU5`, one per reachable walker;
`NDR7` counts the six call sites, because `draw_graph()` needs a canvas and
`graph_wave_resolve()` needs a marker drag. Deleting the call in any one walker reddens
exactly that walker's `NDU` check and `NDR7`; gutting the helper's body reddens all five
`NDU`s and `NDL3` while leaving `NDR7` green (named blind spot: a structural count cannot
see an empty body).

**RULING — a query verb does not write to stderr.** `debug_var` is 0 in a normal run, so
`dbg(0, …)` is not a level, it is an unconditional `fprintf`. `find_closest_wave()`'s
"closest dataset=…" trace was one: harmless while a graph `t` keypress was its only
trigger, once-per-CALL as soon as `xschem get graph_closest_wave` existed (20 lines from
`NDC5` alone, 25 per suite run). Now `dbg(1, …)`. **Evidence:** `NDR8` (structural — a
process cannot read its own stderr) plus the measured 25 → 0 lines per run.

**CORRECTION — the two `graph_fullyzoom()` refusals are NOT symmetric, and the ruling
above over-claimed by lumping them.** The graph-level switch is loop-invariant, so its
refusal can only fire on iteration 1: `ntok_copy` is still NULL there and no switch is
outstanding, and the pre-item `return 0` on that path leaked nothing and stranded nothing.
Everything the ruling says is true of the PER-TRACE refusal only. Reverting the
graph-level one alone left `NDL1`–`NDL5` green, i.e. `NDL3`'s name asserted a property no
behavioural evidence covered. What the graph-level refusal *does* leave behind is the
cursor's other half (the READ-mode clobber above), so `NDL3` now runs that strip with
`autoload=true` and asserts where `switch_back` goes — and reverting the first refusal to
`return 0` reddens it. The structural guard (`NDR4`/`NDR5`) stays.

**RULING — a leak is proved by a differential, and the probe lives in the repo.** The
restore half of residual (b) was pinned by `NDL1`–`NDL5`; the LEAK half by nothing —
deleting the epilogue's `my_free(_ALLOC_ID_, &ntok_copy)` reintroduced a leak larger than
the one the item fixed and left all 118 checks green. `NDK0`–`NDK2` now run
`tests/headless/leakprobe_fullyzoom.tcl` as two child processes (5 and 55 refusals) under
`-d 3 -l <log>`, and compare `src/track_memory.awk`'s totals: equal = slope 0. It must be
a differential because with `_ALLOC_ID_` left as the placeholder `0` every allocation
shares one id and only the slope means anything. **Evidence:** with the free deleted,
`830/830` becomes `895/1545` and `NDK1` alone goes red; `NDK2` guards the vacuous case
where the child ignores its loop count.

**RULING — the mouse mirror put-back is watched through its production consumer.**
`graph_closest_wave()` parks `xctx->mousex/mousey` on the pixel it is asked about; nothing
observed the put-back, and deleting it left all 118 green. `xschem closest_object`
(`find_closest_obj(xctx->mousex, xctx->mousey, 0)`) is the observable, so no new getter was
added. **The capture point is load-bearing**: `NDC9` reads it BEFORE the file's first
query, because with the put-back deleted the mirror parks on the first call and every
later before/after pair then matches — moving the capture after the first query makes the
check pass against the broken code (demonstrated).

The file is now **130 checks** (was 118). `graph_fullxzoom()`'s carried sweep index was
raised in this round and **NOT confirmed** — no reproducer was produced, and D2 already
owns that function; it is recorded in the receipt, not acted on.

### E — ASE-L: recognize, emit and attach a mixed-signal run

**STATUS: §E IS DONE** (2026-08-08, `fluid-editing`). E1–E7 landed in `src/ase.tcl` (one new
section, ~430 lines) plus three wiring hunks (`src/ase_window.tcl` ×3, `src/wave_viewer.tcl` ×1).
`ase::run` on the reference TB now rebuilds `counter.so` when `counter.v` changed, writes
`<rundir>/counter.vcd` beside `<cell>_ase.raw`, records the instance↔VCD map in
`<rundir>/<cell>_ase.cosim`, attaches BOTH to the viewer with the analog DB current, and says so
out loud if the co-simulation desynchronized. Regression-tested by `tests/headless/test_ase_cosim.tcl` — **201 checks, 60 sabotages injected and all 60 caught**. That number is the second half of the story: a five-lens adversarial review pass **after** the suite was green at 151/151 found **eight real defects** none of the checks could see (the Icarus arm's `sim_args` clobbered, a nested code block aborting the run, `multi` blind to hierarchy, a previous run's VCD served as this one's, a false "cannot be trusted" under `trace 0`, VCDs colliding between sessions, bridges in the netlist ignored, an unreadable raw emptying the registry) — and the fix for the last of those introduced a ninth, caught only by re-verifying: a re-attach of the same path served the previous run's DB, because `xschem raw read` switches rather than re-reads. E8 stays open (no `post_commands` slot); E9 and E10 are
independent ASE-L/migrator defects, filed and deliberately out of scope — see below.

**The measurement that shaped E2.** The netlister deduplicates `.model` cards on
**the first two tokens after `.model`, lowercased and whitespace-stripped**
(`model_name()`, `src/spice_netlist.c:143-169`; the reference card's key is `counterd_cosim`),
inserted `XINSERT` so the last writer wins. The reference netlist is therefore:

```
a1 [ CLK ] [ count_out3 count_out2 count_out1 count_out0 ] counter
**** begin user architecture code
.model counter d_cosim simulation="./counter.so" sim_args=["counter.vcd"] delay=0
**** end user architecture code
.end
```

One card, no instance name in it. **So "one VCD per d_cosim instance" is not reachable
without netlist surgery**: two instances of one cell share that card, hence one `.so` and one
`sim_args`. See E2.

| id | item | outcome |
|----|------|---------|
| E1 | ~~Detect.~~ | **DONE — netlist time, from the DECK, enriched by the DESIGN. Not a state declaration.** The deck's `.model <m> d_cosim` cards are what ngspice obeys and are the detector (`ase::cosim_scan_deck`); the design walk (`ase::cosim_design_scan`) says which `.v` built each `.so` and which schematic instance owns it. A state-dict declaration was rejected for the reason the spec already gives against a hand-maintained F2 map: it is a second copy of a fact the netlist states, wrong the moment a code block is added, removed or renamed. The `cosim` state key (E4) is therefore **policy only**. Two deviations from the row's stated sites, both forced: `library_inst_lcv` is used for the lib/cell labels but **cannot be the detector** — it accepts only the Cadence nested layout, so a flat library would silently have no code blocks; `cellview_sibling_path` (§B8) answers "has a verilog view" in both layouts. And the C verb `xschem get_inst_lcv` is unusable for enumeration at all: it requires exactly one SELECTED instance (`scheduler.c:5020-5027`). Enumeration is `xschem instance_list` → `{instname} {symref} {symtype}`; the symtype field is deliberately NOT used as a gate (it reads `missing` whenever the `.sym` did not load). |
| E2 | ~~Emit both artifacts.~~ | **DONE — one VCD per `.model` CARD, `<rundir>/<model>.vcd`, written into that card's `sim_args` by `render_deck`.** Two DIFFERENT code blocks can never collide (different model names → different files). The same block **instantiated twice** is the case the row asks about, and it has no honest per-instance answer: it is DETECTED — by counting **elaborated** instances, not netlist lines, because a `.subckt` body is emitted once however many times it is instantiated (so the spec's own canonical `tb → x1 (dig_top) → a1 (counter)` topology, with `dig_top` placed twice, is one `a1` line and two shims) — marked `multi 1`, EXCLUDED from the attach, and reported — because N shims opening one path interleave their writes and the file would not be data. Per-instance `.model` synthesis (which also means rewriting each instance line's trailing model token) is the documented upgrade path, not taken now. `simulation=` is left **untouched** on purpose: it is the user's choice of backend (`./counter.so` vs upstream's `ivlng` Icarus arm) and rewriting it would break the alternative. What goes into the card is a **bare, lower-cased basename**, not an absolute path, and that is **M18**, not taste: ngspice lower-cases the strings in a device card, so any capital letter anywhere in a run-directory path silently redirects the file — with NO error for `sim_args`. The basename is resolved against ngspice's cwd, which `ase::run_deck` already `cd`s to the rundir, exactly as the deck's own `simulation="./<cell>.so"` already relies on. `ase::cosim_map` keeps the ABSOLUTE path in `vcd` for Tcl (E3), which never goes near ngspice. The VCD is also **design-qualified** — `<cell>_<model>.vcd`, like `<cell>_ase.raw`/`.log`/`.cosim` — because the run directory defaults to `$USER_CONF_DIR/simulations` for every design, and a bare `<model>.vcd` let two sessions serve each other's digital data. And a card ASE will **not** trace gets no VCD at all and is left byte-identical: upstream's Icarus arm (`simulation="ivlng"`, whose `sim_args[0]` is the compiled vvp *design*, not a trace path), a `.so` ngspice opens from outside the run directory, a `+`-continued card, and `cosim trace 0`. **This was found only by running the reference TB end to end** — the run went green, the raw was perfect, and the VCD did not exist. 141 headless checks did not see it. |
| E3 | ~~Attach both.~~ | **DONE — `ase::attach_dbs`, and the ANALOG DB is current.** Measured: `xschem raw read` APPENDS to `extra_raw_arr[]` **and makes what it just read current** (`save.c:1281-1287`, `:1327-1333`), so reading raw-then-VCD leaves a VCD current and every existing consumer (`annotate_op`, `xschem raw value`, `add_trace`) would resolve analog names against it. The raw is read first (slot 0), then each VCD, then slot 0 is switched back explicitly. Partial runs: a missing/unreadable **raw** returns 0 and clears NOTHING (a stale-but-loaded DB beats an empty viewer — `attach_raw`'s existing policy); a missing or unreadable **VCD** is skipped with a notice and does not stop the analog attach, because an analog-only result is still a correct result. The registry is read **before** the outgoing DBs are dropped, so a raw that exists but does not parse (truncated, or missing the requested analysis because the run died after `op`) leaves the previous DB loaded — which is what the stated policy always claimed and the old clear-then-read order never delivered. One subtlety that order forces: `xschem raw read` does **not** re-read a path already in the registry (`save.c:1335-1339`, it just switches), and the raw artifact is a deterministic path a re-run overwrites in place, so the incoming path is cleared **specifically** first or every re-run would replot the previous run's data. `wviewer::attach_raw` grew a 4th argument that defaults to `{}`. `xschem raw_read` is NOT used (issue 0290: it clears the whole registry and bypasses the reader dispatch). |
| E4 | ~~State-dict fields.~~ | **DONE — ONE new key, `cosim`, and it is POLICY, not data.** `{build auto|always|never, trace 0|1, attach 0|1, bridges auto|0, vsupply <volts>}`; absent/empty means every default. It deliberately does **not** list the digital artifacts: those are derived (E1). **`version` stays 1.** Nothing reads it, `ase::state_load` merges over `state_default` so an old file gains the new key with its default automatically, and bumping the number would only invite an equality test somewhere. Asserted against a **committed frozen fixture**, `tests/headless/fixtures/ase_state_v1_pre_cosim.state` — it loads, keeps every old key (including an unknown one) byte-identical, gains `cosim {}`, and save→load→save is stable from then on. |
| E5 | ~~Deck emission for the digital side.~~ | **DONE — default `auto_bridge` `pre_set`s when the state configures none.** The migrator never *synthesized* those cards; it only carried them out of upstream's `code_shown` block (`ase_migrate.py:531-544` catches any `pre_*` line), so a **hand-built** mixed-signal state had none at all and ngspice bridged with built-in thresholds unrelated to the design's supply. `render_deck` now emits the adc/dac pair when the deck has ≥1 `d_cosim` card and no `auto_bridge_d_*` `pre_set` is already present **in the state OR in the netlist text**, at the supply from `cosim vsupply` → a `VDD` design variable → 1.8. The netlist half is not hypothetical: upstream's shipped testbench puts the pair in a `code_shown` block, so checking only the state appended ASE's defaults *after* the design's, and the later `pre_set` wins (measured, ngspice-46) — a 3.3 V design would have run with 1.8 V bridge thresholds and no message. A state that hand-writes them is left completely alone. Observation taps (§G3) are NOT part of this: they are a schematic-side technique for getting a signal into the *raw*, and the shim reaches internals directly now. |
| E6 | ~~Build orchestration.~~ | **DONE — `ase::cosim_build`, before the deck runs, and a failed build ABORTS the run.** Staleness is a **stamp file** `<so>.stamp` recording the source path, its mtime and size, the shim source's mtime and size, and the build flags — not an mtime compare. The reason is measured, not stylistic: `ase::rundir` defaults to `$USER_CONF_DIR/simulations` for **every** design, so two libraries that each hold a cell named `counter` build to the same `<rundir>/counter.so`; an mtime test would happily reuse the wrong one, and a `-V` shim edit would not invalidate anything. No content hash — Tcl 8.6 core has no digest and tcllib is not a dependency; path+mtime+size errs toward rebuilding, the safe direction. Always-rebuild was rejected on measurement: a warm no-op `build_cosim_so.sh` still costs **8.8 s** (cold 10.3 s). `build never` opts out; `build always` forces. Falling through to the previous `.so` on a build failure is exactly the "silently simulating last week's Verilog" outcome, so it throws instead. The `.so` is built to the **lower-cased** name too (M18): ngspice folds `simulation="./Counter.so"` and then reports `d_cosim failed to load simulation binary ./counter.so`. `Run` on an existing netlist never loads the design, so the `.v` for a model comes from the run-directory map artifact (see F2 below). **A block ASE cannot check never blocks the run.** `xschem instance_list` enumerates the current schematic only (`scheduler.c:6458-6472`) while the netlister hoists the `.model` card to the top of the deck (`spice_netlist.c:575-591`), so a code block one level down has no resolvable `.v` at all — a configuration that worked before §E and must keep working. ASE says what it cannot check and gets out of the way; if the `.so` really is missing, ngspice's own `d_cosim failed to load simulation binary` is what reports it, and E7 matches it. |
| E7 | ~~Report M9 honestly.~~ | **DONE — `ase::run_diagnostics`, called from `ase::run_done`.** The M9 diagnostic is **four separate NUL-terminated literals** in `/usr/local/lib/ngspice/digital.cm` — `XSPICE time is behind vtime:` then `XSPICE %.16g` then `Cosim  %.16g` — so a regexp spanning the value lines could never match; the header alone is the probe. Five `error`-severity strings are matched (desync, event-in-the-past ×2, port-count mismatch, `.so` load failure) and one `note` (`dump call ignored`). The note matters: the reference run emits **61** of them while producing a correct VCD — the patched shim clamps a non-monotonic dump and VerilatedVcd declines the duplicate — so flagging them as errors would make every healthy run red. Errors go to `ase::echo … error` (CIW **and** the action log) and into `ase::last_run`'s new `diagnostics` key; the ASE window also drops a banner into the log window. Note `run_cmd` folds stderr into stdout (`2>@1`), so a stderr-only diagnostic still reaches the log — the scan cannot be unfireable by construction. **Plus the failure the log cannot report**: a `cosim_novcd` check on the filesystem, because M18's silent redirect produces a clean exit, a perfect analog raw, and no digital data at all. That check exists because it happened. It is truthful only because two other things hold: the map promises a `vcd` **only** for a card this run will really trace (else `trace 0` would declare every healthy run untrustworthy and train the user past the real banner), and `run_deck` **deletes** the promised VCDs before launching — otherwise a survivor from the previous run both silences the check and gets attached to this run's analog raw. |
| E8 | **There is no `post_commands` slot.** | **STILL OPEN, and still not needed.** `eprvcd` emits the *boundary event* nodes, which the shim's internal VCD makes redundant for §F. Revisit only if the boundary VCD is ever wanted. |
| E9 | `render_deck` emits `print <expr>` per output | **OUT OF SCOPE for §E, filed as issue 0278.** Measured again here: the reference log is **49,922,360 bytes / 1,475,399 lines**, of which **1,402,702** are transient print rows — 95.07% of the file, and 99.99% is print-table scaffolding; only 129 lines carry anything else. It is a real ASE-L defect and it does dominate the reference run's wall clock. It is not fixed here because the fix changes `render_deck`'s output for **every** analog `dc`/`ac`/`tran` state in the tree, which is a different blast radius from §E's (whose deck changes are inert unless a `d_cosim` card is present). Cost of leaving it: the one reference run this section owes takes ~4 minutes. |
| E10 | Migration leaves junk outputs | **CONFIRMED and filed as issue 0295** (the migrator was not touched). Reproduced by executing the module: `'----' -> [('----', 1, None)]` with an **empty** warn list — silent, not merely lossy. `_row_outputs` (`ase_migrate.py:718-760`) has three drop paths and a dash row hits none: no whitespace (so not the RPN path), and `_RPN_NUM_RE` (`:679`) needs a digit after the leading `-`. |

**Where the F2 mapping lives — decided, and carried NOW.** `<rundir>/<cell>_ase.cosim`, a
run-directory artifact written at run time beside the `.raw` and the `.log`, one
`list`-quoted dict per line:

```
{model counter so ./counter.so sim_args {"..."} insts a1 cont 0 lib ngspice_verilog_cosim_ase
 cell counter vfile /…/counter/verilog/counter.v module counter
 vcd /…/simulations/counter.vcd scope TOP.counter multi 0}
```

Not the state file: it is derived data and would go stale on every schematic edit — the same
argument the spec's open decision 5 makes against a symbol attribute. Not the `Raw` struct: that
is a C change every consumer touches, `free_rawfile()` included, for zero benefit until a
renderer reads it. A deterministic run-directory path is exactly the contract `ase::raw_file`
and `ase::log_file` already use, and it is what lets `ase::last_vcdfiles` work in a fresh xschem
session that never netlisted. **`scope` is a HINT**: Verilator names the DUT trace scope after
the MODULE (measured — the reference `counter.vcd` declares `$scope module TOP` then
`$scope module counter`), but inlining can change it, so F2 must verify the scope against the
DB it actually loaded rather than trust the string.

**And the hint is weaker than "read out of the `.v`" — say what it really is.** `cosim_map`
writes `TOP.$module` unconditionally (`src/ase.tcl:1091`), and `$module` is the `.v`'s first
`module` line **only when the design walk or the previous map resolved a `.v`** for that entry.
When neither did — the walk is flat, so *every* code block below the current schematic is in
this case — `src/ase.tcl:1086` falls back `set module [dict get $e model]` and the recorded
hint becomes `TOP.<the .model card's name>`, a scope that need not exist in any VCD. Measured
on the canonical `tbh → x1 (dig_top) → a1 (dcell)` fixture with the card renamed to `cnt8`:
the entry comes out `model='cnt8' cell='' module='cnt8' vfile='' scope='TOP.cnt8'` while the
cell's `.v` declares `module dcell`. **An entry whose `vfile` is empty carries no `.v`
evidence at all, so its `scope` is not a hint but a guess**; F2 must go straight to the
derived path there. See issue 0307 and RULING 5c.

**Ownership was ruled in full on 2026-08-09 — see "Open decision 5, ruled" at the end of this
spec.** In its terms this artifact owns exactly one of the three facts (f2, *cell→file*), the
map is joined on the **cell** (`lib/cell`) and not on any instance path — it holds none today,
and one would not be unique anyway — and `scope` stays the hint it is called here.

Test: `tests/headless/test_ase_cosim.tcl`, pinned to the `--nogui` arm in `full_audit.sh`.
Groups: the deck scanner over 0/1/2 code blocks and the one-card-two-instances case, `.control`
isolation and `+`-continued cards; the `sim_args` rewrite including a path carrying `&` and `\`;
the map, its artifact and its round trip; the design walk over a fixture library with 0/1/2
d_cosim instances **and the deck↔design join through a real `xschem netlist`**; `render_deck`
end to end (rundir VCD path in, `simulation=` untouched, default bridges at the design's supply,
no bridges without a code block, hand-written bridges not doubled); build orchestration against a
stub build script (first build, up-to-date, edited source, **a foreign stamp**, missing `.so`,
`never`, `always`, a failing build that throws, the Icarus arm, no-source-no-`.so`); the attach
(3 DBs, analog current, each VCD readable, both partial-run directions, an unreadable VCD, the
`multi` exclusion); the real `wviewer::attach_raw` body with its Tk helpers stubbed; the frozen
old-state fixture; the diagnostics including `run_done` recording and echoing them; and a REF
block against the real reference cell that skips cleanly when `xschem_libraries_oa/` is absent.

**The reference run** (`ase::run` on `tb_counter_wrapper`, `tran 10p 2u`, into a scratch run directory whose path deliberately contains a capital letter): 214 s wall, exit 0. Produces `counter.so` + `counter.so.stamp` (built by E6 from `counter.v`), `tb_counter_wrapper_ase.raw` (20.8 MB, 200,386 pts), `counter.vcd` (1.7 MB) and `tb_counter_wrapper_ase.cosim`. Attaching leaves **2 DBs with the analog one current** — `xschem raw info` lists both — and the digital DB resolves `TOP.counter.phase`, `.tc`, `.carry`, `.next_count`, none of which exist anywhere in the raw. Diagnostics: one `note` (61 coalesced dumps), no errors. It runs into a SCRATCH rundir on purpose: `tests/headless/test_vcd_read.tcl` group A asserts exact point counts against `~/.xschem/simulations/counter.vcd`, a 500 ns probe artifact that a 2 µs run would overwrite.

### F — Signal Browser: Ctrl-Alt-V on a code block

| id | item | notes |
|----|------|-------|
| F1 | **The branch.** `ase::show_in_browser_for_current` (`src/ase.tcl:2427`) appends the selected instance name to the hierarchy segments and scopes the pane to that prefix. Add: if the selected instance's cell has a `verilog` view (§B + `library_inst_lcv`), scope to its **digital DB** instead of the analog one. | The `⚠` comments at `src/ase.tcl:2461-2472` are load-bearing — the selection and hierarchy must still be read in the DESIGN context, before any viewer raise. Preserve that ordering. |
| F2 | **Scope-path mapping — the hard one.** The schematic path is `x1.a1`. The VCD's internal path is whatever Verilator named the top module and its sub-scopes (`TOP.counter.cnt`, module-name based, subject to inlining). These two namespaces have **no inherent relationship**. **OWNERSHIP RULED 2026-08-09 — see "Open decision 5, ruled" at the end of this spec, which is F2's contract**: the mapping is three facts, not one (instance→cell is QUERY time, cell→VCD file is NETLIST time in `<rundir>/<cell>_ase.cosim`, file→scope is DERIVED from the loaded DB); the join key is the **cell** (`lib/cell`, with a four-rung ladder ending at the instance's own `model=` property), never the instance path; the schematic prefix is **dropped, not translated**; `scope` stays a hint, is not even eligible when the entry's `vfile` is empty, and the derived answer wins. A code block **below** the netlisted schematic reaches only rung 4 — issue 0307. **IMPLEMENTED 2026-08-09 (batch F item 4), see RULING 5f**: `ase::cosim_scope_for_instance <key> <instpath> ?<token>?` in `src/ase.tcl`, pinned by the **FS** group of `tests/headless/test_ase_cosim.tcl`. F1 still has to CALL it (F1 is not done). | Without this, the browser can show the digital signals but cannot tell you *whose* they are. This is the item most likely to be underestimated. |
| F3 | **Multi-DB display.** The all-DBs reader (`src/wave_viewer.tcl:2000-2130`) already enumerates every registry slot and labels them (`wviewer::db_label`). Confirm a digital DB labels sensibly and that per-DB grouping in the tree reads well when analog and digital scopes interleave. | Mostly free. Verify, don't assume. |
| F4 | **Classification.** The `class`-field and hide-internals rulings (`signal-browser-declass-rulings`, issue 0217) were settled for raw vector names. Digital signals are a new class of name — decide whether they get their own class or reuse an existing one. | Consistency with settled work. |
| F5 | **Empty-pane notice.** Selecting a code-block instance in a run that produced no digital output must say *why* (no VCD / shim not trace-enabled / no scope mapping), not show an empty pane. The `ase::echo … error` pattern at `src/ase.tcl:2531` is the model. | The failure mode users will actually hit. |

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
| G6 | ~~**`counter/verilog/counter.v` is referenced by absolute-ish lookup.**~~ **DONE via B8.** The symbol's display text is now `tcleval([read_data [cellview_sibling_path @symref verilog]])` — no library name in it, so the cell survives being copied to another library. (It briefly used `[xschem cellview_path ngspice_verilog_cosim_ase/counter verilog]`, which hardcoded the library.) | new, from the build |

### H — Tests

| id | item |
|----|------|
| H1 | ~~Headless VCD-reader unit tests~~ **DONE.** `tests/headless/test_vcd_read.tcl`, **187 checks**, pinned to the `--nogui` arm in `full_audit.sh`. Groups: the reference artifact (counts, step times, the two-scopes-one-id alias, the six internals that exist nowhere in the raw), `$timescale` (`1ps` / two-token `10 ns` / `1us` / `1s` / absent / unparsable), buses (widths, bit naming, little-endian `[0:2]`, short-vector left-extension, scalars not exploded), X/Z (never 0, distinct, both inside `get_bus_value()`'s undefined band, vector-wide propagation), the `$dumpvars` initial block + `$comment` isolation, missing `$enddefinitions`, truncation (mid-vector, mid-timestamp, mid-`$var`, mid-scalar), undeclared ids, `real` vars, a no-change file, scope nesting/`$upscope`, and registry coexistence with a spice `.raw` (both listed, switch back and forth, values intact) — including the real analog raw from the same run when present. **22 sabotages injected, all 22 caught.** Three initially survived and each exposed a genuinely missing fixture, which was then added: an undeclared id, a truncated scalar record, and a file whose MAX timestamp is not its LAST. An adversarial review pass then found three real defects that 164 green checks had not — a fixed-size bit-name buffer that collapsed every bit of a long-named bus onto one name, a composite that counted `h`/`l`/`w`/`-` bits as 0 while its own bit columns reported X, and a duplicated first time sample when `$dumpvars` precedes the first `#t` — all three fixed, each with its own sabotage. |
| H2 | Golden mixed-signal run end-to-end: build `.so`, run ngspice, assert both artifacts exist, assert a known internal signal's edge times. Guard on `verilator` being present — skip cleanly, never fail, on a machine without it. |
| H3 | ~~Time-base regression: an edge at a known SPICE time must land at the same time in both DBs (A6/D3).~~ **DONE.** `tests/headless/test_vcd_time_base.tcl`, **124 checks**, `--nogui` arm, 19 sabotages all caught. Fixtures are synthesized (an ASCII spice raw and a VCD encoding the SAME edge, ~15 lines of generator each, the `mkraw`/`mkvcd` idiom from `test_ase_cosim.tcl`) — **no simulator is run**. Groups TB (six units, both DBs in the registry at once), LD (the unit ladder, each rung exactly 1e3), NC (nine negative controls that ARE 1e3 wrong and must be rejected by the same gate), SE (seconds not ticks; multiplier forms), RW (the raw side is not rescaled either) and REF (the real §A6 pair, guarded, and it prints no banner `full_audit` would score as a file-wide SKIP). Tolerance and margins: see the D3 row. |
| H4 | ~~Scope-mapping test for F2~~ **DONE** — the **FS** group of `tests/headless/test_ase_cosim.tcl` (46 checks, 32 sabotages, every check red under at least one). `x1.a1` resolves to an absolute `(database, scope)` pair with three VCDs and the analog raw all loaded and the ANALOG one current, so the resolver has to reach a database that is not the current one (`FS30`-`FS33c`). The checks that carry it are the DIVERGING ones — a recorded hint naming a scope the loaded VCD does not declare (`FS34`-`FS37b`), a hint that differs only in CASE (`FS23`), and one where nothing matches at all (`FS38`/`FS39`) — because the agreeing case passes against an implementation that simply trusts the string. **Two `d_cosim` instances in one deck is the `multi` case**, produced for real through `xschem netlist` at `DS9`-`DS11` and refused by the resolver at `FS41`; a genuine two-CELL collision is `FS10` (rung 1 picks one where a bare cell key matches both) and `FS14` (a rung matching >1 refuses without falling through). Not covered: a really inlined VCD — no verilator on this machine — so the divergence fixtures hand-write the map entry. |
| H5 | ~~View-model tests~~ **DONE.** `tests/headless/test_verilog_view_model.tcl`, 109 checks: `view_type` / `view_handler` (including both open paths driven for real) / `library_new_view` / `library_new_cell` / the seed template / `lib_qualified_abs` / `cellview_sibling_path` / the Alt-2 candidate model, over `verilog` and `veriloga`, in both the nested and the flat layout, plus the measured repro against the reference cell. |
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

1. ~~**Signal-name source for a `verilog` view: parse the `.v`, or read the VCD header?**~~
   **SETTLED 2026-08-08: the VCD `$scope`/`$var` header**, as recommended — and the
   measurement made it more than a convenience. The reference file declares the same id
   code under two scopes; nothing in the `.v` predicts that, because it is a fact about
   what the simulator elaborated. Cost stands: names exist only after a run.
2. ~~**C2's materialization** — union-of-event-times vs. fixed grid.~~ **SETTLED: neither,
   exactly.** Columns come from times where a value actually *changes* (10 in the reference
   file, versus 50,088 `#t` headers), and each change is written as a two-column STEP
   because the renderer interpolates. See the §C table.
3. ~~**C6's `sim_type` token**~~ **SETTLED: `"vcd"`.** All 17 literal `sim_type` comparisons
   behave identically for `"vcd"` and `"tran"`, so `"tran"` buys nothing; and the type
   string is the reader dispatch key in `extra_rawfile()`, so `"tran"` would actively
   misroute the file. See the §C table.
4. ~~**C4's buses** — explode to bits at read time, or a native bus vector in `Raw`.~~
   **SETTLED: both.** Composite vector (the honest name and value) plus one column per bit
   (what the existing bus renderer can actually draw). See the §C table.
5. ~~**F2's mapping ownership** — netlist-time emission (authoritative, automatic) vs. a
   symbol attribute (explicit, hand-maintained, wrong the moment someone renames a module).~~
   **SETTLED 2026-08-09 (batch F item 3). See "Open decision 5, ruled" immediately below.**
6. ~~**B9** — does `veriloga` need any of §C/§D at all, or is recognition sufficient?~~
   **SETTLED 2026-08-08: recognition is sufficient.** Verilog-A is analog and its nodes reach the
   raw through OSDI, so none of the M1/M3/M6 barrier applies. §C/§D stay digital-only. Rationale
   and the asserting checks are in the §B table's B9 row.

### Open decision 5, ruled — who owns the instance↔VCD-scope mapping

**RULED 2026-08-09, batch F item 3, doc-only. Nothing in this section is implemented; it is
the contract item 4 (F2) is handed as input.** The decision as posed — "netlist-time emission
vs. a symbol attribute" — is a false pair, and the symbol attribute was never a live option
(it is the hand-maintained copy §E1 already rejected). The convenient answer, "netlist time
owns it because `<rundir>/<cell>_ase.cosim` already exists", is *most* of the truth and is
wrong in the one place it matters.

**THE RULING: the mapping is not one fact and has no single owner. It is THREE facts with
three different lifetimes, and each is owned by the only component that is still right when
the other two are stale.**

| # | the fact | when it changes | owner | where it lives today |
|---|----------|-----------------|-------|----------------------|
| f1 | *this instance is an instance of cell C, and C has a `verilog` view* | every schematic edit | **QUERY TIME**, read from the live design at the gesture | `library_inst_lcv` (`src/library_defs.tcl:505`) + `cellview_sibling_path` (`:420`) — the same pair `ase::cosim_design_scan` already uses (`src/ase.tcl:985-995`) |
| f2 | *cell/model C's digital data for THIS run is in file F — or there is none, and why* | every run | **NETLIST/RUN TIME**, the only moment the deck ngspice will obey is known | `<rundir>/<cell>_ase.cosim`, `ase::cosim_save_map` (`src/ase.tcl:1145`) writing `ase::cosim_map` (`:1046`) |
| f3 | *inside F, C's signals live under scope S* | whenever the digital simulator re-elaborates — **after** the netlist was written | **LOAD/QUERY TIME**, derived from the DB actually in the registry | nowhere; derivable from `wviewer::signal_list_all` (`src/wave_viewer.tcl:2084`) |

**RULING 5a — netlist time owns f2, and ONLY f2.** `<rundir>/<cell>_ase.cosim` is a record of
the **run**, not of the **design**. It is the right and only owner of "which file, written by
which `.model` card, and was it traced at all", because that fact is not recoverable from
anything else: the VCD does not say which card produced it, the schematic does not say whether
`cosim trace` was 0, and no reader can tell an interleaved `multi 1` file from a good one. It
is the **wrong** owner of f1 (it goes stale on the next edit) and it *cannot* own f3 even in
principle (§C's elaboration happens after it is written).

**RULING 5b — the join key is the CELL (`lib/cell`), never the instance path.** This is the
load-bearing consequence. Two independent facts force it:

* **the artifact holds no hierarchical instance path today.** `insts` holds the deck's leaf
  `a…` token as written on the instance line (`src/ase.tcl:887-892`), and the design walk that
  enriches it is the **current schematic only** — `xschem instance_list` iterates
  `xctx->instances` flat, one level, no hierarchy (`src/scheduler.c:6458-6472`). For this
  spec's own canonical topology `tb → x1 (dig_top) → a1 (counter)` the walk run on `tb` sees
  `x1` and never sees `a1` at all; that is exactly the gap §E6 already documents as "a block
  ASE cannot check never blocks the run".
* **and a path would not be a KEY even if it were recorded.** This, not impossibility, is the
  deciding reason — the hierarchy is in fact present in the deck text the scanner already
  reads (`x1 net1 net2 dig_top` … `.subckt dig_top` … `a1 [ … ] counter`), `cosim_scan_deck`
  already tracks the enclosing block in `curblk` (`src/ase.tcl:877-886`) and
  `cosim_subckt_counts` already walks the parent→child block graph (`src/ase.tcl:914-971`); it
  discards the `x`-instance *name* only because the regexp at `src/ase.tcl:925` leaves `\S*`
  outside its capture group. What cannot be fixed is uniqueness: one `.subckt` instantiated
  twice puts the **same** code block at `x1.a1` *and* `x2.a1`, so a single instance path
  cannot identify the entry. That is the very fact the `multi` flag already records.

Consequences:

* a schematic rename (`a1` → `a_cnt`, no re-netlist) does not invalidate anything, because
  nothing is keyed on the instance name. **The `a` prefix is not free**: ngspice's XSPICE
  syntax and the scanner's own instance regexp (`src/ase.tcl:887`) both require a code block
  to start with `a`/`A`. Measured — renaming `a1` to `u_cnt` still netlists (the netlister
  emits the instance name verbatim), but the line is then no longer an XSPICE code-model card
  and `cosim_scan_deck` returns `insts ''` for that entry, losing its design linkage and its
  `multi` protection with it: `a1` → `insts 'a1'`, `a_cnt` → `insts 'a_cnt'`, `u_cnt` →
  `insts ''`. Only the part after the `a` is free.
* **a code block BELOW the current schematic does NOT resolve on the cell key, and this ruling
  does not pretend otherwise.** Measured on that same canonical topology: `cosim_design_scan`
  on `tb` returns EMPTY, so the map entry comes out `cell='' lib='' vfile=''` and the cell rung
  is dead in exactly the topology F2 exists for. Nor is the `module` rung independent there —
  `src/ase.tcl:1086` falls back `module = model`, so `module` and `model` are the same string
  (the `.model` card's name) twice over. Filed as **issue 0307**; the ladder's rung 4 below is
  what carries the case until that issue is fixed, and it carries it on evidence rather than on
  the coincidence that the card was named after the module.

**The key ladder.** Let *f1* be the query-time answer for the selected instance: its
`{lib cell}` (`library_inst_lcv`), its `.v` (`cellview_sibling_path … verilog`), that `.v`'s
first module name (`ase::cosim_module_of`), and its own `model=` property
(`xschem getprop instance <name> model`). Rungs are tried in this order; each names both
operands, because a rung with only one is not a key:

| rung | the entry's… | compared against | tried when |
|---|---|---|---|
| 1 | `lib` + `cell` | f1's `lib`/`cell` | the entry's `lib` and `cell` are both non-empty |
| 2 | `cell` alone | f1's `cell` | the entry's `cell` is non-empty and its `lib` is empty (the `.v`-basename fallback at `src/ase.tcl:992`) |
| 3 | `module` | f1's module name, read from f1's own `.v` | the entry's `vfile` is **non-empty** — otherwise `module` is not a module name at all (`src/ase.tcl:1086`) |
| 4 | `model` | f1's `model=` **property** | always. The netlister emits that property verbatim as the instance line's last token, and `cosim_scan_deck` keys its entries on the matching `.model` card, so the two strings are the same string by construction — measured, `model='cnt8'` in the map for an instance whose property reads `cnt8`. Model names are unique per map (the scanner's `info` dict is keyed on them), so this rung matches at most one entry |

Semantics, and they are part of the ruling: comparisons are case-insensitive (SPICE folds, and
`cosim_map` already lower-cases its join keys). A rung matching **exactly one** entry wins. A
rung matching **more than one** refuses with `ambiguous` and does **not** fall through — a
multi-match is evidence of a real collision, not of a wrong key, and first-won there would plot
another cell's internals under this cell's name (the silent-wrong-answer class D2 and the §D1
refusal ruling both guard). A rung matching **none** falls through to the next; all four
missing is `nomap`.

Rung 1 is why `lib` is in the ladder at all: measured, two libraries each holding a cell named
`dcell` produce two entries that a bare `cell` key matches **both** (→ `ambiguous`, a refusal
on a question the artifact can actually answer) while `lib/cell` picks exactly one.

**RULING 5c — `scope` STAYS A HINT, and the DERIVED answer wins.** Item 4's brief is
unchanged, and this ruling is deliberately consistent with it rather than overriding it.

**What the hint actually is, which is less than §E's original wording claimed.** It is written
at `src/ase.tcl:1091` as `TOP.$module`, and `$module` is the `.v`'s first `module` line
(`ase::cosim_module_of`, `src/ase.tcl:1023-1030`) **only when the design walk — or the previous
map's sidecar, `src/ase.tcl:1080-1085` — supplied a `.v`**. When neither did, `src/ase.tcl:1086`
falls back `module = model` and the hint silently becomes `TOP.<the .model card's name>`; no
`.v` was opened at all. Measured on the renamed-card fixture: `scope='TOP.cnt8'` for a cell
whose `.v` declares `module dcell`, and `xschem raw index` against the reference
`counter.vcd` answers `-1` for anything of that shape. **So an empty `vfile` is the test:
`vfile eq {}` means the hint carries no `.v` evidence and MUST NOT be accepted as `how=hint` —
step 5 goes straight to the derived path.** That is not a special case bolted on; it is the
same rule as "the derived answer wins", applied where the hint has nothing behind it.

**Verification is a literal, CASE-SENSITIVE prefix test** against the names of the loaded DB:
`vcd_read.c` stores names verbatim, scopes joined with `.` (`src/vcd_read.c:188`, `:579-580`),
because Verilog is case-sensitive (§C, "Not fixed, by design"). **Do not verify through
`get_raw_index()`**, for two measured reasons — and note the hazard runs the *opposite* way to
the obvious guess:

* it folds the **query**, not the store: verbatim → `strtoupper` → `strtolower`
  (`src/save.c:2001-2020`). Against a mixed-case VCD name that ladder MISSES rather than
  over-accepts — measured on the reference file, `TOP.counter.clk` → 7 while
  `top.counter.clk`, `TOP.COUNTER.CLK` and `Top.Counter.Clk` all → `-1`. That is exactly the
  cost `src/vcd_read.c:139-146` documents in prose.
* it resolves **whole signal names**, not scope prefixes, so it could not perform step 5's test
  in the first place: measured, `xschem raw index TOP.counter` → `-1` although eight signals
  live under that scope.

**RULING 5d — the schematic prefix is DROPPED, not translated. The answer is an ABSOLUTE
`(database, scope)` pair.** Measured on the reference artifact `~/.xschem/simulations/counter.vcd`
(2026-08-09), the entire scope tree is:

```
$scope module TOP $end          <- clk, count  (the shim's port mirror)
 $scope module counter $end     <- clk count phase half prev next_count tc carry
```

There is no `x1` in it and there never can be: Verilator elaborates the module as its **own
top**, so the VCD's namespace begins where the schematic's ends. `x1.a1` therefore resolves to
`(counter.vcd, "TOP.counter")` — the prefix is consumed by f1 (it is how the leaf instance was
identified) and then discarded. Any implementation that concatenates the schematic path with a
VCD scope, or that tries to *translate* `x1` into a VCD scope name, is building a relationship
that does not exist.

**RULING 5e — refuse with a reason; never fall back to `TOP`, and never to "the current DB".**
`TOP` is the port mirror, and its signals are precisely the ones already bridged into the
analog raw — landing there would show the user the signals they could already see and call it
success. Ambiguity, a missing DB and an unverifiable scope all refuse, and each refusal names
which of f1/f2/f3 failed. That is F5's notice, and F5 is the *same* item as this ruling's
failure paths, not a separate cosmetic one.

**Why load-time alone was rejected.** Item 4 must walk the DB's scope tree anyway to verify the
hint, so "derive it all, record nothing" is the tempting simplification. It cannot work,
because a scope tree cannot answer **which database**. Walking scopes yields module-name
matches, and two cells whose Verilog modules share a name — or one cell instantiated as two
code blocks — are indistinguishable by it; the reference file goes further and declares
`clk`/`count` under **both** `TOP` and `TOP.counter` *with the same id code* (§C's
re-measurement, re-confirmed above), so even inside one file a scope tree does not by itself
say which scope is the module. It also cannot know a `multi 1` file is interleaved garbage
rather than data (that fact exists only in the deck, `src/ase.tcl:1092-1098`), and it needs the
module name to match against, which comes from the `.v`, which needs the design — and
`ase::run_existing` never loads it (`src/ase.tcl:1049-1056`).

**Why query-time alone was rejected.** It is always current with the schematic, which is
exactly why it owns f1. It has no access to the run's facts: nothing in the schematic says
which VCD this run wrote, whether tracing was on, or whether the entry was excluded. It would
have to **guess** the artifact path — and E2's naming is
`<cell>_<model>.vcd` after `ase::cosim_safe_name` folding plus a `_<n>` collision suffix
(`src/ase.tcl:1105-1117`), a guess that is wrong the moment two model names fold together or
`cosim trace 0` is set.

**The deciding question, answered per failure mode.** This is the test the ruling was built
against: which owner is still correct when the two sides disagree?

| the two sides disagree because… | netlist-time-only | load-time-only | query-time-only | **the split rule** |
|---|---|---|---|---|
| an instance was **renamed** and nothing re-netlisted | wrong if keyed on the instance path; **correct when keyed on the cell** (5b) | n/a — cannot pick a DB | correct | **correct** (f1 live, f2 keyed on the cell) |
| the cell was **re-netlisted** / re-run | correct — the artifact and the VCD are written by the same `ase::run`, so they cannot disagree with each other | correct | wrong — guesses the old path | **correct** |
| the module was **inlined away** by the digital simulator | **wrong, unfixably**: the scope is decided after the artifact is written | correct | wrong | **correct** (f3 derived, 5c) |
| the **rundir is stale** (previous run's VCD survives) | correct *by construction*: `ase::cosim_clear_artifacts` deletes the promised VCDs before the run (`src/ase.tcl:1131-1139`) and `ase::last_vcdfiles` gates on `file isfile` (`:1518-1529`) | may attach yesterday's file | wrong | **correct** |
| the `.v` was edited but not re-run | reports the file that exists; the data is genuinely last week's | same | same | **nobody wins** — out of scope for F2; E6's `.so.stamp` is what catches it at *run* time |
| the code block is **below** the netlisted schematic (`tb → x1 → a1`) | `cell`/`lib`/`vfile` come out EMPTY, so rungs 1-3 are all dead and the recorded `scope` is a card name, not a module name — **measured** | correct, if the right DB is already known | correct | **rung 4 only** (`model` vs the instance's own `model=` property), and the scope must be DERIVED. A documented limit, not a solved case: issue **0307** |

**The contract item 4 implements.** One Tcl-only resolver in `src/ase.tcl` (it needs the
session state and the map; `src/wave_viewer.tcl` gets the answer, not the derivation). No C, no
new field in `Raw` — the §E argument stands verbatim: a `Raw` change touches every consumer,
`free_rawfile()` included, for zero benefit until a renderer reads it.

```
ase::cosim_scope_for_instance <key> <instpath>  ->
    {ok <vcdpath> <scope> <how>}          how = hint|derived
    {none <code> <human sentence>}        code = nodigital|nomap|multi|notraced|
                                                 notloaded|noscope|ambiguous
```

Steps, in this order — **the order is part of the ruling**:

1. **f1, in the DESIGN context, before any viewer raise.** Take the last segment of the path,
   resolve it to `{lib cell}`, ask for a `verilog` view, read that `.v`'s first module name,
   and read the instance's own `model=` property — **all four in this one design-context read**,
   because rung 4 needs the property and nothing above the raise will be readable after it. No
   `verilog` view → `nodigital`. The ordering is F1's existing ⚠ (`src/ase.tcl:2461-2472`): a
   read placed after the raise answers about the viewer's own untitled buffer and degrades
   silently to "no selection".
2. **f2, by the 5b key ladder** over `ase::cosim_load_map`, rungs 1→4, each rung named with
   both its operands. All four rungs matching nothing → `nomap`; any rung matching >1 →
   `ambiguous`, without falling through.
3. **The entry's own refusals, BEFORE anything touches the registry**: `multi 1` → `multi`
   (`ase::last_vcdfiles` already excludes it, so its VCD is *deliberately* not loaded and a
   `notloaded` answer here would name the wrong cause); empty `vcd` → `notraced` (Icarus arm,
   a `.so` outside the rundir, a `+`-continued card, or `cosim trace 0`). Note the trap:
   `cosim_map` sets `scope` unconditionally, including on entries whose `vcd` is empty
   (`src/ase.tcl:1091` vs `:1105`), so a scope hint exists for files that will never exist —
   check `vcd` first. That kills one of the hint's two lies; the other (a hint written with no
   `.v` behind it) is killed by the `vfile` test in step 5, not here.
4. **The DB must be in the registry**, matched on `path` against `wviewer::signal_list_all`'s
   inventory. Absent → `notloaded`.
5. **f3, derived and verified** against that DB's `names`. **The hint is eligible only when the
   entry's `vfile` is non-empty** (5c: an empty `vfile` means no `.v` was ever read and the
   string is the `.model` card's name). Eligible → accept it iff ≥1 name starts with
   `<scope>.`, literally and case-sensitively. Otherwise derive: take the deepest scope whose
   leaf segment equals **f1's** module name — f1's, read from the live `.v`, not the entry's,
   which in the buried case is a card name; else, if exactly one non-root scope exists, take
   it; else `noscope`, naming what was found. Report `hint` or `derived` in `how` so a test can
   tell the two paths apart — a check that only asserts the final scope passes vacuously when
   the hint happens to be right, which for the reference cell it always is.

**What does NOT change.** The `.cosim` artifact's format, its fields and its producer are
untouched by this ruling — it already records exactly f2 and it already calls `scope` a hint.
No existing check changes expectation: `DS13-scope-hint`, `REF10-map-scope` and
`REF12-scope-hint-matches-the-real-vcd` (`tests/headless/test_ase_cosim.tcl:466`, `:1100`,
`:1106`) all assert the *hint's* production and stay correct. There is today **no consumer of
the `scope` field anywhere in the tree** — the only reference outside the tests is the producer
line itself — so nothing can contradict the ruling and nothing has to be restated to
accommodate it.

### RULING 5f — the four things item 4 had to rule to build it (batch F item 4, IMPLEMENTED)

**Implemented 2026-08-09** as `ase::cosim_scope_for_instance` / `ase::cosim_scope_for_state`
plus `ase::cosim_f1`, `ase::cosim_map_match`, `ase::cosim_scopes_of`, `ase::cosim_scope_derive`
and `ase::cosim_db_inventory` in `src/ase.tcl`; pinned by the **FS** group of
`tests/headless/test_ase_cosim.tcl` (63 checks — 46 as first written, 17 added by the review
round below; every check red under ≥1 sabotage). The five steps above were built exactly as
ruled. Six things they left open, ruled here by the implementing crew, with the evidence that
drove each:

* **5f-1 — the disagreement is REPORTED, and the ok tuple grows a fifth slot rather than `how` a
  third value.** `{ok <vcdpath> <scope> <how> <note>}`. `<note>` is empty on a clean answer and,
  on a `derived` answer that OVERRODE an eligible hint, says which hint was discarded and what
  replaced it. Extending `how` to a third token (`derived-hint-rejected`) was rejected as the
  more dangerous shape: 5c's own words are "report `hint` or `derived`", so a consumer written
  against that sentence would compare `$how eq {derived}` and silently stop seeing the very case
  this ruling exists to surface, whereas an extra list element is invisible to every `lindex`
  already written. The note ALSO reaches the user directly, through `ase::echo … note` at
  resolve time — "the DB wins" must not be a fact only a caller who remembers to render `<note>`
  can see (pinned by `FS46`, and by `FS47`, which fails if an *agreeing* resolve says anything).
* **5f-2 — the third parameter is a VIEWER TOKEN, and it is what lets step 1 and step 4 read
  different contexts.** `ase::cosim_scope_for_instance <key> <instpath> ?<token>?`. Step 1 must
  run in the DESIGN context (F1's ⚠); step 4 must read the registry of the window that holds the
  databases. With a token, step 4 delegates to `wviewer::signal_list_all`, which does its own
  `enter_ctx`/`leave_ctx` — so the resolver is called from the design context and still sees the
  viewer's registry, and nothing has to be re-read after a raise. With no token (headless, or a
  resolve before any viewer exists) `ase::cosim_db_inventory` reads the current context's
  registry directly, with the same switch-and-restore shape and the same unconditional restore
  outside every per-DB failure path (`FS33c`, `FS49`: the user's current DB never moves).
* **5f-3 — NO SCOPE MATCHES: the answer is `{none noscope <sentence>}`, and the sentence is F5's
  notice.** It names (a) the module that was looked for, (b) the scopes that WERE found —
  literally `scopes found: TOP, TOP.other`, or `the database declares no scope at all` — and
  (c) the database's basename. It never degrades to an `ok` on the root scope: 5e's ban on `TOP`
  is a ban on *choosing a scope for want of a better one*, so the module rung MAY legitimately
  select a root scope when that root IS f1's module (Verilator elaborating the module as its own
  top — that is evidence), while the "exactly one non-root scope" rung may not. Two scopes with
  the same leaf name at the same depth is `noscope` too, naming the tie: 5e refuses ambiguity
  rather than guessing, and picking either would plot half a design under the other half's name.
  F5 renders this sentence rather than composing its own, so the two cannot drift.
* **5f-4 — `nodigital` covers two different f1 failures**, each with its own sentence: the path's
  last segment names no instance of the schematic currently open, and the instance's cell has no
  `verilog` view. Both are "f1 could not identify a digital cell", both are the user's cue to
  check what they selected, and inventing a seventh code for the first would have made F5 render
  a distinction it cannot act on.
* **5f-5 (ruled in the review round) — an EMPTY answer from `wviewer::signal_list_all` is not
  "the viewer has no databases", and `cosim_db_inventory` falls through to the direct registry
  instead of believing it.** That proc returns `{}` for three different situations: the token is
  not in `wviewer::windows` (stale — and a token goes stale exactly during viewer teardown, which
  is when a browser refresh fires), `enter_ctx` refused the ticket (its own comment documents the
  window-alloc interval where `current_win_path` is transiently empty), and the viewer genuinely
  holds nothing. Only the third is an answer, and it is indistinguishable from the other two at
  the call site. Taking `{}` as authoritative made the resolver answer `{none notloaded "… run
  the simulation, or re-attach its results"}` about a database that was loaded and readable that
  instant — reproduced with a bogus token against a live registry. The fall-through is safe in
  the honest case: with nothing loaded the direct path reports `{}` by itself. Pinned by `FS50`
  (an unknown token) and `FS51` (a `signal_list_all` that exists and returns `{}` without
  throwing, i.e. the refused ticket a `catch` cannot see).
* **5f-6 (ruled in the review round) — `note` is a CIW tag, and `src/ciw.tcl` now configures it.**
  5f-1 asserts the disagreement is *visible*; `ase::echo … note` hands the tag straight to the
  CIW text widget, and an undefined Tk tag is legal and styles nothing, so before this the notice
  rendered identically to any ordinary result line and 5f-1 was true of the return value only.
  `.ciw.l.t tag configure note -foreground {dark orange}` sits beside `input`/`result`/`error`;
  it is deliberately NOT `error`, because a stale hint that the resolver *recovered from* is not
  a failure and must not train the user past the red lines that are. Pinned by `FS47b`, a literal
  source pin (headless has no Tk widget to interrogate). **The colour itself is the one pixel in
  this item — a human should look at it when F5 lands and renders 5f-3's sentence.**

**What this ruling does NOT solve, stated so item 4 does not discover it as a surprise.** A
code block below the netlisted schematic reaches the browser on rung 4 alone, with a derived
scope and no `.v` linkage — issue **0307**, whose fix (a hierarchical design walk, so `cell`,
`lib` and `vfile` are populated for buried blocks) would light rungs 1-3 up and make the
`scope` hint honest there. That fix is *additive to* this ruling, not a revision of it: the key
is still the cell, the hint is still verified, and rung 4 stays as the belt to those braces.

## Dependency order

```
A2,A3,A4,A6  ──►  digital data exists on disk          [DONE]
      │
B1..B9       ──►  xschem knows the cell has a verilog view   [DONE]
      │
      ├──► C1..C7  ──►  a VCD is a Raw DB in the registry    [DONE]
      │        │
      │        └──► D1..D5  ──►  both DBs plot on one time axis
      │                 │
      └──► E1..E7  ─────┤  ASE-L produces and attaches both   [DONE]
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
