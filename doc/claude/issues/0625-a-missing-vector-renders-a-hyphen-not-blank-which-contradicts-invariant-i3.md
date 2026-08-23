# 0625 — a missing vector renders `-`, not blank, which contradicts invariant I3 — and 0615 just made it WHITE

## ⚠ 2026-08-23 — LEFT OPEN DELIBERATELY by the 0617+0618 crew, and here is the evidence

The 0617+0618 brief asked this crew to decide and record whether its work closes 0625
or leaves it. **It leaves it, and the two are not even the same file.** Measured
directly rather than reasoned about:

* the hyphen is **C-side**: `xschem translate -1 {@spice_get_node absent_net}` returns
  `-` (`token.c:4478`, plus the same literal at `:4366 :4866 :4968 :5072 :5140 :5279`
  for the voltage / current / modelparam variants) — and it returns `-` **with no raw
  loaded** as well as with a raw whose vector is absent. So what this issue calls
  "blank when no raw is loaded" is **draw-time text suppression**, not a blank return
  value;
* the device OP block is **Tcl** and renders truly blank: `op_annot::raw_or_blank` and
  `op_annot::eng_or_blank` both return the empty string on a loaded raw with the vector
  absent, and `op_annot::text` renders `id  =\ngm  =\ngds =\n`.

The 0617 work touched neither `token.c` nor `op_annot::text` — and in the end it was
reverted entirely (see 0617), so **nothing this crew landed goes near this issue**.
Closing 0625 needs either a C change to the `@spice_get_*` family or a spec §5 I3
rewording, both outside that brief. What 0617's *retry* will supply is the half this
issue calls "the other half" — the report that says **why** — and that is compatible
with either resolution here.

---

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
