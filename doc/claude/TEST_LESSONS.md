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
- **`update idletasks` runs no timers**, so the suite watchdog cannot fire inside a loop
  of it.
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
- **Never `font configure` a `Tk*Font`**: it resizes every other dialog (row `CF18`; row
  `FZ5` of `test_rdw_window_1245`).

## 4. `xschem` command and data traps

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

## 5. Registration, gates and flakes

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

## 6. Measuring

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
