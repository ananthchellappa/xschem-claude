# Fluid-editing terminology — coined names and what they mean

A glossary of the working vocabulary of the fluid-editing / nice-drag-rerouting thread
(branch `fluid-editing`). Names arose in issue docs, adversarial review rounds, and session
notes; source comments and tests use them freely, so this is the decoder ring.

Related docs: `doc/claude/specs/incremental_wire_reroute.md`, `doc/claude/specs/nice_drag_rerouting.md`,
issues `0081`, `0083`, `0085`. Last updated 2026-07-08 (issue 0085 hardening).

## Core model (spec-level)

| Name | Meaning |
|---|---|
| **P1..P8 predicates** | "Nice" pinned as testable predicates: P1 connectivity, P2 no-short (both HARD); P3 escape-perp, P4 orthogonal, P5 no-body-cross, P6 min-bend/length, P7 stability, P8 determinism (quality). Conflict order **P1=P2 > P3 > P5 > P4 > P7 > P6**. Tcl library `tests/headless/wireedit/predicates.tcl`. |
| **rip-up-and-reroute / follow set** | Wires attached to the moving selection are TOOL-OWNED and re-derived (ripped up and re-laid) each snap step, not translated user selection. User owns only what they explicitly selected. |
| **terminal of the selection** | Generalized "instance pin": any connection point of a selected object that a non-selected wire touches — the boundary cut-set the reroute works on. |
| **release == stepwise** | Phase-II invariant: the END result must equal the accumulated RUBBER-step result. Achieved by restoring a pristine snapshot each step and re-applying the TOTAL delta; every routing decision must be a pure function of (START snapshot, geometry, delta). |
| **partition oracle** | START-time snapshot of the instance-pin→net partition as canonical first-seen ids (`fluid_snapshot_partition` / `fluid_partition_changed`, move.c). Rename-proof (auto `#net` renames give an identical vector); detects merges AND disconnects. The zero/nonzero verdict is exact; the per-pin diff COUNT is not (see cascade-count metric trap). |
| **decline-to-baseline / never-worse** | Discipline for every smart pass: any failed safety condition stands down and leaves the naive result — a pass may only ever improve on what the naive machinery produced, never add damage. |
| **connect-by-kissing** | xschem's intentional drop-onto-copper merge. Why "partition changed" is not automatically a bug: the user may have MEANT the merge, and every fallback attempt reproduces it. |
| **FLUID_TRACE** | Env-gated per-decision trace facility (`fltrace()`, move.c). `FLUID_TRACE=<path> src/xschem ...` writes a dedicated file (NOT stderr — GUI launch freopens stderr to /dev/null). Off by default = one cached int compare. Traces gates, per-leg deltas, elbow hazard masks, offset-pass detect/fire/decline, attempt-ladder verdicts. |

## Routing machinery (move.c)

| Name | Meaning |
|---|---|
| **L elbow / orientation (ml)** | The manhattan jog `place_moved_wire` lays for a stretched wire: H-then-V or V-then-H, selected by `xctx->manhattan_lines` (1/2). "Elbow choice" = which orientation. |
| **Layer 1** | Obstacle-aware elbow flip inside `place_moved_wire` (Phase III): if the chosen orientation is hazardous and the other is clean(er), flip `manhattan_lines`. Since 0085 driven by `fluid_ml_hazards`/`fluid_mlh_sev` (was `fluid_ml_blocked`, bridge-only). |
| **Layer 2** | `fluid_reroute_around_obstacles`: rip up a wire straddling a stationary device and route the moving pin AROUND it with a stop-short junction. |
| **Layer 3** | Outward-stepping detour-row search when Layer 2's one-grid-outside rows are both blocked; capped by the schematic's perp-axis obstacle extent. |
| **straddle** | One wire covering TWO distinct-pre-move-net pins of a stationary device — the canonical P2 short (R18's leg through ammeter v8). |
| **non-pin-incident straddle** | A straddling wire with NO moving-pin endpoint (e.g. the stored L leg anchor→corner). Layer-2 detection requires exactly one moving-pin endpoint (`e1mov == e2mov → break`, and the break aborts ALL further reroutes) → declines. Known deferred gap, mostly masked by the 0085 attempt ladder. |
| **shove** (issue 0015) | `fluid_shove_connected_wire`: a connected perpendicular stub the moving pin drove past is PUSHED ahead of the pin instead of being plowed through (serves P5). |
| **corner-slide** | Wire-editing Phase 4: on an axis-aligned move, a perpendicular attached wire forming a corner SLIDES with the pin instead of jogging at the moved end. |
| **exit stub / escape normal** | P3 machinery: each moved device pin leaves along its outward escape normal (`get_pin_escape_normal`, nearest-bbox-edge geometry — no symbol property, per user decision) with a short stub before the first bend (`insert_exit_stubs`). |
| **two-leg / X-then-Y decomposition** (issue 0081) | A diagonal fluid delta is split into a fixed X-leg then Y-leg — each a pure-axis move the existing machinery handles — with the P2 safety net (attempt loop) rolling back to a single diagonal pass if the composite changes the partition. |
| **offset solder-joint / V-H-V rebuild** (issue 0083) | When a follow-wire landing buries the junction on/inside a stationary device: rebuild the leg as V-H-V with the riser one grid OFF the body and a visible degree-3 solder dot one grid outside, plus a short stub to the pin. |
| **far-pin landing** (issue 0083) | The drag corner lands ON or PAST the device's far (distinct-net) pin; the offset pass's unbounded trigger + removed-span/exact-match hardening repair it. |
| **removed-span strand** (0083 review) | A rebuild deletes naive row copper whose interior fed a tap or a same-net pin → P1 disconnect. Guarded by `fluid_removed_span_unsafe`; conceptual ancestor of 0085's SPANLOSS. |

## Issue 0085: "blind-elbow diagonal fallback"

The 0081 last-resort single diagonal pass picked L elbows blind to whole short classes and
committed the result with no partition re-check (`before_3.sch` → `after_5.sch`).

### Hazard classes (`fluid_ml_hazards` bitmask)

| Name | Meaning |
|---|---|
| **BRIDGE** (`FLUID_MLH_BRIDGE`) | The original Layer-1 class: L covers two distinct-pristine-net pins of one stationary device. |
| **own-pin plow / MOVPIN** | An L leg runs over a CO-MOVING pin (tested at post-move = live + delta; the ELEMENT commit loop runs after the wire pass) on a different pristine net — typically the moved device's own other pin (R18.P's riser through R18.M). Floating pins count: auto-`#net` pristine names are non-empty. |
| **lone foreign pin / FPIN** | A single stationary foreign-net pin under a leg — a merge without a full device bridge. Includes an explicit net-LABEL pin scan (labels are skipped by every shared helper — "label blindness", round-1 F3). |
| **stray wire-endpoint T / STRAY** | A stationary wire's endpoint lands on a leg (or the L corner lands on a stationary wire, or a partial SIBLING's fixed anchor lands on a leg) — a connecting T whose net is not cheaply known. Heuristic band. The C12-stub short in the repro. |
| **span-loss / SPANLOSS** | The orientation abandons the wire's PRE-move span A..preM while attachments sit strictly INSIDE it (stationary tap endpoint, partial sibling's fixed anchor, mid-span-fed stationary pin) and nothing re-covers them → tap stranded, P1 disconnect. Verified band, so it TIES against e.g. a MOVPIN on the covering orientation (keep ml0 = pre-fix outcome). |

### Selection rule

| Name | Meaning |
|---|---|
| **verified vs heuristic severity bands** | `fluid_mlh_sev`: BRIDGE/MOVPIN/FPIN/SPANLOSS (pristine-net/geometry verified) = 2; STRAY (heuristic, can false-flag) = 1. Flip ONLY to a strictly lower severity; ties keep ml0; both-clean falls to the P6 min-bend bias. |
| **touch-A / touch-M exemption** | A wire touching the anchor A (pre-connected) or M (the pin LANDING merges it in every orientation) contributes no orientation-dependent hazard. The touch-M half is the test_39 C2 regression trap (M dropped mid-span on a rail must not stray-flag the rail). |
| **pre-move-span exemption** | A wire tapping the stretched wire's own A..preM span was already connected pre-move → never a stray hazard (round-1 F2; flagging it caused the tap-strand disconnect). |
| **shares-our-junction exemption** | A partial sibling grabbed at the SAME pin (its moving endpoint == preM) is on our net by construction → exempt in both STRAY and SPANLOSS (round-2 R2-F3). |

### Attempt ladder (move_objects commit region)

| Name | Meaning |
|---|---|
| **attempt ladder** | For a decomposed diagonal gesture, EVERY attempt is partition-checked: attempt 0 = two-leg decomposition; attempt 1 = single ortho diagonal pass; attempt 2 = rigid diagonal relay. Pre-0085 only attempt 0 was checked. |
| **rigid diagonal relay** | Attempt 2: `leg_ortho=0` + `manhattan_lines=0` → `place_moved_wire`'s else-branch just translates the moved endpoint. Wire goes diagonal; NO new copper, NO elbow to land on anything. Correctness over aesthetics (P2 > P4/P6). |
| **clean-or-revert** | The relay is kept ONLY when the partition is fully unchanged (pchg==0); any residual change restores the snapshotted ortho attempt-1 result (`alt_snap`, with its own id counters). |
| **cascade-count metric trap** (round-1 F5) | `fluid_partition_changed()`'s per-pin diff count is cascade-sensitive: first-seen relabeling makes ONE early-walk merge relabel every later net's pins, outweighing TWO late merges. Never ORDER two nonzero counts; only zero/nonzero is trustworthy. |

### Review-round finding names

| Name | Meaning |
|---|---|
| **tap-strand disconnect** (round-1 F2) | STRAY false-flagged a tap on the wire's own pre-move span; the flip away from re-covering the span left the tap dangling (P1). Fixed by pre-move-span exemption + SPANLOSS. Test 43 D4. |
| **sibling follow-wire anchor** (round-1 F1, round-2 R2-F2) | A partially-selected sibling follow wire's FIXED endpoint is a real stationary contact that both STRAY and SPANLOSS originally skipped wholesale (`sel != 0`). STRAY now tests it as a contact (D5); SPANLOSS now counts it as a strandable attachment (D6) — its own relay lands on a DIFFERENT pin, so the T onto our span is what joined the two nets. |
| **label blindness** (round-1 F3) | All hazard classes inherited the shared helpers' `type=="label"` skip, but a stationary label pin under a leg names/merges the copper beneath it. Fixed with an explicit label scan → FPIN (nf known) / STRAY (nf unknown). |
| **nf-unknown downgrade** (round-1 F4) | When M is not a moving-instance pin (wire-junction grab), the follow net nf is unknown; MOVPIN/label hits can't verify distinctness and degrade to the heuristic STRAY band instead of a false verified sev-2. |
| **SPANLOSS coverage false-positive** (round-2 R2-F1) | The strand test only checked the tap's inside-endpoint against the legs; a tap whose OTHER endpoint lands on a leg (or the corner lands on its span) stays connected through the tap itself. Fixed with other-endpoint + corner-on-span coverage checks. A REDUNDANT path through distant copper remains invisible — accepted heuristic limit (tie-keep = pre-fix outcome). |

## Process / discipline names

| Name | Meaning |
|---|---|
| **green-but-hollow** | A passing suite that never exercised the changed code path. Struck three times in 0083 (+10 tested, +20 missed; pure-axis tested, diagonal missed; near-pin tested, far-pin missed). Antidote: sabotage-verify (break the fix, prove the test goes RED) and drive the user's REAL gesture magnitudes. |
| **sabotage-verify** | Deliberately revert/damage the fix and confirm the regression test fails — proof the test has teeth. |
| **RED-first** | Write the failing regression before (or verified against) the pre-fix build, then fix to green. |
| **adversarial review round** | Multi-agent workflow: independent attack lenses over the diff, then per-finding skeptical refute-verify (finding survives only if verifiers can trace the failure concretely). 0083 and 0085 each went through two rounds; every confirmed finding is named above. |
| **from-user repro files** | `tests/from_user/before_N.sch` / `after_N.sch`: the user's saved pre/post schematics of a real GUI gesture, plus (since 0085) `after_N_fixed.sch` = the same replayed gesture on the fixed build. |
