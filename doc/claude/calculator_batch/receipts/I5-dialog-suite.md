# I5 — SUITE AUTHOR: the failing rows for PLAN phase 5's argument dialog

**Stage:** PLAN 5.4 (R412 / R421), fences only. **No product code was written.** Nothing is
committed; everything is left uncommitted in the tree.

Branch `fluid-editing`, worked at `580f7968`. Binary as found (`src/xschem`, 2026-10-01 10:40) —
no `make` was run, per the harness rule.

---

## 1. What changed, by symbol / band

### `tests/headless/test_calc_measure.tcl` — band **MT11** (`hcases`, BOTH arms), 23 rows
The one piece of phase 5 that needs no Tk. New helpers `ag_spec`, `ag_ok`, `ag_rows`, `ag_canon`,
`ag_keys`, `ag_cell`, `ag_field`, `ag_verbs`, `ag_surface`, `ag_formals`, `ag_default`,
`ag_enum_in`, plus the literal table `AG_WANT`.

Header edits in the same file: the `calc::dutyCycle` signature line gained `?<xaxis>?` (see §4);
the band list gained MT11; the "which rows pass with no feature present" list gained MT11's four
control rows; holes **H9**, **H10**, **H11** added.

### `tests/headless/test_calc_skeleton.tcl` — band **S28** (`dcases` alone), 25 rows
Sub-bands `S28/0` (the 30-verb fall-through), `S28/1` (no built verb is told it is not),
`S28/2` (a real gesture opens a real modal), `S28/3` (R412 Cancel), `S28/4` (R421's three parts
plus shape validation), `S28/5` (Escape), `S28/6` (the result gate runs first), `S28/A` and
`S28/B` (the two poll sabotages), `S28/C` (the poll gives up and the deadman still ends it),
`S28/D` (the grab is local), `S28/E` (R508), `S28/Z` (hygiene).
New helpers: `s28band` (a per-sub-band catch — see §5), `ad_buf`, `ad_spec`, `ad_keys`,
`ad_verbs`, `ad_tnoproc`, `ad_arm`, `ad_poll_modal`, `ad_disarm`, `ad_spin`, `ad_slow_install`,
`ad_slow_none`, `ad_slow_remove`. Holes **SH1**–**SH6** declared in the band header.

### `tests/headless/test_calc_widgets.tcl` — band **CW14** (`dcases` alone), 13 rows
The dialog's widget inventory, built **without** the modal wrapper, so it needs no poll and
cannot hang. New helpers `cw_spec`, `cw_keys`, `cw_row`, `cw_cell`, `cw_tverbs`, `cw_opt`,
`cw_argval`, `cw_argmap`, `cw_firstorder`, `cw_choices`, `cw_build`. Holes **WH1**–**WH5**.

`git status --short` at the end shows only these three files among mine. Four other test files
and `receipts/I4-fence.md` in that listing belong to the **concurrent** watchdog/fence crew and
were never touched here.

---

## 2. The contract these rows specify

`calc::fn_argspec <name>` → rows of `{key label kind required default}` in DISPLAY order, `{}`
for a name with no arguments. `kind` ∈ `real` | `int` | `rpn` | `{enum <member> …}`.
`key` is the formal name on the proc the result path calls, so the call composes **by key**.

`calc::arg_dialog <name>` → a dict `key → value`, or `{}` for Cancel.
`calc::arg_dialog_build <name>` → builds and returns `.calc.arg`.
`calc::arg_dialog_done <w> <how>`, `how` ∈ `{ok cancel}`.
`.calc.arg.btns.ok` / `.calc.arg.btns.cancel`; one `::calc::argval(<key>)` per field.
`calc::fn_click` route T → `calc::fn_measure`, keeping the fall-through for the other 30.

Order: **result gate → empty-buffer check → dialog → measure → R421.**

---

## 3. The red, verbatim

Reported through the armed spelling. **Zero aborted bands, zero `RAISED:` lines, zero
`UNEXPECTED ERROR`** in all three.

```
tests/headless/run_suites.sh --nogui test_calc_measure   rc=1
FAIL     | test_calc_measure            run 1/1  RESULT: 19 FAILED (139 passed)
tests/headless/run_suites.sh test_calc_measure           rc=1
FAIL     | test_calc_measure            run 1/1  RESULT: 19 FAILED (139 passed)

tests/headless/run_suites.sh test_calc_skeleton test_calc_widgets   rc=1
FAIL     | test_calc_skeleton           run 1/2  RESULT: 15 FAILED (558 passed)
FAIL     | test_calc_widgets            run 2/2  RESULT: 9 FAILED (250 passed)
RESULT: 0/2 runs passed
```

The per-row red is in the scratch transcript `RED_VERBATIM.txt`; the shapes each failure printed:
`NOPROC:calc::fn_argspec`, `NOSUCHKEY:dutyCycle/xaxis`, `only:0`, `NOBUILDPROC`,
`NO-DIALOG-TO-CANCEL`, `NO-MODAL`, `STILL-SAYS-NOT-IMPLEMENTED`,
`SAID(function cross: not implemented (phase 5))`, `MISSING`,
`ERR:bad window path name ".calc.arg"`, `POISON-AN-ANSWER-THE-USER-NEVER-GAVE`. Every one names
the thing that is absent; none is a bare mismatch and none is a Tcl error.

---

## 4. The `dutyCycle` formals measurement that was owed

Read off the shipped procs, not inferred:

```
proc calc::dutyCycle        {rpn level {cycle 0} {dataset 0} {xaxis start}}
proc calc::dutyCycle_scalar {rpn level {cycle 0} {dataset 0}}
```

So **`xaxis` is FIFTH and LAST, after `dataset`** — not third, which is where
`CLICK_CONTRACT.md` §8's field order (`Level · X axis · Cycle · Dataset`) would put it, and not
absent, which is what `test_calc_measure.tcl`'s own header said. Three live documents, three
answers; the proc wins. The header line is corrected in this change.

Two consequences, both now rows:

* The dialog's DISPLAY order and the proc's FORMAL order genuinely differ, so a result path that
  zipped the spec onto `info args` would hand `dutyCycle` its X axis where its cycle ordinal
  belongs. MT11 measures the divergence rather than asserting it.
* **`calc::dutyCycle_scalar` takes no `xaxis` and forwards four arguments.** Its own shipped
  comment declares that deliberate and names phase 5's dialog as the caller it is waiting for. So
  MT11's surface-formals row is red for that reason as well, and the implementer must either give
  the wrapper the formal or have the result path call `calc::dutyCycle`. This file does not
  choose: the row is satisfied by both. Hole H9 records that the axis's *effect* is unobservable
  for a scalar answer, so nothing fences it reaching the data.

---

## 5. What I got wrong, and what corrected me

1. **A bare `}` inside a braced word closes it — twice, the second time in the comment warning
   about the first.** `set pat {lsearch -exact \{([^}]*)\} \$%s}` terminated at the bracket
   expression, and the file died with `missing close-bracket` reported against the file-scope
   `catch` a thousand lines above. The fix is `[^\}]`; the comment explaining it then quoted both
   spellings and unbalanced the proc a second time. CLAUDE.md records the same accident; I
   reproduced it. The comment now describes the characters instead of showing them.
2. **`dict create` at band level reddens MT10.** `mt_dictsites` walks the file for every line that
   builds a dict and names the enclosing proc; a band-level `dict create` holding a
   *specification table* is a new site. `{BAND-LEVEL mt_asanswer mt_stub_run}`. Changed to `list`.
3. **A bareword in `expr` aborted twelve sub-bands.** `expr {$x ? GOT-A-MODAL : NO-MODAL}` raised
   at file scope, where this suite has no `group`, so the whole-file catch printed one
   `UNEXPECTED ERROR:` and every row behind it — including all the hygiene rows — never ran. That
   is why `s28band` now exists: a counted FAIL naming the band, and the bands after it still run.
4. **A `{args}` stub measures the fixture, not the product.** My recorder for `cross_scalar` was
   declared `{args}`, so `info args` answered the single word `args`, no formal matched a key, and
   a *conforming* reference correctly called the stub with nothing. The row reddened against
   correct code. The stub now carries the real proc's own formal names, derived with `info args`,
   each defaulted to a sentinel so the recorder reports the arguments actually passed.
5. **`cget` accepts an unambiguous abbreviation.** `cget -value` on a `ttk::combobox` answers the
   whole of `-values`, and `cget -text` on an entry answers its `-textvariable`. CW14's enum leg
   read `choices(rising falling either {rising falling either})` against a conforming reference —
   a false red. `cw_opt` now compares the option's real name out of `configure`.
6. **`"$name(…)"` is an array reference.** My own reference composed R421's provenance sentence
   that way and Tcl raised `can't read "name(…)": variable isn't array`. The number still reached
   the buffer and the status line kept the previous sentence — so the row blamed the sentence. A
   leg asserting that **the click RETURNS rather than raises** was added because of this.

---

## 6. Sabotage: what each plausible wrong implementation reddened

Against a throwaway conforming reference in scratch, since deleted.

| # | mutation | reddened |
|---|---|---|
| P1 | the click calls the raw `calc::cross`, not `cross_scalar` | 5 rows, the diagnostic one reporting `AD_RAWCALLS` 1 |
| P2 | `-autoseparators` left ON across the replace | **exactly one**: R421 part 3, the undo witness, `{1 {} 1}` |
| P3 | the dialog opens BEFORE the result gate | **exactly two**: both `S28/6` rows |
| P4 | `grab set -global` | **exactly two**: `S28/2`'s `grab status` leg reads `global`, `S28/D` names `::calc::arg_dialog` |
| P5 | the result slot pre-set in the wrapper only, not at the top of the build | **exactly one**: CW14's poison row, `POISON-AN-ANSWER-THE-USER-NEVER-GAVE` |
| P6 | `dutyCycle_scalar` without `xaxis` (the shipped shape) | **exactly one**: MT11's surface row, `dutyCycle_scalar/xaxis=not-a-formal` |
| P7 | side B of `delay` carrying side A's labels (the copy-paste) | **exactly two**: `delay`'s literal row and the label-uniqueness row, naming all four |
| P8 | no shape validation at all | **exactly one**: the new S28/4 row, printing `not-a-number` composed into the call |

And the two required **poll** sabotages, driven on a scratch copy of the suite:

| shape | reddened |
|---|---|
| poll condition weakened to `winfo exists` alone | **S28/B** (the grab read `.calc`, the foreign one) and `S28/2`'s grab legs — i.e. the shape that *ships the bug* is caught |
| driver replaced by a fixed one-shot `after 100` | **S28/A** (window not there, full deadman burned), **S28/B**, and **S28/C** (it fired with no dialog ever built) |

---

## 7. The green, and the reference's deletion

With the reference present, on the arms that matter:

```
test_calc_measure   (--nogui)  OVERALL: ok (158 checks)   RESULT: ALL PASS (158 checks)
test_calc_skeleton  (:99)      OVERALL: ok (573 checks)   RESULT: ALL PASS (573 checks)
test_calc_widgets   (:99)      OVERALL: ok (259 checks)   RESULT: ALL PASS (259 checks)
```

**The reference and every sabotage overlay were then deleted** (`ref.tcl`, `ref2.tcl`, the
wrappers, the scratch suite copies and `sab/`), a tree-wide grep for its banner returns nothing,
and the red reproduced exactly: 19 / 15 / 9 counted failures with zero aborted bands.

---

## 8. Registration delta, DERIVED and not predicted

All three suites are **already registered**, so `cases=` and `blocks=` cannot move. The rest was
derived by lifting `summarize_all`'s five regexp arms out of `tests/run_regression.tcl`'s own text
and running them, with `banner_complete` sourced from `tests/banner_rule.tcl`, over the **real
captured output** of each arm:

| output | counted | lowercase `skip:` | uppercase `SKIP:` | `RESULT:` lines | `banner_complete` |
|---|---|---|---|---|---|
| measure, green | 0 | 0 | 0 | 1 | 1 |
| skeleton, green | 0 | 0 | 0 | 1 | 1 |
| widgets, green | 0 | 0 | 0 | 1 | 1 |
| skeleton `--nogui` | 0 | 0 | 0 | 1 | 0 (by design: `ALL PASS (0 checks)`, no banner) |
| widgets `--nogui` | 0 | 0 | 0 | 1 | 0 (by design: `RESULT: SKIP (no X: …)`) |
| measure, red | 19 | 0 | 0 | 1 | 0 |
| skeleton, red | 15 | 0 | 0 | 1 | 0 |
| widgets, red | 9 | 0 | 0 | 1 | 0 |

So once the implementation lands: `cases` +0, `blocks` +0, `counted_failures` +0, **`skips=` +0**,
`wc -l` +0. Published check counts move: **135 → 158**, **548 → 573**, **246 → 259**.
Both `--nogui` arms are byte-unchanged.

⚠ **Until the implementation lands these rows are a standing red in T1**: three registered cases
at `counted_failures` 19 + 15 + 9 and `banner_complete` 0, i.e. three `HARNESS: … (exit=1,
OVERALL_ok=0, died=0)` lines as well. Sequencing is the driver's call.

---

## 9. Where the contracts were contradicted

1. `CLICK_CONTRACT.md` §8's `dutyCycle` field order puts `X axis` second; the shipped formal is
   fifth. Both are fine — they are different orders for different purposes — but the result path
   must compose **by key**, and that is now a row rather than an assumption.
2. §8's field table gives `dutyCycle` an `X axis` field while the surface wrapper it would be
   passed through cannot take one. §6's "fix 1639 first" note is discharged; this one is not.
3. §9(a) says the three suites that drive the modal "never arm the watchdog". **No longer true** —
   all three `source tests/headless/scratch.tcl` today, which the concurrent I3 stage landed.
4. §8 puts the "pre-set to cancel" line in the wrapper, following `rdw::scope_dialog`. CW14
   requires it at the top of the **build** as well, which is one notch stronger and is what makes
   it measurable without entering `tkwait`. Declared in the row's own comment.
5. CLAUDE.md says row S24's closed `returns` vocabulary is `{scalar wave bool scalar/wave}`; the
   tree has five terms (`scalar/list` was added for R419). Not acted on — CLAUDE.md is the
   driver's.

---

## 10. What I did NOT do

* No product code. `src/calculator.tcl` was read, never written.
* No commit, no push, no full T1.
* `tests/headless/test_suite_watchdog_1403.tcl` and the other files the concurrent crew owns were
  not touched.
* No `look` or `rule` debt was filed — SH3/SH4 and WH3/WH4 name four pixel debts and one wording
  debt that are the driver's to file, since `owed.sh` is off limits here.
* `riseTime`, `delay` and `dutyCycle` are not driven through the OK path (hole SH2); only `cross`
  is.
* The shape-validation row drives one field of one kind (hole SH6).

## 11. Scratch

Everything lived under the session scratchpad at `I5-dialog-suite/`. The reference, the overlays,
the suite copies and the probes are deleted; what remains is the run transcripts, `derive.tcl`
(the lifted `summarize_all` arms), `RED_VERBATIM.txt` and two throwaway HOMEs. No
`/tmp/xschem_emergencysave_*` was touched.
