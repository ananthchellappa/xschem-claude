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
