# Dossier: ngspice small-signal and derived analyses (AC, NOISE, PZ, TF, DISTO, SENS)

Audience: a future Claude Code session building the ASE-L analysis GUI in
`/home/analog/dev/xschem-claude/src/ase.tcl` / `ase_window.tcl`.

Tree: `/home/analog/dev/ngspice`, branch `ver_50`, `git describe = ngspice-46-419-gccebdf2a2`.
All `file.c:LINE` anchors are relative to `/home/analog/dev/ngspice/`.
All empirical claims marked **[verified]** were produced by running
`/home/analog/dev/ngspice/build-ver_50/src/ngspice --batch <deck>` on scratch decks in
`/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/work/`.
Nothing in either repo was modified.

## 0. Build configuration of this tree (matters for what the GUI may offer)

`build-ver_50` was configured as `../configure --prefix=.../stage --with-readline=yes`
(`build-ver_50/config.log`). Resulting feature macros
(`build-ver_50/src/include/ngspice/config.h`):

| macro | state here | effect on this area |
|---|---|---|
| `XSPICE` | **defined** (`config.h:579`) | code-model event layer; `MIFnoise` contributes noise (`src/xspice/mif/mifnoise.c:584`); AC/NOISE call `EVTop` when event instances exist (`src/spicelib/analysis/acan.c:121`, `noisean.c:174`) |
| `OSDI` | **defined** (`config.h:502`) | OpenVAF Verilog-A models contribute noise via `OSDInoise` (`src/osdi/osdiinit.c:200`) |
| `KLU` | **defined** (`config.h:463`) | *compiled in*, but **off by default** (`src/spicelib/analysis/cktntask.c:143` sets `TSKkluMODE = CKTkluOFF`; runs print "Using SPARSE 1.3 as Direct Linear Solver" **[verified]**). NOISE and PZ *refuse to run* under `option klu` (see below) |
| `RFSPICE` | **defined** (`config.h:535`) | adds the `SP` analysis to `analInfo[]`; adds RF port params to VSRC (`v1_z0`, `v1_pwr`, `v1_freq`, `v1_phase` appear as SENS parameters **[verified]**); `NevalSrc*` grows an `S`-param branch (`src/spicelib/analysis/nevalsrc.c:43`) |
| `CIDER` | undefined (`config.h:11`) | numeric devices absent |
| `WITH_PSS` | undefined (`config.h:576`) | `.pss` absent |
| `WANT_SENSE2` | **not even a config.h key** — see §8 | `.sens2` unreachable |
| `PZDEBUG`, `SENSDEBUG`, `ASDEBUG`, `D_DBG_BLOCKTIMES`, `D_DBG_SMALLTIMES` | all undefined (`config.h:532`, `:547`, `:5`; `configure.ac:1079`, `:1067`, `:1071`, `:1087`, `:1091`) | extra tracing available only with `--enable-pzdebug` / `--enable-sensdebug` / `--enable-asdebug` / `--enable-blktmsdebug` / `--enable-smltmsdebug` |

Nothing in AC / NOISE / PZ / TF / DISTO / SENS is gated by a configure flag in a way that
would remove the analysis: all six are unconditionally in `analInfo[]`
(`src/spicelib/analysis/analysis.c:36-59`). The GUI can assume all six exist in any normal
ngspice build.

---

## 1. Common machinery — read this before the per-analysis sections

### 1.1 The `SPICEanalysis` / `IFanalysis` descriptor

`src/spicelib/analysis/analysis.h:84-93`:

```c
struct SPICEanalysis {
    IFanalysis if_analysis;   /* name, description, numParms, analysisParms */
    int size;                 /* sizeof the JOB struct */
    int domain;               /* NODOMAIN / TIMEDOMAIN / FREQUENCYDOMAIN / SWEEPDOMAIN */
    int do_ic;                /* run CKTic() before the analysis */
    int (*setParm)(...);
    int (*askQuest)(...);
    int (*an_init)(...);
    int (*an_func)(CKTcircuit *ckt, int restart);
};
```

`domain` enum: `src/include/ngspice/jobdefs.h:20-23` (`NODOMAIN = 0, TIMEDOMAIN,
FREQUENCYDOMAIN, SWEEPDOMAIN`). In this codebase `domain` is **never read** — grep finds
no consumer. It is metadata only; do not build GUI logic on it.

`do_ic` **is** read: `src/spicelib/analysis/cktdojob.c:190-191` — `if (!error &&
analInfo[i]->do_ic) error = CKTic(ckt);`. So `.ic` initial conditions are applied for
AC/PZ/DISTO/NOISE/SENS but **not** for TF.

Summary table for this area:

| analysis | `name` | `description` | JOB struct | `size` | `domain` | `do_ic` | `an_init` | `an_func` |
|---|---|---|---|---|---|---|---|---|
| AC | `"AC"` | `"A.C. Small signal analysis"` | `ACAN` | `sizeof(ACAN)` | `FREQUENCYDOMAIN` | 1 | NULL | `ACan` |
| NOISE | `"NOISE"` | `"Noise analysis"` | `NOISEAN` | `sizeof(NOISEAN)` | `FREQUENCYDOMAIN` | 1 | NULL | `NOISEan` |
| PZ | `"PZ"` | `"pole-zero analysis"` | `PZAN` | `sizeof(PZAN)` | `NODOMAIN` | 1 | NULL | `PZan` |
| TF | `"TF"` | `"transfer function analysis"` | `TFan` | `sizeof(TFan)` | `NODOMAIN` | **0** | NULL | `TFanal` |
| DISTO | `"DISTO"` | `"Small signal distortion analysis"` | `DISTOAN` | `sizeof(DISTOAN)` | `FREQUENCYDOMAIN` | 1 | NULL | `DISTOan` |
| SENS | `"SENS"` | `"Sensitivity analysis"` | `SENS_AN` | `sizeof(SENS_AN)` | `FREQUENCYDOMAIN` | 1 | NULL | `sens_sens` |

Anchors: `acsetp.c:94-109`, `nsetparm.c:95-110`, `pzsetp.c:90-105`, `tfsetp.c:61-76`,
`dsetparm.c:82-97`, `senssetp.c:106-120` (all in `src/spicelib/analysis/`).

Note `PZinfo`'s description is lowercase `"pole-zero analysis"` and `TFinfo`'s is
lowercase `"transfer function analysis"`, while AC/NOISE/DISTO/SENS are capitalised. If
the GUI shows `spice_analysis_get_description()` output verbatim it will look
inconsistent; consider a display-name table of your own.

### 1.2 `analInfo[]` order **is** the execution order

`src/spicelib/analysis/analysis.c:36-59` (this build, RFSPICE on / PSS off / SENSE2 off):

| JOBtype | analysis |
|---|---|
| 0 | `options` (the `.options` pseudo-analysis) |
| 1 | `AC` |
| 2 | `DC` |
| 3 | `OP` |
| 4 | `TRAN` |
| 5 | `PZ` |
| 6 | `TF` |
| 7 | `DISTO` |
| 8 | `NOISE` |
| 9 | `SENS` |
| 10 | `SP` (RFSPICE) |

`src/spicelib/analysis/cktdojob.c:176-213`: `/* Analysis order is important */ for (i = 0;
i < ANALmaxnum; i++) { for (job = task->jobs; job; job = job->JOBnextJob) if
(job->JOBtype == i) ... }`.

**Consequences the GUI must model:**

1. Deck order does **not** determine run order. A deck with `.tran`, `.ac`, `.ac`,
   `.noise`, `.tf` runs **AC, AC, TRAN, TF, NOISE** — verified: plot list came back
   `noise3, noise2, tf2, tran2, ac2, ac1` (newest first) **[verified]**.
2. Two jobs of the *same* type run in **reverse deck order** (LIFO): `CKTnewAnal`
   prepends (`src/spicelib/analysis/cktnewan.c:34-35`
   `(*analPtr)->JOBnextJob = taskPtr->jobs; taskPtr->jobs = *analPtr;`). Verified: with
   `.ac dec 1 1k 10k` then `.ac dec 1 100k 1meg`, plot `ac1` holds 100k…1meg and `ac2`
   holds 1k…10k **[verified]**.
3. So if the GUI wants deterministic, user-visible ordering it should emit **one analysis
   per run** (a `.control` block issuing `ac …`, then `noise …`, etc.), not a pile of dot
   cards. That also gives per-analysis error handling.

### 1.3 The complete `IFparm` type/flag vocabulary

`src/include/ngspice/ifsim.h`:

| flag | value | line |
|---|---|---|
| `IF_FLAG` | `0x1` | `:100` |
| `IF_INTEGER` | `0x2` | `:101` |
| `IF_REAL` | `0x4` | `:102` |
| `IF_COMPLEX` | `0x8` | `:103` |
| `IF_NODE` | `0x10` | `:104` |
| `IF_STRING` | `0x20` | `:105` |
| `IF_INSTANCE` | `0x40` | `:106` |
| `IF_VECTOR` | `0x8000` | `:115` |
| `IF_ASK` | `0x1000` | `:130` |
| `IF_SET` | `0x2000` | `:129` |
| `IF_REDUNDANT` | `0x10000` | `:138` |
| `IF_PRINCIPAL` | `0x20000` | `:139` |
| `IF_AC` | `0x40000` | `:140` |
| `IF_AC_ONLY` | `0x80000` | `:141` |
| `IF_NONSENSE` | `0x200000` | `:143` |
| `IF_SETQUERY` | `0x400000` | `:145` |

`IF_SET` = settable input, `IF_ASK` = queryable (`ifsim.h:91-95`). They are not mutually
exclusive.

**How a keyword reaches `setParm`:** the parser calls `INPapName(ckt, type, job, keyword,
value)` (`src/spicelib/parser/inpapnam.c:14-37`), which looks the keyword up with
`ft_find_analysis_parm()` (`src/frontend/spiceif.c:1847-1855`) using **`cieq` —
case-insensitive**, then calls `setAnalysisParm` with `if_parm->id`. Analysis *names*
themselves are matched with `strcmp` — **case-sensitive** —
in `ft_find_analysis()` (`src/frontend/spiceif.c:1836-1844`), so the internal names must
be spelled exactly `"AC"`, `"NOISE"`, `"PZ"`, `"TF"`, `"DISTO"`, `"SENS"`. The GUI never
calls that directly, but it explains why `.ac DEC`, `.ac dec` and `.ac Dec` all work while
`.ac decade` does **not** (`decade` is not a keyword) **[verified: "Error: no such
parameter on this device or parameter is missing / in .ac decade 5 1k 10k"]**.

### 1.4 Defaults: every job struct starts as all-zero

`CKTnewAnal` allocates with `tmalloc` (`src/spicelib/analysis/cktnewan.c:30`), and
`tmalloc` is `calloc(num,1)` (`src/misc/alloc.c:52,70` — "New implementation of tmalloc,
it uses calloc"). **Therefore the default of every analysis parameter is the zero value**
unless (a) the card parser explicitly supplies one, or (b) `an_func` patches it at run
time. There is no defaults table anywhere; there is only zero plus what the parser writes.
Each per-analysis section below lists which fields the parser fills.

### 1.5 Netlist card == `.control` command (identical parser)

`src/frontend/runcoms.c:124-184` — `com_pz`, `com_ac`, `com_tf`, `com_sens`, `com_disto`,
`com_noise` all just call `dosim("<name>", wl)`. `dosim` → `if_run`
(`src/frontend/runcoms.c:342`). `if_run` (`src/frontend/spiceif.c:244-368`) builds a
synthetic one-line deck `".%s %s"` from the command name plus its argument words
(`spiceif.c:279-286`) and feeds it to `INPpas2` (`spiceif.c:362`).

**So: the `.control` syntax of `ac`, `noise`, `pz`, `tf`, `disto`, `sens` is *exactly* the
netlist card syntax with the leading dot removed.** There is not a second grammar to
support. The only differences are:

* a `.control` command runs immediately, in the order typed, as its own "special task"
  (`spiceif.c:295-358`), so §1.2's reordering does not apply;
* a `.control` command replaces the previous special task each time
  (`spiceif.c:295-307`), so only one interactive analysis config is live at a time;
* `.control` inherits `.options` from the default task (`spiceif.c:334-356` creates a
  fresh `options` analysis for the special task, seeded from the default task by
  `CKTnewTask`, `src/spicelib/analysis/cktntask.c:81`).

Command-table entries: `src/frontend/commands.c:316` (`tf`), `:339` (`ac`), `:347` (`pz`),
`:351` (`sens`), `:355` (`disto`), `:359` (`noise`). Note the `tf` entry's help string is
**wrong** — it reads `"[.tran line args] : Do a transient analysis."`
(`commands.c:319`), copy-pasted from `tran`. Do not surface `spcp_coms[]` help text for
`tf`.

Also note the boolean columns in that table: `pz` and `disto` have `co_spiceonly = TRUE,
co_major = FALSE`; `ac`, `noise`, `sens`, `tf` have both `TRUE` (`commands.c:316-362`).

### 1.6 Which analyses need a converged DC operating point

| analysis | OP call | on failure |
|---|---|---|
| AC | `CKTop` at `acan.c:134-137`, **skipped** if `ckt->CKTnoopac` (`acan.c:133`) | prints `"\nAC operating point failed -\n"` + `CKTncDump(ckt)` and aborts (`acan.c:139-143`) |
| NOISE | `CKTop` at `noisean.c:200-203`, skipped if `CKTnoopac` (`:199`) | `"\nError: NOISE operating point failed -\n"` + `CKTncDump` + abort (`:205-209`) |
| PZ | `CKTop` at `pzan.c:41-43` | plain `return(error)`; the message the user sees is `doAnalyses: <SPerror text>` |
| TF | `CKTop` at `tfanal.c:44-47` — **result assigned to `converged` and never checked** (`gcc -Wall`: `variable 'converged' set but not used`, `tfanal.c:31`) | **silently continues with an unconverged operating point** |
| DISTO | `CKTop` at `distoan.c:91-94` | `return(error)` |
| SENS | `CKTop` at `cktsens.c:174-177` | `return error` (`:183-184`) |

`option noopac` only takes effect if the circuit is linear:
`cktdojob.c:109` — `ckt->CKTnoopac = task->TSKnoopac && ckt->CKTisLinear;`. When it fires,
AC prints `"\n Linear circuit, option noopac given: no OP analysis\n"` (`acan.c:146`).
Option keyword: `{"noopac", OPT_NOOPAC, IF_SET|IF_FLAG, "No op calculation in ac if
circuit is linear"}` (`src/spicelib/analysis/cktsopt.c:366-367`).

`option keepopinfo` (`cktsopt.c:356-357`, "Record operating point for each small-signal
analysis") makes AC / NOISE / PZ / DISTO each emit an **extra** operating-point plot
before the real one:

| analysis | plot title passed to `OUTpBeginPlot` | resulting plot name |
|---|---|---|
| AC | `"AC Operating Point"` (`acan.c:159`) | `op<N>` |
| NOISE | `"NOISE Operating Point"` (`noisean.c:227`) | `op<N>` |
| PZ | `"Distortion Operating Point"` (`pzan.c:58`) — **wrong label, copy-paste bug** | `op<N>` |
| DISTO | `"Distortion Operating Point"` (`distoan.c:107`) | `op<N>` |
| TF | none | — |
| SENS | none | — |

Verified with `.options keepopinfo` + `ac`/`pz`/`noise`: plot list contained
`op1 (AC Operating Point)`, `op2 (Distortion Operating Point)` *from the PZ run*, and
`op3 (NOISE Operating Point)` **[verified]**.

`option keepopinfo` is per-task, so the GUI can offer it as a checkbox per run.

### 1.7 `hertz` in a B-source re-solves the operating point at every frequency

`src/spicelib/parser/inp2b.c:40-42` — if the *text* of any `B` (arbitrary-source) card
contains the substring `hertz` (case-insensitive `cistrstr`), `ckt->CKTvarHertz = 1`.
AC (`acan.c:251-306`), NOISE (`noisean.c:373-428`) and SP then redo `CKTop` +
`CKTload` at *every* frequency point. This is a large slowdown and the GUI should warn
about it (and note it is triggered by mere textual presence of the word, not by actual
use).

### 1.8 Plot naming, and why you must not hard-code `ac1`

`src/frontend/outitf.c:1207-1219` — `plotInit()` calls
`plot_alloc(run->type)` where `run->type` is the *analysis name string* passed to
`OUTpBeginPlot` (`outitf.c:222`). `plot_alloc`
(`src/frontend/vectors.c:1094-1120`) maps that string through
`ft_plotabbrev()` and appends a **single global counter** `plot_num`:

```c
if ((s = ft_plotabbrev(name)) == NULL) s = "unknown";
do { sprintf(buf, "%s%d", s, plot_num);
     for (tp = plot_list; tp; tp = tp->pl_next)
         if (cieq(tp->pl_typename, buf)) { plot_num++; break; }
} while (tp);
```

`ft_plotabbrev` (`src/frontend/typesdef.c:330-348`) lower-cases the analysis name and
returns the first `plotabs[]` entry whose *pattern is a substring of it*. Table
(`typesdef.c:67-90`), in match order:

```
tran<-"transient"  op<-"op"     tf<-"function"  dc<-"d.c."  dc<-"dc"
dc<-"transfer"     ac<-"a.c."   ac<-"ac"        pz<-"pz"    pz<-"p.z."
pz<-"pole-zero"    disto<-"disto"  dist<-"dist" noise<-"noise"
sens<-"sens"       sens<-"sensitivity"  sens2<-"sens2"
sp<-"s.p."         sp<-"sp"     harm<-"harm"    spect<-"spect"  pss<-"periodic"
```

Because `plot_num` is **global and monotone**, the *first* plot of a run is not
necessarily `<type>1`. In one session: `ac1`, `noise1`, `noise2`, then `tf2`, then `pz2`
**[verified]**. **The GUI must discover plot names (`setplot` / the plot list /
`plot_cur`), never construct them.** `plot_num` is only reset by `destroy all`
(`src/frontend/postcoms.c:1046`).

The analysis-name strings that reach `ft_plotabbrev` in this area (these are also the
rawfile `Plotname:` field, `outitf.c:954`):

| string | source | abbrev |
|---|---|---|
| `"AC Analysis"` | `src/spicelib/parser/inp2dot.c:203` (JOBname) | `ac` |
| `"AC Operating Point"` | `acan.c:159` | `op` |
| `"Noise Spectral Density Curves"` / `"Noise Spectral Density Curves - (V^2 or A^2)/Hz"` | `noisean.c:276,278` | `noise` |
| `"Integrated Noise"` / `"Integrated Noise - V^2 or A^2"` | `noisean.c:534,536` | `noise` |
| `"NOISE Operating Point"` | `noisean.c:227` | `op` |
| `"Pole-Zero Analysis"` | `inp2dot.c:265` (JOBname) | `pz` |
| `"Transfer Function"` | `inp2dot.c:368` (JOBname) | `tf` |
| `"Distortion Analysis"` | `inp2dot.c:164` (JOBname) — used only as `JOBname`, DISTO never passes it to a plot | — |
| `"DISTORTION - 2nd harmonic"` | `distoan.c:517` | `disto` |
| `"DISTORTION - 3rd harmonic"` | `distoan.c:541` | `disto` |
| `"DISTORTION - IM: f1+f2"` | `distoan.c:564` | `disto` |
| `"DISTORTION - IM: f1-f2"` | `distoan.c:585` | `disto` |
| `"DISTORTION - IM: 2f1-f2"` | `distoan.c:607` | `disto` |
| `"Distortion Operating Point"` | `distoan.c:107`, `pzan.c:58` | `op` |
| `"Sensitivity Analysis"` | `inp2dot.c:485` (JOBname) | `sens` |

### 1.9 Vector "type" (units) assignment

`src/frontend/outitf.c:1023-1083` `guess_type()`. Relevant arms:

* name contains `#branch` → `SV_CURRENT` (`:1027`)
* `cieq(name,"frequency")` → `SV_FREQUENCY` (`:1035`)
* `ciprefix("inoise", name)` → the global `fixme_inoise_type` (`:1037-1038`)
* `ciprefix("onoise", name)` → `fixme_onoise_type` (`:1039-1040`)
* everything else falls through to `SV_VOLTAGE` (`:1079-1080`)

The two `fixme_*` globals are declared at `outitf.c:99-100` with the comment
"ugly hack to work around missing api to specify the type of signals", and are written by
the noise analysis (`noisean.c:258-266`, `:516-524`).

**Type table** (`typesdef.c:38-63`) — index = `SV_*` in `src/include/ngspice/sim.h`:

```
0 notype | 1 time s | 2 frequency Hz | 3 voltage V | 4 current A
5 voltage-density V/sqrt(Hz) | 6 current-density A/sqrt(Hz)
7 voltage^2-density (V^2)/Hz | 8 current^2-density (A^2)/Hz
9 voltage^2 (V^2) | 10 current^2 (A^2)
11 pole | 12 zero | 13 s-param | 14 temp-sweep | 15 res-sweep
16 impedance Ohms | 17 admittance Mhos | 18 power W | 19 phase rad
20 decibel dB | 21 capacitance F | 22 charge C | 23 temperature Celsius
```

**Defect worth knowing:** `SV_POLE` (11) and `SV_ZERO` (12) exist but are **never
assigned** — `guess_type` has no arm for `pole(`/`zero(`. Verified: `pole(1)` and
`zero(1)` come back as `voltage, complex` **[verified]**, so any axis label ngspice
derives will say "V" for a quantity that is really rad/s (`1/s`). Likewise TF's three
outputs and every SENS vector come back typed `voltage` even though two of the three TF
values are ohms and SENS values are `d(out)/d(param)`. The GUI must supply its own units.

### 1.10 `save` / `.print` can silently delete a whole plot

`beginPlot()` (`src/frontend/outitf.c:180-486`) filters the analysis's namelist against
the save list, and at `:479-486`:

```c
if (numNames && ((run->numData == 1 && run->refIndex != -1) ||
                 (run->numData == 0 && run->refIndex == -1)))
{
    fprintf(cp_err, "Error: no data saved for %s; analysis not run\n",
            spice_analysis_get_description(analysisPtr->JOBtype));
    return E_NOTFOUND;
}
```

Because an analysis can open several plots with **different** namelists, a save list good
for one plot can kill another. Verified: `save onoise_spectrum` + `noise v(out) v1 dec 2
1k 100k` produced only `noise1 (Noise Spectral Density Curves)`; the *Integrated Noise*
plot was gone, and the only diagnostic was the misleading
`"Error: no data saved for Noise analysis; analysis not run"` **[verified]**. The same
deck without `save` produced both plots. NOISE ignores the return value of the integrated
plot's `OUTpBeginPlot` (`noisean.c:532`), which is why it does not abort.

**GUI rule: do not narrow the save list for NOISE (and be careful with DISTO's 2-or-3
plots). If you must, save both `*_spectrum` and `*_total` names.**

`.print <plottype> <exprs>` in batch mode is handled by the *frontend*
(`src/frontend/dotcards.c:314-341`), matching plots with
`ciprefix(plottype, pl->pl_typename)`. So `.print ac …`, `.print noise …`,
`.print pz all`, `.print sens all`, `.print disto …` all work; `.print tf …` works, and TF
additionally prints itself unconditionally in batch mode
(`dotcards.c:274-284`, `"Transfer function information:"`) **[verified]**.

Note `INP2dot` itself declares `.print`/`.plot`/`.width` obsolete and errors on them
(`inp2dot.c:854-860`); they never reach the parser because `src/frontend/inp.c:817-822`
strips them into the frontend's `coms` list first.

### 1.11 Interrupt / pause behaviour (Ctrl-C mid-sweep)

| analysis | pause supported? | resume supported? |
|---|---|---|
| AC | yes — `IFpauseTest()` at `acan.c:243`, saves `ACsaveFreq`, returns `E_PAUSE` | yes — `acan.c:183-193` re-opens the plot with the `numNames==666 && dataType==666` resume hack |
| NOISE | yes — `noisean.c:365-370`, saves `NsavFstp`/`NsavOnoise`/`NsavInoise` | yes — `noisean.c:289-318` |
| PZ | yes — `cktpzstr.c:189-193`, warns `"Pole-Zero analysis interrupted; %d trials, %d roots"` | no (restart only) |
| TF | no test at all | n/a (single point) |
| DISTO | **pause test is commented out** — `distoan.c:256-261` | no |
| SENS | test at `cktsens.c:362-366` returns `E_PAUSE`, but `restart` is hard-forced to 1 at `cktsens.c:162`, so the resume branch (`:302-308`, which would `fprintf(stderr, "ERROR: restore is not implemented for cktsens"); controlled_exit(1);`) is dead and a resume silently restarts | no |

The `666/666` resume protocol is at `outitf.c:198-202`.

### 1.12 Known open defect touching this area

`doc/codex/issues/0012-ac-rawfile-scale-imaginary-part-uninitialised.md` — a binary
rawfile from an AC analysis is not byte-reproducible: the *imaginary* half of the
`frequency` scale vector is uninitialised heap (values ≈5e-310). Status: Open. Affects any
GUI that hashes or diffs rawfiles.

---

## 2. AC — small-signal frequency response

### 2.1 JOB struct and parameter table

`src/include/ngspice/acdefs.h:13-24`:

```c
typedef struct {
    int JOBtype; JOB *JOBnextJob; char *JOBname;
    double ACstartFreq;
    double ACstopFreq;
    double ACfreqDelta;   /* multiplier for dec/oct, step for lin */
    double ACsaveFreq;    /* resume point */
    int ACstepType;       /* DECADE=1 OCTAVE=2 LINEAR=3 */
    int ACnumberSteps;
} ACAN;
```

Step-type enum `DECADE=1, OCTAVE, LINEAR` at `acdefs.h:37-41` (guarded against the
RFSPICE `spdefs.h` copy at `:28-35`). Parameter ids `AC_DEC=1, AC_OCT, AC_LIN, AC_START,
AC_STOP, AC_STEPS` at `acdefs.h:44-51`.

**Complete `ACparms[]`** — `src/spicelib/analysis/acsetp.c:85-92`:

| keyword | id | dataType | description | unit | notes |
|---|---|---|---|---|---|
| `start` | `AC_START` | `IF_SET\|IF_ASK\|IF_REAL` | "starting frequency" | Hz | `< 0` rejected with `errMsg "Frequency of < 0 is invalid for AC start"` and `E_PARMVAL`; **on rejection it writes `ACstartFreq = 1.0`** (`acsetp.c:25-29`) |
| `stop` | `AC_STOP` | `IF_SET\|IF_ASK\|IF_REAL` | "ending frequency" | Hz | `< 0` rejected the same way — and the error arm also sets **`ACstartFreq`** (not `ACstopFreq`) to 1.0, a copy-paste slip (`acsetp.c:34-39`) |
| `numsteps` | `AC_STEPS` | `IF_SET\|IF_ASK\|IF_INTEGER` | "number of frequencies" | count | *points per decade* for `dec`, *per octave* for `oct`, *total points* for `lin` |
| `dec` | `AC_DEC` | `IF_SET\|IF_FLAG` | "step by decades" | — | `IF_ASK` **not** set in the table, but `ACaskQuest` answers it anyway (`acaskq.c:37-45`) |
| `oct` | `AC_OCT` | `IF_SET\|IF_FLAG` | "step by octaves" | — | same |
| `lin` | `AC_LIN` | `IF_SET\|IF_FLAG` | "step linearly" | — | same |

The three flags are mutually exclusive by construction: setting one with a nonzero value
assigns `ACstepType`; setting one with a **zero** value clears `ACstepType` only if it
currently equals that type (`acsetp.c:48-76`). The parser always passes `iValue = 1`
(`inp2dot.c:209`), so the clearing path is unreachable from a deck.

`ACaskQuest` (`src/spicelib/analysis/acaskq.c:16-74`) answers all six.

### 2.2 Netlist card and `.control` command

`src/spicelib/parser/inp2dot.c:182-245` (`dot_ac`). Documented form
(`inp2dot.c:197`, and `src/ngspice.txt:2939-2941`):

```
.AC DEC ND FSTART FSTOP
.AC OCT NO FSTART FSTOP
.AC LIN NP FSTART FSTOP
```

`.control` form: `ac ( DEC | OCT | LIN ) N Fstart Fstop` (`src/ngspice.txt:3905`).

Parse steps, in order:

1. `INPgetTok` the step type; **hard error** `"Missing DEC, OCT, or LIN."` unless it
   `ciprefix`-matches `dec`/`oct`/`lin` (`inp2dot.c:204-208`). Verified **[verified]**.
   Note the guard is a *prefix* test but `INPapName` then requires an *exact*
   (case-insensitive) keyword, so `.ac decade …` passes the guard and dies in
   `INPapName` **[verified]**.
2. `numsteps` (`IF_INTEGER`). **If `< 1` it is silently replaced by 10** and `pdef` is
   set (`inp2dot.c:213-218`).
3. `fstart` (`IF_REAL`). If negative → replaced by `1.` (`:222-227`). Also, if the next
   character is not a digit or `.`+digit, `pdef` is set (`:220-221`).
4. `fstop` (`IF_REAL`). **If `fstop < fstart` it is silently replaced by
   `1000 * fstart`** (`:230-237`).
5. If any substitution happened, two lines go to stderr
   (`inp2dot.c:240-243`):
   `"Warning, ngspice assumes default parameter(s) for ac simulation"` +
   `"    Check your input line '.ac %s'"`.

Verified: `ac dec 5 10k 1k` produced that warning and swept 10 kHz…10 MHz (16 points)
**[verified]**. `ac dec 0 1k 10k` warned and used 10 pts/dec (11 points) **[verified]**.
**This silent fstop rewrite is a serious usability trap the GUI should pre-empt by
validating `fstop >= fstart` and `numsteps >= 1` itself.**

`.ac` with no step type at all → `"Error: Missing DEC, OCT, or LIN."` and the analysis
aborts **[verified]**.

### 2.3 Point counting — the exact arithmetic (`src/spicelib/analysis/acan.c:71-117`)

`ACan` first clamps `if (job->ACnumberSteps < 1) job->ACnumberSteps = 1;` (`acan.c:72-73`).

**DECADE** (`acan.c:77-94`):
* `ACstartFreq <= 0` → `fprintf(stderr, "ERROR: AC startfreq <= 0\n")` + `E_PARMVAL`
  (`:78-81`).
* if `stop/10 < start` (i.e. **less than a decade of span**):
  `ACfreqDelta = 1` when `stop == start`, else `exp(log(10)/N)` (`:82-88`) — the raw
  per-decade ratio, with **no attempt to land on `fstop`**.
* else: `num_steps = floor(|log10(stop/start)| * N)`, then
  `ACfreqDelta = exp(log(stop/start) / num_steps)` (`:90-91`) — the delta is
  **recomputed** so the last point lands exactly on `fstop`, at the cost of the actual
  points/decade being `floor(N*decades)/decades` rather than `N`.

**OCTAVE** (`acan.c:95-102`): `start <= 0` → same error; `ACfreqDelta = exp(log(2)/N)`.
No "land on fstop" correction.

**LINEAR** (`acan.c:103-114`): `ACfreqDelta = (stop-start)/(N-1)` when `N-1 > 1`, else
`0` (a "rather pathological case: a linear step with only one point", per the comment
attributing the patch to Richard McRoberts).

**Anything else** (i.e. `ACstepType == 0`, which is what you get if no flag was set) →
`E_BADPARM` (`acan.c:115-116`).

Loop bound (`acan.c:242`): `while (freq <= job->ACstopFreq + freqTol)`, with

```
DECADE/OCTAVE: freqTol = ACfreqDelta * ACstopFreq * ckt->CKTreltol   (acan.c:198-199)
LINEAR:        freqTol = ACfreqDelta * ckt->CKTreltol                (acan.c:202)
```

`CKTreltol` defaults to 1e-3 (`.options reltol`), so the DEC/OCT tolerance is a *relative*
band of ~`delta*1e-3*fstop` — meaning for sub-decade DEC sweeps the last point can fall
just outside and be dropped.

Measured point counts **[all verified]**:

| command | points | why |
|---|---|---|
| `ac dec 5 1k 100k` | 11 | 2 decades × 5 + 1 |
| `ac oct 2 1k 8k` | 7 | 3 octaves × 2 + 1 |
| `ac lin 11 1k 11k` | 11 | `numsteps` is the total |
| `ac lin 1 1k 1k` | 1 | delta forced to 0, single point |
| `ac dec 3 1k 2k` | **1** | sub-decade branch: next point 2154 Hz > 2000+tol |
| `ac dec 10 1k 2k` | 4 | 1000, 1259, 1585, 1995 |
| `ac dec 100 1k 2k` | 31 | |
| `ac dec 10 1k 1k` | 1 | `ACfreqDelta = 1` → `goto endsweep` after one point (`acan.c:367`) |
| `ac dec 7 1k 1meg` | 22 | ≥1-decade branch: `num_steps = floor(3*7) = 21` |

**GUI implication:** show the user the *actual* point count you compute with this exact
arithmetic, and warn when a `dec`/`oct` span narrower than one decade will produce far
fewer points than "N per decade" suggests.

### 2.4 What makes an AC run meaningless, and how a source gets its AC value

`src/ngspice.txt:2960-2962`: "in order for this analysis to be meaningful, at least one
independent source must have been specified with an ac value."

**There is no check for this in the code.** Verified: a deck whose only source is
`v1 in 0 dc 1` (no `ac`) runs an AC sweep to completion and reports `v(out)` = `0,0` at
every frequency, with **no warning of any kind** **[verified]**. The GUI must validate
this itself.

How AC excitation is specified on a **VSRC** (`src/spicelib/devices/vsrc/vsrc.c:12-52`,
`vsrcpar.c:36-81`, `vsrctemp.c:38-70`):

| deck syntax | keyword / id | effect |
|---|---|---|
| `Vxx n+ n- AC` | `ac` / `VSRC_AC`, `IF_REALVEC` (`vsrc.c:45`) | 0-element vector → only `VSRCacGiven = TRUE` (`vsrcpar.c:75-77`) |
| `Vxx n+ n- AC <mag>` | same, 1 element | `VSRCacMag = mag`, `acMGiven` (`vsrcpar.c:71-74`) |
| `Vxx n+ n- AC <mag> <phase>` | same, 2 elements | also `VSRCacPhase = phase`, `acPGiven` (`vsrcpar.c:67-70`) |
| `alter v1 acmag=…` | `acmag` / `VSRC_AC_MAG`, `IF_REAL` (`vsrc.c:14`) | sets mag + `acGiven` (`vsrcpar.c:51-55`) |
| `alter v1 acphase=…` | `acphase` / `VSRC_AC_PHASE`, `IF_REAL` (`vsrc.c:15`) | sets phase + `acGiven` (`vsrcpar.c:57-61`) |
| readback only | `acreal` / `VSRC_AC_REAL`, `acimag` / `VSRC_AC_IMAG` (`vsrc.c:43-44`, `OPU` = output-only, unquestionable) | derived, see below |

**Defaults, set in `VSRCtemp`:** `if (acGiven && !acMGiven) acMag = 1;` and
`if (acGiven && !acPGiven) acPhase = 0;` (`vsrctemp.c:38-43`). Then
`acReal = acMag*cos(phase*pi/180)`, `acImag = acMag*sin(phase*pi/180)`
(`vsrctemp.c:68-70`) — **phase is in degrees**.

`VSRCacLoad` (`src/spicelib/devices/vsrc/vsrcacld.c:158-180`, the non-RFSPICE arm at
`:158`) stamps `rhs[branch] += acReal; irhs[branch] += acImag`, **except** when
`CKTmode & MODEACNOISE`, in which case exactly one source — the one `ckt->noise_input`
points at — gets `(1.0, 0.0)` and every other AC source is forced to zero
(`vsrcacld.c:159-172`). That is how NOISE reuses the AC machinery.

ISRC is the analogous device: `ISRCacGiven` is checked by NOISE at `noisean.c:126`; its
parameter table lives in `src/spicelib/devices/isrc/isrc.c`.

### 2.5 Output: vectors, scale, log grid

`ACan` builds the namelist from `CKTnames()` (`acan.c:152`), which is simply **every
circuit equation name in `ckt->CKTnodes` order** (`src/spicelib/analysis/cktnames.c:18-31`,
`numNames = ckt->CKTmaxEqNum - 1`). So AC vectors are:

* one vector per **node**, named exactly as the (case-folded) node name in the deck;
* one vector per **branch equation**, named `<source>#branch` (voltage sources, inductors,
  CCVS/VCVS…);
* the scale vector `frequency`, whose UID is created at `acan.c:168`
  (`IFnewUid(..., "frequency", UID_OTHER, ...)`).

Data type: `IF_COMPLEX` for the data, `IF_REAL` for the reference
(`acan.c:169-173`); dumped by `CKTacDump` (`src/spicelib/analysis/cktacdum.c:19-42`),
which copies `CKTrhsOld[i+1]` / `CKTirhsOld[i+1]` into `IFcomplex`.

Log grid: `if (job->ACstepType != LINEAR) OUTattributes(acPlot, NULL, OUT_SCALE_LOG,
NULL)` (`acan.c:177-179`) → the vector shows `grid = xlog` and the rawfile variable line
gets `grid=3` (`outitf.c:1113-1114`).

Verified vector set for a 3-node BJT deck **[verified]**:

```
Name: ac1 (AC Analysis)
  base      : voltage, complex, 21 long
  col       : voltage, complex, 21 long
  frequency : frequency, complex, 21 long, grid = xlog [default scale]
  in        : voltage, complex, 21 long
  v1#branch : current, complex, 21 long
  vcc       : voltage, complex, 21 long
  vcc#branch: current, complex, 21 long
```

(Note `frequency` reports as `complex` in the plot even though it is written as `IF_REAL`
— the `plotInit` "hack" at `outitf.c:1221-1226` promotes *all* vectors to complex if any
one is. This is the same code path implicated in `doc/codex/issues/0012`.)

Post-processing the GUI will want: `vdb()`, `vm()`, `vp()`, `vr()`, `vi()`, `db()`,
`mag()`, `ph()`, `cph()`, `unwrap()` are all control-language functions over these
complex vectors (frontend, out of this dossier's scope).

### 2.6 AC and `WANT_SENSE2`

`acan.c:315-336` contains an `#ifdef WANT_SENSE2` block calling `CKTsenAC` with
`SENacpertflag`. It is dead in every buildable configuration — see §8.

---

## 3. NOISE

### 3.1 JOB struct, working struct, constants

`src/include/ngspice/noisedef.h:66-83`:

```c
typedef struct {
    int JOBtype; JOB *JOBnextJob; char *JOBname;
    CKTnode *output;      /* noise output summation node */
    CKTnode *outputRef;   /* noise output reference node */
    IFuid input;          /* name of the AC source used as input reference */
    double NstartFreq, NstopFreq, NfreqDelta;
    double NsavFstp, NsavOnoise, NsavInoise;   /* pause/resume state */
    int NstpType;         /* DECADE=1 OCTAVE=2 LINEAR=3 */
    int NnumSteps;
    int NStpsSm;          /* points per summary report */
} NOISEAN;
```

`Ndata` inter-stage struct at `noisedef.h:89-109` (`freq`, `GainSqInv`, `lnGainInv`,
`outNoiz`, `inNoise`, `outNumber`, `numPlots`, `prtSummary`, `outpVector`,
`squared_value`, `NplotPtr`, `namelist`, `squared:1`).

Per-generator state array indices: `LNLSTDENS=0`, `OUTNOIZ=1`, `INNOIZ=2`, `NSTATVARS=3`
(`noisedef.h:114-118`).

Modes/ops: `N_DENS=1`, `INT_NOIZ=2`; `N_OPEN=1`, `N_CALC=2`, `N_CLOSE=3`;
`SHOTNOISE=1`, `THERMNOISE=2`, `N_GAIN=3` (`noisedef.h:146-153`).

Numerical guards (`noisedef.h:158-170`) — hard-coded, **not user-settable**:

| constant | value | meaning |
|---|---|---|
| `N_MINLOG` | `1e-38` | smallest number whose log is taken |
| `N_MINGAIN` | `1e-20` | smallest input→output gain tolerated (floor for `1/GainSq`) |
| `N_INTFTHRESH` | `1e-10` | slope below which a log-log spectrum counts as flat |
| `N_INTUSELOG` | `1e-10` | band around exponent −1 where the `ln` integral form is used |

### 3.2 Complete `Nparms[]` — `src/spicelib/analysis/nsetparm.c:82-93`

| keyword | id | dataType | description | value union member actually used |
|---|---|---|---|---|
| `output` | `N_OUTPUT` | `IF_SET\|IF_STRING` | "output noise summation node" | **`value->nValue`** (a `CKTnode *`) — `nsetparm.c:24` |
| `outputref` | `N_OUTREF` | `IF_SET\|IF_STRING` | "output noise reference node" | **`value->nValue`** — `nsetparm.c:28` |
| `input` | `N_INPUT` | `IF_SET\|IF_STRING` | "input noise source" | `value->uValue` (IFuid) — `nsetparm.c:32` |
| `dec` | `N_DEC` | `IF_SET\|IF_FLAG` | "step by decades" | sets `NstpType = DECADE` unconditionally (no zero-clears branch, unlike AC) — `:35-37` |
| `oct` | `N_OCT` | `IF_SET\|IF_FLAG` | "step by octaves" | `:39-41` |
| `lin` | `N_LIN` | `IF_SET\|IF_FLAG` | "step linearly" | `:43-45` |
| `numsteps` | `N_STEPS` | `IF_SET\|IF_INTEGER` | "number of frequencies" | `:47-49` |
| `start` | `N_START` | `IF_SET\|IF_REAL` | "starting frequency" | `<= 0` → `errMsg "Frequency of 0 is invalid"`, `E_PARMVAL`, and sets `NstartFreq = 1.0` — `:51-59` |
| `stop` | `N_STOP` | `IF_SET\|IF_REAL` | "ending frequency" | `<= 0` → same, and again sets **`NstartFreq`** (copy-paste slip) — `:61-69` |
| `ptspersum` | `N_PTSPERSUM` | `IF_SET\|IF_INTEGER` | "frequency points per summary report" | `:71-73` |

**Note the `IF_STRING`/`nValue` mismatch on `output` and `outputref`:** the table declares
them strings but the setter reads the node-pointer member. This works only because the
parser hands over a resolved `CKTnode *` (`inp2dot.c:59`, `:65`). A GUI or a script that
tried to drive these through a generic string path would corrupt a pointer. Do not go
around `dot_noise`.

`NaskQuest` (`src/spicelib/analysis/naskq.c:14-89`) answers all ten ids — but **no entry
in `Nparms[]` carries `IF_ASK`**, so nothing in the front end can reach it.

### 3.3 Card and command syntax

`src/spicelib/parser/inp2dot.c:18-121` (`dot_noise`), documented form at
`inp2dot.c:36` and `src/ngspice.txt:3126-3127`:

```
.NOISE V(OUTPUT <,REF>) SRC ( DEC | LIN | OCT ) PTS FSTART FSTOP <PTSPERSUMMARY>
```

`.control`: `noise v(out<,ref>) src (dec|lin|oct) pts fstart fstop <ptspersummary>`.

Argument-by-argument (all anchors in `inp2dot.c`):

1. The first token **must** be exactly `V` or `v` with nothing after it (`:50`), then
   `(`. Anything else → `LITERR("bad syntax [.noise v(OUT) SRC {DEC OCT LIN} NP FSTART
   FSTOP <PTSPRSUM>]")` (`:111-119`).
2. `output` node: `INPgetNetTok` + `INPtermInsertRef` → `"output"` (`:57-60`). The comment
   at `:52-56` notes this is a *reference* to an existing node, not a definition, so a
   typo is reported later by `INPtermCaseCheck()` (see
   `doc/claude/decisions/0008-undefined-node-diagnostic.md`).
3. optional `,ref` node → `"outputref"`; **if absent, `gnode` (ground) is used**
   (`:62-69`).
4. `SRC`: an instance name → `"input"` (`:71-75`).
5. step type token → passed straight through as a keyword (`:77-82`).
6. `numsteps` (`IF_INTEGER`) → `"numsteps"` (`:83-86`).
7. `fstart` → `"start"` (`:87-90`).
8. `fstop` → `"stop"` (`:91-94`).
9. `PTSPERSUMMARY`: present only if a non-blank token remains (`:98-99`); **if absent,
   `ptspersum` is explicitly set to 0** (`:105-110`). So `NStpsSm` default is 0 *by the
   parser*, not just by `calloc`.

Unlike `.ac`, `dot_noise` performs **no** range fix-ups: bad values just propagate to the
`N_START`/`N_STOP` guards or to `NOISEan`'s own checks.

### 3.4 Pre-flight checks in `NOISEan` (`src/spicelib/analysis/noisean.c`)

In order:

1. **`option klu` refusal** (`:73-78`):
   `"Error: Noise simulation is not (yet) supported with 'option KLU'.\n    Use 'option
   sparse' instead."` → `E_UNSUPP`. (Compiled in this tree because `KLU` is defined; KLU
   is off by default so this normally does not fire.)
2. `posOutNode = job->output->number`, `negOutNode = job->outputRef->number` (`:84-85`).
   **No NULL check** — a card that failed to set `output` would crash. In practice
   `dot_noise` always sets both.
3. `NnumSteps < 1` → warning `"Number of steps for noise measurement has to be larger
   than 0,\n    but currently is %d"` + `E_PARMVAL` (`:87-92`).
4. Single-frequency normalisation (`:93-109`), using
   `AlmostEqualUlps(NstartFreq, NstopFreq, 3)` (`:82`):
   * `numsteps == 1 && LINEAR` and start≠stop → `NstopFreq = NstartFreq` + warning
     `"Noise measurement at a single frequency %g only!"`;
   * otherwise, if start≈stop → `NstopFreq = NstartFreq`, `NnumSteps = 1`, same warning.
   Verified: `noise v(out) v1 lin 1 1k 1k` emits that warning **[verified]**.
5. Input-source validation (`:110-142`):
   * `CKTfndDev(ckt, job->input)` (`:81`); not found or `GENmodType < 0` → warning
     `"Noise input source %s not in circuit"` + `E_NOTFOUND` (`:114-119`);
   * must be `CKTtypelook("Vsource")` → `src_type = SV_VOLTAGE`, or
     `CKTtypelook("Isource")` → `SV_CURRENT`; anything else → warning
     `"Noise input source %s is not of proper type"` + `E_NOTFOUND` (`:121-134`);
   * the source must have `acGiven`; else warning `"Noise input source %s has no AC
     value"` + `E_NOACINPUT` (`:136-141`). Verified: message plus
     `doAnalyses: ac input not found` **[verified]**.

`E_NOACINPUT` text is `"ac input not found"` (`src/spicelib/parser/sperror.c:105`,
code `E_PRIVATE+14` at `src/include/ngspice/sperror.h:29`).

### 3.5 Frequency stepping (differs from AC!)

`noisean.c:145-168`:

```
DECADE: NfreqDelta = exp(log(10.0) / NnumSteps)
OCTAVE: NfreqDelta = exp(log(2.0)  / NnumSteps)
LINEAR: NfreqDelta = (NnumSteps == 1) ? 0 : (NstopFreq - NstartFreq)/(NnumSteps - 1)
default: E_BADPARM
```

**NOISE has no "land exactly on fstop" correction** for DEC/OCT — unlike AC's
`acan.c:90-91`. `freqTol` mirrors AC (`noisean.c:320-330`). Loop at `:364`
`while (data->freq <= job->NstopFreq + freqTol)`, and `:501-502`
`if ((NnumSteps == 1) && (NstpType == LINEAR)) break;`.

Verified `noise v(out) v1 dec 5 1k 10meg` → 21 spectral rows **[verified]**, matching
`4 decades × 5 + 1`.

### 3.6 The algorithm, per frequency point (`noisean.c:364-503`)

1. `CKTomega = 2*pi*freq`; `CKTmode = MODEAC | MODEACNOISE` (`:430-431`).
2. `ckt->noise_input = inst` (`:432`) — this is what makes `VSRCacLoad`/`ISRCacLoad`
   inject a unit excitation at the chosen source and zero all others (§2.4).
3. `NIacIter(ckt)` (`:439`) — solves the **normal** AC system to get the input→output
   transfer function.
4. `GainSqInv = 1 / MAX(|V_out|^2, N_MINGAIN)`; `lnGainInv = log(GainSqInv)` (`:440-446`).
   `V_out = (rhsOld[pos]-rhsOld[neg]) + j(irhsOld[pos]-irhsOld[neg])`.
5. `prtSummary = (NStpsSm != 0) && (step % NStpsSm == 0)` (`:457-462`).
6. `NInzIter(ckt, posOutNode, negOutNode)` (`:473`) — solves the **adjoint** system.
   `src/maths/ni/niniter.c:21-39`: clears the RHS, sets `rhs[posDrive]=1`,
   `rhs[negDrive]=-1`, and calls `SMPcaSolve` (transposed solve) reusing the matrix that
   `NIacIter` already factored.
7. `CKTnoise(ckt, N_DENS, N_CALC, data)` (`:479`) — walks every device's `DEVnoise`.

Each device's noise routine turns an adjoint-solution voltage into an output-referred
density via `NevalSrc` / `NevalSrc2` / `NevalSrcInstanceTemp`
(`src/spicelib/analysis/nevalsrc.c`). The non-RF arms:

```
gain = (rhs[n1]-rhs[n2])^2 + (irhs[n1]-irhs[n2])^2          nevalsrc.c:100-102
SHOTNOISE : *noise = gain * 2*CHARGE*|param|                 nevalsrc.c:105-108
THERMNOISE: *noise = gain * 4*CONSTboltz*CKTtemp*param       nevalsrc.c:110-113
N_GAIN    : *noise = gain                                    nevalsrc.c:115-117
```

`NevalSrcInstanceTemp` is the same with `(CKTtemp + param2)` for the thermal case, where
`param2` is the instance `dtemp` (`nevalsrc.c:337-338`) — "It will replace NevalSrc as
soon as all devices will implement dtemp feature" (`nevalsrc.c:256-262`).
`NevalSrc2` handles two fully-correlated sources with a relative phase `phi21`, used for
BSIM4 `tnoiMod=2` correlated gate/drain noise (`nevalsrc.c:122-137`, `:225-252`).

Integration over frequency is `Nintegrate(noizDens, lnNdens, lnNlstDens, data)`
(declared `noisedef.h:210`), a log-log curve fit whose behaviour is governed by
`N_INTFTHRESH` / `N_INTUSELOG`.

### 3.7 The two plots, exactly

**Plot 1 — spectral density.** Opened at `noisean.c:274-282`:

* title: `data->squared ? "Noise Spectral Density Curves - (V^2 or A^2)/Hz" :
  "Noise Spectral Density Curves"`;
* reference: `frequency`, `IF_REAL`; data: `IF_REAL`;
* log x-scale unless `NstpType == LINEAR` (`:284-286`).

Namelist is assembled by `CKTnoise(ckt, N_DENS, N_OPEN, data)` (`:250`): device routines
append their per-source names **first**, then `cktnoise.c:56-64` appends the two
circuit-level vectors, always last:

```
onoise_spectrum      cktnoise.c:59
inoise_spectrum      cktnoise.c:64
```

Data rows are written by `cktnoise.c:101-118`:
`outpVector[outNumber++] = outNdens;` then `= outNdens * GainSqInv;` with
`refVal.rValue = data->freq`. **The row is written only when
`job->NStpsSm == 0 || data->prtSummary`** (`cktnoise.c:102-103`).

So `ptspersum` **decimates the spectrum**: with `ptspersum = 4` over 21 frequency points
you get rows at steps 0,4,8,12,16,20 → **6 rows** **[verified]**.

**Plot 2 — integrated noise.** Opened at `noisean.c:532-538`, **and only if
`job->NstartFreq != job->NstopFreq`** (`:511`):

* title: `data->squared ? "Integrated Noise - V^2 or A^2" : "Integrated Noise"`;
* **no reference vector** (`NULL, 0`), one row, `IF_REAL`.

Namelist from `CKTnoise(INT_NOIZ, N_OPEN)`: device per-source names, then
`cktnoise.c:76-82`:

```
onoise_total         cktnoise.c:78
inoise_total         cktnoise.c:82
```

Values: `outpVector[outNumber++] = data->outNoiz; = data->inNoise;`
(`cktnoise.c:121-122`).

Verified with a single-frequency noise run: **only the spectral plot exists** — no
`Integrated Noise` plot at all **[verified]**. A GUI offering "spot noise at f" must not
look for `onoise_total`.

### 3.8 Squared vs. RMS output — `set sqrnoise`

`noisean.c:242`: `data->squared = cp_getvar("sqrnoise", CP_BOOL, NULL, 0) ? 1 : 0;`.
It is a **control-language variable**, `unset` by default (it appears nowhere in
`src/spinit.in`).

| | `sqrnoise` unset (default) | `set sqrnoise` |
|---|---|---|
| spectral plot title | `Noise Spectral Density Curves` | `… - (V^2 or A^2)/Hz` |
| integrated plot title | `Integrated Noise` | `Integrated Noise - V^2 or A^2` |
| `onoise_spectrum` type | `voltage-density` (V/√Hz) | `voltage^2-density` ((V²)/Hz) |
| `inoise_spectrum` type | `voltage-density` for a Vsource input, `current-density` for an Isource input | `voltage^2-density` / `current^2-density` |
| `onoise_total` type | `voltage` (V) | `voltage^2` (V²) |
| `inoise_total` type | `voltage` / `current` | `voltage^2` / `current^2` |
| values | `sqrt()` applied to every vector | raw squared values |

Anchors: `noisean.c:258-266` (density types), `:516-524` (integrated types),
`:268-272` and `:526-530` (`squared_value[i] = ciprefix("inoise",name) ||
ciprefix("onoise",name)` — which is *every* name in these plots), `cktnoise.c:110-113`
and `:123-126` (the `sqrt`), `outitf.c:1037-1040` (type lookup).

Verified for a 10 k / 1 nF RC with a Vsource input **[verified]**:
default `onoise_total = 1.984461e-06`, `inoise_total = 5.122594e-05`, types
`voltage`/`voltage-density`; with `set sqrnoise`, `onoise_total = 3.938086e-12`
(= 1.984461e-06²), types `voltage^2`/`voltage^2-density`.

> **Doc/source conflict.** The built-in help says the opposite:
> `src/ngspice.txt:3149-3155` — "All noise voltages/currents are in squared units (V²/Hz
> and A²/Hz for spectral density, V² and A² for integrated noise)." That text is inherited
> from SPICE3 and is **stale**; `sqrnoise` and the `sqrt()` were added later.
> **Trust the source and the measurement: RMS/√Hz is the default.** (The current ngspice
> manual, <https://ngspice.sourceforge.io/docs/ngspice-manual.pdf>, documents `sqrnoise`
> in its variables chapter.)

### 3.9 Per-generator breakdown: names and the `ptspersum` gate

Every device noise routine registers its per-source vectors **only when
`job->NStpsSm != 0`** — e.g. `src/spicelib/devices/res/resnoise.c:68`
`if (job->NStpsSm != 0) { switch (mode) { case N_DENS: … } }`. So:

* `ptspersum` absent or 0 → the plots contain **only** `onoise_spectrum` /
  `inoise_spectrum` and `onoise_total` / `inoise_total` **[verified]**;
* `ptspersum >= 1` → per-device, per-mechanism vectors appear **and** the spectrum is
  decimated by that factor.

That coupling is unfortunate for a GUI: to get a noise-contribution table you must accept
a decimated spectrum. `ptspersum = 1` gives the breakdown with **no** decimation and is
the setting a "noise summary" feature should use.

**Name templates.** Two incompatible conventions coexist:

* Most devices: `"onoise_%s%s"`, `"onoise_total_%s%s"`, `"inoise_total_%s%s"` with
  `instance_name` + a suffix that starts with `_` (`resnoise.c:73`, `:79-80`).
* BSIM3 / BSIM3v0 / BSIM3v1 / BSIM3v32 / BSIM4 / BSIM4v5-v7 / BSIMSOI / HiSIM family:
  `"onoise.%s%s"`, `"onoise_total.%s%s"` with suffixes that start with `.`
  (`src/spicelib/devices/bsim4/b4noi.c:145,150-151`;
  `bsim3/b3noi.c:155,160-161`; `bsimsoi/b4soinoi.c:166`; `bsim3v32/b3v32noi.c:224`;
  `hisim2/hsm2noi.c:101-109`).

So for a BSIM4 instance `m1` you get `onoise.m1.rd`, `onoise.m1.1overf`, `onoise.m1` —
**dots**, not underscores. For a resistor `r1` you get `onoise_r1_thermal`,
`onoise_r1_1overf`, `onoise_r1`. Verified for BJT/RES **[verified]**:

```
onoise_total_q1  onoise_total_q1_rc  onoise_total_q1_rb  onoise_total_q1_re
onoise_total_q1_ic  onoise_total_q1_ib  onoise_total_q1_1overf
onoise_total_r1  onoise_total_r1_thermal  onoise_total_r1_1overf
(and the matching inoise_total_* set)
```

Note the `""` (empty-suffix) entry in each device's name table is the **device total** —
so `onoise_total_q1` is Q1's total and `onoise_total_q1_ic` is one mechanism of it.

Per-device mechanism suffix lists (from the `*nNames[]` arrays):

| device | file:line | suffixes |
|---|---|---|
| RES | `res/resnoise.c:46-52` | `_thermal`, `_1overf`, `` (total) |
| DIO | `dio/dionoise.c:45-51` | `_rs`, `_id`, `_1overf`, `_rsw`, `_idsw`, `_1overfsw`, `` |
| BJT | `bjt/bjtnoise.c:44-50` | `_rc`, `_rb`, `_re`, `_ic`, `_ib`, `_1overf`, `` |
| VBIC | `vbic/vbicnoise.c:46-59` | `_rc`, `_rci`, `_rb`, `_rbi`, `_re`, `_rbp`, `_rs`, `_ic`, `_ib`, `_ibep`, `_iccp`, `_1overfbe`, `_1overfbep`, `` |
| HICUM2 | `hicum2/hicum2noise.c:51-64+` | `_rcx`, `_rbx`, `_rbi`, `_re`, `_rsu`, `_iavl`, `_ibci`, `_ibep`, `_ijbcx`, `_ijsc`, `_it`, `_ibei`, `_1overfbe`, `_1overfre`, … |
| MOS1/2/3/9, JFET, JFET2, MES, VDMOS, SOI3 | `mos1/mos1noi.c:45-53`, `mos3/mos3noi.c:44-52`, `mos9/mos9noi.c:42-46`, `jfet/jfetnoi.c:44-48`, `jfet2/jfet2noi.c:46-50`, `mes/mesnoise.c:41-45`, `vdmos/vdmosnoi.c:44-48`, `soi3/soi3nois.c:65-69` | `_rd`, `_rs`, `_id`, `_1overf`, `` |
| BSIM3 / BSIM3v32 | `bsim3/b3noi.c:131-140`, `bsim3v32/b3v32noi.c:200-209` | `.rd`, `.rs`, `.id`, `.1overf`, `` |
| BSIM4 (v5-v7) | `bsim4/b4noi.c:111-125+` | `.rd`, `.rs`, `.rg`, `.rbps`, `.rbpd`, `.rbpb`, `.rbsb`, `.rbdb`, `.id`, `.1overf`, `.igs`, `.igd`, … |
| BSIMSOI (B4SOI) | `bsimsoi/b4soinoi.c:129-141+` | `.rd`, `.rs`, `.rg`, `.id`, `.1overf`, `.fb_ibs`, `.fb_ibd`, `.igs`, `.igd`, … |
| HiSIM2 | `hisim2/hsm2noi.c:101-109` | `.rd`, `.rs`, `.id`, `.1ovf`, `.igs`, `.igd`, `.igb`, `.ign`, `` |
| SW / CSW | `sw/swnoise.c:51-55`, `csw/cswnoise.c` | total only (empty suffix) |
| OSDI | `src/osdi/osdinoise.c:94-113` | `onoise_<inst>_<src_name>` from the model's declared `noise_sources[]`; total is `onoise_<inst>` for `N_DENS` but **`onoise_total_<inst> ` with a trailing space** for `INT_NOIZ` (`osdinoise.c:111-113`) — a naming bug the GUI should tolerate |
| XSPICE code models | `src/xspice/mif/mifnoise.c:584,592-597` | `onoise_<inst><src_name>` from the code model's declared/programmatic sources |

### 3.10 Which devices contribute noise at all

`CKTnoise` iterates `DEVices[i]->DEVnoise` (`src/spicelib/analysis/cktnoise.c:38-44`).
Non-NULL in this tree (from the `DEV*init.c` tables):

**Contribute:** `bjt`, `bsim1`, `bsim2`, `bsim3`, `bsim3soi_dd`, `bsim3soi_fd`,
`bsim3soi_pd`, `bsim3v0`, `bsim3v1`, `bsim3v32`, `bsim4`, `bsim4v5`, `bsim4v6`,
`bsim4v7`, `bsimsoi`, `csw`, `dio`, `hicum2`, `hisim2`, `hisimhv1`, `hisimhv2`, `jfet`,
`jfet2`, `mes`, `mos1`, `mos2`, `mos3`, `mos9`, `res`, `soi3`, `sw`, `vbic`, `vdmos`,
plus `osdi` (`src/osdi/osdiinit.c:200`) and XSPICE code models
(`src/xspice/cmpp/writ_ifs.c:1109` emits `.DEVnoise = MIFnoise` into every generated
`ifspec` C file).

**Do not contribute (`DEVnoise = NULL`):** `asrc` (B-source), `cap`, `cccs`, `ccvs`,
`cpl`, `hfet1`, `hfet2`, `ind` (and mutual), `isrc`, `ltra`, `mesa`, `mos6`, `nbjt`,
`nbjt2`, `ndev`, `numd`, `numd2`, `numos`, `tra`, `txl`, `urc`, `vccs`, `vcvs`, `vsrc`.

Two consequences the GUI should surface:

* **`mos6` has no noise model** even though `mos1/2/3/9` do — a MOSFET-level-6 design
  will report zero device noise.
* **B-sources, VCVS/VCCS/CCCS/CCVS and transmission lines are noiseless.** A behavioural
  model built out of B-sources contributes nothing.
* A resistor can be made noiseless per instance: `RESnoisy` (`resnoise.c:57`
  `if (!inst->RESnoisy) continue;`), deck keyword `noisy`.

XSPICE detail worth knowing: `noisean.c:339-342` sets
`g_mif_info.circuit.anal_type = MIF_AC` during noise "so that MIFload generates correct AC
matrix entries needed for gain computation".

---

## 4. PZ — pole-zero

### 4.1 JOB struct and parameter table

`src/include/ngspice/pzdefs.h:21-40`:

```c
struct PZAN {
    int JOBtype; JOB *JOBnextJob; IFuid JOBname;
    int PZin_pos, PZin_neg, PZout_pos, PZout_neg;   /* equation NUMBERS, not CKTnode* */
    int PZinput_type;        /* PZ_IN_VOL=1, PZ_IN_CUR=2 */
    int PZwhich;             /* bitmask PZ_DO_POLES=0x1 | PZ_DO_ZEROS=0x2 */
    int PZnumswaps, PZbalance_col, PZsolution_col;
    PZtrial *PZpoleList, *PZzeroList;
    int PZnPoles, PZnZeros;
    double *PZdrive_pptr, *PZdrive_nptr;
};
```

`PZtrial` at `pzdefs.h:11-19`. Masks/ids at `pzdefs.h:42-57`.

**Complete `PZparms[]`** — `src/spicelib/analysis/pzsetp.c:78-88`. Note **every
description string is empty** (`""`), so a GUI cannot build tooltips from the table:

| keyword | id | dataType | description | meaning |
|---|---|---|---|---|
| `nodei` | `PZ_NODEI` | `IF_SET\|IF_ASK\|IF_NODE` | `""` | input + node → `PZin_pos = value->nValue->number` (`pzsetp.c:26`) |
| `nodeg` | `PZ_NODEG` | `IF_SET\|IF_ASK\|IF_NODE` | `""` | input − node → `PZin_neg` (`:30`) |
| `nodej` | `PZ_NODEJ` | `IF_SET\|IF_ASK\|IF_NODE` | `""` | output + node → `PZout_pos` (`:34`) |
| `nodek` | `PZ_NODEK` | `IF_SET\|IF_ASK\|IF_NODE` | `""` | output − node → `PZout_neg` (`:38`) |
| `vol` | `PZ_V` | `IF_SET\|IF_ASK\|IF_FLAG` | `""` | `PZinput_type = PZ_IN_VOL` — V_out/V_in (`:41-45`) |
| `cur` | `PZ_I` | `IF_SET\|IF_ASK\|IF_FLAG` | `""` | `PZinput_type = PZ_IN_CUR` — V_out/I_in (`:47-51`) |
| `pol` | `PZ_POL` | `IF_SET\|IF_ASK\|IF_FLAG` | `""` | `PZwhich = PZ_DO_POLES` (`:53-57`) |
| `zer` | `PZ_ZER` | `IF_SET\|IF_ASK\|IF_FLAG` | `""` | `PZwhich = PZ_DO_ZEROS` (`:59-63`) |
| `pz` | `PZ_PZ` | `IF_SET\|IF_ASK\|IF_FLAG` | `""` | `PZwhich = PZ_DO_POLES\|PZ_DO_ZEROS` (`:65-69`) |

All four node ids store only the integer equation number, so `PZaskQuest` has to map back
with `CKTnum2nod` (`src/spicelib/analysis/pzaskq.c:127-141`).

### 4.2 Card and command syntax

`src/spicelib/parser/inp2dot.c:247-281` (`dot_pz`); documented form `inp2dot.c:259` and
`src/ngspice.txt:3187-3192`:

```
.PZ NODE1 NODE2 NODE3 NODE4 { CUR | VOL } { POL | ZER | PZ }
```

`.control`: `pz node1 node2 node3 node4 {cur|vol} {pol|zer|pz}`
(`src/ngspice.txt:3215-3217`: "In interactive mode, the command syntax is the same except
that the first field is PZ instead of .PZ. To print the results, one should use the command
'print all'.")

Parse order (`inp2dot.c:266-279`): four `IF_NODE` values → `nodei`, `nodeg`, `nodej`,
`nodek`; then one token used **verbatim as a parameter keyword** for the transfer type;
then one token used verbatim for the mode. There is **no validation** of those two tokens
in `dot_pz` — a bad word reaches `INPapName`, which prints the offending word and returns
`E_BADPARM` (`inpapnam.c:28-31`).

Semantics per the help text (`src/ngspice.txt:3204-3213`):
"CUR stands for a transfer function of the type (output voltage)/(input current) while VOL
stands for a transfer function of the type (output voltage)/(input voltage). POL stands
for pole analysis only, ZER for zero analysis only and PZ for both. This feature is
provided mainly because if there is a nonconvergence in finding poles or zeros, then, at
least the other can be found. Finally, NODE1 and NODE2 are the two input nodes and NODE3
and NODE4 are the two output nodes."

**Defaults are all zero** (§1.4): omitting `{POL|ZER|PZ}` leaves `PZwhich = 0`, so
`PZan` does neither pole nor zero search (`pzan.c:67`, `:76`) and `PZpost` opens a plot
with **zero vectors**. Omitting `{CUR|VOL}` leaves `PZinput_type = 0`, which
`CKTpzSetup` treats as *not* `PZ_IN_VOL` — i.e. as the current case (`cktpzset.c:106`).

### 4.3 What `vol` vs `cur` actually changes

`CKTpzSetup(ckt, type)` (`src/spicelib/analysis/cktpzset.c:68-209`) is called twice — once
with `PZ_DO_POLES`, once with `PZ_DO_ZEROS` (`pzan.c:68`, `:77`) — and chooses the
matrix column to drive:

```c
input_pos = job->PZin_pos;  input_neg = job->PZin_neg;              /* :99-100 */
if (type == PZ_DO_ZEROS) {          /* numerator: Vo/Ii in Y */
    output_pos = job->PZout_pos;  output_neg = job->PZout_neg;      /* :102-105 */
} else if (job->PZinput_type == PZ_IN_VOL) {  /* denominator: Vi/Ii in Y */
    output_pos = job->PZin_pos;   output_neg = job->PZin_neg;       /* :106-109 */
} else {                            /* denominator for the current case */
    output_pos = output_neg = input_pos = input_neg = 0;            /* :110-116 */
}
```

then makes the driving-function matrix elements `PZdrive_pptr`/`PZdrive_nptr`
(`:127-135`) which `CKTpzLoad` stamps as `+1` / `−1` each iteration
(`src/spicelib/analysis/cktpzld.c:44-48`). `CKTpzLoad` also folds the balance column into
the solution column (`SMPcAddCol`, `:35-38`) and zeroes the solution column
(`SMPcZeroCol`, `:40-42`) — with a `/* AC sources ?? XXX */` note at `:37` flagging that
independent AC sources are not handled here.

`CKTpzSetup` calls `NIdestroy` + `NIinit` and resets `ckt->CKTnumStates = 0` with the
comment `/* Really awful . . . */` (`cktpzset.c:78-85`), then re-runs every device's
`DEVpzSetup`. So a PZ run *rebuilds the matrix twice* and the circuit's state vector
indices are reassigned — that is why PZ cannot be resumed and why it is fragile.

### 4.4 Known failure modes (all of these are what a GUI must catch)

**`option klu` refusal** (`pzan.c:29-35`):
`"Error: Pole/zero analysis is not (yet) supported with 'option KLU'.\n    Use 'option
sparse' instead."` → `E_UNSUPP`.

**`PZinit` pre-flight** (`pzan.c:92-128`):

| condition | code | message |
|---|---|---|
| any `transmission line` / `Tranline` / `LTRA` instance present | `E_XMISSIONLINE` (`sperror.h:22`) | `"transmission lines not supported by pole-zero"` (`sperror.c:78`), plus the `MERROR` text `"Transmission lines not supported"` (`pzan.c:105`) |
| `PZin_pos == PZin_neg` | `E_SHORT` (`sperror.h:24`) | `"Input is shorted"` → user sees `doAnalyses: input or output shorted` **[verified]** |
| `PZout_pos == PZout_neg` | `E_SHORT` | `"Output is shorted"` |
| input nodes == output nodes and `vol` | `E_INISOUT` (`sperror.h:25`) | `"Transfer function is unity"` → `doAnalyses: transfer function is 1` **[verified]** |
| input nodes == swapped output nodes and `vol` | `E_INISOUT` | `"Transfer function is -1"` |

**Root-finder give-ups** (`src/spicelib/analysis/cktpzstr.c`):

* iteration limit `NITER_LIM = 200` (`cktpzstr.c:43`); on exhaustion, warning
  `"Pole-zero iteration limit reached; giving up after %d trials"` (`:225-227`);
* `Aberr_Num > 2` → warning `"Pole-zero converging to numerical aberrations; giving up
  after %d trials"` (`:221-223`);
* maximum roots searched is the matrix size: `Max_Zeros = SMPmatSize(ckt->CKTmatrix)`
  (`:132`);
* loop guards on guess-interval blow-up: `High_Guess - Low_Guess < 1e40`, `< 1e35`, and
  `neighborhood[2]->s.real - neighborhood[0]->s.real < 1e22` (`:194-199`);
* `if (NZeros >= Seq_Num - 1)` → `E_SHORT` with `"The input signal is shorted on the way
  to the output"` (`:208-214`);
* `E_MAGEXCEEDED` (`sperror.h:23`, message `"magnitude overflow"`, `sperror.c:82`) exists
  for pole magnitudes too large;
* Ctrl-C → warning `"Pole-Zero analysis interrupted; %d trials, %d roots"` + `E_PAUSE`
  (`:189-193`).

**Silent degeneracies observed [verified]:**

* `pz in 0 out 0 vol zer` on a first-order RC found **no zeros**, so `PZpost` opened a
  plot with **zero vectors**; `print all` then printed the *constants* plot instead. The
  GUI must handle a legitimately empty PZ result.
* `pz in 0 out 0 cur pz` on the same RC returned `pole(1) = 0,0` — a meaningless root —
  while `vol pol` correctly returned `-1e6` (= −1/RC for 1 kΩ, 1 nF).

### 4.5 Output

`PZpost` (`pzan.c:134-207`):

* vector names are built with `sprintf(name, "pole(%-u)", i+1)` (`:151`) and
  `sprintf(name, "zero(%-u)", i+1)` (`:155`) — literally `pole(1)`, `pole(2)`, …,
  `zero(1)`, … The `%-u` is a left-justified unsigned with no width, i.e. just `%u`;
  the parentheses are part of the vector name.
* plot: `OUTpBeginPlot(ckt, curJob, JOBname /* "Pole-Zero Analysis" */, NULL, 0,
  nPoles+nZeros, namelist, IF_COMPLEX, &pzPlotPtr)` (`:159-163`) — **no reference /
  scale vector**, one data row.
* complex-conjugate expansion: for each trial root, `multiplicity` copies are emitted, and
  if `s.imag != 0` the conjugate is emitted immediately after (`:166-198`). So a
  complex pair occupies `pole(k)` and `pole(k+1)`.
* `char name[50]` with `sprintf` — bounded in practice, but the buffer is fixed.

Verified for a BJT amplifier: `pole(1) = -5.59676e+09,0`, `pole(2) = -4.85132e+07,0`,
`zero(1) = 7.410572e+09,0`, all typed `voltage, complex` **[verified]**.

Units: these are **s-plane radian frequencies** (rad/s), i.e. `s = σ + jω`. ngspice
labels them `voltage` (§1.9). A GUI showing "pole frequency in Hz" must divide by 2π
itself.

---

## 5. TF — DC small-signal transfer function

### 5.1 JOB struct and parameter table

`src/include/ngspice/tfdefs.h:17-30`:

```c
struct TFan {
    int JOBtype; JOB *JOBnextJob; IFuid JOBname;
    CKTnode *TFoutPos, *TFoutNeg;
    IFuid TFoutSrc, TFinSrc;
    char *TFoutName;                 /* printable "V(x)" / "V(x,y)" */
    unsigned TFoutIsV:1, TFoutIsI:1, TFinIsV:1, TFinIsI:1;
};
```

ids `TF_OUTPOS=1, TF_OUTNEG, TF_OUTSRC, TF_INSRC, TF_OUTNAME` (`tfdefs.h:33-39`).

**Complete `TFparms[]`** — `src/spicelib/analysis/tfsetp.c:53-59`:

| keyword | id | dataType | description | side effect in `TFsetParm` |
|---|---|---|---|---|
| `outpos` | `TF_OUTPOS` | `IF_SET\|IF_NODE` | "Positive output node" | sets `TFoutIsV=1, TFoutIsI=0` (`tfsetp.c:24-28`) |
| `outneg` | `TF_OUTNEG` | `IF_SET\|IF_NODE` | "Negative output node" | also sets `TFoutIsV=1, TFoutIsI=0` (`:29-33`) |
| `outname` | `TF_OUTNAME` | `IF_SET\|IF_STRING` | "Name of output variable" | stores the display string (`:34-36`) |
| `outsrc` | `TF_OUTSRC` | `IF_SET\|IF_INSTANCE` | "Output source" | sets `TFoutIsV=0, TFoutIsI=1` (`:37-41`) |
| `insrc` | `TF_INSRC` | `IF_SET\|IF_INSTANCE` | "Input source" | (`:42-44`) |

**No parameter has `IF_ASK`, and `TFaskQuest` unconditionally returns `E_BADPARM`**
(`src/spicelib/analysis/tfaskq.c:15-32` — its body is `NG_IGNORE`s plus
`switch(which){default: break;} return(E_BADPARM);`). TF is write-only.

Note the ordering hazard: `outpos`/`outneg` and `outsrc` clobber each other's
`TFoutIsV`/`TFoutIsI`, so the *last* one set wins. `dot_tf` never sets both.

### 5.2 Card and command syntax

`src/spicelib/parser/inp2dot.c:348-407` (`dot_tf`); documented at `inp2dot.c:361-362` and
`src/ngspice.txt:3264`:

```
.TF OUTVAR INSRC
```

with `OUTVAR` being either `v(node)` / `v(node1,node2)` or `i(vsrcname)`.
Examples from the help (`ngspice.txt:3269-3270`): `.TF V(5, 3) VIN`, `.TF I(VLOAD) VIN`.
`.control`: `tf outputnode inputsource` (`ngspice.txt:4999`).

Parse (`inp2dot.c:369-405`):

* first token must be `v` or `i` (case-insensitive `cieq`); anything else →
  `LITERR("Syntax error: voltage or current expected.")` (`:398-400`);
* `v(...)`: `outpos` from the first net token, then either `outneg` from the second net
  token with `outname = "V(<n1>,<n2>)"`, or (if the next char is `)`) `outneg = gnode`
  with `outname = "V(<n1>)"` (`:371-392`);
* `i(...)`: the next token becomes `outsrc` (`:393-397`);
* the final token becomes `insrc` (`:402-405`).

Note the `v` branch has an empty error arm — `if (*line != '(') { /* error, bad input
format */ }` (`inp2dot.c:372-374`) — so `.tf v out v1` is silently mis-parsed.

### 5.3 The three results and where they land

`TFanal` (`src/spicelib/analysis/tfanal.c:18-165`):

1. Operating point (`:44-47`) — **result discarded** (§1.6).
2. Resolve `insrc` with `CKTfndDev` (`:49`). Not found → warning
   `"Transfer function source %s not in circuit"`, clears `TFinIsV`/`TFinIsI`, returns
   `E_NOTFOUND` (`:51-58`). Wrong device class → warning
   `"Transfer function source %s not of proper type"` + `E_NOTFOUND` (`:66-71`).
   Only `Vsource` (`TFinIsV=1`) and `Isource` (`TFinIsI=1`) are accepted (`:60-65`).
3. Zero the RHS and apply a **unit excitation** (`:73-84`):
   * current input: `rhs[node0] -= 1; rhs[node1] += 1;`
   * voltage input: `insrc = CKTfndBranch(ckt, TFinSrc); rhs[insrc] += 1;`
4. `SMPsolve(CKTmatrix, CKTrhs, CKTrhsSpare)` (`:87`) — one real solve against the
   already-factored operating-point Jacobian. **There is no AC load, no omega: this is a
   DC small-signal analysis** ("The analysis assumes a small-signal DC (slowly varying)
   input", `ngspice.txt:5005-5006`).
5. Three UIDs (`:90-102`):
   * `"Transfer_function"` (no prefix) — `IFnewUid(ckt, &tfuid, NULL, "Transfer_function",
     UID_OTHER, NULL)`;
   * `"Input_impedance"` **with `job->TFinSrc` as the UID prefix**, so the vector is named
     `<insrc>#Input_impedance`;
   * output impedance: if the output is a current, `"Output_impedance"` prefixed with
     `job->TFoutSrc` → `<outsrc>#Output_impedance`; otherwise
     `tprintf("output_impedance_at_%s", job->TFoutName)` with no prefix →
     `output_impedance_at_V(out)` — **a vector name containing parentheses**.
6. Plot: `OUTpBeginPlot(..., job->JOBname /* "Transfer Function" */, NULL, 0, 3, uids,
   IF_REAL, &plotptr)` (`:104-108`) — **no scale vector, one row, three real values**.
7. Values (`:112-157`):
   * `outputs[0]` = transfer function: `rhs[outPos] - rhs[outNeg]` (voltage output) or
     `rhs[outsrc]` (current output);
   * `outputs[1]` = input impedance: for a current input,
     `rhs[node1] - rhs[node0]`; for a voltage input, `-1/rhs[insrc]`, **clamped to
     `1e20` when `|rhs[insrc]| < 1e-20`** (`:125-129`);
   * `outputs[2]` = output impedance: if `TFoutIsI && TFoutSrc == TFinSrc`, it is copied
     from `outputs[1]` and the second solve is skipped (`:132-139`); otherwise a second
     unit excitation is applied at the output and solved, giving
     `rhs[outNeg] - rhs[outPos]` (voltage output) or `1/MAX(1e-20, rhs[outsrc])`
     (current output).
8. `OUTpData` with `refval.rValue = 0` (`:159-163`).

Verified vector names **[verified]**:

```
tf i(vsense) v1  ->  Transfer_function, v1#Input_impedance, vsense#Output_impedance
tf v(out) v1     ->  Transfer_function, v1#Input_impedance, output_impedance_at_V(out)
```

and for the RC divider `tf v(out) v1` gave `Transfer_function = -1.67329e+00` (BJT amp),
`v1#Input_impedance = 6.475425e+04`, `output_impedance_at_V(col) = 9.990561e+02`
**[verified]**.

Units: transfer function is dimensionless for V/V, A/V for I/V, V/A for V/I, A/A for I/A.
Both impedances are ohms **for a voltage input**; for a *current* input `outputs[1]` is a
voltage-per-unit-current, still ohms. All three are typed `voltage` by ngspice (§1.9).

### 5.4 Batch-mode auto-print

`src/frontend/dotcards.c:274-284`: in non-terse batch mode ngspice walks the plot list and
for every plot whose typename starts with `tf` prints
`"Transfer function information:"` then `com_print(&all)`. So a `.tf` card produces
output with **no `.print` line at all**. `dotcards.c:421-424` also explicitly whitelists
`.tf` as a dot line that is not an error. Verified **[verified]**.

---

## 6. DISTO — small-signal distortion (Volterra)

### 6.1 JOB struct and parameter table

`src/include/ngspice/distodef.h:88-138`:

```c
typedef struct {
    int JOBtype; JOB *JOBnextJob; char *JOBname;
    double DstartF1, DstopF1, DfreqDelta, DsaveF1;
    int DstepType;      /* DECADE=1 OCTAVE=2 LINEAR=3  (distodef.h:142-144) */
    int DnumSteps;
    int Df2wanted;      /* set when f2overf1 was given on the card */
    int Df2given;       /* set when at least one source has a distof2 input */
    double Df2ovrF1;    /* "ratio of f2 over f1 if 2 frequencies given should be < 1" */
    double Domega1, Domega2;
    double *r1H1ptr, *i1H1ptr, *r2H11ptr, *i2H11ptr, *r3H11ptr, *i3H11ptr;
    double *r1H2ptr, *i1H2ptr, *r2H12ptr, *i2H12ptr,
           *r2H1m2ptr, *i2H1m2ptr, *r3H1m2ptr, *i3H1m2ptr;   /* Volterra transforms */
    double **r1H1stor, ... **i3H1m2stor;                      /* per-point storage */
} DISTOAN;
```

Two helper structs the device `DEVdisto` routines use: `DpassStr` (40 doubles,
`distodef.h:20-61`) and `Dderivs` (value + all 1st/2nd/3rd derivatives w.r.t. three
variables, `distodef.h:64-85`).

`CKTdisto` mode codes (`distodef.h:161-170`): `D_SETUP=1`, `D_F1=2`, `D_F2=3`,
`D_TWOF1=4`, `D_THRF1=5`, `D_F1PF2=6`, `D_F1MF2=7`, `D_2F1MF2=8`, `D_RHSF1=9`,
`D_RHSF2=10`.

Parameter ids (`distodef.h:148-155`): `D_DEC=1, D_OCT=2, D_LIN=3, D_START=4, D_STOP=5,
D_STEPS=6, D_F2OVRF1=7`.

**Complete `Dparms[]`** — `src/spicelib/analysis/dsetparm.c:72-80`:

| keyword | id | dataType | description | notes |
|---|---|---|---|---|
| `start` | `D_START` | `IF_SET\|IF_REAL` | "starting frequency" | `<= 0` → `errMsg "Frequency of 0 is invalid"` + `E_PARMVAL`, and sets `DstartF1 = 1.0` (`dsetparm.c:24-32`) |
| `stop` | `D_STOP` | `IF_SET\|IF_REAL` | "ending frequency" | same guard; again writes **`DstartF1`** on error (`:34-42`) |
| `numsteps` | `D_STEPS` | `IF_SET\|IF_INTEGER` | "number of frequencies" | `:44-46` |
| `dec` | `D_DEC` | `IF_SET\|IF_FLAG` | "step by decades" | `:48-50` |
| `oct` | `D_OCT` | `IF_SET\|IF_FLAG` | "step by octaves" | `:52-54` |
| `lin` | `D_LIN` | `IF_SET\|IF_FLAG` | "step linearly" | `:56-58` |
| `f2overf1` | `D_F2OVRF1` | `IF_SET\|IF_REAL` | "ratio of F2 to F1" | **also sets `Df2wanted = 1`** — this single flag switches the whole analysis from harmonic to intermodulation mode (`:60-63`) |

No `IF_ASK` anywhere, though `DaskQuest` implements all seven
(`src/spicelib/analysis/daskq.c:15-72`).

### 6.2 Card and command syntax

`src/spicelib/parser/inp2dot.c:146-179` (`dot_disto`), documented at `inp2dot.c:158`:

```
.DISTO { DEC | OCT | LIN } NP FSTART FSTOP <F2OVERF1>
```

`.control`: `disto (dec|oct|lin) np fstart fstop <f2overf1>`.

Parse (`inp2dot.c:165-177`): step-type token as keyword (**no validation** — unlike
`dot_ac`), `numsteps`, `start`, `stop`, then, only if anything remains on the line,
`f2overf1`. (The source comment at `:175` mislabels it `/* f1phase */`.)

### 6.3 What it computes — the two modes

**Harmonic mode** (`f2overf1` absent, `Df2wanted == 0`). Per the help
(`src/ngspice.txt:3026-3051`): "it analyses distortion in the circuit using only a single
input frequency F1, which is swept as specified by arguments of the .DISTO command exactly
as in the .AC command. Inputs at this frequency may be present at more than one input
source, and their magnitudes and phases are specified by the arguments of the DISTOF1
keyword… The analysis produces information about the A.C. values of all node voltages and
branch currents at the harmonic frequencies 2F1 and 3F1, vs. the input frequency F1 as it
is swept."

Per frequency point, `DISTOan` (`src/spicelib/analysis/distoan.c:254-495`) does:

| ω set | `CKTdisto` mode | solve | result stored in |
|---|---|---|---|
| `Domega1 = 2π·f1` (`:262-263`) | `D_RHSF1` (`:277`) | `NIdIter` (`:287`) | `r1H1ptr`/`i1H1ptr` (`:293-294`) |
| `CKTomega *= 2` (`:296`) | `D_TWOF1` (`:302`) | `NIdIter` (`:308`) | `r2H11ptr`/`i2H11ptr` (`:310-311`) |
| `CKTomega = 3*Domega1` (`:317`) | `D_THRF1` (`:323`) | `NIdIter` (`:329`) | `r3H11ptr`/`i3H11ptr` (`:331-332`) |

Result: **two plots**, `"DISTORTION - 2nd harmonic"` (`:517`) and
`"DISTORTION - 3rd harmonic"` (`:541`).

**Intermodulation / spectral mode** (`f2overf1` given). Help
(`ngspice.txt:3053-3065`): "it should be a real number between (and not equal to) 0.0 and
1.0; in this case, .DISTO does a spectral analysis. It considers the circuit with
sinusoidal inputs at two different frequencies F1 and F2. F1 is swept according to the
.DISTO control line options exactly as in the .AC control line. F2 is kept fixed at a
single frequency as F1 sweeps - the value at which it is kept fixed is equal to F2OVERF1
times FSTART."

Source confirms F2 is **fixed**: `distoan.c:138-144`

```c
if (job->Df2wanted) {
    /* keeping f2 const to be compatible with spectre */
    job->Domega2 = 2.0 * M_PI * freq * job->Df2ovrF1;   /* freq == DstartF1 here */
}
```

with the swept alternative (`omegadelta`) commented out at `:139-141` and `:341-343`.
**`Df2ovrF1` is not range-checked anywhere** — the "strictly between 0 and 1" rule is
documentation only.

Per frequency point in this mode:

| ω set | mode | stored in |
|---|---|---|
| `Domega1` | `D_RHSF1` | `r1H1ptr` |
| `2·Domega1` | `D_TWOF1` | `r2H11ptr` |
| `Domega2` (`:344`) | `D_RHSF2` (`:350`) | `r1H2ptr` (`:358-359`) |
| `Domega1 + Domega2` (`:362`) | `D_F1PF2` (`:369`) | `r2H12ptr` (`:377-378`) |
| `Domega1 − Domega2` (`:382`) | `D_F1MF2` (`:389`) | `r2H1m2ptr` (`:397-398`) |
| `2·Domega1 − Domega2` (`:401`) | `D_2F1MF2` (`:408`) | `r3H1m2ptr` (`:416-417`) |

Result: **three plots**, `"DISTORTION - IM: f1+f2"` (`:564`),
`"DISTORTION - IM: f1-f2"` (`:585`), `"DISTORTION - IM: 2f1-f2"` (`:607`).

Verified plot counts and titles for both modes **[verified]**.

### 6.4 How the input excitations are specified

`CKTdisto` modes `D_RHSF1` / `D_RHSF2` (`src/spicelib/analysis/cktdisto.c:65-166`) walk
every `Vsource` and `Isource` looking for `distof1` / `distof2` data:

```
VSRC: distof1 -> VSRCdF1given, VSRCdF1mag, VSRCdF1phase   (cktdisto.c:100-106)
      distof2 -> VSRCdF2given, VSRCdF2mag, VSRCdF2phase   (cktdisto.c:107-111)
ISRC: analogous ISRCdF1*/ISRCdF2*                          (cktdisto.c:136-147)
```

and stamp `rhs = 0.5*mag*cos(pi*phase/180)`, `irhs = 0.5*mag*sin(pi*phase/180)`
(`cktdisto.c:115-116`; the ISRC arm at `:151-158` uses ±0.5 on the two nodes). Note the
factor **0.5** — hence `DkerProc`'s compensating multipliers below. **Phase is degrees.**

Deck syntax (VSRC parameter table, `src/spicelib/devices/vsrc/vsrc.c:50-51`):

```
IP ("distof1", VSRC_D_F1, IF_REALVEC, "f1 input for distortion")
IP ("distof2", VSRC_D_F2, IF_REALVEC, "f2 input for distortion")
```

i.e. `Vxx n+ n- ... DISTOF1 <mag> <phase> DISTOF2 <mag> <phase>`. `IP` = input-only,
"unquestionable" — the GUI cannot read them back with `show`.

`D_RHSF1` clears `Df2given` first, then any source carrying a `distof2` sets it
(`cktdisto.c:67`, `:101`, `:137`).

**Error path:** if `Df2wanted` is set but `Df2given` is not, `DISTOan` fails with
`errMsg = "No source with f2 distortion input"` and `E_NOF2SRC`
(`distoan.c:50`, `:421-425`; code `E_PRIVATE+15` at `sperror.h:30`, message
`"no F2 source for IM disto analysis"` at `sperror.c:106-108`). Verified: user sees
`doAnalyses: No source with f2 distortion input` **[verified]**.

**Silent-garbage path:** if **no** source has any `distof*` at all and `f2overf1` is not
given, DISTO runs to completion and produces meaningless (zero) plots with **no warning**
**[verified]**. The GUI must require at least one `distof1` source.

### 6.5 Point counting, and the LINEAR difference from AC

`distoan.c:63-89`:

```
DECADE: DfreqDelta = exp(log(10)/N);  freqTol = DfreqDelta*DstopF1*reltol
        NoOfPoints = 1 + floor(N/log(10) * log((DstopF1+freqTol)/DstartF1))     (:70)
OCTAVE: DfreqDelta = exp(log(2)/N);   same freqTol
        NoOfPoints = 1 + floor(N/log(2) * log((DstopF1+freqTol)/DstartF1))      (:77)
LINEAR: DfreqDelta = (DstopF1 - DstartF1)/(DnumSteps + 1)                       (:80-83)
        freqTol    = DfreqDelta*reltol
        NoOfPoints = DnumSteps + 1 + floor(freqTol/DfreqDelta)                  (:85)
default: E_BADPARM                                                              (:87-88)
```

**Note `LINEAR` uses `/(N+1)`** whereas AC uses `/(N−1)` (`acan.c:105-108`). For the same
`lin N fstart fstop` card, DISTO and AC put points at *different* frequencies. Sweep loop
at `:254`, `:482-494` (same `*=` / `+=` structure as AC, with the same
`DfreqDelta==1`/`==0` `goto endsweep` escapes).

Verified `disto dec 2 1k 100k` → 5 rows **[verified]**, matching `1+floor(2*2)`.

Also: **no `DstartF1 <= 0` check at analysis time** (unlike AC's `acan.c:78-81`) — the
`D_START` setter's guard is the only protection, and `NoOfPoints` would take `log(0)` if
it were bypassed.

### 6.6 Output scaling and plot contents

`DkerProc` (`src/spicelib/analysis/dkerproc.c:13-96`) converts Volterra kernels to
sinusoid amplitudes by multiplying both real and imaginary parts by a fixed factor:

| mode | factor | line |
|---|---|---|
| `D_F1` | 2.0 | `:26-27` |
| `D_F2` | 2.0 | `:37-38` |
| `D_TWOF1` | 2.0 | `:48-49` |
| `D_THRF1` | 2.0 | `:59-60` |
| `D_F1PF2` | 4.0 | `:70-71` |
| `D_F1MF2` | 4.0 | `:81-82` |
| `D_2F1MF2` | 6.0 | `:91-92` |
| other | `E_BADPARM` | `:95` |

Vector names in every DISTO plot are the **full `CKTnames()` list** — the same node and
`#branch` names as AC (`distoan.c:512-513`, `:534-535`, etc.), dumped through
`CKTacDump` with `ckt->CKTrhsOld[0]` (which the code stuffed with the frequency at
`:454`-ish) as the scale. Reference vector is `frequency` (`IFnewUid` at `:515`, `:539`,
`:562`, `:583`, `:605`). Data type `IF_COMPLEX`.

Verified for a BJT amp **[verified]**: every DISTO plot carried
`base, col, frequency, in, v1#branch, vcc, vcc#branch`, all complex.

**Log-grid asymmetry (defect):** `OUTattributes(acPlot, NULL, OUT_SCALE_LOG, NULL)` is
called **only** for the 2nd-harmonic plot (`distoan.c:519-521`). The 3rd-harmonic plot and
all three IM plots get no log grid even for a `dec` sweep. Verified: `disto1` shows
`grid = xlog`, `disto2` does not **[verified]**. A GUI that plots these should set the log
axis itself.

**Ctrl-C is ignored** — `distoan.c:256-261` has the `IFpauseTest()` block commented out.

### 6.7 Which devices support DISTO

`CKTdisto` iterates `DEVices[i]->DEVdisto` (`src/spicelib/analysis/cktdisto.c:36-41`,
`:57-62`). Non-NULL in this tree: **`bjt` (`BJTdisto`), `bsim1` (`B1disto`), `dio`
(`DIOdisto`), `jfet` (`JFETdisto`), `mes` (`MESdisto`), `mos1`, `mos2`, `mos3`, `mos9`,
`vdmos`** — and nothing else. Notably absent: **BSIM3, BSIM4, HiSIM, VBIC, HICUM, OSDI,
XSPICE code models, BJT-level>1**. So DISTO is only usable on old-generation models. The
GUI should grey it out (or warn loudly) when the netlist's active devices are not in that
list. Anchors: the `DEVdisto = <fn>` assignment in each `src/spicelib/devices/<dev>/*init.c`.

### 6.8 Relationship to `.four` / Fourier

They are unrelated computations and the GUI should not conflate them.

* `.disto` is a **small-signal, frequency-domain Volterra-series** analysis at 2F1/3F1 or
  the IM products. It gives the harmonic/IM *amplitudes* of the linearised circuit, and
  the help stresses these "are not equal to HD2 and HD3. To obtain HD2 and HD3, one must
  divide by the corresponding A.C. values at F1, obtained from an .AC line. This division
  can be done using nutmeg commands." (`src/ngspice.txt:3047-3051`) — i.e. the GUI must do
  `mag(disto_vec)/mag(ac_vec)` across two plots to get HD figures.
* `.four` is a **large-signal, post-transient DFT**. The netlist parser *rejects* it:
  `inp2dot.c:879-884` → `LITERR("Use fourier command to obtain fourier analysis")`. But
  the frontend intercepts `.four` lines before pass 2 (`src/frontend/inp.c:820`) and
  handles them itself in batch mode: `src/frontend/dotcards.c:407-421` does
  `plot_cur = setcplot("tran"); err = fourier(command->wl_next, plot_cur);` and on failure
  prints `"No transient data available for fourier analysis"`. Verified: a deck with
  `.tran 1u 5m` + `.four 1k v(out)` prints a full harmonic table with THD **[verified]**.
  So `.four` **does** work in batch, on transient data only.
* The interactive equivalents are the `fourier` and `spec` commands
  (`src/frontend/commands.c`; `spec.c`, `com_fft.c`), which also require a `tran` plot.

---

## 7. SENS — DC and AC sensitivity

### 7.1 JOB struct and parameter table

`src/include/ngspice/sensdefs.h:19-40`:

```c
struct st_sens {
    int JOBtype; JOB *JOBnextJob; char *JOBname;
    DevSenList *first;                    /* unused in this implementation */
    double start_freq, stop_freq;
    int step_type;                        /* SENS_DC / SENS_DECADE / SENS_OCTAVE / SENS_LINEAR */
    int n_freq_steps;
    CKTnode *output_pos, *output_neg;
    IFuid output_src;
    char *output_name;
    int output_volt;                      /* 1 = voltage output, 0 = current output */
    double deftol, defperturb;            /* DEAD - see below */
    unsigned int pct_flag :1;             /* DEAD - never read */
};
```

Parameter ids: `SENS_POS=2, SENS_NEG, SENS_SRC, SENS_NAME` (`sensdefs.h:74-79`);
`SENS_START=10, SENS_STOP, SENS_STEPS, SENS_DECADE, SENS_OCTAVE, SENS_LINEAR, SENS_DC,
SENS_DEFTOL, SENS_DEFPERTURB, SENS_DEVDEFTOL, SENS_DEVDEFPERT, SENS_TYPE, SENS_DEVICE`
(`sensdefs.h:81-95`); `SENS_PARAM=24, SENS_TOL, SENS_PERT` (`:97-101`).
So `SENS_DC == 16` and `SENS_LINEAR == 15` — remember those two numbers, they matter in
§7.6.

**Complete `SENSparms[]`** — `src/spicelib/analysis/senssetp.c:87-104`:

| keyword | id | dataType | description | side effects in `SENSsetParam` |
|---|---|---|---|---|
| `outpos` | `SENS_POS` | `IF_SET\|IF_ASK\|IF_NODE` | "output positive node" | **also sets `output_neg = NULL`, `output_volt = 1`, `step_type = SENS_DC`** (`senssetp.c:23-28`) |
| `outneg` | `SENS_NEG` | `IF_SET\|IF_ASK\|IF_NODE` | "output negative node" | only `output_neg` (`:30-32`) |
| `outsrc` | `SENS_SRC` | `IF_SET\|IF_ASK\|IF_INSTANCE` | "output current" | **also `output_volt = 0`, `step_type = SENS_DC`** (`:34-38`) |
| `outname` | `SENS_NAME` | `IF_SET\|IF_ASK\|IF_STRING` | "Name of output variable" | (`:40-42`) |
| `start` | `SENS_START` | `IF_SET\|IF_ASK\|IF_REAL` | "starting frequency" | no validation at all (`:44-46`) |
| `stop` | `SENS_STOP` | `IF_SET\|IF_ASK\|IF_REAL` | "ending frequency" | no validation (`:48-50`) |
| `numsteps` | `SENS_STEPS` | `IF_SET\|IF_ASK\|IF_INTEGER` | "number of frequencies" | (`:52-54`) |
| `dec` | `SENS_DECADE` | `IF_SET\|IF_FLAG` | "step by decades" | (`:56-58`) |
| `oct` | `SENS_OCTAVE` | `IF_SET\|IF_FLAG` | "step by octaves" | (`:60-62`) |
| `lin` | `SENS_LINEAR` | `IF_SET\|IF_FLAG` | "step linearly" | (`:64-66`) |
| `dc` | `SENS_DC` | `IF_SET\|IF_FLAG` | "analysis at DC" | (`:68-70`) |

The `outpos`/`outsrc` side effect of forcing `step_type = SENS_DC` is why the card grammar
puts the output first and the `ac …` clause last: the output setter resets the mode, then
the mode flag overrides it. **Order matters and the GUI must emit output before mode.**

**Dead parameters.** `SENSsetParam` handles `SENS_DEFTOL` (`senssetp.c:72-74`) and
`SENS_DEFPERTURB` (`:76-78`), and `SENSask` answers them (`sensaskq.c:161-167`), **but
neither has an entry in `SENSparms[]`**, so no keyword reaches them; and
`job->deftol` / `job->defperturb` are **never read** by `sens_sens` — the perturbation is
two file-static constants:

```c
static double Sens_Delta     = 0.000001;   /* cktsens.c:24 */
static double Sens_Abs_Delta = 0.000001;   /* cktsens.c:25 */
```

used at `cktsens.c:570-573`:
`delta_var = (sg->value != 0.0) ? sg->value * Sens_Delta : Sens_Abs_Delta;`.
**The perturbation size is hard-coded at 1e-6 relative / 1e-6 absolute and cannot be
changed from a deck, a command, or an option.** Similarly `pct_flag` (which would switch
to percentage sensitivities) is never read, and `SENS_DEVDEFTOL`, `SENS_DEVDEFPERT`,
`SENS_TYPE`, `SENS_DEVICE`, `SENS_PARAM`, `SENS_TOL`, `SENS_PERT` and the whole
`DevSenList`/`ModSenList`/`ParamSenList` machinery (`sensdefs.h:51-67`) are declared but
unimplemented. If the GUI wants "sensitivity of X to *these* parameters with *this*
perturbation", only the *filter* half exists (§7.3).

`SENSinfo` uses `sens_sens` as `an_func` (`senssetp.c:119`), whose prototype is at
`sensdefs.h:72`.

### 7.2 Card and command syntax — including the filter feature

`src/spicelib/parser/inp2dot.c:460-585` (`dot_sens`). The source comment
(`inp2dot.c:487-490`) documents the **current** grammar, which is wider than the built-in
help:

```
.sens <output> [<filter strings>]
+ [ ac [dec|lin|oct] <pts> <low freq> <high freq> | dc ]
```

`.control`: `sens <output> [filters] [ac (dec|oct|lin) N fstart fstop | dc]`.

The help text (`src/ngspice.txt:3226-3231`, `:4701-4703`) only documents

```
.SENS OUTVAR
.SENS OUTVAR AC { DEC | OCT | LIN } N FSTART FSTOP
```

and says nothing about filters. That is a **doc gap**, not a conflict — the filter
feature was added by commit `abc3fceb7` ("Enhance sensitivity analysis with an option to
choose the parameters to be varied. Shell-style wildcards (\"*?\") are supported."). Trust
the source.

Parse steps:

1. First token must be `v` or `i` (`cieq`), else
   `LITERR("Syntax error: voltage or current expected.")` (`inp2dot.c:495`, `:519`,
   `:524-526`).
2. `v(n1)` → `outpos` = n1, `outneg` = ground, `outname = "V(n1)"`;
   `v(n1,n2)` → `outpos`, `outneg`, `outname = "V(n1,n2)"` (`:495-518`). A missing `(`
   after `v` is a hard error here (unlike `.tf`): `LITERR("Syntax error: '(' expected
   after 'v'")` (`:496-499`).
3. `i(vsrc)` → `outsrc` (`:519-523`).
4. **Filters** (`:529-565`): every remaining whitespace-delimited token, up to (but not
   including) the token `ac` or `dc`, is pushed onto the global
   `char **Sens_filter` (declared `src/spicelib/analysis/cktsens.c:33`, `extern`'d at
   `inp2dot.c:477`). `INPgetTok` is bypassed "because INPgetTok() breaks on '*'"
   (`:530-531`). The previous list is `FREE`d each time (`:533-534`) — note this frees the
   array but **leaks the strings**, and `Sens_filter` is process-global, so it persists
   across circuits.
5. `ac` → step-type token as a keyword, then `numsteps`, `start`, `stop`
   (`:567-577`). `dc` or nothing → DC mode. Any other word →
   `LITERR("Syntax error: 'ac' or 'dc' expected.")` (`:578-581`).

### 7.3 Which parameters are eligible

`sens_sens` enumerates candidates with the `sgen` iterator
(`src/spicelib/analysis/cktsgen.c:17-216`), which walks device types → models →
instances → **model parameter table, then instance parameter table**
(`cktsgen.c:64-71`, `:97-106`, `:129-138`). The eligibility test is
`set_param()` (`cktsgen.c:193-216`):

```c
if (!sg->ptable[sg->param].keyword) return 0;
if ((dataType & (IF_SET|IF_ASK|IF_REAL|IF_VECTOR|IF_REDUNDANT|IF_NONSENSE))
        != (IF_SET|IF_ASK|IF_REAL))
    return 0;                                   /* cktsgen.c:199-202 */
if (sg->is_dc && (dataType & (IF_AC | IF_AC_ONLY)))
    return 0;                                   /* cktsgen.c:203-205 */
if (sens_getp(sg, sg->ckt, &ifval)) return 0;   /* cktsgen.c:207 */
if (dataType & IF_PRINCIPAL) sg->is_principle += 1;
sg->value = ifval.rValue;
```

So a parameter is eligible **iff** it is exactly `IF_SET|IF_ASK|IF_REAL` — a scalar real
that is both settable and queryable — and is not `IF_VECTOR`, `IF_REDUNDANT` or
`IF_NONSENSE`, and (in DC mode) not `IF_AC`/`IF_AC_ONLY`, and the device's `ask` routine
actually returns a value for this instance.

> **Doc/source divergence.** `src/ngspice.txt:3243-3244` says "The sensitivity of OUTVAR
> to all **non-zero** device parameters is calculated". The source does **not** filter on
> value: a zero-valued parameter is perturbed by the absolute delta
> (`cktsens.c:572-573`). Verified: `d1:af`, `c1:cap`, `r1:tc1` etc. all appear with 0.0
> sensitivity **[verified]**. Trust the source.

### 7.4 Output vector naming

`cktsens.c:222-249`:

```c
if (!sg->is_instparam)                                   /* MODEL parameter */
    snprintf(namebuf, ..., "%s:%s", instance->GENname, ptable[param].keyword);
else if ((ptable[param].dataType & IF_PRINCIPAL) && sg->is_principle == 1)
    snprintf(namebuf, ..., "%s", instance->GENname);      /* the principal one */
else
    snprintf(namebuf, ..., "%s_%s", instance->GENname, ptable[param].keyword);
```

i.e.

| kind | vector name | example |
|---|---|---|
| model parameter | `<instance>:<param>` | `r1:tc1`, `d1:is`, `c1:cap` |
| instance parameter flagged `IF_PRINCIPAL` (and the first such) | `<instance>` | `r1`, `r2`, `v1`, `c1` |
| any other instance parameter | `<instance>_<param>` | `r1_temp`, `d1_area`, `v1_z0` |

Note the **model** parameter uses a colon and the **instance** parameter an underscore.
`namebuf` is `char[513]` (`cktsens.c:223`).

Verified for `sens v(out) dc` on a deck with `r1`, `r2`, `d1`, `v1` **[verified]** — the
plot contained, among ~90 vectors: `r1`, `r1:af r1:bv_max r1:ef r1:kf r1:lf r1:narrow
r1:r r1:rsh r1:short r1:tc1 r1:tc2 r1:tce r1:wf`, `r1_bv_max r1_dtemp r1_l r1_m r1_scale
r1_tc r1_tc2 r1_tce r1_temp r1_w`, the same for `r2`, `d1:<41 model params>` and
`d1_area d1_dtemp d1_l d1_lm d1_lp d1_m d1_pj d1_temp d1_w d1_wm d1_wp`, plus `v1`,
`v1_freq v1_phase v1_pwr v1_z0` (the last four are RFSPICE port params — they only exist
because this tree has `RFSPICE` on).

**A three-device deck yields ~90 sensitivity vectors.** A GUI must offer filtering by
default, not show the raw list.

### 7.5 The filter (glob) syntax

`cktsens.c:37-56` `scan(filter, name)` implements a tiny glob:

* `*` matches any run of characters; a **trailing** `*` matches everything remaining
  (`:41-42`);
* `?` matches exactly one character (`:47`);
* everything else must match byte-for-byte — **the match is case-sensitive** and the names
  it matches are already case-folded by the parser, so filters should be written
  lowercase;
* a match requires both strings exhausted (`:53-55`).

`check_filter` (`:58-67`) returns true if *any* filter matches. `cktsens.c:243`:
`if (!Sens_filter || check_filter(namebuf))` — no filters means everything.

Filtered-out entries leave a `NULL` hole in `output_names`, which is then compacted into a
dense `vec_names` array for `OUTpBeginPlot` (`cktsens.c:250-265`), and the *same* holes
are skipped again in the compute loop (`cktsens.c:454-455`
`if (!output_names[k++]) continue;`). So filtering genuinely saves compute time, not just
output.

Example: `sens v(out) r1:r r2:r m*:vth0 ac dec 10 1k 1meg`.

### 7.6 DC vs AC mode, and a real stepping bug

`cktsens.c:166-172`:

```c
is_dc  = (job->step_type == SENS_DC);
nfreqs = count_steps(job->step_type, job->start_freq, job->stop_freq,
                     job->n_freq_steps, &step_size);
if (!is_dc) freq = job->start_freq;
```

`count_steps` (`cktsens.c:862-906`):

```
steps < 1                 -> steps = 1
SENS_DC (and default):    n = 0, s = 0                 -> n forced to 1 at the end
SENS_LINEAR:              n = steps,  s = (high-low)/steps
SENS_DECADE:  low<=0 -> low=1e-3 ; high<=low -> high=10*low
                          n = (int)(steps*log10(high/low) + 1.01),  s = 10^(1/steps)
SENS_OCTAVE:  low<=0 -> low=1e-3 ; high<=low -> high=2*low
                          n = (int)(steps*log(high/low)/M_LOG2E + 1.01), s = 2^(1/steps)
n <= 0 -> n = 1
```

Note the silent `low = 1e-3` and `high = 10*low` / `2*low` fix-ups — another place where
bad input is quietly rewritten.

**DC mode** (`is_dc`): `nfreqs == 1`, `freq == 0.0`, `type = IF_REAL`, **no reference
vector** (`freq_name = NULL`, `cktsens.c:266-269`), one row of real numbers.
`start`/`stop`/`numsteps` are ignored.

**AC mode**: `type = IF_COMPLEX`, reference vector `frequency`
(`cktsens.c:271-275`), `nfreqs` rows, and log grid unless `SENS_LINEAR`
(`cktsens.c:296-297`).

> ### DEFECT: `sens … ac lin` produces a *geometric* sweep
>
> `cktsens.c:783` advances the sweep with `freq = inc_freq(freq, job->step_type,
> step_size);`, and `inc_freq` (`cktsens.c:828-837`) is
>
> ```c
> if (type != LINEAR) freq *= step_size; else freq += step_size;
> ```
>
> `LINEAR` here is **not** `SENS_LINEAR`. `cktsens.c` never defines `LINEAR`, but its
> include chain pulls in the `#define LINEAR 3` from `noisedef.h:127` / `distodef.h:144`.
> Preprocessing confirms it: `gcc -E` renders the line as `if (type != 3)`
> (`inc_freq` at `cktsens.c:831`). Since `SENS_LINEAR == 15`, `SENS_DECADE == 13`,
> `SENS_OCTAVE == 14` and `SENS_DC == 16`, the test is **always true** and every SENS AC
> sweep multiplies by `step_size` — including the linear one, whose `step_size` is
> `(high-low)/steps`, a *frequency*, not a ratio.
>
> Verified: `sens v(out) ac lin 5 1k 5k` swept
> **1e3, 8e5, 6.4e8, 5.12e11, 4.096e14 Hz** (each × 800) **[verified]**.
> `dec`/`oct` are unaffected because `step_size` is a ratio for them.
>
> **GUI consequence: do not offer `lin` for SENS AC** until this is fixed upstream; offer
> `dec`/`oct` only, or synthesise a linear sweep with a Tcl loop of single-point runs.

### 7.7 The algorithm (adjoint/perturbation), and why it is slow and fragile

Documented in the header comment `cktsens.c:80-92`:

```
Determine operating point (call CKTop)
For each frequency point:
    (for AC) call NIacIter to get base node voltages
    For each element/parameter in the test list:
        construct the perturbation matrix
        Solve for the sensitivities:  delta_E = Y^-1 (delta_Y E - delta_I)
        save results
```

Per frequency point (`cktsens.c:357-785`):

* `ckt->CKTbypass` is forced to 0 for the whole analysis (`:317-318`, restored `:809`);
* if `freq != 0`: `CKTomega = 2πf`, then **`CKTunsetup` + `CKTsetup` + `CKTtemp` +
  `CKTload` — the entire circuit is torn down and rebuilt at every frequency**
  (`:373-401`, with the comment `/* Yes, all this has to be re-done */`), then `NIacIter`
  (`:421`);
* the circuit's RHS/matrix pointers are swapped to the scratch `delta_Y`/`delta_I`
  (`:440-446`) so each device's own `DEVsetup`/load routines can be reused to build the
  perturbation matrix (`:490-499`) — with a hard `controlled_exit(EXIT_FAILURE)` guard if
  a `DEVsetup` allocates a node: `"Internal Error: node allocation in DEVsetup() during
  sensitivity analysis, this will cause serious troubles !, please report this issue !"`
  (`:496-497`);
* the parameter is perturbed by `delta_var`, re-loaded, and the difference is formed by
  negating and re-accumulating (`:547-617`);
* `SMPmultiply(delta_Y, ..., E, ..., iE)` then `delta_I -= delta_Y·E` then
  `SMPcSolve(Y, delta_I, delta_iI, NULL, NULL)` reusing the already-factored `Y`
  (`:648-695`);
* the result is divided by `delta_var` (`:745`, `:764-765`), so the output units are
  **∂(output)/∂(parameter)** in absolute terms.

`src/ngspice.txt:3251-3253`: "The output values are in dimensions of change in output per
unit change of input (as opposed to percent change in output or per percent change of
input)." Confirmed by the code.

Cost model for the GUI: `nfreqs × num_vars` full device loads + one complex solve each,
plus `nfreqs` full circuit rebuilds. A 3-device deck already has ~90 parameters; a real
analog block will have thousands. **Filtering is mandatory for interactive use.**

Robustness notes:
* the KLU guard is **commented out** (`cktsens.c:97-105`), so `option klu` + `sens` takes
  the KLU code paths (`:327-340`, `:403-418`, `:501-523`) which carry a `FIXME` about
  `SMPkluMatrix` being NULL (`:196-198`);
* `if (!num_vars) return OK; /* XXXX Should be E_ something */` (`:216-217`) — a filter
  that matches nothing exits silently with no plot;
* commits `ca7c6cce7` ("Avoid crash, when sensitivity analysis is called") and `c1effe3b3`
  ("Just a hack to avoid a crash during sensitivity analysis: Exclude parameter RCO from
  sens code…") indicate a history of instability; the BJT `rco` exclusion is the reason
  some parameters carry `IF_NONSENSE`.

### 7.8 What `sens` in `.control` does that the card does not

**Nothing.** Both go through the same `dot_sens`, via `if_run`'s synthetic `.sens …` card
(§1.5). Specifically:

* `if_run` lists `sens` among the interactive analyses (`src/frontend/spiceif.c:264`,
  `:398`) and routes it through `INPpas2`;
* the only `sens`-specific special case in `dosim` is for the string `"sens2"`, not
  `"sens"` (`src/frontend/runcoms.c:330-338`, guarded by the comment
  `/* "sens2" not used in ngspice */`), which calls `if_sens_run`.

The practical differences are the generic ones: an interactive `sens` runs immediately and
alone (so §1.2's reordering does not bite), you can inspect and post-process the plot in
the same `.control` block, and you can re-issue it with different filters without
re-parsing the netlist. The **filter arguments** are available in both forms.

---

## 8. SENS2 — present in name only, unreachable in every buildable configuration

`--enable-sense2` exists (`configure.ac:233-234`, help string "Use spice2 sensitivity
analysis.") and sets an Automake conditional `SENSE2_WANTED` (`configure.ac:1236`). But:

* `configure.ac` contains **no `AC_DEFINE([WANT_SENSE2], …)`** — grep finds only the
  comment at `configure.ac:232`;
* `src/include/ngspice/config.h.in` has **no `WANT_SENSE2` key** at all, so `config.h`
  can never define it (only the MSVC tree has a stub: `visualc/src/include/ngspice/config.h:543`
  `/* #undef WANT_SENSE2 */`);
* `SENSE2_WANTED` is referenced by **no `Makefile.am`**;
* `analysis.c:33` declares `extern SPICEanalysis SEN2info;` and `:51` lists it, but
  **`SEN2info` is defined nowhere in `src/`** — so even if `WANT_SENSE2` were defined the
  link would fail;
* the only surviving artefacts are `src/include/ngspice/sen2defs.h`, the `.sens2` parser
  `dot_sens2` (`src/spicelib/parser/inp2dot.c:588-651`, `#ifdef WANT_SENSE2`), its
  dispatch arm (`inp2dot.c:940-945`), the `if_sens_run` call in `dosim`
  (`src/frontend/runcoms.c:331`), and ~20 `#ifdef WANT_SENSE2` blocks in the analyses
  (`acan.c:315`, `dctran.c:86` etc.).

For the record, the vestigial `.sens2` grammar was
`.sens {AC} {DC} {TRAN} [dev=nnn parm=nnn]*` (`inp2dot.c:601`), driven generically through
`ft_find_analysis_parm` (`:617`).

**GUI decision: do not expose SENS2. Treat SENS as the only sensitivity analysis.**

---

## 9. Adjacent, and out of scope here: `.sp` (RFSPICE)

`RFSPICE` is **on** in this tree, so `analInfo[]` also carries `SPinfo`
(`analysis.c:53-54`). Its parameter table
(`src/spicelib/analysis/spsetp.c:91-99`) is AC's plus one flag:

```
start stop numsteps dec oct lin        (same ids/semantics as AC)
donoise   SP_DONOISE  IF_SET|IF_FLAG|IF_INTEGER  "do SP noise"
```

`SPICEanalysis SPinfo` = name `"SP"`, description `"S-Parameters analysis"`,
`FREQUENCYDOMAIN`, `do_ic = 1`, `an_func = SPan` (`spsetp.c:101-116`).
Card: `.sp` (`inp2dot.c:718-753`, `:912-917`); command `sp` (`commands.c:334`,
`runcoms.c:196-203`). It shares the noise machinery through
`src/spicelib/analysis/cktspnoise.c` and the `#ifdef RFSPICE` branches of
`nevalsrc.c` / `osdinoise.c`, and produces `S_*`, `Y_*`, `Z_*`, `NF`, `NFmin`, `Rn`,
`SOpt`, `Cy_*` vectors typed by the SP arms of `guess_type`
(`src/frontend/outitf.c:1049-1065`). It is a separate area — flagged here only so the GUI
author knows it exists in the same table and would appear in any generic
`spice_analysis_ptr()` enumeration.

`WITH_HB` (`.hb`, harmonic balance) is guarded inside `RFSPICE` (`analysis.c:22-24`,
`inp2dot.c:918-924`) and is **not** enabled here.

---

## 10. Defect and trap register (my findings, for the plan's risk section)

Ordered roughly by how much a GUI is likely to trip over them.

| # | severity | where | what |
|---|---|---|---|
| 1 | high | `acan.c` / `inp2dot.c:230-237` | `.ac` with `fstop < fstart` silently rewrites `fstop = 1000*fstart`; `numsteps < 1` silently becomes 10. Only a stderr "Warning, ngspice assumes default parameter(s)" **[verified]** |
| 2 | high | none — absence of a check | AC with no AC-valued source returns all zeros with **no diagnostic** **[verified]** |
| 3 | high | `cktsens.c:831` | `sens … ac lin` is a geometric sweep because `inc_freq` tests against `LINEAR`(=3) instead of `SENS_LINEAR`(=15) **[verified: 1k → 800k → 640M → 512G → 410T]** |
| 4 | high | `outitf.c:479-486` + `noisean.c:532` | a narrowed `save`/`.print` list silently deletes the Integrated-Noise plot and reports `"analysis not run"` **[verified]** |
| 5 | high | `noisean.c:511` | no Integrated-Noise plot at all when `fstart == fstop`, so "spot noise" runs have no `*_total` vectors **[verified]** |
| 6 | high | `distoan.c` (absence of a check) | DISTO with no `distof1` source runs and emits zero-valued plots with no warning **[verified]** |
| 7 | high | device tables | DISTO is implemented for only 10 legacy devices (`bjt bsim1 dio jfet mes mos1 mos2 mos3 mos9 vdmos`); BSIM3/4, HiSIM, VBIC, HICUM, OSDI, XSPICE have no `DEVdisto` |
| 8 | medium | `vectors.c:1104-1111` | plot names use a single global counter — the first plot of a run is not `<type>1` **[verified: `tf2`, `pz2`]** |
| 9 | medium | `cktdojob.c:176-213` + `cktnewan.c:34-35` | jobs run in JOBtype order, and same-type jobs run in reverse deck order **[verified]** |
| 10 | medium | `tfanal.c:31,44` | TF ignores `CKTop`'s return value (`gcc`: "variable 'converged' set but not used") — an unconverged OP yields silent garbage |
| 11 | medium | `src/ngspice.txt:3149-3155` | built-in help claims noise output is in squared units; the default is RMS/√Hz unless `set sqrnoise` **[verified]**. Stale SPICE3 text |
| 12 | medium | `senssetp.c:72-78` + `cktsens.c:24-25` | `deftol`/`defperturb`/`pct_flag` are dead; perturbation is hard-coded 1e-6 |
| 13 | medium | `distoan.c:519-521` | only the 2nd-harmonic DISTO plot gets `OUT_SCALE_LOG`; 3rd-harmonic and all three IM plots do not **[verified]** |
| 14 | medium | `distoan.c:256-261` | DISTO's Ctrl-C pause test is commented out — long sweeps are uninterruptible |
| 15 | medium | `guess_type`, `outitf.c:1023-1083` | `SV_POLE`/`SV_ZERO` are never assigned; poles, zeros, TF impedances and all SENS vectors are typed `voltage` **[verified]** |
| 16 | medium | `noisean.c` + device `*noise.c` | per-generator breakdown vectors require `ptspersum != 0`, which *also* decimates the spectrum. `ptspersum = 1` is the only "full breakdown, full spectrum" setting |
| 17 | medium | `b4noi.c:145` vs `resnoise.c:73` | two noise-name conventions: `onoise_r1_thermal` (underscore) vs `onoise.m1.rd` (dot, BSIM/HiSIM family) |
| 18 | low | `osdinoise.c:111-113` | OSDI integrated-noise total vector name ends in a space: `"onoise_total_%s%s"` with `" "` |
| 19 | low | `pzan.c:58` | PZ's `keepopinfo` plot is titled `"Distortion Operating Point"` **[verified]** |
| 20 | low | `acsetp.c:37`, `nsetparm.c:64`, `dsetparm.c:37` | the `stop`-parameter error arms all write `*startFreq = 1.0` instead of the stop field |
| 21 | low | `commands.c:319` | the `tf` command's help string reads "Do a transient analysis." |
| 22 | low | `pzsetp.c:79-87` | every PZ parameter description is `""` |
| 23 | low | `inp2dot.c:533-534` | `Sens_filter` array is freed but its strings leak; the list is process-global and survives across circuits |
| 24 | low | `nsetparm.c:83-84` | `output`/`outputref` are declared `IF_STRING` but the setter reads `value->nValue` (a pointer) |
| 25 | low | open issue | `doc/codex/issues/0012` — AC binary rawfile's `frequency` imaginary half is uninitialised heap |
| 26 | low | `inp2dot.c:372-374` | `.tf v out v1` (missing parenthesis) has an empty error arm and is mis-parsed |
| 27 | low | `cktsens.c:216-217` | a SENS filter matching nothing returns `OK` with no plot and no message |

---

## 11. Reference deck fragments (ready for the GUI's templates)

Verified working against `build-ver_50/src/ngspice --batch`.

```spice
* AC, control-block form (preferred: deterministic order, per-run error handling)
.control
ac dec 20 10 10G
plot vdb(out) ; or: wrdata ac.dat vdb(out) vp(out)
.endc
```

```spice
* NOISE with full per-generator breakdown and no spectrum decimation
.control
noise v(out) vin dec 20 10 10G 1
setplot noise1          ; spectral density: onoise_spectrum, inoise_spectrum, onoise_<dev>...
setplot noise2          ; integrated: onoise_total, inoise_total, onoise_total_<dev>...
print onoise_total inoise_total
.endc
```

```spice
* NOISE in squared units
.control
set sqrnoise
noise v(out) vin dec 20 10 10G
.endc
```

```spice
* PZ - both poles and zeros, voltage transfer function
.control
pz in 0 out 0 vol pz
print all
.endc
```

```spice
* TF - DC small-signal gain, Rin, Rout
.control
tf v(out) vin
print all                ; Transfer_function, vin#Input_impedance, output_impedance_at_V(out)
.endc
```

```spice
* DISTO - harmonic mode (needs distof1 on a source)
vin in 0 dc 0.7 ac 1 distof1 1 0
.control
disto dec 10 1k 100k
setplot disto1 ; 2nd harmonic
setplot disto2 ; 3rd harmonic
.endc

* DISTO - intermodulation mode (needs distof2 too)
vin in 0 dc 0.7 ac 1 distof1 1 0 distof2 0.5 0
.control
disto dec 10 1k 100k 0.9
; three plots: IM f1+f2, IM f1-f2, IM 2f1-f2
.endc
```

```spice
* SENS - DC, filtered to the resistors' resistance only
.control
sens v(out) r*:r dc
print all
.endc

* SENS - AC.  Use dec/oct only; 'lin' is broken (see defect #3).
.control
sens v(out) r*:r c*:cap ac dec 10 100 100k
.endc
```

Committed regression decks worth reading as ground truth:
`tests/polezero/simplepz.cir`, `tests/polezero/pz2.cir`, `tests/polezero/pzt.cir`,
`tests/polezero/filt_rc.cir`, `tests/polezero/filt_bridge_t.cir`,
`tests/polezero/filt_multistage.cir`, `tests/sensitivity/diffpair.cir` (+ its `.out`),
`tests/general/diffpair.cir`, `tests/vbic/CEamp.cir`,
`tests/vbic/noise_scale_test.cir`.

---

## 12. Gaps I could not close

* **No local copy of the current ngspice manual.** `doc/` contains only `claude/` and
  `codex/` analysis artefacts; `man/man1/ngspice.1` is a short UNIX page. The
  machine-local documentation I could cite is `src/ngspice.txt`, the **`help` command
  database**, which is visibly SPICE3-era in places (the squared-noise-units claim,
  §3.8, and the absence of the `.sens` filter feature, §7.2). Section numbers in the
  current manual (<https://ngspice.sourceforge.io/docs/ngspice-manual.pdf>) could not be
  verified from here and are deliberately not cited.
* **`Nintegrate`'s exact curve fit** (declared `noisedef.h:210`) — I did not locate its
  definition; it is presumably in a device-shared file. The GUI does not need it, but a
  reviewer wanting to explain `onoise_total` numbers would.
* **`sens_load` / `sens_temp` / `sens_setp` / `sens_getp` internals** (`cktsens.c` statics
  and `cktsgen.c`'s `sens_getp`) were not read line by line; I characterised the
  eligibility rule from `set_param` only. Whether a given device parameter is *really*
  perturbable also depends on that device's `param`/`ask` routines behaving under a
  swapped matrix.
* **XSPICE `MIFnoise` source-name derivation** (`src/xspice/mif/mifnoise.c`
  `setup_declarative_sources` / `prog_names`) — I confirmed the name template but not how
  a code model declares its noise sources in `ifspec.ifs`/`cfunc.mod`. Needed if the GUI
  is to list code-model noise contributors.
* **OSDI noise-source declaration** — `descr->noise_sources[i].name` comes from the
  compiled `.osdi` descriptor; I did not trace how OpenVAF populates it, so I cannot say
  what a Verilog-A `white_noise(...)`/`flicker_noise(...)` call turns into as a vector
  name.
* **`option klu` interaction with SENS** — the guard is commented out
  (`cktsens.c:97-105`); I did **not** run `sens` under `option klu` to see whether it
  produces wrong numbers or crashes. Someone should, before the GUI lets a user combine
  them.
* **Multi-frequency SENS accuracy** — the per-frequency `CKTunsetup`/`CKTsetup` cycle
  (`cktsens.c:380-401`) resets state indices; I did not verify that AC sensitivities at
  the 2nd and later frequency points are correct. The `lin` bug (#3) suggests this path is
  lightly exercised.
* **`.probe`** is accepted and ignored (`inp2dot.c:946-948`, "Maybe generate a 'probe'
  format file in the future"), so there is no probe-based output route for the GUI.
* **Whether any of defects #1–#7 are already known upstream.** I checked
  `doc/codex/issues/` (only `0012` touches this area) but not the ngspice bug tracker.
