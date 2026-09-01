# 0961 — a simulator whose location is written `./name` cannot be measured once the probe changes folder, and the code comment says the opposite

**STATUS: OPEN, and LATENT — not reachable through the Simulators window today.**
Found by item S3a's verification pass, reproduced first-hand by the write-up
before filing.

## What it is

Item S3a fixed issue 0949 by running the probe with the probe's own scratch folder
as the program's current directory — the only form measured to survive a space, a
dollar, a bracket, a quote and a semicolon in a simulation folder's name. Anything
resolved relative to the *caller's* folder therefore has to be made absolute
first, and `ase::cap_run` does that:

```tcl
if {[file pathtype $prog] eq {relative} && [file dirname $prog] ne {.}} {
  set prog [file normalize $prog]
}
```

The carve-out is for a **bare name** like `ngspice`, which Tcl's `exec` looks up
on the PATH and which the folder change cannot affect. But `[file dirname ./ng]`
is also `.`, and `./ng` is **not** a PATH lookup — Tcl treats any name containing
a separator as a path. So `./ng` falls into the carve-out, is left alone, and is
then resolved against the probe's scratch folder, where it does not exist.

The comment above it states the opposite as fact: *"A bare name with no folder in
it is left alone: that is a PATH lookup, which the move cannot affect."* For
`./ng` neither clause is true.

## Measured

Two forms of the same program, same session, same probe folder. Only the spelling
of the location differs:

```
C  ./fast     rc=1 out=/usr/bin/timeout: failed to run command './fast': No such file or directory
C  bin/fast   rc=0 out=I-RAN
```

## Why it is latent

`ase::sim_register` runs `file normalize` on the location it is given, so a
simulator added through **Setup > Simulators** or from the Command window is stored
absolute and never reaches this branch. Confirmed: registering `./relng` stores
`/tmp/.../bin/relng`. The broken branch is reachable only by calling
`ase::cap_run` directly, which nothing in the tree does with a relative name.

So this costs the user nothing today. It is filed because a comment that states a
false rule is how the next reader gets it wrong, and because the next caller of
`ase::cap_run` — S4 is the likely one — has no reason to suspect it.

## Why no test row catches it

Row **K5** of `tests/headless/test_ase_simcaps_0948.tcl` is the row for relative
program locations, and it builds its relative name as a multi-segment,
repo-root-relative path (`tests/headless/.scratch/...`), which takes the branch
that works. It never builds a `./name`. The row is honest — it self-skips loudly
when the stand-in is not below the working folder — but it cannot see this.

## Fix shape

One line and one comment. Normalize whenever the name contains a separator at all,
which is exactly Tcl's own rule for "this is a path, not a PATH lookup":

```tcl
if {[file pathtype $prog] eq {relative} && [string match {*/*} $prog]} { ... }
```

(plus the Windows separator, on the platform this file already guards for). Then
correct the comment to say what the carve-out really is: a name with **no
separator in it**. Row K5 grows a `./name` case.

## Acceptance

* `ase::cap_run ./prog ... $workdir $secs` starts the same program as
  `ase::cap_run [pwd]/prog ...`.
* A bare `ngspice` is still found on the PATH after the folder change.
* The comment describes the rule the code implements.
