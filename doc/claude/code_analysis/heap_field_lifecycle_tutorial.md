# Tutorial: safely adding a heap-owning field to a core object struct

**Audience:** anyone (human or a future Claude session) about to add a field that
*owns heap memory* — a pointer the object is responsible for freeing — to one of
the core object structs in `xschem.h`: `xInstance`, `xWire`, `xRect`, `xLine`,
`xPoly`, `xArc`, `xText`, `xSymbol`.

**Why this exists:** the `pin_selection` feature added `unsigned char *pin_sel`
(plus `int pin_sel_size`) to `xInstance`. The first cut freed it only at the two
instance **death** sites and was committed (`d3ac625f`). A code review then found a
whole class of **double-free / use-after-free** crashes: six *other* sites
struct-copy an instance and re-NULL its other heap pointers but left `pin_sel`
aliased or garbage. The fix (`5f19f9c4`) was one or two lines at each site. This
doc turns that painful lesson into a checklist so the next person gets it right the
first time.

Companion (authoritative site map): `instance_lifecycle_census.md` — every site
that mutates `xctx->inst[]`, with stable IDs (IB1–4/IB7, ID1–2, IZ1–2, IR1–2,
IG1–2). The wire/graphical analogs are `wire_lifecycle_census.md` and
`graphical_lifecycle_census.md`. **Read the relevant census; this tutorial tells
you what to *do* at each kind of site.**

---

## 1. The trap, in one paragraph

Core objects live in flat arrays (`xctx->inst[]`, `xctx->wire[]`, …) and are moved
around by **whole-struct assignment** (`a[i] = a[j]`). A struct copy is *shallow*:
it copies the pointer value, so now two struct slots point at one heap buffer. The
codebase's idiom for "make an independent copy" is **copy the struct, then re-NULL
and re-`my_strdup` each heap-owned pointer** (`prop_ptr`, `node`, `name`,
`instname`, `lab`, …). If you add a new heap pointer and forget to re-NULL it at one
of these sites, that slot **aliases** the source buffer. The crash comes later, when
*either* owner frees it (the second free is a double-free) or after one owner frees
it and the other dereferences the dangling pointer.

Growth does not save you. `check_inst_storage()` (**IG1**, `store.c`) `memset`s the
*newly grown* high-water slots to zero — but `inst_delete_compact()` (**ID1**) does
**not** re-zero the tail it vacates; those slots keep the aliased survivor copy that
was shifted over them. So a slot **reused** after a delete (e.g. `place_symbol`
appending at `n == xctx->instances`, now pointing into vacated space) still holds a
stale pointer. You must initialize the field explicitly at birth; you cannot rely on
the memset.

---

## 2. The five site classes and what each must do

| Class | What happens to the struct | What your new heap field needs |
| --- | --- | --- |
| **BIRTH / INIT** | a new object is created or a recycled slot is filled | **initialize** the field (usually `= NULL`, size `= 0`). Do not assume the slot is zeroed. |
| **COPY** (a birth that duplicates an existing object) | `dst = src` then re-NULL+`my_strdup` the heap pointers | **NULL it** so the copy does not alias `src`'s buffer. Then deep-copy *only if the field's value should be carried* (transient state like selection should not be). |
| **TRAVEL** (reorder: shift / swap) | the struct moves to another index, nothing is duplicated | **nothing** — the pointer rides along with its one owner. |
| **DEATH** | the object is destroyed | **free** the field (`my_free`) and zero its size. |
| **BULK RESET** | the whole array is emptied | **free** the field for every live object (usually the death door in a loop). |
| **UNDO** (snapshot **and** restore) | live→slot copy (push), slot→live copy (pop) — both are struct copies | **NULL it on both sides** so neither aliases the other. Transient state is excluded from undo entirely. |

Mnemonic: **BIRTH inits, COPY un-aliases, TRAVEL ignores, DEATH frees, UNDO does
both.** Growth (`IG1`) and the initial calloc (`IG2`) are allocation plumbing — they
zero new slots, so they need nothing, but they are *not* a substitute for BIRTH init
(reused slots aren't re-zeroed).

A field that is **transient** (selection highlight, a cache, a UI hint — anything
not part of the saved document) should be NULL/zero at every BIRTH/COPY/UNDO site:
a fresh, loaded, pasted, copied, or undo-restored object is simply "not in that
state yet." That is the case for `pin_sel`.

---

## 3. The worked example — `pin_sel` mapped to the census

`xInstance.pin_sel` (`unsigned char *`, the per-pin selection bitmap) +
`xInstance.pin_sel_size` (`int`, its allocated length). Transient selection state.

| Census | site (function) | file:line | treatment |
| --- | --- | --- | --- |
| IB1 | `place_symbol()` init / reused slot | `actions.c` (near the `node=NULL` block) | **NULL** (slot may be a vacated-tail alias after ID1) |
| IB2 | `load_inst()` | `save.c` (near `node=NULL`) | **NULL** (realloc'd slot is not zeroed for reused indices) |
| IB3 | `merge_inst()` (paste) | `paste.c` (near `node=NULL`) | **NULL** |
| IB4 | `move_objects()` copy | `move.c` (after `inst[instances]=inst[n]; …=NULL`) | **NULL** (the copy must not alias the source) |
| IB7 push | `mem_serialize_slot()` snapshot (via `mem_push_undo`) | `in_memory_undo.c` (after `s->iptr[i]=inst[i]; …=NULL`) | **NULL** (snapshot must not alias the live buffer) |
| IB7 pop | `mem_restore_slot()` restore | `in_memory_undo.c` (after `inst[i]=s->iptr[i]; …=NULL`) | **NULL** (restored inst starts unselected; must not alias the slot) |
| ID1 | `inst_delete_compact()` death door | `store.c` (next to `delete_inst_node`) | **free** + size `= 0` |
| IZ1 | `inst_storage_reset()` bulk reset | `store.c` | **free** + size `= 0` |
| IR1 | `place_symbol()` `pos>=0` shift | `actions.c` | **nothing** (shifted slots travel; the inserted slot is the IB1 birth, already NULL'd) |
| IR2 | `change_elem_order()` swap | `editprop.c` | **nothing** (swap moves whole structs; pin_sel travels) |
| IG1/IG2 | `check_inst_storage` realloc / initial calloc | `store.c` / `xinit.c` | **nothing** (zero new slots; but see IB1 — reused slots are not re-zeroed) |

Two subtleties worth internalizing:

- **`delete_inst_node()` is NOT a death site for `pin_sel`.** It frees `node[]` and
  runs on **every netlist rebuild** (`delete_netlist_structs`, and `select_element`'s
  `prepare_netlist_structs`). Freeing `pin_sel` there would wipe a live selection
  constantly. Free at the true death/bulk doors only (ID1/IZ1).
- **The size guard.** Because a symbol's pin count can change under a live selection,
  `pin_sel_size` records the allocation length and every consumer clamps its scan to
  `min(pin_sel_size, current_pin_count)`. That guard is independent of this lifecycle
  work, but it is why the field is a *pair* — and both halves must be reset together.

---

## 4. Finding every site (don't trust your memory — grep)

The census was built from two sweeps; reproduce them for your struct:

```sh
# 1) whole-struct array writes (COPY / TRAVEL / UNDO)
grep -nE 'inst\[[^]]+\] *= *.*inst\[|iptr\[[^]]+\] *= *|= *s->iptr\[' src/*.c

# 2) the "re-NULL the heap pointers" idiom (every COPY/INIT site lives next to one)
grep -nE '\.(prop_ptr|node|name|instname|lab) *= *NULL' src/*.c

# 3) death / free idiom
grep -nE 'my_free\(_ALLOC_ID_, &xctx->inst\[|delete_inst_node' src/*.c
```

Every hit of sweep 1 is a COPY (needs un-alias) or a TRAVEL (needs nothing) — read
it in context to tell which. Every hit of sweep 2 is a site that *already*
re-initializes the other heap pointers; your new field belongs in that same block.
Every hit of sweep 3 is a candidate DEATH site — but verify it is a *true* death and
not a per-rebuild teardown like `delete_inst_node`.

For another struct, swap `inst`/`iptr` for `wire`/`wptr`, `rect`/`bptr`,
`poly`/`pptr`, etc. (the undo slot uses the `?ptr` short names — see
`in_memory_undo.c`).

---

## 5. Verifying (the bug is invisible until it crashes)

A shallow-copy alias produces **no compile warning and no test failure** until a
free path runs twice. Drive the exact scenarios headless (a double-free aborts the
process, so a clean exit is the pass):

```tcl
# build the state, then exercise every path that copies/frees the struct
xschem instance devices/res.sym 0 0 0 0 {name=R1}
xschem set en_pin_select 1
xschem select instance R1 ; xschem select pin R1 0
xschem copy_objects 0 100      ;# IB4 copy  — copy must not alias
xschem unselect_all            ;# frees both — double-free here if aliased
# undo:  edit + undo with the field set        (IB7 push/pop)
# load:  load a real .sch repeatedly with the field set, then select_all
#        (IB2 + rebuild_selected_array dereferences a garbage pointer)
# delete: select only the transient state, Delete — must be a no-op
```

Run under `--nogui --pipe -q --script` and grep the output for `double free`,
`corruption`, `Aborted`, `Segmentation`. For the GUI gesture paths, inject events
with `xschem callback <win> <event> <x> <y> <key> <button> <aux> <state>` on
`DISPLAY=:0` (ButtonPress=4, Release=5, Motion=6; screen = `(world+origin)/zoom`).
See `pin_selection.md` and the session notes for the full battery.

---

## 6. The alternative you should weigh first

Before adding a heap pointer to a hot, frequently-copied struct, ask: **does this
state belong in the object at all?** Purely transient, derived, or UI-only state can
live in a **side structure on `xctx`**, keyed by the object's durable id
(`xInstance.id`, resolved via `inst_index_from_id`, see
`instance_identity_decision.md`). That removes the field from *every* copy / load /
paste / undo / death path at a stroke — none of them know it exists — at the cost of
an id→index lookup at use time.

For `pin_sel` the in-struct array was chosen to mirror the existing
`xPoly.selected_point` precedent (which gets the lifecycle right — grep it through
the same sites as a reference) and to ride the `rebuild_selected_array` scan. That
is a legitimate choice, but it is precisely the choice that buys you this whole
checklist. If your field is heavier or you don't need per-redraw struct locality,
the side-table design is often the safer call.

---

## 7. One-line takeaway

> Adding a heap-owning field to a core object struct is **not** done when it
> compiles and the happy path works. It is done when you have visited **every**
> BIRTH, COPY, TRAVEL, DEATH, BULK-RESET, and UNDO site in that struct's lifecycle
> census and decided, explicitly, what the field does at each.
