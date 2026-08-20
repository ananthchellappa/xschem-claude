# 0465 — the whole op_annotation suite is invisible to `tclsh run_regression.tcl`

Status: OPEN (measured by S9's RED pass, not fixed)

> ⚠ **Counts here are the S9-attempt-1 numbers (192 checks).** That step was
> reverted (issue **0466**) and the suite is back to **172** checks, so the gap
> this issue describes is unchanged and the fix line is now safe to add on its
> own: with S9 out of the tree the suite is green, so wiring it into
> `run_regression.tcl` no longer has to wait for an implementation.
> ⚠ And it is worse than stated: Verify-B measured that stubbing the **draw.c**
> renderer reds NOTHING headless — the screen path needs the DISPLAY leg, not
> just the headless one.
Found: S9 of doc/claude/specs/op_annotation.md. Subject: `tests/run_regression.tcl`
and `tests/headless/test_op_annot.tcl`.

`tests/headless/test_op_annot.tcl` is the ONLY guard on the whole OP-annotation
feature — 192 checks after S9's section O, covering S1's name builder, S2's three
PDK descriptors, S5's formatter, S6's carrier, S7's `text_hidden()` refactor
across five .c files, S8's three keys and S9's draw-time overlay. It is named in
`tests/run_regression.tcl` **nowhere**:

    $ grep -c op_annot tests/run_regression.tcl        -> 0
    $ grep -c op_annot tests/headless/run.sh           -> 0
    $ grep -c op_annot tests/headless/run_suites.sh    -> 0   (run_suites takes
                                                               names as argv; it
                                                               enumerates nothing)

Measured, and this is the sharp part: with section O's **17 deliberately red
rows** committed, a full `cd tests && tclsh run_regression.tcl` still reports
exactly the pre-existing 3 FAIL / 0 GOLD? / 0 RESULT? / 0 FATAL / 3 NOGOLD.
T1 cannot see the feature at all, in either direction — it would not have shown
S9's RED and it will not show a later regression that turns 192 checks red.

Every step S1-S8 ran the suite by hand
(`./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_op_annot.tcl`),
which is why the gap survived eight steps: the tier that a crew reads as "the
baseline" and the tier that actually covers this feature are different tiers,
and nothing says so out loud.

⚠ Two rows of the suite SELF-SKIP under `--nogui` (M1/M2, and now O14) because
their subject sits inside `if(has_x)`. Adding the suite to run_regression's
headless list gets the other 189; the display leg still needs
`DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog --script …`.

Fix shape: one line in `tests/run_regression.tcl`'s headless list
(`"headless/test_op_annot"`), then re-measure T1 — the suite is red on purpose
until S9's implementation lands, so the line must go in with (or after) the
implementation, never before it, or T1's baseline moves for a reason unrelated
to whatever the next crew is measuring.

⚠ NOT filed as an S9 blocker and NOT fixed here: S9's Files cell is draw.c /
svgdraw.c / psprint.c, and a RED agent that quietly rewired the tier-1 runner
would have changed what every later agent in this run measures against.
