# 0398 — a door-abandoned placement mutates the document (and the netlist) while `modified` stays 0

Status: **OPEN — measured, not fixed.** Found by the adversary pass of item **D8** of the
2026-08-11 unattended backlog run, against the tree that landed issue **0262**'s repair.
**Major**: a real, unsaved document mutation that the modify flag denies — the buffer will close
without a prompt, and the mutation reaches the emitted deck.
Area: `src/select.c` (`unselect_all()`'s wholesale `ui_state = 0`) vs the placement-preview arm's
own `modified` bookkeeping; `src/callback.c` `repair_orphan_placement_preview()` (which
deliberately does not touch `modified`, issue 0262 decision **D3**).
Related: **0262** (the decision that made this the *whole* remaining residue rather than half of a
dead-canvas story), **0397** (the GUI routes into it), **0358** (`save`), **0263** (the netlist
gate that is structurally blind to it), **0244** / **0267** / **0270** (the ratified rule this
breaks: *an aborted gesture must not lie about the modify flag*), **0123**.

## Symptom (measured headless, post-0262-repair)

On a **clean, saved** document — the case the doors suite cannot reach, see below:

```
loaded, clean          : inst=0 modified=0
xschem add_wire_label -place   ;# the preview is a real instance in inst[]
armed                  : inst=1 modified=0
xschem unselect_all            ;# the 0262 door; the repair fires at the next entry
after door + repair    : sp=0 inst=1 modified=0
xschem instance_net l1 p       ->  FOO
```

The user abandoned a gesture and is left with **an extra `lab_pin` in the drawing that renames the
net it sits on**, on a buffer that reports itself **clean**. Nothing will prompt on close, and
nothing will prompt before the next netlist.

## The netlist consequence, same run

```
control (placement still live)  ->  R1 net1 GND 1k / R2 net1 GND 2k     (0263's gate works)
after door + repair             ->  R1 FOO  GND 1k / R2 FOO  GND 2k     (modified reads 0)
```

Issue **0263**'s netlist gate is structurally blind here: `leave_placement_for()` keys on the
gesture bits the door already dropped, and `preview_sel` is gone by then (cleared by the 0262
repair, and before the repair existed it named an object that was no longer a preview). Identical
pre- and post-0262-fix, so this is **not a regression from that fix** — but it is what "orphan-only"
actually costs, and 0262's ratification text should not be read as saying the residue is harmless.

## Why the shipped suite cannot see it

`tests/headless/test_placement_preview_doors.tcl` row **F7** asserts
`[xschem get modified] == 1` after the door and calls it "modify flag untouched". That row passes
for a fixture reason, not a behavioural one: the suite's own `setup` draws a wire first and its
comment says so ("wires=1, modified=1"), so F7 is reading the **fixture's** dirt, never the
orphan's. **F7 should be re-fixtured on a saved/loaded document** — that is the smallest useful
first step on this issue and it turns the defect red.

## What a fix has to decide

Two shapes, neither taken here:

1. **The arm owns it.** A `-place` arm that parks a real object in `inst[]` sets `modified` when the
   object is parked, not when it is dropped, and the teardown clears it back. That makes every
   abandoned gesture honest but changes the modify contract that `0244`/`0267`/`0270` ratified for
   the *aborted* path (an aborted gesture must leave `modified` alone).
2. **The repair owns it.** `repair_orphan_placement_preview()` sets `modified = 1` when it repairs,
   on the grounds that it is precisely acknowledging that a real object was left behind. Cheap, one
   line, and it makes the close-prompt honest — but it is a second user-visible behaviour change on
   top of 0262's, and 0262 decision **D3** deliberately kept the repair out of the document's
   bookkeeping.

Do not fix this silently: it is the same ratification family as 0262 D4, and the human question
there ("keep the object?") and this one ("and admit it?") should be answered together.
