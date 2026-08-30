# 0945 — a simulator typed at its real path, with a dollar sign in it, is refused when you add it

**Status: FIXED 2026-08-29 (item S2a), by the same guard that closed issue
0938's restart half.** Filed and closed in the same pass, because the
measurement that reproduced 0938 found this arm unfiled beside it.

**This is NOT the 0937 regression.** It is refused consistently at both ends —
registration and the run agree — so no row and no reading of 0938 could have
found it there. It dates from 0931 (`0225a962`), the commit that first taught
`ase::sim_register` to turn a location into a file name, and it is the other
face of 0933's still-open storage half.

## What the user does

Their PDK lives under a folder whose name has a dollar sign in it. Instead of
the portable form, they type the location their disk actually spells:

```
/tmp/m0938/root/p$q/bin/ngspice
```

## What happened

```
H1 sim_register returns = 0
H2 sim_said at reg time = The location given for the simulator named lit
                          mentions a setting this session does not know about,
                          so it cannot be turned into a real file name:
                          /tmp/m0938/root/p$q/bin/ngspice
H3 stored entry         = ... path {/tmp/m0938/root/p$q/bin/ngspice} ... ok 0
```

The program at that path runs perfectly from a shell. The sentence blames a
setting; the path names no setting. The `$q` is a folder name.

## Why it happened

`ase::sim_register` turns the location into a file name with
`ase::expand_path` — `subst -nocommands -nobackslashes` — and treated **any**
failure as a bad location. A `$` followed by a name character is the one shape
that fails (measured: a bare trailing `$`, `[x]`, a backslash and braces all
come through untouched), and a real folder name can contain one.

## What shipped

**A location that already names a real file is a file name, not a template.**
When the substitution fails and `file exists` says there is a program sitting at
that location, registration takes it as the file name it is and normalises it,
exactly as it normalises the successful arm. It defers to the filesystem guards
that follow — a folder is still reported as a folder, a file without its
executable bit still as one — and a location naming a setting nobody set names
nothing on the disk, so that arm still says what it always said.

The guard can only ever turn a refusal into a run. It never changes a location
that works today.

**The rule this creates has not been ratified**: what a location means now
depends, in this one arm, on what is on the disk at the moment you add it. It is
on the user's queue.

## Acceptance rows

**R16** in `tests/headless/test_ase_simreg_0931.tcl`: registering the literal
absolute path returns 1, the entry's `ok` flag is 1, the list shows no problem
against it, the resolver says ok, and **the program actually starts** (the
backend's own command line, `eval exec`-ed against a stub echoing a sentinel).
Its second half is the normalisation term — a location written with a redundant
`./` step must be stored cleaned, because the value stored, the value every
message shows and the value handed to the run have to be one string.
