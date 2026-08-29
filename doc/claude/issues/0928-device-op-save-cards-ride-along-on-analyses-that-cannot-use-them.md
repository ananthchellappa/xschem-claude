# 0928 — device OP save cards rode along on analyses that cannot use them

**Status:** **FIXED 2026-08-29.** Found by measuring the user's challenge to
0927, the same day. **This was a live regression introduced by 0927**: harmless
while the gate defaulted off, a tax on every transient run the moment it
defaulted on.

**Related:** 0927 (the default flip), 0617/0620 (the feature and its deck cost),
0635 (the contradiction a bare return would have reproduced)

---

## 1. The user's challenge

> *"that's BS - you're telling me we have to have a .save card per every device
> existing in the design to get this?"*
> *"ngspice doesn't have a way to be told 'save all OP device info'?"*

Fair, and measuring it found a real defect — though not the one either of us
expected. See §4 for what ngspice actually offers; the defect is §2.

## 2. The defect

`ase::op_cards_capture` and `ase::render_deck` both gated the device
operating-point `.save` block on **one** condition: `save_op_params`. Neither
asked whether an **operating-point analysis was even enabled**.

`ase::op_analysis_enabled` existed and had **exactly one caller** — the
*gate-off nudge*, which is the message shown when the feature is **off**. So the
predicate that knows whether these cards can ever be read was consulted only on
the path where no cards are emitted.

Consequence: a **transient-only bench** collected one `.save` card per device
per parameter for numbers nothing in this tree reads. `6` annotates an operating
point; `Alt+Shift+6` reads node voltages out of the raw and never a device
parameter.

## 3. Why it matters, in numbers rather than adjectives

**A deck-level `.save` is sampled at every timepoint of every analysis in the
deck.** Measured on generated decks, 500 MOSFETs × 6 parameters = 3000 cards:

| analysis | Δ wall clock | Δ raw size | verdict |
|---|---|---|---|
| `.op` (1 point) | **+0.03 s** | **+107 KB** | free |
| `.tran`, 10068 points | **+8.6 s** | **+242 MB** (40.7 MB → 282.4 MB, 6.94×) | not free |

Cost is ~8.0 bytes and ~285 ns per (device × parameter × timepoint) — a pure
multiplier on saved timepoints, not a property of the cards. Peak RSS is flat
(~17 MB, 1.02×) because ngspice streams the raw to disk, and it is **not** disk
I/O: routing output to `/dev/null` leaves it just as slow, so the expense is
in-process per-timepoint parameter evaluation.

**So the user's instinct was right and the diagnosis was one level off.** Per
device per parameter is not the problem — under an `.op`, which is what the
feature is for, 3000 cards are free. The problem is those cards riding an
analysis that cannot use them.

## 4. What ngspice actually offers instead — measured, and why neither is adopted

Four probe agents plus three adversarial verifiers, on ngspice-46+.

**`show` (one command, every device, no cards) — DISQUALIFIED.** It does dump
every operating-point parameter of every device including inside subcircuits,
and `show m : gm gds vth id vgs vds` selects columns. But **the device-name
column is truncated to exactly 21 characters**, and `set width=200` does not
widen it. Two devices sharing a >21-char hierarchical prefix produce byte-
identical column headers and cannot be mapped back to devices. Column order is
also reversed relative to netlist order. Measured on
`m.xtop_level_analog_bank.xfirst_stage_device.mdev` vs `…xsecond_stage_device…`.

**`write out.raw all @m1 @m2` (one token per DEVICE, all ~89 params each) —
REJECTED, silently wrong off the `.op` path.** This is real and better than it
looks: it makes the deck O(devices) rather than O(devices × params), writes a
standard binary raw with correctly-named untruncated hierarchical vectors, works
on BSIM4/sky130 at three levels of nesting, and **xschem's existing raw reader
consumes it with zero changes** (`read_dataset()` in `src/save.c` — the header
parse stops at the tab before the type column, so the `notype` typing is inert).
The `set d1 = m1` / `@$d1[x]` ceremony the first probe believed was required is
**not** required; a bare `@m1` works identically, byte for byte.

It is rejected because the **scope verifier refuted it**: in `.tran` (208
points) and `.dc` (11 points) every device-parameter vector is emitted with
`dims=1` inside a multi-point plot — **exactly one sample nonzero, 207 zeros, and
the nonzero one is the END-OF-RUN value parked at index 0**. Measured identity:
the expansion's `gm[0]` equals the explicit-`.save` reference's `gm[207]`, while
the true `gm[0]` differs. No warning, no error, a well-formed raw; a viewer
plots a spike at t=0 and a flat zero line. The explicit-`.save` path on a
byte-identical deck gives genuinely time-varying values at all 208 points, so
this is a defect of the write-expansion path, not an ngspice limit. Also 5/6
params on level-1 MOS (`vth` does not exist there) though 6/6 on BSIM4.

**`.options savecurrents` / `.probe`** give terminal currents only — no gm, gds
or vth. **`.save all`** gives node voltages and voltage-source branch currents
and no `@m…` vector of any kind. Deck-level wildcards (`.save @m1[all]`,
`.save @m1[*]`) are a **trap**: they do not error, they silently create one
bogus zero-valued vector named after the literal text **and suppress every other
vector in the raw**.

**Conclusion.** Per-device-per-parameter cards remain the only form that is
correct across analyses. Since they are free under `.op`, the fix is to stop
emitting them anywhere else.

## 5. The fix

`ase::op_analysis_enabled` is now consulted on **both** halves:

* **`ase::op_cards_capture`** — skips when no `op` analysis is enabled. This is
  what saves the `op_annot::save_cards` hierarchy walk (measured 348 ms for 78
  flattened FETs on `sky130_tests_ase/tb_bandgap`).
* **`ase::render_deck`** — the same condition on the append. Not redundant: the
  cache outlives one netlist (`ase::run_existing` renders from a block an
  earlier netlist primed), so a user who turns `op` off and re-runs would
  otherwise still get the cards.

The capture records an **empty cache HIT** rather than returning bare. A bare
return is a cache MISS, and render_deck's stale-artifact arm would then tell the
user to re-netlist an artifact this session had just written — issue 0635's
contradiction, exactly.

## 6. Acceptance

`tests/headless/test_ase_core.tcl`:

* **C5b** — gate ON, no `op` analysis: zero device cards in the deck. Fourth
  term is the non-vacuity control — the same state with `op` re-enabled emits
  the three cards — so a sabotage that simply stops emitting cannot pass.
* **C5b2** — the capture half, which C5b cannot see because it drives
  `render_deck` over a hand-primed cache: `op_annot::save_cards` is **never
  called**, a cache **HIT** is still left (the 0635 guard), and **nothing is
  echoed**.

Suites after the change: `test_ase_core` ALL PASS (180), `test_ase_final` (79),
`test_ase_window` (227), `test_ase_dialogs` (174), `test_ase_persist` (109),
`test_ase_final_gf180` (34), `test_ase_view` (36),
`test_annot_blank_cause_0909` (27).

## 7. Not done

The `op_annot::save_cards` walk still runs for the whole hierarchy below the
entry cell rather than for the sheet the user is looking at. That is a separate
question and nobody has ruled on it.
