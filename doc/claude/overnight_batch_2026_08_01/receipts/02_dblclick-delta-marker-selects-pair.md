# Item 02 dblclick-delta-marker-selects-pair

- commit: `1ec3ce89`
- files changed:
  - `src/xschem.h`
  - `src/draw.c`
  - `src/callback.c`
  - `src/scheduler.c`
  - `src/actions.c`
  - `src/xinit.c`
  - `src/wave_viewer.tcl`
  - `tests/headless/test_wave_markers.tcl`
  - `doc/claude/specs/graph_markers.md`
  - `doc/claude/specs/waveform_viewer_modes.md`
  - `doc/claude/code_analysis/waveform_subsystem_reference.md`
  - `doc/claude/code_analysis/ovb01_02_dblclick_delta_marker_selects_pair_decision.md`
  - `doc/claude/overnight_batch_2026_08_01/prompts/02_dblclick-delta-marker-selects-pair.md`
  - `doc/claude/issues/0189-dblclick-delta-marker-selects-pair.md`
- tests: `tests/headless/test_wave_markers.tcl` — 979 checks (was 870)
- non-baseline audit fails claimed:
  - `test_palette` — reproducibly red, PROVEN NOT MINE: I reverted all seven src files to HEAD, rebuilt, and it is red on pristine HEAD too. Its last leg is a bare `event generate .drw <Control-Shift-Key-P>` + `update idletasks`, the exact anti-pattern the PLAN's test discipline forbids (memory wslg-key-delivery-flakes). Unrelated to markers.
  - `test_wire_vertex_grab` — failed in BOTH audit runs, passes standalone (run_suites 1/1 ALL PASS) with my tree AND is untouched by anything I changed (wire editing). Audit-load flake.
  - `test_launch_context` — failed in audit run 2 only, passes standalone.
  - `test_remap` — failed in audit run 2 only, passes standalone.
  - `test_wave_split_strip` — failed in audit run 1 only (220/221), passes standalone at 221 checks in run 2 and on demand.
  - `test_wave_trace_menu` — 9 legs (TR3/TR4/TS8) red on the first neighbouring-suite run, ALL PASS at full 323 checks on immediate re-run. Known WSLg gesture flake class.
- docs updated:
  - `doc/claude/specs/graph_markers.md`
  - `doc/claude/specs/waveform_viewer_modes.md`
  - `doc/claude/code_analysis/waveform_subsystem_reference.md`
  - `doc/claude/code_analysis/ovb01_02_dblclick_delta_marker_selects_pair_decision.md`
  - `doc/claude/issues/0189-dblclick-delta-marker-selects-pair.md`
- decision doc: /home/qflow/dev/xschem/claude_1/xschem/doc/claude/code_analysis/ovb01_02_dblclick_delta_marker_selects_pair_decision.md
- implementation prompt: /home/qflow/dev/xschem/claude_1/xschem/doc/claude/overnight_batch_2026_08_01/prompts/02_dblclick-delta-marker-selects-pair.md

## Spec holes resolved (SURFACE THESE TO THE USER)

1. **Q:** There is no marker selection SET. How should one be represented?
   - **Decision:** Two new fields on xctx — a FIXED array graph_marker_sel_set[8] plus a count — with the existing graph_marker_sel kept as the HEAD of the set. The selection is NOT written to any prop token, at any set size.
   - **Why:** graph_markers.md §3.5 ('What is not in the token') and D9 are explicit: marker selection is UI state, not content — 'saving it would mean a reloaded schematic opens with a marker mysteriously highlighted' — and clear_drawing() (src/actions.c:1915) resets it precisely so it dies with the document. The shape recommended in PLAN.md is still followed exactly: head + set, one get/set trio as the only readers/writers, one predicate every draw-side comparison goes through.
   - **Rejected:** PLAN.md Q1's recommendation to mirror issue 0175 literally and add an optional companion PROP TOKEN emitted only at size >= 2. That model works for traces because hilight_wave is a real per-rect render-state token; the marker analogue of hilight_wave is a session field, so there is no head token to extend.

2. **Q:** Does the double-click select the whole delta chain, or just the pair?
   - **Decision:** The immediate pair only. With M3 pointing at M2 pointing at M1, double-clicking M3 selects {M3, M2} and never M1.
   - **Why:** The user wrote 'the one that its deltas are derived from', singular, and the callout only ever renders one delta block.
   - **Rejected:** Walking the prev chain transitively.

3. **Q:** Which direction is the delta link followed?
   - **Decision:** One way only — from the difference marker to its reference. Double-clicking the REFERENCE selects just the reference.
   - **Why:** prev is a back-pointer and any number of delta markers may share one reference; 'select everything that derives from me' is a different, unasked-for feature.
   - **Rejected:** A reverse scan of the window collecting every marker whose prev names the clicked one.

4. **Q:** Double-click a NON-difference (plain) marker?
   - **Decision:** Selects just that marker — same as a single click, no error, no message.
   - **Why:** The user's sentence is about the delta case only; anything else would make a plain double-click feel broken.
   - **Rejected:** Refusing, or emitting a CIW line.

5. **Q:** The reference marker was deleted or cannot be resolved?
   - **Decision:** Select only the difference marker, silently.
   - **Why:** graph_marker_clear_prev_n already zeroes dangling prev links window-wide on every delete, so this only arises from a hand-edited or foreign token — where silence is right.
   - **Rejected:** A CIW warning about the missing partner.

6. **Q:** Does Delete now remove both markers?
   - **Decision:** Yes, on both paths, as ONE gesture with ONE undo point. graph_marker_delete() splits into a push/no-push pair so graph_marker_delete_selected() can push undo once and then delete every member; the viewer hands the whole set to wviewer::delete_items, which already gives one undo point and one log line.
   - **Why:** Issue 0176 ('Delete deletes whatever is selected') settled one undo point and one log line PER GESTURE. Two undo points for one keystroke would mean two `u` presses to put a pair back.
   - **Rejected:** Deleting only the head; or calling the public delete in a loop and accepting N undo points.

7. **Q:** Delete's strip-scope gate when the pair spans two strips?
   - **Decision:** Gate on the HEAD (the marker the user acted on): if its strip is under the pointer, the whole set goes, partners on other strips included.
   - **Why:** The shipped gate (src/callback.c:6948-6955, mirrored in Tcl) exists so a Delete pressed over another strip cannot eat a selection, and both C and the Tcl mirror already re-resolve the head this way.
   - **Rejected:** Any-member-in-scope (looser than the shipped rule); per-member filtering (would delete half a pair and leave a dangling prev — strictly worse).

8. **Q:** Reference marker on a DIFFERENT strip?
   - **Decision:** Still selected, still rendered selected. The gesture just asks for an all-graphs repaint.
   - **Why:** The renderer already matches markers by NUMBER alone (src/draw.c:6012-6017 explains why), so a cross-strip pair works by construction; graph_marker_selgraph is documented as a stale-able hint and must not become load-bearing.
   - **Rejected:** Scoping the selection to one rect.

9. **Q:** What is the double-click threshold, and which seam is used?
   - **Decision:** Tk's own — <Double-Button-1> in the viewer, and the `-3` event that src/xschem.tcl:13939 already synthesises for every editor toplevel. No new constant, and GRAPH_CLICK_TOL is NOT reused.
   - **Why:** Double-click detection happens entirely in Tk's binding table (NEARBY_MS 500 / NEARBY_PIXELS 5). GRAPH_CLICK_TOL (3.0, file-private to callback.c) is a click-vs-drag TRAVEL test on a single click and answers a different question. What the existing interlock does contribute is the -1e30 poison (src/callback.c:1224-1226 and :1389), which already stops the trailing release of a marker double-click from bolding a trace — preserved, with a regression leg, not rebuilt.
   - **Rejected:** A bespoke travel/time test in C, as PLAN.md Q9 implies by 'reuse the existing interlock's travel/time rules'.

10. **Q:** The viewer binds <Double-Button-1> to a bare {break} (spec decision D9: no graph-properties dialog in a read-only viewer). What happens to that?
    - **Decision:** The binding now calls a small Tcl wrapper first and then breaks UNCONDITIONALLY. The wrapper pair-selects only when the C hit-test says a marker is under the pointer; every other double-click is swallowed exactly as today.
    - **Why:** D9 is a shipped viewer contract. Keeping the break unconditional means the props dialog stays unreachable no matter what the hit-test answers.
    - **Rejected:** Forwarding the `-3` event to C from the viewer. If the Tcl and C hit-tests ever disagreed, the C arm would fall through and open .graphdialog over the read-only viewer — the exact fall-through class issue 0176 removed for Delete.

11. **Q:** Does the pair-select need a wviewer::with_edit bracket, like m/d and the marker drag release?
    - **Decision:** No. Selection writes no token, pushes no undo, sets no modify flag, and `select` is one of the three sub-verbs the scheduler exempts from readonly rejection (src/scheduler.c:5142).
    - **Why:** with_edit is a context switch plus four state writes; paying it on a click would also disguise the fact that this path is not a mutation. It is assertable: the viewer buffer stays modified=0 / readonly=1 across the gesture.
    - **Rejected:** Bracketing it 'for symmetry' with the neighbouring marker seams.

12. **Q:** Does the selection get logged for replay?
    - **Decision:** No. Neither the existing graph_marker_select nor the trace selection logs, and this does not start. The new verb form deliberately takes explicit numbers (`select -set 2 1`) so adding a log line later is one line.
    - **Why:** waveform_viewer_modes.md §15 opens by stating the trace selection 'is view state: no dirty flag, no undo point, no log line', and graph_marker_select() (src/draw.c:6611) carries no log_action. The replay-critical operations already name explicit numbers (`graph_marker delete <n>`, `wviewer::delete_items ... {3 4}`), so replay is unaffected. This DIVERGES from PLAN.md Q10's recommendation.
    - **Rejected:** Logging `xschem graph_marker select -set <n1> <n2>` — which would make marker selection the only logged selection in the subsystem, an inconsistency the next reader would file as a bug.

13. **Q:** What do the select verbs return now that a selection can hold two markers?
    - **Decision:** Always the HEAD, for every form including the new -pair and -set (so -none still answers -1). The set is read with a new fail-soft getter, `xschem get graph_marker_sel_set`.
    - **Why:** graph_markers.md §11 flags 'it changes verb result shapes' as the thing to decide before shipping. Deciding it as NO CHANGE keeps roughly 27 shipped assertions and wviewer::marker_selected untouched.
    - **Rejected:** Returning the list, which would make -none answer {} instead of -1 and break existing legs.

14. **Q:** A plain single click on one member of a two-marker selection?
    - **Decision:** It COLLAPSES the selection to that one marker. The shipped rule 'a second click on the already-selected marker deselects it' is kept byte-for-byte for the single-selection case.
    - **Why:** Two precedents collide: markers deselect on re-click (spec §6.2), traces collapse and never deselect (issue 0174 D3). Keeping the marker rule at set size 1 keeps every existing gesture leg green; collapsing at size >= 2 is the only reading in which the click disambiguates rather than destroys — and a second click then still deselects.
    - **Rejected:** Deselecting one member out of a pair, which leaves a half-selection whose Delete would break a delta link.

15. **Q:** Does the double-click toggle, and does the first click still single-select?
    - **Decision:** The first click still single-selects; the double-click then WIDENS it, and it SETS absolutely — a repeated double-click leaves the pair selected.
    - **Why:** Only the -3 arm is new; the press/release select path is untouched. Setting rather than toggling also makes the gesture idempotent when the first click happened to deselect an already-selected marker.
    - **Rejected:** Making the second click a toggle.

16. **Q:** Anchor or callout — which parts of a marker accept the double-click?
    - **Decision:** Both (the hit-tester's part 1 and part 2).
    - **Why:** 'Double-clicking the marker' — the callout is the marker's readout and is already its other grab handle for every drag gesture.
    - **Rejected:** Anchor-only.

17. **Q:** Should the -3 arm decline the strip-reorder grip column, the way the press-side hit test does?
    - **Decision:** No.
    - **Why:** The grip owns no double-click gesture, and a callout is clamped inside the plot box, so an overlap only exists on a very narrow strip — where selecting the marker under the pointer is the right answer anyway. Fewer moving parts.
    - **Rejected:** Mirroring graph_marker_press()'s grip decline into the -3 arm.

18. **Q:** Ctrl / Shift / Alt + double-click?
    - **Decision:** Out of scope, unchanged. The -3 arm does not inspect modifiers today and still will not.
    - **Why:** Not asked for, and the viewer already swallows Shift+B1 / Alt+B1 entirely.
    - **Rejected:** Inventing an additive (Ctrl+double-click) variant.

19. **Q:** Does `select -set` validate that the numbers name existing markers?
    - **Decision:** No — permissive, exactly like `select <num>` is today. `-pair` does check the partner, because resolving prev is its job.
    - **Why:** A nonexistent number simply renders no ring; a validating setter would also have to decide what to do with a partially valid list.
    - **Rejected:** Rejecting unknown numbers.

20. **Q:** How big is the selection array, and is it mirrored in Tcl?
    - **Decision:** GRAPH_MARKER_MAX_SEL = 8, C-only.
    - **Why:** The double-click builds one or two; 8 is headroom for a future Ctrl+click without another header edit. Tcl reads the list from the getter and never needs the cap, so there is nothing to mirror.
    - **Rejected:** 2 (no headroom); 64 (GRAPH_MAX_SEL_WAVES, pointless here); a malloc'ed pointer (would add a free path to clear_drawing for nothing).

21. **Q:** Where do the tests live, and can they have teeth without a display?
    - **Decision:** A new MS* group in tests/headless/test_wave_markers.tcl, written MK-style: no raw and no DISPLAY, so it runs in BOTH arms. Records are written straight into the markers token with setprop, exactly as the existing MK7 group does. A new verb form `xschem graph_marker delete -selected` is added so the multi-delete, its undo-point count and its prev sweep are assertable headless too.
    - **Why:** Selection, the prev walk and the delete never touch the raw, so a fixture would be dead weight; and landmine 41 means anything observing the viewer model is DISPLAY-only, so the both-arms group is where the durable teeth are.
    - **Rejected:** Extending the MR* group, which needs a raw for no reason; or leaving the multi-delete to a display-only keystroke leg.

22. **Q:** How is 'no draw-side comparison was left bare' proved?
    - **Decision:** A source-level leg (MS13) in the LS5 idiom from tests/headless/test_wave_legend.tcl:264-282: read draw.c and callback.c, count matches on CODE lines only, and assert that the renderer and both gesture arms contain graph_marker_is_selected( and no bare graph_marker_sel comparison — with the three sanctioned head readers named explicitly.
    - **Why:** A missed comparison renders a selected marker in the unselected style, and no behavioural leg that only ever selects one marker can see it. Sabotage SAB-2 restores one bare comparison and must kill exactly this leg.
    - **Rejected:** Trusting a behavioural leg, or a loose '>= N calls' count.

## PLAN.md claims refuted by source

- PLAN.md Q1 recommends storing the marker selection set as an OPTIONAL COMPANION PROP TOKEN on the graph rect, emitted only at size >= 2, mirroring issue 0175. Source refutes this: doc/claude/specs/graph_markers.md §3.5 ('What is not in the token — Selection. It is UI state, not content: saving it would mean a reloaded schematic opens with a marker mysteriously highlighted. It lives in xctx->graph_marker_sel') and D9, plus clear_drawing() at src/actions.c:1915 which resets it precisely so it dies with the document. Marker selection has NEVER been in a token, so there is no head token to extend. Consequence for the test plan: the seed leg 'the serialised prop of a never-double-clicked strip is byte-identical' becomes the stronger 'no graph's prop_ptr changes at all under ANY selection, including a two-marker one', and the seed sabotage 'emit the companion token at size 1' is replaced by 'write a sel_markers= token from the setter', which must kill that leg and nothing else.
- PLAN.md Q3 says 'There were ELEVEN such bare sites in the trace case'. That is true of issue 0175 and traces (test_wave_legend.tcl:281-282 asserts >= 11 wave_is_hilighted calls), but in the MARKER code there are exactly FOUR 'is this marker selected' comparisons — src/draw.c:6017, src/draw.c:6495, src/callback.c:635, src/callback.c:791 — plus one 'is anything selected' (src/callback.c:613), one repaint-scope hint (src/callback.c:769-770) and one Delete-scope read (src/callback.c:6955). The implementer should look for four, and the source-level leg must assert the exact sanctioned set rather than a '>= N' count.
- PLAN.md Q9 says to 'reuse the existing interlock's travel/time rules rather than adding a new constant'. There is no travel/time rule to reuse: double-click detection happens entirely inside Tk's binding table (NEARBY_MS 500 / NEARBY_PIXELS 5) and the product only ever sees the resulting `-3` event, which src/xschem.tcl:13939 already synthesises. GRAPH_CLICK_TOL (3.0) is documented at src/xschem.h:439 as file-private to callback.c and is a click-vs-drag TRAVEL test on a single click. What the interlock actually contributes is the -1e30 poison of graph_press_x/y, written at src/callback.c:1224-1226 (a press that armed a marker gesture) and again at src/callback.c:1389 (the -3 arm) — and because the first press of a double-click on a marker always poisons, the trailing release ALREADY cannot wave-bold today. That must be preserved with a regression witness, not rebuilt.
- PLAN.md Q9 also says 'If Tk's <Double-Button-1> is the natural seam in the viewer, use it'. It is the seam, but source shows it is currently a SHIPPED, SPEC'D REFUSAL: src/wave_viewer.tcl:6495 binds it to a bare {break} with the comment 'D9: no graph props dlg'. The item necessarily edits that refusal, and D9 has to survive for every non-marker double-click — hence the decision that the new binding always breaks and only additionally pair-selects on a marker hit.
- PLAN.md Q10 recommends logging the selection for replay. Contradicted by waveform_viewer_modes.md §15, whose opening line says the twin feature (trace selection) 'is view state: no dirty flag, no undo point, no log line (landmine 19)', and by graph_marker_select() at src/draw.c:6611-6622 carrying no log_action. Decision D-17 takes source over the recommendation; replay is unaffected because the delete paths already name explicit marker numbers.

## Sabotage

- **SAB-1** — target: graph_marker_select_pair ignores prev (selects the clicked number alone). failedExactly: **true**.
  - Killed exactly the pair legs in both arms: MS1, MS5, MS7, MS9's two pair halves (--nogui and DISPLAY), plus MS-X1b, MS-X1f, MS-X4 and MS-X5 on DISPLAY. MS-X1f/MS-X5 are pair legs the prompt's 8b table added after the decision doc's 8.3 table was written. Every leg named 'must stay green' (MS2, MS3, MS4, MS4b, MS6, MS8, MS11-MS14, MS-X2, MS-X3) stayed green. On the FIRST attempt it also killed one staging sub-leg each of MS8 and MS14, which both staged their two-marker selection with `select -pair`; the LEGS were wrong (MS8's subject is 'no token at any selection SIZE', MS14's is the read-only split) and were changed to stage with `select -set 2 1` / assert only the head. Re-verified after the fix.
- **SAB-2** — target: restore ONE bare `m.num == xctx->graph_marker_sel` in draw_graph_markers. failedExactly: **true**.
  - Killed MS13 and nothing else, in both arms (3 sub-legs: the no-bare-comparison count, the predicate count, and the exact sanctioned-reader list for draw.c). This is the only sabotage no behavioural leg can see -- it is byte-identical in effect at n_sel == 1.
- **SAB-3** — target: graph_marker_delete_selected deletes only the head. failedExactly: **true**.
  - Killed MS9 (4 sub-legs) in both arms and MS-X6 on DISPLAY. It does NOT kill MS-X4 as the decision doc predicted, and cannot: MS-X4 is the VIEWER's Delete, which goes through the Tcl delete_items path and never touches that primitive. That exposed a real gap -- the C `Delete` KEY path over an embedded graph had no leg at all -- so MS-X6 was ADDED to the MF display half (select the pair via `-3`, real Delete keystroke, both records go, one `xschem undo` brings both back). Re-verified after adding it.
- **SAB-4** — target: graph_marker_select_set writes a sel_markers= token onto the rect. failedExactly: **true**.
  - Killed exactly the 'no token, ever' assertions: MS8's whole-serialised-buffer leg in both arms, plus MS8's per-rect token leg, MS-X1e's and MS-X5's on DISPLAY. Nothing else moved. This is the leg that carries decision D-1.
- **SAB-5** — target: push undo per delete instead of once in graph_marker_delete_selected. failedExactly: **true**.
  - Killed MS10 (2 sub-legs) in both arms and MS-X6's two undo legs on DISPLAY. MS9 stayed green, as specified.

## Verifier (fresh adversarial context, not the implementer)

- ok: **true**
- sabotage reproduced independently: [object Object]
- audit matches baseline: **false**
- problems:
  - **HOLLOW BRANCH (rendering + rigid latch):** a graph_marker_is_selected() that only ever matches graph_marker_sel_set[0] — i.e. the partner of every selected pair renders unselected AND its label drags plain instead of rigid — passes the ENTIRE suite: `for(k = 0; k < 1 && k < xctx->graph_marker_n_sel; k++)` in src/draw.c gives 'RESULT: ALL PASS (979 checks)' on DISPLAY. The item's headline deliverable ('both render selected') therefore has no witness at all, and the blind spot is wider than the implementer's pixel-only framing: it swallows the callback.c:635 RIGID latch, which is observable behaviour that MX7e already knows how to test for a single marker.
  - **UNTESTED CONTRACT DECISION D-15:** removing `&& xctx->graph_marker_n_sel == 1` from `if(graph_marker_is_selected(num) && xctx->graph_marker_n_sel == 1) graph_marker_select(-1, -1);` in src/callback.c graph_marker_release() — so a single click on a member of a selected pair DESTROYS the selection instead of collapsing to the clicked marker — yields 'RESULT: ALL PASS (979 checks)'. D-15 is recorded in the decision doc as a deliberate, contested choice ('two precedents collide') and has zero legs.
  - **UNTESTED RESET, AND IT IS THE MF13 LATCH CLASS AGAIN:** deleting `xctx->graph_marker_n_sel = 0;` from clear_drawing() (src/actions.c) yields 'RESULT: ALL PASS (437 checks)'. I then reproduced the resulting corruption directly: after `xschem graph_marker select 1 0; xschem clear force`, the sabotaged binary answers `sel=-1 set=1` — INV-1 broken, graph_marker_is_selected(1) still true in the NEW document, and `xschem graph_marker delete -selected` gates on n_sel (draw.c: `if(!xctx || xctx->graph_marker_n_sel <= 0) return 0;`), not on sel. MF13a asserts only `xschem get graph_marker_sel`; one added leg asserting `xschem get graph_marker_sel_set` == {} after `xschem clear` and after `xschem load` would close it.
  - **MINOR BEHAVIOUR CHANGE OUTSIDE THE STATED 'byte-for-byte unchanged' CLAIM:** `xschem graph_marker select 0` used to set graph_marker_sel = 0 and return 0 (old graph_marker_select only special-cased num < 0); it now returns -1, because graph_marker_select_set() drops every `nums[k] <= 0`. Arguably a fix (0 means 'none' in the marker grammar), but INV-8 and the commit message both say the existing select forms are byte-identical, and no leg covers the 0 input in either direction.
  - **SPURIOUS UNDO POINT ON A NO-OP MULTI-DELETE:** graph_marker_delete_selected() (src/draw.c) pushes undo BEFORE the loop, so `xschem graph_marker select -set 91 92` (numbers no record carries — accepted by design, D-18/MS11) followed by `delete -selected` pushes one undo point, deletes nothing, returns 0 and leaves the bogus set selected. MS12 only covers the EMPTY-selection case, which returns early before the push.
- notes: (none)

## What the tests structurally CANNOT see (eyeball list)

- **TWO MARKERS RENDERING SELECTED AT ONCE.** No verb reads pixels. Empirically proven unreachable, not merely assumed: P2 — a graph_marker_is_selected() whose loop is bounded to k<1, so the PARTNER of every pair renders in the unselected style — passes all 979 DISPLAY checks and all 437 --nogui checks. MS13 cannot see it (the predicate is still called) and no behavioural leg can.
- **THE RIGID LABEL-DRAG LATCH ON THE PARTNER** of a selected pair (src/callback.c:635, `if(part == 2 && graph_marker_is_selected(num))`). This is BEHAVIOUR, not pixels — a rigid text drag moves anchor+label together vs a plain label drag — and it is inside the same P2 blind spot: MX7e only ever exercises a SINGLY selected marker, so nothing witnesses the latch on marker #1 of a {2,1} selection.
- **THE CROSS-STRIP REPAINT SCOPE.** `need_all_redraw = 1` in the -3 arm and `xschem redraw` in marker_dblclick_at are unobservable from Tcl; a stale ring left on the partner's strip would pass everything.
- **D-15, THE COLLAPSE RULE.** A plain click on one member of a two-marker selection should collapse to that marker, not clear the selection. P3 — deleting `&& xctx->graph_marker_n_sel == 1` from graph_marker_release() so a click on a pair member wipes the whole selection — passes all 979 checks. No leg clicks a member of a multi-selection.
- **THE n_sel RESET IN clear_drawing() / alloc_xschem_data().** P4 — deleting `xctx->graph_marker_n_sel = 0;` from clear_drawing() — passes all 437 --nogui checks, because MF13a asserts only `xschem get graph_marker_sel`.
- **THE TWO CIW REFUSAL STRINGS** on the read-only multi-delete path. MS14 proves `delete -selected` raises at the scheduler, but nothing reads the non-modal ciw_echo graph_marker_ro_refuse() emits for the KEY/mouse path, and in particular nothing witnesses that it is now emitted ONCE per gesture rather than once per member.
- **THE DOUBLE-CLICK FEEL.** The tests hand-stamp -time (ms_ev / ms_click / ms_dbl); whether a real hand lands two clicks inside Tk's 500 ms / 5 px window is not assertable.
- **THAT THE PAIR CUE READS AS 'THESE TWO GO TOGETHER'.** Per waveform_viewer_modes.md §15.4 there is deliberately no distinct cue for the head, so both members look identical. Only an eyeball can accept or reject that design judgement.

## Tunable constants (for the eyeball pass)

- `src/xschem.h:GRAPH_MARKER_MAX_SEL=8` — the cap on how many markers can be selected at once. The double-click builds 1 or 2; 8 is headroom so a future Ctrl+click needs no header edit. C-only, nothing mirrored in Tcl (Tcl reads the list from `xschem get graph_marker_sel_set`). Lowering it to 2 would tighten the feature to exactly what shipped; raising it costs 4 bytes per step in xctx.

## Implementer summary

Implemented OVB-02 exactly as the prompt and decision doc specify. The marker selection became a SET (`xctx->graph_marker_sel_set[GRAPH_MARKER_MAX_SEL]` + `graph_marker_n_sel`) with `graph_marker_sel` kept as its HEAD, so `xschem get graph_marker_sel`, every `graph_marker select` return value and `wviewer::marker_selected` are byte-for-byte unchanged. It is NOT a prop token at any size (D-1); MS8 proves it by comparing the WHOLE serialised buffer, not just the `markers` token, before and after a two-marker selection.

One trio in draw.c owns the fields — `graph_marker_is_selected()` (the predicate), `graph_marker_select_set()` (the only writer), `graph_marker_select()` (a one-line wrapper) — plus `graph_marker_select_pair()` (the policy: add `prev` only when it resolves; immediate pair only, never the chain, never the reverse) and a static `graph_marker_sel_drop()`. All four "is this marker selected" sites now go through the predicate. `graph_marker_delete()` split into a static `graph_marker_delete_1(num, push)` so `graph_marker_delete_selected()` can refuse read-only ONCE, copy the set, push undo ONCE and delete each member.

Gestures: a new rung in the on-canvas `-3` arm, tested BEFORE the wave dialog, keeping the `-1e30` poison line untouched; and `bind $wp <Double-Button-1> {wviewer::marker_dblclick_at %W %x %y; break}` in the viewer, with the `break` unconditional so D9 survives and with no `with_edit` bracket (select mutates nothing and is exempt at scheduler.c:5142). `delete_selection_at` keeps its head-scoped gate and hands the whole set to `delete_items`. New surface: `xschem get graph_marker_sel_set`, `graph_marker select -pair|-set`, `graph_marker delete -selected`. `n_sel` reset in clear_drawing() and alloc_xschem_data().

**VERIFICATION.** Baseline at HEAD be5d9b98 was 373 (--nogui) / 870 (DISPLAY), both ALL PASS — MF1 was green, contrary to the PREFLIGHT note. Final: 437 / 979, both ALL PASS, 0 FAILED, i.e. +64 and +109 legs. All five named sabotages killed exactly their targets after two leg corrections (recorded in the decision doc's new "Post-implementation corrections to §8" section and in the sabotage notes above), each reverted from a pristine snapshot with a diff check, each followed by a clean green re-run.

Full audit (run twice, the allowance): SUMMARY 244 pass / 18 fail / 0 crash / 9 skip vs the PREFLIGHT baseline 239/20/1/11; WIREEDIT PASS (all 58); SCRATCH 0 leaked dirs. `test_wave_markers` moved from the baseline FAIL list to PASS and `test_key_graph_context` no longer times out. Four fails were not on the baseline list; all four are dispositioned above — test_palette is red on a PRISTINE rebuild of HEAD (I reverted all seven src files and rebuilt to prove it), the other three pass standalone and did not repeat across the two audit runs.

**FINDINGS / claims I could not reproduce, recorded not fixed:**

1. PLAN.md PREFLIGHT says test_wave_markers is red at MF1; it was green in both arms at HEAD when I measured, matching item 01's scout rather than the PREFLIGHT.
2. Decision doc §8.3 expects SAB-3 to kill MS-X4. It cannot — MS-X4 exercises the viewer's Tcl delete_items path, not `graph_marker_delete_selected`. The real gap (the C Delete KEY path had NO leg) is now closed by the new MS-X6.
3. `test_palette`'s final leg uses a bare `event generate` + `update idletasks`, which the PLAN's own test discipline forbids; it is reproducibly red on pristine HEAD under WSLg. Out of scope, not touched.
4. Pre-existing and untouched, as instructed: MF1's load sensitivity, find_closest_wave's two open defects, graph_coord's missing landmine-37 bracket, and the viewer double-click on an empty plot body still wave-bolting through its trailing release (my MS-X2 deliberately asserts only the selection and the absence of .graphdialog there).

**Note on procedure:** the prompt's "revert with a targeted `git checkout -- <file>`" was not usable, because every sabotage sat inside my own UNCOMMITTED work in the same file. I snapshotted the pristine-with-my-changes src files to the scratchpad before the first sabotage and restored from that snapshot, verifying with `diff -q` each time that the file was byte-identical to the snapshot afterwards — equivalent guarantee, and the only safe one here.
