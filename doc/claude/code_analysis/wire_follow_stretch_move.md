# Wire-follow on move: stretch, orthogonal rubber-banding, and the gap to Cadence

**Status:** analysis / tutorial. No code changed yet. Captures what we learned
diagnosing "grab a component, move it, and the attached wires don't follow the way
Cadence does." Work to be scheduled later.

**Related:** `doc/claude/FAQ.md` Q14 (verb-noun vs noun-verb, the broader
interaction-grammar gap). This doc is the deep-dive on the *wire-follow* half.

---

## 1. The user-visible symptom

Running with `src/cadence_style_rc` loaded (`xschem --script .../cadence_style_rc`),
grab a resistor R18 by left-click-hold-drag and move it:

- **Move right:** the wire on the *top* pin followed and stayed connected; the wire
  on the *bottom* pin was **left behind** (disconnected).
- **Move down:** the routing became a tangle — "the wire routing did not cooperate."

In Cadence the equivalent gesture just works: you drag the device, attached wires
rubber-band along, staying orthogonal and connected. That "you just grab things and
move them and wires stay connected" feel is one of the nicest things about the
editor, so it's worth getting right.

This is **not** a missing feature in xschem — both halves of the behavior already
exist. It's two code-level limitations that surface once you turn everything on.

---

## 2. The mental model: two independent switches

Wire-follow-on-move is governed by **two orthogonal (pun intended) settings**, and
crucially they are **both OFF by default**:

| Switch | TCL var | Default | Question it answers |
|---|---|---|---|
| 1 — *stretch* | `enable_stretch` | `0` (`xschem.tcl:12021`) | Does an attached wire follow **at all**? |
| 2 — *orthogonal* | `orthogonal_wiring` | `0` (`xschem.tcl:12045`) | If it follows, does it stay **Manhattan** (auto-jog) or go diagonal? |

Get this distinction wrong and you'll chase the wrong bug. "Wire didn't follow" is a
Switch-1 question; "wire followed but looks diagonal/ugly" is a Switch-2 question.

### `cadence_style_rc` turns BOTH on (and more)

```tcl
set enable_stretch 1       ;# Switch 1 ON
set orthogonal_wiring 1    ;# Switch 2 ON
set infix_interface 0      ;# verb-noun / prefix command ordering
set cadence_compat 1       ;# Cadence bindkey bundle (Ctrl=sim, click-clears-sel, snap cursor)
set persistent_command 1   ;# armed verbs repeat
set snap_cursor 1
set use_cursor_for_selection 1
```

The important consequence for diagnosis: **with this rc, there are no more knobs to
turn.** Anything still wrong is residual *code* behavior, not misconfiguration.

---

## 3. How Switch 1 works — `select_attached_nets()`

`select.c:1317`. At the start of a stretch-move, for every selected instance it walks
the symbol's pins and looks for wires whose endpoint sits on a pin:

```c
get_inst_pin_coord(inst, r, &x0, &y0);          /* pin r absolute coordinate */
get_square(x0, y0, &sqx, &sqy);                 /* spatial-hash bucket */
for(wptr = xctx->wire_spatial_table[sqx][sqy]; wptr; wptr = wptr->next) {
  i = wptr->n;
  if(xctx->wire[i].x1 == x0 && xctx->wire[i].y1 == y0) select_wire(i, SELECTED1, 1, 0);
  if(xctx->wire[i].x2 == x0 && xctx->wire[i].y2 == y0) select_wire(i, SELECTED2, 1, 0);
}
```

A matched wire gets a **partial** selection — `SELECTED1` (endpoint 1 only) or
`SELECTED2` (endpoint 2 only). During the move, only the selected endpoint travels;
the other stays put → the wire stretches / rubber-bands.

Where it's called from (the gating logic differs per entry path):
- Intuitive left-drag of a selected object: `callback.c:5236-5240`
  (`int stretch = (state & ControlMask ? 1 : 0) ^ enable_stretch;` — Ctrl *reverses*
  the stretch sense, then `if(stretch && !Shift) select_attached_nets();`).
- Key-triggered move/copy: `callback.c:4002, 4018, 4059`.
- `xschem move_objects stretch` / `copy_objects stretch`: `scheduler.c:880, 3910`.

### The limitation (this is the dropped-wire bug)

The match is **exact floating-point endpoint equality** (`==`). A wire follows only
if one of its two *endpoints* is bit-for-bit equal to the pin coordinate. Two common
real-world cases defeat it:

1. **T-junction / mid-span connection** — the pin sits in the *middle* of a wire's
   span (the wire passes *through* the pin). Neither endpoint equals the pin, so the
   wire is ignored and left behind.
2. **Sub-grid coordinate mismatch** — the symbol's pin lands at a coordinate that the
   wire endpoint was snapped *near* but not exactly *onto*. The `==` fails; the wire
   is dropped even though it looks connected.

This exactly explains the "move right, bottom wire left behind" picture: with
`enable_stretch=1` already set, `select_attached_nets` *did* run, so the only thing
that can leave a wire behind is failing this exact-endpoint test.

---

## 4. How Switch 2 works — orthogonal jog insertion

When a partially-selected wire is committed in `move_objects(END)`, each wire goes
through `place_moved_wire(n, orthogonal_wiring)` (`move.c:1021`, called at
`move.c:1280`). `orthogonal_wiring` is read once from the TCL var
(`move.c:1149`).

If orthogonal wiring is on, it first calls:

```c
recompute_orthogonal_manhattanline(rx1, ry1, rx2, ry2);   /* actions.c:4128 */
```

which sets `xctx->manhattan_lines` to **1 (H-then-V)** or **2 (V-then-H)** — and
*never* 0:

```c
if(dx*dx > dy*dy) manhattan_lines = 1;   /* longer leg first: horizontal */
else              manhattan_lines = 2;   /* longer leg first: vertical   */
```

`place_moved_wire` then rewrites the moved wire into an **L** by adjusting its two
endpoints and `storeobject`-ing an extra segment for the second leg
(`move.c:1042-1075` for the `& 1` case, `1092-...` for `& 2`). So a wire that *does*
follow keeps a Manhattan route.

During an active drag, **Spacebar** cycles `manhattan_lines` `0 → 1 → 2`
(`callback.c:4602-4606`) so you can flip the jog direction live (also works while
drawing wires/lines).

### The limitation (this is the "tangle" / messy-routing bug)

`recompute_orthogonal_manhattanline` is the *entire* routing intelligence, and it is:

- **per-wire and context-blind** — it knows only that one wire's two endpoints; it has
  no awareness of the symbol body, other pins, or other wires. So it will happily lay
  a jog straight across R18 or across another net.
- **a fixed heuristic** — "longer leg first," nothing more. No attempt to minimize
  crossings or match the pre-move routing intent.
- **followed by no cleanup** — there is no pass at `move_objects(END)` to merge
  newly-colinear segments or drop zero-length / redundant jogs. Repeated drags
  accumulate cruft.

Combine context-blind jogs on the wires that *did* follow with the wire that got
*dropped* (§3), and you get the "move down → disaster" tangle.

---

## 5. Putting it together — the two pictures, fully explained

| Observation | Root cause | Switch state |
|---|---|---|
| Bottom wire **left behind** on move-right | `select_attached_nets` exact-endpoint `==` match misses T-junctions and sub-grid mismatches (`select.c:1330-1340`) | `enable_stretch=1` was already on → **not** config; genuine code gap |
| Routing **tangled** on move-down | followed wires *do* jog (`recompute_orthogonal_manhattanline` always picks 1 or 2), but the jog heuristic is context-blind and there's no cleanup; plus the dropped wire adds to the mess | `orthogonal_wiring=1` was already on → **not** config |

Key takeaway: **`cadence_style_rc` has already done everything configuration can do.**
What remains is purely code.

---

## 6. The fix plan (priority order)

1. **Tolerant / mid-span `select_attached_nets`** — *highest value; directly fixes the
   dropped wire.* In addition to exact-endpoint matches, do a **point-on-segment** test
   for each pin against nearby wires, and use a **snap-tolerance** comparison instead
   of `==`. When a pin lies on a wire's interior, split the wire at the pin and stretch
   the resulting endpoint (or introduce a stretch vertex). Contained to `select.c`; the
   downstream move/`place_moved_wire` machinery is already ready to carry the partial
   selection.
   - *Decide first* (open the actual `.sch`): is the bottom pin a **T-junction** or a
     **sub-grid mismatch**? The fix differs slightly — point-on-segment+split vs.
     tolerant endpoint compare. Likely want both.
   - *Testable headlessly:* place instance + wires, `xschem move_objects <dx> <dy>`,
     assert the previously-dropped wire is now stretched and still electrically
     connected (check node continuity via `prepare_netlist_structs` + net query).

2. **Release-time cleanup** — at `move_objects(END)`, merge newly-colinear wire
   segments and drop zero-length / redundant jogs, so routing stays tidy across
   repeated drags.

3. **Smarter jog direction** — make `recompute_orthogonal_manhattanline` (or its
   caller) aware of the wire's *far* anchor, the symbol body, and ideally neighboring
   wires, instead of "longer leg first." Even a small improvement (jog away from the
   symbol body) removes most of the obvious tangles.

4. *(Optional, behavior change — needs sign-off)* **Defaults / discoverability.**
   Cadence does all this with zero ceremony. Consider whether stretch+orthogonal should
   be the default for instance drag, or at least be surfaced more prominently than two
   buried Option-menu checkbuttons. This changes long-standing xschem behavior, so it's
   a user decision, not a silent flip.

Item 1 alone converts "a wire got left behind" into "it follows." Items 2–3 are what
make the *followed* wires look like a human routed them.

---

## 7. Code map (quick reference)

| What | Where |
|---|---|
| `enable_stretch` default / menu | `xschem.tcl:12021`, `:10945` |
| `orthogonal_wiring` default / menu | `xschem.tcl:12045`, `:10949` |
| Stretch toggle key `y` | `callback.c:2812` → `edit.toggle_stretch` |
| Stretch attached nets (Switch 1) | `select_attached_nets()` `select.c:1317` |
| Exact-endpoint match (the limitation) | `select.c:1330-1340` |
| Intuitive-drag stretch dispatch | `callback.c:5236-5251` |
| Move commit / orthogonal arg source | `move_objects()` `move.c:1149` |
| Orthogonal jog insertion (Switch 2) | `place_moved_wire()` `move.c:1021-1140` |
| Jog-direction heuristic | `recompute_orthogonal_manhattanline()` `actions.c:4128` |
| Live jog-direction cycle (Spacebar) | `callback.c:4602-4606` |
| `manhattan_lines` semantics | `1` = H-then-V, `2` = V-then-H, `0` = free/diagonal |
| Stretch-move from script | `xschem move_objects stretch` → `scheduler.c:880` |

---

## 8. Glossary

- **Stretch-move** — a move where a *partially* selected wire (one endpoint,
  `SELECTED1`/`SELECTED2`) has only that endpoint dragged, so the wire grows/shrinks
  rather than translating rigidly.
- **`manhattan_lines`** — runtime state (not a saved setting) for how a stretched/drawn
  segment is laid out: `0` diagonal, `1` horizontal-leg-first, `2` vertical-leg-first.
- **Rubber-banding** — the Cadence term for attached wires elastically following a
  moved object while staying orthogonal and connected. xschem's stretch + orthogonal
  wiring is the partial equivalent; §6 is what would close the gap.
