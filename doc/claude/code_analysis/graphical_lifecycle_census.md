# Graphical-object lifecycle census — every site that mutates rect/line/poly/arc storage

Phase B deliverable of the stable-object-handles **step 3 (graphical types)**
work, the analog of `wire_lifecycle_census.md` and
`instance_lifecycle_census.md`. This table is **authoritative** for the
graphical funnel: every site below gets funneled; any site discovered later is
a census bug fixed by funneling it, never by special-casing.

The four graphical types live in **per-layer** arrays — one sub-array per
drawing color/layer (`cadlayers` of them):

```
xctx->rect[layer][index]   count xctx->rects[layer]      type xRect   (save record "B")
xctx->line[layer][index]   count xctx->lines[layer]      type xLine   (save record "L")
xctx->poly[layer][index]   count xctx->polygons[layer]   type xPoly   (save record "P")
xctx->arc [layer][index]   count xctx->arcs[layer]       type xArc    (save record "A")
```

So an object is addressed by the **pair (layer, index)**, which is what
`xschem selection` returns as `{type index col id}` with `col == layer`. This is
the headline difference from wires and instances (flat arrays, single index).

> **xSymbol parallel arrays are OUT OF SCOPE.** Each `xSymbol` carries its *own*
> `rect[]/line[]/poly[]/arc[]` for the symbol's internal geometry
> (e.g. `actions.c:2061` copies `dest_sym->poly`). Those are symbol-definition
> data, a separate type with its own lifecycle (a later step). This census is
> only the *schematic's* `xctx->{rect,line,poly,arc}`.

## Method and acceptance criterion

Two independent sweeps over `src/*.c`, each hit read in context:

1. count mutations:
   `grep -nE '(rects|lines|polygons|arcs)\[[^]]*\] *(\+\+|--|\+=|-=|=[^=])'`
   (filtering the `->rects[PINLAYER]` symbol-pin reads and the netlist-local uses);
2. whole-element array writes:
   `grep -nE '(rect|line|poly|arc)\[[a-z]+\]\[[^]]*\] *= *xctx->(rect|line|poly|arc)\['`
   plus `memmove/memcpy/qsort` over these arrays.

**Acceptance: every hit of both sweeps appears in exactly one row below.**
Verified against the greps on 2026-06-13 at `1835afe8`.

## BIRTH — 3 doors × 4 types = 12 sites (no `check.c` births, like instances)

| # | site | function | notes |
| --- | --- | --- | --- |
| GB1 | `store.c:324` rects++, `:263` lines++, `:223` polygons++, `:171` arcs++ | `storeobject()` (rect+line), `store_poly()`, `store_arc()` | **the interactive/programmatic factories**: `check_*_storage()` grows the array, struct initialised from args + prop tokens, count bumped. Reached by `xschem rect/line/polygon/arc …`, GUI placement. The `pos>=0` leg is GR1 (insert-shift) |
| GB2 | `paste.c:131` rects++, `:271` lines++, `:235` polygons++, `:175` arcs++ | `merge_rect/line/poly/arc()` | **the paste/merge door**: reads an object from a clipboard/merge stream straight into the array (bypasses the store factories, exactly like `merge_inst`). Reached by `xschem copy` + `xschem paste` (GC13) |
| GB3 | `save.c:3066` rects++, `:3102` lines++, `:2960` polygons++, `:3004` arcs++ | `load_rect/line/polygon/arc()` | **the file-load door**: one per record parsed from a `.sch`. Reached by every `xschem load` / reload, and by disk-undo restore |

All three doors end in `xctx->{type}s[c]++` after filling slot
`n == xctx->{type}s[c]` (append) — the chokepoint Phase D stamps.

## DEATH — 2 doors (one selected, one degenerate), per-layer compaction

| # | site | function | notes |
| --- | --- | --- | --- |
| GD1 | `select.c:399-488` (`rects[c]-=j` 418, `lines` 434, `arcs` 458, `polygons` 487; shifts 415/431/455/484) | `delete_objects()` | **the main death door**: a `for(c=0;c<cadlayers)` loop, four order-preserving compactions (predicate = `sel==SELECTED`), frees prop_ptr/poly arrays/rect extraptr. Reached by `xschem delete` (GC3/GC5) |
| GD2 | `move.c:133-180` (`lines[c]-=j` 159, `rects[c]-=j` 179; shifts 156/176) | `check_collapsing_objects()` | **the degenerate-cleanup door**: same per-layer compaction idiom, predicate = zero-length line / zero-area rect; **lines and rects only**. Called after move/copy (`move.c:985,1564`) and load (`save.c:3707`). Not isolated-reachable from Tcl (Phase A honest gap) |

Both are order-preserving per-layer shifts — an id→index update on delete is a
decrement walk, not a rebuild (same as the wire/instance death doors).

## REORDER — 2 idioms (both keep ids inside the struct ⇒ no funnel needed)

| # | site | function | notes |
| --- | --- | --- | --- |
| GR1 | `store.c:274` rect, `:241` line (`arr[c][j]=arr[c][j-1]` for `j>pos`) | inside `storeobject()` when `pos>=0` | **positional-insert shift** — Tcl-REACHABLE for rect/line (`xschem rect … <pos>`, GC9), unlike the instance IR1 which was unreachable. The new element is born at `pos`; later elements shift up *carrying their ids*. arc/poly have no `pos` leg from Tcl |
| GR2 | `editprop.c:1104-1117` (rect leg; also wire/inst/text/line/poly/arc legs) | `change_elem_order()` | **within-layer swap** (z-order raise/lower): `tmp=arr[new]; arr[new]=arr[sel]; arr[sel]=tmp`. Ids ride inside the swapped structs (GC8) |

Neither needs a funnel: the linear-scan resolver makes *ids-travel-in-struct*
authoritative under every shift/swap, exactly as for wires and instances.

## BULK_RESET — 1 site

| # | site | function | notes |
| --- | --- | --- | --- |
| GZ1 | `actions.c:1096-1099` (`lines[i]=arcs[i]=rects[i]=polygons[i]=0`) | `clear_drawing()` | per-layer zeroing of all four counts; frees handled by the surrounding clear. Reached by `xschem clear` (GC10) |

## UNDO — both backends, no count-funnel needed

| # | site | function | notes |
| --- | --- | --- | --- |
| GU1 | `in_memory_undo.c` push (`:334-336` poly deep-copy) / pop (`:446-471` `max=count=uslot`, `:481-483` poly deep-copy) | `mem_push_undo` / `mem_pop_undo` | memory undo copies whole structs both ways; an `id` scalar rides free. Poly's heap arrays (`x/y/selected_point`) are deep-copied separately, but `id` is a struct scalar — copied by the struct assignment. Same as wires/instances |
| GU2 | (disk) `load_*` via GB3 | `pop_undo` disk path | disk undo restores by re-reading the `.sch` through GB3 ⇒ fresh ids on every disk-undo restore. **Invalidate-on-restore**, the settled wire/instance D3 behavior |

The `in_memory_undo.c:34-76` `uslot[].{type}s[c]=0` writes are undo-slot
bookkeeping (clearing the snapshot buffer), not main-array mutations — listed
for completeness, no funnel.

## GROWTH (realloc) — no count change, ids ride

`check_box_storage` / `check_line_storage` / `check_polygon_storage` /
`check_arc_storage` (`store.c`) realloc the per-layer arrays when full; they do
not change counts or order, so an `id` field rides untouched. Called from inside
the birth doors.

## Funnel plan (Phase C)

Mirror the instance funnel. Because births are heterogeneous (store/merge/load
init fields differently) there is **no single factory**; route every count
increment through a register chokepoint, and the uniform death/bulk idioms
through helpers:

| funnel piece | absorbs | shape |
| --- | --- | --- |
| `gfx_register(type, c, n)` | GB1, GB2, GB3 (all 12 `{type}s[c]++`) | the birth chokepoint; Phase D stamps `xctx->{type}[c][n].id` here |
| `gfx_delete_compact(predicate)` *(or keep per-type, decide in C)* | GD1, GD2 | the per-layer order-preserving compaction; predicate selects which |
| `gfx_storage_reset()` | GZ1 | per-layer zeroing |
| unchanged | GR1, GR2, GU1, GU2, growth | ids ride in the struct ⇒ linear-scan resolver is authoritative |

## Phase C + D — DONE (2026-06-13)

The funnel paid off as planned. **Phase C** (`7835a328`) routed all 12 birth
increments through `gfx_register(type, c, n)`. **Phase D** (`d7e62d25` RED,
`6a0d3a56` GREEN) stamped identity in that one chokepoint:
`xctx->{type}[c][n].id = ++xctx->gfx_id_counter` (one shared counter, init 0 in
`alloc_xschem_data`), added `gfx_index_from_id(type, id, &layer)` (linear scan
over all layers, returns the per-layer index), eight scheduler commands
(`<type>_id <layer> <index>` / `<type>_index <id>` for rect/line/poly/arc,
placed in the matching letter-dispatch functions), and filled the `id` slot of
the selection row for all four types. Tests `tests/stable_handles/gfx_*.tcl`
(GH1–GH11, 54 checks); probe `doc/claude/code_analysis/introspection_probes/probe5.tcl`.

**The design call (id vs. layer change) — settled to implementation reality.**
The strategy/guide *recommended* "id survives a layer change", but `change_layer()`
(`actions.c:3349`, triggered by `xschem set rectcolor` on a selection) is
implemented as **delete + recreate** (`storeobject(-1,…)` on the new layer, then
`delete_only_rect_line_arc_poly()`). So the id does **not** survive a layer
change: the reconstructed object is a fresh birth with a fresh id, and the old
id dangles. Making it survive would mean rewriting `change_layer` to carry the
id through the reconstruction — a behavior change, not an additive one. The
honest, additive semantic is "reconstruction ⇒ new identity" (like a disk-undo
restore), characterized by GH6. The resolver still scans **all** layers because
an object can be born on any layer.

## Facts banked for Phase D (identity)

- **One shared `gfx_id_counter`** (per context, beside `wire_id_counter` /
  `inst_id_counter`) for all four types: a graphical object's id is unique
  *among all graphical objects*, so the `selection` row and a future uniform
  API never see a rect and a line collide on id value. Resolver commands stay
  per-type (`rect_index` scans rects, etc.).
- **The id survives a layer change** (the design call, guide §2.4): a shape
  changing color *moves between sub-arrays*, which the funnel treats as a
  move, not a birth+death — so the resolver must scan **all layers** and return
  the pair `{layer index}` (not a bare index). Mirrors "id survives rename" for
  instances.
- **Memory undo round-trips ids for free** (GU1); **disk undo invalidates**
  (GU2) — same D3 contract as wires/instances, no new decision.
- **The positional-insert reorder (GR1) is Tcl-reachable** for rect/line — a
  reorder the instance suite could not reach. The linear-scan resolver covers
  it: the shifted elements carry their ids, only the inserted element is a
  birth through `gfx_register`.
- **Two death doors** (GD1 selected, GD2 degenerate) vs one for instances —
  both funnel through the same compaction helper, so GD2 (the Tcl-unreachable
  degenerate cleanup) is covered structurally even though Phase A can't drive
  it in isolation.
- **No name** on any graphical type (unlike instances) — so unlike the instance
  Phase D, there is no id-vs-name decision: the numeric id is the *only* handle,
  exactly as it was for wires. The choice is settled by consistency.
