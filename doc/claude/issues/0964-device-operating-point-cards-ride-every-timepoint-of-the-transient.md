# 0964 — the device operating-point requests are recorded at every time point of the transient

Status: ✅ **FIXED 2026-08-30**, in the same change as issue 0963. This is issue
**0928 section 7**, reproduced first-hand on the user's own bench and costed.
Design of record: `doc/claude/specs/op_annotation.md` §4.3b. It answers the S4
item's own question — *"say in the write-up whether tier C's .save cards still
ride a transient, and if the fix is small and in scope, take it"* — with **yes,
they did**, and it was in scope: this is where the whole measured win of the
item turned out to live.

## Measured, sky130_tests_ase/tb_bandgap, op AND tran both enabled

    deck with the 468 device requests   20.21 s   144,455,860 bytes
    the identical deck, cards removed   16.13 s    69,595,016 bytes
                                        ------    -------------
    what the device numbers cost         +4.08 s      +74.9 MB

Almost none of that is the operating point. Its own 456 device vectors occupy
one point, about 3.6 KB. The same 456 vectors also appear in the **Transient
Analysis** plot at **20,505 points**, where nothing reads them.

Reproduced in miniature by `tests/headless/test_ase_optier_0963.tcl` section
ACC3 (20 devices, a 200 ns transient, no PDK needed), printed on every run:

    MEASURE c:   deck=3074bytes wall=22ms raw=182148bytes
    MEASURE off: deck=887bytes  wall=18ms raw=8916bytes

i.e. a 20x results file for numbers only the operating point can use.

## The shape of the fix, and the hazard measured inside it

The requests move from deck level into `.control`, immediately before an
operating point that runs LAST. Two things measured that a reader would
otherwise get wrong:

* `unsave` does not exist in ngspice and `save all` does not reset the list, so
  the save list is sticky forward-only — the operating point has to run last or
  the requests reach every earlier analysis anyway.
* **The block's `.save all` leader must stay at deck level.** Moved into
  `.control` with the rest, a bench with per-output `.save <expr>` lines lost
  every other node voltage from its transient: the plot fell from 6 vectors to
  2, `time` and the one named output, silently. Row `G-LEADER` is the only thing
  that can see this.

## And one seam that moves with it

`ase::plot_sim_type` documents that it "must mirror render_deck's emit order
forever". After the reorder the LAST analysis is the operating point, which is
not the plot the waveform viewer should open on. Row `R6` pins it.


## What landed

When the per-device form runs with at least one other analysis enabled:

* the requests move from deck level into `.control`, emitted as `save` commands
  immediately before `op`, split at 999 names per line with the
  save-everything word on the first line only;
* the analysis emit order becomes `dc ac tran op`, so `op` runs **last**.

Both halves are needed. ngspice's save list is sticky forward-only — `unsave`
does not exist and a later `save all` does not reset it, both measured — so
asking inside `.control` with `op` still first puts the requests straight back
onto every analysis that follows.

An operating-point-only run is **byte-identical to what it always was** (row E8
and `test_ase_core` C4/C5), and so is any deck that emits no device requests at
all (row E12). The emit order changes for exactly one shape.

## Measured after the fix

`tests/headless/test_ase_optier_0963.tcl` section ACC3, printed on every run —
20 devices, a 200 ns transient, no PDK needed:

    before (RED pass)   MEASURE c:   deck=3074bytes  wall=22ms  raw=182,148 bytes
    after               MEASURE c:   deck=2483bytes  wall=16ms  raw= 12,731 bytes
    the floor           MEASURE off: deck= 887bytes  wall=16ms  raw=  8,916 bytes

i.e. the results file fell from **20x the no-device-numbers control to 1.4x** it,
and what is left is the operating point's own copy — the only one anything reads.

`tests/headless/test_ase_final.tcl` row F21 now measures it on the real
`test_nfet_final` bench: the operating point still carries the device numbers and
the **transient carries none**. That row also grew a plot-aware reader, because
its old one stopped at the first `Binary:` and would have reported the
transient's vectors under the operating point's name.

## Measured on the user's own bench AFTER the fix, 3 runs of each order

`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap`, op AND tran enabled, the same
deck apart from where the device requests live and which analysis runs last
(`VCCGAUSS` pinned to 1.8 to remove the state's `agauss`):

    op first, 468 cards at deck level   25.36 s / 24.26 s   144,498,100 / 144,491,060 B
    op last, one `save` in .control     19.19 / 19.15 / 20.04 s   69,649,886 / 69,626,142 / 69,870,366 B
                                        ---------------------   -------------------------------------
                                        about 5 s              about 74.8 MB

(A fourth op-first run finished in 4.65 s with a 628 KB file — a transient
convergence failure, `Timestep too small`, that this bench has independently of
any of this. It is excluded, and it is the reason three runs were taken.)

The results file is now within **48 KB (0.07 %)** of the same bench with the
device numbers turned off entirely, against **+74.9 MB** before. Per plot, after:

    PLOT 'Transient Analysis'  vars=424  points=20,512  device parameters=0
    PLOT 'Operating Point'     vars=879  points=1       device parameters=456

— every one of the 456 still there for `6` to read, none of them repeated 20,512
times. (456 and not 468 because of issue **0965**.)

⚠ **CORRECTED BY THE WRITE-UP PASS: THE OPERATING POINT IS *NOT* REACHED FROM A
DIFFERENT STARTING GUESS.** This issue first said the solver would now start
from the transient's final state instead of from cold. That was reasoned from
the reorder, not measured, and it is **false for ngspice**. Measured on a
cross-coupled bistable with 1 pF of state per node — a circuit with three DC
solutions, driven hard into one of them by a transient-only current kick:

    the transient ends LATCHED        v(q) = 1.811825   v(qb) = 0.008087
    the `op` immediately after it     v(q) = 0.800000   v(qb) = 0.800000
    the same deck with no transient   v(q) = 0.800000   v(qb) = 0.800000

`op` inside `.control` re-solves; it does not continue from wherever the
transient left the circuit.

What IS real is this bench's own run-to-run spread, and it is about 2 % wide in
**both** orders: `v(vbg)` **op-first 1.19615 / 1.18454 / 1.20634, op-last
1.19310 / 1.18216 / 1.16632** — two overlapping ranges, same picture per device
parameter (`gm` 7.608–7.683e-6 against 7.649–7.692e-6, `id` 4.830–4.845e-6
against 4.833–4.877e-6). So the change moves the cost and not the numbers, to
the precision this bench is capable of. **Kept as a `rule` debt** all the same:
the analysis order on the user's own bench changed, and the spread is theirs to
accept or not.

## The two things a reader would otherwise get wrong

* **The block's `.save all` leader stays at deck level** (guard G-LEADER). Moved
  into `.control` with the requests, a bench carrying per-output `.save <expr>`
  lines lost every other node voltage from its transient — 6 vectors down to 2,
  silently. Every form emits the leader above `.control`.
* **`ase::plot_sim_type` no longer mirrors the emit order**, and its own comment
  used to say it must, forever. Both readers pick their plot BY NAME, so its
  fixed order is now a preference: the transient wins over the operating point,
  because that is what a user who enabled both wants to look at. Row R6.
* **The deck's `print` lines did follow the reorder, and that was a defect** —
  issue **0967**, found by the S4 sabotage pass and fixed in the repair pass.
  `print` reads whichever plot the simulator is standing in, and those lines sit
  after every analysis, so moving `op` last moved the Outputs pane's **Value**
  column onto the DC operating point. They are now emitted after the analysis
  that is last in the CANONICAL order, so nothing reordered means nothing moves
  and every unreordered deck still renders byte-identically. Rows P1/P2/P3.

## Still owed to the user

A `look` debt: the results file's FIRST plot is now the transient. Rows
R1/R3/R4/R6 prove annotation and the plot-picking seam are unaffected, but what
the waveform viewer window actually SHOWS when it comes up is a pixel question
no headless row can answer.
