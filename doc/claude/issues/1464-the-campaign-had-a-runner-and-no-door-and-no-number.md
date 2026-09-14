# 1464 — the campaign had a runner and no door, and no number at the end of it

**Stage 11 task 2 of two — the campaign DIALOG (§11a/§11b) and the RESULT TABLE
(§11c).** `doc/claude/ase_analyses_batch/PLAN.md` §11,
`APPENDIX_ngspice_analyses.md` §4. ⚖ **R8** is answered (the campaign lives in
the simulation state, no artifact on the schematic); ⚖ **R9** is the open ruling
and every new sentence is filed under it.

Files: `src/ase_window.tcl`, `src/ase.tcl` (the §11c statistics only),
`tests/headless/test_ase_campaign_gui_1464.tcl` (new), `tests/run_regression.tcl`,
`doc/claude/issues/NUMBERING.md`.

## What goes wrong for the user

Issue **1462** shipped 44 core procs, five adapter hooks, a Monte Carlo sampler
and an `index.tsv` writer — and **built no widget**. On the tree as it stood:

* the only way to put a `sweep` key on a bench was to **close ASE-L and
  hand-edit the `.state` file**;
* the only way to start a campaign was `ase::campaign_run` from the Command
  window;
* the only way to read a campaign's answer was to open a directory of rawfiles;
* and §11c's whole claim — *"the campaign ends with a NUMBER, not a directory"* —
  had **no implementation at all**. Histogram, mean, sigma, min/max, yield
  against a spec limit and a scatter of any two columns did not exist anywhere,
  because ngspice has no sort, no median, no percentile and no histogram to
  borrow them from.

§11b's claim is sharper still: *"ADE-L cannot show you its samples."* A sample
set that can only be read by opening a TSV in another program is not shown.

## What shipped

**A `Simulation > Campaign…` dialog**, directly below `Convergence…`: the enable
switch, the seed, a table of axes with Add/Edit/Delete, the campaign's own note
line (core's sentences, never a second wording), **Run Campaign**, **Stop**, a
`k/N` progress readout and a door to the result table.

**An axis editor built entirely from declarations.** Not one `switch` on a kind:
the kind list, each kind's display label and each kind's fields come from
`ase::campaign_axis_kinds` — the adapter's — and the distribution list and each
distribution's parameters come from `ase::mc_dists` — core's. A simulator that
declares a sixth kind tomorrow gets a form for it with nothing edited in
`ase_window.tcl`; one that declares none gets core's own refusal instead of an
empty picker (D34/D36).

**§11c's result table**: `index.tsv` in full, one row per point run or not, with
a column picker, mean / sigma / min / max / median, a spec limit and a yield
number, a **histogram** with the spec limits drawn on it, a **scatter of any two
columns**, **Export** to TSV or CSV, and **Re-run Point**.

**Twelve `ase::stat_*` procs and `ase::campaign_export_text` /
`ase::campaign_rerun` in core**, because a mean computed inside `ase::ui::` can
only be tested on an arm that has a display — the arithmetic that decides a
**yield number** would be measured by half as many rows as the widget that
prints it. `PLAN.md` §11's *Files and procs* already put "the Tcl statistics" in
`src/ase.tcl`; this is the sharper reason.

## ⚠ The measurement that reshaped this task: `1k` is not a number

A campaign's axis column holds the values the **user typed** — `1k 2k 4.7meg`,
not `1.000000e+03` — and `string is double` rejects every one of them. Measured
here, on the first scatter that was asked for:

    ase::stat_pairs $rows myres pm         ->  {}
    ase::stat_pairs $rows myres pm $sufs   ->  {1000.0 55.0} {2000.0 60.0}

So a histogram of a swept axis had **no bars** and a scatter of axis against
measurement had **no points** — silently, on the commonest campaign there is,
and a picture with nothing in it is indistinguishable from a campaign that has
not run. **Which** suffixes exist is the simulator's fact (D34), so they are an
argument: `ase::stat_suffixes <sim>` resolves the adapter's `si_suffixes` hook
and `{}` means plain numbers only — which is also the non-vacuity control, rows
ST20/ST20b.

The suffix parsing itself goes through `ase::si_parse`, the tree's one suffix
reader, which already carries the longest-match rule that keeps `meg` from being
read as `m`. A second reader here would be the copy that drifts (row ST21).

## ⚠ And a `-` is not a zero

`ase::campaign_index_row` writes `-` for a point that never ran **and** for a
measurement that produced nothing — and measured on both binaries (issue 1451), a
measurement that finds nothing exits 0, leaves `$sim_status` 0 and prints
**nothing**. A mean that read `-` as 0 would pull a yield number toward the
failing side and say nothing about it. Every reader drops non-numeric cells and
every summary reports `n` beside `rows`, so the panel says **`n = 28 of 30`**
whether or not they differ.

## ⚠ And sigma divides by n−1

A Monte Carlo column is a **sample** drawn from a process, not the population.
Dividing by `n` understates sigma by `sqrt((n-1)/n)` — 1.7 % at n = 30, 5 % at
n = 10 — and **understating sigma overstates yield**, which is the one direction
an error in this number must not go: it is the number a user reads to decide the
circuit is good enough. Rows ST2/ST2b tell the two forms apart by measurement.

## ⚠ Two defects this task's own suite found in this task's own code

1. **`Run Campaign` could not run from a window whose design was not current.**
   Measured on the dev display: `ase: design glib/bench is not open in this
   window; open it via Session > Design Window first`, from a window where
   `Netlist and Run` works perfectly. That is **issue 0643's complaint
   reappearing on a new button** — *"Where does this inane restriction come
   from? There is no such limitation in Cadence's ADE-L"* — because the design
   routing lived **inline inside `ase::ui::do_run`** and a second door could
   only copy it or go without it. Extracted as `ase::ui::route_design`, called by
   both. Two procs each deciding what "reachable" means is what invariant I1
   forbids.
2. **`Run` was live on an empty form.** `campaign_refusals` is silent for a bench
   with no campaign at all — there is nothing to refuse — so refusals alone left
   the button enabled where pressing it could do nothing but print *"this
   campaign has no points to run"*. A button that can only say no is a button
   that lies. The point count is now the second half of the predicate, asked
   through core's odometer rather than by counting axes.

## ⚠ A third, found by the suite dying instead of reddening

`ase::ui::camp_run`'s five early paths returned `{}`. The suite's own end-to-end
row reads `dict get $res status`, so a refusal **raised** — and `--nogui --pipe`
exits 0 on an uncaught mid-script Tcl error, so the suite **died after the row
before it and printed no `RESULT:` line at all**. That is the failure shape the
crew brief names, met in this task, and the repair belongs in the door rather
than in the row: **every path out of `camp_run` now answers a dict with a
`status`** (`nowindow`, `busy`, `unreachable`, `refused`, `nopoints`,
`nonetlist`, `raised`, `stopped`, `done`). A door whose refusal is
indistinguishable from its success is hard to test because it is hard to use.
Rows **GR13 / GR13b**.

## ⚠ The first canvas ASE-L has ever drawn, and the theme walk had no arm for it

`ase::ui::_theme_widget` has an arm per widget class and **no `Canvas` arm**, so
both plots kept stock Tk's `#d9d9d9` inside a window the walk had painted — and
under xschem's shipped `dark_gui_colorscheme 1`, a light grey panel in a dark
window. That is the class issue **1398** measured 58 widgets of. The ground is
`table`, not `panel`: a plot is a data surface like an Entry or a Treeview. No
new colour is minted — bars and marks are `accent`, axes are `disabledfg`, text
and the spec lines are `fieldfg`, all from the USER-LOCKED palette. Row GT5.

## ⚠ Issue 1463 reaching the screen

1463 is filed and unfixed: a registered binary that never answers the capability
probe costs `ase::cap_budget_ms` — **30 s** — on **every shard**, because a
timed-out probe is not cached. A readout that reported the point that just
*finished* would sit on `0 of 100` for the whole of point 1 and on `1 of 100`
through the whole of point 2 — fifty minutes of a number that never moves, which
would be a second defect stacked on the first. So the readout names the point
that is **about to start**, with its coordinates: `point 3 of 12 — running
(myres=2k, temp=125)`. The seam is `ase::campaign_run`'s own `onstep` callback;
the first point is painted before the call. Rows GR9/GR9b/GR9c.

Measured incidentally and worth recording: a **three-point** campaign invoked the
stand-in simulator **ten** times, because `ase::run_deck` asks `ase::cap_report`
on every run and the probe runs the binary too. Harmless at 0.014 s; thirty
seconds per shard against a binary that cannot answer.

## Stop

`Stop` sets the flag `onstep` reads **and kills the shard that is running**,
through `ase::run_in_flight [ase::run_lock_key <shard state>]` — the same
authority `Simulation > Stop` uses, keyed on the shard's own results file, so it
can only ever name the process this campaign started. Every completed point is
kept, by construction: each point is its own process writing into its own
directory and `index.tsv` is rewritten after **every** shard rather than once at
the end. Closing the dialog mid-campaign does the same thing.

## Suites

`tests/headless/test_ase_campaign_gui_1464.tcl`, **NEW at 78 headless / 156 on
the dev display**, registered in **both** `hcases` and `dcases` of
`tests/run_regression.tcl`. Section EE starts **both** binaries on **both** arms
and checks the measurement column against **physics** — a resistive divider,
`v(out) = 1k/(rtop+1k)`, so 0.5 / 0.25 / 0.1 — then checks the panel's mean,
sigma, median, histogram and yield against that column rather than a fixture.

The two one-directional traps the brief names are asked the other way round:

* **GT2/GT3/GT3b** — the table's columns are asked as **equality** with the index
  file's own header, and a bench that gains an enabled measurement must gain
  **exactly** that column (and lose exactly it again), the whole chain walked
  from the state through `campaign_index_header` through `index.tsv` on disk to
  the treeview. A table that renders the columns it knows about cannot notice one
  it dropped.
* **ST14/GT6/EE4** — the histogram's bins must **sum** to the numbers read, and
  the numbers read plus the unreadable cells must be **one row per point of the
  odometer**. A picture that bins the samples it was given cannot notice a sample
  that never arrived.

## Still open

* **⚖ R9** — every sentence this task mints is in
  `doc/claude/ase_analyses_batch/receipts/39-stage-11-gui.md`, verbatim, and
  filed as `owed.sh add rule 1464`.
* **🔭 M5** — the multi-raw family. A campaign produces one rawfile per point and
  nothing in the waveform viewer or the Calculator handles a family;
  `doc/claude/specs/calculator.md` says v1 handles only the single-raw
  multi-dataset case. This task did **not** invent that contract: the result
  table is a view over `index.tsv`, which is a table and not a waveform, and
  §11c's statistics are computed from it. M5 stays open as a conversation.
* **Issue 1463** — the per-shard probe cost. Named, visible in the readout, not
  fixed here: it is `ase::sim_capabilities`' caching policy, not the campaign's.
* **Per-shard chatter.** `ase::run_deck` and `ase::run_done` say four to eight
  sentences per run, so a 200-point campaign says a thousand lines in the CIW.
  Nothing is wrong with any of them and the run body must stay as loud as it is
  for a single run; whether a campaign may quiet them is the user's to rule.
  The progress readout is the spine a person actually follows, and it is in the
  dialog rather than in the log.
