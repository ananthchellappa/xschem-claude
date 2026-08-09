# 0268 — `ui_state2` survives ESC: `clear_orphan_gesture_bits()` clears one state word and not the other

Status: **FIXED 2026-08-09** on `open_pdk` for the SHAPE family, as a by-product of issue **0269**
(`abort_shape_draw()` owns both words). Verdict on the defect itself: **INERT** — a reporting lie,
not a behavioural defect, established by enumerating every reader. The **wire family** has the
identical residue, is inert for the identical reason, and is deliberately **NOT** fixed; it is
asserted as still-present so a future change is noticed.
Area: `src/callback.c` (`clear_orphan_gesture_bits()`, `abort_operation()`, `abort_shape_draw()`)
Tests: section **G** of `tests/headless/test_shape_draw_gate.tcl` (22 rows). Was: none.
Found: 2026-08-08 in the phase-3 session prompt; measured and adjudicated 2026-08-09.
Related: **0269** (the teardown that closes it), **0243 F3** (which added
`clear_orphan_gesture_bits()` and wrote down the "a teardown owes by hand every clear the terminal
would have done" rule this issue tests), **0200** (`MENUSTARTDESCEND`, the one arm that already
cleared its own `ui_state2` bit).

## Measured, before

`clear_orphan_gesture_bits()` cleared `ui_state` bits only, and its own comment said so
deliberately: *"ui_state2 is deliberately untouched — abort_operation() has never cleared it on any
path (WIRING.md §7), and clearing it on one path only would make that inconsistency worse."*

```
xschem arc gui   ; xschem wire gui ; xschem abort_operation   ->  ui=0  ui2=64   MENUSTARTARC
xschem circle    ; …                                          ->  ui=0  ui2=128  MENUSTARTCIRCLE
xschem zoom_box  ; …                                          ->  ui=0  ui2=8    MENUSTARTZOOM
xschem rect gui  ; …            (infix_interface 0)           ->  ui=0  ui2=4    MENUSTARTRECT
xschem polygon gui ; …          (infix_interface 0)           ->  ui=0  ui2=32   MENUSTARTPOLYGON
```

## The verdict: inert, and why that is a measurement rather than an assumption

The session prompt asked for this to be **proved** inert or **proved** a defect, on the grounds
that 0243 F3's whole lesson is that a teardown owes by hand every clear the terminal would have
done. The proof is domination, and it is total:

- **`ui_state2` has 24 read sites**, all in `src/callback.c` and `src/scheduler.c`; no other `.c`
  file and no production `.tcl` ever reads it. Six are `dbg()` / `Tcl_SetResult` reporting.
- Every semantic read is dominated by a test of a bit in **`ui_state`** — `MENUSTART` for the
  fifteen `check_menu_start_commands()` arms, `MENUSTART` again for the two teardown tests. There
  is no reader reachable while `ui_state` has no `MENUSTART`.
- **Every arming site ASSIGNS `ui_state2` wholesale** (`xctx->ui_state2 = MENUSTARTxxx;`), never
  `|=`. So the next arm overwrites a stale bit before any reader can see it.

A stale `ui_state2` therefore cannot be misread as a live arm. What it *can* do is make
`xschem get ui_state2` lie about what is armed — which is exactly what the 0200/0201 descend tests
assert on, and why `abort_operation()`'s descend arm already clears `MENUSTARTDESCEND` by hand,
calling it "hygiene rather than necessity".

## Why it is fixed anyway, and only for the shapes

Issue 0269 gives the shape family a real owner, `abort_shape_draw()`, and that owner clears both
words together — so closing this costs nothing and removes a second place that knew half the state.
`clear_orphan_gesture_bits()` is now `abort_shape_draw()` plus a bare `&= ~MENUSTART` for the
NON-shape menu arms (pending move / copy / wirecut / rotate / descend), which own no rubber band
and whose `ui_state2` bits `abort_shape_draw()` must not touch — a blanket `ui_state2 = 0` there
would silently cancel a pending descend pick. Test **E7** pins that.

The clear runs on **both** shape paths, not just the menu one. The first version only cleared while
`MENUSTART` was still set; the RED pass found that the first canvas click *consumes* `MENUSTART`
and leaves the discriminator behind, so a clicked-then-abandoned arc kept `ui_state2 =
MENUSTARTARC` with `ui_state == 0`. Same lie, one step further along, and section **G**'s
clicked-state rows are what caught it.

## What is NOT fixed, stated rather than hidden

The **wire family** has the identical residue: under `infix_interface 0`, `xschem wire gui` assigns
`ui_state2 = MENUSTARTWIRE` and ESC leaves it there, because the only thing that zeroes the word is
`abort_wire_line_command()` and `abort_operation()` never calls it for a menu-armed wire. It is
inert by the same domination argument. It is not fixed here because closing it means changing what
ESC does with a wire/line arm — the two-stage ESC and `last_command` are load-bearing there
(issue 0240), and this phase has no measurement of that path. Test **G2** asserts the residue is
**still present**, so the day it changes, something says so.

```
infix_interface 0 ; xschem wire gui ; xschem abort_operation  ->  ui=0  ui2=1   MENUSTARTWIRE
```
