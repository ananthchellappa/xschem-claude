# 0934 — the co-simulation build-script resolver is silent on a wrong path, and accepts a folder

**STATUS: OPEN.** Measured 2026-08-29 at commit `0225a962`. Pinned as KNOWN by
row **C7** of `tests/headless/test_ase_simreg_0931.tcl`, deliberately not
fixed by issue 0931 (out of that item's scope), and filed here because it is
the exact failure mode that item was written to avoid, still live one proc
away.

## What the user sees

They point `::ASE_COSIM_BUILD` at their own build script and get it wrong in
any of three ordinary ways. Nothing is said at the moment it is wrong. Later,
the sentence they do read blames a variable **they have already set**:

    build_cosim_so.sh not found (set ::ASE_COSIM_BUILD)

## Measured, verbatim

    C1 missing     -> ''  (exists=0)
    C2 mode644     -> ''  (exists=1 exec=0)
    C3 a DIRECTORY -> '/usr/local/bin'  (isfile=0 executable=1)

* **C1** — the path does not exist: returns empty, prints nothing.
* **C2** — the file exists at mode 644 and is not marked runnable: returns
  empty, prints nothing.
* **C3 — worse than silence.** `file executable` answers 1 for a **directory**,
  and there is no `file isfile` guard, so a folder is returned as if it were
  the build script and something downstream tries to execute it.

## The whole proc, src/ase.tcl:2469-2481

    proc ase::cosim_build_script {} {
      if {[info exists ::ASE_COSIM_BUILD] && $::ASE_COSIM_BUILD ne {}} {
        if {[file executable $::ASE_COSIM_BUILD]} { return $::ASE_COSIM_BUILD }
        return {}
      }
      …
    }

and the sentence, src/ase.tcl:2569.

## Why it matters

This is the tree's other "a startup variable names an executable" resolver, and
it is the one a reader would copy. Issue 0931 built `ase::sim_check` with four
ordered guards — empty, missing, **a folder**, not runnable — precisely because
of what is measured above, and row C7 exists so that nobody satisfies a
simulator-registry item by copying this neighbour, and so the day this is
repaired that row is what says so.

## Options

1. Give it the same four guards and the same mint: an `ase::sim_why`-style
   sentence naming the variable, the path, and what to do. The `badvar`
   vocabulary is already written and already plain English.
2. Minimum viable: add `file isfile` (half of C3 is an executed directory,
   which is the only arm here that can do damage) and make the downstream
   sentence say *what* is wrong with the path rather than "not found (set
   the variable)".

## Acceptance, when it is fixed

Row C7 flips from asserting the silence to asserting the sentence; add the
directory arm, which nothing covers today at all.
