# 0416 — `test_calc_skeleton` S11 reads pane geometry before WSLg has applied it

Status: **OPEN** — found by the merge-5 `:0` run (loose-ends item 02), diagnosed, deliberately
not fixed there: it belongs to the Calculator batch, which owns `test_calc_skeleton` and its
own `owed.sh` suite debt.
Area: `tests/headless/test_calc_skeleton.tcl` S11 (`:282-300`). **A test defect, not a product
defect** — see "Why the product is innocent".
Related: [0415](0415-two-tests-missing-from-logdir-tests.md) (the sibling loose end),
[0417](0417-test-calc-widgets-r111-pins-a-font-metric-coincidence.md) (the other half of the
same `:0` run), `doc/claude/merge5_loose_ends/receipts/02-merge5-gui-zero-run.md`.

## The defect

S11 asserts the first-open sash proportions:

```tcl
wm geometry .calc 700x800
update idletasks
array unset ::calc::sash
calc::restore_layout
update idletasks
set H [winfo height .calc.pw]
...
set W  [winfo width .calc.pw.bot]
```

`update idletasks` runs idle handlers and processes **no X events at all**, so neither the
`wm geometry` request nor the re-open in S10 (`calc::close` + `calc::open`, a brand-new
toplevel) has been answered by the server when the geometry is read. Under Xvfb the layout is
already settled by then; under WSLg it frequently is not.

Measured on `:0`, 2026-08-15, six runs — **five red, one green**:

```
FAIL: S11 default sash2 near 64% of 777 -> {0} (exp {1}) : FAIL
FAIL: S11 default bot sash near 78% of 1 -> {0} (exp {1}) : FAIL
```

The denominators are the evidence. `H` reads **777** and **657** on different runs instead of
the 800 just requested, and `W` reads **1** — `.calc.pw.bot` had not been laid out at all.
The same six suites on `:99` are 503/503 green every time.

## Why the product is innocent

`calc::restore_layout_body` (`src/calculator.tcl:2217-2255`) already refuses to act on an
unlaid-out pane: `if {$extent <= 40 || $want < 20 || $want > $extent - 20} continue`. With
`extent == 1` every sash is **skipped** and Tk's own distribution is left in place, which is
exactly the documented D4 behaviour. So the window a user sees is never laid out against a
1-pixel pane; only the assertion is.

## The fix this issue asks for

The `test_calc_skeleton` S12 pattern, applied to S11: **wait for the geometry, with real
`update`s, and assert that it arrived** — e.g. poll until `[winfo width .calc.pw.bot] > 1`
and `[winfo height .calc.pw]` has reached the requested size (bounded, a few hundred ms), and
add one named check that goes red when it never does. Do **not** widen the ±14 px tolerance:
that would hide the unlaid-out case rather than exclude it, and a run whose panes were never
laid out must be a red check, not a looser green one.

Same family as 0417 and as the two fixes item 02 did land
(`test_cmdmode_descend_0201` FX0, `test_altf5_ciw` `wait_state`).

## ⚠ S11 is NOT the whole `:0` picture — there are at least two `:0`-only reds here

Added by the item-02 fix round, 2026-08-15. Whoever picks this up must not read the
section above as a complete inventory and go fix one oracle. **Three independent
measurements of the same suite on `:0`, on the same day, at the same commit, found
three different things:**

| who | runs on `:0` | what went red |
|---|---|---|
| item 02 (above) | 6 | **S11** ×2 — `default sash2 near 64% of 777`, `default bot sash near 78% of 1` |
| a reviewer, under concurrent `:0` GUI load | 6 | **S21** ×1, never S11 — `all 22 selectors are on screen at the declared minimum -> {vt=() vf=() it=() if=()} (exp {})` |
| the fix round, quiet display | 5 | **neither** — 4 × `ALL PASS (503 checks)`, 1 × Xwayland abort (`X connection to :0 broken`) |

So the suite has **at least two** `:0`-only failure modes, they surface under
different compositor conditions, and on a quiet display neither may appear at all.
The S21 signature (`vt=() vf=() it=() if=()` — all four selector lists empty) is a
*different* oracle from S11's sash arithmetic and needs its own diagnosis; do not
assume the S11 fix closes it.

Note also the third row: a `:0` run of this suite can die outright with
`X connection to :0 broken (explicit kill or server shutdown)`. That is the
documented WSLg Xwayland abort, not a suite defect — but it means "N/M runs passed"
on `:0` must always be read with the abort count separated out.

The suite's own debt is left **standing** for exactly this reason: one green run on
`:0` does not establish that either mode is gone.
