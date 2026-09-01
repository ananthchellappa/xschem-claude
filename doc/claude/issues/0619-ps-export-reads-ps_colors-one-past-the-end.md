# 0619 - PS/PDF export reads ps_colors[cadlayers], one past the end of the array

**Status:** OPEN (filed by the Measure agent of the 0614+0615 crew, 2026-08-22)
**Found by:** measurement, while establishing the before-state byte-count oracle for issues
0614 / 0615. Not fixed here - filed per the crew rule "file anything measured and not fixed".
**Severity:** heap buffer over-read on every PS/PDF export that contains symbol text.
Cosmetically it injects a garbage RGB triple into the PostScript; structurally it is an
out-of-bounds read of a `my_calloc`'d array.

## The measurement

`src/xschem` at HEAD 0948d02e, PDK-neutral fixture, `xschem print ps` through the
10-argument viewport form:

```
cadlayers = 22
export a : 8 out-of-range RGB lines; distinct = {0.191406 0 3.18825e+06 RGB}
export b : 8 out-of-range RGB lines; distinct = {0.191406 0 3.18825e+06 RGB}
export c : 8 out-of-range RGB lines; distinct = {0.191406 0 3.18825e+06 RGB}
```

Every other RGB line in the same file is a sane triple in [0,1]:

```
0 0.597656 0.796875 RGB
0.128906 0 4.54678e+06 RGB      <-- this one
0.132812 0.132812 0.132812 RGB
0.132812 0.597656 0 RGB
0.664062 0.132812 0.132812 RGB
0.730469 0.132812 0 RGB
0.988281 0.695312 0 RGB
```

A blue channel of 4.54678e+06 means `ps_colors[pixel].blue` read about 1.16e9 - i.e. it is
not a colour, it is whatever sits after the array. The value is *stable within one process*
(three consecutive exports of an unchanged schematic give byte-identical garbage) and
*changes when the heap churns* - loading a raw between two exports moves it from
`49.3008` to `4.54678e+06`.

## The mechanism (read, not guessed)

- `psprint.c:1391` - `ps_colors = my_calloc(_ALLOC_ID_, cadlayers, sizeof(Ps_color));`
  Valid indices are `0 .. cadlayers-1`.
- `psprint.c:415` - `set_ps_colors(unsigned int pixel)` indexes `ps_colors[pixel]` with
  **no bounds check**.
- `psprint.c:1648-1651` - the export instance loop runs `for(c=0;c<cadlayers;++c)` and then,
  on the last layer, makes a dedicated **text pass one layer past the top**:
  ```c
  if(c == cadlayers - 1) {
    ps_draw_symbol(c + 1 , i, c + 1, what, 0, 0, 0.0, 0.0); /* ... draw texts */
  }
  ```
  so inside `ps_draw_symbol` both `c` and `layer` equal `cadlayers`. That is deliberate -
  `layer == cadlayers` is exactly the guard that selects the text block at `psprint.c:1196`.
- `psprint.c:1221` clamps the *push*: `if(textlayer < 0 || textlayer >= cadlayers) textlayer = c_for_text;`
  so `set_ps_colors(textlayer)` at :1222 is always in range.
- `psprint.c:1257` - the *pop* is **not** clamped and restores the wrong variable:
  ```c
  if(textlayer != c) set_ps_colors(c);
  ```
  With `c == cadlayers` and `textlayer` clamped below it, `textlayer != c` is **always true**,
  so `set_ps_colors(cadlayers)` fires once per symbol text drawn. Eight symbol texts in the
  fixture, eight garbage lines.

Note the push/pop are also asymmetric independently of the over-read: the push compares
against `c_for_text` while the pop compares against and restores `c`.

## Why it matters to 0614 / 0615 specifically

Issue 0615 requires the node-voltage colour override to reach `psprint.c` as well as
`draw.c` and `svgdraw.c`, and the 0614+0615 acceptance row asks for **three renders at
masks 1/3/0 with three distinct byte counts**. PS byte counts are **not a sound oracle**
while this bug stands, because the garbage float's *text width* changes the file size for
non-semantic reasons. Measured on the fixture:

```
5638 mb_p0.ps      mask 0
6186 mb_p1.ps      mask 1
5613 mb_p2.ps      mask 2
6211 mb_p3.ps      mask 3
```

masks 0/2 and 1/3 look different in PS - but after masking every `... RGB` line both pairs
are **byte-identical**, i.e. the entire delta was the width of `49.3008` versus
`4.54678e+06`. Use **SVG** for byte-count acceptance, or filter the RGB lines out of the PS
before comparing.

## Suggested fix (not applied)

Clamp in the accessor, which protects all 11 call sites at once:

```c
static void set_ps_colors(unsigned int pixel)
{
  if(pixel >= (unsigned int)cadlayers) return;   /* or clamp */
  ...
}
```

and separately make the pop symmetric with the push at `psprint.c:1257`
(`if(textlayer != c_for_text) set_ps_colors(c_for_text);`). Whoever fixes it should decide
which of the two is the real intent; they are independent defects that happen to overlap.

## Repro

`/tmp/.../scratch_0614+0615/ps_overread.tcl` (throwaway). Any `xschem print ps` of a
schematic containing at least one symbol text reproduces it; grep the output for an `RGB`
line with a component greater than 1.0.

---

## NOTE added 2026-08-22 by the 0614+0615 crew — the over-read's REACH just widened, on paper

0615 gave classified node-voltage texts a layer override (`annot_voltage_layer`,
default 9) applied at `psprint.c:1213-1224`. That change adds **no new
`set_ps_colors` call** and only moves the value of `textlayer` before the existing
push at `:1224` and the asymmetric pop at `:1258` — so on the **shipped corpus the
frequency of this over-read is unchanged**, because every shipped voltage carrier
already spells `layer=15` and therefore already took the push.

What is new: a text that previously **could not** reach the push now can. A
classified voltage text with **no explicit `layer=`** used to clamp to
`c_for_text` (no push, no pop); it now gets layer 9 and takes both. No shipped
symbol has that shape — a **user-written** symbol carrying a bare
`@spice_get_voltage` and no `layer=` does.

Nothing here was fixed, deliberately (the 0614+0615 brief forbade it). Recorded so
the eventual fix knows the entry set grew.
