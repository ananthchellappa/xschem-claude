# 1306 — the Results-window focus hand-back bounces a DELIBERATE click into the text pane, and its guard is reasoned from the wrong mechanism

**Status:** FILED, NOT FIXED.
**Found by:** item **B4-2**'s adversary (Verify-C), 2026-09-04; both halves
reproduced first-hand by the write-up agent, **in one process**, before the
revert decision. **It is one of the three refutations that reverted B4-2.**
**Lives in:** `src/rdw.tcl` as carried by
`doc/claude/op_param_batch/B4-2_working_tree_REVERTED.patch` — **not in the tree
today.** It must be fixed before that patch lands (item **B4-3**).

## Background: what the hand-back is for

B4's hole 3 was real: on the **first** dump of a session the window manager
grants keyboard focus to the newly mapped `.rdw` *after* every synchronous
`focus -force` in the dump path has already returned, so `ESC` could not reach
the canvas and the command mode could not be left. B4-2 closed it with a
one-shot, event-driven hand-back: `rdw::build` binds
`.rdw <FocusIn> {rdw::_focus_handback %W}`, the two paths that MAP the window
arm a `::rdw::focus_pending` flag, and the first `FocusIn` caught clears the
flag and gives the keyboard back to the canvas.

**That part works.** This issue is about its third narrowing.

## The defect

```tcl
proc rdw::_focus_handback {{w {}}} {
    variable focus_pending
    if {![info exists focus_pending] || !$focus_pending} { return 0 }
    if {$w ne {} && $w ne {.rdw}} { return 0 }        ;# <-- this line
    ...
}
```

whose comment claims:

> * **ONLY THE TOPLEVEL ITSELF.**  A toplevel's name is in every child's
>   bindtags, so this binding also sees a FocusIn on the text pane — which is
>   the deliberate click a user makes to select and copy a block, and the one
>   focus this window is entitled to keep.

**The reasoning is about bindtags. The real mechanism is X's ancestor `FocusIn`
chain, and the guard does not survive it.** When focus crosses into
`.rdw.p.t`, Tk delivers a *separate* `FocusIn` to each ancestor with detail
`NotifyNonlinearVirtual` — so the binding fires with **`%W` literally `.rdw`**,
the guard passes, and the keyboard is taken off the text.

### MEASURED — the mechanism, `:99`/openbox

```
before:      focus=.drw  pending=0
FocusIn seen: {.rdw NotifyNonlinearVirtual} {.rdw.p NotifyNonlinearVirtual} {.rdw.p.t NotifyNonlinear}
after  click: focus=.drw  pending=0
VERDICT: TEXT FOCUS BOUNCED TO CANVAS
```

### MEASURED — and the armed flag really is reachable, BOTH HALVES IN ONE PROCESS

The one-shot only bounces if the flag is still armed when the user clicks. It
can be: on a server with **no window manager** (also: focus-follows-mouse with
the pointer still over the canvas, or a `wm deiconify` onto another workspace)
there is no map-time grant to catch, nothing consumes the flag, and the code
comment explicitly rejects a timer disarm. Under `xvfb-run -a`, one process, a
real first-of-session noun-verb dump followed by the user's deliberate click
into the pane:

```
after real dump:  focus=.drw  pending=1
after text click: focus=.drw  pending=0
VERDICT: BOUNCED - the copy target lost the keyboard
```

For contrast, the same script on `:99` under openbox: `pending=0` after the
dump — the WM's grant consumed it, and that is the path every row in both B4-2
suites took.

## Why it matters

The pane is what the whole feature exists for — the user's own stated use is to
**paste dumps into design-review documents**. A window that takes the keyboard
away from its own text at the moment you click into it to select and copy is
worse than one that never focuses at all.

And the code's stated cost is **false in the direction that matters**. It says
the leftover flag hits *"the user's next deliberate click on the window's FRAME
— not its text"*. Measured: it hits the text.

## Recommended fix (option a)

**Do not hand back once the focus has actually landed inside `.rdw`.** The
honest test is not "which window did the event name" but "where did the keyboard
end up":

```tcl
if {[winfo exists .rdw] && [string match .rdw* [focus]]} { ... }
```

evaluated **after** the crossing settles, or equivalently: arm on the map, and
disarm on the first `FocusIn` **whose `%d` is not a virtual detail** *and* whose
resulting `[focus]` is not inside `.rdw`.

**Rejected — filter on `%d` alone.** Rejecting `NotifyNonlinearVirtual` also
rejects the WM's own map-time grant on some servers, which is the one event the
hand-back exists to catch. `%d` may be part of the test; it cannot be all of it.

**Rejected — a timer disarm (`after 1000`).** The code comment rejects it and is
right: a timer is the flakiness this whole mechanism replaced.

**Rejected — bind on the canvas instead (`.drw <FocusOut>`).** It moves the race
rather than removing it, and `FocusOut` fires for every ordinary window switch.

⚠ **A row for this cannot run on `:99` under openbox as the suites are written**
— the WM consumes the flag before any row can observe it, which is precisely why
27 green checks and an eight-variant sabotage matrix missed it. The row must
either arm the flag deliberately and then focus the pane, or run on a
WM-less arm (`AUDIT_WM=none`, or `xvfb-run -a` directly).

## Still open

Everything above, plus the stated-cost sentence in the code comment, which must
be corrected rather than merely narrowed: as written it tells the next reader
the bounce cannot reach the text, and it can.

**Related:** issue **1302** (the mode has no on-canvas indicator) and the `look`
debt `rdw_keys_B4` item (b), which asks the user to rule on whether the Results
window should take the keyboard at all. **That ruling changes which fix is
right, and it has not been given.**
