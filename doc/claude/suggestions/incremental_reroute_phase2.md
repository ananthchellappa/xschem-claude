# Session prompt: Phase II — incremental per-snap-step reroute (timing, not algorithm)

Branch `fluid-editing`. Feature: **incremental, tool-owned wire re-routing (decoupled from
selection)** — spec `doc/claude/specs/incremental_wire_reroute.md`. Read that spec (esp. §4, §5,
§8) and the memory `nice-drag-rerouting.md` first; they carry the full history and gotchas.

## State you're inheriting (all pushed: github/fluid-editing @ `3995ca45`)

- **Phases 0–3** of the older `nice_drag_rerouting.md` are done: golden predicate harness
  (`tests/headless/wireedit/`, `p1..p7`), runtime P1/P2 guards, `get_pin_escape_normal()`, the
  fluid exit-stub escape.
- **Phase I** (this pivot) is done + committed (`a78beeb2`): **ownership decoupling**. The wires
  the tool auto-grabs to follow a moving selection are no longer left in the user's persistent
  selection. Mechanism: `select_attached_nets()` (select.c) snapshots the user's own selected-wire
  count `xctx->fluid_startsel_wires` at its TOP (counting any `sel!=0`, before it grabs any
  follow-wire); `move_objects(END)` (move.c), gated on `fluid_editing`, deselects all wires when
  that count is 0 (they're all tool-owned). Route byte-identical; Phase I is bookkeeping only.
- A pre-existing crash was fixed en route (`dce0bea6`): `update_symbol_bboxes()` used a stale
  `xctx->movelastsel` at move START → `symbol_bbox` heap-overflow. Don't reintroduce.
- **Tooling:** gdb 15.1 + valgrind 3.22 installed. Memcheck gate:
  `sh tests/headless/wireedit/run_wireedit.sh --memcheck` (valgrind per test, fail on rc==99).
  The move/reroute code is heap-churny — run this gate for Phase II.

## What Phase II is (spec §5 Design B, §8 Phase II)

Today the reroute of the follow-wires happens **once, at `move_objects(END)`** (release):
`place_moved_wire`, `compute_wire_slide`, `trim_wires`/`maintain_wire_segments`,
`remove_move_orphan_wires`, `insert_exit_stubs`. During the drag (`RUBBER`) only a rubber-band
preview is drawn — the user sees the final route only after committing.

**Phase II makes the reroute run incrementally, per snap-grid step, during the drag** — in
`move_objects(RUBBER)`, behind a guard "the selection moved by ≥ one `cadsnap` since the last
reroute." **Timing only — do NOT change the routing algorithm** (that's Phase III). The route the
user sees while dragging becomes live, and the committed result on release must equal what the
current END path produces.

Gate everything on `fluid_editing` (default off ⇒ the whole incremental path is skipped ⇒
`RUBBER` still just previews ⇒ byte-identical to today).

## The key design decision (resolve first, state why)

Running the END transforms N times incrementally is **not** obviously equal to running them once —
`trim_wires`/merge/`insert_exit_stubs` are stateful and could drift with accumulation. Two shapes:

1. **Restore-and-reapply (recommended).** Snapshot the full pre-move geometry of `S` + `F` at
   START. Each qualifying `RUBBER` step: restore to that snapshot, apply the **current total**
   delta, run the (unchanged) reroute fresh. Each step is an idempotent from-scratch reroute at the
   current cursor position → trivially matches the END result (END is just the last step). Needs a
   real snapshot/restore of the affected wires (this is where the spec's explicit follow-set `F` +
   terminal state, deferred in Phase I §10.1, likely gets built).
2. **Accumulate mutations.** Apply each step's incremental delta to live geometry and re-run the
   reroute on it. Cheaper per step but must prove no drift vs END — likely fragile.

Pick one, justify it. (1) is the safe correctness path and lands the `F`/snapshot infrastructure
Phase III/IV will consume anyway.

## Constraints / invariants (do not break)

- **One undo per gesture.** Incremental commits must still be a single undo push at START / one
  restore-point — not N undo entries. Check `push_undo`/`pop_undo` interaction with per-step commit.
- **Release == stepwise (acceptance).** The committed `.sch` after a live incremental drag must be
  byte-identical to the same drag committed only at END (today's path). This is the headline test.
- **P1 connectivity + P2 no-short** unchanged from today (Phase II doesn't fix the R18 short — the
  algorithm is untouched; Phase III does). Don't regress them.
- **Byte-identical when `fluid_editing` off.** Golden harness is authoritative.
- **Determinism (P8):** the per-step reroute must be a pure function of (snapshot, total delta,
  obstacles) — no hash-order dependence.
- **Memory-clean:** per-step wire mutation is exactly where corruption hides — run `--memcheck`.

## Where the code is (move.c, HEAD 3995ca45)

- `move_objects()` — START ~L1811 (snapshot hooks: `fluid_snapshot_partition`, and Phase-I count
  lives in `select_attached_nets`), RUBBER ~L1868 (today: just `draw_selection` + accumulate
  `deltax/deltay`), END ~L1889 (the reroute + `fluid_check_move_invariants` + the Phase-I deselect).
- Reroute pieces: `place_moved_wire` ~L1087, `compute_wire_slide` ~L1329, `insert_exit_stubs`
  ~L1565, `order_wire_coords` ~L1555, END cleanup ~L2264 (`maintain_wire_segments`/`trim_wires`/
  `remove_move_orphan_wires`), exit-stub gate ~L2282.
- `select_attached_nets` (select.c ~L1504) discovers terminals (ELEMENT + WIRE branches) — reuse
  for building `F`.
- `rebuild_selected_array` move.c:52 ("new selected set can't be larger" precondition).

## Task (RED-first, one commit, sabotage-verified)

1. **RED-first test** `tests/headless/wireedit/test_wireedit_3?_incremental_step.tcl`: drive the R18
   fixture (or a small 2-pin case) BOTH via one END commit AND via a sequence of one-`cadsnap`
   `RUBBER` steps + END, assert the resulting `segset` is identical. RED if you wire the stepping
   before it converges; GREEN when release==stepwise. Add a gated-off byte-identical case + a
   non-fluid control.
2. **Implement** the per-step reroute in `move_objects(RUBBER)` per your chosen shape, gated on
   `fluid_editing`. Keep the algorithm identical to today's END path.
3. **Verify:** whole wireedit suite (33+), `test_wire_split` + `test_fluid_editing` `OVERALL: ok`,
   AND `run_wireedit.sh --memcheck` clean.
4. **Adversarial review** (workflow): undo integrity (one entry), snapshot/restore memory-safety,
   drift (release==stepwise) under buses/kissing/multi-instance, byte-identical when off.

## Test / discipline notes (carried through)

- `we_move_stretch dx dy` == `xschem move_objects dx dy stretch kissing` == interactive drag
  release. For incremental, you'll drive `move_objects(START)` then repeated `RUBBER` (set
  `mousex_snap/mousey_snap` or the delta) then `END` — check how the scheduler exposes RUBBER
  stepping, or add a headless `xschem move_objects ... step` seam if needed (new subcommand ⇒
  matching-first-letter `xschem_cmds_m` in scheduler.c, or it's unreachable).
- Net readback uses `xschem resolved_net 0` (the `0`); `segset`/`we_norm` for geometry compare.
- Run headless from repo root: `env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <t>`.
- Valgrind gotcha: `env -u DISPLAY valgrind … ./src/xschem …` (env is the OUTER wrapper; never
  `valgrind env …` — it traces `env` and escapes the exec). ASan build recipe + this are in the
  `xschem-pipe-script-test-gotchas` memory.
- Gate on `fluid_editing`; default off must stay byte-identical.

## Acceptance

- Live incremental drag under `fluid_editing`; committed `.sch` byte-identical to the END-only
  path (release==stepwise). One undo entry per gesture. P1/P2 unchanged. Default-off byte-identical.
- Whole wireedit suite + wire_split + fluid_editing green; `run_wireedit.sh --memcheck` clean.
- Adversarially reviewed. `F`/snapshot infrastructure (if built) documented for Phase III.

## Explicitly NOT Phase II

- Changing the routing algorithm / fixing the R18 ammeter short (that's **Phase III**: obstacle-aware
  local update + stop-short/solder-joint, spec §5/§6).
- The beautifier rules (P3 escape, min-bend, junction dots) — Phase IV.
