# 1212 - a cell name typed on another sheet is invisible to the collision check, so that copy still gets someone else's device

**Branch:** annotate
**Status:** FIXED 2026-08-31 by item S6b. Verified by rows AS72, AS73 and
AS74 of `tests/headless/test_auto_specialize_1201.tcl`. What the design walk
cannot reach, and the cross-sheet copy it still refuses, are recorded as [[1220]].
Was: OPEN - measured, not fixed.
**Filed by:** item S6a, write-up pass, 2026-08-31. Measured first by that item's
verify pass and re-measured independently here on the shipped binary.
**Caused by:** [[1201]]. This is the half of [[1202]] that [[1202]]'s fix does
not reach - see "Why 1202 is still FIXED" below.

## What the user sees

Exactly what [[1202]] describes, one level down. A designer hand-types a
`schematic=` cell name on a copy that lives on a **sub-sheet**, and the setting
they typed beside it is silently thrown away: the copy is built out of a
different copy's version of the cell, with a different device in it. Nothing is
said about it anywhere.

## Measured, verbatim (2026-08-31, shipped binary, whole-design netlist)

Top sheet - one copy, one setting, nothing hand-typed:

```
C {w/wp.sym} 120 0 0 0 {name=xY W_P=0.5 modelp=pfet_01v8_lvt}
C {w/wmid.sym} 320 0 0 0 {name=xMID}
```

Sub-sheet `wmid.sch` - the copy that hand-types a name AND asks for the
high-threshold device:

```
C {w/wp.sym} 400 -300 0 0 {name=xW W_P=0.5 modelp=pfet_01v8_hvt schematic=wp__modelp_pfet_01v8_lvt}
```

Deck:

```
xY net1 wp__modelp_pfet_01v8_lvt W_P=0.5
.subckt wmid A
xW net1 wp__modelp_pfet_01v8_lvt W_P=0.5
.subckt wp__modelp_pfet_01v8_lvt A  W_P=1
XM2 net1 net2 net3 net4 sky130_fd_pr__pfet_01v8_lvt L=0.15 W=W_P ...
```

`pfet_01v8_hvt` appears **nowhere in the deck**. `xW` asked for the
high-threshold p-device and got the low-threshold one. The only sentence the
info window prints names `xY`:

> Note: on sheet .../wtop.sch, xY (a wp) sets modelp=pfet_01v8_lvt, and the wp
> drawing uses that setting inside it, so XSCHEM wrote a separate copy of wp
> called wp__modelp_pfet_01v8_lvt and pointed xY at it. Any other copy of wp on
> this design that asks for the same settings shares that one. You do not have
> to add anything to the sheet.

`xW` does not ask for the same settings and is not told it is sharing.

## Cause

GUARD AS-TYPEDNAME - the fifth probe [[1202]]'s fix added to
`auto_spec_collides()` in `src/actions.c` - walks `xctx->instances`, which is
**the sheet currently being netlisted**. A `schematic=` name typed on a copy
one level down is not in that array when the top sheet's call lines are
written, so the probe cannot see it and the name is minted anyway.
`get_additional_symbols()` then folds the two symbol blocks together by name.

## Why [[1202]] is still marked FIXED

The case [[1202]] measured, files and pins with row AS51 - two copies on **one
sheet** - is genuinely closed, and that is the case a designer reaches by
copy-pasting a cell on the sheet in front of them. This issue is the same defect
through a door that fix does not open onto. [[1202]]'s own "What would fix it"
section says *"the other copies on this DESIGN"*; the fix implements *"on this
sheet"*, and this file records the difference rather than leaving it inside a
closed issue.

## Reachability

Adversarial, like [[1202]]: the designer has to type the exact spelling the tool
invents, `<cell>__<setting>_<value>`. The harm when it happens is a silently
wrong deck.

## What would fix it

The probe needs the names typed anywhere in the design, not on one sheet. Two
shapes, neither measured:

1. Collect every `schematic=` value during the hierarchy traversal that
   `spice_netlist()` already performs, before any name is minted, and probe that
   set. Costs one pass and a table.
2. Refuse to mint any name matching the invented shape that a designer could
   plausibly have typed - blunt, and it would rename cells in existing decks.

## Rows

None. A row needs the two-sheet fixture above and must assert that each copy's
body holds the device that copy asked for. Today's row AS51 is single-sheet and
passes.

---

## FIXED, item S6b (2026-08-31)

Two guards, because one of them cannot cover everything.

**GUARD AS-HIER** (`auto_spec_scan_design()` / `auto_spec_scan_file()` in
`src/actions.c`). Before the first cell name is minted, XSCHEM reads the
design's sheet FILES and registers every cell name a copy has typed by hand.
Files, not loaded instances, because at the moment a name has to be minted the
only sheet that is loaded is the one being written -- that ordering is 1202's
whole defect and this is the same defect one level down.

* Lazy: run once per netlist run, and only after a copy has actually qualified.
  Of the 651 shipped schematics measured, not one copy qualifies, so not one of
  them opens an extra file. The full before/after byte-diff of all 651 decks is
  identical.
* Bounded: `CADMAXHIER` depth cap and a visited set on the resolved absolute
  path, so two sheets that place each other terminate. Row AS74 requires both by
  reading the code -- a missing bound is a HANG, not a red.
* Conservative by construction: anything it cannot parse or resolve for certain
  it SKIPS, which degrades to exactly today's behaviour. It never guesses.
* **The TOP sheet registers nothing**, deliberately. Its instances are loaded, so
  GUARD AS-TYPEDNAME already sees them -- and sees them *with their settings*,
  which is what lets GUARD AS-TYPEDSAME (issue 1215) exempt a copy asking for
  the same thing. A text scan cannot work a settings key out, so a name
  harvested from a file is unconditionally taken; registering the top sheet here
  as well would un-do 1215 on the very sheet 1215 is about.

Rejected alternative: `load_schematic()` the hierarchy up front so the real
resolver does the work. It drifts from nothing, but it reads every sheet twice
per netlist and it cannot run where it is needed -- the mint happens inside
`spice_netlist()` while the top sheet's call lines are being written, and
loading another sheet there destroys the context being written.

**GUARD AS-CLASH** (`auto_spec_clash_check()` in `src/actions.c`), the backstop
for what the walk skips -- a sheet named through a generator or through an `@`
substitution resolved only while the netlist runs. When a copy asks for a cell
name this run already handed to a copy that wanted something else, XSCHEM says
so in plain English, naming the sheet, the copy, the cell name and the setting
that did not reach the simulator, and saying what to do. Severity 2, like every
other sentence this feature prints: it appends to the info window and does not
force it open.

**Rows:** AS72 (the ordinary two-level case; both devices in the deck, the
hand-typed name kept, the invented one stepping aside), AS73 (the backstop: one
plain-English line, with none of the tool's internal words in it), AS74
(structural bounds).

**On the user's ruling queue:** whether a clash should be louder than an info
window line -- open the window by itself, or fail the netlist.

**RESIDUAL, filed as 1220.**
