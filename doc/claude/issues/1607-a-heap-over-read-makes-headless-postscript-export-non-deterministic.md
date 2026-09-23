# 1607 — a heap over-read makes headless PostScript export non-deterministic

**STAMP:** `v1 claim=open tree=2bf05781 stamped=2026-09-22 fix=untried open=4 by=driver`

**Status: OPEN — filed 2026-09-22** by the driver, from the headless-crashes batch's fix
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

## Why the fix round did not fix it

Stated in its own words, and the reasoning is sound enough to keep:

* It is **not a `display` dereference** and not that batch's class — the verifier that
  found it said so itself.
* **Every repair changes the exported bytes in 144 places**, on a path with **no golden
  file and no suite**. Allocating `cadlayers + 1` and bounding the read are both plausible
  and they do not produce the same output. That needs its own measurement and its own
  issue, not a fix smuggled into a crash-guard commit.

## Still open

1. **Decide what the text pseudo-layer's colour should be**, which is the real question
   hiding under the off-by-one. Allocating one more entry gives it whatever `my_calloc`
   zeroes to; bounding the read gives it the last real layer's colour. **They are
   different pictures**, and neither is obviously right — this is a question about what the
   exported document should look like, not about the array.
2. **Fix it, and `svgdraw.c` with it** if the measurement there agrees.
3. **A golden for the headless export path.** There is none, which is why a heap over-read
   that changes 144 lines of every file went unnoticed. ⚠ A golden cannot be committed
   until item 1 is settled, or it pins the wrong picture.
4. **Check the display path is really clean** rather than merely repeatable. The two `:160`
   runs agreeing proves determinism, not correctness; the same over-read happens there and
   may simply be reading a stable value.
