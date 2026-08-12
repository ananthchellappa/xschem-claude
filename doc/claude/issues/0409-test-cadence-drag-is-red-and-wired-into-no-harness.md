# 0409 — `tests/headless/test_cadence_drag.tcl` reports 2 FAILED and is wired into no harness

Status: **OPEN** — measured, NOT fixed, cause NOT attributed. Filed by crew item **D10**
(Verify-A), which is not permitted to build and so could not bisect it.
Area: `tests/headless/test_cadence_drag.tcl`; harness wiring in `tests/headless/run.sh`,
`tests/headless/full_audit.sh`, `tests/run_regression.tcl`.

## What was measured

Run under `xvfb` on 2026-08-12 against `src/xschem` `md5 d8f471d7eb014c21f5a815957db97c4e`:

```
RESULT: 2 FAILED   (16 ok)
  FAIL: Ctrl+drag leaves wires behind (detached)
  FAIL: non-cadence plain drag leaves wires behind (enable_stretch=0 stock)
```

The file is tracked, but `grep -rn cadence_drag` finds it in **no** harness — not `run.sh`, not
`full_audit.sh`, not `run_regression.tcl`. Nothing has been keeping it green, so the red is of
unknown age.

## Not attributable to issue 0266 / item D10

The test drives `xschem callback` directly and never calls `xschem move_objects` (its own header
says so); no validator error string appears anywhere in its log; the D10 diff touches only
`src/scheduler.c` inside the `move_objects` branch. It also has no window manager under `xvfb`,
which is a plausible independent cause for a drag test.

## Fix sketch

Someone who may build should restore `src/scheduler.c` from `d99f3791`, rebuild, and re-run — if the
same 2 FAIL appear it is pre-existing (expected). Then either fix the two rows and wire the file
into `tests/headless/run.sh`, or mark it explicitly as GUI-only/WM-dependent and self-`SKIP` when no
window manager is present, the way `test_cadence_stretch_move.tcl` self-skips with no `$DISPLAY`.
An orphan test that nothing runs is worse than no test: it looks like coverage in `ls`.
