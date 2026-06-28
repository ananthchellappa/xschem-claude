# Stable graphical-object handles — a user & developer manual

*How to hold on to a rectangle, line, polygon or arc across edits, why the
`(layer, index)` you'd naturally use is fragile, and how the id was built.*

This manual covers the `xschem rect_id` / `rect_index` family added on the
`feature/stable-object-handles` branch (step 3). It is a focused **sibling** of
[`stable_wire_handles.md`](stable_wire_handles.md) and
[`stable_instance_handles.md`](stable_instance_handles.md): the mechanics (the
linear-scan resolver, the disk-vs-memory-undo contract, the `selection` row
format) are identical and explained in full there. This document covers what is
*different* about the graphical types — they live in **per-layer** arrays, and
they have no name, so the numeric id is the only handle.

Everything in the code blocks below was run against a real build (see
`doc/claude/code_analysis/introspection_probes/probe5.tcl`).

---

## 1. The per-layer addressing problem

rect/line/poly/arc are not stored in one flat array like wires or instances.
Each lives in a **per-layer** array — one sub-array per drawing color/layer:

```tcl
xschem set rectcolor 5        ;# the "current layer" new shapes land on
xschem rect 0 0 100 100       ;# rect 0 on layer 5
xschem rect 200 0 300 100     ;# rect 1 on layer 5
xschem get rects 5            ;# -> 2   (count is PER LAYER — note the "5")
```

So a graphical object is addressed by the **pair `(layer, index)`**, e.g. "rect
1 on layer 5". And that pair is fragile in exactly the §2e way: delete an
earlier rect on the same layer and every later index shifts down, so a held
`(layer, index)` silently names a different rect — with no name to fall back on.

```tcl
xschem rect_id 5 1            ;# -> 706   (a witness id for "rect 1, right now")
xschem unselect_all; xschem select rect 5 0; xschem delete
xschem rect_id 5 1            ;# -> a DIFFERENT rect (the old rect 1 is now rect 0)
```

## 2. The handle: `<type>_id` and `<type>_index`

| Command | You give it | You get back |
| --- | --- | --- |
| `xschem <type>_id <layer> <index>` | a layer and a per-layer index | that object's stable **id** (or `-1` if out of range) |
| `xschem <type>_index <id>` | a stable **id** | its current location as **`{layer index}`** (or `-1` if gone) |

for `<type>` in `rect`, `line`, `poly`, `arc`. The reverse command returns a
**`{layer index}` pair**, not a bare index, because the object could be on any
layer:

```tcl
set h [xschem rect_id 5 3]      ;# durable handle to "the 4th rect on layer 5"
# ... delete an earlier rect on layer 5; indices shift ...
set loc [xschem rect_index $h]  ;# -> {5 2}   (moved from index 3 to index 2)
xschem rect_id [lindex $loc 0] [lindex $loc 1]   ;# -> $h again: same rect
```

A deleted (or never-existent) id returns a bare `-1` — loud and checkable, never
a wrong-but-plausible location. Both commands are read-only.

### One shared id space across the four types

There is a single id counter for all graphical objects, so a rect and a line
**never collide** on id value, and each type's resolver refuses the others' ids:

```tcl
xschem rect_id 5 0   ;# -> 705
xschem line_id 5 0   ;# -> 706   (distinct — shared counter)
xschem rect_index 706   ;# -> -1   (706 is a line's id; rect_index is type-scoped)
```

### Ids in `xschem selection`

The selection enumerator returns one `{type index col id}` row per object; for
graphical types `col` **is the layer**, and the id slot (which used to be `-1`)
now carries the real id:

```tcl
xschem select rect 5 0
xschem selection            ;# -> {rect 0 5 705}
#                                       │ │ └ stable id (== rect_id 5 0)
#                                       │ └ col == layer 5
#                                       └ per-layer index
```

## 3. The behaviors worth knowing

| Operation | what happens to the id |
| --- | --- |
| neighbour on the same layer deleted | survives; `<type>_index` tracks the new `{layer index}` |
| **the object itself deleted** | dangles `-1` (loud) |
| **create → delete → create** | fresh id (never reused) |
| **change the object's layer** | **does NOT survive** — see below |
| memory undo (delete→undo) | round-trips: the same id resolves again |
| disk undo restore | invalidated: fresh id, old id dangles `-1` |
| save / close / reopen | gone (ids are session-only, not in the `.sch`) |

> **Changing an object's layer mints a fresh id.** `xschem set rectcolor <c>`
> with a selection runs `change_layer()`, which is implemented as
> **delete + recreate** on the new layer. So a layer change reconstructs the
> object: the old id dangles and the rect on the new layer carries a new id.
> Hold an id only within a *layer-stable* lifetime; re-fetch after a layer
> change. (This differs from the instance "id survives rename" because a rename
> edits in place, while a layer change rebuilds the object.)

```tcl
set h [xschem rect_id 5 0]
xschem select rect 5 0; xschem set rectcolor 7   ;# move it to layer 7
xschem rect_index $h        ;# -> -1   (the old id dangles; it was reconstructed)
xschem rect_id 7 0          ;# -> a fresh id
```

## 4. Graphical create is not undoable (a related gotcha)

Programmatic `xschem rect/line/polygon/arc` does **not** push an undo record
(unlike `xschem instance`). So a create cannot be undone, but a delete can — the
undoable round-trip is delete→undo, which is why the memory-undo example above
deletes first. (The GUI's mouse-drawn shapes push undo at gesture end; only the
scripted create skips it.)

## 5. How it was built (one switch, because of the funnel)

Graphical objects are born three ways (store factories, paste/merge, file load)
× four types = 12 sites. Step-3 Phase C funneled all twelve through one
chokepoint, `gfx_register(type, c, n)` in `src/store.c`; Phase D made it stamp:

```c
void gfx_register(int type, int c, int n)
{
 switch(type) {
   case xRECT:   xctx->rect[c][n].id = ++xctx->gfx_id_counter; xctx->rects[c]++;    break;
   case LINE:    xctx->line[c][n].id = ++xctx->gfx_id_counter; xctx->lines[c]++;    break;
   case POLYGON: xctx->poly[c][n].id = ++xctx->gfx_id_counter; xctx->polygons[c]++; break;
   case ARC:     xctx->arc[c][n].id  = ++xctx->gfx_id_counter; xctx->arcs[c]++;     break;
 }
}
```

`gfx_index_from_id()` resolves an id back to `{layer index}` by a linear scan
over **all layers** of the type — deliberately not a maintained map, for the
same reason as wires/instances: the id rides inside the struct, so the array is
the authoritative relation under every compaction/insert/swap/undo with no cache
to go stale. The wire manual §8.3 explains this at length.

---

*See also: [`stable_wire_handles.md`](stable_wire_handles.md) (shared mechanics,
full developer walkthrough) and
[`stable_instance_handles.md`](stable_instance_handles.md) (the id-vs-name
story);
[`claude/code_analysis/graphical_lifecycle_census.md`](claude/code_analysis/graphical_lifecycle_census.md)
for the lifecycle map and the layer-change design call.*
