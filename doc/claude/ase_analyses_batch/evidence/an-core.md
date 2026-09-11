# Dossier: the four everyday ngspice analyses — OPTIONS, OP, DC, TRAN

Area owner note: this file covers `OPTinfo`, `DCTinfo`, `DCOinfo`, `TRANinfo` as the C
source defines them, plus the run/launch/output path that a GUI must drive. Source tree
`/home/analog/dev/ngspice`, branch `ver_50`, `git describe = ngspice-46-419-gccebdf2a2`.
Every path below is relative to that tree. Built binary used for the empirical checks:
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (reports `ngspice-46+`, "Compiled with
KLU Direct Linear Solver").

All "verified by running" claims below were produced with scratch decks under
`/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/an/`;
neither repository was modified.

---

## 0. FIRST, A CORRECTION TO THE TASK FRAMING

The task brief says "the four everyday analyses -- OP, DC (transfer curve / DCTinfo),
DCOP (DCOinfo), TRAN" and pairs `OPTinfo` with "OP". **That pairing is wrong, and the
plan must not inherit it.**

- `OPTinfo` is **not** an operating-point analysis. Its `IFanalysis.name` is `"options"`
  and its description is `"Task option selection"` — `src/spicelib/analysis/cktsopt.c:389-403`.
  "OPT" is short for **OPTions**. It is the pseudo-analysis that backs the `.options`
  card and the `option` shell command. It has `an_func == NULL`, so it never runs
  anything (`cktsopt.c:402`).
- `DCOinfo` **is** the operating point. Its `IFanalysis.name` is `"OP"`, description
  `"D.C. Operating point analysis"` — `src/spicelib/analysis/dcosetp.c:32-40`. Its
  `an_func` is `DCop()` in `src/spicelib/analysis/dcop.c:22`. "DCO" = **DC O**perating point.
- There is therefore exactly **one** operating-point analysis registered, not two.
  `grep -n "^SPICEanalysis" src/spicelib/analysis/*.c` returns fourteen hits and only
  `DCOinfo` names itself `"OP"`.

A user's `.op` card reaches `DCOinfo`: `dot_op()` calls `ft_find_analysis("OP")`
(`src/spicelib/parser/inp2dot.c:136`) and `ft_find_analysis()` does an exact `strcmp`
against `IFanalysis.name` (`src/frontend/spiceif.c:1837-1844`). The only entry whose
name is `"OP"` is `DCOinfo`.

What *does* legitimately exist in a pair, and is probably what the brief was reaching
for, is the **two operating-point *modes***, `MODEDCOP` and `MODETRANOP`
(`src/include/ngspice/cktdefs.h:180-181`). Section 5.6 below covers that.

---

## 1. THE REGISTRY: `analInfo[]`, `SPICEanalysis`, `IFanalysis`, `IFparm`

### 1.1 The registry array

`src/spicelib/analysis/analysis.c:36-59`:

```c
SPICEanalysis *analInfo[] = {
    &OPTinfo, &ACinfo, &DCTinfo, &DCOinfo, &TRANinfo,
    &PZinfo, &TFinfo, &DISTOinfo, &NOISEinfo, &SENSinfo,
#ifdef WITH_PSS
    &PSSinfo,
#endif
#ifdef WANT_SENSE2
    &SEN2info,
#endif
#ifdef RFSPICE
    &SPinfo,
#ifdef WITH_HB
    &HBinfo,
#endif
#endif
};
```

The **array index is the `JOBtype`** stamped into every job (`CKTnewAnal()`,
`src/spicelib/analysis/cktnewan.c:19-37`, line 27 `(*analPtr)->JOBtype = type;`). Index
values matter — they are hard-coded in several places.

**In this tree** (`WITH_PSS` undefined, `WANT_SENSE2` undefined, `RFSPICE` defined,
`WITH_HB` undefined — see §9) the indices are:

| idx | symbol | `IFanalysis.name` | `description` |
|-----|--------|-------------------|---------------|
| 0 | `OPTinfo` | `options` | `Task option selection` |
| 1 | `ACinfo` | `AC` | (other agent's area) |
| 2 | `DCTinfo` | `DC` | `D.C. Transfer curve analysis` |
| 3 | `DCOinfo` | `OP` | `D.C. Operating point analysis` |
| 4 | `TRANinfo` | `TRAN` | `Transient analysis` |
| 5 | `PZinfo` | `PZ` | — |
| 6 | `TFinfo` | `TF` | — |
| 7 | `DISTOinfo` | `DISTO` | — |
| 8 | `NOISEinfo` | `NOISE` | — |
| 9 | `SENSinfo` | `SENS` | — |
| 10 | `SPinfo` | `SP` | RFSPICE only |

Corroboration for the numbers, from independent hard-codings in the tree:
- `src/frontend/outitf.c:683-684` — `run->circuit->CKTcurJob->JOBtype == 4` with the
  comment `/* JOBtype == 4 means Transient Analysis. FIX ME */`. TRAN == 4. ✔
- `src/spicelib/analysis/cktop.c:34` — `ckt->CKTcurJob->JOBtype != 2` with the comment
  `/* If this is called from dc simulation, don't set "op" */`. DC == 2. ✔
- `src/spicelib/analysis/dctran.c:983` — `JOBtype != 4` guard, again TRAN. ✔

**GUI warning:** these indices shift if the tree is configured with `--enable-pss` or
`--enable-sense2`, because those entries are inserted *before* `SPinfo`. `TRAN==4` and
`DC==2` and `OP==3` are stable (they precede all the `#ifdef`s), so the hard-codings
above are safe; anything at index ≥ 10 is not.

### 1.2 `SPICEanalysis` — the per-analysis descriptor

`src/spicelib/analysis/analysis.h:4-13`:

```c
struct SPICEanalysis {
    IFanalysis if_analysis;   /* name, description, numParms, analysisParms */
    int size;                 /* sizeof() of the JOB struct to tmalloc */
    int domain;               /* NODOMAIN / TIMEDOMAIN / FREQUENCYDOMAIN / SWEEPDOMAIN */
    int do_ic;                /* run CKTic() before an_func */
    int (*setParm)(CKTcircuit*, JOB*, int which, IFvalue*);
    int (*askQuest)(CKTcircuit*, JOB*, int which, IFvalue*);
    int (*an_init)(CKTcircuit*, JOB*);
    int (*an_func)(CKTcircuit*, int restart);
};
```

`domain` constants: `NODOMAIN=0, TIMEDOMAIN=1, FREQUENCYDOMAIN=2, SWEEPDOMAIN=3` —
`src/include/ngspice/jobdefs.h:140-145`. `domain` is used only to format failure
messages (`CKTtrouble()`, `src/spicelib/analysis/ckttroub.c:43-84`) — it selects whether
the message says "initial timepoint / time = …", "frequency = …", or the sweep-source
values.

`do_ic` is consumed at `src/spicelib/analysis/cktdojob.c:190-191`:
`if (!error && analInfo[i]->do_ic) error = CKTic(ckt);`

### 1.3 `IFanalysis` and `IFparm`

`src/include/ngspice/ifsim.h:323-329`:
```c
struct IFanalysis { char *name; char *description; int numParms; IFparm *analysisParms; };
```
`src/include/ngspice/ifsim.h:45-50`:
```c
struct IFparm { char *keyword; int id; int dataType; char *description; };
```

Type bits (`ifsim.h:100-129`): `IF_FLAG 0x1`, `IF_INTEGER 0x2`, `IF_REAL 0x4`,
`IF_COMPLEX 0x8`, `IF_NODE 0x10`, `IF_STRING 0x20`, `IF_INSTANCE 0x40`,
`IF_PARSETREE 0x80`, `IF_VECTOR 0x8000`, `IF_REQUIRED 0x4000`, `IF_VARTYPES 0x80ff`,
`IF_SET 0x2000`, `IF_ASK 0x1000`. Sensitivity annotations `IF_REDUNDANT 0x0010000`,
`IF_PRINCIPAL 0x0020000` etc. at `ifsim.h:138-146`.

Documented meaning (`ifsim.h:91-96`): `IF_SET` = the front end may write it; `IF_ASK` =
the simulator can report it; both zero = "recognised but not implemented in this
simulator". **`IF_REDUNDANT` appears in no OPT/DCT/DCO/TRAN parm table** — it is only
used by the sensitivity machinery on *device* parameters. So for this area the answer to
"which parms carry IF_REDUNDANT" is: none.

**Source-vs-table inconsistency worth recording:** the lookup helpers do *not* enforce
`IF_ASK`. `ft_find_analysis_parm()` matches on keyword alone
(`src/frontend/spiceif.c:1847-1855`) and `if_analQbyName()` calls `askAnalysisQuest`
without checking the flag (`spiceif.c:1285-1294`). Consequently `tstart/tstop/tstep` are
readable back from a TRAN job even though their `IFparm` entries carry only `IF_SET` —
and the tree relies on that: `if_tranparams()` (`spiceif.c:1301-1345`) reads all three,
and `com_linearize()` calls it (`src/frontend/linear.c:53`). I trust the code over the
flag table here; the flag table is stale.

### 1.4 How a keyword reaches `setParm`

Netlist path: `INP2dot()` dispatches on the dot token
(`src/spicelib/parser/inp2dot.c:834-975`) → per-card `dot_*()` → `INPapName(ckt, which,
job, "keyword", &value)` → `ft_find_analysis_parm()` → `ft_sim->setAnalysisParm()` (i.e.
the `SPICEanalysis.setParm` function) — `src/spicelib/parser/inpapnam.c:14-37`. A
keyword that is not in the table prints the keyword on `cp_err` and returns `E_BADPARM`
(`inpapnam.c:28-31`). Errors are accumulated onto the card via the `GCA`/`IFC` macros
(`src/include/ngspice/inpmacs.h`).

`.options` path is different and is described in §2.3.

---

## 2. `OPTinfo` — the `options` pseudo-analysis (index 0)

### 2.1 Descriptor

`src/spicelib/analysis/cktsopt.c:389-403`:

| field | value |
|---|---|
| `if_analysis.name` | `"options"` |
| `if_analysis.description` | `"Task option selection"` |
| `numParms` | `NUMELEMS(OPTtbl)` (also exported as `int OPTcount`, `cktsopt.c:387`) |
| `size` | `0` — comment `/* no size associated with options */` |
| `domain` | `NODOMAIN` |
| `do_ic` | `0` |
| `setParm` | `CKTsetOpt` (`cktsopt.c:33`) |
| `askQuest` | `CKTacct` (`src/spicelib/analysis/cktacct.c:32`) |
| `an_init` | `NULL` |
| `an_func` | `NULL` |

**JOB struct: there is none.** `CKTnewAnal()` special-cases `type == 0` and hands back a
pointer to `taskPtr->taskOptions`, i.e. the `TSKtask` itself
(`src/spicelib/analysis/cktnewan.c:23-29`). `CKTsetOpt()` casts its `JOB*` straight back
to `TSKtask*` (`cktsopt.c:35`). The backing store is `TSKtask` in
`src/include/ngspice/tskdefs.h`.

Because `size == 0` and the job is not linked into `task->jobs`, an options "job" never
appears in `CKTdoJob`'s execution loop.

### 2.2 The complete `OPTtbl` table

`src/spicelib/analysis/cktsopt.c:264-385`. Columns: keyword, id macro, flags, description
string, and what `CKTsetOpt` does with it (`cktsopt.c:39-262`) or what `CKTacct` returns
(`cktacct.c:36-174`). Id macros are defined in `src/include/ngspice/optdefs.h:55-158`.

**XSPICE-gated block** (`cktsopt.c:265-277`, inside `#ifdef XSPICE`; XSPICE is ON by
default in this tree):

| keyword | id | flags | description | effect |
|---|---|---|---|---|
| `maxopalter` | `OPT_EVT_MAX_OP_ALTER` | SET\|INTEGER | Maximum analog/event alternations in DCOP | `ckt->evt->limits.max_op_alternations = iValue` (`:211`) |
| `maxevtiter` | `OPT_EVT_MAX_EVT_PASSES` | SET\|INTEGER | Maximum event iterations at analysis point | `ckt->evt->limits.max_event_passes = iValue` (`:215`) |
| `noopalter` | `OPT_ENH_NOOPALTER` | SET\|FLAG | Do not do analog/event alternation in DCOP | `ckt->evt->options.op_alternate = MIF_FALSE` (`:219`) |
| `ramptime` | `OPT_ENH_RAMPTIME` | SET\|REAL | Transient analysis supply ramping time | `ckt->enh->ramp.ramptime = rValue` (`:223`) |
| `convlimit` | `OPT_ENH_CONV_LIMIT` | SET\|FLAG | Enable convergence assistance on code models | `enh->conv_limit.enabled = MIF_TRUE` (`:227`) |
| `convstep` | `OPT_ENH_CONV_STEP` | SET\|REAL | Fractional step allowed by code model inputs between iterations | `:231-232` |
| `convabsstep` | `OPT_ENH_CONV_ABS_STEP` | SET\|REAL | Absolute step allowed by code model inputs between iterations | `:236-237` |
| `autopartial` | `OPT_MIF_AUTO_PARTIAL` | SET\|FLAG | Use auto-partial computation for all models | `g_mif_info.auto_partial.global = MIF_TRUE` (`:241`) |
| `rshunt` | `OPT_ENH_RSHUNT` | SET\|REAL | Shunt resistance from analog nodes to ground | `if (rValue > 1e-30) { enabled; gshunt = 1/rValue } else warn "Rshunt option too small. Ignored."` (`:244-252`). Without XSPICE the arm prints `"WARNING - Option Rshunt available only with XSPICE enabled."` (`:254-256`). |

**Always-present block** (`cktsopt.c:278-385`):

| keyword | id | flags | description | effect / notes |
|---|---|---|---|---|
| `cshunt` | `OPT_CSHUNT` | SET\|REAL | Shunt capacitor from analog nodes to ground | `TSKcshunt` (`:176`). Default `-1` (`cktntask.c:95`) |
| `noopiter` | `OPT_NOOPITER` | SET\|FLAG | Go directly to gmin stepping | `TSKnoOpIter = (iValue != 0)` (`:42`) |
| `gmin` | `OPT_GMIN` | SET\|REAL | Minimum conductance | `TSKgmin`. Default `1e-12` |
| `gshunt` | `OPT_GSHUNT` | SET\|REAL | Shunt conductance | `TSKgshunt`. Default `0` |
| `reltol` | `OPT_RELTOL` | SET\|REAL | Relative error tolerence | default `1e-3` |
| `abstol` | `OPT_ABSTOL` | SET\|REAL | Absolute error tolerence | default `1e-12` |
| `vntol` | `OPT_VNTOL` | SET\|REAL | Voltage error tolerence | `TSKvoltTol`, default `1e-6` |
| `trtol` | `OPT_TRTOL` | SET\|REAL | Truncation error overestimation factor | default `7.` |
| `chgtol` | `OPT_CHGTOL` | SET\|REAL | Charge error tolerence | default `1e-14` |
| `pivtol` | `OPT_PIVTOL` | SET\|REAL | Minimum acceptable pivot | `TSKpivotAbsTol`, default `1e-13` |
| `pivrel` | `OPT_PIVREL` | SET\|REAL | Minimum acceptable ratio of pivot | `TSKpivotRelTol`, default `1e-3` |
| `tnom` | `OPT_TNOM` | **SET\|ASK**\|REAL | Nominal temperature | **stored in kelvin**: `TSKnomTemp = rValue + CONSTCtoK` (`:72`); read back in °C (`cktacct.c:170`). Default `300.15` K = 27 °C |
| `temp` | `OPT_TEMP` | **SET\|ASK**\|REAL | Operating temperature | `TSKtemp = rValue + CONSTCtoK` (`:75`); read back °C. Default `300.15` K |
| `itl1` | `OPT_ITL1` | SET\|INTEGER | DC iteration limit | `TSKdcMaxIter`, default `100` |
| `itl2` | `OPT_ITL2` | SET\|INTEGER | DC transfer curve iteration limit | `TSKdcTrcvMaxIter`, default `50` |
| `itl3` | `OPT_ITL3` | INTEGER (no SET, no ASK) | Lower transient iteration limit | **recognised, unimplemented** — `case OPT_ITL3: break;` (`:83-84`). Listed in `unsupported[]` (`src/frontend/spiceif.c:446-453`), so `option itl3=…` prints "option itl3 is currently unsupported." |
| `itl4` | `OPT_ITL4` | SET\|INTEGER | Upper transient iteration limit | `TSKtranMaxIter`, default `10` |
| `itl5` | `OPT_ITL5` | INTEGER (no SET) | Total transient iteration limit | unimplemented (`:88-89`), in `unsupported[]` |
| `itl6` | `OPT_SRCSTEPS` | SET\|INTEGER | number of source steps | alias of `srcsteps` |
| `srcsteps` | `OPT_SRCSTEPS` | SET\|INTEGER | number of source steps | `TSKnumSrcSteps`, default `1` |
| `gminsteps` | `OPT_GMINSTEPS` | SET\|INTEGER | number of Gmin steps | `TSKnumGminSteps`, default `1` |
| `gminfactor` | `OPT_GMINFACT` | SET\|REAL | factor per Gmin step | `TSKgminFactor`, default `10` |
| `acct` | `0` | FLAG | Print accounting | id 0 → never reaches `CKTsetOpt`; handled front-end-side by `if_option()` (`src/frontend/spiceif.c:472-474`, sets `ft_acctprint`) |
| `list` | `0` | FLAG | Print a listing | `ft_listprint` (`spiceif.c:484-486`) |
| `nomod` | `0` | FLAG | Don't print a model summary | `ft_nomod` (`spiceif.c:496-498`) |
| `nopage` | `0` | FLAG | Don't insert page breaks | `ft_nopage` (`spiceif.c:493-495`) |
| `node` | `0` | FLAG | Print a node connection summary | `ft_nodesprint` (`spiceif.c:487-489`) |
| `opts` | `0` | FLAG | Print a list of the options | `ft_optsprint` (`spiceif.c:490-492`) |
| `oldlimit` | `OPT_OLDLIMIT` | SET\|FLAG | use SPICE2 MOSfet limiting | `TSKfixLimit` (`:136`) |
| `numdgt` | `0` | INTEGER | Set number of digits printed | ignored by simulator |
| `cptime` | `0` | REAL | Total cpu time in seconds | ignored |
| `limtim` | `0` | INTEGER | Time to reserve for output | in `obsolete[]` (`spiceif.c:455-460`) |
| `limpts` | `0` | INTEGER | Maximum points per analysis | `obsolete[]` |
| `lvlcod` | `0` | INTEGER | Generate machine code | `obsolete[]` |
| `lvltim` | `0` | INTEGER | Type of timestep control | `unsupported[]` |
| `method` | `OPT_METHOD` | SET\|STRING | Integration method | `strncmp(sValue,"trap",4)==0 → TRAPEZOIDAL`, `strcmp(sValue,"gear")==0 → GEAR`, else **returns `E_METHOD`** (`:141-147`). Default `TRAPEZOIDAL`. Also listed in `unsupported[]` for the `option` shell command path — see §2.3 |
| `maxord` | `OPT_MAXORD` | SET\|INTEGER | Maximum integration order | **clamped**: `<1 → 1` + stderr warning, `>6 → 6` + stderr warning (`:123-134`). Default `2`. Also in `unsupported[]` for the shell path |
| `indverbosity` | `OPT_INDVERBOSITY` | SET\|INTEGER | Control Inductive Systems Check (coupling) | default `2` = "full check, full verbosity" (`cktntask.c:111-112`) |
| `xmu` | `OPT_XMU` | SET\|REAL | Coefficient for trapezoidal method | default `0.5`; `cktntask.c:113-118` documents `0`=Backward Euler, `0.5`=trapezoidal, `0.49`=damps ringing |
| `defm` | `OPT_DEFM` | SET\|REAL | Default MOSfet Multiplier | default `1` |
| `defl` | `OPT_DEFL` | SET\|REAL | Default MOSfet length | default `1e-4` |
| `defw` | `OPT_DEFW` | SET\|REAL | Default MOSfet width | default `1e-4` |
| `minbreak` | `OPT_MINBREAK` | SET\|REAL | Minimum time between breakpoints | `TSKminBreak`; **not initialised** in `CKTnewTask()` → zero from `tmalloc`; derived at run time, see §5.4 |
| `defad` | `OPT_DEFAD` | SET\|REAL | Default MOSfet area of drain | default `0` |
| `defas` | `OPT_DEFAS` | SET\|REAL | Default MOSfet area of source | **BUG: writes `TSKdefaultMosAD`, not `…AS`** — `cktsopt.c:111-113`. `.options defas=…` silently sets the *drain* area. Worth surfacing as a known defect; the GUI should not promise `defas` works |
| `bypass` | `OPT_BYPASS` | SET\|INTEGER | Allow bypass of unchanging elements | default `0` |
| `totiter` | `OPT_ITERS` | **ASK**\|INTEGER | Total iterations | `CKTstat->STATnumIter` |
| `traniter` | `OPT_TRANIT` | ASK\|INTEGER | Transient iterations | `STATtranIter` |
| `equations` | `OPT_EQNS` | ASK\|INTEGER | Circuit Equations | `CKTmaxEqNum` |
| `originalnz` | `OPT_ORIGNZ` | ASK\|INTEGER | Circuit original non-zeroes | KLU or Sparse count |
| `fillinnz` | `OPT_FILLNZ` | ASK\|INTEGER | Circuit fill-in non-zeroes | |
| `totalnz` | `OPT_TOTALNZ` | ASK\|INTEGER | Circuit total non-zeroes | |
| `tranpoints` | `OPT_TRANPTS` | ASK\|INTEGER | Transient timepoints | `STATtimePts` |
| `accept` | `OPT_TRANACCPT` | ASK\|INTEGER | Accepted timepoints | `STATaccepted` |
| `rejected` | `OPT_TRANRJCT` | ASK\|INTEGER | Rejected timepoints | `STATrejected` |
| `time` | `OPT_TOTANALTIME` | ASK\|REAL | Total analysis time (seconds) | `STATtotAnalTime` |
| `loadtime` | `OPT_LOADTIME` | ASK\|REAL | Matrix load time | |
| `synctime` | `OPT_SYNCTIME` | ASK\|REAL | Matrix synchronize time | |
| `reordertime` | `OPT_REORDTIME` | ASK\|REAL | Matrix reorder time | |
| `factortime` | `OPT_DECOMP` | ASK\|REAL | Matrix factor time | |
| `solvetime` | `OPT_SOLVE` | ASK\|REAL | Matrix solve time | |
| `trantime` | `OPT_TRANTIME` | ASK\|REAL | Transient analysis time | |
| `tranloadtime` | `OPT_TRANLOAD` | ASK\|REAL | Transient load time | |
| `transynctime` | `OPT_TRANSYNC` | ASK\|REAL | Transient sync time | |
| `tranfactortime` | `OPT_TRANDECOMP` | ASK\|REAL | Transient factor time | |
| `transolvetime` | `OPT_TRANSOLVE` | ASK\|REAL | Transient solve time | |
| `trantrunctime` | `OPT_TRANTRUNC` | ASK\|REAL | Transient trunc time | |
| `trancuriters` | `OPT_TRANCURITER` | ASK\|INTEGER | Transient iterations for the last time point | `STATnumIter - STAToldIter` |
| `actime` | `OPT_ACTIME` | ASK\|REAL | AC analysis time | |
| `acloadtime` | `OPT_ACLOAD` | ASK\|REAL | AC load time | |
| `acsynctime` | `OPT_ACSYNC` | ASK\|REAL | AC sync time | |
| `acfactortime` | `OPT_ACDECOMP` | ASK\|REAL | AC factor time | |
| `acsolvetime` | `OPT_ACSOLVE` | ASK\|REAL | AC solve time | |
| `trytocompact` | `OPT_TRYTOCOMPACT` | SET\|FLAG | Try compaction for LTRA lines | default `0` |
| `badmos3` | `OPT_BADMOS3` | SET\|FLAG | use old mos3 model (discontinuous with respect to kappa) | default `0` |
| `keepopinfo` | `OPT_KEEPOPINFO` | SET\|FLAG | Record operating point for each small-signal analysis | default `0` |
| `copynodesets` | `OPT_COPYNODESETS` | SET\|FLAG | Copy nodesets from device terminals to internal nodes | default `0` |
| `nodedamping` | `OPT_NODEDAMPING` | SET\|FLAG | Limit iteration to iteration node voltage change | default `0`; when on, `NIiter` damps steps > 10 V (`src/maths/ni/niiter.c:300-324`) |
| `absdv` | `OPT_ABSDV` | SET\|REAL | Maximum absolute iter-iter node voltage change | default `0.5` |
| `reldv` | `OPT_RELDV` | SET\|REAL | Maximum relative iter-iter node voltage change | default `2.0` |
| `noopac` | `OPT_NOOPAC` | SET\|FLAG | No op calculation in ac if circuit is linear | `TSKnoopac`; effective only if `CKTisLinear` (`cktdojob.c:109`) |
| `epsmin` | `OPT_EPSMIN` | SET\|REAL | Minimum value for log | default `1e-28` |
| `sparse` | `OPT_SPARSE` | SET\|FLAG | Set SPARSE 1.3 as Direct Linear Solver | **`#ifdef KLU`** (on in this tree). `TSKkluMODE = (iValue == 0)` — note the inverted sense (`:181`) |
| `klu` | `OPT_KLU` | SET\|FLAG | Set KLU as Direct Linear Solver | `#ifdef KLU`. `TSKkluMODE = (iValue != 0)` |
| `klu_memgrow_factor` | `OPT_KLU_MEMGROW_FACTOR` | SET\|REAL | KLU Memory Grow Factor (default is 1.2) | **BUG: `TSKkluMemGrowFactor = (val->rValue == 1.2)`** (`:187`) — assigns a *boolean* comparison, not the value. Default is `1.2` from `cktntask.c:144`. Do not expose this in a GUI |
| `ltereltol` | `OPT_LTERELTOL` | SET\|REAL | Relative error tolerence | default `1e-3` |
| `lteabstol` | `OPT_LTEABSTOL` | SET\|REAL | Absolute error tolerence | default `1e-6` |
| `ltetrtol` | `OPT_LTETRTOL` | SET\|REAL | Truncation error overestimation factor | default `500.` |
| `newtrunc` | `OPT_NEWTRUNC` | SET\|FLAG | voltage controlled truncation | **`#ifdef PREDICTOR`** — `PREDICTOR` is *undefined* in this tree, so the option forces `TSKnewtrunc = 0` and prints `"Warning: Option 'newtrunc' ignored, compilation with preprocessor flag 'PREDICTOR' is required."` (`:199-207`) |

Unknown ids fall through to `default: return(-1)` (`cktsopt.c:259-261`), which
`INPdoOpts()` reports as `"Warning:  can't set option <name>"`
(`src/spicelib/parser/inpdoopt.c:64-67`).

### 2.3 Two *different* paths reach the options — and they accept different keywords

This is architecturally important and easy to get wrong in a GUI.

**Path A — the `.options` card is parsed twice.**
1. `inp_dodeck()` re-lexes every `.options` line as if it were a `set` command and stores
   the results in `ft_curckt->ci_vars` (`src/frontend/inp.c:1376-1397`), then feeds each
   one to `if_option()` (`inp.c:1605-1625`).
2. Separately, `INP2dot()` sees `.options`/`.option`/`.opt`
   (`src/spicelib/parser/inp2dot.c:949-953`) → `dot_options()` (`inp2dot.c:817-831`) →
   `INPdoOpts()` (`src/spicelib/parser/inpdoopt.c:20-79`), which writes into
   `task->taskOptions` via `setAnalysisParm`.

`INPdoOpts()` has three arms per token (`inpdoopt.c:54-78`):
- keyword found but `(dataType & IF_UNIMP_MASK) == 0` → `" Warning: %s not yet
  implemented - ignored "` and the value is consumed;
- keyword found with `IF_SET` → set it;
- otherwise → `"Error: unknown option %s - ignored"` on `cp_err` **unless** the token
  looks numeric (chars from `0123456789.e+-`), in which case it is silently dropped
  (`inpdoopt.c:70-78`).

**Path B — the `option` / `options` shell command** (`src/frontend/commands.c:140-147`,
both names bound to `com_option`) goes through `cp_usrset()` →
`if_option()` (`src/frontend/options.c:528-534`; `src/frontend/spiceif.c:463-…`).
`if_option()` first intercepts nine *front-end* names that are **not** in `OPTtbl` at all
in a settable sense — `acct`, `noacct`, `noinit`, `norefvalue`, `list`, `node`, `opts`,
`nopage`, `nomod` (`spiceif.c:472-499`) — then consults `OPTtbl`, then checks two
hard-coded rejection lists:
- `unsupported[] = {"itl3","itl5","lvltim","maxord","method"}` (`spiceif.c:446-453`)
  → `"Warning: option %s is currently unsupported."`
- `obsolete[] = {"limpts","limtim","lvlcod"}` (`spiceif.c:455-460`)
  → `"Warning: option %s is obsolete."`

**So `maxord` and `method` are settable from a `.options` card but rejected from the
`option` shell command.** That is a real behavioural split a GUI must know about: emit
`.options method=gear maxord=2` into the deck, do not emit `option method=gear`.

Type coercion in `if_option()` (`spiceif.c:525-560`): REAL accepts CP_REAL or CP_NUM;
INTEGER accepts CP_NUM or rounds a CP_REAL (`floor(x+0.5)`); STRING needs CP_STRING;
FLAG accepts CP_BOOL or CP_NUM. Wrong type → `goto badtype`. If no circuit is loaded:
`"Simulation parameter \"%s\" can't be set until a circuit has been loaded."`
(`spiceif.c:562-568`).

### 2.4 Where the option defaults actually live

`CKTnewTask()`, `src/spicelib/analysis/cktntask.c:16-152`. The `else` arm at
`cktntask.c:92-145` is the "application defaults" block quoted in the table above. The
`if` arm at `cktntask.c:36-88` is taken when the task name is literally `"special"` —
i.e. the interactive task built by `if_run()` for a `.control` `tran`/`dc`/`op` command
(`src/frontend/spiceif.c:311-328`) — and it **copies** the circuit's default task field
by field. Fields *not* copied there, and therefore reset to zero for an interactive run:
`TSKminBreak`, `TSKdelmin`, `TSKfixLimit` (see the `/* minBreak */`, `/* delmin */`,
`/* fixLimit */` comments at `cktntask.c:51,61,68`). `TSKminBreak` and `TSKdelmin` are
recomputed at run time anyway (§5.4), but **`oldlimit` (`TSKfixLimit`) set by `.options`
is silently lost when the user then types `tran …` in `.control`.**

`CKTdoJob()` copies `TSK*` → `CKT*` at the start of every run
(`src/spicelib/analysis/cktdojob.c:52-120`), so options are latched per-run, not
per-analysis.

Two run-time overrides applied there:
- `#ifdef XSPICE`, if the circuit has any `A` devices and `trtol > 1`, `trtol` is forced
  to `1` (printing `"Reducing trtol to 1 for xspice 'A' devices"`) unless
  `set xtrtol=<n>` overrides it (`cktdojob.c:77-92`).
- `ckt->CKTnoopac = TSKnoopac && ckt->CKTisLinear` (`cktdojob.c:109`).

`CKTdoJob` also unconditionally prints `"Doing analysis at TEMP = %f and TNOM = %f"`
(`cktdojob.c:122-123`) — a reliable per-run marker for a GUI log parser.

---

## 3. `DCOinfo` — the operating point, `.op` (index 3)

### 3.1 Descriptor

`src/spicelib/analysis/dcosetp.c:32-44`:

| field | value |
|---|---|
| `if_analysis.name` | `"OP"` |
| `if_analysis.description` | `"D.C. Operating point analysis"` |
| `numParms` | `0` |
| `analysisParms` | `NULL` |
| `size` | `sizeof(OP)` |
| `domain` | `NODOMAIN` |
| `do_ic` | `1` |
| `setParm` | `DCOsetParm` (`dcosetp.c:16-29`) |
| `askQuest` | `DCOaskQuest` (`src/spicelib/analysis/dcoaskq.c:15-22`) |
| `an_init` | `NULL` |
| `an_func` | `DCop` (`src/spicelib/analysis/dcop.c:22`) |

### 3.2 The parameter table is empty. Both accessors are stubs.

`DCOsetParm()` has an empty `switch` and unconditionally `return(E_BADPARM)`
(`dcosetp.c:16-29`). `DCOaskQuest()` unconditionally `return(E_BADPARM)`
(`dcoaskq.c:15-22`). **The OP analysis has zero configurable parameters.**

### 3.3 JOB struct

`src/include/ngspice/opdefs.h:115-119`:
```c
typedef struct { int JOBtype; JOB *JOBnextJob; char *JOBname; } OP;
```
i.e. the bare `JOB` header and nothing else.

### 3.4 Card and command syntax

- Netlist: `.op` — the rest of the line is discarded (`dot_op()` does
  `NG_IGNORE(line)`, `src/spicelib/parser/inp2dot.c:124-143`). The job's UID/plot name is
  the literal string `"Operating Point"` (`inp2dot.c:141`).
- Control: `op` — registered at `src/frontend/commands.c:312-315`, help text
  `"[.op line args] : Determine the operating point of the circuit."`, min args 0, max
  `LOTS`. `com_op()` → `dosim("op", wl)` (`src/frontend/runcoms.c:132-136`). `if_run()`
  rebuilds the line as `.op <args>` (`src/frontend/spiceif.c:279-280`) and re-parses it,
  so any argument the user types is accepted by the lexer and then ignored. **`op` takes
  no options.**

### 3.5 What `DCop()` does

`src/spicelib/analysis/dcop.c:22-125`:
1. `#ifdef XSPICE` sets `g_mif_info.circuit.anal_type = MIF_DC`, `anal_init = MIF_TRUE`
   (`:40-42`).
2. `CKTnames()` → `OUTpBeginPlot(ckt, curJob, JOBname, **refName = NULL**, IF_REAL,
   numNames, nameList, IF_REAL, &plot)` (`:46-52`). The `NULL` reference vector is why an
   OP plot has **no scale vector**.
3. `CKTsoaInit()` if `CKTsoaCheck` (`:56-58`).
4. If XSPICE event instances exist → `EVTop(...MODEDCOP|MODEINITJCT, ...MODEDCOP|MODEINITFLOAT,
   CKTdcMaxIter, MIF_TRUE)` + `EVTdump(IPC_ANAL_DCOP)` + `EVTop_save()` (`:62-72`);
   otherwise `CKTop(ckt, (mode&MODEUIC)|MODEDCOP|MODEINITJCT,
   (mode&MODEUIC)|MODEDCOP|MODEINITFLOAT, CKTdcMaxIter)` (`:76-79`).
5. On failure: prints `"\nDC solution failed -\n"` to **stdout**, calls `CKTncDump(ckt)`
   (the "Last Node Voltages / Previous Iter" table) and returns the failure code
   (`:81-85`).
6. Sets `CKTmode = (mode&MODEUIC)|MODEDCOP|MODEINITSMSIG` (`:87`) — this is what leaves
   the small-signal linearisation in place for a following AC/noise run.
7. `CKTload(ckt)` once more, then `CKTdump(ckt, 0.0, plot)` and `CKTsoaCheck()` (`:113-118`).
   Reload failure prints `"error: circuit reload failed."` to stderr (`:120`).
8. `OUTendPlot(plot)`.

### 3.6 `do_ic == 1` for OP — what that means

`CKTdoJob()` calls `CKTic()` before `DCop()` (`cktdojob.c:190-191`). `CKTic()`
(`src/spicelib/analysis/cktic.c:14-83`):
- zeroes `CKTrhs`;
- for every node with `nsGiven` (a `.nodeset`) sets `CKTrhsOld = CKTrhs = nodeset` and
  sets `CKThadNodeset = 1` (`cktic.c:26-48`);
- for every node with `icGiven` (a `.ic`) sets `CKTrhsOld = CKTrhs = ic` (`:49-70`);
- if `CKTmode & MODEUIC`, calls every device's `DEVsetic` (`:73-80`).

For a plain `.op`, `CKTmode` does not contain `MODEUIC` (no `an_init` sets it), so the
`DEVsetic` sweep does not run and `.ic`/`.nodeset` act only as the initial guess. During
the solve, `CKTload()` additionally *forces* nodeset nodes while `MODEINITJCT|MODEINITFIX`
is active (`src/spicelib/analysis/cktload.c:120-145`: `rhs = 1e10*nodeset*srcFact`,
diagonal `1e10`), and forces `.ic` nodes **only under `MODETRANOP` and only when `MODEUIC`
is clear** (`cktload.c:146-173`). So: `.nodeset` bites in an `.op`; `.ic` does not.

### 3.7 Output vectors and plot naming

Verified by running `.op` on a 3-node RC divider:

```
Plotname: Operating Point
Flags: real
No. Variables: 3
No. Points: 1
Variables:
        0       v(in)   voltage
        1       v(out)  voltage
        2       i(v1)   current
```

- The rawfile `Plotname:` is the job UID string, i.e. `Operating Point` — set at
  `src/spicelib/parser/inp2dot.c:141` and carried through
  `OUTpBeginPlot(..., ckt->CKTcurJob->JOBname, ...)` (`dcop.c:48-52`) into `run->type`
  (`src/frontend/outitf.c:222`) and then `fprintf(... "Plotname: %s\n", run->type)`
  (`outitf.c:954`).
- In-memory plot name is `op1`, `op2`, … : `plot_alloc(run->type)`
  (`outitf.c:1209`) → `ft_plotabbrev()` matches the substring `"op"` in
  `"operating point"` and returns `"op"` (`src/frontend/typesdef.c:67-90`, entry
  `{ "op", "op", … }`, and `typesdef.c:331-348`), then `plot_alloc` appends `plot_num`
  (`src/frontend/vectors.c:1094-1110`).
- The vector set is exactly `CKTnames()`'s node list: every entry of `ckt->CKTnodes`
  except ground (`src/spicelib/analysis/cktnames.c:18-31`). Voltage nodes keep their deck
  name; current branch equations are named `<src>#branch` internally.
- Rawfile name mangling happens in `fileInit_pass2()` (`outitf.c:1087-1117`): a name
  containing `#branch` is written as `i(<name-without-#branch>)` unless
  `set keep#branch` (`outitf.c:1091`); a `SV_VOLTAGE` name is written as `v(<name>)`;
  anything else verbatim. Type classification is `guess_type()` (`outitf.c:1023-1083`).
- **There is no reference/scale vector** (`run->refIndex = -1`, `outitf.c:302-304`), so
  "No. Variables: 3" means three data columns and no independent axis.
- Device-level operating-point quantities (`@m1[gm]`, `@q1[ic]`, …) are **not** in this
  list. They arrive only through the `save` mechanism (§6.4) or the `show`/`showmod`
  commands.

### 3.8 Batch printout for `.op`

With no rawfile, `ft_cktcoms()` prints the classic tables
(`src/frontend/dotcards.c:222-272`):
```
        Node                                  Voltage
        ----                                  -------
        ----    -------
        out                              6.666667e-01
        in                               1.000000e+00

        Source  Current
        ------  -------

        v1#branch                        -3.33333e-04
```
followed by `com_showmod(&all)` unless `ft_nomod` (`.options nomod`) and then
`com_show(&all)` (`dotcards.c:266-269`) — that is the device operating-point dump. With a
rawfile (`terse`), it prints only `"OP information in rawfile."` (`dotcards.c:239-240`).
An `.op` with no non-ground node prints `"Error: incomplete or empty netlist / or no node
to report an operating point for; no operating point printed!"` and returns 1
(`dotcards.c:231-237` — this is the fix recorded in `doc/codex/issues/0072-*.md`).

Note `setcplot("op")` uses `ciprefix` (`dotcards.c:38-48`), so with several op plots it
finds the first whose typename starts with `op`.

---

## 4. `DCTinfo` — the DC transfer curve, `.dc` (index 2)

### 4.1 Descriptor

`src/spicelib/analysis/dctsetp.c:104-119`:

| field | value |
|---|---|
| `if_analysis.name` | `"DC"` |
| `if_analysis.description` | `"D.C. Transfer curve analysis"` |
| `numParms` | `NUMELEMS(DCTparms)` = 10 |
| `size` | `sizeof(TRCV)` |
| `domain` | `SWEEPDOMAIN` |
| `do_ic` | `1` |
| `setParm` | `DCTsetParm` (`dctsetp.c:15-88`) |
| `askQuest` | `DCTaskQuest` (`src/spicelib/analysis/dctaskq.c:15-27`) |
| `an_init` | `NULL` |
| `an_func` | `DCtrCurv` (`src/spicelib/analysis/dctrcurv.c:34`) |

### 4.2 JOB struct

`src/include/ngspice/trcvdefs.h:66-82`:
```c
#define TRCVNESTLEVEL 2          /* trcvdefs.h:58 — "depth of nesting of curves - 2 for spice2" */
#define TEMP_CODE 1023           /* trcvdefs.h:62-64 */

typedef struct {
    int JOBtype; JOB *JOBnextJob; char *JOBname;
    double TRCVvStart[2];        /* starting voltage/current */
    double TRCVvStop[2];         /* ending voltage/current */
    double TRCVvStep[2];         /* voltage/current step */
    double TRCVvSave[2];         /* value BEFORE analysis — restored when done */
    int    TRCVgSave[2];         /* dcGiven flag; as with vSave */
    IFuid  TRCVvName[2];         /* source being varied */
    GENinstance *TRCVvElt[2];    /* pointer to source */
    int    TRCVvType[2];         /* type of element being varied */
    int    TRCVset[2];           /* flag: this nest level used */
    int    TRCVnestLevel;        /* number of levels of nesting called for */
    int    TRCVnestState;        /* iteration state during pause */
} TRCV;
```
The struct is `tmalloc`'d, and `tmalloc` is `calloc` (`src/misc/alloc.c:52-54`,
`s = calloc(num,1)`), so every field starts at zero: `TRCVnestLevel = 0`,
`TRCVvType[] = 0`, `TRCVset[] = 0`.

### 4.3 The complete `DCTparms` table

`src/spicelib/analysis/dctsetp.c:91-102`. Parameter ids from
`src/include/ngspice/trcvdefs.h:84-95`.

| keyword | id macro | flags | description | `DCTsetParm` effect |
|---|---|---|---|---|
| `start1` | `DCT_START1` | `IF_SET\|IF_REAL` | starting voltage/current | `TRCVvStart[0]=rValue; nestLevel=MAX(0,nestLevel); set[0]=TRUE` (`:24-28`) |
| `stop1` | `DCT_STOP1` | `IF_SET\|IF_REAL` | ending voltage/current | `TRCVvStop[0]` (`:30-34`) |
| `step1` | `DCT_STEP1` | `IF_SET\|IF_REAL` | voltage/current step | `TRCVvStep[0]` (`:36-40`) |
| `start2` | `DCT_START2` | `IF_SET\|IF_REAL` | starting voltage/current | `TRCVvStart[1]; nestLevel=MAX(1,nestLevel); set[1]=TRUE` (`:42-46`) |
| `stop2` | `DCT_STOP2` | `IF_SET\|IF_REAL` | ending voltage/current | `TRCVvStop[1]` (`:48-52`) |
| `step2` | `DCT_STEP2` | `IF_SET\|IF_REAL` | voltage/current step | `TRCVvStep[1]` (`:54-58`) |
| `name1` | `DCT_NAME1` | `IF_SET\|IF_INSTANCE` | name of source to step | `TRCVvName[0]=uValue` (`:60-64`) |
| `name2` | `DCT_NAME2` | `IF_SET\|IF_INSTANCE` | name of source to step | `TRCVvName[1]=uValue` (`:66-70`) |
| `type1` | `DCT_TYPE1` | `IF_SET\|IF_INTEGER` | type of source to step | `TRCVvType[0]=iValue` (`:72-76`) |
| `type2` | `DCT_TYPE2` | `IF_SET\|IF_INTEGER` | type of source to step | `TRCVvType[1]=iValue` (`:78-82`) |

Anything else → `E_BADPARM` (`dctsetp.c:84-85`).

**`type1`/`type2` are never written by any parser in the tree** — `dot_dc()` sets only
`name*/start*/stop*/step*` (`src/spicelib/parser/inp2dot.c:304-343`). The type codes are
*discovered* at run time by `DCtrCurv` (§4.5). The parms exist for an external front end
(e.g. `libngspice` callers) that wants to bypass discovery.

**Nothing is askable.** `DCTaskQuest()` has an empty switch and always returns
`E_BADPARM` (`dctaskq.c:15-27`, note the `/* NOTREACHED */ /* TEMPORARY until cases get
added */` comment). A GUI cannot read a DC job's configuration back from the simulator;
it must own that state.

### 4.4 Card and command syntax

Netlist (`src/spicelib/parser/inp2dot.c:284-345`, header comment at `:296-297`):

```
.dc SRC1NAME Vstart1 Vstop1 Vinc1 [SRC2NAME Vstart2 Vstop2 Vinc2]
```

Exact argument order, and where each maps:

| position | token | parm keyword | code |
|---|---|---|---|
| 1 | `SRC1NAME` | `name1` | `inp2dot.c:304-309` (`INPgetTok` then `INPinsert` into the symbol table) |
| 2 | `Vstart1` | `start1` | `inp2dot.c:312-313` |
| 3 | `Vstop1` | `stop1` | `inp2dot.c:316-317` |
| 4 | `Vinc1` | `step1` | `inp2dot.c:320-323` |
| 5 | `SRC2NAME` | `name2` | `inp2dot.c:325-330` |
| 6 | `Vstart2` | `start2` | `inp2dot.c:331-334` |
| 7 | `Vstop2` | `stop2` | `inp2dot.c:335-338` |
| 8 | `Vinc2` | `step2` | `inp2dot.c:339-342` |

Values go through `INPgetValue(ckt,&line,IF_REAL,tab)`, so engineering suffixes and
`{expressions}` are accepted.

Control command: `dc` — `src/frontend/commands.c:343-346`, help
`"[.dc line args] : Do a dc analysis."`; `com_dc()` → `dosim("dc", wl)`
(`src/frontend/runcoms.c:139-143`); `if_run()` rebuilds `.dc <args>` and re-parses
(`src/frontend/spiceif.c:279-292, 362`). Same grammar.

**Only two nested sweeps are supported.** `TRCVNESTLEVEL` is 2 (`trcvdefs.h:58`) and the
parser stops after `step2`. Extra tokens are **silently ignored** — verified: `dc V1 0 1 1
V2 0 1 1 V3 0 1 1` produced 4 rows (2×2), no warning.

There is **no `.step`** in ngspice: `.step param x 1 3 1` produces
`unimplemented dot command '.step'` and aborts the run (verified;
`src/spicelib/parser/inp2dot.c:969-971`). Parametric sweeps beyond the two DC nest levels
must be scripted in `.control` with `alter`/`altermod` inside a `while`/`foreach` loop.

### 4.5 What can be swept, and how the type is discovered

`DCtrCurv()` looks up three device type codes once
(`src/spicelib/analysis/dctrcurv.c:62-64`):
```c
rcode = CKTtypelook("Resistor");
vcode = CKTtypelook("Vsource");
icode = CKTtypelook("Isource");
```
then, for each nest level `i` in `0..TRCVnestLevel`, searches **in this order**
(`dctrcurv.c:87-160`):

1. **Resistor** (`dctrcurv.c:89-106`) — matches `here->RESname == job->TRCVvName[i]`
   (pointer equality of interned `IFuid`s). Saves `RESresist`/`RESresGiven`, sets
   `TRCVvType[i] = rcode`, writes `RESresist = vStart`, `RESresGiven = 1`, then calls
   `CKTtemp(ckt)`.
2. **Voltage source** (`:108-124`) — saves `VSRCdcValue`/`VSRCdcGiven`, sets
   `TRCVvType[i] = vcode`, `VSRCdcValue = vStart`, `VSRCdcGiven = 1`.
3. **Current source** (`:126-142`) — same with `ISRCdcValue`/`ISRCdcGiven`.
4. **Temperature** (`:144-151`) — `if (cieq(job->TRCVvName[i], "temp"))`: saves
   `ckt->CKTtemp`, sets `TRCVvType[i] = TEMP_CODE` (1023), sets
   `ckt->CKTtemp = vStart + CONSTCtoK`, then `inp_evaluate_temper(ft_curckt)` and
   `CKTtemp(ckt)`.
5. Otherwise: **fatal** —
   `"DC Transfer Function: Voltage source, current source, or resistor named \"%s\" is not
   in the circuit"` via `IFerrorf(ERR_FATAL, …)` and `return E_NODEV` (`:153-157`).
   Verified: `dc Vbogus 0 1 0.5` produces exactly that line plus
   `doAnalyses: no such device` and `dc simulation(s) aborted`, and sets `$sim_status` to 1.

**So the sweepable quantities are exactly: a resistor's resistance, a voltage source's DC
value, a current source's DC value, and the circuit temperature (`temp`, case
insensitive). Model parameters and arbitrary instance parameters are NOT sweepable by
`.dc`.**

Notes for the GUI:
- The temperature sweep value is in °C on the deck and converted with `CONSTCtoK`.
- A temperature step re-evaluates `temper`-dependent parameters
  (`inp_evaluate_temper()`) and re-runs `CKTtemp()` at every point (`:466-467`) — this is
  slow and is the reason for the `FIXME` guard at `:456-464` that skips the final
  out-of-range temperature evaluation.
- A resistance step calls `RESupdate_conduct()` and re-loads the resistor model
  (`:448-452`).
- After the run, every swept element is restored to its saved value and `*Given` flag
  (`:487-503`).

### 4.6 Loop structure, point count and the "empty sweep" trap

Termination test per level (`dctrcurv.c:213-264`):
`SGN(step[i]) * (currentValue - stop[i]) > DBL_EPSILON * 1e+03`.

Nesting: level 0 is the **inner** loop, level 1 the **outer**. When the inner finishes,
`i++`, all lower levels are reset to their start values (`:266-282`), the state vectors
rotate, and the outer advances.

**Trap:** if `start > stop` with a positive step (or the reverse), the very first test
already fails and the sweep produces **zero points with no error at all**. Verified:
`dc V1 1 0 0.5` printed `No. of Data Rows : 0`, `$sim_status` 0, and left four
zero-length vectors. A GUI must validate `sgn(stop-start) == sgn(step)` itself.

A zero step is caught earlier, by the parser: `dot_dc()` returns 1 if
`parm->rValue == 0` for either increment (`inp2dot.c:320-322`, `:339-341`), and
`INP2dot()` turns that into `current->error = "Bad syntax! "` (`inp2dot.c:895-897`).
Verified: `dc V1 0 1 0` → `Error: Bad syntax! in   .dc v1 0 1 0`, `$sim_status` 1.
A missing token likewise returns 1 (`inp2dot.c:305-306, 310-311, 314-315, 318-319,
326-327, 332-333, 336-337`).

### 4.7 Convergence at each sweep point

`dctrcurv.c:297-315`:
- if `newcompat.hs` (HSPICE compatibility mode) → full `CKTop(...MODEDCTRANCURVE...,
  CKTdcMaxIter)` at every point, and any failure aborts the analysis;
- otherwise → `NIiter(ckt, ckt->CKTdcTrcvMaxIter)` first, and only on failure fall back to
  `CKTop(..., ckt->CKTdcMaxIter)`.

So `itl2`/`dcTrcvMaxIter` governs the fast path and `itl1`/`dcMaxIter` the recovery path.
The XSPICE event path is at `dctrcurv.c:318-366`.

Each accepted point calls `CKTdump(ckt, ckt->CKTtime, plot)` (`:425`) where
`ckt->CKTtime` has been overloaded to carry the **level-0 sweep value**
(`:370-378`) — that is the value that lands in the scale vector.

`SOA` checking runs per point if enabled (`:427-428`).

Pause/resume: `IFpauseTest()` at `:470-474` saves `TRCVnestState = i` and returns
`E_PAUSE`; the resume entry is `dctrcurv.c:66-76` (`if (!restart && TRCVnestState >= 0)`),
which re-opens the plot with the `666/666` "relink" magic
(`src/frontend/outitf.c:198-202`).

### 4.8 Output vectors and plot naming

Verified with `.dc V1 0 1 0.5 V2 0 1 1` on a 4-node circuit:

```
Plotname: DC transfer characteristic
Flags: real
No. Variables: 6
No. Points: 6
Variables:
        0       v(v-sweep)      voltage
        1       v(b)            voltage
        2       v(in)           voltage
        3       v(out)          voltage
        4       i(v1)           current
        5       i(v2)           current
```

- Plot name string is the job UID `"DC transfer characteristic"`
  (`src/spicelib/parser/inp2dot.c:303`); in-memory plot is `dc1`, `dc2`, …
  (`typesdef.c:71-73`, patterns `d.c.`, `dc`, `transfer` → abbrev `dc`).
- **The scale vector's name encodes the swept quantity type**
  (`dctrcurv.c:180-189`):

  | level-0 type | scale vector name | vector type from `guess_type()` |
  |---|---|---|
  | voltage source | `v-sweep` | falls through to `SV_VOLTAGE` (`outitf.c:1079-1080`) → written as **`v(v-sweep)`** in the rawfile |
  | current source | `i-sweep` | `SV_CURRENT` (`outitf.c:1045-1046`) → `i-sweep` |
  | temperature | `temp-sweep` | `SV_TEMP` (`outitf.c:1041-1042`) |
  | resistance | `res-sweep` | `SV_RES` (`outitf.c:1043-1044`) |
  | anything else | `?-sweep` | — |

  Verified all four by running: the `display` output showed
  `v-sweep : voltage`, `i-sweep : current`, `res-sweep : res-sweep`,
  `temp-sweep : temp-sweep`. Note the asymmetry: `v-sweep` gets the `v(...)` wrapper in
  the rawfile, the other three do not. A rawfile reader must not assume the scale is
  called `v-sweep`.
- **A nested sweep is flattened into a single 1-D vector.** The `dc1` plot from the 2×3
  example holds 6-long vectors with `v-sweep = 0, 0.5, 1, 0, 0.5, 1`; the outer variable
  appears as an ordinary data vector (`b = 0,0,0,1,1,1`). There is **no `Dimensions:`
  header** in the rawfile and `pl_ndims` is set to 1 (`src/frontend/outitf.c:498-499`).
  This is the single biggest gap versus Cadence ADE, which presents nested sweeps as a
  family of curves. A GUI wanting families must re-split the flat vector itself, using
  the known inner-loop length.

---

## 5. `TRANinfo` — transient, `.tran` (index 4)

### 5.1 Descriptor

`src/spicelib/analysis/transetp.c:72-87`:

| field | value |
|---|---|
| `if_analysis.name` | `"TRAN"` |
| `if_analysis.description` | `"Transient analysis"` |
| `numParms` | `NUMELEMS(TRANparms)` = 5 |
| `size` | `sizeof(TRANan)` |
| `domain` | `TIMEDOMAIN` |
| `do_ic` | `1` |
| `setParm` | `TRANsetParm` (`transetp.c:15-61`) |
| `askQuest` | `TRANaskQuest` (`src/spicelib/analysis/tranaskq.c:14-46`) |
| `an_init` | `TRANinit` (`src/spicelib/analysis/traninit.c:17-40`) |
| `an_func` | `DCtran` (`src/spicelib/analysis/dctran.c:67`) |

TRAN is the **only** analysis in this area with a non-NULL `an_init`.

### 5.2 JOB struct

`src/include/ngspice/trandefs.h:18-28`:
```c
typedef struct {
    int JOBtype; JOB *JOBnextJob; char *JOBname;
    double TRANfinalTime;   /* tstop */
    double TRANstep;        /* tstep */
    double TRANmaxStep;     /* tmax  */
    double TRANinitTime;    /* tstart */
    long   TRANmode;        /* MODEUIC or 0 */
    runDesc *TRANplot;
} TRANan;
```
Ids: `TRAN_TSTART=1, TRAN_TSTOP, TRAN_TSTEP, TRAN_TMAX, TRAN_UIC` (`trandefs.h:30-36`).

### 5.3 The complete `TRANparms` table

`src/spicelib/analysis/transetp.c:64-70`:

| keyword | id | flags | description | `TRANsetParm` effect | illegal-value behaviour |
|---|---|---|---|---|---|
| `tstart` | `TRAN_TSTART` | `IF_SET\|IF_REAL` | starting time | `TRANinitTime = rValue` (`:46`) | `rValue >= TRANfinalTime` → `errMsg = "TSTART is invalid, must be less than TSTOP."`, field forced to `0.0`, `return E_PARMVAL` (`:41-45`) |
| `tstop` | `TRAN_TSTOP` | `IF_SET\|IF_REAL` | ending time | `TRANfinalTime = rValue` (`:30`) | `rValue <= 0` → `"TSTOP is invalid, must be greater than zero."`, field forced to `1.0`, `E_PARMVAL` (`:24-29`) |
| `tstep` | `TRAN_TSTEP` | `IF_SET\|IF_REAL` | time step | `TRANstep = rValue` (`:38`) | `rValue <= 0` → `"TSTEP is invalid, must be greater than zero."`, field forced to `1.0`, `E_PARMVAL` (`:32-37`) |
| `tmax` | `TRAN_TMAX` | `IF_SET\|IF_REAL` | maximum time step | `TRANmaxStep = rValue` (`:49`) | **no validation** — `0` is legal and means "derive it" (§5.4); a negative value is accepted and will misbehave |
| `uic` | `TRAN_UIC` | `IF_SET\|IF_FLAG` | use initial conditions | `if (iValue) TRANmode \|= MODEUIC` (`:52-54`) | a zero value is a no-op; **the flag cannot be cleared once set** |

Anything else → `E_BADPARM` (`:57-58`).

`TRANaskQuest()` (`src/spicelib/analysis/tranaskq.c:14-46`) reads back all five
(`tstop`, `tstep`, `tstart`, `tmax`, and `uic` as `1`/`0` from `TRANmode & MODEUIC`) —
even though the `IFparm` entries carry no `IF_ASK` bit (see §1.3).

Note the ordering asymmetry: **`tstart` is validated against `TRANfinalTime`, so `tstop`
must be set first.** The netlist parser does set `tstop` before `tstart`
(`inp2dot.c:432-438`), but an external front end using `setAnalysisParm` directly must
respect the order.

Verified error text, exactly as printed:
```
Error: TSTEP is invalid, must be greater than zero.
in   .tran 0 20u
Error: TSTOP is invalid, must be greater than zero.
in   .tran 1u 0
Error: TSTART is invalid, must be less than TSTOP.
in   .tran 1u 10u 20u
```
each followed by `tran simulation(s) aborted` and `$sim_status = 1`.

### 5.4 Card and command syntax

Netlist (`src/spicelib/parser/inp2dot.c:410-457`, header comment at `:423`):

```
.tran Tstep Tstop <Tstart <Tmax>> <UIC>
```

- `Tstep` → `tstep`, `Tstop` → `tstop` — both via `INPgetValue(...IF_REAL...)`
  (`:430-433`), both **mandatory**.
- If more text remains, `INPevaluate` is tried for `Tstart` (`:435-438`) and, only if
  that succeeded, again for `Tmax` (`:439-443`). A non-numeric token stops the chain
  without error.
- Then, if anything remains, one token is read; `cieq(word,"uic")` sets `uic = 1`
  (`:446-450`), **anything else** gives
  `" Error: unknown parameter on .tran - ignored"` (`:452`). Verified: `tran 1u 10u foo`
  → that message plus `tran simulation(s) aborted`, `$sim_status = 1`. So despite the
  word "ignored" the run does not happen.
- **`uic` cannot be given without `tstart`/`tmax`? — no, it can**: the "tstart" parse is
  attempted with `INPevaluate`, which fails on `uic` and leaves the line intact for the
  final token loop. `.tran 1u 20u uic` works (verified, 124 rows).

Control command: `tran` — `src/frontend/commands.c:320-323`, help
`"[.tran line args] : Do a transient analysis."`; `com_tran()` → `dosim("tran", wl)`
(`src/frontend/runcoms.c:160-164`). Same grammar via the rebuilt `.tran` card.

**No `sweep` clause, no `steady`, no `stop`/`start` keywords.** No compatibility mode in
this tree rewrites `.tran`: `grep` over `src/frontend/inpcompat.c` and `inpcom.c` finds no
`.tran` handling.

### 5.5 `TRANinit()` — tstep→tmax, tmax→delmin, and `nostepsizelimit`

`src/spicelib/analysis/traninit.c:17-40`:
```c
ckt->CKTfinalTime = job->TRANfinalTime;
ckt->CKTstep      = job->TRANstep;
ckt->CKTinitTime  = job->TRANinitTime;
ckt->CKTmaxStep   = job->TRANmaxStep;

if (ckt->CKTmaxStep == 0) {
    if ((ckt->CKTstep < (ckt->CKTfinalTime - ckt->CKTinitTime)/50.0)
        && !cp_getvar("nostepsizelimit", CP_BOOL, NULL, 0))
        ckt->CKTmaxStep = ckt->CKTstep;
    else
        ckt->CKTmaxStep = (ckt->CKTfinalTime - ckt->CKTinitTime)/50.0;
}
ckt->CKTdelmin = 1e-11 * ckt->CKTmaxStep;   /* XXX */
ckt->CKTmode   = job->TRANmode;
```

This is **the** semantic answer to "what does tstep do":

- **`tstep` is not an output interval.** Its only structural role is to become the default
  `tmax` (maximum internal timestep) when `tmax` was not given, and only when it is
  smaller than `(tstop-tstart)/50`.
- `set nostepsizelimit` makes `tmax` default to `(tstop-tstart)/50` regardless.
- An explicit `tmax` (non-zero) overrides both. `tmax = 0` written explicitly is
  indistinguishable from omitting it.
- `delmin` — the timestep floor that triggers "Timestep too small" — is `1e-11 * tmax`,
  i.e. **derived from `tmax`, hence indirectly from `tstep`**.
- `an_init` runs **before** `CKTic()` (`cktdojob.c:188-191`), which is why setting
  `CKTmode = TRANmode` here is what enables the `MODEUIC` branch of `CKTic()`.

`tstep` has two further, non-structural uses:
- output-vector pre-sizing: `vlength2delta()` estimates `TSTOP/TSTEP` points
  (`src/frontend/outitf.c:1250-1255`) and the memory-requirement warning at
  `outitf.c:145-172` uses `CKTfinalTime / CKTstep`;
- it becomes the actual output grid **only** under `set interp` or `linearize` (§5.9).

`CKTminBreak` is derived at the top of `DCtran()`: `#ifdef XSPICE` →
`10.0 * CKTdelmin`, else `CKTmaxStep * 5e-5` (`src/spicelib/analysis/dctran.c:160-169`),
and only when it is still zero, i.e. when `.options minbreak` was not given.

### 5.6 What `uic` actually changes

`MODEUIC` is `0x10000l` (`src/include/ngspice/cktdefs.h:199`). Grepping the whole tree,
outside the analysis drivers it is read in exactly three places:

1. `src/spicelib/analysis/cktic.c:73-80` — under `MODEUIC`, `CKTic()` calls every
   device's `DEVsetic`. For a capacitor that is `CAPgetic()`
   (`src/spicelib/devices/cap/capgetic.c:14-36`), which, **for every capacitor that does
   not carry its own `ic=`**, copies the node-pair voltage out of `CKTrhs` into
   `CAPinitCond`. `CKTrhs` at that moment holds the `.ic` node values that `CKTic()` just
   wrote (`cktic.c:47, 70`). *This is the mechanism by which `.ic v(n)=x` plus `uic`
   reaches a capacitor.* Registered at `src/spicelib/devices/cap/capinit.c:48`
   (`.DEVsetic = CAPgetic`).
2. `src/spicelib/devices/cap/capload.c:30-51` — at `MODEUIC && MODEINITTRAN` the
   capacitor's voltage is taken from `CAPinitCond` instead of the solved node voltages.
3. `src/spicelib/devices/ind/indload.c:42-46` and `:63-71` — at
   `MODEUIC && MODEINITTRAN` the inductor flux state is set from `INDinitCond` (and the
   coupled-inductor flux from the partner's `INDinitCond`).

Plus the negative case: `src/spicelib/analysis/cktload.c:146` —
`.ic` node voltages are force-held during the transient operating point **only when
`MODEUIC` is clear**. That is the classic distinction: without `uic`, `.ic` pins nodes
during the TRANOP and is then released; with `uic`, `.ic` is instead pushed into the
storage elements' initial conditions.

`MODEINITTRAN` is set only for the first transient timepoint (`dctran.c:315`,
`optran.c:415`) and is replaced by `MODEINITFLOAT` after the first `NIiter` pass
(`src/maths/ni/niiter.c:346-349`).

**`uic` does NOT skip the operating point.** `DCtran()` calls `CKTop()` unconditionally
(`dctran.c:237-240`), passing `(CKTmode & MODEUIC) | MODETRANOP | MODEINITJCT`. What
changes is only the message and the fate of the result:
```c
} else if (ckt->CKTmode & MODEUIC && !ft_ngdebug) {
    fprintf(stdout,"Operating point simulation skipped by 'uic',\n");
    fprintf(stdout,"  now using transient initial conditions.\n");
```
(`dctran.c:247-250`). The op *is* computed; the storage elements simply ignore it at
t = 0. Verified: `tran 1u 20u uic` prints exactly those two lines and still yields 124
rows. **The message is misleading and a GUI should not repeat its wording.** Also note
the suppressed alternative: without `uic`, `DCtran` prints the
`"Initial Transient Solution"` node table (`dctran.c:251-263`) unless `ft_noacctprint ||
ft_noinitprint` (i.e. `.options noacct` / `noinit`).

### 5.7 The transient loop, and what limits/rejects a step

`DCtran()`, `src/spicelib/analysis/dctran.c:67-974`. Structure (label line numbers are in
the file's own header comment, `dctran.c:11-15`):

- **Start-up** (`:116-331`): first delta `= MIN(tstop/100, tstep)/10` (`:125`);
  breakpoint list reset to `{0, tstop}` (`:149-154`); `.stop when time = x` breakpoints
  are imported from the `dbs` database (`:206-215`); XSPICE ramp-time breakpoint (`:220-221`);
  operating point (`:224-269`); `CKTsaveDelta = tstop/50` (`:292`);
  `CKTmode = (mode&MODEUIC)|MODETRAN|MODEINITTRAN` (`:315`); `CKTdeltaOld[0..6] = tmax`
  (`:285-287`).
- **`nextTime:`** (`:355`) — `CKTaccept()`, breakpoint retirement, SOA check, output.
- **Output gate** (`:416-419`):
  ```c
  if ((ckt->CKTmode & MODEUIC && ckt->CKTtime > 0 && ckt->CKTtime >= ckt->CKTinitTime)
      || (!(ckt->CKTmode & MODEUIC) && ckt->CKTtime >= ckt->CKTinitTime))
      CKTdump(ckt, ckt->CKTtime, job->TRANplot);
  ```
  i.e. **`tstart` suppresses output, not computation** — points before `tstart` are solved
  and thrown away. Under `uic`, t = 0 itself is additionally suppressed.
- **Termination** (`:430-454`): `AlmostEqualUlps(CKTtime, CKTfinalTime, 100)` or the
  `autostop` check (`check_autostop("tran")`, enabled by `set autostop` read once at
  `:200`; `autostop` finishes the run as soon as every `.measure` condition is met and
  prints `"Note: Autostop after %e s, all measurement conditions are fulfilled."`).
- **`resume:`** (`:460`) — `CKTdelta = MIN(CKTdelta, CKTmaxStep)` (`:480`); order cut to 1
  at a breakpoint and `delta` limited to `0.1 * MIN(saveDelta, breaks[1]-breaks[0])`
  (`:489-508`); on the very first step, if `MODEUIC`, an extra breakpoint at `tstep`
  is inserted `"to reduce ringing of current in devices"` and `delta /= 10` (`:510-519`).
- **Step acceptance** (`:725-895`): non-convergence → `CKTtime -= delta`,
  `STATrejected++`, `delta /= 8`, order back to 1 (`:725-741`). Convergence → `CKTtrunc()`
  computes `newdelta`; if `newdelta > 0.9*delta` the point is accepted and the order may
  be raised to 2 (`:801-835`); otherwise the point is rejected and retried with
  `newdelta` (`:879-894`).
- **Floor** (`:899-915`): if `delta <= delmin` twice in a row →
  `errMsg = CKTtrouble(ckt, "Timestep too small")` and `return E_TIMESTEP`.

Relevant options: `trtol`/`ltereltol`/`lteabstol`/`ltetrtol` feed `CKTtrunc`;
`itl4` (`CKTtranMaxIter`) is the per-timepoint Newton limit; `maxord`/`method`/`xmu`
select the integration formula; `minbreak` merges nearby breakpoints.

### 5.8 What TRAN produces

- Reference vector: `"time"`, created with `IFnewUid(..., "time", UID_OTHER, ...)`
  (`dctran.c:180`) and passed as `refName` to `OUTpBeginPlot` (`:181-185`). `guess_type()`
  maps it to `SV_TIME` (`outitf.c:1029-1030`).
- Plot string `"Transient Analysis"` (`inp2dot.c:429`); in-memory plot `tran1`, `tran2`, …
  (`typesdef.c:68`, pattern `transient` → abbrev `tran`).
- Data vectors: the same `CKTnames()` node list as OP/DC.
- With `set ngdebug` and a `time` reference, two extra debug vectors `speedcheck` and
  `deltacheck` are added (`outitf.c:355-359`, and the save-list arms at `:318-330`).
- Progress: `" Reference value : % 12.5e\r"` every 0.25 s unless `orflag`,
  `ft_norefprint` (`.options norefvalue`) or `cp_background` (`outitf.c:706-734`).
  `"\nNo. of Data Rows : %d\n"` at end-of-plot (`outitf.c:1191` file path, `:1353` plot
  path). `"No. of Data Columns : %d"` at `outitf.c:1015`.
- With `HAS_PROGREP` (a GUI build; **not** defined in this tree — `HAS_WINGUI` and
  `TCL_MODULE` are both undefined in `build-ver_50/src/include/ngspice/config.h:44,564`)
  `SetAnalyse("tran", permille)` would drive a progress bar (`dctran.c:473-478`).

### 5.9 tstep vs. the points actually written — measured

Deck: pulse source into a 1 kΩ / 1 nF RC, `.control` running the same analysis with
different arguments; row counts read from `No. of Data Rows`.

| command | rows |
|---|---|
| `tran 1u 20u` | **125** |
| `tran 1u 20u 5u` (tstart) | **97** |
| `tran 1u 20u 0 0.2u` (tmax) | **169** |
| `tran 1u 20u uic` | **124** |
| `set interp` then `tran 1u 20u` | **21** |

21 = `20u/1u + 1`. Conclusion: by default the rawfile/plot receives **every accepted
internal timepoint**, and `tstep` is only an upper bound on the internal step. To get a
uniform `tstep` grid the user must either

- `set interp` before the run — `beginPlot()` latches it into the file-static
  `interpolated` (`outitf.c:210-214`, printing
  `"Warning: Interpolated raw file data!"`), and `OUTpData()` then routes TRAN
  (`JOBtype == 4`) points through `InterpFileAdd()` / `InterpPlotAdd()`
  (`outitf.c:682-692`). `InterpFileAdd()` walks a `timestep` cursor starting at
  `CKTinitTime + CKTstep` (`outitf.c:1803-1806`), emits `CKTinitTime` and `CKTfinalTime`
  exactly, emits exact hits, linearly interpolates when a step is overshot
  (`:1877`, `:1908`) and drops points before the cursor (`:1837-1840`); or
- run `linearize` afterwards — `com_linearize()` (`src/frontend/linear.c:24-…`) requires
  the current plot to be a `tran*` plot (`linear.c:34`), pulls `tstart/tstop/tstep` back
  out of the job with `if_tranparams()` (`linear.c:53`), and can be overridden per-plot by
  special vectors `lin-tstart`, `lin-tstop`, `lin-tstep` (`linear.c:67-80`).

`set interp` is a *global* front-end flag with a file-static latch; it affects only TRAN.

### 5.10 `optran` — the pre-transient operating-point fallback

**This is the most GUI-relevant hidden feature in this area, and it is ON by default.**

Declared in `src/spicelib/analysis/com_optran.h` (`void com_optran(wordlist *wl);` —
the whole header is four lines). Implemented in `src/spicelib/analysis/optran.c`.

Module state (`optran.c:46-51`):
```c
static double *opbreaks;  static int OPbreakSize;
static double opfinaltime = 1e-6;
static double opstepsize  = 1e-8;
static double opramptime  = 0.;
static bool   nooptran    = TRUE;
```

**Command:** `optran` — `src/frontend/commands.c:672-675`, help
`": Prepare optran by setting 6 flags "`, **min args 6, max args 6**. Verified: a 7th
word gives `optran: too many args.`

**Six positional arguments** (`optran.c:53-72` block comment, and `:114-168`):

| # | meaning | parsed by | target |
|---|---|---|---|
| 1 | `noopiter` inverted flag: `0` → `TSKnoOpIter = 1` (skip the direct Newton attempt), non-zero → `TSKnoOpIter = 0` | `strtol` | `ft_curckt->ci_defTask->TSKnoOpIter` (`:117-132`) |
| 2 | number of gmin steps | `strtol` | `TSKnumGminSteps` (`:134-142`) |
| 3 | number of source steps | `strtol` | `TSKnumSrcSteps` (`:143-152`) |
| 4 | optran step size | `INPevaluate` (suffixes OK) | static `opstepsize` (`:153-157`) |
| 5 | optran final time | `INPevaluate` | static `opfinaltime` (`:158-162`) |
| 6 | supply ramp time (may carry a trailing `uic`) | `INPevaluate` | static `opramptime` (`:163-168`) |

Documented example (`optran.c:61-64`): `optran 0 0 0 50u 10m 0`.

Validation (`optran.c:169-185`):
- `opstepsize > opfinaltime` → `"Error: Optran step size larger than final time."`, abort;
- `opstepsize > opfinaltime/50` → clamped to `opfinaltime/50` with
  `"Note: Optran step size set to %e, (stepsize = finaltime / 50)."`;
- `opramptime > opfinaltime` → `"Error: Optran ramp time larger than final time."`, abort;
- **`opstepsize == 0` deselects optran** — `nooptran = TRUE` and
  `"Note: Optran is deselected."`.
Any parse failure prints `"Error in command 'optran'"` (`:191-192`).

**Three-phase call protocol** (`optran.c:85-108`) — this is why the command behaves
differently depending on where it is written:
- called with a wordlist and **no circuit loaded** (from `spinit`, `.spiceinit`, or
  `cp_init`) → `getdata = TRUE`: only the module statics and three shadow statics
  (`opiter`, `ngminsteps`, `nsrcsteps`) are filled;
- called with `wl == NULL` and a circuit loaded and `dataset` → the shadow statics are
  pushed into `ft_curckt->ci_defTask` (`:85-91`). This is the call
  `src/frontend/inp.c:1585` makes for every netlist read;
- called with a wordlist **and** a circuit loaded (from `.control`) → writes
  `ci_defTask` directly.

**Default: optran is enabled with `1 1 1 100n 10u 0`.** `cp_init()` builds that word list
and calls `com_optran()` itself (`src/frontend/init.c:77-94`, comment: *"To make optran
the standard, call com_optran here. May be overridden by entry in spinit or .spiceinit or
a local call in .control."*). `src/spinit.in` does **not** override it (the whole file is
49 lines and mentions no `optran`).

**Where it runs:** `CKTop()` calls it after Newton, gmin stepping and source stepping have
all failed (`src/spicelib/analysis/cktop.c:94-103`):
```c
int prevconverged = converged;
converged = OPtran(ckt, converged);
if (converged == 106) fprintf(cp_err, "Error: Transient op failed, timestep too small\n\n");
else if (converged != 0 && converged != prevconverged) fprintf(cp_err, "Error: Transient op failed, cause unrecorded\n\n");
else if (converged == 0) return converged;
```
`OPtran()` returns `oldconverged` immediately if `nooptran` (`optran.c:320-321`).

**What `OPtran()` is:** a stripped transient run from t = 0 to `opfinaltime` that produces
no output vectors and keeps its own breakpoint array
(`optran.c:290-294` header comment: *"Do a simple transient simulation, starting with time
0 until opfinaltime. No output vectors are generated, actual times and breakpoints are
kept local … The code is derived from dctran.c by removing all un-needed parts."*).
It saves and restores `CKTmaxStep`/`CKTstep` around the run (`:361-363`, `:485-486`),
sets `CKTmaxStep = CKTstep = opstepsize` (`:363`), `CKTsaveDelta = opfinaltime/50`
(`:413`), and applies a raised-cosine supply ramp when `opramptime > 0`:
`ckt->CKTsrcFact = 0.5 * (1 - cos(M_PI * optime / opramptime))` (`:669-671`).
On success it emits `"Transient op finished successfully"` via `IFerrorf(ERR_INFO)`
(`:484`), preceded at entry by `"Transient op started"` (`:331`).

**The result is the transient state at `opfinaltime`, not a polished DC solution.**
Measured, with `.options noopiter gminsteps=0 srcsteps=0` on a 1 kΩ/1 nF RC (τ = 1 µs)
driven to 1 V:

| optran settings | reported `v(out)` |
|---|---|
| default `1 1 1 100n 10u 0` (10 τ) | `9.999550e-01` |
| `optran 0 0 0 50n 100u 0` (100 τ) | `1.000000e+00` |
| `optran 0 0 0 0 10u 0` (deselected) | run fails: `DC solution failed` + `CKTncDump` table |

`1 - e^-10 = 0.99995460` — the reported operating point is exactly the transient value at
`opfinaltime`. **A GUI that exposes convergence aids must expose `optran`'s final time,
because it silently sets the accuracy of every fallback operating point.**

### 5.11 The shared operating-point solver `CKTop()`

Called by `DCop` (`.op`), `DCtran` (the TRANOP), `DCtrCurv` (fallback), and the AC/noise/
distortion/SP drivers. `src/spicelib/analysis/cktop.c:26-116`, in order:

1. Unless `CKTnoOpIter` (`.options noopiter`), a direct `NIiter(ckt, iterlim)` (`:40-48`).
2. If `CKTnumGminSteps >= 1` (`:57-77`):
   - `== 1` → `dynamic_gmin()` (Gillespie, `:161-274`), and unless `set dyngmin`, on
     failure also `new_gmin()` (`:349-466`, steps the real per-model gmin);
   - `> 1` → `spice3_gmin()` (`:289-346`).
3. If `CKTnumSrcSteps >= 1` (`:85-92`): `== 1` → `gillespie_src()` (`:480-658`), `> 1` →
   `spice3_src()` (`:672-715`).
4. `OPtran()` (§5.10).
5. Failure: `"\nError: The operating point could not be simulated successfully."`, then
   `controlled_exit(1)` if `ft_stricterror`, else
   `"    Any of the following steps may fail.!"` (`:110-113`).

Each phase emits `IFerrorf(ERR_INFO)` progress lines ("Starting dynamic gmin stepping",
"One successful gmin step", "Source stepping completed", …) that a GUI can parse for a
convergence-progress display; several are gated on `ft_ngdebug` (`set ngdebug`).

### 5.12 `MODEDCOP` vs `MODETRANOP` — the real "two operating points"

| | `.op` (`DCop`) | transient op (`DCtran`) |
|---|---|---|
| mode bits | `MODEDCOP\|MODEINITJCT` → `MODEDCOP\|MODEINITFLOAT` (`dcop.c:76-79`) | `MODETRANOP\|MODEINITJCT` → `MODETRANOP\|MODEINITFLOAT` (`dctran.c:237-240`) |
| capacitors | opened (`capload.c:30` gates on `MODETRAN\|MODEAC\|MODETRANOP`, so under `MODEDCOP` the cap contributes nothing) | present in the `MODETRANOP` branch, using `MODEDC && MODEINITJCT` → `CAPinitCond` |
| `.ic` node values held? | **no** (`cktload.c:146` requires `MODETRANOP`) | **yes**, unless `uic` |
| `.nodeset` held? | yes (`cktload.c:120-145`, any `MODEDC` pass) | yes |
| leaves | `MODEDCOP\|MODEINITSMSIG` for a following small-signal analysis (`dcop.c:87`) | `MODETRAN\|MODEINITTRAN` (`dctran.c:315`) |

Both live under the `MODEDC` mask (`0x70`, `cktdefs.h:179-182`), which is what
`cktload.c:120` tests.

---

## 6. LAUNCHING A RUN, AND WHAT COMES BACK

### 6.1 The two task objects

`if_run()` (`src/frontend/spiceif.c:245-439`) distinguishes:

- **`run`** — execute the analyses that the *netlist* declared. `ci_curTask = ci_defTask`,
  `ci_curOpt = ci_defOpt` (`spiceif.c:376-378`). If `ci_curTask->jobs == NULL` it warns
  `"Warning: No job (tran, ac, op etc.) defined:"` and returns 3 unless `ft_batchmode`
  (`spiceif.c:379-385`).
- **`tran`/`dc`/`op`/`ac`/`pz`/`disto`/`sens`/`tf`/`noise`** — build a *new interactive
  task* named `"special"`: the previous one is deleted (`:295-307`), a new UID and task
  are created (`:311-328`) with `CKTnewTask`'s copy-from-default arm (§2.4), an `options`
  job is attached (`:332-356`), and the synthesised `.<what> <args>` card is pushed
  through `INPpas2()` (`:362`). A card error prints
  `"Error: %sin   %s\n\n"` and returns 2 (`:364-367`).

Both then call `ft_sim->doAnalyses(ckt, 1, ci_curTask)` (`spiceif.c:416`), i.e.
`CKTdoJob(ckt, reset=1, task)`. `resume` calls it with `reset = 0` (`:424-432`).

### 6.2 Analysis execution order is fixed by `analInfo[]` index, not by deck order

`CKTdoJob()` (`src/spicelib/analysis/cktdojob.c:177-213`):
```c
for (i = 0; i < ANALmaxnum; i++)
    for (job = task->jobs; job; job = job->JOBnextJob)
        if (job->JOBtype == i) { … an_init … CKTic … EVTsetup … an_func … }
```
with the comment `/* Analysis order is important */` (`:176`). So a deck containing
`.tran` and `.op` runs **AC (1) → DC (2) → OP (3) → TRAN (4)**, regardless of the order
the cards appear in. Errors from one job are remembered in `error2` and the loop
continues (`:209-210`), so several analyses run even if one fails.

`reset == 1` also triggers `CKTunsetup` → `CKTsetup` → `CKTtemp` (`:160-167`).

### 6.3 Front-end wrapper and status

`dosim()` (`src/frontend/runcoms.c:205-394`):
- clears the save-miss memo (`OUTsaveMissClear()`, `:226`);
- picks binary vs ASCII from `AsciiRawFile`/`$SPICE_ASCIIRAWFILE` and then the
  `filetype` variable (`:228-252`);
- refuses with `"Error: there aren't any circuits loaded."` / `"Error: circuit not
  parsed."` (`:254-261`);
- opens the rawfile for `run <file>` (`:289-312`) and remembers `last_used_rawfile`;
- `cp_vset("sim_status", CP_NUM, &err)` before and after — **`$sim_status` is the shell
  variable a GUI should poll** (`:329`, `:352`, `:358`);
- maps `if_run` returns: `1` → `"%s simulation interrupted"` (treated as success),
  `2` → `"%s simulation(s) aborted"` + `sim_status = 1`, `3` → `"%s simulation not
  started"` + `sim_status = 1` (`:343-362`);
- deletes a rawfile that ended up empty (`:365-375`);
- finally runs `do_measure(ft_curckt->ci_last_an, FALSE)` for the `.measure` cards
  (`:388-391`).

`ci_last_an` is set in `beginPlot()` from `spice_analysis_get_name(JOBtype)`
(`src/frontend/outitf.c:226-227`), i.e. `"OP"`, `"DC"`, `"TRAN"`.

Process exit status is a separate concern documented in
`doc/codex/issues/0069-batch-exit-status-reports-the-last-thing-main-did.md` and
`doc/codex/issues/0072-an-op-dot-card-with-no-netlist-aborts-on-an-assertion.md`, with
regression decks in `tests/regression/exitstatus/`.

CLI switches relevant to launching (`src/main.c:951-970`, help text at `:735-760`):
`-b/--batch`, `-a/--autorun`, `-r/--rawfile=FILE`, `-o/--output=FILE`, `-n/--no-spiceinit`,
`-p/--pipe`, `-s/--server`, `-i/--interactive`, `-D/--define=var[=value]`,
`--soa-log=FILE`.

### 6.4 Choosing what is saved

`beginPlot()` (`src/frontend/outitf.c:179-525`) builds the column list:
- with no `save` entries, everything from `CKTnames()` except a filtered set: subcircuit
  nodes if `nosub`, `#`-internal names if `nointernals` (but `#branch` survives),
  `probe_int_*`, and the internal device nodes `#internal`, `#source`, `#drain`,
  `#collector`, `#collCX`, `#emitter`, `#base` (`outitf.c:334-354`);
- `save all`/`allv`, `alli`, `nosub`, `nointernals` are recognised tokens
  (`outitf.c:245-275`); `alli` converts internal device nodes into terminal-current
  specials `@dev[ic]`, `@dev[ib]`, `@dev[ie]`, `@dev[is]`, `@dev[id]`, `@dev[ig]`
  (`outitf.c:366-420`);
- **saves can be scoped per analysis**: `saves[i].analysis` is compared with `an_name`
  using `cieq` (`outitf.c:239-243`). `com_save2(wl, name)` sets that scope
  (`src/frontend/breakp2.c:41-45`). `ft_savedotargs()` derives it: `.print`/`.plot`'s
  second token becomes the analysis name, `.four` maps to `"TRAN"`, `.op` maps to `"OP"`,
  `.tf` maps to `"TF"` (`src/frontend/dotcards.c:107-160`);
- device/model parameter specials `@dev[param]` are parsed by `parseSpecial()` and added
  as `addSpecialDesc()` (`outitf.c:423-468`);
- if the result is empty, `"Error: no data saved for %s; analysis not run"` with the
  analysis *description* string (`outitf.c:479-486`).

`.save` cards are collected by `ft_dotsaves()` (`dotcards.c:57-76`) into the `dbs`
database via `com_save()` (`src/frontend/breakp2.c:33-37`, `settrace()` at `:48-121`).

SOA (safe-operating-area) checking is enabled by the shell variable `set warn=1|2` with
`set maxwarns=N` (`src/frontend/inp.c:1446-1455`), runs per point in `DCop`
(`dcop.c:56-58, 117-118`), `DCtrCurv` (`dctrcurv.c:202-203, 427-428`) and `DCtran`
(`dctran.c:190-191, 379-380`), and is logged to `--soa-log=FILE` (`src/main.c:1101-1164`).

---

## 7. DEFAULTS — CONSOLIDATED, WITH THE LINE THAT SETS THEM

| quantity | default | set at |
|---|---|---|
| `gmin` | `1e-12` | `cktntask.c:93` |
| `gshunt` | `0` | `cktntask.c:94` |
| `cshunt` | `-1` | `cktntask.c:95` |
| `abstol` | `1e-12` | `cktntask.c:96` |
| `reltol` | `1e-3` | `cktntask.c:97` |
| `chgtol` | `1e-14` | `cktntask.c:98` |
| `vntol` | `1e-6` | `cktntask.c:99` |
| `ltereltol` | `1e-3` | `cktntask.c:100` |
| `lteabstol` | `1e-6` | `cktntask.c:101` |
| `ltetrtol` | `500.` | `cktntask.c:102` |
| `newtrunc` | `0` | `cktntask.c:103` |
| `trtol` | `7.` | `cktntask.c:104` (forced to `1` with XSPICE A-devices, `cktdojob.c:81-90`) |
| `bypass` | `0` | `cktntask.c:105` |
| `itl4` (`tranMaxIter`) | `10` | `cktntask.c:106` |
| `itl1` (`dcMaxIter`) | `100` | `cktntask.c:107` |
| `itl2` (`dcTrcvMaxIter`) | `50` | `cktntask.c:108` |
| `method` | `TRAPEZOIDAL` | `cktntask.c:109` |
| `maxord` | `2` | `cktntask.c:110` |
| `indverbosity` | `2` | `cktntask.c:112` |
| `xmu` | `0.5` | `cktntask.c:119` |
| `srcsteps` | `1` | `cktntask.c:120` |
| `gminsteps` | `1` | `cktntask.c:121` |
| `gminfactor` | `10` | `cktntask.c:122` |
| `pivtol` | `1e-13` | `cktntask.c:123` |
| `pivrel` | `1e-3` | `cktntask.c:124` |
| `temp` | `300.15` K (27 °C) | `cktntask.c:125` |
| `tnom` | `300.15` K (27 °C) | `cktntask.c:126` |
| `defm` | `1` | `cktntask.c:127` |
| `defl`, `defw` | `1e-4` | `cktntask.c:128-129` |
| `defad`, `defas` | `0` | `cktntask.c:130-131` |
| `noopiter` | `0` | `cktntask.c:132` (but see optran below) |
| `trytocompact`, `badmos3`, `keepopinfo`, `copynodesets`, `nodedamping` | `0` | `cktntask.c:133-137` |
| `absdv` | `0.5` | `cktntask.c:138` |
| `reldv` | `2.0` | `cktntask.c:139` |
| `epsmin` | `1e-28` | `cktntask.c:140` |
| KLU mode | `CKTkluOFF` (i.e. Sparse 1.3) | `cktntask.c:143` — verified by the banner `Using SPARSE 1.3 as Direct Linear Solver` |
| `klu_memgrow_factor` | `1.2` | `cktntask.c:144` |
| `minbreak` | `0`, then `10*delmin` (XSPICE) or `maxStep*5e-5` | `dctran.c:160-169`; `optran.c:424`; `dctran.c:339-340` (resume) |
| `delmin` | `1e-11 * CKTmaxStep` | `traninit.c:36` |
| TRAN `tmax` | `tstep` if `tstep < (tstop-tstart)/50`, else `(tstop-tstart)/50` | `traninit.c:29-34` |
| TRAN first `delta` | `MIN(tstop/100, tstep)/10` | `dctran.c:125` |
| `CKTsaveDelta` | `tstop/50` | `dctran.c:292` |
| DC `TRCVnestLevel` | `0` (from `tmalloc`=calloc) | `cktnewan.c:30`, `alloc.c:52-54` |
| optran enabled | **yes**, `1 1 1 100n 10u 0` | `src/frontend/init.c:80-94` |
| optran `opfinaltime` | `1e-6` static, overwritten to `10u` by the default call | `optran.c:48`, `init.c:88` |
| optran `opstepsize` | `1e-8` static, overwritten to `100n` | `optran.c:49`, `init.c:87` |
| optran `opramptime` | `0.` | `optran.c:50`, `init.c:89` |
| `maxwarns` (SOA) | `5` | `src/frontend/inp.c:1455` |

---

## 8. ILLEGAL VALUES — WHAT ACTUALLY HAPPENS

| input | result | anchor / verification |
|---|---|---|
| `.tran 0 20u` (tstep = 0) | `Error: TSTEP is invalid, must be greater than zero.` + card echo + `tran simulation(s) aborted`, `$sim_status=1` | `transetp.c:32-37`; run |
| `.tran 1u 0` (tstop = 0) | `Error: TSTOP is invalid, must be greater than zero.` + abort | `transetp.c:24-29`; run |
| `.tran 1u 10u 20u` (tstart ≥ tstop) | `Error: TSTART is invalid, must be less than TSTOP.` + abort | `transetp.c:41-45`; run |
| `.tran 1u 10u 5u 0` (tmax = 0) | accepted; tmax derived | `traninit.c:29-34`; run gave 51 rows |
| `.tran 1u 10u foo` | `Error:  Error: unknown parameter on .tran - ignored` + abort | `inp2dot.c:451-453`; run |
| `.dc V1 0 1 0` (step = 0) | `Error: Bad syntax! in   .dc v1 0 1 0` + abort | `inp2dot.c:320-322`, `:895-897`; run |
| `.dc V1 0 1` (missing token) | `Error: Bad syntax!` + abort | `inp2dot.c:318-319`; run |
| `.dc V1 1 0 0.5` (start > stop, +step) | **silent, zero rows**, `$sim_status = 0` | `dctrcurv.c:213-225`; run |
| `.dc Vbogus 0 1 0.5` | `Fatal error: DC Transfer Function: Voltage source, current source, or resistor named "vbogus" is not in the circuit` + `doAnalyses: no such device` + abort | `dctrcurv.c:153-157`; run |
| `.dc a 0 1 1 b 0 1 1 c 0 1 1` | third triple silently dropped (4 rows) | `inp2dot.c:324-343`; run |
| `.options maxord=0` | clamped to 1 + `Warning -- Option maxord < 1 not allowed in ngspice` on stderr | `cktsopt.c:126-129` |
| `.options maxord=9` | clamped to 6 + warning | `cktsopt.c:130-133` |
| `.options method=xyz` | `E_METHOD` → `Warning:  can't set option method` | `cktsopt.c:146`, `inpdoopt.c:64-67` |
| `option maxord=2` (shell) | `Warning: option maxord is currently unsupported.` | `spiceif.c:446-453, 512-516` |
| `.options newtrunc` | `Warning: Option 'newtrunc' ignored, compilation with preprocessor flag 'PREDICTOR' is required.` (this tree) | `cktsopt.c:199-207` |
| `.options rshunt=1e-40` | `WARNING - Rshunt option too small.  Ignored.` | `cktsopt.c:249-251` |
| `.options bogus=1` | `Error: unknown option bogus - ignored` on `cp_err` (unless the token is purely numeric, then silent) | `inpdoopt.c:70-78` |
| `optran <7 args>` | `optran: too many args.` | `commands.c:673` (min 6 max 6); run |
| `optran 0 0 0 0 10u 0` | `Note: Optran is deselected.` — and with `noopiter gminsteps=0 srcsteps=0` the op then fails outright | `optran.c:181-185`; run |
| `optran … stepsize > finaltime` | `Error: Optran step size larger than final time.` then `Error in command 'optran'` | `optran.c:169-172` |
| `.step …` | `unimplemented dot command '.step'` + `Simulation interrupted due to error!` | `inp2dot.c:969-971`; run |

---

## 9. BUILD GATING IN THIS TREE

Read from `build-ver_50/src/include/ngspice/config.h` (a bare `../configure`):

| macro | state here | configure flag | default upstream |
|---|---|---|---|
| `XSPICE` | **defined** (`config.h:579`) | `--disable-xspice` | **on** |
| `OSDI` | defined (`config.h:502`) | `--disable-osdi` | on |
| `KLU` | **defined** (`config.h:463`) | `--disable-klu` | on (`configure.ac:300-306`) |
| `RFSPICE` | **defined** (`config.h:535`) | `--disable-sp` | on (`configure.ac:1221-1228`) |
| `CIDER` | undefined (`config.h:11`) | `--enable-cider` | off |
| `WITH_PSS` | undefined (`config.h:576`) | `--enable-pss` | off (`configure.ac:1235`) |
| `WANT_SENSE2` | undefined (no entry) | `--enable-sense2` | off (`configure.ac:1236`) |
| `PREDICTOR` | undefined (`config.h:529`) | — | off |
| `SHARED_MODULE` | undefined (`config.h:550`) | `--with-ngshared` | off |
| `HAS_WINGUI` | undefined (`config.h:44`) | Windows GUI build | off |
| `TCL_MODULE` | undefined (`config.h:564`) | `--with-tcl` | off |
| `HAS_PROGREP` | undefined (no entry) | implied by GUI builds | off |
| `NGDEBUG` | undefined (`config.h:475`) | `--enable-debug` | off |

Consequences for this area:
- The nine XSPICE `.options` keywords in §2.2 **are** available here.
- The three KLU keywords (`sparse`, `klu`, `klu_memgrow_factor`) **are** available, but
  the solver defaults to Sparse 1.3.
- `newtrunc` is inert (needs `PREDICTOR`).
- `SEN2info`/`PSSinfo` are absent, so `SPinfo` sits at index 10.
- `HAS_PROGREP` being off means `SetAnalyse()` progress callbacks
  (`dctran.c:473-478`, `dctrcurv.c:476-481`, `optran.c:492-495`, `cktop.c:32-36`) compile
  out. A GUI driving this binary must parse the `Reference value :` / `No. of Data Rows`
  text or use `libngspice`'s callbacks instead.
- Anything touching `libngspice` (`--with-ngshared`, `SHARED_MODULE`) changes the TRAN
  loop materially — `sharedsync()` and the `chkStep` label
  (`dctran.c:939-970`) exist only there.

---

## 10. GAPS AND OPEN QUESTIONS

1. **No official manual in this tree.** `doc/` holds only `doc/claude/` and `doc/codex/`;
   `man/man1/ngspice.1` contains no `.tran`/`.dc`/`.op` text. Every claim above is from
   source or from running the binary. Where the plan needs a documented statement (e.g.
   the manual's wording that `tstep` is "the suggested computing increment"), it must be
   fetched from <https://ngspice.sourceforge.io/docs/ngspice-manual.pdf> and cross-checked
   against §5.5 — I could not verify manual page numbers from here.
2. **`.options defas` is broken** (`cktsopt.c:111-113` writes `TSKdefaultMosAD`). Not
   confirmed against upstream — someone should check whether this is fixed in
   `pre-master-47` before the GUI advertises the option.
3. **`klu_memgrow_factor` is broken** (`cktsopt.c:187` assigns a comparison). Same caveat.
4. **`TSKfixLimit` (`oldlimit`) is not copied into the interactive "special" task**
   (`cktntask.c:68` shows the omission as a bare comment). I did not measure the
   consequence; a GUI that always emits `.control` commands rather than dot cards may
   silently lose `oldlimit`.
5. **`.ic` semantics under `uic` for non-cap/ind devices** — I traced `CAPgetic` and the
   inductor path; the full list of devices implementing `DEVsetic` is long
   (`grep -rl setic src/spicelib/devices/` returns ~30 files) and I did not audit each.
6. **`res-sweep`/`temp-sweep` rawfile round-trip** — I confirmed the in-memory vector type
   but did not verify how `load`/`raw_write` re-types those vectors on read-back.
7. **XSPICE event data in DC/TRAN plots** — `EVTdump`/`EVTop_save` write a parallel event
   stream; I did not characterise the event-node vector naming. That belongs to the XSPICE
   agent's area.
8. **`autostop`** interacts with `.measure`; the exact set of measurement types that can
   terminate a run lives in `src/frontend/com_measure2.c` and was not audited here.
9. Whether any of the recent `ver_50` work (`ccebdf2a2` and its neighbours) changes the
   exit-status semantics a GUI should rely on — read
   `doc/codex/issues/0069-*.md` and `0072-*.md` before designing the launch/status logic.

---

## 11. IMPLICATIONS FOR THE ASE-L GUI

1. **The analysis picker has four entries in this area, not five, and `options` is not one
   of them.** `options` is a global per-run settings sheet shared by every analysis; model
   it as a separate "Simulator options" dialog, not as an analysis. `OP` has *zero*
   parameters, so its row in a Cadence-style "Analyses" table is just a checkbox — the
   whole configuration surface for an operating point is the options sheet plus `optran`.
2. **Nothing about a DC job can be read back from the simulator** (`DCTaskQuest` always
   fails) and neither can an OP job (`DCOaskQuest` always fails); only TRAN answers
   (`tstart/tstop/tstep/tmax/uic`). The GUI must be the authoritative store for analysis
   settings and re-emit them, never round-trip them through ngspice.
3. **`tstep` must be presented honestly.** Label it "maximum/suggested internal step",
   not "output step". If the user wants a uniform output grid — which is what ADE users
   expect — the GUI must emit `set interp` before the run (or run `linearize` after) and
   say so. Measured: 125 raw points vs 21 interpolated for the same `tran 1u 20u`.
4. **`optran` is on by default and silently determines the accuracy of any fallback
   operating point.** A GUI aiming to beat ADE should surface it as a first-class
   "convergence aid" panel with the six fields (`noopiter`, gmin steps, source steps, op
   step size, op final time, ramp time), show that the answer is the transient state at
   `opfinaltime`, and warn when `opfinaltime` is short relative to the circuit's slowest
   time constant. The default `10u` gave a 4.5e-5 relative error on a 1 µs RC.
5. **Nested DC sweeps come back flattened into one 1-D vector with no `Dimensions:`
   header.** To draw the family of curves ADE draws, the GUI has to re-split the flat
   result using the inner-loop point count it computed itself — and it must handle the
   inner count varying if floating-point accumulation lands differently. This is the
   single largest piece of value-add available in this area.
6. **Validate the sweep direction client-side.** `start > stop` with a positive step
   produces zero rows, exit status 0 and no message at all. Likewise validate that the
   sweep target is a `V`, `I` or `R` instance or the literal `temp` — anything else is a
   run-time fatal, not a parse error, so the user only finds out after pressing Run.
7. **`.dc` supports exactly two nest levels and ngspice has no `.step`.** Anything beyond
   that — a parameter sweep, a Monte Carlo, a corner run — must be generated by the GUI as
   a `.control` loop with `alter`/`altermod`, with the GUI owning result collection and
   plot naming. Plan for that generator now; it is the other half of ADE parity.
8. **Emit options as `.options` cards, not as `option` shell commands**, because
   `maxord` and `method` are accepted only on the card (`spiceif.c:446-453`), and because
   `.options` reaches both the front-end flag path and the task path
   (`inp.c:1376-1397` and `inp2dot.c:949-953`). Conversely, `acct`, `noacct`, `noinit`,
   `norefvalue`, `list`, `node`, `opts`, `nopage`, `nomod` are front-end output flags, not
   simulator parameters — group them under "Output/log" in the UI, not under "Tolerances".
9. **Result identification:** plot names are `op<N>`, `dc<N>`, `tran<N>`
   (`typesdef.c:67-90`); rawfile `Plotname:` strings are `Operating Point`,
   `DC transfer characteristic`, `Transient Analysis` (`inp2dot.c:141, 303, 429`). The DC
   scale vector is one of `v-sweep`/`i-sweep`/`res-sweep`/`temp-sweep`/`?-sweep` and only
   `v-sweep` gets a `v(...)` wrapper in the rawfile. A results browser must key off the
   plot typename, not the scale-vector name.
10. **Analyses in one deck run in registry order (AC → DC → OP → TRAN), not deck order**
    (`cktdojob.c:176-213`). If the GUI lets a user enable several analyses at once, it must
    either present them in that order or issue them as separate `.control` commands.

