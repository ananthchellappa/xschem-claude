# Code analysis — data-structure fit for hover fly-lines

Status: 2026-07-13. Companion to `doc/claude/specs/hover_flylines.md` (feature spec) and
`doc/claude/suggestions/flyline_implementation_plan.md` (RED-first plan). Grounded in the
actual struct definitions in `xschem.h` and the connectivity code in `netlist.c`,
`hilight.c`, `select.c`, `node_hash.c`.

## 0. Verdict

Fly-lines are a **moderate, additive** build. The one architectural fact that shapes
everything: **xschem has no first-class "net" object and no persisted connectivity graph.**
A net is a *name string* scattered across per-object fields, plus two name-keyed hash
tables that hold electrical/highlight metadata but **no geometry**. This makes the two
things fly-lines need — *reverse lookup* (name → all its geometry) and *clustering* (which
pieces are physically wired vs only name-connected) — the only friction points. Both are
solvable **without changing any existing struct**; the work is new read-only passes plus a
small amount of transient overlay state. No invasive refactor is required. One optional
data-structure upgrade (a name→objects reverse index) would help fly-lines *and* several
existing operations, and is the only change worth considering beyond the minimum.

## 1. The current net data model (three decoupled layers)

**Layer 1 — connectivity as per-object name strings (the source of truth).**
- `xWire.node` (`char*`, `xschem.h:506`): a wire's net name. `xWire` also has stable `.id`,
  endpoints, `.sel` — but **no cluster/component field**.
- `xInstance.node` (`char**`, `xschem.h:724`): per-pin net names; `.lab` is the label/pin's
  raw name attribute.
- Two pieces are "the same net" **iff their `.node` strings are byte-equal** (per bus bit).
- These are `NULL` until `prepare_netlist_structs(0)` (`netlist.c:1663`) rebuilds them, and
  are invalidated (`prep_hi_structs`/`prep_net_structs` reset) on **every edit**
  (`check.c:429`, `paste.c:384`, `in_memory_undo.c:588`, `editprop.c:1068`).

**Layer 2 — name-keyed metadata hashes (no geometry).**
- `node_hashentry` (`xschem.h:875`): `token` + `Drivers` counts + sig/verilog types. A net
  *registry* — proves a name exists and its electrical role. No pointer to any wire/pin.
- `hilight_hashentry` (`xschem.h:890`): `token` + hierarchy `path` + `value` (highlight
  style index or sim level) + `seq`. Membership here = "this net is highlighted".
- Both are keyed by name; **neither maps a name back to the objects on it.**

**Layer 3 — derived per-object draw state (transient, recomputed).**
- `xInstance.color` (`xschem.h:701`, `-10000` = none) and `.buried_hilight` are *derived*
  from `hilight_table` by `propagate_hilights()` (`hilight.c:1874`) and are read-only at
  draw time. This is the existing precedent for "transient, name-keyed, recomputed overlay
  state" — but it is wired into *wire/symbol coloring*, which fly-lines must not touch (see
  §3, constraint C1).

**Spatial acceleration (already present).**
- `wire_spatial_table` / `inst_spatial_table` / `instpin_spatial_table` `[NBOXES][NBOXES]`
  (`xschem.h:1190`), entries `Wireentry{n}`, `Instentry{n}`, `Instpinentry{x0,y0,n,pin}`.
  Built by `hash_wires()`/`hash_instances()`/`hash_inst_pin()`. This is what makes
  touch-based propagation and clustering near-linear.
- A general `Int_hashtable` utility exists (`int_hash_init`/`int_hash_lookup`/
  `int_hash_free`, `xschem.h:2134`) — usable for a scratch visited-set or a reverse index.

## 2. What this model makes EASY vs HARD for fly-lines

**Easy (already solved):**
- *Object under cursor*: `draw_hover()` (`callback.c:2006`) → `find_closest_obj()`
  (`findnet.c:526`) every MotionNotify, cached in `hover_type/n/col`.
- *(type,n) → net name*: the switch in `hilight_net()` (`hilight.c:2378`).
- *Membership test*: string equality of `.node`; bus-aware via `bus_hilight_hash_lookup`.
- *Endpoints*: `get_inst_pin_coord()` (`netlist.c:753`); wire `x1/y1/x2/y2`.
- *Window-only overlay stroke*: `drawtempline()` (`draw.c:1737`), batched `XDrawSegments`.

**Hard (the two friction points):**

**(H1) Reverse lookup is a full scan.** There is no name→geometry index, so "all pieces of
net N" is an **O(W + I·P)** loop over every wire and every instance pin. Every existing
consumer pays this: `draw_hilight_net()` (`hilight.c:3877`), `propagate_hilights()`
(`hilight.c:1874`), the Tcl `net_members` command (`scheduler.c:5522`). At *hover rate*
(every mouse motion) this is the main performance risk (§4).

**(H2) No connected-component structure.** `prepare_netlist_structs()` builds physical
clusters transiently while propagating names (`name_attached_nets`/`wirecheck`,
`netlist.c:1064/1007`) then **discards the grouping**, keeping only the collapsed name.
So nothing records *which pieces of net N are joined by drawn wire vs only by name* — which
is exactly the distinction fly-lines draw. A flood router exists —
`select_connected_nets()`/`check_connected_nets()` (`select.c:93/30`) grows a physical
cluster via the spatial hash + `touch()` — **but it marks the `xWire.sel`/`xInstance.sel`
field**, i.e. it mutates selection state. Fly-lines need the same flood **non-destructively**.

## 3. Constraints from v1 scope

- **C1 — no wire-appearance change.** Fly-lines are a pure read-only overlay: they must not
  write `hilight_table`, must not set `xInstance.color`, must not touch `.sel`, must not
  mark the schematic modified, must not alter saved bytes. This *rules out* reusing the
  highlight machinery (Layer 3) as the carrier, and rules out `select_connected_nets()`
  as-is (it sets `.sel`). Fly-lines get their **own** transient overlay state.
- **C2 — placeholder rendering.** Dashed colored lines (a `gc_flyline` GC modeled on
  `gc_hover`) are proven-cheap; soft-glow needs a new Cairo alpha overlay surface the
  interactive Xlib line path does not have — deferred.

## 4. Ease-of-implementation assessment

Additive, no struct edits required for the minimum:
- Membership + endpoints + resolution + stroke: **reuse** (all listed in §2 Easy).
- Clustering: **new read-only pass** (§5.1) — reuses the `touch()` + spatial-hash idiom of
  `check_connected_nets`, swapping the `.sel` marker for a scratch `Int_hashtable` visited
  set so nothing is mutated (satisfies C1).
- Overlay carrier: **new transient `Xschem_ctx` fields** (§5.3), not `hilight_table`.
- Perf: since `.node` is stable within one `prep_hi_structs` epoch, **cache** the last
  hovered net's cluster/segment result and invalidate when the prep flag clears (§5.4).
  This sidesteps H1 for the hover case without building a full index.

Net: no consumer of the existing structs has to change; fly-lines sit *beside* the model.

## 5. Suggested data-structure changes, graded

### 5.1 [NEEDED — small] Non-destructive connected-component pass
A new routine (in a new `flyline.c`) that, given a member list for net N, returns a
`cluster_id` per member using a scratch `Int_hashtable` (or a temporary `int*` keyed by
`xWire.id`/`(inst,pin)`) as the visited marker — **never** `.sel`. Body is the `touch()` +
`wire_spatial_table`/`instpin_spatial_table` walk copied from `check_connected_nets`.
Cost: ~1 function. Blast radius: none (reads existing structs + spatial hash). Directly
resolves H2 under C1.

### 5.2 [OPTIONAL — medium, broadly useful] name → objects reverse index
Add a per-net member list so name→geometry is O(members), not O(all geometry). Two shapes:
- extend `node_hashentry` with a head pointer to a small `(type,n,pin)` member list, or
- a separate `Objectentry`-list table (`Objectentry` already exists, `xschem.h:987`) keyed
  by net name, built once per `prepare_netlist_structs` and invalidated with the prep flag.

This is the **only change worth considering beyond the minimum**, because it also speeds
`draw_hilight_net`, `propagate_hilights`, and `net_members` (all currently H1 full scans).
Cost: build-time population + memory ~O(pins); maintenance is free (rebuilt with the prep
epoch, like the spatial hashes). Recommended as a *general* engine improvement, **not**
required for fly-lines v1 (the §5.4 cache covers hover). Sequence it after the feature
proves out, or do it first if you want the whole net subsystem faster.

### 5.3 [NEEDED — tiny] Transient fly-line overlay state
New `Xschem_ctx` fields modeled on `hover_type/hover_n`: the currently-shown net name, its
segment list (or just endpoints), and a union bbox for erase. Plus a `gc_flyline` GC beside
`gc_hover` (`xinit.c:1244`). Keeps fly-lines off `hilight_table`/`.color` (C1).

### 5.4 [NEEDED — small] Result cache keyed by net name + prep epoch
Cache the last resolved net's clusters/segments; reuse while the hovered net name is
unchanged; drop when `prep_hi_structs` clears (edit) or the net changes. Turns repeated
same-net motion events into O(1). This is what makes hover-rate viable without §5.2.

### 5.5 [NICE — tiny refactor] Extract `object_net_name(type,n,col)`
The (type,n)→net-name switch is inlined in `hilight_net()`; fly-lines, hover, and
`net_members` all want it. Extract one helper. Low risk, removes duplication.

### 5.6 [AVOID] Persistent cluster ids
A durable per-cluster id sounds tempting but clusters change on *every* wire edit
(move/trim/merge/split); maintaining stable ids would add cost to the whole editing
pipeline for a transient visualization. Compute on demand + cache (§5.1 + §5.4) instead.

## 6. Recommendation

- **v1 (minimum, additive):** §5.1 (non-destructive clustering) + §5.3 (overlay state) +
  §5.4 (cache) + §5.5 (small resolver extract). No existing struct changes. Satisfies C1/C2.
- **Optional engine upgrade:** §5.2 (reverse index) — do it if/when the broader net
  subsystem's full-scan cost matters; it is the one change that pays back beyond fly-lines.
- **Do not:** reuse `hilight_table`/`.color`/`.sel` as carriers (breaks C1); add persistent
  cluster ids (§5.6).

The connectivity, hover, enumeration, and overlay primitives already exist and are proven;
the model's name-centricity means the entire feature is *new read-only passes beside the
existing structs*, not a rework of them.
