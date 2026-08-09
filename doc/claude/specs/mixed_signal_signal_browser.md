# Mixed-signal debug — digital internals in the Signal Browser

Status: §A (simulation), §B (view model) and §C (VCD → Raw DB) DONE; §D–§F open
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
| G6 | ~~**`counter/verilog/counter.v` is referenced by absolute-ish lookup.**~~ **DONE via B8.** The symbol's display text is now `tcleval([read_data [cellview_sibling_path @symref verilog]])` — no library name in it, so the cell survives being copied to another library. (It briefly used `[xschem cellview_path ngspice_verilog_cosim_ase/counter verilog]`, which hardcoded the library.) | new, from the build |

### H — Tests

| id | item |
|----|------|
| H1 | ~~Headless VCD-reader unit tests~~ **DONE.** `tests/headless/test_vcd_read.tcl`, **187 checks**, pinned to the `--nogui` arm in `full_audit.sh`. Groups: the reference artifact (counts, step times, the two-scopes-one-id alias, the six internals that exist nowhere in the raw), `$timescale` (`1ps` / two-token `10 ns` / `1us` / `1s` / absent / unparsable), buses (widths, bit naming, little-endian `[0:2]`, short-vector left-extension, scalars not exploded), X/Z (never 0, distinct, both inside `get_bus_value()`'s undefined band, vector-wide propagation), the `$dumpvars` initial block + `$comment` isolation, missing `$enddefinitions`, truncation (mid-vector, mid-timestamp, mid-`$var`, mid-scalar), undeclared ids, `real` vars, a no-change file, scope nesting/`$upscope`, and registry coexistence with a spice `.raw` (both listed, switch back and forth, values intact) — including the real analog raw from the same run when present. **22 sabotages injected, all 22 caught.** Three initially survived and each exposed a genuinely missing fixture, which was then added: an undeclared id, a truncated scalar record, and a file whose MAX timestamp is not its LAST. An adversarial review pass then found three real defects that 164 green checks had not — a fixed-size bit-name buffer that collapsed every bit of a long-named bus onto one name, a composite that counted `h`/`l`/`w`/`-` bits as 0 while its own bit columns reported X, and a duplicated first time sample when `$dumpvars` precedes the first `#t` — all three fixed, each with its own sabotage. |
| H2 | Golden mixed-signal run end-to-end: build `.so`, run ngspice, assert both artifacts exist, assert a known internal signal's edge times. Guard on `verilator` being present — skip cleanly, never fail, on a machine without it. |
| H3 | Time-base regression: an edge at a known SPICE time must land at the same time in both DBs (A6/D3). |
| H4 | Scope-mapping test for F2: `x1.a1` resolves to the right VCD scope with two `d_cosim` instances in one deck (the case A5 also guards). |
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
5. **F2's mapping ownership** — netlist-time emission (authoritative, automatic) vs. a
   symbol attribute (explicit, hand-maintained, wrong the moment someone renames a module).
6. ~~**B9** — does `veriloga` need any of §C/§D at all, or is recognition sufficient?~~
   **SETTLED 2026-08-08: recognition is sufficient.** Verilog-A is analog and its nodes reach the
   raw through OSDI, so none of the M1/M3/M6 barrier applies. §C/§D stay digital-only. Rationale
   and the asserting checks are in the §B table's B9 row.

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
