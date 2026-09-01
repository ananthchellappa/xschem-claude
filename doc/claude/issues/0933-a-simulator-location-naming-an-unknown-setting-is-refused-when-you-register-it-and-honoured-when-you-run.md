# 0933 — a simulator location naming an unknown setting is refused when you register it, and honoured when you run

**STATUS: HALF FIXED** 2026-08-29, as part of issue 0937 (backlog item S2).

Half one — the two different answers about one entry — is CLOSED. The
Simulators dialog has to show a per-entry reason in a Problem column, and a
column that contradicted in writing the sentence the user was just given would
be the defect the dialog exists to end. `ase::sim_entry_kind` is now the
entry-flavoured validator: it asks whether the stored location can be turned
into a real file name at all before it asks whether a file is there, and
`ase::sim_status` uses it too, so what the list shows against an entry and what
a run refuses with are ONE sentence (rows R5 and R7 of
`tests/headless/test_ase_simreg_0931.tcl`).

Half two — the unexpanded literal is what gets STORED, so that arm also skips
the path normalisation every other arm gets — is still OPEN. Nothing in 0937
touched it: the stored path is validated, never the expansion, and every field
`ase::sim_status` answers with is byte-identical to what it answered before.

Measured 2026-08-29 at commit `0225a962` (issue 0931's
commit). Two halves, one cause.

## What the user sees

### Half one — two different answers about one entry

A PDK or workarea startup file names a build the portable way the model files
already do, `$::PDK_ROOT/bin/ngspice`, in a session where `PDK_ROOT` is not
set. Registering it says, out loud and correctly:

> The location given for the simulator named pdk-build mentions a setting this
> session does not know about, so it cannot be turned into a real file name:
> `$::NOSUCHROOT/bin/ngspice`

and the entry is kept **flagged unusable** — which is the flag the Setup dialog
(item S2) will render as broken.

Then the run starts it anyway, if a file happens to sit at that literal path.
Measured, with a directory genuinely named `dollar$dir`:

    F3 register returns -> 0
    F3 entry ok         -> 0
    F3 sim_status ok    -> 1  source -> registry  why -> ''
    F3 run_cmd          -> {/…/dollar$dir/ngspice} -b /tmp/d.spice 2>@1

Registration says unusable. The resolver says fine, with nothing to say. The
program runs.

### Half two — decision D6 is not applied on that arm

Issue 0931's decision **D6** normalises a registered path to absolute at
registration, because `ase::run_deck` `cd`s into the run directory before it
launches anything, so a relative argv0 would resolve somewhere else. On this
arm the path is stored exactly as typed:

    F3b register relative-with-dollar -> 0
    F3b stored path       -> dollar$dir/ngspice
    F3b run_cmd from here -> {dollar$dir/ngspice} -b d.spice 2>@1
    F3b after cd /tmp     -> ase: There is no file at dollar$dir/ngspice, which
                             you registered as the simulator named mine. …

    CONTRAST: a normal relative path
    F3c register relative -> 1
    F3c stored path       -> /…/wu/bin/mysim

The same entry answers "here it is" from one directory and "there is no file
there" from another, about a file that does exist where the user registered it.

## Why

`ase::sim_register` (src/ase.tcl) treats a failed `ase::expand_path` as a bad
*path* rather than a bad *call* — which is the right call — but it takes a
branch that skips `file normalize` entirely and leaves `$p` as typed:

    if {[catch {ase::expand_path $p} out]} {
      set kind badvar
    } else {
      set p [file normalize $out]
    }

`ase::sim_status` then re-validates with `ase::sim_check`, which asks only
`file exists` / `isfile` / `executable` about the literal string. It has no
memory of the `badvar` verdict, deliberately (re-validating at resolution time
is what catches a file that was deleted after registration — issue 0931's own
reasoning, and it is correct). The two are simply not talking about the same
question.

## Options

1. **Re-expand at resolution.** `ase::sim_check` (or `sim_status` around it)
   attempts `ase::expand_path` first, and returns the `badvar` kind when it
   fails. Then a setting that arrives *later* in the session — a PDK loaded
   after startup — makes the entry work, which is arguably what a user would
   expect from `$::PDK_ROOT`, and a setting that is still missing refuses with
   the sentence that already exists. Costs one row.
2. **Carry the registration verdict.** `sim_status` reads the entry's `ok`
   field and refuses `badvar` entries without re-checking. Simpler, but it
   freezes a `$::PDK_ROOT` entry as broken for the rest of the session even
   after the variable appears.
3. Normalise on the `badvar` arm too, so at least half two goes away. This does
   not settle half one and would store a normalised path built from a name that
   was never resolved — worse, not better.

Option 1 looks right: the entry is a *recipe*, and the recipe is worth
re-reading each time something is about to be started.

## Acceptance, when it is fixed

Rows that assert (a) `ase::sim_status` refuses a `badvar` entry with the same
sentence `ase::sim_register` printed, and (b) the same entry becomes usable
once the setting it names exists — plus half two folded into the existing
row B12 (the `cd` trap) with a `$`-bearing relative path.

## Not to be confused with

Row **C8** of `tests/headless/test_ase_simreg_0931.tcl` covers the *report* at
registration and is green. Nothing covers what the resolver then does with the
entry.
