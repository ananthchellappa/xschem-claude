# 1645 — the two suites that OWN the viewer arity pins are registered nowhere

**STAMP:** `v1 claim=fixed tree=30d304a0 stamped=2026-10-03 fix=taken open=1`

Status: **OPEN**, found 2026-10-03 by the Calculator batch's unit J1b recon while checking which
rows would catch a signature change. Pre-existing, same family as issues 1615, 1626, 1638 and 1641.

Area: `tests/headless/test_wave_grid.tcl` (row `GT8`), `tests/headless/test_wave_sigbrowser.tcl`
(row `BM05`), `tests/headless/test_node_token_split.tcl` (rows `NDR2`/`NDR3`),
`tests/run_regression.tcl`.
Found: extracted the three case lists from `run_regression.tcl` by text and reconciled them against
the gate's own `cases=` figure.

## The defect

Three suites carrying load-bearing pins are in **neither** `hcases` **nor** `dcases`, so nothing
runs them in front of a commit:

| suite | what it pins | consequence of it not gating |
|---|---|---|
| `test_wave_sigbrowser` row `BM05` | `wviewer::plot_signals`' **four** formals, as a literal source string | ⚠ **nothing** — see the correction below |
| `test_wave_grid` row `GT8` | `wviewer::graph_props`' **three** formals | ⚠ **nothing** — see the correction below |
| `test_node_token_split` rows `NDR2`/`NDR3` | that all seven `node=` walkers resolve the sweep column **by name** and clamp against `nvars` | the one row that re-measures a walker count every run |

⚠ **The arity pins are exactly the ones a change is most likely to trip, and breaking them fails
SILENTLY.** A 5-argument `wviewer::plot_signals` call raises *"too many arguments"*, which
`wviewer::browser_plot_ids`' own `catch` **swallows** — so every gesture check downstream reads as
*"the gesture did nothing"* rather than as an error. A whole class of checks goes quietly blind
instead of failing. A developer who added the parameter would get a green gate and a red
`full_audit.sh`, which globs `test_*.tcl` and does run all of them.

⚠ **And the unregistered `test_node_token_split` is part of why a wrong figure persisted.** The
`sweep=` walker population was written down as *"all SEVEN walkers carry the token forward"* in a
source comment and copied into a batch contract. Re-derived: **six** carry forward, the reader
population is **nine**, and three read only the first token — a different defect entirely. The
"seven" is correct for a **different predicate** (resolves-by-name), which is what `NDR2`/`NDR3`
actually assert — and because nothing runs them, nothing re-attached the number to its predicate.
That is CLAUDE.md's `grep -c '#pragma'` failure with a test as the victim rather than a comment.

## What is NOT claimed here

Only a minority of `tests/headless/test_*.tcl` files are registered (measured 100 of 430 on 2026-10-03, against the **84 of 418** this issue first quoted and CLAUDE.md still records; both terms move with the tree, so the figure belongs in a row or nowhere), and issue 1615 already settled
that the remedy is per suite rather than wholesale — *"a suite you add a fence to, you register in
the same commit"*. This issue is not a call to register the tail. It is a call to register **these
three**, because each one pins something another suite's green run actively depends on.

## Two things to check before registering any of them

1. ⚠ **"It passes standalone" is not evidence that a suite can be registered.** Issue 1615's
   incident: registering a suite gated **red** with all 88 of its own checks passing, because its
   epilogue printed only `RESULT: ALL PASS` while `banner_complete` in `tests/banner_rule.tcl` — the
   only Tcl reader, the one `run_regression.tcl` sources — requires a whole-line
   `^OVERALL: ok(...)?$`. `run_suites.sh` and `full_audit.sh` carry their own EREs that *do* accept
   the `RESULT:` spelling, so the two readers that can see these suites are the two that are not the
   gate. Check each epilogue against `banner_complete` itself.
2. **Derive the trailer delta, do not predict it.** Lift `summarize_all` out of
   `run_regression.tcl`'s own text and run its regexp arms over each suite's real captured output on
   both arms. Two parties reasoning carefully about registration shape have both been wrong about
   `skips=`, because only a **lowercase** `^skip:` is counted.

## ⚠ CORRECTION, measured 2026-10-03 — BOTH CONSEQUENCE CELLS ABOVE WERE FALSE

The table claims `BM05` and `GT8` are what hold those two arities. They are not. Row **`WD4` of
`test_calc_wave_dest.tcl`** — already in `hcases`, already gating every commit — pins both, with
`[llength [pcall info args ::wviewer::plot_signals]]`, which no comment and no reflow can satisfy.
Sabotage-confirmed on the counted arm: HEAD gives `ALL PASS (124 checks)`; a five-formal
`plot_signals` gives `2 FAILED (122 passed)` with `FAIL: WD4 … -> {3 grid 5 {token exprs} …}` and
`FAIL: WD12 … -> {{} {} 1 0 {} 5 0}`. It reddens on a fourth `graph_props` formal too.

So this issue was right about the **mechanism** and wrong about **who holds the line**, and the
arity was never actually unfenced. What the stage did find is worse and is filed as **issue 1646**:
`BM05`'s own pin was **dead and read as live**, satisfied by the comment written to explain it.

## Fixed

All three suites are registered — `test_wave_sigbrowser` in `hcases`, `test_wave_grid` in **both**
lists, `test_node_token_split` in `hcases` — in the commit that files issue 1646. Two of them were
structurally unregisterable first: neither emitted the `OVERALL: ok` sentinel `banner_complete`
requires, so registering them as they stood cost **six** counted failures (four `HARNESS:` lines
plus rows `RB2` and `RB4` of `test_registered_banner_1626`). One additive
`puts "OVERALL: ok ($npass checks)"` per suite, above the existing `RESULT:` line and inside the
`$fail == 0` branch, cleared all six — the same additive fix issue 1615 applied to `wvbs_finish`.

`test_wave_sigbrowser` went to `hcases` **alone** on purpose: its display arm carries a measured
flake (issue **1647**), and end-anchoring the call-site legs moved the coverage that arm uniquely
held onto the counted arm instead.

## Outstanding

1. `test_wave_sigbrowser_sea` is registered in nothing and owns the behavioural surface over
   `wviewer::browser_sea_plot_idx`; the arity of that door is now fenced structurally on the counted
   arm, but nothing exercises its behaviour in a gate.
