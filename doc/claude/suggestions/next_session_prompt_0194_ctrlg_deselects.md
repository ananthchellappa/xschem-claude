# Session prompt — 0194: CTRL-G (grid toggle) deselects the selected trace

*Written 2026-08-01 from a user report. Contains a **source-anchored hypothesis**
that was checked far enough to be worth stating, and a **prediction** that, if it
holds, proves the bug is a class rather than a one-off. Paste the block below into
a fresh session.*

---

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.

Fix issue **0194**, reported by the user against the ASE waveform viewer.

## SYMPTOM 1 — repeatable, this is the bug

> Select a trace, then press **CTRL-G** to toggle the grid in the Waveform
> Viewer. **The trace gets deselected.**

## SYMPTOM 2 — seen ONCE, never reproduced; treat as a clue, not a spec

> Plot signals A, B, C to three strips. Move **B from strip 2 to strip 1**. Press
> CTRL-G. The trace that was moved across strips (B) gets **bolded / unbolded with
> each CTRL-G** — it alternates.

The user's own words: *"haven't been able to reproduce this one"*. Do **not**
contort the design to chase it. Do fix symptom 1 properly, then ask whether the
fix explains symptom 2; if it does, say so and add the leg. If it does not,
record what you ruled out.

## HYPOTHESIS — measured this far, RE-VERIFY the rest

`wviewer::grid_toggle` (`src/wave_viewer.tcl`, ~line 4700) ends with:

```tcl
  wviewer::sync_grid_mirror $token
  wviewer::regenerate $token
  wviewer::log_action [list wviewer::grid_toggle $new $token]
```

**It calls `regenerate` without calling `capture_live_graph_state` first.**

That is the exact failure the file already documents for a sibling gesture.
`regenerate` **re-places every rect from the Tcl model**, while the C engine
writes pan / zoom / **bold** straight into the rect's `prop_ptr`. So any state the
C side owns and the model has not been told about is destroyed by a regenerate.
The selection is precisely such state: issue 0175 made it the per-rect
`hilight_wave` head token plus an optional `sel_waves` companion, written by the
C click arm and folded back into the model only by `capture_live_graph_state`.

Select a trace ⇒ C writes `hilight_wave` into the RECT. CTRL-G ⇒ `regenerate`
rebuilds rects from the MODEL, which never heard about it ⇒ **selection gone.**

**Anchors to verify (line numbers drift):**

| what | where |
|---|---|
| the offending tail | `wviewer::grid_toggle`, `src/wave_viewer.tcl` ~4700 |
| the contract it breaks | `capture_live_graph_state`, ~2485, and the comment block at ~166 and ~200 |
| the selection's storage | `graph_sel_waves_get/set/toggle` (`src/draw.c`), `wviewer::model_sel` / `model_sel_set` — the ONLY readers/writers of the token pair |
| the precedent | `move_strip` / `move_trace` / `move_traces` all call `capture_live_graph_state` FIRST, for this exact reason |

**Counts worth knowing before you "fix it everywhere":** there are ~24
`wviewer::regenerate` call sites and only ~11 `capture_live_graph_state` calls.
**Some regenerates deliberately do not capture** — see the comment at ~4786
("...or `u` would need two"). A blanket sweep is the wrong fix. Work out the rule
and apply it to the sites the rule covers.

## THE PREDICTION — check this early, it decides the shape of the fix

`wviewer::sharedx_toggle` (~5349) **also calls `regenerate` with no capture.**
If the hypothesis is right, **toggling shared-X should drop the selection too**,
and the user has not reported that only because they toggle it less.

Verify it by hand first. If it reproduces, this is a **class** — "window-option
togglers regenerate without preserving live rect state" — and the fix belongs at
that level (one helper, or capture at the head of each option toggler), not as a
one-line patch to `grid_toggle`. Also audit `set_plot_mode` (~2177) and
`cursor_toggle` (~5368) for the same shape.

## THE DISTINCTION THAT MATTERS — do not conflate these

Two different mechanisms, and only one of them applies:

- **`capture_live_graph_state`** — folds live C-owned rect state (pan, zoom,
  bold/selection, markers) back into the Tcl model so a regenerate does not
  destroy it. **A window option SHOULD do this.**
- **`wviewer::push_undo`** — takes a model snapshot for `u` / `U`. Window options
  (plot mode, sharedx, cursors, raw) are **deliberately outside** the undo stack
  (`waveform_viewer_modes.md` §14). **A window option should NOT do this.**

So the fix is "capture, do not push". Adding a `push_undo` to `grid_toggle` would
make CTRL-G undoable, which is a behaviour change nobody asked for.

## WHY SYMPTOM 2 MIGHT FOLLOW FROM THE SAME ROOT — a lead, not a conclusion

After a cross-strip trace move the model *has* been updated (the move captures
first, then remaps the selection into the model). So model and rect can now hold
**different** answers for which trace is bold. A regenerate that re-applies the
model, alternating against something that re-writes the rect between toggles,
would present as "B bolds and unbolds with each CTRL-G".

Two known traps sit exactly there and are worth checking against this symptom:

- **`remap_hilight_after_trace_move` returns `{}` for two different reasons** —
  "no highlight" and "the bold trace is the one that left". The caller must test
  *which*, or an unbolded move silently bolds something in the destination.
- **Model trace index ≠ node index.** `graph_props` SKIPS a trace with an empty
  `vec` when building the `node` token, so every C answer (`graph_trace_at`,
  `hilight_wave`, `sel_waves`) is in NODE space.
  `node_index_of_trace` / `trace_index_of_node` / `node_count` are the mapping and
  nothing may cross without them. A move across strips is exactly where the two
  spaces diverge.

## PROBE PLACEMENT — read before writing a single leg

From `doc/claude/overnight_batch_2026_08_01/PLAN.md`'s universal test discipline,
written after two `[F]` verdicts in one round that were both this mistake:

> **Never drive a leg from a pixel or path where the correct implementation and
> the bug you are guarding against give the SAME answer.**

Applied here:

- **Witness EVERY strip, not the one you clicked.** `hilight_wave` is a per-RECT
  token; a one-rect witness already missed a whole class of bug in issue 0174. A
  leg that reads only strip 0 cannot see a selection wrongly surviving — or
  wrongly appearing — on strip 1.
- **Select on a strip that is NOT index 0**, and select a trace that is NOT node
  0. `atoi("")` reads an absent token as node 0, so a leg built on strip 0 /
  node 0 passes when the token was destroyed.
- Assert the selection **through the same accessors the code uses**
  (`xschem get graph_sel_waves` / `wviewer::model_sel`) **and** on the raw rect
  prop, so a fix that updates one store and not the other cannot pass.

## NAMED SABOTAGES — each must kill exactly its target, then revert, then green

1. Delete the new `capture_live_graph_state` call from `grid_toggle`. Must kill
   the CTRL-G-keeps-selection legs and nothing else. **This is the leg that did
   not exist and is the whole point of the item.**
2. Capture but discard the selection (capture markers/zoom only). Must kill the
   selection legs while the pan/zoom legs stay green.
3. Capture only the head (`hilight_wave`) and not `sel_waves`. Must kill a
   **multi-trace** selection leg — so write one; a single-selection fixture cannot
   tell the two stores apart.

## DISCIPLINE

- Read `doc/claude/code_analysis/waveform_subsystem_reference.md` first, then
  `doc/claude/specs/waveform_viewer_modes.md` §14 (undo) and §15 (selection
  ownership), and issue `0175` (the selection is a SET across two tokens).
- Reproduce in the user's real mode first: they run
  `src/xschem --script src/cadence_style_rc --logdir /tmp`, and the surface that
  matters is the **ASE waveform window** — a graph embedded in a schematic window
  is explicitly not a concern.
- ⚠ **Never** `pkill -f 'src/xschem'` — that pattern matches the user's live
  session. Kill only PIDs you launched, after reading `pgrep -af xschem`.
- Suite: extend `tests/headless/test_wave_grid.tcl` if the grid legs live there,
  otherwise the suite that owns viewer selection. Register any new suite in
  `tests/headless/full_audit.sh` `logdir_tests`. Copy the shipped footer EXACTLY:
  `RESULT: ALL PASS ($npass checks)` + `exit 0/1`.
- **Never** a bare `event generate` + one `update`: loop, `focus -force`, confirm
  `[focus -displayof $w] eq $w`, generate, retry until an expr in the caller's
  scope reports the effect.
- **KNOWN-FLAKY, not yours**: `test_cadence_drag` (12/12 red on pristine),
  `test_wave_trace_menu` TG9 (4-in-10), `test_ase_plot` P4/P6/P8 (1-2 in 10),
  `test_hover_highlight` + `test_palette` (~40 %, measured against a pristine
  control worktree). **The check COUNT is the signal, not the verdict.**
- Git: explicit file list, no `git add -A`, no `git reset --hard`, no `git push`.
  Commit message ends with:
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`

## DELIVERABLES

1. The fix, at whatever level the prediction says is right (one toggler, or the
   class).
2. Legs that fail on today's code — prove it by running them against a stash of
   the fix — covering: CTRL-G keeps a single selection; keeps a **multi-trace**
   selection; keeps it on a **non-zero strip**; and the same for whichever sibling
   togglers turn out to share the defect.
3. `doc/claude/issues/0194-ctrlg-grid-toggle-deselects-trace.md` — the measurement,
   the rule you derived for which regenerates must capture, the sabotage table,
   and an explicit verdict on **symptom 2**: explained by this fix, or still open
   with what you ruled out.
4. A landmine entry in `waveform_subsystem_reference.md` naming the rule, since
   the next person to add a window option will hit this again.
