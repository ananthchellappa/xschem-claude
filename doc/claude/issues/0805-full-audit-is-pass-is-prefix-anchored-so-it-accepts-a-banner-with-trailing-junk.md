# 0805 — `full_audit.sh`'s pass arm is only PREFIX-anchored, so it accepts a completion banner with trailing junk that the other two readers reject

Status: **OPEN** (measured, NOT fixed — deliberately outside the 0689+0690 blast radius)
Filed by: the 0689+0690+0698 crew, 2026-08-25, from its adversary leg.
Class: a **harness** defect of exactly the 0689 family — three readers of one banner,
and the third one disagrees with the other two.
Related: **0689** (the Tcl reader, FIXED in the same commit), **0802** (the other
full_audit divergence this crew filed), **0354 H1** (which anchored these arms at
column 0 in the first place).

## The defect

`tests/headless/full_audit.sh`, `is_pass()`, the `*)` arm:

```sh
*)  line_has '^(RESULT: ALL PASS|OVERALL: ok)' "$out" && ! is_skip "$out" ;;
```

`^…` anchors the **start** of the line and nothing anchors the end, so any line
that merely *begins* with the banner is a pass. The other two readers require the
whole line: `tests/banner_rule.tcl`'s `banner_complete` is
`{^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$}` and `tests/headless/run_suites.sh:155`
is the same shape as an ERE.

## The measurement

Through the file's own `AUDIT_LIB_ONLY=1` harness, 2026-08-25, on this tree
(`XSCHEM=$REPO/src/xschem`, fixtures passed as strings — `line_has` takes content,
not a path):

```
full_audit is_pass: PASS      <<OVERALL: ok>>
full_audit is_pass: PASS      <<OVERALL: ok (30 checks)>>
full_audit is_pass: PASS      <<OVERALL: okay then>>
full_audit is_pass: PASS      <<OVERALL: ok TAB junk>>
full_audit is_pass: notpass   <<OVERALL: 1 FAILED (65 passed)>>
full_audit is_pass: notpass   <<OVERALL: notok>>
full_audit is_pass: notpass   <<forged mid-line>>
```

`banner_complete` and `run_suites.sh`'s ERE return **not-a-completion** for rows 3
and 4 and agree with full_audit on every other row. So the divergence is exactly
the trailing-junk shapes, and only those.

## Why it is latent and not live

Swept 2026-08-25: the tree emits exactly three banner shapes — bare `OVERALL: ok`
(131 sites), `OVERALL: ok (N checks)` (5 sites), `OVERALL: ok  (all checks passed)`
(2 sites, double space). **No suite emits a banner with trailing words or a tab
trailer**, so no test changes classification today. The risk is the 0689 risk: the
day a suite prints `OVERALL: ok — see log for details`, two readers call it a
failure to report and full_audit — the reader CI actually runs — calls it a PASS.

## Why it was not fixed here

`full_audit.sh` is the CI gate (`.github/workflows/ci.yaml`), and
`tests/headless/test_audit_classifier.tcl` sections F/G/H lock its five predicates
against drift. Tightening `is_pass` moves a CI-gated classifier in a commit whose
subject is harness *trust*; the 0689+0690 item deliberately kept its blast radius
to `run_regression.tcl`. Recorded in `tests/banner_rule.tcl`'s header so the next
reader meets it in the code, not only here.

## The fix, when it is taken

Anchor the `*)` arm's `OVERALL: ok` alternative at both ends with the same
optional-trailer tolerance the other two readers use, keep `RESULT: ALL PASS`
whole-line too, then add a section-K row asserting all **three** readers agree
fixture for fixture (today K18 locks only `run_suites.sh`, and K19 only the two
crash literals). Land it with 0802, which touches the same function's caller.

## Still open

Everything above. Also unmeasured: whether `is_skip` and `has_failure` have the
same prefix-vs-whole-line asymmetry — this crew probed only `is_pass`.
