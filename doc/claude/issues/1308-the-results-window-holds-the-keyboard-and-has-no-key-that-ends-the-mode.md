# 1308 — the Results window now HOLDS the keyboard, and nothing on it ends the command mode

**Filed** 2026-09-04 by item **B4-3**'s write-up agent, from the adversary's
residual risk, **re-measured first-hand before filing**.
✅ **FIXED 2026-09-04 by the DRIVER (ruling DD-12)**, immediately after B4-3
landed and before item B5 was dispatched. B4-3 filed it rather than widening its
own scope, which was right.

`<Key-Escape>` is now bound on the **`.rdw` toplevel**, so it fires wherever
focus sits inside the window, including the text pane — the case that matters,
because the pane holding the keyboard is the whole point of issue 1306's fix.

⚠ **It ends the MODE and does NOT close the window.** Escape dismisses a dialog
in many applications, so this is a deliberate deviation: `.rdw` holds the dumps,
and those dumps are the artifact the feature exists to produce. `rdw::close`'s
own comment already records that losing them to a stray click on the X is the
worse failure; a stray Escape is the same accident with a different finger. So
Escape does nothing when no mode is running — never a destructive default.

Measured on the shipped tree, `:99`/openbox:

```
PICK_START=1  RUNNING_BEFORE=1  FOCUS_AFTER_PANE_CLICK=.rdw.p.t
ESC_BOUND_ON_WINDOW=1
RUNNING_AFTER_ESC=0        WINDOW_STILL_OPEN=1
WINDOW_OPEN_AFTER_STRAY_ESC=1
```

Rows **E1-E5** of `tests/headless/test_rdw_keys_1245.tcl` (30 → 35). Sabotage:
deleting the binding reds **E2 E3 E5**; making Escape *also* close the window —
the destructive default DD-12 forbids — reds **E4** alone.

`rdw::pick_running` was added as the predicate. ⚠ **A SUSPENDED MODE COUNTS AS
RUNNING**: a mode paused by a descend is still one the user has to be able to
leave, and `pick(canvas)` is what `pick_end` releases.

---

*Original filing follows.*

**Status: ~~FILED, NOT FIXED.~~**
**Subject:** `src/rdw.tcl` — the interaction between issue 1306's fix and the
window's deliberate "takes the keyboard nowhere" design.

## The defect in one sentence

Once the user does the very thing the window exists for — click the text pane to
select a dump for a design-review document — **the command mode's documented
exit is dead**: `.rdw` and `.rdw.p.t` carry no `<Key-Escape>` and no `1`/`2`/`3`/`4`,
those bindings live on the **canvas**, and the canvas no longer has the keyboard.

## MEASURED — my own run, `:99`/openbox, `cmos_inv.sch`, the SHIPPED B4-3 tree

```
WU-1 armed seized=1 escbind_on_canvas=1
WU-2 rdw_exists=1 focus=.drw
WU-3 afterclick focus=.rdw.p.t seized=1
WU-4 afterESC focus=.rdw.p.t seized=1 esc_on_rdw=0 esc_on_pane=0
WU-5 after2 focus=.rdw.p.t seized=1
```

`WU-3` is issue **1306's fix working**: the deliberate pane click keeps the
keyboard, which is the headline requirement. `WU-4` is the cost nobody had
written down: a real `<Key-Escape>` delivered to whatever holds focus does
**not** end the mode (`seized` stays 1), because there is no Escape binding on
the toplevel or on the pane. `WU-5` is the same for a bare `2`.

The adversary (Verify-C) reached the identical state independently and also ran
**the unfixed arm on the identical fixture and got the identical result**, because
in the ordinary case the window manager's map-time grant has already spent the
one-shot, so the unfixed guard leaves focus on the pane too. **So B4-3 neither
causes nor fixes this**, and it is not a regression — but see "why the fix
sharpens it".

## The mechanism, structurally confirmed

`rdw::_pick_seize` binds the mode's four sequences on `$cv`, the **canvas**:

```
src/rdw.tcl:1389   set pick(prevesc)  [bind $cv <Key-Escape>]
src/rdw.tcl:1393   bind $cv <Key-Escape>  "[list rdw::pick_end]; break"
```

and `grep -n 'Escape' src/rdw.tcl` finds no binding on `.rdw` at all. The four
list keys are the same shape: they are `bind .drw <Key-N>` lines in
`src/cadence_style_rc:181-184`. The window's own comment says so and states it
as a *virtue* —

> `src/rdw.tcl:857` — *"1/2/3/4 and the command mode's Escape — lives on the
> design CANVAS"*
> `src/rdw.tcl:1148` — *"used to leave a command mode whose Escape the keyboard
> could not reach"*

— which is exactly the state the window is now in.

## Why the 1306 fix SHARPENS it even though it does not cause it

Before B4-3, on a window manager that does **not** grant focus at map time, a
pane click was bounced to the canvas: **ESC worked and copying was impossible.**
After B4-3, on that same WM, **copying works and ESC is stuck.** Under a WM that
does grant (openbox, measured), both arms behave the same and are stuck either
way. So the fix does not add the defect; it removes the accident that was
masking it on one arm.

## Recovery, and why it is not good enough

The user can click the canvas — but in this mode a canvas click is **another
pick**, which dumps another device. So the only escape is a gesture that does
the thing the user was trying to stop doing. Closing the window with its own
button also works, and is undiscoverable as a way to end a *canvas* mode.

## Options, none taken here

* **(a) Bind the mode's exit on the window too.** `bind .rdw <Key-Escape>
  {rdw::pick_end; break}` while a pick is live, torn down by `pick_release`.
  Smallest, and it makes the CIW line *"press ESC to leave"* true from wherever
  the keyboard is. Cost: the window gains a keyboard behaviour, which the
  design deliberately avoided, and `Escape` inside a text widget is otherwise
  free for a future search box.
* **(b) Bind all five (ESC + 1/2/3/4) on `.rdw`,** forwarding to the same procs.
  Consistent, larger, and it makes the window a second keyboard surface — which
  is the thing `src/rdw.tcl:857` argues against.
* **(c) Leave it and change the CIW sentence** to say the mode ends on the
  canvas. Honest, free, and it tells the user to make a pick they do not want.
* **(d) Rule it away** — decide the window should never take the keyboard, which
  un-decides issue 1306 and makes copy-with-the-keyboard impossible again.

**(a) is the recommendation**, but it is not B4-3's to take: it is a
user-visible keyboard behaviour on a surface the design says has none, and the
same ruling that settles it settles issue 1306's own "should the window take the
keyboard at all" question. It is on the ledger as B4-3's `E` question.

## Still open

* Which option. It is the same ruling as 1306's, and it must be taken once.
* Whether `Escape` inside `.rdw.p.t` should also *clear the selection* in the
  pane first and end the mode on a second press, the way many text UIs do.
  Nobody has asked for that; it is recorded so it is not re-derived.
