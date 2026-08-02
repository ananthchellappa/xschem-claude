# 0205 — the read-only coordinate probes still honour `lock`, and a lock only gates edits

Status: **OPEN**. Filed 2026-08-01 out of [0204](0204-sod-pick-mutates-the-selection.md),
which established the probes and deliberately declined to make this change in the same
commit. Measured, not reasoned: sabotage S3 below.
Area: `src/scheduler.c` — `object_at` (`xschem_cmds_o`), `net_name_at` (`xschem_cmds_n`).
Tests: `tests/headless/test_ase_locked_wire_pick_0160.tcl` LK11 is the leg that moves.
Related: [0160](0160-ase-locked-wire-unpickable.md) (where "selection IS the lock" was
argued, and where the read-only-probe idea was applied to one path only),
[0200](0200-descend-has-no-verb-noun-pick.md) (`instance_at`, which already uses
`override_lock=1`), [0204](0204-sod-pick-mutates-the-selection.md).
Specs: `doc/claude/specs/select_at.md`.

## The inconsistency

Three read-only coordinate probes now exist. They do not agree about `lock`:

| probe | `override_lock` | why |
|---|---|---|
| `instance_at x y` (0200) | **1** | "Locked instances are reported (selection is the lock; a probe that never selects cannot make one editable)" |
| `object_at x y` (0204) | **0** | parity with `select_at`, so 0204 changed nothing but the mutation |
| `net_name_at x y` (0204) | **0** | same |
| `net_name_at -wire n` (0204) | **n/a** | never runs `find_closest_obj`, so no lock filter applies at all — it already behaves as if `override_lock=1` |

That last row is the tell: the same command already answers differently about a locked wire
depending on which form you call, and nobody had to decide that — it fell out of where the
lock check happens.

`instance_at` has the principle right. For the object types that matter here, `lock` is
enforced in the two hit-test/selection files — `select.c`
(`select_wire/_element/_text/_box/_arc/_line/_polygon`) and `findnet.c` (the
`find_closest_*` testers) — and there is no lock check in `move.c`, `actions.c` or any
delete path, because every edit acts on the **selection**. (`callback.c:144` also honours
`lock`, but on GRIDLAYER graph rects, to make a locked graph non-interactive without Ctrl —
a different mechanism, not part of this argument. The "exactly two files" phrasing in
`ase_window.tcl`'s comment and in 0160 is about the selection path and is imprecise as a
global claim.)

That is the whole content of "selection IS the lock": making a locked object *selectable*
would make it deletable. A verb that returns a row and selects nothing cannot make anything
editable, so there is no reason for it to pretend a locked object is not there.

0204 kept `override_lock=0` anyway, on purpose: it was a refactor of *how* the ASE pick
classifies, and this is a change to *what* it classifies.

## What actually changes, measured

Sabotage S3 in 0204: flip `object_at` to `override_lock=1`, rebuild, run under the gate.

```
FAIL: LK11 a LOCKED voltage source still queues nothing -> {i(v9)} (exp {})
```

So today a `lock=true` voltage source is silently unpickable in Ctrl-4 mode — the click
falls through to the v1-scope notice or to nothing. With `override_lock=1` it queues its
current like any other source. Same for a locked **unnamed** wire, which currently resolves
to nothing at all: `flylines at` hits it (it already uses `override_lock=1`) but rule A6
kills the `#` name, and `net_name_at`'s `override_lock=0` pick then refuses it. A locked
*named* wire already works, through `flylines at` — which is exactly the asymmetry 0160
left behind and 0204 declined to widen.

LK11's own comment says it was "pinned rather than reasoned", so it is a pin, not a
contract.

## The decision to take

Not "is `override_lock=1` correct" — it is. The question is whether a user who locks a
device expects it to stay pickable for *measurement*. The lock exists so a click cannot
move or delete the thing; probing a locked device's current is exactly the case where a
lock should be invisible.

If yes:
1. `object_at` and `net_name_at` take `override_lock=1`, matching `instance_at`.
2. LK11 is rewritten to require the locked vsource to queue `i(v9)`, with the reason.
3. Add a leg for the locked **unnamed** wire, which has never resolved and would start to.
4. `select_at` is NOT touched — LK2 ("select_at STILL refuses a locked wire") stays green,
   and must, or the lock stops being a lock.

Alternative, if the locked-device pick turns out to be wanted per-call: give both probes an
optional trailing `lock` / `nolock` word, defaulting to today's behaviour. More surface, and
probably not worth it — nothing has asked for the choice.

## Cross-references

* `doc/claude/specs/select_at.md` — the read-only-twin table and the current `override_lock`
  values.
* `doc/claude/issues/0160-ase-locked-wire-unpickable.md` — "selection IS the lock".
* `doc/claude/issues/0204-sod-pick-mutates-the-selection.md` — the sabotage table this
  measurement comes from.
