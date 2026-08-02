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
  rubber's guard); the release in `finish:`; the `abort_operation()` hook;
  `|| xctx->graph_axis_drag` in the GRAPHPAN latch; and (second repair, §3.2)
  `graph_axis_drag_abort()` in `waves_selected()`'s `if(!is_inside)` branch.
* `src/actions.c`, `src/xinit.c` — the three fields join the gesture-state reset
  class (`clear_drawing()` and `alloc_xschem_data()`).
* `src/scheduler.c` — three fail-soft getters in `xschem_cmds_g`'s `get`
  `case 'g':` and the fail-loud top-level verb.
* `src/wave_viewer.tcl` — `wviewer::axis_grabbed` and one rung.

Three things measured while implementing, all recorded rather than assumed:

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
3. **`GRAPH_CLICK_TOL` goes into `graph_axis_map()` in SCREEN PIXELS, not
   `× xctx->zoom`.** Decision D-9 records "`GRAPH_CLICK_TOL` (3.0) × `xctx->zoom`"
   and the code does not multiply — correctly: PLAN Q4 asks for "3 *screen* px"
   and `graph_axis_map`'s `p0`/`p1` are canvas pixels, so scaling them would
   compare pixels against world units. The consequence is that the constant now
   means two things inside `callback.c` — every older use (`:710`/`:711`,
   `:1047`/`:1048`) is `* xctx->zoom`, i.e. WORLD units — so the `#define` and
   both call sites carry an explicit note saying which space they are in.

### 3.1 Post-review repair (fixup commit)

An adversarial re-read of the commit found four things, three of them fixed here
and one already true:

* **The suite was not reliably green.** `AX7`'s `<Key-Escape>` was a bare
  `event generate` with no focus set — the only key send in the file, and the
  only wave suite in `tests/headless/` with no `focus -force` anywhere. Measured
  standalone: 8 red runs in 30, 7 of 10 inside one bad window, always the two
  `AX7` legs (a swallowed ESC leaves the arm up, so the trailing release commits
  the zoom). It now goes through `ax_send_key`, the retry-until-the-arm-clears
  sender the other wave suites use, and the leg **asserts that the key was
  delivered** so a lost probe can never read as a pass. A second, independent
  flake found while re-soaking: the AX group's `xschem new_schematic switch`
  calls were unconfirmed, so a stray `EnterNotify` on the main editor during any
  `update` put the C context back and `AX0` then measured the *schematic's*
  rects (`node -> {v_a v_a}`, `readonly -> 0`) — ~1 run in 12. Every switch in
  the group now goes through `ax_ctx`, which confirms `current_win_path`.
* **The `xschem get graph_axis_map` seam carried its own copy of the
  click-vs-drag threshold** — `scheduler.c` passed a literal `3.0` while the
  gesture passed `GRAPH_CLICK_TOL`, so raising the `#define` would have moved the
  product and not the seam the whole `AM` group is driven through, with no leg
  going red. That is landmine 45(a) with the constant instead of the maths. The
  value now has one home: `graph_click_tol()` in `callback.c` (the `#define`
  stays file-private — in the header it reads as `GRAPH_TRACE_PICK_TOL`'s twin,
  landmine 20). `AS3` counts the seam and `AM7` now takes its boundary pixels
  from the parsed `#define`.
* **Two tunable constants were frozen as literals in the suite.**
  `GRAPH_AXIS_ZOOM_MAX_FACTOR` was hardcoded as `1000.0` in `az_expect` and in
  `AM8`'s one-sided bound, so re-tuning the `#define` — which the eyeball list
  invites — could not make any leg go red. Both constants are now read out of the
  source by `az_define`, and `AM12` makes the clamp **actually bind** (a strip
  whose plot box is thousands of pixels wide) and asserts the clamped span
  equals `R × GRAPH_AXIS_ZOOM_MAX_FACTOR` on **both** sides.
* **Coverage gap, now closed:** no leg drove the C press/arm/release path on a
  strip whose rect index is not 0 (`AZ11` only *queried* index 2, `AV5` only
  called the *verb* on index 4), so a `graph_axis_press_arm(0, ...)` hardcode or
  a `graph_master`/`graph_axis_draggraph` mix-up would have been invisible.
  `AG13` presses in **strip 1's** margins; the Y half is the decisive one,
  because Y never propagates, so "rect 1 moved and rect 0 did not" can only mean
  the arm followed the pressed strip. Probed by hand first: the behaviour was
  already correct, so this is a missing witness, not a defect.

### 3.2 Second post-review repair — the latch term, and the defect behind it

A second adversarial review found that **§3 item 1's own headline correction —
`|| xctx->graph_axis_drag` in the GRAPHPAN routing latch — had ZERO coverage**.
Deleting the term left the whole suite green. That is the item's most-documented
line: the commit message headlines it, the decision doc's Status block calls it
correction 1, and `waveform_subsystem_reference.md`'s landmine says the gesture
"DOES owe the GRAPHPAN routing latch".

**Why every existing leg was blind to it.** All of `AG*` and `AX*` release
*inside* the strip they pressed in. There `waves_selected`'s POINTINSIDE arm
re-finds the graph on its own, `graph_master` is still set and the release
reaches `waves_callback` **whether or not the latch fired** — the correct engine
and the broken one give the same answer, so no leg could discriminate. This is
the PROBE PLACEMENT rule of `doc/claude/overnight_batch_2026_08_01/PLAN.md`: a
leg driven from a path where the right and the wrong implementation agree is not
a leg.

**`AG14`, the leg that discriminates**, needs both halves of the disagreement:

* `graph_top` must already be 1 at the press, or the latch fires on its
  `!graph_top` term anyway. `graph_axis_at`'s Y region is "left of the plot box,
  ANYWHERE in the container", so the **TOP-LEFT corner** is a Y region whose
  press sits above the plot box. It only answers `y` on a strip owning no legend
  entry there — with a `node` token the horizontal legend's slot 0 spans
  `rx1+2 .. rx1+rw/n` across the whole top band (`legend_slot_hit`) and
  `graph_axis_at` declines. Hence a third fixture strip carrying **no `node`
  token**, with `graph_legend_at` asserted `-1` at the corner as a teeth leg.
* the release must **leave the strip**, so nothing but the latch can route it
  back: left of the container band, at 1/4 of the plot box's height.

It asserts `ui_state & GRAPHPAN` immediately after the press (the term itself),
then that the outside release still commits `graph_axis_map`'s answer, and that
`y1` really went negative. Measured: clean `0 2.5 -> -7.519 2.5`; with the term
deleted `0 2.5 -> 0 2.5`, silently. Note which leg does **not** die under that
sabotage — "…and its hi": the map's `hi` is 2.5 and the untouched window's `y2`
is 2.5 too, so the `lo` endpoint and the "really zoomed OUT" leg are what carry
the assertion.

**The defect the second job of that line was hiding.** `waves_selected`'s
`if(!is_inside)` branch dropped an armed MARKER drag and not an armed AXIS drag.
That reads unreachable — GRAPHPAN keeps the pointer-outside case out of the
branch, which is `AG14`'s case exactly — but **every `skip = 1` clause jumps the
rect loop entirely**, leaving `is_inside` 0 with GRAPHPAN still set. Adding
Shift mid-drag is one such clause (`event == MotionNotify && Button1Mask &&
ShiftMask`). Measured on the shipped binary:

1. LMB press in a strip's left margin → Y drag armed, GRAPHPAN latched;
2. Shift arrives mid-drag → the skip route runs the `!is_inside` branch, which
   cleared GRAPHPAN and aborted a marker drag but **left the axis arm up**;
3. the release is swallowed by the same skip, so the arm is still up;
4. `graph_axis_press_arm()` does not clear it either — it returns early when the
   new press is not in a margin;
5. a following plain LMB press-drag in the **PLOT BODY**, which owns no axis
   gesture at all, committed a zoom from the abandoned press position:
   `y1/y2 0..2.5 -> 1.2537228..2.3920389`.

Fix: one line, `graph_axis_drag_abort();` beside `graph_marker_drag_abort();`.
`AG15` drives the whole sequence with **no ESC anywhere** (`abort_operation()`
clears the arm and would mask it), asserts GRAPHPAN is gone as its teeth that
the branch really ran, then that the arm went with it, then that the following
body drag commits nothing on any strip.

Both sabotages verified against the committed source: deleting the latch term
kills exactly 3 `AG14` legs; deleting the abort kills exactly 3 `AG15` legs.
Suite after: **361 checks with a display / 200 `--nogui`**.

---

## 4. WHAT DEFENDS IT

`tests/headless/test_wave_axis_zoom.tcl` — 200 checks in the `--nogui` arm, 361
with a display (the file also carries issue 0191's CTRL-wheel groups
`CW*`/`CD*`/`CS*`/`CE*`). Auto-discovered by `full_audit.sh`.

| group | arm | defends |
|---|---|---|
| `AZ*` | both | the region and its four refusals, the corner rule, fail-closed, `vlegend`, a **digital** strip, and **no raw loaded** (the leg that dies if `graph_plotbox_at`'s raw gate is ever copied in) |
| `AM*` | both | both endpoints of both maths, the full-extent and half-extent worked checks, the click/drag boundary from both sides **at the parsed `GRAPH_CLICK_TOL`**, the zoom-out clamp **both as a bound (`AM8`) and as an exact equality on a strip wide enough to make it bind (`AM12`)**, the log axis, the release clamp, fail-soft |
| `AV*` | both | the apply — **witnessing every rect**: X propagates, `unlocked` does not follow, a foreign `sim_type` does not follow, Y is per-graph, digital Y is `ypos1/2`, `modified` stays 0 *with a control leg proving the probe can reach 1*, and read-only still applies |
| `AL*` | both | exactly one log line per commit, in the verb form, with data bounds; and **replaying that line reproduces both rects' windows** |
| `AS*` | both | the anchored expression appears once in `draw.c`, `graph_axis_map()` is called once from `callback.c` and once from `scheduler.c`, `GRAPH_CLICK_TOL` stayed file-private, **the getter takes its threshold from `graph_click_tol()` and carries no numeric copy of it (`AS3`)**, and `graph_axis_zoom()`'s body contains no `set_modify`/`push_undo` |
| `AG*` | display | the real C gesture: what arms and what does not (body, legend, grip, **and a press that grabbed a cursor — asserting both that no axis drag armed and that `graph_flags & 512` really was set**), the two full gestures, the sub-threshold no-op, ESC mid-drag, X-propagates/Y-does-not, `modified` still 0, the whole press/arm/release path on a strip whose rect index is NOT 0 (`AG13`), **the GRAPHPAN routing-latch term itself — top-left-corner press, release OUTSIDE the strip (`AG14`, §3.2)** — and **an abandoned arm not poisoning the next plot-body drag (`AG15`, §3.2)** |
| `AX*` | display | the ASE viewer seam through the **shipped bindings**: a margin press does not arm the reorder and does not change the strip order (inert `sdid` witness), a body press and a grip press still do, the buffer stays `modified 0` / `readonly 1`, ESC cancels (**through the focus-retry sender, with the delivery itself asserted**), and `history_depth` does not move. Every context switch in the group is confirmed by `ax_ctx` |

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

## 4b. EYEBALLED — PASS (2026-08-01)

Verified by the user on a real ASE waveform window, together with 0191. Closes
the eyeball list in §5, and in particular the **one risk this issue's own
remediation introduced and reported on itself**:

* **No stale rubber band.** `graph_axis_drag_abort()` clears `graph_rubber_active`
  *without* erasing an already-painted band — unlike the release path at
  `callback.c`, which calls `drawtemprect(gctiled)` first — and the new call site
  in `waves_selected()`'s `!is_inside` branch has no guaranteed redraw of its own.
  `AG15` proves the STATE is dropped; only this look could confirm no outline
  survives on screen. It does not.
* The band itself renders and erases cleanly during the drag, across the
  un-dragged axis.
* **3 px of travel is accepted** as the click-vs-drag threshold for a margin
  gesture (`GRAPH_CLICK_TOL`, reused but compared in SCREEN pixels here rather
  than world units — it is a parameter of `graph_axis_map()`, so raising it for
  the axis drag alone stays a one-line change if that ever changes).
* The deliberate **absence of a pointer-cursor change** while an axis drag is
  armed is accepted (the strip reorder sets `sb_v_double_arrow`, the trace drag
  sets `hand2`, this sets nothing).
* Axis tick labels remain legible after a zoom, and **losing the two axis margins
  from the ASE viewer's strip drag-reorder grab area is not noticeable in use**.

## 5. NOT COVERED BY ANY CHECK (the eyeball list)

The rubber band's pixels; the drag *feel*; whether the tick labels are still
legible after a zoom; the (absent) pointer-cursor change during the drag; and
whether losing the axis margins from the viewer's strip reorder is noticeable in
use.

---

## 6. FOLLOW-UP: D-19's digital branch was documented and never implemented

Recorded 2026-08-01 while implementing issue **0191** (the CTRL+wheel twin of
this gesture), which needed the identical sub-answer and therefore had to look.

D-19 said a digital strip's Y is the `ypos1`/`ypos2` band "through `DG_Y`". The
**apply** did that — `graph_axis_zoom()` reads `digital` straight off the rect
and writes `ypos1`/`ypos2`. The **map** did not: `graph_axis_map()` resolved the
Y window as

```c
    e1 = S_Y(gr->gy1); e2 = S_Y(gr->gy2);
    A = gr->gy1; B = gr->gy2;
```

unconditionally — the analog window and the analog transform.

**MEASURED at `826e1b60`** on a digital strip with `y1=0 y2=2.5 ypos1=0 ypos2=4`:

```
xschem get graph_axis_at  0 22 526        -> y
xschem get graph_axis_map 0 y  526 267    -> 0.34586281243181671 1.9021063678409851
```

Both endpoints lie inside `[0, 2.5]`, and `graph_axis_zoom` then put them into a
band whose real extent is `[0, 4]`. A full-height left-margin drag on a digital
strip therefore mis-zoomed it by ~2.6× and anchored in the wrong place.

**Corrected in 0191**, not as an opportunistic fix but because the new formula
asks the same question and a second copy of a known-wrong resolution is landmine
45(a)/47(b): the resolution is now one shared helper, `graph_axis_window()`
(static, `src/draw.c`), called by `graph_axis_map()` **and**
`graph_axis_wheel_map()`, with the digital branch using `ypos1`/`ypos2` + `DS_Y`
and the inverse using `DG_Y`. `test_wave_axis_zoom.tcl`'s `CD2` leg is the first
assertion that makes D-19 true — and it had to be written as a **REVERSE** drag:
the forward branch is `lo = A + ua*R` with `ua = (q - A)/R`, which collapses to
`lo = q` for any window, so a forward-drag leg cannot see which window was used
at all (measured — it stayed green with the digital branch deleted).

**Why this suite never caught it:** `AZ11` only *queries* a digital strip's
region and `AV5` only calls the *verb* on one with hand-supplied bounds. Nothing
drove the MAP on a digital strip until 0191.
