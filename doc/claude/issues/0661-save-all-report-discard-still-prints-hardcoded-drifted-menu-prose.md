# 0661 — `save_all_report_discard` still prints hardcoded, drifted menu prose

Status: OPEN (measured, NOT fixed) — **R-0653-d req 2 is met for the nudge and unmet here**
Filed by: the 0650 write-up pass, 2026-08-23, from the adversary leg's finding.

## The rule this breaks

R-0653-d req 2: *"The menu path must be derived from the live menu, or asserted
against it — never hardcoded prose. Real labels carry ellipses. A hardcoded
'Outputs > Save All' that drops the ellipsis or misses a cascade level is a wrong
direction printed with authority, which is worse than printing none."*

Issue 0650 deleted exactly that failure from the gate-off nudge. It did **not**
delete it from `ase::ui::save_all_report_discard` (`src/ase_window.tcl:3016-3026`)
— the **discard** notice, which is one of the four messages 0650's own acceptance
**A3** names by name, emitted through this very channel, **90 lines** from the
constants that were added to prevent it. `src/ciw.tcl`'s header and
`src/ase_window.tcl:2864`'s header both claim *"ONE SOURCE FOR THE THREE LABELS"*;
that claim is measurably false today.

## Measured (headless, current tree)

```
NUDGE menu path : Outputs > Save All… > Save device OP parameters (gm, gds, vth, ...)
DISCARD contains lbl_save_all       : 0
DISCARD contains lbl_save_op_params : 0
```

The discard sentence says `Reopen Outputs > Save All and press OK.` — **ellipsis
dropped** — and labels the row `'Save device OP parameters'` — **parenthetical
dropped**. Two live spellings of the same two labels, in one process, in one file.

A third, lower-severity copy sits at `src/ase.tcl:3662` (a deck comment).

## Why it was not fixed in the write-up pass

The honest fix needs two more constants (`lbl_save_all_v`, `lbl_save_all_i` — the
discard proc labels all three blankets, not just `opparams`), the proc routed
through them, and a **W1t-shaped** row that asserts the discard sentence against
the **live widgets** rather than against the constants. Writing constants and a
test at write-up time, with no red-first leg, is how a tautology ships. The
existing `*Outputs*Save All*` matcher rows would **not** catch the drift — SAB-N7
proved that: sabotaging the remedy back to `{Outputs > Save All}` left every one
of those older rows green and reddened only W1t and F19o.

## Acceptance for the fix

1. `save_all_report_discard`'s sentence contains `[ase::ui::lbl_save_all]`
   **including** the `…`, asserted against the live menu entry's
   `-label` — not against the constant.
2. Its per-blanket labels equal the live checkbuttons' `-text`.
3. Sabotaging any one constant back to its drifted spelling reddens that row.

## Still open

All of it.
