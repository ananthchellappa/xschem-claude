# 0852 - `get_raw_value()` bounds `point` from ABOVE only, so a zero-point database SIGSEGVs `xschem raw pos_at`

**Status:** OPEN, measured, **not fixed**. Filed 2026-08-26 by the 0836 crew as a
SIBLING of [0836](0836-update-op-segfaults-on-a-zero-point-database.md), which
shipped an `update_op()`-local guard by ruling and deliberately did **not** widen
to cover this. Reachable from the shipped wave viewer.

## The same input as 0836, a different dereference

0836's input is the ordinary case, not a corner: ngspice writes `No. Points: 0`
into the raw header when a run **starts** and backfills the real count only when
it **ends**, so for the entire duration of every simulation the file on disk is a
well-formed, untruncated, zero-point raw. `read_dataset()` reads it as a success
with `allpoints == 0`, and `my_realloc(..., 0)` frees and NULLs every
`raw->values[v]` while `raw->values` itself stays non-NULL.

0836 closed `update_op()`. **This is a second, independent SIGSEGV on the same
database**, and 0836's guard does not touch it.

## Measured, at the 0836 commit, `--nogui --pipe`

Fixture: a hand-written well-formed zero-point Operating Point raw (12-line
header + 4 KB of zeros; the same fixture builder the 0836 suite uses).

    P| 1 Z=1 points=0 loaded=0
    P| 2 about to: xschem raw pos_at v(a) 1.0

    FATAL: signal 11

`P| 4 SURVIVED` never prints. Process exit is 1, not 139, because xschem installs
its own handler for signal 11.

Pinned as a **scope tripwire** by check `R8b` in
`tests/headless/test_zero_point_raw_0836.tcl`, which asserts the crash on purpose
so that closing this issue REDS that row and forces it to be turned into a
survival assertion. `R8a` asserts the fixture really is the zero-point database,
so the row cannot pass vacuously on a fixture that failed to load.

## Mechanism (source-confirmed)

Two functions, and the defect is in the second:

`raw_get_pos()` (`src/save.c`, the `xschem raw pos_at` implementation) clamps its
search window to the last point of the dataset:

    int sign, lastpoint = raw->npoints[dset] - 1;
    start = from_start >= 0 ? from_start : 0;
    end   = to_end     >= 0 ? to_end     : lastpoint;
    if(start > lastpoint) start = lastpoint;
    if(end   > lastpoint) end   = lastpoint;
    vstart = get_raw_value(dset, idx, start);

With `npoints[dset] == 0`, `lastpoint` is **-1**, and both clamps drive `start`
and `end` to -1.

`get_raw_value()` (`src/save.c`) then bounds the index from **above only**:

    if(ofs + point < xctx->raw->allpoints) {
      return xctx->raw->values[idx][ofs + point];
    }

`ofs + point` is `0 + (-1)` = -1, `allpoints` is 0, and `-1 < 0` is **true** —
`allpoints` is a signed `int` (`src/xschem.h`), so there is no unsigned wrap to
save it. It dereferences `values[idx][-1]` on a NULL column.

The `dataset == -1` arm three lines above has the identical shape
(`if(point < xctx->raw->allpoints)`), also with no lower bound.

**The missing lower bound is the shared root**, and it is the thing worth fixing:
every other point-index guard in the tree already carries one — `draw.c`'s
`if(point < 0 || point >= xctx->raw->allpoints) goto done;` is the correct shape
verbatim, and `scheduler.c`'s `xschem raw value` / `xschem raw set` arms both
spell `point >= 0 && point < ...`. `get_raw_value()` is the outlier.

`raw_get_pos()`'s own `lastpoint = npoints[dset] - 1` is arguably a second defect
in the same chain: a search over an empty dataset has no answer and should say so
rather than clamp to -1 and ask for it anyway.

## The gate that does not stop it

`raw_get_pos()` runs under `if(sch_waves_loaded() >= 0)`. That is not a point
count: `sch_waves_loaded()` (`src/draw.c`) returns the hierarchy level at which
`raw->schname` string-matches a schematic on the stack, and it tests only
`raw->level != -1` plus non-NULL `values`/`names`/`schname` — the same outer-array
shape as the 0836 defect. A zero-point database passes it. Measured above:
`loaded=0` on the crashing fixture.

## Reachable from the shipped wave viewer

`xschem raw pos_at` is called from `wviewer::interp_value` in
`src/wave_viewer.tcl`, which is reached from the viewer's own value-readout paths.
**The surrounding Tcl `catch` cannot catch a SIGSEGV**, so there is no degraded
mode — the process dies. Combined with 0836's live-raw door, that means a user
watching a running simulation in the waveform viewer is on this path.

## Sibling in the same shape, not separately reproduced

`waves_callback()` (`src/callback.c`) reads a point index derived from
`npoints[dataset] - 1` with `dataset` pinned at 0 and no point-count test in its
guard chain. Same `-1` shape, same root. It needs a GUI event to reach, so it was
**not** reproduced here; it is recorded so a fix for `get_raw_value()` is
understood to cover it, and so nobody re-derives it from scratch.

## Why 0836 did not fix this

0836's open ruling is *narrow* (guard the consumers) vs *wide* (refuse the read).
No user ruling had arrived, so the narrow option shipped, as 0836 recommends —
and narrow means the guard lands at the consumer that was measured, not at every
consumer that might share the shape. Widening silently would have made the 0836
diff something other than 0836. The scope is asserted as a test row rather than
claimed in prose.

**Note the interaction with the ruling**: if the user rules *wide* (a zero-point
raw never attaches at all), this issue and its `waves_callback()` sibling both
become unreachable through the raw reader and the missing lower bound reverts to
a latent hardening item. If the ruling stays *narrow*, this is a live SIGSEGV on
the ordinary path and wants fixing on its own.

## Acceptance if fixed

1. `xschem raw read <zero-point raw> op` then `xschem raw pos_at v(a) 1.0`
   returns normally, **process exit 0**, no `FATAL: signal 11`, and a post-call
   sentinel actually prints. (Exit code alone is not enough: xschem's own
   signal-11 handler makes a crash exit 1, so a test that only looks for 139
   passes on a crashing tree.)
2. **Positive twin.** `raw pos_at` on a good multi-point database still returns
   the same index it returns today, for a value inside the sweep and for one
   outside it. Without this the fix is indistinguishable from "make `pos_at`
   always answer -1".
3. `get_raw_value()` returns 0.0 rather than dereferencing for **any** negative
   `point`, on both the `dataset == -1` arm and the `dataset >= 0` arm — asserted
   separately, since they are two `if`s and a fix can land on one.
4. Check `R8b` in `tests/headless/test_zero_point_raw_0836.tcl` is converted from
   a crash assertion into a survival assertion in the same commit. It is written
   to go RED when this lands, precisely so it cannot be forgotten.
5. Sabotage in both directions: revert the lower bound and confirm rows 1 and 4
   red; make the bound too aggressive (refuse every point) and confirm row 2 reds.
