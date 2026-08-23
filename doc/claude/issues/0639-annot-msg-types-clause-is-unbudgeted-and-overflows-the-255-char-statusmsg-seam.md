# 0639 — `_annot_msg`'s types clause is unbudgeted and overflows the 255-char statusmsg seam

Status: **OPEN — measured, not fixed. PRE-EXISTING** (not introduced by any recent
step). Filed by the 0617+0618 crew, 2026-08-23. Related: **0617**, 0614.

## The seam

`xschem get statusmsg` reads `xctx->statusmsg_text[256]` (`xschem.h:1653`) and
**truncates at 255 characters**. Measured: sent 300, read back 255.

## The defect

`cadence::_annot_msg` (`utils/annot_mode.tcl:227`) appends a "no OP descriptor for
symbol type(s): ..." clause listing up to four symbol type names. It clips the *list*
at four entries but never budgets the *line*. Measured by exhaustive enumeration over
4 masks × 8 states × 3 causes × 4 type-lists × 3 paths: **81 combinations exceed 255
characters, worst case 351.** The current shipped worst case with no new clause is
**241** — 14 characters of headroom.

This is not synthetic. A shipped ASE testbench sheet carrying four
`xschem_library/analyses/*.sym` symbols (`netlist_command_analysis_acstb`,
`_dcinc`, `_noise`, `_tran` — 29-30 chars each) produces it:

```
OLD(len 314) as the user saw it (C truncates at 255):
  |... -- NO RAW FILE: /home/analog/dev/xschem-claude/sky130_tests/simulations/
   tb_bandgap/tb_bandgap_ase.raw -- no OP descriptor for symbol type(s):
   netlist_command_analysis_acstb netlist_command_analysis_dcinc n|
```

The line dies mid-token. Whatever the user most needed is whatever happened to be last.

## The choice nobody has made

The 0617 attempt budgeted the **path** (full → basename → ellipsised → empty) so the
new sentence would fit, which changed the pinned case-(a) message from a full path to
a basename. That attempt was reverted, so the shipped behaviour is again "clip the
type list at 255, keep the full path".

**Neither is obviously right, and it is a user-visible choice**: is the raw's directory
or the list of unrecognised symbol types the thing worth keeping when the line will not
fit? A third option is to stop treating 255 as a wall — raise `statusmsg_text[256]` in
C — but that is a rebuild plus a mirrored-field edit for a display-layer problem.

## Recommended

Decide it as part of 0617's retry (which must fit a new sentence into the same line
and therefore cannot avoid the question), and record the ruling. Until then, note that
`_annot_path`-style path shortening is **not** a free win: it silently rewrites a
message the 0617 brief explicitly pinned as unchanged.
