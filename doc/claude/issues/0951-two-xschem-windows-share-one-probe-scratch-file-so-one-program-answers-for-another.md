# 0951 — two xschem windows share one probe scratch file, so one simulator's results can answer for another's

**STATUS: OPEN — measured 2026-08-30. Found by 0948's verification pass,
reproduced deterministically by its write-up pass. This one defeats the purpose
of 0948 itself, silently, so it should be fixed before anything else in this
family.**

## What the user sees

Nothing — that is the whole problem. They have two xschem windows open, which
is ordinary. One of them is pointed at a simulator build that keeps only the
last analysis of a run. It is measured while the other window is running a
simulation of its own, and it is declared perfectly healthy. Nothing is said,
and their operating point is destroyed exactly as it was before 0948 existed —
issue **0929**'s symptom, arriving through the door 0948 was built to guard.

## Measured

Deterministic reproduction: a "simulator" that runs for four seconds and writes
nothing at all, measured while a healthy build's results file lands in the
shared probe directory under the same fixed name:

```
shared probe directory: .../plain/.ase_probe
the program under test wrote: probe_a.sp probe_a.raw probe_b.sp
verdict about a program that wrote nothing:
        known 1 usable 1 appendwrite 1 blanket_op_save 0 hier_op_names 1
```

`probe_a.raw` there is the other process's. The program under test produced not
one byte and was given a full clean bill of health.

The verification pass measured the same thing the other way round, with a
real second xschem doing the writing:

```
N: OTHER-PROCESS (stock ngspice) probed: known 1 usable 1 appendwrite 1 ...
S: caps after 20.003 s -> <known 1 usable 1 appendwrite 1 ...>
```

## Mechanism

The probe writes and reads four fixed names —

```tcl
src/ase.tcl   set rawa [file join $workdir probe_a.raw]
              set decka [file join $workdir probe_a.sp]
```

— in a directory that is per-**simulation-folder**, not per-process:
`<simulation dir>/.ase_probe`. Two xschem windows on the same design share it.

The proc's own comment believes this is handled:

> ⚠ THE RESULTS FILES ARE DELETED BEFORE EACH RUN. The probe directory is
> shared between probes and between builds, so one program's leftover file
> would otherwise answer for the next program measured.

The delete happens **once, at the top of `capabilities`**, before either probe
run. It closes the window between one probe and the next probe *in the same
process*. It does not close the window between this process's delete and this
process's read, which is where another process's probe lands.

## Fix shape

Either is enough on its own; the first is cheaper and the second is the belt.

1. **Per-process names.** `probe_a.[pid].raw`, or a per-process subdirectory.
   This is the pattern `run_parallel_cmds` already uses for the same reason
   (`tests/test_utility.tcl:82`, `.parallel_jobs.[pid]`), and the pattern issue
   0867 asks for in the regression harness.
2. **Do not trust a results file older than the deck that asked for it.**
   Record the deck's own modification time and refuse a results file that does
   not postdate it. That also catches the case where a probe is cut off by its
   clock and an ancient file survives.

Whichever is chosen, the probe should clean up after itself rather than leaving
four files per simulation folder.

## Acceptance

* A program that writes nothing measures `usable 0` even while another
  process's healthy probe is writing into the same simulation folder.
* Two xschem windows probing two different builds at the same time each get
  their own answer, and neither answer is about the other's program.
* A row that fails when the per-process scoping is removed — the shared
  production path is exercised by nothing today, which is why this was invisible
  to a suite whose every row builds its own throw-away directory.
