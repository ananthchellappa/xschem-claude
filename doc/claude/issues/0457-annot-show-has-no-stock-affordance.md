# 0457 — `annot_show` has no stock (non-cadence-profile) control

Status: **BOTH QUESTIONS RULED BY THE USER 2026-08-22.** (a) the resting value
stays **0**; (b) the control is a **View-menu checkbutton pair**, which needs no C
action and no build. Implementation owed. See "RULING" at the bottom.
Found: S8 of doc/claude/specs/op_annotation.md.

S7 gave `hide=op` / `hide=opvolt` teeth behind the `annot_show` mask and left the
mask at 0 with nothing in a running session able to write it. S8 supplies three
writers:

  * `6` / `Ctrl-6` / `Alt-6` in the **cadence profile** (src/cadence_style_rc),
  * and, for everyone, `xschem set annot_show 1` inside the two shipped
    **Annotate Operating Point** menu items (decision D8).

S8 decision D9 ratified the default of 0: with no raw loaded, mask 1 paints a
block of label-only rows on every carrier at startup, and S10 will multiply that
across every PDK FET, so a resting state the user leaves with one keystroke is
the least surprising one.

**THE UNRATIFIED RESIDUAL, which is the ledger question.** Outside the cadence
profile there is still no *control*: the two Annotate-OP menu items are on-ramps
with no off-ramp short of editing `~/.xschem/xschemrc`, and the three chords are
invisible to `xschem bindings dump` so they cannot be remapped the way every
other action can (S8 decision D10).

> Should `annot_show` get a first-class stock control — a View-menu pair of
> checkbuttons, or three registered C actions in `keybindings.csv` so the chords
> are remappable — or is the cadence profile the intended home for this feature?

Answering it needs a C action and a build, which S8's rc-only, no-build scope
excluded. Recorded here so the decision is made once, deliberately.

**⚠ S10b sharpens this from a carrier nobody has placed to 40 shipped symbols in
every sky130 design** (issue **0475**): the sky130 FET annotation texts are now
`hide=true`, so a user whose rc never sources `sky130_procs.tcl` gets no overlay at
any mask and the numbers are reachable only through View > Show hidden texts — and
per 0475 §11.2 that also hits users who *do* source it but reached the symbol
through a vendored or aliased library, because the descriptor matches on
`cell::name`. Neither of 0475 §7's alternatives (a built-in fallback registration,
or defaulting the mask on) can be evaluated until this residual is settled.


---

# RULING — the user, 2026-08-22

Both halves were put to the user with measurements. Both were answered.

## (a) The resting value stays 0 — RATIFIED, and the evidence is a picture

The claim S8's decision D9 rested on — *"with no raw loaded, mask 1 paints a block
of label-only rows on every carrier at startup"* — was re-measured and is true,
and it is worse than "a block of label-only rows" suggests.

```
--- NO RAW LOADED, mask 1 ---
_annotated -> 0
text M1    -> id  =   gm  =   gds =   vgs =   vth =   vds =
```

Rendered on the shipped `sky130_tests_ase/bandgap_opamp` (13 FETs), the block
lands **on top of each device's own geometry text**: `pfet_01v8` overprinted by
`gm =`, `nf=1` by `vgs =`, `1 x 1 / 6` by `vth =`. Four of six rows illegible on
every device, in exchange for **zero information** — there is no data to show.

Evidence, kept: `~/op_annot_demo/0457_A_rest_mask0.png`,
`0457_B_mask1_noraw.png`, and the side-by-side crop `0457_rest_vs_mask1.png`.
Reproduce with `~/op_annot_demo/shot0457.tcl` (see `REPRO_bandgap.md` for the rc).

**Second measurement, not previously recorded:** with no raw, **mask 1 and mask 3
render byte-identical** (120391 bytes both). Node voltages have nothing to show
either, so the richer setting buys nothing at rest. The choice at startup is not
"less detail vs more detail", it is "clean sheet vs shredded sheet".

This is issue **0605**'s collision at its worst case: all of the damage, none of
the payoff. Since every xschem session begins with no raw loaded, defaulting to 1
would mean every sky130 design *opens* in state B.

### The precondition this exposes, recorded not fixed

`op_annot::text` returns six label-only rows when `_annotated` is 0. At mask 0
that is invisible, so it costs nothing today. It is *not* invisible to a user who
presses `6` **before** running her simulation — she gets the shredded sheet and no
numbers. Whether the block should render **nothing** when there is no data, rather
than empty labels, belongs with **0605** and is not settled here.

## (b) A View-menu checkbutton pair — and the real defect is an ONE-WAY DOOR

The issue asks whether `annot_show` deserves "a first-class stock control". The
grep that framed the question for the user is sharper than the issue text:

```
src/xschem.tcl:14997   xschem set annot_show 1
src/xschem.tcl:15388   xschem set annot_show 1
src/xschem.tcl:16028   set_ne annot_show 0      <- the startup default, not a control
```

**Every writer in the stock tree turns it ON. Nothing turns it off.** A user
clicks *Simulation → Annotate Operating Point into schematic*, gets the overlay
across the whole sheet, and cannot remove it without editing
`~/.xschem/xschemrc` and restarting. That is a menu item that only goes one way.

The three chords do turn it off, but `cadence_style_rc` is **commented out** in
the stock `src/xschemrc:767`, so a stock user never has them; and
`src/keybindings.csv` carries **no `annot` rows**, so they cannot be remapped the
way every other action can (S8 decision D10).

**Chosen: a View-menu checkbutton pair** — device OP info, node voltages —
mirroring the two `annot_show` bits, placed with the existing *Show hidden texts*
entry that FAQ **Q48** already sends users to.

Rejected, with reasons:

* *Registering three C actions in `keybindings.csv`.* Makes the chords first-class
  and remappable, and they stop being invisible to `xschem bindings dump` — but it
  needs a C action and a build (the reason S8 could not do it), and it still
  leaves nothing discoverable by clicking. Not refused on merit; not chosen now.
* *Both.* The complete answer, and the door stays open to it — the menu pair does
  not conflict with later registration.
* *Cadence profile is the home; just make the two menu items toggle.* Smallest
  change, but it leaves the feature undiscoverable outside a profile that ships
  commented out.

### Why this one needs no build

The pair is Tk checkbuttons over `xschem set annot_show`, which already exists and
already push-pulls the Tcl var (`src/actions.c:1176-1182`). No C action, no
`keybindings.csv` row, no rebuild.

## Unblocks 0475 §7

This file's last paragraph says neither of **0475** §7's alternatives — a built-in
fallback registration, or defaulting the mask on — *"can be evaluated until this
residual is settled"*. It is now settled: **the mask stays off**, so "default the
mask on" is refused, and the fallback-registration alternative can be taken up on
its own merits.

`owed.sh clear rule 0457` — both halves answered, 2026-08-22.
