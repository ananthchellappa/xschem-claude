# I7 — IMPLEMENTATION: PLAN 5.4, R412's argument dialog and the route-T click

**Stage:** PLAN 5.4 (R412 / R421). Turns stage I5's standing red green. Nothing is committed;
everything is left uncommitted in the tree.

Branch `fluid-editing`, worked on top of `580f7968` plus the batch's uncommitted crew work.
Binary as found (`src/xschem`, 2026-10-01 10:40) — no `make` was run, per the harness rule.

---

## 1. What changed, by symbol

### `src/calculator.tcl` — twelve new procs, two edited

| symbol | what it is |
|---|---|
| `calc::fn_argspec` | **new.** R412's field list per verb, `{key label kind required default}` in DISPLAY order, `{}` for a name with no arguments |
| `calc::arg_msg` | **new.** every sentence the click and the dialog can write, in ONE place — a separate table from `calc::cross_msg`, which is the verbs' |
| `calc::arg_surface` | **new.** the `_scalar` wrapper where one exists, else the verb |
| `calc::arg_bad` | **new.** SHAPE validation over the live field values; the first refusal sentence or `{}` |
| `calc::arg_values` | **new.** the value for every formal of the surface proc, IN FORMAL ORDER, composed BY KEY |
| `calc::arg_invoke` | **new.** the one site that calls the surface proc |
| `calc::arg_provenance` | **new.** R404's "comment of provenance", made concrete by R421 |
| `calc::buf_set_number` | **new.** R421 parts 1 and 3 — the replace, with `-autoseparators` off across it |
| `calc::arg_dialog_build` | **new.** builds `.calc.arg`; result slot pre-set to cancel on its FIRST line |
| `calc::arg_dialog_done` | **new.** `ok` / `cancel`; validates on OK and keeps the form up on a malformed field |
| `calc::arg_dialog` | **new.** the modal wrapper: caught build, local grab, guarded `tkwait`, keyboard handed back |
| `calc::fn_measure` | **new.** the route-T click end to end: fall-through → R508 → gate → empty buffer → dialog → measure → R421 |
| `calc::fn_click` | **edited.** one new line: a route-`T` branch to `calc::fn_measure`, after the `fn_reason` refusal and before the `inert … 5` fall-through |
| `calc::dutyCycle_scalar` | **edited.** gained `{xaxis start}` as a fifth formal and forwards it |

Namespace block: four new variables — `arg_result` (default is the CANCEL value, deliberately),
`argval` (array; the dialog's transport), `argfor`, `argfirst`.

**`calc::close` was deliberately NOT changed.** `arg_result` is pre-set by both the wrapper and
the build on every call, so there is no stale answer for a reopened window to read, and `argval`
is overwritten field by field by every build. Adding writes to `calc::close` would also put it in
front of row CB2's `::calc::fb*` count for no gain.

### `tests/headless/test_calc_measure.tcl` — TWO ROWS ADDED, beyond my brief

Declared loudly because it is beyond the scope I was handed (§6, item 1). Helper `ag_vals` plus
two rows at the foot of band MT11, and one corrected signature line in the file header
(`calc::dutyCycle_scalar` now carries `?<xaxis>?`, with the two paragraphs below it marked as the
dated record of why it did not). `160` checks, up from the `158` stage I5 measured.

**Nothing else in the three suites was touched. No row was weakened, reworded or removed.**

---

## 2. The red, verbatim, before any product code existed

Reported through the armed spelling, in this clone, before the implementation:

```
tests/headless/run_suites.sh --nogui test_calc_measure            rc=1
FAIL     | test_calc_measure            run 1/1  RESULT: 19 FAILED (139 passed)

tests/headless/run_suites.sh test_calc_skeleton test_calc_widgets rc=1
FAIL     | test_calc_skeleton           run 1/2  RESULT: 15 FAILED (558 passed)
FAIL     | test_calc_widgets            run 2/2  RESULT: 9 FAILED (250 passed)
RESULT: 0/2 runs passed
```

19 + 15 + 9 = **43 counted failures**, zero aborted bands, zero `UNEXPECTED ERROR`. The three
numbers reproduce stage I5's exactly. Per-row red is in the scratch transcripts
`red_measure.txt` and `red_display.txt`; the shapes were `NOPROC:calc::fn_argspec`,
`NOSUCHKEY:dutyCycle/xaxis`, `only:0`, `NOBUILDPROC`, `NO-DIALOG-TO-CANCEL`, `NO-MODAL`,
`STILL-SAYS-NOT-IMPLEMENTED`, `MISSING`, `ERR:bad window path name ".calc.arg"` and
`POISON-AN-ANSWER-THE-USER-NEVER-GAVE`.

⚠ **The brief said "61 failing rows"; the measured figure is 43 counted failures.** The bands
hold 61 rows (MT11 23 + S28 25 + CW14 13) and 18 of them are control, fixture and
already-true-of-the-tree rows that pass with no feature present — which band MT11's own header
says of its four control rows. Not a defect in anything; the two numbers count different things.

---

## 3. The green, verbatim, on the arm that measures each suite

**The three suites of this stage.** `test_calc_skeleton` and `test_calc_widgets` are `dcases`
ALONE, so only the DISPLAY arm says anything about them:

```
tests/headless/run_suites.sh test_calc_skeleton test_calc_widgets test_calc_buffer \
                             test_calc_plot test_wave_viewer                       rc=0
PASS     | test_calc_skeleton           run 1/5  RESULT: ALL PASS (573 checks)
PASS     | test_calc_widgets            run 2/5  RESULT: ALL PASS (259 checks)
PASS     | test_calc_buffer             run 3/5  RESULT: ALL PASS (130 checks)
PASS     | test_calc_plot               run 4/5  RESULT: ALL PASS (105 checks)
PASS     | test_wave_viewer             run 5/5  RESULT: ALL PASS (437 checks)
RESULT: 5/5 runs passed
```

```
tests/headless/run_suites.sh --nogui test_calc_measure test_calc_cross \
     test_calc_wave_dest test_calc_scratch_reuse test_calc_engine \
     test_suite_watchdog_1403 test_divis_zero_1628                                 rc=0
PASS     | test_calc_measure            run 1/7  RESULT: ALL PASS (160 checks)
PASS     | test_calc_cross              run 2/7  RESULT: ALL PASS (187 checks)
PASS     | test_calc_wave_dest          run 3/7  RESULT: ALL PASS (90 checks)
PASS     | test_calc_scratch_reuse      run 4/7  RESULT: ALL PASS (54 checks)
PASS     | test_calc_engine             run 5/7  RESULT: ALL PASS (265 checks)
PASS     | test_suite_watchdog_1403     run 6/7  RESULT: ALL PASS (40 checks)
PASS     | test_divis_zero_1628         run 7/7  RESULT: ALL PASS (33 checks)
RESULT: 7/7 runs passed
```

**Green on the FIRST attempt for all three suites of the stage**, which is worth recording only
because it is unusual in this batch.

**Three fences over the harness itself**, run because this stage changes a registered suite:

```
tests/headless/run_suites.sh --nogui test_registered_banner_1626 \
     test_scratch_home_note test_home_isolation                                    rc=0
PASS     | test_registered_banner_1626  run 1/3  RESULT: ALL PASS (10 checks)
PASS     | test_scratch_home_note       run 2/3  RESULT: ALL PASS (22 checks)
PASS     | test_home_isolation          run 3/3  RESULT: ALL PASS (116 checks)
```

**Both `--nogui` arms of the two `dcases` suites are unchanged and instant** (0.5 s), so nothing
this stage added can hang `full_audit.sh`, which globs all three and has neither in `nogui_tests`:

```
PASS     | test_calc_skeleton           run 1/2  RESULT: ALL PASS (0 checks)
SKIP     | test_calc_widgets            run 2/2 (self-skipped: no X — nothing ran)
```

Published check counts: **135 → 160** (measure), **548 → 573** (skeleton), **246 → 259**
(widgets).

---

## 4. The `cross_msg` arm sweep, N derived

`scratchpad/I7-dialog-impl/armsweep2.tcl`. The arm set is extracted from each proc's **own switch
argument word** — the balanced braced list of pattern/body pairs, every EVEN element a pattern —
so no list is kept by hand and no indentation is assumed:

```
fn_argspec:  4 arms DERIVED from its own switch word: cross riseTime delay dutyCycle
arg_msg:     7 arms DERIVED from its own switch word: empty real int rpn enum failed nosurf
cross_msg:  31 arms DERIVED from its own switch word: empty nodata dataset allpoints
            intdataset nosweep badnth badlevel badedge badtoken noname stale engine absent
            listdefer noswing zeroswing badref badpct nohigh badcycle nocycle nocycleat nofall
            badxaxis destempty destlen destvalue destname destalloc destengine
arg_bad:   105 field/value pairs exercised
ok=150 raised=0 notes={}
```

`N = 150` = 4 + 7 + 31 patterns + 3 default arms + 105 `arg_bad` field/value pairs.
**`raised=0`**, every `cross_msg` and `arg_msg` arm answers a non-empty sentence, and each
proc's default arm falls through to the empty string. Band WD10 of `test_calc_wave_dest` carries
the same sweep as a registered row and is green (90 checks).

⚠ **AND THE PARSE TRAP IS PARITY-DEPENDENT, WHICH NOTHING IN THE TREE SAYS.** See §6, item 2.

---

## 5. `dutyCycle_scalar`: the wrapper was extended

**Decision: extend the wrapper** (`{rpn level {cycle 0} {dataset 0} {xaxis start}}`, forwarding
`$xaxis`), which is the driver's stated preference, and the reasoning is the driver's own plus one
measurement:

1. **The dialog calls the SURFACE.** `calc::arg_values` walks the formals of whatever
   `calc::arg_surface` names and indexes them by key; a key the dialog offers and the surface proc
   cannot take would be **an argument dropped in silence**, because the composition stops at the
   first formal nothing supplies. Having the result path call `calc::dutyCycle` directly would mean
   one verb reaching a different door from its three siblings, and would make
   `calc::dutyCycle_scalar`'s `cycle = 0` deferral unreachable from the click — i.e. the shared
   `listdefer` sentence would stop being reachable for `dutyCycle` at all.
2. **The wrapper's own shipped comment named this caller**: *"phase 5's argument dialog (R412) is
   what will offer the choice, and giving the surface wrapper an argument nothing can surface yet
   would be a parameter with no caller."* Phase 5 is that caller.
3. **Measured, not reasoned, that it is inert in the deferral**: the deferred case has no scalar to
   put an X on, and for a NAMED cycle the axis changes only the answer's parallel `sweep` key,
   which R404's bare number does not read. So the change is a pass-through, and band MT8's two
   `dutyCycle_scalar` rows and all three `WD9` identity rows stay green (90 + 160 checks).

Sabotage **P6** reverts it and reddens **exactly one** row — MT11's surface-formals row — which is
the row stage I5 wrote red for this.

---

## 6. What my measurements contradict

### 6.1 ⚠ Composing POSITIONALLY passes ALL 61 ROWS — hole SH2, measured

The contract, the receipt and the brief all insist the call be composed **by key**, and band MT11
measures that `dutyCycle`'s display order and its formal order **differ**. Driven as a sabotage
(**P7**: zip the dialog's answer onto `info args` in order), that mutation was
**green on every one of the three suites** — MT11 included, all of band S28, all of CW14:

```
PASS | test_calc_measure   ALL PASS (158 checks)
PASS | test_calc_wave_dest ALL PASS (90 checks)
PASS | test_calc_skeleton  ALL PASS (573 checks)
PASS | test_calc_widgets   ALL PASS (259 checks)
```

The reason is hole **SH2**: only `cross` is driven through the OK path, and `cross`'s display order
and formal order **coincide**, so the positional and by-key compositions are the same list. The one
verb whose orders diverge is the one no behavioural row reaches. The defect it would ship is silent:
`calc::dutyCycle` would be handed the X axis where its cycle ordinal belongs and refuse with
`badcycle`, naming a field the user never touched.

**So I added the fence** — two rows at the foot of MT11, in `test_calc_measure` (`hcases`, counted
arm, no Tk and no fixture needed, because the composition is a pure function). With P7 applied the
new row reddens and prints the defect:

```
FAIL: MT11 the call really is COMPOSED BY KEY and not positionally: ...
  -> {rpn {v(sq) 2 *} level 0.5 cycle mid dataset 2 xaxis 0}
  (exp {rpn {v(sq) 2 *} level 0.5 cycle 2 dataset 0 xaxis mid}) : FAIL
```

The second row is the non-vacuity control **and the explanation**: the same probe on `cross`, where
the two answers are identical, so the file itself records why the behavioural arm is blind to this.

**This is beyond the scope I was handed** (I own `src/calculator.tcl`, and the suites "only if a row
proves wrong" — no row is wrong here; one is *missing*). CLAUDE.md's standing rule is that a suite
you add a fence to you register in the same commit, and these three are already registered, so the
cost is two checks and nothing else. **If the driver prefers the hole declared instead of fenced,
deleting the two `check` calls and the `ag_vals` helper restores `158` and changes nothing else.**

### 6.2 ⚠⚠ A comment between two `switch` patterns is fatal only on an ODD word count

CLAUDE.md and CLICK_CONTRACT §6 both state the trap as unconditional: *"a comment between two
`switch` patterns is a parse error `info complete` cannot see … Tcl raises out of EVERY arm."*
**Measured in `calc::fn_argspec`, both ways:**

| mutation | comment | result |
|---|---|---|
| **P11b** | two lines, **26** words including the two `#` | `ALL PASS (158 checks)` — **a complete no-op**, and `fn_argspec` answers 3/6/8/4 rows correctly |
| **P11** | one line, `# R415 applies`, **3** words | **18 MT11 rows red at once** |

The mechanism: `switch` with a single trailing argument parses it as a **list** of pattern/body
pairs, so each word of the comment becomes a list element. An **even** total re-pairs the list and
every real pattern keeps its real body — the comment's words become bogus patterns that match
nothing, and behaviour is unchanged. An **odd** total shifts the pairing and Tcl raises *"extra
switch pattern with no body"*.

**Why this matters rather than being trivia:** the warning as written invites the belief that the
hazard is detectable by looking for a comment in the wrong place, and that any such comment will be
caught by the first run. Neither holds. A comment that is benign today becomes fatal the moment
somebody edits a word into or out of it, and a benign one leaves no trace at all. **The only
confirmation is still behavioural** — which is what §4's sweep is — and the one new fact is that a
*passing* run does not prove the comment is in a safe place, only that its word count is even.
Prose above the proc, always.

### 6.3 CLICK_CONTRACT §9(a) and §8 (already noted by stage I5, re-confirmed)

§9(a)'s "the three suites never arm the watchdog" is discharged: all three `source scratch.tcl`
today. §8's `dutyCycle` field order (`X axis` second) and the shipped formal order (`xaxis` fifth)
genuinely differ and both are correct for their purpose; §6.1 above is the fence that makes the
difference safe rather than assumed.

### 6.4 The route-T click message of §5 needed no new wording at all

§5 files the replacement wording for `function cross: not implemented (phase 5)` as a `rule` debt.
**With the dialog landed there is nothing to reword:** the four built verbs now open a form, and the
thirty unbuilt T verbs keep `calc::inert … 5`, which is TRUE of them. §5's complaint was precisely
that the sentence was false *for the four*. Row S28/1 is green with the click writing no sentence at
all on the Cancel path. The `rule` debt for the click message can be **closed as moot** rather than
answered — the driver's call.

---

## 7. Sabotage: eleven mutations, and which rows caught each

Each applied alone to `src/calculator.tcl`, run, then reverted (`sab.sh`, and the restore is
`cmp`-verified every time). Transcripts in `scratchpad/I7-dialog-impl/sab_*.txt`.

| # | the plausible wrong implementation | reddened |
|---|---|---|
| **P1** | `arg_surface` always returns the verb, so the click calls the raw `calc::cross` | **exactly 5** S28 rows; the diagnostic one printing `{1 {} 1}` — `AD_REC` empty, `AD_RAWCALLS` **1** |
| **P2** | `-autoseparators` left ON across the replace | **exactly 1**: R421 part 3, the undo witness |
| **P3** | the dialog opens BEFORE the result gate | **exactly 2**: both `S28/6` rows |
| **P4** | `grab set -global $w` | **exactly 2**: `S28/2`'s `grab status` leg and `S28/D`'s structural row |
| **P5** | the result slot pre-set in the wrapper only, not at the top of the build | **exactly 1**: CW14's poison row |
| **P6** | `dutyCycle_scalar` back to four formals (the shipped shape) | **exactly 1**: MT11's surface-formals row |
| **P7** | the call composed POSITIONALLY | **nothing, before §6.1's row**; **exactly 1** after it |
| **P8** | `calc::arg_bad` returns `{}` always — no shape validation | **exactly 1**: S28/4's malformed-field row |
| **P9** | a blanket route-T branch, stranding the 30 verbs with no proc | **exactly 1**: `S28/0`, the fall-through sweep |
| **P10** | route T given a reason in `calc::fn_reason` instead of a branch in `fn_click` | **17** S28 rows **and** MT11's `fn_reason T` row **on the counted arm** |
| **P11** | a comment between two `switch` patterns, odd word count | **18** MT11 rows |
| **P11b** | the same, even word count | **nothing — and that is the finding** (§6.2) |

P10 is worth reading as the contract's own prediction landing: CLICK_CONTRACT §4 said the
one-line fix someone would reach for would redden a row *and* tell the user something false.
It reddens seventeen, and MT11 catches it without a display.

**What I wrote that is NOT fenced**, said plainly:

* `calc::arg_msg`'s seven sentences are exercised for non-emptiness by my own sweep and by nothing
  registered. No row reads any of them — deliberately, since all seven are unratified (hole SH3).
* The `failed` and `nosurf` arms are **unreachable by any row**: they guard a raise from the surface
  proc and a verb with no proc, neither of which a conforming tree produces. They are defensive.
* Keeping the form up on a malformed field is a behaviour **no row asserts** (S28/4 deliberately
  asserts neither what the dialog says nor whether it closes). A mutation that closed the form
  instead would be green.
* `focus $argfirst` — putting the keyboard in the first field rather than on the toplevel — is
  unfenced; `S28/2`'s focus leg accepts `.calc.arg` or any descendant.

---

## 8. What I got wrong, and what corrected me

1. **I believed the switch-comment trap was unconditional, and wrote my first sabotage to prove
   it.** It came back `ALL PASS`, and my first reaction was that the suite had not run (0.5 s felt
   impossible). It had run; the suites really are that fast. Probing `fn_argspec` directly under
   `tclsh` showed all four arms answering correctly, and counting the comment's words gave the
   mechanism. **The measurement that looked like a broken harness was the finding.**
2. **I was about to decide `arg_bad`'s `real` predicate from the contract's words**
   (`string is double -strict` and not inf/nan) rather than from the tree. `calc::eval_finite` is
   what the verbs themselves validate with, and it is *stricter* — it refuses `+0.5` and `0x10`.
   Using the contract's predicate would have let the dialog accept a value the verb then refuses
   with `badlevel`, i.e. two predicates for one fact. One predicate, the tree's own.
3. **I assumed the positional-composition bug would be caught by MT11's order row.** It is not:
   that row *warns*, and nothing *measures*. I only found out by running the sabotage, which is the
   whole argument for running them rather than reasoning about them.
4. **My first provenance sentence was going to be one interpolated string.** The receipt's lesson 6
   — `"$name(…)"` is an array reference, and the symptom is a stale status line rather than a
   visible error — stopped that before it was written; `calc::arg_provenance` is built with
   `append`.

---

## 9. What I did NOT do

* No commit, no push, no full T1 — the driver's.
* No `owed.sh` entry. **Debts I think are owed, for the driver to file:**
  * `look` × 4 (stage I5's SH4, unchanged): the dialog's appearance on the real screen; that R421's
    provenance sentence fits the status bar without eliding — ⚠ **worth a real look for `delay`,
    whose sentence carries eight `k=v` pairs and will certainly be long**; tab order and the feel of
    Return/Escape; and that the modal does not open behind `.calc` (its structural half is CW14's
    `wm transient` row).
  * `rule`: the existing `calc_argdialog_field_labels_and_delay_second_signal` debt now has
    rendered labels behind it, and MT11 pins every string, so an overrule is a one-row edit.
  * `rule`: §6.4 — the click-message wording debt from CLICK_CONTRACT §5 is **moot**, not answered.
  * `rule`: the dialog refusing an **emptied optional field** (clearing `Dataset` is refused rather
    than falling back to the proc's default) is a user-visible choice I made and no row asserts.
* `riseTime`, `delay` and `dutyCycle` are still not driven through the OK path (hole SH2). §6.1's
  row covers the static half of `dutyCycle`'s composition; `delay`'s two-operand call remains
  unfenced, as stage I5 declared.
* R401's "an `rpn` field is never parsed" is still unobservable (hole SH5). Nothing in my code
  parses one; nothing can prove it.
* I did not change `calc::close`, `calc::fn_reason`, `calc::catalogue`, `calc::fn_fields` or any
  `calc::cross_msg` sentence.

## 10. Hygiene

`git status --short` at the end lists **exactly the same files as at the start of this stage**, with
no new entries. Of those, the two I meant to change are `src/calculator.tcl` and
`tests/headless/test_calc_measure.tcl` (both were already `M` from other crews' uncommitted work).
`src/calculator.tcl` is `cmp`-identical to the post-implementation copy, so no sabotage survives.
Zero leftover `/tmp/xschem-test-home.*`; the 806 `/tmp/xschem_emergencysave_*` were not touched.

Scratch left under `scratchpad/I7-dialog-impl/`: **276 KB** — the run transcripts, the eleven
mutation scripts, `sab.sh`, `armsweep2.tcl`, `derive.tcl`, `capture.sh`, `nogui_probe.tcl` and the
three raw suite captures. The 339 KB working copy of `calculator.tcl` was swept. `/tmp` is at
728 MB, the figure it was at when this stage started.

## 11. Registration delta, DERIVED

All three suites are already registered, so `cases` and `blocks` cannot move. The rest was derived
by lifting `summarize_all`'s five regexp arms out of `tests/run_regression.tcl`'s own text and
running them, with `banner_complete` sourced from `tests/banner_rule.tcl`, over the **real captured
bytes of each suite's own stdout** on the arm T1 runs it (`derive.tcl`):

| suite | counted | lowercase `skip:` | uppercase `SKIP:`/`note:` | `RESULT:` lines | `banner_complete` |
|---|---|---|---|---|---|
| measure (`--nogui`) | 0 | 0 | 0 | 1, last | 1 |
| skeleton (`:99`) | 0 | 0 | 0 | 1, last | 1 |
| widgets (`:99`) | 0 | 0 | 0 | 1, last | 1 |

So: `cases` **+0**, `blocks` **+0**, `counted_failures` **+0**, `skips=` **+0**, `wc -l` **+0**.
Only the published check counts move (135 → 160, 548 → 573, 246 → 259).

⚠ **That is a derivation and not a prediction of the trailer.** Read `tests/results.<pid>.log`.
