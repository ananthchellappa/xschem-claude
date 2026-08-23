# 0625 — a missing vector renders `-`, not blank, which contradicts invariant I3 — and 0615 just made it WHITE

STATUS: **OPEN — measured, NOT fixed. Pre-existing `translate()` behaviour, newly
prominent.** Found by the adversary leg of the crew that implemented
[0614](0614-annot-chords-must-own-node-voltages.md) /
[0615](0615-node-voltage-colour-collides-with-op-block.md), 2026-08-22.

---

## The invariant, verbatim (spec §5)

> **I3.** A missing vector renders **BLANK**. Not 0, not NaN on screen, not the
> previous run's number. Precedent: `save.c` RULING D5-1 — a plausible wrong
> number on a schematic is worse than none.

## What actually renders

Whenever a raw **is** loaded and the vector is absent, `lab_pin`, `ipin` and
`bus_tap` all render a literal hyphen. Measured on a `devices/nmos4` sheet with an
OP raw that has no `i(...)` vector for the device:

```
mask 3 : ... -|#00ffcc DD|#00ddff 1.8|#ffffff ...
```

That `-` is the branch current. With **no** raw loaded the same texts render truly
blank (no `<text>` element at all, measured across all four masks) — so I3 holds
in the no-raw case and fails in the exact case it was written for: a raw is
loaded and *this* vector is missing.

The good news, and the reason this is a §5 wording defect rather than a data
defect: it is **not** a stale value and **not** a plausible wrong number. The crew
verified that directly — annotating raw A (4 nets) and then raw B missing 3 of the
4 vectors renders the three as `-`, **never** the previous run's `0.9 / 0.1 / 0`,
and clearing the raw returns them to blank. The `save.c` D5-1 precedent I3 cites
is intact. What is wrong is that I3 promises "blank" and the display says `-`.

## Why it is filed NOW

Before 0615, those hyphens were dim red (layer 15, `#ff7777` / `#aa2222`) among
other dim red numbers. 0615 moved node voltages to layer 9 — **`#ffffff` on the
default dark palette** — so a missing node voltage is now a bright white hyphen,
the most prominent thing on the sheet, sitting exactly where a number should be.
The behaviour did not change; its cost did.

## Two ways to settle it, and they are not equivalent

1. **Make the display match the invariant** — render nothing where the vector is
   missing. Honest to I3 as written; but it makes "annotation is off" and "this
   node has no data" look identical, which is the failure mode
   [0604](0604-op-annot-must-report-requested-but-undelivered-vectors.md) /
   invariant **I8** exists to prevent.
2. **Make the invariant match the display** — restate I3 as "renders a
   NON-NUMERIC placeholder (`-`), never 0, never NaN, never the previous run's
   value", and keep the hyphen as the visible seam 0604's reporter cross-refers
   to. Suspect this is right: a user staring at a white `-` has been told
   something true and actionable, which blank does not do.

Whichever is chosen, **0604's CIW/logfile report is the other half** — the hyphen
says *which* row is missing, the report says *why*.

## Where the decision has to land

`doc/claude/specs/op_annotation.md` §5 I3 (the wording), and — if option 1 wins —
`token.c`'s `@spice_get_voltage` / `@spice_get_current` resolution, not the
0614/0615 class machinery, which never sees the value.
