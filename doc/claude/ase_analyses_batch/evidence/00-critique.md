# Completeness critique of the 17-dossier extraction pass

Reader: the session that writes the ASE-L analyses plan.
Scope: what is **missing, contradictory, or unverified** across
`/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/dossiers/`.
I read all 17 files end to end.

Tree: `/home/analog/dev/ngspice`, branch `ver_50`, `git describe = ngspice-46-419-gccebdf2a2`.
Binary for every empirical claim: `/home/analog/dev/ngspice/build-ver_50/src/ngspice` (`ngspice-46+`).
Scratch decks: `/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/critique/`.
Nothing in either repository was modified.

**MEASURED-HERE** marks something I ran myself in this session. **SOURCE-HERE** marks
something I read in this tree myself. Everything else is attributed to the dossier that
found it.

---

## 0. Verdict in one paragraph

The extraction is very good and, for the twelve *registered* analyses, parameter-complete —
every entry of `analInfo[]` has a per-parameter table somewhere, and every analysis-relevant
`spcp_coms[]` command has an owner. The gaps are not in the analysis registry; they are in
four other places: (a) **transient noise and `trrandom`**, an entire second stochastic-source
surface that the manual documents and *no source dossier covers at all*; (b) **five
contradictions between dossiers**, four of which I resolved by reading source or running the
binary, one of which changes a headline number (`itl1/itl2/itl4` are floored at 100, so the
shipped defaults 50 and 10 are inert — three dossiers present them as live); (c) **the "how do
I actually drive this" questions** — abort, multi-plot capture, capability probing, plot→analysis
mapping — which every dossier flagged as open and which I closed here; and (d) **a new,
four-line, reproducible SIGSEGV** in `.disto` that a naive GUI will hit on its first
"operating point + distortion" run. Section 6 is the list of defects I found that no dossier
reported.

---

## 1. Cross-check against `docs-web.md`: what the manual documents that no source dossier covered

I walked `docs-web.md` §13 ("FOUND ONLY IN DOCS — the completeness net") item by item and
looked for a source-side owner. Most items have one. These do not.

### 1.1 HOLE — transient noise (`trnoise`) and `trrandom` have no source-side dossier

`docs-web.md` §2.12 documents transient noise from manual §11.3.11 and correctly calls it
"an analysis that is not a card". **No source dossier picks it up.** `options.md` lists the
`notrnoise` *variable*; `orchestration.md` names the directory `src/frontend/trannoise/`. Nobody
documents the grammar, the parameters, the defaults, the seeding, or the interaction with
`.tran`.

Worse, the surface is **twice as large as the manual's completeness net suggests**, because a
second stochastic source type sits beside it and appears in **no** dossier, docs or source:

```
SOURCE-HERE  src/spicelib/devices/vsrc/vsrc.c:24-25
  IOP ("trnoise",  VSRC_TRNOISE,  IF_REALVEC, "Transient noise description"),
  IOP ("trrandom", VSRC_TRRANDOM, IF_REALVEC, "random source description"),
SOURCE-HERE  src/spicelib/devices/isrc/isrc.c:26-27   -- the identical pair on ISRC
```

`trrandom` is a per-`.tran` random-value source (uniform / gaussian / exponential / poisson,
with a hold time) and is exactly the primitive an ADE-beating "statistical transient" panel
would want. `src/ngspice.txt` (the built-in `help` database) mentions **neither** word — grep
returns 0 hits — so the only in-tree documentation is the parameter table itself.

**MEASURED-HERE**, and it resolves `docs-web.md`'s contradiction C8 / gap 2 outright:

```spice
* /tmp/.../critique/tn.cir
i1    0 mid dc 0 trnoise(1m 1u 0 0)
irts  0 mid dc 0 trnoise(0 0 0 0 5m 18u 30u)
irand 0 mid dc 0 trrandom(2 10u 0 1)
r1 mid 0 1k
.control
tran 1u 200u
let s = stddev(v(mid))
echo "stddev(v(mid)) = $&s"
.endc
```
→ `stddev(v(mid)) = 947.762`, rc 0.

**The manual's "isrc not yet available" (§11.3.11) is wrong for this tree.** Current sources
take both `trnoise` and `trrandom` and they work. Trust the source and the measurement.

**What the plan must commission:** one pass over `src/frontend/trannoise/` (`1-f-code.c`,
`wallace.c`, `FastNorm3.c`), `vsrcpar.c`/`isrcpar.c`'s `TRNOISE`/`TRRANDOM` arms and
`vsrcload.c`/`isrcload.c`'s evaluation, producing the parameter list, defaults, units, seeding
rule and the `notrnoise` kill switch. Without it a "noise" menu can only offer `.NOISE`, which
is half the feature.

### 1.2 HOLE — `nosavecurrents` is documented by the manual and does not exist in this tree

`docs-web.md` §5 and §13.2 item 16 list `nosavecurrents` from manual §13.7 as "the documented
workaround for mixing `savecurrents` with AC". **SOURCE-HERE:**

```
grep -rn "nosavecurrents" . --include=*.c --include=*.h --include=*.in --include=*.txt
→ (no output)
```

The string appears nowhere in the tree. A GUI that emits `set nosavecurrents` to make a
`savecurrents` deck survive an AC run gets silence and the AC run still misbehaves. This is a
**new doc-vs-source contradiction** no dossier caught. `options.md`'s Table C/E — the catalogue
of every front-end variable — does not list it either, correctly, but does not flag its absence.

### 1.3 HOLE — `diode_cj0`, `diode_rser`, `rsdiode` are absent from the options catalogue

`docs-web.md` §4.5 documents them from manual §11.1.5. `options.md` is the options dossier and
its five tables do **not** contain them (they are not in `OPTtbl`, so mechanism A missed them,
and §4.1's mechanism-C list omits them). **SOURCE-HERE** they are ordinary `cp_getvar`
mechanism-C variables:

```
src/spicelib/devices/dio/diosetup.c:89    cp_getvar("diode_cj0",  CP_REAL, &cdiode, 0)
src/spicelib/devices/dio/diosetup.c:241   cp_getvar("diode_rser", CP_REAL, &rsdiode, 0)
src/spicelib/devices/dio/diosetup.c:245   fprintf(stderr, "Diode series resistance in model %s set to %e Ohm\n", ...)
```

They silently change every diode in the netlist, i.e. they change results. They belong in the
options catalogue with a "this alters your models" warning.

### 1.4 Manual items that DO have an owner (recorded so nobody re-hunts them)

`.SNDPARAM`/`.SNDPRINT` → `dotcards.md` §3.24 (build-gated OFF here: `HAVE_LIBSNDFILE` and
`HAVE_LIBSAMPLERATE` both undef, and the cards then fall through to
`Internal Error: ft_cktcoms: bad commands`). `.PROBE` → `dotcards.md` §3.17. `par('expr')` →
`measure.md` §1.7(c). `speedcheck`/`deltacheck` → `an-core.md` §5.8. `--enable-stepdebug` →
`convergence.md` §9.6. `wrnodev` → `convergence.md` §1.6. `aspice`/`snsave`/`snload`/`iplot`/
`trace`/`stop` → `commands.md` §12, §4. `rusage` resources → `options.md` Table B. `.step`
absence → everyone. `ngbehavior` → `options.md` §4.2 + `docs-web.md` §12.

### 1.5 The other direction — source-only capabilities the manual never mentions, worth exposing

These are documented by *no* published manual and are real, working GUI material:

| capability | anchor | why it matters |
|---|---|---|
| `.dc <resistor> a b s` and `.dc temp a b s` | `dctrcurv.c:89-151`; `an-core.md` §4.5 | the manual's `.dc` general form (§11.3.2) does mention them but §11.3.2's *syntax line* does not; a GUI can offer four sweep kinds from one card |
| `.sens` glob filters | `inp2dot.c:529-565`, `cktsens.c:37-67`; `an-smallsig.md` §7.5 | documented in the manual §11.3.7 but absent from `src/ngspice.txt`; the only thing that makes `.sens` usable interactively |
| `$plots` | `src/frontend/options.c:465-472`; §5.2 below | the machine-readable plot index. Manual §13.7 lists it as read-only and says nothing about its shape |
| `devhelp -csv -type -flags` | `src/frontend/device.c:305-345`; §5.6 below | lets a GUI predict the `.sens` vector list offline |
| `casemode` / `curcasemode` | fork-local, `docs-web.md` §14 | 0 hits in `manual.xhtml` |
| `optran` armed by default | `src/frontend/init.c:77-94` | the manual calls the transient OP "optional"; here it is on |

---

## 2. Contradictions between dossiers — resolved

Five real ones. I verified each myself rather than arbitrating on plausibility.

### C1 — `itl1` / `itl2` / `itl4` are floored at 100. THREE dossiers present them as live.

* `convergence.md` §5.1 and §12 item 2: "`niiter.c:38-39` silently raises maxIter to 100 …
  the shipped defaults `itl2 = 50` and `itl4 = 10` are therefore *both* effectively 100."
* `an-core.md` §2.2, §7 and `options.md` §2.2 and `dotcards.md` §3.21 all list
  `itl2 = 50`, `itl4 = 10` with no floor mentioned. `options.md` §2.2 even describes `itl4` as
  "per-timepoint iteration limit; exceeding it halves the timestep" with no caveat.

**SOURCE-HERE, `src/maths/ni/niiter.c:37-39`:**
```c
    /* some convergence issues that get resolved by increasing max iter */
    if (maxIter < 100)
        maxIter = 100;
```
**`convergence.md` is right.** Every `NIiter()` caller — `CKTop` rung 1 (`itl1`), every inner
step of gmin/source stepping (`itl2`), `DCtran`'s per-timepoint loop (`itl4`) and `DCtrCurv`'s
fast path (`itl2`) — is clamped. **Consequence for the plan:** a "transient iteration limit"
spinner that offers 10 is a lie; only values above 100 do anything. The GUI should clamp its
input to ≥100 and say why. Fix the three dossiers' tables when quoting them.

### C2 — `ramptime` does NOT ramp SPICE sources.

* `options.md` §2.9: "**NOT a general supply ramp.** … Ordinary `V`/`I` sources are untouched.
  If the manual describes this as 'supply ramping', the manual overstates it."
* `convergence.md` §10.4: "linear supply ramp `CKTtime/ramptime` applied to V/I/B sources
  (`src/spicelib/devices/vsrc/vsrcload.c:467`, `isrc/isrcload.c:450`, `asrc/asrcload.c:56`)".

**SOURCE-HERE.** Those three line numbers are correct but they sit inside a dead `#ifdef`:
```c
/* vsrcload.c:465-471, isrcload.c:448-454, asrcload.c:54-60 — identical shape */
#ifdef XSPICE_EXP
            value *= ckt->CKTsrcFact;
            value *= cm_analog_ramp_factor();
#else
            if (ckt->CKTmode & MODETRANOP)
                value *= ckt->CKTsrcFact;
#endif
```
`XSPICE_EXP` is **defined nowhere**: not in `configure.ac`, not in `config.h.in`, not in
`build-ver_50/src/include/ngspice/config.h`; grep over `src/` finds only the eight `#ifdef`
guards themselves. The only live readers of `enh->ramp.ramptime` are
`src/xspice/cm/cm.c:507-522` (`cm_analog_ramp_factor()`, which a code model must *choose* to
call) and `src/spicelib/analysis/dctran.c:220-221` (one breakpoint).

**`options.md` is right; `convergence.md` §10.4 is wrong.** `ramptime` is an XSPICE code-model
knob plus a breakpoint. Do not offer it as "supply ramping" in a convergence panel.

### C3 — `write <file> all` writes the CURRENT plot only.

`ase-deck.md` §9 lists this as an open question ("Whether `write <file> all` captures ALL plots
… must be checked before relying on it"). It is load-bearing, because `noise` and `disto` each
produce 2+ plots and ASE-L emits one `write` per analysis.

**MEASURED-HERE** (`/tmp/.../critique/w2.cir`, `set filetype=ascii`, after `disto dec 2 1k 10k`
which leaves `disto1` = 2nd harmonic and `disto2` = 3rd harmonic, current = `disto2`):

| command | `Plotname:` lines in the file |
|---|---|
| `write w_cur_all.raw all` | `DISTORTION - 3rd harmonic` — **one plot** |
| `write w_named.raw disto1.all disto2.all` | `DISTORTION - 2nd harmonic`, `DISTORTION - 3rd harmonic` |
| `setplot disto1` / `write f all` / `set appendwrite` / `setplot disto2` / `write f all` | both |

**Answer: `all` is a vector wildcard inside one plot, not a plot wildcard.** The general
recipe is in §5.2.

### C4 — the `fft`/`spec`/`psd` plot typename is `spN`, not `spectN`; `linearize`'s Plotname is not `transient`.

`outputs.md` §3's literal table says `fft`/`spec` → `Plotname: spectrum`, "typename `spect<N>`",
and `linearize` → `Plotname: transient`, "typename `tran<N>`". `measure.md` §4.6 MEASURED
`sp2 (Spectrum)`.

**SOURCE-HERE + MEASURED-HERE.** `plotabs[]` (`src/frontend/typesdef.c:67-90`) has
`{ "sp", "sp" }` at index 18 and `{ "spect", "spect" }` at index 20, and `ft_plotabbrev()`
(`typesdef.c:341-345`) returns the **first** entry whose pattern is a substring — so `"spectrum"`
matches `sp` and `spect` is unreachable. `com_linearize` does
`plot_alloc("transient"); new->pl_name = tprintf("%s (linearized)", old->pl_name)`
(`src/frontend/linear.c:95-96`), so `"transient"` is the *abbreviation lookup key*, never the
`Plotname:`. Live `setplot` from `/tmp/.../critique/t1.cir`:

```
Current sp4    * critique probe 1 (Spectrum)
        tran4  * critique probe 1 (Transient Analysis (linearized))
        tran3  * critique probe 1 (Transient Analysis)
```

**`measure.md` is right; `outputs.md` §3's last three rows are wrong.** The `Plotname:` literals
are `Spectrum`, `PSD`, `<old> (linearized)`, `<old> (cut out)` / `<old> (copy)`. A GUI matching
`Plotname:` against `outputs.md`'s table would miss every post-processed plot.

### C5 — the squared-noise switch is `sqrnoise`, not `.options noisesquared`/`squared`.

`outputs.md` §3 writes "`.noise` with `.options noisesquared`/`squared` set". Every other
dossier (`an-smallsig.md` §3.8, `dotcards.md` §3.8, `docs-web.md` §2.5, `options.md` Table C)
says `sqrnoise`.

**SOURCE-HERE** `noisean.c:242` is the only read:
`data->squared = cp_getvar("sqrnoise", CP_BOOL, NULL, 0) ? 1 : 0;`
**MEASURED-HERE** (`/tmp/.../critique/sq1-3.cir`), and worth recording because it settles the
mechanism question too — it works from **both** doors:

| deck | plot titles | `onoise_total` |
|---|---|---|
| default | `Noise Spectral Density Curves` / `Integrated Noise` | `1.829825e-06` |
| `.options sqrnoise` | `… - (V^2 or A^2)/Hz` / `Integrated Noise - V^2 or A^2` | `3.348261e-12` |
| `set sqrnoise` (in `.control`) | same as above | `3.348261e-12` |

`outputs.md` is wrong on the name. `sqrnoise` is a mechanism-C variable: `.options sqrnoise`
and `set sqrnoise` are equivalent.

### C6 (minor) — `minbreak`'s auto-default

`dotcards.md` §3.21's table gives `minbreak` as "derived: `CKTmaxStep*5e-5`". That is the
**non-XSPICE** arm. `convergence.md` §6.3 and `an-core.md` §7 have it right: with `XSPICE`
defined (which it is here), `dctran.c:163-164` uses `10.0 * CKTdelmin` = `1e-10 * tmax`, five
and a half orders of magnitude smaller. Use `convergence.md`'s value.

---

## 3. Uncovered surface — the two registry walks

### 3.1 `analInfo[]` — complete, with two phantoms

**SOURCE-HERE**, `src/spicelib/analysis/analysis.c:8-59`. Fourteen `extern` declarations,
twelve of which have a definition anywhere in `src/`:

| # | symbol | `IFanalysis.name` | defined at | parameter-level owner | verdict |
|---|---|---|---|---|---|
| 0 | `OPTinfo` | `options` | `cktsopt.c:389` | `an-core.md` §2 + `options.md` (98-row table) | **covered ×2** |
| 1 | `ACinfo` | `AC` | `acsetp.c:94` | `an-smallsig.md` §2 | covered |
| 2 | `DCTinfo` | `DC` | `dctsetp.c:104` | `an-core.md` §4 | covered |
| 3 | `DCOinfo` | `OP` | `dcosetp.c:32` | `an-core.md` §3 (zero parms) | covered |
| 4 | `TRANinfo` | `TRAN` | `transetp.c:72` | `an-core.md` §5 | covered |
| 5 | `PZinfo` | `PZ` | `pzsetp.c:90` | `an-smallsig.md` §4 | covered |
| 6 | `TFinfo` | `TF` | `tfsetp.c:61` | `an-smallsig.md` §5 | covered |
| 7 | `DISTOinfo` | `DISTO` | `dsetparm.c:82` | `an-smallsig.md` §6 | covered |
| 8 | `NOISEinfo` | `NOISE` | `nsetparm.c:95` | `an-smallsig.md` §3 | covered |
| 9 | `SENSinfo` | `SENS` | `senssetp.c:106` | `an-smallsig.md` §7 | covered |
| — | `PSSinfo` | `PSS` | `psssetp.c:68` | `an-rf-pss.md` §3 | covered, **source-only, never executed** |
| — | `SPinfo` | `SP` | `spsetp.c:101` | `an-rf-pss.md` §2 | covered + measured |
| — | `SEN2info` | — | **nowhere** | `an-smallsig.md` §8 | covered as unreachable |
| — | `HBinfo` | — | **nowhere** | `an-rf-pss.md` §4 | covered as unreachable |

**Nothing fell through.** Every settable and askable `IFparm` of every registered analysis has
a table entry in some dossier. The only registry-level residue is that `PSS` has never been
built or run by anyone on this pass (§7 item 1).

One correction to the indices: `an-core.md` §1.1 and `an-smallsig.md` §1.2 both list `SP` at
index 10. **SOURCE-HERE** the `#ifdef` order in `analysis.c:45-57` is `WITH_PSS`, then
`WANT_SENSE2`, then `RFSPICE`, so with the flags of *this* build SP is index 10 — correct — but
`an-rf-pss.md` §2.1 states the same order with `PSS` inserted before `SENSE2` before `SP`, which
matches. All three agree; no action. The warning both give ("do not hard-code an index ≥ 10")
stands.

### 3.2 `spcp_coms[]` — complete for analyses, but `help all` truncates

`commands.md` §1.3 inventories all 133 entries and every analysis-relevant one has an owner:
run control (`run resume stop step reset remcirc setcirc state status delete save trace iplot
where`), the ten analysis verbs, the option verbs (`option options set setcs unset optran
setseed`), parameter change (`alter altermod alterparam mc_source circbyline`), post-processing
(`meas fourier fft psd spec linearize cutout remzerovec settype deftype`), output (`write wrdata
wrs2p print plot asciiplot load display setplot destroy diff`), XSPICE (`esave eprint eprvcd
edisplay codemodel osdi`), introspection (`rusage sysinfo inventory devhelp show showmod listing
dump mdump mrdump snsave snload`).

**Nothing analysis-relevant fell through.** But one *claim about* the table is wrong and it
matters, because a dossier recommends it as the capability probe:

> `an-rf-pss.md` §5.1: "**Best probe: `help all`** … One invocation enumerates every analysis
> command the binary has."

**SOURCE-HERE, `src/frontend/com_help.c:56`:**
```c
        for (numcoms = 0; cp_coms[numcoms].co_func != NULL; numcoms++)
```
The loop **stops at the first entry whose `co_func` is NULL**. `spcp_coms[]` has eleven such
entries — the control-flow keywords `while repeat dowhile foreach if else end break continue
label goto` at `commands.c:568-610`. Everything from `cdump` (`:612`) onward is invisible.

**MEASURED-HERE** (`/tmp/.../critique/ha.cir`): `help all` prints **115** lines and omits
`linearize`, `cutout`, `wrnodev`, `optran`, `devhelp`, `inventory`, `settype`, `strcmp`,
`strstr`, `strslice`, `fopen`, `fread`, `fclose`, `cdump`, `mdump`, `mrdump`, `check_ifparm`.

It happens to list every analysis verb (they sit at `commands.c:312-362`, well before the NULL
block), so `an-rf-pss`'s *conclusion* survives — but the reasoning does not, and the plan must
not generalise `help all` to "the command inventory". The reliable per-command probe is the
single-name form, whose loop terminates on `co_comname == NULL` (`com_help.c:84`):

**MEASURED-HERE** (`/tmp/.../critique/hp.cir`, all on **stdout**):
```
help linearize  → linearize  [ vec ... ] : Convert plot into one with linear scale.
help optran     → optran : Prepare optran by setting 6 flags
help sp         → sp [.sp line args] : Do an S-parameter analysis.
help pss        → Sorry, no help for pss.
help hb         → Sorry, no help for hb.
```
(`help devhelp` prints nothing at all — a third, unexplained anomaly; do not probe with it.)

---

## 4. NEW defects I found that no dossier reported

### D1 — `.disto` SEGFAULTS whenever its save list resolves to nothing. Four-line repro.

This is the sharpest finding of this pass. **MEASURED-HERE**, `/tmp/.../critique/d1.cir`:

```spice
* minimal: disto whose save list is empty
v1 in 0 dc 1 ac 1 distof1 1 0
r1 in mid 1k
c1 mid 0 1n
.save v(nosuchnode)
.disto dec 2 1k 10k
.control
run
.endc
.end
```
```
Error: no data saved for Small signal distortion analysis; analysis not run
Segmentation fault      rc=139
```

The identical deck with `.ac` or `.noise` substituted returns cleanly (`doAnalyses: not found`,
rc=1). **SOURCE-HERE** the cause is that `DISTOan` never captures `OUTpBeginPlot`'s return:

```
src/spicelib/analysis/distoan.c:516, 540, 563, 584, 606
        SPfrontEnd->OUTpBeginPlot (ckt, ckt->CKTcurJob, "DISTORTION - …", …, &acPlot);
                                   ^ return value discarded on all five output plots
vs. src/spicelib/analysis/acan.c:169-175
        error = SPfrontEnd->OUTpBeginPlot(…);  tfree(nameList);  if (error) return(error);
```
`beginPlot()` returns `E_NOTFOUND` and leaves `acPlot` NULL; the next
`OUTattributes(acPlot, …)` / `CKTacDump(…, acPlot)` dereferences it.

**Every deck shape that reaches it, MEASURED-HERE:**

| deck | route | rc |
|---|---|---|
| `.op` + `.disto`, plain `-b`, no `.control` | dot cards; `.op` installs `com_save2(&all,"OP")` | **139** |
| `.tf` + `.disto`, plain `-b` | same, via `"TF"` | **139** |
| `.op`/`.tf` + `.disto` + `.control run` | same | **139** |
| `.control` with `save v(nosuch)` then `disto …` | **ASE-L's exact shape** | **139** |
| `.control` with `save v(mid)` then `disto …` | a *resolving* save | 0 |
| `.op` + `.disto` with `-b -r file.raw` | `-r` skips `ft_savedotargs()`, nothing scopes | 0 |
| `.disto` alone | | 0 |

**Why the plan must care:** `.op + .disto` is the single most obvious deck a GUI produces the
first time a user ticks two boxes. And ASE-L already emits `save` lines from its Outputs pane
(`ase::op_ctl_saves`), so a stale or misspelt output name plus an enabled distortion analysis
crashes the simulator with no diagnostic beyond one stderr line. Mitigations, in order:
(1) never emit a narrowed `save` in the same run as `disto`; (2) validate every `save` name
against the netlist before emitting (`ase::netlist_map_resolve` already exists and
`ase-state.md` §3.4 notes it is unused); (3) the one-line upstream fix is to capture and check
`error` at all five sites, mirroring `acan.c`.

`pzan.c:159` and `noisean.c:532` have the same unchecked pattern. **MEASURED-HERE**: PZ with an
empty save list does **not** crash (rc 0), and NOISE's is the already-documented silent
Integrated-Noise loss (`an-smallsig.md` §1.10). Only DISTO is fatal.

### D2 — `ac lin 2 <f1> <f2>` silently produces ONE point

**SOURCE-HERE**, `src/spicelib/analysis/acan.c:103-114`:
```c
        case LINEAR:
            if (job->ACnumberSteps - 1 > 1)
                job->ACfreqDelta = (stop - start) / (job->ACnumberSteps - 1);
            else
                job->ACfreqDelta = 0;    /* "a linear step with only one point" */
```
`numsteps == 2` gives `2 - 1 = 1`, which is not `> 1`, so it falls into the one-point arm.

**MEASURED-HERE** (`/tmp/.../critique/t4.cir`, `ac lin N 1k 11k`, `length(frequency)`):

| `numsteps` | 1 | **2** | 3 | 11 |
|---|---|---|---|---|
| points | 1 | **1** | 3 | 11 |

`an-smallsig.md` §2.3 measured `lin 11`, `lin 1` and five `dec`/`oct` cases but never `lin 2`,
so it reads as "`numsteps` is the total" with no exception. `an-rf-pss.md` §2.4 *does* record
the identical `numsteps <= 2 → delta = 0` shape for `.sp` — nobody noticed AC has it too.
A GUI's "Linear / Points" form must reject 2, or silently promote it to 3.

### D3 — `sens … ac` under `option klu` SEGFAULTS; `sens … dc` under KLU is fine

`an-smallsig.md` §12 lists this as an unresolved gap ("the KLU refusal guard in `sens_sens` is
commented out … Someone must run it"). **MEASURED-HERE** (`/tmp/.../critique/sv.cir`, an
R–C–R divider, `sens v(mid) r1 r2`):

| solver | mode | rc | result |
|---|---|---|---|
| sparse | dc | 0 | `r1 = -2.50000e-04`, `r2 = 2.499998e-04` |
| klu | dc | 0 | `r1 = -2.50000e-04`, `r2 = 2.499998e-04` — **identical, safe** |
| sparse | `ac dec 1 1k 10k` | 0 | runs |
| **klu** | **`ac dec 1 1k 10k`** | **139** | **SIGSEGV** |

**Rule for the GUI:** DC sensitivity is safe under either solver. **Block `option klu` +
AC-mode `.sens`.** (NOISE and PZ already refuse KLU explicitly with a clean `E_UNSUPP`;
SENS's guard at `cktsens.c:97-105` is commented out, which is the bug.)

### D4 — in batch mode ngspice installs NO signal handlers; SIGINT is immediately fatal

Nobody answered "how do I abort a run". **SOURCE-HERE, `src/main.c:1217-1220`:**
```c
    /* Set up signal handling */
    if (!ft_batchmode) {
        signal(SIGINT, (SIGNAL_FUNCTION) ft_sigintr);
        signal(SIGFPE, (SIGNAL_FUNCTION) sigfloat);
#ifdef SIGTSTP
        signal(SIGTSTP, …); signal(SIGCONT, …);
```
**MEASURED-HERE** (`/tmp/.../critique/long.cir`, `tran 1n 200m` in `.control`, one `SIGINT`
after 3 s): the process dies on the **first** signal, `rc=130`, **no rawfile written**, the
`write` after the `tran` never runs.

So the abort story is a clean split the plan must state:

| mode | SIGINT | result |
|---|---|---|
| interactive / `-p` | `ft_sigintr` runs; during a run `ft_setflag` makes it **pause** (resumable with `resume`); 3 presses `controlled_exit(1)` | partial plot survives in memory |
| **`-b` batch** | no handler installed → **default disposition, rc 130** | **nothing written, no partial results** |

`ft_batchmode` is also set implicitly whenever stdin is not a tty (`main.c:1175-1180`), so
`ngspice deck.cir < /dev/null` is in this bucket too. Same story for `SIGFPE`: a deck that would
recover via `fperror` + longjmp in interactive mode dies (rc 136) in batch. ASE-L's SIGKILL Stop
(`ase-deck.md` §5.7) is therefore no worse than SIGINT — but the GUI must never promise "stop
and keep what you have" for a batch run. If graceful abort matters, the routes are `-p` pipe
mode (SIGINT → pause, then `write`, then `quit`) or a cooperative flag file checked by a
generated `.control` loop.

### D5 — two `.sens` **cards** abort; two `sens` **commands** are fine

`outputs.md` §6.5 measured `malloc(): unsorted double linked list corrupted`, rc=134 and left it
unexplained. **MEASURED-HERE** the disambiguation matters:

```
.sens v(mid) r1 / .sens v(mid) r2  as CARDS + .control run   → rc 134 (SIGABRT)
sens v(mid) r1  / sens v(mid) r2   as COMMANDS in .control   → rc 0, both run
```

Almost certainly the process-global `Sens_filter` (`cktsens.c:33`, freed and rebuilt per card at
`inp2dot.c:533-534` while leaking its strings) — `dotcards.md` gap 6 predicted exactly this and
could not construct the test. **ASE-L's `.control`-command route dodges it**, but
`ase-deck.md` §7.3 wants a dot-card path for `.four`/`.meas`/`.probe`; if that path ever carries
`.sens`, one sensitivity per deck is the limit.

### D6 — `.options oldlimit` is definitively lost on the `.control`-command route

`an-core.md` gap 4 flagged the omission and said "I did not measure the consequence."
**SOURCE-HERE** it needs no measurement — the field is simply never copied.
`CKTnewTask()`'s "special" arm (`cktntask.c:36-88`, inside `#if (1) /*CDHW*/`, i.e. always
compiled) copies 45 `TSK*` fields and leaves three as bare comments:
```c
        /* minBreak */      (cktntask.c:51)
        /* delmin */        (cktntask.c:61)
        /* fixLimit */      (cktntask.c:68)
```
`minBreak` and `delmin` are recomputed per run (`dctran.c:161-168`, `traninit.c:36`), so they do
not matter. **`TSKfixLimit` is not**, so `.options oldlimit` set by a deck is silently dropped
the moment the analysis is issued as `tran`/`dc`/`op` from `.control` — which is precisely
ASE-L's shape. Small, but it is a "the option box did nothing" bug waiting to be filed against
the GUI.

---

## 5. GUI-blocking unknowns — answered here, or with a precise close-out

Every dossier's gap list ends with the same handful of questions. Here they are, answered.

### 5.1 "How do I know what analyses this ngspice has?"

**Answered.** Three probes, in order of reliability, all in one `-b` run of a trivial deck:

1. **`help <name>` per analysis verb** — the only loop that walks the whole command table
   (`com_help.c:84`). `Sorry, no help for pss.` on stdout means absent. Cost: one line per verb.
2. **`help all`** — one invocation, lists all ten analysis verbs, but **truncates at the
   control-flow keywords** (§3.2). Fine for analyses, wrong as a general inventory.
3. **`devhelp vsource | grep portnum`** — a second, independent RFSPICE probe.
   **MEASURED-HERE** on this build:
   ```
   25  portnum  inout  Port index
   26  z0       inout  Port impedance
   28  pwr      inout  Port Power
   27  freq     inout  Port frequency
   29  phase    inout  Phase of the source
   ```
   Those entries are inside `#ifdef RFSPICE` (`vsrc.c:31-37`), so their absence proves
   `--disable-sp`. This closes `an-rf-pss.md` gap 3.
   Likewise **`devhelp`** with no argument enumerates the compiled-in device families;
   **MEASURED-HERE** it lists 0 rows matching `^(NUMD|NBJT|NUMOS|NDEV)` on this build, which is
   the CIDER probe `cider-devices.md` §2.8 wanted.

There is still **no probe for `PREDICTOR`** other than setting `option newtrunc` and watching
stderr for `Warning: Option 'newtrunc' ignored, …` (`cktsopt.c:199-207`), and none for
`HAVE_LIBFFTW3`, `HAVE_LIBSNDFILE`, `USE_OMP`. `$xspice_enabled` / `$osdi_enabled` are the only
two variables set at startup (`main.c:940-948`).

### 5.2 "What is the plot called, and how do I capture ALL of them?"

**Answered, and this is the single most useful thing in this critique.**

Two variables together form a complete machine-readable results index, and **no dossier states
them as a pair**:

* **`$plots`** — the list of every plot typename. **MEASURED-HERE**, `set` shows it as
  `* plots ( const op1 disto1 disto2 )` and `echo $plots` prints
  `const op1 disto1 disto2`. It is iterable: `foreach p $plots … end` works.
* **`$curplotname`** — after `setplot <p>`, this is the **`Plotname:` literal** of `<p>`
  (`Operating Point`, `DISTORTION - 2nd harmonic`, `Integrated Noise`, …).

So `setplot $p` + `echo $curplotname` is a plot→analysis map with no string construction and no
counter guessing. That kills the whole "never assume `tran1`" class of problem.

**The general multi-plot capture recipe** (MEASURED-HERE end to end,
`/tmp/.../critique/g4.cir`, rc 0):

```spice
.control
set filetype=ascii            $ or binary
set appendwrite
op
noise v(mid) v1 dec 2 1k 10k
disto dec 2 1k 10k
foreach p $plots
  setplot $p
  write <rawfile> all
end
.endc
```
produces a single rawfile containing **every** plot:
```
Plotname: constants
Plotname: Operating Point
Plotname: Noise Spectral Density Curves
Plotname: Integrated Noise
Plotname: DISTORTION - 2nd harmonic
Plotname: DISTORTION - 3rd harmonic
```
This closes `ase-deck.md`'s §7.4 landmine ("`noise` and `disto` silently lose a plot"), its §9
open question, and `an-rf-pss.md`'s design note 6 (PSS's two plots) in one stroke — the loop is
analysis-blind, so PSS, SP, `keepopinfo` extras and `linearize`/`fft` derivatives all come along
for free. Note the loop also captures `const`; the reader filters `Plotname: constants`, which
it must do anyway (`doc/codex/issues/0059`).

Two cautions **MEASURED-HERE** while building it: the `disto` plots came back as
`disto2`/`disto3`, not `disto1`/`disto2` (global counter); and a `.control` `if` comparing
strings (`if "$p" ne "const"`) silently takes the false branch — `orchestration.md` §1.2's
"loop conditions see vectors only" bites here, so filter on the reader side, not in the deck.

### 5.3 "How do I read a measurement result back?"

**Already answered** by `measure.md` §2 and I have nothing to add: use the `meas` **command**
inside `.control` (it creates a length-1 vector via `com_let`, `measure.c:138`), redirect its
text with `meas … > file` for full precision, and/or hoist the scalars into a fresh plot
(`setplot new` / `let m_x = tran1.x` / `write`). Do **not** use `.meas` dot cards with `-r`
(refused, `measure.c:241-247`), do not use `expr=` (broken), and do not re-run a circuit in one
session with `param=` (one-shot). The 7-significant-digit ceiling on the vector
(`"%e"` at `measure.c:138`) is real; parse the printed line if you need more.

### 5.4 "How do I abort a run?"

**Answered in D4.** Batch: you cannot, gracefully. Pipe mode: SIGINT pauses.

### 5.5 "Does a bare `run` dispatch every analysis card?"

`docs-web.md` gap 4 flags this as unresolved and says it "decides whether the GUI emits cards or
issues commands". **MEASURED-HERE: yes** — a deck with `.noise .tf .sens .disto` (no `.op`) and
a `.control run` executed TF, NOISE and SENS (they produced plots; only AC/DC/TRAN/DISTO
reported `no data saved`, i.e. a save-scope failure, not a dispatch failure). `if_run()`'s `run`
arm hands the deck's whole `ci_defTask` to `doAnalyses` (`spiceif.c:373-386`), which loops the
entire `analInfo[]` table (`cktdojob.c:176-213`) — nothing filters by type. Manual §13.5.68's
list of only `.ac/.op/.tran/.dc` is **incomplete**; trust the source.

But this is a trap, not a green light: the same experiment is what surfaced D1. **The plan's
recommendation should stay "emit `.control` commands, one analysis at a time"** — that route
avoids the `analInfo[]` reordering, the `.op`/`.tf` save-scope starvation, the double-run in
`-b`, the two-`.sens` abort *and* the DISTO crash.

### 5.6 "How does the GUI build a `.sens` parameter picker without running a 90-vector sweep?"

`an-smallsig.md` §7.4 measures that a three-device deck yields ~90 sensitivity vectors and says
"a GUI must offer filtering by default" — but gives it no way to *predict* the list.

**Answered.** `devhelp -csv -type -flags <device>` prints exactly the four facts
`cktsgen.c:193-216`'s eligibility rule needs. **MEASURED-HERE** for `resistor`:
```
Instance Parameters
id#, Name, Dir, Type, Flags, Description
1, resistance, inout, real, P,  Resistance
1, r,          inout, real, PR, Resistance
10, ac,        inout, real, AA, AC resistance value
8, temp,       inout, real, ZU, Instance operating temperature
14, dtemp,     inout, real, Z,  Instance temperature difference …
```
**SOURCE-HERE** the legend is `src/frontend/device.c:305-345`: `X`=`IF_NONSENSE`,
`R`=`IF_REDUNDANT`, `P`=`IF_PRINCIPAL`, `A`=`IF_AC`, `AA`=`IF_AC_ONLY`, `N`=`IF_NOISE`,
`Q`/`Z`/`QO`/`U` = the query/uninteresting bits. `Dir` encodes the IOP/IP/OP macro:
`inout` = `IF_SET|IF_ASK`, `in` = set-only, `out` = ask-only.

So the offline predicate is: **`Dir == inout` AND `Type == real` AND flags contain neither `X`
nor `R`** (and, in DC mode, neither `A` nor `AA`). Applied to the table above it yields exactly
`r1` (the `P` one, named bare), `r1_temp`, `r1_dtemp`, `r1_l`, `r1_w`, `r1_m`, `r1_tc`, … —
which is precisely the list `an-smallsig.md` §7.4 measured. The same table is the raw material
for a `@dev[param]` output picker and a `.dc`/sweep-target picker.

### 5.7 The remaining GUI-blocking unknowns I could NOT close — and exactly what would close them

1. **PSS has never been executed by anyone.** `WITH_PSS` is off in `build-ver_50` and both trees
   are read-only. *Close it by:* `mkdir build-pss && cd build-pss && ../configure --enable-pss &&
   make -j8`, then run `examples/pss/ring_osc_pss_ctrl.cir` and `vdp_osc_pss_ctrl.cir` and record
   (a) the two `Plotname:` literals, (b) the plot numbering, (c) whether `Convergence reached` vs
   `Convergence not reached` is the only success signal, (d) whether the recursive
   `DCpss(ckt,1)` re-entry (`dcpss.c:988-996`) terminates. Until then a PSS panel is unshippable.
2. **`libngspice` has never been built.** No `SHARED_MODULE` build exists and no
   `libngspice.so` exists on this machine. Four dossiers (`outputs.md` §9, `commands.md` §15,
   `options.md` gap 5, `orchestration.md`) describe it from headers only. *Close it by:*
   `../configure --with-ngshared && make`, then verify `SendStat`'s percentage per analysis,
   `bg_halt`'s latency, and — the one `CLAUDE.md` calls out as a recurring bug class — whether
   analysis state and options survive repeated `ngSpice_Reset`.
   **This decision gates §5.4 (abort) and the whole progress story**, and it has not been made.
3. **CIDER has never been built.** Five device rows and a 16-card model sub-language in
   `cider-devices.md` are source-only. *Close it by:* `../configure --enable-cider`.
4. **The DC-sweep + auto-bridge failure** (`xspice.md` §12.1/§12.2) has a reproducer but no root
   cause. It blocks offering `dc` on any mixed-signal deck honestly.
5. **`Nintegrate()`'s definition** was never located (`an-smallsig.md` gap 2), so nobody can
   explain an `onoise_total` number to a user.

---

## 6. Ambition check — catalogued capabilities that NO dossier connected to a GUI affordance

The bar is "better than Cadence ADE". These are the pieces of raw material sitting unused.
Roughly in descending order of what they would buy.

1. **`CKTncDump`'s starred rows** — `cktncdump.c:11-43` prints a `Last Node Voltages` table
   after every failed OP, with a trailing ` *` on each node that still fails the convergence
   test. `convergence.md` §4.4 calls it "the single most useful diagnostic in ngspice" and
   nobody proposed a UI for it. **Parse it, map the node names back to schematic nets, highlight
   them on the canvas.** ADE gives you an opaque `sim.log`. This is the biggest single win
   available and it needs no new ngspice feature.
2. **The four-rung convergence ladder as a live status pane.** `cktop.c` emits a fixed,
   parseable state machine on stderr (`Note: Starting dynamic gmin stepping` →
   `Note: Starting true gmin stepping` → `Note: Starting source stepping` →
   `Note: Transient op started`, each with a `… completed`/`… failed` verdict), and
   `set ngdebug` upgrades it to a per-step `Trying gmin = …` / `Supplies reduced to …%` trace.
   Two parser rules: those two ngdebug lines have **no trailing newline**, and stderr/stdout are
   separately buffered so they must be captured as two ordered streams.
3. **`optran` as a first-class panel.** It is **on by default** (`init.c:77-94`,
   `1 1 1 100n 10u 0`), it silently sets the accuracy of every fallback operating point
   (`an-core.md` §5.10 measured 0.9999550 instead of 1.0 on a 1 µs RC), and it *supersedes*
   `.options noopiter/gminsteps/srcsteps`. Nobody has ever seen this knob. Offer the four rungs
   as toggles plus two numbers and emit one `optran a b c step stop 0` line.
4. **`speedcheck` and `deltacheck`.** With `set ngdebug` a transient run adds two vectors to the
   tran plot: wall-clock-vs-simulated-time and accepted-timestep-vs-time
   (`outitf.c:355-359`). That is a ready-made "why is my simulation slow / where is it
   struggling" plot and it appears in exactly one sentence of one dossier (`docs-web.md` §13.3
   item 24). Two clicks from a "Run took 4 minutes" banner.
5. **`rusage devtimes`** — per-device-type load time and call count
   (`src/frontend/resource.c:322-336`). A "what is slow" table, free.
   Plus `rusage tranpoints accept rejected` as a convergence-health gauge
   (`options.md` Table B calls `accept`/`rejected` "the single best convergence-health metric").
6. **`wrnodev`** (`com_wr_ic.c:25-66`) writes the current node voltages as a ready-to-`.include`
   `.ic` file. `convergence.md` §1.6 correctly calls it "the closest thing ngspice has to
   Cadence's save/restore DC solution" — and then nobody designs it in. Pair it with
   `stop when time=…` / `resume`.
7. **`.sens` glob filters** (`sens v(out) r*:r m*:vth0 ac dec 10 1k 1meg`) plus the
   `devhelp -flags` predicate of §5.6: a checkbox tree of perturbable parameters, computed
   offline, that turns an unusable 90-vector dump into a design tool. ADE-L has no sensitivity
   analysis at all.
8. **`set topo_reduce`** (`cktsetup.c:63-257`) — a one-click fix for the "dangling passive →
   spurious Timestep too small" class, off by default, and its console message *names the
   offending element*. Perfect for a "simulation failed → try this" assistant.
9. **`.dc` sweeping a resistor or `temp`** (`dctrcurv.c:89-151`). Four sweep kinds from one
   card, and `temp-sweep` / `res-sweep` scale vectors that a plot axis can label. A GUI that
   presents "DC sweep variable: [V source | I source | Resistor | Temperature]" already reads as
   more capable than the card.
10. **`stop when <expr>` + `resume` + `step`** (`breakp.c:38-206`) — a genuine debugger for a
    transient. `commands.md` §4 documents it fully; no dossier proposes a UI. Note it requires
    interactive/`-p` mode (D4), which is another argument for the pipe transport.
11. **`iplot`** — live incremental plotting during the run (`breakp.c:230-325`), with
    `-w` window and `-d` delay. Refused in batch mode. Nobody tested it (no display in this
    session), but "watch the waveform build" is an ADE feature.
12. **`diff <plot> <plot>`** (`src/frontend/diff.c`) with `diff_abstol`/`diff_reltol`/
    `diff_vntol` — regression comparison of two runs, built in. Zero dossiers mention a use.
13. **`.probe` power probing** — `.probe p(XU1)` yields a `xu1:power` vector
    (`docs-web.md` §6.5), works in **every** analysis including AC (unlike `savecurrents`).
    A "power" column in the Outputs pane, free.
14. **`group_delay`, `cph`/`unwrap`, `mtimeavg`, `m3avg`, `deriv`, `integ`, `interpolate`,
    `sortorder`** — the analysis-flavoured half of the expression vocabulary
    (`measure.md` §6.2). A calculator menu.
15. **`.sp` + `smithgrid`/`polar`/`settype decibel`** — `examples/sp/sp2.cir` and
    `Tschebyschef-LP.cir` already show a Smith chart. `wrs2p` is broken on `.sp` output
    (needs an `Rbase` vector; the `.csparam Rbase=50` idiom in `examples/sp/file.cir:24` is the
    workaround nobody promoted to a recommendation).
16. **`.four`'s `fourierMN` 2-D vectors and `thdMN`** — a THD readout and a harmonic bar chart,
    already computed, currently only printed as a text table.
17. **`--soa-log=FILE`** — safe-operating-area violations to their own file
    (`main.c:1101-1164`), enabled by `set warn=1` / `set maxwarns=N`. An "electrical rule
    check" pane. Note **SOURCE-HERE** it is a `set` variable read at circuit-load time
    (`inp.c:1447-1455`), *not* an `.options` keyword — so the GUI must emit it before the deck
    is read, which is an ordering constraint nobody stated as a design rule.

---

## 7. Things I could not resolve

1. Why `help devhelp` prints nothing at all (neither the help line nor `Sorry, no help for …`)
   while `help linearize` and `help optran` work. Not investigated; do not use `devhelp` as a
   `help`-probe target.
2. Whether the DISTO crash (D1) exists upstream in `pre-master-47`. `/usr/bin/ngspice` exists on
   this machine and I did not run it. Someone must check before filing.
3. The exact mechanism by which a `.tf` or `.op` card scopes the save set *before* the
   `.control` block runs — `ft_savedotargs()` is called from `main.c:1577`, i.e. after, yet the
   `no data saved` errors appear during the `.control run`. I confirmed the *effect* four
   different ways but not the call path.
4. `.probe` power/differential vector naming (`vd_R1`, `mq1:power`) — documented by the manual
   (§11.6.5), never verified against source or a run by anyone.
5. Whether `set interp` changes the *in-memory* plot as well as the rawfile: **MEASURED-HERE**
   it does (`tran 1u 20u` gave `length(time) = 21` under `set interp`), closing `outputs.md`'s
   gap — but I did not check the interpolation of a *complex* AC plot or a nested DC sweep.
6. Everything the `an-rf-pss`, `cider-devices` and `xspice` dossiers flagged as needing a
   rebuilt tree (§5.7 items 1, 3, 4). Read-only mandate.
7. `.meas` under `casemode=distinguish` for the analysis keyword; the `.sens2`/`.hb` grammars;
   the IPC/`Ipc_Anal_t` legacy event transport. All flagged by their owners and still open.
