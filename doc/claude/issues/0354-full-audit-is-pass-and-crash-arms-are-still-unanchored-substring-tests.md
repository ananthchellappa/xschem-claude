# 0354 — full_audit's is_pass and CRASH arms are still unanchored substring tests

Status: FIXED 2026-08-09 — all five holes (H1-H3, the CRASH arm, and H4 measured here)
closed by line-anchoring every predicate. See RESOLUTION at the end; residual risks under
"Still open" there.
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

---

# RESOLUTION — FIXED (2026-08-09)

Fixed together with the fifth hole this item measured (H4, below), issue 0355 (both
halves), and the DETECTOR half of 0352/0353. One mechanism: **every predicate in
`tests/headless/full_audit.sh` now asserts the SHAPE it names**, the way 0350 taught
`is_skip` to.

## BEFORE (measured verbatim, against the FIXED harness at 118d6937)

The Measure agent replayed the five holes through the real library
(`AUDIT_LIB_ONLY=1 . tests/headless/full_audit.sh`, `XSCHEM=/bin/true`):

    $ env -u DISPLAY XSCHEM=.../src/xschem bash .../repro_0354.sh
    H1 want=FAIL  got=PASS
    H2 want=FAIL  got=SKIP
    H3 want=PASS  got=SKIP
    H4 want=PASS  got=CRASH
    H5 want=FAIL  got=CRASH
    is_pass(H1)     = true   <- a failing run is "passing"
    has_failure(H2) = false  <- three failure lines are invisible
    is_skip(H3)     = true   <- a green suite is "skipped"

H1 is the hole that propped up the new CI floor: because 0351 made CI key on the pass
COUNT (`AUDIT_MIN_PASS=15`), a suite printing three `FAIL:` lines, `RESULT: 1 FAILED`,
`OVERALL: notok` and exiting 1 was scored PASS — and that hollow PASS satisfied the floor.

Measured banner inventory behind H2 (the alternation matched none of these shapes):

    161  RESULT: $fail FAIL
      5  RESULT: FAIL
      4  OVERALL: fail
      3  OVERALL: $fail FAILED

## H4 — a fifth hole, measured by this item, absent from the original filing

`classify`'s SECOND crash arm, `*"Tcl_AppInit() error"*` (`full_audit.sh:184`), was
unanchored too. A genuinely FAILING suite whose output mentions that string anywhere
(a diagnostic, a check name) was reported CRASH instead of FAIL. Direction is red→red so
the exit gate never moved, and the `! is_pass` guard means the same string in a PASSING
suite was correctly ignored — so that one arm carried two unanchored predicates with
**opposite** failure directions.

## AFTER

    H1 want=FAIL  got=FAIL
    H2 want=FAIL  got=FAIL
    H3 want=PASS  got=PASS
    H4 want=PASS  got=PASS
    H5 want=FAIL  got=FAIL

    test_audit_classifier.tcl:  RESULT: ALL PASS (49 checks)   (was 19)

## What changed

One shared matcher above the `AUDIT_LIB_ONLY` guard —
`line_has() { printf '%s\n' "$2" | grep -qE "$1"; }` — and then:

- **`is_pass`: all EIGHT arms anchored**, not only the `*)` arm H1 names. The seven
  name-specific sentinel arms get `^EVENT opens palette: yes`, `^PASS: ciw autocomplete
  \(0 failure\(s\)\)`, `^PASS: ciw puts-capture \(0 failure\(s\)\)`, `^RESULT: all
  passed`, `^NOGUI_TEST_PASS`, `^READONLY_GUARD_TEST_PASS`,
  `^ACTION_READONLY_TEST_PASS`. The `<name> headless: all checks passed` banner is
  prefixed BY CONSTRUCTION (`test_hi_descend.tcl:163`), so it is anchored at BOTH ends:
  `^[A-Za-z0-9_]+ headless: all checks passed$`. The `*)` arm is
  `^(RESULT: ALL PASS|OVERALL: ok)`.
- **`has_failure` widened** to `^(FAIL[: !]|RESULT: ([0-9]+ )?FAIL|OVERALL: ([0-9]+
  )?(notok|NOTOK|FAIL|fail))` — covering every failure banner the tree really emits,
  including `test_cadence_stretch_move.tcl:170` and `test_descend_inert_class.tcl:151`
  (a CI hard-gated suite). Column 0 only.
- **`is_skip`'s third alternative PINNED** to `^RESULT: ALL PASS \(0 checks, skipped: no
  X\)` — kept, not deleted.
- **Both CRASH arms anchored**: `^FATAL: signal` (`main.c:58` prints it after a leading
  `\n`, so column 0 is guaranteed) and `^Tcl_AppInit\(\) error` (H4).
- Chain order and the `! is_pass` guard untouched.

## Proof that anchoring `is_pass` reclassified nothing

The sweep this issue demanded, run twice independently (Implement, then the adversary,
who did not trust the first):

- 296 headless blobs captured once with `DISPLAY` unset, each test in the arm the NEW
  full_audit picks; classified with `git show 118d6937:tests/headless/full_audit.sh` and
  with the new file. OLD: **62 CRASH / 13 FAIL / 155 PASS / 66 SKIP**. NEW: **identical.
  Zero moved rows.**
- 40 xvfb blobs over the `has_failure` exposure population (`test_fluid_*`,
  `test_rotate_*`, `test_cadence_stretch_move`, `test_drag_keeps_selection`,
  `test_ase_dirty`, `test_ase_savestate_adopt`, `test_graph_box_zoom_xy`, the four
  selflog suites). OLD 1 FAIL / 39 PASS; NEW identical. **Zero moved rows.**
- Corroborating static check: ZERO of the 296 suites both emit a column-0 skip banner
  AND a column-0 failure banner — which is why widening `has_failure` moved nothing (the
  SKIP→FAIL direction had an empty population).
- Hollow-pass hunt on real data: all 336 blobs scanned for `is_pass && has_failure` and
  `is_pass && ec!=0`. Zero hits.

## Decisions (ladder rung, and the rejected alternative)

- **R2 — anchor ALL eight `is_pass` arms**, not only the `*)` arm H1 names. REJECTED:
  anchor only `*)`, leaving the seven sentinel arms (one of which, `test_nogui`, is a CI
  hard gate) as the same defect wearing a smaller blast radius.
- **R1 (0350 D2: a banner counts only at the START OF A LINE)** — `has_failure` keeps
  column 0; no leading-whitespace tolerance. REJECTED: `^[[:space:]]*FAIL[: !]` per this
  issue's "any indented FAIL line" aside — it would let a suite that echoes a child run's
  indented output flip SKIP→FAIL for a failure that is not its own, reddening the xvfb
  Fluid gate for an untriaged cause, which 0350 D10 forbids.
- **R2 — pin `is_skip`'s third alternative** to the literal its comment documents.
  REJECTED: delete it outright — deletion would let a resurrected legacy banner score a
  hollow PASS, the one thing that alternative exists to prevent.
- **R2 — H4 appended to THIS issue rather than given its own number.** Same predicate,
  same function, same one-line fix, same commit. REJECTED: a separate number — it would
  fragment one fix across two write-ups and leave 0354 closable while its own class was
  still open.
- **R2 — anchor `Tcl_AppInit() error` to the literal the arm already names**; do NOT
  widen to the `Tcl_AppInit() err 1..4:` variants `xinit.c:1507/3253/3325/3373` actually
  emits. Both directions of this arm are red→red, so the exit gate cannot move either
  way. REJECTED: widening in the same commit — a label-only change with no measured need
  that would reclassify currently-FAIL suites to CRASH inside a sweep whose whole point
  is "every moved row needs a named cause".
- **R1 (0243 F2: gates live at the verb, never duplicated at the shared primitive)** —
  `classify`'s chain ORDER is untouched and NO `! is_skip` guard is added to the seven
  name-specific arms. REJECTED: making each arm self-guard for symmetry — it would move
  the gate off the chain onto every arm and make C10b ("skip outranks a non-self-guarding
  pass arm") unobservable, deleting the only lock on an ordering the source documents as
  load-bearing.

## Sabotage matrix

Each variant applied to the real file, suite run, file restored byte-identical.

| Variant | Predicted red | Observed |
|---|---|---|
| S1 unanchor `is_pass` `*)` | C16, C17, C21 | **C16, C17** (2 FAILED) |
| S2 unwiden `has_failure` | C22–C26, C29 | all 6 (6 FAILED) |
| S3 unpin legacy skip alternative | C30, C31 | both (2 FAILED) |
| S4 unanchor `FATAL: signal` | C32 | C32 (1 FAILED) |
| S5 unanchor `Tcl_AppInit() error` | C33 | C33 (1 FAILED) |
| S6 neutralize `line_has` (plan recipe verbatim) | C16,C17,C21,C32,C33,C35 | **only C32, C35 + 18 collateral** |
| S6b neutralize `line_has` FAITHFUL | — | C16,C17,C21,C32,C33,C35 + C5, C27 (8 FAILED) |
| S7 stub `tree_delta_snapshot` | C37, C38, C39 | all 3 (3 FAILED) |
| S8 revert 0355 both halves | C42, C43 | both (2 FAILED) |

Anti-overshoot rows (C3, C12, C13b, C18, C19, C20, C27, C28, C34, C36, C40) stayed green
in every variant.

**Predicted reds that did NOT appear, and why the coverage is still real:**

- **S1 / C21.** C21 exercises the `^[A-Za-z0-9_]+ headless: all checks passed$` arm, not
  the `*)` arm S1 unanchors, so S1 cannot reach it by construction. C21 DOES redden under
  S6b. The *plan's prediction* was wrong, not the check.
- **S6 / C16, C17, C21, C33.** The plan's literal S6 recipe (`case "$2" in *"$p"*`) turns
  every pattern containing ERE metacharacters — alternations, escaped parens — into an
  unmatchable literal. That is a "predicate always FALSE" mutation, not an "unanchored"
  one: it cannot produce the false-POSITIVE direction those four rows assert, and it
  reddens the anti-overshoot rows instead. The adversary therefore wrote **S6b**, the
  faithful anchor-stripping variant, under which all six predicted rows redden and every
  anti-overshoot row stays green. S6b is the variant that proves the anchors are covered;
  S6 as written in the plan is not a valid mutation and should not be reused.

## Still open (adversary residual risks)

1. **`is_pass` consults neither `has_failure` nor the exit code.** A blob with a column-0
   pass banner (a relayed child log, or a first-phase banner) next to column-0 `FAIL:`
   lines and `ec=1` is STILL scored PASS, and still counts toward `AUDIT_MIN_PASS`. The
   class is narrowed from "token anywhere" to "token at column 0", not eliminated. No
   in-tree emitter today (no `.tcl` relays child stdout at column 0; no suite has two
   reachable column-0 verdict banners), so latent.
2. **`has_failure` now matches ZERO-count banners** (`RESULT: 0 FAIL`, `OVERALL: 0
   FAILED, N passed`). All three in-tree emitters are `if {$fail}`-guarded, so latent —
   but a future suite that prints its count unconditionally AND self-skips would flip
   SKIP→FAIL, the untriaged-red-hard-gate outcome 0350 D10 forbids.
3. **`^[A-Za-z0-9_]+ headless: all checks passed$` is the only both-ends anchor.** A
   trailing space or a CRLF-translating Tk channel (the Windows build this codebase
   targets) turns `test_hi_descend` / `test_cadence_descend_newwin_ro` PASS→FAIL. Unix
   emitters are exact matches, so unix-safe today.
4. **The tree-delta arm reports whatever a concurrent agent or the user changes** in the
   same worktree during a run. Report-only, so cosmetic, but it will produce confusing
   `TREEADD` noise in parallel crew runs.
5. `xinit.c`'s `Tcl_AppInit() err 1:`..`err 4:` variants remain unmatched by the CRASH
   arm, as they always were (decision above).
