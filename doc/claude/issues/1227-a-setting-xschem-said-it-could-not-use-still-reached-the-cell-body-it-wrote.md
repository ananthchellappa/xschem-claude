# 1227 - a setting XSCHEM said it could not use still reached the cell body it wrote

**Filed and closed by** item S6b's REPAIR pass, 2026-08-31, on two verifier
findings against S6b's own fix for issue 1213.
**Severity** high. RULING D5-1: a deck no simulator will read, printed under a
sentence saying the setting that broke it "changed nothing"; and, in the second
shape, one copy silently simulating another copy's transistor.

## What a designer saw

Issue 1213 taught XSCHEM to refuse a setting whose value is a space, a tab, a
line break or nothing but punctuation. The refusal worked for a copy whose ONLY
setting was of that shape: the copy fell back to the plain cell and the designer
was told why.

Add ONE usable setting beside the unusable one and the whole defect came back.
The copy now qualifies for a version of the cell of its own -- correctly, on the
strength of the usable setting -- and the cell body it was given was fed the
copy's WHOLE property string, refused setting included.

Measured on one sheet, one copy of a cell whose drawing reads two settings:

```
C {as/wq.sym} 120 0 0 0 {name=xMN W_P=0.5 modelp=pfet_01v8_lvt modeln="<a line break>"}
```

```
xMN net1 wq__modelp_pfet_01v8_lvt W_P=0.5
.subckt wq__modelp_pfet_01v8_lvt A  W_P=1
XM2 net1 net2 net3 net4 sky130_fd_pr__pfet_01v8_lvt L=0.15 ...
XM3 net5 net6 net7 net8 sky130_fd_pr__
XL=0.15 W=W_P nf=1 ad='int((1 + 1)/2) * W_P / 1 * 0.29' ...
```

`sky130_fd_pr__` names a device in no PDK, and the transistor line is cut in
half so the simulator also sees a phantom element called `XL`. That is exactly
what issue 1213 was filed about, rebuilt one level in. The space-valued and
punctuation-valued variants gave `sky130_fd_pr__` and `sky130_fd_pr__---`.

And in the same run the designer read: "instance xMN ... sets modeln= , but wq
never reads modeln when the netlist is written, so that setting did not reach
the simulator and changed nothing." It had reached it, and it had broken the
deck.

### The second shape: one copy simulating another copy's device

A refused setting takes no part in the key that decides which copies share a
cell body. So two copies that ask for the same usable setting and carry
DIFFERENT refused values spell one key and share ONE body -- first writer wins:

```
C {as/wq.sym} 120 0 0 0 {name=xR1 ... modeln="nfet_01v8_lvt "}
C {as/wq.sym} 320 0 0 0 {name=xR2 ... modeln="nfet_03v3_nvt "}
```

`nfet_03v3_nvt` appeared **zero** times in the whole deck. xR2 simulated xR1's
transistor. Both designers were told only that their own setting "changed
nothing" -- false for xR1, true for xR2, and indistinguishable.

### The third shape: the schematic surface, not the deck

Walking down into such a copy records its settings on the level the designer is
standing on, and the annotation surface resolves a transistor's `model=@setting`
through them to work out what to call that device in the results file. With the
refused setting still recorded there, the schematic would ask for numbers
measured for a device the simulator never had. `src/op_annot.tcl` names this
outcome in its own comment, and calls it RULING D5-1.

### The fourth shape: a value with an `@` in it

`modelp=pfet@01v8_lvt` passed the 1213 rule -- one word, letters and digits --
and minted a cell called `aswv__modelp_pfet_01v8_lvt`, which is the name a copy
typing the clean `pfet_01v8_lvt` gets, while the deck inside it carried
`sky130_fd_pr__pfet@01v8_lvt`. The `@` and the `%` are the two marks XSCHEM
reads as "fill something in here later"; the netlister resolves them a second
time while writing the device line, so such a value cannot be spelled into a
cell name honestly. The design walk in `actions.c` already refuses every `@`
value for exactly that reason.

## The fix

**GUARD AS-STRIP**, `lost_attrs_strip_unusable()` in `src/token.c`: the copy's
property string with the refused settings removed, so the cell body XSCHEM
writes for that copy falls back to the value the SYMBOL's own template supplies
-- which is what the warning in the same run says happened, and what the tool
did before issue 1201 existed. Two callers, one function:

* `get_additional_symbols()` (`src/actions.c`) for the cell body, and ONLY when
  the name was minted by XSCHEM. A body the designer named by hand keeps the
  property string byte for byte -- explicit beats implicit, and no shipped deck
  moves.
* `descend_schematic()` (`src/actions.c`) for the level the designer stands on,
  so both doors read one answer.

Equal keys therefore mean equal cell bodies again, which is the invariant GUARD
AS-TYPEDSAME (issue 1215) rests on and which the 1213 fix had quietly broken.

**The allow-rule now also refuses `@` and `%`** (`ua_value_specialisable()`),
with a fourth explanation in `ua_value_fault()` and a shared rule clause that
states the whole rule rather than half of it.

## Measured after the fix

648 shipped sheets under `sky130A/ gf180mcuD/ ihp-sg13g2/ xschem_library/
xschem_libs_newsym/` netlisted: **zero** copies qualify for a cell of their own,
so no shipped deck can have moved by this change at all.

## Rows

**AS78** (the line-break leak, and no deck line may begin `XL=`), **AS79** (two
copies whose refused values differ -- neither typed device may appear anywhere),
**AS80** (the `@`), **AS81** (the level the designer stands on), and two new
elements on **AS65**, which is the row that could have caught all of this and
asserted only sentence text. **AS67** now counts three askers of the rule, not
two.

## A trap recorded at the site

This build compiles the **no-`HAS_SNPRINTF`** arm of `my_snprintf()`
(`src/util.c`), a hand-written formatter that does not understand `%%`: it reads
the second per-cent as a new conversion and eats the words after it. The
sentence came out ending `no '@' or '% 536627636n it.` The per-cent sign is
passed as a `%s` argument instead, with the reason written beside it.

## Related

**1213** is the issue this is the second half of. **1220** records what is still
knowingly imperfect about the cross-sheet case. **1223** is the sibling defect
in the same sentence, on the same shared buffer.
