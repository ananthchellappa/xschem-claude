# 0361 — `undo` after an abandoned placement resurrects the preview as a committed instance the user never dropped

Status: **OPEN — measured, not fixed.** Filed 2026-08-09 by the issue-**0263** write-up agent
(item D2 of the unattended backlog run), from the adversary pass on 0263's fix.
**Pre-existing** — the ESC path does exactly the same, measured side by side — but 0263 makes a
**read** verb plant the undo slot, which is new.
Area: `src/callback.c` `abort_placement_preview()` → `delete()` vs the undo baseline pushed at the
placement arm (`in_memory_undo.c` / `save.c` `push_undo`).
Related: **0263** (the verb that now reaches this path), **0241** (preview-scoped delete),
**0242**, `doc/claude/specs/add_wire_label.md` §8 (the one-baseline-per-gesture rule).

## Measured (headless, pinned binary `md5 e2261cb0b9f1ba90552ca1b09e554ef5`)

```
== D. undo after a netlist-abandoned place_symbol ==
   armed   ui=8232 inst=1 mod=1
   netlist ui=0    inst=0 mod=1
   undo    inst=1  mod=1
== D-control: same but ESC instead of netlist ==
   esc     inst=0 mod=1
   undo    inst=1 mod=1
```

```tcl
xschem clear force ; xschem wire 0 0 300 0 ; xschem unselect_all
xschem place_symbol devices/res.sym   ;# preview rides the cursor, never dropped
xschem netlist                        ;# 0263's gate abandons it: inst 1 -> 0
xschem undo                           ;# inst 0 -> 1  -- it is BACK, as a plain instance
```

The control arm proves the resurrection is **not** introduced by 0263: pressing ESC instead of
netlisting gives byte-identical numbers. The arm pushes an undo baseline; the teardown `delete()`s
the preview but does not pop that baseline; `undo` therefore restores a document snapshot that
contains the preview, and what comes back has no gesture bit, no `preview_sel` stamp and no
`sympin_preview` — an ordinary instance, indistinguishable from one the user placed on purpose.

## Why it matters more now

Before 0263, the only way into this state was a gesture the user *ended themselves* (ESC), where
"undo brings back what I just cancelled" is at least arguable. After 0263 a **read** verb —
`xschem netlist`, or Shift-N, or the toolbar Netlist button, or the `-keep_symbols` cellview
machinery — abandons the gesture as a side effect and leaves an undo slot behind it. A user who
netlists and then presses Ctrl-Z for an unrelated reason gets an object they never dropped, with a
dirty modify flag, and no status line connecting the two events.

## Options

1. **Pop the baseline in the teardown.** `abort_placement_preview()` already knows it owns exactly
   one baseline for the gesture (the one-baseline rule in `add_wire_label.md` §8 exists for the
   modeless re-arm case). Discarding it on abandon makes ESC and the gate both leave the undo stack
   as they found it. Risk: the arm's baseline is *shared* with whatever preceded it on some paths,
   and a wrong pop loses a real edit — the exact failure the one-baseline rule was written to
   prevent.
2. **Do not push a baseline until the preview commits.** Cleaner in principle; means the drop path
   must push one at commit time, and `place_symbol()`'s callers currently rely on the driver having
   pushed already.
3. **Accept it and document it** — "undo after a cancelled placement restores the cancelled
   object" as declared behaviour. Cheapest; keeps the surprise.

Recommendation: **1**, decided together with 0241 (which owns the preview-scoped delete) rather
than in isolation.

## Not fixed here

Out of item D2's scope, and pre-existing to it. Recorded because 0263 widened the set of verbs that
can reach it from "ESC" to "ESC, `netlist`, Shift-N, the toolbar, and the cellview browser".
