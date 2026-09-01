# 0808 — Y5 / L22 / L24 claim to pin the 0688 load_schematic seam, and do not

Status: OPEN (measured, not fixed)
Filed by: the 0688+0683 crew's Verify-B (sabotage) agent, 2026-08-25
Subject: tests/headless/test_op_annot.tcl row Y5; tests/headless/test_ase_launch.tcl rows L22, L24
Related: 0688 (the lifetime fix these rows guard)

## 1. The claim

Issue 0688's fix has TWO call sites for `annot_show_check_root()`:

  * `src/save.c` load_schematic() tail — "THE DETERMINISTIC SEAM", so that
    `xschem get annot_show` reads 0 the instant a `File > Open` returns, with no
    bulk evaluation in between;
  * `src/actions.c` annot_show_sync_cache() — "THE BACKSTOP", for root changes
    that never run load_schematic().

Row Y5's own header states the first of those is what it pins:

> ⚠ THE 0688 DEFECT ITSELF, AND THE SEAM IT PINS. Read with NO bulk eval in
> between: `xschem get annot_show` must already answer 0 the instant the load
> returns. A fix that only rode `annot_show_sync_cache()` would leave the mask
> at 3 for every reader until the next `update_all_sym_bboxes`, and the ASE-L
> menu PULL half (N22c) reads it exactly that way.

The plan's own words for the same row: "it pins the load_schematic seam rather
than the lazy sync". The sabotage variant SAB-C was written to prove exactly
that, predicting Y5, L22 and L24 red.

## 2. The measurement

SAB-C, applied to the shipped patch on branch `annotate`: a live no-op
`annot_show_check_root_noop()` added in src/actions.c, and ONLY the src/save.c
call site re-pointed at it. Full rebuild. The actions.c backstop left intact.

    test_op_annot   (--nogui)        1 FAILED (348 passed)   -> Y11 only
    test_ase_launch (--nogui)        ALL PASS (28 checks)
    test_annot_show_menu (:99)       ALL PASS (22 checks)

**Y5, L22 and L24 all stayed GREEN with the seam gone.** The only row that
noticed was Y11, a source-text grep row (`annot_show_check_root(` must appear
exactly 3 times across src/*.c) — a shape row, not a behavioural one. Delete the
seam and adjust Y11's count and the whole suite is green over a fix with one of
its two mechanisms removed.

## 3. Why

`xschem load` reaches `calc_drawing_bbox()` (src/actions.c:4983) on its way
through zoom/redraw, and that function's third statement is

    annot_show_sync_cache();          /* src/actions.c:4994 */

so the backstop fires INSIDE the load, before the load command returns, even
under `--nogui`. The "no bulk eval in between" that Y5 is written around is not
actually absent: the load performs one itself.

The sync sites are src/actions.c:4994 (calc_drawing_bbox), src/draw.c:10509,
src/svgdraw.c:1101, src/psprint.c:1377, src/scheduler.c:9838, :13742,
src/xinit.c:3846, :3976.

## 4. What this does NOT say

It does not say the save.c seam is wrong or should be removed — belt and braces
is fine, and there may well be a load path that never draws (`no_draw` set, a
load raised before the bbox pass) where only the seam saves the invariant. It
says the SUITE does not distinguish the two, while three rows and a plan cell
assert that it does.

## 5. What would fix it

A row that reaches a load which provably does not run calc_drawing_bbox — the
obvious candidate is a load performed with `xschem set no_draw 1` around it, or
a load that raises — and asserts `xschem get annot_show` is 0 immediately after.
If no such path exists, the honest repair is to DELETE the three claims from the
row comments and from the spec, and say plainly that the sync-cache backstop is
what does the work and the save.c call is redundant defence.

Either way the current comments are a claim the suite cannot cash, which is the
"green over a mechanism nobody tests" class this project has shipped before.

## 6. A second, smaller instance in the same suite: Y1 passes off a stale Tcl var

Same sabotage loop, variant SAB-D (`annot_show_set()` — THE one C writer —
replaced by a live empty body, real body renamed `annot_show_set_real`, rebuilt).
55 of test_op_annot's rows went red, as intended. Row Y1 was PREDICTED red and
stayed GREEN:

    ok:   Y1 KEEP a same-path `xschem load` leaves the mask alone

Y1 does `xschem load $Y_A` ; `xschem set annot_show 1` ; `xschem load $Y_A` and
asserts `xschem get annot_show` == 1. With the setter dead, that `set` writes
nothing — yet the row still read 1, because `annot_show_sync_cache()` pulls from
the Tcl var `::annot_show`, which an earlier row in the same process had left at
a non-zero value. The immediately preceding row Y0 measured this directly: its
mask-0 width came back 78 instead of 0, i.e. the mask was never actually 0.

So Y1 is satisfied by the ambient value rather than by anything it set. The
repair is one line: assert the PRE value too, e.g.

    check {Y1 ...} [list [xschem get annot_show] ...] {1 ...}

after the `set` and before the reload, so a dead setter cannot be mistaken for a
successful KEEP. Y2 and Y3 chain off Y1's state and inherit the same weakness.
