# Wire lifecycle census — every site that mutates wire storage

Phase B deliverable of `doc/claude/suggestions/plan_stable_handles_step1.md`.
This table is **authoritative** for Phase C: every site below gets funneled;
any site discovered later is a census bug fixed by funneling it, never by
special-casing.

## Method and acceptance criterion

Two independent sweeps over `src/*.c`, then each hit read in context:

1. count mutations: `grep -rn 'wires++\|wires--\|wires +=\|wires -=\|wires ='`
2. whole-struct array writes: `grep -rn 'wire\[...\] *= *xctx->wire\['` plus
   `qsort/memmove/memcpy` over wire arrays (none exist) plus array
   (re)allocation sites.

Sweep 2 is not redundant: it caught `change_elem_order()` (a swap that
touches no count) which sweep 1 cannot see. **Acceptance: every hit of both
sweeps appears in exactly one row below.** Verified against the greps on
2026-06-12 at `d2f5daa6`.

## BIRTH — 7 sites

| # | site | function | notes |
| --- | --- | --- | --- |
| B1 | `store.c:339–356` | `storeobject()` WIRE arm | **the official factory**: full field init (coords ORDERed by caller contract — actually by the `xschem wire` cmd; prop deep-copied; `bus` parsed; `set_wire_flags`; `sel` honored + `set_first_sel`). With `pos == -1` appends; with `pos >= 0` see R1 |
| B2 | `save.c:2845–2862` | `load_wire()` | **parallel birth implementation** (its own field init + `ORDER` + bus/flags parse, `node=NULL`). Runs on: file load, **disk-undo restore** (via `pop_undo`, save.c:3850), web/remote loads |
| B3 | `check.c:236` | `trim_wires()` | wire split: clones prop/bus/**node** of wire j into `wire[wires]`, adjusts endpoints, incremental `hash_wire(XINSERT)` |
| B4 | `check.c:520` | `break_wires_at_point()` | split: clones from wire i, sets `sel=0`, `end1/end2` managed, incremental hash insert |
| B5 | `check.c:595` | `break_wires_at_pins()` | split (first arm), like B4 |
| B6 | `check.c:685` | `break_wires_at_pins()` | split (second arm): **`sel=SELECTED` + `set_first_sel(WIRE, wires, 0)`** — the one birth that mutates selection state |
| B7 | `in_memory_undo.c:529–537` | `mem_pop_undo()` | bulk replace: fresh `my_calloc`, then **whole-struct copy from the undo slot** (`wire[i] = uslot.wptr[i]`) with `prop_ptr` re-strdup'd and `node` dropped to NULL |

`storeobject` WIRE callers (all in-tree calls pass `pos = -1`): `move.c:737,
867, 1059, 1084, 1109, 1134` (stretch/break during move), `paste.c:67`
(clipboard/merge paste), `actions.c:1215, 1272` (pin-to-wire hooks),
`actions.c:3282–3329` (orthogonal net routing), `scheduler.c:7065`
(`xschem wire` — the **only** caller that can pass a user-supplied `pos`).

## DEATH / COMPACT — 4 sites (all the same idiom)

| # | site | function | trigger |
| --- | --- | --- | --- |
| D1 | `check.c:288–298` | `trim_wires()` | merged/degenerate wires after trim |
| D2 | `check.c:390–399` | `trim_wires()` | second pass |
| D3 | `move.c:139–147` | `check_collapsing_objects()` | zero-length wires after a move/stretch |
| D4 | `select.c:505–513` | `delete_wires(selected_flag)` | the user-facing delete |

Shared idiom: one forward loop; for each doomed wire free `prop_ptr` +
`node`, count in `j`; survivors shift down `wire[i-j] = wire[i]`; finally
`wires -= j` and `prep_hash_wires = 0`. **Compaction is order-preserving
among survivors** (the probe's "index 6 became a different wire" is this
shift, not a swap). All four sites carry the same comment about
`hash_wire(XDELETE)` being impossible mid-loop — evidence this idiom wants
to be one function.

## BULK RESET — 2 sites

| # | site | function | notes |
| --- | --- | --- | --- |
| Z1 | `actions.c:1062–1069` | `clear_drawing()` | frees each wire's `prop_ptr`/`node`, `wires = 0`. Runs before every load — so B2 is always preceded by Z1 |
| Z2 | `xinit.c:513` | `alloc_xschem_data()` | new context: `wires = 0` (paired with the initial calloc, G2) |

## REORDER — 2 sites

| # | site | function | notes |
| --- | --- | --- | --- |
| R1 | `store.c:330–337` | `storeobject()` `pos >= 0` | insert-with-shift: every index ≥ pos changes meaning. Reachable **only from Tcl** (`xschem wire x1 y1 x2 y2 <pos>`) |
| R2 | `editprop.c:1117–1124` | `change_elem_order()` | swap `wire[new_n] ↔ wire[sel]` (the `xschem change_elem_order` command). Invisible to count-greps — found by sweep 2 |

## ARRAY GROWTH — 3 sites (memory moves; indices stable, pointers not)

| # | site | function | notes |
| --- | --- | --- | --- |
| G1 | `store.c:28–32` | `check_wire_storage()` | `my_realloc` doubling — any held `xWire *` dangles; indices unaffected |
| G2 | `xinit.c:630` | `alloc_xschem_data()` | initial calloc |
| G3 | `in_memory_undo.c:530` | `mem_pop_undo()` | replacement calloc (part of B7) |

## Out of scope (identity-preserving in-place field writes)

Files that write wire *fields* without changing array membership or order:
`hilight.c, move.c, check.c, select.c, store.c, actions.c, xinit.c,
callback.c` (sel flags, coords during stretch, `end1/end2`, `node`,
`prop_ptr` token substitution). These never invalidate an id→index map and
are not funneled in step 1. (They are exactly the writes a later
"coherence" phase routes through accessors.)

## Funnel mapping (Phase C work plan)

| Phase C helper | absorbs |
| --- | --- |
| `wire_store()` (one birth door) | B1 (extracted), B3, B4, B5, B6 (sel/first_sel handled via the existing `sel` param + flag), B2 (load_wire becomes a thin caller — kills the parallel field-init) |
| `wire_delete_compact()` (one death door) | D1, D2, D3, D4 (predicate-callback or flag-mask argument) |
| `wire_bulk_begin/end()` | Z1, Z2, B7/G3 (mem-undo restore), R2 declared bulk (swap) or given a tiny `wire_swap()` |
| unchanged | G1/G2 (allocation plumbing, called from inside the funnel) |
| R1 | keep inside `wire_store` (pos param), id stamping unaffected by the shift since ids live in the structs |

## Facts banked for Phase D (identity)

- **Memory undo round-trips an `id` field for free**: B7 copies whole
  structs from the slot (`wire[i] = uslot.wptr[i]`), and `mem_push_undo`
  (in_memory_undo.c:297–310) copies whole structs in. Only `prop_ptr` is
  re-duplicated and `node` dropped — an `id` member would survive both
  directions untouched.
- **Disk undo cannot**: `pop_undo` (save.c:3850) restores by re-reading
  `.sch`-format files through Z1 + B2 — fresh ids on every disk-undo
  restore. This is the D3 decision point exactly as planned.
- Compaction (D1–D4) is order-preserving, so the id→index map update on
  delete is a simple decrement walk, not a rebuild.
- R2 (swap) and R1 (shift) are the only reorderings; both are trivially
  map-maintainable since the structs carry their ids with them.
