# Crew brief — stranger reds batch

Read `PLAN.md` (acceptance criteria) and your item's issue file before you touch anything,
then the previous item's receipt in `receipts/` if there is one.

## The rules that have cost this project time

* **Never a bare `xschem`.** Use `./src/xschem`, `$XSCHEM`, or
  `tests/headless/devdisplay.sh exec ./src/xschem`. Run suites as
  `tests/headless/run_suites.sh [--nogui] <suite>`, which arms the display, a throwaway
  HOME and a timeout.
* **Use `/usr/bin/grep`, never bare `grep`** (it is a function routing to ugrep).
* **Give every command a timeout**, and make a stall a named outcome, never silence.
* **Rebuild before any measurement meant as evidence** (`timeout 900 make -C src`): no
  harness builds, so a stale binary gives a plausible run with wrong answers.
* **Read `T1-RUN-END`** for `cases=`, `blocks=` and `counted_failures=`; a verdict with no
  trailer did not finish.
* **Do not touch the user's real HOME**, `~/.claude/xschem_dev_display`,
  `~/.claude/gui_test_gate`, `~/.claude/xschem_owed`, the dev display `:99`, or anything
  in `~/dev/xschem-op-wcard`. Work under the scratch root your task names, and **delete it
  when you are done**; state its peak size in your receipt.
* **Never commit.** The driver commits. Leave the tree with your edits in place and say
  exactly which files you changed.

## What a receipt must contain

The measurement that shows the defect on the unfixed code, the same measurement after the
fix, the suites you ran and their check counts, every sabotage you used to prove a new
check can fail, what you did NOT fix and why, and anything you found outside your item
(which is filed, not fixed).
