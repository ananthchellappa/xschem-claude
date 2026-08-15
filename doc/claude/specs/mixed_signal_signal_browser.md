# Mixed-signal debug — digital internals in the Signal Browser

Status: §A (simulation), §B (view model), §C (VCD → Raw DB) and §E (ASE-L) DONE; §D open (D1/D3 done); §F: F1/F2/F5 DONE, F3/F4 open
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

All measured on this machine, ngspice-46 (build 2026-08-02), 2026-08-08 unless a row
says otherwise. These are the facts that shape every decision below. Where a row was
later refined against source or re-measured, the row carries the newer date and points
at the section holding the detail — M15 and M18 both did (batch F item 12, 2026-08-10).

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
| M15 | **`verilator_shim.cpp` has a use-after-free.** `Cosim_setup()` holds the `VerilatedContext` in a function-local `const std::unique_ptr` while the model keeps a raw pointer; the `--timing` `step()` then calls `topp->contextp()` on freed memory. **It is NOT latent in the build we ship, and an earlier version of this row said it was.** The `--timing` `step()` is indeed never compiled (we never pass `-t`), but that is only the *first* of two ways the freed context is reached: the second is `Verilated::threadContextp()`, which the *generated* model dereferences inside `topp->eval()` in every build whenever the Verilog uses `$time`, `$display` with `%t`, `$finish`, `$stop` or `$fatal`. The patch is kept, is correct, and is load-bearing today. See §A part 2. | source read; patched in `tools/cosim/src/`. The old "inert" reading came from a real but NARROW measurement — with the `release()` neutered the *reference* run gave a byte-identical VCD and a clean valgrind, because `counter.v` uses none of those constructs. Re-measured 2026-08-10 under AddressSanitizer with the same neutering and no `-t`: a `$display("t=%t", $time)` counter gives heap-use-after-free in `VerilatedContext::time()` under `Vlng::eval_step()`; the reference `counter.v` in the identical harness stays clean |
| M16 | **`pinfo->cleanup` is not reliably reached** in ngspice-46 batch mode. The first trace build ended with a half-written `#197` where `#1975796` belonged. Periodic `flush()` + `atexit()` fixes it. | measured, then re-measured clean: `truncated: False`, span `0..2000000 ps` |
| M17 | **A trace dump happens on every SPICE timestep, not every signal change.** The reference run produced **200,344 VCD timestamps carrying ~40 real transitions** — one `#t` line per ngspice step. VerilatedVcd dedups *values* but still emits the time header. | `xcheck.py`: 200,344 timestamps vs 10 LSB edges. **Directly sizes decision C2.** |
| M18 | **ngspice lower-cases the strings inside a device card**, not just in script-file mode (M14). A path with any upper case in it is opened under a different name, and for `sim_args` **there is no error at all** — the run exits 0, the analog raw is perfect, the VCD simply never exists. | Measured 2026-08-08, ngspice-46: `sim_args=["/tmp/vcdprobe/Ecap/x.vcd"]` wrote nothing; pre-creating `/tmp/vcdprobe/ecap/` made the file appear **there**. On a card that ALSO carried `sim_args=["…"]` — i.e. four quotes on the physical line — `simulation="./CounterUP.so"` → `d_cosim failed to load simulation binary ./counterup.so.` (that one at least reports). **State that condition whenever you quote this example**: a card carrying *only* `simulation="./CounterUP.so"` has exactly two quotes and ngspice **keeps** its case (re-measured 2026-08-10), so the unqualified form asserts the opposite of the rule below. **Forces E2 to write a bare, lower-cased basename** resolved against the run directory ngspice is already `cd`-ed into. Found only by running §E end to end — 141 green headless checks did not see it. **Mechanism now recorded** in §A "M18 mechanically": `keep_case_of_cider_param()` (ngspice `src/frontend/inpcom.c:223-254` at `db9d99843`) preserves case only when the physical line carries **exactly two** double quotes; any other count, four included, folds the whole line. Adding `sim_args` is therefore what destroys the case of `simulation=`. |

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
| A2 | ~~Trace-enabled cosim shim~~ | **DONE.** `tools/cosim/src/verilator_shim.cpp`, hunks marked `XSCHEM PATCH`: trace object + `traceEverOn` + depth 99 + `open()` from `sim_args`; `dump()` in **both** `step()` variants (the `--timing` one dumps at each Verilog event time `next * tick`, not at the SPICE target, or several internal events inside one timestep collapse); a monotonicity clamp (M16/M9); `flush()`+`atexit()` (M16); the context-lifetime fix (M15). **Note which half of that is live, and do not over-read it:** we never build with `-t`, so the `--timing` `step()` and its event-time `dump()` are not compiled at all in a shipped `.so`. The **M15 fix itself IS compiled** — `VerilatedContext *ctx = contextp.release();` sits at `verilator_shim.cpp:350`, between the `#endif` at `:295` and the `#if VM_TRACE` at `:357`, carrying no preprocessor guard of any kind — and it is load-bearing in that build too (§A part 2). What `-t` removes is one of its two consumers, not the fix. See §A "The shipped cosim build, precisely". |
| A3 | ~~Fix the link~~ | **DONE**, in `tools/cosim/build_cosim_so.sh` — adds `verilated_vcd_c.o` when present. |
| A4 | ~~Package the override~~ | **DONE, but not the way this spec first proposed.** The `sourcepath` trick is moot: `vlnggen` cannot run at all on ngspice-46 (M14). `tools/cosim/build_cosim_so.sh` replaces it outright, doing the same four steps in `sh`. `-V` selects the patched in-repo shim; without `-V` the system copy is used, so a stale vendored tree cannot silently affect a non-trace build. `NGSPICE_COSIM_SRC` overrides. See `tools/cosim/README.md`. |
| A5 | ~~VCD path as a model parameter~~ | **DONE.** `.model counter d_cosim simulation="./counter.so" sim_args=["counter.vcd"] delay=0`; the shim reads `pinfo->sim_argv[0]`, defaulting to `cosim.vcd`. |
| A6 | ~~Pin the time-base contract~~ | **DONE, measured, and now REGRESSION-TESTED (H3/D3).** `tick = pow(10, contextp->timeprecision())`; `` `timescale 1ps/1ps `` → VCD `$timescale 1ps`, span `0..2000000 ps` for a `tran 10p 2u`. Cross-check: counter LSB first rising edge at **50.0120 ns (VCD)** vs **50.0219 ns (raw)** — the ~10 ps offset is exactly the `dac_bridge t_rise=1e-11` plus the 0.9 V analog threshold crossing, i.e. physical, not a units error. Re-measured 2026-08-09 against the artifacts still on disk and pinned to 0.1 ps by `tests/headless/test_vcd_time_base.tcl` group REF: 50.0120 ns vs **50.021883 ns**, skew **9.883 ps**. One thing the original figure left implicit and the test now states: the raw number is the first SAMPLE at or above 0.9 V, not an interpolated crossing — linearly interpolating the same crossing gives 50.01750 ns and a 5.5 ps skew. Both readings are well inside the test's tolerance, so the choice of rule is not what the regression is sensitive to. |
| A9 | **Throttle the trace dump** (new, from M17). 200,344 timestamps for ~40 transitions is ~1.7 MB per 2 µs and sets the floor for any reader's memory. Only dump when something changed, or subsample. | Not blocking; changes C2's arithmetic by ~4 orders of magnitude. |
| A7 | *(optional, alternative)* Build Icarus from source with shared `libvvp` to unlock the `ivlng` route and plain `$dumpvars`. | M12. Only if a `.v` feature Verilator lacks is needed. |
| A8 | *(optional, alternative)* `d_process` route — digital block as any external executable over pipes. Zero Verilog toolchain. | Worth a note in the spec; not on the critical path. |

#### The shipped cosim build, precisely (batch F item 12, 2026-08-10)

Two facts that the rest of §A and §E lean on without ever having stated them.
Both are corrections: the first replaces a rationale in the source that was
simply not true of the code it sat next to, the second records a property of the
product that had only ever been a property of one run.

##### 1. `-t` is never passed on any path. `-V` is passed unless `cosim trace 0`.

`ase::cosim_build` builds the command line in three statements
(`src/ase.tcl:1357-1359`):

```tcl
set cmd [list $script]
if {$trace} { lappend cmd -V }
lappend cmd -o $rd $vfile
```

Those two flags are **not** equally unconditional, and the easy mistake — made
once already in this document — is to read the default as a universal.

**`-t`: universal, and this is the item's actual finding.** There is no branch
anywhere that appends it, and `ase::cosim_build` is the only caller of
`build_cosim_so.sh` in the tree. In `build_cosim_so.sh`, `-t` is the *only*
thing that sets `-DWITH_TIMING` (`build_cosim_so.sh:42`, `:73`). So **no**
library ASE produces is a timing build:

- `WITH_TIMING` is never defined → `verilator_shim.cpp` compiles the non-timing
  `step()` (`verilator_shim.cpp:194-210`, dumping at `pinfo->vtime`) and sets
  `pinfo->method = After_input` (`:389`);
- the `WITH_TIMING` `step()` (`:229-277`) and its event-time `dump()` are **not
  compiled at all**. They are maintained for a `-t` build that nothing in the
  product currently makes.

**`-V`: conditional.** `$trace` is 1 unless the state says literally `0`
(`src/ase.tcl:1315`), so the default library is trace-enabled — but `cosim trace
0` is a supported policy this document documents elsewhere (E2, E4, E7), not a
hypothetical, and on that path the `.so` is a different animal entirely.
`build_cosim_so.sh` uses `-V` for **two** things, and the second one is easy to
miss: it gates `--trace` (`:74`), and it selects the shim source (`:49-53`) —

```sh
if [ "$trace" = 1 ]; then SHIMDIR=${NGSPICE_COSIM_SRC:-$here/src}
else                      SHIMDIR=${NGSPICE_COSIM_SRC:-/usr/local/share/ngspice/scripts/src}
fi
```

So a `cosim trace 0` library has `VM_TRACE` undefined **and is built from the
stock upstream shim**, which carries none of the `XSCHEM PATCH` hunks at all —
verified: `grep -c 'XSCHEM PATCH' /usr/local/share/ngspice/scripts/src/verilator_shim.cpp`
gives `0`, and its `Cosim_setup` still has the unpatched
`const std::unique_ptr<VerilatedContext> contextp` at `:205`. That includes the
M15 `release()` whose retention part 2 argues for: in a `trace 0` build it does
not exist, and the upstream use-after-free is present as upstream shipped it.

This is not a new observation, which is the point — the tree already *tests* the
switch and the first version of this subsection contradicted its own suite.
`ase::cosim_shim_dir` (`src/ase.tcl:1267-1274`) returns the in-repo `src` for
trace and `/usr/local/share/ngspice/scripts/src` otherwise, pinned by
`tests/headless/test_ase_cosim.tcl` **BD19** and **BD20**.

The `-t` choice is a decision, not an accident, and it is the right one for now:
the reference design has no Verilog time delays, and `--timing` drags in
`verilated_timing.o` and a second scheduling model for no benefit. It is
recorded here because `After_input` is exactly why the monotonicity clamp is
mandatory — ngspice calls `step()` more than once at the same `vtime`.

##### 2. M15's fix is load-bearing in every build — and the trace setup was never the reason

Two separate corrections live here, and the second one corrects the first
attempt at this subsection. Keep them apart.

**(i) The old reason was wrong.** The comment at the `release()` in
`Cosim_setup()` used to say the patch was needed because "the trace setup needs
the context too". That is false, and it is checkable in a minute: in
`tools/cosim/src/verilator_shim.cpp` the released pointer `ctx` is used at
exactly two places — the `ng_trace_tick` assignment and the non-`VM_TRACE`
`(void)` cast — and both are inside `Cosim_setup()`, above its closing brace
(`:282-391`), where the `unique_ptr` is still alive. `contextp.get()` would have
served the tracer identically.

**(ii) But "therefore inert" does not follow, and it is the more dangerous
error.** Grepping for the identifier `ctx` answers a narrower question than *who
reaches the context object*. Three aliases hold the same object and none of them
contains the token `ctx`:

| alias | where | live after `Cosim_setup` returns? |
|---|---|---|
| `topp->contextp()` | the raw pointer the model kept | **yes** — the `WITH_TIMING` `step()` calls `timeprecision()`/`time()` through it. Compiled only with `-t`. This is M15 as originally described. |
| `VerilatedTrace::m_contextp` | `verilated_trace.h:285`, assigned in `addModel()` (`verilated_trace_imp.h:659`) | dereferenced only under `parallel()` (`:486`), which a single-thread build never sets — a dead end here. |
| `Verilated::threadContextp()` | a **thread-local**, set by the `VerilatedContext` *constructor* (`verilated.cpp:2421`) and **never cleared by its destructor** (`:2434`) | **yes, in every build, `-t` or not** — see below. |

The third row is what breaks "inert". The *generated* model dereferences that
thread-local inside `topp->eval()` whenever the user's Verilog contains `$time`,
`$display` with `%t`, `$finish`, `$stop` or `$fatal`: `VL_TIME_Q()` expands
literally to `Verilated::threadContextp()->time()`
(`verilated_funcs.h:302`, and `VL_TIME_UNITED_Q` at `:308` wraps it), and
`vl_finish()` calls `gotFinish()` on the same pointer (`verilated.cpp:113`).
Since the destructor only stamps `m_magic` and leaves the thread-local pointing
at freed memory, `eval()` reads a dead object.

**Measured 2026-08-10** (Verilator 5.020, ASan, no simulator involved). A
harness reproducing `Cosim_setup` in the *shipped* configuration — `VM_TRACE`
on, `WITH_TIMING` off — with the `release()` **neutered**, driving `topp->eval()`
40 times:

| Verilog driven | result |
|---|---|
| a counter whose `always` block does `$display("t=%t", $time)` and `$finish` | `ERROR: AddressSanitizer: heap-use-after-free`, READ of size 8 in `VerilatedContext::time()` ← `Vlng___024root___nba_sequent__TOP__0` ← `Vlng___024root___eval` ← `Vlng::eval_step()`; freed at the end of the `Cosim_setup` analogue |
| `xschem_library/ngspice_verilog_cosim/counter.v` — the reference design, identical harness | exits 0, **ASan-clean** |

That second row is the whole trap, and it explains the earlier evidence rather
than contradicting it. The original "byte-identical VCD, clean valgrind"
measurement is real; it was simply taken on `counter.v`, whose only `$display`
has no `%t` and which never calls `$finish`, so it touches none of the three
aliases. Codegen confirms it directly: the `%t` design emits
`VL_TIME_UNITED_Q(1)` and `VL_FINISH_MT` inside `nba_sequent__TOP__0`, which
runs under `Vlng::eval_step()`; the reference design emits neither.

**RULING: keep the `release()`, and record the reason as "every build", not
"only `-t`".** It costs one deliberately-leaked `VerilatedContext` per process
(bounded — `d_cosim` unloads the library at end of run) and it is the difference
between working and reading freed memory for any user Verilog that mentions
time or calls `$finish`. The comment in `verilator_shim.cpp` and the bullet in
`tools/cosim/README.md` now say so, and both warn against re-deriving "inert"
from a run of `counter.v`. This matters operationally because
`tools/cosim/README.md` "Keeping `src/` in sync" tells the next maintainer to
re-apply the `XSCHEM PATCH` hunks by hand on an ngspice upgrade — a maintainer
told this hunk buys nothing would have a reason to drop it.

Two scope notes so this ruling is not over-read:

- It is about the **patched** shim. Per part 1, a `cosim trace 0` build is
  compiled from the stock system shim and has no `release()` at all; there the
  upstream bug is simply present.
- Nothing in the tree currently *tests* any of this. The only harness that
  touches the build path is `tests/headless/test_ase_cosim.tcl`'s stub, which
  explicitly swallows `-t` (`:608`) and records no argv, so a stray `lappend cmd
  -t` in `ase::cosim_build` would leave BD1-BD26 green. Part 1's `-t` fact is
  protected by prose only.

#### M18 mechanically — a device card keeps its case only with EXACTLY two quotes

M18 recorded the *symptom* (ngspice silently lower-cases the strings in a device
card, and for `sim_args` there is no error at all). The mechanism is one small
function, and knowing it lets you predict which of your own lines will be
folded — which the symptom alone does not.

**The code.** Line numbers below are the **ngspice source tree**, not xschem's:
`/home/qflow/dev/ngspice_test`, clean at commit `db9d99843`. Pin the commit when
you quote them — an earlier draft of this section carried numbers taken from a
stale scratchpad copy and every one of them was 4 lines high against the tree it
named. Grep for the identifier, not the line, if the two disagree.

ngspice routes a `.model` line to `keep_case_of_cider_param()`
(`src/frontend/inpcom.c:223-254`) when `is_xspice_model()` (`:416-438`, called at
`:1908`) matches it: the line must start with `.model` *and* mention one of
`filesource`, `table2d`, `table3d`, `d_state`, `d_source`, `d_process`,
`d_cosim`. That function counts the `"` characters on the line and then branches
on a single test (`:238`):

```c
if (numq == 2) {          /* one pair -> preserve what is between them */
    ... toggle keep_case at each '"'; tolower_c only while !keep_case ...
} else {                  /* ANY other count -> fold the WHOLE line */
    for (s = buffer; *s && (*s != '\n'); s++) *s = tolower_c(*s);
}
```

Anything not routed there falls through to the generic fold at `:1912-1927`.

**The rule, in one sentence: count the double quotes on the physical line;
exactly two preserves the single quoted run, and *every other count*, including
four, folds the entire line — quotes, paths and all.** "Even" is not the rule.

Measured on the installed **ngspice-46** (not the source tree) with
`.control listing p .endc`, 2026-08-10:

| card as written | `numq` | what ngspice stored |
|---|---|---|
| `.model Counter d_cosim simulation=./CounterUP.so` | 0 | `simulation=./counterup.so` — folded |
| `.model Counter d_cosim simulation="./CounterUP.so"` | 2 | `./CounterUP.so` — **case kept** |
| `.model Counter d_cosim simulation="./CounterUP.so" sim_args=["MixedCase.vcd"]` | 4 | `./counterup.so` *and* `mixedcase.vcd` — **both folded** |
| …the same plus a second `sim_args` element `"Second.arg"` | 6 | all three folded |

**This is why M18 is silent and why it bit us.** A card carrying only
`simulation="…"` has two quotes and keeps its case perfectly. Adding `sim_args`
— which is precisely what E2 does in order to name the VCD — takes the line to
four quotes and retroactively destroys the case of `simulation=` as well. The
parameter that breaks the line is not the one that appears to be affected.

**Continuation lines are counted separately, and are always folded.** The count
is per *physical* line, and only the line beginning with `.model` is eligible at
all (`is_xspice_model` requires that prefix; the `+` arm at `:1896-1899` is
CIDER-only — it is guarded by `in_cider_model`, so an XSPICE continuation never
reaches `keep_case_of_cider_param` at all). Measured:

```
.model Counter d_cosim simulation="./CounterUP.so"      <- numq 2, ./CounterUP.so KEPT
+ sim_args=["MixedCase.vcd"]                            <- separate line, folded to mixedcase.vcd
```

That is independent confirmation of E2's decision to leave a `+`-continued card
untouched: there is no way to write a case-preserving `sim_args` on a
continuation line.

**What this does *not* change.** ASE's chosen behaviour — write a bare,
lower-cased basename and let it resolve against the run directory — remains
correct, and is now correct for a stated reason rather than an observed one:
every card ASE traces carries both `simulation=` and `sim_args=`, so it always
has at least four quotes and always folds. Lower-casing up front is not
defensive, it is agreeing with the parser.

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
| D2 | ~~**Joint X domain.**~~ **RULED AND IMPLEMENTED 2026-08-10 (batch F item 8): the AUTOMATIC X window is the union of the extents of every database contributing a trace to the shared-X strip GROUP.** See "D2 — the joint X domain" below for the four rulings (what contributes, what a degenerate input does, what the group is, and what is still NOT unioned). `graph_fullxzoom()` was the one `node=` walker that never parsed `%` at all; it is now the seventh caller of `node_token_split()`. | Silent-wrong-answer risk if one DB's extent is used as the whole. |
| D3 | ~~**Time-unit reconciliation.**~~ **DONE — converted once at read (C1, `vcd_read()` stores seconds) and now ASSERTED against A6.** `tests/headless/test_vcd_time_base.tcl`, **124 checks** (112 when the reference artifacts are absent), pinned to the `--nogui` arm. The gate is a stated number, not a feeling: **100 ps**, which is 10.1× above the measured 9.883 ps physical skew and at minimum ~500× below the smallest 1e3 error the file can produce (the ÷1000 direction on the earliest edge used, 50 ns → 49.95 ns of displacement; the ×1000 direction is 499,500×). A zero tolerance would be wrong — the two DBs record different events, a Verilog value change versus an analog threshold crossing after a finite `dac_bridge t_rise`, sampled on ngspice's timestep grid. Coverage: six `$timescale` units including the two-token `10 ns` form, the whole fs→ps→ns→µs→ms→s ladder (**every rung of which IS the 1e3 factor**), the multiplier forms, seconds-not-ticks, and the symmetric "rescale the raw instead" error. The 1e3 rejection is **proved, not asserted**: nine negative-control VCDs that are deliberately 1e3 wrong — perfectly valid files, which is the whole point — go through the *same* `agree` proc the real checks use and must be rejected. **19 sabotages injected, all 19 caught; every one of the 124 checks is caught by at least one.** | Off-by-1e3 here looks like a plausible waveform. |
| D4 | ~~**Cursors, markers, annotation across DBs.**~~ **RULED AND IMPLEMENTED 2026-08-11 (batch F item 9): a cursor at time *t* resolves in the current database PLUS every database contributing a trace to the strip, a dense analog sweep INTERPOLATES and a sparse event stream HOLDS, and neither extrapolates past either end.** See "D4 — cursors and markers across databases" below for the **eight** rulings (D4-6/D4-7/D4-8 came out of the fix round: the sweep column is exempt from the HOLD, the X window does not gate the annotation, and the cursor's scope is every strip that shares it) and for why MARKERS needed no change. `graph_cursor_dbs()` is the eighth caller of `node_token_split()`. The half no engine check could see: the readout BAR is Tcl and was current-database-only, so the digital trace was drawn, legended, and then silently absent from the cursor line. | `Raw` fields, `src/xschem.h:1129-1137` |
| D5 | ~~**Backannotation.**~~ **RULED AND IMPLEMENTED 2026-08-11 (batch F item 10): a digital database contributes NOTHING to `annotate_op` and NOTHING to the schematic voltage overlay, and the exclusion is single-sourced off the reader table's new `digital` column rather than assumed.** See "D5 — backannotation and the digital database" below for the eight rulings (what contributes, where the one predicate lives, the THREE enforcement points, why the array is cleared instead of left standing or handed to a substitute database, which paths tell the user why, that the `@spice_get_*` FLOATERS are the overlay too, that the refusal asks the FILE and not only the caller's type token, and that `raw switch` deliberately does not touch the array). It was not already true, **on two separate roads**: `xschem raw read <f>.vcd vcd` makes the VCD CURRENT, so the next cursor motion published its logic levels into `ngspice::ngspice_data` — with a colliding name, `1` where the analog raw says `0.7535` — and `src/token.c`'s `@spice_get_voltage` family read `cursor_b_val[]` out of the current database with no guard at all, so `lab_pin.sym` printed that same `1` (and `0.5` for an UNKNOWN net) as schematic text. `tests/headless/test_backannotate_digital.tcl`, **81 checks, 31 sabotage patches, 76 of the 81 driven red**. | `src/scheduler.c:2145` |

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

#### D2 — the joint X domain (batch F item 8, 2026-08-10)

**The defect, precisely.** `graph_fullxzoom()` (`src/draw.c`) computed the automatic X
window from ONE database: the current one, or — for a strip that follows a master — the
master rect's `rawfile=`. It was the sixth-and-a-half walker of the `node=` list and the
only one that never parsed the `%` field at all, which is why item 1 did not have to
touch it. With the reference pair (`tb_counter_wrapper_ase.raw` 0..2 µs,
`counter.vcd` 0..500 ns) the answer therefore depended on the registry cursor, and
`tests/headless/test_node_token_split.tcl` measures all three parent answers on one
fixture: with the session raw current the mixed strip is fitted to **0..2e-9**, with the
VCD current to **0..5e-7**, and with a single-sample database current to
**{1e-06 1e-06}** — a **zero-width** window, which makes every X transform divide by
`gr->gw == 0`.

**RULING D2-1 — the window is a UNION, and what contributes is stated, not implied.**
Two kinds of contributor, and only two:

* **every `%<rawfile>` named by a `node=` entry THAT RESOLVES.** One that does not
  resolve contributes nothing — every other walker REFUSES such a trace (issue 0305's
  ruling), so sizing a window for it would fit a trace that is never drawn.
* **the strip's own database** — its `rawfile=`, or the current one when it has none —
  but *only when a trace actually plots from it*: at least one `node=` entry WITHOUT a
  `%<rawfile>`. A strip whose every entry names its own database must NOT be sized by
  whatever database the registry cursor happens to be parked on. That clause is the whole
  defect.

The bare-entry half has an ordering obligation that is easy to get wrong and invisible
when you do: the strip's own database is measured **after the last per-trace switch has
been unwound**, not while it is still in force. `XD15` is the check, on a strip built so
the two answers differ.

**RULING D2-1a — the TRACELESS strip, and why its fallback is a second pass over the
GROUP.** An empty strip has nothing to go on and must still get a drawable window, which
is what the shipped code gave it (`XD12`). The first cut of this item delivered that by
letting a traceless rect fold the current database into the union unconditionally — and
that put the defect straight back, because `wviewer::add_graph` appends exactly such a
strip beside strips that do carry traces: one empty member dragged the registry cursor's
database into the whole group's union, so every other strip's automatic window snapped
back to whatever the cursor was parked on, and the group then *disagreed* (the fallback
fired for the empty member and not for the others), violating D2-3. **The ruling:** a
traceless strip contributes nothing to a group that has traces. Only when the WHOLE group
turns out to be traceless does `graph_fullxzoom()` make a second pass, over the same
group, with the fallback enabled — over the group rather than over rect `i`, so that every
member computes the same answer whichever one the gesture started on. Checks `XD16`,
`XD16b`, `XD17`; `XD12` still pins the lone-empty-strip case.

That second pass is gated on *no `node=` entries at all*, not on *nothing contributed*.
The distinction is load-bearing: a strip whose only entry names a database that does not
resolve has traces, so it takes the **refusal** (keeps the window it had, `XD19`) rather
than the fallback. Sizing it from the registry cursor is precisely what D2-1's first
clause forbids.

**RULING D2-1b — a BARE entry follows the registry cursor, and the viewer builds bare
entries.** `wviewer::db_suffix` returns `{}` for a trace picked from the *current*
database ("THE CURRENT DB WINS", `src/wave_viewer.tcl`), so a production mixed strip is
one bare entry plus one carrying `%<rawfile>`. A bare entry names no database, so by
D2-1's second clause it is measured against whatever is current — which means **the
automatic window of a production mixed strip does move when the current database
changes**, and the cursor-independence of `XD3`/`XD4` is a property of an all-`%` strip
only. This is the ruling working as ruled, not a defect: once the cursor moves off the
analog database the bare analog trace stops being *drawn* as well, so a window that still
spanned it would be sizing for a trace that is not there. It is stated out loud here
because it is the shape a human eyeballing this feature actually sees, and because the
first cut of the item asked for an eyeball whose expected result was the opposite of what
ships. `XD22`/`XD22b` pin both halves. If a cursor-independent window is ever wanted, the
change belongs in `graph_props` — emit a `%` suffix for *every* trace — not in the engine.

**RULING D2-1c — the union is over ONE X QUANTITY, and it is the TARGET rect's.**
`graph_shares_x()` has never required a shared-X group's members to share a `sweep=`
variable, and `sweep=<vector>` is a shipped, used attribute
(`xschem_library/examples/test_nyquist.sch sweep=re_out`). Measuring each member in its
own `sweep=` folded an X-Y strip's VOLTAGE range into a locked time strip's window — a
2 ns waveform squeezed into 3e-9 of the axis, i.e. invisible, and a regression the parent
commit did not have. The `sweep=` of the rect **being written** decides the quantity for
the whole union; each contributing database still resolves that name itself, so a column
NUMBER never crosses a database boundary. A database that does not *have* the named
quantity contributes **nothing** rather than falling through to column 0, which would fold
a different quantity in by the back door. An ABSENT `sweep=` token is not that case: it
means column 0, which is what every database calls its x axis. Checks `XD18`, `XD18b`,
`XD18c`.

**RULING D2-2 — a degenerate input contributes, but never decides alone.** A database
with no values, no columns, no datasets, an empty dataset or an all-NaN sweep column
contributes **nothing** (`graph_x_extent()` returns 0, and 0 is a real answer, not an
excuse to invent one) — `XD20`/`XD20b` build a zero-point raw and `XD21`/`XD21b` an
all-NaN sweep column, both as a lone contributor (which must be REFUSED) and beside the
0..2 µs raw named first (which must widen nothing). Before those fixtures existed the
clause was asserted here and exercised by nothing.

The two halves of that clause are **not equally load-bearing**, and the honest split is
recorded rather than glossed:

* **The NaN guard is real.** Delete `if(v != v) continue;` and `XD21b` goes red: a NaN
  seeds the fold, every later comparison against it is false, and the whole union comes
  back NaN — which the degenerate refusal then turns into "the key did nothing".
* **The empty-database guards are DEFENSIVE, not load-bearing.** Deleting
  `if(!raw || !raw->values || !raw->npoints) return 0;`, `if(raw->nvars <= 0 ||
  raw->datasets <= 0) return 0;` and `if(first) return 0;` — individually or **all three at
  once** — leaves the suite 168/168 green, because a zero-sample database drives a
  zero-iteration loop and the degenerate refusal already catches what falls out. `XD20` and
  `XD20b` pin the BEHAVIOUR (they go red under a fixture sabotage that gives the database
  points, and under `S1`), not the guards. Keep the guards — they are cheap and the reader
  should not have to re-derive the argument — but do not claim a check defends them.

A database whose extent is a POINT — one sample — does contribute,
and since a union only ever widens it can never shrink the answer (`XD10`). But a union
that is degenerate **on its own** — zero width after everything has been folded in — is
**REFUSED**: `x1`/`x2` keep the window the strip already had (`XD11`). The alternative is
a window nothing can be drawn in, which is worse than the bug being fixed; the shipped
code wrote `x1 == x2` and let `setup_graph_data()` divide by zero, and the parent-commit
measurement above shows that is reachable, not theoretical.

**RULING D2-3 — the union is a property of the GROUP, and there is now ONE predicate.**
Every strip that shares an X axis is about to be handed the SAME `x1`/`x2` by
`callback.c`'s loop, so all of them must be measured; taking rect `i`'s own union instead
gives each member of a group a different idea of the window and the last one written
wins. The membership test is the shipped one, verbatim —
`rk->sel || (same_sim_type && !(rk->flags & 2)) || k == master`, with `same_sim_type`
additionally requiring the MASTER not to be `unlocked` and the two `sim_type=` **property
tokens** to match — and it now lives in exactly one place, `graph_shares_x()`.
`graph_axis_zoom()` held the second hand-written copy and was moved onto it; `callback.c`
still applies it inline to decide *which rects to call*, which is a different question
from *which rects to measure*. Note this is NOT the viewer's `sharedx` flag, which the C
engine cannot see.

Two honest limits on how far the checks reach into this ruling, recorded rather than
implied:

* **The group is taken from the MASTER, not from rect `i`** — otherwise each member gets a
  different window and the last write wins. No check can distinguish the two: `--nogui`
  never sets `xctx->graph_master` (it is MOUSE state), so `master` is forced to `i` on
  every headless call and the two expressions are the same code path. Substituting
  `graph_shares_x(i, k)` for `graph_shares_x(master, k)` leaves the file green. The rule
  is **verified by inspection**; the distinction only exists during a real gesture, where
  `callback.c` fixes `master` and loops `i`.
* **`XD3`/`XD4` deliberately measure an ISOLATED rect** (`flags=graph,unlocked`, a flag
  `src/wave_viewer.tcl` never emits), because `unlocked` is the only way to make a group
  of exactly one. The LOCKED-group equivalents — the shape the viewer actually builds,
  every strip locked and therefore a group member — are `XD5`–`XD7` and `XD16`–`XD18c`,
  which get a group of exactly TWO from a made-up `sim_type=` token instead.

**RULING D2-4 — what is deliberately NOT unioned, so nobody re-discovers it as a bug.**

* **A database is counted when its `%<rawfile>` resolves, not when the entry's expression
  also resolves in it.** Sizing a window must not require evaluating RPN, and `draw_graph()`
  switches to that database either way. A `%` naming a real database but a signal that is
  not in it therefore still widens the window.
* **`sim_type=` still gates X propagation**, so a rect tagged `sim_type=vcd` does not
  follow one tagged `sim_type=tran` — the carry-over noted under C6. That is a separate
  facet of D2, it is about which rects are in the group at all rather than about the
  extent, and it is untouched here. The viewer does not currently hit it: `graph_props`
  emits one `sim_type` per session, so a mixed strip is a single rect.
* **Zoom and pan are not re-based.** D2's row names "zoom, pan, `x1/x2`, and the shared-X
  strip logic"; what landed is the AUTOMATIC fit (`f`, `fullxzoom`) and the shared-X
  agreement about it. Interactive pan/zoom already operate on the window itself, not on a
  database extent, so they inherit the union — but nothing here clamps a pan to the union
  or reconciles D4's cursors.

**Proof.** The `XD` leg of `tests/headless/test_node_token_split.tcl` (**37 checks**, true
headless, on the reference pair plus a third 0..2e-9 extent so a window that came from the
registry cursor is recognisable on sight): **29 of the file's 168 checks are red at the
parent commit `da93e9ba`** (`RESULT: 29 FAILED (139 passed)`, re-measured by the closer on
the final fixture with `git show HEAD:src/draw.c` rebuilt and restored byte-exact),
including the four structural counts that went from six walkers to seven. `test_wave_crossdb_trace.tcl`'s `XD` leg was **RESTATED, not deleted** — it used
to pin the defect as a known limitation and now asserts the union at the viewer level.

Two of the 37 are green at the parent by design and carry no positive evidence of their
own: `XD12` (an empty strip still gets a window) and `XD17` (moving the cursor does not
move the window — the parent agrees, on the wrong window; `XD16` asserts the value in the
same breath). `XD22b` is likewise green at the parent, for the reason D2-1b states.


#### D4 — cursors and markers across databases (batch F item 9, 2026-08-11)

**The defect, precisely.** `annot_p`, `annot_x`, `annot_sweep_idx` and
`cursor_b_val[]` are fields of `Raw` (`src/xschem.h`), i.e. **per database**, and
`backannotate_at_cursor_b_pos()` (`src/callback.c`) resolved cursor B in
`xctx->raw` and nowhere else. A cursor at *t* was therefore not one object at one
time — it was N objects that happened to have been placed together and could
drift apart. With one database nobody notices. With an analog raw and a VCD
loaded together the current database read correctly and every other one kept
whatever index it was last left with; for a database that has never been current
that is `annot_p == -1` and a `cursor_b_val[]` still full of `my_calloc` zeros,
which reads as *"that signal is 0"*, not as *"nothing asked"*. Measured at the
parent commit `81a2b53f` on the item's own fixture: with the analog raw current,
the VCD's `TOP.m.siga` answers `0` at every *t*, including the *t* where its last
event set it to 1.

**RULING D4-1 — the cursor resolves in the CURRENT database plus every database
contributing a trace to the strip, and it is deliberately a SUPERSET of D2's
rule for the X window.** Three kinds of contributor:

* the database that is **current on entry, always** — whether or not this strip
  plots anything from it. It is what `xschem raw value <n> {}`, `annotate_op()`
  and the schematic voltage overlay read when nobody switched, so including it
  unconditionally is exactly what makes a single-database session behave as it
  did before D4. (D2 could not afford this clause: an X *window* sized from the
  registry cursor is the defect D2 exists to remove. A cursor *readout* on the
  current database is not a wrong answer, it is the answer the rest of the
  engine is already built on.)
* every **`%<rawfile>` named by a `node=` entry that RESOLVES**. One that does
  not resolve contributes nothing — every other walker REFUSES such a trace
  (issue 0305's ruling), so annotating for it would be annotating a trace that is
  never drawn (`XC19`, and the enumerator's own refusal).
* the strip's **own database** (its `rawfile=`, else the current one) when a
  trace actually plots from it: at least one `node=` entry without a `%`. A
  TRACELESS strip contributes its own database too — unlike D2 there is no group
  to disagree with, and a cursor on an empty strip must still annotate something.

The enumeration is `graph_cursor_dbs()` in `src/draw.c`, **caller number eight of
`node_token_split()`** — never parser number two. It leaves both halves of the
registry cursor where it found them (`extra_idx` and the `extra_prev_idx` that
`xschem raw switch_back` goes to; batch F item 2, finding 1), and so does the
fan-out in `callback.c` that consumes it. That matters more here than anywhere
else in the family: this code runs on **every cursor motion**.

**RULING D4-2 — exactly ONE database publishes `ngspice::ngspice_data`, and it is
the one that is current on entry** (`slots[0]` by construction). The Tcl array is
a flat name→value map read by the schematic voltage overlay and by every floater;
letting each database rewrite it would make the last switch win, and *merging* a
VCD's names into it is **D5's** question — what a digital database contributes to
schematic backannotation — which D4 left open and D5 has since **RULED: nothing,
and if the entry database is itself digital the array is cleared and nobody
publishes** (batch F item 10, "D5 — backannotation and the digital database"). Every
contributing database still gets its own `annot_*` and `cursor_b_val[]`; only the
publishing is singular. `XC51`–`XC54`.

**RULING D4-3 — a dense analog sweep INTERPOLATES; a sparse event stream HOLDS.**
This is the rule the row asked for, and the two halves are not a matter of taste:

* **Dense analog** — unchanged. Samples are close enough together that
  nearest-sample-before and interpolation are visually the same thing, and the
  viewer's readout has always shown the interpolated value (`test_wave_viewer`
  G15b pins the Tcl mirror against this function's answer).
* **Sparse (`sim_type` `"vcd"`)** — the value at *t* is the value set by the LAST
  event at or before *t*, held, however far to the left that event is. That is
  not an approximation, it is what a digital signal *does* between events. And
  the approximation is not merely imprecise, it is **a different symbol**: C3
  encodes `0 → 0.0, 1 → 1.0, X → 0.5, Z → 0.3` and `get_bus_value()` reads
  anything in the 0.2..0.8 band as UNDEFINED, so interpolating across the
  one-tick step C2 materializes at each change (`(t − 1 tick, old)` then
  `(t, new)`) makes the readout say **X about a perfectly known signal**. The
  width of that window is the file's `$timescale`: a picosecond on the reference
  `counter.vcd`, a **nanosecond** on a `1ns` file, i.e. squarely where a human
  puts a cursor. `XC21`/`XC22`/`XC24` park the cursor inside it.
  Only `"vcd"` takes this arm — a `table` database is a sampled table, not an
  event stream.

C2's step materialization means the two rules already agreed *in the middle* of a
hold span (both samples carry the same value, so the interpolation is flat). The
step itself, and the two boundaries below, are where they part.

**RULING D4-4 — neither kind extrapolates, at either end.** A cursor **before** a
database's first sample reads that first sample verbatim; **after** its last
sample, the last one verbatim. For a sparse stream this also answers the row's
two open questions directly: before the first event the value is **the file's own
first recorded state**, which `vcd_read()` already fills with X (0.5) when nothing
was dumped — *not* a synthesized X, and not "undefined"; after the last event it
is the last event's value, because the run ended, not the signal.

Both boundaries are reachable in the shipped product on every cursor move: D2
fits the X window to the UNION of the contributing databases, so the reference
pair puts 1.5 µs of analog axis beyond the VCD's last sample. The old code
extrapolated there off the FORWARD segment's slope, and at the last sample of a
dataset it did so by reading `values[idx][p + 1]` **one element past the end of
the `my_calloc(allpoints)` buffer** (`save.c`). Measured at the parent commit on
the item's fixture: a cursor at 2.5 µs on a raw ending at 2 µs / 0.30 V read
**0.37500001**, and moving it to 2.9 µs read **0.43500002** — a readout that
moves when the data does not, off a heap word. Two lines fix it: the
interpolation fraction is clamped to [0,1] (which also covers the *before* case,
and a decreasing sweep), and `point_not_last` became `p + 1 < ofs_end`.

**RULING D4-5 — MARKERS need no change, and the reason is structural.** A marker
is bound to ONE trace (`GraphMarker.wave`), so it is single-database *by
construction*: `graph_marker_sample()` → `graph_wave_resolve()` already switches
to that trace's own database and returns column numbers valid in it (issue 0305,
batch F item 1; pinned by the `NDM` leg of
`tests/headless/test_node_token_split.tcl`). A marker also samples an exact point
index rather than a position between samples, so D4-3 does not arise for it at
all. The **cursor** is the one that is per-STRIP and therefore has to fan out.
Recorded as a ruling rather than left implicit because the row's title says
"cursors and markers" and a reader is entitled to know why only half of it moved.

**RULING D4-6 — the SWEEP COLUMN is exempt from D4-3's HOLD** (fix round). A time
axis is not an event-driven signal. Holding it froze a VCD's own `time` readout
at the last event's timestamp while the *same* `Raw`'s `annot_x` recorded the
real cursor position, so the database contradicted itself: measured on the item's
fixture, `xschem raw annot` on the VCD said `6 1.75e-07 0` while
`xschem raw value time {}` on it said `1.5e-07`. Before this item the sweep column
interpolated to the cursor for every kind of database, and it still does; D4-4's
clamp then makes that "the cursor position, clipped into this database's own
span", which is the only honest answer past either end. `XCT2`–`XCT6`.

**RULING D4-7 — the X WINDOW IS A RENDERING CONCERN AND DOES NOT GATE THE
ANNOTATION** (fix round). The sample scan in `backannotate_cursor_b_in_db()`
only considers samples inside the strip's current X window `[gr->gx1, gr->gx2]`.
That is invisible while every contributing database overlaps the window, and it
is exactly wrong the moment one does not: with D4-1's fan-out a database whose
samples all fall outside the window fell through with `first == -1` and had
**nothing stamped**, so it kept the annotation of wherever the cursor *used to
be* — or, never having been annotated, the `-1` and the `my_calloc` zeros this
section already calls out as reading *"that signal is 0"*. One cursor, two times,
reachable by any ordinary wheel zoom (`wviewer::wheel_zoom` writes `x1`/`x2` on
the graph rect). Measured: window zoomed to 1..3 µs and the cursor moved
1.5 µs → 2.5 µs left the VCD's `annot_x` frozen at `1.5e-06` while the other two
databases said `2.5e-06`; and a window before `late.raw`'s first sample read its
**last** sample, 0.65, where D4-4 requires its first, 0.60.

So when the window yields nothing, the same database is **rescanned with the
window filter off**, and the answer is D4-4's own rule applied to its whole
sweep — nearest of its own samples, clamped at both ends, never extrapolated.
Resetting `annot_p` to `-1` instead was considered and rejected: a cursor at *t*
deserves a real answer from a database that merely is not on screen, and the
readout bar has no way to render "no answer" that is not itself a lie.
`XCW2`–`XCW7`.

**RULING D4-8 — CURSOR B IS A VIEWER OBJECT, NOT A STRIP OBJECT, so its scope is
every strip that shares it** (fix round). `xctx->graph_cursor2_x` is one global,
and the canonical mixed-signal layout is Cadence's: analog on one strip, the
digital bus on **its own strip** underneath. Fanning out over only the rect that
happened to be passed in left that strip's VCD never annotated at all —
`annot_p -1`, `cursor_b_val` still zero — because `xschem set cursor2_x`
(`scheduler.c`) hard-codes `rect[GRIDLAYER][0]` and every mouse-motion caller
passes just the rect under the pointer. Which databases got a fresh cursor
therefore depended on where the mouse was. `graph_cursor_dbs()` now unions the
contributors of **every** graph rect that shares the cursor.

A strip with `private_cursor` (flags bit 4) is excluded **in both directions** —
it has a `cursor2_x` of its own, so it neither joins another strip's fan-out nor
drags other strips into its own; that is the same reading of the flag
`backannotate_cursor_b_in_db()` already applies when it picks `cursor2`. The
per-database *resolution* still uses the driving strip's `Graph_ctx`: `gr` is the
single shared `xctx->graph_struct` and re-running `setup_graph_data()` per
sibling on every cursor motion would both cost a walk and stamp another strip's
geometry into it. That is sound **because of D4-7** — a database with nothing
inside the driving strip's window is resolved against its own whole sweep rather
than skipped, so a sibling's zoom cannot change the answer. `XCS0`–`XCS6`.

**The Tcl half owes both registry halves too** (fix round). `extra_idx` is the
current database; `extra_prev_idx` is where `xschem raw switch_back` *goes*, and
every `xschem raw switch` overwrites it. `wviewer::trace_cursor_value` restored
only the first half, which is the half-restore batch F item 2 removed from
`find_closest_wave()`, reintroduced one layer up — and this proc runs **once per
trace per cursor motion**, so a mixed strip under a dragged cursor rewrote the
session's `switch_back` destination continuously. Measured: registry parked at
current=0/prev=2, one call, and `switch_back` landed on the borrowed database.
The earlier note that "no Tcl verb writes `extra_prev_idx`" was **wrong about
what that implies**: `switch_back` is its own inverse, so the pair can be *read*
without moving anything (two `switch_back`s leave both halves as found) and put
back with two switches — `switch $prev`, then `switch $cur`.
`wviewer::raw_prev_idx` / `wviewer::raw_cursor_restore`; `XU8`–`XU9c`.

**The half no engine check could see, and it was the whole user-visible payload.**
`wviewer::readout_refresh` — the bar the user actually reads — does not consult
the engine's annotation at all. It calls `wviewer::interp_value`, which asks
`xschem raw list` / `xschem raw value`: the **current database**. So with the
engine fix alone, a cross-DB digital trace was rendered by `draw_graph()`, named
in the legend, and then **silently missing from the cursor line** — no error, no
placeholder. Three changes in `src/wave_viewer.tcl` close it:
`wviewer::trace_cursor_value` brackets a switch into the trace's own database
(the `rawfile`/`sim_type` pair `db_suffix()` already puts after the `%`, so the
readout and the renderer agree by construction) and restores by absolute index on
every path; `interp_value` grew the D4-3 HOLD arm (its two boundary arms were
already D4-4); and `wviewer::readout_entries` dedupes on the **(vec, database)
triple** rather than the bare name — the same lesson as defect 2 of the D1 review
round, one layer up, and the shape §E produces when two `d_cosim` blocks
instantiate one Verilog module. Measured, real viewer, real cursor:
`B: x=999.5p   v(anlg)=500.8m   TOP.m.siga=1` where the parent's line stops after
`v(anlg)`.

**THE HAZARD THIS FIX ALMOST CREATED, and the refusal that closes it.**
`raw_read()` calls `backannotate_at_cursor_b_pos()` from INSIDE
`extra_rawfile()`'s read arm (`save.c`), at a moment when `xctx->raw` is the
freshly read database and is **not yet in `extra_raw_arr[]`** — `extra_idx` still
names the outgoing slot. A fan-out that switched from there overwrote
`xctx->raw`, and the read arm's `extra_raw_arr[extra_raw_n] = xctx->raw` a few
lines later then registered a database it had not read: **two registry slots
aliasing one `Raw`, the newly read one leaked, and a double free at the next
`raw clear`**. `graph_cursor_dbs()` therefore REFUSES — answers 0, caller falls
back to the current database alone — whenever `xctx->raw` is not the registry's
current entry. It survived sixty green checks first, because `vcd_read()` makes
no such call and every database read up to that point in the test was a VCD; the
checks that catch it (`XC81`–`XC85`) read a **spice** raw with a live cursor on a
cross-DB strip.

**Proof.** `tests/headless/test_wave_cursor_crossdb.tcl` — **93 checks, true
headless** (65 as first written, +28 in the fix round for D4-6/D4-7/D4-8 and the
`own_db_plots` clause), in `full_audit.sh`'s `nogui_tests`; fixture synthesized
(two analog raws, one of which starts at 1 µs, and two `$timescale 1ns` VCDs, one
of which starts at 500 ns), no simulator. **21 of the 60 checks that existed at
the time are red at the parent commit `81a2b53f`** — measured with `draw.c` and
`callback.c` reverted and `scheduler.c`'s `raw annot` verb kept, because the file
uses that verb; the shipped file does not run at `81a2b53f` at all. The viewer
half is the `XU` leg (12 checks) and the `PU` leg (5) of
`tests/headless/test_wave_crossdb_trace.tcl`, 109 → 130 checks. `NDX3` and `NDR7`
of `test_node_token_split.tcl` were **RESTATED, not deleted** (seven → eight
callers, seven → eight cursor put-backs); `NDR2`/`NDR3` deliberately stay at
seven and say why — the D4 enumerator resolves no sweep column and samples
nothing.

**Three shapes the first round's fixture could not build, and what they cost.**
Every check in the first round put all traces on **rect 0**, kept the X window at
0..3 µs for the whole file, and never gave a rect its own `rawfile=`. Each of
those three is a whole clause of D4-1 going unexercised: the multi-strip layout
found D4-8, the window found D4-7, and the strip's own database found that
deleting `if(own_db_plots) …` from `graph_cursor_dbs()` left **all 814 checks in
five suites green**. A fixture that only builds the shape the code was written
for is not evidence about the shape it was not.

**Not done here, and named so nobody re-discovers it as a bug** *(RESOLVED by
D5, below — this paragraph is left as the record of what D4 knew)*: D5. The
schematic voltage overlay and `annotate_op()` still read the current database
only, and a digital database still contributes nothing to them — by RULING D4-2,
on purpose. The per-sibling resolution uses the driving strip's `Graph_ctx` by
D4-8, so a strip whose own X window is *narrower* than the driving one can still
have a database resolved against a wider candidate set than it renders; D4-7
makes the answer right in every case measured, and no case where the two disagree
has been constructed. Multi-**dataset** databases remain unexercised: D4-7's
rescan also un-skips a pre-existing shape where a non-final dataset's `first` was
reset to `-1` by a later skipped dataset, which is a strict improvement but has
no check.

#### D5 — backannotation and the digital database

**STATUS: RULED AND IMPLEMENTED 2026-08-11 (batch F item 10).** The answer is
NOTHING, and it is now a rule with enforcement rather than an assumption.
`tests/headless/test_backannotate_digital.tcl`, **81 checks, true headless**
(`--nogui`, in `full_audit.sh`'s nogui arm), **31 sabotage patches across the two
rounds (`S1`-`S33` with gaps, plus `S21a` and `SF`); 76 of the 81 checks are
driven red by at least one of them**, and the five that are not are named
below rather than counted as evidence (`BA40`, `BA53`, `BA55`, `BA56`, `BA5a`).

**⚠ THIS SECTION WAS WRITTEN ONCE ALREADY, AND WAS HALF TRUE.** The first round
enforced the exclusion on the publisher of `ngspice::ngspice_data` and called the
overlay done. An adversarial pass then measured a VCD's logic level being printed
on the schematic anyway, through `src/token.c`'s floaters, which never touch that
array (RULING D5-5); found that the refusal keyed on a type token neither GUI call
site ever passes (RULING D5-6); and found the refusal sentence splicing a
user-supplied path into a Tcl script. Rulings D5-5, D5-6 and D5-7 and 25 of the
81 checks come from that second round. The lesson is the one this section is
about: *"probably nothing", merely assumed, is how a digital database ends up
half-participating* — and "enforced at every path" is a claim that has to be
measured at every path, not at every path one happened to think of.

**Why this needed a ruling and not a shrug.** Backannotation puts *operating
point* values on the schematic — node voltages and device currents — read out of
the flat Tcl array `ngspice::ngspice_data` by `ngspice::get_voltage` /
`get_current` / `get_diff_voltage` / `get_node` (`src/xschem.tcl:2626-2760`) and
by every floater. A VCD carries **logic levels over time**. A logic level is not
a voltage: `1` is not 1.8 V, it is `1`; and `vcd_read()` encodes X as `0.5` and
Z as `0.3` (`VCD_VX`/`VCD_VZ`, `src/vcd_read.c` DECISION 3), so a published VCD
would print **"0.5" on a net whose value is UNKNOWN and "0.3" on one that is
floating**. Every one of those numbers is fabricated, and a fabricated number on
a schematic is indistinguishable from a measured one.

"Probably nothing", merely assumed, is how a digital database ends up
half-participating — excluded at one path, admitted at another, right on Tuesday
and wrong on Wednesday. **It was already half-participating**: see THE DEFECT
below.

**RULING D5-1 — a digital database contributes NOTHING to `annotate_op` and
NOTHING to the schematic voltage overlay.** Not a merged namespace, not a
fallback, not a "digital nets get 0/1 volts" convenience. The waveform window is
a different question and is *not* touched by this ruling: D4's per-`Raw`
`annot_p` / `annot_x` / `cursor_b_val` are still stamped for every contributing
database, digital ones included, so the viewer's readout bar still reads the
digital trace at the cursor. **D5 is about the SCHEMATIC.**

**RULING D5-2 — the exclusion is SINGLE-SOURCED, off the reader table.**
`raw_reader_table[]` in `src/save.c` — the one table that maps a `sim_type`
token to its parser (issue 0290) — grows a `digital` column, and
`raw_type_is_digital(const char *)` / `raw_is_digital(const Raw *)` are the only
answers. A future database type inherits this decision by filling in its row.
**Never `!strcmp(sim_type, "vcd")` at a backannotation site**: that is how the
question gets re-derived four times and answered differently by the third.
`table` is deliberately **not** digital — an ascii table is columns of real
numbers, an analog result read by another parser; the ruling is about logic
levels, not about "anything that is not a spice raw" (`BA12`).
Exposed to Tcl and to checks as `xschem raw is_digital [<sim_type>]`,
read-only, answerable with nothing loaded.

**RULING D5-3 — three enforcement points, because there are three paths.**
Found by walking every caller that turns a loaded database into
`ngspice::ngspice_data`:

1. **`update_op()`** (`src/save.c`) — the point-0 publisher, which the
   `annotate_op` arm, both `raw switch` / `switch_back` gates and the bare
   `xschem update_op` verb all funnel through. A digital database publishes
   nothing and **the array stays UNSET** (the function already clears it on
   entry), and `update_op()` answers **0**, i.e. "nothing was published", which
   `xschem update_op` hands back to the script that asked. `BA30`–`BA36`.
2. **the `annotate_op` arm** (`src/scheduler.c`) — `xschem annotate_op <file>
   <level> vcd` is refused **before anything is loaded or cleared**. Point 1
   would refuse to publish it anyway, but only after the file had been read into
   the registry, made current and drawn: *a refusal that arrives after the side
   effects is not a refusal.* `BA20`–`BA2b`; sabotage `S11` moves the guard
   below the load and reddens `BA22`/`BA23`/`BA28`/`BA29`/`BA2b` — the array
   wiped and the loaded OP deleted from the registry, which is exactly the damage.
3. **the cursor-B publisher** (`backannotate_at_cursor_b_pos`, `src/callback.c`)
   — D4-2 makes the database that is current on entry the sole publisher; D5
   adds: **and if that one is digital, nobody publishes and the array is
   CLEARED.** `BA43`–`BA4c`.

**THE DEFECT this found, which was live.** `xschem raw read <f>.vcd vcd` makes
the VCD **current** (`extra_rawfile()`'s read arm) — that is why
`ase::attach_dbs` and `wviewer::regenerate` both switch back explicitly. Any
path that does not switch back leaves a VCD current, and **the very next cursor
motion wrote that VCD's logic levels into `ngspice::ngspice_data` under the
VCD's own names.** Where a name collides with an analog one, the schematic
overlay silently swapped a measured voltage for a logic level. Measured on the
fixture: with the VCD current, `top.m.same` on the schematic read **1** where
the analog raw says **0.7535**. `BA46`; sabotage `S5` restores the old
behaviour and reddens seven.

**RULING D5-3a — the array is UNSET, not left standing, and NO other database is
promoted into the publisher's place.** Both alternatives were considered and
both are worse:

* *Leave it alone* → the last analog position's numbers stay on screen while the
  user moves the cursor: a **stale overlay that looks live**, which is the
  silent-wrong-answer shape this whole section exists to remove. `BA48`,
  sabotage `S6`.
* *Promote the first analog slot* → the overlay follows a database the user did
  not make current, so **which values the schematic shows depends on registry
  order**. `BA4b`, sabotage `S7`. (`BA4c` asserts the premise that an analog
  database really is in the fan-out at that moment, so `BA4b` is not a claim
  about an absent candidate — it was, until the fixture was fixed; see below.)

"No analog database is current, so there is nothing to show" is the true
statement, and **`?` is how `ngspice::get_voltage` already renders it** — no new
rendering, no new vocabulary. `BA35`, `BA49`, `BA74`.

**RULING D5-4 — the REQUEST paths say why; the CURSOR path is silent.** Item 5's
rule (a notice that describes a different behaviour than the code implements is
worse than no notice; RULING F1e/F1f) applied to the engine side. The refusal
sentence is **minted once**, in `backannot_refuse_digital()`
(`src/save.c`), and rendered by its callers rather than composed a second time:

> backannotation: '<file>' is a digital results database — it carries logic
> levels over time, not an operating point, so there are no voltages or currents
> in it to annotate onto the schematic

It goes to the CIW through the guarded `ciw_echo` idiom
(`[[ciw-feedback-channels]]`), to the debug channel always, and is **returned**
so `annotate_op` can hand the same words back as its Tcl result. So the answer
to *"if ONLY a digital database is loaded, does backannotation do nothing
silently?"* is: **`annotate_op` and `update_op` tell the user why; a cursor
motion does not** — that path runs on every motion of the pointer, and a message
on every motion is noise, not a notice. `BA21`, `BA73`; sabotage `S10` reworks
the sentence and reddens `BA21` alone.

**RULING D5-5 — the `@spice_get_*` FLOATERS ARE THE OVERLAY TOO, by a second
road that never touches `ngspice::ngspice_data`.** The first round of D5 enforced
the exclusion only on the *publisher* of that Tcl array, and that was **not the
whole overlay**. `translate()` / `get_pin_attr()` in `src/token.c` expand
`@spice_get_voltage`, `@spice_get_voltage(…)`, `@spice_get_diff_voltage`,
`@spice_get_current` and `@spice_get_modelparam` by reading
`xctx->raw->cursor_b_val[]` **straight out of the current database** — ten reads
across six branches — and `draw.c` expands exactly those tokens to draw the text
that `lab_pin.sym` (whose entire T record is `T {@spice_get_voltage}`),
`ipin`/`opin`/`iopin`, `vdd`, `ngspice_probe` and `scope` carry. **Measured with
a VCD current on the colliding fixture: `xschem translate <lab_pin> {@spice_get_voltage}`
returned `1`, and `0.5` when the VCD drove the net to `x`** — a fabricated volt,
printed on the schematic, while `ngspice::get_voltage` for the same net correctly
read `?`. So the array-only enforcement left the ruling *half* true, which is the
precise failure mode this section was commissioned to prevent.

All six branches now compute `live` as
`tclgetboolvar("live_cursor2_backannotate") && !raw_is_digital(xctx->raw)` —
one added term at the one precondition they already share, asking the D5-2
predicate rather than a local `strcmp`. **The token then renders exactly what a
session with live backannotation switched off renders: nothing.** "Contributes
nothing" is not "contributes a dash": there is no measurement, so no placeholder
is invented for one, and the Tcl half says the same thing in its own existing
vocabulary (`?`). `BA80`–`BA87`; sabotage `S21` drops the term at all six sites
and reddens `BA81`/`BA82`/`BA85`/`BA87`; `S21a` drops it at ONE site and reddens
only the source witness `BA87` — which is precisely why that witness exists, the
fixture reaching one of the six branches behaviourally; and `S30` latches the
guard and reddens `BA86`.

**RULING D5-6 — the refusal asks the FILE, not only the caller's type token.**
`annotate_op`'s `sim_type` is an **optional 4th argument**, and both shipped GUI
call sites (`src/xschem.tcl:14755` and `:15125`, `xschem annotate_op
$tctx::retval`) pass a filename **alone** — while `select_raw`
(`src/xschem.tcl:14292`) offers an `All Files *` filter, so pointing *Op
Annotate* at a `.vcd` is two clicks. Keying the refusal on the token alone meant
**the menu path was never refused at all**: the `op` → `dc` → `tran` fallbacks
each fail on a VCD, and the user got silence *after* `array unset
ngspice::ngspice_data` and after the "delete previously loaded OP"
`extra_rawfile(3, …)` branch had already fired — the exact "silently empty
schematic plus a registry the user did not ask to change" that D5-3's
before-any-side-effect placement exists to prevent.

So `raw_file_is_digital()` (`src/save.c`) sniffs the head of the file and the
refusal fires on **either** answer. The witness is `$enddefinitions`, which is
**mandatory** in every VCD and appears in no spice rawfile — definitive, not a
guess. The **extension is deliberately not consulted**: a VCD named `.raw` is
still a VCD and a raw named `.vcd` is still a raw, and only the content knows.
An unreadable file is *not* digital — the load below reports the real error.
`BA27`–`BA2b`; sabotage `S22` makes the sniff always answer 0 and reddens
`BA27`/`BA28`/`BA29`/`BA2b`. ⚠ The standing database in that fixture is a 1-point
OP on purpose: annotate_op's delete-previous-OP branch only fires on one, and
with a `tran` database standing instead `BA29` passed against no sniff at all.

**RULING D5-7 — `xschem raw switch` deliberately does NOT touch the annotation
array, for a digital database exactly as for an analog one.** Raised because the
state renders two ways: `raw switch <digital>` leaves the previous analog numbers
on the schematic, and the *next cursor motion* clears them. Considered and
**rejected**: clearing on switch-into-digital.

* `raw switch` is a **navigation** verb, not a request to backannotate. The
  publishers are `annotate_op`, `update_op` and the cursor; switching has never
  republished, and switching between two **analog** databases equally leaves the
  previous one's numbers standing. Nothing on screen is fabricated — those
  numbers are real measurements from a database that is still loaded.
* Clearing would be **actively destructive**. `wviewer::signal_list_all` (the
  All-DBs search, item 14) walks *every* loaded database with `xschem raw switch
  <idx>` (`src/wave_viewer.tcl`), and `ase.tcl` and `wviewer::with_db` do the
  same. A search that happened to hop through a VCD would silently wipe the
  design window's backannotation. A navigation verb must not destroy annotation
  state — that is the same disease as the All-DBs `update_op` clobber recorded in
  `doc/claude/code_analysis/signal_browser_teardown_scoping.md` §1, which D5 must
  not *widen*.

So the answer to "which values does the schematic show?" stays "whichever
database last **published**", and D5's guarantee is that a digital database is
never that database. `BA90`–`BA92` pin the choice in both directions: the array
survives the switch, and the next cursor motion clears it. Sabotage `S23` makes
`raw switch` clear on entry to a digital database and reddens `BA91`, plus
`BA63` as collateral — the analog overlay never comes back.

**⚠ THE REFUSAL SENTENCE CARRIES A USER-SUPPLIED PATH, so it is passed to Tcl as
a VARIABLE.** `backannot_refuse_digital()` originally spliced the database name
into a Tcl script inside a brace group
(`tclvareval("… {ciw_echo {", msg, "} note}")`). A path containing `}` closes the
group early: a plain `a}b.vcd` loses the notice to `extra characters after
close-brace`, and a crafted one **executes** — measured, a file named
`/tmp/p} note}; set ::PWNED 1; if {1} {list a.vcd` set `::PWNED` in the GUI
session. The sentence now goes over as a global variable that no path content can
escape from. Every other `tclvareval` + `ciw_echo` site in the tree interpolates
*program-generated* text; this was the first to interpolate a path, which is why
the quoting discipline starts here.

**The invariant, pinned: the presence of a VCD changes NO annotated value.**
Annotate with the analog raw alone, snapshot the whole array as a sorted
`{name value …}` string, load the VCD, annotate again from the same cursor
position — byte-identical (`BA52`, and `BA53`/`BA54` for the `update_op` and
`annotate_op` request paths). Sabotage `S12` lets every database in the fan-out
publish and reddens thirteen, `BA52` among them.

**"Contributes nothing" has TWO halves, and a colliding-name-only fixture can
only ask one of them.** `BA52` pins *a digital value does not OVERWRITE an analog
one*. It says nothing about a digital name the analog database has never heard
of — and an **additive merge** (publish the entry database, then fill in any name
a later digital database has that the array lacks) overwrites nothing, so it
passed `BA52`, `BA53`, `BA54` and `BA55` and scored **56/56** while putting
`top.m.donly = 1` on the schematic as a volt. The fixture's VCD therefore now
carries a **second, non-colliding** signal, named in the strip's own `%` entry so
it is genuinely in the cursor fan-out, and `BA56`–`BA5a` assert that with the
ANALOG database current it reaches neither the array nor the overlay, through the
cursor path and through `update_op`. Sabotage `S24` is that merge, and it now
reddens `BA52`/`BA58`/`BA59`.

**And the collision question, which is the one that matters.** *Does a digital
node name that collides with an analog one change which value is annotated?* No
— and the fixture is built to be able to tell. `coll.raw` carries
`top.m.same` = 0.75…0.79 (a voltage) and `coll.vcd` carries `top.m.same` =
logic 0/1, **the same stored name**. ⚠ **The case trap**: `read_dataset()`
`strtolower()`s every spice variable name (`src/save.c:1008`) while
`vcd_read()` stores Verilog identifiers **verbatim**, so an upper-case VCD scope
gives `TOP.m.same` against the raw's `top.m.same` — *two different keys*, no
collision, and the whole leg would be green against an implementation that
merges the two namespaces. `xschem raw index` hides this (it probes verbatim,
then upper, then lower), so the collision is asserted against `xschem raw list`,
the **stored** names (`BA1d`; sabotage `SF` upper-cases the VCD scope and
reddens it). This is item 7's lesson (`f51a19d1`) in the annotation array
instead of the browser inventory.

**The one duplicate answer that remains, named rather than hidden.**
`wviewer::db_is_digital` (`src/wave_viewer.tcl`, RULING F4, batch F item 6) also
decides "is this database digital?", by its own `string equal -nocase … vcd`. It
is **not** unified with `raw_type_is_digital()` and that is deliberate: it is
documented PURE, it is called with hand-seeded inventories that never reached
the engine, it trims and folds case where the engine's answer is the engine's
own stamped token, and it answers a different question — *how should this
database's signal NAMES be classified in the browser* — for which "digital"
happens to have the same membership today. **D5-2 governs backannotation
sites**, where the answer must come from the reader table.

**⚠ THE TWO LISTS ARE NOT PINNED AGAINST EACH OTHER, AND THAT IS A REAL GAP.**
The day a second digital reader is added to `raw_reader_table[]` and nobody
edits `wviewer::db_is_digital`, the browser will classify that database's names
as analog while the engine refuses to annotate it — or, worse, the reverse if
the Tcl side is edited and the table is not, in which case the schematic gains a
fabricated volt with no check going red. An agreement check was attempted and
**withdrawn**: `wave_viewer.tcl` is not sourced under `--nogui`, so the only
available witness was a regexp over ~15 k lines of source, and the non-greedy
proc-body pattern backtracked catastrophically (the test file hung past 120 s).
A source witness is still the right shape; it needs a line-scanner, not a
regexp. **Not done, deliberately named rather than left to be discovered.**

**Out of scope, stated so nobody reads silence as a ruling:**
`ngspice_backannotate.tcl` / `hspice_backannotate.tcl` build
`ngspice::ngspice_data` by parsing a simulator's *log*, not a loaded database;
they never see a VCD and are untouched. Nothing here changes what the waveform
window shows.

**What a fixture that only builds the easy shape costs, again.** `BA4b` ("no
substitute publisher") was green against sabotage `S7`, which implements exactly
the promotion D5-3a forbids — because with only an own-database entry plus the
VCD's `%`, the fan-out with the VCD current is *{the VCD}* alone and there was
no analog candidate to substitute. It took an explicit `%<analog raw> tran`
entry on the strip to make the check able to fail. Same disease as D4's
"all traces on rect 0" round.

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
| E2 | ~~Emit both artifacts.~~ | **DONE — one VCD per `.model` CARD, `<rundir>/<model>.vcd`, written into that card's `sim_args` by `render_deck`.** Two DIFFERENT code blocks can never collide (different model names → different files). The same block **instantiated twice** is the case the row asks about, and it has no honest per-instance answer: it is DETECTED — by counting **elaborated** instances, not netlist lines, because a `.subckt` body is emitted once however many times it is instantiated (so the spec's own canonical `tb → x1 (dig_top) → a1 (counter)` topology, with `dig_top` placed twice, is one `a1` line and two shims) — marked `multi 1`, EXCLUDED from the attach, and reported — because N shims opening one path interleave their writes and the file would not be data. Per-instance `.model` synthesis (which also means rewriting each instance line's trailing model token) is the documented upgrade path, not taken now. `simulation=` is left **untouched** on purpose: it is the user's choice of backend (`./counter.so` vs upstream's `ivlng` Icarus arm) and rewriting it would break the alternative. What goes into the card is a **bare, lower-cased basename**, not an absolute path, and that is **M18**, not taste: ngspice lower-cases the strings in a device card, so any capital letter anywhere in a run-directory path silently redirects the file — with NO error for `sim_args`. Precisely (§A "M18 mechanically"): the fold is skipped only for a card whose physical line carries **exactly two** double quotes, and a card ASE traces carries both `simulation="…"` and `sim_args=["…"]`, i.e. at least four — so an ASE-traced card is **always** folded and lower-casing up front is agreeing with the parser, not guarding against it. The basename is resolved against ngspice's cwd, which `ase::run_deck` already `cd`s to the rundir, exactly as the deck's own `simulation="./<cell>.so"` already relies on. `ase::cosim_map` keeps the ABSOLUTE path in `vcd` for Tcl (E3), which never goes near ngspice. The VCD is also **design-qualified** — `<cell>_<model>.vcd`, like `<cell>_ase.raw`/`.log`/`.cosim` — because the run directory defaults to `$USER_CONF_DIR/simulations` for every design, and a bare `<model>.vcd` let two sessions serve each other's digital data. And a card ASE will **not** trace gets no VCD at all and is left byte-identical: upstream's Icarus arm (`simulation="ivlng"`, whose `sim_args[0]` is the compiled vvp *design*, not a trace path), a `.so` ngspice opens from outside the run directory, a `+`-continued card, and `cosim trace 0`. **This was found only by running the reference TB end to end** — the run went green, the raw was perfect, and the VCD did not exist. 141 headless checks did not see it. |
| E3 | ~~Attach both.~~ | **DONE — `ase::attach_dbs`, and the ANALOG DB is current.** Measured: `xschem raw read` APPENDS to `extra_raw_arr[]` **and makes what it just read current** (`save.c:1281-1287`, `:1327-1333`), so reading raw-then-VCD leaves a VCD current and every existing consumer (`annotate_op`, `xschem raw value`, `add_trace`) would resolve analog names against it. The raw is read first (slot 0), then each VCD, then slot 0 is switched back explicitly. Partial runs: a missing/unreadable **raw** returns 0 and clears NOTHING (a stale-but-loaded DB beats an empty viewer — `attach_raw`'s existing policy); a missing or unreadable **VCD** is skipped with a notice and does not stop the analog attach, because an analog-only result is still a correct result. The registry is read **before** the outgoing DBs are dropped, so a raw that exists but does not parse (truncated, or missing the requested analysis because the run died after `op`) leaves the previous DB loaded — which is what the stated policy always claimed and the old clear-then-read order never delivered. One subtlety that order forces: `xschem raw read` does **not** re-read a path already in the registry (`save.c:1335-1339`, it just switches), and the raw artifact is a deterministic path a re-run overwrites in place, so the incoming path is cleared **specifically** first or every re-run would replot the previous run's data. `wviewer::attach_raw` grew a 4th argument that defaults to `{}`. `xschem raw_read` is NOT used (issue 0290: it clears the whole registry and bypasses the reader dispatch). |
| E4 | ~~State-dict fields.~~ | **DONE — ONE new key, `cosim`, and it is POLICY, not data.** `{build auto|always|never, trace 0|1, attach 0|1, bridges auto|0, vsupply <volts>}`; absent/empty means every default. It deliberately does **not** list the digital artifacts: those are derived (E1). **`version` stays 1.** Nothing reads it, `ase::state_load` merges over `state_default` so an old file gains the new key with its default automatically, and bumping the number would only invite an equality test somewhere. Asserted against a **committed frozen fixture**, `tests/headless/fixtures/ase_state_v1_pre_cosim.state` — it loads, keeps every old key (including an unknown one) byte-identical, gains `cosim {}`, and save→load→save is stable from then on. |
| E5 | ~~Deck emission for the digital side.~~ | **DONE — default `auto_bridge` `pre_set`s when the state configures none.** The migrator never *synthesized* those cards; it only carried them out of upstream's `code_shown` block (`ase_migrate.py:531-544` catches any `pre_*` line), so a **hand-built** mixed-signal state had none at all and ngspice bridged with built-in thresholds unrelated to the design's supply. `render_deck` now emits the adc/dac pair when the deck has ≥1 `d_cosim` card and no `auto_bridge_d_*` `pre_set` is already present **in the state OR in the netlist text**, at the supply from `cosim vsupply` → a `VDD` design variable → 1.8. The netlist half is not hypothetical: upstream's shipped testbench puts the pair in a `code_shown` block, so checking only the state appended ASE's defaults *after* the design's, and the later `pre_set` wins (measured, ngspice-46) — a 3.3 V design would have run with 1.8 V bridge thresholds and no message. A state that hand-writes them is left completely alone. Observation taps (§G3) are NOT part of this: they are a schematic-side technique for getting a signal into the *raw*, and the shim reaches internals directly now. |
| E6 | ~~Build orchestration.~~ | **DONE — `ase::cosim_build`, before the deck runs, and a failed build ABORTS the run.** Staleness is a **stamp file** `<so>.stamp` recording the source path, its mtime and size, the shim source's mtime and size, and the build flags — not an mtime compare. The reason is measured, not stylistic: `ase::rundir` defaults to `$USER_CONF_DIR/simulations` for **every** design, so two libraries that each hold a cell named `counter` build to the same `<rundir>/counter.so`; an mtime test would happily reuse the wrong one, and a `-V` shim edit would not invalidate anything. No content hash — Tcl 8.6 core has no digest and tcllib is not a dependency; path+mtime+size errs toward rebuilding, the safe direction. Always-rebuild was rejected on measurement: a warm no-op `build_cosim_so.sh` still costs **8.8 s** (cold 10.3 s). `build never` opts out; `build always` forces. Falling through to the previous `.so` on a build failure is exactly the "silently simulating last week's Verilog" outcome, so it throws instead. The `.so` is built to the **lower-cased** name too (M18): ngspice folds `simulation="./Counter.so"` and then reports `d_cosim failed to load simulation binary ./counter.so`. **That example needs its condition stated, or it contradicts §A "M18 mechanically"** — a card carrying *only* `simulation="./Counter.so"` has exactly two double quotes and ngspice keeps its case (measured 2026-08-10). The fold happens because the real card also carries `sim_args=["…"]`, taking the line to four quotes, at which point the whole line folds and `simulation=` goes down with it. Building to the lower-cased name is still right, and now for a stated reason: every card ASE traces has ≥4 quotes by construction (E2), so it always folds. `Run` on an existing netlist never loads the design, so the `.v` for a model comes from the run-directory map artifact (see F2 below). **A block ASE cannot check never blocks the run.** `xschem instance_list` enumerates the current schematic only (`scheduler.c:6458-6472`) while the netlister hoists the `.model` card to the top of the deck (`spice_netlist.c:575-591`), so a code block one level down has no resolvable `.v` at all — a configuration that worked before §E and must keep working. ASE says what it cannot check and gets out of the way; if the `.so` really is missing, ngspice's own `d_cosim failed to load simulation binary` is what reports it, and E7 matches it. |
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
| F1 | ~~**The branch.**~~ **DONE 2026-08-10 (batch F item 5), see "F1/F5 — the branch and the notice" below.** `ase::show_in_browser_for_current` (`src/ase.tcl:2521`) gained step 3c: `ase::browser_digital_probe` (`:1925`) beside the selection read, ABOVE the viewer raise, and a step 6 that shows the resolved scope through the new `wviewer::browser_show_db_scope` (`src/wave_viewer.tcl:10673`) instead of the analog walk. The ⚠ ordering was preserved and is now ASSERTED rather than described — `FV33` watches the live call order, not the source layout. | The `⚠` comments are load-bearing — the selection and hierarchy must still be read in the DESIGN context, before any viewer raise. Preserve that ordering. |
| F2 | **Scope-path mapping — the hard one.** The schematic path is `x1.a1`. The VCD's internal path is whatever Verilator named the top module and its sub-scopes (`TOP.counter.cnt`, module-name based, subject to inlining). These two namespaces have **no inherent relationship**. **OWNERSHIP RULED 2026-08-09 — see "Open decision 5, ruled" at the end of this spec, which is F2's contract**: the mapping is three facts, not one (instance→cell is QUERY time, cell→VCD file is NETLIST time in `<rundir>/<cell>_ase.cosim`, file→scope is DERIVED from the loaded DB); the join key is the **cell** (`lib/cell`, with a four-rung ladder ending at the instance's own `model=` property), never the instance path; the schematic prefix is **dropped, not translated**; `scope` stays a hint, is not even eligible when the entry's `vfile` is empty, and the derived answer wins. A code block **below** the netlisted schematic reaches only rung 4 — issue 0307. **IMPLEMENTED 2026-08-09 (batch F item 4), see RULING 5f**: `ase::cosim_scope_for_instance <key> <instpath> ?<token>?` in `src/ase.tcl`, pinned by the **FS** group of `tests/headless/test_ase_cosim.tcl`. **F1 CALLS IT as of batch F item 5**, through `ase::cosim_scope_for_f1` (`src/ase.tcl:1834`) — the same resolver with step 1's design read hoisted into the caller, because the caller has to take that read before the viewer raise. | Without this, the browser can show the digital signals but cannot tell you *whose* they are. This is the item most likely to be underestimated. |
| F3 | ~~**Multi-DB display.**~~ **MEASURED AND FIXED 2026-08-10 (batch F item 6), see "F4/F3 — the digital signal class and the tree" below.** `wviewer::db_label` needed **no change** — a VCD reads `counter.vcd (vcd)`, distinct from `tb_ase.raw (tran)` beside it, and carries the space+bracket that stops it being read as a hierarchy segment (`FD38`). The **grouping did not read well and was not "mostly free"**: an inventory whose names are classified as ngspice names loses its top `$scope` level, mis-labels its wires as currents, and — at the shipped default box state — is not in the tree at all. That is F4's business and F4 fixed it. `wviewer::signal_list_all` was already right; what was missing was carrying its `type` **into the browser's own snapshot**. | Mostly free. Verify, don't assume. *(It was not free.)* |
| F4 | ~~**Classification.**~~ **RULED AND IMPLEMENTED 2026-08-10 (batch F item 6): digital names get their OWN class, `digital`.** See "F4/F3 — the digital signal class and the tree" below for the ruling, the measurement that forced it and which 0217 rulings it depends on. | Consistency with settled work. |
| F6 | ~~**The lower pane's per-database dimension.**~~ **RULED AND IMPLEMENTED 2026-08-10 (batch F item 7): the sea snapshot is keyed by DATABASE as well as by path.** Issue **0308 is CLOSED** by it, and two-pane item 15's `BD70d` limit with it. See "F6 — the sea has a database dimension" below for the ruling, the collision that measured it, and **RULING F1g**, which re-causes RULING F1e's sentence instead of deleting its arm. | Not on the original plan. It is the row issues 0308 and `BD70d` were both filed against. |
| F5 | ~~**Empty-pane notice.**~~ **DONE 2026-08-10 (batch F item 5).** `ase::browser_digital_msg` (`src/ase.tcl:1954`) prefixes the F2 resolver's OWN refusal sentence and adds nothing (RULING 5f-3); `wviewer::browser_notice` (`src/wave_viewer.tcl:8187`) puts it on the lower pane's caption, the sidebar status line, and — when the pane really is empty — INTO the pane, wrapped, on the canvas. The `ase::echo … error` tag is the one this row named. **RULING F1e (salvage pass) adds the FOURTH surface this row actually needed: the SUCCESS path's own empty pane**, which without it captioned itself "'TOP.m' has no signals of its own" about a scope that has two. | The failure mode users will actually hit. |

#### F1/F5 — the branch and the notice (batch F item 5, 2026-08-10)

**STATUS: F1, F2 and F5 are DONE; F3 and F4 remain open.** What landed: step 3c and step
7b of `ase::show_in_browser_for_current`, `ase::browser_digital_probe` /
`ase::browser_digital_msg` / `ase::browser_pane_unread` / `ase::cosim_scope_for_f1` in
`src/ase.tcl`, and `wviewer::browser_show_db_scope` / `browser_notice` /
`browser_sea_empty` / `browser_db_group_id` / `browser_rows_headered` /
`browser_row_exists` / `browser_names_under` plus an eleventh `browser_msg` kind in
`src/wave_viewer.tcl`. Pinned by the **FV** group of `tests/headless/test_ase_cosim.tcl`
(46 checks, `--nogui` arm) and `tests/headless/test_wave_sigbrowser_digital.tcl` (**FD**,
25 checks, Tk/X arm — 3 of them source checks that also run headless).

**⚠ THE FIRST ATTEMPT AT THIS ITEM COLLAPSED AND ITS COMMIT (`fda9d5a8`) WAS NEVER
REVIEWED.** Implementer, verifier and all three adversarial reviewers died mid-stream; the
closer committed what was in the tree. A salvage pass
(`doc/claude/batch_F/receipts/05b-f1-f5-salvage.md`) re-measured every claim and added
RULING F1e. **That salvage was itself reviewed, and the review found RULING F1e's payload
did not reach the user at all** — see RULING F1f, which is the fix, and which is why the
counts above moved (46 FV + 25 FD + `BK33` = 72 checks the item owns).

**⚠⚠ THE LESSON, STATED ONCE SO IT IS NOT RE-LEARNED: EVERY CHECK IN BOTH ARMS READ ITS
SURFACE IN THE SAME EVENT-LOOP TURN THAT WROTE IT, AND THAT IS THE ONE TURN THE PRODUCT
NEVER GETS.** A Tk gesture's queued virtual events are delivered when the binding RETURNS,
so a check that asserts a caption without turning the event loop first is asserting a state
that exists for microseconds. Two blockers hid behind exactly that (RULING F1f). `FD23`
and `FD24` are the shape that finds them: drive the real command, `update`, THEN read.

**RULING F1a — the gate is "the cell HAS a `verilog` view", not "has ONLY a verilog view".**
The branch is entered exactly when f1 answers a non-empty `vfile`, and an instance whose cell
has no `.v` is not merely refused, it is never asked: the probe returns `{}` and the shipped
analog path runs untouched. Two reasons, and the first decides it: `cosim_scope_for_instance`
answers `nodigital` for an ordinary analog cell, so entering the branch for every instance
would put "has no digital signals of its own" in the CIW on every Ctrl-Alt-V in an analog
design — training the user straight past the notice F5 exists to deliver. And the question the
gate is a proxy for ("is this a code block in THIS run?") is one only the run's own map can
answer (RULING 5a): a cell with a `verilog` view that the last run did not netlist as a
`d_cosim` card comes back `nomap`, with a sentence saying so, which is strictly more useful
than silence. Gating on "no schematic view" instead would silently skip a cell that IS a code
block but also carries a stale schematic view — the wrong-answer direction. Pinned by
`FV2`/`FV3`/`FV38`.

**RULING F1b — a refusal FALLS THROUGH to the analog path; it never strands the user.** The
digital branch is an *addition* to the shipped walk, not a replacement for it: on any refusal
(and on an `ok` whose scope the tree cannot reach) the existing `browser_show_path` walk runs
exactly as it did before this item, last-mile retry included, and F5's notice is written
AFTERWARDS. Refusing outright would trade a partial answer for none, and the shipped retry is
already the right behaviour for a code block — its own level does not exist in the analog raw,
so landing on the parent is what a user wants while the notice explains the rest. The ordering
is part of the ruling: the notice is the LAST thing the command does, because the fall-through
writes the status line, the pane caption and a CIW line of its own, and a notice written before
them is a sentence nobody reads. `FV34`/`FV36`/`FV40`.

> **F1b's OTHER HALF, added by issue 0313 (2026-08-11): the fall-through must have something
> to fall onto.** The refusal reached the notice correctly and still stranded the user, because
> one step earlier `wviewer::browser_reload` had overwritten the browser's whole model
> (`browsersigs` — the tree's node set AND the lower pane) with the empty answer of a REFUSED
> context loan. Tree collapsed to its bare design root, pane emptied, and since that root was
> already the selected row, ttk queued no `<<TreeviewSelect>>` and no click rebuilt it: only an
> unrelated control (the class filter) brought the listing back. It also inverted F5's whole
> point — `browser_sea_draw` writes the sentence into the pane only when the pane has nothing
> to draw, precisely so it reads "the digital pane you asked for is missing" rather than "this
> pane is empty". A refused reload therefore KEEPS the previous snapshot: one skipped refresh
> is what a refusal may cost, never a wiped browser. `FD72` (sabotage S3).

**RULING F1c — the tree is RE-SCOPED to show the digital database, on a positive test, and it
says so.** A VCD is a foreign registry slot, and with the All-DBs box off its rows are not in
the tree at all — so the branch would be dead on a default browser. `browser_show_db_scope`
therefore invokes that checkbutton on the user's behalf, but only after asking the question
that justifies it: does THAT database's own inventory really carry this scope
(`browser_names_under`, literal and case-sensitive, RULING 5c's test)? That is R12's shape
(two-pane item 18) one database over, including its last clause: the outcome is reported
through a new `browser_msg` kind, `alldbs` — "showing every results database to reach <node>" —
so a tree that just grew says why. It deviates from R12 in exactly one place, deliberately: if
the tick did NOT bring the rows in, it is put back, because leaving a box the user did not tick
for a gesture that then failed is a side effect with nothing to show for it. The walk itself
starts at the database's OWN design root (`d:<idx>|g:`), never at the current database's, and
the landing decodes with `browser_id_path` so no `d:<idx>|` prefix leaks into a reported path.
`FD13`-`FD17b`, `FV21`-`FV24`.

**RULING F1d — the notice is RENDERED on three surfaces and lives exactly as long as the pane
it explains.** It is `ase::browser_digital_msg`'s string, which is the resolver's own sentence
with one fixed prefix — nothing in the viewer inspects it, shortens it or picks a different one
(RULING 5f-3; `FD02` fails if `browser_notice` so much as switches on a cause). The three
surfaces are the lower pane's caption, the sidebar status line, and the pane canvas itself —
the last **only** when the pane has no cells, which is the state F5's row is about; the
fall-through case leaves the user on a populated pane, where a notice painted over the names
would be worse than the caption. Lifetime: the next `browser_sea_refresh` clears it, so a
reason cannot outlive the pane it described. `FD20`-`FD22`.

**RULING F1e — THE SUCCESS PATH HAS AN EMPTY PANE OF ITS OWN, AND IT MUST SAY THE TRUE
THING ABOUT IT** (added by the salvage pass, 2026-08-10; MEASURED on the real viewer, not
predicted). When the branch succeeds the tree really does re-scope and the row really is
selected — and the lower pane still lists nothing, because it is drawn from
`browserseaent`, the CURRENT database's entries alone (item 15's declared limit, `BD70d`
in `tests/headless/test_wave_sigbrowser_i14.tcl`). `browser_sea_refresh` then reaches its
shipped `seaempty` arm and captions that pane **"'TOP.m' has no signals of its own"** —
about a scope that has two. So the *happy* path, unarmed, shipped precisely what F5's row
forbids: an empty pane with a WRONG reason, which is item 4's failure mode ("a notice that
describes a different no-match behaviour than the code implements is worse than no
notice") wearing the other sign. Step 7b of `ase::show_in_browser_for_current` therefore
overwrites it, through the same renderer and on the same three surfaces, with a sentence
that says the scope IS shown and that the lower pane reads only the current database.
**That "same three surfaces" is true only because of RULING F1f below — as first shipped
it was true for one event-loop turn and then false.** Three sub-rulings, all deliberate:

* **It is gated on the PANE, not on "the digital branch ran"** — `ase::browser_pane_unread`
  → `wviewer::browser_sea_empty`, which answers `0` ("no claim") for a viewer with no
  window and for a pane state that was never built, never a guessed yes. `FV43` is the
  control that keeps the arm off a pane that is listing signals.
* **"The pane lists nothing" and "a bar is hiding everything" are DIFFERENT FACTS, and the
  reader asks both** (corrected by the review pass). `browsersea` is the FILTERED set, so an
  empty one has two causes; answering "empty" for the second was a guessed yes about a node
  that HAS signals, and it let step 7b replace the shipped and TRUE caption
  `0 of 2 signals (the Search/Filter bar is hiding them)` with a sentence blaming a foreign
  database. `browser_sea_empty` therefore returns 1 only when nothing is drawn AND
  `browser_sea_own` (the UNFILTERED inventory at that level) is also 0 — which is exactly
  the state `browser_sea_refresh` captions with the `seaempty` arm, so the reader and the
  arm it corrects now agree by construction. `FD26`.
* **The sentence is COMPOSED here, not rendered from the resolver** — `nopane`'s reason one
  arm up: the resolver answered `ok`, so there is no resolver sentence to render. 5f-3's
  actual rule is "minted where the fact is decided", and this fact is decided here. The tag
  is `note`, not `error`: nothing failed, the user got what they asked for with a caveat.
  **It names `[lindex $res 2]`, WHERE THE TREE LANDED, never the scope that was asked for**
  (corrected by the review pass): the two differ on a `partial`, and naming the asked scope
  made the notice claim "showing the digital scope 'TOP.m' in the tree" one statement after
  the CIW had said "no signals under 'TOP.m' - showing TOP instead". `FV45`.

`FV41`/`FV42`/`FV43`/`FV44`/`FV45` own the arm, `FD19`/`FD19b` own the FACT on the real
viewer (the pane is empty there, and the same reader answers 0 on the current database's
own root), `FD23`/`FD24` own the whole thing END TO END through the real command, and `FD27` does
the same for F5's own refusal path. Filling
that pane is still F3's — see issue 0308.

> ⚠⚠ **SUPERSEDED IN PART BY RULING F1g (batch F item 7, 2026-08-10), and the part
> that moved is the CAUSE, not the arm.** Everything above about the *shape* of the
> defect stands and is the reason the arm exists. What has changed is that item 7
> (RULING F6) fixed the cause: the lower pane now reads the row's own database, so
> "the pane is drawn from `browserseaent`, the current database's entries alone" is
> no longer true and the sentence that said so was false the moment F6 landed. The
> arm was RE-CAUSED rather than deleted — its predicate was always about the NODE,
> and it now fires exactly when the landing is a pure ancestor. `FD19` was restated
> (the foreign scope's pane lists its two wires), and `FD23`/`FD24` drive the same
> command against the VCD's own ancestor `TOP` so that the ORDERING this ruling and
> F1f are about is still exercised end to end. See RULING F1g under "F6".

**RULING F1f — THE NOTICE MUST OUTLIVE THE REFRESH THAT ITS OWN GESTURE QUEUED** (added by
the review of the salvage pass, 2026-08-10; MEASURED on the real viewer). `browser_reveal`
lands the tree with `$tv selection set`, which only **queues** `<<TreeviewSelect>>`. The
bind runs `wviewer::browser_sea_refresh`, whose FIRST act is `set browserseanote($token) {}`
and whose last act re-captions the pane from the shipped `seaempty`/`seacount` arms — and
that event is delivered on the very next turn of the event loop, i.e. **the instant the
Ctrl-Alt-V binding returns**. Two consequences, both measured, both blockers:

* the F5 notice AND RULING F1e's notice were written and then erased before the user could
  read either. On return the caption held the sentence; one `update` later it read
  `TOP.m has no signals of its own` — the exact falsehood F1e exists to remove — with
  `browserseanote` empty and no canvas note. Only the sidebar status line survived.
* step 7b's own predicate read the pane MODEL that the queued refresh had not rebuilt yet,
  so the arm decided using **the pane the user had just left**: from a settled design root
  (2 signals) it answered "not empty" and refused to fire at all.

**The fix is one flush, at one place: step 6c, `catch {update}`, below every call that can
move the tree and above the notice.** `update`, not `update idletasks` — the virtual event
is on the main queue, and `browser_reveal` already calls `update idletasks` without
delivering it. It is at the tail on purpose: only the notice write follows it, so
re-entering the event loop there costs nothing that is still in flight. `FV46` pins the
position in source; `FD23`/`FD24` drive the real command against a real viewer and read the
caption, the status line and the canvas AFTER the turn of the event loop that the erasure
needs; `FD25` is the tombstone that shows what happens without it.

**What F1 does NOT solve.** F3 (does a digital DB *label* sensibly, do interleaved analog
and digital scopes read well, and can the lower pane read a foreign database at all?) and
F4 (are digital names a new signal class?) are untouched and still open. Three consequences
of the current shape are worth stating rather than discovering: the lower pane's own-level
names still come from the CURRENT database's inventory, so selecting a foreign VCD scope
selects the node but lists nothing under it (F3's business — issue **0308** — and exactly
the state RULING F1e now captions honestly); a `partial` landing that had to tick the
All-DBs box reports `partial` and not `alldbs`, so that one combination grows the tree
without saying so — **filed as issue 0309, and the salvage pass's claim that the
`browser_names_under` gate makes it "near-unreachable" is WITHDRAWN: the review reached it
on the first try with a two-scope VCD and one Filter pattern.** What it is NOT is a
falsehood — `partial` renders "no signals under 'TOP.m' - showing TOP instead", which is
true; the tick is simply unannounced, and RULING F1e's own sentence now names the landing
so the two agree. Fixing the announcement costs a twelfth `browser_msg` kind and a third
`BK33` restatement, which is why it is tracked rather than done here; and the branch
resolves against the viewer's registry BEFORE the
raise, so a Ctrl-Alt-V taken when the viewer has not yet attached this run's databases
answers `notloaded` — with the sentence that says to re-attach them.

#### F4/F3 — the digital signal class and the tree (batch F item 6, 2026-08-10)

**STATUS: F3 and F4 are DONE. All five §F rows are now closed.** What landed:
`wviewer::db_is_digital`, `wviewer::browser_curtype` and
`wviewer::browser_label_of_db` in `src/wave_viewer.tcl`; an optional `dbtype`
parameter on `wviewer::sig_split` and `wviewer::signal_entry`; a `digital` arm in
`wviewer::browser_label`; a `type` key on both of `browser_reload`'s per-database
dicts; and the six sites that build entries or match names now say which database
they are talking about. Pinned by the **FD30-FD48** band of
`tests/headless/test_wave_sigbrowser_digital.tcl` (26 checks — 16 in the
both-arms block, 10 on the real viewer), every one of which is red under at
least one of seventeen sabotages.

---

**RULING F4 — DIGITAL NAMES GET THEIR OWN CLASS, `digital`. Reusing `net` was
not available, and the reason is measured rather than aesthetic.**

The `class` field enumerates `net` | `devnode` | `devmeas` | `srcbranch`. It
gains a fifth value, `digital`, for every name that came out of a database whose
`sim_type` is `vcd`. Such a name is **never declassed**: `sig_declass` does not
run on it at all.

*Which 0217 rulings this depends on, named explicitly:*

* **Ruling A (`signal_entry` gains a `class` field) — DEPENDS ON, and extends.**
  The whole ruling is expressed as a value of that field. Without Ruling A there
  would be nowhere to put the answer and the tree would have to re-derive
  "digital or not" from the name at every consumer, which is the second-parser
  hazard Ruling A exists to prevent. `FD31c` pins that the key **set** does not
  move: `digital` is a value of the shipped fifth key, never a sixth key.
* **Ruling B (device internals hidden by default, behind a toggle) — DEPENDS ON,
  and is the reason reuse fails.** See the measurement below: reusing `net`
  leaves `sig_declass` running on digital names, and the names it mis-tags are
  classed `devnode`, which is exactly what Ruling B's box hides **by default**.
  `digital` is therefore deliberately **not** a device class (`sig_is_device`
  answers 0) and neither of R11's two boxes narrows a digital inventory at all —
  they partition an *analog* raw, and a VCD has no devices for them to talk
  about. `FD32`/`FD37`.
* **"The two panes RELOCATE the noise rather than delete it" (44 → 128 across two
  panes) — DEPENDS ON, as the boundary this ruling must not cross.** That
  redistribution is about *analog* noise and it is unchanged by this item: every
  analog class, path, label and node count is byte-identical
  (`FD32b`/`FD33b`/`FD35`/`FD36b`, and the live control `FD42b` reads the analog
  raw sitting in the same tree). A digital database arrives as its **own
  registry slot under its own header**, so its scopes are additional rows beside
  the analog ones, never mixed into the 128. What the ruling forbids is the
  other direction — *deleting* rows — and that is precisely what reuse did.

*The measurement that forced it* (a two-scope VCD from `fd_mkvcd_m`, whose top
`$scope module m` is legal Verilog and legal VCD; the name that comes out is
`m.sub.sig`):

| | reused as an ngspice name | ruled `digital` |
|---|---|---|
| class | `devnode` | `digital` |
| path | `sub` — **the `m` level deleted** | `m.sub` |
| label | `sig:i` — a wire drawn as a current | `sig` |
| bus bit `m.sub.count[3]` | `count:3` — the **index eaten** out of the brackets | `count[3]` |
| in the tree at the DEFAULT box state | **not present at all**; `time` alone | present |

⚠ **`sig_declass` is sound BY SPICE GRAMMAR AND BY NOTHING ELSE.** Its own ⚠
block says so: a one-letter path segment cannot be a subcircuit instance because
SPICE requires those to begin with `X`. **A VCD is not SPICE.** Verilog places no
such rule on a module or instance name, so the argument that makes the rule safe
on a raw does not survive the crossing, and the tag it "recovers" from a VCD name
is a hierarchy level it just deleted. That single sentence is the whole ruling:
the classifier must be **told** which grammar a name obeys, and it cannot sniff
it — sniffing the name's shape is the mistake `sig_class`'s own ⚠ block
(issue 0217:44, the `#` trap) already forbids in the analog direction.

⚠ **THE CLASS FOLLOWS THE DATABASE, NOT THE NAME.** `TOP.counter.clk` splits
identically under both readings, and it is still classed `digital` (`FD31b`).
Classing only the names that would otherwise be mangled would make the class a
bug-workaround rather than a fact about the signal, and every consumer that
wanted to ask "is this digital?" would have to ask "would it have been mangled?"
instead.

⚠ **`type` STAYS `other`, DELIBERATELY, AND IS A DIFFERENT FIELD.** `sig_type` is
the one classifier behind the Voltage/Current dropdowns and it reads the leading
`v(` / `i(`; a VCD name has neither, so every digital name is `other` and the
dropdowns select it under "Other". Giving digital names a fourth dropdown value
is a separate decision about a visible control and is **not** taken here.
This is why `browser_label`'s digital arm is tested `class` FIRST and not
`type`: the shipped `class eq net && type ne i` test would have dropped every
digital name into the current formatter.

*The mechanism, and the one fact that had to travel:* `signal_list_all` already
reports each registry slot's `type`. What did not exist was that value **inside
the browser** — `browser_reload` built its per-database dicts without it. It now
carries `type` on both the current-DB dict and each foreign one, and
`browser_curtype` is THE ONE read of it (the same single-place-to-sabotage rule
`browser_alldbs` is built on). An unknown token, an absent snapshot or a thrown
`signal_list_all` all answer `{}`, which reads as **analog** — the deliberate
degradation direction, because a guessed "digital" would stop declassing a real
ngspice raw and put `m`, `v` and `@m` back at the top of the tree, undoing
issue 0217 on a guess.

*The matcher subject follows the same rule.* Two-pane item 20 ruled that the
Search/Filter bars match **the label the pane draws**. `sig_match` invokes its
`-key` as a command PREFIX, so the database kind is **curried in front**:
`[list wviewer::browser_label_of_db $type]`, at both production key sites
(`browser_match` and `browser_refresh`'s All-DBs loop) — BD57's argument, one
database *kind* over instead of one database over. The shipped one-argument
`browser_label_of` is kept, unchanged and analog, for callers with no database in
hand; that is every direct unit test of the matcher (`SM29`, `SM30`, `BD57`'s
negative control), and rewriting those five call sites would have moved five
checks for a fact none of them is about. `FD34`/`FD34b`/`FD43`.

**RULING F3 — `db_label` IS ALREADY RIGHT AND IS NOT CHANGED.** A digital
database's tree header reads `counter.vcd (vcd)`: the file tail plus the
engine's own analysis string, which for a VCD is the literal `vcd` that
`vcd_read()` stamps (`src/vcd_read.c:831`). It is distinct from the analog
`tb_ase.raw (tran)` beside it, and it keeps the property `db_label`'s own ⚠
block is about — a space and a bracket, so it can never be mistaken for a
hierarchy segment by `browser_node_for`. The design root under it comes from the
VCD's own file name via `browser_root_label` (`counter`), exactly as a raw's
does. Confirmed as a VALUE by `FD38` rather than by reading the code.

**What F3/F4 do NOT solve — stated rather than discovered.**

* ~~**The lower pane still lists only the CURRENT database**~~ — issue **0308**,
  **CLOSED 2026-08-10 by batch F item 7; see "F6 — the sea has a database
  dimension" below. `FD48` was RESTATED exactly as this paragraph said it would
  have to be.** What follows is item 6's account, kept because it is the
  measurement that scoped the fix.
  Issue **0308**,
  **NOT a blocker for F3, and DEFERRED for a stated reason.** F3's subject is the
  TREE, and the tree half works completely: `m` and `m.sub` are real rows of the
  foreign VCD's own subtree, its wire and its bus bits hang off `m.sub`, and the
  Search bar reaches them (`FD42`/`FD43`). The lower pane is a different surface
  with a different reader — `browser_sea_refresh` draws it out of
  `browserseaent`, which is the current database's entries and only those (item
  15's declared limit, `BD70d`). RULING F4 cannot reach that: the classification
  is already right there, and what 0308 needs is a per-ROW inventory reader,
  which is `browser_sea_refresh`'s business and not the classifier's.
  **0308 is now pinned as a VALUE rather than a claim by `FD48`**, which selects
  a foreign digital scope by hand and asserts that the row's leaves ARE in the
  tree while the pane lists nothing under `m.sub has no signals of its own` —
  0308's own falsehood, reproduced from the digital side. When 0308 is fixed
  `FD48` must be RESTATED, not deleted. Its oracle is sabotage **S17**, which is
  the shape of that fix and reds `FD48` together with five of item 5's notice
  checks — the concrete evidence for 0308's closing line that fixing it also
  retires RULING F1e's arm.
  What this item does add is the other half — with a VCD as the **current**
  database the pane lists its own signals and draws them bare, which is
  `FD44`/`FD45`/`FD46` and is the state a pure-digital run actually produces.
* **Issue 0309 (a `partial` landing that ticked the All-DBs box says so nowhere)
  is NOT a blocker for F3 either, and is DEFERRED.** It is a defect of
  `browser_show_db_scope`'s outcome *sentence* — item 5's F1 territory — and has
  no bearing on how a name is classified or how the tree groups it. Its own fix
  needs a twelfth `browser_msg` kind plus a third restatement of `BK33`'s moving
  `return`-count leg, which its filed text already says is not a one-liner; doing
  it here would be the neighbouring-code fix this item was told not to take.
  ⚠ Worth recording because it changes the odds rather than the code: RULING F4
  **reduces** 0309's reachability for a digital database. `browser_node_for`
  walks the TREE, and before the ruling a VCD's scopes were classed `devnode` and
  therefore absent from the tree at the default box state — so every digital walk
  landed short and took the `partial` arm. With the ruling the rows exist and the
  walk lands (`FD41` asserts exactly that, `ok` rather than `partial`, with device
  internals still hidden). 0309 remains reachable by the Search/Filter route its
  own reproducer uses.
* ~~**`browser_target_path` / `browser_sea_target_path` are NOT digital-aware.**~~
  **NO LONGER A LIMIT — FIXED in the same item's review round, see "The fix pass"
  below.** The limit as first declared was also *understated*: it said the two
  procs "answer the declassed path while the tree's group id says otherwise" and
  dismissed it as harmless, but the measured consequences were a `Descend to
  here` entry left **ENABLED** and then silently doing nothing, and a scope
  selected together with **its own child wire** reported as
  `those rows are in different parts of the hierarchy`.
* **There is no "hide digital internals" control.** A VCD carries every RTL net,
  including ones nobody drew, and no box narrows them. Adding a third checkbox is
  a product decision about a visible control, not a consequence of this ruling.
* **The three new procs are NOT added to `waveform_signal_browser.md`'s contract
  list.** `GS23` in `tests/headless/test_wave_grid.tcl` pins that list's length
  as an exact ledger (57), so adding names to it is a separate, deliberate edit
  with its own check to move; `GS2`'s source→spec roster is hard-coded and does
  not require them. They are documented here instead. **The fix pass adds a
  fourth (`browser_id_type`) on the same terms.**

##### The fix pass — four defects RULING F4's first landing carried in

RULING F4 admitted a **case-sensitive, non-SPICE namespace** into machinery that
had only ever been given ngspice names. Its first landing was correct about the
class, the label and the tree, and wrong in four places that the new namespace
made reachable. All four are fixed; each is pinned as a value by a check that
fails on the pre-fix tree with exactly the value quoted here.

* **RULING F4c — a `digital` entry's path compares CASE-SENSITIVELY.** `-nocase`
  is a fact about *ngspice* (it lowercases, so the raw says `x1.x2` where the
  schematic says `X1`), not a courtesy. Verilog is case-sensitive and
  `vcd_read.c` stores names verbatim, so **`top.mod` and `top.MOD` are two legal
  sibling scopes**. MEASURED before the fix, on the inventory
  `{top.mod.a top.MOD.b}`: `browser_rows` built two distinct groups (correctly)
  while `browser_level_names` answered **both** names for **either** path and
  `browser_sea_own` counted **2** for each — so selecting either scope drew the
  other one's wires under a caption of `2 of 2 signals`. The rule keys on the
  **entry's own `class`**, never on a database argument, because an entry list is
  the only thing `browser_level_names` is ever given. `browser_names_under`
  already ruled this exact point the same way; the reasoning simply had to travel
  with the names. **`FD49`/`FD50`, both directions in one tuple** — the ngspice
  control leg is load-bearing, because `TP16` pins `X1` finding `x1` and a fix
  that merely made the compare case-sensitive would red a shipped check.
* **RULING F4d — a leaf row is split with ITS OWN database's grammar, and the
  *current* database's kind is not that answer for the tree.** The tree is the
  one surface holding several databases at once (item 14), so "which grammar do
  this row's names obey" is a **per-row** question. A new pure resolver
  `browser_id_type {token id}` answers it out of the snapshot `browser_reload`
  already takes, degrading to analog for an unknown row — the same deliberate
  direction the current-kind reader documents. MEASURED before the fix, on
  `m.sub.sig`: group `ok m.sub`, its own leaf `ok sub`, the two together
  `err {those rows are in different parts of the hierarchy}`.
  ⚠ **Currying the current kind here would have been the mirror defect, not the
  fix**, and that is measured too: sabotage `T6` (force `vcd`) makes the current
  ngspice raw's device leaf answer `ok m.x1.xm1` instead of `ok x1.xm1`. The
  **lower pane** has no such question — it draws the current database's entries
  and only those (item 15's declared limit) — so `browser_sea_target_path` is
  told the current kind directly. **`FD51`/`FD52`, plus `FD54`/`FD55` on the real
  tree and the real pane.**
  ⚠ **THAT LAST SENTENCE STOPPED BEING TRUE ON THE SAME DAY — see RULING F6.**
  The pane now draws whichever database the selected ROW belongs to, so it has
  exactly the per-row question the tree has, and `browser_sea_target_path` is
  told the PANE's row instead of the current kind. The two answers coincide for
  every state that existed before F6, which is why `FD52`/`FD55` are unmoved;
  `FD56` is the state that separates them.
* **An unreachable node is SAID, not swallowed.** `browser_sea_descend_to`'s
  "no such row" arm used to `return 0` in silence while the menu entry above it
  is built ENABLED on `ok` alone — so `Descend to here` did nothing and explained
  nothing. A Filter that hides the scope is a real way to reach that state, so it
  gets a sentence rather than a stricter gate. A **literal string, not a twelfth
  `browser_msg` kind**: that proc's arms are the scope-change vocabulary and its
  `return` count is pinned as a ledger (`BK33`). **`FD52b`.**
* **RULING F4b — in shell syntax, typing exactly what the pane draws always
  finds it.** Two-pane item 20 made the bars match the **label**, and RULING F4
  made a digital bus bit draw `count[0]` (correctly — the pre-ruling label was
  `count:3`, with the index eaten). But `[0]` is a glob character class, so
  MEASURED after that landing: `sig` found the wire, `count` found the bare bus,
  and **`count[0]` — the exact string on screen — found nothing**. On a digital
  database that is the majority of names. It is not purely digital either: an
  ngspice design net `v(x1.count[3])` has drawn `count[3]` since item 20 shipped
  and typing it has never worked.
  **The fix does not change what a glob means.** The glob is tried first and
  unchanged; an exact whole-subject equality is tried second, so the match set
  can only *grow*, and it grows by exactly the string the user can see.
  ⚠ The obvious alternative — quoting the metacharacters — was measured and
  **rejected**: with the subject quoted, `*net_name[[]*` finds nothing, which
  reds `SM07`, whose whole subject is that `[[]` is the escape for a literal `[`.
  Quoting the pattern destroys every wildcard. `SM06` (a bracket range), `SM07`
  and `SM19` (a lone `[` is a no-match, not an error) all still hold, because no
  signal is literally named `net[0-9]` or `[`. **Shell only** — `-syntax regexp`
  is the explicit power-user mode where a metacharacter is what the user came
  for, and it keeps `count\[0\]` as the exact-match escape hatch. **`FD53`.**

#### F6 — the sea has a database dimension (batch F item 7, 2026-08-10)

**STATUS: F6 is DONE. Issue 0308 is CLOSED and `BD70d`'s declared limit with it.**

**RULING F6 — THE LOWER PANE RESOLVES A ROW IN THE DATABASE THE ROW NAMES, NOT IN
WHICHEVER ONE HAPPENS TO BE CURRENT.**

Two procs conspired to make this a *silent wrong answer* rather than a missing
feature, and the order matters:

1. `browser_reload` snapshotted the inventory of the current database alone —
   `browsersigs` — and `browser_refresh` turned it into the one entry list the
   pane was ever drawn from, `browserseaent`.
2. `browser_id_path` stripped the `d:<registry idx>|` prefix and returned the
   bare path. **The one fact that said where to look the path up was discarded
   at the first step of the lookup**, so what remained resolved in the only
   inventory there was.

So a foreign row's path was looked up in the current run's names. The browser did
not error and — where the two databases shared no path — it showed nothing, which
is what issue 0308 recorded. **Where they collide it shows the wrong run's
signals, with the right count and the right caption.** MEASURED, `FD61`, two
databases that each own the path `x1`:

```
                          shipped              ruled
foreign d:1|g:x1   {same onlyraw}       {same onlyvcd}      <- the VCD's own
current      g:x1  {same onlyraw}       {same onlyraw}
caption, both      2 of 2 signals       2 of 2 signals      <- identical either way
```

and one gesture further on, `FD62`: a Plot out of that pane sent
`{v(x1.same) v(x1.onlyraw)}` — the current raw's names — because the pane's
model held them.

**What the ruling changes, and the shape it is spelled in:**

* **The decode answers both halves.** `browser_id_split {id}` → `{<db> <path>}`
  is now the ONE decode; `browser_id_path` and `browser_row_db` are its two
  one-line projections, so they cannot drift about what a prefix is (they were
  two copies of one regexp with a comment asking the reader to keep them equal).
  `browser_id_path`'s signature and answer are unchanged to the character —
  `TP44` counts its call sites in `browser_target_path` and `browser_show_path`
  as a frozen 1/1. **`FD59`.**
* **The sea snapshot gains a per-database map**, `browserseadbent($token)`:
  `d:<idx>` → that foreign database's bar-matched, class-filtered entry list,
  written by `browser_refresh`'s All-DBs loop **in the same pass as the tree
  group it describes**, so the pane can never list a set the tree does not show.
  It is emptied at the top of every refresh — a slot carried over from a database
  that has since been closed is the same wrong answer one refresh later
  (`FD60`'s last leg).
  ⚠ **It is a SECOND array and not an extra key inside `browserseaent`.**
  `browserseaent` *is* the current database's list and a dozen readers take its
  `llength` as "how many signals the pane can draw"; widening that value would
  move every one of them for a fact none of them is about.
* **Every reader and every gesture is told the row.** `browser_sea_ent`,
  `browser_sea_own`, `browser_sea_label` and — through `browserseadbid`, the row
  the pane was last drawn for — `browser_sea_target_path`, `browser_sea_plot_idx`,
  `browser_sea_root_id` (RULING F6a) and `browser_sea_send_to_add_trace`
  (RULING F6b). The `id`
  argument is OPTIONAL and defaults to the current database on all of them, so
  every pre-F6 call site and the whole shipped `BQ`/`FD4x` band keeps its exact
  meaning by construction.
* **A slot the snapshot does not carry answers NOTHING — never the current
  database's entries.** That is issue 0308's lesson read in the right direction:
  *absent* is a state the caption can describe truthfully, *someone else's
  signals* is not. `FD57`.
* **The pane's Plot arms the row's database**, through the same
  `plot_dbs_arm`/`plot_dbs_take` band the tree's plot route has used since spec
  §D1's DEFECT 2. It could not need it before, because the pane could only ever
  hold current-database names. `FD62`.

**THE FIX PASS (same day, three findings against F6's first landing).** The first
landing made the *readers* database-aware and left three of their *consumers*
behind. All three are the same mistake — a database identity rescued in one proc
and discarded in the next — and the rulings are here because each had a
defensible alternative that was rejected:

* **RULING F6a — `Descend to here` out of the pane walks the ROW'S OWN
  database's subtree.** `browser_sea_target_path` answered in the row's database
  and handed the path to `browser_node_for … [browser_root_id $rows]`, which is
  hard-wired to the CURRENT database's root (`g:`, or `d:0|g:` under All-DBs).
  The item made this WORSE than it found it: before F6 the resolver errored on a
  foreign pane and the menu entry was DISABLED, after it the entry is ENABLED and
  the walk starts in the wrong tree. MEASURED both ways — with a foreign scope the
  current run does not carry, the user was told *"'TOP.dcell' is not in the Signal
  Browser tree"* about `d:1|g:TOP.dcell`, a row of that very tree; with the two
  databases colliding at `x1` the walk silently resolved to the CURRENT database's
  `g:x1`. `browser_sea_root_id` is the one-line projection that fixes it.
  **The rejected alternative** was to make `browser_sea_target_path` return `err`
  for a foreign row so the entry went back to DISABLED. It is rejected because the
  TREE's own `Descend to here` has descended from foreign rows since item 14 —
  `browser_target_path` resolves any `d:N|` group id — so refusing in the pane
  would make two entries in one window disagree about whether a foreign row can
  be descended from. ⚠ A slot with no root row in `$rows` still answers `d:N|g:`
  and never `{}`: `{}` is `browser_node_for`'s TOP LEVEL, i.e. the current
  database's unprefixed rows, which is the fallback that made the defect.
  `FD65` (the refusal case) and `FD66` (the collision). 
* **RULING F6b — `Send to Add Trace…` out of the pane carries the row's database
  too, and it carries the NAME with it.** The sibling entry in the same context
  menu prefilled a bare name into a dialog whose OK resolves names through
  `resolve_signal_db`, so on a colliding pair one entry landed on the run the user
  pointed at and the one below it on the current run, silently. The arm is
  `atddb($token)` = `{<the prefilled name> <registry index>}` — `plot_dbs_arm`'s
  shape, one dialog over — cleared when `add_trace_dialog` opens, CONSUMED by
  `add_trace_ok`, dropped with the dialog and with the window. ⚠ **The name is
  half the arm** because this dialog is *modeless and meant to be edited*: the
  index is honoured only while the Expression text is still byte-for-byte the one
  it was armed with, and `add_trace`'s 6th argument overrides the name search
  ENTIRELY, which is right for a pointer and wrong for anything typed over it.
  `FD67`, `FD68`.
* **The mechanism sentence was wrong even where the conclusion was right.**
  `resolve_signal_db` does NOT return the lowest-index match: `signal_list_all`
  yields the CURRENT database first and the first hit is returned, so its
  tie-break is "the current DB wins" (its own ⚠, and `db_by_index`'s, say so).
  Lowest-index is the rule only AFTER the current database has refused the name,
  which is the §D1 / DEFECT 2 case above and where that phrasing is correct. The
  conclusion — an unarmed plot of a foreign name silently draws the current run's
  namesake — is unchanged.

**RULING F1g — RULING F1e's ARM IS RE-CAUSED, NOT DELETED**, and this is taken
deliberately **against issue 0308's own closing suggestion**, which said the arm
"should be DELETED". The evidence that changed the answer:

* The arm's **predicate** was never about the database. `browser_sea_empty` asks
  whether the selected NODE has anything to list, and RULING F6 makes it ask that
  of the node's own database — so it now fires exactly when the landing is a
  **pure ancestor**, which every `partial` landing is.
* Its **sentence** was about the database, and that half is now false. It read
  "…but the lower pane lists only the current results database, so this scope's
  own signals are not in it yet". It now reads "…but that scope has no signals of
  its own - open one of its sub-scopes to see any".
* **Deleting the arm would restore the contradiction it was minted to remove.**
  FV45's own ⚠⚠ block already argued this from the other side: on a `partial`
  the shipped `seaempty` caption says "'TOP' has no signals of its own" and never
  says that the digital show SUCCEEDED, which scope was asked for, or which run
  the tree landed in. The arm supplies all three. What it must not do is name a
  cause that has been fixed.

Pinned by `FD23`/`FD24` (the real command, the real viewer, one event-loop turn
after the binding returns, on the VCD's own ancestor `TOP`) and by `FV42` leg 3.
`ase::browser_pane_unread` and `wviewer::browser_sea_empty` keep their callers
and `FV43`/`FV44` keep their subjects.

**Declared limits, stated rather than discovered:**

* **A foreign database's pane is what the BARS left of it**, because a foreign
  database's *tree* already is (two-pane item 15's declared asymmetry,
  `BD51`/`BD51b`) — §7.1's "the tree is the bar-UNFILTERED set" governs the
  CURRENT database only, and this ruling does not change which side of that line
  a foreign inventory sits on.
* **The own-level count for a foreign row uses that database's UNFILTERED
  inventory**, exactly as the current database's does, so §7.2's three states
  (`seaempty` / `seabars` / `seaclass`) mean the same thing on both.
* **The TREE's own `Send to Add Trace…` (`browser_send_to_add_trace`) still hands
  a bare name onward.** It has the row's database in the id it was given and does
  not use it, so a foreign leaf sent to the dialog resolves by name exactly as it
  did before this item. That is a PRE-EXISTING gap of spec §D1's DEFECT 2 (item
  14 could already put foreign leaves in the tree), not one F6 created, and it is
  left standing deliberately rather than widened into this item. The arm F6b adds
  is the machinery it would reuse.
* **The class filter reaches a foreign database's PANE, not only its tree.**
  `browserseadbent` is written from the post-`browser_class_filter` list in the
  All-DBs loop, so `Show device internals` hides a foreign run's device node in
  the pane exactly as it does in the tree beside it, and §7.2's denominator stays
  the UNFILTERED own-level count (`1 of 2 signals`, not `2 of 2`). `BD58d` /
  `BD58e` — and it needed an ANALOG foreign database to reach at all, because
  RULING F4 makes `browser_class_filter` a no-op on digital names.
* **`browser_sea_empty` still re-derives the row from the treeview**, while the
  pane's two gestures read `browserseadbid`. They differ only in a window where
  a selection has changed and its refresh has not been delivered; a gesture must
  act on the cells the user can see, and the reader is consulted only right after
  a settle (RULING F1f).
* **Issue 0309 is untouched and still open.** It is a defect of
  `browser_show_db_scope`'s outcome *sentence*, needs a twelfth `browser_msg`
  kind and a third restatement of `BK33`'s moving `return`-count leg, and this
  item does not make it worse: `browser_msg`'s return count is unmoved at 11 and
  no `browser_say` arm changed.

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
| H2 | ~~Golden mixed-signal run end-to-end~~ **DONE 2026-08-11 (batch F item 11).** `tests/headless/test_cosim_golden_e2e.tcl`, **46 checks**, in `full_audit.sh`'s `--nogui` arm, golden at `tests/headless/gold/cosim_e2e_counter.golden` (**72 records**). It is the only test in this family that runs no synthesized fixture at all: `xschem netlist` of the reference `tb_counter_wrapper` → `ase::cosim_map` → `ase::cosim_build` (real `tools/cosim/build_cosim_so.sh`, verilator 5.020 + g++, ~9 s) → `render_deck` (which rewrites `sim_args` to a bare lower-case basename) → `ngspice -b` (~2.6 s) → the patched shim's VCD → `ase::attach_dbs` → the six INTERNAL signals read back through `xschem raw` and compared record-for-record with the golden. **The shipping configuration, asserted, not assumed:** `GE11`/`GE13`/`GE16` pin trace-on, no `-t` on any `src/ase.tcl` build path (item 12, `1e5c2b64`) and `trace 1` in the `.so` stamp. **THE GUARD IS PART OF THE DELIVERABLE.** The end-to-end arm skips when `verilator`, `ngspice`, the reference library or the build script is absent, and it skips by printing `note: group GE not run -- absent: …` — **never** `RESULT: SKIP` / `skipped: no X` / `SKIP: no X connection`, because `full_audit.sh:128` scores the WHOLE FILE as SKIP on those substrings and would discard every `GG` check that had already passed. Measured both ways on this box with a shadow `PATH` that omits verilator: guard present → the file prints `note: group GE not run -- absent: verilator` then `RESULT: ALL PASS (15 checks)`, and `full_audit` scores `PASS \| test_cosim_golden_e2e` / `SUMMARY: 1 pass 0 fail 0 crash/timeout 0 skip`; guard deleted (`if {[llength $missing]} {` → `if {0} {`) → **15 red** (`GE14 GE15 GE16 GE18 GE20 GE21 GE22 GE23 GE24a GE24b GE24 GE24c GE25 GE26 GE27`), the file still prints `RESULT: 15 FAILED (31 passed)`, and `full_audit` scores it **FAIL**, never crash/timeout — the file's own guards keep it *reporting* even with every downstream artifact absent. The `GG` group (15 checks) is deliberately verilator-independent and pins the comparator itself: a corrupted value, a missing record, an extra record and a moved edge are four distinguishable reports, and an EMPTY measurement is 72 `MISSING` reports, not silence. **A BROKEN GOLDEN MUST FAIL, NOT CRASH (ruled 2026-08-11, batch F item 11 review):** the same silent-discard hazard the skip-banner rule exists to prevent is reachable through the golden itself, which the golden's own header invites a reader to regenerate by hand. `gold_parse` therefore catches `llength` (a line with an unbalanced brace or quote is not a valid Tcl list and *throws*, aborting the file before one check reports); the `GG11`/`GG14` perturbations are gated on `[llength $GOLD] > 1` while their checks stay ungated so they FAIL rather than abort; and `GG3`/`GG5`/`GG10` require `[llength $GOLD] > 0`, because "zero bad lines / no ports / identical compares equal" are all true of a golden that is not there. Measured, shadow `PATH`: golden absent → `RESULT: 13 FAILED (2 passed)` and `full_audit` `FAIL` (before the guards: no `RESULT:` line at all, scored crash); golden with one unbalanced-brace record appended → `RESULT: 4 FAILED (11 passed)` with `GG3` red at `badlines=1` (before: aborted inside `gold_parse`). **`GE10` PLANTS A DECOY (same review):** the run directory is a per-pid `test_scratch` dir this run just created, so `![file exists $vcdf]` was true *before* `ase::cosim_clear_artifacts` was called and the check passed identically with the clear stubbed out or its call site deleted. It now writes a stale file at `$vcdf` first and asserts both that the file is gone **and** that the returned `gone` list NAMES it. |
| H3 | ~~Time-base regression: an edge at a known SPICE time must land at the same time in both DBs (A6/D3).~~ **DONE.** `tests/headless/test_vcd_time_base.tcl`, **124 checks**, `--nogui` arm, 19 sabotages all caught. Fixtures are synthesized (an ASCII spice raw and a VCD encoding the SAME edge, ~15 lines of generator each, the `mkraw`/`mkvcd` idiom from `test_ase_cosim.tcl`) — **no simulator is run**. Groups TB (six units, both DBs in the registry at once), LD (the unit ladder, each rung exactly 1e3), NC (nine negative controls that ARE 1e3 wrong and must be rejected by the same gate), SE (seconds not ticks; multiplier forms), RW (the raw side is not rescaled either) and REF (the real §A6 pair, guarded, and it prints no banner `full_audit` would score as a file-wide SKIP). Tolerance and margins: see the D3 row. |
| H4 | ~~Scope-mapping test for F2~~ **DONE** — the **FS** group of `tests/headless/test_ase_cosim.tcl` (46 checks, 32 sabotages, every check red under at least one). `x1.a1` resolves to an absolute `(database, scope)` pair with three VCDs and the analog raw all loaded and the ANALOG one current, so the resolver has to reach a database that is not the current one (`FS30`-`FS33c`). The checks that carry it are the DIVERGING ones — a recorded hint naming a scope the loaded VCD does not declare (`FS34`-`FS37b`), a hint that differs only in CASE (`FS23`), and one where nothing matches at all (`FS38`/`FS39`) — because the agreeing case passes against an implementation that simply trusts the string. **Two `d_cosim` instances in one deck is the `multi` case**, produced for real through `xschem netlist` at `DS9`-`DS11` and refused by the resolver at `FS41`; a genuine two-CELL collision is `FS10` (rung 1 picks one where a bare cell key matches both) and `FS14` (a rung matching >1 refuses without falling through). Not covered: a really inlined VCD — so the divergence fixtures hand-write the map entry. (The FS group's own note that there is "no verilator on this machine" was **wrong when written and is corrected here**: `/usr/bin/verilator` 5.020 is installed, which is what H2 above now uses. What FS still cannot produce is a *digital compile that really inlines a module away*, which is a property of the Verilog, not of the toolchain.) **THE TWO-INSTANCE HALF IS THE `TD` GROUP, ADDED 2026-08-11 (batch F item 11): 23 further checks in the same file, 333 total.** FS resolves one instance at a time, and with one instance any lookup returns the only answer there is — a `cosim_map_match` that ignored its arguments and answered `[lindex $map 0]` passes all 63 FS checks (measured: sabotage `S1` reddens 9 FS checks but every FS *end-to-end* resolve still answers `ok`). TD is the fixture that can fail: one testbench, four instances, three `.model` cards, the map produced by a real `xschem netlist` + `ase::cosim_map` rather than hand-written. Its discriminators are (a) `a1`/`a2` are DIFFERENT cells whose `.v` files declare the SAME module `tdmod`, so `cosim_map` mints IDENTICAL hint strings for both (`TD3`) and rung 3 is ambiguous over the real map (`TD6`) — only rung 1's lib/cell key separates them. **`TD7`/`TD8` do NOT establish that on their own, and saying so is the ruling (2026-08-11, batch F item 11 review):** they assert the rung *number*, and in this fixture the three `.model` card names separate the entries exactly as well as lib/cell does, so a rung 1 re-keyed onto the model card name (`$ed eq $fd` in place of the lib/cell predicate) still answers `mdx 1` and `mdy 1` — measured, that sabotage reddened 5 `FS` checks and **not one** of the 21 TD checks. `TD7b`/`TD8b` name the KEY rather than the rung: one `f1` carrying **no model card name at all** (lib/cell alone must still answer `mdx 1`; a model-keyed rung 1 has nothing to match and falls through to the rung 3 `TD6` already proved ambiguous), and one whose model card **deliberately contradicts** its lib/cell (`dlib/tdy` + `model mdx` → `mdy 1`, so the answer says which key the ladder used). (b) `a2`'s database does not declare the hinted `TOP.tdmod` at all, it declares `TOP.wrapy.tdmod`, so the two instances must land in DIFFERENT databases (`TD12`, which a first-match resolver fails) with DIFFERENT scopes (`TD13`, which a hint-trusting resolver fails); (c) `a3`/`a4` are two instances of ONE cell, which the netlister folds into one card, so lib/cell cannot separate them even in principle and the ruled answer is the `multi` refusal for BOTH (`TD20`/`TD21`) while `a1` still resolves in the same breath (`TD23`). 15 sabotages; 22 of the 23 TD checks go red under at least one (`TD7b`/`TD8b` under the model-keyed rung 1 above and under first-match `P1`), and `TD16` is declared a FIXTURE PREMISE (it asserts the fixture VCD's own scope tree) rather than counted as evidence. `TD17` had to be MOVED above `TD16` to be evidence at all: below it, `TD16`'s own `raw switch 0` restored slot 0 by hand and the check was green with the inventory's restore deleted. |
| H5 | ~~View-model tests~~ **DONE.** `tests/headless/test_verilog_view_model.tcl`, 109 checks: `view_type` / `view_handler` (including both open paths driven for real) / `library_new_view` / `library_new_cell` / the seed template / `lib_qualified_abs` / `cellview_sibling_path` / the Alt-2 candidate model, over `verilog` and `veriloga`, in both the nested and the flat layout, plus the measured repro against the reference cell. |
| H7 | ~~Browser-branch tests for F1/F5~~ **DONE 2026-08-10 (batch F item 5).** TWO files, split by ARM and not by topic: the **FV** group of `tests/headless/test_ase_cosim.tcl` (46 checks, `--nogui`) owns the branch — which cell enters it, which sentence each cause produces, and a LIVE assertion that f1 is read before `wviewer::open` moves the context; `tests/headless/test_wave_sigbrowser_digital.tcl` (**FD**, 25 checks, Tk/X arm, auto-enrolled by `full_audit.sh`'s `ls test_*.tcl`) owns the viewer half, which needs a treeview, a checkbutton, a canvas and a status label and therefore cannot live in the engine arm at all. Fixtures are synthesized (`mkraw`/`mkvcd`); no simulator runs. **SABOTAGE — the numbers here are the SALVAGE PASS's, re-measured one patch at a time; the first attempt's claim of "33 injected, 31 caught" died with its author and is not evidence.** 54 patches were applied and reverted from a byte-exact backup (md5-verified after every restore), and **all 65 checks that pass owned — 44 FV, 20 FD and `BK33` — went red under at least one**: FV 44/44, FD 20/20, BK33 under the `alldbs`-deletion patch. **The REVIEW-FIX pass (RULING F1f) then added `FD23`-`FD27`, `FV45` and `FV46` and re-sabotaged every check whose subject it had changed** — 13 further patches (`S1`-`S13`), each applied alone and reverted from a byte-exact backup, and every one of the seven new checks plus the seven re-aimed ones (`FD03`, `FD19`, `FD19b`, `FD22`, `FV41`-`FV43`) went red. The item's own total is now **72 checks — 46 FV, 25 FD and `BK33`**. Two patches reddened nothing and both are named in the receipt: `S04` (deleting the probe's empty-selection and empty-f1 guards) is defence in depth, not a hole — the `vfile` gate below them refuses the same inputs, and `S04b`, which removes all three guards, reddens `FV4`/`FV5` as they claim; `S24` was mis-aimed by its author and `S24b` does the intended move and reddens `FV34`/`FV40`. |
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
                                                 notloaded|notread|noscope|ambiguous
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
   inventory. Absent → `notloaded`. **Registry not READABLE → `notread`, never `notloaded`**
   (5f-7): the inventory reports `refused` when the viewer's context loan was refused, and that
   is a different fact with different advice.
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
  the honest case: with nothing loaded the direct path reports `{}` by itself.
  **⚠ HALF OF THIS RULING WAS OVERTURNED BY 5f-7 — the fall-through is right for the STALE
  token and wrong for the REFUSED ticket.** The evidence sentence moved with it: the
  surviving half (an unknown token still falls through) is pinned by `FS50` and by
  `FS51-unknown-viewer-token-falls-back`; the overturned half is pinned the other way up by
  `FS51b`-`FS51h`, which require a refused loan to answer `notread` and never fall through.
* **5f-7 (issue 0314, measured) — a REFUSED loan does not fall through, it gets its own cause
  `notread`.** 5f-5's fall-through reads *the current context's* registry, and its safety
  argument ("the direct path reports `{}` by itself when nothing is loaded") holds only where
  the current context is the **viewer**. On the gesture path the current context is the **design
  window**, which structurally never has databases — so the fall-through converted "I could not
  ask" into "there are none", and the resolver told the user to run a simulation whose results
  were attached and listed one window away. Which is not hypothetical: it was the *default*, not
  an edge case, because `callback()` holds `xctx->semaphore` for the whole of every gesture and
  `switch_window`/`switch_tab` refuse a context switch while it is raised, so **every** loan
  taken from a keystroke was refused and **every** loan typed into the CIW succeeded. The
  registry readers now report `ok`/`refused`/`unknown`; `refused` returns immediately with that
  status (only the honest empty and the stale token still fall through — and a THROW is counted
  as a refusal too, since the `catch` that guards the call would otherwise turn it into the
  honest empty), and step 4 mints `notread`. **Its sentence says only what a refusal
  establishes**: `refused` is the union of "busy", "the window is mid-alloc/teardown" and "the
  target window is gone", so naming one of them as fact would be `notloaded`'s overreach one
  step smaller — it reports that the registry could not be read, that the file could not be
  *confirmed* loaded, and asks for the gesture again. The **loan itself** is also fixed, so on
  the gesture path this cause is now rare rather than universal: `wviewer::enter_ctx` retries
  the switch with the frame's own semaphore temporarily lowered, **at `semaphore == 1` and only
  for a caller that opts in**. Both conditions are load-bearing: `>= 2` is callback.c's own
  "busy" convention (recursive callback, modal dialog, placement in flight) and keeps its
  refusal, while `== 1` alone does NOT identify a gesture — `ase::wait` holds exactly 1 across a
  `vwait` that pumps the event loop, and `destroy_all_windows` holds it around a `tk_messageBox`
  — so only `signal_list`/`signal_list_all`, whose bodies read and restore and run no
  `update`/`after`, ask to borrow. `in_ctx`'s caller-supplied body never does. Pinned by
  `FS51b`-`FS51h`, `FV10b`/`FV11b`/`FV18` (headless) and `FD70`-`FD74` (the Tk/X arm, including
  the chord driven through the canvas binding's own C entry point); receipt
  `doc/claude/batch_F/receipts/14-0314-0313-gesture-context-loan.md`, which also declares the
  follow-up: a positive gesture-frame flag exported from callback.c would replace the value
  test entirely.
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
