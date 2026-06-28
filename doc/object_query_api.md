# The uniform object query API — `xschem object` / `xschem objects`

*One verb to enumerate every object, one to resolve any handle, one
self-describing descriptor for all of them.*

This is the read/resolve layer that sits on top of the per-type stable handles
(`wire_id`, `instance_id`, `rect_id`, …) documented in
[`stable_wire_handles.md`](stable_wire_handles.md),
[`stable_instance_handles.md`](stable_instance_handles.md) and
[`stable_graphical_handles.md`](stable_graphical_handles.md). Those gave each
object type a durable id; this gives you **one uniform way to read and address
them all**, instead of a different command per type.

Every code block below was run against a real build (see
`doc/claude/code_analysis/introspection_probes/probe6.tcl`).

---

## 1. The descriptor

Both commands speak in one currency: a **descriptor**, a Tcl dict with five keys.

```tcl
type instance index 0 layer 1 id 470 name {R25}
```

| key | meaning |
| --- | --- |
| `type` | `wire`, `instance`, `text`, `rect`, `line`, `poly`, or `arc` |
| `index` | the object's position in its array |
| `layer` | the drawing layer — *real* for graphical types; the fixed display layer for wire/instance; the text's own layer for text |
| `id` | the session-stable handle (now present for all seven types) |
| `name` | the instance name (empty `{}` for every other type) |

Because it is a Tcl dict, you read fields by name and never depend on order:

```tcl
set o [xschem object instance R25]
dict get $o id        ;# -> 470
dict get $o index     ;# -> 0
```

`(type, index, layer)` is the object's full *address*; `id` is its durable
*handle*; `name` is its human handle (instances only). One row carries all
three — so converting between them is a field read, not a command lookup.

## 2. `xschem objects` — enumerate everything

Returns a Tcl **list of descriptors**, one per object, across all seven drawable
types:

```tcl
foreach o [xschem objects] {
    puts "[dict get $o type] #[dict get $o index] on layer [dict get $o layer], id [dict get $o id]"
}
# wire #0 on layer 1, id 1
# instance #0 on layer 1, id 1
# text #0 on layer -1, id 701
# rect #0 on layer 5, id 697
# rect #1 on layer 5, id 698
# line #0 on layer 5, id 699
# arc #0 on layer 6, id 700
```

This is the gap it closes: before, there was no way to list *all* objects
uniformly — `selection` showed only the selection, `selected_set` omitted whole
types, and counts/iteration were per-type and ad hoc.

### Filters (combinable)

```tcl
xschem objects -type rect            ;# only rectangles, across all layers
xschem objects -selected             ;# only the current selection, uniformly
xschem objects -layer 5              ;# only objects whose reported layer is 5
xschem objects -type rect -layer 5   ;# rectangles on layer 5
```

`-selected` is the uniform answer to "what is selected?" — every type, every
field, in one shape:

```tcl
xschem select instance R25
xschem select rect 5 1
xschem objects -selected
;# -> {type instance index 0 layer 1 id 1 name {R25}} {type rect index 1 layer 5 id 698 name {}}
```

## 3. `xschem object` — resolve one reference

```tcl
xschem object <type> <selector>
```

returns the single descriptor (un-wrapped), or `""` if it does not resolve. The
selector says *how* you are naming the object:

| selector | means | example |
| --- | --- | --- |
| `@<id>` | by **stable id** (the durable handle) | `xschem object instance @470` |
| `#<index>` | by **array index** (flat types) | `xschem object wire #6` |
| `#<layer>,<index>` | by **per-layer position** (graphical) | `xschem object rect #5,1` |
| `<name>` | by **name** (instances only) | `xschem object instance R25` |

All three forms resolve the same object three ways:

```tcl
xschem object instance R25       ;# -> type instance index 0 layer 1 id 2 name {R1}
xschem object instance #0        ;# -> (same)
xschem object instance @2        ;# -> (same)
```

The sigils make the reference unambiguous and dissolve a latent trap: an
instance literally *named* `5` used to be unreachable, because the older
"digits mean an index" rule shadowed it. Here a bareword is *always* a name and
`#5` is *always* an index — no collision.

### A dangling reference is loud

Hold an id, delete the object, resolve: you get an honest empty string, never a
different object that happens to sit where the old one did.

```tcl
set h [xschem rect_id 5 0]
xschem select rect 5 0; xschem delete
xschem object rect @$h      ;# -> ""   (the handle dangled — nothing returned)
```

## 4. The round trip the whole effort is for

The point of a handle is to survive edits. Grab one, edit the schematic, and
resolve it back to a live descriptor:

```tcl
set h [dict get [xschem object instance R25] id]   ;# durable handle
# ... arbitrary edits: deletes that shift indices, moves, undo ...
set o [xschem object instance @$h]                 ;# resolve it now
if {$o ne ""} { puts "still here at index [dict get $o index]" } \
else          { puts "it was deleted" }
```

`@<id>` is the reference you store in a script, a log, or a data structure when
you need to mean "*that* object" across time. `#<index>` is only ever true at
the instant you read it (an earlier delete renumbers it); `<name>` is the human
form and, for instances, the only thing that survives save/reload.

## 5. What this does *not* do (and where to look instead)

- **Geometry.** The descriptor carries identity and addressing, not coordinates.
  Use the existing per-type commands with the index/layer you got back:
  `instance_coord`, `wire_coord`, `instance_bbox`, etc.
- **Mutation.** Both commands are strictly read-only. They never select, move,
  or modify anything.
- **Cross-type id uniqueness.** Ids are unique *within* a type family (a wire
  and an instance can both be id `1`), so a reference always names its type:
  `object instance @1` and `object wire @1` are different objects. A future
  global-id scheme could drop the type, but the type-scoped form is what ships.
- **All seven types carry an id.** `text` was the last to get one; the
  enumerator and resolver are now uniform across wire/instance/text/rect/line/
  poly/arc with no straggler. (A descriptor's `id` can still be `-1` for a
  *dangling* reference, but never because a type lacks ids.)
- **Nets.** A *net* is not one of these seven types — it is derived, not stored,
  so it has no id of its own. It gets its own handle surface,
  [`net_as_object.md`](net_as_object.md) (`xschem net` / `nets` /
  `net_members`), where the durable handle is an *anchor* (a wire/instance id on
  the net) and the membership it returns is made of these same object handles —
  `object instance @<id>` resolves a `net_members` pin back to a descriptor.

---

*See also the per-type manuals (`doc/stable_*_handles.md`) for how the ids
themselves work, `doc/net_as_object.md` for the net-level handle that composes
with this API, and `doc/claude/code_analysis/step3_directions_guide.md` for where this API
fits in the larger plan.*
