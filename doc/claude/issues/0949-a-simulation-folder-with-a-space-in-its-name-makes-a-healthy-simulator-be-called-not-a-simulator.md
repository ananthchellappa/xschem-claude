# 0949 — a simulation folder with a space in its name makes a healthy simulator be called "not a simulator"

**STATUS: FIXED FOR THE PROBE (2026-08-30, item S3a). The older half — the
REAL deck's own `write [raw_file $state]` line — is NOT fixed here and is filed
separately as issue 0957 for the deck-emission item. Rows K1-K6 of
`tests/headless/test_ase_simcaps_0948.tcl`.**

## What the user sees

Their simulation folder is somewhere ordinary for this machine — say
`/mnt/c/Users/First Last/designs` — and they press Run. The Command window
tells them, every single time:

> `/usr/local/bin/ngspice`, which is the program the simulator you picked will
> start, produced no results at all when it was tried on a tiny test circuit.
> Check that it really is a circuit simulator, or point this entry at a
> different file.

Nothing is wrong with their simulator. It is the stock ngspice-46+ that this
box has always had, and it answers every question correctly the moment the
folder name has no space in it. The sentence sends them to replace a working
program.

## Measured

Same session, same binary, one thing changed — the folder the probe writes
into:

```
resolved: /usr/local/bin/ngspice
--- A: simulation folder with an ordinary name ---
  caps    : known 1 usable 1 appendwrite 1 blanket_op_save 0 hier_op_names 1
  said    :
--- B: simulation folder whose name has a space in it ---
  caps    : known 1 usable 0 appendwrite 0 blanket_op_save 0 hier_op_names 0
  said    : cap_not_a_simulator
```

A dollar sign in the folder name does the same thing — measured by 0948's
verification pass, with the identical sentence.

## Mechanism

`ase::cap_workdir` puts the probe's scratch inside the simulation directory,
and the probe deck names its results file **unquoted**:

```tcl
src/ase.tcl   write $rawa
```

ngspice's `write` takes the first whitespace-separated word as the file name,
so `write /mnt/c/Users/First Last/designs/.ase_probe/probe_a.raw` writes to
`/mnt/c/Users/First`, and the probe reads back nothing at the name it asked
for. Nothing wrote nothing; the probe simply cannot see what was written.

The verdict is then honest about what it saw and wrong about what it means:
`usable 0` says "no results came back", and `ase::cap_report` renders that as
a statement about the user's **program**. This is 0948's own guard failing in
the direction the branch keeps failing in — a sentence that is locally correct
at every joint and collectively an accusation against the wrong thing. It is
also, one commit later, the same shape as **0938** ("a simulator under a folder
with a dollar sign in it runs again"), whose own write-up says a dollar sign in
a folder name used to "send them looking at a disk".

## The half that is older than this

The real deck has the identical unquoted line:

```tcl
src/ase.tcl:5345        lappend lines "write [raw_file $state]"
```

so in a folder with a space in it the user's actual simulation already fails to
produce a results file, and has since before 0948. That is the deeper defect
and it is why this is filed rather than patched in the probe alone: quoting only
the probe would leave a user in that folder with working capability detection
and a run that still writes its results somewhere else.

## Fix shape

1. Quote the file name in **both** places — the probe deck and `render_deck` —
   and confirm the quoting ngspice actually honours (`write "..."`), on a name
   containing a space, a dollar sign and a bracket.
2. Then, separately, make `cap_report` unable to blame a program for a
   condition that is about a path: a probe that could not even write where it
   asked should answer `known 0` (nothing was measured) rather than
   `usable 0` (measured, and it produced nothing). Absent means "nobody
   measured" — 0948's own contract already says so for the guards; this is the
   arm that violates it.

## Acceptance

* With the simulation folder named `with space`, a stock ngspice measures
  `usable 1 appendwrite 1 hier_op_names 1` and **nothing is said**.
* The same folder produces a real results file from a real Run.
* A program that genuinely writes nothing still answers `usable 0` and is still
  reported — the honest arm must not be lost to the fix.

## The fix (item S3a, 2026-08-30), and why it is not a quoting fix

The write-up guessed the program truncates the path. It does not. Measured
first-hand on ngspice-46+: given `write /a/b c/probe_a.raw` it reads the second
whitespace word as a VECTOR name, finds no such vector, prints

```
Error during 'write': no writable vector found.
```

and writes nothing anywhere.

**No quoting form inside the deck covers it.** Six write forms were measured
against five hostile folder names. A bare name, `write "..."`, backslash
escaping, a `.control`-level `cd "..."` and an indirection through
`set ofn = "..."` all fail for a folder called `do$llar`, because the program
expands `$` inside `.control` regardless of quoting. The ONE form that produced
the results file for a space, a dollar, a square bracket, a single quote and a
semicolon alike is: give the program the target folder as its own current
directory, and name the results with a bare file name.

So the fix is a working-directory change, not a quoting change:

* `ase::cap_run` now takes a `workdir` and runs the program with it underneath,
  restoring the caller's folder on every path out including the error path;
* a program registered by a RELATIVE location is resolved to an absolute one
  before the move, or a user who registered `./build/ngspice` would stop being
  able to run it. A bare name with no folder in it is left alone — that is a
  PATH lookup, which the move cannot affect;
* both probe decks now say `write probe_a.raw` / `write probe_b.raw`.

That dovetails with 0951's private directory: the folder the program is given is
the probe's own, so nothing it writes can land in the user's way.

Row K3 drives the real `/usr/local/bin/ngspice` through folders named
`with space` and `do$llar` against a plain control. Rows K1/K2 do the same with a
word-faithful stand-in that reproduces the measured parser column, so the defect
stays covered on a box with no simulator installed. Row K6 is the structural
half — every `write` line in every deck the probe emits names a bare file — which
no behavioural row can see once the folder is right.

## Correction, 2026-08-30 — the relative-location carve-out is stated wrongly

The bullet above says a bare name with no folder in it is left alone because
"that is a PATH lookup, which the move cannot affect". The code's test for a bare
name is `[file dirname $prog] ne {.}`, and `[file dirname ./ng]` is also `.` —
so a location written `./ng` takes the carve-out, is not made absolute, and is
then resolved against the probe's own folder, where it is not. Measured:
`./fast` -> `failed to run command './fast': No such file or directory`;
`bin/fast` -> ran. The example in the bullet, `./build/ngspice`, is unaffected —
it is the single-segment form that breaks. Latent (`ase::sim_register` normalizes,
so nothing reachable from the Simulators window gets there) and filed as
**issue 0961** with the one-line fix.
