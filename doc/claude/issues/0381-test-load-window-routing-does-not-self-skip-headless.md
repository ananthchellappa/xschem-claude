# 0381 — `test_load_window_routing.tcl` does not self-SKIP under `--nogui` and reports 4 false FAILs

Status: **OPEN** — measured 2026-08-10 (item D5). Pre-existing; unrelated to the descend work.
Area: `tests/headless/test_load_window_routing.tcl`
Found: while sweeping the descend-adjacent suites headless.

## The defect

The suite needs Tk/X (it drives `xschem callback` dispatch). Its siblings detect that and print

```
RESULT: SKIP (needs Tk/X; xschem callback dispatch)
```

This one does not. Run headless it reports **4 FAILs** (`LR1b`, `LR5b`, `LR5e`, `LR6`); run under
`GUI_GATE=0 xvfb-run -a` it reports `RESULT: ALL PASS (14 checks)`. The headless FAILs are a
harness wart, not a product defect.

## Why it matters

A suite that fails for environmental reasons is indistinguishable, in a log, from one that failed
for a real one — and `full_audit.sh`'s scoring has already been bitten twice by exactly this class
(issues 0350, 0354, 0368). Copy the sibling suites' `has_x` guard and emit the same `RESULT: SKIP`
line.
