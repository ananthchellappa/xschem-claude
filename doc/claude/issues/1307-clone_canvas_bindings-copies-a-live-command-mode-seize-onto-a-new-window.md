# 1307 — a new window or tab created while a canvas command mode is LIVE inherits the seize, and the mode's own ESC restores only the canvas it seized

**Status:** FILED, NOT FIXED. **TRUE OF THE TREE AS IT STANDS** (`0ce85dda`) —
this one is **not** a defect of the reverted B4-2 patch. It is measured against
**shipped `ase::ui::select_on_design`**, with no B4-2 code loaded.
**Found by:** item **B4-2**'s adversary (Verify-C), 2026-09-04, as route (b) of
its permanent-seize refutation; measured against ASE by the write-up agent.

## The mechanism, and it is already written down

`src/cmdmode.tcl:44-50` documents the hazard exactly, and states the invariant
that is supposed to make it safe:

> ORDERING NOTE, not obvious and load-bearing. Suspending BEFORE a new window or
> tab is created is what keeps `clone_canvas_bindings` (xschem.tcl) honest: it
> copies `.drw`'s bindings verbatim onto every new canvas, so a still-seized
> mode would be cloned onto the child with the parent's key already substituted
> — clicks there would queue into a mode whose `sod_end` restores bindings on
> the *other* canvas, leaving the child permanently seized with dead scripts.
> **Because every suspend site in the descend chain runs before
> `schematic_in_new_window`, the clone always copies pristine bindings.**

The last sentence is true **of the descend chain** and of nothing else.
`clone_canvas_bindings` is called by C for **every** new window and tab
(`src/xinit.c:2121`, `:2337`), and `File > New Window` / a new tab has **no**
suspend site at all. Issue **1301** already records that the cadence profile's
own descend has none either.

## MEASURED — shipped ASE, reverted tree, `:99`/openbox

`rdw::pick_start exists = 0` — no B4-2 code in the process.

```
select_on_design armed = 1
.drw    P='ase::ui::sod_click probe; break'  E='ase::ui::sod_end probe; break'
.x1.drw P='ase::ui::sod_click probe; break'  E='ase::ui::sod_end probe; break'
after ESC on the parent:
.drw    P=''
.x1.drw P='ase::ui::sod_click probe; break'
VERDICT: ASE LEAKS THE SAME WAY - true of the tree today
```

The parent is cleaned; the child keeps the seize. Its `<Key-Escape>` runs
`sod_end probe`, which finds nothing active and restores bindings on a canvas
that is already pristine — so **the child's ESC is dead** and every click there
queues into a mode that no longer exists.

## And the same route was measured on B4-2's mode, before the revert

```
armed on: .drw
.x1.drw  P='rdw::pick_click; break'  R='break'  E='rdw::pick_end; break'  M='break'
after ESC on the parent:
.x1.drw  P='rdw::pick_click; break'  M='break'
VERDICT: LEAKED - the new window is seized and its ESC restores nothing
ESC on the child returns: 0
```

⚠ **The fourth sequence makes it worse.** Once issue **1304**'s fix lands,
`<B1-Motion> {break}` joins the cloned set, so the leaked child also loses its
rubber band — 1304's *transient* harm becomes *permanent*, on a window the user
never armed a mode on.

## Recommended fix (option a)

**Suspend at the door that creates the window, not only in the descend chain.**
`cmdmode::suspend_all` immediately before `schematic_in_new_window` /
`new_schematic create_window` / the tab-create path, and `resume_all` after —
which is what `cmdmode.tcl`'s own ordering note already prescribes, applied to
the sites it does not yet cover. This is one mechanism for all modes and needs
no per-mode change.

**Rejected — (b) have each mode re-seize on the child.** That is what
`pick_resume`/`sod_resume` do for a *descend*, where the user's mode follows
them to the canvas they land on. A new window is not a descend: the user is
still working on the original, and a mode that spread itself to every window
would be a bigger surprise than one that pauses.

**Rejected — (c) have `clone_canvas_bindings` skip the four seized sequences.**
It would need to know which scripts belong to a mode, i.e. a second definition
of the seize, in C, in a proc whose job is to copy verbatim.

**Rejected — (d) leave it, since the child's ESC is only "dead", not harmful.**
Measured above: clicks on the child run the parent's click handler with `break`,
so the child cannot select anything at all. That is not an inert leftover.

## Acceptance for whoever takes it

1. Arm any registered command mode, create a new window, and assert the child's
   four canvas slots equal the child's own predecessors — **not** the parent's
   seize.
2. `ESC` on the child restores the child; `ESC` on the parent restores the
   parent; neither restores the other's bindings.
3. The existing descend suites (`test_cmdmode_descend_0201`,
   `test_verb_noun_descend_0200`) stay green — the descend path already
   suspends, and this must not double-suspend it (`cmdmode.tcl` D6: a second
   `suspend_all` is a no-op returning 0).

## Still open

Everything above. Related: **1301** (the cadence descend does not suspend),
**1305** (the other route to the same permanent-seize end state), **1304** (the
fourth sequence that widens both).
