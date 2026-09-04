# 1305 — a canvas command mode re-armed while SUSPENDED latches its own seize as the predecessor, and the canvas is then seized for the rest of the session

**Status:** FILED, NOT FIXED.
**Found by:** item **B4-2**'s adversary (Verify-C), 2026-09-04; reproduced
first-hand by the write-up agent before the revert decision.
**It is one of the three refutations that reverted B4-2.**
**Lives in:** `src/rdw.tcl` as carried by
`doc/claude/op_param_batch/B4-2_working_tree_REVERTED.patch` — **not in the tree
today**, because B4-2 was reverted. It must be fixed *before* that patch lands
(item **B4-3**).

## The defect in one sentence

`rdw::pick_start`'s "already armed" guard is

```tcl
if {[info exists pick(canvas)] && ![info exists pick(suspended)]} { return 1 }
```

so a **suspended** mode falls through and re-seizes — **without clearing
`pick(suspended)`**. The later `cmdmode::resume_all` therefore still believes
the mode is suspended, calls `rdw::pick_resume`, and `_pick_seize` runs a second
time on a canvas that is **already seized** — latching *the seize's own scripts*
as the "predecessors". `rdw::pick_end` then faithfully restores them.

## How a user reaches it

`hi_descend_pick_arm` (`src/xschem.tcl:7707`) calls `cmdmode::suspend_all` and
then **waits in the event loop** — `src/cmdmode.tcl`'s ruling D6 calls that
multi-frame wait load-bearing. Pressing `1`/`2`/`3`/`4` during that wait is an
ordinary thing to do; the whole point of D-2 is that those keys are always live
on the canvas.

## MEASURED — the transcript, on `:99`/openbox, `cmos_inv.sch`

Driver: `rdw::pick_start` → `cmdmode::suspend_all` → `rdw::key annotation`
→ `cmdmode::resume_all` → `rdw::pick_end`.

```
pristine     P=''  R=''  E=''  M=''
armed        P='rdw::pick_click; break'  R='break'  E='rdw::pick_end; break'  M='break'
suspend_all -> pending=rdw_pick   suspended flag=1
suspended    P=''  R=''  E=''  M=''
after key    suspended flag STILL set = 1
resumed      P='rdw::pick_click; break'  R='break'  E='rdw::pick_end; break'  M='break'
after ESC    P='rdw::pick_click; break'  R='break'  E='rdw::pick_end; break'  M='break'
VERDICT: PERMANENT SEIZE - ESC restored the seize onto the canvas
second ESC returns: 0
after ESC2   P='rdw::pick_click; break'  R='break'  E='rdw::pick_end; break'  M='break'
```

Read the last three lines: **`ESC` puts the seize back**, and a second `ESC`
returns `0` and restores nothing, because `pick_end` has already
`array unset pick`. There is no key left that ends it.

## What the user experiences

For the rest of the session, on that canvas:

* every click opens a Results dump instead of selecting;
* nothing can be selected by clicking, ever again;
* `<B1-Motion>` is `break`, so the **rubber band is dead too** — this is where
  fix 2 of B4-2 (issue **1304**) widens the damage: its fourth sequence joins
  the leaked set, so 1304's *transient* harm becomes *permanent*;
* the mode's own advice — *"press ESC to leave"* — cannot work.

That is the exact inverse of the user's ruling sentence *"This is a command
mode, so clicking will not change selected set."*: clicking can now **never**
change the selected set again.

## The CONTROL, and it names the cause

`ase::ui::select_on_design` (`src/ase_window.tcl:1877`) **self-serialises** —
`if {[info exists sod(active)]} { ase::ui::sod_end $sod(active) }` — and is
therefore immune. Same sequence, same canvas, same process:

```
pristine  P='' E=''
armed     P='ase::ui::sod_click probe; break' E='ase::ui::sod_end probe; break'
suspended P='' E=''
resumed   P='ase::ui::sod_click probe; break' E='ase::ui::sod_end probe; break'
after ESC P='' E=''
VERDICT: ASE IS CLEAN - the self-serialising arm is what saves it
```

**And B4-2's code comment argues explicitly against copying that**:

> ⚠ AN ALREADY-LIVE MODE RE-ARMS IN PLACE AND DOES NOT RELEASE AND RETAKE.
> ASE's select_on_design self-serialises by ENDING the previous mode first
> (ase_window.tcl:1879); copying that here would drop the pick every time the
> user pressed a different list key, releasing and retaking the same seize for
> nothing.

The reasoning is sound for the **live** case and wrong for the **suspended**
one. Re-arming in place is fine; re-arming in place *while a suspend is
outstanding* is not, because the resume is still coming.

## Recommended fix (option a)

**`rdw::pick_start` must not fall through into `_pick_seize` while a suspend is
outstanding.** Either

* **(a1, recommended)** clear the flag as part of taking the canvas back:
  `unset -nocomplain pick(suspended)` immediately before `_pick_seize`, so the
  later `resume_all` finds nothing suspended and `pick_resume` returns 0 — which
  is exactly what D6's "exactly the first one to arrive wins" latch is for; or
* **(a2)** make the suspended arm a **no-op that returns 1**: the mode is still
  the user's, it is merely paused, and the descend that paused it will resume
  it. This keeps the re-arm-in-place property the comment defends and adds no
  state.

**Rejected — (b) copy ASE and end the previous mode first.** It fixes this case
and reintroduces the release-and-retake the comment rejects, on every list-key
press, for nothing.

**Rejected — (c) make `_pick_seize` idempotent by refusing to latch a
predecessor that is one of its own scripts.** That is a string-comparison guard
against a state that should never be reached; it would also silently mask
whatever *else* re-entered the seize.

⚠ **Whichever is taken, the row must drive `cmdmode::suspend_all` and then press
a key, and it must assert the four `.drw` slots are back to their predecessors
after `ESC`.** No row in either B4-2 suite sets or observes `pick(suspended)`
before calling `pick_start`; that is why an eight-variant sabotage matrix and 27
green checks did not see this.

## Still open

Everything above. And note that **issue 1307** (a live seize cloned onto a new
window) reaches the same end state by a different route, and **1304's fourth
sequence widens both**.
