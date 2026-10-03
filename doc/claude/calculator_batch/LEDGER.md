# LEDGER — calculator_batch

## ⚠ This file is a RECONSTRUCTION, written 2026-09-30, and says so on purpose

**It did not exist before today, and eight places cited it.** `git log --all --
doc/claude/calculator_batch/LEDGER.md` is empty: the file was never committed on any branch,
while `doc/claude/specs/calculator.md` cites it twice (W30 and §5's R113 amendment),
`src/calculator.tcl` cites it at two sites, `tests/headless/test_calc_widgets.tcl`'s header cites
it for "RULING-1/2/3", and two issue files plus `doc/claude/issues/status.md` cite it as the
batch's record of completion. So the batch ran for five receipts on a decision record that was
not there.

That is the same defect family CLAUDE.md names under its "do not write down a number nothing
re-checks" heading — *five shipped source comments cited rows that do not exist* — at document
scale, and it is worse than a rotted line number, because a reader is told a record exists and
goes looking for it.

**What saves the content is the fences.** The five rulings below are reconstructed from places
that are still checkable: the spec's own amendment notes, `receipts/01-phase1a.md` and
`receipts/04-phase1d-*.md`, and — decisively — **real test rows that assert each ruling's
substance** (`S22`, `S23`, `CW8`, `CW9`, and the `RULING-3` rows of
`tests/headless/test_calc_widgets.tcl`). Where a row asserts a ruling, the ruling is recovered,
not remembered. Where no row does, this file says so.

**Nothing here is presented as a verbatim original.** The wording is reconstructed; the substance
is sourced, and each row names its source.

---

## The rulings

| # | Whose | Date | Substance | Recovered from | Fenced by |
|---|---|---|---|---|---|
| **RULING-1** | user | 2026-08-15 | **One palette, not two.** The spec's original R113 — *"follow existing xschem dialog theming (`src/resources.tcl`); do not hand-set colors"* — was wrong twice: `resources.tcl` holds no theming at all, only base64 icons, and *"do not hand-set colors"* was read as *"leave everything default grey"*, which is what Phase 0 shipped and **the user rejected**. The prohibition survives only as *reuse the signal browser's palette variables rather than copying them*; it is no longer a prohibition on colouring. Fonts stay stock. | spec §5's amendment note, `receipts/01-phase1a.md` | `test_calc_skeleton` **S13** (every role resolves, each equal to the signal browser's own definition, and resolving is a pure read) and **S14** (the chrome actually wears it; none of it is still the stock grey) |
| **RULING-2** | user | 2026-08-15 | **The keypad is operators only — no digit keys.** Digits are typed into the buffer. This supersedes both the spec's old `7 8 9 / 4 5 6 * …` reading of W30 and the 4×4 digit pad in the reference screenshot. **RULING-2 fixed the principle and left the SET to the crew**, which chose the twelve operator tokens `+ - * / ** ? == != > < >= <=` on 2026-08-15 (phase 1d). | spec W30, `src/calculator.tcl` (`calc::pad_keys`), `receipts/04-phase1d-*.md` | `test_calc_skeleton` **S22** (*"no digit, decimal point or sign key"* — absence asserted positively) and `test_calc_widgets` **CW9** (the set is exactly the twelve tokens; *"NO keypad button carries a digit"*) |
| **RULING-3** | driver | 2026-08-15 | **No N-route functions in v1** (`dft`, `psd` and the rest deferred); v1 is pure Tcl. Every N-route and out-of-scope catalogue entry is **rendered and greyed, not absent**, and the **catalogue table is the single source** for the disabled state. A click on a greyed entry **refuses and names why** rather than being silently inert. | spec §12.2 (*"RULED 2026-08-15: no"*), `src/calculator.tcl` (`calc::fn_dead_routes`, `calc::fn_reason`) | `test_calc_skeleton` **S23** (exactly the N-route and out-of-scope entries are greyed; moving the dead-route set repaints the greying, proving the table *is* the source) and six `RULING-3` rows in `test_calc_widgets` (rendered **and** disabled, both halves; no live entry greyed with them; the dead set comes from the table's `route` field; a dead click refuses and names it) |
| **RULING-4** | driver | 2026-08-13 | **The Calculator is a toplevel**, not an in-viewer panel. Settled *by the build* — Phase 0 shipped `.calc` as a toplevel and nothing since has argued with it. | spec §12.1 (*"RULED 2026-08-13 by the build: toplevel"*) | `test_calc_skeleton` **S1** (`calc::open` builds `.calc`; a second call raises rather than duplicating) |
| **RULING-5** | driver | 2026-08-15 | **Both notations.** RPN stays the default and the only notation that reaches the engine; algebraic is a translation layer in front of it (§8.3, `calc::alg2rpn`, PLAN phase 8). | spec §12.3 (*"RULED 2026-08-15: both"*) | **nothing yet** — phase 8 is unwritten, so this ruling is recorded but unfenced. Stated here rather than left implicit. |

### ⚠ RULING-3, 4 and 5 were acted on before they were written down anywhere

`receipts/01-phase1a.md` records this in its own voice and it is the most useful paragraph in the
batch: the item brief told the crew that RULING-3/4/5 *"are already written into spec §12"*, citing
ledger rows that each claimed *"Already written into spec §12.2 / §12.3 / §12.1"*. The crew checked
— `git show HEAD:doc/claude/specs/calculator.md | grep -c RULED` → **0** — and found they were not
there. **That crew wrote them into §12 itself**, ~24 lines, and then asked the driver to correct the
three ledger rows that had misstated their status.

**The driver never did, because the ledger did not exist to correct.** The request sat in a receipt
for 29 days. This is why a batch's ledger is not optional bookkeeping: the one mechanism that would
have caught a false premise was the thing the false premise was recorded in.

---

## Receipts collected

| # | Stage | Receipt | Collected | Notes |
|---|---|---|---|---|
| 1 | Phase 0 — skeleton and dividers | `receipts/00-phase0-skeleton.md` | 2026-08-13 | + `00b-audit-baseline-2026-08-14.txt` |
| 2 | Phase 1a — colour, Results Dir, status | `receipts/01-phase1a.md`, `01-phase1a-colour-resultsdir-status.md` | 2026-08-15 | wrote spec R507–R509a and §12's three RULED lines; **flagged two stale PLAN rows the driver never fixed** |
| 3 | Phase 1b — selectors, mode strip, buffer, stack | `receipts/02-phase1b.md`, `02-phase1b-selectors-modestrip-buffer-stack.md` | 2026-08-15 | |
| 4 | Phase 1d — keypad and function browser | `receipts/04-phase1d-keypad-functions.md`, `04-phase1d-keypad-function-browser.md` | 2026-08-15 | chose RULING-2's twelve-token set; found W30 had called `?` binary when the engine consumes **three** operands for it |
| 5 | Phase 1e — widget inventory and sabotage map | `receipts/05-phase1e.md`, `05-phase1e-widget-inventory.md`, `05-phase1e-sabotage-map.md` | 2026-08-15 | |
| — | side items | `receipts/12-del-negative-arg.md`, `12-del-negative-arg-out-of-bounds.md`, `13-phase1-eyeball-punchlist.md`, `14-gui-gate-batch-panel-leak.md` | 2026-08-15 | |
| 6 | **Stage A — issue 1626, registration** | `receipts/A-register-1626.md` | 2026-09-30 | see below |
| 7 | **Stage A2 — the seven findings against the fence** | `receipts/A2-fence-fixes-1626.md` | 2026-09-30 | all seven fixed, and then **REFUTED** on verification — see below |
| 8 | **Stage A3 — close the blockers that refuted A2** | `receipts/A3-close-blockers-1626.md` | 2026-09-30 | cleared; issue 1626 closed, gated **116/115/0/8** at `deccdbd1` |
| 9 | **Stage B — PLAN phase 2, the buffer comes alive** | `receipts/B-buffer-alive.md` | 2026-09-30 | built; all three lenses **REFUTED** |
| 10 | **Stage B2 — the eleven findings against phase 2** | `receipts/B2-close-blockers.md` | 2026-09-30 | fixed; two of three lenses **REFUTED** again |
| 11 | **Stage B3 — final round, scope closed** | `receipts/B3-final.md` | 2026-10-01 | cleared at `REAL_BUT_MINOR`; **phase 2 gated 117/116/0/8 at `a0d56801`** |
| 12 | **Stage C — PLAN 3.1–3.2, Evaluate reads the number** | `receipts/C-evaluate.md` | 2026-10-01 | found `annot_p >= 0` misread as "a cursor exists", producing wrong numbers after an operating-point annotation |
| 13 | **Stage C2 — the blockers against Evaluate** | `receipts/C2-evaluate-blockers.md` | 2026-10-01 | cleared; **gated 120/119/0/8 at `47ea655a`** with `test_calc_engine` + `test_calc_scratch_reuse` |
| 14 | **Stage D — PLAN 3.3–3.4, Plot draws the curve** | `receipts/D-plot.md` | 2026-10-01 | found `Replace` silently appending in `multi` mode; acceptance asserts trace DATA read back, not a return code |
| 15 | **Stage D2 — the blockers against Plot** | `receipts/D2-plot-blockers.md` | 2026-10-01 | cleared; **vertical slice gated 121/120/0/8 at `08b860e1`** |
| 16 | **Stage E — issue 1628, the engine's `DIVIS` out-of-bounds read** | `receipts/E-engine-divis-1628.md` | 2026-10-01 | a C fix, not a Calculator change; valgrind witnessed *"8 bytes BEFORE a block of size 64"*; turned up issue **1629** |
| 17 | **Stage F — `cross` recon** | `receipts/F-cross-recon.md` | 2026-10-01 | five crews; **overturned landmine L2 for named `raw add`**, corrected PLAN 7.2's "exact", filed issues **1630/1631/1632** |
| 18 | **Stage F2/F3 — `cross` red-first suite + implementation** | `receipts/F2-cross-suite-and-implementation.md` | 2026-10-02 | four crews; **reversed the driver's own D10**, 12 false claims retired from one file, SR5 widened as a derivation; `test_calc_cross` 187 checks in `hcases` |
| 19 | **Stage G — `riseTime`/`delay`/`dutyCycle` recon** | `receipts/G-timing-verbs-recon.md` | 2026-10-02 | four crews; **refuted the driver's evaluate-once helper** (the scan is 27x a column read); user ruled R415 and R416 |
| 20 | **Stage G2/G3 — the timing verbs' suite + implementation** | `receipts/G2-timing-verbs-suite-and-implementation.md` | 2026-10-02 | five crews; **a NEW parse trap `info complete` cannot see**; a mutation that was a FALSE RED; `test_calc_measure` 125 checks in `hcases`; 16 sabotages, no holes |
| 21 | **Stage H — the destination for a non-scalar result: recon** | `receipts/H-destination-recon.md` | 2026-10-02 | six crews, two resumed for a second round; **nine driver claims refuted, one of them reproduced INSIDE the correcting contract**; user ruled R419 and R420; route A decided; filed issues **1633–1639** |
| 22 | **Stage H2/H3 — the wave destination: red-first suite + implementation** | `receipts/H-destination-impl.md` | 2026-10-02 | suite author + implementation crew, both resumed once; **eight more driver claims refuted**; a surviving sabotage closed on the driver's call; SR5 widened 53→54; `test_calc_wave_dest` **89 checks** in `hcases`; **15 of 15 sabotages fenced** |
| 23 | **Stage I — making a measurement verb clickable: recon** | `CLICK_CONTRACT.md` | 2026-10-02 | one crew; the `insert` field is **forbidden** to hold a template by two registered rows, so the dialog is an M not an S; user ruled **R421**; the greying is deliberate and fenced, but **the message is false** |
| 24 | **Stage I1 — issue 1639, `riseTime`'s unguarded raise** | `receipts/I1-1639.md` | 2026-10-03 | red first; `0`, `0.0` and `-0` raise **identically**, so the guard had to be value-based; the crew **overruled the driver's framing of the disposition** on the proc's own contract; and it found a fence that had **already rotted to 24-of-31 arms** while staying green |
| 25 | **Stage I2/I3 — the dialog's design, and a stall bound before the modal** | `receipts/I3-watchdog.md` | 2026-10-03 | two crews; a modal in `tkwait` would have turned a test *failure* into an unbounded **hang**; a third watchdog blind shape found (`update idletasks` never runs timers); a hand-rolled deadline **names the outcome wrongly**; zero trailer delta |
| 26 | **Stage I4 — the stall bound, fenced as a derivation** | `receipts/I4-fence.md` | 2026-10-03 | the row found **three registered T1 cases with no bound at all** and they were given one rather than the instrument narrowed; `update` had to join the verb list or the hole stayed two-thirds open; filed issue **1641** |
| 27 | **Stage I5/I7 — PLAN 5.4: the argument dialog** | `receipts/I7-dialog-impl.md` | 2026-10-03 | 61 rows red first, green on the FIRST attempt, no row weakened; **a sabotage passed all 61** and was fenced rather than declared; and **the switch-comment parse trap is PARITY-dependent**, which CLAUDE.md had stated as an absolute |
| 28 | **Stage J — wiring the destination to the verbs that still refuse: recon** | `WIRING_CONTRACT.md` + `receipts/J-wiring-recon-{sites,cost,contract}.md` | 2026-10-03 | three crews; **the driver's framing was wrong in all three clauses while the COUNT was right** — `riseTime` is a deferring caller that FOUR source comments omit, `frequency` is catalogued but unimplemented, and the X axis landed with PLAN 5.4 and never deferred; the real change site (`calc::fn_measure`, whose success arm pastes a list into the buffer with no numeric check) is **invisible to the derivation that got the rest right**; cost measured at **18 green rows**, so the stage is three units; and the CONSUMER half (`wviewer::plot_sweeps_arm`) has zero call sites too |

### ⚠⚠ Stage I — the parse trap this batch has been citing at everyone is PARITY-dependent

**The single most valuable finding of the batch, and it corrects the driver's own standing warning.**
Measured at one site in `calc::fn_argspec`, both directions: a two-line, **26-word** comment between
two `switch` patterns is a **complete no-op** (`ALL PASS (158 checks)`), while `# R415 applies` —
**three** words — turns **18 rows red at once**.

`switch`'s single trailing argument is parsed as a **Tcl list**, so every word of the comment becomes
an element. An **even** total re-pairs the list, every real pattern keeps its real body, and the
comment is swallowed as one harmless pattern/body pair. An **odd** total shifts the pairing by one
and Tcl raises out of every arm.

**The consequence is worse than "a comment there is fatal", not better.** Such a comment can sit
green for months and **detonate the moment somebody edits one word into or out of it** — and this
class keeps recurring precisely because the warning is written in the medium it warns about: CLAUDE.md
already records a literal `{` unbalancing a file *from inside the comment warning about it*, and this
batch's suite author hit a bare `}` twice, the second time **inside the comment warning about the
first**. **A green run proves only that the word count is even.**

### A sabotage that passed all 61 rows, and the same call made twice

Composing the verb's call **positionally** instead of by key passed **every row in all three
suites**. The cause is a declared hole meeting a coincidence: only `cross` is driven end-to-end, and
`cross`'s display order and formal order **coincide**. The verb whose orders diverge — `dutyCycle`,
whose `xaxis` is the **fifth** formal, not the third — is the one no behavioural row reaches, and the
failure is silent: it takes the axis where the cycle ordinal belongs and refuses naming a field the
user never touched.

The implementation crew **added two rows on the counted arm** rather than declaring the hole, plus a
non-vacuity control recording *why* the behavioural arm is blind. That is the second time this batch
the driver has ruled that **a sabotage which passes everything is a hole, not a pass**, and that a
published check count is not a baseline because every site carrying it recomputes it. Both times the
figure was re-derived rather than hand-edited.

### ⚠⚠ Stage H2/H3 — a surviving sabotage, and the driver overruling the crew that found it

**Fifteen sabotages, and the fifteenth survived the first implementation.** Hardcoding the sweep
column's name instead of reading it from the current database gives `ALL PASS` — because every row in
the band drives the `tran` fixture, where the name *is* `time`. Against an `ac` database it is
`frequency` and the hardcoded version is simply wrong. The crew **declared it rather than hiding it**,
and chose not to fix it on the grounds that a new row moves the published check count, which this
batch has repeatedly been burned by moving silently.

**The driver overruled that, and the reasoning is the point**: a fence that passes against its own
defect reads as coverage and is not, which outranks the cost of moving a number — and the number is
not a baseline at all. Every site carrying it (`OVERALL:`, `RESULT:`, and the both-arm
`banner_rule`/`summarize_all` capture) is an **instrument that recomputes it**, so the figure was
re-derived rather than preserved: **89 checks, identical on both arms, delta exactly +1 on each**, and
the registration delta unchanged. The crew's own note on its error is the sharpest line in the
receipt: it had **already measured** the live failure mode before deciding not to fence it.

Closing it also fenced the *placement*, which is better than the row alone. Two mutations of the
suite — dropping the restore so the `ac` database leaks into the next band, and moving the `ac` read
above the checks that resolve a name against the current database — each reddened **exactly one** row.
So the ordering is asserted rather than conventional.

### A row caught the implementation, and the implementation was right to yield to it

The crew's first approach reddened row **S27** of `test_calc_skeleton`, which exists to enforce
**ruling U6** — the Calculator must never evaluate against a raw a legacy path dropped into a
schematic window. The row's grep cannot distinguish *"resolve a result"* from *"remember which slot to
put back"*, so it fired on an innocent use. **The crew changed its code rather than the fence**, and
the replacement is independently better: one `xschem raw info` snapshot carrying name **and** type
together, both halves being necessary because the fixture's three slots share one path and differ only
by type. That is the second time this batch a crew has been caught by a registered row and been right
to treat the row as the authority.

### ⚠⚠ Stage H — the driver's own contract sprang the trap it was written to close

**The worst finding of this stage is a method failure, not a fact.** `DESTINATION_CONTRACT.md` was
written to correct false prose in the tree, and it **reproduced a dead claim inside itself**: that
spec §7.2 spells `cross` as `scalar/list`. The string appears **zero** times in
`doc/claude/specs/calculator.md` and `git log -S` finds it never did — the spec had already been
corrected, and what the driver read was a **stale source comment** above `calc::catalogue` asserting
a deliberate one-word disagreement that no longer existed.

That is CLAUDE.md's `grep -c '#pragma'` failure exactly — a correcting sentence becoming its own
counterexample — and it is recorded because this batch keeps citing that rule at other people. The
lesson: **a stale comment is not a weaker source than code, it is a more dangerous one.** It reads as
settled, nothing re-runs it, and a reader inherits it. Grep the claim.

Nine driver claims were refuted in all. Four of the sharper ones: `calc::fn_rows` **does not exist**
(the proc is `calc::catalogue`); the `nth = 0` deferral is in `calc::cross_scalar`, not `calc::cross`,
which never defers; `table_read()` is **not** destructive to the loaded result (two crews
independently measured its guard unreachable through any `raw` verb); and the driver's claim that
`raw_read()` escapes the float parser is true only of the **binary** path and the sweep column.

**And the verb count was wrong twice.** The tree said *"three verbs behind one missing piece"*; R419
falsified it; the driver corrected it to **two**; that was also wrong. It is **two destinations** —
three verbs behind the waveform one (`dutyCycle` default, **`delay` with `nth = 0`**, `frequency`) and
one behind the list one. `delay` was dropped by reading. A crew got it right by running awk over the
enclosing proc of every `listdefer` call site, which is the only method that has been right about
this number.

### The two rulings, and what each removed

**R419 — `cross nth = 0` is a plain list of crossing times.** *"Just a list of crossing times like
cadence does."* This **refuted a claim the driver had written as fact without ever asking** —
*"Cadence returns a waveform here"*, a parenthetical in `CROSS_CONTRACT.md` D8 that propagated into
the published spec and two source comments, and that inflated the dependency used to justify picking
this stage at all. Offered three shapes, the user chose the plain one and named the reference tool.

**R420 — `dutyCycle`'s X axis is an argument with a default**, defaulting to the time each cycle
started. *"Make it an option to the function… Other choices you gave can be supported with non
default values."* The driver had framed three legitimate X axes as a pick-one. **The parameter should
have been proposed, not the question asked** — when every candidate answer is defensible, the question
is not which one, it is what the default should be.

### The tension, and a hypothesis that died on its own premise

**Registered is required and registered is poison.** An unregistered slot draws nothing with no
message at all, legend entry still showing; but a registered route-A database immediately becomes
`results::current`, so the Calculator could evaluate against its own scratch output and serve a wrong
number. The driver hypothesised an odd `sim_type` would make it structurally invisible, and sent it
out **to be attacked**: it survived plottability (resolution is fully type-agnostic) and **died** on
the premise — `results::current` does not fall through to the user's result, it answers `{}`. So the
type is a fail-safe backstop worth one row, and the **restore is the primary defence** — and it needs
**two** explicit `raw switch <name> <type>` calls, because `raw clear` forces `extra_idx = 0` at
cleanup time and moves the user.

⚠⚠ **The fence for all of it would have passed vacuously.** With the user on slot 0, "after clear ==
capture?" answers YES and the hazard is invisible. **Fourth vacuous-row trap this batch has caught
before shipping**, each one found by asking what the row would do if the defect were present rather
than by checking that it passes.

**The evaluate-once helper was pointless and measurement said so.** The plan was a shared
*evaluate once, scan many* seam so a verb needing two levels would not evaluate twice. On a
100 000-point column: `raw add` + `raw del` is **0.21 ms**, one bulk column read is **10.3 ms**, and
**one `nth = 0` scan is 296 ms** — the scan is **27×** a read. Hoisting the evaluation saves ~20 ms of
~300; on the committed fixture the whole question is 191 µs against 106 µs. The helper was optimising
the cheap half. And the simple shape is *correct*, established four ways (92 combinations
bit-identical, the engine deterministic across array growth, 340 churn cycles with nothing leaked,
two evaluations giving bit-identical X columns) — while **six of ten sharing shapes redden row SR5**.
All three verbs ship as pure delegates, and SR5 stayed green with **no edit**.

**That is the SECOND performance intuition this batch has had refuted**, after D10, where the faster
per-point read turned out to print `%.8g` and could not meet the fixture's own 1e-12 tolerance. The
rule: *a performance number is not a reason on its own, and the shape you were about to optimise may
not be where the time is.*

⚠⚠ **And the second ruling-versus-table disagreement, this one the driver's own.** Spec §7.2's
`dutyCycle` row said `scalar` while **R416, written by the driver minutes earlier in the same file**,
rules it returns a wave. The table contradicted the ruling beside it from the moment the ruling
existed; the implementation crew found it. The first instance was `cross`, where §7.2 said
`scalar/list` against a catalogue of `scalar/wave` and S24's closed vocabulary. **Writing a ruling
obliges re-reading every table in the same section** — and neither time did any suite catch it,
because a table cell is prose.

### ⚠⚠ Stage G2 — a parse failure `info complete` cannot see

A four-line comment placed **between two `switch` patterns** in `calc::cross_msg` left the braces
perfectly balanced, `info complete` answering **1**, and Tcl raising *"extra switch pattern with no
body, this may be due to a comment incorrectly placed outside of a switch body"* out of **every
sentence in the catalogue** — **34 rows red at once**, three of them `cross`'s.

**The batch's standing brace-balance check is therefore insufficient**, which matters because that
check was adopted precisely to catch comment-shaped parse damage. A comment is safe above a proc and
fatal between two `switch` arms, and nothing structural tells them apart. The driver's independent
confirmation was behavioural, not textual: exercise every message kind and see that none raises
(23 kinds, `ok=23 raised=0`). **A comment moved inside a `switch` needs a row or a run, never a brace
count.**

**The most valuable single finding of the stage was a mutation that had been a FALSE RED.** A
legitimate conforming shared helper was *failing* the delegate rule, so the suite was over-constraining
the driver's own T1 decision and would have pushed the implementer into a worse shape to satisfy a row.
A row that is too strict looks exactly like a row that works, which is why it took a mutation pass to
see.

⚠ **Rows 12–16 were collected onto this ledger on 2026-10-01, days after their receipts were
written** — the stages shipped, were gated and were pushed, and the ledger table was simply never
updated. The batch's own operating model says the driver *"collects that receipt onto the
`LEDGER.md` and commits"*, and for five consecutive stages that last step was skipped while the
code went out. Nothing was lost (every receipt exists under `receipts/`), but the ledger stopped
being an answer to *"how many receipts have been collected?"* — which is the exact question the
user has asked about this batch before. Recorded rather than quietly backfilled.

### Stage F — `cross` recon, and the three documents it falsified

**`cross` is being built ahead of phases 4–6, at the user's request** (*"Implement cross"*,
2026-10-01). It is PLAN 7.1 + 7.2, and the spec's own implementation order makes it the keystone:
*"P, then C, then T-on-`cross`, then the rest"*, with `riseTime` `slewRate` `delay` `dutyCycle`
`frequency` `settlingTime` `overshoot` all layered on it.

**The `nth` semantics came from the user, not from us.** They supplied that a negative `nth`
counts back from the end — `-1` the last crossing, `-2` the second-to-last. The driver had the
right recollection and had talked itself most of the way out of it with two arguments from
analogy, both worthless: that SKILL has no negative-index idiom (wrong analogy — `nth` is an
ordinal selector over a derived set, not a list index), and that practitioners get the last
crossing via `nth = 0` and take the tail (evidence about habit, not capability). A research sweep
was running when the user answered it in one line. **The lesson recorded:** on a question of fact
about Cadence behaviour, ask the user — they use the tool professionally, the official docs are
behind a login, and a ruling is a different thing from a fact.

**What recon falsified, each of which would have become a defect:**

1. **Landmine L2 does not apply to a named `xschem raw add`.** Named columns are persistent and
   independent; `raw_add_vector()` grows the arrays so the *old* scratch slot becomes the new named
   column. The `values[nvars]` default is taken only when `yname == NULL`, at twelve `src/draw.c`
   sites and nowhere else — `/usr/bin/grep -c 'plot_raw_custom_data' src/scheduler.c` is **0**. So
   L2 is a true statement about graph custom-wave expressions and **not** a statement about the
   Tcl verb. `cross` carries no re-evaluate-before-reading rule, and R402's delete is leak hygiene
   rather than a staleness remedy. *The driver's own `CROSS_CONTRACT.md` §3 had asserted the
   opposite, as a pending question it expected to resolve the other way.*
2. **PLAN row 7.2's done-when said "exact"** and the fixture README says *"Use a tolerance, not
   equality"*. Corrected before a crew was handed the row — which is the whole argument for recon
   preceding authoring.
3. **`xschem raw add` never returns −1**, so spec §3.1's documented failure value cannot reach a
   Tcl caller; a bad expression on a fresh name answers **1** and leaves an all-zeros column. The
   tree already knew: `calc::eval_rpn`'s header says so, and recon confirmed that comment
   independently.
4. **D6 as first written was not strong enough.** An `±inf` endpoint *passes* the rising predicate
   (`-inf < L && 0.6 >= L` is true), so a finiteness filter applied to what the predicate rejects
   admits a phantom crossing on every infinite sample. The gate must run **first**. And the
   interpolation arithmetic *raises* on nan/inf — so an unguarded `cross` would **throw rather
   than refuse**, aborting a whole suite at the file-scope catch.

**Two rows would have passed by luck**, which is the kind of finding that only arrives from
measuring the fixture rather than reasoning about the feature: `rising nth=-1` on `v(sq)` equals
`either nth=-1`, because the last crossing overall happens to be rising, so a broken direction
filter survives — fixed with the inverted square `1 v(sq) -`. And R414d's interpolation is
unfenceable at level 0.5, where the crossings sit exactly on samples.

**Three defects filed, none fixed:** issue **1630** (`wviewer::interp_value` reports another
dataset's value at and past the end of the sweep — 2.5 V where the truth is 5 V, on a cursor
readout), **1631** (`raw pos_at` advertises a crossing finder and is a monotonic bisection; 42 % of
windows containing a crossing answer `-1` on an oscillating trace), **1632** (`raw values` reads
`npoints` out of bounds for an out-of-range dataset; valgrind-confirmed, and the garbage became a
loop bound — 1.1 GB of log in 3m35s).

### ⚠ Stage F2 — the driver's own D10 was reversed by an adversarial lens, and the test row was selecting for abandoning it silently

The driver decided (`CROSS_CONTRACT.md` D10) that `cross` would scan **per point** rather than read
the column in bulk, so that R414c's bidirectional early exit would save real work: recon measured
0.11 ms against 15 ms on a 100 000-point trace. **The decision was made on half the data.**

`xschem raw value` returns `dtoa(val)`, and `dtoa()` is `my_snprintf(s, S(s), "%.8g", i)`, while the
`values` arm formats `"%.16g"`. So the fast door loses eight significant digits —
`time[9]` is `0.0009000000000000002` in bulk and `0.0009` per point — and a crossing interpolated
from `%.8g` samples carries ~1e-8 relative error against the fixture README's documented **1e-12**
tolerance for `time`. **The cheaper route cannot produce an answer good enough to assert.** D10 is
reversed: bulk always, one read path. 15 ms behind a button press is invisible, and `cross` is only
ever called from behind a button press.

**The generalisable lesson, recorded in the contract next to the reversal:** recon measured speed
because speed was the question the driver asked. Nobody asked what the fast door's *precision* was.
**A performance number is not a reason on its own — the cheaper route has to be shown adequate
first.**

⚠⚠ **And the way it would have gone wrong is the part worth keeping.** A test row compared the
`nth = 0` answer against the `nth = 1` answer with string identity, which under two read paths
could never hold. An implementation that quietly used bulk for everything turned that row **green,
with nothing else in the suite noticing D10 had been discarded.** So the row was selecting for the
silent abandonment of a written decision. Reversing it deliberately is the honest version of the
same outcome — and the pattern to watch for is a row whose only way to pass is for the
implementation to ignore the spec.

### ⚠ The same precision defect then bit INSIDE the suite, and a header fix landed in one of two places

The repaired suite's bit-inequality legs compared bulk-derived answers against `xschem raw value`
comparands — the same `%.16g` against `%.8g` mismatch, one level down. Four legs were structurally
dead: **no value derived from the bulk column can ever be string-equal to a `%.8g` comparand**, so
they read the same for a snapping implementation as for an interpolating one, while the row's name
asserted six discriminating inequalities where there were zero. One sibling row survived only
because `0.001` happens to round-trip through `%.8g`.

Separately, the correction to the header's "three procs" claim landed at line 47 and **not** at line
221 — **this batch's signature failure reappearing inside the change that fixed it, for the fifth
time** — and line 221 is the copy an implementer actually reads when changing the representation.
A count in the same header ("18 remaining rows") drifted to 22 inside the change that quoted it,
which is the house rule against writing down a number nothing re-checks, failing in a comment again.

**What the two suite rounds did deliver**, and it is why they were worth the wall-clock: 40 mutants
of a conforming reference, each asserted present and `info complete`, with **zero** aborts across
all 40 runs. `sweep_as_index0` reddens exactly the two rows written for it; `nth_by_spelling` exactly
the two integer-valued rows; `per_point_mixed_old_D10` exactly the one D10 fence. Two mutations
reddened **nothing** — an empty absence message and a lowercase refusal — and both were named as
holes rather than papered over.

⚠ **The driver wrote issue files and `NUMBERING.md` while a recon crew was live, and the crew's
tree-state report flagged it unprompted.** No measurement was affected, because no crew reads
those files. But the rule as recorded at Stage A was *"while a crew holds the tree, the driver
edits only files no crew measurement reads"*, and the refinement is that **`git status` is itself
something a crew reads**. Either tell crews up front which files the driver is touching, or expect
the flag and reconcile it. Expecting the flag is cheaper, and the flag firing is the fence working.

### PLAN phase 2 is DONE and gated — `a0d56801`, baseline `3e94bbee`

The twelve operator keys insert at the caret, `ClrBuf` clears, `Undo`/`Redo` are live.
`tests/headless/test_calc_buffer.tcl`, **121 checks**, `dcases`. 48 rows written red first,
16 sabotages, three adversarial rounds.

**Two real defects, both found by a lens and neither of them prose:**

* **The separator's first implementation used Tcl's `string is space`**, a strict superset of the
  engine's `" \t\n"` — 29 characters in the BMP, 26 of them not delimiters. So a pasted CR
  suppressed the separator, `plot_raw_custom_data()` saw one fused token, and the whole expression
  returned `-1` phases later with no trace. **The proc implementing the separator rule
  reintroduced the exact failure the rule exists to prevent.** A row now reads the delimiter
  literal out of `src/save.c`, so the two cannot drift.
* **All nine new procs guarded with a bare `winfo exists`**, which *throws* under `--nogui` where
  that command does not exist — R508's own third case, a contract `calc::status` already honoured
  and `test_calc_skeleton` row S13 already fenced. A regression against the tree's own rule.
  `calc::has_win` is now the single site that knows it, and `calc::status` routes through it too.

**And the driver's own near-miss, recorded because the method is the lesson.** Acting on a lens
note, the driver changed `calc::buf_typed` to set `fbredo 0`, which turned a passing row red. Rather
than adjust either side, the driver **measured a bare Tk 8.6.17 text widget**: `canredo` goes 1
after an undo and back to **0** after any new edit. So a real edit clears the redo stack, the 8.6
branch reports Redo *disabled* after typing, and the fallback answering `normal` was not a
conservative over-answer but a **contradiction of the branch it approximates** — and a disagreement
with `calc::buf_note_edit`, which had always set it to 0. The change was right and the row had
encoded the bug; the row is now re-keyed to assert that **the two branches agree**, so it cannot
drift from the behaviour it stands in for.

**One limit declared rather than fixed, with its measurement**: the Tk 8.5 fallback can
*under-answer* when an edit leaves the buffer text byte-identical (delete-then-retype), because
`buf_typed`'s discriminator is "did the text change". `edit modified` is the instrument. Not wired
at the close of a phase: `calc::color` uses `dict` (8.5+) and sits on every widget's path, so this
file cannot run on Tcl 8.4 at all and the blast radius is one Tk minor version, while the 8.6 branch
reads the real stack and never consults these hints. The comment that claimed the hints "never"
under-answer is corrected rather than left standing.

**Carried for a later stage, found in passing and deliberately not fixed:** `calc::status_recall`
and `calc::dest_changed` — both phase-1 procs — still carry a bare `winfo exists` and would raise
under R508's third case. Neither is reachable without a window today.

### ⚠ Stage A2 fixed all seven findings and was then REFUTED, for reproducing inside its own file the defect it was convened to remove

Its regression lens returned `REAL_BUT_MINOR`; its **claims** lens returned **`REFUTED`** with three
blocking findings. The first is the one worth carrying:

**A2's finding F1 existed because Stage A shipped a comment contradicting Stage A's own receipt** —
it claimed that *reordering* the `RESULT:` line would blank the published check count, where §6(c) of
the same receipt had measured that reordering changes nothing in any of the three readers. A2 fixed
that sentence in `test_calc_skeleton.tcl` and `test_calc_widgets.tcl` — **and left it standing in the
fence suite it was editing**, where it also cited `wvbs_finish` as its authority. `wvbs_finish`'s
comment says, in as many words, *"THE ORDER OF THE TWO LINES IS NOT load-bearing and this comment
does not claim it is."* The citation pointed at its own refutation.

The other two blockers were the same species. **`RB6`'s name** claimed that no registered headless
arm could be scored a `HARNESS` failure with all its checks passing — false three ways, because
`regression_case_failed` is `childcode != 0 OR !banner_complete OR banner_died` and `RB6` touches
only the middle arm, which limit `L6` in the same file already said. And **`test_calc_widgets`'
comment contradicted itself nine lines apart**, disclaiming that it quoted a count and then quoting
this suite's own moving check total.

**The lesson is not "A2 was careless".** Three independent stages, each specifically tasked with
auditing the previous one's claims, each shipped at least one sentence that overstated its code. The
defect is structural: **a prose claim is the one artefact in this tree that nothing re-runs**, so it
is the only place an error can survive a green suite, a sabotage round and an adversarial lens. That
is why CLAUDE.md's rule is *either a row asserts it or the sentence drops it* — and why A3's receipt
was required to walk every remaining sentence, row name and limit and say how each was checked,
which is the step A2 omitted.

**The driver's standing decision, recorded here because it bounds the work:** A3 is the last fence
round. If its verification still refutes, the fence suite is dropped from the commit and the
registration plus the sentinel ship alone — that is the actual fix for issue 1626, every lens has
found it clean, and T1's own `HARNESS:` line remains the backstop the fence was only ever trying to
pre-empt. The fence addresses one of `regression_case_failed`'s three arms, so even perfected it
fences about a third of *"can T1 score this"*, and that ceiling is what makes dropping it cheap.

### Stage A3, collected — and the claims lens that refuted A2 cleared it

A3 closed all three blockers, the one real logic defect and the five declarative corrections. Its
re-run claims lens returned **`REAL_BUT_MINOR`** with an explicit *"commit Stage A3"*, having
verified the three blockers were **gone rather than moved** — it re-read `wvbs_finish` to confirm the
corrected citation, re-derived the reader spellings (`summarize_all`'s `^RESULT:` and `^skip:` arms,
`run_suites.sh`'s `grep -E '^RESULT' | tail -1`), and confirmed no check-count figure survives in any
of the three test files.

**The one real logic defect A3 fixed** was the fence reintroducing, inside the row added to cure
arm-blindness, the exact gap the rest of the file exists to close: `rb_nogui_dead` scanned the gate
body's own text without following proc calls or the source chain. The regression lens proved it the
only way that counts — it mirrored `tests/` into scratch, refactored a real in-tree suite's no-X gate
to call a one-line helper, **ran it for real** to confirm the banner is printed, and watched the
detector flag it anyway. A3 widened it to use the same machinery as the whole-file question and
re-measured over all 96 registered entries before and after: identical, 2 flagged, 0 in `hcases`.

**Five residual findings the driver closed itself**, rather than spending a fourth round on text
edits — three of them claim defects of exactly the species that refuted A2:

* **`RB5` was a live false red.** Its own stripper dropped whole-line comments only, while
  `rb_decomment` exists in the same file because, in its words, *"a complete puts statement parked in
  a tail comment is read as code by any line scanner"*. Appending
  `set z 1 ;# regexp -line {^OVERALL: ok} $body` turned the row **red on a comment**, in the file
  whose whole subject is that a false red becomes a standing red in T1. Now uses `rb_code`. Verified
  both directions: with the poison appended the old stripper answers 1 and the new 0; unmodified,
  both answer 0.
* **`test_calc_skeleton`'s comment stated a counterfactual in the indicative past** — *"this suite in
  `dcases` **was scored** `HARNESS: …`"* — when the suite had been in **neither** list, so no T1 run
  ever scored it; the figure is derived, where issue 1615's was a real `counted_failures=1` gate. The
  sibling suite had worded the identical fact conditionally and correctly all along.
* **Two limits run in the REJECTING direction and the header implied none did.** `L2`'s
  sourced-variable case and `L4`'s continuation case report a suite that *really prints* an acceptable
  line as having no emitter — the one direction that reddens T1, in a file whose framing says that
  cannot happen. Both are now signed, and `L4`'s word "missed" replaced: it does not fail to notice a
  defect, it manufactures one.
* **`RB6`'s name said "reachable"** where the method answers **presence**; three measured gate shapes
  answer not-dead and so go unflagged. Renamed to what it does, with the misses named.
* **Two rotted bare `file:line` citations**, pre-existing, nine lines from an A3 edit, in a stage that
  believed it had grepped every digit in every comment of that file: `full_audit.sh`'s `is_skip` cited
  as `:237` when `is_pass` is at 227 and `is_skip` at 287 — the number named neither — and a `puts`
  cited at `:100` that is at 114. Both now cited by **symbol**, which is why CLAUDE.md's rule exists.

**Green after the driver's edits**, both arms, counts unmoved: fence `ALL PASS (10 checks)` on each
arm; `test_calc_skeleton` 545 display / 0 headless; `test_calc_widgets` 244 display / self-skip
headless; and the neighbours that read `run_regression.tcl` or scan the tree —
`test_audit_classifier` 75, `test_scratch_home_note` 22, `test_issue_stamp` 102.

### Stage A, collected

**What it did.** Registered `test_calc_skeleton` and `test_calc_widgets` in `dcases`, added the
`OVERALL: ok ($npass checks)` sentinel to both additively with `RESULT:` kept last and on the
success path only, and built `tests/headless/test_registered_banner_1626.tcl` (`hcases`) — a fence
that lifts both registration lists from `run_regression.tcl`'s own text, resolves each suite's
`source` chain and one level of variable assignment, and asks whether a
`banner_complete`-acceptable line is reachable. Issue **1626**.

**Red, genuinely red.** The crew registered *first* and wrote the fence *second*, so `RB2` failed on
an unfixed tree naming exactly `{headless/test_calc_skeleton headless/test_calc_widgets}`. The
driver's premise was re-measured rather than taken on trust: `banner_complete` = 0 on all four real
captures.

**Check counts unchanged** — the change is additive, and the line above them is what moved.

### ⚠ Three things Stage A corrected in the driver's own brief and issue

1. **The driver wrote that the sentinel-less registered suites "get it from a sourced common". That
   was wrong about the number and about the mechanism.** Measured over every registered entry,
   ignoring comments: **16** emit no literal sentinel, by **three** mechanisms — **13** compute it
   (`puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"`, all `test_ase_*`), **3** build it into a
   variable and `puts $var` (the bare-name `hilight_*` entries in `tests/`), and **1** uses a sourced
   common. The famous mechanism, the one issue 1615 made its name on, is **one suite in sixteen**.
   The driver's `7` came from a grep that counted the sentinel inside *comments* as present, over a
   glob that excluded the four bare-name entries.
2. **A fence handling only the literal case would have put a STANDING RED in T1.** The crew's first
   prototype did, on three real suites, and its own control battery caught it before the gate could.
   That is the thing CLAUDE.md says a fence must never become, and it was two edits away.
3. **`RB4`'s first definition was trivially true and therefore worthless** — it reported 94 false
   reds out of 95, a number so large it measured nothing. Re-defining "naive" as the *plausible*
   wrong implementation brought it to 14, which is the figure that justifies the predicate existing.

### ⚠ The driver edited the tree underneath the crew, and the crew caught it

Stage A's receipt §9 reports `src/calculator.tcl` modified at **19:19:52**, between the crew's own
`tests/run_regression.tcl` edit and its last restore, and says plainly: *"something else was writing
this tree during my stage… It is not mine and I did not touch it."* It was the driver, retiring a
dead `recon/` pointer in a comment block.

**It was harmless and that was luck, not method.** `src/calculator.tcl` is the file both calculator
suites `source`, so it is an input to every measurement the stage made. The edit happened to be
comment-only, and the crew proved the consequence was nil — its before-captures pre-date the edit,
its after-captures post-date it, and both report the same check counts — but a one-line change to a
`proc` would have silently invalidated a before/after comparison that looks identical either way.

Two things follow, and they are the driver's, not the crew's. **While a crew holds the tree, the
driver edits only files no crew measurement reads** — docs, plans, issue files — and never `src/` or
`tests/`. And **a receipt that reports `git status` and names which entries are not its own is what
made this visible at all**: the brief asks for `git status --short` precisely so that *"I did not
intend to write anything"* and *"nothing was written"* stay distinguishable, and here it caught the
driver rather than the crew.

### Adversarial verification of Stage A — three lenses, all `REAL_BUT_MINOR`, none refuted

**And the panel earned its keep by CONVERGING.** Two of the three lenses independently found the
same defect, from different directions, and the third found its mirror image — which is the result
that justifies running independent lenses rather than one longer review:

* **`RB2` is arm-blind.** It unions `hcases` and `dcases` and asks only whether a suite's *text*
  could ever emit the sentinel. Both calculator suites take a no-banner early exit on their headless
  arm, so **adding either to `hcases` as well would leave the fence green while T1 scored it a
  `HARNESS` failure** — the 1615/1626 incident repeated, with the new fence silent. One lens proved
  it by doing exactly that.
* **The mirror image: nothing asserted the suites ARE registered.** A lens deleted both `dcases`
  entries in a scratch copy of `tests/` and the fence still reported `ALL PASS`. So issue 1626's
  *headline* defect could recur silently. The tree already had the precedent — row `V57` of
  `test_op_annot` asserts its own entries are in the lists by name.
* So **receipt §10.1's claim that "issue 1626's open item 2 is now closed" was wider than the
  fence**, in both directions at once. The driver did not re-stamp the issue on it.

Five smaller findings, all with the same character — a fence that is about to gate, where a false
red becomes a standing red in T1:

* **`RB2` false-redded two idiomatic spellings T1 scores fine** — `puts [format "OVERALL: ok (%d
  checks)" $n]`, and a banner built with `append` rather than `set`. Two lenses *ran* both fixtures
  and confirmed each really prints an acceptable line. Nothing is red today because no registered
  suite is spelled either way; the next crew that writes one would have inherited a standing red.
* **A shipped comment contradicted the shipped receipt.** The new verdict-block comment in
  `test_calc_skeleton` said removing *or reordering* the `RESULT:` line would blank the check count;
  §6(c) of the same stage's receipt had measured that reordering changes nothing in any reader.
* **`RB4` was keyed to the continued existence of the imperfection it documents** (it asserted the
  naive-scan false-red set is non-empty), so an unrelated improvement to those 14 suites would have
  turned it red with nothing wrong.
* **`rb_suite_path` resolved a `headless/*` entry with `[file tail]`**, so a nested entry would be
  scored against a different file than the driver runs. Unreachable today; a silent wrong answer
  rather than a declared limit, and the fix removes code.
* **`RB2`'s name said "a stdout puts" while the predicate also accepts `puts stderr`.** The
  behaviour is right — T1 execs every arm with `2>@1` — but a row name must describe its method.

All seven went to **Stage A2** rather than being waved through, receipt
`receipts/A2-fence-fixes-1626.md`.

### ⚠ And a sabotage aimed at something else found a real, unfenced defect

Breaking the `RESULT:`-last **ordering** reddened nothing, correctly: all three readers are
order-independent, so the rule's real content is *be the last `RESULT:` line*. Measuring **that**
instead found that one extra trailing `RESULT: ALL PASS (0 checks)` takes a case's published check
count from 244 to **0**, with `counted_failures` and `skips` both staying honest at 0 and nothing
reddening in any reader. It defeats issue **1487**'s coverage instrument without disturbing either
number CLAUDE.md teaches a reader to check. Filed as issue **1627**; deliberately not fixed here.

**Phase 1c has no receipt.** Numbering runs 00, 01, 02, 04, 05 — there is no `03-`. Either a step
landed without one or the numbering simply skipped; nothing in the tree says which, and this row
exists so the gap is not read as a lost file.

---

## Open, carried by the driver

1. **`PLAN.md` rows 120 and 135 still describe a digit pad RULING-2 removed.** Row 1.7 says
   *"16 keys + 4 user buttons"* (it is 12 + 4) and row 2.2's acceptance is *"`7` then `.` then `5`
   gives `7.5`"*, which is **unreachable**: there is no `7` key, no `5` key and no `.` key, and spec
   W30 records that `.` is not even lexable alone — `strtod(".")` fails, so §3.1 looks it up as a
   vector name and the whole expression returns `-1`. `receipts/01-phase1a.md` flagged both rows on
   2026-08-15, naming them as *"not mine to edit"*. They are the driver's, and they are still wrong.
2. **The `recon/` directory does not exist and never did** — `git log --all --
   doc/claude/calculator_batch/recon/` is empty — yet **three** places cite documents inside it:
   `doc/claude/specs/calculator.md` §5 (`recon/theming.md` §3), `src/calculator.tcl` near
   `calc::catalogue` (`recon/catalogue_defects.md`), and
   `doc/claude/issues/0325-del-with-a-negative-delay-reads-past-the-end-of-the-window.md`. Unlike
   the rulings above, **no fence recovers their content**, so there is nothing to reconstruct — only
   citations to retire. The spec's was retired on 2026-09-30, keeping its (independently checkable)
   claim and dropping the pointer. `src/calculator.tcl`'s is **still live** and belongs to whoever
   next edits that file. Issue 0325's is left alone: an issue file is a dated record, and editing one
   to agree with today falsifies it.
3. **Spec `R510` was defined twice** until 2026-09-30 — §8.1's status-dropdown rendering clause and
   §8.2's binary-operator stack rule — so `PLAN.md` row 4.3's *"RPN operator composition
   (R510–R512)"* pointed at a combobox popdown. The §8.1 clause moved to **R509a**, chosen because
   it had **zero** citations outside `receipts/01-phase1a*.md` while §8.2's `R510` had seven in
   `src/calculator.tcl`, `test_calc_skeleton.tcl` and `PLAN.md`. A row asserting that no requirement
   number in a spec is defined twice would close the class; none exists yet.
4. **RULING-5 (both notations) is unfenced** until phase 8.
5. **`test_audit_classifier` is in neither `hcases` nor `dcases`**, found by Stage A. Section K of
   that suite is the tree's only lock holding the three banner readers in agreement — so the fence
   over the rule issue 1626 is about **gates nothing itself**. Carried as open item 2 of issue
   **1627** rather than left in the general unregistered tail, because of what it fences.
6. **Issue 1627** — a second trailing `RESULT:` line silently rewrites a case's published check
   count. Found by Stage A's sabotage round. Not a calculator defect, but the batch's later phases
   add suites with multiple exit paths, which is exactly how it arrives.

7. **Three defects Stage F filed and nothing fixes yet.** Issue **1630** is the one with a
   user-visible wrong number — `wviewer::interp_value` reports another dataset's value at and past
   the end of the sweep, 2.5 V where the truth is 5 V on a cursor readout, so it wants doing on its
   own account rather than as a by-product. Issue **1631** is documentation (`raw pos_at`'s help
   promises a crossing finder) and is cheap: one sentence saying the search assumes a monotone
   column. Issue **1632** is memory safety plus a runaway loop and should not wait long. **`cross`
   steers clear of all three without depending on any of them being fixed** — it validates its
   dataset against `xschem raw datasets`, never reads `allpoints`, and never touches `pos_at`.
8. ~~**`calc::catalogue`'s `cross` row says `scalar` where the spec says `scalar/list`.**~~
   **CLOSED 2026-10-02, and the driver's half of it was the wrong half.** The catalogue row now says
   `scalar/wave`. `scalar/list` was the *driver's own* uncommitted spec edit and was unshippable:
   row **S24** of `test_calc_skeleton` (a registered `dcases` case) holds `returns` to the closed
   vocabulary `{scalar wave bool scalar/wave}`, so `scalar/list` is a **counted failure** there —
   measured by the implementation crew lifting S24's own predicate and running it over a mutated
   catalogue, which answered `cross=returnsscalar/list`. The crew shipped `scalar/wave`, flagged the
   conflict rather than silently respelling the spec, and said plainly that the spec side was not in
   its permitted edit set. The driver then fixed §7.2. **`scalar/wave` is also the more faithful
   word, not a compromise**: `intersect`, `frequency` and `freq` already use it for exactly this
   shape, and the contract's own D8 records that the reference tool returns a *waveform* for
   `nth = 0`. The Tcl proc returns a Tcl list; the user-facing type is a wave. Those are different
   statements and only the second belongs in a `returns` column.
9. **Two false prose claims, both owed by the `cross` commit** rather than filed, because they sit
   in files it edits: `calc::eval_finite`'s header says `expr {$v == $v}` raises on a NaN operand
   in Tcl 8.5+, and on 8.6.17 it returns `0` quietly (the proc's *conclusion* is still right — be
   textual, not arithmetic — only its stated mechanism is wrong); and spec §3.1's *"the whole
   evaluation returns `-1`"* is true of the C engine and false of `xschem raw add`, which discards
   it. **This is the batch's recurring failure mode and the reason both are written down here**: a
   prose claim is the one artefact nothing re-runs, so it is the only place an error survives a
   green suite, a sabotage round and an adversarial lens.

## The progress bar

`/usr/bin/grep -n 'calc::inert' src/calculator.tcl` lists every control still inert **and the phase
that owns it**. That grep is the batch's real progress indicator, and it is checkable, which is why
no count of it is written here.
