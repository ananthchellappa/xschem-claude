# 0976 — the shipped PDK helpers still spell a device the schematic's way, not the netlist's

**Status:** FILED, NOT FIXED.
**Found:** item S4a's verification pass, 2026-08-30; the call sites confirmed
first-hand by the write-up before filing.
**Scope:** the shipped per-PDK helper files, outside `src/`. This is issue
**0965** again, in the places 0965's fix did not reach.

## What 0965 fixed, and where

Issue 0965: `op_annot::devpath` built a device name from
`xschem translate $instname @model`, which on a live descend answers from the
*parent instance's* own property, while the netlister answers from the
*enclosing symbol's template*. On `tb_bandgap` the two diverge for exactly the
instances that override a model attribute the netlister does not pass down, and
the annotation asked for two device names the deck does not contain.

The fix put one resolver, `op_annot::_model_netlist`, behind both arms of
`op_annot::devpath`. Row **NM5** asserts there is exactly ONE
`translate ... @model` call left — and is explicit that it is scoped to
`src/op_annot.tcl`.

## It is not one place tree-wide. Measured

    sky130A/sky130_procs.tcl:124:    set model [xschem translate $instname @model]
    sky130A/sky130_procs.tcl:186:  set model [xschem translate $instname @model]
    ihp-sg13g2/sg13g2_procs.tcl:375:    set model [xschem translate $instname @model]
    ihp-sg13g2/sg13g2_procs.tcl:454:  set model       [xschem translate $instname @model]
    ihp-sg13g2/sg13g2_procs.tcl:513:  set model       [xschem translate $instname @model]

Two of those are on paths a user reaches today:

* **`sky130_display_fet_params`** (`sky130_procs.tcl:181`) is the proc behind
  the shipped symbol `sky130_fd_pr/annotate_fet_params`, whose text field is
  `T {tcleval([sky130_display_fet_params @ref ])}`. Drop that symbol on a sheet
  and it builds its own `@m....` device path from `@model` at :186 — so on the
  bandgap bench it will spell `x5`/`x6` `...pfet_01v8_lvt` and find nothing,
  which is the original defect, unchanged, on a different surface.
* **`sky130_hier_sch_expand`** (`:114`, reached from `sky130_sch_expand`)
  builds the `.save` lines offered from the menu, using `@model` at :124. Same
  divergence, same two devices, and a `.save` of a name that does not exist is
  accepted silently — 0965's measured silence.

`ihp-sg13g2/sg13g2_procs.tcl` has the same shape at three sites; whether any
IHP symbol overrides a model attribute the way `passgate` does was **not**
measured, so treat that PDK as unverified rather than affected.

## Why it was left alone

`op_annot`'s fix reaches `sky130_op_devpath` (`sky130_procs.tcl:298`) because
that proc takes `model` as a **parameter** — the descriptor hands it in, and
after 0965 what it hands in is the netlist's answer. The two procs above take
no such parameter; they look the model up themselves. Changing them is a change
to a shipped PDK helper on two user-facing surfaces (a symbol that draws on the
sheet, and a menu action that writes a file), with no suite covering either,
and it is not what item S4a was scoped to.

## What would pin it

Whoever fixes it should expose the resolver so the PDK helpers can call it —
`op_annot::_model_netlist` is private today — and give each of the two sky130
surfaces a row on the bandgap bench asserting the device path it builds matches
the one the deck contains, the way row **N1** does for the annotation.

Until then, NM5's "one place" claim is true of `src/op_annot.tcl` and not of
the tree.
