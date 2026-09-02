# 1246 — `Waves > Op Annotate` hard-sets `annot_show 3`, silently clearing the declutter bit

**STUB, claimed by item A1 of `doc/claude/op_param_batch/PLAN.md` (2026-09-02).**
Measured, not fixed: A1 owns neither line. The Write-up agent expands this.

Status: **open** · Branch: `fluid-editing` · Related: 1244, RULING D-8

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
