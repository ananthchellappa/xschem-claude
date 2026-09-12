# Receipt 07 — Stage 2, the type list is measured

**Seven commits, not one.** `PLAN.md` says Stage 2 is *"One commit"*; that was refuted by
measurement before a line was written, and the refutation shaped everything after it.

| | commit | issue | floors moved |
|---|---|---|---|
| C2 | a re-registered backend kept answering from the registry it replaced | **1406** | simcaps 110 → 111 |
| C1 | ASE-L asked the same question of one dict twenty-eight different ways | **1407** | simcaps 111 → 126 |
| C3 | ASE-L described a simulator it had never been told anything about | **1408** | core 266 → 273; dialogs display 215 → 224 |
| C4 | ASE-L never asked the simulator which analyses it has | **1409** | simcaps 126 → 141 |
| C5 | eleven analyses, each with a state and a reason | **1410** | core 273 → 289; simcaps 141 → 148 |
| C6 | the grid says which analyses this build can run, and why not | **1411** | dialogs display 224 → 236 |
| C7 | four defects measured from files instead of a version string | **1412** | simcaps 148 → 158 |

Plus **1405**, a Stage 1 debt the recon found before Stage 2 code was written.

**T1 at zero on every one of them**, run solo.

---

## What the stage delivers

**Eleven analyses instead of four**, in a wrapping grid, each cell carrying its state as a glyph
and its reason as a sentence. The honest answer for this tree today is **four `ok` and seven
`blocked`** — the seven are listed so the user can see they exist, and blocked until Stage 6 gives
them an `emit`.

Under that: a capability vocabulary that says the same thing once instead of twenty-eight times; a
probe that asks the simulator which analyses it has instead of guessing; a resolver with five
reason tokens; and four measured defect keys that tell two builds apart when their version strings
cannot.

---

## THE ONE LESSON THIS STAGE KEPT RE-TEACHING

**A test section is not done when it is green. It is done when its sabotages redden it.**

Three times a sabotage designed to prove a row **went green**, and each time the row that exists
now was written *because* of that:

* **C1** — respelling `ase::cap_report`'s refusal as `![ase::caps_is $c usable 1]`, the exact defect
  the vocabulary exists to prevent (issue 0953, **in the proc 0953 was filed against**), passed
  **all fourteen** rows of section P. P7 proved the two predicates *differ*; nothing proved the
  callers had picked the right one. **P15** is that row.
* **C3** — `ase::ui::chana_x_ok`'s membership guard was **unreachable in the row meant to prove
  it**: that proc returns early unless `anextra` exists, and only `chana_options` sets it — which
  the previous guard had just refused.
* **C5, row U2** — **four fixtures**, three of which looked fine and could not fail. Nothing
  registered (`resolved` empty, caught by the next line anyway); a program on the PATH but nothing
  cached under its key (the lookup misses either way); both, but the second entry registered *after*
  the warm — `ase::sim_register` calls `ase::sim_caps_clear`, so **registering emptied the very
  cache the row needed warm**.

⚠ **And one sabotage was itself malformed**, which is its own trap: deleting `set _sim` along with
the guard made the proc **raise** instead of writing, and the fixture's `catch` swallowed it. **A
sabotage that breaks the proc proves nothing, and it looks exactly like a sabotage correctly
refused.**

## THE DRIVER'S EXPECTATION WAS WRONG NINE TIMES AND THE CODE WAS RIGHT

Measure, then write the expectation — not the other way round.

P8 (two *reads* on one *line*, counted as lines) · AD2 (`>=0` written as a literal expectation) ·
G14f (the pane contents) · the stale-pane fixture (`session_update` does not repaint) · Q15 twice
(`analyses_available` ≠ `analysis_offered`; a type never *asked* about is `unknown`, not `absent`) ·
U6 (`{known 0}` and `{}` are different statements) · G14g twice (eleven cells, not four; and "nothing
is said" became "the cell explains itself") · V7 (`capabilities` matches `cap*` and writes the key
twice **by design**).

## FOUR DEFECTS THE DRIVER SHIPPED AND A ROW CAUGHT

1. A **`viewrank` on types that can never produce data** — `viewrank` is a claim about *results*.
   D7k went red; the row was right and the registry was wrong.
2. A **`#` comment block inside a `dict create` argument list** — in Tcl that is an **argument**. It
   silently shifted the dict, `op` lost its `emit`, and optier broke in five places.
3. A **two-key sort composed backwards**, so the rank was ignored entirely. It looked correct only
   because the four ranked entries happen to be declared in rank order.
4. **The probe skipped all seven new types**, because their token comes from the emit template and
   they have none — fixed with a `role probe` card rather than re-adding the `verb` key C41 deleted.

## THREE TCL TRAPS, EACH PAID FOR MORE THAN ONCE

* **Bare words do not go in `expr`.** `expr {$c ? OK : no}` is a syntax error that aborts the whole
  file, and **the only symptom is the check count going DOWN**. It cost three runs — sections L, Q
  and V.
* **Tcl counts braces inside comments.** An unbalanced one in a comment — even in backticks, even as
  the example of the character being discussed — left a `namespace eval` unclosed and **aborted
  xschem at startup** (issue 0663's arm).
* **A comment inside a command's argument list is an argument**, not a comment. Third occurrence in
  this batch; Stage 2e had it inside a `check` call.

## TWO SUITES HAD NO FLOOR PARAGRAPH AT ALL

`test_ase_simcaps_0948` and `test_ase_dialogs`. A suite that records no expected count leaves **no
trace** when a row is silently deleted — `ALL PASS` prints as happily over 80 checks as over 158.
Both have one now, and dialogs' is **two numbers**: 37 headless against 236 display reported as one
reads as a floor that fell by 199.

⚠ **`run_regression.tcl` runs `test_ase_dialogs` on NEITHER arm** — measured. A receipt quoting a T1
zero has **not** exercised one row of section G14 or GG. That is why C3's and C5's contract rows
live in `test_ase_core` instead.

## What is deferred, and what pins each deferral

* **The second Detect leg** (the no-circuit command-table oracle) — needs `-p`, and ⚖ R1 is answered
  Option A. **M15 stays open.** Its premise was also found false for ngspice: `help`'s answer is a
  compiled-in literal, so there is no external database to relocate.
* **`absent` is unreachable in the grid** until Stage 6 gives the seven an `emit` — the renderable
  test sits above the availability arms. The look debt says so, and the plan's
  four-states-in-one-screenshot **cannot be taken yet**.
* **The `--enable-rfspice` sentence is gone from the batch entirely.** Measured: `help sp` answers on
  all three binaries, so it names a build flag the probe cannot see and is unreachable here.

## Rulings

⚖ **R4 ships by construction** — `ase::state_default` is unmoved at four rows, so the recommended
answer required no decision and the other one costs one key per entry. ⚖ **R9** is on rule debts
**1401**, **1404**, **1408** and **1411**; the grid's pixels are on look debt
**chana_type_grid_1411**.
