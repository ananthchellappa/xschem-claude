# 0805 — `full_audit.sh`'s pass arm is only PREFIX-anchored, so it accepts a completion banner with trailing junk that the other two readers reject

Status: **RESOLVED** 2026-09-17, landed with 0802 as one bundle (as this file's "The
fix" section prescribed). Re-measured still-live before the repair, fixed, and locked
by `test_audit_classifier.tcl` **K20** (three-reader agreement) and **C45/C46/C47**
(the `RESULT: ALL PASS` alternative). Suite: 69 checks → **75 checks, ALL PASS**.
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

## How it was actually fixed (2026-09-17)

The `*)` arm is now anchored at **both** ends:

```sh
*)  line_has '^(RESULT: ALL PASS([[:space:]]+\(.*\))?|OVERALL: ok([[:space:]]+\([^)]*\))?)[[:space:]]*$' "$out" \
      && ! is_skip "$out" ;;
```

Re-measured before touching anything, through the same `AUDIT_LIB_ONLY=1` path:
`R_OKAY` and `R_TAB` were **YES** for full_audit and **NO** for both other readers,
and all seven other fixtures agreed — the divergence was exactly the trailing-junk
shapes and only those, precisely as filed. After: all three agree on all nine.

**⚠ THE TWO ALTERNATIVES CARRY DIFFERENT TRAILERS, AND THAT IS NOT DRIFT.** This is
the one thing the original filing got wrong, and it would have shipped a live
regression. "Use the same optional-trailer tolerance the other two readers use"
(above) is right for `OVERALL: ok` and **wrong for `RESULT: ALL PASS`**:
`test_ase_bus_bits_0159.tcl:294` prints

```tcl
puts "RESULT: ALL PASS ($npass checks[expr {$skipped ? ", $skipped group(s) skipped" : {}}])"
```

so with any group skipped it emits `RESULT: ALL PASS (12 checks, 2 group(s) skipped)`
— an **inner parenthesis inside the trailer**. `\([^)]*\)` stops at that inner `)`,
fails the end anchor, and scores a green shipped suite **FAIL**. Measured, not
reasoned: with `[^)]*` on both alternatives the new row **C47 reds**
(`-> {NO} (exp {YES})`). So `OVERALL: ok` keeps `\([^)]*\)`, byte-identical to
`run_suites.sh` and verdict-identical to `banner_complete` (K20 asserts it); and
`RESULT: ALL PASS` takes `\(.*\)`, which the other two readers cannot constrain
because **neither implements that spelling at all**.

The pre-fix sweep that made this safe, from the emitter statements themselves
(`grep -rhoE '(puts|echo)[^"]*"(RESULT: ALL PASS|OVERALL: ok)[^"]*"' tests/`): every
shipped emitter is bare or carries exactly **one** parenthesised trailer. No suite
emits trailing words, so the divergence was still latent when it was closed.

## The "also unmeasured" question, now measured

`is_skip` and `has_failure` do **not** have the same defect, for two different
reasons, and neither should be "fixed" the way `is_pass` was:

* **`is_skip` is prefix-anchored in both shell readers and byte-identical between
  them** (`^(RESULT: SKIP|SKIP: no X connection|RESULT: ALL PASS \(0 checks, skipped:
  no X\))`, `full_audit.sh` vs `run_suites.sh:191`), and `test_audit_classifier.tcl`
  **C44** already locks that equality. So there is no reader-divergence here at all —
  the 0805 defect class needs two readers that disagree, and these two cannot.
* **Neither can be whole-line anchored anyway**, because their banners carry trailing
  text *by design*: `RESULT: SKIP (no X)`, `SKIP: no X connection (has_x=0); run under
  DISPLAY with --pipe`, `FAIL: <check> -> {..} (exp {..})`. A `$` anchor would reject
  the real thing. `has_failure` additionally has **no counterpart** in the other two
  readers, so it has nothing to diverge from.

Nothing remains open.
