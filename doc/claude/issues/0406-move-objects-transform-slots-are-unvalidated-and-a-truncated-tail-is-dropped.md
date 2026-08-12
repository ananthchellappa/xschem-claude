# 0406 — `move_objects` rot/flip/`-anchor` slots are unvalidated and a truncated tail is silently dropped, so a corrupted action-log line replays as a *different* transform

Status: **OPEN** — measured, deliberately NOT fixed. Filed by crew item **D10** (adversary pass)
while fixing **0266**.
Area: `src/scheduler.c` — the positional transform parser inside the `move_objects` one-shot `else`
(the `rot` / `flip` / `local` / `-anchor ax ay` arguments), which sits **after** the 0266 rejecter
and is not covered by it.
Related: **0266** (validated `argv[2]`/`argv[3]` only), **0405** (the sub-verb coordinates),
**0069** / `doc/claude/specs/action_logging.md` (the replay surface this defect lives on).

## The defect

The action-log emitter (`src/callback.c`, `end_move_copy_logged`) writes

```
xschem move_objects <dx> <dy> <rot> <flip> [-anchor <ax> <ay>] [kissing]
```

0266 made slots 2 and 3 refuse a non-number. Slots 4 onward are still `atoi()` reads and a
`k + 2 < argc` bounds test that **silently drops** `-anchor` when the line is short. Measured
against the 0266 fix (`md5 d8f471d7eb014c21f5a815957db97c4e`, 2026-08-12), one wire `N 0 0 100 0`
selected:

```
xschem move_objects 0 0 1 0 -anchor 50 50   rc=0   N 100 0 100 100   (control, full line)
xschem move_objects 0 0 1 0 -anchor 50      rc=0   N 0 0 0 100       <-- anchor DROPPED, wrong pivot
xschem move_objects 0 0 1                   rc=0   N 0 0 100 0       <-- rotation DROPPED entirely
xschem move_objects 0 0 X 0 -anchor 50 50   rc=0   N 0 0 100 0       <-- atoi("X")=0, rotation dropped
xschem move_objects 0 0 1 0 -anchor X 0     rc=0                     <-- pivot silently (0,0)
xschem move_objects 40 40 GARBAGE           rc=0   N 40 40 140 40    <-- trailing argument ignored
```

## Why it matters

Item D10 existed because **replay is the autograder substrate**. The half of the emitted line that
carries the *geometry* is the unvalidated half: truncating an emitted line by one token replays as a
rotation about the wrong pivot, with rc 0 and no diagnostic — exactly the failure mode 0266's first
write-up claimed was closed. `doc/claude/specs/action_logging.md` and `doc/claude/WIRING.md` were
narrowed to point here rather than claim coverage.

Nothing pins the trailing-argument tolerance either (`40 40 GARBAGE`), so a future edit that starts
consuming that slot has no witness row.

## Fix sketch

Two separable pieces:

1. **Type**: run `move_objects_slot_is_number()` (file-static, added by 0266) over the `rot`/`flip`
   and `-anchor ax ay` arguments and reject by name, same message shape.
2. **Arity**: an `-anchor` with fewer than two following arguments must be an error, not a silent
   drop; likewise an argument the parser recognises no meaning for (today ignored) should be
   refused, or at minimum pinned by a test row so the tolerance is deliberate.

Positive controls that must stay green: `0 0 1 0 local`, `0 0 1 0 -anchor 0 0 kissing`
(`test_label_ride.tcl`), `40 60 1 0 -anchor 100 100` and `40 60 1 0 local`
(`test_rotmove_drop_log.tcl` T1–T8/T12), and the emitted-line round trip in
`tests/headless/test_action_replay.sh`.
