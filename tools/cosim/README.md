# tools/cosim — building `d_cosim` shared libraries, with internal-signal VCD

Supporting tooling for mixed-signal simulation: an ngspice/XSPICE analog deck
co-simulating a Verilog block through the `d_cosim` code model, with the Verilog
block's **internal** signals dumped to a VCD.

Design context and the full work list: `doc/claude/specs/mixed_signal_signal_browser.md`.

## Contents

| path | what |
|------|------|
| `build_cosim_so.sh` | builds `<cell>.so` from `<cell>.v` via Verilator. Replaces ngspice's `vlnggen`. |
| `src/` | copy of `/usr/local/share/ngspice/scripts/src/`, with `verilator_shim.cpp` patched to emit a VCD. Every patch is marked `XSCHEM PATCH`. |

## Quick start

```sh
# no VCD — ports only, stock ngspice shim
tools/cosim/build_cosim_so.sh -o <rundir> path/to/counter.v

# with VCD of the design's internals — uses the patched shim in src/
tools/cosim/build_cosim_so.sh -V -o <rundir> path/to/counter.v
```

The `-V` build writes its VCD to the path named by the `.model` card's
`sim_args`, so two `d_cosim` instances in one deck do not overwrite each other:

```spice
.model counter d_cosim simulation="./counter.so" sim_args=["counter.vcd"] delay=0
```

`./counter.so` is resolved against ngspice's **working directory**. `ase::run_deck`
does `cd $rundir` before launching, so building into the rundir is correct.

## Why not just use ngspice's `vlnggen`?

**It cannot work on ngspice-46.** In script-file mode the interpreter lowercases
every literal token on the line. Measured 2026-08-08:

```
$ printf '*ng_script\necho BARE_UPPER\nsetcs v="X_UPPER"\necho $v\n' > s
$ ngspice s
bare_upper
x_upper                 <- even setcs values are downcased
```

The same commands typed interactively keep their case, so this is specific to
script-file input. `vlnggen` depends on case in at least four places — `--Mdir`,
`--prefix Vlng`, the `VL_IN`/`VL_OUT`/`VL_INOUT` scan of `Vlng.h`, and the
`VL_DATA(...)` lines it echoes into `inputs.h`/`outputs.h`/`inouts.h` — so it dies
at the first verilator call:

```
%Error: Invalid option: --mdir... Suggested alternative: '-Mdir'
```

`build_cosim_so.sh` performs the same four steps directly in `sh`:

1. `verilator --Mdir <objdir> --prefix Vlng --cc <src>` — generate C++ so `Vlng.h` exists.
2. Scan `Vlng.h` for `VL_IN<n>(&name,msb,lsb);` and friends → `VL_DATA(n,name,msb,lsb)`
   lines in `inputs.h` / `outputs.h` / `inouts.h`. **Order is the wire protocol**:
   the port index `d_cosim` passes to `in_fn`/`out_fn` is an offset into these
   tables, so the file order must match the module's port order.
3. Rebuild with `--build --exe`, adding `verilator_main.cpp` and `verilator_shim.cpp`
   (Verilator only compiles when asked to build an executable).
4. `g++ --shared` the shim + runtime objects + `Vlng__ALL.a` into `<cell>.so`.

Step 4 is also where `vlnggen`'s second defect lives: a `--trace` build emits
`verilated_vcd_c.o` as a **global** object, not inside `Vlng__ALL.a`, and
`vlnggen`'s hardcoded object list omits it. This script adds it when present.

## What the shim patch does

Stock `verilator_shim.cpp` never creates a trace object — no `VerilatedVcdC`, no
`open()`, no `dump()` — so `--trace` alone produces nothing. Only module **ports**
cross the `d_cosim` boundary, and ngspice's raw file cannot hold event nodes at
all, so without this patch a code block's internals are invisible to everything
downstream.

Patches, all marked `XSCHEM PATCH`:

- **Trace object.** `Verilated::traceEverOn(true)` before model construction,
  `topp->trace(tracep, 99)` for full hierarchy depth, `open()` on the `sim_args`
  path, and `pinfo->cleanup = ng_trace_cleanup` so `close()` runs — without it the
  VCD is truncated.
- **`dump()` in both `step()` variants.** The non-timing path dumps at
  `pinfo->vtime`; the `--timing` path dumps at each Verilog event time
  (`next * tick`) rather than at the SPICE target, because one SPICE timestep can
  contain several internal events and dumping only at the target collapses them.
- **Monotonicity clamp.** `VerilatedVcdC::dump()` requires non-decreasing time.
  With `method == After_input` ngspice calls `step()` repeatedly at the *same*
  `vtime`, and on a rejected timestep it can call with an earlier one — the
  condition behind ngspice's `"XSPICE time is behind vtime:"` diagnostic. The
  shim clamps rather than trusting the caller.
- **Context lifetime.** Upstream declares `const std::unique_ptr<VerilatedContext>
  contextp` as a local in `Cosim_setup()` and lets it die at function exit while
  the model keeps a raw pointer to it — so the `--timing` `step()` calls
  `topp->contextp()` on freed memory. The patch releases ownership so the context
  lives for the process. This is an upstream bug (spec M15).

  **It is not the trace setup that needs this** — that was the old, wrong
  reason. Every use of the local `ctx` is inside `Cosim_setup()` itself, where
  the `unique_ptr` is still alive, so `contextp.get()` would have served the
  tracer just as well.

  **Re-apply this hunk in every build you make.** Grepping for `ctx` answers a
  narrower question than "who reaches the context": two aliases of the same
  object outlive the function and both are dereferenced afterwards.
  `topp->contextp()` is the one the `WITH_TIMING` `step()` uses, and that arm is
  only compiled with `-t`. The second alias has no `-t` condition at all:
  `Verilated::threadContextp()` is a thread-local that the `VerilatedContext`
  constructor points at itself and its destructor never clears
  (`verilated.cpp:2421`, `:2434`), and the *generated* model dereferences it
  inside `topp->eval()` whenever the user's Verilog uses `$time`, `$display`
  with `%t`, `$finish`, `$stop` or `$fatal` — `VL_TIME_Q()` is literally
  `Verilated::threadContextp()->time()` (`verilated_funcs.h:302`) and
  `vl_finish()` calls `gotFinish()` on the same pointer (`verilated.cpp:113`).

  So the `release()` is load-bearing in **every** build, including the shipped
  non-timing one, and it costs one leaked `VerilatedContext` per process.
  Measured 2026-08-10 with the `release()` neutered and no `-t`: a counter doing
  `$display("t=%t", $time)` faults under AddressSanitizer with
  heap-use-after-free in `VerilatedContext::time()` under `Vlng::eval_step()`.
  The older "byte-identical VCD, clean valgrind" result is real but narrow — it
  was taken on `xschem_library/ngspice_verilog_cosim/counter.v`, whose `$display`
  has no `%t` and which never calls `$finish`, so it reaches neither alias. Do
  not conclude "inert" from a run of that file.

## What we actually ship: never `-t`; `-V` unless `cosim trace 0`

`ase::cosim_build` assembles the command line as `<script>` + `-V` + `-o
<rundir> <vfile>`. The two halves of that are **not** equally unconditional, and
conflating them is easy:

- **`-t` is never passed, on any path.** No branch adds it. So no `.so` ASE
  builds ever defines `WITH_TIMING`: the shim compiles the **non-timing**
  `step()` (the one that dumps at `pinfo->vtime`) and sets `pinfo->method` to
  `After_input`.
- **`-V` is passed unless the state says `cosim trace 0`**, which is a supported
  policy, not a hypothetical. With `-V` (the default) `--trace` is on, `VM_TRACE`
  is defined, and the VCD patches above are live.

What `cosim trace 0` actually does is worth spelling out, because it is more
than "no VCD": `build_cosim_so.sh` also uses `-V` to choose the shim source, and
without it `SHIMDIR` falls back to the **system** copy under
`/usr/local/share/ngspice/scripts/src`. That copy carries none of the `XSCHEM
PATCH` hunks — not the trace object, not the clamp, and not the context-lifetime
`release()`. A `trace 0` library is the stock upstream shim, upstream bug and
all.

Two consequences of the `-t` half worth remembering, because both look like
puzzles otherwise: the `--timing` `step()` and its event-time `dump()` are
**never compiled** in anything the product builds (they are maintained for a
`-t` build nobody currently makes), and the `After_input` method is exactly why
the monotonicity clamp is mandatory — ngspice calls `step()` repeatedly at the
same `vtime`. A `-t` build is still supported by `build_cosim_so.sh`; it is
simply not what the product does today. Note that "not compiled" applies to the
`--timing` `step()`, **not** to the context-lifetime `release()`, which is
unguarded and compiled into every build (see the bullet above).

## Keeping `src/` in sync

`src/` is a vendored copy. On an ngspice upgrade, re-copy from
`/usr/local/share/ngspice/scripts/src/` and re-apply the `XSCHEM PATCH` hunks.
`build_cosim_so.sh` without `-V` deliberately uses the **system** copy, so a
stale vendored tree cannot silently affect a non-trace build. Override either
with `NGSPICE_COSIM_SRC`.

## Verified working

`xschem_libraries_oa/ngspice_verilog_cosim_ase/tb_counter_wrapper` — a 4-bit
Verilog counter co-simulated with an analog weighted-resistor ladder, auto
`adc_bridge`/`dac_bridge` at the boundary. Produces both artifacts in the ASE-L
rundir:

- `tb_counter_wrapper_ase.raw` — analog + bridged digital
- `counter.vcd` — `TOP.counter.{phase,half,prev,next_count,tc,carry}`, none of
  which exist anywhere in the raw
