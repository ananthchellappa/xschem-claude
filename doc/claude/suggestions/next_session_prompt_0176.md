# Issue 0176 — DEL deletes whatever is selected: a marker, or a trace and its markers

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
**Do 0174 then 0175 first** (`next_session_prompt_0174.md`,
`next_session_prompt_0175.md`) — this issue consumes 0175's selection model.
Never push.

## The ask, as decided by the user

> DEL key must delete selection (traces only).

and, resolving the priority question:

> Delete should delete whatever is selected. If that is a marker, delete it. If it
> is a trace, delete the trace and its associated markers.

So this is **not** a priority ladder between two owners — it is one rule keyed on
**what kind of thing is selected**. Note the cascade: **deleting a trace takes its
markers with it.**

## The recon is done. VERIFY it, do not re-derive it

### 1. DEL already has an owner, and it is correctly gated

`wviewer::key_filter` (`wave_viewer.tcl` ~5466) forwards keysym **65535**
(Delete) only when **doubly** gated:

```tcl
} elseif {$N == 65535 && [wviewer::over_graph $W] && [wviewer::marker_selected $W] >= 0} {
```

Its comment states why it is deliberately **not** a `graphkeys` member:
membership means *unconditional* forwarding, and a Delete that reached C with
nothing selected lands on the canvas delete verb — `readonly_block()` and a
**modal dialog over a read-only viewer**. C applies the same scope test on its
side (the pointer must be over the strip owning the selection), so a stale
selection cannot make it fire either.

Delete is also one of the three **mutating** graph keys (`m`, `d`, Delete)
forwarded inside `with_edit` — landmine 17's second half. `wviewer::marker_selected`
(~2752) reads `xschem get graph_marker_sel`, returns -1 on any error, and its
header already says *"-1 means nothing selected, which is what the Delete gate in
key_filter must conclude when it cannot get a trustworthy answer"*.

**Keep all of that.** This issue ADDS a second arm to the same gate; it must not
loosen the first.

### 2. The trace-delete machinery is fully built, INCLUDING the marker cascade

`wviewer::delete_ok` (`wave_viewer.tcl` ~5199) — the OK button of
Graph > Delete… — already does the whole job for a set of traces and/or graphs:
collects the doomed node indices, calls
`wviewer::remap_markers_after_trace_delete`, remaps `hilight_wave` via
`wviewer::remap_node_after_trace_delete`, then
`wviewer::markers_sweep_numbers` window-wide, then `regenerate`.

**The user's "delete the trace and its associated markers" is already the
documented semantics** of `remap_markers_after_trace_delete` (~1140):

> PURE: markers of one graph after the node indices in `doomed_nis` are deleted
> from it. **A marker on a doomed trace is DROPPED** (unlike a move, nothing is
> left for it to annotate); every survivor shifts down by the number of doomed
> nodes strictly below it. Callers must then sweep the dropped NUMBERS
> window-wide with `markers_sweep_numbers` — this proc cannot, it only sees one
> graph.

So do **not** write a second deleter. **Extract** a callable
`wviewer::delete_traces {token pairs}` from `delete_ok` and have both the dialog
and DEL call it. If you find yourself re-implementing the remap or the sweep, stop.

### 3. ⚠ A pre-existing gap you will inherit: `delete_ok` neither pushes undo nor logs

Measured: there is **no** `push_undo`, **no** `log_action` and **no** `with_edit`
anywhere in `delete_ok` (~5199-5285). Every other model mutation in this
subsystem has all three — `move_strip`, `move_trace`, `split_strip`,
`delete_all_markers`, `delete_empty_strips` (§14 of the modes spec: one capture,
one undo point, one log line, one regenerate).

So today, deleting traces through the dialog is **not undoable and not
replayable**. That is a defect, it is not caused by this issue, and this issue
cannot ship without fixing it — a DEL key that silently destroys traces with no
`u` is much worse than a dialog that does, because DEL is one keystroke.

**Fix it in the extracted proc**, so the dialog gets undo and logging for free,
and say in the issue file that the dialog path was repaired as a consequence.

## READ FIRST

1. `doc/claude/issues/0175-*.md` — the selection model you are querying, and
   whether it is per-strip or window-wide (0175's D2).
2. `doc/claude/specs/graph_markers.md` — Delete's current owner, and the marker
   selection model (`graph_marker_sel`).
3. `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 —
   **landmine 17** (all mutation via `with_edit`; the `m`/`d`/Delete forwarding
   bracket; `with_edit` **errors** on a refused context switch so inside a Tk
   binding it must be `catch`ed), **landmine 41** (the C→Tcl marker push hook is
   `has_x`-gated, so **nothing** about the viewer model or the viewer undo stack
   is observable under `--nogui` — this decides which arm your legs live in, and
   getting it wrong gives a leg that asserts the *pre*-mutation state and passes
   for the wrong reason), **landmine 34** (NODE vs MODEL index), **landmine 19**
   (a graph gesture does not dirty the file; but a delete IS a model edit).
4. `doc/claude/specs/waveform_viewer_modes.md` **§14 (undo/redo of viewer edits)** —
   the mutation contract every model edit follows, and the `u` / `Shift-u` keys.

## Seams — compose, do not reinvent

| what | where | note |
|---|---|---|
| `wviewer::key_filter` | `wave_viewer.tcl` ~5455 | the Delete gate. Add an arm; do not loosen the existing one |
| `wviewer::marker_selected` | ~2752 | -1 = nothing selected, fail-closed |
| `wviewer::delete_ok` | ~5199 | **EXTRACT from this.** Already does doomed-set → marker remap → `hilight_wave` remap → window-wide number sweep → regenerate |
| `remap_markers_after_trace_delete` | ~1140 | the cascade: a marker on a doomed trace is DROPPED |
| `remap_node_after_trace_delete` | ~1095 | index remap for survivors |
| `markers_sweep_numbers` | see ~5277's call | the window-wide `prev` sweep the per-graph proc cannot do |
| `wviewer::with_edit` | ~862 | the mutation bracket. **Errors** on a refused switch — `catch` it inside a binding |
| `wviewer::push_undo` / `history_depth` / `undo` / `redo` | §14 | one undo point per gesture |
| `wviewer::log_action` | ~1964 | one replayable line, explicit targets |
| `wviewer::delete_empty_strips` | ~4325 | **NOT to be called from here** — see D3 |

## Decisions to make BEFORE writing code — answer them in the spec

- **D1: what if BOTH a marker and one or more traces are selected?** The two
  selection models are independent (`graph_marker_sel` vs 0175's), so the state is
  reachable. The user's rule is "delete whatever is selected", which read
  literally means **delete both**. That is my default. But it is also the one
  reading that destroys two kinds of thing from one keystroke, so: implement
  "delete both" as one undo point, **and flag it to me in the review** — if it
  feels wrong on the eyeball we invert it to marker-first.
- **D2: nothing selected at all.** DEL must do **nothing**, and specifically must
  **not** reach C (the existing comment explains why: canvas delete verb →
  readonly modal). The gate stays fail-closed: any untrustworthy answer reads as
  "nothing selected".
- **D3: a strip that loses its last trace.** The ask says **traces only** — so the
  now-empty strip **stays**. Do **not** opportunistically call
  `delete_empty_strips`; that is bare `e` (viewer plan item 5) and it is the
  user's gesture to make. State this in the spec so a later session does not
  "tidy up".
- **D4: whole-strip delete via DEL?** Out of scope ("traces only"). If 0175's
  selection can somehow select a strip, DEL ignores it. Say so.
- **D5: one undo point or one per trace?** One per **gesture** (§14's contract),
  so deleting three selected traces is a single `u`. Same for the both-kinds case
  in D1.
- **D6: what does the log line look like?** It must replay without depending on
  the selection at replay time (the 0151 precedent: log the resolved values and
  the explicit token, never `invert`/"current"). So log explicit
  `{gi ti}` pairs — and note the pairs must be in **MODEL** index space, and
  stable against the deletions happening as the line is applied (delete
  highest-index-first, or record the pairs before any mutation).
- **D7: does DEL work when the pointer is not over a graph?** The existing arm
  requires `over_graph`. A window-wide trace selection (0175 D2) plus a pointer
  over the window's margin is then a refusal. Decide: keep `over_graph` for
  consistency with the marker arm, or drop it for traces. I lean **keep it** —
  it is the shipped shape, and it prevents a stray DEL from a distant pointer.

## Hard constraints

- **The read-only viewer**: every mutation goes through `with_edit`
  (readonly 0 → run → `set_modify 0` → readonly 1, bracketed by
  `autosave_backup 0`), and `with_edit` **throws** on a refused context switch, so
  the Tk binding must `catch` and report (the existing marker-key forwarding is the
  pattern, ~5487).
- **Landmine 41 is the test-design constraint, not a footnote.** The marker model
  and the viewer undo stack are invisible under `--nogui`. A leg that says
  "the model lost its `markers` key" or "`u` brings the trace back" is a
  **DISPLAY-arm** leg. Written into the nogui arm it asserts the pre-mutation
  state and passes for entirely the wrong reason. `test_wave_markers.tcl` already
  splits its `MD` group on exactly this line — copy that split and say so in a
  header comment.
- **Landmine 41's second half**: do not have a Tcl wrapper "helpfully" write the
  model to paper over the headless gap — in a DISPLAY session the C hook has
  already written it, and the second write lands after the hook's `push_undo`
  (snapshot-after-mutate, where `u` restores the thing it was meant to undo).
- **One log line per gesture.** Not one per trace.
- **Do not change the marker delete's behaviour**, only reach it through the same
  gate.

## ⚠ THE HOLLOWNESS TRAP

1. **Assert the marker/trace routing BOTH ways.** A marker selected (no traces) →
   the marker goes, the traces are untouched. A trace selected (no marker) → the
   trace goes. A leg that only tests one arm passes on whichever routing you
   happened to write.
2. **Assert the CASCADE explicitly**: put a marker ON the trace being deleted and
   a marker on a DIFFERENT trace of the same strip, delete the first trace, and
   assert the first marker is **gone** and the second **survives with a remapped
   `wave` index**. That second half is what catches an off-by-one in
   `remap_node_after_trace_delete`, and it is where the real bugs live.
3. **Assert the window-wide number sweep**: markers carry numbers, and
   `markers_sweep_numbers` exists because a dropped number must be swept across
   **other** strips too. So the fixture needs markers on at least two strips.
4. **Assert `u` restores the trace AND its markers** — one undo, both back. This
   is the leg that would have caught the missing `push_undo`, and it is
   DISPLAY-only (landmine 41).
5. **Assert nothing-selected DEL is a no-op that never reaches C.** Spy the
   forward (or assert the model and the marker set are byte-identical after);
   a leg that only checks "no crash" passes on a readonly modal.
6. **Assert the log line replays**: apply it to a fresh viewer with the same
   layout and get the same model. A line that names "the selection" instead of
   explicit pairs passes an equality check and fails on replay.
7. Sabotage-verify, each turning **different** legs red: (a) DEL deletes traces
   while a marker is selected (wrong routing); (b) drop the marker cascade
   (markers survive on a deleted trace); (c) drop the survivor remap (markers
   point at the wrong trace); (d) drop the window-wide sweep; (e) omit
   `push_undo`; (f) log per-trace instead of per-gesture; (g) let DEL through with
   nothing selected.

## Tests

- `tests/headless/test_wave_markers.tcl` (**712** / **328**) — owns the Delete key
  and the marker model. The routing, cascade, sweep and undo legs go here, split
  on the landmine-41 line like its existing `MD` group.
- `tests/headless/test_wave_viewer.tcl` (**349** / **48**) — owns the selection.
  The "nothing selected → no-op" and selection-after-delete legs fit here.
- `tests/headless/test_wave_modes.tcl` (**410** / **137**) — owns multi-trace
  strips and the index mapping; the extracted `delete_traces` proc's pure/model
  legs fit here.

Full battery, must stay green at these counts (DISPLAY / nogui) — take the
**post-0175** numbers as the real baseline and say so:
`test_wave_snap` 59/36, `test_wave_grid` 80/44, `test_wave_legend` 44/33,
`test_wave_empty_strips` 94/28, `test_wave_modes` 410/137,
`test_wave_markers` 712/328, `test_wave_viewer` 349/48,
`test_wave_clear_all` 68/3, `test_ase_plot` 150/30,
`test_wave_trace_menu` 223/71, `test_wave_split_strip` 221/80,
`test_wave_drag_preview` 46/18, `test_ase_persist` 109/17,
`test_ase_unnamed_net` 28/28, `test_ase_window` 166/31.

⚠ `test_ase_plot`'s gesture legs — and `test_wave_markers`' generated-key legs —
flake 1-2 in 10 under WSLg and always have. Judge upstream/downstream of what you
touched, then re-run. Do not "fix" the flake.

## Process

`tests/headless/run_suites.sh` with `SUITE_TIMEOUT=900`, never a bare loop.
**Soak the DISPLAY arm 10x** — DEL is a generated-key leg and those are the flaky
ones, so a single green run is not evidence here.

Then: **build → suites green → COMMIT → raise
`tools/review_gate/review_gate.sh` in the background.** Never push.

⚠ **This one destroys user data on a single keystroke**, so the manual pass
matters more than usual. Hand me the sequence: select a trace that has a marker
on it, DEL, then `u`. I want to see the trace and its marker come back together,
and I want to see a neighbouring trace's marker still pointing at the right
trace afterwards.

## Docs to update

- **New issue file** `doc/claude/issues/0176-del-deletes-selection.md` — the
  routing rule, the cascade, D1's both-kinds answer, and **the `delete_ok`
  undo/log gap you repaired on the way** (that is a separate pre-existing defect
  and deserves its own paragraph, not a footnote).
- `doc/claude/specs/graph_markers.md` — Delete now has two arms; the marker arm is
  unchanged but is no longer the only one.
- `doc/claude/specs/waveform_viewer_modes.md` §14 — the delete path now
  participates in undo; add it to the mutation list.
- `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 — extend
  landmine 17's key list with the new Delete arm, and record the lesson if the
  cascade/sweep bit you: *"a trace delete has THREE index consequences — the
  doomed trace's markers are dropped, survivors in the same graph shift down, and
  the dropped marker NUMBERS must be swept window-wide."*
