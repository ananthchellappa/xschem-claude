# 0085 — blind-elbow diagonal fallback: P2 shorts on a diagonal fluid drag

**Status:** FIXED (src/move.c), regression `tests/headless/wireedit/test_wireedit_43_diagonal_fallback_no_short.tcl`
**Reported:** 2026-07-08, from-user repro `tests/from_user/before_3.sch` → `tests/from_user/after_5.sch`,
trace `/tmp/fltrace_7_8_1.log` (launch: `FLUID_TRACE=... src/xschem --script src/cadence_style_rc --logdir`)
**Branch:** fluid-editing. Related: 0081 (per-axis decomposition), 0083 (far-pin landing), spec
`doc/claude/specs/incremental_wire_reroute.md`. Terminology used here is defined in
`doc/claude/code_analysis/fluid_editing_terminology.md`.

## Symptom

Dragging R18 diagonally (+180,−90) in `before_3.sch` — with plenty of free space — produced
`after_5.sch`: everything collapsed onto one net (`#net1`). Two independent shorts:

* `N -220 -160 -220 -100` — a relay riser laid straight through R18's OWN body, connecting its two
  pins (P self-shorted to M);
* `N -400 -90 -400 140` + `N -400 -100 -400 -90` — the rail relay's vertical leg T'd onto C12's
  stub ENDPOINT at (-400,-90), merging the C12 net into the rail net.

## Root cause (three stacked blind spots)

The drag ends diagonal, so the 0081 two-leg (X-then-Y) decomposition runs, its composite fails the
partition check (`partition_changed=4`, legitimately) and rolls back to the **single diagonal
pass** — believed to be "the proven no-short Layers-1-3 path". It is not:

1. **`fluid_ml_blocked` (Layer-1 elbow choice) tested ONLY the stationary-device two-pin bridge.**
   It explicitly skips MOVING instances (`inst[i].sel → continue`), so the L that plows the moved
   device's own far pin looked clean (short (a)). And it never looked at WIRES at all, so the L
   whose leg lands on a foreign stationary wire's endpoint (a connecting T in xschem) also looked
   clean (short (b)). For the rail wire BOTH orientations were bad (the other one bridges ammeter
   v8, which WAS detected) — so the undetected-bad one was picked as "clean".
2. **Layer 2 (`fluid_reroute_around_obstacles`) can't repair the v8-bridge orientation either**:
   its straddle detection requires the straddling wire to have exactly one moving-pin endpoint
   (move.c `e1mov == e2mov → break`), but the L's stored leg (anchor→corner) has none.
3. **The fallback's result was committed sight-unseen**: the attempt loop's
   `if(nlegs == 1) break;` skipped the partition re-check for attempt 1, so the shorted route
   became the final geometry (and each late RUBBER step's live preview).

The 0083 offset pass is pure-axis-gated by design and correctly did not fire.

## Fix (src/move.c)

1. **`fluid_ml_hazards(ml, sel1)`** replaces `fluid_ml_blocked` in the elbow choice. Initially four
   classes (a fifth, SPANLOSS, was added in the hardening round below):
   `BRIDGE` (the old test), `MOVPIN` (L covers a co-moving pin, at its POST-move position
   live+delta — the instance commit loop runs after the wire pass — on a different pristine net),
   `FPIN` (lone stationary foreign-net pin under a leg), `STRAY` (stationary wire's endpoint on a
   leg / L-corner on a stationary wire, with a one-hop exemption: a wire touching the anchor or M
   anywhere is exempt — at A it was pre-connected, at M the pin landing merges it in every
   orientation; without this exemption test_wireedit_39 C2 regresses).
   Orientation choice by severity (`fluid_mlh_sev`): pristine-net-verified classes (2) outrank the
   heuristic STRAY (1); flip only to a STRICTLY lower severity; ties keep ml0; both-zero keeps the
   P6 min-bend bias. Preserves every old flip decision (the old flip target's stray contact was
   invisible = sev 1 < 2).
2. **Every fallback attempt is now partition-checked** (`if(!leg_snapped) break;` replaces the
   unconditional nlegs==1 break). New ladder: attempt 0 = two-leg decomposition; attempt 1 =
   single ortho diagonal pass; attempt 2 = **rigid diagonal relay** (`leg_ortho=0`,
   `manhattan_lines=0` → `place_moved_wire`'s else-branch translates the moved endpoint; wires go
   diagonal; NO new copper, NO elbow to land on anything; all fluid passes decline on
   `!orthogonal_wiring`).
3. **Never-worse:** attempt-1's result is snapshotted (`alt_snap`, with its own id counters); the
   rigid relay is kept ONLY when fully clean (partition unchanged — see F5 below for why counts
   are never ordered), otherwise the ortho attempt-1 result is restored (an intentional landing —
   pin dropped onto live copper — changes the partition in every attempt and must keep the
   prettier ortho jogs, not degrade to diagonal copper).

`FLTRACE` lines added: `elbow:` (per-wire hazard masks + chosen ml) and per-attempt
`attempt=N done ... partition_changed=K` verdicts including the relay keep/restore decision.

## Hardening round (adversarial review `wf_e348633c`, 6 lenses + per-finding refute-verify, 22 agents)

All 8 raw findings survived refutation; 5 distinct classes, all fixed:

* **F1 (P2)** STRAY skipped ALL `sel!=0` wires, so a partially-selected SIBLING follow wire's
  fixed anchor endpoint was invisible → the flip could steer INTO that anchor's T. Fix: partial
  (SELECTED1/2) wires now contribute their FIXED endpoint as a contact; rigid (SELECTED or both
  1|2) wires stay skipped. Test 43 D5.
* **F2 (P2)** STRAY false-flagged taps on the stretched wire's OWN pre-move span, and a flip away
  from re-covering the span DISCONNECTED the tap (P1). Two fixes: exemptions for wires touching
  M's pre-move position / tapping the A..preM span, plus a new verified-band `FLUID_MLH_SPANLOSS`
  class — an orientation that abandons a span carrying strictly-inside stationary attachments
  (tap endpoints, mid-span-fed pins) is flagged, so it TIES against e.g. a MOVPIN on the covering
  orientation and ml0 (the pre-fix outcome) is kept. Test 43 D4 (observed RED pre-hardening: the
  actual flip driver there was MOVPIN on the moving device's own floating pin — auto-`#net`
  pristine names are non-empty — with the same stranded-tap result).
* **F3 (P3)** all classes were blind to stationary net-LABEL pins (every shared helper skips
  `type=="label"`). Fix: explicit label scan → FPIN (verified) or STRAY (nf unknown).
* **F4 (P3)** with nf==NULL (M not a moving-instance pin), MOVPIN flagged same-net co-moving pins
  at verified severity. Fix: nf-unknown hits degrade to the heuristic STRAY band.
* **F5 (P3)** the never-worse compare ordered two nonzero `fluid_partition_changed()` counts, but
  the count is cascade-sensitive (first-seen relabeling) — one early merge can outweigh two late
  ones. Fix: attempt-2 rigid relay is kept ONLY when fully clean (pchg==0); any residual change
  restores the ortho attempt-1 result. Only the zero/nonzero verdict is trusted.

## Round-2 review (`wf_876b8a88`, 3 lenses on the hardening delta) — 3 confirmed, all fixed

* **R2-F1 (P2)** SPANLOSS false-positive: the coverage test only checked the tap's inside-endpoint
  against the legs; a tap whose OTHER endpoint lands on a leg (or the L's corner lands on its
  span) keeps the net connected through the tap itself — the false sev-2 then TIE-vetoed flips
  the round-1 machinery would have made (e.g. away from a real MOVPIN/BRIDGE). Fix: other-endpoint
  + corner-on-span coverage checks before flagging. (A REDUNDANT path through distant copper is
  still invisible — heuristic limit, tie-keep = pre-fix outcome, never worse than HEAD.)
* **R2-F2 (P2)** SPANLOSS skipped `sel!=0` wires entirely, but a partial SIBLING follow wire's
  FIXED anchor T-ing our pre-move span is what joins the two nets (its own relay lands on a
  DIFFERENT pin) — the STRAY exemption half of F2 existed without the penalty half → a flip could
  silently split the nets on a pure-axis drag. Fix: SPANLOSS scans partial siblings' fixed
  anchors (rigid-selected wires stay skipped — they travel with the drag). Test 43 D6.
* **R2-F3 (P3)** the partial-sibling STRAY branch lacked a same-junction exemption: a sibling
  grabbed at the SAME pin (moving endpoint == preM) is on our net by construction; its anchor
  contact false-flagged STRAY. Fix: shares-our-junction exemption in both STRAY and SPANLOSS
  partial branches.

## Verification

* `test_wireedit_43_diagonal_fallback_no_short.tcl` (28 checks): baseline + one-shot END drive +
  stepwise RUBBER drive (trace waypoints) + pure-axis sanity + D4 tap-preservation + D5
  sibling-anchor + D6 sibling-T span coverage; connectivity-only asserts (routes may legally be diagonal after the last
  resort). Sabotage-verified: D1/D2 RED on the pre-fix build (the two shorts, both drives), D4
  RED before the SPANLOSS hardening.
* Full wireedit suite 00..43: ALL PASS (44 files; test 39 C2 initially regressed via a STRAY
  false-flag on the rail M lands on — fixed by the touch-M exemption). Trace shows the intended
  mechanics: `elbow: h0=0x2 h1=0x0 -> flip` (own-pin plow avoided) and `attempt=1
  partition_changed=4 -> ROLLBACK to rigid diagonal relay`, `attempt=2 partition_changed=0 ->
  ACCEPT`.
* Real-file replay (`tests/from_user/before_3.sch`, trace waypoints, END (180,-90)): nodemap
  `R18 P=#net2 M=#net1, v8 plus=#net1 minus=OUT, C12 m=#net2` — partition exactly preserved;
  result saved as `tests/from_user/after_5_fixed.sch` (two diagonal relays).
* Full `tests/run_regression.tcl`: 0 FAIL/GOLD?/FATAL (stefan `xschemtest` step fails only when
  xschem is PATH-resolved — SHAREDIR points at /usr/local; pre-existing environmental).
* Valgrind on tests 42/43: 0 errors; identical 35-block environmental residue on both (not the
  fix's snapshot juggling).

## Deferred / follow-ups

* Quality: the last-resort relay leaves DIAGONAL wires where no clean ortho route exists (P2 >
  aesthetics, spec conflict order). A proper multi-bend diagonal-aware reroute (extending Layer 2
  to non-pin-incident straddles, or firing an offset-style V-H-V on diagonal deltas) would restore
  orthogonal routes for scenes like this repro; the mid-drag pure-axis steps already show the
  achievable route (duck under the rail).
* Layer-2 detection still `break`s (declines ALL further straddles) on the first non-pin-incident
  straddle wire it finds (move.c `e1mov == e2mov → break`) — pre-existing, now mostly masked by
  the attempt-2 net.
