# 1309 — a list key pressed during a suspended descend leaves the DESCEND unterminable

**Filed** 2026-09-04 by item **B4-3**'s write-up agent, from the adversary's
(Verify-C) own measurement, with the mechanism confirmed structurally here.
**Status: FILED, NOT FIXED.** Measured **identical on the fixed and unfixed
arms**, so it is not caused by B4-3 — but it is the half of issue **1305** that
1305's fix does not reach, and it was recorded nowhere.

## The defect in one sentence

Press `E` to arm a hierarchical descend, then press a bare `1`/`2`/`3`/`4` while
the descend is waiting for its click: the Results-window mode re-seizes the
canvas and `break`s **both** of the descend's terminals, so
`hi_descend_pick_cancel` / `hi_descend_dialog` never run, C's arm stays live, and
**no later descend suspends any command mode until some terminal eventually
fires**.

## MEASURED — Verify-C, `:99`/openbox, driving the REAL `hi_descend_pick_arm`

Verify-C drove the real gesture rather than row `D3`'s hand-called
`cmdmode::resume_all`, pressed a bare `2` during the event-loop wait, then
clicked and pressed `ESC`, on both arms side by side:

> **THE FIX DOES EXACTLY WHAT IT CLAIMS** (`pick(suspended)` = 0 after the key on
> the fixed arm, 1 on the unfixed). **BUT the real gesture never reaches
> `resume_all` at all**: with the mode re-seized, rdw `break`s both the click and
> the `ESC`, so no descend terminal runs — measured `cmdmode::is_suspended`=1 and
> C's `ui_state`=65536 still armed after `ESC`, and a fresh `cmdmode::suspend_all`
> returns 0, i.e. **no command mode is suspended by any later descend until some
> descend terminal fires**. IDENTICAL ON BOTH ARMS, so not a regression.

## The mechanism, confirmed structurally on this tree

`hi_descend_pick_arm` (`src/xschem.tcl:7707`) suspends, arms C, and waits:

```
  cmdmode::suspend_all
  xschem descend_pick
  ciw_echo "hi_descend: click the instance to descend into (ESC to cancel)"
```

and its own comment names its only exits —

> *"The matching resume is whichever terminal this pick reaches:
> `hi_descend_do` (a real descend), `hi_descend_dialog` (Cancel / no views), or
> `hi_descend_pick_cancel` (clicked empty space, or ESC)."*

Every one of those three is reached **from C**, through the canvas click or the
canvas `Escape` (`hi_descend_pick_cancel`'s comment: *"the single terminal for
BOTH cancels — the click on empty space and ESC while the pick was armed"*).
`rdw::_pick_seize` then takes those exact two sequences on the same canvas and
ends both scripts in `break`:

```
src/rdw.tcl:1393   bind $cv <Key-Escape>      "[list rdw::pick_end]; break"
```

so C's dispatcher never sees either event and no terminal runs.

## What the user experiences

The descend's own CIW line still says *"ESC to cancel"*. `ESC` ends the
**Results** mode (correctly, after 1305's fix) and does nothing about the
descend. From then on `cmdmode::is_suspended` is stuck at 1 and
`cmdmode::suspend_all` returns 0, so **ASE Direct Plot and the Results mode both
stop being suspended by any subsequent descend** — the exact protection
`cmdmode` exists to provide, silently off, with no message anywhere.

## Relationship to 1305 and 1307, stated so nobody re-files it

* **1305** is the *mode's* half: the double seize that made the canvas
  unrecoverable. **Fixed in B4-3** (`unset -nocomplain pick(suspended)` in
  `rdw::pick_start`).
* **1309** is the *descend's* half, on the other side of the same key press.
  1305's fix does not touch it, and 1305's filed transcript is reachable only by
  calling `resume_all` directly — which is worth saying plainly so nobody
  over-credits the fix.
* **1307** is a third route to a stranded seize (a cloned canvas). Different
  door, different fix.

## Options, none taken here

* **(a) The seized scripts forward instead of swallowing** when C has an armed
  pick — i.e. `break` only if `xschem get ui_state` shows no descend arm.
  Correct-looking and fragile: it re-couples the Tcl mode to a C state word, and
  the two modes would both act on one click.
* **(b) `rdw::pick_start` refuses while a descend is armed** and says so on the
  CIW line. This is the reverse of ruling **D-2**'s premise that the four keys
  are always live, so it needs a ruling.
* **(c) `hi_descend_pick_arm` gains a Tcl-side timeout / cancel** so the arm
  cannot outlive the gesture. Largest, and it touches shipped descend code.
* **(d) The descend suspends *and locks*** — `suspend_all` returning a token that
  `pick_start` must not step over. That is the general fix for the whole class
  (1305, 1307 and this) and is the one worth designing rather than patching.

## Still open

* Everything. This is filed, not fixed, and it is **outside item B4-3's Files
  cell** (`src/xschem.tcl`'s descend chain is not B4-3's to edit).
* Whether (d) subsumes **1307**. It probably does, and a crew taking 1307 should
  read this file first rather than fixing the two doors separately.
