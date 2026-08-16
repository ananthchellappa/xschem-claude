# 0396 — an rc-based test runner scores a FAILING headless suite **green**: most suites signal only by banner

Status: **OPEN** — measured 2026-08-11, deliberately not fixed.
Severity: **minor for the shipped harness, major for autonomous runs** — `tests/headless/full_audit.sh`
is already correct; ad-hoc `rc`-based loops (the ones driver crews write) are not.
Area: `tests/headless/test_create_instance.tcl` (tail), and ~100 sibling suites; contrast
`tests/headless/full_audit.sh:204` (`is_fail`), `:135` (`is_pass`).
Found: 2026-08-11, D7 write-up agent, while red-checking the CI15 rows of issue **0245**.
Related: **0245** (the rows whose sabotage exposed it), **0354** (`is_pass` unanchored),
**0147** (the suite that silently no-op'd and still printed a plausible log).

## What was measured

Red-checking 0245's new CI15 rows meant reverting one binding and re-running the suite. It printed
a failure and exited **zero**:

```
$ GUI_GATE=0 xvfb-run -a ./src/xschem --pipe -q --nolog --script tests/headless/test_create_instance.tcl
rc=0
FAIL: CI15a form-focused Escape aborted the arm (.addlabel) (=> ui=65536 ui2=1)
RESULT: 1 FAILED
```

`rc=0` with a `FAIL:` line in the output. The suite's tail is

```tcl
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
```

— no `exit 1`, and no `OVERALL:` line at all. A census of `tests/headless/test_*.tcl` finds this is
the **majority** shape, not an outlier: every suite that prints `RESULT:` but contains no `exit 1`
(≈100 files, `test_accelerators`, `test_ase_*`, `test_actionlog_suppress_gate`, …) has it.

## Why this is not simply a bug in those suites

`full_audit.sh` is written **around** banner scoring on purpose — its own comments say so
("a handful use their own banner", `:98`), and `is_fail` (`:204`) matches
`^(FAIL[: !]|RESULT: ([0-9]+ )?FAIL|OVERALL: …(notok|FAIL|fail))`. So the shipped audit **does**
catch the case above. The contract for these suites is *the banner*, and `rc` is not part of it.

The hazard is therefore on the consumer side, and it is live: an unattended crew that runs
`./src/xschem --script <t>.tcl; echo rc=$?` and reports "rc=0 ⇒ green" will report a **regression as
a pass**. This item was one `grep` away from doing exactly that — the tier table was assembled from
`rc`, and only a separate `grep -E 'CI14|CI15'` over the logs showed the sabotage had landed.

## The decision this needs

Two defensible answers, not adjudicated here:

- **(a) make `rc` part of the contract** — add `exit [expr {$fail != 0}]` to every suite that lacks
  it. Correct, but it is a ~100-file mechanical change that touches suites this branch does not own,
  and `full_audit.sh:212` documents `exit 0` as the marker of a *clean self-skip*, so a blanket
  rewrite risks reclassifying self-skipping suites as failures.
- **(b) make the banner contract explicit and enforce it in the runners** — document that headless
  suites signal by banner, and give crews a `run_one.sh` wrapper that applies `full_audit.sh`'s own
  `is_fail`/`is_pass` predicates to a single suite so nobody hand-rolls `rc=$?` again.

(b) is the smaller blast radius and matches how the shipped harness already works. (a) is what a
newcomer expects. Whichever lands, note that fixing `rc` alone would still leave `is_pass`
unanchored (**0354**).

## Reproduce

Any suite from the NO-EXIT census, made to fail:

```sh
sed -i 's|{addlabel::canvas_escape}|{addlabel::escape}|' src/xschem.tcl   # break one row
GUI_GATE=0 xvfb-run -a ./src/xschem --pipe -q --nolog \
  --script tests/headless/test_create_instance.tcl; echo "rc=$?"   # rc=0, banner says FAILED
git checkout src/xschem.tcl
```
