# Dossier: the three capabilities nobody had executed — PSS, CIDER, libngspice

Reader: the session that writes the ASE-L analyses plan.
Scope: close critique §5.7 items 1, 2 and 3 — the three things every earlier dossier
described from source only because no build existed. Everything below was **built and run
in this session**. Nothing in either repository was modified.

* ngspice source: `/home/analog/dev/ngspice`, branch `ver_50`, `git describe = ngspice-46-419-gccebdf2a2`.
* Reference binary for "what does the stock build do": `/home/analog/dev/ngspice/build-ver_50/src/ngspice`.
* New out-of-tree builds, all under `/home/analog/.claude/projects/-home-analog-dev-ngspice/workpad/builds/`.
* Scratch decks: `/home/analog/.claude/projects/-home-analog-dev-ngspice/workpad/decks/`.
  Captured output: `/home/analog/.claude/projects/-home-analog-dev-ngspice/workpad/out/`.

**MEASURED** marks something run here. **SOURCE** marks something read in this tree here.

---

## 0. All four builds succeeded. This is itself the first answer.

The question behind critique §5.7 was partly "can a user have this at all". They can. Each
build is a plain out-of-tree `configure && make -j`, no `autogen.sh`, no patches, no
`make install`, zero errors.

| dir under `workpad/builds/` | configure line | wall time (`-j6`, 20 cores) | artifact | result |
|---|---|---|---|---|
| `pss/` | `--enable-pss` | 102 s | `src/ngspice`, 8.23 MB | **OK** |
| `cider/` | `--enable-cider` | 109 s | `src/ngspice`, 8.84 MB | **OK** |
| `shared/` | `--with-ngshared --enable-xspice` | 103 s | `src/.libs/libngspice.so.0.0.15`, 9.73 MB (no `src/ngspice`) | **OK** |
| `all/` | `--enable-pss --enable-cider --with-ngshared` | ~110 s (`-j8`) | `src/.libs/libngspice.so.0.0.15`, 10.43 MB | **OK** — see §3.9 |

Compiler warnings: 269 / 275 / 279 — the same background noise the stock tree produces; no
new warning classes from the three flags. `config.h` of each build confirms the intended
macro and only that macro moved: `pss/` has `#define WITH_PSS` with `CIDER` undef;
`cider/` has `#define CIDER 1` with `WITH_PSS` undef; `shared/` has `#define SHARED_MODULE 1`.
`XSPICE`, `OSDI`, `RFSPICE` and `KLU` are on in all four (they are the tree defaults).

**The one operational catch, MEASURED.** A build that is never `make install`ed has no
`spinit`, so **no XSPICE code models are loaded** and `devhelp` lists only the compiled-in
devices (52–57 rows instead of 133). This is not a defect but it will bite anyone comparing
device lists across binaries. The fix needs no install:

```sh
mkdir -p $LIBDIR/scripts
cp <build>/src/spinit            $LIBDIR/scripts/
find <build> -name '*.cm' -exec cp {} $LIBDIR/ \;
sed -i 's|/usr/local/lib/ngspice/|'$LIBDIR'/|g' $LIBDIR/scripts/spinit
SPICE_LIB_DIR=$LIBDIR <build>/src/ngspice ...
```

MEASURED: with `SPICE_LIB_DIR` unset → `Warning: can't find the initialization file spinit.`
and 57 device rows; with it set as above → no warning and **133** device rows, identical to
the installed stock binary. **A GUI that ships or points at a custom-configured ngspice must
set `SPICE_LIB_DIR`, or the user silently loses every code model.**

---

# PART 1 — PSS (`--enable-pss`)

## 1.1 The capability probe moves, exactly as F5 predicted

MEASURED, same deck (`help pss` inside `.control`), two binaries:

| binary | stdout |
|---|---|
| `build-ver_50/src/ngspice` (stock) | `Sorry, no help for pss.` |
| `builds/pss/src/ngspice` | `pss [.pss line args] : Do a periodic state analysis.` |

`help sp` answers `sp [.sp line args] : Do an S-parameter analysis.` on **both** (RFSPICE is
on by default), and `help hb` answers `Sorry, no help for hb.` on both — HB does not exist and
no flag creates it. **So `help pss` is a sound, cheap, one-line PSS probe** and it is the only
one: `$plots`, `devhelp` and the version banner say nothing about PSS.

Note the help string itself is a typo-carrying fork of the two tables (`spcp_coms[]` says
"periodic **state** analysis", `nutcp_coms[]` says "periodic **steady state** analysis"), so
match on the leading `pss ` token, not on the sentence.

## 1.2 It runs, it is fast, and it is deterministic

MEASURED, `builds/pss/src/ngspice -b`, decks in `workpad/decks/`, three repeats each:

| deck | `pss` args | wall | verdict line | f0 found | reference |
|---|---|---|---|---|---|
| `examples/pss/ring_osc_pss_ctrl.cir` body (3-stage CMOS ring) | `2G 10n bout 1024 10 5 5e-3 uic` | **0.91 s** (σ≈0) | `Convergence reached` | 3.758894068e9 | deck comment says "Predicted frequency is 3.8e+09 Hz" |
| `examples/pss/vdp_osc_pss_ctrl.cir` body (Van der Pol) | `0.5e6 100e-6 1 50 10 50 5e-3 uic` | **0.41 s** | `Convergence reached` | 4.590456891e6 | deck comment says "about 4.54167e+06 Hz" |

Both shipped examples converge, both agree with their own documented answer to ~1 %, and the
runtime is repeatable to the centisecond. **PSS on a small autonomous oscillator is a
sub-second analysis.** The Van der Pol case converged from a guess **9× too low**
(0.5 MHz guess → 4.59 MHz answer) in 11 shooting iterations.

## 1.3 The output: two plots, named, and the numbering is NOT fixed

MEASURED with the F6 multi-plot recipe (`set appendwrite` + `foreach p $plots / setplot $p /
write <file> all / end`), ASCII rawfile, ring oscillator:

```
Plotname: constants                                        No. Points: 1
Plotname: Time Domain Periodic Steady State Analysis       No. Points: 1025   scale: time
Plotname: Frequency Domain Periodic Steady State Analysis  No. Points: 10     scale: frequency
```

* The two `Plotname:` literals are exactly as `an-rf-pss.md` §3.6 read them from source.
  **Confirmed.** `setplot $p` + `echo $curplotname` returns them verbatim, so the F6 recipe
  maps PSS plots to analyses with no counter guessing.
* Typenames were `pss1` (TD) and `pss2` (FD) on a clean run. **Do not rely on that.**
* **Row counts:** the TD plot has `points + 1` rows (1024 → 1025). The FD plot has exactly
  `harmonics` rows, DC included (10 → 10).
* **The TD time axis is absolute circuit time, not 0…T.** MEASURED: first `time` = 1.144088832e-08,
  last = 1.170692402e-08, span = 2.66036e-10 s, which is exactly 1/3.758894068e9. So the plot
  is one period located wherever the shooting converged. **A GUI that plots "one period"
  must subtract the first sample itself**, or the x-axis starts at a meaningless offset.
* **The FD frequency axis** is `0, f0, 2f0, …, (harmonics-1)·f0` — MEASURED
  `0, 3.758894068e9, 7.517788135e9, 1.127668220e10, …`.
* **FD values are magnitudes only.** No phase, no THD, exactly as source said. `Mag[0]` is
  the DC mean (MEASURED `v(vdd)` row 0 = 1.200000000000023, row 1 = 2.23e-16).
* **The FD plot carries a rendering hint in the rawfile.** Every FD variable line ends
  `plot=1` (from `OUTattributes(…, PLOT_COMB, …)`), the TD ones do not. That is a free,
  machine-readable "draw me as a stem/comb plot" flag and no other ngspice analysis sets it.

**Vector names** are the ordinary `CKTnames` set — every node voltage and every branch
current, real, identical name list in both plots (`v(bout) v(gnd_ana) v(inv1) v(inv2) v(inv3)
v(vdd) i(vdd) v(vdd_ana)` on the ring). There is no PSS-specific vector.

## 1.4 Exit status does NOT move. The verdict is a string, and it is the only signal.

MEASURED across sixteen argument perturbations on the 3-stage ring
(`workpad/out/pssfail/*.out|err`, deck template `workpad/decks/p_<tag>.cir`):

| tag | `pss` args (changed field in bold) | rc | verdict on stdout | notes |
|---|---|---|---|---|
| `base` | `2G 10n bout 1024 10 5 5e-3 uic` | 0 | `Convergence reached` | f0 = 3.7589e9 |
| `fg_half` | **`1G`** | 0 | `Convergence reached` | guess 3.8× low — fine |
| `fg_100x` | **`200meg`** | 0 | `Convergence reached` | guess 19× low — fine, 2.1 s |
| **`fg_double`** | **`8G`** | **1** | *(none)* | **hard abort, see below** |
| `tstab_tiny` | **`0.1n`** | 0 | `Convergence reached` | |
| `tstab_zero` | **`0`** | 0 | `Convergence reached` | stabtime 0 is legal |
| `pts_2` | **`2`** points | 0 | `Convergence reached` | but `No. of Data Rows : 0`, plus an abort on stderr, plus **3** pss plots |
| `pts_0` | **`0`** points | 0 | `Convergence reached` | TD plot has **1** row |
| **`harm_1`** | **`1`** harmonic | **124 (timeout)** | *(none)* | **HANGS. Killed at 240 s, 199 % CPU** |
| **`harm_0`** | **`0`** harmonics | **139** | *(none)* | **SIGSEGV, no message at all** |
| `sciter_1` | **`1`** sc_iter | 0 | `Convergence not reached` | |
| `sciter_0` | **`0`** sc_iter | 0 | `Convergence not reached` | **4** pss plots (2 relaunches) |
| `sc_tight` | **`1e-9`** steady_coeff | 0 | `Convergence reached` | **false positive — see below** |
| **`fg_zero`** | **`0`** fguess | **1** | *(none)* | `Timestep too small` abort |
| `badnode` | oscnode = **`nosuchnode`** | 0 | `Convergence reached` | **no crash** — dossier correction |
| `nouic` | **no `uic`** | 0 | `Convergence not reached` | |

**Answer to "is exit status a success signal": no, and it is worse than that.** Exit status
moves only for the *hard* aborts (`fguess` too high, `fguess = 0`) and for the crash. The
ordinary give-up — `Convergence not reached` — returns **rc 0**, prints **both plots with a
full complement of plausible-looking data**, and differs from success by one word on stdout.

The two literal strings, from `dcpss.c`:

```
Convergence reached. Final circuit time is %1.10g seconds (iteration n° %d) and predicted fundamental frequency is %s Hz
Convergence not reached. However the most near convergence iteration has predicted (iteration %d) a fundamental frequency of %s Hz
```

Both are `fprintf(stdout, …)`. **The GUI must scrape stdout for `Convergence reached` /
`Convergence not reached` and must refuse to present a PSS result without it.**

## 1.5 The literal failure messages, with the route each takes

| condition | stream | literal text | rc |
|---|---|---|---|
| `fguess` above the true f0 (2.1× here) | stderr | `Error: Strange behavior`<br>`    CKTtime: 1.0125e-08`<br>`time_temp: 1e-08`<br>*(blank)*<br>`Error: Cannot find a minimum for error vector in estimated period. Try to adjust tstab! PSS analysis aborted`<br>`doAnalyses: impossible error - can't occur`<br>*(blank)*<br>`pss simulation(s) aborted` | 1 |
| `fguess = 0` | stderr | `doAnalyses: PSS:  Timestep too small; time = 2e-12, timestep = 1.39996e-10: trouble with node "gnd_ana"`<br>*(blank)*<br>`pss simulation(s) aborted` | 1 |
| `points = 2` | stderr | `Error: Cannot find a minimum for error vector in estimated period. Try to adjust tstab! PSS analysis aborted` — **while stdout still says `Convergence reached`** | 0 |
| `steady_coeff = 1e-9` | stderr | dozens of `Panic: breakpoint in the past - HELP!` plus one `Error: Strange behavior` block — **while stdout says `Convergence reached`** with f0 = 3.9296e9, i.e. **4.5 % wrong** | 0 |
| `harmonics = 1` | — | *nothing*; process spins at 199 % CPU indefinitely | hang |
| `harmonics = 0` | — | *nothing*; stdout truncated mid-line after ` Reference value :  1.14409e-08` | 139 |
| `dynamic_test == 0` (no node moves) | stderr | `Error: No detectable dynamic on voltages nodes or currents branches.`<br>`    PSS analysis aborted` (`E_ERR_PSS`, rendered `pss failed`) | not reached here |

**SOURCE for the two crashers.** `dcpss.c:979-996`:

```c
max_freq = pssResults [msize] ;             /* = pssResults [1 * msize + 0] */
position = 1 ;
for (j = 1 ; j < ckt->CKTharms ; j++) { ... }
...
if (pssfreqs [position] != ckt->CKTguessedFreq) {
    ckt->CKTguessedFreq = pssfreqs [position] ;
    fprintf (stdout, "The predicted fundamental frequency is incorrect.\nRelaunching the analysis...\n\n") ;
    DCpss (ckt, 1) ;                        /* recursion, no depth limit */
}
```

`pssResults` is `harms * msize` long and `pssfreqs` is `harms` long, so `harmonics <= 1`
indexes both **out of bounds** before the loop can correct `position`. `harmonics = 0`
segfaults immediately; `harmonics = 1` reads garbage, decides the answer is wrong, and
re-enters `DCpss` forever. **`harmonics >= 2` is a hard input constraint the GUI must
enforce; there is no diagnostic if it is violated.**

## 1.6 The recursive relaunch is real, and it multiplies the plot count

MEASURED: `sciter_0` produced `const pss1 pss2 pss3 pss4` — two TD/FD pairs, because
`Relaunching the analysis...` fired once. `pts_2` produced `const pss1 pss2 pss3`. So:

> **A PSS run produces 2·(1 + relaunches) plots.** The last TD plot and the last FD plot are
> the answer; the earlier pairs are abandoned attempts. Count them by `Plotname:` match and
> take the last of each, never by position and never by assuming two.

`an-rf-pss.md` design note 6 and `ase-deck.md`'s "one analysis ⇒ one plot ⇒ one `write`" are
both wrong for PSS in this stronger sense: it is not "two", it is "an even number ≥ 2 that
the GUI cannot predict". The F6 `foreach p $plots` loop handles it correctly with no change.

## 1.7 Three corrections to `an-rf-pss.md` §3

1. **The per-iteration `Shooting cycle iteration number: … || rr: … || predsum: …` line does
   NOT print.** SOURCE `dcpss.c:679-691`: it is inside `#ifdef PSSDEBUG`, and `PSSDEBUG` is
   commented out at `dcpss.c:55` (`//#define PSSDEBUG`) and defined nowhere else in the tree.
   `--enable-pss` does not define it. What *does* print per iteration, on **stdout**, is:
   ```
   In shooting...                                   (once, at iteration 0)
   Updated guessed frequency: %s Hz.
   Next shooting evaluation time is %1.10g and current time is %1.10g.
   ----------------
   ```
   That triple **is** a usable live progress feed for a PSS panel — one block per shooting
   iteration, with the current frequency estimate. It is the only PSS progress on the `-b`
   route.
2. **A bad `oscnode` does not crash.** MEASURED: `pss 2G 10n nosuchnode 1024 10 5 5e-3 uic`
   → rc 0, `Convergence reached`, identical f0. The parser's `INPtermInsertRef` creates the
   node, so `job->PSSoscNode` is never NULL. The dossier's predicted NULL deref at
   `dcpss.c:126` is unreachable from the card/command path. `oscnode` remains a **no-op** —
   the GUI must ask for it (the parser demands a token) and should say plainly that it
   steers nothing.
3. **`fguess = 0` is not a divide-by-zero.** It is a clean `E_TIMESTEP` abort with the
   message above, rc 1.

## 1.8 Cost and reliability on something bigger than a toy

MEASURED. A synthetic 19-stage ring (40 BSIM4 MOSFETs, `workpad/decks/ring19_body.inc`),
whose true oscillation frequency an FFT of a 60 ns transient puts at **6.49946e+08 Hz**
(`meas sp f0 MAX_AT bout`):

| `pss` args | wall | verdict | f0 reported | error vs FFT |
|---|---|---|---|---|
| `650e6 20n bout 1024 10 10 5e-3 uic` (guess = truth) | 8.9 s | **not reached** | 890.1 MHz | +37 % |
| `500e6 20n bout 1024 10 30 5e-3 uic` (sc_iter 30) | 24.6 s | **not reached** | 660.7 MHz | +1.7 % |
| `650e6 20n bout 256 10 10 5e-3 uic` (points 256) | 9.4 s | **not reached** | 890.1 MHz | +37 % |
| `650e6 100n bout 1024 10 10 5e-3 uic` (tstab 100 ns) | 12.1 s | **not reached** | 723.9 MHz | +11 % |

**Not one of them converged**, and the reported frequency swung 660–890 MHz depending on
arguments alone. `sc_iter` is the dominant cost knob (10 → 30 tripled the runtime) and the
only one that helped accuracy. `points` had no effect on either.

So the honest scope is narrower than "periodic steady state": **PSS in this tree reliably
solves the small autonomous oscillators it ships with, and does not reliably solve a
19-stage ring.** It is 2010-vintage code the NEWS file itself calls "still very experimental".

## 1.9 Card route vs command route, and `-r`

MEASURED, and this is a general result the plan needs beyond PSS:

| deck shape | `-b -r file.raw` writes | contents |
|---|---|---|
| `.pss <args>` as a **dot card** | **yes**, 75 353 B binary | both plots: `Time Domain …` (1025 pts) and `Frequency Domain …` (10 pts) |
| `pss <args>` as a **`.control` command** | **no file at all** | — |
| `.tran` card, no `.control` | yes | — |
| `.tran` card + `.control run` | yes | — |
| `tran` as a `.control` command | **no file at all** | — |

> **`-r` captures analyses dispatched from dot cards (with or without an explicit `run`). An
> analysis issued directly as a `.control` command produces no rawfile from `-r` — it must be
> followed by an explicit `write`.** ASE-L already emits `.control` commands plus explicit
> `write`s, so it is on the correct side of this, but the rule should be stated in the plan
> because the `.pss` card + `-r` route is the *simplest* way to get both PSS plots and it is
> the one a reader will reach for.

## 1.10 Verdict: is a PSS panel shippable, and what must its form refuse?

**Shippable, as an explicitly-experimental panel, gated on the `help pss` probe, and only if
the form is a validator.** The analysis is real, fast, and produces two well-named plots that
the existing F6 capture recipe already handles. What it lacks is any self-defence: three of
the eight parameters have values that hang or crash the simulator with no message, and the
give-up path is indistinguishable from success by exit code.

**The form must refuse, hard, before emitting anything:**

| field | refuse | why |
|---|---|---|
| `harmonics` | `< 2` | 0 → SIGSEGV; 1 → infinite recursion (§1.5) |
| `harmonics` | `> ~64` without a warning | every extra harmonic is another O(points) DFT row |
| `fguess` | `<= 0` | rc-1 `Timestep too small` abort |
| `fguess` | **above** the user's own estimate | §1.4: guessing 2.1× high aborts; guessing 19× low converged. **Bias the default low.** |
| `points` | `< 8` | 2 → zero data rows; 0 → a 1-row plot |
| `points` | not a power of two | not a hard rule, but every shipped example uses 1024/256/50 and the DFT is naive O(points·harms) |
| `sc_iter` | `> 1023` | `HISTORY` is fixed at 1024 (`dcpss.c:53`); above it `gf_history[]` overruns |
| `sc_iter` | `< 5` | 0 and 1 both gave `Convergence not reached` on a circuit that converges at 5 |
| `steady_coeff` | `< 1e-6` | 1e-9 produced a **false `Convergence reached` with a 4.5 %-wrong answer** and a stderr panic storm |
| `oscnode` | *nothing* — but label it "(not used by the solver)" | §1.7 item 2 |

**And the panel must:**
* surface `Convergence reached` / `not reached` as a first-class result state, refusing to
  render the FD plot as an answer in the "not reached" case without a banner;
* offer a one-click cross-check — a transient + `linearize` + `fft` + `meas sp … MAX_AT` —
  because that is how §1.8 caught PSS being 37 % wrong while reporting no error;
* stream the `Updated guessed frequency: … Hz.` block as live progress (§1.7 item 1);
* take the **last** TD and FD plot by `Plotname:` match, never a fixed `pss1`/`pss2` (§1.6);
* subtract the TD plot's first `time` sample before plotting a period (§1.3);
* render the FD plot as a stem/comb plot — the rawfile already says so with `plot=1`;
* state that `.options tstep/tmax/delmin` are **ignored** by PSS (`PSSinit` overwrites
  `CKTstep`, `CKTmaxStep`, `CKTdelmin`, `CKTinitTime` and `CKTmode` from `fguess`), so a
  shared "transient settings" pane must not appear to apply to it;
* carry a build-gate message: PSS needs `--enable-pss`, there is no runtime load command.

---

# PART 2 — CIDER (`--enable-cider`)

## 2.1 The `devhelp` probe works exactly as `cider-devices.md` §1.11 hoped

MEASURED, `devhelp` with no argument, two binaries, device lists diffed:

```
only in the --enable-cider build:   NBJT  NBJT2  NUMD  NUMD2  NUMOS
only in build-ver_50:               81 XSPICE code-model rows (adc_bridge, d_and, …)
```

The five numerical families appear at the **end** of the table with these exact rows:

```
NBJT                 :	1D Numerical Bipolar Junction Transistor model
NBJT2                :	2D Numerical Bipolar Junction Transistor model
NUMD                 :	1D Numerical Junction Diode model
NUMD2                :	2D Numerical Junction Diode model
NUMOS                :	2D Numerical MOS Field Effect Transistor model
```

**There is no `NDEV` row** — that name appears in the task brief but not in this tree; the
CIDER set is exactly those five.

Two cautions for the probe:
* The 81-row difference in the other direction is **not** about CIDER. It is the code models,
  which the stock binary loads from an installed `spinit` and a fresh build does not (§0).
  So **do not test "is this CIDER" by row count**; test by
  `devhelp | grep -E '^(NUMD|NBJT|NUMOS)'`, which is `spinit`-independent because those rows
  are compiled in.
* `devhelp` is a `.control` command, so the probe costs one ngspice invocation — the same one
  that already answers `help pss`, `help sp` and `echo $xspice_enabled $osdi_enabled`.

## 2.2 It runs. Costs, MEASURED, on the shipped examples

`builds/cider/src/ngspice -b`, from each example's own directory, unmodified decks:

| example | what it is | wall | notes |
|---|---|---|---|
| `diode/diode.cir` | 1D `NUMD`, 201-node mesh, `.op` + `.ac dec 10 100k 10G` | **0.10 s** | 51 AC points, `.option acct` |
| `diode/diotran.cir` | 1D `NUMD` transient | 0.2 s | |
| `bjt/pz.cir` | 1D `NBJT`, `.pz` | 0.1 s | **`Warning: Pole-zero iteration limit reached; giving up after 201 trials`** |
| `mos/nmosinv.cir` | 2D `NUMOS`, 557-node mesh, `.tran 0.2n 30n` | **1.1 s** | 178 timepoints, 10 circuit equations |
| `mos/cmosinv.cir` | two 2D `NUMOS` | 1.4 s | 305 iterations |
| `mos/ringosc.cir` | 2D `NUMOS` ring | **42.9 s** | 8128 iterations |
| `bjt/ecp.cir` | 2D `NBJT2` emitter-coupled pair | **38.1 s** | |
| `bicmos/bicmpd.cir` | BiCMOS, mixed numerical | **329.5 s** | the expensive one |

**So the cost spread is three and a half orders of magnitude, 0.1 s to 5.5 minutes, driven by
mesh size × timepoints.** A 1D device is free. A single 2D device in a short transient is a
second. Three 2D devices in an oscillator is a minute. That is exactly the shape that makes a
progress bar and a working Stop button matter (Part 3).

The `.op` output of `diode.cir` shows the CIDER-only extras `cider-devices.md` §1.4 predicted:
a `NUMD:` device section with `vd/id/g11/c11/y11`, and — under `.option acct` — per-device
`Device d1 Memory Usage` (Elements / Nodes / Edges / Equil NZ / Bias NZ / State Vector) and
`Device d1 Time Usage` (SETUP/DC/TRAN/AC columns × Setup/Load/Order/Factor/Solve/Update/Check/
Misc/LTE rows). **That is a per-device profiling table no other ngspice device produces**, and
it is free GUI material for a "why is this slow" pane.

## 2.3 Which analyses a numerical device actually participates in

MEASURED, one deck (`workpad/decks/cider_matrix.cir`) with a 51-node `NUMD` and a resistor,
running every analysis in one `.control` block:

| analysis | rc | plot produced | rows |
|---|---|---|---|
| `op` | 0 | `op1` | 1 |
| `ac dec 5 1k 1meg` | 0 | `ac1` | 16 |
| `tran 1n 20n` | 0 | `tran1` | 59 |
| `noise v(2) vin dec 5 1k 1meg` | 0 | `noise1` + `noise2` | 16 + 1 |
| `disto dec 5 1k 1meg` | 0 | `disto2` + `disto3` | 16 + 16 |
| `pz 1 0 2 0 vol pz` | 0 | `pz3` | 1 |
| `tf v(2) vin` | 0 | `tf3` | 1 |
| `sens v(2)` | 0 | `sens3` | 1 |

**Every analysis runs and none of them errors.** That is the trap, not the good news: for
`.noise` and `.disto` the numerical device's `DEVnoise`/`DEVdisto` pointers are NULL
(`cider-devices.md` §1.3), so the device contributes **exactly zero** and the plot is a
silently wrong answer, not a refusal. Same for SOA (`DEVsoaCheck` NULL). And `bjt/pz.cir`
above shows `.pz` on a numerical device failing to converge in its own shipped example.

**MEASURED, the one place CIDER does refuse — and it kills the process:**

```
.options klu   +  any CIDER device  +  ac
→ stderr: Error: CIDER NUMDadmittance small signal simulation is not (yet) supported with 'option klu'.
              Use 'option sparse' instead.
          ERROR: fatal error in ngspice, exit(1)
→ rc 1, and every command after the `ac` in the same .control block never runs.
```

This is `controlled_exit(1)` from `small_signal_check()`, so it is **not** a failed analysis,
it is a dead process. On the libngspice route it would call `ControlledExit` on the host
(§3.7). The runtime default is SPARSE, so this only fires if the GUI itself emits
`.options klu`.

## 2.4 Verdict: offer it, detect it, or ignore it?

**Detect it; do not offer it; and do not ignore it.** Three separable duties:

1. **Detect — cheap and mandatory.** The `devhelp` probe is one grep on a run ASE-L already
   makes. Cache the boolean beside the `help pss` / `help sp` answers on the same
   `ase::sim_capabilities` record. Cost: zero extra invocations.
2. **Do not offer a CIDER model editor in the analyses plan.** CIDER is a *model-authoring*
   feature — a 16-card mesh/doping/mobility sub-language inside a `.model` card. It adds **no
   new analysis, no new dot card, and no new `SPICEanalysis`**. It belongs in a model editor,
   which is out of scope for this pass. `cider-devices.md` §1.11 is right.
3. **But the analyses pane owes CIDER four behaviours**, all of them cheap, all of them
   defensive, and all of them measured above:
   * if the netlist has `.model … numd|nbjt|numos` and the probe says CIDER is absent, say
     so *before running* — ngspice's own message is
     `could not find a valid modelname`, which names neither CIDER nor the flag (MEASURED
     against `build-ver_50` on `examples/cider/diode/diode.cir`);
   * **never emit `.options klu` when a numerical device is present** (§2.3);
   * mark `.noise`, `.disto` and SOA as *silently incomplete* on a CIDER netlist, and mark
     `.pz` as *unreliable* — the shipped `bjt/pz.cir` does not converge;
   * budget for it: the run-timeout heuristic and the progress UI must tolerate a
     five-minute analysis, because `bicmpd.cir` is one.

One more operational note from `cider-devices.md` §1.10 that this build confirms is live:
CIDER's `sp_shutdown()` can call `com_quit()` interactively. **A GUI driving a CIDER-enabled
ngspice non-interactively should export `CIDER_COM_QUIT=OFF`.**

---

# PART 3 — libngspice (`--with-ngshared`)

Driver sources, all under `workpad/builds/driver/` (`drv.c`, `min.c`, `cyc.c`, `leak.c`,
`halt2.c`, `probe.c`, `crash.c`), built with:

```sh
gcc -O0 -g -I<shared>/src/include -I<shared>/src/include/ngspice \
    -I/home/analog/dev/ngspice/src/include -I/home/analog/dev/ngspice/src/include/ngspice \
    drv.c -o drv -L<shared>/src/.libs -lngspice -lpthread -lm -Wl,-rpath,<shared>/src/.libs
```

## 3.1 SendStat: a real percentage, for five analyses, and only on this transport

**The headline nobody had established: `SetAnalyse()` — the function behind `SendStat` — is
compiled only under `SHARED_MODULE`, `HAS_WINGUI` or `TCL_MODULE`.** SOURCE
`src/include/ngspice/ngspice.h:132` (inside `#ifdef HAS_WINGUI`) and `:299` (inside
`#elif defined SHARED_MODULE`), each `#define HAS_PROGREP`, and **every** `SetAnalyse` call
site in the analysis code is wrapped in `#ifdef HAS_PROGREP`.

> **A `-b` or `-p` ngspice has no progress-reporting machinery at all. It is not that the
> callback is unset — the code is not compiled.** This is the single sharpest technical
> difference between the transports and no dossier had it.

MEASURED, `drv stat`, one process, a deliberately slow RC-ladder-plus-diodes deck, one
callback per string with a wall-clock stamp:

| command | SendStat callbacks | strings seen | elapsed |
|---|---|---|---|
| `op` | **0** | — | 0.000 s |
| `tran 1u 2` | **29** | `tran: 3.5%` … `tran: 98.9%`, then `--ready--` | 4.33 s |
| `ac dec 20000 1 1meg` | 9 | `ac: 77.4%`, then `--ready--`×8 | 0.12 s |
| `dc v1 0 5 0.00002` | 3 | `dc: 27.4%`, `dc: 69.9%`, `--ready--` | 0.38 s |
| `tf v(mid) v1` | 0 | — | |
| `pz mid 0 mid 0 vol pz` | 0 | — | |
| `noise … dec 20000 …` | **0** | — | 0.22 s |
| `disto dec 5000 …` | **0** | — | 0.09 s |
| `sens v(mid)` | 0 | — | |

Confirmed against the source: the complete set of `SetAnalyse` call sites in analysis code is
`dctran.c` (`tran init`, `tran`), `dctrcurv.c` (`dc`), `acan.c` (`ac`), `span.c` (`sp`),
`optran.c` (`optran init`, `optran`), `dcpss.c` (`ptran init`, `shooting`, `ptran`),
`cktop.c` (`op`), `cktsetup.c` (`Device Setup`), `inppas2.c` (`Parse`).
**`noisean.c`, `distoan.c`, `pzan.c`, `dctf.c` and `cktsens.c` contain none.**

Format and cadence, from `sharedspice.c:1954-2115`:
* one string per callback, `"<analysis>: %3.1f%%"`, e.g. `tran: 42.8%`;
* `--ready--` at 100 %, and again for any `DecaPercent < 0`;
* `shooting` is special-cased to `"shooting: %d"` — an **iteration count, not a percentage**;
* throttled to one update per **150 ms** (`#define DELTATIME 150`) *and* suppressed when the
  string is unchanged, so a fast analysis emits one or two callbacks and a slow one emits a
  smooth ~7 Hz stream (MEASURED: 29 updates over 4.33 s);
* percent arrives as tenths of a percent internally (`int DecaPercent`), so 0.1 % resolution
  is available if you reimplement the formatting.

MEASURED caveat: `op` never produced a callback in any run, including a hard-converging deck
with two seconds of quiet either side. `cktop.c:35` does call `SetAnalyse("op", 0)`, and a
percent-0 call formats to the bare analysis name — but it did not surface. **Treat OP as
having no progress**; that is the safe and observed behaviour. The first `SetAnalyse` call of
a process is also swallowed by an initialisation quirk (`OldAn1` is seeded with the incoming
name), so `Device Setup` / `tran init` are unreliable too.

**Where the percentage comes from matters for honesty**: for `tran` it is
`CKTtime / CKTfinalTime`, for `dc` it is the sweep position, for `ac` it is
`(log f − log f_start)/(log f_stop − log f_start)`. None of them account for
non-convergence retries, so a `tran` bar can stall at 42 % for minutes. It is a position
indicator, not an ETA.

## 3.2 There is a second, transport-independent progress feed — and nobody has used it

SOURCE `outitf.c:710, 724, 821, 1844, 2005` — five sites, all the same shape:

```c
#ifndef HAS_WINGUI
        if (!orflag && !ft_norefprint && !cp_background) {
            currclock = clock();
            if ((currclock-lastclock) > (0.25*CLOCKS_PER_SEC)) {
                fprintf(stdout, " Reference value : % 12.5e\r", refValue->rValue);
                fflush(stdout);
```

MEASURED: a `tran 100n 0.2` under **plain `-b`, no `-r`** printed 7 ` Reference value : …`
records; the same under `-b -r` printed 7. It appears on the **shared** route too (it reaches
`SendChar`). It is the *current value of the scale vector* — transient time, or AC frequency —
every 0.25 s of CPU, on stdout, terminated by `\r` and **no newline**.

> **So `-b` and `-p` are not progress-blind after all.** The GUI knows `tstop`/`fstop` because
> it wrote them, so `Reference value / tstop` is a percentage it can compute itself, for
> `tran`, `dc`, `ac`, `noise`, `disto` and `sp` alike — a *wider* analysis coverage than
> `SendStat`, at a coarser 4 Hz. The parser rules: split on `\r` as well as `\n`, and expect
> the line to be overwritten in place. `set norefprint` / `.options norefvalue` kills it.

## 3.3 bg_halt: 10 ms, graceful, partial results kept — for five analyses, and it wedges on two

MEASURED, `drv halt` and `halt2`, one process, 1.5 s of run then `bg_halt`:

| background command | scale vector at halt | halt latency | `ngSpice_running()` after |
|---|---|---|---|
| `bg_tran 10n 5` | `time`, 857 309 points | **0.0101 s** | 0 |
| `bg_ac dec 2000000 1 1meg` | `frequency`, 2 007 779 | **0.0103 s** | 0 |
| `bg_dc v1 0 5 2e-7` | `v-sweep`, 491 528 | **0.0101 s** | 0 |
| `bg_noise … dec 2000000 …` | `frequency`, 886 420 | **0.0101 s** | 0 |
| **`bg_disto dec 500000 …`** | — | **1.0095 s, then `Error: Couldn't stop ngspice`** | **1 — still running** |
| `bg_pss 650e6 20n bout 1024 10 30 5e-3 uic` † | `pss1` (TD) survives | **0.0101 s** | 0 |
| **`bg_sens v(bout)`** † | — | **1.0174 s, then `Error: Couldn't stop ngspice`** | **1 — still running** |

† run against `builds/all/`'s `libngspice.so` (`--enable-pss --enable-cider --with-ngshared`),
driver `workpad/builds/driver/pssdrv.c`.

**Answer: yes, a run can be aborted gracefully and the partial results survive.** After the
halt, the vectors are complete-up-to-the-stop, readable through `ngGet_Vec_Info`, listed by
`ngSpice_AllPlots`, and writable: MEASURED, `write halt_partial.raw all` after a halt produced
a valid 77 MB rawfile from a `tran` stopped at 2.4 M points. `bg_resume` then continues the
same run (MEASURED: `time` grew 2 434 248 → 4 831 428 points, contiguous).

The 10 ms is structural, from `_thread_stop()` (`sharedspice.c:549-580`): set `ft_intrpt`,
`usleep(10000)`, poll, up to **100 times**. So the bound is 10 ms typical, **1.0 s worst
case**, and on timeout it prints `Error: Couldn't stop ngspice` and **leaves `fl_running`
TRUE** — from which point `runc()` answers every further command with
`Warning: cannot execute "…", type "bg_halt" first`. **The library is wedged and only
`ngSpice_Reset` + re-`Init` recovers it.**

**Why DISTO cannot be stopped, SOURCE.** `distoan.c:254-261`:

```c
    while(freq <= job->DstopF1+freqTol) {
/*
        if(SPfrontEnd->IFpauseTest()) {
            job->DsaveF1 = freq;
            return(E_PAUSE);
        }
	*/
```

The pause hook is **commented out**. Files with a live `IFpauseTest()`: `acan.c:243`,
`cktpzstr.c:189`, `cktsens.c:362`, `dcpss.c:1029`, `dctran.c`, `dctrcurv.c:470`,
`noisean.c:365`, `noisesp.c:246`, `span.c:656`. Files with **none at all**: `pzan.c`,
`dcop.c`, `dctf.c`, `optran.c`.

**And a live hook is not the same as an interruptible analysis.** MEASURED: `sens` also fails
to halt (1.0174 s, `Couldn't stop ngspice`). SOURCE `cktsens.c:357-366` — the check sits in
the **frequency** loop, once per frequency point. A DC sensitivity has one "frequency", so the
expensive part — the per-parameter loop at `cktsens.c:380-401`, which does a full
`CKTunsetup → CKTsetup → CKTtemp → CKTload` for *every* perturbed parameter — never reaches
another checkpoint. On a 40-MOSFET circuit that is minutes with no exit.

> **GUI rule: a Stop button must never be offered as graceful during `disto` or `sens`, and
> the host must treat a `bg_halt` that returns after ~1 s with `Couldn't stop ngspice` as a
> fatal library state requiring teardown. Measured-safe to halt: `tran`, `ac`, `dc`, `noise`,
> `pss`. Measured-unsafe: `disto`, `sens`. Untested but hookless in source: `pz`, `tf`, `op`,
> `optran`.**

## 3.4 Reading vectors while a run is in progress: yes, with two sharp edges

MEASURED, `drv live`, polling every 400 ms during `bg_tran 10n 5`:

```
[  0.401] LIVE running=1 time.len=465946
[  0.801] LIVE running=1 time.len=968689
[  1.201] LIVE running=1 time.len=1470001
[  1.601] LIVE running=1 time.len=1942012
...
```

The vector grows under the reader and the data is current. `ngSpice_LockRealloc()` /
`ngSpice_UnlockRealloc()` bracket the read and exist precisely for this.

**Edge 1 — `ngGet_Vec_Info` returns a singleton.** SOURCE `sharedspice.c:1194-1240`: the
function fills a single static `myvec` and returns a pointer to it. MEASURED: calling it for
`time` and then for `V(mid)` inside one lock and holding both pointers gave the **same**
values for both, because the second call overwrote the first. **Copy `v_length`,
`v_realdata`/`v_compdata` and `v_flags` out before the next call.**

**Edge 2 — real vs complex.** MEASURED: for a `tran` vector `v_flags = 129`, `v_realdata`
non-NULL, `v_compdata` NULL. For an `ac` vector `v_flags = 130`, `v_realdata` **NULL**,
`v_compdata` non-NULL. Dereferencing `v_realdata` on an AC vector segfaults the host — it did,
here, twice, before I gated on the flag. `VF_COMPLEX` is bit 1.

## 3.5 `ngSpice_Reset`: it is a **teardown**, not a "next circuit" call — and it will crash you

This is the `CLAUDE.md` recurring-bug-class question, and the answer is sharper than "does
state survive".

**MEASURED, minimal reproducer (`workpad/builds/driver/min.c`), four lines of host code:**

```c
ngSpice_Init(...);
ngSpice_Circ(deck);
ngSpice_Reset();
ngSpice_Circ(deck);      /* <-- SIGSEGV, rc 139 */
```

gdb backtrace:

```
#0  CKTmodCrt ()      #1  INP2V ()        #2  INPpas2 ()     #3  if_inpdeck ()
#4  inp_dodeck ()     #5  inp_spsource () #6  create_circbyline ()  #7  ngSpice_Circ ()
```

It crashes with or without an intervening analysis. **SOURCE, the cause is a missing guard,
not a state bug.** `totalreset()` (`sharedspice.c:2552`) sets `is_initialized = FALSE`, then
calls `com_remcirc`, `cp_destroy_keywords`, `destroy_ivars`, `destroy_const_plot`,
**`spice_destroy_devices()`**, `unset_all`, and destroys all four mutexes. It never
re-initialises anything. `CKTmodCrt` then dereferences `DEVices[type]->DEVmodSize` on a
destroyed device table.

And `ngSpice_Command` guards itself — `sharedspice.c:1140`, `if (!is_initialized) return 1;` —
while **`ngSpice_Circ` has no such check** (`sharedspice.c:1247-1265`, the body starts at
`setjmp`). So after a Reset, sending a command is a clean no-op returning 1, and sending a
circuit is a segfault. That asymmetry is the defect.

> **The contract, which the header's one line "Reset ngspice as far as possible" does not
> state: `ngSpice_Reset()` must be followed by `ngSpice_Init()` before any further
> `ngSpice_Circ()`.** Worth an upstream one-liner (`if (!is_initialized) return 1;` at the top
> of `ngSpice_Circ`) in the `doc/codex/issues/` style, and worth a defensive wrapper in any
> host.

**With the correct `Reset` + re-`Init` cycle, state does not leak, and the numbers are
identical to fresh processes.** MEASURED, `cyc.c`, one process doing
tran → Reset+Init → ac → Reset+Init → tran, against three separate processes:

| pass | in-process cycle | fresh process | identical? |
|---|---|---|---|
| P1 `tran 1u 5m` **with** `option reltol=1e-5` + `set sqrnoise` | `time` len **5185**, last 0.005 | 5185 | ✔ |
| P2 `ac dec 10 1 1meg` | `frequency` len 61, `mid[3] = (0.908972843, −0.01035948322)` | bit-identical | ✔ |
| P3 `tran 1u 5m` **with no option lines** | `time` len **5175** | 5175 | ✔ |

P1 vs P3 differing by ten timepoints is the proof that `reltol=1e-5` really was in force in
P1 and really was gone in P3. **No option, no `set` variable and no plot survived the
teardown.**

**The subtler and more useful result is what happens *without* a Reset.** MEASURED (`leak.c`),
one `ngSpice_Init`, three `ngSpice_Circ` calls:

| step | `tran 1u 5m` length |
|---|---|
| A: circuit #1, no options | **5175** |
| B: same circuit, after `option reltol=1e-5` | **5185** |
| C: **new** `ngSpice_Circ`, no options re-issued | **5175** |

…while `set sqrnoise` **did** survive into the next circuit (`$sqrnoise = TRUE` after the
second `ngSpice_Circ`).

> **The rule a GUI must encode: `option …` is per-circuit and is wiped by the next
> `ngSpice_Circ`; `set …` is process-global and is not.** That is the same `ci_vars` vs
> global-variable-list split `hidden-vars.md` §1.5 describes for the batch route, and it holds
> identically here. It means a host can drive many analyses off one loaded circuit safely, and
> must re-emit its `.options` every time it re-sends a netlist.

## 3.6 The F15 pre-deck options: the shared route has **one door**, and it is better than all three

`hidden-vars.md` §3.3's ordering rule says the 26 load-time variables need `-D` (CP_BOOL /
CP_STRING only), a `.spiceinit` on disk (CP_NUM / CP_REAL / CP_LIST), or `set` before `source`
in pipe mode. On the libngspice route there is no command line to put `-D` on. **There does
not need to be.**

MEASURED, `leak.c`, three-way comparison on one deck
(`V1 In 0 dc 10 / R1 In 0 rmod 1k / .model rmod r bv_max=1`):

| delivery | `$curcasemode` after read | `ngbehavior` | `warn=1` SOA check |
|---|---|---|---|
| `ngSpice_Command("set casemode=preserve")` etc. **before** `ngSpice_Circ` | **`preserve`** | `Note: Compatibility modes selected: hs` | fires — `Instance: R1 Model: rmod \|Vr\|=10 has exceeded Bv_max=1` (**case preserved**) |
| nothing | `fold` | `Note: No compatibility mode selected!` | — |
| the same three as `.options …` **inside the deck** | `fold` ✗ | `No compatibility mode selected!` ✗ | fires — `Instance: r1 …` (case folded) |

That reproduces F15's boundary exactly (`casemode`/`ngbehavior` are pre-deck, `warn` is
post-deck) and settles the delivery question:

> **On the libngspice route, `ngSpice_Command("set <name>=<value>")` issued before
> `ngSpice_Circ()` reaches every one of the 26 load-time variables, regardless of `CP_` type.**
> No `-D`, no `.spiceinit` file, no temp directory. The three-door complication of
> `hidden-vars.md` §3.3 and its four silent-failure traps (`-D name=1` killing a CP_BOOL,
> a bare `set` killing a CP_NUM, `-D` always producing a string) **collapse to nothing** on
> this transport. The GUI still needs the per-variable `CP_` type table for validation, but
> not for routing.

Also relevant: `ngSpice_nospinit()` and `ngSpice_nospiceinit()` exist as API calls, to be made
before `ngSpice_Init`, so the host can guarantee a clean variable environment — something the
`-b` route can only approximate with `--no-spiceinit`.

## 3.7 The cost nobody costed: an ngspice crash is now **your** crash

MEASURED, `crash.c` — the F7 `.disto` NULL-dereference, driven through libngspice:

```c
ngSpice_Circ(deck);                                   /* v1 in 0 dc 1 ac 1 distof1 1 0 ... */
ngSpice_Command("save v(nosuchnode)");
ngSpice_Command("disto dec 2 1k 10k");                /* <-- host process dies here */
```

→ **host rc 139.** The `ControlledExit` callback is never reached — this is a raw SIGSEGV
inside `DISTOan`, in the host's address space.

SOURCE, why no handler saves you: `ngSpice_Init` installs a SIGSEGV handler at
`sharedspice.c:914` and **restores the caller's at `:1052`, before returning**. The handler
exists only to survive a bad `spinit`/`.spiceinit`. During simulation there is no protection.

The same applies to every hard exit in the simulator: CIDER + KLU + AC (§2.3) reaches
`controlled_exit(1)`, which in the shared build calls `shared_exit` → the `ControlledExit`
callback → and the host is then obliged to tear down. And `harmonics = 0` PSS (§1.5) would be
another SIGSEGV in-process.

> **This is the decisive asymmetry.** On `-b` and `-p`, ngspice crashes are contained in a
> child process: the GUI sees rc 139 and shows an error. Linked in, the same three measured
> crashes — `.disto` with an empty save scope, `sens … ac` under KLU (critique D3), PSS with
> `harmonics < 2` — **take the editor down with the user's unsaved schematic.**

## 3.8 What the probe actually costs on each route

MEASURED, five capability questions (`help pss`, `help sp`, `help hb`, `devhelp`,
`echo $xspice_enabled $osdi_enabled`), three repeats each:

| route | cost |
|---|---|
| in-process (`ngSpice_Init` + 5 `ngSpice_Command`) | init **0.4–0.7 ms**, commands **0.1 ms**, total **≤ 0.8 ms** |
| spawned `ngspice -b probe.cir` | **< 5 ms** wall (below `/usr/bin/time`'s resolution) |

> **Honest conclusion: the probe cost is not an argument for either transport.** Both are
> single-digit milliseconds. F4's standing costs (issues 0953/0958/0959 — the probe paid
> inside the user's Run gesture, on every press) are ASE-L's own scheduling, not ngspice's
> speed, and linking the library would not fix them.

## 3.9 PSS + CIDER + shared together

`builds/all/` = `--enable-pss --enable-cider --with-ngshared`. **Builds clean** in ~110 s,
`config.h` carries `#define CIDER 1`, `#define WITH_PSS` and `#define SHARED_MODULE 1`
simultaneously, and MEASURED one process answered `help pss` **and** listed the `NUMD`/`NBJT`
rows from `devhelp` **and** reported `SendStat` progress. The three flags are orthogonal.

**PSS progress on the shared route, MEASURED** (`workpad/builds/driver/pssdrv.c`, 3-stage ring):

```
[ 0.199] | stdout In shooting...
[ 0.199] | stdout Updated guessed frequency: 2.374311624e9 Hz.
[ 0.199] STAT shooting: 1
[ 0.380] STAT shooting: 2
[ 0.564] STAT shooting: 3
[ 0.741] | stdout Convergence reached. … predicted fundamental frequency is 3.758894068e9 Hz
[ 0.741] STAT ptran: 97.7%
stat callbacks = 4
plots: pss2 pss1 const
```

and on the 19-stage ring, where the stabilization phase is long enough to see:

```
[ 0.153] STAT ptran: 88.8%     <- stabilization, % of the *then-current* CKTfinalTime
[ 0.315] STAT ptran: 92.3%
[ 0.776] STAT shooting: 1
[ 1.503] STAT shooting: 2   …  [ 3.603] STAT shooting: 5
```

Two things a PSS panel must know about this feed:
* **`ptran: NN%` is not monotone and not meaningful.** `CKTfinalTime` is rewritten at every
  phase change (`dcpss.c:487`), so the percentage jumps to ~90 %, resets, and jumps again.
  Show it as a phase label, never as a bar.
* **`shooting: N` is the honest progress signal** — one callback per shooting iteration, and
  the panel already knows the ceiling because the user typed `sc_iter`. `N / sc_iter` is the
  only real PSS progress fraction available anywhere.

Also MEASURED here: `ngSpice_AllPlots()` returns **newest first** (`pss2 pss1 const`), which
is the opposite of the rawfile write order.

So the answer to "can a GUI have PSS *and* the progress-and-abort story" is **yes, from one
build** — and it matters, because `dcpss.c:1049-1055` is the only place `shooting` and `ptran`
progress exist and they are `#ifdef HAS_PROGREP`. **PSS progress reporting exists only on the
shared/GUI transport.** On `-b`, a PSS panel's only progress feed is the stdout
`Updated guessed frequency:` block (§1.7) — which, as the trace above shows, arrives on the
shared route too, at the same instants, so the `-p` arm loses only the `shooting: N` counter
it can derive from that block anyway.

**And `bg_halt` during PSS works**: MEASURED **0.0101 s**, `ngSpice_running()` → 0, and the
partly-filled time-domain plot `pss1` survives in the plot list.

---

# PART 4 — the costed transport verdict

Three arms: spawn `ngspice -b`, spawn `ngspice -p` and drive it over pipes, or link
`libngspice`. ASE-L runs `-b` today.

## 4.1 The comparison table, every row measured here

| capability | `-b` (today) | `-p` pipe | `libngspice` |
|---|---|---|---|
| **Per-analysis % progress** (`SendStat`) | **none — not compiled** (§3.1) | **none — not compiled** | **yes**: tran / dc / ac / sp / optran, ~7 Hz, `"tran: 42.8%"`; pss reports `shooting: N` + a non-monotone `ptran: NN%` (§3.9) |
| Coarse progress (` Reference value : %e\r`) | **yes**, 4 Hz, stdout (§3.2) | **yes**, 4 Hz | yes, via `SendChar` |
| Progress for noise / disto / pz / tf / sens / op | none anywhere | none | **none** — no `SetAnalyse` call sites exist |
| **Graceful abort** | **no.** SIGINT → rc 130, nothing written (F9/D4) | **yes.** SIGINT latency **< 5 ms**, `Interrupted once . . .` / `doAnalyses: pause requested`, partial vectors intact (MEASURED: 3 104 161 points, 388 MB rawfile written after the stop) | **yes.** `bg_halt` **10.1 ms** typical, **1.0 s** worst; partial vectors intact |
| Abort during `disto` / `sens` | n/a (kill) | untested; the same missing/misplaced hooks apply | **fails**: ~1.0 s then `Couldn't stop ngspice`, library wedged (§3.3) |
| Abort during `pss` | n/a (kill) | untested | **yes**, 10.1 ms, partial TD plot kept (§3.9) |
| **Resume after abort** | no | **yes** — `resume` (MEASURED: 3.10 M → 5.15 M points) | **yes** — `bg_resume` (MEASURED: 2.43 M → 4.83 M) |
| **Read vectors mid-run** | no | only via a `write` after a pause | **yes**, live, growing, `LockRealloc`-bracketed (§3.4) |
| Results transport | rawfile on disk | rawfile on disk | in-memory `ngGet_Vec_Info`, or rawfile |
| **Pre-deck options (F15's 26)** | `-D` (BOOL/STRING only) **+** a written `.spiceinit` (NUM/REAL/LIST) — 4 silent-failure traps | `set` before `source` — one door | **`set` before `ngSpice_Circ` — one door, all types** (§3.6) |
| **An ngspice crash costs** | a child process; rc 139 reported | a child process; rc 139 reported | **the GUI process** (§3.7) — MEASURED on F7's `.disto` |
| A `controlled_exit` (CIDER+KLU) costs | a child process | a child process | a `ControlledExit` callback + mandatory teardown |
| Reset between runs | new process; perfectly clean | `reset` / new process | `ngSpice_Reset` + **mandatory re-`Init`**, else SIGSEGV (§3.5) |
| Option/`set` leakage between runs | impossible | possible; `reset` needed | `option` per-circuit, `set` global (§3.5) |
| Multiple simultaneous runs (corners, MC) | trivial — N processes, N cores | trivial | **one circuit per process**; N requires N host processes or N `dlopen`ed copies |
| Capability probe cost | < 5 ms | < 5 ms | ≤ 0.8 ms (§3.8) |
| Build/deploy burden on the user | **none** — any installed ngspice | **none** | needs `--with-ngshared`, which **does not build an `ngspice` binary**; plus `SPICE_LIB_DIR` for code models (§0) |
| ASE-L code change | none | moderate: an async pipe reader, prompt-boundary parsing, signal delivery | large: FFI from Tcl to a C shared library, callbacks into the Tcl event loop, thread-safety across `SendChar`/`SendStat`/`SendData` |

## 4.2 The case FOR linking libngspice

* It is the **only** route with a real per-analysis percentage, and the only route with any
  PSS progress at all (§3.1, §3.9). For a `bicmpd.cir`-class CIDER run at 5.5 minutes or a
  19-stage PSS at 25 s, that is the difference between a UI that feels alive and one that
  looks hung.
* **Live vector reading** (§3.4) enables a genuine `iplot`-class "watch the waveform build"
  pane, which F14 lists as beyond-ADE material and which neither spawn route can offer.
* **Pre-deck options collapse to one mechanism** (§3.6). No `.spiceinit` written into the run
  directory, no `-D` type table for routing, none of `hidden-vars.md`'s four silent-failure
  traps. That is a real reduction in the plan's surface area.
* Results arrive **in memory**, so a large sweep does not round-trip through a 400 MB rawfile.
* It is the route the ngspice maintainers themselves treat as the GUI API — `sharedspice.h` is
  the documented public C API and `CLAUDE.md` names it as a first-class link target.

## 4.3 The case AGAINST, and FOR `-p` as the middle road

* **A crash in ngspice becomes a crash in the schematic editor** (§3.7), MEASURED on a bug
  (F7) that is four lines to reproduce and that ASE-L's own deck shape reaches. There is no
  handler; the SIGSEGV handler is uninstalled before `ngSpice_Init` returns. Two more measured
  crashers (`sens … ac` under KLU, PSS `harmonics<2`) are in the same class. Process isolation
  is not a nicety here; it is the thing standing between a simulator bug and data loss.
* **`ngSpice_Reset` segfaults if you use it the obvious way** (§3.5). The API's own lifecycle
  has an undocumented mandatory re-`Init` and a missing guard. That is exactly the class of
  bug `CLAUDE.md` warns about, confirmed live.
* **`bg_halt` can wedge the library** (§3.3) — one unstoppable `disto` and the host must tear
  down and re-`Init`, which on this API means losing every plot.
* **One circuit per process.** Corners, Monte Carlo and multi-corner sweeps (F10, which the
  GUI must generate itself anyway) parallelise trivially across spawned processes and not at
  all inside one library instance.
* **Deployment.** `--with-ngshared` produces no `ngspice` binary, so a user who has ngspice
  installed does not have `libngspice.so`; the GUI would have to ship one, pin its ABI
  (`libngspice.so.0`), and set `SPICE_LIB_DIR` (§0). The `-b`/`-p` arms work against whatever
  ngspice the user already has — which is also what `ase::sim_capabilities` is built to
  discover.
* **Tcl↔C FFI cost.** ASE-L is ~19 400 lines of pure Tcl. Linking means a C shim, callbacks
  crossing into the Tcl event loop from a background thread, and a new build dependency in a
  project that currently has none.

**And `-p` buys most of the benefit for a fraction of the cost.** MEASURED against the
**stock** `build-ver_50` binary, no rebuild:

* SIGINT latency **under 5 ms** — indistinguishable from `bg_halt`'s 10 ms;
* partial results fully intact: `length(time) = 3 104 161` after the stop, and a `write … all`
  produced a valid 388 MB rawfile;
* `resume` continued the same run to 5 147 380 points;
* `quit` exited **rc 0**;
* the ` Reference value : %e\r` ticker gives 4 Hz progress for *more* analyses than `SendStat`
  covers (§3.2), and the GUI already knows the endpoint, so it can compute the percentage;
* `set` before `source` is the single pre-deck-option door, same as the shared route;
* crashes stay in the child.

The things `-p` cannot do, honestly: no live in-memory vector reads (you get a pause plus a
`write`), no sub-percent progress for `tran`, and it needs an asynchronous reader that parses
the `ngspice N -> ` prompt to know when a command finished.

## 4.4 The verdict, stated as the fork it is

> **Recommendation: move `-b` → `-p` now; treat `libngspice` as a later, optional
> high-fidelity back end behind the same internal interface, not as the next step.**

The reasoning, in one line each:

1. `-p` closes the *only* capability gap that is actually blocking the plan — **graceful
   abort with partial results** (F9/D4) — at a cost of one async reader, against **any**
   ngspice the user already has, with **zero** new deployment burden. MEASURED end to end here.
2. `-b`'s progress blindness turns out to be false: the ` Reference value ` ticker already
   exists in `-b` and `-p` and covers more analyses than `SendStat` does. The percentage the
   GUI wants is `refvalue / tstop`, and the GUI wrote `tstop`.
3. The genuinely exclusive libngspice wins are **live mid-run vector reads** and **true
   per-analysis percentages including PSS**. Both are real; neither is on the critical path
   for "make every analysis reachable", which is this pass's stated goal.
4. The libngspice risk is not theoretical or stylistic: three separate crashes measured in
   this very session (§3.7) would each have killed the editor, and one of them (`.disto`) is
   reachable from ASE-L's existing deck shape today.
5. Whichever is chosen, the plan should define **one internal run interface** — start,
   progress event, abort, results-located — with `-p` as the first implementation. That keeps
   the libngspice option open for the day someone wants `iplot`, and keeps `-b` available as
   the parallel-corners work-horse, since corners want N processes anyway.

**If the user prefers the libngspice arm anyway**, the plan must budget four specific
mitigations, all of them measured requirements and not speculation: (a) a supervisor that
treats host death as a recoverable simulator crash — i.e. run libngspice in a small helper
process, at which point most of the isolation argument returns and the FFI complexity remains;
(b) a strict `Reset`-then-`Init` wrapper (§3.5); (c) a `bg_halt` watchdog that tears down on
`Couldn't stop ngspice` (§3.3); (d) a hard block on `disto` and `sens` while a Stop button is offered (§3.3).

---

# PART 5 — corrections and additions to earlier dossiers

Numbered so the plan can cite them.

1. **`an-rf-pss.md` §3.5**: the `Shooting cycle iteration number: …` stderr line is behind
   `#ifdef PSSDEBUG`, commented out at `dcpss.c:55`, and **never prints**. The real
   per-iteration feed is the stdout `Updated guessed frequency:` triple. (§1.7)
2. **`an-rf-pss.md` §3.4 / table in §3.5**: a bad `oscnode` does **not** NULL-deref; it runs
   normally. (§1.7)
3. **`an-rf-pss.md` §3.2**: `fguess = 0` is not a divide-by-zero at `pssinit.c:153`; it is a
   clean `Timestep too small` abort, rc 1. (§1.5)
4. **`an-rf-pss.md` §3.6 / `ase-deck.md` §7.4**: "PSS produces two plots" is too weak. It
   produces 2·(1 + relaunches); MEASURED 4 with `sc_iter 0`. (§1.6)
5. **New, PSS**: `harmonics < 2` is undefined behaviour — 0 segfaults silently, 1 hangs
   forever. `steady_coeff` below ~1e-6 produces a **false** `Convergence reached` with a wrong
   frequency. `points < 8` produces empty or 1-row plots. All silent. (§1.4, §1.5)
6. **New, PSS**: the TD plot's time axis is absolute circuit time, offset by
   `tstab` + shooting, not 0…T. (§1.3)
7. **New, PSS**: the FD plot's rawfile variable lines carry `plot=1`, a comb/stem rendering
   hint no other analysis emits. (§1.3)
8. **New, general**: `-b -r file.raw` writes a rawfile for **dot-card** analyses only; an
   analysis issued as a `.control` command yields no file. (§1.9)
9. **New, general, and the biggest one**: `SetAnalyse` — and therefore all progress
   reporting — is compiled only under `SHARED_MODULE` / `HAS_WINGUI` / `TCL_MODULE`. `-b` and
   `-p` have no `SendStat` machinery at all. (§3.1)
10. **New, general**: the ` Reference value : % 12.5e\r` ticker (`outitf.c`, five sites) is a
    4 Hz scale-value progress feed present on **every** transport, killed by
    `set norefprint` / `.options norefvalue`. (§3.2)
11. **New, libngspice**: `ngSpice_Circ()` after `ngSpice_Reset()` segfaults, because
    `ngSpice_Circ` lacks the `is_initialized` guard that `ngSpice_Command` has. Reset must be
    followed by re-`Init`. (§3.5)
12. **New, libngspice**: `ngGet_Vec_Info` returns a pointer to one shared static struct;
    consecutive calls clobber each other. `v_realdata` is NULL for complex vectors. (§3.4)
13. **New, libngspice**: `option …` is wiped by the next `ngSpice_Circ`; `set …` is not.
    (§3.5)
14. **New, libngspice, closes `hidden-vars.md` §3.3 for this transport**:
    `ngSpice_Command("set x=y")` before `ngSpice_Circ` reaches all 26 load-time variables of
    every `CP_` type. (§3.6)
15. **New, F7 escalation**: the `.disto` SIGSEGV kills the *host* on the libngspice route.
    (§3.7)
16. **New, general**: `.disto` has no working `IFpauseTest` (it is commented out) and `.sens`
    checks only once per frequency point, so a DC sensitivity is effectively uninterruptible
    too. Both wedge the shared library on a failed `bg_halt`. `pzan.c`, `dcop.c`, `dctf.c` and
    `optran.c` have no pause hook at all. Measured-safe to halt: `tran`, `ac`, `dc`, `noise`,
    `pss`. (§3.3, §3.9)
17. **New, CIDER**: `devhelp`'s row count is not a CIDER test — a non-installed build lacks
    `spinit` and loses 81 code-model rows. Grep for `^(NUMD|NBJT|NUMOS)`. (§2.1)
18. **New, CIDER**: `bjt/pz.cir`, a shipped example, fails to converge —
    `Warning: Pole-zero iteration limit reached; giving up after 201 trials`. Mark `.pz` on
    numerical devices as unreliable, not merely supported. (§2.2)
19. **New, operational**: `SPICE_LIB_DIR=<dir>` with `<dir>/scripts/spinit` and rewritten
    `codemodel` paths makes a non-installed build fully functional (133 devices). (§0)
20. **New, PSS + shared**: `SendStat` reports `shooting: N` once per shooting iteration —
    the only genuine PSS progress fraction, since the panel knows `sc_iter` — while
    `ptran: NN%` is non-monotone because `CKTfinalTime` is rewritten at each phase change.
    (§3.9)
21. **New, libngspice**: `ngSpice_AllPlots()` returns plots **newest first**, the reverse of
    the rawfile write order. (§3.9)

---

# PART 6 — artifact inventory

Everything durable, under `/home/analog/.claude/projects/-home-analog-dev-ngspice/workpad/`:

```
builds/pss/          --enable-pss                          src/ngspice
builds/cider/        --enable-cider                        src/ngspice
builds/shared/       --with-ngshared --enable-xspice       src/.libs/libngspice.so.0.0.15
builds/all/          --enable-pss --enable-cider --with-ngshared
builds/driver/       drv.c min.c cyc.c leak.c halt2.c probe.c crash.c pssdrv.c  + binaries + logs
libdir/              scripts/spinit + *.cm, for SPICE_LIB_DIR
decks/               ring_body.inc vdp_body.inc ring19_body.inc
                     ring_pss.cir vdp_pss.cir ring_card.cir ring_r.cir ring_only.cir vdp_only.cir
                     ring19.cir r19_{good,low_sc30,pts256,tstab100n}.cir
                     p_{base,fg_half,fg_double,fg_100x,tstab_tiny,tstab_zero,pts_2,pts_0,
                        harm_1,harm_0,sciter_1,sciter_0,sc_tight,fg_zero,badnode,nouic}.cir
                     cider_matrix.cir cider_klu.cir rc_ctrl.cir rc_card.cir rc_run.cir
                     tick.cir pipe_long.cir
out/                 ring_pss.{raw,stdout,stderr} vdp_pss.* card.raw ring19.*
                     pssfail/*.out *.err        (the 16-case perturbation matrix)
                     cider/*.out *.err          (diode, nmosinv, cmosinv, ringosc, ecp, pz,
                                                 diotran, bicmpd, matrix, klu)
                     pipetest.py pipe_partial.raw
```

Reproduce any build with:
```sh
mkdir -p <dir> && cd <dir> && /home/analog/dev/ngspice/configure <flags> && make -j8
```

---

# PART 7 — what I did not close

1. **PSS on a driven (non-autonomous) circuit.** Every shipped example and every deck I built
   is a free-running oscillator. `an-rf-pss.md` §3.7 argues from source that there is no
   driven-PSS mode; I did not falsify that, but I also did not test a driven circuit, so
   "PSS refuses/misbehaves on a driven circuit" remains a source claim.
2. **Why `op` never emits a `SendStat` callback** (§3.1). The call site exists and its guard
   should pass. I established the *behaviour* across many runs but not the mechanism. It does
   not change the plan (treat OP as progress-free) but it is an untied thread.
3. **`bg_halt` during `sp` and `pz`.** PSS (halts, 10 ms) and `sens` (does not halt) are now
   measured (§3.3, §3.9). `span.c:656` and `cktpzstr.c:189` have live hooks and I did not
   exercise either; `pzan.c` has none, so a `pz` whose inner strategy loop is not reached is
   likely uninterruptible like `sens`.
4. **`-p` abort for analyses other than `tran`.** I measured SIGINT on a transient only. The
   `distoan.c` commented-out hook means `-p` almost certainly cannot interrupt `disto` either,
   but I did not run it.
5. **The `SendData` / `SendInitData` per-timepoint callbacks.** I registered them and returned
   0; I never exercised them. They are the mechanism behind a true streaming plot and the
   plan should not assume anything about their cost or their behaviour under `bg_halt`.
6. **CIDER's `output …` device-state dump and `devload`/`devaxis`** (`cider-devices.md`
   §1.4.2, §1.10). The build ships `src/ciderinit`, `src/devload`, `src/devaxis`; I confirmed
   they exist but never ran the dump-and-plot loop.
7. **PSS on the shared route is now measured** (§3.9) — this item is closed. What remains
   open is whether the `Relaunching the analysis...` recursion (§1.6) produces a clean plot
   sequence through `SendInitData`/`SendData` rather than through the rawfile; I only observed
   it via `ngSpice_AllPlots`.
8. **The `.spiceinit` interaction on the shared route.** `ngSpice_nospiceinit()` exists and I
   confirmed it is called before `ngSpice_Init`, but I never wrote a `.spiceinit` and checked
   which of the F15 variables it beats or loses to when a `set` is also issued before
   `ngSpice_Circ`. The `set` door works (§3.6); the precedence order is untested.
