# `pss` before Stage 14 opens — it SEGFAULTS on a short argument list, on both binaries

Taken by the driver on **2026-09-13** while the crews held the code. Both binaries:
`/usr/bin/ngspice` (**45.2**) and `/home/analog/dev/ngspice/build-ver_50/src/ngspice`
(**46+**). ⚖ **R7** has ruled that the PSS panel ships, *explicitly experimental*. This is
what "experimental" turns out to mean in practice, and it is sharper than the ruling
assumed.

## The measurement

One RC deck, one `pss` command, argument count varied. `SURVIVED` is an `echo` on the line
after the `pss` call, so it answers "did the process live?" rather than "did the analysis
work?".

| arguments | 45.2 | the fork | `SURVIVED` printed |
|---|---|---|---|
| `pss 1meg 1m out 1024` (**4**) | **rc 139** | **rc 139** | **no, on either** |
| `… 10` (5) | rc 0 | rc 0 | yes |
| `… 10 50` (6) | rc 0 | rc 1 | yes |
| `… 10 50 5e-3` (7) | rc 0 | rc 0 | yes |
| `… 10 50 5e-3 uic` (8) | rc 0 | rc 0 | yes |

**Four arguments kills the process with SIGSEGV on both binaries**, printing only
`Error: Strange behavior` first. Five or more survive.

The one-argument difference between the binaries — rc 1 against rc 0 at six arguments — is
the analysis aborting, not the process dying; `SURVIVED` printed in both.

## Why this matters more than an ordinary refusal

This batch classifies what a bad analysis costs. The classes so far were *rc 1 with
`$sim_status` 1* (the starved class: `noise`, `tf`, `sens`), *rc 0 with the guard silent*
(`pz`), and *exit(1) that takes the whole deck with it* (`sp` with no port). **`pss` with a
short argument list is worse than all of them:**

* **SIGSEGV, rc 139.** No `$sim_status`, no guard, no `remzerovec`, no salvage — the
  checkpoint machinery from issue 1433 runs *in the deck*, and there is no deck left.
* Everything after it in emit order dies with it, **including `op`**, which this batch keeps
  LAST (0964) precisely so that it is the one thing a broken run still leaves behind.
* The user sees a crash, not a message.

## What Stage 14 must therefore do

1. **Never emit a `pss` card with fewer than five arguments** — not as a default, not when
   an optional field is blank, not when a state file round-trips with a key missing. The
   emitter fills every one of the five, and a test row proves the shortest possible emission
   is five, by counting words in the rendered deck rather than by reading the code.
2. The *"explicitly experimental"* wording ⚖ R7 ruled for is **not** the guard. A sentence
   warns; it does not stop a `.state` file written by an older ASE-L, or a hand-edited one,
   from reaching the simulator four words short.
3. The precondition class for a PSS row with an unusable field is **refusal**, on the same
   ground as `sp`: what it costs is not this analysis but the run.

⚠ And a note on attribution, because the first pass of this measurement got it wrong: the
initial probe ran `help pss`, `pss` and `edisplay` in one deck, saw rc 139, and the obvious
reading was *"`pss` is broken in this build"*. It is not. `help pss` and `edisplay` are fine,
and `pss` itself is fine with five arguments or more. **The defect is input validation on a
short argument list**, which is a different sentence with different consequences — and it
took isolating one command per deck to say it. Same discipline as issue 1438's correction:
establish which call site actually executes before building the explanation on it.
