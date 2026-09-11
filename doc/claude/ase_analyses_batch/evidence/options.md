# Dossier: the complete ngspice simulator-option catalogue

**Tree:** `/home/analog/dev/ngspice`, branch `ver_50`, `git describe` = `ngspice-46-419-gccebdf2a2`.
**Build inspected:** `/home/analog/dev/ngspice/build-ver_50` (bare `../configure`), binary
`/home/analog/dev/ngspice/build-ver_50/src/ngspice`, self-identifies as `ngspice-46+`.
All "verified by running" claims below were produced with that binary against scratch decks;
neither repository was modified.

**Reader:** a future Claude Code session building ASE-L in
`/home/analog/dev/xschem-claude/src/ase.tcl` / `ase_window.tcl`. This dossier is the
*option* half of the picture: what a user can set, how the GUI must deliver it, and what
happens when it does.

Source anchors are `path:LINE` relative to `/home/analog/dev/ngspice`.
Where a claim came from running the binary it is marked **[verified]**.
There is no ngspice manual in this tree (`doc/` holds only `claude/` and `codex/`), so
documentation cross-checks are limited to what the source itself says; the upstream manual
lives at <https://ngspice.sourceforge.io/docs.html> and was **not** consulted. Every
statement below is therefore sourced to code or to an observed run, and where I believe the
published manual says something different I say so explicitly and explain why I trust the code.

---

## 1. The one thing to internalise first: there are FIVE different option mechanisms

A GUI that thinks "an option is an option" will ship broken. In this tree the word "option"
covers five mechanisms with different syntax, different lifetime, different precedence and
different failure modes.

| # | Mechanism | Written as | Storage | Who consumes it |
|---|---|---|---|---|
| **A** | Simulator task options (the `OPTtbl` table) | `.options x=y`, `option x=y`, `set x=y` | `TSKtask` on `ft_curckt->ci_defOpt`, copied into `CKTcircuit` at run | `CKTsetOpt()` `src/spicelib/analysis/cktsopt.c:33` |
| **B** | Read-only run statistics (same table, `IF_ASK`) | `rusage <name>` | `ckt->CKTstat` | `CKTacct()` `src/spicelib/analysis/cktacct.c:32` |
| **C** | Front-end variables read lazily via `cp_getvar()` | `set x=y` **or** `.options x=y` | global `variables` list, or `ft_curckt->ci_vars` | scattered `cp_getvar()` call sites |
| **D** | Front-end variables handled imperatively in `cp_usrset()` | `set x=y` / `option x=y` **only** | C globals (`cp_numdgt`, `ft_acctprint`, …) | `cp_usrset()` `src/frontend/options.c:322` |
| **E** | Netlist-preprocessing pseudo-options | `.options x=y` scanned as raw text | rewrite the card deck | `eval_opt()` `src/frontend/inp.c:431`, `inp_savecurrents()` `src/frontend/inp.c:2417`, `inp_add_series_resistor()` `src/frontend/inpcom.c:8304` |

### 1.1 How the three doors actually converge (mechanism A)

```
.options reltol=1e-5           option reltol=1e-5          set reltol=1e-5
        |                              |                          |
 inp_getopts()  src/frontend/options.c:263                        |
  strips the card out of the deck      |                          |
        |                       com_option()  ------------> cp_vset() -> cp_usrset()
 cp_setparse() -> ft_curckt->ci_vars   src/frontend/com_option.c:134   src/frontend/options.c:322
        |                                                          |
 inp_dodeck() loop  src/frontend/inp.c:1605                        |
        \______________________  if_option()  ____________________/
                                 src/frontend/spiceif.c:464
                                        |
                        ft_sim->setAnalysisParm(ckt, ci_defOpt, id, val)
                                        |
                                 CKTsetOpt()  src/spicelib/analysis/cktsopt.c:33
                                        |  writes TSKtask fields
                                        v
                    CKTdoJob() copies TSK* -> CKT*  src/spicelib/analysis/cktdojob.c:52-120
                                        |
                                    the run
```

Name lookup into `OPTtbl` is **case-insensitive** (`cieq`) — `ft_find_analysis_parm()`
`src/frontend/spiceif.c:1848`.

There is a **fourth, separate path** for `.options` lines that contain a brace expression
(`{...}`): `inp_getopts()` deliberately skips them (`src/frontend/options.c:271`,
`!strchr(dd->line, '{')`), so they stay in the deck, reach `INP2dot` →
`dot_options()` `src/spicelib/parser/inp2dot.c:818` → `INPdoOpts()`
`src/spicelib/parser/inpdoopt.c:21`, which is the **only** path that validates option names.

### 1.2 Precedence and lifetime — the rules a GUI must encode

1. **`set`/`option` issued before a circuit is loaded does NOT reach the simulator.**
   `if_option()` with `ckt == NULL` prints
   `Simulation parameter "%s" can't be set until a circuit has been loaded.`
   and returns (`src/frontend/spiceif.c:562-568`). The variable is still recorded in the
   global list, but **nothing ever replays it into the new circuit** — the only replay loop
   in `inp_dodeck()` walks `ci_vars`, i.e. `.options` lines, not globals
   (`src/frontend/inp.c:1605-1625`).
   **[verified]** `set reltol=7e-6` in a `.spiceinit` produced exactly that warning and the
   run used `reltol = 0.001`.
   → **A GUI must never configure mechanism-A options in `spinit`/`.spiceinit`.** Write them
   as `.options` in the deck, or issue `option …` from inside `.control` after the circuit
   is loaded.

2. **Order of application within one deck load** is: `.options` lines (`ci_vars` loop,
   `src/frontend/inp.c:1605`) → then `.control` commands. So a `.control`-section
   `option`/`set` **overrides** a `.options` card. **[verified]**

3. **`unset <simopt>` does not restore the default.** `cp_remvar()` calls
   `cp_usrset(v, FALSE)` with the *existing* value still in `v`
   (`src/frontend/variable.c:645`), so the value is simply re-applied.
   **[verified]** `option reltol=5e-4` then `unset reltol` → run still used `5e-4`.

4. **`reset` DOES restore all mechanism-A defaults**, because `com_rset` re-enters
   `inp_dodeck` → `if_inpdeck` → `ft_sim->newTask` → `CKTnewTask()`
   (`src/spicelib/analysis/cktntask.c:17`), which rebuilds the task from the hard-coded
   application defaults and then re-applies the deck's `.options`.
   **[verified]** `option reltol=5e-4` ; `reset` ; run → `reltol = 0.001`.
   → **`reset` is the GUI's "revert options to default" button.**

5. **`.options` values live on `ft_curckt->ci_vars` — per circuit.** `set` values live on the
   global `variables` list — per session. For mechanism-C options `cp_getvar()` searches
   *global first*, then usrvars, then plot env, then `ci_vars`
   (`src/frontend/variable.c:773-793`), so **`set` shadows `.options`** for that class.

6. **`set` output legend** (`cp_vprint()` `src/frontend/variable.c:1223-1242`):
   `' '` = global (from `set`), `'*'` = plot / computed, `'+'` = circuit (from `.options`).
   A GUI can parse `set` output to discover what a deck asked for. **[verified]**

7. **Unknown option names are silently accepted** on the plain `.options` / `option` / `set`
   path — `if_option()` returns 0 with no message (`src/frontend/spiceif.c:522`).
   **[verified]** `option nosuchopt=3` produced no output at all.
   On the brace path, `INPdoOpts()` emits
   `Error: unknown option %s - ignored` and marks the card in error, which in batch mode
   **aborts the netlist** (`src/spicelib/parser/inpdoopt.c:75`). **[verified]**
   → **The GUI is the only validator.** Ship the option catalogue in the GUI.

8. **Engineering suffixes work** on `.options` values (`1p`, `5m`, `2u`, `1n`).
   **[verified]** `.options gmin=3p reltol=5m vntol=2u minbreak=1n` produced
   `3e-12 / 0.005 / 2e-06 / 1E-09`. (Beware when testing: `gmin=1p`, `reltol=1m`,
   `vntol=1u`, `chgtol=10f` are all *identical to the defaults*, which makes a naive test
   look like the suffix was ignored.)

9. **`option` with no arguments prints a curated snapshot of the live `CKTcircuit`**
   (`src/frontend/com_option.c:28-105`). It is the closest thing to a machine-readable
   readback, but note:
   - it prints **temperatures in Kelvin** (`300.150000`) while `.options temp=` takes Celsius;
   - the values are only meaningful **after a run**, because `CKTdoJob()` is what copies
     `TSK*` → `CKT*`; before the first analysis you see `CKTinit()` defaults
     (`src/spicelib/devices/cktinit.c:26`), which differ (e.g. `gminsteps`/`srcsteps` read
     `0` before a run and `1` after). **[verified]**
   - it does **not** print every option (no `bypass`, `oldlimit`, `minbreak`, `keepopinfo`,
     `epsmin` is there but `trtol` only shows in the charge-based branch, etc.).

10. **`.temp <val>` is not an analysis card.** `INP2dot` ignores it
    (`src/spicelib/parser/inp2dot.c:861`); the real handler is in `inp_spsource()`
    `src/frontend/inp.c:1167-1177`, which comments the card out and calls
    `cp_vset("temp", CP_REAL, …)` **after** `inp_dodeck`, so **`.temp` beats
    `.options temp=`**. Only one temperature is kept (last `.temp` wins); the SPICE2
    multi-temperature list form is **not** implemented. A temperature sweep must be a GUI
    loop. **[verified]**

---

## 2. TABLE A — the simulator task options (`OPTtbl`)

Master table: `src/spicelib/analysis/cktsopt.c:264-385` (98 entries).
Setter: `CKTsetOpt()` `src/spicelib/analysis/cktsopt.c:33`.
Application defaults: `CKTnewTask()` `src/spicelib/analysis/cktntask.c:93-145`
(plus `CKTinit()` `src/spicelib/devices/cktinit.c:47-97` for the pre-run values that
`option` prints, and `src/spicelib/devices/cktinit.c:108-122` for the XSPICE sub-structs).
Everything in this table is reachable via **all three** of `.options` / `option` / `set`
(subject to §1.2 rule 1), unless the "Reach" column says otherwise.

`TMALLOC` is `calloc` (`src/misc/alloc.c:54`), so every `TSKtask` field **not** listed in
`CKTnewTask()` defaults to **0**.

### 2.1 Tolerances and the Newton loop

| name | reach | type | default | where default set | units | affects | what it does | anchor |
|---|---|---|---|---|---|---|---|---|
| `abstol` | all 3 | real | `1e-12` | cktntask.c:96 | A | every analysis that iterates (op, dc, tran, and the op inside ac/noise/pz/disto/sp) | absolute current-convergence floor in `NIconvTest`; also the floor in per-device bypass and limiting tests | cktsopt.c:53; cktntask.c:96 |
| `reltol` | all 3 | real | `1e-3` | cktntask.c:97 | — | same as `abstol` | relative convergence tolerance on currents and charges | cktsopt.c:50; cktntask.c:97 |
| `vntol` | all 3 | real | `1e-6` | cktntask.c:99 | V | same | absolute voltage-convergence floor (`TSKvoltTol` → `CKTvoltTol`) | cktsopt.c:56; cktntask.c:99 |
| `chgtol` | all 3 | real | `1e-14` | cktntask.c:98 | C | TRAN only | charge tolerance used by the LTE timestep control: `chargetol = reltol*MAX(chargetol,chgtol)/delta` | cktsopt.c:62; cktntask.c:98; ckttrunc/`CKTterr` `src/spicelib/analysis/cktterr.c:41` |
| `trtol` | all 3 | real | `7.0` | cktntask.c:104 | — | TRAN, PSS | truncation-error over-estimation factor; larger = bigger timesteps, less accuracy. **Auto-overridden to 1 when the circuit contains XSPICE `A` devices**, unless `set xtrtol=<n>` is given | cktsopt.c:59; cktntask.c:104; cktdojob.c:81-91; cktterr.c:69 |
| `pivtol` | all 3 | real | `1e-13` | cktntask.c:123 | — | all (matrix) | absolute minimum acceptable pivot magnitude | cktsopt.c:65; cktntask.c:123 |
| `pivrel` | all 3 | real | `1e-3` | cktntask.c:124 | — | all (matrix) | minimum acceptable pivot *ratio* | cktsopt.c:68; cktntask.c:124 |
| `epsmin` | all 3 | real | `1e-28` | cktntask.c:140 | varies | model setup, mostly diode | floor clamp applied to model parameters that are logged/divided (e.g. `DIOsatCur`, knee currents) so `log()` never sees 0 | cktsopt.c:172; cktntask.c:140; `src/spicelib/devices/dio/diosetup.c:111-230` |

### 2.2 Iteration limits

| name | reach | type | default | where default set | affects | what it does | anchor |
|---|---|---|---|---|---|---|---|
| `itl1` | all 3 | int | `100` | cktntask.c:107 | DC op (and the op inside ac/noise/pz/disto/tf/sp) | `CKTdcMaxIter` — iteration limit for the top-level operating point | cktsopt.c:77; `src/spicelib/analysis/dcop.c:67` |
| `itl2` | all 3 | int | `50` | cktntask.c:108 | DC sweep; also every *inner* step of gmin/source stepping | `CKTdcTrcvMaxIter` — DC transfer-curve limit and the per-step limit used by all convergence-aid ladders | cktsopt.c:80; `src/spicelib/analysis/dctrcurv.c:306`; `src/spicelib/analysis/cktop.c:199,239,506` |
| `itl3` | — | int | — | — | none | **accepted but does nothing.** `CKTsetOpt` has an empty `case OPT_ITL3` (cktsopt.c:83) and the table entry lacks `IF_SET`, so `if_option` reports `Warning: option itl3 is currently unsupported.` | cktsopt.c:83,293; spiceif.c:447,514 |
| `itl4` | all 3 | int | `10` | cktntask.c:106 | TRAN, PSS | `CKTtranMaxIter` — per-timepoint iteration limit; exceeding it halves the timestep | cktsopt.c:85; `src/spicelib/analysis/dctran.c:709` |
| `itl5` | — | int | — | — | none | same treatment as `itl3` — `Warning: option itl5 is currently unsupported.` | cktsopt.c:88,295; spiceif.c:448 |
| `itl6` | all 3 | int | `1` | (see `srcsteps`) | DC op | **alias for `srcsteps`** — identical `OPT_SRCSTEPS` id | cktsopt.c:296 |

**[verified]** `.options itl3=99 limpts=1000` produced
`Warning: option itl3 is currently unsupported.` and `Warning: option limpts is obsolete.`

### 2.3 Convergence aids (see §7 for the ladder these drive)

| name | reach | type | default | where default set | affects | what it does | anchor |
|---|---|---|---|---|---|---|---|
| `gmin` | all 3 | real | `1e-12` | cktntask.c:93 | all | conductance added in parallel with every nonlinear device junction | cktsopt.c:44; cktntask.c:93 |
| `gshunt` | all 3 | real | `0` | cktntask.c:94 | all | extra conductance node→ground, added on the matrix diagonal (`CKTdiagGmin` base value) | cktsopt.c:47; cktntask.c:94; cktop.c:252 |
| `noopiter` | all 3 | flag | `0`, but **`optran` sets it to 0 explicitly at startup** | cktntask.c:132 / optran.c:86 | DC op | skip the plain Newton attempt and go straight to gmin stepping | cktsopt.c:41; `src/spicelib/analysis/cktop.c:40` |
| `gminsteps` | all 3 | int | `1` **at run time** (see note) | cktntask.c:121, then `com_optran` overwrites → optran.c:87 | DC op | `0` = no gmin stepping. `1` = dynamic gmin, then "true gmin". `>1` = SPICE3-style fixed ladder of that many steps | cktsopt.c:93; cktop.c:57-77 |
| `srcsteps` / `itl6` | all 3 | int | `1` **at run time** | cktntask.c:120, optran.c:88 | DC op | `0` = none. `1` = Gillespie adaptive source stepping. `>1` = SPICE3 fixed ladder | cktsopt.c:90; cktop.c:85-92 |
| `gminfactor` | all 3 | real | `10` | cktntask.c:122 | DC op | multiplier per gmin step | cktsopt.c:96; cktop.c:188,300-302 |
| `nodedamping` | all 3 | flag | `0` | cktntask.c:137 | DC op / TRAN op | enables iteration-to-iteration node-voltage damping in `NIiter` | cktsopt.c:160; `src/maths/ni/niiter.c:297` |
| `absdv` | all 3 | real | `0.5` | cktntask.c:138 | **none — dead** | intended max absolute iter-to-iter ΔV. Stored in `TSK`/`CKT` but **never read**: the damping code in `niiter.c:310-318` hard-codes `maxdiff > 10` and `damp_factor >= 0.1` | cktsopt.c:163; niiter.c:297-324 |
| `reldv` | all 3 | real | `2.0` | cktntask.c:139 | **none — dead** | same as `absdv` | cktsopt.c:166 |
| `rshunt` | all 3 | real | disabled | `src/spicelib/devices/cktinit.c:122` | DC op, DC sweep, TRAN, **and AC** | resistance from *every* voltage node to ground; converted to `gshunt = 1/rshunt` and stamped on the diagonal. Values `<= 1e-30` are rejected with `WARNING - Rshunt option too small. Ignored.` **XSPICE-gated**: without XSPICE it prints `WARNING - Option Rshunt available only with XSPICE enabled.` | cktsopt.c:244-256; `src/spicelib/analysis/cktload.c:109-113`; `src/spicelib/analysis/acan.c:443-446`; `src/spicelib/analysis/cktsetup.c:355` |
| `cshunt` | all 3 | real | `-1` (task) / effective: unset | cktntask.c:95 | **the `OPTtbl` entry is dead**; the *real* implementation is mechanism E | `OPT_CSHUNT` writes `TSKcshunt` → `CKTcshunt`, which is read by **nothing** except the `option` printout and the `snsave` snapshot. The working path is `eval_opt()` scanning the raw text for `cshunt=`, setting the variable `cshunt_value`, which `INPpas4()` uses to hang a capacitor on every voltage node | cktsopt.c:175; `src/frontend/inp.c:473-487`; `src/spicelib/parser/inppas4.c:29-80`; dead-end shown by grep in §8 |

> **Note on `gminsteps`/`srcsteps` defaults.** `CKTnewTask` sets both to `1`, but
> `cp_init()` unconditionally runs `com_optran` with the argument list `1 1 1 100n 10u 0`
> (`src/frontend/init.c:77-94`), and `inp_dodeck` later calls `com_optran(NULL)`
> (`src/frontend/inp.c:1585`), which writes `TSKnoOpIter=0`, `TSKnumGminSteps=1`,
> `TSKnumSrcSteps=1` onto `ci_defTask` (`src/spicelib/analysis/optran.c:86-88`).
> **The practical consequence: in this build "OP by transient" (`optran`) is ON by default**
> with step `100n`, final time `10u`, ramp `0`. That is a significant behavioural default a
> GUI should surface, because it changes what "the operating point failed" means.

### 2.4 Time integration (TRAN / PSS)

| name | reach | type | default | where default set | affects | what it does | anchor |
|---|---|---|---|---|---|---|---|
| `method` | all 3 | string | `trap` (`TRAPEZOIDAL`) | cktntask.c:109 | TRAN, PSS | integration method. **Only `trap*` and `gear` are accepted** — the parse is `strncmp(v,"trap",4)==0` or `strcmp(v,"gear")==0`, anything else returns `E_METHOD` | cktsopt.c:141-147 |
| | | | | | | **[verified]** `option method=euler` → `setAnalysisParm(options) ci_curOpt: unsupported integration method`. If the manual lists `euler` as a `method` value, **the manual is wrong for this tree**; backward Euler is reached via `xmu=0`, not via `method` | |
| `maxord` | all 3 | int | `2` | cktntask.c:110 | TRAN (Gear only) | Gear integration order. **Clamped to `[1,6]` with a stderr warning** on out-of-range input | cktsopt.c:123-134 |
| `xmu` | all 3 | real | `0.5` | cktntask.c:119 | TRAN (trapezoidal only) | the trapezoidal weight. `0.5` = classic trapezoidal, `0` = backward Euler, `0.49` = damped trapezoidal (the in-source recommendation for ring-oscillator current ringing) | cktsopt.c:120; cktntask.c:113-119; `src/maths/ni/nicomcof.c:43-44` |
| `minbreak` | all 3 | real | `0` → derived | cktntask.c (absent ⇒ 0) | TRAN, PSS | minimum spacing between breakpoints. If left at 0, TRAN derives it: **`10 * delmin` in an XSPICE build**, `maxstep * 5e-5` otherwise. `delmin` itself is `1e-11 * CKTmaxStep` and is **not settable** | cktsopt.c:138; `src/spicelib/analysis/dctran.c:161-168`; `src/spicelib/analysis/traninit.c:36` |
| `trytocompact` | all 3 | flag | `0` | cktntask.c:133 | TRAN, only for `LTRA` lossy lines | enables history compaction on LTRA lines | cktsopt.c:148; `src/spicelib/devices/ltra/ltraacct.c:84` |
| `bypass` | all 3 | int | `0` | cktntask.c:105 | all iterative | nonzero enables per-device "unchanged since last iteration → skip reload". Devices test it as a plain truth value | cktsopt.c:114; e.g. `src/spicelib/devices/bsim4/b4ld.c:514` |
| `newtrunc` | all 3 | flag | `0` | cktntask.c:103 | TRAN | switch from charge-based to **voltage-based** truncation error. **BUILD-GATED on `PREDICTOR`**, which is `--enable-predictor` and is **OFF** in this tree (`build-ver_50/src/include/ngspice/config.h:529` is `/* #undef PREDICTOR */`). Without it, `CKTsetOpt` forces the flag to 0 and prints `Warning: Option 'newtrunc' ignored, compilation with preprocessor flag 'PREDICTOR' is required.` | cktsopt.c:199-207 |
| `ltereltol` | all 3 | real | `1e-3` | cktntask.c:100 | TRAN, **only if `newtrunc`** | relative LTE tolerance in the voltage-based truncation path | cktsopt.c:190; `src/spicelib/analysis/ckttrunc.c:86` |
| `lteabstol` | all 3 | real | `1e-6` | cktntask.c:101 | TRAN, **only if `newtrunc`** | absolute LTE tolerance | cktsopt.c:193; ckttrunc.c:86 |
| `ltetrtol` | all 3 | real | `500.0` | cktntask.c:102 | TRAN, **only if `newtrunc`** | LTE over-estimation factor | cktsopt.c:196; ckttrunc.c:96 |

Because `PREDICTOR` is off here, **`newtrunc` / `ltereltol` / `lteabstol` / `ltetrtol` are
inert in this build.** A GUI should hide them unless it can detect the build flag (there is
no runtime query for it; the only signal is the stderr warning when `newtrunc` is set).

### 2.5 Temperature

| name | reach | type | default | where default set | units | affects | what it does | anchor |
|---|---|---|---|---|---|---|---|---|
| `temp` | all 3, **and readable** | real | `27` °C (`300.15` K) | cktntask.c:125 | °C in, K stored | everything | operating temperature. `CKTsetOpt` adds `CONSTCtoK` (cktsopt.c:75). Read back with `rusage temp` (returns °C, cktacct.c:166) | cktsopt.c:74; cktntask.c:125 |
| `tnom` | all 3, **and readable** | real | `27` °C | cktntask.c:126 | °C in, K stored | model parameter extraction | nominal/measurement temperature for model parameters. `rusage tnom` returns °C | cktsopt.c:71; cktacct.c:169 |

**[verified]** `.options temp=85 tnom=25` → header line
`Doing analysis at TEMP = 85.000000 and TNOM = 25.000000`
(`src/spicelib/analysis/cktdojob.c:122`), `rusage temp` → `Operating temperature = 85`,
`echo $temp` → `85`. But `option` prints `temp = 313.150000` — **Kelvin**. Three different
units in three readbacks; the GUI must normalise.

### 2.6 MOS geometry defaults

| name | reach | type | default | where default set | units | affects | what it does | anchor |
|---|---|---|---|---|---|---|---|---|
| `defl` | all 3 | real | `1e-4` | cktntask.c:128 | m | MOS devices | default channel length when the instance omits `L` | cktsopt.c:102 |
| `defw` | all 3 | real | `1e-4` | cktntask.c:129 | m | MOS devices | default channel width | cktsopt.c:105 |
| `defad` | all 3 | real | `0` | cktntask.c:130 | m² | MOS devices | default drain diffusion area | cktsopt.c:108 |
| `defas` | all 3 | real | `0` | cktntask.c:131 | m² | **BROKEN — writes AD, not AS** | `case OPT_DEFAS: task->TSKdefaultMosAD = val->rValue;` — the source-area default is unreachable | **cktsopt.c:111-113** |
| `defm` | all 3 | real | `1` | cktntask.c:127 | — | MOS devices | default multiplier `M` | cktsopt.c:99 |

**[verified] `defas` bug.** `.options defas=3.0` → `option` reports `Default AD: 3.000000`,
`Default AS: 0.000000`. `.options defad=5.0` → `Default AD: 5.000000`. There is **no way** to
set `defas` in this build. A GUI should either grey the field out or warn.
(Testing tip: `option` prints these with `%f`, so any value below ~1e-6 renders as
`0.000000` and looks like it was ignored — use big test values.)

### 2.7 Model / device behaviour switches

| name | reach | type | default | where default set | affects | what it does | anchor |
|---|---|---|---|---|---|---|---|
| `oldlimit` | all 3 | flag | `0` | (calloc) | MOS1/2/3/6/9, VDMOS, SOI3 | use SPICE2-style MOSFET voltage limiting instead of the SPICE3 one | cktsopt.c:135; `src/spicelib/devices/mos1/mos1load.c:370` |
| `badmos3` | all 3 | flag | `0` | cktntask.c:134 | MOS3, MOS9 | restore the old (kappa-discontinuous) MOS3 model | cktsopt.c:151; `src/spicelib/devices/mos3/mos3load.c:731` |
| `copynodesets` | all 3 | flag | `0` | cktntask.c:136 | DC op | propagate `.nodeset` values from a device's external terminals onto its internal nodes | cktsopt.c:157; `src/spicelib/devices/bsim4/b4set.c:2461` |
| `indverbosity` | all 3 | int | `2` | cktntask.c:112 | setup/temp | verbosity of the coupled-inductor (`K`) consistency check. `0` = silent, `1` = errors only, `2` = full | cktsopt.c:117; `src/spicelib/devices/ind/muttemp.c:58,183` |
| `keepopinfo` | all 3 | flag | `0` | cktntask.c:135 | AC, NOISE, PZ, DISTO, SP | record and emit the operating point that each small-signal analysis computed | cktsopt.c:154; `src/spicelib/analysis/acan.c:155`, `noisean.c:221`, `pzan.c:53`, `distoan.c:104`, `span.c:476` |
| `noopac` | all 3 | flag | `0` | cktntask.c:77 (copy) / calloc | AC, NOISE, SP | skip the operating-point solve before a small-signal analysis — **only honoured when the circuit is linear**: `ckt->CKTnoopac = task->TSKnoopac && ckt->CKTisLinear` | cktsopt.c:169; **cktdojob.c:109**; acan.c:133, noisean.c:199, span.c:454 |

`CKTisLinear` is decided by `cktislinear()` (`src/frontend/inp.c:1441`) — R, L, C only.

### 2.8 Matrix solver

| name | reach | type | default | where default set | affects | what it does | anchor |
|---|---|---|---|---|---|---|---|
| `klu` | all 3 | flag | off (`CKTkluOFF`) | cktntask.c:143 | all | select KLU as the direct linear solver. `klu=0` turns it back off (`TSKkluMODE = (iValue != 0)`) | cktsopt.c:183; `src/include/ngspice/smpdefs.h:33` |
| `sparse` | all 3 | flag | on (the default solver) | cktntask.c:143 | all | select Sparse 1.3. Implemented as `TSKkluMODE = (iValue == 0)`, so **`sparse` (bare, value 1) selects Sparse and `sparse=0` selects KLU** — deliberately inverted, and easy to get wrong | cktsopt.c:180 |
| `klu_memgrow_factor` | all 3 | real | `1.2` | cktntask.c:144 | all, KLU only | **BROKEN.** `task->TSKkluMemGrowFactor = (val->rValue == 1.2);` assigns the *boolean result of a comparison* to a double, so any value other than exactly `1.2` sets the factor to `0.0`, and `1.2` sets it to `1.0`. This propagates to `KLUmatrixCommon->memgrow` | **cktsopt.c:186-188**; `src/maths/ni/niinit.c:36`; `src/maths/KLU/klusmp.c:1117` |

All three are **BUILD-GATED on `KLU`** (`--disable-klu`), which is **ON by default** and is
defined in this build (`build-ver_50/src/include/ngspice/config.h:463`).

**[verified]** `.options klu` → `Using KLU as Direct Linear Solver` and `option` reports
`Matrix solver: KLU`. The solver banner is printed at `src/spicelib/analysis/cktsetup.c:388`
— a GUI can scrape it to confirm what actually ran.

### 2.9 XSPICE / event-driven options — all BUILD-GATED on `XSPICE`

`XSPICE` is **ON by default** (`--disable-xspice` to turn off) and is defined here
(`build-ver_50/src/include/ngspice/config.h:579`). Table block: `cktsopt.c:265-277`.

| name | reach | type | default | where default set | affects | what it does | anchor |
|---|---|---|---|---|---|---|---|
| `maxopalter` | all 3 | int | `num_hybrid_outputs + 1` | `src/xspice/evt/evtinit.c:365` | DC op with A-devices | max analog↔event alternations while solving the DCOP | cktsopt.c:210 |
| `maxevtiter` | all 3 | int | `num_outputs + 1` | `src/xspice/evt/evtinit.c:359` | any analysis with event nodes | max event-propagation passes at one analysis point | cktsopt.c:214; `src/xspice/evt/evtiter.c:146` |
| `noopalter` | all 3 | flag | alternation ON | `src/spicelib/devices/cktinit.c:108` | DC op | disable analog/event alternation in the DCOP. Note the setter **ignores the value** — `case OPT_ENH_NOOPALTER: ckt->evt->options.op_alternate = MIF_FALSE;` — so `noopalter=0` still disables it | cktsopt.c:218-220; `src/xspice/evt/evtop.c:164` |
| `ramptime` | all 3 | real | `0.0` | `src/spicelib/devices/cktinit.c:118` | TRAN, PSS | **NOT a general supply ramp.** Two effects only: (a) a breakpoint is inserted at `t = ramptime` (`dctran.c:220`, `dcpss.c:242`); (b) `cm_analog_ramp_factor()` returns `t/ramptime` during TRAN/TRANOP so that **code models that choose to call it** scale their outputs. Ordinary `V`/`I` sources are untouched. If the manual describes this as "supply ramping", the manual overstates it — I trust the code, which has exactly three readers of `enh->ramp.ramptime` | cktsopt.c:222; `src/xspice/cm/cm.c:498-524` |
| `convlimit` | all 3 | flag | **already enabled** | `src/spicelib/devices/cktinit.c:119` | any analysis with code models | enable per-iteration limiting of code-model *inputs*. **It is on by default and there is no option to turn it off** — `case OPT_ENH_CONV_LIMIT` only ever sets `MIF_TRUE` | cktsopt.c:226-228; `src/xspice/mif/mifload.c:358` |
| `convstep` | all 3 | real | `0.25` | `src/spicelib/devices/cktinit.c:120` | code models | fractional step a code-model input may move between iterations. Setting it also force-enables `conv_limit` | cktsopt.c:230-233; mifload.c:360 |
| `convabsstep` | all 3 | real | `0.1` | `src/spicelib/devices/cktinit.c:121` | code models | absolute floor for the same limit | cktsopt.c:235-238; mifload.c:361 |
| `autopartial` | all 3 | flag | `MIF_FALSE` | `src/spicelib/devices/cktinit.c:133` | code models | compute code-model partial derivatives numerically for *all* models. Value ignored (always sets TRUE) | cktsopt.c:240-242 |
| `rshunt` | all 3 | real | disabled | see §2.3 | DC/TRAN/AC | see §2.3 | cktsopt.c:244 |

**Ordering trap for `maxevtiter` / `maxopalter`.** `EVTinit()` (which calls
`EVTinit_limits()` and *overwrites* both fields) runs at the end of `if_inpdeck()`
(`src/frontend/spiceif.c:226`). Plain `.options` are applied *after* that, in the
`ci_vars` loop (`src/frontend/inp.c:1605`), so they win. But `.options` with braces are
applied *during* `INPpas2`, i.e. **before** `EVTinit`, so a parameterised
`.options maxevtiter={n}` is silently discarded. Use the plain form.

### 2.10 Front-end print flags that live in `OPTtbl` but are intercepted earlier

These nine names are handled at the very top of `if_option()`
(`src/frontend/spiceif.c:472-500`) *before* the table lookup, and independently in
`cp_usrset()` (`src/frontend/options.c:351-372`). Both routes work, so all three doors work.
The `OPTtbl` rows for them have `id = 0` and no `IF_SET`, i.e. they are placeholders.

| name | reach | type | default | affects | what it does | anchor |
|---|---|---|---|---|---|---|
| `acct` | all 3 | flag | off | output | print full accounting (`rusage everything`) after the run | spiceif.c:472; `src/frontend/dotcards.c:447` |
| `noacct` | all 3 | flag | off | output | suppress the default `rusage` summary | spiceif.c:475; dotcards.c:450 |
| `noinit` | all 3 | flag | off | output | suppress the initial-transient-solution printout | spiceif.c:478 |
| `norefvalue` | all 3 | flag | off | output | suppress the reference column | spiceif.c:481 |
| `list` | all 3 | flag | off | output | print the expanded netlist listing | spiceif.c:484 |
| `node` | all 3 | flag | off | output | print a node-connection summary | spiceif.c:487 |
| `opts` | all 3 | flag | off | output | print the option/variable list after the run (`cp_vprint()`) | spiceif.c:490; dotcards.c:440-444 |
| `nopage` | all 3 | flag | off | output | no page breaks | spiceif.c:493 |
| `nomod` | all 3 | flag | off | output | do not print the model summary | spiceif.c:496 |

**Trap:** on the `if_option` path these are set to `TRUE` unconditionally and never cleared
(`ft_acctprint = TRUE;`). Only `unset acct` (which goes through `cp_usrset`, where
`ft_acctprint = isset`) turns them back off. They therefore **leak across circuit loads
within one session**.

### 2.11 Options recognised but rejected

| name | class | what happens | anchor |
|---|---|---|---|
| `itl3`, `itl5`, `lvltim`, `maxord`\*, `method`\* | "unsupported" list | `Warning: option %s is currently unsupported.` — but note the list in `spiceif.c:446-453` is stale: `maxord` and `method` *are* implemented and never reach the warning because they have `IF_SET` | `src/frontend/spiceif.c:446-453,514` |
| `limpts`, `limtim`, `lvlcod` | "obsolete" list | `Warning: option %s is obsolete.` | spiceif.c:455-460,518 |
| `numdgt`, `cptime` | `OPTtbl` placeholders with `id=0` | fall through `if_option` with no message; `numdgt` **does** work but only through `cp_usrset` (see Table D) | cktsopt.c:307-308 |

---

## 3. TABLE B — read-only run statistics (`IF_ASK` rows of `OPTtbl`)

Read them with **`rusage <name>`** (`com_rusage` → `if_getstat` →
`ft_sim->askAnalysisQuest` → `CKTacct`). Anchors: table rows `cktsopt.c:324-351`,
implementation `src/spicelib/analysis/cktacct.c:32-176`, command plumbing
`src/frontend/resource.c:345-353`, `src/frontend/spiceif.c:1353`.

| name | type | meaning | anchor |
|---|---|---|---|
| `totiter` | int | total Newton iterations | cktacct.c:97 |
| `traniter` | int | transient-only iterations | cktacct.c:100 |
| `trancuriters` | int | iterations at the last timepoint | cktacct.c:103 |
| `equations` | int | matrix size (`CKTmaxEqNum`) | cktacct.c:38 |
| `originalnz` | int | original nonzeros | cktacct.c:41 |
| `fillinnz` | int | fill-in nonzeros | cktacct.c:57 |
| `totalnz` | int | total nonzeros. **Reads 0 under Sparse+KLU-build in some paths** — with `KLU` compiled in, the non-KLU branch is `val->iValue = 0` (cktacct.c:88) | cktacct.c:79 |
| `tranpoints` / `accept` / `rejected` | int | timepoints attempted / accepted / rejected — **the single best convergence-health metric for a GUI** | cktacct.c:106-113 |
| `time` | real | total analysis wall time | cktacct.c:115 |
| `trantime`, `tranloadtime`, `transynctime`, `tranfactortime`, `transolvetime`, `trantrunctime` | real | transient time breakdown | cktacct.c:118, 139-153 |
| `actime`, `acloadtime`, `acsynctime`, `acfactortime`, `acsolvetime` | real | AC time breakdown | cktacct.c:121, 155-165 |
| `loadtime`, `synctime`, `reordertime`, `factortime`, `solvetime` | real | overall matrix time breakdown | cktacct.c:124-138 |
| `temp`, `tnom` | real | effective temperatures **in °C** | cktacct.c:166-171 |

`rusage devtimes` additionally dumps per-device-type load time and call count
(`src/frontend/resource.c:322-336`) — excellent raw material for a "what is slow" panel.

**[verified]** `rusage totiter traniter equations tranpoints accept rejected trantime` after
a `tran` produced all seven values. `rusage task` prints only a short subset (many
`IF_ASK` rows are answered from a `JOB*` the call passes as `taskOptions`, and several
return `-1`), so **query names individually**.

---

## 4. TABLE C — front-end variables read via `cp_getvar()` (`set` **or** `.options`)

These never touch `OPTtbl`. They work from `.options` because `.options` lines are parsed
into `ft_curckt->ci_vars` (`src/frontend/inp.c:1381-1389`) and `cp_getvar()` searches that
list (`src/frontend/variable.c:791`). They also work from `set` — including from
`spinit`/`.spiceinit`, because the read is lazy. **This is the class the GUI can safely put
in a startup file.**

Precedence: `set` (global) beats `.options` (circuit) — `variables` is searched first.

### 4.1 Analysis-behaviour variables

| name | type | default | affects | what it does | anchor |
|---|---|---|---|---|---|
| `autostop` | bool | off | TRAN | stop the transient as soon as all `.measure` statements are satisfied. **Auto-disabled with a warning** if any `.meas` uses `max`/`min`/`avg`/`rms`/`integ` | `src/spicelib/analysis/dctran.c:200`; `src/frontend/measure.c:250`; `src/frontend/inp.c:1144-1153` |
| `nostepsizelimit` | bool | off | TRAN | lift the rule that `tmax` defaults to `tstep`; instead `tmax = (tstop-tstart)/50` | `src/spicelib/analysis/traninit.c:30` |
| `dyngmin` | bool | off | DC op | with `gminsteps=1`, run **only** dynamic gmin stepping instead of dynamic-then-"true" gmin | `src/spicelib/analysis/cktop.c:60` |
| `xtrtol` | int | (unset) | TRAN with XSPICE `A` devices | override the automatic `trtol → 1` reduction. Without it, ngspice prints `Reducing trtol to 1 for xspice 'A' devices` | `src/spicelib/analysis/cktdojob.c:83` |
| `num_threads` | int | `2` in code; **`8` from the shipped spinit** | matrix + device load | OpenMP thread count. **BUILD-GATED on `USE_OMP`** (`--disable-openmp`), ON by default, defined here (`config.h:570`) | `src/spicelib/analysis/cktsetup.c:316`; `src/spinit.in:14` |
| `topo_reduce` | bool | off | setup | prune dangling degree-1 R/C leaves before the matrix is bound. **Automatically skipped when `rshunt` is enabled** | `src/spicelib/analysis/cktsetup.c:72` |
| `sqrnoise` | bool | off | NOISE, SP-noise | report noise as squared (V²/Hz) instead of V/√Hz | `src/spicelib/analysis/noisean.c:242`; `src/spicelib/analysis/noisesp.c:152` |
| `notrnoise` | bool | off | TRAN | disable transient noise sources | `src/frontend/trannoise/1-f-code.c:122` |
| `noisyxspice` | bool | off | any with code models | let XSPICE code models contribute noise | `src/xspice/mif/mifload.c:464`; `src/xspice/evt/evtload.c:253` |
| `warn` | int | `0` | OP, DC sweep, TRAN | enable SOA (safe-operating-area) checking; the value becomes `CKTsoaCheck`. **Not run for AC/NOISE** | `src/frontend/inp.c:1447`; `src/spicelib/analysis/dcop.c:117`, `dctrcurv.c:427`, `dctran.c:379` |
| `maxwarns` | int | `5` | same | per-device cap on SOA warnings | `src/frontend/inp.c:1452`; e.g. `src/spicelib/devices/bjt/bjtsoachk.c:38` |
| `interp` | bool | off | TRAN output | write only interpolated data (uniform grid) to the rawfile/plot. Prints `Warning: Interpolated raw file data!` | `src/frontend/outitf.c:211`; `src/frontend/breakp.c:49` |
| `rndseed` | int | `1` | anything using random | seed for `srand`+Tausworthe. Set to `1` at startup in `main.c:936-938`, so **runs are deterministic by default**. `setseed [n]` re-seeds immediately | `src/maths/misc/randnumb.c:82,293-322`; `src/main.c:936` |
| `enable_noisy_r` | bool | off | NOISE | make behavioural (B-source-expanded) resistors noisy; per-instance `noisy=1`/`noisy=0` overrides | `src/frontend/inpcom.c:7417` |
| `ng_nomodcheck` | bool | off | setup | skip BSIM3/BSIM4 model-parameter sanity checks | `src/spicelib/devices/bsim4/b4check.c:47`, `bsim3/b3check.c:41`, and the v5/v6/v7/v32 variants |
| `scale` | real | `1` | model/instance geometry | global geometry scale factor applied to device parameters marked scalable | `src/spicelib/parser/inpgmod.c:265`; `src/spicelib/devices/bsim4/b4par.c:45` |
| `noparse` | bool | off | everything | read the deck but do not build a circuit | `src/frontend/inp.c:1372` |
| `nosubckt` | bool | off | parsing | do not expand subcircuits | `src/frontend/inp.c:936` |
| `renumber` | bool | off | parsing | renumber lines after include expansion | `src/frontend/inp.c:252` |
| `statlocal` | bool | off | parsing | scope of statistical/Monte-Carlo parameters | `src/frontend/inp.c:945` |
| `auto_bridge` | int | on | XSPICE | automatic analog↔event node bridging; `0` disables | `src/xspice/evt/evtcheck_nodes.c:975` |
| `no_auto_bridge_family` | bool | off | XSPICE | suppress family-specific auto-bridges | `src/xspice/evt/evtcheck_nodes.c:624` |
| `probe_alli_given`, `probe_alli_nox`, `probe_is_given` | bool | off | `.probe` handling | set by the `.probe` preprocessor, consumed later | `src/frontend/inpc_probe.c:99,262`; `src/frontend/inp.c:1433` |
| `sim_status` | int | — | **output** | the frontend *writes* the run's error code here; `main.c:1559` reads it for the process exit status | `src/frontend/runcoms.c:329,352,358`; `src/main.c:1559` |
| `controlswait` | bool | off | shared build | defer `.control` execution | `src/frontend/inp.c:1280` |

### 4.2 Variables read while the netlist is *being read* — `set` only, in practice

`cp_getvar()` taken during netlist reading is a **policy read**
(`inp_reading_netlist()`, `src/frontend/variable.c:724-727`, and the long rationale comment
at `variable.c:729-751`). More importantly, `ci_vars` for the *current* deck do not exist
yet at that point, so an `.options` line in the same deck cannot answer. These must come
from `set` in `spinit` / `.spiceinit` / a prior `.control`.

| name | type | values / default | what it does | anchor |
|---|---|---|---|---|
| `ngbehavior` | string | unset ⇒ `Note: No compatibility mode selected!` | compatibility dialect: substring-matched against `hs` (HSPICE), `ps` (PSpice), `xs` (XSPICE), `lt` (LTspice), `ki` (KiCad), `a` (all-netlist), `ll`, `s3` (Spice3 only), `eg` (EAGLE), `spe` (Spectre), `mc` (make-check reset). `hs`+`ps` together → warning, `ps` wins | `src/frontend/inpcompat.c:76-112` |
| `casemode` | string | `fold` (default), `preserve`, `distinguish` | identifier case policy for the whole deck; read back with `$curcasemode` | `src/frontend/options.c:68`, `src/spinit.in:17` |
| `soacheck` | bool | off | inject `.param SWSOA=1` after every `.lib` (IHP Open-PDK SOA hook). **Unrelated to `warn`** | `src/frontend/inpcom.c:4543` |
| `no_auto_gnd` | bool | off | do not rewrite `0`-like node names to ground | `src/frontend/inpcom.c:1541,2330` |
| `sourcepath`, `spicepath`, `inputdir` | list/string | see run | include search path | `src/frontend/inp.c` |
| `no_spinit`, `no_spiceinit` | bool | off | skip the init files entirely | `src/main.c` |
| `brief` | bool | off | suppress the "Processed Netlist" echo | `src/frontend/inp.c:1533` |

---

## 5. TABLE D — `set` / `option` **only**, NOT reachable from `.options`

These are handled imperatively inside `cp_usrset()` (`src/frontend/options.c:322-537`),
which is called by `cp_vset` — i.e. by the `set` and `option` commands — but **never** by the
`.options` → `ci_vars` → `if_option` loop. Putting them on a `.options` card creates a
circuit variable that nothing reads.

| name | type | default | what it does | anchor |
|---|---|---|---|---|
| `numdgt` | int | `-1` (⇒ 6 significant digits) | digits in `print`, `wrdata`, event printouts, fourier | `src/frontend/options.c:401-409`; `src/misc/printnum.c:16-24`; `src/xspice/evt/evtprint.c:380` |
| `rawfileprec` | int | `-1` | precision of ASCII rawfile values | options.c:382-390 |
| `measureprec` | int | `-1` | precision of `.measure` results | options.c:392-400 |
| `rawfile` | string | — | default rawfile name (also settable with `-r`) | options.c:349; `src/main.c:1086` |
| `strict_errorhandling` | bool | off | abort the process on the first error; also bails immediately if a `spinit` error already occurred | options.c:375-381 |
| `strictnumparse` | bool | off | reject sloppy numeric literals | options.c:373 |
| `ngdebug`, `nginfo` | bool | off | extra diagnostic output; `ngdebug` also turns on the gmin/source-stepping progress lines in `cktop.c` | options.c:355-358; `src/spicelib/analysis/cktop.c:45,156` |
| `debug` | bool/string/list | off | fine-grained debug classes: `siminterface`, `cshpar`, `parser`, `eval`, `vecdb`, `graf`, `control`, `async`, `shvecsearch`. **BUILD-GATED on `FTEDEBUG`**, not defined here, so it warns `compiled without debug messages` | options.c:330-348, 540-563 |
| `units` | string | `radians` | `degrees`/`radians` for the control-language trig and phase | options.c:419-423 |
| `unixcom` | bool | off | allow shell commands as ngspice commands | options.c:410-418 |
| `curplot`, `curplotname`, `curplottitle`, `curplotdate` | string | — | rename / switch the current plot (`US_DONTRECORD`) | options.c:424-464 |
| `plots`, `curcasemode` | — | — | **read-only** (`US_READONLY`) | options.c:465-472 |

**[verified]** `.options numdgt=10` then `print v(1)` → `1.234568e+00` (6 digits, i.e. no
effect); `set numdgt=10` then `print v(1)` → `1.2345678900e+00`. This is the cleanest
demonstration of the Table C / Table D split.

`ft_setkwords[]` (`src/frontend/miscvars.c:25-133`) is a hand-maintained list of "known"
`set` names used for help/completion. **It is stale** — it lists `polysteps` (read by
nothing in the tree), `maxwins`, `slowplot`, `dontplot`, `dpolydegree`, `geometry<num>`,
and omits most of Table C. Do not use it as the GUI catalogue.

---

## 6. TABLE E — netlist-preprocessing pseudo-options

These are recognised by **raw text scanning of `.option` lines** before the option machinery
runs. They rewrite the deck. They are `.options`-only in practice (the scan is over
`ci_options` / the raw card text), and the scans are `cistrstr` substring matches, so they
are case-insensitive and can be triggered by a *substring* appearing anywhere on the line.

| name | syntax | default | what it does | anchor |
|---|---|---|---|---|
| `seed` | `.options seed=<n>` or `seed=random` | rndseed = 1 | seeds the RNG. `random` uses `gettimeofday` microseconds. `<n> <= 0` is rejected with a warning. Multiple `seed=` lines warn | `src/frontend/inp.c:442-471` |
| `seedinfo` | `.options seedinfo` | off | make `setseed` print the seed value it used | `src/frontend/inp.c:440`; `src/maths/misc/randnumb.c:326` |
| `cshunt` | `.options cshunt=<C>` | none | **the working cshunt.** Sets the variable `cshunt_value`; `INPpas4()` then creates a capacitor `capac<N>shunt` from every voltage node to ground, using a synthesised default `C` model. Values `<= 0` are rejected | `src/frontend/inp.c:473-487`; `src/spicelib/parser/inppas4.c:29-80` |
| `savecurrents` | `.options savecurrents` | off | append `.save @dev[i…]` for **every** device in the deck (m/j/q/d/r/c/l/b/f/g/w/s/i), plus `.save all` if no other save exists. Massively increases rawfile size | `src/frontend/inp.c:2417-2500` |
| `savecurrents_bsim3` | `.options savecurrents savecurrents_bsim3` | — | MOS variant: saves `id ibd ibs` | `src/frontend/inp.c:2458` |
| `savecurrents_bsim4` | as above | — | saves `id ibd ibs isub igidl igisl igs igb igd igcs igcd` | `src/frontend/inp.c:2461` |
| `savecurrents_mos1` | as above | — | saves `id is ig ib ibd ibs` | `src/frontend/inp.c:2464` |
| `rseries` | `.option rseries=<R>` | `1e-3` if `rseries` present with no `=` value | inserts a series resistor after **every** inductor `L`. The scan is `cistrstr(curr_line,"option")` then `cistrstr(...,"rseries")` — it fires on any line containing "option" | `src/frontend/inpcom.c:8304-8335` |
| `scale` | `.options scale=<x>` | `1` | in `hs`/`spe` compatibility modes only, hoisted early with `cp_vset("scale", …)` so that preprocessing sees it. In plain mode it still works via `ci_vars` (Table C) | `src/frontend/inp.c:879-888, 906-915` |
| `scalm` | `.options scalm=<x>` | — | **explicitly not supported**: sets the variable and prints `Warning: option SCALM is not supported.` | `src/frontend/inp.c:891-901, 918-928` |

---

## 7. The convergence ladder — design input for a "guided remedy" UI

`CKTop()` (`src/spicelib/analysis/cktop.c:26-116`) is the whole DC-operating-point strategy.
The order is fixed; the options only switch stages on and off.

```
CKTop(ckt, firstmode, continuemode, iterlim)
 |
 1. plain Newton, limit = itl1                     [skipped if noopiter]      cktop.c:40-51
 |     converged? -> done
 2. if gminsteps >= 1:                                                        cktop.c:57-77
 |     gminsteps == 1 -> dynamic_gmin()            (diagonal gmin ramp)       cktop.c:161-274
 |                       then, unless `set dyngmin`, new_gmin()               cktop.c:350-467
 |                       ("true gmin": ramps ckt->CKTgmin itself)
 |     gminsteps  > 1 -> spice3_gmin()             (fixed ladder of N steps)  cktop.c:289-346
 |     inner limit for every step = itl2, step factor = gminfactor
 |     converged? -> done
 3. if srcsteps >= 1:                                                         cktop.c:85-92
 |     srcsteps == 1 -> gillespie_src()  (adaptive; internally also tries a
 |                                        10-decade gmin ladder first)        cktop.c:481-660
 |     srcsteps  > 1 -> spice3_src()     (fixed CKTsrcFact = i/N ladder)      cktop.c:668-...
 |     converged? -> done
 4. OPtran(ckt, converged)  -- "operating point by transient"                 cktop.c:97
 |     ON BY DEFAULT in this build (see §2.3 note). Runs a transient from 0
 |     to opfinaltime with step opstepsize, optionally ramping CKTsrcFact as
 |     0.5*(1-cos(pi*t/opramptime)).                                          optran.c:671
 |     converged? -> done
 5. "Error: The operating point could not be simulated successfully."         cktop.c:110
       + "Any of the following steps may fail.!"   (or exit if
         strict_errorhandling)
```

**Progress messages a GUI can parse** (all via `SPfrontEnd->IFerrorf`, prefix `Note:`/`Warning:`):
`Starting dynamic gmin stepping`, `Dynamic gmin stepping completed|failed`,
`Starting spice3 gmin stepping`, `spice3 gmin stepping completed|failed`,
`Starting true gmin stepping`, `True gmin stepping completed|failed`,
`Starting source stepping`. With `set ngdebug` you additionally get per-step
`Trying gmin = %12.4E` and `Supplies reduced to %8.4f%%` lines
(`cktop.c:46,157,235,505,577`). **[verified]** a default run printed
`Note: Starting dynamic gmin stepping` / `Note: Dynamic gmin stepping completed`.

**Remedy → option mapping** a "convergence assistant" should offer, in escalation order:

| Symptom | Suggested change | Why |
|---|---|---|
| OP fails, message names gmin stepping | `srcsteps=10` (fixed ladder) or `gminsteps=10` | switches from the adaptive to the fixed SPICE3 ladders, which are slower but more robust |
| OP fails immediately, no stepping ran | `gminsteps=1 srcsteps=1` (they may have been zeroed) | stages 2/3 are skipped when the counts are 0 |
| OP fails, circuit has floating nodes | `rshunt=1e12` (XSPICE builds) or `gshunt=1e-12` | pins every node to ground |
| OP fails, circuit is a latch/oscillator | `optran 0 1 1 <step> <stop> <ramp>` | let the transient find a state; `optran` already runs by default with 100n/10u |
| "timestep too small" in TRAN | raise `trtol` (7 → 10), raise `itl4` (10 → 100), or set `method=gear maxord=2` | LTE control and per-point iteration limit |
| TRAN ringing on inductor currents | `xmu=0.49` | damped trapezoidal — the reason the option exists (cktntask.c:113-118) |
| Non-convergence with code models | `convstep`, `convabsstep` | limits how far a code-model input may move per iteration |
| Slow but converging | `bypass=1`, `klu` | fewer device reloads; faster factorisation |
| Diverging node voltages | `nodedamping` | note `absdv`/`reldv` are dead (§2.3), damping is fixed at ΔV>10 → factor ≥0.1 |

A GUI should present these as **named remedies with a diff preview of the `.options` line it
will write**, not as 30 numeric fields. The raw fields belong behind an "Advanced" disclosure.

---

## 8. Build gates — what is compiled in *this* tree

Checked against `/home/analog/dev/ngspice/build-ver_50/src/include/ngspice/config.h`
and `configure.ac`.

| Macro | configure flag | default | this build | options it gates |
|---|---|---|---|---|
| `XSPICE` | `--disable-xspice` | **on** | **ON** (config.h:579) | `maxopalter`, `maxevtiter`, `noopalter`, `ramptime`, `convlimit`, `convstep`, `convabsstep`, `autopartial`, `rshunt`; also changes the `minbreak` default derivation (dctran.c:161 vs 167) |
| `KLU` | `--disable-klu` | **on** | **ON** (config.h:463) | `klu`, `sparse`, `klu_memgrow_factor` |
| `OSDI` | `--disable-osdi` | **on** | **ON** (config.h:502) | no `.options`; adds the `osdi` command |
| `RFSPICE` | `--disable-sp` | **on** | **ON** (config.h:535) | adds the `SP` analysis (`.sp`), which honours `keepopinfo`, `noopac`, `sqrnoise` |
| `USE_OMP` | `--disable-openmp` | **on** | **ON** (config.h:570) | `num_threads` |
| `PREDICTOR` | `--enable-predictor` | off | **OFF** (config.h:529) | `newtrunc`, and therefore `ltereltol`/`lteabstol`/`ltetrtol` |
| `CIDER` | `--enable-cider` | off | **OFF** (config.h:10) | CIDER numeric-device options and `rusage devices` |
| `WITH_PSS` | `--enable-pss` | off | **OFF** (config.h:576) | `.pss` analysis (consumes `ramptime`, `trtol`, `itl4`) |
| `WANT_SENSE2` | `--enable-sense2` | off | **never defined anywhere** — `configure.ac:232` documents the flag but no `AC_DEFINE` or `Makefile.am` ever emits it | `.sens2` |
| `FTEDEBUG` | — | off | OFF | `set debug` classes |

---

## 9. Known defects and traps (all confirmed in source; several confirmed by running)

1. **`defas` writes `defad`.** `src/spicelib/analysis/cktsopt.c:111-113`.
   `defas` is unreachable. **[verified]**
2. **`klu_memgrow_factor` assigns a boolean.** `cktsopt.c:186-188`:
   `task->TSKkluMemGrowFactor = (val->rValue == 1.2);` → any value but `1.2` yields `0.0`.
3. **`absdv` / `reldv` are dead.** Set, copied to `CKTcircuit`, read by nothing
   (`niiter.c:297-324` hard-codes the thresholds).
4. **`cshunt` in `OPTtbl` is dead**; the working one is the text-scan pseudo-option (§6).
   The `option` printout shows `cshunt = -1` after a run — that is `TSKcshunt`'s calloc-era
   default (`cktntask.c:95`), not "no shunt". **[verified]**
5. **`convlimit` cannot be turned off.** Enabled in `cktinit.c:119`; the option only ever
   sets `MIF_TRUE` (`cktsopt.c:226`).
6. **`noopalter` and `autopartial` ignore their value** — `noopalter=0` still disables
   alternation (`cktsopt.c:218`, `cktsopt.c:240`).
7. **`sparse` has inverted polarity** — `sparse` selects Sparse, `sparse=0` selects KLU
   (`cktsopt.c:180`).
8. **Unknown option names are silent** on the plain path and **fatal** on the brace path
   (§1.2 rule 7). **[verified] both.**
9. **`unset` does not restore defaults** (§1.2 rule 3). **[verified]**
10. **`set`/`option` before a circuit is loaded is lost** (§1.2 rule 1). **[verified]**
11. **`option` printout uses Kelvin for temperatures and `%f` for the MOS defaults**, so
    small values print as `0.000000` (`com_option.c:33-34, 99-103`). **[verified]**
12. **Print-flag options leak across circuits** (§2.10).
13. **`itl3`/`itl5` are accepted and ignored** with an "unsupported" warning; the
    `unsupported[]` list in `spiceif.c:446-453` also (wrongly) names `maxord` and `method`,
    which *are* implemented.
14. **`ramptime` does not ramp SPICE sources** (§2.9) — only code models that call
    `cm_analog_ramp_factor()`, plus one breakpoint.
15. **`.temp` overrides `.options temp=`** and accepts only one value (§1.2 rule 10).
16. **The `option` command requires a loaded circuit** — `Error: no circuit loaded`
    (`com_option.c:21-24`).
17. **`polysteps`** appears in `ft_setkwords[]` but is read nowhere.

---

## 10. Classification for GUI layout

### 10.1 GLOBAL — belongs to the session / design, one value per design

Put these in a **"Simulator Options"** dialog scoped to the design, written once as
`.options` lines at the top of the generated deck.

- **Tolerances:** `abstol` `reltol` `vntol` `chgtol` `pivtol` `pivrel` `epsmin`
- **Temperature:** `temp` `tnom` (and the `.temp` card, which the GUI should own exclusively)
- **MOS defaults:** `defl` `defw` `defad` `defm` (`defas` is broken — grey it out)
- **Geometry:** `scale`
- **Solver:** `klu` / `sparse` (present as one radio group, not two flags),
  `klu_memgrow_factor` (broken — hide), `num_threads`
- **Model behaviour:** `oldlimit` `badmos3` `ng_nomodcheck` `indverbosity`
- **Compatibility / parsing:** `ngbehavior` `casemode` `no_auto_gnd` `nosubckt` `renumber`
  (these must be emitted as `set` in a preamble, not `.options` — §4.2)
- **Determinism:** `seed` / `rndseed` / `seedinfo`
- **Diagnostics:** `warn` `maxwarns` `soacheck`
- **Output/reporting:** `acct` `noacct` `noinit` `norefvalue` `list` `node` `opts` `nopage`
  `nomod` `numdgt` `rawfileprec` `measureprec` `filetype` `interp` `savecurrents`
  (`numdgt`/`rawfileprec`/`measureprec` must be `set`, not `.options` — §5)

### 10.2 PER-ANALYSIS — only meaningful when a particular analysis is enabled

Show these **inside the analysis's own form**, greyed out or hidden otherwise.

| Analysis | Options that only matter here |
|---|---|
| **OP / DC op** | `itl1`, `noopiter`, `gminsteps`, `srcsteps`/`itl6`, `gminfactor`, `nodedamping`, `copynodesets`, `dyngmin` (set-var), the whole `optran` command |
| **DC sweep** | `itl2` |
| **TRAN** | `itl4`, `trtol`, `chgtol`, `method`, `maxord`, `xmu`, `minbreak`, `trytocompact`, `autostop` (set-var), `nostepsizelimit` (set-var), `notrnoise` (set-var), `xtrtol` (set-var), `interp` (set-var), `newtrunc`+`lte*` (inert here) |
| **AC** | `noopac`, `keepopinfo` |
| **NOISE** | `keepopinfo`, `sqrnoise` (set-var), `noisyxspice` (set-var), `enable_noisy_r` (set-var) |
| **PZ / DISTO / TF** | `keepopinfo` |
| **SP** (`.sp`, RFSPICE) | `keepopinfo`, `noopac`, `sqrnoise` |
| **Any with XSPICE A-devices** | `maxevtiter`, `maxopalter`, `noopalter`, `convstep`, `convabsstep`, `autopartial`, `ramptime` |

Boundary note — the *analysis cards themselves* have their own parameter tables, which are a
different dossier. For reference, their keywords are:
`.ac` → `start stop numsteps dec oct lin` (`src/spicelib/analysis/acsetp.c`);
`.dc` → `start1 stop1 step1 start2 stop2 step2 name1 name2 type1 type2` (`dctsetp.c`);
`.tran` → `tstart tstop tstep tmax uic` (`transetp.c`);
`.pz` → `nodei nodeg nodej nodek vol cur pol zer pz` (`pzsetp.c`);
`.tf` → `outpos outneg outname outsrc insrc` (`tfsetp.c`);
`.disto` → `start stop numsteps dec oct lin f2overf1` (`dsetparm.c`);
`.noise` → `output outputref input dec oct lin numsteps start stop ptspersum` (`nsetparm.c`);
`.sens` → `outpos outneg outsrc outname start stop numsteps dec oct lin dc` (`senssetp.c`);
`.sp` → `start stop numsteps dec oct lin donoise` (`spsetp.c`).

### 10.3 CONVERGENCE AIDS — offer as guided remedies, not raw fields

Never put these on the front page. Surface them from a **"Simulation failed — try this"**
assistant driven by the ladder in §7, each remedy showing the exact `.options` line it will
add.

`gmin` `gshunt` `rshunt` `cshunt` `gminsteps` `srcsteps` `gminfactor` `noopiter`
`nodedamping` `absdv`(dead) `reldv`(dead) `convlimit` `convstep` `convabsstep`
`bypass` `optran` `dyngmin` `topo_reduce`, plus the *escalation* uses of `itl1` `itl2` `itl4`
`trtol` `method` `maxord` `xmu`.

### 10.4 Where the GUI must write each class

| Class | Correct delivery | Wrong delivery |
|---|---|---|
| `OPTtbl` options (Table A) | `.options` line in the generated deck, **or** `option x=y` inside `.control` after the circuit is loaded | `set x=y` in `spinit`/`.spiceinit` (silently lost) |
| `cp_getvar` variables (Table C) | either `set` in a preamble/`.control`, or `.options` — both work | — |
| Read-during-netlist-read variables (Table C §4.2) | `set` in `spinit`/`.spiceinit`/preamble `.control` | `.options` (too late) |
| `cp_usrset` variables (Table D) | `set`/`option` command only | `.options` (creates a dead variable) |
| Preprocessing pseudo-options (Table E) | `.options` line in the deck | `set` (the scans read card text) |
| "Revert to defaults" | the `reset` command | `unset` (no-op) |

---

## 11. Verification log (commands actually run)

All decks under
`/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/`,
run as `build-ver_50/src/ngspice --batch <deck>`:

- `opt.cir` — bare `option` dump before any analysis (CKTinit defaults).
- `opt2.cir` — `.options reltol/gmin/itl1/method/maxord/temp/tnom/srcsteps/gminsteps` +
  `option` + `set` → confirmed `.options` become `+`-marked circuit variables and reach the run.
- `opt3.cir` — `set reltol` / `option abstol` / `option method=euler` / `option nosuchopt=3`
  → confirmed euler rejected, unknown silently accepted, values applied at next `run`.
- `opt4.cir` — `.options nosuchopt itl3 limpts badmos3 noopiter` → confirmed the
  unsupported/obsolete warnings and the gmin-stepping trace.
- `opt5.cir` — `numdgt` via `.options` vs `set` → confirmed only `set` works.
- `opt6.cir` — `rusage` statistics after a `tran`.
- `opt7.cir` + `.spiceinit` — confirmed pre-load `set reltol` is lost.
- `opt8.cir` — confirmed `unset` does not restore.
- `opt9.cir` — confirmed `reset` does restore.
- `opt10.cir` — confirmed the `defas`→`defad` bug.
- `opt11.cir` — confirmed `.options klu` selects KLU.
- `opt12.cir` — confirmed `temp`/`tnom` readback in °C vs the Kelvin `option` printout.
- `opt13/14/15.cir` — confirmed engineering suffixes parse on `.options`.
- `opt16.cir` — confirmed the brace (`{...}`) path validates option names and hard-errors.

---

## 12. Gaps and open questions

1. **No manual cross-check was possible.** There is no ngspice manual in this tree. Anywhere
   this dossier says "the manual may disagree" (notably `method=euler`, `ramptime` as supply
   ramping, `defas`, `absdv`/`reldv`, `cshunt`), a second pass against
   <https://ngspice.sourceforge.io/docs.html> would let the GUI show a doc link next to each
   field — and would let us file the discrepancies upstream. I trust the source in every one
   of those cases because the behaviour is directly observable in the running binary.
2. **CIDER options are entirely uncovered** — `--enable-cider` is off here, so the CIDER
   numeric-device option set (`.options` extensions and `rusage devices`) was not enumerated.
3. **PSS (`.pss`) options are uncovered** — `--enable-pss` is off; `dcpss.c` reads
   `trtol`, `itl4`, `ramptime` and has its own `CKTsteady_coeff`, but the analysis cannot be
   exercised in this build.
4. **RFSPICE/`.sp` is compiled in but I did not run one** — I traced `keepopinfo`/`noopac`/
   `sqrnoise` into `span.c` statically. Worth a live check.
5. **The shared-library path (`libngspice`) was not exercised.** `sharedspice.c:2470` mentions
   `delmin`; whether `ngSpice_Command("option …")` behaves identically to the CLI (and
   whether options survive `ngSpice_Reset`) needs its own check — `CLAUDE.md` flags this as a
   recurring bug class. If ASE-L ever drives ngspice through the shared library rather than a
   pipe, this becomes load-bearing.
6. **Which options survive `snsave`/`snload`** is only partly clear — `spiceif.c:1523-1588`
   snapshots a `_t(...)` list of `CKT*` fields including the dead `CKTabsDv`/`CKTrelDv`, and
   the file itself warns that XSPICE `evt`/`enh` data is not properly stored
   (`spiceif.c:1825-1829`). Not exercised.
7. **No runtime introspection of build flags exists.** A GUI cannot ask ngspice "was
   PREDICTOR compiled in?"; the only signals are the `version` banner, the presence of
   `$xspice_enabled` / `$osdi_enabled` (set in `main.c:940-948`), and the stderr warnings
   emitted when an inert option is set. Consider probing at GUI startup by issuing
   `option newtrunc` on a scratch circuit and watching stderr.
8. **`.options` name collisions with `.param`/`set` names** were not explored. Because
   `.options` values become ordinary circuit variables, a design that also uses `$reltol`
   as a design parameter would collide. Worth a naming rule in the GUI.
