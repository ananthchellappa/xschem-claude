# Dossier: the OFFICIAL ngspice documentation as a cross-check on the analysis surface

Area owner: docs/web agent. Scope: **analysis only** — analysis types, the options that
configure them, how a run is launched, and what it produces.
Audience: a future Claude Code session building Xschem ASE-L.

Every claim below is anchored either to a URL (documentation) or to `file.c:LINE` in
`/home/analog/dev/ngspice` (source, used only to confirm/refute the docs).

---

## 0. Provenance — what I actually read, and how current it is

### 0.1 Pages read

| # | URL | What it is | How read |
|---|-----|-----------|----------|
| D1 | https://ngspice.sourceforge.io/docs.html | documentation index | WebFetch |
| D2 | https://ngspice.sourceforge.io/docs/ngspice-html-manual/manual.xhtml | **the HTML manual — the primary source for this dossier** | downloaded in full (4,787,081 bytes) and mined locally |
| D3 | https://ngspice.sourceforge.io/tutorials.html | tutorial index | WebFetch |
| D4 | https://ngspice.sourceforge.io/ngspice-tutorial.html | "ngspice tutorial for beginners" | downloaded, read |
| D5 | https://ngspice.sourceforge.io/ngspice-control-language-tutorial.html | "ngspice control language" tutorial | downloaded, read |
| D6 | https://ngspice.sourceforge.io/ngspice-eeschema.html | KiCad/Eeschema GUI tutorial | downloaded, skimmed |
| D7 | https://ngspice.sourceforge.io/ngspice-electrothermal-tutorial.html | electro-thermal tutorial | downloaded, not mined (out of scope) |

Local copies live in
`/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/manual/`.

Other documents `docs.html` (D1) offers but that are **not** the manual, listed here so nobody
re-hunts them: `ngspice-47-manual.pdf`, `ngspice-manual.pdf` ("updated"),
`ngspice-43/44/45/46-manual.pdf`, and a set of internal control-flow spreadsheets under
`./docs/cf/` (`ngspice_top-level_control-flow.xlsx`, `op_operating_point.xlsx`,
`model_parsing.xlsx`, `time-step-control.docx`, `matrix-setup.docx`, `netlist-parsing.docx`,
`devices-input-output.docx`). The `op_operating_point.xlsx` and `time-step-control.docx`
sheets are the only ones plausibly relevant to an analysis GUI and I did **not** open them
(binary Office formats) — see Gaps.

### 0.2 The HTML manual's version, and how it lines up with this tree

- Manual title, verbatim: **"Ngspice User's Manual / Version 47 / (ngspice release version)"**,
  authors Holger Vogt, Giles Atkinson, Dietmar Warning, Paolo Nenzi, dated **August 11th, 2026**
  (D2, title block).
- The manual's own "How to use this Manual" says a manual whose name contains `Version xxplus`
  tracks the Git tip; this one does **not**, so it is pinned to the ngspice-47 release (D2,
  front matter).
- This tree: `git describe` = `ngspice-46-419-gccebdf2a2`, HEAD dated 2026-08-15; the binary
  banner prints `ngspice-46+` (`build-ver_50/src/ngspice --version`). `NEWS:1` in this tree
  reads `Ngspice-47, June ??, 2026`, i.e. the tree **is** the pre-47 development line
  (`CLAUDE.md` says `pre-master-47` is the upstream-tracking branch).

**Verdict: the manual (v47, Aug 2026) and this tree (pre-47, Aug 2026) are essentially
contemporaneous.** The manual is *not* meaningfully ahead or behind upstream. It *is*
behind on this fork's local work — see §14.

### 0.3 Deep-linking into the manual

The XHTML manual carries readable anchor ids on most headings, so a plan can cite exact
sections. Format: `https://ngspice.sourceforge.io/docs/ngspice-html-manual/manual.xhtml#<id>`.
Useful ones:

```
#sec_Analyses                      11.3 Analyses
#subsec__AC__Small_Signal_AC       11.3.1 .AC
#subsec__DC__DC_Transfer           11.3.2 .DC
#subsec__DISTO__Distortion_Analysis 11.3.3 .DISTO
#subsec__NOISE__Noise_Analysis     11.3.4 .NOISE
#subsec__OP__Operating_Point       11.3.5 .OP
#subsec__PZ__Pole_Zero_Analysis    11.3.6 .PZ
#subsec__SENS                      11.3.7 .SENS
#subsec__SP_S_Parameter            11.3.8 .SP
#subsec__TF__Transfer_Function     11.3.9 .TF
#subsec__TRAN__Transient_Analysis  11.3.10 .TRAN
#subsec_Transient_noise_analysis   11.3.11 transient noise
#subsec__PSS__Periodic_Steady_State_Analysis  11.3.12 .PSS
#sec_Simulator_Variables           11.1 .options
#subsec_General_Options            11.1.1
#subsec_DC_Solution_Options        11.1.2
#subsec_AC_Solution_Options        11.1.3
#subsec_Transient_Analysis_Options 11.1.4
#subsec__MEAS                      11.4 measurements
#sec_Batch_Output                  11.6 batch output
#subsec__PROBE__Name_vector_s_     11.6.5 .PROBE
#sec_SOA_Warnings                  11.5 SOA
#sec_Commands                      13.5 commands
#sec_Compatibility                 12.11 compatibility
#sec_Starting_options              12.4 starting options
#sec_Standard_configuration_file   12.5 spinit
#sec_User_defined_configuration    12.6 .spiceinit
#sec_Debugging_a_circuit           12.17 debugging
#subsec_RF_Port                    4.1.11 RF port (needed by .sp)
```

Headings **without** an anchor id (so only reachable by scrolling / text search) include
11.2 Initial Conditions, 11.1.5–11.1.7, 11.4.1–11.4.7, 11.4.11–11.4.12, and — notably —
the `13.5.18 Dc`, `13.5.52 Noise`, `13.5.53 Op`, `13.5.68 Run`, `13.5.71 Sens`,
`13.5.97 Tf` command sections. Also, `13.5.88 Sp` carries the wrong anchor
`subsec_Spec__Create_a_1` (a copy-paste artefact from the neighbouring `Spec` section).

---

## 1. The manual's canonical inventory of analyses

### 1.1 The dot-command list (manual §2.2, the manual's own alphabetical index)

This is the manual's closed list of dot commands. Analysis- or analysis-support-related
entries, with the manual's own one-line gloss:

| Card | Manual's gloss | Section |
|------|----------------|---------|
| `.AC` | start an ac simulation | 11.3.1 |
| `.DC` | start a dc simulation | 11.3.2 |
| `.DISTO` | start a distortion analysis simulation | 11.3.3 |
| `.FOUR` | Fourier analysis of transient simulation output | 11.6.4 |
| `.IC` | set initial conditions | 11.2.2 |
| `.MEAS` | measurements during the simulation | 11.4 |
| `.NODESET` | set initial conditions | 11.2.1 |
| `.NOISE` | start a noise simulation | 11.3.4 |
| `.OP` | start an operating point simulation | 11.3.5 |
| `.OPTIONS` | set simulator options | 11.1 |
| `.PLOT` | printer plot during batch simulation | 11.6.3 |
| `.PRINT` | tabular listing during batch simulation | 11.6.2 |
| `.PROBE` | save device currents, voltages and differential voltages | 11.6.5 |
| `.PSS` | start a periodic steady state analysis | 11.3.12 |
| `.PZ` | start a pole-zero analysis simulation | 11.3.6 |
| `.SAVE` | name simulation result vectors to be saved | 11.6.1 |
| `.SENS` | start a sensitivity analysis | 11.3.7 |
| `.SNDPARAM` / `.SNDPRINT` | provide data for / write a sound file | 11.6.8 |
| `.SP` | S parameter analysis | 11.3.8 |
| `.TEMP` | set the circuit temperature | 2.14 |
| `.TF` | start a transfer function analysis | 11.3.9 |
| `.TRAN` | start a transient simulation | 11.3.10 |
| `.WIDTH` | width of printer plot | 11.6.7 |

**`.STEP` is absent from this list, deliberately.** See §10.

### 1.2 Chapter 1.2 "Supported Analyses" — and why it is stale

§1.2 lists only: DC (op + sweep), AC small-signal, Transient, Pole-Zero, Small-Signal
Distortion, Sensitivity, Noise; §1.2.8 then adds PSS as "Experimental code".

**§1.2 omits `.SP` (S-parameter) and `.TF` entirely, and omits transient noise.** Chapter 11.3
documents all three. I trust **chapter 11.3**: it is the reference chapter, `.sp` is
build-gated ON by default in this tree (`configure.ac:1220-1230`, `RFSPICE` defined at
`build-ver_50/src/include/ngspice/config.h:535`), and I ran it (§16.2).

§1.2 also asserts: "the Code Model subsystem … does not implement Pole-Zero, Distortion,
Sensitivity and Noise analyses" and "Event-driven applications … may make use of DC
(operating point and DC sweep) and Transient only."
**The noise half of that is now false.** Manual §24.8 "Small signal noise in analogue code
models" documents `MIFnoise()`, the reserved parameters
`noise_voltage / noise_current / noise_corner / noise_exponent` (declarative mode) and
`cm_noise_add_source()` + `noise_programmatic=TRUE` (programmatic mode). Confirmed present in
this tree: `src/xspice/mif/mifnoise.c`, `src/xspice/cm/cm.c`,
`src/xspice/icm/analog/gain/ifspec.ifs:58` (`noise_voltage`), and
`src/xspice/icm/analog/ota/cfunc.mod`. `NEWS` in this tree lists
"Implement small signal noise simulation for code models" as a 47 feature.
**Trust §24.8, not §1.2.**

### 1.3 The interactive command list (manual §13.5) vs. reality

The manual's §13.5 documents these analysis-launching commands:
`ac` (13.5.1), `dc` (13.5.18), `noise` (13.5.52), `op` (13.5.53), `run` (13.5.68),
`sens` (13.5.71), `sp` (13.5.88), `tf` (13.5.97), `tran` (13.5.99), plus `bg_run` (13.5.10).

**Three analyses have a dot card documented but no §13.5 command section: `pz`, `disto`,
`pss`.** §11.3.6 says only, in passing, "In interactive mode, the command syntax is the same
except that the first field is `pz` instead of `.pz`." Nothing analogous is said for `disto`.
Confirmed against the tree: `src/frontend/commands.c` registers `pz` and `disto` (and `pss`
under `#ifdef WITH_PSS` at `src/frontend/commands.c:324-330`), and the built binary's
`help all` prints:
```
disto [.disto line args] : Do an distortion analysis.
pz [.pz line args] : Do a pole / zero analysis.
```
So `pz` and `disto` are first-class interactive commands that the manual never documents as
such. **A GUI must offer them.**

Also observed while cross-checking (not a doc issue, but a trap): the binary's own one-line
help for `tf` is wrong — `src/frontend/commands.c` gives `tf` the string
`"[.tran line args] : Do a transient analysis."`. Do not scrape `help all` for `tf`'s syntax.

---

## 2. Per-analysis reference, as the manual states it

Every "General form" block below is the manual's own text, verbatim.

### 2.1 `.OP` — operating point (§11.3.5)

```
.op
```
"Compute the DC operating point of the circuit with inductors shorted and capacitors opened."

Convergence-aid ladder, in order (the manual's own enumeration):
1. **gmin stepping** (`gminsteps` option)
   - `gminsteps = 0`: no gmin
   - `gminsteps = 1`: two gmin stepping processes in series (**default**)
   - `gminsteps = 2`: original SPICE 3 gmin
2. **source stepping** (`srcsteps` option)
   - `srcsteps = 0`: none
   - `srcsteps = 1`: Gillespie source stepping (**default**)
   - `srcsteps = 2`: original SPICE 3 source stepping
3. **transient operating point** ("optional")

"DC analysis is complete as soon as one successful step is found."

Detail: "Switch gmin to a start value (1e-3), followed by a first trial of gmin stepping,
using the true device gmin, then try dynamic gmin stepping with diagonal parallel gmin
elements. **If variable `dyngmin` is set, only dynamic gmin stepping is used.**"

**Source confirms the mode semantics exactly** — `src/spicelib/analysis/cktop.c:57-92`:
`CKTnumGminSteps == 1` → `dynamic_gmin()` then `new_gmin()` (or only `dynamic_gmin()` when
`cp_getvar("dyngmin", …)`); `>= 2` → `spice3_gmin()`. `CKTnumSrcSteps == 1` → `gillespie_src()`;
`>= 2` → `spice3_src()`. Defaults verified by running `option` in the built binary:
`gminsteps = 1`, `srcsteps = 1`.

**`dyngmin` is documented only in this paragraph** — it is missing from the §13.7 variable
table. Same for `newtrunc`/`lte*` (documented in §12.12, not §11.1).

#### `optran` — the transient-operating-point command (§11.3.5)

```
optran !noopiter gminsteps srcsteps tstep tstop supramp
```
Examples given: `optran 0 0 0 100n 10u 0` (skip op iteration, no gmin, no source stepping,
go straight to transient op) and `optran 1 1 1 100n 10u 0` ("restores the initial
conditions"). "Flag `supramp` is currently not used." May be placed in `.spiceinit`, `spinit`
or a `.control` section.

The manual's prose says the transient-op defaults are "**optran step size 10n**, total optran
time 10u". **This is wrong for this tree.** `src/frontend/init.c:77-94` calls
`com_optran()` at init with the literal argument vector `1 1 1 100n 10u 0` — step **100n**,
not 10n. The comment there reads "To make optran the standard, call com_optran here."
So (a) the default step is 100n, and (b) the transient-op fallback is armed by default,
which makes the manual's "transient operating point (optional)" understate it.
**Trust the source.**

Also §11.3.5, important for GUI plot bookkeeping: an op analysis is run implicitly before
`.tran` (unless `uic`), and before AC / Noise / PZ. "These data are not stored, except for
setting the `KEEPOPINFO` variable (11.1.2), that prompts creating an OP plot in addition to
the TRAN, AC, Noise, or PZ plots."

### 2.2 `.DC` — DC transfer curve (§11.3.2)

```
.dc srcnam vstart vstop vincr [src2 start2 stop2 incr2]
```
Examples, verbatim:
```
.dc VIN 0.25 5.0 0.25
.dc VDS 0 10 .5 VGS 0 5 1
.dc VCE 0 10 .25 IB 0 10u 1u
.dc RLoad 1k 2k 100
.dc TEMP -15 75 5
```
"`srcnam` is the name of an independent voltage or current source, **a resistor, or the
circuit temperature**." Capacitors open, inductors shorted. With `src2`, "the first source is
swept over its own range for each value of the second source."

**GUI note:** a `.dc` sweep target is one of four kinds — V source, I source, **resistor**, or
`TEMP`. Cadence ADE exposes this as separate "DC sweep variable" kinds; ngspice folds them
into one positional slot. Only **two** nesting levels exist.

Interactive form (§13.5.18): `dc Source Vstart Vstop Vincr [ Source2 Vstart2 Vstop2 Vincr2 ]`.

### 2.3 `.AC` — small-signal AC (§11.3.1)

```
.ac dec nd fstart fstop
.ac oct no fstart fstop
.ac lin np fstart fstop
```
Examples: `.ac dec 10 1 10K`, `.ac dec 10 1K 100MEG`, `.ac lin 100 1 100HZ`.

Manual's own caveats, quoted/paraphrased:
- "at least one independent source must have been specified with an `ac` value";
  "Typically it does not make much sense to specify more than one ac source. If you do, the
  result will be a superposition of all sources and difficult to interpret."
- All non-linear devices are linearised at the DC operating point.
- "The resulting node voltages (and branch currents) are complex vectors. Therefore one has
  to be careful using the `plot` command" — use `vdb()`, `mag()`, `ph()`, `cph()` etc.
- **"Output parameters like `@m1[cgs]` or `@r1[i]` (see 27) are not supported during AC
  simulation."** Repeated in §13.5.1. This is a hard GUI constraint: internal-device-parameter
  probes silently produce nothing in AC.
- `noopac` (§11.1.3) can skip the pre-AC op for purely linear circuits.

The interactive `ac` section (§13.5.1) adds a worked complex-plot example and the note that
`vdb(ac3.2)` is legal but `ac3.vdb(2)` is not.

### 2.4 `.TRAN` — transient (§11.3.10)

```
.tran tstep tstop <tstart <tmax>> <uic>
```
Examples: `.tran 1ns 100ns`, `.tran 1ns 1000ns 500ns`, `.tran 10ns 1us`.

Parameter meanings, verbatim-ish:
- `tstep` — "printing or plotting increment for line-printer output. For use with the
  post-processor, `tstep` is the suggested computing increment."
- `tstop` — final time; `tstart` — initial time, default 0. **"The transient analysis always
  begins at time zero."** In `[0, tstart)` the circuit is analysed but **no outputs are
  stored**.
- `tmax` — "the maximum stepsize that ngspice uses; **for default, the program chooses either
  `tstep` or `(tstop-tstart)/50.0`, whichever is smaller**."
- `uic` — skip the quiescent op; use device `IC=…` and `.ic` values instead. "`IC=…` will take
  precedence over the values given in the `.ic` control line. If neither … is given for a
  specific node, node voltage zero is assumed."

Related variable (§13.7 / §12.9): **`nostepsizelimit`** — "set to a value of
`(tstop - tstart)/50` by adding `set nostepsizelimit` to `.spiceinit`. Both may be overridden
by setting `tmax` on the `.tran` line."

Interactive (§13.5.99): `tran Tstep Tstop [ Tstart [ Tmax ] ] [ UIC ]`; ctrl-C interrupts and
`resume` (13.5.67) continues.

### 2.5 `.NOISE` — small-signal noise (§11.3.4)

```
.noise v(output <,ref>) src ( dec | lin | oct ) pts fstart fstop
+ <pts_per_summary>
```
Examples: `.noise v(5) VIN dec 10 1kHz 100MEG`, `.noise v(5,3) V1 oct 8 1.0 1.0e6 1`.

- `output` node; optional `ref` (default ground) → measures `v(output) - v(ref)`.
- `src` — the independent source that input noise is referred to.
- `pts_per_summary` — optional integer; if given, per-noise-generator contributions are
  printed every that many frequency points.
- **Produces two plots**: spectral density (`onoise_spectrum`, `inoise_spectrum`) and
  integrated noise (`onoise_total`, `inoise_total`, which "are in reality scalars").
- Units switch: `set sqrnoise` → V²/Hz or A²/Hz; **default is `unset sqrnoise`** → V/√Hz.
- **"The KLU matrix solver (11.1.1) is not compatible with noise simulation."** Stated twice
  (also in §11.1.1 under `KLU`). This is a real GUI trap: a `.spiceinit` that sets
  `option klu` (which the manual itself recommends for PDK work, §12.6) silently breaks noise.

`13.5.52` adds the canonical recipe for writing both noise plots to file(s):
```
setplot noise1 / write test_noise1.raw all
setplot noise2 / write test_noise2.raw all
* or, one file:  write testall.raw noise1.all noise2.all
```

### 2.6 `.DISTO` — small-signal distortion (§11.3.3)

```
.disto dec nd fstart fstop <f2overf1>
.disto oct no fstart fstop <f2overf1>
.disto lin np fstart fstop <f2overf1>
```
Examples: `.disto dec 10 1kHz 100MEG`, `.disto dec 10 1kHz 100MEG 0.9`.

Two modes:
- **without `f2overf1`** — harmonic analysis at a single input F1; outputs the AC values at
  2·F1 and 3·F1 versus swept F1. Source amplitudes/phases come from the `distof1` keyword on
  the independent-source lines.
- **with `f2overf1`** (real, strictly between 0.0 and 1.0) — spectral/IM analysis; F2 is held
  at `f2overf1 * fstart`; outputs at F1+F2, F1−F2 and 2·F1−F2. Uses `distof1` and `distof2`
  keywords.

Manual's warnings, which a GUI should surface:
- "If the `distof1` or `distof2` keywords are missing … that source is assumed to have no
  input at the corresponding frequency. **The default values of the magnitude and phase are
  1.0 and 0.0** respectively. The phase should be specified in degrees."
- "these are the AC values of the actual harmonic components, and are **not equal to HD2 and
  HD3**. To obtain HD2 and HD3, one must divide by the corresponding AC values at F1,
  obtained from an `.ac` line."
- "the number `f2overf1` should ideally be an irrational number … keep the denominator in its
  fractional representation as large as possible, certainly **above 3**". Worked
  counter-example given: 1/2 aliases F1−F2 onto F2 and F1+F2 onto 2F1−F2; 49/100 does not.
- "The distortion component desired (2F1 or 3F1) can be selected using … the `setplot`
  command."
- **Device support is a short list**: "Diodes (DIO), BJT, JFET (level 1), MOSFETs (levels 1,
  2, 3, 9, and BSIM1), MESFET (level 1)." §1.2.5 repeats it and adds "All linear devices are
  automatically supported" and a switch caveat, plus the fallback advice: "If a device model
  does not support direct small signal distortion analysis, please use the Fourier of FFT
  statements and evaluate the output per scripting."

**This device list is the single most important caveat for a distortion GUI** — a modern PDK
(BSIM4, HiSIM, PSP via OSDI) supports **none** of it.

### 2.7 `.PZ` — pole-zero (§11.3.6)

```
.pz node1 node2 node3 node4 cur pol
.pz node1 node2 node3 node4 cur zer
.pz node1 node2 node3 node4 cur pz
.pz node1 node2 node3 node4 vol pol
.pz node1 node2 NODE3 node4 vol zer
.pz node1 node2 node3 node4 vol pz
```
Examples: `.pz 1 0 3 0 cur pol`, `.pz 2 3 5 0 vol zer`, `.pz 4 1 4 1 cur pz`.

- `cur` → transfer function (output voltage)/(input current); `vol` → (output voltage)/(input
  voltage). `pol` / `zer` / `pz` select poles only / zeros only / both — "provided mainly
  because if there is a non-convergence in finding poles or zeros, then, at least the other
  can be found."
- node1/node2 = input port, node3/node4 = output port.
- "In interactive mode … the first field is `pz` instead of `.pz`. **To print the results, one
  should use the command `print all`.**"

§1.2.4 caveats: "works with resistors, capacitors, inductors, linear-controlled sources,
independent sources, BJTs, MOSFETs, JFETs and diodes. **Transmission lines are not
supported.**" "The method used in the analysis is a sub-optimal numerical search. For large
circuits it may take a considerable time or fail to find all poles and zeros … for some
circuits, the method becomes 'lost' and may find an excessive number of poles or zeros."

### 2.8 `.SENS` — sensitivity (§11.3.7)

```
.SENS OUTVAR [< filter ...>] [DC]
.SENS OUTVAR [< filter ...>] AC DEC ND FSTART FSTOP
.SENS OUTVAR [< filter ...>] AC OCT NO FSTART FSTOP
.SENS OUTVAR [< filter ...>] AC LIN NP FSTART FSTOP
```
Examples: `.SENS V(1,OUT)`, `.SENS V(OUT) AC DEC 10 100 100k`, `.SENS I(VTEST) rbias m*_* q*:*`.

- `OUTVAR` is a node voltage or a voltage-source branch current.
- Output units: "change in output per unit change of input (**as opposed to percent change**)".
- "By default, all modifiable, real-valued parameters are varied and an output vector is
  created for each." Vector naming: **device name** for a primary device parameter (e.g.
  resistance, inductance); `device_parameter` for other device parameters; `model:parameter`
  for model parameters.
- **Filter strings** (a genuinely GUI-friendly feature): glob patterns matched against the
  potential vector names — `*` any substring, `?` any single character ("a byte, not a
  complete multibyte character"). The example `rbias m*_* q*:*` selects one resistor, all
  device parameters of MOSFETs, and all model parameters of BJTs.

§1.2.6 caveats: "Ngspice calculates the difference … by perturbing each parameter of each
device independently. Since the method is a **numerical approximation**, the results may
demonstrate second order effects in highly sensitive parameters, or may fail to show very low
but non-zero sensitivity. Since each variable is perturbed by a small fraction of its value,
**zero-valued parameters are not analyzed**."

Interactive (§13.5.71):
```
sens output_variable [filter ...]
sens out_var [filter ...] ac (DEC|OCT|LIN) N Fstart Fstop
```

### 2.9 `.TF` — DC small-signal transfer function (§11.3.9)

```
.tf outvar insrc
```
Examples: `.tf v(5, 3) VIN`, `.tf i(VLOAD) VIN`.

Computes "the dc small-signal value of the transfer function (output/input), input
resistance, and output resistance."

§13.5.97 gives a full worked example and the exact output vector names:
```
transfer_function          = 3.750000e-001
output_impedance_at_v(3,5) = 6.662500e+001
vs#input_impedance         = 2.000000e+002
```
**GUI note:** the output-impedance vector name embeds the output expression and the
input-impedance vector name embeds the source name — a GUI must construct those names, not
guess fixed ones.

### 2.10 `.SP` — S-parameter (§11.3.8) — build-gated, ON by default here

```
.sp dec nd fstart fstop <donoise>
.sp oct no fstart fstop <donoise>
.sp lin np fstart fstop <donoise>
```
Examples: `.sp dec 10 1 10K`, `.sp dec 10 1K 100MEG 1`, `.sp lin 100 1 100HZ`.

- "Syntax is identical to `.AC` except that you have one more optional parameter
  `donoise (0|1)`."
- Outputs: `S`, `Y`, `Z` matrices, all `nport × nport`, named `S_i_j` / `Y_i_j` / `Z_i_j`
  where i, j are the `portnum` identifiers.
- With `donoise = 1`: adds the noise current correlation matrix `Cy_i_j`, and for two-port
  networks additionally `Rn` (input noise resistance, unnormalised), `NF` (dB), `NFmin` (dB),
  and `SOpt` (optimum input reflection coefficient for noise).
- **"It may be used to export Touchstone files (to be implemented yet)…"** — the manual itself
  flags the Touchstone export as unfinished. See §16.2 for my confirmation that `wrs2p` does
  **not** work on an `.sp` plot.

**Port setup (§4.1.11 "RF Port"), which is the non-obvious half:**
```
DC 0 AC 1 portnum n1 <z0 n2>
```
Example: `V1 in 0 dc 0 ac 1 portnum 1 z0 100`
- `portnum` (integer) is what turns a VSRC into an RF port. "Portnum of all VSRCs defined as
  RF ports must start from 1 and count up to the number of RF ports. You cannot have duplicate
  portnums."
- `z0` (real) internal impedance, **default 50 Ω**.
- **"When declaring a RF port, the VSRC now becomes a VSRC with Z0 Ohm in series. This extra
  resistor affects all simulations."** — i.e. adding ports perturbs every other analysis in
  the same deck. A GUI must either warn or keep S-parameter decks separate.
- "At least two ports are required for the S-parameter simulation."

Build gate: `--enable-sp` / `--disable-sp` → `AC_DEFINE([RFSPICE], …)` at
`configure.ac:1226`. **ON by default** (the `no` branch is the only disabling one,
`configure.ac:1220-1228`); confirmed defined in this tree at
`build-ver_50/src/include/ngspice/config.h:535`.

### 2.11 `.PSS` — periodic steady state (§11.3.12) — build-gated, OFF by default here

Manual's own first line: **"Experimental code, not yet made publicly available."**

```
.pss gfreq tstab oscnob psspoints harms sciter steadycoeff <uic>
```
Examples:
```
.pss 150 200e-3 2 1024 11 50 5e-3 uic
.pss 624e6 1u v_plus 1024 10 150 5e-3 uic
.pss 624e6 500n bout 1024 10 100 5e-3 uic
```
- `gfreq` guessed fundamental; the algorithm infers `rgfreq` from a transient run and
  **discards `gfreq` if it is outside ±10 % of `rgfreq`**.
- `tstab` stabilisation time before shooting starts. "heavily influences the possibility to
  reach the PSS. Thus it is good practice … e.g. performing a separate TRAN analysis before."
- `oscnob` the node or branch where oscillation is expected.
- `psspoints` number of steps in the predicted period; "should be higher than 2 times the
  requested `harms`. Otherwise the PSS analysis will properly adjust it."
- `harms` number of harmonics.
- `sciter` shooting-cycle iteration limit, **default 50**.
- `steady_coeff` weighting coefficient for the Global Convergence Error, **default 1e-3**;
  "the lower … the higher the accuracy … but at longer analysis time".
- `uic` as for `.tran`.

§1.2.8: "PSS performs analysis only on **autonomous circuits**, meaning that it is able to
predict fundamental frequency and (harmonic) amplitude(s) for oscillators, VCOs, etc. …
Results of PSS are the basis of periodical large-signal analyses like PAC or PNoise" — i.e.
PAC/PNoise do **not** exist yet.

Build gate: `--enable-pss` → `AC_DEFINE([WITH_PSS], …)` at `configure.ac:1083`.
**OFF by default.** Confirmed: `WITH_PSS` is absent from
`build-ver_50/src/include/ngspice/config.h`, `commands.c:324` guards `pss` with
`#ifdef WITH_PSS`, and the built binary's `help all` does not list `pss`.
**A GUI built against this tree must not offer PSS unless it detects the capability.**

### 2.12 Transient noise (§11.3.11) — an analysis that is not a card

"In contrast to the analysis types described above, the transient noise simulation … is
**not implemented as a dot command**, but is integrated with the independent voltage source
`vsrc` (**isrc not yet available**) and used in combination with `.tran`."

Sources (all three combinable on one line): white (Box-Muller), 1/f (Kasdin algorithm,
sequence generated at start-up, length = total sim time / NT rounded up to a power of 2), and
**RTS / burst / popcorn noise** (amplitude + mean capture time + mean emission time, drawn
from an exponential distribution).

Syntax appears as `TRNOISE(...)` on the source line; the manual's RTS example:
```
VRTS2 13 12 DC 0 trnoise(0 0 0 0 5m 18u 30u)
VALL  12 11 DC 0 trnoise(1m 1u 1.0 0.1m 15m 22u 50u)
VW1of 21 0  DC   trnoise(1m 1u 1.0 0.1m)
IRTS2 10 0  DC 0 trnoise(0 0 0 0 5m 18u 30u)
```
(so current sources *do* take `trnoise` in the example, contradicting the "isrc not yet
available" sentence at the top of §11.3.11 — **flagged, unresolved**; see Gaps.)

Reproducibility: `setseed nn` in `spinit`/`.spiceinit`. Switch-off variable: `notrnoise`
(§13.7).

Manual's explicit health warning, verbatim: **"This transient noise feature is still
experimental."** followed by a list of open questions: "clarify the theoretical background /
noise limit of plain ngspice (numerical solver, fft etc.) / time step (NT) selection /
calibration of noise spectral density / how to generate noise from a transistor model /
application benefits and limits".

Practical guidance the source would never tell you: "you may select NT to be a factor of 10
smaller than the frequency limit of your circuit"; "The transient method is probably most
suited to circuits including switches, which are not amenable to the small signal `.NOISE`
analysis."

Shot noise is *not* a built-in source — the manual gives a B-source recipe
(`BI 1 3 I=sqrt(2*abs(i(v1))*1.6e-19*1e7)*v(11)`).

---

## 3. Initial conditions and temperature

### 3.1 `.NODESET` (§11.2.1)
```
.nodeset v(nodnum)=val v(nodnum)=val ...
.nodeset all=val
```
"makes a preliminary pass with the specified nodes held to the given voltages. The
restrictions are then released… may be necessary for convergence on bistable or astable
circuits. `.nodeset all=val` sets all starting node voltages (except for the ground node) to
the same value. **In general, the `.nodeset` line should not be necessary.**"

### 3.2 `.IC` (§11.2.2)
```
.ic v(nodnum)=val v(nodnum)=val ...
```
Two interpretations, which a GUI must expose as a coupled choice with `uic`:
- **`.tran … uic` given** → the `.ic` voltages are used to compute capacitor, diode, BJT, JFET
  and MOSFET initial conditions. "equivalent to specifying the `ic=…` parameter on each device
  line… The `ic=…` parameter can still be specified and **takes precedence**." Warning: "Since
  no dc bias … is computed …, one should take care to specify all dc source voltages on the
  `.ic` control line."
- **`uic` not given** → the DC bias is computed with those node voltages **forced**, then the
  constraint is removed for the transient. "**This is the preferred method** since it allows
  Ngspice to compute a consistent dc solution."

`wrnodev` (§13.5.109) writes all node voltages in `.ic=xx` format so a run can be seeded from
a previous one (`stop when time=3.9` → `wrnodev file` → `.include file`).

### 3.3 Temperature (§1.3.2, §2.14, §11.1.1)
- `.temp 40` (§2.14) — "Sets the circuit temperature in degrees Celsius." **`.temp` overrides
  `.options temp`** (§1.3.2: "Both commands are equivalent, however `.temp` will override
  `.options temp`").
- `.options temp=60`, `.options tnom=25`. Defaults **27 °C / 300 K** for both (§11.1.1).
- Per-device: instance parameters `temp` (absolute) and `dtemp` (delta above overall).
- **Temperature is sweepable**: `.dc temp 25 49 2`.
- `TEMPER` is available inside B/E/G/R/L/C expressions.
- `.options temp` may be "generally overridden by a `.TEMP` card".

---

## 4. The `.options` tables, reproduced (manual §11.1)

Preamble (§11.1): "`.options opt1 opt2 ... (or opt=optval ...)`"; "Options specified to
ngspice via the `option` command (see 13.5.54) are also passed on as if specified on a
`.options` line." `x` is "some positive number".

### 4.1 General (§11.1.1)

| Option | Manual's description | Default |
|---|---|---|
| `SPARSE` | selects Sparse 1.3 solver; "also the standard when no option is given"; "preferable for simulating behavioural device models"; **required with noise (11.3.4) or CIDER (26)** | default solver |
| `KLU` | KLU solver; "preferable (yielding faster simulation) when (large) circuits containing MOS devices are to be simulated. **Small signal noise (11.3.4) or CIDER (26) simulations are not (yet) supported.**" | — |
| `ACCT` | accounting and run time statistics | off |
| `NOACCT` | no statistics, **no printing of the Initial Transient Solution** | — |
| `NOINIT` | suppresses only printing of the Initial Transient Solution; "maybe combined with ACCT" | — |
| `LIST` | summary listing of input data | off |
| `NOMOD` | suppress model parameter printout | off |
| `NOPAGE` | suppress page ejects | off |
| `NODE` | print the node table | off |
| `NOREFVALUE` | suppress reference values during simulation (progress ticker) | off |
| `OPTS` | print the option values | off |
| `SEED=val\|random` | RNG seed; `val` any integer > 0; `random` = current Unix epoch time | — |
| `SEEDINFO` | print the seed value when set to a new integer | — |
| `TEMP=x` | operating temperature | **27 °C (300 K)** |
| `TNOM=x` | nominal temperature | **27 °C (300 K)** |
| `WARN=1\|0` | enable SOA voltage warning messages | **0** |
| `MAXWARNS=x` | max SOA warnings **per model** | **5** |
| `SAVECURRENTS` | save currents through all terminals of M, J, Q, D, R, C, L, B, F, G, W, S, I | off |

`SAVECURRENTS` caveats, verbatim-ish: "Recommended only for small circuits, because otherwise
memory requirements explode…"; "**available only for op, dc, and tran simulation, not for
ac**"; "During transient simulation the value returned may be delayed by one time step"; "For
M devices, MOS level 1 is supported fully, not all nodes are reported for the other MOS
devices"; "may lead to empty vectors of zero length after the simulation, impeding commands
like `wrdata`. Running command `remzerovec` before `wrdata` will remove all these zero length
vectors."

Buried in §11.7.3, **not in the table above**: `.options savecurrents_mos1`,
`.options savecurrents_bsim3`, `.options savecurrents_bsim4` — "listing all currents as
described in chapters 31.6.1, 31.6.8 and 31.6.9". (That cross-reference is broken: the manual
has no chapter 31.) Also there: "Also note that the data thus retrieved may be delayed by one
time step after a transient simulation" and the `nosavecurrents` variable (§13.7) to suppress
it, which is the documented way to mix AC into a savecurrents script.

### 4.2 OP and DC solution options (§11.1.2)

Preamble: "Since transient analysis (11.1.4) is based on OP, many of the options affect
transient simulation as well. **AC analysis can be performed only when a stable operating
point has been found.**"

| Option | Description | Default |
|---|---|---|
| `ABSTOL=x` | absolute current error tolerance | **1 pA** |
| `GMIN=x` | minimum conductance | **1.0e-12** |
| `GMINSTEPS=x` | "sets the number of Gmin steps to be attempted. If the value is set to zero, the standard gmin stepping algorithm is skipped." | **1** (see §2.1 — this description is misleading) |
| `ITL1=x` | dc iteration limit | **100** |
| `ITL2=x` | dc transfer curve iteration limit | **50** |
| `KEEPOPINFO` | "Retain the operating point information when either an AC, Distortion, or Pole-Zero analysis is run." | off |
| `NOOPITER` | "Go directly to gmin stepping, skipping the first iteration." | off |
| `PIVREL=x` | relative pivot ratio | **1.0e-3** |
| `PIVTOL=x` | absolute minimum pivot | **1.0e-13** |
| `RELTOL=x` | relative error tolerance | **0.001 (0.1 %)** |
| `RSHUNT=x` | resistor from each analog node to ground; **"The XSPICE option has to be enabled"** | off |
| `VNTOL=x` | absolute voltage error tolerance | **1 µV** |

`PIVREL` formula given: `EPSREL = AMAX1(PIVREL · MAXVAL, PIVTOL)`.

**§11.1.2.1 "Matrix Conditioning info"** — pure practice guidance, source would not tell you:
- No DC path to ground (two series caps, cascaded code models) → ill-conditioned matrix.
  `.option rshunt = 1.0e12`; "Usually a value of 1 TΩ is sufficient… In bad cases one can try
  lowering the value to 10 GΩ or even 1 GΩ."
- Inductor in parallel with a voltage source → AC fails because AC is preceded by OP.
  `NOOPAC` helps **only if the circuit is linear**; otherwise add a small series resistor.
- `.option rseries = 1.0e-4` "adds a series resistor to each inductor in the circuit. **Be
  careful when using behavioral inductors (see 3.3.13), as the result may become
  unpredictable.**"
- `.option cshunt = 1.3e-13` "adds a capacitor from each voltage node in the circuit to ground."

(`rseries` is implemented as a netlist *preprocessing* pass, not a CKT option:
`src/frontend/inpcom.c:8313,8332`.)

### 4.3 AC solution options (§11.1.3) — exactly one option

`NOOPAC` — "Do not run an operating point (OP) analysis prior to an AC analysis. **This option
requires that the circuit is linear**, i.e. consists only of R, L, and C devices, independent V,
I sources and linear dependent E, G, H, and F sources (without poly statement,
non-behavioral). If a non-linear device is detected, the OP analysis is executed
automatically… It is also useful if you have very large linear arrays (10000 nodes and more),
where **simulation speedup by a factor of 10** may be achieved."
§11.3.1 restates the eligible instance letters: `r, l, c, i, v, e, g, f, h, k`.

### 4.4 Transient analysis options (§11.1.4)

| Option | Description | Default |
|---|---|---|
| `AUTOSTOP` | "stops a transient analysis after successfully calculating all functions specified with the dot command `.meas`. **Autostop is not available with the `meas` command used in control mode.**" | off |
| `CHGTOL=x` | charge tolerance | **1.0e-14** |
| `CONVSTEP=x` | relative step limit applied to code models | — |
| `CONVABSSTEP=x` | absolute step limit applied to code models | — |
| `INTERP` | interpolate output onto a fixed TSTEP grid, linear interpolation. "Simulation itself is not influenced… may drastically reduce memory requirements in control mode, and file size in batch mode, but **care is needed not to undersample**." Works in all modes. Example deck cited: `examples/xspice/delta-sigma/delta-sigma-1.cir` | off |
| `ITL3=x` | lower transient iteration limit ("not implemented in Spice3") | **4** |
| `ITL4=x` | transient time-point iteration limit | **10** |
| `ITL5=x` | transient total iteration limit; "Set ITL5=0 to omit this test" | **5000** |
| `ITL6=x` | synonym for `SRCSTEPS` | — |
| `MAXEVTITER=x` | max event iterations per analysis point | — |
| `MAXOPALTER=x` | max analog/event alternations for a hybrid circuit | — |
| `MAXORD=x` | max integration order. "Possible values for the **Gear** method are from 2 (the default) to 6. Using the value 1 with the trapezoidal method specifies backward Euler" | **2** |
| `METHOD=name` | `Gear` \| `trapezoidal` (`trap`) | **trapezoidal** |
| `NOOPALTER=TRUE\|FALSE` | if false, analog/event alternation during initial DC op is enabled | — |
| `RAMPTIME=x` | rate of change of independent supplies during source stepping; "also affects code model inductors and capacitors that have initial conditions specified" | — |
| `SRCSTEPS=x` | non-zero → source stepping; "The value specifies the number of steps" (see §2.1 — actually a mode selector) | **1** |
| `TRTOL=x` | transient error tolerance. "**If XSPICE is configured and 'A' devices are included, the value is internally set to 1 for higher precision. This slows down transient analysis by a factor of two.**" | **7** |
| `XMU=x` | damping factor for trapezoidal integration. "A value < 0.5 may be chosen. **Even a small reduction, e.g. to 0.495, may already suppress trap ringing.** The reduction has to be set carefully in order not to excessively damp circuits that are prone to ringing or oscillation, which might lead the user to believe that the circuit is stable." | **0.5** |

`XMU` is the kind of thing an ADE-beating GUI should expose with that warning attached.

### 4.5 Element-specific options (§11.1.5)

| Option | Description | Default |
|---|---|---|
| `diode_cj0=x` | add diode junction capacitance if none in `.model`. Example: `.options diode_cj0=20p` | — |
| `diode_rser=x` | add diode series resistance if none in `.model`. Example: `.options diode_rser=20m` | — |
| `BADMOS3` | old MOS3 with the `kappa` discontinuity | off |
| `DEFAD=x` | MOS drain diffusion area | **0** |
| `DEFAS=x` | MOS source diffusion area | **0** |
| `DEFL=x` | MOS channel length | **100 µm** |
| `DEFW=x` | MOS channel width | **100 µm** |
| `SCALE=x` | element scaling factor for geometric parameters. Scales: R/C `W,L`; Diode `W,L,Area`; JFET/MESFET `W,L,Area`; MOSFET `W,L,AS,AD,PS,PD,SA,SB,SC,SD` | 1 |

### 4.6 Transmission line options (§11.1.6)
`TRYTOCOMPACT` — LTRA only; condense past history of input voltages and currents.

### 4.7 Precedence (§11.1.7) — verbatim rule, essential for a GUI

> internal default values → `option` in `spinit`/`.spiceinit` → `.options` line in the input
> file → `option` inside a `.control … .endc` section (**highest**).

### 4.8 Options the manual does not list (source cross-check)

The authoritative CKT-level option table is `src/spicelib/analysis/cktsopt.c:263-390`.
Settable (`IF_SET`) options present there but **absent from manual §11.1**:

`convlimit`, `autopartial` (XSPICE-gated), `gshunt`, `gminfactor`, `oldlimit`, `minbreak`,
`bypass`, `copynodesets`, `nodedamping`, `absdv`, `reldv`, `epsmin`, `indverbosity`, `defm`,
`klu_memgrow_factor`.

`ltereltol` / `lteabstol` / `ltetrtol` / `newtrunc` exist in that table and *are* documented,
but only in **§12.12**, not §11.1 — easy to miss.

Conversely, several §11.1 "options" are **not** CKT options at all; they are frontend
interpreter variables handled in `src/frontend/`: `interp` (`outitf.c:211`, `breakp.c:49`),
`autostop` (`inp.c:1143`, `measure.c:250`), `warn`/`maxwarns` (`inp.c:1447,1452`),
`savecurrents` (`inp.c:2423`), `scale` (`inp.c:2689`, `subckt.c:592`), `seedinfo`
(`inp.c:440`), `noinit`/`norefvalue` (`options.c:359,361`, `spiceif.c:478,481`), `rseries`
(`inpcom.c:8313`). **For a GUI this matters:** `.options` and `set` are two overlapping
namespaces, and which mechanism a name belongs to determines whether it survives `reset`,
whether it can be changed mid-script, and whether it appears in the `option` command's dump.

Running `option` with no arguments on a loaded circuit dumps the live values — the most
reliable capability probe a GUI has. On this tree it prints: temp/tnom (300.15 K), integration
method (TRAPEZOIDAL), MaxOrder 2, xmu 0.5, **indverbosity 2**, **epsmin 1e-28**, matrix solver,
abstol/chgtol/vntol/pivtol, reltol/pivrel, itl1/itl2/itl4, **gminsteps 1 / srcsteps 1**,
trtol 7, gmin 1e-12, **diaggmin 0 / gshunt 0 / cshunt -1 / delmin 0**, and the MOS defaults
(M 1, L 1e-4, W 1e-4, AD 0, AS 0). `diaggmin` and `delmin` appear in that dump but in
neither the manual nor `cktsopt.c`'s settable table.

---

## 5. The `set`-variable table (manual §13.7 "Internally predefined variables")

Preamble: "In addition to the variables mentioned below, the `set` command also affects the
behavior of the simulator via the options previously described under the section on
`.OPTIONS` (11.1)."

Analysis-relevant entries, with the manual's own text condensed. (The full alphabetical list
also contains ~60 plotting/hardcopy/terminal variables — `colorN`, `gridstyle`, `hcopy*`,
`plotstyle`, `pointchars`, `polydegree`, `polysteps`, `ticchar`, `ticmarks`, `ticlist`,
`wfont*`, `xfont*`, `xbrushwidth`, `xgridwidth`, `x11lineararcs`, `nolegend`, `nounits`,
`gridsize`, `height`, `width`, `nobreak`, `noasciiplotvalue`, `noprintscale`, `moremode`,
`device`, `term`, `lprps`, `lprplot5` — out of analysis scope but they are the knobs a
plotting GUI would want.)

| Variable | Meaning (manual) | Default |
|---|---|---|
| `addcontrol` | set by ngspice when run with `-a`; extra lines added to ensure a simulation runs | — |
| `autostop` | see §11.1.4 | off |
| `batchmode` | set by ngspice when run with `-b`; "may be used in input files to suppress plotting" | — |
| `brief` | suppresses automatic display of the processed netlist | **set** |
| `controlswait` | **shared-ngspice only.** With `bg_run`, `.control` commands otherwise run before the simulation finishes; `set controlswait` delays them until the background thread returns | — |
| `csnumprec` | precision of values derived from vectors/variables via `$var`, `$&vec` | **6** |
| `curplot` | **(read only)** `<type><no.>` of the current plot. "Type is one of tran, ac, op, sp, dc, unknown" | — |
| `curplotdate` / `curplotname` / `curplottitle` | set date/name/title of the current plot | — |
| `debug` | parameters: `siminterface`, `cshpar`, `eval`, `vecdb`, `graf`, `control`, `shvecsearch`; bare `debug` prints all | — |
| `diff_abstol` | tolerance used by `diff` | **1e-12** |
| `diff_reltol` | ditto | **0.001** |
| `diff_vntol` | absolute tolerance for voltage vectors in `diff` | **1e-6** |
| `enable_noisy_r` | enable noise calculation for all behavioral resistors (`.spiceinit`); per-instance override `noisy=0`/`noisy=1` | off |
| `filetype` | `ascii` \| `binary` — rawfile format | **binary** |
| `fourgridsize` | interpolation grid points for `fourier` | **200** |
| `fournosave` | suppress vector generation from THD calculation with `four` | off |
| `interactive` | numparam error handling with console input; if unset ngspice exits on a numparam error | — |
| `inputdir` | directory of the last input file — "may be used to direct outputs into a directory relative to the input", e.g. `write $inputdir/outfile.raw` | — |
| `keep#branch` | rawfile branch currents written as `v1#branch` not `i(v1)` — "retains compatibility with software like ICCAP" | off |
| `measoutfile` | file for `.measure` results in batch mode | — |
| `measureprec` | digits when printing measure outputs | **6** |
| `mtimeavgwindow` | time window for the `mtimeavg` function | — |
| `nfreqs` | number of frequencies for `fourier` | **10** |
| `ngbehavior` | compatibility mode — see §11 | see §11 |
| `ngdebug` | extra debug printouts (see §12.17) | off |
| `ng_nomodcheck` | suppress model parameter checks | off |
| `no_auto_braces` | skip the unquoted-parameter check; speeds up large PDK loads | off |
| `no_auto_gnd` | do not replace nodes named `gnd` by node 0. **"If you fail to [zero grounds yourself], ngspice may crash, or deliver wrong results."** | off |
| `nosavecurrents` | "If set by `set nosavecurrents` and followed by `reset`, the setting of internal current vectors (`.options savecurrents`) is suppressed. **This is useful in ac simulation** which does not support `options savecurrents` and you have a mix of several simulations in a single script." | off |
| `nostepsizelimit` | override the tstep max-step limit → `(tstop-tstart)/50` | off |
| `notrnoise` | switch off transient noise sources | off |
| `nopadding` | don't insert padding values in raw files | off |
| `noparse` | don't parse input files when read | off |
| `num_threads` | OpenMP threads | **2** |
| `osdi_enabled` | set at start-up when the OSDI interface is compiled in | — |
| `plainlet` / `plainplot` / `plainwrite` | run `let` / `plot` / `write` without evaluating expressions — needed when vector names contain `/` (KiCad) | off |
| `rndseed` | seed for `sgauss`, `sunif`, `rnd`; "set by the option command `option seed=val\|random`" | — |
| `rsdiode` | series resistance for all diode models if none in the model | — |
| `sanelet` | prevents `let` from modifying values in the `const` plot | off |
| `sharedmode` | set when ngspice runs as a shared library — "may be used in universal input files to suppress plotting" | — |
| `sim_status` | **"will be set to 0 when the simulation starts. If there is an error and the simulation fails with 'xx simulation(s) aborted', then `sim_status` is set to 1. The variable can be used in scripted loops within a transient simulation."** | 0 |
| `sourcepath` | search path for `source`, `.include`, `.lib`. "Only the first entry in the sourcepath list is sent to the code models" | current dir + lib dir |
| `specwindow` | FFT window (see §8.2) | **hanning** |
| `specwindoworder` | Gaussian window order, 2–8 | **2** |
| `sqrnoise` | noise outputs as V²/Hz (A²/Hz) instead of V/√Hz | **unset** |
| `strict_errorhandling` | "an error detected during circuit parsing will immediately lead ngspice to exit with exit code 1 (see 14.5). **May be set in files spinit (12.5) or .spiceinit (12.6) only.**" | off |
| `wr_onespace` / `wr_singlescale` / `wr_vecnames` | `wrdata` formatting | off |
| `xspice_enabled` | set at start-up when XSPICE is compiled in | — |
| `xtrtol` | "Set trtol, e.g. to 7, to avoid the default speed reduction (accuracy increase) for XSPICE (see 12.9). **Be aware of potential precision degradation or convergence issues.**" | — |
| `oscompiled` | 0 Other, 1 MINGW, 2 Cygwin, 3 FreeBSD, 4 OpenBSD, 5 Solaris, 6 Linux, 7 macOS, 8 Visual Studio | — |
| `numdgt` | digits for `print col` tables; "should not be more than 16"; negative → one fewer digit for constant column width | **6** |
| `nperiods` | cycles of the fundamental used by `fourier` | **1** |
| `shellstatus` | status returned by the last `shell` command | — |
| `silent_fileio` | `fopen`/`fread` do not print error messages | off |
| `digital_delay_type` | XSPICE digital element delay behaviour (§8.4) | — |
| `auto_bridge`, `auto_bridge_xxxx` | control automatic insertion of bridging devices (§8.7); `0` disables | — |
| `noisyxspice` | report errors in XSPICE code model library functions ("For debug use") | off |

**`xspice_enabled` and `osdi_enabled` are the two documented capability probes a GUI can use.**
There is no documented probe for `RFSPICE`/`.sp` or for `WITH_PSS` — see Gaps.

---

## 6. Output control (batch) — manual §11.6

Gate, verbatim (§11.6): "`.print`, `.plot` and `.four` are valid **only if ngspice is started
in batch mode**, whereas `.save` and the equivalent `.probe` are acknowledged in all operating
modes." And: "**If you however add the command line option `-r` to create a rawfile, `.print`
and `.plot` are ignored.**"

### 6.1 `.SAVE` (§11.6.1)
```
.save vector vector vector ...
```
Examples: `.save i(vin) node1 v(node2)`, `.save @m1[id] vsource#branch`, `.save all @m2[vdsat]`.
- "If no `.SAVE` line is given, then the default set of vectors is saved (node voltages and
  voltage source branch currents)."
- "If you want to save internal data in addition to the default vector set, add the parameter
  `all`."
- **"If the command `.save vm(out)` is given, and you store the data in a rawfile, only the
  original data `v(out)` are stored. The request for storing the magnitude is ignored."**

Interactive `save` (§13.5.70) adds: `save none`, `save nosub` ("Don't save node vectors that
are defined inside of a subcircuit"), `save nointernals` ("Don't save internal device nodes
issued by OpenVAF/OSDI Verilog-A models like PSP"); subcircuit-qualified names
(`save 3 x1.x2.x1.x2.8 v.x1.x1.x1.vmeas#branch`, `save @m.xmos3.mn1[gm]`); accumulation across
multiple `save` lines; and **"In the `.control … .endc` section `save` must occur before the
`run` or `tran` command to become effective."** To exclude one node you must
`status` → `delete <number>`.

### 6.2 `.PRINT` (§11.6.2)
```
.print prtype ov1 <ov2 ... ov8>
```
`prtype` ∈ **DC, AC, TRAN, NOISE, DISTO**. AC modifiers on `V(N1,N2)`: `VR` real, `VI`
imaginary, `VM` magnitude, `VP` phase, `VDB` 20·log10(magnitude).
"(**Not yet implemented**: For the ac analysis, the corresponding replacements for the letter
`I` may be made in the same way as described for voltage outputs.)"
"Output variables for the noise and distortion analyses have a different general form."

### 6.3 `.PLOT` (§11.6.3)
```
.plot pltype ov1 <(plo1, phi1)> <ov2 <(plo2, phi2)> ... ov8>
```
Example including a distortion line: `.plot disto hd2 hd3(R) sim2`.
(**`hd2`, `hd3(R)`, `sim2` are distortion output-variable names that appear nowhere else in
the manual** — see §13.)

### 6.4 `.FOUR` (§11.6.4)
```
.four freq ov1 <ov2 ov3 ...>
```
"controls whether ngspice performs a Fourier analysis as a part of the transient analysis…
The analysis is the same as is done by the `fourier` command."
"As `.four` is available only when ngspice is executed in batch mode, and no rawfile selected,
you may consider the `spec`, `fourier` or `fft` commands, when using ngspice in `.control`
mode."

### 6.5 `.PROBE` (§11.6.5) — the modern current/voltage/power probe
```
.probe alli
.probe I(device)
.probe I(device,node)
.probe v(node1)
.probe vd(device:node1:node2)
.probe vd(device1:node1, device2:node2)
.probe p(device)
```
- **Current**: implemented by inserting a 0 V VSRC. "The positive pole of the VSRC is pointing
  out towards the net, the negative pole towards the device." Output vectors use `xx#branch`
  notation: `r1#branch`, `xu1:trig#branch`, `mq4:s#branch`. **"Only top level devices are
  accessible, so devices inside of subcircuits are not considered."** X instance lines work,
  and named subckt pins are used instead of numbers.
- **"Compared to `.options savecurrents` the resulting vectors from a `.probe` command are
  available for every simulation type including AC simulation. A slight disadvantage may be
  that new nodes are added to the instance matrix."**
- **Voltage**: inserts a unity-gain VCVS; output vector gets a leading `vd_`
  (`vd_R1`, `vd_m4:d:s`). Node selectors are positional numbers or device pin letters
  (`d,g,s,b` for MOS/JFET; `c,b,e` for bipolar).
- **Power**: `P = Σ iₙ·(vₙ − vref)` where `vref` is the mean of all node voltages. Output
  vector `xu1:power`, `mq1:power`.
- "All new items are added to the list of vectors named by `.SAVE`. **If `.save` is not given,
  only the newly generated `.PROBE` vectors are saved.**" (a sharp foot-gun)
- "Be careful when `.probe alli` is given, because the many output vectors generated
  automatically may require a large amount of memory."

### 6.6 `par('expression')` (§11.6.6)
```
par('expression')
output=par('expression')     $ not in .measure ac
```
- Usable in `.four`, `.plot`, `.print`, `.save` and `.measure`.
- Expression = any B-source expression; may contain `v(n1)`, `i(vdb)`, `.param` parameters and
  `hertz`, `temper`, `time`.
- "**Internally the expression is replaced by a generated voltage node that is the output of a
  B source.** … Several `par('…')` are allowed in each line, **up to 99 per input file**. The
  internal nodes are named `pa_00` to `pa_99`. **An error will occur if the input file
  contains any of these reserved node names.**"
- "The syntax of `output=par(expression)` is strict: no spaces are allowed between `par` and
  `('` or between `(` and `'`."
- "**Note that a B-source, and therefore the `par('…')` feature, operates on values of type
  complex in AC analysis mode.**"

### 6.7 `.width` (§11.6.7)
The manual's example line is **typo'd**: it prints `.with out = 256` where the card is
`.width`. Command-line equivalence is stated in §12.3: "If an `out` parameter is given on a
`.width` card, the effect is the same as `set width = …`".

### 6.8 `.SNDPARAM` / `.SNDPRINT` (§11.6.8)
```
.SNDPARAM FILENAME [ SAMPLERATE [FORMAT [V_OFF [V_MULT] [OVERSAMPLING] ] ] ]
.SNDPRINT PRTYPE OV1 [ OV2 ... OV8 ]
```
Example: `.sndparam test-io.wav 48000 wav24 1.0 0.0 1.0` / `.sndprint tran v(1)`.
Detail is in §13.11. A genuinely obscure output route that a "better than ADE" GUI could
expose for audio work.

### 6.9 Measuring device terminal currents — the three routes (§11.7)
The manual explicitly frames this as a **choice of three**, which is exactly the kind of thing
a GUI should turn into one control:
1. `.probe` (§11.7.1) — works in every analysis including AC; adds matrix nodes.
2. **Insert a 0 V voltage source by hand** (§11.7.2) — `Vmeas 11 0 dc 0`, read `vmeas#branch`.
3. `.options savecurrents` (§11.7.3) — no extra nodes, but **not usable in AC**, memory-hungry
   (1–4 vectors per device), one-timestep delay in transient.

---

## 7. Measurements — `.meas` / `meas` (manual §11.4, §13.5.49)

Types: `{DC|AC|TRAN|SP}`. **"The type `SP` to analyze a spectrum from the `spec` or `fft`
commands is only available when executed in a `meas` command"** (i.e. inside `.control`).

Blanket caveat (§11.4.3): **"Please note that not all of the `.measure` commands have been
implemented."**

Batch-mode restriction (§11.4.2), verbatim: "`.meas` analysis may **not** be used in batch
mode (`-b`), if an output file (rawfile) is given at the same time (`-r rawfile`)… For `.meas`
to be active you need to run the batch mode with a `.plot` or `.print` command. A better
alternative may be to start ngspice in interactive mode."

Argument semantics (§11.4.3): `TD=td` and `AT=time` are **times for tran, frequencies for
ac/sp, and voltages (or currents) for dc**; for ac/sp/dc, `TD` is ignored.
`CROSS=#` / `CROSS=LAST`; likewise `RISE` and `FALL`.

The ten general forms, verbatim headers:

```
1  .MEASURE {DC|AC|TRAN|SP} result TRIG trig_variable VAL=val
   + <TD=td> <CROSS=# | CROSS=LAST> <RISE=# | RISE=LAST>
   + <FALL=# | FALL=LAST> <TRIG AT=time> TARG targ_variable
   + VAL=val <TD=td> <CROSS=…> <RISE=…> <FALL=…> <TARG AT=time>

2  .MEASURE … result WHEN out_variable=val
   + <TD=td> <FROM=val> <TO=val> <CROSS=…> <RISE=…> <FALL=…>

3  .MEASURE … result WHEN out_variable=out_variable2 <TD> <FROM> <TO> <CROSS|RISE|FALL>

4  .MEASURE … result FIND out_variable WHEN out_variable2=val <TD> <FROM> <TO> <CROSS|RISE|FALL>

5  .MEASURE … result FIND out_variable WHEN out_variable2=out_variable3 <TD> <CROSS|RISE|FALL>

6  .MEASURE … result FIND out_variable AT=val

7  .MEASURE … result {AVG|MIN|MAX|PP|RMS|MIN_AT|MAX_AT} out_variable <TD=td> <FROM=val> <TO=val>

8  .MEASURE … result INTEG<RAL> out_variable <TD=td> <FROM=val> <TO=val>

9  .MEASURE … result param='expression'

10 .MEASURE … result FIND par('expression') AT=val
```
plus `DERIV<ATIVE>` (§11.4.11) in three shapes: `AT=val`, `WHEN out_variable2=val …`, and
`WHEN out_variable2=out_variable3 …`.

Notes a GUI must carry:
- Form 9 (`param=`) "may not contain vectors like `v(10)`".
- **Inside `.control`, neither `par('expression')` nor `param=` works** (§11.4.10, §13.5.49);
  the substitute is `let vec_new = expression` first, then `meas … find vec_new …`.
- `meas` (control mode) additionally **stores the result in a vector** named by `result`,
  usable by later commands. `.meas` (batch) only prints.
- `autostop` works with `.meas`, **not** with `meas`.
- Sample output format: `tdiff = 1.000000e-003 targ= 1.083343e-003 trig= 8.334295e-005`.
- Demonstration decks ship in `examples/measure/` (§11.4.12).
- `measoutfile` and `measureprec` variables (§13.7) control file output and digits.

The §11.4.12 example block is the best single source of realistic `.meas` lines (`inv_delay2`,
`out_slew`, `delay_chk`, `skew`…`skew5`, `v0_min/avg/integ/rms` with `from='dfall'
to='dfall+period'`, and the `.meas ac` family including `vout_diff`, `fixed_diff`,
`freq_at2 … fall=LAST`, `bw_chk param='(vout_diff < 100k) ? 1 : 0'`).

---

## 8. Post-processing "analyses" that are commands, not cards

These are analyses from a user's point of view and an ADE-beating GUI must expose them.

### 8.1 `linearize` (§13.5.45) — the mandatory pre-step for FFT
```
linearize <np=xx> <vec1> <vec2> ...
```
- Creates a **new plot** with data interpolated onto an equidistant time scale determined by
  `tstep`, `tstart`, `tstop` of the currently active transient analysis.
- Without `np`: new length = `floor((tstop - tstart) / tstep + 1.5)`.
  **"the parameter `tstep` of your transient analysis has to be small enough… otherwise the
  command `linearize` will do sub-sampling of your signal."**
- `np=512` → spans point 0 to point xx; `np=auto2n` → `2^n` with
  `n = (int)round(log2((tstop - tstart) / tstep))`.
- Sub-window: define vectors `lin-tstart`, `lin-tstop`, `lin-tstep` before calling. "At least
  `lin-tstart` or `lin-tstop` has to be defined." Motivating example: "to prepare a better fft
  by skipping the start-up phase of a ring oscillator."
- "**The `linearize` command should explicitly name the vectors of interest.** Otherwise
  warning messages pop up that the vectors `lin-tstart` etc cannot be linearized."

### 8.2 `fft` (§13.5.33), `spec` (§13.5.89), `psd` (§13.5.59), `fourier` (§13.5.35)

| Command | Form | Notes |
|---|---|---|
| `fft` | `fft vector1 [vector2] …` | "much faster than `spec` (about a factor of 50 to 100 for larger vectors)". Zero-pads to the next 2^N unless linked against **FFTW-3** ("makes arbitrary size transforms for even and odd data"). Creates plot `specN`. |
| `spec` | `spec start_freq stop_freq step_freq vector […]` | slower; explicit frequency grid |
| `psd` | `psd ave vector1 […]` | single-sided PSD; `ave` = points used for post-averaging/smoothing; "printed as total noise power up to Nyquist frequency, and as noise voltage or current"; result units V²/Hz or A²/Hz |
| `fourier` | `fourier fundamental_frequency [expression …]` | DC + first 9 harmonics (or `nfreqs-1`). Window: `<TSTOP-period*numPeriod, TSTOP>` where `numPeriod` = `nperiods` or 1. **"For maximum accuracy, TMAX (see the .tran line) should be set to `period*numperiod/100.0` (or less for very high-Q circuits)."** Also creates vectors `fouriermn` of size `3 × nfreqs`: `[0]` frequencies, `[1]` magnitudes, `[2]` phases; suppressed by `fournosave`. |

**Window functions — the manual gives three different lists and they do not agree.**

| Source | Window names given |
|---|---|
| §13.5.33 table (labelled "for the Fourier transform in the **spec and fft** command") | `none rectangular bartlet hanning blackman blackmanharris hamming gaussian flattop` |
| §13.5.89 (`spec`) | `none hanning cosine rectangular hamming triangle bartlet blackman gaussian` |
| §13.7 `specwindow` | `bartlet blackman cosine gaussian hamming hanning none rectangular triangle` |

**Source resolves it, and the §13.5.33 header is wrong.**
`fft` uses `src/maths/fft/fftext.c:106-169`: `rectangular`, `triangle`/`bartlet`/`bartlett`,
`hann`/`hanning`/`cosine`, `hamming`, `blackman`, **`blackmanharris`**, **`flattop`**,
`gaussian`.
`spec` uses `src/frontend/spec.c:93-141`: `none`, `rectangular`, `hanning`/`cosine`,
`hamming`, `triangle`/`bartlet`, `blackman`, `gaussian` — **no `blackmanharris`, no
`flattop`**.
So the §13.5.33 table is the **`fft`-only** set; `spec` supports a strict subset.
**A GUI must offer different window menus for `fft` and `spec`.**
Other window facts from §13.5.33: "All window functions have a rms value of 1. That means: No
amplitude correction for the result is needed"; `specwindoworder` is the Gaussian order,
integer 2–8, default 2.

Canonical FFT recipe (given twice, §13.5.33 and §13.5.45):
```
setplot tran1
linearize V(2)
set specwindow=blackman
fft V(2)
plot mag(V(2))
```

### 8.3 `cutout` (§13.5.17)
```
let cut-tstart = time1
let cut-tstop  = time2
cutout
```
"Cut out part of each vector of the current tran plot… A new scale vector `time` will be
generated as well. **Vectors that are shorter than the new scale vector will not be copied.**
So the simple command `cutout` may be used to get rid of 0-length vectors in a new tran plot
that may occur if for example something like generating `m1[id]` is not served in an AC
simulation."

### 8.4 `remzerovec` (§13.5.64)
Removes zero-length vectors from the current plot. Recommended before `wrdata` when
`savecurrents` was used (§11.1.1).

### 8.5 Expression vocabulary (§13.2) — what a GUI output expression box may accept
Operators: `+ - * / ^ %` and `,` (which outside a function argument list means `x , y ≡
x + j(y)`); logical `& | !`; relational `< > >= <= = <>` with synonyms
`gt lt ge le eq ne and or not`; C ternary `cond ? expr1 : expr2` (cond must be a scalar).
"The operators are useful when `<` and `>` might be confused with the internal IO redirection."

Functions found in §13.2:
`abs atan atanh avg ceil clock conj cos cosh cph cvector db deriv exp exponential fft floor
group_delay i ifft imag integ j length ln log log10 m3avg mag maximum mean minimum mtimeavg
norm ph poisson real rnd sgauss sin sinh sortorder sqrt stddev sunif tan tanh timer unitvec
unwrap v vecd vecmax vecmin vector`
plus the pseudo-functions `v(vector)` ("With two arguments, `v(a, b)` behaves as
`v(a) - v(b)`") and `i(source)` ("gives access to the current through a voltage source, **if
the matching `source#branch` vector was saved**").
`group_delay`, `cph` (continuous phase beyond π), `unwrap`, `mtimeavg`, `m3avg` and `deriv`
are the analysis-flavoured ones an ADE-beating GUI would want in a menu.

---

## 9. Launching and controlling a run

### 9.1 The three operating modes (§12.4)

| Mode | How | What `.print/.plot/.four` do | What `.meas` does |
|---|---|---|---|
| **Batch** (§12.4.1) | `ngspice -b -r out.raw -o out.log deck.cir` | printed to console/`-o` file — **unless `-r` is given, then ignored** | disabled when `-r` is given |
| **Interactive** (§12.4.2) | `ngspice` then `source deck.cir`, or `ngspice deck.cir` | n/a | n/a |
| **Control** (§12.4.3) | `.control … .endc` in the deck, `ngspice deck.cir` | n/a | `meas` variant |

Manual's warning, verbatim (§12.4.3): **"If your circuit file contains such a control section
(`.control … .endc`), you should not start ngspice in batch mode (with `-b` as parameter). The
outcome may be unpredictable!"**

Also §12.4.3: "The commands within the `.control` section are executed in the order they are
listed and **only after the circuit has been read in and parsed**. If you want to have a
command executed **before** circuit parsing, you may use the prefix `pre_` (13.5.56)."

### 9.2 Command-line options (§12.3), verbatim table

```
ngspice [ -o logfile] [ -r rawfile] [ -b ] [ -i ] [ input files ]
```

| Short | Long | Meaning |
|---|---|---|
| `-n` | `--no-spiceinit` | don't source `.spiceinit` |
| `-t TERM` | `--terminal=TERM` | mfb terminal name (**obsolete**) |
| `-b` | `--batch` | batch mode. "Note that if the input source is not a terminal (e.g. using `<`) ngspice defaults to batch mode (`-i` overrides)." |
| `-s` | `--server` | server mode — temporary rawfile written to stdout, preceded by a line with a single `@` |
| `-i` | `--interactive` | force interactive even when stdin is not a terminal |
| `-r FILE` | `--rawfile=FILE` | default rawfile |
| `-p` | `--pipe` | "Allow a program (e.g., xcircuit) to act as a GUI frontend for ngspice through a pipe. Thus ngspice will assume that the input pipe is a tty and allow running in interactive mode." |
| `-o FILE` | `--output=FILE` | log file for a batch run |
| `-h` | `--help` | help |
| `-v` | `--version` | version |
| — | `--version-small` | small version info |
| `-f` | `--version-full` | full version info |
| `-a` | `--autorun` | "Start simulation immediately, as if a control section `.control / run / .endc` had been added" |
| — | `--soa-log=FILE` | SOA check output |
| `-D` | `--define` | "Set a variable, to be used in a `.control` section. `-D var1` sets a boolean; `-D var2=7` sets a value." |

**`-p` is the mode the manual itself names for a GUI frontend** — §12.14 gives the pipe recipe
(`cat pipe-circuit.cir | ngspice -p`, where the piped file contains *commands*, e.g.
`source circuit.cir` / `tran 10u 2m` / `write pcir.raw all`) and §12.15 gives a bash fifo
recipe (`ngspice -p -i <input.fifo >output.fifo &`). §12.13 documents `-s` server mode and its
`@@@ <bytes> <npoints>` trailer line, noting the point count is missing from the header
("`No. Points: 0`") because it is not yet known when the header is written.

### 9.3 `spinit` and `.spiceinit` (§12.5, §12.6)

`spinit` search: `..\share\ngspice\scripts` relative to the executable; overridden by env
`SPICE_SCRIPTS`. Its stock content loads the code models and OSDI models, guarded by
`if $?xspice_enabled` / `if $?osdi_enabled`, and sets `num_threads`.

`.spiceinit` search order, verbatim list:
1. directory from where the netlist will be loaded
2. `SPICE_USERINIT_DIR`
3. current directory
4. `HOME` (Linux)
5. `USERPROFILE` (Windows)

"read in and executed **after** `spinit`, but **before** any other input file"; suppressed by
`-n`; alternative filename **`spice.rc`**.

The manual's own recommended PDK `.spiceinit`, verbatim — a de-facto "analysis setup" preset a
GUI could ship:
```
set ngbehavior=hsa       ; set compatibility for reading PDK libs
set no_auto_braces       ; omit some time consuming checks during lib loading
set ng_nomodcheck        ; don't check the model parameters
option noinit            ; don't print operating point data
option klu               ; select KLU as matrix solver
optran 0 0 0 100p 2n 0   ; don't use dc operating point, but only transient op
```
(Careful: **`option klu` here silently disables small-signal noise**, §11.1.1/§11.3.4.)
And a PSPICE-model preset:
```
set filetype=ascii
set ngbehavior = ltpsa
option sparse
```
Doc bug: the surrounding prose says "**`set skywaterpdk` suppresses time consuming checks**"
but the example uses `set no_auto_braces`, and `skywaterpdk` appears nowhere in §13.7. Treat
`no_auto_braces` as the real name.

### 9.4 Run-control commands (§13.5)

| Command | Form | Notes |
|---|---|---|
| `run` (13.5.68) | `run [rawfile]` | "If there were any of the control lines `.ac`, `.op`, `.tran`, or `.dc`, they are executed." (the list omits `.noise`, `.pz`, `.sens`, `.tf`, `.disto`, `.sp` — see §13) |
| `bg_run` (13.5.10) | `bg_run` | shared-ngspice background thread; data via plots and/or the `SendData` callback (15.3.3.4) |
| `bg_halt` (13.5.9) | `bg_halt` | "There may be conditions where this command cannot be executed immediately." |
| `bg_ctrl` (13.5.8) | `bg_ctrl` | suspend `.control` commands until `bg_run` finishes; equivalent to `set controlswait` |
| `aspice` (13.5.7) | `aspice input-file [output-file]` | run a *separate* ngspice asynchronously and load its raw data afterwards |
| `stop` (13.5.92) | `stop [after n] [when value cond value] ...` | conditions `= <> > < >= <=` with aliases `eq ne gt lt ge le`. Multiple conditions are **conjoined**. "All `stop` commands have to be given in the control flow **before** the `run` command." |
| `resume` (13.5.67) | `resume` | continue after `stop` or ctrl-C |
| `step` (13.5.91) | `step [number]` | iterate n time-points then stop |
| `status` (13.5.90) | `status` | list saved nodes/parameters, traces and breakpoints, **with the debug numbers** |
| `delete` (13.5.21) | `delete [debug-number …]` | remove them. "The debug numbers are those shown by the `status` command (unless you do `status > file`, in which case the debug numbers are not printed)." |
| `trace` (13.5.98) | `trace [node …]` | print node value at every analysis step. **"Tracing is not applicable for all analyses."** |
| `iplot` (13.5.43) | `iplot [-d delay] [-w width] [-o] [node …]` | live incremental plot; `-d` delay in simulation steps, `-w` fixed window width in simulation units, `-o` automatic vertical offset for event nodes. **"Node expressions are not supported"**; **"The `@name[param]` notation does not work yet."** |
| `where` (13.5.106) | `where` | last non-converging node or device. Recipe: "When the analysis slows down severely or hangs, interrupt the simulator (with control-C) and issue the `where` command. Note that **only one node or device is printed**." |
| `reset` (13.5.65) | `reset` | "Throw out any intermediate data … and **re-parse the input file** … overriding the effect of any `set` or `alter` commands. These two need to be repeated after the `reset` command." Also: "**Reset is required after an `alterparam` command** for making the parameter change effective." |
| `snsave` / `snload` (13.5.86 / 13.5.85) | `snsave file` / `snload circuit-file file` | checkpoint a stopped transient and resume in a *new* ngspice. **"snsave/snload will not work if you have XSPICE devices (or V/I sources with polynomial statements) in your input deck."** Also a known bug: "we currently need the term 'script' in the title line (first line) of the script." |
| `rusage` (13.5.69) | `rusage [resource …]` | resources include `time cputime totalcputime decklineno netloadtime netparsetime faults space temp tnom equations totiter accept rejected loadtime reordertime …` — a ready-made "simulation statistics" panel |
| `inventory` (13.5.42) | `inventory` | count of instances per device type |
| `devhelp` (13.5.23) | `devhelp [-csv] [-type] [-flags] [device [param]]` | the machine-readable parameter catalogue. **`-csv` "is used to generate the simulator documentation"** — i.e. this is the supported way for a GUI to enumerate device/model parameters. Flag letters documented: `X Q Z QO A P AA N U R`, several of which are *sensitivity-analysis* semantics (`X` not used in sensitivity; `Q`/`Z`/`QO` sensitivity chaining; `P` "principal of the device. Used for naming output variables in sensitivity"). |

`alter` / `altermod` / `alterparam` (13.5.3–13.5.5) are the parameter-change trio a sweep GUI
needs; ordering rules are in §10.

---

## 10. Parameter sweeping — the `.step` gap, stated by the manual

**§12.11.4.3, titled `.step`, is not a card description — it is an admission.** Verbatim:
"Repeated analysis in ngspice is offered by a **short script inside of a `.control` section**
added to the input file." It then shows a `while` loop with `alter` + `run` + `write` +
`set appendwrite` and the comment `* replaces .STEP R1 1k 10k 1k`.

`.step` is absent from the §2.2 dot-command list, and I confirmed it is absent from the
parser: the dot tokens present in `src/frontend/inpcom.c`, `src/frontend/inp.c`,
`src/frontend/subckt.c` and `src/spicelib/parser/*.c` do not include `.step`.

**The control-language tutorial (D5 §10, "Emulate nested `.step` commands") is the definitive
recipe** and states the ordering rule that nothing in the manual states as plainly:

> "The `alterparam` command has to be followed by a `reset` command to become activated. On the
> other hand `alter` commands are **resetted by** `reset`. Therefore all three altering commands
> have to be in the inner loop, repeated each time the loop is executed. **Any `alterparam` has
> to come first, then `reset`, only then any `alter` (or `altermod`) commands.**"

Its worked three-level nested sweep (which a GUI's sweep engine can emit almost verbatim):
```
foreach val1 10k 20k 30k
  foreach val2 $cvalues
    foreach val3 1m 3.3k 6.6k
      let index = index + 1
      alterparam rr1 = $val1
      alterparam cc2 = $val2
      reset
      alter R2 $val3
      run
      set plotstrdb = ( $plotstrdb db({$curplot}.v(10)) )
    end
  end
end
plot $plotstrdb xlimit 1 1e4
```
D5 also notes the aspiration: "**In the future ngspice may be enabled to translating such
`.step` commands into emulating control sections automatically and transparent to the user.**"
Do not build the GUI on that.

Second technique from D5 §11, "Modify a circuit on the fly": `.IF / .ELSEIF / .ENDIF`
switched by `alterparam <selector>` + `reset` selects between whole circuit blocks (e.g. two
different op-amps). **"Some restrictions apply, as the following netlist components are not
supported within the `.IF … .ENDIF` block: `.SUBCKT`, `.INC`, `.LIB`, and `.PARAM`."**

D5 §2 also records the mundane but essential rule: "**Command `reset` is required to set back
internal data after a transient simulation**" before running a second, different analysis in
one session.

---

## 11. Statistical analysis / Monte Carlo (manual ch. 18)

Two documented routes.

**(a) Random parameters in the netlist (§18.2).** Built-in numparam functions:

| Function | Meaning |
|---|---|
| `gauss(nom, rvar, sigma)` | nominal + Gaussian, std-dev `rvar` **relative** to nominal, divided by `sigma` |
| `agauss(nom, avar, sigma)` | nominal + Gaussian, std-dev `avar` **absolute**, divided by `sigma` |
| `unif(nom, rvar)` | nominal + relative uniform variation ±`rvar` |
| `aunif(nom, avar)` | nominal + absolute uniform variation ±`avar` |
| `limit(nom, avar)` | nominal ±`avar` depending on whether a random number in [−1,1] is >0 or <0 |

Crucial evaluation-timing rule, verbatim: "The frontend parser evaluates all `.param` or
`.func` statements upon start-up of ngspice, **before** the circuit is evaluated… **If the
random function appears in a device card** (e.g. `v11 11 0 'agauss(1,2,3)'`), a **new** random
number is generated." So `.param aga = agauss(...)` freezes one draw; inline expressions draw
per instance; `.func` bodies re-draw at each use.

**(b) Control-language Monte Carlo (§18.5.2).** `sgauss(0)` / `sunif(0)` in a loop with
`alter`/`altermod`. The distributed example is `examples/Monte_Carlo/MonteCarlo.sp`; the manual
reprints it in full, including the idiom for accumulating per-run vectors into a scratch plot:
```
set curplot = new
set scratch = $curplot
…
let vout{$run}={$dt}.v(out)
…
plot db({$scratch}.all)
```
and the local redefinitions `define unif(nom, var) (nom + nom*var * sunif(0))` etc.

Reproducibility: `setseed nn` (§13.5.77) or `.options SEED=val|random` + `SEEDINFO`
(§11.1.1); variable `rndseed` (§13.7). `mc_source` (§13.5.48) reloads the preprocessed netlist
to create a fresh circuit, "used in conjunction with the `alterparam` command".

Circuit optimization (ch. 19) is documented as four external approaches — ngspice scripts,
tclspice, a Python script, and **ASCO** — not as a built-in analysis.

---

## 12. Compatibility modes (§12.11), because they change what a deck means

Table 12.2, verbatim:

| Flag | Ref. | Description |
|---|---|---|
| `a` | — | complete netlist transformed |
| `ps` | 12.11.5 | PSPICE compatibility |
| `hs` | 12.11.10 | HSPICE compatibility |
| `spe` | 12.11.9 | Spectre compatibility |
| `lt` | 12.11.6 | LTSPICE compatibility |
| `s3` | — | Spice3 compatibility |
| `ll` | — | all (currently not used) |
| `ki` | 12.11.8 | KiCad compatibility |
| `eg` | — | EAGLE compatibility |
| `mc` | — | for 'make check' |

Rules stated: flag `a` combines with any other; `set ngbehavior=ps` **without** `a` applies
PSPICE compat only to `.include`d libraries; "**Flags `ps` and `hs` are mutually exclusive**";
`unset ngbehavior` resets.

**Two doc problems here:**
1. **§12.11.1 says "Per default no compatibility mode is selected." §13.7 says the
   `ngbehavior` "Default value is 'all'." These contradict.**
   Source settles it: `src/frontend/inpcompat.c:60-101` initialises every flag to `FALSE` and
   only sets any if `cp_getvar("ngbehavior", …)` succeeds — there is no built-in default. The
   built binary prints `Note: No compatibility mode selected!` on a bare run.
   **Trust §12.11.1; §13.7's sentence is wrong.**
2. **The source has a flag the table omits: `xs` (XSPICE)** —
   `src/frontend/inpcompat.c:81` sets `newcompat.xs` from a substring match on `"xs"`, and
   `print_compat_mode()` prints it. Not in Table 12.2.
   Note also that `set_compat_mode()` uses `cistrstr` (substring, case-insensitive), so flags
   are matched as substrings of one string, e.g. `hsa` = `hs` + `a`, and `spe` explicitly
   clears `ps`, `lt`, `ki`, `eg` (`inpcompat.c:96-99`), while `mc` clears everything
   (`inpcompat.c:100-110`).

---

## 13. FOUND ONLY IN DOCS — the completeness net

Items a source-reading agent working from `src/spicelib/analysis/` would **not** find, or
would find without meaning. This is the list the rest of the team should diff against.

### 13.1 Analyses / cards that are not in `src/spicelib/analysis/` at all
1. **Transient noise** (§11.3.11). Not an analysis at all — it lives on `VSRC`/`ISRC`
   (`TRNOISE(...)`) and rides on `.tran`. A GUI's "noise" menu must offer both this and
   `.NOISE`.
2. **`.FOUR`** (§11.6.4) — post-processing on transient output, implemented in the frontend.
3. **`.MEAS` / `meas`** (§11.4) — an entire measurement sub-language, frontend-only.
4. **`.PROBE`** (§11.6.5) — netlist rewriting (inserts VSRC/VCVS/power expressions), not an
   analysis.
5. **`.SNDPARAM` / `.SNDPRINT`** (§11.6.8, §13.11) — WAV output of an analysis result.
6. **`fft`, `spec`, `psd`, `fourier`, `linearize`, `cutout`, `remzerovec`** — frontend
   commands that are analyses to a user.
7. **`optran`** (§11.3.5) — a *command*, not a card, that reconfigures the OP algorithm and
   is on by default in this tree.
8. **`.probe alli` / `.options savecurrents` / manual 0 V source** — the three documented ways
   to get device terminal currents (§11.7), each with different analysis coverage.

### 13.2 Options and variables documented outside the options chapter
9. `savecurrents_mos1` / `savecurrents_bsim3` / `savecurrents_bsim4` — only in §11.7.3.
10. `rseries` and `cshunt` — only in §11.1.2.1 (and `rseries` is a preprocessing pass, not a
    CKT option).
11. `newtrunc`, `ltetrtol`, `ltereltol`, `lteabstol` — only in §12.12, with the recommended
    values "**optimum: 400-500 for gear, 800 for trap**" for `ltetrtol` and defaults
    `ltereltol=1e-3`, `lteabstol=1e-6`. Requires `--enable-predictor` ("**which is the
    default**"). Manual's own verdict: "This new feature is **currently largely unexplored**,
    will need theoretical and practical backings."
12. `dyngmin` — only in the §11.3.5 prose; absent from §13.7.
13. `xtrtol` (§12.9/§13.7) and the fact that TRTOL is silently forced to 1 when XSPICE `A`
    devices are present, "**doubling or tripling CPU time**".
14. `nostepsizelimit` (§12.9/§13.7) — the transient max-step behaviour a GUI's "max timestep"
    control must account for.
15. `sqrnoise` — changes the units of every noise result.
16. `nosavecurrents` — the documented workaround for mixing `savecurrents` with AC.
17. `enable_noisy_r` + per-instance `noisy=0|1` — whether behavioral resistors contribute noise.
18. `rsdiode`, `diode_cj0`, `diode_rser` — silent model completion that changes results.
19. `sim_status` — set to 1 when a simulation aborts. **The documented way for a script (and
    therefore a GUI) to detect a failed run.**
20. `strict_errorhandling` — exit code 1 on a parse error, settable **only** in
    `spinit`/`.spiceinit`.
21. `measoutfile`, `measureprec` — how `.meas` output reaches a file.
22. `controlswait` / `bg_ctrl` — the shared-library ordering trap.
23. `keep#branch` — rawfile branch-current naming, "for compatibility with software like ICCAP".

### 13.3 Diagnostics that only exist in prose
24. **`speedcheck` and `deltacheck` vectors** (§12.17.3): with `set ngdebug`, a transient
    simulation generates a vector `speedcheck` (wall-clock time vs. simulated time, ~100 ms
    resolution) and `deltacheck` (accepted timestep delta vs. time) in the tran plot. **This is
    a ready-made "why is my simulation slow / where is it struggling" plot** and appears
    nowhere else.
25. `set ngdebug` also writes `debug-out.txt`, `debug-out2.txt`, `debug-out3.txt` and
    `debug-out-mc.txt` — the netlist at four preprocessing stages.
26. `set debug` "will yield an analysis of each command which is run from `.spiceinit` and
    `.control`".
27. `--enable-ftedebug` / `--enable-stepdebug` configure flags (§12.17.4): the latter "yields a
    very powerful tool for analysing the steps of a transient simulation. **The amount of
    messages printed however is overwhelming and may be interpreted by an insider only.**"

### 13.4 Distortion output variable names
28. §11.6.3's `.plot` example is `\.plot disto hd2 hd3(R) sim2` — **`hd2`, `hd3(R)`, `sim2`
    are the only appearance of distortion output-variable names in the entire manual.** There
    is no table of them. A distortion GUI needs those names and the manual does not supply a
    complete list. (Flagged in Gaps.)

### 13.5 Practice, accuracy and "this is experimental" statements
29. PSS: "**Experimental code, not yet made publicly available.**" (§11.3.12) — and
    "autonomous circuits only" (§1.2.8).
30. Transient noise: "**still experimental**" plus a six-item open-questions list (§11.3.11).
31. `.sp` Touchstone export: "**to be implemented yet**" (§11.3.8).
32. Pole-zero: "sub-optimal numerical search… may find an excessive number of poles or zeros";
    "**Transmission lines are not supported**" (§1.2.4).
33. Sensitivity: numerical perturbation, "zero-valued parameters are not analyzed" (§1.2.6).
34. Distortion: the five-device support list, the HD2/HD3 normalisation warning, and the
    `f2overf1` rationality warning (§11.3.3, §1.2.5).
35. `.meas`: "**not all of the `.measure` commands have been implemented**" (§11.4.3).
36. AC: `@dev[param]` probes unsupported (§11.3.1, §13.5.1).
37. `iplot`: `@name[param]` "does not work yet" (§13.5.43).
38. `.print`: AC current modifiers "**not yet implemented**" (§11.6.2).
39. KLU ⊄ noise, KLU ⊄ CIDER (§11.1.1).
40. `snsave`/`snload` ⊄ XSPICE devices and POLY sources (§13.5.86).
41. `fourier` accuracy rule TMAX = period·numperiods/100 (§13.5.35).
42. `.sp` RF ports insert a series Z0 resistor that "affects all simulations" (§4.1.11).
43. `.probe` sees top-level devices only (§11.6.5.1).
44. `.save vm(out)` silently degrades to `v(out)` in a rawfile (§11.6.1).
45. If `.save` is absent but `.probe` is present, **only** the probe vectors are saved
    (§11.6.5.3).
46. `par('…')` is limited to 99 per file and reserves node names `pa_00`…`pa_99` (§11.6.6).
47. `-b` + `-r` silently disables `.print`, `.plot`, `.four` and `.meas` (§11.6, §11.4.2).
48. `.control` + `-b` → "**The outcome may be unpredictable!**" (§12.4.3).

### 13.6 Worked examples the docs supply and the source does not
49. §11.3.11's shot-noise-via-B-source subcircuit (`ishot`).
50. §13.5.54's `trtol` sweep harness (`option trtol=N / run / rusage traniter trantime / reset`)
    — a template for any "compare simulator settings" GUI feature.
51. §13.5.52's two-file / one-file noise raw output recipes.
52. §13.5.109's `wrnodev` checkpoint-and-restart recipe.
53. §18.5.2.1's full Monte Carlo script.
54. D5 §10's nested-`.step` emulation and §11's `.IF`-switched circuit variants.
55. §13.5.33/§13.5.45's linearize→window→fft recipe.
56. ch. 17's classic decks (AC-coupled amplifier, differential pair, MOSFET characterization,
    RTL inverter, 4-bit adders bipolar and MOS, transmission-line inverter) — good GUI demo
    content.
57. Named example decks referenced by path: `examples/measure/`,
    `examples/Monte_Carlo/MonteCarlo.sp`, `examples/xspice/delta-sigma/delta-sigma-1.cir`,
    `examples/snapshot/`, `soi/ring51_40.sp`, `555-timer-2.cir`.

---

## 14. Where the manual is BEHIND this tree (fork-local features)

**This is not upstream drift — it is local work in `/home/analog/dev/ngspice` on branch
`ver_50`.** `git log --oneline origin/pre-master-47..ver_50` shows **207 commits** not in
upstream. The user-visible feature commits are:

```
feat: record the case mode in the batch raw header too, opt-in
feat: record the case mode in the raw header, opt-in
feat: report two spellings of one node name
feat: report the case mode in force as curcasemode
feat: report a subcircuit pin that a body misses by case alone
feat: report a B source V() reference that misses by case
feat: make casemode=distinguish real and stop the vector table aliasing
feat: add the casemode switch and gate both reader folds on it
feat: add cistrstr, a case insensitive strstr
```

Concretely:
- A **`casemode`** variable (`fold` | `preserve` | `distinguish`) settable via
  `-D casemode=preserve`, `set casemode = preserve` in `.spiceinit`/`spinit`, or
  `ngSpice_Command("set casemode=preserve")` before loading a circuit. Documented in this
  tree's `NEWS` (top block, under "Ngspice-47"), **absent from the official manual** — I
  grepped: `casemode` occurs **0 times** in `manual.xhtml`.
- A read-only **`curcasemode`** variable reporting the mode in force. Verified live:
  `echo $curcasemode` → `fold`; `echo $casemode` → `Error: casemode: no such variable.`
  (so the switch is write-only-ish and `curcasemode` is the probe).
- Opt-in recording of the case mode in the raw-file header (both interactive `write` and the
  batch writer).

**Implication for the plan:** the official manual is a valid completeness net for the
*upstream* analysis surface, but a GUI targeting this tree must additionally read this tree's
`NEWS`, `AGENTS.md`, and `doc/claude/` + `doc/codex/` artefacts. Any GUI feature that displays
or matches node/vector names must be `casemode`-aware, and `curcasemode` is the documented
probe.

---

## 15. Build-gated capabilities, resolved against this tree

`build-ver_50/src/include/ngspice/config.h` (generated):

| Feature | Macro | configure flag | Default upstream | **In this build** |
|---|---|---|---|---|
| XSPICE | `XSPICE 1` (line 579) | `--disable-xspice` | **on** | **ON** |
| OSDI | `OSDI 1` (line 502) | `--disable-osdi` | **on** | **ON** |
| KLU | `KLU` (line 463) | — (`--with-…`) | on | **ON** |
| S-parameter `.sp` | `RFSPICE 1` (line 535) | `--enable-sp` / `--disable-sp` (`configure.ac:1220-1228`) | **on** | **ON** |
| CIDER | `CIDER` | `--enable-cider` (`configure.ac:149-151`) | **off** | **OFF** |
| PSS `.pss` | `WITH_PSS` | `--enable-pss` (`configure.ac:153-155`, define at `:1083`) | **off** | **OFF** |
| SPICE2 sensitivity `.sens2` | `WANT_SENSE2` | `--enable-sense2` (`configure.ac:232-234`) | **off** | **OFF** |
| Harmonic balance `.hb` | `WITH_HB` | **no configure flag exists** | dead | **OFF (unreachable)** |
| voltage-based truncation | `--enable-predictor` | manual §12.12 says "**which is the default**" | on | assumed on (not verified in config.h) |

`.hb` is dispatched at `src/spicelib/parser/inp2dot.c:918-924` inside
`#ifdef RFSPICE / #ifdef WITH_HB`, but `WITH_HB` is never defined anywhere in `configure.ac`.
`.sens2` at `inp2dot.c:940-945` under `WANT_SENSE2`. **Neither `.hb` nor `.sens2` is documented
in the manual at all** — these are the reverse of "found only in docs": source-only, and both
unreachable in this build. A GUI should ignore them.

The stock `spinit` (§12.5) guards code-model and OSDI loading with `if $?xspice_enabled` /
`if $?osdi_enabled`, so those two variables are the documented runtime probes. **There is no
documented runtime probe for RFSPICE/`.sp` or PSS** — see Gaps.

---

## 16. Facts I verified by running the built binary (read-only, in scratch)

Binary: `/home/analog/dev/ngspice/build-ver_50/src/ngspice`, banner `ngspice-46+`,
"Compiled with KLU Direct Linear Solver", creation date 2026-09-03.

### 16.1 Plot names produced by each analysis
One deck running `op / ac / tran / noise / tf / pz / disto / sens` in a `.control` section,
then `setplot`, yields exactly:

```
sens3   (Sensitivity Analysis)
disto3  (DISTORTION - 3rd harmonic)
disto2  (DISTORTION - 2nd harmonic)
pz2     (Pole-Zero Analysis)
tf2     (Transfer Function)
noise2  (Integrated Noise)
noise1  (Noise Spectral Density Curves)
tran1   (Transient Analysis)
ac1     (AC Analysis)
op1     (Operating Point)
const   Constant values (constants)
```

**Key facts for a GUI's result browser, none of which the manual tabulates:**
- Each analysis kind has its **own** counter (`ac1`, `tran1`, `op1`), but `tf`, `pz` and
  `disto` continue a *shared* counter (`tf2`, `pz2`, `disto2`/`disto3`) — plot numbering is
  not simply per-type.
- **`disto` produces two plots** (`DISTORTION - 2nd harmonic`, `DISTORTION - 3rd harmonic`)
  in harmonic mode. The manual describes the components but never names the plots.
- `noise` produces exactly two, as documented.
- The human-readable plot titles above are the strings a GUI should match on.

`.sp` produces a single plot `sp1 (SP Analysis)`.

### 16.2 `.sp` output vectors (2 ports, `donoise=1`), verbatim from `display`
```
Cy_1_1 Cy_1_2 Cy_2_1 Cy_2_2       : current, complex
NF NFmin                          : decibel, complex
Rn                                : impedance, complex
SOpt                              : notype, complex
S_1_1 S_1_2 S_2_1 S_2_2           : s-param, complex
Y_1_1 Y_1_2 Y_2_1 Y_2_2           : admittance, complex
Z_1_1 Z_1_2 Z_2_1 Z_2_2           : impedance, complex
frequency                         : frequency, complex [default scale]
in mid out                        : voltage, complex
v1#branch v1#res v2#branch v2#res : current / voltage, complex
```
Note the vector **types** — `s-param`, `decibel`, `impedance`, `admittance`, `notype` — which a
plotting GUI can use for axis labelling. Note also the extra `vN#res` vectors created by the
port series resistor.

**`wrs2p` does NOT work on an `.sp` plot.** Running `wrs2p file.s2p` immediately after
`sp lin 11 1meg 100meg 1` prints:
```
Note: only 2 ports 1 and 2 are supported by wrs2p
Error: No Rbase vector given
```
and writes nothing. §13.5.110's requirement list ("vectors frequency, S_1_1 … and vector
`Rbase`") describes the *older script-based* S-parameter flow of §13.9.4, not the `.sp`
analysis, which creates no `Rbase`. This corroborates §11.3.8's own "to be implemented yet".
**A GUI must not advertise Touchstone export from `.sp` on this tree.**

### 16.3 Live option defaults
`option` with no arguments (after a `run`) dumps the values quoted in §4.8 above. Of note,
matching the manual: `temp = tnom = 300.15 K`, `METHOD = TRAPEZOIDAL`, `MaxOrder = 2`,
`xmu = 0.5`, `abstol 1e-12`, `chgtol 1e-14`, `vntol 1e-06`, `pivtol 1e-13`, `reltol 0.001`,
`pivrel 0.001`, `itl1 100`, `itl2 50`, `itl4 10`, `trtol 7`, `gmin 1e-12`, MOS `L = W = 1e-4`,
`AD = AS = 0`. **`gminsteps = 1` and `srcsteps = 1`** — mode selectors, per §2.1.

### 16.4 Compatibility default
A bare run prints `Note: No compatibility mode selected!`, confirming §12.11.1 over §13.7.

### 16.5 Interactive commands the binary knows
`help all` lists `disto`, `pz` and `sp` as commands (and **not** `pss`, consistent with
`WITH_PSS` being off). `src/frontend/commands.c` additionally registers `optran`, `pss`
(gated), `cutout`, `linearize`, `inventory`, `mdump`, `mrdump`, `devhelp`, `remzerovec`,
`wrnodev`, `sndparam`, `sndprint`, `snload`, `snsave`, `mc_source`, `esave`, `eprvcd`,
`edisplay`, `eprint`, `osdi`, `settype`, `setseed`, `strcmp`/`strslice`/`strstr`,
`fopen`/`fclose`/`fread`, `psd`, `spec`, `fft`, `fourier`, `meas`, `where`, `sysinfo`.
`help all` output is **incomplete** (it omits `linearize`, `cutout`, `wrnodev`, `meas`…), so a
GUI must not use it as the capability list.

---

## 17. Contradictions and errors found in the docs — flagged, with my verdict

| # | Where | The problem | Verdict |
|---|---|---|---|
| C1 | §13.7 `ngbehavior` "Default value is 'all'" vs §12.11.1 "Per default no compatibility mode is selected" | direct contradiction | **§12.11.1 is right** (`src/frontend/inpcompat.c:60-101`; binary prints "No compatibility mode selected!") |
| C2 | §11.1.2 `GMINSTEPS` / §11.1.4 `SRCSTEPS` described as *counts* vs §11.3.5 describing them as *mode selectors* 0/1/2 | contradiction | **§11.3.5 is right** (`src/spicelib/analysis/cktop.c:57-92`) |
| C3 | §11.3.5 "optran step size **10n**, total optran time 10u" | wrong value | **Source: 100n** (`src/frontend/init.c:87`, literal `"100n"`). Also, optran is armed **by default** here (`init.c:77-94`), which §11.3.5's "(optional)" understates |
| C4 | §13.5.33 window table headed "for the spec **and** fft command" | `blackmanharris` and `flattop` exist for `fft` only | **Two different sets**: `fftext.c:106-169` vs `spec.c:93-141`. §13.7's list is a third, incomplete variant |
| C5 | §1.2 "Supported Analyses" omits `.SP`, `.TF`, transient noise | stale chapter | **Trust ch. 11.3** |
| C6 | §1.2 "the Code Model subsystem does not implement … Noise" vs §24.8 documenting code-model noise | contradiction | **§24.8 is right** (`src/xspice/mif/mifnoise.c`, `icm/analog/gain/ifspec.ifs:58`, this tree's `NEWS`) |
| C7 | Table 12.2 omits the `xs` (XSPICE) compatibility flag | incomplete | Source has it (`src/frontend/inpcompat.c:81`) |
| C8 | §11.3.11 "isrc not yet available" vs its own example using `IRTS2 … trnoise(...)` and `IALL … trnoise(...)` | self-contradiction | **Unresolved — needs a source agent.** See Gaps |
| C9 | §11.6.7 prints the card as `.with out = 256` | typo for `.width` | cosmetic |
| C10 | §11.7.3 cross-references "chapters 31.6.1, 31.6.8 and 31.6.9" | the manual has no chapter 31 | broken cross-ref |
| C11 | §12.6 prose credits `set skywaterpdk` with suppressing checks, while the example uses `set no_auto_braces`; `skywaterpdk` is not in §13.7 | stale name | **Use `no_auto_braces`** |
| C12 | §13.5.68 `run`: "If there were any of the control lines `.ac`, `.op`, `.tran`, or `.dc`, they are executed" | incomplete list — omits `.noise`, `.pz`, `.sens`, `.tf`, `.disto`, `.sp` | I verified a single `.control` `run` is not what I tested (I issued explicit commands); **needs confirmation** — see Gaps |
| C13 | §13.5.88 `Sp` carries anchor id `subsec_Spec__Create_a_1` | wrong anchor, deep links land on `Spec` | cosmetic but affects link-building |
| C14 | `pz`, `disto` (and `pss`) have dot-card sections but **no §13.5 command section** | doc gap, not a source gap | both are real commands (`commands.c`, `help all`) |
| C15 | §13.5.110 `wrs2p` requirement list mentions `Rbase` "as a result of an **ac** analysis" | does not apply to `.sp` output | verified broken on `.sp` (§16.2) |

---

## 18. Implications for the ASE-L GUI (the short version; detail is above)

1. **The analysis menu is larger than "the seven Berkeley analyses".** The complete, current
   list for this build is: `op`, `dc`, `ac`, `tran`, `noise`, `disto`, `pz`, `sens`, `tf`,
   `sp` — plus transient noise (a source property + `.tran`), plus the post-processing
   analyses `fourier`/`fft`/`spec`/`psd`, plus `.meas`. `pss` is compiled out here.
2. **`.step` does not exist.** Sweeps must be generated as control-language loops, and the
   ordering `alterparam → reset → alter/altermod → run` is mandatory (D5 §10). This is the
   single biggest place where ASE-L can beat ADE-L: generate the loop, name the plots, and
   collect `{$curplot}.v(x)` automatically.
3. **Analysis-specific capability gaps must be surfaced, not discovered.** `@dev[param]` probes
   die in AC; `savecurrents` dies in AC; `disto` supports five old device models; `pz` refuses
   transmission lines; KLU kills `.NOISE`; `snsave` kills XSPICE decks; `.probe` ignores
   subcircuit internals; Touchstone export from `.sp` does not work here.
4. **The `.options` / `set` split is a real two-namespace problem.** Some "options" are CKT
   task fields (`cktsopt.c`), some are interpreter variables (`src/frontend/`). They differ in
   precedence (§11.1.7), in whether `reset` clears them, and in whether `option` reports them.
   A settings UI should model both and use `option` (no args) as the read-back.
5. **Results are plots with generated names.** `ac1`, `tran1`, `noise1`/`noise2`,
   `disto2`/`disto3`, `sp1`, `op1`, `tf2`, `pz2`, `sens3` — with per-kind and shared counters.
   `$curplot` is the reliable handle immediately after a run. `setplot` switches; `display`
   enumerates; `destroy` frees.
6. **Save-set management is mandatory for anything large.** `save`/`.save` before `run`;
   `save none` / `save nosub` / `save nointernals` / `esave` for event nodes; `.probe` adds to
   the save set and *replaces* the default set if `.save` is absent.
7. **Launching:** `-p` pipe mode is the manual's own recommendation for a GUI frontend, with
   `-s` server mode and the fifo recipe as alternatives, and `libngspice` (ch. 15,
   `ngSpice_Init` / `ngSpice_Command` / `ngSpice_Circ` / `bg_run` / `SendData` /
   `ngSpice_SetBkpt` / `ngSpice_Reset`) as the in-process route. In shared mode remember
   `set controlswait` / `bg_ctrl`, and that `sharedmode` is set so decks can suppress plotting.
8. **Failure detection:** `$sim_status` (1 on abort), `strict_errorhandling` (exit 1 on parse
   error, `.spiceinit`-only), `where` (last non-converging node/device), `--soa-log=FILE`, and
   the `speedcheck`/`deltacheck` vectors under `set ngdebug`.

---

## 19. Gaps — what I could not determine, and who should close it

1. **Distortion output-variable names.** The manual names `hd2`, `hd3(R)` and `sim2` once, in a
   `.plot` example (§11.6.3), and nowhere defines the set. A source agent should read
   `src/spicelib/analysis/distoan.c` / `cktdisto.c` and produce the authoritative list, because
   a distortion GUI is unusable without it.
2. **§11.3.11's "isrc not yet available" vs its own `IRTS2 … trnoise(...)` example.** Needs
   `src/spicelib/devices/isrc/` checked.
3. **Runtime capability probes for `.sp` and `.pss`.** `xspice_enabled` and `osdi_enabled` are
   documented; nothing analogous is documented for `RFSPICE` or `WITH_PSS`. A GUI needs a
   detection strategy (try the command and catch the error? parse `version`?). Source agent to
   advise.
4. **Whether a bare `run` executes `.noise` / `.pz` / `.sens` / `.tf` / `.disto` / `.sp` cards.**
   §13.5.68 lists only `.ac`, `.op`, `.tran`, `.dc`. I tested explicit commands, not card
   dispatch. `src/spicelib/analysis/cktdojob.c` and `src/frontend/runcoms.c` should settle it.
   This matters: it decides whether a GUI writes cards or issues commands.
5. **`--enable-predictor` default.** §12.12 asserts it is the default; I did not find the
   corresponding `AC_DEFINE` and did not confirm it in `config.h`.
6. **`diaggmin` and `delmin`.** Printed by the live `option` dump but present in neither the
   manual nor `cktsopt.c`'s settable table. Where are they set?
7. **CIDER's analysis-relevant cards** (ch. 26: `METHOD`, `OPTIONS`, `OUTPUT`, `NUMD`, `NBJT`,
   `NUMOS`, 2-D contour plots). CIDER is compiled **off** here, so I deliberately did not mine
   ch. 26. If the GUI must support a CIDER-enabled build, that chapter is a separate pass.
8. **`docs/cf/op_operating_point.xlsx` and `docs/cf/time-step-control.docx`** — official
   control-flow documents for exactly the two algorithms a GUI's convergence panel configures.
   Binary Office formats; not opened.
9. **`.meas` forms that are "not implemented"** (§11.4.3 says some are). Which ones? Needs
   `src/frontend/com_measure2.c` / `measure.c`.
10. **XSPICE event-driven analysis coverage.** §1.2 says DC + transient only for event-driven
    parts; §24.8 now adds noise for *analog* code models. What an event-driven deck can
    actually run in AC/noise needs an XSPICE-side agent (`src/xspice/evt/`).
11. **Chapter 8 (XSPICE models) and chapter 27 (internal device parameters)** were out of
    scope for this pass but are directly relevant to what a GUI can probe (`@dev[param]`);
    §27.1 "Accessing internal device parameters" is the reference and should be mined by
    whoever owns output/probe selection.
