# Receipt D-plot — PLAN 3.3 (Plot) and 3.4 (error reporting)

Stage label `D-plot`. Branch `fluid-editing`, tree at `69cbf9b5`, **nothing committed, pushed
or stashed**. All scratch under `…/scratchpad/D-plot/`.

**No expression evaluator was written, and no trace inserter either.** PLAN 3.3 is
`wviewer::plot_signals` → `wviewer::plan_plot` → `wviewer::add_trace` with the Calculator's
combobox pushed at `wviewer::set_plot_dest`; PLAN 3.4 is `wviewer::validate_rpn`, the
validator `wviewer::add_trace` already calls on that same path, plus one guard for the single
rejection class a token-level test cannot see. The Calculator's own share of both is six
small procs and three one-line ones.

⚠ **The two methods PLAN 3.4 prescribed were MEASURED and both are refuted; the method
adopted is a third one, and its two blind spots are declared with rows.** §4.

⚠⚠ **THE SABOTAGE ROUND FOUND THREE FENCES THAT MEASURED NOTHING, AND ONE OF THEM I BROKE
MYSELF IN THIS STAGE.** §6 and §7 — the most useful part of this receipt.

⚠ **The claim audit (§9) refuted a comment I had already shipped in this stage**, which is
the fourth consecutive round of this batch to find one.

---

## 0. The verdicts, both arms

| suite | `--nogui` | display (`:99`) | before this stage |
|---|---|---|---|
| **`test_calc_plot`** (NEW, `dcases`) | `SKIP (no X …)` — nothing ran, by design | `ALL PASS (67 checks)` | did not exist |
| `test_calc_engine` (`hcases`) | `ALL PASS (253 checks)` | `ALL PASS (253 checks)` | 217 / 217 |
| `test_calc_scratch_reuse` (`hcases`) | `ALL PASS (51 checks)` | `ALL PASS (51 checks)` | 49 / 49 |
| `test_calc_skeleton` (`dcases`) | `ALL PASS (0 checks)` | `ALL PASS (548 checks)` | 0 / 548 |
| `test_calc_widgets` (`dcases`) | `SKIP (self-skipped: no X)` | `ALL PASS (246 checks)` | skip / 246 |
| `test_calc_buffer` (`dcases`) | `SKIP (self-skipped: no X)` | `ALL PASS (130 checks)` | skip / 130 |
| `test_divis_zero_1628` | `ALL PASS (33 checks)` | `ALL PASS (33 checks)` | 33 / 33 |
| `test_del_negative_arg` | `ALL PASS (24 checks)` | `ALL PASS (24 checks)` | 24 / 24 |
| `test_registered_banner_1626` | `ALL PASS (10 checks)` | `ALL PASS (10 checks)` | 10 / 10 |

The wave-viewer suites this change can reach — list built by grepping for the verbs, **not
guessed** (`/usr/bin/grep -rl 'wviewer::add_trace\|wviewer::set_plot_dest\|wviewer::plot_signals\|wviewer::plot_dest\|wviewer::dest_norm\|wviewer::dest_label' tests/`) — all on the display arm, all `ALL PASS`:

`test_wave_viewer` **437**, `test_wave_modes` **488**, `test_wave_clear_all` **76**,
`test_wave_empty_strips` **98**, `test_wave_split_strip` **221**, `test_wave_tabs` **172**,
`test_wave_trace_menu` **397**, `test_wave_grid` **400**, `test_wave_sigbrowser` **353**,
`test_wave_sigbrowser_digital` **82**, `test_wave_sigbrowser_i1315` **192**,
`test_wave_sigbrowser_sea` **79**, `test_wave_sigsearch` **250**, `test_wave_snap` **106**,
`test_wave_axis_zoom` **370**, `test_wave_crossdb_trace` **130**, `test_wave_casemode` **134**,
`test_wave_drag_preview` **94**, `test_raw_case_mode` **277**, `test_ase_current_repair` **54**.

⚠ **One of that list did NOT pass, and it is the hazard the task named: `test_wave_markers`
`TIMEOUT … (after 200s)`.** §8 — measured against this stage's tree AND against the
pre-3.3 tree, which is the only way to say whose it is.

All runs through the armed spelling `tests/headless/run_suites.sh [--nogui] <t>`, display arm
attached to the persistent dev display `:99`, left exactly as found (`status` only, never
`start`/`stop`/`view`).

### The `calc::inert` progress bar, before and after

`/usr/bin/grep -n calc::inert src/calculator.tcl`, **before** (15 lines, 2 of them this
stage's):

```
20, 664, 1697, 1934, 1973, 1984, 1992, 1996, 2002, 2033, 2041, 2117, 2591, 3059, 3144
    2002:            set cmd [list calc::inert $label $phase]        <- W11, the Plot button
    2041:    return [calc::inert "plot destination [.calc.mode.dest get]" 3]
```

**after** (the two above are gone):

```
20, 664, 1849, 2288, 2327, 2338, 2347, 2352, 2396, 2513, 2987, 3455, 3540
```

⚠⚠ **CORRECTED IN PLACE BY STAGE D2 (`receipts/D2-plot-blockers.md` §F5c): that list is
13 lines and it was presented as "13 lines; … nothing else moved", which was a STALE
measurement by the time this receipt shipped.** Re-run on the tree Stage D left, at the
same commit and before Stage D2 changed anything, the same grep gives **14** lines:

```
20, 664, 1874, 2315, 2354, 2365, 2374, 2379, 2382, 2426, 2543, 3017, 3485, 3570
```

The extra one is a **comment** mention (`# and which the three calc::inert ... 6 calls a
few lines above falsify:`) written by a LATER round of this same stage, after the grep
above was taken — so the capture was correct when made and wrong when published. The
load-bearing claim is unaffected and re-checked: **there is still no `calc::inert … 3`
call site**, and of the 14 lines 8 are call sites, 1 is the proc definition and 5 are
comment mentions. Stage D2 quotes no total of its own for the same reason this correction
exists: the number is the grep's, not a sentence's.

**There is no `calc::inert … 3` call site left in the file.** Remaining call sites by phase,
read off the grep rather than counted here: three at phase **6** (the pick-scope radios and
Clip), one at phase **10** (Table), one at phase **5** (the function catalogue), one at phase
**9** (the user buttons), one inside `build_stk`'s own `$phase` loop, plus the proc itself and
two comment mentions.

---

## 1. What I changed, by symbol

### `src/calculator.tcl` — nine new procs, four amended

| symbol | what it is |
|---|---|
| **`calc::rpn_tokens` (NEW)** | PLAN 3.4. The engine's own tokenisation and nothing else's: `split` on space, tab and newline, which is `my_strtok_r(ntok_ptr, " \t\n", "", 0, …)`'s delimiter set with an empty quote set. Row `CE13` reads that string out of `plot_raw_custom_data()`'s own call. |
| **`calc::rpn_maxtokens` (NEW)** | PLAN 3.4 / landmine L1. `STACKMAX - 2`. Row `CE13` reads `#define STACKMAX` out of `src/save.c`, does the subtraction, and drives the engine at the boundary from BOTH sides. |
| **`calc::rpn_bad_token` (NEW)** | PLAN 3.4 / R607. The ONE site. `{}` or a clause naming the token (or the token COUNT). Delegates the alphabet to `wviewer::validate_rpn`; fails OPEN if that proc is absent. |
| **`calc::plot_msg` (NEW)** | Every sentence Plot can say, in one place. `rule` debt filed. |
| **`calc::plot_refusal` (NEW)** | The answer dict, refusing. One site, so the key set cannot drift. |
| **`calc::plot_dest_req` (NEW)** | W13's current value, returned as the LABEL verbatim. `wviewer::dest_norm` is the only label→code map; there is no second table here (row `PL2`, sabotage `P13`). |
| **`calc::plot_rpn` (NEW)** | PLAN 3.3 / R601. R607 pre-flight, then `wviewer::set_plot_dest`, then `wviewer::plot_signals`. Recovers the trace's name by diffing the model's `vec` set across the call. |
| **`calc::plot_in_token` (NEW)** | R601's context loan, `calc::eval_in_token`'s bracket with **no `borrow`** — §3. |
| **`calc::plot_click` (NEW)** | W11's press. `has_win` → `require_result` → `rpn_of_buffer` → `plot_in_token` → `calc::status`. |
| **`calc::eval_msg`** | one new kind, `badtoken`: *"Cannot evaluate: `<clause>`."* The clause is `calc::rpn_bad_token`'s, so one description of the fault serves two sentences. |
| **`calc::eval_rpn`** | one guard added, after the three database checks and **before** the destination mint — §5. |
| **`calc::dest_changed`** | live. Pushes W13's label at `wviewer::set_plot_dest` on the viewer holding the result, or says the choice is held. Also **fixed a pre-existing R508 third-case defect**: it used a bare `winfo exists`, which RAISES under `--nogui`. |
| **`calc::build_mode`** | the Plot button wired to `calc::plot_click`; the loop's `phase` column dropped (no stub left to name a phase for). |

### `tests/headless/test_calc_plot.tcl` (NEW, `dcases`) — 67 checks

Bands `PL0` the setup as a measurement, `PL1` the loan and the semaphore, `PL2` W13's three
labels, `PL3` **the acceptance, as trace data**, `PL4` the model and what Plot must not touch,
`PL5` the three destinations, `PL5b` the press-time push, `PL5c` the seam's error path, `PL6`
`dest_changed`'s push and its replay line, `PL7` R607 on the Plot path, `PL8` R602 declined,
`PL9` R508 both axes.

### `tests/headless/test_calc_engine.tcl` — 217 → **253** checks

* **`CE13` (NEW)** — R607: both prescribed methods refuted by rows, the tokeniser and the L1
  bound read out of the C, the one R607 site driven directly and through `eval_rpn`, the
  **three measured disagreements** between the Tcl mirror and the C engine, and the
  degraded-mode (no validator) arm.
* **`CE5`** — the engine's defined-zero rows moved off `calc::eval_rpn` and onto the verb,
  because the product now refuses first; one row added asserting the refusal.
* **`CE7`** — the rejected-expression leak row restated: it asserted `ok eq 1`.
* **`CE8`** — the derived phase-3 proc sweep **widened** from `eval_*`/`rpn_of_*`/`tmpvec` to
  the four families phase 3 now has, and the entry-point list went from three to five.
* **`CE12`** — **LIMIT 2 is CLOSED** by PLAN 3.4 and its rows are restated in place, which is
  the band header's own stated purpose working for the first time.

### `tests/headless/test_calc_scratch_reuse.tcl` — 49 → **51** checks

`SR2` and `SR4` restated for the new refusal; `SR4` gained a third arm **and then a
per-call data read**, because the third arm destroyed Stage C's sabotage `C` observable
(§6). `SR5`'s engine row renamed to what it measures and given a companion row for Plot's
route to the engine.

### `tests/headless/test_calc_skeleton.tcl`, `tests/headless/test_calc_widgets.tcl`

`S18`'s destination sentence and its Plot-is-inert arm restated; `CW13`'s `$allowed` list
gained `calc::plot_click`. No check count moved in either (548, 246).

### `tests/run_regression.tcl` — `headless/test_calc_plot` into `dcases`

Counted by the method CLAUDE.md prescribes (find `set <n> [list`, pipe through
`/usr/bin/grep -o '"[^"]*"' | wc -l`, comment lines dropped): `tcases` **3**, `hcases` **93**,
`dcases` **24**, plus `xschemtest` → **121 cases**.

---

## 2. The arm decision, and why `dcases` ALONE

**Decided: a NEW suite, `dcases` only.** The reasons, in the order they decide it:

1. **The spec's own test plan names the file.** §11.3's GUI table has a row
   `test_calc_plot.tcl | R601–R606 against a live viewer`. Adding a band to
   `test_calc_engine` would have put a display-only band in the one Calculator suite whose
   whole point (its own header) is that it has no window and gates on both arms.
2. **There is no headless arm that measures anything.** Plot needs a Tk toplevel with a
   canvas. The file self-skips whole.
3. **Row `RB6` of `test_registered_banner_1626` is the gate on that shape**, and I ran it
   against the real thing rather than reasoning: a suite taking a whole-file no-X exit with
   no banner, registered in `hcases`, is scored `HARNESS: … did not complete cleanly`. So
   the question is not "does it pass headless" but "does `banner_complete` accept its
   headless output", and the answer was measured **before** the entry went in:

   ```
   plot.disp:  banner_complete=1 banner_died=0 regression_case_failed(0)=0 col0_RESULT=1 col0_OVERALL=1 lowercase(^skip:)=0
   plot.nogui: banner_complete=0 banner_died=0 regression_case_failed(0)=1 col0_RESULT=1 col0_OVERALL=0 lowercase(^skip:)=0
   ```

   `regression_case_failed` answering **1** on the `--nogui` capture is the whole argument:
   an `hcases` entry would be a standing red. `test_registered_banner_1626` is
   `ALL PASS (10 checks)` after the entry went in.
4. R607's own mechanism has no window in it, so **it is fenced headless**, in `CE13` of
   `test_calc_engine`, where it gates on both arms. The split is: R607 → `hcases`; Plot →
   `dcases`.

`test_calc_buffer`'s registration is the model and its gate comment is quoted in the new
file's own gate.

---

## 3. The context loan: no `borrow`, and the measurement it rests on

`calc::eval_in_token` takes `wviewer::enter_ctx $tok 1` — issue 0314's borrow door.
`calc::plot_in_token` takes `wviewer::enter_ctx $tok` with **no borrow**, and that is a
decision with a source: `enter_ctx`'s own comment says the door is open only for callers
whose bodies *"(a) run no `update`/`after` … (b) only READ, and (c) always restore"*. Plot
writes the viewer's layout, may create a strip, and ends in `wviewer::regenerate`, which
redraws. It is not one of those callers.

The plain door is enough, and that is **measured, not assumed** — from inside a real
`-command`, via a probe that replaced the Plot button's command with one that reads the
semaphore:

```
semaphore inside a Calculator button -command: 0
semaphore at top level: 0
```

A Tk `-command` on the Calculator's own toplevel runs off the Tk event loop, not inside
xschem's `callback()`, so nothing is holding the semaphore and the unborrowed switch
succeeds. Row `PL1` pins it. A future Plot reached from a keybinding on a drawing area would
hold a callback frame and be refused **loudly**, as `busy`.

And the loan is **given back**: row `PL1` switches the context to `.drw`, presses Plot, and
asserts the context is `.drw` again (U8 — a Calculator gesture does not drag the waveform
viewer with it). Sabotage `P5` drops `leave_ctx`; sabotage `O-plot` drops the bracket
entirely and reddens **20** rows.

---

## 4. R607: what I measured about each candidate method

The task asked for this explicitly, so here is every alternative and what it answered.

### (a) PLAN 3.4 as written — "on engine `-1`, re-test each vector-looking token"

**Both halves fail, and I read the C myself rather than trusting the previous receipt.**

`plot_raw_custom_data()` in `src/save.c` has exactly **three** `return -1` sites:

| class | site | is there a failing TOKEN? |
|---|---|---|
| 1 | `if(stackptr1 >= STACKMAX -2)` — stack overflow | **no** — every token is valid |
| 2 | the `SPICE_NODE` arm, `get_raw_index(n, NULL) == -1` | **yes** |
| 3 | `case DEL`, `if(!(tmp >= 0.0))` — a negative `del()` delay (issue 0325) | **no** — it is a stack VALUE |

`raw_add_vector()` **discards** that return (`if(expr) plot_raw_custom_data(...);` and then
`return res`), so from Tcl:

```
raw add bad1 {v(nosuch) v(sq) /} -> 1
raw add good1 {v(lp) v(sq) / db20()} -> 1
```

**There is no `-1` to react to.** (Band `CE5` holds that measurement and I did not duplicate
it.)

### (b) "re-test each vector-looking token with `xschem raw index`"

The verb is the right authority for a NAME — it literally calls `get_raw_index()`. What it
cannot do is decide which tokens are *vector-looking*:

```
raw index {/}       -> -1      raw index {db20()} -> -1      raw index {2}  -> -1
raw index {+}       -> -1      raw index {abs()}  -> -1      raw index {1k} -> -1
raw index {**}      -> -1                                    raw index {-1} -> -1
raw index {?}       -> -1      raw index {v(lp)}  -> 28      raw index {v(nosuch)} -> -1
```

So the method needs the engine's operator/function/number alphabet **first**, and without it
a sweep names `/` as the failing vector. Writing that alphabet here is landmine L5's lesson
one level over ("never parser number two"), and sabotage `N6` — which writes exactly that
second validator, in its most plausible shape ("a token with a bracket is a vector") —
reddens **14** rows. Row `CE13` holds the whole table above.

### (c) ADOPTED — `wviewer::validate_rpn`, plus one guard for class 1

`wviewer::validate_rpn <rpn> <names>` carries the operator and function tables verbatim from
the C and mirrors `get_raw_index()`'s ladder rung for rung through
`name_rungs`/`name_index`/`name_lookup`. **`wviewer::add_trace` already calls it on exactly
this path**, which is why Plot gets R607 for free and Evaluate only had to come through the
same door. Measured, through the real viewer:

```
add_trace BAD -> {unknown token 'v(nosuch)' (not an operator/function, number or raw variable)}
```

Class 1 is the one it cannot see, and **`add_trace` does not catch it either** — measured:

```
add_trace 199-token -> {}        (and the C printed "stack overflow in graph expression parsing")
```

so `calc::rpn_maxtokens` exists for it, and PL7 carries that measurement as a **control
leg** so the guard is fenced against the gap it is for.

The boundary, measured from both sides, with the probe expression chosen so the two answers
differ (`v(sq)` plus N unary `abs()` keeps the value stack at depth 1 while driving the parse
stack):

```
198 parse-stack tokens -> evaluates, reads 1
199 parse-stack tokens -> writes nothing, reads issue 0325's zero
```

### What the adopted method does NOT cover — declared, with rows

Three disagreements between the Tcl mirror and the C engine, all measured, all pinned in
`CE13`:

| direction | shape | consequence |
|---|---|---|
| **stricter** | `nan` / `inf` are NUMBERS to the engine (its number rule is a strtod PREFIX test); the mirror declines them | a false REJECT. Costs nothing worth keeping — `calc::eval_finite` would refuse the answer one step later anyway |
| **looser** | a negative `del()` delay — class 3 above | **false APPROVE**: the product answers issue 0325's defined zero with no message |
| **looser** | a token joined by `\r`, `\v` or `\f` — the engine splits only on space/tab/newline, the validator's own `\S+` scan breaks on all three | **false APPROVE**, same consequence. `xschem raw index "v(lp)\rv(sq)"` is -1 and the engine returns -1 |

**A truthful "I cannot tell you which token" for those two classes would be better than the
silence, and I did not build it.** What the product does instead is pinned by rows, so a
later stage that closes either reddens and must correct the declaration.

### (d) MEASURED AND NOT ADOPTED — the `xschem raw set` sentinel

This is the method that **would** close all three classes, and I measured it working before
deciding against it. `xschem raw set <node> <point> <value>` exists (`src/scheduler.c`, the
`set` arm). Create the destination empty, seed one point, evaluate into it, read:

```
unresolvable-name    rc=0 value=-777      sentinel-survived=YES (engine rejected)
negative-del         rc=0 value=-777      sentinel-survived=YES (engine rejected)
stack-overflow       rc=0 value=-777      sentinel-survived=YES (engine rejected)
good-control         rc=0 value=-3.0103   sentinel-survived=no  (engine wrote)
```

**It is correct for all three of the engine's `-1` classes and for the control**, it asks the
engine instead of mirroring it, and it would therefore also catch any future drift of the Tcl
mirror. **Not adopted, and this is the one judgement in this stage I would most want a second
opinion on.** Three reasons, in order:

1. It needs a **second `xschem raw add` caller** in the `calc` namespace. Row `SR5` asserts
   *"exactly ONE proc issues `xschem raw add` directly"* and *"exactly ONE proc reads a value
   out of the raw"* — the rows C2's round hardened as the L2 discipline. Either the sentinel
   lives inside `calc::eval_rpn`, which puts a `raw set` between the create and the
   evaluating `raw add` and breaks `SR5`'s adjacency row, or it lives in its own proc, which
   breaks the two "exactly one" rows. Both are real losses in exchange for a real gain.
2. It does **not name a token** — it only says the engine refused. So it is a complement to
   (c), not a replacement.
3. It costs one extra full evaluation of the user's expression per press.

That is a Stage-E-sized change to the proc C2 had just finished hardening, and PLAN 3.3 was
the stage's headline. **The measurement is written into `calc::rpn_bad_token`'s own comment
so the next reader does not have to re-derive it.**

### (e) MEASURED AND NOT ADOPTED — the engine names the token itself

`plot_raw_custom_data()` has `dbg(1, "plot_raw_custom_data(): no data found: %s\n", n)`, and
`xschem log <f>` captures the C debug stream in-process. With `xschem debug 1`:

```
HIT: plot_raw_custom_data(): no data found: v(nosuch)
```

**The engine will name the token if asked.** Not adopted: it needs the global debug level
raised and the user's log file redirected for the duration of a button press, both of which
are user-visible side effects of an ordinary gesture, and `dbg(1)` is per-token so it floods.
Recorded because it is the only route that gets the token out of the C without a C change,
and because a C change (plumbing the return out of `raw_add_vector()`) is the clean long
answer and is one line plus a rebuild.

---

## 5. PLAN 3.3 — the acceptance, as trace data

PLAN's criterion: *"Typing `v(out) v(in) / db20()` and pressing Plot draws the gain curve."*
On the committed fixture `out` is `v(lp)` and `in` is `v(sq)` (the deck's `AC 1` drive).

Band `PL3` types that into the real `.calc.buf`, presses the real `.calc.mode.plot`, and then
**reads the materialised column back out of the viewer's own raw**, at three hand-derived
points. The hand values come from `tests/headless/data/README.md`'s ac table, derived with no
simulator in them (`H = 1/(1 + j f/1000)` with the pole at exactly 1 kHz by construction):

| index | f | the hand value | what the trace's column answered |
|---|---|---|---|
| 0 | 100 Hz | `-20·log10(√1.01)` = −0.04321373782642570 | `-0.043213738` |
| **9** | **1000 Hz** | **`-10·log10(2)` = −3.010299956639812** | **`-3.0103`** |
| 19 | 2000 Hz | `-10·log10(5)` = −6.989700043360187 | `-6.9897` |

Tolerance **1e-7 relative**, and the reason is the instrument, not the fixture: `xschem raw
value` prints through `dtoa()` — `"%.8g"` — so eight significant digits is the ceiling
(row `CE0` pins that format string; the README's 1e-12 figures are reachable only through
`xschem raw values`, `"%.16g"`).

And one more row, because three agreeing numbers could in principle come from a constant
column: `PL3` asserts the three are a **falling curve** (`[0] > [9] > [19]`).

The model, band `PL4`: the trace's `expr` is the buffer **byte for byte**, its `vec` is a raw
vector that really resolves in the viewer's context, that vector is **not** a `__calc_tmp`
one, and the buffer is unchanged (R603).

---

## 6. The red, quoted verbatim

### PLAN 3.4, before the code: 28 rows across two suites

```
FAIL     | test_calc_engine             run 1/2  RESULT: 25 FAILED (223 passed)
 FAIL: CE13 calc::rpn_tokens exists and splits on the engine's three delimiters -> {0 {ERR:invalid command name "calc::rpn_tokens"}} (exp {1 {v(lp) v(sq) / db20()}}) : FAIL
 FAIL: CE13 L1 STACKMAX read out of src/save.c, and calc::rpn_maxtokens is STACKMAX minus 2 -> {200 {ERR:invalid command name "calc::rpn_maxtokens"}} (exp {200 198}) : FAIL
 FAIL: CE13 R607 calc::eval_rpn REFUSES a rejected expression and names the token, instead of reporting issue 0325's defined zero -> {1 0} (exp {0 1}) : FAIL
 FAIL: CE13 R607 ...and R402 holds on the new refusal: it is taken BEFORE a destination is minted, so there is nothing to leak -> {{} __calc_tmp89} (exp {{} {}}) : FAIL
 FAIL: CE5 ...and the PRODUCT now refuses that expression by name instead of reporting the zero (R607, band CE13) -> {0} (exp {1}) : FAIL
 FAIL: CE7 a REJECTED expression is refused by name and leaves nothing behind -- it never reaches the mint -> {1 0 __calc_tmp67 {}} (exp {0 1 {} {}}) : FAIL
 FAIL: CE8 none of the five entry points raises with no window (R508's third case) -> {{calc::plot_click:invalid command name "calc::plot_click"} {calc::dest_changed:invalid command name "winfo"}} (exp {}) : FAIL
 FAIL: CE12 CLOSED (was a declared limit): the %<n> dataset spelling is now REFUSED BY NAME rather than reading as a silent zero (v(div)%1) -> {1 0} (exp {0 1}) : FAIL
FAIL     | test_calc_scratch_reuse      run 2/2  RESULT: 3 FAILED (47 passed)
 FAIL: SR2 ⚠ evaluate A, then a REJECTED B: the answer is a REFUSAL naming the token, never A's value -> {1 0 0} (exp {0 {} 1}) : FAIL
 FAIL: SR4 ⚠ a REJECTED expression is refused by TOKEN before the destination is even minted ... -> {0 0 1} (exp {0 1 0}) : FAIL
 FAIL: SR5 ...and the procs that reach the engine through the VIEWER's door instead are Plot's ... -> {} (exp {plot_rpn}) : FAIL
```

⚠ **One of those reds is a PRE-EXISTING DEFECT my own band widening exposed**, not a
consequence of this stage's code:
`calc::dest_changed:invalid command name "winfo"`. The proc shipped with a bare
`winfo exists`, which is R508's third case; it was unreachable while the proc was inert, and
widening `CE8`'s entry-point list from three to five is what found it. B3 recorded two such
sites and this is one of them.

### PLAN 3.3, before the code: 30 rows

Run against **`git show HEAD:src/calculator.tcl` put back in the tree** (serially, with md5
checks both ways), so this is literally the pre-stage product:

```
FAIL     | test_calc_plot               run 1/1  RESULT: 30 FAILED (28 passed)
 FAIL: PL3 the press landed exactly ONE trace -> {0} (exp {1}) : FAIL
 FAIL: PL3 ⚠ THE -3 dB POINT: the trace's own column at index 9 (f = 1 kHz exactly) is -10*log10(2) -> {NOTANUMBER:{}} (exp {ok}) : FAIL
 FAIL: PL3 ...and the three are a falling CURVE, not one number read three times -> {0 0} (exp {1 1}) : FAIL
 FAIL: PL4 the trace records the EXPRESSION the user typed, byte for byte -> {ERR:key "expr" not known in dictionary} (exp {v(lp) v(sq) / db20()}) : FAIL
 FAIL: PL5 Append accumulates: two presses, one strip, two traces -> {1 0} (exp {1 2}) : FAIL
 FAIL: PL6 ...and says so, naming the destination rather than a phase -> {plot destination Replace: not implemented (phase 3)} (exp {Plot destination: Replace.}) : FAIL
 FAIL: PL7 R607 an unresolvable token is NAMED, and it is the name the user typed -> {0 0} (exp {1 0}) : FAIL
 FAIL: PL7 an EMPTY buffer gets its own sentence, not a token one -> {{Plot: not implemented (phase 3)} 0} (exp {{Nothing to plot: the buffer is empty.} 0}) : FAIL
 FAIL: PL8 with no viewer there is no result either ... -> {Plot: not implemented (phase 3)} (exp {No simulation results are loaded...}) : FAIL
 FAIL: PL9 R508 none of Plot's three window-reading entry points raises with no window -> {{calc::plot_click:invalid command name "calc::plot_click"} ...} (exp {}) : FAIL
```

`PL0` and `PL1` passed on that tree, which is right — the fixture and the semaphore
measurement do not depend on Plot existing.

### ⚠⚠ THREE OF MY OWN ROWS WERE WRONG, NOT MERELY RED, AND RUNNING FOUND ALL THREE

1. **`CE13 L1 the engine's own boundary`** was red on a correct engine. The probe expression
   was `v(sq)` repeated N times, which pushes N values and lets the engine answer the LAST
   push — so 198 and 199 copies read back the same number and the boundary was invisible.
   One operand plus N unary `abs()` drives the PARSE stack (which is what the limit is on)
   while keeping the value stack at depth 1, and `v(sq)` is the fixture's AC-1 reference, so
   an evaluated expression reads 1 and a refused one reads issue 0325's zero.
2. **`CE13 … a good expression still answers over the same database`** quoted the −3 dB value
   and got `-6.9897`. R604 with no cursor published reads the **LAST** point, which on
   `ac lin 20 100 2k` is index 19. The row now quotes index 19's hand value and says so.
3. **Two rows PASSED VACUOUSLY on the unfixed tree** — `calc::eval_msg badtoken …` answered
   `{}` for an unknown kind and `dict get $d msg` was `{}` on the success path, so two empty
   strings compared equal and a row written to be red was green. Both now carry a
   non-emptiness term.

**All three were found by running the band before writing the code, which is the whole reason
the order is red-first.**

### And one in the new suite, found by running it green

`PL8` expected `calc::no_result_msg` — "No simulation results are loaded…" — and the product
answered `calc::no_viewer_msg`, because emptying the viewer registry leaves the ASE-L
**session** open and `calc::no_result_advice` then takes issue 0516's arm. The product was
right and the row was wrong. The band now drives **both** worlds and asserts each against the
resolver rather than against one hard-coded string, which is also the claim worth making:
R503f's point is that a new action must not grow a second spelling of either sentence.

---

## 7. Sabotages: 52, and the three that reddened NOTHING

Applied by a scripted patcher that **refuses to apply unless its anchor text is unique in the
file**; suites run; files restored from pristine copies; **md5 verified after every one**
(`final md5 check: OK`, both rounds). Harness in scratch, not in the tree. `C2-3` is a C
change and got its own rebuild in both directions.

### This stage's own — R607

| # | the plausible wrong implementation | reds | bands |
|---|---|---|---|
| **N1** | the pre-flight guard removed from `eval_rpn` entirely | 11 | `CE5`, `CE7`, `CE12`×2, `CE13`×5, `SR2`, `SR4` |
| **N2** | **a bare "expression error" instead of naming the token — exactly what R607 forbids** | 8 | `CE5`×2, `CE7`, `CE12`×2, `CE13`, `SR2`, `SR4` |
| **N3** | the token-count (L1) clause dropped | 2 | `CE5`, `CE13` |
| **N4** | off-by-one on the bound — `>=` for `>` | 1 | `CE13` |
| **N5** | the limit written as STACKMAX (200), not STACKMAX−2 | 2 | `CE13`×2 |
| **N6** | **a SECOND validator — the alphabet re-implemented as "a token with a bracket is a vector"** | 14 | `CE6`, `CE12`, `CE13`, `SR*` |
| **N7** | the tokeniser splits on ALL whitespace (`\S+`) | 2 | `CE13`×2 |
| **N8** | the pre-flight removed, so a mistyped token reports a column collision | 11 | as N1 |
| **N8b** | the pre-flight MOVED below the stale-destination guard | see below | |
| **N9** | fails CLOSED instead of open with no validator | 2 | `CE13`×2 |

### This stage's own — Plot

| # | the plausible wrong implementation | reds | bands |
|---|---|---|---|
| **P1** | **the destination never pushed at press time** | **0 → 2** | went green; band `PL5b` added |
| **P2** | the landing policy reimplemented — `add_trace` into strip 0, bypassing `plan_plot` | 4 | `PL5`×3, `PL5b` |
| **P3** | **`plot_signals`' per-signal failures discarded** | **0 → 1** | went green; band `PL5c` added |
| **P4** | the R607 pre-flight dropped from the Plot path | 2 | `PL7`×2 (the L1 rows — `add_trace` covers the name case and not the count) |
| **P5** | the context loan never given back | 1 | `PL1` |
| **P6** | no loan at all — `plot_rpn` in whatever context is current | 15 | `PL*` wholesale |
| **P7** | the R508 guard dropped from `plot_click` | 2 | `CE8`×2 |
| **P8** | `require_result`'s refusal ignored | 3 | `PL8`×3 |
| **P9** | `.calc.buf get 1.0 end` — the text-widget off-by-one | **0** | **declared: invisible to Plot.** The trailing newline is one of the engine's three delimiters, so the token set is identical, and `add_trace` trims. Sabotage `G` — the same edit — reddens **7** rows in `test_calc_buffer`'s `CB6`, which is the fence for it. |
| **P10** | `dest_changed` back to a message-only stub | 1 | `PL6` |
| **P11** | `dest_changed` uses a bare `winfo exists` — R508's third case | 2 | `CE8`×2 |
| **P12** | the Plot button wired back to `calc::inert` | 22 | `PL*`, `S18`, `CW13` |
| **P13** | `plot_dest_req` translates the label itself — a second label→code table | 1 | `PL2` |
| **P14** | the R402 delete applied to the TRACE's column too | 7 | `PL3`×4, `PL4`×2, `PL5` |
| **O-plot** | `plot_rpn` called without the loan from `plot_click` | 20 | `PL*` |

### Stage C's twenty-one, re-run

| # | reds | | # | reds | | # | reds |
|---|---|---|---|---|---|---|---|
| **A** | 6 | | **H** | 3 | | **O** | 2 |
| **B** | 1 | | **I** | 4 | | **P** | 3 |
| **C** | **0 → 1** | | **J** | 12 | | **Q** | 2 |
| **D2** | **0** (declared unfenced) | | **K** | 67 | | **R** | 2 |
| **E** | 2 | | **L** | 20 | | **S** | 1 |
| **F** | 2 | | **M** | 79 | | **T** | 1 |
| **G** | 7 | | **N** | 2 | | | |

### Stage C2's, re-run

| # | reds | |
|---|---|---|
| **C2-1** | 4 | the `annot_sweep_idx` term dropped |
| **C2-1b** | **0** | declared unfenced in the code, unchanged |
| **C2-1c** | 7 | the discriminator reads field 1 |
| **C2-2** | 12 | the non-finite refusal removed |
| **C2-2b** | 8 | `eval_finite` as a denylist |
| **C2-2c** | 4 | R607 violated for the non-finite case |
| **C2-3** | 3 | the COND arm's `dbg` back to level 0 — **rebuilt in both directions**; `CE11`×3 |
| **C2-4** | 1 | test-side: the 16-digit reader "simplified" to the 8-digit accessor. Applied BY HAND, because it has two occurrences and the unique-anchor harness correctly refused it |

### ⚠⚠ THREE SABOTAGES WENT GREEN, AND ONE OF THEM I BROKE IN THIS STAGE

**`P1` — the destination is never pushed at press time — reddened ZERO.** Every band
reached the combobox through a helper that fires `<<ComboboxSelected>>`, so
`calc::dest_changed`'s push had already put the destination in place and the press-time push
was redundant *on the path the suite drove*. It is not redundant on the path it exists for: a
destination chosen before a viewer was open. Band **`PL5b`** now sets the widget **directly,
with no event**, so the press-time push is the only thing that can work — and asserts both
that `wviewer::plot_dest` moves and that the landing strip was **emptied first**. `P1` now
reddens 2.

**`P3` — the seam's failure list discarded — reddened ZERO**, because every refusal the file
drives is caught by R607's *pre*-flight and never reaches `wviewer::plot_signals` at all.
Band **`PL5c`** shims the viewer verb (not the product proc) to force a failure, asserts the
sentence is `Plot failed: <the viewer's message>.` and never `Plotted`, and carries a control
leg proving the shim is what made the difference. `P3` now reddens 1.

**⚠ `C` — Stage C's pre-engine-guard sabotage — went from 1 red to ZERO, AND MY OWN ROW DID
IT.** Restating `SR4` for the new refusal, I added a third arm that evaluates `$A` again
after `$B`. With the pre-engine guard removed, `$B` overwrote the planted 5 with 2.5 and then
`$A` wrote 5 **back**, so the end-of-band data check saw exactly the value it expected. That
is CLAUDE.md's *"a fence keyed to a symptom dies quietly when something else cures the
symptom"* — caused here by the row added beside it. `SR4` now re-reads the planted column
**after each of the three calls**, which is strictly stronger than what Stage C had, and `C`
reddens 1 again.

**And `N8b` as first written was a NO-OP**: it *added* a second pre-flight after the stale
guard without removing the first, so the original still ran and nothing moved. The real
"moved below the guard" mutation is `N8`'s removal plus that addition; it is recorded here
because a sabotage that cannot change behaviour is a sabotage that proves nothing, and
reading the 0 rather than the count is what caught it.

---

## 8. `test_wave_markers` — the named outcome, and whose it is

```
TIMEOUT  | test_wave_markers            run 1/1 (after 200s)
RESULT: 0/1 runs passed
```

This is the hazard the task named: CLAUDE.md records *"`test_wave_markers` times out when
`run_suites.sh` attaches to a dev display (issue 1488, pre-existing): with `:99` up that
`TIMEOUT` is not your change."* It was given a timeout and watched; it is reported, not
retried silently, and nothing about it was skipped or lengthened.

**And it is measured rather than cited.** See §8b for the control run against
`git show HEAD:src/calculator.tcl` in the tree.

---

## 9. The claim audit — every comment sentence, row name and citation I added

Required field. I walked every sentence I wrote and said how I checked it. **It refuted four,
one of which I had already shipped in this stage.**

| claim | how checked | verdict |
|---|---|---|
| `my_strtok_r(ntok_ptr, " \t\n", "", 0, …)` is the engine's delimiter set | read `plot_raw_custom_data()`; row `CE13` reads the string out of that call every run | ✓ |
| `STACKMAX - 2` is the largest expression that evaluates | row `CE13` reads `#define STACKMAX` out of `src/save.c` and drives the engine at 198 and 199 | ✓ |
| `wviewer::add_trace` returns `{}` for a 199-token expression | driven through the real viewer; row `PL7`'s control leg | ✓ |
| `validate_rpn` mirrors `get_raw_index()`'s ladder and `add_trace` already calls it | read both bodies | ✓ |
| `nan`/`inf` are numbers to the engine, declined by the mirror | driven; rows in `CE13` | ✓ |
| a negative `del()` delay returns −1 from a stack VALUE | read `case DEL` in `src/save.c` | ✓ |
| the `raw set` sentinel sees all three `-1` classes | **driven for all four cases** (§4d) — the first draft of this sentence said "all three" having measured only two, and the third (stack overflow) was measured before the sentence shipped | ✓ after measuring |
| **"re-joining the engine's tokens makes the two tokenisations agree by construction"** | **driven. IT DOES NOTHING** — `join` of a one-element list is that element, `\r` and all, and the validator re-splits it | ✗ **FALSE, and it had already shipped in this stage's first green run.** The line is removed, the divergence is DECLARED, and `CE13` gained five rows measuring it in both directions |
| **"Table (W14) is the only control on this strip still inert"** | `/usr/bin/grep -n calc::inert` on the same proc | ✗ **FALSE** — the pick-scope radios and Clip are inert too (phase 6). Narrowed to "the only ACTION BUTTON" |
| **"each of these four [`dcases` calc suites] takes a no-X exit printing `RESULT: SKIP (...)`"** | read all four gates | ✗ **FALSE** — `test_calc_skeleton` prints `RESULT: ALL PASS (0 checks)`, a hollow pass. Corrected in `tests/run_regression.tcl` |
| **CE12's restated header: "three rows in this band went red"** | counted the red run's output | ✗ **FALSE** — two. The number is gone, and the correction says why: a count nothing re-measures arrived in the very comment written to record the change |
| "the ONE seam every other plot gesture comes through (Direct Plot and the signal browser's three)" | `grep -n wviewer::plot_signals src/*.tcl` | ✗ over-claimed a count. Rewritten to state the shape and name the grep |
| **PL5's row name "the strip it landed in holds exactly the one new trace"** | re-read the assertion | ✗ the row asserted only the LAST trace's `expr`, not how many that strip held. Now asserts the per-strip counts |
| a Calculator button `-command` has semaphore 0 | driven from inside a real `-command`; row `PL1` | ✓ |
| `enter_ctx`'s borrow door is documented read-only | quoted from its own comment, checked word for word | ✓ |
| `set_plot_dest` emits a CIW error with no viewer | read its body | ✓ |
| `dest_changed` shipped a bare `winfo exists` that raises under `--nogui` | **the red run printed it**: `calc::dest_changed:invalid command name "winfo"` | ✓ |
| spec §11.3 names `test_calc_plot.tcl` | grepped the spec | ✓ |
| RB6's hazard applies to an `hcases` entry with a dead gate | read RB6; **and measured `regression_case_failed(0)=1` on the real `--nogui` capture** | ✓ |
| L2 is not in play on the Plot path | read `plot_raw_custom_data()`'s `yname` handling and `auto_expr_name` | ✓ |
| R602 is unreachable without contradicting U7/R503f | read `results_source`/`session_result`; row `PL8` drives both worlds | ✓ |
| every `wviewer::*` and `calc::*` symbol cited | each one grepped in the tree before the sentence shipped; no `file:line` citations were added | ✓ |

**Four false sentences in one stage, three of them written in the round that was fixing the
previous one.** That is the same shape CLAUDE.md records from the 1608 batch, and the only
thing that caught them was walking the list rather than trusting it.

---

## 10. What I did NOT do, and why

* **No T1 run.** The driver's job and the brief forbids it. §11 is the unit-level substitute
  for *scoring*, not for *running*.
* **No expression evaluator, no parser, no second tokeniser, and no second trace inserter.**
  Sabotage `N6` writes the second validator and reddens 14 rows; `P2` writes the second
  landing policy and reddens 4.
* **No C change.** §4e's `dbg`-level route and the "plumb `plot_raw_custom_data()`'s return
  out of `raw_add_vector()`" route are both reported, not taken.
* **The `raw set` sentinel is NOT in the product** (§4d), with the reasons and the
  measurement.
* **R602's letter is declined** (§2 of `calc::plot_rpn`'s header, row `PL8`), and filed as a
  `rule` debt rather than decided.
* **Two R607 blind spots are declared, not closed**: a negative `del()` delay and a
  `\r`/`\v`/`\f`-joined token. Both are rows in `CE13` pinning what the product does.
* **`calc::status_recall` still has a bare `winfo exists`.** I fixed `dest_changed`'s because
  `CE8` now reaches it; that one is still unreachable without a window and is still open
  (B3's list).
* **The fixture was not regenerated and not touched.** No `xschem save` or `saveas` anywhere
  in this stage; zero occurrences in the new suite.
* **Nothing verified by eye, and no `look` debt incurred.** Every claim here is a row, a
  quoted command output, or a predicate lifted from the tree. **Pixels are declared
  unverified in one line: that the gain curve is DRAWN is eyeball-only** — what is asserted
  is the model, the materialised column's numbers at three hand-derived points, and that the
  regenerate returned without error.
* **Two `rule` debts filed**, both as ADDITIONS to the existing `calc_eval_wording_phase3`
  rather than overwrites: `calc_plot_wording_phase3` (eight new Plot sentences) and
  `calc_plot_r602_opens_a_viewer` (the declined requirement). The ledger was backed up first
  (`cp -r ~/.claude/xschem_owed …`). **I cleared nothing.**
* **No permission prompt denied me anything.**
* **Nothing is committed, pushed or stashed.**

---

## 8b. The `test_wave_markers` control — whose timeout it is, measured

Citing CLAUDE.md is not the same as measuring, so the control was run: **`git show
HEAD:src/calculator.tcl` put back in the tree**, serially, with md5 checks both ways, and the
same suite run again through the same armed spelling on the same dev display.

| tree | outcome |
|---|---|
| this stage's `src/calculator.tcl` | `TIMEOUT  | test_wave_markers  run 1/1 (after 200s)` |
| **`HEAD:src/calculator.tcl` (pre-3.3)** | **`TIMEOUT  | test_wave_markers  run 1/1 (after 200s)`** |

Byte-identical outcome on both, and `src/calculator.tcl` restored to
`6e2c706073d1e977a0ca72ef52fa0154` after. **It is pre-existing (issue 1488) and not this
stage's.** Both runs were given an outer `timeout 400` on the driver and watched; `run_suites.sh`'s
own `SUITE_TIMEOUT` is what produced the 200 s line, so the stall is a NAMED outcome in both
cases and not silence.

⚠ What the control does NOT establish: that the suite would pass on a private Xvfb with the
dev display down. CLAUDE.md says it does; I did not test it, because taking `:99` down is on
the brief's do-not-touch list.

---

## 11. The trailer delta — derived from `summarize_all`'s OWN regexp arms

Method: capture each case **exactly as T1's own loop does** — the `dcases` arm through
`devdisplay.sh exec … --pipe -q --logdir <dir> --script <t>.tcl` (the single line
`run_regression.tcl` builds as `$dccmd`), the `hcases` arm through
`env -u DISPLAY … --nogui --pipe -q --nolog --script`, stdout and stderr together, HOME armed
through `tests/headless/test_home.sh` — then **lift `summarize_all` and `t1_carry_line` out of
`tests/run_regression.tcl`'s own text** (a line scan from `^proc <name>` to the first line
that is exactly `}`), `source tests/banner_rule.tcl`, and run the lifted proc over that
capture. No figure below is quoted from a receipt.

```
lifted: t1_carry_line (5 lines)
lifted: summarize_all (89 lines)
--- the lifted summarize_all's arms, as it spells them ---
>> if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]} {
>> } elseif { [regexp {^(NOGOLD|NODISPLAY)} $line] } {
>> } elseif { [regexp {^skip:} $line] } {
>> } elseif { [regexp {^RESULT:} $line] } {
>> } elseif { [banner_complete $line] && [regexp {\([^)]*\)} $line] } {

=== plot.disp: lines=77 counted-shape=0 lowercase(^skip:)=0 any-case(^skip)=0 ^RESULT:=1 NOGOLD/NODISPLAY=0 col0_OVERALL=1
    banner_complete=1 banner_died=0 regression_case_failed(0)=0
    summarize_all returned: 0 ; blocks +1 ; skips +0
plot.disp
RESULT: ALL PASS (67 checks)
Total num fail: 0

=== test_calc_engine.nogui: lines=289 counted-shape=0 lowercase(^skip:)=0 any-case(^skip)=0 ^RESULT:=1 NOGOLD/NODISPLAY=0 col0_OVERALL=1
    banner_complete=1 banner_died=0 regression_case_failed(0)=0
    summarize_all returned: 0 ; blocks +1 ; skips +0

=== test_calc_scratch_reuse.nogui: lines=60 counted-shape=0 lowercase(^skip:)=0 any-case(^skip)=0 ^RESULT:=1 NOGOLD/NODISPLAY=0 col0_OVERALL=1
    banner_complete=1 banner_died=0 regression_case_failed(0)=0
    summarize_all returned: 0 ; blocks +1 ; skips +0
```

**Exactly one column-0 `RESULT:` and one column-0 `OVERALL:` per file** — issue **1627**'s
shape re-measured, because a second trailing `RESULT:` would silently rewrite the published
check count. The new file has two exit paths and the no-X one prints its verdict INSTEAD of
the other, never as well.

**This stage's contribution, derived:** **+1 case, +1 block, +0 counted failures,
+0 `^skip:` lines, +3 verdict lines** (one new block × the case label, the published
`RESULT:` and `Total num fail:`). Relative to the driver's committed baseline **120/119/0/8**
at `47ea655a` that gives **121 cases / 120 blocks**, counted by the prescribed method
(`tcases` 3 + `hcases` 93 + `dcases` 24 + `xschemtest`).

Published check counts that move inside EXISTING blocks: `test_calc_engine` 217 → **253**,
`test_calc_scratch_reuse` 49 → **51**. `test_calc_skeleton` (548) and `test_calc_widgets`
(246) are unmoved — both edits were comment-and-expectation only. A check-count change moves
no line count.

⚠⚠ **THIS IS A DERIVATION OVER MY OWN SUITES' OUTPUT, NOT A PREDICTION OF THE TRAILER, AND IN
PARTICULAR NOT A PREDICTION OF `skips=`.** CLAUDE.md records several occasions where careful
reasoning about registration shape got that figure wrong — most recently issue 1625, where an
adversarial verifier AND the driver both predicted movement and both were wrong, because
`summarize_all` counts **lowercase** `^skip:` and suites announce skipped bands with an
uppercase `SKIP:`. What I measured is that **my** case contributes **zero** lines the
`^skip:` arm matches, and `any-case(^skip)=0` too, so there is nothing of either spelling to
be wrong about — and that `test_calc_plot`'s own no-X line is `RESULT: SKIP (…)`, which the
`^RESULT:` arm takes and the `^skip:` arm does not, but which T1 never reaches because the
entry is `dcases` only. Every other case is unchanged: the only shared file I touched is
`tests/run_regression.tcl`, and I added one entry and two comment paragraphs to it.
**Read the trailer.**

---

## 12. `git status --short` at the end

```
 M src/calculator.tcl
 M tests/headless/test_calc_engine.tcl
 M tests/headless/test_calc_scratch_reuse.tcl
 M tests/headless/test_calc_skeleton.tcl
 M tests/headless/test_calc_widgets.tcl
 M tests/run_regression.tcl
?? .xschem/
?? doc/claude/calculator_batch/receipts/D-plot.md
?? doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
?? tests/headless/test_calc_plot.tcl
```

**Of those I changed exactly eight**: `src/calculator.tcl`, `tests/run_regression.tcl`,
`tests/headless/test_calc_engine.tcl`, `tests/headless/test_calc_scratch_reuse.tcl`,
`tests/headless/test_calc_skeleton.tcl` (one sentence and one branch),
`tests/headless/test_calc_widgets.tcl` (one list entry and its comment), the new
`tests/headless/test_calc_plot.tcl`, and this receipt.

⚠ **`.xschem/`, `doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md` and
`sky130A/.../debug_st1/` are NOT mine** — all three were in this session's starting snapshot
and I did not open any of them for writing.

`src/save.c` is **unmodified**: it was sabotaged once (`C2-3`), rebuilt, run, restored and
rebuilt again, and its md5 is back to `e0429f722665b90b5a2689423f346bda`. The committed
fixture `tests/headless/data/calc_fixture.raw` was read only and never written; there is no
`xschem save` or `saveas` anywhere in this stage. `tests/headless/.scratch/` is empty after
the runs, and the `--logdir` of the capture runs pointed into my own scratch directory.
**Nothing is committed, pushed or stashed.**

---

## 13. What the next stage must know

1. ⚠⚠ **R607 HAS TWO DECLARED BLIND SPOTS AND THE METHOD THAT CLOSES BOTH IS MEASURED AND
   SITTING IN A COMMENT.** The `xschem raw set` sentinel (§4d) answers correctly for all three
   of the engine's `-1` classes. Adopting it is a change to `calc::eval_rpn` and to rows `SR5`
   holds, so it is a stage of its own — but it does not need re-measuring. The two blind spots
   are a negative `del()` delay and a `\r`/`\v`/`\f`-joined token; both are pinned by rows in
   `CE13`, so closing either reddens and forces the declaration to be corrected.
2. ⚠ **`xschem raw set <node> <point> <value> [<dataset>]` EXISTS** (`src/scheduler.c`) and
   nothing in this batch knew it. It writes `raw->values[idx][point]` in place and calls
   `annot_data_changed()`. That is what makes the sentinel possible and it is reusable for any
   probe that needs a known value in a known column.
3. ⚠ **R602 IS DECLINED, NOT FORGOTTEN**, and the spec text is now known-wrong where it says
   Plot opens a viewer. `rule` debt `calc_plot_r602_opens_a_viewer` carries the question, the
   measurement, both sentences the user actually gets, and the cost of overruling. Row `PL8`
   pins the current behaviour and asserts no Plot proc's CODE names a viewer-opening verb, so
   a reversal cannot land silently.
4. ⚠ **A Calculator Tk button `-command` has `xschem get semaphore` == 0**, measured from
   inside a real press (row `PL1`). So the plain `wviewer::enter_ctx` door is enough for any
   future Calculator gesture that WRITES, and the issue-0314 borrow door — which is documented
   read-only — should not be widened for one. A gesture reached from a drawing-area keybinding
   is a different world and would be refused.
5. **`wviewer::plot_signals` is the ONE seam and it was NOT extended.** `calc::plot_rpn` pushes
   the destination and calls it; everything about where a trace lands is `wviewer::plan_plot`'s.
   Phase 3.6's Table and any later plot gesture should come through the same door. A second
   landing rule reddens 4 rows (sabotage `P2`).
6. ⚠ **A TRACE'S COLUMN IS PERSISTENT AND MUST NOT BE DELETED.** R402's `raw del` discipline
   belongs to Evaluate's `__calc_tmp` scratch column only. Applying it to the Plot path blanks
   the trace and reddens 7 rows (sabotage `P14`). `wviewer::auto_expr_name` owns the name.
7. ⚠ **`wviewer::add_trace` does NOT catch landmine L1.** It returns `{}` for a 199-token
   expression while the engine writes nothing. Any later caller of that verb needs
   `calc::rpn_maxtokens` in front of it, or it reports a trace full of zeros.
8. ⚠ **`calc::status_recall` still carries a bare `winfo exists`** (R508's third case). I fixed
   `calc::dest_changed`'s because band `CE8` now reaches it; that one is still unreachable
   without a window. It will raise the moment anything headless calls it.
9. **Band `CE8`'s phase-3 proc sweep is keyed to four NAME FAMILIES** — `eval_*`, `rpn_*`,
   `plot_*`, `dest_*`, plus `tmpvec`. A new proc outside them escapes the R508 guard rows
   silently, which is exactly what `receipts/C-evaluate.md` item 4 predicted and what this
   stage's widening fixed. Name new procs into a family, or widen the glob in the same change.
10. **Re-run the PREVIOUS stages' sabotages, and read the ZEROES.** Stage C's `C` went green
    because of a row *I* added to `SR4` in the same change — the third occurrence in this batch
    of a fence dying because something beside it cured the symptom. Two of my own Plot
    sabotages also reddened nothing, and both were real gaps. **The count is not the
    information; the zero is.**
11. ⚠ **Do not predict `skips=`, and do not predict the published check count either.** §11
    derives this stage's own contribution and says plainly that it is not a prediction of the
    trailer.
