# Instance lifecycle census — every site that mutates instance storage

Phase B deliverable of the stable-object-handles **step 2 (instances)** work,
the analog of `wire_lifecycle_census.md`. This table is **authoritative** for
the instance funnel: every site below gets funneled; any site discovered later
is a census bug fixed by funneling it, never by special-casing.

Instances live in `xctx->inst[]` (count `xctx->instances`, type `xInstance`,
`xschem.h:609`). Unlike wires, an instance also carries a **name**
(`instname`, e.g. `R25`) and a **symbol reference** (`ptr`, an index into
`xctx->sym[]`), and per-pin net names in `node[]`.

## Method and acceptance criterion

Two independent sweeps over `src/*.c`, each hit read in context:

1. count mutations: `grep -n 'instances++\|instances--\|instances +=\|instances
   -=\|instances ='` (filtering the unrelated `sch_inst_number`, netlist-local
   `const int instances`, etc.);
2. whole-struct array writes: `grep -n 'inst\[...\] = ...inst\['` plus
   `qsort/memmove/memcpy` over `xctx->inst` (none exist) plus realloc sites.

**Acceptance: every hit of both sweeps appears in exactly one row below.**
Verified against the greps on 2026-06-13 at `1c653298`.

## BIRTH — 4 sites (the headline difference from wires: **no `check.c` births**)

| # | site | function | notes |
| --- | --- | --- | --- |
| IB1 | `actions.c:1564` (`++` at 1654) | `place_symbol()` | **the interactive factory**: symbol looked up + linked (`ptr`), struct initialised, `check_inst_storage()` at 1612, name assigned/uniquified via `new_prop_string()`, `hash_names(XINSERT)` + `hash_inst(XINSERT)`, then `select_element(...,SELECTED)`. Reached by `xschem instance …`, GUI place, pin-to-wire hooks. `pos>=0` path = IR1 (shift) |
| IB2 | `save.c:2855` (`++` at 2899) | `load_inst()` | **load-path birth**: own field init from the `.sch` `C {…}` record; name comes **from the file** (no uniquify); symbols linked afterward by `link_symbols_to_instances()`. Runs on file load and **disk-undo restore** (via `pop_undo`) |
| IB3 | `paste.c:274` (`++` at 312) | `merge_inst()` | **clipboard/merge birth**: struct from the merged file, `check_inst_storage()` at 280, `new_prop_string()` uniquifies the name, `hash_names(XINSERT)`. Reached by `xschem paste` / merge |
| IB4 | `move.c:941` (`++` at 972) | `move_objects()` RUBBER→END copy | **copy birth**: `inst[instances] = inst[n]` (whole-struct copy at 941), then `new_prop_string()` renames to a fresh unique name, `update_attached_floaters()`, `set_first_sel(ELEMENT,…)`. Reached by `xschem copy_objects` and interactive copy-drag |

**Name assignment is part of birth semantics** (`token.c`): `new_prop_string()`
mints/uniquifies `instname` (called *after* `++` for IB1/IB3/IB4, *before* for
IB2 which takes the file's name); `check_unique_names()` is the bulk
rename-duplicates pass. The funnel's birth door must support both "name given"
(load) and "name to be uniquified" (interactive/copy/merge).

## DEATH / COMPACT — 1 death door (+ 1 error-path rollback)

| # | site | function | notes |
| --- | --- | --- | --- |
| ID1 | `select.c:579` (`-= j` at 582) | `delete_objects()` | the **only** user-facing instance delete: forward loop, each doomed instance `delete_inst_node(i)` (frees `node[]`) then survivors shift down `inst[i-j]=inst[i]`, finally `instances-=j` + `prep_hash_inst=0`/`prep_net_structs=0`/`prep_hi_structs=0`. **Order-preserving** compaction (CHI7 proves the index-shift) |
| ID2 | `actions.c:1702` (`--`) | `place_symbol()` rollback | error path only: undoes the IB1 `++` when symbol embed setup fails. Not a user-facing death; the funnel birth door owns this |

## BULK RESET — 2 sites

| # | site | function | notes |
| --- | --- | --- | --- |
| IZ1 | `actions.c:1073` | `clear_schematic()` | frees every instance (`delete_inst_node` per inst) then `instances = 0`. Runs before every load, so IB2 is always preceded by IZ1 (CHI10 locks the count) |
| IZ2 | `xinit.c:515` | `alloc_xschem_data()` | new context: `instances = 0` (paired with the initial calloc, IG-init) |

## REORDER — 2 sites

| # | site | function | notes |
| --- | --- | --- | --- |
| IR1 | `actions.c:1619` | `place_symbol()` `pos>=0` | insert-with-shift: `inst[j]=inst[j-1]` for every index ≥ pos. **Unreachable from Tcl** (the `xschem instance` command hardcodes `pos=-1`) — the analog of wire R1; characterization notes it as an honest gap |
| IR2 | `editprop.c:1053` (swap at 1100) | `change_elem_order()` | swap `inst[new_n] ↔ inst[sel]` (`xschem change_elem_order`). Found by sweep 2; CHI9 exercises it |

## ARRAY GROWTH / BULK REPLACE — realloc + undo

| # | site | function | notes |
| --- | --- | --- | --- |
| IG1 | `store.c:67` | `check_inst_storage()` | `my_realloc` by `ELEMINST`; also zeroes `flags` on the new slots (bit 8 hygiene). Any held `xInstance *` dangles; indices unaffected |
| IG2 | `xinit.c` | `alloc_xschem_data()` | initial calloc (paired with IZ2) |
| IB7 | `in_memory_undo.c:489` | `pop_undo()` | **bulk replace**: `instances = uslot.instances`, fresh `my_calloc`, then whole-struct copy from the slot with `prop_ptr`/`instname`/`name`/`lab` re-duplicated and `node` dropped; `prep_hash_inst=0`. Push side copies structs in at `in_memory_undo.c:302` |

## Out of scope (identity-preserving in-place field writes)

Writes to instance *fields* without changing array membership or order —
`sel` flags, `x0/y0` during move/stretch, `rot/flip`, `prop_ptr`/`instname`
token edits, `node[]` (re)assignment by the netlister, `color`/`flags`. These
never invalidate an id→index map and are not funneled in step 2.

## Funnel mapping (Phase C — DONE)

Phase C complete (commits IC1 death / IC2 bulk / IC3 birth): the death and
bulk idioms are extracted into `store.c` and all four births funnel their
increment through `inst_register(n)`. The reorder (IR1/IR2), growth (IG1) and
bulk-replace (IB7) sites need **no** funneling: with the planned linear-scan
id→index resolver (as for wires) the id travels inside the struct, so the
array is the authority under every shift/swap/realloc/undo with zero map
maintenance. Suite green throughout (instances 33/33, wires 57/57).

| Phase C helper | absorbs |
| --- | --- |
| `inst_store()` (one birth door) | IB1 (extracted), IB2 (load_inst becomes a thin caller), IB3, IB4 — with a `name` mode flag (given vs uniquify) to cover the load-vs-interactive difference, and `pos` for IR1 |
| `inst_delete_compact()` (one death door) | ID1 (predicate/flag-mask), ID2 rollback |
| bulk channel | IZ1, IZ2, IB7/`pop_undo`, IR2 swap (or a tiny `inst_swap`) |
| unchanged | IG1/IG2 (allocation plumbing, called from inside the funnel) |

## Phase D (identity) — DONE (2026-06-13)

The funnel paid off exactly as banked below: identity was stamped in **one
line** at the `inst_register` chokepoint (`xctx->inst[n].id =
++xctx->inst_id_counter`), with a per-context monotonic counter, an
`inst_index_from_id` linear-scan resolver, two scheduler commands
(`instance_id` / `instance_index`), and the id surfaced in the `selection`
instance row. Memory undo round-tripped it for free; disk undo invalidates on
restore (the settled wire-D3 behavior). Decision (`both`, id as durable session
handle + name as human/cross-session form) is recorded and now marked
**implemented** in `instance_identity_decision.md`; suite
`tests/stable_handles/inst_*.tcl` (48 PASS) and probe
`code_analysis/introspection_probes/probe4.tcl`.

## Facts banked for Phase D (identity)

- **Memory undo round-trips an `id` field for free**: IB7 copies whole structs
  both directions (`in_memory_undo.c:302` push, `:489` pop) — only `prop_ptr`
  et al. are re-duplicated and `node` dropped, so an `id` member survives
  untouched, exactly as for wires.
- **Disk undo cannot**: `pop_undo`'s disk path restores by re-reading the
  `.sch` through IZ1 + IB2 (`load_inst`) — fresh ids on every disk-undo
  restore. Same D3 decision as wires (recommend invalidate-on-restore).
- Compaction (ID1) is order-preserving, so an id→index update on delete is a
  decrement walk, not a rebuild (CHI7).
- IR2 (swap) and IR1 (shift) are the only reorderings; both carry ids inside
  the structs.
- **The decision wires did not have:** instances already own a *stable handle*
  — the **name** (`instname`), which CHI7 proves survives compaction while the
  index does not. So Phase D for instances is a genuine design choice
  (id vs. name vs. both) — **analysed and recorded in
  `instance_identity_decision.md`** (recommendation: both, id as the durable
  session handle, name as the human / cross-session form; verified that names
  are *reused* — `R37` came back after delete — so name-only is unsafe).
  Decision awaits user ratification before any field is stamped.
- **Symbol coupling:** `ptr` indexes `xctx->sym[]`; the birth door must link it
  (lookup for IB1/IB3/IB4, `link_symbols_to_instances()` for IB2). The funnel
  does not touch symbol lifecycle — that is a later type.
