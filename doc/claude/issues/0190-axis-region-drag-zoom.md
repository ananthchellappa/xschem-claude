# 0190 — LMB press-and-drag in an axis-number margin zooms that axis only

**Status:** FIXED (2026-08-01)
**Branch:** `fluid-editing`. Reported as item 03 of the 2026-08-01 overnight
waveform batch.

> LMB press-and-drag outside the plot area of a strip and in the AXIS region -
> where axis numbers are displayed - will result in zooming along that axis only.
> For the X-axis, if user presses-and-drags from left to right, that is a zooming
> in. The portion of the trace(s) that occupy the strip from x1 (press location)
> to x2 (LMB release location) will now be zoomed in and take up the entire plot
> area. If user presses-and-drags from right to left, then, the entire portion of
> the trace(s) currently displayed in the strip will be displayed between x1 and
> x2 (axis numbers will change accordingly to accommodate the zoom). In the right
> to left, the right-most (x2) is where LMB was pressed. Similarly for the Y axis.
> If drag is upwards, then zoom in, if downwards (towards origin) then zoom out -
> similar to what is done for X-axis.

Spec: `doc/claude/specs/waveform_viewer_modes.md` **§17** (plus the two new rows
and the seventh rule in §15.1, and the note in §12.1).
Decision doc (24 resolved spec holes, and seven PLAN claims source refuted):
`doc/claude/code_analysis/ovb01_03_axis_region_drag_zoom_decision.md`.

---

## 1. WHAT THOSE PIXELS DID BEFORE — measured, both sides

**In the C engine an LMB press-drag in an axis margin was a complete no-op.**
Traced end to end: `waves_selected()` accepts the press and sets `graph_master`;
`waves_callback` seeds `graph_press_x/y`; `graph_marker_press()` normally
declines (a callout is clamped inside the plot box); the four cursor grabs
usually miss; the `GRAPHPAN` routing latch is taken; the graph pan needs
`Button2Mask`, so no motion arm fires; and the release falls into the wave-bold
arm, whose `on_body` test is false in a margin and which then asks
`graph_legend_at` — `-1` there — and changes nothing.

**In the ASE viewer the same press armed the strip drag-reorder.**
`wviewer::strip_drag_press` resolves the strip with `strip_at_pixel`, which tests
the **whole band**, margins included. It refuses only a modified press, the grip,
an armed marker drag, the 10-px trace zone and a cursor grab — so both axis
margins fell through to the reorder. The spec's own description of that zone has
always been *"the reorder handle (always) or empty waveform body"* (§12.1): the
margins were in it by permissiveness, not by decision.

So the feature is purely additive in C, and in the viewer it takes back a zone
the spec never claimed.

---

## 2. THE DECISIONS THAT MATTERED

**The region.** The bottom margin (below the plot box) owns X, the left margin
owns Y. Derived from the **plot box** `gr->x1/x2/y1/y2` and the **container**
`gr->sx1..sy2` — never from `marginx`/`marginy`, because the right plot edge is
`rx2 - 0.35*marginx` and the top edge is one of three formulas depending on
`digital`/`vlegend`. The **bottom-left corner answers Y**, matching the shipped
RMB left-margin arm, which tests `graph_left` first and never consults
`graph_bottom` — one precedence rule in the file, not two.

**Precedence: the margin was already occupied.** Four owners keep priority, and
each has a leg:

| owner | why it wins | how |
|---|---|---|
| a **marker** press | it has owned Button1 first refusal since it shipped | `mkpress` pre-empts the whole block — no code change |
| a **cursor** grab | the cursor's LINE crosses the margin and its numeric READOUT is DRAWN there (`draw_cursor` labels at `gr->ry2-1`, `draw_hcursor` at `gr->rx1+5`), and the four grab tests have **no plot-box confinement** | the arm is last in the cursor block, gated on `!(graph_flags & (16\|32\|512\|1024))` |
| the reorder **GRIP** | `graph_marker_press()` already gives it unconditional first refusal for exactly this overlap | rule 3 of `graph_axis_at()` |
| a **legend** entry | for `vlegend=1` and for digital strips the legend *is* the left margin | rule 4: `graph_legend_at(i,px,py) >= 0` ⇒ NONE |

**No raw requirement, no digital refusal** — deliberately unlike
`graph_plotbox_at`, which this otherwise copies. It is pure geometry;
`setup_graph_data` builds a valid transform from the tokens alone, and both axes
are meaningful on a digital strip (X is `x1`/`x2`, Y is the `ypos1`/`ypos2` band
the RMB arm already writes). Copying that raw gate would have made the whole
region silently dead before the first simulation.

**The two maths.** With the current window `[A,B]`, `R = B-A`, and the press and
release normalised into it as `ua`/`ub`, `s = ub-ua`:

```
s > 0  ZOOM IN    lo = A + ua*R          hi = A + ub*R
s < 0  ZOOM OUT   R2 = R/|s|             lo = A - ub*R2      hi = lo + R2
```

`|s|` clamped below at `1/GRAPH_AXIS_ZOOM_MAX_FACTOR` (1000.0) so a degenerate
drag can never write an `inf` into `x1`/`x2`, where it would be permanent; the
3-px click threshold normally binds first. Release positions are **clamped** to
the plot extent, not refused (a drag that overshoots by 2 px must still commit).
Log axes need nothing: `gr->gx1..gy2` and `G_X`/`G_Y` are *already* in log space,
which is why the shipped box zoom writes `dtoa(G_X(...))` with no `pow(10,·)` —
adding one here would double-convert (landmine 35 from the other side).

**X propagates, Y does not** — through the shipped participation predicate
`rk->sel || (same_sim_type && !(rk->flags & 2)) || k == i`, **not** the viewer's
`sharedx` (which the C engine cannot see). `wviewer::graph_props` never emits
`unlocked`, so in the viewer X follows every strip of the same `sim_type`
whatever `sharedx` says — exactly as the MMB pan and the RMB box zoom already do.

**No dirty flag, no C undo, no viewer undo, one log line.** A zoom is view state
(landmine 19), which is also what lets the read-only viewer perform it with no
`with_edit` bracket and what makes readonly-rejecting the verb wrong (landmine 17
lists the box zoom by name). One `log_action` line per commit, in the VERB form
`xschem graph_axis_zoom <gi> x|y <lo> <hi>` at `%.17g`, never pixels — so a
single line replays the whole propagation.

**The formula has ONE home.** `graph_axis_map()` is called by the release arm and
by `xschem get graph_axis_map`; neither inlines it. Landmine 45(a): a feature
whose feedback and whose commit compute the same thing twice will drift, and no
behavioural leg can see it while they still agree — so a source-level leg counts
the anchored expression.

**The viewer carries no geometry.** `wviewer::axis_grabbed` is the
`marker_grabbed` twin and `strip_drag_press` grows exactly one rung. C has
already decided by the time it runs, because the press was forwarded at the top
of the proc. There is deliberately no Tcl hit test to drift out of sync with the
plot box (contrast `GRAPH_REORDER_HANDLE_W`, which *is* mirrored and carries a
"change both" warning).

---

## 3. THE CHANGE

* `src/xschem.h` — `GRAPH_AXIS_NONE/_X/_Y`, `GRAPH_AXIS_ZOOM_MAX_FACTOR`, three
  transient `xctx` fields at the end of the marker block, three prototypes.
* `src/draw.c` — `graph_axis_at()` (the region query), `graph_axis_map()` (THE
  formula) and `graph_axis_zoom()` (THE apply), beside `graph_plotbox_at`.
* `src/callback.c` — `graph_axis_drag_clear/_abort/_press_arm` + the band
  geometry helper; the arm at the end of the cursor-grab block; the motion band
  beside the Button3 rubber (and the reciprocal `!graph_axis_drag` term in that
  rubber's guard); the release in `finish:`; the `abort_operation()` hook; and
  `|| xctx->graph_axis_drag` in the GRAPHPAN latch.
* `src/actions.c`, `src/xinit.c` — the three fields join the gesture-state reset
  class (`clear_drawing()` and `alloc_xschem_data()`).
* `src/scheduler.c` — three fail-soft getters in `xschem_cmds_g`'s `get`
  `case 'g':` and the fail-loud top-level verb.
* `src/wave_viewer.tcl` — `wviewer::axis_grabbed` and one rung.

Two things measured while implementing, both recorded rather than assumed:

1. **The GRAPHPAN latch DID need the extra term.** The prompt expected it not to.
   Both margins are usually `graph_top == 0`, but the Y region is "left of the
   plot box, anywhere in the container", so a press in the TOP-LEFT corner of a
   strip that owns no legend entry there (`legend=0`, or no `node` token yet)
   arms a Y drag with `graph_top` already 1 — and without the term that drag's
   release is silently dropped (landmine 36).
2. **`graph_axis_zoom()` reads `digital` straight off the rect**, not through a
   scratch `Graph_ctx`. `setup_graph_data()` parses `digital` *below* its
   off-screen early return (landmine 37a), so an off-screen digital strip
   answered 0 and the Y write went into `y1`/`y2`. Caught by the `AV5` leg
   before the fixture was re-fitted.

---

## 4. WHAT DEFENDS IT

`tests/headless/test_wave_axis_zoom.tcl` — 119 checks in the `--nogui` arm, 173
with a display. Auto-discovered by `full_audit.sh`.

| group | arm | defends |
|---|---|---|
| `AZ*` | both | the region and its four refusals, the corner rule, fail-closed, `vlegend`, a **digital** strip, and **no raw loaded** (the leg that dies if `graph_plotbox_at`'s raw gate is ever copied in) |
| `AM*` | both | both endpoints of both maths, the full-extent and half-extent worked checks, the 3/4-px boundary from both sides, the zoom-out clamp, the log axis, the release clamp, fail-soft |
| `AV*` | both | the apply — **witnessing every rect**: X propagates, `unlocked` does not follow, a foreign `sim_type` does not follow, Y is per-graph, digital Y is `ypos1/2`, `modified` stays 0 *with a control leg proving the probe can reach 1*, and read-only still applies |
| `AL*` | both | exactly one log line per commit, in the verb form, with data bounds; and **replaying that line reproduces both rects' windows** |
| `AS*` | both | the anchored expression appears once in `draw.c`, `graph_axis_map()` is called once from `callback.c` and once from `scheduler.c`, `GRAPH_CLICK_TOL` stayed file-private, and `graph_axis_zoom()`'s body contains no `set_modify`/`push_undo` |
| `AG*` | display | the real C gesture: what arms and what does not (body, legend, grip, **and a press that grabbed a cursor — asserting both that no axis drag armed and that `graph_flags & 512` really was set**), the two full gestures, the sub-threshold no-op, ESC mid-drag, X-propagates/Y-does-not, and `modified` still 0 |
| `AX*` | display | the ASE viewer seam through the **shipped bindings**: a margin press does not arm the reorder and does not change the strip order (inert `sdid` witness), a body press and a grip press still do, the buffer stays `modified 0` / `readonly 1`, ESC cancels, and `history_depth` does not move |

Six named sabotages, each verified to fail exactly its target and no more:
invert the direction test (kills the four reverse-drag groups and `AG8`, leaves
`AM1`/`AM5`/`AM7`–`AM11` green); drop the anchoring term (kills the reverse
**endpoint** legs while **`AM3` stays green**, because the anchor term vanishes
for a full-extent reverse drag — the asymmetry that is the whole reason both
endpoints are asserted); widen the region into the plot box; drop the
participation loop; arm before the cursor grab (kills `AG6` only); and give the
release arm its own inline copy of the map (kills the `AS1` source legs **only**
— every behavioural leg stays green, which is exactly the drift no behavioural
test can see).

---

## 5. NOT COVERED BY ANY CHECK (the eyeball list)

The rubber band's pixels; the drag *feel*; whether the tick labels are still
legible after a zoom; the (absent) pointer-cursor change during the drag; and
whether losing the axis margins from the viewer's strip reorder is noticeable in
use.
