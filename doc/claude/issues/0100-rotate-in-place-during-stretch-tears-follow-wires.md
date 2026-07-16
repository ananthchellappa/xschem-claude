# 0100 — rotate-in-place (ALT-R) during connected stretch tears follow wires off pins

**Status: FIXED (uncommitted). 23/23 checks GREEN incl. the user's exact drop (40,20) and an
off-anchor grab; RED-first (9 FAIL pre-fix); sabotage-verified per edit (A → 9 FAIL, C → 3 FAIL
off-anchor); 0099/rotate_stretch/0098/0088/0089/0096/cadence_stretch_move suites green;
valgrind 0 errors. `tests/from_user/after_18_fixed.sch` = the user gesture on the fixed binary.**
**Branch:** fluid-editing. Sibling of 0099 (same user report, different mechanism — 0099's
trace was read as a short; the user's actual gesture produces a TEAR-OFF).

## Repro

`tests/from_user/before_7.sch` → `tests/from_user/after_18.sch`. Launch
`FLUID_TRACE=/tmp/fltrace_7_8_15.log src/xschem --script src/cadence_style_rc --logdir /tmp`.

Gesture: select R18 (res, pin P=#net2 shared with C12, pin M=#net1), press `m`
(cadence connected stretch), drag a bit, press **ALT-R** mid-drag, keep dragging
(deltas 30,50 → 30,40 → 30,30 → 40,30 → 40,20), drop at delta (40,20).

Symptom: both R18 pins end on fresh nets (`pchg: R18 pin 0 ... snap=#net2 now=#net4`,
`pin 1 snap=#net1 now=#net5`) — the follow wires are DISCONNECTED, not shorted.
Saved after_18: R18 at `-80 -60 1 1`; its old M-stub dangles at (-80,-30); its old
P-wire dangles at (-120,-130). Neither touches a pin.

## Root cause — per-object rotatelocal pivots

ALT-R during STARTMOVE issues `move_objects(ROTATE|ROTATELOCAL,0,0,0)`
(callback.c:5100, `case 'r'` + EQUAL_MODMASK; ALT-F likewise FLIP|ROTATELOCAL at
:4592) — **not** plain ROTATE. `xctx->rotatelocal=1` (move.c:5383) changes every
pivot in the shared commit block:

- ELEMENT (move.c:5862): rotates about **its own origin** `inst.x0,y0` — pins land
  at the rotate-in-place positions. Correct.
- follow WIRE (move.c:5575): partial-selected endpoint rotates about **the wire's
  own (x1,y1)** — a pivot with no relation to the pin the endpoint must track.
  The endpoint lands at garbage → P1 disconnect.

Numeric proof from the trace/saved file (rot=1 maps rel (x,y)→(−y,x)):
- inst (-120,-80) about own origin + Δ(40,20) → (-80,-60) ✓ saved.
- P-wire attached end (-120,-110) about the wire's own x1,y1=(-120,-150) + Δ →
  (-120,-130) ✓ saved dangle. About the CORRECT pivot (-120,-80) it would land
  (-50,-60) = exactly pin P.
- M-stub attached end (-120,-50) == its wire's own x1,y1 → identity + Δ → (-80,-30)
  ✓ saved dangle. Correct pivot ⇒ (-110,-60) = exactly pin M.

Everything the rotate-keep-connected work (Phase 4a/4b crux (a), issue 0099)
assumed a SINGLE global pivot `xctx->{x1,y1}` shared by instance and follow
endpoints. That holds for plain ROTATE (Shift-R / menu / `xschem rotate`) — which is
what the 0099 test drives — but ALT-R, the user's actual key, is ROTATELOCAL.
The 0099 fix comment "mid-move ALT-R issues ROTATE, not ROTATELOCAL"
(move.c:3981) is factually wrong. Green-but-hollow: 0099's 15 checks all pass while
the reported gesture still breaks.

Secondary casualties under rotatelocal (same wrong-pivot assumption):
- `fluid_ml_hazards` pre-move-M recovery (move.c:3984) inverse-rotates about
  `xctx->x1,y1` — wrong pivot ⇒ pristine-net lookup misses ⇒ hazard classes degrade.
- `fluid_ml_hazards` MOVPIN loop (move.c:4014) predicts a co-moving pin at
  `ROTATION(xctx->x1,y1)(pin)+Δ` — under rotatelocal the commit will use the pin's
  own instance origin ⇒ prediction lands elsewhere ⇒ elbow may pick a shorting L.

The reroute/shove/offset engine stays gated `move_rot==0&&move_flip==0` (unchanged,
Phase 4c scope); the 0098 facet-B de-short passes run under rotation and are
partition-verified (they cannot fix a disconnect, only decline).

## Fix (3 edits in src/move.c, all gated ⇒ byte-identical outside a rotated/flipped fluid stretch)

A. **Commit WIRE case (~5575):** under `rotatelocal && (move_rot||move_flip) &&
   fluid_editing && stretch_select` and a PARTIAL-selected wire, look up the selected
   instance whose (pristine) pin coincides with the wire's moving endpoint; use that
   instance's `x0,y0` as the wire's rotation pivot — the exact pivot the ELEMENT
   commit uses, so the endpoint lands ON the pin by construction. No owner found
   (endpoint follows a selected wire, not a pin) ⇒ old behavior.
B. **Hazards pre-move M:** the WIRE case stashes the pristine moving-endpoint coords
   in statics before calling place_moved_wire; `fluid_ml_hazards` uses them directly
   instead of inverse-rotating about an assumed pivot (exact under any pivot; equal
   to the old math under plain ROTATE).
C. **Hazards MOVPIN pivot:** rotatelocal ⇒ per-instance pivot `inst[i].x0,y0`
   (mirror of the ELEMENT commit), else global `xctx->x1,y1` as before.

Quality layers (`fluid_ml_future_covers`, `fluid_p6_bias_ml`) do translation-only
pre-move lookups; under rotation those miss ⇒ the helpers return 0 ⇒ inert. Worst
case a suboptimal-but-connecting L. Left as-is (Phase 4c).

## Scope / known limitation

Same as 0099: rot180/rot270 (now also *in-place*) put both pins on one line such that
the two follow routes must cross — needs the reroute engine un-gated under rotation
(Phase 4c). Recorded as informational notes in the test (with a hard no-short FLOOR
assert), not hard fails. Flip-in-place on R18 is geometrically a pin no-op (pins on
the anchor's vertical axis) — a good pure-connectivity check.

Adversarial review (wf_80304448-181, 16 agents) confirmed the fix byte-identical
outside its gates (zero findings on that lens) and surfaced three PRE-EXISTING holes
in adjacent gestures (fully-SELECTED pin-to-pin strap between two co-selected
instances; wire-grab stretch follower; tolerance-vs-exact owner match) — all tear
identically pre-0099; documented with candidate fixes as
`doc/claude/issues/0101-rotatelocal-stretch-remaining-holes.md`.

## Test

`tests/headless/test_rotate_stretch_reconnect_0100.tcl` (X-required, self-skips):
drives the REAL key — `xschem callback <win> KeyPress ... 114 0 0 8` (keysym `r`,
Mod1Mask) — with continued MOTION after the rotate (mirrors the user trace), drops at
the user's delta (40,20) plus (30,20), plus ALT-F flip-in-place. Asserts the
electrical partition (R18.P on #net2 with C12, R18.M on #net1, distinct) via
`xschem instance_nodemap`. RED-first on the pre-fix binary.
