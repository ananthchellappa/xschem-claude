# 0191 — CTRL+wheel in an axis-number margin zooms that axis about the pointer

**Status:** FIXED (2026-08-01)
**Branch:** `fluid-editing`. Reported as item 04 of the 2026-08-01 overnight
waveform batch.

> In the axis regions - where the LMB press-and-drag for zoom is supported,
> CTRL+Scroll_wheel will support zoom in/out for THAT AXIS ONLY. Zooming will be
> around the mouse pointer. That is, the point(s) on the trace(s) that are at x1
> (position of the mouse pointer) will remain there after zoom.

Spec: `doc/claude/specs/waveform_viewer_modes.md` **§18** (plus four new rows in
§15.1 and a correction box in §17.3).
Decision doc (D-25…D-40, continuing issue 0190's ledger):
`doc/claude/code_analysis/ovb01_04_axis_region_ctrl_wheel_zoom_decision.md`.
Depends on issue **0190**, whose `graph_axis_at()` and `graph_axis_zoom()` are
reused verbatim.

---

## 1. WHAT CTRL+WHEEL DID BEFORE — measured, and three comments were wrong

The single most load-bearing fact of this item is that **a wheel event over a
graph never reaches the binding table.** `handle_button_press()`
(`src/callback.c`) opens with an inline
`if(waves_selected(...)) { waves_callback(...); return; }`, and
`handle_mouse_wheel()` is only reached fourteen branches later. So for any wheel
press whose pointer is inside a graph rect, the function has already returned.

Consequently the four `ACTX_OVER_GRAPH` wheel rows in `init_input_bindings` are
**unreachable dead code**, and three source comments described a behaviour that
does not exist:

* `callback.c`'s binding-table comment — "Ctrl-wheel never did, so it has no
  over_graph row and stays canvas pan" — is true only when the pointer is **off**
  every graph;
* `wave_viewer.tcl`'s — "Ctrl+wheel is hard-pinned to CANVAS zoom
  (callback.c:4417)" — is wrong twice over: over a graph it is neither the canvas
  nor a zoom, and the cited line no longer exists.

**MEASURED** on an embedded schematic graph with `graph_use_ctrl_key = 0`
(one `flags=graph` rect, `x1..x2 = 0..1`, `y1..y2 = 0..2.5`, pixels derived from
`graph_plotbox_at`, each chord fired as
`xschem callback .drw 4/5 <px> <py> 0 <4|5> 0 <state>`):

| chord | plot BODY | bottom (X) margin | left (Y) margin |
|---|---|---|---|
| plain wheel | graph X **pan** ±0.05·gw | graph X **pan** | graph Y **pan** ±gh/divy |
| Shift+wheel | graph X **zoom**, anchored, ×0.8 in / ×1.2 out | same | graph Y **zoom**, anchored |
| **Ctrl+wheel** | graph X **pan** — byte-identical to the plain wheel | graph X **pan** | graph Y **pan** |

`xorigin`/`yorigin`/`zoom` never moved in any of the twelve trials.

**In the ASE viewer**, Ctrl+wheel anywhere on a strip zoomed **both** axes
(X on every strip, Y on the pointed one — issues 0144/0146). That is the
behaviour the user asked to narrow *in the margins only*.

So the feature is real, and "leave the body unchanged" means "leave it
**panning the graph**", not "leave it panning the canvas".

---

## 2. THE FIX

One formula, in C, reached by both surfaces:

```
                       graph_axis_window()        <- NEW, static, draw.c
                       (which window, which pixel extent, digital-aware)
                          |                 |
          graph_axis_map()                  graph_axis_wheel_map()   <- NEW
          (0190, the DRAG)                  (0191, the WHEEL)
                 |      |                       |          |
    callback.c release  |     callback.c CTRL+wheel arm    |
                 scheduler.c                     scheduler.c getter
                                                            ^
                                     wviewer::wheel_zoom's new `axis` arm
```

`graph_axis_at()` (the region) and `graph_axis_zoom()` (the apply) are 0190's and
are reused unchanged.

**The maths**, with `[A,B]` the current window, `R = B - A`, `p` the pointer's
canvas pixel clamped to the plot extent, `K = GRAPH_AXIS_WHEEL_FACTOR = 0.8`:

```
  f  = up ? K : 1/K       q = G_axis(p)      u = (q - A)/R
  R2 = R * f              lo = q - u * R2    hi = lo + R2
```

`(q - lo)/(hi - lo) == u`, so the data coordinate under the pointer keeps its
screen pixel. **That is the whole specification.** `lo = A + (R - R2)/2` has the
right width and the wrong place and passes every "the range shrank" assertion —
which is why the suite's decisive legs re-ask `xschem graph_coord` for the same
pixel *after* the write, and why every probe pixel is at **25 %** of the plot
extent (at the centre the two forms agree).

The step is a **reversible** multiplier: N clicks in and N back out restore the
window exactly. The shipped Shift+wheel arms are ×0.8 in / ×1.2 out and lose 4 %
of the range per round trip; matching them would have bought only a
"returns approximately" assertion.

**Files:**

| file | what |
|---|---|
| `src/xschem.h` | `GRAPH_AXIS_WHEEL_FACTOR 0.8` (**mirrored in Tcl**) + the `graph_axis_wheel_map` prototype |
| `src/draw.c` | `graph_axis_window()` (new static, the shared window resolution) + `graph_axis_wheel_map()` (new); `graph_axis_map()` rewired onto the helper |
| `src/callback.c` | the CTRL+wheel arm in `waves_callback`, the `wheel_axis_done` local, `&& !wheel_axis_done` on the two plain-wheel arms, and the corrected binding-table comment |
| `src/scheduler.c` | `xschem get graph_axis_wheel_map <gi> x\|y <p> in\|out`, fail-soft |
| `src/wave_viewer.tcl` | `wviewer::axis_wheel_window` (asks C), `wheel_zoom`'s new `{axis {}}` argument, `wheel`'s `ctrl` rung, and the corrected comment |

**Decisions worth surfacing** (full list in the decision doc §5):

* **D-27** the step is `0.8`, taken from the viewer's Ctrl+wheel and not from
  `callback.c`'s non-reversible Shift arms;
* **D-29** the axis window is one shared helper — which necessarily corrected
  0190's digital branch (see §4);
* **D-32** the arm is gated **off** under `graph_use_ctrl_key`, where Ctrl is the
  graph *access* modifier;
* **D-34** no `GRAPH_AXIS_ZOOM_MAX_FACTOR`: it guards a division by a drag span
  that a wheel map does not have;
* **D-35** no dirty flag, no C undo, no viewer undo point — a zoom is view state;
* **D-36** the viewer writes its Tcl MODEL, so unlike 0190's rect-only write a
  window resize does not discard it;
* **D-37** the engine path self-logs one replayable `graph_axis_zoom` line; the
  viewer path logs nothing, like every other viewer range gesture.

---

## 3. TESTS

`tests/headless/test_wave_axis_zoom.tcl` (0190's suite), five new groups:
**128 → 200** checks in the `--nogui` arm, **196 → 338** with a display
(190 / 308 at first commit; the repair pass below added the rest).

`CW*` the map and its verb (fail-soft, the closed form, the WIDTH leg kept
separate from the FIXED-POINT leg, the round trip, the other axis byte-identical
on every rect, propagation, edge pinning, the clamp); `CD*` the digital window
with the two ranges staged **disjoint**; `CS*` source-level one-home tripwires
including the C↔Tcl mirrored constant; `CE*` the real gesture on an embedded
graph plus every "unchanged" regression witness from the measured table above,
`graph_use_ctrl_key`, a non-zero strip index and a `--logdir` child proving the
gesture self-logged one replayable line; `CV*` the live ASE viewer through the
shipped `<Control-Button-4>` bind.

Eleven named sabotages, each applied, verified and reverted:

| # | sabotage | killed |
|---|---|---|
| SAB-1 | zoom about the CENTRE | 9 fixed-point / closed-form legs — and **not** `CW2`, the width leg. The distinction the suite is built on |
| SAB-2 | apply to both axes in the arm | `CE3` + `CE1`'s other-axis witness + `CE9`'s log legs + the `AS1` count |
| SAB-3 | fire regardless of region | `CE5` (the body still pans) + the two Y-margin legs |
| SAB-4 | delete the digital branch | `CD1`/`CD2`/`CD3`/`CD4` + `CS4`. Its answer matched the pre-0191 analog closed form to the digit |
| SAB-5 | drift the Tcl `0.8` to `0.75` | `CS2` **only**, in both arms |
| SAB-6 | viewer drops the `axis` argument | `CV1`/`CV2`'s single-axis legs |
| SAB-7 | drop `!wheel_axis_done` | `CE1b` (named) and every other X-margin engine leg — the clobbering pan destroys the whole window, so the blast radius is unavoidable |
| SAB-8 | drop `&& !(state & ShiftMask)` from the arm | `CE13`'s two log legs, `CE12`'s Y-margin leg, `CE9`'s two line-count legs — and **no** X-margin window leg |
| SAB-9 | viewer X arm asks C for `$gi` instead of `$t` | `CV7`'s two per-strip legs **only**; `CV1` stays green |
| SAB-10 | viewer Y branch gated on `$t == 0` | `CV8`'s two legs only |
| SAB-11 | `pow(10,·)` the anchor `q` on a log axis | `CW10`/`CW11`'s six log legs only; `CW10`'s width leg survives |

### 3.1 The repair pass (2026-08-01, after the adversarial verifier)

Four holes, each now closed by a leg that a named sabotage kills:

1. **`!(state & ShiftMask)` had zero coverage.** No test anywhere in
   `tests/headless` sent a Ctrl+Shift wheel over a graph — every `ce_click` call
   site used state 0, 1 or 4 and `cv_wheel` was hard-coded to `-state 4`.
   Deleting the term left both arms fully green. It is **not** inert: the
   suppressed arm applies on its way past and `graph_axis_zoom()` self-logs.
   In the **X** margin the final window is byte-identical anyway, because the
   per-graph loop reloads `gr->gx1/gx2` from `master_gx1/master_gx2` (captured
   *before* the master block) and the Shift arm overwrites with the same numbers
   — an accident of ordering, not an assertion. In the **Y** margin it is
   visible, because `setup_graph_data` re-reads `y1`/`y2` from the tokens the
   suppressed arm just wrote. `CE12` asserts the window in three chords (X up, X
   down, Y up) and `CE13` asserts the log: 1 line shipped, 3 sabotaged.
2. **`CV1`'s fixture could not see D-33.** Both strips were staged to the
   identical `0..1.0`, where "each strip anchored in its own window" and "strip
   0's answer broadcast" give the same numbers — precisely the case D-33 is
   about. `CV7` stages `0..1.0` and `0..2.0` and names which answer each strip
   got.
3. **The viewer's per-object state was witnessed on one object.**
   `wviewer::wheel_zoom`'s y branch is gated on `$t == $gi` with `$gi` from
   `wviewer::graph_at_pointer`, and `CV2` was the only Y-margin viewer leg —
   pointing at strip 0. `CV8` is `CE10`'s viewer counterpart and asserts
   `graph_at_pointer` resolves 1 before it wheels.
4. **PLAN Q6 (log axes) was implemented by inheritance and never asserted for
   the WHEEL map.** `AM9` sets `logx` on the *drag* map only. `CW10`/`CW11` set
   `logx` / `logy`, re-derive the anchored form in log space, assert neither
   bound left the `-3..0` token range and re-measure the fixed point.

Two fixture lessons, both measured, both now carried by the code:

* a **predicted** margin pixel is not good enough for a leg that runs late in a
  long-lived viewer session. `CV8`'s Y probe is found by asking
  (`cv_yprobe` → `graph_axis_at`), with a re-scan, because `az_ymargin`'s
  midpoint is geometry and `graph_axis_at` has four refusals geometry cannot see
  — and any `update` can deliver a `<Configure>` that re-lays the viewer out.
  With the midpoint the gesture silently degraded to the body zoom on ~1 run in 3
  and **only** the "every strip's x1/x2 unchanged" leg saw it (the body zoom
  scales Y by the same `K`, so every Y leg passed);
* the pre-existing `CV1`–`CV6` legs still use the probe pixels cached at `CV0`
  and carry the same exposure. Not touched here (out of this repair's scope), but
  recorded: a `CV3`/`CV4`/`CV7` failure showing "X unchanged, Y zoomed" is that
  flake, not a product defect.

One structural change came out of it: `CE13` rides in `CE9`'s `--logdir` child
rather than opening a second one. A second GUI child put another toplevel on the
display, and under WSLg that restacked/resized the parent canvas often enough to
land the `AX*`/`CV*` cached probe pixels on the wrong strip about **1 run in 8**
(measured both ways: 8/8 green before, 7/8 and 3/4 with the extra child, 10/10
after merging it). `CE9`'s `celine` also now takes the **first** matching log
line, not the last, so its replay legs stay an independent statement about the
plain-Ctrl gesture.

---

## 4. A DEFECT IN 0190 THIS ITEM HAD TO CORRECT

`graph_axis_map()` resolved a digital strip's Y window from `gy1`/`gy2` and
`S_Y` unconditionally, while `graph_axis_zoom()` wrote the answer into
`ypos1`/`ypos2`. MEASURED on `y1=0 y2=2.5 ypos1=0 ypos2=4`:
`xschem get graph_axis_map 0 y 636 310` → `0 1.6437` — the analog window, applied
to a band of extent `0..4`. 0190's own D-19 was documented and never implemented.

Not fixed opportunistically: the new formula asks the identical question, and a
second copy of a known-wrong resolution is exactly the drift landmine 45(a)/47(b)
exists to prevent. Recorded in `doc/claude/issues/0190-axis-region-drag-zoom.md`
§6 and in the reference's landmine 47(d).

---

## 5. NOT COVERED BY ANY CHECK (the eyeball list)

The item introduces **no new rendering** — no band, no glyph, no chrome. What no
test can see:

* whether one wheel click of 20 % is the right *step* in a narrow margin, or
  whether the margin is a comfortable place to aim the pointer at all
  (`GRAPH_AXIS_WHEEL_FACTOR` in `src/xschem.h` is the knob, and the Tcl mirror in
  `wviewer::wheel_zoom` must move with it);
* whether the anchored zoom *feels* anchored when the pointer sits in the margin
  rather than on a trace (the invariant is exact; the perception is not tested);
* whether narrowing the viewer's margin Ctrl+wheel from "both axes" to "one axis"
  reads as a feature or as a dead zone to a user who learned the old behaviour.
