# Dossier: Measurements and Analysis Post-Processing
## The ADE "Outputs / Measurements" surface in ngspice

Tree: `/home/analog/dev/ngspice`, branch `ver_50`, `git describe = ngspice-46-419-gccebdf2a2`.
Binary exercised: `/home/analog/dev/ngspice/build-ver_50/src/ngspice` (self-reports `ngspice-46+`,
build `Thu Sep  3 06:46:24 UTC 2026`, "Compiled with KLU Direct Linear Solver").
Scratch decks used for every literal transcript below live in
`/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/measwork/`.

Official documentation consulted: the ngspice manual PDF at
<https://ngspice.sourceforge.io/docs/ngspice-manual.pdf> (chapter 11.4 "Measurements after AC, DC
and transient analysis"; 13.5.33 fft; 13.5.35 fourier; 13.5.45 linearize; 13.5.49 meas; 13.5.59 psd;
13.5.89 spec; 13.7 internally predefined variables). Where the manual and this tree disagree the
disagreement is called out explicitly and the **source + empirical behaviour is trusted**, because a
GUI is driving *this* binary.

---

# 0. Executive orientation for the GUI author

ngspice's "Outputs" surface is **four unrelated mechanisms** that a GUI must present as one:

| Mechanism | Produces | Lives where | Read back how |
|---|---|---|---|
| `.meas`/`.measure` **card** | one scalar, printed | stdout + optional `measoutfile`; also a numparam `.param` | parse text, or `set measoutfile` |
| `meas` **command** (in `.control`/interactive) | one scalar, printed **and** a length-1 vector | current plot | `print`, `write`, `$&name`, redirect `meas ... > file` |
| `.four` / `fourier` | printed harmonic table + `fourierMN` (3×nfreqs) and `thdMN` vectors | current plot | index the 2-D vector |
| `fft` / `psd` / `spec` | a whole new **plot** of complex spectra | new plot named `spN` | `plot`, `wrdata`, `write`, or `meas sp` on it |

The single most consequential fact: **`.meas` cards do not create vectors; the `meas` command
does.** A GUI that wants machine-readable numbers should prefer the `meas` command inside a
`.control` block, or `set measoutfile`.

---

# 1. `.meas` / `meas`: files, entry points, control flow

## 1.1 Where the code is

| File | Role |
|---|---|
| `src/frontend/measure.c` | `.meas` **card** driver (`do_measure`), interactive `meas` **command** (`com_meas`), autostop hook |
| `src/frontend/com_measure2.c` | the whole measurement engine and grammar (`get_measure2`) — 2176 lines |
| `src/frontend/com_measure2.h` | 3 exported symbols only: `measure_get_precision`, `get_measure2`, `measure_extract_variables` |
| `src/frontend/dotcards.c:149` | `.meas` cards are scanned at save time (`ft_savedotargs`) so their vectors get saved |
| `src/frontend/inp.c:1142` | `.meas` cards are **removed from the deck** and chained onto `ft_curckt->ci_meas` |
| `src/frontend/inpcom.c:7715` | `par('expr')` inside a `.meas` **card** → auto-generated B source |
| `src/frontend/inpcom.c:10592` | `inp_meas_control()` — auto `let`/`unlet` rewrite of `meas` commands **inside a deck's `.control`** |
| `src/frontend/subckt.c:405` | the numparam deferral that makes `param=` work and `expr=` fail |
| `src/frontend/runcoms.c:389` | `do_measure(ft_curckt->ci_last_an, FALSE)` after every `run` |

## 1.2 Card extraction and evaluation order

* `.meas` cards are recognised by `ciprefix(".meas", …)` — so `.meas` and `.measure` both work.
  **`.measurement` does NOT** (verified: the deck aborts with `Error on line 7 or its substitute: /
  Error: incomplete or empty netlist`). Restrict a GUI to `.meas` or `.measure`.
* `src/frontend/inp.c:1142-1165` splices every `.meas` card out of the deck into
  `ft_curckt->ci_meas`. They are therefore never seen by the device parser.
* `src/frontend/runcoms.c:388-391`:
  ```c
  /* execute the .measure statements */
  if (!err && ft_curckt->ci_last_an && ft_curckt->ci_meas) {
      do_measure(ft_curckt->ci_last_an, FALSE);
  }
  ```
  `ci_last_an` is set in `src/frontend/outitf.c:227` from
  `spice_analysis_get_name(analysisPtr->JOBtype)` — the strings are `"OP"`, `"AC"`, `"DC"`,
  `"TRAN"`, `"PZ"`, `"TF"`, `"DISTO"`, `"NOISE"`, `"SENS"`, `"SP"` (see
  `src/spicelib/analysis/analysis.c:36-59` and e.g. `src/spicelib/analysis/transetp.c:74`,
  `acsetp.c:96`, `dctsetp.c:106`, `spsetp.c:103`).
  **Only the LAST analysis run's `.meas` cards are evaluated** (`measure.c:351`, `measure.c:446`
  skip a card whose analysis word does not match). See §1.9.
* `do_measure()` makes **two passes** (`measure.c:280` and `measure.c:412`). Pass 1 evaluates
  everything except `param`/`expr`; pass 2 evaluates `param`/`expr` via numparam, so a `param=`
  measurement can reference an earlier measurement's result.

## 1.3 The `.meas` card vs the `meas` command — the differences that matter

| | `.meas` card | `meas` command |
|---|---|---|
| Entry point | `do_measure()` `measure.c:212` | `com_meas()` `measure.c:37` |
| When it runs | automatically after `run` | when you type it |
| Result vector | **no** | **yes** — `com_let("<name> = %e", result)` `measure.c:138` |
| Result as `.param` | **yes** — `nupa_add_param(resname, result)` `measure.c:379,495` | no |
| `param=` / `expr=` | `param=` yes, `expr=` broken (§1.7) | not supported at all |
| `par('expr')` | yes (auto B source) | **not supported** |
| Whitespace after `=` | tolerated (§1.6) | **rejected** (§1.6) |
| `measoutfile` | honoured | ignored |
| `>` / `>>` redirection | no | yes (it's a normal command) |
| autostop | yes (`.option autostop`) | no |
| Blocked by `-b -r rawfile` | **yes** (`measure.c:242`) | no |
| SP analysis | works (§1.9) — contradicting the manual | works |

Registered in `src/frontend/commands.c:395`:
```c
{ "meas", com_meas, FALSE, TRUE,
  { 0, 0, 0, 0 }, E_DEFHMASK, 1, LOTS,
  NULL,
  "various ... : User defined signal evaluation." } ,
```

## 1.4 The COMPLETE grammar

Common shape (`com_measure2.c:1676-1717` tokenises positionally):

```
[.]meas[ure] <analysis> <result_name> <function> <function-specific tail>
             ^wl_cnt 0  ^wl_cnt 1     ^wl_cnt 2
```

### 1.4.1 Analysis word — `<analysis>`

`chkAnalysisType()` `measure.c:146-154`:
```c
/* only support tran, dc, ac, sp analysis type for now */
if (!cieq(an_type, "tran") && !cieq(an_type, "ac") &&
        !cieq(an_type, "dc") && !cieq(an_type, "sp"))
```
Legal: **`tran`, `dc`, `ac`, `sp`** — case insensitive. Anything else is a hard error.

Verified (`antypes.sp`, one `.meas` per unsupported type):
```
Error: unrecognized analysis type 'noise' for the following .meas statement on line 12:
       .meas noise n1 max v(2)
Error: unrecognized analysis type 'op' for the following .meas statement on line 13:
Error: unrecognized analysis type 'pz' for the following .meas statement on line 14:
Error: unrecognized analysis type 'tf' for the following .meas statement on line 15:
Error: unrecognized analysis type 'sens' for the following .meas statement on line 16:
Error: unrecognized analysis type 'disto' for the following .meas statement on line 17:
```
So **noise, pz, tf, sens, disto, op, pss, hb are NOT measurable**. A GUI must grey out the
measurement panel (or offer only control-language post-processing) for those analyses.

`get_measure2()` additionally requires the *current plot* to be one of those four
(`com_measure2.c:1661-1668`):
```c
if (!ciprefix("tran", plot_cur->pl_typename) && !ciprefix("ac", …) &&
    !ciprefix("dc", …) && !ciprefix("sp", …))
    fprintf(cp_err, "Error: measure limited to tran, dc, sp, or ac analysis\n");
```
The `sp` prefix also matches **`spectrum` plots created by `fft`/`psd`/`spec`** — see §4.6. That
is deliberate and is how you measure on a spectrum.

### 1.4.2 Function word — `<function>`

`measure_function_type()` `com_measure2.c:207-257`, matched with `strcasecmp` (exact word, no
abbreviation):

| Word | Enum | Implemented? | Notes |
|---|---|---|---|
| `TRIG` | `AT_DELAY` | yes | must be followed later by `TARG` |
| `TARG` | `AT_DELAY` | yes | (as the second half of TRIG…TARG) |
| `DELAY` | `AT_DELAY` | yes | synonym for `TRIG` |
| `FIND` | `AT_FIND` | yes | `FIND x AT=…` or `FIND x WHEN …` |
| `WHEN` | `AT_WHEN` | yes | |
| `AVG` | `AT_AVG` | yes | trapezoid, time-weighted |
| `MIN` | `AT_MIN` | yes | prints `at=` |
| `MAX` | `AT_MAX` | yes | prints `at=` |
| `MIN_AT` | `AT_MIN_AT` | yes | returns the *scale* value; prints `with=` |
| `MAX_AT` | `AT_MAX_AT` | yes | returns the *scale* value; prints `with=` |
| `RMS` | `AT_RMS` | yes | |
| `PP` | `AT_PP` | yes | max−min in window |
| `INTEG` | `AT_INTEG` | yes | Simpson 3/8 → 1/3 → trapezoid |
| `DERIV` | `AT_DERIV` | **NO** | rejected at runtime |
| `ERR` `ERR1` `ERR2` `ERR3` | `AT_ERR…` | **NO** | rejected at runtime |
| `param` / `param=` | (handled in `measure.c`) | yes, **card only** | numparam expression |
| `expr` / `expr=` | (handled in `measure.c`) | **BROKEN**, see §1.7 | |

`INTEGRAL` and `DERIVATIVE` (documented as `INTEG<RAL>` / `DERIV<ATIVE>` in manual §11.4.8 /
§11.4.11) are **not accepted**: `measure_function_type()` compares whole words.

Verified (`meas_tran.sp`):
```
	measure 'm_integral'  failed
Error: measure  m_integral  :
	no such function as 'integral'

Error: measure  m_deriv failed:
	function 'deriv' currently not supported

Error: measure  m_err failed:
	function 'err' currently not supported
```
Source for the deriv/err rejection: `com_measure2.c:2156-2166`.

**Doc-vs-source conflict #1** — the manual documents `DERIV<ATIVE>` with three general forms and
`INTEG<RAL>`. This tree implements neither `DERIV` nor `INTEGRAL`. Trust the source. (The manual
hedges in §11.4.3: *"Please note that not all of the .measure commands have been implemented."*)
A GUI must **not** offer a `deriv` measurement; offer `let d = deriv(v(out))` + `meas … FIND d AT=…`
instead (verified working).

### 1.4.3 Qualifiers (`measure_parse_stdParams`, `com_measure2.c:1289-1390`)

Parsed as `NAME=VALUE` with `strtok(p,"=")`; the name match is `strcasecmp`.

| Qualifier | Value | Effect | Source |
|---|---|---|---|
| `VAL=<real>` | number or `'expr'` (numparam-expanded in a card) | threshold for TRIG/TARG/WHEN | `:1343` |
| `TD=<real>` | number | ignore data below this scale value — **TRAN only, and only in WHEN/TRIG/TARG** | `:1345`, applied `:501` |
| `FROM=<real>` | number | window start | `:1347` |
| `TO=<real>` | number | window end; **`TO=0` means "no limit"** | `:1349`, `:516` |
| `AT=<real>` | number | point measurement | `:1351` |
| `RISE=<n>` or `RISE=LAST` | int or `LAST` | count rising crossings; sets `m_fall=m_cross=-1` | `:1331` |
| `FALL=<n>` or `FALL=LAST` | int or `LAST` | count falling crossings; sets `m_rise=m_cross=-1` | `:1335` |
| `CROSS=<n>` or `CROSS=LAST` | int or `LAST` | count crossings of either slope | `:1339` |
| bare `LAST` | (no `=`) | equivalent to `CROSS=LAST` | `:1308-1314` |

`LAST` is `MEASURE_LAST_TRANSITION = -2`; "not given" is `MEASURE_DEFAULT = -1`
(`com_measure2.c:26-27`).

Any other name is a hard error: `com_measure2.c:1354` → `"no such parameter as '%s'"`.

**Qualifier defaults** (set in `measure_parse_find:1408-1424`, `measure_parse_when:1482-1499`,
`measure_parse_trigtarg:1564-1579`):

| Field | tran / ac / sp default | dc default |
|---|---|---|
| `m_val` | **0.0** (calloc; `measure_parse_trigtarg` never assigns it) | 0.0 |
| `m_td` | 0.0 | 0.0 (then **overwritten** by the first scale value, `:497-499`) |
| `m_from` | 0.0 | **−1.0e99** |
| `m_to` | 0.0 → "no limit" | **+1.0e99** |
| `m_at` | 1e99 sentinel = "not given" | 1e99 |
| `m_rise/m_fall/m_cross` | −1 = not given | −1 |

`TMALLOC` is `calloc` (`src/misc/alloc.c:70`), which is why `m_val` defaults to 0.

Verified defaults (`noval.cmd`):
```
== TRIG with no VAL (defaults to 0) ==
n1                  =  1.00000e-03 targ=  2.00000e-03 trig=  1.00000e-03
== explicit VAL=0 ==
n2                  =  1.00000e-03 targ=  2.00000e-03 trig=  1.00000e-03
== WHEN with no cross/rise/fall ==
n3                  =  8.33442e-05
== to=0 means no limit ==
n4                  =  9.99961e-01 at=  9.25140e-03
== negative from ==
n5                  =  9.99961e-01 at=  2.51400e-04
== TD on AVG (ignored) ==
n6                  =  2.13954e-10 from=  0.00000e+00 to=  1.00000e-02
n7                  =  -1.23274e-06 from=  5.00000e-03 to=  1.00000e-02
== LAST bare keyword ==
n8                  =  9.41666e-03
```
`n6` vs `n7` is the proof that **`TD=` is silently ignored by `AVG` (and by `MIN`, `MAX`, `MIN_AT`,
`MAX_AT`, `PP`, `RMS`, `INTEG`)**: only `FROM=` restricts the window there. `TD=` is honoured only
by `com_measure_when()` (`com_measure2.c:501`), i.e. by `WHEN`, `TRIG` and `TARG`, and there only
for `tran`. This is not in the manual. A GUI should either map its "delay" field to `FROM=` for the
statistic measurements, or grey `TD` out for them.

### 1.4.4 Per-function grammar and printed output format

All literal formats from `com_measure2.c`. `precision` = `measure_get_precision()`
(default 5, §1.8). `mName` is `%-20s`.

**TRIG…TARG (delay)** — `com_measure2.c:1744-1841`
```
[.]meas <an> <name> TRIG <vec> [VAL=v] [TD=t] [RISE=n|FALL=n|CROSS=n|LAST]
                    TRIG AT=<t>
               TARG <vec> [VAL=v] [TD=t] [RISE=n|FALL=n|CROSS=n|LAST]
               TARG AT=<t>
```
Constraint (`:1760-1765`, `:1779-1784`): *each* of TRIG and TARG must supply **at least one of
`AT=`, `RISE=`, `FALL=`, `CROSS=`**, else `"at, rise, fall or cross must be given"`.
Result = `targ − trig`. Format:
```c
"%-20s=  %.*e targ=  %.*e trig=  %.*e\n"
```
Live:
```
m_trig              =  1.00000e-03 targ=  1.08334e-03 trig=  8.33429e-05
```

**FIND … AT= / FIND … WHEN …** — `:1842-1914`
```
[.]meas <an> <name> FIND <vec> AT=<val>
[.]meas <an> <name> FIND <vec> WHEN <vec2>=<val|vec3> [TD=] [FROM=] [TO=] [RISE=|FALL=|CROSS=|LAST]
```
Format `"%-20s=  %.*e\n"`. Live: `m_findat            =  -1.14090e+00`

**WHEN** — `:1915-1952`
```
[.]meas <an> <name> WHEN <vec>=<val>          [TD=] [FROM=] [TO=] [RISE=|FALL=|CROSS=|LAST]
[.]meas <an> <name> WHEN <vec>=<vec2>         [TD=] [FROM=] [TO=] [RISE=|FALL=|CROSS=|LAST]
```
Card format `"%-20s=   %.*e\n"` (three spaces), command format `"%-20s=  %.*e\n"` (two).
Live: `m_when              =   4.88982e-03`

**AVG** — `:1998-2043`, format `"%-20s=  %.*e from=  %.*e to=  %.*e\n"` where `from` is `m_at`
(which is `m_from` when `AT` was not given, `:2020-2021`) and `to` is `m_measured_at`.
⚠ For `AVG` the printed `to=` is **the last scale value the loop touched, not the requested `to=`**
(`measure_minMaxAvg` sets `meas->m_measured_at = svalue` after the loop, `com_measure2.c:951`).
Seen in the DC test: `meas dc d6 AVG i(vs) from=1 to=2` printed
`d6                  =  4.62103e-03 from=  1.00000e+00 to=  3.50000e+00`.
The *value* respects `to=`; only the echoed `to=` is wrong. Do not parse that field.

**MIN / MAX** — `:2044-2091`, format `"%-20s=  %.*e at=  %.*e\n"`; result = the extremum.
**MIN_AT / MAX_AT** — same block, format `"%-20s=  %.*e with=  %.*e\n"`; result = the *scale*
value at the extremum.
```
m_max               =  1.19985e+00 at=  2.50280e-03
m_maxat             =  2.50280e-03 with=  1.19985e+00
```

**PP** — `:2104-2154`, `"%-20s=  %.*e from=  %.*e to=  %.*e\n"`, result = max−min.
**RMS / INTEG** — `:1953-1997`, `"%-20s=   %.*e from=  %.*e to=  %.*e\n"` (card) /
`"%-20s=  %.*e from=  %.*e to=  %.*e\n"` (command). Here `from`/`to` **are** rewritten to the
actual integration limits (`com_measure2.c:1157-1158`), so they are trustworthy.

**param=** — handled entirely in `measure.c:472-504` (numparam), format
`"%-20s=" … "  %.*e\n"`.

Full literal transcript of one run over every implemented type (`meas_tran.sp`,
two 1 kHz / 0.9 kHz sines, `.tran 10u 5m`):
```
  Measurements for Transient Analysis

m_trig              =  1.00000e-03 targ=  1.08334e-03 trig=  8.33429e-05
m_delay             =  -7.31321e-06 targ=  7.60297e-05 trig=  8.33429e-05
m_when              =   4.88982e-03
m_when2             =   3.94211e-03
m_find              =  1.08166e+00
m_findat            =  -1.14090e+00
m_max               =  1.19985e+00 at=  2.50280e-03
m_maxat             =  2.50280e-03 with=  1.19985e+00
m_min               =  -1.13525e+00 at=  2.00280e-03
m_minat             =  2.00280e-03 with=  -1.13525e+00
m_pp                =  1.99969e+00 from=  2.00000e-03 to=  4.00000e-03
m_rms               =   7.07118e-01 from=  2.00000e-03 to=  3.50000e-03
m_avg               =  6.94259e-05 from=  2.00000e-03 to=  4.00280e-03
m_integ             =   1.31162e-04 from=  2.00000e-03 to=  3.00000e-03
m_param             =  1.20000e+01
m_expr              =   failed
m_par               =  4.85349e-01
m_td                =  6.84988e-09 from=  0.00000e+00 to=  5.00000e-03
```
Header banners (`measure.c:320-339`), one per run, printed before the first card:
```
  Measurements for Transient Analysis
  Measurements for DC Analysis
  Measurements for AC Analysis
  Measurements for SP Analysis
```
⚠ The banner is chosen from the **first `.meas` card in the deck**, not from the analysis actually
run. A deck with `.meas ac …` first and `.meas tran …` second, run as `tran`, prints
`Measurements for AC Analysis` and then only the tran result. Verified (`two4.sp`):
```
  Measurements for AC Analysis
trmax               =  9.99922e-01 at=  2.49287e-04
```

### 1.4.5 What each function uses as the independent (scale) vector

| Function | tran | ac / sp | dc |
|---|---|---|---|
| `WHEN`,`TRIG`,`TARG`,`FIND…AT` | `plot_cur->pl_scale` (`:409`, `:684`) | same | same |
| `MIN/MAX/AVG/PP/MIN_AT/MAX_AT` | `vec_get("time")` `:818` | `vec_get("frequency")` `:811` | `v-sweep` → `i-sweep` → `temp-sweep` → `res-sweep` `:825-833` |
| `RMS/INTEG` | `vec_get("time")` `:1022` | `vec_get("frequency")` `:1015` | same four `-sweep` names `:1029-1038` |

So the DC sweep scale a GUI must expect is one of exactly `v-sweep`, `i-sweep`, `temp-sweep`,
`res-sweep` (error text at `com_measure2.c:1041`:
`" no such scale vector as v-sweep, i-sweep, temp-sweep, or res-sweep."`).

`MIN/MAX/AVG/PP` also require `d->v_length == dScale->v_length`, else
`"Error: length of scale vector (%s) does not match length of data vector (%s)."`
(`com_measure2.c:850-454`, i.e. `:850`). That fires when you `let` a shorter vector.

### 1.4.6 AC/SP vector-type prefixes

`correct_vec()` `com_measure2.c:111-133` peels a one-letter type off a `v?(…)` token, **only when
the analysis word is `ac` or `sp`** (`:1433`, `:1516`, `:1589`). `get_value()` `:137-162` then maps:

| Token | letter | value returned |
|---|---|---|
| `v(node)` | (none) | **real part** — *not* magnitude |
| `vm(node)` | m | `hypot(re,im)` magnitude |
| `vr(node)` | r | real |
| `vi(node)` | i | imaginary |
| `vp(node)` | p | `radtodeg(atan2(im,re))` — see below |
| `vdb(node)` | d | `20*log10(hypot(re,im))` |

Verified on a 1 k/1 n RC at 100 kHz (`acmeas.cmd`):
```
a1                  =  7.16957e-01     <- v(out)   (real part)
a2                  =  8.46733e-01     <- vm(out)
a3                  =  7.16957e-01     <- vr(out)
a4                  =  -4.50477e-01    <- vi(out)
a5                  =  -5.60982e-01    <- vp(out)
a6                  =  -1.44507e+00    <- vdb(out)
```

⚠ **Only `v`-prefixed forms are handled.** `im()`, `ip()`, `idb()` do not exist:
```
Error: no such vector as im(vin).
 meas ac b2 FIND im(vin) AT=100k failed!
Error: no such vector as idb(vin).
 meas ac b3 FIND idb(vin) AT=100k failed!
```
Workaround the GUI must generate: `let x = db(i(vin))` then `meas ac … FIND x AT=…` (verified:
`c1 = -1.44507e+00`, identical to `vdb`).

⚠ **`vp()` returns RADIANS by default.** `radtodeg()` is
`#define radtodeg(c) (cx_degrees ? ((c) * (180 / M_PI)) : (c))`
(`src/include/ngspice/complex.h:73`) and `bool cx_degrees = FALSE;`
(`src/maths/cmaths/cmath1.c:42`). It flips to degrees only via `set units=degrees`
(`src/frontend/options.c:419-423`; any string starting with `d`/`D`). The comment
`/* phase (in degrees) */` at `com_measure2.c:156` is **wrong for the default configuration**.
Verified:
```
== default (radians) ==
p1                  =  -5.60982e-01
ph(v(out))[40] = -5.60982e-01
== set units=degrees ==
p2                  =  -3.21419e+01
ph(v(out))[40] = -3.21419e+01
```
Note `.four` phase is **always degrees** (`fourier.c:354` uses `*180.0/M_PI` literally, bypassing
`radtodeg`), so `.four` and `vp()` disagree unless `units=degrees` is set. A GUI must label the
phase unit from `units`, and probably should `set units=degrees` at start-up for ADE-like behaviour.

### 1.4.7 DC-specific semantics

`com_measure_when` treats DC specially (`com_measure2.c:495-522`):
* `m_td` is hijacked to store the first scale value (`:497-499`) — a `TD=` on a DC measurement is
  overwritten and meaningless.
* `from`/`to` are a *closed* interval (`continue` on both sides), not "break at `to`".
* `measure_parse_stdParams:1384-1387` swaps `from`/`to` if `to < from` for DC only.
* A nested sweep restarts `v-sweep`; `first` is reset when the scale returns to its origin
  (`:519-521`), so `RISE=n` counts **across sweep branches** — this is exactly what the shipped
  `examples/measure/mos-meas-dc-control-file.sp` exploits.

Verified DC (`dcsweep.sp` + `dc vds 0 3.5 0.05 vgs 3.5 0.5 -0.5`, 497 rows, scale `v-sweep`):
```
d1                  =  7.65900e-03            FIND i(vs) AT=1
d2                  =  1.30536e-02 at=  3.50000e+00     MAX i(vs)
d3                  =  1.44582e+00            WHEN i(vs)=10m
d4                  =  8.45130e-01 targ=  1.44582e+00 trig=  6.00690e-01
d6                  =  4.62103e-03 from=  1.00000e+00 to=  3.50000e+00
d7                  =  1.01788e-02 from=  1.00000e+00 to=  2.00000e+00
d8                  =  1.01010e-02 from=  1.00000e+00 to=  2.00000e+00
d9                  =  3.50000e+00 with=  0.00000e+00
Error: measure  d5  TRIG(TARG) : out of interval
 meas dc d5 TRIG i(vs) VAL=0.005 RISE=2 TARG i(vs) VAL=0.01 RISE=2 failed!
```

## 1.5 CRASH: `meas sp` on a real `.sp` analysis segfaults

**This is a genuine defect in this tree and a GUI must not step on it.**

The `frequency` scale of a real `.sp` (RFSPICE) run is **complex**
(`display` shows `frequency : frequency, complex, 100 long`), but
`com_measure_when()`'s SP branch reads `v_realdata` unconditionally:

`src/frontend/com_measure2.c:466-471`
```c
        } else if (sp_check) {
            if (d->v_compdata)
                value = get_value(meas, d, i); //d->v_compdata[i].cx_real;
            else
                value = d->v_realdata[i];
            scaleValue = dScale->v_realdata[i];      /* <-- NULL deref */
```
and `measure_rms_integral()` has **no SP branch at all**, so SP falls into the `else` at
`src/frontend/com_measure2.c:1073` → `xvalue = xScale->v_realdata[i];` → same NULL deref.

Empirical (`sp_one.cir`, `.sp lin 100 1e8 1e9 1`; exit status of the process):
```
########## meas sp w1 WHEN S_1_1=0.5                                  => Segmentation fault  exit=139
########## meas sp r1 RMS S_2_1                                       => Segmentation fault  exit=139
########## meas sp i1 INTEG S_2_1                                     => Segmentation fault  exit=139
########## meas sp a1 AVG S_2_1                                       => exit=0
########## meas sp p1 PP S_2_1                                        => exit=0
########## meas sp t1 TRIG S_1_1 VAL=0.5 RISE=1 TARG S_2_1 VAL=0.1 RISE=1 => Segmentation fault  exit=139
```
`measure_at()` (`:727-739`) and `measure_minMaxAvg()` (`:864-874`) *do* test `v_compdata` first,
which is why `FIND … AT=`, `MAX`, `MIN`, `MAX_AT`, `MIN_AT`, `AVG`, `PP` survive:
```
s21max              =  6.46026e-04 at=  1.00000e+08
s21at               =  2.58705e-05
```
**GUI rule: on an S-parameter plot allow only `FIND…AT=`, `MIN/MAX/MIN_AT/MAX_AT`, `AVG`, `PP`.
Block `WHEN`, `TRIG…TARG`, `RMS`, `INTEG` — they take the whole simulator down.**
(On an *fft/spec/psd* spectrum plot, whose `frequency` is real, all of them are safe — see §4.6.)

## 1.6 Whitespace around `=` — cards forgive, commands do not

`measure_parse_line()` (`measure.c:546-582`) joins a token that ends in `=` with the following
token, so **the card tolerates `VAL= 0.5`**. `com_meas()` does no such joining.

Separately, `inp_remove_ws()` (`src/frontend/inpcom.c:4296-4340`) strips whitespace around `=` on
**every deck line, including lines inside `.control`** (`inpcom.c:4400-4411`; only `echo` lines are
exempted). So a `meas` command *written in a deck* also gets its spaces removed, and works.

But a `meas` command **typed at the prompt, piped in with `-p`, or sent via
`ngSpice_Command()` does not go through `inp_remove_ws()`**. Verified in `-p` pipe mode:
```
== space after = , product ==
Error: measure  s1  FIND(WHEN) : bad syntax
 meas tran s1 FIND v(2) WHEN v(1)= 0.9*v(2) failed!
== let vint then use it ==
Error: measure  s2  FIND(WHEN) : bad syntax
 meas tran s2 FIND v(2) WHEN v(1)= vint failed!
== no space, using vint ==
s3                  =  8.83923e-01
== VAL with space ==
Error: measure  s4  TRIG(TRIG) : bad syntax. equal sign missing ?
 meas tran s4 TRIG v(1) VAL= 0.5 RISE=1 TARG v(1) VAL= 0.5 RISE=2 failed!
```
**GUI rule: always emit `KEY=VALUE` with no surrounding whitespace.**

## 1.7 Expressions in a measurement — four different rules

There are FOUR expression paths and they have different capabilities. This is the most confusing
part of the surface and the GUI should hide it entirely behind one field.

### (a) `.meas … param='<expr>'` — card, numparam, works, **but only once per circuit load**

Deferred to pass 2 so it can see earlier measurement results
(`src/frontend/subckt.c:402-409`):
```c
    for (c = deck; c; c = c->nextcard)
        /* 'param' .meas statements can have dependencies on measurement values */
        /* need to skip evaluating here and evaluate after other .meas statements */
        if (ciprefix(".meas", c->line) && cistrstr(c->line, "param")) {
            ;
        } else {
            nupa_eval(c);
        }
```
Chaining verified (`chain.sp`):
```
vmax                =  9.99845e-01 at=  2.52800e-04
vmin                =  -9.99845e-01 at=  7.52800e-04
vspan               =  1.99969e+00     <- param='vmax - vmin'
vhalf               =  9.99845e-01     <- param='vspan/2'
chk                 =  1.00000e+00     <- param='(vspan > 1.5) ? 1 : 0'
```

⚠ **`param=` fails on every run after the first in the same session.** The numparam placeholder is
consumed by the first `nupa_eval()`; the second call finds nothing to substitute
(`insertnumber()` `src/frontend/numparam/xpressn.c:1441-1446`). Verified (`rerun.sp`, two `run`s in
one `.control`):
```
  Measurements for Transient Analysis
mx                  =  9.99845e-01 at=  2.52800e-04
mp                  =  6.00000e+00
===== SECOND RUN =====
Error in netlist line no. 8, new internal line no. 7:
insertnumber: fails.
  s = ".meas tran mp param=    6.000000000000000e+00   " u="  6.000000000000000e+00  " id=0
  Measurements for Transient Analysis
mx                  =  9.99845e-01 at=  2.52800e-04
mp                  =   failed
```
**GUI rule: if the GUI re-runs a circuit in the same ngspice session (a sweep, a corner loop, an
iterative tune), it must `source` the deck again before each run, or avoid `.meas param=`
entirely and compute derived scalars in the control language.**

### (b) `.meas … expr='<expr>'` — card — **BROKEN in this tree**

`subckt.c:405` defers only lines containing the substring `"param"`. An `expr=` line is
substituted at read time *and again* by `do_measure`'s pass 2 (`measure.c:479 nupa_eval(meas_card)`),
and the second substitution has no placeholder left. Verified (`meas_expr.sp`):
```
Error in netlist line no. 8, new internal line no. 7:
insertnumber: fails.
  s = ".measure tran e1 expr=    1.200000000000000e+01   " u="  1.200000000000000e+01  " id=0
  Measurements for Transient Analysis
e1                  =   failed          <- expr='fval + 7'
e2                  =   failed          <- expr = 'fval + 7'
e3                  =  1.20000e+01      <- param='fval + 7'
e4                  =  1.00000e+00      <- param='(fval < 10) ? 1 : 0'
e5                  =  2.23607e+00      <- param='sqrt(fval)'
e6                  =  5.00000e+00      <- param=fval
```
`measure.c:343` and `:453` both list `expr` as a legal type, so the intent was there. **GUI rule:
never emit `expr=`; always emit `param=`.**
Corollary hazard: the deferral test is `cistrstr(c->line, "param")`, so any `.meas` line that merely
*contains* the letters `param` (a node named `param_out`, a result named `vparam`) is silently
skipped in the first numparam pass and may misbehave.

### (c) `.meas … par('<expr>')` — card — works, **mutates the netlist**

`src/frontend/inpcom.c:7711-7760` replaces `par('expr')` with `v(pa_NN)` and injects a B source
`b pa_NN pa_NN 0 v = <expr>`. Hard limit **99 `par()` calls per input file**
(`inpcom.c:7721-7727`: `"ERROR: More than 99 function calls to par()"`).

Verified — the extra node and B-source branch appear in the operating point of `parprint.sp`
(`.print tran v(1) pwr=par('v(1)*v(2)') v(1,2)` and `.four 1k par('v(1)+v(2)')`):
```
Node                                   Voltage
----                                   -------
1                                            0
2                                            0
pwr                                          0
pa_01                                        0
bpa_01#branch                                0
bpwr#branch                                  0
```
Note that `.print`/`.plot`/`.save`/`.four` accept the **named** form `name=par('expr')`, which
creates a node with *that* name (`pwr` above); `.meas` accepts the anonymous `par('expr')` form,
which creates `pa_NN`.
The measurement itself works: `m_par = 4.85349e-01` for
`.measure tran m_par FIND par('v(2)*v(1)') AT=2.3m`.
**GUI consequence: an expression written into a dot card changes the netlist — extra nodes, extra
branch currents, extra rows in the OP printout, extra entries in `display`.** If the GUI shows the
user a node list it must filter `pa_\d\d` / `b*#branch` or explain them.

### (d) `meas` command with an arithmetic RHS — works **only from a deck's `.control`**

`inp_meas_control()` `src/frontend/inpcom.c:10592-10647` rewrites, at read time:
```
   meas tran yeval2 FIND v(2) WHEN v(1)= 0.9*v(2)
becomes
   let vexprint1 = 0.9*v(2)
   meas tran yeval2 FIND v(2) WHEN v(1)=vexprint1
   unlet vexprint1
```
(comment quoted verbatim from `inpcom.c:10584-10591`). The trigger is
`ciprefix("meas", curr_line) && find_assignment(...)` plus `str_has_arith_char(token)`, and it only
runs for lines between `.control` and `.endc` of a **sourced file**.

Typed/piped/shared-library `meas` commands get none of this. Verified in `-p` mode:
```
Error: measure  e1  FIND(WHEN) : Expressions like 0.9*v(2) are not supported.
Error: measure  e2  FIND(WHEN) : Cannot evaluate v(2)+0.1
Error: measure  e4  FIND(WHEN) : Expressions like par(0.9*v(2)) are not supported.
```
The rejection is `measure_parse_when()` `com_measure2.c:1524-1532`, gated by
`str_has_arith_char2()` (`com_measure2.c:63-79`), whose arithmetic set is
`"*/<>?:|&^!%\\"` — note **`+` and `-` are NOT in that set**, which is why `v(2)+0.1` fails with
the different message "Cannot evaluate" (from `INPevaluate2`) rather than "not supported".

What *does* work everywhere:
* a length-1 vector on the RHS — `com_meas()` `measure.c:64-115` substitutes its numeric value;
* a pre-computed vector name — `let vint = 0.9*v(2)` then `WHEN v(1)=vint` (verified `s3`);
* an arithmetic `VAL=`/`FROM=`/`TO=`/`AT=` value — these go through `ft_numparse()`
  (`com_measure2.c:1325`) which *does* evaluate arithmetic:
  ```
  == C: VAL with expression ==
  e3                  =  1.05129e-03 targ=  1.08334e-03 trig=  3.20512e-05     (VAL=0.2*2)
  == E: from/to as expressions ==
  e5                  =  9.99845e-01 at=  1.25280e-03                          (from=1m*2)
  ```

**GUI rule (the one that matters): when driving ngspice over a pipe or `libngspice`, emit
`let <tmp> = <expression>` first and reference `<tmp>` in the `meas` line. Never rely on the
`.control` auto-rewrite.** The manual agrees for `par`/`param` (13.5.49: *"Unfortunately
par('expression') and param will not work here … You may use an expression by the let command
instead"*) but says nothing about the auto-`let` rewrite, which is this tree's own feature.

## 1.8 Precision — three separate knobs, and a silent truncation

| Knob | Affects | Default | Set where |
|---|---|---|---|
| `measureprec` (`set measureprec=N`) | the `%.*e` in every measurement *printout* | 5 | `src/frontend/options.c:392-400` → `measure_precision` |
| env `NGSPICE_MEAS_PRECISION` | same, lower priority | — | `com_measure2.c:88-89` |
| `numdgt` (`set numdgt=N`) | `print` output | 6 | `src/frontend/options.c:401` |

`measure_get_precision()` `com_measure2.c:82-95`:
```c
    int  precision = 5;
    if ((env_ptr = getenv("NGSPICE_MEAS_PRECISION")) != NULL)
        precision = atoi(env_ptr);
    if (measure_precision > 0)
        precision = measure_precision;
```

⚠ **The result VECTOR created by the `meas` command carries only ~7 significant digits, no matter
what `measureprec` says.** `measure.c:138`:
```c
    wl_let = wl_cons(tprintf("%s = %e", outvar, result), NULL);
```
`"%e"` is 6 decimal places. Verified (`prec2.cmd`, `set measureprec=14`, `set numdgt=16`):
```
mx                  =  9.99961311400234e-01 at=  9.25139999999971e-03
mx = 9.9996130000000005e-01
vecmax(v(1)) = 9.9996131140023437e-01
```
**GUI rule: for full precision, parse the printed line (with `measureprec` raised), not the
vector.** If the vector is the only route, accept 7 digits — usually fine, but not for a delay
measured in fs against a ns-scale time.

## 1.9 Analysis dispatch, multi-analysis decks, and the batch double-run

* `do_measure()` skips any card whose analysis word ≠ the *last* analysis run
  (`measure.c:351`, `:446`). A deck with `.ac` **and** `.tran` therefore evaluates only the
  `.tran` cards. Verified (`two4.sp` / `two5.sp`): only `trmax` appears.
* Worse, a `.meas ac …` card also registers an **AC-scoped save**
  (`dotcards.c:149` → `measure_extract_variables` → `com_save2(w, analysis)`,
  `com_measure2.c:355`), and `outitf.c:239` then ignores TRAN-scoped saves for the AC run. A deck
  with `.meas ac …` and `.print tran …` and nothing else can lose an analysis entirely:
  ```
  Error: no data saved for A.C. Small signal analysis; analysis not run
  ```
  and with `.print ac` added instead:
  ```
  Error: no data saved for Transient analysis; analysis not run
  ```
* `.meas ac … vm(out)` additionally produces a junk save token:
  ```
  Warning: can't parse 'vm': ignored
  ```
  (`src/frontend/outitf.c:437`) because `measure_extract_variables` → `gettoks()`
  (`dotcards.c:637`) mishandles the `vm(` prefix.

**GUI rule: one analysis per deck for dot-card measurements; for multi-analysis, drive each
analysis from a `.control` block and issue `meas` after each.** That route is clean — verified
(`multi.cmd`, pipe mode):
```
No. of Data Rows : 213
trmax               =  9.99922e-01 at=  2.49287e-04
Doing analysis at TEMP = 27.000000 and TNOM = 27.000000
No. of Data Rows : 81
acmax               =  9.99980e-01 at=  1.00000e+03
f3db                =  1.59156e+05
List of plots available:
Current ac1	* multi analysis control route (AC Analysis)
	tran1	* multi analysis control route (Transient Analysis)
	const	Constant values (constants)
```
(`f3db` there is `meas ac f3db WHEN vdb(out)=-3.0103` — the canonical ADE bandwidth measurement,
exact answer for a 1 k/1 nF RC is 159 155 Hz.)

**Batch double-run.** In `-b` mode, `src/main.c:1577-1583` runs the deck *again* if
`ft_savedotargs()` reports any `.print`/`.plot`/`.four`/`.op`/`.tf`/`.save`/`.meas` saves, even
when a `.control` block already ran it:
```c
        else if (ft_savedotargs()) {
            /* all dot card data to be put into dbs */
            int error2 = ft_dorun(NULL);
            if (ft_cktcoms(FALSE) || error2)
                sp_shutdown(EXIT_BAD);
        }
        else if (error3 == 0) {
            fprintf(stdout, "Note: Simulation executed from .control section \n");
```
So a deck with both `.meas` cards and `.control run` simulates **twice** in `-b` (three times if
`.control` runs twice). Combined with §1.7(a) this means the second pass reports
`param= … failed`. **GUI rule: do not mix `.meas` dot cards with a `.control run` in `-b`.**

Corollary the GUI must know: a deck whose **only** outputs are `param`-type `.meas` cards produces
no saves at all and batch mode refuses to run:
```
Error: incomplete or empty netlist
       or no ".plot", ".print", or ".fourier" lines in batch mode;
no simulations run!
```

## 1.10 `-r rawfile` blocks `.meas` cards

`measure.c:241-247`:
```c
    /* don't allow .meas if batchmode is set by -b and -r rawfile given */
    if (ft_batchmode && rflag) {
        fprintf(cp_err, "\nNo .measure possible in batch mode (-b) with -r rawfile set!\n");
        fprintf(cp_err, "Remove rawfile and use .print or .plot or\n");
        fprintf(cp_err, "select interactive mode (optionally with .control section) instead.\n\n");
```
Verified with `ngspice -b -r out.raw rawmeas.sp` — that exact text appears and no measurement
is printed. The `meas` **command** is unaffected (it calls `get_measure2` directly):
```
No .measure possible in batch mode (-b) with -r rawfile set!
...
cmdmax              =  9.99845e-01 at=  2.52800e-04
binary raw file "rr.raw"
```
This is the single most important reason a GUI should use `.control` + `write` rather than `-r`.

## 1.11 `autostop`

`.option autostop` + `.meas` cards → `check_autostop()` (`measure.c:533-542`) is called from
`dctran.c` on every accepted timepoint and stops the transient as soon as every measurement is
satisfiable. Verified (`autostop.sp`, `.tran 10u 10m` with `.meas tran t50 WHEN v(1)=0.5 RISE=1`):
```
No. of Data Rows : 58
Note: Autostop after 5.028000e-04 s, all measurement conditions are fulfilled.
  Measurements for Transient Analysis
t50                 =   5.00000e-04
```
`src/frontend/inp.c:1143-1153` **auto-disables** autostop if any `.meas` line contains
` max `, ` min `, ` avg `, ` rms ` or ` integ `:
```
Warning: .OPTION AUTOSTOP will not be effective because one of 'max|min|avg|rms|integ' is used in .meas
         AUTOSTOP being disabled...
```
Autostop is unavailable for the `meas` command (no dot cards ⇒ `ft_curckt->ci_meas == NULL`;
`measure.c:250-255` also warns `"Warning: No .meas commands found!"`).

---

# 2. Reading a measurement back out — the empirical answer

This is the question a GUI most needs settled. Five routes were tested; here is what each yields.

## Route A — `set measoutfile=<path>` (dot cards only)

`measure.c:257-263` opens the file with `"w"` (truncate) once per `do_measure()` call and mirrors
every line. Deck `readback.sp` with `set measoutfile = "$inputdir/measout.txt"` and
`set measureprec = 12`; resulting `measout.txt` **verbatim**:
```

  Measurements for Transient Analysis

dotmax              =  9.998452485945e-01 at=  1.252800000000e-03
dotpp               =  1.999690497189e+00 from=  1.000000000000e-03 to=  3.000000000000e-03

```
Format is stable and trivially parseable: `^(\S+)\s+=\s+(\S+)(?:\s+(\w+)=\s+(\S+))*$`.
Caveats: truncated on every run (so a `.control` `run` followed by the batch re-run leaves only the
last); the `meas` command does **not** write to it; the `at=`/`from=`/`to=`/`with=`/`targ=`/`trig=`
tail is function-dependent (see §1.4.4) and the AVG `to=` is unreliable.

## Route B — `meas … > file` / `>> file` (command only) — **recommended**

`get_measure2` writes to `FILE *mout = cp_out` (`com_measure2.c:1647`), so shell redirection in the
control language captures it. Verified (`readback2.sp`), `out2.txt` verbatim:
```
cmdrms              =  7.07119e-01 from=  1.00000e-03 to=  3.00000e-03
cmdavg              =  6.94259e-05 from=  1.00000e-03 to=  3.00280e-03
```

## Route C — the result vector + `print` (command only)

`com_meas` at `measure.c:130-141` runs `get_measure2` and then `com_let("<name> = %e", result)`.
Verified with `display` before and after:
```
--- display after .meas ---            (dot cards had already run)
    V(1)                : voltage, real, 508 long
    time                : time, real, 508 long [default scale]
    vac1#branch         : current, real, 508 long
--- meas command creates a vector ---
cmdmax              =  9.998452485945e-01 at=  1.252800000000e-03
cmdpp               =  1.999690497189e+00 from=  1.000000000000e-03 to=  3.000000000000e-03
    V(1)                : voltage, real, 508 long
    cmdmax              : notype, real, 1 long
    cmdpp               : notype, real, 1 long
    time                : time, real, 508 long [default scale]
    vac1#branch         : current, real, 508 long
```
**Proof that `.meas` cards create no vector**: `dotmax`/`dotpp` are absent from `display`.
The vector is `notype, real, 1 long` and is created in the **current plot**.

`print cmdmax cmdpp >> file` gives:
```
cmdmax = 9.998452e-01
cmdpp = 1.999690e+00
```
(precision from `numdgt`; see §1.8 for the 7-digit ceiling.)

## Route D — `echo "$&vecname"`

```
cmdmax = 0.999845
cmdpp  = 1.99969
z = 1.99969
```
Six significant digits — convenient for a status line, not for data.

## Route E — a scalar-only plot + `write` — **the machine-readable one**

```
setplot new
let m_mx = tran1.mx
let m_mn = tran1.mn
write scal.raw m_mx m_mn
```
Produces a 1-point rawfile. With `set filetype=ascii`, verbatim:
```
Title: Anonymous
Date: Wed Sep  9 19:02:28  2026
Command: ngspice-46+, Build Thu Sep  3 06:46:24 UTC 2026
Plotname: unknown
Flags: real
No. Variables: 2
No. Points: 1
Variables:
	0	m_mx	notype
	1	m_mn	notype
Values:
 0	9.999613000000001e-01
	-9.999613000000001e-01
```

### Anti-route — do NOT `write` or `wrdata` a scalar into the simulation plot

The plot's default scale is imposed, so a length-1 vector is **expanded to the full record**.
`write meas_vectors.raw cmdmax cmdpp` in the tran plot gave a header claiming
```
No. Variables: 3
No. Points: 508
Variables:
	0	time	time
	1	cmdmax	notype dims=1
	2	cmdpp	notype dims=1
```
and `wrdata meas_vectors.data cmdmax cmdpp` produced 508 identical rows:
```
 0.00000000e+00  9.99845200e-01  0.00000000e+00  1.99969000e+00 
 1.00000000e-07  9.99845200e-01  1.00000000e-07  1.99969000e+00 
 2.00000000e-07  9.99845200e-01  2.00000000e-07  1.99969000e+00 
```
12 471 bytes of raw file for two numbers.

## Recommended GUI recipe (all pieces verified)

```
* deck.sp emitted by the GUI - no .meas dot cards at all
...device lines...
.control
  set measureprec = 12
  set numdgt = 12
  set units = degrees            $ if ADE-style degrees are wanted
  tran 10u 5m
  * one 'let' per user expression, then one 'meas' per user measurement
  let vdiff = v(outp) - v(outn)
  meas tran tr_delay TRIG v(in) VAL=0.9 RISE=1 TARG v(out) VAL=0.9 RISE=1 > $inputdir/meas.txt
  meas tran ov       MAX v(out) FROM=1m TO=5m                            >> $inputdir/meas.txt
  * and/or the machine-readable route
  setplot new
  let m_tr_delay = tran1.tr_delay
  let m_ov       = tran1.ov
  set filetype = ascii
  write $inputdir/meas.raw m_tr_delay m_ov
  setplot tran1
  write $inputdir/waves.raw all
.endc
.end
```
Run it as `ngspice -b deck.sp` (**no `-r`**) or interactively. `$inputdir` is the directory of the
last input file (manual 13.7), which keeps the GUI's temp dir self-contained.

## Shared-library route

`src/include/ngspice/sharedspice.h` exposes no measurement API. The only handles are
`ngSpice_Command()` (`:456`), `ngGet_Vec_Info()` (`:460`), `ngSpice_CurPlot()` (`:523`),
`ngSpice_AllPlots()` (`:529`), `ngSpice_AllVecs()` (`:535`). So a `libngspice` GUI must issue
`meas` via `ngSpice_Command` and then read the length-1 vector via `ngGet_Vec_Info` — i.e.
Route C, with its 7-digit ceiling. Note `sharedspice.h:68-124` documents the casemode interaction:
under `casemode=distinguish`, `ngGet_Vec_Info` stops matching names case-insensitively.

---

# 3. `.four` / `fourier`

## 3.1 Where and how

`src/frontend/fourier.c`. Two entry points:
* `.four` card → `src/frontend/dotcards.c:407-421`, which does `plot_cur = setcplot("tran")` then
  `fourier(command->wl_next, plot_cur)`. Suppressed with `-r`:
  `".fourier line ignored since rawfile was produced."`
* `fourier` command → `com_fourier()` `fourier.c:263-267`, registered
  `src/frontend/commands.c:387`: `"fund_freq vector ... : Do a fourier analysis of some data."`
  (min 1 argument, no maximum).

`.four` output vectors are saved via `dotcards.c:140-148` with `com_save2(w, "TRAN")  /* A hack */`.

## 3.2 Syntax

```
.four <fundamental_freq> <expr> [<expr> ...]
fourier <fundamental_freq> <expr> [<expr> ...]
```
`<expr>` goes through `ft_getpnames_quotes(wl, TRUE)` (`fourier.c:98`), so it is the **full control-
language expression language** (§5), not just node names. In a dot card an expression must be
written `par('…')` (verified: `.four 1k par('v(1)+v(2)')` created node `pa_01`).

## 3.3 Control variables and their defaults

`fourier.c:69-78`:
```c
    if (!cp_getvar("nfreqs", CP_NUM, &nfreqs, 0) || nfreqs < 1)
        nfreqs = 10;
    if (!cp_getvar("nperiods", CP_NUM, &nperiods, 0) || nperiods < 1)
        nperiods = 1;
    if (!cp_getvar("polydegree", CP_NUM, &polydegree, 0) || polydegree < 0)
        polydegree = 1;
    if (!cp_getvar("fourgridsize", CP_NUM, &fourgridsize, 0) || fourgridsize < 1)
        fourgridsize = DEF_FOURGRIDSIZE;
    if (cp_getvar("fournosave", CP_BOOL, NULL, 0))
        foursave = FALSE;
```
with `#define DEF_FOURGRIDSIZE 200` (`fourier.c:32`).

| Variable | Default | Meaning |
|---|---|---|
| `nfreqs` | **10** | number of harmonics (index 0 = DC) |
| `nperiods` | **1** | how many fundamental periods to take, counted back from the END of the record (`fourier.c:124-130`) |
| `polydegree` | **1** | interpolation degree onto the uniform grid; **0 = no interpolation** |
| `fourgridsize` | **200** | grid points *per period*; the effective grid is `fourgridsize * nperiods` (`fourier.c:118`) |
| `fournosave` | unset | suppress the `fourierMN`/`thdMN` vectors |
| `cp_numdgt` (`numdgt`) | 6 | field width / digits in the printed table (`fourier.c:167`, `pnum()` `:270-282`) |

## 3.4 Output format (literal)

`four.sp`: 1 kHz sine + 10 % 3rd-harmonic summed in a B source, `.tran 5u 10m`, `.four 1k v(3) v(1)`:
```
Fourier analysis for v(3):
  No. Harmonics: 10, THD: 9.99204 %, Gridsize: 200, Interpolation Degree: 1, No. Periods: 1

Harmonic Frequency   Magnitude   Phase       Norm. Mag   Norm. Phase
-------- ---------   ---------   -----       ---------   -----------
 0       0           -3.1753e-08 0           0           0          
 1       1000        0.999901    2.26289e-05 1           0          
 2       2000        6.35052e-08 -86.4       6.35115e-08 -86.4      
 3       3000        0.0999105   0.000673324 0.0999204   0.000650695
 4       4000        6.35052e-08 -82.8       6.35115e-08 -82.8      
 5       5000        6.35052e-08 -81         6.35115e-08 -81        
 6       6000        6.35052e-08 -79.2       6.35115e-08 -79.2      
 7       7000        6.35052e-08 -77.4       6.35115e-08 -77.4      
 8       8000        6.35052e-08 -75.6       6.35115e-08 -75.6      
 9       9000        6.35052e-08 -73.8       6.35115e-08 -73.8      
```
Format strings: header `fourier.c:159-175`, rows `fourier.c:183-190`. Field width
`fw = ((cp_numdgt > 0) ? cp_numdgt : 6) + 5 + shift`.

Definitions (`CKTfour()` `fourier.c:292-361`):
* `Mag[0]` = DC (mean), `Phase[0]=nMag[0]=nPhase[0]=Freq[0]=0`.
* `Mag[i] = hypot(2*Re/n, 2*Im/n)`, `Phase[i] = atan2(...)*180/M_PI` — **always degrees**, not
  affected by `units` (contrast §1.4.6).
* `nMag[i] = Mag[i]/Mag[1]`, `nPhase[i] = Phase[i]-Phase[1]`.
* `THD = 100*sqrt(sum_{i>=2} nMag[i]^2)` — **percent**.

## 3.5 The vectors it creates

`fourier.c:199-240`. For the *m*-th `fourier`/`.four` call and the *n*-th expression in that call:
* `thd<m><n>` — length 1, the THD in percent;
* `fourier<m><n>` — length `3*nfreqs`, `v_numdims = 2`, `v_dims = {3, nfreqs}`;
  row 0 = frequency, row 1 = magnitude, row 2 = phase.

Note the name is a **plain concatenation of two decimal numbers** (`tprintf("fourier%d%d", …)`), so
the 10th call's 1st expression and the 1st call's 10th expression both produce `fourier110`. A GUI
that issues many `fourier` calls must not rely on the name; it should read the vector immediately
after each call, or `let` it into a name of its own.

Verified `display` after four `fourier` calls (the 4th with `fournosave` set):
```
    fourier11           : notype, real, 30 long, dims = [3,10]
    fourier21           : notype, real, 15 long, dims = [3,5]
    fourier31           : notype, real, 15 long, dims = [3,5]
    thd11               : notype, real, 1 long
    thd21               : notype, real, 1 long
    thd31               : notype, real, 1 long
```
i.e. `fournosave` correctly suppressed the 4th pair.

Scalar readback verified:
```
f3 = 1.718601e-08          <- let f3 = fourier11[1][3]   (magnitude of harmonic 3)
THD = 4.86143E-06          <- echo "THD = $&thd11"
```
⚠ `print fourier11` is useless: the vector lives in the tran plot and is printed against the 2008-
point `time` scale, so 30 values are followed by ~2000 blank rows. Always index it
(`fourierMN[row][harmonic]`) or `plot fourierMN[1] vs fourierMN[0]` (the manual's own example).

## 3.6 The tstep accuracy caveat — quantified

`fourier()` resamples onto a uniform grid using `ft_interpolate(..., polydegree)` (`fourier.c:137`).
With `polydegree = 0` there is no interpolation and the raw, **non-uniformly spaced** transient
samples are fed straight into a DFT that assumes uniform spacing:
```c
    } else {
        fourgridsize = vec->v_length;
        data = vec->v_realdata;
        timescale = time->v_realdata;
    }
```
(`fourier.c:144-148`), and `CKTfour()` ignores `Time` entirely (`fourier.c:331 NG_IGNORE(Time);`)
— it assumes sample *i* is at `numPeriod*i/ndata` of the record.

Measured cost on the same signal (true THD 10 %):
```
=== default fourier ===                Gridsize: 200, Interpolation Degree: 1, No. Periods: 1
  THD: 9.99204 %
=== nfreqs=5 fourgridsize=512 nperiods=2 polydegree=2 ===
  No. Harmonics: 5, THD: 9.99999 %, Gridsize: 1024, Interpolation Degree: 2, No. Periods: 2
=== polydegree=0 (no interpolation) ===
  No. Harmonics: 5, THD: 1144.66 %, Gridsize: 2008, Interpolation Degree: 0, No. Periods: 0…2
```
**`polydegree=0` gave THD = 1144 % instead of 10 %.** The manual says the same in words
(13.5.35): *"If polydegree is 0, then no interpolation is done. This is likely to give erroneous
results if the time scale is not monotonic."* — the real risk is not non-monotonicity but
non-uniformity, which every adaptive transient has.

The other half of the caveat: even with interpolation on, the *transient* `tstep` bounds the true
resolution. Interpolating a coarsely sampled waveform onto a 200-point grid manufactures points but
not information. **GUI rule: when the user asks for `.four`, require `tstep <= 1/(2*nfreqs*fund)`
and warn otherwise; keep `polydegree >= 1`; raise `fourgridsize` for high `nfreqs`.**
`nperiods > 1` also fails hard if the record is too short:
`"Error: (%d * wavelength) longer than time span"` (`fourier.c:126`).

---

# 4. `fft`, `psd`, `spec`, and `linearize`

## 4.1 Commands

`src/frontend/commands.c:379-394`:
```c
    { "fft", com_fft, ...  1, LOTS, NULL, "vector ... : Create a frequency domain plot with FFT." },
    { "psd", com_psd, ...  2, LOTS, NULL, "vector ... : Create a power spetral density plot with FFT." },
    { "fourier", com_fourier, ... 1, LOTS, NULL, "fund_freq vector ... : Do a fourier analysis of some data." },
    { "spec", com_spec, ... 4, LOTS, NULL, "start_freq stop_freq step_freq vector ... : Create a frequency domain plot." },
```
```
fft   <expr> [<expr> ...]
psd   <averaging_points> <expr> [<expr> ...]
spec  <start_freq> <stop_freq> <step_freq> <expr> [<expr> ...]
```
`psd`'s first argument is the width of a rectangular smoothing window; `< 1` or unparseable →
`1` with the message `"Number of averaged data points:  1"` (`com_fft.c:303-313`).

All three require the current plot's scale to be a **real `SV_TIME`** vector
(`com_fft.c:54-58`, `:292-296`; `spec.c:40-44`):
`"Error: fft needs real time scale"` / `"Error: spec needs real time scale"`.
`fft` also refuses a record shorter than 2 points:
`"Error: fft needs more than one time point, check the tran simulation!"` (`com_fft.c:63-66`).

## 4.2 Build gate: FFTW3

`src/frontend/com_fft.c:21-23`, `:71-91`, `:178-251` — `#ifdef HAVE_LIBFFTW3`.
`configure.ac:190-192, 929-933`: `--with-fftw3[=yes/no]`, **default yes**; probes `fftw3.h` and
`fftw_plan_dft_1d`. **In this tree it is ON**: `build-ver_50/src/include/ngspice/config.h:535`…
actually `:168` — `#define HAVE_LIBFFTW3 /**/`.

Consequences of the two paths (a GUI reporting resolution must know which it has):

| | FFTW3 (this build) | Green's radix-2 fallback |
|---|---|---|
| Input length | exact `length` | zero-padded to next `2^M = N` |
| `fpts` | `length/2 + 1` | `N/2 + 1` |
| freq axis | `i/span` | `i/span*length/N` |
| amplitude scale | `length/2` | `length/2` (fixed by E-241, `com_fft.c:83-91`) |
| console note | `"FFT: Time span: … input length: …"` | adds `", zero padding: %d"` |

Live (FFTW path):
```
FFT: Time span: 0.010005 s, input length: 2001
FFT: Frequency resolution: 99.95 Hz, output length: 1001
```
```
PSD: Time span: 0.01 s, input length: 2001
PSD: Frequency resolution: 100 Hz, output length: 1001
Total noise power up to Nyquist frequency 1.000e+05 Hz: 7.494760e-01 V^2 (or A^2), 
Noise voltage or current: 8.657228e-01 V (or A)
```
Note the span definitions differ: `fft` uses
`span = time[length-1] - time[0] + time[length-1] - time[length-2]` (`com_fft.c:69` — one extra
sample interval), `psd` uses `span = time[length-1] - time[0]` (`com_fft.c:300`). Hence
`99.95 Hz` vs `100 Hz` on the same data. Do not present them as identical.

## 4.3 Windowing

`fft` and `psd` share `fft_windows()` in `src/maths/fft/fftext.c:96-184`.
`spec` has its **own, older** copy inline in `src/frontend/spec.c:87-158`.

`com_fft.c:95-103` (identical block at `:332-340` for `psd`):
```c
    if (!cp_getvar("specwindow", CP_STRING, window, sizeof(window)))
        strcpy(window, "hanning");
    if (!cp_getvar("specwindoworder", CP_NUM, &order, 0))
        order = 2;
    if (order < 2)
        order = 2;
```

| Name | `fft`/`psd` (`fftext.c`) | `spec` (`spec.c`) | line |
|---|---|---|---|
| `none` | ✔ | ✔ | `:103` / `:93` |
| `rectangular` | ✔ | ✔ | `:106` / `:96` |
| `triangle` | ✔ | ✔ | `:113` / `:120` |
| `bartlet` | ✔ | ✔ | `:113` / `:120` |
| `bartlett` | ✔ | ✘ | `:113` |
| `hanning` (default) | ✔ | ✔ | `:122` / `:104` |
| `hann` | ✔ | ✘ | `:122` |
| `cosine` | ✔ | ✔ | `:122` / `:104` |
| `hamming` | ✔ | ✔ | `:129` / `:112` |
| `blackman` | ✔ | ✔ | `:136` / `:128` |
| `blackmanharris` | ✔ | **✘** | `:146` |
| `flattop` | ✔ | **✘** | `:157` |
| `gaussian` (uses `specwindoworder`) | ✔ | ✔ | `:169` / `:138` |

Verified: running `spec` with `blackmanharris` / `flattop` gives
```
Warning: unknown window type blackmanharris
Warning: unknown window type flattop
```
and `spec.c:154-157` then **aborts the whole `spec`** (`goto done`).

**Two real defects a GUI must work around:**

1. **`fft`/`psd` window names are compared byte-exactly.** `fftext.c` uses `eq()`, i.e.
   `#define eq(a,b) (!strcmp((a),(b)))` (`src/include/ngspice/macros.h:25`). `spec.c` uses
   `eqc()` = `cieq()` (`macros.h:26`), so `spec` *is* case-insensitive. A deck hides the
   difference because the reader lowercases `.control` lines under the default
   `casemode=fold`, but a piped or `libngspice` command does not. Verified in `-p` mode:
   ```
   ngspice 145 -> set specwindow = Hanning
   ngspice 146 -> echo "specwindow = $specwindow"
   specwindow = Hanning
   Warning: unknown window type Hanning
   Warning: unknown window type Hanning for fft, set to "none" 
   ```
   vs. in a deck's `.control`: `echo "specwindow is now: $specwindow"` prints `hanning`.

2. **"set to none" is false — the window array is left uninitialised.** `com_fft.c:102-103`:
   ```c
       if (fft_windows(window, win, time, length, maxt, span, order) == 0)
           fprintf(cp_err, "Warning: unknown window type %s for fft, set to \"none\" \n", window);
   ```
   `win = TMALLOC(double, length)` is `calloc`-zeroed, and `fft_windows` returns 0 **without
   writing `win`**, so every sample is multiplied by 0. `com_psd` does the right thing
   (`com_fft.c:339-340`: `goto done;`). Measured:
   ```
   ngspice 166 -> meas sp pk MAX m          (specwindow = none)
   pk                  =  9.99609e-01 at=  9.99500e+02
   Warning: unknown window type Hanning
   Warning: unknown window type Hanning for fft, set to "none" 
   ngspice 171 -> meas sp pkbad MAX m2
   pkbad               =  0.00000e+00 at=  9.99500e+04
   ```
   **A GUI must validate the window name itself and always emit lowercase.**

`specwindoworder` (gaussian only): source clamps `order < 2 → 2` and imposes **no upper bound**
(`com_fft.c:97-100`, `spec.c:141-144`). The manual (13.5.33) says *"an integer in the range 2-8"*
— **doc-vs-source conflict #2**, minor; trust the source but have the GUI offer 2-8.
The manual also asserts *"All window functions have a rms value of 1"*; the source comment at
`fftext.c:102` says *"window functions - should have an average of one"*. Different claims; neither
verified here.

## 4.4 What the transforms create

**`fft`** (`com_fft.c:140-176`):
```c
    plot_cur = plot_alloc("spectrum");
    plot_cur->pl_name = copy("Spectrum");
    ...
    f = dvec_alloc(copy("frequency"), SV_FREQUENCY, VF_REAL | VF_PERMANENT | VF_PRINT, fpts, NULL);
    ...
        f = dvec_alloc(vec_basename(vec), SV_NOTYPE, VF_COMPLEX | VF_PERMANENT, fpts, NULL);
```
→ a new plot containing `frequency` (real, `fpts` long, the default scale) plus **one complex
vector per input, named after the input's base name**, with type `SV_NOTYPE`.

**`psd`** (`com_fft.c:377-411`): identical, `pl_name = "PSD"`, vectors also `SV_NOTYPE`, complex
but with `cx_imag = 0` — the real part is `V^2/Hz` after smoothing (`com_fft.c:524-525`).

**`spec`** (`spec.c:195-224`): `pl_name = "Spectrum"`, and it **preserves the input's `v_type`**
(`spec.c:218 vec->v_type`), so `v(1)` comes out as `voltage, complex`. Verified `display`:
```
Name: sp2 (Spectrum)
    frequency           : frequency, real, 51 long [default scale]
    v(1)                : voltage, complex, 51 long
```
against `fft`'s
```
Name: sp2 (Spectrum)
    frequency           : frequency, real, 1001 long [default scale]
    v(3)                : notype, complex, 1001 long
```
That `SV_NOTYPE` on `fft`/`psd` output matters for a GUI: axis labelling and unit inference are
lost. Use `settype voltage v(3)` after `fft` if the GUI labels axes from vector type.

All three set `plot_cur->pl_fromfile = vec_fromfile(vlist, ngood)` (`com_fft.c:149`, `:384`;
`spec.c:204`) — a fork-local change documented in `doc/codex/issues/0070`, meaning a spectrum
derived from loaded data is still marked as "came from a file".

## 4.5 `spec` argument validation

`spec.c:46-86`. Verified error messages:
```
=== spec nyquist violation ===
Error: nyquist limit exceeded, try stop freq less than 1.000000e+05 Hz
=== spec step too coarse ===
Error: bad step freq 1e6
=== spec step too fine (< 1/timespan) ===
Error: time span limits step freq to 1.0e+02 Hz
=== spec start > stop ===
Error: bad stop freq 1k
```
Rules: `start >= 0`; `stop > start`; `step <= stop-start`; `stop <= 0.5*tlen/span`
(`spec.c:70`); and `floor(span*step)/step > 0` i.e. `step >= 1/(t[n-1]-t[0])` (`spec.c:76-86`).
`start` is snapped down to a multiple of `step` (`spec.c:78`). `set spectrace` prints a running
`spec: %e Hz: \r` progress line (`spec.c:236-241`).

## 4.6 Plot naming — why `meas sp` is the right verb on a spectrum

`plot_alloc("spectrum")` → `ft_plotabbrev("spectrum")` (`src/frontend/typesdef.c:331-348`) scans
`plotabs[]` (`typesdef.c:67-90`) for the first pattern that is a substring of the name. Entry 18 is
`{ "sp", "sp" }` and `"sp"` is a substring of `"spectrum"`, so the plot's `pl_typename` becomes
`sp<N>`. Verified for both:
```
Name: sp2 (Spectrum)      <- fft
Name: sp3 (PSD)           <- psd
Name: sp4 (Spectrum)      <- spec
```
And `get_measure2` accepts a plot whose typename has the `sp` prefix, while
`com_measure_when`/`measure_at`/`measure_minMaxAvg` all handle a **real** `frequency` scale on the
sp branch (`com_measure2.c:470-474`, `:736-739`, `:870-874` — the `// fft` comment at `:738` is
explicit about it). So **`meas sp …` on an fft/spec/psd plot is fully supported and safe**, unlike
`meas sp` on a real `.sp` run (§1.5). Verified:
```
pk                  =  9.99609e-01 at=  9.99500e+02
```

---

# 5. `linearize` — what it is, when it is mandatory, what it costs

`src/frontend/linear.c:23-173`. Registered `src/frontend/commands.c:656`:
```c
    { "linearize", com_linearize, FALSE, FALSE,
      { 040000, 040000, 040000, 040000 }, E_DEFHMASK, 0, LOTS,
      NULL,
      " [ vec ... ] : Convert plot into one with linear scale." } ,
```
```
linearize [np=<N>|np=auto2n] [vec ...]
```

## 5.1 What it does

Creates a **new plot** `tran<N+1>` named `"<old> (linearized)"` (`linear.c:95-109`) whose `time`
vector is `tstart, tstart+tstep, …` for `len` points, and interpolates every requested vector (or
all of them) onto it with `lincopy()`.

`tstart/tstop/tstep` come from the circuit's transient parameters (`if_tranparams`, `linear.c:52`).
If no circuit is loaded (data came from `load`), they are derived from the scale vector
(`linear.c:56-65`) with the warning
`"Warning: Can't get transient parameters from circuit. / Use transient analysis scale vector data instead."`.

They can be overridden by putting length-1 vectors named `lin-tstart`, `lin-tstop`, `lin-tstep`
in the current plot (`linear.c:67-84`), which echo:
```
linearize tstart is set to: 2.000000e-03
linearize tstop is set to: 4.000000e-03
linearize tstep is set to: 1.000000e-06
```
(Expect cosmetic noise afterwards: those control vectors are themselves candidates for
interpolation, producing
`Warning: lin-tstep is a scalar - interpolation is not possible` × 3.)

Length: `len = (int)((tstop - tstart) / tstep + 1.5)` (`linear.c:136`).

Guards: `"Error: plot must be a transient analysis"` (typename must have prefix `tran`,
`linear.c:35`), `"Error: no vectors available"`, `"Error: non-real time scale for %s"`,
`"Error: bad parameters -- start = %G, stop = %G, step = %G"`.

## 5.2 `np=` — a subtle trap

`linear.c:119-136`:
```c
        if (ciprefix("np=", para)) {
            np = TRUE;
            para += 3;
            len = atoi(para);
            if (len == 0 && ciprefix("auto2n", para)) {
                /* number of points as 2^n */
                expo = (int)round(log2((tstop - tstart) / tstep));
                len = 1 << expo;
            }
```
`np=` changes **only the count**; `tstep` is still the circuit's `tstep` (`linear.c:144`). So the
time span is silently re-cut. Verified on `.tran 5u 10m` (2008 raw points):
```
orig tstart/tstop
time[0] = 0.000000e+00
time[2007] = 1.000000e-02
linearize np=1024
length(time) = 1.024000e+03
time[0] = 0.000000e+00
time[1023] = 5.115000e-03       <- span TRUNCATED to 5.115 ms
linearize np=auto2n
length(time) = 2.048000e+03
time[2047] = 1.023500e-02       <- span EXTENDED past tstop
```
and the extension is **zero-filled**, not extrapolated:
```
time[1999] = 9.995000e-03   v(1)[1999] = -3.14089e-02
time[2000] = 1.000000e-02   v(1)[2000] = -2.01794e-12
time[2040] = 1.020000e-02   v(1)[2040] = 0.000000e+00
time[2047] = 1.023500e-02   v(1)[2047] = -2.44929e-15
```
`np=auto2n` is therefore *zero-padding to a power of two*, which is exactly what you want for the
Green's-FFT path but changes the effective `span` (and hence the reported frequency resolution) on
the FFTW path. The manual's phrasing (13.5.45, *"spans from point 0 to point xx, covering xx-1
periods"*) is opaque; the empirical rule above is what to build against.

`linearize <vec>` restricts the copy to the named vectors (`linear.c:148-164`); the new plot then
holds only `time` plus those:
```
Name: tran5 (Transient Analysis (linearized))
    V(1)                : voltage, real, 2001 long
    time                : time, real, 2001 long [default scale]
```
An unknown name gives
`Error: command 'linearize': no such vector %s` and is skipped.

## 5.3 When it is mandatory

**Before `fft` and `psd`: always.** Those routines never look at the time values — they multiply by
`win[j]` and hand the array to the FFT, which assumes uniform sampling. Measured error on a pure
1 V 1 kHz sine (`fft2.sp`):
```
=== FFT on raw variable-step data ===
FFT: Time span: 0.0100043 s, input length: 2008
pk                  =  9.95420e-01 at=  9.99570e+02
=== FFT on linearized data ===
FFT: Time span: 0.010005 s, input length: 2001
pk2                 =  9.99885e-01 at=  9.99500e+02
```
0.46 % amplitude error and a shifted bin from skipping `linearize` on an *easy* waveform; on a
sharp-edged digital signal, where the adaptive stepper clusters points at edges, the error is far
larger and shows up as a spurious noise floor.

**Before `spec`: strongly recommended, not strictly required.** `spec` computes a direct DFT using
the *actual* timestamps — `rad = 2*M_PI*time[k]*freq[j]` (`spec.c:250`) — so it is far more
tolerant, but it still weights every sample equally (`amp = 2*win[k]/(tlen-1)`, `spec.c:249`),
which is a rectangle rule in *index* space. Measured:
```
== spec on RAW variable-step data ==      specraw  =  9.96512e-01 at=  1.00000e+03
== spec on LINEARIZED data ==             speclin  =  9.99901e-01 at=  1.00000e+03
== fft on RAW ==                          fftraw   =  9.95420e-01 at=  9.99570e+02
```

**Before `.four`/`fourier`: not needed** — `fourier()` does its own interpolation onto a uniform
grid (unless `polydegree=0`, §3.6).

## 5.4 What it costs

* **Memory**: a whole second plot with `len` points per vector. With `.tran 5u 10m` the raw plot is
  2008 points × 7 vectors; the linearized plot adds 2001 × 7. For a long transient with hundreds of
  saved nodes this can double peak RSS. Mitigation: `linearize <only the vectors you will transform>`.
* **Fidelity**: `lincopy()` is linear interpolation, so any feature narrower than `tstep` is lost.
  The manual (13.5.45) is blunt: *"the parameter tstep of your transient analysis has to be small
  enough to get adequate resolution, otherwise the command linearize will do sub-sampling of your
  signal."* A GUI offering an FFT button must therefore either force a small `tstep` on the
  transient, or use `.option INTERP` (which does the same resampling during the run and saves the
  memory), or refuse and explain.
* **Plot churn**: `plot_setcur(new->pl_typename)` (`linear.c:108`) makes the new plot current. A
  GUI that tracks "the current plot" must re-read `$curplot` after every `linearize`, `fft`, `spec`
  and `psd`.

## 5.5 `cutout` — the companion

`com_cutout()` `src/frontend/linear.c:179-301`, registered `commands.c:660`:
```
cutout [vec ...]
```
Copies a *slice* of the current tran plot into a new plot `"<old> (cut out)"` (or `"(copy)"` if no
limits) using length-1 vectors `cut-tstart` / `cut-tstop` placed in the plot beforehand. No
resampling — it copies the original samples. Verified:
```
=== cutout ===
length(time) = 4.000000e+02
time[0] = 3.001400e-03
```
Vectors shorter than the slice are silently skipped (`linear.c:294-295`). Requires a `tran` plot.

---

# 6. The expression language available for outputs

This is the same language for `let`, `print`, `plot`, `write`, `fft`, `spec`, `psd`, `fourier`,
`wrdata` and (via `let`) for measurements. Parser: `src/frontend/parse-bison.y`,
lexer + node builders `src/frontend/parse.c`, evaluation `src/frontend/evaluate.c`,
maths `src/maths/cmaths/cmath{1,2,3,4}.c`.

## 6.1 Operators and precedence

`src/frontend/parse-bison.y:94-104`, lowest precedence first:
```
%right  '?' ':'
%left   '|'
%left   '&'
%left   '=' TOK_NE TOK_LE '<' TOK_GE '>'
%left   '~'
%right  ','
%left   '-' '+'
%left   '*' '/' '%'
%left   NEG      /* negation--unary minus */
%right  '^'      /* exponentiation */
%left   '[' ']'
```
Operator table `src/frontend/parse.c:314-341`:

| Token | Arity | Meaning |
|---|---|---|
| `+ - * / %` | 2 | arithmetic; `%` is `op_mod` |
| `^` | 2 | power (right-assoc) |
| `,` | 2 | list/pair — also what makes `v(a,b)` work |
| `= <> > < >= <=` | 2 | comparisons → 1.0/0.0 (`<>` is the not-equal spelling; `!=` is **not** a token) |
| `& \|` | 2 | logical and/or |
| `~` | 1 | logical not |
| `-` | 1 | unary minus |
| `[ ]` | 2 | index — `v[i]`, `v[i][j]` for multi-dim |
| `[[ ]]` | 2 | range — `v[[lo,hi]]` |
| `? :` | ternary | `cond ? a : b` |

⚠ **The ternary requires a SCALAR condition.** Verified:
```
Error: ft_ternary(), condition must be scalar, but length=2008
  in term: v(1) > 0 ? 1 : 0
```
So `v(1) > 0 ? 1 : 0` is illegal in the control language (write `(v(1) > 0)` instead, which already
yields 1/0 per point). The `? :` in a `.meas … param='…'` is a **different** evaluator (numparam's,
`src/frontend/numparam/`) and works on scalars — which is exactly what `.meas param='(a<b)?1:0'`
does.

Grammar productions: `parse-bison.y:136-173`. Note `TOK_STR '(' exp ')'` is a function call
(`:153`), and juxtaposition builds a list (`exp_list: one_exp exp_list`, `:124-127`) — which is why
`plot v(1) v(2)` plots two curves rather than erroring.

## 6.2 Function table

`src/frontend/parse.c:355-417` — complete, in table order:

| Name(s) | Notes |
|---|---|
| `mag`, `magnitude`, `abs` | `hypot` for complex, `fabs` for real |
| `ph`, `phase` | phase; **radians unless `set units=degrees`** (§1.4.6) |
| `cph`, `cphase` | continuous (unwrapped) phase |
| `unwrap` | |
| `j` | multiply by i |
| `real`, `re` / `imag`, `im` | |
| `conj` | |
| `db` | `20*log10(mag)` |
| `log`, `ln` | natural log (**`log` is `cx_log`, i.e. ln** — not base 10) |
| `log10` | base-10 |
| `exp`, `sqrt` | |
| `sin cos tan sinh cosh tanh atan atanh` | (no `asin`/`acos`/`asinh`/`acosh`) |
| `sortorder` | permutation indices |
| `norm` | normalise to max magnitude 1 |
| `rnd`, `sunif`, `sgauss`, `poisson`, `exponential` | random generators |
| `pos` | 1 where >0 |
| `nint`, `floor`, `ceil` | |
| `mean`, `stddev` | scalars |
| `avg` | running average (vector) |
| `m3avg` | |
| `group_delay` | AC group delay |
| `vector(n)`, `cvector(n)`, `unitvec(n)` | constructors |
| `length` | scalar |
| `vecmin`, `minimum` / `vecmax`, `maximum` | scalars |
| `vecd` | |
| `interpolate` | onto the current plot's scale |
| `deriv` | polynomial-fit derivative; degree from `dpolydegree`, **default 2** (`src/maths/cmaths/cmath4.c:263-264`) |
| `integ` | running integral |
| `fft`, `ifft` | as *expression* functions (distinct from the `fft` command) |
| `mtimeavg` | moving time average over `mtimeavgwindow`, **default `10*CKTstep`** (or 1e-6 with no circuit) (`cmath4.c:1055-1063`) |
| `v` | **not a real function** — the differential-pair kludge, see §6.4 |

Verified behaviours:
```
d[10] = 6.248829e+03            let d = deriv(v(1))
ii[100] = 3.147504e-04          let ii = integ(v(1))
mean(v(1)) = 1.329854e-05
stddev(v(1)) = 7.058728e-01
vecmin(v(1)) = -9.99961e-01
vecmax(v(1)) = 9.999613e-01
length(v(1)) = 2.008000e+03
length(fft(v(1))) = 1.005000e+03      (and it prints the same FFT: banner)
length(unitvec(5)) = 5.000000e+00
Note: mtimeavgwindow not given, window set to 5e-05 s
```

`PP_mkfnode` lowercases the function name before lookup (`parse.c:506-513`), so function names are
**always case-insensitive**, in every casemode.

User-defined functions come from `define` (`ft_substdef`, `parse.c:517`), so a GUI can offer a
macro facility: `define pwr(a,b) a*b` then `plot pwr(v(out),i(vout))`.

## 6.3 How to reference things

| Thing | Spelling | Mechanism |
|---|---|---|
| node voltage | `v(out)` or bare `out` | `vec_fromplot_maybe_report` `src/frontend/vectors.c:701-739` strips `x(` … `)` for any leading letter |
| differential | `v(a,b)` | comma node → `v(a) - v(b)`, `parse.c:563-568` |
| branch current of a source/inductor | `i(vdd)` or `vdd#branch` | `vectors.c:722-726` appends `#branch` when the leading letter is `i`/`I` |
| device terminal current | `@vdd[i]` | `if_getparam`, `vectors.c:882` |
| device internal parameter | `@m1[gm]` | same |
| whole device dump | `@m1[all]` or `@m1` | returns a list of `@m1[<param>]` vectors, `vectors.c:889-907` |
| model parameter | `@nch[kp]` | same path, `do_model` resolution |
| vector in another plot | `tran1.v(out)`, `ac1.mag(v(out))` | `vec_get_maybe_report` `vectors.c:792-814` |
| every plot | `all.v(out)` | wildcard plot, `vectors.c:797-799` |
| all vectors | `all`, `allv`, `alli`, `ally`, `alle` | `vec_is_all_wildcard`, `fteext.h:387` |

Verified live on a level-1 NMOS:
```
=== device internal parameters via @ ===
@m1[gm] = 7.000000e-04
@m1[id] = 2.450000e-04
Error: no such parameter vth.
Warning from checkvalid: vector @m1[vth] is not available or has zero length.
=== model parameter ===
@nch[kp] = 1.000000e-04
=== branch current ===
@vd[i] = -2.45000e-04
vd#branch = -2.45000e-04
i(vd) = -2.45000e-04
=== differential ===
v(d,g) = 6.000000e-01
v(d)-v(g) = 6.000000e-01
=== case ===
v(D) = 1.800000e+00
@M1[GM] = 7.000000e-04
```
`@m1[all]` returned 55 parameters (`m l w ad as pd ps nrd nrs icvds icvgs icvbs temp dtemp id is ig
ib ibd ibs vgs vds vbs vbd dnode gnode snode bnode dnodeprime snodeprime von vdsat sourcevcrit
drainvcrit rs sourceconductance rd drainconductance gm gds gmb gbd gbs cbd cbs cgs cgd cgb cqgs cqgd
cqgb cqbd cqbs cbd0 cbdsw0 cbs0 cbssw0 qgs qgd qgb qbd qbs p sens_l_* sens_w_*`), which is exactly
the list a GUI's "device parameter browser" should show — enumerate with `@<inst>[all]` at the
operating point, or `devhelp <device>` / `show <inst>` for the human-readable form.

**Critical for measurements**: `@`-references are resolved through `if_getparam` and produce a
**length-1** vector at the *current* operating point, **not** a swept waveform — unless the name was
`.save`d, in which case `outitf.c`'s "special" machinery records it per timepoint. So
`.save @m1[gm]` (or `.probe`, which `inpcom.c:7667` rewrites to `.save`) is required before you can
`meas tran gm_max MAX @m1[gm]`.

`vec_get()` also has to be told which plot; `@`-vectors are created in the *current* plot at lookup
time (`vectors.c:994 vec_new(nd)`), so they accumulate. `remzerovec` and `unlet` clean up.

## 6.4 The `v(a,b)` mechanism

`parse.c:415` declares `{ "v", NULL }` — a function with a NULL implementation. `PP_mkfnode`
`parse.c:563-568`:
```c
    if (!f->fu_func && arg->pn_op && arg->pn_op->op_num == PT_OP_COMMA) {
        p = PP_mkbnode(PT_OP_MINUS, PP_mkfnode(func, arg->pn_left),
                    PP_mkfnode(func, arg->pn_right));
```
so `v(a,b)` literally becomes `v(a) - v(b)`. The comment at `parse.c:344-345` calls it out:
*"We have 'v' declared as a function, because if we don't then the defines we do for vm(), etc
won't work. This is caught in evaluate(). Bad kludge."*

For **dot cards** there is a separate, older translation, `fixem()` `src/frontend/dotcards.c:536-633`,
applied by `fixdotplot`/`fixdotprint`:
```
v(x,0)   -> v(x)
v(0,x)   -> -v(x)
v(a,b)   -> v(a)-v(b)
vm(a,b)  -> mag(v(a)-v(b))     vp(a,b) -> ph(...)   vi(a,b) -> imag(...)
vr(a,b)  -> real(...)          vdb(a,b) -> db(...)
i(x)     -> x#branch
```
So `.print`/`.plot` accept `vdb(out,ref)` but the control-language `plot` command does not (there
`vdb` is not a function — you write `db(v(out)-v(ref))`). Verified in `parprint.sp`:
`.print tran … v(1,2)` produced a column headed `v(1)-v(2)`.
`.plot` also accepts a trailing `(lo,hi)` which `fixdotplot` rewrites to `xlimit lo hi`
(`dotcards.c:484-515`), and the keywords `linear`, `xlog`, `ylog`, `loglog` are stripped before the
save pass (`plot_opts[]`, `dotcards.c:84-89`).

## 6.5 Case-sensitivity rules in THIS tree

This fork has a three-way case policy that upstream does not
(`src/include/ngspice/fteext.h:215-234`, `src/frontend/inpcom.c:1067-1143`,
`doc/claude/decisions/0001-distinguish.md`, `doc/codex/issues/0060`):

```c
enum {
    NG_CASE_FOLD = 0,     /* R1 == r1, spelling lowercased (default) */
    NG_CASE_PRESERVE,     /* R1 == r1, spelling as first typed */
    NG_CASE_DISTINGUISH   /* R1 != r1, spelling as typed; experimental */
};
```
Selected with `set casemode=fold|preserve|distinguish` **before** reading the deck; the mode in
force is readable as `$curcasemode` (read-only, `src/frontend/options.c:68`).

The one rule for vector names is `vec_name_eq()` `src/frontend/vectors.c:429-436`:
```c
bool vec_name_eq(const char *v_name, const char *typed)
{
    if (inp_case_mode() != NG_CASE_DISTINGUISH)
        return cieq(v_name, typed) != 0;
    return (strcmp(v_name, typed) == 0) || vec_wrapped_name_eq(v_name, typed);
}
```

Measured end-to-end (deck declares node `Out`, three `meas` spellings):
```
########## casemode=fold
out                                          0
    out                 : voltage, real, 208 long
a1 = 9.99845e-01   a2 = 9.99845e-01   a3 = 9.99845e-01
########## casemode=preserve
Out                                          0
    Out                 : voltage, real, 208 long
a1 = 9.99845e-01   a2 = 9.99845e-01   a3 = 9.99845e-01
########## casemode=distinguish
Warning: casemode 'distinguish' is experimental. Identifier identity is case sensitive. …
Out                                          0
    Out                 : voltage, real, 208 long
a1                  =  9.99845e-01 at=  2.52800e-04
Warning: no vector named 'out'; 'Out' differs only in case (casemode=distinguish)
Error: measure  a2  MAX(TRIG) : no such vector as 'v(out)'
 meas tran a2 MAX v(out) failed!
Warning: no vector named 'OUT'; 'Out' differs only in case (casemode=distinguish)
Error: measure  a3  MAX(TRIG) : no such vector as 'V(OUT)'
 meas tran a3 MAX V(OUT) failed!
```

**Rules a GUI must implement:**
1. **Function names** (`mag`, `db`, `deriv`, …) are always case-insensitive — lowercased in
   `PP_mkfnode` (`parse.c:507`).
2. **Measurement keywords** (`TRIG`, `VAL`, `RISE`, `tran`, …) are always case-insensitive —
   `strcasecmp`/`cieq` throughout `com_measure2.c`.
3. **Vector / node / instance names** follow `casemode`. Under `fold` (default) the reader also
   *rewrites* the deck to lowercase, so `display` shows lowercase names; under `preserve` and
   `distinguish` the deck's spelling survives.
4. Under `distinguish` the GUI must echo names **exactly as the schematic spells them**, and it
   gets a helpful near-miss warning when it does not.
5. **`specwindow` is the glaring exception** — it is a *keyword* but is compared with byte-exact
   `eq()` in `fft_windows()` (§4.3). Always emit lowercase.
6. `.model`/`.subckt`/`.global`/`.param` identity uses `ng_ideq()`
   (`inpcom.c:1141-1144`), which is exact under fold and distinguish, case-insensitive under
   preserve.

---

# 7. "Plot this expression" vs "Measure this scalar" — the GUI mapping

## 7.1 Plot an expression

**Interactive / control** — `com_plot`, `src/frontend/commands.c:178`:
```
plot <expr> [<expr> ...] [vs <expr>]
     [xlimit lo hi] [ylimit lo hi] [xindices lo hi] [xcompress n]
     [xdelta d] [ydelta d] [xlog] [ylog] [loglog] [linear] [nogrid]
     [polar] [smith] [xlabel "..."] [ylabel "..."] [title "..."] [samep]
```
(keywords read in `src/frontend/plotting/plotit.c:328-706`). Help string:
`"expr ... [vs expr] [xl xlo xhi] [yl ylo yhi] : Plot things."`

Sister commands: `asciiplot` (`commands.c:232`), `gnuplot file plotargs` (`:212`),
`pyplot [file] plotargs` (`:216`), `hardcopy file plotargs` (`:228`),
`wrdata file plotargs` (`:220`), `write file expr ...` (`:236`), `wrs2p file` (`:224`).

**Dot card**:
```
.plot <an> <expr> ... [(lo,hi)] [linear|xlog|ylog|loglog]
.print <an> <expr> ...
```
Both accept `name=par('expr')` (creates a B source, §1.7c) and the `fixem()` shorthands (§6.4).

**Persisting it.** ngspice has no "saved plot definition" concept. A plot expression is saved
either as a `.plot`/`.print` card in the deck, or as a `plot`/`wrdata` line in a `.control` block.
**The GUI owns the persistence.** ASE-L should keep its own outputs list (name, expression, kind,
axis, analysis) in the schematic/session and regenerate the deck lines on every run. That is
exactly how ADE's "Outputs" pane behaves and it side-steps every ngspice quirk above.

What ngspice *does* persist per run is the raw file: `write <file> <expr> ...` evaluates the
expressions and writes the results, so a GUI can materialise derived waveforms into the rawfile and
let its waveform viewer read them back with no expression engine of its own. `set filetype=ascii`
switches the raw format (manual 13.7: *"This can be either ascii or binary … The default is
binary."*).

## 7.2 Measure a scalar

Two shapes, and the GUI should offer exactly one to the user:

**Shape A — dot card** (deck is self-contained, results are text):
```
.meas <an> <name> <function> <args>
```
plus `set measoutfile=<path>` in a `.control` block, or `.control`-free batch and parse stdout.
Costs: no vector, `param=` one-shot, blocked by `-r`, one-analysis-per-deck, `par()` mutates the
netlist.

**Shape B — control command** (recommended):
```
.control
  <analysis command>
  let <tmp> = <expression>          $ one per user expression
  meas <an> <name> <function> <args using vectors only>
.endc
```
Costs: `param`/`par` unavailable (use `let`), no autostop, 7-digit vector.

**Persistence**: again the GUI's job. A measurement definition is (name, analysis, function,
signal-expression, qualifiers). ASE-L should store that tuple and emit either shape on demand.
Because Shape B needs a `let` for anything that is not a bare vector name, the natural internal
model is: *every* output row carries an expression; at emit time the GUI decides whether the
expression is a plain vector reference (emit directly) or needs a hoisted `let`.

## 7.3 Where each result lands (summary table)

| Produced by | stdout | `measoutfile` | vector | `.param` | new plot | rawfile |
|---|---|---|---|---|---|---|
| `.meas` card | ✔ | ✔ | ✘ | ✔ | ✘ | ✘ |
| `meas` command | ✔ (redirectable) | ✘ | ✔ (len 1, current plot) | ✘ | ✘ | via `write` |
| `.four` card | ✔ | ✘ | ✔ `fourierMN`,`thdMN` | ✘ | ✘ | ✘ |
| `fourier` cmd | ✔ | ✘ | ✔ same | ✘ | ✘ | ✘ |
| `fft` / `psd` / `spec` | banner only | ✘ | ✔ in the new plot | ✘ | ✔ `spN` | via `write`/`wrdata` |
| `linearize` / `cutout` | warnings only | ✘ | ✔ copies | ✘ | ✔ `tranN` | ✘ |
| `.print` / `print` | ✔ | ✘ | ✘ | ✘ | ✘ | ✘ |
| `write` | ✘ | ✘ | ✘ | ✘ | ✘ | ✔ |
| `wrdata` | ✘ | ✘ | ✘ | ✘ | ✘ | ✔ (columns) |

---

# 8. Complete list of control variables this area reads

| Variable | Read at | Default | Effect |
|---|---|---|---|
| `measoutfile` | `measure.c:257` | unset | mirror `.meas` output to this file (`"w"`) |
| `measureprec` | `options.c:392` | 5 | digits in measurement printouts |
| `NGSPICE_MEAS_PRECISION` (env) | `com_measure2.c:88` | unset | same, lower priority |
| `autostop` | `measure.c:250`, `inp.c:1143` | unset | stop tran when all `.meas` satisfied |
| `numdgt` | `options.c:401` | 6 | `print`, `.four` table width |
| `units` | `options.c:419` | radians | `d*` → degrees for `ph`/`vp` |
| `nfreqs` | `fourier.c:69` | 10 | fourier harmonics |
| `nperiods` | `fourier.c:71` | 1 | fourier periods |
| `polydegree` | `fourier.c:73` | 1 | fourier interpolation degree (0 = none) |
| `fourgridsize` | `fourier.c:75` | 200 | fourier grid points per period |
| `fournosave` | `fourier.c:77` | unset | suppress `fourierMN`/`thdMN` |
| `specwindow` | `com_fft.c:95,332`, `spec.c:91` | `hanning` | window function |
| `specwindoworder` | `com_fft.c:97,334`, `spec.c:141` | 2 | gaussian order (clamped ≥2) |
| `spectrace` | `spec.c:236` | unset | progress line during `spec` |
| `dpolydegree` | `cmath4.c:263` | 2 | `deriv()` polynomial degree |
| `mtimeavgwindow` | `cmath4.c:~1052` | `10*CKTstep` | `mtimeavg()` window |
| `filetype` | `write` | `binary` | `ascii` or `binary` raw |
| `casemode` / `curcasemode` | `inpcom.c:1238` | `fold` | identifier case policy (fork-local) |
| `interp` (option) | `outitf.c:211` | off | resample during the run (alternative to `linearize`) |
| `inputdir` | shell var | dir of last input file | handy for `write $inputdir/…` |

Note: `nperiods`, `fournosave`, `specwindow`, `specwindoworder`, `spectrace`, `measoutfile`,
`autostop` and `mtimeavgwindow` are **absent from `ft_setkwords[]`**
(`src/frontend/miscvars.c:26-140`), which is only the tab-completion list — they work fine.

---

# 9. Build gates relevant to this area

| Gate | Flag | Default in this tree | Effect here |
|---|---|---|---|
| `HAVE_LIBFFTW3` | `--with-fftw3` (`configure.ac:190`) | **ON** (`config.h:168`) | `fft`/`psd` use FFTW, no zero padding, different freq axis |
| `RFSPICE` | `--disable-sp` (`configure.ac:157`) | **ON** (`config.h:535`) | `.sp` analysis exists ⇒ `meas sp` on a real S-param plot exists ⇒ the crash in §1.5 is reachable |
| `WITH_PSS` | `--enable-pss` (`configure.ac:153`) | **OFF** (`config.h:576 /* #undef WITH_PSS */`) | no PSS analysis; irrelevant to `.meas` anyway (not a measurable type) |
| `HAS_PROGREP` | platform | — | `SetAnalyse("meas", 0)` / `SetAnalyse("spec", …)` progress reporting |
| `KEEPWINDOW` | not defined | off | `spec` would also export the window as a vector `win` (`spec.c:275-282`) |
| `HAVE_LIBSNDFILE && HAVE_LIBSAMPLERATE` | | — | enables `.sndparam`/`.sndprint` dot cards next to `.print` (`dotcards.c:370-406`) |
| `USE_OMP` | `--enable-openmp` | — | parallelises `mtimeavg` only |

---

# 10. Documentation vs. source: the conflict list

| # | Manual says | This tree does | Trust |
|---|---|---|---|
| 1 | `.MEASURE … DERIV<ATIVE> …` with three forms (§11.4.11) | `"function 'deriv' currently not supported"` (`com_measure2.c:2156-2166`) | **source** |
| 2 | `ERR`/`ERR1`/`ERR2`/`ERR3` implied by the grammar | `"function 'err' currently not supported"` | **source** |
| 3 | `INTEG<RAL>` (§11.4.8) | only `INTEG`; `INTEGRAL` → `"no such function as 'integral'"` | **source** |
| 4 | §11.4.3: *"result will be a vector containing the result of the measurement"* | true only for the `meas` **command**; `.meas` cards create no vector (proved with `display`) | **source**; 13.5.49 states it correctly |
| 5 | 13.5.49: *"The measurement type SP is only available here [in the meas command], because a fft command will prepare the data"* | `.meas sp` cards work fine after a `.sp` run (`spdot.cir` → `s21max = 1.12377e-03 at= 1.00000e+08`) | **source** |
| 6 | 13.5.33: `specwindoworder` *"in the range 2-8"* | only `< 2` is clamped; no upper bound | source (but offer 2-8) |
| 7 | 13.5.33: *"All window functions have a rms value of 1"* | code comment says *"should have an average of one"* (`fftext.c:102`) | unresolved; do not rely on either |
| 8 | 13.5.33 window list: none/rectangular/bartlet/hanning/blackman/blackmanharris/hamming/gaussian/flattop | `fft`/`psd` also accept `bartlett`, `hann`, `triangle`, `cosine`; **`spec` rejects `blackmanharris` and `flattop`** | **source** |
| 9 | (silent) | unknown window in `fft` warns *"set to none"* but actually zeroes the signal | **source** |
| 10 | (silent) | `expr='...'` on a `.meas` card is broken; `param=` works only on the first run | **source** |
| 11 | (silent) | `TD=` is ignored by AVG/MIN/MAX/PP/RMS/INTEG | **source** |
| 12 | (silent) | the AVG printout's `to=` is not the requested `to=` | **source** |
| 13 | 13.5.45: `np=xx` *"spans from point 0 to point xx, covering xx-1 periods"* | `tstep` is retained, so the span is truncated (`np=1024` → 5.115 ms of a 10 ms run) or zero-padded (`np=auto2n` → 10.235 ms) | **source** |
| 14 | comment `/* phase (in degrees) */` at `com_measure2.c:156` | radians unless `set units=degrees` | **empirical** |
| 15 | (silent) | `meas sp WHEN/TRIG/RMS/INTEG` on a real `.sp` plot **segfaults** | **empirical** |

---

# 11. Bugs found (candidates for `doc/codex/issues/`)

1. **Segfault: `meas sp` on a complex-scale S-parameter plot.**
   `src/frontend/com_measure2.c:471` (`com_measure_when`, SP branch) and
   `src/frontend/com_measure2.c:1073` (`measure_rms_integral`, no SP branch) dereference
   `v_realdata` of a complex `frequency` vector. Repro: `.sp lin 100 1e8 1e9 1` then
   `meas sp w1 WHEN S_1_1=0.5` → SIGSEGV (exit 139). Fix shape: mirror the `if (dScale->v_compdata)`
   guard already present at `:736` and `:870`.
2. **`.meas … expr='…'` never works.** `src/frontend/subckt.c:405` defers only lines matching
   `cistrstr(c->line, "param")`. Fix shape: also defer `expr`, or defer any `.meas` line.
3. **`.meas … param='…'` works only on the first run of a circuit load.** Same numparam
   placeholder-consumption issue; second `run` prints `insertnumber: fails.` and `failed`.
4. **Unknown `specwindow` silently zeroes the FFT.** `src/frontend/com_fft.c:102-103` warns
   `set to "none"` but does not set anything; `fft_windows` returns without writing `win[]`.
   `com_psd` (`:339-340`) aborts instead — the two should agree.
5. **`specwindow` is compared case-sensitively for `fft`/`psd` but case-insensitively for `spec`**
   (`eq()` in `fftext.c` vs `eqc()` in `spec.c`). Invisible from a deck, fatal from a pipe or
   `libngspice`.
6. **`.meas ac … vm(out)` emits an unparseable save token** (`Warning: can't parse 'vm': ignored`)
   and, with no other AC-scoped save, kills the AC analysis outright
   (`Error: no data saved for A.C. Small signal analysis; analysis not run`).
7. **AVG's echoed `to=` is the last scanned scale value, not the window end**
   (`com_measure2.c:951`).
8. **The `Measurements for <X> Analysis` banner is taken from the first `.meas` card, not the
   analysis that ran** (`measure.c:317-340`).

None of these were fixed — this dossier is read-only reconnaissance.

---

# 12. Appendix: reproduction decks

All under
`/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/measwork/`:

| File | Demonstrates |
|---|---|
| `meas_tran.sp` | every implemented measurement type in one tran run |
| `meas_expr.sp` | `expr=` broken vs `param=` working |
| `rerun.sp` | `param=` failing on the second run |
| `chain.sp` | chained `param=` referencing earlier measurements |
| `antypes.sp` | which analysis words `.meas` accepts |
| `rc-meas-ac.sp` (copy of `examples/measure/`) | AC measurements, `vm/vr/vi/vp/vdb` |
| `acmeas.sp` + `acmeas.cmd` | AC type prefixes, `im()` failing, `-3 dB` via `let`+`WHEN` |
| `dcsweep.sp` + `dcmeas.cmd` | DC multi-branch `RISE=n` counting |
| `sp_meas.cir`, `sp_one.cir`, `spdot.cir` | the SP segfault matrix and the working `.meas sp` card |
| `four.sp`, `fourcmd.sp`, `fourvec.sp` | `.four` output, options, vector readback |
| `fft.sp`, `fft2.sp`, `win.sp`, `win2.sp` | `fft`/`psd` vs `linearize`, all windows, case sensitivity |
| `spec2.sp` + `spec2.cmd`, `specacc.cmd` | `spec` validation errors, accuracy vs `linearize` |
| `lin.cmd`, `lin2.cmd`, `lin3.cmd` | `linearize` np=/auto2n/lin-tstart, `cutout`, zero padding |
| `readback.sp`, `readback2.sp`, `scal2.cmd`, `asc.cmd`, `prec.cmd`, `prec2.cmd` | every readback route and the precision ceiling |
| `two.sp` … `two5.sp`, `multi.cmd` | multi-analysis dispatch, the save-scoping trap, the clean control route |
| `casedist.sp` + `case.cmd` | `casemode` × measurement name resolution |
| `mos.sp` + `mos.cmd` | `@dev[param]`, `@model[param]`, branch currents, differentials |
| `parprint.sp` | `par()` in `.print` / `.four` creating B sources |
| `rawmeas.sp`, `rmeas.sp` | `-r` blocking `.meas` cards but not the `meas` command |
| `autostop.sp` | autostop |
| `prefix.sp` | `.meas` / `.measure` accepted, `.measurement` not |
