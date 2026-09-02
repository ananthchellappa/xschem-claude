# 1248 — the A1 suite's "A3 MUST REPLACE" tripwire runs on a fixture that cannot see the mask

Status: **open** (measured by item A1's adversary pass, re-measured by the
write-up pass; **not fixed** — the repair needs a raw fixture, which is item A3's
material) · Branch: `fluid-editing`
Related: **1244**, item A3 of `doc/claude/op_param_batch/PLAN.md`

Three coverage holes in `tests/headless/test_annot_declutter_1244.tcl`, filed
together because they share one cause: the suite proves the **mask arithmetic**
very well and the **rendering** and the **per-context write** not at all.

## 1. Rows I2 and I3 are vacuous, and I2 is a tripwire that cannot trip

Row I2 is labelled in its own source:

> `## ⚠ ITEM A3 MUST REPLACE I2 — after A3 the two exports MUST differ.`

It asserts the SVG export is byte-identical at `annot_show` 1 and 9. It is —
but so is every other pair, because the fixture is `xschem_library/examples/
nand2.sch`, which has no operating point loaded and whose eight FET symbols do
not resolve (`l_s_d(): Symbol not found: nmos4.sym` × 4, `pmos4.sym` × 4).
Measured (write-up pass, 2026-09-02, same warmed viewport export the suite uses):

```
VACUITY nand2 fixture, bytes 25405: 0=1 1=1 2=1 3=1 8=1 9=1 11=1
```

Every mask renders byte-identically to mask 0 — **including 1 vs 3**, a pair
that genuinely differ in meaning (node voltages off vs on). So rows I2 and I3
prove only that `xschem print svg` is deterministic.

The consequence is the sharp part: **item A3 can land, make text disappear
correctly, and I2 will still pass.** The row that was written to force A3 to
replace it cannot notice A3 at all.

Repair: give the row a fixture with a real raw — `test_op_annot.tcl`'s
`opa_o_mkrlraw` shape — so that mask 1 vs mask 3 differ *before* A3, which is the
non-vacuity control the row is missing. Row I3 (invariant I-C, permanent) needs
the same fixture for the same reason.

## 2. Sabotage SB5 is caught by a grep, not by behaviour — and the plan says otherwise

The plan's sabotage matrix predicts that replacing
`xschem set annot_show $new` with a bare `set ::annot_show $new` reds
`{S4 D3 D4 D5 M1 M2}`. Measured, it reds **`{S4}` only** — the source grep.
D3, D4, D5, M1 and M2 all stay **green**, because the proc's own
`catch {xschem update_all_sym_bboxes}` tail reaches `annot_show_sync_cache()`
(`src/actions.c:1368`), which pulls the Tcl var into `xctx->annot_show` one
statement after the sabotage, so every mask the suite reads back is repaired
before it is read.

So the per-context-write discipline — the thing the item's brief calls out in
capital letters — is guarded by **two source greps** (this suite's S4 and row N21
of `test_op_annot.tcl`) and by **no behavioural row anywhere**.

It is not merely cosmetic: the bare set bypasses `annot_show_set()`, so
`xctx->annot_root` is never stamped, and the declutter bit would then survive a
root-sheet change forever while its three neighbours do not (the same seam as
issue **1247**, seen from the other side).

Repair: a row that reads the mask **without** letting a sync run in between —
e.g. `xschem get annot_show` immediately after the write with no bbox pass, or a
second window/context — so that a stale mirror is visible as a wrong number
rather than only as a missing string.

## 3. The `off` arm is untested above bit 3

`cadence::annot_declutter off` is `expr {$mask & ~8}`. Row M2 exercises it only
at masks 7 and 15, so a `& 7` typo — which would also clear **every** bit above
bit 3 — passes every row in the suite. Nothing above bit 3 exists yet, which is
exactly why this will be discovered by a future bit and not by this suite.

Repair: one row at a mask with a high bit set (e.g. 24), asserting `off` clears
bit 3 and leaves the rest.

## Why none of it was fixed in A1

Hole 1 needs a raw fixture, which is item A3's material and would have A1 build
half of A3's test scaffolding on a guess about A3's rung. Holes 2 and 3 are
cheap, but both change what the item's own suite asserts *after* its verification
passes had signed off on it, and the batch's rule is that a discovered defect is
filed, never fixed silently. **Item A3 should fix hole 1 as part of replacing row
I2** — it is the same edit.

## Addendum (item A2's implement pass, 2026-09-02): the name rows share hole 1

Item A2's section N rows **N5–N8** — the ones that prove `annot_name_token()`
compares against all three shipped spellings, whole-string, and is applied
outside the `annot_class_free()` gate — are **structural**, read out of the C
source with a function-body slicer, and they say so in their own comments. They
have to be: `xText.flags` is not observable from Tcl at all (`xschem get
text_flags` does not even raise — it returns the empty string through the generic
`get` fall-through), `src/scheduler.c` reads `text[i].flags` only for
`TEXT_FLOATER` and never exposes `text_hidden`, and adding a reflection accessor
means editing a file item A2 does not own. Row **N10** is labelled `A3 MUST
REPLACE THIS ROW` for the same reason this issue's hole 1 is: the honest
behavioural proof needs a raw fixture in `test_op_annot.tcl`'s `opa_o_mkrlraw`
shape. A2's *behavioural* rows (**N11–N14**) are all negative — "nothing moved" —
and were additionally checked cross-binary: the warmed SVG export and the
round-trip `.sch` are byte-identical to the pre-A2 binary's, not merely
self-consistent across masks.

A2 did fix the vacuous-fixture half for its own rows: section N brings
`xschem_libs_newsym/examples/cmos_inv/schematic/cmos_inv.sch`, which loads
cleanly under `src/cadence_style_rc` (14 instances) and renders all three name
spellings plus two parameter texts on one sheet. **Rows I2/I3 were deliberately
left alone** — replacing them is item A3's, per this issue. A3 closes both.
