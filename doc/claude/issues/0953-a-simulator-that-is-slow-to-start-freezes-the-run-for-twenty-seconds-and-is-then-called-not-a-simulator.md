# 0953 — a simulator that is slow to start freezes Run for twenty seconds, and is then called "not a simulator"

**STATUS: FIXED (2026-08-30, item S3a) — one bounded budget for the whole
measurement, a sentence that claims only what was established, and a cut-off that
is never remembered as a settled answer. The remaining half — getting the probe
out of the user's gesture altogether — is NOT done and is described below. Rows
G5, J1, J3, J4, J5, J6, J7, J9 and J10 of
`tests/headless/test_ase_simcaps_0948.tcl`.**

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

## The fix (item S3a, 2026-08-30)

**One budget for the whole measurement.** `ase::cap_budget_ms` (30000) is the
number of milliseconds the whole probe may take, and `ase::cap_left` hands each
run what is left of it. The measured 20.0 s was two runs each paying a literal
`timeout 10` buried in the runner that nothing could ask to be smaller. Once one
run has been cut off the second is **not attempted** — nothing more can be learned
from a program that is not answering, and the user is already waiting. Worst case
is one budget, not two.

**The caller can now find out.** `ase::cap_run` returns
`{exitcode output was-it-cut-off elapsed-milliseconds}`. It used to return Tcl's
own catch code, so a program cut off at ten seconds was indistinguishable from one
that failed instantly, and the only place the truth survived — `::errorCode` —
was thrown away. `was-it-cut-off` is 1 only when all three of these hold: a cap
was actually applied, the child's status is 124, and the elapsed time reached the
cap. That closes both holes at once — a real simulator that chooses to exit 124 on
its own is not called a timeout, and a cap that was never applied cannot
manufacture one.

**The polite stop is not enough.** `ase::cap_timeout_cmd` prefers
`timeout -k 2 <secs>`. Measured on this box: a stop-ignoring program under a plain
three-second cap ran its full thirty seconds; with the grace it ends at five.
Without it the bound is not a bound at all for that program (row J3).

**The sentence says only what was established.** New kind `cap_no_answer` in
`ase::sim_why`:

> `<path>`, which is the program the simulator you picked will start, was given a
> tiny test circuit to try and had still not finished with it after N seconds, so
> there was no way to find out what it can do. It may simply be slow to start.
> Your run is going ahead anyway, and this will be tried again the next time you
> press Run.

It does not say the program is broken and it does not say it is not a simulator,
because neither was measured. "It had not finished" and "it is not a circuit
simulator" are different statements about somebody's program.

**And it is not remembered.** A cut-off answers `{known 0 unmeasured timeout secs
N}`, which `ase::sim_capabilities` never caches (issue 0950(a)), so the next Run
tries again.

## The decision taken without a ruling

**Thirty seconds, once, for the whole measurement.** Today it was twenty seconds
AND a false accusation AND a poisoned session. The rejected alternative was
keeping the worst case at twenty, which would cut off exactly the
eleven-second-to-start simulator this issue's own acceptance criteria name — i.e.
would keep the defect for the user the issue is about. A healthy probe is 0.014 s
cold and nothing at all warm, so a working simulator never feels the bound. This
changes what the user experiences mid-gesture and no ruling covers it; recorded as
`owed.sh` rule 0953.

**A probe cut off part-way keeps nothing.** One run cut off makes the WHOLE answer
`known 0`. The alternative — a `known 1` answer carrying only the keys that were
measured — would either claim `blanket_op_save 0` about a question nobody asked
(ruling D5-1's shape) or hand every reader a `known 1` dict with a key missing,
which this section's own contract forbids.

## Addendum, 2026-08-30 — the sentence was saying 31, and 30 was unreachable

Found by the sabotage pass on this item, measured through the front door at three
budgets: 3000 ms produced a 3.004 s wait and the words "after 4 seconds"; 10000
produced 10.004 and "after 11"; 30000 produced 30.005 and "after 31". Systematic,
every time, and it meant **the shipped sentence could never print 30** — the very
number this issue chose and the number the user's rule debt asks them to ratify.

The cause is a join, not a bug in either half. `ase::cap_left` hands the program a
cap in WHOLE seconds, so a program that is cut off always comes back a few
milliseconds PAST it; `ase::cap_spent` then rounded any part-second up. Rounding up
is right — a user who waited 3.2 s did not wait 3 — so the fix is a grace, not a
change of direction: the last tenth of a second no longer buys a whole extra one.
A real 3.2 s wait still reads as 4. `src/ase.tcl`, `ase::cap_spent`.

## Addendum, 2026-08-30 — six guards nothing could see

The sabotage pass passed on behaviour and failed on coverage: six guards had no row
that could see them, and one row that read as coverage was vacuous under the very
defect it names. All seven are now pinned, and each was re-measured under the
mutation it was written for.

* **The shared deadline — this issue's headline guard — was invisible.** Giving each
  run the full budget *and* attempting the second run after a cut-off (the exact
  pre-fix shape) reddened nothing: row J6's band was `< 9000` against a shipped
  3003 ms and a sabotaged 6003, so a clean doubling sailed through. J6's bound is
  now tied to the budget the row itself sets, and two rows that **count** rather
  than time it were added: **J11** (a measurement whose first run was cut off starts
  the program once, not twice) and **J12** (a stand-in that answers correctly but
  takes two seconds gets only what is left of one shared three-second budget, and
  a per-run budget would measure it successfully — which is what tells the two
  shapes apart). All three redden now.
* **The number of seconds the user is told they waited was unmeasured-safe** —
  ruling D5-1's exact shape. Replacing the counter's whole body with `return 999`
  left every check green while the Command window told a user who had waited three
  seconds that their program had not finished after 999. **J13** reads the counter
  off the clock at four distances, **J14** fishes the number back out of the
  sentence row J5's real cut-off actually put in the Command window — asking the
  mint where the number sits rather than hard-coding the wording.
* **Both arms of "was it cut off"** were unseen. **J16** pins the exit-code arm (a
  program that genuinely failed 2.85 s into a 3 s cap is not reported as one that
  did not finish) and **J15** the elapsed-time arm (a program that chooses exit 124
  on its own, instantly, is not either — the claim `ase::cap_run`'s own header
  makes and nothing tested).
* **The two D5-4 phrase rows saw whole chunks, not clauses.** One clause of either
  new sentence could be pasted verbatim into a second real `set` in `src/ase.tcl`
  with everything green. F6 and J10 now count at both grains; measured, the
  duplication reddens both.
* **`ase::cap_workdir`'s writability check** is reachable only on a filesystem that
  answers oddly, so it is pinned structurally by row **I6** and the source now says
  why no fixture can reach it.
* **Row K4's "the folder is put back afterwards" half was vacuous under its own
  defect.** With the restore deleted from `ase::cap_run`, an earlier probe had
  already left the process in a folder that was then removed, and Tcl's `pwd`
  answers the EMPTY STRING once that has happened — so both readings were empty and
  compared equal. K4 now puts the process somewhere real first and requires the
  folder it comes back to to still exist.

## Still open

The probe still runs inside the user's Run gesture, so a program that never
answers still costs a bounded pause. Getting the measurement off that path
altogether is the larger half and is not attempted here.

**Correction, same day: that pause is paid on EVERY press of Run, not once** —
the sentence above said "one bounded pause" and it was wrong. A cut-off answers
`known 0`, `known 0` is correctly never remembered (issue 0950(a)), so the next
press measures from scratch. Reproduced first-hand at a lowered budget: three
presses at a program that never answers cost 3004, 3003 and 3005 ms, and the
verification pass measured 30.0 s x 3 = 90.0 s at the shipped budget. Before this
item the same user paid 20 s once and nothing after, so for a user who keeps
pressing Run this is worse than what it replaced. Filed as **issue 0958** with
five options, and the `owed.sh` rule text has been corrected to say per press
rather than "once" — nobody should ratify a cost that is not the one they will
pay.

**And the whole bound depends on `timeout(1)` being on the box**, with nothing
said when it is not: measured, the same slow program on the same box with the
prefix empty ran unbounded for 16.0 s, came back as `cap_not_a_simulator` — the
exact false sentence this issue exists to remove — and was then remembered, so
0950(a) evaporates with it. Filed as **issue 0959**.
