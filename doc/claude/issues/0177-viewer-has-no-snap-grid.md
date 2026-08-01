# 0177 — the waveform viewer must have NO schematic snap grid, anywhere

**Status:** FIXED (2026-07-30), **EYEBALLED PASS** — with one unrelated
observation carried to issue 0178 (RMB on a legend entry was toggling the
selection instead of opening the trace context menu).
**Branch:** `fluid-editing`. Reported at the 0175 eyeball, which passed with this
one exception.

> Implementation seems ok except that the "snap grid" seems to be at play when
> it comes to clicking on the legend text.
>
> though a schematic window has been used to implement the waveform viewer,
> there is no concept of schematic snap grid, so clean that up.

Two asks: a defect on the legend click, and an architectural one — make "this
canvas has no snap grid" a **property of the viewer** rather than a local
override that every new code path has to remember to repeat.

---

## 1. THE MEASURED MECHANISM

Not a list of suspects. Measured on the shipping build, ASE viewer, 3 traces,
canvas 1000x776, `zoom 0.2738`, `tk_scaling 1.334`, driving real Tk `<Motion>`
and `<ButtonPress-1>`/`<ButtonRelease-1>` through the production bindings.

The whole thing turns on **one boundary**, at canvas row **y = 22** — which is
`6` xschem units below the strip rect's top edge:

```
column scan at x=420, cadsnap=400        BEFORE                AFTER
  y    cursor    mirror        legend?   plotbox?
  0    {}        GRID-SNAPPED  no        no      |  routing flips at y=22   ->  y=7
  2    {}        GRID-SNAPPED  YES       no      |  mirror snapped 0..21    ->  never
 22    tcross    raw           YES       no      |
110    tcross    raw           no        YES     |

Motion -> Press -> 1px jitter -> Release, on each of the three legend entries:
  y=2    query 0/1/2  ->  selects NOTHING          ->  (after) selects 0/1/2
  y=8    query 0/1/2  ->  selects NOTHING          ->  (after) selects 0/1/2
  y=22   query 0/1/2  ->  selects 0/1/2
```

### 1.1 Why the pointer was grid-snapped over the legend

`waves_selected()` (`callback.c` ~77) decides whether an event belongs to a
graph. Its geometric test insets the strip rect by a margin:

```c
border = (int)(5.0 * tk_scaling);   /* "fixed number of screen pixels" */
...
POINTINSIDE(xctx->mousex, xctx->mousey, r->x1 + border, r->y1 + border,
                                        r->x2 - border, r->y2 - border)
```

**The comment says screen pixels. The arithmetic is in XSCHEM units.**
`r->x1`/`r->y1` are schematic coordinates, and `X_TO_XSCHEM(x) = x*zoom - xorigin`,
so one screen pixel is `xctx->zoom` xschem units. The inset was therefore
`1/zoom` too wide: **21.9 canvas pixels where 6.7 were intended**, a 3.3x
overshoot. (The `(int)` cast also floored it, quietly making it 5 units rather
than 5 pixels at `tk_scaling 1.0`.)

`legend_slot_hit()` starts its horizontal legend slots at `gr->ry1` — **the rect
top itself** (`draw.c` ~4518, `yt1 = gr->ry1`). So that 22-pixel band sat
directly on top of the legend entries. Inside it:

- `waves_selected()` returns 0, so `handle_motion_notify()` never reaches
  `waves_callback()` and falls through to the **schematic arm**;
- issue 0143's local un-snap at `callback.c` ~810 therefore never runs, and
  `mousex_snap`/`mousey_snap` keep the grid-quantised values written at the top
  of `callback()`;
- the schematic arm then draws `draw_crosshair(2, state)`, which paints **at**
  `xctx->mousex_snap` (`callback.c` ~2646, ~2683) — i.e. hopping in `cadsnap`
  steps. It also runs `draw_snap_cursor` and `draw_hover`.

### 1.2 Why 0175's probe did not see it

Two reasons, and both are the escape:

1. **It generated no `<Motion>`.** The crosshair is drawn from the motion pump.
2. **It probed legend row 54**, which is *below* the 22-pixel band. The band is
   the top of the legend, not all of it.

### 1.3 Why the reporter saw it and the default build does not

`src/cadence_style_rc` — the rc this user actually runs — sets
`draw_crosshair 1`, `crosshair_size 2`, `snap_cursor 1`, `snap_cursor_size 4`,
`use_cursor_for_selection 1`. The shipped defaults are all `0`
(`src/xschem.tcl` ~15438, ~15528). With the defaults there is nothing to draw in
that band, so the same code is invisible. On the reporter's build, moving the
pointer onto the top of a legend entry made a schematic crosshair appear and
snap to the grid — which is exactly "the snap grid is at play when it comes to
clicking on the legend text".

`use_cursor_for_selection 1` adds a second visible consequence in the same band:
a press there takes the schematic press path and **selects the graph rect as a
schematic object**, at the snapped coordinate (`callback.c` ~7396).

### 1.4 The full inventory of grid-snapped surfaces reachable from a viewer canvas

| site | file | reached |
|---|---|---|
| `mousex_snap`/`mousey_snap` computed from `cadsnap` | `callback.c` ~8194 | every event, every region |
| `statusmsg("mouse = …", mousex_snap, …)` | `callback.c` ~8199 | every event (bar hidden by `pack forget`, but written) |
| `draw_crosshair` shape position | `callback.c` ~2646, ~2683 | the rect-edge band, and outside every rect |
| `draw_snap_cursor` repaint gate + fallback position | `callback.c` ~2570, `findnet.c` ~208 | same, with Shift held |
| motion `statusmsg` while `ui_state` | `callback.c` ~5267 | same |
| click-select coordinate under `use_cursor_for_selection` | `callback.c` ~7396 | same |
| cadence release-collapse re-select | `callback.c` ~7771 | same |
| `graph_at_pointer` (Tcl, the wheel target) | `wave_viewer.tcl` ~4934 | any wheel event |
| `over_graph` (Tcl, the `a`/`b`/`s`/`m`/`t`/Delete key gate) | `wave_viewer.tcl` ~5548 | any of those keypresses |

Issue 0143's single local un-snap covers **none** of these. That is the point of
the issue.

The last two are worth naming separately, because they are user-visible bugs the
report did not mention and the property fixed for free:

- **`graph_at_pointer`** answers "which strip is the wheel over" by testing
  `xschem get mousex_snap` against the band registry. A Tk `<MouseWheel>` bind
  `break`s, so no C callback runs for it; the value it reads is whatever the last
  event left. Deterministically snapped on the **View > Zoom In/Out menu path** —
  clicking a menubar entry means the pointer left the canvas, and LeaveNotify
  goes through `callback()` but not through `waves_callback`. With `cadsnap 10`
  that is a 10-unit quantum: within half a cell of a band boundary the wheel
  zoomed the **neighbouring strip**.
- **`over_graph`** is the gate that decides whether the graph keys reach C at
  all. A `<KeyPress>` likewise has no preceding C callback of its own, so within
  half a grid cell of the viewport's outer edge the snapped point rounded outside
  every band and `a`/`b`/`s`/`m`/`t`/Delete were **silently swallowed**.

Both are now correct because the mirror they read is raw. Neither needed its own
patch, which is the argument for (a) over (c) in one paragraph.

---

## 2. THE FIX — a property, not another override

### 2.1 What was chosen: (a), implemented on the `no_grid` precedent

A new per-context flag `xctx->no_snap` (`xschem.h`), reachable from Tcl as
`xschem set no_snap 1` / `xschem get no_snap`, consulted **where the two fields
are born**:

```c
/* callback.c, ~8200 */
xctx->mousex = X_TO_XSCHEM(mx);
xctx->mousey = Y_TO_XSCHEM(my);
if(xctx->no_snap) {
  xctx->mousex_snap = xctx->mousex;
  xctx->mousey_snap = xctx->mousey;
} else {
  xctx->mousex_snap = my_round(xctx->mousex / c_snap) * c_snap;
  xctx->mousey_snap = my_round(xctx->mousey / c_snap) * c_snap;
}
```

One test, before the grid arithmetic, covering every downstream reader forever —
which is what the ask was. `wviewer::open` sets it next to the `no_grid` and
`graph_snap_cursor` it already sets.

The prompt asked for "a cheap, reliable 'is this a viewer window' test in C". A
per-context flag **is** that test, and it is the shape this file already uses
twice (`no_grid` for the grid/origin, `graph_snap` for the item-9 diamond), for
the identical blast-radius reason. It is also, in effect, a degenerate form of
option (b): a per-window snap value whose only two states are "the global grid"
and "no grid".

**The two schematic pointer glyphs are turned off by the same property**, at
their single source in `callback()`:

```c
int draw_xhair   = tclgetboolvar("draw_crosshair") && !xctx->no_snap;
int snap_cursor  = tclgetboolvar("snap_cursor")    && !xctx->no_snap;
```

Neither is a viewer concept: `draw_crosshair` paints *at* `mousex_snap`, so on a
grid it **is** the snap grid made visible; `draw_snap_cursor` snaps to the
nearest net or symbol pin, of which a waveform canvas has none. Gating the two
locals covers every use in the `callback()` call tree with one test each,
instead of chasing each drawing site.

### 2.2 And the units bug, separately

```c
border = 5.0 * tk_scaling * xctx->zoom;   /* was (int)(5.0 * tk_scaling) */
```

This is a correctness fix independent of the snap property — it restores the
value the comment always claimed. It is what makes the top of a legend entry
clickable at all.

**Blast radius, stated precisely, because it is NOT viewer-scoped.**
`waves_selected()` runs for every context that owns graph rects, embedded
schematic graphs included. The old band's on-screen width was `6/zoom` pixels, so
it was correct only at `zoom ≈ 1` and wrong in *both* directions:

| `zoom` | | old band | new band |
|---|---|---|---|
| 0.1 | zoomed in | 60 px | 6.7 px |
| 0.27 | the measured viewer | 21.9 px | 6.7 px |
| 1.0 | | 6 px | 6.7 px |
| 10 | zoomed out | 0.6 px | 6.7 px |

So an embedded graph on a zoomed-in schematic becomes noticeably *grabbier* (its
edge reserves 6.7 px instead of 60), and on a zoomed-out one it stops being
un-grabbable (0.6 px was less than a pixel of margin). Both are the documented
intent — "a fixed number of screen pixels" — and the whole point is that the
margin no longer changes size as you zoom. Witnessed by `test_graph_box_zoom_xy`,
`test_graph_context` and `test_key_graph_context`, which drive graphs on `.drw`.

### 2.2b Does anything on a viewer canvas LEGITIMATELY want a grid?

Option (a) changes the value seen by *every* handler on that window, which is the
point, but it has to be checked against readers that want the grid on purpose.
Three independent adversarial passes over the tree found **one**, and it is inert:

- **`break_wires_at_point(xctx->mousex_snap, xctx->mousey_snap, 1)`**
  (`callback.c` ~7241, Button3 + `EQUAL_MODMASK`) is the only consumer whose own
  comment says it wants the grid — *"move break point to nearest grid point"*.
  It is reachable on a viewer, because `wviewer::strip_bindings` forwards every
  Button-3 press to C. It is inert there: a waveform canvas holds only
  `rect[GRIDLAYER]` graphs, so there is no wire to break.

Everything else either wants raw pixels (`graph_at_pointer`, `over_graph`,
`legend_slot_hit`, the box-zoom and pan gates, `findnet.c`'s fallback) or is
inert on a read-only viewer. Two readers are *change-detect gates* that were
weakly relying on the grid as a motion filter — `draw_snap_cursor`'s
`pos_changed` and `redraw_w_a_l_r_p_z_rubbers`' early-out — and both now flip per
pixel instead of per grid cell on a `no_snap` canvas; both are switched off there
anyway (the first by the property, the second because every consumer needs an
armed `START*` gesture a read-only window cannot have).

### 2.3 Why (b) and (c) were rejected

**(b) — make `c_snap` genuinely context-scoped** (a per-window snap *value*, with
the viewer's set to "none"). Rejected on cost, not on principle; it is the more
honest data model and the file says so. `cadsnap` is not one variable: it is a
Tcl global that is also a **saved/restored per-window context variable**
(`tctx::global_list`, `src/xschem.tcl`), it is written by the Options menu, by
`xschem set cadsnap`, by rc files and by several tests, and it is read as a
double in `callback()` and as a Tcl var in a dozen Tcl procs. Giving it a real
per-context home means moving all of that, and the only behaviour it buys over
(a) is the ability for a *schematic* window to have a different grid from
another schematic window — which nothing has asked for. (a) delivers the whole
of the actual ask at a fraction of the surface. If a per-window grid VALUE is
ever wanted, `no_snap` is the degenerate case of it and converts cleanly.

**(c) — keep the local overrides and add the missing ones.** Rejected outright,
and the reason is this issue: (c) is what 0143 did, this is the second session on
the subject, and §1.4 lists eight surfaces that would each need their own
override plus a promise from every future author. It is the option that
guarantees a fourth session.

### 2.4 What 0143 keeps

`waves_callback`'s own un-snap at `callback.c` ~810 **stays**, and its comment
now states its scope honestly. It is not superseded: an ordinary **schematic**
window can embed graphs, `waves_callback` runs on those too, and that context is
not `no_snap` — its grid is real and wanted everywhere except inside a graph.
`tests/headless/test_graph_box_zoom_xy.tcl` drives exactly that case on `.drw`
and goes red the moment the line is deleted. Issue 0143 is **extended, not
superseded**; see the note added to its file.

---

## 3. WHAT THE VIEWER CANVAS DRAWS FOR A POINTER HOVER, BY REGION

After the fix. A strip is the `xRect` in `rect[GRIDLAYER]`; the PLOT BOX
(`gr->x1..x2 / y1..y2`) is strictly inside it, inset by 14% of the rect.

| region | routed to | drawn under the pointer | cursor | plain LMB click selects |
|---|---|---|---|---|
| plot body | graph | **the item-9 diamond**, on the nearest sample of the nearest trace | `tcross` | the trace within 10 px, else clears the selection |
| legend band (above the plot box) | graph | **nothing** | `tcross` | the trace of the entry under the pointer |
| left / bottom axis margin | graph | **nothing** | `tcross` | nothing (horizontal legend); the row's trace if `vlegend` or `digital` |
| the strip reorder grip | graph | **nothing** (the three grip bars are static, not hover feedback) | `tcross` | nothing, unless the pointer is also in the legend band |
| the rect-edge inset (5 screen px) | schematic canvas | **nothing** — `draw_crosshair` and `draw_snap_cursor` are off on this context; `draw_hover` may outline the rect | default | the graph rect, as a schematic object |
| outside every rect | schematic canvas | **nothing**, same reason | default | starts a rubber-band area select |

**"The schematic crosshair" does not appear in this table**, which was the
requirement. The last two rows are the margin that keeps the rect grabbable at
all; they are now 5 screen pixels wide instead of `5/zoom`, and they are the only
rows where the pointer leaves the graph.

---

## 4. TESTS

`tests/headless/test_wave_snap.tcl` (it owns snap and the item-9 diamond).

Headless — **`SN1`–`SN10`**: the flag round-trips and is per context; the
letter-dispatch trap (`SN5`, the `SP5` clone); source tripwires that the branch
is at the SOURCE and the grid arithmetic is the *other* arm (`SN6`); that 0143's
override survives (`SN7`); that both glyph locals are gated (`SN8`); that the
inset is converted (`SN9`); that `wviewer::open` arms it (`SN10`).

DISPLAY — **`SNG1`–`SNG6`**, all of them real Tk gestures:

- `SNG1` the blast-radius pair: the viewer answers 1, `.drw` answers 0.
- `SNG2` a `<Motion>` sweep down the whole viewer canvas under `cadsnap 400`
  leaves the mirror on the grid at **zero** of ~150 rows — legend band, axis
  margins, grip and rect edge included.
- `SNG3` the **inverse** witness, which did not exist anywhere in the tree
  before: the same sweep on `.drw` leaves it on the grid at **every** row. A flag
  that leaked onto a schematic context was previously caught only implicitly, by
  whichever gesture suite happened to depend on an exact drag delta.
- `SNG4` the escape itself — `Motion → Press → 1 px jitter → Release` on each of
  three legend entries selects that entry, **and a 40x coarser grid returns the
  same three answers**. The jitter is deliberate: a press and release at
  byte-identical coordinates is not reachable with a hand on a mouse, and its
  absence is why 0175's probe came back clean.
- `SNG5` **hover**, which nothing covered before: a legend hover is routed to the
  graph (`tcross`) and publishes no snap.
- `SNG6` walks the whole legend band and counts the rows that fall in the
  rect-edge inset: `<= 12` (the measured band runs y=1..108 with routing from
  y=7, so 6 rows; before the units fix routing started at y=22), and `> 80%` of
  the band routes to the graph. A fraction, not a pixel count, so the leg stays
  honest across window sizes and tk scalings.

Both fixes were **sabotage-verified behaviourally**, not just by source grep:
disarming `no_snap` in `wviewer::open` reddens `SNG2`; reverting `border` to the
un-converted form reddens `SNG6`.

`test_wave_trace_menu.tcl` **TL4** had to be repaired rather than left alone: it
proves the legend QUERY is snap-immune by setting `cadsnap 400` on the viewer,
and once `no_snap` is armed that no longer perturbs anything — the leg would have
gone **hollow, not red**. It now drops the property for the duration of the probe
(and asserts the mirror really is on the grid while it does), then restores it.

⚠ **Writing that witness surfaced a third way the leg had lost its teeth, and it
is worth stating on its own:** even with `no_snap` disarmed, a motion **anywhere
the graph owns** is routed to `waves_callback`, which un-snaps both mirrors at its
head — so no probe inside a strip can ever observe a snapped mirror. TL4's
parking motion sits at `x = 0.02 * W` (about 20 px), which before this issue fell
inside the 21.9-px rect-edge inset and therefore took the *schematic* arm and a
snapped mirror; after the units fix that same pixel is 3x outside the 6.7-px
inset and routes to the graph. The witness now probes canvas `(1,1)`, which is
still inside the inset. That the old parking pixel changed arms is itself
independent evidence the units fix does what it claims.

Measured counts after this issue: `test_wave_snap` **86** DISPLAY / **50**
`--nogui` (was 59/36).

---

## 5. NOT VERIFIED / EYEBALL

The suite cannot close this one, same as 0175 — every drawn glyph in §3 is
painted window-only with `draw_pixmap = 0` and cannot be read back. The manual
sequence is §6 below.

Open, deliberately not done here:

- `wviewer::graph_at_pointer` (`wave_viewer.tcl` ~4934) reads
  `xschem get mousex_snap` for the wheel target. It is now unsnapped by the
  property, so it is correct — but it is still the one Tcl reader of the mirror
  in the viewer, and `strip_at_pixel` next to it exists precisely because the
  mirror is also *stale* for an event with no preceding Motion. Staleness is a
  freshness problem, not a snap problem, and is out of scope.
- The rect-edge inset still lets a press select the graph rect as a schematic
  object (§1.3). Harmless on a read-only canvas, and the band is now 5 px.
- **`handle_enter_notify` has an un-guarded edit path** (`callback.c` ~5229):
  when `lastsel == 0` and `~/.xschem/.selection.sch` exists it sets
  `mousex_snap = 490; mousey_snap = -340;` and calls `merge_file(1, ".sch")` —
  no `readonly` test anywhere, and it runs before any `waves_selected` routing.
  So starting a copy in any xschem window and then moving the pointer into a
  waveform viewer merges a schematic into it. Found by adversarial review of this
  change, **pre-existing and unrelated to snapping** (it writes both mirrors
  itself), left alone deliberately rather than widened into this issue.
- `wviewer::open` stamping its four per-context flags onto the wrong context is
  now refused rather than silently done (a `current_win_path` check before the
  block). The underlying "the switch no-ops ~3 times in 10 under a raised
  semaphore" hazard is unchanged; only the consequence is.

---

## 6. THE EYEBALL — the manual sequence

**Set up so the defect would be visible if it were still there.** The shipped
defaults hide it, so use the reporter's profile and make the grid impossible to
miss:

1. Launch with `src/cadence_style_rc` (the sky130A workarea already does:
   `./sky130A/run.sh`). Confirm in the CIW that `draw_crosshair` is 1 and
   `snap_cursor` is 1 — with them at 0 this whole test proves nothing.
2. Open a waveform viewer with **three or more traces on one strip** (Direct
   Plot, or `~` on a session). Three is the minimum that makes a wrong legend
   pick distinguishable from a stuck one.
3. In the CIW: `xschem set cadsnap 400`. **40x the default.** Anything still
   riding the grid will now move in visible jumps.

**A — the plot body.** Move the pointer slowly across a trace.
- SHOULD: a small **diamond** sticks to the nearest sample of the nearest trace
  and slides along it; the status bar shows `x:` / `y:` for that sample. The
  cursor is a **crosshair (`tcross`)**.
- SHOULD NOT: any second glyph; any jumping in fixed steps; the schematic
  crosshair box.
- CLICK: the trace within ~10 px goes bold. Click empty body → the selection
  clears.

**B — the legend band** (above the plot, where the trace names are). This is the
one that was reported. Sweep the pointer left-to-right **along the very top of
the names, then down through them**.
- SHOULD: **nothing at all** appears under the pointer. Cursor stays `tcross`
  across the whole band, right up to a few pixels from the window edge.
- SHOULD NOT: a small crosshair box appearing and hopping in grid steps as you
  move — that was the defect. Nor the cursor flipping between crosshair and
  arrow as you cross an invisible line ~20 px below the top of the strip.
- CLICK each of the three names, **including on the topmost pixels of the text**:
  each selects its own trace (bold stroke + bold-italic legend entry). Clicking
  the leftmost name must not select the middle one.
- REPEAT with `xschem set cadsnap 10`: **identical answers**. If any click picks
  a different trace at 400 than at 10, the fix has regressed.

**C — the axis margins** (left of the y-axis numbers, below the x-axis numbers).
- SHOULD: nothing under the pointer; cursor `tcross`.
- CLICK: nothing happens — no selection change, no bold.

**D — the reorder grip** (the three short bars at the right-hand end of the
strip band).
- SHOULD: nothing appears on hover; the bars themselves do not light up (they
  are static, not hover feedback). Cursor `tcross`.
- PRESS-DRAG: the strip reorders as before.
- CLICK without dragging: nothing changes — *except* on the top part of the grip
  column, which is also the last legend slot, where it selects the last trace.
  That overlap is pre-existing and unchanged by this issue.

**E — the very edge.** Move the pointer to within a couple of pixels of the
window's outer border.
- SHOULD: the cursor becomes the ordinary arrow (this is the 5-pixel margin that
  keeps the graph rect grabbable), and **still nothing is drawn**.
- SHOULD NOT: a crosshair, a snap diamond, or a pointer that vanishes entirely.

**F — the blast radius. Go back to a normal schematic window.**
- The grid and the crosshair must be **exactly as before**: with `cadsnap 400`
  the crosshair jumps in big steps, wires start and end on grid points, and the
  snap cursor works. If the schematic lost its grid, the property has leaked.

**G — the two free fixes** (§1.4), both easiest to see with `cadsnap 400`:
- Put the pointer near a boundary between two stacked strips and use
  **View > Zoom In** from the menu — the strip that zooms must be the one the
  pointer is on, not its neighbour.
- Put the pointer near the outer edge of the viewport and press **`a`** (add
  cursor A) — it must work, not be silently swallowed.
