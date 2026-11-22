# Receipt: item 02, the two open items of issue 1657

> **Driver's note, 2026-11-22 07:30.** This receipt was written in the clone before the
> item landed. Since then:
>
> - The commit is in the main tree `/home/analog/dev/xschem-claude` as `dcd53b124`
>   (cherry-pick of the clone's `ea60e07a0`). One document conflicted with the items
>   that landed in between and was merged by hand keeping every entry: in
>   `doc/claude/FAQ.md` this item's two entries are **Q99** (the noise totals) and
>   **Q98** (the deck preview) in the main tree; where this receipt says "FAQ Q97" read
>   Q98. The other 22 files are the gated ones. Not pushed.
> - The main tree is rebuilt (`make -C src`, rc 0). To try section 2, start
>   `/home/analog/dev/xschem-claude/src/xschem` (close any xschem of that tree that is
>   open first), not the clone.
> - The two small text errors of section 5 are corrected in a follow-up commit in the
>   main tree (the comment above `ase::ui::optsheet_preview`; the issue file now names
>   R14 to R18).
> - Debts filed from the main tree (`tests/headless/owed.sh show`), the receipt's two
>   looks in one entry and its eleven rulings in five: look
>   `options_preview_deck_order_real_screen`; rules `opt_preview_wording` (headings,
>   the sentence, the note's two forms, tutorial and FAQ), `opt_preview_line_order`
>   (the deck's order inside a group; the sentence after "op off, then on"),
>   `raw_totals_as_op_names` (`totals_as_op`, `-asis`, the `op_run_order` hook, the
>   hook count dropped from the spec), `op_reread_makes_op_current` (the current table
>   moves; `vdc()`; the case-mode re-read), `issue_1657_cure_not_taken`.
> - The combined tree (items 03, 03b, 04 and this one) gets one full regression of its
>   own before the port; the batch's `PLAN.md` logs it.

Overnight batch of 2026-11-21. Written on 2026-11-22 from the stage reports and from the
clone `/home/analog/ob22`.

## 1. Verdict

**Done, and something has to be looked at (mark E).** Both open items of issue 1657 are
built, repaired once after review, and gated at zero counted failures. They are one commit
in `/home/analog/ob22`: **`ea60e07a0`** (parent `7b0b601b7`, 23 files, not pushed).

What you now have:

- The deck preview on the ASE-L Options sheet lists its option lines grouped by analysis,
  in the order the deck will actually run them, and says so when the operating point has
  been moved behind the other analyses.
- When a results file was loaded without naming an analysis and its noise totals were
  stored under the name `op`, a later request that names `op` now reads the file again and
  gets the real operating point, instead of being handed the noise totals.

It is E and not a clean pass because the pane's new wording and layout were only ever seen
on a private, invisible display, and because the crews chose several user-visible answers
and sentences without you (eleven rulings and two looks are listed in section 5).

The commit changes `src/save.c`, `src/scheduler.c` and `src/xschem.h`, so a tree that takes
it needs `make -C src`. `src/Makefile.in` is untouched, so no `./configure`.

## 2. What to try

### The Options preview

1. Build the clone (`make -C src` in `/home/analog/ob22`) and start it on your own screen.
2. Open a bench with an operating point and a transient enabled, for example `tb_bandgap`,
   and open ASE-L. Scope one simulator option to each analysis (for example `itl1` on the
   operating point, `itl4` on the transient).
3. Open the Simulator options sheet and read the deck preview **before any netlist
   exists**. If device operating-point numbers are being saved, one sentence in
   parentheses should stand under the slot heading, saying that the order is settled when
   the netlist is written.
4. Netlist (Netlist > Recreate). Without touching the sheet, the preview should repaint:
   a `TRAN BLOCK` group, then `OP BLOCK -- runs last in this deck`.
5. Switch the Save All tick off, or switch an analysis off and on. The open sheet should
   follow each change by itself.
6. Switch the operating point off, Netlist, then switch it back on. The parenthesised
   sentence should come back, because that netlist cannot say where the operating point
   will run.
7. Enable an s-parameter row as well, if the bench has one. The heading should then read
   `OP BLOCK -- runs after tran in this deck`, not "runs last".

**What to look at, because no check can see it:**

- Whether the group headings (`TRAN BLOCK`, `OP BLOCK -- runs last in this deck`) read well
  at two spaces in, above deck lines at four spaces in.
- The parenthesised sentence now wraps onto a second line with a deeper indent. A check
  reads only where its last character lands, not how it reads.
- The pane shows eight lines. On a bench with several option lines the operating point's
  heading is reached only by scrolling.
- Lines under `not delivered` are still not wrapped and can run past the right edge.
- The sheet repaints when it gets the keyboard focus. Flicker or delay on the Windows X
  server has not been seen by anyone.
- Scroll the pane, select some text, then click away and back with nothing changed: the
  scroll position and the selection should survive. This was seen to hold once on the
  private display, but no check holds it.

### A request for `op` on a file whose noise totals were stored as `op`

Take a noise run's raw file whose first plot is `Integrated Noise` and which also holds an
operating point. In the xschem command line:

```
xschem raw clear
xschem raw read <file>            ;# no analysis named: the noise totals are taken as op
xschem raw totals_as_op           ;# new: answers 1
xschem raw read <file> op         ;# now reads the file again, in the same slot
xschem raw info                   ;# the op table, with node voltages, not v(onoise_total)
xschem raw totals_as_op           ;# answers 0
```

Then the same starting point through the things you actually use:

- Press the Cadence annotate chord (Alt-6): the sheet should show operating-point
  voltages, not noise totals. Try it also after descending into an instance.
- In the Calculator, evaluate `vdc(out)`: it should give a value where it used to be
  refused.

What still shows the totals, on purpose (see section 5): `xschem raw switch`,
`xschem raw switch_back`, `xschem raw select <file>` with no analysis named, and
`results::select <file>` with none.

## 3. Decisions taken for you

Your rulings of 2026-11-21, one line each: the preview follows the order the deck runs;
a request that names `op` is given the operating point, and a file without noise totals
behaves as before.

### Options preview

| Hole | Chosen | Rejected |
|---|---|---|
| Order of lines inside one group | The deck's own order: the option's set lines, then the lines ASE-L adds itself, then the restore lines, last set first | Each set line beside its restore line, as before; with two options on one analysis that is not what the deck writes |
| Shape of a group heading | Two spaces in, `<TYPE> BLOCK`, then ` -- ` and the marker | The sketch's lower-case type with an arrow; a `<- put back` marker on restore lines (it would break the rule that deck lines are shown character for character) |
| "The operating point runs last" is not always true | `runs last in this deck` only when nothing follows; otherwise `runs after <analyses> in this deck`. An s-parameter analysis still runs after a moved operating point | Saying "last" unconditionally |
| Where the not-settled sentence goes | Once, in parentheses, directly under the slot heading, and only when the order can matter | Saying it always |
| The sentence is wider than the pane | Wrap that kind of line at a word, continuation indented deeper than a deck line; deck lines and headings never wrap | A horizontal scrollbar; a shorter sentence |
| Keeping an open sheet current | Repaint when the state, the held netlist block or the forced shape is written, and (added by the repair) when the sheet gets the keyboard focus; the text is replaced only if it changed | Repainting on focus only; repainting the whole sheet |
| The window and the run could read different netlist files | The order is then reported as not known, and the pane says so | Resolving the run directory from the window, which moves a global |
| A netlist written while the operating point was off, then the operating point switched on | Not known, so the sentence shows | Leaving it shown as "first" and only documenting the case |
| A dc row that sweeps a design variable | No extra words. Measured on ngspice-45.2 and on a copy of the ver_53 binary: the reload drops `option` settings and keeps `set` variables, and every option the catalogue can leave in force is one or the other in a harmless way | A second adapter hook; a vague "may not be in force" clause |
| Wording of the left-in-force note once the order is known | "...left in force for the analyses that run after it in this deck (op, sp) -- why" and "...left in force after it; no analysis runs after it in this deck -- why". While the order is unknown the sentence you reviewed is unchanged | |
| One option left in force by two analyses | Both notes are kept | One note per option name |
| Backends other than ngspice | A new optional adapter hook, `op_run_order`; a backend without it is treated as "operating point first" | |

### The `op` request

| Hole | Chosen | Rejected |
|---|---|---|
| How a script sees that a table holds totals stored as `op` | A new command, `xschem raw totals_as_op [<slot>]`; `xschem raw info` prints what it always printed | A suffix on the `raw info` line, which every parser of that line would misread |
| Putting such a table back without triggering the re-read | A new option, `xschem raw read <f> <type> -asis`; the Calculator's restore uses it | `raw switch` (it annotates as a side effect); an untyped read |
| `-asis` together with `-case <mode>` | The table stays the totals | Passing `op` on, which would defeat `-asis` |
| Where the re-read puts the table | In the same slot, and it becomes the current table, as a switch would make it. **The work order said "cursors untouched"; the build departs from that**, because a request that is given the operating point has to make it current | |
| Which sheet the re-read table belongs to | The sheet the replaced table belonged to, when that sheet is on the current hierarchy path (added by the repair) | Binding it to wherever the request came from, which made the top level lose its results after a request from inside an instance |
| A re-read that fails | Answer 0, nothing moved | Falling back to showing the totals |
| `annotate_op <file> <level> op` | Counts as naming `op` | |
| Calculator `vdc()` while the totals table is current | The table is replaced by the operating point and stays current | Reading aside and leaving the totals current |
| The annotate chord | Its first two steps (the selected table, any loaded table) ask for a read of that table's own file | Falling through to the third step, which picks a slot by hierarchy level and would read the wrong file |
| `xschem raw_read <f> <type>` followed by a case-mode change | The re-read now asks for the type that was asked. **This moves one answer for files without noise totals too** (see section 4) | |

### Documents and tests

- The adapter-authors spec no longer states how many hooks there are. The work order asked
  for the count to be updated; the project rule against numbers nothing re-checks won.
  The old heading was already wrong before this item.
- The chord checks live in `test_annot_op_behind_tran_1242`, which was given a completion
  banner and registered in the headless list only.
- `doc/xschem_man/developer_info.html` was updated although the work order did not list
  it, because it mirrors the `xschem raw` command text.
- The issue's stamp says `claim=fixed open=0`. The cure that was not taken is treated as
  your choice, not as an outstanding defect.

## 4. How it was checked

### Checks added

Every new check was run against the unchanged product first. Those meant to catch the
defect were red there; those written as controls were green there by design.

| Suite | Added | Count before -> after |
|---|---|---|
| `test_ase_core` | RO12 to RO18: the order question, the fallback for a backend without the hook, that the ngspice hook never starts the simulator (RO17), the operating-point-was-off case (RO18) | 687 -> 694 |
| `test_ase_optsheet_1441` | PV12 to PV18, PV15b (pane text); on a display UI25 to UI30 and UI25b (repaints, wrap, focus) | 64 -> 72 headless, 90 -> 105 display |
| `test_ase_run_seed` | RS10b, RS11, RS12: the window hands over the full netlist, or nothing when the run would read another file | 11 -> 14 |
| `test_ase_effective_1442` | DK10c to DK10f (line order compared with the deck actually written), SP7b (the dc-reload fact) | 97 -> 102 |
| `test_raw_ascii_point_bounds` | Band M: the mark, the re-read through each door, the cursors, failure, case mode, `-asis`, a new window, a descended sheet, a VCD or table select after a re-read, equal variable counts | 377 -> 511 |
| `test_calc_analysis_tokens` | AT15: `vdc(out)` and the restore | 98 -> 107 headless, 100 -> 112 display |
| `test_annot_op_behind_tran_1242` | R14 to R18: the annotate chord, including inside an instance; newly registered | 22 -> 30 |

### Breaking the product on purpose

The build stage broke the product 36 ways; each break reddened named checks and was put
back. Twenty-five of them reddened exactly the checks written for them. Examples: the
preview ignoring the order it is handed; the reader never marking a table; a failed
re-read answering 1; the re-read adding a slot instead of replacing.

The repair stage added seven more, and an independent stage reproduced eleven breaks from
scratch, all caught. It then tried three new ones, and **all three went unnoticed**:

1. Replacing the pane's text on every repaint (which loses scroll position and selection).
2. Letting every indented line wrap, not only the sentence.
3. Not resetting the schematic's case-mode verdict after a re-read.

The product is right in all three; what is missing is a check.

### Review

Two read-only reviews found real defects in the first build, and all were fixed in the
repair, none refuted. The main ones:

- After a re-read, a later select of a VCD or table file answered "read" where it should
  answer "switched", and a select that should be refused succeeded.
- A re-read asked from inside an instance bound the table to that instance, so the top
  level lost its results on the way back.
- `raw read <f> op -case <mode>` read the file twice.
- Several sentences in the tutorial, specs and code comments were untrue.
- Five behaviours had no check (line order in a group, the hook's purity, and others).

### Before and after

The build stage measured 176 combinations (two files, two file forms, four starting
states, eleven readers). Twenty-four moved, all on the file with totals first.
**The stage's statement that nothing moved for a file without totals is not complete.**
One answer did move, through a reader that table did not include: after
`xschem raw_read <f> <type>`, a case-mode change now re-reads the file as the type that
was asked. A file holding an operating point then a transient, asked for `tran`, used to
turn into `op` and now stays `tran`; a VCD asked for as `vcd` used to be dropped and now
stays loaded. Two checks hold this, and the issue file says it.

### Suites and arms

Sixteen related suites were run one at a time, headless and on a private display, at the
final tree; all passed, twice. Then the full regression:

```
T1-RUN-BEGIN pid=754992 ... planned_cases=229 ... home=throwaway binary=/home/analog/ob22/src/xschem
T1-RUN-END pid=754992 cases=229 blocks=228 counted_failures=0 skips=15 elapsed=1410s end=2026-11-22 07:24:47
```

Verdict file: `/home/analog/ob22/tests/results.754992.log` (I read both lines there). The
run used a private display with openbox and a throwaway home. The expected figures were
derived beforehand from the registration lists: one more case than the base's 228, because
one suite was registered. The tree that was gated is byte for byte the tree of the commit.

The 15 skipped rows are the same 15 as on the base, all rows that need a display or an
action log on the headless arm (in `test_dblclick_connected_grow`, `test_op_annot`,
`test_ase_netlist_display`, `test_device_limits`, `test_sky130_res_series`,
`test_input_line_inject_1352`, `test_preview_name_inject_1601`,
`test_generator_paren_1604`, `test_ase_dc_param_sweep`, `test_pin_marker_1724`). None
belongs to this item.

A full regression of another clone (`/home/analog/ob21`) was live during the second half
of the gate. Nothing was red, so nothing had to be run again.

### What was NOT checked

- Your real screen. Every display check ran on a private Xvfb.
- A real Netlist and Run followed by a look at the open sheet. The checks feed the preview
  the same way the product does and compare with decks the product wrote, but no simulator
  run drove it.
- How the pane looks: indentation, the wrapped sentence, long lines.
- The cost of the repaint on a very large netlist (extracted layout). The sheet also now
  keeps the whole netlist text in memory per file.
- The three unnoticed breaks above.
- Every reworded sentence in the tutorial, FAQ, specs and issue: read against the code by
  a reviewer, held by no check.
- The limit about a file whose operating point holds several points was read from the
  code, not driven.

The stages' raw evidence (logs, the 176-cell table, the ngspice measurement, a screenshot
of the wrapped sentence) is under
`/tmp/claude-1000/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/scratchpad/`
in `ovb02/`, `rep02/` and `chk02/`. That is a memory-backed directory and will not survive
a reboot; nothing from it was copied into the clone. The screenshot is
`/tmp/claude-1000/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/scratchpad/rep02/shot_notsettled.png`.

## 5. Left open

### Two small text errors still in the commit

- `src/ase_window.tcl`, the comment above `ase::ui::optsheet_preview`, still says "An
  empty slot prints nothing but its own heading". The pane prints the heading and a
  `(nothing)` line. The sentence is older than this item; I confirmed it is still there.
- The issue file's list of checks for the second item says "R14 to R17" and never names
  R18, the only check that drives the instance fix through the chord. Confirmed in the
  tree.

### Limits, by design or not fixed

- **The totals are still shown** by `xschem raw switch`, `xschem raw switch_back`, a
  `raw select` or `results::select` that names no analysis, and a graph that loads its own
  file. All of the first three also annotate the sheet with them.
- The ASE result selector passes the stored type of a loaded row, so picking such a row a
  second time replaces the totals with the operating point, while the first pick showed
  the totals.
- The Calculator's Plot door does not re-read: `vdc(...)` plotted while the totals table
  is current is refused as an unknown name. A refusal, not a wrong value.
- If the file behind such a table is gone, the annotate chord now reports that no
  operating point is loaded, where it used to annotate the totals.
- A case mode you set by hand on the totals table (`xschem raw case distinguish`) is lost
  when the re-read replaces it.
- A hand-made file whose operating point holds several points is stored as `dc` by the
  re-read; the Calculator's restore after `vdc()` from another analysis would then be
  refused.
- A netlist written while the sheet had unsaved edits is still treated as "operating point
  first" in the preview.
- A forced one-line form with more devices than one line takes is handled in the code but
  driven by no check.
- Moving the focus between widgets inside the sheet repaints the preview too; it costs
  under a millisecond and replaces nothing when unchanged.
- `doc/claude/specs/calculator.md` still describes the Calculator as always restoring your
  table; it was not updated for the `vdc()` case.
- Issue 0685 stays open as filed.

### Defects seen outside the work order (not touched)

- `test_results_select` (in no regression list): three rows red (SEL462, SEL468, SEL469)
  on both arms, identical on a build of the base commit.
- `test_raw_read_dispatch` (in no list): stalls on a display at row SC06; the base stalls
  at the same place. Headless it passes. Each stalled run leaves a
  `/tmp/xschem_emergencysave_*` directory; the stages removed their own, older ones of
  other sessions remain, and three killed runs may have left some unnamed.
- `test_ase_optier_0963`: stalls on a display after row N3, silently, at this commit and
  at the base. This is not the known intermittent failure of that suite. It is registered
  headless only, so the regression never runs that arm.
- `test_ase_dialogs` row G2sens: red on a private display, here and at the base.
- `test_ase_window` row W7: red once while other sessions' runs were live, green alone.
- The annotate chord's third step picks its slot by comparing a slot index with a
  hierarchy level.
- On a malformed header that clears a non-empty registry, the half-built table is not
  freed (read from the code).
- The header comment of `test_ase_optsheet_1441.tcl` carries old check counts.
- One older mixed-declaration warning in `src/scheduler.c`.

### Debts to file

Nothing was filed; the owed ledger was not touched by any stage.

**Look (your eyes):**

1. The Options sheet's deck preview on a real bench, on your screen: before a netlist,
   after Netlist, with Save All off. Headings, the wrapped sentence, long `not delivered`
   lines past the right edge, the eight-line pane, and whether a scrolled pane stays put.
2. The repaint when the sheet gets the keyboard focus, on your screen.

**Rule (your decision):**

1. Heading copy: `<TYPE> BLOCK`, `-- runs last in this deck`,
   `-- runs after <analyses> in this deck`.
2. The new sentence: "the op analysis runs after <analyses> when device operating-point
   numbers are saved; that is settled when the netlist is written".
3. The two new forms of the left-in-force note (section 3).
4. Lines inside a group now stand in the deck's order instead of set-beside-restore.
5. The sentence now also appears when the netlist was written with the operating point
   off and it is then switched on.
6. The reworded tutorial and FAQ Q97 sentences: what a line four spaces in means, the
   s-parameter and one-line cases, the repaint on focus, the wrapping.
7. The hook counts were removed from the adapter-authors spec rather than updated. You may
   prefer a check that derives the count.
8. The two additions to the `xschem raw` command: `totals_as_op` and `-asis`. Scripts can
   see both names.
9. Calculator `vdc()` replaces your current totals table with the operating point and
   leaves it current.
10. The re-read makes the operating point the current table, where the work order said
    the cursors stay untouched.
11. The cure not taken: an untyped read that does not store the noise totals as `op` at
    all when the file also holds an operating point. It would close every limit in the
    first bullet above, but it changes what untyped reads return. It is described in the
    issue file and not built.

## 6. Files changed

All in commit `ea60e07a0`, paths relative to `/home/analog/ob22`:

Product:

- `src/ase.tcl`
- `src/ase_window.tcl`
- `src/calculator.tcl`
- `src/save.c`
- `src/scheduler.c`
- `src/xschem.h`
- `utils/annot_mode.tcl`

Tests:

- `tests/run_regression.tcl` (one suite registered)
- `tests/headless/test_ase_core.tcl`
- `tests/headless/test_ase_optsheet_1441.tcl`
- `tests/headless/test_ase_run_seed.tcl`
- `tests/headless/test_ase_effective_1442.tcl`
- `tests/headless/test_raw_ascii_point_bounds.tcl`
- `tests/headless/test_calc_analysis_tokens.tcl`
- `tests/headless/test_annot_op_behind_tran_1242.tcl`

Documents:

- `doc/claude/issues/1657-results-are-matched-to-analysis-rows-by-position-while-the-sidecar-records-the-row.md`
- `doc/claude/issues/NUMBERING.md`
- `doc/claude/specs/ase_l.md`
- `doc/claude/specs/ase_l_adapter_authors.md`
- `doc/claude/specs/results_selection.md`
- `doc/claude/FAQ.md`
- `doc/ase_l_tutorial.html`
- `doc/xschem_man/developer_info.html`
