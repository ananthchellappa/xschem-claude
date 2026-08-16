# 0386 — the descend-pick gate is one-directional: entering a click mode over a live arm still swallows the pick

Status: **OPEN** (measured, not fixed)
Found: 2026-08-10, crew item D6 adversary pass (`ATK-1`/`ATK-1b`), after the 0257 fix landed.
Area: `src/scheduler.c` `net_hilight_interactive()` (`:5967-5968`, bare `|=`); `src/callback.c`
`enter_deselect_mode()` (`:4030`, same shape); the gate that only runs the other way is
`xschem descend_pick` (`src/scheduler.c`) calling the new `abort_click_mode()` (`src/callback.c`).
Tests: `tests/headless/test_cmdmode_descend_0201.tcl` MS1-MS8 cover **mode → arm** only. Nothing
covers **arm → mode**.
Related: **0257** (the fix that closed the other direction), **0247** (`leave_wire_draw_for()`, the
ratified reciprocal-teardown precedent), **0202** (`cmdmode` suspend/resume), **0268**.

## The defect

D6 closed the measured order — enter net-highlight/deselect/persistent-wire, *then* arm the descend
pick — by tearing the competing mode down at the verb and naming it. The reverse order is
untouched: the two mode-entering verbs OR their bit in with no check for a live
`MENUSTARTDESCEND`. Measured under xvfb:

```
hi_descend                    -> armed, ui_state2 = 32768
xschem hilight_net_interactive-> ui_state |= NET_HILIGHT, no reciprocal check
click the instance            -> resolved = ''            <-- pick swallowed
                                 ui_state  = 1048576
                                 ui_state2 = 32768         <-- discriminator stranded
                                 cmdmode::is_suspended = 1
xschem load <other sheet>     -> all three values unchanged  <-- residue survives a document change
ESC                           -> ui_state2 = 0, is_suspended = 0   (0257's relaxed guard redeems it)
```

So the *terminal* damage of 0257 is gone (ESC can always redeem the arm now), but the swallow, the
stranded discriminator and command mode being suspended across an `xschem load` are all still
reachable — just in the other order. The `9` / `8` keys are raw `bind .drw <Key>` (per
`scheduler.c`'s own comment) and therefore survive `cmdmode::suspend_all`, so this order is
reachable from the keyboard, not only from a script.

## The shape of the fix

The ratified rule (0243 F2) puts gates at the verbs, and 0247's `leave_wire_draw_for()` is the
precedent for making one *reciprocal*: the mode-entering verbs should either

* cancel the live pick and **name** it — `hi_descend_pick_cancel` + a composed held sentence such as
  `Net highlight: descend pick cancelled -- click a net or label`, mirroring what `descend_pick`
  already says in the other direction; or
* refuse to enter while a pick is armed and say so (weaker: "whatever you just pressed is what you
  meant" argues against refusing a key the user just pressed).

The first is the symmetric counterpart of what landed for 0257 and reuses the existing
`hi_descend_pick_cancel` terminal, which already resumes `cmdmode`.

## Test rows this needs

Mirror MS1-MS8 in the other order in `tests/headless/test_cmdmode_descend_0201.tcl`: arm, enter each
of the three modes, assert `ui_state2 & MENUSTARTDESCEND == 0`, `cmdmode::is_suspended == 0`, a held
sentence naming the cancelled pick, and that the following click does the *mode's* job.
