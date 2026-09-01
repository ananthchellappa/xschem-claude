# 0848 — an uncovered window never repaints: TWO bugs, in series

Status: **FIXED 2026-08-26.** This is the "double-click on ngspice_state1 corrupts the
schematic window with waveforms" report, chased across five sittings and finally settled
by the user's screenshot. Related: 0840, 0844, 0647, 0413.

## What the user saw, and what I kept telling them

Their screenshot shows the **design window's own canvas** — its menubar, toolbar, tab bar
(`…bandgap.sch +`) and `SNAP: 10 GRID: 20 MODE: spice` status bar all present — painted
with waveform traces. Clicking anywhere cured it.

For two rounds I read `window_report` censuses, saw two mapped toplevels, and told them
it was stacking. **A census cannot see what a canvas is painted with.** The user's own
earlier report already contained the disproof — *"I was able to drag the waveform viewer
to reveal schematic"* — but the screenshot is what forced the issue.

## The measurement that cracked it

Reproduced on `:99` with two ordinary schematic windows: load A in `.`, open a real
second window `.x1` over it holding B, then move `.x1` away and compare `.drw`'s captured
pixels against a known-good capture (fraction of differing pixels):

| state | guard armed | guard clear |
|---|---|---|
| both bugs present | 0.0263 | 0.0263 |
| only the switch fixed | 0.0263 | **0.0000** |
| both fixed | **0.0000** | **0.0000** |

An explicit `new_schematic switch .drw` + `redraw` always gave 0.0000, which is what
"clicking cures it" was.

⚠ **The middle row is the whole lesson.** The first discriminating run measured the
`pending_fullzoom` guard with the switch still broken, got 0.0263 either way, and I wrote
that the guard was *innocent* and reverted the change. It was not innocent; it was
**masked**. Two bugs in series, and fixing either alone moves nothing.

## Bug 1 — `switch_no_tcl_ctx` silently no-ops for the main window (`xinit.c`)

```c
} else if(!strcmp(what, "switch_no_tcl_ctx")) {
    if(!tabbed_interface || is_window_context(win_path)) switch_window(&window_count, win_path, 0);
}
```

`is_window_context()` returns 0 for slot 0 *by design* — its own comment says *"slot 0 is
the main window, handled by the normal paths"*. There are no normal paths on this arm,
and no `else`. The sibling `"switch"` arm has the three-way fallback this one was never
given.

The caller is `callback()`'s Expose handling — *"a temporary switch just to redraw
obscured window parts"*. When it no-ops, `callback()` carries on believing the switch
happened and repaints the **wrong context**. Caught with a `dbg` in `handle_expose`:

```
callback(): switching window context for redraw ONLY: .x1.drw --> .drw
handle_expose: ctx=.x1.drw rect=0,0 700x432 pixmap=4195304 win=4195017 size=700x453
```

The switch is announced; the repaint services `.x1` and copies `.x1`'s pixmap into `.x1`'s
window. `.drw` is never touched.

Fix: no gate. `switch_window(..., tcl_ctx=0)` already maps slot 0 to `.drw` and is exactly
the tcl-context-free swap this path wants — for tabs too, since a genuine tab shares the
`.drw` X window.

## Bug 2 — the `pending_fullzoom` guard drops Expose (`callback.c`)

```c
if(xctx->pending_fullzoom == 1) return 0; /* no switching if opening a new window */
```

The guard stops a window being opened from having its context yanked away by focus events
arriving mid-creation. That holds for `FocusIn` and `EnterNotify`. An **Expose** is a
different thing: another window saying its pixels are gone. Refusing it protects nothing
and leaves that window corrupt. Now `&& event != Expose`.

## Why it looked like the waveform viewer's fault

The viewer opens congruent with the design window (`set_geom` reads the `untitled.sch`
slot, which holds the design window's own geometry), paints its graphs there, and is then
stepped aside by `wviewer::uncover`. The design window's Expose for the freshly-vacated
region is dropped by bug 2 and misrouted by bug 1 — so the schematic canvas keeps the
viewer's waveform pixels.

**The 0840 shove made this visible.** While the viewer sat exactly on top, the design
window was fully covered and there was nothing to notice.

`wave_viewer.tcl` additionally now steps the viewer aside **before anything is painted
into it**, so no region is vacated after painting in the first place. The late shove stays
as the verification.

## Tests — `tests/headless/test_expose_repaint.tcl`, 8 checks

Reads real canvas pixels via `xwd`/`convert`/`compare`; SKIPs with a reason if any of the
three is missing, or without Tk. E2 refuses to proceed on a blank capture, because a blank
canvas compares equal to anything and would make every row pass while measuring nothing.
E5 refuses to proceed unless the covering window actually looks different.

Sabotage, all reddening **E8**: restore the Expose drop; restore the `switch_no_tcl_ctx`
gate; restore both (the shipped state the user reported).

## ⚠ WHICH X SERVER CAN SEE THIS — and why `:0` is the wrong place to check

The user, unprompted, 2026-08-26: *"the problem never shows up on WSLg (DISPLAY=:0)"*.

That is the mechanism confirming itself. **Xwayland keeps obscured window contents**, so
an uncovered window is restored by the server and the application is never asked to
repaint — neither bug can fire. Both of these are defects in the *repaint* path, so they
are invisible on any server that does the saving for you.

| display | what it is | reproduces 0848? |
|---|---|---|
| `:0` | Xwayland (WSLg) | **no** — saves obscured content |
| `$DISPLAY` | the user's VcXsrv over TCP | **yes** — this is where it was reported |
| `:99` | Xvfb, the dev display | **yes** — 0.0263 with the bugs in, 0.0000 out |

So CLAUDE.md's standing rule *"run a GUI feature's suite on :0 once before calling it
done"* is **exactly backwards for this suite**: a `:0` run is a guaranteed false green.
The suite debt was filed asking for one and has been corrected to ask for
`AUDIT_DISPLAY=$DISPLAY` instead.

This also explains the shape of the whole episode. Every automated run I did before the
screenshot was on a server that cannot show the defect, or read instruments (`window_report`
censuses) that cannot see canvas contents. The only two things that ever saw it were the
user's eyes and, once aimed correctly, a pixel capture on Xvfb.
