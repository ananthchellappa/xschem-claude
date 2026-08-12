# 0399 — the 0262 repair erases its own evidence, and its status line names a cause it cannot know

Status: **OPEN — measured, not fixed.** Two small consequences of issue **0262**'s ratified repair,
found by the adversary pass of item **D8** of the 2026-08-11 unattended backlog run. Filed rather
than folded into 0262 because both are about the repair's **reporting surface**, not its decision.
**Minor**, but the first one degrades a tool that 0242 ratified explicitly.
Area: `src/callback.c` — `repair_orphan_placement_preview()` and
`check_placement_preview_invariant()`.
Related: **0262** (the repair), **0242** (the tripwire and its stated purpose), **0358**, **0397**,
**0241** (the rule the status line is answering).

## Part 1 — the observability regression

Issue **0242** ratified the tripwire with an explicit purpose:

> it turns "how many doors are left" from an argument into an empirical question, permanently.

After 0262, `xschem get sympin_preview` **can no longer report a desync**: the getter is an
`xschem()` entry, and the repair runs at `xschem()` entry *before dispatch*, so the probe repairs
the state it was about to measure and then answers 0. The stderr `dbg(0)` line still fires — once
per episode, behind a **file-static** `reported` latch — so a *scripted* observer can still count
episodes off stderr, but any state-based observer sees a healthy session.

Consequence: **the only way left to observe a live door from Tcl is through
`xschem test_gate_bypass 1`**, the construction seam (doors rows F13/F14 do exactly that). A future
crew that greps for stuck-flag evidence and finds silence must not read that as "the class is
closed". Options if this matters: a `xschem get placement_desyncs` counter incremented by the
repair (cheap, gives the empirical question back without a seam), or making the latch per-context
so a second window's episode is not swallowed.

## Part 2 — the status line names a cause it cannot know

Shipped text, hardcoded:

```
Pending placement abandoned by a deselect; object left in place
```

The repair runs at a **funnel**, not at a door. It has no idea which door fired. "by a deselect" is
correct for the bare verb and both GUI routes of issue **0397**, and **wrong** for
`save`/`saveas`/Ctrl+S (issue **0358**), which is a *persist*, not a deselect — and wrong in advance
for any door nobody has found yet, which is the whole class the repair was ratified to cover.

It also names the **cause** rather than the **object**, which is a thin reading of the issue-0241
rule ("a teardown must name what it is tearing down") that 0262 decision **D7** invokes to justify
speaking at all. Compare the gates, which say what they displaced: `Netlist: pending placement
abandoned`.

Suggested shape, not implemented: drop the cause and name the object and the residue —
e.g. `Pending placement abandoned; the label was left in the drawing` — or have the repair take a
`const char *where` (both call sites already pass one to the tripwire) and say
`Pending placement abandoned at <where>`.

## Why neither is fixed here

Part 1 is a design choice with more than one answer and no measured harm yet; part 2 is a user-facing
string, and item D8 is already status **E** on one user-visible change (0262 **D4**) — adding a
second uncoordinated one to the same status bar would muddy the question the human has to answer.
