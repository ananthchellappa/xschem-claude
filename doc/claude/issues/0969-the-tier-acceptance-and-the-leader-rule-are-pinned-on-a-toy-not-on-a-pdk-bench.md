# 0969 — the value acceptance and the leader rule are pinned on a toy, not on a PDK bench and not on a run

**FILED, NOT FIXED — a coverage gap, not a behaviour defect.** Both properties
were checked by hand during item S4's verification and both HOLD today; nothing
committed watches either of them. Found by S4's verification pass. Status:
**OPEN**. Sibling in kind of issue **0962**.

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
