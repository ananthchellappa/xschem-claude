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
  lives for the process. This is an upstream bug, fixed here because the trace
  setup needs the context too.

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
