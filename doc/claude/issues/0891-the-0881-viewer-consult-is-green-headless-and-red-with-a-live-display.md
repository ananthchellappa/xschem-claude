# 0891 — 0881's viewer consult is green headless and red with a live display

**Status:** **OPEN**. Measured 2026-08-28 during the item A11 write-up, on the
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

## What is owed

* Establish which side is wrong: the product (the consult really does miss the
  viewer's database once a real toplevel exists) or the fixture (the display arm
  builds a viewer the consult was never meant to find). Do **not** assume the
  fixture — 0881's whole point is that the consult was missing.
* Whichever it is, V50 and V51 must run and pass in **both** arms. Two green
  arms is the only state that closes this.
* Note this red is invisible to every runner: `run_regression.tcl` runs
  `test_op_annot` headless, and so does `full_audit.sh`'s `nogui_tests`.
