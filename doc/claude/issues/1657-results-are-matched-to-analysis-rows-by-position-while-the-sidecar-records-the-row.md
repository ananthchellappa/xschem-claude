# 1657 — Results are matched to analysis rows by POSITION, while the sidecar already records the row

**STAMP:** `v1 claim=fixed tree=7c77f3594 stamped=2026-11-22 fix=taken open=0 by=ovb02`

**Answered and built on 2026-11-20**, on top of `d36cb429e`, and committed as `7c77f3594`
(this opening said "in the working tree, nothing is committed" until 2026-11-22). The user
met the two sentences again that day, on the same bench, in the run that also produced issue
1724's message pass. The title is the defect as it was filed; the three
questions the filing left open are answered below by measurement, the matcher now pairs a
record with what the record's own row declares, and the other procs that walk the rows the
same way were each measured. A verifier of that pass then found two more readers that an
operating point run last crosses, neither of them through the row walk: the sentence about
a stopped run (repaired, below) and the engine's own reader of a results file, the one
case here in which the user got a WRONG VALUE (repaired in the engine by the round that
followed, the same day: "The engine's reader of type `op`", below). Two items were left open
that day; the user ruled on both on 2026-11-21 and both were built on 2026-11-22 ("The two
items that were open", near the foot, with the limits that stay and the one cure the user can
still choose). The text as it was filed on 2026-10-07 is kept at the foot.

## The cause

A deck that asks for the per-device operating-point numbers inside `.control` runs the
operating point **last** (issue 0964: ngspice's save list is sticky forward only, so the
device requests must come immediately before the last analysis; the renderer's `op_last` in
`ase::backend::ngspice::render_deck`). `ase::reconcile_plots` predicted with
`ase::analysis_emit_order $state 0 $sim` — the operating-point-**first** order — and held
sidecar record *i* to prediction *i*.

The deck's own order beside the order the matcher walked, from decks rendered by
`render_deck` itself (device requests held for the netlist; rows 0 `op`, 2 `ac`, 3 `tran`):

| bench | the deck writes | the matcher walked |
|---|---|---|
| `op` + `tran`, device requests inside `.control` | `tran/3` `op/0` | `op/0` `tran/3` |
| `op` + `ac` + `tran`, device requests inside `.control` | `ac/2` `tran/3` `op/0` | `op/0` `ac/2` `tran/3` |
| either, device requests on the op write line (the forced one-line form) | as the walk | as the walk |
| either, device numbers switched off | as the walk | as the walk |

A real run of `sky130_tests_ase/tb_bandgap` (`op` and `tran` enabled, transient shortened,
nothing forced), on apt 45.2 and on a copy of ver_53:

```
sidecar record                       what the matcher held it to
0  tran/3 = Transient Analysis       op/0   = Operating Point
1  op/0   = Operating Point          tran/3 = Transient Analysis
results file, in file order: Transient Analysis, Operating Point
```

and the run said, word for word what the user's log holds:

```
#= ase: results -- the tran analysis in row 3 recorded 'Transient Analysis' where the registry declares 'Operating Point', so results cannot be matched to the row that asked for them.
#= ase: results -- the op analysis in row 0 recorded 'Operating Point' where the registry declares 'Transient Analysis', so results cannot be matched to the row that asked for them.
```

With `ac` enabled as well, three sentences, one per row.

## The three questions the filing left open

**1. Is position the intended contract of the sidecar?** Between the sidecar and the
**results file**, yes, and it holds: the deck writes one record immediately above each
`write`, in its own loop, so record *N* and plot *N* are the same write. In every real run
measured (apt 45.2 and a copy of ver_53; `op`+`tran` and `op`+`ac`+`tran`; operating point
first and last) the sidecar order was the deck's order and the file's order. Between the
sidecar and the **row order**, no, and it was never meant to be: the record carries the
row's index in `analyses` and not a counter
(`ase::plotmap_record`'s own header: *"a counter would say 'the third plot'; the position
says WHICH ROW, which is the whole reason this file exists"*), and the header above the
sidecar's procs names the operating-point-last variant as the reason order cannot identify a
plot. So the writer is right and the sidecar is right. The defect was in the reader: the
registry leg of `ase::reconcile_plots` threw the row away and compared by position against a
walk in an order the deck does not always use.

**2. What did the user lose?** On the benches the question was first measured on (`op` +
`tran`, and `op` + `ac` + `tran`), no result. She was told two false things on every such
run (three with `ac`), and when something really was wrong the true sentence came out
wrong with them (the over-walk measured below). ⚠ On a bench with an `op` and a `noise`
row she did lose a result, to another reader: "The engine's reader of type `op`", below,
which is repaired.

- `ase::reconcile_report`'s answer is read by nothing: `ase::run_done` calls it inside a
  `catch` and drops what it returns.
- On those two benches every reader got its own plot. In the operating-point-last run:
  `xschem raw read <file> op` gives the one-point plot and `... tran` the transient;
  `ase::stimuli_nvec` asked for row 0 gives the operating point's vector count and for
  row 3 the transient's. ⚠ That is not "every reader picks its plot by name": the engine's
  reader behind `xschem raw read <file> op` picks by TYPE, in file order, among the plots
  whose name reads as that type, and when this was measured it was right only because
  neither bench writes a second plot that reads as `op` ahead of the operating point. It
  no longer rests on that: "The engine's reader of type `op`", below.
- The same bench run with the operating point last and with it first (the one-line form,
  which moves nothing), on both programs: the Outputs values are equal; the transient and
  the AC plots hold the same vectors, equal in every sample as `xschem raw values` prints
  them; every operating-point vector the two runs share has the same value (the two forms
  save different sets of device vectors).
- What the sentences cost: a run in which each row wrote its own plot was called
  mislabelled every time, which is how a channel gets ignored. A run **stopped** before its
  operating point was called mislabelled in place of the calm sentence a Stop gets (row
  RO6's fixture; no real run was stopped for this). And a
  real over-walk was misdescribed: measured on both programs with the transient's walk made
  one plot too long, the old pairing said three things, none of them naming the plot the row
  should have recorded; the pairing by row says the one true thing,
  `the tran analysis in row 3 recorded 'constants' where the registry declares 'Noise Spectral Density Curves'`.

**3. Does it reproduce?** On every run where an operating point and another analysis are
enabled and the device operating-point numbers are saved (the default), on any program:
apt 45.2 takes the per-device form and ver_53 the dump form, and both move the operating
point last. It does not need this bench or its row order.

## What was changed

`ase::reconcile_plots` (`src/ase.tcl`). Two legs, paired two ways:

- **record against the results file**: position by position, as before.
- **record against the registry**: by row. The first record of a row is held to the first
  plot that row declares, the second to its second (a row's plots are declared in the order
  its walk writes them, which is unchanged).
- A record with no row to be held to — its row is not an enabled row now, or it is one
  record more than the row declares — is compared, in order, with the declared plots no
  record claimed, which is how every record was compared before. So a bench edited between
  rendering the deck and reading it back is still told; a walk too long in a run that then
  ended early (every count agreeing) is still told; and a record beyond every declared plot
  is still left to the count sentence.

No sentence of the reconciliation was reworded and none was added. The counts (`under`,
`over`, `predmismatch`, `aborted`) and the severity order are untouched.

`ase::ckpt_report` (`src/ase.tcl`), by the repair pass of the same day. A run that is
stopped after its checkpointed analysis was written -- which a deck that runs its
operating point last makes possible, under the trailing operating point -- is no longer
told that the plot was "still filling" and "kept at" the checkpoint's count. Measured on
apt 45.2 (an `op` and a `tran`, device requests held, the deck cut above its `op` line,
which leaves what a kill at that instant leaves): the results file held the transient at
400066 points, the checkpoint 400000 of them, the sidecar the transient's record, and the
run said the transient was still filling. It now says, where the sidecar holds the record
of the last checkpointed row and the results file lists that plot at the record's place
(`ase::ckpt_finished`): `ase: salvage -- this run was stopped after its 'Transient
Analysis' plot was written: the results file holds it at 400066 points, with every
analysis that finished before it. The op analysis in row 0 did not finish.` With the
record there and the plot not in the file, or no results file, the checkpoint is still
what is reported, in the old words. Row CK23e. Not told apart: a run stopped while that
plot was being written, whose file already lists the plot.

`read_dataset()` (`src/save.c`), by the round that followed the same day: a caller that
asks for type `op` is given the `Operating Point` plot, and the `Integrated Noise` plot
only when the file holds no operating point. The section "The engine's reader of type
`op`", below, has the measurements, the rows and the limits.

What the pairing by row no longer says, measured by the same verifier on hand-made
sidecars that no deck can write (the sidecar is deleted before every run, and the run is
reconciled against the state its deck was rendered from): a record whose row is out of
range, or a disabled row, naming a plot an unclaimed row declares; a record whose TYPE
differs from its row's type while the plot name fits the row; and rows recorded out of
deck order with each record its own row's plot. The old pairing told the first two only
because it had crossed them, and its sentence for the third was not true. Left as they
are; telling the first two would take a new sentence.

Rows, in section RO of `tests/headless/test_ase_core.tcl`. The record order of every fixture
is read from the `echo "PLOT ..."` lines of a deck `render_deck` wrote for the bench; RO2 is
the leg that says that order really is the crossed one.

| row | what it holds | against the pairing as it stood |
|---|---|---|
| RO1 | who walks the rows through `ase::analysis_emit_order`, derived from the source | green (a census) |
| RO2 | the deck records its operating point last where the walk has it first | green (the fixture) |
| RO3 | that order reconciles `ok` and says nothing, with `op`+`tran` and with `op`+`ac`+`tran` | red |
| RO4 | a row that recorded another plot is told once, against what that row declares; two records that carry each other's row are both told (a pairing by the row's type calls that fixture `ok`) | red |
| RO5 | a two-plot row ahead of the operating point: `constants` as its second plot is the one mislabel, every count agreeing | red |
| RO6 | a run that ended before its operating point is `predmismatch` / `aborted`, a lost write `under`, an extra plot `over` | red |
| RO7 | a record with no row to be held to | red |
| RO8 | the file leg is still position by position | green (unchanged) |
| RO9a, RO9b | why `ase::meas_counter_index` is not crossed | green |
| RO10 | why `ase::ckpt_rows` is not crossed | green |

The rows that held the `constants` detection and the counts before (RC2, RC3, RC4, RC4b, RC5,
RC5b, RC12, MP18, MP18b, MP19, CK24 to CK24d; SM2 of `test_ase_sp_1452`) did not move, and
each was driven red again by taking its leg out of the changed proc.

## The other procs that walk the rows operating-point-first

Row RO1 derives them: the deck (which passes its own `op_last`) and four others.

| proc | what it pairs | crossed by an operating point run last? | what the user sees |
|---|---|---|---|
| `ase::reconcile_plots` | a sidecar record with a predicted plot | **yes** | false sentences, no wrong value: above. Fixed. |
| `ase::meas_counter_index` | a Fourier row with the run-wide call number its result is named after (`thd<n>1`) | **no** | — |
| `ase::ckpt_rows` | nothing; lists the rows that get a checkpoint block | **no** | — |
| `ase::preview_analysis_types` | nothing; orders the per-analysis groups of the Options preview | **it was, in the order shown**; since 2026-11-22 it takes the order its caller asks the backend for, and no longer passes the operating-point-first order (row RO1 moved) | the groups in the deck's order, each headed by its analysis: "The two items that were open", item 1 |

Two readers that do not go through that walk and are crossed all the same, found by the
verifier of this pass:

| reader | what it reads | crossed by an operating point run last? | what the user sees |
|---|---|---|---|
| `ase::ckpt_report` | the checkpoint file, as "the plot that was still filling" | **yes**, for a run stopped under the trailing operating point | a false sentence. Fixed: above, row CK23e. |
| `read_dataset()` in `src/save.c`, asked for type `op` (`xschem raw read <file> op`, `xschem annotate_op`, `ase::attach_dbs <file> op`, the Calculator's operating-point read) | the first plot in file order whose name reads as `op` | **yes**, on a bench with an `op` and a `noise` row | a WRONG VALUE. Fixed in the engine: "The engine's reader of type `op`", below; band M of `tests/headless/test_raw_ascii_point_bounds.tcl`. |

`ase::meas_counter_index` is not crossed because the deck moves only the operating point,
and no row that carries such a number is emitted for an operating point: the one kind that
declares a counter is the Fourier producer, and the adapter's rule refuses it on any row that
is not a transient. Measured with `op`+`tran`, `op`+`ac`+`tran` and `op`+`tran`+`tran`: the
predicted numbers are the ones the operating-point-last deck gives (`thd11`, `thd21`,
`thd31`). ⚠ That reason is the adapter's and not the proc's. With the refusal taken out in
memory, the operating-point-last deck named **every** Fourier result after the wrong call
(`fourier_a` read `thd21`, the second call's number, and so on) — a wrong value. Rows RO9a
and RO9b now hold both halves: a kind that carries a counter and can be measured on an
operating point reddens them.

`ase::ckpt_rows` is not crossed because an operating point declares no `salvage` and is
never a member; the members keep their order among themselves, which is all
`ase::ckpt_report`'s "the last one" reads. Row RO10.

## The engine's reader of type `op` (repaired 2026-11-20, in `src/save.c`)

**As the verifier measured it, before the repair.** ngspice names the noise totals' plot
`Integrated Noise`, and `read_dataset()` (`src/save.c`) answered a caller that asked for
type `op` with it as well as with `Operating Point`, taking the first in file order. A deck
that runs the operating point last writes the noise plots first. On a three-element bench,
`op` + `noise` (dec 4, 1k to 100k), device requests held (the default), real runs on apt
45.2 and on a copy of ver_53: the deck writes `noise/1 noise/1 op/0`; the file reads
`Integrated Noise`, `Noise Spectral Density Curves`, `Operating Point`; `xschem raw read
<file> op` gave one dataset whose names were `v(onoise_total) v(inoise_total)` and no
`v(out)`; `xschem annotate_op <file>` published those, so no node voltage was annotated;
an Outputs row `vdc(out)*2` read `Cannot evaluate: unknown token 'vdc(out)' (not an
operator/function, number or raw variable).`; `ase::attach_dbs <file> op` attached the
noise totals. With device numbers off (operating point first) the same bench read `v(in)
v(out) i(v1)` and the row read `1.500000e+00`. Not introduced by the pass that fixed the
reconciliation: `src/save.c` and the deck's order were unchanged by it.

**The rule built.** For a caller that ASKED for type `op`, an `Integrated Noise` plot
answers only when the read took no other plot -- which, for every plot name a simulator
writes and on a file whose blocks the reader can step over, is "the file holds no
`Operating Point` plot" (the list at the foot of this section has the file it cannot step
over, and the plot name no simulator writes). Such a caller's pass over the file
skips each `Integrated Noise` plot as it skips a plot of another type. A pass that reaches
the end of the file having taken nothing and skipped one is run once more from where it
began, with the totals answering as they always did. Nothing that was read is thrown away:
a pass that took no plot has written nothing into the database except a casemode line
standing ahead of the first plot, and that field is put back before the second pass. The
rule and the list of what it leaves alone are written above the `integrated noise` arm of
`read_dataset()`.

**What did not move**, measured cell by cell against the binary as it stood, on
hand-written results files in both block forms (a `Values:` block and a `Binary:` block),
every file asked `op`, `noise`, `tran`, `dc` and no type at all: a read that names no type;
a read asking for any type but `op`; a file with noise plots and no operating point asked
`op` (the totals, the same names and values); an operating point alone; the promotion of a
multi-point operating point to `dc`; the casemode header; a malformed block. The only cells
that moved in that matrix are those asking `op` of a file that holds both kinds of plot,
and each now answers what the older binary answered for the same file with its
`Integrated Noise` plots taken out.

The verifier of that round ran a wider matrix (more orders, CRLF line ends, a title
between plots, malformed header lines, a plot named after the type), old binary against
new, and found cells that sentence does not hold for. Each kind is in the list below
with what was done about it: a file holding the totals and a plot whose whole name
is `op` and no `Operating Point` plot, whose answer moved; a file with a malformed header
line in the totals' own header, which is now refused where the operating point was
answered; and an ascii file with CRLF line ends and the totals first, which the rule does
not reach.

**Measured after**, the same bench on the same two programs. Operating point last: the
reader asked for `op` lists `v(in)`, `v(out)`, `i(v1)` (on apt 45.2 the two per-device
currents beside them); `xschem annotate_op` publishes `v(in)` 1, `v(out)` 0.75 and
`i(v1)`; the Outputs row `vdc(out)*2` reads `1.500000e+00`; `ase::attach_dbs <file> op`
attaches the operating point. With a `tran` row added: the same. Operating point first: as
before. A noise-only run: the reader asked for `op` still lists `v(onoise_total)
v(inoise_total)` and the annotation still publishes them.

**Rows.** Band M of `tests/headless/test_raw_ascii_point_bounds.tcl` (registered, no
simulator). The cells the rule moves were red on the binary as it stood, and every other
cell was green on it. Added after the verifier's matrix: the files `in_pno` (the totals,
then a plot named `op`), `op_trb`, `op_inb`, `op_in_nsb` and `in_opb` (a malformed header
line behind the operating point, or in it), every one asked every type in both block
forms, and the M-wipe rows (what such a read leaves loaded). Every expected answer is
again the older binary's: on the file itself where nothing moved, on the file without its
totals where the rule moves the cell, and for the one cell whose malformed line is in the
totals' own header, on the operating point followed by a transient plot that carries the
same malformed line in the same place (`op_trb`).

**What follows from the rule, and where it stops.**

- *More than one operating point in a file.* With the operating point first, the totals
  used to arrive as a second `op` dataset, fail the variable-count rule and END the read.
  They are skipped now and the read goes on, so a file holding `Operating Point`,
  `Integrated Noise`, the spectrum, `Operating Point` gives each operating point as a
  dataset where it gave the first. Measured on such files: `xschem annotate_op` publishes
  the first operating point; the Calculator's `vdc()` reads the first; `ase::attach_dbs
  <file> op` attaches both datasets; `ase::optexport_datasets` counts both. A read asking
  `op` already gave every operating point of a file that holds several and no totals. No
  tracked ASE state has an enabled `noise` row or two enabled `op` rows, and no results
  file in the tree holds an `Integrated Noise` plot.
- *Totals with as many variables as the operating point* were appended to it as a second
  dataset, under the operating point's names. They are not any more.
- *A malformed operating point behind the totals.* The read used to succeed with the
  totals; it is refused now, as a read of a malformed operating point is refused. Where
  what is malformed is a header line (`No. Points:` with no number, say) the refusal also
  clears every database that was loaded, as that refusal does for any file: before the
  rule the totals answered and what was loaded stayed. File `in_opb` of band M and its
  M-wipe row.
- *A malformed header line BEHIND the operating point costs the read, and the loaded
  databases with it.* A header line the reader cannot read (`No. of Data Rows :`,
  `No. Variables:` or `No. Points:` holding no number) refuses the whole file and clears
  every loaded database, in a plot the reader skips as in one it takes; that is older
  than the rule (file `op_trb`: an operating point, then a transient with such a line,
  refused on the older binary too). While a read asking `op` ended at the totals, such a
  line standing behind them -- in the totals' own header after its `No. Variables:` line,
  or in any plot after them -- was never met: the caller was given the operating point,
  and the databases loaded before it stayed loaded. The totals are stepped over now, the
  read goes on, meets the line, is refused, and the registry is empty afterwards.
  Measured on both binaries (files `op_inb` and `op_in_nsb` of band M: their cells in
  both block forms, and their M-wipe rows on the ascii form). Only a hand-made or
  damaged file holds such a line; the verifier's real runs of both programs wrote none.
  Left as built and stated above the arm. The older outcome could be kept by ending the
  read with what it holds when such a line is met after the totals were stepped over;
  that would make a malformed header cost less behind the totals than it costs anywhere
  else, and was not built.
- *An ASCII results file whose lines end CRLF is NOT cured.* The reader's skip of a block
  it does not want looks for an LF-only blank line (issue 0300), so the skip of the totals'
  block runs to the end of the file, the pass takes nothing, and the totals answer as
  before. A binary file with CRLF header lines is cured. ASE-L writes binary files.
  Accepted and said above the arm; the cure is issue 0300's skip and was not attempted
  here. No row: it would hold a wrong answer in place. Not a regression: an ascii CRLF
  file with the operating point first answers with it on both binaries, and one with the
  totals first answered with the totals before the rule too.
- *A plot whose whole name is the word asked for* (`Plotname: op`, which the reader's
  plot-name arm takes) counts as a taken plot. A file holding the totals, then such a plot,
  and no `Operating Point` plot used to answer `op` with the totals and now answers with
  that plot. No simulator writes such a name. Here the rule as built ("took no other
  plot") and the rule as it is said ("the file holds no `Operating Point` plot") give
  different answers, and the answer of a file that holds no operating point changed.
  Left as built and pinned so that it cannot drift (file `in_pno` of
  band M, the cells of kind `named`, and row M0b for its numbers). Holding the other
  answer would take the reader knowing, before it takes that plot, whether an
  `Operating Point` plot stands anywhere in the file.
- *An `opinfo` plot* (`NOISE Operating Point` and its like) holds the words the reader's
  operating-point arm looks for, so it is an operating point to this rule as it always was
  to the reader. Standing behind the totals it now answers `op` where the totals did;
  standing ahead of them it already did. Measured on hand-written files; the noise-only
  run above, on either program, wrote the two noise plots and no such plot.
- *Which plot a read asking `noise` is given* is untouched and is still file order: the
  totals where they stand first, as they do in ASE-L's files, and the spectrum where it
  does. That question is recorded above the `noise` entry of the adapter's registry.
- *A database of the file that is already loaded under `op` was not read again.* As it
  stood on 2026-11-20: the reader is not called, `extra_rawfile()` (`src/save.c`) switches
  to the database that is there. A read that named no type stores a totals-first file
  under `op`, so after such a read `xschem raw read <file> op` showed those totals, and so
  did `xschem annotate_op <file>` when that database was loaded and not the current one.
  `ase::attach_dbs <file> op`, `op_annot::db_attach` and the Calculator's read
  (`calc::eval_texts`) were given the operating point in both cases. **Closed on
  2026-11-22** for every request that names `op`: "The two items that were open", item 2,
  which also lists the readers that ask for no read and still show such a database as it
  stands.
- *A window opened on a loaded database* carries it across by its stored type
  (`open_sub_schematic`, `hi_descend_newwin`). A database that a read naming no type took
  from a totals-first file is stored as `op`, so the new window asks for `op`, in a
  registry of its own, and gets the operating point. Driven since 2026-11-22: row
  M-newwin of `tests/headless/test_raw_ascii_point_bounds.tcl` (it was green on the
  binary as it stood, as this entry had read from the code).

## The two items that were open (ruled 2026-11-21, built 2026-11-22)

Both were left to the user on 2026-11-20. The user ruled on 2026-11-21; the batch of that
night built them (`doc/claude/overnight_batch_2026_11_21/`, item 02, whose receipt holds
the measurements this section quotes).

### 1. The Options preview shows the deck's order, in labelled groups

**As it stood.** With one per-analysis option on `op` and one on `tran`, the slot "inside
the analysis block" listed the `op` lines above the `tran` lines; the deck of the same
bench, device requests held, wrote them below. Reproduced on 2026-11-22 before anything
changed: the preview listed `option itl1=300`, `option itl1=100`, `option itl4=200`,
`option itl4=10` and the deck wrote the two `itl4` lines around `tran` and then the two
`itl1` lines around `op`.

**Ruled:** "deck order + labels". The preview asks the question the deck asks, with the
netlist the window already reads, lists the per-analysis groups in the order the deck will
run them, and heads each group with its analysis. Before a netlist of this session exists
it says plainly that the operating point's group may run last.

**Built.**

- *The question is the backend's.* Core asks `ase::op_run_order`, which asks an optional
  adapter hook, `op_run_order {state netlist_text}`, for `first`, `last` or `unknown`. The
  ngspice adapter answers from the same facts `render_deck` decides on (the switch that
  saves device numbers, an enabled operating point, another enabled analysis, device
  requests held for exactly this netlist text, the forced shape) without rendering and
  without starting a simulator (row RO17 watches the procs that would measure it).
  `unknown` is "the switch is on, the operating point and another analysis are enabled,
  and this is not the netlist the requests are held for": no netlist yet, a netlist
  another session's capture replaced in the one held block, or a netlist edited since.
  It is also the answer for a netlist that IS the held one when it was written while the
  operating point was switched off: the capture then holds an empty block for it and
  records why (`ase::op_cards_why`), and once the user switches the operating point on,
  the next netlist will capture requests (row RO18; found by the attack of 2026-11-22,
  where the hook answered `first` and the sheet showed no sentence). A backend with no
  hook is answered `first`.
- *The window hands over the unreduced netlist* for that one question, as a fifth argument
  of `ase::opt_preview` (`ase::ui::optsheet_netlist_full`); the seed rule keeps its reduced
  copy. Where the run would read another file than the window does (a bench with no run
  directory while `local_netlist_dir` is set) nothing is handed over, and the answer is
  `unknown`.
- *The slot.* Each entry is `{option line analysis}`. The groups stand in the deck's order
  and the lines of a group in the order the deck writes them around that analysis (rows
  DK10e and DK10f compare a group of two scoped options, and a scoped option around the
  pair ASE-L adds, with the deck); the lines ASE-L adds itself (the `klu` pair around an
  AC `sens`) stand in their own analysis's group, each once. The pane prints a group
  heading, `<TYPE> BLOCK`, two spaces in. Under a slot heading a deck line stands four
  spaces in, as before; so do the placeholder `(nothing)` of an empty slot and the lines
  under `not delivered`, which are not deck lines. (This bullet said "a deck line is still
  the only thing four spaces in" until 2026-11-22; those two made it untrue.)
- *What it says.* When the deck moved the operating point: `OP BLOCK -- runs last in this
  deck` (or `runs after tran in this deck` where an `sp` row still follows it). When the
  order is not settled and it can matter (two groups with lines, or an option left in
  force), once, under the slot's heading: *"the op analysis runs after tran when device
  operating-point numbers are saved; that is settled when the netlist is written"*. On the
  pane that sentence wraps at a word (row UI25b); the mark of a group and this sentence
  are never listed under `not delivered` (row PV15b).
- *The note about an option that is not put back* names what runs after it once the order
  is known (*"left in force for the analyses that run after it in this deck (op)"*), says
  *"no analysis runs after it in this deck"* when none does, and keeps the reviewed words
  while the order is not known.
- *The open sheet does not go stale.* A new netlist, the tick that saves device numbers,
  an analysis switched on or off and a forced shape each repaint an open sheet's preview.
  Those are ASE-L's own writers; a netlist changed on disk by something else (the
  schematic window's own Netlist command, an edit by hand) repaints it when the sheet gets
  the keyboard focus (row UI30).

**Measured for the note** (2026-11-22, ngspice-45.2 and a copy of the `ver_53` build): a
`dc` row that sweeps a design variable loads the circuit again at every point; after that
reload an `option name=value` written inside the block is back at the deck's value (`itl1`
300 to 100, `gmin` 1e-10 to 1e-12) and a `set` variable is still set. Every option the
shipped catalogue can leave in force is either written as a `set` variable or scoped to an
analysis the deck runs after `dc`, so "left in force for the analyses that run after it"
holds across such a row. Row SP7b derives that from the catalogue and the registry.

**Rows.** `tests/headless/test_ase_core.tcl` RO1 (moved), RO12 to RO18;
`test_ase_optsheet_1441.tcl` PV12 to PV18 with PV15b and, on a display, UI25 to UI30 with
UI25b; `test_ase_effective_1442.tcl` DK10c to DK10f, SP7b; `test_ase_run_seed.tcl` RS10b,
RS11, RS12. RO13 holds the hook against decks `render_deck` wrote, cell by cell.

**Stated limits.** The order shown is the order of a deck rendered from the netlist on
disk. A Netlist and Run writes a new netlist first; where that changes what is captured
(a sheet that became dirty, say) the deck follows the new capture and the open sheet is
repainted when it lands. The held block is one per process, so netlisting another
session's design makes this session's preview say "not settled" until its own netlist is
written again; that is what a Run on the old netlist would then do (row RO15). An empty
block held because the sheet had unsaved edits, or because the walk of the design raised,
is still answered `first`: the capture does not say whether the next netlist will fare
better. A sheet that is open and does not have the keyboard focus still shows the order
of the netlist it last read when another program rewrites that file. The pane shows a
few lines at a time, so on a bench with many option lines the operating point's heading
is reached by scrolling; and the lines under `not delivered` are not wrapped and can run
past the pane's right edge, as before this item.

### 2. A request for `op` reads again when an untyped read stored the noise totals

**As it stood.** Reproduced on 2026-11-22 on a hand-written file (`Integrated Noise`,
`Noise Spectral Density Curves`, `Operating Point`), after `xschem raw read <file>` or
`xschem raw_read <file>` with no type: `xschem raw read <file> op` answered 1 and listed
`v(onoise_total)`; `xschem raw select <file> op` answered 2 and listed it; `xschem
annotate_op <file>` published the totals when that database was loaded and a transient was
current, and the operating point when the totals were current. And one the filing had only
read: after `xschem raw_read <file> op` (the operating point, correctly), `xschem raw case
preserve` showed the totals, because that door did not record the type it was asked.

**Ruled:** "re-read when op is asked". A request that names `op` and meets a table that an
untyped read took from the noise totals reads the file again and gets the operating point.
Every caller is cured. A file without noise totals behaves exactly as before.

**Built.**

- *The mark.* `read_dataset()` sets `Raw.totals_as_op` when a read that named no type took
  an `Integrated Noise` plot as `op`, as the first dataset or appended to an operating
  point of the same variable count (rows M-equal: both orders, both block forms; the table
  then holds two datasets, and the request naming `op` leaves the operating point alone
  in it). `xschem raw totals_as_op [<slot>]` reads it; `xschem raw info` prints what it
  printed.
- *Who asks.* The registry reads again only for a request whose own words named `op`
  (`RAW_READ_NAMED_TYPE`): `xschem raw read <file> op`, `xschem raw select <file> op`, and
  `xschem annotate_op`. Not for a type the engine filled in (a select with no type, a graph
  that names none), never from the drawing code, and not for `xschem raw read <file> op
  -asis`, which a caller that only puts a table back says.
- *In place.* The file is read first; on success the marked table is replaced in the same
  slot, the slot count does not move, the cursors move as a switch moves them. It never
  goes through the clear arm. The binding stays the replaced table's when that table was
  bound on the current hierarchy stack: asked from inside an instance, the operating point
  is bound to the sheet the totals were bound to, as a switch to any other loaded table
  leaves it (rows M-descend). As first built the re-read bound the new table to the sheet
  the request came from: MEASURED by the attack of 2026-11-22, results selected at the
  top and the annotate chord pressed inside an instance showed the top-level net's voltage
  on a same-named net of the child, and after ascending the top-level design had no
  results. Repaired the same day.
- *Telling the re-read from a switch.* The slot count does not move, so a caller that
  must know asks `extra_rawfile_reread()` right after the call. The answer is cleared on
  entry of every read call, in both arms of the registry: as first built it was cleared
  only in the SPICE arm, and after any re-read a select of a loaded VCD answered 1 where
  it answers 2, and `xschem raw select <file> table` of a file loaded as `op` succeeded
  where it is refused (rows M-flag). The `-case` option of `xschem raw read` asks it too,
  so a read naming `op` with a case mode reads a marked table once, in its slot; with
  `-asis` as well the table is read again the way it was first read, so it stays the
  totals (rows M-case-option).
- *When the re-read fails* the answer is 0 and nothing moved: the table that was loaded is
  still loaded, what was current is still current. One exception, older than this and not
  changed: a header line the reader cannot read clears every table from inside the reader,
  for every file.
- *`raw select`* that named `op` and met a marked table answers 1, what a read answers.
- *The readers that never read* are cured in Tcl with the mark: the Cadence profile's
  annotate chord (`cadence::_annot_op_db_ok`) asks for a read of a marked table's own file
  instead of publishing it; `calc::aq_run` does not evaluate a marked table where it
  stands; `calc::aq_restore` puts the user's table back with `-asis`.
- *The door that forgot what it was asked.* `xschem raw_read <file> <type>` now records the
  type, so a case-mode change reads the file again as it was asked. The table a re-read
  builds records `op` the same way (rows M-case-reread, through each of the three doors).
  **This is the one answer that moved for a file WITHOUT noise totals**, and it moved for
  every type: after `xschem raw_read <file> <type>` a case-mode change used to read the
  file with no type and take its first plot. Measured both ways on 2026-11-22: a file
  holding an operating point and then a transient, asked `tran`, came back from `xschem
  raw case preserve` as the operating point and now stays the transient; a VCD asked `vcd`
  was refused by that re-read, which left nothing loaded, and now stays loaded. Both are
  cures of the same defect; rows M-case-plain hold them.
- *A totals-only file* is marked too: the first request that names `op` reads once more,
  gets the totals again, and the table is no longer marked. Its answer does not change.

After an untyped read of a totals-first file that holds an operating point, each of these
is given the operating point: `xschem raw read <f> op`; `xschem raw select <f> op`; `xschem
annotate_op <f>` with the totals current and with them loaded and not current; the Cadence
profile's annotate chord; `ase::attach_dbs <f> op`, `op_annot::db_attach` and
`calc::eval_texts` (as before); the Calculator buffer's `vdc()` through `calc::aq_run` on
both arms; a window opened from it.

**Rows.** Band M of `tests/headless/test_raw_ascii_point_bounds.tcl` (the M-loaded,
M-mark, M-totals-only, M-plain, M-asis, M-annotate-loaded, M-select, M-reread-keeps,
M-case, M-case-reread, M-case-plain, M-case-option, M-flag, M-equal, M-descend and
M-newwin rows); band AT15 of `test_calc_analysis_tokens.tcl` (both arms of
`calc::aq_run`, the restore, and on a display a draw that does not read again); R14 to R18
of `test_annot_op_behind_tran_1242.tcl`, which is registered with this change (R18 is
the annotate chord pressed inside an instance: the operating point stays bound to the
top level).

**Stated limits, each as the ruling leaves it.** These ask for no read, so they move to a
marked table and show it as it stands:

- `xschem raw switch`, `xschem raw switch_back`, and a `xschem raw select` that names no
  type. All three publish a one-point `op` table when they land on it, so they publish
  the totals.
- `results::select` with no type on a totals-first file that is not loaded: it reads with
  no type, stores the totals and publishes them in the same call.
- A graph with `autoload` set draws from a marked table as it stands (a draw never reads
  again; band AT15's display leg holds that).
- A totals-first file whose operating point holds several points is stored as `dc` by the
  re-read, as it always was by a read that asks `op`; the slot's type changes with it.

**The cure not taken, which the user can still choose.** A read that names no type could
decline to store the totals as `op` at all when the file also holds an operating point. It
would reach every reader in the list above, because the marked table would never exist.
It was not offered when the user ruled, and it moves answers this issue lists as
deliberately unchanged (what a read naming no type gives for a totals-first file, in band
M's cells). Not built; returned to the user as a ruling to make.

**The sibling left open: issue 0685.** `xschem annotate_op` of a file whose operating point
is loaded and not current still shows the loaded numbers when the file has no noise totals
(row F12 of `tests/headless/test_annot_stale_0684.tcl`, unmoved). The user chose this
item's cure over the one that is 0685's engine fix; 0685 stays open as filed.

---

## As filed on 2026-10-07

The filing, word for word, less its title and its stamp line (which read `claim=open`,
`tree=790556f2`, `fix=untried`, `open=2`). Two things in it are corrected by the sections
above: the loop it quotes is in `ase::reconcile_plots`, not `ase::cap_verdict`; and `orderok`
says only that every enabled row has a rank on this backend, so it was never a statement
about the order the deck runs in.

### The user's own evidence

From `/tmp/Xschem.log.3`, a real `tb_bandgap` run on 2026-10-07 (the user handed the log
over while reporting unrelated Calculator defects):

```
#= ase: results -- a row whose expression names exactly one vector is read from the
      results file; anything else is read from the print log. This run: 5 from the file, 0 from the log.
#= ase: results -- the tran analysis in row 3 recorded 'Transient Analysis' where the
      registry declares 'Operating Point', so results cannot be matched to the row that asked for them.
#= ase: results -- the op analysis in row 0 recorded 'Operating Point' where the
      registry declares 'Transient Analysis', so results cannot be matched to the row that asked for them.
```

The two sentences are **each other's mirror image**: row 3 (`tran`) produced the title the
registry expected for row 0, and row 0 (`op`) produced the one expected for row 3. That is
not two independent mislabels — it is **one crossed pairing** reported twice.

### The mechanism, read in `ase::cap_verdict` (`src/ase.tcl`)

Two lists are built and then compared **1:1 by position**:

| list | built from | order |
|---|---|---|
| `$map` | `ase::plotmap_read` — the sidecar written at run time | the order the plots were **written** |
| `$expect` | a walk over the registry's analysis rows | the order the rows are **listed** |

```tcl
# 1:1, position by position, against BOTH the file and the registry
for {set i 0} {$i < $n} {incr i} {
    set mrec [lindex $map $i]
    ...
    set sel [lindex [lindex $expect $i] 2]
    if {![string match -nocase $sel $got]} {
        lappend mis [list [lindex $mrec 0] [lindex $mrec 1] $got $sel registry]
    }
}
```

⚠ **`$mrec` carries the row index at element 1 and the comparison throws it away.** The
sidecar record is `{atype rowindex plotname}` and `$expect`'s elements are
`{atype rowindex plot_select}` — so **both sides already know which row each plot belongs
to**, and the matcher pairs them by their position in two differently-ordered lists instead.
The row index is used only to *report* the mismatch it caused.

The `registry` side of the comparison is guarded by `if {!$orderok || ...} continue`, so this
fired with `orderok` TRUE — i.e. something upstream judged the order sound and the positional
pairing then crossed two rows anyway. Whether `orderok`'s own computation is wrong, or whether
it is answering a different question from the one this loop needs, is **not established here**.

### What is NOT established, and must be before anything is changed

1. **Whether position is the intended contract.** It is possible the sidecar is *supposed* to
   be written in registry-row order and the real defect is upstream, in whatever writes it —
   in which case keying on the row index would paper over a wrong sidecar. Read
   `ase::plotmap_read` and its writer before deciding.
2. **What the user actually lost.** The sentence says results "cannot be matched to the row
   that asked for them", but not what the consequence is downstream — whether those two rows
   show no results, the wrong results, or stale ones. **That is the half that decides how
   urgent this is**, and it is unmeasured. The run reported `5 from the file, 0 from the log`,
   so the data was read; only the pairing failed.
3. Whether this reproduces, or needs this particular registry's row ordering. One observation.

### Why it is filed rather than fixed

It arrived inside a report about seven Calculator defects and is none of them. Keying the
match on the row index both sides already carry is a two-line change and looks obviously
right, which is exactly the shape this tree has been burned by twice (CLAUDE.md records a
guard that "looked right" and refused correct work, and two wrong repairs to a predicate whose
own 187-check suite passed against both). It needs (1) and (2) answered first.

Family: not the same as 1413/1647 (knowing `hcases`-alone trades). Nearest relative is issue
1650's shape — a positional assumption that is right for every fixture anyone drove and wrong
for the real case.
