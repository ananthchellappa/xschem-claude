# Issue 0005 — replayable click-select needs stable object referents (risky surgery, deferred)

**Opened:** 2026-06-11
**Status:** OPEN — DEFERRED by design. Captured so the constraint is not
rediscovered. Not scheduled; explicitly out of action-logging v1.
**Affects:** the replay fidelity of `Xschem.log` for any session that selects
objects by clicking; the larger goal of faithful full-session replay
**Branch:** `feature/action-logging`
**Spec basis:** `doc/claude/specs/action_logging.md` decision 4 ("object-reference gap
accepted for v1") and §6 ("future, not v1"). This issue is the detailed
*why it is hard*, so a future implementer sees the surgery before starting.

## Summary

The action log replays a session by re-running `xschem …` commands. **Pointer
click-select has no faithful Tcl form**, so today it is recorded only as a
non-replayable `#` marker (e.g. `# selected instance at <x> <y>`). Making it
genuinely replayable is not a thin wrapper — it requires giving every selectable
object a **stable identity that survives serialization and re-loading into a
fresh process**, which touches the object model and the file format. That is the
risky surgery this issue documents and defers.

## Why the obvious fix is not enough

It looks like a one-liner: "expose the existing hit-test as `xschem select_at x
y`." The hit-test is already there —

- `find_closest_obj(mx, my, override_lock)` (`src/findnet.c:506`) returns a
  `Selected {type, n, col}`, and
- it is *already* surfaced as `xschem closest_object` (`src/scheduler.c:636`).

So a coordinate-driven `select_at x y` is genuinely easy. **The hard part is the
return value.** `Selected.n` is an **array index** into `xctx->inst[]` /
`xctx->wire[]` / `xctx->rect[layer][]` / etc. That index is:

1. **Unstable within a session** — deleting or adding objects compacts/renumbers
   the arrays, so `n` denotes a different object after almost any edit.
2. **Not portable across a reload** — a fresh instance that `source`s the log
   builds its arrays in load order; index `k` there is not the index `k` that
   was clicked during recording.

So "select index 7, then move it" replays into "move whatever is at index 7
now," which is exactly the kind of silent divergence that makes a replay log
worse than no log.

## What a faithful fix actually requires

A **stable, serializable referent per selectable object** — an identity that the
recorder can capture and the replayer can resolve in a different process. The
difficulty is wildly uneven by object type:

| Object | Stable referent today? | Gap |
|---|---|---|
| Instance | Yes — `instname` (unique within a sheet) | usable as-is |
| Net / wire | Partial — net *name* exists, but a wire segment is not uniquely named | a name can map to many segments |
| Pin (symbol pin) | **No** | identified only by position within its symbol; no addressable id |
| Text | **No** | only its string + position; duplicates collide |
| Line / rect / poly / arc | **No** | purely positional/index identity, per layer |

Closing the gap for the "No" rows means **minting identities the format does not
currently carry** — either:

- (a) a persisted per-object id written into the `.sch`/`.sym` record (a
  **file-format change**: bumps `XSCHEM_FILE_VERSION`, touches `save.c` load and
  store, and must stay backward-compatible with the entire existing library),
  or
- (b) a deterministic content+position hash resolved at replay time (no format
  change, but fragile: two identical texts at the same point are
  indistinguishable, and any geometry edit upstream in the log invalidates
  later references).

Both are real surgery on load-bearing code (`save.c`, the object structs in
`xschem.h`, `select.c`, the spatial-hash hit-testing). Neither is appropriate to
attempt opportunistically alongside the logging feature.

## Why deferring is the right call

- The log is **already useful without it**: view/global actions (zoom, pan,
  scroll, colorscheme, netlist, load) replay faithfully today, and *area*-select
  is replayable now (`xschem select_inside x1 y1 x2 y2` already exists). The
  unreplayable case is specifically pointer click-select of an individual
  unnamed object.
- The `#`-marker (decision 4) keeps the session record honest — it says *what*
  and *where* without pretending to be replayable. A later `select_at` can
  upgrade those markers in place once a referent exists.
- The cost/benefit is poor right now: file-format surgery for the niche of
  exact click-select replay, versus shipping a log that covers the common
  actions.

## Blast radius if attempted (for the future implementer)

- `xschem.h` — new field on `xInstance`/`xRect`/`xLine`/`xPoly`/`xArc`/`xText`
  for option (a).
- `save.c` — store/load of the new field; `XSCHEM_FILE_VERSION` bump;
  back-compat path for files without the id.
- `select.c` / `findnet.c` — a `select_at`/`select_obj <ref>` entry point and
  the ref→object resolver.
- `scheduler.c` — the new subcommand(s).
- The whole `xschem_library/` corpus must still load and round-trip unchanged.

## Dependent goal (also deferred)

**Faithful full-session replay** (spec §6 — the causal chain of selections,
`descend`/`go_back`, `load`) is blocked on this: you cannot replay "select this,
descend into it, edit, go back" without a stable referent for "this." Once 0005
is solved, that becomes a sequencing/design problem rather than an
object-identity one. Tracked here as the motivation, not separately, until 0005
moves.

## Acceptance (whenever it is undertaken)

- A recorded click-select of each object type replays into a *fresh* instance
  and selects the same object (the row-50 acceptance smoke, extended).
- Existing library files load unchanged (no format regression).
- The `#`-marker path remains for anything still unaddressable, so the log is
  never silently wrong.
