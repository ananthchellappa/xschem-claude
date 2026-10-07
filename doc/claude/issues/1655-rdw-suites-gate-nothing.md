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
