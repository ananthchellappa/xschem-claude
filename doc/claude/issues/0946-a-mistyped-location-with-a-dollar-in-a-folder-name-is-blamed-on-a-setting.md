# 0946 — a mistyped simulator location with a dollar sign in a folder name is blamed on a setting

**Status: OPEN.** Filed by the S2a write-up agent, who measured it first-hand on
the repaired tree before writing this down. It is the **narrowed remainder** of
issue 0938 — narrowed, not removed — and it is 0933's still-open storage half
seen from a third angle.

**It is not a regression and it is not new.** The shipped-before code said the
same sentence in this arm. What the 0938 repair changed is how much of the arm
is left: the *working* program at a dollar-bearing path used to get this
sentence too, and now only a location where **no file is there** does.

**Issue 0938's own write-up scopes this remainder too narrowly, and this file
exists to correct that.** 0938 says it happens "after a restart, an entry whose
dollar-bearing program has since been **deleted**". Both qualifiers are wrong.
It happens in the **live session, on the first gesture, with nothing deleted and
no restart involved** — a typo is enough.

## What the user does

Their PDK lives under a folder whose name has a dollar sign in it. They add
their simulator in `Setup > Simulators…` by typing the location the disk really
spells, and they get one letter wrong — or the program has since moved.

## What they are told, measured

```
A1 the location typed   = /tmp/wu0946/root/p$q/bin/ngspce
A2 does it exist        = 0
A3 sibling that DOES    = 1
A6 entry                = name typo path {/tmp/wu0946/root/p$q/bin/ngspce} ... varok 0 ok 0
A7 the list's problem   = The location given for the simulator named typo mentions a setting
                          this session does not know about, so it cannot be turned into a real
                          file name: /tmp/wu0946/root/p$q/bin/ngspce
A8 sim_status ok        = 0
```

The identical typo one folder over, at a path with no dollar sign, is told the
truth:

```
B1 the list's problem   = There is no file at /tmp/wu0946/plain/bin/ngspce, which you
                          registered as the simulator named typo2. Check that you typed the
                          location correctly, or point this entry at a different file.
```

So the user with the ordinary PDK is sent to look at their disk, which is where
the mistake is, and the user with the dollar-sign PDK is sent to look for a
setting they never used. Under the **plain-English ruling** — *say what happened
AND what the user can do about it* — the second sentence does neither.

It is the more painful arm precisely **because** issue 0945 now advertises this
gesture as supported: typing your real dollar-bearing path is a documented thing
to do, so getting it slightly wrong is a thing users will do.

## Why

`ase::expand_path` is `subst -nocommands -nobackslashes`. Given
`/…/p$q/bin/ngspce` it tries to read a variable named `q`, fails, and raises.
The new guard in `ase::sim_register` catches that and asks `file exists`; when a
program **is** there it takes the location as the file name it is (0938/0945).
When nothing is there, there is no evidence left to choose between the two
readings, and the code keeps the older one — "you meant a setting".

**The program genuinely cannot tell which the user meant.** `$q` is a
well-formed variable reference *and* a legal folder name, and the one thing that
could have decided it — a file on the disk — is absent. That is why this is a
wording problem with a real fix rather than a logic bug with an obvious one.

## Options

1. **Say both things in one sentence, since both are true.** *"The location
   given for the simulator named typo could not be turned into a real file name:
   it mentions `$q`, which this session has no setting for, and there is no file
   at that location either. Check the spelling, or set the setting."* Mints one
   new sentence, needs no new state, and is honest about the ambiguity. This is
   the recommended option.
2. **Ask the disk one level up.** If the parent folder of the location exists,
   the dollar was almost certainly a folder name, so answer the missing-file
   sentence. Guesses well in practice; guesses silently, and a wrong guess is
   the same class of defect wearing the other hat.
3. **Keep what the user typed**, so the answer never has to be reconstructed —
   which is 0933's storage half, and fixes 0947 at the same time. Largest, and
   the only one that removes the ambiguity rather than describing it.

## Acceptance, when it is fixed

A row in `tests/headless/test_ase_simreg_0931.tcl`, beside R19 (which covers the
folder and non-executable outcomes of the same arm): register a location under a
real dollar-bearing folder that names **no file**, and assert the sentence tells
the user about the missing file, or about both possibilities — and never about a
setting alone. Its control is the existing plain-path typo arm, which must keep
saying exactly what it says today.
