# 0891 — 0881's viewer consult is green headless and red with a live display

**Status:** **FIXED** 2026-08-28 (backlog item A12); **ruling debt SETTLED 2026-08-29** on the user's "decide the 23" instruction — see the RULING section at the foot of this file (arm ratified; three follow-up code changes named, not yet done). Verdict: **the fixture was
at fault, the product was not** — established by measurement, not by assumption,
see "Which side was wrong" below. Originally measured 2026-08-28 during the
item A11 write-up, on the
persistent dev display `:99` (alive, 1920x1080x24, openbox 3.6.1). **Not caused
by A11** — see the attribution section, which is evidence, not an assertion.
This is 0881's own machinery, and 0881 is marked FIXED.

## The claim

`test_op_annot` is `RESULT: ALL PASS (447 checks)` + `OVERALL: ok` under
`--nogui`. The same suite, same binary, same tree, run through
`tests/headless/devdisplay.sh exec`:

    RESULT: 2 FAILED (451 passed)
    OVERALL: notok

The two are **V50** and **V51** — which are, by 0881's own write-up, that
issue's acceptance rows.

## What the user would see

**V50.** The waveform window is showing one results file; a different file sits
at the preferences path. The row asserts the file **the viewer is showing** is
the one annotated. Headless it is. With a display live, the annotation read the
decoy: expected the numbers from `v_a10_vrun.raw` (`d 3 g 0.9`), got the decoy's
(`d 21 g 0.1`), and the second leg came back `noraw` / `{1 {No raw file
loaded}}` where `ok` and the viewer's own path were expected.

That is the user-visible shape of 0881 itself — *the numbers that land on the
schematic come from a different results file than the one on screen* — and it is
the user's own verbatim ruling that closed 0881: *"The info should already be
available - it's been loaded to display waveforms in the waveform viewer."*

**V51.** The results file changed under the viewer, so the annotation must
refuse and say which file and why. With a display live it refuses with the wrong
sentence — the user is told

    No simulation results are loaded, so there are no voltages to show. Run a
    simulation first, then try again.

when what actually happened is

    The results file v_a10_vrun.raw on disk is from a different simulation run
    than the one the waveform window is showing, so nothing was placed on the
    schematic. Plot the results again in the waveform window, then try again.

The refusal is correct — nothing is painted, `{0 -1}`, so RULING D5-1 holds —
but the reason given is wrong, and a wrong reason is the same defect class as a
wrong number.

## Attribution — why this is not the plain-English pass

Three independent legs, all measured:

1. **The wording in the failure output is A11's new wording and it MATCHES the
   expectation.** V50's fourth element is
   `Showing each node's voltage at 3 ns, where cursor B is on the waveform.` in
   both actual and expected. The divergence is the state (`noraw` vs `ok` /
   `viewerdiff`) and which file was attached — never the sentence.
2. **A11 changed no code on that path.** Comparing non-comment lines of
   `utils/annot_mode.tcl` against `HEAD` (`1d466364`), every change is one of:
   the four new procs (`_annot_tsec`, `_annot_menu_op`, `_annot_bytes`,
   `_annot_fit`, `_annot_say`), a minted sentence, or a render site collapsing
   onto `_annot_say`. `_annot_raw_supply`, the candidate search and the
   two-window compare are untouched.
3. **An earlier verifier reproduced it on the pre-item tree**, by extracting
   `HEAD`'s `src/`, `utils/` and `tests/` into a scratch tree and running the
   pre-item suite against the same binary on the same display: same two rows red.

## Why it was never seen

0881's write-up records V50/V51 as **headless** rows (its sabotage list reads
"`S-R1` delete the viewer consult -> V47 V50 V51 headless"), and headless is
where they were run. Under `--nogui` there is no real Tk toplevel, so the viewer
the rows consult is a different object from the one a user has. The suite's
display legs self-skip headlessly, which is the recorded arm — and it is
precisely why a display-only divergence could sit under a green banner.

This is the CLAUDE.md rule about `:0` in a new place: *treat a bug that only a
display can reproduce as a test defect too*. The fix is to make the arm the user
actually has the arm the acceptance rows run in, not to hope one supplies it.

## What was owed

* Establish which side is wrong: the product (the consult really does miss the
  viewer's database once a real toplevel exists) or the fixture (the display arm
  builds a viewer the consult was never meant to find). Do **not** assume the
  fixture — 0881's whole point is that the consult was missing.
* Whichever it is, V50 and V51 must run and pass in **both** arms. Two green
  arms is the only state that closes this.
* ~~Note this red is invisible to every runner: `run_regression.tcl` runs
  `test_op_annot` headless, and so does `full_audit.sh`'s `nogui_tests`.~~
  **⚠ THIS SENTENCE WAS HALF WRONG AND THE CORRECTION MATTERS.** `test_op_annot`
  is **not** in `full_audit.sh`'s `nogui_tests` (`grep -c test_op_annot
  tests/headless/full_audit.sh` = 0), so a full audit already fell to its display
  branch and already reddened: measured before the fix,
  `tests/headless/full_audit.sh test_op_annot` printed
  `display arm: ATTACHED to persistent dev display :99 (devdisplay.sh),
  GUI_GATE=0`, then `FAIL | test_op_annot`, `SUMMARY: 0 pass 1 fail`, exit 1.
  So the audit had been reporting this failure — to nobody who read it. The
  genuinely blind runner was **T1**: `tests/run_regression.tcl` hard-coded
  `--nogui` for every `hcases` entry, and T1 is the everyday runner.

---

# THE CLOSE  (2026-08-28, backlog item A12)

## Which side was wrong: THE FIXTURE. Proved positively, in three legs.

The comfortable answer here was "the fixture", and taking it on faith is what
would have re-shipped 0881. It was not taken on faith.

**Leg 1 — the product was confirmed WORKING on a live display, by a suite that
drives the real waveform window.** `tests/headless/test_annot_show_menu.tcl`
stands its viewer up through `wviewer::open` + `wviewer::attach_raw`, not a
stand-in. On `:99` with openbox 3.6.1 live: `RESULT: ALL PASS (32 checks)`,
exit 0 — row **B12g** included, and B12g is 0881's own acceptance ("the results
file the WAVEFORM VIEWER is showing is the one annotated, even when the session
metadata names a different file"). The consult a real user gets works.

**Leg 2 — the fixture builds a window no user has, and it is two mismatches, not
one.** Both measured in one process on `:99`:

* `test_op_annot.tcl`'s `opa_v_viewer` stood the viewer up with
  `xschem new_schematic create`. Under Tk, `tabbed_interface` is 1 by default, so
  that makes a **TAB**: `win_path` `.x1.drw` is a C-side name with **no Tk widget
  behind it** (`winfo exists` = 0), and `winfo children .` contains no `.x1` at
  all. The real viewer is never a tab — `wviewer::open` uses
  `xschem load_new_window -window {}` (`src/wave_viewer.tcl:1267`), which always
  yields a real toplevel (`.x2`, `winfo exists` = 1).
* The fixture's stub `::wviewer::window_for` returned the **win_path**. The
  shipped `wviewer::window_for` (`src/wave_viewer.tcl:803-810`) returns the
  registry's **`top`** field — the Tk toplevel — and already `winfo exists`-checks
  it before answering.

So on the display arm `winfo exists .x1.drw` answered 0 inside
`cadence::_annot_viewer_db` (`utils/annot_mode.tcl:1094-1098`), the consult
returned empty, and `_annot_tran_supply` fell back to the rebuilt preferences
path — the decoy. **That single statement is the whole of both failures.**

**Leg 3 — the decisive experiment.** In a `/tmp` symlink shadow tree with
**product code byte-unchanged**, only those two fixture lines altered, the
display arm went to `RESULT: ALL PASS` / `OVERALL: ok` / exit 0 while the
headless arm stayed green. Nothing in `utils/annot_mode.tcl` or
`src/wave_viewer.tcl` had to move to make the display arm pass.

## The rejected alternative

**Relaxing the Tk liveness probe** at `utils/annot_mode.tcl:1094-1098` — the
`winfo exists $top` test — was rejected. It asks a legitimate question of a
legitimate value: it is the only thing stopping the consult borrowing into a
**dead** viewer's context. Relaxing it would have made both arms agree by
lowering the bar, which is the one repair this issue explicitly forbids. The
probe is kept and is now fenced by structural row **V56**, because no
behavioural row in the tree can see it (a second guard — `wviewer::enter_ctx`
refusing an unregistered token — covers the same case from the other side).

## What shipped

**The fixture** (`tests/headless/test_op_annot.tcl`, `proc opa_v_viewer`). Under
Tk it now builds its waveform stand-in the way `wviewer::open` does —
`xschem load_new_window -window {}`, then `xschem load` the schematic, then
`xschem set readonly 1` — and verifies the context switch rather than assuming it
(landmine 17: `-window` always creates the toplevel, but the switch to it
silently no-ops under a raised semaphore). It records **both** registry keys the
product records, and `window_for` now answers the **top**, as the product's does.
The empty file argument is load-bearing: `load_new_window -window <file>` with a
non-empty name takes `scheduler.c`'s pristine-untitled reuse arm and loads into
the *current* window instead.

**V34 was deliberately left alone.** It uses the same `new_schematic create`
shape on purpose, does not stub `window_for`, passes on both arms, and its whole
value is being the control V50 is contrasted against.

**The arm** (`tests/run_regression.tcl`). A second list, `dcases`, and a second
loop run `headless/test_op_annot` a **second** time on the persistent dev display
via `tests/headless/devdisplay.sh exec` — never on the invoking `$DISPLAY`, which
is the human's real screen. Same three-condition verdict, same
`banner_complete` / `banner_died` / `regression_case_failed` predicates out of
`tests/banner_rule.tcl` (never a private copy — `test_audit_classifier.tcl`
section K locks the three readers together). A box with no dev display prints an
uncounted, loud `NODISPLAY:` line rather than a red or a silence, following issue
0147's `NOGOLD` precedent for "this arm verified NOTHING"; `summarize_all`'s
surfacing regexp was widened from `^NOGOLD` to `^(NOGOLD|NODISPLAY)`.

## Rows

| row | kind | arm | what it holds |
|---|---|---|---|
| **V50**, **V51** | behavioural | **both** | unchanged, not rewritten, not weakened — 0881's acceptance, now green on the arm the user has |
| **V53** | behavioural | display; **announced skip** headless | the stand-in is a real live Tk toplevel, not a tab's canvas, and the shipped consult finds the file the waveform window is showing |
| **V54** | structural | both | the fixture is built on the verb the real viewer uses and answers the registry field the real viewer answers — this is what makes a fixture regression visible **headlessly** |
| **V56** | structural | both | the liveness probe exists and declines the borrow when the window is gone |
| **V57** | structural | both | the runner really does have a display arm, it routes through `devdisplay.sh`, it does not pass `--nogui`, and `NODISPLAY` is surfaced |

V53 cannot be expressed headlessly — `winfo` does not exist under `--nogui`, so
the very probe under test is unreachable. It therefore prints, loudly:

    skip: V53 needs a display - winfo does not exist under --nogui, so the Tk
    liveness probe in cadence::_annot_viewer_db, which is the thing under test,
    is never reached

and **V54 carries the same claim as source text in both arms**, so the everyday
headless runner still reddens if the fixture regresses.

## Measured, at the close

Persistent dev display `:99` (Xvfb 1920x1080x24) with a real window manager live
— **openbox 3.6.1** (`devdisplay.sh status` → `wm: openbox (Openbox)`). Nothing
was run on `$DISPLAY` (the user's Windows X server over TCP) and nothing on `:0`.

| arm | before | after |
|---|---|---|
| `--nogui` | `ALL PASS (447 checks)` / `ok` | `ALL PASS (451 checks)` / `ok` |
| `devdisplay.sh exec` on `:99` | `2 FAILED (451 passed)` / `notok` / exit 1 | `ALL PASS (458 checks)` / `ok` / exit 0 |
| `full_audit.sh test_op_annot` | `FAIL`, `0 pass 1 fail`, exit 1 | `PASS`, `1 pass 0 fail`, exit 0 |
| `tests/run_regression.tcl` | no display arm at all | **zero** counted failures, and `headless/test_op_annot.disp.log` appears in `results.log` with its own summary block |

`test_annot_show_menu` on `:99`: `ALL PASS (32 checks)`, exit 0.

## Spun off, not fixed here

**Issue 0893** — the same *wrong reason* defect class, in the case that remains
**after** this one: when the consult SUCCEEDS but the file the waveform window
named cannot be read again off disk. Fixed alongside, with its own row V55.

**Issue 0894** — **two of the rows above did not work.** The sabotage pass found
that V57's routing leg and V57's classifier leg were both satisfiable with the
thing they name entirely removed: the routing leg grepped the whole loop for
`devdisplay.sh|$dd`, which the loop's own `$dd_alive` variable and its own
`NODISPLAY` sentence satisfy with no routing at all; and the classifier leg read
`opa_proc_src`'s slice of `summarize_all`, which runs to end of file because
`run_regression.tcl` has only one proc, so it matched the loop's printed message
instead of the classifier. Strip the dev-display routing out of the launch line —
so `tclsh run_regression.tcl` opens xschem on the human's own screen — and the
tree stayed `ALL PASS` in both arms. Both legs were repaired in the same commit
and each is now verified to go 1 → 0 across its removal. **0894 also covers a
third unseen guard on issue 0893's arm.** A restored arm that nothing notices
the removal of would have set this exact trap again.

**Issue 0898** — the arm has a price: T1 now runs `test_op_annot` twice, so its
3000 ms wall-clock row W33 has two chances to flake on a loaded machine.

**Issue 0896** — measured on the way out and **not** fixed here: the two-window
compare this feature depends on is skipped entirely when the waveform window's
results file has no points yet (a run the user is watching fill), and another
run's numbers reach the schematic with no warning. That is a live RULING D5-1
violation on a path no row covers. **Issue 0895** is the same conflation's third
face — a *deleted* viewer file still produces "No simulation results are
loaded" while the traces are on screen, which is issue 0893's commonest trigger.

---

# THE RULING  (2026-08-29, decided under the user's "decide the 23" instruction)

**DECIDED: the display arm stays in the everyday regression run, exactly as it
ships.** No code moves.

The debt asked whether `tests/run_regression.tcl` should keep starting the
persistent dev display and re-running the annotation suites on it, given the two
costs — extra wall clock, and an X server left running afterwards — with the only
alternative on offer being a silent skip when no display is there.

## Why this was not the user's call to make

* **The alternative is the defect.** A silent skip under a green banner *is*
  issue 0891. `CLAUDE.md` already forbids it twice over — "a standing red is a
  defect, not furniture", and the T1-baseline-zero rule — and issue 0147 already
  settled the shape of the answer with `NOGOLD`: an arm that verified nothing
  says so, loudly, without being counted a regression. `NODISPLAY` is that same
  precedent applied to the same problem.
* **The evidence is not an argument, it is a measurement.** 0881's feature was
  `ALL PASS (447 checks)` headless and `2 FAILED` on a display, same binary, same
  tree — and the two red rows were 0881's own acceptance rows. The blind runner
  was T1, and T1 is the everyday runner.
* **Neither cost is really a cost.** `CLAUDE.md` instructs the user to start the
  persistent dev display once and leave it up (idempotent, ~0.3 s), so a
  surviving Xvfb is the documented intended state, not litter. And the runner
  must *not* stop it: the control dir is shared with every other session and
  worktree, so a `stop` at the end of a regression run would pull the display out
  from under whatever else is attached to it. Leaving it up is the correct
  behaviour, not an oversight.
* **It fails open and never touches the human's screen.** No display → an
  uncounted `NODISPLAY:` line, so a headless CI box stays green. Every child is
  launched through `devdisplay.sh exec`, which pins `DISPLAY=:99` and
  `GUI_GATE=0` for the child only (`tests/headless/devdisplay.sh:402`), so the
  user's real screen and their Pause/Stop panel are both left alone.

## Correction to the debt's own pitch — the cost is 3x what it says

The pitch reads "runs `test_op_annot` a SECOND time ... ~15 s more". That was
true when it was written and is not true now: `dcases` has grown to **four**
suites (`test_op_annot`, `test_annot_show_menu`, `test_annot_stale_0684`,
`test_annot_blank_cause_0909`), of which three are also run headless and one
(`test_annot_show_menu`) runs only here.

Measured from the run of 2026-08-29 01:48–01:53 (log mtimes, dev display `:99`
alive with openbox 3.6.1, a loaded box with other agents live): the headless loop
ended 01:52:24 and the display loop ended 01:53:09 — **~45 s** for the four
suites, against a whole-run wall clock of roughly five minutes. All four were
green on the display arm: 483, 36, 52 and 27 checks, `OVERALL: ok`.

The ruling does not change with the bigger number. 45 s on a five-minute run to
cover the only arm in which a window exists is still the cheap side of the trade.

## Left standing, deliberately

* **Issue 0898** (the `W33` wall-clock row now has two chances to flake) is a
  separate open question about what T1 should cost, with its own option list. It
  is not settled here.
* **Which suites belong in `dcases`** is not settled here either. This ruling is
  about the arm existing, not its membership; a suite whose subject is not a
  window has no business in it, and that is a per-suite judgement.

---

# ADVERSARY REVIEW OF THE RULING  (2026-08-29)

**The direction is right and stays: the display arm is kept.** A silent skip
under a green banner is the defect this issue is named after, `CLAUDE.md`
forbids it twice, and issue 0147's `NOGOLD` already settled the shape. That half
of the ruling is not disturbed, and it did not need the user.

**What is overturned is the other half — "exactly as it ships. No code moves."**
Three findings, all read out of the tree, none of them a preference.

## 1. The new arm is the one loop in the tree with no clock on it

| reader | wraps every launch in a time cap? |
|---|---|
| `tests/headless/full_audit.sh` | yes — `timeout ${AUDIT_TIMEOUT:-300}`, 7 call sites |
| `tests/headless/run_suites.sh` | yes — `timeout ${SUITE_TIMEOUT:-200}`, 3 call sites |
| `tests/run_regression.tcl` display loop | **no — zero** |

That asymmetry did not matter while T1 was `--nogui` everywhere, because the
hang this tree has actually measured **cannot happen without a display**. Both
cases are written down in `full_audit.sh` itself:

* `test_placement_wire_gate` — "with ANY display it blocks forever at the G4
  `xschem place_text` row — headlessly `place_text()` fails fast because the
  text dialog needs a Tk toplevel, but under a real X the modal is raised for
  real and nothing dismisses it. Measured: killed at 120 s under WSLg, **still
  stalled after 300 s under xvfb-run**." Xvfb is not a defence.
* `test_descend_symbol` — a modal `alert_` nothing dismisses: "**It does not
  fail, it HANGS**, and paid `AUDIT_TIMEOUT` (300 s) plus a crash row on every
  full run."

The audit survived both only because of its cap. T1 now runs four suites with a
live display and no cap, so the failure mode it newly admits is not a red row —
it is a runner that never returns.

## 2. And a hang there destroys the whole report, not just its own row

`results.log` is opened with `open ... w` and closed only after `xschemtest`;
there is no `fconfigure -buffering` and no `flush` anywhere in the file (grep =
0). Tcl's default is full buffering at 4 KB and **the entire finished
`results.log` is 2678 bytes** — under one buffer. The display loop runs *after*
all 38 headless cases have been summarized into that unflushed buffer. So a hang
or the Ctrl-C that ends it throws away every headless result as well, and the
everyday runner produces nothing at all.

## 3. The ruling states a membership rule and then declines to apply it, on a number it had

The ruling says "a suite whose subject is not a window has no business in
[`dcases`]", records ~45 s, and leaves membership standing. The per-suite split
was available in the same log mtimes the 45 s came from:

| display-arm suite | cost | also run headless? | `full_audit.sh` pins it |
|---|---|---|---|
| `test_op_annot` | ~16 s | yes | (not in `nogui_tests`) |
| `test_annot_show_menu` | ~0.8 s | **no — display only** | — |
| `test_annot_stale_0684` | **~27 s** | yes, 26.6 s | **`--nogui`** |
| `test_annot_blank_cause_0909` | ~0.35 s | yes | **`--nogui`** |

**~27 s of the ~45 s — about 60% — is `test_annot_stale_0684`**, a suite whose
subject is a results file going stale rather than a window, which already runs
to completion headless in the same run, and which `full_audit.sh:161` has
already assigned to `--nogui`. Two readers in one tree now put the same suite on
opposite arms, and the one with no time cap took the riskier side. The ruling's
cost argument was made on an aggregate whose majority buys nothing.

## The decision that should stand

Keep the arm. Then, in the same loop and without touching a fence:

1. **Put a clock on each display-arm launch**, matching `full_audit.sh`'s 300 s,
   as `exec $dd exec timeout 300 $xschem_cmd ...`. `timeout` exits 124, which the
   existing `regression_case_failed` verdict already turns into a counted
   failure; the appended line should say plainly that the suite ran out of time
   on the hidden test display rather than implying a crash.
2. **Line-buffer `results.log`** (`fconfigure $fd -buffering line`) so a hang, or
   the Ctrl-C that ends one, cannot erase 38 case blocks that already passed.
3. **Drop `test_annot_stale_0684` from `dcases`** and reconcile with
   `full_audit.sh`'s `nogui_tests`, which has already ruled on it. That returns
   ~27 s of the ~45 s and leaves the arm covering the three suites whose subject
   really is a window.

All three keep row **V57** green: the launch line still matches
`(devdisplay\.sh|\$dd)\s+exec`, the loop still carries no `--nogui`,
`summarize_all` still surfaces `NOGOLD|NODISPLAY`, and `test_op_annot` and
`test_annot_show_menu` both stay in `dcases`.

**Smaller, noted not fixed:** `dd_alive` is probed once before the loop, so a
display stopped mid-run by another session — the shared control dir makes that
possible, and the ruling relies on that sharing for its "never stop it"
argument — lands as `exit=6` on every remaining suite rather than as a
`NODISPLAY` line.

---

## RULING, 2026-08-29 — decided on the user's instruction

The user said, verbatim, 2026-08-29:

> **"decide the 23, leave 0861 and 0299 for me"**

A read-only audit of the 57-entry ruling queue classified 25 of the waiting
questions as ones whose answer is cheap and obvious — things that should be
decided rather than handed to the user to read. **This debt was one of the 23.**
Only 0861 and 0299 were held back for the user.

This section is the settled ruling and supersedes the earlier
"# THE RULING" section above where the two differ. That section's first half —
keep the display arm — stands unchanged. Its second half, *"exactly as it ships.
No code moves"*, does not.

### The ruling

**Keep the second pass on the hidden test display.** The everyday regression run
(`tclsh tests/run_regression.tcl`) goes on starting the persistent dev display
and re-running the annotation suites on it, goes on leaving that display up
afterwards, and goes on printing an uncounted `NODISPLAY:` line — never a silent
skip, never a green banner — on a machine that has no such display.

**Then make three changes to that loop.** All three match precedent that already
exists elsewhere in this tree, and none of them disturbs the fences row `V57`
locks:

1. **Put a clock on each display-arm launch**, the same 300 s the full audit
   already uses: `exec $dd exec timeout 300 $xschem_cmd ...`. `timeout` exits
   124, which the existing `regression_case_failed` verdict already counts as a
   failure. The line that gets appended must say in plain words that the suite
   ran out of time on the hidden test display — not something that reads like a
   crash.
2. **Write the report as the run goes** — `fconfigure $fd -buffering line` on
   `results.log` — so a suite that stops responding, or the Ctrl-C that ends it,
   cannot throw away the 38 headless case blocks that already passed.
3. **Stop re-running `test_annot_stale_0684` on the display arm** — drop it from
   `dcases`, reconciling with the full audit, which has already assigned that
   suite to `--nogui`. Its subject is a results file going stale, not a window.
   That returns ~27 s of the ~45 s and leaves the arm covering the three suites
   whose subject really is a window.

### Why

* **The only alternative on offer — skip quietly when no display is there — is
  this issue.** `CLAUDE.md` forbids it twice: *"a standing red is a defect, not
  furniture"*, and the T1-baseline-zero rule. Issue **0147** already settled the
  correct shape with `NOGOLD`: an arm that verified nothing says so out loud and
  is not counted as a regression. `NODISPLAY` is that precedent reapplied.
* **The evidence is a measurement, not a preference.** 0881's feature was
  `ALL PASS (447 checks)` with no windows open and `2 FAILED` with a display
  live — same binary, same tree — and the two red rows were 0881's own
  acceptance rows. The blind runner was T1, and T1 is the everyday runner.
* **Neither alleged cost survives inspection.** `CLAUDE.md` tells the user to
  start the dev display once and leave it up (idempotent, ~0.3 s), so a
  surviving Xvfb is the documented intended state. And the runner must *not*
  stop it: the control directory is shared with every other session and
  worktree, so a stop at the end of a regression run would pull the display out
  from under whatever else is attached to it.
* **It never touches the human's screen.** Every child goes through
  `devdisplay.sh exec`, which pins `DISPLAY=:99` and `GUI_GATE=0` for that child
  only, so the user's real screen and their Pause/Stop panel are left alone.
* **Why the three changes.** The display arm is the only loop in this tree with
  no time limit on it: the full audit wraps every launch in
  `timeout ${AUDIT_TIMEOUT:-300}` (7 call sites) and `run_suites.sh` in
  `timeout ${SUITE_TIMEOUT:-200}` (3 call sites); `run_regression.tcl` has none.
  That was harmless while T1 was headless everywhere, because the hang this tree
  has actually measured **cannot happen without a display** — a modal dialog is
  raised for real and nothing dismisses it, and the audit records two such
  suites, one of which was still stalled after 300 s under Xvfb. And an
  un-flushed report makes that hang worse than a red row: `results.log` is
  opened plain, has no `fconfigure -buffering` and no `flush` anywhere in the
  file, Tcl buffers to 4 KB, and the whole finished report is 2678 bytes — under
  one buffer — so a hang on the display arm, which runs *after* all 38 headless
  cases are summarized, would leave the user with nothing at all. Finally, the
  earlier ruling stated the membership rule ("a suite whose subject is not a
  window has no business in `dcases`") and then declined to apply it to a number
  it already had; ~60% of the arm's cost is one suite that is not about a window
  and that the full audit has already pinned to `--nogui`.

### Verified in the tree

* `tests/run_regression.tcl:80-82` — `dcases` is **four** suites, not the one the
  debt's pitch names: `test_op_annot`, `test_annot_show_menu`,
  `test_annot_stale_0684`, `test_annot_blank_cause_0909`. Three of the four are
  also in `hcases` (lines 56, 59, 60), so they genuinely run twice;
  `test_annot_show_menu` runs only on the display arm.
* `tests/run_regression.tcl:190` — `catch {exec $dd start 2>@1}`: the runner
  really does **start** the dev display. A grep for `stop` in that file returns
  only comment prose, so nothing ever takes it down — the display is left up.
* `tests/run_regression.tcl:192-203` — `$dd status` is matched against
  `*state:*alive*`; where that fails, the loop prints an uncounted
  `NODISPLAY: ... THIS ARM VERIFIED NOTHING` line with `Total num fail: 0` and
  carries on. The probe matches reality: `devdisplay.sh status` prints
  `state:   alive` today.
* `tests/run_regression.tcl:205` — the launch line is
  `exec $dd exec $xschem_cmd --pipe -q --script ${dc}.tcl`: routed through
  `devdisplay.sh`, with **no** `--nogui`. `tests/headless/devdisplay.sh:402` is
  `DISPLAY="$DPY" GUI_GATE=0 "$@"`, pinning the child to `:99` with the gate off
  for the child only.
* `tests/run_regression.tcl:94-104` — `summarize_all`'s surfacing regexp is
  `^(NOGOLD|NODISPLAY)`: printed, not counted, per issue 0147's precedent.
* `tests/headless/test_op_annot.tcl:14177-14184` — row **V57** locks all of it:
  `test_op_annot` in both `hcases` and `dcases`, the loop exists, the launch line
  routes through `devdisplay.sh|$dd exec`, the loop carries no `--nogui`,
  `summarize_all` carries `NOGOLD|NODISPLAY`, and `test_annot_show_menu` is in
  `dcases`. All three changes above keep this row green.
* **The arm is currently green, not a standing red.** Tails of the four logs from
  the 2026-08-29 01:5x run: `test_op_annot.disp.log` `ALL PASS (483 checks)
  OVERALL: ok`; `test_annot_show_menu.disp.log` `ALL PASS (36 checks)`;
  `test_annot_stale_0684.disp.log` `ALL PASS (52 checks)`;
  `test_annot_blank_cause_0909.disp.log` `ALL PASS (27 checks)`.
* **Cost, measured** from log mtimes of that same run: last headless case
  01:52:24, last display case 01:53:09 — **~45 s** for the display arm, against
  `create_save.log` 01:48:13 → `results.log` 01:53:09, a ~5-minute whole run. The
  debt's pitch says "~15 s"; that is stale by roughly 3x. Per-suite:
  `test_op_annot` ~16 s, `test_annot_show_menu` ~0.8 s (display-only, the one
  genuinely new coverage), `test_annot_stale_0684` ~27 s,
  `test_annot_blank_cause_0909` ~0.35 s.
* `full_audit.sh:161` already lists `test_annot_stale_0684` under `nogui_tests`,
  so the two readers in this tree currently put the same suite on opposite arms,
  and the one with no time cap took the riskier side.
* `doc/claude/issues/0898-*.md` — the double-run's real cost is the `W33` 3000 ms
  wall-clock row (1089 ms clean, 5010 ms on a loaded box) now having two chances
  to flake. It carries its own option list and is explicitly recorded as
  undecided; it is not folded into this ruling.

### Does anything move?

**Partly.** The arm itself is **ratified** — it stays exactly where it is, and
the "keep the display running afterwards" behaviour is correct as shipped.

**Three code changes are implied, and none of them is done yet — follow-up
work:**

1. `tests/run_regression.tcl:205` — wrap the display-arm launch in
   `timeout 300`, and word the appended failure line as "ran out of time on the
   hidden test display", not as a crash.
2. `tests/run_regression.tcl` — `fconfigure $fd -buffering line` on the
   `results.log` channel.
3. `tests/run_regression.tcl:80-82` — remove `test_annot_stale_0684` from
   `dcases`.

**Also noted, not fixed:** `dd_alive` is probed once before the loop, so a
display stopped mid-run by another session — the shared control directory makes
that possible, and this ruling leans on that sharing for its "never stop it"
argument — lands as `exit=6` on every remaining suite rather than as the
`NODISPLAY` line the design intends.

**Left standing, deliberately:** issue **0898**, and the wider question of which
suites belong in `dcases` beyond the one this ruling removes.

### Told to the user

The regression run keeps its second pass on the hidden test display — it caught a
whole feature that passed with no windows open and failed with them — but it now
gives up on a suite that stops responding instead of hanging the run forever,
writes its report as it goes so a stuck run cannot throw away results that
already passed, and stops re-running one slow file-freshness suite that has
nothing to do with windows, which halves the extra time.

---

**An adversary reviewed this ruling.** It could not overturn the direction —
keeping the arm — and said so plainly; what it overturned was the claim that no
code moves, producing the three changes above, and that better answer is what is
recorded here.

**The user may reverse this at any time; it was decided to spare their
attention, not to bind them.**
