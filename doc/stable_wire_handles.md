# Stable wire handles — a user & developer manual

*How to hold on to a wire across edits, why you couldn't before, and how it
was built.*

This manual covers the `xschem wire_id` / `xschem wire_index` commands added
on the `feature/stable-object-handles` branch (step 1 of the stable-object
identity work). It is written for two readers at once:

- the **xschem user / script author** who wants to write Tcl that survives
  contact with a changing schematic, and
- the **curious programmer** who wants to understand how object identity was
  retrofitted onto a 25-year-old C data model without rewriting it.

You can read just the odd-numbered sections for the first role, or the whole
thing for the second. Everything in the code blocks below has been run against
`xschem_library/examples/mos_power_ampli.sch` (91 wires) and the outputs are
the real outputs.

---

## 1. The problem: a wire had no name you could keep

Open a schematic and ask xschem about its wires. The only way to refer to a
wire is by its **position in an array** — wire 0, wire 1, … wire 90. That
position is called the wire's *index*. Almost every wire command takes one:

```tcl
xschem wire_coord 5        ;# -> 1110 -680 1110 -660   (the 6th wire's endpoints)
xschem getprop wire 5 lab  ;# -> OUTI                  (its net label)
xschem select wire 5       ;# select it
```

The trouble is that an index is only a *position*, and positions move. When
you delete a wire, xschem **compacts** the array — every wire after the hole
slides down one slot to fill it. So an index you wrote down a moment ago can
silently come to mean a completely different wire:

```tcl
xschem wire_coord 6        ;# -> 1110 -600 1110 -560
xschem select wire 5 ; xschem delete
xschem wire_coord 6        ;# -> 180 -1110 180 -1070   <-- a DIFFERENT wire!
```

Nothing errored. Index 6 used to name one wire; after the delete it names its
neighbor, because everything shifted down. A script that held the number `6`
across that delete is now operating on the wrong object and has no way to know
it. Connectivity operations (`trim_wires`, `break_wires`,
`rebuild_connectivity`) are worse: they *split and merge* segments, so indices
churn even when you didn't touch the wire you cared about.

This is the single biggest obstacle to writing real automation against xschem:
**there was nothing a script could hold on to.** (This was documented as
defect #7 in `code_analysis/tcl_introspection_wire.md` §2e — the analysis that
motivated this whole effort.)

---

## 2. The fix in one sentence

Every wire now carries a **session-stable id** — a number stamped on it when
it is created, never reused, that follows the wire around no matter how the
array is reshuffled. Two new commands let you read and resolve it:

| Command | Takes | Returns |
| --- | --- | --- |
| `xschem wire_id <index>` | a current array **index** | that wire's stable **id** (or `-1` if the index is out of range) |
| `xschem wire_index <id>` | a stable **id** | the wire's **current index** (or `-1` if no live wire has that id) |

The workflow is: **use an index to grab a handle once, then hold the id.**

```tcl
set h [xschem wire_id 6]    ;# grab a durable handle to "wire 6, right now"
# ... arbitrary edits happen: deletes, moves, trims, undo ...
set i [xschem wire_index $h] ;# where did it go?
if {$i == -1} {
  puts "that wire is gone"
} else {
  puts "still here, now at index $i: [xschem wire_coord $i]"
}
```

Run against the same delete that broke us above:

```tcl
set h [xschem wire_id 6]     ;# -> 98   (the id; yours will differ)
xschem select wire 5 ; xschem delete
set i [xschem wire_index $h] ;# -> 5    (index moved from 6 to 5)
xschem wire_coord $i         ;# -> 1110 -600 1110 -560   <-- the SAME wire
```

The id tracked the wire through the compaction. And if you delete the wire the
handle points *to*, the handle fails **loudly** — it returns `-1`, it never
silently aliases a stranger:

```tcl
set h [xschem wire_id 6]
xschem select wire 6 ; xschem delete
xschem wire_index $h         ;# -> -1   (honest "it's gone", not a wrong wire)
```

---

## 3. What does the `6` in `xschem wire_id 6` mean?

This is worth slowing down on, because it is the crux of the whole design and
it is genuinely easy to misread.

**The `6` is an array index — a transient, positional address. It is *not* an
id.** It means "whatever wire is sitting in slot 6 of the wire array *at this
instant*." `wire_id` is the one-time bridge that converts that fragile,
positional reference into a durable one.

Think of it like a coat check:

- The **index** is *"the third coat from the left on the rack right now."*
  Useful only at this moment — someone adds or removes a coat and "third from
  the left" is now a different coat.
- The **id** is the **numbered ticket** the attendant hands you. It names
  *your* coat no matter how the rack is rearranged.
- `xschem wire_id 6` is the act of pointing at the third coat and saying
  *"give me the ticket for that one."* You point with a position; you walk
  away with a ticket.
- `xschem wire_index <ticket>` is the reverse: *"where is the coat for this
  ticket now?"* — the attendant walks the rack and finds it (or tells you it's
  gone).

So the index and the id are **different numbers for the same wire**, and they
are different on purpose:

```tcl
xschem wire_id 5   ;# -> 6     index 5  <-->  id 6
xschem wire_id 1   ;# -> 2     index 1  <-->  id 2
```

(They happen to be off by one here only because this file's wires were loaded
in array order, so slot 0 got id 1, slot 1 got id 2, and so on. Do **not** rely
on any arithmetic relationship between an index and an id — that is exactly the
coupling the feature exists to break.)

**Rule of thumb: index for *now*, id for *later*.** The instant you might do
anything that mutates the schematic before you use a wire again — a delete, a
move, a trim, an undo, even a `rebuild_connectivity` — stop carrying the index
and carry the id instead.

### Where do you get that first index?

You get it the way you always have — at a moment when you genuinely know which
wire you mean:

- from an enumeration loop (`for {set i 0} {$i < [xschem get wires]} ...`),
- right after selecting a wire,
- from a geometric search you just ran (see §7).

You use the index *once*, immediately, to mint the handle, and then you let it
go.

---

## 4. When *not* to use the old commands

The new commands don't replace the index-based API — they sit on top of it.
Indices are still how you address wires for `wire_coord`, `getprop wire`, and
`select wire`. What changes is the *discipline*:

| Don't | Do instead | Why |
| --- | --- | --- |
| Hold a raw index across **any** mutation | Convert to an id with `wire_id`, resolve back with `wire_index` | Compaction/splits/merges silently renumber indices (§1) |
| Assume `wire_coord 0` works | See the gotcha below | Off-by-one: index 0 returns empty (defect #1) |
| Expect `selected_set` to list wires | Use `selected_wire`, or enumerate geometrically (§7) | `selected_set` only reports instances/rects/texts (defect #4) |
| Rename a net with `setprop wire <n> lab <name>` | Edit the owning **label instance** instead | The connectivity engine overwrites a wire's `lab` on every rebuild — your write is silently lost (defect #6) |

### Gotcha: `wire_coord 0` is unreachable

There is a pre-existing off-by-one in `wire_coord`: it guards with `n > 0`
instead of `n >= 0`, so **index 0's coordinates come back empty**:

```tcl
xschem wire_coord 0   ;# -> {}        (empty — the bug)
xschem wire_coord 1   ;# -> 260 -550 340 -550
xschem wire_id    0   ;# -> 1         (wire_id does NOT have this bug)
```

This matters because the obvious "loop over every wire" idiom **silently drops
one wire** (see the bug bite in §6). It is listed as a trivial, separate fix
(defect #1) and was deliberately left out of this feature's scope so the
identity change stays a clean, isolated diff. Until it's patched, use the
complete-enumeration technique in §6 when totals must be exact.

---

## 5. Command reference

### `xschem wire_id <index>`

Returns the session-stable id of the wire currently at array index `<index>`,
or `-1` if the index is out of range (`< 0` or `>= [xschem get wires]`).

- Ids are **positive** (`> 0`). The value `0` is reserved to mean "never
  stamped" and no live wire ever has it.
- Ids are **unique within a context's session** and are **never reused**: if
  you create a wire, delete it, and create another at the same coordinates,
  the second gets a fresh, larger id.
- Ids are **not** saved in the `.sch` file. They are a runtime, in-memory
  identity only — load the same file twice and the ids may differ.

### `xschem wire_index <id>`

Returns the current array index of the wire whose id is `<id>`, or `-1` if no
live wire carries that id (it was deleted, or invalidated by a disk-undo
restore — see §8).

A `-1` is the *designed* answer for a dangling handle: loud, checkable, never a
wrong-but-plausible index. Always test for it before using the result as an
index.

Both commands are additive and side-effect free — they read state, they never
modify the schematic, undo stack, or selection.

---

## 6. Tutorial: a "total wire length" utility

Let's build something real: a command that sums the length of every wire in the
current schematic. This tutorial doubles as a lesson in *verifying your own
output*, which is a theme of this codebase (see
`claude_suggs/green_but_hollow_tests.md`).

### First attempt — the obvious loop

```tcl
proc total_wire_length_naive {} {
  set total 0.0
  set n [xschem get wires]
  for {set i 0} {$i < $n} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    set total [expr {$total + hypot($x2 - $x1, $y2 - $y1)}]
  }
  return $total
}
```

Run it and it doesn't return a number at all — it **throws**:

```
can't use empty string as operand of "-"
```

The very first iteration (`i == 0`) calls `wire_coord 0`, which returns an
empty string (the off-by-one from §4). `lassign` then sets `x1 y1 x2 y2` all to
`""`, and `$x2 - $x1` on empty strings is an error. The bug bit loudly and
immediately — which, annoyingly, is the *good* outcome. Watch what happens when
we "fix" the error the easy way.

### The easy fix that hides a worse bug

The obvious patch is to skip empty results:

```tcl
proc total_wire_length_guarded {} {
  set total 0.0
  set n [xschem get wires]
  for {set i 0} {$i < $n} {incr i} {
    set c [xschem wire_coord $i]
    if {$c eq {}} continue          ;# <-- silences the error
    lassign $c x1 y1 x2 y2
    set total [expr {$total + hypot($x2 - $x1, $y2 - $y1)}]
  }
  return $total
}
```

Now it runs cleanly and returns **`10670.0`**. No error, a confident number.
**It is wrong.** The `continue` didn't just swallow the error — it swallowed
*wire 0 itself*, silently dropping its length from the total. We traded a loud
failure for a quiet one, which is strictly worse: nothing now tells you the
answer is short.

### Verify against an independent ground truth

The discipline that catches this: *check the total against a source that
counts differently.* xschem's own file serializer writes one `N` record per
wire — including wire 0 — so the saved file is the authoritative wire list:

```tcl
proc total_wire_length_complete {} {
  set f /tmp/_wires_dump.sch
  file delete -force $f
  xschem saveas $f schematic        ;# xschem's serializer = ground truth
  set fd [open $f r]; set data [read $fd]; close $fd
  set total 0.0
  foreach line [split $data \n] {
    if {[regexp {^N ([-0-9.]+) ([-0-9.]+) ([-0-9.]+) ([-0-9.]+) } $line \
                 -> x1 y1 x2 y2]} {
      set total [expr {$total + hypot($x2 - $x1, $y2 - $y1)}]
    }
  }
  file delete -force $f
  return $total
}
```

This returns **`10710.0`** — `40.0` more than the guarded loop. That missing 40
units is the length of *wire 0*. The guarded loop ran 90 times where it should
have run 91; `wire_coord 0` returned empty, the `continue` skipped it, and the
total came up exactly one wire short.

This is the "green but hollow" failure mode in miniature: code that runs
cleanly and produces a confident number that is quietly off (see
`claude_suggs/green_but_hollow_tests.md` for the project's writeup of this
trap). The lesson is not "guard the empty string" — that's what *caused* the
silent version. The lesson is *cross-check the result against an independent
count.*

### The robust version

Use the complete enumeration, and make the index loop *prove* it saw every
wire instead of assuming it did — a count check turns the silent gap visible:

```tcl
proc total_wire_length {} {
  set total 0.0 ; set seen 0
  set n [xschem get wires]
  for {set i 0} {$i < $n} {incr i} {
    set c [xschem wire_coord $i]
    if {$c eq {}} continue          ;# index 0 today; tomorrow maybe more
    lassign $c x1 y1 x2 y2
    set total [expr {$total + hypot($x2 - $x1, $y2 - $y1)}]
    incr seen
  }
  if {$seen != $n} {
    # the loop dropped at least one wire (wire 0 today). Fall back to the
    # serializer, which sees every wire including index 0.
    return [total_wire_length_complete]
  }
  return $total
}
```

`puts "total wire length: [total_wire_length]"` → `total wire length: 10710.0`.

**What this tutorial taught beyond the number:** a loud failure
(`can't use empty string…`) is a *gift* — the dangerous version is the one that
runs and lies; silencing an error with `continue` can convert the first into
the second; a count check (`seen != n`) turns a silent gap back into a visible
one; and xschem's own save format is a reliable ground truth for "what objects
actually exist."

---

## 7. Querying wires by geometry — "which wires touch point (x, y)?"

A common real task: the user clicks somewhere, or names a coordinate, and you
want the wire(s) passing through it. There is no built-in "wires at point"
command, but it is a short geometric computation over the wire list — and this
is where stable ids earn their keep, because the *result* should outlive the
query.

### The honest state of "selected wires"

First, a caveat the user should know, because it shapes the approach. Reading
back *which wires are currently selected* is an API gap today:

```tcl
xschem unselect_all
xschem select wire 5 ; xschem select wire 7
xschem get lastsel       ;# -> 2          (count of selected objects)
xschem get first_sel     ;# -> 1 5 0      (type=WIRE(1), index=5, col=0 — FIRST only)
xschem selected_set      ;# -> {}         (omits wires entirely — defect #4)
xschem selected_wire     ;# -> {OUTI} {E1}  (net LABELS of the selected wires,
                         ;#                   not their indices or ids)
```

So you can learn *how many* objects are selected and the *net names* of
selected wires, but there is no clean call that hands you the **indices** of
every selected wire. (`first_sel` gives only the first.) That is a known hole
to be filled by the future `xschem object` / `xschem selection` work.

The practical consequence: **don't try to read an existing selection
geometrically.** Instead, compute the wires you want from geometry — which
gives you stable ids directly — and *then* select them if you want them
highlighted. "Compute, then select," not "select, then read back."

### A reusable point-on-segment test

```tcl
# Is point (px,py) within tol of the segment (x1,y1)-(x2,y2)?
proc wire_on_point {px py x1 y1 x2 y2 {tol 0.5}} {
  set dx [expr {$x2 - $x1}] ; set dy [expr {$y2 - $y1}]
  set len2 [expr {$dx*$dx + $dy*$dy}]
  if {$len2 == 0} {                     ;# degenerate (zero-length) wire
    return [expr {hypot($px-$x1, $py-$y1) <= $tol}]
  }
  set t [expr {(($px-$x1)*$dx + ($py-$y1)*$dy) / double($len2)}]
  if {$t < 0 || $t > 1} { return 0 }    ;# projection falls outside the segment
  set cx [expr {$x1 + $t*$dx}] ; set cy [expr {$y1 + $t*$dy}]
  return [expr {hypot($px-$cx, $py-$cy) <= $tol}]
}
```

This projects the point onto the (infinite) line, rejects projections that
fall beyond the wire's endpoints, and accepts if the nearest point on the
segment is within `tol` (xschem's user units; `0.5` is comfortably sub-snap).

> **Tcl gotcha worth pausing on:** the `double($len2)` is not cosmetic. Wire
> coordinates come back from `wire_coord` as *integer* strings, and a
> user-supplied point is usually integers too. Written as `... / $len2` with
> every operand an integer, Tcl does **integer division** — `200 / 400` is `0`,
> not `0.5` — and the projection parameter `t` collapses to an endpoint, making
> the test miss points that are genuinely on the wire. Forcing one operand to
> floating point fixes it. (This bug was caught only by *running* the proc on
> integer input; it "worked" on hand-typed float test points. The same
> verify-don't-assume discipline as §6.)

### The query — returning durable handles

```tcl
# Return a list of {id index {x1 y1 x2 y2}} for every wire touching (px,py).
proc wires_at_point {px py {tol 0.5}} {
  set hits {}
  set n [xschem get wires]
  for {set i 1} {$i < $n} {incr i} {     ;# start at 1: wire_coord 0 is broken
    set c [xschem wire_coord $i]
    if {$c eq {}} continue
    lassign $c x1 y1 x2 y2
    if {[wire_on_point $px $py $x1 $y1 $x2 $y2 $tol]} {
      lappend hits [list [xschem wire_id $i] $i $c]
    }
  }
  return $hits
}
```

Try it at the midpoint of wire 5 (`1110 -680 1110 -660` → midpoint
`1110 -670`):

```tcl
wires_at_point 1110 -670
;# -> {6 5 {1110 -680 1110 -660}}
;#      ^  ^  ^----------------- coordinates
;#      |  +------------------- current index (use it now)
;#      +---------------------- stable id (hold it for later)
```

Aim instead at a *junction* — the endpoint `1110 -680`, where three wires meet
— and the query returns all three, each with its own handle:

```tcl
wires_at_point 1110 -680
;# -> {6 5 {1110 -680 1110 -660}} {55 54 {1110 -680 1240 -680}} \
;#    {56 55 {1110 -690 1110 -680}}
```

(One caveat consistent with §4: this loop starts at index 1, so it cannot find
*wire 0* — if you need a point that might land on the very first wire, fall
back to the serializer enumeration from §6, which sees every wire.)

Notice each result carries the **id** as its first field. That is
deliberate: the moment this query returns, its *indices* start aging — any edit
invalidates them — but the ids stay good. So a caller can stash the ids, let
the user edit, and still act on exactly those wires later:

```tcl
set handles {}
foreach hit [wires_at_point 1110 -670] {
  lappend handles [lindex $hit 0]      ;# keep only the ids
}
# ... time passes, the user moves and deletes other wires ...
foreach h $handles {
  set i [xschem wire_index $h]
  if {$i != -1} { xschem select wire $i }   ;# re-select the survivors
}
xschem redraw
```

That loop — *find by geometry, remember by id, re-resolve to indices on demand*
— is the canonical pattern the whole feature enables. It was impossible before:
there was no `$h` you could put in that list.

---

## 8. Under the hood — how it was accomplished

This section is for the reader who wants the engineering story. It's a small
change in lines of code but a deliberate one in design.

### 8.1 The hard part was *not* the id — it was finding every birth

You can't stamp a stable id at creation if you don't know where "creation"
happens. The surprise, documented in `code_analysis/wire_lifecycle_census.md`,
was that wires are **born in seven different places**, not one. The obvious
factory (`storeobject` in `store.c`) is only one; the connectivity engine in
`check.c` creates and splits wires directly in four more spots, the file loader
(`load_wire`) had its *own* parallel copy of the field-initialization code, and
the in-memory undo system bulk-replaces the whole array. Deaths and array
compaction were scattered across four more functions in three files.

So the real first move (Phase C, several commits) was a pure **refactor with no
behavior change**: funnel all eighteen of those sites through a single family of
functions in `store.c`:

- `wire_store()` — the one "birth door" for normal creation,
- `wire_store_split()` — the birth door for connectivity-engine splits,
- `wire_delete_compact()` — the one "death door" (the shared
  free-and-shift-down idiom that was copy-pasted four times),
- `wire_storage_reset()` — the bulk clear used by load and undo.

Only once *every* wire flowed through those doors could a single line in each
door reliably stamp identity. This is the same lesson the project learned in
two earlier efforts (the scheduler command log and the key-binding table):
**when a concern is scattered, funnel first, then add the feature at the
funnel.** A feature bolted onto a scattered lifecycle would have missed cases —
exactly the bug class it was trying to cure.

### 8.2 The id itself: a stamp and a counter

With the funnel in place, identity is almost anticlimactic:

- `xWire` (the wire struct in `xschem.h`) gained one field:
  `unsigned int id;`.
- The context struct `Xschem_ctx` gained a monotonic counter,
  `unsigned int wire_id_counter;`. It lives in the context — *not* in a global
  — because xschem can have several schematics open in tabs/windows, each with
  its own `xctx`. Each gets its own id space.
- Each birth door does `xctx->wire[n].id = ++xctx->wire_id_counter;`. The
  counter only ever goes up and survives `clear`/load, so within one context's
  lifetime an id is **never reused** — which is what makes a dangling handle
  detectable rather than a silent collision.

A wire *split* is treated as a birth: the surviving segment keeps its id, and
each new segment gets a fresh one. (That decision is recorded by tests H6a–d.)

### 8.3 Resolution: a deliberate linear scan, not a hash map

`xschem wire_index <id>` has to turn an id back into an array index. The
"obvious" implementation is a hash map from id to index, maintained on every
insert, delete, and reorder. **The code deliberately does not do that.** It
scans the array:

```c
int wire_index_from_id(unsigned int id) {
  int i;
  if(id == 0) return -1;
  for(i = 0; i < xctx->wires; ++i)
    if(xctx->wire[i].id == id) return i;
  return -1;
}
```

Why refuse the "faster" data structure? Because the id lives *inside the wire
struct*, the array is *already* the authoritative id→index relation. It is
correct, for free, under every single mutation — the compaction shift, the
insert-with-shift, the `change_elem_order` swap, the undo bulk-replace, the
clear — with zero maintenance code. A separate map would be a second copy of
that truth, and a second copy is exactly the kind of thing that goes stale.
*Staleness is the disease this whole feature exists to cure*, so the
implementation refuses to introduce a fresh strain of it. Queries arrive at
human/script speed over arrays of typically a few hundred wires; a linear scan
is imperceptible. If a profile ever disagrees, a rebuild-on-miss cache can hide
behind that exact function signature without changing a single caller. (This
trade-off — boring-and-always-correct over clever-and-fragile — is the heart of
the design.)

### 8.4 Undo: two backends, two honest contracts

xschem has two undo implementations, and they treat identity differently — by
nature, not by neglect, and the difference is *tested and documented* rather
than hidden:

- **Memory undo** snapshots whole wire structs in and out. The `id` field rides
  along inside the struct automatically, so undo/redo **round-trips identity**:
  undo makes a handle dangle, redo brings back the *same* id resolving to the
  same wire (tests H5a/H5b). This worked with zero undo-code changes — the
  funnel/census predicted it.
- **Disk undo** restores by re-reading `.sch`-format temp files, i.e. through
  the loader's birth door — so restored wires are genuinely *new births with
  fresh ids*. A handle held across a disk-undo restore is **invalidated**: it
  resolves to `-1`. This is safe precisely because the counter is monotonic —
  the fresh ids are strictly larger than anything a script could already hold,
  so an old handle can never accidentally alias a restored wire (tests
  H7a–H7c).

The practical guidance: **memory undo preserves handles; disk undo invalidates
them.** If your script holds handles across an undo, prefer
`xschem undo_type memory`. Either way, the failure is loud (`-1`), never a
wrong answer.

### 8.5 Files touched (the whole change, at a glance)

- `xschem.h` — one field on `xWire`, one counter on `Xschem_ctx`, one
  prototype.
- `store.c` — stamp the id in both birth doors; add `wire_index_from_id`.
- `xinit.c` — initialize the counter when a context is allocated.
- `scheduler.c` — two new command branches (`wire_id`, `wire_index`) in the
  wire-command group.
- `tests/stable_handles/` — the characterization + identity suite (46 checks),
  written test-first (failing tests committed *before* the implementation, by
  design).
- `code_analysis/introspection_probes/probe3.tcl` — the before/after
  demonstration that re-runs the original §2e failure side by side with the
  handle version.

That's it. The leverage came from the refactor that preceded it, not from the
identity code, which is a field and a counter.

---

## 9. Limitations and what comes next

Be clear-eyed about the current scope:

- **Wires only.** Instances, texts, rects, lines, polygons and arcs still have
  no stable id. Instances are the planned next step (they have the worst
  remaining index scatter). The recipe — census → funnel → stamp — is proven
  and repeats mechanically.
- **Session-scoped.** Ids are not written to `.sch` files. They are stable
  *within* a running editor context, not *across* save/load. Persisting them is
  an explicit non-goal of this step.
- **No bulk/typed read API yet.** You still enumerate by index loop, and
  reading back a selection's wire indices is a gap (§7). The planned
  `xschem object <type> <n>` / `xschem selection` layer will sit on top of
  these ids.
- **The `wire_coord 0` off-by-one** (§4) is a separate trivial fix, not yet
  applied.

The longer arc: stable handles are also the missing piece for *replayable
action logs* (logging "delete the wire with id 1234" instead of the fragile
"delete wire 6") and for selection-as-data. One identity mechanism serves all
of these.

---

## 10. Quick reference & reproducing

```tcl
# --- the two new commands ---
xschem wire_id    <index>   ;# index -> stable id   (-1 if index out of range)
xschem wire_index <id>      ;# id    -> current index (-1 if no live wire has it)

# --- the canonical pattern ---
set h [xschem wire_id $i]            ;# grab a handle at a known index
# ...edits...
set i [xschem wire_index $h]         ;# resolve it back
if {$i != -1} { ... use index $i ... }  ;# always check for -1

# --- remember by id, not by index ---
set handles [lmap hit [wires_at_point $x $y] {lindex $hit 0}]
foreach h $handles { set i [xschem wire_index $h]; if {$i!=-1} {...} }
```

To watch the problem and the fix side by side:

```sh
cd src
./xschem -q --script ../code_analysis/introspection_probes/probe3.tcl
cat /tmp/wire_probe3.log
```

To run the test suite that specifies all of the above (needs an X display):

```sh
cd src
./xschem -q --script ../tests/stable_handles/wrap.tcl
cat /tmp/sh_test.log        # 46 PASS, 0 FAIL
```

### See also

- `code_analysis/tcl_introspection_wire.md` — the analysis that motivated the
  work; §2e is the original identity failure, §5 the defect list.
- `code_analysis/wire_lifecycle_census.md` — the eighteen wire-mutation sites.
- `claude_suggs/plan_stable_handles_step1.md` — the full TDD plan and phase
  history.
- `claude_suggs/green_but_hollow_tests.md` — the verification discipline the
  §6 tutorial illustrates.
