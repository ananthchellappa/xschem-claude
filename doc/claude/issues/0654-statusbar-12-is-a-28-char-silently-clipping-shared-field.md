# 0654 — `.statusbar.12` is a ~28-character, silently clipping, shared, self-clearing field

Status: OPEN (measured, accepted as the fallback sink anyway — see "Why it was accepted")
Filed by: the 0650 crew, 2026-08-23. Discovered while building `xschem::notify`'s
third sink (issue 0650, ruling R-0653-a).

## What was measured

`$topwin.statusbar.12` (created at `src/xschem.tcl:15573` as
`label $topwin.statusbar.12 -fg red -text {}`, packed LAST at `src/xschem.tcl:14479`,
after `.statusbar.1 -fill x`) is the drawing window's red notice field. Four
properties, all measured on this box, none of them documented anywhere before now:

1. **It clips silently, at ~28–42 characters.** At `wm geometry . 1000x800` with a
   live mouse readout in `.statusbar.1`, two independent measurements on the same
   widget: 199 px allotted / first clip at char 30, and 314 px allotted / first
   clip at char 42. It gets only the leftover cavity, so the wall MOVES with
   whatever `.statusbar.1` currently holds. Tk warns about nothing.
2. **It is shared with `*BUSY*`.** `src/hilight.c:2201` writes `*BUSY*` into it.
3. **It self-clears.** `src/hilight.c:2305` clears it to `{}` UNCONDITIONALLY at
   the end of `propagate_logic()`, so a notice parked there is wiped by any
   digital propagation — and a notice can itself blank a live `*BUSY*`.
4. **It is per-toplevel.** Both C writers prefix `xctx->top_path`. A Tcl sink
   writing a bare `.statusbar.12` posts to the MAIN window while the user works in
   `.x1`. `src/xschem.tcl:14146` already ships exactly that bug for `.statusbar.7`.
   (`xschem get topwindow` returns `.` and would build `..statusbar.12`;
   `xschem get top_path` returns `""` for the main window, which is what the C
   side prefixes.)

This is issue 0639's defect class — an unbudgeted line into a fixed field — in a
field an order of magnitude smaller. 0639's wall is 255 characters; this one's is
about 29.

## Why it was accepted anyway (0650 decision D3/D4)

`xschem::notify`'s fallback sink writes here when the CIW is not visible, with the
28-character budget enforced by ONE builder (`xschem::notify_short`, invariant I1),
proved by `NT9`/`NT10` in `tests/headless/test_ase_core.tcl` and by `PS15` in
`tests/headless/test_ase_log_seam_0207.tcl` (which also asserts non-vacuity: the
SOURCE message is longer than the budget). Point 4 is handled —
`xschem::notify_statusbar` addresses `[xschem get top_path].statusbar.12`.

REJECTED as the fix for point 1: repacking `.statusbar.12` with `-side right`
AHEAD of `.statusbar.1 -fill x` so it wins its full requested width. It does remove
the wall, but it moves the `*BUSY*` indicator to the far right of the main window
and can crush the coordinate readout on a narrow window — a main-window layout
change nobody asked for, on a step whose subject was a message channel.

## What is still owed

Points 2 and 3 are NOT fixed. A notice parked in this field disappears on any
digital propagation, and the field is red for every tag. Options for a later step:
a dedicated notice segment; a `statusmsg`-style hold; or a permanent notice line in
the ASE session window (issue 0655).

---

**Addendum, 2026-08-23 (the 0650 write-up pass).** Two more measured properties of
the same field, filed separately as **0660** because they are about *notify's use*
of it rather than the field itself: it is `configure -text`, a **replace**, so
several notices in one netlist leave only the last (measured: 3 notices → only
`'ASE: netlist written'` survived); and it is created `-fg red`
(`src/xschem.tcl:15573`) with nothing changing it, so a **plain success line is
delivered to the user in the error colour**. A third, now fixed, is **0656**: a
whitespace-only notice used to blank whatever was parked here, `*BUSY*` included.
