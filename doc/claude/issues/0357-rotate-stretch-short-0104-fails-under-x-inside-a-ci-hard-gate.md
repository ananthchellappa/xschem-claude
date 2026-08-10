# 0357 — test_rotate_stretch_short_0104 fails under X, inside a CI hard gate

**Status:** OPEN — measured, not fixed. Ownership undecided (see below).
**Filed:** 2026-08-09, out-of-band during the 0354 item (harness/classifier work).
**Not caused by that item:** its diff is four files — `full_audit.sh`,
`test_audit_classifier.tcl`, `test_placement_wire_gate.tcl`, `ci.yaml` — zero C source, and
the binary is unchanged. Both the OLD and the NEW classifier score this suite FAIL on the
identical captured blob.

## What was measured

Three independent measurements (Implement, Verify-A, Write-up), same result each time:

    $ GUI_GATE=0 xvfb-run -a ./src/xschem --pipe -q --nolog \
        --script tests/headless/test_rotate_stretch_short_0104.tcl
    FAIL: rot180-ip (-30,70): no NEW dangling endpoints
          (pre={-550 160} {-550 120} {-420 -300}
           post={-550 160} {-550 120} {-420 -300} {-120 -50})
    RESULT: 1 FAIL (76 checks)
    OVERALL: FAIL
    ec=1

A 180-degree in-place rotation creates a NEW dangling wire endpoint at `{-120 -50}` that was
not there before. The other 75 checks pass.

## Why it was never seen

The suite **self-skips headlessly** — `SKIP: no viewable X window (.drw); the 0104
stale-anchor short test needs a real display` — so it has never been in any driver tier
baseline, and every routine run in this repo is headless.

## Why it matters

`test_rotate_*.tcl` is **globbed into CI's hard "Fluid suites gate (xvfb)"**
(`.github/workflows/ci.yaml`), whose exit condition is `FAIL+CRASH > 0`. If it reproduces on
GitHub runners it is red there now, independently of anything the 0354 item did. It is the
single FAIL among the 40 xvfb blobs captured during that item, under both classifiers.

Not on the run's KNOWN-RED list. Note the list may be stale in both directions: the same xvfb
sweep found `test_fluid_editing` — listed as known-red under X — **passing**
(`RESULT: ALL PASS (26 checks)`).

## Ownership — decide before working it

This is rotate/stretch behaviour, i.e. plausibly the fluid-editing branch owner's territory
(issue numbers 0212-0229 / 0278-0306 are reserved for that branch). It was filed at 0357 only
to claim a number under this run's numbering rule and to avoid a silent drop. Whoever picks it
up should first confirm which branch owns the failing code path rather than assume.

## Not investigated

Whether the new dangling endpoint is a genuine wiring regression or a stale test anchor —
`doc/claude/WIRING.md` is the required reading before touching the rotate/trim/merge path
either way. No wiring code was read or changed for this filing.
