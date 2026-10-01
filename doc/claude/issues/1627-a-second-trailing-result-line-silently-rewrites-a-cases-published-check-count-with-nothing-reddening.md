# 1627 — a second trailing `RESULT:` line silently rewrites a case's published check count, with nothing reddening

**STAMP:** `v1 claim=open tree=621c1ff5 stamped=2026-09-30 fix=none open=2`

Status: **OPEN**, measured 2026-09-30 · Branch: `fluid-editing`
Found by: the Stage A sabotage round of issue **1626**,
`doc/claude/calculator_batch/receipts/A-register-1626.md` §6(c2) — a sabotage aimed at something
else, which is how it surfaced.
Related: issue **1487**, which added each case's check count and `skip:` lines to the verdict for
exactly this reason — *"the verdict was the one file that could not say what had not been
measured"*. This is a hole in that closure.

## The measurement

`summarize_all` in `tests/run_regression.tcl` publishes a case's **last** `^RESULT:` line into the
verdict. `tests/headless/run_suites.sh` independently does `grep -E '^RESULT' | tail -1`. Both are
deliberate and both agree.

Append one extra line after a suite's real verdict:

```
RESULT: ALL PASS (244 checks)
OVERALL: ok (244 checks)
RESULT: ALL PASS (0 checks)
```

Fed to `summarize_all` lifted out of `run_regression.tcl`'s own text, the block it publishes is:

```
sab_c2.txt
RESULT: ALL PASS (0 checks)
Total num fail: 0
TOTALS: blocks=1 counted_failures=0 skips=0
```

**The published check count goes from 244 to 0. `counted_failures` stays 0. `skips` stays 0.
Nothing reddens in any of the three banner readers, and `run_suites.sh`'s `tail -1` reports the
same wrong line.** The case is scored a clean pass that announces it measured nothing, and the
announcement is the only trace.

## Why this matters more than it looks

CLAUDE.md's reading of a green verdict is explicit: *"`counted_failures=0` is a claim about
correctness, not about coverage — read `skips=` with it"*. Issue 1487 made that readable by putting
each case's check count in the verdict. This defect defeats that instrument **without touching
either number it taught people to read**: `counted_failures` and `skips` are both honest, and the
third figure — the check count — is the one that lies.

The shape is also one CLAUDE.md already warns about in a different place: *"a fence keyed to a
symptom dies quietly when something else cures the symptom"*. Here the fence is the published
count, and what kills it is an extra line nobody is looking for.

## How it would arrive in practice

Not by sabotage. By a suite with **more than one exit path** printing a verdict on more than one of
them — a teardown path, an early return, an error handler that reports before exiting, or a
`finish`-style proc called twice. `test_calc_skeleton` and `test_calc_widgets` each have two exit
paths today (a success verdict and a no-display verdict), and the Calculator batch's later phases
add more. **Nothing in the tree would catch it**, which is why this is filed rather than left in a
receipt.

## ⚠ What is NOT the defect

`RESULT:` appearing *after* the `OVERALL: ok` banner is **harmless and was measured to be so**.
`banner_complete` is `regexp -line` over the whole captured body, `summarize_all` keeps the last
`^RESULT:` of which there is then one, and `run_suites.sh` takes `tail -1`. All three are
order-independent. Stage A broke the ordering deliberately and all three readers stayed green,
correctly. **The rule that matters is "be the last `RESULT:` line", not "come after the banner"** —
which is why the hazard is a *second* `RESULT:` line and not a reordered one. Anyone fixing this by
asserting an order has fixed the wrong thing.

## Still open (open=2)

1. **The fix.** A row asserting that a suite's output carries **exactly one** `^RESULT:` line, over
   the registered set, in the manner of `tests/headless/test_registered_banner_1626.tcl` — which
   already lifts both registration lists from the driver's own text and resolves each suite's
   `source` chain, so it is the natural home. ⚠ Note the asymmetry that makes this harder than
   `RB2`: `RB2` answers *could this suite ever emit the sentinel* from static text, and is
   deliberately conservative in the accepting direction because a false red there is a standing
   red in T1. *"Exactly one `RESULT:` per run"* is a **run-time** property of a particular arm, not
   a static one — a suite with two exit paths is correct precisely because only one of them runs.
   So a static row would have to reason about reachability, which its own limit `L5` says it does
   not do. The honest shape is probably a check **inside** the driver, where the output is in hand.
2. **`test_audit_classifier` is in neither `hcases` nor `dcases`**, so section K — the tree's only
   lock holding the three banner readers in agreement — gates nothing. Found in the same stage
   (receipt §10.3) and left untaken. It is the same class as issue 1626 and it is the fence over
   the very rule this issue is about, so it belongs next to this work rather than in the general
   unregistered tail.
