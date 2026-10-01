# Receipt D2-plot-blockers — Stage D's blocking items F1–F7

Stage label `D2-plot-blockers`. Branch `fluid-editing`, tree at `69cbf9b5`, **nothing
committed, pushed or stashed**. All scratch under `…/scratchpad/D2/`. Scope was closed to
the seven items handed over; nothing else was built.

⚠⚠ **F1 WAS REAL, REPRODUCED AGAINST A REAL VIEWER, AND THE CAUSE IS ONE SENTENCE OF SPEC
NOBODY HAD READ ON THIS PATH**: `wviewer::add_trace`'s single-name arm asks **two**
questions, not one, and the Calculator's pre-flight asked only the first. §1.

⚠⚠ **AND THE SABOTAGE ROUND FOUND A DEAD FENCE IN STAGE D'S OWN WORK: `P6` — "no context
loan at all" — reddened ZERO where its receipt records 15, and the mechanism is that
`wviewer::open` leaves the xschem context standing IN the viewer, so the loan is redundant
on every path the suite drives.** §10. That is the specific thing the task said to look
for, and it was there. The fence is repaired and `P6` reddens 1 again.

⚠ **The claim audit (§9) refuted a FIFTH false comment Stage D shipped, which the handover
did not list** — `calc::eval_click`'s "`%<n>` reads as a SILENT ZERO … NOT FIXED HERE:
naming the failing token is R607/PLAN 3.4's job", written in the same change that landed
3.4 and that restated band CE12 for the closure.

---

## 0. The verdicts, both arms

| suite | `--nogui` | display (`:99`) | Stage D left it at |
|---|---|---|---|
| **`test_calc_plot`** (`dcases`) | `SKIP (self-skipped: no X — nothing ran)` | **`ALL PASS (105 checks)`** | 67 |
| **`test_calc_engine`** (`hcases`) | **`ALL PASS (265 checks)`** | `ALL PASS (265 checks)` | 253 |
| `test_calc_scratch_reuse` (`hcases`) | `ALL PASS (51 checks)` | `ALL PASS (51 checks)` | 51 |
| `test_calc_skeleton` (`dcases`) | `ALL PASS (0 checks)` | `ALL PASS (548 checks)` | 548 |
| `test_calc_widgets` (`dcases`) | `SKIP (self-skipped: no X)` | `ALL PASS (246 checks)` | 246 |
| `test_calc_buffer` (`dcases`) | `SKIP (self-skipped: no X)` | `ALL PASS (130 checks)` | 130 |
| `test_divis_zero_1628` | `ALL PASS (33 checks)` | `ALL PASS (33 checks)` | 33 |
| `test_registered_banner_1626` | `ALL PASS (10 checks)` | `ALL PASS (10 checks)` | 10 |
| `test_del_negative_arg` | `ALL PASS (24 checks)` | `ALL PASS (24 checks)` | 24 |

Wave-viewer suites this change can reach — list built by grepping for the verbs it now
calls, **not guessed**
(`/usr/bin/grep -rl 'wviewer::dest_menu_label\|wviewer::resolve_signal_db\|wviewer::add_trace\|wviewer::set_plot_dest\|wviewer::plot_signals\|wviewer::plot_dest\|wviewer::dest_norm\|wviewer::dest_label\|wviewer::plan_replace_clear\|wviewer::set_plot_mode' tests/`),
all on the display arm, all `ALL PASS`:

`test_ase_current_repair` **54**, `test_raw_case_mode` **277**, `test_wave_axis_zoom`
**370**, `test_wave_casemode` **134**, `test_wave_clear_all` **76**,
`test_wave_crossdb_trace` **130**, `test_wave_drag_preview` **94**,
`test_wave_empty_strips` **98**, `test_wave_grid` **400**, `test_wave_modes` **488**,
`test_wave_sigbrowser` **353**, `test_wave_sigbrowser_digital` **82**,
`test_wave_sigbrowser_i1315` **192**, `test_wave_sigbrowser_sea` **79**,
`test_wave_sigsearch` **250**, `test_wave_snap` **106**, `test_wave_split_strip` **221**,
`test_wave_tabs` **172**, `test_wave_trace_menu` **397**, `test_wave_viewer` **437**.

`test_wave_markers` is `TIMEOUT … (after 200s)` — §8, with this stage's own control.

All runs through the armed spelling `tests/headless/run_suites.sh [--nogui] <t>`, display
arm attached to the persistent dev display `:99`, left exactly as found (`status` only).

### The `calc::inert` progress bar

`/usr/bin/grep -n calc::inert src/calculator.tcl` on the tree this stage leaves:

```
20 664 1938 2481 2520 2531 2540 2545 2548 2604 2724 3198 3666 3751
```

`/usr/bin/grep -c 'calc::inert.*\b3\b'` is **0** — no phase-3 stub is left, unchanged from
Stage D. **No total is quoted here**, because §F5c of this receipt exists precisely to
correct a total Stage D quoted; the grep is the instrument.

---

## 1. F1 — the R607 pre-flight named a token that was FINE

### What the seam actually asks

`wviewer::add_trace`'s **single-name** arm (`src/wave_viewer.tcl`) does two things in
order: `wviewer::validate_rpn $rpn $varlist`, where `$varlist` is `xschem raw list` — the
**current** database — and then, **on a failure**, `wviewer::resolve_signal_db $token
$rpn`, which walks `wviewer::signal_list_all` and tries **every loaded database**. Its own
comment quotes the spec:

> spec §D1: validation is against EVERY loaded database, not just the current one.

`calc::rpn_bad_token` stopped at the first question. So for any single-token buffer naming
a signal in a loaded-but-not-current database, Plot refused **by name** while the seam it
would have used plots it correctly.

### Reproduced, through the real viewer, before anything was changed

Probe `…/scratchpad/D2/f1probe.tcl`, run through the armed spelling on `:99`: an ASE-L
session, a real viewer, the committed fixture read as `ac` **and** a three-point ascii raw
written to scratch holding one uniquely named signal `v(xdbonly)`, with the fixture
switched back so it is current:

```
PROBE: raw info: 1 current | 0 …/second.raw tran | 1 …/calc_fixture.raw ac |
PROBE: raw index v(xdbonly) in CURRENT db: -1
PROBE: resolve_signal_db v(xdbonly): idx 0 path …/second.raw type tran cur 0 label {second.raw (tran)}
PROBE: calc::rpn_bad_token -> {unknown token 'v(xdbonly)' (not an operator/function, number or raw variable)}
PROBE: PLOT PRESS said: Cannot plot: unknown token 'v(xdbonly)' (not an operator/function, number or raw variable).
PROBE: traces before=0 after=0
PROBE: CONTROL wviewer::add_trace -> {}
PROBE: traces now=1
PROBE:    trace expr=v(xdbonly) vec=v(xdbonly) keys=expr name vec color rawfile sim_type
PROBE: calc::rpn_bad_token v(reallynosuch) -> {unknown token 'v(reallynosuch)' …}
PROBE: resolve_signal_db v(reallynosuch) -> {}
```

Two things that probe settles and no amount of reading would have: the seam **succeeds**
(`add_trace -> {}`, trace landed with §D1's `rawfile`/`sim_type` keys), and
`resolve_signal_db` still answers **empty** for a name no database has — so the pre-flight
can still prove a genuinely bad token bad.

### The fix: ask the same question, and fail open everywhere else

`calc::rpn_bad_token {rpn {tok {}}}`. When the current-database validator rejects **and**
the caller passed a viewer token **and** the expression is ONE engine token, it asks
`wviewer::resolve_signal_db` — the viewer's own proc, not a rule restated here — and
approves on a hit. **Every way of not knowing approves**: the proc absent, the proc
raising, or a hit.

Three deliberate narrownesses, each with a row:

* **Only a single token**, because that is the only case the seam asks it for;
  `add_trace`'s expression arm validates against the current database and nothing else, so
  for an expression the single question already *is* the seam's. The gate counts the
  **engine's** tokens while the seam counts non-space runs, and the engine's delimiter set
  is a subset of that one, so this gate can only ever be **more** open than the seam's,
  never less.
* **The name handed over is `string trim`'s**, which is the argument `add_trace` passes.
  Nothing measured that at first — sabotage `Q4b` reddened **zero** — so `PL7b` now drives
  a pasted trailing carriage return through **both** and asserts they agree.
* **Evaluate passes no token, and that is correct.** `xschem raw add` resolves through
  `get_raw_index()` against the current database only — measured, `xschem raw index
  v(xdbonly)` is `-1` in that same two-database world — so Evaluate's refusal naming it is
  **true**. Rows in `CE13` and `PL7b` pin both halves, so a later stage cannot "fix"
  Evaluate to match.

### The red, verbatim

New band `PL7b` plus the engine-side rows, against the stage-D product put back in the
tree and **verified byte-identical by md5** (`6e2c706073d1e977a0ca72ef52fa0154`):

```
FAIL: PL7b ⚠⚠ THE TRACE LANDS: a single token naming a signal in a LOADED-BUT-NOT-CURRENT database is PLOTTED, not refused by name -> {0 0} (exp {1 1}) : FAIL
FAIL: PL7b ⚠ ...and the sentence names it as what was PLOTTED, never as an unknown token, which is the wrong-name failure this band exists for -> {1 1 1} (exp {0 0 1}) : FAIL
FAIL: PL7b ...and the landed trace carries the FOREIGN database's path and type … -> {{v(lp) v(sq) / db20()} 0 {ERR:key "sim_type" not known in dictionary}} (exp {v(xdbonly) 1 tran}) : FAIL
FAIL: PL7b calc::rpn_bad_token APPROVES it when a viewer token is given … -> {NORUN} (exp {}) : FAIL
FAIL: PL7b ...and still REFUSES a name no loaded database has … -> {1 0} (exp {1 1}) : FAIL
FAIL: CE13 R607 WITH a viewer token, a single name some OTHER loaded database has is APPROVED … -> {ERR:wrong # args: should be "calc::rpn_bad_token rpn"} (exp {}) : FAIL
FAIL: CE13 R607 ...and an EXPRESSION is not asked either … -> {1 0} (exp {1 1}) : FAIL
FAIL: CE13 R607 CONTROL: with the REAL resolve_signal_db and no viewer window the same call REFUSES … -> {1 0} (exp {1 1}) : FAIL
FAIL: CE13 R607 ...and a RAISING resolve_signal_db fails OPEN rather than propagating … -> {{ERR:wrong # args…} 1} (exp {{} 0}) : FAIL
FAIL: CE13 R607 ...and an ABSENT one fails open too … -> {ERR:wrong # args…} (exp {}) : FAIL
```

### ⚠ One of my own new rows was WRONG, and the fixed product caught it

```
FAIL: PL7b ⚠ ...and the sentence does not name the token as unknown … -> {0 1} (exp {0 0}) : FAIL
```

It asserted the success sentence does not contain `v(xdbonly)` **at all**. A successful
press says `Plotted v(xdbonly) (Append).`, because that **is** the vector that landed. The
row now asserts the absence of the *refusal* (`unknown token`, `Cannot plot:`) and the
*presence* of the name. The product was right and the row was wrong — the same species of
mistake Stage D records three of.

---

## 2. F2 — Replace is an Append under `multi`, and a New Tab choice vanished

### The Calculator's claim was the wrong one, and the viewer was not touched

`wviewer::plan_plot`'s own banner declares it: its multi arm lands every signal in a strip
it **creates** or a reused **empty** one, so there is by construction nothing for
`replace` to clear, and `wviewer::plan_replace_clear` returns empty there for every input.
The viewer **surfaces** that in exactly one place — `wviewer::dest_menu_label`, which its
Options cascade reads — appending `-> appends`.

So the fix is that the Calculator **names the destination through that proc** instead of
through `wviewer::dest_label`, on both of its sentences (`calc::plot_rpn`'s `plotted` and
`calc::dest_changed`'s `dest`). One place said it; now two readers use that one place.
**The viewer's ruling 24 is untouched** — nothing in `src/wave_viewer.tcl` changed, and
`test_wave_modes` is `ALL PASS (488 checks)`.

The false shipped claim was in `calc::build_mode`'s W13 comment: *"Row PL2 asserts the
three offered here are three DISTINCT codes to `wviewer::dest_norm`, **so the control
cannot be offering a choice the viewer silently collapses**."* `dest_norm` is pure and
does map three labels to three codes — which is all `PL2` measures — but what the viewer
does with `replace` afterwards is a MODE question. Both the comment and `PL2`'s row name
are corrected, and the row name now claims only what it measures.

### The New Tab cancellation: DECLARED, and no longer silent

`wviewer::dest_labels` has **four** entries; W13 offers **three** (spec §4). `plot_rpn`
pushes W13's value on every press, which is R601's requirement, so a `New Tab` chosen from
the viewer's own Options menu is overwritten by the next Calculator press. **The limit is
declared, not closed** — W13 still offers three — but the silence is gone:
`calc::plot_dest_dropped` answers one sentence, appended to the `Plotted` and the
`Plot failed:` sentence alike (the push has already happened by the time the seam fails):

> `The viewer was set to New Tab, which W13 does not offer, so that choice is gone.`

"W13 does not offer it" is read **off the widget** (`calc::plot_dest_offered` →
`.calc.mode.dest cget -values`), not off a list in the code, so a later phase that widens
W13 needs no edit here. Nothing measured that at first — sabotage `Q11` reddened **zero** —
so `PL5e` now widens the real widget in place, re-asks, narrows it again and asserts the
restore.

### The red, verbatim

```
FAIL: PL5d ⚠ R506: choosing Replace in multi mode SAYS it appends, instead of naming a policy the mode does not run -> {1 0} (exp {1 1}) : FAIL
FAIL: PL5d ⚠ ...and the press SAYS so: the Plotted sentence names Replace AND that it appends … -> {1 1 0} (exp {1 1 1}) : FAIL
FAIL: PL5e ⚠ the press SAYS the New Tab choice is gone, naming it, instead of cancelling it in silence -> {1 0} (exp {1 1}) : FAIL
FAIL: PL5e calc::plot_dest_dropped answers the clause for a destination W13 lacks … -> {1 {ERR:invalid command name "calc::plot_dest_dropped"} …} (exp {1 {} {} {} {} {}}) : FAIL
```

`PL5d` asserts **both directions**, which is the point: the sentence says it appends **and
the total trace count grows by exactly one**, which a Replace that cleared its landing
strip of k≥1 traces could not do for any k. A single-mode control leg beside it shows the
same fixture really can be cleared, so neither row is satisfied by a Replace that does
nothing anywhere.

A `rule` debt is filed for both sentences — `calc_plot_dest_honesty_d2`, an **addition** to
`calc_plot_wording_phase3`, never an overwrite. The ledger was backed up first
(`cp -r ~/.claude/xschem_owed …/scratchpad/D2/owed_backup_before`). **I cleared nothing.**

---

## 3. F3 — "Nothing in it is reached by renaming a product proc aside" was FALSE

The sentence was in **two** places — `tests/run_regression.tcl` and the suite's own header
— and the suite renames **three** `wviewer::` procs aside. Both copies now carry the same
list, so neither can go stale alone without the other contradicting it. For each rename:
what the stub stands in for, **and what drives the real proc**:

| rename | the stub stands in for | what drives the REAL proc |
|---|---|---|
| `wviewer::plot_signals` (`PL5c`) | a forced failure — once R607's pre-flight has approved an expression, nothing in this file can make the seam fail | `PL3`, `PL4`, `PL4b`, `PL5`, `PL5b`, `PL5d`, `PL5e`, `PL7`, `PL7b`, and `PL5c`'s own control leg |
| `wviewer::log_action` (`PL6`) | a capture of the replay line, which is that row's subject | ⚠ **NOTHING IN THIS FILE.** Named as a coverage gap: it is a one-line `catch` around the `xschem log_action` verb, the verb has its own fence in `tests/headless/test_replay_door_1619.tcl`, and what `PL6` measures is the line's CONTENT, not its delivery |
| `wviewer::current_token` (`PL8`) | an empty answer, so emptying the viewer registry really leaves no result | `PL0`, whose `calc::require_result` row resolves the live viewer through `calc::viewer_tokens`, which calls it; `PL8` restores it and its last row re-checks the live layout |

`PL7b` renames nothing — it reaches the cross-database case by loading a **second real
database**, which is the shape that found the defect.

---

## 4. F4 and the FIFTH, unlisted, false comment

**F4 as handed over.** `calc::eval_rpn`'s header said *"⚠ WHAT THIS DOES **NOT** DO, and
it is PLAN 3.4's (R607) … it cannot tell a REJECTED expression from one that legitimately
evaluates to zero … R607 has to find the failing token by validating every vector-looking
token with `xschem raw index` BEFORE the engine runs."* 3.4 landed in that same stage. The
paragraph now says why the refusal **is** a pre-flight (nothing downstream of the engine
call can tell a rejection from a legitimate zero — `raw_add_vector()` discards the `-1`,
and issue 0325 zeroes a fresh column) and points at `calc::rpn_bad_token`'s header for
what is still open, rather than claiming the work is not done.

⚠ **AND A FIFTH, WHICH THE HANDOVER DID NOT LIST AND WHICH IS THE SAME SPECIES.**
`calc::eval_click`'s header carried *"⚠ SECOND DECLARED LIMIT: the documented `%<n>`
dataset SPELLING reads as a SILENT ZERO from here … **NOT FIXED HERE: naming the failing
token is R607/PLAN 3.4's job** and that is where this stops being silent. Band CE12 …
asserts **both limits as they stand**."* Band `CE12` was restated **in the same change**
to read `CE12 CLOSED (was a declared limit): the %<n> dataset spelling is now REFUSED BY
NAME`. So the comment contradicted a row four hundred lines away, in the same commit. It
now says the spelling is **not supported but no longer silent**, and quotes the row that
holds each half. Found by walking the band's rows against the prose beside them, not by a
run — no row can catch a comment.

---

## 5. F5 — the three minor claims

* **(a) `PL9`'s last row name.** It read *"…are exactly the **THREE** that take their
  inputs as arguments"* while the expected list on the next line held **four**. The row
  name now describes the **method** (*"the ones whose CODE names no widget path are exactly
  the procs that take their inputs as arguments"*) and the exact list carries the count,
  where it is re-measured. CLAUDE.md's rule, and the row was its own counterexample.
* **(b) `calc::rpn_bad_token`'s "TWO MEASURED DISAGREEMENTS".** The count is gone. The
  paragraph now reads *"MEASURED DISAGREEMENTS … each pinned by a row in CE13 and none of
  them hidden (the count is the rows', not this sentence's — an earlier revision quoted one
  and disagreed with the two other statements of it in the same change)"*. It then lists
  **four**, because this stage declared arity (§6b) beside the other three.
* **(c) The stale grep in `receipts/D-plot.md` §0.** Corrected **in place**, with the
  correction marked as Stage D2's and the reason stated: the capture listed **13**
  `calc::inert` lines and the tree has **14**, because a LATER round of the same stage
  added one more **comment** mention after the grep was taken. So the figure was correct
  when made and wrong when published. The load-bearing half is re-checked and unaffected:
  `/usr/bin/grep -c 'calc::inert.*\b3\b'` is **0**.

---

## 6. F6 — the three gaps, DECLARED with measurements

### (a) Every expression press leaves a persistent `expr<N>` column

`wviewer::add_trace` materialises a multi-token RPN as a **persistent** raw vector because
the trace has to keep reading it. Nothing un-materialises one:
`wviewer::clear_graph_traces` drops the **model** entry and leaves the column in the
in-memory raw. Declared in `calc::plot_rpn`'s header **and pinned by new band `PL4b`**,
which plots the gain expression, Replace-plots a single name into the same strip, and
asserts the trace is gone from the model **while `xschem raw index` still resolves its
column**. R402's delete is not the fix — sabotage `P14` applies it to this path and reddens
the data rows wholesale; a correct fix has to know no trace in any tab still reads the
column, which is `add_trace`'s knowledge.

### (b) ARITY — a third blind spot, not the two the D receipt listed

Measured headless against the committed fixture:

```
expr {v(ramp) +}            -> raw add rc=1  | eval_rpn ok=1 value=10 msg={}
expr {v(ramp) v(div)}       -> raw add rc=1  | eval_rpn ok=1 value=10 msg={}
expr {v(ramp) v(div) + *}   -> raw add rc=1  | eval_rpn ok=1 value=15 msg={}
expr {+}                    -> raw add rc=1  | eval_rpn ok=1 value=0  msg={}
expr {v(ramp) abs() abs()}  -> raw add rc=1  | eval_rpn ok=1 value=10 msg={}
   {v(ramp) +}        -> validate_rpn {}  rpn_bad_token {}
   {v(ramp) v(div)}   -> validate_rpn {}  rpn_bad_token {}
   {+}                -> validate_rpn {}  rpn_bad_token {}
```

Every token resolves, so a per-token alphabet check cannot see it: too few operands, a
leftover stack and an operator with no operands at all are all **approved**, and the
product answers a **confident number with no message**. That is R607's own failure mode one
step past an unresolvable name. **Not closed**, and not cheap to close: it needs an
operand-count model of the engine's operator table, which is landmine L5's *"never parser
number two"* in its most expensive form, or the `xschem raw set` sentinel Stage D measured
and declined. Declared in `calc::rpn_bad_token`'s header and pinned by four rows in
`CE13`, one of which asserts the leftover-stack answer is not merely unvalidated but
**misleading** (`v(lp) v(sq)` answers neither 1 nor a refusal).

### (c) The answer dict's `dest` key — MADE one thing rather than declared

It carried W13's **label** on the `badtoken`/`noctx`/`busy` refusals and the resolved
**code** on success and on `failed`. Normalised in `calc::plot_refusal`, the one site the
refusing dict is built, so the key now means exactly *"the destination CODE this press
resolved to, or empty when nothing resolved one"*. `wviewer::dest_norm` is idempotent on a
code, which is what makes that safe on the paths already passing one; an **empty** dest is
left empty rather than folded to `append`, because R508's no-window world resolved nothing
and saying `append` would invent a choice the user never made. New band `PL2b` drives all
three answering paths plus the empty one. Its red:

```
FAIL: PL2b the answer dict's `dest` is the resolved CODE on the noctx, badtoken and success paths alike, never W13's label -> {noctx {New Strip} badtoken {New Strip} ok newstrip} (exp {noctx newstrip badtoken newstrip ok newstrip}) : FAIL
```

---

## 7. F7 — the structural scans now read CODE, and the helper is LIFTED not copied

`PL9`'s and `CE8`'s R508 scans read a raw `info body`, so a future **comment** inside a
Plot proc naming a `.calc` widget path would have moved that proc into the "unguarded" half
and reddened a registered T1 fence on an edit that changed no behaviour. That exact defect
has been found twice this session (`RB5`, `CE12`).

Both scans now decomment first. `test_calc_engine` already has `ce_decomment`/`ce_code`, so
**`test_calc_plot` LIFTS them out of that file's own text** rather than carrying a third
copy: a line scan from `^proc <name>` to the first line that is exactly a close brace, the
method `test_scratch_home_note` uses on `run_regression.tcl`'s `summarize_all`. **Both**
procs are lifted, because `ce_code` calls `ce_decomment` — lifting a named subset is the
same defect one level up (CLAUDE.md limit L9). The lift's own success is a row, and its
non-vacuity is a second row driving four inputs (whole-line comment, tail comment, real
code, and a `#` inside a string, which must survive).

**And the fix is measured, not asserted.** Sabotage pair:

| # | what it does | reds |
|---|---|---|
| **Q12a** | a comment naming `.calc.mode.dest` added inside `calc::plot_msg`, a PURE proc | **0** — the intended zero |
| **Q12b** | the same comment **plus both scans reverted to the raw `info body`** | **4** (`CE8`×2, `PL9`×2) |

So the zero in `Q12a` is the decommenting working, and `Q12b` proves it is what made the
difference. Without the fix the comment alone reddens two registered suites.

---

## 8. `test_wave_markers` — the named outcome, and this stage's own control

```
TIMEOUT  | test_wave_markers            run 1/1 (after 200s)
RESULT: 0/1 runs passed
```

CLAUDE.md records this (*"`test_wave_markers` times out when `run_suites.sh` attaches to a
dev display (issue 1488, pre-existing)"*), and Stage D measured it against
`HEAD:src/calculator.tcl` at this same commit. **Citing is not measuring, so this stage ran
its own control too**, with the stage-D `src/calculator.tcl` put back and md5-verified in
both directions:

| `src/calculator.tcl` in the tree | md5 | outcome |
|---|---|---|
| this stage's | `a7b960e60547207be7ec4b01aa017382` | `TIMEOUT \| test_wave_markers run 1/1 (after 200s)` |
| **Stage D's, as handed over** | `6e2c706073d1e977a0ca72ef52fa0154` | **`TIMEOUT \| test_wave_markers run 1/1 (after 200s)`** |

Byte-identical outcome on both, and the tree restored after. **It is pre-existing (issue
1488) and not this stage's.** Both runs carried an outer `timeout 400` on the driver and
were watched by a monitor with its own deadline, so *"still running"* and *"wedged"* were
distinguishable states throughout; `run_suites.sh`'s own `SUITE_TIMEOUT` produced the 200 s
line, so the stall is a **named outcome** in both cases and not silence.

⚠ What the control does NOT establish, the same gap Stage D declared: that the suite would
pass on a private Xvfb with the dev display down. CLAUDE.md says it does; taking `:99` down
is on the brief's do-not-touch list, so it was not tested.

---

## 9. The claim audit — every sentence, row name and citation I touched

| claim | how checked | verdict |
|---|---|---|
| `add_trace`'s single-name arm falls back to `resolve_signal_db` over every loaded DB | read the body; driven through a real viewer with two DBs (§1); rows `PL7b` and `CE13` | ✓ |
| the seam PLOTS the loaded-but-not-current name | `add_trace -> {}` and the trace landed with `rawfile`/`sim_type`; row `PL7b` | ✓ |
| `resolve_signal_db` answers empty for a name no DB has | driven, both in the probe and as a row | ✓ |
| `add_trace`'s EXPRESSION arm does not ask the second question | read the body; row in `CE13` drives it with a shimmed `resolve_signal_db` | ✓ |
| the engine's delimiter set is a SUBSET of `\S+`, so this gate can only be more open | read both; `CE13` already asserts the delimiter string out of the C | ✓ |
| Evaluate's refusal of a non-current name is TRUE | `xschem raw index v(xdbonly)` = −1 in that world, measured; rows both sides | ✓ |
| `add_trace` trims its own `rpn` first | read the body; row `PL7b` drives `"v(xdbonly)\r"` through BOTH | ✓ after sabotage `Q4b` reddened 0 |
| `plan_plot` emits no clear key under `multi`, so Replace is an Append | read `plan_plot` and `plan_replace_clear`; row `PL5d` drives the mode and the trace count | ✓ |
| `dest_menu_label` is the ONE place that surfaces it | `/usr/bin/grep -n 'dest_menu_label' src/*.tcl` and read its header | ✓ |
| **"the control cannot be offering a choice the viewer silently collapses"** | re-read `dest_norm` (pure, three codes) against `plan_plot` (mode-dependent) | ✗ **FALSE, shipped by Stage D.** Corrected in the comment AND in `PL2`'s row name |
| `dest_labels` has four and W13 three, so a press overwrites `newtab` | driven, row `PL5e`: `set_plot_dest {New Tab}` then a press, `plot_dest` back to `append` | ✓ |
| "W13 does not offer it" is read off the widget | row `PL5e` widens the real widget and re-asks | ✓ after sabotage `Q11` reddened 0 |
| **`calc::eval_rpn`'s "cannot tell a REJECTED expression … PLAN 3.4's"** | 3.4 is in the same working tree; `CE13` drives the refusal | ✗ **FALSE** (F4). Rewritten |
| **`calc::eval_click`'s "`%<n>` reads as a SILENT ZERO … NOT FIXED HERE"** | read band `CE12`, which asserts the opposite **in the same change** | ✗ **FALSE, unlisted fifth** (§4). Rewritten |
| **`PL9`'s "exactly the THREE…"** against a four-element list | counted the list beside it | ✗ **FALSE** (F5a). Name now describes the method |
| **`rpn_bad_token`'s "TWO MEASURED DISAGREEMENTS"** | counted what the paragraph itself then lists | ✗ over-specific. Count dropped (F5b) |
| **`D-plot.md` §0's "13 lines … nothing else moved"** | re-ran the grep on the tree Stage D left | ✗ **STALE**: 14 (F5c). Corrected in place with the reason |
| the materialised column outlives its trace | row `PL4b`: trace gone from the model, `raw index` still resolves | ✓ |
| arity is unseen and the answer is a confident number | driven for five shapes headless (§6b); four rows in `CE13` | ✓ |
| the `dest` key carried two vocabularies | the red run printed it: `{noctx {New Strip} badtoken {New Strip} ok newstrip}` | ✓ |
| `ce_code` can be lifted out of `test_calc_engine.tcl` by a line scan | row `PL9` asserts the lift returned `ok` and a second row drives four inputs | ✓ |
| the raw-body scans would false-redden on a comment | sabotage pair `Q12a`/`Q12b` (§7) | ✓ measured |
| three product procs are renamed aside, and what drives each real one | read every `rename` in the file and traced each caller; `log_action`'s gap is admitted | ✓ |
| `wviewer::log_action` is a one-line wrapper round `xschem log_action` | read it | ✓ |
| the `xschem log_action` verb is fenced by `test_replay_door_1619` | `/usr/bin/grep -n log_action` on that file — it drives the **verb**, which is the honest claim; it does **not** drive `wviewer::log_action` | ✓ as narrowed |
| **Stage D's `P6` reddens 15** | re-ran that mutation: **0**, then probed why (§10) | ✗ **DEAD FENCE**. Repaired; `P6` is back to 1 and `O-plot` to 13. ⚠ That Stage D's own run was also 0 is **INFERRED, not measured** — its version of the suite file no longer exists, and §10 writes the inference out |
| every `wviewer::*` and `calc::*` symbol cited | each grepped before the sentence shipped; no bare `file:line` citations added | ✓ |

---

## 10. ⚠⚠ THE DEAD FENCE: `P6` REDDENED ZERO WHERE ITS RECEIPT RECORDS 15

Stage D's receipt records sabotage **`P6` — "no loan at all: `plot_rpn` in whatever context
is current" — at 15 reds**. That mutation, re-run here: **0 reds**, `test_calc_plot` at
`ALL PASS (102 checks)`. The task said to look for exactly this, so it was **measured** —
and then the mechanism was measured too, rather than explained.

Probe `…/scratchpad/D2/p6probe.tcl`, with `P6` applied:

```
PROBE: AFTER the fixture read+leave, current_win_path = .x1.drw      <- the VIEWER
PROBE: viewer win_path = .x1.drw
PROBE: AFTER require_result, current_win_path = .x1.drw
PROBE: after switch .drw, current = .drw
PROBE: raw loaded in .drw: -1   raw list: ERR:No raw file loaded
PROBE: just before the press, current = .drw
PROBE: PRESS said: Cannot plot: unknown token 'v(lp)' (not an operator/function, number or raw variable).
PROBE: AFTER the press, current = .drw  traces 0 -> 0
```

**The mechanism.** `wviewer::open` leaves the xschem context standing **in** the viewer, so
`wviewer::enter_ctx` takes its documented *"already there"* fast path for the fixture read,
`prev` is empty and `leave_ctx` restores nothing. From `PL0` onward **every band is already
in the viewer's context**, so the loan is redundant on every path the suite drives. The one
band that is not — `PL1`, which switches to `.drw` first — asserted only
`current_win_path`, and with no loan the press **refuses** (the pre-flight reads `.drw`'s
empty raw) and therefore never switches context either. So the row passed on the broken
product.

**The repair.** `PL1`'s U8 row now asserts, in one place, that the press from a foreign
context **plots** — which it can only do by taking the loan — **and** that the context
comes back, **and** that `.drw` genuinely cannot see the fixture (`xschem raw loaded` < 0),
which is the non-vacuity leg that makes "it plotted" mean "it switched".

`P6` reddens **1** again. `O-plot` moved 14 → 15 by the same row, and `P5` (the loan never
given back) still reddens 1.

⚠ **And the general lesson is sharper than "re-run the old sabotages": `P6`'s zero was
probably NOT caused by any change in this stage — but that is INFERRED, and the inference
is written out rather than asserted, because I cannot measure it.** I took my first pristine
copy of `test_calc_plot.tcl` *after* editing it, so **Stage D's own version of that file no
longer exists anywhere I can reach** (it is untracked, so `git show` has nothing either).
What I can say, and what the inference rests on:

* the pre-repair `PL1` row asserted only `{$was [current_win_path]}` eq `{.drw .drw}`, and
  that row **passed** under `P6` — measured, in the run that returned 0;
* my bands only ADD to Stage D's; I deleted no row, and the two rows I renamed
  (`PL2`'s, `PL9`'s) assert the same things under `P6`;
* so every row Stage D's suite had was also in the suite that scored `P6` at **0**.

The likeliest explanation of Stage D's **15** is therefore that its `P6` was a different
edit from mine — `O-plot`'s shape, which also drops the `noctx` guard and reddens 13–15
here. **Two sabotages that read as the same English sentence were not the same mutation,
and only one of them was measuring the loan.** The durable fix for that is the one this
stage adopted: keep the mutations as DATA, not as prose.

---

## 11. Sabotages: SIXTY-SEVEN mutations, every one re-run on the tree this stage leaves

Harness `…/scratchpad/D2/sab.py` plus four JSON tables, **in scratch, not in the tree**. It
**refuses to apply unless the anchor text is unique in the target file**, runs the named
suites, restores all four tracked files from pristine copies and **verifies every md5 after
every sabotage** — `restore=OK` on all 67. Two of Stage D's entries are recorded as
**aliases** rather than re-run twice, because they are the same edit as another one
(`N8` = `N1`, `P9` = `G`). `C2-3` is a C change and got its own rebuild in both directions.

### This stage's own — F1, F2, F6c, F7

| # | the plausible wrong implementation | reds | where |
|---|---|---|---|
| **Q1** | **the cross-database consult removed — the F1 defect itself** | **8** | engine 3, plot 5 |
| **Q2** | the consult asked for EVERY token count, not just a single name | 1 | engine 1 (`CE13`'s expression row) |
| **Q3** | fails CLOSED when `resolve_signal_db` is absent | 1 | engine 1 |
| **Q3b** | fails CLOSED when `resolve_signal_db` raises | 1 | engine 1 |
| **Q4** | `plot_rpn` passes no token — the plumbing dropped | 3 | plot 3 |
| **Q4b** | the name handed over is **not** `string trim`'d | 1 | plot 1 — **was 0 before `PL7b` gained the row** |
| **Q5** | `dest_menu_label` back to `dest_label` in `plot_rpn` — the F2a defect | 1 | plot 1 |
| **Q6** | the same in `dest_changed` | 1 | plot 1 |
| **Q7** | `plot_dest_dropped` always empty — the silence restored | 3 | plot 3 |
| **Q8** | `prev` read AFTER the push (the plausible ordering error) | 1 | plot 1 |
| **Q9** | `plot_refusal` stops normalising — the F6c defect | 1 | plot 1 (`PL2b`) |
| **Q10** | `plot_dest_dropped` compares LABELS where it must compare codes | 2 | plot 2 |
| **Q11** | the offered list hardcoded instead of read off the widget | 1 | plot 1 — **was 0 before `PL5e` gained the widen-in-place row** |
| **Q12a** | a comment naming `.calc.mode.dest` inside the pure proc `calc::plot_msg` | **0** | **the intended zero** — §7 |
| **Q12b** | the same comment **plus both scans back on the raw `info body`** | **4** | engine 2, plot 2 — the control that makes `Q12a`'s zero mean something |

### Stage D's own — R607, re-run

| # | reds (D's figure) | | # | reds (D's figure) |
|---|---|---|---|---|
| **N1** | **12** (11) | | **N6** | **42** (14) |
| **N2** | **9** (8) | | **N7** | **2** (2) |
| **N3** | **4** (2) | | **N8b** | **1** (not quoted) |
| **N4** | **1** (1) | | **N9** | **2** (2) |
| **N5** | **2** (2) | | **N8** | = `N1`'s edit; Stage D records it separately |

### Stage D's own — Plot, re-run

| # | reds (D's figure) | | # | reds (D's figure) |
|---|---|---|---|---|
| **P1** | **5** (2) | | **P8** | **3** (3) |
| **P2** | **11** (4) | | **P10** | **4** (1) |
| **P3** | **1** (1) | | **P11** | **3** (2) |
| **P4** | **4** (2) | | **P12** | **45** (22) |
| **P5** | **1** (1) | | **P13** | **1** (1) |
| **P6** | **1** — ⚠ **was 0 on the tree as handed over** (15); §10 | | **P14** | **29** (7) |
| **P7** | **4** (2) | | **O-plot** | **13** (20) |
| **P9** | = `G`'s edit; `G`'s split below gives its Plot figure, still **0** | | | |

### Stage C's twenty-one, re-run

reds now, with Stage D's re-run figure in brackets:

| # | reds | | # | reds | | # | reds |
|---|---|---|---|---|---|---|---|
| **A** | **6** (6) | | **H** | **3** (3) | | **O** | **2** (2) |
| **B** | **1** (1) | | **I** | **4** (4) | | **P** | **3** (3) |
| **C** | **1** (1) | | **J** | **12** (12) | | **Q** | **2** (2) |
| **D** | **5** (6) | | **K** | **65** (67) | | **R** | **2** (2) |
| **D2** | **0** (0) | | **L** | **20** (20) | | **S** | **1** (1) |
| **E** | **2** (2) | | **M** | **83** (79) | | **T** | **1** (1) |
| **F** | **2** (2) | | **N** | **2** (2) | | | |
| **G** | **7** (7) | | | | | | |

### Stage C2's, re-run

| # | reds | |
|---|---|---|
| **C2-1** | **4** (4) | the `annot_sweep_idx` term dropped |
| **C2-1b** | **0** (0) | declared unfenced in the code, unchanged |
| **C2-1c** | **7** (7) | the discriminator reads field 1 |
| **C2-2** | **12** (12) | the non-finite refusal removed |
| **C2-2b** | **8** (8) | `eval_finite` as a denylist |
| **C2-2c** | **4** (4) | R607 violated for the non-finite case |
| **C2-3** | **3** (3) | the COND arm's `dbg` back to level 0 — **rebuilt in both directions**, md5 back to `e0429f722665b90b5a2689423f346bda` |
| **C2-4** | **1** (1) | test-side: the 16-digit reader "simplified" to the 8-digit accessor |

### The zeroes, read rather than counted

**Three whole-sabotage zeroes, and all three are accounted for.**

* **`D2`** (the `raw add` belt alone removed) — **0**, exactly as Stage C declared it. The
  belt is unreachable while the pre-engine guard stands, and `calc::eval_rpn`'s own comment
  says so and does not claim it is fenced. Unchanged.
* **`C2-1b`** (the `$p < 0` term weakened) — **0**, exactly as Stage C2 declared it, and its
  own comment carries the declaration. Unchanged.
* **`Q12a`** — **0 by design**, and `Q12b` is the control that makes the zero mean
  something: §7.

**And the per-suite zeroes are the information, not the totals.** `G`'s Plot column is
**0**, which re-measures Stage D's `P9` declaration (*"invisible to Plot"*) on a tree whose
Plot suite has grown from 67 to 105 checks — the trailing newline is one of the engine's
three delimiters and `add_trace` trims, so the token set really is identical; `test_calc_buffer`'s
`CB6` is the only fence and it still reddens 7. `N6`'s `test_calc_scratch_reuse` column is 0
(it reddens 21 on each of the other two). `Q2`/`Q3`/`Q3b` show **plot 0 / engine 1**, which
is right: those three are headless questions and `CE13` is where they are asked. `P12`'s
`test_calc_widgets` column is 0 while its Plot column is 44 — `CW13` asserts an allow-LIST
of commands, and re-wiring the button to `calc::inert` keeps it inside that list.

**Two of my own fences were zeroes until I read them** — `Q4b` and `Q11`, both now rows
(§1, §2). That is the third round of this batch where a zero was the finding.

---

## 12. The trailer delta — derived from `summarize_all`'s OWN regexp arms

Method, as `receipts/D-plot.md` §11 set it: capture each case **exactly as T1's own loop
builds its command line** — the `dcases` arm through `devdisplay.sh exec … --pipe -q
--logdir <dir> --script <t>.tcl`, the `hcases` arm through `env -u DISPLAY … --nogui --pipe
-q --script`, stdout and stderr together, HOME armed through `tests/headless/test_home.sh` —
then **lift `t1_carry_line` and `summarize_all` out of `tests/run_regression.tcl`'s own
text** (a line scan from `^proc <name>` to the first line that is exactly a close brace),
`source tests/banner_rule.tcl`, and drive the lifted proc the way the driver drives it
(`summarize_all <fn> <fd> <label>`: it opens the capture and WRITES the block). **No figure
below is quoted from a receipt.**

```
lifted: t1_carry_line (5 lines)
lifted: summarize_all (89 lines)
--- the lifted summarize_all's arms, as it spells them ---
>> if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]} {
>> } elseif { [regexp {^(NOGOLD|NODISPLAY)} $line] } {
>> } elseif { [regexp {^skip:} $line] } {
>> } elseif { [regexp {^RESULT:} $line] } {
>> } elseif { [banner_complete $line] && [regexp {\([^)]*\)} $line] } {

=== plot.disp: lines=118 counted-shape=0 lowercase(^skip:)=0 any-case(^skip)=0 ^RESULT:=1 NOGOLD/NODISPLAY=0 col0_OVERALL=1
    banner_complete=1 banner_died=0 regression_case_failed(0)=0
    summarize_all returned: 0 ; blocks +1 ; failures +0 ; skips +0
    | plot
    | RESULT: ALL PASS (105 checks)
    | Total num fail: 0
=== plot.nogui: lines=5 counted-shape=0 lowercase(^skip:)=0 any-case(^skip)=0 ^RESULT:=1 NOGOLD/NODISPLAY=0 col0_OVERALL=0
    banner_complete=0 banner_died=0 regression_case_failed(0)=1
=== test_calc_engine.nogui: lines=301 counted-shape=0 lowercase(^skip:)=0 any-case(^skip)=0 ^RESULT:=1 NOGOLD/NODISPLAY=0 col0_OVERALL=1
    banner_complete=1 banner_died=0 regression_case_failed(0)=0
    | RESULT: ALL PASS (265 checks)
=== test_calc_scratch_reuse.nogui: lines=60 counted-shape=0 lowercase(^skip:)=0 any-case(^skip)=0 ^RESULT:=1 NOGOLD/NODISPLAY=0 col0_OVERALL=1
    banner_complete=1 banner_died=0 regression_case_failed(0)=0
    | RESULT: ALL PASS (51 checks)
TOTALS: blocks=4 failures=0 skips=0
```

**This stage's contribution, derived: +0 cases, +0 blocks, +0 counted failures, +0 `^skip:`
lines, +0 verdict lines.** It registers nothing — Stage D already put
`headless/test_calc_plot` in `dcases` — so the counts relative to the driver's committed
baseline **120/119/0/8** at `47ea655a` are **Stage D's +1 case and +1 block**, and this
stage adds none. Counted by the method CLAUDE.md prescribes (find `set <n> [list`, pipe
through `/usr/bin/grep -o '"[^"]*"' | wc -l`): `tcases` **3** + `hcases` **93** + `dcases`
**24** + `xschemtest` = **121 cases**.

What moves is the **published check count inside existing blocks**: `test_calc_plot`
67 → **105**, `test_calc_engine` 253 → **265**. A check-count change moves no line count.

**Exactly one column-0 `RESULT:` and one column-0 `OVERALL:` per display capture** — issue
**1627**'s shape re-measured, because a second trailing `RESULT:` would silently rewrite the
published check count. And `plot.nogui` answers `regression_case_failed(0)` = **1**, which
re-measures from scratch the argument for the arm decision: an `hcases` entry for that file
would be a standing red. It is `dcases` only, so T1 never takes that path.

⚠⚠ **THIS IS A DERIVATION OVER MY OWN SUITES' OUTPUT, NOT A PREDICTION OF THE TRAILER, AND
IN PARTICULAR NOT A PREDICTION OF `skips=`.** CLAUDE.md records four occasions where
careful reasoning about registration shape got that figure wrong, most recently issue 1625
where an adversarial verifier **and** the driver both predicted movement and both were
wrong, because `summarize_all` counts **lowercase** `^skip:` and suites announce skipped
bands with an uppercase `SKIP:`. What I measured is that my captures contribute **zero**
lines of either spelling (`lowercase(^skip:)=0` **and** `any-case(^skip)=0` on all four), so
there is nothing here to be wrong about. **Read the trailer.**

---

## 13. `git status --short` at the end

```
 M src/calculator.tcl
 M tests/headless/test_calc_engine.tcl
 M tests/headless/test_calc_scratch_reuse.tcl
 M tests/headless/test_calc_skeleton.tcl
 M tests/headless/test_calc_widgets.tcl
 M tests/run_regression.tcl
?? .xschem/
?? doc/claude/calculator_batch/receipts/D-plot.md
?? doc/claude/calculator_batch/receipts/D2-plot-blockers.md
?? doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
?? tests/headless/test_calc_plot.tcl
```

**Of those, this stage changed exactly six**: `src/calculator.tcl`,
`tests/run_regression.tcl`, `tests/headless/test_calc_engine.tcl`,
`tests/headless/test_calc_plot.tcl`, `receipts/D-plot.md` (§F5c's in-place correction, and
nothing else in it) and this receipt. **`tests/headless/test_calc_scratch_reuse.tcl`,
`test_calc_skeleton.tcl` and `test_calc_widgets.tcl` are Stage D's and were NOT touched** —
they appear above because Stage D's work is uncommitted.

⚠ **`.xschem/`, `doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md` and
`sky130A/.../debug_st1/` are NOT mine** — all three were in this session's starting
snapshot, and Stage D's receipt says the same of them.

⚠ **And the three Stage-D suite files I did NOT touch are proved untouched, not merely
unintended**: their diff-vs-HEAD line counts are **byte-for-byte the figures this session
started with** — `test_calc_scratch_reuse.tcl` **82**, `test_calc_skeleton.tcl` **22**,
`test_calc_widgets.tcl` **11**, unchanged while `src/calculator.tcl` went 452 → 673,
`test_calc_engine.tcl` 369 → 472 and `tests/run_regression.tcl` 29 → 48. The sabotage
harness's restore set deliberately did not include them either, so nothing in this stage
could have written them.

**Nothing else moved, and that is checked rather than intended:**

| file | md5 now | why it is proved |
|---|---|---|
| `src/save.c` | `e0429f722665b90b5a2689423f346bda` | sabotaged once (`C2-3`), rebuilt, run, restored, rebuilt again |
| `src/xschem` | `869e05b44d6bb4014335ea2128e52edf` | relinked after the `C2-3` cycle; byte-identical, and `make -C src -q xschem` now answers 0 |
| `tests/headless/data/calc_fixture.raw` | `23bf926f6def8fe4525a881e80fcdd1a` | equals `git show HEAD:…` — read only, never written |

`/usr/bin/grep -c 'xschem save\|saveas'` is **0** in both `src/calculator.tcl` and
`tests/headless/test_calc_plot.tcl`: there is no save instrument anywhere in this stage.
The new band `PL7b` writes its second raw into the suite's own `test_scratch` directory and
nowhere else. `tests/headless/.scratch/` is empty after the runs, and every probe and
capture `--logdir` pointed into my own scratch directory. **Nothing is committed, pushed or
stashed.**

---

## 14. What I got wrong during the stage

1. ⚠ **I edited `src/calculator.tcl` before taking a copy of the file I had been handed**,
   and then needed the pre-change product to show a red. Recovered by reversing every edit
   programmatically and **proving the reconstruction by md5**
   (`6e2c706073d1e977a0ca72ef52fa0154`) — which also caught **two stray `#` lines** my
   first two reversals left behind, each from a comment block whose insertion had added a
   blank comment line. Without the md5 check I would have shown a red against a file that
   was *nearly* the handover. **Copy the handover first; a hash is the only proof a
   reconstruction is one.**
2. **A row of mine asserted the success sentence must not contain the token at all**, and
   the fixed product reddened it: `Plotted v(xdbonly) (Append).` names the vector that
   landed. The row wanted the absence of the *refusal*, not of the *name*.
3. **Two of my own new fences measured nothing and I only found out by reading the
   zeroes** — `Q4b` (the `string trim`) and `Q11` (the widget-versus-hardcoded list). Both
   are now rows. This is the third round of this batch where the useful information was a
   zero rather than a count.
4. **I reasoned about `P6` for several paragraphs before measuring it**, and the reasoning
   was wrong in a specific way worth recording: I assumed the suite's context at press time
   was `.drw`, because that is where `PL1` puts it. It is the viewer, for every band, and
   the reason is `wviewer::open`'s own side effect plus `enter_ctx`'s fast path. The probe
   answered in one run what the reasoning had not.
5. **The handover listed four false claims and there were five.** The fifth
   (`calc::eval_click`'s `%<n>` paragraph) was found only by reading band `CE12`'s rows
   against the prose beside them. A comment that contradicts a row four hundred lines away
   is invisible to every runner.

---

## 15. What I did NOT do, and why

* **No T1 run.** The driver's job, and the brief forbids it. §12 derives this stage's own
  contribution over real captures and is explicitly **not** a prediction of the trailer.
* **No change to `src/wave_viewer.tcl`.** F2 says the viewer is not wrong and ruling 24
  stands; the Calculator was made honest instead. `test_wave_modes` and the other nineteen
  reachable wave suites are `ALL PASS`.
* **No C change, no rebuild of the product.** `src/save.c` is untouched except by sabotage
  `C2-3`, which rebuilt in both directions and left its md5 at
  `e0429f722665b90b5a2689423f346bda`.
* **No new capability, no refactor, no new line of inquiry.** The two new procs
  (`calc::plot_dest_offered`, `calc::plot_dest_dropped`) exist only to make the F2
  cancellation audible and to keep `plot_rpn` free of `.calc` paths (which is what keeps the
  `CE8`/`PL9` guarded/pure split meaningful).
* **F6(a) and F6(b) are DECLARED, not closed**, as the task pre-authorised — each with its
  measurement and each pinned by rows, so closing either reddens and forces the declaration
  to be corrected. **F6(c) was made one thing instead of declared**, because the fix is one
  line in the one site that builds the dict.
* **The `xschem raw set` sentinel is still not in the product** (Stage D §4d). It would
  close the arity class as well as the other two, and it is still a stage of its own.
* **Nothing verified by eye, and no `look` debt incurred.** Every claim here is a row, a
  quoted command output, or a predicate lifted from the tree. **One line of unverified:
  that the trace of a cross-database signal is DRAWN is eyeball-only** — what is asserted
  is the model, the foreign database's path and type on the trace, and that the regenerate
  returned without error.
* **One `rule` debt filed**, `calc_plot_dest_honesty_d2`, as an ADDITION to
  `calc_plot_wording_phase3` — never an overwrite. The ledger was backed up first
  (`cp -r ~/.claude/xschem_owed …/scratchpad/D2/owed_backup_before`) and
  `diff -rq backup ~/.claude/xschem_owed` afterwards reports exactly one difference,
  `Only in …/rule: calc_plot_dest_honesty_d2`. **I cleared nothing, and nothing else in the
  ledger moved.**
* **No permission prompt denied me anything.**
* **Nothing is committed, pushed or stashed.**

---

## 16. What the next stage must know

1. ⚠⚠ **TWO SABOTAGES THAT READ AS THE SAME SENTENCE WERE NOT THE SAME EDIT**, and that is
   how `P6` came to be recorded at 15 reds while the loan it names was fenced by nothing.
   When a receipt describes a sabotage in prose, the prose is not the mutation. This
   stage's harness keeps the mutations as data (`…/scratchpad/D2/table*.json`), which is
   the thing worth copying forward — and it is in scratch, so **the next stage has to
   rebuild it unless it is moved somewhere durable**.
2. ⚠ **`wviewer::open` LEAVES THE XSCHEM CONTEXT IN THE VIEWER.** Any suite that means to
   measure a context loan must switch somewhere else first **and assert the work
   succeeded**, not just that the context came back. The context is the symptom; the work
   is the fence.
3. ⚠ **`wviewer::add_trace`'s SINGLE-NAME arm and its EXPRESSION arm ask different
   questions**, and that asymmetry is now load-bearing in `calc::rpn_bad_token`. If spec
   §D1 is ever extended to expressions, the `$n == 1` gate there must widen in the same
   change; `CE13` has the row that will redden.
4. ⚠ **R607 NOW HAS FOUR DECLARED BLIND SPOTS, not two**: a negative `del()` delay, a
   `\r`/`\v`/`\f`-joined token, and **arity** in both its forms. All four are rows in
   `CE13`. The `xschem raw set` sentinel closes the first and third; nothing cheap closes
   arity.
5. ⚠ **`calc::plot_dest_dropped` reads W13's own `-values`.** Widening W13 to the viewer's
   four destinations needs **no edit** to that proc — but it reddens `PL5e`, which asserts
   the clause is present for `newtab` today. That red is the declaration asking to be
   corrected, not a regression.
6. **The Plot answer dict's `dest` is now always a CODE or empty.** Phase 6 can switch on
   it. `PL2b` is the row that keeps it that way.
7. **`test_calc_plot` lifts `ce_decomment`/`ce_code` out of `test_calc_engine.tcl`.**
   Renaming either proc in that file breaks the lift — loudly, by name, in `PL9`'s first
   row, which is the point.
8. **Band `CE8`'s pure/guarded split is an EXACT list.** Any new `plot_*`/`dest_*` proc
   lands in one half and the row has to be updated in the same change; `plot_dest_offered`
   (guarded) and `plot_dest_dropped` (pure) are this stage's two.
