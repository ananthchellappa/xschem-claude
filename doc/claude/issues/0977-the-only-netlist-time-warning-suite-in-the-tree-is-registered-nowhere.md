# 0977 — the only netlist-time warning suite in the tree was registered nowhere

**Status: FIXED 2026-08-30 by item S4b.** Filed and fixed in the same pass,
deliberately: the change that pass made lives in the same C function this suite
covers, so leaving it unrun meant a sabotage of one could silently break the
other.

## What was true

`tests/headless/test_hash_extra_node_warn_0165.tcl` was named in **neither**
`tests/run_regression.tcl`'s `hcases` **nor** `tests/headless/full_audit.sh`'s
`nogui_tests`:

    is test_hash_extra_node_warn_0165 registered anywhere?
      run_regression.tcl: 0
      full_audit.sh:      0

So nothing had ever run it. It passed by hand (15 checks) and nobody knew,
because nobody ran it.

It could not have been run by the regression runner even if it had been listed.
`banner_complete` (`tests/banner_rule.tcl`) requires a whole-line `OVERALL:`
banner as well as the `RESULT:` line, and this file printed only the `RESULT:`
one — so `hcases` would have scored it as a suite that did not complete.

## Why it matters

It is the tree's **only** other netlist-time warning suite, and it covers the
warning emitted from `print_spice_element()` in `src/token.c` — the very
function issue 0970's "you typed this and it had no effect" check was added to.
Two warnings, one function, one of them watched by nothing.

## What was done

* The dual banner (`RESULT: ALL PASS (N checks)` **and** `OVERALL: ok`) added,
  with a comment at the site saying why both are needed.
* Registered in `tests/run_regression.tcl`'s `hcases` and
  `tests/headless/full_audit.sh`'s `nogui_tests`, once each.
* Row **UB10** of `tests/headless/test_unused_attr_0970.tcl` is structural and
  pins all four facts — named once in each file, and both banners present — so
  it cannot fall out of the lists again unnoticed.

Measured after: `RESULT: ALL PASS (15 checks)`, `OVERALL: ok`, exit 0, and the
case appears in `results.log` at `Total num fail: 0`.
