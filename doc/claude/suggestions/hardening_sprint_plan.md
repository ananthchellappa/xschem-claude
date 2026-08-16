# Hardening sprint — atomic step plan

Status: **Track A DONE** (2026-07-11, commits d086a73d..3bdabf0c) · **Track B DONE**
(2026-07-11, commits c5cb0685/a6ac2026/74cda8e0 + B4) · **Track C DONE** (2026-07-11,
C1 261ed06f · C2 57ac013f · C3 37052868 · C4 b9131d21 · C5 c6f69e37); **Track D DONE** —
D1 9d12a067 · D2 0473d845 · D3 98d5e209 · D4 5b2ec840 · D5 f40fd304 · D6 (this commit).
**Sprint complete** (all four tracks A/B/C/D landed).
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

> **A2 CORRECTION, 2026-08-09 (issue 0350).** A2 is landed but was NOT finished, and
> reading it as DONE cost a month. Widening `is_skip` to three tokens while leaving it
> an UNANCHORED substring test over the whole stdout+stderr blob — evaluated *ahead of*
> `is_pass` — created a new false positive: the token appearing anywhere, including
> inside a check NAME a test echoes mid-run, reclassified the whole test as SKIP. Four
> fully-passing suites (59 checks) were being discarded, and since SKIP touches neither
> FAIL nor CRASH and `AUDIT_MIN_PASS` defaults to 0, they were *structurally incapable*
> of failing the audit. A2's own sabotage check ("force one test to skip, confirm it is
> not counted as PASS") could not catch this — it only probes the direction A2 fixed.
> The predicate is now line-anchored, a `has_failure()` guard beats any skip banner, and
> the chain is a testable `classify` verb locked by
> `tests/headless/test_audit_classifier.tcl`. See `doc/claude/issues/0350-*.md`.

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
**B1 DONE** c5cb0685 · **B2 DONE** a6ac2026 · **B3 DONE** 74cda8e0 · **B4 DONE** (this commit).
**Track B COMPLETE** — enforcement now REFUSES silent P2 shorts; mixed selections verified;
silent fail-safe degradations counted. Next recommended track: C (delta-sweep fuzzer).

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

### B4 — Count silent fail-safe degradations — DONE
**Problem:** every fluid helper silently no-ops when `fluid_snap_pinnet==NULL` or the
pin count drifted — "engine gave up" is indistinguishable from "clean".
**Do:** a per-gesture counter incremented at each fail-safe bail, exported as Tcl var
`fluid_last_move_failsafes` and printed by fltrace at END.
**Done when:** a gesture that adds an instance mid-drag (scripted) reports nonzero;
normal drags report 0. **Effort:** 2h.
**Corrections while landing:**
  - *Site count:* the plan's "~6 sites (move.c:2183/2340/2383/5154/5471/5716)" had drifted and
    undercounted — the `!fluid_snap_pinnet || npins<=0` / `fluid_count_pins()!=npins` bail is
    pervasive (~30 guards). Rather than one-off edits, added a `fluid_failsafe(cond)` wrapper
    (counts iff the bail fires, condition unchanged → byte-identical) and wrapped the entry bails
    of the five snapshot-consuming healer passes: `fluid_ripup_foreign_pin_short`,
    `fluid_reroute_around_obstacles`, `fluid_offset_foreign_pin_landing`,
    `fluid_shove_connected_wire`, `fluid_straighten_reversals`. Counter reset at START (next to
    `fluid_snapshot_partition`), published in `fluid_check_move_invariants` at END.
  - *Trigger:* "add an instance mid-drag" only drifts the pin count in the ONE-SHOT
    (`move_objects start … end`) form. A STEPWISE drag's `fluid_reroute_restore` reverts the added
    instance each RUBBER step, so the drift never reaches the healers and the count stays 0. The
    one-shot form (no RUBBER step → END not dirty → no restore) lets the instance persist to the
    healers → they bail (`offset: skip (pin count changed)`) → nonzero.
**Landed:** test_wireedit_55 — clean one-shot AND stepwise drags report 0; a one-shot that adds an
instance reports 7. wireedit 55/55 ALL PASS (byte-identical: the wrapper only counts). Sabotage:
neuter the `++` in `fluid_failsafe` → the drift case drops to 0 (proves the counter is load-bearing);
reverted → 7 again.

---

## Track C — Delta-sweep fuzzer. ~2-3 days. Finds the next 0105 before a user does.
Run after B lands (enforcement reduces fuzzer noise to genuinely-unknown failures).
**C1 DONE** 261ed06f · **C2 DONE** 57ac013f · **C3 DONE** 37052868 · **C4 DONE** b9131d21 ·
**C5 DONE** (this commit). **Track C COMPLETE** — machine-found bugs + replay files; the
fuzzer's headline finds: 0 escaped RED across ~7200 enforced before_* drops (B3 has no gap
there), and a multi-pin DISCONNECT that DOES escape B3 (risk #3, `c4_transistor`).

### C1 — Single-drop harness proc — DONE
**Do:** `tests/headless/fuzz/harness.tcl`: proc `fuzz_drop {fixture gesture}` — load
fixture, snapshot nets/geometry, apply gesture (scripted path: `xschem select_at` +
`move_objects dx dy stretch`; transform steps via `xschem rotate/flip` equivalents of the
mid-drag verbs), then run the assertion pack (C2), return verdict + a replayable spec
line. Reuse `wireedit/predicates.tcl`.
**Done when:** one hand-written drop on before_8 reproduces the known-good 0105-fixed
result GREEN. **Effort:** 0.5d.
**Corrections while landing (empirical, `--nogui` headless):** three plan premises were
wrong, one confirmed:
  1. **Mid-drag rotate/flip IS headless-safe (premise CONFIRMED, was uncertain).** The
     transform verbs are injected while `STARTMOVE` is live via the scripted seam
     `move_objects start <ax> <ay> stretch kissing` → `xschem rotate_in_place`/
     `flip_in_place` (each dispatches `move_objects(ROTATE|ROTATELOCAL / FLIP|ROTATELOCAL)`
     when `ui_state&STARTMOVE`) → `move_objects end <dx> <dy>` (explicit total delta). With
     `has_x==0` the `draw_selection` calls inside those branches are no-ops, so there is NO
     SIGSEGV (the rotate-stretch GESTURE tests self-skip without X only because they drive
     the real callback/draw path). Release==stepwise holds, so a mid-drag rotate is a
     release-topology event the headless path reproduces. `ROTATELOCAL` pivots on the body
     origin, so the start anchor is irrelevant to the drop; the harness anchors at the body
     origin for faithfulness.
  2. **`p2_no_short` (absolute) is UNUSABLE on before_8 (premise WRONG).** before_8 ships a
     benign distinct-net CROSSING — its `#net3` riser (x=-80) crosses the `#net1` backbone
     (y=-40) at (-80,-40) with NO shared endpoint, so `touch()` does not merge them (two
     distinct nets, no electrical short), but `p2_no_short`'s geometric arm uses `seg_touch`
     (bbox overlap), which flags a crossing exactly like a short → 0 on the PRISTINE fixture,
     can never pass. The before_8 wireedit tests (53/54) already sidestep it for this reason.
     So the fuzzer's electrical P2 is **move-relative**: `p2_no_device_merge` (the device
     short) + a before-relative label-survival check (the arm-(b) named-net-merge concern).
     A NEW crossing the *move* introduces is a C2 novelty-scoped QUALITY check, not the hard
     electrical verdict. (This also fixes C2's check (1) — see there.)
  3. **P1 must be name-INVARIANT (premise WRONG).** `instance_nodemap` byte-compare fails on
     a benign `#netN` renumber (traversal-order-dependent, WIRING.md §5) that a reroute
     causes even when the partition is identical — e.g. before_7 + R18 ALT-R (-30,70) (the
     0104 gesture) renumbers but preserves grouping. The harness compares the pin-GROUPING
     partition (set of pin-groups keyed by pin identity, not net name) instead.
  4. **3-way verdict (added).** B3 enforcement REFUSES an unrepairable short, leaving geometry
     pristine — which passes every electrical check (nothing saved) but did NOT route. So the
     verdict is GREEN (landed + clean) / RED (a hard check failed = saved violation) / REFUSED
     (clean but the device did not move by the requested delta). Landing = body origin moved
     by exactly (dx,dy), transform-agnostic (`ROTATELOCAL` keeps origin + adds delta).
**Landed:** `harness.tcl` (fuzz_load/snapshot/apply/assert/drop + fuzz_partition,
fuzz_labels_survive, _fuzz_landed) + self-test `test_fuzz_harness_c1.tcl` (GREEN done-when +
headless-rotate GREEN + REFUSED teeth + RED teeth, ALL PASS). Runs true headless, no X.

### C2 — Assertion pack (each with a sabotage variant) — DONE
**Do:** five checks per drop: (1) P1/P2 — `instance_nodemap` byte-compare +
`p2_no_short` + `p2_no_device_merge`; (2) Manhattan — `count_diag_wires == 0`;
(3) no novel dangling end — `dangling_eps` post ⊆ pre; (4) no novel copper through any
stationary instance bbox (p5 variant over wires absent from the pre-set); (5) copper
budget — total novel length ≤ k·(|dx|+|dy|) + slack (start k=3, tune).
**Done when:** each check has a sabotage fixture proving teeth (e.g. hand-inject a
diagonal wire → check 2 fires). **Effort:** 0.5d.
**Corrections while landing (empirical):** three of the five checks needed a different
metric than the plan named (all documented in `harness.tcl`; sabotage-proven in
`test_fuzz_c2_sabotage.tcl`, 7 checks × {baseline passes, defect fires} = 14 asserts ALL PASS):
  1. **Check (1) is MOVE-RELATIVE electrical, not `p2_no_short` byte-compare** (the C1 fix):
     `instance_nodemap` byte-compare false-REDs on a benign `#netN` renumber (name-invariant
     partition instead), and the absolute `p2_no_short` is 0 on the pristine before_8 (its
     benign #net3×#net1 crossing). So (1) = partition-preserved (name-invariant) +
     `p2_no_device_merge` (before-relative) + label-survival (before-relative). Severity: HARD.
  2. **Check (4) uses the TIGHT symbol box, not the `Instance:` bbox.** `_inst_body_box`
     (predicates.tcl) is inflated by attribute TEXT (documented caveat), so the 0105 backbone
     bump at y=-50 -- which clears R18's real body by 2.5 units but clips its value-text region
     -- false-flagged as a body cross (AMBER on a good drop). Fixed with `_inst_symbol_box_world`
     (the `Symbol:` line from instance_bbox, transformed by a verbatim Tcl port of the ROTATION
     macro). Scoped to NOVEL wires only.
  3. **Check (5) budgets TOTAL-LENGTH GROWTH, not "novel length".** Segset-diff "novel length"
     counts the whole TRANSLATED follow set (every follow wire lands at a novel coordinate) —
     ratio 5-13× the Manhattan distance on CLEAN drops, so k=3 is unusable. Total-length growth
     is the right metric (rigid translation preserves length): measured grow/|man| ∈ [-2,+2]
     across fixtures, so `grow ≤ 3·|man| + 100` clears every clean landed drop with margin.
     (Caveat: a same-length monotone staircase — extra bends, equal length — is a bend-count
     axis this misses; revisit if C3's 0111 revert needs it.)
  Severity model: checks 2-5 are QUALITY (a fail = AMBER route regression, never RED). Verdict
  priority RED > REFUSED > AMBER > GREEN (see C1's 3-way + AMBER).
**Landed:** the 4 quality procs + severity-tagged `fuzz_assert` in `harness.tcl`;
`test_fuzz_c2_sabotage.tcl` proves teeth for all 7 sub-checks. C1 self-test still ALL PASS
(0105/0104 drops GREEN under the full 5-check pack).

### C3 — Sweep driver + failure capture — DONE
**Do:** `fuzz_sweep.tcl`: fixtures {before_3, before_5, before_7, before_8} ×
delta ∈ cadsnap·[-15..15]² (stride 1 near zero, 3 farther out) × gesture menu
{plain drag, m-stretch, m+ALT-R, m+ALT-R×2, m+ALT-F, gesture split into two drops}.
Every failure writes a self-contained replay file
(`fuzz_fail_<fixture>_<dx>_<dy>_<gesture>.tcl`) that is itself a runnable RED test —
failures auto-become regression skeletons. Shard by fixture for wall-clock; print a
summary matrix.
**Done when:** full sweep of one fixture completes < ~10 min; deliberately reverting the
0111 fix makes the sweep produce a failing replay file. **Effort:** 1d.
**Landed + corrections while landing (empirical):**
  - **Speed:** the FULL 4-fixture × 5-gesture × 361-delta sweep (~7200 drops) runs in **62s**
    headless (~15s/fixture) -- far under the 10-min/fixture bar. Baseline (enforce ON, the
    shipped default): **0 RED**, 266 AMBER, 242 REFUSED, 6692 GREEN. The 0-RED is a real
    result: across ~7200 drops the sweep finds NO escaped saved short -- B3 has no gap on these
    fixtures. AMBER is dominated by rotation gestures (rot/rot2) -- the WIRING.md §11 risk #9
    rotation route-quality gap (saved diagonals + extra bends), a known class, not noise.
  - **The 0111-revert done-when is NOT achievable (premise WRONG).** The 0111 bug saves #net3 as
    a 4-segment monotone STAIRCASE where a 2-segment L suffices -- but the staircase is
    same-Manhattan-length (1180 == the L), leaves no dangling end, no body cross, and is even
    GLOBAL-bend-neutral (pristine before_8 has 7 bends; the fixed drop *reduces* to 5 by
    collapsing, the reverted staircase *keeps* 7 -- so "no bend INCREASE" passes both). Catching
    it needs a per-net MIN-BEND oracle (predicates.tcl P6, which the spec says "needs a golden
    oracle") -- out of the delta-sweep's reach. Verified by reverse-applying f1692607's move.c,
    rebuilding, and diffing the fail-sets: reverting 0111 produces ZERO new replay files. The
    0111 class stays covered by its dedicated gesture test test_fluid_exit_stub_staircase_0111.tcl.
  - **Revert-teeth demonstrated the CATCHABLE way instead:** the sweep takes `FUZZ_ENFORCE`;
    setting it 0 REVERTS the B3 fix (log-only), so the drops B3 was REFUSING SAVE their shorts ->
    the sweep's P1/P2 electrical checks catch them as **RED**. On before_8: enforce ON = 0 RED /
    113 REFUSED; enforce OFF = 113 RED / 0 REFUSED, the *same* drops (the enforce-ON REFUSED set
    == the enforce-OFF RED set). So reverting a real fix (B3) DOES make the sweep produce failing
    replay files -- the done-when's intent, with a regression the checks cover. (Bonus: this
    revalidates all of Track B in one command, and fuzzes the raw router B3 normally masks.)
  - **Two harness FPs the sweep surfaced and I fixed** (green-but-hollow discipline applied to
    the fuzzer itself): (i) the `split` gesture halved the delta with `int(dx/2)`, landing a
    5-unit SUB-GRID intermediate that FALSELY shorted (WIRING.md §1.2) -- now each half snaps to
    cadsnap; (ii) the body-cross check false-flagged ~520 drops where the dragged device's OWN
    follow routes clip its body (a 2-terminal device's pins are on the body axis) or a wire on a
    device's OWN net clips that device -- fixed by excluding the dragged target and by a
    NET-AWARE exemption (only FOREIGN copper through a body counts). AMBER 954 -> 266, all real.
  - Replay files self-locate `harness.tcl` and bake the `FUZZ_ENFORCE` mode (else an enforce-off
    RED replays as REFUSED); verified a replay round-trips. `tests/headless/fuzz/fails/` is
    gitignored.
**Landed:** `fuzz_sweep.tcl` (config via env, 4-way GREEN/AMBER/RED/REFUSED matrix, replay
capture, FUZZ_ENFORCE toggle) + `test_fuzz_c3_sweep.tcl` (smoke test: enforce on/off RED
contrast + split grid-snap + replay round-trip, ALL PASS) + harness split/body-cross/enforce
fixes.

### C4 — Fixture variants targeting the known blind spots (parallel with B) — DONE
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
**Landed + corrections while landing:** the four variants are `c4_*` IN-MEMORY builders in
`harness.tcl` (kept in code, not .sch, so the one-edit derivation is obvious), dispatched by
`fuzz_load` and sweepable (`FUZZ_FIXTURES=c4_transistor`, `FUZZ_TARGET=lx`, the new `mixed`
gesture). `test_fuzz_c4_blindspots.tcl` pins 8 xfail tripwires (risk-tagged; a mismatch FAILS
loud with a "blind spot may be FIXED, re-baseline" note). ALL PASS.
  - **"Expect RED" is only true with B3 OFF (premise refinement).** Under the shipped default
    (B3 enforcement ON) most blind-spot shorts are REFUSED (rolled back to pristine), NOT saved
    RED -- so the xfail baseline distinguishes REFUSED (B3 caught it, repair still owed) from RED
    (an ENFORCEMENT GAP) from GREEN (repaired). risks #1/#3a/#5/#2a = REFUSED (enf-on) / RED
    (enf-off); #2b = AMBER (a landing mixed drop keeps a route-quality flag).
  - **The sweep surfaced a real ENFORCEMENT GAP (risk #3, multi-pin).** Dragging the nmos ITSELF
    DISCONNECTS its d/s pins (the 2-pin follow set doesn't cover a 4-pin device) -- a P1
    partition change the C engine itself logs. B3 does NOT refuse disconnects (WIRING.md §9:
    disconnect is log-only, visible, cascade-sensitive), so it SAVES as RED *even under B3*
    (`c4_transistor` target M1 (20,-80), and 1 escaped RED in the plain target-R18 sweep too).
    Pinned as an xfail RED under enf-on -- the headline C4 find, cross-referenced in WIRING §11.3.

### C5 — Nightly CI job — DONE
**Do:** GH workflow (schedule: nightly) running the sweep under xvfb-less scripted mode
(fuzzer uses the headless path — no X needed), uploading failure replay files as
artifacts. Keep PR CI fast (Track A suites only).
**Done when:** nightly run visible in Actions with summary. **Effort:** 2h.
**Landed:** `.github/workflows/fuzz-nightly.yaml` — `schedule: '0 6 * * *'` + `workflow_dispatch`,
separate from `ci.yaml` (PR CI stays Track-A-only). Three steps: build; a GATE running the four
fuzz self-tests (C1-C4 -- the C4 xfail tripwires fail the job loud if a pinned blind-spot verdict
flips, e.g. a repair landing); an informational full sweep (before_3/5/7/8 + the c4_* fixtures,
enforce ON) that never reddens the build (a known xfail RED must not) and uploads every failure
replay file + a summary (also written to `$GITHUB_STEP_SUMMARY`) as the `fuzz-replays` artifact.
**Note (verified against the live repo):** GitHub gates BOTH `schedule` and `workflow_dispatch`
on the workflow existing on the DEFAULT branch (here `main`, not `master`) — a `gh workflow run`
and a raw `POST .../dispatches?ref=fluid-editing` both 404 while the file lives only on
`fluid-editing`. So the nightly (and any manual dispatch) becomes live in Actions once this branch
merges to `main`; that merge is the user's call and out of this sprint's scope. Validated locally
instead: YAML parses, the gate exits 0 (all four self-tests ALL PASS), the sweep emits its matrix
+ replay files. (`ci.yaml` is untouched, so the PR fluid gate is unaffected.)

---

## Track D — Gesture context + pass table (R2+R4). ~1 week. Makes fixes cheap.
Pure refactor: every step must be byte-identical on the full suite (Track A is the net).

### D1 — `Fluid_gesture` struct, snapshots first — DONE
**Do:** define `typedef struct {...} Fluid_gesture;` (in move.c initially) holding the
four START snapshots + `npins` (`fluid_snap_pinnet/snap_id/geo_snap_id/start_wire`);
one file-scope instance; mechanical rename of accesses. Add `fluid_gesture_arm()` /
`fluid_gesture_free()` wrapping the existing snapshot/discard functions, asserting
single-free (the 7084-7094 discipline becomes structural).
**Done when:** full wireedit + gesture suites byte-identical; valgrind
(`run_wireedit.sh --memcheck`) clean. **Effort:** 0.5-1d.
**Landed (this commit):** `Fluid_gesture` struct — 7 fields (`snap_id`/`snap_npins`,
`snap_pinnet`, `geo_snap_id`/`geo_snap_npins`, `start_wire`/`start_nwire`) + one file-scope
instance `fluid_g` in move.c; mechanical rename of all ~177 accesses; `fluid_gesture_arm()`/
`fluid_gesture_free()` wrap `fluid_snapshot_partition`/`fluid_discard_snapshot`. wireedit **55/55**
and the full fuzz sweep (matrix + 216 replay files + 4 self-tests) are **byte-identical** to the
pre-D1 baseline; `run_wireedit.sh --memcheck` reports **0 errors**.
**Premise corrections while landing (as in A/B/C, ~3×):**
  1. *Line numbers drifted* (WIRING/plan anchored at f1692607): snapshot fn is now `move.c:~2397`
     (plan said :2262), discard `:~2447`, invariant check `:~6000` (plan :5869). Anchored by name.
  2. *The single-free "assert" cannot be a hard abort* — the load-bearing correction. The plan assumed
     arm/free pair strictly at START↔END. Reality: a gesture is ALSO legitimately closed by
     `clear_schematic()` (buffer teardown / reload mid-gesture — `test_wireedit_33` case J), which the
     plan didn't list; **wired `clear_schematic` → `fluid_gesture_free()`** (mirroring its existing
     `fluid_reroute_discard` call, `fluid_gesture_free` made non-static + declared in xschem.h) so that
     path closes the context too. FURTHER, two DEFERRED WIRING §11.10 paths (Delete / descend `e`
     pressed mid-STARTMOVE) abandon a gesture without END/ABORT/clear, so a hard `assert(!armed)` would
     turn those pre-existing, out-of-scope bugs into a SIGABRT — contrary to this sprint's
     rollback-not-crash philosophy (cf. B3). So the single-free discipline is enforced as a
     **RECOVER-AND-LOG** tripwire: `fluid_gesture_arm` detects an already-armed context, frees it, and
     `dbg(0)`+`fltrace`s it — no abort. Byte-identical to pre-D1 (which already recovered the leak via
     `fluid_snapshot_partition`'s own leading discard); the tripwire fires only on the leak path (never
     on the clean suite) and is exactly what **D2's "deliberately skip a free" exercises** (grep the
     `dbg`/`fltrace` line, not a crash). `<assert.h>` therefore not added.
  3. *`fluid_startsel_id`/`nid` are NOT move.c statics* — they are `xctx` fields (xschem.h:1272-1273)
     set in `select.c` (`select_attached_nets`, which runs BEFORE move START). D2 lists them to "fold
     into the struct"; they can't move into a move.c-local `Fluid_gesture` without breaking select.c.
     **D2 must treat them separately** (leave in xctx, or promote the struct to xschem.h). Flagged here.

### D2 — Fold the hidden-parameter statics into the struct — DONE
**Do:** move `fluid_startsel_id/nid`, `fluid_stretch_premove_x/y`,
`fluid_leg_future_dx/dy`, `fluid_slide_pushthrough_on`, `fluid_jog_doomed_from`,
`fluid_manh_doomed_from`, the saved id-counter quad — each with a one-line comment
stating its validity window (one place_moved_wire call / one leg / one attempt /
one gesture). Reset points move into the lifecycle functions where the window allows.
**Done when:** `grep -c '^static.*fluid' move.c` drops accordingly; suites byte-identical;
deliberately skipping `fluid_gesture_free` trips the new assert. **Effort:** 1d.
**Landed (this commit):** folded the five genuine move.c hand-down statics —
`fluid_slide_pushthrough_on`, `fluid_leg_future_dx/dy`, `fluid_stretch_premove_x/y`(+`_valid`),
`fluid_jog_doomed_from`, `fluid_manh_doomed_from` (8 vars, 6 decl lines) — into `Fluid_gesture` as
fields, each with a one-line VALIDITY-WINDOW comment. The struct definition moved UP (ahead of
`fluid_slide_push_through`, its first field consumer at ~:1528) so all fluid code sees `fluid_g`.
`grep -c '^static.*fluid' src/move.c`: **99 → 93**. wireedit **55/55** + full fuzz sweep (matrix +
216 replays + 4 self-tests) **byte-identical**; `run_wireedit.sh --memcheck` 0 errors. Tripwire proven:
with the END `fluid_gesture_free()` temporarily commented out, a two-gesture no-reload probe fires the
D1 recover tripwire (dbg) on the 2nd gesture's arm **exactly once** (reverted → 0).
**Premise corrections while landing:**
  1. *Two listed items are NOT move.c statics.* `fluid_startsel_id`/`nid` are `xctx` fields
     (xschem.h:1272-1273) set in `select.c` (`select_attached_nets`); the "saved id-counter quad" is
     `xctx->fluid_reroute_wid/iid/gid/tid` (also `xctx`, Phase-II reroute). Both are cross-file /
     per-window `xctx` state — they can't fold into a move.c-local `Fluid_gesture` without promoting
     the struct to xschem.h (a larger change). Left in `xctx`; only the five genuine move.c statics
     folded. **Promoting `Fluid_gesture` to xschem.h so these + `fluid_startsel_*` join it is a clean
     R2/R5 follow-up** (needed anyway for D6's `xschem fluid_pass`).
  2. *No reset points needed relocating.* Per the reset-point map, all five statics have SUB-gesture
     windows (one attempt / one leg / one place_moved_wire call / one ci-iteration), so none has a
     whole-gesture window that "allows" moving its reset into arm/free. The fold is therefore a PURE
     rename with every write/read/reset left in place — byte-identical by construction. The §7.9
     early-return "leaks" (jog `:4053`, manh `:4367`/`:4472`) are HARMLESS: each watermark is
     re-written before its next read, and the reader `n >= watermark` is equivalent for `-1` and `0`
     over wire indices `>= 0`, so a zero-init `fluid_g` is byte-identical to the old `-1`/`1` inits
     (documented in the struct header). "Skipping `fluid_gesture_free` trips the **assert**" is met by
     the D1 **recover tripwire** (dbg/fltrace), per D1 correction #2 — not a hard abort.

### D3 — Pass table drives the END cleanup cluster — DONE
**Do:** `static const Fluid_pass fluid_end_passes[] = {{name, fn, gates, verify_dir,
mutation_class}, ...}` with gate bits `END_ONLY | ORTHO | FINAL_LEG | ROTFREE_ONLY |
NEEDS_RIPPED`; replace the hand-written block (move.c:6838-6903) with one driver loop.
Order stays the array order — encode today's exact sequence (ripup, shorting-tails,
loops, [!rotfree] anchor-tails, straighten, overshoot, [ripped] orphan-stub). The
`insert_exit_stubs` call and manhattanize stay outside the table for now (different
gates) but get table entries with a `MANUAL_SITE` flag documenting why.
**Done when:** suites byte-identical; fltrace shows identical pass firing sequence on the
0105-0111 repros. **Effort:** 1d.
**Landed (this commit):** 9-entry `fluid_end_passes[]` (7 driver-run + 2 MANUAL_SITE) +
per-entry issue-history/contract comments (moved from the call site), `Fluid_verify_dir` /
`Fluid_mut_class` enums (WIRING §5 taxonomy made structural; D3 driver does not consult
them — they are the D5/D6 hooks), and one driver loop replacing the hand-written cluster.
Heterogeneous signatures solved as planned-risk predicted: uniform `int (*fn)(void)`; the
six void passes get one-line adapters (`fluid_pass_*`, exact old calls); ripup keeps its
int return, threaded via a new `SETS_RIPPED` bit into the driver's `ripped` flag consumed
by `NEEDS_RIPPED`. Driver re-checks END_ONLY/ORTHO/FINAL_LEG (guaranteed by the enclosing
site gate — provably no-op, keeps the bits executable) + the per-pass bits, and fltraces
`pass <name>: run (rotfree=%d ripped=%d)` per firing (the D3 firing-sequence proof; fuller
SKIP/changed observability is D4). Verified: wireedit 55/55 + memcheck 0 errors; full fuzz
sweep matrix (every per-fixture row) + 216 replay files byte-identical (re-baselined
against a stashed pre-D3 build for the row-level compare); 4 fuzz self-tests ALL PASS;
fltrace on the 0105 drag (`ripped=1` → orphan-stub fires, anchor-tails skipped rotfree)
and the 0111 NW drag (`ripped=0` → orphan-stub skipped) byte-identical to pre-D3 after
filtering the new `FLTRACE pass` lines.
**Premise corrections while landing (~3×, as in every prior step):**
  1. *Line numbers drifted again*: the hand-written block was at move.c:7062-7127 (plan
     said 6838-6903); anchored by the step-9 cluster gate + issue comments. The table +
     driver land after `fluid_manhattanize_relay_diagonals` (~:4544) / in the cluster.
  2. *The plan's `ROTFREE_ONLY` bit matches NO driver-run pass.* Today's only inline
     rotation gate in the cluster is `if(!rotfree) fluid_prune_anchor_tails()` — a
     **rotated-only** pass (0110 un-gated straighten/overshoot from rotfree; the
     translation path never strands 0103 tails). Encoding it as ROTFREE_ONLY would invert
     the gate. Added **both** bits: `ROTATED_ONLY` (prune_anchor_tails) and
     `ROTFREE_ONLY` (used only by the `insert_exit_stubs` MANUAL_SITE entry, whose real
     site gate is rot==0&&flip==0).
  3. *`insert_exit_stubs` differs from the cluster by MORE than the plan's "different
     gates"*: it is **not END-only** (it also runs on every live RUBBER commit — each
     step restores from pristine and re-inserts), fires for `wire_exit_stub` users with
     fluid_editing OFF, and owns a trailing `check_collapsing_objects` sweep. Its entry
     carries ORTHO|FINAL_LEG|ROTFREE_ONLY|MANUAL_SITE (no END_ONLY) and documents all
     three. The jog (`fluid_jog_pin_off_backbone`) got **no** entry: it is an internal
     per-pin subroutine of ripup with args (qx,qy,vertaxis) — documented on ripup's
     entry, per "ripup (+jog)".

### D4 — Per-pass observability in the driver — DONE
**Do:** driver emits (under FLUID_TRACE) one line per pass: `pass <name>: SKIP(<gate>)` /
`ran, changed=N` — the decline-reason record that would have surfaced 0110's masking
instantly; env `FLUID_TRACE_DUMP=1` additionally dumps the wire array between passes.
**Done when:** trace of a 0106 repro shows the jog's gap-expansion pass firing and each
skip's named gate. **Effort:** 2-3h.
**Landed (this commit):** three trace-only helpers after the pass table (nothing runs unless
`fluid_trace_on()`, so byte-identical with tracing off — the D3 guarantee preserved): (1)
`fluid_pass_skip_gate()` returns the gate-bit NAME of the first failing check in the driver's
short-circuit order (or NULL) — now the SINGLE source of truth for both the driver's skip/run
control flow AND the `SKIP(<gate>)` trace label, so they can't drift; (2) `fluid_wsig_snapshot`/
`fluid_wsig_diff` — a per-wire geometry signature keyed by the session-stable `wire[].id`
(endpoints ordered so a bare `order_wire_coords` swap isn't a change), diffed pre/post-pass into
`changed=N` (adds+deletes+moves); (3) `fluid_dump_wires()` gated on BOTH FLUID_TRACE and the new
`FLUID_TRACE_DUMP` (cached like `fluid_trace_on`). Driver: `traced = fluid_trace_on()` picks a
fast path (no snapshot/malloc, byte-identical to D3) vs the measured path; emits
`pass <name>: SKIP(<gate>)` or `ran, changed=N (rotfree ripped wires nb->na)`, and dumps the wire
array at cluster entry + after each ran pass when FLUID_TRACE_DUMP=1. Done-when met — the 0106
drag (0,-40) trace shows `ripup_foreign_pin_short: ran, changed=5 (... ripped=1 wires 15->18)`
(the jog gap-expansion fired), `prune_anchor_tails: SKIP(ROTATED_ONLY)`,
`straighten_reversals: ran, changed=10 (wires 18->13)`, and both MANUAL_SITE entries as
`SKIP(MANUAL_SITE)`. Verified: wireedit 55/55 (+ memcheck 0 errors); full fuzz sweep matrix +
216 replays byte-identical to D3; the trace-ON malloc path is memcheck-clean under the project
policy (`--leak-check=no --track-origins`, rc=0, 0 errors) and appears in ZERO valgrind stacks
(the only `definitely lost` block is identical trace-on/off, i.e. pre-existing — the reason the
suite runner uses `--leak-check=no`).

### D5 — Idempotence oracle — DONE
**Do:** debug mode (env `FLUID_IDEMPOTENT_CHECK=1`, used by tests): driver runs the
cleanup cluster twice; any second-round change = hard failure with the offending pass
named. This is the 0111 oscillation class as a one-line property. Add to the wireedit
runner for the whole suite.
**Done when:** current suite passes with the check on; reverting the 0111 reschedule
makes it fire on the after_28 repro. **Effort:** 2-3h.
**Landed (this commit):** `fluid_end_cluster_idempotence_probe()` re-runs the cluster once and
flags any pass that still changes the wire GEOMETRY SET (id-independent multiset compare via
`fluid_wsig_geom_changed` + `fluid_wsig_cmp` — a delete+re-add of the same span is still a
fixpoint, so an id churn is not a false violation), naming the first offender to stderr
(`FLUID_IDEMPOTENCE_VIOLATION: pass <name> ...`, live in the --nogui path), fltrace, and the Tcl
var `fluid_idempotence_violation`. `fluid_idempotent_check_on()` caches the env (off => the probe
never runs => byte-identical to D4). `run_wireedit.sh --idempotent` runs the whole suite under the
oracle and fails any test that emits the violation token. Done-when met both ways: (1) the current
suite is a fixpoint — `run_wireedit.sh --idempotent` = 55/55 ALL PASS, "fixpoint clean"; (2) teeth
demonstrated by temporarily reverting the 0111 reschedule (`if(0 && ...)` on the near-pin branch,
straighten.c region) — the 0111 NW-drag repro then prints
`FLUID_IDEMPOTENCE_VIOLATION: pass straighten_reversals ...` (reverted immediately; the fixed build
is clean again). Verified: wireedit 55/55; full fuzz sweep matrix + 216 replays byte-identical to
D3; the oracle-ON 2nd-run path is memcheck-clean (rc=0) on the 0106 and 0111 repros.
**Premise correction while landing (1×):** *the plan's "runs the cleanup cluster twice" must
re-run it AFTER `insert_exit_stubs`, not right after the cluster.* The 0111 oscillation is
CROSS-pass (cluster `straighten` collapses onto the pin ⇄ MANUAL_SITE `insert_exit_stubs` re-jogs
one grid off). A 2nd cluster run positioned INSIDE the cluster block (before exit stubs) sees the
already-collapsed geometry and finds nothing to change — it MISSES 0111. The probe is therefore
called just after the `insert_exit_stubs` block (round 1 = full finalization; round 2 re-runs the
cluster over the finalized route and catches `straighten` re-collapsing the exit-stub's re-jog),
gated identically to the cluster so it runs exactly when round 1 did.

### D6 — Single-pass harness: `xschem fluid_pass <name>` — DONE
**Do:** scheduler branch (goes in the matching first-letter dispatch function —
[[scheduler-letter-dispatch]], else silently unreachable): `xschem fluid_snapshot arm`
(runs `fluid_gesture_arm` on current geometry) and `xschem fluid_pass <name>` (runs one
table entry against the current schematic, returns changed-count). First unit test:
build a synthetic 3-wire staircase via `xschem wire`, arm, run `straighten`, assert the
2-segment result — no gesture, no X, milliseconds.
**Done when:** unit test green headless; a second test proves gate enforcement (pass
declines without an armed snapshot). **Effort:** 0.5d.
**Landed (this commit):** two `xschem_cmds_f` branches — `xschem fluid_snapshot arm` →
`fluid_harness_snapshot_arm()` (returns 1 if a valid START snapshot was taken), `xschem fluid_pass
<name>` → `fluid_harness_run_pass()` (looks the name up in `fluid_end_passes[]`, runs its fn,
returns the D4 changed-count; 0 on fail-safe decline; errors on an unknown or MANUAL_SITE name).
Both declared in xschem.h. The harness re-establishes the driver's precondition
(`prepare_netlist_structs(0)` before the pass) so a cold call sees a current pin table. New headless
test `test_wireedit_56_fluid_pass_harness_d6.tcl` (8 checks ALL PASS): a synthetic 3-segment
staircase (0,0)→(0,10)→(10,10)→(10,20) armed + `fluid_pass straighten_reversals` collapses to the
2-segment L (0,0)-(10,0)-(10,20) [changed=3]; gate enforcement (no armed snapshot → declines,
changed=0, geometry unchanged); arm on a pin-less scene → 0; unknown / MANUAL_SITE names error.
Verified: wireedit 56/56 (plain + `--idempotent`, both ALL PASS); full fuzz sweep matrix + 216
replays byte-identical to D3 (the harness adds verbs + functions, the move_objects driver is
untouched); the new harness malloc/reshape path is memcheck-clean (0 errors).
**Premise corrections while landing (2×):**
  1. *The plan's arm-order is imprecise.* "build a staircase, arm, run straighten" declines: the
     START wire snapshot must be NON-EMPTY for `fluid_wire_is_novel_span` to discriminate (a
     zero-wire baseline returns "nothing is novel", a deliberate safety default), and the snapshot
     needs ≥1 instance pin (`fluid_count_pins()>0`, else `fluid_snapshot_partition` no-ops). So the
     scene arms on a pristine baseline (an off-to-the-side res for the pin + one baseline wire)
     BEFORE adding the novel staircase — the correct gesture analogue (START snapshots the pre-drag
     state; the drag makes the novel copper). The plan's arm/run order and the "no instance needed"
     implication were both wrong.
  2. *Cold passes need `prepare_netlist_structs(0)` first.* The driver runs it before the cluster;
     a standalone `fluid_pass` call must refresh the pin table / node[] itself or `point_on_any_pin`
     reads a stale table and the pass mis-declines. Folded into `fluid_harness_run_pass`.

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
