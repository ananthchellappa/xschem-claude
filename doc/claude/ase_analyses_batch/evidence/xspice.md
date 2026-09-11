# Dossier: XSPICE / mixed-signal, and how it changes the analysis surface

Reader: a future Claude Code session building ASE-L (Analog Simulation Environment - Lite)
in `/home/analog/dev/xschem-claude/src/ase.tcl` + `ase_window.tcl`.

Tree surveyed: `/home/analog/dev/ngspice`, branch `ver_50`, `git describe` = `ngspice-46-419-gccebdf2a2`.
Binary exercised read-only: `/home/analog/dev/ngspice/build-ver_50/src/ngspice`
(reports `ngspice-46+`, built `Thu Sep 3 06:46:24 UTC 2026`, KLU, SPARSE 1.3 fallback).
Scratch decks used for every live experiment quoted below live in
`/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/work/`.
Nothing in either repository was modified.

Every line reference is `path:LINE` relative to `/home/analog/dev/ngspice/`.
Where a claim comes from running the binary it is marked **[observed]** and the deck is quoted.

---

## 0. One-paragraph orientation

XSPICE adds a **second simulator** inside ngspice: an event-driven scheduler
(`src/xspice/evt/`) that runs *beside* the analog Newton/matrix solver and exchanges data
with it only through "hybrid" instances that have both analog and event ports.
Everything the event side knows about lives in `ckt->evt` (`struct Evt_Ckt_Data`,
`src/include/ngspice/evt.h:360-368`), which is **not** the analog plot and **not** the
rawfile. Event results are therefore invisible to every rawfile-based workflow and must be
read back through a separate set of commands (`eprint`, `eprvcd`, `edisplay`) or a separate
shared-library API (`ngGet_Evt_NodeInfo`, `ngSpice_Raw_Evt`). A GUI that treats "run and
read the raw file" as the universal path will silently lose all digital data.

---

## 1. Build gating — what is on in THIS tree

| Feature | Flag | Default | This tree |
|---|---|---|---|
| XSPICE core (`#define XSPICE`) | `--disable-xspice` to turn OFF | **ON** | ON — `build-ver_50/src/include/ngspice/config.h:579` `#define XSPICE 1` |
| Shipped `.cm` code-model libraries | built when XSPICE on | ON | 7 libraries built, see §3 |
| Icarus Verilog shim (`ivlng.so`, `ivlng.vpi`) | unconditional under XSPICE (`src/xspice/verilog/Makefile.am:29-35`) | ON | built: `build-ver_50/stage/lib/ngspice/ivlng.so`, `ivlng.vpi` |
| Verilator helper script `vlnggen` | installed as data (`src/xspice/verilog/Makefile.am:11-12`) | ON | installed: `build-ver_50/stage/share/ngspice/scripts/vlnggen` |
| GHDL/VHDL helper `ghnggen` | `src/xspice/vhdl/Makefile.am:8-9` | ON | installed: `build-ver_50/stage/share/ngspice/scripts/ghnggen` |
| OSDI | `--disable-osdi` | ON | `config.h:502` `#define OSDI 1` |
| S-parameter analysis (`sp`) | `--disable-sp` (`configure.ac:1220-1229`) | **ON** | `config.h:535` `#define RFSPICE 1` |
| PSS analysis | `--enable-pss` (`configure.ac:1082-1085`) | **OFF** | `config.h:576` `/* #undef WITH_PSS */` — **`pss` is NOT available here** |
| CIDER | `--enable-cider` | OFF | `config.h:11` `/* #undef CIDER */` |

XSPICE default-on is set by `configure.ac:142-143` (only `--disable-xspice` exists) and
`configure.ac:1111` / `configure.ac:1177`.

A control variable `xspice_enabled` is created at startup by `src/main.c:943`
(`cp_vset("xspice_enabled", CP_BOOL, &t)`) and by `src/sharedspice.c:944` for libngspice.
`src/spinit.in` tests it (`if $?xspice_enabled`) before issuing the `codemodel` lines, and
`configure.ac:1113`/`1168` substitute `@XSPICEINIT@` with `*` (comment) or `""` accordingly.

---

## 2. What an "event-driven simulation" is, in ngspice terms

* **Event instance** — an `A` card whose `.model` names a code model with at least one
  digital (`d`) or user-defined-type port. `MIFinstance.event_driven` is set.
* **Hybrid instance** — an event instance that ALSO has analog ports
  (`fast->analog && fast->event_driven`, `src/xspice/evt/evtinit.c:157`). Hybrids are the
  only bridge between the two solvers. `adc_bridge`, `dac_bridge`, `bidi_bridge`,
  `real_to_v` are hybrids; `d_nand` is pure-event.
* **Event node** — a net that carries a UDN value rather than a voltage. It is **not** on
  `ckt->CKTnodes`; it is on `ckt->evt->info.node_table`
  (`src/include/ngspice/evt.h:82-99`, and see `Evt_Ckt_Has_Node()` at
  `src/xspice/evt/evtplot.c:80`, whose comment says exactly this).
* **Event queues** — three of them: instance queue, node queue, output queue
  (`src/include/ngspice/evt.h:124-200`). Outputs are posted with a delay
  (`Evt_Output_Event.event_time`), so the scheduler is a real discrete-event simulator with
  its own time axis.
* **Event node data** — `Evt_Node` records `{op, step, node_value}`
  (`src/include/ngspice/evt.h:207-214`). `step` is the *sweep value* in a DC sweep and the
  *time* in a transient; `op` is TRUE only when the point came from a DC operating point.
  Values are stored **only when they change**, so an event vector is irregularly sampled and
  has its own scale.

### 2.1 Which analyses call the event solver

Grepping every file in `src/spicelib/analysis/` for `XSPICE`:

| Analysis | source | Event participation |
|---|---|---|
| `op` (`dcop.c`) | `dcop.c:61-72` | **Full**: `EVTop()` replaces `CKTop()`, then `EVTop_save(ckt, MIF_TRUE, 0.0)` — one point, flagged `op` |
| `tran` (`dctran.c`) | `dctran.c:223-233`, `425`, `606-645`, `917-935` | **Full**: `EVTop()` for the tran-op, then per-timestep event dequeue/iterate, `EVTaccept()`, `EVTbackup()` |
| `dc` sweep (`dctrcurv.c`) | `dctrcurv.c:292-368` | **Partial/fragile**: `EVTop()` at the first point, then per-step `NIiter` + `EVTcall_hybrids` + `EVTop()` only if a hybrid output changed. `evt_step` is taken from **the first sweep variable only** (`dctrcurv.c:322-334`; supports V source, I source, resistance, TEMP). See §12 for an observed failure. |
| `ac` (`acan.c`) | `acan.c:119-128`, `266-275` | **OP only**: `EVTop()` computes the bias point, `EVTop_save(ckt, MIF_TRUE, 0.0)` stores one event point; the frequency sweep itself never touches the event solver. Also note `EVTop` bypasses the `noopac` shortcut (`acan.c:132`). |
| `noise` (`noisean.c`) | `noisean.c:172-181`, `388-397` | **OP only**, same shape as `ac`. Code models can contribute noise via `MIFnoise` (`src/xspice/mif/mifnoise.c:462`), see §3.4 |
| `sp` / S-parameters (`span.c`) | `span.c:440-449`, `679-688` | **OP only**, same shape as `ac` |
| `optran` (op-by-transient) (`optran.c`) | `optran.c:477`, `605-617`, `827` | **Full transient-style** event stepping |
| `pss` (`dcpss.c`) | `dcpss.c:246-258`, `469`, `1185-1205`, `1409` | Full support in source, **but not built here** (`--enable-pss` off) |
| `pz` (`pzan.c`) | — | **No XSPICE code at all** |
| `tf` (`tfanal.c`) | — | **No XSPICE code at all** |
| `disto` (`distoan.c`) | — | **No XSPICE code at all** |
| `sens` (`cktsens.c`) | — | **No XSPICE hook**; hits a fatal internal error, see §12.3 |

The official manual agrees with the source on the headline restriction:
> "Event-driven applications that include digital and User-Defined Node types may make use
> of DC (operating point and DC sweep) and Transient only."
> — https://ngspice.sourceforge.io/docs/ngspice-html-manual/manual.xhtml

**Where source and doc differ:** the source is *more* permissive than the manual — `ac`,
`noise` and `sp` do run on mixed decks and do compute an event-aware bias point
(`acan.c:121`, `noisean.c:175`, `span.c:443`). I trust the source here: the runs succeed
**[observed]**. But the manual's spirit is right: only the DC operating point is
event-aware; the frequency sweep linearises the code models around it and the event nodes
are frozen. Treat `ac`/`noise`/`sp` as "supported, but the digital state is whatever the
operating point produced".

---

## 3. Loading code models: the `codemodel` command and `.cm` libraries

### 3.1 The command

Registered at `src/frontend/commands.c:283-286`, inside `#ifdef XSPICE`:

```
{ "codemodel", com_codemodel, FALSE, TRUE,
  { 040000, 040000, 040000, 040000 }, E_BEGINNING, 1, 1,
  NULL,
  "library library ... : Loads the code model libraries." }
```

Note the arity is `1, 1` — **exactly one argument**, despite the help text saying
"library library ...". `com_codemodel` (`src/frontend/com_dl.c:9-27`) only ever looks at
`wl->wl_word`, i.e. the first word. A GUI must emit one `codemodel` line per `.cm` file.

The loader is `load_opus()` (`src/spicelib/devices/dev.c:397`): `dlopen(name, RTLD_NOW)`,
then `dlsym` for `CMdevNum`/`CMdevs` (the code models) and `CMudnNum`/`CMudns` (the
user-defined node types), then `add_device()` (`dev.c:361`) and `add_udn()` (`dev.c:382`),
finally `relink()` which rewrites `ft_sim->devices` and `DEVmaxnum`.

Path rule from `src/xspice/README`: "the codemodel path must begin with ./ or / to work"
(it is passed straight to `dlopen`).

### 3.2 What spinit does (`src/spinit.in`)

```
if $?xspice_enabled
@XSPICEINIT@ codemodel @pkglibdir@/spice2poly.cm
@XSPICEINIT@ codemodel @pkglibdir@/analog.cm
@XSPICEINIT@ codemodel @pkglibdir@/digital.cm
@XSPICEINIT@ codemodel @pkglibdir@/xtradev.cm
@XSPICEINIT@ codemodel @pkglibdir@/xtraevt.cm
@XSPICEINIT@ codemodel @pkglibdir@/table.cm
@XSPICEINIT@ codemodel @pkglibdir@/tlines.cm
end
```

In this build tree `@pkglibdir@` expands to
`/home/analog/dev/ngspice/build-ver_50/stage/lib/ngspice/`, and all seven `.cm` files are
present there **[observed]**. spinit is located via `Spice_Lib_Dir` (see
`src/frontend/cpitf.c:262-326`); `Lib_Path` is `$Spice_Lib_Dir/scripts`
(`src/misc/ivars.c:75`, env override `SPICE_SCRIPTS`) and is put on the control-language
`sourcepath` (`src/frontend/cpitf.c:249-253`). That is why `ngspice vlnggen foo.v` finds
the Verilator script (§10).

`ngspice -n` / `--no-spiceinit` suppresses `.spiceinit` (local/user), and the variable
`no_spinit` suppresses the system `spinit` (`src/frontend/cpitf.c:264`). Missing spinit is a
warning only: `"Warning: can't find the initialization file spinit."`
(`src/frontend/cpitf.c:321`).

### 3.3 What fails, and with what message

**(a) The `.cm` file cannot be loaded** — `load_opus` prints, then `com_codemodel` prints,
then the netlist reader prints a third time. **[observed]** with a `.spiceinit` containing
`codemodel /nonexistent/path/mylib.cm`:

```
Error opening code model "/nonexistent/path/mylib.cm": No such file or directory!
Error: Library /nonexistent/path/mylib.cm couldn't be loaded!
Warning: code models like /nonexistent/path/mylib.cm have not been loaded successfully.
    Any of the following steps may fail, if code models are involved!.
```

Sources: `src/spicelib/devices/dev.c:411` (or `:415` when the file exists but `dlopen`
fails), `src/frontend/com_dl.c:15`, `src/frontend/inpcom.c:1483-1484`.
The third message only appears when a netlist is subsequently read
(`inpcom.c:1482`, inside `inp_readall`).

**This is NOT fatal by default.** `ft_spiniterror` is set and `ft_codemodelerror` records
the library name (`com_dl.c:17-18`); the run continues. It becomes fatal only if
`set strict_errorhandling` is in effect — `com_dl.c:19-20` calls `controlled_exit(EXIT_BAD)`,
and `src/frontend/options.c:380-381` bails out immediately if the variable is set after the
error. **GUI recommendation: put `set strict_errorhandling` in the spinit/`.spiceinit` you
generate, so a broken installation fails loudly instead of producing a plausible-looking
wrong answer.**

**(b) The `.cm` loaded fine but the deck names a model type that no loaded library
provides** — the error is raised by `MIFgetMod` (`src/xspice/mif/mifgetmod.c:296`).
**[observed]** with `.model mynand d_nand_not_loaded(...)`:

```
Error on line 5 or its substitute:
  a1 [in1 in2] out mynand
MIF-ERROR - unable to find definition of model mynand
    Simulation interrupted due to error!

Error: incomplete or empty netlist
       or no ".plot", ".print", or ".fourier" lines in batch mode;
no simulations run!
```

Exit status was **0** **[observed]**, so a GUI must parse stderr/stdout, not `$?`, to detect
this. Related message for a `.model` whose type resolved to a negative device index:
`"MIF: Unknown device type for model %s"` (`mifgetmod.c:147`).

**(c) A related failure worth knowing**: the digital node type `d` is compiled into the
binary (`src/spicelib/devices/dev.c:253-255`, `g_evt_udn_info[0] = &idn_digital_info`), so
`d` nodes work even if no `.cm` loaded. `real` and `int` come only from `xtraevt.cm`
(`src/xspice/icm/xtraevt/udnpath.lst`), so a deck using them with `xtraevt.cm` unloaded
fails at model lookup, not at node-type lookup.

### 3.4 The shipped code models (inventory)

Built from `src/xspice/icm/<lib>/modpath.lst`; names below are the `Spice_Model_Name` from
each `ifspec.ifs`.

* **analog.cm** — `climit`, `divide`, `d_dt`, `gain`, `hyst`, `ilimit`, `int`, `limit`,
  `mult`, `multi_input_pwl`, `oneshot`, `pwl`, `sine`, `slew`, `square`, `summer`, `xfer`,
  `s_xfer`, `triangle`, `filesource` (dir `file_source`), `delay`, `pwlts`, `astate`, `ota`.
* **digital.cm** — `adc_bridge`, `dac_bridge`, `bidi_bridge`, `d_and`, `d_buffer`, `d_dff`,
  `d_dlatch`, `d_fdiv`, `d_genlut`, `d_inverter`, `d_jkff`, `d_lut`, `d_nand`, `d_nor`,
  `d_open_c`, `d_open_e`, `d_or`, `d_osc`, `d_process`, `d_pulldown`, `d_pullup`, `d_pwm`,
  `d_ram`, `d_source`, `d_srff`, `d_srlatch`, `d_state`, `d_tff`, `d_tristate`, `d_xnor`,
  `d_xor`, `d_cosim`.
* **xtradev.cm** — `aswitch`, `capacitoric`, `cmeter`, `core`, `inductoric`, `lcouple`,
  `lmeter`, `potentiometer`, `zener`, `memristor`, `sidiode`, `pswitch`, `seegen`.
* **xtraevt.cm** — models `d_to_real`, `real_delay`, `real_gain`, `real_to_v`;
  **plus the UDN types `real` and `int`** (`udnpath.lst`).
* **table.cm** — `table2d`, `table3d` (the `mada` directory exists but is NOT in
  `modpath.lst`, so it is not built).
* **tlines.cm** — `mlin`, `tline`, `cpline`, `cpmlin`, `msopen`.
* **spice2poly.cm** — `spice2poly` (dir `icm_spice2poly`); this is what makes SPICE-2 `POLY`
  controlled sources work, via `ENHtranslate_poly()` (`src/xspice/enh/enhtrans.c:82`, called
  from `src/frontend/inp.c:965`).

Only **one** shipped model contributes noise: `ota`
(`src/xspice/icm/analog/ota/cfunc.mod:41-50`, eight `cm_noise_add_source()` calls).

**Runtime introspection [observed]:** `showmod all` after a run lists every code-model
`.model` with all parameters resolved to their effective values (including auto-inserted
bridges). `show <inst>` lists instance parameters. `showmod <modelname>` alone did **not**
find a code model model (printed `No matching instances or models`); `showmod <modeltype>`
and `showmod all` both worked. A GUI can use `showmod all` to harvest parameter names and
defaults without parsing `ifspec.ifs`.

---

## 4. Event node types (UDNs)

The type table is `g_evt_udn_info[]` / `g_evt_num_udn_types`
(`src/include/ngspice/evtudn.h:117-118`, defined at `src/spicelib/devices/dev.c:67-68`).
Slot 0 is always `d`, installed statically at `dev.c:253-255`. Others are appended by
`add_udn()` (`dev.c:382`) as `.cm` libraries load, so **UDN indexes depend on load order**.

Each type supplies the vtable in `Evt_Udn_Info_t` (`src/include/ngspice/evtudn.h:104-116`):
`create, dismantle, initialize, invert, copy, resolve, compare, plot_val, print_val,
ipc_val`. `plot_val` is what turns an event value into a plottable double; `print_val` into
a string; `resolve` is the wired-logic resolution when several outputs drive one node.

### 4.1 `d` — 12-state digital (built in)

`src/xspice/idn/idndig.c:344-359`, name `"d"`, description `"12 state digital data"`.
Value is `Digital_t { Digital_State_t state; Digital_Strength_t strength; }`
(`src/include/ngspice/cmtypes.h:64-67`).

* states: `ZERO`, `ONE`, `UNKNOWN` (`cmtypes.h:52-55`)
* strengths: `STRONG`, `RESISTIVE`, `HI_IMPEDANCE`, `UNDETERMINED` (`cmtypes.h:57-62`)
* printed as the 12 strings `0s 1s Us 0r 1r Ur 0z 1z Uz 0u 1u Uu`
  (`idndig.c:264-267`, `idndig.c:322-327`)
* members addressable as `node(state)` and `node(strength)`
  (`idndig.c:207-256` for plot values, `idndig.c:259-330` for print values)
* plot values: state → `0.0 / 1.0 / 0.5`; strength → `0.1 / 0.6 / 1.1 / -0.4`
  (deliberately offset so state and strength traces do not overlap; `idndig.c:213-247`)
* multi-driver resolution is a 12×12 table in `idn_digital_resolve` (`idndig.c:150-185`)

### 4.2 `real` (from `xtraevt.cm`)

`src/xspice/icm/xtraevt/real/udnfunc.c` — value is a bare `double`.
`resolve` **sums** all driver values (`udnfunc.c:94-110`). `invert` negates.
`print_val` formats `%15.6e`.

### 4.3 `int` (from `xtraevt.cm`)

`src/xspice/icm/xtraevt/int/udnfunc.c` — value is a bare `int`, `print_val` `%8d`.

### 4.4 User-defined types

A `.cm` library adds them by shipping a `udnfunc.c` per type and listing the directory in
`udnpath.lst` (`src/xspice/README`). The GUI cannot know the member names of a
user-defined type a priori; the only runtime discovery is `edisplay`, which prints the type
*name* per node (`src/xspice/evt/evtprint.c:453`), not the member list.

---

## 5. What an analysis run does DIFFERENTLY when event nodes exist

Everything in this section is unconditional consequence of the deck containing `A` cards.

### 5.1 `trtol` is silently forced to 1

`src/spicelib/analysis/cktdojob.c:81-91`:

```c
if (ckt->CKTadevFlag && (ckt->CKTtrtol > 1)) {
    if (cp_getvar("xtrtol", CP_NUM, &newtol, 0)) {
        printf("Override trtol to %d for xspice 'A' devices\n", newtol);
        ckt->CKTtrtol = newtol;
    } else {
        printf("Reducing trtol to 1 for xspice 'A' devices\n");
        ckt->CKTtrtol = 1;
    }
}
```

`CKTadevFlag` is set in the parser when any `A` card is seen
(`src/spicelib/parser/inppas2.c:118`). **[observed]** every mixed-signal run printed
`Reducing trtol to 1 for xspice 'A' devices`.

**GUI consequence:** a `.options trtol=7` the user typed is *overridden*. The only escape is
the control variable `set xtrtol=<n>`. This makes mixed decks markedly slower and more
accurate than the same options on a pure-analog deck. Expose `xtrtol` in the GUI next to
`trtol`, and show the effective value.

### 5.2 `CKTop()` is replaced by `EVTop()`

`src/xspice/evt/evtop.c:70`. `EVTop` alternates:
1. `EVTiter(ckt)` — settle the event side.
2. `CKTop(...)` on the first pass, else `NIiter(...)` falling back to `CKTop` (`evtop.c:126-146`).
3. `EVTcall_hybrids(ckt)` — let hybrids post new event outputs (`evtop.c:149`).
4. If `ckt->evt->queue.output.num_changed == 0` → done (`evtop.c:160-161`).
5. Else loop; abort with `E_ITERLIM` after `max_op_alternations`
   (`evtop.c:172-190`), printing `"Too many analog/event-driven solution alternations"` and
   one `ENHreport_conv_prob(ENH_EVENT_NODE, ...)` block per still-changing output naming
   instance / connection / port.

The statistics `op_alternations`, `op_load_calls`, `op_event_passes`,
`tran_load_calls`, `tran_time_backups` (`src/include/ngspice/evt.h:284-290`) are printed by
`eprint` (§7.2) — they are the only convergence telemetry for the event side.

### 5.3 Transient: the event queue drives the timestep

`src/spicelib/analysis/dctran.c:606-645`:

```c
while ((g_mif_info.circuit.evt_step = EVTnext_time(ckt))
       <= (ckt->CKTtime + ckt->CKTdelta)) {
    g_mif_info.breakpoint.current = 1e30;
    EVTdequeue(ckt, g_mif_info.circuit.evt_step);
    EVTiter(ckt);
    ...
    if (g_mif_info.breakpoint.current < ckt->CKTtime + ckt->CKTdelta) { ... cut CKTdelta ... }
}
```

So: pending events *inside* the next analog step are processed first, and a code model may
force a shorter analog step by setting a temporary breakpoint
(`cm_analog_set_temp_bkpt` / `cm_analog_set_perm_bkpt`, exported at `src/xspice/xspice.c:46-47`).

On an accepted timepoint, `EVTaccept(ckt, ckt->CKTtime)` (`dctran.c:425`) commits the queue
and node history. On a rejected timepoint, `EVTbackup(ckt, ...)` (`dctran.c:927-933`) rolls
the event state back; `tran_time_backups` counts these.

After a *successful* trunc-error check, hybrids and models that called `cm_irreversible()`
get an extra EVENT call (`dctran.c:805-820`) so co-simulations can advance. That is the
mechanism `d_cosim` relies on — a Verilog simulation cannot be un-run, so it must only be
advanced on accepted time.

`ramptime > 0` inserts a breakpoint at the end of the ramp (`dctran.c:220-221`).

### 5.4 Netlist is rewritten before setup (auto-bridging)

`Evtcheck_nodes()` is called from `if_inpdeck()` (`src/frontend/spiceif.c:185`) — i.e. after
the circuit is built but before any analysis. It can *append a sub-deck* of bridge model and
device cards. See §6. This means the circuit a GUI thinks it sent is not necessarily the
circuit that runs, and `showmod all` will list models the user never wrote.

### 5.5 `.probe alli` becomes fatal

`src/xspice/evt/evtcheck_nodes.c:980-987`. **[observed]**, exit status **1**:

```
Error: Dot command '.probe alli' and digital nodes are not compatible.
    Simulation will fail!

ERROR: fatal error in ngspice, exit(1)
```

### 5.6 `snsave`/`snload` are refused

`src/frontend/spiceif.c:1725-1730`:
`"Warning: snsave not implemented for XSPICE A devices."` /
`"    Command 'snsave' will be ingnored!"` (typo is in the source).
`spiceif.c:1825-1826` explains: `ckt->evt->data` is not serialised.

### 5.7 `-r <rawfile>` deliberately throws the event data away

`src/main.c:1567-1570`:

```c
#ifdef XSPICE
    // Do not save any XSPICE node data, as there is no way to use it.
    EVTdiscard();
#endif
```

`EVTdiscard()` (`src/xspice/evt/evtprint.c:968`) clears the `save` flag on every event node.
**[observed]** a deck with `.save v(out) dout` and `.tran`, run as
`ngspice -b -r batch.raw deck.cir`, produced a rawfile with only `time` and `v(out)`; `dout`
was silently absent, with no warning. **This is the single most important fact in this
dossier for a GUI that shells out to ngspice.**

---

## 6. Automatic bridging — the feature that makes mixed decks "just work"

Implemented entirely in `src/xspice/evt/evtcheck_nodes.c`; the 140-line comment at
`evtcheck_nodes.c:30-171` is the authoritative specification. Author: Giles Atkinson, 2022.

### 6.1 Trigger

If the *same name* appears as both an analog node (`ckt->CKTnodes`) and an event node
(`ckt->evt->info.node_list`), ngspice inserts a bridge device between them
(`evtcheck_nodes.c:1002-1015`, matching with `ng_ideq()` so the case mode is honoured).

### 6.2 Control variable `auto_bridge`

`evtcheck_nodes.c:974-976`, values from `evtcheck_nodes.c:184-186`:

| value | meaning |
|---|---|
| `0` (`AB_OFF`) | bridging disabled — a mixed-type node is a **fatal netlist error** |
| `1` (`AB_SILENT`) | **default** (`show = AB_SILENT` when the variable is unset) |
| `2` (`AB_DECK`) | also print the generated sub-deck |

**[observed]** with `set auto_bridge=2` in `.spiceinit`:

```
999990000: * Auto-bridge sub-deck.
999990001: .model auto_adc adc_bridge(in_low = '3.3/2' in_high = '3.3/2')
999990002: auto_adc2 [ in1 in2 ] [ in1 in2 ] auto_adc
```

**[observed]** with `set auto_bridge=0`:

```
Evtcheck_nodes: Auto bridging is switched off but node in1 is mixed-type.

Error: circuit not parsed.
```
(message text at `evtcheck_nodes.c:1017-1020`.)

### 6.3 The built-in digital defaults

`evtcheck_nodes.c:789-802` — used only for `udn_index == 0`, i.e. `d` nodes:

| direction | model card | device card |
|---|---|---|
| IN (analog → event) | `.model auto_adc adc_bridge(in_low = '%g/2' in_high = '%g/2')` | `auto_adc%d [ %s ] [ %s ] auto_adc` |
| OUT (event → analog) | `.model auto_dac dac_bridge(out_low = 0 out_high = %g)` | `auto_dac%d [ %s ] [ %s ] auto_dac` |
| INOUT / both | `.model auto_bidi bidi_bridge(out_high = %g in_low = '%g/2' in_high = '%g/2')` | `auto_bidi%d [ %s ] [ %s ] null auto_bidi` |

`%g` is `vcc`. **`vcc` defaults to 3.3 V** when no `.param vcc` is in scope —
`evtcheck_nodes.c:616` `vcc = 3.3; // Fallback default for digital.` For any other node
type the fallback is `vcc = 0` and, with no user-supplied variable, the circuit **fails**.

**[observed]** confirming the 1.65 V threshold in a ramp: `in2` ramping 0→3.3 V over 10 ns
produced its event transition at t = 6.056 ns ≈ 5.0 ns (1.65 V crossing) + 1.0 ns
(`adc_bridge` default `rise_delay`).

### 6.4 The lookup order (paraphrased from `evtcheck_nodes.c:84-171`)

1. Variable `auto_bridge_parm_<TYPE>` names a `.param` to use as `vcc`; for `d` nodes the
   parameter name defaults to `vcc`.
2. That parameter is searched from the most deeply nested XSPICE device outward through
   enclosing subcircuits.
3. Unless `no_auto_bridge_family` is set: search the connected instances (then enclosing
   subcircuits) for a string parameter `family`. If found and not starting with `*`, try
   `.include bridge_<FAMILY>_<TYPE>_<DIR>.subcir` with device card
   `Xauto_bridge%d %s %s bridge_<FAMILY>_<TYPE>_<DIR> vcc=%g`.
4. Else variable `auto_bridge_<FAMILY>_<TYPE>_<DIR>`.
5. Else variable `auto_bridge_<TYPE>_<DIR>` where `<DIR>` ∈ {`in`,`out`,`inout`}.
6. The variable's value is a list of 2 or 3 elements: `setup card`, `device card`, optional
   integer max-nodes-per-device. The setup card is `sprintf`'d with up to **five** copies of
   `vcc` (`evtcheck_nodes.c:815`).

Variables must be set **before** the netlist is parsed, hence `pre_set` (see §11.4).

### 6.5 Non-digital bridging **[observed]** and a landmine

A `real`-typed event node touching an analog node with no `auto_bridge_real_out` variable:

```
Evtcheck_nodes: Can not insert bridge for mixed-type node rout

Error: circuit not parsed.
```
(`evtcheck_nodes.c:1023-1027`.)

The example in the source comment (`evtcheck_nodes.c:151-152`) is **wrong on two counts**:

```
   set auto_bridge_real_out = ( ".model real_to_v_bridge r_to_v"
   + "areal_bridge%d %s null %s real_to_v_bridge" 1 )
```
* the shipped model is named `real_to_v`, not `r_to_v`
  (`src/xspice/icm/xtraevt/real_to_v/ifspec.ifs:4`);
* `real_to_v` has exactly two ports, `in` (real) and `out` (v)
  (`ifspec.ifs:11-18`), so the `%s null %s` three-token device card is malformed.

**[observed]** using that card verbatim **segfaults ngspice (exit 139) with no output at
all**. Correcting it to `"areal_bridge%d %s %s real_to_v_bridge"` works and prints
`v(rout) = 3.300000e+00` with `edisplay` reporting `rout : real`.

**GUI rule:** never let a user hand-edit an `auto_bridge_*` format string without
validation. A mismatch between the format's `%s` count and the model's port count kills the
process silently. Prefer offering a curated list of bridge recipes.

### 6.6 What the GUI must expose

* whether auto-bridging is on/off/verbose (`auto_bridge`)
* the effective `vcc` (a `.param vcc=` in the deck, or 3.3 default)
* the family mechanism (`.param family=` / instance `family=` parameter), which most
  `d_*` models accept (`family` is in `adc_bridge`'s parameter table at
  `src/xspice/icm/digital/adc_bridge/ifspec.ifs:85-92`)
* a way to *see* the generated sub-deck (`auto_bridge=2`) — it belongs in a "generated
  netlist" pane, since bridge parameters silently determine every logic threshold

---

## 7. The event-specific commands and outputs

All five are registered inside `#ifdef XSPICE` at `src/frontend/commands.c:266-286`.

### 7.1 `esave` — choose which event nodes keep a history

`EVTsave` at `src/xspice/evt/evtprint.c:971`.
Usage string: `esave all | none | <node1> <node2> ...`.
Default is **save everything**: `node->save = MIF_TRUE` when a node is interned
(`src/xspice/evt/evttermi.c:420`, comment "Backward compatible behaviour: save all").
The flag is consumed in `EVTaccept` (`src/xspice/evt/evtaccept.c:219-234`): unsaved nodes
keep only the most recent value (needed for backup) and everything else is recycled.
Must be issued **before** the run. **[observed]** `esave dout` then `tran` →
`edisplay` showed `dout: 10` events, `in1: 1`, `in2: 1`.

### 7.2 `eprint` — tabular event dump

`EVTprint` at `src/xspice/evt/evtprint.c:101`. Usage: `eprint <node1> <node2> ...`.
Documented limitations are in the file's own header comment (`evtprint.c:72-95`):
1. at most **93** nodes (`EPRINT_MAXARGS`, `evtprint.c:99`);
2. **no member selection** — it always prints `"all"` (`evtprint.c:204`, `evtprint.c:231`);
3. crude fixed formatting (4 spaces between columns, `evtprint.c:369-394`);
4. **only the most recent simulation**, i.e. it ignores the `jobs` structure;
5. no time-range selection.

Output has three sections. **[observed]**:

```
**** Results Data ****

Time or Step
dout


0.000000000e+00    1s
3.065000000e-09    0s
...

**** Messages ****

<per-port cm_message_send() output, or empty>

**** Statistics ****

Operating point analog/event alternations:  2
Operating point load calls:                 9
Operating point event passes:               3
Transient analysis load calls:              663
Transient analysis timestep backups:        0
```

For an `op` run the step column reads `DCOP` instead of a number
(`evtprint.c:378-381`). Error strings:
* `ERROR - Node %s is not an event node.` (`evtprint.c:166`)
* `ERROR - No node data: simulation not yet run?` (`evtprint.c:172`) **[observed]**
* `Error: no circuit loaded.` (`evtprint.c:154`)
* `eprint: too few args.` from the command-table arity **[observed]**

**[observed] gotcha:** `eprint dout(state)` fails with
`ERROR - Node dout(state) is not an event node.` — `eprint` uses `get_index()`
(`evtprint.c:314`) which does **not** parse the `(member)` qualifier, unlike `plot`/`let`
which go through `Evt_Parse_Node()` (`src/xspice/evt/evtplot.c:106`).

### 7.3 `eprvcd` — VCD writer

`EVTprintvcd` at `src/xspice/evt/evtprint.c:578`.
Usage: `eprvcd [-a] [-t timescale] <node1> <node2> ...`.

* `-a` (`evtprint.c:615-616`) also emits **analog** vectors/expressions at every analog
  timestep, as VCD `real` variables. Any argument that is not an event node is evaluated as
  a control-language expression (`evtprint.c:673-693`); it must be a single word (no spaces).
* `-t <value>` sets the VCD timescale, clamped to the 1 fs … 1 s range
  (`evtprint.c:618-632`, `evtprint.c:735-770`).
* Default timescale is derived from `ckt->CKTstep` (the `.tran` TSTEP), always one decade
  finer: tstep ≥ 1 ms → µs, ≥ 1 µs → ns, ≥ 1 ns → ps, else fs (`evtprint.c:772-792`).
* Digital values are mapped to VCD via `get_vcdval()` (`evtprint.c:461-489`): the 12 XSPICE
  strings collapse to `0 1 x z`; anything parseable as a number becomes a VCD `real`.
* Same 93-argument cap.
* Known missing (source comment, `evtprint.c:574`): **hierarchy and bit vectors**. Every
  signal is a scalar `$var wire 1` or `$var real 1`.

**[observed]** `eprvcd -a -t 1p dout v(out) > mix.vcd` produced:

```
$date September 09, 2026 18:59:21 $end
$version ngspice 46+ $end
$timescale 1 ps $end
$var wire 1 ! dout $end
$var real 1 " v(out) $end
$enddefinitions $end
$dumpvars
1!
r3.3 "
$end
#3064
0!
...
```

The command writes to stdout, so a GUI redirects with `> file.vcd` inside `.control`.

### 7.4 `edisplay` — enumerate event nodes

`EVTdisplay` at `src/xspice/evt/evtprint.c:399`. Takes **no** arguments (`commands.c:280`
declares `0, 0`) despite its help text. Prints node name, type name, and event count.
Works **before** a run (all counts 0) **[observed]** — so a GUI can enumerate the event
nodes of a parsed circuit without simulating, which is exactly what a signal-selection
dialog needs.

**[observed]**, after a run:
```
List of event nodes in plot tran1
    node name           : type , number of events

    in1                 : d    ,    10
    in2                 : d    ,     1
    dout                : d    ,    10
```
The "in plot tran1" line comes from `ckt->evt->jobs.job_plot[cur_job]` (`evtprint.c:420-423`).

Hierarchical names use `.`: **[observed]** a subcircuit `x1` gave event nodes
`x1.dint`, `x1.dy` (and the auto-generated instance name `a.x1.abrg`).

### 7.5 `plot` / `print` / `let` — event nodes as pseudo-vectors

`EVTfindvec()` (`src/xspice/evt/evtplot.c:202`) is called from `findvec()`
(`src/frontend/vectors.c:255` and `:338`) whenever a name is not found among analog
vectors. It builds a **fresh, non-permanent** `dvec` with:

* a step-shaped waveform (two points per event, so the trace has vertical edges,
  `evtplot.c:239-262`)
* **its own scale vector** named `<node>_steps`, typed `SV_TIME`
  (`evtplot.c:287-290`)
* both flagged `VF_EVENT_NODE` (`src/include/ngspice/dvec.h:21`)
* the data vector typed `SV_VOLTAGE` (so it plots on a voltage axis)
* a final point extended to `ckt->CKTtime` (`evtplot.c:266-268`)

The optional member qualifier `node(member)` is parsed by `Evt_Parse_Node()`
(`evtplot.c:106`); member names are lowercased, node names are not
(case handling per `Evt_Node_Name_Eq()`, `evtplot.c:62`).

**Consequences a GUI must handle:**

* **[observed]** `let a = dout(state)` works and gives a 6-point vector for a 90-point
  transient. `plot dout` works. **`print dout` mostly prints blanks**, because `print`
  aligns everything to the plot's default scale (`time`) and the event vector's scale is
  `dout_steps`. Do not use `print` for event nodes.
* `EVTfindvec` reads `g_mif_info.ckt` — **the currently loaded circuit**, not the plot's
  circuit. Event vectors cannot be recovered from a loaded rawfile or after `remcirc`.
* `plot ... digitop` stacks event traces with a vertical offset
  (`src/frontend/plotting/plotit.c:370`, `:896-935`); the spacing is the control variable
  `plot_auto_spacing`, **default 1.5** (`plotit.c:901-904`). This is the ngspice equivalent
  of a waveform-viewer digital pane and the GUI should offer it.

### 7.6 Rawfile behaviour — the trap

**[observed]** three separate results, all on the same deck:

1. `write out.raw all` → the rawfile contains **only** the analog vectors
   (`time, i(abrg), v(in1), v(in2), v(out), i(vin1), i(vin2)`). `dout` is absent, silently.
2. `write out2.raw v(out) dout` → the rawfile *does* contain `dout` and `dout_steps`, but
   declared as `dims=10` while `No. Points: 119`. Reading it back gives 119-long vectors
   where entries 10..118 are **zeros**:
   ```
   dout_steps[9]  = 1.000000e-08
   dout_steps[10] = 0.000000e+00
   dout_steps[11] = 0.000000e+00   ...
   ```
   i.e. the event vector is zero-padded to the analog length on write and not truncated on
   read.
3. `ngspice -b -r file.raw` with `.save v(out) dout` → `dout` absent (see §5.7).

**Therefore: the rawfile is not a viable transport for event data.** The GUI's options are
(a) `eprvcd` to a VCD file and read that, (b) `eprint` and parse the text, (c) libngspice
callbacks (§8).

---

## 8. Reading event results back programmatically (libngspice)

Declared in `src/include/ngspice/sharedspice.h`, all inside `#ifdef XSPICE`.

| symbol | line | what it does |
|---|---|---|
| `char** ngSpice_AllEvtNodes(void)` | `sharedspice.h:474` | NULL-terminated array of event node names; implemented as `EVTallnodes()` (`src/xspice/evt/evtshared.c:262`) |
| `pevt_shared_data ngGet_Evt_NodeInfo(char* nodename)` | `sharedspice.h:470` | full history of one node as `{int dcop; double step; char *node_value;}[]` (`sharedspice.h:280-292`); implemented as `EVTshareddata()` (`evtshared.c:76`). `node_value` is the `print_val` string, e.g. `"1s"`. Passing NULL frees the previous result. |
| `int ngSpice_Init_Evt(SendEvtData*, SendInitEvtData*, void*)` | `sharedspice.h:482` | register two callbacks: a per-node dictionary callback at init, and a per-node/per-accepted-timestep data callback |
| `int ngSpice_Raw_Evt(const char* node, SendRawEvtData*, void*)` | `sharedspice.h:495` | per-event callback on one node; returns the node's UDN type index or −1. Only **one** callback pointer is stored globally — the last one wins. |
| `int ngSpice_Decode_Evt(void* evt, int type, double *pplotval, const char **pprintval)` | `sharedspice.h:507` | turn a raw value into a plot double and/or a print string; with `evt == NULL` returns the *type name* (`src/sharedspice.c:1423-1435`) |
| `char* ngCM_Input_Path(const char* path)` | `sharedspice.h:465` | set/read `Infile_Path`, used by `fopen_with_path()` for file-reading code models |

`SendEvtData` signature (`sharedspice.h:389-403`):
`int (int node_index, double step, double dvalue, char *svalue, void *pvalue, int plen, int mode, int ident, void* userData)`.
`SendInitEvtData` (`sharedspice.h:404-415`): `(int index, int max_index, char *node_name, char *udn_name, int ident, void* userData)`.

**Case rules** are spelled out at `sharedspice.h:67-91`: under `casemode=fold`/`preserve`
these lookups accept any case; under `casemode=distinguish` they require the stored
spelling. The safe rule in every mode: use the string `ngSpice_AllEvtNodes()` returned.

**A caveat in the dictionary path:** `EVTdump()` (`src/xspice/evt/evtdump.c:110`) filters the
dictionary to "nodes not within subcircuits", and it tests for a `':'` in the node name
(`evtdump.c:209-217`). But subcircuit-expanded **node** names use `'.'`
(**[observed]**: `x1.dint`) — `':'` is used for expanded **model** names
(**[observed]**: an error message showed `x1:myinv`). So in practice the filter never fires
and all event nodes are reported. Do not rely on either behaviour; enumerate with
`ngSpice_AllEvtNodes()`.

Also see `README.shared-xspice` (repo root) for the `save none` trick that suppresses analog
storage while keeping callbacks.

---

## 9. Jobs, plots, and `setplot`

Each analysis run appends a "job" to `ckt->evt->jobs` (`EVTsetup_jobs`,
`src/xspice/evt/evtsetup.c:482-517`), capturing that run's `node_data`, `state_data`,
`msg_data` and `statistics`. `EVTsetup_plot()` (`evtsetup.c:635`) is called from
`src/frontend/outitf.c:503` to record which analog plot name (`tran1`, `dc1`, `op1`, …)
belongs to the job, and `EVTswitch_plot()` (`evtsetup.c:652`) is called from
`src/frontend/vectors.c:1411` when the user runs `setplot`, so switching plots switches the
event data too.

**GUI consequence:** `setplot tran2; edisplay` shows the second transient's event nodes.
But `eprint` explicitly ignores the jobs structure (its own comment, `evtprint.c:88-89`,
item 4: "It works only for the latest simulation"), so `eprint` after `setplot` may not
agree with `edisplay`. Verify before relying on it.

All of this requires the circuit to still be loaded. Destroying the circuit destroys the
event history (`src/xspice/evt/evtdest.c:268-282`).

---

## 10. `d_cosim` and Verilog/VHDL co-simulation

### 10.1 The model card

Interface: `src/xspice/icm/digital/d_cosim/ifspec.ifs`.

Ports (all `d`, all vectors, all `Null_Allowed: yes`):
`d_in` (in), `d_out` (out), `d_inout` (inout).

Parameters:

| name | type | default | meaning |
|---|---|---|---|
| `simulation` | string | **required** (`Null_Allowed: no`) | shared library holding the compiled design (or the shim) |
| `delay` | real | `1.0e-9` (limit ≥ 1e-12) | output delay applied to every output port |
| `lib_args` | string vector | — | argv handed to the shim library |
| `sim_args` | string vector | — | argv handed to the simulation itself |
| `queue_size` | int | `128` (limit ≥ 1) | internal input event queue; comment recommends > `(2*F)/MTS` for clocked logic |
| `irreversible` | int | `1` | value passed to `cm_irreversible()` |

Minimal deck (from `examples/xspice/verilator/pwm.cir`):

```
adut null [ out ] pwm_sin
.model pwm_sin d_cosim simulation="./pwm"
```

`null` is the placeholder for an unconnected port group.

### 10.2 The two backends

**Verilator** — the user must run, from the directory holding the Verilog:

```
ngspice vlnggen 555.v                  # simple designs
ngspice vlnggen -- --timing delay.v    # '--' passes flags to Verilator
```
(`examples/xspice/verilator/README.txt`.) This produces `555.so` (`555.DLL` on Windows).

`vlnggen` is **an ngspice interpreter script, not a shell script** — it starts with
`*ng_script_with_params` (`src/xspice/verilog/vlnggen:1`) and is written in ngspice control
language: `set`, `if`, `fopen`, `$oscompiled`, `shell`. It is installed to
`$pkgdatadir/scripts/vlnggen` and is found because `Lib_Path` is on `sourcepath`
(`src/misc/ivars.c:75`, `src/frontend/cpitf.c:249-253`). It compiles
`verilator_shim.cpp` + `verilator_main.cpp` (installed to
`$pkgdatadir/scripts/src/`) together with Verilator's generated C++, and links
`Vlng__ALL.a` plus the global objects; object selection is probed with `fopen` because
which globals exist depends on the Verilator flags. It refuses to run if an `inputs.h`
exists in the CWD (`vlnggen:70-79`).

**Icarus Verilog** — must be built with `--enable-libvvp`. The user runs
`iverilog -o 555 ../verilator/555.v`, then the model card points at ngspice's own shim:

```
.model vlog_ff d_cosim sim_args=["555"]
+ simulation = "ivlng"
+ lib_args = [ "libvvp" "<path>/ivlngvpi.so" ]
```
(`examples/xspice/icarus_verilog/README.txt`.) `ivlng.so` and `ivlng.vpi` are built by the
ngspice build itself and installed to `$pkglibdir` — **[observed]** both are present in
`build-ver_50/stage/lib/ngspice/`.

**GHDL/VHDL** — the same `d_cosim` mechanism with `ghnggen`
(`src/xspice/vhdl/ghnggen`, `ghdl_shim.c`, `ghdl_vpi.c`). Examples in
`examples/xspice/ghdl/`. Not exercised in this session.

### 10.3 The shim contract

`src/include/ngspice/cosim.h`. The shared library must export
`void Cosim_setup(struct co_info *pinfo)`. `struct co_info` carries port counts, a `step()`
function, `in_fn`/`out_fn`, a mutable `vtime`, the `lib_argv`/`sim_argv` arrays, a
`dlopen_fn` helper, and a `Cosim_method` enum (`Normal`, `After_input`, `Both` —
`cosim.h:17`) that exists because "Verilator does nothing without an input change, so
`step()` must be called after input".

### 10.4 Library resolution and failure mode

`cosim_dlopen()` (`src/xspice/icm/digital/d_cosim/cfunc.mod:158-185`) tries, for each of
`""`, `".so"` (plus `.DLL` on Windows, `.dylib` on macOS): first the name as given, then
`NGSPICELIBDIR "/" name`. On failure it prints to stderr and returns NULL.

**[observed]** with `simulation="./nosuchlib"`:

```
Cannot open shared library ./nosuchlib: /home/analog/dev/ngspice/build-ver_50/stage/lib/ngspice/./nosuchlib.so: cannot open shared object file: No such file or directory
...
Instance: adut   Message: d_cosim failed to load simulation binary ./nosuchlib.
```

and then **the transient ran to completion with exit status 0**, producing analog results
with the co-simulated block doing nothing (`cfunc.mod:492-495` just `return`s and
`cfunc.mod:619-621` treats the instance as "error state, do nothing at all").

**GUI rule: a missing co-simulation library is a soft failure that yields plausible wrong
answers.** The GUI must scan run output for `d_cosim failed to load simulation binary` and
`Cannot open shared library` and mark the run invalid.

### 10.5 Irreversibility

`cm_irreversible(place)` (`src/xspice/cm/cm.c:749`) marks an instance as un-backup-able and
positions it in the hybrid call order (lower `place` = called earlier / more protected).
It may only be called during INIT: `"%s: Ignoring call to cm_irreversible(): not in INIT"`
(`cm.c:761`), and a repeat call gives
`"%s: Ignoring new value %d in cm_irreversible()"` (`cm.c:767`) or
`"Warning: Duplicate value %d in cm_irreversible() for instance %s."` (`cm.c:744`).
The transient loop honours it at `dctran.c:805-820`.

### 10.6 File-reading code models and the working directory

`file_source`, `d_source`, `d_state`, `table2D`, `table3D`, `xfer` all use
`fopen_with_path()`, which searches relative to `Infile_Path` — the directory of the netlist
(`cm_get_path()`, `src/xspice/cm/cm.c:713`). For libngspice, `ngCM_Input_Path()` sets it.
Also, `src/frontend/inpcom.c:416-438` (`is_xspice_model`) keeps the **original case** of
`.model` lines mentioning `filesource`, `table2d`, `table3d`, `d_state`, `d_source`,
`d_process`, `d_cosim` — because their string parameters are filenames. A GUI that
regenerates decks must keep those lines byte-exact.

---

## 11. Options and variables that only matter in mixed mode

### 11.1 `.options` (parsed in `src/spicelib/analysis/cktsopt.c`, table at `:267-276`)

All are inside `#ifdef XSPICE` except `rshunt`, which prints
`"WARNING - Option Rshunt available only with XSPICE enabled."` when XSPICE is off
(`cktsopt.c:253-255`).

| option | type | set at | default | where the default is set |
|---|---|---|---|---|
| `maxopalter` | integer | `cktsopt.c:211` → `evt->limits.max_op_alternations` | `num_hybrid_outputs + 1` | `src/xspice/evt/evtinit.c:365` |
| `maxevtiter` | integer | `cktsopt.c:215` → `evt->limits.max_event_passes` | `num_outputs + 1` | `src/xspice/evt/evtinit.c:359` |
| `noopalter` | flag | `cktsopt.c:218-219` → `evt->options.op_alternate = FALSE` | alternation **ON** | `src/spicelib/devices/cktinit.c:108` |
| `ramptime` | real | `cktsopt.c:223` | `0.0` | `cktinit.c:118` |
| `convlimit` | flag | `cktsopt.c:227` | **already TRUE** | `cktinit.c:119` |
| `convstep` | real | `cktsopt.c:231-232` | `0.25` | `cktinit.c:120` |
| `convabsstep` | real | `cktsopt.c:236-237` | `0.1` | `cktinit.c:121` |
| `autopartial` | flag | `cktsopt.c:241` → `g_mif_info.auto_partial.global` | `MIF_FALSE` | `cktinit.c:133` |
| `rshunt` | real | `cktsopt.c:245-251` | disabled | `cktinit.c:122` |

Notes:

* **`maxevtiter` / `maxopalter` defaults are circuit-dependent**, not constants. They are
  computed in `EVTinit_limits()` from the parsed circuit, and a `.options` value overrides.
  A GUI showing "default" must therefore show "auto (outputs+1)" rather than a number.
* **`convlimit` is already enabled by default in this tree** and there is no option to
  turn it off — `OPT_ENH_CONV_LIMIT` only ever sets TRUE. The mechanism
  (`src/xspice/mif/mifload.c:357-376`) clamps each analog input to a code model to
  `max(|last_input| * convstep, convabsstep)` per Newton iteration and increments
  `CKTnoncon` when it clamps, i.e. it *forces extra iterations*. Raising `convstep` /
  `convabsstep` is the only way to weaken it. **This is a source/doc divergence to check:**
  the manual presents `convlimit` as an enable flag; the source has it on since at least
  commit `8362dec27`. I trust the source (`cktinit.c:119` is unambiguous and long-standing).
* `noopalter` makes `EVTop` return after one pass (`evtop.c:164-165`); the transient loop
  then compensates by calling `EVTiter` once at t=0 (`dctran.c:609-613`,
  `optran.c:601-605`). Use it when a mixed OP will not converge and you only need a
  starting point.
* `rshunt` adds `1/rshunt` to every matrix diagonal (`src/spicelib/analysis/cktload.c:109-114`,
  set up at `cktsetup.c:355-415`, and applied in AC at `acan.c:443-447`). It is the classic
  cure for floating digital-output nodes.
* `ramptime` ramps supplies over the given time in a transient and sets a breakpoint at its
  end (`dctran.c:220-221`); code models read the factor via `cm_analog_ramp_factor()`
  (`src/xspice/cm/cm.c:509-522`). The `optran` command's **6th** argument is a separate
  op-transient ramp (`src/spicelib/analysis/optran.c:50`, `:165`, `:669-671`), defaults
  documented in `README.optran` as `1 1 1 100n 10u 0`, installed by
  `src/frontend/init.c:77-93`.

### 11.2 Control variables

| variable | read at | default | effect |
|---|---|---|---|
| `xtrtol` | `cktdojob.c:83` | unset | overrides the forced `trtol=1` for A-device circuits |
| `auto_bridge` | `evtcheck_nodes.c:975` | `1` (silent) | 0 = off/fatal, 2 = print generated deck |
| `no_auto_bridge_family` | `evtcheck_nodes.c:624` | unset | skip the `family` lookup |
| `auto_bridge_parm_<TYPE>` | `evtcheck_nodes.c:567` | `vcc` for `d` | name of the `.param` that supplies `vcc` |
| `auto_bridge_<FAMILY>_<TYPE>_<DIR>` | `evtcheck_nodes.c:740-742` | unset | custom bridge recipe |
| `auto_bridge_<TYPE>_<DIR>` | `evtcheck_nodes.c:759-761` | unset | custom bridge recipe |
| `plot_auto_spacing` | `plotit.c:901` | `1.5` | digital trace spacing for `plot ... digitop` |
| `xspice_enabled` | set by `main.c:943` | TRUE in this build | spinit gate |
| `strict_errorhandling` | `options.c:376-382` | unset | turn code-model load failure into `exit(EXIT_BAD)` |
| `probe_alli_given` | `evtcheck_nodes.c:980` | set by `.probe alli` | fatal with event nodes |
| `casemode` / `curcasemode` | `sharedspice.h:79-108` | `fold` | changes event-node name matching |

### 11.3 `.param vcc`

Not an option, but it is the single most consequential number in a mixed deck: it sets both
the DAC output swing and the ADC thresholds (`vcc/2`) for every auto-inserted bridge.
Default 3.3 (`evtcheck_nodes.c:616`). It may differ per subcircuit
(`evtcheck_nodes.c:80-96`). **A GUI's mixed-signal panel should surface `vcc` as a
first-class field.**

### 11.4 `pre_set` — setting variables before the netlist is parsed

`src/frontend/inp.c:787-793`: any control-language command written as `pre_<cmd>` inside a
`.control` block (or after `*#`) is stripped of the `pre_` prefix and executed **before**
circuit parsing. This is the supported way to set `auto_bridge*` variables from inside a
deck, and the tests use it (`tests/xspice/digital/auto-bridge-family-empty.cir`).
`-D var=value` on the command line was **[observed]** not to work for `auto_bridge`.

---

## 12. Observed defects and fragility — things a GUI must not walk into

These were all reproduced against `build-ver_50/src/ngspice` in this session. Root causes
are **not** established; they are reported as behaviour.

### 12.1 A `.dc` sweep through an auto-bridged node does not propagate

Deck `dcsw5.cir`:
```
vin1 in1 0 dc 3.3
vin2 in2 0 dc 0
r1 out 0 1k
a1 [in1 in2] dout mynand
abrg [dout] [out] mydac
.model mynand d_nand(rise_delay=1n fall_delay=1n)
.model mydac dac_bridge(out_low=0 out_high=3.3)
.control
dc vin2 0 3.3 0.3
print v(in2) v(out)
.endc
```
Result: `v(in2)` sweeps 0 → 3.3 correctly, `v(out)` stays at 3.3 V for the whole sweep
(it should fall to 0 once `in2` crosses 1.65 V). `eprint in2 dout` reports exactly one
event, at step 0.

The same circuit in a transient **works** (`dcsw4.cir`, transition at 6.056 ns).

### 12.2 The same `.dc` sweep works or fails depending on card ORDER

Writing the ADC bridge explicitly with the *same* node names works — `dcsw6.cir`, bridge
card placed **before** `a1`:
```
aadc [in1 in2] [in1 in2] myadc
a1   [in1 in2] dout mynand
```
gives `v(out)` = 3.3 → 0 at v-sweep 1.8. Moving the identical `aadc` line **after** `a1`
(`dcsw9.cir`) reproduces the 12.1 failure exactly. Auto-generated bridge cards are always
appended at the end of the deck (`evtcheck_nodes.c:1035-1060`), which is presumably why
12.1 happens.

A second, milder DC-sweep artefact: with hysteretic thresholds
(`adc_bridge(in_low=1.0 in_high=2.0)`), the sweep **latches at UNKNOWN** once the input
enters the dead band and never resolves, giving `v(out)` = 1.65 V (the `dac_bridge`
`out_undef` default of 0.5 scaled) from 1.2 V onward.

**GUI action: do not offer `.dc` as a first-class mixed-signal analysis without a loud
warning, and never rely on auto-bridging in a DC sweep.**

### 12.3 `sens` on a deck with A devices is a hard crash

Deck `sens.cir`, `sens v(out)` on the same mixed circuit:
```
Internal Error: node allocation in DEVsetup() during sensitivity analysis, this will cause serious troubles !, please report this issue !

ERROR: fatal error in ngspice, exit(1)
```
Source of the message: `src/spicelib/analysis/cktsens.c:496`. Exit status 1, no results.
**The GUI must refuse `sens` when the deck contains `A` cards** (detect them or read
`ckt->CKTadevFlag` equivalently by grepping the expanded netlist).

### 12.4 A malformed `auto_bridge_*` device card segfaults ngspice

See §6.5. Exit 139, zero output.

### 12.5 `pz` on a mixed deck

**[observed]** `pz in1 0 out 0 vol pz` printed
`doAnalyses: The input signal is shorted on the way to the output / pz simulation(s) aborted`
— but that is a pz-topology complaint on this particular deck, not necessarily an
XSPICE-specific diagnostic. `pzan.c` has no XSPICE code at all, so on a deck where pz *does*
run, the event side is never solved and `g_mif_info.circuit.anal_type` keeps whatever value
the previous analysis left (initialised to `MIF_DC` at `src/xspice/mif/mif.c:53`). Treat pz
results on a mixed deck as unvalidated.

### 12.6 `tf` and `disto` run silently

**[observed]** both completed with no warning on a mixed deck. Neither has any XSPICE hook.
The code models are loaded in whatever `anal_type` was last set — for `tf` after an `op`,
that is `MIF_DC`; for `disto` there is no AC-mode signalling at all
(`distoan.c` never sets `g_mif_info.circuit.anal_type`), so the code models' AC gains
(`mifload.c:618-670`) are never requested. Results are therefore linearised only through
whatever partials the DC load left behind. **Warn.**

---

## 13. The practical question: which analyses should ASE-L offer on a mixed-signal deck?

Recommended GUI policy. "Mixed-signal deck" = the expanded netlist contains at least one
`A` card (equivalently `ckt->CKTadevFlag`, `src/spicelib/parser/inppas2.c:118`).

| Analysis | Offer? | GUI behaviour |
|---|---|---|
| `tran` | **Yes, primary** | Full event support. Show `xtrtol`, `maxevtiter`, `maxopalter`, `noopalter`, `convstep`/`convabsstep`, `rshunt`, `ramptime` in an "XSPICE" sub-panel. Offer a digital waveform pane (`plot … digitop`) and a "export VCD" action (`eprvcd`). |
| `op` | **Yes** | Full event support (alternating solve). Surface the alternation statistics from `eprint`. Offer `noopalter` as the escape hatch when it fails to converge. |
| `dc` | **Yes, with a warning** | Only the first sweep variable is recorded on the event axis (`dctrcurv.c:322-334`); second-sweep nesting is invisible to the event side. Warn that auto-bridged nodes may not track the sweep (§12.1/§12.2) and suggest explicit bridge cards placed **before** the digital instances. |
| `ac` | **Yes, with a caveat** | The bias point is event-aware; the sweep is not. Explain in the UI that digital state is frozen at the OP value and that `edisplay` will show 1 event per node. |
| `noise` | **Yes, with the same caveat** | Additionally: only `ota` among the shipped code models has noise sources; every other code model is noiseless, which will make a mixed-signal noise number optimistic. |
| `sp` | **Yes, same caveat as `ac`** | Requires `RFSPICE` (on here). |
| `optran` | **Yes** (it is a setting, not a menu item) | Full event support; default is already on (`README.optran`, `src/frontend/init.c:77-93`). |
| `pss` | **Not available** | `WITH_PSS` undefined in this build. Grey out unless the GUI detects a PSS-enabled binary (probe with `ngspice -b` on a trivial `.pss` deck, or check `help`). |
| `pz` | **Warn strongly / consider disabling** | No XSPICE support in `pzan.c`. |
| `disto` | **Warn strongly / consider disabling** | No XSPICE support in `distoan.c`. |
| `tf` | **Warn strongly / consider disabling** | No XSPICE support in `tfanal.c`. |
| `sens` | **Refuse** | Hard crash, exit 1 (§12.3). |

Two more hard refusals independent of the analysis:
* `.probe alli` + any event node → fatal (§5.5). If the GUI has a "probe all currents"
  convenience, disable it for mixed decks.
* `snsave`/`snload` → refused for A devices (§5.6).

---

## 14. Grammar a GUI must emit

### 14.1 The `A` card

Parsed by `MIF_INP2A()` (`src/xspice/mif/mif_inp2.c:161`), called from `INPpas2`.
Shape: `A<name> <connection>... <modelname>`.

* A **scalar** connection is one token; a **vector** connection is a bracketed list
  `[ n1 n2 ... ]`. Mixing them wrongly gives, **[observed]**:
  * `ERROR - Scalar connection expected, [ found` (`mif_inp2.c:372`)
  * `Missing [, an array connection was expected`
  * `Encountered end of line before all required connections were found.`
* The literal token `null` marks an unconnected port group.
* A port's electrical type may be overridden inline with `%<type>` before the node(s).
  Types (`src/include/ngspice/miftypes.h:99-112`):
  `v` single-ended voltage, `vd` differential voltage, `i` current, `id` differential
  current, `vnam` current through a named voltage source, `g` VCIS, `gd` differential VCIS,
  `h` ICVS, `hd` differential ICVS, `d` digital, or any user-defined type identifier.
* `~` before a digital node inverts it; it is rejected on analog nodes
  (`mif_inp2.c:850-853`, `"ERROR - Tilde not allowed on analog nodes"`).
* Directions (`miftypes.h:119-123`): `MIF_IN`, `MIF_OUT`, `MIF_INOUT`.

The exact port list, allowed types, vector-ness and null-allowance for each model are in
`src/xspice/icm/<lib>/<model>/ifspec.ifs` under `PORT_TABLE:`. **These files are the
authoritative source for a GUI's device-form generator.** They are plain text and trivially
parseable: `NAME_TABLE:` (Spice_Model_Name, C_Function_Name, Description),
`PORT_TABLE:` (Port_Name, Description, Direction, Default_Type, Allowed_Types, Vector,
Vector_Bounds, Null_Allowed) and `PARAMETER_TABLE:` (Parameter_Name, Description, Data_Type,
Default_Value, Limits, Vector, Vector_Bounds, Null_Allowed). Columns are whitespace-aligned,
one column per parameter/port in the group.

### 14.2 The `.model` card

`.model <name> <codemodeltype>(param=value ...)`. Values may be scalars or bracketed
vectors (`sim_args=["555"]`). Single-quoted values are expressions evaluated during netlist
parsing; braces are stripped by `set`, which is why the auto-bridge defaults use `'...'`
(`evtcheck_nodes.c:139-141`).

---

## 15. Quick reference: the exact strings a GUI should watch for in run output

| String | Meaning | Source |
|---|---|---|
| `Reducing trtol to 1 for xspice 'A' devices` | mixed deck detected, trtol overridden | `cktdojob.c:88` |
| `Override trtol to N for xspice 'A' devices` | `xtrtol` honoured | `cktdojob.c:84` |
| `Error opening code model "X": No such file or directory!` | `.cm` missing | `dev.c:411` |
| `Error: Library X couldn't be loaded!` | ditto, from `codemodel` | `com_dl.c:15` |
| `Warning: code models like X have not been loaded successfully.` | ditto, at netlist read | `inpcom.c:1483` |
| `MIF-ERROR - unable to find definition of model X` | code model type not loaded | `mifgetmod.c:296` |
| `MIF: Unknown device type for model X` | bad model type index | `mifgetmod.c:147` |
| `Evtcheck_nodes: Auto bridging is switched off but node X is mixed-type.` | `auto_bridge=0` | `evtcheck_nodes.c:1017` |
| `Evtcheck_nodes: Can not insert bridge for mixed-type node X` | no recipe for a non-digital type | `evtcheck_nodes.c:1023` |
| `Error: Dot command '.probe alli' and digital nodes are not compatible.` | fatal, exit 1 | `evtcheck_nodes.c:982` |
| `Too many analog/event-driven solution alternations` | `maxopalter` exceeded, returns `E_ITERLIM` | `evtop.c:169` |
| `Cannot open shared library X: ...` | `d_cosim` library missing (non-fatal!) | `d_cosim/cfunc.mod:184` |
| `d_cosim failed to load simulation binary X.` | ditto (non-fatal!) | `d_cosim/cfunc.mod:492` |
| `ERROR: no entry function in X` | shim lacks `Cosim_setup` | `d_cosim/cfunc.mod:499` |
| `Internal Error: node allocation in DEVsetup() during sensitivity analysis` | fatal, exit 1 | `cktsens.c:496` |
| `Warning: snsave not implemented for XSPICE A devices.` | snapshot refused | `spiceif.c:1727` |
| `ERROR - Node X is not an event node.` | `eprint`/`eprvcd` bad name (or a `(member)` qualifier) | `evtprint.c:166` |
| `ERROR - No node data: simulation not yet run?` | `eprint` before a run | `evtprint.c:172` |
| `Warning: Input queue size should be greater than ...` | `d_cosim` `queue_size` too small | `d_cosim/cfunc.mod:580` |
| `Instance: NAME   Message: TEXT` | any `cm_message_send()` from a code model | via `eprint` **** Messages **** and stdout |

---

## 16. Tests in-tree worth reading before changing anything

* `tests/xspice/digital/` — `d_ram.cir`, `d_source.cir`, `d_state.cir` (file-reading models),
  `auto-bridge-family-empty.cir`, `auto-bridge-family-null.cir`,
  `auto-bridge-node-case-fold.cir`, `event-node-case-fold.cir`,
  **`save-event-node.cir`** (asserts that `.save <eventnode>` is silent and that `eprint`
  finds the node in the same run).
* `tests/xspice/case/` and `tests/xspice/casedist/` — the whole auto-bridge + event-node
  name-matching matrix under `casemode=preserve` / `distinguish`.
* Harness: `tests/xspice/digital/spinit.in` shows the minimal spinit a GUI needs —
  `codemodel <builddir>/src/xspice/icm/digital/digital.cm` plus `set sourcepath` and
  `set filetype=binary`. Test driver uses `ngspice -r foobaz` (per `CLAUDE.md`), which is
  exactly the `-r` path that discards event data (§5.7) — the tests that need event data get
  it from `.control` blocks, not the rawfile.

---

## 17. Concrete recommendations for ASE-L

1. **Never launch a mixed-signal run with `-r`.** Generate a `.control` block that runs the
   analysis, then writes analog data with `write` and event data with `eprvcd` (and/or
   `eprint`), and read both files back.
2. **Detect mixedness early.** Parse the expanded netlist for `A` cards, or run
   `ngspice -b` with a `.control` containing only `edisplay` (works before a run, §7.4) to
   enumerate event nodes for a signal-picker.
3. **Signal picker must have two lists**: analog vectors (from `display`/rawfile) and event
   nodes (from `edisplay` / `ngSpice_AllEvtNodes`). `display` does **not** list event nodes
   **[observed]**.
4. **Waveform pane needs a digital lane.** Event vectors have their own scale
   (`<node>_steps`), so a GUI plotting them alongside analog must not assume a common x
   vector. `plot ... digitop` is the built-in stacking mode.
5. **Surface `vcc`, `auto_bridge`, and the generated bridge sub-deck.** These silently set
   every logic threshold. Offering a "show generated netlist" view (`auto_bridge=2`) is
   worth more than any option box.
6. **Gate the analysis menu** per §13, and refuse `sens` outright.
7. **Put `set strict_errorhandling` in the generated spinit** so a broken code-model
   installation is loud.
8. **Harvest model metadata from `ifspec.ifs`** at GUI build time for device forms, and
   cross-check against `showmod all` at runtime for effective values.
9. **Treat `d_cosim` as a build step, not a netlist detail.** The GUI needs a project-level
   "compile Verilog" action that shells `ngspice vlnggen ...` (or `iverilog`), tracks the
   produced `.so`, and refuses to run until it exists — because a missing library is a
   soft failure.
10. **Show the `eprint` statistics block after every mixed run.** It is the only convergence
    diagnostic the event solver produces.

---

## 18. Gaps / not established in this session

* Root cause of §12.1/§12.2 (DC sweep + card order) is **not** identified. `dctrcurv.c`
  calls `EVTcall_hybrids()` then `EVTop()` only when `queue.output.num_changed != 0`
  (`dctrcurv.c:352-353`); why an identical `adc_bridge` behaves differently based on its
  position in the deck was not traced.
* The ngspice HTML manual could not be retrieved in full by the fetch tool — only the
  introductory chapters came back. The one quotable statement obtained is in §2.1. The
  documented text for `eprint`, `eprvcd`, `esave`, `edisplay`, `codemodel`, `auto_bridge`
  and all the XSPICE `.options` was **not** verifiable against the official docs in this
  session; everything in §7 and §11 comes from source plus live runs.
  (https://ngspice.sourceforge.io/docs/ngspice-html-manual/manual.xhtml,
  https://ngspice.sourceforge.io/docs/ngspice-manual.pdf)
* `pss` behaviour with event nodes is unverified — the analysis is not built here.
* GHDL/VHDL co-simulation (`ghnggen`) was not exercised; only its presence confirmed.
* The IPC path in `EVTdump()` (`Ipc_Anal_t`, `src/include/ngspice/ipc.h`) — the original
  ATESSE/CAE client-server transport — was not exercised. It is a third, legacy route for
  event data that may or may not still function.
* Whether `eprint` after `setplot <otherplot>` reports the switched job or the last run was
  not tested; the source comment and `EVTswitch_plot()` disagree in spirit (§9).
* `bidi_bridge` and the INOUT auto-bridge path were not exercised live.
* Multi-driver resolution behaviour (`resolve`) on `d` and `real` nodes was read but not
  exercised.
* Behaviour under `casemode=preserve` / `distinguish` for event nodes was read from source
  and from the test-suite names only; not exercised.
