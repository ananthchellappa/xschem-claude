# 1767 — the double-click grow leaves out a label that sits on a pin of the device

**STAMP:** `v1 claim=fixed tree=540e4e56a stamped=2026-11-25 fix=taken open=2 by=driver-1767`

Reported by the user on 2026-11-25 and fixed the same day. Two things are open, listed
under "Open".

## What the user wrote

> work was done previously on ensuring wire-labels get selected by the
> double-click-to-extend-wire-selection thing. What I find is that wire-labels DON'T get
> selected if they are connected to the instance being double-clicked on directly (i.e.,
> without an intervening wire segment). Could you fix?

## What it was

Not a slip of the code: the first ruling (2026-11-21, "the grow takes the net-name
labels") was built as "a label whose pin touches a selected WIRE", and the case of a
label put straight on a pin of the double-clicked device was written down as a stated
limit (decision 5 of that ruling in `doc/claude/specs/dblclick_connected_select.md`,
rows L13a and L13b of the suite, FAQ Q96). The user's report overrules that limit.

## What was built

- **The rule.** The label pass of a grow step (`dblgrow_select_labels()` in
  `src/select.c`) takes a net-name label whose first pin touches a selected wire, as
  before, **or sits exactly on a pin of an instance that is selected when the pass
  begins**. That is the device that was double-clicked; in the form without coordinates,
  every instance of the selection it grows.
- **Which labels** is unchanged: a symbol of type `label` whose `global` attribute is
  neither `ground` nor a true boolean. Power symbols, ports, probes, `lab_show` and bus
  taps on a pin are left, as on a wire.
- **Where the pins are read.** `dblgrow_selected_pins()` lists the pins of the selected
  instances off the selection flags before the pass selects anything. It does not read
  the instance spatial table, so the answer does not depend on that table being up to
  date.
- **The wires of every level are what they were.** The ring routine selects no wire it
  did not select before.
- **Labels stay leaves.** In `grow_one_ring_wires()` a label taken from a pin expands
  onto nothing at the next step of the bare form, like a label taken from a wire.
- Both forms of the command and the gesture share the pass, so `xschem
  select_grow_connected x y`, the form without coordinates and the double click of the
  Cadence profile all take the label. The log line is unchanged.

## Rows

`tests/headless/test_dblclick_connected_grow.tcl`, registered on both arms.

| row | what it holds |
|---|---|
| LF8 | the fixture: a label exactly on the free pin of the device, on no wire; a decoy label one grid pitch beside that pin; the seed point picks the device |
| L13a | seeded on the device, four steps: the label on its bare pin is in every set, with the wire at the other pin and the labels on the wires; the decoy never |
| L13b | the older one-shot (`xschem connected_nets`) takes that label too |
| L13c, L13d | Delete after one step removes the device, its wire, the label on that wire and the label on its pin, and nothing else; one undo brings them back |
| L13e | the form without coordinates, after a pick of the device: the same sets |
| L13f | seeded on the wire at the device's other pin: the device is not selected and the label on its bare pin is taken at no level |
| L13m, L13mn | one step on the device, moved three ways: the label went along and is still on the pin |
| LF18, L13s, L13sn | the scope table of the first ruling with each symbol on a pin of a seed device and no wire on the sheet: what is taken from a pin is what is taken from a wire |
| LF19, L13t, L13u | two labels on one point with no wire under them are taken together, seeded on either |
| L13v | two labels picked by hand on one point of an unselected wire are two seeds: their wire comes |
| LF20, L13w, L13x | a `label` symbol with two pins, taken by its first: the wire on its second pin and a label on its second pin are never reached, in either form |
| G13a, G13b | as gestures, both event streams: three double clicks on the device give the sets of L13a, nothing is made, lost, moved or left armed |
| G13c | one real Tk double click on the device: the set of level 1, no window opened, Edit Properties stays on the device, Delete removes the device, its wire and both labels |

The bank question is `dblclick-pin-label`.

## Breaks

Each is one change to `src/select.c`, built and run against the suite on the display
arm and with `--nogui` (2026-11-25, on the tree of this change).

| | what was broken | rows that turn red |
|---|---|---|
| b1 | the label pass reads no pin (the rule as it was) | L13a, L13c, L13e, L13m, L13s, L13t, L13u, L13w, L13x, G13a, G13b, G13c |
| b2 | a selected label offers no pin to the label pass | L13t, L13u |
| b3 | a selected label offers every pin it has, not the first only | L13x |
| b4 | a label taken from a pin is no leaf in the ring routine | L13x |
| b5 | the ring routine counts the pins of selected labels when it asks for leaves | L13v, and rows of the first ruling: T3, L8f, L8g, L10a, L10b, L12e, GQ4 |
| b6 | a label on a pin is taken whatever its `global` attribute says | L13s, L8h |
| b7 | the pins of instances that are not selected count too | L13f, and most rows of the suite that name a whole set |
| b8 | a pin within one grid pitch of the label counts as the pin under it | L13a, L13c, L13e, L13m, G13a, G13b, G13c |

## The builder's choices (not ruled by the user)

1. **Every selected instance offers its pins, not a device only.** A port or a power
   symbol that is double-clicked takes the net-name label on its pin as a device does.
2. **Two labels on one point with no wire under them go together.** A selected label
   offers its first pin, so the second label on it is taken. Without this a label put
   on another label stayed behind after a Delete.
3. **The pin of a device the grow did not select offers nothing.** A grow seeded on a
   wire never selects a device, so a label on another pin of a device that wire ends on
   is not taken (row L13f). The request names the instance that was double-clicked.
4. **Exactly on the pin.** A label one grid pitch beside the pin, on no wire, is not
   taken (the decoy of LF8).

## Open

1. The user's ruling on the four choices above.
2. The user's own look, on their screen: a double click on a device of their design
   that carries a label straight on a pin.

## Not checked

- The user's own screen and pointer. Every run here was on a hidden display under
  openbox; rows G13a to G13c send the events a pointer sends.
- A schematic of the user's design.
