# A cookbook for stable object handles

*Practical recipes that put the stable-handle and uniform-object API to work.
Every snippet here was run against a real build; the outputs shown are the real
outputs.*

This is the hands-on companion to the reference manuals
([`stable_wire_handles.md`](stable_wire_handles.md),
[`stable_instance_handles.md`](stable_instance_handles.md),
[`stable_graphical_handles.md`](stable_graphical_handles.md),
[`object_query_api.md`](object_query_api.md)). Those explain each command; this
shows what they *let you build* — things that were impossible or fragile before,
and are now a few lines of Tcl.

The two ideas you lean on throughout:

- **A handle is `{type id}`.** The `id` is a session-stable number that stays
  glued to one object across deletes, moves, sorts and undo. All seven drawable
  types carry one (a descriptor's `id` is only `-1` for a *dangling* handle).
- **The uniform descriptor.** `xschem objects` hands you one self-describing Tcl
  dict per object — `type index layer id name` — and `xschem object <type>
  <selector>` resolves a handle back to a live descriptor (or `""` if it is
  gone).

---

## 0. A tiny reusable toolkit

Three helpers carry every recipe below. Paste them once.

```tcl
# Select the object a descriptor refers to, dispatching on flat vs per-layer type.
proc select_descriptor {o} {
  set t [dict get $o type]; set i [dict get $o index]; set l [dict get $o layer]
  switch $t {
    wire - instance - text    { xschem select $t $i }
    rect - line - poly - arc   { xschem select $t $l $i }
  }
}

# Capture a list of durable {type id} handles. Pass any `objects` filter,
# e.g. `capture_handles -selected` or `capture_handles -type rect`.
proc capture_handles {args} {
  set hs {}
  foreach o [xschem objects {*}$args] {
    lappend hs [list [dict get $o type] [dict get $o id]]
  }
  return $hs
}

# Re-resolve a captured handle list and select whatever still exists.
# Returns how many of the handles were still live.
proc reselect {handles} {
  xschem unselect_all
  set live 0
  foreach h $handles {
    lassign $h type id
    set o [xschem object $type @$id]   ;# "" if it was deleted
    if {$o eq ""} continue
    select_descriptor $o
    incr live
  }
  return $live
}
```

The whole point: `capture_handles` records *identities*, not positions, so the
list stays meaningful no matter what you do to the schematic in between.

---

## 1. A durable bookmark: remember a selection across edits

**The problem.** You want to remember "these objects," run a batch of edits that
add and delete things, then get exactly those objects back. Saving array indices
fails — an earlier delete renumbers everything.

**The recipe.** Capture handles, edit freely, `reselect`.

```tcl
# remember the current selection as durable handles
set marks [capture_handles -selected]
# -> {instance 2} {rect 699}

# ... now anything happens, including a delete that shifts indices ...
xschem unselect_all; xschem select instance RA; xschem delete

# restore the bookmark by identity
reselect $marks            ;# -> 2  (both still live and now re-selected)
```

Verified: after deleting an *earlier* instance (which renumbers the array), the
restored selection is still exactly the same instance and rectangle you marked —
not their unlucky successors. If one of the marked objects had itself been
deleted, `reselect` simply skips it (the handle resolves to `""`) instead of
selecting a stranger or throwing.

> The same pattern gives you **undo-proof scratch references**: stash
> `capture_handles -selected` in a variable before a risky operation, and you can
> always point back at those objects afterward.

## 2. Diff two states by *identity*, not position

**The problem.** "What did that operation add and remove?" You cannot answer this
by comparing index lists — the indices shift, so everything looks changed.

**The recipe.** Because ids are never reused, a before/after **set difference on
ids** is exact.

```tcl
proc id_set {} {
  set s {}
  foreach o [xschem objects] { dict set s [list [dict get $o type] [dict get $o id]] 1 }
  return $s
}

set before [id_set]
# ... some operation: here, add one instance and delete another ...
set after  [id_set]

set added   {}; foreach k [dict keys $after]  { if {![dict exists $before $k]} {lappend added $k} }
set removed {}; foreach k [dict keys $before] { if {![dict exists $after $k]}  {lappend removed $k} }
```

Verified output for "add RD, delete RB":

```
added   -> {instance 7}        ;# resolve it: [dict get [xschem object instance @7] name] == RD
removed -> {instance 5}        ;# the id of the now-gone RB
```

The added ids still resolve to live descriptors; the removed ids resolve to `""`.
This is the foundation for change-tracking, audit logs, and "highlight what my
script just touched" features — none of which are expressible with indices.

## 3. Delete (or transform) while iterating — safely

**The problem.** The classic foot-gun: looping over a list by index while
deleting from it. Each delete compacts the array, so indices slide out from under
your loop and you skip or double-process objects.

**The fragile way (do not do this):**

```tcl
# BUG: deleting shifts later indices; this skips objects
for {set i 0} {$i < [xschem get rects 5]} {incr i} {
  xschem select rect 5 $i; xschem delete   ;# i now points at the wrong rect
}
```

**The recipe.** Capture the handles *first*, then act on them one at a time.
Because each handle is re-resolved at the moment you use it, it does not matter
how much the array reshuffles between actions.

```tcl
# delete every rect on layer 5 that sits at an even original index — safely
set targets {}
foreach o [xschem objects -type rect -layer 5] {
  if {[dict get $o index] % 2 == 0} { lappend targets [dict get $o id] }
}
foreach id $targets {
  set o [xschem object rect @$id]
  if {$o eq ""} continue
  xschem unselect_all; select_descriptor $o; xschem delete
}
```

Verified: starting from 3 rects, this deletes exactly the two intended ones,
leaving 1 — no skips, no surprises, regardless of the renumbering each delete
causes. The rule generalises: **decide what to act on by identity, snapshot the
handles, then act.**

## 4. Attach your own data to objects — and have it survive edits

**The problem.** You want to annotate objects from a script — notes, tags,
computed values — and have those annotations follow the objects as the user edits
the schematic, including *renaming* them.

**The recipe.** Use the stable id as the key of your own Tcl dict. The id is
independent of name and position, so your data stays attached.

```tcl
set notes {}
dict set notes [xschem instance_id RB] "needs review"

# the user renames RB -> RBETA (an in-place edit; the id is unchanged)
xschem setprop instance RB name RBETA

# look the note up by id — still there, under the new name
dict get $notes [xschem instance_id RBETA]    ;# -> "needs review"
```

Verified: the note survives the rename because it was keyed on the durable id,
not the name. (Recall the asymmetry from the manuals: a *rename* is an in-place
edit so the id survives; a graphical *layer change* rebuilds the object, so there
the id is intentionally fresh — key on the id and you find out the truth either
way.)

## 5. A uniform inventory / report in three lines

**The problem.** "What is in this schematic?" Before, you queried each type with a
different command (and some, like arcs, had no count command at all).

**The recipe.** One enumerator, one loop.

```tcl
set counts {}
foreach o [xschem objects] { dict incr counts [dict get $o type] }
puts $counts        ;# -> instance 3 rect 3
```

Grow it into a real report by reading more fields off the same descriptors:

```tcl
# every instance, by name, with its durable handle
foreach o [xschem objects -type instance] {
  puts "[dict get $o name]\tid=[dict get $o id]\tindex=[dict get $o index]"
}

# everything currently selected, uniformly (all seven types in one shape)
foreach o [xschem objects -selected] {
  puts "[dict get $o type] [dict get $o id] [dict get $o name]"
}
```

This is the surface that used to be impossible: `selected_set` omitted whole
types and there was no "list everything" at all. Now one shape covers them all.

---

## 6. Putting it together: a "guarded transform" skeleton

Most real automation is some flavour of *select a set, transform it, keep track
of what happened*. Here is a reusable skeleton that combines the recipes —
identity in, identity out, nothing lost to renumbering:

```tcl
# Run {body} once per object matching `objects $filter`, resolving each by its
# durable id at the moment of use, and return the handles that survived.
proc for_each_object {filter body} {
  set handles [capture_handles {*}$filter]    ;# snapshot identities first
  set survived {}
  foreach h $handles {
    lassign $h type id
    set o [xschem object $type @$id]           ;# re-resolve NOW
    if {$o eq ""} continue                      ;# skip anything already gone
    uplevel 1 [list set obj $o]
    uplevel 1 $body
    if {[xschem object $type @$id] ne ""} { lappend survived $h }
  }
  return $survived
}

# example: select-and-report every rect on layer 5, leaving the model free to
# change under the loop
for_each_object {-type rect -layer 5} {
  puts "rect id [dict get $obj id] at index [dict get $obj index]"
  # ... do anything here: move it, delete it, recolor it ...
}
```

The discipline in one sentence: **snapshot identities, then resolve-and-act one
at a time.** That single habit turns the entire class of "the list changed under
me" bugs into a non-event.

---

## Quick reference for the commands used here

| command | returns |
| --- | --- |
| `xschem objects [-type T] [-selected] [-layer L]` | list of `{type index layer id name}` dicts |
| `xschem object <type> @<id>` | the descriptor for that handle, or `""` |
| `xschem object <type> #<index>` / `#<layer>,<index>` | the descriptor at that position |
| `xschem object instance <name>` | the descriptor for that named instance |
| `xschem <type>_id …` / `<type>_index <id>` | the low-level per-type id ↔ position bridges |
| `xschem select <type> <index>` / `<type> <layer> <index>` | select one object |

All of these are read-only except `select`; none of them modify identity. See the
per-type manuals for the full surface, and
`doc/claude/code_analysis/introspection_probes/probe6.tcl` for a runnable tour.
