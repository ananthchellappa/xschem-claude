# 0321 — `Descend to here` refuses the device node that Ctrl-Alt-V just selected

**Status:** OPEN, LOW. Not a regression — the row has always been unreachable in
that direction. What changed is that issue **0319**'s fix makes it the row the
user is *standing on*, so a gesture that used to be unreachable is now one
right-click away.
**Area:** `src/wave_viewer.tcl` — `wviewer::hier_resolve` (the browser → schematic
direction), used by `browser_target_path` / `browser_descend_to` / `hier_walk`.
**Found:** 2026-08-12, by an adversarial reviewer during issue 0319's fix
(finding A-6). Recorded rather than fixed, per that task's rule about widening.
**Related:** 0319 (the forward direction, FIXED), 0217 (the declass rule), 0212
(`hier_resolve`'s `VECTOR` sentinel — the precedent for refusing a segment it
cannot honestly resolve).

## What happens

After 0319, Ctrl-Alt-V on a FET called `M18` correctly selects the browser tree
row **`x1 > x1 > xm18`** — the raw's own spelling of that device. Right-click
that row and choose **Descend to here** (or double-click it, item 11's path):

* `browser_target_path` hands `hier_walk` the path `x1.x1.xm18`;
* `hier_walk` step 3 calls `wviewer::hier_resolve xm18`, which scans the
  schematic's instances exact-first then `-nocase` (`wave_viewer.tcl:10733-10746`)
  and finds neither `xm18` nor `XM18` — the schematic calls it `M18`;
* the walk fails, rolls back, and reports that it cannot resolve `xm18`.

## Why this is mostly correct, and only mostly

Descending into a **primitive** is not a thing xschem can do: a FET has no
schematic to descend into, and `descend -inst` on a non-subcircuit already
answers the string `0` without moving (measured, and noted at
`wave_viewer.tcl:10770`). So the refusal is the right OUTCOME.

What is wrong is the REASON the user is given. They are told the node cannot be
resolved, when the truth is "that is a device, not a subcircuit — there is
nothing below it". Those are different sentences with different remedies, which
is exactly the distinction `browser_msg`'s eleven kinds exist to preserve.

## The asymmetry, stated plainly

0319 taught the FORWARD direction the netlister's spelling
(`ase::inst_path_segment` → `@spiceprefix@name`). The REVERSE direction has no
such rule, so the two no longer agree about what a device is called:

| direction | schematic | raw / tree |
|---|---|---|
| forward (`ase::show_in_browser_for_current`) | `M18` | asks for `XM18`, lands on `xm18` ✔ |
| reverse (`hier_resolve`) | looks for `xm18`/`XM18` | the schematic has `M18` ✘ |

## Candidate fixes, none chosen

1. **Symmetry.** Have `hier_resolve` compare `ase::spice_seg_name`'s answer for
   each candidate instance against the segment — the same authority, not a
   guess. ⚠ This is NOT the `x`-prefix guess that 0319 forbids and that
   `BN32`/`S16` red; it consults the netlister rather than inventing a letter.
   It would let the walk identify `xm18` as `M18` and then refuse it *for the
   right reason*.
2. **A better sentence only.** Detect that the row is a device-class node (0217
   already classifies it) and say so, without teaching the resolver anything.
3. **Do nothing.** The refusal is already correct; only the wording is poor.

## What is NOT in question

The forward fix. `BN32` in `tests/headless/test_wave_sigbrowser_0319.tcl` is the
tombstone for "fix this in the resolver by guessing an `x`", and it must keep
reding for that mutation whatever is done here.
