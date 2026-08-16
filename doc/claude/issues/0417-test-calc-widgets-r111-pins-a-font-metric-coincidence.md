# 0417 — `test_calc_widgets` R111's fixture pins a font-metric coincidence, and is red on `:0`

Status: **OPEN** — found by the merge-5 `:0` run (loose-ends item 02), diagnosed, deliberately
not fixed there: it belongs to the Calculator batch, which owns `test_calc_widgets` and its own
`owed.sh` suite debt.
Area: `tests/headless/test_calc_widgets.tcl` CW11, the check
`R111 fixture: the window really grew (or the two legs above are vacuous)` (`:1042`).
**A test defect, not a product defect.**
Related: [0416](0416-test-calc-skeleton-s11-reads-pane-geometry-before-wslg-has-applied-it.md),
`doc/claude/merge5_loose_ends/receipts/02-merge5-gui-zero-run.md`.

## The defect

The check is a three-way conjunction:

```tcl
check_expr "R111 fixture: the window really grew (or the two legs above are vacuous)" \
    {[wh .calc.pw.bot] > $_both0 && [ww .calc.pad] == [wrw .calc.pad] && $_both0 > 0}
```

On `:0` it fails **7 runs out of 7** (2026-08-15) while passing 7/7 on `:99`. A probe that
replays the same resize and prints each conjunct separately names the offender — it is not the
"really grew" half at all:

```
:99   before: pad_h=198 pad_w=128 pad_reqw=128 bot_h=227
      conj1 bot_h>both0 : 1 (374 vs 227)   conj2 pad_w==pad_reqw : 1 (128 vs 128)
:0    before: pad_h=198 pad_w=128 pad_reqw=116 bot_h=227
      conj1 bot_h>both0 : 1 (374 vs 227)   conj2 pad_w==pad_reqw : 0 (128 vs 116)
```

`.calc.pad`'s **requested** width is 128 on the Xvfb dev display and **116** on WSLg, because
it is derived from the key buttons' font metrics and the two servers do not have the same
default font. Its **allocated** width is 128 on both, because
`.calc.pw.bot.pad` carries `-minsize 140` and `calc::apply_pane_minsize` only ever *raises*
that floor. So on `:99` the floor and the request happen to coincide to the pixel — the
condition `src/calculator.tcl:2035-2076` documents in as many words ("140 == 140 IS ZERO
SLACK") — and on any display with slightly narrower text the pane is 12 px wider than its
contents ask for, which is the floor doing its job.

`[ww .calc.pad] == [wrw .calc.pad]` therefore does not test R111 ("the keypad keeps its natural
width"); it tests that this display's fonts make the contents exactly equal the documented
minimum.

## The fix this issue asks for

State the rule instead of the coincidence. R111's claim about width is that the keypad does not
take horizontal **growth**, so the honest oracle is that `[ww .calc.pad]` is **unchanged across
the resize** (and `-stretch never`, which the leg above already checks) — true on any font, and
still red the moment the keypad starts stretching. The "really grew" conjunct
(`[wh .calc.pw.bot] > $_both0`) is sound and should stay.

## Not to be confused with

The pane floor itself. 140 is deliberate and measured (`src/calculator.tcl:2044-2070`); the
12 px of slack on WSLg is that floor working as designed, not a layout bug.
