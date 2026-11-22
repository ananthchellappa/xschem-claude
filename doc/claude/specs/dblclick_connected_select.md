# Cadence-style double-click incremental connected-selection

## Status
IMPLEMENTED. Engine: `select_grow_connected_step()` in `src/select.c`. Trigger:
`handle_double_click()` in `src/callback.c`. Subcommand: `xschem
select_grow_connected [x y]`, a branch of `xschem_cmds_s()` in `src/scheduler.c`.
Suite: `tests/headless/test_dblclick_connected_grow.tcl` (registered on both arms of
the regression). Branch `fluid-editing`. Written 2026-07-12; design decisions RATIFIED
2026-07-12 (see "Ratified decisions" below). Companion plan:
`../suggestions/plan_dblclick_connected_select.md` (a dated record, left as written).

(Corrected 2026-11-21: this section still read "SPEC / DESIGN — not implemented"
long after the feature shipped.)

**Ratified 2026-07-12:** trigger via a `cadence_compat`-gated C branch + subcommand
(not the registry); rings are **wires-only**; 3rd click = **geometric** whole-net
flood; escalation **capped at 3** clicks; LMB double-click **gives up Edit
Properties** under the Cadence profile (`q` opens properties instead — user
confirmed sufficient).

**Ruled 2026-11-21 (by the user, overruling "wires-only" for one class of object):**
every step also takes the **net-name labels** whose pin touches a wire it selects.
See "Ruling of 2026-11-21" below; it is the authority wherever an older sentence of
this file still says "wires only".

## Motivation

Virtuoso lets you double-click an object to **grow the selection outward along
connectivity**, one ring of connected wire segments per double-click, until the
whole net is selected. xschem has all the connectivity machinery
(`select_connected_nets`) but exposes it only as a one-shot (Ctrl-RMB /
Shift-RMB / `xschem connected_nets`). There is no incremental, click-to-grow
gesture.

## Target behavior

Trigger: **double-click** on a schematic object (default gesture = LMB
double-click; see §"Trigger & bindability"). Successive double-clicks on the
**same seed** escalate:

| Click | On a wire | On a pin / net-label / instance |
|---|---|---|
| **1st** | select the wire **+ its immediately adjacent connected wire segments** (one ring). If the wire was not selected, this first double-click both selects it and grows the ring — identical to the result had it been pre-selected. | select the object **+ the wire segments immediately touching its pins/anchor** (one ring). |
| **2nd** | for **each** wire segment selected by click 1, add **its** immediately adjacent wire segments (ring 2). | same — ring 2 from the ring-1 set. |
| **3rd** | **select all** connected wire segments (whole net). | same. |
| **every click** (since 2026-11-21) | **+ every net-name label whose pin touches one of the wires selected so far.** | same. |

- A single (non-double) click anywhere behaves exactly as today (plain select /
  deselect).
- The double click REPLACES the selection: it unselects everything, selects the seed
  again and grows from it (the next section says why). Only the scriptable form
  without coordinates grows the live selection. (Corrected 2026-11-21: this bullet
  said "Double-click is purely additive to the selection", which the implementation
  never was.)
- "Immediately adjacent" = geometric endpoint/junction adjacency between wire
  segments (the split inter-attachment `xWire` records), **not** node-name
  equivalence. Two physically-separate wires with the same net name are NOT one
  ring apart; they are only unified by the 3rd (whole-net) click if that click is
  defined name-wise (see Open question O3).

### Escalation state & reset — IMPLEMENTED as seed-driven recompute

A small state machine keyed on a **seed** (object under the double-click) + a
**level** counter (1 → ring1, 2 → ring2, 3 → whole net; capped at 3).

The interactive gesture / coordinate form **recomputes the selection from the
seed** each call: `unselect_all`, re-select the seed, grow `level` rings (or flood
to fixpoint at level 3). This is the key robustness decision — see "Interactive
reality" below: the surrounding fluid gesture leaves an unpredictable transient
selection, so growing the *live* selection incrementally is unreliable. Recompute
sidesteps it entirely; the selection at level N is a pure function of (seed, N).

**Reset to level 0 (restart)** in two cases:

1. The double-clicked object differs from the stored seed (compared by type +
   session-stable id) — checked inside `select_grow_connected_step`.
2. **ANY intervening non-double gesture** — a single click (anywhere, INCLUDING on
   the seed itself), a drag, a wire draw, etc. The next double-click on the seed then
   restarts at ring1 instead of jumping straight to whole-net.

Case 2 is the subtle one. The live selection CANNOT detect it: a plain click on the
already-selected seed leaves the selection visually unchanged (seed + ring stay
selected), and the double-click's own press re-selects the seed anyway — so neither a
selection-count check nor a seed-identity check can distinguish "continuation" from
"fresh after an intervening click." The only reliable signal is the **event stream**,
and it is read like this (all in `callback.c`):

- A button-1 **RELEASE** that is not a double-click's release2 snapshots the current
  level into `dblgrow_level_save` and **tentatively zeroes** `dblgrow_level`.
- The double-click's **`-3`** handler, right before growing, **restores**
  `dblgrow_level = dblgrow_level_save`. Reaching `-3` proves the preceding
  press/release was the *first half of a double*, not a standalone click, so its
  tentative reset is undone and escalation continues.
- A standalone single click's tentative zero is **never restored** (no `-3` follows),
  so it sticks → the next double restarts at ring1.
- `dblgrow_last_press_was_grow` (set by `-3`, cleared by every non-`-3` button-1
  press) guards the double's own **release2** — whose preceding "press" was the `-3`
  grow — from tripping the reset.

This is robust to the exact double-click event pattern. Ground truth (Tk
`event generate`): a real double fires `P1, R1, <Double>(-3), R2` — the 2nd press
emits ONLY `-3` (the specific `<Double-Button-1>` binding wins over the generic
`<ButtonPress>`), NOT a second callback-4. Because the snapshot is taken at the
*release* (not the press), the mechanism works whether or not a second press-4 is
emitted (the headless test harness injects a synthetic extra press-4; real Tk does
not — both pass). After level 3 (whole net) further double-clicks on the same seed
are no-ops.

Note the **coordinate command** `xschem select_grow_connected x y`, driven directly
(not through a press/release), still escalates on repeated same-seed calls regardless
of an `unselect_all` in between — it never rides the button event stream, so only
case 1 applies. Tests: T5 (coord survives `unselect_all`), T8 (gesture resets on
deselect / off-seed click), T9 (resets on a single click ON the seed — the
selection-invisible case), T10 (escalation + reset under the real `4,5,-3,5` stream).

The scriptable **coordless** form (`xschem select_grow_connected` with no coords)
is instead *incremental* — it grows the current selection by one ring and DOES
reset the level on an external selection change (a `sel_sig` snapshot of
`lastsel`). This is the primitive scripts/tests use.

No timing window of our own — we ride Tk's `<Double-Button-N>`; seed identity, not
a timer, drives escalation.

### Interactive reality — the fluid/pin gesture must be aborted at `-3`

With the Cadence profile (`fluid_editing=1` + `en_pin_select=1`) the **2nd press
of the double-click always arms a transient gesture BEFORE `-3` fires**: a fluid
move-grab (`STARTMOVE`, on a wire or instance body) or a pin wire-arm (`STARTWIRE`
+ `pin_pending`, on an instance pin). So `ui_state` at `-3` is almost never a bare
`0`/`SELECTION`. The trigger (below) detects these transient arms and
`abort_operation()`s them first, then recomputes+grows. It also latches
`place_click_committed` so the **release2** that follows does not run the cadence
"deselect everything but the object under the cursor" collapse (which would undo
the grow). Both were found only by driving the *full* `press,release,press,-3,
release` sequence — a bare `-3` event silently skips the whole problem, so tests
MUST drive the real sequence. Post-mortem:
[`../code_analysis/lessons_gesture_test_full_event_sequence.md`].

(Corrected 2026-11-22: "always arms" is true of a stream that carries a second press,
which is what rows T7 to T9 and G14b of the suite drive: on a wire or a device body that
press arms the move-grab (row G14c). A real Tk double click carries no second press
(the "ground truth" above; row G16a), so nothing is armed when `-3` arrives, and the
abort is there for the streams that do carry one. What the abort restores is not what
keeps the escalation either: with the state a real pointer sends, the first release of
the next double click has already collapsed the grown selection to the seed, and the
step recomputes the selection from the seed.

One such stream is NOT cleanly aborted, measured the same day and left as found: press,
release, press, the double, release on a free device PIN. The second press arms the
wire-draw, the abort drops it and the grow selects what it should, but with
`persistent_command` set the wire command stays remembered (`abort_operation()` keeps
`last_command` on purpose, as the first of the two stages of ESC; the plain click path
on a pin clears it at the release), so the next press anywhere starts a wire. No pointer produces that stream, since Tk hands the
second press over as the double alone; a real double click on the same pin leaves
nothing behind (row G16c). No row drives the stream with the second press on a pin,
and row G14c stays off the pin for that reason.)

## Trigger & bindability

Double-click is **not** expressible in today's `xschem bind` registry (grammar =
`wheel|button|key` + code + mods + ctx + action; no click-count dimension —
`InputBinding` and its parsers in `src/callback.c`). It is hardwired: Tk
`<Double-Button-1/2/3>` → `xschem callback %W -3 …` (installed by `set_bindings` in
`src/xschem.tcl`) → `callback()` → `handle_double_click()` in `src/callback.c`,
bypassing the registry.

Without the Cadence profile LMB double-click = **Edit Properties** (the
`edit_property(0)` call in `handle_double_click()`). `handle_double_click()` receives
`cadence_compat` — the natural gate.

(2026-11-21: the file-and-line coordinates this section and the next carried were
measured in July and had drifted; they now name symbols.)

**RATIFIED path — new subcommand + `cadence_compat`-gated trigger, no registry
change.** `xschem select_grow_connected [x y]` in `scheduler.c` is the scriptable/
rebindable engine entry. IMPLEMENTED (commit 2).

**Trigger — C branch in `handle_double_click`, NOT a Tk rebind.** The plan's
Step 5 first proposed a Tcl rebind of `<Double-Button-1>`. That was rejected in
implementation: the Tk `<Double-Button-1>` binding funnels to synthetic event
`-3` which ALSO terminates in-progress draw gestures (STARTWIRE/STARTLINE/
STARTPOLYGON, the tail of `handle_double_click`); a blind Tk rebind would drop that.
Instead the branch lives inside `handle_double_click`: when
`cadence_compat` and `ui_state` is idle/SELECTION, call
`select_grow_connected_step(mousex, mousey, 1)` and return; an active draw gesture
still falls through to the termination code below. This keeps the `-3` funnel's
screen→schematic conversion, `semaphore>=2`/`ui_state` guards, and gesture
termination — none of which a Tk rebind would have. Still honors O1=A: no
registry-grammar change, gated by `cadence_compat`, subcommand available for
scripting/user-rebind. No `cadence_style_rc` bind line needed (auto under
`cadence_compat`).

(Rejected alternatives: a first-class `dblclick` registry device — more C work;
a Tk `<Double-Button-1>` rebind — loses draw-gesture termination.)

### Default binding
- `cadence_compat=1`: LMB double-click = connected-grow. **Edit Properties on
  double-click is deliberately given up** — reached via `q` instead (user
  confirmed sufficient).
- `cadence_compat=0`: LMB double-click unchanged (= Edit Properties). The
  `select_grow_connected` subcommand still exists; a user may bind it to any Tk
  event (e.g. `<Double-Button-2>`, a free no-op slot today —
  `handle_double_click` acts only on Button1).

## Reused infrastructure (do not reinvent)

- **One-ring grow:** NOT `select_connected_nets(2)`. (Corrected 2026-11-21: this
  bullet called that call "direct neighbors, no recursion". With bit 2 set,
  `check_connected_nets()` skips its whole wire loop: a selected wire gains no
  neighbour, only the label/pin/probe instances on it are marked. The grow has its
  own ring routine, `grow_one_ring_wires()` in `src/select.c`.)
- **Whole net:** the same ring routine run to a fixed point (`dblgrow_apply_level()`),
  not `select_connected_nets(0)`: the one-shot also takes ports and probes.
- **Seed pick:** `select_object(mx,my,SELECTED,override_lock,NULL)` in `src/select.c`
  / `xschem select_at`.
- **Selection model:** per-object `.sel` flag + `xctx->sel_array` rebuilt by
  `rebuild_selected_array()` under `need_reb_sel_arr`. Any `.sel` flip must set the
  dirty flag — the `select_*` primitives already do.
- **Silent compute (for flicker-free multi-ring draw):** `select_wire` and
  `select_element` with `fast` bit 2 = nodraw; the step strokes the selection once.
- **Wire-segment model:** each clickable inter-attachment region is a distinct
  `xWire` (split by `break_wires_at_attach_points` in `src/check.c`); "one ring" =
  the set of `xWire` records whose endpoints touch the current selection. Read
  `doc/claude/specs/wire_segment_splitting.md` and `doc/claude/WIRING.md` before
  touching this.

### Wires-only rings (RATIFIED 2026-07-12; amended 2026-11-21) — needs a thin variant
`check_connected_nets(&2, …)` also auto-selects touching pin/label/probe
**instances** and always hard-marks `SELECTED`, so it is NOT reusable verbatim.
Rings must grow **wire segments only**: a thin wires-only ring routine
(non-recursive bucket walk over `wire_spatial_table` + `touch()`, marking with
`select_wire`, no instance inclusion). The seed object of any type stays selected;
growth never pulls in other devices.

Amended 2026-11-21: the RINGS are still wires only, and that is what keeps the wire
set of every level what it was. The labels are taken by a separate pass after the
rings (next section); a ring never selects an instance.

## Ruling of 2026-11-21 — the grow takes the net-name labels

The user, 2026-11-21: "The double-click to expand wire selection SHOULD select
wire-labels. Why? Sometimes, one does this just to select all connect material to
delete easily." Asked which attached objects each ring should take with its wires,
the user chose **net-name labels only**. This overrules decision O2 ("rings are
wires only": the grow selected no instance at all) for these labels and nothing
else. O1, O3 and O4 stand. The wider sets the user was offered (labels with ports;
everything the older one-shot takes) were not taken.

### What is taken

After the rings of a step, every instance that passes this test is selected with them:

1. its symbol's type is exactly `label` (`inst_is_netlabel()` in `src/check.c`), and
2. its `global` attribute, read from the instance first and then from the symbol (the
   netlister's own two steps), is neither `ground` nor a true boolean, and
3. the symbol has at least one pin, and its first pin touches a wire that is selected
   whole and is not zero-length.

So `lab_pin` and `lab_wire` are taken, which is what the product itself places as a
wire label (Add Wire Label, key `l`; `xschem net_label`; the stubs of the Space key
end in a `lab_pin`). `lab_generic` and `bus_connect` are labels with no `global` and
are taken too. The power symbols of the `vdd` / `gnd` kind are not (their symbols say
`global=true` / `global=ground`); a `lab_pin` whose own attributes say `global=true`
is not; a `vdd` whose own attributes say `global=false` is. Ports (`ipin`, `opin`,
`iopin`), probes, `lab_show`, bus taps and devices are never taken.

The test knows a power symbol by its `global` attribute and by nothing else. The power
symbols of the gschem import library (`xschem_library/gschem_import`) are of type
`label` and carry no `global`, so the grow takes them like a `lab_pin` and a Delete
removes them with the net (rows L11 SGV and SGG place that library's `vdd-1` and
`gnd-1`).

The stubs of the Space key are driven on every side of a device by rows L12c to L12h
and, as gestures, G12a and G12b. Until 2026-11-22 a stub that ran upward or leftward
out of its pin was outside the grow: `add_pin_stubs()` in `src/actions.c` stored it
end-first, so nothing touched it and a click or a double click on its middle picked
nothing, until the sheet was saved and loaded again. It is stored with its end points
in order now.
The merge door had the same gap: `merge_wire()` in `src/paste.c` (`xschem merge`, and
paste) stored a wire as its file wrote it, and one written end-first stayed in that
state when the pending placement was dropped by `xschem unselect_all` instead of being
placed. It orders before it stores now (rows L12i and L12j).

| level | wires | labels |
|---|---|---|
| 1 | the seed (or the wires at the seed's pins) and one ring | every net-name label touching one of them |
| 2 | one more ring | every net-name label touching one of them |
| 3 | every wire that touches, to a fixed point | every net-name label touching the flooded copper |
| 4+ | nothing new | nothing new |

After the third double click, Delete removes the whole touching net with its labels.
The scriptable forms (`xschem select_grow_connected x y`, and the form without
coordinates) take the same labels.

### How

`dblgrow_select_labels()` in `src/select.c`: one pass over the instances after the
rings, in the tail both forms of `select_grow_connected_step()` share, BEFORE the
selection count is stored. The order is load-bearing: the bare form compares that
count on its next call, and a count taken without the labels would make every
following bare call look like an external change and restart at level 1. No new log
line, no change to the log format, the escalation state or undo.

### Decided by the lead (holes the ruling left; each names the rows that hold it)

1. **Labels are leaves.** A label the grow took never carries it onto another wire:
   not across a crossing of two wires that share no end point, and not by name to
   another island (the name-wise select has its own chord, Ctrl+Alt+Shift+LMB). In
   `grow_one_ring_wires()` a net-name label whose pin already sits on a selected wire
   expands onto nothing. The set of WIRES at every level is what it was before the
   ruling, with one exception: in the bare form, a label that the caller selected
   beforehand and that sits on such a crossing used to pull the crossing wire in;
   with a selected wire already under it, it no longer does. A label with no selected
   wire under it is a seed like any other and still expands onto every wire at its pin.
   Only a label the grow can take is a leaf: a power symbol picked by hand still
   expands, even with a selected wire under it. Rows L8a to L8d (the crossing wire is never
   reached), L8e (the exception), L8f and L8g (a label seed), L8h (the power symbol).
2. **"Touches a selected wire" is the whole rule.** A label on the joint between a
   selected wire and one that is not selected yet is taken. So a Delete at level 1 or
   2 can remove the label of a wire that stays. Rows L17b and G17b hold the joint
   label in the level-1 set; rows LP1 to LP4 hold the other side of "touches": a label
   on a wire's end point is on it, a label one grid pitch beside it is not.
3. **Level 3 takes every such label touching the flooded copper.** A fourth double
   click changes nothing. Rows L3 and L4; LM1 and LM2 when the labels on the net carry
   different names.
4. **A label as the seed** behaves as before (it stays selected, the wires touching
   its pin are ring 1) and now also brings the other labels on those wires. Rows L10a
   and L10b.
5. **A device as the seed:** a label that sits directly on a pin of that device, with
   no wire under it, is NOT taken: the rule is about wires. The older one-shot
   (`xschem connected_nets`, Shift-RMB, Ctrl-RMB) does take it. A stated limit. Rows
   L13a and L13b.
6. **Locked labels** follow the wires: the ring routine selects a locked wire, and the
   label pass takes a locked label the same way. Delete then removes both. Rows LK
   and LKb.
7. **`q` after the grow.** Edit Properties prefers an instance in a mixed selection
   (`set_first_sel()` in `src/select.c`). After a grow seeded on a WIRE that took a
   label it therefore opens that label's form, where before the ruling it opened the
   wire's. After a grow seeded on a device or on a label it stays on the seed. Keeping
   it on the wire needs a change in that selection primitive, which other gestures
   share; it was not made. A stated limit, pinned by rows GQ1 (a wire seed), GQ2 (a
   device seed), GQ3 (the way back to the wire's form) and GQ4 (a label seed).
8. **Moving the grown selection.** A selected label is placed by the move itself and
   does not ride its wire (`wire_label_ride.md` §16.4). For a move, a connected drag
   and a copy that changes nothing visible: the labels go with their wires and stay
   on them (rows L17, G17). For ALT-R / ALT-F (rotate or flip each object about its
   own origin) it does: before the ruling the unselected labels rode the turned
   wires; now each selected label turns about its own pin and stays where it was,
   off the turned wire, and the product prints its "stranded" note. Accepted for
   those two keys; rows L17d to L17f pin it as it stands (the pins stay, and which
   labels are left off copper), driven as `xschem rotate_in_place` and `xschem
   flip_in_place`.
9. **Replay.** The log line carries no level and no object list, so an action log
   recorded before the ruling replays with the labels selected too (and a Delete
   after it deletes them). No recorded log under `tests/` held the verb when this
   was written. Row L19 replays three logged lines on a rebuilt fixture.
10. **The stock profile (`cadence_compat` 0) does not change:** its double click
    still opens Edit Properties (rows G18 and G18L). That is said of the DOUBLE CLICK.
    The command `xschem select_grow_connected` is the same engine under either
    profile and takes the labels with `cadence_compat` 0 as well: the L rows of the
    suite run with it off.

Two limits that are not new: the bare form tells an external change of the selection
only by its COUNT, so a change that keeps the count is taken for a continuation; and
a wire of no length is reached by the ring routine (`touch()` answers yes for every
point of its row) but names no label (row LZ).

## Non-goals
- No change to single-click selection, drag, or any non-double-click gesture.
- No change under `cadence_compat=0` unless the user explicitly binds the new
  action.
- Not touching netlist / hierarchy traversal — this is pure in-sheet geometric
  selection.

## Ratified decisions (2026-07-12)
- **O1 — bindability path: A (Tcl rebind + subcommand).** New `xschem
  select_grow_connected`; `cadence_style_rc` rebinds `<Double-Button-1>`. No
  registry-grammar change.
  Corrected 2026-11-21: nothing rebinds `<Double-Button-1>` and the rc has no line
  for it. As "Trigger & bindability" above records, the trigger is a C branch in
  `handle_double_click()` gated by `cadence_compat`; the subcommand and "no registry
  change" are what was built.
- **O2 — ring contents: wires-only.** Rings add only wire segments; seed of any
  type stays selected; no other devices pulled in. Needs the thin wires-only ring
  variant.
  **OVERRULED BY THE USER 2026-11-21 for net-name labels:** the grow also selects
  the net-name labels on the wires it selects ("Ruling of 2026-11-21" above). For
  every other instance (devices, ports, probes, power symbols) O2 stands.
- **O3 — 3rd click: geometric flood** (`select_connected_nets(0)`) — physically
  touching only, same model as rings 1–2. (Node-name net = possible later option,
  out of scope.)
  Corrected 2026-11-22: the decision stands, the call named in it is not what was
  built. The third click runs the ring routine to a fixed point
  (`dblgrow_apply_level()`, see "Reused infrastructure" above);
  `select_connected_nets(0)` would also take ports and probes.
  **SHIPPED SEPARATELY, 2026-08-08:** the node-name option exists on
  its own chord instead of taking over a double-click level — Ctrl+Alt+Shift+LMB /
  `xschem select_same_net`, see [select_same_net_by_label.md](select_same_net_by_label.md).
  This spec's escalation is unchanged and stays purely geometric (a label of the
  same name on another island is not reached, ruling of 2026-11-21, decision 1).
- **O4 — cap at 3.** click1→ring1, click2→ring2, click3→whole net (jump,
  regardless of net size), click4+→no-op.
- **Edit Properties on double-click: given up** under the Cadence profile; `q`
  covers it (user confirmed).
