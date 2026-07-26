# 0138 — fluid connected-drag: minimum-copper compaction for NAMED nets (stranded crossbar)

**Status:** FIXED (not pushed)
**Branch:** fluid-editing
**Area:** wiring / fluid connected-drag (`src/move.c`, `fluid_straighten_reversals` +
`fluid_jog_is_moved_pin_escape_overshoot`) — see `doc/claude/WIRING.md`
**Fixture:** `tests/from_user/before_39.sch` → `after_41.sch`.
Test `tests/headless/test_fluid_compact_named_crossbar_0138.tcl`.
**Follows:** 0137 (same min-copper principle, auto `#`-nets only). Sibling of 0136 (whose body-shove this
must not undo).

## Principle (spec)

**Every move must leave MINIMUM copper, cleanly** — the 0137 principle, now for explicitly-labelled nets.
0137 reclaimed a moved pin's over-long escape stub, but only for auto (`#netN`) nets: the reclaim BAILED on
any wire carrying an explicit (user) label. So named nets kept their stranded copper.

## Reproduction (user-reported, `/tmp/Xschem.log.7`, trace-verified)

Fixture `before_39.sch`: `x1 = SANDBOX/solar_ctl` rot1 @ (80,10). Two SOUTH-lead output pins route to
lab_pins on the right:

- **TRIANG** pin (50,70) → l0 (220,20)               (2-bend: pin-riser, crossbar, far riser)
- **CTRL1** pin (90,70) → l1 (220,-20) via an x=140 trunk

Both pins escape SOUTH (their lead normal), so each net dips below the pin then rises to its label.

Gesture: a **multi-motion connected-drag** of x1 — jiggle DOWN to a deep excursion then partly back UP
(instance-origin y visits 10→30→0→20→50→80(x→70)→60, net (−10,+50)). Saved as `after_41.sch`. Result on
the pre-fix binary:

```
TRIANG crossbar stranded at y=150 (min 130)  copper 340 (min 300)
CTRL1  crossbar stranded at y=160 (min 130)  copper 360 (min 320)
```

The auto nets `#net1/#net2` (the north input pins) compacted every gesture; only the two NAMED nets were
left long.

## Root cause (two named problems)

1. **`push-only-retreat-slack`** — the pipeline is push-only: each DOWN motion shoves the perpendicular
   escape stub outward so the crossbar tracks the pin's *deepest* excursion (a correct 1-grid escape at the
   low point). On the RETURN nothing PULLS it in; the stub just grows (10→20→30). The crossbar is frozen at
   the drag's low-water mark, not the final pin level.

2. **`explicit-label reclaim carve-out` (ROOT)** — the only pass that reclaims carried pre-existing copper,
   `fluid_straighten_reversals`' min-copper reclaim (`fluid_jog_is_moved_pin_escape_overshoot`), bailed on
   explicit nets:
   - `move.c:3578` — early return if the jog's own `lab` is explicit (non-`#`).
   - `move.c:3594` — return if either neighbour is explicit.
   - `move.c:3691` (pass-1 loop) — skip if kd/kA/kC carry an explicit label.

   `fluid_wire_explicit_lab` ≡ `lab[0] && lab[0] != '#'`. So `TRIANG`/`CTRL1` (named) were skipped;
   `#net1/#net2` (auto) passed and compacted. Geometrically the crossbar IS a valid same-side reversal at
   the straighten slide — the only thing stopping it was the label carve-out.

## Fix (`src/move.c`, gated `fluid_editing`)

1. **Admit explicit nets into the escape-overshoot predicate** — drop the `fluid_wire_explicit_lab`
   bails at :3578 / :3594 (buses stay excluded). A verified overshoot slide is a pure **same-net inward
   shorten**; the slide's partition (`fluid_part_equal`) + foreign-copper (`fluid_slide_merges_foreign`)
   verify already reject any merge/rename, so the label carve-out is unnecessary.

2. **Bypass the pass-1 explicit-label skip only for a verified overshoot** — compute `is_overshoot` once;
   the :3691 skip now fires only when `!is_overshoot`. Novel-span explicit reshaping stays blocked (no
   behaviour change there) — only the narrow, verified escape-overshoot shape is opened.

3. **Outward search** — the minimal 1-grid escape row can be taken by a sibling net that already compacted
   onto it (TRIANG holds y=130 across the full width, so CTRL1's 1-grid escape at y=130 would short it).
   For an overshoot, search outward grid-by-grid (pin+1, pin+2, …) and take the nearest row that VERIFIES.
   Every generated row is strictly inside `(pin, current-jog)`, so it is always shorter than leaving the
   jog stranded; landing at the jog (no-op) or beyond (longer) is never generated. Bounded to ≤ 8 rows
   (same spirit as `insert_exit_stubs`' D2 outward slide). Result: **CTRL1 → y=140**, its riser crossing
   TRIANG's crossbar perpendicularly at (140,130) — a legal cross, not a short.

4. **Body-guard every overshoot slide (against the REAL body)** — the reversal near-slide is normally an
   unguarded "pure shorten", but the overshoot **outward rows** (`ci > 0`) TRANSLATE the crossbar to a new
   column at fixed length while the neighbours shorten, so the crossbar can sweep into a device body that
   the pin-partition + foreign-copper verify never see. Those rows must clear BOTH bodies:
   - **moved** body (`guard_moved = extends || is_overshoot`, `call_body=1`) — 0136: CTRL1's x=170 trunk was
     deliberately shoved clear of the dragged device; the naive reclaim pulled it back to x=140 straight
     THROUGH the body.
   - **stationary** bodies (`guard_stat = extends || overshoot_row`) — review `wf_fa599f4d` never-worse
     lens: with the multi-step search reaching deeper columns than 0137, a crossbar could route across a
     pin-less stationary symbol squeezed into the escape corridor.

   Both checks on the outward rows use the **real drawn body** (`inst.xx1..yy2`, bbox WITHOUT texts — new
   `notext` arg on `fluid_seg_crosses_body`), NOT the text-inflated world bbox. `before_41`'s minimal 1-grid
   escape (R1 crossbar at y=60) sits ABOVE R1's real body but INSIDE its text bbox; the text-inflated check
   wrongly declined it (regressing 0137). The real body distinguishes 0136's genuine through-body route from
   0137/0138's legal text-graze. The far-collapse (`ci == 0`) and all non-overshoot callers keep the
   text-inflated bbox gated on `extends` (byte-identical).

Minimal result: **TRIANG copper 300 (crossbar y=130), CTRL1 copper 320 (crossbar y=140)** — down from
340/360. The compaction is a stable fixpoint (repeated down/up round-trips do not regrow copper).

## Verification

- New RED→GREEN test `test_fluid_compact_named_crossbar_0138.tcl` — 13/13 (RED 8-fail on the pre-fix
  binary, stash-verified).
- `wireedit` 57/57; all `test_fluid_*` green; **0136 recovered 11/11** (the body guard); 0137 8/8;
  0134 10/10; 0135 9/9; ref_drop 12/12; rotate_body 7/7; rotate_second 11/11; exit_stub 20/20.
- FE arc failures (FE3/FE6/FE8) pre-date this branch (stash-verified identical pre-fix; arc code is
  orthogonal to wire straighten).
- Fixpoint/idempotency probe: after the jiggle, further down40/up40 and down60/up60 keep TRIANG=300,
  CTRL1=320, 4 distinct nets.

## Notes / open

- Non-fluid and rotated/flipped stretch are byte-identical (predicate gates `move_rot==move_flip==0`;
  pass-1 change gated on `is_overshoot`).
- The outward search + opened explicit path also let the auto `#net` input pins compact further than
  0137's single-step reclaim did (strictly less copper, verified) — an improvement, not a regression;
  `wireedit` golden routes are unchanged.
- **Adversarial review** `wf_ccee80ad` (4 lenses × structured verify): rename/merge safety, bounds/loop,
  and body-guard-cross all refuted with concrete reasoning (the fluid verify's connectivity model is
  byte-identical to the netlister's `wirecheck`, so 4-way crossings are non-connections in both and every
  cross-net merge is caught; `lab_pin`s carry a `PINLAYER` pin so are partition-visible; `cand[10]` cannot
  overflow). Two non-refuted findings, both addressed/accepted:
  - *never-worse* (low): the body guard could false-decline an auto `#net` minimal escape grazing a
    text-inflated bbox → **fixed** by the real-body (`notext`) check above.
- **Delta re-review** `wf_fa599f4d` (real-body `notext` + guard-split): `notext` plumbing, `xx1..yy2`
  freshness (written by `symbol_bbox` together with `x1..y2`, recomputed per moved instance before the
  straighten END pass), bounds, and the moved-body relaxation all refuted. One non-refuted (low): the
  stationary-body check was extends-only, so an overshoot outward row could sweep a **pin-less stationary
  symbol** the partition/foreign checks miss → **fixed** by `guard_stat = extends || overshoot_row` (real
  body). Verified via trace probe (a stationary `res` in the corridor yields `DECLINE slide … crosses body`
  on rows that the moved body cannot cover); a standalone golden test is impractical (any device placed in
  a routing corridor connects to a net and alters the topology, so it cannot isolate the guard), so this
  path is covered by the trace probe plus symmetry with the 0136-tested moved-body guard (same helper).
  - *mid-span tap disconnect* (medium): the reclaim guards only d's endpoint degree, so a same-net wire
    T-junctioning the crossbar mid-span is severed by the slide. **Pre-existing** (reachable via 0137's
    auto-net path, not introduced by 0138) and **benign**: a pin-bearing branch flips `fluid_part_equal`
    → reverted; `prepare_netlist_structs` bakes the net name onto every wire so no rename occurs on any
    netlisted/saved file; only a hand-crafted never-netlisted single-label-source file could see a rename.
    Not fixed here (out of scope; adding a mid-span-degree guard risks regressing 0137's own cases).
- Still open (min-copper family, WIRING §11 item 16): multi-jog staircases whose whole run could shift.
