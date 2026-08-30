# 0951 — two xschem windows share one probe scratch file, so one simulator's results can answer for another's

**STATUS: FIXED (2026-08-30, item S3a) — the probe now works in a directory of
its own per measurement, removed when the measurement ends including when the
probe blows up, and it refuses to take a verdict from any results file it did
not see appear. Rows I1, I3, I4, I5 and G4 of
`tests/headless/test_ase_simcaps_0948.tcl`.**

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

## The fix (item S3a, 2026-08-30)

Two guards, against two different things, both in `src/ase.tcl`.

**A place of its own, per measurement.** `ase::cap_workdir` used to answer the
one fixed name `<simulation folder>/.ase_probe`, shared by every process on the
box. It now creates `<simulation folder>/.ase_probe/p<pid>_<n>`, refuses any
candidate name something is already sitting at, and answers empty when no such
place can be made at all. `ase::cap_workdir_done` gives it back — the private
directory with `-force`, the shared `.ase_probe` parent **without**, so the
parent disappears when it is empty and survives when another process's probe is
still working in it. `ase::sim_capabilities` calls it on every path out,
including the one where the probe raised, and then re-raises so a defect in a
probe stays loud.

**Not believing a results file this run did not see appear.** `ase::cap_claim`
is asked immediately before each run whether the name is free; `ase::cap_result`
answers empty when it was not. That covers the collision the private directory
cannot: a recycled process number, a predecessor that died without tidying up,
or a caller that hands the probe a directory of its own choosing. The probe also
no longer **deletes** the two results files at the top of the run — which is how
the old tree got the right answer in the staged case, by destroying somebody
else's results.

**What that leaves.** The false yes needs a concurrent write, which no
deterministic test row can stage. Row I4 plants a plausible healthy results file
at the OLD fixed name and asserts the program that wrote nothing is still
reported as producing nothing AND that the planted file survives; row I5 hands
the probe a directory that is already populated and asserts the same. Row G4
asserts the user's simulation folder is empty again afterwards.

## Correction, 2026-08-30 — the race CAN be staged, and no committed row stages it

The paragraph above says the false yes "needs a concurrent write, which no
deterministic test row can stage". The verification pass staged it: a helper that
drops a healthy results file at `.ase_probe/probe_a.raw` one second into the probe
makes the OLD tree answer `known 1 usable 1 appendwrite 1 ...` (the false yes) and
the NEW tree answer `known 1 usable 0 appendwrite 0 ...`.

The same pass also showed that row **I4's headline half passes on the defective
tree** — with the old shared folder AND the old delete-at-top restored, a planted
raw is destroyed before it can be read, so I4's `1 0 0` is identical on both trees
and only its file-survival half reddens. The fix is real and I5 covers the belt;
what is missing is a row for the shape the issue is actually about. Filed as
**issue 0962**.
