# 0802 — `full_audit.sh` scores a pass banner followed by a death marker as PASS

Status: **RESOLVED** 2026-09-17, landed with 0805 as one bundle. Re-measured still-live
before the repair (`classify` returned **PASS** on banner+exit-0+column-0 death while
`banner_died` and `regression_case_failed` both said YES), fixed, and locked by
`test_audit_classifier.tcl` **K21** with **K22** as its anti-overshoot. All three
acceptance items below are met.
Filed by: the 0689+0690+0698 crew, 2026-08-25, from its Implement leg.
Class: a **harness** defect — the same hollow-pass hole 0689 just closed in the
Tcl reader is still open in the shell reader that CI actually runs.

STUB CLAIMED FIRST, then measured. See "The measurement" below.

## The defect

`tests/headless/full_audit.sh:311-325`:

```sh
elif line_has '^FATAL: signal' "$out" \
     || { line_has '^Tcl_AppInit\(\) error' "$out" && ! is_pass "$name" "$out" "$ec"; }; then
  echo CRASH
```

The `Tcl_AppInit` arm is guarded by `&& ! is_pass`. So a suite that prints its
completion banner, exits 0, and **then** dies mid-script is classified `PASS`:
`is_pass` is true, the guard suppresses the CRASH arm, and the death line is
never surfaced. `xschem --nogui --pipe` exits 0 on an uncaught mid-script Tcl
error, so this is the ordinary shape of a real death, not an exotic one.

The `^FATAL: signal` arm is NOT guarded and does fire regardless of the banner.
The hole is specific to the `Tcl_AppInit` literal.

## The measurement

Through the suite's own `AUDIT_LIB_ONLY=1` sourcing path, 2026-08-25:

| fixture | `classify` verdict |
|---|---|
| banner + exit 0 + `Tcl_AppInit() error` at column 0 | **PASS**  ← the hole |
| no banner + exit 0 + `Tcl_AppInit() error` at column 0 | CRASH |
| banner + exit 0 + `FATAL: signal 11` at column 0 | CRASH |

`tests/banner_rule.tcl::banner_died` — the predicate `tests/run_regression.tcl`
now uses — returns 1 for **all three**, so the Tcl reader is deliberately
stricter than the shell reader as of this commit. That divergence is recorded in
`banner_rule.tcl`'s own comment and locked by `test_audit_classifier.tcl` K9-K12.

## Why it is filed and not fixed

Dropping the `&& ! is_pass` clause changes `classify`'s output for an existing
input class, and `tests/headless/test_audit_classifier.tcl` **section H** locks
that behaviour — including a row (0354 H4) that exists *because* the clause was
added on purpose, to stop a check NAME containing the literal from scoring a
genuinely failing suite as CRASH instead of FAIL. `full_audit.sh` is in
`.github/workflows/ci.yaml`; `run_regression.tcl` is not. Changing the CI gate's
classifier is a strictly larger blast radius than the harness-trust fix that
uncovered this, and it needs its own red phase over section H.

## Recommended fix (for whoever takes it)

Keep the `! is_pass` clause's intent — do not let a check *name* forge a crash —
by tightening the anchor rather than the guard: match the literal only when it is
the **start of a line that is not itself a check line**, i.e. require the death
marker to appear at column 0 (which `line_has '^...'` already does) and drop the
`! is_pass` clause, then re-run section H and repair the 0354 H4 row against the
new, narrower predicate. Note `xinit.c` also emits `Tcl_AppInit() err 1:` ..
`err 4:` (xinit.c:1507/3253/3325/3373), which neither reader has ever matched;
widening to those is a separate unmeasured change (0354 H4 note).

## Acceptance

1. A fixture of "banner + exit 0 + column-0 `Tcl_AppInit() error`" classifies
   CRASH (or FAIL), never PASS.
2. A fixture whose only occurrence of the literal is inside a check name still
   classifies FAIL, not CRASH (the 0354 H4 row stays green).
3. `test_audit_classifier.tcl` passes in full, including section H, and the CI
   gate list is unchanged.

## How it was fixed, and all three acceptance items (2026-09-17)

The guard is simply **gone**; the recommended fix's "tighten the anchor rather than
the guard" needed no new anchoring, because `line_has '^...'` was **already** column-0
anchored by 0354 H1. The clause had become dead weight rather than a gate:

```sh
elif line_has '^FATAL: signal' "$out" \
     || line_has '^Tcl_AppInit\(\) error' "$out"; then
```

1. **Met.** `classify(R_DIE_BARE, ec 0)`: **PASS → CRASH**. Locked by **K21**, which
   asserts full_audit's verdict beside `banner_died` and `regression_case_failed` in
   one row, so the two readers can never again disagree about the same log. Observed
   red first: `-> {PASS YES YES} (exp {CRASH YES YES})`.
2. **Met, and this is the part worth reading.** ⚠ **The row this filing warns about —
   "a row (0354 H4) that exists *because* the clause was added on purpose" — is
   labelled `C33`, not `H4`.** `H1`–`H4` are *issue* sub-item labels from 0354; the
   suite's section H rows are labelled `C30`–`C34`. A grep for `"H<digit>` finds
   nothing and sizes the repair wrong. `C33`'s fixture `B_APPINITNAME` carries the
   literal **mid-line inside a check name**, so the column-0 anchor rejects it with or
   without the guard — `C33` and `C34` were green before the change and are green
   after, never touched. **K22** adds what nothing locked: the same shape for a
   *passing* suite (`R_DIE_MID`, both death literals quoted mid-line) must stay
   `PASS`. K22 is green in both directions by construction and has never been observed
   red; it is kept deliberately, because it reddens if anyone ever closes this by
   widening the death anchor instead of dropping the guard.
3. **Met.** `test_audit_classifier.tcl`: **RESULT: ALL PASS (75 checks)**, twice
   identically, section H included. The CI gate list is untouched — `.github/workflows/
   ci.yaml` was not edited, and the gate was run exactly as CI runs it
   (`AUDIT_DISPLAY=none AUDIT_MIN_PASS=15`, the same 15 suites): **15 pass, 0 fail,
   0 crash, rc 0**. `test_grid_toggle_sel_gc` appended to that run scored **SKIP**, so
   the no-display skip path is confirmed intact rather than turned into a hollow pass.

Note the widening to `Tcl_AppInit() err 1:`..`err 4:` (`xinit.c:1507/3253/3325/3373`)
remains **not done** and still unmeasured, exactly as this filing and the 0354 H4 note
left it. It is a separate change and neither reader matches those strings today.
