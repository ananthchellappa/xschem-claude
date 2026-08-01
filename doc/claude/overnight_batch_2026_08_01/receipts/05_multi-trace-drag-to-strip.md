# Item 05 multi-trace-drag-to-strip

- commit: `5648fe6f` (+ a fixup commit from the repair stage — see git log)
- files changed:
  - `src/xschem.h`
  - `src/draw.c`
  - `src/scheduler.c`
  - `src/actions.c`
  - `src/xinit.c`
  - `src/wave_viewer.tcl`
  - `tests/headless/test_wave_modes.tcl`
  - `tests/headless/test_wave_drag_preview.tcl`
  - `tests/headless/test_wave_trace_menu.tcl`
  - `doc/claude/specs/waveform_viewer_modes.md`
  - `doc/claude/specs/waveform_viewer.md`
  - `doc/claude/code_analysis/waveform_subsystem_reference.md`
  - `doc/claude/code_analysis/ovb01_05_multi_trace_drag_to_strip_decision.md`
  - `doc/claude/overnight_batch_2026_08_01/prompts/05_multi-trace-drag-to-strip.md`
  - `doc/claude/issues/0192-multi-trace-drag-to-strip.md`
- tests: `tests/headless/test_wave_modes.tcl`, `tests/headless/test_wave_drag_preview.tcl`,
  `tests/headless/test_wave_trace_menu.tcl` — 1319 checks (was 1170)
- non-baseline audit fails claimed:
  - `test_wire_vertex_grab` — FAIL in the audit on 'shorten: wire is (0,0)-(60,0)' / 'grow: wire is (0,0)-(150,0)'; RESULT: ALL PASS standalone. A wire-editing suite; this item touches no wire code (its only non-viewer edits are two `graph_preview_n = 0` reset lines).
  - `test_launch_context` — FAIL in the audit on 'main window has a usable size (geom=1x1+0+0)'; RESULT: ALL PASS standalone. The same WSLg window-geometry flake item 04's receipt already claimed. Nothing in it touches graphs.
- docs updated:
  - `doc/claude/specs/waveform_viewer_modes.md` — new §19 (19.1 gesture + why the set is decided at PRESS time, 19.2 the model ops and the one new index term, 19.3 the one mutation and its ordering contract, 19.4 the singular/plural dispatch, 19.5 the shrink preview as a SET, 19.6 the tests + the nine sabotages + the honest unassertable list); two new rows in §15.1's LMB/RMB ownership table splitting the trace-drag row into UNSELECTED vs SELECTED; an 'Extended by §19' box at the head of §13
  - `doc/claude/specs/waveform_viewer.md` — new 'REVISION 2026-08-01 (issue 0192): the arm is a SET' block inside the item-6 'Mid-drag shrink preview' section: the head keeps its meaning, the new getter, the trailing-pairs setter, the cap and its truncation rule, one writer / one predicate, per-strip centres (D-50), and the N-wide eyeball gap
  - `doc/claude/code_analysis/waveform_subsystem_reference.md` — new landmine 49 ('a multi-object viewer gesture FOLDS the pure primitive and owes ONE of everything'), with (a) the per-SOURCE index adjustment and the fixture that can see it, (b) one undo/regenerate/log line with NORMALISED indices, (c) a shipped log line is a replay contract, (d) the head/set/count + one-writer + one-predicate storage reused from landmine 46; §8's trace-drag paragraph, §9's verb list (get graph_preview, get graph_preview_set, the extended set graph_preview) and §13's suite list (MV*)
  - `doc/claude/issues/0192-multi-trace-drag-to-strip.md` — new, in 0189's house style: symptom/ask, what was MEASURED before any code (the shrink is already shipped; a press does not change the selection), the fix, the decisions that mattered, the source-level leg, files, and what no check can see
  - `doc/claude/code_analysis/ovb01_05_multi_trace_drag_to_strip_decision.md` — Status line updated to IMPLEMENTED with the three places implementation refined the doc (SAB-4's and SAB-9's 'exactly this and nothing else' predictions, and SAB-6's target moving from DM2 to DM6)
  - `doc/claude/overnight_batch_2026_08_01/receipts/05_multi-trace-drag-to-strip.md` — the receipt (left UNCOMMITTED for the batch's final ledger commit, as the prompt requires)
- decision doc: /home/qflow/dev/xschem/claude_1/xschem/doc/claude/code_analysis/ovb01_05_multi_trace_drag_to_strip_decision.md
- implementation prompt: /home/qflow/dev/xschem/claude_1/xschem/doc/claude/overnight_batch_2026_08_01/prompts/05_multi-trace-drag-to-strip.md

## Spec holes resolved (SURFACE THESE TO THE USER)

1. **Q:** D-41. What happens when the press lands on a trace that is NOT in the current selection, while a selection exists elsewhere?
   **Decision:** Drag that one trace alone — exactly today's behaviour. The selection is neither extended, collapsed nor cleared by the press.
   **Why:** The user's sentence is conditional: "When multiple traces are selected, an LMB-press-and-drag with press on one of them". Silently extending a selection on a press is the class of surprise that issue 0174 D3 already ruled against for clicks. Keeping this path byte-identical is also what lets the shipped single-trace log line survive (D-42).
   **Rejected:** (a) always move the whole selection — a press on an unrelated trace would teleport traces the user was not touching; (b) collapse the selection to the pressed trace at press time — destroys a selection built for another purpose, and the C release arm already does this for a genuine click.

2. **Q:** D-42. Should the drop always call a new plural mutation, or keep the shipped singular one for the one-trace case?
   **Decision:** Keep both. `wviewer::move_trace` (shipped) when the moving set is exactly the pressed trace; the new `wviewer::move_traces` otherwise.
   **Why:** `wviewer::move_trace 0 0 1 <tok>` is a REPLAY CONTRACT — it is what the action log records, what TD1/TD2/TD7 in test_wave_viewer.tcl assert verbatim, and what test_wave_modes.tcl MG15 drives. Routing the single case through a new verb would rewrite that line for no behavioural gain and break replay of every log already on disk. The dual path costs about four lines.
   **Rejected:** One verb for both (breaks the shipped log line and 8+ assertions); `move_trace` delegating to `move_traces` (it would have to suppress the inner log line and synthesise the outer one — more code, not less).

3. **Q:** D-43. The selection spans several SOURCE strips. Move all of them, or only those on the pressed strip?
   **Decision:** Move all of them.
   **Why:** The user wrote "all selected traces". `move_trace_in_graphs` is already parameterised on `(from_gi, from_ti)`, so a fold over it needs no new model concept.
   **Rejected:** Moving only the traces from the pressed strip — arbitrary, and invisible to the user until traces go missing from the drop.

4. **Q:** D-44. The destination strip is one of the source strips (some selected traces are already there).
   **Decision:** Traces already on the destination stay exactly where they are — not re-appended, indices unchanged; the others move in. A drop where nothing at all would move mutates nothing and logs nothing.
   **Why:** The shipped `from_gi == to_gi` rule (spec §13.3) says a drop on the source is not a state change; applying it per pair is the same rule. Re-appending would silently reorder a strip the user did not ask to reorder, and spec §12's opening sentence says a drag never touches a strip's internal trace order.
   **Rejected:** Re-appending the same-strip members so the whole selection ends up contiguous at the bottom — a hidden reorder.

5. **Q:** D-45. What order do the moved traces take in the destination?
   **Decision:** Appended at the end, in SOURCE order = ascending by (strip index, trace index), each keeping its expression, alias, vector and colour.
   **Why:** It is the shipped single-trace rule applied N times; it is deterministic so the log line replays identically; and it preserves the reading order of the stack.
   **Rejected:** Pick order (there is none — a selection is a set, not a history); pressed-trace-first (privileges an accident of where the pointer landed).

6. **Q:** D-46. Can the drag state machine carry a SET, or does this item require rewriting it? (PLAN.md's stated DEFER trigger.)
   **Decision:** It can. One new per-window array `tdrag_pairs` beside the five that already exist. NOT a defer.
   **Why:** The state machine already carries `(gi, ti)`; carrying a list of them changes no control flow. The mutation layer already has the N-object shape in `delete_items`. Verified at wave_viewer.tcl:381-391 (creation), :526-529 (teardown in `forget`), :4047 (`trace_drag_clear`).
   **Rejected:** DEFER. The trigger did not fire and deferring would have been a fudge for "this looks like several files".

7. **Q:** D-47. What is the "cool-factor shrink" and what is actually left to build?
   **Decision:** It is already shipped. Do NOT change the shrink factor, the shrink maths or the knob. Build only the PLURAL arm — the preview takes a set of (strip, node) pairs instead of one.
   **Why:** Source shows `draw_graph_points` (draw.c:3548-3614, :3666-3670) already scales BOTH X and Y about the plot-box centre; the magnitude is already one knob, `::wviewer_drag_shrink` (wave_viewer.tcl:4129), default 0.7, rc-overridable with a documented fallback; it is already `flags & 16` chrome stripped from every export; and it already has a dedicated 46-check suite. The value 0.7 was tuned by the user's own eyeball on 2026-07-29 ("shrink should be in both X and Y, not just Y. Bump up the shrink to 30 %"), so re-tuning it is an eyeball question, not an implementation one.
   **Rejected:** A second constant for the multi case (two knobs for one effect is exactly the drift landmine 45(a) warns about); scaling the shrink by the number of traces (unrequested and unassertable).

8. **Q:** D-48. Where does the multi-trace preview state live?
   **Decision:** In `xctx`, in the `graph_marker_sel` shape: keep `graph_preview_gi`/`_wave` as the HEAD with their exact current meaning, add FIXED arrays `graph_preview_set_gi[]`/`_set_wave[]` plus `graph_preview_n`, with ONE writer (`graph_preview_arm()`) and ONE draw-side predicate (`graph_preview_has()`).
   **Why:** Landmine 46 is explicit that this is the pattern and that a fixed array is required because `xctx` is reset rather than freed. Keeping the head means `xschem get graph_preview` and all seven shipped DV legs stay byte-identical, which is the same compatibility story that made issue 0189 cheap.
   **Rejected:** (a) Replacing the scalars with the array only — churns the shipped getter and its tests for nothing; (b) an array in `Graph_ctx` — six call sites build a local `Graph_ctx` and the set is window-wide, so it would be recomputed per graph per draw; (c) a prop token — the preview is transient chrome and a token would persist, paste and export (landmine 19).

9. **Q:** D-49. What happens to `Graph_ctx.preview_wave`?
   **Decision:** Rename it to `preview_gi`: the rect index this draw may preview, or -1. Keep the default at setup_graph_data:3823, ABOVE the RECT_OUTSIDE early return. The per-trace membership question moves into `graph_preview_has()`.
   **Why:** The per-graph question stays in Graph_ctx (so `draw_graph_points` does no set walk when nothing is armed), and there remains exactly ONE comparison site. The default must stay above the early return because `gr` is the shared `xctx->graph_struct` and a stale value leaks onto the next graph (landmine 11).
   **Rejected:** A fixed array of node indices inside Graph_ctx — 256 more bytes on a struct six call sites build on the stack, to answer a question one global predicate already answers.

10. **Q:** D-50. When the selection spans several strips, where do the traces shrink to?
    **Decision:** Each shrinks about its OWN strip's plot-box centre, in place. No change to the centre computation.
    **Why:** `prev_c`/`prev_cx` already come from the `gr` of the graph being drawn, so this is free and correct. Making the bundle visually gather at the pointer would be a new floating-overlay render outside each rect's bbox clip — a different feature.
    **Rejected:** A pointer-following ghost of the carried traces. Recorded as an eyeball question and a possible follow-up rather than built.

11. **Q:** D-51. Does a source strip survive being emptied by the move?
    **Decision:** Yes, unchanged.
    **Why:** Deleting it would renumber the stack behind the user's back and lose its axis settings (spec §13.1). Tidying empty strips is the bare `e` gesture, and it is the user's to make.
    **Rejected:** Auto-removing emptied source strips.

12. **Q:** D-52. What happens to the selection after the move?
    **Decision:** It follows the traces, and it is free: each moved trace joins the destination's set at its appended node index, each source's remaining selection shifts past every hole, and an unrelated destination selection survives.
    **Why:** All of that is `move_trace_in_graphs`' shipped behaviour repeated by the fold. On PLAN.md's warning that `remap_hilight_after_trace_move` returns `{}` for two different reasons: source shows the shipped caller already avoids the trap — `moved_was_bold` is computed independently at wave_viewer.tcl:3303 rather than inferred from an empty return, and `remap_sel_after_trace_move` (:3240) is already the SET form. It is an invariant to preserve, not a defect to fix.
    **Rejected:** Dropping the selection on a move (a stale node index bolds the WRONG trace, which spec §15.5 says is worse than losing the selection).

13. **Q:** D-53. Who reads the live window-wide selection?
    **Decision:** One reader: a new `wviewer::selection_pairs {W}` returning MODEL {strip, trace} pairs. Both `trace_drag_arm` and `delete_selection_at` call it.
    **Why:** Landmines 43 and 46(a): two folds of the same state drift, and the drift is invisible to any test that exercises only one path. The extraction is about eight lines moved out of `delete_selection_at` (wave_viewer.tcl:4950-4958) and is behaviour-identical.
    **Rejected:** A second inline loop inside `trace_drag_arm` — the exact shipped bug shape those landmines were written about.

14. **Q:** D-54. How many undo points does a multi-trace move take?
    **Decision:** Exactly ONE `wviewer::push_undo`, immediately after `capture_live_graph_state`, so a single `u` restores every trace AND the mouse-written pan/zoom/bold that preceded the edit.
    **Why:** Precedent: `delete_items` (issue 0176 D5) and landmine 46(c) — "a multi-object delete owes exactly ONE undo point; split the primitive, never loop the public form". Here the equivalent is that the fold runs on the PURE layer, so no intermediate state is ever snapshotted. A one-key gesture that takes three `u` to undo is the defect this shape prevents.
    **Rejected:** One undo point per moved trace (this is sabotage SAB-2).

15. **Q:** D-55. What happens to an EMPTY destination strip's axis ranges?
    **Decision:** Blanked to auto on the drop, exactly once (on the first fold step); a destination that already holds traces keeps the window the user is looking at.
    **Why:** Landmine 34(a): `capture_live_graph_state` has just frozen whatever window the last fit left on the empty strip, and a microamp trace dropped into a 0-2 V window is drawn off-screen — the drop looks like it failed. This is shipped behaviour that the fold inherits for free.
    **Rejected:** Blanking on every step (would discard the window the earlier arrivals just established) or never blanking (sabotage SAB-3).

16. **Q:** D-56. Escape mid-drag, a sub-threshold click, and a drop outside every strip.
    **Decision:** All three commit nothing and log nothing, and all three take the shrink preview down. The existing teardown order in `trace_drag_reset` — preview cleared BEFORE the feedback frame repaint — must not be disturbed.
    **Why:** The shipped rule (spec §13.1), and that ordering exists because doing it the other way leaves a shrunk trace on screen until the next repaint on the paths where no feedback frame was ever painted (wave_viewer.tcl:4067-4074 says so in its own comment).
    **Rejected:** Committing a partial move on a drop outside the stack.

17. **Q:** D-57. What does the replay log line look like?
    **Decision:** One line: `wviewer::move_traces {{0 1} {0 3} {1 0}} 2 <token>` — the NORMALISED pairs (deduped, ascending, destination-strip members dropped) by explicit index, plus the explicit token.
    **Why:** Selection state does not exist at replay time (spec §15, issue 0175 D8), and the normalised list is what was actually applied, so replaying the line reproduces this run exactly (issue 0176 D6, the same reason `delete_items` logs its normalised pairs).
    **Rejected:** Logging the raw press-time list (a replay would re-derive a different move if a pair was dropped); logging N singular `move_trace` lines (N undo points on replay, contradicting D-54) — the latter is sabotage SAB-8.

18. **Q:** D-58. Which test suites get which legs?
    **Decision:** Three, each the honest home: `test_wave_modes.tcl` gets a new PURE `MV*` group (both arms) beside its M7/M8/DT groups; `test_wave_drag_preview.tcl` gets `DV8`-`DV12` (verb, both arms) and `DM1`-`DM6` (gesture, DISPLAY); `test_wave_trace_menu.tcl` gets the end-to-end `MM*` group (DISPLAY). No new suite file, so no `full_audit.sh` registration change.
    **Why:** `test_wave_trace_menu.tcl` is the ONLY suite with a live multi-trace strip built hermetically (`xschem raw new`/`raw add`, no ngspice) and it already drives Ctrl+click multi-select through the shipped bindings. `test_wave_drag_preview.tcl` owns `graph_preview`. `test_wave_modes.tcl` owns the pure list/index math. Note `M9` is already taken in that file by issue 0173, hence `MV`.
    **Rejected:** Extending `test_wave_viewer.tcl`'s TD block as PLAN.md suggested — its fixture is ONE trace plus ONE empty strip and cannot host a multi-selection. It stays as the single-trace regression witness for D-42, and its count must not change.

19. **Q:** D-59. Is the preview set capped, and what happens on overflow?
    **Decision:** `GRAPH_MAX_PREVIEW_WAVES 64` (matching `GRAPH_MAX_SEL_WAVES`). An over-long set truncates the PREVIEW only — the move itself is uncapped.
    **Why:** A preview is chrome. The worst case of overflow is that the 65th carried trace is drawn full size while it travels. Refusing the gesture because the bundle is large would turn a cosmetic limit into a functional regression. Fixed array, never a pointer, because `xctx` is reset rather than freed (landmine 46(b)). Deliberately NOT mirrored in Tcl — Tcl reads the list back and never needs the cap (the `GRAPH_MARKER_MAX_SEL` rule).
    **Rejected:** A dynamic allocation; refusing a selection larger than the cap.

20. **Q:** D-60. Does the pointer change for a multi-trace drag?
    **Decision:** No. The shipped `hand2` grab hand, set on the PRESS, unchanged for any number of traces.
    **Why:** PLAN.md's recommendation, and the affordance is the same one: pressing a trace means you are holding it. A second cursor for the multi case would be a new thing to learn for no information gain — the shrink already shows how many traces are being carried.
    **Rejected:** A distinct multi-drag cursor.

## PLAN.md claims refuted by source

- PLAN.md Q5, 'What is the cool-factor shrink? -> during the drag, each moving trace is rendered scaled toward its strip's vertical midline (a transient, bit-16 render). Put the magnitude behind ONE named constant so it is a one-line tune at eyeball time. ... the equivalent viewer-plan item 6 was specified Y-only at 10 % and the user rejected it on sight.' REFUTED as new work: the shrink is ALREADY SHIPPED and the rejection was already acted on. draw_graph_points (src/draw.c:3548-3614 and :3666-3670) scales BOTH X and Y about the plot-box centre; the magnitude is already ONE knob, `::wviewer_drag_shrink` (src/wave_viewer.tcl:4129), default 0.7 (a 30 % shrink), rc-overridable with a documented out-of-range fallback; it is already flags-bit-16 chrome stripped from every export (draw.c:7222-7234); and it already has a dedicated suite, tests/headless/test_wave_drag_preview.tcl, measured ALL PASS (46 checks). The fix landed 2026-07-29 and is written up in doc/claude/specs/waveform_viewer.md. The remaining work is ONE trace -> N.
- PLAN.md 'Likely files: ... src/xschem.h (the shrink constant, mirrored in Tcl if Tcl needs it)'. REFUTED: there is no C #define for the shrink and there must not be one — the knob is a Tcl global so an rc file can set it. The only new C constant this item adds is the preview-set cap `GRAPH_MAX_PREVIEW_WAVES`, and that one is deliberately NOT mirrored in Tcl (Tcl reads the list back through the new getter and never needs the cap — the GRAPH_MARKER_MAX_SEL precedent at src/xschem.h:451-458).
- PLAN.md 'Likely files: src/draw.c (the shrink render + graph_wave_at)'. PARTIALLY REFUTED: the shrink render exists and is edited only at its single comparison line (draw.c:3548); and `graph_wave_at` (draw.c:5851) is not touched at all — the pick already returns the NODE index the arm needs, and GRAPH_TRACE_PICK_TOL is shared by four surfaces and must not move (landmine 33). Also `src/callback.c`, listed as a likely file, needs no change whatsoever: no C gesture routing is altered.
- PLAN.md Q7, '`remap_hilight_after_trace_move` returns `{}` for two different reasons ("no highlight" and "the bold trace is the one that left") and the caller must test which, or an unbolded move silently bolds something in the destination.' TRUE of the helper (src/wave_viewer.tcl:3200-3206) but ALREADY HANDLED by the shipped caller: `move_trace_in_graphs` computes `moved_was_bold` independently at :3303 rather than inferring it from an empty return, and the SET form `remap_sel_after_trace_move` already exists at :3240. This is an invariant to preserve, not a defect to fix.
- PLAN.md test-plan seed, 'extend the TD* block in tests/headless/test_wave_viewer.tcl (it is the suite that already owns trace drag) ... Carry the inert `sdid` per-strip key'. PARTIALLY REFUTED: `sdid` already exists there (tests/headless/test_wave_viewer.tcl:1884-1886), but that fixture is ONE trace on strip 0 plus an EMPTY strip 1 and cannot host a multi-selection at all. The tree's only live multi-trace fixture is test_wave_trace_menu.tcl's `fill_viewer` (:406 — three traces on strip 0, one on strip 1, hermetic raw at :482-486), which is also the only place Ctrl+click multi-select is already driven through the shipped bindings (`ts_click`, :1277). The decision doc moves the gesture legs there and keeps TD* as the untouched single-trace regression witness.
- Tree drift, not a PLAN claim: src/xschem.h:1771 says the preview state is 'Reset in graph_preview_clear(), clear_drawing() and alloc_xschem_data()'. There is NO `graph_preview_clear()` function anywhere in src/ — the resets are inline at src/actions.c:1935-1937 and src/xinit.c:686-688. The prompt has the implementer correct the comment (not add the function) while editing that block.

## Sabotage

- **SAB-1** — target: MM1, MM5 (must LEAVE MM7 + all TD* green). failedExactly: **true**.
  Killed MM1(3 legs), MM2(3), MM4(2), MM5(3), MM6(2), MM11(1). MM7 stayed GREEN and test_wave_viewer.tcl stayed ALL PASS (368) — the critical cross-check passes, so MM7 really is driven from an UNSELECTED trace and D-41 is tested. The MM2/MM4/MM6/MM11 deaths are the same property seen from other angles, not collateral.
- **SAB-2** — target: MM3's depth leg (must LEAVE MM3's content leg green). failedExactly: **true**.
  push_undo moved inside the fold, one per pair. Exactly one leg died: 'MM3 the gesture took exactly ONE undo point' -> {2}. MM3's content legs and the other 380 checks stayed green.
- **SAB-3** — target: MM11, MV9. failedExactly: **true**.
  Implemented inside move_traces_in_graphs (restore the destination's x1/x2/y1/y2 after the fold) rather than by deleting the blanking from the shipped primitive, so the sabotage stays local to the new code. Killed MV9's empty-destination leg and both MM11 legs; nothing else in either suite.
- **SAB-4** — target: MV8 (decision doc says 'and only this'). failedExactly: **false**.
  LOUDER THAN PREDICTED, and the prediction is unachievable as written. Dropping '- $done($gi)' killed MV8 (3 legs) plus MV1/MV2/MV3/MV5/MV6/MV7/MV9/MV10 — i.e. every leg that moves >=2 traces out of ONE source, which includes the MV1 the prompt itself specifies ('two pairs from ONE source'). Decision doc §7's 'leave MV-1 (single source, single trace) green' describes a leg the prompt does not define. MV8 died with exactly the signature the design predicts: v(d) travelled instead of v(c). MV4/MV11/MV12 stayed green.
- **SAB-5** — target: DM1, DM2 (must LEAVE DV8 + DG1 green). failedExactly: **true**.
  Killed DM1 (2 legs) and DM2 (1 leg) only. DV8, DG1, DM3, DM4, DM5 all green — the second critical cross-check passes, so the DV8 verb leg tests the C storage rather than the Tcl arm.
- **SAB-6** — target: DM2 per the decision doc; retargeted to DM6. failedExactly: **true**.
  Killed exactly one check: 'DM6 the predicate matches on the set element's GI'. ⚠ Its NAMED behavioural target DM2 cannot see it: the gi half of graph_preview_has() affects PIXELS ONLY (the arm, which is what `get graph_preview_set` reads back, is identical either way). So it is pinned at SOURCE level inside DM6 (extracting the function body by signature, the MS13 ms_fnbody idiom) and recorded as a genuine unassertable.
- **SAB-7** — target: DM3, MM7 (must LEAVE MM1 green). failedExactly: **true**.
  trace_drag_arm takes the selection unconditionally. Killed DM3 (1 leg) and MM7 (2 legs) only; MM1 and the rest stayed green.
- **SAB-8** — target: MM4 (must LEAVE MM1 green). failedExactly: **true**.
  One log line per pair. Killed MM4 (4 legs) plus the single log leg of MM5 and of MM6 — those two assert the identical 'ONE mutation line' property, so this is the same target seen three times, not collateral. MM1's content legs stayed green.
- **SAB-9** — target: MM1's order leg, MV2 (decision doc says MM1's arrival-COUNT leg survives). failedExactly: **false**.
  LOUDER THAN PREDICTED. Descending fold killed MV2 and MM1's order leg as designed, plus ~19 more MV* and 8 more MM* legs including the arrival COUNTS: on a 0-and-2 fixture a descending fold computes 0 - 1 = -1, which move_trace_in_graphs REFUSES, so only one trace arrives. The decision doc's 'the count leg survives' holds only for a fixture whose lowest moving index is >= the number of movers from that strip; the prompt's MM0/MM1 fixture (non-contiguous 2-of-3, i.e. 0 and 2) is not one.

## Verifier (fresh adversarial context, not the implementer)

- ok: **true**
- audit matches baseline: **false**

### Sabotage reproduced independently

- S1 (the fixup's own witness) — restored `|| $to == $from` in wviewer::trace_drag_drop (src/wave_viewer.tcl:4494). Result `RESULT: 5 FAILED (392 passed)`, and the five are EXACTLY MM14's behavioural legs: 'MM14 strip 1's trace moved IN' -> {vec_a {} vec_b vec_c}; 'its source is emptied and SURVIVES' -> {4 1 1}; 'the selection followed' -> {0 0 -}; 'ONE mutation line' -> {}; 'exactly ONE undo point' -> {0}. Every MM1-MM13 leg and both frame legs stayed green. `git diff src/wave_viewer.tcl` showed only the one-line sabotage before revert; reverted by restoring a pre-sabotage copy (git checkout -- would have been safe here since the tree is committed, but the copy is equivalent) and `git status --porcelain -uno` returned to the two PREFLIGHT files.
- S1 counter-check: this is the leg the FIRST commit failed. Confirms the repair stage's central claim is really witnessed, and that MM8/MM6 alone could not see it (they stayed green under the sabotage).
- SAB-2 — `wviewer::push_undo $token` in move_traces replaced by `foreach __sab2 $norm { wviewer::push_undo $token }` (one per pair). Result `RESULT: 1 FAILED (396 passed)`, killing EXACTLY 'MM3 the gesture took exactly ONE undo point -> {2} (exp {1})'. MM3's content legs ('one `u` returns 1', 'it put every trace back', 'the selection with them', 'the depth moved by exactly 1') and all 395 other checks stayed green — i.e. the depth leg and the content legs really are independent. Reverted; clean re-run `RESULT: ALL PASS (397 checks)`.

### Audit detail

My run: `SUMMARY: 242 pass  18 fail  1 crash/timeout  11 skip  (total 272)`, `WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)`. PREFLIGHT baseline is 20 FAIL + 1 TIMEOUT (total 271; 272 because item 03 added a suite). 16 of my 18 fails plus the TIMEOUT are on the baseline list verbatim. FOUR baseline fails went green and are not claimed as wins (test_pristine_untitled_viewer_0172, test_readonly_action_dispatch, test_verb_noun_copy_move, test_wave_markers). TWO fails are NOT on the baseline list — test_wave_drag_preview and test_palette — both detailed in problems[] and both green standalone. Net fail count is DOWN, not up.

### Problems

- AUDIT EXTRA #1 (the item's OWN suite): `GUI_GATE=0 bash tests/headless/full_audit.sh` reported `FAIL | test_wave_drag_preview` with `FAIL: DG4 the sampled column really does cross a trace -> {0} (exp {1})` and `FAIL: DG3 armed again for the cancel leg -> {0} (exp {1})`. test_wave_drag_preview is NOT on PLAN.md's PREFLIGHT fail list, and the item receipt claims its audit was clean there. I reproduced the same `2 FAILED (92 passed)` once standalone out of 11 display runs (the other 10 were ALL PASS (94)). Mitigating: both legs are SHIPPED legs introduced by 9727791a (viewer plan item 6), not legs this item added, and both are downstream of one pixel-column geometry sample — the WSLg geometry-flake class PLAN.md §Known-flaky names. Counter-evidence is thin: the pre-item file (`git show 5648fe6f^:tests/headless/test_wave_drag_preview.tcl`) ran ALL PASS (46) 6/6, which cannot distinguish a ~1/11 rate. Not proven a regression; genuinely unrecorded.
- AUDIT EXTRA #2: `FAIL | test_palette`, also not on the PREFLIGHT list. Its audit block ends at `QUERY '' -> 151 results (all commands)` with NO `RESULT` line — the run died before the final marker, which is how full_audit scores it FAIL. Standalone it emits no FAIL line and reaches `EVENT opens palette: yes`. Item 05 touches no palette, action-table or library code; this is the WSLg Xwayland/abort class PLAN.md names. (The `library_list = exactly the 11 intended libs` FAIL line near it in the log belongs to test_sky130a_libmgr, which IS on the baseline list, not to test_palette.)
- COVERAGE: MM10's Escape leg calls `wviewer::strip_drag_cancel $vdrw` directly rather than delivering an Escape KeyPress, so the Escape BINDING is not witnessed end to end for a multi-trace drag. Mitigated by TD5 in test_wave_viewer.tcl, which does `focus -force` + `event generate <KeyPress> -keysym Escape` for the single-trace drag and asserts tdrag state {-1 -1 0}.
- COVERAGE: the singular/plural dispatch `if {[llength $movable] == 1 && [lindex $movable 0] eq [list $from $ti]}` has a third case no leg drives — a MULTI-trace carried set whose movable reduces to exactly the pressed pair (selection {{0 0} {1 0}}, press strip 0 trace 0, drop on strip 1) takes the SINGULAR `move_trace` branch and logs `wviewer::move_trace`, not `move_traces`. MM6 has 2 movable pairs and MM14's movable is not the pressed pair, so this branch is exercised only by MM7's genuinely-single case. Behaviourally equivalent (one undo point, one log line, same result), so this is a coverage note, not a defect.
- DISCIPLINE SCOPE: DM6's `xctx->graph_preview_n\s*=[^=]` count of 2 is scoped to src/draw.c only, but `graph_preview_n` is in fact assigned in three files — actions.c:clear_drawing and xinit.c:alloc_xschem_data also write it directly, bypassing the declared ONE-writer `graph_preview_arm`. Both are consistent with the sibling graph_preview_* scalars beside them and both are commented, but a fourth direct writer added anywhere outside draw.c would be invisible to DM6.
- LEDGER: `doc/claude/overnight_batch_2026_08_01/PLAN.md` still carries `- [ ] 05 multi-trace-drag-to-strip` and the receipt `receipts/05_multi-trace-drag-to-strip.md` is untracked. Both are orchestrator-owned per the item prompt, so this is a note for the batch's final ledger commit, not an item defect.

- notes: (none)

## Repair stage report

Both problems fixed at item scope; committed as `ef567e2b`.

### What was wrong (re-verified from source, not from the notes)

**1. BLOCKING — the contract clause.** Confirmed exactly as reported. `src/wave_viewer.tcl` `trace_drag_drop` had `if {!$active || $to < 0 || $to == $from} { return {} }` *before* the `movable` filter, so any drop back on the pressed trace's own strip short-circuited the whole gesture. D-44 said "Recommendation taken" with no deviation note. `MM8` is the all-on-one-strip case, `MM6` drops on strip 1 — neither could see it.

**2. SECONDARY — the fixture.** Confirmed: `mmspec` had no vec-less trace, so NODE index == MODEL index in every `MM` leg.

### What I changed

- **`src/wave_viewer.tcl`**: new PURE `wviewer::movable_pairs {pairs to_gi}` — the one answer to "would a drop here commit", read by the drop, the refusal *and* the drop-target frame. Guard is now `!$active || $to < 0`. `trace_drag_feedback`'s 4th arg went from the press strip to the carried set (gate `$new != $from` → `movable_pairs`), `trace_drag_motion` resolves the carried set once at the top, and `trace_drag_arm` seeds `tdrag_to` at `-1` instead of the pressed index — otherwise the first motion inside the pressed strip reads as "nothing changed" and the frame never paints. Direction **(a)**: implement the clause, do not re-negotiate it.
- **Tests**: `MV13` (9 pure checks, `test_wave_modes.tcl`, both arms); `MM14` (12 checks, the verifier's own X1 probe end-to-end, plus both frame states); `MM8` +3 checks including the negative frame state and a real-threshold witness; `mmspec` → `{{vec_a - vec_b vec_c} {vec_d} {vec_e}}` with `mm_fill` reading `-` as a vec-less plant.
- **Docs**: spec §19.1 refusal rows + new §19.1.2, §13 extension note, §13.5 frame rule, §19.2/§19.6; decision doc D-44 ⚠ block + Status header; issue 0192 §2 and new §7; subsystem reference landmine 49 (e) and (f). The receipt (untracked, orchestrator-owned) carries a full FIXUP section.

### What I ran

Sabotage, each copy-restored (`git checkout --` would have discarded uncommitted work), then a clean green re-run:

| id | sabotage | killed | left green |
|---|---|---|---|
| S1 | restore `\|\| $to == $from` | exactly 5 `MM14` legs | 392 others, all `MM1`-`MM13` |
| S2 | feedback frames unconditionally | exactly `MM8`'s negative frame leg | 396 others; `test_wave_viewer` 368 |
| S3 | `selection_pairs` node-as-model | 13 legs on the new fixture | **`ALL PASS (381)` on the pre-fixup one** |
| S4 | `movable_pairs` drops its filter | 3 `MV13` + `MM8`'s frame leg | `MM8`'s model legs (the pure fold refuses independently) |

S3 is the measurement that closes finding 2: the broken mapping was **completely invisible** to the committed fixture.

Counts: `test_wave_modes` 203→212 / 476→485, `test_wave_trace_menu` 381→397, `test_wave_drag_preview` 43/94 unchanged, `test_wave_viewer` **368 unchanged** (D-42's witness).

`GUI_GATE=0 bash tests/headless/full_audit.sh`: `SUMMARY: 260 pass 12 fail 0 crash/timeout 0 skip (total 272)`, `WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)`. 11 of 12 fails are on the PLAN PREFLIGHT list verbatim.

### What remains

- The 12th audit fail is `test_wave_trace_menu` at `396 passed, 1 failed` on **`TL4`** ("the probe really ran under a coarse grid") — a plain-`<Motion>` `mousex_snap` leg in the LEGEND block, of the flake class the item receipt already records for this suite. Standalone it is `ALL PASS (397)` **6 runs out of 6** (including a 4-run soak); no `MM*`/`MV*` leg failed in any run. `test_wave_markers` (on the list) is `ALL PASS (979)` standalone; its in-audit leg was `MS-X3` where the item-05 baseline shape was `MF1` — it flakes both directions.
- Not fixed, out of scope, noticed: the decision doc's §2.1 "what exists today" anchor table still quotes the pre-item `to == from` guard — it is an explicitly pre-implementation snapshot, so I left it.
- The receipt and `PLAN.md` under `doc/claude/overnight_batch_2026_08_01/` are **untracked** in this tree (

## What the tests structurally CANNOT see (eyeball list)

- That ANY trace actually renders shrunk, let alone N of them. Every DM/DV leg reads `xschem get graph_preview` / `graph_preview_set`, i.e. the ARM; nothing in any suite reads a pixel back, and there is no seam between S_Y()/S_X() and XDrawLines to intercept. The entire second half of the user's verbatim spec ('All selected traces being moved will display the cool-factor shrink') is verified only up to the C storage.
- That the shrink lands on the RIGHT trace of the RIGHT strip. graph_preview_has()'s gi term is pixels-only: a version matching by node alone would shrink node 2 of EVERY strip mid-drag and the arm read back by `get graph_preview_set` would be identical. It is pinned solely by DM6's source-level regexes over the extracted function body — a semantically equivalent rewrite (e.g. a helper, or a `!=`-and-continue form) would fail those legs while being correct, and a subtly wrong one that kept the same token shape would pass.
- That the reorder_handle=4 drop-target frame is actually DRAWN, and drawn legibly around the destination strip. MM8/MM14 assert the prop value 1 vs 4 on every rect, never a pixel.
- Whether 0.7 is the right shrink for a BUNDLE. It was eyeballed for ONE trace on 2026-07-29. One-line tune: `set ::wviewer_drag_shrink <0..1>` in xschemrc (1.0 disables the effect without disabling the drag).
- Whether traces shrinking IN PLACE on their own source strips (D-50) reads as 'I am carrying these' when the selection spans strips — they never gather at the pointer. This is a deliberate scope decision, not an accident, but only an eyeball can accept or reject it.
- Whether the destination frame plus N shrunk traces plus the hand2 cursor is legible at real viewer window sizes, and whether a 64-trace preview (or the 65th trace drawn full size at the cap) looks broken.
- The hand2 cursor SHAPE during a multi-trace drag specifically. `cget -cursor` proves the string, not what the user sees, and the multi-gesture legs only assert the RESTORE (MM10), never the press.
- That a real user's press lands where mm_px_for_node's synthetic column scan lands — GRAPH_TRACE_PICK_TOL proximity for a press that is near several selected traces at once is exercised only through the same scan the code uses.

## Tunable constants (for the eyeball pass)

- `src/wave_viewer.tcl:wviewer::drag_shrink=0.7` (rc override `::wviewer_drag_shrink`; THE one-line tune — it was eyeballed for a SINGLE trace on 2026-07-29 and a BUNDLE may want a different value; 1.0 disables the effect without disabling the drag)
- `src/xschem.h:GRAPH_MAX_PREVIEW_WAVES=64` (bounds the PREVIEW only — the move itself is uncapped, so a 65-trace selection just draws its 65th carried trace full size)

## Implementer summary

Item 05 implemented and committed as 5648fe6f (15 files, explicit stage list; the receipt is deliberately left uncommitted for the batch's final ledger commit). Build green. Verdict [E] — the unassertable list is non-empty by construction, which the PLAN and the decision doc both predicted ("the shrink is pure pixels").

WHAT SHIPPED. Press on a SELECTED trace and drag: every selected trace in the window moves to the strip you drop on, appended in SOURCE order, as ONE undo point, ONE regenerate and ONE log line carrying the NORMALISED pairs — and all of them wear the mid-drag shrink on the way. Press on an UNSELECTED trace and it is byte-for-byte today's gesture, wviewer::move_trace log line included (D-42, a replay contract).

BOTH measurements the design rests on reproduced before a line was written. (a) The "cool-factor shrink" is ALREADY SHIPPED — both axes, one rc knob at 0.7, bit-16 chrome, a 46-check suite — so this item made it carry N instead of 1 and changed neither the factor, the maths nor the knob. PLAN.md's notes for this item are out of date on six separate points, all listed in the receipt (including a header comment naming a graph_preview_clear() function that does not exist — the comment was corrected, the function deliberately not added). (b) A press does NOT change the selection; only the no-travel release does (with nodes 0 and 2 selected, a press on node 1 left {0 2} and the release collapsed it to {1}) — which is what makes the press-time read in trace_drag_arm a contract rather than a coincidence.

DESIGN. selection_pairs is THE one fold of the live selection into MODEL pairs (delete_selection_at rewired onto it, D-53); tdrag_pairs carries the set from press to drop; move_traces_in_graphs is a PURE fold over the shipped move_trace_in_graphs; move_traces is the one mutation in delete_items' N-object shape. The only new arithmetic is `ti - done(gi)` — each index adjusted by the count already removed from ITS OWN source graph. The preview became a SET in the graph_marker_sel shape: head scalars unchanged (so `xschem get graph_preview` is byte-identical and all seven shipped DV legs pass), a fixed set array, ONE writer (graph_preview_arm, which also owns the disarm), ONE draw-side predicate (graph_preview_has), Graph_ctx.preview_wave -> preview_gi, and a NEW `xschem get graph_preview_set`. No changes to callback.c, graph_wave_at/graph_trace_at/graph_near_wave, GRAPH_TRACE_PICK_TOL, move_trace, move_trace_in_graphs, move_trace_to_new_strip or delete_items.

TESTS (GUI_GATE=0, both arms). test_wave_modes 160->203 nogui / 433->476 display (MV1-MV12); test_wave_drag_preview 18->43 / 46->94 (DV8-DV12, DM0-DM6); test_wave_trace_menu 323->381 (MM0-MM13, on a THREE-strip fixture with inert sdid identities and a NON-CONTIGUOUS 2-of-3 selection built through the shipped Ctrl+click bindings); test_wave_viewer held at 368 — the single-trace regression witness D-42 requires not to move. All green. No new suite FILE, so no full_audit.sh registration change (it globs test_*.tcl).

AUDIT: SUMMARY: 248 pass 14 fail 0 crash/timeout 10 skip (total 272), WIREEDIT: PASS, SCRATCH: 0 leaked dir(s). The PLAN PREFLIGHT baseline is STALE (taken at e516cc85 before items 01-04 landed; its total 271 predates item 03's suite), so it is read against the 21-line FAIL list. 12 of the 14 fails are on that list verbatim, including test_wave_markers at exactly its baseline shape (1 FAILED, the leg is MF1, pass count UP at 978). Eight baseline fails went green in this run and are NOT claimed as wins. The two non-baseline fails are both ALL PASS standalone and are listed in nonBaselineFails.

TWO PROCESS FINDINGS. (1) The prompt's sabotage-revert recipe (`git checkout -- <file>`) is only safe for a file that is otherwise clean; on an uncommitted item it discards the feature along with the sabotage. It did exactly that once here and cost a full re-apply of src/wave_viewer.tcl. The nine sabotages were then run by restoring a pre-sabotage COPY, verified each time with `diff -q`. Future prompts should say so. (2) test_wave_trace_menu has a flake class BEYOND the known TG9: on PRISTINE HEAD, with zero edits in the tree, it came back `10 FAILED (313 passed)` in two runs out of three, on the TR3/TR4/TS8 legend-slot legs, which depend on the geometry WSLg hands back. Recorded, not chased, not introduced by this item.

SABOTAGE DEVIATIONS, both recorded in the receipt and in the decision doc's Status line: SAB-4 and SAB-9 are LOUDER than decision doc §7 predicts (§7's "MV-8 and only MV-8" is unachievable given the MV1 the prompt itself specifies, and a descending fold on a 0-and-2 fixture produces a negative index that the primitive refuses, so arrival-count legs die alongside order legs); SAB-6's named behavioural target DM2 cannot see it at all, because the gi half of the predicate affects pixels only — it is pinned at SOURCE level inside DM6, where it kills exactly one check.
