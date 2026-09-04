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

## Two traps this batch paid for during Feature B

**Sabotage must run on a COPY, never on the tree the other verifiers are using.**
Item B2c's crew ran three verify agents in parallel; one of them mutated
`src/op_param_lists.tcl` in place to test a sabotage variant, and that voided
Verify-A's first T1 number and Verify-C's first suite number — both agents
measured a tree somebody else was editing underneath them, and neither could
tell. Copy the file, mutate the copy, restore by `cp` and **verify the restore
with `md5sum`** before reporting any number.

**Never write an unbalanced brace as a literal — in a comment, a test, or a
fixture.** It makes *that whole file* fail `info complete`, and no test will tell
you: the file simply stops loading. Build such a string with `format %c`, the
way rows Z0–Z4 and Y1 of `test_op_param_store_1245.tcl` do. The driver hit this
writing issue 1291's own fix comment and it was caught by a syntax check, not by
a suite.

## And one about what a green count means

Three items in this batch shipped green and were wrong: B1 at 37/37 returning
`nan` as a value, B3's suite claiming three fences it did not have, and B2c at
79 green while deleting the user's rows — its "a row this build does not
understand survives a save" row used an **unknown verb**, the one shape its
classifier genuinely could not identify, so the row passed while the promise was
false. **A suite fences the questions its author thought of.** Before you call
one done, write down the input most likely to break your change, and check
whether any row would see it.
