# 1246 — `Waves > Op Annotate` hard-sets `annot_show 3`, silently clearing the declutter bit

Status: **FIXED** by item A3, 2026-09-02 (see the bottom of this file) ·
Branch: `fluid-editing` · Related: 1244, RULING D-8

## What was measured

`src/xschem.tcl:17299` and `src/xschem.tcl:17725` both do:

```tcl
xschem set annot_show 3
```

That is a **hard set**, not a bit-wise merge. Item A1 added `ANNOT_SHOW_NOPARAM 8`
(bit 3) to the same mask, so a user who has turned the schematic parameter
declutter on with `Ctrl-Alt-6` and then uses that menu item loses the declutter
**with no message at all** — the parameters come back and nothing says why.

Harmless before A1 landed (bit 3 did not exist). User-visible after it, and
more so after item A3 makes the bit actually hide text.

The neighbouring ASE-L writer is **not** affected: `src/ase_window.tcl:2939` is
`set new [expr {($cur & ~$bit) | ...}]`, bit-wise, and preserves bit 3.

## Why it is not simply "make it bit-wise"

`3` is doing two jobs on those lines: it sets bits 0 and 1 **and** clears bit 2
(the transient snapshot, issue 0868), which is deliberate — that menu item
publishes an operating point, and leaving a held transient bit armed over fresh
OP numbers is RULING D5-1's shape. The repair has to say which bits it means to
clear and which it is merely not setting, so it is a ruled change, not a
mechanical one.

## Acceptance (proposed)

* With `annot_show` = 9, invoking that menu path leaves bit 3 set.
* Bit 2 still ends clear, for the reason above.
* A row in `tests/headless/test_annot_declutter_1244.tcl` or
  `test_annot_show_menu.tcl` pins both halves.

---

## FIXED by item A3, 2026-09-02

**BEFORE**, measured by item A3's measure agent on this tree — both writers
verbatim, at the lines item A1 filed:

```
=== 1246: the two HARD SETS, verbatim (brief's line numbers CORRECT) ===
17299:         xschem set annot_show 3
17725:         xschem set annot_show 3
```

**AFTER** — both sites, the shipped bit-wise idiom from `src/ase_window.tcl:2939`
(the lines moved, because the fix and its comment are longer than the literal):

```
src/xschem.tcl:17311:  xschem set annot_show [expr {([xschem get annot_show] | 3) & ~4}]
src/xschem.tcl:17749:  xschem set annot_show [expr {([xschem get annot_show] | 3) & ~4}]
```

`xschem get annot_show`, never `$::annot_show` — the mirrored-variable trap row
N22c already pins. Bits 0 and 1 are set (which is what the menu entry promises),
bit 2 is cleared **deliberately** (the held transient snapshot, issue 0868, is
RULING D5-1's shape and this file's own text asks for it), and **bit 3 is left
alone**, which is the defect repaired. One writer per site, so the two suites'
site counts survive.

**Behaviour, read back out of the source and evaluated** (row **A24** of
`tests/headless/test_annot_declutter_1244.tcl` extracts the expression from
`src/xschem.tcl` rather than restating it):

```
0 -> 3     1 -> 3     3 -> 3     4 -> 3
8 -> 11    9 -> 11    11 -> 11   15 -> 11
```

**The two rows in files item A3 does not own were updated in the same commit,**
because as written neither could tell the two sites apart (`.` matches newline in
both regexps, so the first match after either menu label was line 17299): row
**N22b** of `tests/headless/test_op_annot.tcl` and row **B6** of
`tests/headless/test_annot_show_menu.tcl` are re-pointed at the bit-wise writer
form and each keeps its site-count element at 2. Row **A29** of the declutter
suite asserts the three documents agree. Sabotage `SB-MASK-WRITERS` (restore both
literals) reds A23, A24, A29, N22b and B6.
