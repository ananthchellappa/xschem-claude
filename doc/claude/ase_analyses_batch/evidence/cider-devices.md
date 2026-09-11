# Dossier: CIDER, device-level gating of analyses, and OSDI

**Area owner:** build-gated capability (CIDER) + per-device function-pointer gating of every
ngspice analysis + OSDI/Verilog-A analysis support.

**Trees inspected (read-only):**
- ngspice source: `/home/analog/dev/ngspice`, branch `ver_50`, `git describe` = `ngspice-46-419-gccebdf2a2`
- built binary used for empirical checks: `/home/analog/dev/ngspice/build-ver_50/src/ngspice`
  (banner: `ngspice-46+`, "Compiled with KLU Direct Linear Solver")
- configure line for that build (`build-ver_50/config.log:7`):
  `../configure --prefix=/home/analog/dev/ngspice/build-ver_50/stage --with-readline=yes`

All scratch decks were written under
`/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/`.
Nothing in either repo was modified.

Line references are `path:LINE` relative to `/home/analog/dev/ngspice/`.

---

## 0. TL;DR for the plan author

Three things dominate everything else in this area:

1. **ngspice never tells the user that an analysis is unsupported for the devices in the deck.**
   Every per-device analysis hook is guarded by `if (DEVices[i] && DEVices[i]->DEVxxx && ckt->CKThead[i])`.
   A missing hook means the device is *silently omitted from that analysis' matrix load*. The run
   completes, the plot appears, and the numbers are wrong (usually zero). I verified this empirically
   for `.disto` (§2.6.1), `.noise` (§2.6.2) and `.ac` with a `level=6` MOSFET (§2.6.3).
   **This is the single strongest argument for the coverage matrix in §2.5 being baked into ASE-L.**

2. **CIDER is OFF in this tree** (`build-ver_50/src/include/ngspice/config.h:10-11` → `/* #undef CIDER */`).
   A CIDER deck loaded into this binary dies with `could not find a valid modelname` pointing at the
   *instance* line, never mentioning CIDER (§1.9). CIDER adds **no new analysis type** — it adds five
   numerical device types plus a 16-card model sub-language, and it *narrows* which analyses work
   (no noise, no distortion, no SOA). A GUI should **detect** it, not offer it unconditionally.

3. **The `DEVsen*` family of pointers is dead code.** `DEVsenSetup`/`DEVsenLoad`/`DEVsenUpdate`/
   `DEVsenAcLoad`/`DEVsenPrint`/`DEVsenTrunc` are declared in `src/include/ngspice/devdefs.h:92-103`
   and populated by ~20 devices, but **are never called anywhere outside `src/spicelib/devices/`**
   (verified by exhaustive grep, §2.2). Modern `.sens` (`src/spicelib/analysis/cktsens.c`) is a
   finite-difference perturbation engine that uses `DEVask`/`DEVparam`/`DEVload`/`DEVacLoad`/
   `DEVtemperature` instead. Do **not** grey out `.sens` based on `DEVsenSetup`.

---

## 0.1 Build configuration of THIS tree (authoritative, from the generated header)

Source: `build-ver_50/src/include/ngspice/config.h`.

| Symbol | State here | Line | configure flag | Default upstream |
|---|---|---|---|---|
| `CIDER` | **undef (OFF)** | `config.h:10-11` | `--enable-cider` | off (`configure.ac:150-151`, `configure.ac:1215-1217`) |
| `NDEV` | **undef (OFF)** | `config.h:468-469` | `--enable-ndev` | off (`configure.ac:281-282`, `configure.ac:1240-1244`) |
| `OSDI` | **defined (ON)** | `config.h:502` | `--disable-osdi` | **on** (`configure.ac:1208-1212`) |
| `XSPICE` | **defined (ON)** | `config.h:579` | `--disable-xspice` | **on** |
| `RFSPICE` (S-param `.sp`) | **defined (ON)** | `config.h:535` | `--disable-sp` | **on** (`configure.ac:1222-1229`) |
| `WITH_PSS` | **undef (OFF)** | `config.h:576` | `--enable-pss` | off (`configure.ac:154-155`) |
| `SENSDEBUG` | undef | `config.h:547` | — | off |
| `WANT_SENSE2` | **never definable** | — | `--enable-sense2` | **broken, see §2.2.1** |
| `KLU` | defined (banner) | — | `--enable-klu`/default | on; but **runtime default is SPARSE**, see §1.8 |

`AM_CONDITIONAL`s: `CIDER_WANTED` and `NUMDEV_WANTED` both keyed to `enable_cider`
(`configure.ac:1233-1234`); `SP_WANTED` (`configure.ac:1229`); `PSS_WANTED`, `SENSE2_WANTED`
(`configure.ac:1235-1236`); `OSDI_WANTED` (`configure.ac:1212`); `NDEV_WANTED` (`configure.ac:1244`).

The analysis registration array itself is build-gated the same way —
`src/spicelib/analysis/analysis.c:35-58`:

```
OPT, AC, DCT, DCO, TRAN, PZ, TF, DISTO, NOISE, SENS,
  [PSS   if WITH_PSS]
  [SEN2  if WANT_SENSE2]
  [SP    if RFSPICE]
  [HB    if RFSPICE && WITH_HB]
```

So in **this** binary the analysis list is exactly: OP, AC, DC (transfer curve), DCOP, TRAN, PZ, TF,
DISTO, NOISE, SENS, SP. No PSS, no SENS2, no HB.

---

# PART 1 — CIDER

## 1.1 What CIDER is

CIDER = the Berkeley mixed-level simulator (SPICE3 + a 1D/2D drift-diffusion numerical device
simulator, originally CIDER 1b1). Enabling it compiles `src/ciderlib/` (four convenience
libraries: `input`, `support`, `oned`, `twod` — `src/Makefile.am:14-16`, `src/Makefile.am:437-443`)
and five numerical *device* types into `DEVices[]`.

`src/ciderlib/` contents:
- `input/` — the model-card sub-language parser (16 card types, §1.5)
- `support/` — globals, material database, mobility/recombination support, device print/logfile
- `oned/` — 1-D device: mesh, Poisson, continuity, AC admittance (`oneadmit.c`), solve, print
- `twod/` — 2-D device: same, plus `twoadmit.c`, `twocurr.c`, `twomobil.c`, `twoncont.c`, …

## 1.2 What device types CIDER adds

Registered only under `#ifdef CIDER` in `src/spicelib/devices/dev.c:130-137` (headers) and
`dev.c:197-203` (the `static_devices[]` entries):

| Device | Instance letter | `.model` type | level | Terminals | Struct |
|---|---|---|---|---|---|
| `NUMD` | `D…` | `numd` | 1 (default) | D+, D− | `src/spicelib/devices/numd/numdinit.c:10` |
| `NUMD2` | `D…` | `numd` | 2 | Anode, Cathode (`numd2/nud2.c:50-53`) | `numd2/numd2init.c:10` |
| `NBJT` | `Q…` | `nbjt` | 1 (default) | C, B, E | `nbjt/nbjtinit.c:10` |
| `NBJT2` | `Q…` | `nbjt` | 2 | Collector, Base, Emitter, Substrate (`nbjt2/nbt2.c:60-65`) | `nbjt2/nbt2init.c:10` |
| `NUMOS` | `M…` | `numos` | (none) | Drain, Gate, Source, Substrate (`numos/numm.c:82-87`) | `numos/numosinit.c:10` |

Model-type→device dispatch: `src/spicelib/parser/inpdomod.c:532-585` (inside `#ifdef CIDER`).
Instance-line acceptance of the numerical model type on a `D`/`Q`/`M` card:
`src/spicelib/parser/inp2d.c:74-77` and `inp2d.c:104-115` (NUMD/NUMD2),
`src/spicelib/parser/inp2q.c:91-94` and `inp2q.c:116-121` (NBJT/NBJT2),
`src/spicelib/parser/inp2m.c:134-135` (NUMOS).

Notable parser quirk: on `NUMD2` and `NBJT2` an **unlabelled trailing number is an error**
(`inp2d.c:104-112`, `inp2q.c:116-121`), whereas on `NUMD`/`NBJT` it is taken as `area`.
So `D1 1 2 M_PN 100` is legal for level 1 and illegal for level 2 — a GUI must always emit
`AREA=<n>` explicitly.

## 1.3 Which analyses a CIDER numerical device supports

This is decided purely by the `SPICEdev` function pointers, exactly like every other device.
All five numerical devices have the identical shape (verified in all five `*init.c`):

| Hook | NUMD/NUMD2/NBJT/NBJT2/NUMOS | Evidence |
|---|---|---|
| `DEVload` | present | `numd/numdinit.c:36` |
| `DEVsetup` / `DEVpzSetup` | present (both = `…setup`) | `numd/numdinit.c:37,39` |
| `DEVtemperature` | present | `numd/numdinit.c:40` |
| `DEVtrunc` | present | `numd/numdinit.c:41` |
| `DEVacLoad` | **present** | `numd/numdinit.c:43` |
| `DEVpzLoad` | **present** | `numd/numdinit.c:51` |
| `DEVdisto` | **NULL** | `numd/numdinit.c:61` |
| `DEVnoise` | **NULL** | `numd/numdinit.c:62` |
| `DEVsoaCheck` | **NULL** | `numd/numdinit.c:63` |
| `DEVconvTest` | NULL | `numd/numdinit.c:52` |
| `DEVsetic` | NULL | `numd/numdinit.c:47` |
| `DEVdump` / `DEVacct` | **present** (unique to these five) | `numd/numdinit.c:66-67`, `nbjt/nbjtinit.c:66-67`, `nbjt2/nbt2init.c:66-67`, `numd2/numd2init.c:66-67`, `numos/numosinit.c:66-67` |

**Therefore, for a deck containing a CIDER device:**

| Analysis | Supported? | Why |
|---|---|---|
| `.op`, `.dc`, `.tran` | YES | `DEVload` + `DEVtrunc` |
| `.ac` | YES (special path, §1.4) | `DEVacLoad` → `NUMDadmittance` etc. |
| `.pz` | YES | `DEVpzLoad` + `DEVpzSetup` |
| `.tf` | YES (DC only) | rides on the OP Jacobian, §2.1.7 |
| `.sens` | technically yes, practically useless | §1.7 |
| `.noise` | **NO** — silently contributes zero | `DEVnoise = NULL` |
| `.disto` | **NO** — silently contributes zero | `DEVdisto = NULL` |
| `.sp` | rides on `.ac` (`DEVacLoad`) — untested | §2.4 |
| SOA (`set warn=1`) | **NO** — device is skipped | `DEVsoaCheck = NULL` |

**CIDER adds no new `.dot` analysis card.** There is no `.cider`, no `.device`, no new
`SPICEanalysis`. It only adds device types and changes *how* the existing analyses evaluate them.

## 1.4 What CIDER *changes* about an existing analysis

### 1.4.1 AC gets a per-model solution technique

The `method` card inside a CIDER `.model` carries `ac.analysis` (`src/ciderlib/input/method.c:26`):

```
IP("ac.analysis", METH_ACANAL, IF_STRING, "AC solution technique")
```

Accepted values (case-insensitive prefix match, minimum 1 char —
`src/ciderlib/input/method.c:92-100`): `direct` → `DIRECT`, `sor` → `SOR`.
Enum values in `src/include/ngspice/numenum.h:31-33`: `SOR=201`, `DIRECT=202`, `SOR_ONLY=203`.

**Default when the card omits it: `SOR`**, set at device setup —
`src/spicelib/devices/numd/numdset.c:91-92`, `nbjt/nbjtset.c:89-90`, `nbjt2/nbt2set.c:92-93`,
`numd2/nud2set.c:92-93`, `numos/nummset.c:92-93`. (The process-global initial value
`AcAnalysisMethod = DIRECT` in `src/main.c:159` / `src/sharedspice.c` is overwritten per model.)

The method can also be **downgraded at runtime**: `NUMDacLoad` writes the value returned by
`NUMDadmittance()` back into the model card, i.e. if SOR fails to converge the model
permanently switches to DIRECT for the rest of the run — `src/spicelib/devices/numd/numdacld.c:49-51`
(and the mirror lines in `nud2acld.c:51`, `nbt2acld.c:50`, `nummacld.c:49`).
The SOR/DIRECT branch is at `src/ciderlib/oned/oneadmit.c:84`.

Other `method`-card parameters (`src/ciderlib/input/method.c:21-30`):
`devtol`/`dabstol`, `dreltol`, `onecarrier`, `ac.analysis`, `frequency` (stored as
`2*pi*value`, `method.c:80-82`), `nomobderiv`, `itlim`, `voltpred`.

### 1.4.2 OP/DC/TRAN gain a per-device internal-state dump

`CKTdump()` calls `DEVdump` for every device that has one — `src/spicelib/analysis/cktdump.c:56-60`
(the whole block is `#ifdef CIDER`). Only the five numerical devices define it.
`NUMDdump` (`src/spicelib/devices/numd/numddump.c:29-56`) writes a **separate file per dump point**,
named `<rootfile><PREFIX>.<n>.<instance>.<ext>` where PREFIX ∈ {`OP`, `DC`, `TR`} keyed off
`CKTmode` (`numddump.c:40-56`). The `examples/cider/cider-gnuplot/` directory contains samples:
`DC.12.qj1.ascii`, `TR.200.q2.ascii`, `TR.300.d1.ascii`.

Which fields go into the dump is chosen by the `output` card (§1.5); the *root name* and the
raw-vs-ascii choice are `output rootfile=…` and `output rawfile` (`src/ciderlib/input/output.c:36-38`).
Dumping is enabled per instance by the `save=<n>` / `print=<n>` instance parameter
(`src/spicelib/devices/numd/numd.c:14-15`) — in transient, `n` means "every n-th accepted timepoint"
(`numddump.c:65-68`). The `examples/cider/bjt/pz.cir` line `Q1 5 4 2 M_NPN AREA=4 SAVE` shows the
bare-flag form.

### 1.4.3 `rusage` gains a "devices" section

`NDEVacct()` (`src/spicelib/analysis/cktdump.c:80-93`) walks `DEVacct` and prints per-device
solver statistics; it is wired into the `rusage` command at `src/frontend/resource.c:376-382`
(`#ifdef CIDER`, `rusage devices`). Also reachable via `.options acct` in the examples.

### 1.4.4 Case retention in the netlist preprocessor

CIDER model cards are the only place where ngspice preserves the case of parameter text.
`is_cider_model()` (`src/frontend/inpcom.c:394-412`) returns true for any `.model` line whose text
contains `numos`, `numd`, or `nbjt` **on the same physical line as the `.model` keyword** (the
comment at `inpcom.c:396-399` says continuation lines are missed). `inp_cider_models()`
(`inpcom.c:801+`) concatenates the continuation lines into one while keeping the originals in
`card->actualLine` so `INPparseNumMod()` (`src/spicelib/parser/inpgmod.c:437+`) can re-walk them
card by card. Case retention is applied at `inpcom.c:2100-2113` and `inpcom.c:2194-2199`.
Practical consequence for a GUI: a filename in `options ic.file=<Path>` keeps its case
(`line_contains_icfile()`, `inpcom.c:2197`), but a CIDER model whose type keyword lands on a
continuation line loses case retention entirely. **Always put `.model <name> numd level=N`
on one line.**

## 1.5 The CIDER model sub-language: the complete card catalogue

`INPparseNumMod()` (`src/spicelib/parser/inpgmod.c:437-...`) re-parses the original `.model`
continuation lines: each `+` line starts a **card**, further `+`s continue the previous card,
`*`/`$`/`#`/empty are comments (`inpgmod.c:475-490`). Card lookup is `INPfindCard(cardName,
INPcardTab, INPnumCards)` (`inpgmod.c:510`); the table is `src/ciderlib/input/cards.c:27-46`
(16 entries, some aliases of the same `IFparm` table). A bare `title` card is also accepted
(`inpgmod.c:520`).

| Card keyword | `IFcardInfo` | Purpose | Parameter keywords |
|---|---|---|---|
| `contact` | `CONTinfo`, `contact.c:28` | contact properties | `neutral`, `aluminum`, `p.polysilicon`, `n.polysilicon`, `workfunction`, `number` |
| `doping` | `DOPinfo`, `doping.c:62` | dopant profiles | `domains`, `uniform`, `linear`, `gaussian`, `gdiff`, `gimp`, `erfc`, `errfc`, `exponential`, `suprem3`, `ascii`, `infile`, `lat.rotate`, `lat.unif`, `lat.linf`, `lat.gauss`, `lat.erfc`, `lat.exp`, `boron`, `phosphorus`, `arsenic`, `antimony`, `p.type`, `acceptor`, `n.type`, `donor`, `x.axis`, `y.axis`, `x.low`, `x.high`, `y.low`, `y.high`, `conc`, `peak.conc`, `location`, `range`, `char.length`, `ratio.lat` |
| `electrode` | `ELCTinfo`, `electrod.c:33` | contact location | `x.low`, `x.high`, `y.low`, `y.high`, `ix.low`, `ix.high`, `iy.low`, `iy.high`, `number` |
| `boundary` | `BDRYinfo`, `boundary.c:43` | domain boundary props | `domain`, `neighbor`, `x.low`, `x.high`, `y.low`, `y.high`, `ix.low`, `ix.high`, `iy.low`, `iy.high`, `nss`, `qss`, `qf`, `sn`, `srvn`, `vsrfn`, `sp`, `srvp`, `vsrfp`, `layer.width` |
| `interface` | `INTFinfo`, `boundary.c:53` | same table as `boundary` | (same) |
| `x.mesh` | `XMSHinfo`, `mesh.c:35` | vertical mesh lines | `location`, `width`, `number`, `node`, `ratio`, `h.start`/`h1`, `h.end`/`h2`, `h.max`/`h3` |
| `y.mesh` | `YMSHinfo`, `mesh.c:46` | horizontal mesh lines | (same table) |
| `method` | `METHinfo`, `method.c:33` | numerics + **AC technique** | `devtol`/`dabstol`, `dreltol`, `onecarrier`, `ac.analysis`, `frequency`, `nomobderiv`, `itlim`, `voltpred` |
| `mobility` | `MOBinfo`, `mobility.c:41` | mobility models | `material`, `electron`, `hole`, `majority`, `minority`, `mumax`, `mumin`, `ntref`, `ntexp`, `vsat`, `vwarm`, `mus`, `ec.a`, `ec.b`, `concmodel`, `fieldmodel`, `init` |
| `models` | `MODLinfo`, `models.c:45` | which physics is on | `bgn`, `bgnw`, `tmpmob`/`tempmob`, `conmob`/`concmob`, `fldmob`/`fieldmob`, `trfmob`/`transmob`, `srfmob`/`surfmob`, `matchmob`, `srh`, `consrh`/`conctau`, `auger`, `avalanche` |
| `physics` | `PHYSinfo`, `material.c:88` | alias of `material` table | (same as `material`) |
| `material` | `MATLinfo`, `material.c:77` | material constants | `number`, `insulator`, `oxide`, `sio2`, `nitride`, `si3n4`, `semiconductor`, `silicon`, `polysilicon`, `gaas`, `nc`/`nc0`/`nc300`, `nv`/`nv0`/`nv300`, `eg`/`eg0`/`eg300`, `deg.dt`/`egalpha`, `eg.tref`/`egbeta`, `deg.dc`/`eg.cref`, `nbgn`, `deg.dn`/`eg.nref`, `nbgnn`, `deg.dp`/`eg.pref`, `nbgnp`, `affinity`, `permittivity`/`epsilon`, `tn`/`tn0`/`taun0`, `tp`/`tp0`/`taup0`, `nsrhn`/`srh.nref`, `nsrhp`/`srh.pref`, `cn`/`cnaug`/`augn`, `cp`/`cpaug`/`augp`, `arichn`, `arichp` |
| `domain` | `DOMNinfo`, `domain.c:35` | region↔material binding | `x.low`, `x.high`, `y.low`, `y.high`, `ix.low`, `ix.high`, `iy.low`, `iy.high`, `number`, `material` |
| `region` | `REGNinfo`, `domain.c:45` | alias of `domain` | (same) |
| `options` | `OPTNinfo`, `optionsc.c:52` | device kind + geometry | `resistor`, `capacitor`, `diode`, `bipolar`/`bjt`, `soibjt`, `moscap`, `mosfet`, `soimos`, `jfet`, `mesfet`, `defa`, `defw`, `defl`, `base.area`, `base.length`, `base.depth`, `tnom`, `ic.file`, `unique` |
| `output` | `OUTPinfo`, `output.c:75` | what to dump / debug | `all.debug`, `op.debug`/`dc.debug`, `tran.debug`, `ac.debug`/`pz.debug`, `geometry`, `mesh`, `material`, `globals`, `statistics`/`resources`, `rootfile`, `rawfile`, `hdf`, `doping`, `psi`, `equ.psi`, `vac.psi`, `n.conc`/`electrons`, `p.conc`/`holes`, `phin`/`qfn`, `phip`/`qfp`, `phic`/`band.con`, `phiv`/`band.val`, `e.field`, `jc`/`j.conduc`, `jd`/`j.disp`, `jn`/`j.electr`, `jp`/`j.hole`, `jt`/`j.total`, `unet`/`recomb`, `mun`/`mob.elec`, `mup`/`mob.hole` |

Note `output ac.debug` / `output pz.debug` are the **same flag** (`OUTP_AC_DEBUG`,
`src/ciderlib/input/output.c:26-27`) — enabling AC debug also enables PZ debug.

Enumerations used by these cards (doping profile shapes, mobility model ids, material ids,
time-integration methods) are in `src/include/ngspice/numenum.h:21-77`.

## 1.6 What a CIDER deck actually looks like

Verbatim from `examples/cider/diode/diode.cir` (a 1-D numerical diode driven by OP + AC):

```
One-Dimensional Diode Simulation

Vpp 1 0 0.7v (PWL 0ns 3.0v 0.01ns -6.0v) (AC 1v)
Vnn 2 0 0v
D1  1 2 M_PN AREA=100

.model M_PN numd level=1
+ options defa=1p
+ x.mesh loc=0.0 n=1
+ x.mesh loc=1.3 n=201
+ domain   num=1 material=1
+ material num=1 silicon
+ mobility mat=1 concmod=ct fieldmod=ct
+ doping gauss p.type conc=1e20 x.l=0.0  x.h=0.0 char.l=0.100
+ doping unif  n.type conc=1e16 x.l=0.0  x.h=1.3
+ doping gauss n.type conc=5e19 x.l=1.3  x.h=1.3 char.l=0.100
+ models bgn aval srh auger conctau concmob fieldmob
+ method ac=direct

.option acct bypass=0 abstol=1e-18 itl2=100
.op
.ac dec 10 100kHz 10gHz
.print ac i(Vpp)
.END
```

Structural facts a GUI must respect:
- The entire device physics lives **inside one `.model` card** as `+`-continued sub-cards. There is
  no separate section, no include-able file format other than `.include`-ing the whole `.model`
  (see `examples/cider/bjt/pebjt.lib` and `examples/cider/bicmos/bicmos.lib`).
- `method ac=direct` uses a 3-character prefix of `ac.analysis`; the parser's keyword matcher is a
  prefix match, so `ac=`, `ac.a=` and `ac.analysis=` are all accepted.
- `.option bypass=0 abstol=1e-18 itl2=100` in the example is *ordinary ngspice* `.options`, not a
  CIDER card. CIDER decks routinely need a much tighter `abstol` — worth surfacing as a hint.
- `examples/cider/bjt/pz.cir` shows a numerical BJT under `.PZ 3 0 5 0 vol pz`, i.e. PZ genuinely
  works with CIDER devices.
- Other example families: `examples/cider/{bicmos,bjt,diode,jfet,mos,resistor,serial,parallel,surfmob,cider-gnuplot}`.

## 1.7 `.sens` over CIDER devices — technically legal, practically a trap

`.sens` perturbs any parameter whose flags are exactly `IF_SET|IF_ASK|IF_REAL` with none of
`IF_VECTOR|IF_REDUNDANT|IF_NONSENSE` (`src/spicelib/analysis/cktsgen.c:198-205`). For `NUMD` that
set is just `area` and `temp` (`src/spicelib/devices/numd/numd.c:13,34`); the model table is a
single dummy entry ("numerical-device models no longer have parameters",
`numd/numd.c:38-42`). But each perturbation step runs a full
`CKTunsetup → CKTsetup → CKTtemp → CKTload` cycle (`src/spicelib/analysis/cktsens.c:380-401`),
which for a numerical device means re-meshing and re-solving the device. A GUI should warn.

## 1.8 CIDER + KLU: AC and NOISE abort the process

`small_signal_check()` (`src/ciderlib/oned/oneadmit.c:35-43`, mirrored at
`src/ciderlib/twod/twoadmit.c:35-44`) does:

```
if (CKTmode == MODEAC || CKTmode == MODEACNOISE) {
    "Error: CIDER %s small signal simulation is not (yet) supported with 'option klu'."
    "    Use 'option sparse' instead."
    controlled_exit(1);
}
```

That is `controlled_exit(1)` — it **kills the process**, it does not just fail the analysis.
Called from `NUMDadmittance` (`oneadmit.c:60-64`), `NUMD2admittance` (`twoadmit.c:62`),
`NBJT2admittance` (`twoadmit.c:217`), `NUMOSadmittance` (`twoadmit.c:446`), `NUMD2ys` (`twoadmit.c:1186`).

Mitigating fact: **the runtime default in this tree is SPARSE, not KLU.** `TSKkluMODE` is
initialised to `CKTkluOFF` (`src/spicelib/analysis/cktntask.c:143`) and only `.options klu`
turns it on (`src/spicelib/analysis/cktsopt.c:181-184`); a plain run prints
`Using SPARSE 1.3 as Direct Linear Solver` (observed). So the hazard only appears if the user
(or the GUI) adds `.options klu`.

There is also a *dead* guard in the device setup routines:
`#if defined(KLU) && defined(NOT_WITH_CIDER)` at `src/spicelib/devices/numd/numdset.c:49-51`,
`nbjt/nbjtset.c:47-49`, `nbjt2/nbt2set.c:50-52`, `numd2/nud2set.c:50-52`. `NOT_WITH_CIDER` is
never defined anywhere, so this earlier, friendlier refusal never fires.

**GUI rule: if the deck contains a CIDER device, never emit `.options klu`.**

## 1.9 What happens if a CIDER deck meets a non-CIDER binary (i.e. this one)

Verified empirically. Deck: `examples/cider/diode/diode.cir` unchanged, run
`ngspice --batch diode.cir`:

```
Circuit: one-dimensional diode simulation

Error on line 11 or its substitute:
  d1 1 2 m_pn area=100
  could not find a valid modelname
    Simulation interrupted due to error!
```

Mechanism: with `CIDER` undefined, `INPdomodel` falls through the `numd` branch to the default
arm. Because `XSPICE`/`OSDI` *are* defined, that arm does `INPtypelook("numd")` → −1 → error
message `"Unknown model type numd - ignored"` and the `.model` card is dropped
(`src/spicelib/parser/inpdomod.c:592-616`). The `.model` error is a *warning-shaped* message; the
hard failure only surfaces later on the instance line. **The user gets no hint that CIDER is the
missing feature.**

## 1.10 Other CIDER-only runtime surface

- **Extra init scripts**, installed only under `CIDER_WANTED` (`src/Makefile.am:176-178`):
  `src/ciderinit` (aliases + terminal defaults, incl. `alias dl devload`, `alias dx devaxis`),
  `src/devload` (an `.control` script that `load`s a dumped device state and sets up x/y scales),
  `src/devaxis`. These exist to plot the `DEVdump` output; they are the closest thing CIDER has
  to a viewer.
- **CIDER globals** live in process-global variables set in `src/main.c:134-166` (mirrored in
  `src/sharedspice.c:269-301`): `ONEacDebug`, `ONEdcDebug` (default `TRUE`), `ONEtranDebug`
  (`TRUE`), `TWO*Debug`, `BandGapNarrowing`, `TempDepMobility`, …, `MaxIterations = 100`
  (`main.c:158`), `AcAnalysisMethod = DIRECT` (`main.c:159`). Because they are globals, a
  `libngspice` host must assume they survive `ngSpice_Reset` — relevant to the shared-build
  discipline in `CLAUDE.md`.
- **`evalAccLimits()`** is called at simulator init only under CIDER (`src/main.c:513-516`).
- **Shutdown behaviour**: `sp_shutdown()` under CIDER calls `com_quit(NULL)` when
  `IsCiderLoaded() > 0` and the env var `CIDER_COM_QUIT` is not `"OFF"`
  (`src/main.c:530-546`; counter in `src/ciderlib/support/globals.c:159-167`, incremented only by
  `src/ciderlib/twod/twomesh.c:463` and decremented in `twodest.c:137` / `onedest.c:107`).
  **A GUI driving a CIDER-enabled ngspice non-interactively should export `CIDER_COM_QUIT=OFF`**
  to avoid an interactive quit confirmation at exit.

## 1.11 Recommendation for ASE-L

**Detect, don't offer blindly.**

1. On first contact with a simulator entry, run `devhelp` once and cache the device list.
   The presence of `NUMD` / `NBJT` / `NUMOS` rows *is* the CIDER build test — it needs no
   `config.h`, no version string, and it works for any ngspice binary the user points at.
   (Confirmed: `devhelp` prints exactly the `DEVices[]` table,
   `src/frontend/device.c:66-75`; the CIDER entries only exist under `#ifdef CIDER`,
   `src/spicelib/devices/dev.c:197-203`.)
2. If CIDER is absent: do not show a CIDER model editor at all, and if the user's netlist
   contains `.model … numd|nbjt|numos`, raise a clear "this ngspice was built without
   `--enable-cider`" message *before* running, because ngspice's own message is useless (§1.9).
3. If CIDER is present: CIDER is a **model-authoring** feature, not an analysis feature.
   The analysis pane needs only three CIDER-specific behaviours:
   - grey out / warn on `.noise`, `.disto`, and SOA;
   - block `.options klu` (§1.8);
   - offer the `output …`-driven device-state dump as a per-run artifact (§1.4.2) and wire
     `devload`/`devaxis` into the viewer.
   Everything else about CIDER belongs in a model editor, not the analysis GUI.
4. CIDER is a compile-time-only feature: there is no runtime `codemodel`/`osdi`-style load command.
   If the user wants it, they must rebuild. Say so explicitly.

---

# PART 2 — Device gating of analyses

## 2.1 The `SPICEdev` contract: which pointer gates which analysis

Struct definition: `src/include/ngspice/devdefs.h:50-129`.

| Pointer | Declared | Called from | Guarded how | Effect when NULL |
|---|---|---|---|---|
| `DEVload` | `devdefs.h:57` | `CKTload` (`src/spicelib/analysis/cktload.c`) | per-device loop | device absent from DC/OP/TRAN matrix |
| `DEVsetup` | `devdefs.h:59` | `CKTsetup` | — | no matrix pointers |
| `DEVunsetup` | `devdefs.h:61` | `CKTunsetup` | — | leaks / stale state on re-setup |
| `DEVpzSetup` | `devdefs.h:63` | `CKTpzSetup`, `src/spicelib/analysis/cktpzset.c:37-42` | `DEVices[i] && DEVices[i]->DEVpzSetup && ckt->CKThead[i]` | **PZ matrix pointers never bound for that device** |
| `DEVtemperature` | `devdefs.h:65` | `CKTtemp` | — | no temp update; also used by `.sens` (`cktsens.c:929-943`) |
| `DEVtrunc` | `devdefs.h:67` | `CKTtrunc` | per-device loop | no LTE contribution → timestep control ignores the device |
| `DEVacLoad` | `devdefs.h:71` | `CKTacLoad`, `src/spicelib/analysis/acan.c:432-437` | `DEVices[i] && ->DEVacLoad && CKThead[i]` | **device is an open circuit in AC, NOISE, SP and AC-mode SENS** |
| `DEVaccept` | `devdefs.h:73` | `CKTaccept` (`src/spicelib/devices/cktaccept.c`) | per-device loop | no per-timepoint bookkeeping |
| `DEVask` / `DEVmodAsk` | `devdefs.h:83,85` | `show`, `showmod`, `.sens` (`cktsens.c:948-...`) | — | parameter unreadable; `.sens` skips it |
| `DEVpzLoad` | `devdefs.h:87` | `CKTpzLoad`, `src/spicelib/analysis/cktpzld.c:29-33` | `DEVices[i] && ->DEVpzLoad != NULL && CKThead[i]` | **device is an open circuit in PZ** |
| `DEVconvTest` | `devdefs.h:89` | `CKTconvTest` | per-device loop | device never vetoes convergence |
| `DEVsenSetup` … `DEVsenTrunc` | `devdefs.h:92-103` | **nowhere** | — | **dead, see §2.2** |
| `DEVdisto` | `devdefs.h:104` | `CKTdisto`, `src/spicelib/analysis/cktdisto.c:36-40` (D_SETUP) and `cktdisto.c:56-61` (D_TWOF1…D_2F1MF2) | `DEVices[i] && ->DEVdisto && CKThead[i]` | **device contributes no distortion — result is silently zero** |
| `DEVnoise` | `devdefs.h:106` | `CKTnoise`, `src/spicelib/analysis/cktnoise.c:39-42`; SP-noise `cktspnoise.c:44-47`; `span.c:89-95` | `DEVices[i] && ->DEVnoise && CKThead[i]` | **device is noiseless — silently zero** |
| `DEVsoaCheck` | `devdefs.h:108` | `CKTsoaInit` (`src/spicelib/devices/cktsoachk.c:26-29`), `CKTsoaCheck` (`cktsoachk.c:43-49`) | `devs[i] && ->DEVsoaCheck && CKThead[i]` | **no SOA warnings for that device** |
| `DEVdump` / `DEVacct` | `devdefs.h:110-116`, `#ifdef CIDER` | `CKTdump` (`cktdump.c:56-60`), `NDEVacct` (`cktdump.c:87-92`) | guarded | no device-internal dump |
| `DEVbindCSC*` | `devdefs.h:120-127`, `#ifdef KLU` | `CKTsetup`, `noisean.c:349-357`, `cktsens.c:409-417` | guarded | device excluded from the KLU CSC matrix |

### 2.1.1 Which analysis consumes which pointer, restated as a lookup table

| Analysis | Hard gate(s) | Also needs |
|---|---|---|
| `.op` / `.dc` / `.tran` | `DEVload` | `DEVtrunc` for correct timestep control (TRAN) |
| `.ac` | `DEVacLoad` | `DEVsetup` |
| `.sp` (RFSPICE) | `DEVacLoad` (via `CKTacLoad`, `src/maths/ni/niaciter.c:35`) | ≥1 `Vsource` with `portnum>0`, §2.4 |
| `.noise` | `DEVacLoad` **and** `DEVnoise` | `.ac`-capable circuit; a noise source somewhere |
| `.sp` noise | `DEVacLoad` **and** `DEVnoise` | `cktspnoise.c:44` |
| `.disto` | `DEVacLoad` **and** `DEVdisto` | ≥1 source with `distof1`/`distof2` |
| `.pz` | `DEVpzSetup` **and** `DEVpzLoad` | hard-rejects transmission lines, §2.6.4 |
| `.tf` | `DEVload` only (DC operating-point Jacobian) | §2.1.7 |
| `.sens` DC | `DEVload` + `DEVparam` + `DEVask` + `DEVtemperature` | parameters flagged `IF_SET\|IF_ASK\|IF_REAL` |
| `.sens` AC | `DEVacLoad` + the same | §2.3 |
| SOA (`set warn=1`) | `DEVsoaCheck` | §2.7 |

### 2.1.7 `.tf` is a DC-only analysis and is effectively ungated

`TFanal` (`src/spicelib/analysis/tfanal.c:44-47`) calls `CKTop`, then solves the *existing DC*
Jacobian with a unit excitation (`tfanal.c:72-88`). It never calls `CKTacLoad`. Its only device
requirement is that the named source resolves to a `Vsource` or an `Isource`
(`tfanal.c:60-70`, error `"Transfer function source %s not of proper type"`). So `.tf` works for
any deck that has an operating point — including MOS6, CPL, URC and code models. Grey it out only
when there is no independent source.

## 2.2 The dead pointers: `DEVsen*`

Exhaustive grep over `src/` for `DEVsenSetup|DEVsenLoad|DEVsenUpdate|DEVsenAcLoad|DEVsenPrint|DEVsenTrunc`
outside `src/spicelib/devices/` and `src/xspice/cmpp/` returns **only the declarations**
(`src/include/ngspice/devdefs.h:92,94,96,98,100,102`). No analysis, no frontend file, no
`src/maths/` file ever reads them.

The `.sens` that ships is `sens_sens()` in `src/spicelib/analysis/cktsens.c:92+`. It:
- enumerates candidate parameters with `sgen_init`/`sgen_next` (`src/spicelib/analysis/cktsgen.c`),
  filtering on `dataType` (`cktsgen.c:198-205`);
- reads the current value with `DEVask` / `DEVmodAsk` (`cktsens.c:947-...`);
- perturbs it with `DEVparam` / `DEVmodParam`;
- re-loads with `DEVacLoad` (AC) or `DEVload` (DC) — `sens_load()`, `cktsens.c:908-926`;
- re-temps with `DEVtemperature` — `sens_temp()`, `cktsens.c:929-943`.

**Consequence for the GUI:** the `senSetup` column in every device's `*init.c` is decorative.
`.sens` availability is governed by (a) `DEVacLoad` in AC mode, and (b) whether any parameter in
the deck passes the `IF_SET|IF_ASK|IF_REAL` filter.

### 2.2.1 `--enable-sense2` is a broken flag

`configure.ac:232-234` declares `--enable-sense2` with the help text "define WANT_SENSE2 for the
code", and `configure.ac:1236` creates `AM_CONDITIONAL([SENSE2_WANTED], …)`. But **`WANT_SENSE2`
is never `AC_DEFINE`d anywhere**, and no `Makefile.am` adds `-DWANT_SENSE2`. Verified by grep over
`configure.ac`, all `*.am`, and all `*.in`. Therefore the SPICE2-style `.sens2` analysis
(`src/spicelib/parser/inp2dot.c:588-621`, `src/spicelib/analysis/analysis.c:31-33,49-51`, plus
`cktsetup.c:296,428`, `dctran.c:86,294,323,443,770`, `cktdest.c:35`) is **unreachable in every
supported configuration**. `.sens2` is not a GUI feature.

## 2.3 There are no per-device "RF/SP hooks"

`SPICEdev` has no S-parameter member. `.sp` (`SPan`, `src/spicelib/analysis/span.c`) works by:
1. asking `NIspPreload()` to build the complex matrix — which is just `CKTacLoad(ckt)`
   (`src/maths/ni/niaciter.c:25-37`), i.e. the ordinary `DEVacLoad` loop;
2. finding the **`Vsource` device family** by `CKTtypelook("Vsource")` and requiring
   `DEVacLoad` on it (`span.c:747-762`), returning `E_NOMOD` if absent;
3. calling three VSRC-specific functions **directly, not through a pointer**:
   `VSRCspinit(...)` (`src/spicelib/devices/vsrc/vsrcacld.c:15`, called at `span.c:255` and
   `span.c:765`) and `VSRCspupdate(...)` (`vsrcacld.c:40`, called at `span.c:790`).
4. RF ports come from instance parameters on `V` sources:
   `portnum`, `z0`, `pwr`, `freq`, `phase` (`src/spicelib/devices/vsrc/vsrc.c:32-36`).
   `CKTportCount` is counted during `VSRCtemp` (`src/spicelib/devices/vsrc/vsrctemp.c:26,99-101`);
   port ids must be dense 1..N (`vsrctemp.c:129-150`).

So: **SP support per device is exactly AC support per device.** If a device is invisible in `.ac`,
it is invisible in `.sp`. SP-noise additionally needs `DEVnoise` (`cktspnoise.c:44`) — OSDI models
participate (`src/osdi/osdinoise.c:27-34,177-182`).

## 2.4 Everything that keys on `DEV_DEFAULT`

`DEVpublic.flags = DEV_DEFAULT` (`src/include/ngspice/devdefs.h:195`) does **not** gate any
analysis. It only selects which families the bare `show` / `alter` commands walk
(`DGEN_DEFDEVS`, `src/frontend/device.c`). Practical effect for a GUI probe: `show` with no
arguments misses `Resistor`, `Capacitor`, `Inductor`, `CplLines`, `URC`, `TransLine`, `mutual`
(all `.flags = 0`). Use `show all :` instead (§2.8).

## 2.5 THE COVERAGE MATRIX

Generated by parsing every `SPICEdev` designated initializer under
`src/spicelib/devices/*/*init.c` (58 structs, 57 files — `ind/indinit.c` defines two).
`Y` = a non-NULL function is assigned; `-` = explicitly `NULL` or the field is absent (which is
identical in effect, because these are static designated initializers and unmentioned fields are
zero). Column `dump` is `DEVdump`, present only under `#ifdef CIDER`.

Columns map to analyses as: `acLoad` → AC / NOISE-gain / SP / AC-SENS; `pzSetup`+`pzLoad` → PZ;
`disto` → DISTO; `noise` → NOISE and SP-NOISE; `soaCheck` → `set warn=1`; `trunc` → TRAN
timestep control; `load` → OP/DC/TRAN/TF/DC-SENS.

| device (`DEVpublic.name`) | file:line of struct | load | acLoad | pzSetup | pzLoad | disto | noise | senSetup† | soaCheck | trunc | accept | convTest | setic | dump |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ASRC | `asrc/asrcinit.c:10` | Y | Y | Y | Y | - | - | - | - | - | - | Y | - | - |
| BJT | `bjt/bjtinit.c:10` | Y | Y | Y | Y | **Y** | Y | Y | Y | Y | - | Y | Y | - |
| BSIM1 | `bsim1/bsim1init.c:10` | Y | Y | Y | Y | **Y** | Y | - | - | Y | - | Y | Y | - |
| BSIM2 | `bsim2/bsim2init.c:10` | Y | Y | Y | Y | - | Y | - | - | Y | - | Y | Y | - |
| BSIM3 | `bsim3/bsim3init.c:10` | Y | Y | Y | Y | - | Y | - | Y | Y | - | Y | Y | - |
| B3SOIDD | `bsim3soi_dd/b3soiddinit.c:8` | Y | Y | Y | Y | - | Y | - | - | Y | - | Y | Y | - |
| B3SOIFD | `bsim3soi_fd/b3soifdinit.c:8` | Y | Y | Y | Y | - | Y | - | - | Y | - | Y | Y | - |
| B3SOIPD | `bsim3soi_pd/b3soipdinit.c:9` | Y | Y | Y | Y | - | Y | - | - | Y | - | Y | Y | - |
| BSIM3v0 | `bsim3v0/bsim3v0init.c:9` | Y | Y | Y | Y | - | Y | - | - | Y | - | Y | Y | - |
| BSIM3v1 | `bsim3v1/bsim3v1init.c:9` | Y | Y | Y | Y | - | Y | - | - | Y | - | Y | Y | - |
| BSIM3v32 | `bsim3v32/bsim3v32init.c:10` | Y | Y | Y | Y | - | Y | - | Y | Y | - | Y | Y | - |
| BSIM4 | `bsim4/bsim4init.c:10` | Y | Y | Y | Y | - | Y | - | Y | Y | - | Y | Y | - |
| BSIM4v5 | `bsim4v5/bsim4v5init.c:10` | Y | Y | Y | Y | - | Y | - | Y | Y | - | Y | Y | - |
| BSIM4v6 | `bsim4v6/bsim4v6init.c:10` | Y | Y | Y | Y | - | Y | - | Y | Y | - | Y | Y | - |
| BSIM4v7 | `bsim4v7/bsim4v7init.c:10` | Y | Y | Y | Y | - | Y | - | Y | Y | - | Y | Y | - |
| B4SOI | `bsimsoi/b4soiinit.c:8` | Y | Y | Y | Y | - | Y | - | Y | Y | - | Y | Y | - |
| Capacitor | `cap/capinit.c:10` | Y | Y | Y | Y | - | - | Y | Y | Y | - | - | Y | - |
| CCCS | `cccs/cccsinit.c:10` | Y | Y | Y | Y | - | - | Y | - | - | - | - | - | - |
| CCVS | `ccvs/ccvsinit.c:10` | Y | Y | Y | Y | - | - | Y | - | - | - | - | - | - |
| **CplLines** | `cpl/cplinit.c:10` | Y | **-** | **-** | **-** | - | - | - | - | - | - | - | - | - |
| CSwitch | `csw/cswinit.c:12` | Y | Y | Y | Y | - | Y | - | - | Y | - | - | - | - |
| Diode | `dio/dioinit.c:11` | Y | Y | Y | Y | **Y** | Y | Y | Y | Y | - | Y | Y | - |
| HFET1 | `hfet1/hfetinit.c:10` | Y | Y | Y | Y | - | **-** | - | - | Y | - | - | Y | - |
| HFET2 | `hfet2/hfet2init.c:10` | Y | Y | Y | Y | - | **-** | - | - | Y | - | - | Y | - |
| hicum2 | `hicum2/hicum2init.c:19` | Y | Y | Y | Y | - | Y | - | Y | Y | - | Y | Y | - |
| HiSIM2 | `hisim2/hsm2init.c:10` | Y | Y | Y | Y | - | Y | - | Y | Y | - | Y | Y | - |
| HiSIMHV1 | `hisimhv1/hsmhvinit.c:10` | Y | Y | Y | Y | - | Y | - | Y | Y | - | Y | Y | - |
| HiSIMHV2 | `hisimhv2/hsmhv2init.c:10` | Y | Y | Y | Y | - | Y | - | Y | Y | - | Y | Y | - |
| Inductor | `ind/indinit.c:10` | Y | Y | Y | Y | - | - | Y | - | Y | - | - | - | - |
| mutual | `ind/indinit.c:78` | -‡ | Y | Y | Y | - | - | Y | - | - | - | - | - | - |
| Isource | `isrc/isrcinit.c:10` | Y | Y | **-** | **-** | - | - | - | - | - | Y | - | - | - |
| JFET | `jfet/jfetinit.c:10` | Y | Y | Y | Y | **Y** | Y | - | - | Y | - | - | Y | - |
| JFET2 | `jfet2/jfet2init.c:10` | Y | Y | Y | **-** | - | Y | - | - | Y | - | - | Y | - |
| LTRA | `ltra/ltrainit.c:10` | Y | Y | Y | **-** | - | - | - | - | Y | Y | - | - | - |
| MES | `mes/mesinit.c:10` | Y | Y | Y | Y | **Y** | Y | - | - | Y | - | - | Y | - |
| MESA | `mesa/mesainit.c:10` | Y | Y | Y | Y | - | **-** | - | - | Y | - | - | Y | - |
| Mos1 | `mos1/mos1init.c:10` | Y | Y | Y | Y | **Y** | Y | Y | **-** | Y | - | Y | Y | - |
| Mos2 | `mos2/mos2init.c:10` | Y | Y | Y | Y | **Y** | Y | Y | **-** | Y | - | Y | Y | - |
| Mos3 | `mos3/mos3init.c:10` | Y | Y | Y | Y | **Y** | Y | Y | **-** | Y | - | Y | Y | - |
| **Mos6** | `mos6/mos6init.c:10` | Y | **-** | **-** | **-** | **-** | **-** | - | - | Y | - | Y | Y | - |
| Mos9 | `mos9/mos9init.c:10` | Y | Y | Y | Y | **Y** | Y | Y | **-** | Y | - | Y | Y | - |
| NBJT (CIDER) | `nbjt/nbjtinit.c:10` | Y | Y | Y | Y | - | **-** | - | **-** | Y | - | - | - | Y |
| NBJT2 (CIDER) | `nbjt2/nbt2init.c:10` | Y | Y | Y | Y | - | **-** | - | **-** | Y | - | - | - | Y |
| NDEV (`--enable-ndev`) | `ndev/ndevinit.c:10` | Y | Y | Y | Y | - | - | - | - | Y | Y | Y | Y | - |
| NUMD (CIDER) | `numd/numdinit.c:10` | Y | Y | Y | Y | - | **-** | - | **-** | Y | - | - | - | Y |
| NUMD2 (CIDER) | `numd2/numd2init.c:10` | Y | Y | Y | Y | - | **-** | - | **-** | Y | - | - | - | Y |
| NUMOS (CIDER) | `numos/numosinit.c:10` | Y | Y | Y | Y | - | **-** | - | **-** | Y | - | - | - | Y |
| Resistor | `res/resinit.c:10` | Y | Y | Y | Y | - | Y | Y | Y | - | - | - | - | - |
| SOI3 | `soi3/soi3init.c:10` | Y | Y | Y | **-** | - | Y | - | - | Y | - | Y | Y | - |
| Switch | `sw/swinit.c:11` | Y | Y | Y | Y | - | Y | - | - | Y | - | - | - | - |
| Tranline | `tra/trainit.c:10` | Y | Y | Y | **-** | - | - | - | - | Y | Y | - | - | - |
| **TransLine (TXL)** | `txl/txlinit.c:15` | Y | Y§ | **-** | **-** | - | - | - | - | - | - | - | - | - |
| **URC** | `urc/urcinit.c:10` | -¶ | **-** | Y | **-** | - | - | - | - | - | - | - | - | - |
| VBIC | `vbic/vbicinit.c:15` | Y | Y | Y | Y | - | Y | - | Y | Y | - | Y | Y | - |
| VCCS | `vccs/vccsinit.c:10` | Y | Y | Y | Y | - | - | Y | - | - | - | - | - | - |
| VCVS | `vcvs/vcvsinit.c:10` | Y | Y | Y | Y | - | - | Y | - | - | - | - | - | - |
| VDMOS | `vdmos/vdmosinit.c:10` | Y | Y | Y | Y | **Y** | Y | - | Y | Y | - | Y | Y | - |
| Vsource | `vsrc/vsrcinit.c:10` | Y | Y | Y | Y | - | - | - | - | - | Y | - | - | - |
| *XSPICE code model (any)* | generated, `src/xspice/cmpp/writ_ifs.c:1082-1120` | `MIFload` | `MIFload` | **-** | **-** | **-** | `MIFnoise` | - | **-** | `MIFtrunc` | - | `MIFconvTest` | - | - |
| *OSDI model (any)* | built at load, `src/osdi/osdiinit.c:188-200` | `OSDIload` | `OSDIacLoad` | `OSDIsetup` | `OSDIpzLoad` | **-** | `OSDInoise`∥ | - | **-** | `OSDItrunc` | - | - | - | - |

† `senSetup` column retained only to show what the *vestigial* pointer holds; it gates nothing (§2.2).
Devices with a non-NULL `DEVsenSetup`: BJT, Capacitor, CCCS, CCVS, Diode, Inductor, mutual,
Mos1, Mos2, Mos3, Mos9, Resistor, VCCS, VCVS.

‡ `mutual` has `DEVload = NULL` (`ind/indinit.c:105`) by design: mutual coupling is loaded from
inside `INDload` (`src/spicelib/devices/ind/indload.c:27-81`), which walks the `MUT` model list.
Not a gap.

§ `TXL` sets `DEVacLoad = TXLload` — the *same* function as `DEVload`
(`txl/txlinit.c:46,48`). `src/spicelib/devices/txl/txlload.c` never references `CKTomega` and
never writes an imaginary matrix entry (grep for `Ptr + 1` returns 0 hits in that file). So TXL
contributes only real conductances in AC. **Flagged as suspicious; see §4 Gaps.**

¶ `URC` has `DEVload = NULL` (`urc/urcinit.c:35`) because `URCsetup` expands the line into
`Resistor`/`Capacitor`/`Diode` instances; the comment in `src/spicelib/devices/dev.c:139`
("URC device MUST precede both resistors and capacitors") exists for exactly this. Not a gap:
the expansion inherits R/C/D's own analysis support. But note the URC's own row is all-NULL,
so a naive matrix consumer would wrongly conclude "URC blocks AC".

∥ `OSDInoise` returns immediately when the compiled model declares no noise sources —
`src/osdi/osdinoise.c:67-69`. See §3.

## 2.6 What actually happens when you ask for an unsupported analysis — verified

### 2.6.1 `.disto` with a device that has no `DEVdisto` → silent zeros

Deck (BSIM4 common-source + `distof1`/`distof2` on the input source), run with
`ngspice --batch`. Result: the analysis runs to completion, prints all five distortion plots
(HD2, HD3, IM 2f1−f2, …) and **every value is `0.000000e+00, 0.000000e+00`**. No warning, no
error, exit status 0.

Root cause: `CKTdisto` only iterates devices with a non-NULL `DEVdisto`
(`src/spicelib/analysis/cktdisto.c:36-40, 56-61`). Only BJT, BSIM1, Diode, JFET, MES,
Mos1/2/3/9 and VDMOS have one — **not a single BSIM3/BSIM4/HiSIM/PSP/OSDI device**.
`.disto` is effectively a legacy-model-only analysis.

### 2.6.2 `.noise` with devices that have no `DEVnoise` → silent zeros

Deck: `vin` → `e1` (VCVS, gain 10) → `c1`. Neither VCVS nor Capacitor has `DEVnoise`.
Result: `inoise_total = 0.000000e+00`, `onoise_total = 0.000000e+00`, no warning.
Root cause: `CKTnoise` loop guard, `src/spicelib/analysis/cktnoise.c:39-42`.

### 2.6.3 `.ac` with a `level=6` MOSFET → the device is an open circuit, silently

Deck: two identical common-source stages, one with `.model n6 nmos level=6`, one with
`.model n1 nmos level=1`, same bias, same 10 k load.

```
v(o6) = 0.000000e+00,0.000000e+00      <-- MOS6, DEVacLoad == NULL
v(o1) = -5.00000e+00,0.000000e+00      <-- MOS1
```

`src/spicelib/devices/mos6/mos6init.c:43` is `.DEVacLoad = NULL`, and there is **no
`mos6acld.c`** in `src/spicelib/devices/mos6/` at all (confirmed by directory listing and by
`mos6/Makefile.am`). MOS6 also has no `DEVpzSetup` (`mos6init.c:39`), no `DEVpzLoad`
(`mos6init.c:51`), no `DEVdisto` (`:59`), no `DEVnoise` (`:60`). **MOS6 is a DC/TRAN-only
device masquerading as a full MOSFET model.** This is the most dangerous single entry in the
matrix, because `level=6` is a plausible thing for a user to type.

### 2.6.4 `.pz` → the only analysis with an explicit device rejection (and it is incomplete)

`PZinit()` (`src/spicelib/analysis/pzan.c:92-106`) hard-rejects a deck containing any instance of
`"transmission line"`, `"Tranline"` or `"LTRA"`:

```
i = CKTtypelook("transmission line");
if (i == -1) { i = CKTtypelook("Tranline"); if (i == -1) i = CKTtypelook("LTRA"); }
if (i != -1 && ckt->CKThead[i] != NULL)
    MERROR(E_XMISSIONLINE, "Transmission lines not supported");
```

Verified: a deck with a `T` element gives `doAnalyses: Transmission lines not supported`.
Note the lookup is a **fallback chain, not a loop** — it stops at the first name that resolves,
so in a build where `"Tranline"` exists (it does) `LTRA` is *never* checked. A deck with only an
`O` (LTRA) element and no `T` element would therefore pass the guard and then silently produce
garbage (LTRA has `DEVpzLoad = NULL`, `ltra/ltrainit.c:51`).

Not covered by the guard at all: `CplLines` (`P`), `TransLine`/TXL (`Y`), `URC` (`U`),
`Isource` (`I`), `JFET2`, `SOI3`, `Mos6`, every XSPICE code model, and `Mos6`.

Verified for TXL: a `.pz` deck containing a `Y` element (TXL has `DEVpzSetup = NULL`,
`txl/txlinit.c:44`) does **not** crash — it fails with the misleading
`doAnalyses: The input signal is shorted on the way to the output`
(`src/spicelib/analysis/cktpzstr.c:213`), because the TXL's matrix pointers were never bound
during `CKTpzSetup` so the network collapses.

### 2.6.5 `.sens` in AC mode with a device that has no `DEVacLoad`

`sens_load()` returns 1 (`src/spicelib/analysis/cktsens.c:917-923`), and the caller does
`continue` (`cktsens.c:547-550`) — but the output vector for that parameter has *already been
named and allocated* (`cktsens.c:222-247`). The parameter therefore appears in the plot with an
all-zero sensitivity. Silent again.

## 2.7 SOA checking — how it is actually turned on

Contrary to what the `.options`-shaped name suggests, SOA is driven by **two control-language
variables read once at netlist-parse time**, `src/frontend/inp.c:1446-1456`:

```
if (cp_getvar("warn", CP_NUM, &warn, 0))  ckt->CKTsoaCheck = warn;   else ckt->CKTsoaCheck = 0;
if (cp_getvar("maxwarns", CP_NUM, &maxwarns, 0)) ckt->CKTsoaMaxWarns = maxwarns; else ckt->CKTsoaMaxWarns = 5;
```

- Defaults: **`warn` off (`CKTsoaCheck = 0`)**, **`maxwarns = 5`** — both set in `inp.c:1449,1455`.
- `warn`/`maxwarns` are **not** `.options` keywords; grep for `"warn"` / `"maxwarns"` in `src/`
  finds only these two `cp_getvar` calls. They must be `set` before the circuit is loaded.
  A GUI that emits `set warn=1` inside the `.control` block *after* `source`/at `run` time is
  **too late** — the value is captured during `inp_spsource()`.
- Runtime call sites: `CKTsoaCheck(ckt)` from `dctran.c:379-380`, `dcop.c:117-118`,
  `dctrcurv.c:427-428`. The mode filter is `MODEDC|MODEDCOP|MODEDCTRANCURVE|MODETRAN|MODETRANOP`
  (`src/spicelib/devices/cktsoachk.c:37`), i.e. **no SOA in AC/NOISE/PZ/SP/DISTO**.
- Empirically verified: `set warn=1`, `set maxwarns=3`, then `source`, then `run` produced exactly
  three `Instance: d1 Model: dmod Time: … Pd=inf W at Vd=0.7316 V has exceeded Pd_max=1e+99 W`
  lines and then stopped.
- Devices with a `DEVsoaCheck`: BJT, BSIM3, BSIM3v32, BSIM4, BSIM4v5/v6/v7, B4SOI, Capacitor,
  Diode, hicum2, HiSIM2, HiSIMHV1/2, Resistor, VBIC, VDMOS. **Everything else is silent**,
  including all MOS1/2/3/6/9, JFET, MES/MESA, HFET, all switches, all sources, all inductors,
  all CIDER devices, all XSPICE code models, and all OSDI models.

## 2.8 How a GUI can compute the matrix cheaply for a given netlist

Two complementary approaches; use both.

### (a) Static: bake the matrix in, key it off element letter + `.model` type + `level`/`version`

The matrix in §2.5 is fixed at build time of ngspice; it does not change per netlist. What varies
is *which families the netlist instantiates*. The mapping from deck syntax to family is entirely
in `src/spicelib/parser/inpdomod.c`:

| `.model` type keyword | `level` | family |
|---|---|---|
| `npn`/`pnp` | 0,1,2 | BJT (`inpdomod.c:47-56`) |
| `npn`/`pnp` | 4, 9 | VBIC (`inpdomod.c:57-64`) |
| `npn`/`pnp` | 8 | hicum2 (`inpdomod.c:65-71`) |
| `d` | — | Diode (`inpdomod.c:82-90`) |
| `njf`/`pjf` | 0,1 | JFET; 2 → JFET2 (`inpdomod.c:93-120`) |
| `nmf`/`pmf`/`nhfet`/`phfet` | 0,1 → MES; 2,3,4 → MESA; 5 → HFET1; 6 → HFET2 (`inpdomod.c:126-179`) |
| `urc` | — | URC (`inpdomod.c:184-192`) |
| `vdmos`/`vdmosn`/`vdmosp` | — | VDMOS (`inpdomod.c:194-204`) |
| `nmos`/`pmos`/`nsoi`/`psoi` | 0,1→Mos1; 2→Mos2; 3→Mos3; 4→BSIM1; 5→BSIM2; **6→Mos6**; 7→MOS7(absent); 8,49→BSIM3vN by `version` (3.0→v0, 3.1→v1, 3.2→v32, 3.3/default→BSIM3); 9→Mos9; 14,54→BSIM4vN by `version` (4.0–4.5→v5, 4.6→v6, 4.7→v7, 4.8/default→BSIM4); 15→BSIM5(absent); 55→B3SOIFD; 56→B3SOIDD; 57→B3SOIPD; 10,58→B4SOI; 60→SOI3; 68→HiSIM2; 73→HiSIMHV1/2 by `version` | (`inpdomod.c:206-376`) |
| `numd` | 1→NUMD, 2→NUMD2 | CIDER (`inpdomod.c:532-553`) |
| `nbjt` | 1→NBJT, 2→NBJT2 | CIDER (`inpdomod.c:554-575`) |
| `numos` | — | NUMOS (`inpdomod.c:576-584`) |
| anything else | — | XSPICE code model / OSDI model, looked up by name (`inpdomod.c:592-616`) |

Model-less elements map directly: `R`→Resistor, `C`→Capacitor, `L`→Inductor, `K`→mutual,
`V`→Vsource, `I`→Isource, `E`→VCVS, `F`→CCCS, `G`→VCCS, `H`→CCVS, `S`→Switch, `W`→CSwitch,
`T`→Tranline, `O`→LTRA, `P`→CplLines, `U`→URC, `Y`→TransLine(TXL), `B`→ASRC, `A`→XSPICE,
`N`→NDEV. (One parser file per letter: `src/spicelib/parser/inp2{a..z}.c`.)

This is enough to compute the matrix from the *pre-expansion* netlist with zero simulator calls.
It is the right thing to do for live UI feedback while the user edits.

### (b) Dynamic: two ngspice commands, no analysis run

Confirmed working against the built binary:

1. **`devhelp`** (no arguments) prints one line per entry of `DEVices[]`:
   `<name> : <description>` (`src/frontend/device.c:66-75`). This tells you *which families this
   binary has at all* — CIDER present/absent, NDEV present/absent, which XSPICE `.cm` sets got
   loaded by `spinit`, and which `.osdi` models are registered. Run it **once per simulator entry**
   and cache it.
2. **`show all :`** after `source`-ing the deck but **before running any analysis** prints one
   section header per device family actually present:

   ```
   ngspice N -> show all :
    Mos6: Level 6 MOSfet model with Meyer capacitance model
    Resistor: Simple linear resistor
    Tranline: Lossless transmission line
    Vsource: Independent voltage source
   ```

   The literal `all :` matters: bare `show` only walks families flagged `DEV_DEFAULT`
   (§2.4) and misses R/L/C/T/P/U/Y/K. The `:` terminates the device group with an empty
   parameter list so nothing but the headers is printed.
   `showmod` is the model-only equivalent (`Mos6 models (…)`) and also works without a run.

   The family names printed are exactly `DEVpublic.name`, i.e. the first column of §2.5 —
   so the join is a plain string lookup. This handles subcircuits, `.include`d PDK models, OSDI
   models and code models correctly, which (a) cannot.

**Recommended GUI algorithm**

```
families = show_all_colon(deck)            # runtime truth, after `source`
binary   = devhelp_cache(simulator)        # what this build even has

for each analysis A in {ac, tran, dc, op, noise, disto, pz, tf, sens, sp}:
    required = HOOKS[A]                    # from §2.1.1
    missing  = [f for f in families if any(h not in MATRIX[f] for h in required)]
    if all families miss a *contributing* hook (disto/noise):  state = "useless — will return zeros"
    elif some families miss a *matrix* hook (acLoad/pzLoad):   state = "partial — these devices vanish"
    else:                                                     state = "ok"
```

Two refinements worth the effort:
- Distinguish "the analysis produces nothing at all" (no device in the deck has `DEVdisto`;
  `.disto` will be all zeros — this is a **hard warn**) from "one device out of twenty is
  missing `DEVnoise`" (normal: an ideal `E` source is genuinely noiseless — this is **fine**).
  The rule: `DEVnoise`/`DEVdisto` are *additive contributions*; `DEVacLoad`/`DEVpzLoad`/`DEVload`
  are *matrix stamps*. A missing contribution is usually correct; a missing stamp is always wrong.
- Special-case the four devices where a missing stamp is a genuine trap and there is no
  workaround: **Mos6** (`.ac`, `.pz`, `.noise`, `.disto`), **CplLines** (`.ac`, `.pz`),
  **TXL** (`.pz`, and see the §4 caveat about AC), **LTRA/Tranline** (`.pz`, already a hard error).
  These deserve a modal-strength warning, not a grey-out.

---

# PART 3 — OSDI / Verilog-A devices

## 3.1 Build gate

`OSDI` is **defined** in this tree (`build-ver_50/src/include/ngspice/config.h:502`), and is
**on by default upstream** — the flag is `--disable-osdi` (`configure.ac:145-147`,
`configure.ac:1208-1212`, `AM_CONDITIONAL([OSDI_WANTED], [test "x$enable_osdi" != xno])`).

Models are loaded at runtime with the `osdi` command (registered at
`src/frontend/commands.c:289-292`). `src/spinit.in:36-46` conditionally loads a stock set
(`asmhemt`, `bjt504t`, `BSIMBULK107`, `BSIMCMG`, `HICUMl0-2.0`, `psp103`, `psp103_nqs`,
`r2_cmc`, `vbic_4T_et_cf`, …) — but only when `osdi_enabled` is set, and `spinit.in:20`
does `unset osdi_enabled` by default. So **out of the box no `.osdi` model is auto-loaded**;
the deck or the GUI must issue `osdi <file>.osdi` (ASE-L already has a `pre_osdi <file>.osdi`
hook, per `xschem-claude/src/ase.tcl:36`).

## 3.2 Which analyses an OSDI model supports

`osdi_create_spicedev()` allocates the `SPICEdev` with `TMALLOC` and assigns exactly thirteen
pointers — `src/osdi/osdiinit.c:157,188-200`:

```
DEVparam, DEVmodParam, DEVask, DEVmodAsk,
DEVsetup, DEVpzSetup (= OSDIsetup), DEVtemperature, DEVunsetup,
DEVload, DEVacLoad, DEVpzLoad, DEVtrunc, DEVnoise
[+ DEVbindCSC / DEVbindCSCComplex / DEVbindCSCComplexToReal under KLU, osdiinit.c:203-205]
```

Everything else is **NULL by construction**: `TMALLOC` → `tmalloc()` →
`calloc(num, 1)` (`src/include/ngspice/memory.h:6`, `src/misc/alloc.c:52-70` —
"New implementation of tmalloc, it uses calloc and does not call memset()"). So the absence is
guaranteed, not accidental.

| Analysis | OSDI support | Evidence |
|---|---|---|
| `.op`, `.dc`, `.tran` | **YES** | `DEVload = OSDIload` (`osdiinit.c:196`), `DEVtrunc = OSDItrunc` (`:199`) |
| `.ac` | **YES** | `DEVacLoad = OSDIacLoad` (`osdiinit.c:197`). Implementation: reuse the OP-point Jacobian — `descr->load_jacobian_resist(inst, model)` + `descr->load_jacobian_react(inst, model, ckt->CKTomega)` (`src/osdi/osdiacld.c:24-33`) |
| `.pz` | **YES** | `DEVpzSetup = OSDIsetup` (`:193`), `DEVpzLoad = OSDIpzLoad` (`:198`). Implementation stamps `J_resist + J_react·s` via `load_jacobian_tran(inst,model,s->real)` + `load_jacobian_react(inst,model,s->imag)` (`src/osdi/osdipzld.c:24-48`) |
| `.tf` | **YES** (DC path only) | rides on `DEVload` |
| `.noise` | **CONDITIONAL** | `DEVnoise = OSDInoise` (`:200`), but `OSDInoise` returns `OK` immediately if `descr->num_noise_src == 0` (`src/osdi/osdinoise.c:67-69`) |
| `.sp` (S-params) | **YES** | rides on `DEVacLoad` via `CKTacLoad` |
| `.sp` noise | **YES** | `src/osdi/osdinoise.c:27-34` (`RFSPICE` block), `:120-182` |
| `.disto` | **NO** | `DEVdisto` never assigned |
| `.sens` | **YES, and dangerously broad** | §3.4 |
| SOA (`set warn=1`) | **NO** | `DEVsoaCheck` never assigned |
| CIDER `DEVdump`/`DEVacct` | NO | never assigned |
| `DEVconvTest`, `DEVaccept`, `DEVsetic`, `DEVfindBranch`, `DEVdelete`, `DEVmodDelete`, `DEVdestroy` | NO | never assigned |

Notable consequences beyond analysis:
- **No `DEVconvTest`** → an OSDI device can never veto Newton convergence on its own internal
  quantities; convergence is judged only on node voltages/currents by the generic `NIconvTest`.
- **No `DEVsetic`** → `.ic` / UIC initial conditions on an OSDI device's internal nodes are ignored.
- **No `DEVaccept`** → no per-timepoint hooks (no hysteresis/latching state).

## 3.3 What happens if a user asks for an analysis OSDI does not support

**Nothing visible.** In all cases the failure is silent and the numbers are wrong-but-plausible:

- **`.disto`**: `CKTdisto`'s guard (`src/spicelib/analysis/cktdisto.c:36-40`) skips the device
  entirely. Since *no* modern compact model has `DEVdisto` either, a deck of OSDI transistors
  gives exactly the all-zeros result reproduced in §2.6.1. No error, exit 0.
- **`.noise` on a Verilog-A model with no `white_noise()`/`flicker_noise()` contributions**:
  `descr->num_noise_src == 0` → `OSDInoise` returns `OK` without touching `OnDens`
  (`osdinoise.c:67-69`). The device is treated as perfectly noiseless. If *every* device in the
  deck is like that, `onoise_total` and `inoise_total` are 0 (as reproduced in §2.6.2), which is
  easy to mistake for "very low noise".
  There is no way to ask ngspice "does this OSDI model have noise sources?" other than running a
  `.noise` and looking for `onoise_<instance>_<sourcename>` vectors — the per-source vector names
  come from `descr->noise_sources[i].name` (`osdinoise.c:92-96`, `:104-109`).
- **SOA (`set warn=1`)**: `CKTsoaCheck` skips the device (`cktsoachk.c:43-49`). The user gets a
  clean run with no warnings and may conclude the design is inside SOA when it is not.
- **A model whose `.osdi` ABI version does not match**: this *is* reported, loudly, at load time —
  `src/osdi/osdiregistry.c:384-407` checks `OSDI_VERSION_MAJOR`/`OSDI_VERSION_MINOR` against
  `OSDI_VERSION_{MAJOR,MINOR}_CURR` and refuses. This is the one OSDI failure mode with a real
  error message, and it happens at `osdi <file>` time, not at analysis time.

## 3.4 `.sens` over OSDI models is a foot-gun

`write_param_info()` (`src/osdi/osdiinit.c:34-91`) builds each `IFparm` with
`dataType = IF_ASK | (IF_SET unless opvar) | IF_REAL|IF_INTEGER|IF_STRING`
(`osdiinit.c:41-59`), plus `IF_VECTOR` for arrays (`:62-64`) and `IF_UNINTERESTING` for aliases
(`:66-69`). It **never sets `IF_NONSENSE`**. The `.sens` candidate filter requires exactly
`IF_SET|IF_ASK|IF_REAL` and nothing from `{IF_VECTOR, IF_REDUNDANT, IF_NONSENSE}`
(`src/spicelib/analysis/cktsgen.c:198-205`) — which every scalar real Verilog-A parameter
satisfies.

So `.sens` on a deck of, say, PSP103 devices will try to perturb **every real model parameter and
every real instance parameter of every instance**, each perturbation costing a full
`CKTunsetup → CKTsetup → CKTtemp → CKTload [→ NIacIter]` cycle (`cktsens.c:380-421`).
For a modern compact model that is several hundred parameters per device.

**Mitigation the GUI must expose:** `.sens` takes a filter glob list between the output
expression and the `ac`/`dc` keyword —
`.sens <output> [<filter> …] [ac <dec|lin|oct> <n> <fstart> <fstop> | dc]`
(`src/spicelib/parser/inp2dot.c:487-489`, filter scanning at `inp2dot.c:528-565`, glob matcher
`scan()` at `src/spicelib/analysis/cktsens.c:37-55` supporting `*` and `?`).
Vector names are built as `<instance>:<modelparam>` for model parameters,
`<instance>` alone for the principal instance parameter, and `<instance>_<param>` otherwise
(`cktsens.c:224-238`). **ASE-L should make the filter a first-class, required-ish field for
`.sens`, not an obscure extra.**

## 3.5 The XSPICE code-model row, for completeness

`cmpp` emits a fixed `SPICEdev` for every code model
(`src/xspice/cmpp/writ_ifs.c:1082-1120`):
`DEVload = MIFload`, `DEVacLoad = MIFload` (the *same* function; MIF switches on
`g_mif_info.circuit.anal_type`), `DEVpzSetup = NULL`, `DEVpzLoad = NULL`, `DEVdisto = NULL`,
`DEVnoise = MIFnoise`, `DEVsoaCheck = NULL`, all `DEVsen*` NULL, `DEVtrunc = MIFtrunc`,
`DEVconvTest = MIFconvTest`.

So: code models work in OP/DC/TRAN/AC/NOISE/SP, are **invisible in `.pz`** (and, because
`DEVpzSetup` is NULL too, their matrix pointers are never bound in PZ — the same failure shape as
TXL in §2.6.4), contribute nothing to `.disto`, and never SOA-check.

`MIFnoise` (`src/xspice/mif/mifnoise.c:462+`) is a recent addition: it supports both
*declarative* noise sources (model parameters discovered by `find_noise_params`) and
*programmatic* sources produced by calling the model's own `cm_func` in a registering pass
(`mifnoise.c:496-530`), gated per instance by `model->analog` / `here->analog`
(`mifnoise.c:481-486`) and by the model's `noise_programmatic` parameter. `noisean.c:337-343`
sets `anal_type = MIF_AC` so `MIFload` produces AC stamps during the noise sweep.
Digital/event-driven instances are excluded (`!model->analog`).

---

# 4. Source vs. documentation, and gaps

## 4.1 Where I trust source over documentation

- The ngspice manual (https://ngspice.sourceforge.io/docs.html, chapters on CIDER and on
  `.disto`/`.noise`/`.pz`) documents these analyses generically and does **not** publish a
  device-support matrix. Nothing in the manual warns that `.disto` returns zeros for BSIM3/BSIM4,
  or that `level=6` MOSFETs vanish in AC. **Trust the source; the manual is silent, not wrong.**
- The manual describes SOA control as `.option warn=1`-adjacent. The source shows it is
  `set warn=1` / `set maxwarns=N`, read via `cp_getvar` at `src/frontend/inp.c:1447,1452`, with
  no `.options` keyword anywhere. **Trust the source** — and note the ordering constraint (§2.7).
- `configure.ac:232-234`'s help text claims `--enable-sense2` "define[s] WANT_SENSE2 for the code".
  It does not (§2.2.1). **The help text is wrong.**
- `src/spicelib/devices/{numd,nbjt,nbjt2,numd2}/…set.c` contain a KLU refusal guarded by
  `NOT_WITH_CIDER`, a symbol that is never defined. The *effective* CIDER+KLU behaviour is the
  `controlled_exit(1)` in `oneadmit.c:35-43` / `twoadmit.c:35-44`. **The dead guard is misleading;
  trust the live one.**

## 4.2 Gaps — things I could not determine, or that need another agent / a maintainer

1. **TXL in AC.** `txl/txlinit.c:48` sets `DEVacLoad = TXLload`, and `txlload.c` never touches
   `CKTomega` and never writes an imaginary matrix entry. That reads as "TXL is purely resistive
   in AC", which would be a real bug, but I did not construct a deck to prove it numerically and
   I did not read all 683 lines of `txlload.c`. Needs a targeted check before it goes in the GUI
   as a hard warning.
2. **CPL (`P` element) in AC.** `cpl/cplinit.c:43` is `.DEVacLoad = NULL` with no
   `cplacld.c` in the directory, which implies coupled lines are simply absent from any AC
   result. Not verified numerically.
3. **`DEVfindBranch`.** Only a handful of devices define it and I did not trace which analyses
   depend on it (it is used to resolve `I(Vxx)`-style branch references). It may gate whether a
   device can be named as a `.noise` input source or a `.tf` source. Worth a follow-up.
4. **Whether `.sp` has additional per-device requirements beyond `DEVacLoad`.** `span.c` is
   ~900 lines and I read only the port/preload path. Another agent owns `.sp`; cross-check the
   `DOING_SP` flag handling (`ckt->CKTcurrentAnalysis & DOING_SP`, e.g. `osdinoise.c:178`) with them.
5. **XSPICE event-driven (digital) devices under AC/PZ/NOISE.** `MIFnoise` skips `!analog`
   instances, but I did not determine what an event node does to an AC matrix, nor whether a
   mixed analog/event deck can run `.ac` at all. That belongs to the XSPICE dossier.
6. **PSS.** `WITH_PSS` is off here (`config.h:576`), so `.pss` device requirements are untested;
   `src/spicelib/analysis/dcpss.c` exists but never links in this build.
7. **NDEV** (`--enable-ndev`, off): its `SPICEdev` is fully populated (see matrix) but it is an
   external-simulator socket interface; I did not investigate what it actually connects to.
8. **`.disto`'s own source requirements.** `CKTdisto`'s `D_RHSF1`/`D_RHSF2` arms look up
   `Vsource`/`Isource` by type (`cktdisto.c:88-92`) and need `distof1`/`distof2` on at least one;
   I did not enumerate the exact failure mode when none is present. The DISTO dossier should cover it.
9. **Verifying the matrix against a CIDER build.** I could not compile a `--enable-cider` tree
   (read-only mandate), so the five CIDER rows are from source only, never executed.
10. **`show all :` stability.** I verified the command works and prints family headers on this
    build, but it is a frontend convenience command with no test coverage that I found in
    `tests/`. A GUI depending on its output format should parse defensively (match
    `^\s+(\S+):\s` and ignore everything else) and fall back to static analysis (§2.8a) if the
    parse yields nothing.
