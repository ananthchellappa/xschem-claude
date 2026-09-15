# 1472 — Two co-simulation installation defects were measured, characterised, and said to nobody

**Status:** FIXED pending the driver — Stage 16 task 3 of the ASE-L analyses batch
(`doc/claude/ase_analyses_batch/PLAN.md` §16c), receipt
`doc/claude/ase_analyses_batch/receipts/48-stage-16-cosim.md`. Filed 2026-09-15 by the Stage 16
task 3 crew at the moment the work needed a number (1472 checked free in every clone under
`~/dev/*` and outside every reserved band; `NUMBERING.md` pointer → 1473).

## What the user meets

Issue 1470 shipped `ase::backend::ngspice::scripts_dir_of` (the parse rule) and
`cosim_shim_verdict` (the two installation greps) of PLAN §16c — **and nothing called them.** That
is 1470's own correction **C6**, restated in receipt 47's *What binds later work* 7. So both
defects stayed exactly as invisible as they had been before anyone characterised them:

1. **A `vlnggen` that does not link the VCD runtime.** Verilator writes `verilated_vcd_c.o` beside
   the other globals rather than into `Vlng__ALL.a`, so a **`--trace` build fails its FINAL LINK
   with unresolved symbols**. It happens in the user's own build step, outside ASE-L, and arrives
   as *"my wrapper won't link"* with nothing naming the cause. *TRANSCRIBED* from
   `evidence/fork-dependencies.md` §5 B4.1; the fork's fix is commit `e47a2abc8`.
2. **A `verilator_shim.cpp` whose model holds a non-owning pointer to a destroyed
   `VerilatedContext`.** `Cosim_setup()`'s `const std::unique_ptr` destroys the context on return
   while `Vlng` keeps using it: **use-after-free for the whole simulation.** It may never crash,
   which is why it must be said out loud — a run that "worked" is not evidence the memory was
   valid. *TRANSCRIBED* from the same file, B4.2; the fork's fix is commit `c2722d89b`.

And a third thing, which is why neither could be said even if somebody had called the checks:

3. **No probe leg collected `$sourcepath`, so nothing knew which installed tree to read.** A
   hardcoded `/usr/share` would answer "stock" for every fork a user registers (M19's finding).

## What was actually wrong with the measurement — and it was not what the tree said

The capability vocabulary's own comment recorded that `$sourcepath` *"came back EMPTY from inside
the probe deck"*. Issue 1470 re-measured and found it did not reproduce (its correction **C5**),
but left the key unwired. **Both readings were incomplete.** *MEASURED HERE* 2026-09-15, the
shipped deck D run by hand on apt 45.2 and on the fork, one run, both markers:

```
@@gref=M7 my 0 rail                                            <- bare
"@@sourcepath=. /usr/share/ngspice/scripts /usr/share/ngspice/scripts ."   <- wholly quoted
```

ngspice's `echo` **re-quotes an argument expanded from a LIST variable** (`sourcepath` is
`cptype list`), so the quote lands in front of the `@@` and `cap_d_field`'s position-0 test never
matches. The payload had been arriving intact the whole time, in a shape no reader could find —
which is indistinguishable from empty at every call site. Stripping quotes per *element* in
`scripts_dir_of`, which 1470 shipped, does not reach it.

⚠ **The same quoting hid a second, latent defect.** A quoted marker line does not begin with `@@`,
so it survived `cap_d_identity`'s marker skip and was offered to the version and date tests: a
program installed under, say, `/opt/ngspice-46.2/share` would have had its Band 1 `version_line`
**fabricated from a folder name**. The three preflight binaries happen not to reproduce it (no
`ngspice-` and no four consecutive digits in either installed path). Row SD4 no longer depends on
that luck.

## The fix

* **The fact.** `scripts_dir` is a **Band 1 identity key** (`ase::caps_keys`), published by leg D
  from one more `echo` line in a deck that was already running — **no new process**. *MEASURED
  HERE*, three cold probes per binary, before → after: apt 45.2 `536 427 424` → `544 429 429` ms,
  the fork `456 452 451` → `459 452 450` ms. Display and log only; nothing gates on it. A
  `$sourcepath` naming no absolute `scripts` directory leaves the key **absent**, which every
  reader takes as *not measured* rather than as a claim about the user's installation.
* **The reader.** `ase::backend::ngspice::cap_d_unquote` removes one pair of whole-line double
  quotes before the marker test, in both `cap_d_field` and `cap_d_identity`'s skip. Removing a
  quote that is not there is a no-op, so every bare marker reads as before.
* **The say-site.** `ase::cosim_scripts_dir` (the free peek), `ase::cosim_shim_notes` (the
  adapter's failed checks, validated), `ase::cosim_shim_say` (once per installed directory per
  session) and `ase::cosim_shim_report` (the run's door), called from `ase::run_deck`'s
  co-simulation block **above `ase::cosim_build`** — a failed `--trace` link raises out of
  `run_deck`, so a warning placed after the build would never reach the user who needs it.
* **The words.** The frame is `ase::sim_why cosim_install` (R9-722); the clauses and remedies are
  1470's own **R9-713 … R9-716**, re-used verbatim and now said for the first time, with the
  fork's own change carried as `patch`.

Suite: `tests/headless/test_ase_variant_1470.tcl`, sections **SD** (8) and **CD** (11), floor
raised **57 → 76**. One row moved, with a paragraph naming this issue: `test_ase_simcaps_0948`
**V8** (the identity band gained the key).

## Rulings this leaves with the user (`owed.sh add rule 1472`)

The two new strings (⚖ R9, `R9_COPY_REVIEW.md` section *Issue 1472*, **R9-722** and **R9-723**),
plus four choices made in the recommended shape:

1. **It is said on the run that first asks for Verilog waveforms**, not when the dialog opens and
   not on every run — PLAN §16c's own wording, and the gate is this run's promise of a VCD rather
   than the mere presence of co-simulation.
2. **Once per installed scripts directory per session, keyed on the DIRECTORY and not the
   program** — two entries sharing one tree are told once between them, because it is one file and
   one fix; a different tree is told about as well.
3. **A verdict of `unknown` says nothing at all.** "I could not look" is not a finding about
   somebody's installation.
4. **The sentence names the FILE, not the program.** The executable is blameless; naming it would
   send the user to change the wrong thing.
