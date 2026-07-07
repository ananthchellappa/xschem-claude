# Session prompt: Phase III — obstacle-aware local update + stop-short (lands the R18 no-short)

Branch `fluid-editing`. Feature: **incremental, tool-owned wire re-routing (decoupled from
selection)** — spec `doc/claude/specs/incremental_wire_reroute.md`. Read that spec (esp. §4, §5, §6,
§9) and the memory `nice-drag-rerouting.md` first; they carry the full history, predicates, and
gotchas. This is the phase that finally **fixes the short** — the algorithm change, not timing.

## State you're inheriting (all pushed: github/fluid-editing @ `51ab5298`)

- **Phases 0–3 of the older `nice_drag_rerouting.md`** are done: golden predicate harness
  (`tests/headless/wireedit/`, `predicates.tcl` p1..p7 + `pin_escape_normal`), runtime P1/P2 guards
  (`fluid_check_move_invariants`, log-only), `get_pin_escape_normal()` (C, geometry nearest-edge),
  the exit-stub escape.
- **Phase I (ownership decouple)** `a78beeb2` + crash fix `dce0bea6`.
- **Phase II (incremental per-snap-step reroute — TIMING)** `51ab5298`. The follow-wire reroute now
  runs **live, once per `cadsnap` step** in `move_objects(RUBBER)`, via **restore-and-reapply the
  total delta**: at a fluid stretch move START the whole pristine schematic is snapshotted into a
  scratch `Undo_slot xctx->fluid_reroute_snap` (`mem_serialize_slot`); each RUBBER step restores it
  and re-applies the current total delta through the **shared END commit block** (reached from RUBBER
  via a local `commit_now` flag that gates out the END-only finalizers). The committed route on
  release is byte-identical to the release-only path. The routing ALGORITHM was left byte-for-byte
  identical to the old END path — **Phase II deliberately did NOT fix the short.** Decision record:
  `doc/claude/suggestions/incremental_reroute_phase2_decision.md`.
- **The `F`/snapshot infrastructure Phase III needs is now built** (the per-step restore point +
  `commit_move_geometry()` re-entry). Phase III replaces the per-step reroute *decision*, not the
  timing scaffolding.
- **Tooling:** gdb 15.1 + valgrind 3.22. Memcheck gate:
  `sh tests/headless/wireedit/run_wireedit.sh --memcheck` (fail on rc==99). Run it per phase — the
  per-step wire mutation is heap-churny.
- **Headless drag seam:** `xschem move_objects start <ax> <ay> [kissing] [stretch]` /
  `... step <x> <y>` / `... end [dx dy]` / `... abort` drives a drag one snap at a time (scheduler.c
  `xschem_cmds_m`). `xschem move_objects <dx> <dy> stretch kissing` is the one-shot release path.

## The failing case Phase III must fix (spec §2 — the acceptance)

Files `tests/from_user/{before,after,beautified}.sch`. Launch the user uses:
`src/xschem --script src/cadence_style_rc` (so `cadence_compat=1`, `fluid_editing=1`,
`orthogonal_wiring=1`, and `cadence_compat` forces `autotrim_wires=1`).

- **before.sch:** ammeter `v8` pins `plus`=(-390,140), `minus`=(-330,140) (body spans x∈[-390,-330]
  at y=140). `#net1` = R18 pin `M`(-420,-80) → vertical riser up to the y=140 bus → left to x=-550,
  and right to `v8.plus`(-390,140). `OUT` = `v8.minus`(-330,140) → opin at (-270,140).
- **The move:** R18 dragged SE (-420,-110)→(-310,10), Δ=(+110,+120). R18's own pins land clean.
- **The bug (current binary):** R18's M-pin riser redraw lays its horizontal leg along y=140 and
  `trim_wires` merges it into `N -550 140 -310 140` — a wire running **straight through v8** (past
  both -390 and -330) → `v8.plus` and `v8.minus` become the **same** wire → ammeter shorted →
  `#net1` merges into `OUT`. **Reproduced in EVERY gate combo incl. fully default** → it's the
  **base stretch-follow** (`place_moved_wire` manhattan jog + `trim_wires`), obstacle-blind.
- **beautified.sch (ACCEPTABLE target — style, not byte-golden):** riser at **x=-410**, rises to
  y=140, reaches `v8.plus` via a short horizontal `N -410 140 -390 140`. **Stops at -390, never
  continues to -330** → v8 not shorted. Corner is a **visible T-junction at (-410,140)**, offset
  from the pin.

## What Phase III is (spec §5 step 2–3, §6)

Replace the per-step **jog** with an **obstacle-aware local update**: for each terminal + follow-wire,
apply the smallest edit toward the terminal's new position that keeps the route Manhattan AND obeys
the invariants, consulting obstacles (device bboxes, foreign-net pins). The headline rule:

- **Stop-short + visible junction ("solder joint").** When a moving leg would advance to sit
  *exactly on* a foreign object's connection point (the riser sweeping right onto `v8.plus`), **stop
  one grid short** and connect via a short explicit segment, leaving a **visible** T-junction —
  never continue past onto/through the device. This IS the no-short mechanism.
- **No device-body / foreign-pin crossing (P5):** a leg may not pass through an instance bbox
  interior or run across a device between its two pins.

Do this **inside the per-step commit** (`commit_move_geometry` / the reroute helpers in move.c), so
it runs incrementally — each one-grid step is a small, unambiguous local decision, never a global
solve. Keep P8 determinism (pure fn of snapshot + total delta + obstacles). Gate on `fluid_editing`
(default off ⇒ byte-identical). Keep the Phase II invariants: **release == stepwise**, one undo,
memcheck-clean.

## The general P2 detector you must build first (spec §9)

The current `p2_no_short` / `fluid_check_move_invariants` are **label-centric and MISS this short**
(no net labels — it's a device short across v8). Build a **device-pin-merge** predicate: no instance
**outside** the selection may have two pins that were on **distinct** nets pre-move end up on **one**
net post-move (v8 is exactly such an instance). More generally: no two pre-move-distinct nets may
merge unless the user's own geometry caused it. Add it to `predicates.tcl` with sabotage teeth, and
wire it into the runtime guard so the R18 short is *detectable* before you fix it.

## Task (RED-first, one commit, sabotage-verified)

1. **General P2 detector** (`predicates.tcl` device-pin-merge + runtime), with teeth.
2. **RED fixture** `tests/headless/wireedit/test_wireedit_3?_r18_no_short.tcl`: load `before.sch`
   (or an in-memory reduction), drive the R18 move BOTH stepwise and via release, assert **P2**
   (v8.plus ≠ v8.minus net) and **P1** (net partition preserved). RED against `51ab5298` (ships the
   short); GREEN after Phase III. Also assert the beautified *style* (riser offset from the pin,
   stops short of -330) without pinning exact coords.
3. **Implement** the obstacle-aware local update + stop-short/visible-junction inside the per-step
   reroute, gated on `fluid_editing`, keeping the algorithm a pure fn of (snapshot, delta, obstacles).
4. **Verify:** whole wireedit suite + `test_wire_split` + `test_fluid_editing` `OVERALL: ok`;
   `run_wireedit.sh --memcheck` clean; **release == stepwise still holds** (Phase II's test_33
   byte-compare must stay green); `tests/from_user` R18 fixture is the headline acceptance.
5. **Adversarial review** (workflow): P2 across buses/multi-pin/kissing/multi-instance; stop-short
   granularity (§10.4: always one grid vs nearest clear line; pin dragged *past* the obstacle);
   determinism; default-off byte-identical; memory-safety.

## Constraints / invariants (do not break)

- **P1 connectivity + P2 no-short are HARD** (spec §6). Conflict order `P1=P2 > P3 > P5 > P4 > P7 > P6`.
- **Release == stepwise** (Phase II acceptance) must survive the algorithm change — the per-step
  decision must be deterministic so N steps + END equal one release.
- **One undo per gesture. Byte-identical when `fluid_editing` off.** Golden harness authoritative.
- **Memory-clean** — run `--memcheck`.

## Where the code is (move.c @ `51ab5298`)

- `commit_move_geometry()` — the shared per-step geometry commit (reached by both END and a RUBBER
  `commit_now` step). Reroute pieces inside: `compute_wire_slide` (~1330), `place_moved_wire` (the
  manhattan jog that lays the shorting leg, ~1088), `trim_wires`/`maintain_wire_segments`,
  `remove_move_orphan_wires` (~1456), `insert_exit_stubs` (~1566), `order_wire_coords` (~1556).
- `get_pin_escape_normal(i, r, &nx, &ny)` — pin outward normal (reuse for escape/stop-short dir).
- Obstacles: `symbol_bbox`/`instance_bbox` for device bodies; `get_inst_pin_coord` /
  foreign-net pin coords for stop-short targets. `touch()` (clip.c) point-on-seg (coordinate-ordered
  precondition — `order_wire_coords` normalizes).
- Predicate reuse: `predicates.tcl` p5 (`seg_in_rect_interior` body-cross), `pin_escape_normal`,
  `pred_verdict`. Net readback: `xschem resolved_net 0` (the `0`); `segset`/`we_norm` geometry compare.
- Headless from repo root: `env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <t>`.
  Valgrind: `env -u DISPLAY valgrind … ./src/xschem …` (env is the OUTER wrapper).

## Explicitly NOT Phase III

- The beautifier polish beyond stop-short (min-bend, escape-perp lane packing, junction-dot
  rendering) — **Phase IV** (spec §8).
- Cleanup/stability/determinism reconciliation with `merge_collinear_wires` — **Phase V**.

## Acceptance

- R18 fixture: after the drag (stepwise AND release), `v8.plus` ≠ `v8.minus` net (P2), net partition
  preserved (P1), riser offset from the pin and stopping short of -330 (beautified style). General
  device-pin-merge P2 detector added with teeth. Whole wireedit suite + wire_split + fluid_editing
  green; `run_wireedit.sh --memcheck` clean; release==stepwise (test_33) still green. Adversarially
  reviewed.
