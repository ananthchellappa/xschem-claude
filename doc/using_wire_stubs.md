# Using wire stubs + auto net-labels (`add_pin_stubs`)

*A hands-on demo / tutorial for the "add pin stubs + labels" edit operation: draw a short
wire stub out of each instance pin and drop a `lab_pin` net-label "flag" at the far end.*

- **Feature spec / design notes:** `doc/claude/specs/wire_stub_netlabel.md`
- **Not to be confused with** `doc/wire_exit_stub.md` — that is a *different*, experimental
  option (`wire_exit_stub`) about keeping a stub out of a pin **while you move/stretch a
  component**. This document is about the on-demand **`add_pin_stubs`** operation (SPACE key
  / Symbol menu / `xschem add_pin_stubs` command).

---

## 1. What it does

Select an instance (or individual instance pins) and invoke the operation. For each pin
that gets processed it:

1. draws a short **wire stub** straight out of the pin (along the pin's outward direction),
2. places a **`lab_pin` net-label** at the stub's far end, named after the pin,
3. orients the label so its text reads **away from the instance** — "a flag in the wind".

Rules:

- **Whole instance selected** → every pin that is **not already connected** gets a
  stub + label. (An already-wired pin, or one abutting another instance's pin, is skipped.)
- **Individual pins selected** → only those pins (still skipping any already wired).
- **Stub length** is the smallest on-grid length greater than **2× the label text height**,
  so the flag always clears the stub.
- **Label text size** = the pin's own name-text size; when several pins are processed the
  **median** of their sizes is used (one oversized pin can't blow up every stub).

---

## 2. Quick start

Launch xschem the usual way (Cadence-style config):

```sh
cd <repo>
DISPLAY=:0 src/xschem --script src/cadence_style_rc --logdir /tmp
```

You need an instance with a few **unconnected** pins. Use any of your subcircuit/opamp
symbols, or drop in this tiny four-sided test block. Save it as e.g. `~/stubtest.sym`:

```
v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit}
V {}
S {}
E {}
B 4 -17.5 -17.5 17.5 17.5 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=WEST dir=in show_pinname=true}
B 5 17.5 -2.5 22.5 2.5 {name=EAST dir=out show_pinname=true}
B 5 -2.5 -22.5 2.5 -17.5 {name=NORTH dir=in show_pinname=true}
B 5 -2.5 17.5 2.5 22.5 {name=SOUTH dir=out show_pinname=true}
```

In xschem: **File ▸ Insert symbol** (`Shift+I`), pick `~/stubtest.sym`, and click to drop it
on an empty schematic. You should see a box with four pins labelled WEST/EAST/NORTH/SOUTH.

---

## 3. Three ways to invoke it

| Surface | How | Notes |
|---|---|---|
| **Key** | select, then press **SPACE** | default binding `edit.add_pin_stubs`; rebindable |
| **Menu** | **Symbol ▸ "Add pin stubs + labels"** | shown right under *Check pin names*, accelerator `Space` |
| **Command** | `xschem add_pin_stubs [-prefix <s>] [-suffix <s>] [-inst-prefix]` | scriptable; the only way to set naming options |

All three share the same core, so they behave identically (except the command exposes the
naming options).

---

## 4. Eyeball walkthrough

### 4.1 Core — SPACE adds stubs + labels ⭐

1. Click the instance **body** to select the whole instance (turns green).
2. Press **SPACE**.
3. **Expect:** a short stub grows out of *each* pin, with a `lab_pin` flag at each far end
   named after the pin (WEST, EAST, NORTH, SOUTH). The view does **not** pan.

Same result from **Symbol ▸ "Add pin stubs + labels"**.

### 4.2 "Flag in the wind" orientation (the signature visual) ⭐

Look closely at the four labels:

- **WEST** stub points left → the text extends **further left**, away from the box.
- **EAST** points right → text extends **further right**.
- **NORTH** / **SOUTH** point up / down → those read **vertically**, extending away.

Every label leans **outward**, never back over the body. Zoom in to confirm the stub is
long enough to clear the label height (stub length > 2× text height).

### 4.3 Only unconnected pins (whole-instance mode)

- Undo, then draw a wire (`w`) touching one pin. Select the whole instance and press SPACE.
- **Expect:** that pin is **skipped**; the other three get stubs. (A pin abutting another
  instance's pin is treated as connected and skipped too.)

### 4.4 Individual pins only

- Undo. Select just some pins (click the pins if pin-selection is enabled, or use the
  console: `xschem select pin x1 0; xschem select pin x1 2`) and press SPACE.
- **Expect:** only those pins get stubs (still skipping any that are already wired).

### 4.5 Median sizing (finer check)

- Give the pins different name sizes in the `.sym`, e.g. add `name_size=0.6` to one pin and
  `name_size=0.15` to another, leave the rest default. Reload, place, select, SPACE.
- **Expect:** all labels come out at the **median** size — not dominated by the big pin.

### 4.6 Naming options (command only)

In the Tcl console (press `=`), with the instance selected:

- `xschem add_pin_stubs -inst-prefix` → `x1_WEST`, `x1_EAST`, …
- `xschem add_pin_stubs -prefix n_ -suffix _p` → `n_WEST_p`, …
- default (no options / SPACE / menu) → the bare pin name.

> **Heads-up:** identical label names on different instances *short* those nets. Use
> `-inst-prefix` (or a `-prefix`/`-suffix`) when you want per-instance-unique net names.

### 4.7 One undo removes everything

After any add, press **Undo** (`u`) **once** → every stub wire **and** label from that
operation disappears together (a single undo step).

---

## 5. How SPACE coexists with pan and Manhattan-cycle

SPACE only adds stubs when it actually *can*; otherwise it falls back to its historical
behavior, so it is never a "dead key":

| Situation | What SPACE does |
|---|---|
| Something stubbable selected, idle | **adds stubs** |
| Nothing selected | **drag-pan** the canvas (hold + move) |
| Only a non-stubbable object selected (a wire, text, rect) | **drag-pan** |
| Mid gesture (drawing a wire/line, or moving) | **cycles the Manhattan corner** of the rubber-band |
| Read-only view | **drag-pan** (the edit is refused silently — see §6) |
| Editor busy (a modal dialog is up) | falls through to pan/cycle; never edits re-entrantly |

Try it: with **nothing** selected, hold SPACE and drag → the view pans. Start a wire (`w`),
move so the rubber-band follows, then tap SPACE a few times → the corner routing flips.

### Rebinding the corner-cycle (free SPACE entirely for stubs)

The Manhattan-corner cycle is its own action (`edit.cycle_manhattan`), shipped unbound, so
you can move it to a dedicated key. In the Tcl console:

```tcl
xschem bind key 96 0 canvas edit.cycle_manhattan   ;# backtick ` now cycles corners mid-gesture
```

Persist it in your `cadence_style_rc`, or add a row to `keybindings.csv`:
`key,96,0,canvas,edit.cycle_manhattan,`. The drag-pan is likewise a rebindable action
(`view.pan`, also shipped unbound).

---

## 6. Read-only views

`add_pin_stubs` mutates the schematic, so it is refused in a **read-only** view through
*every* entry point — the SPACE key, the Symbol menu item, and the `xschem add_pin_stubs`
command all do nothing. On the SPACE path the key simply **pans** instead (no modal
dialog). Make the view editable first (**Edit ▸ Make Editable**, or `Ctrl-2` from a
read-only descend) to add stubs.

---

## 7. Reference

**Command**

```
xschem add_pin_stubs [-prefix <s>] [-suffix <s>] [-inst-prefix]
```

Returns the number of stubs added (0 if nothing was stubbable, symbol-edit mode, or
read-only). Net name = `[<instname>_ if -inst-prefix][<prefix>]<pinname>[<suffix>]`.

**Actions / default bindings**

| Action id | Default | Purpose |
|---|---|---|
| `edit.add_pin_stubs` | **Space** (idle-gated) | add stubs + labels to the selection |
| `edit.cycle_manhattan` | *(unbound)* | cycle the Manhattan corner of an in-progress gesture |
| `view.pan` | *(unbound)* | drag-pan the canvas |

**Sizing / geometry rules**

- Label size `S` = median of the processed pins' name-text sizes (a pin with no explicit
  `name_size` uses the render default, 0.2).
- Stub length `L` = smallest `cadgrid` multiple strictly greater than `2 × H`, where `H` is
  the label line height at size `S`.
- Outward direction = pin center − symbol body center, snapped to the dominant axis
  (Manhattan), transformed through the instance's rotation/flip.
- A pin with no name (and no prefix/suffix to fill in) is skipped rather than dropping a
  blank net-label.

---

*This tutorial mirrors the automated coverage in `tests/wire_stub_netlabel.tcl` (headless)
and `tests/headless/test_wire_stub_bindings.tcl` (live key routing); if a step here behaves
differently, one of those is the source of truth.*
