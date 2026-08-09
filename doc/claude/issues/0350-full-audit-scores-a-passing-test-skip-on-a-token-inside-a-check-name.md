# 0350 — full_audit scores a passing test SKIP because a token appeared inside a check name

Status: FIXED for the reported defect — item closed **E** (a human must look; see
        "Still open" and issue 0354, which the fix does not cover)
Area: tests/headless/full_audit.sh (harness classifier)
Found: 2026-08-09, unattended backlog run, item D1
Related: 0148 (scratch leaks), 0147 (hollow green), 0351, 0352, 0353, 0354

## Symptom

`tests/headless/full_audit.sh` classified four fully-passing suites as SKIP and
therefore discarded 59 green checks:

    $ env -u DISPLAY tests/headless/full_audit.sh test_save_reload_copy_selflog \
          test_descend_goback_selflog test_key_make_sch_from_sel_log test_delete_cut_selflog
    SKIP     | test_save_reload_copy_selflog
    SKIP     | test_descend_goback_selflog
    SKIP     | test_key_make_sch_from_sel_log
    SKIP     | test_delete_cut_selflog
    SUMMARY: 0 pass  0 fail  0 crash/timeout  4 skip  (total 4)

Run directly, the same four print `RESULT: ALL PASS` with 25 / 26 / 3 / 5 `ok:` lines.

## Cause

`is_skip()` (full_audit.sh:116-117 pre-fix) was three UNANCHORED bash substring
tests over the whole merged stdout+stderr blob, evaluated BEFORE `is_pass`
(:199 vs :201). Any occurrence of `RESULT: SKIP` / `skipped: no X` /
`SKIP: no X connection` anywhere — including inside a check NAME echoed mid-run
by `proc check` — reclassified the entire test as SKIP.

SKIP increments only SKIP (:200), the exit gate is `FAIL+CRASH > 0` (:243), and
`AUDIT_MIN_PASS` defaults to 0 (:254). So such a test is **structurally
incapable of failing the audit**. Proved end-to-end with a throwaway probe: a
test printing an explicit `FAIL:` line and exiting 1 was scored SKIP and the
audit exited 0.

The six live call sites: test_save_reload_copy_selflog.tcl:139/205/280,
test_descend_goback_selflog.tcl:212, test_delete_cut_selflog.tcl:77,
test_key_make_sch_from_sel_log.tcl:81.

## Fix

1. `is_skip()` is now a line-anchored grep — the banner counts only at column 0.
2. New independent `has_failure()`; the skip arm is `is_skip && ! has_failure`,
   so a FAIL line always beats a skip banner.
3. The classification chain is lifted into a `classify NAME OUT EC` verb so the
   ORDERING is testable; the run loop keeps only counter bookkeeping.
4. `AUDIT_LIB_ONLY=1 . full_audit.sh` defines the predicates and returns without
   running an audit, so they can be regression-locked.

Locked by `tests/headless/test_audit_classifier.tcl` (19 checks), which carries a
deliberate LIVE CANARY: one check whose name contains `skipped: no X`.

---

# Verification record (write-up agent, 2026-08-09)

**Item status: E — landed and committed, but a human must look.** Not `x`: the
adversary pass refuted the central claim's completeness and the refutation was
independently reproduced (see "Still open" and issue 0354). Not `F`/reverted:
nothing regressed, no PASS-classified test can move, and reverting would restore a
measured defect that discards 59 green checks. Reasoning ladder rung **R2** —
smallest blast radius, least surprising.

## BEFORE (measure agent, verbatim)

    $ env -u DISPLAY tests/headless/full_audit.sh test_save_reload_copy_selflog test_descend_goback_selflog test_key_make_sch_from_sel_log test_delete_cut_selflog
    SKIP     | test_save_reload_copy_selflog
    SKIP     | test_descend_goback_selflog
    SKIP     | test_key_make_sch_from_sel_log
    SKIP     | test_delete_cut_selflog
    SUMMARY: 0 pass  0 fail  0 crash/timeout  4 skip  (total 4)

    $ d=$(mktemp -d); env -u DISPLAY ./src/xschem --pipe -q --logdir "$d" --script tests/headless/test_save_reload_copy_selflog.tcl
    ok:   keyboard/ctx-menu copy (skipped: no X)  (no display)
    RESULT: ALL PASS          <- test_save_reload_copy_selflog, 25 'ok:' lines
    RESULT: ALL PASS          <- test_descend_goback_selflog, 26 'ok:' lines
    RESULT: ALL PASS          <- test_key_make_sch_from_sel_log, 3 'ok:' lines
    RESULT: ALL PASS          <- test_delete_cut_selflog, 5 'ok:' lines   (59 real green checks discarded in total)

    # temporary probe printing a FAIL line and exiting 1:
    SKIP     | test_zzz_audit_probe
    SUMMARY: 0 pass  0 fail  0 crash/timeout  1 skip  (total 1)
    AUDIT_EXIT=0                 <- a test that printed FAIL and exited 1 leaves the audit green

## AFTER (verify-A, verbatim)

    PASS     | test_save_reload_copy_selflog
    PASS     | test_descend_goback_selflog
    PASS     | test_key_make_sch_from_sel_log
    PASS     | test_delete_cut_selflog
    SUMMARY: 4 pass  0 fail  0 crash/timeout  0 skip

    honest wholesale self-skips, unchanged: SKIP test_grid_toggle_sel_gc, SKIP test_ase_dirty,
    SKIP test_graph_box_zoom_xy, PASS test_ase_savestate_adopt, PASS test_sweep_diff
    (SUMMARY: 2 pass  0 fail  0 crash/timeout  3 skip)  -- no hollow PASS

    new CI headless gate, run verbatim, DISPLAY unset:
    SUMMARY: 15 pass  0 fail  0 crash/timeout  0 skip  (total 15)   exit 0

**Full-tree re-sweep**, one instrumented 296-test run carrying both the pre-fix
chain and the new `classify()` over identical captured output: old 150 PASS / 13
FAIL / 62 CRASH / 71 SKIP → new 155 PASS / 13 FAIL / 62 CRASH / 66 SKIP. Exactly
5 rows differ, **all SKIP→PASS**; zero PASS→anything, zero SKIP→FAIL, FAIL and
CRASH counts identical. The 5th row is `test_audit_classifier` itself — the defect
reproducing on the file written to lock it.

All 14 driver tier rows re-measured by **direct binary invocation** (unaffected by
a harness change) and identical to baseline: 421 / 376 / 178 / 171 / 157 / 115 /
32 / 21, the three OVERALL-only suites, wireedit ALL PASS, run.sh 6 goldens,
run_regression exactly 3 known-red FAIL lines at results.log :63/:64/:67.

## Decisions

| # | Rung | Decision | Rejected alternative |
|---|------|----------|----------------------|
| D1 | R1 (0243-F2: gates live at the VERBS) | Fix the harness, not the six check names — the verdict gate belongs at the verdict banner | Renaming the 6 in-name check sites: cheapest, zero harness risk, but leaves the classifier lying for the next author and destroys the only in-tree canary |
| D2 | R2 | Anchored per-line predicate | run_suites.sh:105's "last `^RESULT` line wins" — test_grid_toggle_sel_gc prints **no** RESULT line, so that rule turns a must-stay-SKIP into a hollow PASS |
| D3 | R1 (0244/0267/0270: an aborted path must not lie) | `has_failure()` as an independent second guard | Relying on AUDIT_MIN_PASS floors alone — they bite only where a floor is set, and the default is 0 |
| D4 | R2 | Keep `is_skip` BEFORE `is_pass` | Reordering so PASS wins — measured to make test_grid_toggle_sel_gc and any legacy `ALL PASS (0 checks…)` test hollow PASSes |
| D5 | R2 | Do NOT unify full_audit's and run_suites.sh's skip policies; document the split | Making either match the other — changes every ad-hoc soak invocation in CLAUDE.md for no measured defect |
| D6 | R2 | Gate the 11 tier suites in the **cheap headless** step | Extending the xvfb glob (what WIRING.md R1 proposed) — slower, and puts deterministic true-headless tests behind an X server whose breakage is the very hollow-green mode this item closes |
| D7 | R2 | `AUDIT_MIN_PASS` == exact suite count | The xvfb gate's 15-of-33 slack — correct there, wrong here: a skip IS the regression |
| D8 | R2 | Delete no untracked file this crew did not create | `git clean -fdx` over the 81 `untitled*.sch` and 7 scratch dirs — `untitled-NN.sch` is the shape of unsaved user work |
| D9 | R2 | File the undo_link_child leak (0352), don't fix it here; correct hardening_sprint_plan's "A2 DONE" | Leaving the plan as historical record — it is read as current status |
| D10 | R2 | A post-fix SKIP→FAIL flip gets filed, not gated | Gating every newly-honest test at once — lands a red CI whose cause was never triaged |

## Sabotage matrix (verify-B; all 8 applied to the real files and restored from md5-verified backups)

| Variant | Predicted | Observed |
|---|---|---|
| S1 unanchored is_skip | 6 red | **5 red** — C4 C5 C6 + audit subset went 5 PASS/exit 0 → 4 SKIP + 1 FAIL/exit 1. C7 GREEN (hole) |
| S2 drop the line anchor | 5 red | **4 red** — C4 C5 C6 + same audit-level reversion. C7 GREEN (hole) |
| S3 no-op has_failure | 2 red | **1 red** — C8. C7 GREEN (hole) |
| S4 pass-before-skip | 3 red | **1 red** — C10b only |
| S5 drop the min-pass floor | 1 red | 1 red — C15b, exactly as predicted |
| S6 shrink the gate list | 1 red | 1 red — C15a names the missing suite verbatim |
| S7 remove the lib-only guard | 2 red | **2 red** — all 16 predicate/classify checks + suite banner |
| S8 classify swallows crash | 1 red | 1 red — C13b, exactly as predicted |

**Predicted reds that did NOT appear, and why (these are the honest gaps):**

- **S1/S2/S3 → C7 stayed green.** C7 (in-name token + FAIL lines → FAIL) is protected
  by `has_failure` when the anchor regresses and by the anchor when `has_failure`
  regresses. Applying S1+S3 **together** does redden it, so C7 is genuine
  defence-in-depth — but **no single planned variant covers it**, and the plan
  asserted three would.
- **S4 → C10a stayed green, and test_grid_toggle_sel_gc did not move.** `is_pass`'s
  `*)` arm calls `! is_skip` itself, so with a generic test name the chain ORDER is
  unobservable. Only C10b covers ordering, via a name-specific arm that does not
  self-guard. The plan's stated risk for reordering is **overstated** for that test.
- **S4 → the predicted legacy-blob PASS never occurred**: there is no `classify()`
  check on the legacy blob anywhere (C3 is `is_skip`-only), so that predicted red had
  no assertion behind it.
- **S6 → C15b stayed green.** The expected count lives in `$GATED` inside the test,
  not read from ci.yaml, so list shrinkage is caught by C15a **only** — a
  single-point dependency.
- **S1/S2 canary mechanism was wrong**: test_audit_classifier is scored FAIL, not
  SKIP (its own `^FAIL:` lines trip `has_failure`). Predicted outcome (gate exits 1)
  held; the stated reason did not — the AUDIT_MIN_PASS floor is **not** what catches
  that regression.
- **S7 mechanism was wrong**: no 20s timeout is reached (the sourced audit exits fast
  via its MISSING-file path). The guard is covered, but this variant does **not**
  prove the exec timeout is present, as the plan claimed.

## Still open

Reproduced independently by the write-up agent against the **fixed** harness:

1. **`is_pass` and the CRASH arm are still unanchored** — the same defect class this
   issue fixed for `is_skip`. A suite printing FAIL lines, `OVERALL: notok`, exit 1
   is scored **PASS** if any line contains the substring `OVERALL: ok`, and it
   **counts toward the new `AUDIT_MIN_PASS=15` floor**. Filed as **issue 0354**.
2. **`has_failure` misses ~26 tests' failure banners** (`RESULT: <n> FAIL`,
   `RESULT: FAIL`, lowercase `OVERALL: fail`, `OVERALL: <n> FAILED`). Latent. 0354.
3. **The third skip alternative anchors `RESULT:`, not the token**, so a green
   `RESULT: ALL PASS (20 checks; 3 legs skipped: no X)` is scored SKIP. 0354.
4. **Running the new hard gate dirties the working tree** — `untitled-NN.sch` in the
   repo root — while full_audit reports `SCRATCH: 0 leaked dir(s)`. Issues 0352/0353.
5. **The xvfb hard gate was never re-run** in this item. The subset proof (new
   `is_skip` ⊂ old) says no test can move into SKIP there, so a flip is structurally
   implausible — but it is **inferred, not measured**.
6. **The default exit gate is unchanged**: a bare `full_audit.sh` still exits 0 with
   ~66 SKIPs. The repair exists only where a floor is set, i.e. the two CI gates.
7. **`AUDIT_LIB_ONLY` sourcing has two undocumented side effects**: `cd "$REPO"`
   changes the caller's cwd, and the `[ ! -x "$XSCHEM" ] → exit 2` check sits ABOVE
   the guard, so sourcing in a tree with no built binary **exits the calling shell**.
8. **C15a is satisfiable by a suite name that survives only in a comment** inside the
   `run: |` body — deleting a name is caught, commenting one out is not.

## Crew hygiene note

The verify-B agent's cleanup command `rm -f untitled-6*.sch` over-matched and deleted
**7 pre-existing untracked stubs** (`untitled-6.sch`, `untitled-60..65.sch`) alongside
the 3 its own gate run had leaked — a D8 violation, self-reported. Bounded loss: all
59 surviving root `untitled*.sch` are byte-identical 89-byte empty stubs (single md5
`4ab664717a3bcc5dc1758b878f51a89a`), so the deleted files were the same leak artifact
and carried no information. Nothing tracked, nothing referenced. Deliberately not
recreated — fabricating them with fresh mtimes would be worse than reporting it.
