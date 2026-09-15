# APPENDIX — what ngspice can actually do, at the parameter level

**Companion to `PLAN.md`.** The plan is about *how the GUI exposes it*; this file is *what
"it" is*. Every plan item cites a section here instead of restating it. Nothing in this file
is a proposal — it is an inventory of a binary and a source tree.

| | |
|---|---|
| ngspice tree | `/home/analog/dev/ngspice`, branch `ver_50`, `git describe` = **`ngspice-46-419-gccebdf2a2`** |
| binary for every measurement below | `/home/analog/dev/ngspice/build-ver_50/src/ngspice` (a bare `../configure`) |
| second binary, used for cross-checks | `/usr/bin/ngspice` — **ngspice-45.2**, the distro build, **configured differently** (§1.5) |
| evidence base | `evidence/` — `design-of-record.md` is the spine, `00-critique.md` adjudicated the inter-dossier contradictions, `builds.md` is the only dossier that built and ran PSS, CIDER and libngspice |
| written | 2026-09-09 |

**Citation convention.** ngspice anchors are `file:line` against the tree named above, which is
clean at `ccebdf2a2` and therefore stable. **xschem-claude anchors are proc names**, never line
numbers — that tree is dirty and moving, and a prior batch already ruled on this
("Line ranges replaced by section names — a section survives an edit, a line range does not",
`ase_l_ux_batch/LEDGER.md`, item 1 findings table).
`[R-M<n>]` = measured by the design-of-record's author. **`[A-M<n>]` = measured by me, this
pass, against the binaries above**; the numbers are quoted, not paraphrased, and **the deck is
quoted in full beside the marker** so a challenged measurement is re-typed and re-run. `[crit §x]` = adjudicated by `evidence/00-critique.md`.

**Where a dossier was wrong, the correction is in place and says so.** Nine such corrections are
marked ⚠ **CORRECTION**. They are not deleted, because the wrong number is usually already
quoted somewhere else in the tree.

---

## 0. The one-screen version

ngspice-46 in this build offers **ten runnable analyses plus one pseudo-analysis** — eleven
runnable across builds. **Nine** are unconditional in every ngspice that has ever shipped
(`ac dc op tran pz tf disto noise sens`); **SP** is present because RFSPICE is on by
default here, **PSS** is absent because `--enable-pss` was not given — and `/usr/bin/ngspice` on
this same machine **has** PSS, so the capability gate is not hypothetical [A-M7]. Two more,
`SEN2` and `HB`, are `extern`-declared and **defined nowhere in the tree**; they will never run.

The option surface is **two provably disjoint catalogues**: `OPTtbl`'s **98** `.options`
keywords (§3.1 — not "~86"; see the correction there) and **163** front-end variables reached
only through `cp_getvar` (§3.2), of which **26 must arrive before the netlist is read** and are
silently ignored from `.options` and from `.control`.

Everything sweep-shaped above two `.dc` nest levels — parameter sweeps, corners, Monte Carlo,
non-uniform temperature — **does not exist in ngspice** and has to be generated (§4).

And the surface is not safe: this pass counts **two SIGSEGVs, one infinite hang, one SIGABRT,
one process-killing `controlled_exit`, and eleven silent wrong answers**, all reproducible, all
in §7.

**A stopped run is not a lost run.** Batch mode installs no signal handler, so any signal kills the
process where it stands and nothing reaches disk — but a `.control` block can checkpoint itself with
`stop after` / `write` / `resume`, and the result survives a `kill -9` byte-exactly. §6.8 is the
mechanism, its cost, and the four ways of writing it that fail at **rc 0**.

---

## 1. What this build is, and what a different build would change

### 1.1 The registry — `analInfo[]` has twelve entries here

`src/spicelib/analysis/analysis.c:36-59`, read verbatim this pass:

```c
SPICEanalysis *analInfo[] = {
    &OPTinfo, &ACinfo, &DCTinfo, &DCOinfo, &TRANinfo,
    &PZinfo,  &TFinfo,  &DISTOinfo, &NOISEinfo, &SENSinfo,
#ifdef WITH_PSS
    &PSSinfo,
#endif
#ifdef WANT_SENSE2
    &SEN2info,
#endif
#ifdef RFSPICE
    & SPinfo,
#ifdef WITH_HB
    & HBinfo,
#endif
#endif
};
```

The **array index is the `JOBtype`** stamped into every job (`cktnewan.c:19-37`, line 27).
With this build's flags:

| idx | symbol | registry `name` | registry `description` | gate | present here |
|---|---|---|---|---|---|
| 0 | `OPTinfo` | `options` | `Task option selection` | — | yes — **not runnable**, §2.1 |
| 1 | `ACinfo` | `AC` | `A.C. Small signal analysis` | — | yes |
| 2 | `DCTinfo` | `DC` | `D.C. Transfer curve analysis` | — | yes |
| 3 | `DCOinfo` | `OP` | `D.C. Operating point analysis` | — | yes |
| 4 | `TRANinfo` | `TRAN` | `Transient analysis` | — | yes |
| 5 | `PZinfo` | `PZ` | `pole-zero analysis` | — | yes |
| 6 | `TFinfo` | `TF` | `transfer function analysis` | — | yes |
| 7 | `DISTOinfo` | `DISTO` | `Small signal distortion analysis` | — | yes |
| 8 | `NOISEinfo` | `NOISE` | `Noise analysis` | — | yes |
| 9 | `SENSinfo` | `SENS` | `Sensitivity analysis` | — | yes |
| — | `PSSinfo` | `PSS` | `Periodic Steady State analysis` | `WITH_PSS` | **no** (`--enable-pss`) |
| — | `SEN2info` | — | — | `WANT_SENSE2` | **never** — §1.4 |
| **10** | `SPinfo` | `SP` | `S-Parameters analysis` | `RFSPICE` | **yes** (`--disable-sp` removes it) |
| — | `HBinfo` | — | — | `WITH_HB` | **never** — §1.4 |

`SPICEanalysis` descriptor fields (`analysis.h:4-13`): `if_analysis` (name, description,
`numParms`, `analysisParms`), `size` (bytes of the JOB struct), `domain`
(`NODOMAIN=0 TIMEDOMAIN=1 FREQUENCYDOMAIN=2 SWEEPDOMAIN=3`, `jobdefs.h:140-145` — used **only**
to format failure messages in `CKTtrouble()`, `ckttroub.c:43-84`), `do_ic` (run `CKTic()`
first — 1 for OP and TRAN), and the four function pointers `setParm` / `askQuest` / `an_init` /
`an_func`.

### 1.2 ⚠ The indices at or above 10 MOVE. Never hard-code one.

`WITH_PSS` and `WANT_SENSE2` insert **before** `SPinfo`, so `SP` is index 10 here, 11 with PSS,
12 with both. `OP == 3`, `DC == 2` and `TRAN == 4` precede every `#ifdef` and are safe — and the
tree itself relies on that, with three independent hard-codings that would break otherwise:

* `outitf.c:683-684` — `run->circuit->CKTcurJob->JOBtype == 4`, with the comment
  `/* JOBtype == 4 means Transient Analysis. FIX ME */`;
* `cktop.c:34` — `ckt->CKTcurJob->JOBtype != 2`, `/* If this is called from dc simulation … */`;
* `dctran.c:983` — `JOBtype != 4`.

A GUI has no reason to touch a `JOBtype` at all; the rule is recorded because two dossiers
tabulated indices and a reader may copy one.

### 1.3 Build gates in this tree

Read from `build-ver_50/src/include/ngspice/config.h` this pass:

| macro | state here | configure flag | upstream default | what turning it the other way costs the GUI |
|---|---|---|---|---|
| `XSPICE` | **defined** | `--disable-xspice` | on | the 9 XSPICE `.options` keywords (§3.1), the whole event layer (§6.6), `trtol`-forced-to-1 |
| `OSDI` | defined | `--disable-osdi` | on | Verilog-A devices; and `devhelp` against a scratch deck cannot see them (§1.6) |
| `KLU` | **defined** | `--disable-klu` | on | `sparse` / `klu` / `klu_memgrow_factor` keywords. **Runtime default is still SPARSE 1.3** — the banner says `Using SPARSE 1.3 as Direct Linear Solver` |
| `RFSPICE` | **defined** | `--disable-sp` | on | `sp`, and the five `portnum`/`z0`/`pwr`/`freq`/`phase` VSRC parameters vanish with it |
| `CIDER` | undefined | `--enable-cider` | off | five numerical device families; no new analysis (§1.7) |
| `WITH_PSS` | undefined | `--enable-pss` | off | the twelfth analysis (§2.12) |
| `WANT_SENSE2` | undefined | `--enable-sense2` | off | nothing — the code does not exist (§1.4) |
| `PREDICTOR` | undefined | none in `configure.ac` | off | `.options newtrunc` is inert and says so |
| `SHARED_MODULE` | undefined | `--with-ngshared` | off | `libngspice`; **and this build then produces no `ngspice` binary at all** |
| `HAS_WINGUI` / `TCL_MODULE` / `HAS_PROGREP` | undefined | — | off | the `SetAnalyse()` progress callbacks compile out; §6.5 is the replacement |
| `NGDEBUG` | undefined | `--enable-debug` | off | — |

### 1.4 `SEN2` and `HB` do not exist

Verified this pass by whole-tree grep:

```
src/spicelib/analysis/analysis.c:23:extern SPICEanalysis HBinfo;
src/spicelib/analysis/analysis.c:33:extern SPICEanalysis SEN2info;
src/spicelib/analysis/analysis.c:51:    &SEN2info,
src/spicelib/analysis/analysis.c:56:    & HBinfo,
```

Four hits total: two `extern` declarations and two uses inside `#ifdef` blocks. **No definition
anywhere in `src/`.** `--enable-sense2` therefore produces a link error, not a feature; there is
no configure flag for `WITH_HB` at all (`an-rf-pss.md` §1.4). The `.sens2` and `.hb` dot cards
parse (`inp2dot.c:608`, `:774`) and then have nothing to dispatch to. Do not offer either, ever,
and do not write a "when a build has it" branch.

### 1.5 The probes that work — with their literal output

All three run inside one ordinary `-b` deck's `.control` block. There is **no** version string,
no `--capabilities` flag, and only two capability variables are set at startup
(`$xspice_enabled`, `$osdi_enabled`, `main.c:940-948`) — and §3.4 records why the second lies.

**Probe 1 — `help <verb>`, one line per analysis verb.** This is the reliable one: its loop
terminates on `co_comname == NULL` (`com_help.c:84`), so it reaches the whole command table.
Measured this pass on the dev build [A-M1]:

```
help op        -> op [.op line args] : Determine the operating point of the circuit.
help dc        -> dc [.dc line args] : Do a dc analysis.
help ac        -> ac [.ac line args] : Do an ac analysis.
help tran      -> tran [.tran line args] : Do a transient analysis.
help pz        -> pz [.pz line args] : Do a pole / zero analysis.
help tf        -> tf [.tran line args] : Do a transient analysis.      <- upstream copy-paste bug
help disto     -> disto [.disto line args] : Do an distortion analysis.
help noise     -> noise [.noise line args] : Do a noise analysis.
help sens      -> sens [.sens line args] : Do a sensitivity analysis.
help sp        -> sp [.sp line args] : Do an S-parameter analysis.
help pss       -> Sorry, no help for pss.
help hb        -> Sorry, no help for hb.
help optran    -> optran : Prepare optran by setting 6 flags
help meas      -> meas various ... : User defined signal evaluation.
help fourier   -> fourier fund_freq vector ... : Do a fourier analysis of some data.
help linearize -> linearize  [ vec ... ] : Convert plot into one with linear scale.
```

Two details a parser must encode, both new this pass:

* **`help tf` prints the transient help.** The verdict rule is therefore *"keep the stanza only
  when its **first token** equals the verb probed"* — which survives this bug, because the line
  still begins `tf `. Matching on the sentence does not.
* ⚠ **Each stanza in this build is followed by a four-line manual-URL footer**
  (`For further details please see the latest official ngspice manual in PDF format at` /
  `https://ngspice.sourceforge.io/docs/ngspice-manual.pdf` / `or in HTML format at` /
  `https://ngspice.sourceforge.io/docs/ngspice-html-manual/manual.xhtml`). `[R-M16]` did not
  record it. A reader that assumes one line per verb will mis-associate every stanza after the
  first. Split on the `== <verb>` echo the probe itself writes, not on line count.

**Probe 2 — `devhelp`.** Two forms, both measured this pass [A-M3]:

```
devhelp                 -> 134 lines, "Devices available in the simulator" then "<FAMILY> : <desc>"
devhelp | grep -cE '^(NUMD|NBJT|NUMOS|NDEV)'   -> 0        <- the CIDER probe; 5 rows when CIDER is in
devhelp vsource         -> the full VSRC parameter table, one row per IFparm
```

and inside `devhelp vsource`, this build shows:

```
   25	 portnum   	 inout	 Port index          <- these five are inside #ifdef RFSPICE
   26	 z0        	 inout	 Port impedance
   27	 freq      	 inout	 Port frequency
   28	 pwr       	 inout	 Port Power
   29	 phase     	 inout	 Phase of the source
   30	 trnoise   	 inout	 Transient noise description
   31	 trrandom  	 inout	 random source description
```

So `devhelp vsource | grep portnum` is a **second, independent** RFSPICE probe (their absence
proves `--disable-sp`), and the same dump proves `trnoise`/`trrandom` are settable **and**
askable on this build (§5).

`devhelp -csv -type -flags <device>` adds the four columns the `.sens` eligibility rule needs
(`device.c:305-345`); see §2.10.

**Probe 3 — `devhelp` is also the OSDI/XSPICE evidence.** It is a *stronger* XSPICE signal than
the `codemodel` command: the command proves XSPICE was compiled, the model rows prove `spinit`
actually loaded the `.cm` files. ⚠ Do **not** test CIDER by row count — a non-installed build
lacks `spinit` and loses 81 XSPICE rows, which looks like a different feature set entirely.
Grep for the family names (`builds.md` §2.1).

### 1.6 The probe that does NOT work — `help all`

`com_help.c:56`:

```c
for (numcoms = 0; cp_coms[numcoms].co_func != NULL; numcoms++)
```

The loop **stops at the first entry whose `co_func` is NULL**, and `spcp_coms[]` has eleven such
entries — the control-flow keywords `while repeat dowhile foreach if else end break continue
label goto` at `commands.c:568-610`. Everything from `cdump` (`:612`) onward is invisible.
`[crit §3.2]` measured `help all` printing **115** lines and omitting `linearize`, `cutout`,
`wrnodev`, `optran`, `devhelp`, `inventory`, `settype`, `strcmp`, `strstr`, `strslice`, `fopen`,
`fread`, `fclose`, `cdump`, `mdump`, `mrdump`, `check_ifparm`.

It happens to list every analysis verb — they sit at `commands.c:312-362`, well before the NULL
block — so `an-rf-pss.md` §5.1's *conclusion* ("best probe: `help all`") survives while its
reasoning does not. **Do not generalise `help all` to "the command inventory".**
Also: `help devhelp` prints **nothing at all** — neither a help line nor `Sorry, no help for …`
— an unexplained third anomaly. Never probe with it.

### 1.7 What a different build changes, in one table

| a build with… | gains | and the GUI must |
|---|---|---|
| `--enable-pss` | the `pss` verb and §2.12 | offer the panel, and enforce §2.12's five hard refusals — three of its parameters crash or hang with no message |
| `--disable-sp` | *loses* `sp`, and loses `portnum`/`z0`/`pwr`/`freq`/`phase` on VSRC | drop the SP row and the Ports table together |
| `--enable-cider` | `NUMD NUMD2 NBJT NBJT2 NUMOS` families | **no new analysis, no new dot card, no new `SPICEanalysis`.** Detect it, warn on `.model … numd\|nbjt\|numos` when it is absent (ngspice's own message is `could not find a valid modelname`, naming neither CIDER nor the flag), never emit `.options klu` on such a deck (measured `exit(1)` with every later `.control` command skipped), mark noise/disto/SOA silently incomplete and pz unreliable, and budget **minutes**: the shipped examples span **0.10 s to 329.5 s** (`builds.md` §2.2) |
| `--disable-xspice` | *loses* 9 `.options` keywords and the whole event layer | drop §6.6, and stop forcing `trtol` to 1 |
| `--with-ngshared` | `libngspice` | note this build produces **no `ngspice` binary**; see §7.3 for why this pass refuses it |

**[A-M7] — and this is not a thought experiment.** The two binaries on this machine disagree:

```
build-ver_50   help pss -> Sorry, no help for pss.
               pss 0.5e6 100e-6 1 50 10 50 5e-3 uic
                        -> pss: no such command available in ngspice
/usr/bin/ngspice (45.2)
               help pss -> pss [.pss line args] : Do a periodic state analysis.
               pss 0.5e6 100e-6 1 50 10 50 5e-3 uic
                        -> dispatches; $plots gains pss1;
                           $curplotname = "Time Domain Periodic Steady State Analysis"
```

This also **partly closes the design-of-record's OPEN item M2** ("does `help <verb>` answer the
same way on a different build?"): on a second, differently-configured, differently-versioned
binary it answers correctly for `pss` and `sp`, and the analysis behind the answer really runs.
The literal a GUI sees when it guesses wrong is `pss: no such command available in ngspice`.

⚠ **UPDATED 2026-09-10.** The `build-ver_50` half of the transcript above is historical: that tree
was reconfigured with `--enable-pss --enable-cider` and now answers `help pss`, while still
reporting `ngspice-46+`. The disagreement is still live on this machine — the bare-configure
upstream build in §1.8's middle column answers `Sorry, no help for pss.` (re-measured 2026-09-10) —
and the flip is itself the plainest evidence that a PSS verdict is a configure-time fact no version
string carries.

### 1.8 THE THREE-VARIANT CAPABILITY MATRIX — measured 2026-09-10

**This is the reference table for everything the plan says about *which* ngspice.** It replaces
"the two binaries on this machine" as the working set: a third was built for this pass, and it is
the one that decides the architecture.

| | **apt 45.2** | **stock upstream 47** | **the fork (`ver_50`)** |
|---|---|---|---|
| path | `/usr/bin/ngspice` | `…/workpad/builds/upstream47/src/ngspice` | `/home/analog/dev/ngspice/build-ver_50/src/ngspice` |
| provenance | Ubuntu 26.04.1 LTS, `45.2+ds-1`, `resolute/universe` | `origin/pre-master-47` @ `c5cd68015`, bare `../configure` | `ver_50` @ `ccebdf2a2`, bare `../configure` |
| **`-v` / `version -v`** | `ngspice-45.2` | **`ngspice-46+`** | **`ngspice-46+`** |
| `spcp_coms[]` names | 132 | **134** | **134** |
| help strings that differ from the fork's | several | **zero, out of 134** | — |
| `devhelp` device list vs the fork | CIDER rows extra, XSPICE `astate`/`ota` missing | **identical** | — |
| solver | KLU | KLU | KLU |
| `pss` | **YES** (runs; `$plots` gains `pss1`) | no | no |
| CIDER (`NUMD NUMD2 NBJT NBJT2 NUMOS`) | **YES** (5 rows; `version -f` says *CIDER 1.b1 … included*) | no | no |
| `pyplot` | no (**and it has no `#ifdef`, so no rebuild recovers it**) | YES | YES |
| XSPICE `astate` / `ota` code models | no | YES | YES |
| `sp` / RFSPICE | YES | YES | YES |
| XSPICE / OSDI | YES / YES | YES / YES | YES / YES |
| **casemode (`$curcasemode`)** | **no** | **no** | **YES** — `fold preserve distinguish` |
| `$casemode` accepts `-D casemode=preserve` | **yes, silently, and folds anyway** | **yes, silently, and folds anyway** | yes, and honours it |
| ASE-L capability dict (`ase::sim_capabilities`) | `usable 1 appendwrite 1 hier_op_names 1 blanket_op_save 0 altshow_op_dump 0 casemode_detected {fold}` | `altshow_op_dump 1 casemode_detected {fold}` | `altshow_op_dump 1 casemode_detected {fold preserve distinguish}` |
| resulting `ase::op_save_tier` | **`c`** (`unsafe`) | **`d`** (`dump`) | **`d`** (`dump`) |

**Read three things off it, and they are what §1.7's two-binary table could not show.**

1. **Version detection is impossible between columns 2 and 3.** Both print `ngspice-46+`, because
   `configure.ac:19` is `m4_define([ngspice_major_version], [46+])` in both trees and the fork
   never touched it. All 134 command names match; a join of the two 134-row help-string lists
   filtered to rows that differ is **empty**. Only the build timestamp differs, and that records
   whoever ran `make`. **No version string, command name or help string can tell stock 47 from the
   fork** — which is why the plan's variant record is probe-derived and its version-keyed table
   has zero rows (`PLAN.md` §0.13, `DECISIONS.md` **D43**, **D44**).
2. **Capability is not ordered by version, and it moves in both directions at once.** The oldest
   column has an analysis and five device families the newest two lack; the newest two have a
   command and two code models the oldest lacks. **No binary is "basic"**, so a two-mode GUI
   cannot be built without making a false statement about one axis (`PLAN.md` §0.13.4).
3. **The one thing that DOES separate all three is behaviour, not identity** — casemode
   (a capability), and the two defect probes of §7.5 (behaviour that lands in a file).

⚠ **`altshow_op_dump` is not a fork feature.** It needs upstream `10276f993` (2026-07-07), and
`git tag --contains 10276f993` returns **nothing** — it is in `origin/pre-master-47` and in **no
release**. So on that axis fork == stock 47, and it is 45.2/46 that differ. `altshow` itself has
shipped since ng-37 (upstream `0a8a56c65`, 2007-10-09), which is exactly why ASE-L's
`ase::cap_altshow_verdict` probes the **defect** and not the feature. **Anything that tells a user
"ngspice 47 fixes that" is naming a version that does not exist yet** (`evidence/fork-features.md`
§2).

---

## 2. The twelve analyses

Grammars below are from the parser (`inp2dot.c`, the `*setp.c` tables), **not** from the manual
and not from `src/ngspice.txt` — those disagree in at least four places, one of which
(`help tf`) is measured in §1.5 and one of which (`.noise` default units) is in §2.6.

**Two rules that apply to all of them.**

1. **Card and command share one parser.** `if_run()` (`spiceif.c:257-368`) recognises
   `tran ac dc op pz disto adjsen sens tf noise` (+ `pss`, `sp`, `hb` per build), rebuilds
   `".<what> <flattened args>"` into a `char buf[BSIZE_SP]` — **512 bytes** — and runs
   `INPpas2()` on it. The grammar is therefore identical character for character. The
   **differences are behavioural**, and §2.13 tabulates all seven.
2. **Nothing can be read back.** `DCOaskQuest`, `DCTaskQuest` and `TFaskQuest` are stubs that
   return `E_BADPARM` unconditionally; `NaskQuest`, `DaskQuest` and `SPaskQuest` are implemented
   but no `IFparm` row carries `IF_ASK`, so nothing in the front end can reach them. **The GUI is
   the sole authoritative store of analysis settings.** The one exception in the whole surface is
   `trnoise`/`trrandom`, which are device parameters and *are* readable (§5.1).

---

### 2.1 `options` — the pseudo-analysis (index 0)

> **Tooltip:** *the task settings sheet — tolerances, iteration limits, solver, device defaults.
> Not something you run.*

**It is registered as an analysis and is not one.** `cktsopt.c:389-403` gives it `size = 0`
(comment `/* no size associated with options */`), `domain = NODOMAIN`, `an_init = NULL`,
`an_func = NULL`. `CKTnewAnal()` special-cases `type == 0` and hands back a pointer to
`taskPtr->taskOptions`, i.e. the `TSKtask` itself (`cktnewan.c:23-29`); `CKTsetOpt()` casts its
`JOB*` straight back (`cktsopt.c:35`). Because `size == 0` and the job is never linked into
`task->jobs`, **an options "job" never appears in `CKTdoJob`'s execution loop.**

| | |
|---|---|
| card | `.options k=v k=v …` / `.option …` / `.opt …` |
| command | `option k=v …` / `options k=v …` — **and it accepts a different keyword set**, §3.1 |
| parameters | **98**, tabulated in §3.1 |
| plots | none |
| shape | none |

`CKTdoJob()` copies `TSK*` → `CKT*` at the start of **every run** (`cktdojob.c:52-120`), so
options are latched per-run, not per-analysis. It also prints, unconditionally,
`Doing analysis at TEMP = %f and TNOM = %f` (`cktdojob.c:122-123`) — a reliable per-run marker
for a log parser.

Two run-time overrides applied there that a GUI must know about:
* `#ifdef XSPICE`, if the circuit has any `A` device and `trtol > 1`, **`trtol` is forced to 1**
  with `Reducing trtol to 1 for xspice 'A' devices`, unless `set xtrtol=<n>` overrides
  (`cktdojob.c:77-92`). This changes numbers on every mixed-signal deck.
* `ckt->CKTnoopac = TSKnoopac && ckt->CKTisLinear` (`cktdojob.c:109`).

---

### 2.2 `OP` — operating point (index 3)

> **Tooltip:** *solve the DC bias point: every node voltage and source current with all
> capacitors open and inductors shorted.*

| | |
|---|---|
| card | `.op` — **the rest of the line is discarded** (`dot_op()` does `NG_IGNORE(line)`, `inp2dot.c:124-143`) |
| command | `op` — `commands.c:312-315`, min args 0, max `LOTS`. `if_run()` rebuilds `.op <args>` and re-parses, so anything typed is lexed and then ignored |
| parameters | **none.** `DCOsetParm()` has an empty switch and returns `E_BADPARM` (`dcosetp.c:16-29`); `DCOaskQuest()` likewise (`dcoaskq.c:15-22`). The JOB struct is the bare `JOB` header (`opdefs.h:115-119`) |
| preconditions | at least one non-ground node. An empty netlist prints `Error: incomplete or empty netlist / or no node to report an operating point for; no operating point printed!` and returns 1 (`dotcards.c:231-237`; this tree's own fix, `doc/codex/issues/0072-*.md`) |
| `Plotname:` | **`Operating Point`** (`inp2dot.c:141` → `dcop.c:48-52`) |
| plots | **1** |
| shape | **scalar set** — 1 point, `Flags: real`, **no scale vector** (`refName = NULL` at `dcop.c:48-52`, `run->refIndex = -1` at `outitf.c:302-304`). "No. Variables: 3" means three data columns and no independent axis |

**Vectors.** Exactly `CKTnames()`'s list: every entry of `ckt->CKTnodes` except ground
(`cktnames.c:18-31`). Voltage nodes keep their deck name; branch equations are named
`<src>#branch` internally and written as `i(<src>)` unless `set keep#branch`
(`outitf.c:1091`). **Device-level quantities (`@m1[gm]`, `@q1[ic]`) are NOT in this list** —
they arrive only through the `save` mechanism, and §6.4 records the measurement that says why.

**Traps.**

* **`.nodeset` bites in an `.op`; `.ic` does not.** `do_ic == 1` for OP, so `CKTic()` runs first
  (`cktdojob.c:190-191`): it writes both into `CKTrhsOld`/`CKTrhs` (`cktic.c:26-70`), but during
  the solve `CKTload()` **forces** nodeset nodes while `MODEINITJCT|MODEINITFIX` is active
  (`cktload.c:120-145`, `rhs = 1e10*nodeset*srcFact`, diagonal `1e10`) and forces `.ic` nodes
  **only under `MODETRANOP` and only when `MODEUIC` is clear** (`cktload.c:146-173`).
* **The operating point you get may come from a transient.** `optran` is armed by default in
  this build — `init.c:80-94` calls `com_optran` with the literal arguments `1 1 1 100n 10u 0`,
  read this pass. See §3.5; the measured error is `0.9999550` instead of `1.0` on a 1 µs RC.
* **`.op` card and `op` command print differently.** The card makes `ft_cktcoms()` print the
  node/source table plus `showmod` and `show` (`dotcards.c:222-272`); the command prints only
  `No. of Data Rows : 1`. Under `-r` the card prints `OP information in rawfile.` instead.
* `setcplot("op")` uses `ciprefix` (`dotcards.c:38-48`), so with several op plots it finds the
  **first** whose typename starts with `op` — not the newest.

---

### 2.3 `DC` — DC transfer curve (index 2)

> **Tooltip:** *step a source, a resistor or the temperature and record the bias point at every
> value.*

| | |
|---|---|
| card | `.dc SRC1 Vstart1 Vstop1 Vinc1 [SRC2 Vstart2 Vstop2 Vinc2]` (`inp2dot.c:284-345`) |
| command | `dc …` — identical grammar |
| `Plotname:` | **`DC transfer characteristic`** (`inp2dot.c:303` → `dctrcurv.c:191-195`) |
| plots | **1** (+ `Distortion Operating Point`? no — DC takes no `keepopinfo` extra) |
| shape | **sweep**, 1-D, and a nested sweep is **flattened** — see the traps |

**Parameters** — `DCTparms`, `dctsetp.c:91-102`, ids from `trcvdefs.h:84-95`:

| keyword | flags | meaning | unit | default | legal | illegal value does |
|---|---|---|---|---|---|---|
| `name1` | `SET\|INSTANCE` | instance to step (position 1 on the card) | — | none | a V source, an I source, a **resistor**, or the literal **`temp`** | fatal — `DC Transfer Function: Voltage source, current source, or resistor named "%s" is not in the circuit`, `E_NODEV`, `$sim_status = 1` (`dctrcurv.c:153-157`) |
| `start1` | `SET\|REAL` | first sweep start | V / A / Ω / °C | 0 (calloc) | any real | — |
| `stop1` | `SET\|REAL` | first sweep stop | same | 0 | any real | — |
| `step1` | `SET\|REAL` | first sweep increment | same | 0 | **non-zero**, sign matching `stop−start` | `0` → parser returns 1 → `Error: Bad syntax! in   .dc v1 0 1 0`, run aborted (`inp2dot.c:320-322`, `:895-897`) |
| `name2` `start2` `stop2` `step2` | as above | the outer nest level | | | | |
| `type1` `type2` | `SET\|INTEGER` | source type code | — | discovered | — | **never written by any parser in the tree**; they exist for an external front end that wants to bypass discovery |

**Nothing is askable.** `DCTaskQuest()` has an empty switch (`dctaskq.c:15-27`, with the comment
`/* TEMPORARY until cases get added */`).

**What is sweepable, and in what order it is looked for** (`dctrcurv.c:62-64`, `:87-160`):
resistor → voltage source → current source → `temp` (case-insensitive `cieq`, `TEMP_CODE` 1023).
**Model parameters and arbitrary instance parameters are NOT sweepable by `.dc`.**

**The scale vector's name encodes the swept kind** (`dctrcurv.c:180-189`), and this is the
label a plot axis should follow:

| level-0 kind | scale vector | in the rawfile |
|---|---|---|
| voltage source | `v-sweep` | **`v(v-sweep)`** — it alone gets the `v(...)` wrapper |
| current source | `i-sweep` | `i-sweep` |
| temperature | `temp-sweep` | `temp-sweep` |
| resistance | `res-sweep` | `res-sweep` |
| anything else | `?-sweep` | — |

**Traps.**

* **`start > stop` with a positive step produces ZERO points and no error at all.** Measured:
  `.dc V1 1 0 0.5` → `No. of Data Rows : 0`, `$sim_status = 0`, four zero-length vectors. The
  test is `SGN(step)*(current − stop) > DBL_EPSILON*1e3` (`dctrcurv.c:213-264`) and it fails on
  the first iteration. **The GUI must validate `sgn(stop−start) == sgn(step)` itself.**
* **Only two nest levels.** `TRCVNESTLEVEL` is 2 — `trcvdefs.h:20`,
  `#define TRCVNESTLEVEL 2 /* depth of nesting of curves - 2 for spice2 */`; ⚠ an earlier draft
  cited `:58`, which is inside the struct that *uses* it. A third triple is **silently
  dropped**. Measured: `.dc a 0 1 1 b 0 1 1 c 0 1 1` produced 4 rows, no warning.
* **A nested sweep comes back flattened.** The 2×3 example gives 6-long vectors with
  `v-sweep = 0, 0.5, 1, 0, 0.5, 1` and the outer variable as an ordinary data vector. There is
  **no `Dimensions:` header** and `pl_ndims` is 1 (`outitf.c:498-499`). A family of curves must
  be re-split by the reader using the inner-loop length it computed itself. This is the single
  largest gap versus Cadence ADE.
* **`temp` as a sweep level is a real, native capability and nobody documents it in the syntax
  line.** `[R-M12]`: `dc v1 0 1 0.5 temp -40 60 50` → **9 rows**, one flattened `v-sweep` scale.
  So "sweep the bias at three temperatures" is **one command** when the temperatures are
  uniformly stepped, and a generated campaign only when they are not (§4.3).
* A temperature step re-runs `inp_evaluate_temper()` and `CKTtemp()` at **every** point
  (`dctrcurv.c:466-467`) — slow, and the reason for the `FIXME` guard at `:456-464`.
* Convergence per point: `NIiter(ckt, CKTdcTrcvMaxIter)` first (`itl2`), falling back to
  `CKTop(…, CKTdcMaxIter)` (`itl1`) — unless `newcompat.hs`, which uses full `CKTop` everywhere
  and aborts on any failure (`dctrcurv.c:297-315`).

---

### 2.4 `TRAN` — transient (index 4)

> **Tooltip:** *integrate the circuit forward in time from the operating point (or from the
> initial conditions).*

| | |
|---|---|
| card | `.tran Tstep Tstop [Tstart [Tmax]] [UIC]` (`inp2dot.c:410-457`) |
| command | `tran …` — identical grammar |
| `Plotname:` | **`Transient Analysis`** (`inp2dot.c:429` → `dctran.c:181-185`); `<old> (linearized)` after `linearize` |
| plots | **1** |
| shape | **sweep**, scale `time` |

**Parameters** — `TRANparms`, `transetp.c:64-70`:

| keyword | flags | meaning | unit | default | legal | illegal value does |
|---|---|---|---|---|---|---|
| `tstep` | `SET\|REAL` | **not an output interval** — see below | s | none, mandatory | `> 0` | `Error: TSTEP is invalid, must be greater than zero.`, field forced to `1.0`, `E_PARMVAL`, `tran simulation(s) aborted`, `$sim_status = 1` |
| `tstop` | `SET\|REAL` | final time | s | none, mandatory | `> 0` | `Error: TSTOP is invalid, must be greater than zero.`, forced to `1.0`, abort |
| `tstart` | `SET\|REAL` | when data starts being **kept** (the run still starts at 0) | s | `0` | `< tstop` | `Error: TSTART is invalid, must be less than TSTOP.`, forced to `0.0`, abort |
| `tmax` | `SET\|REAL` | maximum internal timestep | s | derived — see below | **no validation at all**; `0` is legal and means "derive it"; a negative value is accepted and misbehaves | — |
| `uic` | `SET\|FLAG` | skip the operating point, start from the initial conditions | — | off | — | a zero value is a no-op; **the flag cannot be cleared once set** (`transetp.c:52-54`) |

⚠ **Ordering hazard:** `tstart` is validated against `TRANfinalTime`, so **`tstop` must be set
first**. The netlist parser does that (`inp2dot.c:432-438`); anything driving `setAnalysisParm`
directly must respect it.

`TRANaskQuest()` reads back all five (`tranaskq.c:14-46`) even though no row carries `IF_ASK` —
the lookup helpers do not enforce the flag (`spiceif.c:1847-1855`, `:1285-1294`), and
`com_linearize()` relies on that (`linear.c:53`). Trust the code; the flag table is stale.

**What `tstep` actually does** — `traninit.c:17-40`, and this is the most misunderstood field in
SPICE:

```c
if (ckt->CKTmaxStep == 0) {
    if ((ckt->CKTstep < (ckt->CKTfinalTime - ckt->CKTinitTime)/50.0)
        && !cp_getvar("nostepsizelimit", CP_BOOL, NULL, 0))
        ckt->CKTmaxStep = ckt->CKTstep;
    else
        ckt->CKTmaxStep = (ckt->CKTfinalTime - ckt->CKTinitTime)/50.0;
}
ckt->CKTdelmin = 1e-11 * ckt->CKTmaxStep;   /* XXX */
```

* `tstep`'s **only structural role** is to become the default `tmax`, and only when it is smaller
  than `(tstop−tstart)/50`.
* `set nostepsizelimit` makes `tmax` default to `(tstop−tstart)/50` regardless.
* `delmin` — the floor that triggers `Timestep too small` — is `1e-11 × tmax`, hence indirectly
  derived from `tstep`.
* `tmax = 0` written explicitly is indistinguishable from omitting it.
* `CKTminBreak` is `10 × CKTdelmin` under XSPICE (which is on here) and `CKTmaxStep × 5e-5`
  otherwise (`dctran.c:160-169`). ⚠ **CORRECTION:** `dotcards.md` §3.21's table gives only the
  non-XSPICE form; with XSPICE the value is five and a half orders of magnitude smaller
  [crit §C6]. Use `10 × delmin`.

**Measured point counts** [A-M10], from `No. of Data Rows`. ⚠ **These numbers are deck-dependent —
so here is the deck**, in full, because a point count with an unspecified pulse source cannot be
re-run and therefore cannot be challenged:

```
* tran point counts -- 1k / 1n RC, pulse source
v1 in 0 pulse(0 1 1u 10n 10n 5u 10u)
r1 in mid 1k
c1 mid 0 1n
.control
tran 1u 20u
.endc
.end
```

| command | rows, this deck | an earlier pass, deck **not recorded** |
|---|---|---|
| `tran 1u 20u` | **111** | 125 |
| `tran 1u 20u 5u` | **89** | 97 |
| `tran 1u 20u 0 0.2u` | **156** | 169 |
| `tran 1u 20u uic` | **110** | 124 |
| `set interp` then `tran 1u 20u` | **21** | 21 (= 20u/1u + 1) |

⚠ **CORRECTION IN KIND, not in fact.** The right-hand column is what an earlier pass measured on a
deck it did not write down. The absolute numbers differ because the pulse differs; **every relation
the table exists to show is identical on both decks** — `tstart` drops points, `tmax` adds them,
`uic` costs exactly one, and `set interp` gives `tstop/tstep + 1` regardless. Only the `interp`
number is deck-independent, and it is arithmetic. Quote the relations, not the absolutes; if you need
an absolute, run the deck above.

So **by default the plot receives every accepted internal timepoint.** For a uniform grid there
are exactly two routes and the GUI must offer one of them explicitly:

* **`set interp` before the run** — latched into a file-static at `beginPlot()`
  (`outitf.c:210-214`), prints `Warning: Interpolated raw file data!`, routes TRAN points
  (`JOBtype == 4`) through `InterpFileAdd()`/`InterpPlotAdd()`. It affects **only TRAN**.
* **`linearize` after it** — requires the current plot to be `tran*` (`linear.c:34`), pulls
  `tstart/tstop/tstep` back out of the job, and writes a **new plot** named
  `<old> (linearized)`. Overridable per plot with `lin-tstart` / `lin-tstop` / `lin-tstep`
  vectors (`linear.c:67-80`).

**What `uic` changes.** `MODEUIC` (`cktdefs.h:199`) is read in exactly three places outside the
drivers: `cktic.c:73-80` calls every device's `DEVsetic` — for a capacitor that is `CAPgetic()`,
which for **every capacitor without its own `ic=`** copies the node-pair voltage out of `CKTrhs`,
where `CKTic()` has just written the `.ic` values; `capload.c:30-51` and `indload.c:42-71` then
take the state from `CAPinitCond`/`INDinitCond` at `MODEUIC && MODEINITTRAN`. Plus the negative
case at `cktload.c:146`. **So: without `uic`, `.ic` pins nodes during the TRANOP and is then
released; with `uic`, `.ic` is pushed into the storage elements instead.** A `uic` checkbox with
no surface for authoring `.ic`/`.nodeset` is a control that changes the answer and reports
nothing about what it used.

**Traps.**

* `tran 1u 10u foo` → `Error:  Error: unknown parameter on .tran - ignored` **and the run does
  not happen** (`inp2dot.c:451-453`), despite the word "ignored".
* `.tran 1u 20u uic` (no `tstart`/`tmax`) **works** — `INPevaluate` fails on `uic` and leaves the
  token for the final loop. But an explicit `tmax` with no `tstart` must emit `tstart 0`, because
  the argument list is positional.
* With `set ngdebug` a transient gains two extra vectors, `speedcheck` and `deltacheck`
  (`outitf.c:355-359`) — wall-clock-vs-simulated-time and accepted-step-vs-time. A ready-made
  "why is this slow" plot that costs nothing and appears in one sentence of one dossier.
* A memory pre-check refuses very large transients: `Warning: memory required (…B), made of N
  nodes and approximately M time steps, is more than the DRAM memory available (…B)!` — a
  warning on POSIX, a hard `controlled_exit(1)` on **Windows** (`outitf.c:143-173`). Suppressed
  by `set no_mem_check`.

---

### 2.5 `AC` — small-signal frequency response (index 1)

> **Tooltip:** *linearise about the operating point and sweep frequency; every node becomes a
> complex gain.*

| | |
|---|---|
| card | `.ac {DEC\|OCT\|LIN} N Fstart Fstop` (`inp2dot.c:182-245`) |
| command | `ac {dec\|oct\|lin} N fstart fstop` — identical grammar |
| `Plotname:` | **`AC Analysis`**; **`AC Operating Point`** as an *extra, earlier* plot under `keepopinfo` (`acan.c:157-161`) |
| plots | **1**, or **2** with `keepopinfo` |
| shape | **spectrum / swept complex**, scale `frequency`, `Flags: complex`, `grid=3` (log) unless LINEAR |

**Parameters** — `ACparms`, `acsetp.c:85-92`:

| keyword | flags | meaning | unit | default | legal | illegal value does |
|---|---|---|---|---|---|---|
| `start` | `SET\|ASK\|REAL` | start frequency | Hz | none | `>= 0`, and `> 0` for dec/oct | `< 0` → `Frequency of < 0 is invalid for AC start`, `E_PARMVAL`, **and it writes `ACstartFreq = 1.0`** |
| `stop` | `SET\|ASK\|REAL` | stop frequency | Hz | none | `>= 0` | `< 0` → **`Frequency of < 0 is invalid for AC stop`** — its own message, not `start`'s — and ⚠ the error arm then sets **`ACstartFreq = 1.0`**, not `ACstopFreq`: a copy-paste slip at `acsetp.c:34-39`. The *field written* is what is shared, not the string. A message-matching parser that expects `start`'s text here finds nothing |
| `numsteps` | `SET\|ASK\|INTEGER` | points **per decade** (dec), **per octave** (oct), or **total** (lin) | count | none | `>= 1`; and **`!= 2` for lin** | clamped to 1 at `acan.c:72-73` |
| `dec` / `oct` / `lin` | `SET\|FLAG` | step type; mutually exclusive | — | none | exactly one | missing → hard error `Missing DEC, OCT, or LIN.` |

`ACaskQuest` answers all six including the three flags, though the flags carry no `IF_ASK`
(`acaskq.c:16-74`).

**The parser silently repairs three things and warns once** (`inp2dot.c:204-243`):

| you wrote | it uses | warning |
|---|---|---|
| `numsteps < 1` | **10** | `Warning, ngspice assumes default parameter(s) for ac simulation` + `    Check your input line '.ac %s'` |
| `fstart < 0` | **1.0** | same pair |
| **`fstop < fstart`** | **`1000 × fstart`** | same pair |

Measured: `ac dec 5 10k 1k` warned and swept 10 kHz…10 MHz, 16 points; `ac dec 0 1k 10k` warned
and used 10 pts/dec, 11 points. **A GUI must pre-empt all three** — the warning names neither the
field nor the substituted value.

Note the step-type guard is a `ciprefix` test but `INPapName` then requires an exact keyword, so
`.ac decade 5 1 1k` passes the guard and dies inside `INPapName` with
`Error: no such parameter on this device or parameter is missing`.

**Traps.**

* ☠ **`ac lin 2 <f1> <f2>` silently produces ONE point.** `acan.c:103-114`:
  `if (job->ACnumberSteps - 1 > 1) … else ACfreqDelta = 0;` — `2−1 = 1` is not `> 1`.
  Re-measured this pass [A-M2] on this binary, from this deck:

  ```
  * ac lin 2 trap
  v1 in 0 dc 0 ac 1
  r1 in mid 1k
  c1 mid 0 1n
  .control
  ac lin 2 1k 11k
  let n = length(frequency)
  print n
  .endc
  .end
  ```

  `ac lin 2 1k 11k` → `No. of Data Rows : 1`, `n = 1.000000e+00`;
  `ac lin 3 1k 11k` → `No. of Data Rows : 3`, `n = 3.000000e+00`.
  ⚠ **`sp lin 2` has the identical defect and the identical shape** — measured this pass:
  `sp lin 2 100meg 1g` → `No. of Data Rows : 1`, `sp lin 3 100meg 1g` → 3 (§2.11, §7.2 S1). `an-smallsig.md` §2.3 measured `lin 11`, `lin 1`
  and five dec/oct cases but never `lin 2`, so it reads as "numsteps is the total" with no
  exception. **Refuse 2, or silently promote to 3.**
* **An AC run with no AC source is meaningless and there is no check.** Measured: a deck whose
  only source is `v1 in 0 dc 1` runs to completion and reports `v(out) = 0,0` at every frequency
  with **no warning of any kind**. The GUI must validate this itself: `ac`/`acmag` on at least
  one independent source, any magnitude. Defaults, from `vsrctemp.c:38-43`: `acGiven && !acMGiven`
  ⇒ `acMag = 1`; `acGiven && !acPGiven` ⇒ `acPhase = 0`. **Source phase is in degrees**
  (`vsrctemp.c:68-70`).
* **`frequency` reports as `complex` in the in-memory plot** even though it is written `IF_REAL`
   — `plotInit`'s "hack" at `outitf.c:1221-1226` promotes *all* vectors to complex if any one is.
* ⚠ **Output phase is in RADIANS by default.** `[R-M10]`: `vp(mid)` = `-4.96729e-04`; after
  `set units=degrees`, `-2.84605e-02` — a factor of 57.2958. `units` is a `CP_STRING` read at
  `options.c:419` (`miscvars.c:124`). Any phase margin computed without it is wrong by 57×.

---

### 2.6 `NOISE` (index 8)

> **Tooltip:** *how much noise this circuit has at one output, where it comes from, and how it
> varies with frequency.*

| | |
|---|---|
| card | `.NOISE V(OUTPUT[,REF]) SRC {DEC\|LIN\|OCT} PTS FSTART FSTOP [PTSPERSUMMARY]` (`inp2dot.c:18-121`) |
| command | `noise v(out[,ref]) src {dec\|lin\|oct} pts fstart fstop [ptspersummary]` |
| `Plotname:` | **`Noise Spectral Density Curves`** and **`Integrated Noise`**; renamed under `sqrnoise`; plus **`NOISE Operating Point`** first under `keepopinfo` |
| plots | **2** — or **1** at a single frequency, or **3** with `keepopinfo` |
| shape | plot 1 = **spectrum**; plot 2 = **scalars** (1 point, no scale) |

**Parameters** — `Nparms`, `nsetparm.c:82-93`:

| keyword | flags | meaning | unit | default | legal | illegal value does |
|---|---|---|---|---|---|---|
| `output` | `SET\|STRING` (⚠ read as `nValue`) | output summation node | node | none | must resolve | see below |
| `outputref` | `SET\|STRING` (⚠ `nValue`) | reference node | node | **ground** when the `,ref` is absent | must resolve | — |
| `input` | `SET\|STRING` (`uValue`) | the source noise is referred to | instance | none | a V or I source **carrying an AC value** | three distinct refusals, below |
| `dec`/`oct`/`lin` | `SET\|FLAG` | step type | — | none | one | **no zero-clearing branch, unlike AC** |
| `numsteps` | `SET\|INTEGER` | points per decade / per octave / total | count | none | `>= 1` | `< 1` → `Number of steps for noise measurement has to be larger than 0,\n    but currently is %d` + `E_PARMVAL` |
| `start` | `SET\|REAL` | start frequency | Hz | none | `> 0` | `<= 0` → `Frequency of 0 is invalid`, `E_PARMVAL`, sets `NstartFreq = 1.0` |
| `stop` | `SET\|REAL` | stop frequency | Hz | none | `> 0` | same, and ⚠ again writes **`NstartFreq`** — the same copy-paste slip as AC |
| `ptspersum` | `SET\|INTEGER` | frequency points per summary report | count | **0**, set explicitly by the parser when the token is absent (`inp2dot.c:105-110`) | `>= 0` | — |

⚠ **`output`/`outputref` declare `IF_STRING` and the setter reads `value->nValue`, a
`CKTnode *`** (`nsetparm.c:24`, `:28`). It works only because the parser hands over a resolved
node. **Never drive these through a generic string path** — it corrupts a pointer.
`NaskQuest` implements all ten ids (`naskq.c:14-89`) and **no row carries `IF_ASK`**, so nothing
can reach it.

**Preconditions, in the order `NOISEan` enforces them** (`noisean.c`):

1. `option klu` → `Error: Noise simulation is not (yet) supported with 'option KLU'.\n    Use 'option sparse' instead.` → `E_UNSUPP` (`:73-78`).
2. `posOutNode`/`negOutNode` are dereferenced with **no NULL check** (`:84-85`).
3. Single-frequency normalisation (`:93-109`) using `AlmostEqualUlps(start, stop, 3)`: emits
   `Noise measurement at a single frequency %g only!`.
4. Input source: not found → `Noise input source %s not in circuit` + `E_NOTFOUND`; wrong class →
   `Noise input source %s is not of proper type` + `E_NOTFOUND`; **no `acGiven` → `Noise input
   source %s has no AC value` + `E_NOACINPUT`**, which the user sees as
   `doAnalyses: ac input not found` (`sperror.c:105`).

**Stepping differs from AC** (`noisean.c:145-168`): `DECADE` → `exp(log(10)/N)`,
`OCTAVE` → `exp(log(2)/N)`, `LINEAR` → `(stop−start)/(N−1)` with `N==1` giving 0. A 1 Hz…1 MHz
`dec 10` run is 6 decades × 10 + 1 = **61 points** — a derived readout worth showing on the form.

**⚠ The `Integrated Noise` plot exists only when `start != stop`** (`noisean.c:511`). Measured:
a single-frequency noise run produces **only** the spectral plot. A "spot noise at f" feature
must not look for `onoise_total`.

**Vectors.** Circuit-level ones are appended last by `cktnoise.c:56-64` / `:76-82`:
`onoise_spectrum`, `inoise_spectrum` in plot 1; `onoise_total`, `inoise_total` in plot 2.

**`sqrnoise` — the units switch, and it is a `set` variable, not an `.options` keyword.**
⚠ **CORRECTION:** `outputs.md` §3 writes `.options noisesquared`/`squared`. Both are wrong;
`noisean.c:242` is the only read and it is `cp_getvar("sqrnoise", CP_BOOL, NULL, 0)`
[crit §C5]. It works from **both** doors (`.options sqrnoise` and `set sqrnoise`), measured:

| deck | plot titles | `onoise_total` |
|---|---|---|
| default | `Noise Spectral Density Curves` / `Integrated Noise` | `1.829825e-06` |
| `.options sqrnoise` | `… - (V^2 or A^2)/Hz` / `Integrated Noise - V^2 or A^2` | `3.348261e-12` |
| `set sqrnoise` in `.control` | identical to the above | `3.348261e-12` |

⚠ **CORRECTION to the built-in help.** `src/ngspice.txt:3149-3155` says "All noise
voltages/currents are in squared units" — inherited from SPICE3 and **stale**. RMS / per-√Hz is
the default in this tree.

**Traps.**

* ☠ **`ptspersum` couples the contributor table to spectrum DECIMATION.** Every device noise
  routine registers its per-source vectors only when `NStpsSm != 0` (e.g. `resnoise.c:68`), and
  `cktnoise.c:102-103` writes a spectrum row only when `NStpsSm == 0 || prtSummary`. Measured:
  `ptspersum = 4` over 21 frequency points leaves **6 rows**. `ptspersum = 1` gives the full
  breakdown with **no** decimation and is the setting a "noise summary" feature wants. The raw
  parameter is a decimation factor whose *side effect* is the table — a GUI should present it as
  a checkbox named for the thing the user wants, with the decimation behind it.
* ⚠ **Three naming hazards in the contributor table**, and a sum that ignores any of them is
  wrong: (a) two conventions coexist — `onoise_total_<inst>_<mech>` with **underscores** for most
  devices (`resnoise.c:73`), `onoise.<inst>.<mech>` with **dots** for BSIM3/BSIM4/BSIMSOI/HiSIM
  (`b4noi.c:145-151`); (b) the **empty-suffix** entry is the device *total*, so a naive sum
  double-counts; (c) OSDI emits `onoise_total_<inst>` **with a trailing space**
  (`osdinoise.c:111-113`).
* **Devices with no noise model contribute exactly zero, silently.** `DEVnoise` is NULL for
  `asrc` (B-source), `cap`, `cccs`, `ccvs`, `cpl`, `hfet1`, `hfet2`, `ind`, `isrc`, `ltra`,
  `mesa`, **`mos6`**, `nbjt`, `nbjt2`, `ndev`, `numd`, `numd2`, `numos`, `tra`, `txl`, `urc`,
  `vccs`, `vcvs`, `vsrc`. So a behavioural model built out of B-sources is noiseless, and
  MOS level 6 has no noise while levels 1/2/3/9 do. A resistor can also be made noiseless per
  instance with the deck keyword `noisy` (`resnoise.c:57`).
* `Nintegrate()`'s definition was never located by anyone on this pass, so nobody can yet explain
  an `onoise_total` number to a user in a tooltip. Recorded in §8 as still open.

---

### 2.7 `TF` — DC small-signal transfer function (index 6)

> **Tooltip:** *the DC gain from one source to one output, plus the input and output
> resistances — three numbers, no sweep.*

| | |
|---|---|
| card | `.TF OUTVAR INSRC` where OUTVAR is `v(node[,node2])` or `i(vsrcname)` (`inp2dot.c:348-407`) |
| command | `tf <outvar> <insrc>` |
| `Plotname:` | **`Transfer Function`** |
| plots | **1** |
| shape | **three scalars** — 1 point, `IF_REAL`, **no scale vector** |

**Parameters** — `TFparms`, `tfsetp.c:53-59`: `outpos` (`SET\|NODE`), `outneg` (`SET\|NODE`),
`outname` (`SET\|STRING`, the display string), `outsrc` (`SET\|INSTANCE`), `insrc`
(`SET\|INSTANCE`). No defaults; no `IF_ASK`; **`TFaskQuest` returns `E_BADPARM`
unconditionally** (`tfaskq.c:15-32`) — TF is write-only.

⚠ **Ordering hazard:** `outpos`/`outneg` set `TFoutIsV=1, TFoutIsI=0`, and `outsrc` sets the
reverse. **The last one set wins.** `dot_tf` never sets both.

**Preconditions** (`tfanal.c:49-71`): `insrc` must exist (`Transfer function source %s not in
circuit`) and be a `Vsource` or `Isource` (`Transfer function source %s not of proper type`),
both `E_NOTFOUND`. The operating point is computed and its **result is discarded** (`:44-47`).

**⚠ The three vector names are not what any design wrote.** Measured (`tfanal.c:90-102`):

```
tf i(vsense) v1  ->  Transfer_function   v1#Input_impedance      vsense#Output_impedance
tf v(out)    v1  ->  Transfer_function   v1#Input_impedance      output_impedance_at_V(out)
```

The input impedance carries the **source name as a UID prefix**, and the voltage-output form of
the output impedance is `output_impedance_at_V(<node>)` — **with a capital `V` and literal
parentheses in the vector name**. A probe keyed on `Input_impedance` or
`output_impedance_at_<node>` finds nothing. ⚠ **CORRECTION** to `design-C`, carried here.

**Values** (`tfanal.c:112-157`): a single real solve against the already-factored OP Jacobian
with a unit excitation — **there is no AC load and no omega; this is DC small-signal.** Input
impedance for a voltage input is `−1/rhs[insrc]`, **clamped to `1e20`** when
`|rhs[insrc]| < 1e-20`. Output impedance is copied from the input impedance and the second solve
skipped when `TFoutIsI && TFoutSrc == TFinSrc`.

Units: the transfer function is dimensionless for V/V, A/V for I/V, V/A for V/I, A/A for I/A;
both impedances are ohms. **ngspice types all three as `voltage`** — the GUI must label them.

**Traps.**

* `.tf v out v1` (missing the parenthesis) is **silently mis-parsed** — the `v` branch has an
  empty error arm, `if (*line != '(') { /* error, bad input format */ }` (`inp2dot.c:372-374`).
  `.sens` has a hard error for the same mistake; `.tf` does not.
* In non-terse batch mode a `.tf` card auto-prints: `dotcards.c:274-284` walks the plot list and
  for every plot whose typename starts with `tf` prints `Transfer function information:` then
  `com_print(&all)`. So `.tf` produces output with no `.print` line at all.
* A `.tf` **card** installs `com_save2(&all, "TF")`, which scopes the save set — and that is one
  of the four routes into the DISTO segfault (§2.9).

---

### 2.8 `PZ` — pole-zero (index 5)

> **Tooltip:** *find the poles and zeros of one transfer function in the s-plane.*

| | |
|---|---|
| card | `.PZ NODE1 NODE2 NODE3 NODE4 {CUR\|VOL} {POL\|ZER\|PZ}` (`inp2dot.c:247-281`) |
| command | `pz n1 n2 n3 n4 {cur\|vol} {pol\|zer\|pz}` |
| `Plotname:` | **`Pole-Zero Analysis`**; ⚠ under `keepopinfo` the extra OP plot is labelled **`Distortion Operating Point`** — an upstream copy-paste bug at `pzan.c:57-61` |
| plots | **1**, or **2** with `keepopinfo` |
| shape | **root list** — `Flags: complex`, **no scale vector**, one data row |

**Parameters** — `PZparms`, `pzsetp.c:78-88`. ⚠ **Every `description` string in this table is
the empty string `""`** — a GUI cannot build tooltips from the parameter table for PZ, and must
carry its own text.

| keyword | flags | meaning | default | notes |
|---|---|---|---|---|
| `nodei` | `SET\|ASK\|NODE` | input + | 0 | stored as an **equation number**, not a `CKTnode*` |
| `nodeg` | `SET\|ASK\|NODE` | input − | 0 | |
| `nodej` | `SET\|ASK\|NODE` | output + | 0 | |
| `nodek` | `SET\|ASK\|NODE` | output − | 0 | |
| `vol` | `SET\|ASK\|FLAG` | transfer is Vout/Vin | — | |
| `cur` | `SET\|ASK\|FLAG` | transfer is Vout/Iin | — | |
| `pol` | `SET\|ASK\|FLAG` | poles only | — | |
| `zer` | `SET\|ASK\|FLAG` | zeros only | — | |
| `pz` | `SET\|ASK\|FLAG` | both | — | |

**Defaults are all zero, and that is a trap.** Omitting `{POL|ZER|PZ}` leaves `PZwhich = 0`, so
`PZan` does **neither** search (`pzan.c:67`, `:76`) and `PZpost` opens a plot with **zero
vectors**. Omitting `{CUR|VOL}` leaves `PZinput_type = 0`, which `CKTpzSetup` treats as the
*current* case (`cktpzset.c:106`). `dot_pz` performs **no validation** of those two tokens — a
bad word reaches `INPapName`, which prints it and returns `E_BADPARM`.

**Preconditions** (`pzan.c:29-35`, `:92-128`):

| condition | code | what the user sees |
|---|---|---|
| `option klu` | `E_UNSUPP` | `Error: Pole/zero analysis is not (yet) supported with 'option KLU'.\n    Use 'option sparse' instead.` |
| any transmission line (`Tranline`, `LTRA`) | `E_XMISSIONLINE` | `transmission lines not supported by pole-zero` |
| `nodei == nodeg` | `E_SHORT` | `doAnalyses: input or output shorted` |
| `nodej == nodek` | `E_SHORT` | same |
| in == out, `vol` | `E_INISOUT` | `doAnalyses: transfer function is 1` |
| in == swapped out, `vol` | `E_INISOUT` | `Transfer function is -1` |

**Root-finder give-ups** (`cktpzstr.c`): iteration limit `NITER_LIM = 200`, warning
`Pole-zero iteration limit reached; giving up after %d trials`; `Aberr_Num > 2` →
`Pole-zero converging to numerical aberrations; giving up after %d trials`; `Max_Zeros` is the
matrix size; Ctrl-C → `Pole-Zero analysis interrupted; %d trials, %d roots` + `E_PAUSE`.

**Vectors.** `sprintf(name, "pole(%-u)", i+1)` and `"zero(%-u)"` (`pzan.c:151`, `:155`) — the
parentheses are **part of the vector name**. A complex pair occupies `pole(k)` and `pole(k+1)`,
the conjugate emitted immediately after. Values are **s-plane radian frequencies** (rad/s);
ngspice types them `voltage`, so a GUI showing "pole frequency in Hz" must divide by 2π itself.

**Traps.**

* **A legitimately empty result is normal.** Measured: `pz in 0 out 0 vol zer` on a first-order
  RC found no zeros, so `PZpost` opened a plot with **zero vectors**, and a following
  `print all` printed the *constants* plot instead.
* **`cur` mode can return a meaningless root with no complaint.** Measured: `pz in 0 out 0 cur
  pz` on the same RC returned `pole(1) = 0,0` while `vol pol` correctly returned `-1e6`
  (= −1/RC).
* PZ rebuilds the matrix **twice** and reassigns the state-vector indices
  (`cktpzset.c:78-85`, with the source's own comment `/* Really awful . . . */`). It cannot be
  resumed, and it prints the solver banner three times.
* On a CIDER netlist the shipped `examples/cider/bjt/pz.cir` itself prints
  `Warning: Pole-zero iteration limit reached` (`builds.md` §2.2) — mark PZ *unreliable* there.
* `doc/claude/specs/calculator.md` records `pzbode`/`pzfilter` as "ngspice `pz` output not
  modelled" — so the Calculator is not a destination for this result today.

---

### 2.9 `DISTO` — small-signal distortion, Volterra (index 7)

> **Tooltip:** *harmonic and intermodulation amplitudes of the linearised circuit, versus input
> frequency. Not THD — you divide by the AC response yourself.*

| | |
|---|---|
| card | `.DISTO {DEC\|OCT\|LIN} NP FSTART FSTOP [F2OVERF1]` (`inp2dot.c:146-179`) |
| command | `disto {dec\|oct\|lin} np fstart fstop [f2overf1]` |
| `Plotname:` | harmonic mode: **`DISTORTION - 2nd harmonic`**, **`DISTORTION - 3rd harmonic`**. IM mode: **`DISTORTION - IM: f1+f2`**, **`DISTORTION - IM: f1-f2`**, **`DISTORTION - IM: 2f1-f2`**. Plus **`Distortion Operating Point`** first under `keepopinfo` |
| plots | **2 XOR 3** — see [A-M4] |
| shape | **spectrum**, `Flags: complex`, scale `frequency` |

**Parameters** — `Dparms`, `dsetparm.c:72-80`:

| keyword | flags | meaning | unit | default | illegal value does |
|---|---|---|---|---|---|
| `start` | `SET\|REAL` | start frequency | Hz | none | `<= 0` → `Frequency of 0 is invalid`, `E_PARMVAL`, sets `DstartF1 = 1.0` |
| `stop` | `SET\|REAL` | stop frequency | Hz | none | same, and again writes **`DstartF1`** — the third instance of that copy-paste slip |
| `numsteps` | `SET\|INTEGER` | points | count | none | — |
| `dec`/`oct`/`lin` | `SET\|FLAG` | step type | — | none | **no validation in `dot_disto`, unlike `dot_ac`** |
| `f2overf1` | `SET\|REAL` | ratio of F2 to F1 | — | absent | **setting it also sets `Df2wanted = 1`** — this single flag switches the whole analysis from harmonic to intermodulation mode (`dsetparm.c:60-63`). The help says it "should be < 1" |

**[A-M4] — NEW this pass; it closes the design-of-record's OPEN item M4.** The deck, in full, so a
challenged literal is re-typed and re-run rather than re-opened:

```
* disto IM literals
v1 in 0 dc 0 ac 1 distof1 1 0 distof2 1 0
vcc cc 0 dc 5
rb in b 10k
rc cc c 1k
re e 0 100
q1 c b e qmod
.model qmod npn(is=1e-16 bf=100 vaf=50)
.control
save all
disto dec 2 1k 10k 0.9
foreach p $plots
  setplot $p
  echo "PLOT $p |$curplotname|"
end
.endc
.end
```

Run twice — once as written, once with the trailing `0.9` removed:

```
disto dec 2 1k 10k 0.9   ->  $plots = const disto1 disto2 disto3
   |disto1| -> |DISTORTION - IM: f1+f2|
   |disto2| -> |DISTORTION - IM: f1-f2|
   |disto3| -> |DISTORTION - IM: 2f1-f2|

disto dec 2 1k 10k       ->  $plots = const disto1 disto2
   |disto1| -> |DISTORTION - 2nd harmonic|
   |disto2| -> |DISTORTION - 3rd harmonic|
```

**The two modes are exclusive: 2 plots or 3 plots, never 5.** The three IM literals were until
now read from source only; they are now measured, and they match `distoan.c:563-610` exactly.

**Excitation.** `CKTdisto` modes `D_RHSF1`/`D_RHSF2` (`cktdisto.c:65-166`) walk every V and I
source looking for `distof1`/`distof2`, stamping `rhs = 0.5*mag*cos(pi*phase/180)`. **Phase is
degrees.** Deck syntax is `Vxx n+ n- … DISTOF1 <mag> <phase> DISTOF2 <mag> <phase>` — declared
`IP` (input-only, "unquestionable", `vsrc.c:50-51`), so **the GUI cannot read them back with
`show`**.

**Preconditions.**

* `Df2wanted` set but no source carries a `distof2` → `No source with f2 distortion input`,
  `E_NOF2SRC`, seen as `doAnalyses: No source with f2 distortion input`.
* ⚠ **No source with any `distof*` at all, and no `f2overf1`: DISTO runs to completion and
  produces meaningless zero plots with no warning.** Measured. The GUI must require at least one
  `distof1` source.
* Device support is **narrow**: `DEVdisto` is non-NULL only for `bjt`, `bsim1`, `dio`, `jfet`,
  `mes`, `mos1`, `mos2`, `mos3`, `mos9`, `vdmos`. **Absent: BSIM3, BSIM4, HiSIM, VBIC, HICUM,
  OSDI, XSPICE code models.** On a modern PDK the answer is zeros, silently.

**Point counting differs from AC** (`distoan.c:63-89`): `LINEAR` uses `(stop−start)/(N+1)`
whereas AC uses `/(N−1)`. **For the same `lin N fstart fstop` card, DISTO and AC place points at
different frequencies.** Measured `disto dec 2 1k 100k` → 5 rows.

**Output scaling.** `DkerProc` (`dkerproc.c:13-96`) multiplies the Volterra kernels by a fixed
factor per mode: 2.0 for `D_F1`/`D_F2`/`D_TWOF1`/`D_THRF1`, 4.0 for `D_F1PF2`/`D_F1MF2`, 6.0 for
`D_2F1MF2`. Vector names are the **full `CKTnames()` list**, the same nodes and `#branch` names
as AC.

**Traps.**

* ☠☠ **`disto` SIGSEGVs — rc 139 — whenever its save list resolves to nothing.** This is the
  sharpest defect in the whole surface. `DISTOan` never captures `OUTpBeginPlot`'s return at any
  of its **five** output-plot sites (`distoan.c:516, 540, 563, 584, 606`), unlike `acan.c:169-175`
  which does `error = …; if (error) return(error);`. `beginPlot()` returns `E_NOTFOUND` and
  leaves `acPlot` NULL; the next `OUTattributes(acPlot, …)` dereferences it.
  Reproduced this pass [A-M6] on **both** binaries, from this four-line deck:

  ```
  disto probe deck
  v1 in 0 dc 1 ac 1 distof1 1
  r1 in mid 1k
  r2 mid 0 1k
  .control
  save v(nosuchnode)
  disto dec 2 1k 10k
  op
  .endc
  .end
  ```

  | deck | this build | `/usr/bin/ngspice` 45.2 |
  |---|---|---|
  | `.control` `save v(nosuchnode)` + `disto …` (ASE-L's exact shape) | **rc 139** | **rc 139** |
  | `.control` `disto …` + `op`, **no save at all** | **rc 0** | — |

  ⚠ **CORRECTION, and it narrows a proposed refusal.** `design-C`'s R2 refuses "`disto` enabled
  AND zero saved outputs". `[R-M13]` and this pass both measure that a `.control` deck with
  `disto` and **no save at all returns rc 0**. The true trigger is **a save list that resolves to
  nothing**, and C's rule would refuse a deck that works [crit §C8].
  **M6 is now closed: the bug is upstream, present in released ngspice-45.2, and worth filing
  separately from the GUI mitigation.** `pzan.c:159` and `noisean.c:532` share the unchecked
  pattern; measured, PZ with an empty save list does **not** crash and NOISE's failure is the
  already-documented silent loss of the Integrated Noise plot. **Only DISTO is fatal.**
* **Log-grid asymmetry.** `OUTattributes(…, OUT_SCALE_LOG, …)` is called **only** for the
  2nd-harmonic plot (`distoan.c:519-521`). The 3rd-harmonic plot and all three IM plots get no
  log grid even for a `dec` sweep. Measured: `disto1` shows `grid = xlog`, `disto2` does not.
  The GUI must set the log axis itself.
* **Ctrl-C is ignored** — the `IFpauseTest()` block at `distoan.c:256-261` is commented out.
* **No `DstartF1 <= 0` check at analysis time**, unlike AC's `acan.c:78-81`; the `D_START` setter
  is the only guard.
* **DISTO is not `.four`.** `.disto` is small-signal Volterra; the amplitudes "are not equal to
  HD2 and HD3. To obtain HD2 and HD3, one must divide by the corresponding A.C. values at F1,
  obtained from an .AC line" (`src/ngspice.txt:3047-3051`). The GUI must do
  `mag(disto_vec)/mag(ac_vec)` across two plots to get an HD figure. `.four` is a large-signal
  post-transient DFT and is a different feature (§6.7).

---

### 2.10 `SENS` — DC and AC sensitivity (index 9)

> **Tooltip:** *how much one output moves when each device and model parameter is perturbed.
> ADE-L has no equivalent.*

| | |
|---|---|
| card | `.sens <output> [<filter globs>] [ ac {dec\|lin\|oct} <pts> <flow> <fhigh> \| dc ]` (`inp2dot.c:460-585`) |
| command | `sens <output> [filters] [ac … \| dc]` |
| `Plotname:` | **`Sensitivity Analysis`** — ⚠ **the same literal in both modes** |
| plots | **1** |
| shape | DC: **scalars**, `Flags: real`, 1 row, ~90 vectors. AC: **spectrum**, `Flags: complex`, scale `frequency` |

**Parameters** — `SENSparms`, `senssetp.c:87-104`: `outpos`, `outneg`, `outsrc`, `outname`,
`start`, `stop`, `numsteps`, `dec`, `oct`, `lin`, `dc`. All `IF_SET`; the first seven also
`IF_ASK`.

⚠ **Order matters and the GUI must emit output before mode.** `outpos` also sets
`output_neg = NULL`, `output_volt = 1` **and `step_type = SENS_DC`**; `outsrc` also sets
`output_volt = 0` and `step_type = SENS_DC` (`senssetp.c:23-38`). The output setter *resets the
mode*, and the mode flag then overrides it. That is exactly why the card grammar puts the output
first and the `ac …` clause last.

**Dead parameters — say so rather than offering them.** `SENSsetParam` handles `SENS_DEFTOL` and
`SENS_DEFPERTURB` and `SENSask` answers them, but **neither has a row in `SENSparms[]`**, so no
keyword reaches them; and `job->deftol`/`job->defperturb` are **never read**. The perturbation is
two file-static constants:

```c
static double Sens_Delta     = 0.000001;   /* cktsens.c:24 */
static double Sens_Abs_Delta = 0.000001;   /* cktsens.c:25 */
```

**The perturbation size is hard-coded at 1e-6 and cannot be changed from a deck, a command or an
option.** `pct_flag` (percentage sensitivities) is never read either, and `SENS_DEVDEFTOL`,
`SENS_DEVDEFPERT`, `SENS_TYPE`, `SENS_DEVICE`, `SENS_PARAM`, `SENS_TOL`, `SENS_PERT` and the
whole `DevSenList`/`ModSenList`/`ParamSenList` machinery are declared and unimplemented.

**The filter feature is real, undocumented in `src/ngspice.txt`, and the only thing that makes
`.sens` usable.** Every remaining token before `ac`/`dc` is pushed onto the process-global
`char **Sens_filter` (`cktsens.c:33`, `inp2dot.c:529-565`). The glob (`cktsens.c:37-56`) is
`*` = any run, `?` = exactly one, everything else byte-for-byte and **case-sensitive** against
already-folded names — so write filters lowercase. Example:
`sens v(out) r1:r r2:r m*:vth0 ac dec 10 1k 1meg`. Filtering genuinely saves compute time, not
just output (`cktsens.c:454-455` skips the holes again in the compute loop).

**Output vector naming** (`cktsens.c:222-249`):

| kind | vector name | example |
|---|---|---|
| **model** parameter | `<instance>:<param>` — a **colon** | `r1:tc1`, `d1:is` |
| instance parameter flagged `IF_PRINCIPAL`, first such | `<instance>` | `r1`, `v1` |
| any other instance parameter | `<instance>_<param>` — an **underscore** | `r1_temp`, `d1_area` |

**A three-device deck yields ~90 vectors.** Measured on a deck with `r1 r2 d1 v1`: `r1`,
`r1:af r1:bv_max r1:ef r1:kf r1:lf r1:narrow r1:r r1:rsh r1:short r1:tc1 r1:tc2 r1:tce r1:wf`,
`r1_bv_max r1_dtemp r1_l r1_m r1_scale r1_tc r1_tc2 r1_tce r1_temp r1_w`, the same for `r2`,
41 model parameters for `d1`, and `v1 v1_freq v1_phase v1_pwr v1_z0` — the last four existing
**only because RFSPICE is on**.

**The picker can be computed offline, with no run** [crit §5.6]. `devhelp -csv -type -flags
<device>` prints exactly the four facts `cktsgen.c:193-216`'s eligibility rule needs. The legend
is `device.c:305-345`: `X`=`IF_NONSENSE`, `R`=`IF_REDUNDANT`, `P`=`IF_PRINCIPAL`, `A`=`IF_AC`,
`AA`=`IF_AC_ONLY`, `N`=`IF_NOISE`; `Dir` is `inout`/`in`/`out` for the `IOP`/`IP`/`OP` macro.
The predicate is:

> **`Dir == inout` AND `Type == real` AND the flags contain neither `X` nor `R`** — and, in DC
> mode, neither `A` nor `AA`.

Applied to the shipped `resistor` table it yields exactly the list measured above.

**Traps.**

* ☠ **`sens … ac` under `option klu` SIGSEGVs; `sens … dc` under KLU is safe.** Measured
  `[R-M14]` and `[crit §D3]` on an R–C–R divider:

  | solver | mode | rc | result |
  |---|---|---|---|
  | sparse | dc | 0 | `r1 = -2.50000e-04`, `r2 = 2.499998e-04` |
  | klu | dc | 0 | **identical** |
  | sparse | `ac dec 1 1k 10k` | 0 | runs |
  | **klu** | **`ac dec 1 1k 10k`** | **139** | **SIGSEGV** |

  NOISE and PZ refuse KLU explicitly with a clean `E_UNSUPP`; **SENS's guard at
  `cktsens.c:97-105` is commented out** — that is the bug.
* ☠ **`sens … ac lin` produces a GEOMETRIC sweep.** `inc_freq` (`cktsens.c:828-837`) is
  `if (type != LINEAR) freq *= step_size; else freq += step_size;` — but `LINEAR` here is the
  `#define LINEAR 3` pulled in from `noisedef.h:127`, **not** `SENS_LINEAR`, which is 15.
  `gcc -E` renders the line as `if (type != 3)`, so the test is **always true**. Measured:
  `sens v(out) ac lin 5 1k 5k` swept **1e3, 8e5, 6.4e8, 5.12e11, 4.096e14 Hz** — each × 800.
  `dec`/`oct` are unaffected because their `step_size` is a ratio. **Do not offer `lin` for SENS
  AC.**
* ⚠ **Two SENS rows in one deck are indistinguishable by `Plotname:`.** `[R-M11]`:
  `sens v(mid) dc` and `sens v(mid) ac dec 2 1k 10k` in one deck both report `$curplotname` =
  `Sensitivity Analysis`; `$plots` = `const sens1 sens2 dc2`. Matching on the literal alone does
  not survive, and it does not survive two rows of the same type either. §6.3 is the join that
  does.
* ☠ **Two `.sens` CARDS abort the process**: rc 134, `malloc(): unsorted double linked list
  corrupted`. Two `sens` **commands** in `.control` are fine, rc 0, both run [crit §D5]. The
  cause is almost certainly the process-global `Sens_filter`, freed and rebuilt per card at
  `inp2dot.c:533-534` **while leaking its strings**. This is one more reason the deck route is
  `.control` commands and never cards.
* The algorithm is adjoint/perturbation, one matrix solve per parameter per frequency point
  (`cktsens.c:80-92`). It is slow, and on a large deck it is the most expensive analysis here.

---

### 2.11 `SP` — S-parameters, RFSPICE (index 10 here)

> **Tooltip:** *drive each port in turn and record the scattering, admittance and impedance
> matrices versus frequency.*

| | |
|---|---|
| card | `.sp {DEC\|OCT\|LIN} <numsteps> <fstart> <fstop> [<donoise>]` (`inp2dot.c:718-750`) |
| command | `sp …` — identical. ⚠ but **`nutcp_coms[]` has no `sp` entry**, so in the standalone `nutmeg` binary `sp` is not a command at all |
| `Plotname:` | **`SP Analysis`**; **`AC Operating Point`** first under `keepopinfo` (it reuses the AC string) |
| plots | **1**, or **2** with `keepopinfo` |
| shape | **matrix versus frequency** — complex, scale `frequency` |

**Parameters** — `SPparms`, `spsetp.c:91-99`: `start`, `stop`, `numsteps` (all `SET|ASK|REAL`
or `INTEGER`), `dec`, `oct`, `lin` (`SET|FLAG`), and `donoise` (`SET|FLAG|INTEGER`).
⚠ `SPsetParm` reads `value->iValue` and tests `== 1` **exactly** (`spsetp.c:80-82`), so
**`donoise 2` is treated as false.** Omitting it leaves `SPdoNoise` at its zeroed 0.
`SPnoiseInput`/`SPnoiseOutput` are declared and **never written or read** — there is no way to
name a noise input/output for SP the way `.noise` does.

**Sweep semantics** (`span.c:399-431`) match AC's: `dec`/`oct` are per-decade/per-octave and
require `start > 0`; `lin` is a total and, like AC, `numsteps <= 2` gives `SPfreqDelta = 0` and
one point. Measured: `sp lin 3 1e8 1e9` → 3 rows; `sp oct 2 1e8 8e8` → 7 rows;
`sp dec 100 1 1e6 0` → 601 rows. `.options reltol` feeds `freqTol` and therefore decides whether
the last point lands.

**A port is an independent voltage source carrying `portnum`.** There is no port device and no
port model. The five parameters, all `IOP` (`vsrc.c:31-37`):

| keyword | meaning | unit | default | set where |
|---|---|---|---|---|
| `portnum` | port index, 1-based — **this is what makes it a port** | — | none | — |
| `z0` | port impedance | Ω | **50** | `vsrctemp.c:76-77` |
| `pwr` | port power | W | **0.001** (0 dBm) | `vsrctemp.c:88-89` |
| `freq` | port frequency | Hz | **1e9** | `vsrctemp.c:86-87` |
| `phase` | phase | deg | **0.0** | `vsrctemp.c:90-91` — ⚠ and **it has no effect on anything**: `VSRCportPhaseRad` is written at `vsrctemp.c:96` and read nowhere |

Promotion (`vsrctemp.c:74-82`): `portnum` must be given **and > 0**, and `z0` must be **> 0**; a
`z0 0` or `z0 -50` **silently demotes** the source back to an ordinary source.

**Preconditions, in enforcement order** (`span.c:376-386`, `vsrctemp.c:128-176`):

| condition | what happens |
|---|---|
| **no port at all** | stderr `Error: No RF Port is present, cannot run sp analysis`, then `ERROR: fatal error in ngspice, exit(1)` — **`controlled_exit`, the whole process dies, exit code 1, and the `.control` block never resumes** |
| **only one port** | `Error: Only one RF Port is found, we need at least two!` + the same `controlled_exit` |
| port index > port count | `Fatal error: v2: incorrect port ordering` + `doAnalyses: no such parameter …` + `sp simulation(s) aborted` — this one **returns**, `E_BADPARM` |
| duplicate port index | `Fatal error: v1: duplicate port Index` + the same |
| DC operating point fails | stdout `\nAC operating point failed -\n`, `CKTncDump(ckt)` prints the non-converged nodes |

**So port numbers must be a contiguous 1..N with no gaps and no repeats**, and the "fewer than
two ports" case is **fatal to the process**, not to the analysis.

**[R-M5] — and it turns a dead end into a feature.** On two *ordinary* V sources that declare no
port in the netlist:

```
alter v1 portnum = 1 / alter v1 z0 = 50 / alter v2 portnum = 2 / alter v2 z0 = 50
sp lin 3 100meg 1g
```
→ rc 0, `$curplotname` = `SP Analysis`, `s_1_1[1] = 1.674674e-05,-2.89363e-03`.
**Ports can be assigned at run time from the `.control` block, with nothing written to the
schematic.** ⚠ **CORRECTION** to `design-B`, which made `two_ports` a `fatal` precondition with
no route to satisfy it [crit §C11].

⚠ **`portnum` cannot be read back.** `vsrc.c:32` declares it `IF_INTEGER`; `vsrcask.c:160-162`
answers with `value->rValue`; the caller reads `iValue` from the same union and always gets 0.
Measured: `show v1 : all` reports `portnum 0` for a source declared `portnum 1`, and
`print @v1[portnum]` gives `0.000000e+00`. `z0`, `pwr`, `freq`, `phase` read back correctly.
**Port indices are GUI-owned state; a netlist scan can only *add* sources that already declare
one.**

⚠ **A port is not electrically neutral outside SP** — the single largest trap in the feature.
`vsrcset.c:53-79` creates an extra internal node `<vsrcname>#res` per port and rewires the
branch equation through it; `vsrcload.c:51-64` (DC/transient) and `vsrcacld.c:150-157` (AC) stamp
`g0 = 1/z0` across it. Measured on a port `V1 in 0 dc 1 z0 50` into `R1 in 0 50` beside a plain
`V2 x 0 dc 1` into `R2 x 0 50`:

```
v(in) = 5.000000e-01        <- the port
v(x)  = 1.000000e+00        <- the ordinary source
```

**Adding `portnum` to a source inserts a `z0` series resistance that changes every DC, AC and
transient result.** In transient, a port with `pwr` or `freq` given becomes a `PORT` waveform
(`vsrcload.c:453-459`), overriding whatever else it carried.

**Output vectors**, in this order after the ordinary node/branch vectors (`span.c:501-551`):
`S_<i>_<j>`, `Y_<i>_<j>`, `Z_<i>_<j>` for all i,j = 1..N (row = destination port, column =
source port); then **only if `donoise 1`** `Cy_<i>_<j>`; then **only if `donoise 1` AND N == 2**
`NF`, `SOpt`, `NFmin`, `Rn` in exactly that order. Types are assigned by name **conditional on
the plot typename starting with `sp`** (`outitf.c:1048-1064`) — `S_*` → `s-param`, `Y_*` →
`admittance`, `Z_*` → `impedance`, `NF`/`NFmin` → `decibel`, `Rn` → `impedance`, `SOpt` →
`notype`, `Cy_*` → `current`.

**`donoise 1` limits a GUI must surface** (`span.c:74-178`): the noise parameters exist **only
for exactly two ports**; `Y0` is taken from **port 1 only**, so a 2-port with `z0 75` on port 1
and `z0 50` on port 2 gets its `NF`/`SOpt` referred to 75 Ω; there are **no per-device noise
contribution vectors** (`NOISE_ADD_OUTVAR` is redefined under RFSPICE to merely increment a
counter), and **no `onoise_spectrum`/`onoise_total` at all**. Units: `NF`/`NFmin` are **dB**,
`Rn` is **ohms**, `SOpt` is a dimensionless complex reflection coefficient, `Cy_i_j` is A²/Hz
un-normalised. Measured smoke test on a resistive 2-port: `NF = 3.405061` dB,
`NFmin = 1.938200` dB, flat over frequency.

**Export.** `wrs2p <file>` writes Touchstone v1 through `spar_write()` (`rawfile.c:934-1022`):
fixed format `# Hz S RI R <Rbase>`, one row of
`freq ReS11 ImS11 ReS21 ImS21 ReS12 ImS12 ReS22 ImS22`, default precision **6** (different from
`raw_write`'s 15), and it prints `Note: only 2 ports 1 and 2 are supported by wrs2p` on stderr
every time. It needs an `Rbase` vector; the workaround nobody promoted to a recommendation is
`.csparam Rbase=50` (`examples/sp/file.cir:24`).

Also: if `ckt->CKTvarHertz` is set (the `hertz` variable used in a B-source), SP **re-solves the
operating point at every frequency point** (`span.c:664-708`).

⚠ Two files that look relevant and are not: `src/spicelib/analysis/cktspnoise.c` and
`noisesp.c` are **entirely dead** — their bodies are inside `#ifdef RFSPICE_` with a trailing
underscore and the comment `/* not used, CKTspnoise is in span.c */`. They still compile, to
nothing.

---

### 2.12 `PSS` — periodic steady state (absent here; index 10 when built)

> **Tooltip:** *find the exact period and one period of the steady-state waveform of an
> oscillator, plus its harmonic magnitudes. **Experimental.***

| | |
|---|---|
| gate | `--enable-pss` (`WITH_PSS`). **Absent in this build**; present in `/usr/bin/ngspice` 45.2 [A-M7] |
| card | `.pss <fguess> <stabtime> <oscnode> <points> <harmonics> <sc_iter> <steady_coeff> [uic]` (`inp2dot.c:653-711`) — ⚠ the source comment at `inp2dot.c:667` says `/* .pss Fguess StabTime OscNode <UIC>*/` and is **stale; ignore it** |
| command | `pss …` — identical |
| `Plotname:` | **`Time Domain Periodic Steady State Analysis`** and **`Frequency Domain Periodic Steady State Analysis`** |
| plots | **2 × (1 + relaunches)** — not 2. See below |
| shape | TD = **sweep** (scale `time`); FD = **harmonic list** (scale `frequency`, magnitudes only) |

**Parameters** — `PSSparms`, `psssetp.c:57-66`. **There are no defaults**; `CKTnewAnal` `tmalloc`s
the job, so every field starts at 0 and the card must supply all seven positionally.

| # | keyword | flags | meaning | unit | refuse | why |
|---|---|---|---|---|---|---|
| 1 | `fguess` | `SET\|REAL` | guessed fundamental | Hz | **`<= 0`**; and **any value above the user's own estimate** | 0 → rc-1 `Timestep too small` abort. Measured: a guess **2.1× high aborts**; **19× low converged**. Bias the default LOW |
| 2 | `stabtime` | `SET\|REAL` | settling time before shooting starts | s | — | 0 is legal and converged |
| 3 | `oscnode` | `SET\|STRING` (⚠ stored as `nValue`) | oscillation node | node | nothing | **it steers nothing** — assigned at `dcpss.c:126` and never read. The parser demands a token, so the field must exist; label it *(not used by the solver)* |
| 4 | `points` | `SET\|INTEGER` | time points in the reported period | count | **`< 8`** | 2 → `No. of Data Rows : 0` plus a stderr abort plus **3** pss plots; 0 → a 1-row plot. Every shipped example uses 1024/256/50 |
| 5 | `harmonics` | `SET\|INTEGER` | harmonics **including DC** | count | ☠ **`< 2`** | **0 → SIGSEGV with no message at all; 1 → infinite recursion at 199 % CPU, killed at 240 s.** `dcpss.c:979-996` indexes `pssResults` and `pssfreqs` out of bounds before the correcting loop can run, then re-enters `DCpss(ckt,1)` with no depth limit |
| 6 | `sc_iter` | `SET\|INTEGER` | shooting-cycle iteration limit | count | **`> 1023`** and **`< 5`** | `HISTORY` is fixed at 1024 (`dcpss.c:53`); 0 and 1 both gave `Convergence not reached` on a circuit that converges at 5. It is also the dominant **cost** knob — 10 → 30 tripled the runtime |
| 7 | `steady_coeff` | ⚠ declared `SET\|INTEGER`, **read as `rValue`** | convergence coefficient | — | **`< 1e-6`** | 1e-9 produced a **false `Convergence reached` with a 4.5 %-wrong answer** and a stderr storm of `Panic: breakpoint in the past - HELP!` |
| 8 | `uic` | `SET\|INTEGER` | use initial conditions | — | — | omitting it gave `Convergence not reached` on a deck that converges with it |

**`PSSinit` overrides transient options** (`pssinit.c:148-169`): `CKTstep = 0.01/fguess`,
`CKTinitTime = 0`, `CKTmaxStep = 0.5/fguess`, `CKTdelmin = 1e-9 × CKTmaxStep`,
`CKTmode = PSSmode`. **So `.options tstep`/`tmax`/`delmin` are ignored by PSS** — a shared
"transient settings" pane must not appear to apply to it. Only `reltol`, `abstol`, `vntol` and
`trtol` still matter.

**☠ Exit status is not a success signal, and it is worse than that.** Measured across sixteen
argument perturbations (`builds.md` §1.4): status moves only for the *hard* aborts (`fguess` too
high, `fguess = 0`) and the crash. The ordinary give-up returns **rc 0**, prints **both plots
full of plausible data**, and differs from success by one word on stdout. The two literals, both
`fprintf(stdout, …)` from `dcpss.c`:

```
Convergence reached. Final circuit time is %1.10g seconds (iteration n° %d) and predicted fundamental frequency is %s Hz
Convergence not reached. However the most near convergence iteration has predicted (iteration %d) a fundamental frequency of %s Hz
```

**A GUI must scrape stdout for these and must refuse to present a PSS result without one.**

**Output shape, measured** (`builds.md` §1.3):

* the TD plot has **`points + 1`** rows (1024 → 1025); the FD plot has exactly **`harmonics`**
  rows, DC included (10 → 10);
* ⚠ **the TD time axis is absolute circuit time, not 0…T.** First `time` = `1.144088832e-08`,
  last = `1.170692402e-08`, span = `2.66036e-10` s = exactly 1/`3.758894068e9`. **A GUI plotting
  "one period" must subtract the first sample itself**;
* the FD frequency axis is `0, f0, 2f0, …, (harmonics−1)·f0`; **values are magnitudes only**, no
  phase, no THD; `Mag[0]` is the DC mean;
* ⚠ **every FD variable line in the rawfile ends `plot=1`** (from `OUTattributes(…, PLOT_COMB,
  …)`), and the TD ones do not. That is a free, machine-readable "draw me as a stem plot" flag
  and **no other ngspice analysis sets it**;
* vector names are the ordinary `CKTnames` set. There is no PSS-specific vector;
* ⚠ **the plot count is not 2.** The recursive relaunch at `dcpss.c:988-996` fires whenever the
  predicted fundamental is judged wrong, printing
  `The predicted fundamental frequency is incorrect.\nRelaunching the analysis...`. Measured:
  `sc_iter = 0` produced `const pss1 pss2 pss3 pss4`; `points = 2` produced three pss plots.
  **Take the LAST TD and the LAST FD plot by `Plotname:` match**, never `pss1`/`pss2`.

⚠ **CORRECTIONS to `an-rf-pss.md` §3**, from the build that actually ran it (`builds.md` §1.7):
(1) the per-iteration `Shooting cycle iteration number: …` line is inside `#ifdef PSSDEBUG`,
which is commented out at `dcpss.c:55` and defined nowhere — what *does* print per iteration on
stdout is `In shooting...` once, then a repeating triple
`Updated guessed frequency: %s Hz.` / `Next shooting evaluation time is … and current time is …`
/ `----------------`, which is the only PSS progress feed on the `-b` route;
(2) **a bad `oscnode` does not crash** — the parser's `INPtermInsertRef` creates the node, so the
predicted NULL deref at `dcpss.c:126` is unreachable; (3) **`fguess = 0` is not a divide-by-zero**
but a clean `E_TIMESTEP` abort.

**How well does it work?** Honestly: **it solves the small autonomous oscillators it ships with
and does not reliably solve a 19-stage ring.** Measured (`builds.md` §1.2, §1.8): the 3-stage
CMOS ring in **0.91 s** and Van der Pol in **0.41 s**, both `Convergence reached`, both within
~1 % of their documented f0; but a 19-stage ring whose true f0 an FFT puts at
**6.49946e+08 Hz** gave four `Convergence not reached` runs reporting between **660.7 MHz and
890.1 MHz** depending on arguments alone. The NEWS file calls PSS "still very experimental" and
that is the right label for the panel.

⚠ **`-r` and PSS.** Measured (`builds.md` §1.9), and it generalises beyond PSS:

| deck shape | `-b -r file.raw` writes |
|---|---|
| `.pss <args>` as a **dot card** | **yes** — both plots |
| `pss <args>` as a **`.control` command** | **no file at all** |
| `.tran` card, with or without `.control run` | yes |
| `tran` as a **`.control` command** | **no file at all** |

> **`-r` captures analyses dispatched from dot cards. An analysis issued as a `.control` command
> produces no rawfile from `-r` and must be followed by an explicit `write`.**

---

### 2.13 Where the card and the command differ — all seven

The grammar is identical (§2, rule 1). The behaviour is not, and every row here is verified.

| # | difference | card | `.control` command |
|---|---|---|---|
| 1 | **error blast radius** | a bad card **kills the netlist** and the run | a bad command kills **only itself**; the session continues and later commands still run |
| 2 | **error text** | carries a line number: `Error: %sin   %s` then `%s simulation(s) aborted` | same text, **no line number** (`deck.linenum = 0`) |
| 3 | **task lifetime** | the deck's `ci_defTask`; still runs on a later bare `run` | each command **replaces `ci_specTask`**; `ci_defTask` is untouched |
| 4 | **`{}` substitution** | numparam expands it | ⚠ **not substituted** — control lines are removed before `inp_subcktexpand()` runs. `tran {tstop/200} {tstop}` fails with `TSTEP is invalid…`. **Emit `.csparam` + `$&name`, or plain literals** |
| 5 | **`.op` printing** | prints the node/source table plus `showmod` and `show` | prints only `No. of Data Rows : 1` |
| 6 | **`-r` capture** | captured (§2.12) | **not captured**; needs an explicit `write` |
| 7 | **`.options oldlimit`** | reaches `TSKfixLimit` | ☠ **silently dropped** — §3.3 |

Plus three deck-level facts that only the card route can hit:

* **A bare `run` dispatches EVERY analysis card in `analInfo[]` order regardless of type.**
  Measured [crit §5.5]: a deck with `.noise .tf .sens .disto` and a `.control run` executed TF,
  NOISE and SENS. `if_run()`'s `run` arm hands the whole `ci_defTask` to `doAnalyses`
  (`spiceif.c:373-386`), which loops the entire table (`cktdojob.c:176-213`) with nothing
  filtering by type. Manual §13.5.68's list of only `.ac/.op/.tran/.dc` is **incomplete**.
* **Execution order is by `analInfo[]` index, not deck order**, and duplicates run last-first
  because `CKTnewAnal` pushes onto the head of the job list (`cktnewan.c:33`). Measured on one
  deck with seven cards, the rawfile order was **AC, DC, OP, TRAN, TF, DISTO, NOISE**.
* **A deck with both a `.control` analysis and an analysis card runs the analysis twice** in
  `-b` (`doc/codex/issues/0069`).

**Consequence, and it is unanimous across all three designs:** emit `.control` **commands, one
analysis at a time**. That route avoids the reordering, the `.op`/`.tf` save-scope starvation,
the `-b` double run, the two-`.sens` SIGABRT and one of the two routes into the DISTO SIGSEGV.

---

## 3. The two option catalogues

They are **two**, and that is a measured fact, not a taxonomy choice:

> `comm -12 <(cp_getvar names) <(OPTtbl names)` is **empty** (`hidden-vars.md` §2).

No name is in both, so a GUI never has to arbitrate which mechanism wins for a given name.
`cshunt` (OPTtbl) and `cshunt_value` (`cp_getvar`) are two halves of one feature under two
different names; `temp` and `scale` look like a clash and are not.

### 3.1 Catalogue A — `OPTtbl`, the `.options` keywords

⚠ **CORRECTION — the count is 98, not "~86".** Counted this pass [A-M8] over
`cktsopt.c:264-385`:

| | |
|---|---|
| rows in the table | **98**, all distinct keywords |
| inside `#ifdef XSPICE` | **9** — and XSPICE is ON here, so **all 98 compile in this build** |
| carrying `IF_SET` (settable) | **57** |
| carrying `IF_ASK` (readable) | **29** |
| carrying **both** | **2** (`tnom`, `temp`) |
| carrying **neither** | **14** — `itl3 itl5 acct list nomod nopage node opts numdgt cptime limtim limpts lvlcod lvltim` |

57 + 29 − 2 = 84 with at least one flag; 84 + 14 = 98. ✓

⚠ **CORRECTION TO THIS CORRECTION.** An earlier draft explained "86" as *"57 + 29, which
double-counts `temp`/`tnom`"*. That reconstruction is wrong. `hidden-vars.md` §2 says the table
"has exactly **86** rows — 57 `IF_SET`, **27** `IF_ASK`, plus `itl3` and `itl5` which are
neither", and 57 + 27 + 2 = 86 exactly: it counted `IF_ASK`-**only** and named two strays, and
its arithmetic is right about **that** set. What it missed is the other twelve neither-flag
rows. **Both numbers are right about different questions.** Quote **98** for the table and
**57** for the settable floor; do not "fix" `hidden-vars.md`, cite its scope. `an-core.md`
§2.2's table is the complete one and its line anchors are right.

**The XSPICE-gated block** (`cktsopt.c:265-277`):

| keyword | flags | meaning | default | effect / trap |
|---|---|---|---|---|
| `maxopalter` | SET\|INT | max analog/event alternations in DCOP | — | `evt->limits.max_op_alternations` |
| `maxevtiter` | SET\|INT | max event iterations per analysis point | — | `evt->limits.max_event_passes` |
| `noopalter` | SET\|FLAG | no analog/event alternation in DCOP | off | |
| `ramptime` | SET\|REAL | "Transient analysis supply ramping time" | 0 | ☠ **INERT — see §3.3** |
| `convlimit` | SET\|FLAG | convergence assistance on code models | off | |
| `convstep` | SET\|REAL | fractional step allowed by code-model inputs between iterations | 0 | |
| `convabsstep` | SET\|REAL | absolute step, same | 0 | |
| `autopartial` | SET\|FLAG | auto-partial computation for all models | off | |
| `rshunt` | SET\|REAL | shunt resistance from analog nodes to ground | off | `<= 1e-30` → `WARNING - Rshunt option too small.  Ignored.`; without XSPICE the arm prints `WARNING - Option Rshunt available only with XSPICE enabled.` |

**The always-present block** (`cktsopt.c:278-385`), grouped as a GUI would group them.
Defaults are from `CKTnewTask()`, `cktntask.c:92-145`.

*Tolerances* — `reltol` 1e-3, `abstol` 1e-12, `vntol` 1e-6, `chgtol` 1e-14, `trtol` **7.**
(forced to 1 with XSPICE A-devices), `pivtol` 1e-13, `pivrel` 1e-3, `ltereltol` 1e-3,
`lteabstol` 1e-6, `ltetrtol` **500.**, `epsmin` 1e-28, `absdv` 0.5, `reldv` 2.0. All
`SET|REAL`.

*Iteration limits* — `itl1` (DC) **100**, `itl2` (DC transfer curve) **50**, `itl4` (upper
transient) **10**, `itl6`/`srcsteps` **1**, `gminsteps` **1**, `bypass` 0, `maxopalter`,
`maxevtiter`. ☠ **`itl1`/`itl2`/`itl4` are floored at 100 — §3.3.** `itl3` and `itl5` are
recognised and **unimplemented**: `case OPT_ITL3: break;` at `cktsopt.c:83`, `:88`, and both are
in `unsupported[]` so the `option` command prints
`Warning: option itl3 is currently unsupported.`

*Timestep and integration* — `method` (`SET|STRING`; `strncmp(sValue,"trap",4)` → TRAPEZOIDAL,
`strcmp(sValue,"gear")` → GEAR, **anything else returns `E_METHOD`**, default TRAPEZOIDAL);
`maxord` (`SET|INT`, default **2**, **clamped**: `<1 → 1` with `Warning -- Option maxord < 1 not
allowed in ngspice`, `>6 → 6` with a warning); `xmu` (default **0.5**; `cktntask.c:113-118`
documents 0 = Backward Euler, 0.5 = trapezoidal, 0.49 = damps ringing); `minbreak`
(**not initialised** — zero from `tmalloc`, derived per run, §2.4); `trytocompact` (LTRA lines,
off); `newtrunc` (**inert here**, needs `PREDICTOR`, §3.3).

*Convergence aids* — `gmin` 1e-12, `gshunt` 0, `cshunt` **−1**, `gminfactor` **10**, `noopiter`
(go straight to gmin stepping, off), `noopac` (skip the OP in AC **only if `CKTisLinear`**),
`nodedamping` (off; when on, `NIiter` damps steps > 10 V, `niiter.c:300-324`), `copynodesets`
(off), `oldlimit` (**inert on the `.control` route**, §3.3), `rshunt`, `convlimit`/`convstep`/
`convabsstep`.

*Device defaults* — `defm` 1, `defl` 1e-4, `defw` 1e-4, `defad` 0, `defas` 0, `badmos3` (off),
`indverbosity` **2** (full coupling check, full verbosity).
☠ **`defas` is broken**: `cktsopt.c:111-113` reads

```c
    case OPT_DEFAS:
        task->TSKdefaultMosAD = val->rValue;
```

— it writes the **drain** area. Re-read this pass; still there. `.options defas=…` silently sets
`defad`. Do not promise `defas` works.

*Temperature* — `temp` and `tnom`, both `SET|ASK|REAL`, both default **300.15 K = 27 °C**, both
**stored in kelvin** (`TSKtemp = rValue + CONSTCtoK`) and **read back in °C**
(`cktacct.c:170`).

*Solver* — `sparse` and `klu`, both `#ifdef KLU` (on here). ⚠ **Note the inverted sense**:
`sparse` sets `TSKkluMODE = (iValue == 0)`, `klu` sets `TSKkluMODE = (iValue != 0)`. Runtime
default is **SPARSE 1.3**. ☠ `klu_memgrow_factor` is **broken**, `cktsopt.c:186-188`, re-read
this pass:

```c
    case OPT_KLU_MEMGROW_FACTOR:
        task->TSKkluMemGrowFactor = (val->rValue == 1.2);
```

The row is declared `IF_SET|IF_REAL` and the field is a `double`, so the option stores **1.0 if
you write exactly 1.2 and 0.0 for every other value** — including every value a user would want.
The `CKTnewTask` default is a correct 1.2, so **the option can only make things worse. Do not
offer this field.**

*Output/behaviour flags* — `keepopinfo` (record the OP for each small-signal analysis, off —
this is the one that adds a plot, §6.2), `noopac`.

*The nine that never reach `CKTsetOpt` at all* — `acct`, `list`, `nomod`, `nopage`, `node`,
`opts` have `id == 0` and are intercepted front-end-side by `if_option()`
(`spiceif.c:472-499`); `numdgt` and `cptime` are ignored by the simulator; `limtim`, `limpts`,
`lvlcod` are in `obsolete[]` (`Warning: option %s is obsolete.`) and `lvltim` in
`unsupported[]`.

*The 27 read-only `IF_ASK` statistics* — this is the `rusage` surface, and it is free GUI
material for a "why was that slow" strip: `totiter traniter equations originalnz fillinnz
totalnz tranpoints accept rejected time loadtime synctime reordertime factortime solvetime
trantime tranloadtime transynctime tranfactortime transolvetime trantrunctime trancuriters
actime acloadtime acsynctime acfactortime acsolvetime`. `options.md` Table B calls
`accept`/`rejected` "the single best convergence-health metric".

⚠ **CORRECTION — Unknown keywords produce NO message on either route ASE-L can take.** An
earlier draft of this paragraph said `.options bogus=1` → `Error: unknown option bogus -
ignored` on `cp_err`. That branch exists in source (`inpdoopt.c:74-78`) and **neither route
measured reaches it**. Both probes, this pass, on `build-ver_50`:

```
* route 1 -- ASE-L's own deck shape, analyses inside .control
v1 a 0 dc 1
r1 a 0 1k
.options bogusdot=1
.control
option bogusopt=3
op
set
.endc
.end
   ->  no message of any kind. The trailing bare `set` lists:
         + bogusdot  1
           bogusopt  3
       i.e. BOTH names were silently invented as variables.

* route 2 -- a dot-card analysis, no .control at all
v1 a 0 dc 1
r1 a 0 1k
.options frobnicate
.options bogus=1
.op
.end
   ->  a completely clean run. rc 0, no warning, no error.
```

Why: a top-level `.options` card is consumed by `inp_dodeck()`'s `ci_vars` loop, which calls
`if_option()` per variable (`inp.c:1605-1620`), and `if_option()` **returns 0 silently** for a
name that is in neither `OPTtbl` nor `unsupported[]`/`obsolete[]` (`spiceif.c:510-524`). The
`Error: unknown option %s - ignored` branch lives in `INPdoOpts()` (`inpdoopt.c:69-78`), which
this path does not reach.

**The operational rule.** *There is no error channel for a misspelled option on ASE-L's route.*
§8.1's requested-vs-effective read-back is the **only** way the GUI learns that a name did not
land, and it is therefore **mandatory, not a nicety** — which is what `PLAN.md`'s Stage 7f
says. (A recognised keyword with `(dataType & IF_UNIMP_MASK) == 0` does still give
` Warning: %s not yet implemented - ignored `; that is a different, narrower case.)

### 3.1.1 ⚠ Two different paths reach the options, and they accept different keywords

This is architecturally important and easy to get wrong.

**Path A — the `.options` card, parsed twice.** `inp_dodeck()` re-lexes every `.options` line as
if it were a `set` command and stores the results in `ft_curckt->ci_vars` (`inp.c:1376-1397`),
feeding each to `if_option()`; **separately**, `INP2dot()` → `dot_options()` → `INPdoOpts()`
(`inpdoopt.c:20-79`) writes into `task->taskOptions` via `setAnalysisParm`.

**Path B — the `option` / `options` shell command** (`commands.c:140-147`, both names bound to
`com_option`) goes through `cp_usrset()` → `if_option()`, which first intercepts nine front-end
names (`acct noacct noinit norefvalue list node opts nopage nomod`), then consults `OPTtbl`,
then checks two hard-coded rejection lists — `unsupported[] = {"itl3","itl5","lvltim","maxord",
"method"}` and `obsolete[] = {"limpts","limtim","lvlcod"}`.

> ⚠ **CORRECTION — `maxord` and `method` are NOT rejected from the `option` command.** An
> earlier reading of this file had them rejected. They are not: the `unsupported[]` and
> `obsolete[]` loops sit **inside** `if (!if_parm || !(if_parm->dataType & IF_SET))`
> (`spiceif.c:510`), and both keywords carry `IF_SET` — `cktsopt.c:313-314` declares
> `{ "method", OPT_METHOD, IF_SET|IF_STRING, … }` and
> `{ "maxord", OPT_MAXORD, IF_SET|IF_INTEGER, … }` — so neither ever reaches the check.
> Measured this pass: a `.control` running `option method=gear`, then `op`, then a bare
> `option`, printed `Integration Method = GEAR` and `MaxOrder = 2`, **with no warning**. The
> list at `spiceif.c:446-453` is stale **in the source**, not in the behaviour.
> `evidence/options.md`'s Table-A footnote already said so, and §8.1 of this appendix quotes
> the same measurement. **Both doors work; either spelling is fine.** Do not split the option
> emitter for these two keywords, and do not except them from `PLAN.md` Stage 7e's
> emit-then-restore path.

Type coercion in `if_option()` (`spiceif.c:525-560`): REAL accepts CP_REAL or CP_NUM; INTEGER
accepts CP_NUM or rounds a CP_REAL (`floor(x+0.5)`); STRING needs CP_STRING; FLAG accepts CP_BOOL
or CP_NUM. Wrong type → `badtype`. With no circuit loaded:
`Simulation parameter "%s" can't be set until a circuit has been loaded.`

### 3.2 Catalogue B — the 163 `cp_getvar` variables

`hidden-vars.md` counted **163 distinct names at 304 call sites across 48 files**, using
`grep -a` — plain `grep` under-reports because `src/maths/cmaths/cmath4.c` is ISO-8859 text and
GNU grep classifies it binary, silently dropping `dpolydegree` and `mtimeavgwindow`.

*Cross-check this pass:* a literal-string re-grep found **162** names. The 163rd is the
**computed** family `auto_bridge_<family>_<type>_<dir>`, built with `snprintf` at
`evtcheck_nodes.c:524, 569, 742, 761` — no literal-string grep can see it. The two counts
reconcile exactly; **use 163**.

**Not one of them is an `OPTtbl` keyword**, and **none of them can be discovered at runtime** —
there is no way to ask ngspice a variable's `CP_` class. A variable omitted from the GUI's table
is a variable the GUI cannot spell safely.

**Phase vocabulary**, in execution order (`hidden-vars.md` §2):

| phase | when | can `.options` reach it? |
|---|---|---|
| **L1** netlist-read | inside `inp_readall()` | **no** |
| **L2** deck-processing | `inp_spsource()`, before `ci_vars` exists | **no** |
| **L3** circuit-load | `inp_dodeck()` at/after `inp.c:1376` | yes |
| **S** setup | `CKTsetup()`/`DEVsetup()`, first `run` | yes |
| **A** analysis-setup | once per analysis | yes |
| **I** inner loop | per iteration | yes |
| **O** output | `beginPlot`/rawfile write | yes |
| **C** command | only when that command runs | yes |

**Group R — the 21 that change numerical results.** These are the ones that need a ⚠ badge:

`scale` (multiplies every *geometric* device parameter of R, C, DIO and every MOS family, and
drives model binning — measured **not** to scale a resistor's `resistance`), `wnflag`
(MOS `W` total vs per-finger; `CP_NUM`), `diode_cj0` and `diode_rser` (`CP_REAL`; override every
diode model that omitted `cj0`/`rs` — **only under `ngbehavior=ps` or `lt`**; ⚠ the critique
reported them unconditional, and `hidden-vars.md` corrects that), `ng_nomodcheck` (skips the
BSIM3/BSIM4 sanity clamps), **`sqrnoise`** (§2.6), **`notrnoise`** (§5.4), `noisyxspice`
(the only per-iteration `cp_getvar` in the tree), **`autostop`** (ends a transient as soon as
every `.meas` is satisfied — **it changes `tstop`, so it changes the data**; auto-disabled with a
warning if any `.meas` uses `max/min/avg/rms/integ`), **`nostepsizelimit`** (§2.4), `dyngmin`,
`xtrtol`, `topo_reduce` (prunes dangling degree-1 R/C leaves and **names the offending element**
in its console message — a ready-made "simulation failed → try this" fix), `num_threads`
(timing only; **`spinit` sets 8**), `cshunt_value`, `enable_noisy_r`, `soacheck`, **`warn`** and
`maxwarns` (SOA checking; diagnostics, not solution), `auto_bridge` and
`no_auto_bridge_family` (topology).

Plus the back-door that is not a variable and reads every variable:

> **`var(<name>)` inside a `.param` or `{}` expression** — `xpressn.c:1134`,
> `cp_getvar(vec_name, CP_REAL, …)`. Measured: `set myres=4700` in `.spiceinit` plus
> `.param rv = 'var(myres)'` and `r1 in 0 {rv}` gives `@r1[resistance] = 4.700000e+03`.
> **This is how a GUI injects arbitrary named scalars into an unmodified netlist** (§4.2).
> Two cautions, both measured: `var(nosuchvar)` returns **0 silently** (the resistor fell to its
> 1e-12 minimum with no message), and the read is L1/L2, so `.control set myres=…` and
> `.options myres=…` **both fail silently**.

**Group G — the 11 that decide whether a run happens or produces output at all:** `noparse`,
`nosubckt`, `no_mem_check`, **`interp`** (§2.4 — this is the only uniform-output-grid switch),
`filetype`, **`appendwrite`**, `plainwrite` (skips expression parsing in `write` **and therefore
skips `checkvalid()`** — the escape hatch from §3.4's abort), `noquotesinoutput`, `keep#branch`,
`nopadding`, `casemodewrite`.

**Group N — netlist rewriting and parse policy**, all L1/L2/L3 and therefore all in §3.2.1:
`casemode`, `ngbehavior`, `no_auto_gnd`, `no_auto_braces`, `addcontrol`, `rawfile`,
`sourcepath`, `mingwpath`, `substart`/`subend`/`subinvoke`/`modelcard`/`modelline`, `statlocal`,
`renumber`, `brief`, `controlswait`, `probe_is_given`, `probe_alli_given`, `probe_alli_nox`,
`no_spinit`, `no_spiceinit`, `interactive`, `editor`, and the ten PSpice `U`-device knobs
`ps_*`.

**Group X — post-processing, measurement and control language:** `measoutfile`, `nfreqs` (10),
`nperiods` (1), `fourgridsize` (200), `fournosave` (**turning it on removes the `fourierMN` and
`thdMN` vectors §6.7 depends on**), `polydegree` (1), `dpolydegree` (2), `mtimeavgwindow`,
`specwindow` (`none rectangular bartlet hanning hamming blackman gaussian flattop`),
`specwindoworder`, `spectrace`, `diff_abstol`/`diff_reltol`/`diff_vntol`, `sanelet`, `plainlet`,
`csnumprec`, `nosort`, `altshow`, `level`, `askquit`, `histsubst`, `moremode`, `silent_fileio`,
**`rndseed`** (§4.4), **`sim_status`**, `nosighandling`, `addescape`, `spicepath`, `rhost`,
`rprogram`, `remote_shell`.

**Group D — 62 pure-presentation variables** (terminal width/height, X11 and Windows fonts and
brushes, graph frame, gnuplot/pyplot, hardcopy, help browser). None can change a number. They are
listed in `hidden-vars.md` §2.5 and a GUI has no reason to surface any of them.

⚠ **Two names the options dossier missed and that belong in the catalogue with a "this alters
your models" warning:** `diode_cj0` and `diode_rser` (§ above), plus `rsdiode`
[crit §1.3]. They are ordinary mechanism-C variables read at `diosetup.c:89`, `:241`, `:245`.

### 3.2.1 The 26 that must be emitted BEFORE the deck is read

`.options x` and a `set x` inside `.control` both do **nothing, silently**, for every name here.
The boundary is one line — `inp_dodeck()` builds `ci_vars` from the deck's `.options` cards at
`inp.c:1376`, and everything read earlier is out of reach.

**L1 — inside `inp_readall()`:**

| variable | `CP_` type | reachable by | NOT reachable by |
|---|---|---|---|
| `casemode` | STRING | spinit, `.spiceinit`, `-D` | `.options`, `.control` |
| `ngbehavior` | STRING | spinit, `.spiceinit`, `-D` | " |
| `sourcepath` | **LIST** | spinit, `.spiceinit` | **`-D`**, `.options`, `.control` |
| `mingwpath` | BOOL | spinit, `.spiceinit`, `-D` | " |
| `no_auto_gnd` | BOOL | " | " |
| `no_auto_braces` | BOOL | " | " |
| `addcontrol` | BOOL | " | " |
| `rawfile` | STRING | spinit, `.spiceinit`, `-D`, **`-r`** | " |
| `soacheck` | BOOL | " | " |
| `enable_noisy_r` | BOOL | " | " |
| `probe_alli_nox` | BOOL | " | " |
| `debug-out-short` | BOOL | " | " |
| **`wnflag`** | **NUM** | spinit, `.spiceinit` **only** | **`-D`**, `.options`, `.control` |
| `ps_global_tmodels` `ps_global_hash_table` `ps_tpz_delays` `ps_use_mntymx` `ps_ports_and_pins` `ps_udevice_msgs` `ps_udevice_exit` `ps_scan_gates_optimize` `ps_with_inverters` `ps_with_tri_inverters` | **NUM** ×10 | spinit, `.spiceinit` **only** | **`-D`**, `.options`, `.control` |
| *any name used as* `var(<name>)` | **REAL** | spinit, `.spiceinit` **only** | **`-D`**, `.options`, `.control` |

**L2 — `inp_spsource()`, before `ci_vars` exists:** `nosubckt`, `statlocal`, `controlswait`,
`substart`/`subend`/`subinvoke`/`modelcard`/`modelline`, `noparse` (`inp.c:1372`, one line before
the boundary), and the `subckt.c:592`/`inp.c:2689` sites of `scale`.

**Pre-L1:** `no_spinit` (the practical route is the command-line `--no-spiceinit`),
`no_spiceinit` (shared build only).

**The ordering rule, stated once:**

> Any option above is a **pre-deck** option. Deliver it (a) as `-D name` / `-D name=<string>`
> when the variable is `CP_BOOL` or `CP_STRING`; (b) by writing a `.spiceinit` in the run
> directory when it is `CP_NUM`, `CP_REAL` or `CP_LIST`; or (c) as a `set` line **before**
> `source` in `-p` pipe mode. Emitting it as `.options` or inside `.control` produces **no
> message and no effect**.

⚠ **`warn` and `maxwarns` are NOT in this list** — they are the first two reads on the safe side
of the boundary, so `.options warn=1` works and `set warn=1` in `.control` does not (measured).
But `--soa-log=FILE` (`main.c:1101-1164`) is a **command-line flag**. So the SOA feature needs
**two doors for one feature**: `.options warn=1` for the value, `--soa-log=` for the file. Emit
one without the other and the log is empty.

**`.spiceinit` mechanics, measured `[R-M17]`:** a `.spiceinit` beside the deck is found from a
**foreign cwd** — the search order is netlist directory, then `$SPICE_USERINIT_DIR`, then cwd,
then `$HOME`, with a `break` on the first hit (`main.c:1264-1300`) — so ours **shadows the
user's entirely**. `-n` / `--no-spiceinit` silently drops it: the same deck gave `4700` with the
file honoured and `1e-12` without, and ⚠ the only message printed was a **resistor** warning, not
a word about the ignored file. `-D casemode=preserve` **composes** with it.

⚠ **CORRECTION `[R-M7]` — chain by COPYING, never by `source`.** `design-B`'s D19 proposes
`source <the user's ~/.spiceinit>` from inside a generated file. Measured: ngspice parses the
target as a **netlist** (`Circuit: set frobnicate`, `Error on line 2 … Unable to find definition
of model`) and **the user's variables are lost**. Reading the user's file and copying its lines
in under a banner works perfectly — both sets of variables survive.

### 3.3 The INERT list — options that exist and do nothing in this build

Every row re-verified this pass. A GUI that offers any of these as a live field is lying.

| option | why it is inert | anchor | shape |
|---|---|---|---|
| **`itl1` `itl2` `itl4` below 100** | `niiter.c:37-39` raises `maxIter` to 100 on **every** `NIiter()` caller — `CKTop` rung 1, every inner gmin/source step, `DCtran`'s per-timepoint loop, `DCtrCurv`'s fast path. **The shipped defaults `itl2 = 50` and `itl4 = 10` are therefore both 100 in fact.** ⚠ three dossiers present them as live | re-read: `if (maxIter < 100) maxIter = 100;` | **offer with a clamp at 100 and the reason** |
| **`itl3` `itl5`** | the `case` arms are empty `break;`s, and both are in `unsupported[]` | `cktsopt.c:83`, `:88` | do not offer |
| **`ramptime`** | the live code is inside `#ifdef XSPICE_EXP` — verified this pass, **zero definitions in the whole tree**; only the eight `#ifdef` guards themselves exist. The only live readers of `enh->ramp.ramptime` are `cm.c:507-522` (`cm_analog_ramp_factor()`, which a code model must *choose* to call) and one breakpoint at `dctran.c:220-221`. ⚠ **CORRECTION:** `convergence.md` §10.4 calls it "linear supply ramp applied to V/I/B sources" and is **wrong**; `options.md` §2.9 is right [crit §C2] | `vsrcload.c:465`, `isrcload.c:448`, `asrcload.c:54` | do not offer; **never as "supply ramping"** |
| **`oldlimit`** | `CKTnewTask()`'s always-compiled "special" arm copies 45 `TSK*` fields and leaves three as bare comments. Verified this pass: `cktntask.c:68` is literally `/* fixLimit */`. So `.options oldlimit` is **silently dropped the moment the analysis is issued as a `.control` command** — which is exactly ASE-L's route. (`minBreak` at `:51` and `delmin` at `:61` are dropped too, but both are recomputed per run and are harmless) | `cktntask.c:68` | **tombstone** — keep the row with the reason so nobody re-adds it from the manual |
| **`nosavecurrents`** | documented by the manual §13.7 as the workaround for `savecurrents` + AC, and **the string appears nowhere in this tree**. Verified this pass: a whole-tree grep including `*.in` and `*.txt` returns **0 hits** | — | **tombstone** |
| **`klu_memgrow_factor`** | stores `(val->rValue == 1.2)` — a boolean — into a double | `cktsopt.c:187` | do not offer |
| **`newtrunc`** | needs `PREDICTOR`, undefined here; forces `TSKnewtrunc = 0` and prints `Warning: Option 'newtrunc' ignored, compilation with preprocessor flag 'PREDICTOR' is required.` | `cktsopt.c:199-207` | do not offer (and this warning is the only probe for `PREDICTOR` there is) |
| **`scalm`** | explicitly refused: `Warning: option SCALM is not supported.` | `inp.c:891-901` | do not offer |
| **`defas`** | writes `TSKdefaultMosAD` | `cktsopt.c:111-113` | offer, **with the defect named** |
| **`x11lineararcs`** | `if (0 && …)` — and `spinit.in:4` **sets it**, so it is a visible lie in `set` output | `x11.c:707` | do not offer |
| **`debug`** | `FTEDEBUG` undefined; warns `compiled without debug messages` | `options.c:346-348` | do not offer |
| **`.SNDPARAM` / `.SNDPRINT`** | `HAVE_LIBSNDFILE` and `HAVE_LIBSAMPLERATE` both undef; the cards then fall through to `Internal Error: ft_cktcoms: bad commands` | `dotcards.md` §3.24 | do not offer |

⚠ **CORRECTION, the other direction.** `polysteps`, `dpolydegree` and `mtimeavgwindow` are
**not** inert — `options.md` and `ft_setkwords[]` mislead here. `polysteps` is read at
`plotcurv.c:342` inside `plotinterval()`, which `ft_graf()` calls at four sites; `dpolydegree` at
`cmath4.c:263`; `mtimeavgwindow` at `cmath4.c:1054`.

⚠ And `ft_setkwords[]` (`miscvars.c:25-133`), the tree's own list of "known" `set` names, is
**stale in both directions**: it lists `maxwins`, `slowplot`, `dontplot`, `geometry<num>` and
omits most of catalogue B. **Do not use it as the GUI catalogue.**

### 3.4 The four silent-failure traps

Every one of these produces a working run with the wrong setting and no message. They are the
reason a GUI must model option *types*, not just names.

**Trap 1 — a `CP_BOOL` is KILLED by writing `=1`.** Measured (`hidden-vars.md` §6.1):

```
tran 1u 20u on an RC with a 1 ns edge
  (no interp)      length(time) = 109
  set interp       length(time) =  21   + "Warning: Interpolated raw file data!"
  set interp=1     length(time) = 109   <- SILENTLY OFF

noise v(mid) v1 dec 2 1k 10k, reading onoise_total
  (default)          3.858661e-07
  set sqrnoise       1.488926e-13   <- squared, ON
  set sqrnoise=1     3.858661e-07   <- SILENTLY OFF
  set sqrnoise=true  3.858661e-07   <- SILENTLY OFF (it became a CP_STRING)
```

There are **61 `CP_BOOL` variables**. Write them as a bare `set x`, and **never** `set x=anything`.
Absence is off; `set x=0` is off; `set x=1` is *also* off.

**Trap 2 — a `CP_NUM`/`CP_REAL` is KILLED by a bare `set`.** The converse:

```
.op on a resistor with bv_max=1 at 10 V, counting SOA warnings
  set warn         0 warnings   <- CP_BOOL cannot answer a CP_NUM read
  set warn=1       1 warning
  set warn=1.0     1 warning    (REAL -> NUM coercion works)
  set warn="1"     0 warnings   <- quoted, CP_STRING, SILENTLY OFF
```

**41 `CP_NUM`** and **12 `CP_REAL`** variables need `set x=<number>`. **49 `CP_STRING`** need a
value (a bare `set` is inert, quoting is fine). **4 `CP_LIST`** (`sourcepath`, `svg_intopts`,
`svg_stropts`, `ticlist`) need the `( a b c )` form and **nothing else reaches them**.

`ticmarks` is the one variable in the tree that does it correctly — read at `CP_NUM`
(`graf.c:117`) **then** at `CP_BOOL` (`graf.c:118`), so both spellings work. It is the pattern
every other boolean read should have used.

**Trap 3 — `-D name=value` is ALWAYS a `CP_STRING`.** `main.c:984-999`: no `=` → `cp_vset(name,
CP_BOOL, TRUE)`; with `=` → `cp_vset(name, CP_STRING, value)` and nothing else. Measured:

| invocation | result |
|---|---|
| `-D sqrnoise` (CP_BOOL read) | **works** — `onoise_total = 1.489e-13` |
| `-D sqrnoise=1` | **inert** |
| `-D warn=1` (CP_NUM read) | **inert** |
| `-D warn` | **inert** — CP_BOOL cannot answer a CP_NUM read |
| `-D casemode=preserve` (CP_STRING) | **works** |
| `-D ngbehavior=hs` (CP_STRING) | **works** — `Note: Compatibility modes selected: hs` |

**So `-D` can deliver exactly the `CP_BOOL` and `CP_STRING` variables and nothing else.** For a
`CP_NUM`/`CP_REAL`/`CP_LIST` pre-deck variable the only doors are a `.spiceinit` beside the deck
or `-p` pipe mode.

Other coercions worth encoding: `set x=1.7` read as `CP_NUM` gives **1** (truncation, not
rounding); `set x=0x10` gives **0**; `set x=1.5` read as `CP_STRING` becomes `"1.500000"` —
which matters for `hcopywidth`/`hcopyheight`/`hcopyfontsize`, read as strings by the PostScript
driver.

**Trap 4 — `savecurrents` + AC destroys the entire write.** ⚠ And the documented remedy does not
exist (Trap row in §3.3). The real behaviour is **two different failures, one option**
(`hidden-vars.md` §4.2):

* on the `.control` + `write` route, **the whole `write` aborts and no file is written at all** —
  one zero-length vector makes `checkvalid()` fail for the entire plot;
* on the `-r` route, the file is written with **every device-current column identically zero at
  every frequency**.

**The in-tree remedy is `remzerovec`**, and it is **per-plot**, so it must be emitted before
**every** write, not once at the end. ASE-L already does this (its `render_deck` comment records
the probe); this section is the empirical justification, and it generalises: `savecurrents` is
merely the easiest way to create a zero-length vector, not the only one.

### 3.5 Convergence, and the knob nobody has ever seen

`CKTop()` (`cktop.c`) is a four-rung ladder and it emits a fixed, parseable state machine on
**stderr**: `Note: Starting dynamic gmin stepping` → `… completed`/`… failed` →
`Note: Starting true gmin stepping` → `Note: Starting source stepping` →
`Note: Transient op started`. `set ngdebug` upgrades it to a per-step trace.

Two parser rules that must be **comments in whatever code parses this**: the two `ngdebug`
per-step lines (`Trying gmin = …`, `Supplies reduced to …%`) end **without a newline**, and the
ladder is on **stderr** while `CKTncDump` and SOA warnings are on **stdout** — so **match on line
CONTENT, never on arrival order**, and never build a state machine that assumes sequence.

**`optran` is the fourth rung, it is a COMMAND not an option, and it is ON BY DEFAULT.**
Verified this pass, `src/frontend/init.c`:

```c
    /* To make optran the standard, call com_optran here.
    May be overridden by entry in spinit or .spiceinit or a local call
    in .control. */
        /* the default optran parameters: 1 1 1 100n 10u 0 */
```

It **supersedes** `.options noopiter` / `gminsteps` / `srcsteps` on the same task — its first
three arguments *are* those three settings. Six positional arguments, min 6 max 6
(`commands.c:672-675`; a 7th gives `optran: too many args.`):

| # | meaning | parsed by | target |
|---|---|---|---|
| 1 | `noopiter` **inverted**: `0` → `TSKnoOpIter = 1` (skip the direct Newton attempt) | `strtol` | `TSKnoOpIter` |
| 2 | number of gmin steps | `strtol` | `TSKnumGminSteps` |
| 3 | number of source steps | `strtol` | `TSKnumSrcSteps` |
| 4 | optran step size | `INPevaluate` (suffixes OK) | static `opstepsize` |
| 5 | optran final time | `INPevaluate` | static `opfinaltime` |
| 6 | supply ramp time | `INPevaluate` | static `opramptime` |

Validation (`optran.c:169-185`): `opstepsize > opfinaltime` → `Error: Optran step size larger
than final time.`, abort; `opstepsize > opfinaltime/50` → clamped with `Note: Optran step size
set to %e, (stepsize = finaltime / 50).`; `opramptime > opfinaltime` → `Error: Optran ramp time
larger than final time.`; **`opstepsize == 0` deselects optran** with `Note: Optran is
deselected.`

**Why a GUI must surface it:** it silently decides the accuracy of every fallback operating
point. Measured `an-core.md` §5.10: **0.9999550 instead of 1.0** on a 1 µs RC. No ngspice user
has ever seen this knob, and the sentence *"this operating point may come from a transient"* is a
fact about the numbers in an OP readout.

⚠ **The ramp argument should always be emitted as 0**: `optran.c:670-671` has no clamp, the
factor oscillates and returns to 0 at 2×ramptime, and `README.optran` says ramping is not
established.

**`CKTncDump`'s starred rows** (`cktncdump.c:11-43`) are the other half. After every failed
operating point ngspice prints a `Last Node Voltages` table with a trailing ` *` on **each node
that still fails the convergence test**. `convergence.md` §4.4 calls it "the single most useful
diagnostic in ngspice"; it is machine-parseable, it needs no ngspice change, and nothing in any
GUI has ever displayed it.

---

## 4. What has to be GENERATED, because ngspice has no construct for it

### 4.1 The headline

> **ngspice has no `.STEP`, no corner statement, no `.MC`/`.DATA` card, and no built-in
> statistical analysis.** `grep -rn '"\.step"' src/frontend/ src/spicelib/parser/` returns
> nothing. `.step param x 1 3 1` gives `unimplemented dot command '.step'` and aborts the run
> (`inp2dot.c:969-971`, verified).

The only "sweep of a sweep" the *simulator* offers is the second source of `.dc` (§2.3), and
`temp` is accepted there as a pseudo-source. Everything else is the GUI's to generate. ngspice's
own shipped example says so: `examples/various/param_sweep.cir:1-4` is titled *"parameter sweep …
replaces `.STEP R1 1k 10k 1k`"*.

**So a GUI is not "driving an analysis" here; it is a code generator for a small imperative
language.** §4.5 is that language's list of sharp edges.

### 4.2 Parameter sweeps — four mechanisms, ranked

| mechanism | cost per point | re-parse? | reaches |
|---|---|---|---|
| **`alter <inst> <param>=<v>`** | cheapest | **no** | an instance parameter of a live device. `alter @device[parameter] = expr`, `alter device parameter = expr`, `alter device = expr` (its "default" parameter), and a vector form `alter @vin[pulse] = [ 0 5 10n 10n 10n 50n 100n ]` |
| **`altermod @<model>[<p>]=<v>`** | cheapest | no | a model parameter; also `altermod mod1 [mod2 …] file = newparams.mod` for a whole-model reload |
| **`alterparam <name> = <v>` + `reset`** | a full re-parse | **yes** | a `.param`. It **edits the stored deck text** (`ci_mcdeck`, `inp.c:1747-1840`) and does nothing to the live circuit until `reset` (or `mc_source`) reloads it. Also `alterparam <subcktname> <pname> = <v>`, which rewrites the *n*-th positional value on the `X` line |
| **`.param x = 'var(<name>)'` + a per-run `set x` in `.spiceinit`** | a full re-parse, but **the deck is byte-identical between runs** | yes | **anything, including a value inside a subcircuit or a `.lib` that ASE-L did not render** — §3.2, Group R |

The fourth is the one that needs no schematic change and no per-run deck edit: the deck says
`.param rv = 'var(myres)'`, the run directory's `.spiceinit` says `set myres = 4700`, and
`[R-M17]` measured `@r1[resistance] = 4700` **with the process cwd somewhere else entirely**.
For a `.param` the GUI itself rendered, `alterparam` + `reset` is cheaper and `var()` is the
fallback.

⚠ **`alter` is ~10× cheaper per run on a big PDK deck** because it skips the re-parse. So an
axis made only of `alter`-able quantities can be collapsed into one process; an axis containing a
corner or a `.param` cannot.

### 4.3 Temperature — three mechanisms, and one of them is not a sweep

| route | shape | when to use |
|---|---|---|
| **`dc <src> a b s temp t0 t1 ts`** | **one command, one plot, temperature is a scale vector** | `[R-M12]`: `dc v1 0 1 0.5 temp -40 60 50` → **9 rows**. The *only* route that gives an ADE-style "one curve versus temperature" with no control flow. Use it whenever the analysis is OP/DC **and** the temperatures are uniformly stepped |
| **`set temp = <celsius>`** in a loop | N runs, N plots | mandatory for AC/TRAN versus temperature. No re-parse happens: `temp` is a `US_SIMVAR`, so `cp_vset` hands it to `if_option()` which writes `CKTtemp`, and `CKTdoJob()` re-runs `inp_evaluate_temper()` at the start of every analysis. ⚠ **`temp` is STICKY** — it persists to the next analysis and is **not reset by `reset`** (measured: the next analysis header still said `TEMP = 125.000000`). Set it explicitly for every run, including the nominal one |
| **`.temp <v>` card** | deck-level nominal | goes through the same variable (`cp_vset("temp", …)` at `inp.c:1194`), so a later `set temp` overrides it and `reset` re-applies it |

⚠ **`temp` is not a `.param`.** For a campaign the honest emission is `.options temp=<v>`
re-rendered per shard (an OPTtbl `IF_REAL` keyword), never `set temp` — the stickiness above is
why.

Per-instance overrides also exist as ordinary instance parameters `temp` and `dtemp`
(`res.c:17`).

### 4.4 Corners and Monte Carlo

**Corners.** `.lib <file> <section>` is resolved **inside `inp_readall()`**, long before any
control statement runs (`expand_section_references()`, `inpcom.c:4530`, called from
`inpcom.c:2340`), and the deck copy that `reset`/`mc_source` reload is taken **after** library
expansion. **So a `.lib` section cannot be `alter`ed and a corner always needs a re-rendered
deck.** A corner is therefore: a named set of `.lib` rows + variable overrides + a temperature,
re-rendered per point.

⚠ **`.param` inside `.if`/`.elseif`/`.else` is NOT conditional.** numparam evaluates all branches
(`inp_subcktexpand` precedes `dotifeval`) and the last textual `.param` wins. Measured: three
"different" corners all used `rmul = 1.1`. Only device, `.model` and `.subckt` cards are
conditional. **Do not build a corner mechanism out of `.if`.**

**Monte Carlo — two entirely disjoint sets of random functions**, and a GUI that lets a user type
a distribution must know which side of the fence the expression will be evaluated on:

| netlist / `.param` / `.model` level | control language |
|---|---|
| `agauss(nom, avar, sigma)` = `nom + (avar/sigma)*N(0,1)` | `sgauss(v)` — one `N(0,1)` per element |
| `gauss(nom, rvar, sigma)` = `nom + (nom*rvar/sigma)*N(0,1)` | `sunif(v)` — one `U(-1,1)` per element |
| `aunif(nom, avar)` = `nom + avar*U(-1,1)` | `rnd(v)` — integer in `[0, floor(v))`, **libc `rand()`, a different stream** |
| `unif(nom, rvar)` = `nom + nom*rvar*U(-1,1)` | `poisson(v)` |
| `limit(nom, avar)` = `nom ± avar`, sign from `U(-1,1)>0` | `exponential(v)` |

**`agauss` etc. do not exist in the control language; `sgauss` etc. do not exist in the
netlist.** Every shipped example re-defines the first set in terms of the second
(`examples/Monte_Carlo/MonteCarlo.sp:26-33`). ⚠ `agauss` and `gauss` **silently return the
nominal value if `avar <= 0` or `sigma <= 0`** (`xpressn.c:49-52`, `:60-63`) — a `sigma = 0` gets
no variation and no warning; `unif`/`aunif`/`limit` have no such guard.

`compose v gauss=1000 mean=0 sd=1` and `compose v unif=1000 mean=0.5 span=1`
(`com_compose.c:600-631`) build a whole sample vector in one call — the cleanest way to
pre-compute every per-run value so the user can *see the sample before it runs*. ⚠ Caveat:
`com_compose` does **not** call `checkseed()`.

**Seeding — the rules, and the two traps.**

* `setseed <n>` (`0 < n <= INT_MAX`) does `srand(n); TausSeed(); cp_vset("rndseed", n)` and
  **re-seeds immediately**. `setseed` with no argument uses `rndseed` if set, else `getpid()`.
  A non-numeric or non-positive argument prints `Warning: Cannot use <x> as seed!` and is
  **ignored**.
* `set rndseed = <n>` does **not** re-seed by itself — it is picked up lazily by `checkseed()`,
  which is called from exactly five places, **all** in `cmath2.c` (`cx_rnd`, `cx_sunif`,
  `cx_poisson`, `cx_exponential`, `cx_sgauss`). It is **never** called from the netlist-level
  functions, nor from `com_compose`.
* ☠ **Trap A — the first parse is seeded from the PID.** `main.c:935-938` seeds deterministically,
  and then `main.c:1371` calls `initw()`, which does `srand((unsigned int) getpid()); TausSeed();`
  (`wallace.c:76-86`) right before the input file is read. Measured over three invocations, same
  deck, `rndseed = 1` each time: `@r1[resistance]` = `9.967322e+02`, `9.668247e+02`,
  `9.902101e+02` — while the control-language `sgauss(0)` gave the identical pair every time,
  because `cx_sgauss` calls `checkseed()`. **Never let a reported result come from the first
  parse; always `reset` before the first measured run.**
* ☠ **Trap B — `.option seed=<n>` destroys Monte Carlo entirely.** `eval_opt()` runs on **every**
  re-parse, including the ones `reset` and `mc_source` perform, so it re-seeds to the same value
  before every draw. Measured: six "Monte Carlo" runs all returning `1.013170e+03`, and a second
  deck returning `1.075945e+03` four times. **Every run is the same sample, silently.** An
  in-loop `setseed` does not help, because `eval_opt()` runs *after* it. `seed=random` varies but
  is not reproducible across invocations.

> **The generator rule: never emit `.option seed=<n>` for a statistical campaign.** Emit
> `setseed <n>` once at the top and `reset` before the first measured run; or, for "re-run just
> case #17", emit `setseed <base+17>` before that case's `reset` — which is what
> `examples/Monte_Carlo/MC_2_control.sp:26` does.

**A stronger recommendation, and it is the design-of-record's:** have the **GUI draw the
samples in Tcl** rather than using any of these. The reasons are all measured — the two seeding
traps above; `doc/claude/issues/0210-ase-migrate-source-library-leaks-and-sg13g2.md:99` records a
model-level Monte-Carlo draw **proven to change between runs of the same migrated state**; and
§5.4 records that transient white and 1/f noise are irreproducible under *every* seed control.
When the GUI draws, the sample set is reproducible, inspectable, exportable and re-runnable point
by point.

**And statistics must be computed outside the deck: ngspice has no sort, no median, no
percentile and no histogram.**

### 4.5 The generator's sharp edges

Each of these bites a first implementation. All are measured in `orchestration.md` §10.

| # | edge |
|---|---|
| 1 | **Variables and vectors are different namespaces, and a loop condition sees only vectors.** `set n = 4` + `dowhile m < n` runs the body **once** and warns on stderr. All bounds must be `let` vectors |
| 2 | **An invalid `if`/`while` condition takes the FALSE branch instead of erroring**, and `.control`'s `if` on **strings** takes the false branch for both `eq` and `ne` `[B-M5]`. There is no in-deck string test. Every decision belongs in the generator, not the deck |
| 3 | **`$var` swallows a following `.` `-` `(` `[` `&` `#` `?` `@`** (`VALIDCHARS`, `variable.c:875`). `source deck_$c.cir` looks for a variable named `c.cir`. Always `{$var}`. `[R-M19]` measured the exact shape a plot-capture loop wants — `set wl = "$wl $p.all"` → `Error: p.all: no such variable`, four times, then `Error during 'write': no writable vector found` |
| 4 | **`$&vec` truncates to 6 significant digits** (`"%G"`, `variable.c:55`) unless `set csnumprec`. Measured: `1234.56789012345` became `1234.57` |
| 5 | **`meas` results are stored with `"%e"`, ~7 significant digits** (`measure.c:138`), and **a failed `meas` creates no vector** with no existence predicate |
| 6 | **`save` is lost by `reset`/`mc_source`; `.save` cards survive.** Re-emit `save` after every `reset` — `examples/Monte_Carlo/MC_ring.sp:39` gets this wrong |
| 7 | **Plot names are not `<type><run>`.** `plot_num` is one global counter advanced only on collision. Measured: `op1 op2 tran2 ac2 tran3 ac3 dc3 op3` with no `tran1`/`ac1`/`dc1`. Confirmed again this pass — a deck with one `disto` produced `disto2`/`disto3`, and a deck with `noise` after `ac` produced `noise2`/`noise3`. **Capture `$curplot`; never predict a counter** |
| 8 | **`setplot <name>` is a case-sensitive PREFIX match and a non-match is silent.** [A-M9]: on a session whose plots were `noise2`/`noise3`, `setplot noise1` selected nothing and left the current plot where it was — the following `write` silently wrote a different plot. `destroy <name>` is byte-exact |
| 9 | **A `plotname.` prefix that matches nothing silently reads the CURRENT plot** (`vectors.c:809-811`). `let x = ac7.v(out)` with no `ac7` returns a wrong number with no error |
| 10 | **`destroy all` resets `plot_num` to 1** and deletes the collector plot with everything else |
| 11 | **`setplot new` with no name gives `unknown1`/`Anonymous`.** Name the collector: `setplot new aselres "ASE-L results" aseldata` |
| 12 | **`wrdata`/`plot` iterate over the plot's default scale**, which in a synthetic plot is the *first vector created*. Measured: a reshaped 27-element vector created first made `wrdata` emit 24 rows of uninitialised memory (`1.63041663e-322`, `-1.03751853e+229`). Create the index vector first and `setscale` it |
| 13 | **`dowhile` always runs its body once**, so a zero-iteration axis silently becomes one iteration. Use `while` |
| 14 | **A bare `repeat` loops forever**; `goto`/`label` are **case-sensitive** while almost nothing else is |
| 15 | **Nets or vectors named `eq le ge lt gt ne or and not` break the expression parser** — `print v(eq)` → `PPerror: syntax error` |
| 16 | **`.model` with a parenthesised parameter list plus a random function is a FATAL parse error**: `.model d1 d (is=agauss(1e-14,1e-15,3))` → `Cannot compute substitute` → `exit(1)`. Drop the outer parens |
| 17 | **`reset` prints `Reset re-loads circuit <title>` to stdout every call** (`inp.c:551`), and every analysis prints its TEMP line, the solver banner and `No. of Data Rows`. A 1000-run sweep is thousands of lines to filter. `.options noacct` removes the accounting block; **nothing suppresses the reset banner** |
| 18 | **`mc_source` leaks a whole circuit per call** (`setcirc` shows 4 after 3 calls); `reset` does not, and re-draws the random numbers just the same. **Prefer `reset`** |
| 19 | **`shell` output interleaves unpredictably** with ngspice's buffered stdout |
| 20 | **Nothing in a sweep is parallel or shared.** `USE_OMP` only parallelises the matrix load within one analysis |
| 21 | **`alter` on a `casemode=preserve` deck needs the deck's exact spelling** — the lower-casing at `device.c:1409-1419` is conditional on `inp_case_folding()` |

### 4.6 One process per point, or one process for all of them

The choice is real and the trade is measured. `orchestration.md` §9.3-§9.4 and `builds.md` §4:

| | one process per point (a shard runner) | one process, a `.control` loop |
|---|---|---|
| abort | kill the current shard; **every completed shard survives on disk** | Ctrl-C is timing-dependent — it either kills one run and continues or discards the whole control block, **indistinguishably** |
| an interrupted run | non-zero exit code on that shard | leaves **`sim_status = 0`** — *indistinguishable from success* |
| progress | `k/N`, free, nothing to parse | a generated `echo` the GUI must parse |
| the deck | one artifact, reviewable, diffable, hand-runnable | a generated loop nobody can read |
| results | one raw per point; the family is a directory | one raw with N plots, or a hand-built collector with edge #12 |
| cost | N process starts + N parses | N parses with `reset`, or none with `alter` |

⚠ Also measured: **`sim_status` is 0 for an interrupted run and 0 for a non-converged OP with
`singular matrix` warnings.** It is not a general success predicate.

---

## 5. Transient noise — a second, completely separate noise capability

### 5.1 What it is, and why it is not `.NOISE`

`trnoise` and `trrandom` are **not analyses and not dot cards**. They are two ordinary
`IF_REALVEC` **instance parameters** on `VSRC` **and** `ISRC` — the same slot that holds `pulse`,
`sin`, `pwl`:

```
src/spicelib/devices/vsrc/vsrc.c:24-25
 IOP ("trnoise",  VSRC_TRNOISE,  IF_REALVEC, "Transient noise description"),
 IOP ("trrandom", VSRC_TRRANDOM, IF_REALVEC, "random source description"),
src/spicelib/devices/isrc/isrc.c:26-27   -- the identical pair on ISRC
```

Re-confirmed this pass [A-M3] in `devhelp vsource`: ids **30** and **31**, both **`inout`**.

⚠ **CORRECTION — the manual is wrong about current sources.** Manual §11.3.11 says "isrc is not
yet available". Measured: `i1 0 n1 dc 0 trnoise(0 0 0 0 5m 18u 30u)` gives mean 3.06 V across
1 kΩ. **Both work.** That matters more than it sounds: a parallel *current* source is the only
way a GUI can inject noise into an existing net without editing the schematic's topology.

⚠ **`src/ngspice.txt` mentions neither word** — `grep -c` returns 0. There is no `help trnoise`.
The only in-tree documentation is the parameter table itself.

**Because they are device parameters, they are the one part of this whole surface that CAN be
read back**: `print @<inst>[trnoise]`, `show <inst> : trnoise`, and `print @<inst>[function]` →
**7** = TRNOISE, **8** = TRRANDOM (`vsrcdefs.h:148-160`). Asking for the wrong function name
returns an empty vector, so `@<inst>[trnoise]` is itself a clean probe.

**The one-paragraph distinction a tooltip needs:**

> **`.NOISE` and transient noise answer different questions and share no code.** `.NOISE` is
> small-signal and frequency-domain: it linearises about the operating point, asks each device
> for its spectral density, propagates each contribution to one output through the linear
> transfer function, and reports density versus frequency plus an integrated total. It is exact,
> fast, repeatable, and blind to everything non-linear. **`trnoise`/`trrandom` are the opposite:
> they are stimulus, not analysis.** They make one source emit a random waveform during a normal
> transient, so the noise passes through the full non-linear circuit — jitter on a clock edge, a
> comparator flipping, a PLL wandering. There is no spectrum unless you compute one
> (`linearize` + `fft`), the answer is a *realisation* and not an expectation, and you need many
> runs to say anything statistical. **Ideal sources contribute nothing to `.NOISE`, so adding
> `trnoise` to a source changes no `.NOISE` result — and `.NOISE` never sees it. Use `.NOISE` to
> size a design; use `trnoise` to see a design fail.**

### 5.2 `trnoise(...)` — all seven arguments

```
trnoise( NA  TS  NALPHA  NAMP  RTSAM  RTSCAPT  RTSEMT )
           1   2    3      4      5       6        7
```

| # | name | meaning | unit | default | zero means | refuse |
|---|---|---|---|---|---|---|
| 1 | `NA` | white-noise **rms per sample** — the σ of the Gaussian drawn once per `TS` | V or A | required (index 0 read unconditionally) | no white noise; the sign is ignored (`-1m` ≡ `1m`) | — |
| 2 | `TS` | **the noise timestep** — the interval between fresh samples, **and the transient breakpoint spacing** | s | required (index 1 read unconditionally) | white **and** 1/f switched off entirely, no breakpoints posted. This is the legal "RTS only" idiom | ☠ **`< 0` HANGS FOREVER** — §7 T1 |
| 3 | `NALPHA` | 1/f PSD exponent α, output ∝ f^−α | — | `0.0` | **also forces `NAMP := 0`** — there is no 1/f without a positive exponent | **strictly `0 < α < 2`**; α = 2 is a silent zero, α > 2 is a divergent random walk with a fixed f^−2 slope |
| 4 | `NAMP` | 1/f driving rms — σ of the white sequence fed to the Kasdin filter | V or A | `0.0` | no 1/f | `>= 0` |
| 5 | `RTSAM` | RTS amplitude — the height of the two-level telegraph step | V or A | `0.0` | no RTS, **and args 6-7 are not read** | `>= 0` |
| 6 | `RTSCAPT` | mean trap capture time = mean duration of the **low** state | s | `0.0` | `exprand(0) == 0` ⇒ capture is instantaneous ⇒ the source sits permanently at `+RTSAM`, a pure DC offset. Measured `trnoise(0 0 0 0 5m)` → `AVG = 5.00000e-03`, σ ≈ 8e-16 | `>= 0` |
| 7 | `RTSEMT` | mean trap emission time = mean duration of the **high** state | s | `0.0` | emission is instantaneous ⇒ one-timestep spikes. Measured `trnoise(0 0 0 0 5m 18u)`: duty 0.6 %, mean high 94 ns | `>= 0` |

The three arms superpose: `interp(white ⊕ 1/f) + (RTSAM if high) + VSRCdcValue`
(`vsrcload.c:399-427`). A `dc` value is **added**; `dc 0` is the normal idiom.

**Derived readouts a form should show** (they are the difference between a usable panel and a
list of Greek letters): white-noise **density = `NA*sqrt(2*TS)`** V/√Hz; **point count ≈
`5*tstop/TS`**, independent of the requested `tstep`; and, for 1/f, a **memory estimate** —
`≈ 40 bytes × tstop/TS` **pre-allocated per source before the first timepoint**, measured at
**416 MB for 1e7 samples**.

⚠ **`TS` is a COST control, not an accuracy control**, and a form must say so: each source with
`TS > 0` posts a breakpoint every `TS` (`vsrcacct.c:250-258`), so it — not `tstep` — sets the
transient step.

**Emit all seven, always, positionally, padded with 0.** ⚠ **CORRECTION:** `trnoise.md` §10.3
says to omit args 5-7 when RTS is off; measurement found padding benign (**stddev 8.59e-4
unpadded vs 8.65e-4 padded**, no DC offset) while short forms are a **heap read past the array**
(§7 T2) and two shipped ngspice examples get them wrong. **Pad** [crit §C25].

### 5.3 `trrandom(...)` — all five arguments

```
trrandom( TYPE  TS  TD  PARAM1  PARAM2 )
            1    2   3     4       5
```

It is **piecewise-constant**: one draw per `TS`, held flat in between. No interpolation, no
filtering.

| # | name | meaning | default | notes |
|---|---|---|---|---|
| 1 | `TYPE` | distribution selector, `(int)` cast | required | **out of range (0, 5, …) ⇒ the source silently emits 0 for ever** |
| 2 | `TS` | hold time, and a breakpoint at each | required | ☠ **`TS = 0` or negative is FATAL**: `doAnalyses: impossible error - can't occur`. Note the asymmetry with `trnoise`, where `TS = 0` is legal |
| 3 | `TD` | delay before the first draw | `0.0` | for `t < TD` the source holds **`PARAM2`**. Measured: `trrandom(2 10u 25u 1 7)` sits at exactly 7 until 25 µs. A negative `TD` is ignored |
| 4 | `PARAM1` | distribution parameter 1 | `1.0` | |
| 5 | `PARAM2` | distribution parameter 2 / offset | `0.0` | **also the value used before the first draw, and the value a `dc`-less source injects into the operating point** |

| `TYPE` | distribution | `PARAM1` | `PARAM2` | measured (20 ms, `TS = 10 µs`, defaults) |
|---|---|---|---|---|
| **1** | uniform on `[−PARAM1, +PARAM1)` | **half**-range | offset | mean 0.011, σ 0.576 (= 1/√3 ✓), min −0.99988, max +0.99801 |
| **2** | gaussian | standard deviation | mean | mean 0.043, σ 1.003 ✓; `(2 10u 0 2 1)` → mean 1.047, σ 2.006 ✓ |
| **3** | exponential | mean | offset | mean 0.998, σ 1.012, min 0 ✓; `(3 10u 0 2 1)` → mean 2.996, σ 2.023, min 1 ✓ |
| **4** | poisson | λ | offset | mean 1.003, σ 0.992 ✓ (integer-valued, min 0 max 5); λ = 3 → mean 3.012, σ 1.711 (√3 = 1.732 ✓) |

⚠ **`PARAM1` for the uniform case is the HALF-range.** A field labelled "Range" is off by 2×.
And types 3 and 4 are strictly one-sided, so they always carry a DC offset equal to their mean —
a "random supply drop" wants type 2 or 1.

### 5.4 Seeding, and the sentence a form owes the user

The two generators are seeded differently and only one is reachable:

* **White and 1/f come from the Wallace pool**, which `initw()` seeds from **`getpid()`**
  (`wallace.c:83`), once, before the deck is read. `setseed`, `set rndseed` and `.option seed=`
  do **not** reach it.
* **RTS and `trrandom` are seed-reproducible.**

> **One sentence, on screen, worth more than the whole manual on the subject:**
> *"White and 1/f noise are not reproducible in this build — the generator is seeded from the
> process id."*

⚠ **`notrnoise` does not kill everything it looks like it kills.** It zeroes
`NA TS NALPHA NAMP RTSAM RTSCAPT RTSEMT` in `trnoise_state_gen` (`1-f-code.c:122`), so it kills
white and 1/f **always**, kills RTS **only when the same source also has `TS > 0`**, and
**never** touches `trrandom`.

Also: a deck with transient noise **consumes the same `drand()` stream** as everything else
(`wallace.c:53-54`, `:98-100`), so it shifts every subsequent Monte Carlo draw. A campaign mixing
the two must seed per run.

### 5.5 Two injection routes, neither touching the schematic

⚠ **CORRECTED 2026-09-15 by Stage 13 task 1 (issue 1466, C1/C2), measured on both binaries.** **(1) `ase_inoise_1` is an XSPICE `a` card** — SPICE reads a device from its first letter; on the fork it gives `MIF-ERROR - unable to find definition of model 0`, rc 1, and `ase::netlist_facts` would file it under `xspice`. A generated card's name begins with its device letter (`iase_noise_<row>_<k>`). **(2) A `trnoise(…)` written on a card serves EVERY transient in the deck**: a second `tran` with no restore is noisy (45.2: 0.88 V RMS, 4439 points where its card asks for ~108). Shipped: a quiet carrier in the netlist slot, `alter … trnoise = [ … ]` above the row's own card, and `alter … trnoise = [ 0 0 0 0 0 0 0 ]` below its guard. **(3) `trrandom` on a current source freezes** when its delay outruns its hold time (one value where a V source gives 501), so an injected random current is a V source into a 1 S VCCS.


1. **`alter <src> trnoise = [ 10m 1u 0 0 ]`** on an existing DC-only source. ⚠ **grey out any
   source that carries a stimulus** — §7 T5: one source carries exactly **one** transient
   function, and `alter` on a source that had `sin(...)` **destroys the sine** (measured: max
   `v(in)` fell from 1.0-with-sine to 1.02 = dc + noise, with no warning).
2. **A parallel current source added by the deck renderer**, e.g.
   `ase_inoise_1 0 out dc 0 trnoise(1m 1u 1 0.1m 5m 18u 30u)` — validated against the netlist's
   node map first. This is the route that needs no existing source at all.

---

## 6. Results — what comes back, and how to get all of it

### 6.1 The rawfile format

Two writers: the `-r`/streaming one (`outitf.c`) and the `write`-command one (`rawfile.c`). They
emit **different key sets**, and a reader must accept both.

| key | `-r` writer | `write` writer | notes |
|---|---|---|---|
| `Title: ` | `run->name`, the deck's first line | `pl->pl_title` | one per plot, repeated for every plot in a multi-plot file |
| `Date: ` | taken **now** | taken when the plot was created | e.g. `Wed Sep  9 18:47:52  2026` — note the **double space** before the year |
| `Command: ` | always `ngspice-<version>, Build <date>` | same, only `if (ft_sim)` | ⚠ see the security note below |
| **`Plotname: `** | `run->type` | `pl->pl_name` | **the only analysis identifier in the file** |
| `Option: casemode=<mode>` | `:993-997` | `:200-201` | **off by default**, gated on `casemodewrite`. Local to this tree; no released ngspice writes it |
| `Option: <name>[=<value>]` | never | one per `pl_env` entry | `pl_env` is populated **only** by `raw_read()`, so this appears only when re-writing a loaded plot |
| `Flags: ` | `complex` or `real` | plus ` unpadded` when `nopadding` | |
| `No. Variables: ` | `run->numData` | count of `pl_dvecs` | |
| `No. Points: ` | `0       ` (8 spaces) as a placeholder, **backfilled by `fileEnd()`** | the true length of the longest vector | |
| `Dimensions: ` | **never written** | only when `numdims > 1` | which is why a nested `.dc` has none |
| `Variables:` / `Values:` / `Binary:` | both | both | |

⚠ **`Offset:` is recognised on read and rejected** (`Warning: Offset: is not supported`).
⚠ **Any non-blank line the reader does not recognise aborts the whole load**:
`Error: strange line in rawfile:\n  %s\n  load aborted.` and `return NULL`
(`rawfile.c:860-867`). **There is no forward compatibility — a new header key breaks every
existing reader.**

**The `Variables:` block.** `-r` writes `\t<index>\t<name>\t<typename>[\tgrid=3]`; `write` adds
`[ min=][ max=][ color=][ grid=][ plot=][ dims=]`. The 23 type names are in `sim.h:4-28`:
`notype time frequency voltage current voltage-density current-density voltage^2-density
current^2-density voltage^2 current^2 pole zero s-param temp-sweep res-sweep impedance
admittance power phase decibel capacitance charge`.

⚠ **The type is GUESSED, not known.** `guess_type()` (`outitf.c:1022-1083`) infers it from the
vector's *name* and the plot name, and **everything unrecognised defaults to `voltage`** — the
source's own comment at `:1018-1021` calls this a FIXME. Consequences a reader must handle:

* **Name mangling on write.** A `SV_CURRENT` vector `x#branch` is written `i(x)`; a `SV_VOLTAGE`
  vector `x` is written `v(x)`. Because the type is guessed, this mangles names that were never
  node names. Measured: a `.pz` run through `-r` writes its pole as **`v(pole(1))`**; `.sens`
  parameter sensitivities come out as **`v(r1:rsh)`**, **`v(c1_temp)`**; a two-source `.dc`
  sweep scale comes out as **`v(v-sweep)`**. **A GUI must be prepared to strip a `v(`/`i(`
  wrapper it did not ask for.** `set keep#branch` suppresses only the `#branch` half.
* On read, a name **starting with a digit** is re-wrapped as `<abbrev>(<name>)`, so node `1`
  becomes `v(1)`.
* ⚠ **`scale=<name>` exists on read and is NEVER written by either writer.** A vector with its
  own scale loses that binding through a round trip — which matters for XSPICE event vectors.
* ⚠ **Reading a rawfile executes code**: the `Command:` key is fed to the command interpreter.
  Treat a rawfile from an untrusted source accordingly.

**Format selection from outside the deck**, three equivalent levers: `-D filetype=ascii`,
`SPICE_ASCIIRAWFILE=1` in the environment, or `set filetype=ascii`. Binary is the default and is
roughly 3× smaller.

### 6.2 The literal `Plotname:` per analysis — the complete table

Three name spaces exist for one analysis and a GUI touches all three: the **registry name**
(`AC`), the **plot name** (`AC Analysis`) and the **plot typename** (`ac2`).

**This table is NORMATIVE, not evidential.** `PLAN.md`'s D30 makes it a load-time error to register
an analysis without a results destination, so **every destination named below must appear in some
registry row's `results`**, and a registry row without one will not load. The `destination` and
`label shown` columns were lifted here from `evidence/design-of-record.md` §9.1 in this pass, for
exactly that reason: a normative table cannot live only in an evidence file. The dossier remains the
second-level anchor.

| what produced it | `Plotname:` literal | when | destination | label shown |
|---|---|---|---|---|
| `op` | `Operating Point` | always | Value column (scalars) | *Operating point* |
| `dc` | `DC transfer characteristic` | always | waveform viewer | *DC sweep* |
| `ac` | `AC Analysis` | always | waveform viewer | *AC* |
| `ac`/`noise`/`pz`/`tf`/`disto`/`sp` with **`keepopinfo`** | an **extra plot, written FIRST** | `AC Operating Point` for AC and SP; `NOISE Operating Point` for NOISE; **`Distortion Operating Point` for BOTH DISTO and PZ** — the PZ one is an upstream copy-paste bug at `pzan.c:57-61` | read for its vectors, labelled from the sidecar. ⚠ **role `opinfo` plots are NEVER handed to `xschem raw read` with `op`** | *<analysis> — operating point* |
| `tran` | `Transient Analysis` | always | waveform viewer | *Transient* |
| `noise` | `Noise Spectral Density Curves` | always; ` - (V^2 or A^2)/Hz` appended under `sqrnoise` | waveform viewer | *Noise — spectral density* |
| `noise` | `Integrated Noise` | **only when `start != stop`**; ` - V^2 or A^2` appended under `sqrnoise` | Value column (`onoise_total`, `inoise_total`) | *Noise — integrated* |
| `noise` **contributors** (`ptssum`) | inside the spectrum plot, as per-device vectors | only when the contributor table was asked for | result table | *Noise contributors* |
| `pz` | `Pole-Zero Analysis` | always | result table (Re, Im, f, Q) + an s-plane scatter | *Poles and zeros* |
| `tf` | `Transfer Function` | always | Value column — `Transfer_function`, `v1#Input_impedance`, `output_impedance_at_V(b)` | *Transfer function* |
| `disto` | `DISTORTION - 2nd harmonic`, `DISTORTION - 3rd harmonic` | **harmonic mode only** | waveform viewer, two named trace groups | *Distortion — 2nd / 3rd harmonic* |
| `disto` | `DISTORTION - IM: f1+f2`, `DISTORTION - IM: f1-f2`, `DISTORTION - IM: 2f1-f2` | **IM mode only** — measured [A-M4] | waveform viewer, three named trace groups | *Distortion — IM f1+f2 / f1−f2 / 2f1−f2* |
| `sens` | `Sensitivity Analysis` | ⚠ **both DC and AC modes** | DC: result table sorted by \|value\|. AC: waveform viewer | *Sensitivity* |
| `sp` | `SP Analysis` | always | S-matrix picker → waveform viewer (Smith/polar); `wrs2p` for export | *S-parameters* |
| `pss` | `Time Domain Periodic Steady State Analysis`, `Frequency Domain Periodic Steady State Analysis` | 2 × (1 + relaunches) — **take the LAST pair** | waveform viewer, both | *PSS — time domain / frequency domain* |
| **`fft` / `spec`** | **`Spectrum`** | typename **`spN`** | waveform viewer | *Spectrum* |
| **`psd`** | **`PSD`** | | waveform viewer | *PSD* |
| **`linearize`** | **`<old> (linearized)`** | e.g. `Transient Analysis (linearized)` | waveform viewer, replacing the source trace group | *<old> (linearized)* |
| **`.four`** | no plot — `fourierMN` (2-D) and `thdMN` (scalar) vectors in the current plot | only with a `.four` card | result table (harmonics) + Value column (`thd`) | *Harmonics* / *THD* |
| **`meas`** | no plot — a length-1 vector per measurement in the current plot | one per measurement row | Value column, under the measurement's own name | *<the user's name>* |
| **XSPICE event nodes** | not in the rawfile at all (§6.6) | whenever `edisplay` finds nodes | `eprvcd` → the VCD pipeline `ase::attach_dbs` already owns | *<node name>* |
| `cutout` | `<old> (cut out)` | | waveform viewer | *<old> (cut out)* |
| XSPICE event nodes via `write` | `digital` (typename `dig1`) | §6.6 says not to use this route | **none — refused** | — |
| no analysis / the fallback | **`constants`** (typename `const`) | always present | **none — and a rawfile whose FIRST plot is this one is rejected outright by `ase::raw_content_verdict`** | — |

⚠ **Two plots can share one literal, so the literal is the LABEL and the sidecar's creation order is
the IDENTITY.** `sens … dc` and `sens … ac` both report `Sensitivity Analysis`; two rows of one type
do too. The join is **positional on creation order**, 1:1 with the plotmap sidecar's lines (§6.3).

⚠ **`AC Operating Point` reads back as `op`.** xschem's `read_dataset` matches
`strstr(lowerline, "operating point")` **before** the AC arm (`src/save.c`), so a `keepopinfo` OP
plot from an AC, NOISE, PZ, TF, DISTO or SP run attaches with `sim_type = op` and collides with the
real operating point. That is why `role opinfo` plots are never handed to `xschem raw read` with
`op`.

⚠ **CORRECTION — `outputs.md` §3's last three rows are wrong** [crit §C4]. It says `fft`/`spec`
write `Plotname: spectrum` with typename `spect<N>`, and `linearize` writes `Plotname:
transient`. Source and measurement disagree: `plotabs[]` (`typesdef.c:67-90`) has `{"sp","sp"}`
at index 18 and `{"spect","spect"}` at index 20, and `ft_plotabbrev()` returns the **first**
entry whose pattern is a substring — so `"spectrum"` matches **`sp`** and `spect` is
unreachable. And `com_linearize` does `plot_alloc("transient")` then
`new->pl_name = tprintf("%s (linearized)", old->pl_name)` (`linear.c:95-96`), so `"transient"`
is the *abbreviation lookup key*, never the `Plotname:`. Live `setplot`:

```
Current sp4    * critique probe 1 (Spectrum)
        tran4  * critique probe 1 (Transient Analysis (linearized))
        tran3  * critique probe 1 (Transient Analysis)
```

**A GUI matching `Plotname:` against `outputs.md`'s table would miss every post-processed plot.**

### 6.3 Capturing every plot, and mapping a plot back to the analysis that made it

**`write <file> all` is a VECTOR wildcard inside ONE plot, not a plot wildcard** [crit §C3].
Measured on a session left with `disto1` (2nd harmonic) and `disto2` (3rd harmonic), current
plot `disto2`:

| command | `Plotname:` lines in the file |
|---|---|
| `write w_cur_all.raw all` | `DISTORTION - 3rd harmonic` — **one plot** |
| `write w_named.raw disto1.all disto2.all` | both |
| `setplot disto1` / `write f all` / `set appendwrite` / `setplot disto2` / `write f all` | both |

**[A-M5] — NEW, and it closes the design-of-record's OPEN item M3.** The question was whether the
**bare** `write <file>` (no `all`, no names) drops vectors on a complex or multi-point plot,
because a capture walk emits the bare form. The deck:

```
* bare write vs write all
v1 in 0 dc 0 ac 1
r1 in mid 1k
c1 mid 0 1n
.control
set appendwrite
save all
ac dec 2 1k 10k
write w_bare.raw
write w_all.raw all
noise v(mid) v1 dec 2 1k 10k
write n_bare.raw
write n_all.raw all
setplot previous
write s_bare.raw
write s_all.raw all
.endc
.end
```

⚠ **`set appendwrite` is not optional in this probe.** Without it `write` TRUNCATES, and the first
two runs of the original experiment showed exactly one plot per file and would have been read as
*"the walk loses plots"*. The `setplot previous` pair is there on purpose: it is the exact shape
`PLAN.md` Stage 6's walk emits. Compare `No. Variables:` and `No. Points:` in each header pair —
re-run on the deck above:

| plot | `write f` | `write f all` |
|---|---|---|
| `AC Analysis` — complex, 3 points | `No. Variables: 4`, `No. Points: 3` | **identical** |
| `Integrated Noise` — real, 1 point | `No. Variables: 2`, `No. Points: 1` | **identical** |
| `Noise Spectral Density Curves` — after `setplot previous` | `No. Variables: 3`, `No. Points: 3` | **identical** |

(An earlier pass reported `7` variables for the AC plot on a larger deck it did not record. The
variable count is a property of the circuit, not of the write form; **what this measurement asserts
is that the two columns are equal**, and they are on every shape tried.)

**The bare form writes every vector of the current plot. A `setplot`-and-write walk loses
nothing.**

**Two variables together are a complete machine-readable results index**, and no dossier stated
them as a pair before `00-critique.md` §5.2 did:

* **`$plots`** — the list of every plot typename. Measured: `echo $plots` prints
  `const op1 disto1 disto2`. It is iterable with `foreach p $plots … end`.
* **`$curplotname`** — after `setplot <p>`, the **`Plotname:` literal** of `<p>`.

So `setplot $p` + `echo $curplotname` is a plot→analysis map **with no string construction and
no counter guessing**. That kills the whole "never assume `tran1`" class of problem.

⚠ **But the obvious `foreach $plots` capture loop writes `constants` FIRST** `[R-M2]`, and a
rawfile whose first plot is `constants` is one this tree's own reader rejects — `Title: Constant
values`, `Plotname: constants`, `No. Variables: 12`, `No. Points: 1`, and a `Date` identical to
the build stamp are all markers the ASE-L verdict proc treats as decisive. `destroy const` before
the loop is refused outright (`Error: can't destroy the constant plot`) and `$plots` is unchanged,
and there is no in-deck filter because `.control`'s `if` on strings takes the false branch both
ways. The shape that works is a **`setplot previous` walk** — a single-plot analysis emits
exactly what it emits today, and a multi-plot analysis appends `(nplots−1)` × {`setplot previous`;
`remzerovec`; `write <raw>`}. Measured `[R-M1]`: first plot in the file is genuine data, both
NOISE plots captured, the `op` write untouched.

**And the join must be positional, not by literal.** `[R-M11]`: two `sens` rows in one deck both
report `Sensitivity Analysis`; two rows of the same type collide the same way. The shape that
survives is a **creation-ordered sidecar** written by the deck itself:

```
echo "PLOT <type> <id> |$curplotname|" >> <cell>.plotmap
```

whose line *k* corresponds 1:1 to the rawfile's `Plotname:` record *k*. Measured `[R-M1]`:

```
PLOT noise n1 |Integrated Noise|
PLOT noise n1 |Noise Spectral Density Curves|
PLOT op o1 |Operating Point|
```

⚠ The sidecar file must be **deleted before every run**, exactly as the rawfile is, because `>>`
appends. And ⚠ **`[R-M19]`: a generated deck cannot build a plot list as a string** — the one
remaining escape (naming plots explicitly on a single `write` line, which *does* work when the
names are literal) cannot be generated from inside the deck, because `$` substitution swallows
the `.` in `$p.all`.

### 6.4 Scalars, and the one write that is special

Every scalar an analysis produces is **a one-point plot in the rawfile**: `Operating Point`,
`Integrated Noise`, `Transfer Function`, `Sensitivity Analysis` in DC mode. Reading them from the
raw is cheaper and more honest than parsing `print` output — and it is the only thing that gives
NOISE, TF and SENS a scalar home at all. The cost, and it is real: an arbitrary user-typed
**expression** like `v(a)*2` is **not** a vector in the raw, so a `print`-parsing path has to stay
for those.

⚠ **Device-parameter names on a write line are the GENERATOR of those vectors, not a filter over
vectors that exist.** `[R-M4]`, measured with `.save all` in the deck:

| command | result |
|---|---|
| `write raw all @m1[gm] @m1[id] @m1[vdsat]` | a **7-variable** OP plot carrying those three device vectors |
| `setplot op1` + `write raw all` | **zero** device vectors |

So a capture scheme that removes or relocates the per-analysis `op` write **destroys the
device-operating-point data**, and a bare `@dev` name on a *multi-point* write is silently wrong
— dims=1, one non-zero sample at index 0.

⚠ Related, and it is a known ngspice invocation asymmetry:
`doc/claude/issues/0434-bogus-save-card-failure-mode-depends-on-the-ngspice-invocation-idiom.md`
records that `ngspice -b -r out.raw deck.sp` **fabricates a column** for an unrecognised
`@…[id]`. The failure mode depends on the idiom.

### 6.5 The log stream — what is parseable, and the progress feed

**⚠ CORRECTION `[R-M8]` — `-b` is NOT progress-blind, and all three designs said it was.**
Measured: `tran 10n 20m` under plain `-b` printed **8** ` Reference value :  1.80112e-02` records
on stdout. The mechanism is `outitf.c:713, 727, 825, 828` — ` Reference value : % 12.5e\r`,
throttled to at most one per **0.25 s**, carrying the current scale value: simulation time for
TRAN, frequency for AC/NOISE/SP, sweep value for DC. A GUI that knows `tstop` can compute a
percentage for **tran, dc, ac, noise, disto and sp** — **wider coverage than libngspice's
`SendStat`**, which emits nothing at all for op, noise, disto, pz, tf and sens (`builds.md` §3.1).

Two reader rules: the records are **`\r`-terminated with no newline** (a line-oriented reader
blocks until the analysis ends — read by chunks and split on `\r`), and the feed is **suppressed**
by `-o` (which sets `orflag`), by `set norefvalue` / `.options norefvalue`, and when the process
is judged to be in the background. **A GUI showing a progress bar must not emit `norefprint`.**

**Markers worth matching**, in the order they appear:

* `Note: No compatibility mode selected!` — or a mode name.
* **`Circuit: <title line>`** — the best "the deck loaded" marker.
* `binary raw file "<name>"` / `ASCII raw file "<name>"`.
* `Doing analysis at TEMP = %f and TNOM = %f` — once per run.
* `Using SPARSE 1.3 as Direct Linear Solver` — **once per matrix setup**, so `.pz` prints it three
  times.
* `Warning: Interpolated raw file data!` under `set interp`.
* **`No. of Data Columns : <n>  `** (two trailing spaces) at the start of a plot — **`-r`/file
  path only**; **`No. of Data Rows : <n>`** at the end — **both paths**. ⚠ **Neither names the
  analysis.** Pair them by order with the plots in the rawfile.
* `Total analysis time (seconds) = <x>` / `Total elapsed time (seconds) = <x>` — a clean "run
  finished" marker.
* Errors: `Error on line <n> or its substitute:`; `    Simulation interrupted due to error!`;
  `Error: no data saved for <analysis description>; analysis not run`;
  `<what> simulation(s) aborted` / `interrupted` / `not started`; and **`doAnalyses: <reason>`**,
  whose reasons worth matching are `timestep too small`, `matrix is singular`,
  `iteration limit reached`, `matrix can't be decomposed as is`, `out of memory`,
  `no such analysis type`, `transmission lines not supported by pole-zero`,
  `ac input not found`, `no F2 source for IM disto analysis`, `transfer function is 1`,
  `pss failed`.
* `Warning: unrecognized variable - <name>` — a `.save` of a `@dev[param]` that did not resolve,
  emitted **only at the first data point**.
* ⚠ `Warning: singular matrix:  check node <name>` and the gmin/source-stepping notes appear and
  **the run still succeeds and exits 0** once a fallback works. They are not failure markers.

**Exit status.** `sp_shutdown()` maps `EXIT_NORMAL`=0, `EXIT_BAD`=1, `EXIT_INFO`=2→0. The
decision recorded upstream in this tree (`doc/codex/issues/0069`) is that **the exit status does
not change and `$sim_status` is the signal a deck should use**. ⚠ But §4.6 records that
`sim_status` is 0 for an interrupted run *and* for a non-converged OP — so the honest contract is
a `$sim_status` guard **after every analysis**, never once at the end. Measured: one guard at the
end gave rc 0 and a 2198-byte raw with the failure completely masked.

⚠ **Batch mode is entered three ways** (`main.c:1175-1180`): `--batch`, `-b < deck`, and
**`ngspice deck.cir < /dev/null`** — stdin not a tty is enough. This tree's own
`tests/regression/exitstatus/op-empty-notty.cir` pins that third route.

⚠ **Never use `-s` / `--server`.** Measured: the rawfile goes to stdout, `No. Points:` stays at
its placeholder, the true count is emitted **on stderr** as `@@@ <byteOffset> <count>`, and **the
log text is interleaved into the rawfile stream**. ngspice cannot read its own `-s` output back —
`raw_read()` aborts on the first `Note:` line.

**`-o log.txt`** merges stdout **and** stderr via `dup2` and sets `orflag`, killing the progress
feed. `-o` and `-s` together are useless.

### 6.6 Event-driven results — the digital half

XSPICE is **on by default in this build**, so a mixed-signal deck is an ordinary deck. `[R-M6]`
measured the whole path on an `adc_bridge → d_inverter → dac_bridge` chain:

* **Inventory:** `edisplay` prints a machine-readable list of the event nodes in the current
  plot — `din : d , 7` / `dout : d , 7` — with **no netlist parsing**. It is also the check that
  decides whether any of this is emitted at all.
* **Transport:** `eprvcd din dout > f.vcd` writes a **valid VCD** (`$timescale 1 ps`,
  `$var wire 1 ! din`, value changes).
* ⚠ **The rawfile is NOT a viable transport.** `write mx.raw all` contained
  `time i(adac) v(aout) v(in) i(vin)` and **not** `din`/`dout` — silently. Naming event nodes
  explicitly produces vectors declared `dims=10` while `No. Points: 119`, zero-padded and not
  truncated on read.
* Under `-b -r`, event data is **thrown away**: `EVTdiscard()` at `main.c:1567`, with the source's
  own comment "there is no way to use it".

**Two cautions a mixed deck is owed**: `trtol` is **silently forced to 1** whenever event nodes
exist (§2.1), which changes numbers; and the **DC-sweep + auto-bridge failure has a reproducer
and no root cause** (`xspice.md` §12.1), so `dc` on a deck with event nodes is *caution*, not
*ok*. **One refusal:** `.probe alli` on such a deck is fatal —
`Error: Dot command '.probe alli' and digital nodes are not compatible`.

### 6.7 Post-processing that produces results, not just pictures

These are **producers**, and they are the reason a "results" story is not only the waveform
viewer.

| verb | kind | produces | notes |
|---|---|---|---|
| `.four <f0> <vec>` | **card**, intercepted by the frontend before pass 2 | `fourierMN` 2-D vectors and a **`thdMN`** scalar, plus a printed harmonic table | The netlist parser *rejects* `.four` (`Use fourier command to obtain fourier analysis`) but `inp.c:820` intercepts it and `dotcards.c:407-421` runs it against the `tran` plot. **It works in batch, on transient data only.** Knobs: `nfreqs` (10), `nperiods` (1), `fourgridsize` (200), `polydegree` (1); ⚠ `fournosave` **removes the vectors** |
| `fourier <f0> <vec>` | command | same | the interactive equivalent |
| `fft` / `spec` | command | a new plot, `Plotname: Spectrum`, typename `spN` | needs a `tran` plot; `specwindow` and `specwindoworder` shape it |
| `psd` | command | `Plotname: PSD` | |
| `linearize` | command | `<old> (linearized)` | requires the current plot to be `tran*` |
| `meas` | command | ⚠ **a length-1 vector in the current plot**, via `com_let` | so a subsequent `write` carries it as an extra column with `dims=1`. **This is how a GUI gets numeric measurements back through the rawfile instead of scraping stdout**, and it is the strongest argument for the `.control` route over `-r` |
| `wrnodev <file>` | command | a ready-to-`.include` `.ic` file of the current node voltages | `convergence.md` §1.6 calls it "the closest thing ngspice has to Cadence's save/restore DC solution" |
| `wrs2p <file>` | command | Touchstone v1 | §2.11; needs the `.csparam Rbase=50` workaround |
| `diff <plot> <plot>` | command | a run-to-run comparison with `diff_abstol`/`diff_reltol`/`diff_vntol` | built-in regression comparison; zero dossiers found a use for it |

**`.meas` grammar traps** (`measure.md`), all four of which a form must encode:

* **`.meas` dot cards are REFUSED under `-r`**: `No .measure possible in batch mode (-b) with -r
  rawfile set!` followed by `Remove rawfile and use .print or .plot or ...`. **Use the `meas`
  command.**
* **`expr=` is broken** — do not offer it.
* **`param=` is one-shot per session** — it fails if the same circuit is re-run in one process
  (which a one-process-per-point runner never does).
* **The created vector carries only ~7 significant digits** (`"%e"` at `measure.c:138`). When full
  precision matters, redirect `meas … > file` and parse the printed line.

The `kind` vocabulary is `trigtarg` (delay), `find`/`when`, `avg`/`rms`/`min`/`max`/`pp`/`integ`,
`deriv`, `param`; expression fields accept `par('…')`.

⚠ **And the one that makes a phase margin wrong by 57×:** `set units=degrees` is **mandatory**
before any `meas` or plot that touches `vp()`, `ph()`, `cph()` or a phase (§2.5, `[R-M10]`).
`units` is a `CP_STRING` with values `radians` (default) and `degrees`.

Also under `-b -r`: `.four` and `.print` are ignored with
`.fourier line ignored since rawfile was produced.` / `.print line ignored since rawfile was
produced.`, and `.op`/`.tf` print `OP information in rawfile.` / `TF information in rawfile.`
instead of their tables. **Only `.save` among the dot cards still applies.**

---

### 6.8 Run control and result salvage — what a Stop keeps

**Provenance.** Every measurement in §6.8 was taken on **2026-09-10** by
`evidence/salvage.md`, against the same binary as the rest of this file
(`build-ver_50/src/ngspice`, `ngspice-46-419-gccebdf2a2`). That dossier quotes each deck in
full and carries the raw byte counts; this section is its reference half — the ngspice
facts, without the plan-side argument. Where the two differ, the dossier is the record.
Its reference deck throughout is an RC driven by a 1 kHz sine with four vectors in the
transient plot (`time`, `v(in)`, `v(out)`, `i(v1)`), so a row is 32 bytes: `tran 10n 80m`
→ 8,000,008 points, 256 MB, 7.84 s; `tran 10n 8m` → 800,008 points, 25.6 MB, 0.82 s.

⚠ **Two numbering spaces, and they collide.** `evidence/salvage.md` labels the three
*routes* it examined `S1` (`-r` streaming), `S2` (`stop`/`resume` checkpointing) and `S3`
(signal handling). Those are route labels from the quick pass that preceded it. **They are
not §7.2's `S<n>` defect ids**, which are this document's own and mean something else
entirely. §6.8 uses the mechanism names instead, and cites §7's ids only as §7's ids.

**The headline, because it reverses what §7.1 `X10` said until today:** a `-b` run **can**
keep what it has already computed. Not through `-r`, which a `.control` deck bypasses
(§6.8.3), but through `stop after` / `write` / `resume` inside the block itself (§6.8.4).
What `-b` cannot do is keep anything when a signal arrives, because it handles none
(§6.8.1). Those are two different statements and only the second one is a hard limit.

### 6.8.1 Signals: batch installs no handler at all

SOURCE, `src/main.c`. The whole signal block sits inside one guard:

```c
    /* Set up signal handling */
    if (!ft_batchmode) {
        /*  Set up interrupt handler  */
        signal(SIGINT, (SIGNAL_FUNCTION) ft_sigintr);
        /* floating point exception  */
        signal(SIGFPE, (SIGNAL_FUNCTION) sigfloat);
#ifdef SIGTSTP
        signal(SIGTSTP, (SIGNAL_FUNCTION) sigstop);
        signal(SIGCONT, (SIGNAL_FUNCTION) sigcont);
#endif
...
    }
```

SIGINT, SIGFPE, SIGTSTP, SIGCONT, SIGTTIN and SIGTTOU are installed **only** outside batch
mode. SIGTERM, SIGHUP and SIGQUIT are installed in **no** mode at all — a grep of the tree
finds SIGQUIT only in `com_shell.c` and `unixcom.c`, where it is saved and restored around
a child process.

MEASURED, one signal per row, sent 2 s into the 7.84 s run:

| signal | rc | rawfile on disk | deck's trailing echo |
|---|---|---|---|
| INT | 130 | none | no |
| TERM | 143 | none | no |
| HUP | 129 | none | no |
| QUIT | 131 | none | no |
| USR1 | 138 | none | no |
| USR2 | 140 | none | no |
| PIPE | 141 | none | no |

All seven take the default disposition and the process dies where it stands. Interactive
and `-p` are the other story: `ft_sigintr` **pauses** the run and `resume` continues it;
three presses reach `controlled_exit(1)`.

**There is no rationale to find.** Nothing in the tree trades salvage away for something
else; batch mode was written for scripted, non-interactive use where nobody presses Stop,
and the handler block was scoped to the interactive shell it was written for. A reader
looking for the benefit is looking for something that is not there.

⚠ **Latency, and what it does to the `-b` vs `-p` argument.** MEASURED, time from `kill`
to process exit, three runs each, mid-transient: **SIGTERM 5.6 / 4.5 / 5.3 ms**, **SIGKILL
5.0 / 5.2 / 5.5 ms**. The two are indistinguishable because nothing handles either.
⚠ **That figure is a moment in a run, not a constant** — two later sittings measured 0.4–0.6 ms
and 1.6–2.2 ms, and the mechanism is now known. It scales with what the run has accumulated in
memory, because the kernel is tearing down an address space: MEASURED, SIGKILL at three depths
into the same deck, **0.78–0.85 ms at 24 MB RSS, 1.83–2.14 ms at 62 MB, 3.84–5.15 ms at
177 MB**. And a `T0=$(date +%s%N); kill; wait; T1=$(date +%s%N)` harness charges its own two
fork/execs to ngspice — 4.21–4.46 ms the `date` way against 1.83–2.14 ms timed parent-side
across `waitpid`, at the same depth. **Read it as: a few milliseconds at worst, sub-millisecond
on a small run, TERM and KILL alike.** Time it in the parent, around the wait.
`evidence/builds.md` credits `-p` with "a graceful abort measured at under 5 ms", and §7.4
below repeats it — **batch already aborts in that time**. What `-p` buys on this axis is
not a *faster* abort. It is a **non-destructive** one: no checkpoint granularity, no torn
file, no `shell mv`, and the data still live in the process afterwards. Anyone comparing
the two transports on abort should compare that, not the milliseconds.

**What to send, and why.** SIGTERM first, SIGKILL after a short grace — not because ngspice
does anything with SIGTERM, but because a `shell` child may be running (§6.8.6) and because
SIGTERM is what a process-group teardown expects. The grace only has to cover a `mv`, so
~200 ms is generous. `rename(2)` is atomic in the kernel, so a kill landing on the whole
group during the rename leaves either the old file or the new one, never a mixture.

### 6.8.2 `-r` writes as it goes, and its header lies until the run ends

MEASURED, `ngspice -b -r out.raw deck.cir` on a **dot-card** deck (`.tran 10n 80m`):

| | |
|---|---|
| run to completion | 7.84 s wall, 256,000,537 bytes, `No. Points: 8000008` |
| SIGINT at 4 s | rc 130, **133,128,473 bytes already on disk**, `No. Points: 0` |
| repaired and loaded | 4,160,256 points, `maximum(time)` = **4.160248e-02** of the 0.08 s asked for |

52 % of the file is on disk at 51 % of the run. The stream is real; only the header is not.

SOURCE, `src/frontend/outitf.c`. `fileInit()` writes the count field as a placeholder and
remembers where it put it:

```c
    sprintf(buf, "No. Points: ");
    ...
    if (run->fp == stdout || (run->pointPos = ftell(run->fp)) <= 0)
        run->pointPos = (long) n;
    fprintf(run->fp, "0       \n"); /* Save 8 spaces here. */
```

`fileEnd()` — whose own comment is *"Here's the hack... Run back and fill in the number of
points"* — seeks to `pointPos` and writes `run->pointCount` with `%d`. Kill the process and
`fileEnd()` never runs, so `0` stands over a file full of valid data. This is the same
placeholder §6.1's `No. Points:` row describes, and the same shape §6.5 records for `-s`,
where the true count goes to stderr instead.

⚠ **The repair is two steps, not one.** The arithmetic is
`rows = floor(body_bytes / stride)` with `stride = No. Variables × 8` (×16 for
`Flags: complex`), body starting immediately after `Binary:\n`. **But the file usually does
not end on a row boundary, and the leftover bytes are fatal.** MEASURED, a 3-variable deck
(stride 24), three SIGINTs at random times: 1,710,421 rows with **8** leftover bytes;
1,191,594 rows with **16**; 1,783,808 rows with 0. Two in three tore. A 4-variable deck
never shows it, because its 32-byte row divides stdio's 4096-byte buffer exactly.

Skip the truncation and the loader does not drop the last row — it abandons the file:

```
Error: strange line in rawfile:
  load aborted.
no data read.
```

**Nothing is recovered.** That is §6.1's "any non-blank line the reader does not recognise
aborts the whole load", reached from the data side. So:

> 1. `No. Points:` ← `floor(body / stride)`, written into the reserved field.
> 2. `truncate` the file to `body_start + rows × stride`.

Both are in place; the body is never copied. The reserved field is 8 characters, which is
also the cap — see the defect below.

**The repair generalises**, MEASURED on all four shapes this tree can produce:

* **complex** — `.ac dec 2000000 1 1e6`, SIGINT at 3 s → 437,469,491 bytes, `Flags:
  complex`, stride 64; patched `0 → 6,835,456`; loads, four complex vectors,
  `frequency` reaching 2616.541 Hz of the 1 MHz sweep.
* **multi-plot** — `.op` + `.ac dec 20000 1 1e6` + `.tran 10n 80m`, SIGINT at 4 s →
  136,078,836 bytes holding three plots. ⚠ **The order on disk is `ac`, `op`, `tran`** —
  ngspice's dot-card execution order, not the deck's. Only the last plot is short; the
  first two carry correct counts and must be left alone. Patched on the transient only
  (`0 → 4,012,416`); loads as `const ac1 op1 tran1`.
* **a killed `write`**, which fails in the opposite direction — §6.8.6.

⚠ **UPSTREAM: `-b -r` corrupts its own output above 99,999,999 points** (§7.2 **S28**).
`fileInit()` reserves 8 characters and `fileEnd()` writes `%d` with no width, so a 9-digit
count eats the newline. MEASURED, `.tran 1n 100m` with `-r`, run to completion: 101.075 s,
3,200,000,569 bytes, stdout's own `No. of Data Rows : 100000008`, and on disk:

```
No. Variables: 4$
No. Points: 100000008Variables:$
	0	time	time$
```

ngspice will not load what ngspice just wrote (`strange line in rawfile` / `no data read`),
and it exits **0**. MEASURED recovery, needing no copy of the 3.2 GB body: overwrite the
first 8 digits with `99999999`, write `\n` over the 9th, truncate to
`body_start + 99999999 × stride`. The file then loads — 99,999,999 points, `maximum(time)`
= 9.999999e-02. **Nine points lost of 100,000,008.**

### 6.8.3 `-r` is not merely bypassed by a `.control` deck — it deletes the path

SOURCE, `src/main.c`'s batch arm: when `rflag` is set, `ft_dorun(ft_rawfile)` runs
**unconditionally**, after the deck has already been sourced — including after a `.control`
block ran every analysis and wrote every result itself. SOURCE, `src/frontend/runcoms.c` — ⚠ the
behaviour is in **`dosim()`**, not in `ft_dorun()`, which is a four-line wrapper doing nothing but
`return dosim("run", &wl)`; grep the wrapper and you find no `fopen`, no `unlink` and no `err`
mapping, and conclude this entry is false. `dosim()` opens the path before running anything:

```c
        else { /* binary */
            if ((rawfileFp = fopen(wl->wl_word, "wb")) == NULL) {
```

and on the way out:

```c
    if (rawfileFp) {
        if (ftell(rawfileFp) == 0) {
            (void) fclose(rawfileFp);
            if (wl) {
                (void) unlink(wl->wl_word);
            }
        }
    }
```

With no dot-card analysis left to run, nothing is written, `ftell` is 0, and the path is
unlinked.

MEASURED: a 32-byte file `victim.raw`; a deck whose `.control` block runs `tran` and then
`write victim.raw`; invoked as `ngspice -b -r victim.raw deck.cir`. The log prints
`binary raw file "…victim.raw"` **twice** — once for the block's own write, once for the
`-r` open. At exit: `ls: cannot access 'victim.raw': No such file or directory`, **rc 0**.

So on an ASE-L-shaped deck `-r` is not inert. It is a destructor pointed at whatever path
is named (§7.1 **X11**). A GUI that reaches for `-r` to get progress, or a fallback
rawfile, must point it at a path nothing else owns — and must not expect any content in it.

### 6.8.4 `stop` / `resume`: checkpointing that works in `-b`

SOURCE, `src/frontend/breakp.c`. `ft_bpcheck()` is called from `OUTpData()` — the generic
per-point output hook, not a transient-specific one — as
`ft_bpcheck(run->runPlot, run->pointCount)`. So the "iteration" a `stop after` counts is
**the written point count**, and the machinery reaches every analysis that emits points.

⚠ **`stop when` is NOT disarmed when it fires, and `resume` re-fires it immediately.**
MEASURED, the obvious checkpoint deck — `stop when time > 0.01`, `tran 10n 80m`, `write`,
`resume` — reproduces every line a reader would take as success: `1 : condition met: stop
when time > 0.01`, then the echoes after the `tran`, after the `write` and after the
`resume`, and a 32,000,573-byte rawfile holding a real 1,000,009-point plot. What it does
not report: **wall clock 1.24 s against 7.84 s unchecked**. Instrumented, after the `tran`
`status` still prints

```
1    stop when time > 0.01
```

— still armed. `resume` runs one timestep, `time > 0.01` is true again, and it stops.
`length(time)` after the resume: **1,000,010**. One point. The deck then falls off the end
of the block and exits **rc 0**, having simulated **12.5 %** of what it was asked for. The
only tells are on stderr: a second `condition met` line and `simulation interrupted`, both
of which read like the checkpoint working (§7.2 **S29**).

SOURCE, why `stop after` is different — the test is an equality, which cannot recur inside
one analysis:

```c
            case DB_STOPAFTER:
                if (iteration == dt->db_iteration)
```

Neither kind is ever removed from the list (`status` lists a fired `stop after` too), but
only `stop when` can re-fire.

⚠ **`stop when time > X` also changes the answer; `stop after N` does not.** SOURCE,
`com_stop()` treats a time condition specially:

```c
        /* If com_stop is called after tran simulation has already started, set a breakpoint
           if not in the past */
        if ((thisone->db_type == DB_STOPWHEN) && cieq(thisone->db_nodename1, "time")) {
            if (thisone->db_value2 > ft_curckt->ci_ckt->CKTtime) {
                CKTsetBreak(ft_curckt->ci_ckt, thisone->db_value2);
```

That is a real breakpoint handed to the integrator, and it forces a timepoint. MEASURED,
`tran 10n 8m`, bodies compared byte for byte against the unchecked run:

| checkpoint scheme | final rows | body sha256 vs unchecked |
|---|---|---|
| none | 800,008 | — |
| 3 × `stop after` | 800,008 | **identical** |
| 100 × `stop after` | 800,008 | **identical** |
| 1 × `stop when time` | 800,011 | different |
| 3 × `stop when time` | 800,017 | different |

`stop when time` costs **3 extra rows per checkpoint** and a different timestep grid from
the first checkpoint on — the trajectory shows the forced landing at
`t = 2.000000000000e-03` exactly, where the unchecked run steps past it. The physics is
unharmed (`max |Δv(out)| = 4.7e-13` at shared timepoints), but the point count and the
bytes are not, and anything comparing two runs sees a difference nobody asked for (§7.2
**S31**).

> **Checkpoint with `stop after <points>`. Never with `stop when time`.** The cost is that
> the interval is counted in **points**, not simulated time — §6.8.5 turns that into a
> number a GUI can pick.

**The in-memory plot accumulates, so a checkpoint is a prefix, not a segment.** MEASURED,
three `stop after` checkpoints on `tran 10n 8m`, each `write` to its own path:

| file | body bytes | rows | exact prefix of the final body? |
|---|---|---|---|
| checkpoint 1 | 6,400,000 | 200,000 | **yes** |
| checkpoint 2 | 12,800,000 | 400,000 | **yes** |
| checkpoint 3 | 19,200,000 | 600,000 | **yes** |
| final | 25,600,256 | 800,008 | (sha256 = unchecked run) |

Checkpoint *k* is everything from the start, byte for byte, so a later checkpoint written
over an earlier one at the same path loses nothing. **Unless `appendwrite` is set** — under
it, `write` to an existing path appends a plot instead of replacing the file. MEASURED,
three checkpoints and the final write to one path with `set appendwrite` in force:

```
No. Points: 200000
No. Points: 400000
No. Points: 600000
No. Points: 800008
```

Four stacked plots, **64,001,536 bytes** where the single plot is 25,600,541 — growth of
roughly `(N/2 + 1) ×` the final size, and a reader that fetches results by plot name no
longer finds the run's answer under `tran1` (§7.2 **S32**). MEASURED fix, and it works
mid-block: `unset appendwrite` around the checkpoint write, `set appendwrite` after it, and
send the checkpoint to **its own path**, never the results file.

**Which analyses honour it**, MEASURED:

| analysis | `stop when` | `stop after N` | `resume` | notes |
|---|---|---|---|---|
| `tran` | yes (`time > x`) | yes | yes | the reference case |
| `dc` | yes (`v(in) > 0.5`, fired at 500,002 pts) | yes | yes | `stop after` + resume → 1,000,000 pts, same as unchecked |
| `ac` | yes (`frequency > 1000`, fired at 300,002 pts) | yes | yes | |
| `op` | n/a | fires at 1 point | n/a | single point; nothing to salvage |
| `noise` | — | yes | yes | ⚠ see below |
| `disto` | — | yes, **once per pass** | yes | two `condition met` lines for one armed stop |

⚠ **`noise` and `disto` are salvaged as an incomplete plot SET, not a short plot.** MEASURED:
an unchecked `noise v(out) V1 dec 100000 1 1e6` leaves `noise1 noise2`; stopped mid-run it
leaves **`noise1` only**, and `resume` then produces `noise2`. `disto` has the same two-plot
shape. This is the invariant `evidence/ase-deck.md` §7.4 already flagged — "one analysis
produces one plot" is false for `noise` and `disto` — now with a second way to break it
(§7.2 **S33**).

⚠ **A stop armed once is armed for every later analysis in the same block.** MEASURED,
`stop after 200000` armed once, then `op`, `tran`, `ac`:

```
1 : condition met: stop  after 200000
tran simulation interrupted
nt = 2.000000e+05
 : condition met: stop  after 200000
ac simulation interrupted
na = 2.000000e+05
```

The `ac` was truncated to 200,000 of its 600,001 points, **rc 0** — `run->pointCount`
restarts per analysis, so the equality is satisfied again. MEASURED, the `stop when time`
version of the same leak: the `tran` stops correctly, then the `ac` evaluates a condition on
a vector its plot does not have, once per frequency point — **600,045 lines of
`Error: time: no such node`, a 15.6 MB log**, and the `ac` runs to completion anyway, rc 0
(§7.2 **S30**). **`delete all` before the next analysis, always**; MEASURED that it works,
and that a final `delete all` before the last `resume` lets the run finish clean.

⚠ **Nothing in the exit status or `$sim_status` says a run was checkpointed.** MEASURED,
the guard ASE-L already emits, verbatim, after a stopped `tran` with no resume:

```
tran simulation interrupted          <- stderr, from dosim() in runcoms.c
SIM-STATUS-IS 0
REACHED-END
```

`$sim_status` is **0**, the `write` ran, the deck reached its end, **rc 0**, and the rawfile
holds 200,000 points where 800,008 were asked for. SOURCE: `dosim()` — which `ft_dorun()` calls
— maps `err == 1` to
*"simulation interrupted"* and then sets `err = 0` — an interrupted run is deliberately not
an error, which is right for `-p`, where the user chose to stop. In `-b` it means the
existing guard cannot tell a complete run from a checkpointed one, and neither can rc. This
sharpens §7.2 **S27**. The only in-band tells are the stderr lines `N : condition met:
stop …` (`breakp.c`, `ft_bpcheck()`) and `<what> simulation interrupted` (`runcoms.c`,
`dosim()`). **A deck-emitted completion echo is the cheap, reliable marker** — infer
completeness from its absence, never from rc.

MEASURED, `remzerovec` is undisturbed by a stop: with `.options savecurrents`, a stopped
transient plot holds `@c1[i]`, `@r1[i]`, `in`, `out`, `time`, `v1#branch`, **all 200,000
long**; `remzerovec` removes nothing and the write succeeds. The zero-length-vector
condition of §3.4 Trap 4 / §7.3 **N15** is not created by a stop.

### 6.8.5 What a checkpoint costs, and how many to take

MEASURED, `tran 10n 8m` (800,008 points, 25.6 MB final), checkpoints spread evenly, three
runs each, wall seconds. Checkpoint *k* writes `k/(N+1)` of the final size, so N checkpoints
write **N/2 × final size** of extra bytes:

| N | extra bytes written | tmpfs | ext4 | overhead |
|---|---|---|---|---|
| 0 | 0 | 0.81 / 0.86 / 0.81 | 0.83 / 0.83 / 0.80 | — |
| 4 | 2 × 25.6 MB | 1.01 / 0.92 / 0.97 | 0.96 / 0.97 / 0.91 | +0.15 s (+18 %) |
| 20 | 10 × 25.6 MB | 1.42 / 1.46 / 1.44 | 1.42 / 1.44 / 1.44 | +0.61 s (+75 %) |
| 100 | 50 × 25.6 MB | 3.89 / 3.95 / 3.94 | 4.32 / 3.90 / 3.94 | +3.1 s (+380 %) |

Linear in bytes, and tmpfs and ext4 are the same because SOURCE: there is **no `fsync`
anywhere in `rawfile.c` or `outitf.c`**, only `fflush`. That is page-cache throughput.

⚠ **The model reproduces; the constants do not.** Two later sittings on the same machine, same
deck, best of five: N = 4 → **+8 %** and **+21 %**; N = 20 → **+60 %** and **+62 %**;
N = 100 → **+288 %** and **+299 %**, implying B = 510–540 MB/s — *above* what this section
first called a ceiling. So: **+8 to +21 % at N = 4, +60 to +75 % at N = 20, +288 to +380 % at
N = 100, three sittings on one machine.** **B is page-cache throughput that moved ±30 % between
sittings; it is a planning constant, not a bound.** The shape — extra bytes = N/2 × final size,
linear in bytes — is what survives, and everything below is derived from the shape. A *machine*
crash, as opposed to a kill, can still lose a checkpoint that `write` reported finished. The
atomic rename of §6.8.6 adds **≈ 4 ms per checkpoint** (0.08 s over 20) — two A/B sittings
measured 3.7 and 3.9 ms; an earlier pass recorded ≈ 12 ms and was three times too large.

**Choosing N.** Two costs pull against each other: a Stop at a uniformly random moment
wastes `T/(2(N+1))` of the simulated work, and the checkpoints cost `N × S / (2B)`.
Minimising the sum gives

> **N + 1 = sqrt(T × B / S)**

with T the expected runtime in seconds, S the expected rawfile size, B ≈ 400 MB/s. Worked
against the table: the reference deck (T = 0.82 s, S = 25.6 MB) gives N + 1 = 3.6, i.e.
**N = 3**, and N = 4 measures at +18 %. A ten-minute transistor-level transient producing a
200 MB rawfile gives N + 1 = sqrt(600 × 400 / 200) = 35 — a checkpoint every ~17 s, costing
8.3 s, **1.4 %**. The formula scales the right way because checkpoint cost depends only on
the rawfile, never on how hard the circuit is to solve.

**N = 4 is the defensible default** where T and S cannot be estimated, clamped to `[2, 50]`:
cheap in absolute terms, and it bounds the worst-case loss at **20 %**, which is the number
any warning has to quote.

**Converting N to `stop after` thresholds** needs a point-count estimate. MEASURED, for a
`tran tstep tstop` the count was `tstop/tstep + 8` (800,008 for `10n`/`8m`; 8,000,008 for
`10n`/`80m`), so `k × tstop/(tstep × (N+1))` is a good threshold. ⚠ That formula is measured
only on a deck with no breakpoints; `pulse`/`pwl` sources, `.options interp` or a max-step
setting will not match it. The adaptive form — read `length(time)` at the first checkpoint
and re-arm from the measured value — is written in §6.8.6 but was not exercised against a
deck whose count it could not predict.

### 6.8.6 The recipe, and the four ways it fails silently

⚠ **A kill during a `write` tears the file, and the loader recovers nothing** (§7.1
**X12**). MEASURED: a deck that finishes a 2,000,008-point transient and then writes the
same 64 MB rawfile 40 times in a `repeat` loop, `kill -9` at a random point inside the loop,
five times:

| run | file bytes | header says |
|---|---|---|
| 1 | 64,000,560 (complete) | `No. Points: 2000008` |
| 2 | 27,291,648 | `No. Points: 2000008` |
| 3 | 64,000,560 (complete) | `No. Points: 2000008` |
| 4 | **0** | — |
| 5 | 14,065,664 | `No. Points: 2000008` |

Two failure modes, both destructive. **The header over-claims** — SOURCE, `raw_write()` in
`rawfile.c` knows the length up front, because the vector is complete in memory, so it
writes `fprintf(fp, "No. Points: %d\n", length)` correctly and *then* streams the body. That
is the mirror image of §6.8.2, where `-r` under-claims, and ngspice's answer to it is:

```
Error: bad rawfile
  point 1727094, var v(out)
  load aborted
no data read.
```

1.7 million good points on disk and **nothing recovered**. (The §6.8.2 repair does fix this
mode: patched `2000008 → 1727094` and truncated, the file loads with `maximum(time)` =
1.727086e-02.) **Or the file is empty** — `fopen(path, "wb")` truncates before the first
byte is written, and run 4 was killed inside that window, destroying the previous good
checkpoint with nothing to fall back to. Nothing repairs that one.

**MEASURED fix: write to a temp path and rename.** `write <path>.tmp` +
`shell mv -f <path>.tmp <path>`, six `kill -9`s at random points in the same loop —
`safe.raw` was complete and loaded with **zero** errors **6 for 6**; the damage was confined
to the `.tmp` (torn at 63.5 MB, 6.2 MB, 48.8 MB, 30.3 MB, 9.7 MB in five of the six), which
the GUI sweeps at the next run.

⚠ **SOURCE, stated flatly because it decides who owns the rename: ngspice has no rename,
move or copy primitive.** `spcp_coms[]` in `src/frontend/commands.c` offers `write`,
`hardcopy`, `cdump`, `eprvcd`, `fopen`/`fread`/`fclose`, `cd`, `getcwd` — and `shell`. There
is no option on `write` that writes elsewhere and renames. The atomicity comes from
`shell mv` in the deck, or from the GUI checkpointing into a path it renames itself. It
cannot come from ngspice. (⚠ `com_shell` runs `cmd` on a Windows build, where `mv -f` is
not a builtin; on that platform the rename has to move into the GUI.)

**The recipe, MEASURED end to end** — one `.control` block, `set appendwrite`, `op` then
`ac` then a checkpointed `tran`, guard + `remzerovec` + `write` per analysis:

```
.control
set appendwrite
let ckstep = 400000          <- ALL THREE before the first analysis: trap (a).
let cknext  = ckstep            A `let` made after `tran` lands in tran1 and is
let ckdone  = 0                 WRITTEN INTO every file the loop writes.
set  cktgt  = $&cknext       <- and go through a `set` variable: trap (b)

op
<guard>
remzerovec
write <rundir>/<cell>_ase.raw

ac dec 1000 1 1e6
<guard>
remzerovec
write <rundir>/<cell>_ase.raw

stop after $cktgt
tran 10n 80m
while ckdone = 0
  unset appendwrite
  remzerovec
  write <rundir>/<cell>_ase.raw.ckpt.tmp
  shell mv -f <rundir>/<cell>_ase.raw.ckpt.tmp <rundir>/<cell>_ase.raw.ckpt
  set appendwrite
  echo CKPT-DONE $cktgt
  let cknext = cknext + ckstep
  set cktgt = $&cknext
  if cknext < <total>
    stop after $cktgt
    resume
  else
    let ckdone = 1
    delete all
    resume
  end
end
<guard>
remzerovec
write <rundir>/<cell>_ase.raw
echo ASE-RUN-COMPLETE
.endc
```

MEASURED, that deck verbatim against `tran 10n 80m` with `ckstep = 1600000`, killed with
SIGTERM at 6 s — **rc 143**:

* the log carries a per-checkpoint echo at 1,600,000, 3,200,000 and 4,800,000 and **no**
  `Syntax error`, **no** `no such variable`, **no** failed guard;
* `<cell>_ase.raw` is 384,650 bytes holding the completed `op` (1 point) and `ac` (6,001
  points) plots, **intact** — `load` gives `const op1 ac1`;
* `<cell>_ase.raw.ckpt` is **153,600,270** bytes holding **one** transient plot of 4,800,000
  points; `load` gives `const tran1`, `maximum(time)` = **4.799992e-02** of the 0.08 s asked
  for — **60 % of the run kept out of a hard kill**. ⚠ Check that against the arithmetic before
  quoting it: 4,800,000 rows × 4 vectors × 8 bytes = 153,600,000 plus a short header. This line
  read **192,000,311** until 2026-09-10 — 40 bytes a row, i.e. *five* vectors — which is what
  the recipe's misplaced `ckdone` was costing, in plain sight;
* whether a `.tmp` survives depends on where the kill lands: this run left none, a re-run
  killed mid-write left a torn one beside an **intact** previous checkpoint, which is §6.8.6's
  rename working. The GUI sweeps it either way;
* ⚠ the per-checkpoint echoes are **not** a progress signal under a kill — ngspice's stdout is
  block-buffered when redirected, so the last echoes can die in the buffer. The *completion*
  marker is unaffected, because what is read is its **absence**;
* `ASE-RUN-COMPLETE` **absent**, which is the only thing that says the run was aborted,
  because rc and `$sim_status` will not (§6.8.4).

Seven properties, each measured — and the first holds **only with the counters where they now
are**; with `let ckdone = 0` after the `tran`, as this recipe printed it until 2026-09-10, the
final file carries a fifth vector and is byte-identical to nothing: the final result is
byte-identical to an unchecked run (re-verified after the counter moved: `No. Variables: 4`,
final body sha256 `b9836c494d9d52ad`, the unchecked run's);
each checkpoint is an exact prefix of the final; the checkpoint file holds exactly one plot;
the results file is never touched by a checkpoint; a kill at any instant leaves the
checkpoint loadable; `$sim_status` and `remzerovec` are undisturbed; `delete all` before the
final `resume` keeps the run from stopping again.

⚠ **Trap (a) — a `let` counter created after an analysis is invisible to the next one**
(§7.3 **N22**). MEASURED:

```
created a while curplot = const
after op, curplot = op1 ; a = 111
created b while curplot = op1
after tran, curplot = tran1
  a = 111
  b =                        <- Error: &b: no such variable.
  const.a = 111
```

Vectors created before any analysis land in the `const` plot and are visible from every
later plot. Created while `op1`/`ac1` is current they land *there* and vanish when `tran1`
becomes current. Written the natural way — counters next to the `tran`, after `op` and `ac`
— `let cknext = cknext + ckstep` fails with `Error: RHS "cknext + ckstep" invalid`, the
counter never advances, no further checkpoint is armed, and the deck carries on at **rc 0**.
**Create the counters at the top of the block, before the first analysis**, or prefix them
with a plot name.

⚠ **The trap has a second half, and it is the one that ships.** A counter created after the
`tran` is not merely invisible to the *next* plot — it is a vector **of the current plot**, so
every `write` from that point on emits it. MEASURED, `let ckdone = 0` between `tran 10n 800u`
and the checkpoint loop: the rawfile carries `No. Variables: 5` and a
`	1	ckdone	notype dims=1` column beside `time`, `v(in)`, `v(out)`, `i(v1)` — in the
checkpoint *and* in `<cell>_ase.raw`, which ASE-L reads by enumerating a plot's vectors. Moved
up beside the other two counters, the same deck gives `No. Variables: 4` and `let ckdone = 1`
updates the `const` vector in place. **The counter must be in `const` for correctness of the
output, not only for the loop to work.**

⚠ **Trap (b) — `stop after $&vec` breaks above 1,000,000 points** (§7.3 **N21**). SOURCE:
`com_stop()` parses the `after` argument digit by digit (`if (!isdigit_c(*s)) goto bad;`).
MEASURED, how a computed number reaches the command line:

| value | `$&x` | `set s = $&x` → `$s` |
|---|---|---|
| 7 | `7` | `7` |
| 1500000 | **`1.5E+06`** | `1500000` |
| 1234567 | **`1.23457E+06`** | `1234570` |
| 12345678 | **`1.23457E+07`** | `12345700` |
| 100000000 | **`1E+08`** | `100000000` |

MEASURED consequence: `stop after $&big` with `big = 1200000` prints **`Syntax error parsing
breakpoint specification.`**, arms nothing, and the run continues to completion at rc 0 with
no checkpoint at all. Through a `set` variable it arms correctly and fires at 1,200,000
points — and **rounds to 6 significant figures** (1,234,567 → 1,234,570), which is harmless
for a threshold but means the threshold is approximate. This is exactly the regime
checkpointing exists for: a loop tested only on short runs passes, and stops checkpointing
the moment the run is long enough to matter.

⚠ **Trap (c)** is `appendwrite` stacking the checkpoints into the results file (§6.8.4), and
⚠ **trap (d)** is the armed stop leaking into the next analysis (§6.8.4). Both are rc 0.

### 6.8.7 Where salvage is unavailable, or simply unmeasured

Listed plainly so the next reader does not mistake silence for coverage. **None of these
carries an `M<n>` id** — §8's numbering space is shared with `LEDGER.md` and
`evidence/design-of-record.md` §16, and minting into it from here is how `M13` collided
once already.

1. **`pss`, `sp`, `pz`, `sens`, `tf` were not checkpointed at all.** `evidence/builds.md`
   item 3 records that `sens` does not honour `bg_halt` and that `pz` likely cannot be
   interrupted. Those are the analyses where salvage may simply not exist, and a GUI needs
   the list before it promises anything.
2. **Every measurement above is an RC.** The byte-identity result for `stop after` is the
   one most worth re-confirming on a transistor-level deck: the mechanism says it should
   hold (`stop after` never touches `CKTsetBreak`), but it was proved only where the
   timestep is not LTE-limited.
3. **The `tstop/tstep + 8` point-count estimate** held exactly on this deck and will not
   hold on a deck with breakpoints, `interp`, or a max-step setting (§6.8.5).
4. **A full checkpoint loop against `dc` or `ac`.** Both stop and resume correctly
   (§6.8.4); neither was run through the whole §6.8.6 recipe, and `dc`'s sweep-variable
   plot may interact with the `unset appendwrite` dance differently.
5. **Writeback under memory pressure.** 410 MB/s is page-cache throughput on a machine with
   9 GB free; a rawfile approaching RAM will hit dirty-page throttling and the cost model
   will understate.
6. **`shell mv` on Windows** (§6.8.6).
7. **The 9-digit `No. Points:` defect is not filed upstream.** It is measured and
   reproducible (§6.8.2, §7.2 **S28**) and belongs in `doc/codex/issues/` in the ngspice
   tree; nobody has written it there.

---

## 7. The trap and defect register

Every crash, hang, silent wrong answer and silent no-op found across the whole pass, with its
repro and its anchor. **The `class` column separates the two things a plan must do differently:**

* **UPSTREAM** — a genuine ngspice defect worth **filing separately**. The GUI still has to route
  around it, but the fix belongs in ngspice and the report belongs upstream.
* **ROUTE-AROUND** — behaviour that is arguably correct, or documented, or too entangled to
  change; the GUI simply must not walk into it.
* **DOC** — the manual or `src/ngspice.txt` disagrees with the code. Trust the code.

### 7.1 Crashes, hangs and aborts

| id | class | what | repro | anchor |
|---|---|---|---|---|
| **X1** | **UPSTREAM** ☠ | **`.disto` SIGSEGVs (rc 139) when its save list resolves to nothing.** `DISTOan` discards `OUTpBeginPlot`'s return at **five** sites; `beginPlot()` returns `E_NOTFOUND`, leaves `acPlot` NULL, and the next `OUTattributes` dereferences it | `.control` / `save v(nosuchnode)` / `disto dec 2 1k 10k` — rc 139. Also `.op`+`.disto` and `.tf`+`.disto` as dot cards. **A `.control` deck with `disto` and NO save returns rc 0** | `distoan.c:516,540,563,584,606` vs the correct `acan.c:169-175`. **[A-M6]: reproduced on `/usr/bin/ngspice` 45.2 — it is upstream, not a fork artifact.** The one-line fix is to capture and check `error` at all five sites |
| **X2** | **UPSTREAM** ☠ | **`sens … ac` under `option klu` SIGSEGVs.** The KLU refusal guard is **commented out** | `sens v(mid) r1 r2` + `ac dec 1 1k 10k` + `.options klu` → rc 139. `sens … dc` under KLU is **safe and identical to sparse** | `cktsens.c:97-105` (the commented guard). NOISE and PZ refuse KLU cleanly with `E_UNSUPP` |
| **X3** | **UPSTREAM** ☠ | **PSS `harmonics = 0` SIGSEGVs with no message; `harmonics = 1` spins forever at 199 % CPU.** `pssResults` is `harms × msize` and `pssfreqs` is `harms` long, both indexed out of bounds before the correcting loop, then `DCpss(ckt,1)` re-enters with no depth limit | `pss 2G 10n bout 1024 0 5 5e-3 uic` → rc 139, stdout truncated mid-line. `harmonics 1` → killed at 240 s | `dcpss.c:979-996`. Needs `--enable-pss` to reach |
| **X4** | **UPSTREAM** ☠ | **A negative `TS` in `trnoise` HANGS ngspice forever.** `n1 = (size_t) floor(time/TS)` goes hugely positive and `while (index >= this->top) trnoise_state_gen(...)` never terminates | `v1 … trnoise(1m -1u 0 0)` + `tran` → rc 124 under `timeout 20`, no output, no diagnostic | `vsrcload.c:409`, `1-f-code.h:52-53`. Contrast `trrandom`, where a negative/zero `TS` fails cleanly |
| **X5** | **UPSTREAM** ☠ | **Two `.sens` CARDS abort the process**: rc 134, `malloc(): unsorted double linked list corrupted`. Almost certainly the process-global `Sens_filter`, freed and rebuilt per card **while leaking its strings** | `.sens v(mid) r1` + `.sens v(mid) r2` + `.control run` → rc 134. Two `sens` **commands** → rc 0, both run | `cktsens.c:33`, `inp2dot.c:533-534`. **The `.control` route dodges it** |
| **X6** | ROUTE-AROUND ☠ | **`sp` with fewer than two ports calls `controlled_exit(EXIT_BAD)` — the whole process dies, exit code 1, and the `.control` block never resumes.** A `run_done` that only reads rc may still see 0 if an earlier analysis succeeded | `sp lin 3 1e8 1e9` with no `portnum` → `Error: No RF Port is present, cannot run sp analysis` + `ERROR: fatal error in ngspice, exit(1)` | `span.c:376-386`. Satisfiable in the deck: §2.11's `alter portnum` route |
| **X7** | ROUTE-AROUND ☠ | **`.options klu` on a CIDER netlist calls `exit(1)`**, and every later `.control` command is skipped | any CIDER device + `.options klu` + `ac` → `Error: CIDER NUMDadmittance small signal simulation is not (yet) supported with 'option klu'.` + `ERROR: fatal error in ngspice, exit(1)`, rc 1 | `small_signal_check()`; `builds.md` §2.3. **Never emit `.options klu` on such a deck** |
| **X8** | ROUTE-AROUND ☠ | **`trrandom` with `TS <= 0` is fatal** | `trrandom(2 0 0 1)` → `doAnalyses: impossible error - can't occur` (E_PANIC out of `CKTsetBreak`) | `trnoise.md` §1.2 |
| **X9** | **UPSTREAM** ⚠ | **Out-of-bounds heap read on a short `trnoise`/`trrandom` argument list.** `vsrcpar.c:236-237` and `:274-275` read `coeffs[0]` and `coeffs[1]` with **no `numValue < 2` guard**, unlike `SINE`/`EXP`/`PULSE` | `trnoise(1m)` is accepted and produces silent 0 output; `trrandom(2)` produces the E_PANIC message. Both read past a 1-element `TMALLOC` | `vsrcpar.c:92-93` shows the guarded pattern |
| **X10** | ROUTE-AROUND | **In batch mode ngspice installs NO signal handlers; SIGINT is immediately fatal.** `main.c:1217-1220` guards the whole `signal()` block on `if (!ft_batchmode)` | `tran 1n 200m` in `.control`, one SIGINT after 3 s → the process dies on the **first** signal, **rc 130, no rawfile written**, the `write` after the `tran` never runs | Interactive/`-p`: `ft_sigintr` **pauses** the run, resumable with `resume`; 3 presses `controlled_exit(1)`. Same story for SIGFPE (rc 136 in batch). ⚠ **CORRECTED 2026-09-10:** this row used to end *"a GUI must never promise 'stop and keep what you have' for a `-b` run"*, and that is too strong. **The signal is unsurvivable; the run is not.** A `-b` deck that checkpoints itself with `stop after` / `write` / `resume` keeps everything up to its last checkpoint through a `kill -9` — measured, **§6.8.4** and **§6.8.6**. What a GUI must never promise is salvage of the work done *since* that checkpoint, and it must send SIGTERM before SIGKILL so a `shell mv` can finish (§6.8.1). **Every** signal is fatal in batch, not only SIGINT: TERM 143, HUP 129, QUIT 131, USR1 138, USR2 140, PIPE 141, all with no file (§6.8.1) |
| **X11** | ROUTE-AROUND ☠ | **`ngspice -b -r <path>` DELETES `<path>` when a `.control` block ran the analyses.** `main.c`'s batch arm calls `ft_dorun(ft_rawfile)` unconditionally after the deck is sourced; **`dosim()`**, which that wrapper calls, opens the path `"wb"` before running anything and, finding `ftell == 0` on the way out, `fclose`s and `unlink`s it | a deck whose `.control` block runs `tran` and `write victim.raw`, invoked as `ngspice -b -r victim.raw deck.cir`: the log prints `binary raw file "…victim.raw"` **twice**, and at exit the file — good, 32 bytes, written by the block itself — is **gone**, **rc 0** | `main.c` batch arm; `runcoms.c`, `dosim()` (not the `ft_dorun()` wrapper). §6.8.3. **Never point `-r` at a path anything else owns**, and expect no content in it on a `.control` deck |
| **X12** | ROUTE-AROUND ☠ | **A kill during a `write` destroys the checkpoint, in either of two ways, and the loader recovers nothing.** `raw_write()` knows the vector length up front, so it writes a **correct** `No. Points:` and *then* streams — a truncated file therefore **over-claims** (the mirror image of `-r`'s under-claim). And `fopen(path, "wb")` truncates before the first byte, so a kill inside that window leaves **0 bytes** where the previous good checkpoint was | 40 writes of a 64 MB rawfile in a `repeat` loop, `kill -9` at a random point, five times → two complete, two torn (27,291,648 and 14,065,664 bytes, both headed `No. Points: 2000008`), one **0-byte**. `load` on a torn one: `Error: bad rawfile / point 1727094, var v(out) / load aborted / no data read.` — 1.7 M good points, **nothing** returned | `rawfile.c`, `raw_write()`. §6.8.6. Fix measured 6/6: `write <path>.tmp` + `shell mv -f`. ⚠ **ngspice has no rename, move or copy primitive** — `spcp_coms[]` offers only `shell` — so the atomicity comes from the deck or from the GUI, never from ngspice. The §6.8.2 repair fixes the over-claiming mode; nothing fixes the 0-byte one |

### 7.2 Silent wrong answers

| id | class | what | repro / measurement |
|---|---|---|---|
| **S1** | **UPSTREAM** | **`ac lin 2 <f1> <f2>` yields ONE point.** `if (job->ACnumberSteps - 1 > 1)` — `2−1` is not `> 1` | [A-M2]: `ac lin 2 1k 11k` → `No. of Data Rows : 1`; `lin 3` → 3. `acan.c:103-114`. **`.sp` has the identical shape** (`span.c:417-427`) |
| **S2** | **UPSTREAM** | **`sens … ac lin` produces a GEOMETRIC sweep.** `inc_freq` tests against the `#define LINEAR 3` pulled in from `noisedef.h`, not `SENS_LINEAR` (15), so the test is always true | `sens v(out) ac lin 5 1k 5k` swept **1e3, 8e5, 6.4e8, 5.12e11, 4.096e14 Hz** — each × 800. `cktsens.c:828-837` |
| **S3** | **UPSTREAM** | **`.options defas=<v>` sets the drain area.** `case OPT_DEFAS: task->TSKdefaultMosAD = val->rValue;` | re-read this pass at `cktsopt.c:111-113` |
| **S4** | **UPSTREAM** | **`.options klu_memgrow_factor=<v>` stores a boolean.** `TSKkluMemGrowFactor = (val->rValue == 1.2)` into a `double` | `cktsopt.c:186-188`. **Do not offer the field** |
| **S5** | **UPSTREAM** | **`portnum` cannot be read back** — declared `IF_INTEGER`, answered as `rValue`, read as `iValue` | `show v1 : all` reports `portnum 0` for a source declared `portnum 1`. `vsrc.c:32` vs `vsrcask.c:160-162` |
| **S6** | **UPSTREAM** | **The SP `phase` parameter has no effect on anything.** `VSRCportPhaseRad` is written and read nowhere | `grep -rn VSRCportPhaseRad src` → one write at `vsrctemp.c:96` |
| **S7** | **UPSTREAM** | **PSS `oscnode` steers nothing** — assigned and never read | `dcpss.c:126`. And [`builds.md` §1.7] a *nonexistent* `oscnode` runs normally |
| **S8** | **UPSTREAM** | **PSS `Convergence not reached` returns rc 0 with both plots full of plausible data.** And `steady_coeff = 1e-9` produced a **false `Convergence reached` 4.5 % wrong** | `builds.md` §1.4. **rc is not a success signal; scrape stdout** |
| **S9** | **UPSTREAM** | **`.pz` `keepopinfo` labels its OP plot `Distortion Operating Point`** | `pzan.c:57-61`, a copy-paste from `distoan.c:106-110` |
| **S10** | **UPSTREAM** | **`help tf` prints the transient help** | [A-M1], re-measured: `tf [.tran line args] : Do a transient analysis.` |
| **S11** | **UPSTREAM** | **`help all` truncates at the first NULL `co_func`** and omits 17 commands | `com_help.c:56`; [crit §3.2] measured 115 lines |
| **S12** | **UPSTREAM** | **The AC/NOISE/DISTO `stop` setters write `<X>startFreq` on error**, not `stopFreq` | `acsetp.c:34-39`, `nsetparm.c:61-69`, `dsetparm.c:34-42` — the same slip three times |
| **S13** | ROUTE-AROUND | **An AC run with no AC source runs to completion and reports zeros with no warning** | measured; there is no check in the code. §2.5 |
| **S14** | ROUTE-AROUND | **A DISTO run with no `distof*` source produces meaningless zero plots with no warning** | measured; §2.9 |
| **S15** | ROUTE-AROUND | **`.dc` with `start > stop` and a positive step produces ZERO rows, `$sim_status = 0`** | `dctrcurv.c:213-264`; §2.3 |
| **S16** | ROUTE-AROUND | **A third `.dc` triple is silently dropped** | `.dc a 0 1 1 b 0 1 1 c 0 1 1` → 4 rows, no warning |
| **S17** | ROUTE-AROUND | **`.ac` silently rewrites `fstop` to `1000 × fstart` when `fstop < fstart`**, `numsteps < 1` to 10, and `fstart < 0` to 1.0 — with one warning that names neither field nor value | `inp2dot.c:204-243`; §2.5 |
| **S18** | ROUTE-AROUND | **`.options seed=<n>` turns Monte Carlo into N copies of one sample**, because `eval_opt()` re-runs on every `reset`/`mc_source` | measured: six runs all `1.013170e+03`. §4.4 Trap B |
| **S19** | ROUTE-AROUND | **The first parse of a deck with netlist-level random functions is irreproducible** — `initw()` does `srand(getpid())` after `main.c` set a deterministic seed | measured over three invocations. §4.4 Trap A |
| **S20** | ROUTE-AROUND | **One source carries exactly one transient function; the last one on the line silently wins**, and `alter … trnoise=` destroys a `sin(...)` the source had | measured both directions. §5.5 |
| **S21** | ROUTE-AROUND | **`trnoise` `NALPHA = 2.0` yields exactly zero 1/f output** (σ = 1.37e-18); **`NALPHA = 0` silently discards `NAMP`** | `1-f-code.c:51`, `vsrcpar.c:242`. This is what breaks the shipped `simple-noise.cir` |
| **S22** | ROUTE-AROUND | **`trrandom` with an out-of-range `TYPE` emits 0 for ever**; and a `trrandom` source with no `dc` value **shifts the operating point by `PARAM2`** (measured 5 V) | `1-f-code.h:94-97`; `trnoise.md` §6.1 |
| **S23** | ROUTE-AROUND | **`optran` injects a random `trrandom` draw into the operating point** — measured 34.85 mV where the normal ladder gives 0 | `trnoise.md` §6.2 |
| **S24** | ROUTE-AROUND | **A bare `@dev` name on a multi-point write is silently wrong**: dims=1, one non-zero sample at index 0 | §6.4 |
| **S25** | ROUTE-AROUND | **`setplot <name>` that matches nothing silently leaves the current plot**, and a `plotname.` prefix that matches nothing silently reads the current plot | [A-M9]; `vectors.c:809-811` |
| **S26** | ROUTE-AROUND | **`.control`'s `if` on strings takes the FALSE branch for both `eq` and `ne`** | `[B-M5]`. There is no in-deck string test |
| **S27** | ROUTE-AROUND | **`sim_status` is 0 for an interrupted run and 0 for a non-converged OP with `singular matrix` warnings** — ⚠ **and 0 after a `stop` fires**, so a checkpointed partial run is indistinguishable from a complete one. SOURCE: `dosim()` (which `ft_dorun()` calls) maps `err == 1` to *"simulation interrupted"* and then sets `err = 0`; an interrupted run is deliberately not an error. Measured on a stopped `tran`: `SIM-STATUS-IS 0`, `REACHED-END`, the `write` ran, **rc 0**, 200,000 points where 800,008 were asked for | `orchestration.md` §9.4; §6.8.4. **Completeness needs a deck-emitted echo after the last analysis** — its absence is the only reliable marker |
| **S28** | **UPSTREAM** | **`ngspice -b -r` corrupts its own output above 99,999,999 points.** `fileInit()` reserves 8 characters for the count (`"0       \n"`) and `fileEnd()` back-fills it with `%d` and no width, so a 9-digit count eats the newline | measured end to end: `.tran 1n 100m` with `-r`, 101.075 s, 3,200,000,569 bytes, header reading `No. Points: 100000008Variables:` — and ngspice refuses to load what ngspice just wrote (`strange line in rawfile` / `no data read`), **rc 0**. Zero-copy recovery measured: patch to `99999999`, `\n` over the 9th byte, truncate — 9 points lost of 100,000,008. §6.8.2. **Not yet filed in `doc/codex/issues/`** |
| **S29** | ROUTE-AROUND | **`stop when` is not disarmed when it fires, so `resume` re-fires it one point later** — and the deck exits **rc 0** having simulated a fraction of what it was asked for | measured: `stop when time > 0.01` + `tran 10n 80m` + `write` + `resume` printed every line that reads like success, took **1.24 s against 7.84 s unchecked**, and covered **12.5 %** of the run. `status` still lists the stop after it fires; `length(time)` went 1,000,009 → **1,000,010** across the `resume`. The two `condition met` lines are the re-fire, not a duplicate. `breakp.c`, `ft_bpcheck()`: the `DB_STOPAFTER` arm is an equality and cannot recur, `DB_STOPWHEN` can. §6.8.4. **Checkpoint with `stop after <points>`, never with `stop when`** |
| **S30** | ROUTE-AROUND | **A stop armed once stays armed for every later analysis in the same `.control` block** — `run->pointCount` restarts per analysis, so the equality is satisfied again | measured: `stop after 200000` armed once truncated the `tran` **and** the following `ac` (200,000 of 600,001 points), **rc 0**. The `stop when time` version is worse: the `ac` evaluates `time` against a plot that has none, once per frequency point — **600,045 lines of `Error: time: no such node`, a 15.6 MB log** — and completes anyway, rc 0. §6.8.4 — ASE-L runs op/dc/ac/tran in one block, so **`delete all` between analyses is mandatory**, and again before the final `resume` |
| **S31** | ROUTE-AROUND | **`stop when time > X` changes the numbers; `stop after N` does not.** `com_stop()` calls `CKTsetBreak()` for a time condition, which forces a timepoint the unchecked run would have stepped past | measured on `tran 10n 8m`: 3 and 100 `stop after` checkpoints give a body whose **sha256 is identical** to the unchecked run; one `stop when time` gives 800,011 rows, three give 800,017, and the grid differs from the first checkpoint on. The physics survives (`max \|Δv(out)\| = 4.7e-13` at shared timepoints) — the byte count and the point count do not. `breakp.c`, `com_stop()`. §6.8.4 |
| **S32** | ROUTE-AROUND | **Under `appendwrite`, a checkpoint `write` STACKS plots instead of replacing the file**, and readback by plot name stops finding the run's answer | measured, ASE-L's own deck shape: three checkpoints + the final write to one path produced **four** plots (`No. Points:` 200000 / 400000 / 600000 / 800008) totalling **64,001,536 bytes** where one plot is 25,600,541 — growth of ≈ `(N/2 + 1) ×` the final size. Fix measured, and it works mid-block: `unset appendwrite` around the checkpoint write, `set appendwrite` after, and the checkpoint to **its own path**. §6.8.4 — without `appendwrite` the accumulate-and-overwrite property holds byte-exactly — each checkpoint is an exact prefix of the final |
| **S33** | ROUTE-AROUND | **A salvaged `noise` or `disto` is missing a PLOT, not merely short** | measured: an unchecked `noise v(out) V1 dec 100000 1 1e6` leaves `noise1 noise2`; stopped mid-run it leaves **`noise1` only**, and `resume` then produces `noise2`. `disto` has the same two-plot shape and fires a `stop after` **once per pass**. §6.8.4, and the same invariant `evidence/ase-deck.md` §7.4 flagged. A GUI must not present these two as truncated when they are incomplete |

### 7.3 Silent no-ops

| id | class | what | anchor |
|---|---|---|---|
| **N1** | **UPSTREAM** | **`.options oldlimit` is dropped on the `.control` route** — `TSKfixLimit` is never copied | `cktntask.c:68`, verified this pass as a bare comment |
| **N2** | ROUTE-AROUND | **`itl1`/`itl2`/`itl4` below 100 do nothing** — every `NIiter()` caller is floored | `niiter.c:37-39` |
| **N3** | ROUTE-AROUND | **`itl3`/`itl5` do nothing** — empty `case` arms | `cktsopt.c:83`, `:88` |
| **N4** | **DOC** | **`ramptime` ramps nothing** — the live code is behind `#ifdef XSPICE_EXP`, defined nowhere. ⚠ `convergence.md` §10.4 says otherwise and is wrong | verified: 0 definitions tree-wide |
| **N5** | **DOC** | **`nosavecurrents` does not exist** — documented by manual §13.7, **0 hits in the tree** | verified this pass |
| **N6** | ROUTE-AROUND | **`newtrunc` needs `PREDICTOR`** and prints an ignore warning | `cktsopt.c:199-207` |
| **N7** | ROUTE-AROUND | **`scalm` is refused** with `Warning: option SCALM is not supported.` | `inp.c:891-901` |
| **N8** | ROUTE-AROUND | **`x11lineararcs` is `if (0 && …)` — and `spinit.in:4` sets it**, so it is a visible lie in `set` output | `x11.c:707` |
| **N9** | ROUTE-AROUND | **A `CP_BOOL` written `=1` is OFF**; a `CP_NUM` written bare is inert; `-D name=value` is always a `CP_STRING` | §3.4 |
| **N10** | ROUTE-AROUND | **26 variables are unreachable from `.options` AND from `.control`** | §3.2.1 |
| **N11** | ROUTE-AROUND | **`-n` / `--no-spiceinit` silently discards the run directory's `.spiceinit`**, and the only message is a *resistor* warning | `[R-M17]` |
| **N12** | **UPSTREAM** | **`$osdi_enabled` is a false negative** — `spinit.in:20` does `unset osdi_enabled` unconditionally, verified this pass | `hidden-vars.md` §5.4 |
| ~~**N13**~~ | ~~ROUTE-AROUND~~ | ~~`option maxord=` and `option method=` are rejected from the shell command~~ **WITHDRAWN 2026-09-09 — there is no defect here.** The `unsupported[]` loop is unreachable for both keywords because they carry `IF_SET` (`spiceif.c:510` guards it; `cktsopt.c:313-314` declares them). Measured: `option method=gear` → `Integration Method = GEAR`. See §3.1.1. Left as a tombstone because the wrong claim is quoted elsewhere | — |
| **N14** | ROUTE-AROUND | **`.options bogus=1` invents a variable silently when the token is numeric**; `[R-M9]` measured `option bogusopt=3` creating `bogusopt 3` in the variable list | `inpdoopt.c:70-78` |
| **N15** | ROUTE-AROUND | **`savecurrents` + AC kills the entire `write`** (no file) or zeroes every current column (`-r`). The remedy is `remzerovec`, **per plot** | §3.4 Trap 4 |
| **N16** | ROUTE-AROUND | **`.meas` dot cards are refused under `-r`**; `expr=` is broken; `param=` is one-shot | §6.7 |
| **N17** | **DOC** | **`src/ngspice.txt` says noise output is in squared units.** It is not; RMS/√Hz is the default | §2.6 |
| **N18** | **DOC** | **The manual says `trnoise`/`trrandom` are not available on `isrc`.** They are | §5.1 |
| **N19** | **DOC** | **Manual §13.5.68 lists only `.ac/.op/.tran/.dc` as dispatched by a bare `run`.** Every registered analysis is dispatched | [crit §5.5] |
| **N20** | ROUTE-AROUND | **`fournosave` removes the `fourierMN`/`thdMN` vectors** a THD readout depends on | §6.7 |
| **N21** | ROUTE-AROUND | **`stop after $&vec` arms NOTHING once the count passes 1,000,000.** `com_stop()` parses the `after` argument digit by digit (`if (!isdigit_c(*s)) goto bad;`) while `$&` formats a vector in exponential notation: `1500000` reaches the command line as **`1.5E+06`**. Measured: `stop after $&big`, `big = 1200000` → `Syntax error parsing breakpoint specification.`, nothing armed, the run finishes with **no checkpoint at all**, rc 0. Through a `set` variable it arms and fires correctly — and rounds to 6 significant figures (1,234,567 → 1,234,570) | `breakp.c`, `com_stop()`; §6.8.6 trap (b). **This is exactly the regime checkpointing exists for** — a loop tested on short runs passes and stops checkpointing the moment a run is long enough to matter |
| **N22** | ROUTE-AROUND | **A `let` counter created after an analysis is invisible to the next one**, so a checkpoint loop stops advancing and the deck carries on at rc 0. Vectors created before any analysis land in the `const` plot and are readable from every later plot; created while `op1`/`ac1` is current they land there and vanish when `tran1` becomes current. Measured: `b` created under `op1`, then after the `tran` → `Error: &b: no such variable`, while `const.a` still reads 111. In a checkpoint loop the symptom is `Error: RHS "cknext + ckstep" invalid`, a counter that never advances, and no further checkpoint armed. §6.8.6 trap (a) | **Create loop counters at the top of the `.control` block, before the first analysis**, or prefix them with a plot name |

### 7.4 Why `libngspice` is not the escape hatch

It is worth stating here because "just link the library" is the obvious reaction to X1, X2, X6
and X10, and `builds.md` measured the answer:

* **An ngspice crash becomes YOUR crash.** The `.disto` NULL-deref driven through the library
  **killed the host process at rc 139** — the SIGSEGV handler is installed only during
  `ngSpice_Init` and restored before it returns. X2 and X3 are in the same class. On the `-b`
  route the child dies and the GUI lives.
* **`bg_halt` wedges** on `disto` (1.0095 s, `Error: Couldn't stop ngspice`) and on `sens`.
* **`ngSpice_Circ` after `ngSpice_Reset` SEGFAULTs**, because `Reset` is a full teardown and
  `ngSpice_Circ` lacks the `is_initialized` guard `ngSpice_Command` has — the exact recurring bug
  class ngspice's own `CLAUDE.md` names.
* **`SendStat` emits nothing at all for op, noise, disto, pz, tf and sens**, while the `-b`
  ticker covers tran, dc, ac, noise, disto and sp (§6.5).
* `--with-ngshared` builds **no `ngspice` binary**, so a GUI would ship and ABI-pin
  `libngspice.so.0` and set `SPICE_LIB_DIR`.

**`-p` pipe mode is the middle road** and it is the one measured to work: SIGINT **pauses in
under 5 ms** with partial results intact (a valid 388 MB rawfile written after a stop, `resume`
continuing to 5.1 M points, `quit` rc 0), against **any ngspice the user already has**; and the
pre-deck problem collapses from three doors and four traps to **one** — `set` before `source`.
Its cost is one asynchronous reader that parses the `ngspice <N> -> ` prompt echo.

⚠ **CORRECTED 2026-09-10 — the "under 5 ms" figure is not a difference between the two transports.** Batch dies just as fast: measured mid-transient, **SIGTERM 5.6 / 4.5 / 5.3 ms** and **SIGKILL 5.0 / 5.2 / 5.5 ms**, indistinguishable because nothing handles either — and two later sittings measured 0.4–0.6 ms and 1.6–2.2 ms on smaller runs, because the figure tracks the process's resident memory rather than the signal (§6.8.1). **A few milliseconds at worst; sub-millisecond on a small run.** What `-p` buys on abort is that the abort is **non-destructive** — no checkpoint granularity, no torn-file window, no `shell mv`, and the data still live in the process afterwards. The latency framing invites a reader to think the two transports are close on this axis, and on *latency* they are identical. `-p`'s remaining advantages are elsewhere: the no-circuit capability probe (§7.2 note on probing with the bare verb), and collapsing the pre-deck delivery to one door. **Losing work is no longer one of them** — §6.8.4 is stop-and-keep-what-you-have, in `-b`, on the stock binary.

---

### 7.5 THE VARIANT-KEYED HAZARD TABLE — which binary has which of these

**Added 2026-09-10 by the variant-support amendment.** §7.1–§7.3 answer *"what goes wrong"*.
This answers *"on whose machine"*, and it carries the rule that keeps it honest:

> **A hazard is keyed on WHAT THE BINARY ANSWERED, never on its version string** — because two
> of the three binaries answer the same version string (§1.8). A row whose key would be a version
> number is either **probeable** (then it is a probe, and the key is the probe's answer) or
> **universal** (then there is no key, and the mitigation is unconditional). **This table has zero
> version-keyed rows and that is the finding, not an omission.**

| hazard | apt 45.2 | stock 47 | fork | how ASE-L knows | what ASE-L does |
|---|---|---|---|---|---|
| **X1** `.disto` NULL-deref when the save list resolves to nothing | ☠ | ☠ | ☠ | **nothing to know** — universal, and probing it would SIGSEGV the user's binary | never emit a narrowed `save` in the same run as `disto`. **Unconditional** |
| **X2** `sens … ac` under `option klu` | ☠ | ☠ | ☠ | universal; same reason | never emit `option klu` on a run carrying an AC `sens`. **Unconditional** |
| **S1** `ac lin 2` / `sp lin 2` → one point | ☠ | ☠ | ☠ | universal, and it is a *source* fact | warn at the form and name the fix (*"a linear sweep of 2 points yields 1 point; use 3"*). **Unconditional** |
| **D4** `No. Points:` 8-char field overflows above 99,999,999 points | ☠ | ☠ | ☠ | universal, and the cheap proof is structural — probing it means writing 1.6 GB | refuse or warn at the form. **Unconditional** |
| **V1** *(new)* **a one-vector op plot is written with a phantom second column named `all`** | ☠ | ☠ | **fixed** | **PROBE** — key `one_vector_write` (below) | filter the duplicate at the two seams that show a vector list; force the `.save all` leader only when the probe measured **0** |
| **V2** *(new)* **a capitalised keyword ARGUMENT is rejected, silently** | ☠ | ☠ | **fixed** | **PROBE** — key `keyword_case` (below) | ASE-L already emits every keyword lower case; the probe only decides whether the pass-through linter warns about *user* text |
| **V3** *(new)* **a bare `gnd` token in control-command arguments is rewritten to ` 0 `** | ☠ | ☠ | **fixed** | **PROBE** — key `gnd_literal` (below) | warn about user text; ASE-L emits no such token |
| **V4** `unset` of a `US_SIMVAR` / `curplot` / `plots` → SIGABRT rc 134 | ☠ | ☠ | fixed | **DELIBERATELY NOT PROBED** — see the ⚠ below | warn about user text, on every binary, **never refuse** |
| **V5** `define f(x) …` then two `print f(…)` → SIGABRT; `define d(x,y) x` → SIGSEGV | ☠ | ☠ | fixed | not probed, same reason | warn about user text |
| **V6** `load` of a raw whose header carries `Option: curplot=` / `plots=` / `curplotname=` → SIGSEGV | ☠ | ☠ | fixed | not probed, same reason | warn about user text. ⚠ **The fork's own `casemodewrite` header (`Option: casemode=…`) does NOT collide** and loads cleanly on apt — a fork-written raw is safe to hand to a stock binary |
| **V7** *(new)* **a narrowed `save` starves `noise`, `tf` and dc `sens`** | ☠ | ☠ | ☠ | universal | never emit a narrowed `save` in the same run as an analysis whose result vectors are not netlist names. **Unconditional** |
| **PSS** absent | **present** | absent | absent | **PROBE** — `help pss` / `analyses_available` | offer it only where measured present (§1.7 `[A-M7]`) |
| **CIDER** absent | **present** | absent | absent | **PROBE** — `devhelp`, grepped `^(NUMD\|NBJT\|NUMOS)` | warn before running a `numd`/`nbjt`/`numos` netlist where absent |
| **casemode** absent | absent | absent | **present** | **PROBE** — `sim_probe_capability`'s three delivery legs | offer exactly the modes measured deliverable; never read back `$casemode` |

⚠ **V4/V5/V6 are deliberately NOT probed, and this is a rule rather than an omission.** Each is
probeable — a marker file written after the aborting statement is a clean file-existence verdict,
measured `absent` on apt 45.2 and stock 47 and `lifetime_ok` on the fork. It is refused anyway,
because the probe's cost is **a deliberate SIGABRT of the user's own `/usr/bin/ngspice`**, and on
a stock Ubuntu desktop that is apport's reportable case: `dpkg -l apport` → `ii 2.34.1-0ubuntu0.1`,
`/etc/default/apport` → `enabled=1`, `systemctl is-enabled apport.service` → `enabled`, and
`/usr/lib/systemd/system/apport-coredump-hook@.service` present — all measured on this machine,
2026-09-10. It is silent *here* only because WSL leaves `core_pattern` at `core` and
`systemd-coredump` is not installed. What the key would buy is upgrading a *warning* to a
*refusal* on two of three binaries, and a warning is free. See `PLAN.md` §0.13.6 and the
refuse-list.

#### 7.5.1 The three probes, with their decks and their measured answers

Each is **one line inside a `.control` block that is already running**, so all three ride a single
`-b` process. Every verdict is read from a **file**, never from an exit code (D7).

**`one_vector_write` — 1 iff a one-save op plot comes back holding exactly that one vector.**

```spice
* leg D fragment
.control
set filetype=ascii
save v(mid)
op
write probe_d.raw
.endc
```

| binary | the raw's `Variables:` block |
|---|---|
| apt 45.2 | `0 v(mid) voltage` / **`1 v(all) voltage`** → key **0** |
| stock 47 | `0 v(mid) voltage` / **`1 v(all) voltage`** → key **0** |
| fork | `0 v(mid) voltage` → key **1** |

Characterised exactly (`evidence/fork-dependencies.md` §5): op with **1** save → phantom; op with
2 or 3 saves → clean; `tran` with 1 save → clean, because the `time` scale is a second vector. A
bare `write` substitutes the token `all`, and `ft_evaluate()` renames a single unchained result
with the parse node's own text.

**`keyword_case` — 1 iff a capitalised keyword ARGUMENT resolves.**

```spice
write probe_k.raw ALL
```

| binary | `probe_k.raw` |
|---|---|
| apt 45.2 | **absent** — `Warning from checkvalid: vector ALL is not available or has zero length.` / `Error during 'write': no writable vector found.` → key **0** |
| stock 47 | **absent**, same two lines → key **0** |
| fork | **present** → key **1** |

⚠ **A capitalised COMMAND NAME probes nothing.** Measured: `Echo "…" >> f` works on all three —
command dispatch inside a deck's `.control` block is folded. The unfolded path is the **argument**,
which is why the probe is `write … ALL` and not `Write …`. This corrects the obvious form of the
probe before someone writes it.

**`gnd_literal` — 1 iff a bare `gnd` token survives a control-command argument list.**

```spice
echo "@@gnd=M7 my gnd rail" >> probe_d.txt
```

| binary | the line that comes back |
|---|---|
| apt 45.2 | `@@gnd=M7 my 0 rail` → key **0** |
| stock 47 | `@@gnd=M7 my 0 rail` → key **0** |
| fork | `@@gnd=M7 my gnd rail` → key **1** |

Paths survive the rewrite (`/ _ - .` are not delimiters); it is whitespace- and paren-delimited
bare `gnd` that is replaced, including inside `echo v(gnd)` → `v( 0 )`.

#### 7.5.2 The narrowed-save starvation, measured across all three (**V7**, new)

X1 records that `disto` **SIGSEGVs** when its save list resolves to nothing. The same starvation
hits three more analyses **cleanly but silently-in-the-GUI-sense**, and it was not written down
anywhere in this batch before 2026-09-10. Measured on all three binaries, identically:

| deck | result | `$sim_status` | rawfile |
|---|---|---|---|
| `save v(mid)` + `noise v(mid) v1 dec 5 1k 100k 1` | `Error: no data saved for Noise analysis; analysis not run` | **1** | `Plotname: constants` only |
| `save v(mid)` + `tf v(mid) v1` | `Error: no data saved for transfer function analysis; analysis not run` | **1** | — |
| `save v(mid)` + `sens v(mid)` | `Error: no data saved for Sensitivity analysis; analysis not run` | **1** | — |
| `save v(mid)` + `pz in 0 mid 0 vol pz` | *(runs)* | 0 | — |
| the same decks with **no** `save` line | both noise plots, rc 0 | 0 | `Noise Spectral Density Curves` + `Integrated Noise` |

**The rule, and it is the general form X1 is one instance of:** an analysis whose result vectors
are **not netlist names** — `onoise_spectrum`, `inoise_spectrum`, `onoise_total`, `inoise_total`,
the transfer-function and sensitivity outputs — cannot run under a `save` list derived from
netlist names. ASE-L's Outputs pane produces exactly such a list, and a **stale** entry (the normal
case after a user renames a net) is enough. `pz` is the exception that proves the rule: its result
vectors are `pole(n)` / `zero(n)`, and it survives.

⚠ **`$sim_status` DOES fire here** (1, not 0), so ASE-L's existing guard catches it as a failed
run — the user gets `RUN-FAILED`, not a wrong number. The defect is that the *reason* is
unexplained. Stage 16's sentence and Stage 6's precondition are what close it.

#### 7.5.3 One more thing the one-`write`-per-analysis shape loses (**new**)

Measured on all three binaries: after a successful `noise … dec 5 1k 100k 1`, `$plots` is
`const noise1 noise2` and a **bare `write z.raw` produces ONE plot — `Integrated Noise`.** The
spectral-density curves, which are the reason anyone runs a noise analysis, are gone, with rc 0
and `$sim_status` 0, so nothing fires. The fix is §6.3's `setplot previous` walk (PLAN Stage 6a),
and there is a **second, measured** form worth recording beside it:

```
write z.raw noise1.all noise2.all   ->  Noise Spectral Density Curves + Integrated Noise
```

⚠ **Do not reach for the named-plot form as a shortcut.** Unlike `foreach p $plots / setplot $p`
it does *not* write `constants` first (measured: exactly two plots), but the plot ids are
**session counters** — measured `const op1 ac1 noise1 noise2` in a deck that ran `op` and `ac`
first, so a second noise run in the same process is `noise3`/`noise4`. A renderer that emits the
literal `noise1` is guessing at a counter, which is precisely the class of thing the sidecar
(§6.3) exists to stop guessing at. The walk stays the shape of record; this row exists so the next
reader who measures the shortcut knows why it was not taken.

---

## 8. What is still open, and the exact experiment that would close it

Four of the design-of-record's twelve OPEN items are **closed by this pass**: M3 by [A-M5], M4 by
[A-M4], M6 by [A-M6], and M2 **in part** by [A-M7].

⚠ **One numbering space across the batch.** `M1`–`M12` are `evidence/design-of-record.md` §16's,
inherited unchanged — in particular **M5 is the multi-raw family** here, in `LEDGER.md` and in
`PLAN.md`'s "Still open" table. `M13`–`M15` are **this pass's additions**: M13 the DC-sweep +
auto-bridge root cause, M14 `help devhelp`, and **M15** the stripped/relocated help database,
which an earlier draft of this section numbered `M2'`. **`M16`–`M17` were added on 2026-09-10 by the
adapter pivot** — the unwritten adapter-author specification, and the schema validated against one
implementation plus one paper exercise. **`M18` was added later the same day, when ⚖ R1 was
answered and always-salvage became a requirement** — it is the window in which Stage 2e's warning
is honest and ASE-L is still lossy. Like M16 and M17 it is not an ngspice question, so it has no
row below; `LEDGER.md`'s debt table owns all three. **The next free id is M19**, and `LEDGER.md`'s
debt table is the one to believe about what is free. No id is reused and no id carries a prime.

⚠ Do not confuse these with `[R-M16]` and `[R-M17]` used earlier in this document: those are the
design of record's **measurement markers**, a different namespace entirely.

What remains:

| # | question | why it matters | the experiment |
|---|---|---|---|
| **M1** | Can a GUI get stdout and stderr as **two ordered streams**? ASE-L folds them with `2>@1`, and the two `ngdebug` ladder lines carry **no trailing newline** | blocks a live convergence-ladder pane; without it the pane reads the log after the fact | run a deliberately non-converging OP with `set ngdebug` and diff the interleaving against two separate `-o`/`2>` files. One deck |
| **M15** | Does `help <verb>` answer correctly on a build with a **relocated or stripped** help database? [A-M7] covers a second build but both had their database | a wrong answer either hides a working analysis or offers a missing one | the same probe against a third build, cross-checked against `devhelp`'s families. Publish only on a clean parse |
| **M5** | A **multi-raw family** (one raw per point) is new to the waveform viewer and to the Calculator, whose spec says v1 handles only the single-raw multi-dataset case | a family-of-curves display has no owner | not an experiment — a conversation with `doc/claude/specs/calculator.md`'s owner |
| **M7** | Does `.probe p(XU1)` really yield `xu1:power`, and what are the differential / power vector spellings (`vd_R1`, `mq1:power`)? Documented by manual §11.6.5, **never verified against source or a run by anyone** | a "power" column is keyed on those names | one deck with `.probe p(x1)` and `.probe vd(r1)`; `display` and `write`, then read the names |
| **M8** | Does `set interp` handle a **complex AC** plot and a **nested DC** sweep correctly? Measured only on a real transient (21 points from `tran 1u 20u`) | the Output-grid control depends on it | three decks, `length()` and a spot value before and after |
| **M9** | Does an `eprvcd` VCD attach cleanly **alongside** a rawfile, and does a digital pane label the nodes with their ngspice names? | the whole event-results claim | drive the `adc_bridge`/`d_inverter` deck through a real session with the VCD in the attach list |
| **M10** | **`Nintegrate()`'s definition was never located**, so nobody can explain an `onoise_total` number in a tooltip | that number goes in front of a user | `grep -rn "Nintegrate" src/`, then read |
| **M11** | Does `alterparam` + `reset` preserve `.options` and `set` variables across the re-parse, and does it re-read the run directory's `.spiceinit`? | decides whether an `alter`-only axis can be collapsed into one process (§4.6) | one deck: `option reltol=0.05`, `alterparam`, `reset`, then a bare `option` — §8.1 gives the reader for free |
| **M12** | What does `wrs2p` actually emit for an `sp` run with the `.csparam Rbase=50` workaround, and is it valid Touchstone? | S-parameter export | one two-port deck, `wrs2p out.s2p`, open it in any Touchstone reader |
| **M13** | The **DC-sweep + auto-bridge failure** has a reproducer and no root cause | blocks offering `dc` on a mixed-signal deck honestly | `xspice.md` §12.1/§12.2 has the reproducer; someone must debug it |
| **M14** | Why does `help devhelp` print **nothing at all** — neither a help line nor `Sorry, no help for …`? | only matters as "never probe with it", which is already the rule | not worth an experiment; recorded so nobody re-hunts it |

### 8.1 The verification channel nobody used

⚠ New with `[R-M9]`, and it is the cheapest staleness check available on an unfamiliar binary.
After `option reltol=0.05 itl4=7 method=gear`, a **bare `option`** printed:

```
reltol (current) = 0.05
itl4 (transient iterations) = 7
Integration Method = GEAR
```

plus temp / tnom / maxorder / solver / pivtol / gmin / gminsteps / srcsteps / trtol / delmin. And
a **bare `set`** listed every variable in force — **including `bogusopt 3`, silently created by
`option bogusopt=3`**, and a bare `set frobnicate`.

So `option > <file>` and `set >> <file>` at the end of a deck give a **requested-vs-effective
diff**: it catches the §3.4 silent drops, catches a silently-dropped out-of-range value, and
**proves a pre-deck delivery landed**. ⚠ Its one limit: **neither channel reveals a `CP_` class**,
so §3.4's type table still has to ship.

---

## 9. What this appendix does NOT cover

House style: every document says what it refuses. These are deliberate omissions, each with its
reason, so the next reader does not assume they were missed.

* **The CIDER model sub-language.** Five device families, a 16-card mesh/doping/mobility grammar
  inside a `.model` card. It adds **no analysis, no dot card and no `SPICEanalysis`** (§1.7), so
  it belongs to a model editor and not to an analyses inventory. What the analyses surface owes
  CIDER is the four defensive behaviours in §1.7 and nothing more.
* **The XSPICE code-model catalogue.** `icm/{analog,digital,xtradev,xtraevt,table,tlines,
  spice2poly}` are devices, not analyses. §6.6 covers the only part that is a *results* question.
* **The device parameter space.** `devhelp -csv -type -flags <device>` is the machine-readable
  source (§2.10 uses it for the SENS picker), and enumerating it per family is a different
  document.
* **The full control-language expression vocabulary** — `group_delay`, `cph`/`unwrap`, `mtimeavg`,
  `m3avg`, `deriv`, `integ`, `interpolate`, `sortorder`. `doc/claude/specs/calculator.md` owns
  that surface and already models most of it.
* **The 62 presentation variables** of catalogue B (`hidden-vars.md` §2.5). None can change a
  number and none belongs in a simulation form.
* **`libngspice`'s API surface** beyond §7.4's costed verdict. `outputs.md` §9 and `builds.md`
  Part 3 have it; this pass refuses the transport, so cataloguing it here would be inventory for
  a road not taken.
* **`iplot`, `step`, `speedcheck`, `deltacheck`, `aspice`, `snsave`, `snload`.** All need
  interactive or `-p` mode (or `set ngdebug`, which floods the log). They are the pipe transport's
  first customers, and they are inventoried in `commands.md` §4 and §12.
  ⚠ **CORRECTED 2026-09-10: `stop`, `stop when` and `resume` were in that list and do not belong
  there.** All three work in `-b` inside a `.control` block, and they are the whole of §6.8.4 — the
  mechanism by which a batch run keeps what it has already computed. `stop after` is the safe form;
  `stop when` re-fires (§7.2 **S29**).
* **Anything about how the GUI should present this.** That is `PLAN.md`'s job, and keeping it out
  of here is the point of the split.

---

## 10. Where each claim's evidence lives

| claim class | owner |
|---|---|
| inter-dossier contradictions, and four ngspice defects nobody else found | `evidence/00-critique.md` |
| **PSS actually built and run; CIDER actually built and run; libngspice vs `-p` vs `-b`, measured** | `evidence/builds.md` |
| per-analysis parameter tables | `evidence/an-core.md`, `an-smallsig.md`, `an-rf-pss.md` |
| the two option catalogues | `evidence/options.md` (OPTtbl + `set`), `evidence/hidden-vars.md` (163 `cp_getvar`, the CP-type table, the 26 pre-deck) |
| the two grammars | `evidence/dotcards.md` (cards), `evidence/commands.md` (`.control` verbs) |
| plot names, rawfile shape, invocation routes, exit status | `evidence/outputs.md` — ⚠ its §3's last three rows are corrected in §6.2 here |
| sweeps, corners, Monte Carlo, seeding, abort, progress | `evidence/orchestration.md` |
| **signals, `-r` streaming and its repair, `stop`/`resume` checkpointing, what a Stop costs and what it keeps** | `evidence/salvage.md` — §6.8 here is its reference half; the dossier carries every deck in full, plus its scorecard against the quick pass, whose "the transient halted, the write ran, and resume continued" is the one claim that would have shipped a silently-truncating checkpoint loop (§7.2 **S29**) |
| transient noise and `trrandom` | `evidence/trnoise.md` |
| the device × analysis support matrix | `evidence/cider-devices.md` |
| `.meas`, `.four`, `fft`, the expression vocabulary | `evidence/measure.md` |
| the event-driven surface | `evidence/xspice.md` |
| the convergence ladder and `CKTncDump` | `evidence/convergence.md` |
| the official manual and tutorials cross-check | `evidence/docs-web.md` |
| **which ngspice the user actually has: the three-binary matrix (§1.8), the variant-keyed hazard table and its three probes (§7.5)** | `evidence/variants.md` (stock 47 built and characterised; the measured proof that stock 47 and the fork are indistinguishable by inspection), `evidence/fork-dependencies.md` (the 105 functional fork commits classified; the five crashes reproduced live on apt 45.2), `evidence/fork-features.md` (what the fork really adds — **not** a blanket OP save; the per-binary capability dicts) |
| the synthesis all of the above was judged into | `evidence/design-of-record.md` |
| the three competing designs, kept for provenance | `evidence/design-A.md`, `design-B.md`, `design-C.md` |
| **the measurements marked `[A-M<n>]`** | taken this pass against `build-ver_50/src/ngspice` and `/usr/bin/ngspice` 45.2. ⚠ **Decks are quoted in full at each `[A-M<n>]` marker**, in the shape `design-of-record.md` uses for `[R-M<n>]`, so a challenged number is re-typed and re-run. An earlier draft of this row said "decks in the session scratchpad" — a session-local directory, exactly like the `../dor/` one `README.md` warns about, and a measurement whose deck is gone is unfalsifiable rather than merely unverified |
