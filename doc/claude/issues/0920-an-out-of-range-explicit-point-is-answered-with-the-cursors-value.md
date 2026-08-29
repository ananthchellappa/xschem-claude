# 0920 - `xschem raw value <vec> 99` answers the cursor's value, not "no such point"

**Status:** OPEN, MEASURED, DELIBERATELY NOT FIXED. Filed 2026-08-29 by the
PLAN+RED pass of item **B3** (issue 0861), which measured it while fencing the
over-refusal risk on the same `else if` arm. Number claimed as a stub before the
work started, per house rules.

## What was measured

`src/scheduler.c`, the `xschem raw value <vec> <point> [dataset]` arm. When the
explicit point is OUT OF RANGE the in-range arm does not fire and control falls
through to the cursor-B annotation read, which answers **the value at the
annotation point** under the label of the point that was asked for.

On the B3 fixture (3 points, `v(d)` = 1.8 / 1.9 / 2.0, operating point attached
so `annot_p` is 0):

    xschem raw value {v(d)} 2    -> 2      correct, point 2 exists
    xschem raw value {v(d)} 99   -> 1.8    <-- the OP value, wearing "point 99"

Same class as RULING **D5-1**: a number displayed next to a thing it was not
measured for. It is milder than 0861 because the number is real; what is
fabricated is the *point label*.

## Why B3 did not fix it

B3's guard is `annot_p >= 0` on that fall-through, which is the minimum term
that separates the refused state from the published one. It changes the
out-of-range read only in the state where there is nothing to answer with at
all — after B3, `raw value v(d) 99` blanks on a refused transient and is
UNCHANGED at 1.8 on a published operating point. Row `SGN18` of
`tests/headless/test_spice_get_node_0861.tcl` pins both halves so the behaviour
is decided rather than inherited from where a brace landed.

Making the out-of-range read blank outright is a separate, wider decision: it
would change a published database's answer, and no row in the tree says what
depends on that today.

## Acceptance if fixed

1. `xschem raw value <vec> <point>` with `point >= npoints` answers empty, in
   every state, rather than the cursor value.
2. The point `-1` accessor is unaffected: it is the annotation read and keeps
   answering the published value.
3. `SGN18`'s operating-point half moves from `1.8` to blank, deliberately.
