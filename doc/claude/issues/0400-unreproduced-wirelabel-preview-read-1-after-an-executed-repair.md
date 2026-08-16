# 0400 — UNREPRODUCED: `wirelabel_preview` read 1 after a repair that had demonstrably executed

Status: **OPEN — observed ONCE, never reproduced, unexplained.** Recorded rather than buried, by the
adversary pass of item **D8** of the 2026-08-11 unattended backlog run. **Do not chase this from
cold** — it is filed so that if the same reading ever recurs there is a dated first sighting to
match it against, not because there is a known defect here.
Area: `src/callback.c` `repair_orphan_placement_preview()` (the `xctx->wirelabel_preview = 0;`
write) and/or `src/scheduler.c`'s new `xschem get wirelabel_preview` probe.
Related: **0262** (the repair and the probe), **0399**.

## What was seen

The **first** run of the adversary session, on the freshly built binary, read:

```
wirelabel_preview = 1
```

after a repair that had **demonstrably executed** in the same episode — `sympin_preview` read 0,
`preview_sel_n` read 0, and the repair's status line
(`Pending placement abandoned by a deselect; object left in place`) was present. The three clears
are three consecutive statements in one function with no early exit between them, so a partial
execution has no obvious mechanism.

## What was ruled out

* **Not a stale binary.** `src/xschem` (17:53:43) was newer than every source file (17:52:54).
* **Not flaky-by-frequency.** 20 back-to-back repeats of the identical script, plus every later run
  in that session and the full doors suite (row **F5**, `wirelabel_preview` cleared), read **0**.
* **Not a missing probe.** The doors suite maps a missing `get` key to the literal `PROBE-MISSING`,
  and the reading was the digit `1`.

## Where to look if it recurs

1. **Which `xctx`.** The repair acts on whichever context is current at entry, and the `reported`
   latch is file-static, not per-context (0262 still-open item 8). A second context whose flag was
   never cleared would answer 1 to a probe issued while *it* is current.
2. **Ordering against the arm.** `add_wire_label` sets `wirelabel_preview = 1` one line **before**
   its own `unselect_all(1)` (`scheduler.c`) — an interleaving in which the repair runs between
   those two lines would clear the flag and then have it immediately re-raised. That window is
   believed to be zero for the *success* path (0242 made the flag/bit pair atomic), but it is the
   only known place where the flag is written outside the pair.
3. **The probe itself**, `xschem get wirelabel_preview` — added by 0262 into the `get` chain's
   `case 'w'`, immediately above the `wave_hilights` branch that was converted from `if` to
   `else if` in the same edit.

Reproduce attempts should use `xschem test_gate_bypass 1` to build the desync deliberately, since
after 0262 an ordinary probe repairs the state before it can measure it (issue **0399** part 1).
