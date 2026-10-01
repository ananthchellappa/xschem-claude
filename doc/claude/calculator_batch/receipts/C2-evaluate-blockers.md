# Receipt C2-evaluate-blockers — closing the five findings against Stage C's Evaluate

Stage label `C2-evaluate-blockers`. Branch `fluid-editing`, tree at `a68b4d25`, **nothing
committed, pushed or stashed**. All scratch under `…/scratchpad/C2/`.

Scope was closed to E1–E5. Everything below is one of those five, with two exceptions
named as scope judgements in §9.

⚠ **The two WRONG ANSWERS are fixed and both were reproduced before being touched.** E1's
`= 6.5 (at the cursor)` and E2's `= -nan (at the last point)` were each driven out of the
real binary, by hand, before a row existed — and then as rows that were red.

⚠ **AND THE SABOTAGE ROUND FOUND TWO DEFECTS I HAD INTRODUCED**, one in the product's
fence and one in a suite about to be registered. Both are in §5 and §6, and they are the
most useful part of this stage.

---

## 0. The verdicts, both arms

| suite | `--nogui` | display (`:99`) | before this stage |
|---|---|---|---|
| **`test_calc_engine`** (`hcases`, RE-REGISTERED) | `ALL PASS (217 checks)` | `ALL PASS (217 checks)` | 120 / 120 |
| **`test_calc_scratch_reuse`** (`hcases`, RE-REGISTERED) | `ALL PASS (49 checks)` | `ALL PASS (49 checks)` | 46 / 46 |
| `test_calc_skeleton` | `ALL PASS (0 checks)` | `ALL PASS (548 checks)` | 0 / 548 |
| `test_calc_widgets` | `SKIP (self-skipped: no X)` | `ALL PASS (246 checks)` | skip / 246 |
| `test_calc_buffer` | `SKIP (self-skipped: no X)` | `ALL PASS (130 checks)` | skip / 130 |
| `test_divis_zero_1628` | `ALL PASS (33 checks)` | `ALL PASS (33 checks)` | 33 / 33 |
| `test_del_negative_arg` | `ALL PASS (24 checks)` | `ALL PASS (24 checks)` | 24 / 24 |
| `test_op_annot` (SHORT path, the real tree) | `ALL PASS (486 checks)` | `ALL PASS (493 checks)` | 486 / 493 |
| `test_registered_banner_1626` | `ALL PASS (10 checks)` | `ALL PASS (10 checks)` | 10 / 10 |

`RESULT: 10/10 runs passed (2 skipped)` headless and `RESULT: 9/9 runs passed` on the
display arm, through the armed spelling `tests/headless/run_suites.sh [--nogui] <t>`,
attached to the persistent dev display `:99` and left exactly as found (`status` only).
Neighbours that read `tests/run_regression.tcl` or scan the tree, all `--nogui`:
`test_audit_classifier` **75**, `test_scratch_home_note` **22**, `test_issue_stamp` **102**,
`test_home_isolation` **116** — all `ALL PASS`, none moved.

**The evidence runs above were taken on a binary rebuilt after the last `src/save.c`
write**, and `make -C src` is a no-op on the tree as it stands. §6 records why that
sentence had to be checked rather than assumed.

---

## 1. What I changed, by symbol

### `src/calculator.tcl`

| symbol | what changed |
|---|---|
| **`calc::eval_cursor_point`** | **E1.** Now requires BOTH a non-negative point AND a non-negative `annot_sweep_idx` — the third field of `xschem raw annot`. The comment above it, which asserted as measured fact that "no headless route sets `annot_p`", is replaced by the two routes that do and by the measurement of what the false sentence cost. The `$p < 0` half is **declared unfenced** in the code, because sabotage `C2-1b` reddened nothing. |
| **`calc::eval_finite` (NEW)** | **E2.** The one site that knows which spellings are numbers to show. A **positive** test for a finite decimal, not a denylist of non-finite spellings, because `%g` spells those differently on glibc and on the MSVC runtime `XSchemWin/` targets. Its own comment carries that reasoning and the measurement. |
| **`calc::eval_msg`** | **E2.** One new kind, `nonfinite`: *"Evaluate: the result is not a finite number (`<v>`)."* |
| **`calc::eval_rpn`** | **E2.** One guard added after the existing numeric check, routed through `calc::eval_finite`. R402 is unaffected: the destination is already deleted by the time this arm is reached. |
| **`calc::eval_click`** | **E5.** Two declared limits added to its comment — Evaluate always reports dataset 0, and the `%<n>` dataset spelling reads as a silent zero. **No code change.** |
| **`calc::inert`** | **E4(a).** The doc comment no longer says Evaluate "falls through to this proc when there is one". |
| **`calc::build_mode`** | **E4(b).** The comment above the Plot/Eval loop no longer says "a press WITH a result still lands on the phase-3 stub". |

### `src/save.c`

| symbol | what changed |
|---|---|
| **`plot_raw_custom_data()`**, the `stack1[i].i == COND` arm | **E3.** `dbg(0, …)` → `dbg(1, …)`, matching every other `dbg()` in that function. **Rebuilt.** The comment states the shape and quotes no count, because band `CE11` counts the lines every run. |

### `tests/headless/test_calc_engine.tcl` — 120 → **217** checks

* sources `tests/headless/scratch.tcl` for `test_scratch` (band `CE9` must write a
  multi-point op/dc fixture; nothing committed in the tree is one). New helper
  **`ce9_cfun`**, which lifts a C function body by identity with comment lines dropped.
* **`CE0`**'s cursor row **renamed and widened** to what it actually measures — "a READ
  leaves all three annotation fields cleared" — and it now says in its own name that it
  says nothing about other publishers.
* **`CE3`** — E4: the `i(@m1[id])` row's name and comment made true, and **two rows added**
  so the claim is re-measured instead of asserted.
* **`CE4`**'s out-of-range row **strengthened to pin WHICH refusal** (see §5, SAB `Q`).
* **`CE7`**'s post-mint refusal row, same strengthening, same reason.
* **`CE8`**'s "did not reach the engine" row **replaced by a counting shim** on
  `calc::eval_rpn`, with a control leg and a mint-serial axis; `pure` gained `eval_finite`.
* **`CE9` (NEW)** — R604 against the REAL `annot_p`, driving both headless publishers.
* **`CE10` (NEW)** — the non-finite refusal, including `calc::eval_finite` driven directly
  with the MSVC spellings this machine cannot produce.
* **`CE11` (NEW)** — the `?` arm's per-point chatter, COUNTED in-process through
  `xschem log`, with a control leg proving the capture sees a `dbg(0)` line.
* **`CE12` (NEW)** — E5's two declared limits, pinned as rows.

### `tests/headless/test_calc_scratch_reuse.tcl` — 46 → **49** checks

**`SR5`**: the comment stripper is now one proc (`sr_code`) used by **all four** scans, with
a negative control. It had stripped comments for the adjacency scan and handed three
namespace-wide scans the raw `info body`. See §6 — this was a live false red.

### `tests/headless/test_calc_skeleton.tcl` — comment only, 548 checks unmoved

E4: the `S18` comment's tail — "the phase-3 stub is still what a press WITH a result
reaches — S27 drives that arm" — is gone, with the correction and a pointer to this receipt.

### `tests/run_regression.tcl` — the two `hcases` entries RE-ADDED

Counted by the method CLAUDE.md prescribes (find `set <n> [list`, pipe through
`/usr/bin/grep -o '"[^"]*"' | wc -l`, comment lines dropped): `tcases` **3**, `hcases`
**93**, `dcases` **23**, plus `xschemtest` → **120 cases**. The committed comment block
describing these two suites as the Calculator's only `hcases` entries was **true again**
only after this edit; it had been committed at `c2cdb307` while the entries themselves were
held back.

---

## 2. E1 — `annot_p >= 0` is not "a cursor exists"

### What was measured, by hand, before any row existed

A 3-point `Operating Point` raw (the shape `test_op_annot` row `T26` uses; `read_dataset()`
rewrites it to `sim_type dc`), `v(d)` = 6.5 / 6.6 / 6.7, through the real binary:

```
read: 1  sim_type=dc points=3 datasets=1
annot BEFORE update_op: -1 0 -1
eval BEFORE: ok 1 value 6.6999998 at last point 2 dataset 0 ...
fmt  BEFORE: = 6.6999998  (at the last point)
update_op -> 1
annot AFTER update_op: 0 0 -1
eval AFTER: ok 1 value 6.5 at cursor point 0 dataset -1 ...
fmt  AFTER: = 6.5  (at the cursor)
fmt  AFTER (x2): = 13  (at the cursor)
```

So the task's three numbers reproduce exactly, and the second and third are **wrong
answers wearing a false explanation**: the honest answers are 6.7 and 13.4, and there is no
cursor anywhere.

### ⚠ The claim that caused it was false TWICE, not once

The proc's comment said *"`annot_p` is set only by that publisher, which runs from a graph
redraw; no headless route sets it"*. **Two** headless verbs set it:

* **`xschem update_op`** → `update_op()` (`src/save.c`) sets `xctx->raw->annot_p = 0` for
  any op/dc database. That function's own comment already records (issue **0862**) that its
  guard tests the **type only**, so a genuine multi-point `.dc` sweep publishes its first
  step as the operating point.
* **`xschem annotate_at <t>`** → `backannotate_at_time()` → `backannot_pos_at()` →
  `backannotate_cursor_b_in_db()` (`src/callback.c`) — **the graph's own cursor-B
  publisher**, reached with a requested time instead of a pointer position. Measured:

```
annot: -1 0 -1
annotate_at 0.003 -> 1
annot after annotate_at: 30 0.003 0
cursor_point: 30
eval: ok 1 value 1.5 at cursor point 30 dataset -1 ...
```

**That second route is the find that changes the shape of the fix**, and nothing in Stage C
or the task had it: it means the cursor arm can be driven for real on the gating arm, and
that a fix which simply ignored `annot_p` would be wrong. Every CE9 row below drives one of
these two verbs; **no proc is renamed aside anywhere in the band.**

### The discriminator, verified in the C and through the verb

`xschem raw annot` answers `"<annot_p> <annot_x> <annot_sweep_idx>"` (`src/scheduler.c`,
the `annot` arm of the `raw` verb). In `backannotate_cursor_b_in_db()` the publisher does
`sweep_idx = get_raw_index(...); if(sweep_idx < 0) sweep_idx = 0;` and then stamps
`raw->annot_sweep_idx = sweep_idx` beside `raw->annot_p = p` — so a real cursor always
leaves the third field **>= 0**. `update_op()` never names the field; the read/reset paths
set it to -1. Both halves are now rows:

```
ok:   CE9 exactly ONE site in the C sets annot_sweep_idx to anything but -1, and it is the cursor-B publisher in callback.c
ok:   CE9 ...and update_op() publishes annot_p without naming annot_sweep_idx at all, which is why the third field discriminates
```

The second of those reads `update_op()`'s body through `ce9_cfun`, **with comment lines
dropped**, because the whole content of the row is that prose mentioning a field must not
count as code writing it.

### ⚠ One state is NOT separated, and is declared rather than guessed at

An `update_op` on a database where a cursor had **already** been published leaves that
cursor's `annot_sweep_idx` in place while moving `annot_p` to 0, so the proc reads point 0
and calls it a cursor. The C overwrites `cursor_b_val[]` in the same breath, so by then the
whole published annotation is the operating point's and nothing in Tcl can recover the
cursor's. Separating them needs the C to stamp or clear the third field, which is outside
this file and outside this stage's scope. Declared in the proc's comment; **no row.**

---

## 3. E2 — a non-finite result is not a value to show

Measured before any row:

```
RPN {v(ramp) -1 * sqrt()} -> ok=1 value=-nan fmt== -nan  (at the last point)
RPN {1e300 1e300 *}       -> ok=1 value=inf
RPN {1e300 1e300 * -1 *}  -> ok=1 value=-inf
RPN {710 exp()}           -> ok=1 value=inf
string is double -strict nan: 1 / -nan: 1 / Inf: 1 / -Inf: 1
```

So the numeric check `eval_rpn` already ended on vouches for the **shape** of the answer
and not for its being a number to show.

**What it says, and why:** `Evaluate: the result is not a finite number (-nan).` R607's
requirement is read as a principle rather than a literal — R607 is about the engine's `-1`
and about naming the token that failed to resolve, which does not apply here because the
expression *did* evaluate. What carries over is *"a bare 'expression error' is not
acceptable"*, so the refusal **names the spelling it saw**. It is taken through
`calc::eval_refusal`, the same one site every other Evaluate refusal uses, so `eval_fmt`
prints it with no `=` in front — identical in shape to how Evaluate already refuses when
there is no result. A `rule` debt is filed (§8).

**⚠ The predicate is a POSITIVE test, and that is the part a row had to fence.** `%g`
spells a non-finite differently per C library: glibc gives `inf`/`-inf`/`nan`/`-nan`, the
MSVC runtime `XSchemWin/` targets gives `1.#INF`/`-1.#IND`/`1.#QNAN`. A denylist written on
this machine passes every Windows spelling straight through **and every behavioural row
stays green** — which is why `calc::eval_finite` is a proc and `CE10` drives it directly
with the MSVC spellings as well as the glibc ones, plus a matching list of finite
spellings so the predicate is not merely 'refuse anything unusual'. Sabotage `C2-2b` is exactly that denylist, and it reddens six
rows, all of them in the direct-call legs.

**No division-by-zero rows were added.** Issue 1628 fixed that at the engine and
`test_divis_zero_1628.tcl` (33 checks) covers it; I read that suite. Its band `DZ1e`'s
sentence — *"NO ROW HERE ASSERTS A GARBAGE VALUE: every row asserts the DEFENSIBLE value"* —
is the reason `CE10` asserts a refusal rather than a particular non-finite spelling's value.

---

## 4. E3 — the `?` arm's per-point flood

Measured over the committed fixture's transient arm, with the operand triples bracketed by
markers and `errfp` captured:

```
captured total lines: 203
cond lines: 202
other lines: {update_op(): 'tran' is not an operating point database, publishing nothing}
```

**202, not 101** — one line per point of **both** datasets, because `raw_add_vector()`
evaluates over `0 .. raw->allpoints - 1`. §10 item 2 of `receipts/C-evaluate.md` says 101;
**that receipt is a dated record and is not edited — the correction is here.** The 101
figure is the per-dataset point count, which is what a reader would reach for and what
makes the error easy to repeat.

The fix is `dbg(0` → `dbg(1`, rebuilt. The fence **counts**, in-process: `xschem log <f>`
points the C `errfp` at a file and `xschem log` with no argument puts it back
(`src/scheduler.c`, the `log` verb) — which is the stream `dbg()` writes through
(`src/util.c`). The control leg uses `update_op()` refusing a transient, a `dbg(0)`
one-liner, so a zero count is a measurement and not a broken instrument. A structural row
reads the arm's level out of the C as a second axis, with comment lines dropped.

⚠ **The failure message is capped at three distinct lines on purpose.** A regression here
prints one line per point, and a row that echoed them all would put 202 lines of product
chatter into T1's verdict file — the same noise this band removes, arriving through the
fence. The first red capture did exactly that before it was capped.

---

## 5. E4 — the false sentences, and how I searched for a fourth

### (a) and (b), both in `src/calculator.tcl`, both fixed

`calc::inert`'s doc comment and `calc::build_mode`'s Plot/Eval comment. Both now say
Evaluate runs the engine, and both record that the sentence they replace was corrected in
`test_calc_widgets`' CW13 by the stage that built Evaluate and left behind in the product
file it was rewriting.

### (c) the receipt's 101 → 202

Corrected in §4 above. `receipts/C-evaluate.md` is **not edited.**

### ⚠ HOW I SEARCHED FOR A FOURTH, AND I FOUND THREE MORE

Three greps, all with `/usr/bin/grep`, over `src`, `tests`, `doc/claude/specs` and
`PLAN.md`, excluding `receipts/` (dated records):

1. `-iE 'phase[- ]3 stub|phase-3 stub'` — the phrase itself.
2. `-iE 'falls? through|lands on'` filtered to lines also naming eval/inert/stub — the
   *shape* of the claim, so a paraphrase is caught.
3. `-iE 'eval[^a-z]{0,20}(inert|not implemented|stub)'` and its mirror, plus
   `'calc::inert Eval'` — the claim stated from the other side.

Three live copies came back beyond the two in the task:

| # | where | the sentence | what I did |
|---|---|---|---|
| 4 | `tests/headless/test_calc_skeleton.tcl`, the `S18` comment | *"the phase-3 stub is still what a press WITH a result reaches — S27 drives that arm"* | **FIXED** — see §9 for the scope judgement |
| 5 | `doc/claude/specs/calculator.md`, the **W12** row of §4's widget table | *"…with a result it falls through to the phase-3 stub, because item 10 settled WHICH database Evaluate reads and none of WHAT it computes."* | **RECORDED, NOT FIXED** |
| 6 | `doc/claude/specs/results_selection.md`, **R503e** | *"`calc::eval_click` refuses when there is no result and otherwise **falls through to `calc::inert Eval 3`** — the computation is `doc/claude/calculator_batch` phase 3's and item 10 builds none of it."* Plus its next sentence, which pins **S27** by a row name that no longer exists: *"Pinned S27 *"Evaluate WITH a result falls through to the phase-3 stub"*"* | **RECORDED, NOT FIXED** |

**Both spec sentences are stated in the present tense about current product behaviour and
both are now false.** The minimal corrections, for whoever takes them:

* `calculator.md` W12: replace *"with a result it falls through to the phase-3 stub, because
  item 10 settled WHICH database Evaluate reads and none of WHAT it computes"* with *"with a
  result it computes (R603/R604, calculator_batch PLAN 3.2); item 10 settled only WHICH
  database it reads"*.
* `results_selection.md` R503e: the clause *"otherwise falls through to `calc::inert Eval
  3`"* and the S27 row name both need replacing; S27's current form asserts the engine step
  and two borrowed contexts, not a stub. ⚠ R503e is a **ruling record of what item 10
  built**, so the sentence may be partly historical by intent; that is the judgement I did
  not make.

One further copy exists in `doc/claude/results_batch/receipts/10-calculator-consumes-selection.md`
and in `doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md`. The first is a
dated receipt (leave it); the second is an untracked survey that was in this session's
starting snapshot and is not mine.

`tests/headless/test_calc_skeleton.tcl`'s **other** mention at the `S27` band is already
correct — it says the old form *used to* assert the stub — so it is not a seventh copy.

### The two test-file claims the task named

* **`CE3`'s `i(@m1[id])` row.** Measured: through `xschem raw value` (`%.8g`) the fixture
  answers `0.00087035`, which is the hand value 870.35 µA **bit for bit** — relative error
  `0.0`. So the row name's *"loosened per the README"* was false (it ran at its neighbours'
  1e-7) and the comment's *"a row using its neighbours' tolerance would be red on a correct
  fixture"* was being disproved by the row every time it passed. The README's 3.5e-9 is
  real and visible through `xschem raw values` (`%.16g`), which answers
  `0.0008703500030099997`. **All three facts are now rows**: the 1e-7 row, an **equality**
  row (`tol 0.0`) proving no tolerance is being spent, and a row asserting the 16-digit
  reader *does* see the disagreement (passes at 1e-7, fails at 1e-9). Sabotage `C2-4`
  "simplifies" the 16-digit reader to the 8-digit one and reddens the third.
* **`CE8`'s "did not reach the engine either".** It was checked only by `[leaked] eq {}`,
  which a *successful* evaluation also satisfies, because `eval_rpn` deletes its destination
  on the success path. Replaced by a **counting shim** on `calc::eval_rpn` — something the
  success path cannot satisfy — with a control leg proving the shim counts, a mint-serial
  axis (`calc::tmpvec` increments before the engine call and nothing puts it back), and the
  `leaked` axis kept because it is free. Sabotage `C2-5`+`C2-5b` (the `has_win` guard
  dropped **and** `rpn_of_buffer` defaulting to an expression, which is the only way the
  engine is actually reachable with no window) reddens 3 `CE1` + 3 `CE8` rows.

---

## 6. The red, quoted verbatim

Both new bands and every strengthened row were written **before** any product change. From
`scratchpad/C2/red2.log`, on the unfixed tree, **19 reds, no aborts, no
`UNEXPECTED ERROR`, no `BGERROR`** — the rows failed, they did not throw:

```
FAIL: CE9 ⚠ THE DEFECT: an operating-point publish is NOT a cursor, so eval_cursor_point must still answer -1 -> {0} (exp {-1}) : FAIL
FAIL: CE9 ⚠ THE DEFECT, AS A NUMBER: the answer is still 6.7 at the LAST point, not 6.5 at a cursor nobody put there -> {{off:{6.5} rel=0.029850746268656744} cursor 0} (exp {ok last 2}) : FAIL
FAIL: CE9 ...and an EXPRESSION reports 13.4, not 13 -> {{off:{13} rel=0.029850746268656744} cursor} (exp {ok last}) : FAIL
FAIL: CE9 ...and the sentence says `at the last point`, which is the half of R604 the user reads -> {0 1} (exp {1 0}) : FAIL
FAIL: CE10 sqrt of a negative -> NaN: refused, not reported as a value (v(ramp) -1 * sqrt()) -> {1} (exp {0}) : FAIL
FAIL: CE10 ...and the refusal NAMES what it saw rather than saying 'expression error' (v(ramp) -1 * sqrt()) -> {0 0} (exp {1 1}) : FAIL
FAIL: CE10 ...and eval_fmt prints the refusal, with no `=` to read as an answer (v(ramp) -1 * sqrt()) -> {1 1} (exp {1 0}) : FAIL
FAIL: CE10 overflow -> +Inf: refused, not reported as a value (1e300 1e300 *) -> {1} (exp {0}) : FAIL
FAIL: CE10 overflow negated -> -Inf: refused, not reported as a value (1e300 1e300 * -1 *) -> {1} (exp {0}) : FAIL
FAIL: CE10 exp past DBL_MAX -> +Inf: refused, not reported as a value (710 exp()) -> {1} (exp {0}) : FAIL
FAIL: CE11 the `?` operand trace is GONE: evaluating a ternary over 202 points writes ZERO lines of it -> {202} (exp {0}) : FAIL
FAIL: CE11 ...and nothing else per-point either: the whole captured debug stream is empty for one Evaluate -> {202 {{7 1 9}}} (exp {0 {}}) : FAIL
FAIL: CE11 the COND arm's dbg() is level 1, like every other dbg() in plot_raw_custom_data() -> {0} (exp {1}) : FAIL
```

**The non-vacuity leg of `CE9` was GREEN on the broken tree**, which is what constrained
the fix in both directions rather than letting it be "ignore `annot_p`":

```
ok:   CE9 `xschem annotate_at 0.003` is a HEADLESS publisher of a REAL cursor
ok:   CE9 ...and it stamps all three fields: point 30 ... and a sweep index that is NOT -1
ok:   CE9 eval_cursor_point reads the REAL annot_p -- no proc was renamed to reach this row
ok:   CE9 R604 with a REAL cursor: v(div) = v(ramp)/2 = 1.5 at absolute point 30, and it says `cursor`
```

**E4's and E5's items have no red and cannot have one**: a false comment is the one artefact
in this tree that nothing re-runs, which is the whole reason E4 exists. What they have
instead is the **new rows** that make each corrected claim re-measured, and a sabotage each.

### ⚠ TWO DEFECTS I INTRODUCED, both caught by running rather than by reading

**(i) A row of mine was red on a correct tree, for one capture.** `CE8`'s mint-serial row
read `::calc::tmpn` *after* the control leg and the non-vacuity row, both of which mint:
`-> {1 0} (exp {1 1})`. A false red is the one thing a registered fence must never be. The
serial is now snapshot immediately after `eval_click` returns, and the comment says why.

**(ii) `SR5` of `test_calc_scratch_reuse` false-redded ON A COMMENT, in the full headless
pass**, after every `test_calc_engine` run had been green:

```
FAIL: SR5 ...and exactly ONE proc calls eval_rpn, the one that holds the context loan
     -> {eval_cursor_point eval_in_token} (exp {eval_in_token}) : FAIL
```

The cause is the defect family this whole batch keeps being refuted for. `SR5` stripped
comments for its **adjacency** scan and then handed **three namespace-wide scans** the raw
`info body` — so the moment `calc::eval_cursor_point` grew an in-body comment naming
`calc::eval_rpn` (my declared-limit note, saying that proc re-tests the point itself), the
caller row read **prose as code**. The band's own comment cites `rb_decomment` and row `RB5`
of `test_registered_banner_1626` — *"a complete command parked in a tail comment is read as
code by any line scanner"* — and then reproduced it in the very next scan. Fixed at the
cause:
one `sr_code` proc, a decommented body map built once, all four scans using it, plus a
**negative control** that poisons a body with three commands mentioned only in comments
(whole-line and tail) and asserts they survive the raw body and are gone from the stripped
one. 46 → 49 checks. ⚠ **It would have been cheaper to reword my comment, and that would
have left the false red in the tree for the next person's comment to trip.**

**And the process lesson from (ii) is sharper than the fix:** I re-ran only the suite I was
editing. The row that broke was in its sibling, and nothing but the full pass would have
found it.

---

## 7. Sabotages — Stage C's twenty-one re-run, plus eight of my own

Applied by a scripted patcher that **refuses to apply unless its anchor text is unique in
the file**, with every anchor checked for uniqueness before the round rather than at apply
time; suites run; files restored from pristine copies; **md5 verified after every one**.
Harness in scratch, not in the tree. `C2-3` is a C change and got its own rebuild in both
directions.

| # | the plausible wrong implementation | reds | bands |
|---|---|---|---|
| **A** | `tmpvec` returns a FIXED name | 6 | `CE2`×4, `SR3`×2 |
| **B** | `tmpvec` does not skip an existing name | 1 | `CE2` |
| **C** | the pre-engine guard removed, the belt kept | 1 | `SR4` (the data row only) |
| **C+D2** | **both** guards removed | 6 | `SR4`×5, `SR6` |
| **D2** | the `raw add` belt alone | **0** | **declared unfenced in the code** |
| **E** | `rpn_of_text` trims | 2 | `CE1`×2 |
| **F** | `rpn_of_text` collapses whitespace | 2 | `CE1`×2 |
| **G** | `.calc.buf get 1.0 end` | 0 headless, **7** display | `CB6`×7 in `test_calc_buffer` |
| **H** | an engine call between the add and the read | 18 | `SR5` adjacency, `CE7`/`SR6` leak rows, `CE10` |
| **I** | the cursor read passes `$dataset` not `-1` | 4 | `CE4`×2, `CE9`, `CE12` |
| **J** | the cursor branch deleted | 12 | `CE4`×5, `CE6`×3, `CE9`×2, `CE7`, `CE12` |
| **K** | `point $np` instead of `$np - 1` | 68 | wholesale |
| **L** | the `raw del` dropped (R402) | 19 | `CE7`×6, `SR6`×5, … |
| **M** | the `raw del` moved BEFORE the read | 80 | wholesale |
| **N** | `eval_click`'s `has_win` guard dropped | 2 | `CE8`×2 |
| **O** | `eval_click` calls `eval_rpn` directly | 1 headless, **1** display | `SR5` caller row; `S27`'s loan row |
| **P** | `eval_fmt` drops the which-point clause | 3 | `CE4`, `CE9`×2 |
| **Q** | the value's numeric check dropped | 2 | `CE4`, `CE7` |
| **R** | the L2 refusal does not name the destination | 2 | `SR4`×2 |
| **S** | `calc::close` resets the mint's serial | 1 | `CE2` |
| **T** | the dataset range check dropped | 1 | `CE3` |
| **C2-1** | **E1: the `annot_sweep_idx` term dropped — EXACTLY WHAT SHIPPED** | 4 | `CE9`×4 |
| **C2-1b** | E1: the point term weakened to "is it an integer" | **0** | **declared unfenced in the code** |
| **C2-1c** | E1: the discriminator reads `annot_x` (field 1) instead of field 2 | 7 | `CE9`×7 |
| **C2-2** | E2: the non-finite refusal removed | 12 | `CE10`×12 |
| **C2-2b** | **E2: `eval_finite` written as a DENYLIST of the glibc spellings** | 6 | `CE10`×6, all in the direct-call legs |
| **C2-2c** | E2: R607 violated — a generic "expression error" | 4 | `CE10`×4 |
| **C2-3** | **E3: the COND arm's `dbg` level back to 0** (rebuilt) | 3 | `CE11`×3 |
| **C2-4** | E4: the 16-digit reader row "simplified" to the 8-digit one | 1 | `CE3` |
| **C2-5+C2-5b** | E4/`CE8`: the guard dropped **and** the buffer defaulting | 6 | `CE1`×3, `CE8`×3 |

`C2-1` was additionally run against all three display suites: **`ALL PASS` on every one**,
which is correct and worth recording — `test_calc_skeleton`, `test_calc_widgets` and
`test_calc_buffer` do not touch the cursor, so the shipped E1 defect was invisible to
every suite that existed and only `CE9` can see it.

### ⚠⚠ SABOTAGE `Q` WENT GREEN, AND THAT IS THE MOST IMPORTANT LINE IN THIS SECTION

Stage C recorded `SAB-Q` (the value's numeric check dropped) as reddening **2** rows. On my
first round it reddened **0**. The cause is **my own E2 fix**: `calc::eval_finite` also
refuses an empty read, so with the numeric check deleted the product still refused and
still deleted the destination — just with the wrong sentence. `CE4`'s out-of-range row
asked only `[dg $d msg] ne {}` and `CE7`'s asked only `ok`/`leaked`, so both stayed green.

That is CLAUDE.md's *"a fence keyed to a symptom dies quietly when something else cures the
symptom"*, and **nothing detects it automatically** — it was found only because the task
required re-running every sabotage Stage C named. Both rows now pin the **sentence** the
user would get, compared against `calc::eval_msg point 99999` rather than against
"non-empty", and `CE10` gained two rows asserting the two refusals are distinguishable at
all. `Q` reddens **2** again, in the same two bands Stage C recorded.

---

## 8. Registration, and the trailer delta

### Checked against `banner_complete` BEFORE registering, and quoted

The predicate in `tests/banner_rule.tcl` — the only Tcl reader, and the one
`run_regression.tcl` sources — is:

```tcl
proc banner_complete {body} {
  return [regexp -line {^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$} $body]
}
```

Run over **four real captures** (both suites × both arms), through
`tests/banner_rule.tcl` itself and not through `run_suites.sh`:

```
test_calc_engine.disp:        banner_complete=1 banner_died=0 regression_case_failed(0)=0 col0_RESULT=1 col0_OVERALL=1 lowercase_skip=0
   sentinel line: {OVERALL: ok (182 checks)}
test_calc_engine.nogui:       banner_complete=1 banner_died=0 regression_case_failed(0)=0 col0_RESULT=1 col0_OVERALL=1 lowercase_skip=0
test_calc_scratch_reuse.disp: banner_complete=1 banner_died=0 regression_case_failed(0)=0 col0_RESULT=1 col0_OVERALL=1 lowercase_skip=0
   sentinel line: {OVERALL: ok (46 checks)}
test_calc_scratch_reuse.nogui: banner_complete=1 banner_died=0 regression_case_failed(0)=0 col0_RESULT=1 col0_OVERALL=1 lowercase_skip=0
```

**Exactly one column-0 `RESULT:` and one `OVERALL:` per file** — issue **1627**'s shape
re-measured, because a second trailing `RESULT:` would silently rewrite the published check
count. Both files still have one exit path on purpose.

`tests/headless/test_registered_banner_1626.tcl`, which gates registration, is
`ALL PASS (10 checks)` on both arms **after** the entries went in.

### The trailer delta, derived from `summarize_all`'s OWN regexp arms

Method: capture each case exactly as T1's `hcases` loop does
(`--nogui --pipe -q --script`, stdout and stderr together, HOME armed through
`tests/headless/test_home.sh`), then **lift `summarize_all` and `t1_carry_line` out of
`tests/run_regression.tcl`'s own text** and run the lifted proc over that capture. No figure
below is quoted from a receipt.

```
lifted: t1_carry_line (5 lines)
lifted: summarize_all (89 lines)
--- the lifted summarize_all's arms, as it spells them ---
>> if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]} {
>> } elseif { [regexp {^(NOGOLD|NODISPLAY)} $line] } {
>> } elseif { [regexp {^skip:} $line] } {
>> } elseif { [regexp {^RESULT:} $line] } {
>> } elseif { [banner_complete $line] && [regexp {\([^)]*\)} $line] } {
=== test_calc_engine.nogui: lines=246 counted-shape=0 lowercase(^skip:)=0 any-case(^skip)=0 ^RESULT:=1 NOGOLD/NODISPLAY=0
    banner_complete=1 banner_died=0 regression_case_failed(0)=0
    summarize_all returned: 0 ; blocks +1 ; skips +0
test_calc_engine.nogui
RESULT: ALL PASS (217 checks)
Total num fail: 0

=== test_calc_scratch_reuse.nogui: lines=56 counted-shape=0 lowercase(^skip:)=0 any-case(^skip)=0 ^RESULT:=1 NOGOLD/NODISPLAY=0
    banner_complete=1 banner_died=0 regression_case_failed(0)=0
    summarize_all returned: 0 ; blocks +1 ; skips +0
test_calc_scratch_reuse.nogui
RESULT: ALL PASS (49 checks)
Total num fail: 0

TOTAL t1_blocks=2 t1_skips=0
```

**This stage's contribution, derived:** **+2 cases, +2 blocks, +0 counted failures,
+0 `^skip:` lines, +6 verdict lines** (two blocks × 3 lines: the case label, the published
`RESULT:` and `Total num fail:`). Relative to the driver's committed baseline **118/117/0/8**
at `c2cdb307` that gives **120 cases / 119 blocks**, counted by the prescribed method
(`tcases` 3 + `hcases` 93 + `dcases` 23 + `xschemtest`).

⚠ **This is a derivation over my own two suites' output, not a prediction of the trailer,
and in particular NOT a prediction of `skips=`.** CLAUDE.md records several occasions where
careful reasoning about registration shape got that figure wrong — most recently issue 1625,
where an adversarial verifier and the driver both predicted movement and both were wrong.
What I measured is that **my** two cases contribute **zero** lines the `^skip:` arm matches
in either arm, and `any-case(^skip)=0` too, so there is nothing of either spelling to be
wrong about. Every other case is unchanged: the only shared file I touched is
`tests/run_regression.tcl`, and I added two entries and one comment paragraph to it.
**Read the trailer.**

Published check counts that move inside existing blocks, relative to the committed baseline:
`test_calc_skeleton` 546 → **548**, `test_calc_buffer` 121 → **130** (both Stage C's, already
in the tree when I arrived), and the two new blocks publish **217** and **49**. A check-count
change moves no line count.

### The `rule` debt

One filed, `calc_eval_nonfinite_sentence`, as an **addition** to the existing
`calc_eval_wording_phase3` rather than an overwrite of it — the pattern the ledger already
uses for `0960_catchall_sentence`. It carries the sentence verbatim, the measurement that
justifies it, the alternative readings, and the observation that **rule debt
`1245_B1_nonfinite_render` asks the same question for the RDW's operating-point column**, so
the two surfaces should probably get one answer. The ledger was backed up first
(`cp -r ~/.claude/xschem_owed …`). **I cleared nothing.**

---

## 9. Two scope judgements, stated at the moment of departing

Scope was closed to E1–E5. I departed from it twice and both are small, deliberate and
reversible:

1. **I fixed `tests/headless/test_calc_skeleton.tcl`'s false comment** (copy #4 of E4(b)'s
   sentence) rather than only recording it. Reason: that file is already in this change set,
   it is a registered `dcases` entry, and shipping a sentence I had just proved false is the
   exact defect E4 exists to remove. It is a comment; no row moved; 548 checks unchanged.
2. **I added two rows and a helper to `SR5` of `test_calc_scratch_reuse`** beyond the task's
   list, because a comment of mine turned that row into a false red (§6(ii)). Rewording my
   comment would have been in scope and would have left the defect for the next person.

**I did NOT touch either spec.** Both false sentences are recorded verbatim in §5 with their
minimal corrections, including the one judgement I declined to make (whether R503e's clause
is historical by intent).

---

## 10. What I did NOT do, and why

* **No T1 run.** The driver's job and the brief forbids it. §8 is the unit-level substitute
  for *scoring*, not for *running*.
* **No expression evaluator, no parser, no second tokeniser.**
* **No division-by-zero work.** Issue 1628 closed it at the engine; `test_divis_zero_1628`
  (33 checks, read in full) owns the ground.
* **The fixture was not regenerated and not touched.** `md5 23bf926f6def8fe4525a881e80fcdd1a`
  before and after, byte-identical. No `xschem save` or `saveas` anywhere in this stage;
  zero occurrences in either suite.
* **Nothing is committed, pushed or stashed.**
* **E5's two gaps are declared, not built.** Evaluate reporting dataset 0 needs the `Family`
  pick scope, which is PLAN phase 6 and still `calc::inert … 6`; the `%<n>` silence needs
  R607's token validator, which is PLAN 3.4. Both are rows in `CE12` so a later phase that
  closes either reddens and has to correct the declaration.
* **`update_op`-after-a-cursor is declared, not separated** (§2). It needs a C change.
* **Two arms are declared UNFENCED in the code**, neither claimed as covered: `eval_rpn`'s
  `raw add` belt (Stage C's `D2`, unchanged) and `eval_cursor_point`'s `$p < 0` term (my
  `C2-1b`). Both have a sabotage that reddens nothing, and both say so where they are.
* **Nothing verified by eye, and no `look` debt incurred.** Every claim here is a row, a
  quoted command output, or a predicate lifted from the tree.
* **No permission prompt denied me anything.**
* **No `.scratch/` litter**: `tests/headless/.scratch/` is empty after the runs.

---

## 11. `git status --short` at the end

```
 M src/calculator.tcl
 M src/save.c
 M tests/headless/test_calc_buffer.tcl
 M tests/headless/test_calc_skeleton.tcl
 M tests/headless/test_calc_widgets.tcl
 M tests/run_regression.tcl
?? .xschem/
?? doc/claude/calculator_batch/receipts/C-evaluate.md
?? doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
?? tests/headless/test_calc_engine.tcl
?? tests/headless/test_calc_scratch_reuse.tcl
```

**Of those I changed exactly six**: `src/calculator.tcl`, `src/save.c`,
`tests/run_regression.tcl`, `tests/headless/test_calc_skeleton.tcl` (comment only), and the
two untracked suites. ⚠ **`tests/headless/test_calc_buffer.tcl`,
`tests/headless/test_calc_widgets.tcl`, `receipts/C-evaluate.md`, `.xschem/`, the survey
document and `debug_st1/` are NOT mine** — all six were in this session's starting snapshot
and I did not open any of them for writing. This receipt is the seventh file, new.

---

## 12. What the next stage must know

1. ⚠⚠ **`xschem annotate_at <t>` PUBLISHES A REAL CURSOR HEADLESSLY**, through the graph's
   own cursor-B code. Nothing in the batch knew this. It means R604's cursor clause, PLAN
   3.3's Plot and 3.6's Table can all be driven against **real** `annot_p` on the gating arm
   instead of by renaming a proc aside. Band `CE9` is the pattern.
2. ⚠ **`annot_p >= 0` is "something was published", not "a cursor exists".** The three-field
   answer of `xschem raw annot` is the whole discriminator and `annot_sweep_idx` is the
   field that matters. Anything else in the tree that gates on `annot_p` alone and *means*
   "a cursor" has this defect. `update_op()`'s own comment lists the readers it knows about
   (token.c's `live_cursor2` readers, `spice_get_node()`, scheduler.c's `raw value` cursor
   arm, `op_annot.tcl`) — those want "something was published" and are fine. **A reader that
   wants a cursor is a different question and nobody has swept for one.**
3. ⚠ **A `raw read` WITHOUT a `raw clear` does NOT reset the annotation.** Measured: annot
   survives a second read of the same file. Any band that publishes a cursor must clear on
   the way out, or it poisons every band after it. `CE9` and `CE11` both do.
4. **`xschem log <f>` / `xschem log` is an in-process capture of the C debug stream**
   (`errfp`, `src/scheduler.c`'s `log` verb). That is how `CE11` counts without a child
   process or valgrind, and it is reusable for any `dbg()` assertion.
5. ⚠ **PLAN 3.4 (R607) now has a SECOND customer**: the `%<n>` dataset spelling reads as a
   silent zero (`CE12`), and the cure is the same pre-engine token validator the task's E5(b)
   describes. `wviewer::validate_rpn <rpn> <names>` in `src/wave_viewer.tcl` is the one the
   house already has — do not write a second.
6. ⚠ **Two false sentences remain in the SPECS** (§5, rows 5 and 6), one of them pinning a
   test row by a name that no longer exists. They are the driver's, with the minimal
   corrections written out.
7. **A non-finite result now REFUSES.** A later phase that wants to show divergence (Plot,
   Table) has to decide that separately, and rule debt `1245_B1_nonfinite_render` is already
   asking the same question for the RDW — one answer should cover both.
8. ⚠ **`test_calc_engine` now sources `tests/headless/scratch.tcl`** and is the only
   calculator suite that writes anything. If a later band needs no fixture, do not undo
   that: `CE9`'s multi-point op/dc raw has no committed equivalent in the tree.
9. **Re-run the previous stage's sabotages, not only your own.** Sabotage `Q` went green
   because my fix cured the symptom its rows were keyed to (§7), and nothing else in this
   stage would have caught it.
10. **Run the whole suite set after every edit, not the suite you are editing.** The `SR5`
    false red (§6(ii)) was in the sibling file and survived four green runs of the file I had
    in hand.
11. ⚠ **I edited a file while my own background sabotage loop held it**, and the edit landing
    after the loop's final restore rather than inside it was luck, not method — the same
    hazard the LEDGER records under *"the driver edited the tree underneath the crew"*. I
    re-ran the one measurement that could have been invalidated (`C2-1` on the display arm)
    serially afterwards, and it agreed. Do not overlap an edit with a run that restores files.
