# Dossier: the ngspice netlist dot-card grammar for analysis, as the parser actually accepts it

Scope: every dot card that **is** an analysis or **configures** one, as implemented in
`/home/analog/dev/ngspice` on branch `ver_50` (`git describe` = `ngspice-46-419-gccebdf2a2`),
verified against the binary at `/home/analog/dev/ngspice/build-ver_50/src/ngspice`
(`ngspice-46+`, build 2026-09-03).

Every claim carries a source anchor (`file:LINE`, paths relative to `/home/analog/dev/ngspice`)
or a URL. Empirical results were produced by running the built binary read-only on scratch decks
under `/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/dot/`.
Nothing in either repository was modified.

Official documentation used for the "documented vs. actual" comparisons:
<https://ngspice.sourceforge.io/docs/ngspice-manual.pdf> (ngspice User's Manual, Version 47) and
<https://ngspice.sourceforge.io/docs/ngspice-html-manual/manual.xhtml>.

---

## 0. Executive summary for the GUI author

Ten facts that shape any ASE-L design more than the individual card grammars do:

1. **Deck order does not determine run order.** All analysis cards in a deck accumulate as *jobs*
   on one task and are executed in the fixed order of the `analInfo[]` table
   (`src/spicelib/analysis/analysis.c:36-59`), driven by `CKTdoJob()`'s outer loop over analysis
   *type* (`src/spicelib/analysis/cktdojob.c:176-213`). Order is: **OPTIONS, AC, DC, OP, TRAN, PZ,
   TF, DISTO, NOISE, SENS, [PSS], [SENS2], [SP], [HB]**.
2. **Two cards of the same type run in reverse deck order** — `CKTnewAnal()` prepends to the job
   list (`src/spicelib/analysis/cktnewan.c:34`).
3. **A malformed analysis card is fatal to the whole netlist**, not just to that analysis:
   `inp_dodeck()` returns 1 on the first card carrying an error (`src/frontend/inp.c:1497-1512`),
   and the circuit is never built. The equivalent `.control` command only aborts itself.
4. **`.control` commands `op/dc/ac/tran/tf/pz/disto/noise/sens/sp` re-use the exact card parser.**
   `if_run()` builds the string `".<what> <args>"` and hands it to `INPpas2()` → `INP2dot()`
   (`src/frontend/spiceif.c:279-286, 362`). The grammar is byte-identical; only error reporting,
   task lifetime and brace substitution differ (§8).
5. **In `--batch` mode without `-r`, nothing runs unless the deck has a `.print`, `.plot`, `.four`,
   `.meas`, `.op`, `.tf`, `.sndprint` or `.sndparam` card** (`src/frontend/dotcards.c:107-161`,
   `src/main.c:1577-1594`).
6. **`.op` and `.tf` cards install analysis-scoped `save all` entries** (`dotcards.c:154-160`), which
   silently starves every *other* analysis in the same deck of saved vectors → `Error: no data saved
   for <analysis>; analysis not run` (`src/frontend/outitf.c:479-486`).
7. **`.step` does not exist.** `.step ...` → `unimplemented dot command '.step'` and the netlist
   fails to load. Parameter sweeps must be scripted in `.control` (manual §12.11.4.3 says exactly
   this) or driven by `alterparam` + `reset` + `run`.
8. **`.options <unknown>=<value>` is silently accepted and becomes a control-language variable** —
   `.options` is the deck's `set` (§6.1). But `.options` containing `{` takes a completely
   different code path and *does* error on unknown names.
9. **`.end` is not a terminator when reading from a file.** The reader comments it out and appends
   one terminal `.end`; cards after `.end` are still parsed (`src/frontend/inpcom.c:2285-2291`,
   `2348-2351`). Verified empirically.
10. **`{expr}` works in card arguments but *not* in `.control` command arguments.** Card lines go
    through numparam; control lines were removed from the deck before numparam ran (§8.3).

---

## 1. Pipeline: where each dot card is consumed

A card can be consumed at five different stages. Knowing which stage matters, because it decides
whether an error is fatal, whether `{}` is substituted, and whether the card is even visible later.

| Stage | Function / file | Cards it consumes or rewrites |
|---|---|---|
| A. line reader | `inp_read()` `src/frontend/inpcom.c:1689-2375` | `.title` (→`*`, replaces line 1), `.include`/`.inc`/`.incpslt` (spliced in, →`*`), `.lib` (old-style rewrite under `lt`/`ps`), `.hdl` (dropped+warn), `.biaschk` (dropped+warn), `.end` (→`*`), `.control`/`.endc` (case-fold exemptions) |
| A2. library expansion | `expand_section_references()` `inpcom.c:4530-4548`, `expand_section_ref()` `inpcom.c:4416+` | `.lib <file> <section>`, `.libsave`, `.endl` |
| B. deck preprocessing | `inp_readall()`/`inpcom.c` helpers | `.probe` (`src/frontend/inpc_probe.c:45-…`), `.macro`/`.eom` (subckt aliases, `inpcom.c:3356-3359`), `.cmodel` (`inpcom.c:3755,5461`), `.dc (temper)` repair (`inpcom.c:10335-10347`), compat rewrites (`src/frontend/inpcompat.c`: `.backanno` `:1768`, `.distribution` `:266`) |
| C. front-end deck scan | `inp_spsource()` `src/frontend/inp.c:508-1300` | `.control`/`.endc` (block extraction), `.options`/`.option`/`.opt` (extracted, `inp.c:609` → `src/frontend/options.c:262-285`), `.width`/`.four`/`.plot`/`.print`/`.sndprint`/`.sndparam` (moved out of deck to `wl_first`), `.op`/`.meas`/`.tf` (**copied** to `wl_first`, kept in deck), `.save` (after subckt expansion, `inp.c:954-960`), `.csparam` (`inp.c:1027-1055`), `.if`/`.elseif`/`.else`/`.endif` (`inp.c:2130-2215`), `.param` re-ordering (`inp.c:1124-1139`), `.meas` extraction (`inp.c:1142-1165`), `.temp` (`inp.c:1167-1177`) |
| C2. subckt/numparam | `inp_subcktexpand()` `src/frontend/subckt.c:236-425`; `src/frontend/numparam/spicenum.c:207-283, 622-744` | `.subckt`/`.ends`, `.global` (`subckt.c:180-204`), `.param`, `.func`, and `{}` substitution on all other dot lines |
| D. simulator parser | `INP2dot()` `src/spicelib/parser/inp2dot.c:834-975`, called from `INPpas2()` `src/spicelib/parser/inppas2.c:262-273` | `.op .ac .dc .tran .tf .pz .disto .noise .sens [.sens2] [.pss] [.sp] [.hb] .options` and the accept-and-ignore set |
| D2. pass 3 | `INPpas3()` `src/spicelib/parser/inppas3.c:23-169` | `.nodeset`, `.ic` |
| E. post-run | `ft_cktcoms()` `src/frontend/dotcards.c:190-461` | `.width .print .plot .four .sndprint .sndparam` (and prints the `.op` / `.tf` tables) |

**Consequence for a GUI**: a `.print` card never reaches the simulator parser, so the
`obsolete dot command '%s' - ignored` branch at `inp2dot.c:854-860` is unreachable through the
normal file/`source` path (verified: `.print tran v(out)` produces no such error).

### 1.1 `ciprefix()` over-matching

Nearly every stage-A/B/C test is `ciprefix()` (prefix, case-insensitive,
`src/misc/string.c` / `src/include/ngspice/macros.h`), while the stage-D dispatcher uses `cieq()`
(exact, case-insensitive, `src/misc/string.c:259-268`). The mismatch is observable:

| Card written | What happens | Evidence |
|---|---|---|
| `.endc_not` | Treated as `.endc` → `Warning: misplaced .endc card` | empirical; `inp.c:772` |
| `.optx reltol=1e-3` | Extracted as an options line and **sets reltol** | empirical; `options.c:271` uses `ciprefix(".opt", …)` |
| `.paramx q=1` | Silently ignored (matches `ciprefix(".para", token)` at `inp2dot.c:964`, but numparam's `transform()` uses `ciprefix(".param", s)` at `spicenum.c:241` and does not classify it as a param line) | empirical |
| `.tempx 50` / `.temperature 50` | **Fatal**: ` unimplemented dot command '.tempx'` — stage D's `cieq(token,".temp")` (`inp2dot.c:861`) misses, even though `inp.c:1167`'s `ciprefix(".temp", …)` would have matched | empirical |
| `.endl…`, `.ends…`, `.endc…` | Excluded from the `.end` test, which requires `buffer[4]` to be NUL or space (`inpcom.c:2287-2291`) | source |

---

## 2. Tokenisation, numbers, case, expressions

### 2.1 Token separators

`INPgetTok()` (`src/spicelib/parser/inpgtok.c:27-138`) — used for keywords, source names,
`.dc` sweep names:

* leading run of ` `, `\t`, `\r`, `=`, `(`, `)`, `,` is skipped;
* the token ends at any of ` `, `\t`, `\r`, `=`, `(`, `)`, `,`, `*`, `/`, `^`, or at a second
  `+`/`-` sign (a small state machine at `inpgtok.c:83-105` allows one sign and one exponent sign);
* trailing ` `, `\t`, `\r` and — when `gobble` is set — `=` and `,` are then eaten.

`INPgetNetTok()` (`inpgtok.c:149-224`) — used for **node names** on `.noise`, `.tf`, `.sens`, `.pz`,
`.nodeset`, `.ic`, `.pss`. It is deliberately liberal: only ` `, `\t`, `\r`, `=`, `,`, `)` end the
token, so `+VCC`, `IN-`, `a*b` are legal node names.

`INPgetUTok()` (`inpgtok.c:232-…`) — used inside `INPevaluate()`; additionally honours `"`/`'`
quoting.

**Practical effect** (all verified empirically): commas and `=` are interchangeable with spaces on
every analysis card.

```
.tran 1u 100u      ->  109 points
.tran 1u,100u      ->  109 points
.tran=1u,100u      ->  109 points
.ac dec,10,1,1k    ->  31 points   (identical to '.ac dec 10 1 1k')
.dc v1,0,1,0.25    ->  5 points
```

But `(`/`)` are separators too, so `.tran(1u,100u)` fails with
` Error: unknown parameter on .tran - ignored` (the trailing `)` is read as the UIC token).

### 2.2 Numbers and unit suffixes

`INPevaluate()` (`src/spicelib/parser/inpeval.c:13-203`) is the only number parser reached from
analysis cards (via `INPgetValue()`, `src/spicelib/parser/inpgval.c:29-35`). Grammar:

```
[+|-] digits [ '.' digits ] [ (E|e|D|d) [+|-] digits ] [ scale-letter ] <ignored trailing text>
```

Scale letters (`inpeval.c:143-193`), case-insensitive:

| letter | multiplier | note |
|---|---|---|
| `t`, `T` | 1e12 | |
| `g`, `G` | 1e9 | |
| `meg`, `MEG` | 1e6 | tested as `m` followed by `e`/`E` and `g`/`G` (`inpeval.c:178-181`) |
| `k`, `K` | 1e3 | |
| `m`, `M` | 1e-3 | when not `meg`/`mil` |
| `mil`, `MIL` | 25.4e-6 | mantissa multiplied by 25.4, exponent −6 (`inpeval.c:182-186`) |
| `u`, `U` | 1e-6 | |
| `n`, `N` | 1e-9 | |
| `p`, `P` | 1e-12 | |
| `f`, `F` | 1e-15 | |
| `a`, `A` | 1e-18 | |
| anything else | ×1 | `default: break;` at `inpeval.c:191` |

There is **no `x` for 1e6** and no `mil`-like alias beyond the three above. Anything after the
first scale letter is discarded, so `1ms`, `1sec`, `1kohm`, `1megohm`, `1atto`, `1foo` all parse.

Empirically measured through `@c1[capacitance]` and `@r1[resistance]`:

```
C=1      -> 1.000000e+00     C=1meg -> 1.000000e+06     C=1mil -> 2.540000e-05
C=1f     -> 1.000000e-15     C=1a   -> 1.000000e-18     C=1p   -> 1.000000e-12
C=1t     -> 1.000000e+12     C=1g   -> 1.000000e+09     C=1k   -> 1.000000e+03
C=1e-20  -> 1.000000e-20     C=1foo -> 1.000000e-15     C=1atto-> 1.000000e-18
R=1x     -> 1.000000e+00     R=1d3  -> 1.000000e+03     R=1k5  -> 1.000000e+03
R=1kohm  -> 1.000000e+03     R=1megohm -> 1.000000e+06
```

`1k5` (RKM notation) is **not** honoured on dot cards — `INPevaluateRKM_R/_C/_L`
(`inpeval.c:208, 452, 690`) are used only by `inp2r/inp2c/inp2l` for device values, never by
`INP2dot`.

`INPgetValue(…, IF_INTEGER, …)` rounds: `(int) floor(0.5 + tmp)` (`inpgval.c:31`).

Missing/unparsable arguments do **not** error at this level: `INPevaluate` returns 0.0 with
`*error = 1`, and most callers ignore the error flag. The downstream `setParm` range checks
(§3) are what actually complain.

### 2.3 Case

* The reader lowercases every card in place unless the card is on an exemption list
  (`inpcom.c:2211-2226`) — analysis cards are **not** exempt, so under the default mode a deck's
  `.TRAN 1U 1M` reaches the parser as `.tran 1u 1m`.
* Lowercasing is gated on `inp_case_folding()` (`inpcom.c:1108-1111`), i.e. on the **`casemode`**
  control variable: `fold` (default), `preserve`, `distinguish`
  (`set_case_mode()`, `inpcom.c:1231-1285`). **This is a local extension of this fork**, added by
  commit `424ebaf75` — it is not in stock ngspice-46/47. `src/spinit.in:17` carries a commented-out
  `*set casemode=preserve`.
* Independently of `casemode`, the dot-card *dispatch* is case-insensitive: `INP2dot` uses
  `cieq(token, ".ac")` etc. (`inp2dot.c:846-968`), and keyword lookup uses
  `ft_find_analysis_parm()` → `cieq()` (`src/frontend/spiceif.c:1847-1855`). So `.AC DEC 10 1 1K`
  works in every mode.
* `ft_find_analysis()` itself is **case-sensitive** `strcmp` (`spiceif.c:1836-1844`), but every
  caller passes a literal that matches the table (`"AC"`, `"NOISE"`, `"options"`, …).

### 2.4 `{expr}` and `.param`

numparam's `transform()` (`src/frontend/numparam/spicenum.c:239-263`) classifies any dot line that
is not `.param`/`.subckt`/`.control`/`.endc`/`.ends` as category `'.'`, and upgrades it to `'B'`
if `stripbraces()` found braces. Category `'B'` lines get `nupa_substitute()`
(`spicenum.c:713-717`). **Therefore `{}` expressions are substituted on `.tran`, `.ac`, `.dc`,
`.noise`, `.options`, … cards.** Verified:

```
.param tstop=2m
.param npts=20
.param f0=1k
.tran {tstop/200} {tstop}     -> 212 rows
.ac   dec {npts} {f0/1000} {f0*100}  -> 101 points (dec 20, 1 Hz .. 100 kHz)
.dc   v1 0 {2*1} {0.5}        -> 5 points
```

`.param` cards may appear in any order relative to their use and to each other — `inp_reorder_params()`
(`inpcom.c:142-143` decl) sorts them by dependency; empirically a `.tran {ts} {tstop}` above both
`.param` lines works. A duplicate `.param` silently takes the **last** value (verified: `q=1` then
`q=2` gives `v(in) = 2`).

Substituted values are written as a fixed-width numeric string, visible in error messages:

```
Error on line 6 or its substitute:
  .options reltol=    1.000000000000000e-04     nonsense=    1.000000000000000e-04
```

---

## 3. The analysis cards, one by one

Common notation: **IFparm** names below are the strings in the analysis's `IFparm` table; they are
what `INPapName()` looks up (`src/spicelib/parser/inpapnam.c:14-37`) and what the `.control`
`show`/`option` machinery uses. All job structs are zero-filled (`tmalloc` is `calloc`,
`src/misc/alloc.c:52-56`), so any parameter the card does not set is 0.

### 3.1 `.op`

```
.op
```

* Parser: `dot_op()` `inp2dot.c:124-143`. Arguments are **ignored entirely** (`NG_IGNORE(line)`).
* No IFparm table at all: `DCOinfo` declares `0, NULL` (`src/spicelib/analysis/dcosetp.c:32-47`);
  `DCOsetParm()` always returns `E_BADPARM` (`dcosetp.c:17-29`).
* Analysis name `"OP"`, description `"D.C. Operating point analysis"`, `do_ic = 1`,
  `an_func = DCop`.
* Error if the simulator lacks the analysis: `DC operating point analysis unsupported\n`
  (`inp2dot.c:138`).
* Plot: `Plotname: Operating Point`, 1 point, no reference vector → typename `op1`.
* **Side effect**: the card is *also* copied into `ci_commands` (`inp.c:826-836`), which makes
  `ft_savedotargs()` do `com_save2(&all, "OP")` (`dotcards.c:154-156`) and makes `ft_cktcoms()`
  print the node/source table plus `showmod`/`show` (`dotcards.c:222-272`). See §7.2.
* Two `.op` cards produce two `Operating Point` plots (verified).

### 3.2 `.tran`

```
.tran Tstep Tstop [Tstart [Tmax]] [UIC]
```

* Parser: `dot_tran()` `inp2dot.c:410-457`. Strictly positional. `Tstart` and `Tmax` are attempted
  with `INPevaluate(&line,&error,1)` and only applied when `error == 0`, so a non-numeric fifth
  token silently stops the positional chain and falls through to the UIC test.
* IFparms (`src/spicelib/analysis/transetp.c:64-70`): `tstep` `TRAN_TSTEP`, `tstop` `TRAN_TSTOP`,
  `tstart` `TRAN_TSTART`, `tmax` `TRAN_TMAX` (all `IF_SET|IF_REAL`), `uic` `TRAN_UIC`
  (`IF_SET|IF_FLAG`).
* `uic` is matched with `cieq(word,"uic")` (`inp2dot.c:448`), so `UIC`, `Uic`, `uic` all work.
* Range checks in `TRANsetParm()` (`transetp.c:22-55`), literal messages:
  * `TSTOP is invalid, must be greater than zero.` (`transetp.c:26`) — when tstop ≤ 0; job's
    `TRANfinalTime` is reset to 1.0.
  * `TSTEP is invalid, must be greater than zero.` (`transetp.c:34`) — tstep ≤ 0; `TRANstep` → 1.0.
  * `TSTART is invalid, must be less than TSTOP.` (`transetp.c:42`) — tstart ≥ tstop; `TRANinitTime` → 0.
* Unknown trailing token: ` Error: unknown parameter on .tran - ignored` (`inp2dot.c:452`).
  **The word "ignored" is wrong** — the message is attached to the card via `LITERR`, and
  `inp_dodeck()` aborts the whole netlist (`inp.c:1497-1512`). Verified:

```
### CARD: .tran 1u 100u foo
Error on line 5 or its substitute:
  .tran 1u 100u foo
 Error: unknown parameter on .tran - ignored
    Simulation interrupted due to error!
Error: circuit not parsed.
```

* **Tmax default** (`src/spicelib/analysis/traninit.c:29-34`): if `tmax` is 0 (unset), it becomes
  `min(tstep, (tstop-tstart)/50)` — unless the control variable `nostepsizelimit` is set, in which
  case it is `(tstop-tstart)/50`. `CKTdelmin = 1e-11 * CKTmaxStep` (`traninit.c:36`).
* `Tstart` suppresses *output* before that time; the solution is still computed
  (`src/spicelib/analysis/dctran.c:416-417`).
* Plot: `Plotname: Transient Analysis`, reference vector `time`, typename `tran1`, `tran2`, …
* With `uic`, the console prints
  `Operating point simulation skipped by 'uic',\n  now using transient initial conditions.`
  otherwise `Initial Transient Solution` and a node table.

### 3.3 `.ac`

```
.ac {DEC|OCT|LIN} NP FSTART FSTOP
```

* Parser: `dot_ac()` `inp2dot.c:182-245`.
* IFparms (`src/spicelib/analysis/acsetp.c:85-92`): `start` `AC_START` (`IF_SET|IF_ASK|IF_REAL`),
  `stop` `AC_STOP`, `numsteps` `AC_STEPS` (`IF_SET|IF_ASK|IF_INTEGER`), `dec` `AC_DEC`,
  `oct` `AC_OCT`, `lin` `AC_LIN` (all `IF_SET|IF_FLAG`).
* **Step-type token: prefix-checked but exact-matched.** `inp2dot.c:205` guards with
  `ciprefix("dec"|"oct"|"lin", steptype)`, but line 210 then does
  `INPapName(..., steptype, ...)` which requires an exact (case-insensitive) hit in `ACparms`.
  So:
  * `dec`, `DEC`, `Dec`, `oct`, `lin` → OK.
  * `decade`, `octave`, `linear`, `octopus` → pass the guard, then fail the lookup.
  * `d`, `o`, `l`, empty → fail the guard.
  * Literal outputs (verified):
    ```
    ### CARD: .ac decade 5 1 1k
    decade                                    <- INPapName's echo, inpapnam.c:29
    Error on line 5 or its substitute:
      .ac decade 5 1 1k
    no such parameter on this device or parameter is missing
    ```
    ```
    ### CARD: .ac d 5 1 1k
    Error on line 5 or its substitute:
      .ac d 5 1 1k
    Missing DEC, OCT, or LIN.                 <- inp2dot.c:206
    ```
* **Silent defaulting** (`inp2dot.c:214-243`), unique to `.ac`:
  * `numsteps < 1` → 10
  * `fstart < 0`, or the token does not start with a digit or `.digit` → 1.0
  * `fstop < stop` → `1000 * fstart`
  * each of the three sets a flag that prints, on stderr:
    ```
    Warning, ngspice assumes default parameter(s) for ac simulation
        Check your input line '.ac dec 5 1'
    ```
    (the quoted text is the remainder of the card after `.ac`, `inp2dot.c:242`).
* Range check in `ACsetParm()` (`acsetp.c:26, 36`): `Frequency of < 0 is invalid for AC start` /
  `... for AC stop`. Note `fstart == 0` passes the setParm check but is rejected at run time by
  `ACan()`: `ERROR: AC startfreq <= 0` (`src/spicelib/analysis/acan.c:79, 97`) →
  `doAnalyses: parameter value out of range or the wrong type`.
* Plot: `Plotname: AC Analysis`, `Flags: complex`, reference vector `frequency`, typename `ac1`.
  With `.options keepopinfo` an extra real plot `AC Operating Point` precedes it (verified;
  `ckt->CKTkeepOpInfo` set from `OPT_KEEPOPINFO`, `src/spicelib/analysis/cktsopt.c:356`).

### 3.4 `.dc`

```
.dc SRC1 Vstart1 Vstop1 Vinc1 [SRC2 Vstart2 Vstop2 Vinc2]
```

* Parser: `dot_dc()` `inp2dot.c:284-345`. This is the only card whose parser returns 1 for a
  syntax error; `INP2dot` then overwrites `current->error` with the literal `"Bad syntax! "`
  (`inp2dot.c:896`) — note the trailing space and the absence of a newline.
* Triggers for `Bad syntax! `: missing source name, missing any of the three numbers, or
  `Vinc == 0` (`inp2dot.c:305-343`). Verified for `.dc`, `.dc v1`, `.dc v1 0 1`, `.dc v1 0 1 0`.
* IFparms (`src/spicelib/analysis/dctsetp.c:91-102`): `start1/stop1/step1` (`DCT_START1/STOP1/STEP1`,
  `IF_SET|IF_REAL`), `start2/stop2/step2`, `name1`/`name2` (`IF_SET|IF_INSTANCE`),
  `type1`/`type2` (`IF_SET|IF_INTEGER`, not settable from a card). Setting any `*2` parm raises
  `TRCVnestLevel` to 1 (`dctsetp.c:42-70`).
* **What may be swept**, resolved at run time in `DCtrCurv()` (`src/spicelib/analysis/dctrcurv.c:87-160`),
  in this order:
  1. a **resistor** instance name (`dctrcurv.c:89-106`) — sweeps `RESresist`;
  2. a **voltage source** (`:108-124`) — sweeps `VSRCdcValue`;
  3. a **current source** (`:126-142`) — sweeps `ISRCdcValue`;
  4. the literal name `temp` (case-insensitive `cieq`, `:144-151`) — sweeps `CKTtemp`
     (value + `CONSTCtoK`), re-running `inp_evaluate_temper()` and `CKTtemp()` each step.
  Otherwise, fatal:
  ```
  Fatal error: DC Transfer Function: Voltage source, current source, or resistor named "vzzz" is not in the circuit
  doAnalyses: no such device
  ```
  (`dctrcurv.c:153-157`). All four sweep kinds verified empirically.
* **Reference vector name** depends on the swept object (`dctrcurv.c:180-189`):
  `v-sweep` (voltage), `i-sweep` (current), `temp-sweep`, `res-sweep`, `?-sweep`.
  Empirically, the raw-file variable line reads `v(v-sweep)`/`temp-sweep`/`res-sweep`.
* **Nested sweeps are flattened into one plot.** `.dc v1 0 1 0.5 v2 0 2 1` yields a single `dc1`
  plot with 9 points and a saw-tooth `v-sweep` reference; there is no dimension metadata in the
  raw file. Verified:
  ```
  Index   v-sweep         v(out)
  0  0.000000e+00  0.000000e+00
  1  5.000000e-01  3.333333e-01
  2  1.000000e+00  6.666667e-01
  3  0.000000e+00  0.000000e+00     <- outer step 2 begins
  ...
  ```
  Splitting the outer sweep is the GUI's job.
* `(temper)` in a `.dc` card is rewritten to `temp    ` by `inp_repair_dc_ps()`
  (`inpcom.c:10335-10347`).
* Plot: `Plotname: DC transfer characteristic`, typename `dc1`.
* Documented form (manual §11.3.2): `.dc srcnam vstart vstop vincr [src2 start2 stop2 incr2]` —
  the manual does **not** mention resistor or `temp` sweeps; the source does. Trust the source.

### 3.5 `.tf`

```
.tf v(NODE[,NODE2]) INSRC
.tf i(VSRCNAME)     INSRC
```

* Parser: `dot_tf()` `inp2dot.c:348-407`. The first token must be exactly `v` or `i`
  (`cieq`, `inp2dot.c:371, 393`); otherwise
  `Syntax error: voltage or current expected.` (`inp2dot.c:399`).
* IFparms (`src/spicelib/analysis/tfsetp.c:53-59`): `outpos`/`outneg` (`IF_SET|IF_NODE`),
  `outname` (`IF_SET|IF_STRING`), `outsrc` (`IF_SET|IF_INSTANCE`), `insrc` (`IF_SET|IF_INSTANCE`).
* With one node, `outneg` becomes the ground node and `outname` becomes `V(<node>)`; with two,
  `V(<n1>,<n2>)` (`inp2dot.c:385-391`).
* `do_ic = 0` in `TFinfo` (`tfsetp.c:71`) — the only analysis that does not run `CKTic`.
* Output vectors (verified):
  * `.tf v(out) v1` → `v(Transfer_function)`, `v(v1#Input_impedance)`, `v(output_impedance_at_V(out))`
  * `.tf i(v1) i1` → `v(Transfer_function)`, `v(i1#Input_impedance)`, `v(v1#Output_impedance)`
* Plot: `Plotname: Transfer Function`, 1 point, typename `tf1`. `ft_cktcoms()` prints
  `Transfer function information:` followed by `print all` for every `tf*` plot
  (`dotcards.c:274-284`).
* Like `.op`, the card is also copied to `ci_commands` and installs `com_save2(&all,"TF")`
  (`dotcards.c:157-159`).
* A node name that no card defines is reported by the fork-local check
  `Warning: no node named 'zzz'; it is referenced but no card defines it`
  (`INPtermInsertRef`/`INPtermCaseCheck`, see `inp2dot.c:52-56` comment,
  `doc/claude/decisions/0008-undefined-node-diagnostic.md`).

### 3.6 `.pz`

```
.pz NODE_I NODE_G NODE_J NODE_K {VOL|CUR} {POL|ZER|PZ}
```

* Parser: `dot_pz()` `inp2dot.c:247-281`. Four `IF_NODE` values then two keyword flags.
* IFparms (`src/spicelib/analysis/pzsetp.c:78-88`): `nodei` `PZ_NODEI`, `nodeg` `PZ_NODEG`,
  `nodej` `PZ_NODEJ`, `nodek` `PZ_NODEK` (all `IF_SET|IF_ASK|IF_NODE`), and the flags
  `vol` `PZ_V`, `cur` `PZ_I`, `pol` `PZ_POL`, `zer` `PZ_ZER`, `pz` `PZ_PZ`
  (all `IF_SET|IF_ASK|IF_FLAG`).
* **Source/comment disagreement**: the comment at `inp2dot.c:259` says
  `/* .pz nodeI nodeG nodeJ nodeK {V I} {POL ZER PZ} */`, i.e. `V`/`I`. The table has
  `vol`/`cur`. The manual (§11.3.6) documents `.pz node1 node2 node3 node4 cur pol` etc.
  **Behaviour follows the table**; the comment is wrong. Verified:
  ```
  ### CARD: .pz in 0 out 0 v pz
  v
  Error on line 5 or its substitute:
    .pz in 0 out 0 v pz
  no such parameter on this device or parameter is missing
  ```
  `.pz in 0 out 0 vol pz` and `.pz in 0 out 0 cur pol` both run.
* Omitting either keyword yields the same `no such parameter …` error (empty token).
* An unknown node in `nodei`… is **created** by `INPtermInsertRef()` (`inpgval.c:88-94`) and only
  warned about at the end of the parse; the run then usually fails with e.g.
  `doAnalyses: The input signal is shorted on the way to the output`.
* Plot: `Plotname: Pole-Zero Analysis`, typename `pz1`; `co_major = FALSE` for the `pz` command
  (`src/frontend/commands.c:347`).

### 3.7 `.disto`

```
.disto {DEC|OCT|LIN} NP FSTART FSTOP [F2OVERF1]
```

* Parser: `dot_disto()` `inp2dot.c:146-179`.
* IFparms (`src/spicelib/analysis/dsetparm.c:72-80`): `start` `D_START`, `stop` `D_STOP`
  (`IF_SET|IF_REAL`), `numsteps` `D_STEPS` (`IF_SET|IF_INTEGER`), `dec`/`oct`/`lin`
  (`IF_SET|IF_FLAG`), `f2overf1` `D_F2OVRF1` (`IF_SET|IF_REAL`).
* No `ciprefix` guard on the step type here — a wrong token goes straight to the
  `no such parameter on this device or parameter is missing` path. `.disto` with no arguments
  produces exactly that.
* Range check: `Frequency of 0 is invalid` (`dsetparm.c:26, 36`).
* Supplying `F2OVERF1` switches to the two-tone IM analysis and requires at least one source with
  `DISTOF2`, else: `doAnalyses: No source with f2 distortion input` (verified).
* Without `F2OVERF1`: two plots are produced (harmonic distortion). Plot name
  substring `disto` → typename `disto1`, `disto2` (`src/frontend/typesdef.c:79`).

### 3.8 `.noise`

```
.noise V(OUTPUT[,REF]) SRC {DEC|OCT|LIN} NP FSTART FSTOP [PTSPERSUM]
```

* Parser: `dot_noise()` `inp2dot.c:18-121`. The first token must be exactly `V` or `v` with
  nothing after it (`inp2dot.c:50`); anything else (including `i(v1)`) →
  ```
  bad syntax [.noise v(OUT) SRC {DEC OCT LIN} NP FSTART FSTOP <PTSPRSUM>]
  ```
  (`inp2dot.c:112-118`, the same text twice for the null-token case).
* IFparms (`src/spicelib/analysis/nsetparm.c:82-93`): `output` `N_OUTPUT`, `outputref` `N_OUTREF`,
  `input` `N_INPUT` (all `IF_SET|IF_STRING`), `dec`/`oct`/`lin` (`IF_SET|IF_FLAG`),
  `numsteps` `N_STEPS`, `ptspersum` `N_PTSPERSUM` (`IF_SET|IF_INTEGER`),
  `start` `N_START`, `stop` `N_STOP` (`IF_SET|IF_REAL`).
  (Note: the parser passes a `CKTnode*` for `output`/`outputref` even though the table says
  `IF_STRING` — `inp2dot.c:59-69`.)
* `PTSPERSUM` is optional; the presence test is the odd loop at `inp2dot.c:98-99`. When absent it
  is explicitly set to 0 (`inp2dot.c:106-107`).
* Range check: `Frequency of 0 is invalid` (`nsetparm.c:53, 63`) for `start`/`stop` ≤ 0.
* Missing input source at run time: `Warning: Noise input source vzz not in circuit` then
  `doAnalyses: not found`.
* **Two plots per run** (`src/spicelib/analysis/noisean.c:274-282` and `:532-536`):
  * `Noise Spectral Density Curves` (or `... - (V^2 or A^2)/Hz` when the control variable
    `sqrnoise` is set, `noisean.c:242, 275-278`), reference vector `frequency` →
    typename `noise1`;
  * `Integrated Noise` (or `Integrated Noise - V^2 or A^2`), 1 point → typename `noise2`.
  With `.options keepopinfo` a third plot `NOISE Operating Point` precedes them
  (`noisean.c:221-235`).
* Vector naming, verified with `.noise v(out) v1 dec 10 1 100k 10` on an R divider:
  ```
  Noise Spectral Density Curves:
    frequency, onoise_r2_thermal, onoise_r2_1overf, onoise_r2,
    onoise_r1_thermal, onoise_r1_1overf, onoise_r1,
    onoise_spectrum, inoise_spectrum
  Integrated Noise:
    v(onoise_total_r2_thermal), v(inoise_total_r2_thermal), … ,
    v(onoise_total), v(inoise_total)
  ```
  With `PTSPERSUM` absent, only `onoise_spectrum`/`inoise_spectrum` and the two totals appear
  (3 and 2 columns in the same test circuit).

### 3.9 `.sens`

```
.sens OUTVAR [<filter> ...] [DC]
.sens OUTVAR [<filter> ...] AC {DEC|OCT|LIN} NP FSTART FSTOP
```
where `OUTVAR` is `v(NODE[,NODE])` or `i(VSRCNAME)`.

* Parser: `dot_sens()` `inp2dot.c:460-585`.
  * `v` requires a `(` immediately: `Syntax error: '(' expected after 'v'` (`inp2dot.c:497`).
  * Neither `v` nor `i`: `Syntax error: voltage or current expected.` (`inp2dot.c:525`).
* IFparms (`src/spicelib/analysis/senssetp.c:87-104`): `outpos` `SENS_POS`, `outneg` `SENS_NEG`
  (`IF_SET|IF_ASK|IF_NODE`), `outsrc` `SENS_SRC` (`IF_SET|IF_ASK|IF_INSTANCE`),
  `outname` `SENS_NAME` (`IF_SET|IF_ASK|IF_STRING`), `start`/`stop` (`IF_SET|IF_ASK|IF_REAL`),
  `numsteps` (`IF_SET|IF_ASK|IF_INTEGER`), `dec`/`oct`/`lin`/`dc` (`IF_SET|IF_FLAG`).
* **Gap**: `SENS_DEFTOL` and `SENS_DEFPERTURB` are handled in `SENSsetParam()`
  (`senssetp.c:72-78`) and `SENSask()` (`sensaskq.c:42-46`) but have **no entry in `SENSparms[]`**,
  so `deftol`/`defperturb` are unreachable from a card or a command.
* **Filters** are scanned by hand (`inp2dot.c:529-565`) because `INPgetTok()` breaks on `*`. The
  scan first skips the remainder of the current token, then collects whitespace-delimited words
  until it meets `ac` or `dc` (case-insensitive) or end of line, storing them in the **file-scope
  global** `Sens_filter` (`src/spicelib/analysis/cktsens.c:33`). Matching is a hand-written glob
  (`cktsens.c:37-56`): `*` = any run, `?` = one char, everything else compared **byte-exactly**
  (case-sensitive).
* Trailing junk that is not `ac`/`dc` is silently treated as a filter, so `.sens v(out) foo`
  produces an empty result rather than an error (verified — no columns, no message). The
  `Syntax error: 'ac' or 'dc' expected.` message (`inp2dot.c:580`) fires only when the loop
  terminated on a non-empty token that is neither `ac` nor `dc`, which in practice requires the
  filter loop to have been broken some other way.
* Output vectors are one per (device, parameter): model parameters as `<dev>:<parm>` and instance
  parameters as `<dev>_<parm>`, e.g. `v(r1:rsh)`, `v(r1_w)`, `v(r1)` (verified — a two-resistor
  circuit gives 53 vectors; `.sens v(out) r*` narrows it).
* DC form: 1 point. AC form: `numsteps` points with a `frequency` reference.
* Plot: `Plotname: Sensitivity Analysis` → typename `sens1`.
* Documented form (manual §11.3.7) matches: `.SENS OUTVAR [<filter ...>] [DC]` /
  `... AC DEC ND FSTART FSTOP` / `... AC OCT ...` / `... AC LIN ...`.

### 3.10 `.sp` — S-parameter analysis (build-gated: `RFSPICE`, **ON** in this tree)

```
.sp {DEC|OCT|LIN} NP FSTART FSTOP [DONOISE]
```

* Parser: `dot_sp()` `inp2dot.c:716-750`, inside `#ifdef RFSPICE` (`inp2dot.c:912-917` for the
  dispatch).
* Build gate: `--enable-sp` is the default (`configure.ac:1220-1227` defines `RFSPICE` unless
  `--disable-sp`); confirmed `#define RFSPICE 1` in
  `build-ver_50/src/include/ngspice/config.h`.
* IFparms (`src/spicelib/analysis/spsetp.c:91-99`): `start` `SP_START`, `stop` `SP_STOP`
  (`IF_SET|IF_ASK|IF_REAL`), `numsteps` `SP_STEPS` (`IF_SET|IF_ASK|IF_INTEGER`),
  `dec`/`oct`/`lin` (`IF_SET|IF_FLAG`), `donoise` `SP_DONOISE`
  (`IF_SET|IF_FLAG|IF_INTEGER`).
* `DONOISE` is read unconditionally as an integer (`inp2dot.c:747`); when the token is absent
  `INPevaluate` yields 0, so noise output is off. Verified: with `1` the plot gains
  `NF`, `SOpt`, `NFmin`, `Rn`; with `0` or nothing it does not.
* Range check: `Frequency of < 0 is invalid for AC start` / `... stop` (`spsetp.c:28, 38`).
* Requires ≥2 port sources — `Vxxx n+ n- dc 0 ac 1 portnum <n> z0 <n>`
  (`examples/sp/sp1.cir`). Manual: "At least two ports are required for the S-parameter
  simulation with the command .sp (11.3.8)".
* Plot: `Plotname: SP Analysis`, `Flags: complex`, reference `frequency` → typename `sp1`.
  Vectors: `S_i_j`, `Y_i_j`, `Z_i_j`, `i(Cy_i_j)`, plus `NF`/`SOpt`/`NFmin`/`Rn` when noise is on
  (verified on `examples/sp/sp1.cir`).

### 3.11 `.pss` — periodic steady state (build-gated: `WITH_PSS`, **OFF** in this tree)

```
.pss Fguess StabTime OscNode Points Harmonics SC_iter Steady_coeff [UIC]
```

* Parser: `dot_pss()` `inp2dot.c:655-711`, inside `#ifdef WITH_PSS`.
* Build gate: `--enable-pss` (`configure.ac:1082-1085`). Confirmed **not** defined here
  (`/* #undef WITH_PSS */` in `build-ver_50/src/include/ngspice/config.h`), so in this build:
  ```
  ### CARD: .pss 150 200e-3 2 1024 1 150 5e-3 uic
  Error on line 5 or its substitute:
    .pss 150 200e-3 2 1024 1 150 5e-3 uic
   unimplemented dot command '.pss'
  ```
  and `pss` is not a command: `pss: no such command available in ngspice`.
* IFparms when built (`src/spicelib/analysis/psssetp.c:57-66`): `fguess` `GUESSED_FREQ`
  (`IF_SET|IF_REAL`), `oscnode` `OSC_NODE` (`IF_SET|IF_STRING`), `stabtime` `STAB_TIME`
  (`IF_SET|IF_REAL`), `points` `PSS_POINTS`, `harmonics` `PSS_HARMS`, `uic` `PSS_UIC`,
  `sc_iter` `SC_ITER`, `steady_coeff` `STEADY_COEFF` (all `IF_SET|IF_INTEGER` —
  note `steady_coeff` is declared INTEGER in the table but assigned from `value->rValue`
  at `psssetp.c:47`, and the parser reads it as `IF_REAL` at `inp2dot.c:698`; an inconsistency
  that only matters if the flag is ever turned on).
* Unknown trailing token here prints directly to stderr and is genuinely ignored:
  `Error: unknown parameter %s on .pss - ignored\n` (`inp2dot.c:707`) — unlike `.tran`, this one
  is *not* a `LITERR`, so the netlist still loads.
* Plot name `Periodic Steady State Analysis` → typename prefix `pss` (`typesdef.c:89`).

### 3.12 `.hb` — harmonic balance (build-gated: `WITH_HB`, **never definable**)

* Parser `dot_hb()` `inp2dot.c:754-811`, dispatch `inp2dot.c:918-924`, table entry
  `analysis.c:22-24, 55-57`. `WITH_HB` is referenced in seven files but **is never `AC_DEFINE`d
  and has no `configure` switch** (`grep -rn WITH_HB` over `configure.ac` finds nothing). Dead
  code in every autotools build. Empirically `.hb 1e9 5` →
  ` unimplemented dot command '.hb'`.

### 3.13 `.sens2` — SPICE-2 sensitivity (build-gated: `WANT_SENSE2`, **never definable**)

```
.sens2 {AC} {DC} {TRAN} [dev=nnn parm=nnn]*
```

* Parser `dot_sens2()` `inp2dot.c:589-650`, dispatch `inp2dot.c:940-945`.
* `configure.ac:232-234` declares `--enable-sense2` and a comment says it "define[s]
  WANT_SENSE2 for the code", and `configure.ac:1236` creates the automake conditional
  `SENSE2_WANTED` — but **no `AC_DEFINE([WANT_SENSE2], …)` exists anywhere in the tree**. The
  macro can therefore never be defined by `configure`; `.sens2` is dead code.
* This is the only analysis that would be parsed as `key=value` pairs against
  `ft_find_analysis_parm()` (`inp2dot.c:610-647`), with the literal error
  ` Error: unknown parameter on .sens-ignored \n` (`inp2dot.c:621`).
* `CKTdoJob()` treats SENS2 specially, running it *before* setup and skipping it in the main loop
  (`cktdojob.c:37-48, 140-154, 179-182`).

### 3.14 `.four` / `.fourier`

```
.four FREQ OV1 [OV2 OV3 ...]
```

* Not an analysis job. `INP2dot` rejects it outright:
  `Use fourier command to obtain fourier analysis\n` (`inp2dot.c:879-884`) — but this branch is
  unreachable because `inp_spsource()` has already pulled `.four*` cards out of the deck into
  `wl_first` (`inp.c:819-833`, `ciprefix(".four", s)`).
* Pre-run: `ft_savedotargs()` skips the card name and the frequency, then
  `com_save2(w, "TRAN")` — "A hack" (`dotcards.c:140-148`).
* Post-run: `ft_cktcoms()` sets `plot_cur = setcplot("tran")` and calls `fourier()`
  (`dotcards.c:407-421`). Errors: `Warning: no nodes given: <line>` (`dotcards.c:144`) when no
  vectors follow; `No transient data available for fourier analysis` (`dotcards.c:419-420`).
* With `-r`: `.fourier line ignored since rawfile was produced.` (`dotcards.c:409-410`).
* Output (verified) is a table with `No. Harmonics`, `THD`, `Gridsize`, `Interpolation Degree`,
  `No. Periods`, then per-harmonic magnitude/phase/normalised values.
* Control-block equivalent: `fourier fund_freq vector ...` (`commands.c:387-390`) — same maths,
  but it uses the **current plot** rather than forcing the `tran` plot.

### 3.15 `.meas` / `.measure`

```
.meas(ure) {DC|AC|TRAN|SP} RESULT <function> <args...>
```

* Removed from the deck and chained on `ft_curckt->ci_meas` (`inp.c:1142-1165`); also copied into
  `ci_commands` (`inp.c:827-836`). Executed after a run by `do_measure()`
  (`src/frontend/measure.c:265-…`), called from `dosim()` (`src/frontend/runcoms.c:388-391`).
* **Accepted analysis tokens** (`chkAnalysisType()`, `src/frontend/measure.c:146-154`):
  `tran`, `ac`, `dc`, `sp` (case-insensitive). Anything else:
  ```
  Error: unrecognized analysis type 'foo' for the following .meas statement on line 15:
         .meas foo x max v(out)
  ```
  (`measure.c:307-308`; printed twice in practice, once per pass).
* Incomplete card: `\nWarning: Incomplete measurement statement in line\n    %s\nignored!\n`
  (`measure.c:290, 294, 299`).
* **Function keywords** (`measure_function_type()`, `src/frontend/com_measure2.c:208-257`),
  all `strcasecmp`, i.e. exact-but-case-insensitive:
  `DELAY`, `TRIG`, `TARG`, `FIND`, `WHEN`, `AVG`, `MIN`, `MAX`, `MIN_AT`, `MAX_AT`, `RMS`, `PP`,
  `INTEG`, `DERIV`, `ERR`, `ERR1`, `ERR2`, `ERR3`. Plus `param`/`expr`, matched by
  `cieqn(meastype,"param",5)` / `cieqn(meastype,"expr",4)` (a 5/4-character prefix test) and
  deferred to a second pass (`measure.c:343-348, 410-500`).
* **Documentation disagreement**: the manual (§11.4.8, §11.4.x) documents `INTEG<RAL>` and
  `DERIV<ATIVE>`, and so does the in-tree comment at `com_measure2.c:298-309`. The code accepts
  only `INTEG` and `DERIV`. Verified:
  ```
  .meas tran vint  INTEG    v(out) from=0 to=1m   ->  vint = 9.98505e-04
  .meas tran vint2 INTEGRAL v(out) from=0 to=1m   ->  measure 'vint2'  failed
                                                      Error: measure  vint2  :
                                                          no such function as 'integral'
                                                      .meas tran vint2 integral v(out) from=0 to=1m failed!
  ```
  **Trust the source.**
* **Standard sub-parameters** (`measure_parse_stdParams()`, `com_measure2.c:1290-1389`), all
  `NAME=VALUE` with `strcasecmp` on the name: `RISE`, `FALL`, `CROSS`, `VAL`, `TD`, `FROM`, `TO`,
  `AT`. The bare word `LAST` is allowed, and `RISE=LAST` / `FALL=LAST` / `CROSS=LAST`.
  Errors: `bad syntax. equal sign missing ?\n`, `bad syntax, cannot evaluate right hand side of %s=%s\n`,
  `no such parameter as '%s'\n`, `no such vector as '%s'\n`, `bad syntax of %s\n`.
* Measurement is restricted to `tran`, `ac`, `dc`, `sp` **plots** at run time:
  `Error: measure limited to tran, dc, sp, or ac analysis` (`com_measure2.c:1661-1667`).
* Pre-run, `measure_extract_variables()` (`com_measure2.c:265-…`) parses the card to install
  `save` entries; it recognises only `DC`, `AC`, `TRAN` for the analysis token and silently
  substitutes `TRAN` for anything else (`com_measure2.c:329-336`) — note this differs from
  `chkAnalysisType()`, which also accepts `sp`.
* Unknown vector: `Warning: can't parse 'nosuch': ignored` (from `copynode`/`gettoks`), then at
  evaluation `Error: measure  bad  avg(TRIG) : no such vector as 'v(nosuch)'` and
  ` .meas tran bad avg v(nosuch) failed!`.
* `.options autostop` is disabled with a warning if any `.meas` uses ` max `, ` min `, ` avg `,
  ` rms ` or ` integ ` (`inp.c:1143-1153`):
  `Warning: .OPTION AUTOSTOP will not be effective because one of 'max|min|avg|rms|integ' is used in .meas`.
* Result values are also injected as parameters via `nupa_add_param()` (`measure.c:379, 495`), so
  a later `.meas … param='vmax*2'` can reference an earlier result (verified: `p = 2.00000e+00`).
* Control-block equivalent: `meas <same args>` (`commands.c:395-398`, `com_meas`), operating on
  the current plot.

### 3.16 `.save`

```
.save VECTOR [VECTOR ...]
```

* Handled entirely in the front end. After subcircuit expansion, `.save` lines are copied into
  `wl_first` and commented out (`inp.c:954-960`). `ft_dotsaves()` splits every card after the
  first token and calls `com_save(wl)` (`dotcards.c:57-76`).
* `com_save()` → `settrace(wl, VF_ACCUM, NULL)` (`src/frontend/breakp2.c:34-37`). Because `name`
  is NULL, **`.save` never scopes to an analysis** — `.save tran v(out)` treats `tran` as a
  (nonexistent) vector name and saves only `v(out)` (verified: 2 columns).
* Special names recognised in `beginPlot()` (`src/frontend/outitf.c:245-285`): `all`, `allv`
  (equivalent), `alli`, `nosub`, `nointernals`, and (shared build only) `none`.
* Accepted vector syntaxes: plain node, `v(node)`, `i(vsrc)` → `vsrc#branch`, `@dev[param]`
  (`copynode()`, `breakp2.c:160-…`). Verified: `.save v(out) i(v1) @c1[capacitance]` yields
  columns `time, v(out), i(v1), @c1[capacitance]`.
* **An unresolved `.save` name is silent** — `report_save_case_miss()` (`outitf.c:1614-1650`)
  fires only under `casemode=distinguish` and only when a case twin exists. Verified:
  `.save v(out) v(zzz)` produces 2 columns and no message.
* **If *every* save is unresolved the analysis is aborted**:
  ```
  Error: no data saved for Transient analysis; analysis not run
  doAnalyses: not found
  run simulation(s) aborted
  ```
  (`outitf.c:479-486`).
* `ft_dotsaves()` is called twice — once from the `comfile` branch (`inp.c:733`) and once after
  the deck is loaded (`inp.c:1257`) — deliberately, so `.save` is honoured even alongside
  `.control`.
* Control-block equivalent: `save <same args>` (`commands.c:439-442`). `.probe` (§6.5) forces a
  `.save all` if neither `.save` nor a `.control` `save ` is present (`inpc_probe.c:69-96`).

### 3.17 `.probe`

```
.probe                      (== .probe alli)
.probe alli
.probe I(DEV) | I(DEV,n)
.probe Vd(DEV) | Vd(X1:2:3) | Vd(X1:2,X2:3)
.probe p(DEV)
```

* Fully implemented as a **netlist rewrite**: `inp_probe()` (`src/frontend/inpc_probe.c:45-…`,
  called from `inpcom.c:1490`) inserts 0 V `VSRC`s in series with the named terminals and `E`
  sources for differential probes, then sets the control variable `probe_is_given`
  (`inpc_probe.c:99`). `modprobenames()` renames the internal `vcurr_` nodes afterwards
  (`inp.c:1432-1435`).
* The `.probe` branch in `INP2dot` (`inp2dot.c:946-948`) is a no-op leftover — the card has
  already been commented out.
* Documented syntax list is in the source comment at `inpc_probe.c:29-43`; power probing is
  manual §11.6.5.3 (`.probe p(XU1)`).
* Diagnostics: `Note: Empty .probe command, treated as .probe alli`
  (`inpc_probe.c:109`), `Warning: Strange parameter in line %s, ingnored` (`:123, :129`, sic).
* Manual §11.6: ".save and the equivalent .probe are acknowledged in all operating modes",
  unlike `.print`/`.plot`/`.four`.

### 3.18 `.print`, `.plot`, `.width`

```
.print PRTYPE OV1 [OV2 ... OV8]
.plot  PLTYPE OV1 [(plo1,phi1)] [OV2 ...]
.width out=NNN
```

* All three are removed from the deck at `inp.c:819-833` and executed after the run by
  `ft_cktcoms()` (`dotcards.c:299-369`).
* `PRTYPE`/`PLTYPE` is matched with `ciprefix(plottype, pl->pl_typename)` against **every** plot
  (`dotcards.c:331-337, 359-365`), so `.print tran …` prints from `tran1`, `tran2`, … in turn.
  Failure: `Error: .print: no %s analysis found.` / `Error: .plot: no %s analysis found.`
  (`dotcards.c:339, 367`). Verified: `.print ac v(out)` in a tran-only deck →
  `Error: .print: no ac analysis found.`
* `.plot` additionally strips the option words `linear`, `xlog`, `ylog`, `loglog` before saving
  (`dotcards.c:84-89, 121-135`) and rewrites `vm(x)`→`mag(v(x))`, `vp(x)`→`ph(v(x))`,
  `v(x,0)`→`v(x)`, `v(0,x)`→`-v(x)`, trailing `(a,b)`→`xlimit a b` (`dotcards.c:464-470`).
* `.width` looks for the first token beginning with `out` and does `cp_vset("width", …)`
  (`dotcards.c:299-313`); malformed → `Error: bad line %s`.
* Under `-r` all three are skipped with
  `.print line ignored since rawfile was produced.` / `.plot line ignored …` /
  `.fourier line ignored …` (`dotcards.c:316-317, 344-345, 409-410`). Verified.
* Manual §11.6: ".print (11.6.2), .plot (11.6.3) and .four (11.6.4) are valid only if ngspice is
  started in batch mode".
* Control-block equivalents: `print`, `plot`/`asciiplot`, `set width=NNN`.

### 3.19 `.ic` and `.nodeset`

```
.ic      v(NODE)=VAL [v(NODE)=VAL ...]
.nodeset v(NODE)=VAL [v(NODE)=VAL ...]
.nodeset all=VAL
```

* Handled in pass 3, `INPpas3()` (`src/spicelib/parser/inppas3.c:23-169`), which runs after every
  node has been created. `INP2dot` deliberately does nothing (`inp2dot.c:871-872, 885-886`).
* Parameter ids are looked up by `strcmp(prm->keyword,"nodeset")` / `"ic"` in
  `ft_sim->nodeParms` (`inppas3.c:55-60, 116-121`); failure → `nodeset unknown to simulator. \n`
  / `ic unknown to simulator. \n`.
* Each entry must be exactly `V`/`v` followed by `(name)` (`inppas3.c:89, 138`). Otherwise:
  ` Error: .nodeset syntax error.\n` (`inppas3.c:109`) / ` Error: .ic syntax error.\n`
  (`inppas3.c:160`) — both fatal to the netlist. Verified for `.ic out=0.5` and
  `.nodeset out 0.5`.
* Unknown node is a **warning** and the entry is skipped:
  ```
  Warning : IC on non-existent node - zzz, ignored
     Please check line .ic v(zzz)=0.5
  ```
  (`inppas3.c:144-147`; the `.nodeset` twin at `:95-98` says `Nodeset on non-existent node`).
* **`all=VAL` is `.nodeset`-only** (`inppas3.c:79-87`); `.ic all=0.1` is a syntax error (verified).
  The manual documents `.nodeset all = val` and does not document `.ic all`.
* `.options copynodesets` (`OPT_COPYNODESETS`, `cktsopt.c:358`) propagates nodesets to device
  internal nodes.
* Control-block equivalent: none directly; `ic` is not a command. The transient `uic` flag on
  `.tran` is what consumes `.ic`.

### 3.20 `.temp`

```
.temp VALUE
.temp=VALUE
```

* Handled at `inp.c:1167-1177`, **after** the circuit has been built: the text after `.temp`
  (an optional `=` is skipped) is stored, the card is commented out, and later
  `cp_vset("temp", CP_REAL, …)` sets the variable and `CKTtemp` (`inp.c:1184-1196`).
* Only a single number is accepted; a multi-value list produces
  ```
  Warning: Could not set temperature to 0 25 50
     Set to default 27 C instead.
  ```
  (`inp.c:1191`). Verified. `INP2dot` ignores `.temp` (`inp2dot.c:861-867`; the old
  ` Warning: .TEMP card obsolete - use .options TEMP and TNOM` message is commented out at
  `inp2dot.c:864-866`).
* **`.temp` always wins over `.options temp=`, regardless of card order** (verified all four
  combinations: `.options temp=100` + `.temp 50` → `TEMP = 50.000000`). Because the `.temp`
  scan runs after `inp_dodeck()` has applied the options.
* Manual §2.14: "This card overrides the circuit temperature given in an .option line".
* Note the trailing-prefix hazard: `.temperature 50` is **fatal** (§1.1).
* Control-block equivalents: `set temp=50`, or `.options temp=50`.

### 3.21 `.options` / `.option` / `.opt`

```
.options OPT1 OPT2=VAL ...
```

Two entirely different code paths, chosen by whether the line contains `{`:

**(a) No brace** (`inp_getopts()`, `src/frontend/options.c:262-285`, called from `inp.c:609`):
the card is pulled out of the deck, case-fixed, and reversed onto an `options` list. In
`inp_dodeck()` the first token is skipped and the rest is fed to `cp_lexer` + `cp_setparse`
(`inp.c:1381-1397`), producing `struct variable`s on `ct->ci_vars`; each is then handed to
`if_option()` (`inp.c:1605-1619`, `src/frontend/spiceif.c:463-582`).
* Recognised simulator options are those in `OPTtbl[]` (`src/spicelib/analysis/cktsopt.c:264-385`)
  with `IF_SET`.
* Nine names are intercepted before the table and set front-end flags
  (`spiceif.c:472-499`): `acct`, `noacct`, `noinit`, `norefvalue`, `list`, `node`, `opts`,
  `nopage`, `nomod`.
* Five names warn `Warning: option %s is currently unsupported.` — `itl3`, `itl5`, `lvltim`,
  `maxord`, `method` (`spiceif.c:446-453, 514`). Verified for `itl3`. (Note `method` and `maxord`
  *are* in `OPTtbl[]` with `IF_SET`, so the unsupported list is only reached for the ones that
  are not, i.e. `itl3`, `itl5`, `lvltim`.)
* Three warn `Warning: option %s is obsolete.` — `limpts`, `limtim`, `lvlcod`
  (`spiceif.c:455-460, 519`).
* **Anything else is silently accepted and becomes a control-language variable.** Verified:
  ```
  .options nonsense=5 myflag       ->  $nonsense = 5   $myflag = TRUE
  ```
  This is how `.options savecurrents`, `.options seed=…`, `.options warn=…`,
  `.options maxwarns=…`, `.options noopiter`, `.options klu` etc. reach their consumers.

**(b) With a brace**: the card stays in the deck, is numparam-substituted, reaches
`INP2dot` → `dot_options()` (`inp2dot.c:817-831`) → `INPdoOpts()`
(`src/spicelib/parser/inpdoopt.c:20-79`). Here an unknown name is an **error**:
```
Error: unknown option nonsense - ignored
```
(`inpdoopt.c:75`) and the netlist fails to load. Other messages from this path:
` Warning: %s not yet implemented - ignored \n` (`inpdoopt.c:55`),
`Warning:  can't set option %s\n` (`inpdoopt.c:65`),
`error:  analysis options table not found\n` (`inpdoopt.c:37-38`). Bare numeric tokens are
excused (`inpdoopt.c:71-74`). Verified:
```
.param rt=1e-4
.options reltol={rt} nonsense={rt}
->  Error: unknown option nonsense - ignored
    Error on line 6 or its substitute:
      .options reltol=    1.000000000000000e-04     nonsense=    1.000000000000000e-04
    Error: circuit not parsed.
```

**Options that matter to analyses** (from `OPTtbl[]`, `cktsopt.c:264-385`; XSPICE block is
`#ifdef XSPICE`, **ON** here; KLU block is `#ifdef KLU`, **ON** here):

| name | id | type | meaning | default (source) |
|---|---|---|---|---|
| `temp` | `OPT_TEMP` | real | operating temperature (°C) | 27 (`TSKtemp = 300.15` K, `cktntask.c:125`) |
| `tnom` | `OPT_TNOM` | real | nominal/model temperature | 27 (`cktntask.c:126`) |
| `gmin` | `OPT_GMIN` | real | minimum conductance | 1e-12 (`cktntask.c:93`) |
| `gshunt` | `OPT_GSHUNT` | real | node-to-ground conductance | 0 (`:94`) |
| `cshunt` | `OPT_CSHUNT` | real | node-to-ground capacitance | −1 (`:95`); also read as `cshunt_value` by `INPpas4()` (`inppas4.c:41`) |
| `abstol` | `OPT_ABSTOL` | real | current tolerance | 1e-12 (`:96`) |
| `reltol` | `OPT_RELTOL` | real | relative tolerance | 1e-3 (`:97`) |
| `chgtol` | `OPT_CHGTOL` | real | charge tolerance | 1e-14 (`:98`) |
| `vntol` | `OPT_VNTOL` | real | voltage tolerance | 1e-6 (`:99`) |
| `trtol` | `OPT_TRTOL` | real | truncation-error factor | 7.0 (`:104`); forced to 1 when XSPICE `A` devices exist unless `xtrtol` is set (`cktdojob.c:81-91`) |
| `ltereltol`/`lteabstol`/`ltetrtol`/`newtrunc` | `OPT_LTE*`/`OPT_NEWTRUNC` | real/flag | voltage-based truncation | 1e-3 / 1e-6 / 500 / 0 (`:100-103`) |
| `pivtol` | `OPT_PIVTOL` | real | | 1e-13 (`:123`) |
| `pivrel` | `OPT_PIVREL` | real | | 1e-3 (`:124`) |
| `itl1` | `OPT_ITL1` | int | DC iteration limit | 100 (`TSKdcMaxIter`, `:107`) |
| `itl2` | `OPT_ITL2` | int | DC transfer-curve limit | 50 (`TSKdcTrcvMaxIter`, `:108`) |
| `itl4` | `OPT_ITL4` | int | transient iteration limit | 10 (`TSKtranMaxIter`, `:106`) |
| `itl6`/`srcsteps` | `OPT_SRCSTEPS` | int | source-stepping steps | 1 (`:120`) |
| `gminsteps` | `OPT_GMINSTEPS` | int | | 1 (`:121`) |
| `gminfactor` | `OPT_GMINFACT` | real | | 10 (`:122`) |
| `noopiter` | `OPT_NOOPITER` | flag | skip straight to gmin stepping | 0 (`:132`) |
| `method` | `OPT_METHOD` | string | `trap` / `gear` | TRAPEZOIDAL (`:109`) |
| `maxord` | `OPT_MAXORD` | int | integration order | 2 (`:110`) |
| `xmu` | `OPT_XMU` | real | trapezoidal coefficient | 0.5 (`:119`) |
| `bypass` | `OPT_BYPASS` | int | | 0 (`:105`) |
| `minbreak` | `OPT_MINBREAK` | real | | derived: `CKTmaxStep*5e-5` (`dctran.c:168, 340`) |
| `keepopinfo` | `OPT_KEEPOPINFO` | flag | emit an extra OP plot for AC/noise | 0 (`:135`) |
| `copynodesets` | `OPT_COPYNODESETS` | flag | | 0 (`:136`) |
| `noopac` | `OPT_NOOPAC` | flag | skip the OP for AC when linear | ANDed with `CKTisLinear` (`cktdojob.c:109`) |
| `nodedamping`/`absdv`/`reldv` | | flag/real/real | iteration damping | 0 / 0.5 / 2.0 (`:137-139`) |
| `epsmin` | `OPT_EPSMIN` | real | | 1e-28 (`:140`) |
| `defl`/`defw`/`defad`/`defas`/`defm` | | real | MOS defaults | 1e-4 / 1e-4 / 0 / 0 / 1 (`:127-131`) |
| `klu` / `sparse` / `klu_memgrow_factor` | `OPT_KLU`… | flag/real | linear solver | `CKTkluOFF`, 1.2 (`:143-144`) — verified: `.options klu` prints `Using KLU as Direct Linear Solver` |
| `trytocompact`, `badmos3`, `oldlimit`, `indverbosity` | | | | 0/0/0/2 (`:133-134, :112`) |
| XSPICE only: `maxopalter`, `maxevtiter`, `noopalter`, `ramptime`, `convlimit`, `convstep`, `convabsstep`, `autopartial`, `rshunt` | | | event/code-model controls | `cktsopt.c:267-275` |
| ask-only (not settable): `totiter`, `traniter`, `equations`, `time`, `loadtime`, `trantime`, `actime`, … | | | statistics | `cktsopt.c:324-351` |

Front-end-only "options" that are really control variables (not in `OPTtbl[]`) and matter to
analyses: `savecurrents` (`inp_savecurrents()`, `inp.c:1084` — verified to add `i(@r1[i])`,
`i(@c1[i])` columns), `seed`, `warn`, `maxwarns` (`inp.c:1447-1455`), `autostop`,
`nostepsizelimit` (`traninit.c:30`), `sqrnoise` (`noisean.c:242`), `noparse`, `brief`
(set by default per manual §17), `interp`, `filetype`, `ngbehavior`, `casemode`, `xtrtol`,
`cshunt_value`, `soacheck`.

### 3.22 `.global`, `.include`/`.inc`, `.lib`, `.param`, `.func`, `.csparam`, `.model`, `.subckt`/`.ends`

These do not create analyses but shape what an analysis can address.

* **`.global name1 [name2 ...]`** — consumed by `collect_global_nodes()`
  (`src/frontend/subckt.c:165-205`); the card is commented out. `INP2dot`'s
  ` Warning: .global not yet implemented - ignored ` (`inp2dot.c:958`) is dead code (verified:
  `.global vdd` produces no message). The reader auto-inserts `.global gnd` as line 1 unless
  `no_auto_gnd` is set or PSPICE compat is on (`inpcom.c:2330-2336`); otherwise it prints
  `Note: gnd in a subcircuit is not set to 0 automatically`.
* **`.include <file>` / `.inc <file>`** — `inpcom.c:1862-2072`. Filename may be quoted
  (`get_quoted_token`). Resolution: `inp_pathresolve_at(name, dir_of_including_file)`, then a
  retry against the most recent successful include directory (`inpcom.c:1935-1948`). Errors are
  **fatal to the process** (`controlled_exit(EXIT_FAILURE)`):
  `Error: .include filename missing`, `Error: Could not find include file %s`,
  `Error: .include statement failed.\nCould not open file\n%s`. The card is rewritten to
  `* end of: …`. `.incpslt` switches to PSPICE+LTSPICE compat for the included file only
  (`inpcom.c:1874-1909`).
* **`.lib <file> <section>`** — new-style; expanded by `expand_section_ref()`
  (`inpcom.c:4416-…`) against `.lib <section> … .endl` blocks found by
  `find_section_definition()` (`inpcom.c:517-554`, `strcasecmp` on the section name). Fatal
  errors: `ERROR, library file %s not found`, `ERROR, library file %s, section definition %s not
  found`, `ERROR, .endl not found`, `\nError: Missing second quote in line \n      %s`.
  Under `ngbehavior` containing `lt` or `ps`, `.lib <file>` is rewritten to `.inc <file>`
  with `  File included as:   .inc %s` (`inpcom.c:1830-1839`). Verified working with a two-section
  library.
* **`.param <ident>=<expr> ...`** — numparam category `'P'` (`spicenum.c:241-244`); order-free;
  duplicates: last wins. Multi-assignment on one line is split by
  `inp_split_multi_param_lines()` (`inpcom.c:144`).
* **`.func <ident>(args) {expr}`** / `.func <ident>(args) = {expr}` — `inp_grab_func()` /
  `inp_expand_macros_in_deck()` (`inpcom.c:135, 139`).
* **`.csparam <ident>={expr}`** — `inp.c:1027-1055`: split on `=` and turned into a `let` in the
  `const` plot, so the value is reachable from `.control` as `$&ident`. Bad syntax:
  `Warning: bad csparam definition, %s skipped!` + `    See line %d, .%s` (`inp.c:1040-1041`).
* **`.model` / `.subckt` / `.ends`** — `.model` in pass 1 (`inppas1.c:13-45`); `.subckt`/`.ends`
  in `inp_subcktexpand()`. `INP2dot`'s
  ` Warning: Subcircuits not yet implemented - ignored ` (`inp2dot.c:929`) is dead code.
  The aliases `.macro`/`.eom` are accepted (`inpcom.c:3356-3359, 3692-3696`), and
  `substart`/`subend`/`subinvoke`/`modelcard`/`modelline` control variables can rename them
  (`subckt.c:241-250`).
* **Analysis cards inside a `.subckt` are honoured.** Verified: a `.tran 10u 1m` inside a
  `.subckt` body produced a `Transient Analysis` plot. A GUI that emits hierarchy must not leak
  analysis cards into subcircuit bodies.

### 3.23 `.if` / `.elseif` / `.else` / `.endif`

```
.if (boolean expression)
  ...
.elseif (boolean expression)
  ...
.else
  ...
.endif
```

* `dotifeval()` / `recifeval()` (`inp.c:2130-2215`), run after subcircuit expansion and numparam
  substitution. numparam has already turned `.if(expr)` into `.if (   1.000000000e+000  )`; the
  condition is read with `atoi(line+3)` (`inp.c:2146`) and `atoi(line+7)` for `.elseif`
  (`inp.c:2160`). Non-taken branches are commented out in place.
* **This gates analysis cards.** Verified:
  ```
  .param mode=2
  .if (mode==1)
  .tran 10u 1m
  .elseif (mode==2)
  .ac dec 5 1 1k
  .else
  .op
  .endif
  ->  a single 'AC Analysis' plot, 16 points
  ```
  This is the cleanest deck-level mechanism a GUI has for "pick one analysis of several".

### 3.24 Accept-and-ignore / diagnostic-only cards

| Card | Behaviour | Anchor |
|---|---|---|
| `.end` | Reader comments it out and appends one terminal `.end`; **cards after it still parse** | `inpcom.c:2287-2291, 2348-2351`; verified |
| `.prot` / `.unprot` | Suppress the "Processed Netlist" listing between them; ignored by the parser | `inp.c:1539-1544`, `inp2dot.c:964-967` |
| `.title <text>` | Replaces the deck title (last one wins), card → `*` | `inpcom.c:1812-1825`; verified: two `.title` lines → `Circuit: second title` |
| `.hdl <file>` | `Warning: Dot command .hdl is not supported, ingnored` + line/file + `This message will be posted only once!`; card dropped | `inpcom.c:1841-1851`; verified |
| `.biaschk` | `Warning: Dot command .biaschk is not supported, ingnored` + once-only note | `inpcom.c:1852-1860`; verified |
| `.backanno` | Commented out (LTSPICE compat) | `inpcompat.c:1768` |
| `.distribution` | Commented out | `inpcompat.c:262-270` |
| `.cmodel` | Treated as a `.model` variant | `inpcom.c:3755, 3857, 5461` |
| `.sndparam` / `.sndprint` | Collected like `.print`; the executor is `#if defined(HAVE_LIBSNDFILE) && defined(HAVE_LIBSAMPLERATE)` — **both undefined here** (`config.h:189, 192`), so the cards are collected and then fall through to `Internal Error: ft_cktcoms: bad commands` | `dotcards.c:370-406, 422-428` |
| `.step ...` | ` unimplemented dot command '.step'` — **fatal** | `inp2dot.c:969-971`; verified; manual §12.11.4.3 confirms `.step` is script-only |
| any other `.xxx` | ` unimplemented dot command '.xxx'` — **fatal** | `inp2dot.c:969-971`; verified for `.zzz` |

---

## 4. Order, duplication and multi-analysis semantics

### 4.1 Execution order is by analysis type, not deck order

`CKTdoJob()` (`cktdojob.c:176-213`) has the comment `/* Analysis order is important */` and loops
`for (i = 0; i < ANALmaxnum; i++) for (job = task->jobs; …) if (job->JOBtype == i)`.
`analInfo[]` order (`analysis.c:36-59`):

```
0 OPTinfo   ("options")   – not a runnable job
1 ACinfo    ("AC")
2 DCTinfo   ("DC")        – DC transfer curve
3 DCOinfo   ("OP")
4 TRANinfo  ("TRAN")
5 PZinfo    ("PZ")
6 TFinfo    ("TF")
7 DISTOinfo ("DISTO")
8 NOISEinfo ("NOISE")
9 SENSinfo  ("SENS")
[ PSSinfo   ]  #ifdef WITH_PSS   (off here)
[ SEN2info  ]  #ifdef WANT_SENSE2 (never definable)
[ SPinfo    ]  #ifdef RFSPICE     (on here)
[ HBinfo    ]  #ifdef WITH_HB     (never definable)
```

**Verified** with a deck listing `.op .tran .ac .dc` in that order and `-r`:

```
Plotname: AC Analysis                No. Points: 51
Plotname: DC transfer characteristic No. Points: 5
Plotname: Operating Point            No. Points: 1
Plotname: Transient Analysis         No. Points: 112
```

i.e. AC → DC → OP → TRAN.

### 4.2 Duplicates run last-first

`CKTnewAnal()` does `(*analPtr)->JOBnextJob = taskPtr->jobs; taskPtr->jobs = *analPtr;`
(`cktnewan.c:34-35`) — a LIFO push. **Verified**:

```
.tran 10u 1m     (112 rows)
.tran 1u 200u    (209 rows)
.ac dec 5 1 1k   (16 points)
.ac lin 3 1 3    (3 points)
->  ac (3), ac (16), tran (209), tran (112)
```

The *second* `.ac` ran first, and the *second* `.tran` ran first. Every duplicate gets its own
plot: `ac1`, `ac2`, `tran1`, `tran2` (numbering follows creation order, `vectors.c:627-640`).

### 4.3 One deck-level task; interactive commands get a separate one

* The deck's cards accumulate on `ft_curckt->ci_defTask`, created in `if_inpdeck()`
  (`spiceif.c:129-131`). `run` executes that task (`spiceif.c:376-386`).
* Each of `op/dc/ac/tran/tf/pz/disto/noise/sens/sp` **deletes and re-creates** a "special" task
  `ci_specTask` (`spiceif.c:295-328`), so only the most recent interactive analysis is live.
* `CKTnewTask()` copies the default task's option values into a task named `"special"`
  (`cktntask.c:36-88`), so `.options` from the deck **do** apply to interactive analyses.
* `run` with an empty default task:
  `Warning: No job (tran, ac, op etc.) defined:` and return code 3 → `run simulation not started`
  (`spiceif.c:379-385`, `runcoms.c:354-358`). Suppressed in batch mode ("a hack to re-enable
  'make check'").

### 4.4 The double-run trap

In `--batch` mode, `main.c:1577-1583` calls `ft_savedotargs()` and, if it returns non-zero,
`ft_dorun()` — **even if a `.control` block already ran the simulation**. Verified:

```
.tran 100u 1m
.print tran v(out)
.control
run
.endc
->  2 runs   ("No. of Data Rows" appears twice)

same deck without the .print line
->  1 run
```

With `-r`, both runs happen but only the `ft_dorun()` one is written to the raw file (verified:
2 runs, 1 `Plotname`).

---

## 5. Where results land

### 5.1 Plot naming

`beginPlot()` copies the `IFuid` passed by the analysis into `run->type`
(`src/frontend/outitf.c:222`), `plotInit()` puts it in `pl_name` (`outitf.c:1214`), and
`plot_add()` derives the short type name via `ft_plotabbrev()` (`vectors.c:627-640`,
`src/frontend/typesdef.c:331-348`), which scans `plotabs[]` (`typesdef.c:67-90`) for the first
**substring** hit in the lowercased plot name:

```
tran <- "transient"     op   <- "op"        tf    <- "function"
dc   <- "d.c.","dc","transfer"              ac    <- "a.c.","ac"
pz   <- "pz","p.z.","pole-zero"             disto <- "disto"   dist <- "dist"
noise<- "noise"         sens <- "sens","sensitivity"           sens2 <- "sens2"
sp   <- "s.p.","sp"     harm <- "harm"      spect <- "spect"   pss  <- "periodic"
```

The `IFuid` strings the analyses pass:

| Analysis | `IFuid` (→ `Plotname:`) | typename |
|---|---|---|
| `.op` | `Operating Point` (`inp2dot.c:141`) | `op1` |
| `.tran` | `Transient Analysis` (`inp2dot.c:429`) | `tran1` |
| `.ac` | `AC Analysis` (`inp2dot.c:203`) | `ac1` |
| `.dc` | `DC transfer characteristic` (`inp2dot.c:303`) | `dc1` |
| `.tf` | `Transfer Function` (`inp2dot.c:368`) | `tf1` |
| `.pz` | `Pole-Zero Analysis` (`inp2dot.c:265`) | `pz1` |
| `.disto` | `Distortion Analysis` (`inp2dot.c:164`) | `disto1`, `disto2` |
| `.noise` | `Noise Spectral Density Curves` / `Integrated Noise` (`noisean.c:276-278, 534-535`) | `noise1`, `noise2` |
| `.sens` | `Sensitivity Analysis` (`inp2dot.c:485`) | `sens1` |
| `.sp` | `SP Analysis` (`inp2dot.c:736`) | `sp1` |
| `.ac`+keepopinfo | `AC Operating Point` (`src/spicelib/analysis/acan.c`) | `ac1` … (an `op`-ish name; `ft_plotabbrev` finds "op") |
| `.noise`+keepopinfo | `NOISE Operating Point` (`noisean.c:226`) | as above |
| `.pss` | `Periodic Steady State Analysis` (`inp2dot.c:675`) | `pss1` |

`deftype p <plottype> <pattern>` can extend `plotabs[]` at run time (`typesdef.c:192-217`;
`Error: too many plot abs (%d) defined.` when full).

### 5.2 Reference vectors

| Analysis | reference | type |
|---|---|---|
| `.tran` | `time` | time |
| `.ac`, `.sp`, `.noise` (spectral), `.sens ac` | `frequency` | frequency (`grid=3` = log) |
| `.dc` | `v-sweep` / `i-sweep` / `temp-sweep` / `res-sweep` | per `dctrcurv.c:180-189` |
| `.op`, `.tf`, `.pz`, `.sens dc`, `.noise` (integrated) | none (`refIndex = -1`) | — |

### 5.3 What a run writes

* With `-r <file>`, `ft_getOutReq()` returns TRUE (`runcoms.c:420-434`) and `fileInit()` writes
  the raw file; the frontend prints `binary raw file "<name>"` or `ASCII raw file "<name>"`
  (`runcoms.c:301, 309`) and `No. of Data Columns : N` / `No. of Data Rows : N`.
* Binary vs ASCII: the `filetype` control variable (`binary`/`ascii`), or the `SPICE_ASCIIRAWFILE`
  environment default (`runcoms.c:228-252`). Bad value:
  `Warning: strange file type "%s" (using "ascii")`.
* Without `-r`, `plotInit()` builds an in-memory plot; `plot_add()` prints
  `Title: …\nName: …\nDate: …` (`vectors.c:617-618`).
* An empty rawfile is unlinked at the end of the run (`runcoms.c:365-375`).

### 5.4 Exit status (`--batch`)

Measured on `ngspice -b`:

| Deck | no `-r` | with `-r` |
|---|---|---|
| `.tran` + `.print` | 0 | 0 |
| `.tran` only (no output card) | **1** (`Error: incomplete or empty netlist …no simulations run!`) | 0 |
| `.tran foo bar` + `.print` | 1 | 1 |
| `.op` only | 0 | 0 |
| `.zzz 1` + `.op` | 1 | 1 |

(`main.c:1561-1594`; `doc/codex/issues/0069` and `0072` in this tree are about exactly this
surface.)

---

## 6. Cards that configure rather than run — quick reference

### 6.1 The "options are variables" rule

See §3.21(a). Practically: **any** `name=value` or bare `name` on a `.options` card that
`OPTtbl[]` does not know becomes a nutmeg variable with no diagnostic. A GUI cannot rely on
ngspice to validate option names on a normal `.options` card; it must carry its own table (the
one in §3.21 plus the front-end variables listed there).

### 6.2 Save-set interactions (the single most confusing area)

`ft_getSaves()` (`breakp2.c:126-153`) flattens `dbs` into `(analysis, name)` pairs.
`beginPlot()` (`outitf.c:234-287`) then:

1. if there are **no** saves → `saveall = TRUE`, everything is written;
2. otherwise `saveall = FALSE`, and each save whose `analysis` field is set and does **not**
   `cieq` the current analysis's short name is skipped (`outitf.c:239-243`);
3. `all`/`allv` re-enable save-everything **for the analyses they are scoped to**;
4. if the resulting column count is 0 (or 1 with only the reference) →
   `Error: no data saved for %s; analysis not run` and `E_NOTFOUND`.

Which cards set an `analysis` scope: `.plot`/`.print`/`.sndparam`/`.sndprint` (their own
`PLTYPE`), `.four` (hard-coded `"TRAN"`), `.op` (`"OP"`), `.tf` (`"TF"`), and `.meas`
(via `measure_extract_variables`). `.save` never does.

**Verified failure mode** — a deck with `.op .tran .ac .dc .tf`, run without `-r`:

```
Error: no data saved for A.C. Small signal analysis; analysis not run
Error: no data saved for D.C. Transfer curve analysis; analysis not run
Error: no data saved for Transient analysis; analysis not run
doAnalyses: not found
run simulation(s) aborted
```

The same deck with `-r` runs all four analyses cleanly. **A GUI should always drive runs with
`-r` (or from `.control`) and never rely on `.print`/`.op`/`.tf` for output routing.**

### 6.3 `.options keepopinfo`

Adds a preceding operating-point plot to AC (`AC Operating Point`) and noise
(`NOISE Operating Point`). Verified for AC.

### 6.4 `.options savecurrents`

`inp_savecurrents()` (`inp.c:1084`) appends `.save @<dev>[i]` lines for every eligible device.
Verified: adds `i(@r1[i])`, `i(@c1[i])` columns.

### 6.5 `.probe`

Rewrites the netlist and forces `.save all` when no save exists — see §3.17.

---

## 7. Literal error and warning texts (index for a GUI's error→field mapping)

Fatal-to-netlist (attached to the card by `LITERR`, printed by `inp_dodeck()` as
`Error on line %d or its substitute:\n  %s\n%s\n`, then
`    Simulation interrupted due to error!` and `Error: circuit not parsed.`):

| Text | Card | Anchor |
|---|---|---|
| `Missing DEC, OCT, or LIN.` | `.ac` | `inp2dot.c:206` |
| `no such parameter on this device or parameter is missing` (preceded by the offending token echoed alone on stderr) | `.ac`, `.disto`, `.noise`, `.pz`, `.sp`, `.sens ac` | `inpapnam.c:29`, `sperror.c` |
| `Bad syntax! ` | `.dc` | `inp2dot.c:896` |
| `TSTEP is invalid, must be greater than zero.` | `.tran` | `transetp.c:34` |
| `TSTOP is invalid, must be greater than zero.` | `.tran` | `transetp.c:26` |
| `TSTART is invalid, must be less than TSTOP.` | `.tran` | `transetp.c:42` |
| ` Error: unknown parameter on .tran - ignored` | `.tran` | `inp2dot.c:452` (misleading — it is fatal) |
| `bad syntax [.noise v(OUT) SRC {DEC OCT LIN} NP FSTART FSTOP <PTSPRSUM>]` | `.noise` | `inp2dot.c:112-118` |
| `Syntax error: voltage or current expected.` | `.tf`, `.sens` | `inp2dot.c:399, 525` |
| `Syntax error: '(' expected after 'v'` | `.sens` | `inp2dot.c:497` |
| `Syntax error: 'ac' or 'dc' expected.` | `.sens` | `inp2dot.c:580` |
| ` Error: .ic syntax error.` | `.ic` | `inppas3.c:160` |
| ` Error: .nodeset syntax error.` | `.nodeset` | `inppas3.c:109` |
| `Error: unknown option %s - ignored` | `.options` **with braces only** | `inpdoopt.c:75` |
| ` unimplemented dot command '%s'` | any unknown dot card, `.step`, `.pss`/`.hb` when not built | `inp2dot.c:969` |
| ` obsolete dot command '%s' - ignored ` | `.width`/`.print`/`.plot` — unreachable in the normal path | `inp2dot.c:857` |
| `Frequency of 0 is invalid` | `.noise`, `.disto` | `nsetparm.c:53,63`; `dsetparm.c:26,36` |
| `Frequency of < 0 is invalid for AC start` / `... stop` | `.ac`, `.sp` | `acsetp.c:26,36`; `spsetp.c:28,38` |

Non-fatal (run-time or front-end):

| Text | Meaning | Anchor |
|---|---|---|
| `Warning, ngspice assumes default parameter(s) for ac simulation` + `    Check your input line '%s'` | `.ac` silently defaulted a value | `inp2dot.c:241-242` |
| `ERROR: AC startfreq <= 0` → `doAnalyses: parameter value out of range or the wrong type` | `.ac` with fstart 0 | `acan.c:79, 97` |
| `Fatal error: DC Transfer Function: Voltage source, current source, or resistor named "%s" is not in the circuit` → `doAnalyses: no such device` | `.dc` sweep target missing | `dctrcurv.c:153-157` |
| `Warning: Noise input source %s not in circuit` → `doAnalyses: not found` | `.noise` | `src/spicelib/analysis/noisean.c` |
| `doAnalyses: No source with f2 distortion input` | `.disto` with `f2overf1` and no `DISTOF2` source | distortion analysis |
| `doAnalyses: The input signal is shorted on the way to the output` | `.pz` with a bogus node | pz analysis |
| `Warning : IC on non-existent node - %s, ignored` / `Warning : Nodeset on non-existent node - %s, ignored` (+ `   Please check line %s`) | `.ic` / `.nodeset` | `inppas3.c:144-147, 95-98` |
| `Warning: no node named '%s'; it is referenced but no card defines it` | node named on `.tf`/`.sens`/`.noise`/`.pz` that no card defines (**fork-local diagnostic**) | `inpsymt.c` / `doc/claude/decisions/0008-undefined-node-diagnostic.md` |
| `Error: no data saved for %s; analysis not run` | save set empty for this analysis | `outitf.c:483` |
| `Error: .print: no %s analysis found.` / `Error: .plot: no %s analysis found.` | `.print`/`.plot` PLTYPE matched no plot | `dotcards.c:339, 367` |
| `Warning: no nodes given: %s` | `.four`/`.print`/`.plot` with no vectors | `dotcards.c:119, 144` |
| `Warning: can't parse '%s': ignored` | a save/print token that is not a vector | `gettoks()`/`copynode()` |
| `Warning from checkvalid: vector %s is not available or has zero length.` | `.print` of a missing vector | `src/frontend/com_display.c` / `vectors.c` |
| `Warning: option %s is currently unsupported.` / `Warning: option %s is obsolete.` | `.options itl3` etc. | `spiceif.c:514, 519` |
| `Warning: Could not set temperature to %s\n   Set to default 27 C instead.` | `.temp` with more than one value | `inp.c:1191` |
| `Warning: redundant .control card` / `Warning: misplaced .endc card` | nesting errors | `inp.c:769, 778` |
| `Warning: Missing .control statement!\n    in file %s\n    This may cause subsequent errors.` | stray `.endc` | `inpcom.c` |
| `Note: Empty .probe command, treated as .probe alli` | `.probe` with no args | `inpc_probe.c:109` |
| `Note: v1: dc value used for op instead of transient time=0 value.` | informational, printed per source per OP | `src/spicelib/devices/vsrc` |
| `Error: incomplete or empty netlist\n       or no ".plot", ".print", or ".fourier" lines in batch mode;\nno simulations run!` | batch mode, no output card, no `.control` run | `main.c:1589-1592` |
| `Error: incomplete or empty netlist\n       or no node to report an operating point for;\nno operating point printed!` | `.op` on a deck with no non-ground node | `dotcards.c:232-235` |
| `Internal Error: ft_cktcoms: bad commands` | a card reached `ft_cktcoms()` that it cannot dispatch (e.g. `.sndprint` in a build without libsndfile) | `dotcards.c:458-460` |

Command-form wrapper (see §8): each of the above card errors is re-emitted as
`Error: <text>\nin   .<card>\n<what> simulation(s) aborted`.

---

## 8. `.control` equivalence

### 8.1 The mapping

`if_run()` (`spiceif.c:257-368`) recognises `tran ac dc op pz disto adjsen sens tf noise`
(+ `pss` if `WITH_PSS`, `sp` if `RFSPICE`, `hb` if `WITH_HB`), builds `".<what> <flattened args>"`
into a `char buf[BSIZE_SP]` (**512 bytes**, `src/include/ngspice/defines.h:118`) and runs
`INPpas2()` on it. **The grammar is therefore identical, character for character.**

| Card | Command | Command table entry |
|---|---|---|
| `.op` | `op [args]` | `commands.c:312-315` |
| `.tran ...` | `tran ...` | `commands.c:320-323` |
| `.ac ...` | `ac ...` | `commands.c:339-342` |
| `.dc ...` | `dc ...` | `commands.c:343-346` |
| `.tf ...` | `tf ...` | `commands.c:316-319` |
| `.pz ...` | `pz ...` | `commands.c:347-350` |
| `.sens ...` | `sens ...` | `commands.c:351-354` |
| `.disto ...` | `disto ...` | `commands.c:355-358` |
| `.noise ...` | `noise ...` | `commands.c:359-362` |
| `.sp ...` | `sp ...` | `commands.c:334-337` (`#ifdef RFSPICE`) |
| `.pss ...` | `pss ...` | `commands.c:326-329` (`#ifdef WITH_PSS`; absent here — `pss: no such command available in ngspice`) |
| (all deck cards) | `run [rawfile]` | `commands.c:467-470` |
| `.four f v...` | `fourier f v...` | `commands.c:387-390` |
| `.meas ...` | `meas ...` | `commands.c:395-398` |
| `.save ...` | `save ...` | `commands.c:439-442` |
| `.print ...` | `print ...` | `com_print` |
| `.plot ...` | `plot ...` / `asciiplot ...` | |
| `.options ...` | `option ...` / `options ...` | `commands.c:140-145` |
| `.width out=N` | `set width=N` | |
| `.temp v` | `set temp=v` | |
| — | `step [n]`, `resume`, `stop`, `reset`, `remcirc`, `alter`, `altermod`, `alterparam`, `optran`, `setcirc` | `commands.c:411-470`, `src/spicelib/analysis/optran.c:73` |

Note `step` in the control language is **"iterate n times after a breakpoint"**
(`commands.c:455-458`), not a parameter sweep.

### 8.2 Behavioural differences (all verified)

1. **Error handling.** A bad card kills the netlist; a bad command kills only itself and the
   session continues:
   ```
   .control
   ac decade 5 1 1k
   tran
   tran 1u 100u foo
   dc v1 0 1
   noise
   pz in 0 out 0
   sens out
   op
   .endc
   ```
   produces
   ```
   decade
   Error: no such parameter on this device or parameter is missing
   in   .ac decade 5 1 1k
   ac simulation(s) aborted
   Error: TSTEP is invalid, must be greater than zero.
   TSTOP is invalid, must be greater than zero.
   in   .tran
   tran simulation(s) aborted
   Error:  Error: unknown parameter on .tran - ignored
   in   .tran 1u 100u foo
   tran simulation(s) aborted
   Error: Bad syntax! in   .dc v1 0 1
   dc simulation(s) aborted
   Error: bad syntax [.noise v(OUT) SRC {DEC OCT LIN} NP FSTART FSTOP <PTSPRSUM>]
   in   .noise
   noise simulation(s) aborted
   Error: no such parameter on this device or parameter is missing
   no such parameter on this device or parameter is missing
   in   .pz in 0 out 0
   pz simulation(s) aborted
   Error: Syntax error: voltage or current expected.
   in   .sens out
   sens simulation(s) aborted
   ```
   and then `op` still runs. The wrapper format is `Error: %sin   %s\n\n`
   (`spiceif.c:365`) followed by `%s simulation(s) aborted` (`runcoms.c:349`).
   Note the card form gives a line number; the command form does not (`deck.linenum = 0`).
2. **Task lifetime.** Each command replaces `ci_specTask`; the deck's `ci_defTask` is untouched
   and still runs on `run`. Verified:
   ```
   .tran 10u 1m
   .control
   ac dec 5 1 1k
   tran 1u 100u
   run
   setplot
   .endc
   ->  Current tran2   (Transient Analysis)   <- from 'run', i.e. the .tran card
             tran1     (Transient Analysis)   <- from 'tran 1u 100u'
             ac1       (AC Analysis)          <- from 'ac dec 5 1 1k'
             const
   ```
3. **`{}` is not substituted in a control command.** Control lines are removed from the deck
   before `inp_subcktexpand()` runs numparam (`inp.c:779-807` vs `inp.c:936-942`), and
   `transform()` classifies in-control lines as category `'C'` (`spicenum.c:653-659`).
   Verified:
   ```
   .param tstop=2m
   .csparam ctstop={tstop}
   .control
   tran {tstop/200} {tstop}   ->  TSTEP is invalid… / TSTOP is invalid… / unknown parameter
   tran 10u $&ctstop          ->  runs
   .endc
   ```
   **The GUI must emit `.csparam` + `$&name` (or plain literals) for control-block analyses.**
4. **`.op` printing.** A `.op` *card* makes `ft_cktcoms()` print the node/source table plus
   `showmod` and `show` (`dotcards.c:222-272`). The `op` *command* prints only
   `No. of Data Rows : 1`; the table needs an explicit `print all` / `op` + `show`.
5. **Command availability flags.** `pz` and `disto` have `co_major = FALSE`
   (`commands.c:347, 355`), i.e. they are omitted from the short `help` listing.
6. **`.control` block placement.** `.control`/`.endc` may appear anywhere; the block is extracted
   in deck order and executed after the circuit is built (`inp.c:1259-1296`). Commands prefixed
   `pre_` are extracted separately and run **before** circuit parsing (`inp.c:787-793, 845-859`).
   `*#` at the start of a line makes a single control command outside a block
   (`inp.c:779-805`). Nesting errors: `Warning: redundant .control card`,
   `Warning: misplaced .endc card`.
7. In a shared build (`SHARED_MODULE`) control execution can be deferred by the `controlswait`
   variable (`inp.c:1273-1287`).

---

## 9. Build gates summary for this tree

From `build-ver_50/src/include/ngspice/config.h` and `configure.ac`:

| Macro | Card(s) affected | configure switch | State here | Default upstream |
|---|---|---|---|---|
| `RFSPICE` | `.sp` | `--disable-sp` to turn off (`configure.ac:1220-1227`) | **ON** | on |
| `WITH_PSS` | `.pss` | `--enable-pss` (`configure.ac:1082-1085`) | **OFF** | off |
| `WANT_SENSE2` | `.sens2` | `--enable-sense2` declared (`configure.ac:232-234`) but **no `AC_DEFINE`** | **impossible** | impossible |
| `WITH_HB` | `.hb` | none | **impossible** | impossible |
| `XSPICE` | `.options maxopalter/maxevtiter/noopalter/ramptime/convlimit/convstep/convabsstep/autopartial/rshunt`; `A` devices; `null` global node | `--disable-xspice` | **ON** | on |
| `KLU` | `.options klu/sparse/klu_memgrow_factor` | `--enable-klu`-ish; defined here | **ON** | on |
| `CIDER` | `.model` case retention, `.options` numeric-device knobs | `--enable-cider` | **OFF** | off |
| `OSDI` | `osdi` command, `pre_osdi` | `--disable-osdi` | **ON** | on |
| `HAVE_LIBSNDFILE` + `HAVE_LIBSAMPLERATE` | `.sndparam`, `.sndprint` executors | autodetect | **OFF** (both `#undef`) | depends |

---

## 10. Gaps, hazards and open questions

1. **`.pz` keyword comment is wrong** in `inp2dot.c:259` (`{V I}` vs the real `vol`/`cur`).
   A GUI generator that follows the comment produces decks that fail.
2. **`.meas INTEGRAL` / `DERIVATIVE` are documented but not implemented.** Emit `INTEG` / `DERIV`.
3. **`.sens deftol` / `defperturb` have handlers but no `IFparm` entries** — unreachable.
   If ASE-L wants perturbation control it must be added to `SENSparms[]`.
4. **`.tran`'s "ignored" message is fatal.** Any GUI that offers a free-text "extra options" field
   on the transient form will produce dead netlists; validate the trailing token against exactly
   `uic`.
5. **`if_run()`'s `sprintf(buf, ".%s", s)` into a 512-byte buffer** (`spiceif.c:249, 280`) is
   unbounded. A very long `.sens` filter list or `.dc` line issued as a *command* can overflow it.
   Not exercised here; flagged for whoever builds the command path.
6. **`Sens_filter` is a process-global** (`cktsens.c:33`) freed and rebuilt per `.sens` card
   (`inp2dot.c:533-534`). Two `.sens` cards in one deck share the last card's filters. Not
   tested; the code reads that way.
7. **Nested `.dc` produces a flat plot with no dimension metadata.** The GUI must reconstruct the
   outer sweep from the reference vector's saw-tooth, or issue one `dc` command per outer point.
8. **`.step` is absent.** The plan needs a decision on how ASE-L expresses parametric sweeps:
   `.control` loops (`foreach` / `while` + `alterparam` + `reset` + `run`), `.if` corner
   selection, or the GUI running ngspice once per point. Not resolved here.
9. **Whether `.print`/`.plot`/`.width` can ever reach `INP2dot`** — I could not construct a case
   in the file/`source` path; the `obsolete dot command` branch appears dead. A shared-library
   (`ngSpice_Circ`) caller was not tested and may differ.
10. **`casemode` is fork-local** (commit `424ebaf75`). If ASE-L is meant to work against stock
    ngspice too, it must not depend on `preserve`/`distinguish` or on the fork-local
    `Warning: no node named '…'` diagnostic.
11. **Monte-Carlo / `mc_source`, `.distribution`, `agauss`/`unif` in `.param`** touch analysis
    setup (`inp.c:944-951, 1076-1081`; `commands.c` `mc_source`) but were not explored — they are
    the natural companion to a "statistical analysis" tab and need their own pass.
12. **Shared-library route** (`src/sharedspice.c`, `ngSpice_Command`, `ngSpice_Circ`) was not
    exercised. If ASE-L drives `libngspice` rather than the binary, the batch-mode rules in §4.4
    and §7 (which live in `main.c`) do **not** apply, and control execution may be deferred
    (`controlswait`). This needs a separate confirmation pass.
13. **`.op` on a deck with no non-ground node** returns 1 from `ft_cktcoms()`
    (`dotcards.c:231-237`) — an empty-schematic case a GUI will hit constantly.

---

## 11. Reproduction recipes

All decks live under
`/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/dot/`.
The probe harness used throughout is `runcard.sh`:

```sh
#!/bin/sh
# $1 = the dot card under test
NG=/home/analog/dev/ngspice/build-ver_50/src/ngspice
D=$(mktemp -d .../scratchpad/dot/tc.XXXX)
cat > $D/t.cir <<EOF
error probe deck
v1 in 0 dc 1 ac 1 sin(0 1 1k)
r1 in out 1k
c1 out 0 1u
$1
.end
EOF
echo "### CARD: $1"
$NG -b -r $D/t.raw $D/t.cir 2>&1 | grep -v <noise>
rm -rf $D
```

Useful one-liners:

```sh
# analysis order and plot names
ngspice -b -r out.raw deck.cir >/dev/null 2>&1 && strings out.raw | grep -E '^Plotname|^No. Points'
# the exact column list of a plot
strings out.raw | sed -n '/Variables:/,/Binary/p'
# interactive plot inventory
printf 'source deck.cir\nrun\nsetplot\ndisplay\nquit\n' | ngspice -p
# what a scale suffix evaluates to
# (put the value on a C or R and read it back)
printf 'source p.cir\n' | ngspice -b   # with .control: op / print @c1[capacitance] / .endc
```
