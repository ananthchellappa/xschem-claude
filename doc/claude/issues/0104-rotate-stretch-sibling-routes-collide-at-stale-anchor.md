# 0104 — rotate during connected stretch: sibling follow-wires collide at a stale backbone anchor (short)

**Status: FIXED (uncommitted). Test `tests/headless/test_rotate_stretch_short_0104.tcl`
77/77 GREEN (user drop + flip variant + rot270 + column sweep dx∈{-60..-10} dy=70;
partition + dangle-set-subset + user-stub-survival + placement anti-vacuity asserts +
known-tail confinement bound + xfail promotion signal), sabotage-verified RED with the
pass disabled (3 fails: user drop short, anchor endpoint, flip-variant short), valgrind
memcheck clean on the repro gesture. 0099 (21), 0100 (51), 0103 (77), 0098 (both), fluid
0088/0089/0096, drag-keeps-selection, cadence stretch/move, the full wireedit aggregate
(51 cases) and `run_regression.tcl` (11×0 fails) all pass. Adversarially reviewed
(wf_506236ef, 5 lenses / 21 agents): 10 confirmed findings, all fixed — see below.**

## Fix (src/move.c) — post-review shape
- New `fluid_prune_shorting_anchor_tails()` (defined after `fluid_prune_anchor_tails`),
  called from the END-only fluid cleanup block right after `fluid_ripup_foreign_pin_short()`
  (ungated by rotfree — the guards are geometric). Delete-only de-short: strict no-op unless
  the GEOMETRIC pin-partition already differs from the GEOMETRIC START snapshot; candidate =
  non-bus, unlabeled, unprotected (0091), novel-SPAN wire with one end on a pristine attach
  spot (START endpoint, START deg >= 2, no pin) still touched by other copper (deg >= 1 —
  the crossing route; deg 0 dangling is 0103's), kept end still a junction, interior free of
  taps (`fluid_loop_interior_clean`). Dooms accumulate GREEDILY (each must strictly reduce
  the pair-disagreement count vs START); the set commits ONLY at count 0 (exact START
  restore), else every doom reverts — de-short provably or byte-identical.
- New GEOMETRIC START snapshot `fluid_geo_snap_id` (captured in `fluid_snapshot_partition`
  via `fluid_loop_partition`, freed in `fluid_discard_snapshot`) + helper
  `fluid_part_diff_pairs()` (pairwise class-structure disagreement count vs that snapshot;
  incomparable → "maximally different", the don't-commit direction).

## Review findings fixed (wf_506236ef)
1. **[major] name-vs-geometry verify blessed deleting pristine copper** (live-repro'd:
   `spice_ignore` bridge scene — name partition blind to ignored wires, geometry not; a
   plain non-rotated `m` stretch deleted the user's stub feeding the bridge, silently).
   → geometry-to-geometry compare (`fluid_geo_snap_id`). Reviewer's repro now: chain intact,
   pass strict no-op, on 7 drop sweeps.
2. **[major ×3] pass permanently inert in multi-island named-net schematics** (GND/VDD
   islands make name-vs-geometry equivalence unsatisfiable; near-universal in real designs).
   → same fix; reviewer's islands repro now fires the pass correctly.
3. **[major] singles-only dooming declined two-simultaneous-short scenes.** → greedy
   accumulate + commit-at-zero; reviewer's dual-R18 scene now prunes both tails (diff 5→1→0).
4. **[minor] mid-span tap on the doomed tail could sever a pin-less lab= branch** (pin-blind
   verify). → `fluid_loop_interior_clean` candidacy gate.
5. **[minor] helper's incomparable→EQUAL fail-safe was commit-unsafe.** → returns
   maximally-different; a 0 (commit signal) must be earned.
6. Comment overstating a downstream `fluid_partition_changed()` rollback (absent on
   un-snapshotted END paths) rewritten to state the real invariant (commit only on proven
   exact restore).
7. Test: dead empty if-clause removed; `case_known_tail` now bounds novel dangles to the
   single known tail tip + carries an xfail promotion signal; check count computed
   (`$::nchecks`); baseline `#netN` literals kept but documented as a fixture-identity anchor.

## Known limitation (pre-existing, surfaced by the new test)
rot180 at the same drop (-30,70) is only routable by the attempt-2 RIGID DIAGONAL RELAY
(attempts 0/1 short; relay ACCEPTs pchg=0) — and the relay path (`leg_ortho==0`) skips the
whole END cleanup block, so a 0103-class same-net stale-anchor tail dangles at (-120,-40).
Electrically clean; fails identically with this fix disabled (sabotage-verified pre-existing).
Covered as `case_known_tail` in the test with hard partition/placement floors; promote back
to a full `case` when the relay path gains END cleanup.

## Name (short)
"Rotate-stretch stale-anchor collision short": after ALT-R during a connected `m`
stretch, one moved pin's elbow keeps its far leg anchored at the pin's *pristine
pre-move* attach point on the backbone (the 0103 tail shape), while the SIBLING
pin's follow wire — straight, no elbow freedom — happens to run exactly through
that stale anchor coordinate. The two routes touch at the anchor endpoint, merging
the two nets across the device. Every fallback attempt is equally shorted, so the
0085 accept ladder keeps the shorted ortho result and it is saved.

## Repro (user, GUI)
1. `FLUID_TRACE=/tmp/fltrace_7_8_18.log src/xschem --script src/cadence_style_rc --logdir /tmp`
2. Load `tests/from_user/before_7.sch`. Select R18 (vertical res at (-120,-80),
   pin0 (-120,-110)=#net2 top, pin1 (-120,-50)=#net1 bottom; #net1 backbone runs
   along y=-40 from x=-400 to the pristine pin1 stub anchor at (-120,-40)).
3. Press `m` (connected stretch), drag, mid-drag ALT-R (rot90), drag to total
   delta **(-30,+70)**, click to place. Saved: `tests/from_user/after_21.sch`.
4. Minimal pair: total delta (-40,+70) (or (-20,+70)) is electrically clean
   (0103 territory, after_20.sch) — only (-30,+70) lands R18's rotated pin0 at
   x=-120, the pristine anchor's own column.

## Observed (after_21.sch)
All of old #net2 (C12 bottom plate branch) is relabeled #net1 — one merged net
across R18:

- pin1 elbow: `N -180 -40 -180 -10` (leg to pin1) + `N -180 -40 -120 -40`
  (far leg reaching back to the pristine anchor (-120,-40));
- pin0 straight follow route: `N -120 -150 -120 -40` + `N -120 -40 -120 -10`
  (split AT the anchor point by the touching endpoint);
- the touch at (-120,-40) shorts #net2 onto #net1.

## Mechanism (trace /tmp/fltrace_7_8_18.log)
- `elbow: wire=6 sel1=0 ... -> ml=2 r1=(-120,-150) r2=(-120,-10)`: pin0's follow
  wire is a degenerate straight vertical (junction x == rotated pin x == -120),
  no orientation freedom.
- `elbow: wire=12 sel1=1 ml0=1 h0=0x0 h1=0xa -> ml=1 r1=(-180,-10) r2=(-120,-40)`:
  pin1's elbow far anchor is the PRISTINE attach point (-120,-40) (0100 crux (a):
  anchored end stays pristine). h0=0x0 — the hazard classifier sees CURRENT
  geometry only; pin0's future straight route at x=-120 is invisible, so the
  orientation is judged clean. The OTHER orientation (h1=0xa) is genuinely worse
  (it lays copper along y=-10 straight through pin0's landing). No orientation
  choice can help: both reach the same stale anchor.
- Every attempt (0 = X→Y legs, 1 = single ortho diagonal, 2 = rigid relay) ends
  `partition_changed=4` → `rigid relay not clean (4, attempt-1 had 4): kept ortho
  attempt-1 result` (RUBBER steps) / `(4, attempt-1 had 3)` at END. Shorted result
  committed and saved.

## Why existing passes miss it
- **0103 `fluid_prune_anchor_tails`**: two independent blockers. (a) Candidacy
  requires exactly one FREE end (touch-degree 0) — the tail's stale-anchor end has
  degree 2 (pin0's foreign route endpoints split there), so it is never a
  candidate. (b) Verify direction: 0103 dooms are verified to PRESERVE the
  pass-entry partition; here the entry partition is already shorted and the fixing
  deletion CHANGES it (restores START) — it would be vetoed even if candidacy were
  widened. Wrong tool by construction.
- **0094/0098 `fluid_ripup_foreign_pin_short` + jog**: keyed on a moved device PIN
  landing on foreign copper. No pin sits at (-120,-40) — it is a wire-endpoint on
  wire-body touch. Detector never fires.
- **0102 P2 safety-net relay**: rot180 crossing-route relay; different geometry
  (this is rot90, endpoint-touch not segment crossing).
- **Elbow hazard classes (0085/0086)**: choose BETWEEN two L orientations of the
  same two endpoints; the anchor endpoint itself is the hazard, shared by both.

## Fix direction
New delete-only END de-short pass in the `!commit_now` fluid cleanup block
(`fluid_prune_shorting_anchor_tails`, next to `fluid_ripup_foreign_pin_short`):
strict no-op unless `fluid_partition_changed() != 0` at entry. Candidate = non-bus,
unlabeled, non-user-protected (0091) wire with one end ON a pristine attach spot
(`fluid_start_endpoint_at`, START degree >= 2) whose CURRENT degree is >= 1
(foreign copper passing through — exactly what disqualifies it from 0103), kept
end still a junction without it. Doom the candidate, verify
`fluid_partition_changed() == 0` (START partition RESTORED — the 0094/0098 verify
direction), commit else revert. Deleting `N -180 -40 -120 -40` provably restores
the START partition (pin0 keeps old-#net2 path, pin1 keeps backbone via elbow).

## Artifacts
- fixture: `tests/from_user/before_7.sch`
- user-saved bad result: `tests/from_user/after_21.sch`
- trace: `/tmp/fltrace_7_8_18.log`
- prior art: 0103 (same tail, dangling variant), 0094/0098 (START-partition-restore
  verify pattern), 0100 (pristine anchors), 0085 (accept ladder)
