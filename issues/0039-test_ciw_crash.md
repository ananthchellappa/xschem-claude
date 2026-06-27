# Issue 0039 — test_ciw.tcl aborts with crash if run with --nolog (wrong invocation)

**Opened:** 2026-06-27
**Status:** FIXED (2026-06-27) — guard added; correct invocation documented.
**Affects:** tests/headless/test_ciw.tcl
**Severity:** low — correct invocation (--logdir, not --nolog) works fine
**Branch:** fluid-editing

**Repro:**
  1. Run: DISPLAY=:0 ./src/xschem --pipe --nolog --script tests/headless/test_ciw.tcl
  2. FAIL: CIW toplevel exists → then crash at [.ciw.l.t cget -state]

## Root cause
--nolog suppresses ciw_create. The test continued past the FAIL and crashed on
absent .ciw.* widgets. The correct invocation is:
  DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) \
      --script tests/headless/test_ciw.tcl

## Fix
Added early-exit guard after the first failing check so wrong-flag runs fail
cleanly (FAIL + FATAL + exit 1) instead of crashing mid-script.

## Acceptance criteria
- Run with --nolog: fails cleanly (no crash)
- Run with --logdir: passes all checks
