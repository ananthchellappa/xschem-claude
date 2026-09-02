# 1238 — stock `proc simulate` lost its exe/casemode composer at the annotate merge

**Status:** OPEN. Filed 2026-09-01, at the `annotate` → `fluid-editing` merge.
Deliberate, declared, and on the owed ledger as a `look` — the user has not yet
ruled on whether to re-teach it or accept the loss.

## What was lost

Issue **0506** taught `proc simulate` (`src/xschem.tcl`) — **stock xschem's own
Simulation menu, the button most users press** — to compose its command from the
simulator profile, via `sim_profile_compose_cmd`. Before that, it ran
`sim($tool,$def,cmd)` verbatim, so a user could register a case-capable ngspice,
set Case=preserve, press Test, read *"delivers fold preserve distinguish"*, press
Simulate, and get a different binary at `fold`.

At the merge the profile store was retired in favour of `annotate`'s simulator
registry (the user's ruling: two stores describing one machine can disagree with
themselves). `proc simulate` knows nothing about ASE-L, so the bridge went with
the store it read. **`simulate` runs the row's `cmd` verbatim again, as on
`main`.** The 0506 defect above is reachable once more.

**ASE-L's own run path lost nothing.** `ase::run_cmd` composes exe, args, `-n`
and `-D casemode=` from the registry entry, and `ase::run_precheck` still refuses
a `distinguish` request the binary cannot deliver.

## Why it was not just re-pointed in the merge

Three real questions, none of which a merge should answer by itself:

1. **Shape mismatch.** `sim()` is per-TOOL with N rows and a default radio; the
   registry is one in-force entry. Which registry entry composes a `vhdl` row?
2. **Stock xschem must still run** with `ase.tcl` sourced, nothing registered and
   no session anywhere — so the composer needs a "no answer" path that behaves
   exactly as today, which is most of the compatibility contract 0506 carried.
3. **The unplaceable-flags problem is unchanged and was the hard part.** Two
   shipped templates cannot take appended flags at all: row 0's first word is a
   VARIABLE (`{$terminal -e {ngspice -i "$N" -a || sh}}`) and row 4's is a
   wrapper (`mpirun`). 0506's first revision appended anyway and produced
   `xterm -e {ngspice ...} -D casemode=preserve` — flags for the TERMINAL, two
   levels out from the simulator.

## The tests that went with it

`tests/headless/test_sim_plain_run.tcl` kept its C-netlister half (CS218–CS221a,
re-pointed at the registry) and **retired CS200–CS217 plus CS221's simulate
half — eighteen checks, not migrated anywhere**. They are recoverable verbatim:

```sh
git show <merge commit>^:tests/headless/test_sim_plain_run.tcl
```

When the composer returns, so do they.

## The options

1. **Re-teach `simulate` to read the registry.** Ask `ase::sim_status ngspice`
   for the spice tool only, keep every other netlist type verbatim, and re-use
   0506's exe-plan (`sim_profile_cmd_exe_plan`, also recoverable from the merge
   parent) for the declined/unplaceable rules.
2. **Accept the loss** and say so in the docs: ASE-L is where a configured
   simulator runs, and stock Simulate is the "run exactly what I typed" path.
   This has a real argument behind it — 0506 was making the stock button do
   something the string in the box did not say.
3. **Delete the stock path's ambiguity instead**: make Simulate refuse when a
   simulator is registered whose exe differs from the row's first word, pointing
   at ASE-L. Loudest, smallest, and does not re-open the unplaceable question.

Not decidable from the code; it is a product call.
