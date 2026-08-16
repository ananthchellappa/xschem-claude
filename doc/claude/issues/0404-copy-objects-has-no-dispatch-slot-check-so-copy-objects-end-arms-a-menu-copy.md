# 0404 — `copy_objects` has no dispatch-slot check, so `xschem copy_objects end` silently arms a menu copy

Status: **OPEN** — measured, deliberately NOT fixed. Filed by crew item **D10** (planner) while
fixing **0266** in the sibling verb.
Area: `src/scheduler.c` — the `copy_objects` branch (`:2883`–`:2933`).
Related: **0266** (the same defect in `move_objects`, fixed there), **0392** (the return-channel
family: a verb that cannot say "no").

## The defect

`copy_objects` has **no sub-verb layer at all** — no `start`/`step`/`end`/`abort` — and no
validation of `argv[2]`. Every argument shape falls into the one body, which uses the same
argument-COUNT discriminator `argc > 3 + nparam` and the same `atof()` reads that 0266 fixed on
`move_objects`.

Measured against `src/xschem` at `d99f3791`:

```
xschem copy_objects end        rc=0  ui_state 65544  ui_state2 2048 (MENUSTARTCOPY)  wires 1
                                     <-- arms a DEFERRED menu copy; nothing copied, no error
xschem copy_objects end 0 0    rc=0  ui_state 8       wires 1 -> 2
                                     <-- really copies, at delta atof("end") = (0,0)
```

So `copy_objects <anything>` arms, and `copy_objects <anything> <dx> <dy>` copies at a corrupted
delta with the first slot silently read as `0.0` — exactly the two consequences 0266 names, in the
verb 0266 did not touch.

## Why it was not fixed with 0266

Scoped out on the R2 rung (smallest blast radius) at the end of an unattended run:

- `copy_objects` has **no sub-verb contract to name**, so 0266's error text ("unknown sub-verb;
  expected `start|step|end|abort` …") is a misnomer here. The right message for `copy_objects` is
  a plain "expected `<dx> <dy>` [`kissing`] [`stretch`]", i.e. a different message, not a shared one.
- Fixing both verbs in one item doubles the surface a single sabotage matrix has to cover.

## Fix sketch

Reuse `move_objects_args_reject()` (added in 0266, `src/scheduler.c`) behind a copy-flavoured
message, or factor it to take the verb name. Call it from `copy_objects` **before** the
`if(kissing) xctx->connect_by_kissing = 2; if(stretch) select_attached_nets();` pair, so a rejected
line leaves no state behind — the same placement 0266 pins with its ordering row.

Positive controls that must stay green: bare `xschem copy_objects` (Edit ▸ Duplicate / `c`),
`copy_objects kissing`, `copy_objects stretch`, `copy_objects <dx> <dy> [rot flip [local]
[-anchor ax ay]] [kissing]` (the issue 0069 replay form), and the tier suites that use them.

---

## WIDENED 2026-08-12 — the class is **six** verbs, not one

The adversary pass of the same crew item probed every sibling verb that arms `MENUSTART` the way
`move_objects` did. Measured against the 0266 fix (`md5 d8f471d7eb014c21f5a815957db97c4e`), each
from a cleared context:

```
xschem copy_objects END   rc=0  ui_state 65536  ui_state2 2048 (MENUSTARTCOPY)
xschem rect END           rc=0  ui_state 65536  ui_state2 4
xschem polygon END        rc=0  ui_state 65536  ui_state2 32
xschem line END           rc=0  ui_state 65536  ui_state2 2
xschem arc END            rc=0  ui_state 65536  ui_state2 64
xschem circle END         rc=0  ui_state 65536  ui_state2 128
```

Every one answers `TCL_OK` to an argument it does not understand and arms a deferred menu gesture
the caller never asked for — the GUI consequence 0266 measured (one canvas click then starts a
gesture nobody requested) applies to all six. So this issue is the **class** issue for
"an unknown dispatch slot arms instead of erroring"; 0266 fixed only `move_objects`.

Scope note for whoever takes it: the six verbs do not share one message. `copy_objects` takes
`<dx> <dy> [rot flip [local] [-anchor ax ay]] [kissing|stretch]` like `move_objects` and can reuse
`move_objects_args_reject()` behind a copy-flavoured message; the five shape verbs take their own
coordinate shapes and need their own. Doing all six at once needs one sabotage variant per verb —
that is the reason 0266 did not, and the reason this should be planned as its own item rather than
bolted onto a fix.
