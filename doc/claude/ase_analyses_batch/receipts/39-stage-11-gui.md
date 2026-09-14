# Issue 1464 — the campaign had a runner and no door, and no number at the end of it

**Stage 11, task 2 of two — the campaign DIALOG (§11a/§11b) and §11c's RESULT
TABLE.** Files I own and touched, and nothing else: **`src/ase_window.tcl`**,
**`src/ase.tcl`** (the §11c statistics and two campaign readers — see *Why core
grew* below), **`tests/headless/test_ase_campaign_gui_1464.tcl`** (new),
**`tests/headless/test_ase_window.tcl`** (one row's expectation),
**`tests/run_regression.tcl`**, plus
`doc/claude/issues/1464-the-campaign-had-a-runner-and-no-door-and-no-number.md`,
`doc/claude/issues/NUMBERING.md` and this receipt.

No commit, no `git add`, no stash, no restore, no clean, no push.
`tests/run_regression.tcl` **not run** (issue 0990 — the driver's, solo). **No
simulation on any bench under `sky130A/` or `ihp-sg13g2/`**: every simulator run
below is a hand-written deck or an ASE-L-rendered deck under the suite's own
scratch directory, against an explicit binary path. Nothing under `~/.xschem/`
was opened for writing.

**Floors:** `test_ase_campaign_gui_1464` **NEW, 78 headless / 156 on the dev
display**; `test_ase_window` **295 → 295** (no row added; one row's *expectation*
moved, with its own paragraph in the same diff). Every other ASE suite unmoved
on both arms.

---

## ⚠ THE HEADLINE: `1k` IS NOT A NUMBER, AND A HISTOGRAM OF A SWEPT AXIS HAD NO BARS

A campaign's axis column holds the values the **user typed** — `1k 2k 4.7meg`,
not `1.000000e+03` — and `string is double` rejects every one of them. Measured
here, on the first scatter this task asked for:

```
ase::stat_pairs $rows myres pm         ->  {}
ase::stat_pairs $rows myres pm $sufs   ->  {1000.0 55.0} {2000.0 60.0}
```

So a histogram of a swept axis drew **no bars** and a scatter of axis against
measurement drew **no points**, silently, on the commonest campaign there is —
and a picture with nothing in it is indistinguishable from a campaign that has
not run. This is failure mode 6 in its own right: *a histogram that bins the
samples it was given will not notice a sample that never arrived*, and here the
whole column never arrived.

**Which suffixes exist is the simulator's fact (D34)**, so they are an argument
rather than a set in core: `ase::stat_suffixes <sim>` resolves the adapter's
existing `si_suffixes` hook, and `{}` means plain numbers only. That is also the
non-vacuity control — rows **ST20 / ST20b** read the same column with the
suffixes given and withheld, and the withheld read is EMPTY.

The parsing itself goes through **`ase::si_parse`**, the tree's one suffix
reader, which already carries the longest-match rule. Row **ST21** is why a
second reader was not written: `1meg 1m` → `1000000.0 0.001`, and a naive
first-character match makes a megahertz a millihertz — nine orders of magnitude,
silently.

## ⚠ AND TWO DEFECTS THIS TASK'S OWN SUITE FOUND IN THIS TASK'S OWN CODE

**1. `Run Campaign` could not run from a window whose design was not current.**
Measured on the dev display, with the fixture bench open and `Netlist and Run`
working perfectly from the same window:

```
ase: design glib/bench is not open in this window; open it via Session > Design Window first
```

That is **issue 0643's complaint reappearing on a new button** — the user's own
words, *"Where does this inane restriction come from? There is no such
limitation in Cadence's ADE-L"* — and the cause was structural: the design
routing lived **inline inside `ase::ui::do_run`**, so a second door could only
copy it or go without it. Extracted as **`ase::ui::route_design`**, called by
both. Row **RD10** is structural and asks it in both directions: both doors call
it, and **neither** re-inlines `ase::stack_level`.

**2. `Run` was live on an empty form.** `ase::campaign_refusals` is silent for a
bench with no campaign at all — there is nothing to refuse — so refusals alone
left the button enabled where pressing it could do nothing but print *"this
campaign has no points to run"*. A button that can only say no is a button that
lies. The point count is now the second half of the predicate, asked through
core's odometer rather than by counting axes (an axis with an empty list
contributes nothing and empties the whole campaign). Rows **GC4 / GR1c**.

**3. A refusal out of `Run Campaign` could not be told from a success.** Its five
early paths returned `{}`, so the suite's own end-to-end row — `dict get $res
status` — **raised**, and `--nogui --pipe` exits 0 on an uncaught mid-script Tcl
error: the suite **died after the previous row and printed no `RESULT:` line at
all**. That is the exact failure shape the brief names, met here, and the repair
belongs in the door and not in the row: **every path out of `camp_run` now
answers a dict with a `status`**. A door whose refusal is indistinguishable from
its success is hard to test because it is hard to USE. Rows **GR13 / GR13b**.

## ⚠ AND THE FIRST CANVAS ASE-L HAS EVER DRAWN, WHICH THE THEME WALK COULD NOT SEE

`ase::ui::_theme_widget` has an arm per widget class and had **no `Canvas` arm**,
so the histogram and the scatter kept stock Tk's `#d9d9d9` inside a window the
walk had just painted — and under xschem's shipped `dark_gui_colorscheme 1`, a
light grey panel in a dark window. That is the class issue **1398** measured 58
widgets of, at 1.119:1. The ground is `table`, not `panel`: a plot is a data
surface like an Entry or a Treeview. **No new colour is minted** — bars and
marks are `accent`, axes `disabledfg`, text and the spec lines `fieldfg`, all
from the USER-LOCKED palette. Row **GT5**.

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

| claim | evidence |
|---|---|
| `string is double` rejects `1k`, so a swept axis column reads as empty without the adapter's suffixes | **MEASURED HERE**, transcript above; rows ST20/ST20b are the pair |
| `string is double` answers 1 for `nan` and `inf`, `double("nan")` RAISES, `double("1e400")` answers `Inf` | **MEASURED HERE** in `tclsh`, all ten literals; row ST7 |
| `meg` must be matched before `m` | **TRANSCRIBED** from `ase::si_parse`'s own header, then **MEASURED** as row ST21 through the shipped reader |
| the sample sigma (n−1) and the population sigma (n) give 2.13809 and 2.0 on the same eight numbers | **MEASURED HERE**; ST2 asserts the first, ST2b tells them apart |
| a measurement that finds nothing exits 0 and prints nothing, so `-` is a common cell | **TRANSCRIBED** from issue 1451 / `run_finished`'s own comment. Not re-measured; the consequence (a `-` is not a zero) is measured, rows ST1/ST1b |
| `Run Campaign` refused from a window where `Netlist and Run` works | **MEASURED HERE** on the dev display, full sentence above |
| `_theme_widget` has no `Canvas` arm | **READ** from the source, then **MEASURED** as GT5 by mutation w15 |
| a three-point campaign invokes the stand-in simulator **ten** times | **MEASURED HERE** — `ase::run_deck` asks `ase::cap_report` per run and the probe runs the binary too; it is issue 1463's cost seen from the other side |
| 104 committed `.state` files round-trip byte-identically | **COUNTED AND MEASURED LIVE** (`git ls-files`, `ase::state_load` → `ase::state_save`), with two controls in the same loop |
| ⚠ `ase::state_serialize` alone is **not** the byte-identity mechanism | **MEASURED HERE, AND IT COST A FALSE ALARM** — see the corrections |
| the divider campaign's measurement column is 0.5 / 0.25 / 0.1 | **MEASURED HERE** on **both** binaries, section EE |
| baselines: campaign_1462 133/133, simreg_0931 117, core 638, persist 49/153, conv_gui 45/104, converge 76, window 56/295, dialogs 37 / 1 FAILED (384) | **RE-MEASURED HERE** before I edited anything |

---

## What shipped

### The dialog — `Simulation > Campaign…`, last on the menu

The enable switch, the seed with its caution, a **table of axes** (Kind, Column,
Values, Points) with Add/Edit/Delete, the campaign's **note line**, **Run
Campaign**, **Stop**, the **`k/N` progress readout** and a door to the result
table. The note line prints **core's own sentences** — the refusals when there
are any, the run notes otherwise, and the "no axes yet" sentence when there is
neither. A second wording of one refusal is the drift `ase::analysis_unrenderable_msg`
exists to stop.

### The axis editor — built entirely from declarations

**Not one `switch` on a kind.** The kind list, each kind's display label and each
kind's fields come from `ase::campaign_axis_kinds` (the adapter's); the
distribution list and each distribution's parameters come from `ase::mc_dists`
(core's). Rows GA2/GA2b/GA3/GA3b/GA4 assert every one of those against the hook
itself rather than a list typed in the suite, so a simulator that declares a
sixth kind gets a form for it with nothing edited here. A kind with **no**
fields — `temp` — is a real answer and still looks like a complete form (GA5).

### §11c's result table

`index.tsv` in full, one row per point run or not; a column picker; mean, sigma,
min, max and median; a spec limit with a yield number; a **histogram** with the
spec limits drawn on it; a **scatter of any two columns**; **Export** to TSV or
CSV; **Re-run Point**.

### Why core grew, and what it grew

`src/ase.tcl` gained **twelve `ase::stat_*` procs**, `ase::campaign_export_text`
/ `_formats`, `ase::campaign_index_exits` and `ase::campaign_rerun`.
**I asked the question the brief told me to ask — is this a fact about ngspice?
— and the answer is no for every one of them**: they read a table of strings. The
brief's other test (does a *reader* genuinely have to grow) is met by a sharper
argument than PLAN.md's own *Files and procs* line: **a mean computed inside
`ase::ui::` can only be tested on an arm that has a display**, so the arithmetic
that decides a **yield number** would be measured by half as many rows as the
widget that prints it. The one place the simulator does get a say —
which SI suffixes exist — is an **argument**, resolved through the adapter's
existing `si_suffixes` hook by `ase::stat_suffixes`, with no fallback set.

---

## The decisions inside the arithmetic, each with its reason

| | |
|---|---|
| **sigma divides by n−1** | A Monte Carlo column is a SAMPLE, not the population. Dividing by n understates sigma by `sqrt((n-1)/n)` — 1.7 % at n = 30, 5 % at n = 10 — and **understating sigma OVERSTATES yield**, the one direction this number must not err in: it is the number a user reads to decide the circuit is good enough. ST2/ST2b |
| **a `-` is dropped, not read as 0** | `campaign_index_row` writes `-` for a point that never ran AND for a measurement that produced nothing. ST1/ST1b: the mean over a column carrying `-` must equal the mean over the same column with those cells physically removed, and must NOT equal the mean with them read as zeros. ⚠ **The first version of ST1b was calibrated against one wrong implementation and missed another** — it compared against 1.2, the answer if BOTH `-` and the empty cell were read as 0, and sabotage **s2** (which reads only `-` as 0, giving 1.5) slipped past it while ST1 caught it. Rewritten to compare against both wrong answers |
| **`n` is reported beside `rows`, always** | so the panel says `n = 28 of 30` whether or not they differ, and the gap is visible without the user knowing to look. RD7 |
| **no spec is not a 100 % yield** | `specified 0` and a `{}` percentage; the panel says *"Yield: give a spec limit"*. A number nobody asked for is worse than no number. ST13/RD8/GT9 |
| **spec limits are inclusive** | a design centred on its own limit must not fail its nominal corner. ST12 |
| **a one-sided spec is a real spec** | *"phase margin at least 45 degrees"* has no upper bound and inventing one would fail points that pass. ST12b |
| **a constant column is ONE bin** | `(hi-lo)/nbins` is 0 there, and a corner sweep whose measurement moved nothing is the answer a user most wants to see. ST9 |
| **an empty bin draws nothing** | a floor under the bar height would make a GAP in the distribution look like a sample — the same defect as a `-` read as a zero, one layer out in the picture. GT7c |
| **bins are bounded 4..24** | three points in eleven bins is a picture of nothing; forty bins over thirty samples is a comb. ST11 |
| **a scatter pair is dropped WHOLE** | keeping one coordinate would pair point 7's x with point 8's y and draw a correlation that does not exist. ST18 |
| **columns are found BY NAME** | an axis added to a campaign moves every measurement column to the right; a reader that remembered "column 4" would report a yield from the wrong column after an edit nobody connected to it. ST15/ST15b |
| **six significant digits** | the same decision and the same reason as `ase::mc_digits`: `log` and `sqrt` put their last bits in libm's hands. ST19 |

---

## ⚠ ISSUE 1463 REACHING THE SCREEN — what I chose, and why

1463 is filed and **not fixed**: a registered binary that never answers the
capability probe costs `ase::cap_budget_ms` — **30 s** — on **every shard**,
because a timed-out probe is not cached. The brief says plainly that a readout
sitting at `0/100` for fifty minutes would be a second defect on top of it.

**What I chose:** the readout names the point that is **about to start**, with
its coordinates — `point 3 of 12 — running   (myres=2k, temp=125)` — and never
`0 of N`. The seam is `ase::campaign_run`'s own `onstep` callback, which fires
*after* each point; what it paints is the **next** one, and the first is painted
before the call. **No new core seam was added for this**: the existing callback
is sufficient, and a second one would have been a change to committed code for a
surface concern. Rows GR9 / GR9b / GR9c drive the callback directly, so the
claim is measured without needing a slow simulator.

Measured incidentally and worth recording: a **three-point** campaign invoked the
stand-in simulator **ten** times, because `run_deck` asks `cap_report` on every
run and the probe runs the binary too. Harmless at 0.014 s; thirty seconds per
shard against a binary that cannot answer. The suite's tally now counts only
campaign decks, and says why in its own comment.

## Stop

`Stop` sets the flag `onstep` reads **and kills the shard that is running**,
through `ase::run_in_flight [ase::run_lock_key <shard state>]` — the same
authority `Simulation > Stop` uses, keyed on the shard's own results file, so it
can only ever name the process this campaign started. **There is no second kill
mechanism and no pattern match on a command line.** Every completed point is
kept by construction, and closing the dialog mid-campaign does the same thing
(`camp_cancel` sets the flag before it destroys the window).

⚠ **One limitation I am reporting rather than fixing.** Task 1 measured that a
killed shard whose simulator left a **grandchild holding the pipe** never
delivers EOF, so `campaign_wait` sits until its own budget. A Stop against such a
simulator therefore ends the campaign at the next point boundary but does not
shorten the current point. That is core's wait, not the button's, and task 1
already carries its own repair for the lock; I did not touch it.

---

## Both arms, before and after, from the `RESULT:` line

| suite | headless BEFORE | headless AFTER | display BEFORE | display AFTER |
|---|---|---|---|---|
| **`test_ase_campaign_gui_1464`** | — (new) | **ALL PASS (78)** | — (new) | **ALL PASS (156)** |
| `test_ase_window` | ALL PASS (56) | **ALL PASS (56)** | ALL PASS (295) | **ALL PASS (295)** |
| `test_ase_core` | ALL PASS (638) | ALL PASS (638) | ALL PASS (638) | ALL PASS (638) |
| `test_ase_persist` | ALL PASS (49) | ALL PASS (49) | ALL PASS (153) | ALL PASS (153) |
| `test_ase_campaign_1462` | ALL PASS (133) | ALL PASS (133) | ALL PASS (133) | ALL PASS (133) |
| `test_ase_simreg_0931` | ALL PASS (117) | ALL PASS (117) | — | — |
| `test_ase_conv_gui_1460` | ALL PASS (45) | ALL PASS (45) | ALL PASS (104) | ALL PASS (104) |
| `test_ase_converge_1459` | ALL PASS (76) | ALL PASS (76) | — | — |
| `test_ase_dialogs` | ALL PASS (37) | ALL PASS (37) | 1 FAILED (384) | **1 FAILED (384)** |

**Neighbourhood, every one ALL PASS and every one with a `RESULT:` line** —
headless: `test_ase_preflight` 235 · `test_ase_simcaps_0948` 211 ·
`test_ase_optier_0963` 109 · `test_ase_meas_1443` 113 ·
`test_ase_optsheet_1441` 62 · `test_ase_simdlg_0937` 5 · `test_ase_plot` 31.
Dev display: `test_ase_optsheet_1441` 87 · `test_ase_simdlg_0937` 55 ·
`test_ase_plot` 151 · `test_op_annot` 492.

The one display red is `test_ase_dialogs` at **1 FAILED (384 passed)**, the same
verdict I measured **before** I touched anything and the same one the crew brief
records as standing — the brief names the row as **`G2sens`**, issue **1436**.
⚠ **What I measured is the VERDICT LINE, not the row name**: I did not re-read
the failing row's own text, so "it is still G2sens" is transcribed from the brief
and from an unchanged count, not measured here. It is the only failure on either
arm of any suite above.

⚠ **`test_ase_window` reddened once, at `W1m`, and that is the row doing its
job.** It pins the Simulation menu's entry list exactly, so `Campaign…` had to be
added to it with a paragraph saying why the entry is last. Measured 1 FAILED
(294) before the row was updated and ALL PASS (295) after — **no row was added or
removed**, so the floor is unchanged.

⚠ **Section EE starts real simulators on BOTH binaries, on BOTH arms**, and both
ran. **Every run quoted in this receipt printed a `RESULT:` line**; there is no
run whose absence of output I am reading as a pass.

---

## `.state` byte identity — 104 of 104, with two controls

Measured live through `ase::state_load` → **`ase::state_save`**:

```
COMMITTED .state files: 104
ROUNDTRIP identical=104 mismatch=0
CONTROL non-empty sweep: differs
CONTROL empty sweep (what the dialog writes on OK): identical
```

**Both controls are in the same loop shape as the measurement.** The first gives
a real file a non-empty `sweep` and demands it come back DIFFERENT — so the
comparison is comparing rather than agreeing with itself. The second gives the
same file `sweep {}`, which is **exactly what the dialog writes when it is opened
and OK'd on a bench with no campaign**, and demands it come back identical. Row
**GC5** is the same claim inside the running program, and **GC5b** its control.

---

## The six ways a row fails to fail

1. **Fixtures that never disagree.** Every extractor has a control that must
   answer the null: **ST1b** (the mean with `-` cells present equals the mean
   with them REMOVED and equals neither read-as-zero answer), **ST2b** (the
   population sigma would answer 2.0), **ST20b** (the same column with the
   suffixes withheld is EMPTY), ST6b, ST10, ST13, ST15b, ST16b, RD5, RD9,
   GC5b, GC6b, GR1b, GT7b, GT10c, GT12, GX1, GX2, RR1b, RR4.
   ⚠ **And one of those controls was itself mis-calibrated and had to be
   measured**: ST1b originally compared against a single wrong answer (1.2) and
   sabotage **s2**, which produces a different wrong answer (1.5), walked past
   it. Rewritten to compare against the removal and against both read-as-zero
   forms.
2. **Position asked where the mechanism is last-writer-wins.** Inverted
   deliberately: **RD10** asserts both run doors route through **one** proc and
   that neither re-inlines the predicate — a behavioural row cannot see where a
   line sits, which is exactly what row S12 of `test_ase_simreg_0931` taught task 1.
3. **An extractor that returns nothing.** Every reader is total and answers a
   comparable value — `NOPROC`, `RAISED:…`, `NOWIDGET`, `NOFILE:…`, `{}` — and
   every call goes through `q_ans`, `q_w`, `q_cfg` or `q_slurp`. **RD9** demands
   six window readers answer `{}` for a session that does not exist.
4. **A sabotage missing from the generator.** My first list was short, as it has
   been for every crew in this batch, and it was short in two different ways.
   **Five rows were added before the campaign ran**, from reading my own
   mutation list and finding it had nothing to point at: **GR1b/GR1c** (a
   refusal displaces the run notes in the note line), **GR11b** (Stop really
   sets the flag), **GT5b** (the panel opens on the LAST column), **GT7c** (an
   empty bin draws nothing) and **RD10** (the structural one — both run doors
   through one router). **Six more were added after it**, from three separate
   causes: the third-`.dc`-level claim task 1 handed to this task had no row at
   all (**DC1/DC2/DC3**), the "dialog closed mid-campaign" comment had no row
   (**GX3**), and `camp_run`'s refusal paths were untestable until they answered
   a dict (**GR13/GR13b**). And **two existing rows were found agreeing with
   themselves** and rewritten: **GT8** (both sides called `stat_pairs`) and
   **GT10b** (the arithmetic passed whether or not the spec line was drawn),
   with **GT10c** added beside the second.
5. **Two halves tested in different suites.** **GR4 / GR5 / GR5b** go from the
   form's own state through `ase::ui::camp_run` to a real `campaign/` directory,
   a real `deck.spice`, a real `index.tsv` and one shard directory per point on
   disk — and ask the shard set in **both** directions. Section **EE** does it
   again on both real binaries with the measurement column checked against
   physics.
6. ⚠ **A one-directional row.** Both shapes the brief names are asked the other
   way round. **GT2 / GT2c / GT3 / GT3b**: the table's columns are asked as
   EQUALITY with the index file's own header, and a bench that gains an enabled
   measurement must gain **exactly** that column and lose exactly it again — the
   whole chain walked from the state through `campaign_index_header` through
   `index.tsv` on disk to the treeview. **ST14 / GT6 / EE4**: the histogram's
   bins must SUM to the numbers read, and the numbers read plus the unreadable
   cells must be **one row per point of the odometer**.

---
## THE SABOTAGE CAMPAIGN

One runner at a time, confirmed with `ps -e -o pid=,args=` before each launch;
restore is `cp` from a pristine snapshot with an **md5 compare printed every
time**. The table is a **name+status diff, never a count**. `camp` is
`test_ase_campaign_gui_1464` **on the dev display**, which is the arm that runs
every row — 156 against 78 headless, so the display arm is a strict superset and
one run covers both. Two collateral columns are carried and are only shown when
they move: `test_ase_core` (638, headless) and **`test_ase_window` (295, dev
display)**, the second because this task extracted a proc out of
`ase::ui::do_run` and added an entry to the Simulation menu that `W1m` pins.

**PASS 1 — 48 mutations, 46 killed by name, 1 anchor-miss, 1 survivor, 0
restore mismatches.** `restore: OK` printed on every line; `test_ase_core` was
**ALL PASS (638)** under all 48; `test_ase_window` was **ALL PASS (295)** under
all of them but **w20**, which is the point of carrying it. The anchor-miss is
**s15** — its anchor named the wrong file — and it is re-run in pass 2. The
survivor is **w24**, and it is written up above: it found a defect in the
product, not merely a hole in the suite.

**PASS 2 — the corrected `s15`, the mutations for the rows added after pass 1
(`DC1`–`DC3`, `GX3`, `GR13`/`GR13b`, the strengthened `GT8`/`GT10b`/`GT10c` and
the rewritten `ST1b`), and the four that pin the default-column repair
(`w33`/`w34`/`w35`, plus `w24b` — `w24`'s own defect, retried.)** It runs against
its own pristine snapshot, taken only after both arms were re-verified green.

⚠ **PASS 2 WAS DISCARDED AND RE-RUN, AND THE REASON IS WRITTEN UP BELOW.** Its
first five mutations all came back `NORESULT`, which is systemic rather than
per-mutation: the baseline it was measuring against was already broken by one of
my own patch scripts, and **my own green gate could not see an empty result**.
The five results were thrown away, the three defects behind them repaired, both
arms re-verified (**77 / 155**), a fresh snapshot taken, and the remaining
mutations re-run as one **FINAL PASS** of fifteen — the pass-2 set plus **`g1`**,
a deliberate `return -code error` inside `ase::stat_columns`, intended to prove
that a guarded section really does NAME its raise.

⚠ **`g1` did not prove that, and the MUTATION is what was wrong.** It reddened
`ST16`/`ST16b`/`GX0` and **not `ST0`**, because `q_ans` wraps every call in this
suite — a raise *inside* a proc becomes `RAISED:…` and never reaches the section
guard at all. `g1` measured `q_ans`, which is worth knowing and is not what it
was for. **The guard's real proof is `s15` itself**: the same mutation, on the
same binary, produced a bare `NORESULT` before the guards went in and reddens
**`EX2`** by name after. A before/after on one real mutation is stronger evidence
than a synthetic raise would have been — it is the defect that motivated the
repair, measured on both sides of it.

The final pass also carries the repair that came out of the diagnosis: **every
pure-Tcl section is now wrapped** the way the widget block and `EE` already were,
so `s15` — which produced the original `NORESULT` — now reddens **`EX2` by
name**.

| # | what I broke | camp (dev display) | rows that reddened |
|---|---|---|---|
| **s1** | sigma divides by n instead of n-1 -- the population form, which OVERSTATES yield | 5 FAILED (136 passed) | `ST2` `ST2b` `RD7` `EE3/apt` `EE3/fork` |
| **s10** | no spec at all reports a 100 % yield | 4 FAILED (137 passed) | `ST13` `RD8` `GT7b` `GT9` |
| **s11** | a scatter pair with one missing coordinate is kept, with 0 for the other | 1 FAILED (140 passed) | `ST18` |
| **s12** | `stat_column` finds the column by POSITION instead of by name | 4 FAILED (137 passed) | `ST15b` `GT6` `GT7` `GT10b` |
| **s13** | a row shorter than the header shortens the column instead of answering `-` | 1 FAILED (140 passed) | `ST17` |
| **s14** | the summary reports the CELL count as `n`, so `-` cells are counted as numbers | 4 FAILED (137 passed) | `ST6` `ST6b` `RD7` `GT7b` |
| **s15** | CSV export stops quoting a cell that carries a comma or a quote | ANCHOR-MISS — its anchor named the wrong file | re-run in the final pass, below |
| **s16** | a tab inside a cell is written into the TSV | 1 FAILED (140 passed) | `EX3` |
| **s17** | an unknown export format silently becomes CSV instead of being refused | 1 FAILED (140 passed) | `EX4` |
| **s18** | `campaign_index_exits` stops checking the header, so another campaign's exit codes are carried across | 1 FAILED (140 passed) | `RR4` |
| **s19** | `campaign_rerun` stops refusing before it runs | 1 FAILED (140 passed) | `RR8` |
| **s2** | a `-` cell is read as 0.0 instead of being dropped | 8 FAILED (133 passed) | `ST1` `ST6` `ST6b` `ST10` `ST14` `ST18` `ST19` `RD7` |
| **s20** | `campaign_rerun` rebuilds the index WITHOUT the other points' exit codes | 3 FAILED (138 passed) | `RR6` `EE7/apt` `EE7/fork` |
| **s21** | an out-of-range point silently becomes point 0 | 1 FAILED (140 passed) | `RR7` |
| **s22** | a statistic is printed with 17 significant digits | 1 FAILED (140 passed) | `ST19` |
| **s23** | `stat_suffixes` answers `{}` for every simulator | 7 FAILED (134 passed) | `ST18` `ST20` `ST21` `ST22` `GT6` `GT7` `GT10b` |
| **s3** | the simulator's SI suffixes are ignored, so `1k` stops being a number | 7 FAILED (134 passed) | `ST18` `ST20` `ST21` `ST22` `GT6` `GT7` `GT10b` |
| **s4** | a value `double()` refuses (nan) becomes 0.0 instead of being dropped | 1 FAILED (140 passed) | `ST7` |
| **s5** | the median of an even count takes the lower middle instead of averaging the pair | 1 FAILED (140 passed) | `ST4` |
| **s6** | the histogram's last bin is OPEN, so the maximum falls outside the picture | 6 FAILED (135 passed) | `ST8` `ST14` `GT6` `GT7c` `EE4/apt` `EE4/fork` |
| **s7** | a constant column answers NO bins instead of one bin holding everything | 1 FAILED (140 passed) | `ST9` |
| **s8** | the bin count loses both clamps | 1 FAILED (140 passed) | `ST11` |
| **s9** | the spec limits become EXCLUSIVE | 5 FAILED (136 passed) | `ST12` `ST12b` `RD8` `EE5/apt` `EE5/fork` |
| **w1** | `camp_form_state` always writes a sweep dict, never `{}` | 2 FAILED (139 passed) | `GC5` `GC6b` |
| **w10** | `camp_dist_keys` answers a hardcoded `{mean sigma}` for every distribution | 3 FAILED (138 passed) | `RD2` `GA7` `GA8` |
| **w11** | the axis editor's OK stops asking core | 2 FAILED (95 passed) | `GA9` `GX0` |
| **w12** | the List and Distribution halves are both live at once | 1 FAILED (140 passed) | `GA8b` |
| **w13** | the result table renders one column fewer than the index has | 3 FAILED (138 passed) | `GT2` `GT3` `GT3b` |
| **w14** | an EMPTY histogram bin is drawn as a one-pixel bar | 1 FAILED (140 passed) | `GT7c` |
| **w15** | the `Canvas` arm is removed from the theme walk | 1 FAILED (140 passed) | `GT5` |
| **w16** | Export always writes TSV whatever the extension says | 1 FAILED (140 passed) | `GT11b` |
| **w17** | Re-run with nothing selected silently re-runs point 0 | 1 FAILED (140 passed) | `GT12` |
| **w18** | Stop stops setting the flag the loop reads | 1 FAILED (140 passed) | `GR11b` |
| **w19** | the Values column shows the DRAWN SAMPLES instead of the distribution | 2 FAILED (139 passed) | `RD4` `GA11` |
| **w2** | a seed typed before the first axis is silently dropped | 1 FAILED (140 passed) | `GC6` |
| **w20** | `route_design` returns 1 unconditionally | 1 FAILED (103 passed) | `GX0` window: 11 FAILED (284 passed) W6m2 W6m3 W6m3 W6m5 R7 R7 R9 R9 R10 R14 R14 |
| **w21** | the result panel opens on the FIRST column instead of the last | 1 FAILED (140 passed) | `GT5b` |
| **w22** | the note line prints the run notes even when there is a refusal | 1 FAILED (140 passed) | `GR1b` |
| **w23** | a bench with no campaign gets an empty table instead of the sentence | 1 FAILED (140 passed) | `GX1` |
| **w24** | the scatter is drawn without the simulator's suffixes | ALL PASS (141 checks) | ⚠ **NONE — SURVIVED.** See *one mutation survived, and it was right to*: the default scatter was `myres` against `raw`, empty with the suffixes and without them. Re-run as **w24b** against the repair, where it reds `GT8` |
| **w25** | the axis editor opens an empty picker for a simulator that declares no kinds | 1 FAILED (140 passed) | `GX0` |
| **w3** | Run's enable stops asking the point count, so it is live on an empty form | 1 FAILED (140 passed) | `GC4` |
| **w4** | the progress readout names the point that just FINISHED | 1 FAILED (140 passed) | `GR9b` |
| **w5** | the step callback never answers `stop` | 1 FAILED (140 passed) | `GR10b` |
| **w6** | `camp_run` stops routing the design, as it did before the defect was found | 2 FAILED (102 passed) | `RD10` `GX0` |
| **w7** | the axis form uses only the FIRST of the adapter's declared fields | 2 FAILED (139 passed) | `GA3` `GA4` |
| **w8** | the kind picker shows the raw kind names instead of the adapter's labels | 1 FAILED (140 passed) | `GA2` |
| **w9** | the distribution's parameter fields are a hardcoded `{mean sigma}` | 2 FAILED (139 passed) | `GA7` `GA8` |
| **s15** | CSV export stops quoting a cell that carries a comma or a quote | 1 FAILED (150 passed) | `EX2` |
| **d1** | the `dc` registry gains a THIRD sweep-variable field | 1 FAILED (150 passed) | `DC1` core: 7 FAILED (631 passed) |
| **d2** | the `dc` emit template gains a third sweep slot | 1 FAILED (150 passed) | `DC2` core: 7 FAILED (631 passed) |
| **w26** | `camp_progress` stops being total for a window that is gone | 1 FAILED (150 passed) | `GX3` |
| **w27** | closing the dialog mid-campaign stops setting the stop flag | 1 FAILED (150 passed) | `GX3` |
| **w28** | `camp_run` answers `{}` again when it cannot find its window | 1 FAILED (121 passed) → **re-run 1 FAILED (150 passed)** | `GX0` → **`GR13b`** after the row was made total (see *a row of mine was not total*) |
| **w29** | `camp_run` answers `{}` again for a campaign with no points | 1 FAILED (150 passed) | `GR13` |
| **w30** | the spec limits are never drawn on the histogram | 1 FAILED (150 passed) | `GT10b` |
| **w31** | a spec limit outside the data is CLAMPED to the edge instead of not drawn | 1 FAILED (150 passed) | `GT10c` |
| **w32** | the scatter draws its axes but no marks | 1 FAILED (150 passed) | `GT8` |
| **w24b** | the scatter is drawn without the simulator's suffixes (w24, now that the default columns are not empty) | 1 FAILED (150 passed) | `GT8` |
| **w33** | the panel opens on the last column of the index rather than the last DATA column | 2 FAILED (149 passed) | `GT5d` `GT5e` |
| **w34** | the scatter may open on a column against itself | 1 FAILED (150 passed) | `GT5e` |
| **w35** | a numeric BOOKKEEPING column counts as a data column | 3 FAILED (148 passed) | `GT5c` `GT5d` `GT5e` |
| **g1** | a deliberate raise inside `ase::stat_columns`, intended to prove a guarded section NAMES its raise | 3 FAILED (120 passed) | `ST16` `ST16b` `GX0` — ⚠ **NOT `ST0`, and the mutation is the thing that was wrong**: `q_ans` already wraps every call, so a raise *inside* a proc never reaches the section guard. It proved `q_ans`, not the guard. **The guard's real proof is `s15` itself** — `NORESULT` before the guards, **`EX2`** after, same mutation, same binary |

## ⚖ R9 — every new user-facing sentence, verbatim

`owed.sh add rule 1464`. **The user's to ratify**; nothing is blocked on it.

### The dialog

```
Campaign…                                  (the Simulation menu entry)
Campaign                                   (the window title)
Run this bench as a campaign
Seed
leave it empty and anything the simulator draws for itself differs every run
Axes
Kind        Column        Values        Points          (the axis table's headings)
Add…        Edit…         Delete
Run Campaign
Stop
Results…
No axes yet. Without one this bench runs once, as it does today.
not running
```

⚠ **The seed caution is split in two on purpose.** What a seed does NOT reproduce
is the **adapter's** sentence (`campaign_seed_notes`, minted under 1462) and is
shown verbatim; what an **absent** seed costs is ASE-L's own and is the sentence
above, because "there is no seed" is a fact about the campaign rather than about
the simulator.

### The progress readout — the `k/N` line, composed

```
point 3 of 12 — running   (myres=2k, temp=125)
point 1 of 1 — running                              (no coordinates: one axis, one value)
12 of 12 done — 11 ran, 1 failed
stopped after 4 of 12 — every completed point is kept
```

⚠ **"every completed point is kept" is a PROMISE**, and it is the one §11a ranks
the shard runner above a `.control` loop for. It is true by construction: each
point is its own process writing into its own directory, and `index.tsv` is
rewritten after **every** shard rather than once at the end.

### The axis editor

```
Campaign Axis                              (the window title)
Kind
Column name
(from the fields above)
Points
List
Distribution
Samples
```

⚠ **The five axis-kind labels and their field labels are the ADAPTER's**
(`Design variable` / `Temperature` / `Corner` / `Instance parameter` / `Model
parameter`, with `Variable`, `Model row`, `Instance`, `Parameter`, `Model`) and
were minted by issue **1462**; they ride that debt, not this one. The form reads
them from the hook.

⚠ **`normal` / `uniform` / `bounded` are CORE's three neutral distribution
names** and the form does **not** translate them. They are deliberately not
ngspice's five netlist spellings (`agauss`, `gauss`, `aunif`, `unif`, `limit`),
which all five map onto them — D34 keeps a simulator's word out of core.
**Whether the form should offer the simulator's own five as a convenience is a
decision the user has not made**, so it offers three. That is the one place in
this task where I could have been more helpful and chose not to be without a
ruling.

### The result table

```
Campaign Results                           (the window title)
No campaign has run in this bench's run directory yet.
Column      Distribution      Scatter      X      Y      Spec
Export…     Re-run Point      Close
This column holds no numbers.
n = 28 of 30      mean 1.234      sigma 0.056      min 1.1      max 1.4      median 1.23
Yield: give a spec limit
Yield: 26 of 28 (92.9 %)
ase: exported 30 rows to /path/to/campaign.tsv
ase: select a point in the table first
```

### The two refusals the dialog says for itself

```
ase: no campaign is running
ase: this campaign has no points to run
```

Every other sentence this dialog shows is **core's** — the campaign refusals and
the run notes come from `ase::campaign_refusals` / `ase::campaign_notes`
verbatim, and were minted under issue 1462.

---

## Corrections to this brief and to `PLAN.md`

| | |
|---|---|
| **C1** | ⚠ **`ase::state_serialize` is NOT the byte-identity mechanism, and my first measurement of it reported 104 MISMATCHES.** The committed files are `ase::state_save`-canonical — `state_save` is what adds the file's exact framing — so a harness that compares `state_serialize`'s output against the file on disk disagrees with **every** file and looks exactly like a catastrophic regression. `test_ase_final_gf180`'s row **G3** has the correct shape (`state_save` into a scratch path, then a binary compare) and I re-did it that way: **104 of 104 identical**. Recording it because the wrong harness is the obvious one to write and its output is maximally alarming |
| **C2** | ⚠ **PLAN.md §11c's statistics cannot be a pure surface, and the reason is the SI suffix.** §11c reads as arithmetic over `index.tsv`; what it actually needs is a *simulator-aware* number reader, because an axis column holds `1k`, not `1000`. That makes `ase::stat_suffixes` an adapter resolve in the middle of what the plan calls pure Tcl statistics. It is still core (the suffixes are an argument, there is no fallback set), but a crew that read §11c and wrote `expr` over `lsort` would ship a histogram with no bars |
| **C3** | ⚠ **The brief's *"`src/ase_window.tcl` is yours; `src/ase.tcl` only if a reader genuinely has to grow"* under-describes this task.** Fourteen procs had to land in core, and the deciding argument is not "a reader had to grow" — it is that **a number computed in `ase::ui::` can only be tested on a display arm**. Statistics that decide a yield number belong where both arms can falsify them; PLAN.md §11's *Files and procs* already said so, and this is the sharper reason |
| **C4** | ⚠ **A second run door cannot be written while the design routing is inline in `ase::ui::do_run`.** Measured, not reasoned: `Run Campaign` died on `ase: design <lib>/<cell> is not open in this window` from a window where `Netlist and Run` works. `PLAN.md` §11 does not mention the routing at all, and a crew that added a Run button without it ships issue 0643's defect on a new control. Extracted as `ase::ui::route_design`; row RD10 is structural |
| **C5** | ⚠ **`_theme_widget` had no `Canvas` arm**, because nothing in ASE-L had ever drawn one. §11's *"a histogram is a new drawing in this tree"* is more literally true than it reads: the widget CLASS is new too, and the theme walk silently skipped it. Any later plot in this program inherits the arm; any later widget class will not |
| **C6** | **`test_ase_window`'s `W1m` pins the Simulation menu exactly**, so every new entry on that menu moves it. Not a defect — it is the row working — but it is not in any stage's *Suites that move* list and the next crew that adds a menu entry will meet it as a surprise red |
| **C7** | ⚠ **A three-point campaign invokes the simulator TEN times**, because `ase::run_deck` asks `ase::cap_report` on every run and the probe runs the binary too. Issue 1463 measures the cost against a binary that cannot answer; this is the *count* against one that can, and it is what a stand-in's invocation tally has to filter for or it measures the probe |
| **C7c** | **PLAN.md §11's sizing is low on both files.** It budgets `src/ase_window.tcl` **≈ +450** and `src/ase.tcl` **≈ +700** for the whole stage. Measured: this task alone is **+1415** in `ase_window.tcl` (the dialog, the axis editor, the result table, the two drawings, the copy, and the comment blocks that carry the measurements) and **+367** in `ase.tcl` for §11c's arithmetic — on top of task 1's **+1191**. The suite is **1310** lines. Not a defect in the plan, but a crew costing the stage off those numbers will be out by 2× |
| **C7d** | ⚠ **`index.tsv`'s LAST column is not the bench's answer when the bench has no measurement — it is `raw`, a column of FILE PATHS.** PLAN.md §11c describes the table as offering statistics over the index's columns and says nothing about which one a person should be looking at first; taking the last is the obvious reading, and it opens the panel on "This column holds no numbers." with a perfectly good swept axis one place to its left. Found by a **surviving** sabotage (w24), because the same choice made the default scatter EMPTY and therefore unable to discriminate. The panel now prefers the bench's own axis and measurement columns, derived from the state rather than from the three bookkeeping names |
| **C7e** | ⚠ **A pure-Tcl section with no `catch` wrapper turns any raise into a NORESULT**, and every suite in this batch has such sections. Mine had five; `--nogui --pipe` exits **0** on an uncaught mid-script error, so the suite stops printing and `run_suites.sh` reads the missing verdict as TIMEOUT. Found by sabotage **s15**, whose row set came back empty while `test_ase_core` and `test_ase_window` both passed under the same mutation. The widget block and `EE` already carried the guard; the fix is to give every section one, so a raise is a NAMED red (`ST0`/`EX0`/`RD0`/`DC0`/`RR0`) rather than silence |
| **C8** | **`"$kind(...)"` is an array reference in Tcl**, and it raised `variable isn't array` inside the axis table's own reader. Braced as `${kind}(...)`. Trivial, and worth one line because the reader was written in the house style of composing a display string and the failure was a *raise*, not a wrong string |

---

## ⚠ AND A ROW OF MINE WAS NOT TOTAL, WHICH THE CAMPAIGN CAUGHT TOO

Sabotage **w28** puts `camp_run`'s `{}` return back — the defect `GR13b` exists
to name — and it reddened **`GX0`**, not `GR13b`. The reason is that `GR13b`
wrote `[dict get [q_ans ase::ui::camp_run nosuchkey] status]`: the `q_ans`
wrapper made the *call* total and the `dict get` **outside** it did not, so the
very failure the row was written for raised, and the raise was absorbed by the
widget block's guard and reported as a section that did not finish. **The row
that should have named the defect named nothing.**

Repaired — the `dict get` is now inside a total reader that answers
`NOSTATUS:<what came back>` — and re-run: `w28` reds `GR13b`. It is the third
time in this task that "every extractor is total" had to be applied to my own
extractors rather than to the code under test.

## ⚠ THE NORESULT WAS MINE, AND SO WAS THE GATE THAT LET IT THROUGH

The `NORESULT` above was chased to the end rather than filed as a curiosity, and
what it found was **three** defects, none of them in the shipped code:

1. **A patch script that stopped one line early.** The script rewriting `ST1b`
   scanned forward to *the first line containing* `{skipped}` — which was the
   `[expr {… ? {read-as-zero} : {skipped}}]` line, not the block's final bare
   `{skipped}`. The orphan was left behind as a command:
   `invalid command name "skipped"`, **line 151**, and the suite died two rows
   in. A search anchored on a token that appears twice is a search that lands on
   the wrong one.
2. ⚠ **MY OWN GREEN GATE COULD NOT SEE AN EMPTY RESULT.** The pass runner
   verified both arms before snapshotting, with
   `case "$h$d" in *FAIL*|*NORESULT*) abort ;; esac` — and when a suite prints
   **no verdict at all**, `$h` and `$d` are *empty*, which matches neither
   pattern. The `${h:-NORESULT}` substitution existed only in the `echo`. So the
   gate whose entire purpose is to catch a silent suite waved one through, and
   every mutation after it reported `NORESULT` against a baseline that was
   already broken. **Five results were discarded and the pass re-run.** Fixed by
   defaulting the variables, not the message.
3. **Two rows written against an assumed shape.** `ase::ui::chana_fields`
   answers the field **names**, not descriptors — `DC3` walked them as dicts and
   compared eight empty strings. And `GR13`'s refusal probe left its own axis in
   the *session state*, because `camp_run` commits the form **before** it
   evaluates the refusals (deliberately: the campaign that runs is the one on
   screen). Two later rows then read a column named `temp`. Both measured, both
   repaired, both now restoring what they borrow.

**The lesson worth keeping is (2).** Every guard in this receipt is about a
defect hiding in the absence of a signal, and the guard I wrote to enforce that
had the same hole in it. It is the reason the suite's sections are now guarded
too: *"a NORESULT is not a result"* has to be true of the harness as well as of
the suite.

## ⚠ AND ONE MUTATION PRODUCED A **NORESULT**, WHICH IS NOT A RESULT

**`s15` — CSV export stops quoting — came back `NORESULT`:** no `RESULT:` line at
all, while `test_ase_core` (638) and `test_ase_window` (295) were both ALL PASS
under the same mutation, so `ase.tcl` had sourced perfectly well and the failure
was inside my own suite.

The cause is structural and it is the brief's own warning met in my own file:
**sections `ST`, `EX`, `RD`, `DC` and `RR` had no `catch` wrapper.** The widget
block and section `EE` have one — `} gerr]} { check {GX0 the widget sections ran
to the end} ... }` — and the pure-Tcl sections did not, so a raise anywhere in
them killed the suite at **rc 0**, which is what `--nogui --pipe` does with an
uncaught mid-script error. `run_suites.sh` reads a missing verdict as TIMEOUT
and a person reads it as nothing.

**Every section is now guarded the same way**, so a raise becomes a named red —
`ST0` / `EX0` / `RD0` / `DC0` / `RR0`, each carrying the raise text — instead of
a suite that simply stops talking. That is the same repair task 1 made to its
row `RN5` for the same reason, generalised from one row to every section.

## ⚠ ONE MUTATION SURVIVED, AND IT WAS RIGHT TO

**`w24` — the scatter drawn without the simulator's SI suffixes — passed 141 of
141.** The brief predicts this ("your first list will be short; it has been for
nine crews"), and what it exposed is a defect in the *product*, not only a hole
in the suite.

**What it found.** `ase::ui::campres_default_col` took the LAST column of
`index.tsv`, on the reasoning that the last column is the last MEASUREMENT
whenever the bench has one. It is — and when the bench has **none**, the last
column is **`raw`, a column of file paths**. So the result table opened its
histogram on *"This column holds no numbers."* with a perfectly good swept axis
one place to its left, and the scatter defaulted to that axis against `raw`.
That pair has **zero points with the suffixes and zero without them**, so no row
over the default columns could tell the mutation apart from the real code.

**An empty default is a default that hides every defect behind it**, and that is
the general lesson: a mutation surviving is as often a statement about the
fixture's *starting position* as about a missing assertion.

**What shipped because of it.** The panel now prefers the bench's **own data
columns** — its axis labels and its enabled measurement names — over the index's
bookkeeping, and within those the columns that hold numbers
(`campres_data_cols` / `campres_numeric_cols` / `campres_pref_cols` /
`campres_default_xy`). ⚠ **The three bookkeeping names are not spelled in
`ase_window.tcl`**: the data columns are derived from the state through the same
readers `ase::campaign_index_header` builds the header from, so a fourth
bookkeeping column needs no edit here. And `exit` is the row that makes the
distinction real — it is perfectly numeric and still must not be a default,
because opening a yield panel on a column of exit codes answers no question the
user asked (**GT5c**).

Rows **GT5b / GT5c / GT5d / GT5e**; mutations **w33 / w34 / w35** for the repair
itself, and **w24b** is `w24` re-run against it — the same defect, now killable.

## ⚠ THE THIRD `.dc` LEVEL: A REFUSAL THAT IS STRUCTURAL RATHER THAN SPOKEN

`PLAN.md` §11 opens with it — a third `.dc` sweep level is **accepted and
discarded**, three nested sweeps giving the same **9** rows as two, rc 0 and
nothing on stderr, on both binaries — and concludes that **ASE-L must REFUSE a
third level at the form**. Issue 1462's receipt (C7) handed that to this task,
because the only place a third level can be ASKED for is the `dc` analysis form.

**Measured: there is nothing to refuse, and that is better than a refusal.** The
registry declares exactly two sweep levels (`source`/`source2` and their
start/stop/step) and the emit template spends exactly those eight slots, so a
form built from the registry **cannot express a third**. Rows **DC1** (the
fields), **DC2** (the template, asked the other way — a template carrying a slot
no field shows would reach the deck unseen) and **DC3** (the Choose Analyses form
really builds from that list).

⚠ **And the sabotage confirms it from both sides at once.** Mutation **d1** adds
a `source3` field to the registry: it reds **`DC1`** here **and 7 rows of
`test_ase_core`**, which is the suite that owns the registry. Two independent
suites, one defect, neither told about the other — which is what a shared
registry is supposed to buy.

## ⚠ THE CAMPAIGN'S MOST IMPORTANT ROW IS IN SOMEBODY ELSE'S SUITE

Mutation **w20** makes the extracted `ase::ui::route_design` answer 1
unconditionally, and the result is:

```
w20 | camp: 1 FAILED (103 passed) rows: GX0
    | window: 11 FAILED (284 passed)  W6m2 W6m3 W6m3 W6m5 R7 R7 R9 R9 R10 R14 R14
```

**Eleven rows of `test_ase_window`** — `W6m2`/`W6m3`/`W6m5` (issue 0616's
withdraw-and-deiconify routing) and `R7`/`R9`/`R10`/`R14` (issue 0643's
reachability refusal and its remedy sentence). Two things follow, and both are
worth more than a green count:

1. **The extraction preserved the behaviour those rows pin.** They are green with
   the real proc and red the instant its decision is removed, so moving the block
   out of `ase::ui::do_run` changed where the code lives and nothing else.
2. **My own suite is NOT where that behaviour is measured, and should not be.**
   `RD10` is structural — it asserts both doors call the router and neither
   re-inlines the predicate — and it does not red here, because the mutation is
   *inside* the router rather than at a call site. The behavioural coverage lives
   in the suite whose subject is that door. That is the healthy shape of
   "two halves of a feature tested in different suites": the halves meet in
   `test_ase_window`, which is why it is the second collateral column of this
   campaign rather than an afterthought.

⚠ **And it is why running that suite on the DEV DISPLAY for every mutation was
worth the wall-clock.** `test_ase_window` headless is 56 checks; the eleven rows
above are display-only. A campaign that carried only the headless collateral
column would have reported `w20` as killing one row in one suite.

## ⚠ THREE THINGS THE TABLE SAYS THAT A PASS/FAIL COUNT WOULD NOT

* **`ST15` alone is a weak row, and the campaign says so.** Mutation **s12**
  makes `stat_column` find its column by a fixed POSITION rather than by name —
  and position 4 happens to be `pm` in ST15's own fixture, so **ST15 stayed
  green**. `ST15b` (an unknown column name) and the three display rows over a
  REAL `index.tsv` (`GT6`, `GT7`, `GT10b`) are what killed it. A fixture whose
  layout happens to agree with the defect is failure mode 1 in miniature, and
  the row is kept with its control rather than rewritten to hide it.
* **`s3` and `s23` kill an identical row set**, because they are the same defect
  reached two ways — ignoring the suffixes argument, and answering no suffixes
  for every simulator. That is the adapter seam being the only route, which is
  what D34 asks for.
* **`ST1b` did not fire on `s2`**, the very mutation it was written for. See the
  corrections: it was calibrated against one wrong implementation. `ST1` caught
  the defect; the control has been rewritten to compare against the removal and
  against both read-as-zero answers.

## ⚠ TWO MUTATIONS REDDEN `GX0` AS WELL AS THEIR OWN ROW, AND THAT IS THE CATCH WORKING

A few mutations below show `GX0` beside their named row and a much lower passed
count — for example **w11** (the axis editor's OK stops asking core) reds `GA9`
**and** `GX0`, at 95 passed instead of 140. That is not a second defect: `GA9`
asserts the editor STAYS UP when core refuses, and with the mutation in it
closes, so the lines after it address widgets that no longer exist and the
widget block's own `catch` converts the raise into `GX0`. **The named row fires
first and names the defect**; `GX0` is the block reporting that it did not reach
its end, which is exactly what that row exists for — a suite that died silently
after `GA9` would have printed a plausible `RESULT:` line for a smaller suite.

## What I did NOT ship, and why

* **No quiet mode for the per-shard chatter.** Task 1's own debt names this as
  task 2's, and I considered it and declined. `ase::run_deck` and
  `ase::run_done` say four to eight sentences per run; for a 200-point campaign
  that is a thousand lines in the CIW. **Nothing is wrong with any of them** —
  they are true, per run — and quieting them means either a flag threading
  through the run body or a hook on `ase::echo`, both of which change behaviour
  for every run in the program to serve one caller. What I shipped instead is a
  **spine the user actually follows**: the `k/N` readout, in the dialog, naming
  the point that is running and its coordinates. **Whether a campaign may quiet
  the run body is the user's ruling**, and it is recorded under `add rule 1464`
  rather than taken.
* **No offer of ngspice's own five distribution names.** See ⚖ R9 above: D34
  says the simulator's spelling stays out of core, and whether the *form* may
  offer them as a convenience is a decision, not an implementation detail.
* **`Re-run Point` does NOT re-render the nominal deck.** `ase::campaign_rerun`
  runs the one shard and rewrites `index.tsv`; it does not call
  `ase::campaign_prepare`, so a re-run against a `campaign/` directory that has
  never held a full run leaves no `campaign/deck.spice`. That is deliberate:
  re-rendering the nominal deck on every single-point re-run is wasted work on
  the normal path, and it would let a bench whose *nominal* deck no longer
  renders fail a re-run of a point that renders perfectly. Recorded because a
  reviewer will ask.
* **No parallelism.** One shard at a time, exactly as task 1 built it.
* **No change to `ase::campaign_run`, `campaign_step` or `campaign_wait`.** The
  progress readout and the Stop both ride the `onstep` seam task 1 already
  provides; adding a second callback would have been a change to committed code
  for a surface concern.
* **`tests/run_regression.tcl` not run** — the driver's, solo (issue 0990).

---

## Ledger

Backed up before the write: `/tmp/stage11b/owed_backup_011722` (`cp -a` of
`~/.claude/xschem_owed`).

| | rule | look | suite |
|---|---|---|---|
| **before** | 176 | 66 | 10 |
| **after** | **177** | **67** | **11** |

* **`add rule 1464`** — printed `recorded`. The dialog's copy, the progress and
  Stop sentences, the axis editor's labels, the result table's statistics /
  yield / export strings, and the two decisions I declined to take without a
  ruling (the per-shard chatter, and whether the form may offer ngspice's own
  five distribution names).
* **`add look ase-campaign-histogram-and-progress-1464`** — **REQUIRED, and
  filed.** PLAN.md §11's own *Re-measure on the dev display* paragraph asks for
  **the histogram, with mean/sigma/yield beside it**, and **the `k/N` progress
  readout**. A histogram is a new drawing in this tree and nothing else in ASE-L
  draws one. **Suites green on both arms — please look.** Nothing here is
  reported as done on a green suite.
* **`add suite test_ase_campaign_gui_1464`** — 141 checks on the dev display and
  a GUI feature's suite owes one `:0` run. ⚠ Note for whoever drains it:
  `AUDIT_DISPLAY=:0` is **Xwayland**, not the user's screen; the `look` above is
  the one that needs the real VcXsrv display.

One rule, one look and one suite added; **none destroyed**. No `clear` of any
kind was issued.

---

## Debts this task leaves

1. ⚖ **The sentences above** — `owed.sh add rule 1464`. **Blocking nothing.**
2. 👁 **The histogram and the `k/N` readout** — `owed.sh add look`. Pixels
   unseen.
3. 🔭 **M5 stays open.** See below.
4. ⚠ **The per-shard chatter is still a thousand lines for a 200-point
   campaign.** Named above, filed as a ruling, not taken.
5. ⚠ **Issue 1463 is still live.** The readout makes it *visible* rather than
   silent; it does not make it cheap. Thirty seconds times N points is still
   thirty seconds times N points.

### 🔭 M5 — the multi-raw family: what the TABLE does, and what stays open

**The brief is explicit that this is a conversation, not an experiment, so
nothing was invented.** Task 1 sharpened M5 into five questions a viewer
contract would have to answer; I did not answer any of them, and I did not add
a viewer attachment, a family object or a legend rule.

**What this task's surface does instead, stated plainly:** the campaign result
table is a **view over `index.tsv`**, which is a *table*, not a waveform. Every
number in it — mean, sigma, min/max, median, the histogram's bins, the yield,
the scatter's points — is computed from that table's cells in Tcl. It never
opens a rawfile, never attaches one to the waveform window and never asks the
Calculator anything. **The `raw` column is a path the user can see**, and
`Re-run Point` re-runs the shard behind a selected row; that is the whole of the
connection between the table and the N rawfiles.

That is deliberate, and it is worth recording as an *input* to M5 rather than as
an answer to it: **task 1's question 4 — "where do the statistics live?" — now
has a measured answer**, and the answer is *the campaign result table, over the
index, not the viewer over the rawfiles*. If that holds when the contract is
discussed, it leaves the viewer needing only questions **1** (who owns the
family) and **2** (what a curve's label is). Questions 3 and 5 are untouched.

**M5 stays OPEN.**

---

## Hygiene, stated rather than assumed

* **One sabotage runner at a time**, confirmed with `ps -e -o pid=,args=` before
  launch; restore is `cp` from a pristine snapshot with an **md5 compare printed
  every time**.
* ⚠ **No `pkill`, and no `pkill -f` anywhere.** Task 1 reached for
  `pkill -f 'sleep 37'` and `-f` matched its own shell. Nothing in this task
  kills anything except through `kill_running_cmds <id>`, the numeric branch the
  Stop button already uses, on an id this program started.
* **Every run had a `timeout`**, and every waiting loop a deadline.
* **No `git checkout` / `restore` / `stash` / `clean` / `add` / `commit` /
  `push`.**
* **Nothing under `~/.xschem/` opened for writing**; no `$HOME/.spiceinit`; no
  simulation on any bench under `sky130A/` or `ihp-sg13g2/`.
* **Snapshots archived at hand-over** — see the last section.

## Snapshots, disarmed at hand-over

`CREW_BRIEF.md`'s *DISARM YOUR SABOTAGE SNAPSHOTS* section: a stale pristine copy
plus a stale background waiter is how a finished crew overwrites a live tree with
hours-old content. **Every restorable artifact this task produced is moved out of
reach of its own restore scripts** — 34 files under
`/tmp/stage11b/ARCHIVED_DO_NOT_RESTORE/`: the four pristine snapshots
(`pristine_`, `pristine2_`, `pristine4_`, and the pre-change `pre_`), all four
mutation tables, all four sabotage runners, both pass runners, the assembly
script and every patch script. A second directory,
`/tmp/stage11b/DRYRUN_DO_NOT_RESTORE/`, holds the sandbox copies every patch was
dry-run against before it touched the tree, and is named the same way for the
same reason.

**The campaign logs are KEPT** and are the evidence this receipt points at:
`sab_results.txt` (pass 1, 48 mutations), `sab_results2.txt` (the **discarded**
pass, kept because the `NORESULT`s in it are the measurement behind three of the
corrections), `sab_results4.txt` (the final pass, 15), `sab_table.md`,
`chain23.log` and `chain_final.log` (the runners' own output, including the
assembly), the four `pristine*_md5.txt` files, and `owed_backup_011722` (the
ledger, copied before the first `add`).

⚠ **If this crew is ever woken after collection**: check `git status` and
`git log` before touching anything. The tree will have moved on, another crew is
probably live in it, and the single most damaging thing a finished crew can do is
tidy up.

---

# ADDENDUM — what T1 caught: a green suite that did not exit cleanly

**Reported by the coordinator after this task was handed back**, against a tree
holding my work uncommitted:

```
HARNESS: headless/test_ase_campaign_gui_1464 (display arm) did not complete cleanly
         (exit=10, OVERALL_ok=1, died=0)
RESULT: ALL PASS (151 checks)
OVERALL: ok
```

Every check passed, the banner printed, `banner_complete` was satisfied and
`banner_died` was false — and `regression_case_failed` counted it anyway, because
its first arm is `childcode != 0`. **That is the harness doing its job**, and it
is the same rule this whole receipt is written around: a signal that is *absent*
is still a signal.

## ⚠ I FOUND THE CAUSE BEFORE I MADE IT ZERO, WHICH WAS THE POINT

The one-line `exit [expr {$fail ? 1 : 0}]` would have turned the arm green
immediately. The coordinator's instruction was to find out **what** made it 10
first, because if the cause were a toplevel left mapped or a pending `after`,
that line would paper over a leak. So the `exit` was written last.

**Bisected to one line, by truncating the suite at section boundaries and then
inside a section.** `after_RR` rc 0 → `after_GUI` rc 10 → inside the widget
block, `before_GR` rc 0 → `before_GT` rc 10 → line **896**, which is
`set GR_RES [q_ans ase::ui::camp_run $gkey]`. Then, with two scripts identical
but for a single line:

```
ase::ui::route_design $gkey                    ->  rc 0
ase::ui::route_design $gkey ; xschem netlist   ->  rc 10
```

**A netlist flips the `-q` fall-through to 10 on the display arm.** Headless
stays 0 — the same suite, same binary, measured. And it is the **attempt**, not
the success: in the second script `xschem netlist` raised (`catch` returned 1)
and the exit code moved anyway.

## Everything else was excluded by MEASUREMENT, not by argument

| candidate | measured |
|---|---|
| a leaked channel (issue 1461's class) | `file channels` → `stdin stdout stderr` only |
| a pending `after` | one: `after#0` → `::__wd_fire`, the watchdog **every** suite sourcing `scratch.tcl` arms (issue 1403) |
| a mapped toplevel | closing both sessions removed `.ase4`/`.ase5` and **rc stayed 10** |
| a live `vwait` / semaphore leak | `xschem get semaphore` → **0** |
| a run still in flight | no `::execute(pipe,*)` entries |
| a loaded rawfile | `xschem raw loaded` → -1, `raw points` → *No raw file loaded* |
| `execute` itself | `execute 0 /bin/true` rc 0; `execute` of the **exact stand-in** rc 0; route+execute rc 0 |
| `ase::run_deck` | **not required** — removing the `run_deck` call left rc 10 |
| `ase::run_done` | stubbed to a no-op → still rc 10 |
| `cap_report`, `sim_casemode_selectable`, `sim_apply_choice`, `preflight_gate` | each stubbed in turn → still rc 10 |

**There is no leak in this suite.** That is a measured statement, not a
reassurance, and it is what makes the explicit `exit` the correct fix rather than
a cover.

## Why THIS suite and not `test_ase_conv_gui_1460`

**Because this is the first GUI suite that netlists.** It is the first to drive a
real run door from a dialog: `camp_run` → `route_design` → `ase::netlist`.
`test_ase_conv_gui_1460` never calls `ase::run`, `ase::run_deck` or
`ase::ui::do_run` — its only match on those names is a comment — and its `EE`
section runs the simulator with a plain `exec`, which never enters xschem's
netlister.

⚠ **Answering the coordinator's question 4 directly: `test_ase_conv_gui_1460` is
LATENT, and one line would make it deterministic.** Re-measured just now on the
dev display: **rc 0, ALL PASS (104 checks)**. It exits 0 *only because it never
netlists*, not by construction. The day it grows a row that runs a deck — Stage
10's own convergence remedies are one `Apply`-and-run away from that — it becomes
rc 10 with every check still green. **I have not touched it**; it is not my file,
and the fix is one line at its end matching the four established `dcases` suites.

## What changed here

1. **Section `HY`** — four rows that assert the state a real leak *would* have
   left, because once a suite exits explicitly its exit code stops carrying any
   information about what it left behind:
   * **HY1** no channel beyond the three standard ones (issue 1461's class — this
     suite reads five files of its own);
   * **HY2** the only pending timer is the shared watchdog;
   * **HY3** closing the sessions closes their windows — no `.ase*` toplevel left;
   * **HY4** no run of this suite still in flight.
   All four **sabotage-verified by name**: a `::open` left dangling reds HY1
   (`{file6}`), a stray `after 999999` reds HY2 (`{after#22 list}`), skipping a
   session close reds HY3 (`{.ase5}`), and a planted `::execute(pipe,99999)` reds
   HY4. The suite also now **closes the sessions it opened**, which it did not
   before.
2. **An explicit `exit [expr {$fail ? 1 : 0}]`**, with the measurement written
   beside it — the house convention that the four established `dcases` suites
   (`test_op_annot`, `test_annot_stale_0684`, `test_ase_simdlg_0937`,
   `test_ase_optsheet_1441`) all already follow.

## Verification after the repair

| arm | exit code | verdict |
|---|---|---|
| headless | **0** | ALL PASS (**78** checks) |
| dev display | **0** | ALL PASS (**156** checks) |
| `test_ase_conv_gui_1460`, dev display | **0** | ALL PASS (104 checks) — unchanged, and latent as described |

Floors moved **74 → 78** headless and **151 → 156** display (the four `HY` rows;
HY3 is display-only). Every stated count in the suite header,
`tests/run_regression.tcl`, the issue file, `NUMBERING.md` and this receipt has
been reconciled.

`tests/run_regression.tcl` **not run** — T1 is the driver's and runs solo (issue
0990). **Snapshots not re-armed**: the bisection ran from copies under
`/tmp/stage11b/` that were never restore sources, and the suite was restored from
`/tmp/stage11b/hy_pristine.tcl` by `cp` with an md5 compare after each sabotage.

## ⚠ The correction this adds to the batch

**C13 — a `dcases` suite must end with an explicit `exit`, and the reason is not
tidiness.** `CLAUDE.md` calls rc 10 the *"benign fall-through"* (issue 0016
Part 4), and benign is exactly what it is not once a case is in `dcases`, where
`regression_case_failed` reads the child code first. The trigger is narrower than
"no `exit`": **a netlist on the display arm**. Any suite that drives a run door
meets it; any suite that does not, will not — until it does, silently, with every
check green.

---

# ADDENDUM 2 — T1 caught my own leak-detector, and it was wrong twice

The exit-code repair stood; **`HY1` did not.** T1 reported it red on the display
arm with `{file6}` while my own runs were green — and the variable was the
invocation:

| how it was run | HY1 |
|---|---|
| mine, dev display, `--nolog` | green |
| T1's display arm, `--logdir $dlogdir` | **red**, `{file6}` |

## ⚠ WHAT THE CHANNEL ACTUALLY IS — measured, not inferred

The coordinator's hypothesis was that `--logdir` means an open log channel.
**It does not, and that was worth measuring rather than assuming.** A session run
under `--logdir` with a trivial script writes `Xschem.log` and `file channels`
still holds **exactly the three standard channels**: the action log is a
C-level `FILE*` (`src/util.c`), never a Tcl channel.

So I identified the channel positively instead. A Tcl `fileN` channel is named
for its descriptor, so `/proc/self/fd/N` names it. Reproducing T1's exact
invocation — `devdisplay.sh exec timeout --kill-after=20 900 … --pipe -q
--logdir <dir> --script …`, run from `tests/`:

```
DIAG extra chan=file6 path=pipe:[19098259]
```

**It is a PIPE.** Specifically, an `execute` pipe in **asynchronous close**.
`execute_fileevent` (`src/xschem.tcl`) reaches EOF, finds the child not yet a
zombie, and closes the pipe **without setting it blocking** — a deliberate choice
carrying its own comment, so that a simulator which closes stdout early cannot
freeze the program. Tcl keeps an asynchronously-closing channel in
`file channels` until the child is reaped, while `execute(pipe,$id)` has already
been unset. **That is precisely why `HY2` and `HY4` stayed green while `HY1` went
red** — there was no pending timer and no registered pipe, only a channel waiting
on a reap.

Checkpointing `file channels` through the whole suite put it in section **EE**,
the only section that starts real ngspice binaries.

## ⚠ AND THE ROW WAS FLAKY, WHICH IS WORSE THAN BEING WRONG

Because it is a race against a child being reaped, the same suite **passed the
check on one run and failed it on the next**, with only section EE between them.
This batch's own rule is that a flaky row is worse than no row, and `HY1` was one.

## What the corrected row asserts

**No channel that is a REGULAR FILE, beyond the three standard ones.** Each extra
channel is classified **by identity** (`/proc/self/fd`), not by count and not by
name: a `pipe:` or `socket:` belongs to `execute`'s own lifecycle and is covered
by `HY4` for as long as it is still a registered run; anything else — including a
path that cannot be resolved — is counted, because it can only be this suite's
own `::open`. A channel number is an allocation order, not a fact, so nothing is
allow-listed.

**And the positive control is inside the row, not in a comment.** `HY1a` opens a
file, demands the detector **sees** it, closes it, demands the detector stops
seeing it, and checks the resolved path equals the file opened. A detector that
saw nothing would otherwise pass this section for ever — which is the exact shape
issue 1461 hid in, and the shape both of my earlier self-inflicted defects took.

## Verification — the arm T1 runs, repeated

| invocation | runs | result |
|---|---|---|
| dev display, **`--logdir`** (T1's exact command) | 3 | rc **0**, ALL PASS (156) every time |
| dev display, `--nolog` | 2 | rc **0**, ALL PASS (156) every time |
| headless, `--nolog` | 1 | rc **0**, ALL PASS (78) |

**All five hygiene rows sabotage-verified UNDER `--logdir`**, which is the arm I
had not been testing on:

| mutation | row that reddened |
|---|---|
| a real file channel left open | **HY1** → `{file7 /etc/hostname}` |
| the detector blinded (`hy_leaked_files` returns `{}`) | **HY1a** |
| a stray `after 999999` | **HY2** → `{after#22 list}` |
| a session close skipped | **HY3** → `{.ase5}` |
| a planted `::execute(pipe,99999)` | **HY4** → `{pipe,99999}` |

Restore by `cp` with an md5 compare after every mutation; the suite's md5 matches
its pristine copy.

## `test_ase_conv_gui_1460` under `--logdir`

Measured twice, T1's exact invocation: **rc 0, ALL PASS (104 checks)** both times.
So it is green under both invocations — and still **latent for the exit code**,
for the reason in the first addendum: it never netlists. `--logdir` does not
change that; it was never the variable.

## Counts

Floors **74 → 78** headless and **151 → 156** display (`HY1a` is new; `HY3` is
display-only). Every stated count reconciled across the suite header,
`tests/run_regression.tcl`, the issue file, `NUMBERING.md` and this receipt.

## ⚠ C14 — the correction this adds

**A hygiene row must assert an identity, never a count.** "One more channel than
I expect" is a statement about the environment; "a channel that is a regular
file" is a statement about this suite. The first form is green under `--nolog`
and red under `--logdir` and calls the difference a leak. ⚠ **And a guard against
something hiding in the absence of a signal can fail in both directions**: the
gate in ADDENDUM 1's list could not see a real absence, and this row saw an
absence that was not real. Both were mine, and both were found by somebody
running the thing a different way.
