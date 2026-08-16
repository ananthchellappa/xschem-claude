# 0423 — a Tcl error in `xschem.tcl` (or any helper it sources) SEGFAULTS instead of reporting

Status: **open — measured, not fixed.** Found by the S1 Implement agent of the
op-annotation run (2026-08-16) while validating sabotage variant SAB-7 on branch
`annotate`. Filed rather than fixed: the fix is in C (`xinit.c`), S1 is a pure-Tcl
step, and no crew step in this run owns `alloc_xschem_data()`.

## What was expected

`doc/claude/specs/op_annotation.md`'s S1 risk note, and `src/xinit.c:1508-1539`
read literally, say that a Tcl error while sourcing a helper is a **quiet**
failure: under `--pipe` / `--nogui`, `source_tcl_file()` prints to stderr and
returns `TCL_ERROR` without `Tcl_Exit`, and `Tcl_EvalFile` has already abandoned
the rest of `xschem.tcl`. The predicted symptom was ~340 headless suites failing
in confusing ways with **no crash**.

## What actually happens — measured

Making the first executable line of `src/op_annot.tcl` a call to a nonexistent
command and running

```
./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_op_annot.tcl
```

gives **exit 139, SIGSEGV, core dumped**. No test row runs; there is no `RESULT:`
banner at all.

```
Tcl_AppInit() error: can not execute .../src/xschem.tcl, please fix:
invalid command name "op_annot_boom"
Line No: 14552

can't read "cairo_font_line_spacing": no such variable
can't read "color_ps": no such variable
... (one per global xschem.tcl never reached)

Program received signal SIGSEGV, Segmentation fault.
#0  __strcmp_avx2 ()
#1  alloc_xschem_data ()
#2  Tcl_AppInit ()
#3  Tcl_MainEx ()
#4  main ()
```

## Cause

`src/xinit.c:658`, the first statement in `alloc_xschem_data()` that consults Tcl:

```c
if(!strcmp(tclgetvar("undo_type"), "disk")) {
```

`Tcl_AppInit()` calls `alloc_xschem_data()` (`xinit.c:3435`) **after** the
`source_tcl_file(xschem.tcl)` at `xinit.c:3401` has already failed and returned.
`undo_type` is one of the many globals `xschem.tcl` sets below the point where it
was abandoned, so `tclgetvar()` answers `NULL` and `strcmp(NULL, "disk")` faults.
The cascade of `can't read "<global>": no such variable` lines immediately before
the crash is the same cause reported non-fatally by other call sites that happen
to use `tclgetboolvar`/`tclgetintvar` (which tolerate the miss) rather than a bare
`strcmp` on the returned pointer.

Nothing about `op_annot.tcl` is special here. Any Tcl error anywhere in
`xschem.tcl` or in any file it sources reaches the same place.

## Why it matters

* The failure mode is **worse than documented but louder than feared**. A crashing
  binary with exit 139 and no `RESULT:` banner is classified `RESULT?` by
  `full_audit.sh` and `couldn't execute`-adjacent by `run_regression.tcl`, so it
  is not silent — but the message a developer sees last is a SIGSEGV, which sends
  them hunting for a memory bug in C when the actual defect is one bad line of Tcl
  that the program already printed a perfectly good diagnostic for, five lines up.
* It makes every `.tcl` helper edit a potential "xschem segfaults on startup"
  report.

## Suggested fix (not applied)

Two independent hardenings, either of which removes the crash:

1. `xinit.c:658` — never `strcmp()` a raw `tclgetvar()` result. The codebase's own
   idiom elsewhere is to test the pointer first; a `tclgetvar()` miss must be
   treated as "not set".
2. `Tcl_AppInit()` — when `source_tcl_file(xschem.tcl)` returns `TCL_ERROR`, the
   interpreter is not in a state any later initialisation can assume. Report and
   exit non-zero there, instead of continuing into `alloc_xschem_data()` with a
   half-initialised Tcl side.

(1) is the one-line change; (2) is the one that turns a whole class of downstream
"no such variable" cascades into a single legible failure.

## Test note

`tests/headless/test_op_annot.tcl` row A3 (the `stdin_repl_setup` canary) was
written to catch the *quiet* version of this failure and remains the right check
for a partially-abandoned `xschem.tcl` — e.g. a helper that raises but is sourced
after `alloc_xschem_data()`'s dependencies are set. It cannot fire for the crash
described here, because no script runs at all.
