# 0445 — the sky130 prototype emitter still writes `.save …[cgso]`/`[cgdo]`, one click away

Status: OPEN. Filed by S5, fixed by neither S5 nor S3 (reverted three times).
Owner: whichever step lands the PDK-neutral save-card emitter and carrier symbol.
Related: 0429 (the measurement), the D8 ruling in sky130A/sky130_procs.tcl:340-368.

## What is wrong

D8 removed `cgso` and `cgdo` from the sky130 **descriptor** because a single
unknown model parameter suppresses the WHOLE raw on ngspice-42 while the exit
status stays 0 — silent, total waveform loss:

    ngspice-42   .save …[cgso] …[cgdo]  -> exit 0, one `checkvalid` line, NO RAW
    ngspice-46+  same cards             -> raw written, real values

The descriptor is clean. The **prototype emitter is not**:
`sky130A/sky130_procs.tcl:86-87` (`sky130_write_save_lines`) still writes both
cards by hand, and it is wired to a live menu item at :235
(`Create FET .save file`). One click still produces a .save file that destroys
the raw for every ngspice-42 user.

## Why S5 did not fix it

S5's Files cell is `src/op_annot.tcl`; it is the READ side. Deleting the
prototype emitter also destroys the acceptance oracle for four currently-green
rows in `tests/headless/test_op_annot.tcl` (P3, P19, P20, P21 diff live prototype
output) and dangles the two shipped menu items, because S3 — the PDK-neutral
emitter that would replace them — has been reverted three times (0436, 0442,
0443) and does not exist. Trading one open defect for two broken menu items and
four lost acceptance rows is the larger blast radius (decision D8 of S5).

## The fix, when the neutral emitter lands

Delete `sky130_write_save_lines` and its menu item together with
`sg13g2_write_save_lines` and its own, and repoint both menus at the neutral
emitter, which reads the descriptor and therefore cannot emit a parameter the
descriptor does not carry. Until then the two prototype emitters are the only
save-card generators in the tree and this defect ships with them.

## Interim mitigation for a 42 user

Do not use the menu item; write the cards from the descriptor, or upgrade. A 46+
user who wants the two parameters back does it in their own rc without a rebuild
(I5), as recorded in the D8 block:

    set d [op_annot::descriptor nmos]
    dict set d params [concat [dict get $d params] {{cgso cgso 1} {cgdo cgdo 1}}]
    op_annot::register nmos $d
