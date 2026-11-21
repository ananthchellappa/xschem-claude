# Work order 04 — the double-click grow takes the net-name labels on the wires it selects

Prepared 2026-11-21.

## The request

The user: "The double-click to expand wire selection SHOULD select wire-labels. Why?
Sometimes, one does this just to select all connect material to delete easily."

## Ruled by the user on 2026-11-21

Asked which attached objects each ring should take with its wires, the user chose
**net-name labels only**: `lab_pin` and `lab_wire` labels whose pin touches a selected
wire. Power symbols of the `vdd`/`gnd` kind are not taken; they are told apart by their
`global` attribute. Ports (`ipin`, `opin`, `iopin`), probes, `lab_show`, bus taps and
devices are not taken.

As a test: the symbol's type is exactly `label` (`inst_is_netlabel()` in `src/check.c`)
AND its `global` attribute, read from the instance first and then from the symbol, is
neither `ground` nor a true boolean. `lab_generic` and `bus_connect` are labels with no
`global` and so are taken; say so in the spec.

This overrules decision O2 ("rings are wires only") of
`doc/claude/specs/dblclick_connected_select.md`, ratified 2026-07-12, for these labels
only. O1, O3 (the third level is a GEOMETRIC flood) and O4 (cap at three) stand.

## What the user gets

Under the Cadence profile, a double click on a wire (or on a label or pin) selects, at
each level, the wires it selects today plus every net-name label whose pin touches one
of those wires. After the third double click, Delete removes the whole touching net with
its labels. The scriptable forms (`xschem select_grow_connected x y` and the form without
coordinates) do the same.

## What is true today

Read from the code on 2026-11-21 at `7c77f3594`, not run. Full notes:
`/home/analog/dev/xschem-claude/doc/claude/overnight_batch_2026_11_21/maps/04_dblclick-grow-takes-labels.map.json`
(read only). A skeptic's corrections, if any, are at the foot of this work order.
Reproduce first; the tree wins.

- `handle_double_click()` (`src/callback.c`) calls `select_grow_connected_step()`
  (`src/select.c`), which picks the seed, keeps the level, recomputes from the seed (the
  coordinate form) or grows the live selection (the coordless form), and then, in a tail
  both forms share, rebuilds the selection, stores a selection COUNT in `dblgrow_sel_sig`,
  writes one action-log line and draws.
- `dblgrow_apply_level()` calls `grow_one_ring_wires()`: once per level for levels 1 and
  2, to a fixed point for level 3. That routine marks wires only; its ELEMENT arm expands
  from every selected instance's pins. No instance is ever selected by the grow.
- `tests/headless/test_dblclick_connected_grow.tcl` is in no list of
  `tests/run_regression.tcl`, exits at its top when there is no display, and issues
  `update` with no stall bound. Its rows T1a and T6, and row T2 of
  `tests/headless/test_select_same_net_by_label.tcl` (also in no list), are the old
  ruling written as rows.

## Decided by the lead (spec holes; the receipt lists them for the user)

1. **Labels are leaves.** The set of WIRES at every level stays exactly what it is today.
   A label never carries the grow onto another wire: not across a crossing where two
   wires share no endpoint, and not by name to another island. (The name-wise selection
   has its own chord, Ctrl+Alt+Shift+LMB.)
2. **"Touches a selected wire" is the whole rule.** A label on the joint between a selected
   wire and one not yet selected is selected. The spec says what follows: deleting at
   level 1 or 2 can take the label of a wire that stays.
3. **Level 3 takes every such label touching the flooded copper.** A fourth double click
   changes nothing.
4. **A label as the seed** behaves as today (it stays selected, the wires touching its
   pin are ring 1) and now also brings the other labels on those wires.
5. **Locked labels** follow what the wire walk does for locked wires. State the choice in
   the spec.
6. **`q` after the grow.** Edit Properties prefers an instance in a mixed selection, so
   after a wire-seeded grow that selected labels it may open a label's form where it
   opened the wire's. Measure what it does today and after. If `q` can stay on the object
   the user double-clicked by a change inside the grow itself, do that. If it needs a
   change in a selection primitive other gestures share, do not make it: leave it,
   describe it in the spec, and return a `rule` debt.
7. **ALT-R / ALT-F on the grown selection:** a selected label is placed by the move
   itself and does not ride its wire (section 16.4 of
   `doc/claude/specs/wire_label_ride.md`). Accepted; describe it and return a `rule` debt.
8. **The stock profile (`cadence_compat` 0) does not change.**

## How

One label pass after the rings, in `src/select.c`, in the tail both forms share and
BEFORE the selection count is stored: for every instance that passes the test above, is
bound to a symbol, has at least one pin rectangle and is not selected, read pin 0 and
select the instance quietly when the pin touches a selected wire that is not
zero-length. So that a label the grow added is not an expansion source on the next
coordless step, the ring routine's ELEMENT arm leaves out a net-name label whose pin
already touches a selected wire; a label seed with no selected wire under it still
expands. No new log line, no change to the log format, the escalation state or undo.

## Rows (red today unless marked)

Fixture, built in the script as `build_chain` does: five wires W0..W4 joined end to end
in an L-shaped chain, seed on W0's interior; `lab_pin` instances LA on W1's interior, LB
on W2's interior, LC on W4's interior; a resistor with one pin exactly on W4's free end
(read the pin's coordinate back); a separate island wire with a label that carries LA's
net name; one label off any copper with that name. Read instances by name
(`xschem selected_set`) and wires by id (`xschem selection`), and assert exact sets.

1. Level 1: wires {W0, W1}, instances {LA}.
2. Level 2: wires {W0, W1, W2}, instances {LA, LB}; and LB is NOT in the set at level 1.
3. Level 3: five wires, instances {LA, LB, LC}, no device, no pin row.
4. A fourth call changes nothing.
5. The device is never selected, at any level, from either end of the chain (green today
   as a bare claim; written as the exact sets above so it cannot pass empty).
6. Delete after level 3 leaves the resistor and the two decoy labels and nothing else of
   the chain; one undo brings back five wires and three labels.
7. Rings stay geometric: the island and the off-copper label are never selected (green
   today).
8. Labels are leaves: with a label on the crossing point of two wires that share no
   endpoint, a grow seeded on one never selects the other, in both forms, at every level
   (green today; it tells the built design from the one that lets labels carry the grow).
9. The coordless form: `xschem select_at` on the seed, then three bare calls give levels
   1, 2, 3 with the sets of rows 1 to 3. This is the fence for the order of the label
   pass and the stored count: with the pass after the count, the level never leaves 1.
10. Label seed: select LA, grow once: LA stays, W1 is selected, a second label on W1 is
    selected.
11. Scope, each asserted in or out BY NAME at level 3 on the chain: `lab_wire` in;
    `lab_generic` in; `vdd` and `gnd` out; a `lab_pin` instance carrying `global=true`
    out; `ipin`, `opin`, `iopin` out; `lab_show` out; a probe out.
12. The real streams, display arm, under the shipping profile (`cadence_compat`,
    `fluid_editing`, `en_pin_select` all 1): the stream Tk really emits (press, release,
    double, release) and the stream with a second press before the double, three times
    each, give rows 1 to 3; afterwards the wire and instance counts are unchanged, no
    label has moved, and no move or wire-draw state is left armed.
13. Reset with labels: after three double clicks, one single click ON the seed, then one
    double click gives row 1, not row 3.
14. One row with a real Tk double click (`event generate` with time stamps on one pixel,
    the shape of `pg_dblclick` in `tests/headless/test_calc_pick.tcl`) and a command trace
    proving which callback events the editor saw.
15. The stock profile: a real double click on W0 opens Edit Properties (bounded by a
    timer that closes and names whatever popped), the selection is W0 alone and the log
    gained no grow line (green today, must stay).
16. Logging: one line per gesture and per command, as rows T11a and T11b hold; replaying
    the logged lines on a rebuilt fixture reproduces row 3.
17. Restated, not deleted: T1a, T1b and T6 of the grow suite; T2 of
    `test_select_same_net_by_label.tcl`.

Registration, in the same change:

- `test_dblclick_connected_grow`: give it a stall bound (source `tests/headless/scratch.tcl`
  below its display gate), a `RESULT:` line with a check count, and an epilogue that
  satisfies `banner_complete`. Measure whether the engine rows (the command forms) run
  under `--nogui`. If they do, restructure the top-of-file gate so they run on the counted
  arm and register the suite in both lists; if not, register it in `dcases` alone and say
  what you measured. Row W20h of `test_suite_watchdog_1403` must stay green.
- `test_select_same_net_by_label`: you change its row T2, so it is registered too,
  unless its baseline is red for a reason outside this item; then run it by
  `run_suites.sh`, report the reds and the reason, and leave it out.

## Texts to update

The spec `dblclick_connected_select.md`: a ruling dated 2026-11-21 that names what O2
said and what replaces it, the level table, the scope test, decisions 1 to 8 above; its
status line still says the feature is not implemented, its "reused infrastructure"
section says `select_connected_nets(2)` is a one-ring grow (it is not: that call grows no
wire), and its line coordinates are stale: name symbols instead.
`select_same_net_by_label.md` (the sentence and the table that say the double click
reaches wire segments only). The comments above `grow_one_ring_wires`,
`dblgrow_apply_level`, `select_grow_connected_step` and the same-net block in
`src/select.c`; above the `select_grow_connected` branch in `src/scheduler.c`; in
`handle_double_click` and above the same-net action in `src/callback.c`; the two comments
in `src/cadence_style_rc`. The headers of the two suites. A new entry on top of
`doc/claude/FAQ.md`: what the double click selects now and what it still leaves (labels
of the same name on another island, devices, ports, power symbols).
`doc/claude/suggestions/plan_dblclick_connected_select.md` is a dated record: leave it.

## Traps

- The label pass must come before the selection count is stored, or the coordless form
  resets to level 1 on every call. No existing row asks for coordless level 2.
- `tests/headless/test_selflog_grep_guard.tcl` (registered) pins the number of
  `log_action` sites of this verb in `src/select.c`. Add none, and do not quote that
  literal in a comment there.
- `get_inst_pin_coord` answers the origin for a pin that does not exist: check the pin
  count first. `touch()` on a zero-length wire answers yes for every point on its row,
  and the first press of a double click can leave zero-length stubs: skip them.
- Setting `cadence_compat` to 1 turns `autotrim_wires` on and nothing turns it off again:
  attach devices at wire ENDS and derive wire counts.
- A bare double-click event (`-3` alone) skips the abort of the armed gesture and the
  release that follows: drive the whole stream.
- The stock-profile row opens a modal form; bound it. A hand-rolled `after ... exit`
  deadline is scored as a failure and not as a timeout: use the suite watchdog.
- A wire label in a fixture is a `lab_pin.sym` or `lab_wire.sym` INSTANCE; `lab=` on the
  wire names nothing. `xschem instance_pin_coord` answers `{name x y}`.
- Under `--nogui` the command `winfo` does not exist.
- This change mutates no wire, but read `doc/claude/WIRING.md` before you touch
  `src/select.c`'s wire walk, as `CLAUDE.md` asks.

## Out of scope

The older one-shot connected-select (Shift-RMB, Ctrl-RMB, `xschem connected_nets`), which
already takes labels, ports and probes; the name-wise chord; any change in the stock
profile.

## Done means

Rows 1 to 17 green on the arm each belongs to, each new row shown red on the unchanged
product, the suite registered and gating, and the spec saying what the gesture does now.
