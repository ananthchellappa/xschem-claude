# 0090 — fluid reroute leaves a redundant same-net monotone STAIRCASE (multi-gesture drag)

Status: FIXED (2026-07-08)
Branch: fluid-editing
Repro: `tests/from_user/before_3.sch` → `after_10.sch`
Trace: `FLUID_TRACE=/tmp/fltrace_7_8_6.log`
Test: `tests/headless/wireedit/test_wireedit_47_staircase_0090.tcl` (RED-first)
Related: [0088](0088-fluid-reroute-redundant-samenet-loop.md) (redundant CYCLE, delete-only),
[0089](0089-fluid-reroute-redundant-samenet-detour.md) (redundant same-side REVERSAL / U-turn).

## Symptom

Dragging R18 (res) from `before_3.sch` to R18@(-150,-10) and saving as `after_10.sch`, the riser
meeting R18's **M pin** (net `#net1`) is a **staircase** instead of the clean 3-segment L a single
drag produces:

```
after_10.sch  #net1 M-riser (5 segments, V-H-V-H-V, monotone down-and-left):
  (-400,140) v (-400,50) h (-250,50) v (-250,30) h (-150,30) v M(-150,20)
                              ^^^^^^^^^^^^^^^^^^^ redundant step at x=-250

ideal (single-gesture (250,30) produces this):
  (-400,140) v (-400,30) h (-150,30) v M(-150,20)          -- 3 segments
```

No short, no disconnect — all `#net1`. Purely a bend-count / legibility (P6-quality) defect.

## Root cause — multi-gesture composition

The user reached R18@(-150,-10) in **several successive gestures** (mouse down/drag/up, repeated),
not one drag. The fluid reroute snapshots the pristine schematic at **each gesture's** start and
re-applies that gesture's total delta (Phase II restore-and-reapply). So gesture *N* inherits gesture
*N-1*'s **committed** geometry as its pristine.

Within a gesture the two-leg (X-then-Y) decomposition lays an intermediate jog, and the corner-slide
that would flatten it is **correctly DECLINED**:

```
FLTRACE slide: wire=3 corner=(-250,50) DECLINE (future pin landing on slid copper)
```

The decline is right *per gesture*: a co-moving foreign-net pin (R18.P = `#net2`) has a **future** leg
(the Y move) whose corridor would cross the slid `#net1` copper — sliding it there is a transient
short (issues 0086/0087). But across gestures the declined jogs **pile up** into a monotone staircase
that no END pass removed. A single-gesture equivalent move never sees the intermediate hazard, so it
routes cleanly — proving the staircase is a pure multi-gesture artifact.

**Why the existing passes miss it:**
- 0088 `fluid_remove_redundant_loops` deletes a redundant same-net **cycle**. A staircase is a
  **tree** (no cycle) — delete-only cannot shorten it.
- 0089 `fluid_straighten_reversals` pass-1 slides a jog whose two perpendicular same-net neighbours
  leave on the **SAME** side (a reversal / U-turn). A monotone staircase step is the **opposite-side**
  case (`sa != sb`), which pass-1 explicitly skipped.

## Fix

Generalize `fluid_straighten_reversals` pass-1 (move.c) to collapse **both** shapes with the same
partition-verified slide:

- **reversal** (neighbours same side): unchanged — slide to the nearer neighbour; only ever SHORTENS
  copper, so it keeps its byte-identical no-extra-guard path (`ncand == 1`).
- **staircase** (neighbours opposite side, new): the slide COLLAPSES one neighbour and **EXTENDS** the
  other, so two extra safeguards are needed:
  1. **P5 body-cross guard** on the reshaped `d`/`A`/`C` legs (`fluid_seg_crosses_stationary_body`) —
     an extended leg must not plough a stationary device body. A reversal never extends, so this guard
     is applied only to the opposite-side case.
  2. **farther-target fallback** (`ncand == 2`): try the nearer target first; the nearer target often
     drives the reshaped riser through the **moving device's own body** (declined by guard 1), whereas
     the farther target merges the jog into the existing riser and lets pass-2 (tail retract) finish
     the clean L. Try nearer, then farther; keep the first that passes every guard.

Also: `insert_exit_stubs()` (which runs after the straighten pass and does not trim) can leave a
**zero-length wire** at a stationary partner pin when the collapsed follow-wire now lands exactly on
that pin along its normal. A `check_collapsing_objects()` sweep is added right after
`insert_exit_stubs()` (inside its existing `fluid_editing || wire_exit_stub` gate) to drop the residue.
No-op (byte-identical) on the paths that never create one.

Safety (identical to 0089): every mutation is pin-partition VERIFIED (`fluid_loop_partition`, pure
`touch()`) against the pass-entry base and reverted on any change (subsumes no-short + no-disconnect,
never-worse); a foreign pin-less labeled net a pin-partition can't see is guarded by
`fluid_slide_merges_foreign`; the jog must be NOVEL (`fluid_wire_is_novel_span`, absent at move START)
so a user's deliberate staircase is never rewritten; explicit-labeled / bus copper is declined
(a partition verify cannot see a net RENAME). Caller-gated on `fluid_editing` (default off ⇒ never runs
⇒ byte-identical).

## Verification

- `test_wireedit_47_staircase_0090` (18 checks): repro collapse (no x=-250 jog + exact clean-L geometry)
  + a second gesture split reaching the same endpoint + single-gesture no-regress + a non-staircasing
  no-op; P1/P2/P4 rails. RED-first: 4 staircase checks FAIL on the committed binary (`d1464f08`).
- Full `run_wireedit.sh`: ALL PASS. Tests 43/44 (0085/0086/0087 diagonal) had their C12-net probe
  moved from the old riser point `(-420,-150)` to C12's **pin** `(-420,-170)` — the staircase collapse
  now (correctly) reshapes those scenarios' `#net2` into a clean L, so the probe was over-specified to
  the old geometry; connectivity/no-short/manhattan asserts are unchanged and pass.
- fluid_editing=0: byte-identical (direct segset diff vs `d1464f08`).
- `run_wireedit.sh --memcheck`: clean.

## Deferred / out of scope

The single-gesture path was already clean; this only cleans the multi-gesture accumulation at END. The
"true no-clean-L ortho-quality" reshape (last-resort diagonal relays) remains open. A wire-origin tag
(tool-emitted vs user copper) would let novelty scoping distinguish an inherited tool staircase from a
user's hand-drawn one without the span-novelty proxy.
