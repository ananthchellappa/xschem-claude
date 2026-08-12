# 0407 — the `move_objects` numeric slot admits `nan` / `inf` / hex, which then corrupt or erase the saved schematic

Status: **OPEN** — measured, NOT fixed. Pre-existing (`atof()` did the same), but 0266 now
*advertises* the guarantee, which is what makes it worth a number.
Area: `src/scheduler.c` — `move_objects_slot_is_number()` (added by **0266**) and every other
coordinate read that reaches `store.c` / `save.c`.
Related: **0266**, **0405**, **0406**.

## The defect

0266's predicate is a full `strtod` parse — strictly better than `atof()`, and it is what makes the
error message "`<dx> <dy> must both be numbers`" true in the C sense. But `strtod` accepts `nan`,
`inf`, `infinity`, `0x…` and out-of-range exponents, so the values that actually damage a document
pass the check. Measured against the 0266 fix (2026-08-12), one wire `N 0 0 100 0` selected, saved
immediately after:

```
xschem move_objects nan 0    rc=0   saved record:  N nan 0 nan 0 {lab=#net1}
xschem move_objects inf 0    rc=0   the wire is ABSENT from the saved file entirely
xschem move_objects 1e400 0  rc=0   same disappearance
xschem move_objects 0x10 0   rc=0   N 16 0 116 0        (silently hex)
```

`N nan 0 nan 0` is a record that will not round-trip meaningfully, and the `inf` case loses the
object without an error at any layer.

## Why it is filed and not fixed

Not a regression — `atof()` produced the same values before 0266 — so fixing it inside D10 would
have widened a verified change past its sabotage matrix (rung R2). But a validator that now promises
"numbers" arguably owns a **finite** check, and the promise is in the shipped user reference
(`doc/xschem_man/developer_info.html`).

## Fix sketch

Add a finiteness test to `move_objects_slot_is_number()` — C89-safe form: reject when
`v != v` (NaN) or `v > DBL_MAX || v < -DBL_MAX` (`<float.h>` is already reachable), and decide
explicitly whether `0x…` should be accepted (it is almost certainly a typo in a coordinate).
The deeper question — whether `store.c`/`save.c` should refuse a non-finite coordinate regardless of
which verb produced it — is the wider version of this issue and probably the right place.
