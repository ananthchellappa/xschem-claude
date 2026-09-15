# Dossier: transient noise (`trnoise`) and random sources (`trrandom`)

Closes critique hole §1.1 — the second stochastic-source surface that no other dossier covers.

Source tree `/home/analog/dev/ngspice`, branch `ver_50`, `git describe = ngspice-46-419-gccebdf2a2`.
Every path below is relative to that tree. Binary for every empirical claim:
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (`ngspice-46+`, KLU, `HAVE_LIBFFTW3` **defined**,
`build-ver_50/src/include/ngspice/config.h:168`).
Scratch decks: `/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/trn/`.
Neither repository was modified.

**MEASURED** marks something run in this session. **SOURCE** marks something read in this tree.

---

## 0. Headline for the plan

`trnoise` and `trrandom` are **not** analyses and **not** dot-cards. They are two ordinary
`IF_REALVEC` *instance parameters* on `VSRC` and `ISRC` — the same slot that holds `pulse`,
`sin`, `pwl`. They turn a source into a stochastic stimulus **inside a transient run**, and they
are invisible to every other analysis. Six facts that drive the whole design:

1. **The manual is wrong about current sources.** Manual §11.3.11's "isrc is not yet available"
   does not hold here: `ISRCpTable` carries the identical pair (`src/spicelib/devices/isrc/isrc.c:26-27`)
   and both work — MEASURED on `i1 0 n1 dc 0 trnoise(0 0 0 0 5m 18u 30u)`, mean 3.06 V across 1 kΩ.
   That matters more than it sounds: **a parallel current source is the only way a GUI can inject
   noise into an existing net without editing the schematic's topology** (§10.2).
2. **`src/ngspice.txt` mentions neither word** — `grep -c` returns 0. There is no `help trnoise`.
   The only in-tree documentation is the parameter table itself and the comment blocks in
   `vsrcload.c:377-384` / `vsrcacct.c:226-231`.
3. **`TS` — not `tstep` — sets the transient timestep.** Each source with `TS > 0` posts a
   breakpoint every `TS` (`vsrcacct.c:250-258`). MEASURED: point count ≈ `max(tstop/tstep, 5·tstop/TS)`,
   independent of the requested `tstep`. A "noise timestep" spinner is a **cost** control, not an
   accuracy control, and the GUI must say so.
4. **White and 1/f noise are irreproducible run to run, and no seed fixes them.** They come from
   the Wallace pool, which `initw()` seeds from `getpid()` (`src/frontend/trannoise/wallace.c:83`),
   once, before the deck is read. `setseed`, `set rndseed`, `.option seed=` do **not** reach it.
   RTS and `trrandom` *are* seed-reproducible. MEASURED both ways (§4).
5. **One source carries exactly one transient function.** `sin(...) trnoise(...)` on one line
   silently keeps only the last one. Adding noise to a stimulus source is not possible; you need a
   second source (§9-T5).
6. **`notrnoise` does not kill everything it looks like it kills** (§5.4): it kills white and 1/f
   always, RTS only when the same source also has `TS > 0`, and `trrandom` never.

---

## 1. Where it lives, and the grammar the parser actually accepts

### 1.1 The two parameters

```
SOURCE  src/spicelib/devices/vsrc/vsrc.c:24-25
 IOP ("trnoise",  VSRC_TRNOISE,  IF_REALVEC, "Transient noise description"),
 IOP ("trrandom", VSRC_TRRANDOM, IF_REALVEC, "random source description"),
SOURCE  src/spicelib/devices/isrc/isrc.c:26-27   -- byte-identical pair on ISRC
```

`IOP` = settable **and** askable. Consequences a GUI can rely on:

| capability | anchor | MEASURED |
|---|---|---|
| set from the netlist | `INPdevParse` → `find_instance_parameter` (`src/spicelib/parser/inpdpar.c:23-32`) | yes |
| set at runtime | `alter <inst> trnoise = [ ... ]` **and** `alter @<inst>[trnoise] = [ ... ]` | yes, both |
| read back | `print @<inst>[trnoise]`, `print @<inst>[coeffs]`, `show <inst> : trnoise` | yes, full vector |
| identify which function a source carries | `print @<inst>[function]` → `7` = TRNOISE, `8` = TRRANDOM | yes |

The `function` enum is `src/spicelib/devices/vsrc/vsrcdefs.h:148-160`:
`PULSE=1, SINE=2, EXP=3, SFFM=4, PWL=5, AM=6, TRNOISE=7, TRRANDOM=8, EXTERNAL=9, SOUND=10 [, PORT=11]`.
Asking for the *wrong* function name returns an empty vector (`vsrcask.c:80-95`), so
`@d[trnoise]`/`@d[trrandom]` is itself a clean probe. `@<inst>[order]` returns `0` and is useless.

> **This is the one corner of the analysis surface where F12 does not apply.** Analysis jobs cannot
> be read back; these source parameters can, and `alter` writes them live. The GUI should still own
> the authoritative copy, but it may use the readback as a post-run assertion.

### 1.2 Grammar — MEASURED, twelve variants

`INPgetValue`'s `IF_REALVEC` arm (`src/spicelib/parser/inpgval.c:36-61`) reads numbers until one
fails to evaluate, so the parentheses are decoration.

| written as | accepted | note |
|---|---|---|
| `trnoise(1m 1u 0 0)` | ✅ | canonical |
| `TRNOISE(1M 1U 0 0)` | ✅ | keyword and suffixes are case-insensitive |
| `trnoise (1m 1u 0 0)` | ✅ | space before `(` |
| `trnoise 1m 1u 0 0` | ✅ | no parens at all — the shipped `examples/transient-noise/noilib-demo.h` uses this |
| `trnoise(1m,1u,0,0)` | ✅ | commas are separators |
| `trnoise(1m 1u 0 0 0 0 0 99)` | ✅ | extra arguments **silently ignored** |
| `dc 0 trnoise(...)`, `DC trnoise(...)`, `trnoise(...)` alone | ✅ | a bare `DC` with no number parses |
| `trnoise()` | ❌ | `Simulation interrupted due to error! / incomplete or empty netlist` |
| `trnoise(1m)` | ⚠️ **accepted, reads past the array** | `vsrcpar.c:239` takes `coeffs[1]` with no `numValue` guard; MEASURED output was silently 0. Never emit fewer than 2 |
| `trnoise(1m -1u 0 0)` | ☠️ **HANGS FOREVER** | see §9-T1 |
| `noise 200u 0.05n 1 50u` | ❌ | `unknown parameter (noise)`. There is no `noise` alias — and `examples/transient-noise/noilib-demo.h` subckt `inv13` uses it, so **that shipped subcircuit will not parse** |
| `trrandom(2)`, `trrandom(2 0 ...)`, `trrandom(2 -10u ...)` | ❌ | `doAnalyses: impossible error - can't occur` (E_PANIC out of `CKTsetBreak`) |

Note the asymmetry the GUI must encode: for `trnoise`, `TS = 0` is **legal and meaningful**
("no white/1-f, RTS only"); for `trrandom`, `TS = 0` is **fatal**.

---

## 2. `trnoise(...)` — the complete positional parameter list

```
trnoise( NA  TS  NALPHA  NAMP  RTSAM  RTSCAPT  RTSEMT )
           1   2    3      4      5       6        7
```

Parsed at `src/spicelib/devices/vsrc/vsrcpar.c:226-262` (ISRC: `isrcpar.c:228-264`, identical),
stored by `trnoise_state_init` (`src/frontend/trannoise/1-f-code.c:205-227`), evaluated in
`vsrcload.c:386-428` / `isrcload.c:380-423`, breakpoints in `vsrcacct.c:232-301` /
`isrcacct.c:264-337`.

| # | name | meaning | unit | default if omitted | zero means |
|---|---|---|---|---|---|
| 1 | `NA` | **white-noise rms per sample** — the σ of the Gaussian drawn once per `TS` | V (VSRC) or A (ISRC) | *required*; index 0 is read unconditionally | no white noise; the sign is ignored (MEASURED: `-1m` ≡ `1m`) |
| 2 | `TS` | **noise timestep** — the interval between fresh samples, and the transient breakpoint spacing | s | *required*; index 1 is read unconditionally (§9-T2) | white **and** 1/f are switched off entirely (`vsrcload.c:403`), and no breakpoints are posted (`vsrcacct.c:240-241`). This is the legal "RTS only" idiom |
| 3 | `NALPHA` | **1/f PSD exponent** α: output PSD ∝ f<sup>−α</sup> | — | `0.0` (`vsrcpar.c:229`) | **also forces `NAMP := 0`** (`vsrcpar.c:242`, `NALPHA != 0.0` guard) — there is no 1/f without a positive exponent |
| 4 | `NAMP` | **1/f driving rms** — σ of the white sequence fed to the Kasdin filter (`Q_d` in `f_alpha`) | V or A | `0.0` | no 1/f |
| 5 | `RTSAM` | **RTS amplitude** — the height of the two-level telegraph step | V or A | `0.0` | no RTS, and args 6-7 are not read (`vsrcpar.c:248-253`) |
| 6 | `RTSCAPT` | **mean trap capture time** = mean duration of the **low** state | s | `0.0` | `exprand(0) == 0` ⇒ capture is instantaneous ⇒ the source sits permanently at `+RTSAM`, i.e. a pure DC offset. MEASURED: `trnoise(0 0 0 0 5m)` gives `AVG = 5.00000e-03` with σ ≈ 8e-16 |
| 7 | `RTSEMT` | **mean trap emission time** = mean duration of the **high** state | s | `0.0` | emission is instantaneous ⇒ one-timestep spikes. MEASURED `trnoise(0 0 0 0 5m 18u)`: duty 0.6 %, mean high 94 ns |

The three arms superpose: the emitted value is
`interp(white ⊕ 1/f) + (RTSAM if in the high state) + VSRCdcValue` (`vsrcload.c:399-427`).
A DC value, when given, is **added**, and a `dc 0` is the normal idiom.

### 2.1 White noise — what `NA` actually buys you

`trnoise_state_gen` (`1-f-code.c:160-190`) draws two `N(0, NA²)` variates per call from `GaussWa`
(the Wallace generator — `#define WaGauss` at `src/include/ngspice/ngspice.h:223`; `FastRand` is
commented out at `:222`). `vsrcload.c:409-414` then **linearly interpolates** between sample `n`
and `n+1`, so the continuous waveform is a triangle-filtered sample stream, not a sample-and-hold.

Three estimators of "how much noise", all MEASURED on `trnoise(1m 1u 0 0)`, and they disagree —
the GUI must pick one and label it:

| estimator | value | why |
|---|---|---|
| `stddev(v(n))` on the raw plot | **0.856 mV** | *biased high*: the grid clusters points just after each breakpoint, over-weighting them |
| `meas tran x RMS v(n)` | **0.821 mV** | time-weighted; matches theory `sqrt(2/3)·NA = 0.8165 mV` for a linearly-interpolated iid stream |
| `linearize` at Δt = `TS`, then `stddev` | **1.002 mV** | lands on the sample instants and recovers `NA` itself |

**Rule for the GUI: report `meas tran ... RMS`, never `stddev()`, on a transient-noise waveform.**

**Equivalent one-sided white PSD — the number an analog designer wants:**

> **S₁ = 2·NA²·TS  [V²/Hz]  ⇔  NA·√(2·TS)  [V/√Hz]**, flat to roughly 1/(2·TS).

MEASURED by filtering with a 1 kΩ / 159 nF RC (noise bandwidth 1/(4RC) = 1572 Hz) and reading the
output rms over a 50 ms run:

| `NA` | `TS` | predicted out-rms | MEASURED |
|---|---|---|---|
| 1 mV | 0.1 µs | 17.7 µV | 19.1 µV |
| 1 mV | 1 µs | 56.1 µV | 55.3 µV / 50.7 µV (two runs) |
| 1 mV | 10 µs | 177 µV | 180 µV |

Scaling is exactly linear in `NA` (MEASURED 1 m → 0.862 m, 10 m → 8.612 m over 25 008 points).
So a GUI can offer the field as **"White noise density [V/√Hz]"** and solve `NA = density/√(2·TS)`
once the user has chosen `TS`. That is strictly better than what the manual offers, which is `NA`
alone with no calibration at all.

### 2.2 1/f noise — what `NALPHA` and `NAMP` actually buy you

`f_alpha()` (`1-f-code.c:24-110`) implements Kasdin's method: build the h<sub>k</sub> coefficients
for exponent α/2, fill w<sub>k</sub> with `NAMP·GaussWa`, multiply the two spectra, invert. The
whole record is **pre-computed in one shot** at the first sample of each run
(`1-f-code.c:118-158`), sized `ceil(tstop/TS) + 10`, and each emitted value is
`oneof[n] − oneof[0]` so the series starts at zero.

Measured PSD slope (linear fit of `log|V(f)|` vs `log f`, 100 Hz…100 kHz, 65 536-sample runs):

| `NALPHA` | fitted `|V(f)|` slope | ⇒ PSD | verdict |
|---|---|---|---|
| −1 | 0.000 (output is identically 0) | — | **α ≤ 0 produces nothing**: `1-f-code.c:126` requires `NALPHA > 0.0` |
| 0.5 | −0.266 | f<sup>−0.5</sup> | ✅ |
| 1.0 | −0.508 | f<sup>−1</sup> | ✅ true 1/f |
| 1.5 | −0.755 | f<sup>−1.5</sup> | ✅ |
| **2.0** | garbage (output ≈ 1.4e-18) | — | ☠️ **exactly zero output**, see §9-T3 |
| 2.5 | −0.998 | f<sup>−2</sup> | non-stationary random walk; the α you asked for is not what you get |

**Valid range is 0 < α < 2, open at both ends.** Clamp the widget.

`NAMP` is the rms of the *driving* sequence, **not** of the output. The realised output rms scales
linearly with `NAMP` but also grows with the length of the run (≈ √ln N, as 1/f must):

| record | `NAMP` | MEASURED output rms (α = 1) |
|---|---|---|
| 1 024 samples | 1 mV | 1.77 mV |
| 8 192 samples | 1 mV | 2.06 mV |
| 65 536 samples | 1 mV | 2.57 mV |
| 65 536 samples | 10 mV | 26.8 mV |

So a "1/f amplitude" field cannot be labelled "rms" honestly. Label it **"1/f driving amplitude"**
and show the realised rms after the run (`meas tran ... RMS`), which is the honest number.

**Cost.** The 1/f path allocates three `double` arrays of `tstop/TS + 10` and runs two FFTs.
MEASURED peak RSS (baseline ngspice ≈ 15 MB), with the run cut short by `stop when time > 1u`:

| `tstop/TS` | array length | peak RSS | wall |
|---|---|---|---|
| 1e5 | 100 010 | 20.5 MB | 0.10 s |
| 1e6 | 1 000 010 | 57.8 MB | 0.10 s |
| 1e7 | 10 000 010 | **416 MB** | 1.10 s |

≈ **40 bytes per sample, per 1/f source**, paid before the first timepoint. A 1 s run at `TS = 1 ns`
would ask for 40 GB. **The GUI must compute `tstop/TS` and refuse or warn above ~1e7.**
It also prints `<N> 1/f noise values in time domain created` **to stdout**, once per 1/f source per
run — a log parser must expect it. Without `HAVE_LIBFFTW3` the length is rounded up to a power of
two instead (`1-f-code.c:136-144`); this build has FFTW3, so it is exact.

### 2.3 RTS (random telegraph / burst) noise

A two-state Markov telegraph. `RTScapTime` and `RTSemTime` are drawn with `exprand()` and re-armed
in the accept routine (`vsrcacct.c:277-300`); the load adds `RTSAM` while `time >= RTScapTime`
(`vsrcload.c:417-421`). Each transition is a breakpoint, so the edges are exact.

MEASURED, `trnoise(0 0 0 0 5m 18u 30u)`, 20 ms run, `setseed 11`:

| quantity | theory | MEASURED |
|---|---|---|
| high level | `RTSAM` = 5 mV | 5.000 mV (max), 0 (min) |
| mean low duration | `RTSCAPT` = 18 µs | 18.6 µs |
| mean high duration | `RTSEMT` = 30 µs | 28.9 µs |
| duty (`AVG`/`RTSAM`) | `EMT/(CAPT+EMT)` = 0.625 | 0.608 / 0.636 (two seeds) |

So: **`RTSCAPT` is the mean *low* time and `RTSEMT` the mean *high* time**, and the mean offset the
source adds is `RTSAM·EMT/(CAPT+EMT)`. A GUI can show that number live as the user types.
Several RTS sources in one deck are independent traps; that is the standard way to build a
multi-trap burst-noise model.

---

## 3. `trrandom(...)` — the complete positional parameter list

```
trrandom( TYPE  TS  TD  PARAM1  PARAM2 )
            1    2   3     4       5
```

Parsed at `vsrcpar.c:264-291` (`isrcpar.c:265-292`), state in `trrandom_state_init`
(`1-f-code.c:230-241`), value drawn by `trrandom_state_get`
(`src/include/ngspice/1-f-code.h:64-99`), re-drawn at breakpoints in `vsrcacct.c:303-329`.

It is a **piecewise-constant** source: one draw per `TS`, held flat in between. No interpolation,
no filtering.

| # | name | meaning | unit | default | notes |
|---|---|---|---|---|---|
| 1 | `TYPE` | distribution selector, `(int)` cast of the value | — | *required*, index 0 read unconditionally | out-of-range (0, 5, …) ⇒ the source silently emits **0** for ever (`1-f-code.h:94-97`). MEASURED for both 0 and 5 |
| 2 | `TS` | **hold time** — a new value every `TS`, and a breakpoint at each | s | *required*, index 1 read unconditionally | `TS = 0` or negative ⇒ **fatal**, `doAnalyses: impossible error - can't occur` |
| 3 | `TD` | delay before the first draw | s | `0.0` | for `t < TD` the source holds `PARAM2`. MEASURED: `trrandom(2 10u 25u 1 7)` sits at exactly 7 until 25 µs. Negative `TD` is ignored |
| 4 | `PARAM1` | distribution parameter 1 (table below) | varies | `1.0` (`vsrcpar.c:267`) | |
| 5 | `PARAM2` | distribution parameter 2 / offset | varies | `0.0` | **also the value used before the first draw**, and the value a `dc`-less source injects into a DC operating point (§6.1) |

| `TYPE` | distribution | `PARAM1` | `PARAM2` | MEASURED (20 ms, `TS = 10 µs`, defaults) |
|---|---|---|---|---|
| **1** | **uniform** on `[−PARAM1, +PARAM1)` | half-range (amplitude) | offset | mean 0.011, σ 0.576 (= 1/√3 ✅), min −0.99988, max +0.99801 |
| **2** | **gaussian** | standard deviation | mean | mean 0.043, σ 1.003 ✅; with `(2 10u 0 2 1)` → mean 1.047, σ 2.006 ✅ |
| **3** | **exponential** | mean | offset | mean 0.998, σ 1.012, min 0 ✅; with `(3 10u 0 2 1)` → mean 2.996, σ 2.023, min 1 ✅ |
| **4** | **poisson** | λ | offset | mean 1.003, σ 0.992 ✅ (integer-valued: min 0, max 5); λ = 3 → mean 3.012, σ 1.711 (√3 = 1.732 ✅) |

Note `PARAM1` for the uniform case is the **half**-range, not the full range — a GUI field labelled
"Range" would be off by 2×. Note also that types 3 and 4 are strictly one-sided, so they always
carry a DC offset equal to their mean; a "random supply drop" panel wants type 2 or 1.

Like `trnoise`, a given `dc` value is added on top of the draw (`vsrcload.c:430-437`).

---

## 4. Seeding and repeatability — MEASURED, and the answer is split

### 4.1 The two generators, and why only one of them is seedable

```
SOURCE  src/main.c:936-938        int ii = 1; cp_vset("rndseed", CP_NUM, &ii); com_sseed(NULL);
SOURCE  src/main.c:1370-1371      #elif defined(WaGauss)
                                      initw();
SOURCE  src/frontend/trannoise/wallace.c:76-86
                                  void initw(void) { ...
                                      srand((unsigned int) getpid());     /* <-- HERE */
                                      TausSeed(); ... }
```

There are two independent random streams:

| stream | used by | seeded by |
|---|---|---|
| **Wallace pool** (`GaussWa`, `wallace.c`) | `trnoise` **white** (`1-f-code.c:172-174`) and `trnoise` **1/f** (`1-f-code.c:48,54`) | `initw()` once at start-up, from **`getpid()`**. Nothing else ever refills it from a user seed |
| **CombLCGTaus** (`randnumb.c`) | `trrandom` (`drand`/`gauss0`/`exprand`/`poisson`) and RTS (`exprand`) | `srand(n) + TausSeed()` via `com_sseed`, i.e. the `setseed` command and `.option seed=` |

`initw()` runs in `main.c` *after* `com_sseed(NULL)` and *before* the deck is read, so it
overwrites the seed with the PID and fills `pool1` with PID-derived variates. A later `setseed`
re-seeds only the Tausworthe states; `pool1`'s **contents** are never rebuilt, and `NewWa()`
(`wallace.c:298-370`) only shuffles them. Hence:

> **`trnoise` white noise and `trnoise` 1/f noise cannot be made reproducible by any user-facing
> control in this build.** They change with the process id.

### 4.2 The measurements

Same deck, run repeatedly, comparing the printed waveform byte for byte:

| what | seeding | run-to-run |
|---|---|---|
| `trnoise(1m 1u 0 0)` white | none | **differs** — σ 0.8395 / 0.8529 / 0.8598 m |
| `trnoise(1m 1u 0 0)` white | `.option seed=12345` | **still differs** — σ 0.8513 / 0.8604 / 0.8522 m |
| `trnoise(1m 1u 0 0)` white | `setseed 12345` in `.control` | **still differs** — first sample −6.40e-7 vs +1.11e-6 |
| `trnoise(0 1u 1 1m)` 1/f | any | **differs** (same pool) |
| `trnoise(0 0 0 0 5m 18u 30u)` RTS | `setseed 12345` | **identical** — same md5, mean 0.00345982 both runs |
| `trrandom(1 10u 0 1 0)` | none | **differs** |
| `trrandom(1 10u 0 1 0)` | `setseed 12345` | **identical** — same md5 |
| `trrandom(2 10u 0 1 0)` | `.option seed=12345` (deck card) | **identical** — same md5 |

### 4.3 The three seeding routes, and the one that silently does nothing

MEASURED, `trrandom(2 10u 0 1 0)`, two runs each, comparing md5 of the printed waveform:

| route | reproducible? | why |
|---|---|---|
| nothing | ❌ | PID-derived |
| **`set rndseed=12` alone** | ❌ | `checkseed()` (`randnumb.c:76-89`) is called **only** from `src/maths/cmaths/cmath2.c:137,180,216,254,292` — i.e. from `agauss/gauss/unif/aunif/limit`. Nothing in the `trrandom` path ever calls it |
| `set rndseed=12` + `setseed` (bare) | ✅ | `com_sseed(NULL)` reads `rndseed` and calls `srand`+`TausSeed` |
| `setseed 12` | ✅ | direct |
| `.option seed=12` / `.option seed=random` (deck card) | ✅ | `eval_opt` (`src/frontend/inp.c:441-470`) calls `com_sseed(NULL)` itself at circuit-load time |

Curiosity, MEASURED: `setseed 12` and `set rndseed=12 ; setseed` are each self-consistent but
produce **different** streams from one another. Pick one form and keep it; the GUI should emit
`setseed <n>` inside `.control`.

`.option seedinfo` (`inp.c:439-440` → `setseedinfo()`) makes the seed value print at every reseed —
worth offering as a "log the seed" checkbox so a run can be reproduced later.

### 4.4 Independence of streams

MEASURED with two identical sources in one deck, comparing `stddev(a−b)` against `√2·stddev(a)`:

| pair | σ(a) | σ(b) | σ(a−b) | √2·σ | verdict |
|---|---|---|---|---|---|
| two `trnoise(1m 1u 0 0)` | 0.9007 m | 0.8992 m | 1.2649 m | 1.2727 m | **independent** |
| two `trrandom(2 10u 0 1 0)` | 1.018 | 0.985 | 1.366 | 1.416 | **independent** |

Each instance owns its own `struct trnoise_state` / `trrandom_state` and (for 1/f) its own
pre-computed array; they merely draw from a shared global generator in interleaved order. There is
**no per-instance seed** — you cannot pin one source and vary another.

### 4.5 What "repeat the run" means

Every `tran` command re-generates everything. MEASURED with five back-to-back `tran` commands in
one `.control` block: `210 1/f noise values in time domain created` printed five times, and σ came
out 1.911 m / 1.671 m / 1.826 m / 1.569 m / 1.635 m — five different realisations.
`vsrcload.c:392-398` resets `state->top` on the 0 → t>0 edge and `1-f-code.c:119` rebuilds the 1/f
array from the *current* `CKTfinalTime`, so changing `tstop` between runs is safe.

**Therefore a transient-noise Monte Carlo is simply `repeat N / tran ... / <measure> / end`** — no
`alter`, no reseeding, no netlist rewrite. That is the cheapest statistical loop in the whole
orchestration surface (compare `orchestration.md`, which has to build everything from `alter`).

---

## 5. Interaction with `.tran`

### 5.1 Yes — `TS` forces the timestep, via breakpoints

`VSRCaccept` posts `CKTsetBreak(break_time += TS)` on every crossing (`vsrcacct.c:250-258`);
`break_time` starts at `−1.0` (`vsrcset.c:34`) so the first breakpoint is armed at `t = 0`.
RTS adds two more breakpoints per cycle (capture, emission); `trrandom` adds one per `TS` plus one
at `TD`.

MEASURED time grid for `trnoise(1m 1u 0 0)`, `tran 1u 10u` — after every breakpoint the integrator
restarts at `TS/50` and doubles until it lands exactly on the next multiple of `TS`:

```
0, 1n, 2n, 4n, 8n, 16n, 32n, 64n, 128n, 256n, 456n, 656n, 828n, 1.000u,
1.020u, 1.060u, 1.140u, 1.300u, 1.500u, 1.700u, 1.850u, 2.000u, ...
```

### 5.2 The cost model — the single most important GUI number

MEASURED, RC circuit, `tran 1u 1m` (so `tstep = 1 µs`, `tstop = 1 ms`), varying only `TS`:

| `TS` | points, white | wall | peak RSS | points, 1/f | wall | peak RSS |
|---|---|---|---|---|---|---|
| 10 µs | 1 309 | 0.10 s | 15.0 MB | 1 311 | 0.10 s | 17.2 MB |
| 1 µs | 5 059 | 0.10 s | 15.1 MB | 5 025 | 0.10 s | 17.4 MB |
| 100 ns | 50 019 | 0.10 s | 17.0 MB | 50 012 | 0.10 s | 19.5 MB |
| 10 ns | 500 008 | 0.60 s | 38.0 MB | 500 008 | 0.60 s | 41.8 MB |

> **points ≈ max( tstop/tstep , 5 · tstop/TS )** — and the requested `tstep` is irrelevant once
> `TS < tstep`. MEASURED separately: `tran 1u 5000u` and `tran 10u 5000u` with `TS = 1 µs` both
> produced **25 008** rows.

So the "Noise timestep" field silently multiplies run time **and rawfile size** by `tstep/TS`. A GUI
that shows a live "estimated points: 500 008" beside that field is already ahead of ADE, which has
no equivalent knob to get wrong.

### 5.3 Accepted / rejected statistics

MEASURED with `rusage tranpoints accept rejected`, same RC, `tran 1u 5000u`:

| stimulus | accepted | rejected |
|---|---|---|
| `pulse(...)`, no noise | 10 258 | 1 001 |
| `trnoise(1m 1u 0 0)` | 25 241 | **185** |
| `trnoise(1m 0.1u 0 0)` | 250 061 | 924 |

**Rejections go *down*.** Breakpoints keep the step short enough that the LTE controller rarely has
to back off. So "lots of accepted timepoints, almost no rejections" is the *signature* of a
transient-noise run, and a convergence-health pane (critique §6 item 5) must not read that as a
healthy circuit — it is just a finely chopped one.

### 5.4 `notrnoise` — what it kills, exactly

`1-f-code.c:120-124`, inside `trnoise_state_gen`, executed once per source on its **first value
generation**:

```c
if (cp_getvar("notrnoise", CP_BOOL, NULL, 0))
    this->NA = this->TS = this->NALPHA = this->NAMP =
        this->RTSAM = this->RTSCAPT = this->RTSEMT = 0.0;
```

MEASURED on a four-source deck (`set notrnoise` and `.options notrnoise` behave identically —
it is a mechanism-C variable, so both doors work):

| source | without | with `notrnoise` |
|---|---|---|
| `trnoise(1m 1u 0 0)` white | σ 0.926 m | **0** |
| `trnoise(0 1u 1 1m)` 1/f | σ 1.538 m | **0** (and the "1/f noise values created" line disappears) |
| `trnoise(0 0 0 0 5m 18u 30u)` **RTS only** | σ 2.408 m | **σ 2.412 m — SURVIVES** |
| `trnoise(1m 1u 0 0 5m 18u 30u)` white+RTS | σ 2.554 m, max 7.22 m | **0** |
| `trrandom(2 10u 0 1 0)` | σ 1.059 | **σ 1.077 — SURVIVES** |
| total points | 4 045 | 735 |

The mechanism: an RTS-only source has `TS == 0`, so `vsrcload.c:403` returns before ever calling
`trnoise_state_get`, so `trnoise_state_gen` never runs, so the kill switch never fires. And
`trrandom` uses a different state struct that has no such check at all.

> **GUI rule.** Do **not** offer `notrnoise` as "disable transient noise". Offer a per-row Enable
> checkbox that stops emitting the parameter, and use `notrnoise` at most as a redundant belt.
> If it is offered, the label must be "disable white and 1/f transient noise".

### 5.5 Other `.tran` forms

MEASURED, all fine and all producing a fresh realisation each time: `tran 1u 200u`,
`tran 1u 200u 100u` (tstart — the 1/f array is still sized from `tstop`), `tran 1u 200u 0 5u`
(maxstep), `tran 1u 200u uic`.

`TS ≥ tstop` is accepted but useless: MEASURED `trnoise(1m 1000u 0 0)` under `tran 1u 100u` yields
only the first tenth of one interpolation ramp — σ 51.7 µV, max 176 µV instead of ≈ 1 mV.
**Warn when `TS > tstop/100`.**

`TRNOISE_STATE_MEM_LEN` is 4 (`src/include/ngspice/1-f-code.h:9`): the state remembers only the
last four samples, and reaching further back is fatal —
`fprintf(stderr, "ouch, trying to fetch from the past %d %d")` + `controlled_exit(1)`
(`1-f-code.h:55-59`). I could **not** provoke it: the `TS` breakpoints cap the step at `TS`, so a
rejected step can never rewind more than one sample. Recorded so nobody re-hunts it, and so a log
parser can recognise the string if it ever appears. Same for
`"ouch, noise data exhausted"` (`1-f-code.c:181-184`).

---

## 6. Interaction with every other analysis — MEASURED

Short version: **outside a transient, `trnoise` contributes exactly nothing and `trrandom` is a
trap.** One deck carrying a `trnoise` source and a `trrandom` source ran `op`, `dc`, `ac`, `noise`
and `tf` cleanly — rc 0, no warning, no diagnostic of any kind.

### 6.1 The operating point

`vsrcload.c:74-83`: when `CKTmode & (MODEDCOP | MODEDCTRANCURVE)` **and** `dcGiven`, the DC value is
used and the transient function is never consulted. Otherwise `MODEDC` (= `0x70`, i.e.
`MODEDCOP|MODETRANOP|MODEDCTRANCURVE`, `cktdefs.h:179-182`) forces `time = 0` — at which
`trnoise` returns 0 (`vsrcload.c:403`) but `trrandom` returns its *initial* `state->value`, which
`trrandom_state_init` (`1-f-code.c:238`) sets to **`PARAM2`**.

MEASURED, four 1 kΩ loads, plain `op`:

| source | v(node) at the OP |
|---|---|
| `i1 0 a dc 0 trrandom(2 10u 0 1m 5m)` | **0** |
| `i2 0 b trrandom(2 10u 0 1m 5m)` (no `dc`) | **5 V** ⇐ `PARAM2` × 1 kΩ |
| `i3 0 c dc 0 trnoise(1m 1u 0 0 5m 18u 30u)` | 0 |
| `i4 0 d trnoise(1m 1u 0 0 5m 18u 30u)` (no `dc`) | 0 |

> **GUI rule: always emit an explicit `dc 0` on a generated stochastic source.** Without it a
> `trrandom` source shifts the operating point of the whole circuit by `PARAM2`, silently.

### 6.2 The `optran` fallback contaminates the operating point (new)

`optran` — on by default (F11) — never advances `ckt->CKTtime`; it carries its own local `optime`
(`src/spicelib/analysis/optran.c:304` and every use at `:433-585`). Consequences, MEASURED with
`.options noopiter gminsteps=0 srcsteps=0` to force rung 4 (`Note: Transient op started` /
`Transient op finished successfully`):

| source | normal ladder | **optran fallback** |
|---|---|---|
| `vn nn 0 dc 0 trnoise(100m 10n 0 0)` | 0 V | **0 V** — safe, because the load reads `CKTtime`, which stays 0 |
| `vq qq 0 dc 0 trrandom(2 100n 0 100m 0)` | 0 V | **34.85 mV** — a live random draw baked into the reported operating point |

`VSRCaccept` runs during optran (mode is `MODETRAN`, `optran.c:415`), `break_time` starts at −1, and
`0 >= −1` fires one draw. **Any analysis whose operating point falls through to optran — `op`, `dc`,
`ac`, `noise`, `tf`, `pz`, `disto`, `sens` — inherits that draw.** With a fixed seed it is
deterministic; without one it changes every run and the user sees an operating point that wanders.
This is a real defect and nothing in the tree documents it.

### 6.3 AC, NOISE, DISTO, PZ, TF, SENS

`VSRCacLoad` uses only `acMag`/`acPhase`, and `.DEVnoise` is `NULL` for both device types
(`src/spicelib/devices/vsrc/vsrcinit.c:60`, `isrc/isrcinit.c:60` — compare `res/resinit.c:60`,
`.DEVnoise = RESnoise`). So:

* **AC is unaffected.** MEASURED: `ac` magnitudes with a `trnoise` source present are the plain RC
  response. A source may legally carry both `ac 1` and `trnoise(...)`; they are independent
  parameters (MEASURED, both orders).
* **`.NOISE` cannot see transient noise at all.** MEASURED, byte-identical:
  `onoise_total = 1.286185e-07` with and without `trnoise(1m 1u 0 0)` on a source in the circuit.
* `.dc`: `MODEDCTRANCURVE` + `dcGiven` ⇒ the DC value, so a swept run is clean; without `dc`, the
  `PARAM2` trap of §6.1 applies at every sweep point.
* `tf`, `pz`, `disto`, `sens` all build on the OP/AC matrices — unaffected except via §6.2.

**What a GUI must warn:** if the user enables transient noise and the run has **no** transient
analysis, say so — the settings will have no effect whatsoever, silently.

---

## 7. `trnoise` versus `.NOISE`, in one tooltip paragraph

> **`.NOISE` and transient noise answer different questions and share no code.**
> `.NOISE` is a *small-signal, frequency-domain* analysis: it linearises the circuit about its
> operating point, asks each device for its noise spectral density (`DEVnoise`), propagates each
> contribution to one output through the linear transfer function, and reports V²/Hz versus
> frequency plus an integrated total — "how much noise does this circuit *have*, where does it come
> from, and how does it vary with frequency". It is exact, fast, repeatable, and blind to anything
> non-linear: no clipping, no jitter, no sampling, no burst.
> **`trnoise` / `trrandom` are the opposite**: they are *stimulus*, not analysis. They make one
> source emit a random waveform during a normal transient run, so the noise passes through the full
> non-linear circuit and you can watch what it actually does — jitter on a clock edge, a comparator
> flipping, a PLL wandering, a sampled-data system folding noise. There is no spectrum unless you
> compute one (`linearize` + `fft`), the answer is a *realisation* and not an expectation, and you
> need many runs to say anything statistical. **Ideal sources contribute nothing to `.NOISE`, so
> adding `trnoise` to a source changes no `.NOISE` result — and `.NOISE` never sees it. Use `.NOISE`
> to size a design; use `trnoise` to see a design fail.**

---

## 8. Four worked example decks, each measured

All four run against `build-ver_50/src/ngspice` with `-b`, rc 0. Files under
`.../scratchpad/trn/ex1.cir` … `ex4.cir`.

### 8.1 White noise only — calibrated

```spice
* EX1 white transient noise, calibrated
* trnoise(NA TS 0 0): NA = per-sample rms, TS = sample interval
vn  n 0 dc 0 trnoise(1m 1u 0 0)
rs  n out 1k
cl  out 0 159n                 $ noise bandwidth 1/(4RC) = 1572 Hz
.control
setseed 4242
tran 1u 50m
meas tran vsrc_rms RMS v(n)   from=0  to=50m
meas tran vout_rms RMS v(out) from=1m to=50m
.endc
.end
```

MEASURED: `250 205` rows;
`vsrc_rms = 8.20676e-04` (theory `sqrt(2/3)·NA` = 8.165e-4 ✅);
`vout_rms = 5.53454e-05` (theory `NA·sqrt(2·TS)·sqrt(1572)` = 5.61e-5 ✅).
Equivalent density **1.41 µV/√Hz**.

### 8.2 1/f (flicker) noise

```spice
* EX2 1/f (flicker) transient noise
* trnoise(0 TS NALPHA NAMP): NALPHA = PSD exponent (0<a<2), NAMP = driving rms
vn n 0 dc 0 trnoise(0 1u 1 1m)
rn n 0 1k
.control
setseed 4242
tran 1u 65536u
meas tran vrms RMS v(n) from=0 to=65536u
linearize v(n)
fft v(n)
.endc
.end
```

MEASURED: `65546 1/f noise values in time domain created`; `vrms = 2.19541e-03`;
peak-to-peak `0.0229`; fitted spectrum slope over 100 Hz…100 kHz `−0.477 dec/dec` on `|V(f)|`,
i.e. **PSD ∝ f^−0.95** ✅ for the requested α = 1.

### 8.3 RTS / burst noise

```spice
* EX3 RTS (random telegraph / burst) noise
* trnoise(0 0 0 0 RTSAM RTSCAPT RTSEMT)
vn n 0 dc 0 trnoise(0 0 0 0 5m 18u 30u)
rn n 0 1k
.control
setseed 4242
tran 1u 20000u
meas tran vavg AVG v(n) from=0 to=20000u
meas tran vmax MAX v(n)
meas tran vmin MIN v(n)
.endc
.end
```

MEASURED: `vavg = 3.17925e-03` (theory `RTSAM·30/(18+30)` = 3.125e-3 ✅);
`vmax = 5.00000e-03`; `vmin = 0`; 22 518 rows; 841 transitions in a 20 ms window with
mean low 18.6 µs and mean high 28.9 µs.

### 8.4 Random-value source (all four distributions)

```spice
* EX4 trrandom: piecewise-constant random-value source
* trrandom(TYPE TS TD PARAM1 PARAM2)  TYPE 1=uniform 2=gauss 3=exp 4=poisson
vu u 0 dc 0 trrandom(1 10u 0 1 0)
vg g 0 dc 0 trrandom(2 10u 0 1 0)
ve e 0 dc 0 trrandom(3 10u 0 1 0)
vp p 0 dc 0 trrandom(4 10u 0 1 0)
ru u 0 1k
rg g 0 1k
re e 0 1k
rp p 0 1k
.control
setseed 4242
tran 1u 20000u
meas tran u_avg AVG v(u)
meas tran g_avg AVG v(g)
meas tran e_avg AVG v(e)
meas tran p_avg AVG v(p)
.endc
.end
```

MEASURED: `u_avg = 1.13e-02` σ 0.5735 (uniform, √(1/3) = 0.5774 ✅);
`g_avg = 4.29e-02` σ 0.9638 (gaussian ✅);
`e_avg = 9.86e-01` σ 0.9833 (exponential, mean = σ = 1 ✅);
`p_avg = 1.00450e+00` σ 1.0248 (poisson λ = 1 ✅).

### 8.5 Bonus: the shipped "shot noise" idiom, and a shipped bug

`examples/transient-noise/shot_ng.cir` shows the pattern worth stealing — a unit-rms white source
used as a *modulator* so the noise amplitude can track a bias current:

```spice
VNG 0 11 DC 0 TRNOISE(1 1n 0 0)
V1  2 3  DC 0                          $ ammeter
BI  1 3  I = sqrt(2*abs(i(v1))*1.6e-19*1e7) * v(11)
```

But `examples/transient-noise/simple-noise.cir:3` is labelled "1/f noise current" and reads
`TRNOISE(0.05 8p 0 1.0 0.001)`. MEASURED, it produces **no 1/f at all** (`NALPHA = 0` forces
`NAMP := 0`, §9-T4) — just white noise plus a permanent DC offset, because with only five arguments
`RTSCAPT` and `RTSEMT` are 0 and the trap never releases. And
`examples/transient-noise/noilib-demo.h` subckt `inv13` uses the non-existent keyword `noise`,
which is a hard parse error. **The shipped examples are themselves evidence that positional
arguments are unusable by hand** — which is the case for the GUI.

---

## 9. Defects and traps found in this pass

| id | severity | what |
|---|---|---|
| **T1** | ☠️ **hang** | **A negative `TS` in `trnoise` hangs ngspice forever.** `trnoise(1m -1u 0 0)` + `tran`: MEASURED rc 124 under `timeout 20`, no output, no diagnostic. `n1 = (size_t) floor(time/TS)` (`vsrcload.c:409`) goes hugely positive, and `trnoise_state_get`'s `while (index >= this->top) trnoise_state_gen(...)` (`1-f-code.h:52-53`) never terminates. **The GUI must reject `TS < 0` before emitting.** Contrast `trrandom`, where a negative or zero `TS` fails cleanly (if uselessly) with `doAnalyses: impossible error - can't occur` |
| **T2** | ⚠️ out-of-bounds read | `trnoise(1m)` and `trrandom(2)` are accepted. `vsrcpar.c:236-237` / `:274-275` read `coeffs[0]` and `coeffs[1]` with **no `numValue < 2` guard**, unlike `SINE`/`EXP`/`PULSE` (`vsrcpar.c:92-93`). MEASURED: `trnoise(1m)` produced silence (0 output); `trrandom(2)` produced the E_PANIC message. Both are heap reads past a 1-element `TMALLOC` |
| **T3** | ⚠️ silent zero | **`NALPHA = 2.0` yields exactly zero 1/f output.** With α/2 = 1 every Kasdin coefficient `hfa[i]` collapses to 1 (`1-f-code.c:51`), the spectral product keeps only DC, and `oneof[n] − oneof[0] ≡ 0`. MEASURED σ = 1.37e-18. α > 2 gives a divergent random walk with a fixed f^−2 slope regardless of α. **Valid range is strictly 0 < α < 2** |
| **T4** | ⚠️ silent zero | **`NALPHA = 0` silently discards `NAMP`** (`vsrcpar.c:242`), so `trnoise(0 1u 0 1m)` emits identically 0. MEASURED. This is what breaks the shipped `simple-noise.cir` |
| **T5** | ⚠️ silent override | **One source, one transient function.** MEASURED: `dc 0 ac 1 sin(0 1 10k) trnoise(1m 1u 0 0)` runs as pure noise (max 2.1 mV); `... trnoise(...) sin(0 1 10k)` runs as a pure sine (max 1.0). The `ac` spec survives in both. No warning. Likewise `alter vsig trnoise = [...]` on a source that carried `sin(...)` **destroys the sine** (MEASURED: max v(in) fell from 1.0-with-sine to 1.02 = dc + noise) |
| **T6** | ⚠️ wrong result | **`optran` injects a random `trrandom` draw into the operating point** (§6.2). MEASURED 34.85 mV where the normal ladder gives 0 |
| **T7** | ⚠️ wrong result | **A `trrandom` source with no `dc` value shifts the operating point by `PARAM2`** (§6.1). MEASURED 5 V |
| **T8** | ⚠️ incomplete | **`notrnoise` does not disable RTS-only sources or `trrandom` at all** (§5.4) |
| **T9** | ⚠️ unreproducible | **No user-facing seed reaches `trnoise` white or 1/f noise** (§4.1). This is arguably the single biggest quality gap in the feature: you cannot re-run a failing noise transient |
| **T10** | ℹ️ cost cliff | **1/f pre-allocates ≈ 40 bytes × `tstop/TS` per source before the first timepoint** (§2.2). 1e7 samples = 416 MB MEASURED |
| **T11** | ℹ️ divergent code | VSRC and ISRC use **different** breakpoint algorithms for the same feature — VSRC tracks `VSRCbreak_time` (`vsrcacct.c:250-258`), ISRC compares `AlmostEqualUlps(n·TS, CKTtime, 3)` (`isrcacct.c:282-297`), and the ISRC path divides by `TS` with no `TS > 0` guard. MEASURED, the observable behaviour is nonetheless identical for RTS-only, white and `trrandom` (V and I gave the same 22 613 rows and the same duty cycle). Recorded as a maintenance hazard, **not** as a behavioural difference — do not let a plan claim ISRC is broken. ⚠ **TOO WIDE — Stage 13 task 1 (issue 1466, C3), measured on both binaries and re-measured by the driver:** `trrandom(2 1u 1m 1m 0)` on an I source holds **one** value through [1 m, 2 m] where a V source takes **501**. The 3-ulps test above misses the first redraw when TD ≫ TS and never posts another breakpoint. White noise, RTS and TD = 0 `trrandom` on ISRC do redraw |
| **T12** | ℹ️ doc | `examples/transient-noise/noilib-demo.h` subckt `inv13` uses a `noise` keyword that does not exist ⇒ hard parse error if instantiated |

None of T1-T12 is reported by any dossier, and none is in `src/ngspice.txt`.

---

## 10. GUI implication — where this belongs and what the fields are

### 10.1 The ruling: this is analysis surface, not source surface

Transient noise is a *simulation setting*: it changes what the transient analysis means, it costs
run time proportional to a number the user chooses, and it is meaningless outside a transient. It
must **not** be a parameter string a user types onto a source symbol — three of the twelve traps
above (T1, T3, T4) are pure consequences of positional arguments, and two shipped ngspice examples
get them wrong. It also must **not** go on the schematic: F13's founding doctrine says the
schematic carries only the circuit, and this is not circuit.

**Put it on the Tran form, as a collapsible "Transient noise" section**, and put the per-source
rows in a small table inside it. Concretely, against `ase-ui.md`'s map:

* `ase::ui::chana_fields` gains nothing for `tran` (the quick fields stay `step`, `stop`).
* The Choose-Analyses dialog's fixed grid rows 2..7 stay as they are; the noise section is a new
  frame that `chana_show` grids **only for `type eq tran`**, above the fixed `Options…` row 8.
  ⚠️ `chana_show`'s destroy list at `ase_window.tcl:4587` is a hardcoded five names — the new frame
  **must** be added to it or it will survive a type switch and show the tran settings on the AC
  form. `ase-ui.md` §2.5 calls this "the single sharpest trap in the analysis code"; it is exactly
  the trap this feature walks into.
* The state row grows keys under the existing `tran` row — `ase::state_load` merges over defaults
  (`ase.tcl:494-501`), so no schema migration and no `.state` churn; the 104 committed `.state`
  files keep round-tripping byte-stable because absent keys stay absent.
* These keys **must actually reach the deck**. F3's standing defect (`chana_options` collects keys
  that never reach the deck) is precisely the failure mode to avoid here; a Transient-noise panel
  that does not emit is worse than none.

### 10.2 How the deck gets the source, without touching the schematic

⚠ **CORRECTED 2026-09-15 by Stage 13 task 1 (issue 1466, C1/C2), measured on both binaries.** **(1) `ase_inoise_1` is an XSPICE `a` card** — SPICE reads a device from its first letter; on the fork it gives `MIF-ERROR - unable to find definition of model 0`, rc 1, and `ase::netlist_facts` would file it under `xspice`. A generated card's name begins with its device letter (`iase_noise_<row>_<k>`). **(2) A `trnoise(…)` written on a card serves EVERY transient in the deck**: a second `tran` with no restore is noisy (45.2: 0.88 V RMS, 4439 points where its card asks for ~108). Shipped: a quiet carrier in the netlist slot, `alter … trnoise = [ … ]` above the row's own card, and `alter … trnoise = [ 0 0 0 0 0 0 0 ]` below its guard. **(3) `trrandom` on a current source freezes** when its delay outruns its hold time (one value where a V source gives 501), so an injected random current is a V source into a 1 S VCCS.


Three routes, in the order the GUI should prefer them. MEASURED, all three.

1. **Attach to an existing source — `alter`, no netlist change.** Works on any source that carries
   only a DC value (supplies, bias sources — the common case for "noisy supply", "noisy bias"):
   ```
   alter vsup trnoise = [ 10m 1u 0 0 ]
   ```
   MEASURED: σ(vdd) 0 → 8.73 mV, mean stays 5.0000. **Forbid it on a source that carries a
   stimulus** (T5) — the GUI knows which sources it drives, and can grey those rows out.
2. **Inject a new parallel current source — one netlist line, zero topology change.** This is the
   route that makes the feature schematic-free, and it exists only because ISRC supports `trnoise`
   (contradicting the manual):
   ```
   ase_inoise_1 0 <net> dc 0 trnoise(1m 1u 0 0)
   ```
   Emit it in `render_deck` between the netlist and the `.include` block — a new emission slot
   after step 1 of `ase-deck.md` §1.1. Validate `<net>` against the netlist first
   (`ase::netlist_map_resolve`, which `ase-state.md` §3.4 notes is currently unused — this is its
   second customer, after the `.disto` mitigation). Caveat to surface in the UI: current injection
   needs a defined impedance at the node; a high-Z net will swing wildly.
3. **A series voltage source** requires renaming a net and is the only route that does change the
   netlist. Offer it last, or not at all in v1.

`circbyline` is **not** a route: MEASURED, `circbyline` inside `.control` of an already-loaded deck
adds nothing to the running circuit (σ = 1.7e-13, no `TS` breakpoints).

### 10.3 The fields

**Section header:** `☐ Transient noise` (enable). Below it, a table of rows — one per noisy source —
plus Add/Edit/Delete, reusing the existing table engine (`ase-ui.md` §3.4).

Per row, three groups. Every field carries a unit and a live derived readout, because the whole
point of the panel is that the raw arguments are uncalibrated.

**Where**
| field | widget | notes |
|---|---|---|
| Target | combobox | either `source: <name>` (route 1, restricted to DC-only sources) or `inject at net: <net>` (route 2, from the netlist node map) |
| Kind | radio | `Voltage` / `Current` — only for the inject route |

**Noise timestep** (shared by white, 1/f, RTS off/on)
| field | maps to | validation | live readout |
|---|---|---|---|
| Sample interval `TS` | arg 2 | **> 0** (T1); warn if `> tstop/100` (§5.5); warn if `tstop/TS > 1e6` | *"≈ N timepoints, ≈ M MB rawfile"* from §5.2's `5·tstop/TS` |

**White noise**
| field | maps to | validation | live readout |
|---|---|---|---|
| ☐ enable | — | | |
| Amplitude — a two-way unit toggle: **rms per sample [V]** ⟷ **density [V/√Hz]** | arg 1 `NA` | ≥ 0 | the other form, via `NA = density/√(2·TS)` (§2.1), plus *"flat to 1/(2·TS) = f Hz"* |

**1/f (flicker) noise**
| field | maps to | validation | live readout |
|---|---|---|---|
| ☐ enable | — | when off, emit `0 0` for args 3-4 | |
| Exponent α | arg 3 `NALPHA` | **0 < α < 2, open** (T3, T4); default 1.0 | *"PSD ∝ 1/f^α"* |
| Driving amplitude | arg 4 `NAMP` | > 0 | memory estimate from §2.2; label it *driving*, never *rms* |

**RTS / burst noise**
| field | maps to | validation | live readout |
|---|---|---|---|
| ☐ enable | — | when off, omit args 5-7 entirely | |
| Amplitude `RTSAM` | arg 5 | > 0 | |
| Mean **low** time `RTSCAPT` | arg 6 | **> 0** — zero pins the source high, a pure DC offset | *"duty = EMT/(CAPT+EMT) = …, mean offset = …"* |
| Mean **high** time `RTSEMT` | arg 7 | **> 0** — zero gives one-timestep spikes | same |

**Random-value source** (`trrandom`) — a separate row kind in the same table
| field | maps to | validation | live readout |
|---|---|---|---|
| Distribution | arg 1 `TYPE` | combobox `Uniform / Gaussian / Exponential / Poisson` → 1/2/3/4; never a raw integer (out-of-range emits silence) | |
| Hold time `TS` | arg 2 | **> 0**, fatal otherwise | timepoint estimate |
| Delay `TD` | arg 3 | ≥ 0 | *"holds <PARAM2> until t = TD"* |
| Param 1 | arg 4 | label **changes with distribution**: `Half-range` / `Std. deviation` / `Mean` / `Lambda` | |
| Param 2 | arg 5 | label `Offset` / `Mean` / `Offset` / `Offset` | ⚠️ *"also the operating-point value — an explicit `dc 0` is emitted"* |

**Repeatability** (section footer, one line — this is the honest part)
| field | emits | notes |
|---|---|---|
| ☐ Fixed seed `[ 12345 ]` | `setseed <n>` as the first line of `.control` | **Reproduces RTS and `trrandom` only.** The label must say so: *"White and 1/f noise are not reproducible in this ngspice build (seeded from the process id)."* That single sentence is more than the ngspice manual says, and it stops a bug report |
| Runs `[ 1 ]` | `repeat N … end` around the tran + measures | the Monte Carlo of §4.5 — free, no `alter` |

### 10.4 What the deck must emit, and in what order

⚠ **See the correction at §10.2: the carrier below is an `a` card, and a card-level `trnoise` leaks into every later transient.**


Per `ase-deck.md` §1.1's slot table:

1. **new slot, right after the netlist (step 1)** — the injected source lines, one per "inject at
   net" row, always with an explicit `dc 0` (§6.1):
   `ase_inoise_1 0 out dc 0 trnoise(1m 1u 1 0.1m 5m 18u 30u)`
2. **inside `.control`, before the first analysis** — `setseed <n>` when the seed box is ticked, and
   one `alter` per "attach to source" row:
   `alter vsup trnoise = [ 10m 1u 0 0 ]`
   (`alter` is already the orchestration primitive per F10, so this reuses that generator.)
3. **nothing else changes.** The `tran` line, the `sim_status` guard, `remzerovec`, the per-analysis
   `write`, the `op`-last ordering (F13) are all untouched — transient noise rides on the existing
   transient row.

Emit arguments **positionally, always all seven** (padding with `0`) for `trnoise` and **always all
five** for `trrandom`. Never emit a short form: T2 is a heap read, T4 is a silent zero, and the
shipped examples prove that humans get the short forms wrong.

### 10.5 What to do with the results — the part that beats ADE

The panel should not stop at stimulus. Three post-run affordances, all of which the measurements
above already validate, and none of which ADE-L offers on a transient:

1. **An honest rms.** Auto-emit `meas tran <out>_nrms RMS v(<out>) from=<t1> to=<tstop>` per selected
   output and show it in the Outputs pane — it is a scalar, so it fits the "Value" column that F13
   restricts to scalars. **Do not use `stddev()`**; §2.1 measured it 5 % high.
2. **A spectrum on demand.** `linearize` + `fft` + `settype decibel`, into its own plot. This is the
   only way to see what the noise actually did, and it needs the uniform grid `linearize` provides
   (a transient-noise plot is deliberately non-uniform, §5.1). The spectrum is not a scalar, so per
   F13 it needs a named destination — the same one a `.four`/`fft` result uses.
3. **N runs, one histogram.** §4.5: `repeat N / tran … / meas … / end`, collecting one scalar per
   run. That is a jitter histogram, a `Vth`-crossing spread, a comparator error rate — the thing
   people buy transient noise for, and something ADE-L needs a full Monte-Carlo licence to do.

Cross-reference for whoever writes the ADE-parity table: **ADE-L has no transient-noise feature at
all** (Spectre's `noisetype=tran`/`transient noise` lives in the Spectre `tran` options, not in
ADE-L's analysis chooser). Exposing this well is not parity work — it is a category where ngspice
is ahead and ASE-L can show it.

---

## 11. Gaps — what I could not settle

1. **Whether the `getpid()` seeding of the Wallace pool is fixable from outside.** It is one line
   (`wallace.c:83`) and one call site (`main.c:1371`), so an upstream patch that calls
   `initw()` *after* `.option seed=` — or re-inits the pool from `com_sseed` — would make
   `trnoise` reproducible. I did not attempt it (read-only mandate). **If the plan wants
   reproducible transient noise, that patch is the whole job**, and it is small.
2. **Whether `"ouch, trying to fetch from the past"` / `"ouch, noise data exhausted"` are reachable.**
   I could not provoke either; the `TS` breakpoints appear to make them unreachable. Both call
   `controlled_exit(1)`, so if they *are* reachable a GUI sees a hard exit with one stderr line.
3. **`trnoise` under XSPICE event-driven co-simulation and under `d_cosim`.** Not tested; the
   breakpoint interaction with `g_mif_info.breakpoint` (`vsrcacct.c` has no XSPICE arm for TRNOISE,
   but `dctran.c` does) is unexamined.
4. **`trnoise` in the `--with-ngshared` build.** `sharedspice.c:1067-1081` mirrors `main.c`'s
   `initw()` call, so the PID seeding presumably applies to a host process too — unverified, and
   §5.7 item 2 of the critique already flags that no shared build exists on this machine.
5. **The `setseed 12` vs `set rndseed=12 ; setseed` stream difference** (§4.3). Both are
   reproducible; I did not chase why they differ.
6. **`.probe`/`savecurrents` interaction with the injected current source.** Not tested.
7. **Whether the manual's §11.3.11 parameter names match these seven positions.** I read the source
   and measured; I did not fetch the manual. `docs-web.md` §2.12 is the other half of that check.
