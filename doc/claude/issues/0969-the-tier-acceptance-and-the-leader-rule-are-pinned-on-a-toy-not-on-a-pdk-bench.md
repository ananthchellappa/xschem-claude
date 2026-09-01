# 0969 — the value acceptance and the leader rule are pinned on a toy, not on a PDK bench and not on a run

**FIXED 2026-08-30** (the S4a repair pass): both gaps are now pinned on the PDK
bench, with a real run, in section **X** of the suite. Filed as a coverage gap,
not a behaviour defect — both properties were checked by hand during item S4's
verification and both held. Sibling in kind of issue **0962**.

Design of record: `doc/claude/specs/op_annotation.md` §4.3b.
Suite: `tests/headless/test_ase_optier_0963.tcl`.

## Gap 1 — the acceptance runs on a hand-written level-1 transistor

The S4 item's acceptance is explicit about the bench:

> on a real bench with devices inside PDK model subcircuits, the values
> annotated onto the schematic through tier B must MATCH the values annotated
> through tier C … the same numbers, per device, per parameter, compared.

Rows **ACC1** (from the results files) and **ACC2** (through the tree's own
reader, i.e. the numbers that would be painted on the schematic) do compare
per device and per parameter, and they do it correctly — one simulator run, one
operating point, two spellings, which is the only way the comparison is
decisive (see §4.3b: two separate runs disagree by a median of 1.7 % on this
bench and swamp the answer). But the circuit they run on, `RNL`, is:

    .model zmod nmos level=1 vto=0.7 kp=100u
    .subckt zinner d g s b
    M1 d g s b zmod w=10u l=1u
    .ends

one transistor, one plain subcircuit, five parameters. Sections B, M and R use
the same one. **No committed row compares the two forms on a device inside a
PDK model subcircuit**, which is where the device name is
`@m.x1.x1.xm4.msky130_fd_pr__pfet_01v8` rather than `@m.xi1.m1` — the shape
`ase::op_cards_devices` has to split at the `[`, and the shape the descriptor's
wrapped/typed spellings are built for.

**Measured by hand, and it passes**, on `sky130_tests_ase/tb_bandgap`, one
ngspice invocation, one `op`, two `write` lines:

    device-parameter pairs compared: 456
    bit-identical mismatches:          0
    present in one form, absent from the other: 0

and, with all 78 names on the write line rather than the 76 resolvable ones,
form b writes no file at all — which is issue **0965**, and which means the
item's acceptance **as worded is unsatisfiable on that bench**. That is worth a
row of its own: a regression in how hierarchical names are split or spelled
would show up as blank rows and nothing would catch it.

## Gap 2 — the leader rule is a grep, and its measured hazard was a run

The plan's row was two-armed: the deck still carries its save-everything leader
above `.control`, **and** a real run's transient plot still carries every node
voltage. Only the first arm shipped. Row **G-LEADER** counts deck-level
`.save all` and `.save v(out)` lines and stops there.

The hazard it stands for was measured on a **run**: with the leader moved into
`.control` alongside the device requests, a bench with per-output `.save <expr>`
lines lost every other node voltage from its transient — **the plot fell from 6
vectors to 2**, `time` and the one named output, silently. The grep does catch
the sabotage that causes that (SAB-LEADER reds G-LEADER and nothing else), so
the guard is not blind; but the number that makes it alarming is never re-taken,
and a different way of losing those vectors would not be seen at all.

**Checked by hand and it holds**: on `tb_bandgap`, whose netlist carries 40+
per-node `.save` lines, the transient plot holds 424 vectors with the
device-numbers tick on and 424 with it off.

The suite already runs real ngspice in sections B, M, R and ACC, so the second
arm is cheap: render an op+tran deck with two saved outputs, run it, and assert
the Transient Analysis plot's vector list still names both.

## Checked, and NOT a gap — recorded so nobody re-derives it

The S4 plan predicted that row **H1** of `tests/headless/test_ase_simcaps_0948.tcl`
"asserts THE DECK DID NOT MOVE and will redden by design", and asked for it to
be rewritten. It did not redden and it did not need rewriting: H1's own fixture
state never primes a captured card block, so the tier switch takes the
no-cards path and the deck it renders is byte-identical to what it always was.
Nothing was lost by leaving it alone — the analysis reorder is held by
`test_ase_optier_0963` rows E9, R1 and R2, by `test_ase_core` D6 and by
`test_ase_final` F21, all five of which redden under SAB-REORDER. What is true
is the narrower statement: **nothing in `test_ase_simcaps_0948` sees the
reorder**, and nothing needs to.


## HOW IT WAS FIXED — section X, on the bench, with a real ngspice

`tests/headless/test_ase_optier_0963.tcl` gained section **X**, which opens
`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap` the way the product opens it —
its own committed state, its own library defs — and runs it four times. It is
gated on `auto_execok ngspice` and on the bench being present, exactly as
sections B/M/R/ACC are, and it skips loudly rather than silently.

⚠ **THE TRANSIENT IS SHORTENED, AND ONLY THE TRANSIENT.** The committed bench
asks for `tran 10n 200u` — 20,505 points, about 16 s. Every row in the section
is about the SHAPE of the deck and the SPELLING of what comes back, and neither
depends on how long the transient runs. With `tran 1u 2u` a whole
netlist + run + read cycle is about 3.3 s, so the four runs add roughly 14 s.
That is a state edit, not a bench edit: nothing under `sky130A/` is written.

* **Gap 1 → rows X1 and X2.** X1 asserts that on the bench every one of the 468
  requests comes back with a number (it was 456, i.e. 12 blank rows, before
  issue 0965 was fixed). X2 forces form b on the same bench and compares all 468
  values device by device and parameter by parameter, through the tree's own
  reader — the numbers that would be painted on the schematic — and prints deck
  bytes and lines, wall clock and results-file bytes for both forms. Measured:

      form c   deck 35,255 B / 329 lines   wall 3,296 ms   raw   284,283 B
      form b   deck 17,641 B / 328 lines   wall 3,420 ms   raw   710,738 B
      differences over all 468 values: NONE

  The item's acceptance was unsatisfiable as worded until 0965 was fixed; it is
  satisfiable now, and X2 is what keeps it so.
* **Row X3** is the measurement guard **G4** stands on, taken on this bench
  rather than on a toy: a device name made unmatchable on purpose costs form b
  the WHOLE operating point and no results file at all, at exit 0, while form c
  keeps every other device — and the run now says so in both cases.
* **Gap 2 → row X4**, as a RUN and not a grep: with the transient enabled, the
  count of transient node-voltage vectors is the same with the device-numbers
  tick on as with it off (measured: 424 either way), and no device number rides
  the transient at all.
* **Row X5** measures the tier the bench really lands on with this box's own
  ngspice and no priming: `c unsafe`. G4 fires on the bench, not only on a
  primed capability.
* **Row X6** is the section's discipline: no device or card count is typed into
  it; every count comes from the walk. **Row N5** is the same discipline for
  section N, whose whole 78-name finding is reproduced from committed files with
  no simulator at all, in about two seconds, by walking each emitted name
  through the deck's own call graph via `op_annot::_deck_index`.
