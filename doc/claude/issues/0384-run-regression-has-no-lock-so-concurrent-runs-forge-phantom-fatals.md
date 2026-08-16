# 0384 — `run_regression.tcl` has no lock, so two concurrent runs forge phantom FATALs

Status: OPEN (measured, not fixed)
Found by: D6 Verify-A (tier diff), 2026-08-10
Class: harness / test infrastructure
Severity: high for automated crews — it manufactures failure lines that read exactly
like product regressions.

## Symptom

`tests/run_regression.tcl` writes its verdict to the single fixed path
`tests/results.log`, and each case writes into a single fixed
`tests/<case>/results/` tree (plus `tests/<case>/results/.work/<n>.d` job
scratch and `tests/.parallel_jobs.<pid>`). Nothing locks any of it. Two or more
simultaneous runs in the same checkout therefore share every one of those paths.

Measured during D6 verification, with three `tclsh run_regression.tcl`
processes live at once (PIDs 709189, 709945, 714251):

Run 1 — `results.log` gained a fourth counted line that is not in the known-red set:

```
FATAL: 53.  Please search for FATAL in its output file for more detail
```

All 53 came from `netlisting`, and all 53 were the same thing:

```
FATAL: mkdir -p '.../netlisting/results/.work/156.d' && cd '.../xschem_library/examples' \
  && '.../src/xschem' 'pump.sch' -q --nogui -r -V -o '.../.work/156.d' ... : exit 126
```

`exit 126` is "found but could not execute" — the exec never happened, so no
netlist was ever compared. `grep -oE "exit [0-9]+$" netlisting_output.txt | sort | uniq -c`
returned `53 exit 126` and nothing else.

Run 2 — a different, also-not-known-red pair:

```
FATAL: 244.  Please search for FATAL in its output file for more detail
FATAL: signal 15
HARNESS: headless/test_ihp_sg13g2_libmgr did not complete cleanly (exit=1, ...)
```

`signal 15` is SIGTERM: one run's cleanup reaped another run's children. The
driver shell exited 144.

Run 3 — same tree, same binary, same sources, run **alone**:

```
FAIL: library_list = exactly the 9 intended libs -> {... sg13g2_tests_ase ...} : FAIL
HARNESS: headless/test_ihp_sg13g2_libmgr did not complete cleanly ...: FAIL
HARNESS: headless/test_pdk_launcher did not complete cleanly ...: FAIL
```

Exactly the documented known-red trio. Zero FATALs. So the FATALs in runs 1 and
2 were manufactured entirely by concurrency.

## Why it matters

The counted-line rule in `run_regression.tcl:62` is

```tcl
if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]} {
```

so a leading `FATAL` counts. A crew agent diffing "3 FAIL lines" against "4 FAIL
lines including a FATAL in netlisting" has every reason to call that a
regression and bisect a fix that was never wrong. The failure mode is
indistinguishable from a real one at the `results.log` level; you only see it is
bogus by opening `netlisting_output.txt` and noticing that every failure is
`exit 126`/`signal 15` — i.e. the binary was never run — rather than an output
mismatch.

It is also nondeterministic in *which* case it hits: run 1 poisoned `netlisting`,
run 2 poisoned `test_ihp_sg13g2_libmgr`.

## A second, independent source of the same signature

A concurrent **relink** of `src/xschem` produces the identical `exit 126`
symptom, because the tests fork the binary by path while the linker is replacing
it. Observed in the same window: `src/xschem` mtime moved 23:00:38 -> 23:09:53 ->
23:11:39 and its size went 1604480 -> 1596232 -> 1604480 while suites were
running. So "all failures are `exit 126`" means *either* a concurrent regression
run *or* a concurrent build — never a product defect.

## Diagnosis recipe (cheap, put this in the crew playbook)

1. `grep -oE "exit [0-9]+$" tests/<case>_output.txt | sort | uniq -c` — if every
   failure is `exit 126` or `signal 15`, the binary never ran; stop.
2. `ps aux | grep "tclsh run_regression"` — more than one means the run is void.
3. `stat -c '%y %s' src/xschem` before and after; if it moved, the run is void.
4. Re-run alone and diff against that.

## Fix candidates (not implemented — out of D6's scope)

- **Advisory lock.** `run_regression.tcl` takes an exclusive lock on
  `tests/.regression.lock` at start and either blocks or exits with a loud
  "another regression run is in progress (pid N)". Smallest and it directly
  matches the observed hazard.
- **Distinguish "never ran" from "ran and differed".** The counter currently
  folds both into `FATAL`. An `exit 126`/`127`/`signal 15` job is an
  *infrastructure* failure and should be reported on its own line
  (`INFRA: 53 jobs never executed`), so a reader is never invited to read it as a
  golden mismatch. This is the same distinction CLAUDE.md already draws for
  `couldn't execute "xschem"` / `exit 127`, just not enforced for 126 or for
  signals.
- **Per-run result roots.** `results.log` -> `results.<pid>.log` and
  `<case>/results` -> `<case>/results.<pid>`, with a stable symlink to the
  newest. Largest blast radius (every gold-promotion path reads those names), so
  listed last.

The first two are independent and either one alone would have made this
diagnosable in seconds.

## Related

- CLAUDE.md already warns that `couldn't execute "xschem"` / `exit 127` means
  nothing in that run is meaningful (issue 0016 part 4). This is the same class,
  one exit code over, and additionally self-inflicted by the harness.
- Not related to 0380 (`test_lib_sweep` derives the repo root from the cwd),
  though both bite when more than one runner shares a checkout.
