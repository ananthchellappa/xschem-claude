# 0446 — a pin expression fabricates `0` when one terminal is GND and the other net is absent from the raw

STATUS: OPEN — measured, not fixed. Filed by the S5 RED agent of the
operating-point annotation run (doc/claude/specs/op_annotation.md).
Pinned by row S17 of tests/headless/test_op_annot.tcl.

## Symptom

A `pinexpr` row of an op_annot descriptor renders the number **0** — a strict
double, indistinguishable on screen from a real measurement — for a device
whose pin voltages are not in the loaded raw at all.

Every other read in the same block blanks correctly. Only the pin expressions
fabricate, and they fabricate exactly when a terminal sits on GND, which is the
common case for a FET source.

## Measured (this tree, HEAD ce07064e, /home/analog/dev/xschem-claude/src/xschem)

Fixture: `s5_top.sch` instantiates `s5_leaf.sym`; `s5_leaf.sch` holds one
sky130 `nfet_01v8` M1 with drain on net `d`, gate on `g`, source and bulk on
`0`. The raw is a hand-written ASCII Operating Point file whose vectors are
named for the TOP of the hierarchy (`@m.x1.xm1.…`, `v(x1.d)`, `v(x1.g)`).

Descend into x1, then load the raw with NO explicit level, so it is taken to
describe THIS level (landmine 4 of the spec):

    xschem get sim_sch_path        -> {}          (was x1.)
    op_annot::devpath M1           -> @m.xm1.msky130_fd_pr__nfet_01v8
    xschem raw value <that>[gm] -1 -> {}          correct: blank
    xschem translate M1 {@#0:spice_get_voltage } -> {- }
    xschem translate M1 {@#1:spice_get_voltage } -> {- }
    xschem translate M1 {@#2:spice_get_voltage } -> {0.0 }
    xschem translate M1 {expr(@#1:spice_get_voltage - @#2:spice_get_voltage )}
                                   -> 0           string is double -strict = 1

## Cause

Two behaviours meeting, neither wrong on its own:

* `token.c:4364` — a net that is absent from the raw expands to the literal
  `-`, while a GND net (`0`) is hardcoded to `0.0` whether or not any raw is
  loaded.
* `token.c:5441` — translate()'s trailing `is_expr()` / `eval_expr()` pass then
  evaluates `expr(- - 0.0 )`, and eval_expr reads the two `-` as unary minus:
  `-(-0.0)` = `0`.

So the missing-data marker is silently consumed as arithmetic. When BOTH
terminals are absent the expression stays `{ -  }` and is correctly rejected by
`string is double -strict` — the fabrication needs exactly one operand to be a
hardcoded GND.

## Why it matters

Invariant I3 of the spec: a missing vector renders BLANK, never 0, never a
fabricated number — precedent save.c RULING D5-1, "a plausible wrong number on
a schematic is worse than none". `vgs = 0` on an annotated FET is precisely
that: it reads as a device with its gate shorted to its source, not as missing
data.

## Why S5 did NOT fix it

S5's Files cell is `src/op_annot.tcl` and the fault is in C
(`token.c`). Worse, no guard available to the Tcl formatter is both cheap and
correct:

* REJECTED — blank every pinexpr row when all `params` rows are blank. Wrong by
  construction: pin voltages need NO save cards (spec §4.2 is explicit that
  this is the point of `pinexpr`), so "no device parameters saved, but the node
  voltages are there" is a legitimate and expected state that this would break.
* REJECTED — have op_annot::text decompose the expression and check each
  `@#N:spice_get_voltage` token itself. That is a second evaluator of the same
  string, which is the I1 drift shape the whole subsystem exists to prevent.

## Fix sketch (for whoever takes it)

Make the missing-net marker something `eval_expr` cannot silently absorb, or
make `translate` refuse to run its `expr()` pass over an expansion that
contained the marker. Either is a C change with its own blast radius across
every `@#N:spice_get_*` consumer, hence a separate issue rather than a rider on
S5.

## Guard in place

`tests/headless/test_op_annot.tcl` splits the claim in two so the halves fail
separately:

* row **S17** asserts that at level 0 the same raw and the same instance give
  the full block, and that one level down every raw READ blanks
  (`op_annot::raw_or_blank` of the shifted name is `{}`);
* row **S17b** asserts the MEASURED block at the shifted level — six blank
  params, two blank derived, and `vgs = 0` / `vds = 0` — with this issue named
  in the row title, so the golden RECORDS the defect rather than blessing it.

When this issue is fixed those two lines become blank and row S17b reds. That
is the intended signal, not a regression: change S_LVLSHIFT's `vgs = 0` /
`vds = 0` to blank rows and close this issue.

## RE-SCOPED by the S5 write-up agent — the reachability is much wider than the title suggests

The Symptom section above is right ("a device whose pin voltages are not in the loaded raw
at all"), but every measurement under "Measured" exercises only the HIERARCHY-LEVEL shift,
and row S17b's title names "the level-shifted block". Anyone triaging this by its title or
by its guard row will read it as a hierarchy corner case. It is not.

**NO HIERARCHY IS REQUIRED. A flat schematic and the wrong .raw is enough.** Re-measured by
the S5 write-up agent on the committed tree, one level, no descend, no level argument —
a sky130 `nfet_01v8` with source and bulk on GND (the ordinary topology) and a perfectly
valid Operating Point raw belonging to an unrelated circuit:

    raw annot -> 0 0 -1                      (the gate OPENS: annot_p = 0)
      @#0 -> '-'
      @#1 -> '-'
      @#2 -> '0.0'
      @#3 -> '0.0'
    vgs -> '0' double=1
    vds -> '0' double=1
    === op_annot::text M1 on a FOREIGN raw, source+bulk on GND ===
    id    =
    gm    =
    gds   =
    vth   =
    vdsat =
    cgg   =
    vgs   = 0
    vds   = 0
    ft    =
    gm/id =

Eight rows blank correctly; two fabricate. The trigger is only "the device's nets are not
in the loaded raw, and at least one terminal is on GND". Ordinary ways to reach it:

* loading last week's .raw, or another testbench's, against the schematic on screen;
* annotating before the simulation that matches this cell has been run;
* any of the level mismatches already described above.

A control measurement in the same session shows the fabrication genuinely needs the GND
terminal: with the source NOT connected to GND, both operands expand to `-`, the
expression stays non-numeric, and all ten rows blank correctly.

**This raises the priority.** It is not a corner; it is the first thing a user will do
wrong, and the result is `vgs = 0` / `vds = 0` painted on a FET — which reads as a real
measurement of a device with its gate shorted to its source.

**IT ALSO GATES S6.** Nothing calls `op_annot::text` today, so nothing is user-reachable
yet. The moment S6 lands the PDK-neutral carrier symbol, this becomes visible on real
schematics. S6 must either close this first, or ship the carrier with a deliberate,
recorded decision to accept it.

---

## S6 ACCEPTANCE — measured through the shipped carrier, ACCEPTED, NOT FIXED (2026-08-19)

The paragraph above says S6 "must either close this first, or ship the carrier
with a deliberate, recorded decision to accept it." **S6 accepted it.** This is
that record.

### BEFORE (S6's Measure agent, verbatim, on a tree with no carrier)

    B01 flat   xschem_library/devices/annotate_params.sym exists : 0
    B02 newsym xschem_libs_newsym/devices/annotate_params exists : 0
    B03 find_file_first annotate_params.sym                      : ||
    B04 op_annot::text proc exists                               : 1
    callers of op_annot::text tree-wide, excluding src/op_annot.tcl and
      tests/headless/test_op_annot.tcl -> (count: 0)

i.e. the defect was real but **unreachable**: nothing rendered `op_annot::text`
anywhere in the product.

### AFTER (S6, through `devices/annotate_params` on a flat sky130 schematic)

Same fixture, one FET with its source on GND, a raw containing neither `v(d)`
nor `v(g)`. Eight rows blank correctly; two fabricate:

    id    =        gm    =        gds   =        vth   =        vdsat =
    cgg   =        vgs   = 0      vds   = 0      ft    =        gm/id =

Independently reproduced by three S6 agents (plan, implement, adversary), the
last of them through the **real draw path** under xvfb, not only through
`xschem translate`.

### The decision — ladder rung L3 (user-visible, no prior ratification)

**D5. The carrier ships with 0446 open.** Rejected alternatives, both considered
and both worse:

* *(a) a Tcl-side per-pin finiteness pre-check inside `op_annot::text`.* It would
  re-parse a user-supplied expression in Tcl, edit S5's contract-bearing proc,
  and paper over a C defect (`token.c:4364` hardcodes GND to `0.0`; `eval_expr`
  then reads `expr(- - 0.0 )` as a unary minus) that the S6 brief explicitly
  forbade fixing in this step.
* *(b) dropping the `pinexpr` rows from the carrier block.* Hides correct data in
  the common case, and forks the block shape between carrier 1 (S6) and carrier 2
  (S9).

**Blast radius, measured:** only the two descriptors carrying `pinexpr` —
`sky130A/sky130_procs.tcl:387-388` and `gf180mcuD/gf180_procs.tcl:94-95`. IHP
(`ihp-sg13g2/sg13g2_procs.tcl:703`) deliberately has none and **cannot** hit
this.

### Pinned by a green check that asserts the WRONG behaviour

`tests/headless/test_op_annot.tcl` row **K16** asserts `vgs = 0` / `vds = 0`
against a raw with no `v(d)`/`v(g)`, and the other eight rows blank. It is green
today **on purpose**: when this issue's C fix lands, K16 goes red, and that red
is the signal that the fix reached the carrier. Do not "repair" K16 — update it
in the same change that fixes the C, and say so in the commit.

Row **S17b** already pinned the same fabrication one level down, before a carrier
existed.

### LEDGER QUESTION STILL OWED TO A HUMAN

> Ship a carrier that paints `vgs = 0` / `vds = 0` on a FET against a wrong
> `.raw` (sky130 and gf180 only), or hold the carrier until this issue's C fix
> (`token.c:4364` / `:5441`) lands?

S6's status is **E** for this question among others.
