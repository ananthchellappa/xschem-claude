# 0460 — the "no OP descriptor" clause names decorations, and relabels an unresolved symbol

Status: **PART 1 FIXED 2026-08-28** (issue 0909's repair, `cadence::_annot_skip_types`).
**PART 2 STILL OPEN** — an unresolved symbol is now skipped rather than
mislabelled, but it is still not reported in its own words.

⚠ WHY IT SAT FOR NINE DAYS AND THEN SUDDENLY MATTERED: until issue 0909 the
descriptor clause only reached the user when NOTHING on the sheet could be
annotated, which is a state a real design does not reach, so the whole list was
effectively invisible. 0909 deleted that gate for a good reason — a mixed sheet
was saying nothing about the block that never appeared — and every entry in this
issue became live on every press, as a WARNING, on completely successful
annotations. `logo` and `subcircuit` were being named on the user's own
tb_bandgap_opamp.

WHAT WAS ADDED: `logo probe ammeter subcircuit vsource isource missing`.
WHAT WAS DELIBERATELY NOT ADDED, against this issue's own suggestion:
`resistor`, `capacitor`, `inductor` and the code/title text symbols. A passive
device type is exactly what a design kit might describe next, so its absence
from the descriptor registry is the issue-0906 news the clause exists to carry.
`capacitor` is still named on tb_bandgap_opamp, and it should be. That
divergence is this crew's judgement and is recorded in the owed rule under 0909.
Row BC20 of tests/headless/test_annot_blank_cause_0909.tcl asserts both halves
by name -- the skipped list and, negatively, eleven device types that must
never join it.

Originally filed as:

Status: OPEN (measured by S8's adversary pass, not fixed)
Found: S8 of doc/claude/specs/op_annotation.md. Subject: `cadence::_annot_skip_types`,
`utils/annot_mode.tcl:109`.

S8 requirement 4 says the second first-run confusion — *nothing on this sheet has
an annotation descriptor* — must be said out loud. It is. But the skip list
under-covers what shipped schematics actually contain, so the clause names
things no user would ever expect an operating point from. Measured against the
REAL registries (adversary pass, per-PDK rc sourced under DISPLAY=:99):

    sky130A  mips_cpu tb.sch  -> no OP descriptor for symbol type(s):
                                 logo missing verilog_preprocessor
    sky130A  top.sch          -> logo missing
    sky130A  alu.sch          -> logo
    gf180    test_cap_mim_1f5fF (real library.defs, symbols resolving)
                              -> logo moscap resistor vsource
    hierarchical fixture top  -> subcircuit

Two distinct defects in one line:

1. **Noise.** `logo` is the XSCHEM logo decoration; `vsource`, `resistor`,
   `moscap`, `subcircuit` are legitimate parts nobody annotates with FET
   operating-point rows. The clause should stay silent about them. Suggested
   additions to `_annot_skip_types`: `logo subcircuit vsource isource resistor
   capacitor inductor code code_shown title probe`.

2. **A DIFFERENT ERROR RELABELLED.** `missing` is xschem's marker for a symbol
   it could not resolve at all — a broken library path, not a missing
   descriptor. Reporting it as "no OP descriptor for symbol type(s): missing"
   sends the user to write a descriptor for a problem that is a library
   reference. It should be reported as its own condition, e.g.
   `-- N symbol(s) could not be resolved (missing)`.

Not fixed in S8 because both are wording/coverage changes to a list that S10
(PDK symbol tagging) will revisit with the full type inventory in hand, and
because the rows that cover this clause (N14/N15) use a bespoke `zzs8probe`
type and would not have caught it — extending the list without extending the
fixtures would just move the blind spot.

## Still open

Whether the skip list is the right mechanism at all, or whether the clause
should be driven positively (name only types that have a `spiceprefix` and a
device path shape) rather than by exclusion.
