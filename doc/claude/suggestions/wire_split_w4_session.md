# Session prompt — Wire segment splitting, W4 (coalesce-on-save), ahead of W3

Paste the block below into a fresh session (after `/clear`). Self-contained.

---

Build **W4 (coalesce-on-save)** of the wire-segment-splitting feature, RED-first. Do W4
**before** W3, on purpose (see "Why W4 first").

## Read first
- Spec + plan: `doc/claude/specs/wire_segment_splitting.md` — read the top **Built**
  section, decisions **D1/D2** (§3), **INV-1** (§4), **§6.3 (coalesce-on-save)**, the
  **§9 plan (W4 row)**, and the **Hazards** (H5, H7).
- Auto-memory `wire-segment-splitting` should already be loaded; it has the commit list.
- Issue `doc/claude/issues/0078-*` is the deferred `select_at`-replay follow-up (not W4).

## State (branch `fluid-editing`, all committed)
`b5d4bc13` W0 pin-aware `trim_wires` merge · `1cbd05bb` W1 read-time split
(`break_wires_at_attach_points` + `maintain_wire_segments`, load hook in `save.c`) ·
`5d3fd388` W2 connectivity-invariance test · `0992065a` review fixes (D2 gate etc.) ·
`1e22d97b` stale-hash fix. Test: `tests/headless/test_wire_split.tcl` (17 checks, in
`run_regression.tcl` hcases).

## Why W4 first (the bug it closes)
W1 splits each wire at its interior attachment points **in memory** on load, gated on
`autotrim_wires` (which `cadence_compat` force-sets). But **coalesce-on-save is not built**,
and `save_wire` (`src/save.c:2651`) writes one `N` record per `wire[]` entry with no
coalesce. So for an autotrim/cadence user, opening a mid-span-tapped single-wire cell and
saving rewrites `1 N record → N` — the `.sch` loses byte-stability, git churns, props
triplicate (violates **D1**). Default users (`autotrim_wires` off) are unaffected. W3
(edit-time split) only widens this exposure, so close it first.

## Goal (D1)
On save, the on-disk `.sch` must be the **minimal coalesced form** — collinear, same-`prop_ptr`,
pin-free abutting runs re-joined — so a file authored as one `N` round-trips as one `N`,
byte-identical to today. The **in-memory** segmented `wire[]` must be **untouched** by save
(the user keeps clickable segments after saving). Connectivity/netlist must stay invariant
(**INV-1**). Gate strictly on `autotrim_wires`: with it **off**, save is verbatim (today's
behaviour exactly — do not merge a default user's deliberately-abutting wires).

## Design (recommended)
1. Factor the collinear-merge core out of `trim_wires` (`src/check.c` merge loop, ~lines
   360-392) into a reusable `merge_collinear_wires(list, n, ignore_pins)` operating on a
   **passed array**, so:
   - `trim_wires` uses it with `ignore_pins = 0` (keeps today's pin-aware behaviour, W0).
   - the save path uses it with `ignore_pins = 1` (**pin-blind** — coalesce across every
     collinear same-prop abutting run, since the split is a pure UX concern with no
     connectivity meaning).
   - Only ever merge segments whose `prop_ptr` are **identical** (divergent `bus=`/`lab=`/
     `*_ignore=` persist as separate records — a real difference, Hazard H7).
2. Coalesce on a **scratch copy** of the wire list at save time, emit the coalesced records,
   discard the scratch. **Do not mutate `xctx->wire[]`.** Gate on `tclgetboolvar("autotrim_wires")`.
   - Hook point: `save_wire` (`src/save.c:2651-2664`). Watch the **second** WIRE emitter in
     the generic per-object save switch (~`src/save.c:5763`) — keep both consistent, or route
     both through the coalescing helper. (Scratch-copy avoids disturbing live state; a
     mutate-in-place-then-re-split fallback exists but is heavier and must restore + rebuild
     hashes — prefer scratch-copy.)

## RED-first tests (append a W4 section to `tests/headless/test_wire_split.tcl`)
Use the existing harness (`check`/`bail`/`OVERALL: ok`, `write_sch`, `$wdir`). Assert on
`^N ` record counts via `xschem saveas $tmp schematic` then reading the file.
- **T6 (RED anchor):** autotrim on; build the res+label fixture (1 wire, mid-span label+pin);
  `xschem saveas $tmp`; grep `^N ` → **1** record whose coords/prop equal the original;
  reload `$tmp` → **re-splits to 3** segments (round-trip). Fails today (saves 3 `N`).
- **T7:** autotrim **off**; load fixture → `get wires == 1`; saveas → `.sch` **byte-identical**
  to input (default verbatim). Guards the D2 no-op path.
- **T6b (prop-aware):** diverge one segment's prop (e.g. add `bus=` to the middle segment via
  `xschem` API), saveas → that boundary **persists** (2 records, not 1). Proves prop-aware
  coalesce.
- **Round-trip INV-1:** reuse the W2 `instance_nodemap R7` check across load→save→reload —
  must stay byte-identical.
- Sabotage-verify each (revert the coalesce → count flips), per green-but-hollow discipline.

## Gotchas / invariants (from the xhigh review)
- Never mutate the live `wire[]` on save; users keep their segments.
- Merge only across **identical** `prop_ptr`; never silently drop a segment's attributes.
- Gate on `autotrim_wires`; keep default-mode save byte-for-byte unchanged.
- Idempotent: load→save→load→save must be stable.
- `#netN` numbering: netlist regressions run default-mode (split off) so goldens are safe;
  still assert netlist invariance across the round-trip.
- If you ever coalesce in-place, you MUST re-split (`maintain_wire_segments`) and set
  `prep_hash_wires=0` after, and rebuild — scratch-copy sidesteps all of this.

## Build / run / verify (environment)
- Build: `make -C src` (from repo root `/home/qflow/dev/xschem/claude_1/xschem`). Expect
  zero warnings.
- Run a headless test **directly** (do NOT trust `run_regression.tcl` here — it uses a bare
  `xschem` on PATH which is absent, and the golden dirs have no baseline):
  `./src/xschem --nogui --pipe -q --script tests/headless/test_wire_split.tcl` → `OVERALL: ok`.
- After W4: run the headless sweep directly (`test_fluid_editing`, `test_descend_log_absorb`,
  `test_getprop_index_bounds`, `test_wire_split`) to confirm no regressions.
- Commit per phase on branch `fluid-editing`; end commit messages with the
  `Co-Authored-By: Claude Opus 4.8 (1M context)` trailer. Do NOT `git add -A` (the tree has
  unrelated pre-existing changes) — stage explicit paths.

## After W4
Update the spec **Built** section + status, and the `wire-segment-splitting` memory. Then W3
(edit-time re-split/rejoin: route delete/move/stretch/place/draw-wire choke-points through
`maintain_wire_segments` with `push_undo` before mutation; T4 rejoin-on-label-delete, T5
keep-split-at-surviving-pin), then W5 (T3 X-crossing no-short, T8 off-grid no-split) and W6
integration.

Caveman mode may be active (cosmetic terseness) — ignore for code/commits.
