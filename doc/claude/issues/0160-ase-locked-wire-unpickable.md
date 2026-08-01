# 0160 — a `lock=true` wire was unpickable from ASE, silently

Status: **FIXED** (2026-07-26)
Area: `src/ase_window.tcl` (`sod_click`)
Tests: `tests/headless/test_ase_locked_wire_pick_0160.tcl` — `LK1`-`LK12` (16 checks, new file)
Spec: `doc/claude/specs/ase_l.md`, "Select On Design v1 scope"
Related: 0154 (the audit that surfaced it — "Not fixed" item 7), 0159 (the bus dialog, same proc),
0153 (the schematic colour cue)

## Report

From the 0154 backlog:

> **A `lock=true` wire is unpickable, silently.** `select_at` picks with `override_lock=0` while
> `flylines at` uses `1`, so `sod_click`'s `if {$hit eq {}} { return }` fires before any
> classification — not even the notice.

Reproduced at 666f7f26 in both arms, on a locked wire carrying an ordinary named net:

```
xschem select_at 100 0        ->  {}          (nothing)
xschem flylines at 100 0      ->  net LOCKED  (resolves fine)
ase::ui::sod_net_at 100 0 {}  ->  LOCKED
```

Only the **select** step objected. The resolver never had a problem: `xschem flylines at` calls
`find_closest_obj(mx, my, 1)` (`scheduler.c:3535`), while `xschem select_at` calls
`select_object(x, y, SELECTED, 0, NULL)` (`scheduler.c:9699`). The click then died on
`sod_click`'s opening `if {$hit eq {}} { return }`, so the user got no queue, no highlight and no
message — the failure mode the report calls out.

## Why the fix is NOT "override the lock"

The user's instinct in the backlog was that a read-only pick should ignore the lock. That is right
about *reading* and wrong about *how to get there*, because of where the lock actually lives.

`lock` is enforced in exactly two files:

- `src/select.c` — `select_wire` (`:1183`), `select_element` (`:1300`), `select_text` (`:1404`),
  `select_box` (`:1447`), `select_polygon` (`:1524`), `select_line` (`:1555`). Each is the same
  shape: `if(lock=="true" && select_mode == SELECTED && !override_lock) return;`
- `src/findnet.c` — the hit-testers `find_closest_wire` (`:47`), `_polygon` (`:160`), `_line`
  (`:191`), `_arc` (`:390`), `_box` (`:446`), `_element` (`:471`), `_text` (`:519`), and
  `find_closest_pin` (`:565`).

There is **no lock check in `move.c`, `actions.c`, or any delete path** — every edit operates on
the selection. So *selection is the lock*: make a locked wire selectable and you have made it
movable and deletable. Passing `override_lock=1` from `select_at`, or exposing an override switch
on the verb, would have quietly disarmed the feature the user asked for.

A read-only probe does not need the selection at all — it only used `select_at` as a hit-test and
as the Cadence-style click feedback. So the fix resolves the net **without selecting**:

```diff
   set hit [xschem select_at $x $y]
-  if {$hit eq {}} { return }
   set kind {}
```

and the empty-hit return moves to the bottom, inside the "classified as nothing" arm:

```tcl
   if {$kind eq {}} {
+    if {$hit eq {}} { return }        ;# empty canvas: silent, exactly as before
     catch {ciw_echo "ase: v1 queues source currents only — …"}
     return
   }
```

An empty hit now gets its chance at classification (`sod_net_at` → `xschem flylines at`, which
already ignored the lock), and only ends the click if that also finds nothing. A miss-click on
empty canvas therefore stays **silent**, as it always was — a pick mode that scolded every stray
click would be noise.

### The lock is already not airtight

Worth recording, because it bounds how much this decision is really protecting: `callback.c:7394`
already selects with `override_lock=1` on a **double-click**, with the comment *"Following 5 lines
do again a selection overriding lock, so locked instance attrs can be edited"*. So a sanctioned
override path exists. The fix here deliberately does not widen it.

## What the user sees now

A locked wire's net queues normally. The 0153 colour cue still paints: `hilight_netname` lives in
`hilight.c` and does not consult `lock` (verified — `xschem hilight_netname LOCKED` returns 1 on
the locked fixture). What is still missing is the *selection* highlight, which is correct by
definition — the object is locked. Judgement call: no extra "this wire is locked" notice is
printed, because the pick now succeeds and already reports `ase: queued output …`; a second line
on every locked pick would be noise. Say so if you want it.

## Test

`tests/headless/test_ase_locked_wire_pick_0160.tcl`, 16 checks, teeth in both arms. Fixture in
`test_scratch`: a locked wire (`LOCKED`), an unlocked one (`FREE`), a locked **bus** wire
(`B[1:0]`), a non-source instance (`R9`) and a locked + an unlocked voltage source, with
`dp_queue`/`sod_queue`/`bus_dialog` stubbed so no ASE session is needed, and `ciw_echo` stubbed so notices are observable.

- `LK1`-`LK3` — fixture witness plus the two engine invariants the fix must **not** move:
  `select_at` still refuses a locked wire, `flylines at` still resolves it.
- `LK4`-`LK6` — the fix: the locked wire queues on both pick modes, and afterwards is **still not
  selected**.
- `LK7`-`LK9` — controls: an unlocked wire still queues *and* selects; an empty-canvas click still
  queues nothing *and says nothing*; the locked net still takes a highlight.
- `LK8c`-`LK8d` — a non-source instance body still queues nothing but **does** get the v1-scope
  notice, so the late return cannot swallow it.
- `LK11`-`LK12` — a **locked voltage source** still queues nothing (`find_closest_element`
  excludes it, so nothing resolves at its body), while an unlocked one still queues its current.
- `LK10` — interaction with 0159: a locked **bus** wire still goes through the bit dialog.

### Verified

- RED first: `LK4`/`LK5`/`LK10` fail before the change; **16/16** after, in both the `--nogui` and
  the `--pipe`+`DISPLAY=:0` arm.
- Three sabotages, each red on a different leg group:
  1. restore the early return → `LK4`/`LK5`/`LK10` red;
  2. drop the late empty-hit return → `LK8b` red (a miss-click scolds);
  3. **the wrong fix** — change `select_at`'s C call to `select_object(..., SELECTED, 1, NULL)`,
     rebuild → `LK2` and `LK6` red (the wire becomes selected). The test actively rejects
     overriding the lock, which is the whole point of the design decision above.
- Green after the change: `test_ase_interact` (63), `test_ase_bus_bits_0159` (39), `test_ase_plot`
  (145), `test_ase_window` (166), `test_ase_dialogs` (133), `test_ase_persist` (109),
  `test_ase_unnamed_net` (28), `test_wave_viewer` (292), `test_wave_modes` (174), `test_ase_core`
  (66), `test_ase_final` (28), `test_ase_final_gf180` (33).

### NOT verified

- Not eyeballed: the behavior was driven programmatically, not by clicking a locked wire in a real
  session.
- No `full_audit.sh` sweep for this change.
