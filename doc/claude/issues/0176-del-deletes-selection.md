# 0176 — DEL deletes whatever is selected: a marker, or a trace and its markers

- **Status:** FIXED (2026-07-30)
- **Area:** `src/wave_viewer.tcl` — new `wviewer::delete_in_graphs` (PURE),
  `wviewer::delete_items` (THE mutation), `wviewer::marker_graph_at`,
  `wviewer::delete_selection_at` (the DEL body); `wviewer::delete_ok` reduced to a
  decoder; the `key_filter` Delete arm rewritten. **No C change.**
- **Tests:** `tests/headless/test_wave_markers.tcl` `MQ1`..`MQ11` (DISPLAY;
  793/328, up from 786/328 before `MQ11`), `tests/headless/test_wave_modes.tcl`
  `DT1`..`DT10` (both arms; 433/160),
  `tests/headless/test_wave_viewer.tcl` `G14b` (the repaired dialog; 368/48).
  `MF11b`'s Delete legs retargeted.
- **Related:** 0174 / 0175 (the selection this consumes), 0171 (Clear All),
  viewer plan items 4 (`Ctrl-E`) and 5 (`e`), `graph_markers.md` (the marker arm)
- **Reference:** `doc/claude/code_analysis/waveform_subsystem_reference.md`
  landmines 17, 19, 34, 41; `doc/claude/specs/waveform_viewer_modes.md` §14, §16

## Report

> DEL key must delete selection (traces only).

and, resolving the priority question:

> Delete should delete whatever is selected. If that is a marker, delete it. If
> it is a trace, delete the trace and its associated markers.

So it is not a priority ladder between two owners — it is **one rule keyed on
what kind of thing is selected**, with a cascade: deleting a trace takes its
markers with it.

## What was already there, and what was not

The marker arm shipped with the waveform markers (`graph_markers.md` §6.1). The
trace-delete machinery shipped with the Delete dialog, **including** the marker
cascade — `remap_markers_after_trace_delete`'s documented semantics are exactly
the user's sentence. Nothing new had to be invented for either.

What was missing was a **seam**: `wviewer::delete_ok` was welded to the dialog's
listbox (it read `$w.items curselection` and decoded it through `delmap`), so
there was no callable trace deleter at all — `grep`ing all 190 `proc wviewer::`
definitions turns up none.

## The pre-existing defect this had to repair on the way

`delete_ok` had **no `push_undo`, no `log_action`** and no target remap. Deleting
traces through the dialog was therefore **neither undoable nor replayable**, and
a strip deleted below the target strip left the target pointing one strip too
high. Every other model mutation in this subsystem (`move_strip`, `move_trace`,
`split_strip`, `delete_empty_strips`, `delete_all_markers`) has all of it.

That is a separate defect and it is not caused by this issue — but this issue
could not ship without fixing it. A DEL key that destroys traces with no `u` is
much worse than a dialog that does, because DEL is one keystroke and the dialog
is four clicks. The repair is structural rather than additive: the body was
lifted out of `delete_ok` into `wviewer::delete_items`, which owns the whole
ceremony, and the dialog now calls it. **The dialog gained undo, redo, a
replayable log line, the target remap and a no-op discipline for free**, and it
cannot drift away from the key path because there is only one path.

`G14b` is the leg group that holds it: one undo point per OK, one log line
naming explicit model indices, `u`/`U` round-tripping, and an OK with an empty
selection reported as `0` with no undo point and no log line.

## Decisions

### D1 — both kinds selected: **delete both**, as one gesture ⚠ FLAGGED

The two selection models are independent (`graph_marker_sel` vs 0175's
`hilight_wave`/`sel_waves`), so "a marker AND traces are selected" is reachable.
The user's rule read literally is *delete whatever is selected*, so both go — one
capture, one undo point, one log line, one regenerate (D5).

⚠ **This is the reading that destroys two kinds of thing from one keystroke.**
It is flagged for the eyeball; if it feels wrong it inverts to marker-first,
which is a two-line change in `delete_selection_at` (drop `pairs` when `marks` is
non-empty) and the sabotage run already measured which legs move (`MQ3`).

`MQ3` is the leg: a trace on strip 1 and a marker on strip 0 both selected, DEL
over strip 0, and the count comes back **2**.

### D2 — nothing selected: DEL does nothing, and never reaches C

`delete_selection_at` returns 0 before touching anything, and `key_filter`
`return`s without forwarding. This is now **structural** rather than a gate
condition: since Delete is no longer forwarded on any path, C's
`case XK_Delete` fall-through — `readonly_block()` and a modal dialog over a
read-only viewer — is unreachable from this window.

`MQ4` proves it with an execution trace on the `xschem` command: `xschem
callback` is called **zero** times, the model is byte-identical, no undo point,
no log line. A leg that only checked "no crash" would pass on a readonly modal.

### D3 — a strip that loses its last trace **stays**

The ask says *traces only*. `delete_items` never calls `delete_empty_strips`;
tidying the stack is bare `e` (viewer plan item 5) and it is the user's gesture
to make. Stated here so a later session does not "helpfully" clean up. `MQ3`
asserts the emptied strip is still there, in the model **and** as a rect.

### D4 — whole-strip delete via DEL is out of scope

`delete_items` takes a `graphs` argument because the dialog can delete whole
strips, but **DEL always passes `{}`**. If a future selection model can select a
strip, DEL ignores it.

### D5 — one undo point and one log line per GESTURE

Not per trace. Deleting three selected traces is a single `u` and a single
replayable line. §14's contract.

### D6 — the log line carries explicit MODEL indices

0175 D8 spelled out the constraint: a replay runs with **no selection state at
all**, so a line naming "the selection" would delete nothing (or worse, whatever
the replaying session happened to have selected). The line is

```tcl
wviewer::delete_items {} {{0 1} {0 2}} 3 <token>       ;# one marker
wviewer::delete_items {} {{0 1}}       {3 4} <token>   ;# two
#                     ^        ^        ^      ^
#                  strips  {gi ti}   marker   the resolved token
#                          MODEL     NUMBERS
```

(A one-element marker list renders without braces — `[list ... {3} ...]` is
`3` — which is what the `MQ1`/`MQ3` expectations compare against.)

and it is built from the **normalised** payload — deduped, with pairs inside a
doomed strip dropped — not from the caller's raw arguments, so replaying it
reproduces the run exactly. Stability against its own deletions is structural:
`delete_in_graphs` walks the ORIGINAL list with its own `gi` counter and removes
traces highest-index-first, so every index in the line is in the pre-mutation
space. `MQ7` replays a recorded line into a fresh, identical viewer **with no
selection** and compares the resulting model.

### D7 — `over_graph` is kept

The marker arm required it and the trace arm now shares it, so a stray DEL with
the pointer parked on the window margin is a refusal. Consistent, and it is the
shipped shape. `MQ9`.

### D8 (new) — the marker half is a MODEL edit, not the C verb

The obvious implementation was to keep forwarding the key to C for the marker.
Four measured reasons not to:

1. `xschem graph_marker delete` is readonly-rejected at the scheduler
   (`scheduler.c:5115`), so it would need a `with_edit` bracket.
2. `graph_marker_delete` **self-logs** `xschem graph_marker delete N`
   (`draw.c:6480`), which is readonly-rejected *again* on replay and aborts the
   whole `source` — precisely why `delete_all_markers` wraps its call in
   `xschem log_action -suppress push/pop`.
3. It pushes a **C** undo point onto a read-only scratch buffer.
4. It reaches the Tcl model **only** through `graph_marker_notify()`, which is
   `has_x`-gated (landmine 41). Under `--nogui` the rect would lose the marker
   and the model would not, and this proc's own `set_graphs` + `regenerate`
   would put it straight back.

Every other Tcl deletion path in the file (`delete_ok`, `clear_graph_traces`,
`delete_empty_strips`) already rewrites the token directly, and
`markers_drop_number` reproduces both of `graph_marker_delete`'s effects exactly:
the record goes, and every surviving `prev` that pointed at it is zeroed. So the
marker number simply joins the `gone` list and rides the **same window-wide
sweep** the cascade already needed. One call does both jobs.

**Behaviour is unchanged; the mechanism is the shipped one.** What is deliberately
not carried over: the C undo push and `set_modify(1)` on the viewer buffer (noise
on a read-only scratch buffer, and no other Tcl deletion path does it either) and
the C self-log line (replaced by the one Tcl line, exactly as
`delete_all_markers` does).

### D9 (new) — C's strip-scope test is REPRODUCED, not loosened

`callback.c`'s `case XK_Delete` deletes the selected marker only when
`graph_marker_find(sel, &sgi, NULL) && sgi == xctx->graph_master`, i.e. the
pointer must be over the strip that **owns** the selected marker. Since the key
is no longer forwarded, that test had to move into Tcl:
`wviewer::marker_graph_at` is the mirror of `graph_marker_find` (read off the
**rects**, like C, and fails closed at -1) and it is compared against
`wviewer::strip_at_pixel` of the KeyPress coordinates. `MQ5` is the leg, with an
A/B control: the same gesture on the owning strip does delete it.

**A latent wart closed on the way.** The old Tcl gate was
`marker_selected >= 0` — window-wide, with no strip test — so a marker selected
on a *different* strip made key_filter forward, C refused on scope, and control
fell straight through to `if(xctx->ui_state & SELECTION)` → `readonly_block()`, a
modal dialog over the read-only viewer. `MQ5` asserts zero `xschem callback`
calls on exactly that gesture.

## The three index consequences

This is the sentence to remember, and it is now in the reference doc: **a trace
delete has THREE index consequences.**

1. a marker **on** the doomed trace is DROPPED — unlike a move, nothing is left
   for it to annotate;
2. every marker and every selected node **in the same graph** that sat above a
   doomed node shifts **down** by the number of doomed nodes strictly below it —
   a stale index annotates or bolds the WRONG trace, which is worse than losing
   the marker or the selection;
3. the dropped marker **NUMBERS** must be swept **window-wide**, because a delta
   block's `prev` partner may live in a strip the deletion never touched, and a
   dangling `prev` degrades the block to a plain callout with no indication at
   all (`graph_marker_text` simply omits it).

`MQ2` asserts all three in one gesture, and `DT2` asserts the pure math of all
three headless.

## Test-arm split (landmine 41, applied to Tk)

`wviewer::delete_items` ends in `wviewer::regenerate`, which goes through
`viewport_rect` → `winfo width`. Under `--nogui` there is no Tk at all, so the
**command layer cannot run headless whatever the fixture does**. The half that
can is the pure index/marker/selection math.

| arm | where | what |
|---|---|---|
| both | `test_wave_modes.tcl` `DT*` | `delete_in_graphs`: the cascade, the survivor remap, the `gone` numbers, the selection set, the vec-less-trace index space |
| DISPLAY | `test_wave_markers.tcl` `MQ*` | routing both ways and both together, the live cascade + sweep, undo/redo, the log line, the two refusals, a real Delete keystroke |
| DISPLAY | `test_wave_viewer.tcl` `G14b` | the repaired dialog |

Writing a command-layer leg into the nogui arm would assert the **pre**-mutation
state and pass for entirely the wrong reason. Same lesson as the `MD` group,
different mechanism (Tk rather than `has_x`).

## Sabotage-verified — and one hole it found

Seven mutations of `src/wave_viewer.tcl`, each re-running the affected suites in
both arms and each required to turn a **different** leg set red:

| # | sabotage | went red |
|---|---|---|
| a | a selected marker suppresses the trace arm (wrong routing) | `MQ3` ×4 |
| b | drop the marker CASCADE | `DT2`/`DT3`/`DT9` (both arms) + `MQ2`/`MQ3`/`MQ10` |
| c | drop the SURVIVOR remap | `DT2`/`DT5`/`DT6` + `MK5` ×4 (both arms) + `MQ2` |
| d | drop the window-wide number sweep | `MQ1`/`MQ2`/`MQ3`/`MQ5` + `MF11b` + `MX10` |
| e | omit `push_undo` | `MQ1`/`MQ2`/`MQ3`/`MQ8`/`MQ10` + `G14b` ×3 |
| f | log per-TRACE instead of per-gesture | `MQ11` |
| g | let DEL through with nothing selected | `MQ4` + `MQ5` — the two "zero `xschem callback` calls" legs |

**⚠ (f) was INVISIBLE on the first pass, and that is the finding worth keeping.**
Every leg in the group deleted exactly ONE trace, so "one log line per gesture"
and "one log line per trace" were indistinguishable and a deleter that logged
per trace passed all 786 checks. `MQ11` was written to close it: two traces of
one strip selected, one gesture, and the assertions are **one** undo point and
**one** log line carrying **both** pairs. The general lesson: a
"per gesture, not per item" contract cannot be tested with a one-item fixture,
and the count leg has to be the one that fails.

## Two defects the adversarial review found in the FIRST draft

Both survived the full battery and the 7-way sabotage run, which is the point of
recording them.

### The target-strip remap was read on the wrong side of the mutation

`delete_items` originally remapped the stored target **after** `set_graphs`,
copying `move_strip`'s contract literally. That is wrong here and right there:
`move_strip` never changes the graph COUNT, but a delete does, and
`wviewer::target_index` clamps its answer to the **live** count. So a target
sitting at or past the new end was shrunk **twice** — once by the clamp, once by
`index_after_removal`:

```
3 strips, target = 2 (the last), delete strip 0
  post-mutation read:  clamp(2, 2) = 1  ->  index_after_removal(1, {0}) = 0   WRONG
  pre-mutation read:   clamp(2, 3) = 2  ->  index_after_removal(2, {0}) = 1   right
```

The active-strip bar and the next single-plot signal would both go to the wrong
strip. `wviewer::split_strip` already had the correct discipline *and said why*
in a comment — the read is now hoisted above the mutation in both places.
`MQ12` is the leg, and it is built on the CLAMPED case on purpose.

### Second incidental repair — `delete_empty_strips` had the identical bug

Same pattern, three procs away, pre-existing and reachable (`e` with the target
on the last strip). Fixed the same way. Its existing `EG4` leg could not see it:
its fixture targets strip 5 of 6 survivors, so the clamp is inert and the two
readings agree. `EG4b` adds the case where the target is the LAST strip, and it
names the wrong answer explicitly so a regression cannot look benign.

### The `MQ9` gate leg was DEAD

It tried to prove D7 by parking the pointer at pixel (3,3) and expecting
`over_graph` to refuse. **Measured: `over_graph` answers 1 there.** Since item 18
the strips TILE the viewport, so `graphbb` covers every canvas pixel and there is
no off-graph region at all — the leg took its `else` branch every run, pressed no
key, and compared an unmutated model against itself. It now stubs `over_graph`
(the shipped proc's own answer when the C context is on another window), drives
the real `key_filter`, and carries an A/B control: the same key with the gate
restored *does* delete.

A third, smaller one: the `xschem callback` spy in `MQ4`/`MQ5` was armed across
an `update`, so a queued `<Motion>` dispatched there counted as a forward. It was
observed firing once. The spy window is now the proc call alone.

## Not changed (deliberately)

- The C side. Not one line.
- The marker delete's **behaviour** — only the path it is reached by (D8/D9).
- `graphkeys`. Delete is still not a member, for the reason the original comment
  gave: membership means unconditional forwarding.
- The `e` / `Ctrl-E` / `Ctrl-D` keys and the Delete dialog's UI.
- Selection is still view state: no dirty flag, no undo point, no log line for a
  selection *change* (0175 D8, landmine 19). Only the delete is an edit.

## Measured suite counts (DISPLAY / nogui)

The baseline is **measured on a pristine `89e98771` worktree**, not remembered:
the session prompt's numbers were taken post-0175 and several suites have grown
since. What follows is `RESULT:` from the pristine tree vs this branch.

| suite | before | after | delta |
|---|---|---|---|
| `test_wave_markers` | 712 / 328 | **803 / 328** | +91 DISPLAY (`MQ1`..`MQ12`, `MF11b` retargeted) |
| `test_wave_modes` | 413 / 140 | **433 / 160** | +20 in BOTH arms (`DT1`..`DT10`) |
| `test_wave_viewer` | 360 / 48 | **368 / 48** | +8 DISPLAY (`G14b`) |
| `test_wave_empty_strips` | 94 / 28 | **98 / 28** | +4 DISPLAY (`EG4b`, the second repair) |
| every other wave/ASE suite | unchanged | unchanged | — |

`test_wave_markers` self-checks its own totals (`MZ1`), so `mk_expect_x` moved
710 → 801 and `mk_expect_nogui` stayed at 326.

Full battery green in both arms, plus a 10x DISPLAY soak of the three main
suites — `Delete` is a generated-key leg (`MQ10`) and those are the flaky ones
under WSLg, so one green run would not have been evidence.

**One flake, and the control that was needed to attribute it.** `MF1` ("the
anchor really SLID") failed 6 of 30 markers runs on this branch while a pristine
`89e98771` soak in the same session failed 0 of 20 — so "it is byte-identical and
runs before anything I added" was NOT sufficient, and reasoning was standing in
for a measurement.

The fair control is a PAIRED one: same binary, same session, this branch's test
file alternating with the pristine one, 8 rounds each.

```
this branch   8/8  ALL PASS (803)          <- MF1 did not flake once
pristine      0/8  1 FAILED (711 passed)   <- MF11b only, the intended change
```

`MF1` is a `zoom_full` plus a 5-pixel sample walk, i.e. load- and
timing-sensitive; the unpaired soaks that showed 6/30 ran while a 20-agent review
workflow was loading the machine, and the pristine controls ran after it
finished. Attribution: a pre-existing WSLg timing flake, same class as the ones
recorded for `test_ase_plot` and `test_wave_trace_menu`. Not chased.

That paired run also double-confirms the behaviour change is real and that
retargeting `MF11b` was required, not cosmetic: the PRISTINE `MF11b` fails
against this branch's `wave_viewer.tcl` with exactly `{4} (exp {3})` — the one
extra viewer log line that Delete now emits.

## For the eyeball

The sequence that matters, and the one D1 hangs on:

1. Plot two or three traces into one strip, and a couple more into a second.
2. Put a marker on a trace of strip 0 (`m`), and a **delta** marker on a trace of
   strip 1 (`d`) so the two are linked.
3. Click the first trace's legend entry to select it. Press **DEL**.
   → the trace goes, its marker goes with it, and the delta block on the OTHER
   strip degrades cleanly rather than pointing at a dead number.
4. Press **`u`**. → the trace and its marker come back **together**, and the
   neighbouring trace's marker is still on the right trace.
5. Now select a marker (click it) *and* a trace (Ctrl+click its legend), and
   press DEL. → **both** go, and one `u` brings both back. **This is D1.** If it
   reads wrong, say so and it inverts to marker-first.
