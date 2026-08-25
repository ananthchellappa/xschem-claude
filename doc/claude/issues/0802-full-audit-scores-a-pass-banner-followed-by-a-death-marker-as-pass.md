# 0802 — `full_audit.sh` scores a pass banner followed by a death marker as PASS

Status: **OPEN** (measured, NOT fixed — deliberately out of the 0689+0690 blast radius)
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
