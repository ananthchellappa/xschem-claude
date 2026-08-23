# 0631 — `op_annot::devpath` takes `@model` from the LIVE hierarchy; the netlister's shared `.subckt` block does not carry it

STATUS: **OPEN — measured, not fixed.** Found 2026-08-22 by the S3 crew while
closing the generate → simulate → read loop on the user's own bench,
`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap`. **2 of 78 devices** get a card
that names nothing.

This is the first defect of its kind the feature has been able to see: the
hand-written demo generator (`~/op_annot_demo/gen.tcl`, 78 cards) only ever
walked `x1.x1` — 13 FETs inside `bandgap_opamp` — and never reached the two
instances that carry the override.

---

## MEASURED

```
$ op_annot::save_cards   on sky130_tests_ase/tb_bandgap
  rc=0  469 lines (1 x `.save all` + 468 cards)  244 ms
  counts = dropped_by_rule 0  not_found 0  name_failed 0     <-- reports success
```

Cross-checked against the deck the netlister writes for the same cell (blocks
expanded independently, `+` continuations joined, callee = last token before the
first token containing `=`):

```
deck FET leaves: 78      distinct card devices: 78
ORPHAN cards (name nothing in the deck)   2:
    @m.x1.x5.xm2.msky130_fd_pr__pfet_01v8_lvt
    @m.x1.x6.xm2.msky130_fd_pr__pfet_01v8_lvt
MISSING devices (in the deck, no card)    2:
    @m.x1.x5.xm2.msky130_fd_pr__pfet_01v8
    @m.x1.x6.xm2.msky130_fd_pr__pfet_01v8
```

And run for real (the demo deck with its own device cards replaced by the
generated block, `/usr/local/bin/ngspice 46+`, `tran 10n 40u`, 28.9 MB raw):

```
raw vars 892      cards with no vector at all: 0
dims=0 vectors:  12   <-- exactly the 2 orphan devices x 6 params, and nothing else
node voltages / branch currents kept: v(vbg) v(vcc) i(vcc) all present
```

**466 of 468 cards are perfect.** The other 12 are the `dims=0` shape rule R5
warns about: a full column of `0.0`, rc 0, and **stderr completely silent**. On
screen those two FETs would read **`0`**, which is invariant **I3**'s forbidden
outcome (a plausible wrong number is worse than a blank).

## THE CAUSE, EXACTLY

`sky130A/xschem_libs/sky130_tests/bandgap/schematic/bandgap.sch:191,193`

```
C {sky130_tests/passgate} 1380 -530 0 0 {name=x5 W_N=0.5 L_N=0.35 W_P=0.6 L_P=0.35 … m=1
modelp=pfet_01v8_lvt}
```

`passgate.sch`'s M2 is `model=@modelp`, and `passgate.sym` declares
`extra="VCCBPIN VSSBPIN modeln modelp"` — but its **`format=` line does not pass
`modelp`**:

```
format="@name @pinlist @VCCBPIN @VSSBPIN @symname W_N=@W_N L_N=@L_N W_P=@W_P L_P=@L_P m=@m"
```

So the deck writes **one** shared block

```
.subckt passgate Z A GP GN VCCBPIN VSSBPIN  W_N=1 L_N=0.2 W_P=1 L_P=0.2
XM1 … sky130_fd_pr__nfet_01v8 …
XM2 … sky130_fd_pr__pfet_01v8 …        <-- the DEFAULT, not the caller's lvt
```

and every caller of `passgate` — x3, x4, x5, x6 — simulates the **non-lvt**
device. `op_annot::devpath` asks `xschem translate M2 @model` **inside the
descended cell**, where the hierarchical `@modelp` *does* resolve against the
caller, and gets `pfet_01v8_lvt`. Schematic and deck genuinely disagree; the
emitter follows the schematic and the raw follows the deck.

Note it is **not** the S3 walk landing in the wrong cell: `XM1` under the same
two instances is named correctly (`…nfet_01v8`, matching the deck), because
`modeln` was not overridden. Only the one overridden token diverges.

## TWO READINGS, AND BOTH ARE ARGUABLE

1. **A shipped-library defect.** `passgate.sym` puts `modelp` in `extra=` and not
   in `format=`, so a caller's override changes the *schematic* and the symbol's
   own on-canvas `@modelp` text while being **silently dropped from the netlist**.
   Whoever set `modelp=pfet_01v8_lvt` on x5/x6 is simulating something other than
   what they drew, and has been since long before this feature existed.
2. **A name-builder defect.** Even if (1) is fixed, `devpath` reads the *editor's*
   view of the hierarchy while the card is consumed by the *netlister's* view.
   Anything the netlister flattens away — an `extra=` override, a dedup, a
   parameter specialisation it did not synthesise a block for — reappears here.

## WHY S3 DID NOT FIX IT

The available fix is a **deck-model cross-check** in the walk: the deck already
knows the leaf's callee token (`XM2 … sky130_fd_pr__pfet_01v8 L=…` → the last
token before the first `=`), so when the built devpath *embeds* the model string
the two can be compared and a mismatch suppressed and counted (`not_found`).

It was not taken because:

* there is **no guardian row** for it — the section-W and section-X fixtures both
  build device names that do not embed the model (`@m.mt0`, `@m.xmx0.m1`), so the
  check would be **inert** on every existing fixture and would ship exactly the
  "green check certifying nothing" that has now reverted this step four times
  (spec landmine 11);
* the "does the devpath embed the model" test is a heuristic, and a false
  positive **suppresses good cards** — under-emission on 78 devices to fix
  over-emission on 2;
* the honest fix for reading (1) is one line in a shipped `.sym`, and that is a
  library change, not an op_annot change.

## WHAT A FOLLOW-UP STEP OWES

1. A fixture with a device whose descriptor devpath **embeds the model** and a
   caller that overrides that model through an `extra=` token the `format=` line
   drops — i.e. a two-cell reproduction of `passgate` — so the cross-check has a
   row that reddens without it.
2. The cross-check itself, counted as **`not_found`** (the deck has the device,
   the walk could not name it), never as `dropped_by_rule`.
3. A decision on reading (1): fix `sky130_tests/passgate.sym`'s `format=` to pass
   `modelp`/`modeln`, or delete the dead `modelp=` from `bandgap.sch`'s x5/x6.
   Either makes the schematic and the deck agree again. **This is a change to a
   shipped PDK library and needs the user's ruling.**

## THE GOOD NEWS, FOR THE RECORD

The same run is the first end-to-end proof the feature has ever had on the user's
own bench: **all 78** cards of the hand-written `~/op_annot_demo/bandgap_bare.save`
are a byte-exact subset of the 468 the generator now produces, no card carries an
`i()`/`v()` wrapper, `.save all` is present exactly once as the first line, and
the node voltages survive it (rule R2).
