# 1443 — a GUI that could not read a number back, and five producers nobody could ask for

**Status:** fixed
**Branch:** `fluid-editing`
**Area:** ASE-L — measurements and post-processing (`PLAN.md` Stage 8a + 8c)
**Suite:** `tests/headless/test_ase_meas_1443.tcl` (new)
**Batch:** `doc/claude/ase_analyses_batch/`, Stage 8 task 1 of 2

---

## The defect

`grep -c '\bmeas\b' src/ase.tcl` returned **zero**. Two of the six benchmark ADE
tasks the batch is measured against — *read back the phase margin* and *the
spread of one measurement over 200 Monte Carlo runs* — ended at *"you are on your
own"*. A user could run every analysis ngspice has and then had to read the
number off a log by eye.

And `.four`, `fft`, `spec`, `psd` and `linearize` had **destinations in every
design and no producers anywhere**: nothing in ASE-L could ask for one, so the
harmonic table, the spectrum and the THD were unreachable from the GUI.

## What shipped

A `measurements` state list beside `outputs` — one row per measurement, absent by
default, in `ase::omit_if_empty` — emitted as `meas` **commands** inside
`.control`, immediately after the analysis they read, plus the five
post-processing producers. ASE-L owns the schema (the list, the row shape, the
refusal evaluator, the sidecar and its parser, the emission order); the ngspice
adapter owns the kind vocabulary, the line spelling, the phase-unit trap and the
producer commands, through four new **optional** hooks.

**The radians trap is defeated through the one option speller.** Measured on both
binaries, an RC whose phase at 1 kHz is exactly −45°, through `meas` itself:

```
(nothing set)           meas ac p FIND vp(out) AT=1k  ->  -7.853982e-01
.options units=degrees  the same line                 ->  -7.853982e-01
set units=degrees       the same line                 ->  -4.500000e+01
```

End to end on both binaries, on an RC whose −3 dB point is exactly 1 kHz:

```
f3db                =  1.000000e+03
phs                 =  -4.500000e+01      <- DEGREES
```

---

## Corrections — C145 onwards (C100–C144 were issues 1437, 1439, 1441 and 1442)

### C145 — `units` IS one of the 247 catalogue rows, and the brief says it is not

This task's brief and `LEDGER.md`'s Stage 8 block both state that *"`units` is
**not** one of the 247 catalogue rows at all — neither an `OPTtbl` keyword nor a
`cp_getvar` name"*. **Counted live 2026-09-13 over the shipped catalogue: it is
one of them**, added by issue 1437, with `cptype string`, `phase run`, `group
output`, `default radians`, `values {radians degrees}`, `ngphase C` and a `help`
that already carries the 57.2958 sentence. `ase::opt_door ngspice units control`
answers `control`, `ase::opt_line ngspice units degrees control` already spells
`set units=degrees`, and `ase::opt_restore_line` already spells
`set units=radians`.

⚠ **The consequence is a better fix than the brief asked for.** The auto-emission
goes **through the one speller** rather than through a new adapter literal, so
the line cannot drift from the options sheet's answer for the same option, and a
second adapter that describes its own phase-unit option gets the behaviour for
free. Rows **PH3**, **PH3b** and **PH3c**.

### C146 — trap 4's REASON is false on the binary a downloading user has

`PLAN.md` §8a: *"the created vector carries only 7 significant digits (`"%e"` at
`measure.c:138`), so when full precision matters the GUI redirects `meas … > file`
and parses the printed line."* The redirect works (see C152) — but **the
precision argument for it does not hold on apt 45.2**. Measured 2026-09-13, the
same deck on both binaries, with `set measureprec` **and** the
`NGSPICE_MEAS_PRECISION` environment route:

| | default | `set measureprec=12` | `set measureprec=14` | env `=12` |
|---|---|---|---|---|
| **apt 45.2** | `7.561621e-01` | `7.561621e-01` | `7.561621e-01` | `7.561621e-01` |
| **the fork** | `7.56162e-01` | `7.561621326422e-01` | `7.56162132642176e-01` | unchanged |

`$measureprec` reads back `12` on apt 45.2 and the printed line does not move: the
setting is **accepted and inert** there, in silence. `%.6e` is seven significant
digits, which is exactly what `measure.c:138`'s `"%e"` gives the vector — so on
45.2 the redirect buys **nothing at all** over the vector.

⚠ **It still ships, and the reason that is true is a different one**: a failed
measurement's own diagnostic goes to the run log while every successful one goes
to a file ASE-L parses deterministically, and on the fork the redirect really
does carry six more digits. Shipping the plan's reason would have put an
unmeasured claim on the user's screen. Same shape as issue 1442's C141.

### C147 — traps 1 and 2 are about the CARD; on the COMMAND form both spellings do not exist

`PLAN.md` §8a lists *"`expr=` is broken"* and *"`param=` is one-shot per
session"* as two refusals a form must encode, and then lists `param` as one of
the eight **kinds**. Re-measured 2026-09-13 on both binaries, on the COMMAND form
the deck actually uses:

```
meas tran e1 expr='ok1+7'   -> Error: measure e1 : no such function as 'expr=7.756162e+00'
meas tran p1 param='ok1+7'  -> Error: measure p1 : no such function as 'param=7.756162e+00'
meas tran p2 param=ok1      -> Error: measure p2 : no such function as 'param=7.561621e-01'
meas tran r1 FIND par('v(mid)*2') AT=1m -> Error: no such vector as par(v(mid)*2)
```

`com_meas()` goes straight to `get_measure2` and never reaches the numparam path
the card uses, so all three expression spellings are simply **absent**. The
`param` kind therefore ships as a **`let`**, which is measured to work
(`let pm1 = 180 + ok1` → `pm1 = 1.807562e+02`, both binaries) and which cannot
meet trap 2 at all — the once-per-session numparam placeholder is not on that
route. Rows **LN9**, **LN9b**.

### C148 — `.four` as a CARD runs the whole simulation a SECOND time

`PLAN.md` §8c: *"`.four` is a **CARD** in the slot above `.control`."* Measured
2026-09-13 on both binaries, the same circuit written two ways:

| deck | `Doing analysis at TEMP` | THD reported |
|---|---|---|
| `.four 1k v(mid)` card + `.control tran … write` | **2** | 9.99999 % |
| `fourier 1k v(mid)` command inside `.control` | **1** | 9.99999 % |

`main.c`'s batch arm calls `ft_dorun(NULL)` whenever `ft_savedotargs()` reports
any `.print`/`.four`/`.meas` save, **even when a `.control` block has already run
the deck** — so a card doubles the simulation. The `fourier` command creates the
identical `fourier<m><n>` and `thd<m><n>` vectors and prints the identical
harmonic table.

⚠ **So the `.four` card slot ships EMPTY and the rule is kept, not broken.** §8c
states the card/command split as *"nothing analysis-shaped ever goes in the card
slot"*; emitting no dot card at all satisfies it and costs the user nothing.
Row **DK4** asserts that no `.meas`, `.measure` or `.four` line is ever written.

### C149 — a producer's plot in the results file is read back as the analysis it MIMICS

`PLAN.md` §8c: *"All four are captured by Stage 6's walk and named by the same
sidecar."* `src/save.c`'s `read_dataset()` maps a `Plotname:` to a `sim_type` by
**substring**: `strstr(lowerline, "transient analysis")` at `:957` and
`strstr(lowerline, "spectrum")` at `:987`. Measured 2026-09-13 through this
tree's own reader, on one results file holding a real transient, a linearized
copy made to **disagree** with it, and an `fft` spectrum:

```
xschem raw read multi.raw tran  ->  points=809, vars=4, datasets=2  sim_type=tran
xschem raw read multi.raw ac    ->  points=205, vars=8, datasets=1  sim_type=ac
                                    ... with no ac analysis in the deck at all
```

That is issue **1430**'s `AC Operating Point` refusal exactly, one stage later: a
companion plot needs a results file of its **own** before it can be captured.

⚠ **So no producer plot is written**, `ase::analysis_captures`, the
`setplot previous` walk and the plotmap are untouched — which is what keeps
`test_ase_core`'s **WK8** over-walk guard meaning what it meant — and the
producers' RESULTS come back as measurements (`meas sp <name> MAX v(out)` on the
spectrum) and as the printed harmonic table. Rows **PP7**, **PP7b**, **DK6**.

### C150 — a measurement vector written into the simulation plot costs a FULL-LENGTH column

`APPENDIX` §6.7 recommends the rawfile route in as many words: *"a length-1
vector in the current plot, via `com_let` — so a subsequent `write` carries it as
an extra column with `dims=1`. **This is how a GUI gets numeric measurements back
through the rawfile instead of scraping stdout.**"* Measured 2026-09-13 on both
binaries, one `.tran 0.2u 200m` (1,000,001 points), the same circuit:

| deck | rawfile |
|---|---|
| `fourier` **after** the `write` | **48,000,724** bytes |
| `fourier` **before** the `write` | **64,000,905** bytes |

**+16 MB for two scalars**, because the plot's default scale is imposed and a
length-1 vector is expanded to the whole record — the "Anti-route" of
`evidence/measure.md` §2, met by the route §6.7 recommends. The measurement block
therefore sits **below** the row's first `write`, and the numbers come back
through the sidecar. Row **DK2**, bound four ways, and **DK2c** on the emitter.

### C151 — `fft`, `psd` and `spec` leave their OWN plot current, so a second transform reads a spectrum

`PLAN.md` §8c: *"`fft`/`spec`/`psd` are COMMANDS after the transient."* Measured
2026-09-13 on both binaries, in one deck:

```
tran …           ->  $curplot = tran1
linearize        ->  $curplot = tran2   (Transient Analysis (linearized))
fft v(mid)       ->  $curplot = sp2     (Spectrum)
psd 1 v(mid)     ->  Error: fft needs real time scale    <- NO PLOT, and rc 0
```

Written one after another they do not compose: the second transform reads the
first one's output. The block therefore tracks a time-domain **source** variable,
which `linearize` updates and every later transform is sent back to. Rows
**PP3**, **PP4**, **PP4b**.

⚠ And the plot literals themselves are confirmed, on both binaries:
`fft` → `sp2` (`Spectrum`), `psd` → `sp3` (`PSD`), `spec` → `sp4` (`Spectrum`),
`linearize` → `tran2` (`Transient Analysis (linearized)`), and `fourier` creates
**no plot at all** and leaves `$curplot` where it was.

### C152 — a FAILING `meas … > file` creates the file and leaves it at ZERO bytes

Trap 4 assumes a `meas` command can be redirected. Measured 2026-09-13 on both
binaries, in one deck, with `echo … > f` (22 bytes) and `print … > f` (31 bytes)
as positive controls in the **same** deck — because after issue 1442's `option >`
finding a null result here is exactly the answer that looks the same whether you
measured or not:

| command | bytes |
|---|---|
| `echo POSITIVE-CONTROL-ECHO > f` | **22** |
| `print v(mid)[0] > f` | **31** |
| `meas tran mx MAX v(mid) > f` | **54** / **66** |
| **a `meas` whose measurement FAILS, `> f`** | **0** |

So the redirect works — and opening the sidecar with `>` on the first measurement
would **truncate the whole file** whenever that one row fails. It is opened with
an `echo` that cannot fail and every measurement appends. Row **DK3**.

⚠ And the failure's own diagnostic goes to **stdout on apt 45.2 and to stderr on
the fork** — both reach the run log through `2>@1`, and neither reaches the
sidecar, which is what makes "the row produced no number" a readable verdict.

### C153 — `ase::si_parse` answers `{ok <value>}`, not a number

Recorded because the first cut of the `spec` band rule read it as a number, and
**every band then passed silently** — two lists compared with `<=`. It is the
same shape as this batch's other silent-comparison defects and it will bite the
next rule that validates a numeric field. `ase::backend::ngspice::meas_num` is
the one-line reader that unwraps it.

---

## What I did NOT ship, and why

* **A Measurements dialog, a template picker or a Value-column row.** That is
  Stage 8 **task 2** (§8b) and this task deliberately builds no widget. The
  schema shapes task 2 inherits are listed in the receipt.
* **A results file for the producers' plots.** C149 makes it a real artefact with
  a reader of its own — `<cell>_ase.spectra.raw`, deleted per run — and that is a
  separate change with its own blast radius. Until then the plot is produced, it
  is measurable, and it is not in the results file.
* **`meas` on an S-parameter run.** `sp` is still a probe stub with no `emit`
  template, so no deck can carry one. The crash rule is written over the analysis
  word anyway, so it covers `sp` the day Stage 9 gives it fields — and it is
  testable today because binding asks the bench, not the emit order.
* **`autostop`.** It is a `.meas`-card feature (`ft_curckt->ci_meas`) and this
  change emits no cards.
* **`help` text for the kinds.** ⚖ R9, as Stage 7 left it.

---

## Files

| file | what |
|---|---|
| `src/ase.tcl` | the `measurements` schema key, thirty `ase::meas_*` core procs, the ngspice kind catalogue and speller, `render_deck`'s block and fatal re-check, `run_deck`'s sidecar deletion |
| `tests/headless/test_ase_meas_1443.tcl` | **new**, 88 checks, sections KN VD LN PH PP DK SC HK |
| `tests/headless/test_ase_core.tcl` | R1 re-baselined 18 → 19 schema keys, R1m added, floor 598 → 600 |
| `tests/headless/test_ase_persist.tcl` | R1 re-baselined 18 → 19 schema keys |
| `tests/run_regression.tcl` | `hcases` gains `headless/test_ase_meas_1443` |
