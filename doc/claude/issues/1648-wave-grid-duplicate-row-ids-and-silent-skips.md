# 1648 — `test_wave_grid`: duplicate row ids, and seven skips that can never be counted

**STAMP:** `v1 claim=open tree=060c6d77 stamped=2026-10-03 fix=none open=2`

Status: **OPEN**, found 2026-10-03 by issue 1645's recon.
Area: `tests/headless/test_wave_grid.tcl`.

## Defect 1 — `GS0`/`GS1`/`GS2`/`GS3` name rows in **two** different bands

The ids `GS0`–`GS3` are used in the spec-reconcile text band **and** in the display-only `GG*`
band. So a verdict line reading `FAIL: GS2 …` does not say which band failed, and a reader
diagnosing a gate red has to guess or re-run. Row ids are the only coordinate a verdict carries;
a duplicated one is a coordinate that does not resolve.

This matters more now than it did: the suite is being registered in **both** lists (issue 1645),
so the same id can appear in two different case blocks of the same verdict.

## Defect 2 — seven skip sites, all spelled uppercase, so up to 125 checks can vanish silently

`/usr/bin/grep -nE 'SKIPPED|skip:'` finds seven sites, at lines 862 (the gate), 907, 998, 1026,
1340, 1388 and 1397 at `060c6d77` — **every one of them uppercase** (`SKIPPED:`).

`summarize_all` counts only **lowercase** `^skip:`. So this suite can **never** contribute to the
trailer's `skips=` figure. Registered in `dcases`, a run where the canvas never maps or the menubar
is not found drops up to **125 checks** while the verdict still reads
`counted_failures=0 skips=8`.

⚠ That is the half of issue 1487 the trailer was built to close. CLAUDE.md states it plainly —
*"`counted_failures=0` is a claim about correctness, not about coverage"* — and the remedy is the
one the uppercase/lowercase distinction has already taught this tree four times: **announce a
skipped row in the spelling the instrument counts**, or the coverage number is silently wrong.

This is not the same as the deliberate uppercase announcements elsewhere in the tree. Those are
suites whose headless arm is *not run at all* for a `dcases`-only entry, where the spelling is
genuinely moot. Here the suite runs on both arms and can drop rows on either.

## What is NOT claimed

Neither defect is currently causing a red: both arms are green at `060c6d77`
(counted `ALL PASS (275 checks)`, display `ALL PASS (400 checks)`, rc 0, zero `FAIL` lines). These
are a legibility defect and a coverage-reporting defect, not a correctness one.

## Outstanding

1. Renaming one of the two `GS*` bands.
2. Deciding, per site, whether each of the seven skips should announce lowercase so the trailer
   can see it.
