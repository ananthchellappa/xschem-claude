# Backlog batch 2026-11-12 — PLAN

User's words, 2026-11-12: "Use batch mode to handoff tasks to subagent crews to work on 1, 3, 4
and then 2 in that order". The four items were offered by the driver the same day; the stage
order below is the user's.

Each stage: an implementer crew (one task) -> receipt -> a verifier crew (adversarial) -> the
driver's T1 gate (private Xvfb, never :99 while the xschem-private session may hold it) ->
the driver's commit -> the ledger. Crews never commit.

## Stage A — item 1: the random seed steps aside for a bench that seeds itself

Background: 1668e5fb4 (`ase::run_seed_state`, src/ase.tcl; suite
tests/headless/test_ase_run_seed.tcl) adds `.options seed=<default>` to a plain run that has
no seed of its own, so a `tt_mm` bench is repeatable (FAQ Q93; the user's ruling: "tt_mm should
give same result each time"). It only looks at the bench's options ROWS. A bench can also seed
itself in TEXT it owns: the netlist (a `.options seed=` / `.option seed` card in the circuit),
or its own simulator-command / control text (`set rndseed=`, `setseed`, a `.control` block the
user wrote). Then ASE-L's line may be redundant or may win over the user's, depending on order;
ngspice behaviour on two seed lines is the thing to MEASURE, not assume.

The private session (assembler branch) fixed the same gap as 7843e17e7 "fix(ase): the default
seed steps aside for a bench that seeds itself". It may be READ for its seed logic only:
`git -C ~/private/xschem-private show 7843e17e7`. Never fetch, merge or cherry-pick private
history into this repo (its origin is public GitHub), never write in ~/private, and port NOTHING
but the seed logic — no other assembler feature, no "premium" feature (the user: "ASE-L only.
Nothing to do with ASE-Integrator. That's a premium feature").

Deliver: measure whether the gap is real on fluid-editing (a deck with the bench's own seed in
netlist text and in its own control text; which seed governs, with and without ASE-L's line);
if real, fix it so a bench that seeds itself anywhere it owns is left alone; rows in
test_ase_run_seed proving it, each red without the fix.

## Stage B — item 3: a T1 gate never waits for :99

Two Claude sessions on this machine share the persistent dev display :99; today each had to ask
the other to keep off it while a T1 ran there. The workaround that worked:
`XSCHEM_DEVDISPLAY_DIR=<a dir that does not exist> tclsh run_regression.tcl` makes T1 start its
own private Xvfb from :100 (see run_regression.tcl's display-arm selection, `t1_private_xvfb`).
Two costs: (a) it is a trick nobody would find; (b) THREE rows then skip because they ask
`devdisplay.sh status` rather than "is there a display with a WM": D1-D4 (draw.c cursor
readouts + callback.c measurement tooltip), N2 (draw_temp_symbol hide-symbols), V26
(headless-vs-display colour comparison). Find their suites with
`/usr/bin/grep -ln 'persistent dev display alive' tests/headless/*.tcl`.

Deliver: (1) T1 does not attach to :99 when another live T1 or suite run is using it — it goes
private instead, saying so in its output — and a documented knob forces either choice;
(2) the three rows run on whatever display arm T1 gave them, so a private-display gate skips
exactly what a :99 gate skips; (3) a fence for both; CLAUDE.md's Tests section updated in the
same commit (one short bullet, not an essay).

## Stage C — item 4: more device limits

8a0a72b56 added `devlim` (src/property_form.tcl: register / spec / clamp_edit; providers
sky130_fet_limits, sg13g2_fet_limits, gf180_fet_limits in the three workareas' procs files;
hook devlim_clamp in src/editprop.c apply_symbol_prop; suite test_device_limits). Extend:
(1) resistor and capacitor geometry in all three PDKs, where the PDK data in this repo
(symbols' templates, the PDK checker procs, model files' ranges) gives a limit;
(2) edits made by script: `xschem setprop instance <i> <tok> <val>` goes through the same clamp;
(3) gf180 `_dss` devices: find their rule IN THIS REPO's data (models/sm141064.ngspice bins,
symbol defaults); if the repo cannot settle it, leave them unclamped and record a ruling
(`owed.sh add rule`) rather than guess. Every limit cites where it came from in a comment.

## Stage D — item 2: checks that silently never run

8a0a72b56 found drc_check() gated on `info procs fet_drc`, a name nothing in the tree defines,
so every PDK drc= check was dead with no symptom. Audit the tree (src/*.c, src/*.tcl, the
workarea rc/procs files) for the same shape: a feature gated on a proc, command, variable or
file that nothing defines/creates, so it never runs and never says so. For each finding:
show it is dead (a measurement, not a reading), then fix it (wire the real name) or delete the
dead branch, with a row that is red on the dead version. Report the search method and its
blind spots.

## Stage E — follow-up: run_suites.sh and full_audit.sh step aside too

User's words, 2026-11-12: "proceed with that fix as well" — after the xschem-private session
reported that stage B (c24560855) covers T1 only, and `tests/headless/run_suites.sh` and
`full_audit.sh` (through `xvfb_arm.sh`) still attach the dev display :99 whatever else is on it.

Deliver: the same rule as T1's `auto` for those launchers — attach :99 only when no other live
user holds it (same /proc-identity detection as `t1_dev_display_users`, ONE implementation
shared or provably equivalent, never a second hand-kept copy that can drift), otherwise a private
Xvfb, saying so; a documented knob forcing either choice (reuse `T1_DISPLAY`'s vocabulary);
`AUDIT_DISPLAY` keeps its meaning and wins. A fence, red first. CLAUDE.md's display-arm and
persistent-dev-display sections updated in the same commit, one short bullet each (the sentence
"no knob goes private while :99 is up" under issue 1488 must become true or be removed).
