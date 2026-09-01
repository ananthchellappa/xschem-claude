# 0853 - `xschem raw switch` gates `update_op()` on the OUTGOING database's point count

**Status:** OPEN, measured, **not fixed**. Filed 2026-08-26 by the 0836 crew.
Found while fixing [0836](0836-update-op-segfaults-on-a-zero-point-database.md);
it was one of the three doors to that crash, and closing 0836 closed the crash
but not this. Both remaining halves are measured below.

## One word, two user-visible faults

`src/scheduler.c`, the `raw` dispatcher, snapshots the current database at the
top of the branch, **before** any switch happens:

    Raw *raw = xctx->raw;

and the `switch` arm then does the switch and gates the republish on it:

    } else if(argc > 2 && !strcmp(argv[2], "switch")) {
      ...
      /* only update_op() if switching into a 1-point OP or DC */
      if(ret && raw && raw->rawfile && raw->allpoints == 1 &&
         (!strcmp(xctx->raw->sim_type, "op") || !strcmp(xctx->raw->sim_type, "dc"))) {
        update_op();
      }

The comment states the intent exactly: *only update_op() if switching **into** a
1-point OP or DC*. But the predicate is **mixed**: `allpoints` is read off `raw`,
the **outgoing** database, while `sim_type` is read off `xctx->raw`, the
**incoming** one. `update_op()` then operates on the incoming one.

The `switch_back` arm a few lines below carries the identical predicate and the
identical defect.

## Measured, at the 0836 commit, `--nogui --pipe`

Fixtures: `G` = a good 1-point Operating Point raw (`v(a)=3.14`); `S` = a good
3-point Transient raw.

    P| 1 S=1 pts=3
    P| 2 G=1 pts=1
    P| 3 uop=1 va=3.14 nd=6
    P| 6 --- switch BACK INTO the 1-point op (entry raw = S, 3pt -> gate FALSE) ---
    P| 7 cur_pts=1 sim=op nd=0 va=
    P| 8 explicit update_op=1 va=3.14 nd=6

**Fault 1 — it fails to annotate when it should.** At `P|7` the current database
*is* a 1-point operating point, which is precisely the case the gate exists to
serve, and nothing was published: `ngspice::ngspice_data` is empty. The gate read
`allpoints` off the outgoing 3-point transient and answered false. `P|8` proves
the database was perfectly publishable all along — an explicit `xschem update_op`
publishes `v(a)=3.14` and all 6 entries. So a user who switches from a waveform
database back to their operating point gets a schematic with no numbers on it,
and nothing says why.

**Fault 2 — it annotated when it should not, and that used to be a SIGSEGV.**
The mirror case: outgoing database has exactly 1 point, incoming one has **zero**
(a still-running simulation's raw — see 0836 for why that is the ordinary case).
The gate reads `allpoints == 1` off the outgoing database, `sim_type == "op"` off
the incoming one, both true, and calls `update_op()` on a zero-point database:

    P| 4 switch0=1 cur_points=1 sim=op
    P| 5 about to: xschem raw switch 1   (entry raw=G allpoints==1 op, NEW raw=Z 0pt)

    FATAL: signal 11

That crash is **now refused** by 0836's `update_op()` guard, and the survival is
pinned by check `R7a`-`R7e` in `tests/headless/test_zero_point_raw_0836.tcl`.
But the gate is still asking the wrong database, and 0836's guard is the only
reason the answer no longer matters.

## The fix is one pointer, and it needs its own positive twin

Reading `xctx->raw->allpoints` instead of `raw->allpoints` makes the predicate
ask one database one question. `raw` is then only needed for the `raw->rawfile`
non-NULL test, which should also move to `xctx->raw` — a switch INTO an entry
with no filename is the thing worth skipping, not a switch out of one.

⚠ **Do not "simplify" by deleting the gate.** Calling `update_op()` on every
switch would publish a multi-point transient's point 0 onto the schematic as
though it were an operating point, which is a fabricated number on a schematic —
the outcome RULING D5-1 exists to prevent.

## Acceptance if fixed

1. Switch INTO a 1-point op database from a multi-point transient: publishes,
   `ngspice::ngspice_data` has all 6 entries, `v(a)` is 3.14. (Fault 1 — this
   fails today and is the row that proves the fix does something.)
2. Switch INTO a multi-point transient from a 1-point op database: does **not**
   publish; the array is left as the previous `update_op()` left it, not
   refilled from the transient's point 0.
3. Switch INTO a zero-point database from a 1-point op database: `update_op()`
   is not called at all, so 0836's refusal sentence does **not** appear — today
   it does, because the gate fires and the guard catches it one frame later.
   This row distinguishes "the gate asks the right question" from "the guard
   cleans up after it asks the wrong one".
4. `switch_back` gets the same three rows; it is a separate `if` and a fix can
   land on one and not the other.
5. `R7a`-`R7e` in `tests/headless/test_zero_point_raw_0836.tcl` stay green
   (the switch must still survive a zero-point database).
6. Sabotage both ways: restore the outgoing-database read and confirm row 1 reds;
   delete the gate entirely and confirm row 2 reds.
