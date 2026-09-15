# 1471 — The Simulators window never says what the program in front of it can do, and no page says what works on which ngspice

**Status:** FIXED pending the driver — Stage 16 task 2 of the ASE-L analyses batch
(`doc/claude/ase_analyses_batch/PLAN.md` §16a's window row and §16e's release note), receipt
`doc/claude/ase_analyses_batch/receipts/47-stage-16-gui.md`. Filed 2026-09-15 by the Stage 16 task 2
crew. Builds on issue **1470** (task 1), whose receipt 46 *What task 2 builds on* is the specification.
**Not here:** 16c's two co-simulation clauses still have no say-site (receipt 46 C6) — Stage 16 task 3.

## What the user meets

1. **The window where the question is asked has no answer in it.** Issue 1470 composes one sentence per
   program — what *this* build can and cannot do — and says it in a run's log only: once per binary per
   session, and only when something is missing. A user who registers `/usr/bin/ngspice` under
   **Setup > Simulators…**, opens **Edit…** and presses **Detect** is told which spellings of a net name
   it keeps, and nothing about the fast operating-point dump it lacks or the two kinds of command line it
   misreads. The first two frames of the sentence — *nothing measured* (R9-678) and *can do everything*
   (R9-679) — are said nowhere at all.
2. **A person deciding whether to use ASE-L has nothing to read.** *"Will this work with my ngspice?"* is
   answered by measurements spread over forty receipts and three evidence files, and by no page a user
   would find. PLAN §16e calls the description the highest-adoption-value item of the variant amendment.

## The fix

* **The row editor gains one line**, `$top.simrow.variant`, directly beneath the case-mode status line
  (grid row 5; the buttons move to 6). Its one writer is `ase::ui::simdlg_variant_paint`, which paints what
  it is handed and decides nothing.
* **The schema decides what it says** (`src/ase.tcl`, beside `ase::variant_report`):
  * `ase::variant_status {backend path eargs}` — at editor-open and whenever the Program field is left.
    `ase::casemode_status`'s shape exactly: no location, no program, a folder or no probe hook gives
    nothing (the status line owns those); otherwise `ase::variant_sentence` over the cached answer **only
    when the peek `ase::sim_caps_have_path` says one is in hand**, else over `{known 0}` — the first frame.
    It starts nothing (D8).
  * `ase::variant_detected {backend path caps}` — after Detect, about the answer Detect got. A `known`
    that is not 1 gives nothing: the status line has already said why (slow, no place, no key), and the
    peek would otherwise read the unremembered answer back as "never measured" and tell the user to press
    the button they just pressed (issue 1371's refuted sentence).
  * Neither calls `ase::variant_say`, so looking at a program never silences the run log's line.
* **Detect empties the line before the launch** is flushed, and paints `ase::variant_detected`'s answer
  after it.
* **The release note** — `doc/claude/ase_analyses_batch/RELEASE_NOTE.md`: the description (24 tagged
  claims, each with an evidence row naming the measurement) and ⚖ R11's support sentence. Where it ships
  is the user's call (below).

## Decisions taken here, each on the user's queue

* **C2 — the window shows the complete frame** (*"<path> can do everything ASE-L offers."*), not nothing.
  PLAN §16's *What you see* said nothing; §16a's own rule said a complete build *"reads eleven words and
  stops"*. The run log keeps the delta-only rule because it repeats every session; the window is looked at
  on purpose, and an empty line there already means four other things (no location, no program, no probe,
  a probe that did not answer) — *everything* must not be a fifth reading of the same silence. Rule `1471`.
* **The window says the first frame** (R9-678) when nothing is in hand, as receipt 46 specified — beside a
  status line that also names Detect (*"…has not been tried yet … press Detect to try it."*). Two mentions
  of one button in one editor, recorded rather than resolved. Rule `1471`.
* **After a Detect whose probe did not answer, the line is empty** rather than the first frame. Rule `1471`.
* **An emptied Program field empties the line**, although the status line above keeps its last sentence
  (its existing behaviour, untouched). Rule `1471`.
* **The release note's destination** — upstream's `Changelog`, a project page, or nowhere yet — and **one
  departure from R11's drafted support sentence**: *"stock upstream at the 47 tip"* became *"stock upstream
  ngspice built from source"*, because 47 is not a release (receipt 46 C8's rule). Rule
  `1471_release_note_destination`.

## Verification

`tests/headless/test_ase_simwin_variant_1471.tcl`, new, in `hcases` and `dcases`: sections WS (the two
procs, no binary), WR (the note's rules, the file only), ST (the 104 `.state` files) on both arms, and WG
(the real menu and widgets) on the display arm, whose WG7 rows press Detect on apt 45.2 and on the fork.
A counted wrapper on the probe hook and a MARK-writing stand-in program hold every non-Detect row to zero
launches; WG5 is the positive control. Numbers, sabotage and the look: receipt 47.

## Declared limits

* **Two sentences side by side is two row editors.** The window's line lives in the row editor, which
  shows one program at a time; the look debt's *"side by side, one shot"* is paid with two session
  windows' editors placed next to each other on the dev display.
* **The note's claims about stock upstream are the probe's only.** No feature-by-feature run on it exists,
  so *"the same on every ngspice we test"* cites apt 45.2 and the fork.
