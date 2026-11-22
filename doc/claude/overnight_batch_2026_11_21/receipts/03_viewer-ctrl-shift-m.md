# Receipt: item 03, Ctrl-Shift-M in the waveform viewer

> **Driver's note, 2026-11-22 00:46.** This receipt was written in the clone before the
> item landed. Since then:
>
> - The commit is in the main tree `/home/analog/dev/xschem-claude` as `9eb647078`
>   (cherry-pick of the clone's `373eaf5aa`; the 18 files are byte for byte the gated
>   ones). Not pushed. The change is Tcl only, so no rebuild: to try it, start
>   `/home/analog/dev/xschem-claude/src/xschem` (close any xschem of that tree that is
>   open first). The clone `/home/analog/ob21` moves on to item 03b, so do not use it
>   for section 2. The private tree gets it through item 05's patch.
> - Debts filed from the main tree (`tests/headless/owed.sh show`): look
>   `viewer_ctrl_shift_m_real_screen`; rules `viewer_keys_focus_elsewhere`,
>   `viewer_cadence_s_swaps_cursors`, `viewer_user_binding_rows` (your own binding rows
>   and the Escape row, in one entry), `viewer_graph_use_ctrl_key`,
>   `viewer_plot_mode_menu_accel` (which also carries "the whole family is closed
>   silently" and "the target subwindow flips").
> - Two things section 5 leaves open were handed to item 03b as riders in its work
>   order: the missing test for the chord with exactly one cursor showing, and the
>   middle-button pan at a high Tk scaling (`wviewer::btn2_filter`).
> - The reds this receipt names in unregistered suites (`test_wave_sigbrowser_keys`,
>   `test_wave_axis_zoom`, `test_wave_sigbrowser_0312`) are older than the item and are
>   carried to the batch's final report.

Overnight batch of 2026-11-21. Kind: code. Base commit `f09888cda`.

## 1. Verdict

**Done, and something has to be looked at (mark E).**

The item is one commit, `373eaf5aa`, on `fluid-editing` in the clone `/home/analog/ob21`, parent `f09888cda`, not pushed.
It is not yet in `/home/analog/dev/xschem-claude` or in the private tree.
The full regression ran green on it: zero counted failures.

**What you now have.** In a waveform viewer, Ctrl-Shift-M flips the plot mode (single/multi) of the target subwindow instead of bringing up "View is Read Only".
In the Cadence profile, plain `s` over a strip swaps cursors A and B there.
A whole family of other chords (Alt-s, Ctrl-Alt-s, Ctrl-Alt-t, Alt-b and so on) no longer reaches a schematic editing command from a viewer's plot.

**Why E and not a clean pass.** Three things:

- Nothing was seen on your Windows X server. Every key was a test key on a hidden display. A look is owed (section 5).
- One state still gives the old popup: the pointer over the viewer's plot while the keyboard focus is somewhere else, or right after a viewer opens and before the first click in its plot. This is declared, not fixed, and is the next item of the batch (03b).
- One deliberate break of the product is caught by no test: Ctrl-Shift-M made dead while exactly one cursor (A or B alone) is showing. The product is right there; the test is missing.

## 2. What to try

Your normal launch still shows the old behaviour.
To see the change, run the clone's program: `/home/analog/ob21/src/xschem`. It needs no rebuild; the change is Tcl only.

1. Open a design, run a simulation from ASE-L and open the waveform viewer.
2. **Click once in the plot.** A viewer that has just opened does not have the keyboard focus on its plot. Until that click, a viewer key either does nothing or brings up the old "View is Read Only" box, depending on where the desktop left the focus.
3. Press Ctrl-Shift-M. The status bar's `Plot: single` becomes `Plot: multi`, with no popup. Press it again and it goes back.
4. Open Options > Plot Mode. Its one entry shows `Ctrl+Shift+M` beside it.
5. With Caps Lock on, Ctrl-m does the same flip.
6. In the Cadence profile, turn on cursors A and B (`a`, `b` over a strip), then press plain `s` over a strip: the cursors swap and the readout bar follows.
7. With both cursors still on, press Ctrl-Shift-M: the mode flips, and the cursors and the readout stay as they were.
8. Press Alt-s, Ctrl-Alt-s or Ctrl-Alt-t in the plot: nothing happens. Before, these gave the reload prompt, the Save-as-symbol form and a new schematic tab.

**What to look at, since no test can see it:**

- Whether the physical chord arrives at all on your Windows X server, with and without Caps Lock, and whether Alt reaches the viewer.
- How `Ctrl+Shift+M` looks on the nested menu entry, and how the status bar looks when the mode flips.
- That cursor B, a marker and the readout text are drawn in the right place in the right-hand subwindow, on a second tab, in a second viewer window, and after you resize or maximise the viewer. The tests check that the key reached the plot and what the plot was told, not the pixels.
- Before step 2: move the pointer into the plot without clicking, press Ctrl-Shift-M and note which of three things happens (nothing, the read-only box, or the flip). This tells item 03b what your desktop does.

One state still gives the old popup, by decision: pointer resting over the viewer's plot while the keyboard focus is in the schematic window, for example after Alt-Tab without moving the mouse.

## 3. Decisions taken for you

**Your rulings of 2026-11-21.** Only one applies to this item: an item that gates green lands as its own local commit on `fluid-editing`, and nothing is pushed.

The first receipt of this item called several of the decisions below your rulings. That was wrong. The work order carries them as "Decided by the lead", for you to confirm or overrule.

**Decided by the lead, in the work order:**

- **The whole family is closed, not only Ctrl-Shift-M, and closed silently.** A chord the viewer does not use does nothing. Rejected: curing the one reported chord.
- **Cadence `s` swaps the cursors in a viewer only.** Over a graph embedded in an ordinary schematic every key does what it did before, in both profiles.
- **The target subwindow flips,** not the one under the pointer.
- **Keyboard focus is out of scope.** The chord works where the viewer's other chords work, that is, with the focus on the plot.
- **`graph_use_ctrl_key` set:** Ctrl-Shift-M is the plot mode there too, unconditionally.
- **Extra modifiers are accepted.** Ctrl-Alt-Shift-M runs the flip, as Ctrl-Alt-D already runs Clear All.
- **No echo line** in the command window; the status bar shows the mode.
- **No new tip-of-the-day question.**
- **The shortcut in the menu** was left to the crew, on a condition about the tests (next list).

**Holes the crews filled:**

- **The menu entry shows the shortcut.** Options > Plot Mode carries `Ctrl+Shift+M`. Rejected: a key documented in the guide with no menu hint.
- **How the viewer decides which keys go to the graph.** It reads the program's live key-binding table on each graph key, plus a short list of the graph cases built into the key handler; a test re-derives that list from `src/callback.c` on every run. Rejected: a fixed list of keys and modifiers, which leaves your own binding rows for bare `m`, `s`, Shift-M or Ctrl-m running editor commands from a viewer.
- **Your own binding rows.** A row of yours bound for the schematic canvas (or globally) on a graph key no longer runs from a viewer. A row for the graph context is honoured only if its action is the plain "forward to the graph" one. Rejected: forwarding any graph-context row, which would let an editor action run in a viewer.
- **Ctrl-b, Ctrl-d and Ctrl-Shift-M are refused by name.** They are the viewer's own shortcuts (Signal Browser, Clear All, plot mode). A "forward to the graph" row of yours for one of them is ignored inside a viewer, as it was for Ctrl-b and Ctrl-d before this item; over an embedded graph it still works. Rejected: asking Tk at run time which chords the viewer binds.
- **Escape with a row of yours for Escape in the binding table.** The viewer then aborts through the program's own abort command and does not run your row. Without such a row (every shipped configuration, and yours today) Escape behaves as before. Rejected: leaving it and only correcting the guide.
- **`graph_use_ctrl_key` set, bare keys.** A bare graph key then does nothing in a viewer (before: it ran editor commands, the read-only box for `b` and `t`). Control chords still go to the graph. In that mode cursor A, cursor B, the delta marker and the measurement tooltip have no key in a viewer; three of the four were already so, and the guide now names them without a count. Rejected: sending the bare key on as its Control chord. With the Cadence profile set as well, plain `s` is refused and Ctrl-s swaps.
- **Which pixel decides.** The key event's own pixel, which must be inside a strip by the program's border plus one pixel (8 pixels on the test display, more on a display that scales more). The old test on the last known mouse position is dropped for graph keys. Rejected: the fixed 8-pixel inset, which is too small above a Tk scaling of 1.6.
- **One chord the program would give the graph is refused in a viewer:** `t` with Control plus a further modifier that is neither Alt nor Super (or a held middle or right button). Declared as a limit. Rejected: a special case for it.
- **The focus problem is declared, not fixed.** It is documented in the guide and the spec and held by two tests that assert today's behaviour, so they turn red the day somebody fixes it. Rejected: a guard in the central event handler `callback()`, which changes what every key does in that state and could not be checked in a repair round; and making `wviewer::open` focus the plot, which is yours to rule on.
- **Guide wording.** Section 9.3 says what the viewer refuses, that `s` swaps in the Cadence profile, and that Ctrl-m also makes a marker; it says "no key typed into a viewer's plot" reaches an editing command. Two troubleshooting rows were added.
- **Where tests went, and what was not registered.** The embedded-graph fence went into the registered `test_wave_viewer` instead of the unregistered `test_key_graph_context`. `test_wave_sigbrowser_keys` and `test_wave_sigbrowser_i12` stay unregistered: the first has three standing reds that are not this item's.
- **No issue was filed and no number minted.** Issue 0186 got a dated note.

**Decided in the second run** (tests only; the product did not change):

- **The resize test grows the window** by 200 pixels and presses at a pixel below every strip the plot had before, then puts the window back. Rejected: shrinking it, or pressing on the old seam, which only tells a stale answer from a fresh one by luck.
- **Tests for a second viewer and for the chord with cursors showing were added on both arms,** not only on the display arm as asked. Rejected: display tests only, which would leave three breaks invisible on the windowless arm.
- **The Cadence-profile test takes the readout bar down and puts it back,** rescanning its own trace pixels and asserting the plot is as tall as before. Rejected: leaving the bar up (the break would not show), or rescanning for every later test.

## 4. How it was checked

**The item took two runs.**
The first run built the change and repaired it three times. Its product was measured right in every situation anyone tried, with a real pointer and real keys.
It ended with nothing committed because of the tests, not the behaviour: its third attack round built deliberate breaks of the product, and eight of them, in six groups, were caught by no test. The batch's rule is that such a break blocks the item, and the repair rounds were used up.
The second run closed it out: it wrote the missing tests (one commit, touching two test files and two spec lists, no product file), had them checked by a fresh reader, ran the full regression and made the commit.

**Before the change, measured on a private display with real keys:** Ctrl-Shift-M and Caps Lock + Ctrl-m gave the "View is Read Only" box; plain `s` in the Cadence profile the same; Alt-s and Super-s the reload prompt; Ctrl-Alt-s the Save-as-symbol form; Ctrl-Alt-t a new schematic tab; Alt-b and Super-b stepped `hide_symbols`; a graph key just inside a strip's edge ran the canvas command.

**Tests added** (no registration changed; every suite that got tests was already registered):

- `tests/headless/test_wave_viewer.tcl`, display arm, real key events: rows KM0 to KM15 and G1f. KM1 the chord over a strip; KM2 Shift-M, `m`, Ctrl-m, `d`, and the cursor keys, in both profiles; KM3 two subwindows; KM4 and KM5 Caps Lock and Num Lock; KM6 a second tab, graph keys included; KM7 the cursor swap, and the chord with both cursors on; KM8 graph keys with Alt, Super and mixes; KM9 the strip edge, two subwindows side by side, and after a resize; KM10 `graph_use_ctrl_key`; KM11 your own binding rows and Escape; KM12 embedded graphs unchanged; KM13 every forwarded chord sent as a real key in four profiles; KM15 two viewer windows; KM14 and G1f the two declared focus limits.
- `tests/headless/test_wave_subwindows.tcl`, both arms: SWK19 to SWK25 and SWK27 to SWK29, SWK26 on the display arm. They hold the decision procedures and compare the viewer's copies of program facts with `src/callback.c` read as text on every run.
- `tests/headless/test_wave_grid.tcl`: the key census and the menu shortcut (GH0 to GH6).
- New shared helper `tests/headless/wvkey_engine.tcl`.

**Red first.** The first run's tests were red on the unchanged product, except the ones that are controls or fences by design. The tests added later in `test_wave_viewer` cannot be shown red on the unchanged product, because the suite stops early there; their only proof is the break each exists for. The three checks the second run added to `test_wave_subwindows` were red on the unchanged product on both arms.

**Breaks of the product.** The first run built several dozen across its rounds; the table of which break reddens which rows is in the headers of the two test files. The eight breaks that had passed everything were rebuilt in the second run, twice (by the repair and by its checker), and each now reddens exactly the row named:

| break of the product | red in `test_wave_viewer` | red in `test_wave_subwindows` (both arms) |
|---|---|---|
| graph keys dead in the right-hand subwindow | KM9 | SWK27 |
| graph keys dead on every tab but the first | KM6 | not caught |
| strip pixels remembered across a resize | KM9 | SWK27 |
| graph keys dead in a second viewer window | KM15 | SWK27 |
| the chord in the second viewer flips the first | KM15 | SWK19 |
| the chord dead while both cursors show | KM7 | SWK19 |
| Cadence profile: `m`, Ctrl-m, `d` make no marker | KM2 | not caught |
| Cadence profile: `a`/`b` do not bring up the readout | KM2 | not caught |

The checker then built seven breaks of its own. Six were caught (three of them on the display arm only). One was not: the chord made dead while exactly one cursor shows (section 5).

**Suites at the final tree, run by the checker** (through `run_suites.sh`, private display with openbox):

| suite | no window (`--nogui`) | display |
|---|---|---|
| test_wave_viewer | 59 | 516 (519 with an action log, the full regression's arm) |
| test_wave_subwindows | 280 | 576 |
| test_wave_grid | 432 | 680 |
| test_wave_sigbrowser | 154 | 373 |
| test_wave_sigbrowser_i12 (unregistered) | 40 | 126 |

All pass. `test_wave_sigbrowser_keys` (unregistered) is red as it was before the item (section 5).
The first run also saw green, on the product as it still is: test_startup_quiz, test_wave_tabs, test_wave_modes, test_wave_clear_all, test_issue_stamp, test_key_graph_context (display) and test_wave_sigbrowser_panes. These were not run again in the second run, since no product file changed.

**End to end, first run.** The clone was launched as `sky130A/run.sh` does, with real keys: after one click in the plot, Ctrl-Shift-M gives multi, the status bar follows, one log line, no box. A sweep of 390 real chords typed into the plot in the Cadence profile handed the program only Escape and the graph chords; no box, form or new window appeared.

**The gate.** One full regression in `/home/analog/ob21`, on a private display (Xvfb `:100`, openbox), 2026-11-22 00:11:59 to 00:39:02. It ran on the last work-in-progress head, whose tree is the tree of commit `373eaf5aa`. It ran once.

```
T1-RUN-END pid=3819655 cases=225 blocks=224 counted_failures=0 skips=13 elapsed=1623s end=2026-11-22 00:39:02
```

Verdict file: `/home/analog/ob21/tests/results.3819655.log`, 679 lines. I read its first and last lines; they are that run's.
The numbers were derived before the run from the registration lists (225 cases, 224 blocks, 13 skips) and the run agreed. They are the batch's baseline numbers, and the 13 skipped rows are the baseline's, all of them rows that need a display or a dialog on the windowless arm; none is this item's.
No other run was announced in the clone. Runs of other sessions were live in two other checkouts when it started and were not waited for.
Check counts that moved, all in this item's suites: `test_wave_viewer` display 440 to 519; `test_wave_subwindows` 250 to 280 and display 544 to 576; `test_wave_grid` 429 to 432 and display 672 to 680.

**Not checked:**

- Anything on your Windows X server: how the physical chord arrives, Caps Lock, Num Lock, whether Alt reaches the viewer, how the shortcut looks in the nested menu, where the focus lands after a viewer opens.
- Pixels in the new situations (right-hand subwindow, second tab, second viewer, after a resize). The tests read what the plot was told, the marker count and the label text.
- A resize by hand: a drag of the border or a maximise. The test grows the window once by command and puts it back.
- A real key or mouse button on a display with Tk scaling above 1.6.
- `test_wave_markers`, the suite with the most tests on these keys (issue 1488 keeps it out), neither before nor after.
- The graph effect of `t`, Shift-A, Shift-B, Ctrl-t, Ctrl-Shift-A, Ctrl-Shift-B and a typed Ctrl-s: tests check they are forwarded and harm nothing, not what they do.
- Whether a binding-table row of yours for a mouse button or the wheel can run from a viewer.
- Two of the second-viewer breaks were never measured on a quiet machine; another checkout had a run live each time. The red rows and values were the same in every run.

## 5. Left open

**Gaps in the tests** (the product was measured right in each):

- **Ctrl-Shift-M with exactly one cursor showing.** A break that makes the chord dead with cursor A alone or B alone passes every suite. The tests press it with no cursor and with both. One more leg of SWK19, answering the cursor state as A only, B only and both, would close it on both arms.
- **Three breaks are caught on the display arm only:** graph keys dead on other tabs, and the two Cadence-profile breaks. Each needs a real viewer behind it. The header of `test_wave_subwindows` says so.

**Problems not fixed in the product:**

- **The focus state** (the popup you reported, through another door). Pointer over the viewer's plot, focus elsewhere: Ctrl-Shift-M brings up "View is Read Only" or does nothing; in the Cadence profile `s`, `w` and bare `b` bring up the box; Alt-b steps `hide_symbols`. One click in the plot ends it. It predates the item. Item 03b of the batch takes it up.
- **Middle-button pan at high scaling.** `wviewer::btn2_filter` still trims a fixed 8 pixels while the program's border grows with the Tk scaling. Measured at scaling 2.0 in the first run: a middle-button drag starting 9 pixels inside a strip pans the viewer's schematic canvas. Older than the item; a one-line repair plus a test. Candidate for an issue of its own.
- With `graph_use_ctrl_key` set, cursor A, cursor B and the delta marker have no key in a viewer. Older than the item; now written down.

**Defects seen outside the work order:**

- `test_wave_sigbrowser_keys` (unregistered): BK22 red on both arms, BK29 and BK31 on the display arm. The second run's checker confirmed the same three with the pre-item files in place.
- `test_wave_axis_zoom` (unregistered), display: CV2c red, also before the item (first run).
- `test_wave_sigbrowser_0312` (unregistered), display: BF21a and BF24a red, also before the item (first run).
- `test_startup_quiz` and `test_wave_grid` leave gitignored `*~.sch` backups under `xschem_library/` (44 in the clone); `tests/untitled~.sch` and `tests/untitled-1~.sch` are from the baseline run. Left in place.

**Corrections to the work order, as measured:** Alt-m arms a move only with `infix_interface` off; Ctrl-Alt-t opens a tab, not a window, under the tabbed interface; three rows of `test_wave_sigbrowser_keys` are red at baseline, not one; `graph_markers.md` said Shift-M's case has no Control arm, and it has.

**One process incident, first run:** a bare `./src/xschem --version` was started in the clone with `DISPLAY` set to your screen. It exited by itself, no log or `~/.xschem` file changed, and the crew believes no window was shown.

**The tree against the facts I was given:** they agree. The clone's head is `373eaf5aa` with parent `f09888cda`, 18 files, and the only uncommitted file is this receipt. The facts' build entry names `e19d5293b` as the work-in-progress commit; that was the first run's last one and is no longer on the branch.

**Debts to file** (none filed by the crews; I filed none):

- **Look.** On the Windows X server, Cadence profile, running the clone: the steps of section 2, starting with the press before the first click.
- **Rule: the focus state.** Options: (a) leave it as documented; (b) `wviewer::open` gives the plot the focus; (c) a guard in `callback()` that drops such a key or hands it to the viewer; (d) `autofocus_mainwindow 1` in the rc. Item 03b is working on this; its receipt should carry the question.
- **Rule: the menu shortcut** on Options > Plot Mode.
- **Rule: `graph_use_ctrl_key`** makes bare graph keys do nothing in a viewer and leaves the measurement tooltip without a key there.
- **Rule: your own binding-table rows** are refused in a viewer (canvas and global rows on graph keys; any row for Ctrl-b, Ctrl-d, Ctrl-Shift-M).
- **Rule: Escape** with a row of yours for Escape aborts and does not run the row.
- **Rule: Cadence `s`** swaps cursors in a viewer and still starts a wire over an embedded graph (the lead's decision; the work order asks that it be listed).

## 6. Files changed

All in `/home/analog/ob21`, commit `373eaf5aa` against `f09888cda`: 18 files, none of them yet in the main tree. No C file, no `Makefile.in`.

Product:
- `src/wave_viewer.tcl`
- `src/cadence_style_rc` (a commented remap recipe)

User documents:
- `doc/waveform_viewer_guide.html`
- `doc/ase_l_tutorial.html`

Specs and notes:
- `doc/claude/specs/waveform_viewer.md`
- `doc/claude/specs/waveform_viewer_modes.md`
- `doc/claude/specs/waveform_viewer_subwindows.md`
- `doc/claude/specs/graph_markers.md`
- `doc/claude/specs/waveform_signal_browser_two_pane.md`
- `doc/claude/code_analysis/waveform_subsystem_reference.md`
- `doc/claude/issues/0186-viewer-context-destroyed-by-reload-and-inplace-loads.md`

Tests:
- `tests/headless/test_wave_viewer.tcl`
- `tests/headless/test_wave_subwindows.tcl`
- `tests/headless/test_wave_grid.tcl`
- `tests/headless/test_wave_sigbrowser.tcl`
- `tests/headless/test_wave_sigbrowser_keys.tcl`
- `tests/headless/test_wave_sigbrowser_i12.tcl`
- `tests/headless/wvkey_engine.tcl` (new)

The second run's part of this is in four of them: the two test files `test_wave_viewer.tcl` and `test_wave_subwindows.tcl`, and the two specs `waveform_viewer.md` and `waveform_viewer_subwindows.md`.

The first run's full result: `/home/analog/dev/xschem-claude/doc/claude/overnight_batch_2026_11_21/receipts/03_viewer-ctrl-shift-m.run1.json`.

Evidence (session scratch, cleared by a reboot), all under `/tmp/claude-1000/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/scratchpad/`:
`ovb03`, `ovb03_rep1`, `ovb03_rep2`, `ovb03_rep3`, `ovb03_att3` (first run); `ovb03_r4` (the second run's repair), `ovb03_chk1` (its check), `ovb03_gate` (the regression's output and the commit message).
