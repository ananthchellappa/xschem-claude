# 0847 — closing a schematic hands the window to the waveform viewer, and destroys the viewer

Status: **FIXED 2026-08-26.** This is the "my schematic window vanished" report the user
has been making for days, and it was never a window-manager race. Related: 0172 (which
found the neighbouring hazard and fixed the wrong half), 0647, 0840, 0844.

## Measured — the user's own session, not a reconstruction

`/tmp/Xschem.log.4`, four `window_report` censuses taken by the user at their bench.

Before the close:

```
#=   .          stack=1  normal  1110x761+3597+340  'xschem [3] - tb_bandgap.sch (read-only)'
#=   .x1        stack=4  normal  1110x761+3793+481  'Waveforms tb_bandgap (ngspice_state1)'
```

One `Ctrl-W` (== `xschem exit`) in the tb_bandgap window. After:

```
xschem new_schematic destroy .x1.drw
#=   .          stack=3  normal  1110x761+3597+340  'xschem [5] - untitled.sch (read-only)'
```

`.x1` is gone, and the **main window has become context [5]** — the viewer's buffer,
titled and read-only exactly as the viewer's was. One keystroke.

## Mechanism

`swap_tabs()` (`xinit.c`) and its non-tabbed twin `swap_windows()` both chose their swap
partner as *the first non-NULL `save_xctx[j]`, j from 1*. With a viewer open, that **is**
the viewer. So `xschem exit` on the design:

1. swapped the viewer's document into the primary window,
2. destroyed what was now the sub-window — which by then held the design,
3. left the user looking at the viewer's untitled read-only buffer, in the main window,
   with the viewer's own toplevel gone.

Issue 0172 stood one line away from this and fixed the other half. Its comment says it
plainly — *"closing the main window while a viewer is open re-homes the viewer's context
onto .drw"* — and it swaps the `wave_viewer` **brand** back so the surviving canvas is not
mis-branded. Nobody asked whether a viewer should be a swap **target** at all.

## Fix

`first_swappable_ctx()` (`xinit.c`, declared in `xschem.h`) returns the first context that
is not a waveform viewer, or −1. Both swappers use it. Both callers in `scheduler.c`'s
`exit` arm now require `wc > 0 && first_swappable_ctx() >= 0` before taking the swap path;
with only viewers open they fall through to the clear/quit arm, which blanks the closing
window and **leaves the viewer alone in its own window**.

The caller guard is not decoration. Without it `swap_tabs()` declines, the follow-up
`new_schematic("destroy", ".drw")` on the primary window is itself refused, and the
schematic the user asked to close is **still there** — Ctrl-W silently does nothing. Row
V7b is the one that says so.

## Tests — `tests/headless/test_close_with_viewer.tcl`, 12 checks

V1–V7b: with a viewer as the only other window, closing the design leaves the viewer
toplevel alive, does not brand the main window, and really does close the schematic (the
cleared buffer comes back as `untitled-1.sch`, because the viewer holds the plain
`untitled.sch` name and xschem iterates — correct, and asserted as a family).

V8–V11 are the **positive twin**: with a real second schematic open the swap still
happens. Without them, a "fix" that simply never swaps passes everything else.

Sabotage:

| variant | reds |
|---|---|
| choose the swap target ignoring the viewer brand (the shipped bug) | V5 |
| remove the caller guard in the tabbed arm | V7b |
| never swap at all (over-reach) | V10 V11 |

## ⚠ Coverage gap, stated

The suite runs with the shipped `tabbed_interface=1`, so only the **tabbed** arm is
exercised. Removing the caller guard from the **non-tabbed** arm leaves all 12 rows green.
That arm shares `first_swappable_ctx()` and is symmetric by inspection, but it is not
measured. Closing it needs a session launched with `tabbed_interface 0`, which this
harness cannot switch mid-run.

## Neighbours, green in the same batch

`test_wave_viewer` (400), `test_wave_viewer_geometry`, `test_remap_verify`,
`test_window_report` (13), `test_ciw` (50), `test_traversal_flag_leak` (11),
`test_ase_core` (173), `test_op_annot` (358), `test_reopen_readonly`,
`test_no_untitled_litter`.
