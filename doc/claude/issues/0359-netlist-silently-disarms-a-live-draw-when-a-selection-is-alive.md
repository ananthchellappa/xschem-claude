# 0359 — `netlist` silently disarms a live wire/shape draw whenever a selection is alive, and the shipped comment says it cannot

Status: **OPEN — measured, not fixed.** Filed 2026-08-09 by the issue-**0263** write-up agent
(item D2 of the unattended backlog run), from the adversary pass on 0263's fix.
**Minor by damage, notable by wrongness**: no object is lost and no deck is affected, but a modal
gesture ends with no announcement, and the code comment that justifies *not* gating it asserts the
opposite of what the binary does.
Area: `src/select.c` (`unselect_all()`'s wholesale `ui_state = 0`) vs the draw-family bits, reached
through the netlist drivers' `unselect_all(1)`.
Related: **0263** (the fix whose decision D3 this qualifies), **0269**/**0271**/**0272** (the shape
and wire draw teardown/gate pairs), **0243** (`clear_orphan_gesture_bits()`), **0268**
(`ui_state2` residue), `doc/claude/WIRING.md` §8 class D.

## What 0263's fix asserts

Issue 0263 gates the `netlist` verbs with `leave_placement_for()` + `leave_merge_for()` and
deliberately **omits** `leave_wire_draw_for()` / `leave_shape_draw_for()`. The shipped comment in
`src/scheduler.c` justifies the omission twice over:

> A rubber-band draw parks no object in `inst[]`/`wire[]`, so the netlister cannot see it, and
> `unselect_all()` zeroes `ui_state` only when something is selected (`select.c`), which a bare draw
> is not — so the round trip provably cannot clobber a draw either.

The first half is true. **The second half is false**, because `wire gui` / `rect gui` do not clear
an existing selection: if anything was selected *before* the draw armed, `unselect_all()`'s guard
`if((xctx->ui_state & SELECTION) || xctx->lastsel)` is satisfied and it zeroes `ui_state` wholesale,
taking `STARTWIRE`/`STARTRECT` with it.

## Measured (headless, pinned binary `md5 e2261cb0b9f1ba90552ca1b09e554ef5`)

```
== A. live wire draw, NOTHING selected ==
   armed  ui=1 (STARTWIRE=1 is bit0)
   netlist ui=1 status=
== B. live wire draw WITH a selection alive ==
   armed  ui=9 lastsel=1
   netlist ui=0 status= last_command=1
== C. live rect draw WITH a selection alive ==
   armed  ui=10
   netlist ui=0 status=
```

Reproduce:

```tcl
xschem clear force ; xschem wire 0 0 300 0 ; xschem unselect_all
xschem select_all                  ;# anything selected: lastsel >= 1
xschem wire gui                    ;# ui_state = 9  (STARTWIRE|SELECTION)
xschem netlist                     ;# ui_state = 0  -- the draw is gone, silently
```

Arm A is the case the comment describes and it behaves as the comment claims. Arm B/C is the case
the comment denies.

Three things are wrong with arm B/C, in increasing order of consequence:

1. the draw ends with **no status line** — it violates the 0241 rule that a teardown must name what
   it is tearing down (here nothing even calls a teardown; the bits are simply dropped);
2. `last_command` is left at **1**, i.e. the `persistent_command` resting mode survives the bits
   that gave it meaning — the same shape as the 0243 orphan-bit class;
3. the same happens to a **deferred `MENUSTART` arm** (measured `ui=65544`, a pending
   "Duplicate objects"), which is disarmed unnamed.

## Why it is not 0263's defect

0263's damage is a wrong netlist and a committed object. A draw owns no object, so the deck is
unaffected and nothing is committed — 0263's *conclusion* (do not call the two draw gates from the
netlist verb; ending an in-flight draw on every `n` would be user-visible harm for zero correctness
gain) stands unchanged. What does not stand is its *reason*. The draw is not protected by the
selection guard; it is simply not worth protecting via a `delete()`-free teardown that does not yet
exist for this direction.

## Options

1. **Correct the comment only.** Cheapest, honest, changes no behaviour. Leaves a modal gesture
   dying unannounced.
2. **Call `leave_wire_draw_for("Netlist")` / `leave_shape_draw_for("Netlist")` at the netlist
   verbs after all.** Now the teardown at least *names* itself — but it also ends a draw the user
   is mid-stroke on, on every scripted `xschem netlist`, which is exactly the harm 0263 D3 rejected.
3. **Make `unselect_all()` stop zeroing draw bits it does not own.** The correct fix in principle
   and the one with the biggest blast radius: `unselect_all()` has ~817 call sites and its wholesale
   `ui_state = 0` is load-bearing for several of them (see issue 0123's objection).

Recommendation: **1 now, 3 as part of whatever finally settles 0262/0123** — those two are already
blocked on the same wholesale `ui_state = 0`.

## Not fixed here

Out of item D2's scope: D2 is 0263, whose blast radius is deliberately two gate calls. Recorded so
that the next author who reads the `scheduler.c` comment does not inherit a false invariant.
