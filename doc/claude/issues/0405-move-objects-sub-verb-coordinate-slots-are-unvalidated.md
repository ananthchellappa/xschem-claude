# 0405 — `move_objects end/start/step` coordinate slots are unvalidated: the recommended commit constructor still eats a non-number as 0.0

Status: **OPEN** — measured, deliberately NOT fixed. Filed by crew item **D10** (adversary pass)
while fixing **0266** in the *one-shot* form of the same verb.
Area: `src/scheduler.c` — the `move_objects` sub-verb branches (`start` / `step` / `end`), which sit
**ahead of** the 0266 rejecter and never reach it.
Related: **0266** (fixed the one-shot form's first two slots), **0406** (the transform slots of the
same verb), **0404** (the same arm-on-unknown-slot defect in six sibling verbs), **0407** (what the
new numeric predicate still admits), **0069** (action-log replay forms).

## The defect

0266 added `move_objects_args_reject()` and wired it into the verb's final `else` — the one-shot
coordinate form. The four sub-verb branches are dispatched *before* that `else`, so their own
coordinate arguments are still read with bare `atof()`, which answers `0.0` for anything it cannot
parse. Measured against `src/xschem` at the 0266 fix
(`md5 d8f471d7eb014c21f5a815957db97c4e`, 2026-08-12), one wire `N 0 0 100 0`, `start 0 0` armed:

```
xschem move_objects end END 40   rc=0   N 0 40 100 40     <-- dx silently 0
xschem move_objects end 40 40    rc=0   N 40 40 140 40     (control)
xschem move_objects end {} 40    rc=0   N 0 40 100 40     <-- an EMPTY Tcl variable is not 0.0
xschem move_objects end 40       rc=0   N 0 0 100 0       <-- truncated: falls to the no-delta path, commits at (0,0)
xschem move_objects start END END        rc=0             <-- anchor silently (0,0)
xschem move_objects step  END END        rc=0             <-- snap point silently (0,0)
```

On issue 0266's own pending-merge constructor, `xschem move_objects end END 40` commits the merge
but lands the wire at `N 300 40 400 40` instead of `N 340 40 440 40` — rc 0, no diagnostic. That is
the same false-green class 0266 was filed to end, one slot to the right.

## Why it matters more than its size

`move_objects end <dx> <dy>` is the form **this project's own docs and tests recommend** as the
scripted commit constructor (`WIRING.md`, `doc/xschem_man/developer_info.html`, the wireedit
start/step/end tier, `tests/headless/fuzz/harness.tcl`). It is therefore the most likely place a
future false green is born: a test that commits with a typo'd or empty-variable delta asserts about
a document that moved somewhere else, and passes for the wrong reason.

## Why it was not fixed with 0266

Rung R2, end of an unattended run. 0266's sabotage matrix, tier baseline and status-E question were
all built around the one-shot form; widening the fix after the adversary pass would have shipped
code no sabotage variant covered. Filed instead, per the run's "never fix a discovered defect
silently, never leave a measured one unfiled" rule.

## Fix sketch

Call the existing `move_objects_slot_is_number()` (already file-static in `src/scheduler.c`) on the
coordinate arguments of the three coordinate sub-verbs, and reject with the same
`Tcl_ResetResult`/`Tcl_AppendResult` message shape 0266 uses. Keep **bare `end` legal** — commit
with no explicit delta is the documented contract (0266 D8) and `fuzz/harness.tcl:122-124` plus the
wireedit tier depend on it; the shape to refuse is `end <one-arg>` and `end <non-number> …`.

Positive controls that must stay green: `start ax ay [kissing] [stretch]`, `step x y`, bare `end`,
`end <dx> <dy>`, `abort`, the whole wireedit incremental tier, and `test_paste_modify_flag_0244.tcl`
section F rows F27–F29.
