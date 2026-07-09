# 0096 — fluid group drag leaves a FOREIGN-net reversal jog crossing the moved selection (near-slide shorts the moved device, far target never tried)

**Branch:** fluid-editing   **Status:** FIXED + regression test (RED-first), UNCOMMITTED
**Fixture:** `tests/from_user/before_5.sch` (same fixture as 0091 / 0094).
**Repro launch:** `FLUID_TRACE=/tmp/fltrace_7_8_12.log src/xschem --script src/cadence_style_rc --logdir /tmp`
**Given by user:** `after_15.sch` (actual, bad), `preferred_15.sch` (acceptable target).
**Test:** `tests/headless/test_fluid_reversal_0096.tcl` (X-required, self-skips under `--nogui`).
**Related:** [0089](0089-fluid-reroute-redundant-samenet-detour.md) (same-side REVERSAL),
[0090](0090-fluid-reroute-redundant-samenet-staircase.md) (opposite-side STAIRCASE — introduced the
near→far fallback + body guard this issue generalizes),
[0091](0091-fluid-reroute-samenet-crosses-moved-body.md) (foreign-net cross of the moved body, `prot[]`).

## Gesture
Leftward crossing-select **C12 + R18 + their #net2 connecting wire** (3 segments; `startsel_w=3`),
then drag the group by **(-60,+80)** (C12 `-320,-190`→`-380,-110`; R18 `-260,-50`→`-320,30`).

## Symptom
Electrically OK, but **aesthetically wrong**: R18's bottom-pin **#net1** riser reverses out to the OLD
column `x=-260` and the backbone then returns **LEFT at y=-10 straight THROUGH the moved parts**
(`after_15.sch`):
```
N -400 -10 -260 -10 {lab=#net1}   <- passes through the selection bounding box
N -320 70 -260 70 {lab=#net1}
N -260 -10 -260 70 {lab=#net1}     (excursion out to the old x=-260 column and back)
N -400 -10 -400 140 {lab=#net1}
N -320 60 -320 70 {lab=#net1}
```
A non-selected wire that should have been routed AROUND the moved selection instead crosses it.

## Root cause
After the group stretch, #net1 leaves R18's bottom pin, jogs out to the old column `x=-260`, and the fixed
backbone comes back at `y=-10`. That vertical `x=-260` wire is a classic **same-side REVERSAL (U-turn)**:
both perpendicular #net1 neighbours (`y=-10` backbone → far `x=-400`; `y=70` rung → far `x=-320`) leave to
the **left**. `fluid_straighten_reversals` pass 1 is built to collapse exactly this.

The reversal-collapse **slides the jog to the NEARER neighbour** (`x=-320`) — and that slide is **rejected**:
at `x=-320` the vertical jog `y∈[-10,70]` runs through R18 (now at `-320,30`) and covers **both** R18 pins
(`-320,0` #net2 top and `-320,60` #net1 bottom) → a #net1/#net2 **short** → the pin-partition changes →
`fluid_part_equal` false → revert (silently — the DECLINE trace lines only fire on `foreign`/`body`, not a
partition change).

The pre-fix code treated a reversal as `ncand = oppo ? 2 : 1`, i.e. **the near neighbour is the ONLY target
a reversal ever tries** (its stated premise: "a reversal only ever SHORTENS, so the nearer neighbour is the
unique correct target"). That premise fails for a **rigid group drag that parks the moved device between
the U-turn's two columns**: the near collapse would drive the jog through the device, and the FAR target
(`x=-400`, which routes #net1 cleanly PAST the device) is never attempted. So the reversal stands and #net1
keeps crossing the selection.

Trace (pre-fix) — pass 1 never logs a slide for #net1; only the net3 orphan stub is pruned:
```
straighten: ENTER W=15 snap_npins=7
straighten: deleted orphan stub wire=10 [-380 -300 -320 -300]
```
(The user's `after_15`→`preferred_15` was a manual SECOND gesture: grab the crossing wire and drag it down,
whereupon `fluid_collapse_axis_overshoot_stub` shoved the riser to `x=-410`. The fix makes the FIRST group
drag produce the clean route by itself.)

## Fix
`src/move.c`, `fluid_straighten_reversals` pass 1: **try the far neighbour as a fallback for a reversal too**,
not only for a staircase.
- `ncand = oppo ? 2 : 1;` → `ncand = 2;` — always try near (`ci==0`) then far (`ci==1`).
  For a normal reversal whose near slide succeeds this is **byte-identical**: `ci==0` sets `progress` and
  the `ci < ncand && !progress` loop never runs `ci==1`.
- Body guard generalized from `oppo` to `extends = oppo || ci == 1`. A collapse that **lengthens** a
  neighbour (a staircase either target, OR a reversal's far fallback) must clear every **stationary** body;
  a reversal's near slide (`ci==0`) is a pure shorten and keeps its no-body-guard path. The far target is
  partition-verified + foreign-verified + body-guarded exactly like the staircase far target.

Trace (post-fix):
```
straighten: slid jog wire=13 x->-400 (reversal collapse)
straighten: deleted orphan stub wire=9  [-380 -300 -320 -300]
straighten: deleted orphan stub wire=11 [-400 -10 -400 60]   <- orphaned riser tail retracted (pass 2)
```
Result #net1 routes below/left of the selection (rung `y=70`, riser `x=-400`), matching `preferred_15`
topology (preferred's `x=-410` was the extra second-gesture shove; `x=-400` clears C12 — body `x∈[-390,-370]`
— by 10 and is electrically identical).

## Safety / scope
- Only fires when the near slide is **declined**; every far slide is pin-partition-invariant, foreign-copper
  guarded, and (being an extend) stationary-body guarded — same guarantees as the existing staircase far
  target. If both near and far are declined, nothing changes (byte-identical to old behaviour for that wire).
- Novelty-scoped (`fluid_wire_is_novel_span`) + `prot[]`-gated: a user's deliberate detour, and the user's
  own selected net, are never reshaped.
- Caller-gated on `fluid_editing` (default OFF) → standard regression suite byte-identical. Confirmed: the
  two headless FAILs (`test_fluid_editing` FE8 arc, `test_wire_split` W7 netlist ordering) reproduce on clean
  HEAD and are unrelated pre-existing flakes.

## Adversarial review (wf_0511b35f, 5 lenses + synthesis) — verdict SHIP, no must-fix
byte-identity CLEAN (the `ci < ncand && !progress` short-circuit makes a near-success byte-identical; per-
iteration `reach` malloc/free balanced, no UAF — the accept branch's `trim_wires` runs only after `progress`
exits both loops). termination CLEAN + STRENGTHENED (a far reversal strictly DECREASES copper length
ΔL = −2·min(|fa−dx1|,|fb−dx1|) < 0, so a far-slid wire can never be slid back → no oscillation; the guard is
an OOB/UAF-safe backstop). partition-safety CLEAN (the far reversal runs the IDENTICAL electrical verify —
`fluid_part_equal` + `fluid_slide_merges_foreign` + body guard — as the already-shipped staircase far slide).

### Deferred (low priority, non-blocking)
1. **Moving-body graze.** `fluid_seg_crosses_stationary_body` guards only STATIONARY (`.sel==0`) instances, so
   a far-extended leg (reversal OR staircase) can visually GRAZE a MOVING symbol's body. Harmless: a wire over
   a body creates no node in the `touch()` model, and any real pin contact flips the partition → DECLINED. It
   is pre-existing and shared line-for-line with the shipped staircase far path; feature default-OFF. Fixing it
   (guard the moved set too) risks declining currently-committing staircase slides, so it is NOT bundled here.
2. **Under-covered decline side.** `test_fluid_reversal_0096` exercises the far-reversal COMMIT (near declined
   by short → far commits `x=-400`); add a fixture where the far target is ALSO declined to lock the no-op side.
3. **Pre-existing pinless-branch net-split blind spot** (surfaced, predates 0096, separate issue): an explicitly-
   labeled but PINLESS branch T-junctioning the INTERIOR of a pivoting neighbour A/C is invisible to both
   `fluid_part_equal` (pinless) and `fluid_slide_merges_foreign` (checks merges, not disconnects), so a slide
   could silently rename that net. Narrow; affects the shipped staircase path equally. Track separately.
