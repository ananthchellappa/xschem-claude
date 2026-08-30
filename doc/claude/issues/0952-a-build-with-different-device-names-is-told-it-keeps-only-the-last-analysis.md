# 0952 — a build that spells device parameters differently is told it keeps only the last analysis, and given advice that changes nothing

**STATUS: OPEN — measured 2026-08-30. Found by 0948's verification pass,
reproduced by its write-up pass. The right answer is already computed and
thrown away, so the fix is small.**

## What the user sees

They point ASE-L at a simulator that adds every analysis to the results file
perfectly well, but that names a device's operating-point parameters differently
from the way this tree reads them. They are told:

> `<their program>`, which is the program that will run your simulation, keeps
> only the last analysis of a run and throws the earlier ones away as it goes.
> Your run has more than one analysis in it, so everything but the last one
> would be lost. Run one analysis at a time, or use a build that adds each
> analysis to the results file.

Every clause of that is false about their build, and the one thing it tells
them to do — run the analyses one at a time — changes nothing at all. What is
actually true is that this tree cannot read a single device's numbers out of
their operating point, which is a different problem with a different answer.

## Measured

A stand-in that is the real ngspice underneath, with only the device path
rewritten in the deck — the add-each-analysis behaviour untouched:

```
caps    : known 1 usable 1 appendwrite 0 blanket_op_save 0 hier_op_names 0
said (2 analyses): cap_no_append
CIW> ... keeps only the last analysis of a run and throws the earlier ones
     away as it goes ... Run one analysis at a time ...
--- what the probe's own results file holds ---
  plot constants  points 1
  plot Transient Analysis  points 59
```

**Two plots, in one file.** The build appended exactly as asked. It is reported
as a build that does not.

## Mechanism

`appendwrite` is read off the presence of an `Operating Point` plot:

```tcl
src/ase.tcl   if {$op ne {} && [lindex $op 1] >= 1 && $tr ne {}} { set appendwrite 1 }
```

and that plot only exists when the probe's three save cards resolved to real
vectors. When they do not, ngspice still writes the first analysis — as a
`constants` plot — so the file has two plots and the tree sees no operating
point. Two different capabilities are entangled in one test, and the sentence
picks the wrong one.

The probe already computes the right answer. `hier_op_names` reads 0 in exactly
this case, and `ase::cap_report` never looks at it.

## Fix shape

1. Decide `appendwrite` on **how many analyses came back in one file**, not on
   which analysis it was: two plots from a deck that asked for two analyses is
   an append, whatever they are named. A `constants` plot is still a plot the
   build kept.
2. Give `hier_op_names 0` its own sentence, or fold it into what S4 does with
   per-device saving — 0948 deliberately left this one unspoken because S4 owns
   what to do about it. What must not stand is the current arrangement, where
   the naming answer is measured, discarded, and reported as something else.

## Acceptance

* The stand-in above (real appends, different device names) measures
  `appendwrite 1 hier_op_names 0` and is **not** told to run one analysis at a
  time.
* A build that genuinely keeps only the last analysis still measures
  `appendwrite 0` and is still told so — row B2 of `test_ase_simcaps_0948.tcl`
  must stay green.
* Whatever is said about a naming difference is said about naming.
