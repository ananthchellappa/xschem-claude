# 0094 — group drag lands a moved device's off-net pin on a foreign backbone → short + follow-riser loop

**Branch:** fluid-editing   **Status:** FIXED + adversarially reviewed, UNCOMMITTED
**Fixture:** `tests/from_user/before_5.sch` (same fixture as 0091).
**Repro launch:** `FLUID_TRACE=/tmp/fltrace.log src/xschem --script src/cadence_style_rc --logdir /tmp`

## Gesture
Left-drag rubber-band selects **C12 + R18 + the #net2 connecting wire** (3 wires; `fluid_startsel_wires=3`),
then drag the group by **(-40,+70)**. (0091 is the SAME selection dragged by (-20,+60).)

## Symptom
The saved schematic has:
1. **A short** — R18's two pins, distinct at START (`#net2` top, `#net1` bottom), both resolve to `#net1`
   after the move (`fluid_editing INVARIANT (P2 device)` fires). R18 is shorted out.
2. **A loop** — the #net1 follow-riser for R18's bottom pin wraps right and up
   (`(-300,50)-(-300,60)-(-260,60)-(-260,-10)`) and rejoins the old backbone, closing a rectangle
   through R18's body.

## Root cause
The drag delta lands R18's **top pin (#net2) at exactly (-300,-10)** — on the fixed **#net1 backbone**
`(-400,-10)-(-260,-10)` (y=-10, x∈[-400,-260], so x=-300 is interior). `trim_wires` splits the backbone at
the pin, and the pin-overlap merges #net1 and #net2 → the short. **This short is in the base stretch, not
the fluid reroute** — it reproduces with `fluid_editing=0` (rigid stretch shorts too). The follow-riser
loop is the fluid reroute wrapping around the now-load-bearing backbone.

0091 (same fixture, (-20,+60)) is clean because R18-top lands at y=-20, **clear** of the backbone: the
backbone's right end orphans (R18-bottom moved away) and `fluid_straighten_reversals` slides it down to
R18-bottom's row and deletes it — trace:
```
straighten: slid jog wire=13 x->-280 (reversal collapse)
straighten: slid jog wire=9  y->40  (reversal collapse)
```
For (-40,+70) those slides **never fire**: R18-top pins the backbone node (-300,-10), making it a **deg-3
T-junction with a foreign pin on it** — not the clean deg-1 corner the reversal-collapse requires
(`point_on_any_pin` / `fluid_deg_at != 1` guards), and any slide off the pin would change the *post-stretch*
partition (which already contains the short and is the verify baseline `base`), so it is rejected. The
short is thus self-protecting.

This is the long-deferred **Phase-4 "no-short guard + rip-up"** (`nice_drag_rerouting.md` §; referenced as
DEFERRED in `insert_exit_stubs` and the move.c END comments): a moved instance pin landing on foreign
copper is a genuine P2 short that the reroute must RIP UP, because the pin position is fixed by the rigid
move — only the foreign copper can move out of the way.

## Clean target (by analogy to 0091's (-20,60) result)
R18-bottom (-300,50, #net1) routes to the #net1 column at x=-400 via an under-run at y=50; the horizontal
backbone `(-400,-10)-(-260,-10)` is deleted; R18-top (-300,-10, #net2) is left clear → no short, no loop.
```
#net1: ... -400,50 -400,140 ; -400,50 -300,50   (under-run to R18.M)  [backbone gone]
#net2: -300,-80 -300,-10 (R18 top) ; -360,-80 -300,-80 ; -360,-90 -360,-80 (C12 bottom)
#net3: -360,-300 -360,-150 (C12 top) ; -420,-300 -360,-300
```

## Why the other passes miss it
- `fluid_remove_redundant_loops` (0088): the loop runs through R18's BODY (device pins), not a pure-copper
  cycle → declines (correct).
- `fluid_straighten_reversals` (0089/0090): the reshape corner is a deg-3 pinned T, not a deg-1 jog, and the
  slide would change the shorted baseline → both guards reject.
- `fluid_collapse_axis_overshoot_stub` (0092): needs a novel dangling stub on the grabbed net; N/A.
- The nlegs==1 attempt-loop partition-rollback (0093 D2) would only pick a different variant, and EVERY
  variant of this drop shorts (the pin is physically on the backbone), so rollback cannot help.

## Fix direction
A dedicated END pass that, on a detected move-created **device merge** (P vs START), rips up the foreign
backbone off the offending pin and reroutes the shorted net's device attachment to its sibling row —
partition-verified to RESTORE the START distinctness (not preserve the shorted post-stretch base). Gated on
`fluid_editing` (default off ⇒ byte-identical) + the usual stretch/final-leg gates; strict no-op unless a
move-created merge exists.

## Fix (src/move.c) — IMPLEMENTED
- `fluid_ripup_foreign_pin_short()` (END pass, runs FIRST, before `fluid_remove_redundant_loops`):
  fixpoint over move-created device merges. For a merge pair (P invader, START-net `sp`; Q sibling on the
  backbone net `sq`), axis-aligned (`px==qx` or `py==qy`), collects the perpendicular backbone (seed on P's
  line + touch-connected flood), **slides it onto Q's line**, and KEEPS the slide iff `fluid_partition_changed()==0`
  (restores START distinctness) **and** no slid wire newly touches copper outside its pre-slide component
  (`fluid_wire_reach_set` — the pin-less-labeled-net foreign-short guard, mirroring `fluid_slide_merges_foreign`).
  Reverts otherwise. Never reshapes explicitly-`lab=` copper.
- `fluid_prune_novel_orphan_stub()` (runs AFTER straighten, only `if(ripped)`): deletes the fresh dangling
  backbone stub past the sibling pin (`fluid_start_deg_at==0` ⇒ provably drag-created), connectivity-verified.
- No P5 no-body-cross guard: a graze that doesn't hit the crossed device's pins is electrically clean and
  P2 (no-short) OUTRANKS P5 in the conflict order; a pin-hitting cross is a merge the verify rejects.
  Route-around deferred.

## Verification
- Repro (-40,+70): `SHORTED=0`, no loop, R18 routes to the far-left #net1 column — same clean shape as
  0091's (-20,+60). RED-first `test_wireedit_51_offpin_foreign_backbone_0094.tcl` (3 teeth fail pre-fix,
  GREEN post-fix). Wireedit suite 52/52 PASS; valgrind clean; default-off byte-identical.
- Adversarial review (workflow wf_fe8ba9a4 + a lifecycle/scope re-review): confirmed 2 findings and fixed both:
  (1) pin-less-foreign-net short → the `fluid_wire_reach_set` guard above; (2) **use-after-free of `ap`** —
  the live pin net name was hoisted to the p-loop but a declined slide's `prepare_netlist_structs(0)`
  frees+rebuilds `inst[].node[]`, dangling it for the next q on a ≥3-pin device → now re-read fresh each q.
  Lifecycle/scope/termination/index-alignment all CLEAN. The body-cross finding is the deliberate P2>P5
  tradeoff above.
