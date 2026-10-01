# Receipt C-evaluate — PLAN 3.1 and 3.2: Evaluate

Stage label `C-evaluate`. Branch `fluid-editing`, tree at `3e94bbee`, **nothing committed,
pushed or stashed**. All scratch under `…/scratchpad/C-evaluate/`.

**No expression evaluator was written.** The engine is `plot_raw_custom_data()` in
`src/save.c`, reached through `xschem raw add <name> <expr>`; this stage built the *door* to
it — a destination discipline, a point to read, and a sentence — and the four engine-side
procs together are shorter than §3.2's operator table would have been.

⚠ **I verified part 1's claims before building on them and found ONE correction and TWO
new facts that change what a row can assert** — §6.1. The fixture itself is right in every
particular I checked.

---

## 0. The verdicts, both arms

| suite | `--nogui` arm | display arm (`:99`) | before this stage |
|---|---|---|---|
| **`test_calc_engine`** (NEW, `hcases`) | `RESULT: ALL PASS (120 checks)` | `RESULT: ALL PASS (120 checks)` | did not exist |
| **`test_calc_scratch_reuse`** (NEW, `hcases`) | `RESULT: ALL PASS (46 checks)` | `RESULT: ALL PASS (46 checks)` | did not exist |
| `test_calc_skeleton` | `RESULT: ALL PASS (0 checks)` | `RESULT: ALL PASS (548 checks)` | 546 / 0 |
| `test_calc_widgets` | `SKIP (self-skipped: no X)` | `RESULT: ALL PASS (246 checks)` | 246 / skip |
| `test_calc_buffer` | `SKIP (self-skipped: no X)` | `RESULT: ALL PASS (130 checks)` | 121 / skip |

`RESULT: 5/5 runs passed` on the display arm and `RESULT: 3/3 runs passed (2 skipped)`
headless, through the armed spelling `tests/headless/run_suites.sh [--nogui] <t>`, display
arm attached to the persistent dev display `:99`, left exactly as found (`status` only,
never `start`/`stop`/`view`).

**The two new suites pass on BOTH arms deliberately** — see §6.2, where asserting the
`--nogui` world outright made the engine suite a standing red under `full_audit.sh`.

Neighbours that read `tests/run_regression.tcl` or scan the tree, all `--nogui`, all
`ALL PASS`: `test_registered_banner_1626` **10**, `test_audit_classifier` **75**,
`test_scratch_home_note` **22**, `test_regression_concurrency_1476` **46**,
`test_issue_stamp` **102**, `test_selflog_grep_guard` **390**.

### The `calc::inert` progress bar, before and after

`/usr/bin/grep -c 'calc::inert' src/calculator.tcl`: **13 → 12**, and the line that went is
exactly the one this stage owns —

```
-1240:    return [calc::inert {Eval} 3]
```

The two remaining phase-3 entries are `calc::dest_changed`'s plot-destination line and
`build_mode`'s **Plot** button, both PLAN **3.3** and deliberately untouched.

---

## 1. What I changed, by symbol

### `src/calculator.tcl` — ten new procs, two amended, one new variable

| symbol | what it is |
|---|---|
| **`calc::rpn_of_text` (NEW)** | PLAN 3.1. The identity in RPN mode. A proc rather than an inline read so phase 8 has **one** site to replace; row `CE1` asserts it has exactly one caller, which is what makes "one place" checkable rather than intended. Identity is **byte** identity, whitespace included — the buffer is multi-line and a newline is one of the engine's three delimiters. |
| **`calc::rpn_of_buffer` (NEW)** | PLAN 3.1. The window read in front of it, guarded by `calc::has_win` (R508). Answers `{}` with no window. |
| **`calc::tmpvec` (NEW)** | R402's `__calc_tmp<N>`, minted from the new `tmpn` serial. **Never re-uses a name**, and skips one the loaded raw already holds. This is the stage's whole answer to L2 — see §2. |
| **`calc::eval_cursor_point` (NEW)** | R604's first clause: `annot_p` out of `xschem raw annot`, or `-1`. Its own proc so the cursor arm can be measured at all (nothing headless publishes a cursor). |
| **`calc::eval_msg` (NEW)** | Every sentence Evaluate can say, in one place. `rule` debt filed. |
| **`calc::eval_refusal` (NEW)** | The answer dict, refusing. One site, so the key set cannot drift across nine refusal paths; row `CE3` asserts the key set. |
| **`calc::eval_rpn` (NEW)** | PLAN 3.2 / R604 / R605 / L2. Evaluate against the current database and answer one scalar. R605 is the **shape** of the proc, not a line in it. |
| **`calc::eval_fmt` (NEW)** | R603/R604's sentence: the value and which point it came from. |
| **`calc::eval_in_token` (NEW)** | R603. Runs the engine step inside the selected result's own context, through the `wviewer::enter_ctx $tok 1` / `leave_ctx` bracket `calc::session_result` already uses (issue 0173/0314). A refused loan is reported as **busy**, never as "no data" (T-J). |
| **`calc::eval_click`** | rewired. `require_result` → `rpn_of_buffer` → `eval_in_token` → `calc::status`. Gained a `calc::has_win .calc.mode.eval` guard **at the top** — R508 binds entry points, and `require_result` writes the Results Dir row as a side effect, so reaching it with no window is a write. |
| **`calc::require_result`** | one key added: **`token`**, from the `detail` field `calc::results_source` already returns. Without it phase 3 has the slot and no context to read it in. The three refusing arms carry `token {}`. |
| **`calc::results_publish`** | two `winfo exists` → `calc::has_win`. **Pre-existing R508 third-case defect**: under `--nogui` the bare spelling *raises*, which `require_result`'s own `catch` swallowed — so nothing broke, but the proc was abandoned half-done, and phase 3 made that reachable from an entry point that now does real work. |
| **`calc::tmpn` (NEW namespace variable)** | the mint's serial. **Interpreter-scoped, like `editcan` and unlike the three `fb*`**: `calc::close` must not reset it, or a name minted before a close comes back after one. Row `CE2` asserts that, and `SAB-S` reddens it. |

### `tests/headless/test_calc_engine.tcl` (NEW, `hcases`) — 120 checks

Bands `CE0` fixture + accessor contract, `CE1` PLAN 3.1, `CE2` R402 minting, `CE3` the
hand-computed numbers over both transient datasets, `CE4` R604 cursor-or-last-point,
`CE5` the two rejections and why R607 cannot use the engine's `-1`, `CE6` the ac and op
analyses (the −3 dB point, the `?` truth table), `CE7` R402 leak-freedom, `CE8` R508 both
axes.

### `tests/headless/test_calc_scratch_reuse.tcl` (NEW, `hcases`) — 46 checks

Bands `SR1` the hazard measured with no Calculator in the way, `SR2` §11.1's literal
scenario, `SR3` the interleave, `SR4` the guard forced, `SR5` R605 structurally, `SR6`
R402 on the refusing paths.

### `tests/headless/test_calc_buffer.tcl` — new band `CB6`, 121 → 130 checks

PLAN 3.1's **window read**, which the `hcases` suite cannot reach. It exists because
`SAB-G` (`.calc.buf get 1.0 end` instead of `end-1c`, the classic text-widget off-by-one)
reddened **nothing** in either new suite. Placed before `CB4`, which closes the window.

### `tests/headless/test_calc_skeleton.tcl` — S27 restated, 546 → 548 checks

The row `S27 Evaluate WITH a result falls through to the phase-3 stub` was a **scope
fence** for results batch item 10 and this stage legitimately crosses it. **Restated, not
deleted**: with a result and an empty buffer the answer names the buffer (which is itself
proof the resolution succeeded); with an expression it runs the engine step inside a
**second** borrowed context; and the gate hands phase 3 the `token`.

### `tests/headless/test_calc_widgets.tcl` — comment only, 246 checks unmoved

CW13's comment said `calc::eval_click` *"FALLS THROUGH TO `calc::inert` — the phase-3 stub
is still what a press with a result reaches"*. True until today. Corrected in place.

### `tests/run_regression.tcl` — both new suites into `hcases`

Measured by the counting method CLAUDE.md prescribes (find `set <n> [list`, pipe through
`/usr/bin/grep -o '"[^"]*"' | wc -l`): `tcases` **3**, `hcases` **92**, `dcases` **23**,
plus `xschemtest` — so **119 cases**.

---

## 2. LANDMINE L2 — exactly how it is handled, and the row that proves it

⚠⚠ **L2 AS WRITTEN IS NOT REACHABLE FROM THE CALCULATOR, AND THE REACHABLE FORM IS WORSE.**
Both halves are measured by rows, not asserted in prose.

**Why the spec's mechanism is not reachable.** L2 describes the GRAPH path:
`plot_raw_custom_data()` called with `yname == NULL` writes `raw->values[raw->nvars]`, one
shared scratch column. The Calculator's only Tcl door to the engine is
`xschem raw add <name> <expr>`, and `raw_add_vector()` registers `<name>` **first**, so the
evaluator resolves `yname` and writes the **named** column. Measured — row `SR1`:

```
ok:   SR1 an UNRELATED add does not disturb a named column -- the shared-scratch collision is not reachable here
```

**The reachable form.** Re-using a destination name. Row `SR1`, with no Calculator in it:

```
ok:   SR1 a destination created with expression A holds A's numbers
ok:   SR1 ⚠ re-using it for a REJECTED expression leaves A's numbers in place -- THIS IS THE BUG
ok:   SR1 ...and `xschem raw add` answers 0, which means 'the vector existed', NOT 'the expression failed'
ok:   SR1 ...while a FRESH destination for the same rejected expression answers zero
```

That is L2's own sentence — *"`get_raw_value()` on an expression trace returns whatever was
evaluated last"* — arriving through a reused name instead of a shared column. And there is
**no return value to detect it with**: `raw_add_vector()` discards the evaluator's `-1`.

**And the write cannot be taken back, which decides WHERE the guard goes.** Row `SR1`:

```
ok:   SR1 ⚠ a `raw add` that answers 0 has STILL overwritten that column -- register-or-find THEN evaluate
```

**So the handling is three things, in this order:**

1. **`calc::tmpvec` never re-uses a name** and skips one the raw already holds. A fresh
   column per evaluation makes the stale read unreachable by construction, and a rejected
   expression therefore reads as a defined **zero** (issue 0325 zeroes a new column before
   evaluation), never as the previous answer.
2. **`calc::eval_rpn` asks `xschem raw index $dest` BEFORE the engine call** and refuses if
   the column is not its own. In front, not behind, because of the row above.
3. **The `raw add` and the `raw value` are adjacent statements** in that one proc — R605's
   "same Tcl command, nothing in between".

**THE ROW THAT PROVES IT** is `SR4`, which forces the collision by shadowing the minting
proc (the only way the arm is reachable once `tmpvec` skips existing names):

```
ok:   SR4 ⚠ handed a destination it did not create, eval_rpn REFUSES instead of reading it
ok:   SR4 ...and it does NOT hand back the planted value
ok:   SR4 ...and the refusal names the destination, so the message is diagnosable
ok:   SR4 ...and the same refusal is taken for a GOOD expression, because the guard is about the COLUMN, not the expression
ok:   SR4 non-vacuity: with the real minting proc back, the same expression is answered
ok:   SR4 the refused call neither deleted the planted column nor overwrote its data, because it refuses BEFORE the engine runs
```

`SAB-D` (both guards removed) reddens **six** rows including all of those; `SAB-C` (only
the pre-check removed) reddens exactly the **last** one, which is the row that forces the
guard to sit in front of the engine rather than behind it.

**And R605 structurally**, over the body's own text with comments stripped:

```
ok:   SR5 R605 the engine call and the read are both in eval_rpn's own body
ok:   SR5 R605 ...and the read is the statement IMMEDIATELY after the engine call -- nothing in between
ok:   SR5 exactly ONE proc in the namespace reads a value out of the raw, and it is eval_rpn
ok:   SR5 ...and exactly ONE proc calls the engine
ok:   SR5 ...and exactly ONE proc calls eval_rpn, the one that holds the context loan
```

⚠ **One arm is declared UNFENCED, in the code, in as many words.** `eval_rpn` also checks
`raw add`'s return as a belt; while the pre-check stands that arm needs another writer to
claim the name between two adjacent statements, so **no row forces it** and `SAB-D2`
(removing it alone) is green. The comment says exactly that.

---

## 3. R604 — the value, and where it came from

**`ALL`** reported values in `CE3`/`CE6` come from the **last point**, because no cursor is
published; the cursor arm is reached by shadowing `calc::eval_cursor_point`. The dict names
which, and so does the sentence:

```
ok:   CE3 every answer above was reported as coming from the LAST point, there being no cursor
ok:   CE4 no cursor -> the LAST point of the asked-for dataset, and it says `last`
ok:   CE4 a cursor at absolute 30 -> v(div) = v(ramp)/2 = 1.5, and it says `cursor`
ok:   CE4 a cursor at absolute 131 reads DATASET 1's sample 30 (0.75), not dataset 0's (1.5)
ok:   CE4 ...and the dict reports the absolute point and dataset -1, naming how it read
ok:   CE4 R603/R604 the sentence carries the value AND says which point it came from
```

**I read R604/R605 rather than inferring the rule, and two things in it are not what a
reasonable implementation would reach for:**

* **`annot_p` is an ABSOLUTE index across all datasets**, so the cursor read passes
  dataset `-1`. The 131-row exists to separate that from the plausible wrong version:
  dataset 1's sample 30 is absolute 131 and reads 0.75, where passing the dataset reads
  dataset 0 and answers 1.5. `SAB-I` reddens it.
* **`cursor_b_val[]` is NOT usable for a computed column.** `raw_add_vector()` sets a new
  column's entry to 0.0 and nothing recomputes it, so the obvious implementation —
  `xschem raw value <tmp> {}`, the documented cursor read — answers a confident **zero**.
  Measured 2026-10-01. Reading the column at `annot_p` is therefore the only honest answer
  available, which means **R604 is met to one sample of the grid, not to the interpolated
  cursor position**. That narrowing is in the proc's comment and in the `rule` debt.

---

## 4. The red, quoted verbatim

Captured with both suites complete and **no product code written at all**
(`scratchpad/C-evaluate/red3.log`):

```
FAIL     | test_calc_engine             run 1/1  RESULT: 86 FAILED (28 passed)
FAIL     | test_calc_scratch_reuse      run 1/1  RESULT: 21 FAILED (23 passed)
```

No `UNEXPECTED ERROR`, no `group … ABORTED`, no `BGERROR`: the rows **failed**, they did not
throw. Representative lines:

```
FAIL: CE1 the two procs exist -> {0 0} (exp {1 1}) : FAIL
FAIL: CE2 the proc exists -> {0} (exp {1}) : FAIL
FAIL: CE3 ds0  v(div)  -> v(div) = v(ramp)/2 in dataset 0 -> {NOTANUMBER:{ERR:invalid command name "calc::eval_rpn"}} (exp {ok}) : FAIL
FAIL: CE4 with no cursor it answers -1, which is what `xschem raw annot` says -> {ERR:invalid command name "calc::eval_cursor_point"} (exp {-1}) : FAIL
FAIL: CE8 none of the three raises with no window (R508's third case) -> {{calc::rpn_of_buffer:invalid command name "calc::rpn_of_buffer"} {calc::rpn_of_text:invalid command name "calc::rpn_of_text"}} (exp {}) : FAIL
FAIL: SR2 calc::eval_rpn exists -> {0} (exp {1}) : FAIL
FAIL: SR2 evaluate A, then B: A answered A's value -> {NOKEY:ok NOTANUMBER:{NOKEY:value}} (exp {1 ok}) : FAIL
FAIL: SR4 calc::tmpvec exists and is what eval_rpn mints through -> {0 0} (exp {1 1}) : FAIL
FAIL: SR5 R605 the engine call and the read are both in eval_rpn's own body -> {0 0} (exp {1 1}) : FAIL
```

⚠ **An earlier red capture ABORTED three bands** (`group CE4 ABORTED -> can't rename
"::calc::eval_cursor_point": command doesn't exist`), which is the issue-1616 trap the brief
names: the bands' bare `rename` calls threw on a tree where the proc does not exist and took
their remaining rows with them. Every `rename` in both files now goes through `pcall`, and
the capture above has zero aborts — 86 reds instead of 68.

**The restated sibling row was red first too**, before I touched it:

```
FAIL: S27 Evaluate WITH a result falls through to the phase-3 stub -> {Nothing to evaluate: the buffer is empty.} (exp {Eval: not implemented (phase 3)}) : FAIL
```

That is the product saying, in its own voice, that the phase-3 stub is gone.

---

## 5. Sabotages: twenty-one, every one of them red

Applied to `src/calculator.tcl` alone by a scripted patcher that **refuses to apply unless
its target text is unique in the file**; suite run; file restored from a checksummed backup;
**md5 verified after every one** (`96a3b31f8d9cdc7d7c36b41cf0aa5c60`, unchanged at the end).
Harness in scratch, not added to the tree.

| # | the plausible wrong implementation | reds | the rows that caught it |
|---|---|---|---|
| **A** | `tmpvec` returns a FIXED name — the obvious implementation | 4 + 2 | `CE2` spelling / three-different / skip / close rows; `SR3` destination rows |
| **B** | `tmpvec` does not skip a name the raw already holds | 1 | `CE2 a name the loaded raw already holds is SKIPPED, not handed back` |
| **C** | the pre-engine guard removed, the `raw add` belt kept | 1 | **only** `SR4 …nor overwrote its data, because it refuses BEFORE the engine runs` |
| **D** | **both** guards removed | 6 | all four `SR4` refusal rows, the data row, and `SR6`'s forced-collision row |
| **D2** | the `raw add` belt alone removed | **0** | **declared unfenced in the code** — unreachable while the pre-check stands |
| **E** | `rpn_of_text` trims | 2 | `CE1` leading-space, trailing-space |
| **F** | `rpn_of_text` collapses whitespace runs | 2 | `CE1` inner-tab, inner-newline |
| **G** | `.calc.buf get 1.0 end` — the text-widget off-by-one | 0 + 0 + **7** | **nothing** in either new suite; all seven `CB6` rows in `test_calc_buffer`. This is why `CB6` exists. |
| **H** | an engine call inserted between the add and the read | 6 + 8 | `SR5`'s adjacency row, and every `CE7`/`SR6` leak row |
| **I** | the cursor read passes `$dataset` instead of `-1` | 2 | `CE4`'s absolute-131 rows |
| **J** | the cursor branch deleted — always report `last` | 9 | `CE4`'s three cursor rows, `CE6`'s three −3 dB rows, the dict row, the out-of-range row |
| **K** | `point $np` instead of `$np - 1` | 45 | `CE3` wholesale, `CE4`, `CE5`, `CE6` |
| **L** | the `raw del` dropped (R402) | — | `CE7` and `SR6` leak rows |
| **M** | the `raw del` moved BEFORE the read | 35 + 8 | `CE3`/`CE4`/`CE5`/`CE6`/`CE7` and `SR2`/`SR3`/`SR4`/`SR5` |
| **N** | `eval_click`'s `calc::has_win` guard dropped | 2 | `CE8 …none of them WRITES a calc:: namespace variable` → **`{respath}`**, the product naming the variable it wrote |
| **O** | `eval_click` calls `eval_rpn` directly — U6's removed `self` arm | 1 + 1 | `SR5 …exactly ONE proc calls eval_rpn`; `S27 …a SECOND borrowed context` |
| **P** | `eval_fmt` drops the "which point" clause | 1 | `CE4` R603/R604 sentence row |
| **Q** | the value's numeric check dropped | 2 | `CE4` out-of-range row, `CE7` refusal-deletes row |
| **R** | the L2 refusal does not name the destination | 2 | `SR4`'s naming rows |
| **S** | `calc::close` resets the mint's serial | 1 | `CE2 …the serial only ever goes UP` |
| **T** | the dataset range check dropped | 1 | `CE3 a dataset the raw does not have is refused and the message names it` |

### ⚠ Three sabotages were GREEN on their first wording, and that is the most useful part of this round

The habit B3's receipt records — **run each sabotage and read how FEW rows it reddened**,
rather than being satisfied that it reddened something — found three fences that were
decoration. All three are repaired and now redden by name:

* **`SAB-B` green.** `CE2`'s skip row planted the name `tmpvec` had just *returned*, then
  asserted the next answer differed and was free — which the **counter** guarantees on its
  own. Deleting the skip logic entirely left it green. It now reads `::calc::tmpn` and
  plants `tmpn + 1`, so the collision is aimed where the minting proc has to notice it.
* **`SAB-S` green.** `CE2`'s close row compared the two *name strings*. A mint reset to 0
  also produces a name that differs from the last one, so the very defect the row is for
  satisfied it. It now compares **serials** and asserts the serial only goes up.
* **`SAB-O` green on all three calculator suites.** `S27`'s loan row looked for an
  `enter`/`leave` pair in the log — but `calc::require_result` takes one loan of its own to
  resolve the selection, so a press that evaluated in *this* window's context still left a
  pair behind. The row now **counts**: two pairs, the gate's and Evaluate's. A derived
  structural row in `SR5` was added beside it.
* **`SAB-G` green in both new suites** — not a wording defect but a missing fence: the
  window read had no behavioural row anywhere, because the suite that owns `rpn_of_buffer`
  cannot open a window. Band `CB6` closed it.

---

## 6. What I got wrong, and what corrected me

### 6.1 Part 1's hand values are right; its TOLERANCE TABLE cannot be used by this stage's rows

The task said to verify part 1's claims. I did, through the real binary, and every
hand-derived number checks out: `v(ramp)` = k/10, `v(sq)` = 0.5 at samples 10/22/50/62/90
and 1 at 100, `v(div)` = ramp/2 and ramp/4, `i(@rtop[i])` = ramp/2000 and ramp/4000,
`v(dcmid)` = 3 and `i(@rdc1[i])` = 1 mA bit-exact in the op dataset, `@m1[gm]` = 1.339 mS,
`i(@m1[id])` = 870.35 µA to 3.5e-9, the ac response = 0.5 − 0.5j at index 9 with
`db20()` = −3.010299956639812 and `ph()` = −45°, `frequency` bit-exact, `raw add` answering
1 for a rejected expression, and `raw index` not parsing `%<n>`. Rows re-measure all of it.

⚠ **But the README's per-quantity tolerances (1e-11 … 1e-12 relative) are the agreement
between the committed `.raw` and the hand value, and they are measurable only through
`xschem raw values`, which prints `"%.16g"`.** Everything a *scalar* reader sees comes
through `xschem raw value`, which prints through `dtoa()` — **`"%.8g"`**, `src/util.c`. So
eight significant digits is the ceiling for any row in this stage, and a row that had taken
the README's 1e-11 would have been **red on a correct fixture**. Every row here uses 1e-7
relative and says why; row `CE0` reads that format string out of `src/util.c` so the two
cannot drift. **This is the same species of error the README itself records catching twice,
one layer further out: the tolerance belongs to the instrument, not only to the artefact.**

Two facts I had to measure because nothing recorded them, both of which changed the design:

* **A second bare `xschem raw read <f>` does not necessarily return to `tran`** once the
  same file has also been read as `op`: it lands back on the OP slot (1 point), so
  `raw value <v> 30 0` answers EMPTY and a row reads that as a wrong number rather than as
  a wrong database. Both suites read with an **explicit type**, every time, and say so.
* **`xschem raw add {} <expr>` is not refused** — it registers a vector whose name is the
  empty string and evaluates into it. That is why `calc::tmpvec` can never answer `{}` and
  why `CE2` has a row for it.

### 6.2 My own R508 rows made the engine suite a standing red under `full_audit.sh`

`CE1` and `CE8` asserted `[info commands winfo] eq {}` outright — true on the `--nogui` arm
and **false** on a display arm. `full_audit.sh` globs every `test_*.tcl` and runs it on the
display arm, so I had built exactly what CLAUDE.md says a new fence must never become. Both
rows now **name** which of R508's two no-window worlds the arm is in, and the third case is
**forced** by renaming `::winfo` aside (the mechanism `test_calc_skeleton` S13 and
`test_calc_buffer` CB5 already use), so both arms measure both cases. Caught by running the
display arm on purpose rather than by reasoning.

### 6.3 Two row names I wrote were false before they were ever run

`CE5`'s 199-token row was written as a `string repeat` expression that does not produce 199
tokens and whose stack result is ambiguous; it is now 50 `v(ramp)` plus 49 `+`, with the
token count asserted in the row. And `CE3`/`CE0` carried `[gm]` and `[id]` inside
**double-quoted** row names, so Tcl ran them as command substitutions and aborted two bands
with `invalid command name "gm"`. Braced. Both found by running, not by reading.

### 6.4 A refusal sentence claimed a cursor that was not there

`SAB-K`'s output read `Evaluate: the cursor is at point 101, which this result has no data
for.` — on the **last-point** branch, where there is no cursor at all. The sabotage's job
was the off-by-one; what it exposed was a user-visible sentence making a false claim about
how the point was chosen. Now `Evaluate: that result has no data at point <n>.` **A
sabotage aimed at arithmetic found a wording defect, which is an argument for reading
sabotage output rather than only its count.**

---

## 7. The trailer delta — derived from `summarize_all`'s own arms over real captured output

Method: capture each case exactly as T1's `hcases` arm does
(`--pipe -q --nolog --nogui`, stdout and stderr together, a throwaway `HOME` under my
scratch), then **lift `summarize_all` and `t1_carry_line` out of
`tests/run_regression.tcl`'s own text** (a line scan from `^proc <name>` to the first line
that is exactly `}`), `source tests/banner_rule.tcl`, and run the lifted proc over that
capture. No figure below is quoted from a receipt.

```
lifted: t1_carry_line (5 lines)
lifted: summarize_all (89 lines)
--- the lifted summarize_all's arms ---
>> if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]} {
>> } elseif { [regexp {^(NOGOLD|NODISPLAY)} $line] } {
>> } elseif { [regexp {^skip:} $line] } {
>> } elseif { [regexp {^RESULT:} $line] } {
>> } elseif { [banner_complete $line] && [regexp {\([^)]*\)} $line] } {
=== test_calc_engine.nogui: lines=142 counted-shape=0 lowercase(^skip:)=0 any-case(^skip)=0 ^RESULT:=1 NOGOLD/NODISPLAY=0
    banner_complete=1 banner_died=0 regression_case_failed(0)=0
    summarize_all returned: 0 ; blocks +1 ; skips +0
headless/test_calc_engine
RESULT: ALL PASS (120 checks)
Total num fail: 0

=== test_calc_scratch_reuse.nogui: lines=55 counted-shape=0 lowercase(^skip:)=0 any-case(^skip)=0 ^RESULT:=1 NOGOLD/NODISPLAY=0
    banner_complete=1 banner_died=0 regression_case_failed(0)=0
    summarize_all returned: 0 ; blocks +1 ; skips +0
headless/test_calc_scratch_reuse
RESULT: ALL PASS (46 checks)
Total num fail: 0

TOTAL t1_blocks=2 t1_skips=0
```

**The delta this stage contributes**, derived rather than remembered: **+2 cases, +2 blocks,
+0 counted failures, +0 `^skip:` lines, +6 verdict lines** (two new blocks × label +
published `RESULT:` + `Total num fail:`). Relative to the driver's committed baseline
**117/116/0/8** at `a0d56801` that gives **119/118** cases/blocks, and the published check
count inside `test_calc_skeleton`'s existing block moves 546 → 548 and inside
`test_calc_buffer`'s 121 → 130, neither of which changes any line count.

⚠ **This is a derivation over my own suites' output, not a prediction of the trailer**, and
in particular **not a prediction of `skips=`.** CLAUDE.md records four occasions where
careful reasoning about registration shape got that figure wrong, most recently issue 1625
where two independent parties predicted movement and both were wrong. What I measured is
that **my** two cases contribute **zero** lines the `^skip:` arm matches, in either arm
(`any-case(^skip)=0` too, so there is nothing of either spelling); every other case is
unchanged, because the only shared file I touched is `tests/run_regression.tcl` and I added
two entries to it and nothing else. **Read the trailer.**

### The registration shape, re-checked through the only Tcl reader

```
display: banner_complete=1 banner_died=0 regression_case_failed(0)=0
nogui:   banner_complete=1 banner_died=0 regression_case_failed(0)=0
```

**Checked against `banner_complete` BEFORE registering, and quoted here**: the predicate in
`tests/banner_rule.tcl` is

```tcl
proc banner_complete {body} {
  return [regexp -line {^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$} $body]
}
```

and both files end `OVERALL: ok ($npass checks)` then `RESULT: ALL PASS ($npass checks)`,
on the success path only. Issue **1627**'s shape re-measured on both real captures:
column-0 `RESULT:` **1**, column-0 `OVERALL:` **1** — **each file has ONE exit path**, with
no no-X gate, because nothing in either suite needs a display. Row `RB2`/`RB6` of
`test_registered_banner_1626` run after registering: `ALL PASS (10 checks)`.

---

## 8. `git status --short` at the end

```
 M doc/claude/calculator_batch/LEDGER.md
 M src/calculator.tcl
 M tests/headless/test_calc_buffer.tcl
 M tests/headless/test_calc_skeleton.tcl
 M tests/headless/test_calc_widgets.tcl
 M tests/run_regression.tcl
?? .xschem/
?? doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
?? tests/headless/data/
?? tests/headless/test_calc_engine.tcl
?? tests/headless/test_calc_scratch_reuse.tcl
```

**Of those I changed exactly six**: `src/calculator.tcl`, `tests/run_regression.tcl`,
`tests/headless/test_calc_buffer.tcl`, `tests/headless/test_calc_skeleton.tcl`,
`tests/headless/test_calc_widgets.tcl` (comment only), and the two new suite files.
⚠ **`doc/claude/calculator_batch/LEDGER.md` is NOT mine** — it was already modified in this
session's starting snapshot, as were `.xschem/`, the survey document, `debug_st1/` and
`tests/headless/data/` (part 1's fixture). I did not open any of them for writing. Nothing
is committed, pushed or stashed. `git diff src/calculator.tcl` deletes exactly eight lines,
all of them named in §1.

---

## 9. What I did NOT do, and why

* **No T1 run.** The driver's job and the brief forbids it. §7 is the unit-level substitute
  for *scoring*, not for *running*.
* **No expression evaluator, no parser, no second tokeniser.** §0.
* **PLAN 3.3 (Plot) and 3.4 (R607) are not built**, and 3.4's premise is now measured
  rather than assumed — see §10.1.
* **No C change.** The `dbg(0, …)` in `case COND` (§10.2) is reported, not fixed: it is one
  word in `src/save.c`, a rebuild, and squarely outside PLAN 3.1/3.2.
* **I did not fix `calc::status_recall` or `calc::dest_changed`**, the two bare
  `winfo exists` sites B3 carried. I fixed `calc::results_publish`'s two because
  `calc::eval_click` reaches it and R508 binds the entry point; the other two are still
  unreachable without a window and are still open.
* **No `xschem raw switch` and no `xschem raw read` from the Calculator.** Inside the loan
  the selected slot is already the current one (`results::current` returns the row whose
  `cur` flag is set), so phase 3 does not need the `type`/`idx` the gate carries for
  identification. The Calculator mutates nothing but its own temporary column.
* **No probe wrote anything.** No `xschem save`/`saveas` anywhere in this stage, nothing
  under `xschem_library/`, `tests/headless/gold/` or any tracked fixture; the committed
  fixture was read only (`md5 23bf926f6def8fe4525a881e80fcdd1a`, unchanged). Every probe ran
  with `HOME` pointed at my own scratch directory; every suite ran through the armed
  spelling. The dev display `:99` was left as found (`status` only).
* **Nothing verified by eye, and no `look` debt incurred.** Every claim here is a row, a
  quoted command output, or a predicate lifted from the tree.
* **One `rule` debt filed**, `calc_eval_wording_phase3`: nine new user-visible sentences,
  the number format (`%.8g`, no engineering suffix — 870.35 µA reads as `0.00087035`), and
  R604's one-sample narrowing. I cleared nothing.
* **No permission prompt denied me anything.**
* **The sabotage harness is in scratch, not in the tree** (a Python patcher with 21 named
  sabotages that refuses a non-unique anchor, plus md5 verification). Whether it belongs
  under `doc/claude/calculator_batch/` is the driver's call; B3 left the same question open.

---

## 10. What the next stage must know

1. ⚠⚠ **PLAN 3.4 (R607) CANNOT BE WRITTEN AS "on engine `-1`, name the token", AND THIS IS
   NOW MEASURED EVERY RUN.** `raw_add_vector()` discards `plot_raw_custom_data()`'s return
   value, so from Tcl a good expression and a rejected one are indistinguishable by return:
   `xschem raw add` answers 1 if it created the vector and 0 if it already existed, and
   nothing else. Row `CE5 \`xschem raw add\` reports SUCCESS for a REJECTED expression,
   exactly as for a good one` holds both halves. **The failing token has to be found by
   validating every vector-looking token with `xschem raw index` BEFORE the engine runs**,
   or the return has to be plumbed out of the C first. The house already has a pre-validator
   to reuse: **`wviewer::validate_rpn <rpn> <names>`** in `src/wave_viewer.tcl`, which
   `wviewer::add_trace` calls on exactly this path — do not write a second one (L5's
   lesson one level over).
   **Consequence for today's product, stated plainly:** `calc::eval_rpn` reports a defined
   **0** for a rejected expression and cannot say it was rejected. The guard guarantees the
   0 is *this* expression's and not a previous one's; distinguishing "rejected" from
   "legitimately zero" is 3.4's.
2. ⚠ **`case COND` in `src/save.c` carries a `dbg(0, …)` that prints ONE LINE PER EVALUATED
   POINT, on every path.** Measured: `xschem raw add x {7 1 9 ?}` over the fixture's
   transient arm prints 101 lines of `7 1 9` to the suite's output, and `?` is one of
   RULING-2's twelve keypad tokens — so the first user who presses `?` and Evaluates floods
   their terminal, and a 20000-point transient prints 20000 lines. `test_calc_engine`
   measures the `?` truth table on the **op** dataset (one point, one line) to keep its own
   output readable, and says so. One word in C (`dbg(0` → `dbg(1`); **the driver's call, not
   taken here.**
3. **`xschem raw annot` is the cursor reader, and `annot_p` is an ABSOLUTE index across all
   datasets.** Pass dataset `-1` to `xschem raw value`. And `cursor_b_val[]` is useless for a
   computed column (it is set to 0.0 at creation and never recomputed), so a `raw value
   <tmp> {}` cursor read answers a confident zero. PLAN 3.3's Plot and 3.6's Table both need
   this.
4. **A phase-4 proc that reaches the engine has four obligations**: mint through
   `calc::tmpvec` (never a fixed name — L2), ask `xschem raw index` before the engine call
   (the write cannot be taken back), delete on **every** exit path including error (R402),
   and add itself to `test_calc_engine`'s derived phase-3 proc sweep by being named
   `eval_*`/`rpn_of_*` — that list is derived from the namespace, so a differently-named
   proc silently escapes `CE8`'s guard rows.
5. ⚠ **A second bare `xschem raw read <f>` after the same file has been read as another
   analysis does NOT necessarily return to `tran`.** Always give the type. This cost me one
   confusing probe where `raw value <v> 30 0` answered empty because the OP slot (1 point)
   was current.
6. ⚠ **The tolerance belongs to the instrument.** `xschem raw value` is `%.8g`; the fixture
   README's 1e-11/1e-12 figures are only reachable through `xschem raw values` (`%.16g`).
   Any later row reading one scalar needs 1e-7, and row `CE0` pins the format string.
7. **`calc::rpn_of_text` is phase 8's ONE site.** `calc::alg2rpn` goes in front of its
   `return` and nothing else in the file moves; row `CE1` asserts it has exactly one caller.
   RULING-5 stays unfenced until then.
8. ⚠ **`test_calc_skeleton.tcl` still has no `::bgerror` handler**, so it can print
   `OVERALL: ok` over a real background error — B3 §10.5's open item, unchanged, and still a
   live hole in T1's scoring for a registered `dcases` entry. Both new suites in this stage
   carry one, ending `: FAIL`.
9. ⚠ **`src/calculator.tcl` still carries live-looking `recon/` citations** at several sites;
   that directory exists on no branch. B3 §10.6's open item. `/usr/bin/grep -n 'recon/'
   src/calculator.tcl` is the instrument. I added none.
10. **Both new suites pass on BOTH arms and are registered in `hcases` only.** That is
    deliberate: `full_audit.sh` runs every `test_*.tcl` on the **display** arm, so a suite
    that asserts the `--nogui` world outright becomes a standing red there even though T1
    never runs it that way. §6.2 is the measurement.
