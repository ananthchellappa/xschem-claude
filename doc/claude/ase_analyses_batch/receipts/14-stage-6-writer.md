# Stage 6 — the writer, the sidecar and reconciliation

**One commit, issue 1430, and the second of Stage 6.** The first is **1429**, ⚖ R3's
reader seam (`595ab274`); Stage 5 is **1426** (`tf`), **1427** (`pz`), **1428** (`sens`).
Nothing here touches any of them.

**Floors:** `test_ase_core` 417 → **453** · `test_ase_preflight` 192 → **194** ·
`test_ase_optier_0963` 103 → **105** — **forty new rows**, and every other ASE suite is
byte-unmoved on both arms. All three are in `tests/run_regression.tcl`, so **T1 covers
every row this commit adds**.

**One deck golden moved, and it is the only one in the tree: `test_ase_core.tcl`'s D1**
(with `C4` and `C5`, which compare against it).

```
src/ase.tcl                             | 512 +++...      (+510 / -2)
tests/headless/test_ase_core.tcl        | 738 +++...      (+737 / -1)
tests/headless/test_ase_optier_0963.tcl |  41 ++
tests/headless/test_ase_preflight.tcl   |  31 ++
```

⚠ **⚖ R3 IS STILL UNANSWERED and this issue does not touch it.** Nothing here reads a
number or moves a print line.

---

## What shipped

### `src/ase.tcl` — fourteen new core procs, all **schema**

| proc | what it answers |
|---|---|
| `ase::plotmap_path {state}` | `<rundir>/<cell>_ase.plotmap` |
| `ase::plotmap_record {type idx name}` | the record, **spelled once** |
| `ase::plotmap_parse {line}` / `ase::plotmap_read {path}` | read back, in **file order** |
| `ase::option_enabled {state name}` | is a `.options` row switched on |
| `ase::plot_when_valid {when}` / `ase::plot_when {when state}` | 6b's predicate: `1` / `0` / `unknown` |
| `ase::analysis_plots {sim row state}` | every plot this row is **predicted** to produce |
| `ase::plot_capturable {p}` / `ase::plot_select {p}` | the split, and the declared literal |
| `ase::analysis_captures` / `ase::analysis_uncaptured` | the half the deck writes, and the half it does not |
| `ase::reconcile_plots {sim state rawpath mappath}` | 6c's six verdicts |
| `ase::reconcile_report {state}` | said once per run, through `ase::echo` |

### `src/ase.tcl` — the adapter (`ase::backend::ngspice`)

* `render_deck`'s write block gains **one `echo … >> …plotmap` line per `write`** and the
  **`setplot previous` walk**, whose length is `ase::analysis_captures`' answer.
* The `ac` registry entry gains its measured second plot,
  `{select {AC Operating Point} role opinfo … when {opt keepopinfo}}` — matching `pz`'s,
  which has had one since issue 1427.

### `src/ase.tcl` — the run path

* `ase::run_deck` deletes the sidecar beside the results file, before every run.
* `ase::run_done` calls `ase::reconcile_report`, **caught**, after the other two reports.

### `ase::analysis_schema_errors` — the `plots` key stops being decoration

Four new refusals: `noplots`, `noplotselect`, `noplotrole`, `badplotwhen`. The shipped
ngspice registry answers **`{}`**, as it did before.

**`src/ase_window.tcl` is untouched.** No new state key, no `seed_enabled`,
`ase::state_default` still seeds exactly four rows, and the **104 committed `.state` files
are byte-identical** — section **CP** is the row that would notice.

---

## Every measured fact this rests on, and where it was measured

All 2026-09-12, scratch decks under `/tmp/wr6probe`, **never a bench under `sky130A/`** and
nothing written under `~/.xschem/`. Binary 3 is
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (`ngspice-46+`); binary 1 is
`/usr/bin/ngspice` (`ngspice-45.2`). **Both were run for every measurement below, and every
one came back identical on the two.**

### 1. Two `sens` rows write two plots and nothing separates them

```
sens v(mid) r1 dc / write   ->   Plotname: Sensitivity Analysis
sens v(mid) r2 dc / write   ->   Plotname: Sensitivity Analysis
```

This is the defect. The plot literal cannot separate them **even in principle** — two
*different* analyses share it (`sens … dc` / `sens … ac`, APPENDIX §0.7) — and write order
is `ase::analysis_emit_order`'s rank, which moves under 0964's `op`-last variant.

### 2. `echo "…" >> <path>` works inside `.control`, and `$curplotname` is the plot's name

```
echo "PLOT op 0 |$curplotname|" >> p1.plotmap    ->  PLOT op 0 |Operating Point|
echo "CURPLOT=$curplot CURPLOTNAME=$curplotname" ->  CURPLOT=tf1 CURPLOTNAME=Transfer Function
```

`$curplot` is the *slot* (`tf1`); `$curplotname` is the *name* the results file's
`Plotname:` record carries. The sidecar wants the second.

### 3. END TO END, through ASE-L's own `render_deck`, on BOTH binaries

The headline measurement, and the one the whole task is for. A state with **two enabled
`ac` rows** — `dec 10 1 10k` and `lin 5 1k 2k` — plus `op` and `tran`, rendered by
`ase::backend::ngspice::render_deck`, run in a scratch directory under `/tmp`. `rc 0` on
both binaries, `paste(1)` of the sidecar against the results file's `Plotname:` records:

```
PLOT op   0 |Operating Point|      @ Plotname: Operating Point
PLOT ac   1 |AC Analysis|          @ Plotname: AC Analysis
PLOT ac   2 |AC Analysis|          @ Plotname: AC Analysis
PLOT tran 3 |Transient Analysis|   @ Plotname: Transient Analysis
```

Row for row, byte for byte, identical on the fork and on apt 45.2. **The two `AC Analysis`
plots are now told apart — by 1 and by 2 — and nothing else in the file can tell them
apart.** `ase::reconcile_plots` over those artefacts: **`ok`, 4 / 4 / 4, and nothing said.**

### 3b. ...and a run whose analysis FAILED keeps the sidecar 1:1, measured

The first end-to-end deck carried two `sens` rows and its third analysis failed on **both**
binaries (`RUN-FAILED`, `quit 1`, rc 1 — issue 1428's `sens` ground). That is the better
test of the record's placement, and it passed:

```
sidecar: 2 records    results file: 2 plots     op / ac, in order, matching
```

The `$sim_status` guard quits **above** the record, so the analysis that failed appended
**nothing** — which is what row **PF218f2** asserts against deck text and this confirms
against a live simulator. ⚠ **It also caught a wrong sentence.** Reconciliation answered
`predmismatch` (4 predicted, 2 recorded) and said *"the analyses changed between rendering
the deck and reading it back"* — the other cause, and the wrong one that day. The sentence
now names both, and row **RC12** asserts it does.

### 4. `setplot previous` walks creation order backwards and SATURATES on `constants`

```
ac (keepopinfo)   W0 ac1  |AC Analysis|   W1 op1 |AC Operating Point|
                  W2 const |constants|    W3 const |constants|
```

⚠ **It does not fail and it does not wrap.** An over-walk lands on ngspice's built-in
`constants` plot and **stays there**, and the next `write` appends the twelve mathematical
constants to the results file at rc 0. The only trace is a **stderr** line — `Warning: No
previous plot is available. Plot remains unchanged (const).` — where nothing in this tree
looks. This is why reconciliation has a `mislabel` arm and not only a counter.

### 5. The `keepopinfo` table, per analysis — and it REFUTES `PLAN.md` §6

```
.options keepopinfo   ac    -> AC Analysis + `AC Operating Point`
                      pz    -> Pole-Zero Analysis + `Distortion Operating Point`
                      tf    -> Transfer Function, and NOTHING ELSE
                      sens  -> Sensitivity Analysis, and NOTHING ELSE
no keepopinfo         all four -> exactly one plot
```

`PLAN.md` §6 lists `tf` among the types `keepopinfo` prepends an operating point to. It
does not, on either binary. `pz`'s companion is labelled **`Distortion Operating Point`** —
upstream's copy-paste, carried verbatim and never "fixed", exactly as issue 1427 recorded.
(For the record, the out-of-scope types measured the same way: `disto` writes
`DISTORTION - 2nd harmonic` + `DISTORTION - 3rd harmonic` + `Distortion Operating Point`;
`noise dec` writes `Noise Spectral Density Curves` + `Integrated Noise` + `NOISE Operating
Point`; **`noise lin 1` writes no `Integrated Noise` at all**, which is `PLAN.md` 6b's
`when {expr {start ne stop}}` confirmed.)

### 6. A results file holding an `opinfo` plot AND the real operating point answers WRONG

The decisive one. `src/save.c`'s `read_dataset()` matches
`strstr(lowerline, "operating point")` **before** its AC arm (`save.c:972`, above the AC arm
at `:986`), so `AC Operating Point`, `Distortion Operating Point` and `NOISE Operating
Point` all read back as `op`. Fixture: one results file holding the companion and the real
operating point, made to **disagree** by an `alter V1 dc` between them —

```
raw:  AC Operating Point   v(in)=2  v(mid)=1
      Operating Point      v(in)=1  v(mid)=0.5

xschem raw read <file> op   ->  points=2, vars=3, datasets=2 sim_type=op
xschem raw value v(in)  0   ->  2        <- the AC operating point
xschem raw value v(mid) 0   ->  1        <- ... and the real one is 0.5
```

⚠ **The first fixture I built could not have caught this**, and that is worth recording: a
plain RC divider has the same operating point before and after, so both plots read
`v(mid) = 0.5` and the row would have passed while the bug was live. It took an `alter`
between the two analyses — which is ASE-L's own per-row verbatim hatch (issue 1419) — to
make the two sources disagree. *A row whose fixtures never disagree cannot fail*, met for
the sixth time in this batch.

### 7. A 2-D `dc` sweep is ONE plot, not two

```
dc V1 0 1 0.5 V2 0 1 0.5   ->  W0 dc1 |DC transfer characteristic| / W1 const |constants|
```

Checked because it was the last candidate for an in-scope multi-plot analysis. It is not
one, which is what leaves the walk with no production exerciser until Stage 6d.

### 8. `foreach p $plots` still cannot name the plots from inside a deck

```
set plist = "$plots" / foreach p $plist / setplot $p / echo "$p |$curplotname|"
   ->  PLOT "const |AC Analysis|          (one iteration, `$p` is the literal `"const`)
```

`PLAN.md`'s correction C1 re-confirmed on this build, from the other direction: the quoting
is ngspice's own, the loop runs once, and `setplot` never moves. `echo … >>` is the only
shape left.

---

## What the plan and the tree said that this refuted

This is the batch's twenty-second through twenty-sixth corrections (Stage 5 took C43–C55,
issue 1429 took C56–C59).

### C60 — `PLAN.md` §6's `keepopinfo` list names `tf`, and `tf` does not produce one

*"`keepopinfo` prepends an OP plot to `ac`, `noise`, `pz`, `tf`, `disto` and `sp`."*
Measured (fact 5): `tf` produces one plot with `keepopinfo` on or off, and so does `sens`.
The registry declares what was measured rather than what the plan says — and it matters,
because the walk length is read from the registry: a `tf` entry declaring two plots would
have made every `tf` run **over-walk**, and an over-walk is silent (fact 4).

### C61 — the walk CANNOT capture an `opinfo` plot into the results file

`PLAN.md` 6a has the walk capture every plot of an analysis, and 6d proposes to keep
`role opinfo` plots out of `xschem raw read … op` on the *reader* side. **That is not
available**: the match is in C, over the whole file (fact 6), and `ase::attach_dbs` hands
`xschem raw read` the file entire. Measured, the companion **wins** — `v(mid) = 1` where
the real operating point is `0.5`.

So `ase::analysis_plots` **predicts** it (reconciliation needs to know reality holds it)
and `ase::analysis_captures` **declines** it, and the run says so in as many words. The
shape the plan wants needs a **second results file** (`<cell>_ase.opinfo.raw`), which is a
separate artefact with a separate reader and is **not** in this commit. It is on the ⚖ R9
rule debt as the one design call worth the user's time.

### C62 — the sidecar is WRITE-ordered, not creation-ordered

`PLAN.md` 6a: *"The sidecar is creation-ordered and 1:1 with the rawfile's `Plotname:`
records."* It cannot be both, because the walk runs **backwards**: a multi-plot analysis
reaches the file in reverse creation order (`AC Analysis` then `AC Operating Point`,
measured). The 1:1 half is the load-bearing half and it holds exactly; "creation-ordered"
does not. Nothing downstream cares — both readers in this tree pick their plot **by name**
out of the multi-plot file — but the sentence would have sent the next reader looking for a
property that is not there.

### C63 — `ase::analysis_plots {sim row opts}` takes the STATE, not an options list

A shape note rather than a refutation. The prediction has to be computable **after** the
run, from the state alone, because `ase::run_done` has no netlist text and no options list
in hand. Passing the state is what makes 6c's `predmismatch` arm possible at all.

⚠ **The cost of that is named, not hidden**: a `.options keepopinfo` card written into the
**schematic's own netlist** is invisible to the prediction. Such a run has one more plot on
disk than the registry expected, and reconciliation reports it as an `over` — which is the
safety net doing its job, degrading rather than destroying.

### C64 — the walk has NO production exerciser in the shipped registry, and that is stated

Measured across every in-scope type (facts 5 and 7): `op`, `dc` (1-D and 2-D), `ac`, `tran`,
`tf`, `sens` and `pz` each capture exactly **one** plot, because `ac`'s and `pz`'s second
plots are `opinfo` and declined (C61). `noise` and `disto`, which do capture two and three,
are Stage 6d's and out of this task's scope.

So `render_deck`'s walk is machinery Stage 6d plugs into, and it ships **unexercised by the
shipped registry**. Rather than write a row that cannot fail, it is driven the way issue
1429's **RS3** drove ⚖ R3's two rulings — stub the one proc the emitter asks
(`ase::analysis_captures`) and watch the whole shape follow — with the **unstubbed render
of the same state** beside it as the control (rows **WK5**, **E5b**, **RC5b**). The shape
is also verified end to end against a real simulator by hand, on both binaries (fact 3).

---

## Suites moved, before → after, per arm

| suite | headless | display (`:99`) |
|---|---|---|
| `test_ase_core` | 417 → **453** | 417 → **453** |
| `test_ase_preflight` | 192 → **194** | 192 → **194** |
| `test_ase_optier_0963` | 103 → **105** | **TIMEOUT** — see below |
| `test_ase_cosim` | 341 → 341 | 341 → 341 |
| `test_ase_simcaps_0948` | 190 → 190 | 190 → 190 |
| every other ASE suite | unmoved | not run |

⚠ **`test_ase_optier_0963`'s display arm timed out at 400 s, and it is the filed
pre-existing stall**, not a regression: `CLAUDE.md` names it (*"86 of 103 rows, stops after
row N3"*), and the three Stage 5 crews and the 1429 crew all hit it in the same place. Its
**headless** arm — the one `run_regression.tcl` runs — is **ALL PASS (105)** before and
after. Bounded by `run_suites.sh`'s own per-arm `timeout`, so there is no orphan.

New sections: **PM**, **GP**, **WK**, **RC** in `test_ase_core.tcl`; rows **PF218f2** and
**PF218f3** in `test_ase_preflight.tcl`; rows **E5b** and **E5c** in
`test_ase_optier_0963.tcl`. All three floor paragraphs raised in the same commit.

⚠ **ONE EXISTING ROW MOVED, AND IT IS A DECK GOLDEN.** `test_ase_core.tcl`'s **D1** gains
the one line that joins every write; **C4** and **C5** compare against D1's golden and
follow it. That is the whole of the "every deck golden moves" cost `PLAN.md` Stage 6 budgets
for — **one golden, in one file** — because the sidecar record is the only line added to a
single-plot deck and every other rendered-deck assertion in the tree counts writes,
`remzerovec`s or `.save` cards rather than comparing whole decks. The other three files that
carry `remzerovec` in a string (`test_ase_simcaps_0948`, `test_ase_optier_0963`,
`test_ase_preflight:1077`) write their probe decks **by hand**; they are not `render_deck`
output and they do not move.

⚠ **AND ONE FIXTURE MOVED WITHOUT ITS ROW MOVING.** `em_bad_types` (row **EM9**) gained a
valid `plots` key. `ase::analysis_schema_errors` learned a third thing to refuse, and that
fixture would otherwise have answered **three** errors — turning a row about the field/slot
contradiction into a test of two unrelated checks at once. The three new refusals have
their own fixtures, in section **GP**. This is *"prefer adding a new row over editing the
original anchor"* applied to a fixture rather than to a golden.

⚠ **`test_ase_core.tcl`'s floor paragraph said 391 → 411 and the suite reported 417.** The
1429 crew's sentence was written before its last six rows landed. Corrected in place rather
than overwritten, with the reason, because a count nobody re-derives is a count that drifts.

⚠ **Sections PM, GP, WK and RC carry their own `catch`**, ending in row **PM0**. This
file's outer one closes at the end of section SI, thousands of lines above them — issue
1428's S10 and issue 1429's S31 both paid for that lesson.

---

## The sabotage table

**Thirty-three distinct respellings of `src/ase.tcl`, plus nine re-runs — sixty-five suite
runs in all**, each respelling a plausible rewrite rather than a break: the tidy-up somebody
would actually make. Restore was `cp`
from `/tmp/wr6probe/good/` with an `md5sum -c` after **every** one; every restore
was verified before the next sabotage ran.

⚠ **THE TREE MOVED TWICE AFTER THE CAMPAIGN, and both moves are named here rather than
left for someone to notice.** (1) `test_ase_core.tcl` gained **WK2b, WK8, RC4b**, the
hardened **WK4/WK2**, and the rewritten **GP1/PM4**, all of which the campaign itself
bought — each is re-sabotaged below with an `r` suffix. (2) `src/ase.tcl` gained **one
sentence**: `predmismatch`'s, which named the wrong cause (§3b). Every suite was re-run to
green after both, and the full ASE family after that.

Counted by first attempt: **twenty-nine reddened a named row**, **two survived** (S23, S29),
and **two did not redden a row at all — they KILLED the PM/GP/WK/RC section** (S21, S24),
which the section's own `catch` reported as the unnamed row **PM0**. Every exception was
re-run against what it bought. Three further sabotages reddened *something* while proving
the row that was supposed to catch them could not (S05, S06, S14) — those are the
interesting ones and they are below the table.

⚠ **The campaign owned `src/ase.tcl` while it ran, and one measurement was taken anyway.**
An end-to-end render taken during the campaign came back showing a sidecar record with no
`|` delimiters — a real defect's exact signature, and in fact sabotage **S01** sitting in
the file at that moment. It is recorded here rather than tidied away; the end-to-end
measurements in this receipt were all re-taken after the campaign finished.

| # | the respelling | rows reddened |
|---|---|---|
| S01 | `ase::plotmap_record` drops the `\|` delimiters ("plot names are one word anyway") | core **C4** **C5** **D1** **PM2** **RC1** **RC11** **RC12** **RC2** **RC3** **RC4** **RC5** **RC5b** **RC8** **WK2** · preflight **PF218f3** |
| S02 | the record drops the row INDEX ("the type is enough") | core **C4** **C5** **D1** **PM2** **RC1** **RC11** **RC12** **RC2** **RC3** **RC4** **RC5** **RC5b** **RC8** **WK2** · preflight **PF218f3** |
| S17 | the sidecar record emitted AFTER the write instead of before | core **C4** **C5** **D1** **WK1** **WK5** · preflight **PF218f2** |
| S18 | the walk's step emits no record | core **WK5** |
| S19 | the walk's step emits no `remzerovec` | core **WK5** |
| S20 | the walk's write carries `all <device names>` | optier **E5c** |
| S21 | `pmapf` resolved OUTSIDE the `n_enabled_analyses` guard | core **PM0** — **KILLED the section** (unnamed) |
| S22 | the walk length read from `analysis_plots`, not `analysis_captures` — **the over-walk** | core **WK5** · optier **E5b** **E5c** |
| S23 | the record's index becomes a write COUNTER | **NOTHING** *(survivor)* |
| S24 | the record's redirection `>>` becomes `>` | core **C4** **C5** **D1** **PM0** · preflight **PF218f3** — **KILLED the section** (unnamed) |
| S03 | `plotmap_parse`'s name group goes non-greedy | core **PM2** |
| S04 | `plotmap_parse` accepts any index, not just digits | core **PM3** |
| S05 | `plotmap_path` answers `<cell>_ase.raw` — the results file | core **PM1** **RC11** **WK3** |
| S06 | `plotmap_read` sorts its answer instead of keeping file order | core **RC5** **RC5b** |
| S07 | `plotmap_path` returns `{}` for a cell-less state instead of raising | core **PM1b** |
| S08 | an unreadable `when` answers 1 instead of `unknown` ("be permissive") | core **GP3** |
| S09 | `option_enabled` takes `value 0` for ON | core **GP3** |
| S10 | `option_enabled` becomes case-sensitive | core **GP3** |
| S11 | `analysis_plots` ignores `when` entirely | core **GP4** **GP5** **RC8** |
| S12 | `plot_capturable` returns 1 for `opinfo` ("capture everything") | core **GP5** **RC8** |
| S13 | `analysis_uncaptured` always answers `{}` | core **GP5** **GP6** **RC8** |
| S14 | the `noplots` refusal deleted from the validator | core **GP2** |
| S15 | the `badplotwhen` refusal deleted | core **GP2** |
| S16 | the `noplotselect` refusal deleted | core **GP2** |
| S25 | the pre-run sidecar delete dropped from `run_deck` | core **RC13** **RC13b** |
| S26 | the `reconcile_report` call dropped from `run_done` | core **RC10** |
| S27 | that call no longer caught | core **RC10** |
| S28 | the registry-`select` half of the `mislabel` arm deleted | core **RC5** |
| S29 | severity order: `under`/`over` decided before `mislabel` | **NOTHING** *(survivor)* |
| S30 | `norun` folded into `ok` — the empty run says something | core **RC7** **RC9** |
| S31 | the uncaptured note suppressed | core **RC8** |
| S32 | `under`'s `missing` list taken from the HEAD of the record instead of the tail | core **RC2** |
| S33 | `cap_raw_plots`' triples used as plot names (no `lindex 0`) | core **RC1** **RC12** **RC2** **RC3** **RC4** **RC5** **RC5b** **RC8** |
| S22r | the same, re-run against WK8 -- the PRODUCTION over-walk | core **WK5** **WK8** · optier **E5b** **E5c** |
| S29r | the same, re-run against RC4b | core **RC4b** |
| S20r | the same, re-run against E5c | optier **E5c** |
| S21r | the same, re-run against WK4's caught render | core **WK4** |
| S23r | the same, re-run against WK2b | core **WK2b** |
| S24r | the same, re-run against WK2's seeded capture | core **C4** **C5** **D1** **WK2** **WK3** · preflight **PF218f3** |
| S06r | the same, re-run against PM4's re-ordered fixture | core **PM4** **PM5** **RC5** **RC5b** |
| S14r | the same, re-run against the row it bought | core **GP2** |
| S13r | the same, re-run against the rows it bought | core **GP5** **GP6** **RC8** |


### The two that SURVIVED, and the rows they bought

**S23 — the record's index replaced by a write COUNTER — changed nothing.** WK2's two rows
sit at positions **0 and 1** and are written in that order, so a row index and a counter
produce byte-identical text: `test_ase_core` stayed at **ALL PASS**. The fixture that can
see it has to disagree twice over — a **disabled row in front** (so no counter can reach
the enabled rows' positions) and **`op` last in the list** (where `ase::analysis_emit_order`
writes it first). Row **WK2b**: a counter says `op 0 / tran 1`, the row index says
`op 2 / tran 1`. S23r reddens it.

**S29 — the severity order swapped so `under`/`over` are decided before `mislabel` —
changed nothing**, because every RC fixture fired exactly one arm: RC2 and RC3 have no
mislabel, RC4 and RC5 have matching counts. A verdict precedence with no fixture in which
two arms collide is **unasserted by construction**. Row **RC4b** is a plot that is *both*
missing and mislabelled, and asserts that `mislabel` wins **and** that the `under` sentence
is still said beside it. S29r reddens it.

### The two that KILLED A SECTION, and the two hardenings they bought

Neither reddened a row on its first attempt: both **raised**, and the PM/GP/WK/RC section's
own `catch` reported the unnamed row **PM0** with the rest of the block's checks lost. In a
sabotage log that reads as *"almost nothing went red"*, which is issue 1429's S31 exactly.

* **S24** — the record's `>>` respelled as `>`. `test_ase_core`'s WK2 loop ran
  `regexp {… >> (.*)$} $wl -> wkr wkp` **without reading the answer**; `wkr` stayed unset
  and `lappend` raised. The loop now reads the `regexp`'s return value. **And the identical
  shape had bitten one sabotage earlier, in a different file**: S01 (the record loses its
  `|` delimiters) left `pfmap` unset in the brand-new **PF218f3**, and
  `test_ase_preflight` printed `FATAL: can't read "pfmap"` and `1 FAILED (193 passed)` —
  **129 of its 194 checks lost**. `pfmap` is seeded now, and S01 reddens PF218f3 by name.
* **S21** — `pmapf` resolved outside the `n_enabled_analyses` guard, which makes
  `ase::plotmap_path` raise for the one state WK4 exists to test. WK4's render is caught
  now, so the same sabotage is a named red that says what raised.

### The three rows that were VACUOUS until a sabotage said so

None of these three sabotages was a survivor — each reddened *something* — but each proved
the row that was supposed to catch it could not.

* **S06** (`plotmap_read` sorts its answer) reddened **RC5/RC5b** and **not PM4**, the row
  whose entire claim is *"reads back in FILE ORDER"*. PM4's fixture was `op 0 / sens 3 /
  sens 5` — which is **already `lsort`'s answer**. It is `tran 1 / op 0 / sens 5 / sens 3`
  now, which sorting reorders in two places. S06r reddens PM4.
* **S14** (the `noplots` refusal deleted) reddened **GP2** and not **GP1**, because GP1's
  second element asked *the validator* whether it had reported `noplots` — and the shipped
  registry produces none whether the check exists or not. GP1 walks the **registry** now,
  counting the seven renderable types and listing any without a `plots` key.
* **S05** (`plotmap_path` answers the results file's path) left the **D1 golden green**,
  because D1 substitutes `@PLOTMAP@` by calling `ase::plotmap_path` — the tree's own
  idiom for a machine-dependent path, inherited from `@RAWFILE@`. **WK3** is the row that
  catches it, and it does.

---

## What I did NOT ship, and why

* **`noise`, `disto` and `sens (ac)`** (`PLAN.md` 6d). No analysis type is added and no
  `kind` is declared, so `ase::analysis_schema_errors` stays `{}`, row **GR8**'s declared
  `kind` set is unmoved, and `test_ase_preflight`'s **PF222a-e / PF222h-j** — which rest on
  `noise` being **UNRENDERABLE** — are green with the rest of that suite's 194. The three
  types' plot literals **are** measured here (fact 5) and written into the receipt so 6d
  inherits them rather than re-deriving them.
* **Checkpointed salvage** (6f) and **the four variant mitigations** (6g). `render_deck`
  emits no `stop after`, no `resume`, no `delete all`, no `.ckpt`; `run_deck`'s pre-run
  delete list gains the sidecar and nothing else.
* **A second results file for the `opinfo` companion** (`<cell>_ase.opinfo.raw`). This is
  correction **C61**'s consequence and it is the one design call on the ⚖ R9 debt: it needs
  a new artefact, a new pre-run delete, and a reader, and it is worth asking about before
  building. Until it exists the run **says** the plot was computed and says it is not kept,
  which is strictly better than today's silence.
* **Anything in `src/ase_window.tcl`.** The plots the walk captures reach the viewer through
  `ase::attach_dbs` exactly as they do today; what is new is that the run can now *name*
  them. Labelling a result from the sidecar is a surface change and it is 6d's, with the
  `resulttable` Stage 5b built.
* **`ase::attach_dbs` taking the sidecar** (`PLAN.md`'s *Files and procs* row). Its
  signature is `{rawfile sim_type {vcdfiles {}}}` and every caller of it is in
  `src/ase_window.tcl`, which this task may not touch. The reconciliation is called from
  `ase::run_done` instead — which is where the other two post-run reports already live, and
  which is the right place for a **report** rather than for an attach.
* **A `when` form beyond `{opt <name>}`.** `PLAN.md` 6b sketches
  `when {expr {start ne stop}}` for `noise`'s `Integrated Noise`. Nothing in the shipped
  registry needs it, so shipping an evaluator for it would be an untested branch; instead
  `ase::plot_when_valid` **refuses** it at validation time (row **GP2**) so the next crew is
  told to implement it rather than discovering at run time that their plot silently
  vanished.
* **Any change to `render_deck`'s print anchor, its `$sim_status` guard, its `remzerovec`
  placement or its `.save` cards.** Those are issues 1243, 0964, 0929 and 0963, and row
  **WK7** asserts every one of them is still where they put it.
* **`seed_enabled`, anywhere.** Four seeded rows; the 104 committed `.state` files are
  byte-identical and section **CP** proves it.

---

## What this stage learned that binds later ones

**A plan's factual table is checkable in twenty minutes, and one row of this one was
wrong.** `PLAN.md` §6 lists `tf` among the types `keepopinfo` gives an operating point to.
It does not. Had the registry been written from the plan, every `tf` run would have
over-walked — and an over-walk does **not** fail: `setplot previous` saturates on the
`constants` plot and the next `write` appends ngspice's twelve mathematical constants to the
results file, at rc 0, with the only trace on **stderr**. ⚠ **Measure the table, not only
the conclusion** — issue 1429 learned the same thing about a plan's *reason*, and this is its
sibling.

**A fixture where the two sources happen to agree cannot catch a reader that picks the
wrong one.** The first two-operating-point fixture was a plain RC divider, whose AC
operating point and real operating point are the same numbers — so `xschem raw value v(mid)`
answered `0.5` either way and the file looked fine. An `alter` between the two analyses made
them disagree (`1` against `0.5`), and the answer came back **wrong**. That measurement is
the whole of correction C61; without it the walk would have shipped capturing the companion.
⚠ This is the batch's **sixth** *a row whose fixtures never disagree cannot fail*, and the
first where the fixture was a **simulator deck** rather than a test row.

**Two counts agreeing is not two things agreeing.** Reconciliation's first three arms are
counters — predicted, recorded, actual — and all three agree for the one failure the walk
can actually produce. The `mislabel` arm exists because the *names* disagree when the
*numbers* do not, and it is the only arm that can see an over-walk. ⚠ A safety net built
from counters would have been green on the exact defect it was written for.

**A sabotage on the CODE reddens a row in the TEST that has nothing to do with it.**
Respelling `ase::plotmap_record` without its `|` delimiters made a brand-new preflight row's
`regexp` miss, left its capture variable unset, and the `string match` after it **raised** —
which that file's outer catch turned into `FATAL: can't read "pfmap"` and
`1 FAILED (193 passed)`, an **unnamed** failure costing 129 of 194 checks. In a sabotage log
that reads as *"almost nothing went red"*. ⚠ **Seed every capture variable before the
`regexp` that fills it**, in a file whose abort handling is a file-level catch. Issue 1429's
S31 is the same lesson one file over, and it arrived here within one sabotage of the row
being written.

**And then it happened again, in the other file, from a different sabotage.** **S24**
respelled the deck's `>>` redirection as `>`; `test_ase_core`'s WK2 loop ran
`regexp {… >> (.*)$} $wl -> wkr wkp` without reading the answer, `wkr` stayed unset, and
`lappend` **raised** — killing the whole PM/GP/WK/RC block and arriving as the unnamed row
**PM0** with 23 checks lost. ⚠ **Two files, two sabotages, one shape.** The rule is not
"seed the variable" but the stronger one: **read the `regexp`'s return value**, because a
pattern that stops matching is exactly what a sabotage — or a future change to the emitted
text — produces.

**Do not run a probe against a tree another process is rewriting.** An end-to-end render was
taken while the sabotage campaign was live, and it came back showing a record with no
delimiters — which is a real defect's exact signature, and was in fact sabotage S01 sitting
in `src/ase.tcl` at that moment. It cost one confused minute and could have cost a wrong
correction in this receipt. ⚠ **A sabotage campaign owns the working tree while it runs**;
every other measurement waits for it.

**`|` delimiters and a greedy `(.*)` are worth more than they look.** Every plot literal
ngspice writes contains spaces, and one contains a hyphen and a digit
(`DISTORTION - 2nd harmonic`), so a whitespace-delimited record cannot carry a name at all.
Making the name the **last** field and closing on the **last** pipe means an embedded `|`
survives too — asserted in row **PM2**, because a non-greedy respelling is the plausible
"tidy-up" and it silently truncates.

**A row can name the right property and still be blind to it, because its fixture makes the
two candidate answers equal.** WK2 asserts *"two rows of one type are told apart by the
record's index"* against a state whose two rows sit at positions **0 and 1** and are written
in that order — so a **row index** and a **write counter** produce byte-identical text.
Sabotage **S23** replaced one with the other and `test_ase_core` stayed at **ALL PASS
(450)**. The fixture that can see it has to disagree twice over: a **disabled row in front**
(so no counter can reach the enabled rows' positions) and **`op` last in the list** (where
`ase::analysis_emit_order` writes it first, reversing list order against write order). Row
**WK2b**. ⚠ **Ask what ELSE would produce this exact output**, not only what the row claims
to measure — this is the batch's seventh meeting with that rule and the second in this
commit.

**A golden that substitutes a path through the proc under test cannot check that path.**
D1's new `@PLOTMAP@` is resolved by calling `ase::plotmap_path` — the same call
`render_deck` makes — because the rundir is machine-dependent and the golden has to stay
deterministic. That is the tree's own established idiom (`@RAWFILE@` has done it through
`ase::rundir` since issue 0929), and it means **sabotage S05, which made `plotmap_path`
return the *results file's* path, left D1 GREEN**: both sides moved together. The row that
catches it is **WK3**, which asserts the record's destination is `ase::plotmap_path`'s
answer **and is not the results file**. ⚠ A substituted golden pins the *shape* of a line,
never the *value* it substitutes; the value needs its own row, with a second, independent
source for the answer.

**A SELF-MATCHING WAITER FROM AN EARLIER CREW IS STILL SPINNING IN THIS SESSION.** Measured
2026-09-12 17:22, `ps -eo pid,ppid,etime,args`:

```
1436601  460669  05:33:18  /bin/bash -c … until [ -z "$(pgrep -f 'test_ase_simcaps')" ]; do sleep 4; done; …
```

Five and a half hours, from the `sens` crew (its restore path is `/tmp/sensprobe/pristine`).
It is the exact trap issue 1429's receipt closes with — *"a waiter that greps for its own
command line never returns"* — and it is **worse than that one**: this pattern also matches
**anyone else's** `test_ase_simcaps` run, so every suite pass in this session re-arms it. It
is inert (a `sleep` loop) and it was **left alone**, since it belongs to another crew's
bookkeeping; it is reported because a lesson written down in a receipt is not the same as a
lesson applied, and here is the proof standing in the process table. ⚠ **Match on something
the waiter itself cannot contain, and on something no other session can either** — a pid, or
a marker file.

**A SENTENCE THAT NAMES A CAUSE IS AN ASSERTION, AND MINE WAS WRONG THE FIRST TIME IT RAN.**
`predmismatch` said *"the analyses changed between rendering the deck and reading it back"* —
which is one way to reach that state and, it turns out, the rarer one. The first end-to-end
run reached it the other way: an analysis failed, the `$sim_status` guard quit, four plots
were predicted and two recorded, and the state was untouched. ⚠ **A diagnostic may only
assert what it measured.** Reconciliation measures two numbers; it does not measure why they
differ, so the sentence now names both routes and leaves the user to tell them apart with
the exit code and the log — both of which they have and it does not. Every suite row for
that arm was written against deck text and fixture files, and **none of them could have
caught this**: only a live simulator produced the shape.

---

## Rulings

⚖ **R9 — six new user-facing sentences, and one design call.** All six are said once per
run through `ase::echo`, which is the channel every other result note in this file already
uses, so nothing new is drawn and **no `look` debt is filed**.

1. **under** — *"one plot of the `tran` analysis was not captured: this run recorded 2 and
   the results file holds 1."*
2. **over** — *"this run captured 3 plots where the registry expected 2; the extra ones
   (`constants`) were ignored."*
3. **mislabel** — *"the `tran` analysis in row 1 recorded 'X' where the results file holds /
   the registry declares 'Y', so results cannot be matched to the row that asked for them."*
4. **nomap** — *"the plot sidecar `<cell>_ase.plotmap` is missing, so the N plot(s) in the
   results file cannot be matched to the analysis rows that asked for them."*
5. **predmismatch** — *"the enabled rows predict 1 plot(s) and this run recorded 2: the run
   stopped before the rest, or the analyses changed between rendering the deck and reading
   it back."* ⚠ **This sentence named only the second cause until an end-to-end run showed
   the first** (§3b): a real `sens` failure made the `$sim_status` guard quit, four plots
   were predicted and two recorded, and nothing whatever was wrong with the state.
6. **uncaptured companion** — *"the `ac` analysis also computes 'AC Operating Point'. ASE-L
   leaves it out of the results file: every plot whose name contains 'Operating Point' reads
   back as the OP and would replace the real one."*

**And the design call, which is the one worth the user's time:** should ASE-L write a
**second results file** (`<cell>_ase.opinfo.raw`) so the `keepopinfo` companion is available
without corrupting the operating-point readback? Measured cost: one more artefact, one more
pre-run delete, one more reader. Measured reason it is not simply captured into the existing
file: correction **C61**.

Recorded as `owed.sh add rule 1430` at the moment it was incurred, saying in as many words
that **it does not stand in for ⚖ R3**. Batch with 1426, 1427, 1428 and 1429, which are all
still waiting.

⚠ **THE LEDGER WAS BACKED UP FIRST**, per `CLAUDE.md`'s one-ledger-every-clone paragraph, to
`/tmp/wr6probe/owed_backup_20260912_165534` (149 rule / 56 look / 9 suite at the time). The
new entry is stamped `repo:/home/analog/dev/xschem-claude`.

⚠ **AND THE LEDGER HAS FOUR UNSTAMPED ENTRIES, WHICH IS EVIDENCE AND IS REPORTED RATHER
THAN CLAIMED.** `CLAUDE.md` records a measurement of **2026-09-10 12:40** finding **zero**
unstamped entries and a 182/14 split. Measured again **2026-09-12 16:55**, before the `add`:

```
/usr/bin/grep -L '^repo:' ~/.claude/xschem_owed/{rule,look,suite}/*
  ->  rule/1357
      rule/1357@xschem-claude
      look/hier_pdf_nav_1357_H6.1789071932.2875683
      suite/test_hier_pdf_links_1333

/usr/bin/grep -h '^repo:' … | sort | uniq -c   ->  197 xschem-claude / 13 op-wcard
```

The two `rule/1357` entries point at **two different issue files** —
`1357-hier-pdf-nav-strip-presentation-is-unratified.md` and
`1357-add-from-the-summary-list-writes-the-annotation-list.md` — which is issue **1400**'s
collision standing in the ledger itself. `cleared.log` mentions `1357` **zero** times, so
this script destroyed nothing; per `CLAUDE.md`, a silent `cleared.log` beside bare entries
means another clone's older `owed.sh` did it, and there is no pre-image anywhere. **I
touched none of them** — a rule debt clears only when the user says so.

**No `look` debt.** `src/ase_window.tcl` is untouched and nothing new is drawn.

**No `suite` debt beyond the display-arm runs recorded below**, which were taken.

---

## For the driver

* T1 was **not** run by this crew (issue 0990 — the driver runs it solo).
* **Nothing was committed, added, stashed, restored or cleaned.**
* `NUMBERING.md`'s pointer was advanced **1430 → 1431** in the same edit as the entry. Both
  mint checks were run before minting: the reserved-band scan over this clone's head table
  (**silent** for 1430) and `ls ~/dev/*/doc/claude/issues/1430-*` plus
  `/usr/bin/grep -lw 1430` across every clone's `NUMBERING.md` (only this clone's own
  pointer line).
* ✅ **All three suites this task moves ARE in `run_regression.tcl`** — `test_ase_preflight`
  (`:29`), `test_ase_optier_0963` (`:67`) and `test_ase_core` (`:75`, added by issue 1413).
  **Nothing here is outside T1's reach**, which is unusual for this batch and worth saying
  plainly: issue 1421 lists twenty-one `test_ase_*` suites T1 cannot verify and **none of
  them moved**.
* **The whole ASE family (29 suites) was re-run headless after the last edit**, every run
  `timeout 400`-bounded: **27/27 passed, 2 self-skipped** (`test_ase_dirty` and
  `test_ase_log_seam_0207`, both of which need an X connection and say so in their own first
  line). `test_ase_core` **453**, `test_ase_preflight` **194**, `test_ase_optier_0963`
  **105** (its headless arm, which is the one `run_regression.tcl` runs), `test_ase_cosim`
  **341**, `test_ase_simcaps_0948` **190** — the last two unmoved.
* **Both binaries were exercised end to end**, through ASE-L's own `render_deck`, in a
  scratch directory under `/tmp`: the fork
  (`/home/analog/dev/ngspice/build-ver_50/src/ngspice`, `ngspice-46+`) and `/usr/bin/ngspice`
  (`ngspice-45.2`). Byte-identical sidecars and byte-identical `Plotname:` lists on both,
  with `ase::reconcile_plots` answering `ok` 4/4/4 on both. **Nothing under `~/.xschem/` was
  touched and no bench under `sky130A/` was run**; every xschem invocation was given a path
  (`./src/xschem`) and `--nolog`, never `--logdir`, never a bare `xschem`.
* **The display arm (`:99`, openbox 3.6.1 live, `1920x1080x24`, confirmed by
  `devdisplay.sh status` before the run) was taken through `run_suites.sh`**,
  `SUITE_TIMEOUT=400`: `test_ase_core` **ALL PASS (453)**, `test_ase_preflight` **ALL PASS
  (194)**, `test_ase_cosim` **ALL PASS (341)**, `test_ase_simcaps_0948` **ALL PASS (190)**,
  and `test_ase_optier_0963` **TIMEOUT after 400 s** — the filed pre-existing display-arm
  stall, hit in the same place by all three Stage 5 crews and by 1429. `4/5 runs passed`.
  No orphan: `pgrep -af src/xschem` is clean afterwards.
* ⚠ **`test_cosim_golden_e2e` has ONE PRE-EXISTING headless FAIL, measured BEFORE this
  change and identical after it**: `GE24-matches-the-golden`, a digital VCD timestamp off
  by one nanosecond (`TOP.counter.next_count 1950011` against `1950012`). It is not in
  `run_regression.tcl`. Nothing in this commit touches co-simulation; `test_ase_cosim` is
  ALL PASS (341) before and after.
