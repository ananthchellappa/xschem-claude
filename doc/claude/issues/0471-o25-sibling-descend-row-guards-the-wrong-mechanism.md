# 0471 — test row O25 passes on the epoch's `instances`+`currsch` terms, not on the `sim_sch_path` dependency it names

Status: **OPEN, measured, NOT fixed. TEST defect, not a code defect.**
Filed by the S9b write-up agent from the S9b sabotage pass (Verify-B), which
found it while explaining the one predicted red that did not appear.

## What happened

The S9b plan predicted that row **O25** ("two SIBLING instances of one
subcircuit, descended with `keep_symbols 1` and no top-level export between
them, each carry their OWN number") would go **red** under the
`load_flush_off` sabotage variant, which neutralises HOOK A
(`annot_data_changed()` in `clear_drawing()`). It stayed **green** on both arms.

Verify-B did not leave that as an unexplained gap. Instrumented with the
`annot_overlay_flushes` seam on the good binary:

    t1  after descend1   flush=88  inst=1  currsch=1  path=x1.
    t2  after exportA    flush=89
    t3  after go_back    flush=90  inst=2  currsch=0     <- A FLUSH WITH NO EXPORT
    t4  after descend2   flush=90  inst=1  currsch=1  path=x2.
    t5  after exportB    flush=91

`go_back` runs an intervening `annot_overlay_sync()` that **re-stamps the epoch**
at `instances=2 / currsch=0`, so the second descent mismatches on those two
ordinary observed terms. O25's coverage therefore comes from the epoch's
`instances` and `currsch` fields — **not** from HOOK A, and **not** from the
`sim_sch_path` dependency the row is named for.

This directly contradicts the row's own comment, which says

> NO TOP-LEVEL EXPORT BETWEEN THE TWO DESCENTS, DELIBERATELY … Headless there is
> no intervening draw, so this row measures the epoch and not the luck

There **is** an intervening sync headless, so the row measures precisely the luck
it claims to exclude.

## What it is NOT

* It is **not vacuous**: the `cache_frozen` variant (epoch reduced to
  `if(annot_epoch.valid) return;`) reds O25 along with 30 other rows.
* It is **not a live correctness hole**: every descend/ascend necessarily moves
  `instances` and `currsch`, so no real staleness is reachable by this route
  today. The behaviour is safe; the guard is mislabelled.

## Fix shape (not applied)

Either

1. **re-word the comment** to name the terms that actually cover it
   (`instances` + `currsch`), so a later crew does not trust it as the
   `sim_sch_path` guard; or
2. **restructure the row** to defeat the intervening sync — two siblings with the
   *same* instance count at the *same* `currsch`, differing only in
   `sim_sch_path` — if the `sim_sch_path` dependency is to be guarded
   structurally at all.

Option 2 is the one that buys coverage; option 1 is the one that stops the
mislabelling from misleading someone. Do at least option 1.

## Still open

Yes.
