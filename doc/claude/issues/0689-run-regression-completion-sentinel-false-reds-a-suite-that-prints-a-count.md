# 0689 — `run_regression.tcl`'s completion sentinel is `^OVERALL: ok$`, so any suite that prints a check count is reported as a HARNESS FAIL while green

STATUS: OPEN — measured 2026-08-25 by the 0683+0684 crew (measure pass), confirmed by
the implement and both verify passes. Filed, not fixed.
FOUND IN: `tests/run_regression.tcl:117`.

---

## 1. The defect

```tcl
set sentinel 0
if {![catch {open ${hc}.log r} rf]} { set body [read $rf]; close $rf; set sentinel [regexp -line {^OVERALL: ok$} $body] }
if {$childcode != 0 || !$sentinel} {
  puts $af "HARNESS: ${hc} did not complete cleanly (exit=$childcode, OVERALL_ok=$sentinel) -- crashed, aborted mid-script, or a check failed: FAIL"
}
```

The regexp is anchored at both ends, so it cannot match a suite whose sentinel line
carries a count. `headless/test_pdk_launcher` prints

```
OVERALL: ok (30 checks)
```

with **zero** failed checks, and T1 duly reports

```
HARNESS: headless/test_pdk_launcher did not complete cleanly (exit=0, OVERALL_ok=0) -- crashed, aborted mid-script, or a check failed: FAIL
```

That is **one of the three FAIL lines in this branch's T1 baseline of record.** The
suite is green; the sentinel format is not.

## 2. Why it is worth a number rather than a shrug

A false red in the top-level tier is a tax on every crew that runs T1: each one has
to re-derive that this line is benign, and the day a *real* failure appears in that
suite it is indistinguishable from the standing noise. The failure mode also grows —
any suite that ever adds a count to its sentinel joins the list silently.

## 3. The fix, not applied here

Relax the anchor to `{^OVERALL: ok( |$)}` (or `{^OVERALL: ok\M}`). Not applied in this
run because T1's FAIL count is the baseline of record for a concurrently-running
batch, and changing it mid-run would make every crew's before/after diff meaningless.
Whoever fixes it should re-baseline T1 in the same commit and say so.

## 4. Still open

The fix, and a sweep of the other headless suites for the same sentinel drift.
