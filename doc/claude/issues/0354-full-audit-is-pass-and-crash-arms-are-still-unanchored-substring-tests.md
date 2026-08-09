# 0354 — full_audit's is_pass and CRASH arms are still unanchored substring tests

Status: OPEN — measured, reproduced, deliberately NOT fixed
Area: tests/headless/full_audit.sh (harness classifier)
Found: 2026-08-09, unattended backlog run, item D1, by the adversary pass over the 0350 fix
Related: 0350 (the same defect class, fixed for `is_skip` only), 0351, 0147 (hollow green)

## Summary

Issue 0350 anchored `is_skip`. It did **not** anchor the two predicates that sit
next to it in the same chain, and it did not complete `has_failure`'s alternation.
Three holes of the identical defect class survive. One of them is load-bearing for
the CI floor that 0351 introduced.

**This is not a regression from 0350.** `is_pass` and the CRASH arm are unchanged
from before that work, and the 0350 fix is provably incapable of moving any
PASS/CRASH/TIMEOUT test (its new `is_skip` is a strict subset of the old one, and
`has_failure` is consumed only by the skip arm). What 0350 changed is the *stakes*:
0351 made CI key on the pass **count**, so a hollow PASS now props up a hard gate.

## H1 — a failing suite is scored PASS, and counts toward AUDIT_MIN_PASS

`is_pass`'s `*)` arm (full_audit.sh:109-110) is
`[[ "$out" == *"RESULT: ALL PASS"* || "$out" == *"OVERALL: ok"* ]]` — an unanchored
substring test, exactly what 0350 removed from `is_skip`. Reproduced against the
**fixed** harness:

    $ env -u DISPLAY XSCHEM=/bin/true bash -c '
        AUDIT_LIB_ONLY=1 . tests/headless/full_audit.sh
        blob="ok:   replay log says OVERALL: ok for the child run  (ok)
    FAIL: parent assertion -> {1} (exp {0}) : FAIL
    RESULT: 1 FAILED (1 passed)
    OVERALL: notok"
        classify test_probe "$blob" 1'
    PASS

A suite that printed FAIL lines, printed `OVERALL: notok`, and exited 1 is scored
PASS. Run alone under `AUDIT_MIN_PASS=1` it yields `SUMMARY: 1 pass  0 fail` and
audit exit 0. So the 0351 gate comment's claim that the exact-count floor repairs
"a SKIP can never fail the audit" is true only for the SKIP-shaped hollow green;
a PASS-shaped one still satisfies the floor. **A check name mentioning
`OVERALL: ok` is exactly what an action-log / replay test writes** — this is
reachable, not theoretical.

The CRASH arm (`*"FATAL: signal"*`) carries the same defect in the other
direction: a check name containing `FATAL: signal` scores a whole green suite
CRASH. Measured by the implementer while authoring test_audit_classifier.tcl
(see its header note).

## H2 — `has_failure` misses most of the tree's own failure banners

`^(FAIL[: !]|RESULT: [0-9]+ (FAILED|FAILURE)|OVERALL: (notok|FAIL))` does not match
the shapes ~26 shipped tests actually emit: `RESULT: <n> FAIL` (18 emitters, e.g.
test_cadence_stretch_move.tcl:170), `RESULT: FAIL` (4: test_altf5_ciw,
test_selflog_output, test_snap_bindkeys, test_undo_link_symbols), lowercase
`OVERALL: fail` (4, e.g. test_drag_keeps_selection.tcl:158),
`OVERALL: <n> FAILED, <n> passed` (test_descend_inert_class.tcl:151 — a suite 0351
just added to the CI hard gate), and any indented FAIL line. Reproduced:

    RESULT: SKIP (GUI legs need a usable display)
    not ok: the headless leg actually failed
    RESULT: 2 FAIL
    OVERALL: fail                              -> classify = SKIP   (want FAIL)

So "any FAIL line beats a skip banner" is currently true only for the `FAIL:`
shape. Latent today — every in-tree column-0 skip emitter either exits on the same
logical line or is `fail == 0`-guarded (test_ase_dirty.tcl:370,
test_ase_savestate_adopt.tcl:216, test_graph_box_zoom_xy.tcl:160) — but that is the
*tests'* discipline, which is precisely what 0350 set out to stop relying on.
The 0350 regression lock C8 exercises only the `FAIL:` shape, so this is unlocked.

## H3 — the third skip alternative anchors the wrong token

`^RESULT:.*skipped: no X` anchors `RESULT:`, not the token, so the token may sit
anywhere on any RESULT line. The comment above it describes it as covering one
extinct literal; the regex is far wider. Reproduced:

    ok: headless legs (ok)
    RESULT: ALL PASS (20 checks; 3 keyboard legs skipped: no X)
    OVERALL: ok                                -> classify = SKIP   (want PASS)

That banner is the most natural thing an author writes after reading 0350's new
contract telling them to keep the note out of check names — it silently discards a
fully-green suite. Issue 0350's own defect, relocated from "anywhere in the blob"
to "anywhere on a RESULT line". Behaviour is unchanged from pre-0350 (the old
unanchored `*skipped: no X*` also matched it), so this is a missed opportunity
rather than a regression.

## Why this was not fixed in the same item

Widening `has_failure` or anchoring `is_pass` changes classification **tree-wide**,
across ~300 suites. The 0350/0351 work was verified against the tree as it landed
(a 296-test dual-classifier sweep: 5 rows moved, all SKIP→PASS, zero PASS→anything).
Shipping a further predicate change with no human watching would mean landing
unverified reclassifications on top of a verified baseline, and any SKIP→FAIL flip
it produced would redden a hard gate whose cause had never been triaged — which
0350 decision D10 already rules out. Fixing this needs its own before/after sweep.

## Suggested fix, when someone takes it

- Anchor `is_pass`'s banner arm and the CRASH arm the same way `is_skip` was
  anchored, and extend test_audit_classifier.tcl with the H1 blob.
- Widen `has_failure` to `RESULT: [0-9]+ FAIL`, `RESULT: FAIL`, case-insensitive
  `OVERALL:.*fail`, and add a C8 variant per banner shape.
- Either pin H3's alternative to the literal it documents
  (`^RESULT: ALL PASS \(0 checks, skipped: no X\)`) or drop it entirely.
- Re-run the 296-test dual-classifier sweep before and after; every moved row needs
  a named cause.
