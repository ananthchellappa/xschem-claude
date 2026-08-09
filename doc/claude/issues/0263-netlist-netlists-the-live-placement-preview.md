# 0263 — `netlist` emits the live placement preview as a real device, so a netlist taken mid-gesture silently renames a net

Status: **OPEN** — measured, out of issue 0242's scope (it is not a door: it clears no gesture
bits and leaves no terminal state). **Major**: the netlist is wrong, silently, and nothing in the
document is modified to show it.
Area: `src/netlist.c` / the per-format backends vs the placement preview objects in `xctx->inst[]`
Tests: reported, not asserted — `tests/headless/test_placement_preview_doors.tcl` section F prints
it as a `note:` line.
Found: 2026-08-08, closing issue **0242**
Related: **0242** (parent census, row `netlist`), **0262** (the other 0242 residue), **0241**,
`doc/claude/specs/add_wire_label.md`.

## Symptom

```tcl
set ::label_new_name FOO
xschem clear force ; xschem wire 0 0 100 0 ; xschem unselect_all
xschem add_wire_label -place      ;# preview rides the cursor, not dropped
xschem netlist
```

The preview `lab_pin` is a fully-formed instance in `xctx->inst[]` — it is what makes the
0242 orphan netlist-visible in the first place (`xschem instance_net l1 p` → `FOO`). So the netlist
is generated with the label applied: the wire the preview happens to be sitting on comes out named
`FOO` instead of its real name, from a label the user has not dropped and may still be typing.

Measured after the netlist and three ESCs: `sympin_preview=0`, `orphans=1`.

## Why this is NOT issue 0242's defect

0242's doors all **arm a second gesture** and clear `START_SYMPIN`/`STARTMOVE` without running the
teardown, leaving `sympin_preview` set — the terminal desync. `netlist` does neither: both
`sympin_preview` and `START_SYMPIN` end at 0, the canvas stays alive, and ESC still works. It was
listed in 0242's census as "orphan is netlisted" and excluded from that fix on purpose — the
teardown is the wrong tool here. A netlist is a **read** operation; it must not delete the user's
in-flight preview as a side effect, which is exactly what calling `leave_placement_for()` would do.

The bug is that a preview is indistinguishable from a committed instance to everything downstream.

## Options

1. **Exclude preview objects from the netlist traversal.** The identity already exists:
   `xctx->preview_sel` / `preview_sel_n`, stamped at every arm by `stamp_placement_preview()`
   (`select.c`, issue 0241). The traversal would skip ids in that set while a placement is live.
   Cheap and targeted; the risk is that the netlisters walk instances in several places and each
   would need the filter.
2. **Refuse the netlist while a placement is live**, with a statusbar line ("drop or ESC the
   pending placement first"). Honest and one-line, but netlisting is scriptable and often runs from
   automation that would now fail on a state the user cannot see.
3. **Commit nothing, warn only** — netlist as today, plus a loud `dbg(0)` line naming the preview
   instance. Cheapest; leaves the wrong netlist on disk.

**Recommendation: 1.** The preview identity is already tracked for exactly this reason ("what the
live cursor placement is, as durable ids", `xschem.h`), and it is the only option that keeps both a
correct netlist and a live gesture.

## Landmine

The same blindness plausibly affects every other whole-document consumer that walks `xctx->inst[]`
while a gesture is live — `save`, `check`, ERC, the hierarchy traversal, symbol generation. This
issue covers the netlist because that is where it was measured; the sweep is the real work, and
option 1's filter should be written as a shared predicate, not inlined per backend.
