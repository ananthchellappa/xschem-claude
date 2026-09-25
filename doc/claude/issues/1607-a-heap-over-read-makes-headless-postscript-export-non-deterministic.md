# 1607 — a heap over-read makes headless PostScript export non-deterministic

**STAMP:** `v1 claim=fixed tree=cff55068 stamped=2026-09-24 fix=taken open=0 by=driver`

**Status: CLOSED 2026-09-24** — all four items answered and measured, batch
`doc/claude/issue_1607_batch/`. The `psprint.c` defect is fixed on **both** display arms
(`0` valgrind errors on all four combinations of verb × arm, `0` out-of-gamut components,
`1` md5 in 9 runs on every arm); `svgdraw.c` has the call shape and **not** the defect, and
the four clamps that keep it that way are now fenced statically by row `V27`; the display arm
was shown to have been reading garbage all along rather than being clean; and item 3's
"golden" was answered with rows `V22`–`V27` instead, for two measured reasons a golden could
not survive. `tests/headless/test_ps_valid_1350.tcl` went from 21 checks to 27.

**Filed 2026-09-22** by the driver, from the headless-crashes batch's fix
round, which verified it, measured it, and deliberately did not fix it
(`doc/claude/headless_crashes_batch/receipts/A-verify.md` §2.1).
**Class** memory safety — a read one element past a heap array, whose value then reaches
the exported file.
**Related:** **1606** (an unbounded `sprintf` on `ev_precision`; same class of defect, a
different mechanism) and **1492**/**1493** (the no-display crash class this was found
beside and is **not** a member of).

---

## The defect — MEASURED

`create_ps()` in `src/psprint.c` allocates the colour table with

```c
my_calloc(_ALLOC_ID_, cadlayers, sizeof(Ps_color))
```

and then, for the text pseudo-layer, calls `ps_draw_symbol(c + 1, i, c + 1, …)` while
`c == cadlayers - 1`. Inside that call, `if(textlayer != c) set_ps_colors(c);` indexes
**`ps_colors[cadlayers]`** — one past the end.

The value read is whatever the heap holds there, and it goes straight into the output.

## What it costs — MEASURED by the fix round

Three headless PostScript exports of the **same** file
(`xschem_library/examples/LCC_instances.sch`), on the same binary:

```
md5 6e2a450a1ddb32fa0f4670030ebd6960
md5 2e1a4f414c8634b6ee4072122515a860
md5 5aa22645acd20a85521c5634fcad028c
```

Three different files. Each one carries **144 `… RGB` lines with a component greater than
1**, and the PostScript colour gamut is 0..1.

With a display (`:160`), twice: `8a4a4dc3a34b9d0c1d8e0e7cea0927c7` both times, and **zero**
out-of-gamut components. So the corruption is specific to the no-display path, where the
allocation's neighbourhood differs.

**Non-determinism is the part that matters.** `xschem -p` / `--pdf` is how a design leaves
this program for a document, and today the same schematic exported twice headless produces
two different files.

## `svgdraw.c` carries the identical idiom — READ, not measured

`svg_colors` at `:1138` and `svg_draw_symbol(c + 1, …)` at `:1301` are the same shape. **No
measurement was taken there**, so this issue asserts the code shape and not the
consequence. Anyone fixing `psprint.c` should measure the SVG path rather than assume it
behaves the same way.

### MEASURED 2026-09-24 — the SVG path has the shape and NOT the defect

Receipt: `doc/claude/issue_1607_batch/receipts/A-svgdraw.md`. **Eight valgrind runs of
`xschem print svg`, every one `ERROR SUMMARY: 0 errors from 0 contexts`** — three shipped
sheets headless, the same three on `:99`, a five-pass adversarial sweep (`hide_symbols=2`,
every net hilighted, a custom-RGB `net_hilight_style` with `color_layer < 0`, `lvs_ignore=1`,
`color_ps=0`), and one pass with the Tcl `$svg_colors` list truncated from 22 elements to 3
while `cadlayers` stayed 22. Zero `Invalid read` lines anywhere. 9 runs give 1 md5.

**The instrument was proved sharp rather than assumed.** In a scratch clone the one-line 1353
guard was deleted from `set_ps_colors()` and the identical valgrind spelling on the identical
sheet reported `432 errors from 3 contexts`, *"8 bytes after a block of size 264"*, stack
`set_ps_colors ← ps_draw_symbol ← create_ps ← ps_draw`. So this invocation, sheet, arm and
build configuration **do** catch this defect class when it is present.

**Why the shape is not the defect, which is the part this issue got wrong.** The two back ends
differ structurally, and the difference is the whole answer:

* **PostScript colour is sticky graphics state.** `set_ps_colors(pixel)` emits an `RGB`
  operator that persists, so the text passes must put the previous colour **back** —
  `psprint.c` `if(textlayer != c) set_ps_colors(c)` and `if(plw != c) set_ps_colors(c)`,
  where `c == cadlayers` in the pseudo-layer pass. **That restore is the over-read.**
* **SVG colour is emitted once, per layer, into a CSS stylesheet** looped over `i` in
  `[0, cadlayers)`; every element then carries only `class="lN"`. `svgdraw.c` has **no
  analogue of `set_ps_colors()` at all** and no restore call —
  `/usr/bin/grep -n '!= c)' src/svgdraw.c` returns nothing. The `svg_draw_symbol(c + 1, …)`
  call is byte-for-byte psprint's shape; **the sink it fed in psprint does not exist here.**
* The one per-object read, `svg_colors[layer]` in `svg_draw_string_line()`, has **no local
  bounds test** — but all four callers clamp `layer` immediately above with
  `if(x < 0 || x >= cadlayers) x = <a real layer>`, and `svg_draw_symbol()` jumps past the
  whole geometry section with `if(layer == cadlayers) goto draw_texts;`. In that pass
  `c == layer`, so `c_for_text` takes `TEXTLAYER` or `TEXTWIRELAYER` — both real layers.

So **the consequence did not reproduce because four explicit clamps prevent it, not by luck** —
a different and stronger statement than "unmeasured, not clean". Those clamps are now what the
file depends on, so `svgdraw.c` carries a comment saying so and row **V27** fences them.

### ⚠ A correction to the paragraph above, from the sabotage round

**Do not cite "valgrind clean" as though it would have caught an arbitrary out-of-range layer.**
The sabotage crew deleted one clamp and forced a symbol text past `cadlayers`, and measured
three things that qualify the eight clean runs:

* **The over-read is real and gives psprint's exact signature when it is reachable.** With the
  schematic-own-text clamp removed instead, valgrind reported `3 contexts`, `Invalid read of
  size 4`, *"0 / 4 / 8 bytes after a block of size 264"* at `svg_draw_string ← svg_draw` — the
  same shape as the reverted `psprint.c` guard. So the clamps are load-bearing, not decoration.
* **Valgrind is only a reliable instrument when the index is exactly `cadlayers`**, where the
  address lands in the allocator redzone. At a far index (99) it falls inside unrelated live or
  freed blocks, which valgrind considers addressable, and it was **silent in 3 runs out of 4**.
* **The observable consequence is decided by heap layout.** One extra environment variable of
  **one byte** flipped the malformed colour on and off (`pad=0` green, `pad=1` red, `pad=10`
  green, `pad=100` red).

The eight clean runs are still evidence — they were taken against clamped code, which produces
no out-of-range index at all — but **the verdict rests on the four clamps dominating every read,
not on the valgrind zero.** That is why the fence for them is static (`V27`) and not behavioural.

### The clamp fence needed scoping, because a dead copy of one clamp stands in for the live one

Worth recording, because the obvious implementation of `V27` is wrong. `svgdraw.c` contains a
**`#if 0` region** — the disabled "determine used layers" walk in `svg_draw()` — and inside it is
a **byte-for-byte copy of the fourth clamp, double space included**:

```
  *       if(textlayer < 0 ||  textlayer >= cadlayers) textlayer = TEXTLAYER;   <- #if 0, DEAD
          if(textlayer < 0 ||  textlayer >= cadlayers) textlayer = TEXTLAYER;   <- LIVE
```

Measured: a whole-file regexp for that clamp is **green on a copy whose live clamp has been
deleted** — the dead copy satisfies it. So `V27` strips comments and `#if 0` regions before
matching, using a depth-counting `#if`/`#endif` scan rather than a non-greedy regexp so a future
nested `#if` cannot end the strip early. Two more controls decided its shape: a single-space
regexp for that clamp is **red on the file as shipped** (the double space is real), so the
matcher collapses whitespace and joins tokens with an *optional* space; and a row asserting "four
clamps are present" is **green** on a copy with one clamp deleted and an unrelated one added
elsewhere, so `V27` asserts each of the four **by name** and the only count it checks is the
length of its own table — which stops a silently shortened table from making the row vacuously
true.

⚠ **A range row is impossible for SVG and this is why V25 is a *shape* row.** `svgdraw.c`
emits `#%02x%02x%02x`, so garbage that fits in a byte is a syntactically valid colour and
invisible to any gamut check. What is detectable is a value **> 255** — `Svg_color`'s members
are `int`, unlike `Ps_color`'s `unsigned int` — which emits more than two hex digits and breaks
the `#rrggbb` shape. Measured: **0** malformed tokens, both arms.

⚠ **Found in passing, not this defect:** `svg_draw()` leaks `svg_colors` (264 bytes) on its two
`fopen`-failure returns, which skip the `my_free` at the end of the function. A leak on an
unwritable plotfile — no out-of-bounds read, no use-after-free. Unfiled; fold it into the next
visit to this file.

## Why the fix round did not fix it

Stated in its own words, and the reasoning is sound enough to keep:

* It is **not a `display` dereference** and not that batch's class — the verifier that
  found it said so itself.
* **Every repair changes the exported bytes in 144 places**, on a path with **no golden
  file and no suite**. Allocating `cadlayers + 1` and bounding the read are both plausible
  and they do not produce the same output. That needs its own measurement and its own
  issue, not a fix smuggled into a crash-guard commit.

## PARTIALLY FIXED 2026-09-24 in `dc23e730` — the `psprint.c` half, MEASURED

The hierarchical-PDF port from the `op-wcard` branch carries a repair for this site, and
the determinism it buys was measured rather than argued. `LCC_instances.sch`, nine runs of
each verb on one binary, `--nogui`:

| | `xschem print ps` | `xschem hier_psprint` | out-of-gamut `RGB` lines |
|---|---|---|---|
| before | **6 distinct md5s / 9 runs** | **6 distinct / 9** | **144**, in 4 of the 9 runs |
| after | **1 md5 / 9** | **1 md5 / 9** | **0 in all 9** |

144 is exactly the figure recorded above, and it varied run to run exactly as this issue
said it would.

⚠ **The repair is a THIRD answer to item 1, not either of the two this issue named.**
`set_ps_colors()` gained `if(pixel >= (unsigned int)cadlayers) return;` — so the text
pseudo-layer gets **no colour emitted at all**, rather than a zeroed entry or the last real
layer's. That is defensible here because every drawing site sets its own colour first, which
makes the restore redundant — but it is a decision this issue did not anticipate and it is
recorded as one.

**`svgdraw.c` remains untouched**, and its consequence did **not** reproduce: five runs of
`xschem print svg` on `LCC_instances.sch` with the patched binary gave one md5 and zero
out-of-range `rgb()` components. So the code shape this issue flags there is real and its
effect is unobserved — which is a different statement from "it is fine", and the next person
should treat it as unmeasured rather than clean.

## ITEM 4 ANSWERED 2026-09-24 — the display path was NOT clean, it was lucky

Receipt: `doc/claude/issue_1607_batch/receipts/B-display-arm.md`. This issue's own suspicion
was right, and the reading that the display arm was fine was too comfortable. A clone with
**exactly one line reverted** (the guard in `set_ps_colors()`; `git diff --stat` = 1 insertion,
1 deletion, the 1353 comment untouched, `config.h` byte-identical), built beside a patched
binary from the same clone, 9 runs per cell, all on `:99`:

| verb | binary | ` RGB` lines | out of gamut | distinct md5s / 9 |
|---|---|---|---|---|
| `print ps` | reverted | 445 | **144, in 9 of 9 runs** | **9 / 9** |
| `print ps` | patched | 301 | 0 in 9 of 9 | **1 / 9** |
| `hier_psprint` | reverted | 726 | 233 ×3, 89, 0, 0, 233 ×3 | **8 / 9** |
| `hier_psprint` | patched | 493 | 0 in 9 of 9 | **1 / 9** |

Valgrind on the reverted binary **with a display**: 432 errors from 3 contexts for `print ps`,
699 for `hier_psprint` — reads at `+0`/`+4`/`+8` past the 264-byte block, identical counts to
headless (432 / 3 = 144, matching the out-of-gamut line count exactly). The garbage blue
component across the nine `:99` runs was a different heap-pointer magnitude every time
(`1.29687e+07`, `3.54792e+06`, `1.2709e+07`, …), which is why nine runs give nine md5s.

**With a display this path was the WORSE of the two** — garbage in 9 of 9 runs against
headless's 4 of 9, and 9 distinct md5s against 3. The two agreeing `:160` runs recorded above
proved determinism, not correctness: they landed on the same value twice.

**And the fix changes nothing that is rendered**, which is the claim `psprint.c`'s comment
makes and which had only been measured on the headless corpus. `gs -r100`, each of the 9
reverted runs against the patched output, page by page: `print ps` 9 pages compared / **0
differing**; `hier_psprint` 27 pages / **0 differing**. Repeated in `ppmraw` because greyscale
can alias two hues: the same **36 and 0**. The textual diff is **144 lines present only in the
reverted file, all of them ` RGB`**, and none only in the patched one — the suppressed
emissions are dead colour sets and no drawing operator moves.

The patched binary is `0 errors from 0 contexts` on all four combinations of verb × arm, 0
out-of-gamut components, 1 md5 in 9 runs on every arm. **The `psprint.c` half of this issue is
closed on both arms.**

⚠ The original figure was taken on `:160`, which does not exist on this machine; this is `:99`.
`:160` was not reproduced.

## Still open

1. ~~Decide what the text pseudo-layer's colour should be.~~ **Answered in `dc23e730`, by
   a third option this issue did not list**: emit nothing. See above.
2. ~~**`svgdraw.c` is still untouched.**~~ **Answered 2026-09-24 — it has the call shape and
   not the defect**, measured with valgrind on both arms against a control that proves the
   instrument catches this class. The four clamps that keep it absent are now documented in the
   file and fenced **statically** by row **V27**. See the measured section above.
3. ~~**A golden for the headless export path.**~~ **Answered 2026-09-24, and NOT with a
   golden** — see the section below. Rows **V22**–**V26** assert the property instead.
4. ~~**Check the display path is really clean**~~ **Answered 2026-09-24: it was not clean, it
   was lucky**, and it was worse than headless. See the section above.

## Why item 3 was answered with rows and not with a golden

Item 3 asked for "a golden for the headless export path". Two measurements say a committed
golden is the wrong instrument, and both were found while looking for one
(`doc/claude/issue_1607_batch/receipts/C-suite-gap.md`):

* **Every sheet with a title block renders the schematic file's mtime.**
  `T {@time_last_modified}` in `xschem_library/devices/title.sym` put `2026-09-01 09:56:17`
  into the in-tree export and `2026-09-24 15:37:19` into a fresh clone's — the only difference
  between two otherwise identical files. A golden would redden in every fresh clone, which is
  precisely the environment CLAUDE.md says gate figures are taken in.
* **The colour tables are user preferences.** `ps_colors` derives from `light_colors` and
  `svg_colors` from `tctx::colors` / `dark_colors`, and `svg_colors` follows
  `dark_colorscheme`. A golden would pin the environment rather than the exporter.

So the property to assert is **self-consistency across runs**, which is also exactly what this
issue's headline says the defect is: *the same schematic exported twice headless produces two
different files*. That needs no golden and no filtering.

⚠ **The gap was worse than "no row existed", and this is the part worth remembering.** Three
helpers in the tree **filter out exactly the lines this issue is about** —
`ps_filter` in `test_hier_pdf_links_1333.tcl` (drops every `RGB` line; its comment says a
byte-for-byte comparison of this back end *"is impossible without dropping them"*),
`opa_l_normps` in `test_op_annot.tcl` (same, for issue 0454, whose header states *"two PS
exports of identical content are NOT byte-equal"*), and `opa_l_print2`, which adds a **warm-up
export** to *"settle issue 0454's volatile PS colour into the same slot for both sides of a
comparison"*. Had the over-read returned, every row using those would have stayed green **by
construction**. That is the mechanism by which 144 corrupted lines in every exported file went
unnoticed. Two of the three exist *because of* this defect and are now dead weight — removing
them is a small follow-on, kept separate because `ps_filter` also masks issue 1342's
`setlinewidth` garbage, which rows V11/V21 fence independently.

Also worth recording: `test_callback_argc.tcl`'s same-process double `print ps` row asserts the
two files **differ**, to prove `xschem fill_type` did display-free work. Against a
non-deterministic exporter that row could have passed with `fill_type` doing nothing at all.
`dc23e730` silently de-vacuified it.
