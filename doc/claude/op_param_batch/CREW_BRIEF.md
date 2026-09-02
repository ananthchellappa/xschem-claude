# Crew brief — OP parameter lists

You are running **one item** from `PLAN.md`, end to end: scout, measure, plan,
RED, implement, verify, write up, commit, ledger row.

## Non-negotiable

* **Read `DECISIONS.md` first.** D-1 … D-8 are the user's rulings. They override
  the spec. If your item seems to need something a decision forbids, **stop and
  say so in your write-up** — do not implement around it.
* **RED before green.** Write the failing checks first and show them failing.
* **You own only the files your item names.** If you need a file another item
  owns, say so; do not edit it.
* **Never a bare `xschem`** on `PATH` — it is a 3.4.6 binary that rewrites the
  user's recent-files. Use `./src/xschem`, `$XSCHEM`, or
  `tests/headless/devdisplay.sh exec ./src/xschem`.
* **`run_regression.tcl` runs SOLO** (issue 0990). Two at once corrupt each
  other and the loser reports a `FATAL` that never happened.
* **Editing `src/Makefile.in` obliges `./configure`** (issue 0424). Verify with
  `grep -c <newfile> src/Makefile` — expect **2**.
* **A green suite is not an eyeball.** Record a `look` debt with
  `tests/headless/owed.sh add look …` and say "suites green, please look".
* Issue numbers come from `doc/claude/issues/NUMBERING.md` and nowhere else.

## Acceptance is a name+status diff

Not a count. The baseline is in `LEDGER.md`. Report per case if anything moved,
in either direction.

## Your ledger row

Append it to `LEDGER.md` yourself. If you cannot, say so loudly in the write-up
so the driver can — a missing row is how a batch loses track of itself.
