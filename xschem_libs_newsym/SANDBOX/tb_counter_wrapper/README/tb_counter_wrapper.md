# `SANDBOX/tb_counter_wrapper` — mixed-signal co-simulation with the Verilog internals visible

A 4-bit counter that exists **only as Verilog** — cell `SANDBOX/counter` has a
`symbol` view and a `verilog` view and **no schematic view at all** — co-simulated
with an ngspice analog deck, so that its *internal* signals (`phase`, `half`,
`prev`, `next_count`, `tc`, `carry`) can be browsed in xschem's Signal Browser.

That is the whole point of the design. Only module **ports** cross the XSPICE
`d_cosim` boundary, and ngspice's `.raw` file cannot hold event nodes at all, so
those six signals appear in no raw file anywhere. They reach xschem through a VCD
written by a patched Verilator shim (`tools/cosim/`), which the waveform viewer
reads as a second database on the same time axis as the analog raw.

Design notes and every measurement behind this flow:
`doc/claude/specs/mixed_signal_signal_browser.md`.

---

## 1. What you must install

Nothing here needs a PDK. The deck uses ngspice built-ins (voltage source,
capacitor) plus the `d_cosim` code model, so once the tools below are in place it
runs standalone.

### 1.1 xschem itself, from this repo

Debian/Ubuntu development packages (from `doc/xschem_man/install_xschem.html`):

```sh
sudo apt-get install build-essential bison flex gawk \
    libx11-dev libxrender-dev libx11-xcb-dev libcairo2-dev \
    libxpm-dev libjpeg-dev tcl8.6-dev tk8.6-dev xterm
```

```sh
./configure          # scconfig, not autotools
make                 # binary lands in src/xschem; no install needed
```

### 1.2 ngspice — **build it from source; the distro package will not do**

You need an ngspice whose `d_cosim` code model supports the **`sim_args`**
parameter, because that is how the VCD path is handed to the shim.

Measured on Ubuntu 24.04, 2026-08-12:

| build | `d_cosim` | `sim_args` |
|---|---|---|
| `apt` ngspice 42 (`/usr/lib/x86_64-linux-gnu/ngspice/digital.cm`) | present | **absent** |
| source ngspice 46 (`/usr/local/lib/ngspice/digital.cm`) | present | present |

Without `sim_args` the analog side still simulates perfectly and **no VCD is ever
written** — the failure is silent. Check your build before anything else:

```sh
strings /usr/local/lib/ngspice/digital.cm | grep -w sim_args     # must print sim_args
```

Build (the recipe this repo already documents, `doc/xschem_man/tutorial_xschem_sky130.html`):

```sh
git clone https://git.code.sf.net/p/ngspice/ngspice ngspice_git
cd ngspice_git && mkdir release && ./autogen.sh && cd release
../configure --with-x --enable-xspice --disable-debug --enable-cider \
             --with-readline=yes --enable-openmp --enable-osdi
make && sudo make install        # /usr/local/{bin,lib,share}
```

`--enable-xspice` is the flag that matters — it is what builds `digital.cm`, which
is what carries `d_cosim`.

⚠ If the distro package is *also* installed you now have two `ngspice` binaries.
xschem runs whichever one PATH finds (`ase.tcl:3239` execs a bare `ngspice`), so
make sure `/usr/local/bin` comes first:

```sh
command -v ngspice          # want /usr/local/bin/ngspice
ngspice --version | sed -n 2p
```

### 1.3 Verilator + a C++ compiler

```sh
sudo apt-get install verilator g++
```

Known good here: **Verilator 5.020** (Debian package) and **g++ 13.3**. The
Verilog is compiled to a shared library by `tools/cosim/build_cosim_so.sh`, which
replaces ngspice's own `vlnggen` — `vlnggen` cannot work on ngspice-46, which
lower-cases every literal token in script-file mode and so calls verilator with
`--mdir`. Details in `tools/cosim/README.md`.

**Icarus Verilog is not an alternative on Ubuntu.** The instance `a1` carries a
commented-out `simulation="ivlng"` arm, but the Ubuntu `iverilog` package ships no
`libvvp.so`, which `ivlng.so` dlopens. Leave the Verilator arm active.

### 1.4 Verify the install before opening any GUI

```sh
./src/xschem --nogui --pipe -q --script tests/headless/test_cosim_golden_e2e.tcl
```

Expect `RESULT: ALL PASS (46 checks)` (~4 min: it runs the full 10 ps / 2 µs
reference). It drives the real chain — netlist → verilator+g++ build → `ngspice -b`
→ VCD → both databases attached → internal edges compared against a committed
golden. With a tool missing it prints `note: group GE not run -- absent: …` and
still passes the parts that do not need a simulator, so read that line.

(That test exercises the reference copy in
`xschem_libraries_oa/ngspice_verilog_cosim_ase/`, not this SANDBOX cell. Same
Verilog, same flow.)

---

## 2. Running it

### 2.1 Make the SANDBOX library visible

This library tree is registered by its own `library.defs`, which is **not** on
xschem's default search path. Easiest:

```sh
./src/xschem --script src/cadence_style_rc
```

`cadence_style_rc` points `XSCHEM_LIBRARY_DEFS` at
`xschem_libs_newsym/library.defs` (and turns on the Cadence-style interaction
mode). To do it without that file, put this in `~/.xschem/xschemrc`:

```tcl
set XSCHEM_LIBRARY_DEFS /path/to/repo/xschem_libs_newsym/library.defs
set library_registry_defs_only 1
set XSCHEM_LIBRARY_PATH {}
append XSCHEM_LIBRARY_PATH :/path/to/repo/xschem_libs_newsym
```

⚠ `append XSCHEM_LIBRARY_PATH …` must be written **unqualified** like that. The
write trace that rebuilds the internal path list does not fire on a
namespace-qualified write, and the library silently stays unfound.

### 2.2 Simulate

1. Library Manager → library **SANDBOX** → cell **tb_counter_wrapper** → view
   **ngspice_state1**. Opening that view launches ASE-L with the saved setup:
   `tran 100p 2u`, `VDD = 1.8`, outputs `clk` and `count_out3..0`, and the
   `auto_bridge` adc/dac `pre_set`s at 1.8 V.
2. ASE-L menu **Simulation → Netlist and Run**. (Plain **Run** reuses an existing
   netlist; the first run must netlist.)

What happens, in order: xschem netlists the design → ASE finds the `.model counter
d_cosim` card and joins it to `SANDBOX/counter`'s `verilog` view → builds
`counter.so` with Verilator + g++ → rewrites the card's `sim_args` to the run's VCD
name → `cd`s into the run directory and runs `ngspice -b` → attaches the analog raw
**and** the VCD to the waveform viewer as two databases.

Run directory defaults to `~/.xschem/simulations`. Artifacts:

| file | what |
|---|---|
| `counter.so`, `counter.so.stamp` | the compiled Verilog; the stamp records source path+mtime+size+flags so a changed `counter.v` forces a rebuild |
| `tb_counter_wrapper_ase.raw` | analog + bridged digital (`v(clk)`, `v(count_out3..0)`) |
| `tb_counter_wrapper_counter.vcd` | `TOP.clk`, `TOP.count`, and `TOP.counter.{clk,count,phase,half,prev,next_count,tc,carry}` |
| `tb_counter_wrapper_ase.cosim` | the instance↔VCD map ASE writes for the Signal Browser |
| `tb_counter_wrapper_ase.log` | the ngspice log |

Timings on the reference machine: first build ~10 s (warm rebuild ~9 s, so it is
skipped when nothing changed), ngspice **0.36 s**, raw 1.8 MB.

### 2.3 See the internals

Select instance `a1` on the schematic and press **Ctrl-Alt-V**. The Signal Browser
scopes to that instance and lists the VCD's signals. `phase`, `half`, `prev`,
`next_count`, `tc` and `carry` are the payload: they exist in the digital simulator
only, and `xschem raw index TOP.counter.phase` against the analog raw returns -1.

Sanity check on the data: `tc` rises at **1450 ns** — 50 ns + 14×100 ns, i.e. the
15th clock edge, exactly when `count` first reaches 15.

---

## 3. Things that will bite

- **Do not delete `C2[3..0]`.** It is the only analog load on the digital bus, and
  it is what makes ngspice insert the auto `dac_bridge`s. Without it
  `count_out3..0` leave the `.raw` entirely.
- **Keep upper-case letters out of the run directory.** ngspice lower-cases the
  strings inside a device card whenever the physical line does not carry exactly
  two double quotes — and an ASE-traced card carries four. A run directory with a
  capital letter in it therefore sends the VCD somewhere else, with **no error**.
  ASE handles this by writing a bare lower-cased basename; do not hand-edit
  `sim_args` into an absolute path.
- **`cosim trace 0`** in the state is more than "no VCD": the build then falls back
  to the *system* shim under `/usr/local/share/ngspice/scripts/src`, which carries
  none of the `XSCHEM PATCH` hunks (no trace object, no monotonicity clamp, no
  context-lifetime fix).
- **Adding a port to `counter.v` means editing the symbol too.** The port order in
  the symbol's `format="@name [ @@clk ] [ @@count[3..0] ] @model"` *is* the
  co-simulation wire protocol. Adding an *internal* signal costs nothing — that is
  the property this testbench exists to demonstrate.
- `#` comment records in `.sch`/`.sym` files are dropped when xschem saves.

## 4. Files

```
SANDBOX/counter/symbol/counter.sym                        symbol (ports + d_cosim format string)
SANDBOX/counter/verilog/counter.v                         the only implementation
SANDBOX/tb_counter_wrapper/schematic/tb_counter_wrapper.sch
SANDBOX/tb_counter_wrapper/symbol/tb_counter_wrapper.sym
SANDBOX/tb_counter_wrapper/ngspice_state1/tb_counter_wrapper.state   ASE-L setup
SANDBOX/tb_counter_wrapper/README/tb_counter_wrapper.md             this file
```

This file is itself a **view** — type `text`, so it appears in the Library
Manager's view list beside `schematic` and `ngspice_state1`, and opening it
hands it to your text editor instead of `xschem load`. See
`doc/claude/specs/text_view_type.md`.

Related: `tools/cosim/README.md` (the build script and the shim patches),
`doc/claude/specs/mixed_signal_signal_browser.md` (why any of this is shaped the
way it is). The upstream-derived reference copy of the same design, kept at
10 ps steps for the regression golden, is
`xschem_libraries_oa/ngspice_verilog_cosim_ase/`.
