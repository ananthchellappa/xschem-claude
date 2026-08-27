# 0855 - the waveform viewer's value readout shows `0` on a still-running simulation

**Status:** OPEN, **measured**, not fixed. Filed 2026-08-26 by the 0852 crew, as a
SIBLING of [0852](0852-get-raw-value-has-no-lower-bound-so-a-zero-point-database-sigsegvs-raw-pos-at.md)
and a cousin of [0836](0836-update-op-segfaults-on-a-zero-point-database.md).
**Severity is much lower than either**: 0852 was a process death, this is a wrong
number on screen. It only became visible BECAUSE 0852 was fixed — before the fix
the process died before it could print anything.

## What the user sees

Start a simulation, open the waveform viewer while it is still running, move the
cursor. The readout bar says **`0`** for every trace.

There is no data yet — ngspice writes `No. Points: 0` into the raw header when a
run STARTS and backfills the real count only when it ENDS, so for the whole
duration of every run the file on disk is a well-formed zero-point raw (0836 has
the full mechanism). "No data yet" is the honest answer. `0` is a number the
database does not contain, on a readout the user reads as a measurement.

This is the same class as **RULING D5-1** — never put a fabricated number in
front of the user — which 0836's `update_op()` refusal exists to enforce on the
schematic annotation. The readout bar is the other surface, and it does not.

## Mechanism (source-confirmed)

`wviewer::interp_value` (`src/wave_viewer.tcl`) asks the engine for a position,
gets `-1` ("not found") from `raw_get_pos()`, and takes its `pos < 0` boundary
arm — RULING D4-4's "hold, never extrapolate" — which clamps to the nearest end:

    if {$pos < 0} {
      set s0 [xschem raw value $sweep 0]
      set sl [xschem raw value $sweep [expr {$n - 1}]]
      ...
      return [xschem raw value $var 0]
    }

That arm is correct for its intended input: a cursor dragged off the end of a
real sweep. It has no way to distinguish that from **a sweep with no points at
all**, because `$n` is 0 and nothing in the proc tests it.

`xschem raw value` then supplies the `0`. Its dispatcher arm (`src/scheduler.c`)
is bounded correctly —

    if( (dataset >=0 && point >= 0 && point < raw->npoints[dataset]) ||
        (dataset == -1 && point >= 0 && point < raw->allpoints) ) {
      val = get_raw_value(dataset, idx, point);
      ...
    } else if(xctx->raw->cursor_b_val) {
      val = xctx->raw->cursor_b_val[idx];      /* <-- this is the 0 */

— so with `allpoints == 0` the bound correctly refuses, and the **fallback** hands
back `cursor_b_val[idx]`, which is `my_calloc`-zeroed and was never filled
because `update_op()` refused this database (0836). The fallback exists so that
a `raw value` with no explicit point returns the cursor's value; it is not
wrong in itself, it is just indistinguishable from a real reading of 0.0 by the
caller.

## Measured, at the 0852 commit, `--nogui --pipe`

Fixture `L` = a well-formed zero-point transient (a running `.tran`), the same
builder `tests/headless/test_zero_point_pos_at_0852.tcl` uses:

    M| L iv = 0
    M| L values=() value0=0

`xschem raw values v(a) 0` correctly answers **nothing** — the empty database
reports itself honestly through that door. `xschem raw value v(a) 0` answers
`0`, and `interp_value` answers `0`.

Pinned as check **`V2c`** in `tests/headless/test_zero_point_pos_at_0852.tcl`,
labelled `OBSERVED (sibling, not fixed here)`, so that fixing this REDS that row
rather than passing silently.

## The fix shape, and the ruling it needs first

The narrow fix is one test in `wviewer::interp_value`: if `$n <= 0`, there is no
value at any x, so return nothing rather than entering the boundary arm. The
readout then needs a way to render "nothing" — a blank or a dash — which is a
**user-visible presentation decision**, not a code detail, and it is the reason
this is filed rather than fixed:

* **(a)** blank the reading (show the trace name with no number),
* **(b)** show a placeholder such as `--`,
* **(c)** show a short phrase once, e.g. `no data yet`, the way 0836's refusal
  sentence explains itself,
* **(d)** leave it as `0`.

⚠ Whatever is chosen, the *engine* side should probably not change: `xschem raw
value`'s cursor fallback is used by other callers and narrowing it here would be
0836's "narrow vs wide" question all over again on a different function.

## Acceptance if fixed

1. Readout on a zero-point database renders the chosen "no data" form, not `0`.
2. **Positive twin.** Readout on a finished multi-point database is unchanged:
   the interpolation rows `V1b` in the 0852 suite must stay green, including the
   two D4-4 boundary values (a cursor before the first sample and after the last
   one still HOLD, and must not be turned into "no data" by an over-broad test).
3. A `vcd` database still HOLDS rather than interpolating (RULING D4-3) — the
   same proc, a different arm, easy to break from here.
4. Check `V2c` in `tests/headless/test_zero_point_pos_at_0852.tcl` is converted
   from an OBSERVED row into an assertion of the new behaviour, in the same
   commit. It is written to go RED when this lands.
5. Sabotage: restore the `pos < 0` fall-through and confirm row 1 reds.
