# 0496 — the sch_path-keyed deck index cannot see parameter-specialised subcircuits

STATUS: **FIXED BY S3 (2026-08-22).** **Addressed by S3 (attempt 5), landed 2026-08-22** — see the *S3 LANDED* section of `doc/claude/suggestions/next_session_prompt_op_annotation.md`. The deck index is re-keyed on the **`.subckt` NAME**, and the instance→block edge is read off the instance's own deck **element line** (the last token before the first token containing `=`, after joining `+` continuations); `_here_block` and per-instance `_normkey` are deleted and the walk threads the callee block down the recursion. The name key is paid for by `_block_is_here`, which compares the callee block's `** sch_path:` against `xschem get schname` after every descend. **⚠ Re-keying alone was necessary and NOT sufficient**: the specialisation rides on an instance attribute `schematic=passgate_1` that `get_sch_from_sym` resolves to a nonexistent path, and the base-schematic fallback (`actions.c:4176`) is gated by `has_x && fallback` while the `xschem descend` verb passes `fallback=0` — so `hi_descend_view_path` (`actions.c:4139`) has to be fed from the callee block's own `** sch_path:` to get past the class-2 refusal. Measured on the bench that refuted attempt 4 (`sky130_tests_ase/tb_bandgap_opamp`, row **W30**): **31 distinct card devices == the deck's 31 FET leaves, both directions**, 12 cards under `@m.x6.` and 12 under `@m.x3.x6.`, counts `{0 0 0}`, no *"normal for such cells"* anywhere. The sabotage variant `index_keyed_on_sch_path` reddens W30 and degrades it to 19 devices.

Original filing follows.

STATUS: **OPEN.** Measured on branch `annotate`, step S3d, 2026-08-21, at
`d56283ec`. Refuted attempt 4's central claim; see 0494.
Related: 0494, 0442 (the drop-class predecessor), 0497 (the misreporting).

---

## The claim

Attempt 4's oracle indexes the netlister's own deck by its `** sch_path:`
comment lines and answers *"may I emit a card for this instance"* and *"may I
walk into it"* by lookup. Decision **D3** chose that key over the cell name and
over `** sym_path:`, and its rationale considered `schematic=` polymorphism —
but not **parameter specialisation**.

## The measurement

`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap_opamp`:

```
CARDS=114  DISTINCT-DEVICES=19
deck MOS element count = 39
WARNINGS: {2 subcircuit instance(s) got no cards because the netlist does not
expand them here (spice_stop, spice_sym_def, an ignored or behavioural cell, or
an empty block) - normal for such cells}
```

The deck the oracle itself just wrote:

```
 31:** sch_path: .../sky130_tests/passgate/schematic/passgate.sch
 32:.subckt passgate   Z A GP GN VCCBPIN VSSBPIN  W_N=1 L_N=0.2 W_P=1 L_P=0.2
135:** sch_path: .../sky130_tests/gain_stage/schematic/gain_stage.sch
136:.subckt gain_stage IN OUT VCC VSS START_N START EN_N  wcap=10 WN=0.5 WP=1
175:** sch_path: .../sky130_tests/passgate/schematic/passgate.sch
176:.subckt passgate_1 Z A GP GN VCCBPIN VSSBPIN  W_N=1 L_N=0.2 W_P=1 L_P=0.2
195:** sch_path: .../sky130_tests/gain_stage/schematic/gain_stage.sch
196:.subckt gain_stage2 IN OUT VCC VSS START_N START EN_N  wcap=10 WN=0.5 WP=1
```

**Two distinct `.subckt` blocks share one key.** `passgate` and `passgate_1` are
the same schematic netlisted twice with different parameters, synthesised by
`get_additional_symbols`.

## The two consequences

1. **Under-emission (measured).** `xschem get_sch_from_sym` answers the
   *synthesised* name `passgate_1` / `gain_stage2`, which is not a key of the
   index, so `_descendable` is 0 and the whole subtree emits nothing — 12 of the
   deck's 39 MOS elements (`x3.xm1/5/6/7/8/9/10/46`, `x3.x6.xm1/xm2`,
   `x6.xm1/xm2`) get no card. Those FETs render **blank** on an ordinary bench
   run, which is the exact symptom S3 exists to remove.
2. **A latent over-emission, which is the raw-destroying direction.** The two
   blocks merge under one key (measured: `passgate.sch -> xm1 xm2 xm1 xm2`).
   Benign *today* only because `skip_instance` (`netlist.c:1235-1259`) is
   flag-based, so both specialisations always carry identical element names. Any
   future parameter-driven drop rule turns this into cards for devices that are
   in no block — and per rule R5 a fully-bogus block writes **no raw at all**.

## Why the user is told it is fine

The only signal is the aggregate warning above, ending **"- normal for such
cells"**. For a `spice_stop` or behavioural cell that text is true. For a
parameter specialisation it is false: the netlister expanded the cell, wrote its
block, and the walk simply could not find it. See 0497.

## What attempt 5 must do

The index key has to survive specialisation. Candidates, unmeasured:

* Key on `** sch_path:` but store a **list** of blocks per key, and disambiguate
  the instance → block edge by the `.subckt` name taken from the instance's own
  deck element line (which names `passgate_1` directly).
* Ask the C for the effective netlist cell of an instance rather than inferring
  it from `get_sch_from_sym`.

Whichever is chosen needs a fixture with a parameter-specialised subcircuit —
none of the seven drop classes exercises one, which is why 275 checks were green.

## Still open

* Does any other `get_additional_symbols` path (polymorphic `schematic=`,
  `spice_sym_def` variants) produce the same key collision? Only parameter
  specialisation was measured.
* An attempt to turn the merge into an observable over-emission by giving the
  ignored instance `schematic=w_ok` failed: that routes through the polymorphic
  path, which drops `default_schematic=ignore` and changes the netlister's own
  answer. The over-emission direction therefore remains **argued, not measured**.
