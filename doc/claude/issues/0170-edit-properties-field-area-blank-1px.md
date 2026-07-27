# 0170 — Edit Properties showed an EMPTY field area: the content frame was pinned to 1 pixel

Status: **FIXED** (2026-07-27)
Area: `src/property_form.tcl`, `slickprop::edit_form` — the scrollable field area's
`<Configure>` bindings (2 lines → 2 bindings)
Tests: `tests/headless/test_prop_form_field_width_0170.tcl` (12 checks, new file)
Related: 0169 (the vpwl escape bug found while chasing this — a real but *different*
defect), `doc/claude/specs/slick_property_forms.md`

## Report

> The vpulse added to devices library is working ok. The vpwl is not displaying any
> properties. … No name/value fields are displayed at all

The dialog opened with a correct header (`V1 — devices/vpwl`), Apply-to, Library/Cell/View,
Name row, checkbuttons and buttons — and a tall **empty grey area** where the property rows
belong.

## What it was NOT

Every early hypothesis was wrong, and the probes killed them one by one. Measured in the
user's own session with the form open:

```
symbol   = <devices/vpwl>
template = <name=V1 DC=0 pwl="0 0 1n 1">
cf ns    = <::vpwl>
tokens   = <name DC pwl>
inner    = 4 widgets, canvas 490x142
```

So the symbol resolved, the template parsed, the cell's companion namespace loaded, the
tokens were built, the widgets were created **and mapped**, and the canvas had been sized
to their exact height. Nothing in the form logic had failed.

## Root cause

The second probe measured the content frame itself:

```
Frame inner {} map=1  1x142+0+0  req=460x142      <- ONE PIXEL WIDE
bbox all = 0 0 1 142
```

Every field row was correctly gridded *inside a 1px-wide frame*, so all of it was clipped
away. The scrollable area is the usual canvas + inner-frame idiom:

```tcl
.dialog.fa.c create window 0 0 -anchor nw -window .dialog.fa.c.inner -tags inner
bind .dialog.fa.c.inner <Configure> {
  .dialog.fa.c configure -scrollregion [.dialog.fa.c bbox all]
  .dialog.fa.c itemconfigure inner -width [winfo width .dialog.fa.c]   ;# <- the bug
}
```

The item's width was driven from the **inner frame's** `<Configure>`. That event can arrive
while the canvas is still 1px wide (it has not been mapped/sized yet), so the handler runs
`itemconfigure inner -width 1`, which shrinks inner to 1 — **and inner never changes size
again**. No further `<Configure>` fires on it, so nothing can ever widen it back. It is a
one-way latch, and which side of the race you land on depends on map timing, which is why
`vpulse` looked fine and `vpwl` did not, and why it reproduced on the user's WSLg desktop
but not in a scripted run.

It also explains the most confusing symptom: **dragging the dialog bigger did nothing.** A
resize fires `<Configure>` on the *canvas*, which had no binding at all.

## Fix

Split the two jobs, and take the width from the authoritative source — the canvas's own
`<Configure>`, whose `%w` is the canvas's new width and which *does* fire again when the
real size arrives:

```tcl
bind .dialog.fa.c.inner <Configure> {
  .dialog.fa.c configure -scrollregion [.dialog.fa.c bbox all]
}
bind .dialog.fa.c <Configure> {
  if {%w > 1} { .dialog.fa.c itemconfigure inner -width %w }
  .dialog.fa.c configure -scrollregion [.dialog.fa.c bbox all]
}
```

The `%w > 1` guard stops it pinning in the first place; binding on the canvas means a later
resize heals it even if it somehow does. No other change — the field-building code, the
cell-customization hooks and the apply path are untouched.

`src/xschem.tcl:1676` (the net-hilight-style editor) uses the same canvas+inner idiom but
only sets `-scrollregion` from the inner `<Configure>` — it never forces the item width, so
it cannot self-pin. It is the only other instance in the tree and needs no change.

## Verification

`tests/headless/test_prop_form_field_width_0170.tcl`, 12 checks, GUI arm (skips cleanly
without a display, since the form is Tk):

1. steady state — inner is wider than 1px, tracks the canvas width, and the field entry and
   the custom PWL sub-frame have real width;
2. the mechanism, deterministically — pin the item to 1px exactly as a too-early
   `<Configure>` would, then resize the **toplevel** (what dragging the dialog edge does;
   `$canv configure -width` alone only sets a requested size the packer overrides, which is
   *why* dragging never healed it) and assert the content frame comes back;
3. structural — the canvas `<Configure>` owns the width, the inner one does not, and the
   `%w > 1` guard is present.

Sabotage: restoring the old single binding fails **7 of 12**, including `inner frame is
wider than 1px` — the original defect reproduces headlessly, not just on WSLg.

Neighbours green: `test_vpwl` 21, `test_isources` 14, `test_vpulse` 11,
`test_editprop_preserve`, `test_pin_type_edit` 19, `test_getprop_index_bounds` 8,
`test_perform_action_apply_pin_prop`.

Confirmed interactively by the user, twice: first the probe's "nudge 1" (re-issuing
`itemconfigure inner -width`) made every field appear instantly in the live session, and
then the shipped fix — the form comes up populated on a normal open (2026-07-27).
