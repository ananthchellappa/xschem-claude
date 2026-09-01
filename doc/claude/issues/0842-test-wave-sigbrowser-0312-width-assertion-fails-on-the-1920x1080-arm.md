# 0842 — `test_wave_sigbrowser_0312` rows BF21a/BF24a fail their WIDTH term while every layout term passes

Status: **OPEN — measured 2026-08-26.** A standing red. Confirmed pre-existing by
re-running at `HEAD` with an unrelated change removed (identical 2 failures).
Related: 0841 (same *class*), and CLAUDE.md's `AUDIT_SCREEN` note — the one
recorded precedent for a suite that passes at one virtual screen size and fails
at another is `test_fluid_bodyshove_guards_0132` at `1600x1200`.

## Measured

`tests/headless/test_wave_sigbrowser_0312.tcl`, on `:99`, `AUDIT_SCREEN`
defaulting to `1920x1080x24`:

```
FAIL: BF21a wide: the bar really got the width, is FLAT — every child packed,
      none gridded, and the pack order is ViVA §3.2's
  ->  {0 0 {7 0} {…type …pat …syntax …case …alldb …search …err}}
  exp {1 0 {7 0} {…type …pat …syntax …case …alldb …search …err}}

FAIL: BF24a widened again: back to FLAT, with BAR03's pack order restored
      byte-for-byte
  ->  {0 0 {7 0} {…} {1 1 1 1 1 1 1}}
  exp {1 0 {7 0} {…} {1 1 1 1 1 1 1}}
```

**Only the FIRST field differs, and it is the width term.** Everything the rows
are actually about is correct and byte-identical to the golden:

* `0` in field 2 — nothing is gridded;
* `{7 0}` — all seven children packed, none gridded;
* the full pack order, in ViVA §3.2's sequence, child for child;
* BF24a's `{1 1 1 1 1 1 1}` — the asymmetric pads survived the re-widen.

And the neighbouring rows pass, including the ones that matter most:

```
ok:   BF21b wide: every control is ON SCREEN
ok:   BF22a (THE DEFECT) flat at the shipped 450 px: All DBs, Search and the …
ok:   BF24b …including the asymmetric pads the build shipped
ok:   BF25a the hysteresis band holds …
```

`BF22a` is labelled **THE DEFECT** by the suite's own author and it is green, so
the behaviour 0312 was opened about is intact. What fails is a precondition:
*"the bar really got the width"* — i.e. the test asked for a wide bar and the
window manager or the virtual screen did not give it one.

## What to check first, in order

1. **Whether it passes at a different `AUDIT_SCREEN`.** One run at
   `AUDIT_SCREEN=2560x1440x24` and one at the default settles whether this is
   screen-size coupling. Cheap, and it is the most likely cause given the row is
   a width precondition.
2. **Whether the WM matters.** `AUDIT_WM=openbox` was only really live from
   2026-08-23 (issue 0645) — a `wm geometry` request for a very wide toplevel is
   exactly the kind of thing a WM can clamp and a bare Xvfb cannot. Any recorded
   *pass* of these rows from before that date was taken WM-less and does not
   transfer.
3. **Only then** treat it as a layout defect.

⚠ **Do not "fix" this by relaxing the width term to accept 0.** That deletes the
precondition and leaves BF21a asserting a layout it never actually put under the
condition it names — a row that passes while proving nothing, which is worse than
a red. If the width cannot be obtained on this arm, the row should **skip**
loudly, not pass quietly.
