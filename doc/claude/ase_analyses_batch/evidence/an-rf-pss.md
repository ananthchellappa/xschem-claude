# Dossier: build-gated advanced analyses — SP (S-parameter / RFSPICE), PSS (periodic steady state), HB remnant

Tree: `/home/analog/dev/ngspice`, branch `ver_50`, `git describe = ngspice-46-419-gccebdf2a2`.
Built tree probed: `/home/analog/dev/ngspice/build-ver_50`, binary `/home/analog/dev/ngspice/build-ver_50/src/ngspice`
(`ngspice-46+`, Creation Date `Thu Sep  3 06:46:24 UTC 2026`, KLU solver).
All "measured" outputs below were produced by running that binary read-only on scratch decks under
`/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/sp/`.

There is **no ngspice manual source in this repo** (`doc/` contains only `doc/claude/` and `doc/codex/`).
Where I cite documentation it is the upstream manual URL that the binary itself prints
(<https://ngspice.sourceforge.io/docs/ngspice-manual.pdf>), and I mark it as unverified-against-source.
Everything else is anchored to `file:LINE` in this tree.

---

## 0. Executive summary for the GUI author

| Analysis | Symbol | Configure flag | Default in THIS tree | Compiled here? |
|---|---|---|---|---|
| SP (S-parameters) | `RFSPICE` | `--disable-sp` | **ON** | **YES** |
| PSS | `WITH_PSS` | `--enable-pss` | **OFF** | **NO** |
| HB (harmonic balance) | `WITH_HB` | *(no flag exists)* | **never definable by configure** | **NO — and cannot be built** |

- SP is fully usable here and is the only one of the three you can build a GUI panel against with confidence.
- PSS exists as source but is not compiled in this tree, is marked "(experimental)" by its own configure help
  string, and has at least one argument (`oscnode`) that is **required syntactically but never used**.
- HB is a copy-pasted stub with **no implementation at all**; see §4.

---

## 1. Build gating — exact facts from `configure.ac`

### 1.1 The flag declarations

```
configure.ac:153-155
# --enable-pss: enable PSS Analysis
AC_ARG_ENABLE([pss],
    [AS_HELP_STRING([--enable-pss], [Enable PSS Analysis, (experimental)])])

configure.ac:157-159
# --disable-sp: disable S Parameter Analysis
AC_ARG_ENABLE([sp],
    [AS_HELP_STRING([--disable-sp], [Disable S parameter Analysis])])
```

### 1.2 What each flag actually defines

PSS — `configure.ac:1082-1085`:

```c
if test "x$enable_pss" = xyes; then
    AC_DEFINE([WITH_PSS], [], [Define if you want PSS analysis])
    AC_MSG_RESULT([WARNING: PSS analysis enabled])
fi
```

The test is `= xyes`, so the **absence** of the variable leaves `WITH_PSS` undefined.
**PSS is OFF by default.** Confirmed.

SP — `configure.ac:1221-1229`:

```c
if test "x$enable_sp" = xno; then
    AC_MSG_RESULT([S parameter analysis disabled])
    has_sp=false
else
    AC_MSG_RESULT([S parameter analysis enabled])
    AC_DEFINE([RFSPICE], [1], [S parameter analysis])
    has_sp=true
fi
```

The test is `= xno`, so absence takes the `else` branch. **SP is ON by default.** Confirmed.

Automake conditionals that gate which `.c` files are compiled:
- `configure.ac:1231` — `AM_CONDITIONAL([SP_WANTED], [test "x$has_sp" = xtrue])`
- `configure.ac:1235` — `AM_CONDITIONAL([PSS_WANTED], [test "x$enable_pss" = xyes])`

`src/spicelib/analysis/Makefile.am:99-112`:

```
if PSS_WANTED
libckt_la_SOURCES += dcpss.c pssaskq.c pssinit.c psssetp.c
endif

if SP_WANTED
libckt_la_SOURCES += cktspdum.c span.c spaskq.c spsetp.c
endif
```

### 1.3 What this tree's build actually has

`build-ver_50/src/include/ngspice/config.h`:
- line 535: `#define RFSPICE 1`
- line 576: `/* #undef WITH_PSS */`
- line 501-502: `#define OSDI 1`
- line 578-579: `#define XSPICE 1`
- line 10-11: `/* #undef CIDER */`

So the reference build here is **SP on, PSS off, XSPICE on, OSDI on, CIDER off**.

### 1.4 `WITH_HB` is not a configure flag at all

`grep -rn WITH_HB` over `configure.ac`, the generated `configure`, and
`src/include/ngspice/config.h.in` returns **nothing** (exit 1). There is no `AC_ARG_ENABLE([hb])`,
no `AC_DEFINE([WITH_HB], …)`, and no `#undef WITH_HB` template line. `WITH_HB` can only be
introduced by hand (e.g. `CPPFLAGS=-DWITH_HB`), and doing so does not produce a working build — see §4.

### 1.5 Knock-on gating: the `portnum`/`z0` device parameters vanish without RFSPICE

`--disable-sp` does not merely drop the analysis. The VSRC port parameters themselves are inside
`#ifdef RFSPICE` (`src/spicelib/devices/vsrc/vsrc.c:31-37`), so on a no-SP build a deck line
`V1 in 0 portnum 1 z0 50` fails at parse time with
`unknown parameter (portnum)` (`src/spicelib/parser/inpdpar.c:131`).
A GUI that emits a port-style source must therefore know whether the target binary has SP **before**
netlisting, not only before running.

`wrs2p` (the Touchstone writer command) is **not** gated — `src/frontend/commands.c:224` sits outside any
`#ifdef` (verified: the only preprocessor directives between lines 110 and 232 are the `TCL_MODULE`
block at 168/177/182). So the presence of `wrs2p` is **not** a valid SP probe.

---

## 2. SP — S-parameter analysis (RFSPICE)

Author line: `src/spicelib/analysis/span.c:1-5` — "Alessio Cacciatori 2021".
Introduced in ngspice-37 (`NEWS:345` — "Add S parameter simulation (command '.sp').").
Touchstone *reading* came later, ngspice-41 (`NEWS:215`).

### 2.1 Registration and analysis identity

`src/spicelib/analysis/spsetp.c:101-116`:

```c
SPICEanalysis SPinfo  = {
    { "SP", "S-Parameters analysis", NUMELEMS(SPparms), SPparms },
    sizeof(SPAN),
    FREQUENCYDOMAIN,   /* domain, see jobdefs.h:19-24 */
    1,                 /* do_ic -> CKTic() runs before SPan */
    SPsetParm,
    SPaskQuest,
    NULL,              /* an_init == NULL */
    SPan
};
```

- Analysis **name** (used by `.save <analysis> …` filtering, `ft_find_analysis`): `"SP"`.
- Analysis **description** (printed in "Error: no data saved for %s"): `"S-Parameters analysis"`.
- Registered in `src/spicelib/analysis/analysis.c:52-58` inside `#ifdef RFSPICE`, **last** in `analInfo[]`.

`src/spicelib/analysis/cktdojob.c:176-211` runs jobs in `analInfo[]` index order and comments
"Analysis order is important". With this tree's flags the order is:

`0 OPT, 1 AC, 2 DCT, 3 DCO, 4 TRAN, 5 PZ, 6 TF, 7 DISTO, 8 NOISE, 9 SENS, 10 SP`

so a deck holding both `.ac` and `.sp` runs **AC first, SP last**, regardless of card order.

### 2.2 The IFparm table (complete)

`src/spicelib/analysis/spsetp.c:91-99`:

| keyword | id (`spardefs.h:41-49`) | flags | description string | type | unit |
|---|---|---|---|---|---|
| `start` | `SP_START` | `IF_SET\|IF_ASK\|IF_REAL` | "starting frequency" | double | Hz |
| `stop` | `SP_STOP` | `IF_SET\|IF_ASK\|IF_REAL` | "ending frequency" | double | Hz |
| `numsteps` | `SP_STEPS` | `IF_SET\|IF_ASK\|IF_INTEGER` | "number of frequencies" | int | points (see §2.4) |
| `dec` | `SP_DEC` | `IF_SET\|IF_FLAG` | "step by decades" | flag | — |
| `oct` | `SP_OCT` | `IF_SET\|IF_FLAG` | "step by octaves" | flag | — |
| `lin` | `SP_LIN` | `IF_SET\|IF_FLAG` | "step linearly" | flag | — |
| `donoise` | `SP_DONOISE` | `IF_SET\|IF_FLAG\|IF_INTEGER` | "do SP noise" | int (0/1) | — |

Note `dec`/`oct`/`lin` carry `IF_SET` only (no `IF_ASK`) in the flags word, yet `SPaskQuest`
(`spaskq.c:38-60`) does answer them. `donoise` is the odd one out: it is both `IF_FLAG` and
`IF_INTEGER`, and `SPsetParm` reads `value->iValue` and tests `== 1` exactly
(`spsetp.c:80-82`), so `donoise 2` is treated as **false**.

The job struct — `src/include/ngspice/spardefs.h:14-30`:

```c
typedef struct {
    int JOBtype; JOB *JOBnextJob; char *JOBname;
    double SPstartFreq;
    double SPstopFreq;
    double SPfreqDelta;   /* multiplier for dec/oct, step for linear */
    double SPsaveFreq;    /* resume point after Ctrl-C */
    int SPstepType;       /* DECADE=1, OCTAVE=2, LINEAR=3 */
    int SPnumberSteps;
    unsigned SPdoNoise : 1;
    int SPnoiseInput;     /* declared, never written or read anywhere */
    int SPnoiseOutput;    /* declared, never written or read anywhere */
} SPAN;
```

`SPnoiseInput` / `SPnoiseOutput` are dead fields — nothing in the tree assigns or reads them.
There is **no** way to name a noise input/output for SP the way `.noise` does.

**Defaults**: none are set anywhere. `CKTnewAnal` allocates the job with `tmalloc`
(`src/spicelib/analysis/cktnewan.c:30`), and `tmalloc` is `calloc(num,1)`
(`src/misc/alloc.c:70`), so every field starts at 0. The card parser fills them positionally, so
"the default" is whatever the card supplies. The one derived value is `SPfreqDelta`, computed in
`span.c:399-431` from the step type (see §2.4). `SPnumberSteps < 1` is silently forced to 1
(`span.c:396-397`).

### 2.3 Card and command syntax

**Dot card** — `src/spicelib/parser/inp2dot.c:718-750` (`dot_sp`), dispatched at `inp2dot.c:912-917`:

```
.sp {DEC|OCT|LIN} <numsteps> <fstart> <fstop> [<donoise>]
```

Order in the parser is exactly: step-type token → `numsteps` (int) → `start` (real) →
`stop` (real) → `donoise` (int). The stale comment at `inp2dot.c:730` says
`/* .ac {DEC OCT LIN} NP FSTART FSTOP */` — it is copied from `dot_ac` and omits `donoise`;
trust the code.

`donoise` is **optional**: omitting it leaves `SPdoNoise` at its zeroed 0.
Measured: `.sp lin 3 1e8 1e9` runs and produces S/Y/Z only, no Cy/NF vectors.

**Control command** — `src/frontend/runcoms.c:196-203` (`com_sp` → `dosim("sp", wl)`),
registered at `src/frontend/commands.c:332-338`:

```
sp {DEC|OCT|LIN} <numsteps> <fstart> <fstop> [<donoise>]
```

`dosim` prefixes a `.` and re-parses through the same `dot_sp`
(`src/frontend/spiceif.c:257-292`, the `eq(what,"sp")` arm at `spiceif.c:271-276`), so the
control-language form and the dot-card form are byte-identical in behaviour.
The command's registered help string (`commands.c:337`) is
`"[.sp line args] : Do an S-parameter analysis."`.

There is a third, dead path: `src/frontend/shyu.c:320-358` handles `sp` inside `if_sens_run`
(the `.sens` machinery). It is unreachable for normal `sp` invocations.

**Note on `sp` in the nutmeg-only command table**: `nutcp_coms[]` (`commands.c:694`) contains a
`pss` entry (`commands.c:837-844`) but **no** `sp` entry. So in the standalone `nutmeg` binary
`sp` is not a command at all, even in an RFSPICE build.

### 2.4 Sweep semantics and the frequency loop

`span.c:399-431`:

- `DECADE` (`dec`): `SPfreqDelta = exp(log(10)/numsteps)` — `numsteps` is **points per decade**.
  Requires `start > 0`, else `ERROR: AC startfreq <= 0` and `E_PARMVAL` (`span.c:402-405`).
- `OCTAVE` (`oct`): `SPfreqDelta = exp(log(2)/numsteps)` — points per octave.
  Same `start > 0` requirement (`span.c:410-413`).
- `LINEAR` (`lin`): if `numsteps-1 > 1`, `SPfreqDelta = (stop-start)/(numsteps-1)`, i.e. `numsteps`
  is the **total** number of points; if `numsteps <= 2`, `SPfreqDelta = 0` and the loop runs once
  (`span.c:417-427`, "Patch from: Richard McRoberts … a linear step with only one point").
- Anything else → `E_BADPARM` (`span.c:429-430`).

Loop bound: `while (freq <= job->SPstopFreq + freqTol)` (`span.c:652`) where
`freqTol = SPfreqDelta * SPstopFreq * CKTreltol` for dec/oct and
`SPfreqDelta * CKTreltol` for linear (`span.c:585-596`). So `.options reltol` shifts whether the
last point lands.

Measured point counts:
- `sp lin 3 1e8 1e9` → `No. of Data Rows : 3`
- `sp oct 2 1e8 8e8` → 7 rows (1e8, 1.414e8, 2e8, 2.828e8, 4e8, 5.657e8, 8e8)
- `sp dec 100 1 1e6 0` → `No. of Data Rows : 601`

Non-linear sweeps get `OUT_SCALE_LOG` on the plot (`span.c:567-569`), which is why `display`
reports `frequency … grid = xlog` for a `dec` sweep and no grid note for `lin`.

Progress reporting: `SetAnalyse("sp", …)` under `#ifdef HAS_PROGREP`
(`span.c:915-927` and `span.c:934-940`) — a Windows-GUI-only progress hook.

### 2.5 What a port *is* in ngspice terms

**A port is an independent voltage source (`V…`) that carries a `portnum` parameter.**
There is no dedicated port device and no port model.

Parameters, `src/spicelib/devices/vsrc/vsrc.c:31-37` (all `IOP`, i.e. settable and askable):

| keyword | id | declared type | meaning | default | where default is set |
|---|---|---|---|---|---|
| `portnum` | `VSRC_PORTNUM` | `IF_INTEGER` | "Port index" — 1-based | none; **this is what makes it a port** | — |
| `z0` | `VSRC_PORTZ0` | `IF_REAL` | "Port impedance" (Ω) | **50** | `vsrctemp.c:76-77` (and again `vsrcpar.c:347-351`) |
| `pwr` | `VSRC_PORTPWR` | `IF_REAL` | "Port Power" (W) | **0.001 W (0 dBm)** | `vsrctemp.c:88-89` |
| `freq` | `VSRC_PORTFREQ` | `IF_REAL` | "Port frequency" (Hz) | **1e9** | `vsrctemp.c:86-87` |
| `phase` | `VSRC_PORTPHASE` | `IF_REAL` | "Phase of the source" (deg) | **0.0** | `vsrctemp.c:90-91` |

Syntax is the ordinary `keyword value` device-parameter form handled generically by
`INPdevParse` (`src/spicelib/parser/inpdpar.c:107-160`) — the `V` card parser
(`src/spicelib/parser/inp2v.c:55`) just delegates. So:

```
V1 in 0 dc 0 ac 1 portnum 1 z0 100 pwr 0.001 freq 2.3e9
V2 out 0 dc 0 ac 0 portnum 2 z0 50
```

(shipped example `examples/sp/sp1.cir`).

**Promotion rules** — `src/spicelib/devices/vsrc/vsrctemp.c:74-82`:

```c
if (here->VSRCportNumGiven) {
    if (!here->VSRCportZ0Given) here->VSRCportZ0 = 50.0;
    here->VSRCisPort = here->VSRCportZ0 > 0.0 && here->VSRCportNum > 0;
} else
    here->VSRCisPort = FALSE;
```

So: `portnum` must be given **and** `> 0`, and `z0` must be `> 0`. A `z0 0` or `z0 -50` silently
demotes the source back to an ordinary source.

**Derived quantities** — `vsrctemp.c:93-97`:
- `VSRC2pifreq = 2*pi*freq`
- `VSRCVAmplitude = sqrt(pwr * 4 * z0)`  (available-power → open-circuit amplitude)
- `VSRCportY0 = 1/z0`
- `VSRCportPhaseRad = phase * pi/180`
- `VSRCki = 0.5 / sqrt(z0)`  (Kurokawa power-wave normalisation)

**Ordering and validation** — `vsrctemp.c:99-122` appends each port to `ckt->CKTrfPorts[]` and
bubble-sorts by `VSRCportNum`; `vsrctemp.c:128-176` then checks every port index and rejects:
- `portnum > portCount` → `ERR_FATAL`, `E_BADPARM`. Measured literal:
  `Fatal error: v2: incorrect port ordering` then
  `doAnalyses: no such parameter on this device or parameter is missing` and
  `sp simulation(s) aborted`. (Triggered by numbering two ports 1 and 3.)
- duplicate `portnum` → `ERR_FATAL`, `E_BADPARM`. Measured literal:
  `Fatal error: v1: duplicate port Index` + the same two follow-up lines.

**Therefore port numbers must be a contiguous 1..N with no gaps and no repeats.**

**A port is not electrically neutral outside SP.** `vsrcset.c:53-79` creates an *extra internal node*
named `<vsrcname>#res` for every port and rewires the branch equation through it, and both
`vsrcload.c:51-64` (DC/transient) and `vsrcacld.c:150-157` (AC) stamp `g0 = 1/z0` across
pos↔res. Measured on a deck with a port `V1 in 0 dc 1 z0 50` into `R1 in 0 50` beside a plain
`V2 x 0 dc 1` into `R2 x 0 50`:

```
v(in) = 5.000000e-01
v(x)  = 1.000000e+00
v(v1#res) = 1.000000e+00
```

i.e. adding `portnum` to a source **inserts a `z0` series resistance that changes every DC, AC and
transient result**. This is the single largest GUI trap in the SP feature.

In **transient**, a port with `pwr`/`freq` given becomes a `PORT` waveform
(`vsrcpar.c:362-379` sets `VSRCfunctionType = PORT` when either `pwr` or `freq` is set;
`vsrcload.c:453-459`):

```c
case PORT:
    value += here->VSRCVAmplitude * cos(time * here->VSRC2pifreq);
```

Note two defects here: the `case PORT` has **no `break;`** (harmless only because it is last in the
switch), and **`VSRCportPhaseRad` is never used** — `grep -rn VSRCportPhaseRad src` shows it is
written at `vsrctemp.c:96` and read nowhere. **The `phase` parameter has no effect on anything.**

In **AC**, `vsrcacld.c:130-138` uses `acmag`/`acphase`, *not* `pwr`, for a port. In **SP**, all
AC excitations are forced to zero and the ports are driven one at a time by `VSRCspupdate`
(`vsrcacld.c:121-129`, `vsrcacld.c:40-62`).

**Readback of `portnum` is broken.** `vsrc.c:32` declares `portnum` as `IF_INTEGER`, but
`vsrcask.c:160-162` answers with `value->rValue`. The caller reads `iValue` from the same union,
so it always reads 0. Measured:

```
show v1 : all   ->    portnum                     0        (deck said portnum 1)
print @v1[portnum] @v2[portnum]  ->  0.000000e+00 / 0.000000e+00
```

`z0`, `pwr`, `freq`, `phase` are `IF_REAL` and read back correctly (`show` reported `z0 75`,
`pwr 0.002`, `freq 2.4e+09`, `phase 30`). **A GUI cannot discover port indices by asking the
simulator**; it must track them itself or infer them from a completed run (see §2.9).

Setting works in both directions: `alter @v1[z0] = 100` was measured to take effect
(`show` afterwards reported `z0 100`), because `VSRCparam` reads the correct union member
(`vsrcpar.c:354-360`).

### 2.6 Minimum netlist for `.sp` to work at all

Hard requirements, in the order the code enforces them:

1. **At least one voltage source with `portnum`.** `span.c:376-380`:
   ```c
   if (ckt->CKTportCount == 0) {
       fprintf(stderr, "\nError: No RF Port is present, cannot run sp analysis\n");
       controlled_exit(EXIT_BAD);
   }
   ```
   **This is `controlled_exit`, not a return.** Measured: the whole process dies —
   stderr `Error: No RF Port is present, cannot run sp analysis` then
   `ERROR: fatal error in ngspice, exit(1)`, **process exit code 1**, and the `.control`
   block never resumes. A GUI must pre-validate this itself; there is no recovery.

2. **At least two ports.** `span.c:382-386`, same `controlled_exit(EXIT_BAD)`.
   Measured literal: `Error: Only one RF Port is found, we need at least two!`
   followed by `ERROR: fatal error in ngspice, exit(1)`, exit code 1.

3. **Contiguous unique port numbers 1..N** — see §2.5. These *do* return an error
   (`E_BADPARM`) rather than killing the process.

4. A `Vsource` device must be linked into the binary and instantiated — `span.c:746-760`
   looks up `CKTtypelook("Vsource")` and returns `E_NOMOD` if no VSRC model head exists.
   (In practice implied by requirement 1.)

5. The DC operating point must converge, unless `.options noopac` is set and the circuit is
   linear (`span.c:454-467`). On failure: `stdout` gets
   `\nAC operating point failed -\n`, `CKTncDump(ckt)` prints the non-converged nodes, and the
   analysis returns the error.

Relevant `.options` that change SP behaviour:
- `noopac` — `cktsopt.c:366-367`, "No op calculation in ac if circuit is linear". When set,
  SP skips `CKTop` and prints `\n Linear circuit, option noopac given: no OP analysis\n`
  (`span.c:466-467`).
- `keepopinfo` — `cktsopt.c:356-357`, "Record operating point for each small-signal analysis".
  When set, SP emits an **extra plot** named `"AC Operating Point"` before the SP plot
  (`span.c:476-487`). A GUI that assumes one plot per analysis must account for this.
- `reltol` — feeds `freqTol` (§2.4).
- `temp`/`tnom` — the whole run happens at `CKTtemp`, which is also the temperature used for
  the thermal-noise `4kT` factor (`span.c:117`).

Also: if `ckt->CKTvarHertz` is set (the `hertz` variable is used in a B-source or similar), SP
**re-solves the operating point at every frequency point** (`span.c:664-708`).

### 2.7 Output vectors — exact names, order, types

Naming is built in `span.c:501-551`. For an N-port circuit the SP plot contains, in this order
after the ordinary node/branch vectors:

1. `S_<i>_<j>` for i,j = 1..N — `sprintf(tmpBuf, "S_%d_%d", dest, j)` (`span.c:505`),
   outer loop `dest`, inner loop `j`. Row = destination port, column = source port.
2. `Y_<i>_<j>` for i,j = 1..N (`span.c:515`).
3. `Z_<i>_<j>` for i,j = 1..N (`span.c:525`).
4. **Only if `donoise` is 1:** `Cy_<i>_<j>` for i,j = 1..N (`span.c:538`).
5. **Only if `donoise` is 1 AND `N == 2`:** `NF`, `SOpt`, `NFmin`, `Rn`
   — in exactly that order (`span.c:547-550`).

Reference/scale vector: `frequency`, real-valued, created at `span.c:555`.
The data vectors are `IF_COMPLEX` (`span.c:559`).

Vector *types* are inferred by name, **conditional on the plot's typename starting with "sp"** —
`src/frontend/outitf.c:1048-1064`:

```c
else if (pltypename && ciprefix("sp", pltypename) && ciprefix("S_", name)) type = SV_SPARAM;
else if (… ciprefix("Y_", name)) type = SV_ADMITTANCE;
else if (… ciprefix("Z_", name)) type = SV_IMPEDANCE;
else if (… cieq(name, "NF"))     type = SV_DB;
else if (… cieq(name, "NFmin"))  type = SV_DB;
else if (… cieq(name, "Rn"))     type = SV_IMPEDANCE;
else if (… cieq(name, "SOpt"))   type = SV_NOTYPE;
else if (… ciprefix("Cy_", name))type = SV_CURRENT;
```

The `"sp"` prefix comes from `ft_plotabbrev` matching the pattern `"sp"` against the lowercased
analysis name (`src/frontend/typesdef.c:85-86`, `typesdef.c:331-348`), giving plot typenames
`sp1`, `sp2`, ….

Measured, 2-port with `donoise 1`, interactive (`display`):

```
Cy_1_1  : current,    complex
Cy_1_2  : current,    complex
Cy_2_1  : current,    complex
Cy_2_2  : current,    complex
NF      : decibel,    complex
NFmin   : decibel,    complex
Rn      : impedance,  complex
SOpt    : notype,     complex
S_1_1   : s-param,    complex
S_1_2   : s-param,    complex
S_2_1   : s-param,    complex
S_2_2   : s-param,    complex
Y_1_1   : admittance, complex
…
Z_2_2   : impedance,  complex
frequency : frequency, complex [default scale]
in      : voltage, complex
mid     : voltage, complex
out     : voltage, complex
v1#branch : current, complex
v1#res    : voltage, complex
v2#branch : current, complex
v2#res    : voltage, complex
```

Note the frequency scale is reported as `complex` in the in-memory plot even though it is written
as `IF_REAL`; `com_measure2.c:735` explicitly handles this ("`.sp`, s-param" — it reads
`dScale->v_compdata[i].cx_real`).

**In a rawfile the names differ.** `fileInit_pass2` (`outitf.c:1086-1111`) rewrites any
`SV_CURRENT` vector as `i(<name>)` and any `SV_VOLTAGE` as `v(<name>)`. Measured `-r sp.raw`
header:

```
Plotname: SP Analysis
Flags: complex
No. Variables: 28
Variables:
        0       frequency       frequency
        1       v(in)   voltage
        2       v(mid)  voltage
        3       v(out)  voltage
        4       i(v2)   current
        5       v(v2#res)       voltage
        6       i(v1)   current
        7       v(v1#res)       voltage
        8       S_1_1   s-param
        …
       11       S_2_2   s-param
       12       Y_1_1   admittance
        …
       19       Z_2_2   impedance
       20       i(Cy_1_1)       current     <-- note the i() wrapper
       21       i(Cy_1_2)       current
       22       i(Cy_2_1)       current
       23       i(Cy_2_2)       current
       24       NF      decibel
       25       SOpt    notype
       26       NFmin   decibel
       27       Rn      impedance
Binary:
```

So a rawfile reader must look for `i(Cy_1_1)`, not `Cy_1_1`. `S_`/`Y_`/`Z_`/`NF`/`NFmin`/`Rn`/`SOpt`
keep their bare names.

The **plot name** in-memory is `sp<N>` and the **plot title line** is the analysis `JOBname`.
Measured `setplot` listing after `sp` then `ac`:

```
List of plots available:
Current ac1     * sp setplot (AC Analysis)
        sp1     * sp setplot (SP Analysis)
        const   Constant values (constants)
```

`(SP Analysis)` is the `pl_name`, taken from the `JOBname` string `"SP Analysis"` that
`dot_sp` passes to `newAnalysis` (`inp2dot.c:736`). In a rawfile the same string is the
`Plotname:` line.

### 2.8 The maths behind S/Y/Z, and how many ports are supported

**No hard port limit exists** — `grep -rn "MAXPORT\|portCount >\|portCount <"` returns nothing.
Matrices are allocated `portCount x portCount` at `span.c:218-251`. Practically limited by
memory and by the O(N) extra solves per frequency point.
Measured: `examples/sp/sp4.cir` (3 ports) runs and produces the full 3x3 `S_/Y_/Z_/Cy_` sets.

Per frequency point (`span.c:782-838`):
1. `NIspPreload(ckt)` loads the AC matrix once (`src/maths/ni/niaciter.c:25`).
2. For each port p = 1..N: reset RHS, set `CKTactivePort = p`, `VSRCspupdate` injects `1.0` into
   the branch equation of port p only (`vsrcacld.c:56-58`), `NIspSolve` solves, then
   `CKTspCalcPowerWave` fills column p-1 of A and B.

`CKTspCalcPowerWave` (`src/spicelib/analysis/cktspdum.c:85-116`) — Kurokawa power waves with
real reference impedance:

```
a_i = ki * (V_i + z0_i * I_i)
b_i = ki * (V_i - z0_i * I_i)      with ki = 0.5/sqrt(z0_i)
```

`CKTspCalcSMatrix` (`cktspdum.c:41-83`):

```
S = B * A^-1
Z = Gn^-1 * (E - S)^-1 * (S*Z0 + Z0) * Gn
Y = Gn^-1 * (S*Z0 + Z0)^-1 * (E - S) * Gn
```

where `Z0 = diag(z0_i)` and `Gn = diag(2*ki) = diag(1/sqrt(z0_i))`
(`src/spicelib/devices/vsrc/vsrcacld.c:15-37`, `VSRCspinit`). **The reference impedance is
per-port and comes only from each port's `z0`; there is no global reference-impedance knob.**

**Latent defect worth knowing about**: `span.c:779-780`

```c
memcpy(rhswoPorts, ckt->CKTrhs,  (size_t)ckt->CKTmaxEqNum * sizeof(double));
memcpy(rhswoPorts, ckt->CKTirhs, (size_t)ckt->CKTmaxEqNum * sizeof(double));
```

The second `memcpy` should target `irhswoPorts`. As written, `rhswoPorts` ends up holding the
imaginary RHS and `irhswoPorts` is never filled from the circuit. It does not bite in practice
because `MODESP` forces every AC source to zero (`vsrcacld.c:121-129`), so the preloaded RHS is
zero — but it means any future non-zero pre-port excitation would be wrong.

Dead flag: `MODESPNOISE` (`cktdefs.h:195`) is tested in `vsrcacld.c:117` but **never set anywhere**
in the tree.

### 2.9 SP noise — what `donoise 1` actually computes

The file the task named, `src/spicelib/analysis/cktspnoise.c`, is **entirely dead code**: its
whole body is inside `#ifdef RFSPICE_` (note the trailing underscore, `cktspnoise.c:23`) with the
comment at `cktspnoise.c:22` — `/* not used, CKTspnoise is in span.c */`. It is still listed in
`Makefile.am:63` and compiles to an empty translation unit. The same is true of
`src/spicelib/analysis/noisesp.c` (`#ifdef RFSPICE_` at `noisesp.c:30`, comment `/* not used */`
at line 29).

**The live implementation is `CKTspnoise` in `span.c:74-178`.**

How it works:
1. `initSPmatrix(ckt, 1)` (`span.c:257-280`) allocates `CKTNoiseCYmat` (NxN) and
   `CKTadjointRHS` (N x CKTmaxEqNum), and captures `refPortY0` from **port 1**
   (`ckt->CKTrfPorts[0]->VSRCportY0`, `span.c:277-278`).
2. A **fake `NOISEAN` job** is fabricated per SP run — `SPcreateNoiseAnalysys`
   (`span.c:319-335`) copies the SP frequency plan into a `NOISEAN` and forces
   `NStpsSm = 1` ("Force to output noise at every freq step"). `CKTspnoise` temporarily swaps
   `ckt->CKTcurJob` to it (`span.c:78-79`, restored at `span.c:176`) so that per-device
   `DEVnoise` routines see a `NOISEAN`.
3. At each frequency, after the S-matrix is built, the **adjoint system** is solved once per port:
   `NInspIter(ckt, port)` (`span.c:181-202`) injects a unit current at that port's nodes and
   stores the whole solution vector as a row of `CKTadjointRHS` (`span.c:860-878`).
4. Every device's `DEVnoise` is then called with `N_CALC`; the per-source accumulation happens
   inside `NevalSrc` / `NevalSrc2` / `NevalSrcInstanceTemp`
   (`src/spicelib/analysis/nevalsrc.c:43-93`, `:159-225`, `:269-320`) and, for OSDI models,
   `src/osdi/osdinoise.c:135-...`, all guarded by `if (ckt->CKTcurrentAnalysis & DOING_SP)`.
   Each noise source is converted to a port-referred noise **current** and accumulated into
   `CKTNoiseCYmat[d][s] += i_d * conj(i_s)`.
5. `CKTspnoise(…, N_CALC, …)` (`span.c:111-159`) then, **only when `CKTportCount == 2`**,
   derives the two-port noise parameters:
   ```
   tempCy = CKTNoiseCYmat / (4*k*CKTtemp)
   Rn     = tempCy[1][1].re / |Y21|^2                      (clamped to >= 1e-30)
   Ycor   = Y11 - (tempCy[0][1]/tempCy[1][1]) * Y21
   Gu     = tempCy[0][0].re - Rn*|Y11-Ycor|^2
   Gopt   = sqrt(Ycor.re^2 + Gu/Rn) ;  Bopt = -Ycor.im
   SOpt   = (Y0 - Yopt)/(Y0 + Yopt)        with Y0 = refPortY0 (port 1's 1/z0)
   Fmin   = 1 + 2*Rn*(Ycor.re + Gopt)      -> then 10*log10()
   NF     = Fmin + (Rn/Y0)*|Y0 - Yopt|^2   -> then 10*log10()
   ```
   (`span.c:117-153`.) The reference is Stephen Maas, *Noise in Linear and Nonlinear Circuits*
   — cited in the source comment at `span.c:116`.

**Units and meanings for the GUI:**
- `Cy_i_j` — the raw noise **current** correlation matrix, A²/Hz, complex, dumped without the
  `4kT` normalisation (`cktspdum.c:194-205`).
- `NF` — noise figure **in dB** at the actual `z0` source termination (`span.c:153`).
- `NFmin` — minimum noise figure **in dB** (`span.c:152`).
- `Rn` — equivalent noise resistance in **ohms**, un-normalised (`span.c:127`).
- `SOpt` — optimum **source reflection coefficient**, complex, dimensionless (`span.c:147-148`).

**Limitations to surface in a GUI:**
- Noise parameters exist **only for exactly 2 ports** (`span.c:123`, `span.c:545`,
  `cktspdum.c:140`, `cktspdum.c:207`). For 1 or ≥3 ports you get `Cy_i_j` and nothing else.
  Measured on 3 ports: `Cy_1_1 … Cy_3_3` present, no `NF`/`NFmin`/`Rn`/`SOpt`.
- `Y0` is taken from **port 1 only**. A 2-port with `z0 75` on port 1 and `z0 50` on port 2 gets
  its `NF`/`SOpt` referred to 75 Ω regardless of port 2.
- There are **no per-device noise contribution vectors**. `NOISE_ADD_OUTVAR`
  (`src/include/ngspice/noisedef.h:121-138`) is redefined under RFSPICE so that in SP mode it
  merely increments `ckt->CKTnoiseSourceCount` instead of creating a named output. So the
  `onoise_<device>` breakdown you get from `.noise` is **not** available from `.sp donoise 1`.
  (`CKTnoiseSourceCount` itself is only ever incremented and zeroed — `cktinit.c:146`,
  `noisedef.h:125` — nothing reads it.)
- There is **no** `onoise_spectrum` / `inoise_spectrum` / `onoise_total` in an SP plot.
  Measured: those names appear nowhere in the SP `display` output.
- SP noise uses the same per-device `DEVnoise` entry points as `.noise`, so any device with a
  noise model contributes; devices without one contribute nothing silently.

Measured smoke test (resistive 2-port, 25 Ω / 1 kΩ / 25 Ω, `.sp lin 5 1e8 1e9 1`):
`NF = 3.405061` dB, `NFmin = 1.938200` dB, flat over frequency — plausible for a resistive pad.

### 2.10 Post-processing that a GUI will want to expose

- **`wrs2p [file]`** — `src/frontend/commands.c:224-227` (help string
  `"file : Send s-param data to file."`), implemented at
  `src/frontend/postcoms.c:762-...` and `src/frontend/rawfile.c:921-1020`.
  - Default filename when no argument: `"s_param.s2p"` (`postcoms.c:775-778`).
  - **Always prints to stderr**: `Note: only 2 ports 1 and 2 are supported by wrs2p`
    (`postcoms.c:780`).
  - Requires the vectors `frequency`, `S_1_1`, `S_2_1`, `S_1_2`, `S_2_2` (`postcoms.c:784-789`).
  - **Requires a vector named `Rbase`** (`postcoms.c:809-815`). Without it:
    `Error: No Rbase vector given` and nothing is written. The idiom in
    `examples/sp/file.cir:24` is `.csparam Rbase=50`.
  - Output format is Touchstone v1, header `# Hz S RI R <Rbase>` (`rawfile.c:986`),
    column order **freq, S11, S21, S12, S22**, real/imag pairs. Precision is `raw_prec`
    or 6 (`rawfile.c:936-939`).
  - Measured output on a 50 Ω / 50 Ω pad:
    ```
    !2-port S-parameter file
    !Title: * wrs2p test
    !Generated by ngspice at Wed Sep  9 18:54:29  2026
    # Hz S RI R 50
    !freq           ReS11          ImS11          ReS21          ImS21          ReS12          ImS12          ReS22          ImS22
     1.000000e+08   3.333333e-01   0.000000e+00   6.666667e-01   0.000000e+00   6.666667e-01   0.000000e+00   3.333333e-01   0.000000e+00
     …
    ```
- **Reading a Touchstone file back** is *not* an SP feature — it goes through the XSPICE `xfer`
  code model (`src/xspice/icm/analog/xfer/`), driven by `.model … xfer file=<touchstone>
  span=9 offset=N`. See the worked subcircuit `s2p_generic` in
  `examples/sp/file.cir:60-84`. This is gated on `XSPICE` (on by default here), not on RFSPICE.
- **`plot … smithgrid` / `smith` / `polar`** — `src/frontend/plotting/plotit.c:529-586`.
  Shipped usage in `examples/sp/sp2.cir`.
- **`meas`** accepts SP plots: `com_measure2.c:1660-1666` allows plot typenames
  `tran`, `ac`, `dc`, `sp` and rejects everything else with
  `Error: measure limited to tran, dc, sp, or ac analysis`.
  **Note `pss` is NOT in that list** — `meas` cannot be used on PSS results.
- Useful derived quantities seen in the shipped examples:
  `db(s_1_1)`, `ph()`, `cph()` (unwrapped phase), `deriv()`, `mag()`, and
  `settype decibel|phase <vec>` (`examples/sp/Tschebyschef-LP.cir`,
  `examples/sp/file.cir:32` computes group delay as `-1*deriv(cph(S_2_1))/(2*pi)`).

### 2.11 Shipped SP examples (good GUI test fixtures)

`examples/sp/`:
- `sp1.cir` — 2 ports as *power* ports (`pwr`, `freq` given), `.sp lin 100 1e8 1e9 1`.
- `sp2.cir` — 2 ports as *voltage* ports (`pwr`/`freq` commented out), `.sp dec 100 1 1e6 0`,
  demonstrates `smithgrid`, `polar`, `hardcopy`, colour variables.
- `sp3.cir` — identical circuit driven from `.control` with `sp dec 100 1 1e6 0`.
- `sp4.cir` — **3 ports**, `.sp lin 100 1e8 1e9 1`.
- `Tschebyschef-LP.cir` — filter, `settype decibel/phase`, `smithgrid`.
- `file.cir` — SP + `wrs2p` + `.csparam Rbase=50` + Touchstone read-back via `xfer`;
  also `137mhz_bpf.s2p` and `filter.lib`, `filter.sp`.

There are **no `tests/` entries for SP** — `grep` finds `.sp`/`portnum` only under `examples/`
and in unrelated `.sp`-suffixed XSPICE files. SP has no regression coverage in this tree.

### 2.12 Complete measured error strings for SP

| Trigger | Stream | Literal text | Recoverable? |
|---|---|---|---|
| 0 ports | stderr | `Error: No RF Port is present, cannot run sp analysis` then blank line then `ERROR: fatal error in ngspice, exit(1)` | **No — process exits 1** |
| 1 port | stderr | `Error: Only one RF Port is found, we need at least two!` then `ERROR: fatal error in ngspice, exit(1)` | **No — process exits 1** |
| duplicate `portnum` | stderr | `Fatal error: v1: duplicate port Index` / `doAnalyses: no such parameter on this device or parameter is missing` / `run simulation(s) aborted` | yes |
| gap in `portnum` | stderr | `Fatal error: v2: incorrect port ordering` / same two follow-ups | yes |
| `dec`/`oct` with fstart ≤ 0 | stderr | `ERROR: AC startfreq <= 0` / `doAnalyses: parameter value out of range or the wrong type` / `sp simulation(s) aborted` | yes |
| negative fstart | stderr | `Error: Frequency of < 0 is invalid for AC start` / `in   .sp lin 10 -1 1e9 0` / `sp simulation(s) aborted` | yes |
| bad step-type token | stderr | `Error: no such parameter on this device or parameter is missing` / `in   .sp bogus 2 1e8 8e8 0` / `sp simulation(s) aborted` | yes |
| OP fails | stdout | `\nAC operating point failed -\n` + `CKTncDump` node list | yes |
| `wrs2p` without `Rbase` | stderr | `Error: No Rbase vector given` | yes |

Two `spsetp.c` oddities: `SP_STOP` with a negative value sets `job->SPstartFreq = 1.0`
(`spsetp.c:39` — should be `SPstopFreq`), and both messages say "AC start"/"AC stop" rather
than SP.

---

## 3. PSS — periodic steady state

**Not compiled in this tree.** Everything below is source reading only; I could not run it.
Author: Stefano Perticaroli, 2010; reviews 2012 by Francesco Lannutti
(`src/spicelib/analysis/dcpss.c:1-5`). `NEWS:807` describes it as
"still very experimental pss code" (ngspice-23, 2011).

### 3.1 Registration

`src/spicelib/analysis/psssetp.c:68-83`:

```c
SPICEanalysis PSSinfo  = {
    { "PSS", "Periodic Steady State analysis", sizeof(PSSparms)/sizeof(IFparm), PSSparms },
    sizeof(PSSan),
    TIMEDOMAIN,
    1,          /* do_ic */
    PSSsetParm,
    PSSaskQuest,
    PSSinit,    /* has an init hook, unlike SP */
    DCpss
};
```

Registered at `analysis.c:46-48`, positioned **before** SENS2 and SP in `analInfo[]`.

### 3.2 The IFparm table (complete), with meanings, units, defaults

`src/spicelib/analysis/psssetp.c:57-66`:

| keyword | id (`pssdefs.h:31-40`) | declared type | description string in source | struct field | unit |
|---|---|---|---|---|---|
| `fguess` | `GUESSED_FREQ` | `IF_SET\|IF_REAL` | "guessed frequency" | `PSSguessedFreq` | Hz |
| `oscnode` | `OSC_NODE` | `IF_SET\|IF_STRING` | "oscillation node" | `PSSoscNode` (`CKTnode*`) | node name |
| `stabtime` | `STAB_TIME` | `IF_SET\|IF_REAL` | "stabilization time" | `PSSstabTime` | s |
| `points` | `PSS_POINTS` | `IF_SET\|IF_INTEGER` | "pick equispaced number of time points in PSS" | `PSSpoints` (`long int`) | count |
| `harmonics` | `PSS_HARMS` | `IF_SET\|IF_INTEGER` | "consider only given number of harmonics in PSS from DC" | `PSSharms` | count, **including DC** |
| `uic` | `PSS_UIC` | `IF_SET\|IF_INTEGER` | "use initial conditions (1 true - 0 false)" | sets `MODEUIC` in `PSSmode` | flag |
| `sc_iter` | `SC_ITER` | `IF_SET\|IF_INTEGER` | "maxmimum number of shooting cycle iterations" *(sic, typo in source)* | `sc_iter` | count |
| `steady_coeff` | `STEADY_COEFF` | `IF_SET\|IF_INTEGER` | "set steady coefficient for convergence test" | `steady_coeff` (`double`) | dimensionless |

**Two type mismatches a GUI must know about:**
1. `steady_coeff` is declared `IF_SET|IF_INTEGER` (`psssetp.c:65`) but `PSSsetParm` reads
   `value->rValue` (`psssetp.c:47`) and `PSSaskQuest` answers `value->rValue`
   (`pssaskq.c:130`). The card parser explicitly requests `IF_REAL`
   (`inp2dot.c:698`), so a `.pss` card works; anything driving `setAnalysisParm` off the
   declared type would pass an int and get garbage.
2. `oscnode` is declared `IF_STRING` but stored/read as `value->nValue`, a `CKTnode*`
   (`psssetp.c:27`, `pssaskq.c:108`). Only the card parser's
   `INPtermInsertRef` path (`inp2dot.c:684-688`) supplies a valid value.

**Defaults: there are none.** As with SP, `CKTnewAnal` `tmalloc`s the `PSSan`
(`cktnewan.c:30` → `alloc.c:70` = `calloc`), so every field starts at 0 and the card must supply
all seven positional values. Supplying `fguess` = 0 divides by zero immediately
(`pssinit.c:153` computes `0.01 * (1/fguess)`).

`PSSinit` (`src/spicelib/analysis/pssinit.c:148-169`) is the only place anything is derived,
and it **overrides transient options the user may have set**:

```c
ckt->CKTstep    = 0.01 * (1/job->PSSguessedFreq);   /* "chosen empirically to be 1% of PSSguessedFreq" */
ckt->CKTinitTime= 0;                                /* "Init time should be always zero" */
ckt->CKTmaxStep = 0.5*(1/job->PSSguessedFreq);      /* "should not exceed Nyquist criterion" */
ckt->CKTdelmin  = 1e-9*ckt->CKTmaxStep;
ckt->CKTmode    = job->PSSmode;                     /* wipes other mode bits */
ckt->CKTstabTime     = job->PSSstabTime;
ckt->CKTguessedFreq  = job->PSSguessedFreq;
ckt->CKTharms        = job->PSSharms;
ckt->CKTpsspoints    = job->PSSpoints;
ckt->CKTsc_iter      = job->sc_iter;
ckt->CKTsteady_coeff = job->steady_coeff;
```

So `.options` `tstep`/`tmax`/`delmin` are **ignored** for PSS; only `reltol`, `abstol`, `vntol`
(`CKTvoltTol`) and `trtol` still matter, via the convergence test (§3.5).

### 3.3 Card and command syntax

`src/spicelib/parser/inp2dot.c:653-711` (`dot_pss`), dispatched at `inp2dot.c:906-909`.
The comment at `inp2dot.c:667` says `/* .pss Fguess StabTime OscNode <UIC>*/` — **stale, ignore it**.
The actual positional order from the code is:

```
.pss <fguess> <stabtime> <oscnode> <points> <harmonics> <sc_iter> <steady_coeff> [uic]
```

Mapped, in parse order:
- `INPgetValue(IF_REAL)`  → `"fguess"`      (`inp2dot.c:676-677`)
- `INPgetValue(IF_REAL)`  → `"stabtime"`    (`inp2dot.c:679-680`)
- `INPgetNetTok` + `INPtermInsertRef` → `"oscnode"` (`inp2dot.c:683-687`)
- `INPgetValue(IF_INTEGER)` → `"points"`    (`inp2dot.c:689-690`)
- `INPgetValue(IF_INTEGER)` → `"harmonics"` (`inp2dot.c:692-693`)
- `INPgetValue(IF_INTEGER)` → `"sc_iter"`   (`inp2dot.c:695-696`)
- `INPgetValue(IF_REAL)`    → `"steady_coeff"` (`inp2dot.c:698-699`)
- optional trailing token, must be exactly `uic` (case-insensitive), else
  `fprintf(stderr, "Error: unknown parameter %s on .pss - ignored\n", word)`
  (`inp2dot.c:701-709`).

The shipped examples confirm the order, and `examples/pss/hartley_osc_pss_ctrl.cir:27` even
documents it as a comment:

```
* gfreq tstab oscnob psspoints harms sciter steadycoeff
pss 120 100e-3 n2 1024 11 10 5e-3
```

("oscnob" is that example's spelling; the parameter keyword is `oscnode`.)

**Control command** — `src/frontend/runcoms.c:187-194` (`com_pss` → `dosim("pss", wl)`),
registered at `src/frontend/commands.c:324-331` with help string
`"[.pss line args] : Do a periodic state analysis."` (and in `nutcp_coms[]` at
`commands.c:837-844` with `"[.pss line args] : Do a periodic steady state analysis."` —
the two strings differ). Same syntax as the card, routed through `spiceif.c:267-270`.

Shipped invocations (`examples/pss/`):

```
.pss 624e6 500n 1 1024 10 5 5e-3 uic      (ring_osc_pss.cir:29)
.pss 50 200e-3 2 1024 11 10 5e-3 uic      (hartley_osc_pss.cir:21)
.pss 0.5e6 100e-6 1 50 10 50 5e-3 uic     (vdp_osc_pss.cir:22)
.pss 1e6 10e-6 4 1024 10 50 5e-3 uic      (vackar_osc_pss.cir:21)
.pss 500e6 1u 1 1024 10 10 5e-3 uic       (compl_cross_quad_osc_pss.cir:35)
.pss 3.1e6 500e-6 3 256 10 50 5e-3        (colpitt_osc_pss.cir:21)
pss 2G 10n bout 1024 10 5 5e-3 uic        (ring_osc_pss_ctrl.cir:36)
pss 500e6 8n out 1024 10 5 5e-3 uic       (19-nand-ro-IHP_ctrl.cir:63)
pss 1e6 50e-6 3 256 10 50 5e-3            (colpitt_osc_pss_ctrl.cir:32)
pss 120 100e-3 n2 1024 11 10 5e-3         (hartley_osc_pss_ctrl.cir:28)
pss 1.8e6 20e-6 4 1024 10 50 5e-3 uic     (vackar_osc_pss_ctrl.cir:29)
pss 0.5e6 100e-6 1 50 10 50 5e-3 uic      (vdp_osc_pss_ctrl.cir:29)
pss 400e6 2u 1 1024 10 10 5e-3 uic        (compl_cross_quad_osc_pss_ctrl.cir:38)
```

Note the `.cir` (non-`_ctrl`) variants pass bare digits (`1`, `2`, `3`, `4`) as `oscnode` —
those are stale node numbers from before the circuits were renamed; the `_ctrl` variants use
real node names (`bout`, `out`, `n2`). Since `oscnode` is unused (§3.4), both work.

### 3.4 **`oscnode` is a no-op**

`grep -n "oscnNode\|PSSoscNode" src/spicelib/analysis/dcpss.c` yields exactly two hits:

```
dcpss.c:93    int j, oscnNode;
dcpss.c:126   oscnNode = job->PSSoscNode->number ;
```

The value is **assigned and never read**. The only real consequence of the argument is that a
missing or unresolvable node produces a **NULL dereference** at `dcpss.c:126`. The convergence
machinery works over *all* nodes and branches, not a nominated one. A GUI must still ask for the
field (the parser demands a token there) but should be honest that it does not steer anything.

### 3.5 Algorithm, convergence controls and failure modes

PSS is a **shooting method layered on the transient engine**. `DCpss`
(`dcpss.c:60-...`, 1485 lines) is a modified `DCtran` with a three-state machine
(`dcpss.c:96`): `STABILIZATION → SHOOTING → PSS`.

Startup banner, unconditional on stdout (`dcpss.c:117-123`):

```
Periodic Steady State Analysis Started

PSS Guessed Frequency %g
PSS Points %ld
PSS Harmonics number %d
PSS Steady Coefficient %g
PSS sc_iter %d
PSS Stabilization Time %g
```

**Phase 1 — STABILIZATION.** Plain transient from t=0 to `CKTfinalTime = stabtime`
(`dcpss.c:166`). Initial `delta = MIN(1/fguess/100, CKTstep)` (`dcpss.c:170`).
On reaching `stabtime` (within 100 ULP, `dcpss.c:482`) it prints
`Exiting from stabilization` and `Time of first shooting evaluation will be %1.10g`
(`dcpss.c:488-489`) and switches to SHOOTING with
`CKTfinalTime = time_temp + 2/fguess` (`dcpss.c:487`).

**Phase 2 — SHOOTING.** Each shooting cycle simulates one estimated period and compares the RHS
at the period boundary against the stored reference. Per iteration it prints (stderr,
`dcpss.c:681-687`):

```
----------------
Shooting cycle iteration number: %3d || rr: %g || predsum: %g
```

Convergence test per node/branch (`dcpss.c:693-723`):

```c
/* voltage node (no '#' in name) */
if (fabs(err_conv[i]) > (fabs(RHS_max[i]-RHS_min[i]) * CKTreltol + CKTvoltTol) * CKTtrtol * CKTsteady_coeff)
    excessive_err_nodes++;
if (fabs(RHS_max[i]-RHS_min[i]) > 10e-6)  dynamic_test++;   /* 10 uV floor */

/* current branch ('#' in name) */
if (fabs(err_conv[i]) > (fabs(RHS_max[i]-RHS_min[i]) * CKTreltol + CKTabstol) * CKTtrtol * CKTsteady_coeff)
    excessive_err_nodes++;
if (fabs(RHS_max[i]-RHS_min[i]) > 10e-9)  dynamic_test++;   /* 10 nA floor */
```

So `steady_coeff` is a **multiplier on the convergence tolerance**: bigger = looser = converges
sooner. The shipped examples all use `5e-3`, i.e. tightening by 200x relative to
`reltol*trtol`.

Frequency update (`dcpss.c:773-790`): if the error minimum sits at the current sample the guess
is decreased (`f = 1/(1/f + |predsum|)`), otherwise it is set to `1/(t_min - t_temp)`.
Every iteration prints (stdout, `dcpss.c:805-809`):

```
Updated guessed frequency: %s Hz.
Next shooting evaluation time is %1.10g and current time is %1.10g.
----------------
```

Loop exit (`dcpss.c:840`): `shooting_cycle_counter > CKTsc_iter` **or** `excessive_err_nodes == 0`.
Then (`dcpss.c:847-891`) it prints the history table

```
Frequency estimation (FE) and RHS period residual (PR) evolution
%-3d -> FE: %-15.10g || RR: %15.10g || predsum/dynamic_test: %15.10g || minimum: %15.10g
```

and one of:

```
\nConvergence reached. Final circuit time is %1.10g seconds (iteration n° %d) and predicted fundamental frequency is %s Hz
\nConvergence not reached. However the most near convergence iteration has predicted (iteration %d) a fundamental frequency of %s Hz
```

**Both of these are `fprintf(stdout, …)` and both lead to a completed run** — a GUI cannot
distinguish success from give-up by exit code, only by scraping `Convergence reached` vs
`Convergence not reached`. `HISTORY` is fixed at 1024 (`dcpss.c:53`), so `sc_iter` above ~1023
overruns `gf_history[]`.

**Phase 3 — PSS.** One more period is simulated, sampling exactly `points` equispaced instants
via breakpoints (`dcpss.c:423-451`). Each accepted sample is `CKTdump`ed into the time-domain
plot *and* stored into `pssvalues[]` for the DFT (`dcpss.c:435-445`).

**Hard failure modes (both return an error and abort):**

| Condition | Source | Message (stderr) | Return |
|---|---|---|---|
| No node or branch shows dynamics above the 10 µV / 10 nA floors | `dcpss.c:725-740` | `Error: No detectable dynamic on voltages nodes or currents branches.\n    PSS analysis aborted` | `E_ERR_PSS` (=17, `iferrmsg.h:39`), rendered by `sperror.c:110-112` as `pss failed` |
| Error-vector minimum lands before the shooting reference time | `dcpss.c:742-756` | `Error: Cannot find a minimum for error vector in estimated period. Try to adjust tstab! PSS analysis aborted` | `E_PANIC` (with the source comment "to be corrected with definition of new error macro") |
| Time step collapses below `delmin` | `dcpss.c:1395-1404` | `CKTtrouble(ckt, "Timestep too small")` | `E_TIMESTEP` |
| `oscnode` absent / unresolvable | `dcpss.c:126` | *(none — NULL dereference)* | crash |

**Soft failure / re-entry:** if the DFT says the dominant harmonic is not the one at `fguess`,
PSS **calls itself recursively** (`dcpss.c:988-996`):

```
The predicted fundamental frequency is incorrect.
Relaunching the analysis...

The new guessed fundamental frequency is: %.6g
```

`DCpss(ckt, 1)` is invoked from inside `DCpss`, with **no depth limit**. A GUI should expect a
PSS run to take an unbounded and non-monotone amount of time, and should expect the time-domain
plot to be *closed and reopened*.

Ctrl-C handling: `IFpauseTest()` at `dcpss.c:1029-1033` returns `E_PAUSE`, and the
`restart == 0` path re-links the plot via
`OUTpBeginPlot(NULL,NULL,NULL,NULL,0,666,NULL,666,&job->PSSplot_td)`
(`dcpss.c:341-348`), printing `Error: Couldn't relink rawfile` on failure.

Windows progress hook (`dcpss.c:1041-1047`): `SetAnalyse("ptran init"|"shooting"|"ptran", …)`.

### 3.6 Output — **two plots, time domain then frequency domain**

This is the biggest structural difference from every other ngspice analysis.

**Plot 1 (time domain)** — opened at `dcpss.c:225-232`:

```c
SPfrontEnd->IFnewUid(ckt, &timeUid, NULL, "time", UID_OTHER, NULL);
OUTpBeginPlot(ckt, ckt->CKTcurJob,
              "Time Domain Periodic Steady State Analysis",
              timeUid, IF_REAL,
              numNames, nameList, IF_REAL,
              &(job->PSSplot_td));
```

- scale vector: `time`, real
- data vectors: whatever `CKTnames` yields — every node voltage and branch current, real
- data points: the `points` samples of one converged period, plus whatever was dumped during
  the shooting phase (`dcpss.c:878` also dumps at the convergence instant)
- closed at `dcpss.c:933` before the FD plot is opened.

**Plot 2 (frequency domain)** — opened at `dcpss.c:936-946`:

```c
SPfrontEnd->IFnewUid(ckt, &freqUid, NULL, "frequency", UID_OTHER, NULL);
OUTpBeginPlot(ckt, ckt->CKTcurJob,
              "Frequency Domain Periodic Steady State Analysis",
              freqUid, IF_REAL,
              numNames, nameList, IF_REAL,
              &(job->PSSplot_fd));
OUTattributes(job->PSSplot_fd, NULL, PLOT_COMB, NULL);   /* comb/stem rendering */
```

- scale vector: `frequency`, real. Values are `0, f0, 2*f0, …, (harmonics-1)*f0`
  (`dcpss.c:1470-1473`, `Freq[0]=0`, `Freq[i]=i*FundFreq`).
- **`harmonics` includes DC**: `harmonics 10` gives 10 rows, DC plus 9 harmonics.
- data vectors: same names as the TD plot (node voltages, branch currents).
- **values are magnitudes only** — `pssResults[j*msize+i] = pssmags[j]` (`dcpss.c:960`).
  `DFT()` computes `Phase`, `nMag`, `nPhase` and a `thd`, but **only `Mag` is dumped**;
  phase and THD are discarded. There is no phase output from PSS at all.
- `Mag[0]` is the DC mean (`dcpss.c:1465`).
- The DFT is a naive O(ndata*numFreq) sum, not an FFT (`dcpss.c:1456-1462`).

**Plot naming.** `ft_plotabbrev` (`typesdef.c:331-348`) matches the pattern `"periodic"`
(`typesdef.c:89`) against the lowercased analysis name, so **both** plots get the typename
prefix `pss` and are numbered by the global `plot_num` counter (`vectors.c:1102-1112`).
So a run produces `pssN` (time domain) followed by `pssN+1` (frequency domain).
Shipped examples confirm the ordering: `vdp_osc_pss_ctrl.cir:32` does `setplot pss1` to get
back to the time-domain plot after the bare `plot` picked up the current (= frequency) one;
`19-nand-ro-IHP_ctrl.cir:64-67` uses `setplot pss3` for the frequency plot and `setplot pss2`
for the time one.

**A GUI must not hardcode the numbers.** The reliable discriminators are the plot's `pl_name`
strings — `Time Domain Periodic Steady State Analysis` and
`Frequency Domain Periodic Steady State Analysis` — which appear in `setplot`/`display`
listings and as the `Plotname:` line of a rawfile.

**Consequence for a rawfile-per-run workflow:** one `pss` command writes **two** plots. Any
GUI logic built on "one analysis ⇒ one plot ⇒ one `write`" (which is what
`/home/analog/dev/xschem-claude/src/ase.tcl:10844` and `:10753` currently assume, with
`set appendwrite` and an enabled-analysis count) will mis-count for PSS.

`vlength2delta` (`outitf.c:1250-1275`) special-cases "tran or pss" for vector pre-allocation, but
keys on `CKTmode & MODETRAN`, which `DCpss` does set (`dcpss.c:321`, `:335`, `:1298`, `:1323`,
`:1338`).

### 3.7 What PSS is for, and what it is not

It is an **autonomous-oscillator** PSS: it estimates the oscillation frequency itself and
converges the period. Every shipped example is a free-running oscillator (ring, Colpitts,
Hartley, Vackar, Van der Pol, cross-coupled quadrature, 19-stage NAND RO). There is **no
driven-PSS mode**, no "beat frequency" input, no PAC/PXF/PNOISE follow-on analysis, and no
harmonic-balance alternative. If a GUI offers "periodic steady state" the honest scope is
"find the oscillation period of an autonomous circuit and report one period plus its harmonic
magnitudes".

---

## 4. HB — the harmonic-balance remnant

**HB does not exist in this tree beyond dead `#ifdef` blocks, and cannot be made to exist by
setting `WITH_HB`.**

Evidence:

1. `WITH_HB` is referenced in exactly seven places, all `#ifdef` guards:
   `inp2dot.c:752`, `inp2dot.c:918`, `analysis.c:22`, `analysis.c:55`,
   `spiceif.c:273`, `spiceif.c:407`, `shyu.c:359`.
2. It is **defined nowhere** — no `AC_ARG_ENABLE`, no `AC_DEFINE`, no line in
   `src/include/ngspice/config.h.in` (grep count = 0).
3. The symbol the guards reference, `HBinfo`, is **declared but never defined**:
   `grep -rn "HBinfo\|HBan\|HBsetParm\|HBaskQuest" src` returns only
   `analysis.c:23` (`extern SPICEanalysis HBinfo;`) and `analysis.c:56` (`& HBinfo,`).
   There is no `hbsetp.c`, no `hban.c`, no `hbdefs.h`, and no `HB_WANTED` automake conditional.
   Defining `WITH_HB` would therefore produce an **undefined-symbol link error**.
4. Even the parser stub is broken. `dot_hb` (`inp2dot.c:754-811`) is a verbatim copy of
   `dot_pss` that:
   - looks up `ft_find_analysis("PSS")`, not `"HB"` (`inp2dot.c:769`);
   - names the job `"Harmonic Balance State Analysis"` but applies **PSS** parameters;
   - sets a parameter called `"freq"` (`inp2dot.c:777`) which **does not exist in `PSSparms`**;
   - sets `"harmonics"` **twice** (lines 780 and 792), the first time from an `IF_INTVEC`;
   - carries the comment `/* .pss Fguess StabTime OscNode <UIC>*/` and the error string
     `"Periodic steady state analysis unsupported.\n"`.
   The `.hb` dispatch (`inp2dot.c:918-924`) is nested inside `#ifdef RFSPICE`, so `.hb` would
   also require SP.
5. `shyu.c:359-397` contains a second `hb` stub that looks up `ft_find_analysis("HB")` and then
   applies **SP** parameters (`numsteps`, `start`, `stop`, `donoise`), with the error string
   `"S-Param analysis unsupported\n"`.
6. The only trace of HB in the working code is a comment on a VSRC field:
   `vsrcdefs.h:107` — `double VSRCportPower; /* Port power (W) for HB analysis */` — and
   `cktdefs.h:288` — `GENinstance** CKTrfPorts; /* List of all RF ports (HB & SP) */`.
   The `pwr`/`freq` port parameters were evidently intended to feed HB and today only feed
   the transient `PORT` waveform.

Measured against the built binary:

```
$ ngspice -b <deck with ".control\nhb 1e9 5\n.endc">
stderr: hb: no such command available in ngspice
```

**Recommendation for the GUI: do not expose HB at all, and do not attempt to detect it.**
If detection is wanted anyway, use the same `help all` probe as for the others (§5); a build
with a working HB would have to add an `hb` entry to `spcp_coms[]`, which does not exist today.

---

## 5. Runtime capability detection — what a GUI should actually do

I tested every candidate probe against the built binary. Ranked by reliability:

### 5.1 Best probe: `help all`, parsed for a line beginning with the command name

`com_help` (`src/frontend/com_help.c:80-111`) walks `cp_coms[]` — the live, `#ifdef`-filtered
command table — and prints `<name> <helpstring>` for each. `help all` prints them all
(`com_help.c:60-73`, `allflag`). Output goes to **stdout**.

Deck:

```
* probe
.control
help all
.endc
.end
```

Measured (`ngspice -b probe.cir 2>/dev/null | grep -E '^(sp|pss|hb|ac|tran|noise) '`):

```
ac [.ac line args] : Do an ac analysis.
noise [.noise line args] : Do a noise analysis.
sp [.sp line args] : Do an S-parameter analysis.
tran [.tran line args] : Do a transient analysis.
```

`sp` present, `pss` and `hb` absent — exactly matching `config.h`. **One invocation enumerates
every analysis command the binary has.** This is the closest thing ngspice offers to an
"enumerate analyses" call.

Caveat: the list is *commands*, not analyses. `op`, `dc`, `run`, `resume`, `reset` are in there
too, and non-analysis commands like `wrs2p` are unconditional.

### 5.2 Second probe: `help <name>` for a single answer

Same deck with `help sp` / `help pss`. Measured, both on **stdout**:

```
sp [.sp line args] : Do an S-parameter analysis.
```
```
Sorry, no help for pss.
```

`Sorry, no help for %s.` is emitted at `com_help.c:103`. Note it also fires for a genuinely
unknown word, so a false "not compiled" reading is impossible only because the command names
are fixed.

Both forms then print the manual-URL trailer, which is noise to filter:

```
For further details please see the latest official ngspice manual in PDF format at
  https://ngspice.sourceforge.io/docs/ngspice-manual.pdf
or in HTML format at
  https://ngspice.sourceforge.io/docs/ngspice-html-manual/manual.xhtml
```

### 5.3 Third probe: run the command and read stderr

`src/frontend/control.c:218`:

```c
fprintf(cp_err, "%s: no such command available in %s\n", ..., cp_program);
```

Measured (stderr):

```
pss: no such command available in ngspice
hb: no such command available in ngspice
```

The `.control` block **continues executing** afterwards (measured: the `echo` after the failed
`pss` still ran, and `ngspice` exited 0 apart from the unrelated empty-netlist complaint).
This probe is destructive-free but costs a parse of whatever deck you attach it to.

### 5.4 Fourth probe: the dot card

`src/spicelib/parser/inp2dot.c:969-971` — anything that falls off the end of the dot-command
chain gets:

```c
char *token2 = tprintf(" unimplemented dot command '%s'\n", token);
LITERR(token2);
```

Measured for `.pss 1e6 1m 1 1024 10 5 0.1` in this SP-on/PSS-off build (stdout, via the deck
error report):

```
Error on line 4 or its substitute:
  .pss 1e6 1m 1 1024 10 5 0.1
 unimplemented dot command '.pss'
    Simulation interrupted due to error!
```

This is a *deck* error, so it aborts the run. Less useful as a probe, but it is the message a
user will see if the GUI emits `.pss` at an unsupporting binary — worth recognising and
translating.

### 5.5 Probes that do **not** work

- **`--version` / the banner.** Measured output lists only the KLU solver and the build date:
  ```
  ******
  ** ngspice-46+ : Circuit level simulation program
  ** Compiled with KLU Direct Linear Solver
  ** The U. C. Berkeley CAD Group
  ** Copyright 1985-1994, Regents of the University of California.
  ** Copyright 2001-2026, The ngspice team.
  ** Please get your ngspice manual from https://ngspice.sourceforge.io/docs.html
  ** Please file your bug-reports at http://ngspice.sourceforge.net/bugrep.html
  ** Creation Date: Thu Sep  3 06:46:24 UTC 2026
  ******
  ```
  No RFSPICE/PSS/XSPICE/OSDI/CIDER indication.
- **Bare `help`.** Prints only the "type `help all`" pointer, not a command list.
- **Presence of `wrs2p`.** Unconditional (§1.5).
- **Any dedicated enumeration command.** `spice_num_analysis()` /
  `spice_analysis_get_name()` (`analysis.c:62-79`) are consumed only by `main.c:507-510`
  and `sharedspice.c:443-446` to fill `SIMinfo`. Nothing in the control language exposes them.
  *(For a libngspice-based GUI, `SIMinfo.numAnalyses` / `SIMinfo.analyses[i]->name` **is** a
  direct programmatic enumeration — but there is no public `sharedspice.h` accessor for it, so
  even there you would be reaching into `ft_sim`.)*
- **`devhelp`.** Enumerates *devices*, not analyses. It would show `vsource` either way; whether
  it lists the `portnum`/`z0` parameters is untested here but would in principle be a
  second-order RFSPICE probe.

### 5.6 Suggested probe deck (one invocation, everything at once)

```
* ngspice capability probe
.control
help all
.endc
.end
```

run as `ngspice -b probe.cir` and parsed for `^sp `, `^pss `, `^hb `, plus the other analysis
commands. Expect the harmless stderr line
`Error: incomplete or empty netlist ... no simulations run!` and a non-zero exit code from the
empty deck — attach a trivial `V1 1 0 1 / R1 1 0 1k / .op` if a clean exit matters.

---

## 6. GUI design notes, ranked

1. **SP is the only one worth a first-class panel today.** PSS needs a rebuild
   (`--enable-pss`) that most distro packages do not do, and HB does not exist.
   The panel should be *conditionally shown* on the §5.1 probe, not always shown.

2. **Ports are a schematic-level concept the GUI must own.** Because
   `@Vx[portnum]` always reads back 0 (§2.5), the GUI is the only place port identity can live.
   Design implication: an ASE-L "Ports" pane that owns the 1..N assignment, enforces
   contiguity/uniqueness *before* netlisting, and emits `portnum`/`z0` onto the chosen sources.
   Post-run, port count is recoverable from the vector list (count of `S_<i>_<i>`) and port
   identity from the `<vname>#res` nodes, but only after a successful run.

3. **A port changes DC/AC/transient results.** Because `portnum` inserts `z0` in series
   (measured, §2.5), a schematic that carries ports cannot be reused unchanged for a `tran`
   or `dc` run. The GUI must either (a) emit `portnum` only into the SP netlist variant, or
   (b) warn loudly. Cadence ADE users will expect (a).

4. **Guard the two fatal SP preconditions in the GUI, not in the simulator.**
   Zero ports and one port both call `controlled_exit(EXIT_BAD)` — the process dies with exit
   code 1 and nothing downstream runs. A "Run" button that can kill the simulator on a
   configuration mistake is unacceptable; check `portCount >= 2` before emitting `.sp`.

5. **Two-port-only outputs need conditional UI.** `NF`, `NFmin`, `Rn`, `SOpt` and `wrs2p` all
   require exactly 2 ports. `Cy_i_j` works at any N. A noise checkbox should grey out its
   noise-figure results panel for N != 2 rather than showing empty traces.

6. **PSS produces two plots per run.** Any "one analysis, one write, one plot" assumption
   (which `ase.tcl` currently encodes around `appendwrite` and `n_enabled_analyses`) breaks.
   Discriminate by `pl_name`: `Time Domain Periodic Steady State Analysis` vs
   `Frequency Domain Periodic Steady State Analysis`.

7. **PSS has no phase output and no `meas` support.** The frequency-domain plot carries
   magnitudes only (§3.6) and `meas` rejects `pss` plots (`com_measure2.c:1660-1666`).
   A results browser must not offer phase or measurement UI for PSS results.

8. **Analysis run order is fixed by `analInfo[]`, not by the user.** SP always runs last in a
   multi-analysis task (`cktdojob.c:176`). If the GUI lets the user order analyses, it must
   either emit them as separate `.control` commands (which *do* run in the order written,
   because each `dosim` call is its own `doAnalyses`) or explain that dot-cards are reordered.
   ASE-L already emits `.control` commands (`ase.tcl:10938-10965`), so this is a non-issue for
   the current design — but it is a real difference between the two netlist shapes.

9. **`.options keepopinfo` silently adds an extra plot per small-signal analysis**
   (`span.c:476-487`). Worth surfacing as a checkbox with an explanation, or suppressing.

10. **Sweep-parameter semantics differ between `lin` and `dec`/`oct`.** `numsteps` is
    *total points* for `lin` and *points per decade/octave* for the others (§2.4). A Cadence-style
    "Sweep Type / Points" pair must relabel the second field when the first changes; getting
    this wrong is the classic ngspice AC-sweep mistake and SP inherits it verbatim.

---

## 7. Source-and-doc disagreements, and where I trust source

| Claim | Doc/comment says | Source says | I trust |
|---|---|---|---|
| `.sp` argument list | `inp2dot.c:730` comment: `.ac {DEC OCT LIN} NP FSTART FSTOP` | plus a trailing `donoise` integer (`inp2dot.c:747-748`) | **source** — measured: `.sp lin 3 1e8 1e9 1` accepted, and `1` toggles the noise vectors |
| `.pss` argument list | `inp2dot.c:667` comment: `.pss Fguess StabTime OscNode <UIC>` | seven positional args + optional `uic` (`inp2dot.c:676-709`) | **source**, corroborated by `examples/pss/hartley_osc_pss_ctrl.cir:27` |
| `oscnode` meaning | `psssetp.c:59` "oscillation node"; every example supplies one | assigned once at `dcpss.c:126`, never read | **source** — the argument is inert |
| `steady_coeff` type | `psssetp.c:65` declares `IF_INTEGER` | read/written as `rValue`; card parses `IF_REAL` | **source** (`rValue`); the IFparm flag is a bug |
| `portnum` readback | `vsrc.c:32` declares `IF_INTEGER` | `vsrcask.c:161` answers `rValue` | **measured** — reads back 0 |
| `phase` on a port | `vsrc.c:36` "Phase of the source" | `VSRCportPhaseRad` computed at `vsrctemp.c:96`, read nowhere | **source** — no effect |
| `pwr` on a port | `vsrcdefs.h:107` "Port power (W) for HB analysis" | HB does not exist; `pwr` only feeds the transient `PORT` cosine via `VSRCVAmplitude` (`vsrcload.c:456`) | **source** |
| `CKTspnoise` location | `cktspnoise.c` is named for it and is in `Makefile.am` | guarded by `#ifdef RFSPICE_`, dead; the live one is `span.c:74` | **source**, and the file's own comment at `cktspnoise.c:22` agrees |
| SP noise output set | — | no `onoise_*`/`inoise_*` vectors; `NOISE_ADD_OUTVAR` suppressed under `DOING_SP` (`noisedef.h:121-138`) | **measured** — `display` shows none |

The upstream PDF manual (<https://ngspice.sourceforge.io/docs/ngspice-manual.pdf>) is not in this
repo and I did not fetch it; anything a future session reads there about `.sp` or `.pss` should be
re-checked against the line anchors above, because the in-tree comments are already demonstrably
stale in three places.

---

## 8. File index (everything relevant, with what is in it)

**SP, compiled when `RFSPICE`:**
- `src/spicelib/analysis/span.c` — `SPan` driver, `CKTspnoise` (the live one), `NInspIter`,
  `initSPmatrix`, `deleteSPmatrix`, `SPcreateNoiseAnalysys`, the noise-parameter maths
- `src/spicelib/analysis/spsetp.c` — `SPsetParm`, `SPparms[]`, `SPinfo`
- `src/spicelib/analysis/spaskq.c` — `SPaskQuest`
- `src/spicelib/analysis/cktspdum.c` — `CKTspCalcSMatrix`, `CKTspCalcPowerWave`, `CKTspDump`
- `src/include/ngspice/spardefs.h` — `SPAN` struct, `SP_*` ids, step-type enum

**SP, dead code (`#ifdef RFSPICE_`):**
- `src/spicelib/analysis/cktspnoise.c` — unused `CKTSPnoise`
- `src/spicelib/analysis/noisesp.c` — unused `NOISEsp`

**SP support, compiled unconditionally but with `#ifdef RFSPICE` sections:**
- `src/spicelib/devices/vsrc/vsrcdefs.h` (`:35-46`, `:95-112`, `:121-127`, `:159-163`, `:193-199`)
- `src/spicelib/devices/vsrc/vsrc.c:31-37` — the port IFparm entries
- `src/spicelib/devices/vsrc/vsrcpar.c:336-385` — port parameter setters
- `src/spicelib/devices/vsrc/vsrcask.c:159-175` — port parameter getters (the `rValue` bug)
- `src/spicelib/devices/vsrc/vsrctemp.c:25-176` — port promotion, defaults, ordering, validation
- `src/spicelib/devices/vsrc/vsrcset.c:53-92`, `:118-123` — the `#res` internal node
- `src/spicelib/devices/vsrc/vsrcload.c:44-72`, `:453-459` — DC/tran stamping and `PORT` waveform
- `src/spicelib/devices/vsrc/vsrcacld.c:15-88` — `VSRCspinit`, `VSRCspupdate`, `VSRCgetActivePorts`;
  `:103-158` — AC stamping with the port conductance
- `src/spicelib/devices/vsrc/vsrcbindCSC.c:30,91,147` — KLU bindings for the port nodes
- `src/spicelib/analysis/nevalsrc.c:30-38, 43-94, 159-226, 269-321` — SP noise accumulation
- `src/osdi/osdinoise.c:27-35, 135-...` — the same for OSDI/Verilog-A models
- `src/maths/ni/niaciter.c:22-...` — `NIspPreload`, `NIspSolve`
- `src/spicelib/devices/cktinit.c:138-147` — zeroing of the RF state
- `src/spicelib/analysis/cktdest.c:117-126` — freeing of the RF state
- `src/include/ngspice/cktdefs.h:194-195` (`MODESP`, `MODESPNOISE`), `:285-298` (RF fields)
- `src/include/ngspice/tskdefs.h:32-34` — `DOING_SP`
- `src/include/ngspice/noisedef.h:121-138` — the `NOISE_ADD_OUTVAR` override
- `src/include/ngspice/ipc.h:115-117` — `IPC_ANAL_SP`
- `src/include/ngspice/acdefs.h:28-42` — step-type enum guard

**PSS, compiled when `WITH_PSS`:**
- `src/spicelib/analysis/dcpss.c` — `DCpss` (1485 lines) and the private `DFT`
- `src/spicelib/analysis/psssetp.c` — `PSSsetParm`, `PSSparms[]`, `PSSinfo`
- `src/spicelib/analysis/pssaskq.c` — `PSSaskQuest`
- `src/spicelib/analysis/pssinit.c` — `PSSinit` (the option overrides)
- `src/include/ngspice/pssdefs.h` — `PSSan` struct, parameter ids

**Shared front-end plumbing (both):**
- `src/spicelib/analysis/analysis.c` — `analInfo[]` and the enumeration helpers
- `src/spicelib/analysis/cktdojob.c:176-211` — analysis dispatch order
- `src/spicelib/parser/inp2dot.c` — `dot_pss` (`:653-711`), `dot_sp` (`:718-750`),
  `dot_hb` (`:754-811`), dispatch (`:906-925`)
- `src/frontend/runcoms.c:187-203` — `com_pss`, `com_sp`
- `src/frontend/commands.c:324-338` (spcp), `:837-844` (nutcp) — registration
- `src/frontend/spiceif.c:257-292`, `:388-411` — command→analysis routing
- `src/frontend/shyu.c:278-397` — the `.sens`-embedded (dead) SP/PSS/HB blocks
- `src/frontend/outitf.c:1022-1082` — `guess_type`, the name→type table for SP vectors
- `src/frontend/typesdef.c:67-90` — `plotabs[]`, which maps analysis names to `sp`/`pss` prefixes
- `src/frontend/postcoms.c:762-...` + `src/frontend/rawfile.c:921-1020` — `wrs2p` / `spar_write`

**Examples:** `examples/sp/` (6 decks + a `.s2p` + a `.lib`), `examples/pss/` (13 decks).
**Tests:** none for either.
