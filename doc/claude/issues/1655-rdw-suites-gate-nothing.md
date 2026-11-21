# 1655 — all three `test_rdw_*` suites lack the `OVERALL: ok` sentinel and none is registered, so the RDW font control's fences run in no gate

**STAMP:** `v1 claim=open tree=81dfbcf9 stamped=2026-10-07 fix=none open=1`

Status: **OPEN**, measured 2026-10-07 while mirroring the RDW font control into the Calculator
(spec R114). Same defect family as issues 0420, 0456, 0492, 0629, 0689, 1413, 1615, 1626, 1645 and
1652 — the one `tests/banner_rule.tcl` records as *"filed FOUR times and waved through as
furniture each time."*

Area: `tests/headless/test_rdw_keys_1245.tcl`, `tests/headless/test_rdw_seam_1245.tcl`,
`tests/headless/test_rdw_window_1245.tcl`; `banner_complete` in `tests/banner_rule.tcl`;
`tests/run_regression.tcl`.

## The defect

Measured, two independent checks:

```sh
/usr/bin/grep -c 'rdw' tests/run_regression.tcl              # -> 0
for f in tests/headless/test_rdw_*.tcl; do
  /usr/bin/grep -c 'OVERALL: ok' "$f"; done                  # -> 0, 0, 0
```

So none of the three is in `hcases` or `dcases`, and none could be registered as it stands:
`banner_complete` is `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$` and is the only reader
`run_regression.tcl` consults. Registering one today costs a counted `HARNESS:` failure with all
of its own checks passing — issue 1615's incident exactly.

## Why it matters more than the usual instance of this family

`test_rdw_window_1245` holds the **`FZ` band**, which is the RDW font control's own fence set —
including row **FZ5**, the row asserting that *no global font was touched*. That is the single most
load-bearing claim in that feature: the alternative implementation (`font configure TkFixedFont
-size N`) is a one-liner that works perfectly in the window and silently resizes the attribute
editor, the symbol-property editor, the text-input dialog, editpaths, the graph dialog, the notify
popup and the Calculator's buffer. `rdw.tcl`'s own header enumerates them. **Nothing runs the row
that would catch a regression to that one-liner.**

The Calculator's equivalent fences were therefore written to mirror the `FZ` band's **method** and
not its epilogue: band `CF` of `test_calc_measure` and band `S29` of `test_calc_skeleton`, both in
already-registered suites.

## Also reported, and NOT independently confirmed here

The design crews for R114 reported `test_rdw_window_1245` as **red at HEAD on both arms** (1 FAILED
/ 210 passed headless, 3 FAILED / 266 passed on `:99`), with none of the failures an `FZ` row. That
is second-hand: this issue confirms only the registration and sentinel halves, by the two commands
above. Re-run the suite before acting on the red.

## Fix sketch

One additive `puts "OVERALL: ok ($npass checks)"` per suite, with the `RESULT:` line kept **last**
(`summarize_all` publishes a case's last `RESULT:` line), then register each in the list its arms
actually support — measured with `tests/banner_rule.tcl` on both arms first, never predicted, which
is the method issues 1625/1626 settled on. Expect the trailer's `cases`/`blocks` to move and derive
the delta before launching.

## Note, 2026-11-19 (issue 1724): one of the three is registered now, and what it needed

The stamp line above is left as it was. What changed, for the record:

- `tests/headless/test_rdw_keys_1245.tcl` prints the `OVERALL: ok` sentinel and is in
  `dcases` (the comment at its entry in `tests/run_regression.tcl` says why that list
  alone). `test_rdw_seam_1245` and `test_rdw_window_1245` still print no sentinel and are
  in no list, so the `FZ` band is still run by no gate.
- **Registered, it stalled on a display with no window manager** (found by the third
  review of issue 1724, in the gate's own command shape). Two causes, both in the suite:
  it renamed the product's `ciw_echo` away, installed a recorder, and deleted the recorder
  without putting the product's proc back, so the next `.ciw <FocusIn>` raised `invalid
  command name "ciw_echo"` as a background error, whose dialog is modal; and rows F3 and
  RA4 are about something only a window manager gives. Now the product's proc is put back
  directly after the recorder goes (row S1b), row WM0 names the window manager from the
  root window's own record of it and checks that against `wm frame`, and F3 and RA4 are
  left out, under an upper-case `SKIPPED:` line each, on a display that has none. There
  the suite reaches its `RESULT:` line instead of stalling.
- A lower-case `skip:` line was deliberately not used: the regression driver's trailer
  counts those.
- **A window manager that has died** (found by the fourth repair's verifier of the same
  issue, built by its closing pass the same day). When the manager of a live display is
  ended, the root window still names it, so the suite took the display for one with a
  manager: row WM0 went red, and F3 and RA4 ran and went red too (no stall). This tree's
  notes record that state twice, an `openbox` killed on a live display. The suite now
  takes such a record as no manager when the main window has no frame: row WM0 reads
  `unnamed` and passes, F3 and RA4 are left out under their upper-case `SKIPPED:` lines,
  and the run reaches its `RESULT:` line with no red. Measured on a private display
  whose `openbox` had been ended by pid before the suite, and with no manager started
  at all.
- Not measured: a window manager that puts no frame round its windows, where row WM0's
  two readings would disagree; a manager that dies while the suite is running; a root
  window that names no manager while the main window has a frame (rows F3 and RA4 run
  there since this change, and WM0 is red in that state either way); a root record that
  cannot be read.
- `test_rdw_window_1245`'s tooltip rows (`HT9`, `HT12`, `HT15`) are still not stable,
  which is why that suite stays out of the lists; its row `HT14` was restated the same day
  (issue 1387: the mode arms in a tab).
