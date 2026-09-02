# 1253 — the declutter does not reach P6 pin-owned pin names

Status: **FIXED** by item **A5-b**, 2026-09-02 (measured first-hand by item A3's
write-up pass; three one-liners, one per back end). **Coverage residue filed as
1261.** · Branch: `fluid-editing`
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


---

## FIXED by item A5-b, 2026-09-02

**What landed — this issue's own recommended one-liner, taken verbatim**, on the
line immediately after the `pin_name_visible()` anchor and **before**
`get_pin_name_layout()`, so the `pnm`/`pfont` malloc/free pair is never reached
for a hidden pin. Byte-identical in all three back ends:

```c
      if(!pin_name_visible(pin->prop_ptr)) continue;
      if(text_hidden_inst(0, n)) continue;    /* 1253 / D-1, see above */
```

`src/draw.c:975` · `src/svgdraw.c:1002` · `src/psprint.c:1295`. `flags` 0 carries
no annotation class and no explicit `hide=` bit, so the call falls through to the
declutter rung and returns 0 whenever the bit is clear — nothing outside mask 9
moves. `pin_name_visible()` itself is untouched (it is shared with the
symbol-edit views through `pin_name_shown()`).

**Measured before (item A5's measure pass, verbatim), fully valued block:**

```
A5b SVG mask 9 texts = MA1 XDRAIN {aid = 11.1u} {agm = 333u}
A5b PS  mask 1 : (MA1)=1 (A5W=1u)=1 (XDRAIN)=1 (XGATE)=0
A5b PS  mask 9 : (MA1)=1 (A5W=1u)=0 (XDRAIN)=1 (XGATE)=0
```

**After:** rows **A36** (SVG) and **A37** (PostScript) gold the pin name gone at
mask 9 and present at mask 1, with the `show_pinname=false` twin rendering at
**neither** mask — the non-vacuity control that the P6 pass is what is being
observed. Row **A39** golds invariant I-C: with `ANNOT_SHOW_OP` clear, masks 0 and
8 are identical and both keep the pin name. Row **A38** is the source census, and
row **A22**'s census golden moved `{3 1 1 1 0}` → `{4 2 2 1 0}` deliberately — the
regexp was **not** widened.

**Sabotage:** `SB-A5b-PINS` (a `text_hidden_inst_pin_off` shim at *only* the three
new call sites, the other six instance sites keeping the real predicate) reds
**A22, A36, A37, A38**, exactly as predicted.

## Still open

* **1261** — `draw.c`'s leg is asserted by the source census A38 only. The belief
  that `draw()` has no observable seam is **wrong**: `print_image()` calls
  `draw()`, and a warm-then-real `xschem print png` pair at a tight viewport
  measures the pin name going away (12912 → 8301 bytes, with an 8744/8744
  `show_pinname=false` control).
* **The click target does not move.** `symbol_bbox()` (`src/select.c`) walks only
  `symptr->text[]` and has no P6 pass, so hiding a pin name changes no bbox and
  nothing about picking changes. Adding a fourth pin pass there would be new
  geometry, not a conformance gap; nothing in D-1 asks for it. Deliberately not
  done, and row A38 golds `select.c` at **zero** on purpose.
