# 0843 — `Session > Design Window` can make the design window VANISH, because a dropped re-map is never checked

Status: **FIXED 2026-08-26.** Reported by the user twice on the real screen
(a Windows X server over TCP), the second time with the action-log trace of
issue 0840's instrumentation alongside it.
Related: 0054 (why the re-map idiom exists), 0616 (which records that the WM
DROPS re-maps, and the `always`/`ifhidden` trade), 0052.

## The user's report, verbatim

> This time, when I did Session > Design Window in ASE-L, the schematic editor
> window vanished (not the first time I've seen this)

## Measured — the code, and why it is the one command most likely to do this

`raise_activate_toplevel` (`src/xschem.tcl:5722`) brought a window forward with:

```tcl
if {[winfo ismapped $top]} {
    set geo [wm geometry $top]
    wm withdraw $top
    wm deiconify $top
    catch { wm geometry $top $geo }
}
```

The withdraw/deiconify pair is the WSLg idiom of issue **0054** — a plain
`raise` is an inert no-op there once a window is mapped, so the only way to
bring a window forward is to unmap and remap it.

**But issue 0616 already records, in this tree, that that window manager is
documented to DROP a re-map.** And the withdraw is not conditional on the
deiconify succeeding. `wm withdraw` always works. `wm deiconify` may not. Nothing
looked afterwards. The net effect is a window the user was looking at a moment
ago and now is not.

`Session > Design Window` passes the default `always` raise_mode **deliberately**
— `ase::ui::design_window`'s own comment says *"the Session menu item in
particular IS the user's documented recovery when a window has gone missing, so
it must keep re-mapping"*. So the one command whose entire job is to bring a
missing window **back** was the one most likely to make one **disappear**, and it
did it to a window that was already perfectly visible, where the re-map bought
nothing at all.

## Fix — verify, deferred

`_remap_verify` re-checks 150 ms later and asks again if the window is still
unmapped, up to two retries.

⚠ **Deferred, not synchronous.** `winfo ismapped` reflects Tk's view of the last
`MapNotify`, so an immediate read races the server's reply and would
false-negative on a re-map merely in flight. And an `update` here would re-enter:
this proc is called from menu commands, focus handlers and the viewer open path.
`after` is the idiom the surrounding code already uses for exactly this
(`ase_window.tcl`'s `after 120 force_window_repaint`, issue 0052).

⚠ **The recovery is deliberately dumb** — deiconify again, then `wm state
normal`. The failure being recovered from is a window manager ignoring a
request, and the only useful response to that is to ask again.

⚠ **NO RULING WAS NEEDED, and that is the point of doing it this way.** The
obvious alternative was to flip `design_window`'s default from `always` to
`ifhidden`, which would stop withdrawing visible windows — but it would also give
up bringing a *buried* window forward on WSLg, which is the open trade in rule
debt `[0616]` and is the user's to decide. Verifying the re-map keeps `always`
and removes the failure mode, so it settles this defect without pre-empting that
ruling.

## Acceptance

1. `raise_activate_toplevel` on a **mapped** toplevel leaves it mapped.
2. `raise_activate_toplevel` on a **withdrawn** toplevel still brings it back —
   the recovery case the menu item exists for.
3. `_remap_verify` re-maps a window a dropped deiconify left withdrawn.
4. `_remap_verify` leaves an already-mapped window **completely** alone, geometry
   included — a verifier that re-mapped unconditionally would re-introduce the
   very withdraw/deiconify cycle it exists to recover from.
5. The retry chain terminates.

`tests/headless/test_remap_verify.tcl`, 9 checks, ALL PASS on `:99` with
openbox 3.6.1. Self-skips without X, since every row is about real mapping.

Sabotages: SB1 (`_remap_verify` neutralised) reds R1+R2; SB3 (the withdrawn arm's
deiconify replaced by a withdraw) reds V3.

⚠ **SB2 EXPOSED A HOLE IN THIS SUITE'S OWN POSITIVE TWIN, AND IT IS RECORDED
RATHER THAN QUIETLY PATCHED.** A verifier sabotaged to withdraw, deiconify and
resize *every* window it was handed **passed** the first draft of R2. The row
captured `wm geometry` immediately after R1's call, so under that sabotage both
sides of the comparison were mangled identically and compared equal. R2 now sets
its own distinctive geometry first and re-reads it, and R2a pins that the
geometry it captured is not the sabotage's own; SB2 reds R2 with that in place.
**A positive twin that shares the defect with the thing it guards proves
nothing**, and it passes silently, which is the worst way to be wrong.
