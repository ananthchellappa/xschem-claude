# 1248 — the A1 suite's "A3 MUST REPLACE" tripwire runs on a fixture that cannot see the mask

Status: **FIXED** by item A3, 2026-09-02 (holes 1 and 2; hole 3 see below) ·
Branch: `fluid-editing`
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

---

## FIXED by item A3, 2026-09-02

**BEFORE** — item A3's measure agent re-measured hole 1 independently rather than
trusting this file. On row I2's `nand2.sch` fixture **every** mask exports
byte-identically:

```
=== 1248: row I2's fixture cannot see the mask (re-measured independently) ===
instances=14  texts=0
   mask 0 vs mask 0 : 1   bytes 5882
   mask 1 vs mask 0 : 1   bytes 5882
   mask 2 vs mask 0 : 1   bytes 5882
   mask 3 vs mask 0 : 1   bytes 5882
   mask 8 vs mask 0 : 1   bytes 5882
   mask 9 vs mask 0 : 1   bytes 5882
   mask 11 vs mask 0 : 1   bytes 5882
   mask 1 vs mask 3 : 1   <- 1=OP only, 3=OP+node voltages
```

**including `1` vs `3`**, a pair that genuinely differ in meaning. The tripwire
could not trip.

**ONE CORRECTION to this file's original text, measured:** the eight
"Symbol not found" lines appear only when `src/cadence_style_rc` has been sourced;
a *fresh* load of `nand2.sch` resolves all 14 instances. The fixture's blindness is
a library-path artefact of the suite's own preamble, not a property of `nand2.sch`.

**AFTER** — the three rows were replaced **in place**, against a live fixture
(`cmos_inv.sch` + a hand-written OP raw + a descriptor registered on types
`nmos`/`pmos`), and the suite grew from **52 to 82 checks**:

| row | before | after |
|---|---|---|
| **I2** | `A3 MUST REPLACE THIS ROW` — SVG at mask 1 == mask 9, on a blind fixture | `SUPERSEDED BY ROW A3` — now the D-6 control |
| **I3** | invariant I-C on the same blind fixture | rebuilt on the live fixture (row **A5**), PERMANENT |
| **N10** | `text_hidden names no NAME bit` | `REPLACED BY A3: the two-argument entry is a pure delegate` |
| **N14** | `1249 PINNED` `{1 1 1 0 0}` | `1249 FIXED (was PINNED)` `{1 1 1 1 1}` |

The non-vacuity control this file asked for exists: row **A4** asserts that on the
new fixture mask 1 and mask 3 **already differ** before the rung matters, and row
**A2** asserts that every string row A1 claims absent at mask 9 is **present** at
mask 1.

**Hole 2 (sabotage SB5 caught by a source grep and by no behavioural row) is
closed**: rows **A1/A3/A10/A12/A14/A15/A27** are behavioural and item A3's
sabotage pass reds seven of them on a dead rung. **Hole 3 (the `off` arm untested
above bit 3) is closed** by rows **A5** and **A16**, both PERMANENT: with
`ANNOT_SHOW_OP` clear, the declutter bit moves neither a byte of SVG nor a
bounding box, swept over four mask pairs (0/8, 2/10, 4/12, 6/14).

### Still open, from item A3's own sabotage pass — now filed as **1254**

Row **A17** ("hide_symbols=2 closes the D-6 gate") **did not fire** under the
`SB-GATE-ALWAYS` variant. It compares the mask-1 and mask-9 renders at
`hide_symbols=2` and asserts they are identical — but at that setting the
keep-name filter has already reduced both to names only, so the rung has nothing
left to remove and the row is identical either way. It cannot detect that the gate
stopped honouring `hide_symbols`, which is the one thing its name claims. To bite,
A17 needs a text the keep-name filter keeps and the rung would hide, or it should
assert the gate directly rather than through a doubly-filtered render.

That hole, and a second one item A3's sabotage pass found (the new
`src/scheduler.c` overlay-sync line is guarded by no row at all), are filed
together as issue **1254**.
