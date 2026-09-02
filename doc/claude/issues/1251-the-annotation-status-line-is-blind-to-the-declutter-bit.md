# 1251 — the annotation status line is blind to the declutter bit

Status: **open** (measured by item A3's write-up pass, 2026-09-02; **not fixed** —
item A3 owns neither file) · Branch: `fluid-editing`
Related: **1244**, ruling **D-8**, item **A4** of `doc/claude/op_param_batch/PLAN.md`
(which owns `utils/annot_mode.tcl`), row **V21** of `tests/headless/test_op_annot.tcl`,
row **S8** of `tests/headless/test_annot_declutter_1244.tcl`

## The defect

`cadence::_annot_msg` builds the sentence the status line shows after every
annotation key. It switches on the mask **with the top bit masked off**:

```tcl
utils/annot_mode.tcl:906:  switch -exact -- [expr {$mask & 7}] {
```

Eight arms, `0`..`7`, and not one of them can mention `ANNOT_SHOW_NOPARAM` (bit
3, value 8) because the value never reaches the switch. So mask 1 and mask 9
produce the **same** sentence:

> `Showing device operating-point values on the schematic.`

## Why this is now wrong, when it was harmless before

Item A1 added the bit and the chord; item A3 (this commit) added the rung that
reads it. Before A3 the bit moved no pixel, so a status line that ignored it was
accurate. **After A3 the bit is the difference between a FET drawing `WN/LLN/1`,
`D`, `vgs=`, `vds=` beside its name and drawing its name and the OP block
alone.** Press `6` after a `Ctrl-Alt-6` and the editor says "showing operating
point values" about a sheet from which it has just removed every parameter.

`cadence::_annot_declutter_msg` (the chord's *own* sentence, added by A1) is
correct and unaffected. The gap is only in the sentence the **other** keys write,
which is the one a user sees when they come back to the sheet later.

## Measured, 2026-09-02, on this tree

```
$ grep -n "expr {\$mask & 7}" utils/annot_mode.tcl
906:  switch -exact -- [expr {$mask & 7}] {
```

The eight arms are `0 1 2 3 4 5 6 7` and the `default` arm. Rendering AFTER item
A3, same sheet, same key, mask 1 vs mask 9 — the pixels differ and the sentence
does not:

```
mask 1 texts: ... WP/LLP/1 M2 D {vgs=- - - } {vds=- - - } - {zid =} {zgm =} WN/LLN/1 M1 D vgs=0 vds=0 ...
mask 9 texts: ... M2 - {zid =} {zgm =} M1 - {zid =} {zgm =} ...
```

## Why item A3 did not fix it (ladder L2, and it is not a free edit)

* `utils/annot_mode.tcl` is **item A4's** file per the driver's brief for A3, and
  A3's Files cell does not name it.
* Row **V21** of `tests/headless/test_op_annot.tcl` golds all eight arms
  byte-for-byte, and row **S8** of the declutter suite pins the `& 7` on purpose.
  Widening the switch from item A3 would red a row in a file A3 does not own, in
  the same commit as the draw rung, for a cosmetic gain.

**Rejected alternative:** leave the two documents disagreeing — the PLAN's A3
note 4 asks A3 to "decide whether to close that gap" and silence would have read
as a decision not taken. This file is the decision, in writing.

## Recommended repair (for item A4, or whoever next owns the file)

Keep the eight arms as the *base* sentence — they are ratified wording (0886) and
V21 golds them — and **append** one clause when bit 3 is set, so the arms
themselves are untouched and V21 keeps passing on the `& 7` part:

```tcl
if {$mask & 8} { append m " Device parameters are hidden." }
```

Then extend V21 (or add V21b) with the two-mask pair, and unpin row S8 with a
comment naming this issue. Note `cadence::_annot_fit` elides at 255 bytes
(issue **1250**), so the appended clause must be counted in that budget.
