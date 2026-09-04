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

## ✅ FIXED in item **B4-3**, 2026-09-04 — option **a1**, one line

```tcl
    ## ISSUE 1305: clear the outstanding suspend as part of taking the canvas
    ## back, so resume_all finds nothing to resume.  BELOW the guard above.
    unset -nocomplain pick(suspended)
    rdw::_pick_seize $cv
```

`src/rdw.tcl:1449`, placed **below** the `$cv eq {} || ![winfo exists $cv]`
guard on purpose — a re-arm that could not take a canvas must leave the suspend
intact for the real resume — and **above** `_pick_seize`. It is the same idiom
`rdw::pick_resume` uses twelve lines further down, and the one
`ase::ui::sod_resume` uses (`src/ase_window.tcl:2047`). Ladder rung **L1**, by
precedent: cmdmode ruling **D6**, *"exactly the first one to arrive wins"*.

**Rejected alternative, restated with its cost:** **(a2)** preserves the rehome
but makes a `1`-`4` press during `hi_descend_pick_arm`'s wait **silently do
nothing**, which contradicts ruling **D-2**'s premise that those keys are always
live. Sabotage variant `SB-1305-SWALLOW` greens this issue the a2 way (delete
`![info exists pick(suspended)]` from the early-return guard) and the new rows
**red it** — `RED:D3`, `RED:K17` — so a2's behaviour cannot slip in later.

### AFTER — the transcript the BEFORE section above records, re-run

Row `D3` of `tests/headless/test_rdw_keys_1245.tcl`, `:99`/openbox:

```
ok:   D3 ISSUE 1305: with the mode live and a descend's suspend outstanding, a real
      bare 2 on the canvas re-arms the pick AND clears the suspend, so the later
      resume finds nothing to resume and a real ESC hands ALL FOUR of the canvas's
      own predecessors back.
RESULT: ALL PASS (30 checks)
```

The filed post-`ESC` dump — `P='rdw::pick_click; break' R='break'
E='rdw::pick_end; break' M='break'` — is gone; all four slots come back byte-
identical to the canvas's own predecessors. `SB-1305-REVERT` (drop the one line)
reproduces the filed **PERMANENT SEIZE** and reds `D3` + `K17`.

### The fences

* **`D3`** (keys, `:99`) — behavioural, and it asserts the four `.drw` **slots**
  after `ESC`, never `cmdmode::resume_all`'s return count: `cmdmode.tcl:130`
  does `incr n` for every callback that does not *throw*, regardless of its
  return value, so a count leg would read 1 before **and** after the fix.
* **`K17`** (window, **both arms**) — structural, because the keys suite
  self-skips under `--nogui`. It asserts the `unset` is present, that its index
  is **below** the `winfo exists $cv` guard and **above** `_pick_seize`, and
  that `![info exists pick(suspended)]` is still in the early return, so nobody
  "fixes" 1305 by deleting the guard.

### ⚠ COST, STATED — and it is real

`pick_start` now re-seizes on the canvas **current at key-press time**, which
during a descend's wait is still the **parent**. Because `resume_all`'s
`pick_resume` now returns 0, a descend that lands on a **different** canvas (new
window, new tab) leaves the mode live on the **old** one and never rehomes it.
That residue is recorded on issue **1307**, whose own subject is a command-mode
seize arriving on a canvas nobody armed it on. No new number was minted for it.

### ⚠ AND: this issue's filed transcript is NOT user-reachable as filed

B4-3's adversary drove the **real** `hi_descend_pick_arm` gesture rather than
row `D3`'s hand-called `cmdmode::resume_all`, and found the double seize needs
`resume_all` to run while the mode is live — and **every real terminal is eaten
by the seize itself**, so `resume_all` never runs. `D3` calls it directly, and
the row says so. **So this fix's practical value is defence-in-depth, not the
unrecoverable session-wide seize this file describes.** Say so plainly rather
than over-crediting it. The gesture's *actual* consequence is filed as issue
**1309** — the DESCEND becomes unterminable — and 1305's fix does not reach it.

## Still open

* **Issue 1309**, the other side of the same key press, unfixed.
* **Issue 1307** (a live seize cloned onto a new window) reaches the same end
  state by a different route, and **1304's fourth sequence widens both**. 1309's
  option (d) — a suspend that returns a lock `pick_start` must not step over —
  probably subsumes 1307 and this; a crew taking either should read 1309 first.
* The a1 **rehome residue** above.
