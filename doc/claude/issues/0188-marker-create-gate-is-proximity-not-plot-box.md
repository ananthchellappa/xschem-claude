# 0188 — `m`/`d` must place a marker anywhere in the strip's PLOT BOX, at the diamond's sample

**Status:** FIXED (2026-08-01)
**Branch:** `fluid-editing`. Reported as item 01 of the 2026-08-01 overnight
waveform batch.

> Currently, to select a trace, the mouse pointer needs to be reasonably close to
> the trace - proximity. Good. However, this is not needed for adding a marker.
> Adding a marker is done by pressing "m" key - clear intention. Therefore, if the
> mouse is within the plot area of a strip, and user presses "m" key, add a marker
> at the point that the diamond cursor has snapped to

Two halves, and only one of them is a change. Trace **selection** keeps its
proximity — `GRAPH_TRACE_PICK_TOL`, 10 screen px, shared by four picking
surfaces (`xschem.h`, landmine 33). Marker **creation** loses its proximity and
becomes a plot-box test, picking exactly the sample the item-9 diamond snap
cursor is already sitting on.

---

## 1. THE MEASURED MECHANISM

The diamond and the key had **two different gates**, and had since the diamond
shipped. `draw_graph_snap_cursor()` (`draw.c`) gates on the plot box:

```c
  if(!graph_plotbox_at(i, (double)mx, (double)my)) continue;
  if(graph_point_at(i, (double)mx, (double)my, 1e30, -1, -1, &h)) { ... }
```

with the comment *"THE GATE IS THE PLOT BOX, NOT A DISTANCE TO A TRACE"* —
written when the diamond's own first cut was reported as *"the mouse pointer
needs to be too close to the trace"*. `graph_marker_create()` still gated on
distance:

```c
  if(!graph_point_at(i, px, py, GRAPH_MARKER_PICK_TOL /* 20.0 */, -1, -1, &hit)) {
    graph_marker_refuse("xschem: no trace near the pointer");
```

so the glyph that shows *which* sample would be marked and the key that marks it
disagreed about **where a marker can exist at all** — in both directions.

Measured on the shipping build (`XSCHEM V3.4.8RC`, HEAD `e516cc85`), hermetic
`raw new` fixture (`vsweep 0 1.0 0.1`, `v_a = 1+vsweep`, `v_b = 2*vsweep`, one
graph rect `0 0 800 400`, `node="v_a\nv_b"`, `x1=0 x2=1 y1=0 y2=2.5`,
`zoom_full`):

| pixel | `graph_plotbox_at` | `graph_trace_at … 20` | `graph_marker add` BEFORE | AFTER |
|---|---|---|---|---|
| (544, 621) — inside the box, > 25 px from every trace | **1** | −1 | **`{}` refused** | **created**, anchored to node 1 |
| (544, 411) — on trace `v_a` | 1 | 0 | `1` created | unchanged |
| (145, 480) — **outside** the box, 6 px from `v_a`'s left end | **0** | **0** (a hit) | **`1` created** | **`{}` refused** |
| digital strip, anywhere | 0 | — | `{}` | unchanged |
| traceless strip, inside its box | 1 | −1 | `{}` | unchanged |

Row 1 is the reported half: a plainly visible diamond sitting on a sample, and
`m` doing nothing. Row 3 is the half nobody reported and the fix removes: a
20-px **halo** outside the plot box, in the axis-number margin, where no diamond
is ever drawn (`waveform_viewer_modes.md` §15.7 says the legend band and both
axis margins draw **nothing** on hover) and yet a marker could be created.

Both the pixel verb and the queries answer correctly with **no X server**, which
is why the bulk of this issue's suite is in the BOTH-ARMS engine half rather than
behind a `has_x` guard.

---

## 2. THE FIX

Three lines inside `graph_marker_create()` (`src/draw.c`), the **single**
primitive behind all three creation doors — the `m` arm, the `d` arm
(`callback.c`) and `xschem graph_marker add` (`scheduler.c`). Nothing else
changed: `callback.c`, `wave_viewer.tcl` and `scheduler.c` needed no edit.

1. the existing `gr->digital` refusal stays **first**, so its specific message
   survives (`graph_plotbox_at()` refuses digital too and would swallow it);
2. **new gate** — `if(!graph_plotbox_at(i, px, py))` → *"the pointer is not
   inside the plot area of a strip"*;
3. the pick's tolerance becomes `1e30` and its refusal becomes *"no trace to
   mark in this strip"* — a traceless, bus-only or unresolvable-`rawfile=` strip
   is now the only way to reach it.

`#define GRAPH_MARKER_PICK_TOL 20.0` had exactly one use in the tree and is
**deleted**. A constant whose comment documents a gate that no longer exists is
the trap the next reader falls into; `test_wave_snap.tcl` SQ3 ("no
proximity-threshold var survives") set the precedent for the sibling feature.

⚠ **The trap inside the function.** It builds its `Graph_ctx` with
`setup_graph_data(i, 1, gr)` — `skip = 1` — which suppresses the `x1`/`x2` parse,
so in *that* `gr` `gx1 == gx2 == gw == 0` and every derived coefficient
(`cx dx scx sdx`) is **infinity**; the usual `gr->scx == 0.0` "no transform"
sentinel is useless because `inf != 0`. `gr->digital` is the only field of it
that may be read, and the box must come from `graph_plotbox_at()`, which builds
its own context with `skip = 0`. Recorded as **landmine 45(b)** in
`doc/claude/code_analysis/waveform_subsystem_reference.md`; 45(a) is the reusable
half of the whole issue — *a creation gate must match the FEEDBACK gate*.

Decisions (D1–D16, with the alternatives rejected) are in
`doc/claude/code_analysis/ovb01_01_marker_anywhere_in_plotbox_decision.md`.

---

## 3. WHAT DEFENDS IT

`tests/headless/test_wave_markers.tcl`. Every pixel is **scanned** with the
engine's own queries, never hardcoded, and a staging leg FAILS (never skips) when
a scan comes up empty.

* **`MP*`, both arms** (engine): `MP0` staging (box wider than 100 px; far, halo
  and on-trace pixels all scanned; the far pixel's nearest trace is node **1**);
  `MP1` the far pixel is inside the box and −1 at 10 and at 25 px; **`MP2`** it
  creates, while `graph_trace_at` at that same pixel still says −1; `MP3` the
  anchor is the *nearest* trace; `MP4` a real sample (`x == point/10` exactly at
  `%.17g`, `y` against `raw value`); `MP5` inside the x window; `MP6` within one
  sample step of `graph_coord`'s independent pixel→data answer; **`MP7`** the
  halo pixel is refused with both witnesses read in the same leg; `MP8` `d` gets
  the same relaxation and carries its `prev`; `MP9` a vertical sweep of the box
  creates on a **fraction** > 0.95 (never a magic count — the `test_wave_snap`
  SG6 lesson; the restored-tolerance sabotage scores 8/18) while 8 px above and
  8 px below the box create nothing; `MP10` digital still refused; `MP11`
  traceless still refused inside a real box; `MP12` refused with no raw;
  **`MP13`** trace selection proximity is unchanged and `GRAPH_TRACE_PICK_TOL` is
  still 10.0; `MP14` source tripwires on the gate line, the `1e30` line and a
  `count_code` 0 for `GRAPH_MARKER_PICK_TOL` in both files; `MP15` the marker
  exception to landmine 19 (the buffer still goes dirty).
* **`MP20`/`MP21`/`MP22`, display**: the real `m` and `d` KEY arms in empty
  plot-box space, and **the diamond equality** — with `graph_snap_cursor` armed,
  `xschem get graph_snap` and the marker the key then creates name the same
  strip, the same trace and the same x/y. That is the user's sentence, asserted.
  DISPLAY-only by construction: `draw_graph_snap_cursor()` returns early under
  `!has_x` (landmine 41).
* **`MX4` inverted, `MX4b` new** (ASE viewer): `mx_empty_row` had to gain the
  `wviewer::plotbox_at` requirement `mf_empty_px` already carries, because before
  this fix both regions refused and the scan's choice did not matter — now they
  answer differently. `MX4b` drives the margin refusal through the **verb only**:
  a key not claimed by the graph falls through to the schematic handler where `m`
  is `readonly_block()`, a MODAL that hangs a headless run to the harness timeout.

Sabotage-verified, each applied, rebuilt, run in both arms and reverted:

| # | sabotage | killed, exactly |
|---|---|---|
| SAB-1 | `1e30` → `20.0` | `MP2`(2) `MP3` `MP4`(2) `MP5` `MP6` `MP8`(2) `MP9`-positive `MP15`(2) `MP20`(3) `MP21`(2) `MP22`(5) `MX4`(4) + `MP14`'s `1e30` tripwire |
| SAB-2 | delete the `graph_plotbox_at` gate | `MP7`-refusal, both `MP9`-negatives, `MX4b`(2) + `MP14`'s gate tripwire |
| SAB-3 | `restrict_wave = 0` instead of `-1` | `MP3` only + `MP14`'s tripwire |

(The `MP14` casualties are the point of a source tripwire: it asserts the exact
line each sabotage edits, so it cannot survive its own sabotage.)

---

## 4. WHAT THIS DELIBERATELY DID NOT CHANGE

* `GRAPH_TRACE_PICK_TOL` and its four sharing surfaces, and the `{tol 10}` proc
  defaults in `wave_viewer.tcl`. "Good," said the report.
* `find_closest_wave()` — two open defects (landmine 40) and the wrong shape for
  this (it reads the C mouse mirror, measures only |Δy|, and does not yield the
  `(dataset, point, raw x, raw y)` identity `graph_marker_add_record` needs).
* Digital and bus strips: still refused (`graph_markers.md` §11 Deferred).
* The marker **drag** (`graph_marker_move` / `graph_marker_anchor_at`): it
  already passes `1e30` restricted to the marker's own trace and deliberately
  tolerates the margins (landmine 36's tolerance gap).
* The anchor model, `log_action`'s data-addressed `add_at` line, undo, and
  `set_modify(1)` — `graph_marker_add_record` is untouched, so replay is
  unaffected by definition.

## 5. NOT ASSERTED — for the eyeball

Behavioural, not visual: two consequences are judgement calls no check can make.
The **removed halo** (refusing `m` 6 px outside the box while a trace passes
right there) is argued from §15.7 and asserted as behaviour, not eyeballed; and a
marker anchored to a trace that is off the strip's **y** window (D11 — the pick
filters on the x window only, exactly as the diamond does) draws its anchor glyph
outside the plot box while `graph_marker_label_box` clamps the callout inside it.
