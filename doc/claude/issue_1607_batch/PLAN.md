# Issue 1607 — closing the three items the hierarchical-PDF port left open

Issue: `doc/claude/issues/1607-a-heap-over-read-makes-headless-postscript-export-non-deterministic.md`
Related: **1353** (the same defect under its psprint number; the comment block above
`set_ps_colors()` in `src/psprint.c` is its write-up), **1606** (same class, different
mechanism), **1603** (the other issue the port partly closed).

`dc23e730` closed item 1 — the `psprint.c` half — with one line in `set_ps_colors()`:
`if(pixel >= (unsigned int)cadlayers) return;`, i.e. emit no colour for the pseudo-layer
the text pass runs at. Measured: 6 distinct md5s in 9 headless runs became 1, and 144
out-of-gamut `RGB` components became 0.

Three items stayed open. This batch closes them.

---

## Stage A — item 2: does `svgdraw.c` have the defect, or only the shape?

The issue says `svg_colors` at `:1138` and `svg_draw_symbol(c + 1, …)` at `:1301` are
"the same shape", that no measurement was taken there, and that five runs of
`xschem print svg` produced one md5 and zero out-of-range components — so the
consequence did **not** reproduce.

**The question is not "should we add the same `if`".** It is whether there is a reachable
out-of-bounds read at all. Answering it with a defensive patch would leave the issue open
in substance: nobody would know whether the SVG path had ever been wrong.

Deliverable: a verdict backed by valgrind on both display arms **and** a call-path trace,
then either the minimal patch or the sentence that records the path as proven safe.

## Stage B — item 4: is the display path clean, or only repeatable?

The issue is explicit that the two agreeing `:160` runs proved determinism and not
correctness: the same over-read happened with a display and may simply have been reading
a stable value.

Deliverable: valgrind on the display arm with the guard **reverted** in a scratch clone,
and a page-by-page raster comparison of reverted vs patched output there. That last
comparison is also the test of the claim the `psprint.c` comment makes — that the restore
is redundant because every drawing site sets its own colour first.

## Stage C — item 3: coverage for the headless export path

`test_ps_valid_1350.tcl` already carries the colour rows (`V19`, `V20` — no RGB channel
outside 0..1, `V20` across the whole corpus) and `V14` — every sheet distils with exit 0
and empty stderr. So item 3 is smaller than its wording, and two real gaps remain:

1. **Determinism is not asserted anywhere.** It is the property 1607 is *about* — "the same
   schematic exported twice headless produces two different files" — and in-gamut colour is
   a consequence of the fix, not the property. A row that hashes N exports of one sheet
   reddens on any future reintroduction, including one that reads garbage that happens to
   land in gamut.
2. **The SVG export path has no coverage at all**, which is exactly why 1607's SVG half
   could only ever be "unmeasured".

Deliverable: rows in the suite that already owns this code, reusing its helpers.

---

## What is NOT in scope

- Issue **1603**'s other 26 null-`type` sites. Adjacent, separately filed, separately owned.
- Turning `ps_hier_nav` on. That waits on a human opening a PDF in a real viewer; there is
  no viewer on this machine.
