# Test-writing and gate lessons

Standing lessons for anyone writing or debugging a suite, a fence, a pick mode or
Calculator code in this tree. They were condensed out of `CLAUDE.md` on 2026-11-21 so that
file could shrink; each entry is the rule only. The measurements, incidents and row-by-row
receipts behind them are in `doc/claude/claude_md_history_2026_11_21.md` (search it for the
row or proc name). Unlike that file, this one is current: correct or delete an entry when
it stops being true. Where it differs from `CLAUDE.md`, `CLAUDE.md` wins.

"Counted arm" is the `--nogui` (`hcases`) arm; "display arm" is `dcases`.

## 1. Rows that pass for the wrong reason

- **Assert the path was taken.** A "this click touches nothing" row passes when an earlier
  gate returns before the code under test is reached (`CW13`: no result was loaded, so
  `calc::eval_click` returned before reading the buffer). Add a leg proving the input was
  really parsed or the branch really entered.
- **Assert a trajectory, not an end state**, when two steps cancel (Enter pushes, Pop
  removes: the stack is 0 either way). Record the value after each press.
- **An allow-list that excuses a control by name is a standing hazard** (`CW13`'s
  `$allowed`): a proc that stops being a stub while on the list leaves the row green and
  its sentence false. Keep the claim inside the sweep, or pair an exclusion with a
  deterministic positive drive.
- **A sweep needs a riding count.** A row whose only leg is "nothing leaked" can be
  emptied to one member with no red; assert the population size too (`[mt_sized $n 9]`).
- **Write a fixture leg for any row whose comparand is a snapshot.** A band at the foot of
  a file must open what the band above closed (`calc::close`), or it compares two error
  sentinels and passes.
- **Two numbers a row compares must differ by more than its tolerance, measured when the
  row is written**, with an explicit distinctness leg. The statistic is the adjacent pair
  the row compares, not the range: a per-edge series in periodic steady state repeats to
  about 1e-11 while its range looks ample. Add a control that drives the blind columns by
  name. The mirror case: a level that puts a quantity inside the tolerance door makes a
  discrimination row red on correct code.
- **A comparand that shares the product's loop agrees with its bug.** Give the derivation
  a different mechanism (a single pass holding one open transition, not the same paired
  `foreach`).
- **A suite can pass its full count against a wrong repair of the predicate it covers**
  (`test_calc_cross` against four wrong `calc::cross_pair` tolerances). Build each
  candidate and sweep it; when all fail, leave the predicate, declare the limit and make
  the rejecting sweep a row.
- **A fixture can pre-empt the claim**: `.calc.buf edit reset` right before a click
  empties Tk's undo stack, so a one-step-undo row passes with both `edit separator` calls
  deleted. Drive "the user typed, then clicked".
- **Press the button and assert what it answers.** Reading `wm protocol $w
  WM_DELETE_WINDOW` and then destroying the window travels `<Destroy>` and never
  evaluates the close script.
- **A fence keyed to a symptom dies when something else cures the symptom.** Assert the
  correct shape rather than a wrong one's absence, and re-run the site-by-site sabotage
  after any change in the same file.
- **A band that aborts deletes its rows from the verdict and is not scored as a failure**:
  `group`'s catch turns a bare `expr` or `dict get` on a disposition word or raise
  sentinel into one `ABORTED` line. Route every verb answer through its accessor, and
  make `missing=0` under sabotage an acceptance test.
- **A green gate says nothing about what nothing asserts** (issue 1650: no registered
  suite asserted `integ()`, `deriv()`, `prev()`, `ravg()` or `avg()` on any dataset). A
  (door × fixture) 2×2 needs all four cells. Establish discrimination by building each
  sabotage, not by arguing it.
- **Read the row that already drove a guard before adding it.** Rows `SO3`/`SO4` of band
  `MT27` exist so that refusing a guard is a measurement: a guard that refuses correct
  work is the wrong direction (ADE-L is a floor; a computable answer is returned, not
  clamped). Widen the declaration instead.
- **A key and the row asserting its exact key set land in one commit**; either one alone
  is a gate red.
- **A row that chooses its subject from what the product made can choose around the
  defect.** A leg that took "the first stub whose end points are in order" passed while
  the other stub of every pair was stored end-first and no point on its middle picked it.
  Walk everything the command made and assert the shape of each (rows `L12c`–`L12h` of
  `test_dblclick_connected_grow`).
- **A universal sentence over a fixture of one kind proves the kind, not the rule.** Every
  label of a net carried one name, so "takes only the labels of the first name" passed
  every row; no label sat near a selected wire and off it, so "near counts as on" passed
  too. Give a fixture the member the rule must refuse and the member it must not care
  about (rows `LP1`–`LP4`, `LM1`).
- **`check` compares strings.** An expected list written over several lines is not `eq`
  to the list a row built: canonicalise the literal (`lrange {…} 0 end`). And an error
  string from a `pcall` can have the very length the row expects of its list
  (`ERR:invalid command name "x"` is four words): test the elements' type before
  unpacking, or a row written to fail on the unchanged product throws there instead.

- **A limitation written into a row is a defect with a fence around it** (issue 1734,
  found by the user on the first use of Plot Difference). A Direct Plot emptied a
  difference trace. The documents recorded that as a limit, and rows `GS3` and `GU4` of
  `test_ase_plot_difference_1727` asserted the empty vector as the expected answer, so
  the suite was green because the trace was blank. The row that came closest, `GS2`,
  read a difference after a second difference and passed because that one door had been
  taught not to load the results: it fenced the work-around, on the only door that had
  it. No row pressed Ctrl-4 after a difference. When a document says "X stops working
  after Y", ask whose behaviour that is before a row asserts it. After a plot, drive the
  other doors a user reaches for next (band `GA`: the real key, its clicks, its ESC), and
  read the value where the user reads it (the readout bar): "the trace is still in the
  model" was true while the strip was empty.
- **A comparand read back from the product agrees with whatever the product chose** (the
  difference's name, same report). Row `GK7` compared the CIW's *as trace '…'* with the
  vector name read out of the viewer's own model, so any name passed, `expr1` included,
  and no row said what a user reads on the legend. The name was a build's choice nobody
  had ruled. A string a user reads is asserted as a literal the row builds from its own
  inputs (band `GI`: `v(<second>)-v(<first>)`), on the surface that shows it (the strip's
  node token, the readout bar), for a name with a hierarchy path and capitals.
- **No row reads what no row was asked about, and a fresh window is one layout of many**
  (the new strip's X axis, same report; issue 1736). No row of that suite read an axis of
  any strip, and every plot landed in the layout a new viewer has: one subwindow,
  single-plot, nothing split, no strip made by a run's own plot, on a results file of a
  few points that the suite writes. The user's window, on the `tb_bandgap` bench, had
  strips from a run's plot in multi-plot. The closest row, `GK9`, asked which analysis
  the viewer shows. A plot gesture's rows compare the new strip's axes with its
  neighbours' in at least one layout a user makes (band `GZ`), and at least one band runs
  on a file a simulator wrote (`test_wave_expr_reattach_1734`, group `PV7` of
  `test_ase_plot_outputs`).
- **A zoom has two homes, and the view fixtures knew one** (same defect: its cause was
  not in Plot Difference but in the viewer's Replace). The engine's zoom lives on the
  rect; the viewer's own zoom, View > Fit and a marker write the window into the model.
  The bands that own the kept view (`PV` of `test_ase_plot_outputs`, `GZ` and `GV` of
  `test_wave_grid`) put their zoom on the rects only, by a fixture rule that says so
  ("the model is left auto"), so a stored window never met `~` or a run in multi-plot.
  The one row where a stored zoom met a Replace, `GV14` of `test_wave_grid`, had one
  strip in its subwindow and read its X only. Drive a zoom through each door that makes
  one, and read every strip, X and Y.
- **A rule written for one member is read again when a later feature gives it several**
  (same defect). "The strip a Replace leaves keeps the view" was written when a run's
  plot was one strip, and rows `SWD4` and `PO16d` asserted it on a fixture where that
  strip was the only one that came back. Multi-plot gave a run one strip per row, and
  its rows (`PO14`, `PR11`) read which trace lands in which strip and never a window: so
  the first row sat in the window stored for the last row's strip under two green
  suites. When a feature multiplies what a rule speaks of, the rule's rows are run on
  the new shape.
- **Traces of one scale cannot show a strip drawn in another's window** (same defect).
  The view fixtures' vectors all run over one range, so a strip in another strip's Y
  window still held its trace, and "the Y is some strip's fit" passed. Give the rows
  traces whose ranges differ by a large factor and assert that each strip's Y window
  holds its own trace's smallest and largest value, computed from the file's numbers
  (`PV7`, `GZ3`), not only that windows are equal to one another.
- **A screenshot is evidence about the door.** The session could not be replayed: the
  doors that made the picture write no action-log line. The picture named one all the
  same: the sweep took 0.8^4 of the X axis, which is four steps of the viewer's
  zoom-out, and the bottom strip's Y scale was the top strip's. Measure the picture
  before guessing a sequence from the log. And reconcile every picture of a report, not
  the first: the recipe that gave the first screenshot did not give the second without
  one more unlogged door (View > Fit), and the order of the strips in both said which
  door had been pressed before either (issue 1736).
- **A sentence about a thing is checked after the gesture that said it has finished**
  (the review of issue 1734's repair). "Trace '…' is empty … it draws again when …" was
  asserted after a Direct Plot and after a run's plot under Append, where the trace
  stays. Under Replace, the session's default, the same plot removes the trace a moment
  after the load has said the sentence, and no row pressed `~` with a trace that could
  not be evaluated. A row for a message drives every door that can say it, under the
  default settings first, and asserts with the sentence that its subject is still there
  (band `GG` of `test_ase_plot_difference_1727`: the sentence count and the traces left,
  per destination, per subwindow, per tab).
- **A predicate that asks the disk answers for the disk as it is now.** "A database whose
  path is no file exists in memory only" kept a Calculator table, and equally a
  file-read database whose file a run had deleted. Its rows handed the load their own
  keep list or held tables only, so the predicate never met the member it had to refuse.
  This is the "fixture of one kind" entry above again: row `RK6` of
  `test_wave_expr_reattach_1734` gives the predicate one database of each kind in one
  model, and `RV1` deletes the file under a live trace.
- **Every part of a repair has a break that turns a row red, or it has no row.** The
  review removed one line of the repair at a time and two came out with every suite
  green: the records dropped before a restore, and the walk over every tab where the
  shown tab would do. Both were decisions the crew had written down. After a repair,
  list each line that changes behaviour and build the break for each; a sabotage list
  that covers the bands and not the parts leaves this open. The fixtures said why: every
  restore row closed the window first, which drops the records anyway, and every
  Calculator-wave row had one tab.
- **Two orders that agree on the fixture do not say which one the product follows.** Two
  traces computed into one vector draw the expression computed last. A load that took
  "the first in the strips" was wrong, and "the last in the strips" passes a row whose
  later trace also stands later. Give the pair both arrangements (rows `RC4` and `RC5`).
- **A row that fences an economy needs the row where the cheap test and the thing it
  stands for part ways** (the second review of issue 1734's repair). Undo evaluated "the
  vectors the data lacks", and row `RU3` fenced exactly that: nothing else is computed.
  "The data lists the name" stood for "the data holds this trace's vector", and the two
  part ways once a name is handed out again: the trace leaves, a load makes no vector
  for it, a later trace is computed into the free name, undo brings the first one back.
  Its label then stood over the later trace's numbers. `RU3`'s fixture could not show
  it, because every vector there had one owner from start to end. For a skip of the form
  "it is already there", write three more rows beside the fence: the same name with
  other content (`RS1`, `RU5`, `GG14`), what was computed from it (`RS3`, `RU7`), and
  the case where it cannot be rebuilt and must not be left standing (`RS4`, `GG15`). And
  ask of every per-name record what it says once the name has had two owners: the
  analysis on record for the vector was the later trace's (`RS5`, `GG16`).
- **A row added to hold a second direction is red on the unchanged product only if it
  holds the first too.** "After redo the later trace reads its own nets" is green on the
  product that never evaluated at undo, because the vector was never touched. Put the
  undo reading and the redo reading in one row (`GG14`, `GG15`), or the redo row passes
  red-first's test of nothing.
- **Two mechanisms that each give a behaviour hide the removal of either.** The
  tip-of-the-day window kept its size both by a remembered largest size and by keeping
  the size it has; with either taken out every row stayed green (issue 1739). When a
  deliberate break stays green, look for the second mechanism before adding a row, and
  then remove one of the two or break both at once (the suite header's "the size left to
  Tk and no minimum size").

- **Two things that agree because both hit a wall do not agree.** Row `S25` of
  `test_calc_skeleton` asserted that one wheel notch over the function list's scrollbar moves
  it as far as Tk's own binding, and a comment recorded the two figures as equal "to the last
  digit". They were equal because the list could scroll less than three units in all, so 3
  units and Tk's 5 both stopped at its end. Six more catalogue entries gave the list one more
  row and the row went red on a change that touched no wheel code (issue 1760). When two
  measured numbers are equal, check that neither is the end of its range: drive the same
  comparison where there is room left.
- **An expected number derived from the formula is not the number the product owes when the
  product works on samples.** `ymax` at a window limit between two samples of `x(5-x)` owes
  the straight line between them (5.7), not the parabola (5.76); the row was wrong and the
  product right (issue 1760, row `EVD8`). Derive from what the samples are.
- **A row that compares against the product's own helper does not see that helper break.** A
  refusal was asserted equal to a sentence built with `calc::nest_say`, the proc that drops
  the translator's opening words; with that proc made to do nothing both sides kept the
  words and the row stayed green. One literal a user reads, beside the built comparands,
  turned the break red (row `EVA6`).

- **A row can hold a known limitation as its expected value.** Three rows of
  `test_ase_simdlg_0937` (`S22`, `S32`, `S45`) expected the bottom bar of one session window
  to name the simulator picked in another, or picked from the Command window; `S45`'s own
  comment called that "the known limitation recorded as D5" and added "the run resolves it".
  They went red the day the bar was made to name what its own run starts (issue 1762), and
  were right to. When a surface is supposed to predict something, assert it against the
  thing it predicts (here: what the run's own step puts in force), and when a repair closes
  a limitation, look for the rows that were written against it.
- **A refresh nobody asked for hides a stale label.** With the per-session bar taken out
  again, the rows that read a bar straight after another window opened stayed green: the
  label widget still held the text of its last repaint, which happened to be right. Only
  the row that repaints every bar first (`BS11`) saw it. Read a label after the repaint a
  user's next gesture causes, not only as it was left.
- **An event the window manager sends can do the job of the code a row is about.** Three
  of the four marks behind "the session used last" (issue 1764: opening a window, a launch
  raising it, closing one) were each also made by the keyboard focus the window manager
  hands over at that moment, so the row stayed green with any one of them taken out. Ask
  before the event loop turns (the opening), take the binding off the window first (the
  raise), or read the record itself (the close): rows `RK5` and `RK6`.
- **A row that fails by ending the suite names nothing.** Helpers that ask about a window
  answer a word for a missing one (`NOBROWSER`, `NOFORM`) instead of raising, so the row
  that asked is the red one (five breaks of `test_ase_save_browse_1763` ended the suite
  until its helpers did).
- **A reference read through the code under test moves with the break.** Row `I3c` of
  `test_selection_dim_1769` compared a highlight's pixel with "its own colour", read a few
  lines earlier by highlighting the same net: a break that dimmed every highlight dimmed
  the reference too, and the row stayed green. Tie the reference to something the code
  under test does not paint (here: the colour must be one of the palette's own, row `I3`).
- **"The canvas equals a fresh redraw" says nothing when both are wrong the same way.** It
  catches a painter that left something stale; it cannot catch a rule the redraw itself
  breaks. Sample a pixel against a colour the suite computes itself as well (rows `F3`,
  `U1` to `U3` of `test_selection_dim_1769`: the dim colour is the suite's own arithmetic).
- **"Is this colour on the screen" is answered yes by an antialiased letter.** The edge of
  a legend letter blends the layer's colour with the background, and a few such pixels
  land exactly on "the layer's colour, 35 percent towards black". Rows `OV6` and `OV7` of
  `test_wave_overlay_latest_1780` asked whether a shade was gone from the canvas and were
  red with the feature right. A curve is thousands of pixels and an edge is a handful, so
  ask for a count (`ov_has`), not for presence. A shade towards white on a dark background
  cannot be made by an edge; that half of the row never lied.
- **A fixture that writes the model where the product writes the strip tests nothing of
  the fold.** The bold trace is written into the strip's rect by a click and reaches the
  model only when something folds the strips. Row `OV16` first set `hilight_wave` in the
  model and rebuilt: the row was green with the fold taken out (break `t45`). Set it where
  a click sets it (`xschem setprop -fast rect 2 <i> hilight_wave <n>`), and say in a
  fixture row that the model does not hold it yet.
- **A row about "this door notes what it read" needs a window that has read nothing.**
  Row `OV15` restored a state into a window that had loaded the same file a moment
  earlier; the note that load left answered for the restore, and the row was green with
  the restore's own note taken out (break `t66`). Use a fresh session.
- **Two paths to one outcome: a row reaches one of them.** "Ctrl-R takes the later
  versions out" has a path for a window that keeps a trace on earlier data and one for a
  window that keeps none. Every row of `test_wave_overlay_latest_1780` went down the
  first, and the second could be deleted with the suite green (break `n5`). When a proc
  branches on a count, write one row per side of the branch (row `OV16`, second half).
- **A helper that looks a thing up by its exact label answers MISSING when the label
  gains a suffix.** `rd_at` of `test_ase_plot_difference_1727` found a read-out entry by
  its name; when a kept trace's name gained its time (`v(b)-v(a)@01:02:03`) two rows went
  red on a value that was right. A helper that searches by name should say which part of
  the name it matches (`rd_plain`), and a row should assert the new part once (`GG18`).

- **A break that turns no row red does not prove the code dead; it proves no row reaches
  it.** Break `m2` of issue 1780 (a file state kept again gets its old kept name) turned
  nothing red, the code was reasoned to be unreachable and taken out, and an hour later a
  check on a longer path (a reload between two selects, then `u`) found the defect it had
  repaired. Before removing code on a loose break, find the caller that could reach it and
  write that scenario; "the sweep spares those copies" was true of one door and not of the
  load that drops them.

- **A repair can mask an older break: run the whole break table again after it, not only
  the new breaks.** Ctrl-R got a second read "as the analysis ASE-L names" when the first
  finds nothing (issue 1780). The row that used to catch break `m6` (Ctrl-R ignores the
  row the dialog chose) used a file that holds one analysis, so the new second read gave
  the unbroken answer and the row stayed green. It needed a file that holds both (row
  `OV27`).

## 2. Text scans, names and Tcl parse traps

- **Never put a comment between two `switch` patterns.** The trailing argument is parsed
  as a list, so the comment's words become pattern/body pairs: an even word count is a
  silent no-op, an odd one raises "extra switch pattern with no body" out of every arm.
  `info complete` answers 1 either way. On the display arm the odd case can show as a
  `TIMEOUT` with zero `FAIL:` lines, so diagnose on the counted arm. Put prose above the
  proc, and confirm behaviourally with an arm sweep **derived from the proc's own switch
  argument**, never a hand-kept list of kinds.
- **A `calc::*_msg` builder is a `switch` whose arms are `pattern { return …` on one
  physical line, taking three arguments `{kind a b}`.** Bands `MT20/B`
  (`test_calc_measure`) and `S28/8` (`test_calc_skeleton`) derive builders and arms that
  way; an `if` ladder, bodies on following lines, or a different arity fails the sweep for
  every builder in the file.
- **Inside a `"`-quoted check name, `[i]` is command substitution and a nested `"` ends
  the string** while the braces still balance. Quote messages with single quotes. `expr
  {… ? absent : PRESENT}` raises `invalid bareword`.
- **Pin a signature with `info args` and its defaults with `info default`**, not with a
  text scan: every evasion found (a comment copy, an unqualified callee, a backslash
  continuation) defeated a text leg and none defeated the interpreter's own parse. A scan
  over call sites is still useful; declare its blind spellings.
- **A whole-file text scan counts every occurrence, including prose about the predicate**
  (issue 1646). Strip comments first (`wvproc_body`), and for the stripper's non-vacuity
  leg run it on a shipped sibling that does carry a comment.
- **A tip-of-the-day proof names the command it is about, and a row that scans all of
  `src/` for that name then counts the proof's lines.** Row `PR4` of
  `test_ase_plot_difference_1727` ("no door outside the profile runs it") went red on both
  arms when the question for Alt-Shift-D was added, and `test_startup_quiz` alone was run
  for that commit, so the full regression was red until the next one. After adding a
  question, run the suite of the feature it is about as well. A scan for doors passes over
  a proof clause by its shape and still shows any other line of the bank.
- **A comment inside a braced `group` body is still brace-counted.** One `{` in the prose
  with no `}` gives `missing close-brace: possible unbalanced brace in comment`, the suite
  prints no row at all and `run_suites.sh` says `NORESULT (exit 0)`. Spell the brace in
  words.
- **A row's name states its method, not its coverage**, and cross-references to rows are
  checked, not trusted (row `X1` of `test_snprintf_fmt_1608.tcl` derives the real row set
  from the suite's own `check` calls).
- **A probe that lifts a proc must discover everything the proc needs**, and puts the
  failure's cause in the check's name, so a break prints `invalid command name "…"` rather
  than a sentinel.
- **Each suite's `check` has its own signature**: the Calculator suites take `{name got
  want}`, `test_lib_dialog_wayout_0999` takes `{name ok {detail {}}}`.
- House helpers in the Calculator suites: `pcall` takes separate arguments (`pcall mt_load
  ac`, not a braced list); `near` answers the word `ok`, not a boolean; arithmetic on an
  accessor's output is counted by ratchet row `MT29/D`, so use a sentinel-safe proc.
- **A newline inside the brackets of a quiz proof ends the command** (issue 1738): the
  proof is handed to `expr`, and `[P_order file {a}` continued on the next line with
  `{b}]` is `P_order` with two arguments, so the proof RAISES and row A15 reads it as
  false. Keep each `[...]` call of a proof on one line. Evaluate a failing proof clause
  by clause with `catch`: the row's name prints only the proof's first line under `grep`.
- **`string is integer` refuses `clock milliseconds`** (issue 1738, met in a cut that was
  not shipped): the value is wider than 32 bits, so a guard written that way is always
  false and whatever it guards silently never happens. Use `string is wideinteger`, and
  give the row a value the clock really produces, not `1000`.

- **A command substitution cannot wrap inside its brackets.** In `expr {[P_order file {a}` /
  newline / `{b}] && ...}` the newline ends the command, `P_order` is called with two
  arguments, and the proof is simply false: the suite says "its proof holds" failed and
  nothing about a wrong argument count (a quiz proof, 2026-11-24). Wrap between the `&&`
  terms, never inside `[...]`.

- **`expr` hands a signed number back without its sign.** `[expr {$v > 0 ? "+$v" : "$v"}]`
  answers `40` for 40: the string `+40` looks like a number, and `expr` returns the number.
  A token whose sign is part of its grammar (`4+40` on a graph's colour list) is built
  outside `expr`: `if {$v > 0} { return "+$v" }` (issue 1780, caught by row `OP1`).

- **A new parameter with the name of a local of the proc is overwritten by it, silently.**
  `wviewer::hold_manual` has a local `all` (every strip of the window). A new last
  argument `all` was accepted, defaulted, and then replaced by the strip list on the
  proc's fourth line; the first test of it said `expected boolean value but got "{traces
  ..."` from a background error, far from the cause. Before adding a parameter, search the
  body for `set <name>` and `foreach <name>` (issue 1780: the argument is `every`).

## 3. Tk and event traps

- **`winfo` and `font` do not exist under `--nogui`**: test `info commands winfo` before
  `winfo exists`, or the guard itself raises (row `CF5` of `test_calc_measure`).
  `toplevel`, `bind` and `event generate` are absent too.
- **A Tk button runs its `-command` on release, and only after `<Enter>`**: the working
  gesture is Enter → press → release with explicit `-x`/`-y`, then `<Leave>` to cancel the
  tooltip timer. `invoke` tests `-command`, not the binding.
- **`event generate .calc.buf <KeyPress>` hangs on the display arm** (`focus -force` does
  not help). For an undo-separator claim `.calc.buf insert` is the stronger drive anyway
  (row `CB2`: `insert` leaves the edit unseparated); follow it with `mark set insert
  end-1c`.
- **An event's `-x`/`-y` are screen pixels; a canvas pick works in schematic units.**
  `X_TO_SCREEN` in `src/xschem.h`: pixel = (schematic + origin) / zoom, from `xschem get
  xorigin|yorigin|zoom`. Round-trip through `xschem get mousex|mousey` instead of trusting
  the arithmetic.
- **`callback()` writes `xctx->mousex/mousey` for every event, and the design canvas's own
  `<Configure>` (a re-layout or resize) overwrites the pair** (issue 1659). The three
  click modes (`ase::ui::sod_press_script`, `calc::_pick_seize`, `rdw::_pick_seize`) run
  `xschem callback %W 6 %x %y 0 0 0 %s` ahead of their click; any other reader after a
  re-layout with no motion sees a stale pair.
- **In a click helper, know what the `update` after the motion does.** With `-when now`
  the event is delivered synchronously and that `update` only exposes the pair to a
  `<Configure>`: move it in front of the motion (`kx_click`). Without `-when now` that
  `update` is what delivers the motion: keep it and drain in front (`pg_click`, which also
  reads the pair back; row `PGC`).
- **`alert_` is not re-entrant** (a fixed `.alert` toplevel, `tkwait`, no grab): a second
  caller raises out of a menu command. For a notice use `catch { ::xschem::notify {…} }`.
  A suite renames `alert_` to a recorder to stop a hang; keep that rename when moving a
  spy to the notice channel.
- **A window mapped, re-mapped or raised under the real pointer gets an Enter from the
  server, and the engine answers an Enter that switches the context with `focus
  <canvas>`.** A row that asks where an OPEN leaves the keyboard focus must park the
  pointer off every window first (`ptr_park` in `test_wave_viewer`), or assert the window
  under the pointer with the answer: the first `G1f` and `KM18` of overnight item 03b asked
  for the focus on the plot canvas and read green on a product that left it on the toplevel
  until they did.
- **A plain `focus <w>` moves the keyboard whenever this application holds it**, between
  toplevels too; only when another application has it does Tk just note `<w>` for later.
  So "plain, never `-force`" does not make a focus call harmless: an open that focused the
  viewer's plot took the next keys typed over the schematic. Ask what the keys typed next
  DO, with the pointer where a user leaves it (row `KM18`), not only where the focus is.
  To see which calls a proc makes, rename `::focus` to a recorder around it; the engine's
  own `focus -force <canvas>` for a new window is in that list too, so filter by target.
- **A viewer shortcut that runs leaves the viewer's context current.** A control that
  follows it and warps the pointer to where it already is gets no Enter and reads the
  wrong context: take the pointer off every window and back first (`ptr_park`, `ptr_back`).
- **`tk::MenuUnpost {}` does not take down a menu posted from a menubar** (F10, an
  Alt-letter): hand it the posted menu, which is the window that has the focus then, and
  release the grab. A menu left up answers `winfo containing` for every later row.
- **`event generate <w> <Motion> -warp 1` moves the real pointer**, and the server sends
  the crossing events itself. `winfo containing` answers `{}` over a window-manager frame
  and over another application: raise the window before warping into it, and assert the
  window under the pointer instead of assuming it.
- **Tk hands a generated key to the window that has the focus, whichever window it is
  generated on.** To send a key "to" a canvas, give it the focus and confirm with `focus
  -displayof`. Code that must act for a window without the focus has to choose the binding
  itself (`wviewer::tag_key_seq`), and its fence is parity with real delivery on the live
  tag (row `KM19`). Tk's choice among bindings is not transitive: of two sequences that
  ask for different modifiers the later bound wins, so three of them can answer by order.
- **A key that opens a modal on a product that still mis-routes it must not be sent
  there.** Ask first, with a key nobody has a use for (the left Shift key), whether the
  product routes a key the way the row needs, and report `not-sent` (rows `KM16`, `KM19`).
  An error raised inside a binding is a background error, and Tk's dialog for it blocks
  the suite: record it for the leg with `interp bgerror {} <recorder>`.
- **A status-bar prompt longer than the bar has room for is never on screen in a window
  whose size nobody set.** The label's request grows the bar, the window grows, the design
  canvas gets a `<Configure>`, the engine blanks `.statusbar.10` on that event, and the
  prompt timer starts the round again. A row that reads the slot once after a click can
  read the sentence in the instant between two rounds: poll for it, then let the event
  loop turn several times and read it again (`prompt_is` in
  `test_ase_plot_difference_1727`). `wm geometry . WxH` pins the window and hides the loop,
  so drive at least one long prompt before the suite sets a geometry.
- **A prompt compared with the mode's record says nothing about the slot.** The record
  holds the whole sentence in any window; the slot is cut to its room, and the room
  depends on the red field beside it (`.statusbar.12`), which the notice channel fills
  whenever the CIW is not mapped. Under `--logdir` the CIW is mapped and that field stays
  empty, so a sentence that is cut for a user with the CIW closed reads almost whole in
  the suite. Put the short form there the way the channel does
  (`xschem::notify_statusbar [xschem::notify_short {} <notice>]`), give the prompt timer
  a few turns, and assert the words the user must see on the widget's own text, in a
  window whose size was put back to unset with `wm geometry . {}` (`slot_tight`, band GQ
  of `test_ase_plot_difference_1727`).
- **After a plot the current context is the viewer's.** A command on the design canvas
  that asks which schematic is current (`ase::session_for_current`) then reads the
  viewer's untitled sheet. A pointer coming back onto the schematic switches it; a suite
  has to do that itself (`xschem new_schematic switch .drw`) before the next generated
  key, and should read the path back.
- **`update idletasks` runs no timers**, so the suite watchdog cannot fire inside a loop
  of it.
- **A generated key with a capital keysym and no Shift in `-state` ran the small
  letter's binding** (measured 2026-11-24 on the viewer canvas): `event generate $w
  <KeyPress> -keysym U` ran the viewer's undo, which is bound to `u`, and with `-state 1`
  it ran the redo, bound to `U`. Pass the Shift state with a capital keysym, and have a
  row that presses a shifted key read something only that key changes (row `RU2` of
  `test_wave_expr_reattach_1734` reads which side of the history a step moved to).
- **A synthetic double click with a second press (`4, 5, 4, -3, 5`) on a free device PIN
  poisons every later row** under `persistent_command`: the abort drops the armed
  wire-draw but the wire command stays remembered, and the next press anywhere starts a
  wire. Tk hands a real double click over as `4, 5, -3, 5`, which leaves nothing behind
  (row `G16c` of `test_dblclick_connected_grow`); keep a second-press stream off pins
  (row `G14c`).
- **Calculator sash geometry**: the window's minimum grows with its font, so the sashes
  are re-derived on every font step; enforce the last pane with a backward cap; take the
  inter-pane gap and the sash-coordinate lead from the live widget (`calc::sash_metrics`),
  never from `-sashwidth` or from extent minus pane extents.
- **A generated drag cannot see a pane hidden under the window that manages it.**
  `event generate` addresses the paned window by name, so the drag rows of
  `test_ase_pane_dividers_1737` stay green with the two `lower` calls of
  `ase::ui::pane_layout` taken out, while on a screen the panes are not seen at all. A
  pane that is managed by a window it is not a child of needs a row on the stacking
  order (`winfo children` lists it lowest first; band `PD0`).
- **A mapped classic paned window stops listening to what its panes ask for.** That is
  what keeps a repaint from moving a divider, and it is also what broke a window that
  used to grow with a live font-size change (issue 1737). No row existed for it; a probe
  that printed the window's and the panes' sizes at the base and with the change, side
  by side, through the same steps, showed it. Before replacing a geometry manager, run
  such a pair for every door that changes what the content asks for.
- **A widget the packer finds no room for is unmapped, and keeps the place it had.**
  `winfo y` and `winfo height` of it read as if it were still on screen. A row about
  what a short window still shows asks `winfo ismapped` first (`w_foot_in` of
  `test_startup_quiz`; its first form passed row `D51` with the buttons gone).
- **Tk makes a toplevel follow its widgets only until the toplevel gets a size from
  outside** (`wm geometry` with a size, a drag of the border, a window manager's own
  size). After that, taller content is cut. A row about a window growing with its
  content runs after such a size (row `D49`), or it tests Tk and passes on a product
  that does nothing.
- **openbox moves a window that grows by Tk's own following back onto the screen, and
  leaves one alone whose size was set with `wm geometry`.** A keep-on-screen row can be
  green for the window manager's reason (row `D54` on the window as it was before issue
  1739). Take the product's own move out and see the row go red.
- **`font actual` reports the size of a font created in pixels (`-size -12`) in
  points.** Code that branches on a size below zero is not reached through it (row
  `D59`).
- **Never `font configure` a `Tk*Font`**: it resizes every other dialog (row `CF18`; row
  `FZ5` of `test_rdw_window_1245`).
- **A binding that destroys its own widget needs a `break`.** Tk runs the class binding
  for the same event afterwards, on a window that is gone, and that raises "bad window
  path name" as a background error, whose dialog blocks. The first double click of
  `test_ase_save_browse_1763` hung on it, with a user's screen the next place it would
  have shown (the browser's `<Double-ButtonRelease-1>`, issue 1763). A suite that presses
  such a gesture records background errors (`interp bgerror {} <recorder>`) and asks for
  none (row `SB3`), so the next one is a red row and not a stall.
- **Two generated presses with no `-time` are a double click.** Tk tells a double click by
  the events' time stamps, and `event generate` gives every event the same one. The second
  `<ButtonPress-3>` of a suite then runs the canvas's `<Double-Button-3>` line (`xschem
  callback %W -3 ...`) and never the press: rows silently test nothing. Give each press a
  `-time` a second later than the last (`press` in `test_selection_dim_1769`), and a
  smaller step when a double click is what is wanted (row `H9`). A real second press
  arrives the same way: Tk hands a double click over as press, release, the double,
  release.
- **A Tk sequence matches a key that carries MORE modifiers than it names.** `<Alt-Key-D>`
  takes Ctrl-Alt-Shift-D, and `<Control-Shift-Key-D>` takes it too. A new chord with three
  modifiers is checked against every two-modifier line on the same letter, on the canvas
  and on every bind tag a window of the session carries (`WaveViewer`), and gets a closer
  match beside each (issue 1769; rows `C1`, `C2`, `W1`).
- **The canvas's `<Enter>` line hands its event over with a state of 0** (`xschem callback
  %W %T %x %y 0 0 0 0`), whatever button or key is held. C code that reads the state of an
  EnterNotify reads nothing. `<Leave>` and `<Motion>` pass `%s`.
- **A write made inside a variable trace is not seen by the other traces.** A trace that
  put `selection_dim` right (true to 1) left the menu's check entry showing the old word:
  Tk's own trace of the variable keeps the tick and did not run for the nested write. Do
  the write when the event loop is idle (`selection_dim_written`, row `M4`).
- **Whether a new toplevel gets the keyboard is the window manager's choice.** A small
  window that calls no `focus` still has the keyboard under openbox the moment it maps. A
  row "the window does not take the keyboard" is a row about the window manager and was
  red on a correct product. Test what the product owns: a key typed on that window does
  the right thing (rows `OV25` of `test_wave_overlay_latest_1780`).

- **`event generate <Key-NAME>` for a keysym the display's keymap does not hold sends a
  key with the keysym `??`**, not the one asked for. On the hidden display `Mode_switch`,
  `Multi_key`, `Hyper_L` and `Scroll_Lock` have no keycode, so a row that "typed" them
  tested an unnamed key. Read `%K` back, or type only keysyms the keymap has (`Super_L`,
  `ISO_Level3_Shift`), and test the rest through the pure helper (issue 1780, rows `OP7`
  and `OV29`).

## 4. `xschem` command and data traps

- **A command run from a key press runs inside the editor's event handler, where
  `xschem go_back` and `xschem descend` do nothing** (`xctx->semaphore`). A row that
  calls the action's proc directly passes on a product that fails from the key: the run
  key of issue 1764 made no deck from two levels down until its work was moved behind
  the key press with `after idle`. Press the key through the callback
  (`xschem callback <canvas> 2 <x> <y> <keysym> 0 0 <state>`), and compare what it did
  and said with the button it stands for, pressed in the same place (rows `RK1`, `RK2`).
- **`xschem bindings dump` answers a list of rows, not lines**: iterate it as a list and
  compare `lindex 4` with the action. A row skipped while the editor is busy has a sixth
  word, `idle`.

- `xschem object_bbox` does not exist; the readers are `xschem wire_coord` and `xschem
  instance_bbox`.
- `object_at`'s fourth field is a session-stable id, not a file-stable one: compare fields
  0 and 1 only.
- A net label is a `lab_pin.sym` instance. `lab=` on a wire loads without complaint and
  leaves the net auto-named (`#net1`).
- `xschem net_at` is `point_on_wire_or_pin()`, and a wire always wins `find_closest_obj`
  over an instance it crosses, so the `terminal` class is unreachable on `cmos_inv.sch`:
  use a bare-pin fixture.
- `xschem instance_pin_coord <i> name <pin>` answers `{name} x y` (the name is element 0).
  For a pin name ending in a backslash neither it nor `xschem pinlist <n> name` returns a
  Tcl list: use `ase::ui::sod_term_pin_names` and `ase::ui::sod_term_pin_xy`.
- `xschem raw list` enumerates every variable, AC's expanded columns included, and `raw
  index` indexes the same array. `raw index` is case-insensitive and accepts a bare net
  name, so only a byte comparison of the inventory sees a case error. `raw loaded` answers
  −1 silently where `raw index` and `raw list` raise `No raw file loaded`.
- `xschem raw value` rounds through `%.8g`; compare with `xschem raw values` (`%.16g`).
- **`xschem get current_win_path` is a context identifier, not a Tk path**: in the tabbed
  interface it answers `.x2.drw` for a schematic drawn on `.drw`, and `bind` on it raises
  (inside `catch` it binds nothing and the mode only looks armed). Resolve the widget from
  `xschem windows` (field 0 the context path, field 1 the toplevel; the main window's
  toplevel is `.`, so its canvas is `.drw`). `switch_window()`/`switch_tab()` return 1
  under `xctx->semaphore`, so verify by walking the window's hierarchy stack, answering −1
  for "not here".
- **A seize must never latch its own scripts as the predecessors**: re-seizing a seized
  canvas makes the restore re-install the seize, permanently (issue 1305). Guard in the
  seize as well as in `pick_start`.
- **`xschem saveas` of an untitled schematic, and `xschem load -gui` over a dirty untitled
  sheet, write `untitled~.sch` in the startup directory** (gitignored, so `git status`
  hides it); it reddens the hygiene rows of the `test_rdw_*` suites. Load the real sheet
  first and assert the glob at the foot.
- `is_generator(NULL)` is that function's cache-free call, not a predicate: null-check
  first.
- **Before fixing a "cosmetic" output, grep for a reader**: `op_annot.tcl` parses the
  netlist's `** sch_path:` comments and suppresses a subtree on a mismatch (issue 1605).
  A fixture for those comments must netlist a subcircuit; a primitive emits no
  `sym_path:` line.

- **A drag that changes which pins are connected takes a different road through
  `move_objects()`, and a suite with no such drag never walks it.** The attempt ladder rolls
  the first route back when the pin partition changes and, when every attempt changes it (the
  user dropped a wire's end on a pin), keeps the SECOND attempt's result. A new placement
  that runs on the first attempt only was therefore silently replaced by the old one in
  exactly the drags that make a connection (issue 1740, row F2 of
  `test_wire_drag_junction_1740.tcl`). Give a wiring suite one drag that lands on a pin.
- **A later pass will "repair" what a new placement leaves on purpose.** The overshoot pass
  of issue 0092 is the one END pass that does not ask whose copper it reshapes; on the result
  of issue 1740's junction pass it took the rest of a wire for an overshoot tail and moved
  the BAR to its tip. It needs a START pin snapshot, so a fixture with no instance at all
  never shows it: rows F1 and F1b carry one label that touches nothing for that reason.
- **A guard copied from another pass brings that pass's purpose with it.** The push-through
  slide counts a new overlap of bounding boxes with another net as a contact, crossings
  included, because it must not park copper near a foreign riser. The same rule in the
  junction pass dropped the plan for every drag across another net's wire, which in a real
  schematic is most of them, and the suite's fixtures had no second net in the way (row F4).
- **`xschem wire` merges and splits as it stores when `autotrim_wires` is on.** Two wires in
  a straight line with nothing at the joint come back as one, and a label does not keep them
  apart; a wire that ends on the middle of another splits it. Read the wire set back before
  trusting a fixture's shape (issue 1740: a "wire that continues the dragged one" could not
  be built that way).

- **The overshoot pass of issue 0092 can delete the wire the user is dragging.** It trims a
  "new dangling stub in line with a continuation at a junction with one perpendicular wire",
  and it does not ask whose wire that is. A dragged wire with a free far end, next to a wire
  the old placement carried, is exactly that shape: a wire through a device pin, one side
  dragged farther than the other side is long, came back with the dragged side GONE (issue
  1741, row H4). When a row's wire set is short by one, read the trace for `overshoot: TRIM`.

- **A fixture schematic with no instance is loaded in symbol mode, and netlisting it stops
  on a question.** `load_schematic()` switches the netlisting mode for a sheet that has no
  instance; `ase::netlist` on it then pops "Please Set netlisting mode (Options menu)" and a
  suite sits there until its timeout, with the last `ok:` line two rows earlier (issue 1761,
  band `DW3`; `test_ase_core`'s round-trip fixture carries one label pin for the same
  reason). Give a fixture sheet one instance, resolved or not. A label symbol that does not
  resolve names no net: read the net's name off the wire (`xschem getprop wire 0 lab`)
  rather than predict it.

- **A viewer rebuild after traces were taken out must come while the strips are still
  the ones on screen, one for one.** `wviewer::view_map` gives each strip its own view by
  place only while the count is unchanged; once a strip was added or removed it matches by
  traces across the whole tab, and a strip of another subwindow that holds the same
  traces as an emptied one takes the emptied strip's view (issue 1765, rows PV5 and PV6;
  the defect issue 1733's review found). Rebuild inside the step that removes the traces,
  as `wviewer::clear_subwin` and `wviewer::owned_clear` do, and only then ready strips.

- **A step taken before a load must be taken back when the load reads nothing.** The
  first cut of issue 1765 renamed the viewer's data and pinned traces to the new name,
  then loaded; a load that read nothing left the rename standing, and the saved state
  named `<file>@held1` as its result. A release before a load had the mirror defect.
  Give the pair one settling step after the load (`wviewer::hold_settle`) and a row
  whose file cannot be read (RK17, RL11).
- **`my_snprintf()` has no `%%`.** It is the tree's own small formatter (`src/util.c`): a
  doubled percent sign ends the output there. Pass the sign as a `%s` argument
  (`sel_dim_toggle()`; row `T2` of `test_selection_dim_1769` reads the whole sentence).
- **`xschem print png|svg` of a selection prints the selection's area and drops the
  selection**; only Ctrl-* prints the window with the selection kept, and it asks for the
  file in a dialog (answer it by replacing `save_file_dialog` for the key press, row
  `X2`). **`xschem undo` after a wire cut does not repaint**: the cut's cue stays on the
  canvas until the next redraw, so load the fixture afresh before reading pixels.
- **A redraw started from the end of `xschem()` must run before the depth returns to 0.**
  `draw()` evaluates Tcl (a symbol's `tcleval()` text), that Tcl runs `xschem` commands,
  and each of them would otherwise reach the same line and start the redraw again
  (`sel_dim_sync()`, issue 1769: found as a suite that never ended, in the only-probes view).
- **Traces pointed at other data make "the same data" false.** A load of a file the
  window attached already is carried as the same data, view and all. After traces were
  moved from an earlier run's data onto that file, a strip zoomed in X kept the earlier
  run's Y window and its trace was off screen: drop the attach record with the move
  (`wviewer::hold_release`), and read the Y window the strip SHOWS, not only a fit made by
  the row (RK13: `rk_y` beside `rk_yfit`).

- **A fold of the viewer's strips made AFTER a model edit that renumbers traces writes the
  old numbers back.** `wviewer::capture_live_view_state` copies the bold trace and the
  selection from the rects into the model. `wviewer::hold_release` took a later version
  of a waveform out of the model (which renumbers the traces after it) and the load that
  follows folded the strips, still numbered the old way, over the result: the bold mark
  ended one trace off. Fold first, edit, and rebuild before anything folds again (issue
  1780, row `OV16`; `wviewer::delete_items` has always done it in that order).

- **Unloading a database by name can leave another one current.** `xschem raw clear <name>
  <type>` of a database that is not the current one moved the engine's current database
  (break `n13`: after it the viewer's plain traces drew from another file). Read the
  current database first and switch back to it (`wviewer::held_sweep`, row `OV18`).

## 5. Registration, gates and flakes

- **An issue number can be taken between the mint check and the commit.** The checks of
  CLAUDE.md said 1773 was free at 09:15; a worktree of another clone took it at 10:07,
  while this clone was still building under it and had recorded nothing. A reviewer found
  it by running the worktree glob again. Run the three checks again right before the
  commit, and when another session is minting in the same hours, leave it a block and
  take a number beyond it (issue 1780, `NUMBERING.md`).

- **Derive a registration's trailer delta before the gate; never predict it from the
  registration shape.** Lift `summarize_all` and every proc it needs out of
  `run_regression.tcl`, source `banner_complete` from `tests/banner_rule.tcl`, and run
  them over the suite's real captured output on each arm; then check `planned_cases` in
  the run's header. `skips=` counts lowercase `^skip:` lines only: an uppercase `SKIP:`,
  a `SKIPPED:` or a `RESULT: SKIP` costs none, and a home with no probe-capable ngspice
  adds some.
- To count a registration list, find `set hcases [list` (not a line number), stop at the
  first line with no trailing backslash, and pipe through `/usr/bin/grep -o '"[^"]*"' |
  wc -l`. `grep -c '"headless/'` and `grep -cE '\.log$'` miscount, and an awk slurp
  ending on `^]` reads the whole file.
- A path of 84 characters at `test_op_annot`'s worst-case probe gated clean and 173 did
  not, which is why gate clones live at short paths.
- Check a suite's epilogue against `banner_complete` before registering it; `wvbs_finish`
  (`tests/headless/wvbs_common.tcl`) and the Calculator suites print `OVERALL: ok` for
  that reason.
- Registration shape is measured: run the suite's real output on each arm through
  `tests/banner_rule.tcl`. A display-only suite goes in `dcases` alone. A suite whose
  gesture path crashes under `--nogui` keeps an `hcases` entry as a crash guard and so
  gets two blocks in the verdict (`test_fluid_editing`: `RESULT: SKIP (no X)` in one, its
  checks in the other).
- `test_rdw_window_1245` is not registered (checked 2026-11-21) and has an unfixed tooltip
  flake (`HT9`/`HT12`/`HT15`).
- T1's `hcases` arm strips `DISPLAY` (`env -u DISPLAY` on `hccmd` and `xtcmd`, fenced by
  rows `X1`–`X4` of `test_home_isolation`); `run_suites.sh --nogui` attaches `:99`, so a
  suite's check count can differ between the two.
- **T1 is the arbiter for the Calculator suites.** A hand loop of `run_suites.sh` back to
  back reddens suites that pass standalone.
- A failing-row set that moves between runs at one commit is a flake. Re-gate; do not
  retry, lengthen or skip inside the suite.
- When triaging a suite, grep `doc/claude/issues/` for the **suite name**, not the
  symptom: an `hcases`-alone trade is often filed deliberately (issues 1647, 1413).
- After any `openbox` cleanup run `devdisplay.sh status`: `wm: openbox (-)` instead of
  `(Openbox)` means the shared display lost its WM. Match a WM by its display, never by
  its name.
- After a delegated crew fails to return, re-run the suites it touched: a red-first row
  may be planted with no fix behind it.
- **A new proc can redden a suite nobody on the job opened.** Some rows derive their
  population from the product's text and hold every member to a hand-kept table: row
  `SVR-D1` of `test_ase_saved_results_1705` reads the Tcl sources results_selection.md R913
  lists for every proc that names one of its artifact-path procs and fails on one its `CLASS`
  table lacks (issue 1727's two readers, red in the full T1 only). Before the gate, grep
  `tests/` for the name of the proc the new one stands beside (`dp_finish` for a sibling
  of Direct Plot's finish) and run every suite that names it. Class the newcomer by what
  the row's rule demands of it, then build the break that class exists to catch.

- **A spy that renames a proc out of its namespace breaks it.** `rename ::wviewer::p
  ::spy_p` moves the proc to the global namespace, where its `variable windows` names
  `::windows`: every call then fails with "can't read windows", inside whatever `catch`
  the caller has. Rename inside the namespace (`::wviewer::spy_p`). (Issue 1765.)
- **A stand-in for a proc that takes a one-shot arm must take the arm.**
  `wviewer::add_trace` takes the display name and the owner mark armed for its window
  (`expr_label_arm`, `owner_arm`). A stub that only records the call leaves the arm
  standing and adds a trace without what the arm carried, so every row downstream reads
  another product (issue 1765: the stub of `test_ase_plot_outputs` added unmarked traces
  and Replace kept them all).
- **A row that binds "a key the product does not use" names a key the product may use
  tomorrow.** Rows KM19 and CG6 bound Ctrl-R on the viewer's tag as their own and removed
  it afterwards; when Ctrl-R became the viewer's Reload they removed the default. Check
  the key against `install_default_binds` when a default is added, and say in the row why
  that key is free.
- **A text fence over a proc's order breaks on an early `return`.** `string first {return}`
  after a branch's opening found the guard `{ return }` on the branch's first line once
  one was added (GX9 of `test_wave_grid`). Anchor on the line that ends the branch
  (`"\n    return\n"`), and on the call's own arguments when the proc gains a second
  call of the same name (`wviewer::attach_raw $key $rf`).

## 6. Measuring

- **Which data a trace shows is three measurements, and the engine's fit is over the X
  window on screen.** A value read in the database the trace names says what it is pinned
  to; the rect's `node` token says what the engine was told; the engine's own Y fit says
  what it draws. The fit covers the visible X window only, so after a zoom two runs that
  differ in amplitude can fit to the same number: pick the window so the expected values
  differ (rows RK3 and RL4, issues 1765 and 1766).

- The linked binary's md5 is not a restore proof (`src/scheduler.c` embeds `__DATE__` and
  `__TIME__`); an object such as `save.o` is reproducible and is the witness.
- `valgrind env -u DISPLAY ./src/xschem` traces `env`; put `env` first.
- `/proc/<pid>/environ` is the exec-time environment, and `pgrep -f` matches the launching
  subshell. Use `pgrep -x <comm>`, and corroborate a display claim with `/usr/bin/grep -l
  'map=1' /tmp/Xschem.log.*`. The race-free probe is one `xev -root -event substructure`
  on a private Xvfb (redirect `TMPDIR`).
- A suite killed from outside prints `FATAL: signal 15` and is scored a death: recognise
  that before diagnosing a hang.

## 7. Scope

- **Before narrowing a unit, ask what the narrowed tree does, not only what it can
  prove.** Split between the decision (a pure proc, gated on the counted arm) and the act
  (display-only, declared), not between fenceable and unfenceable.
