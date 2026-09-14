# The operating-point ladder, as two streams — debt **M1**, answered

**Measured 2026-09-13 by the driver**, before Stage 10 was dispatched, because M1 was due
*"before Stage 10"* and it gates §10b's **live** pane rather than the stage.

**The question, as `LEDGER.md` posed it:** *Can the ladder pane get stdout and stderr as two
ordered streams? ASE-L folds them with `2>@1`, and two `ngdebug` lines carry no trailing newline.*

**The answer is NO on the fold, YES on separate streams, and the second half of the question turns
out to be the sharper one.**

## The deck

Not a failing operating point — a **succeeding** one that exercises the ladder, which is what
§10b's pane reads. `.options noopiter` skips plain Newton so gmin stepping runs and prints; the
circuit is three diodes in series off a 5 V source through 1 Ω, which needs the ladder and then
settles at `v(a) = 2.570247e+00`.

```
.model dmod d(is=1e-14 n=1)
v1 in 0 5
r1 in a 1
d1 a b dmod
d2 b c dmod
d3 c 0 dmod
.options noopiter gminsteps=10 srcsteps=10
.control
set ngdebug
op
print v(a)
.endc
.end
```

## 1. ⚠ THE FOLDED STREAM IS NOT IN CHRONOLOGICAL ORDER, AND IT IS NOT EVEN CLOSE

`ngspice -b ladder.cir > fold.txt 2>&1` — what ASE-L's `run_cmd` builds, `2>@1` appended
(`src/ase.tcl:720`, and the item at `:10330-10391` that made the command composable kept it):

```
     1  Note: Starting spice3 gmin stepping          <- stderr
     2  Trying gmin =   1.0000E-02 Note: One successful gmin step
   ...  (eleven rungs)
    13  Note: spice3 gmin stepping completed
    14
    15  Note: No compatibility mode selected!        <- stdout
    18  Circuit: * exercise the op ladder ...
    20  Doing analysis at TEMP = 27.000000 and TNOM = 27.000000
    22  Using SPARSE 1.3 as Direct Linear Solver
```

**Every one of the 13 stderr lines precedes every one of the 13 stdout lines** — and
`Note: No compatibility mode selected!`, the `Circuit:` banner and `Doing analysis` all happen
**before** gmin stepping begins. The fold is not *interleaved unpredictably*; it is **systematically
reordered**, because stdout to a file or pipe is block-buffered and flushed at exit while stderr is
unbuffered.

⚠ **So `PLAN.md` §10b's instruction — *match on line CONTENT, never on arrival order, and never
build a state machine that assumes sequence* — is now a measurement rather than a caution, and it
is stronger than it reads.** A pane that trusted the fold's order would show the whole ladder
*before* the analysis banner on every run, and a "live" pane reading the fold would see **nothing
from stdout at all** until the process exits.

## 2. Separate streams ARE each correctly ordered

`ngspice -b ladder.cir > out.txt 2> err.txt` gives 13 lines in each file, each internally in
order: `err.txt` is the ladder from `Starting` to `completed`, `out.txt` is the banner, the solver
line, `v(a) = 2.570247e+00` and the trailing note.

**So the ladder can be read in order — but only if ASE-L stops folding.** That is a change to the
capture in `ase::run_deck` / `run_cmd`, and it is a real cost to price into §10b rather than a
detail: `2>@1` is appended by `run_cmd` itself and every existing reader of the log expects one
stream.

## 3. ⚠ THE LADDER'S WRITES DO NOT RESPECT LINE BOUNDARIES — AND THE PARTIAL IS ALWAYS THE RUNG

The debt's second clause said *"two `ngdebug` lines carry no trailing newline"*. Measured from the
other end, reading the pipe with `os.read` and reporting each chunk:

```
chunk 1: 121 bytes, ends-with-newline=False, tail=b'cessful gmin step\nTrying gmin =   1.0000E-03 '
chunk 2: 464 bytes, ends-with-newline=False, tail=b'cessful gmin step\nTrying gmin =   1.0000E-11 '
chunk 3:  95 bytes, ends-with-newline=False, tail=b'000E-12 Note: One successful gmin step\nNote: '
chunk 4:  31 bytes, ends-with-newline=True,  tail=b'spice3 gmin stepping completed\n'
TOTAL chunks=4  chunks NOT ending in a newline=3
```

**Three of four chunks end mid-line, and the dangling text is always `Trying gmin = <value> `** —
the announcement of the rung *currently being attempted*. The newline arrives only when that rung
finishes and `Note: One successful gmin step` is written.

⚠ **This is the whole difficulty of a live ladder pane, and it is the opposite of a detail.** The
one event the pane exists to show — *which rung are we on right now* — is precisely the one that is
never newline-terminated while it matters. A reader built on `gets` blocks on it and the pane
freezes one rung behind the simulator. **A live pane must read BYTES, not lines, and must render an
unterminated tail as an in-progress rung.**

In the finished *file* every line is terminated, because the following write supplies the newline —
which is why this never showed up in any after-the-fact log read, and why the debt was worth
paying before the stage rather than during it.

## What this settles, and what it leaves

* **M1 is closed.** Two ordered streams are available; the fold ASE-L uses today cannot provide
  them, and the reason is buffering rather than anything about ngspice.
* **§10b's live pane is affordable**, at the price of a second capture channel and a byte-oriented
  reader. It is no longer blocked on an unknown.
* **Not measured here:** whether ASE-L's Tcl-side capture (`execute` + `execute_fileevent`) can
  carry two channels without reordering them against each other — that is a question about the
  harness, not about the simulator, and it belongs to whoever builds the pane.
* Both binaries print the same ladder text; this file was measured on
  `/home/analog/dev/ngspice/build-ver_50/src/ngspice` and the fold order was confirmed identical on
  `/usr/bin/ngspice`.

---

## 4. Fixture text for §10a/§10b, and one warning the stage will need

Captured while paying M1, on the fork, `set ngdebug` in the `.control` block. All of it is
**stderr**.

**Rung 2, gmin stepping** — the shape §10b's pane parses:

```
Note: Starting spice3 gmin stepping
Trying gmin =   1.0000E-02 Note: One successful gmin step
Trying gmin =   1.0000E-03 Note: One successful gmin step
...
Note: spice3 gmin stepping completed
```

**Rung 4, the transient operating point** — two lines, and they are how a user could be told
their operating point came from a transient:

```
Note: Transient op started
Note: Transient op finished successfully
```

### ⚠ AND `optran` RESCUED EVERY DECK THAT WAS BUILT TO FAIL

`.options noopiter gminsteps=0 srcsteps=0 itl1=1` on three series diodes — Newton skipped, both
stepping ladders disabled, one iteration allowed — **still converges**, because rung 4 runs and
succeeds. This is `PLAN.md` §10b's *"⚠ ON BY DEFAULT in this ngspice"* confirmed by measurement
rather than by reading `init.c:77-94`.

⚠ **Three deck spellings failed to turn it off**, all at rc 0 with no complaint:

```
.options optran 0 0 0 0 0 0
.options optran=0
.options optran = 0 0 0 0 0 0
```

Each one left `Note: Transient op started` / `finished successfully` in the log. **Not a proof that
it cannot be done from a deck** — it is a measurement that the obvious spellings do not, silently.

That matters to §10b directly, because its rung-4 checkbox is a control that must be able to mean
**off**. Whoever builds it must find the spelling that works and **prove it with a deck that fails
to converge when the box is cleared** — a checkbox that silently does nothing would be worse than
no checkbox, and this is exactly the class of defect this batch keeps finding (an accepted-and-inert
setting: `measureprec` on 45.2, difference #5).

It is also why **§10a's starred `CKTncDump` table could not be captured here**: with `optran` on by
default and unkillable by the spellings above, the deck never reaches the failure path that prints
it. `PLAN.md` §10's suite is specified to run on **canned log text** for determinism, so this does
not block the stage — but the canned text still has to come from somewhere, and whoever writes it
will meet this first.

## 5. §10b's headline number, reproduced exactly on both binaries

`PLAN.md` §10b says an `optran`-supplied operating point *"returns the TRANSIENT state at the stop
time as your operating point — measured 0.9999550 instead of 1.0 on a 1 us RC"*. Re-measured
2026-09-13 under the plan's own stated conditions:

```
v1 in 0 1
r1 in out 1k
c1 out 0 1n
```

| | apt 45.2 | the fork |
|---|---|---|
| plain `op` | `v(out) = 1.000000e+00` | `1.000000e+00` |
| `.options noopiter gminsteps=0 srcsteps=0` → rung 4 supplies it | **`9.999550e-01`** | **`9.999550e-01`** |
| what stderr said | `Note: Transient op started` / `finished successfully` | identical |

**Identical to every digit on both binaries, and identical to the number the plan recorded.**

⚠ **So the sentence §10b wants on the OP form is true, and it is true of a number the user is
already looking at.** The operating point is wrong in the fifth digit on a *trivial* RC; the error
is whatever the circuit's slowest time constant has left unsettled at optran's 10 µs stop, so a
real bench is not bounded by anything this deck shows.

⚠ **And the only signal that it happened is a line on stderr that no user ever sees** — folded into
the log by `2>@1` and, per §1 above, printed out of order when it gets there. That is the whole
argument for §10b's sentence existing.

### A note on how this was got wrong once

An earlier attempt in this batch tried to reproduce the plan's number with `option noopiter`
**alone**, got `1.000000e+00`, and read it as a refutation. It was not: with only the first rung
disabled, **gmin stepping succeeds at rung 2** and returns the true answer. The plan said
`.options noopiter gminsteps=0 srcsteps=0` and meant all three. **A claim is not refuted until it
has been re-run under its own stated conditions** — recorded here because the near-miss cost
nothing this time and the same shape has cost this batch a day before.
