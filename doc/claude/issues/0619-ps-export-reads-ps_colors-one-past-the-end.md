# 0619 - PS/PDF export reads ps_colors[cadlayers], one past the end of the array

**Status:** FIXED 2026-09-29 (filed by the Measure agent of the 0614+0615 crew, 2026-08-22).
⚠ The header is deliberately not the whole answer here: the **over-read** this title names had
already been fixed by issue **1353**, and what 2026-09-29 repaired is the push/pop asymmetry this
file called an independent defect -- which was still handing the accessor an out-of-range index.
Read "RESOLVED 2026-09-29" at the end BEFORE re-measuring anything in "The measurement" below;
every figure there is a `0948d02e` figure and none of it has been reproducible since 1353.
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

---

## RESOLVED 2026-09-29 — and HALF OF IT HAD ALREADY BEEN FIXED BY ISSUE 1353

Read this before re-measuring anything above. The filing's two defects did not age the same way.

**The over-read was already gone.** Issue **1353** added the bounds test this file's "suggested
fix" asks for, in exactly that shape:
`set_ps_colors()` opens with `if(pixel >= (unsigned int)cadlayers) return;`. So every number in
"The measurement" above -- the 8 out-of-range RGB lines, `0.128906 0 4.54678e+06` -- is a
`0948d02e` figure and has not been reproducible since. It is fenced three ways already:
row **V24** of `tests/headless/test_ps_valid_1350.tcl` asserts the guard's text, **V19** asserts
every RGB triple on a two-instance fixture is in range, **V20** asserts the same over a ~96-sheet
corpus. Measured here: the emitted PostScript is clean, all triples in [0,1].

**The asymmetry -- the half this file called "independent" -- was still live, and it is the whole
of what remained.** `ps_draw_symbol()` still ended its symbol-text pass with
`if(textlayer != c) set_ps_colors(c)` and its pin-name pass with `if(plw != c) set_ps_colors(c)`,
both with `c == cadlayers`. So **the out-of-range index was still being COMPUTED and still being
HANDED TO THE ACCESSOR** -- 4 requests for colour 22 with `cadlayers == 22` on a two-instance
fixture, per export verb, visible with `-d 1` because `dbg()` prints the index before the 1353
test consumes it. Only the sink was repaired; the caller was not.

**⚠ WHICH IS WHY THIS FILING MATTERED EVEN THOUGH ITS SYMPTOM WAS CURED.** Every fence this tree
had was keyed to the malformed OUTPUT. A change made for a different issue stopped producing that
output, and all three rows went on passing while the defect sat in the file untouched -- CLAUDE.md's
"a fence keyed to a symptom dies quietly when something else cures the symptom", in the flesh.

**The intent question this file raised is answered, from history and not from taste.** Upstream
`70aed29f` (2025-04-06) wrote the pop while the text block was still guarded
`layer == cadlayers - 1`, where `c` **was** the ambient layer and `set_ps_colors(c)` was in range.
Upstream `6b12969d` (2025-04-21) moved the pass one layer past the top -- guard to
`layer == cadlayers`, plus `ps_draw_symbol(c + 1, i, c + 1, ...)` in `create_ps()` -- to keep text
above geometry, and did not update the pop. `c` became a pseudo-layer; the pop became a fossil of
the world before that commit. `draw.c` and `svgdraw.c` carry the same two clamps and **no pop at
all**, because their colour is not sticky state. So the pop mirrors the push, the push compares
against `c_for_text`, and `c_for_text` is what the pop must restore. Fixed that way at both sites.
`ps_draw_annot_overlay()`'s `if(layer != c) set_ps_colors(c)` is a **different and correct** site:
its caller passes `cadlayers - 1`.

**What the repair changes in the output, measured both ways.** Where `textlayer == c_for_text`
(a symbol text on its default layer -- the shipped corpus) the exported PostScript is
**byte-identical** to before: 4 discarded requests simply stop being made. Where they differ (an
explicit `layer=` on a symbol text, or 0615's `annot_voltage_layer` override) the fix **adds the
restore that was missing**, measured on a `layer=7` fixture as two extra `0.132812 0.132812
0.132812 RGB` lines, 6041 -> 6103 B. No rendered colour changes:
`doc/claude/issue_1607_batch/receipts/B-display-arm.md` measured the suppressed restores as dead
colour sets, 0 of 36 rasterised pages differing, because every drawing site emits its own colour
first (`ps_draw_string_line()` opens with `set_ps_colors(layer)` inside its own `GS`/`GR`). What
the repair actually buys is that the push's `if(textlayer != c_for_text)` guard -- an "already at
that colour" test -- becomes **sound**, which it was not while the pop never restored the ambient.

**⚠ AND IT COSTS SOMETHING, MEASURED: THIS FIX MAKES ROW V24 THE *SOLE* FENCE FOR THE 1353
CLAMP.** Delete `if(pixel >= (unsigned int)cadlayers) return;` from `set_ps_colors()` with this
repair in place and `test_ps_valid_1350` reports **`1 FAILED (28 passed)` -- V24 and nothing
else**. The five behavioural rows that used to catch exactly that deletion, **V19** and **V20**
(RGB channels in range) and **V22**, **V23** and **V26** (export determinism), all stay **GREEN**
with a real out-of-bounds read reinstated.

**They were fences only BECAUSE 0619 was unfixed, and that is the whole trap.** Until this fix
the caller was still computing `cadlayers` as a colour index -- `if(textlayer != c)
set_ps_colors(c)` once per symbol text, `if(plw != c) set_ps_colors(c)` once per pin name, both
with `c == cadlayers` -- so the clamp **had a live exerciser**, and removing it put heap garbage
straight into the exported file where those five rows could see it. Measured on that older tree:
deleting the clamp *without* this repair reddens **eight** rows, V20 reporting `bad triples=49153
on 66 sheets`. Repairing the caller removed the last path that feeds the clamp an out-of-range
index, so the clamp is still correct and still necessary as the accessor's contract for every call
site in the file, and **no longer exercised by anything the suite runs**. Row V28 asserts the
caller's side and is *not* a fence for the clamp: it stays green when the clamp goes. (The
"11 call sites" in "Suggested fix" above is stale like every other figure in that part of this
file; no replacement count is written here, because a count in prose is a number nothing
re-checks.)

**Therefore deleting or "simplifying" V24 silently unfences a genuine heap over-read** -- the one
valgrind called *"Invalid read of size 4 ... 8 bytes after a block of size 264"* -- **and nothing
detects it.** A reader who asks whether the clamp is behaviourally covered will find five green
rows and conclude V24 is belt-and-braces; it is not. This is the dual of the defect 0619 itself
was: a fence keyed to a symptom dies quietly when something else cures the symptom. Recorded in
V24's own comment in `tests/headless/test_ps_valid_1350.tcl` as well as here, because the row is
what a future reader has in front of them.

**Fences added:** rows **V28** (behavioural: a `-d 1` export asks `set_ps_colors()` for no index
that is not a layer, with an instrument-liveness clause so a dead probe cannot pass) and **V29**
(static: both pops are symmetric with their pushes, each asserted by name, fossil spellings
asserted absent) of `tests/headless/test_ps_valid_1350.tcl`, already an `hcases` case.
Receipt: `doc/claude/issues/receipt-0619-ps-colors.md`.

**No committed golden or expected-output file embedded the garbage.** Swept: nothing under
`tests/` contains a PostScript `RGB` line at all, and the only tracked files that quote one are
issue write-ups (0454, 0615, this one). Nothing needed regenerating.

**Byte counts as an oracle, since this file warned against them:** the warning is now narrower
rather than lifted. The garbage float's text width is gone, so a PS byte count no longer moves for
that non-semantic reason -- but it still moves with page scale, translate and line width, which
depend on the display arm and the window size the throwaway HOME gives (V26's block measures 4468
differing PostScript lines between arms on one sheet). Compare **two children on the same arm**
(V22/V23 do, with no filtering at all) or compare the sorted RGB multiset (V26). Do not compare a
byte count across arms, and do not add a fourth RGB-stripping filter: three already exist because
of this defect, and if a row needs to drop a line to pass, the line is the finding.
