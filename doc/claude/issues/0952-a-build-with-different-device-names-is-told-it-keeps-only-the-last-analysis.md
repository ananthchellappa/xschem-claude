# 0952 — a build that spells device parameters differently is told it keeps only the last analysis, and given advice that changes nothing

**STATUS: FIXED (2026-08-30, item S3a) — whether the analyses were added to
the one file and whether the device parameter names are the ones this tree reads
are now two separate measurements, and neither can fail the other. Rows B5, B9
and B10 of `tests/headless/test_ase_simcaps_0948.tcl`.**

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

## The fix (item S3a, 2026-08-30)

`appendwrite` was decided by `$op ne {} && [lindex $op 1] >= 1 && $tr ne {}` —
i.e. by whether the vectors the probe expected turned up under the names it
expected. A build that adds every analysis correctly but spells its device
parameters differently saves no vector the probe named, so its operating point
degenerates to a `constants` plot, no plot in the file is called
`Operating Point`, and the append question answered no about a build that
appended perfectly. Measured: the file held TWO plots, `constants` with one point
and `Transient Analysis` with fifty-nine.

It is now decided by the only thing that is actually about appending:

```tcl
set appendwrite [expr {[llength $pa] >= 2 ? 1 : 0}]
```

Deck A asks for two analyses and two writes into one file. Two plots coming back
in that one file means the writes were added, whatever the plots are called, and
that is decidable without knowing any vector's name.

**The point-count requirement moved to the key that owns it.** An operating point
carrying `No. Points: 0` holds no device numbers for anyone to read, so
`hier_op_names` now requires `[lindex $op 1] >= 1`. That claim is unchanged — row
B5 still asserts an empty operating point must not read as success — it has moved
into the key it was always about. Letting it answer the append question is what
produced this defect.

**The say-site follows for free.** With `appendwrite 1` the "keeps only the last
analysis" arm of `ase::cap_report` never fires for this build, so nothing is said
and the record the Simulators window reads back is empty (row B10). That was the
half that mattered: the sentence was a wrong diagnosis AND advice that changes
nothing, because running one analysis at a time would not make the device names
readable.

## Still open, and deferred here on purpose

A build whose device parameter names this tree cannot read is measured
(`hier_op_names 0`) and **still says nothing about it**. Giving that its own
sentence is deck-emission's business — the emitter is what has to do something
different about it — and is left to the item that owns deck emission.
