# 0358 — `save` writes the live placement preview into the .sch AND leaves the terminal 0242 desync

Status: **OPEN — measured, not fixed.** Filed by the issue-0263 scout (item D2 of the 2026-08-09
unattended backlog run), 2026-08-09, at `bc4ff4a2`. Number claimed as a stub before the work; this
file is the full measurement, no fix proposed.
**Major/terminal**: an object the user never dropped is persisted to disk, and the canvas is dead
afterwards (the issue-0123/0262 terminal state) with ESC unable to repair it.
Area: `src/save.c:3635` (`save_schematic()`'s `unselect_all(1)`) vs the placement-preview flags.
Related: **0263** (the netlist twin — same blindness, different verb), **0262** (the same terminal
door through the bare `unselect_all` verb), **0242**, **0241**, **0123**.

## Symptom (measured headless, `./src/xschem --nogui --pipe -q --nolog --script …`)

```tcl
xschem load cell.sch
xschem wire 400 0 500 0        ;# one real edit -> modified=1
xschem unselect_all
set ::label_new_name FOO
xschem add_wire_label -place   ;# preview rides the cursor: ui=16424 sp=1
xschem save
```

Measured:

```
armed : sp=1 START_SYMPIN=1 STARTMOVE=1 ui=16424 inst=5 mod=1
saved : sp=1 START_SYMPIN=0 STARTMOVE=0 ui=0     inst=5 mod=0
esc3  : sp=1 START_SYMPIN=0                      ui=0   inst=5
```

* the written `.sch` **contains the preview instance** (`C {lab_pin.sym} … {name=l1 lab=FOO}`);
* the C tripwire fires: `placement_preview: sympin_preview=1 outlived START_SYMPIN at xschem()
  entry (ui_state=0 wirelabel_preview=1 instances=5)`;
* three ESCs cannot clear it — `abort_placement_preview()` is gated on the bit `unselect_all()`
  already dropped, so the canvas stays dead exactly as in 0262.

`save` on a **clean** buffer is silent about this only because `save()` (actions.c) short-circuits
before `save_schematic()`; the defect needs one prior real edit, which is the normal case.

## Mechanism

`save_schematic()` calls `unselect_all(1)` at `src/save.c:3635`, immediately before
`write_xschem_file(fd)`. A live placement preview is always SELECTED, so `unselect_all()`'s
wholesale `xctx->ui_state = 0` (`src/select.c:1256-1259`) drops `START_SYMPIN|STARTMOVE` without
running `abort_placement_preview()`; `sympin_preview` / `wirelabel_preview` are plain `Xschem_ctx`
fields, not `ui_state` bits, so they survive. The preview instance was never `delete()`d, and the
write that follows one line later therefore serialises it as an ordinary instance.

This is the **0262 door, in a verb that also persists the result** — 0262's residue is memory-only.

`write_backup()` (`src/save.c:3514-3536`, the autosave `~` file) has the same blindness to the
preview but does **not** call `unselect_all()`, so it writes the orphan without the terminal
desync.

## Not fixed here

Out of item D2's scope (D2 is issue 0263, the netlist verb). Recorded so the sweep the 0263
landmine asks for — "every other whole-document consumer that walks `xctx->inst[]` while a gesture
is live" — has a measured second data point to start from. Any fix must be decided against the
same ratified ladder 0262 is still waiting on: `save` arms no second gesture, so
"whatever you just pressed is what you meant" has no subject here either.

## Update 2026-08-09 — how the twin (0263) was settled, and why that answer does not transfer

**Issue 0263 landed the same day** (item D2), and it did *not* filter the traversal: it gated the
netlist **VERBS** with `leave_placement_for("Netlist")` + `leave_merge_for("Netlist")`, so the
gesture is abandoned, named on the status bar, and the modify flag is left alone. The measurement
that forced that shape applies here too — a `preview_sel`-keyed filter is useless against a verb
that destroys `preview_sel` on its own way through.

Three reasons the same two lines are **not** simply pasted into `save`, recorded as 0263 decision
**D9**:

1. **`write_backup()` has no verb to gate.** The autosave carries the orphan with no user action to
   attach a teardown to, so at least one arm of 0358 needs a different mechanism anyway.
2. **The ratification question is different.** 0263's is "may a *read* verb end a gesture?" and it
   is answered ABANDON only because the status quo there was *worse* — the verb already destroyed
   the gesture and committed the object. `save`'s question is "may a *persist* verb end a gesture?",
   and its status quo is the 0262 terminal desync, not a silent commit. Same ladder, different
   subject.
3. **Blast radius.** 0263's tier evidence is netlist-shaped (decks, goldens, `tests/netlisting`).
   Folding `save` in would put a `delete()` in front of every save path with none of that evidence.

So this issue stays open on its own terms, with 0263 as the worked precedent and its section-G deck
oracle as the model for what a `save` fix would have to assert.

## Repro script

`/tmp/claude-1000/-home-analog-dev-xschem-claude/scratch_D2/repro5.tcl` section **C2** (scratch,
not committed — reproduce with the six lines above).
