# 0634 — `test_op_annot` W19a depends on a gitignored, untracked `~.sch` that nothing can restore

**Status:** open — filed 2026-08-23 by the S4 RED agent.
**Severity:** test-suite fragility. One check goes red for a reason unrelated to
any code change, and `git` cannot put the tree back.

## What was measured

`tests/headless/test_op_annot.tcl:9115` reads

```tcl
set w19a_bak [file exists [file join $w19a_bakdir bandgap_opamp~.sch]]
```

and row **W19a** asserts that value is **1**:

```
check {W19a I4/0495 a walk over the SHIPPED bandgap_opamp leaves modified 0, ...} \
  [list [lindex $w19a 0] $w19a_bak $w19a_st0 $w19a_st1 [expr {$w19a_sig1 eq $w19a_sig0}]] \
  [list 0 1 {73 0 0} {73 0 0} 1]
```

The file it names is
`sky130A/xschem_libs/sky130_tests_ase/bandgap_opamp/schematic/bandgap_opamp~.sch`.
It is **not tracked** (`git ls-files` lists only `bandgap_opamp.sch`) and it is
**gitignored** (`.gitignore:75  *~.sch`).

During this S4 run the Measure agent deleted it (and `tb_bandgap~.sch`) while
probing the issue-0632 hazard. `test_op_annot` then reported

```
FAIL: W19a I4/0495 a walk over the SHIPPED bandgap_opamp leaves modified 0, the instance
count and every byte on disk unchanged -> {0 0 {73 0 0} {73 0 0} 1} (exp {0 1 {73 0 0} {73 0 0} 1})
RESULT: 1 FAILED (329 passed)
```

— the only differing element is `$w19a_bak`, `0` instead of `1`. No source file
had changed. `git status` showed nothing, `git checkout` could restore nothing,
and no committed fixture describes the missing bytes.

Restored by hand (`cp bandgap_opamp.sch bandgap_opamp~.sch` — the row's own
comment records that the two are byte-identical today, and issue 0632's
transcript records the `~` at the same 7618 bytes), after which
`test_op_annot` is `RESULT: ALL PASS (330 checks)` again.
`tb_bandgap~.sch` was **not** restored: it was 3799 bytes against the `.sch`'s
3843, so its content cannot be reconstructed, and no row asserts it.

## Why it matters

* A gitignored artifact is, by definition, developer state. A committed suite
  that asserts its presence is asserting something about **one directory**, not
  about the code — which is the exact failure mode W19a's own comment warns
  about ("A row that did not record its presence would be measuring the
  developer's directory, not the code"). Recording it is not enough: the row
  *requires* it.
* The tell is maximally confusing for the next crew: a green suite goes red with
  no diff, and the recovery is not in git.

## Options

1. **Plant the `~` in the test** — write `bandgap_opamp~.sch` into the cell
   directory from the `.sch` bytes before the walk and delete it afterwards, as
   W19b already does for its byte-copy under `$scratch/wbg`. Keeps the assertion
   and makes it hermetic. Costs a write into a committed library directory.
2. **Byte-copy the whole cell into `$scratch` first**, plant the `~` there, and
   walk that — exactly W19b's shape. Hermetic and writes nothing into the tree;
   loses the "on the SHIPPED bench" property the row is named for.
3. **Track the `~`** with a `.gitignore` exception. Cheapest, but commits an
   autosave backup as a fixture, which invites confusion of its own.
4. Make the row *record* rather than *require* the flag (report it, assert only
   the modified/instances/bytes half). Weakest — it stops guarding the case the
   `~` exists, which is 0495's whole point.

**Recommended: option 2.** W19b already proves the shape works, it writes
nothing into a committed library, and the "shipped bench" property is really
about the *content* (73 instances, the real hierarchy), which a byte-copy keeps.

## Not to be confused with

Issue **0632** (the walk rewriting ancestor `~` backups when the entry sheet is
dirty) and issue **0609** (the untitled-backup leak). This one is only about a
committed check depending on a file the repository does not contain.
