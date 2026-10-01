# Receipt A2 — close the seven adversarial findings against the issue-1626 fence

Stage **A2** of `doc/claude/calculator_batch/`, worked 2026-09-30 on `fluid-editing` at
`621c1ff5`. **Nothing is committed** — the work is left in the tree for the driver, which
keeps the T1 gate. Stage A's receipt (`A-register-1626.md`) is a dated record and is
**not edited**; every correction to it is in §F1 and §9.3 below.

The fence suite went from **7 checks to 10** and all seven findings are closed. Four reds
were real reds on the real tree; two more were produced on a synthetic tree built for the
purpose; one finding (F1) is a comment and no red is possible, which is said plainly
rather than dressed up.

---

## F1 — the shipped comment that contradicted the shipped receipt

**Outcome: fixed. No red is possible — this is a comment, and nothing in the tree reads
it.** Quoted before and after, as the task requires.

### Before (`tests/headless/test_calc_skeleton.tcl`, verdict block)

```
## ⚠ ADDITIVE, AND `RESULT:` STAYS LAST. `summarize_all` in run_regression.tcl
## publishes a case's LAST `RESULT:` line into the verdict and run_suites.sh greps
## the last one, so removing or reordering it would blank the check count in both.
## The precedent is `wvbs_finish` in tests/headless/wvbs_common.tcl.
```

The clause **"or reordering"** is false and Stage A's own §6(c) measured it false:
reordering changed nothing in any of the three readers, and that receipt's own words are
*"Nothing catches it and nothing should"*. The comment contradicted the receipt written
in the same stage.

### After

```
## ⚠ ADDITIVE, AND `RESULT:` MUST BE THE LAST `RESULT:` LINE — WHICH IS NOT THE
## SAME CLAIM AS "AFTER THE BANNER", and an earlier revision of this comment got
## that wrong. `summarize_all` in run_regression.tcl publishes a case's LAST
## `^RESULT:` line into the verdict and run_suites.sh does `grep -E '^RESULT' |
## tail -1`. Both are order-INDEPENDENT: printing `RESULT:` *before* the banner
## was measured and all three readers stayed green, correctly, because
## `banner_complete` is `regexp -line` over the whole captured body. So
## reordering these two lines costs nothing and nothing in the tree catches it.
## What DOES cost something is a SECOND `RESULT:` line after this one: the
## published check count silently becomes whatever the last one says, with
## `counted_failures` and `skips` both still 0 and no reader reddening —
## measured at 244 → 0 on this batch's sibling suite. That is issue **1627**,
## which is OPEN and unfenced, and the way it arrives is a suite with more than
## one exit path printing a verdict on more than one of them. This suite has two
## exit paths today (here and the no-DISPLAY gate near the top of the file) and
## the Calculator's later phases add more, so a new exit path must print its
## verdict instead of this one, never as well. The precedent for the ordering is
## `wvbs_finish` in tests/headless/wvbs_common.tcl, whose own comment says the
## same thing.
```

`test_calc_widgets.tcl`'s version was already correct (it stops before the false clause).
I extended it anyway with the same **1627** pointer and the "a third exit path must print
its verdict INSTEAD of one of these" instruction, because 1627 names *both* suites as
having two exit paths today and the pointer is the actionable half. That is a small scope
decision I took rather than queued; it changes no behaviour.

**Re-measured here, not taken from Stage A:** `^RESULT:` count over this suite's real
display-arm log is **1** (§7), which is the property 1627 is about.

---

## F2 — RB2 is arm-blind: the finding two lenses raised independently

**Outcome: fixed, both halves. Red first, on the real tree.**

### (a) The red — the current fence stays green while the registration is wrong

`headless/test_calc_widgets` added to `hcases` in `tests/run_regression.tcl`, nothing else
changed, fence run armed and headless:

```
PASS     | test_registered_banner_1626  run 1/1  RESULT: ALL PASS (8 checks)
RESULT: 1/1 runs passed
```

and what T1 would actually have done with that entry, over that suite's **real** `--nogui`
output, scored by `tests/banner_rule.tcl`'s own predicates sourced:

```
RESULT: SKIP (no X: the Calculator widget inventory is Tk-only)
banner_complete=0 banner_died=0 regression_case_failed(0)=1
```

So: a counted `HARNESS: … (exit=0, OVERALL_ok=0, died=0)` in T1, with the new fence
reporting `ALL PASS`. The 1615/1626 incident repeated with the fence silent.

### The fix — `rb_nogui_gate` / `rb_nogui_dead`, and row `RB6`

New symbols in `tests/headless/test_registered_banner_1626.tcl`:

| symbol | what |
|---|---|
| `rb_scan_text` | `rb_emitters`' per-text scan, **taken apart** so the same scan can be aimed at a fragment. `rb_emitters` now calls it. |
| `rb_nogui_gate` | returns the BODY of a whole-file no-X early-exit gate, or empty. Three conditions, each load-bearing and each sabotaged below: an `if` at file scope whose condition tests the **absence** of a display, whose statement is taken by brace balance, and whose **body `exit`s**. |
| `rb_nogui_dead` | 1 when that gate exists and `rb_scan_text` finds no banner **inside** it. |
| `RB6` | assertion: the list of `hcases` entries for which `rb_nogui_dead` is 1 is **empty**; plus a four-fixture control battery. |

**Keyed to the property, not the two names.** `RB6`'s assertion is over every `hcases`
entry; the two Calculator suites appear only in the information the row prints. A third
Tk-only suite registered in `hcases` is caught without the row being edited.

**Anti-vacuity is keyed to this file's own fixtures, not to the tree.** That is the
mistake F5 is about, and I did not repeat it here: the controls are `g1` (gate, no banner
inside — must be flagged), `g2` (gate that prints the banner before exiting — must NOT
be), `g3` (no gate — must NOT be), `g4` (a no-X guard that does **not** exit, i.e. a
per-band skip — must NOT be).

### The green, same sabotage still in place → row reddens and names the entry

```
FAIL: RB6 no `hcases` entry takes a whole-file no-X early exit whose body prints no completion banner, … Registered suites with the shape, as information and re-measured every run: 2: test_calc_skeleton test_calc_widgets -> {headless/test_calc_widgets {g1=1 g2=0 g3=0 g4=0}} (exp {{} {g1=1 g2=0 g3=0 g4=0}}) : FAIL
RESULT: 1 FAILED (8 passed)
```

Sabotage byte-reverted (`md5sum` of `tests/run_regression.tcl` matched the pre-sabotage
copy), then:

```
PASS     | test_registered_banner_1626  run 1/1  RESULT: ALL PASS (9 checks)
```

### What the detector derives, measured over the whole registered set

`hcases` entries with the shape: **0** — so the row is green at HEAD and is **not** a
false red. Registered entries with the shape: exactly **2**, the two Calculator suites.
And a third registered suite has a no-X whole-file exit gate but prints
`OVERALL: ok` **inside** it before exiting — `test_headless_guards_xarm_1492`, a `dcases`
entry — so it is correctly **not** flagged. That is an in-tree control for `g2`'s arm and
the row's name says so.

### (b) L6, the general limit, declared in the header in the L1–L5 voice

```
##   L6  ⚠ RB2 IS ARM-BLIND. It unions `hcases` and `dcases` and asks one
##       question of a suite's whole text, so it cannot say that a banner is
##       reachable on the HEADLESS arm and unreachable on the display one, or
##       the reverse. A fully general answer needs per-arm reachability
##       analysis, which L5 says this file does not do and which it deliberately
##       does not attempt: the cost of guessing wrong in the rejecting direction
##       is a standing red in T1. What IS fenced is the one arm-dependent shape
##       that can be read off the text -- the whole-file no-X early exit both
##       Calculator suites use -- and RB6 asserts no `hcases` entry has it. A
##       suite made unreachable-on-headless by any OTHER means (a `return` at
##       file scope, a gate spelled some third way, a banner inside a proc only
##       the display arm calls) is NOT detected, and T1's own HARNESS line is
##       still the backstop. RB6's controls say which shape it reads.
```

I did **not** attempt reachability analysis, as instructed.

---

## F3 — nothing asserted the registration itself

**Outcome: fixed. Red first, on the real tree.**

### The red

Both `dcases` entries deleted from `tests/run_regression.tcl`
(`/usr/bin/grep -c 'headless/test_calc' tests/run_regression.tcl` → **0**):

```
PASS     | test_registered_banner_1626  run 1/1  RESULT: ALL PASS (9 checks)
RESULT: 1/1 runs passed
```

Issue 1626's headline defect — 789 checks gating nothing — could come back silently, and
the fence built to stop it said nothing.

### The fix — row `RB7`, following row `V57` of `tests/headless/test_op_annot.tcl`

Three legs over the **lifted** lists (`$hc`, `$dc`, taken out of the driver's own text by
`rb_list_items`, not re-spelled here): `headless/test_calc_skeleton` in `dcases`,
`headless/test_calc_widgets` in `dcases`, `headless/test_registered_banner_1626` in
`hcases`. The third leg turns this file's "it also checks itself" claim from header prose
into an assertion.

**Names are right here and the property is right in RB6.** "Is this suite registered"
cannot be derived from any property of the tree — the whole hazard is that the tree looks
fine without the entries. `V57` does the same thing for the same reason.

### Still with the deletion in place → reddens and says which legs

```
FAIL: RB7 the two suites this fence exists for are registered in `dcases` by name and this fence itself is registered in `hcases`, lifted from the driver's own lists -- so a deregistration that nothing notices cannot put issue 1626's defect back (precedent: row V57 of tests/headless/test_op_annot.tcl) -> {0 0 1} (exp {1 1 1}) : FAIL
RESULT: 1 FAILED (9 passed)
```

Restored (md5 match), then `RESULT: ALL PASS (10 checks)`.

**The NOTE a lens raised is covered by this row**: `RB1`'s name carries an entry count
that asserts nothing, and `RB7` now asserts the three entries that matter by name. I did
**not** add an assertion about the count itself — a hardcoded 96 is exactly the number
nothing re-checks that CLAUDE.md forbids, and the list's *content* is the thing with
meaning.

---

## F4 — two idiomatic spellings RB2 false-redded

**Outcome: fixed. Red first, and both spellings RUN before being accepted.**

### Both fixtures really do print a line `banner_complete` accepts

```
--- tclsh fmt.tcl ---                      --- tclsh app.tcl ---
OVERALL: ok (7 checks)                     OVERALL: ok (7 checks)
RESULT: ALL PASS (7 checks)                RESULT: ALL PASS (7 checks)
--- xschem --nogui fmt.tcl ---
OVERALL: ok (7 checks)
--- banner_complete over each ---
fmt.tcl banner_complete=1
app.tcl banner_complete=1
```

(`fmt.tcl` is `puts [format "OVERALL: ok (%d checks)" $n]`; `app.tcl` is
`set b "OVERALL:"` / `append b " ok ($n checks)"` / `puts $b`.)

### The red — fixtures `a6` and `a7` added to RB3's must-be-accepted side first

```
FAIL: RB3 the predicate's own controls: 12 synthesized suites, 6 that must be accepted and 6 that must be rejected -> {a1=1 a2=1 a3=1 a4=1 a6=0 a7=0 r1=0 r2=0 r3=0 r4=0 r5=0 r6=0} (exp {a1=1 a2=1 a3=1 a4=1 a6=1 a7=1 r1=0 r2=0 r3=0 r4=0 r5=0 r6=0}) : FAIL
RESULT: 1 FAILED (6 passed)
```

### The fix

* `rb_brace_body` generalised to **`rb_group_body {s op cl}`** (braces or square
  brackets); `rb_brace_body` is now a one-line wrapper.
* new **`rb_word_literals`** — every double-quoted and brace-quoted literal in a string,
  in textual order.
* `rb_puts_args` gained a **`cmd`** kind for a command-substitution word. The accepting
  rule is the conservative one L1 already applies to `$v`: look at the text the spelling
  carries, i.e. the quoted literals inside the brackets. `%d` survives `rb_render` and
  `(%d checks)` matches `banner_complete`'s `\([^)]*\)` trailer.
* `rb_var_literals` follows **`append` beside `set`**, and — the part a naive reading of
  the finding misses — returns the **in-order concatenation** as well as the individual
  literals. `append` is useless without it: neither `"OVERALL:"` nor `" ok (…)"` is a
  banner on its own. Fixture `a7` is built from a deliberately split `$RB_OKH`/`$RB_OKT`
  so this is what it tests.
* `rb_emitters` handles the new kind through `rb_scan_text`.

### The green

```
ok:   RB3 the predicate's own controls: 13 synthesized suites, 7 that must be accepted and 6 that must be rejected
```

(13/7/6 counts `a8` as well — see F7.) All six reject fixtures stayed rejected, including
`r4` (`puts $fd "…"`), which the new bracket arm must not reach.

---

## F5 — RB4 was keyed to the continued existence of the imperfection it documents

**Outcome: fixed. Red first, on a synthetic tree built to be STRICTLY BETTER than the
real one** — which is the whole point of the finding: no red was possible on the real
tree, because the real tree still has the imperfection.

### The red

A mini tree under scratch — `tests/banner_rule.tcl` and `tests/headless/scratch.tcl`
copied, a synthetic `tests/run_regression.tcl` whose `hcases`/`dcases` name three suites
that each print `OVERALL: ok` **literally**, and the **real** fence suite copied in beside
them so `$repo` resolves to the mini tree:

```
ok:   RB0 …
ok:   RB1 every one of the 3 registered entries resolves to a suite file …
ok:   RB1b …
ok:   RB2 …
ok:   RB3 …
ok:   RB3b …
FAIL: RB4 the plausible wrong implementation -- a one-file scan of the suite's own non-comment text -- would false-red 0 registered suites this predicate accepts:  -> {0} (exp {1}) : FAIL
ok:   RB5 …
RESULT: 1 FAILED (7 passed)
```

A tree in which every registered suite emits the literal sentinel is better in every way,
and the old `RB4` called it a failure.

### The fix — two legs, neither needing the tree to stay imperfect

* over the **registered** set: naive-rejected is a **subset** of accepted. True vacuously
  when that set is empty, and violated the moment the resolved predicate becomes
  *narrower* than a plain text scan.
* over **this file's own** control fixtures: at least one must-be-accepted fixture is
  rejected by the naive scan, so the gap the resolved predicate exists for is demonstrated
  on fixtures nobody else's commit can cure. `FIXREC` records each fixture's id,
  expectation and path (including `a5`, RB3b's sourced-common pair) for this leg.

The registered-suite count and names stay in the check **name** as information,
re-measured every run.

### The green, both trees

mini tree (the false-red case):

```
ok:   RB4 the resolved predicate is not interchangeable with a one-file text scan … and at least one must-be-accepted control fixture is rejected by that scan (a3 a7 a5) … Registered suites the scan would false-red, as information and re-measured every run: 0: 
RESULT: ALL PASS (8 checks)
```

real tree:

```
ok:   RB4 … (a3 a7 a5) … Registered suites the scan would false-red, as information and re-measured every run: 14: test_ase_campaign_1462 test_ase_campaign_gui_1464 test_ase_conv_gui_1460 test_ase_converge_1459 test_ase_effective_1442 test_ase_events_1465 test_ase_meas_1443 test_ase_optsheet_1441 test_ase_simwin_variant_1471 test_ase_sp_1452 test_ase_trnoise_1466 test_ase_trnoise_gui_1467 test_ase_variant_1470 test_wave_sigbrowser_panes
```

⚠ **The re-keying did NOT weaken the row against its actual target.** Sabotage SAB-5
below replaces `rb_emitters` with the naive scan and the new `RB4` still reddens, now via
the subset leg, naming all 14. The only thing removed is the false red on somebody else's
improvement.

---

## F6 — `rb_suite_path` resolved a `headless/*` entry with `[file tail]`

**Outcome: fixed, and the lens's claim VERIFIED before acting on it, as instructed.**

### Verifying the claim first

The driver launches `--script ${hc}.tcl` with its cwd in `tests/`
(`tests/run_regression.tcl`, the two `exec` sites in the `hcases` and `dcases` loops, and
`dlogdir` is built from `[pwd]`). So `[file join $repo tests $e.tcl]` **is** the driver's
own construction. Measured, old (`[file tail]`) vs new (bare fallback):

```
headless/test_calc_skeleton        …/tests/headless/test_calc_skeleton.tcl   same=1
hilight_hier_oracle                …/tests/hilight_hier_oracle.tcl           same=1
headless/sub/foo                   old=…/tests/headless/foo.tcl       new=…/tests/headless/sub/foo.tcl        same=0
headless/wireedit/run_x            old=…/tests/headless/run_x.tcl     new=…/tests/headless/wireedit/run_x.tcl same=0
entries=96 differ=0
missing under old=0   missing under new=0
```

Identical on all **96** real entries; the fix **removes** the special case, and the old
form is a silent wrong answer for a nested entry. The claim holds.

### The red — row `RB1b`, added before the fix

```
FAIL: RB1b the driver's two launch lines spell `--script ${hc}.tcl` / `${dc}.tcl` against its cwd in tests/, and rb_suite_path preserves an entry's directory components under tests/ -- a NESTED entry included -> {{dc hc} {headless/test_calc_skeleton.tcl hilight_hier_oracle.tcl headless/foo.tcl headless/run_x.tcl}} (exp {{dc hc} {headless/test_calc_skeleton.tcl hilight_hier_oracle.tcl headless/sub/foo.tcl headless/wireedit/run_x.tcl}}) : FAIL
RESULT: 1 FAILED (7 passed)
```

`RB1b` has two legs so it is not a tautology against its own implementation: the
`--script ${hc}.tcl` / `${dc}.tcl` spelling is **lifted out of the driver's text** rather
than remembered, and the resolution property is then asserted against it. New helper
`rb_rel_tests` returns a resolved path's spelling relative to `tests/`, which is the
entry the driver would have written.

### The green

```
PASS     | test_registered_banner_1626  run 1/1  RESULT: ALL PASS (8 checks)
```

`rb_suite_path` is now one line: `return [file join $repo tests $e.tcl]`.

---

## F7 — RB2's name understated what the predicate accepts

**Outcome: fixed (wording), and the behaviour measured rather than assumed. No red is
possible for a name; a fixture was added so the renamed claim is re-measured.**

### The behaviour, measured exactly as the driver captures it

`tests/run_regression.tcl` execs all three arms as `> $log 2>@1` (three sites). A fixture
printing the banner on **stderr**, captured that way:

```
--- captured exactly as the driver captures it (> log 2>@1) ---
OVERALL: ok (3 checks)
RESULT: ALL PASS (3 checks)
banner_complete=1 regression_case_failed(0)=0
```

So accepting `puts stderr` is correct, not sloppy.

### Before / after

```
-check "RB2 every registered suite has a stdout puts whose rendered argument banner_rule.tcl's own banner_complete accepts, source chain and one assignment level resolved" \
+check "RB2 every registered suite has a puts to stdout or stderr -- the two channels T1 captures -- whose rendered argument banner_rule.tcl's own banner_complete accepts, with the source chain, a command-substitution word and one level of set/append assignment resolved" \
```

L3 now carries the second half of the finding:

```
##   L3  a `puts` whose CHANNEL word is a variable is treated as a write to that
##       channel and ignored, so `puts $fd "OVERALL: ok"` is not an emitter --
##       correct, since it does not reach the log -- AND IT STAYS REJECTED EVEN
##       WHEN $fd HOLDS stdout OR stderr, which the predicate cannot know. A
##       literal `stdout` or `stderr` channel word IS followed (fixture a8);
##       only the variable spelling is dropped.
```

Fixture **`a8`** (`puts stderr "<banner>"`, must be accepted) holds the renamed claim, so
the name is not a sentence claiming more than the battery measures. That addition is mine
and was not asked for; the reasoning is CLAUDE.md's rule that a row's name must describe
its method.

---

## 1. What I changed, by symbol

| file | what |
|---|---|
| `tests/headless/test_registered_banner_1626.tcl` | **header**: method bullets restated (stdout **or stderr**, command substitution, `set`/`append`); `L2` and `L3` rewritten; **`L6` added**. **new**: `rb_group_body`, `rb_word_literals`, `rb_scan_text`, `rb_nogui_gate`, `rb_nogui_dead`, `rb_rel_tests`. **changed**: `rb_brace_body` (wrapper), `rb_puts_args` (`cmd` kind), `rb_var_literals` (`append` + concatenation), `rb_suite_path` (one line), `rb_emitters` (delegates to `rb_scan_text`). **rows**: `RB1b`, `RB6`, `RB7` added; `RB2` renamed; `RB4` re-keyed; `RB3` battery grew by `a6`, `a7`, `a8`; `FIXREC` records the fixtures for `RB4`. |
| `tests/headless/test_calc_skeleton.tcl` | the verdict block's comment only — the false "or reordering" clause replaced with the measured hazard and an issue-**1627** citation. No code. |
| `tests/headless/test_calc_widgets.tcl` | the same comment extended with the 1627 citation and the "a third exit path prints its verdict INSTEAD" instruction. No code. |
| `tests/run_regression.tcl` | the `dcases` comment block only: the "FOUR different mechanisms" count removed (a number nothing re-checks — `RB4` re-measures it), and `RB6`/`RB7` described. No list change; the file is byte-identical to Stage A's apart from that comment. |

---

## 2. The red, per finding

In §F1 – §F7 above, verbatim, each with the command that produced it. Summary:

| finding | red was possible? | red |
|---|---|---|
| F1 | **no** — a comment, nothing reads it | stated as such; before/after text quoted |
| F2 | yes, real tree | fence `ALL PASS (8 checks)` with a Tk-only suite in `hcases`, while `regression_case_failed 0` over that suite's real `--nogui` output = **1** |
| F3 | yes, real tree | fence `ALL PASS (9 checks)` with both `dcases` entries deleted |
| F4 | yes, real tree | `RB3 … a6=0 a7=0 (exp a6=1 a7=1)` |
| F5 | yes, synthetic tree | `RB4 … would false-red 0 … -> {0} (exp {1})` on a tree that is strictly better |
| F6 | yes, real tree | `RB1b … headless/foo.tcl headless/run_x.tcl` instead of the nested paths |
| F7 | **no** — a name; behaviour was already correct | `banner_complete=1` on a real stderr capture, quoted |

---

## 3. The green, each arm

Fence suite, armed (`tests/headless/run_suites.sh [--nogui] test_registered_banner_1626`):

```
display arm:   PASS | test_registered_banner_1626  RESULT: ALL PASS (10 checks)
headless arm:  PASS | test_registered_banner_1626  RESULT: ALL PASS (10 checks)
```

Before → after: `ALL PASS (7 checks)` → `ALL PASS (10 checks)`, both arms (`+RB1b`,
`+RB6`, `+RB7`).

Both calculator suites, armed, both arms — **check counts unchanged**, which is the point:

```
display arm:
PASS     | test_registered_banner_1626  run 1/3  RESULT: ALL PASS (10 checks)
PASS     | test_calc_skeleton           run 2/3  RESULT: ALL PASS (545 checks)
PASS     | test_calc_widgets            run 3/3  RESULT: ALL PASS (244 checks)
RESULT: 3/3 runs passed

headless arm:
PASS     | test_registered_banner_1626  run 1/3  RESULT: ALL PASS (10 checks)
PASS     | test_calc_skeleton           run 2/3  RESULT: ALL PASS (0 checks)
SKIP     | test_calc_widgets            run 3/3 (self-skipped: no X — nothing ran)
RESULT: 2/2 runs passed (1 skipped)
```

The ten rows, display-arm order (`RB5` prints last because it is the file's own
self-check and its block is last in the file):

```
RB0 RB1 RB1b RB2 RB3 RB3b RB4 RB6 RB7 RB5
```

---

## 4. What I sabotaged and what it reddened

The suite was byte-restored after every one and the restore verified by `md5sum`.

| # | the plausible wrong implementation | what reddened |
|---|---|---|
| SAB-1 | `rb_nogui_gate` stops requiring the gate body to **`exit`** (a per-band `if {!…has_x…}` guard counts as a whole-file gate) | `RB6` — **8 real `hcases` entries** flagged (`test_add_wire_label test_ase_core test_ase_optsheet_1441 test_generator_paren_1604 test_input_line_inject_1352 test_lib_new_path_guards_0799 test_op_annot test_preview_name_inject_1601`) **and** control `g4=1`. This is the sabotage worth reading: the `exit` requirement is what keeps the row from being a standing red on eight innocent suites, and `g4` is the fixture that says so without needing the tree. |
| SAB-2 | `rb_nogui_dead` stops asking whether a banner is reachable **inside** the gate (flag any gate) | `RB6` — control `g2=1`, and `test_headless_guards_xarm_1492` appears in the printed set. It stays out of the *assertion* only because it is a `dcases` entry; `g2` is what catches the defect regardless. |
| SAB-3 | `rb_var_literals` stops **concatenating** across `append` | `RB3` — `a7=0` |
| SAB-4 | `rb_var_literals` follows only `set`, not `append` | `RB3` — `a7=0` |
| SAB-5 | `rb_emitters` replaced with the naive one-file text scan — the headline wrong implementation | `RB2` (14 false reds, every `test_ase_*` plus `test_wave_sigbrowser_panes`), `RB3` (`a3=0 a7=0 r3=1 r4=1 r6=1`), `RB3b` (`{0 {}}`), **and the re-keyed `RB4`** via its subset leg, naming all 14. `RESULT: 4 FAILED (6 passed)`. |
| SAB-6 | `rb_puts_args` without the `cmd` arm (i.e. the pre-A2 code) | `RB3` — `a6=0`; this is F4's red |
| SAB-7 | `rb_suite_path` with `[file tail]` (the pre-A2 code) | `RB1b`; this is F6's red |
| SAB-8 | a Tk-only suite in `hcases` | `RB6`; this is F2's red |
| SAB-9 | both `dcases` entries deleted | `RB7`; this is F3's red |

Every new row has been observed red, and every change to the predicate has been observed
to be load-bearing.

---

## 5. The trailer delta, RE-DERIVED over my own output

**Stage A's figure is not quoted.** `tests/run_regression.tcl`'s `t1_carry_line` and
`summarize_all` were lifted out of its own text by name (`\nproc <name> ` to the next
column-0 `}`), `tests/banner_rule.tcl` sourced beside them, and run over logs captured
**exactly as T1 captures them** — the `hcases` arm as
`--nogui --pipe -q --script X.tcl > log 2>&1`, the `dcases` arm on `:99` with
`GUI_GATE=0` and a `--logdir` of its own (what `devdisplay.sh exec` pins).

`summarize_all`'s own arms, printed from the lifted body:

```
ARM:      if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]} {
ARM:      } elseif { [regexp {^(NOGOLD|NODISPLAY)} $line] } {
ARM:      } elseif { [regexp {^skip:} $line] } {
ARM:      } elseif { [regexp {^RESULT:} $line] } {
ARM:      } elseif { [banner_complete $line] && [regexp {\([^)]*\)} $line] } {
```

Per log:

```
fence.hc.log                 blocks+1 counted+0 skips+0
test_calc_skeleton.dc.log    blocks+1 counted+0 skips+0
test_calc_widgets.dc.log     blocks+1 counted+0 skips+0
TOTALS: blocks=3 counted_failures=0 skips=0
```

Raw counts over the same three real logs:

```
fence.hc.log                 ^skip:=0 ^SKIP=0 nocase=0 counted-shapes=0 ^RESULT:=1 banner_complete=1
test_calc_skeleton.dc.log    ^skip:=0 ^SKIP=0 nocase=0 counted-shapes=0 ^RESULT:=1 banner_complete=1
test_calc_widgets.dc.log     ^skip:=0 ^SKIP=0 nocase=0 counted-shapes=0 ^RESULT:=1 banner_complete=1
```

The blocks it wrote — what the verdict file will contain:

```
fence.hc.log
RESULT: ALL PASS (10 checks)
Total num fail: 0
test_calc_skeleton.dc.log
RESULT: ALL PASS (545 checks)
Total num fail: 0
test_calc_widgets.dc.log
RESULT: ALL PASS (244 checks)
Total num fail: 0
```

`wc -l` of that = **9**.

**Delta against the baseline `cases=113 blocks=112 counted_failures=0 skips=8` at
`f3d60af9`: cases +3, blocks +3, counted_failures +0, skips +0, `wc -l` +9.** My A2 rows
move **nothing** in the trailer — they change one block's check count from 7 to 10, which
is inside a published `RESULT:` line, not a counted or skip shape.

⚠ **`skips=` is derived, not predicted.** All three of my logs contain **zero** `^skip:`
lines **and** zero `^SKIP` lines and zero case-insensitive `^skip` lines, so there is no
uppercase/lowercase trick hiding here — the trap that caught both a verifier and the
driver on issue 1625. The baseline's 8 is untouched by anything in this stage. **Read the
trailer.**

One thing the driver should know about a *different* number: `test_op_annot` reported
**493** checks on the display arm through `run_suites.sh` and **486** headless, and its
display arm printed one `skip:` line — `W23 … (no action log -- run with --logdir)`. That
is a `run_suites.sh` artefact: T1's `dcases` loop passes `--logdir` (row `V57`'s eighth
leg), so that row runs under T1. Nothing to do with this stage; recorded so nobody
diagnoses it as one.

---

## 6. Neighbouring suites, both arms

Run because I touched `tests/run_regression.tcl` and the two calculator suites — the same
set Stage A ran. The repo is at a 29-character path and `test_op_annot` passes, as
CLAUDE.md's short-path rule requires.

```
display arm:
PASS | test_audit_classifier              RESULT: ALL PASS (75 checks)    # section K intact
PASS | test_scratch_home_note             RESULT: ALL PASS (22 checks)    # C1 lifts summarize_all
PASS | test_regression_concurrency_1476   RESULT: ALL PASS (46 checks)
PASS | test_issue_stamp                   RESULT: ALL PASS (102 checks)
PASS | test_snprintf_fmt_1608             RESULT: ALL PASS (48 checks)
PASS | test_op_annot                      RESULT: ALL PASS (493 checks)   # V57, the dcases loop line
PASS | test_home_isolation                RESULT: ALL PASS (116 checks)   # G2, new-file launcher scan
RESULT: 2/2 and 5/5 runs passed

headless arm:
PASS | test_audit_classifier              RESULT: ALL PASS (75 checks)
PASS | test_scratch_home_note             RESULT: ALL PASS (22 checks)
PASS | test_regression_concurrency_1476   RESULT: ALL PASS (46 checks)
PASS | test_issue_stamp                   RESULT: ALL PASS (102 checks)
PASS | test_snprintf_fmt_1608             RESULT: ALL PASS (48 checks)
PASS | test_op_annot                      RESULT: ALL PASS (486 checks)   # + its 5 known skip: lines
PASS | test_home_isolation                RESULT: ALL PASS (116 checks)
RESULT: 7/7 runs passed
```

---

## 7. `git status --short` at the end

```
 M doc/claude/calculator_batch/PLAN.md
 M doc/claude/issues/NUMBERING.md
 M doc/claude/specs/calculator.md
 M src/calculator.tcl
 M tests/headless/test_calc_skeleton.tcl
 M tests/headless/test_calc_widgets.tcl
 M tests/run_regression.tcl
?? .xschem/
?? doc/claude/calculator_batch/CREW_BRIEF.md
?? doc/claude/calculator_batch/LEDGER.md
?? doc/claude/calculator_batch/receipts/A-register-1626.md
?? doc/claude/calculator_batch/receipts/A2-fence-fixes-1626.md      <-- this file
?? doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md
?? doc/claude/issues/1626-….md
?? doc/claude/issues/1627-….md
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
?? tests/headless/test_registered_banner_1626.tcl
```

Mine are exactly five: `tests/headless/test_registered_banner_1626.tcl` (untracked, new in
Stage A), `tests/run_regression.tcl`, `tests/headless/test_calc_skeleton.tcl`,
`tests/headless/test_calc_widgets.tcl`, and this receipt. **Checked by mtime, not by
intention**: the four code files
carry 20:04–20:06; `PLAN.md` 19:12:05, `specs/calculator.md` 19:12:32,
`src/calculator.tcl` 19:19:52 and `NUMBERING.md` 19:34:04 are all older than my first
edit and are the driver's. Nothing new appeared in `git status` during the stage.

**No probe wrote anything.** This stage ran no `xschem save` / `saveas`; nothing under
`xschem_library/`, `tests/headless/gold/` or any tracked fixture was touched. All scratch
is under `…/scratchpad/A2-fence-fixes/` (captures, backups, the mini tree, the lifted
probes, a throwaway `fakehome`). The real dev display `:99` was left exactly as found —
attached to, never started or stopped. No T1 run.

---

## 8. What I did NOT do, and why

* **No T1 run** — the driver's job, and a concurrent run plus my hand-run suites can redden
  a gate. §5 is the unit-level substitute and it is a substitute for *scoring*, not for
  *running*.
* **Nothing committed, pushed or stashed.**
* **No per-arm reachability analysis.** Explicitly out of scope (F2), and `L6` now says so
  in the suite's own header rather than leaving it unsaid.
* **I did not fence issue 1627.** `RB6`'s sibling — a row asserting exactly one `^RESULT:`
  line per run — is a **run-time** property and the issue's own §"Still open" says the
  honest home is inside the driver where the output is in hand. I added the citation to
  both suites' comments instead. Measured here as information: each of my three real logs
  has `^RESULT:=1`.
* **I did not touch the Stage A receipt.** Corrections are in §F1 and §9.3.
* **I did not register `test_audit_classifier`.** Still in neither list (Stage A §10.3,
  issue 1627's open item 2). Out of scope and untaken.
* **Nothing was verified by eye.** Every claim here is a row, a sourced predicate, or
  quoted command output. No `look` debt incurred and none needed — this stage has no
  pixels.

---

## 9. What I got wrong, and what corrected me

**Four things.**

1. **I started to re-key `RB4` to the subset property alone, and that property is
   ENTAILED BY `RB2`.** If `RB2` is green then `real == 1` for every registered suite, so
   "naive-rejected ⊆ accepted" holds automatically and the row would have asserted nothing
   — the exact defect `RB4`'s own first definition had in Stage A (§7.3 of that receipt),
   arriving a second time by a different route. What corrected me was writing out the
   truth table before writing the row. The fix is the **second leg**, over this file's own
   fixtures, which is not entailed by anything and cannot be cured by somebody else's
   commit; SAB-5 then confirmed the re-keyed row still catches the naive-grep
   implementation.

2. **I nearly shipped `append` support that does not work.** Following `append` beside
   `set` and testing each literal separately accepts nothing: `"OVERALL:"` is not a banner
   and `" ok (…)"` is not a banner. The fixture caught it — `a7=0` with `append` followed
   and the concatenation missing (SAB-3 reproduces exactly that). The finding as written
   says "follow `append` beside `set`", and a crew implementing it literally would have
   added a row that passes only because `rb_render` is generous. **The in-order
   concatenation is the actual content of F4's second half.**

3. **My first `rb_nogui_gate` had no `exit` requirement**, because the shape I was reading
   off the two calculator suites was "an `if` about `has_x` near the top of the file".
   SAB-1 is that version, and it flags **eight** real `hcases` entries including
   `test_op_annot` — i.e. the version I would have shipped first was an eight-case
   standing red in T1, which is the one thing CLAUDE.md says a fence must never become.
   What corrected me was measuring the detector over all 96 registered entries **before**
   writing the row rather than after, which is the habit Stage A's own §7.2 recommends.

4. **My proc-lifting probe mis-counted braces** because it counted `\{` and `\}` inside
   regexp literals — `rb_render`'s `{\$\{[^\}]*\}}` is balanced to Tcl and unbalanced to a
   naive character count. The lift reported `missing close-brace` on exactly one proc and
   then failed with `invalid command name "rb_render"`. Skipping backslash-escaped
   characters fixed it. Worth recording because the tree's established lifting idiom
   (`\nproc <name> ` to the next column-0 `}`) does **not** have this problem and the
   brace-balance variant does.

Corrections to Stage A's receipt, recorded here as the brief requires:

* **§9.3** — Stage A's §6 said "FOUR different mechanisms"; the predicate now resolves
  **six** spellings and the suite quotes no count at all, because `RB4` re-measures the
  gap every run. The same count was in `tests/run_regression.tcl`'s comment block and is
  removed there too.
* Stage A's comment in `test_calc_skeleton.tcl` contradicted Stage A's own §6(c). Fixed in
  §F1; the receipt is left as the dated record it is.

---

## 10. What the next stage must know

1. **`RB6` and `L6` mean that registration shape is now partly fenced and partly not.** A
   suite whose headless arm cannot reach a banner by the **whole-file no-X exit** shape
   cannot be added to `hcases` without reddening. A suite made unreachable any other way
   still can, and T1's `HARNESS:` line is the backstop. **Before registering any suite,
   still check its epilogue against `banner_complete` — on the arm you are registering.**
2. **`RB7` names three entries.** If Phase 2 renames or moves either calculator suite, or
   this fence, `RB7` reddens and must be edited in the same change. That is deliberate:
   it is the only row that can notice a deregistration.
3. **`test_headless_guards_xarm_1492` is the in-tree precedent for a scorable no-X gate**
   — it prints `RESULT: SKIP (no display)` *and* `OVERALL: ok` before exiting. If anyone
   ever wants a calculator suite in `hcases`, that is the shape to copy; both suites
   deliberately do **not** (Stage A §3, and it stays the right call while their headless
   arms run zero checks).
4. **Issue 1627 is still open and unfenced**, and both calculator suites now carry the
   citation at their verdict blocks. The honest fix is a check inside the driver. If a
   Phase-2 row adds a third exit path to either suite, that path must print its verdict
   **instead of** one of the existing two.
5. **`skips=` was re-derived, not predicted** (§5): zero `skip:` lines of any case in all
   three of my logs. Read the trailer.
6. **`test_op_annot`'s display-arm count through `run_suites.sh` is 493 with one `skip:`
   line** (`W23`, no action log). T1 passes `--logdir`, so that is a hand-run artefact.
   Not a regression and not this stage's.
