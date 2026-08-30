# 0932 — clearing your simulator choice does not survive a restart

**STATUS: OPEN.** Measured 2026-08-29 at commit `0225a962`, the commit that
built the simulator registry (issue 0931). Found by the adversarial verifier of
that item, reproduced independently before filing.

## What the user sees

You registered two builds of your own, `A` and `B`. Then you changed your mind
and went back to the plain `ngspice` on your `PATH` — the gesture that means
"none of mine, thanks". You save the list. You quit xschem and start it again.

**Your build `A` is in force, and nothing tells you.** Every run from then on
starts a program you deliberately took out of service, and the numbers that end
up on the schematic came from it.

## Measured, verbatim

Two real processes, `HOME` redirected into a scratch tree so the user's own
`~/.xschem` was never touched. The first process:

    KID1 regA=1
    KID1 regB=1
    KID1 selected=''
    KID1 runcmd=ngspice -b /tmp/d.spice 2>@1
    KID1 write=1

The whole file it wrote:

    # xschem ASE-L simulator list -- written by xschem, issue 0931.
    # Read once at startup. Edit by hand if you like: it is a plain
    # Tcl script of ase::sim_register lines.
    ase::sim_register A /…/wu/bin/mysim -args {} -backend {}
    ase::sim_register B /…/wu/bin/mysim -args {} -backend {}

A second process, same `HOME`, no load call of its own:

    KID2 selected='A'
    KID2 list=2
    KID2 runcmd=/…/wu/bin/mysim -b /tmp/d.spice 2>@1

The full, unfiltered output of the second process contains **no message of any
kind** about the change.

## Why

`ase::sim_write_conf` (src/ase.tcl) writes one `ase::sim_register` line per
entry and an `ase::sim_select` line **only when something is in force**:

    if {$sim_use ne {} && [dict exists $simulators $sim_use] \
        && [dict get $simulators $sim_use origin] ne {rc}} {
      puts $fp [list ase::sim_select $sim_use]
    }

So "no choice" has no representation in the file at all. On the way back in,
`ase::sim_register` auto-selects the first entry (issue 0931 decision D1,
deliberate and right in its own context):

    if {$sim_use eq {}} { set sim_use $name }

Two decisions that are each correct on their own compose into a silent
reversal of the user's own gesture.

## Why this one matters more than its size

Issue 0931 decision **D2** refuses to fall back to the `PATH` program when the
user's registered choice is broken, and the stated reason is that *running a
different program than the one the user picked, and mentioning it only in a
pane they may not be reading, is ruling D5-1 in another costume*. This defect
arrives at exactly that place through the persistence layer instead, and does
not even mention it in a pane.

## Why no test row caught it

`tests/headless/test_ase_simreg_0931.tcl` rows **E2** (in-process round trip)
and **E6** (a real restart in spawned children) both set a choice before
saving. The one state that does not survive is the one neither row visits.

## Options

1. **Write the cleared choice explicitly** — emit `ase::sim_select {}` after
   the register lines when nothing is in force. One line in the writer, and
   the file keeps saying exactly what the user meant.
2. **Do not auto-select while loading the file** — set `sim_origin conf`
   already marks that pass; the loader could suppress the first-entry
   auto-select and let the explicit `ase::sim_select` line (present or absent)
   be the only thing that chooses. Cleaner in principle, but it makes a
   hand-written file with no select line behave differently from the same
   registrations typed in a session.
3. Leave it, and say so in the sentence the user reads at startup. Rejected on
   sight: there is no such sentence today.

Option 1 is the smaller change and the one that keeps a hand-edited file and a
session behaving alike.

## Acceptance, when it is fixed

A row that is the E6 restart with the choice **cleared** before the save, and
that asserts the second process reports `ngspice`, not the registered build —
plus the round-trip row E2 repeated with an empty selection.
