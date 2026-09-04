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

## ✅ FIXED in item **B4-3**, 2026-09-04 — but this section's OWN CODE LINE WAS REFUTED

**Read the strikethrough below before copying anything out of it.** The shape of
option (a) — *decide on where the keyboard LANDED, not on which window the event
named* — is right and is what shipped. **The literal predicate this section
printed is wrong and does NOT fix the defect.**

### ⛔ REFUTED, by three independent agents, on both display arms

```tcl
if {[winfo exists .rdw] && [string match .rdw* [focus]]} { ... }   ;# ← DOES NOT WORK
```

`.rdw*` matches the **descendant** `.rdw.p.t` exactly as readily as the toplevel
`.rdw`, so the deliberate pane click still satisfies the guard and is still
handed back. Measured with that exact line applied to a copy:

```
DET-B afterclick focus='.drw' pending=0 verdict=BOUNCED
   [CAND-A  string match .rdw*  -- 3/3 BOTH arms: THE RECOMMENDED FIX LINE DOES NOT FIX IT]
```

and again as sabotage variant `SB-1306-BRIEFLINE` against the shipped tree:
keys suite `RED:F3 RED:F4`, window suite `RED:K16`, on both arms — while the
map-time-grant control row `F1` stayed **green** under it, which is exactly why
`F1` alone was never evidence.

### ✅ WHAT SHIPPED: the EXACT toplevel test

```tcl
set land {} ; catch {set land [focus]}
if {$land ne {.rdw}} { return 0 }
```

`src/rdw.tcl:1215-1216`, strictly **below** the `focus_pending` early return
(headless has no `focus` command; the proc survives `--nogui` only by returning
first). `%W` is kept above it as a cheap necessary-but-not-sufficient first cut.

**The discriminator is the one the window manager itself supplies:** the
map-time grant lands on the **TOPLEVEL** (`[focus]` eq `.rdw`, detail
`NotifyAncestor`) while **every deliberate landing lands on a CHILD**
(`[focus]` eq `.rdw.p.t`). Measured `KEPT 4/4` on both arms, with the grant
hand-back still alive (`DET-C grant-leg pending=0 focus='.drw' handback_ok=1`).

Row **K16** of `tests/headless/test_rdw_window_1245.tcl` now keeps `string
match` out of `rdw::_focus_handback` permanently, so the refuted glob cannot
come back as a "simplification".

### ⛔ ALSO REFUTED: this section's "or equivalently" formulation

> *"disarm on the first `FocusIn` whose `%d` is not a virtual detail and whose
> resulting `[focus]` is not inside `.rdw`"*

The WM's own grant has `[focus]` **inside** `.rdw`, so that test rejects the one
event the hand-back exists to catch. It is not equivalent; it is the opposite.

### The comment correction this issue demanded, and how it was taken

The code comment's *"only the toplevel itself / bindtags"* paragraph was
**INCOMPLETE, not wrong**, and both mechanisms are real and were measured. It
now names both: an **inferior** crossing (focus already inside `.rdw` moving to
`.rdw.p.t`) really does reach the binding through bindtags; a crossing from
**outside** (`.drw` → `.rdw.p.t`) *also* delivers a separate `FocusIn` to `.rdw`
itself with detail `NotifyNonlinearVirtual` along X's **ancestor** chain, which
no `%W` test can survive. Swapping one half-truth for the other would have been
wrong in the other direction.

The **"COST, STATED"** paragraph is now TRUE for the first time: a deliberate
landing does **not** spend the one shot, so a click on the window's **frame** or
its **button column** (Tk buttons do not take focus on X, so `[focus]` stays at
`.rdw`) hands the keyboard back exactly once; a click on the **text** never
does.

### ⚠ AND THE FIX EXPOSED A DEFECT OF ITS OWN — issue **1308**

With the pane holding the keyboard, the mode's documented exit is dead: `ESC`
and a bare `2` are both bound on the **canvas**, and `.rdw` carries neither.
Measured, and **identical on the unfixed arm** in the ordinary case. Filed as
**1308**, whose ruling is the SAME ruling as this issue's "should the window
take the keyboard at all" question. Read it before taking either.

---

## Recommended fix (option a) — *kept verbatim for the record; see the refutation above*

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

* **The ruling, not the code.** The mechanism is fixed and fenced (rows `F3`,
  `F4`, `K16`; sabotage `SB-1306-REVERT`, `SB-1306-BRIEFLINE`, `SB-1306-ALWAYS`
  all red them). What is still open is whether the window *should* hold the
  keyboard at all — the `look` debt `rdw_keys_B4` item (b) — and that same
  ruling settles issue **1308**.
* **Issue 1308**: with the pane holding the keyboard there is no key that ends
  the mode.
* **A theoretical hazard the adversary probed and could not trigger.** Tk keeps
  a per-toplevel focus record, and `tk::TextButton1` calls `focus $w`
  unconditionally, so after the feature's own pane click that record names
  `.rdw.p.t`. On a WM that re-grants focus on a remap, a later grant would land
  on the **child**, `[focus] ne {.rdw}`, and the hand-back would decline. Two
  variants were built (`wm iconify`→`deiconify`, `wm withdraw`→`deiconify`) and
  **openbox did not re-grant**; `rdw::close` destroys the window, so a fresh
  build always resets the record. Recorded, not fixed, because nothing on this
  machine reproduces it.
* **The `%W` first cut is unfenced dead weight.** Deleting it on a copy left
  both suites fully green (76 / 30) — harmless, since the landing test subsumes
  it, but row `K15` fences only that the binding *passes* `%W`, not that
  anything consults it.

**Related:** issue **1302** (the mode has no on-canvas indicator) and the `look`
debt `rdw_keys_B4` item (b), which asks the user to rule on whether the Results
window should take the keyboard at all. **That ruling changes which fix is
right, and it has not been given.**
