# Spec — Hover fly-lines (dynamic implicit-connectivity highlighting)

Status: IMPLEMENTED (v1) 2026-07-13. Track A (headless connectivity engine, `xschem flylines`
query) and Track B (on-screen overlay, `draw_flylines()`) both shipped on branch `fluid-editing`;
soft-glow (§7.3) deferred per the B4 spike (`code_analysis/flyline_softglow_spike.md`). Design
decisions locked (§12). Built on the existing hover-highlight (`draw_hover()` in `callback.c`,
`xctx->hover_*`), net-highlight (`hilight.c`), temp-overlay (`drawtempline()` in `draw.c`) and
net-name (`prepare_netlist_structs()` in `netlist.c`) subsystems. Connectivity/clustering lives in
the new `src/flyline.c` (`flyline_compute()`), shared by the query and the overlay. Regression:
`tests/headless/test_flylines.sh` (35 rails, --nogui logic) + `test_flylines_render.tcl`
(14 rails, -x GUI overlay).

Locked decisions (v1): star topology from the hovered cluster; global/bang nets suppressed
by default (opt-in, capped at 32); bus labels aggregated per label (per-bit internally,
one visual set); membership = any equal `.node` string (xschem's own connectivity, incl.
device-pin-to-device-pin); hover-only trigger (freeze key deferred to P3); fly-lines
coexist with active net-highlight (orthogonal). Rationale and deferred alternatives in §12.

## 1. Motivation

Cadence Virtuoso offers "dynamic highlighting": hovering a pin, wire, or net-label
draws temporary **flight lines** — thin connector lines from the node under the cursor
to every *other* piece of the same net that is joined **only implicitly** (by net-label
name, pin name, or global net), with no drawn wire between them. It reveals hidden
connectivity — the labels-only connections that are easy to miss when reading a
schematic — without permanently cluttering the drawing and without running a netlist.

xschem today has no equivalent. The building blocks all exist (see §9); this feature
recombines them into a hover-driven, transient, per-net connector overlay.

## 2. Terminology

- **Node / net name** — the canonical string carried by each wire (`xWire.node`) and
  each instance pin (`xInstance.node[j]`). Connectivity in xschem *is* string equality
  of these, per bus-bit, after `prepare_netlist_structs()`.
- **Cluster** — a maximal set of geometry (wires + pins + labels) on one net that is
  mutually joined by **drawn wires / physical touch**. A net with no drawn wires between
  two labels of the same name has two clusters.
- **Implicit connection** — two clusters sharing a net name with no wire between them.
  Fly-lines visualize exactly these.
- **Anchor** — the on-screen point a fly-line terminates on for a given cluster (a pin
  coordinate, a wire endpoint/midpoint, or a label attach point).
- **Global / bang net** — a schematic-wide net (`vdd!`, `gnd!`, `0`, or any label with
  the `global=true` attribute), registered in `xctx->globals[]` via `record_global_node()`.

## 3. Behavior (what the user sees)

1. Feature gated by a config var (default **off**), e.g. `flylines` / a menu toggle.
   Independent of `hover_highlight` but rides the same motion pump.
2. On mouse-move over copper (wire), an instance pin, or a net-label, xschem resolves
   the net under the cursor and draws fly-lines from the hovered cluster to every other
   cluster of the same net. The existing dashed hover outline still marks the hovered
   object itself.
3. Fly-lines are **window-only** and transient: erased and recomputed as the cursor
   moves to a new net, cleared when the cursor leaves the canvas or lands on nothing.
4. If the net has only one cluster (no implicit connections), no fly-lines are drawn
   (optionally a subtle "isolated" cue — deferred).
5. Global nets are **suppressed by default** (see §6.2); an opt-in shows them capped.
6. Fly-lines and the persistent net-highlight are **orthogonal**: hovering draws fly-lines
   whether or not the net is currently highlighted; neither suppresses the other.
7. A "pin/freeze" key to snapshot the current fly-lines (so the mouse can move away while
   they persist) is **deferred to P3**; v1 is hover-only.

Non-goals (v1): cross-hierarchy fly-lines (single view only, matching Virtuoso's default
and xschem's one-sheet-per-view model); off-sheet-connector following; net-expression /
inherited-connection (CDF `nlAction`) tracing; soft-glow rendering (see §7.3).

## 4. Scope & correctness rules

- **Single schematic view / current hierarchy level.** Node strings are leaf/local names
  at the current level; do not descend.
- **Implicit only.** Never draw a fly-line between two anchors already joined by drawn
  wire (i.e. in the same cluster). This is the defining rule and the main new algorithm
  (§5.2).
- **Per bus-bit.** A bus label `A<3:0>` is four nets; matching must be bit-wise via the
  existing `expandlabel`/`bus_hilight_hash_lookup` path, not naive full-string `strcmp`.
- **Exclude auto-named nets.** Node strings beginning with `#` or matching the
  `get_unnamed_node()` `net#`/`#net` form are unique per cluster and can never connect
  implicitly — skip them entirely.
- **Netlist must be current.** Reading `.node` requires `prepare_netlist_structs(0)` to
  have run and not been invalidated by an edit (see §6.3).

## 5. Algorithm

### 5.1 Net resolution on hover

Hook the existing hover path (`draw_hover()`, `callback.c:2006`), which already computes
`find_closest_obj()` (`findnet.c:526`) each MotionNotify and caches `hover_type/n/col`.
Add net-name resolution modeled exactly on `hilight_net()` (`hilight.c:2378`):

- `WIRE`  → `xctx->wire[n].node`
- `ELEMENT` where symbol is a label/pin (`IS_LABEL_SH_OR_PIN`) → `xctx->inst[n].node[0]`
- Device **pin** under cursor → requires wiring `find_closest_pin()` (`findnet.c:552`,
  currently `en_pin_select`-gated) into the hover cascade → `xctx->inst[n].node[col]`,
  pin coord from `get_inst_pin_coord()` (`netlist.c:753`).

Precondition: ensure `prepare_netlist_structs(0)` (`netlist.c:1663`, idempotent via
`prep_hi_structs`) has run. Do **not** call it unconditionally on every motion (§6.3).

If the resolved name is empty, unnamed (`#…`), or unchanged since the last motion,
early-return (reuse the hover change-detection idiom, generalized from `type/n/col` to a
net-name key).

### 5.2 Cluster computation (the core new work)

Given target net name `N`, gather all geometry whose `.node` matches `N` (bit-wise), then
partition it into physical clusters:

- **Members** (decision: *any* equal `.node`): iterate wires (`wire[i].node == N`) and
  instances (`inst[i].node[j] == N` for **all** pins, not just label/pin symbols),
  mirroring `propagate_hilights()` (`hilight.c:1874`) / `draw_hilight_net()`
  (`hilight.c:3877`). This is exactly xschem's connectivity, so device-pin-to-device-pin
  implicit links are included. The Tcl `net_members` command (`scheduler.c:5522`) already
  does the exact-string version and is a reference.
- **Cluster partition**: union-find (disjoint-set) over members, unioning any two that
  physically touch. "Touch" = shared endpoint / point-on-wire, computed with the spatial
  hashes (`wire_spatial_table`, `instpin_spatial_table`) so it stays near-linear — the
  same touch test `name_attached_nets()`/`wirecheck()` (`netlist.c:1007/1064`) use to
  propagate names, and/or `select_connected_nets()`/`check_connected_nets()`
  (`select.c:93`). Note: the netlister builds these clusters internally but **discards**
  the grouping (keeps only the shared name string), so we must recompute.
- Result: a list of clusters, each with a representative **anchor** point (§5.3).

xschem has **no per-net connected-component structure today** — this partition is the
central piece the feature adds.

### 5.3 Anchor selection per cluster

For each cluster pick one anchor point for its fly-line endpoint:
- Pin/label cluster → the pin coord (`get_inst_pin_coord`) for electrical correctness
  (label name-text-bbox center is an alternative for visual aim — see
  `hover_netlabel_text.md`; pick pin coord for v1).
- Wire-bearing cluster → nearest wire endpoint to the hub, or the wire midpoint.
- The **hub** is the hovered cluster's anchor.

### 5.4 Topology

**Decision: star.** Draw one line from the hub anchor (the hovered cluster) to each other
cluster's anchor — reads clearly as "from the node under the mouse to all others". Keep the
topology behind a small internal strategy hook so a minimum-spanning-tree variant (less ink
on dense nets, but the drawn line no longer starts at the hovered node) can be swapped in
later without touching the enumeration/render code.

### 5.5 Rendering

Clone the `draw_hover()` window-only frame (`callback.c:2006`):
1. Save `draw_window`/`draw_pixmap`; set `draw_pixmap=0`, `draw_window=1`.
2. Emit segments with `drawtempline(gc_flyline, ADD, x1,y1,x2,y2)` in world coords,
   flush with `drawtempline(gc_flyline, END, …)` (`draw.c:1737`, batched `XDrawSegments`).
3. Restore flags.

Create a dedicated `gc_flyline` GC alongside `gc_hover` (`xinit.c:1244`) — its own color
(config var), width, and dash pattern (`LineOnOffDash`). Add `gc_flyline` to
`Xschem_ctx` (`xschem.h:1211` neighborhood).

### 5.6 Erase / refresh

Track the drawn segment list (or just `{net-name, endpoint list}`) in new `Xschem_ctx`
fields modeled on `hover_type/hover_n`. On the next motion (net changed) or on
`LeaveNotify`, erase before redrawing:
- Simple/robust: regional `draw()` over the fly-line union bbox (like
  `draw_hilight_region()`, `hilight.c:3026`) — repaints correctly, costs a partial redraw.
- Cheaper but fiddlier: re-stamp each segment strip from `save_pixmap` via
  `MyXCopyAreaDouble` (`draw.c:6185`), then re-stroke any other window-only overlays
  (selection, scope, crosshair, hover) inside that bbox.
Start with the regional-`draw()` approach; optimize only if motion feels heavy.

Add a re-establish call next to the `draw_hover(1)`/`draw_crosshair()` re-stamp in
`draw()` (`draw.c:6120`) so fly-lines survive pan/zoom/full-redraw.

## 6. Edge cases & policies

### 6.1 Single-cluster net
No implicit connections → draw nothing.

### 6.2 Global / bang nets
Detect via `record_global_node(3, NULL, tok)` (`netlist.c:708`). A global sits on many
pins → a full star is an O(n²) hairball. **Decision:**
- **Default: suppress** fly-lines for globals (they are understood to be everywhere) —
  `flylines_show_globals=0`.
- With `flylines_show_globals=1`: draw the nearest-K clusters to the hub up to a hard cap
  `flylines_cap` (**default 32**) and emit a `ciw_echo` notice when the count is capped
  (no silent truncation — repo discipline). The `capped` flag is also returned by the
  query API (§8).

### 6.3 Performance & staleness
- `.node` strings are `NULL`/stale until `prepare_netlist_structs(0)`; edits reset
  `prep_hi_structs`/`prep_net_structs` (`check.c:429`, `paste.c:384`,
  `in_memory_undo.c:588`, `editprop.c:1068`).
- Do **not** rebuild on every motion. Options: (a) gate the feature to only draw when the
  netlist is current, rebuilding once lazily on the first hover after an edit; (b) cache
  the cluster/anchor result keyed by resolved net name, invalidated when `prep_hi_structs`
  clears. Recompute clusters only when the hovered net name changes.
- Debounce fast motion; apply the same `flylines_cap` (default 32) to **any** net, not
  only globals, so a large ordinary net cannot flood the overlay (highlight code already
  special-cases `wires>2000 || instances>2000`). Cap by nearest-K clusters to the hub.

### 6.4 Buses
**Decision: aggregate per label (v1).** Resolve per-bit internally (`expandlabel`), gather
each bit's connections, then draw **one** endpoint-deduped visual set for the whole bus
label. A per-bit mode (separate fly-lines per bit) is a deferred option (§12).

### 6.5 Multi-window / tabs
Overlays are per-context (`save_pixmap`, `gc_*`, hover state all in `Xschem_ctx`);
background tabs share the single `.drw` canvas. Gate fly-line drawing to the
front/visible context exactly like the animation tick and the
`net_hilight_redraw_other_windows()` background-tab guard, or it will scribble onto the
wrong tab.

### 6.6 Read-only / gated sessions
Purely visual; safe in read-only. Must be a no-op in `--nogui` (no canvas) and cheap in
headless (the query API in §8 still works).

## 7. Rendering fidelity

### 7.1 v1 look
Thin dashed colored lines via `gc_flyline` — proven feasible (`gc_hover` is exactly this).
Config: color, width, dash on/off lengths.

### 7.2 Marching ants (optional, later)
Ride `net_hilight_anim_tick` (`xschem.tcl:455`) + `draw_hilight_region()` and scroll a
`dash_offset` like `draw_hilight_wire()` (`draw.c:1655`).

### 7.3 Soft-glow / translucency (deferred)
The Unix interactive line path is Xlib `XDrawLine`/`XDrawSegments` — **solid colors, no
alpha**. Cairo is used only for text/fills here; `cairo_set_source_rgba` is disabled on
the interactive line path. A Cadence-style translucent glow needs a **new Cairo overlay
surface** (`cairo_set_source_rgba` + `cairo_stroke`) that does not exist today —
significant new plumbing. Explicitly out of scope for v1.

## 8. API & testability

Add a scheduler subcommand so the connectivity logic is testable headless, independent of
rendering (repo discipline — no eyeball-only features):

- `xschem flylines at <x> <y>` — resolve the net at a point and return the computed fly-
  line set: `{net {N} clusters {…} segments {{x1 y1 x2 y2} …} global 0|1 capped 0|1}`.
- `xschem flylines net <name>` — same, given a net name directly.
- Extend `object_descriptor()` / `xschem hover` (`scheduler.c:3388`, `:5804`) to also
  surface the resolved net name (add a `net {N}` field) — small, independently useful.

Config vars (mirror C↔Tcl where the C side reads them — see `MIRRORED IN TCL` in
`xschem.h`): `flylines` (enable), `flylines_show_globals`, `flylines_cap`,
`flylines_color`, `flylines_width`, `flylines_dash`.

Regression tests (`tests/headless/`): build fixtures with (a) two same-name labels, no
wire → expect one segment; (b) label + matching pin → one segment; (c) already-wired
pair → **zero** segments (the implicit-only rule); (d) a global net → suppressed by
default, capped when enabled; (e) a bus label; (f) an unnamed `#net` → zero.
Assert on the `xschem flylines` output; sabotage-verify each rail.

## 9. Reuse map (existing code)

| Need | Symbol / location |
|---|---|
| object under cursor | `draw_hover()` `callback.c:2006`; `find_closest_obj()` `findnet.c:526` |
| pin under cursor | `find_closest_pin()` `findnet.c:552` (currently gated) |
| (type,n)→net name | `hilight_net()` `hilight.c:2378` |
| net-name string build | `prepare_netlist_structs()` `netlist.c:1663` |
| all geometry on a net | `propagate_hilights()` `hilight.c:1874`; `draw_hilight_net()` `hilight.c:3877`; `net_members` `scheduler.c:5522` |
| bus-bit match | `bus_hilight_hash_lookup()` `hilight.c:161`; `expandlabel` |
| touch test / clustering | `name_attached_nets()`/`wirecheck()` `netlist.c:1064/1007`; `select_connected_nets()` `select.c:93`; spatial tables `xschem.h:1190` |
| pin/label/wire endpoint | `get_inst_pin_coord()` `netlist.c:753`; `wire[i].x1/y1/x2/y2`; `inst.x0/y0` |
| global-net test | `record_global_node()` `netlist.c:708` |
| window-only temp line | `drawtempline()` `draw.c:1737`; frame in `draw_hover()` `callback.c:2006` |
| erase / regional repaint | `MyXCopyAreaDouble()` `draw.c:6185`; `draw_hilight_region()` `hilight.c:3026` |
| survive full redraw | re-stamp block in `draw()` `draw.c:6120` |
| dashed GC template | `gc_hover` setup `xinit.c:1244` |
| animation tick | `net_hilight_anim_tick` `xschem.tcl:455`; `redraw_hilight_region` `scheduler.c:7354` |

## 10. Files to touch

- `src/xschem.h` — `gc_flyline`, fly-line overlay state fields, config-var mirrors.
- `src/xinit.c` — create/free `gc_flyline`.
- `src/callback.c` — hover-path hook: resolve net, compute+draw fly-lines, erase-on-move,
  Leave/enter handling; wire `find_closest_pin` into the cascade.
- `src/hilight.c` (or a new `flyline.c`) — cluster computation + anchor + topology + the
  enumeration/draw pass. A new `flyline.c` keeps it isolated (add to `OBJ` + a compile
  rule in `src/Makefile`, per CLAUDE.md).
- `src/draw.c` — fly-line stroke helper; re-stamp hook in `draw()`.
- `src/scheduler.c` — `xschem flylines …` subcommand (correct first-letter dispatch fn —
  see the scheduler-letter-dispatch note); `net` field in `object_descriptor`.
- `src/xschem.tcl` — config-var defaults (`set_ne`), menu/toggle, anim tick if used.
- `tests/headless/` — new regression script + fixtures.
- `doc/claude/specs/hover_flylines.md` — this file.

## 11. Phasing

Delivered as two tracks (see `suggestions/flyline_implementation_plan.md`); v1 status noted inline.

- **P0 spike** — `gc_flyline`; hover hook; net resolve; `xschem flylines at` query; draw a
  star to *all* same-net endpoints (no clustering yet), gated + netlist-current. Get
  pixels + a headless query on screen. **[DONE]**
- **P1 clustering (core)** — union-find physical clusters; draw only between distinct
  clusters; exclude unnamed. This is the correctness meat. **[DONE — `flyline.c` union-find]**
- **P2 globals + perf** — global detection + suppress/cap; result caching + invalidation;
  motion debounce; big-net cap. **[DONE — globals suppress/cap; net-name change-detection +
  prep_hi_structs invalidation as the cache (§5.4); `flylines_cap`. Motion debounce not needed
  in practice — same-net motion is already O(1).]**
- **P3 polish** — pin hover-pick; bus policy; multi-tab gating; freeze key; optional
  marching-ants; (Cairo soft-glow only if later wanted). **[PARTIAL — bus aggregate-per-label
  DONE (A7); soft-glow assessed + deferred (B4). Freeze key, marching-ants, explicit multi-tab
  gating remain OPEN for a later pass.]**

### v1 build (Track A logic + Track B render), what shipped
- **Track A (headless):** `xschem flylines net <name> | at <x> <y>` returns
  `{net global capped members clusters segments}`; C1 read-only invariant locked. 35 rails.
- **Track B (render):** `draw_flylines()` strokes the star on hover through `gc_flyline`
  (dashed placeholder, C2), erases on net-change/`<Leave>`, survives pan/zoom via
  `flyline_restamp()` + retained `xctx->fly_seg`; Options-menu toggle `flylines`. 14 GUI rails.
- **Deferred:** soft-glow (B4, `code_analysis/flyline_softglow_spike.md`), freeze/pin snapshot,
  marching-ants, cross-hierarchy, explicit background-tab gating.

## 12. Resolved decisions & deferred alternatives

Decisions locked 2026-07-13 (see §3–§6 for where each is applied):

| # | Question | Decision (v1) | Deferred alternative |
|---|---|---|---|
| 1 | Cluster topology | **Star** from hovered cluster to each other cluster | MST over cluster anchors (less ink; hub not central) — behind a strategy hook |
| 2 | Global/bang nets | **Suppress by default**; opt-in `flylines_show_globals`, nearest-K capped at `flylines_cap`=32, capped-notice | Always-show, or per-net override |
| 3 | Buses | **Aggregate per label**, one deduped set | Per-bit mode (separate fly-lines per bit) |
| 4 | Membership | **Any equal `.node`** (all wires/pins/labels; incl. device-pin↔device-pin) — xschem's own connectivity | Restrict to labels/ports/globals |
| 5 | Trigger | **Hover-only** | Click-to-freeze / pin snapshot → P3 |
| 6 | Vs active highlight | **Coexist** (orthogonal; both draw) | — |

Still genuinely open (do not block P0/P1; decide when reached):
- Exact anchor for a wire-bearing cluster: nearest endpoint to hub vs wire midpoint (§5.3).
- Label anchor: pin coord (electrical, v1 default) vs name-text-bbox center (visual aim).
- Whether the "isolated net" cue (§3.4) is worth drawing at all.
- Debounce interval / redraw strategy tuning (regional `draw()` vs strip re-stamp, §5.6).

## 13. Risk summary

No architectural blocker — connectivity, hover, enumeration, and overlay primitives all
exist and are individually proven. Real risk concentrates in: (1) **per-net physical
clustering** (new algorithm, must be correct or lines duplicate wired connections),
(2) **global-net blow-up** (policy + cap), (3) **hover-rate performance** (caching +
staleness), (4) **whole-canvas overlay erase** (regional repaint ordering). Soft-glow is
the only genuinely new plumbing and is deferred.
