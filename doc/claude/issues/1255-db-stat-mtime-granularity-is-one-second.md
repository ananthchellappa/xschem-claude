# 1255 — `op_annot::_db_stat` is `{mtime size}`, and `file mtime` is one-second granular

Status: **open** (measured by item A4, 2026-09-02; **filed, not fixed** — a fix
touches `src/op_annot.tcl`'s guard family, which item A4's Files cell does not
name) · Branch: `fluid-editing`
Related: **1250** (whose part 2 this is the product half of), **0684**, **0910**,
item **A4** of `doc/claude/op_param_batch/PLAN.md`

## The measurement

`op_annot::_db_stat` (`src/op_annot.tcl:1136`) answers `{mtime size}`, and Tcl's
`file mtime` has **one-second** resolution. `op_annot::db_current` compares that
stamp against the candidate's current stat, so the freshness question the whole
0684 family rests on cannot resolve anything finer than a second. It fails in
**both** directions:

* **A same-second rewrite is invisible.** A re-run that finishes inside the same
  wall-clock second as the last stamp, at the same path and the same size, reads
  as unchanged — so the sheet keeps painting the previous run's numbers under
  "These results were already loaded", which is issue 0684's own headline
  defect. `tests/headless/test_annot_stale_0684.tcl:55-57` already states this as
  a known, unremoved limitation; this issue is where it is filed rather than
  only commented.
* **A byte-identical rewrite one second later forces a needless re-read.** The
  stamp mismatches, `src/op_annot.tcl:1354-1358` answers 0, guard G11 detaches,
  and the selector re-attaches the file the user was already looking at. Nothing
  is wrong on screen afterwards, but the sentence changes from "These results
  were already loaded" to "Loaded results from <path>." for a file whose bytes
  never changed.

## How it was measured (item A4, 2026-09-02)

The second direction is what made the T1 red of issue 1250 intermittent, and it
was forced on demand rather than reasoned about. Inserting one `f_bump`
(`after 1100`) before row F20's byte-identical rewrite of `$F_RAW` in a scratch
copy of `tests/headless/test_annot_stale_0684.tcl` reproduces, byte for byte,
the failure line issue 1250 quotes from a real `run_regression.tcl` run:

```
FAIL: F21 CONTROL an already-loaded operating point is published by the press,
      and nothing is taken off or re-read behind it
      -> {{0 {-1 0 -1}} 0 1 1} (exp {{0 {-1 0 -1}} 1 1 1}) : FAIL
```

The natural window between row F19's stamp and row F20's rewrite was timestamped
at **0.7–1.5 ms** on the `--nogui` arm and **9.8–10.9 ms** on the display arm,
i.e. about **1.1% of T1 runs** land on the losing side of the clock — which is
the whole of what issue 1250 called its "unexplained" half.

## What item A4 did and did not do

A4 fixed the **test** half: row F21 now mints its own stamp
(`::op_annot::_db_stamp`) inside its own staging, so the row's subject is what
the press does rather than what the clock did between two earlier rows, and new
row **F49** is the deterministic twin that reds every time the staging is
removed. Verified: with every fixture write in that suite separated by a forced
one-second tick (65 writes), the suite is still `ALL PASS`.

It did **not** touch `_db_stat`. That is this issue.

## Candidate repairs, none of them measured yet

1. **Add a content digest to the stamp** — `{mtime size md5}` or a cheap hash of
   the header. Closes both directions; costs a read of the file on every stamp,
   which is the thing guard G11 exists to avoid.
2. **Compare on size + mtime + a monotonic "we wrote this" token.** Only the
   publisher knows a rewrite happened; a stamp minted at publish time cannot be
   fooled by a same-second re-run it did not do.
3. **Treat "same size, mtime differs by <= 1 s" as unchanged.** Cheapest, and it
   makes the second direction go away without touching the first — but it widens
   the first direction's blind spot by a second in the other direction, so it
   trades a needless re-read for a stale number, which is the wrong way round
   under invariant I3 / RULING D5-1.

Nothing here is a recommendation. The measurement is the deliverable; the choice
needs a bench where the simulator, not a test fixture, is doing the writing.

---

## A7 attempt, 2026-09-03 — **`[F]`, reverted. This issue stays OPEN.**

Item **A7-c** implemented the fix and it **worked for the shape asked**:
`op_annot::_db_stat` returned `{mtime size fingerprint}`, the fingerprint being
a `zlib crc32` over a bounded window (whole file at ≤ 8192 bytes, else head 4096
+ tail 4096, read binary); a sampling failure answered `{}` = UNKNOWN so
`db_current` re-reads; a `zlib`-less interpreter degraded to `{mtime size}` out
loud. Driven: a same-second, same-size, different-bytes rewrite moved the stamp
(`66994941 -> 2796787623`) and `db_current` answered 0, where before it answered
1 and the sheet kept painting the previous run's number. Cost re-measured at
3.7 µs (276 B) and 5.0 µs (1,218,048 B), inside row F35's budget.

**It was reverted with the rest of A7**, whose A7-a leg was refuted (issue
**1270**). Nothing here needs re-deriving — the implementation, rows F50 and F51,
and the cost table are all in
`doc/claude/op_param_batch/A7_working_tree_REFUTED.patch`.

**Two corrections the re-do must carry**, both measured by A7's adversary:

1. The comment A7 wrote reads `⚠ THE ONE-SECOND HOLE IS CLOSED -- ISSUE 1255`.
   It is closed for files ≤ 8 KiB and for changes touching the first or last 4096
   bytes. **Reword the headline**; the residue paragraph below it is accurate.
2. The blind middle is **82 % of a 45 KB raw** (a same-second, same-size,
   one-value rewrite at offset 29050 left the fingerprint identical at
   `1286397804`) and **99.3 % of F35's 1.2 MB fixture**, and ngspice binary raws
   are same-size by construction across a re-run with the same vector set.
   Widening the window is not free: a full-file crc32 measures **258 µs** against
   a 5 µs baseline and reds F35's `big <= 3*small + 100` leg. `exec stat -c %.9Y`
   measures 1460–1772 µs, reds two more legs, forks per press and is GNU-only.
