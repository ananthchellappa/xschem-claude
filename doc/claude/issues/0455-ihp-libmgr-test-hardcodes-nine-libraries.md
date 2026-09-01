# 0455 — test_ihp_sg13g2_libmgr hard-codes 9 libraries and a 10th is committed

> **RESOLVED 2026-08-25 — DUPLICATE of issue 0690, fixed there.** The golden now
> lists 10 and the suite reports `OVERALL: ok (67 checks)`. Filed four times in all
> (0421, 0455, 0491, 0690).
>
> ⚠ **THIS FILE'S FIRST DIAGNOSIS IS REFUTED, AND IT IS RECORDED HERE SO NOBODY ACTS
> ON IT LATER.** It originally read the directory as untracked litter and pointed at
> **deleting it** — which would have destroyed **140 tracked files across 49 cells**
> to make one test green. This file already corrected itself once (below); the
> 0689+0690 crew re-confirmed the correction five independent ways before touching the
> golden, per the driver's rule that *a golden updated to match a broken tree is worse
> than a stale golden*. `sg13g2_tests_ase` is the **migrated ASE-L testbench library**
> and it stays.
>
> One remedy this file offered is also refuted: **"or make it a superset test"**. The
> check is deliberately **exact-equality**, which is what would catch a library
> genuinely leaking into the workarea; widening it to a superset would convert this
> red into a permanent lie. See 0690 §8.

Status: **RESOLVED as a duplicate of 0690** (2026-08-25). Was: OPEN (measured, not fixed)
Found: S8 of doc/claude/specs/op_annotation.md, baseline measurement on branch `annotate`.

`cd tests && tclsh run_regression.tcl` reports a real check failure:

    FAIL: library_list = exactly the 9 intended libs ->
      {analyses devices examples ngspice ngspice_verilog_cosim sg13g2_pr
       sg13g2_stdcells sg13g2_tests sg13g2_tests_ase xschem_simulator}
      (exp {... sg13g2_tests xschem_simulator}) : FAIL

The extra entry is `sg13g2_tests_ase`.

**⚠ THE FIRST DIAGNOSIS OF THIS ISSUE WAS WRONG, AND THE FIX IT IMPLIED WAS
DESTRUCTIVE.** S8's measurement pass recorded the directory as "NOT tracked by
git — an earlier crew's ASE work left it", and this file was originally named
`0455-ihp-libmgr-test-reds-on-an-untracked-workarea-library.md`, i.e. it told
the next reader to delete a stray. Re-checked at write-up time:

    $ git ls-files ihp-sg13g2/xschem_libs/sg13g2_tests_ase | wc -l
    140
    $ git log --oneline -1 -- ihp-sg13g2/xschem_libs/sg13g2_tests_ase
    bf83fa95 regen(pdk): sky130A + ihp-sg13g2 benches through the fixed migrator

It is **140 committed files**, added in c69b88de and regenerated in bf83fa95,
both ancestors of HEAD. Deleting the directory — the fix the old wording pointed
at — would have destroyed tracked work to make a test green.

So the failure is a COMMITTED library meeting a test that hard-codes a
nine-library expectation. The fix is to update `test_ihp_sg13g2_libmgr`'s
expectation to the 10 libraries that now ship (or make it a superset test).
Nothing in the library manager is broken.

Pre-existing and unrelated to OP annotation: S8 only established that it
predates the step, and corrected the diagnosis.
