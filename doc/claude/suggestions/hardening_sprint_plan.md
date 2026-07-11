# Hardening sprint — atomic step plan

Status: **Track A DONE** (2026-07-11, commits d086a73d..3bdabf0c); Tracks B–D PROPOSED.
Track A yield beyond the planned steps: the A3 fold-in immediately caught a shipped
engine regression (issue 0112, fixed af9075b9 + amnesty hole c2dc1848 — the sprint's
thesis demonstrated on day one), an adversarial review hardened the runners
(0d21208e: $XSCHEM propagation, crash-before-skip, AUDIT_MIN_PASS, failure detail),
and WIRING.md risk §11.13 (corner-slide foreign-landing, needs RED test) was recorded.
A5 proof: sabotage commit a431e959 turned Actions red at the fluid gate with the exact
failing check named in the log; revert 3bdabf0c went green.
(Original baseline: PROPOSED 2026-07-11, branch `fluid-editing`, HEAD 85e0c9c8.)
Source analysis: `doc/claude/WIRING.md` (§11 risks, §12 backlog),
`doc/claude/code_analysis/wiring_support_assessment.md`.

Goal: make connected-drag industrial-strength — bugs **found** at gesture time or by
machine, not by users; bugs **fixed** against single-pass harnesses, not by whole-gesture
forensics. No new routing features during the sprint.

Four tracks, ~2 weeks total. Steps are atomic: each is independently landable,
independently revertable, has a RED-first or sabotage verification, and leaves the tree
green. Order within a track matters; tracks A → B → C → D is the recommended sequence
(A makes everything else trustworthy; B changes the failure mode; C finds bugs; D makes
them cheap to fix). C4 fixture work can proceed in parallel with B.

Conventions that apply to every step:
- RED-first where a behavior changes; sabotage-verify every new checker
  ([[green-but-hollow]]).
- Headless invocation: `./src/xschem --nogui --pipe -q --nolog --script <f>` from repo
  root. Net readback: `xschem resolved_net 0` then `getprop wire <i> lab` — never bare
  `resolved_net` (stamps every wire with the selected net, hides shorts).
- Gesture tests need real X (xvfb in CI); scripted `move_objects dx dy stretch` is
  byte-identical to the release path only — per-motion bugs need waypoint gestures.
- Default-off byte-identical: anything behavior-visible gates on `fluid_editing` (already
  the case for the whole engine; new enforcement adds one more switch, see B1).
- Update `doc/claude/WIRING.md` §11/§12 as steps land.

---

## Track A — CI firewall (R1). ~1 day. Do first; nothing else is trustworthy without it.
**DONE 2026-07-11.** A1 d086a73d · A2 18b159bc · A3 85f37198 (+0112 fix af9075b9,
amnesty c2dc1848) · A4 ae50f70e · A5 d65591c5 (+runner hardening 0d21208e; proof
a431e959 red → 3bdabf0c green). A2 note: the audit summary already printed separate
counts — the step's remaining work was the banner conversion + is_skip/is_pass.

### A1 — Commit the untracked repro corpus
**Problem:** most of the evidence base for issues 0090–0111 exists only in the working
tree (`git status` shows `??`): `tests/from_user/after_10..28*.sch`,
`before_2/4/6.sch`, `before_7_dual_0104rv.sch`, `preferred_12/15.sch`,
`tests/headless/repro_after26.tcl`, plus `beautified_11.sch`. A clean checkout cannot
reproduce the issue history.
**Do:** `git add` the `tests/from_user/*.sch` files and `repro_after26.tcl`; write a
short `tests/from_user/README.md` documenting the naming convention (currently implicit):
`before_N` = user pre-gesture state (N = fixture generation: before_3 → 0085-0090,
before_7 → 0099-0104, before_8 → 0105-0111); `after_M` = the buggy save (global monotone
counter); `preferred_M` = hand-authored desired route (P6 oracle); `after_M_fixed` =
post-fix reference. Exclude scratch logs (`*.log`, `_ctx_*`, `_nhangle_*` stay out).
**Done when:** in a fresh clone, every `from_user/*.sch` referenced under
`tests/headless/` exists —
`grep -rhoE '[A-Za-z0-9_./]*from_user/[A-Za-z0-9_~]+\.sch' tests/headless/ --include='*.tcl' | sed 's|.*from_user/|tests/from_user/|' | sort -u | while read f; do [ -f "$f" ] || echo "MISSING $f"; done`
prints nothing — and the fixture-loading gesture tests (0088/0096/0104) pass when run
from the clone root under X. (The originally proposed `xargs -n1 tclsh` check is
unusable: wireedit scripts need the xschem interpreter — bare tclsh dies with
`invalid command name "xschem"` — and gesture tests self-skip before loading anything.
Note a deleted fixture makes the loading test HANG under `--pipe`, not fail — the
existence grep is the reliable red signal.) **Effort:** 1-2h.

### A2 — Make self-skips report as SKIP, not PASS
**Problem:** gesture tests self-skip without X printing
`RESULT: ALL PASS (0 checks, skipped: no X)`; `full_audit.sh` `is_skip` matches only
`RESULT: SKIP`, so on a display-less box every gesture test counts as a hollow PASS.
**Do:** change the self-skip print in every gesture test (grep
`skipped: no X` under `tests/headless/`) to `RESULT: SKIP (no X)`; extend
`full_audit.sh` `is_skip` to match it; make the audit summary print pass/skip/fail
counts separately.
**Done when:** on a display-less run, audit reports those tests SKIP; sabotage: force
one test to skip, confirm it is not counted as PASS. **Effort:** 1-2h.

### A3 — Fold the wireedit suite into the audit runner
**Problem:** `full_audit.sh` globs only `$HERE/test_*.tcl`; the 52-test
`tests/headless/wireedit/` suite runs only via the manual `run_wireedit.sh`.
**Do:** have `full_audit.sh` invoke `wireedit/run_wireedit.sh` (it already exits nonzero
on fail/no-result) and merge its verdict into the audit exit code.
**Done when:** sabotage one wireedit test (flip an expected coordinate), audit exits
nonzero; revert, exits zero. **Effort:** 1h.

### A4 — Fix cwd-dependent fixture paths
**Problem:** `test_rotate_stretch_*.tcl` load fixtures via cwd-relative
`tests/from_user/...` (silently depend on repo-root cwd); the 0105-0111 tests use the
robust `$HERE`-relative style.
**Do:** convert the rotate-stretch tests (and any other `grep -l 'tests/from_user'
tests/headless/test_*.tcl` offenders) to `$HERE`-relative paths.
**Done when:** `cd /tmp && tclsh <repo>/tests/headless/test_rotate_stretch_short_0104.tcl`
passes (or SKIPs cleanly without X). **Effort:** 1h.

### A5 — Hard-gate the fluid suites in GitHub CI under xvfb
**Problem:** `.github/workflows/ci.yaml` hard-gates only
`full_audit.sh test_sweep_diff test_nogui`; the xvfb audit step is `|| true`
(informational). A fluid regression cannot fail CI.
**Do:** two sub-steps. (a) Run the full audit (now including wireedit per A3, with
correct SKIP accounting per A2) under `xvfb-run -a` in CI and watch it for 2-3 runs for
flakes (WSLg flake notes are local; GH runners under xvfb are typically stable — if a
specific test flakes, mark it with a retry-twice wrapper, don't drop the gate).
(b) Remove the `|| true`.
**Adjusted while landing (2026-07-11):** the flake watch found the full audit is not
flaky but deterministically RED on GH runners — 19 identical failures across runs
(12 FAIL + 7 CRASH/TIMEOUT: ciw/libmgr/descend-view/readonly/select_at/wire_split
class, plus `test_cadence_drag`; full list in the `headless-audit-log` artifacts).
Removing `|| true` wholesale would leave CI permanently red, so per this step's title
the hard gate is the FLUID suites: a new `Fluid suites gate (xvfb)` step runs
`full_audit.sh wireedit test_fluid_* test_rotate_* test_cadence_stretch_move
test_drag_keeps_selection` (glob → new fluid tests auto-gated; all deterministic-green
across the watched runs — under xvfb every gesture test actually runs, 0 skips). The
full audit stays informational with `|| true`; burning down the 19 env failures is
follow-up work outside the sprint.
**Done when:** a PR with a deliberately sabotaged wireedit test goes red in CI; revert
commit goes green. **Effort:** 2-4h incl. flake watch.

---

## Track B — Enforce invariants, stop logging them (P0 minimum). ~2-3 days.
Changes the failure mode: silent saved corruption → immediate visible refusal.
**B1 DONE** c5cb0685 · **B2 DONE** a6ac2026 · **B3 DONE** (this commit) · B4 next.

### B1 — Enforcement switch — DONE c5cb0685
**Do:** add Tcl var `fluid_enforce_invariants` (default **1** — enforcement is the point;
escape hatch for emergencies), read via `tclgetboolvar` at END. Document in
`cadence_style_rc`. No behavior yet — plumbing only.
**Done when:** var readable from C, toggleable at runtime. **Effort:** 1h.
**Landed:** `set_ne fluid_enforce_invariants 1` in xschem.tcl + cadence_style_rc; a
plumbing read + fltrace at the END invariant-check site (FLUID_TRACE shows
`fluid_enforce_invariants=1`). wireedit 52/52 byte-identical. CI fluid gate green.

### B2 — Arm the P2 safety net on every rot-free fluid commit path — DONE
**Problem:** the pure-axis and diagonal `leg_snap` arms require
`fluid_startsel_wires == 0`; a selection containing any wire commits
sight-unseen (`if(!leg_snapped) break`) — documented open hole 0093-D2 /
WIRING.md risk #2, re-opens the fixed 0105/0109 shorts.
**Do:** arm `leg_snap` (nlegs=1) for mixed selections too — rollback-to-pristine is
selection-agnostic; keep the X-then-Y *decomposition* and push-through slide gated
tool-owned-only as today.
**RED-repro CORRECTED while landing:** the planned repro — "box-select R18 + one stub,
drag left along y=0 (after_26 topology)" — does **not** reproduce as written, and two of
its premises were wrong (verified empirically, `--nogui` scripted release path):
  1. Selecting one of R18's OWN follow stubs makes that stub move RIGIDLY (SELECTED, not
     SELECTED1/2), so it no longer stretches — the plow never forms. The gate flip needs a
     *different* wire in the selection (a decoy far from the route), leaving the follow
     stubs tool-grabbed and stretching.
  2. The pure-axis "drag along y=0" is the WORST case for B2, not the demonstrable one: its
     rigid-relay fallback is DEGENERATE (anchor and moved pin stay collinear on the drag
     axis), so the armed ladder engages but **cannot repair** the short — it is only
     REFUSED by B3. Post-B2 that drag still shorts (attempt-1 fallback). So a pure-axis
     mixed drag is a B3 case, not a B2-repairable one.
The actual B2 win (`tests/headless/wireedit/test_wireedit_53_mixed_selection_safetynet_0113.tcl`,
true headless — release-topology short, byte-identical to the gesture release): before_8 +
a DECOY corner wire → `fluid_startsel_wires>0`; drag R18 **diagonally** (-110,-80). RED
(pre-B2): follow stubs plow → R18.P/M merge (device short) committed sight-unseen. GREEN
(post-B2): the ladder rolls the short back and lands the rigid diagonal relay → P/M stay on
distinct nets. P4 is not asserted (the accepted relay may keep one diagonal — WIRING.md §9).
Sweep evidence: of 8 mixed shorts on before_8's delta grid, B2 repairs 5 (diagonal drops);
the 3 residual are pure-axis/near-collinear (B3's job).
**Done when:** new test GREEN; full wireedit + gesture family unchanged (the snapshot
costs one mem-serialize; clean attempt 0 breaks immediately). **Effort:** 0.5-1d
(most of it the RED test).
**Landed:** 4th `leg_snap` arm (move.c, mixed rot-free nlegs==1). RED demonstrated by
stashing the arm (pre-B2 → 2 FAILED). wireedit 53/53 ALL PASS; test 53 memcheck 0 errors.

### B3 — Promote `fluid_check_move_invariants` to rollback-or-refuse — DONE
**Problem:** the real P1/P2/device-merge checker only sets Tcl vars and logs; violations
shipped while it printed them (0094/0098/0099 traces).
**Do:** at real END (not commit_now), when enforcement is on and the checker reports a
violation: restore the gesture-pristine snapshot (follow the restore ritual: ui_state, 4 id
counters, `rebuild_selected_array`, `movelastsel`), pop the gesture's undo push, notify via
`ciw_echo`, leave the schematic untouched. RED-first: WIRING.md risk #1 (label the before_8
backbone `VDD`, run the 0105 gesture): pre-change the short is SAVED; post-change refused,
geometry byte-identical.
**Done when:** RED test flips; every existing green test still green (enforcement never fires
on a clean drag); sabotage: disable one de-shorter, confirm refusal fires. **Effort:** 1d.
**REFUSE SIGNAL CORRECTED while landing (empirical):** the plan said refuse on
`violations || disconnects || dev_merges`, but that premise is wrong two ways:
  1. **The checker fires on 7 PASSING wireedit tests** (00/22/26/27/36/42/43) — it is NOT
     silent on the clean suite. Two (26/27) are the checker's OWN log-only tests; the rest
     hit it on `never-worse` DECLINE sub-cases that legitimately leave a baseline short/
     disconnect (36 d/i/k, 42), or an incidental device short the test ignores (43 D6). So
     "enforcement must never fire on a clean drag" cannot mean "never fire where the checker
     is nonzero" — those drags are dirty by the checker's own measure.
  2. **Refuse on `disconnects` is wrong.** A P1 disconnect is VISIBLE (dangling pin), its
     count is cascade-sensitive (WIRING §5), and the never-worse healers accept a baseline
     disconnect (test_42). Refusing on it would over-refuse legitimate moves. The sprint's
     target is the SILENT saved SHORT, so the gate refuses on **P2 electrical merges only**
     (`shorts + dev_merges`, the checker's new return); disconnects stay log-only.
This narrowing leaves the whole suite green EXCEPT test_wireedit_22 (F5), whose OWN header
predicted "when the no-short guard lands, P2 flips GREEN → update the baseline": F5's short is
a named-net (NETB) merge the de-shorters blackout on, so B3 refuses it and NETA/NETB stay
distinct — baseline updated RED→GREEN as instructed. All the DECLINE sub-cases (36/42/43)
stay green: their "no NEW foreign merge" assertions hold under refuse too (pristine adds
nothing). RED-first proof is self-contained in test_wireedit_54 (drives BOTH switch states:
enforce-0 SAVES the short, enforce-1 REFUSES byte-identical).
**Landed:** `fluid_check_move_invariants` now returns shorts+dev_merges; `enf_snap` pristine
snapshot armed at push_undo, restored on refuse (restore ritual + `cur/head_undo_ptr--` to
drop the undo push, both backends share those counters); ciw_echo notice; set_modify restores
the pre-gesture modified flag. wireedit 54/54 ALL PASS; test 54 memcheck 0 errors. Sabotage:
neuter `fluid_ripup_foreign_pin_short` → the plain-0105 short escapes → B3 refuses (R18 stays
pristine); reverted → repaired again.

### B4 — Count silent fail-safe degradations
**Problem:** every fluid helper silently no-ops when `fluid_snap_pinnet==NULL` or the
pin count drifted — "engine gave up" is indistinguishable from "clean".
**Do:** a per-gesture counter incremented at each fail-safe bail (the ~6 sites:
move.c:2183, 2340, 2383, 5154, 5471, 5716), exported as Tcl var
`fluid_last_move_failsafes` and printed by fltrace at END.
**Done when:** a gesture that adds an instance mid-drag (scripted) reports nonzero;
normal drags report 0. **Effort:** 2h.

---

## Track C — Delta-sweep fuzzer. ~2-3 days. Finds the next 0105 before a user does.
Run after B lands (enforcement reduces fuzzer noise to genuinely-unknown failures).

### C1 — Single-drop harness proc
**Do:** `tests/headless/fuzz/harness.tcl`: proc `fuzz_drop {fixture gesture}` — load
fixture, snapshot nets/geometry, apply gesture (scripted path: `xschem select_at` +
`move_objects dx dy stretch`; transform steps via `xschem rotate/flip` equivalents of the
mid-drag verbs), then run the assertion pack (C2), return verdict + a replayable spec
line. Reuse `wireedit/predicates.tcl`.
**Done when:** one hand-written drop on before_8 reproduces the known-good 0105-fixed
result GREEN. **Effort:** 0.5d.

### C2 — Assertion pack (each with a sabotage variant)
**Do:** five checks per drop: (1) P1/P2 — `instance_nodemap` byte-compare +
`p2_no_short` + `p2_no_device_merge`; (2) Manhattan — `count_diag_wires == 0`;
(3) no novel dangling end — `dangling_eps` post ⊆ pre; (4) no novel copper through any
stationary instance bbox (p5 variant over wires absent from the pre-set); (5) copper
budget — total novel length ≤ k·(|dx|+|dy|) + slack (start k=3, tune).
**Done when:** each check has a sabotage fixture proving teeth (e.g. hand-inject a
diagonal wire → check 2 fires). **Effort:** 0.5d.

### C3 — Sweep driver + failure capture
**Do:** `fuzz_sweep.tcl`: fixtures {before_3, before_5, before_7, before_8} ×
delta ∈ cadsnap·[-15..15]² (stride 1 near zero, 3 farther out) × gesture menu
{plain drag, m-stretch, m+ALT-R, m+ALT-R×2, m+ALT-F, gesture split into two drops}.
Every failure writes a self-contained replay file
(`fuzz_fail_<fixture>_<dx>_<dy>_<gesture>.tcl`) that is itself a runnable RED test —
failures auto-become regression skeletons. Shard by fixture for wall-clock; print a
summary matrix.
**Done when:** full sweep of one fixture completes < ~10 min; deliberately reverting the
0111 fix makes the sweep produce a failing replay file. **Effort:** 1d.

### C4 — Fixture variants targeting the known blind spots (parallel with B)
**Do:** four new fixtures, each one edit away from before_8/before_3:
(a) **labeled rail** — `lab_pin VDD` on the backbone (risk #1: named-rail blackout);
(b) **transistor** — nmos with non-axis-aligned pin pairs (risk #3);
(c) **net-label mover** — a `lab_pin` instance as the dragged object + one near the
route corridor (risk #5); (d) **mixed selection** — R18 + one stub pre-selected
(risk #2, pairs with B2). Add to the sweep matrix. Expect RED — record each RED as an
xfail with the risk number so the sweep stays actionable (xfail flips = tripwire, the
0104 mechanism).
**Done when:** sweep runs all variants; REDs are xfail-classified, not noise.
**Effort:** 0.5-1d.

### C5 — Nightly CI job
**Do:** GH workflow (schedule: nightly) running the sweep under xvfb-less scripted mode
(fuzzer uses the headless path — no X needed), uploading failure replay files as
artifacts. Keep PR CI fast (Track A suites only).
**Done when:** nightly run visible in Actions with summary. **Effort:** 2h.

---

## Track D — Gesture context + pass table (R2+R4). ~1 week. Makes fixes cheap.
Pure refactor: every step must be byte-identical on the full suite (Track A is the net).

### D1 — `Fluid_gesture` struct, snapshots first
**Do:** define `typedef struct {...} Fluid_gesture;` (in move.c initially) holding the
four START snapshots + `npins` (`fluid_snap_pinnet/snap_id/geo_snap_id/start_wire`);
one file-scope instance; mechanical rename of accesses. Add `fluid_gesture_arm()` /
`fluid_gesture_free()` wrapping the existing snapshot/discard functions, asserting
single-free (the 7084-7094 discipline becomes structural).
**Done when:** full wireedit + gesture suites byte-identical; valgrind
(`run_wireedit.sh --memcheck`) clean. **Effort:** 0.5-1d.

### D2 — Fold the hidden-parameter statics into the struct
**Do:** move `fluid_startsel_id/nid`, `fluid_stretch_premove_x/y`,
`fluid_leg_future_dx/dy`, `fluid_slide_pushthrough_on`, `fluid_jog_doomed_from`,
`fluid_manh_doomed_from`, the saved id-counter quad — each with a one-line comment
stating its validity window (one place_moved_wire call / one leg / one attempt /
one gesture). Reset points move into the lifecycle functions where the window allows.
**Done when:** `grep -c '^static.*fluid' move.c` drops accordingly; suites byte-identical;
deliberately skipping `fluid_gesture_free` trips the new assert. **Effort:** 1d.

### D3 — Pass table drives the END cleanup cluster
**Do:** `static const Fluid_pass fluid_end_passes[] = {{name, fn, gates, verify_dir,
mutation_class}, ...}` with gate bits `END_ONLY | ORTHO | FINAL_LEG | ROTFREE_ONLY |
NEEDS_RIPPED`; replace the hand-written block (move.c:6838-6903) with one driver loop.
Order stays the array order — encode today's exact sequence (ripup, shorting-tails,
loops, [!rotfree] anchor-tails, straighten, overshoot, [ripped] orphan-stub). The
`insert_exit_stubs` call and manhattanize stay outside the table for now (different
gates) but get table entries with a `MANUAL_SITE` flag documenting why.
**Done when:** suites byte-identical; fltrace shows identical pass firing sequence on the
0105-0111 repros. **Effort:** 1d.

### D4 — Per-pass observability in the driver
**Do:** driver emits (under FLUID_TRACE) one line per pass: `pass <name>: SKIP(<gate>)` /
`ran, changed=N` — the decline-reason record that would have surfaced 0110's masking
instantly; env `FLUID_TRACE_DUMP=1` additionally dumps the wire array between passes.
**Done when:** trace of a 0106 repro shows the jog's gap-expansion pass firing and each
skip's named gate. **Effort:** 2-3h.

### D5 — Idempotence oracle
**Do:** debug mode (env `FLUID_IDEMPOTENT_CHECK=1`, used by tests): driver runs the
cleanup cluster twice; any second-round change = hard failure with the offending pass
named. This is the 0111 oscillation class as a one-line property. Add to the wireedit
runner for the whole suite.
**Done when:** current suite passes with the check on; reverting the 0111 reschedule
makes it fire on the after_28 repro. **Effort:** 2-3h.

### D6 — Single-pass harness: `xschem fluid_pass <name>`
**Do:** scheduler branch (goes in the matching first-letter dispatch function —
[[scheduler-letter-dispatch]], else silently unreachable): `xschem fluid_snapshot arm`
(runs `fluid_gesture_arm` on current geometry) and `xschem fluid_pass <name>` (runs one
table entry against the current schematic, returns changed-count). First unit test:
build a synthetic 3-wire staircase via `xschem wire`, arm, run `straighten`, assert the
2-segment result — no gesture, no X, milliseconds.
**Done when:** unit test green headless; a second test proves gate enforcement (pass
declines without an armed snapshot). **Effort:** 0.5d.

---

## Sequencing summary

| order | step | effort | unblocks |
|---|---|---|---|
| 1 | A1-A5 CI firewall | ~1d | trust in everything below |
| 2 | B1-B4 enforcement | ~2-3d | corruption → refusal; fuzzer noise floor |
| 3 | C1-C5 fuzzer (+C4 parallel with B) | ~2-3d | machine-found bugs, replay files |
| 4 | D1-D6 context + pass table | ~1wk | cheap fixes, per-pass tests, oscillation oracle |

Exit criterion for the sprint: an escaped wiring bug means "fuzzer gap or predicate gap —
add the case, watch it fail, fix one pass under the harness", not fltrace forensics plus
hand-transcribed waypoints.

Explicitly deferred (revisit after the sprint): move.c split (R5), incremental
connectivity engine (R6/P1), wire birth/purpose metadata (P2), occupancy index (P5),
the Phase-6 A*/Lee solver (blocked on D-track by design), and the WIRING.md §11 risk
burn-down items not covered by C4 fixtures (risks 4, 6-12) — each of those should land
as an xfail gesture test first, then a fix.
