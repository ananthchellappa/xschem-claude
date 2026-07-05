# Issue 0078 — `select_at` replay resolves to a different segment after a wire is split (coordinate-replay fidelity gap for wires)

**Opened:** 2026-07-05
**Status:** OPEN — known limitation, deferred follow-up. Explicitly a **non-goal** of the
wire-segment-splitting feature (`doc/claude/specs/wire_segment_splitting.md` §8, Hazard H8).
**Severity:** LOW — no crash, no netlist/connectivity effect; a fidelity gap in
action-log replay and any tooling that treats "one click = one net-run object".
**Class:** identity/replay — the same coordinate-vs-stable-handle gap as issue 0005, now
surfaced specifically for wires by in-memory segment splitting.
**Branch:** `fluid-editing`.
**Affects:** interactive click-select logging/replay (`xschem select_at x y`,
`scheduler.c:7742`) over wires, once wire-segment-splitting (ride `autotrim_wires`) is built.
**Depends on:** `doc/claude/specs/wire_segment_splitting.md` (the split is what creates the
new segment boundaries a recorded click can now land astride).

---

## 1. Problem

Interactive wire clicks are **logged and replayed by coordinate**: a click records
`xschem select_at <x> <y>` (`scheduler.c:7742`), and on replay `find_closest_wire`
(`findnet.c:28-52`) does an O(N) nearest-*segment* scan and selects whichever wire is
closest to that point. Wires get **no stable-name absorb** — only ELEMENT hits do (the
descend/`select_at` absorb of `doc/claude/specs/action_log_absorb.md` / issue 0005).

Wire-segment-splitting turns one long `xWire` into several short ones **in memory**. A
click recorded at a point mid-way along the *original* wire, replayed after the wire has
gained a split at that region, now resolves to whichever **short segment** is nearest — a
**different array index and different session `wire_id`** than at record time. A script that
did `select_at <mid-wire>` and then operated on "the wire" gets a sub-segment instead.

## 2. Why it is a real gap (and why it is not fixed by the splitting feature)

- Split segments each get a **fresh** `wire_id` (`store.c:403`) with **no recorded
  parent/segment relationship** — nothing links the pieces back to the wire the user drew.
- `trim_wires` rejoin keeps `wire[i]`'s id and drops `wire[j]` (`check.c:355-359`), and
  `wire_delete_compact` (`store.c:416`) reindexes survivors — so *which* id survives a
  split→edit→rejoin cycle depends on array scan order, not on which segment the user
  considers canonical.
- The splitting feature deliberately scopes this **out** (spec §8): it asserts on stable
  `wire_id` in tests and never claims coordinate-replay fidelity for wires.

So the split does not *cause* a new class of bug — it makes the pre-existing coordinate-
replay gap (issue 0005) observable for wires, where before a wire was a single object and a
mid-wire click always resolved to it.

## 3. Impact

- **Action-log replay:** a recorded `select_at` over a wire may select a different segment
  on replay if the schematic's segmentation changed between record and replay (e.g. a label
  added/removed, or replayed under a different `autotrim_wires` setting than recorded).
- **`xschem object` handles / cross-window ops** that cached a wire id before a split→rejoin
  cycle can dangle or point at an unexpected surviving segment.
- No effect on connectivity, netlist, save, or undo correctness.

## 4. Possible directions (not yet chosen)

- **Segment-parent recording:** stamp each split segment with the originating logical-wire
  id (a `parent_id` / group tag) so replay/handles can resolve to the whole run. Requires a
  new field and merge/split bookkeeping; interacts with save (D1 coalesce drops it).
- **Coordinate + span replay:** log wire selects as a coordinate *plus* the intended span,
  and on replay union the segments covering that span.
- **Logical-wire absorb:** extend the `action_log_absorb.md` holding-area idea from
  ELEMENT to WIRE, recording a stable descriptor instead of raw `select_at x y`.
- **Accept + document:** treat wires as coordinate-addressed and document that a recorded
  wire click resolves to the nearest segment under the current segmentation.

## 5. Related
- Issue **0005** — the original coordinate-vs-stable-handle `select_at` replay gap; wires
  were never given a stable-name absorb (only ELEMENTs were).
- `doc/claude/specs/wire_segment_splitting.md` — §8 non-goals, Hazard H8; the feature that
  makes this observable for wires.
- `doc/claude/specs/action_log_absorb.md` — the ELEMENT-side outcome-level absorb this
  would mirror.
- Session-stable `id` handles the segments already carry (just without parentage).
