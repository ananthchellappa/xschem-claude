# 1430 — two sensitivity plots in one results file, and nothing said which row wrote which

**Stage 6 of `doc/claude/ase_analyses_batch/`, second commit: the writer, the sidecar and
reconciliation (`PLAN.md` 6a, 6b, 6c).** The first is issue **1429**, ⚖ R3's reader seam.
Nothing here touches that seam, or `noise`/`disto`/`sens (ac)` (6d), or checkpointed
salvage (6f), or the variant mitigations (6g), or `src/ase_window.tcl`.

## The defect

ASE-L's deck writes one plot per analysis into one results file (`set appendwrite`, issue
0929), and **the results file carries no way to tell two plots of the same type apart.**

Measured 2026-09-12, one deck, two enabled `sens` rows, **identical on the fork
(`ngspice-46+`) and on `/usr/bin/ngspice` (`ngspice-45.2`)**:

```
sens v(mid) r1 dc / write   ->   Plotname: Sensitivity Analysis
sens v(mid) r2 dc / write   ->   Plotname: Sensitivity Analysis
```

Nothing in the file separates them, and **the plot literal cannot separate them even in
principle**: two *different* analyses already share `Sensitivity Analysis` (`sens … dc` and
`sens … ac`, APPENDIX §0.7), and two rows of one type share it by construction. Order is
not an answer either — the write order is `ase::analysis_emit_order`'s rank, which moves
under issue 0964's `op`-last variant.

**And "one analysis, one plot" is itself wrong.** Measured the same day, one analysis per
deck, walked with `setplot previous`, both binaries:

| with `.options keepopinfo` | plots written |
|---|---|
| `ac` | `AC Analysis` **+ `AC Operating Point`** |
| `pz` | `Pole-Zero Analysis` **+ `Distortion Operating Point`** (upstream's copy-paste) |
| `tf` | `Transfer Function`, and nothing else |
| `sens` | `Sensitivity Analysis`, and nothing else |

ngspice's `write` writes **the current plot**, so the companion is computed and thrown
away — issue 0929's defect one level down, "one plot per *analysis*" instead of "one plot
per *run*", and equally silent.

## What this changes

Fourteen new core procs, one registry row, four new refusals in the registry validator,
two lines in the emitted deck, and two calls on the run path. **`src/ase_window.tcl` is untouched.**

| proc | class | what it answers |
|---|---|---|
| `ase::plotmap_path {state}` | core, **schema** | `<rundir>/<cell>_ase.plotmap` |
| `ase::plotmap_record {type idx name}` | core, **schema** | the record, spelled once |
| `ase::plotmap_parse {line}` / `ase::plotmap_read {path}` | core, **schema** | read back, in file order |
| `ase::option_enabled {state name}` | core, **schema** | is a `.options` row switched on |
| `ase::plot_when_valid {when}` / `ase::plot_when {when state}` | core, **schema** | 6b's predicate: 1 / 0 / `unknown` |
| `ase::analysis_plots {sim row state}` | core, **schema** | every plot this row is PREDICTED to produce |
| `ase::analysis_captures` / `ase::analysis_uncaptured` | core, **schema** | the half the deck writes, and the half it does not |
| `ase::plot_capturable {p}` / `ase::plot_select {p}` | core, **schema** | the split, and the declared literal |
| `ase::reconcile_plots {sim state rawpath mappath}` | core, **schema** | 6c's four arms |
| `ase::reconcile_report {state}` | core, **schema** | said once per run, through `ase::echo` |

The **format** is schema and the **emission** is content (D34–D37). The sidecar is ASE-L's
own artefact — rendered by ASE-L's deck, deleted by ASE-L before every run, read by ASE-L
and by nothing else — so the record is spelled once in core and parsed once in core. What
stays in `ase::backend::ngspice::render_deck` is the three ngspice words that carry it:
`echo`, `>>` and `$curplotname`.

### The emitted deck, and the one line that is new

```
<analysis>
if $?sim_status = 0 … end / if $sim_status ne 0 … quit 1 … end
remzerovec
echo "PLOT <type> <row index> |$curplotname|" >> <cell>_ase.plotmap     <- NEW
write <raw> [all <device names>]
  ... repeated (captured plots − 1) times:
  setplot previous
  remzerovec
  echo "PLOT <type> <row index> |$curplotname|" >> <cell>_ase.plotmap
  write <raw>
```

A single-plot analysis emits **exactly what it emitted before, plus the record** — so the
`setplot previous` walk costs the ordinary deck nothing at all, and `test_ase_core.tcl`'s
**D1** is the **only** deck golden in the tree that moves.

⚠ **THE INDEX IS THE ROW'S POSITION IN `analyses`, NOT A COUNTER.** A counter says "the
third plot"; the position says **which row**, which is the entire reason the file exists.

⚠ **`$curplotname` IS READ AT THE MOMENT OF THE WRITE, NEVER PREDICTED.** The record says
what ngspice actually had in hand; the registry's own `select` is what reconciliation
compares it against, and a disagreement is a **finding** rather than a silent relabel.

⚠ **`echo … >> path` IS THE ONLY SHAPE THAT WORKS**, and the alternatives are measured
dead ends: a capture loop cannot name the plots from inside the deck (`foreach p $plots`
yields `"const` — the quoting is ngspice's), `.control`'s `if` takes the **false** branch
on both `eq` and `ne` for strings, and `$plots` cannot be subscripted. `PLAN.md`'s
correction C1 says the same thing from the other side.

## The measured refusal: an `opinfo` plot is PREDICTED and NOT CAPTURED

⚠ **This refutes `PLAN.md` 6a**, which has the walk capture every plot.

`src/save.c`'s `read_dataset()` matches `strstr(lowerline, "operating point")` **before**
its AC arm, so `AC Operating Point`, `Distortion Operating Point` and `NOISE Operating
Point` all read back as `sim_type` **`op`**. Measured 2026-09-12 on a results file holding
the companion **and** the real operating point, the two made to disagree by an `alter`
between them:

```
xschem raw read <file> op    ->  points=2, vars=3, datasets=2 sim_type=op
xschem raw value v(in)  0    ->  2         <- the AC operating point
xschem raw value v(mid) 0    ->  1         <- ... and the real one is 0.5
```

So capturing the companion would make **Annotate Operating Point publish the wrong numbers
onto the schematic** whenever `keepopinfo` is on and both `ac` (or `pz`) and `op` are
enabled — issue 0929's defect wearing the other coat. ASE-L cannot filter it on the read
side either: the match is in C, over the whole file, and `ase::attach_dbs` hands
`xschem raw read` the file entire.

The companion therefore needs a **results file of its own** (`<cell>_ase.opinfo.raw`,
deleted per run like this one) before it can be captured at all, and that is a separate
artefact with a separate reader. Until then the run **says** the plot exists and says it is
not in the file — which is strictly better than today, where nothing is said at all.

## 6c — the three facts reconciliation compares, and the arm counting cannot see

After every run, before anything is attached: the **prediction**
(`ase::analysis_captures` over the enabled rows), the **record** (the sidecar), and the
**reality** (`ase::cap_raw_plots` over the results file).

| verdict | when | what is said |
|---|---|---|
| `norun` | neither | nothing — `ase::raw_content_verdict` already speaks for that case |
| `nomap` | plots on disk, no sidecar | the plots cannot be matched to the rows that asked for them |
| `mislabel` | a record disagrees with the file, or with the registry's `select` | which side holds what, naming the row |
| `under` | fewer plots than records | *"one plot of the `tran` analysis was not captured"* |
| `over` | more plots than records | *"this run captured N plots where the registry expected M"* |
| `predmismatch` | the enabled rows no longer fit the record | the two numbers that disagree |

⚠ **`under` IS THE CASE THAT IS SILENT TODAY.** ngspice's `write` aborts **silently** when
a zero-length vector survives into the plot — which is the entire reason `remzerovec`
precedes every write — so the run exits 0, the log says nothing, and the results file is
simply one plot short.

⚠ **AND `mislabel` IS THE ARM NOBODY WOULD PREDICT.** Measured 2026-09-12, both binaries: a
walk that asks for one plot more than the analysis produced does **not** fail — `setplot
previous` **saturates** on the built-in `constants` plot (`Warning: No previous plot is
available. Plot remains unchanged (const).`, on **stderr**, where nothing in this tree
looks) and the next `write` appends ngspice's twelve mathematical constants to the results
file under a perfectly plausible record. **Every count agrees.** Only the registry's own
`select` disagrees, and comparing it is the only thing that can see it. Row **RC5**.

## The `plots` key stops being decoration

`plots` was declared by four registry entries through Stages 1–5 and **read by nothing**.
Issue 1428's sabotage S35 named that class in as many words: *a key read by nothing is a
key checked by nothing.* `ase::analysis_schema_errors` — the validator this registry
already runs — now refuses four ways of getting it wrong: `noplots` (a renderable type
whose results nothing can name), `noplotselect`, `noplotrole`, and `badplotwhen`.

⚠ **`badplotwhen` IS THE ONE THAT MATTERS.** A `when` form the evaluator cannot read makes
`ase::plot_when` answer `unknown`, and **both** consumers then exclude the plot — so the
deck silently stops capturing a plot the registry says it captures, at rc 0, with nothing
on either stream. A validator is the only place that can be seen.

## What it looks like end to end, on both binaries

A state with **two enabled `ac` rows** (`dec 10 1 10k` and `lin 5 1k 2k`) plus `op` and
`tran`, rendered by `render_deck`, run in a scratch directory. `rc 0` on the fork and on apt
45.2, and `paste(1)` of the sidecar against the results file:

```
PLOT op   0 |Operating Point|      @ Plotname: Operating Point
PLOT ac   1 |AC Analysis|          @ Plotname: AC Analysis
PLOT ac   2 |AC Analysis|          @ Plotname: AC Analysis
PLOT tran 3 |Transient Analysis|   @ Plotname: Transient Analysis
```

Byte for byte identical on the two binaries. `ase::reconcile_plots` over those artefacts:
**`ok`, 4 / 4 / 4, and nothing said.** The two `AC Analysis` plots are told apart by **1**
and **2**, and nothing else in the file can tell them apart.

⚠ **And a run whose analysis FAILED keeps the sidecar 1:1.** An earlier end-to-end deck
carried two `sens` rows whose third analysis failed on both binaries (`RUN-FAILED`,
`quit 1`, rc 1): **2 records, 2 plots, matching**. The `$sim_status` guard quits **above**
the record, so the analysis that failed appended nothing — which is row **PF218f2** against
deck text, confirmed here against a live simulator. That run also corrected a sentence: the
`predmismatch` note said *"the analyses changed between rendering the deck and reading it
back"*, and the real cause was the run stopping early. It names both now.

## What the user sees

* Two sensitivity analyses in one run stop being indistinguishable — and so do two rows of
  any type.
* When a plot goes missing, the run log **says which type lost it**. Today it says nothing.
* When an analysis computes a plot ASE-L deliberately does not keep, the run **says so, and
  says why**.

## Suites

| suite | before | after |
|---|---|---|
| `test_ase_core` | 417 | **453** — new sections **PM**, **GP**, **WK**, **RC** |
| `test_ase_preflight` | 192 | **194** — **PF218f2**, **PF218f3** |
| `test_ase_optier_0963` | 103 | **105** — **E5b**, **E5c** |

All three are in `tests/run_regression.tcl` (lines 29, 67 and 75), so T1 covers every row
this issue adds.

**One deck golden moved and it is named: `test_ase_core.tcl`'s D1** (with `C4` and `C5`,
which compare against it). One fixture moved without its row moving: `em_bad_types` (row
**EM9**) gained a valid `plots` key, so that row keeps testing the field/slot contradiction
alone. `ase::state_default` still seeds exactly **four** rows, no `seed_enabled` is
declared anywhere, and the **104 committed `.state` files are byte-identical** — section
**CP** is the row that would notice.

## Rulings

⚖ **R9** — four new user-facing sentences (the `under`, `over`, `mislabel`/`nomap` and
uncaptured-companion notes). Recorded as `owed.sh add rule 1430`.

⚖ **R3 is untouched and still unanswered.** This issue neither reads a number nor moves a
print line.
