# Plan: stable object handles — step 1 (wire lifecycle funnel + ids), TDD

Branch: `feature/stable-object-handles`.
Status: Phase A DONE (26 checks green at clean HEAD; two facts characterized
along the way: disk undo round-trips a save byte-identically, memory undo
loses the multi-line v{} header — CH5c locks the body-level invariant).
Phase B DONE (`doc/claude/code_analysis/wire_lifecycle_census.md`: 7 births, 4 deaths,
2 bulk resets, 2 reorders, 3 growth sites — incl. two found only by the
struct-write sweep: change_elem_order swap, mem_pop_undo bulk replace;
banked for D: memory undo struct-copies ids for free, disk undo re-loads
through load_wire).
Phase C DONE (C1 9c332c76, C2 ea08bb0e, C3 6a6986a2, C4 ba13cc1f): all 18
census sites route through store.c — wire_store / wire_store_split /
wire_delete_compact / wire_storage_reset; suite grew to 32 checks (split
births now provably executed, verified green on the PRE-refactor build
first via git stash).
Phase D DONE (D1 dd0a56d6 RED: 12 xchecks logged XFAIL on the
pre-implementation build; D2 6e0c6eaf GREEN: xWire.id stamped at both
birth doors, per-context monotonic wire_id_counter, `xschem wire_id` /
`xschem wire_index`, id→index resolution is a deliberate linear scan —
ids travel in the structs so the array is the map, no coherence
machinery to go stale; D3 d539e30e: user chose option (b)
invalidate-on-restore for disk undo — zero C change, the monotonic
counter makes aliasing impossible, H7a–c assert the contract).
Phase E DONE (probe3.tcl re-runs the §2e failure side-by-side with the
handle version; cross-refs in tcl_introspection_wire.md §5 defect 7 and
§6.4). Suite: 46 checks, 0 XFAIL. STEP 1 COMPLETE — step 2 awaits the
user's pick from the decision menu (E3).
Prereqs: `doc/claude/code_analysis/tcl_introspection_wire.md` (the why),
`doc/claude/code_analysis/objects_in_c_vs_cpp.md` §5 (the how),
FAQ Q7 (why the funnel comes before the handle).

## Goal of step 1

Three things, bundled because each is unsafe or unverifiable without the
others:

1. **Characterization tests first** — lock today's wire lifecycle behavior
   through the Tcl surface, so the refactor is provably behavior-identical.
2. **Funnel** — every birth, death, compaction and bulk-replace of a wire
   goes through one function family in `store.c`. Pure refactor.
3. **Identity** — a session-stable, never-reused wire id stamped at the
   funnel, queryable from Tcl, surviving neighbor-deletes, compaction and
   (memory-)undo. The tracer bullet that proves the architecture.

Wires only. The other six object types repeat the recipe mechanically in
later steps, once the recipe is proven on the type we know best.

## Non-goals of step 1 (explicitly deferred)

- Other object types (instances next — they have the second-worst scatter).
- Persisting ids in the `.sch` file format (session-scoped only).
- The uniform `xschem object` dict API, selection-as-ids, net-as-object.
- The general cache-coherence sweep (only what the funnel absorbs naturally).
- Fixing the unrelated potholes from the analysis (wire_coord 0, unchecked
  getprop index, selected_set omissions) — separate, trivial commits later;
  do not mix them into the refactor diffs.

## TDD discipline (applies to every phase)

- The characterization suite must be green at **every commit** from A3 on.
- New-feature tests are committed **failing first** (marked `XFAIL` in the
  log so the suite distinguishes "expected red" from regressions), then
  flipped to `PASS` by the implementation commit. The commit message of the
  implementation cites the tests it turns green.
- No C change lands without a test that observes it. If a change is
  unobservable through the Tcl surface, add the observation command first
  (that is itself TDD: the observation command gets a test).
- Test harness: the proven wrapper pattern from `tests/file_open_dialog/`
  (log file + `check` proc + modal stubs + `exit`; run
  `cd src && ./xschem -q --script ../tests/stable_handles/wrap.tcl`).
  Reuse `mos_power_ampli.sch` (91 wires) as the rich fixture; tiny synthetic
  cases build their own wires from an empty schematic.

## Phase A — safety net (no C changes)

**A1. Harness.** `tests/stable_handles/{wrap.tcl,test_body.tcl}` cloned from
the file-open suite pattern. One extra utility worth adding: a
`wire_snapshot` proc (loop `wire_coord i` + `getprop wire i lab` into a
sorted list) — sorted so it is *order-independent*, because compaction may
legally reorder the array; behavior we must preserve is the **set** of
wires, not their indices. (The analysis proved indices are already
unstable today; characterization must not accidentally freeze an
implementation detail we intend to keep free.)

**A2. Characterization tests** (all must pass at current HEAD):

| id | behavior locked |
| --- | --- |
| CH1 | `xschem wire x1 y1 x2 y2` → `get wires` +1; snapshot gains exactly that wire |
| CH2 | select + `delete` → −1; snapshot loses exactly that wire |
| CH3 | `undo` / `redo` round-trips CH1+CH2 snapshots — **run twice: `xschem undo_type memory` and `undo_type disk`** (both backends are live code paths, scheduler.c:6891) |
| CH4 | `trim_wires` / `break_wires` / `rebuild_connectivity` on the fixture: wire counts and snapshots recorded as goldens (these exercise the check.c birth/death sites we are about to refactor — they are the highest-risk sites, so they get the densest coverage) |
| CH5 | scripted edit→undo→save cycle produces a byte-identical `.sch` vs golden (whole-pipeline drift detector) |
| CH6 | `xschem get lastsel` / `selected_wire` behavior after select-wire (locks the selection side effects the funnel must not change) |

**A3. Commit** harness + goldens. Acceptance: suite green at clean HEAD,
runtime < ~60 s.

## Phase B — census (doc only)

**B1.** `doc/claude/code_analysis/wire_lifecycle_census.md`: every site that mutates
wire storage, classified. Seed list from the greps already done — to be
completed by reading each file (the census is authoritative; if it finds
more sites, the funnel covers them, no exceptions):

| class | known sites (to verify + complete) |
| --- | --- |
| BIRTH | `store.c:339` (storeobject WIRE arm); `check.c:236,520,595,685` |
| DEATH/COMPACT | `check.c:298,399`; `move.c:147`; `select.c:513` |
| BULK_RESET | `actions.c:1069`; `xinit.c:513` |
| BULK_REPLACE | load path (`save.c`); undo restore (`in_memory_undo.c`, disk undo in `save.c`); paste? |
| REORDER | any qsort/memmove over `xctx->wire` (to be searched) |

For each: file:line, what invariants it touches (`prep_hash_wires`,
`need_reb_sel_arr`, …), and whether it can call the funnel directly or needs
a bulk channel. **Acceptance: every `wires++`, `wires--`, `wires =` and
every pointer-arithmetic write into `xctx->wire[]` in the tree is in the
table.**

**B2.** Commit the census.

## Phase C — the funnel (pure refactor, one commit per site cluster)

New family in `store.c` (C89, plain functions; mutation is human-speed, the
draw path never enters here):

```c
int  wire_store(double x1,double y1,double x2,double y2,
                short sel, const char *prop);     /* the ONE birth door  */
void wire_delete_compact(/* census-shaped args */);/* the ONE death door  */
void wire_bulk_begin(void); / wire_bulk_end(void); /* load/undo/clear     */
```

- **C1.** Extract the WIRE arm of `storeobject` into `wire_store`;
  `storeobject` calls it. Zero-diff behavior; suite green.
- **C2.** Rewrite the four `check.c` births to call `wire_store`. These are
  the risk concentrate: each site must be diffed **field by field** against
  the helper's semantics (`end1/end2`, `sel`, prop ownership) — the lesson
  from the action-registry migration applies verbatim: *"a call that looks
  like this helper" is a hypothesis; read the branch.* CH4 is the test that
  has the authority here.
- **C3.** Funnel the death/compaction sites (`check.c`, `move.c`,
  `select.c`).
- **C4.** Bulk channel for reset/load/undo-restore sites.
- Each commit: suite green, diff reviewed for verbatim semantics. No
  functional change anywhere in C1–C4.

## Phase D — identity (the TDD payoff)

**D1 (RED).** Commit failing tests for a deliberately *minimal* new surface
(two scheduler subcommands, additive):

```
xschem wire_id <index>      → id (or -1)
xschem wire_index <id>      → current index (or -1)
```

| id | property under test |
| --- | --- |
| H1 | id of a created wire is > 0 and unique |
| H2 | **the §2e scenario**: take id of wire A, delete wire B, `wire_index id(A)` still dereferences to A's coordinates |
| H3 | delete A itself → `wire_index id(A)` = −1 (loud dangling, not a stranger) |
| H4 | create→delete→create at same coords → **new** id (no reuse within session) |
| H5 | memory-undo round-trip: id still resolves after undo+redo |
| H6 | `rebuild_connectivity` split/merge semantics: surviving segment keeps its id; new segments get fresh ids (decision recorded by the test itself) |
| H7 | disk-undo round-trip — **expected XFAIL initially**, becomes the D3 decision |

**D2 (GREEN).** Implementation:

- `unsigned int id` field appended to `xWire` (memory-undo copies structs →
  H5 should pass with no undo code touched; verify `free_undo_wires` /
  restore paths copy the field).
- Monotonic `wire_id_counter` in `Xschem_ctx` (per tab/window context, like
  everything else in `xctx`).
- Stamp in `wire_store`; id→index map as an `Int_hashtable`
  (`xschem.h:1670` — the utility already exists), maintained in
  `wire_delete_compact` and rebuilt in `wire_bulk_end`.
- Two new `scheduler.c` branches for the query commands (+ entries in
  `xschem help`).

**D3 (decision point — bring to the user, do not pick unilaterally).**
Disk undo serializes through the `.sch` format, so ids do not round-trip.
Options:
  (a) write ids as an extra token into undo temp-files only (they round-trip
      through the existing token machinery, but must be stripped from
      user-visible saves — added complexity, format questions);
  (b) on disk-undo restore, invalidate all handles (rebuild map, bump all
      generations) — honest, simple, documented and *tested* as such (H7
      flips from XFAIL to PASS-with-invalidation-semantics);
  (c) step 1 ships with memory undo only fully supported, disk undo
      documented as handle-invalidating (same as b, framed as scope).
Recommendation to present: (b) — additive, reversible, no format risk.

## Phase E — close out

- E1. End-to-end probe added to `doc/claude/code_analysis/introspection_probes/`
  re-running the original §2e failure (`wire_coord 6` names a stranger
  after a delete) side-by-side with the handle version that doesn't.
- E2. Cross-reference notes: pointer from `tcl_introspection_wire.md` §5
  defect 7 to the new mechanism (the analysis doc itself stays as the
  historical record); FAQ entry if questions arose; update
  `doc/claude/specs/`-style checklist if the user wants one for this effort.
- E3. Decision menu for step 2, presented not pre-chosen: (a) instances
  next (worst remaining scatter), (b) coherence sweep using the funnel,
  (c) `xschem object` uniform read API on top of ids, (d) action-logging
  issue 0005 integration (log/replay by handle).

## Risks and their mitigations

| risk | mitigation |
| --- | --- |
| check.c sites are not semantically identical to storeobject | C2 treats each as its own commit-with-proof; CH4 goldens; field-by-field diff in the commit message |
| census misses a mutation site (e.g. a memmove in a rarely-built path) | census acceptance = grep-complete over `wires++/--/=` AND array writes; any site found later is a census bug fixed by funneling, never by special-casing |
| undo backends diverge on identity | both backends in CH3 from day one; H5/H7 separate them explicitly |
| id field changes struct size → hidden memcpy/sizeof assumptions | grep `sizeof(xWire)` and raw `memcpy` over wire arrays during census; the bulk channel covers the legitimate ones |
| WSLg display flakiness blocks GUI-driven tests | everything here drives `xschem` commands headlessly (no event-generate); same robustness class as the file-open suite |

## Commit cadence summary

A3 (harness+goldens) → B2 (census) → C1..C4 (funnel, suite green each) →
D1 (red tests) → D2 (green) → D3 (decision commit) → E1/E2 (probe+docs).
~10 commits, each independently revertable, suite green throughout
(XFAILs excepted, by name).
