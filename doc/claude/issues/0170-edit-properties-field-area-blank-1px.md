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

## Lessons learned

This one took four rounds and a wrong fix before the actual defect was found. The bug
itself is two lines; the diagnosis is the part worth keeping.

### 1. Widgets present, mapped and correctly gridded ≠ visible. Measure the CONTAINER.

Every probe aimed at the children came back green — `map=1`, sensible `geo=`, sensible
`req=`, the whole tree present:

```
Label l0 {DC Voltage} map=1 86x22+26+7  req=86x22
Frame cf1 {}          map=1 456x98+2+40 req=280x98
```

Not one of those numbers is wrong. The child geometry is measured **inside** the parent's
coordinate space, so a parent clipped to 1px reports children that look perfectly healthy.
Only `Frame inner map=1 1x142+0+0 req=460x142` gave it away.

**Rule: when a widget tree exists and nothing is drawn, walk UP and measure the ancestors'
`winfo width/height` against their `reqwidth/reqheight`.** A `winfo width` far below
`reqwidth` is the signature of a clipped container. Dumping children is the natural
instinct and it is the wrong direction.

### 2. A failed local repro does NOT clear the code.

Six scripted reproductions were run — `--pipe`, real GUI, both rc files, the workarea rc,
LibMgr's own `place_symbol`, `--logdir` — and every one produced a correct form. The
conclusion drawn from that ("it's your session state") was wrong: the defect is a **race**
against canvas map timing, so it reproduces on one desktop, one cell, one open, and not the
next. Worse, the runs *did* contain the bug — they just never measured the frame that had
it, so a passing repro was actually a mis-aimed one (lesson 1 again).

**Rule: a repro that "works fine" is evidence about the repro, not about the code.** Before
concluding "cannot reproduce", check that the probe would have *detected* the reported
symptom had it been present. Here it would not have.

### 3. The non-symptom was the sharpest clue.

"Resizing the form does nothing" was reported as a dead end and is in fact the diagnosis: a
resize delivers `<Configure>` to the **canvas**, so a resize-immune bug is one where the
canvas has no handler. Anything that heals on a nudge but not on a resize is about **which
widget owns the binding**, not about painting.

**Rule: when a symptom survives an event that should have fixed it, ask which widget that
event actually goes to.** (It also ruled out the tempting WSLg repaint explanation this
tree really does have a precedent for — issue 0052, `force_window_repaint`.)

### 4. Finding *a* real bug is not evidence you found *the* bug.

Issue 0169 (`vpwl`/`ipwl` losing their PWL default to a single-backslash nested quote) was
uncovered on the way here. It is real, it was cell-specific, it hit exactly the two cells
the user named and spared the two that worked — an extremely convincing fit. It was fixed,
tested, sabotage-verified and committed, and it explained **none** of the reported symptom.

**Rule: after fixing a plausible adjacent bug, re-check it against the ACTUAL reported
symptom before closing.** "Explains why these cells differ" is not "explains why the fields
are absent". The 0169 fix stands on its own merits; it just was not this.

### 5. Probe the user's live session; a modeless dialog makes that possible.

What finally cracked it was a source-able probe run from the CIW **with the form open** —
which only works because the Edit-Properties form is modeless (issue 0009, M2). Two rounds:
the first proved the model was fine (symbol, template, namespace, tokens, widget count), the
second measured the container and nudged it. The nudge that healed it *was* the fix,
demonstrated live before a line was changed.

**Rule: when local repro and the user's report disagree, instrument THEIR process.** Ship a
probe that dumps state and then attempts escalating repairs — the repair that works names
the fix.

### 6. A GUI test that builds the widget tree by hand cannot see container geometry.

`test_vpwl` / `test_isources` had covered `slickprop::build_fields` for months and were
green throughout. They call it with `frame .tf` — a bare frame that never lives inside the
scroll canvas — so no canvas item, no `<Configure>` race, no width path at all. They assert
the widgets *exist*; the bug is that the widgets are *unusable*.

**Rule: a test that constructs the container itself has excluded the container from the
test.** For anything geometry- or visibility-shaped, drive the REAL dialog (`xschem
edit_prop`) and assert measured geometry, not widget existence. That is what the new test
does, and why sabotage now fails 7 legs where the old suite failed none.

### 7. The Tk rule this generalizes to

Driving a canvas window item's `-width` from the **item's own** `<Configure>` is a one-way
latch whenever the canvas can be narrower than the item at first configure. The width must
come from the **canvas's** `<Configure>` (`%w`), which fires again when the real size
arrives. Same applies to `-height` in a horizontally-scrolling variant. Guard the degenerate
value (`%w > 1`) so it can never pin even once.
