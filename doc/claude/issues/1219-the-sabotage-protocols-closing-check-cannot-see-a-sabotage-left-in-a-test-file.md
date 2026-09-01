# 1219 - the sabotage protocol's closing check cannot see a sabotage left in a test file

**Branch:** annotate
**Status:** OPEN - measured, not fixed. Process/harness, not product code.
**Filed by:** item S6a, write-up pass, 2026-08-31, from three agents' measurements
in that item's own session.

## What happened

The crew protocol's closing assertion before publishing any sabotage number is:

```
grep -rn SABOTAGE /home/analog/dev/xschem-claude/src/     # must be empty
```

On 2026-08-31 between **16:14:35 and 16:25:18** the canonical suite file
`tests/headless/test_auto_specialize_1201.tcl` held a live sabotage variant -
`as_stripsym` reduced to `return $deck`, which is the item's own plan entry
**SAB-HDRSTRIP** - left there by a script that wrote through a symlink into the
repository instead of into its `/tmp` copy. In that window:

* one agent ran `tests/run_regression.tcl` and got **4 counted failures**, all in
  that suite (rows AS6, AS26, AS56 and the harness's non-completion line), and
  had to spend a pass proving the red was not the item's fault;
* another read the tree as handed over and measured `RESULT: 3 FAILED (54
  passed)`, `OVERALL: notok`, exit 1 - while the [[1208]] issue file beside it
  said *"Status: FIXED ... Verified by row AS56"* and row AS56 was red.

The closing grep was **clean the whole time**, and correctly so: the sabotage was
in `tests/`, not `src/`, and it carried no marker - because the protocol's own
other rule says a `/* SABOTAGE */` comment does not neutralise anything and the
right way to disable a guard is to delete it, which leaves no word to grep for.

## Why the obvious widening does not work

`grep -rn SABOTAGE tests/` is worse than useless: measured today it returns **60
lines across 28 files**, all pre-existing prose in suites that discuss their own
sabotage variants. A check that is never empty is not a check.

## What would fix it

Byte-compare, not marker-grep. Before the first variant, copy every file the
run will touch; before publishing any number, assert each is `cmp`-identical to
its copy. The sabotage pass on this item did exactly that and additionally
recorded that its rebuilt binary was **md5-identical to the implement agent's**,
which is a stronger restore proof than any diff. A `git status --porcelain`
that shows only the item's own paths is the cheap second half.

Worth stating in the same breath, because it is what turned an 11-minute mistake
into two wasted verification passes: **a sabotage variant must never be written
through a path inside the repository**, and a script that composes an output path
should resolve it (`readlink -f`) before opening it for writing.

## Where the rule lives

The crew's house rules, not `CLAUDE.md` - so this file is the record, and
whoever maintains the crew brief is the audience. `CLAUDE.md` is untouched: no
build or test invariant of the repository changed.
