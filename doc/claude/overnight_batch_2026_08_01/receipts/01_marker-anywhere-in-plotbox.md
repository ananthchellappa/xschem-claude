# Item 01 marker-anywhere-in-plotbox

- commit: `be5d9b98`
- files changed:
  - `src/draw.c`
  - `src/xschem.h`
  - `tests/headless/test_wave_markers.tcl`
  - `doc/claude/specs/graph_markers.md`
  - `doc/claude/specs/waveform_viewer_modes.md`
  - `doc/claude/code_analysis/waveform_subsystem_reference.md`
  - `doc/claude/code_analysis/ovb01_01_marker_anywhere_in_plotbox_decision.md`
  - `doc/claude/overnight_batch_2026_08_01/prompts/01_marker-anywhere-in-plotbox.md`
  - `doc/claude/issues/0188-marker-create-gate-is-proximity-not-plot-box.md`
- tests: `tests/headless/test_wave_markers.tcl` — 870 checks (was 803)
- non-baseline audit fails claimed:
  - `test_palette` — FAIL in my full_audit run, not on the PREFLIGHT baseline list. Re-verified NOT MINE: run standalone with full_audit's own predicate it exits 0 and prints 'EVENT opens palette: yes' (= PASS). The suite contains zero references to 'graph' or 'marker'. Environmental (the run_suites classifier reports it NORESULT even when it passes, because test_palette has a bespoke banner rather than 'RESULT: ALL PASS').
  - `test_wire_vertex_grab` — FAIL in my full_audit run, not on the baseline list. Re-verified NOT MINE: 'RESULT: ALL PASS' standalone under run_suites.sh. Wire-editing suite, touches nothing this item changed.
  - `test_wave_markers` — FAIL in the audit at exactly ONE leg, MF1 ('the anchor really SLID'), which is the documented load-sensitive baseline red leg for this suite (PLAN.md, doc/claude/issues/status.md) and is itself on the baseline FAIL list. Standalone it is ALL PASS in both arms (373 / 870), measured 4 times after the final revert. This is precisely the gate the prompt set: 0-or-1 FAILED, the failing leg is exactly MF1, and the pass count rose by the number of legs added.
- docs updated:
  - `doc/claude/specs/graph_markers.md`
  - `doc/claude/specs/waveform_viewer_modes.md`
  - `doc/claude/code_analysis/waveform_subsystem_reference.md`
  - `doc/claude/code_analysis/ovb01_01_marker_anywhere_in_plotbox_decision.md`
  - `doc/claude/issues/0188-marker-create-gate-is-proximity-not-plot-box.md`
- decision doc: /home/qflow/dev/xschem/claude_1/xschem/doc/claude/code_analysis/ovb01_01_marker_anywhere_in_plotbox_decision.md
- implementation prompt: /home/qflow/dev/xschem/claude_1/xschem/doc/claude/overnight_batch_2026_08_01/prompts/01_marker-anywhere-in-plotbox.md

## Spec holes resolved (SURFACE THESE TO THE USER)

1. **Q:** What exactly is "the plot area" the user means?
   **Decision:** The strip's PLOT BOX — the rectangle between the two axes — as answered by the existing `graph_plotbox_at()` (src/draw.c:5031). Not the legend band, not the axis-number margins, not the reorder-grip column.
   **Why:** It is the SAME gate the item-9 diamond snap cursor already uses (src/draw.c:5180-5187), so "the point the diamond has snapped to" is well defined exactly where the key now works. `waveform_viewer_modes.md` §15.7 already states the legend band and both axis margins draw NOTHING on hover.
   **Rejected:** The whole graph rect (would arm `m` where no diamond is ever shown); writing a new geometry pass (the box is already a shipped, tested, Tcl-visible query).

2. **Q:** What does the marker snap to when the pointer is far from every trace?
   **Decision:** The nearest sample of the nearest trace in that strip, however far — `graph_point_at(i, px, py, 1e30, -1, -1, &hit)`, byte-for-byte the call `draw_graph_snap_cursor()` makes.
   **Why:** Same call, same inputs ⇒ the marker cannot land anywhere but under the diamond, which is literally what the user asked for. The `1e30` idiom is already used by the marker drag and the snap pump.
   **Rejected:** PLAN.md's suggestion to reuse `find_closest_wave()` — REFUTED by source: it reads the stale C mouse mirror instead of the caller's pixels, measures only |Δy| at the nearest sample, does not return the (dataset, point, raw x, raw y) identity the marker record needs, and carries two still-open defects (landmine 40).

3. **Q:** Where does the relaxation live — the key arms or the primitive?
   **Decision:** Inside `graph_marker_create()` (src/draw.c:6357), the single primitive behind both key arms and the `xschem graph_marker add` verb.
   **Why:** One gate, three doors — and it is what makes the item assertable in the `--nogui` arm: the scout MEASURED that `xschem graph_marker add <gi> <px> <py>`, `xschem get graph_plotbox_at`, `xschem get graph_trace_at` and `xschem graph_coord` all work headless, so the bulk of the suite is BOTH-arms rather than DISPLAY-only.
   **Rejected:** Gating in the callback.c `m`/`d` arms (splits the key from the verb and makes the change invisible to the engine-arm suite).

4. **Q:** Does the same relaxation apply to `d` (the delta marker)?
   **Decision:** Yes.
   **Why:** `d` is `m` plus a `delta` flag on the shared tail (`graph_marker_add_record`); there is literally no second code path to relax. The user's argument ("pressing the key is clear intention") is identical.
   **Rejected:** Relaxing `m` only.

5. **Q:** Pointer outside the plot box — legend, axis margin, grip column?
   **Decision:** Refuse, with a new message. This deliberately REMOVES a measured 20-px halo that exists outside the box today.
   **Why:** Measured on the shipping build: `xschem graph_marker add 0 145 480` (6 px outside the box, near a trace end) CREATES a marker today and must refuse after. Outside the box no diamond is drawn (§15.7), so there is no "point it snapped to" to mark.
   **Rejected:** A union gate (inside the box OR within 20 px of a trace). It keeps the halo alive, contradicts §15.7, and — decisively — makes the margin-refuse test leg UNKILLABLE by any sabotage, because both halves of the union refuse a far margin pixel anyway.

6. **Q:** Digital strips and bus traces?
   **Decision:** Still refused, unchanged — and the SPECIFIC digital message keeps its place FIRST, before the new plot-box gate.
   **Why:** `graph_plotbox_at` also refuses digital strips, so ordering is the only thing preserving "markers are not supported on digital strips" rather than the generic plot-area message. Bus entries are skipped inside `graph_point_at`, so a bus-only strip falls into the "no trace to mark" arm.
   **Rejected:** Unlocking digital/bus strips (explicitly deferred in graph_markers.md §11).

7. **Q:** Several traces equidistant from the pointer?
   **Decision:** Unchanged: nearest trace by point-to-SEGMENT distance, strictly-nearer wins, ties go to the FIRST node; then the nearest SAMPLE on the winner by 2-D screen distance, x/y returned RAW.
   **Why:** Verified at src/draw.c:5390-5426. It is what the diamond already resolves to, so key and glyph agree by construction.
   **Rejected:** Any new tie rule.

8. **Q:** No raw loaded, or a strip with no traces?
   **Decision:** Refuse — and by machinery that already exists, with no new test in the code.
   **Why:** `graph_plotbox_at` and `graph_point_at` share the identical `!xctx->raw || sch_waves_loaded() == -1` guard prefix; a strip with no `node` token produces no candidate and falls into the "no trace to mark" arm. Both measured.
   **Rejected:** Adding an explicit guard (would duplicate an existing one).

9. **Q:** Does the marker still bind to a TRACE, so anchor-drag still slides along it?
   **Decision:** Yes — trace + dataset + absolute point + cached raw x/y, completely unchanged. Only the GATE moves.
   **Why:** `graph_marker_add_record` is untouched, so `push_undo`, `set_modify(1)`, the `graph_marker_notify` push to the ASE model and the data-addressed `add_at` action-log line are all unchanged; replay is unaffected because the log never carried pixels.
   **Rejected:** Anchoring to a free x/y point (that would be a data-model change — a genuine DEFER trigger — and it is not needed).

10. **Q:** What becomes of `GRAPH_MARKER_PICK_TOL` (20.0)?
    **Decision:** Deleted from src/xschem.h, with its two spec references and two test comments mended.
    **Why:** src/draw.c:6375 is its ONLY use in the whole tree and it is not mirrored in Tcl. Its comment ("is there a trace near the pointer on m / d") would document a gate that no longer exists — exactly the trap the next reader falls into. `test_wave_snap.tcl` SQ3 sets the precedent ("no proximity-threshold var survives").
    **Rejected:** Leaving it as a dead #define to keep the diff smaller.

11. **Q:** What if the nearest trace is off the strip's Y window (invisible)?
    **Decision:** Still eligible, exactly as the diamond is today.
    **Why:** `graph_point_at` filters on the X window only (src/draw.c:5376); consistency with the feedback glyph is the rule this item exists to establish. A visible trace is always nearer in screen space, so this only fires when EVERY trace is off-window, and the callout stays readable because `graph_marker_label_box` clamps it to the plot box.
    **Rejected:** Adding a y-window filter (would make key and diamond disagree again, in the other direction).

12. **Q:** Does the marker DRAG (anchor re-snap) change too?
    **Decision:** No — out of scope, untouched.
    **Why:** `graph_marker_move`/`graph_marker_anchor_at` already pass 1e30 restricted to the marker's own trace and deliberately tolerate the margins (landmine 36's documented 8-px above-the-box grab).
    **Rejected:** Applying the plot-box gate to the drag (would break that documented grab).

13. **Q:** Where does the suite live, and in which arm?
    **Decision:** `tests/headless/test_wave_markers.tcl`, a new `MP*` group placed in the BOTH-ARMS engine half, plus three display legs in the existing MF display block and an inverted MX4 in the viewer group.
    **Why:** The scout measured that the whole pixel path (create verb, plot-box query, trace query, graph_coord) works under `--nogui`, so far more of this item is engine-arm testable than PLAN.md assumed. The suite already owns the hermetic `raw new` fixture, the scanners and the footer.
    **Rejected:** A new suite; a DISPLAY-only group (would halve the coverage for nothing).

14. **Q:** The existing MX4 legs assert the OLD refusal ("m in empty waveform space creates nothing") — what happens to them?
    **Decision:** Invert them — but FIRST tighten `mx_empty_row` (test_wave_markers.tcl:3757) to require `wviewer::plotbox_at`, the requirement `mf_empty_px` already carries.
    **Why:** Without that requirement, MX4's expected value after this change depends on whether the scanned row happens to land in the legend margin or inside the plot box. A test whose expected value depends on an unasserted scan is worse than no test — and that is the exact defect mf_empty_px carries a 9-line comment about.
    **Rejected:** Leaving MX4 alone (it would fail correctly but for a reason the leg name cannot convey).

15. **Q:** How is the margin-refusal driven in the DISPLAY / viewer arms?
    **Decision:** Through the VERB (`mk_wadd`), never a synthetic `m` keypress.
    **Why:** A key not claimed by the graph falls through to the schematic handler where `m` is `readonly_block()` — a MODAL that hangs the run to the harness timeout and is scored CRASH. The suite's own MX0 banner documents this, probe-verified. `waves_selected` insets each rect by 5*tk_scaling*zoom screen px, so "inside the rect" does not imply "claimed".
    **Rejected:** Pressing `m` at a margin pixel.

16. **Q:** Is a numbered issue file warranted?
    **Decision:** Yes — `doc/claude/issues/0188-marker-create-gate-is-proximity-not-plot-box.md` (0188 is the next free number; highest present is 0187).
    **Why:** Same class as issues 0177 and 0174: a shipped feature whose gate was trace-proximity where it should have been the plot box, reported by the user in those words. `doc/claude/issues/status.md` is deliberately NOT updated — its own header says it is a point-in-time snapshot to be re-derived.
    **Rejected:** No issue file (treating this as greenfield feature work).

## PLAN.md claims refuted by source

- "find_closest_wave() is still live for precisely this 'nearest, however far' purpose — reuse it, do not clone it." REFUTED on five counts: it reads the stale C mouse mirror (xctx->mousex/mousey) rather than the caller's pixels (landmine 33); it measures only |Δy| at the nearest sample, not a real distance; it returns the dataset and writes *node_number but NOT the (dataset, point, raw x, raw y) identity graph_marker_add_record requires — that is what GraphPointHit exists for; landmine 40 records two still-open defects in it (per-node extra_rawfile switch with a single restore, gated on intent not success) which marker creation would inherit; and the correct primitive is already in the function being edited, graph_point_at(..., 1e30, ...), which is what the diamond uses. PLAN's Q2 recommendation itself (drop the tolerance to 1e30) is correct — only the trailing find_closest_wave sentence is wrong.
- "a press at a plot-box pixel measured to be >10 px from every trace now places a marker (this is the leg that dies if the gate is not relaxed)." REFUTED — >10 px is NOT enough and a leg built on it would be green and hollow. The gate today is GRAPH_MARKER_PICK_TOL = 20.0 (src/xschem.h:443), not GRAPH_TRACE_PICK_TOL = 10.0; a pixel 12 px from a trace already creates a marker on the shipping build. The far pixel must be >20 px away; the suite's own scanners use 25 for exactly this reason (test_wave_markers.tcl:1745 and :3766).
- "test_wave_markers is ALREADY RED, at 1 FAILED (802 passed) ... you inherit that one red leg." REFUTED as stated: measured today on unmodified HEAD e516cc85 with GUI_GATE=0 run_suites.sh, the suite is GREEN — `RESULT: ALL PASS (328 checks)` in the --nogui arm and `RESULT: ALL PASS (803 checks)` in the DISPLAY arm across FOUR consecutive runs. 803 = 802 + the MF1 leg PLAN saw fail; MF1 is load-/timing-sensitive, as doc/claude/issues/status.md already records. The implementer's gate must be "0 or 1 FAILED, any failing leg is exactly MF1, and the pass count rose by exactly the number of legs I added".
- "Likely files: src/draw.c, src/callback.c, src/xschem.h, src/wave_viewer.tcl (key_filter), possibly src/scheduler.c." NARROWED: the code change is src/draw.c + src/xschem.h ONLY. The callback.c m/d arms pass the pointer through and test nothing (read-only is gated in the primitive, not the arm); wave_viewer.tcl's key_filter gates on wviewer::over_graph, which is the graph RECT bbox — strictly looser than the plot box, so C decides in the viewer too; and scheduler.c already exposes `xschem get graph_plotbox_at` (:3859) and `xschem get graph_trace_at`, so no new verb and no letter-dispatch risk.
- PLAN.md's test-plan seed implies the far-pixel legs need a display. REFUTED/expanded: the entire pixel path runs under --nogui — measured `xschem graph_marker add 0 <px> <py>`, `xschem get graph_plotbox_at`, `xschem get graph_trace_at ... 1e30` and `xschem graph_coord` all answering correctly with no X server. Most of this item's suite therefore belongs in the BOTH-ARMS engine half rather than behind a has_x guard, which roughly doubles the coverage PLAN assumed.
- PLAN.md does not mention that the suite already contains legs asserting the OLD behaviour. FINDING: test_wave_markers.tcl group MX4 (:3918-3934) asserts "m in empty waveform space creates nothing" and "the pixel-addressed verb refuses there too", and its scanner mx_empty_row (:3757) does NOT require graph_plotbox_at — so after the change MX4's correct expected value depends on whether the scanned row lands in the legend margin or the plot box. The scanner must be tightened and MX4 inverted, or the item ships a nondeterministic test.
- PLAN.md does not warn about the Graph_ctx inside graph_marker_create. FINDING: it calls setup_graph_data(i, 1, gr) — skip=1 on a memset-zeroed local — which suppresses the x1/x2 read (draw.c:3866-3874), leaving gx1==gx2==gw==0 and gr->cx = gr->w/gr->gw (draw.c:4045) at INFINITY. gr->digital is the only field of that gr that may be read, and the `gr->scx == 0.0` no-transform test is useless there because inf != 0. An implementer who "optimises" by computing the plot box inline from that gr gets nonsense; the box must come from graph_plotbox_at(), which builds its own Graph_ctx with skip=0.

## Sabotage

```json
[
 {
  "name": "SAB-1 put the tolerance back: 1e30 -> 20.0 in graph_marker_create",
  "target": "MP2(2) MP3 MP4(2) MP5 MP6 MP8(2) MP9-positive MP15(2) MP20(3) MP21(2) MP22(5) MX4(4)",
  "failedExactly": true,
  "note": "Measured in BOTH arms: --nogui 13 FAILED (360 passed), DISPLAY 26 FAILED (844 passed). Kill set is exactly the target PLUS one extra leg: MP14's `graph_point_at(i, px, py, 1e30, -1, -1, &hit)` SOURCE TRIPWIRE, which asserts the very line the sabotage edits and therefore cannot survive its own sabotage (a tripwire that did would be the defective leg). MP7, MP9-negative, MP10-MP13, MX4b and the rest of MP14 stayed green. Two legs were CORRECTED to make the list exact: MP13's 'and creation succeeded there' witness moved to MP2 (MP13 is the regression witness that selection proximity is UNCHANGED, so it must survive every sabotage of the creation gate — the prompt's own table contradicted itself here), and MP8/MP21 gained explicit `string is integer` / `llength` terms because two empty strings compare equal and both legs were passing vacuously."
 },
 {
  "name": "SAB-2 delete the `if(!graph_plotbox_at(i, px, py))` block",
  "target": "MP7-refusal, both MP9-negatives, MX4b(2)",
  "failedExactly": true,
  "note": "Measured: --nogui 4 FAILED (369 passed), DISPLAY 6 FAILED (864 passed). Exactly the target plus MP14's `if(!graph_plotbox_at(i, px, py)) {` tripwire (same reason as SAB-1). MP2-MP6, MP8, MP10-MP13, MP15, MP20-MP22 and MX4 all stayed green. First run of this sabotage also killed MP8's delta leg for MP7's reason (the halo creation shifted the window-wide numbering); MP8 was restructured to build its own base marker so each leg dies only for its own reason, and the sabotage was re-run."
 },
 {
  "name": "SAB-3 pass restrict_wave = 0 instead of -1 to graph_point_at",
  "target": "MP3 only",
  "failedExactly": true,
  "note": "Measured: --nogui 2 FAILED (371 passed), DISPLAY 2 FAILED (868 passed) — MP3 plus MP14's tripwire (which pins the literal `-1, -1` argument pair). Everything else green, including MP20/MP22, because the MF/viewer strips carry a single trace so node 0 is the nearest trace there anyway; the MP fixture's far pixel is deliberately scanned from the BOTTOM of a two-trace box so its nearest trace is node 1, which is the only thing that gives this sabotage a target at all (asserted as a staging leg in MP0)."
 }
]
```

## Verifier (fresh adversarial context, not the implementer)

- ok: true
- sabotage reproduced independently: true
- audit matches baseline: true
- audit detail: GUI_GATE=0 bash tests/headless/full_audit.sh -> SUMMARY: 244 pass  16 fail  1 crash/timeout  10 skip  (total 271); WIREEDIT: PASS (all 58); SCRATCH: 0 leaked dir(s). Baseline was 239/20/1/11. My run is GREENER than baseline overall — and notably test_wave_markers, which the PLAN baseline lists as FAIL, PASSED inside my audit. Five fails in my run are not on the baseline list: test_multi_window, test_palette, test_remap, test_wave_split_strip, test_wire_vertex_grab. I re-ran all five standalone from repo root with GUI_GATE=0: test_wave_split_strip 'RESULT: ALL PASS (221 checks)', test_multi_window 'ALL PASS (15 checks)', test_remap 'ALL PASS', test_wire_vertex_grab 'ALL PASS', test_palette exits 0 printing 'EVENT opens palette: yes' (bespoke banner, no RESULT line, which is why the audit classifier scores it FAIL/NORESULT). test_wave_split_strip is the only one on this item's turf; it contains zero 'graph_marker' references and its audit-run failure was the SG10 box-zoom leg, unrelated to marker creation, and it does not reproduce. Nine baseline fails did not recur (altf5_ciw, ase_unnamed_net, deselect_mode, nh_anim_rearm, pristine_untitled_viewer_0172, readonly_action_dispatch, rotate_stretch_short_0104, verb_noun_copy_move, wave_markers) — the baseline list is itself load-sensitive in both directions. No fail is attributable to this item.
- commit scope: 9 files, all inside src/ (2) + tests/headless/ (1) + doc/claude/ (6). No stray file, no unrelated hunk. src/draw.c is a single hunk inside graph_marker_create(); src/xschem.h is one deleted #define plus its mended comment block. Working tree after my runs carries ONLY the two preflight dirty tracked files (doc/claude/suggestions/next_session_prompt_0165.md, sky130A/.../tb_bandgap.state).
- hollowness probe: Hunted all five named failure modes and found none. (1) Index-space coincidence: MP3 compares the marker's `wave` field to `xschem get graph_trace_at ... 1e30` — both NODE space — and the fixture deliberately puts the far pixel's nearest trace at node 1, which I confirmed by running SAB-3 myself (kills MP3 alone). (2) Press that never reaches the graph: MP20/MP21/MP22 drive `xschem callback .drw 2 x y 109/100` after an explicit `mf_move`, and all ten of those legs die under SAB-1 — the keys really deliver and really reach graph_marker_create. MX4's `send_key_fb` can fall back to wviewer::key_filter, but that is the shipping handler and the following count leg is the real assertion. (3) Per-object state on one object: the MP fixture carries three strips (2-trace analog / digital / traceless) and the MF/MX fixtures a fourth and fifth; digital, traceless and no-raw are each witnessed separately. (4) Threshold a restored bug squeaks past: MP1 pins the far pixel at >25 px (past the retired 20), and MP9's 0.95 fraction measured 0.44/0.53 under the restored gate. (5) Negative leg passing because the key was never delivered: MP7/MX4b/MP9-negatives are driven through the pixel VERB, not a key, and all of them die under SAB-2 — so the refusals are real refusals, not silent no-ops. MP8 and MP21 carry explicit `string is integer` / `llength` non-vacuity terms, which I confirmed are load-bearing (under SAB-1 MP8's delta leg reports `{{} 0}` vs `{{} 1}` — it fails on the integer term, not vacuously).
- verifier recommendation: [E] — DONE-EYEBALL-PENDING. The implementation, the suite and the docs are sound and every sabotage kills exactly its target, but the unassertable list above is non-empty (PLAN clause 11), and two of its entries are things the user would notice: the retired 'no trace near the pointer' message is replaced by two new strings nobody has read on screen, and the halo-removal / diamond-coincidence are pixel judgements.
- problems:
  - MINOR, receipt accuracy: the claims JSON states SAB-1 measured '26 FAILED (844 passed)' in the DISPLAY arm. I measure 27 FAILED (843 passed). 843+27=870 and 27 is exactly the sum of the claim's OWN enumerated target list (MP2 2 + MP3 1 + MP4 2 + MP5 1 + MP6 1 + MP8 2 + MP9-pos 1 + MP15 2 + MP20 3 + MP21 2 + MP22 5 + MX4 4 + MP14 1 = 27), so the kill SET is right and the number is a transcription slip in the receipt, not a hollow leg.
  - MINOR, stale prose left in the tree: src/callback.c:1509 still cites the retired message as its example — 'the refusal must use the feature's own non-blocking channel (graph_marker_refuse -> ciw_echo, like "no trace near the pointer")'. That string no longer exists anywhere in src/. The implementer declared it as knowingly-not-fixed (callback.c is outside the item's declared file list), which is defensible, but it is now a comment pointing at a message the reader cannot grep for.
  - MINOR, coverage gap the suite does not close: neither new refusal string is asserted, and `d` is never refused in the margin (see unassertable). Nothing is wrong; nothing is watching either.
- notes: (none)

## What the tests structurally CANNOT see (eyeball list)

- The two NEW CIW refusal STRINGS. `graph_marker_refuse()` writes 'xschem: the pointer is not inside the plot area of a strip' and 'xschem: no trace to mark in this strip' to ciw_echo, and I grepped the whole suite: no leg captures either text — every refusal leg asserts the RETURN value ({}) only. The file's own line 118 documents this as a pre-existing gap for all six marker refusals; this item widens it by one and replaces a string the user may have learned.
- Pressing the actual `m` (or `d`) KEY outside the plot box. No leg does it, by design (decision D15: an unclaimed key falls through to the schematic handler where `m` is readonly_block(), a modal that hangs the run to the harness timeout). The margin refusal is reachable only through the pixel VERB (MP7, MX4b). Structurally the same primitive, but the key half of the newly-narrowed behaviour is not driven end to end.
- `d` in the margin. MP7 and MX4b both call `graph_marker add` WITHOUT `-delta`; no leg asserts that the delta arm is refused outside the plot box. The `delta` flag is only read after the gate so it cannot differ, but nothing asserts it.
- Whether the removed 20-px halo FEELS right. Refusing `m` 6 px outside the box while a trace visibly passes there is a judgement call, argued from waveform_viewer_modes.md §15.7 and asserted as behaviour, never eyeballed.
- Pixel coincidence of the drawn diamond glyph and the drawn marker anchor. MP22 asserts the equality as DATA (same strip, same node, same raw x/y to 1e-7). The snap glyph is painted to the window only and never to save_pixmap, so no check can read back that the two land on the same screen pixels — the user's sentence is verified at the model level, not the pixel level.
- A marker anchored to a trace that is off the strip's Y window (decision D11). graph_point_at filters on the x window only, so the anchor glyph is drawn outside the plot box while graph_marker_label_box clamps the callout inside it. Behaviourally reachable, visually unjudged.
- Whether the diamond is actually VISIBLE at the pixel where `m` now succeeds. The suite proves the two code paths make identical calls; it cannot prove the glyph was rendered (draw_graph_snap_cursor's paint is chrome, bit 16, stripped from every export and never in save_pixmap).

## Tunable constants (for the eyeball pass)

- `src/xschem.h:GRAPH_TRACE_PICK_TOL=10.0` — UNCHANGED by this item and deliberately so (trace SELECTION proximity, the half of the report the user called 'Good'). It is now the only marker-adjacent tolerance left, it is MIRRORED as the {tol 10} defaults of wviewer::trace_at / wviewer::near_wave_at in src/wave_viewer.tcl, and MP13 witnesses that it is still 10.0. If picking a trace still feels fussy after this change, this is the one number to move — all four picking surfaces together.
- `tests/headless/test_wave_markers.tcl:MP9 coverage fraction=0.95` — the vertical-sweep threshold. A FRACTION on purpose (test_wave_snap SG6): the restored-proximity sabotage scores 0.44-0.53 (8/18, 9/17), so there is wide margin, but it is the leg that would need loosening if a future fixture puts a strip edge inside the sweep.
- `tests/headless/test_wave_markers.tcl:MP6 pointer-x tolerance=0.101` — one sample step of the hermetic 11-point fixture. Safe only because the fixture rect is 800x400 world units and xschem's zoom is uniform, so the plot box is always ~2.25x wider than tall and nearest-in-x dominates the 2-D snap. A fixture with a TALLER box would need this raised.

## Implementer summary

DONE and committed as be5d9b98 (9 files, 1821 insertions). `m`/`d` now create a marker anywhere inside a strip's PLOT BOX, at the sample the item-9 diamond snap cursor has snapped to.

THE CHANGE (3 lines of logic in one primitive, exactly as scouted). `graph_marker_create()` (src/draw.c) keeps its `gr->digital` refusal FIRST (so that specific message survives — graph_plotbox_at refuses digital too and would swallow it), then gains `if(!graph_plotbox_at(i, px, py))` and hands `graph_point_at` a `1e30` tolerance with a new "no trace to mark in this strip" refusal. That is byte-for-byte the pair of calls draw_graph_snap_cursor() makes, so glyph and key cannot disagree in either direction. `#define GRAPH_MARKER_PICK_TOL 20.0` had exactly one use in the tree and is deleted, its comment block mended. src/callback.c, src/wave_viewer.tcl and src/scheduler.c needed NO edit — all three creation doors (both key arms and `xschem graph_marker add`) already went through the one primitive, so decision-doc §6.4's narrowing held. `GRAPH_TRACE_PICK_TOL` untouched.

ANCHOR RE-VERIFICATION. Every anchor in the prompt re-read from source before editing; line numbers drifted by 0-2 and nothing else. The decision doc's four refutations of PLAN.md all confirmed: the suite was GREEN at HEAD (328 --nogui / 803 DISPLAY, not "red at MF1 with 802"); the old gate really was 20.0 not 10.0 (so a ">10 px" far pixel would have been green-and-hollow); find_closest_wave is the wrong primitive; only draw.c + xschem.h needed code changes. Measurements from the decision doc §2.5 reproduced with a probe before writing a line of test: far pixel inside the box refused-then-creates, halo pixel 1 px outside the box created-then-refuses, digital and traceless unchanged.

TESTS. tests/headless/test_wave_markers.tcl grew +67 checks: MP0-MP15 in the BOTH-ARMS engine half on its own three-strip fixture (2-trace analog / digital / traceless), and MP20-MP22 in the MF display half driving the REAL key arms — MP22 being the user's sentence asserted, `xschem get graph_snap` vs the marker the `m` key then creates (same strip, same node, mk_close on x and y; DISPLAY-only by construction, landmine 41). On the viewer side mx_empty_row gained the `wviewer::plotbox_at` requirement mf_empty_px already carries and documents (before this fix both regions refused so the scan's choice did not matter; now they answer differently and MX4's verdict would have depended on an unasserted scan), MX4 was INVERTED, and a new MX4b drives the margin refusal through the VERB only — never a synthetic `m`, which falls through to readonly_block()'s modal and hangs the run to the harness timeout. Counts: 328->373 (--nogui), 803->870 (DISPLAY); MZ1's hand-maintained expectations updated in both.

ONE ROBUSTNESS FIX THE FIRST AUDIT FORCED, worth flagging. The MP fixture scan originally seeded its plot-box search over an absolute 0..1800 x 0..1400 pixel range. It passed every standalone run and then found NOTHING in the first full_audit run — zoom_full fits the drawing to whatever the canvas happens to be, and under a window the WM had not finished sizing the strips were not in that range. An empty coordinate reached `expr {$mpby1 + 1}` and unwound the whole FILE through the outer catch, costing 20 further legs. Three house idioms applied: the seed sweep is now bounded by the strip's own band through the engine transform (mp_band, mirroring mf_band); the scan retries up to 3x behind mp_reestablish (deiconify / wait-for-mapped / zoom_full), re-deriving EVERY pixel together; and an unscannable pixel becomes the sentinel -1 rather than {}, so legs fail loudly instead of throwing. The group also gained the GROUP CATCH the MF and MX halves already carry. Recorded in the decision doc §8.2.

AUDIT. `GUI_GATE=0 bash tests/headless/full_audit.sh`: SUMMARY 243 pass / 19 fail / 0 crash-timeout / 9 skip (baseline 239/20/1/11), WIREEDIT: PASS (all 58), SCRATCH: 0 leaked dir(s). The baseline TIMEOUT (test_key_graph_context) did not recur. Three fails needed accounting and all three are cleared in nonBaselineFails above. Both arms of test_wave_markers re-run green after the final revert (373 / 870, x2).

DEVIATIONS FROM THE PROMPT, both recorded in the decision doc §8.1 rather than silently absorbed: (1) MP14's source tripwires die with every sabotage, though the prompt files MP10-MP14 as "must stay green" — a tripwire that survives a sabotage of its own line is the defective leg, so they were kept; (2) MP13's "and creation succeeded at that same far pixel" witness was MOVED to MP2, because as written MP13 both asserted the unchanged selection gate AND re-created a marker, which made it die under SAB-1 in contradiction with the same table's stay-green column. MP13 must survive every sabotage of the creation gate — it is the proof this item changed ONE gate and not the other.

PRE-EXISTING, NOT RE-FIXED (per instruction): src/callback.c:1509 quotes the now-retired "no trace near the pointer" string as its example of a non-modal refusal channel — stale prose, callback.c is outside this item's declared file list. find_closest_wave still carries landmine 40's two open defects. graph_coord (scheduler.c) still does not bracket graph_flags 128|256 around its setup_graph_data, the last of landmine 37's exposed queries. MF1 remains load-sensitive.
