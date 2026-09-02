# 1253 — the declutter does not reach P6 pin-owned pin names

Status: **open** (measured first-hand by item A3's write-up pass, 2026-09-02;
**not fixed** — deliberately, see below) · Branch: `fluid-editing`
Related: **1244**, ruling **D-1**, the P6 pin-name feature

## The defect

Ruling **D-1** is explicit that pin labels are in scope, in the user's own words:

> *"even pin labels can be hidden when user is hiding other things that are not
> @name. We are only interested in name and annotation of OP info."*

Item A3's rung sits in `text_hidden()`, which gates the loop over a symbol's
`text[]` records. It does **not** gate the **fourth** pass — the P6 feature that
draws a pin's name from the pin's own tokens, gated by `pin_name_visible()`:

```
src/draw.c:959       if(!pin_name_visible(pin->prop_ptr)) continue;
src/svgdraw.c:986    if(!pin_name_visible(pin->prop_ptr)) continue;
src/psprint.c:1279   if(!pin_name_visible(pin->prop_ptr)) continue;
```

So a pin whose symbol spells `show_pinname=true` keeps its name on a fully
decluttered device, beside the device name and the OP block.

## Measured, first-hand, 2026-09-02 (after item A3 landed)

Fixture: a one-instance sheet, symbol `type=nmos` with a `@name` text, one
parameter text `P6PARAM`, a `d` pin spelling `show_pinname=true` and a `g` pin
spelling `show_pinname=false`; a hand-written OP raw; descriptor registered on
type `nmos`. SVG text extraction:

```
show_pin_names=1 mask=1 : M1 P6PARAM d {zid =}
show_pin_names=1 mask=9 : M1 d {zid =}
show_pin_names=2 mask=1 : M1 P6PARAM d {zid =}
show_pin_names=2 mask=9 : M1 d {zid =}
```

`P6PARAM` (a `T` record) is hidden by the rung. **`d` is not** — it is the
pin-owned name, drawn by the P6 pass. `g` (`show_pinname=false`) never renders,
which is the non-vacuity control that the pass is really what is being observed.

## Blast radius, censused on this tree

```
$ git ls-files '*.sym' | xargs grep -ho "show_pinname=[a-zA-Z]*" | sort | uniq -c
      4 show_pinname=
   1240 show_pinname=false
   2968 show_pinname=true
```

**The acceptance rows are unaffected**: all four pins of each of the three PDK
FETs the batch accepts against (`sky130A` `nfet_01v8`, `gf180mcuD` `nfet_03v3`,
`ihp-sg13g2` `sg13_lv_nmos`) spell `show_pinname=false` — verified for
`nfet_01v8.sym`, four of four. The 2,968 `true` records are elsewhere in the
libraries, and a user's own symbol can spell it either way.

## Why it was not fixed here (ladder L2, and the rejected alternative)

The plan's Files cell names **six** instance call sites of `text_hidden()`. The
P6 pass is a **seventh** site, in a loop with no instance-text semantics — it
walks `symptr->rect[PINLAYER]`, not `symptr->text[]`, and its visibility question
is answered by a different predicate with its own tri-state Tcl var and its own
cache (`pin_names_sync_cache`). Adding a declutter arm there in the same commit as
the draw rung would have widened the change past its measured surface.

**Rejected:** doing it anyway "because D-1 says pin labels". The rung as shipped
already hides pin labels that are `T` records, which is every pin label on every
PDK device the batch accepts against; the residue is a *different feature's*
pass and deserves its own measurement.

## Recommended repair

One arm in the three P6 loops, reusing the same gate the rung uses:

```c
if(text_hidden_inst(0, n)) continue;   /* flags 0: no name, no class -> declutter applies */
```

placed beside the `pin_name_visible()` test. `text_hidden_inst(0, n)` is exactly
"would the declutter hide an unclassified text on this instance?" — it is the
existing predicate, not a fourth copy of the decision (invariant I1). Verify
against a fixture whose pins spell `show_pinname=true`; the four PDK acceptance
rows cannot see it.
