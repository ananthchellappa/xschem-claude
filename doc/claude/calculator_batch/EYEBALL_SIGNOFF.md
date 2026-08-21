# Calculator batch — eyeball sign-off checklist

Tick as you go. Written 2026-08-21 at HEAD `5a1d38aa`.

**What this covers:** the **8 `look` debts** the Calculator owes — calculator
batch **item 5 ×2** (the phase-1 closing eyeball and the four recorded drifts),
**item 13 ×4** (wheel scrolling, wheel feel, ASE-L's greyed menu entry, the
Results Dir row) and results batch **item 10 ×2** (the U7 refusal and the
no-viewer sentence). Nothing else in `owed.sh list` belongs here — the casemode,
GUI-gate and other results debts are other work, and **`tests/headless/owed.sh
list` is the authority** on what is still owed at the moment you read it.

**Do all of this on your real screen.** Not `:99`. The point is a human looking
at pixels, and the dev display is invisible.

**Anything that reads badly is a fix, not a sign-off.** Most of these controls
are here *because* a passing check could not judge them: 244 checks say the
Calculator's every widget exists, is the right class and is in the right initial
state, and not one of them says the window reads right.

**A look debt clears only when you say so.** `owed.sh drain` never touches this
list, and no green suite discharges any line below.

## Three launches, not eight

Sections are ordered so you restart xschem twice, not seven times.

| launch | command (from the repo root) | sections |
|---|---|---|
| 1 | `cd src && ./xschem` | **A B C D E** |
| 2 | `./src/xschem --script src/cadence_style_rc` | **F G** |
| 3 | `./sky130A/run.sh` | **H** |

Sections A–G need **no simulator, no PDK and no `.raw` file**. Only H does, and
the one it needs is already on disk.

---

## Setup

- [ ] 1. Confirm your display: `echo $DISPLAY` must print `:0`, not `:99`.
- [ ] 2. Confirm the binary is current: `find src -maxdepth 1 -name '*.c' -newer src/xschem`. If that prints nothing, no rebuild is needed. If it prints anything, run `cd src && make` first.
- [ ] 3. Know that **a Tcl change never needs a rebuild.** `src/*.tcl` is read at run time, so the Calculator you are about to look at is whatever `src/calculator.tcl` says right now. Only a `.c` change needs `make`.
- [ ] 4. Take a note of what is owed before you start: `tests/headless/owed.sh count`.
- [ ] 5. Know what these steps write to `~/.xschem`, because it is not nothing. Sections F and H open a cellview, which adds it to your **Open Recent** list (`recent_files`). Section H picks a result, which pushes it onto the recent-results list (`raw_history`, deduped, capped at 20). Quitting xschem rewrites `geometry`, as every xschem session always does. Nothing is deleted and no step asks you to delete anything — but if you would rather not collect the entries, `cp -a ~/.xschem ~/.xschem.backup-eyeball` first.
- [ ] 6. Two small aid scripts are used in sections C, D and E. They live in `doc/claude/calculator_batch/eyeball/`, write nothing to disk, and are read into a running xschem through `Tools ▸ Execute TCL command` (accelerator `=`). That dialog has **no OK button** — the button is **`Evaluate`**, and `Shift-Return` in the input box does the same. It also reopens holding whatever you last typed, so press **`Clear Input`** before typing a new line.

---

## A. Phase 1 beside the ViVA reference — debt `Calculator_phase_1_against_the_ViVA_reference_…`

**The question:** every control is present and correctly disabled — but does the
window *read* right?

The capture and the reference are both in the repo, and the capture is still
current: a fresh capture of the live window at this HEAD was compared with it
pixel by pixel and **0 of 484946 differed** (that is the whole 658x737 PNG,
window-manager frame included). You may judge from the PNGs, from the live
window, or from both.

- [ ] 7. Open `doc/claude/calculator_batch/receipts/05-phase1e.png` (ours) and `doc/claude/calculator_batch/ref/viva_xl_calculator.png` (the reference) side by side in your image viewer.
- [ ] 8. Note the sizes before judging proportions: ours is 658x737 **including the window-manager frame** (656x680 of client area); the reference is 687x1037. The reference is a much taller window, so compare shares of height, not pixels.
- [ ] 9. Start launch 1 (`cd src && ./xschem`) and open `Tools ▸ Calculator`. Leave it open for sections A through E.
- [ ] 10. Look at the **Selectors** pane. Eight ids are greyed: `sp` `vswr` `hp` `zm` `mp` `zp` `yp` `gd`. Do they read as *information* — "not in this version" — or as breakage?
- [ ] 11. Look at the **Functions** pane. Fourteen names are greyed: `dft` `psd` `spectrum` `spectralPower` `harmonic` `harmonicFreq` `convolve` `thd` `dftbb` `psdbb` `evmQAM` `evmQpsk` `pzbode` `pzfilter`. Same question.
- [ ] 12. Click one of the fourteen. The status line along the bottom must say why it is unavailable.
- [ ] 13. Judge legibility at the default size. Six columns of function names, of which about 29% is off the right-hand edge, and 2 of 10 rows are below the fold at first open. Acceptable, or does the pane need to open bigger?
- [ ] 14. Look at the pane headers. Ours are the labelframe **title text** in dark red (`#8b0000`) — "Selectors", "Stack", "Buffer", "Functions", "Keypad". The reference draws a red title **bar** across the Function Panel. Is title text enough of a "coloured panel header"?
- [ ] 15. Look at the mode strip and the buffer toolbar. **Plot / Eval / Table / Enter / Pop** are words where the reference has icons. Does a row of words read as a toolbar, or as unfinished?
- [ ] 16. Say whether the window as a whole reads as a finished tool with parts switched off, or as a half-built one. That single sentence is the payload of this debt.

**What would count as wrong:** a greyed control that reads as a *fault* rather
than as "not yet"; function names you cannot read without resizing; a pane you
cannot tell the name of.

```sh
tests/headless/owed.sh clear look Calculator_phase_1_against_the_ViVA_reference__doc_claude_calcul.1786836728.3810758
```

---

## B. The four drifts item 5 recorded and did NOT fix — debt `Calculator__the_four_unexplained_drifts_…`

**The question:** item 5 found four differences from the reference that no spec
row explains, and deliberately fixed none of them. Which are worth a later item?

The phase-0 layout is frozen, so nothing was moved to make the capture look
closer. You are giving **one line of ruling on each** — "later item" or "leave" —
not looking for a defect. The full write-up is
`doc/claude/calculator_batch/receipts/05-phase1e.md` section 6.

- [ ] 17. **Drift 1 — no coloured header bar.** The reference has a red rule under its menubar and a red title bar on the Function Panel. We have accent-coloured title *text* and nothing else. Later item, or leave?
- [ ] 18. **Drift 2 — the Results Dir row's glyph substitutes.** Our row uses `v` for the reference's red triangle and `…` for its folder icon. The same substitution for Plot/Eval/Table *is* written down in the spec; for this row it is not. Write it down later, change it, or leave?
- [ ] 19. **Drift 3 — hairline group separators.** The reference boxes each selector group in a frame and ends the row with a `»` chevron. Ours are hairlines. Later item, or leave?
- [ ] 20. **Drift 4 — the function browser's share of the height.** Ours gets about a third of the first-open height (227 px of 680), the reference about 40%. This is what puts column 6 off the edge and 2 rows below the fold in step 13. Later item, or leave?
- [ ] 21. Note two stale numbers in the debt text itself, already corrected in the receipt: it says "226 checks" (it is **244** after the fix round) and "656x680" (that is the **client** size; the PNG is 658x737 with the frame). Neither changes the judgement.
- [ ] 22. Write your four rulings down somewhere before you clear this — the debt text is deleted when you do.

**What would count as wrong:** finding a fifth difference nobody recorded. Say
so; that is a new item, not this debt.

```sh
tests/headless/owed.sh clear look Calculator__the_four_unexplained_drifts_item_5_recorded_and_did_.1786836736.3810800
```

---

## C. The wheel scrolls all three regions — debt `Calculator__mouse-wheel_scrolling_…`

**The question:** does one notch move a sane amount, in all three scrollable
regions, without the pointer being over a scrollbar?

**Two of the three regions ship empty**, so an aid script is required, not a
convenience: the Stack list is filled by Push/Pop, which are inert until plan
phase 4, and the Buffer opens blank. Seed them both.

- [ ] 23. In the schematic window press `=` (or `Tools ▸ Execute TCL command`). Press **`Clear Input`** if the box is not empty.
- [ ] 24. Type this one line and press **`Evaluate`**: `source /home/qflow/dev/xschem/claude_1/xschem/doc/claude/calculator_batch/eyeball/seed_calc_regions.tcl`
- [ ] 25. The result pane must report `seeded: stack = 12 rows, buffer = 12 display lines`. If it says the Calculator is not open, open it first and re-run.
- [ ] 26. Put the pointer **inside the Stack list** — not on its scrollbar, not on a button — and roll one notch. It must move 5 rows of the 12.
- [ ] 27. Put the pointer over the Stack's **Push / Pop / Del / Recall buttons** and roll. It must scroll the list behind them. The wheel over a button doing nothing is what this debt was filed about.
- [ ] 28. Put the pointer **inside the Buffer text** and roll one notch. It must move about 50 pixels — roughly a quarter of the seeded 12 lines.
- [ ] 29. Hold **Shift** and roll in the Buffer. It must scroll sideways; the seeded lines are deliberately wider than the pane.
- [ ] 30. Put the pointer over the **ten-button row under the buffer** (Enter, Pop, Swap, Roll, ClrBuf, ClrStk, M+, ME, Undo, Redo) and roll. It must scroll the buffer. Try more than one of the ten.
- [ ] 31. Switch the function browser's category combobox to **`All`** with the mouse. You need this: in the default `Special Functions` the whole list is one notch tall, which tells you nothing about step size. Do not try to reach the combobox with the wheel — ttk comboboxes are deliberately left out of the wheel walk, because there the wheel would change the *value*.
- [ ] 32. Put the pointer **inside the function list** and roll. It must scroll; a canvas has no wheel binding of its own in Tk, so this region was genuinely dead before item 13.
- [ ] 33. Hold **Shift** and roll in the function list. It must scroll sideways — that is how you reach the columns step 13 said were off the edge.

**What would count as wrong:** any of the positions above doing nothing; a notch
that jumps a whole page; Shift-wheel scrolling vertically.

```sh
tests/headless/owed.sh clear look Calculator__mouse-wheel_scrolling_in_all_three_regions.1786808599.1970846
```

---

## D. The wheel FEEL after the item-13 review — debt `Calculator_wheel_FEEL_after_the_item-13_review_…`

**The question:** the review changed two things a suite cannot judge. Do they
feel right?

Keep the seeded window from section C, and keep the category on **`All`** — this
is the only category with enough travel to feel a step at all.

**Read this before the first roll, because it changes what you are judging.**
The wheel walk binds the function list's **scrollbar** as well, and a widget
binding shadows Tk's class binding. So the scrollbar and the list run the *same
code* and cannot disagree. You are not checking whether they match — they always
will. You are ruling on the one step they share.

- [ ] 34. Roll one notch **down** with the pointer in the function list. It moves 0.13 of the list — three canvas units, about 47 pixels.
- [ ] 35. Roll a few more notches down, then back up to the top. Judge the step: comfortable, or a crawl?
- [ ] 36. Roll one notch with the pointer **over the function list's vertical scrollbar** (at the right of the Functions pane). It moves the same 0.13. If you have already rolled to the bottom, roll **up** — a notch down at the bottom moves nothing, and that is the list being at its end, not a dead scrollbar.
- [ ] 37. **Rule on the step size.** Tk's own default for a wheel over a scrollbar is **5** canvas units — 0.22 of the `All` list. The Calculator uses **3** — 0.13. Say whether 3 is right, or should be 5.
- [ ] 38. Two things worth knowing before you rule. The other two regions inherit Tk's own defaults exactly — the Stack's 5 rows is Tk's Listbox default, the Buffer's 50 pixels is Tk's Text default. A canvas has no Tk default, so 3 is the one number here that was chosen rather than inherited.
- [ ] 39. And ignore one line in the debt text: it says the list and the scrollbar "measured 0.2206 both ways". That was measured in `Special Functions`, where the whole list is one notch tall, so both readings are just the travel running out. It is not evidence that 3 equals 5.
- [ ] 40. Roll with the pointer on the **"Functions" title strip** — the caption row at the top of the pane, and the padding around it. The list must scroll.
- [ ] 41. Roll on the **"Buffer"** title strip. The buffer must scroll.
- [ ] 42. Roll on the **"Stack"** title strip. The stack must scroll — this is judgeable only because section C seeded it; without the seed the list is empty and a working wheel and a dead one look identical.
- [ ] 43. Judge the whole change: those three strips were 16% / 25% / 11% of each pane's visible area and were dead space to the wheel. Does making them live read as correct, or does scrolling from a caption feel wrong?

**What would count as wrong:** a title strip that still does nothing; a notch
that jumps a whole page, or that takes ten rolls to cross the list.

```sh
tests/headless/owed.sh clear look Calculator_wheel_FEEL_after_the_item-13_review__fn-browser_step_.1786812495.2024267
```

---

## E. The U7 refusal, and the four Results Dir labels — debt `calculator_U7_refusal___Results_Dir_label_forms`

**The question:** does the refusal read as a menu path rather than as boxes, and
do the row's four provenance labels fit beside a real path?

Still launch 1, and it matters that this window has **no ASE-L session** — that
is what selects the U7 sentence.

- [ ] 44. Look at the Results Dir row as it stands: the label reads `Results Dir:` and the field reads `(no raw file loaded)`.
- [ ] 45. Press **Eval** on the mode strip. Read the status line along the bottom of the Calculator.
- [ ] 46. It must read: *"No simulation results are loaded. Run a simulation, or pick an existing one with ASE-L ▸ Results ▸ Select."* — 106 characters. The two `▸` must be real arrow glyphs, not empty boxes.
- [ ] 47. Judge it as a menu path. Does `ASE-L ▸ Results ▸ Select` tell you where to go, and can you find that menu from here?
- [ ] 48. Note that it does not all fit: 87 of the 106 characters show, cut after `…existing one with ASE-L `. Widening the window to about 778 px shows the whole thing. That overflow is issue **0517**, already filed — section G is where you rule on it. Do not report it twice.
- [ ] 49. Now the four label forms. Press `=` again, press **`Clear Input`**, type this one line and press **`Evaluate`**: `source /home/qflow/dev/xschem/claude_1/xschem/doc/claude/calculator_batch/eyeball/u7_label_forms.tcl`
- [ ] 50. A small pad opens low on the screen, lined up with the Calculator's left edge. It has four label buttons, a `press Eval` button, and a real path in an entry.
- [ ] 51. Press each of the four label buttons in turn and read the Results Dir row: `Results Dir (ASE-L session):`, `Results Dir (waveform viewer):`, `Results Dir (unavailable):`, then plain `Results Dir:`.
- [ ] 52. Judge whether each label **leaves enough room for the path beside it**. Only about 45 to 50 characters of path fit next to the longer ones, and the cut is at the right-hand end, so the file name goes first.
- [ ] 53. The numbers, if you want them: the row is 644 px. `Results Dir:` takes 85 px, `(ASE-L session):` 196, and `(waveform viewer):` — the longest — 221, leaving 357.
- [ ] 54. The pad's own note names two things so you do not read them as defects: `(unavailable):` deliberately replaces the path with a sentence of its own, and `(waveform viewer):` is **synthetic** — no real sequence in xschem reaches it, and it is on the pad only so the four strings can be compared.
- [ ] 55. Press the pad's **press Eval** button. The row snaps back to `Results Dir:` / `(no raw file loaded)`. That is correct: Eval re-resolves the real world before it speaks.
- [ ] 56. Close the pad window when you are done. Nothing else changes, and the section-C seeding survives.

**What would count as wrong:** `▸` rendering as a box; a label that does not say
whose result it is; a path cut so hard at the default window size that you
cannot tell which file the row means.

```sh
tests/headless/owed.sh clear look calculator_U7_refusal___Results_Dir_label_forms.1787247321.189995
```

---

## F. ASE-L's `Tools ▸ Calculator` is no longer greyed out — debt `ASE-L_Tools___Calculator_is_no_longer_greyed_out`

**The question:** the tool you actually work in was the one place the Calculator
stayed disabled. Is it live now, and does it open the Calculator?

Quit launch 1. This section needs a **registered cellview**, which is what the
Cadence-style rc supplies.

- [ ] 57. Start launch 2 from the repo root: `./src/xschem --script src/cadence_style_rc`. The Library Manager opens by itself.
- [ ] 58. In the Library Manager pick library **`examples`**, cell **`TwoStageAmp`**, view **`schematic`**, and open it. The schematic must appear in the editor window.
- [ ] 59. In the schematic window choose `Tools ▸ Launch ASE-L`. A window appears titled `Analog Sim Environment TwoStageAmp (unsaved)` — the `(unsaved)` is normal for a session you have not saved.
- [ ] 60. Open that window's **Tools** menu. It has exactly two entries: `Waveform Viewer` and `Calculator`.
- [ ] 61. `Calculator` must be **live, not greyed**. A greyed entry here is the original defect coming back.
- [ ] 62. Click it. The Calculator must open.
- [ ] 63. Click it a **second** time. It must **raise the same window**, not open a second Calculator. There is one Calculator per xschem, on purpose.
- [ ] 64. Say whether a Tools menu of two entries reads as finished, or as though something is missing beside them.

**What would count as wrong:** the entry greyed; the entry live but doing
nothing; a second Calculator window appearing on the second click.

```sh
tests/headless/owed.sh clear look ASE-L_Tools___Calculator_is_no_longer_greyed_out.1786808599.1970868
```

---

## G. The no-viewer sentence — a RULING, not a look — debt `calculator_R503f_no-viewer_refusal_sentence`

**This section is different from every other one here, and deliberately so.**

The debt asks you to read a sentence and judge two things: that its glyphs are
real, and that it is not truncated. **Both were already answered by
measurement**, so there is nothing left for an eye to settle. The em-dash and
both `▸` were captured as real glyphs. And the truncation does not need a
judgement either — it fails outright: the sentence is 264 characters / 1855 px
inside a 613 px entry, only 609 px of which render text, so **84 characters
show** and it is cut at *"the session's vie"*. Showing it whole would need a
1902 px window.

A second thing has moved under it. The sentence explains a lookup that **your
own ruling of 2026-08-20 turned into rework** — the ASE-L *session* owns the
result, so neither "the viewer windows" nor "the current context" is the right
place to look. That is issue **0516**, RULED and awaiting implementation. Do
not re-report it.

So what is wanted from you here is **a ruling on the length budget**, filed as
issue **0517**: of 287 user-facing strings, **four** overflow the status entry,
at 3.05x, 1.61x, 1.58x and 1.20x the 609 px it renders. This is the worst of the
four.

- [ ] 65. Read the sentence as it stands: *"The ASE-L session has no waveform viewer, and the Calculator reads the session's viewer — a result selected while the session has no viewer is not visible here. Run a simulation, or open the session's waveforms and then pick a result with ASE-L ▸ Results ▸ Select."*
- [ ] 66. **Rule on the budget.** Pick one: (a) hard-cap every status string at what the shipped window shows, and rewrite the four; (b) let the status entry wrap or grow so long sentences are readable; (c) leave it — a cut sentence is acceptable because the full text is in the row's tooltip.
- [ ] 67. If you pick (a), say what the cap should be — 84 characters is what fits today at the shipped 656x680.
- [ ] 68. Optional, and it costs nothing because launch 2 is already this world: in the ASE-L window from section F, **do not** open the Waveform Viewer; open the Calculator from its Tools menu and press **Eval**. That is the sentence, truncated, on screen. A session *with* a viewer gives the section-E sentence instead — the two come from different arms of the same chooser.
- [ ] 69. Record your ruling in issue `doc/claude/issues/0517-four-ase-l-result-sentences-overflow-the-status-entry.md`, then clear the debt as **answered**, not as looked-at.

```sh
tests/headless/owed.sh clear look calculator_R503f_no-viewer_refusal_sentence.1787252113.268210
```

---

## H. The Results Dir row names a neighbouring raw, and says whose — debt `Calculator__Results_Dir_row_shows_a_NEIGHBOURING_raw_…`

**The question:** open the Calculator from the schematic window while a
*different* window holds a result — does the row name that result, and does it
say where it came from?

This is the original item-13 report: the row said `(no raw file loaded)` while
the user was looking at waveforms in another window. No simulator is needed —
the `.raw` this uses is already on disk.

- [ ] 70. Quit launch 2. Start launch 3 from the repo root: `./sky130A/run.sh`.
- [ ] 71. In the Library Manager open library **`sky130_tests`**, cell **`test_nfet_final`**, view **`schematic`**.
- [ ] 72. `Tools ▸ Launch ASE-L` on that schematic.
- [ ] 73. **In the ASE-L window, open `Tools ▸ Waveform Viewer` FIRST.** Order matters: with no viewer open, a selection lands somewhere the Calculator does not read, and the row stays empty. That is issue **0516**, already filed — if you meet it, it is not a new bug.
- [ ] 74. Now `Results ▸ Select…`. In the Path box enter `/home/qflow/.xschem/simulations/test_nfet_final_ase.raw` and select it. The waveforms load.
- [ ] 75. Go to the **schematic** window — not the ASE-L window — and open `Tools ▸ Calculator`.
- [ ] 76. The Results Dir row must name **that** path, chosen in a different window, and the label must read `Results Dir (ASE-L session):`.
- [ ] 77. Expect the path to be cut: 51 of its 55 characters show, ending `…test_nfet_final_ase` with the `.raw` off the right-hand edge. Say whether that is enough to know which file you are about to compute against.
- [ ] 78. Judge the label. Does "(ASE-L session)" tell you *whose* result it is, or is it jargon? This is the wording no check can settle.
- [ ] 79. Hover the path field. The balloon must give the full path and name the session — that is where the detail the row cannot fit is supposed to live. Say whether a hover is a good enough home for it.
- [ ] 80. Now close the ASE-L session while the Calculator is open. The row keeps showing the old path: that is issue **0518**, already filed. Do not re-report it — but do say whether a stale row is tolerable in the meantime.

**What would count as wrong:** the row reading `(no raw file loaded)` at step 76
when a viewer plainly holds a result; a label that names no source; a balloon
that does not appear.

```sh
tests/headless/owed.sh clear look Calculator__Results_Dir_row_shows_a_NEIGHBOURING_raw__and_says_w.1786808599.1970857
```

---

## Finish

- [ ] 81. Run `tests/headless/owed.sh list` and confirm no Calculator debt remains in the look list.
- [ ] 82. Five suite debts also sit in `owed.sh list`, three of them the Calculator's own — `test_ase_window`, `test_calc_skeleton`, `test_calc_widgets`. Those are a **different list**: they pay themselves on a green `:0` run, and `tests/headless/owed.sh drain` is what runs them. Nothing in this document touches them.
- [ ] 83. Report anything that read badly. That is a follow-up item, not a sign-off.

---

## What a look debt is *not*

- **A green suite does not discharge one.** Every line above exists because a
  passing check could not see it. The Calculator's suites were green through all
  eight of these.
- **`owed.sh drain` never reads this list.** It runs the *suite* debts and
  nothing else. There is no command that converts a look debt into a suite debt
  or pays one with the other.
- **Only your own `clear` closes a line.** Not a commit, not a receipt, not an
  audit, and not an agent. If you did not look at it — or, for section G, did
  not rule on it — it is still owed.
- **Already-filed defects are not sign-off failures.** Three of them are named
  inline above so you can recognise them and move on: **0516** (a selection made
  with no viewer open is invisible to the Calculator), **0517** (four sentences
  overflow the status entry), **0518** (the Results Dir row goes stale when the
  session closes).
