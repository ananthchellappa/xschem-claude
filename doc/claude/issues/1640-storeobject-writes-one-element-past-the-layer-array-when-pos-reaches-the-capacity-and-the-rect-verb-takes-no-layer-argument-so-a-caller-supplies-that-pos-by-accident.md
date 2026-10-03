# 1640 — `storeobject()` writes one element past the layer array when `pos` reaches the array's capacity, and the `rect`/`line` verbs take no layer argument, so a caller who passes one supplies that `pos` by accident

**STAMP:** `v1 claim=open tree=a90ffb98 stamped=2026-10-02 fix=none open=4`

Status: **OPEN**, found 2026-10-02 by a calculator batch suite-author crew reaching for a
programmatic rectangle, and characterised here. Pre-existing; no Calculator change caused it.

Area: `storeobject()` and `wire_store()`, with `check_box_storage()` and `check_wire_storage()` —
all `src/store.c` — behind the `rect`, `line` and `wire` coordinate arms of the dispatcher in
`xschem_cmds_r()`, `src/scheduler.c`.
Found: `env -u DISPLAY ./src/xschem --pipe -q --nogui --script …`, eleven calls, two controls and
one valgrind run. Witnessed under valgrind-3.26.0.

## Part 1 — a heap buffer overflow, witnessed, that kills the process with exit 134

`storeobject()`'s `xRECT` arm opens with `check_box_storage(rectc)`, which grows the array only
when `xctx->rects[c] >= xctx->maxr[c]` — it is told the **count**, never the **index about to be
written**. The insert path then takes `n = pos` with no bound of any kind, and `pos` arrives
straight from the caller.

`CADMAXOBJECTS` is the initial per-layer capacity and `CADMAXWIRES` the wire one, so on a fresh
schematic the first unwritable index is exactly that capacity. Measured:

```
xschem rect 0 0 100 100 99     EXIT=0     rects=1
xschem rect 0 0 100 100 100    EXIT=134   double free or corruption (!prev)
xschem rect 0 0 100 100 200    EXIT=134   double free or corruption (!prev)
xschem line 0 0 100 100 100    EXIT=134   double free or corruption (!prev)   lines=1
xschem wire 0 0 100 100 199    EXIT=0     wires=1
xschem wire 0 0 100 100 200    EXIT=134   double free or corruption (!prev)   wires=1
```

**All three birth doors have it**, each at its own capacity. `rect` and `line` are written by
`storeobject()` itself; the `wire` arm reaches `wire_store()` through `storeobject()`'s `WIRE` arm,
and that function repeats the shape verbatim with its own `check_wire_storage()`. The `wire` arm is
the one that looks innocent at `pos` 100 and is not. These three dispatcher arms are also the
**only** `storeobject()` call sites in the tree that pass anything other than −1.

`xschem get rects` answers **1** in every crashing case, because `gfx_register()` increments the
count after the out-of-bounds write — so the verb reports a stored object, returns the empty
string, raises no Tcl error, and the process is already doomed.

### What valgrind witnessed, and the value that corrupted the metadata

```
==2926153== Invalid write of size 8
==2926153==    at 0x…: storeobject (in …/src/xschem)
==2926153==    by 0x…: xschem_cmds_r.constprop.0 (in …/src/xschem)
==2926153==    by 0x…: xschem (in …/src/xschem)
==2926153==    by 0x…: TclInvokeStringCommand (…libtcl8.6.so)
==2926153==  Address 0x7338dc0 is 0 bytes after a block of size 8,800 alloc'd
==2926153==    at 0x…: calloc (vg_replace_malloc.c:1678)
==2926153==    by 0x…: my_calloc (in …/src/xschem)
==2926153==    by 0x…: alloc_xschem_data (in …/src/xschem)
```

Three such invalid writes, at `0 bytes after`, `16 bytes after`, and one reported `24 bytes before`
the **next** array's block — the write runs off the end of one layer's array, through the
allocator's metadata, and into the neighbouring allocation. The block is the one
`alloc_xschem_data()` calloc'd for this layer, and its size divided by the capacity is
`sizeof(xRect)`, which is how the arithmetic was checked rather than assumed.

The fourth write never got reported, because valgrind's own heap bookkeeping died on it:

```
valgrind: m_mallocfree.c:304 (get_bszB_as_is): Assertion 'bszB_lo == bszB_hi' failed.
valgrind: Heap block lo/hi size mismatch: lo = 8864, hi = 4636737291354636288.
```

**`4636737291354636288` is `0x4059000000000000`, which is the IEEE-754 double `100.0`** — the `y2`
coordinate of the call, sitting in the heap block's trailing size field. That is the whole defect in
one number: a user-supplied coordinate is now the allocator's idea of how big a chunk is.

So this is **not** a double `my_free` on the same pointer and **not** a free of memory the caller
still owns. Nothing is freed twice. glibc's `double free or corruption (!prev)` is the message it
prints when `free()` finds a chunk whose size fields disagree with its neighbour's `prev_size` — the
corruption is an *overflow*, and the free that trips over it is innocent.

### ⚠ It is a T1 hazard, and `banner_died` is the wrong thing to have checked

The abort fires at **process teardown, not during the command**. A script survives the bad call
completely: measured, after `xschem rect 2 0 0 100 100` the same process went on to place 50 more
rectangles (`rects=51`), ran `xschem clear force`, printed all four of its own progress markers, and
only then aborted. Nothing is printed on stdout; the glibc sentence goes to **stderr**; there is no
column-0 `FATAL: signal` or `Tcl_AppInit() error` line, so `banner_died` in `tests/banner_rule.tcl`
does **not** match it.

That does not make it cosmetic. `regression_case_failed` tests the child code **first**:

```tcl
proc regression_case_failed {childcode body} {
  if {$childcode != 0} { return 1 }
  …
```

and the exit code is **134**. Any registered suite that reaches this write is a counted T1 `FAIL`
whose own `RESULT:` line may well say `ALL PASS`, with the cause on a stream the verdict does not
carry. The absence of a death marker is therefore the least informative fact about it.

## Part 2 — the `rect` verb takes no layer argument, which is how `pos` gets supplied by accident

Nothing in Part 1 is reachable by anyone who means to pass a `pos`; a caller who writes one knows
the array. The reason this was found is that the verb's signature is not the one it looks like.

The help block in `xschem_cmds_r()` is accurate and the trap is in what it omits:

> `rect [x1 y1 x2 y2] [pos] [propstring] [draw]`
> if `x1 y1 x2 y2` is given place recangle on current layer (rectcolor) at indicated coordinates.

**There is no layer argument.** The layer is `xctx->rectcolor`, implicitly. So the natural-looking
`xschem rect <layer> <x1> <y1> <x2> <y2>` shifts every argument left by one: the layer becomes `x1`,
and the caller's **`y2` becomes `pos`**. A rectangle asked for at `0 0 100 100` on layer 2 is a
request to insert at index 100 — Part 1 exactly, on the first call, on an empty schematic:

```
xschem rect 2 0 0 100 100
rectcolor=4
rects(rectcolor) before=0
result=<>                         (empty, no Tcl error)
rects(rectcolor) after=1
rects(2) after=0                  (the layer the caller thought it named)
EXIT=134                          double free or corruption (!prev)
```

`rects(2) after=0` is the second half of the misreading: the rectangle, such as it is, went to layer
`rectcolor`, so a caller who then asks how many rectangles are on the layer it passed is told
**zero** and concludes the verb is interactive placement rather than a programmatic insert. It is a
programmatic insert; it just ignored the layer and ate a coordinate.

Any coordinate below the capacity hides both halves. `xschem rect 2 0 0 100` is `argc` 6, so `pos`
stays −1, the append path runs, and it answers cleanly with the rectangle on the wrong layer and one
coordinate wrong. `xschem rect 0 0 100 100` — the correct spelling — is clean.

## Part 3 — a `pos` between the count and the capacity silently loses the object

The same missing bound has a non-memory half that is quieter and survives any fix aimed only at the
crash. With `pos` greater than `xctx->rects[c]` but inside the capacity, the shift loop
`for(j = xctx->rects[rectc]; j > pos; j--)` does not execute, `n = pos`, and the object is written
into a slot the count will never reach:

```
xschem rect 0 0 100 100 5        EXIT=0
xschem get rects <rectcolor>  -> 1
xschem saveas <scratch>/pos5.sch:
  B 4 0 0 0 0 {}
```

One rectangle counted, and it is the **zero-filled slot 0** — a degenerate zero-size rectangle on
layer 4. The rectangle the caller asked for is at index 5, outside the count, and is not saved, not
drawn and not reachable. (Slot 0 reads as zeros here only because `alloc_xschem_data()` calloc's the
array; after a `check_box_storage()` growth with `ZERO_REALLOC` unset it is whatever the allocator
handed back, so the shape of this half is "an uncounted gap", not "a zero rectangle".)

The valid insert path is sound and worth stating so nobody widens the fix: with
`0 <= pos <= rects[c]` the shift loop's highest write is index `rects[c]`, `check_box_storage()` has
already guaranteed that index exists, and `rects[c]` then increments past it.

## Open items

1. **Bound `pos` where the write happens.** `storeobject()` and `wire_store()` are the two places
   that take an index from a caller, and neither looks at it. The cheap honest form is to reject
   `pos > xctx->rects[c]` (and the wire equivalent) and let the verb say so — it is the item with
   the memory safety in it, and it closes Part 1 and Part 3 together, because a gap and an overflow
   are the same unchecked comparison on either side of the capacity.
2. **Tell the storage check which index is coming.** `check_box_storage()` and
   `check_wire_storage()` take a layer and a void respectively and derive the needed capacity from
   the count. If item 1 is ever relaxed to make a far `pos` legal rather than refused, these are the
   functions that must be told the index instead; as they stand they cannot grow for a `pos` they
   are never shown. Noted so that a future "allow sparse insert" change does not reintroduce the
   overflow one layer down.
3. **The help text should say that the layer is implicit.** The block in `xschem_cmds_r()` names
   `rectcolor` in passing, in a sentence about where the rectangle is placed. It does not say *no
   layer argument is accepted*, which is the sentence that would have prevented this, and the same
   omission is in the `line` and `poly` blocks. One clause each, and worth doing first and
   separately — the same reasoning issue 1635 gives for `raw new`'s point-count sentence and 1631
   for `pos_at`'s. ⚠ `xschem set rectcolor <n>` is the existing way to choose the layer; a crew
   tempted to *add* a layer argument should notice that `pos` is already positional behind the
   coordinates, so the compatible shapes are limited.
4. **A fence is owed and none exists.** The row is three calls and an exit code: `pos` at
   capacity − 1 exits 0, `pos` at capacity exits 134, and the correct four-coordinate spelling
   exits 0 as the control. The control is what distinguishes this defect from a broken fixture.
   It must assert the **exit code of a child process**, not a Tcl result — the verb answers the
   empty string and raises nothing in every case, so a row that only inspects the return value
   measures nothing. The Part 3 row compares `xschem get rects` against what a `saveas` to scratch
   actually contains, which is the only readout that showed the object had been lost.

## What this is NOT

Not a double free, and not a free of live memory, despite glibc's wording. See Part 1: the message
names the symptom glibc can see, and the cause is a four-doubles-wide overflow of the layer array,
witnessed by valgrind as an invalid write `0 bytes after` the block and confirmed by the allocator
metadata holding the double `100.0`.

Not a defect in the interactive path. `new_rect()` and the other interactive creators call
`storeobject()` with `pos` −1, and every in-tree `storeobject()` call site that was read passes
either −1 or an index derived from an array it has just measured. The unbounded `pos` is only
reachable from the Tcl verbs.

Not an argument-count or argument-parsing bug in the dispatcher. The `rect` arm parses exactly what
it documents; Part 2 is a mismatch between that documented signature and the one a caller expects
from every other layer-taking verb, and it is filed here because it is the only route by which a
caller supplies a dangerous `pos` without meaning to.

Not reproduced through `xschem poly`, whose dispatcher arm calls `store_poly()` with a hardwired −1
and so has no caller-supplied index to get wrong.
