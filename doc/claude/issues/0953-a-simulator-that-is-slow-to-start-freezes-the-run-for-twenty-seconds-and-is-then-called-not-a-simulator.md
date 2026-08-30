# 0953 — a simulator that is slow to start freezes Run for twenty seconds, and is then called "not a simulator"

**STATUS: OPEN — measured 2026-08-30 by 0948's write-up pass, confirming its
verification pass. Two defects with one cause; both are about a program that is
merely slow, not broken.**

## What the user sees

They press Run. The editor stops responding — no message, no progress, nothing
to cancel — for twenty seconds. Then the Command window tells them their
simulator "produced no results at all when it was tried on a tiny test
circuit", and the run proceeds anyway.

Their simulator is fine. It takes eleven seconds to start because it checks out
a licence, or because it lives on a network mount that had gone cold.

## Measured

A stand-in that does nothing but take a while:

```
SLOW-TO-START: waited 20.0 s -> known 1 usable 0 appendwrite 0 blanket_op_save 0 hier_op_names 0

real    0m20.100s
```

The verification pass measured the same twenty seconds for a program that never
returns at all (`HANG probe blocked for 20.006 s`), and separately measured an
eleven-second-to-start but otherwise perfect ngspice being told it is not a
circuit simulator.

## Mechanism

Two probe runs, each capped at ten seconds by `ase::cap_run`'s `timeout 10`, and
the whole thing is called straight from the middle of `ase::run_deck`:

```tcl
src/ase.tcl:2214  catch {ase::cap_report $sim [ase::n_enabled_analyses $state]}
```

`exec` blocks the interpreter, so those twenty seconds are twenty seconds of a
frozen editor. Nothing shows a wait cursor, nothing can be cancelled, and Stop
does not exist yet at that point in the gesture.

The cap is right to exist — without it a program that sits reading its own
prompt would hang Run forever, and it is one of the two belts 0948 built for
exactly that. What is wrong is (a) paying it synchronously in the user's
gesture and (b) reading "it took too long" as "it produced nothing", which is
the same category error as issue 0949: a measurement that did not happen is
reported as a fact about the program.

Note the cost when everything is normal is not the problem: a healthy build
measures in about 14 ms cold and 0.05 ms warm, once per session.

## Fix shape

1. **Tell the two apart.** A probe run cut off by its own clock has not
   measured the program. Answer `known 0`, say nothing, and — with issue 0950 —
   do not remember it either. Only a program that ran to completion and
   produced nothing earns `usable 0`.
2. **Get it out of the gesture.** Either measure before the user is waiting
   (the first time the Simulators window resolves an entry, say), or run the
   probe the way every other simulation is run — through the asynchronous
   launcher, with the answer arriving when it arrives and the report deferred
   to the next Run.
3. If it must stay synchronous, a much shorter first cap with one retry buys
   most of the safety for a fraction of the freeze.

## Acceptance

* A simulator that takes 11 s to start is measured correctly and is not
  described to the user as producing no results.
* A simulator that never returns cannot hang Run, and cannot freeze it for
  twenty seconds either.
* The healthy path stays at its measured ~14 ms once per session.
