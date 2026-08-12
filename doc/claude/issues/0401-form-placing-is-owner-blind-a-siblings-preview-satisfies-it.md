# 0401 — `addpin::placing` / `addlabel::placing` are owner-blind: a *sibling* form's preview satisfies them

Status: **open**, measured 2026-08-11 (item D9, split out of issue 0246). Filed not fixed —
see 0246 decision D5.

## The claim

Both modeless placement forms answer "am I placing?" with the same owner-free test:

```tcl
proc addpin::placing   {} { return [expr {[xschem get ui_state] & 16384}] }   ;# src/xschem.tcl
proc addlabel::placing {} { return [expr {[xschem get ui_state] & 16384}] }
```

`START_SYMPIN` (16384) says *some* sympin preview rides the cursor. It does not say **whose**.
Both forms are singletons on the same canvas and can be open at once, so each form's `placing()`
returns true for the other's preview.

## Measured consequence (the state manufactured for issue 0246 W9)

`arm()` has a redundant-rearm shortcut so a non-editing keystroke does not rebuild the preview
and flicker the canvas:

```tcl
if {$current eq $last && [addlabel::placing]} return    ;# src/xschem.tcl (addpin: same shape)
```

Sequence, no state injection (measured at 9e51b4c8):

1. Add-Wire-Label arms `A` — label preview live, `addlabel::last` = `A`.
2. Add-Pin arms on top — the C `-place` tears the label preview down and arms a pin preview.
   `addlabel::armed` is still 1 and `addlabel::last` is still `A`.
3. A non-editing key in the Label Name field → `start_pass` → `arm`: `$current eq $last` and
   `placing()` is satisfied **by the PIN's preview**, so `arm` returns early. The label form is
   now `armed=1` with **no preview of its own** and never notices.

Under the pre-0246 code that early return also skipped the `::sympin_place` write, which is how
the write-only latch went stale in the first place. 0246 deleted the latch and split the drop
witness per owner, so the *drop accounting* is now correct regardless: the label form's counter
cannot move, so it pauses instead of draining. The owner-blind `placing()` itself is untouched —
the form can still sit `armed=1` with nothing on the cursor.

## Second face, found by the 0246 adversary pass: it also gates `after_drop`, so 0246's pause is hook-order dependent

Both forms append `after_drop` to the **same** `.drw <ButtonRelease>`, so on a real drop both run,
in form-open order, and each starts with the same owner-blind guard:

```tcl
if {[addpin::placing]} return   ;# preview still attached -> no drop happened
```

When the **owner's** hook runs first it drains its queue and immediately re-arms the next name,
which re-raises `START_SYMPIN`. The non-owner's hook then hits that guard and returns *above* the
0122-E1 witness compare — the same place the deleted `::sympin_place` latch used to return from.
Measured headlessly at the 0246 fix (label form armed first, so the owner runs first, after a real
label commit):

```
OWNERFIRST lab.queue={B} lab.armed=1 ui=16424
NONOWNER   pin.queue={IN OUT} pin.armed=1 pin.status={} inst=2
```

The pin form keeps its queue (0246's guarantee holds — it cannot *drain*), but it stays `armed=1`
with an **empty** status instead of the "placement paused" line. In the other order (non-owner
first, which is what `test_sch_add_pin.tcl` Q3/Q4 and `test_add_wire_label.tcl` W9/W10 exercise) it
does pause. So issue 0246 decision **D3** — "the non-owner disarms and says so" — holds only in the
favourable order; in the other order the silent-zombie residue survives, unchanged from before
0246 (the `placing` test always preceded the latch test, so this is not a regression).

Fixing that means the same thing this issue already asks for: an "*I* am placing" test distinct
from "someone is placing".

## Why it was not fixed with 0246 (rung R2: smallest blast radius)

The obvious conjunct is `wirelabel_preview` (`xschem get wirelabel_preview`), the same fact the C
uses to split the witness. Three reasons to leave it:

- `placing()` also drives `abort_if_placing` (the Close/Escape teardown), the Ctrl+MMB type cycle
  and the 0245 canvas-Escape rows. An owner-aware `placing()` that answers *false* makes
  `abort_if_placing` stop aborting — a Close button that leaves a live preview on the cursor is a
  strictly worse bug than a form that thinks it is armed.
- `wirelabel_preview` can itself be left stale by a door (issues 0262/0399); D8's
  `check_placement_preview_invariant` repairs flags but is not a guarantee at this call site.
- There is no owner bit at all for the *pin* side — `wirelabel_preview == 0` also means "no
  preview", so an owner-aware `addpin::placing` would need a new flag, not a new conjunct.

## What a fix would need

A positive per-owner preview identity in C (e.g. a `sympin_preview_owner` enum: none / pin /
label, set by the three `-place` arms and cleared wherever `sympin_preview` is), plus a getter,
plus `placing()` split into "someone is placing" (for the teardown paths, which must stay
owner-blind) and "*I* am placing" (for the re-arm shortcut). That is a bigger change than 0246
needed and touches every Escape/abort row, so it wants its own item.

## Where it lives

- `src/xschem.tcl` — `addpin::placing`, `addlabel::placing`, and the two `arm()` shortcuts.
- Detector today: `tests/headless/test_add_wire_label.tcl` W9 precondition row
  (`0246 W9 precondition: label form still thinks it is placing` asserts `armed` 1 — it is
  documenting this defect, and must be **inverted** when 0401 is fixed).
