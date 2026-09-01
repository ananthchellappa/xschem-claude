# 0852 - `get_raw_value()` bounds `point` from ABOVE only, so a zero-point database SIGSEGVs `xschem raw pos_at`

**Status:** **FIXED 2026-08-26**, measured, suite green, sabotage matrix run in
four directions. Filed 2026-08-26 by the 0836 crew as a SIBLING of
[0836](0836-update-op-segfaults-on-a-zero-point-database.md), which shipped an
`update_op()`-local guard by ruling and deliberately did **not** widen to cover
this. Reachable from the shipped wave viewer. See **WHAT SHIPPED** at the bottom.

⚠ The fix does **not** settle 0836's open *ruling* (narrow vs wide). It takes the
narrow option one call site further because the narrow option was the one in
force; if the user later rules *wide* (a zero-point raw never attaches at all),
these guards become belt-and-braces rather than load-bearing, and nothing here
has to be undone.

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
`tests/headless/test_zero_point_raw_0836.tcl`, which asserted the crash on
purpose so that closing this issue would RED that row and force it to be turned
into a survival assertion. `R8a` asserts the fixture really is the zero-point
database, so the row could not pass vacuously on a fixture that failed to load.
**That conversion has since happened** — see WHAT SHIPPED below; `R8b` now
asserts survival and `R8c` was added beside it. The tripwire worked exactly as
designed, which is the argument for writing them.

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


---

# WHAT SHIPPED (2026-08-26)

## The change: two guards, in two functions, both in `src/save.c`

**1. `get_raw_value()` — the root.** The lower bound the rest of the tree already
has. The two arms were **merged** rather than each given its own test:

```c
    if(dataset >= 0) {
      for(i = 0; i < dataset; ++i) {
        ofs += xctx->raw->npoints[i];
      }
    }
    if(point >= 0 && ofs + point < xctx->raw->allpoints) {
      return xctx->raw->values[idx][ofs + point];
    }
```

Merging is the substantive part, not a tidy-up. The `dataset == -1` arm gives
`ofs == 0`, which reproduces the old upper bound exactly; `dataset < -1` gives
`ofs == 0` too, which is what the old `else` arm's zero-iteration loop produced.
**Behaviour is bit-identical to the old code for every non-negative point** — the
positive twin below is 31 measured lines that did not move — and there is now
exactly **one** dereference site under exactly **one** bound, so this issue's own
worry that "a fix can land on one `if` and not the other" is no longer a thing
that can happen.

**2. `raw_get_pos()` — the caller half.** A search over a dataset with no points
has no answer, so it says so instead of clamping the window to
`npoints[dset] - 1 == -1` and asking for point -1 anyway:

```c
    if(!raw->npoints || raw->npoints[dset] <= 0) return -1;
```

`-1` is this function's own "not found", the value `x` is already initialised to.
The `npoints` NULL test is not decoration: `sch_waves_loaded()` (`src/draw.c`)
gates this function and tests `raw->values`/`names`/`schname` and `raw->level`,
never the point count and never `npoints` — the same outer-array-only shape as
0836's defect.

**The two guards are deliberately redundant.** Either one alone stops the
SIGSEGV. That is measured, not assumed — see sabotage A1 and A2 below.

## Acceptance, row by row

| # | Row | Where | Result |
|---|---|---|---|
| 1 | zero-point `raw pos_at` returns, exit 0, sentinel prints, no `FATAL` | `R1a`-`R1n` | **PASS** |
| 2 | positive twin: a good multi-point database answers exactly as before | `P6`-`P9`, `R2a`-`R2f` | **PASS** |
| 3 | `get_raw_value()` refuses any negative point on both arms | `R3a`-`R3d` | **PASS**, *structurally* — see below |
| 4 | `R8b` in the 0836 suite converted from crash to survival, same commit | `R8b`, `+R8c` | **PASS** |
| 5 | sabotage both directions | 4 directions, below | **PASS** |

### Row 1 went wider than asked

The issue asked for the defaulted call. `R1h`-`R1n` also cover the explicit
`dset` argument, a dataset index out of range, a negative dataset, an explicit
`from_start`/`to_end` window, a window past the end, **and** searching for the
value `0.0`. That last one is not padding: with `vstart == vend == 0.0` the range
test `sign*value >= sign*vstart && sign*value <= sign*vend` is TRUE, so `0.0` is
the one search value that used to *enter* the bisection loop on an empty dataset
rather than being rejected by the range test. A fix tested only with `1.0` would
have left the loop unexercised.

`R1d`-`R1g` repeat the whole thing on a zero-point **transient**, because that is
the database a user actually has open: a `.tran` that is still running is what
leaves a zero-point raw on disk, and a transient is what the waveform viewer is
looking at.

### Row 3 is STRUCTURAL, and that is a deliberate, stated trade

It cannot be behavioural. After this fix **no `xschem raw ...` subcommand reaches
`get_raw_value()` with a negative point at all**: `raw_get_pos()` refuses the
empty dataset first, `raw value` and `raw set` already spell `point >= 0`,
`raw values` loops from 0, and the one remaining negative-index site,
`waves_callback()` (`src/callback.c`), needs a GUI event. Asserting it by
behaviour would mean adding a test-only subcommand to the shipped dispatcher,
which is a worse trade than a source-shape row.

So the fix **removes the premise** — the arms are merged — and `R3b`-`R3d` assert
that merge holds: exactly one dereference site, exactly one lower bound, and
neither old upper-only shape surviving. `R3a` fails loudly if `src/save.c` cannot
be read, so the rows cannot pass vacuously on an empty string. The extracted body
has its **C comments stripped first** (`regsub`), because the guard is documented
in a comment that quotes the very shapes the rows match — including `draw.c`'s
and `scheduler.c`'s spellings — and matching prose would make the expected counts
depend on how the fix is *described*. That was caught by the row going red at 2.

`R3e`-`R3f` do the same for `raw_get_pos()`'s refusal, and they exist **because
the sabotage matrix measured that nothing else does** (direction A2).

### Row 4, and one row added beside it

`R8b` in `tests/headless/test_zero_point_raw_0836.tcl` was written as a crash
assertion precisely so that closing this issue would red it. It now asserts
survival, and `R8c` was added beside it: the answer must be `-1` ("not found"),
not a fabricated index. Survival alone would pass on a function that answered 0.

## Sabotage matrix — four directions, disjoint red sets

| direction | what was reverted | 0852 red | 0836 red |
|---|---|---|---|
| **A1** | `get_raw_value()`'s lower bound only | 2 — `R3c R3d` | 0 |
| **A2** | `raw_get_pos()`'s empty-dataset refusal only | 1 — `R3f` | 0 |
| **A3** | **both** | 17 — `R1b R1c R1e R1f R1g R1h R1i R1j R1k R1l R1m R1n R3c R3d R3f V2b V2c` | 2 — `R8b R8c` |
| **B** | bound made too aggressive (`point > 0`) | 4 — `P8 P9 R2c R3c` | 3 — `R4o R5c R5j` |

Read this table as the redundancy proof it is:

* **A1 and A2 red ZERO behavioural rows.** Each guard alone is sufficient, so
  removing either one is invisible to every survival and twin row in both suites.
  That is exactly why rows `R3c`/`R3d`/`R3f` had to be structural — without them
  a careless cleanup could delete either guard and every test in the repo would
  stay green while the tree got one edit away from the crash again.
* **A3 brings the SIGSEGV back**, and both suites say so by name.
* **B** proves the twin is not vacuous: an over-tight bound that refuses point 0
  reds the falling-signal search and two fixture read-back rows. Note `P6`/`P7`
  stay green under B — their first sample is `0` either way — which is why the
  fixture read-back is asserted per-vector rather than as one blob.

## A fixture defect fixed in passing (0836's, not this one's)

0836's `S` fixture supplied **nine** doubles for a 3-point × 4-variable transient
and labelled the layout "column-major". The layout is **row-major** (point-major:
per point, all variables in header order), so 3 × 4 = **twelve** doubles were
required. The data area was 72 bytes where the header promised 96, xschem printed
`Warning: binary block is not of correct size`, and the reader ran off the end of
the file: `xschem raw values time 0` answered `0 7.78 1.2` — `v(a)`'s first sample
masquerading as a timestamp — and `v(a)`'s last sample was leftover memory.

No 0836 row asserted `S`'s values, so it passed. But a short fixture is the quiet
version of exactly the hollow-fixture trap that suite's own header forbids, and
the next row to read a number out of `S` would have been reading garbage.
Corrected here, with the comment rewritten to say row-major and to record what
went wrong. The 0836 suite is 73/73 after the change (72 before; `R8c` is new).

`P6`-`P9` in the 0852 suite are the **anti-hollow-fixture rows** that make the
same mistake impossible here: every vector of the multi-point fixture must read
back exactly, per-variable.

## The shipped caller, exercised

`wviewer::interp_value` (`src/wave_viewer.tcl`) is how a user reaches
`raw_get_pos()` — it is the waveform viewer's value readout, and the Tcl `catch`
around it cannot catch a SIGSEGV. Its body is mirrored verbatim into the suite's
fixture file (`src/wave_viewer.tcl` is a Tk file; this is a `--nogui` suite), and
`V0` asserts the shipped proc still makes the call the mirror models, so the
mirror cannot silently go stale.

* `V1a`/`V1b` — the readout on a finished 5-point transient interpolates
  correctly (`0.5 ns` on a 0..4 V ramp reads `0.5`) and holds flat outside the
  sweep (RULING D4-4). This is the positive twin one layer up: if the fix had
  moved `pos_at`'s answers, these numbers would move too.
* `V2b` — **the headline**: the readout no longer kills xschem mid-run.

## Sibling filed, not fixed: 0855

`V2c` records what the readout says *instead* of crashing: **`0`**. That is a
number the database does not contain, shown on a bar the user reads as a
measurement — the same class as RULING D5-1, which 0836's refusal enforces on the
schematic annotation. `interp_value`'s `pos < 0` arm (D4-4 "hold, never
extrapolate") is correct for a cursor dragged off a real sweep and has no way to
tell that from a sweep with no points; `xschem raw value` then supplies the `0`
from the `my_calloc`-zeroed `cursor_b_val` fallback.

Filed as **0855** rather than fixed here because the remedy is a
**user-visible presentation choice** (blank / `--` / a short phrase / leave it),
not a code detail. `V2c` is written so that fixing 0855 REDS it.

## What this fix also covers, without a row of its own

`waves_callback()` (`src/callback.c`) computes
`get_raw_value(dset, idx, xctx->raw->npoints[dset] - 1)` with no point-count test
in its guard chain — the identical `-1` shape, on the identical input. The
`get_raw_value()` lower bound makes it return 0.0 instead of dereferencing. It
needs a GUI event to reach and was **not** reproduced, so it is claimed as
covered by the root fix and nothing more; it is named in the code comment so the
coverage is not folklore.

## Still open on the same input

**[0853](0853-raw-switch-gates-update-op-on-the-outgoing-database-s-point-count.md)**
— `xschem raw switch` gates the republish on the OUTGOING database's point count
while reading `sim_type` off the incoming one. Unaffected by this fix.

## Files

| file | change |
|---|---|
| `src/save.c` | the two guards; 0836's scope note updated to say these are now fixed |
| `tests/headless/test_zero_point_pos_at_0852.tcl` | **new**, 41 checks |
| `tests/headless/test_zero_point_raw_0836.tcl` | `R8b` converted, `R8c` added, `S` fixture corrected — 73 checks |
| `tests/headless/full_audit.sh` | registered in `nogui_tests` |
| `tests/run_regression.tcl` | registered in `hcases` (T1 coverage) |
| `doc/claude/issues/0855-*.md` | **new**, the readout sibling |

## Verification

* `test_zero_point_pos_at_0852` — **41/41**, standalone and through
  `run_suites.sh` (attached to the persistent dev display `:99`, `GUI_GATE=0`).
* `test_zero_point_raw_0836` — **73/73**, same.
* `full_audit.sh` on both — `2 pass 0 fail 0 crash/timeout 0 skip`, 0 leaked
  scratch dirs, 0 tree litter.
* **T1 (`tclsh run_regression.tcl`) — ZERO counted failures.** The 3 `NOGOLD`
  lines are the documented standing state (`create_save`, `open_close`,
  `netlisting` have no committed baseline).
