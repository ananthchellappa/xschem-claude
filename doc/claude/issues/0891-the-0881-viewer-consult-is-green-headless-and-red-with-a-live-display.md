# 0891 — 0881's viewer consult is green headless and red with a live display

**Status:** **FIXED** 2026-08-28 (backlog item A12). Verdict: **the fixture was
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
