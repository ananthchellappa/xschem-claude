# 1261 — `draw.c`'s leg of 1253 is guarded by source text, though `print png` is a real window

Status: **open** (measured first-hand by item A5's adversary pass and again by
its write-up pass, 2026-09-02; **not fixed**) · Branch: `fluid-editing`
Related: **1253** (fixed by item A5-b), **1244**, **1254**, ruling **D-1**

## The defect, in one sentence

Item A5-b's third back-end — the screen renderer, `src/draw.c` — is asserted only
by a **source-text** row (`A38`, a grep census), on the stated belief that
`draw()` has no observable seam; but `xschem print png` renders **through
`draw()`**, and a decluttered pin name is visible in the PNG's bytes.

## The belief, and why it was wrong

Item A5's report and row **A38**'s own comment say: *"draw()'s body is inside
`if(has_x)` and pin names bump no counter, so the screen leg is structural only."*
Both halves are true and the conclusion still does not follow. `print_image()`
(`src/draw.c`) is itself gated on `has_x` and then calls `draw()` directly:

```c
  draw_no_ui_decorations = 1; /* issue 0151 */
  draw();
```

and `scheduler.c`'s print arm says so in its own comment — *"png uses the screen
draw() path"*. The suite already runs under a display (`devdisplay.sh exec`), so
`has_x` is 1 and the path is reachable from a test.

## Measured, first-hand, 2026-09-02, against the A5 binary

Fixture: one instance, symbol with **only** a `@name` text, one pin
`show_pinname=true`; the twin fixture spells `show_pinname=false`. A valued raw,
a descriptor registered, and a **warm-then-real** PNG pair per mask (the suite's
own `a3_pr2` idiom). Viewport `1200 900 250 -360 460 -240` — tight enough that
the pin name clears `draw()`'s zoom cull:

```
PNG show_pinname=true  mask 1 = 12912
PNG show_pinname=true  mask 9 = 8301
PNG show_pinname=false mask 1 = 8744   (control)
PNG show_pinname=false mask 9 = 8744   (control)
```

The declutter is visible in the screen renderer's own output, and the
`show_pinname=false` twin is the non-vacuity control that the P6 pass is what is
being observed. ⚠ **A wide viewport hides it**: at the suite's usual
`2400 1600 100 -420 1000 -20` the pin name is zoom-culled at both masks and the
two PNGs are byte-identical — the first attempt at this measurement produced
exactly that false negative.

## Why this matters more than one missing row

If a later change reverts **only** `draw.c`'s `if(text_hidden_inst(0, n)) continue;`
— leaving `svgdraw.c` and `psprint.c` correct — rows **A36** and **A37** stay
green and only the grep census **A38** reds. A grep census is defeated by any
refactor that keeps the token and moves the behaviour. That is *"the suite stays
green while the feature breaks"*, the precise failure mode item **A5-d** existed
to close for two other rows.

## Why item A5 did not add the row (ladder L2, and the rejected alternative)

The window was found by the adversary pass, after the tiers, the six-variant
sabotage matrix and the full audit. **The write-up agent may not run `make`**
(crew rule 2), so a new `draw.c` row could not be *shown failing* — the deliverable
standard this very item was held to. A row added at that point would be a row
nobody had watched go red, which is what this issue is about.

**Rejected alternative:** asserting the PNG's absolute byte sizes as goldens.
They are cairo/libpng/depth dependent. The row must assert **relations**: for
`show_pinname=true`, mask 1 ≠ mask 9; for the `show_pinname=false` twin,
mask 1 == mask 9.

## The row to add, and the sabotage that must red it

* **Fixture:** as above — a symbol carrying *only* `@name` plus one
  `show_pinname=true` pin, and a twin spelling `false`; a valued raw; a tight
  viewport; `print png` warm-then-real per mask.
* **Legs:** `true` fixture mask 1 size ≠ mask 9 size; `false` fixture mask 1 ==
  mask 9; both sizes > 0.
* **Sabotage:** `SB-A5b-PINS` restricted to `draw.c` (the `text_hidden_inst_pin_off`
  shim at that one call site). It must red the new row, and **must not** red
  `A36`/`A37`.

## Still open

* Whether `xschem print png` should get a cheaper seam (a drawn-pin-name counter
  behind `xschem get`) so the row does not depend on image bytes at all. That is
  new instrumentation, not a conformance gap, and is nobody's item yet.

---

## A7 attempt, 2026-09-03 — **`[F]`, reverted. This issue stays OPEN.**
### …but the demonstration this issue asked for succeeded, and is recorded here so it is not re-derived.

Item **A7-d** replaced the grep census's draw.c claim with a behavioural row
**A38b**: on a symbol carrying only `@name` plus one `show_pinname=true` pin with
a valued raw, warm-then-real `xschem print png` at the tight viewport
`1200 900 250 -360 460 -240`, asserting mask1 ≠ mask9 with a `show_pinname=false`
twin as the non-vacuity control and PNG-magic / `> 0` legs. A38 kept its
structural legs for `svgdraw.c` / `psprint.c` / `select.c`.

**The sabotage this issue asked for was run and it worked.** `SB-A7d-PINS-TOKEN`
— `src/draw.c:975` changed to `if(0 && text_hidden_inst(0, n)) continue;`, the
refactor-shaped defect, token and grep count preserved — rebuilt:

```
sabotaged: show_pinname=true  mask1=16874 mask9=16874   (identical)
restored:  show_pinname=true  mask1=16874 mask9=15189
           show_pinname=false mask1=15561 mask9=15561
RESULT: 1 FAILED (131 passed)   -- the one red is A38b
A36 (svg), A37 (ps), A38 (the grep census, count still exactly 1): all GREEN
```

The grep row provably could not see the defect; the behavioural row could. A
coarse twin (callee replaced by a static always-0) reds A22, A38 and A38b.

**Two corrections to this issue's own text**, both re-measured: the absolute byte
sizes are nothing like the 12912/8301/8744 recorded here (assert **relations**,
as this issue itself recommends — never absolute goldens, they are
cairo/libpng/display dependent); and the warning that "a wide viewport hides it"
does **not** reproduce on this binary/display — the wide viewport works too, and
A7 reported it as a `COST|`-style line rather than asserting it.

**Residue to carry into the re-do:** A38b asserts the difference by **file
size**, and its non-vacuity twin by size **equality** — a rendering change that
preserves the compressed size passes both; cheap to strengthen to a byte compare.
And A38b/A38c are **display-arm only** (under `--nogui` `print png` writes no
file), so draw.c's behavioural guard vanishes on any headless leg.

The row and its fixture are preserved in
`doc/claude/op_param_batch/A7_working_tree_REFUTED.patch`; A7 was reverted for
its A7-a leg (issue **1270**), not for this one.

## Closed by item A7's re-do, 2026-09-03

Item **A7** implemented this, was refuted on a state nobody had named
(issue **1270** — the declutter counter counted the *rung*, not what came off
the sheet), was reverted with every line preserved as
`doc/claude/op_param_batch/A7_working_tree_REFUTED.patch`, and was re-done by
the driver: patch re-applied, the four-line repair added at A7's own edit point,
and two new suite rows (**A64**, **A65**) that catch the 1270 defect and the
tempting wrong repair, both proved by sabotage rather than asserted.

Read **1270** for the full account, including the residual risks that survive
this fix. Item A7 closes feature A of `doc/claude/op_param_batch/PLAN.md`.
