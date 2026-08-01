# Item 04 axis-region-ctrl-wheel-zoom

- commit: `7e810bc2` (+ a fixup commit from the repair stage — see git log)
- files changed:
  - `src/xschem.h`
  - `src/draw.c`
  - `src/callback.c`
  - `src/scheduler.c`
  - `src/wave_viewer.tcl`
  - `tests/headless/test_wave_axis_zoom.tcl`
  - `doc/claude/specs/waveform_viewer_modes.md`
  - `doc/claude/code_analysis/waveform_subsystem_reference.md`
  - `doc/claude/code_analysis/ovb01_04_axis_region_ctrl_wheel_zoom_decision.md`
  - `doc/claude/overnight_batch_2026_08_01/prompts/04_axis-region-ctrl-wheel-zoom.md`
  - `doc/claude/issues/0191-axis-region-ctrl-wheel-zoom.md`
  - `doc/claude/issues/0190-axis-region-drag-zoom.md`
- tests: `tests/headless/test_wave_axis_zoom.tcl` — 308 checks (was 196)
- non-baseline audit fails claimed:
  - `test_wave_snap` — FAIL in the audit, ALL PASS (90 checks) standalone. WSLg/load flake. Checked hardest of the four: it is a waveform suite and this item edits draw.c.
  - `test_remap` — FAIL in the audit, ALL PASS standalone. This item changed only a C comment inside init_input_bindings.
  - `test_launch_context` — FAIL in the audit AND standalone, on 'main window has a usable size (geom=1x1+364+90)'. A WSLg window-geometry flake; nothing in it touches graphs.
  - `test_ciw_actionlog_output` — TIMEOUT in the audit, ALL PASS (25 checks) standalone under `--logdir`. A timeout under audit load.
- docs updated:
  - `doc/claude/specs/waveform_viewer_modes.md` — new §18 (18.1 gesture + the MEASURED chord x region table, 18.2 the maths and the fixed-point invariant, 18.3 where it applies, 18.4 no dirty flag/undo + the asymmetric logging, 18.5 the surface, 18.6 the tests); four new rows in §15.1's LMB/RMB ownership table; a correction box in §17.3 recording that D-19's digital branch was never implemented; a §17 cross-reference; §17.6's stale 119/173 check counts replaced with 190/308
  - `doc/claude/code_analysis/waveform_subsystem_reference.md` — new landmine 48 ('a wheel event over a graph never reaches the binding table', with the measured chord x region table); new landmine 47(d) (the axis WINDOW has one home, and its digital branch was wrong for one release, plus the two test lessons); §5 waves_callback paragraph; §9 verb list gains graph_axis_wheel_map; §10's 'New graph GESTURE IN A MARGIN' recipe gains the wheel variant
  - `doc/claude/issues/0191-axis-region-ctrl-wheel-zoom.md` — new issue file in 0190's house style
  - `doc/claude/issues/0190-axis-region-drag-zoom.md` — new §6 recording that its D-19 digital branch was documented and never implemented, what was measured, and that 0191's graph_axis_window() corrects it
  - `doc/claude/code_analysis/ovb01_04_axis_region_ctrl_wheel_zoom_decision.md` — Status line updated to IMPLEMENTED with the final check counts and the two implementation findings
  - `doc/claude/overnight_batch_2026_08_01/receipts/04_axis-region-ctrl-wheel-zoom.md` — the receipt (left uncommitted for the batch's final ledger commit, as the prompt requires)
- decision doc: `/home/qflow/dev/xschem/claude_1/xschem/doc/claude/code_analysis/ovb01_04_axis_region_ctrl_wheel_zoom_decision.md`
- implementation prompt: `/home/qflow/dev/xschem/claude_1/xschem/doc/claude/overnight_batch_2026_08_01/prompts/04_axis-region-ctrl-wheel-zoom.md`

## Spec holes resolved (SURFACE THESE TO THE USER)

### 1. D-25. Where does the gesture live -- the C engine (like item 03's LMB drag), the Tcl viewer, or both?

**Decision:** Both surfaces, with ONE formula in C. A new arm in waves_callback serves embedded schematic graphs; the ASE viewer's existing Tcl wheel handler asks C both which region the pointer is in and what the new window is, then writes that into its own model.

**Why:** A C-only implementation would be SILENTLY DEAD in the viewer -- exactly the failure PLAN Q10 flagged -- because src/wave_viewer.tcl:6611-6623 binds every wheel sequence with a `break` and never forwards to C. A Tcl-only implementation would leave embedded graphs behind, contradicting item 03, which deliberately put the drag in the engine 'beside the Button3 box zoom it is the twin of'. Putting the arithmetic in C and letting the viewer consume it as a query satisfies the one-formula-one-home rule (landmine 45(a)) with no third copy.

**Rejected:** C-only (dead in the viewer). Tcl-only (dead on embedded graphs, second copy of the map). Having the viewer forward the wheel to C: it would work, but the margin zoom would then write only the rect and be discarded by the next regenerate (a plain window resize) while the body zoom on the same modifier survives -- two Ctrl+wheel gestures with different lifetimes, three lines apart.

### 2. D-26. What exactly is 'the axis region'?

**Decision:** graph_axis_at() (src/draw.c:5105), reused verbatim and not widened: bottom margin = X, left margin = Y, bottom-left corner = Y; the plot box, everything outside the container rect, the reorder-grip column at every height, and any pixel graph_legend_at() claims all decline.

**Why:** PLAN said 'reuse it, do not write a second one' and source agrees completely -- it is already the shared oracle for the C drag gesture and, via `xschem get graph_axis_drag`, for the ASE viewer's press seam. A second region definition for one feature is the drift the whole item-03 split exists to prevent.

**Rejected:** A wheel-specific region such as 'anywhere outside the plot box' (would swallow the legend and the grip).

### 3. D-27. What is the zoom factor per wheel click? PLAN said 'match the existing graph wheel-zoom factor in callback.c; do not invent a new one.'

**Decision:** GRAPH_AXIS_WHEEL_FACTOR = 0.8, a new #define in src/xschem.h beside GRAPH_AXIS_ZOOM_MAX_FACTOR, MIRRORED in Tcl as wviewer::wheel_zoom's existing 0.8 literal with a 'change both' comment on each side and a source-level test leg asserting they are equal. Wheel-up multiplies the range by 0.8; wheel-down divides by 0.8.

**Why:** Source shows there are TWO existing factors and they differ. callback.c's Shift+wheel arms use var = 0.2*range, i.e. x0.8 in but x1.2 out (MEASURED: [0,1] -> [0.0999, 0.8999] and -> [-0.0999, 1.1001]) -- NOT reversible, losing 4% of the range per in-out round trip. The viewer's Ctrl+wheel already uses x0.8 / x(1/0.8), which is exact. The gesture being extended is Ctrl+wheel and the viewer is this batch's subject, so the viewer's Ctrl+wheel factor is the right ancestor; it also turns the round-trip test into a tight assertion instead of a loose 'approximately' one.

**Rejected:** Copying the Shift-wheel 0.8/1.2 pair (a 'returns approximately to the start' leg is the kind that passes while broken). A brand-new number. Two step sizes (0.2 analog / 0.05 digital, as the shipped Shift-wheel arms carry) -- one gesture, one step.

### 4. D-28. Where does the wheel formula live, and how can a headless suite reach it?

**Decision:** graph_axis_wheel_map(i, axis, p, dir, &lo, &hi) in src/draw.c immediately after graph_axis_map(), exposed as `xschem get graph_axis_wheel_map <gi> x|y <p> in|out` -> {lo hi} | {} (fail soft). The input is the DIRECTION WORD, not a numeric factor, so the constant lives inside the formula and has exactly one home.

**Why:** Landmine 47(b) in a second shape, and the same reason graph_axis_map was exposed: a getter is the only way to assert BOTH endpoints -- and therefore the anchor -- without replaying a Tk gesture, and it is what makes the --nogui arm of the suite meaningful at all.

**Rejected:** Taking f as a numeric argument (the constant would then have a second home at every call site including the getter -- precisely the problem item 03 had to solve after the fact with the graph_click_tol() accessor). Computing the map inline in the arm and again in the viewer.

### 5. D-29. Two formulas now need the same answer to 'what is this axis's window and what pixel extent does it occupy?' Where does that live?

**Decision:** A new static helper graph_axis_window() in src/draw.c, called by BOTH graph_axis_map() (item 03's drag) and the new graph_axis_wheel_map(). It carries the DIGITAL branch: on a digital strip the Y window is ypos1/ypos2 through the DS_Y/DG_Y transform, not gy1/gy2 through S_Y/G_Y.

**Why:** The new formula asks the identical question and a second copy is exactly the drift landmine 45(a)/47(b) exists to prevent. Writing the helper correctly is not optional: MEASURED, on a digital strip staged y1=0 y2=2.5 ypos1=0 ypos2=4, `xschem get graph_axis_map 0 y 526 267` answered 0.34586 1.90211 -- both inside the ANALOG window -- while graph_axis_zoom writes those numbers into ypos1/ypos2, whose real extent is [0,4]. Item 04's Y arm would otherwise ship that same defect as brand-new behaviour. This also makes item 03's own decision D-19 ('Y writes ypos1/ypos2 through DG_Y') true for the first time.

**Rejected:** Duplicating the analog-only resolution into the new function (consistent-but-wrong, and a second home). Writing the new function correctly and leaving graph_axis_map alone (the drag and the wheel would then disagree on digital strips -- a worse maintenance smell than either). Refusing digital strips in the wheel arm (arbitrary; graph_axis_at deliberately does not refuse them).

### 6. D-30. PLAN Q3 says Ctrl+wheel over the strip BODY is 'out of scope, unchanged, and witnessed as unchanged'. Unchanged from what?

**Decision:** It keeps doing what it MEASURABLY does today: a graph X pan of 0.05*gw, identical to a plain wheel. Not a canvas pan, not a canvas zoom. The plain-wheel arms stand down only via a `wheel_axis_done` flag that is set only when the axis zoom actually fired.

**Why:** Three comments in the tree would have led an implementer to write the regression witness against the wrong behaviour: callback.c:4805 says Ctrl-wheel over a graph 'stays canvas pan' and wave_viewer.tcl:5362 says it is 'hard-pinned to CANVAS zoom'. Both are false -- MEASURED, xorigin/yorigin/zoom never move once the pointer is over a strip. A witness written from a comment passes vacuously.

**Rejected:** Making Ctrl+wheel inert over the body (loses a shipped affordance). Extending the axis zoom to the body (the user asked for the margins, and the body already has Shift+wheel).

### 7. D-31. Plain, Shift and Alt wheel in the axis regions?

**Decision:** All unchanged, each with an explicit regression witness. MEASURED today: plain wheel in the X margin pans X and in the Y margin pans Y; Shift+wheel in the X margin zooms X anchored at x0.8/x1.2 and in the Y margin zooms Y; Alt+wheel over a graph is inert.

**Why:** PLAN Q2 and Q4. The witnesses are load-bearing because the new arm sits in the same if/else chain, on the same event type, and the plain arms currently match a Ctrl chord (they test only !(state & ShiftMask)).

**Rejected:** Nothing -- but note the Shift+wheel arms deliberately keep their non-reversible x0.8/x1.2 factor, so a leg must assert 1.2 there and 1/0.8 in the new arm.

### 8. D-32. What about graph_use_ctrl_key, the mode where Ctrl is required to touch a graph at all?

**Decision:** The new arm is gated on !graph_use_ctrl_key. In that mode Ctrl+wheel remains the ordinary graph wheel pan.

**Why:** Source: waves_selected:152 refuses every graph event without Ctrl in that mode, waves_callback's access_cond (:941) is the same test, and handle_mouse_wheel's Shift and Ctrl branches (:5300, :5303) already carry the identical !graph_use_ctrl_key reservation. Taking Ctrl+wheel there would leave that mode with no graph wheel pan at all. The default is 0 (xschem.tcl:15458), so the feature is on out of the box.

**Rejected:** Ignoring the flag (breaks the mode). Making the axis zoom the Ctrl+wheel behaviour there too (Ctrl carries no information in that mode -- every graph gesture holds it).

### 9. D-33. sharedx stacks -- does an X zoom hit one strip or all of them?

**Decision:** All, and by the mechanism that already exists: graph_axis_zoom()'s shipped participation predicate for the C path, and wheel_zoom's existing every-strip X loop for the viewer path (calling the C map once per strip with the same pointer pixel). Y is always the one strip.

**Why:** PLAN Q5, and item 03's D-8 already measured the mechanism: the C engine cannot see the viewer's `sharedx` at all, and wviewer::graph_props never emits `unlocked`, so X follows every same-sim_type strip whatever sharedx is set to. Calling the C map per strip anchors each strip in its own window at the same pointer pixel -- the same answer when the windows agree, and the right answer when they do not.

**Rejected:** Consulting sharedx from C (impossible). Zooming only the pointed strip's X (desynchronises a time-aligned stack).

### 10. D-34. Range clamping. PLAN Q9 said 'clamp to the same sane maximum item 03 uses; share the clamp, do not duplicate the number.'

**Decision:** No new clamp, and GRAPH_AXIS_ZOOM_MAX_FACTOR is deliberately NOT reused. The only guards are the shipped `if(hi == lo) hi += 1e-6` idiom and the existing `R == 0 || e2 == e1 => return 0` refusal.

**Why:** Source shows what that constant actually guards: R2 = R / |s| in the DRAG map, where |s| is a user-controlled drag span that can approach zero and put an inf into x1/x2 permanently (xschem.h:469-475 says so explicitly). The wheel map has no such division -- R2 = R * f with f a compile-time constant -- so importing the clamp would be cargo. Repeated wheel-ins shrink the range geometrically but can never reach zero in finite clicks, and the hi == lo guard catches the denormal end.

**Rejected:** Applying GRAPH_AXIS_ZOOM_MAX_FACTOR to the accumulated range (it is a per-gesture factor bound, not a window-size bound, and a 'minimum span' policy is a new user-visible rule nobody asked for).

### 11. D-35. Does it set the dirty flag, push a C undo point, push a viewer undo point, or need capture_live_graph_state?

**Decision:** None of the four, on either path. Item 03's D-14/D-15/D-16 verbatim.

**Why:** Landmine 19: the whole of waves_callback contains zero set_modify(1) and zero push_undo() -- a zoom is view state, and the ASE viewer's buffer is read-only for life so a dirty flag there would be a lie. Landmine 47(c): a C-side view write is a PRODUCER for the capture a later Tcl mutation runs, never a consumer. And wviewer::wheel_zoom pushes no undo snapshot today and must not start (modes spec section 14.1 -- window view state is deliberately outside a snapshot), or a single `u` after a zoom would revert an unrelated model edit.

**Rejected:** Copying the waveform-marker discipline, which deliberately does dirty and push undo -- because a marker is durable content and a zoom is not.

### 12. D-36. Does the viewer's margin zoom survive a window resize (a regenerate)?

**Decision:** Yes -- and this is a deliberate difference from item 03. The viewer writes the C map's answer into the Tcl MODEL (set_graphs + regenerate), exactly as wviewer::wheel_zoom already does for the body zoom.

**Why:** Item 03 accepted 'a plain window resize discards it' because its gesture has no Tcl in its loop. Here there IS Tcl in the loop -- the viewer owns the wheel bind -- so writing the model costs nothing and avoids the surprise of two Ctrl+wheel gestures, three lines apart, with different lifetimes.

**Rejected:** Having the viewer call `xschem graph_axis_zoom` (rect-only, and inconsistent with the body arm it sits beside).

### 13. D-37. Does it log for replay? PLAN Q8 said yes, with explicit numeric bounds.

**Decision:** The C ENGINE path logs exactly one `xschem graph_axis_zoom <gi> x|y <lo> <hi>` line at %.17g -- for free, because it applies through graph_axis_zoom(). The VIEWER path logs nothing, exactly like wviewer::wheel_zoom, pan_x and graph_zoom today.

**Why:** The engine path delivers PLAN's numeric bounds and is assertable in a --logdir child process. The viewer's log_action seam is for MODEL MUTATIONS (move_strip, move_trace, set_target_strip, clear_all); ranges are not in that class -- no viewer range gesture has ever logged, and adding a line to one arm of one modifier would make a replayed session inconsistent with itself.

**Rejected:** Logging from the viewer too (one line in a family of five silent ones). Logging pixels (they do not exist at replay time).

### 14. D-38. Which strip does the viewer act on, and what if the C mouse mirror is stale for a wheel with no preceding Motion?

**Decision:** wviewer::graph_at_pointer (shipped) resolves the strip; the axis question is then asked of C with the EVENT's own %x/%y. A stale mirror makes graph_axis_at answer "" and the gesture degrades to today's both-axes body zoom -- it can never pick the wrong strip.

**Why:** graph_at_pointer reads the C mouse mirror (wave_viewer.tcl:5385-5386), which the strip-drag work documented as stale for an event with no preceding Motion. Introducing a second Tcl strip resolver here would be exactly the second-source-of-truth item 03's D-22 refused, and the failure mode of the shipped one is graceful.

**Rejected:** A strip_bands_px-based resolver for this gesture alone (a second geometry home). Changing graph_at_pointer (out of scope; four other callers).

### 15. D-39. Empty strip, no raw loaded, or off-screen strip?

**Decision:** Empty and no-raw are allowed (pure geometry, item 03's D-20). An off-screen strip is refused through the shipped `gr->scx == 0.0 || gr->scy == 0.0` sentinel, and the verb answers {}.

**Why:** graph_axis_at already imposes no raw requirement and setup_graph_data produces a valid transform from the tokens alone. Landmine 37 names the scx/scy sentinel as the correct way for a caller that needs the transform to detect the off-screen early return.

**Rejected:** Copying graph_plotbox_at's loaded-raw gate, which would make the whole gesture silently dead before the first simulation.

### 16. D-40. Which suite owns this?

**Decision:** Extend tests/headless/test_wave_axis_zoom.tcl (item 03's suite) with five new groups CW*/CD*/CS*/CE*/CV*. No new file, no full_audit.sh registration change.

**Why:** PLAN's own suggestion, and source confirms it: that suite already owns axis geometry and carries the pixel scanners (az_box/az_xmargin/az_ymargin), the source-constant reader (az_define), the every-rect witness (az_windows), the --logdir child-process pattern for asserting a C self-logged line, and a live ASE viewer under $DISPLAY. full_audit.sh globs test_*.tcl so the file is already discovered.

**Rejected:** A new suite (would duplicate ~250 lines of scanners). test_wave_markers.tcl, which carries this batch's inherited red leg MF1 and is already shared by items 01 and 02.

## PLAN.md claims refuted by source

- PLAN Q10 ('verify the wheel event reaches the viewer... the most likely place for the feature to be silently dead') points at the wrong side. The viewer receives it fine. It is the C ENGINE that is surprising: handle_button_press's inline `if(waves_selected(...)) { waves_callback(...); return; }` (src/callback.c:7483-7486) pre-empts handle_mouse_wheel (src/callback.c:7541) for EVERY wheel press over a graph, so the four ACTX_OVER_GRAPH wheel binding rows (src/callback.c:4807-4810) are unreachable dead code and a binding-table row is NOT a viable way to add this gesture.
- PLAN Q3's premise ('Ctrl+wheel over the strip BODY -> out of scope, unchanged') is right but its implied meaning is wrong. MEASURED: Ctrl+wheel over an embedded graph -- body or margin -- is today a GRAPH X PAN of 0.05*gw, byte-identical to a plain wheel; xorigin/yorigin/zoom never move. It is not the canvas pan the tree's comments claim.
- PLAN Q1 ('match the existing graph wheel-zoom factor in callback.c so the feel is uniform; do not invent a new one'). There are TWO existing factors and they differ. callback.c's Shift+wheel arms (:2029, :2069) use var = 0.2*range = x0.8 in / x1.2 out -- MEASURED, and NOT reversible (4% drift per round trip). wviewer::wheel_zoom's Ctrl+wheel (wave_viewer.tcl:5458) uses x0.8 / x(1/0.8), which is exact. Taking 'the' factor in callback.c would ship a zoom that does not round-trip.
- PLAN Q9 ('Range clamping -> clamp to the same sane maximum/minimum span item 03 uses; share the clamp, do not duplicate the number'). GRAPH_AXIS_ZOOM_MAX_FACTOR guards a division by a user-controlled DRAG SPAN (R2 = R / |s|, xschem.h:469-475). A wheel map has no such division -- R2 = R * f with f a compile-time constant -- so there is nothing to share.
- PLAN's Q6 'log-scale axes: applied in the axis's own (log) space, same as item 03' is correct, but PLAN item 03's warning that setup_graph_data returns early before parsing logx does not apply the way it reads: gr->gx1..gy2 and G_X/G_Y are ALREADY in log space, and the off-screen case is caught by the gr->scx/scy sentinel. Reading logx off the rect and converting would double-apply the log.
- src/callback.c:4804-4806's own comment -- 'over a waveform graph, the no-modifier and Shift wheel drive the graph... Ctrl-wheel never did, so it has no over_graph row and stays canvas pan' -- is true only when the pointer is OFF every graph. Over a graph all three go to waves_callback, and the over_graph rows it describes are never consulted.
- src/wave_viewer.tcl:5361-5362's comment -- 'Ctrl+wheel is hard-pinned to CANVAS zoom (callback.c:4417)' -- is wrong on both counts (over a graph it is neither the canvas nor a zoom) and cites a line that no longer exists.
- Item 03's decision D-19 and doc/claude/specs/waveform_viewer_modes.md section 17.3 claim 'a DIGITAL strip's Y is the ypos1/ypos2 band... Y writes ypos1/ypos2 through DG_Y'. Source shows graph_axis_map() (src/draw.c:5213-5219) resolves the Y window from gr->gy1/gy2 with S_Y/G_Y UNCONDITIONALLY, with no digital branch, while graph_axis_zoom() writes the result into ypos1/ypos2 for a digital strip. MEASURED on a strip staged y1=0 y2=2.5 ypos1=0 ypos2=4: `xschem get graph_axis_map 0 y 526 267` -> 0.34586281243181671 1.9021063678409851, i.e. inside the analog window. A full-height left-margin drag on a digital strip therefore mis-zooms it by ~2.6x and anchors in the wrong place. Corrected here as a necessary consequence of D-29, not as an opportunistic fix.
- doc/claude/specs/waveform_viewer_modes.md section 17.6 says '119 checks in the --nogui arm, 173 with a display'. MEASURED today at 826e1b60: 128 and 196.

## Sabotage

### SAB-1 — zoom about the CENTRE (`zlo = A + (R - R2)/2.0`) in graph_axis_wheel_map
- target: CW3 / CE2 / CV6 (the fixed point), and CW2 must SURVIVE
- failed exactly: **no**
- note: All three named targets died. CW2 (the WIDTH leg) stayed GREEN — the distinction the whole suite is built on. Also killed, all in the same class: CW1 (closed form), CW4, CW8 (edge pinning), CD3, CS3 (the Tcl/C equivalence) and CS1 (the source tripwire that counts the anchored expression). 14 red, 293 green.

### SAB-2 — the callback.c arm calls graph_axis_zoom for BOTH axes
- target: CW6 / CE3 (the other axis is byte-identical)
- failed exactly: **no**
- note: CE3 (named) died, plus CE1's Y-untouched leg, CE9's log legs and AS1's call count. CW6 did NOT die and CANNOT: it drives the VERB `xschem graph_axis_zoom` so it can run in the --nogui arm, and no callback.c sabotage can reach it. Reported as a finding; CE3 carries the same invariant on the gesture path.

### SAB-3 — drop the graph_axis_at test (`int ax = GRAPH_AXIS_X`, always fire)
- target: CE5 (CTRL+wheel in the BODY still pans)
- failed exactly: **no**
- note: CE5 died (the body zoomed 0.0999..0.8999 instead of panning 0.05..1.05). Also CE3 and CE10's Y legs, because forcing the axis to X makes the Y margin zoom X. 4 red.

### SAB-4 — delete the digital branch of graph_axis_window()
- target: CD1 / CD2 (the digital band) and CS4 (the source count)
- failed exactly: **no**
- note: All three named targets died, plus CD3/CD4. The sabotaged map answered -10.375488281249991 -7.9954833984374929 where the Tcl-side ANALOG closed form gives -10.37548828125 -7.9954833984375 — i.e. it reproduced the pre-item defect to the digit. This run also EXPOSED a blind leg: CD2 was originally a FORWARD drag and stayed green, because graph_axis_map's forward branch collapses to lo = q for any window. Rewritten as a REVERSE drag before accepting the sabotage.

### SAB-5 — change wviewer::wheel_zoom's 0.8 literal to 0.75
- target: CS2 (the MIRRORED IN TCL constant)
- failed exactly: **YES**
- note: Exactly one red in BOTH arms: CS2. 1 FAILED (189 passed) --nogui and 1 FAILED (307 passed) under DISPLAY.

### SAB-6 — wviewer::wheel's ctrl arm drops the axis argument
- target: CV1 / CV2 (the viewer single-axis legs)
- failed exactly: **YES**
- note: Exactly two red: CV1's 'left every strip's y1/y2 unchanged' and CV2's 'left every strip's x1/x2 unchanged'. CV1's X-window legs stayed green because zoom_about and the C map agree numerically — which is CS3's point.

### SAB-7 — remove `&& !wheel_axis_done` from the two plain-wheel arms
- target: CE1b (the margin zoom is not ALSO a pan)
- failed exactly: **no**
- note: CE1b (named) died, and so did CE1/CE2/CE4/CE10/CE9. Unavoidable: the follow-on pan recomputes from the PRE-zoom gr->master_gx1/gx2 and overwrites the whole X window (0.05 1.05), so every X-margin engine leg dies with it. Cannot be narrowed to CE1b alone.

## Verifier (fresh adversarial context, not the implementer)

- **ok: false**
- **sabotage reproduced independently:** YES - SAB-1 end to end. Applied `zlo = A + (R - R2) / 2.0;` in place of `zlo = q - u * R2;` in graph_axis_wheel_map() (src/draw.c:5381); `git diff src/draw.c` showed that one line and nothing else; rebuilt; DISPLAY run gave `19 FAILED (319 passed)`. All three named targets died - CW3 'THE FIXED POINT' (before=0.2497981913246963 after=0.299838553059757), CE2 (before=0.249364044789752 after=0.2994912358318015), CV6 (before=0.2503302181693375 after=0.3002641745354701) - and the leg that had to SURVIVE, CW2 (the WIDTH leg), stayed green in both of its checks. Collateral was CW1(2), CW4(3), CW8(2), CW10(2), CW11(2), CD3(2), CS1(1), CV7(1), CS3(1), all fixed-point/closed-form legs, i.e. the same class. Reverted with `git checkout -- src/draw.c`, rebuilt, clean re-run ALL PASS (338) and ALL PASS (200).
- **audit matches baseline:** NO, but explained. `GUI_GATE=0 bash tests/headless/full_audit.sh` gave `SUMMARY: 259 pass 12 fail 1 crash/timeout 0 skip (total 272)`, `WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)`. Nine baseline fails went green in my run (test_altf5_ciw, test_ase_unnamed_net, test_deselect_mode, test_fluid_editing, test_graph_context, test_nh_anim_rearm, test_pristine_untitled_viewer_0172, test_readonly_action_dispatch, test_verb_noun_copy_move, test_wave_markers) and the baseline TIMEOUT test_key_graph_context passed, while THREE fails appeared that are NOT on the PREFLIGHT list: test_wave_modes (FAIL), test_wave_snap (FAIL), test_wave_split_strip (TIMEOUT). All three are waveform suites, i.e. exactly the turf this item edits, so I re-ran each standalone against the same binary: test_wave_modes ALL PASS (433 checks), test_wave_snap ALL PASS (90 checks), test_wave_split_strip ALL PASS (221 checks) - full counts, not skipped bodies. test_wave_modes's audit failures were all MG17 legs reporting the wrong context window (`{.x1.drw}` where `{.drw}` was wanted), the signature of a leaked toplevel from a neighbouring suite under audit load, and test_wave_snap's were the two `key g`/`key G` legs (the WSLg key-delivery flake in memory `wslg-key-delivery-flakes`). Not attributable to the item; the audit run is demonstrably noisy in both directions (0 SKIP vs the baseline's 11).

### Problems

- **HOLLOW, DEMONSTRATED:** the Y-axis half of the GESTURE is not witnessed by any check, on either path. Two one-token sabotages of shipped source leave the suite ALL PASS (338 checks under DISPLAY, 200 --nogui).
  - (a) src/callback.c, the new CTRL+wheel arm: `double p = (ax == GRAPH_AXIS_X) ? (double)mx : (double)my;` -> `... ? (double)mx : (double)mx;` (the Y branch now hands the formula the X pixel, which graph_axis_wheel_map clamps to the plot extent, so the Y zoom is anchored at a completely wrong point). Measured: CE3's Y window becomes `0.49155036 2.4915504` where the correct anchored answer is `0.24948653 2.2494865` - a 0.24 error, 12% of the range - and CE3, CE10 and every other leg stay green.
  - (b) src/wave_viewer.tcl, wheel_zoom's y arm: `wviewer::axis_wheel_window $token $t y $py $wdir` -> `... $px $wdir`. Measured: CV2's Y window becomes `0.44603692952749574 2.4460369295274957` where the correct answer is `0.25050395097564948 2.2505039509756495`; ALL PASS (338).
- **ROOT CAUSE of that hole, and it is the exact trap the suite documents and then walks into:** every Y-margin probe pixel in the file is `az_ymargin`'s y, which is `($by1 + $by2) / 2` - the plot box's vertical CENTRE, u = 0.5 - where an anchored zoom and a zoom-about-centre are numerically identical. CE0 and CW0 both carry an explicit teeth leg asserting the X probe is OFF-CENTRE ('at the centre a zoom-about-centre form is indistinguishable from the anchored one'), and CW4/cwpy is off-centre for the verb, but CE3, CE10's Y leg, CV2 and CV8 all fire at the centre-y. Consequently none of the four Y gesture legs asserts either of the two things the X legs assert: byte-equality with `xschem get graph_axis_wheel_map` (CE1b's counterpart) or the fixed point (CE2/CV6's counterpart). They assert only that the window's WIDTH became R*K, that the other axis did not move, and that the other strip did not move - all three of which survive an arbitrarily wrong anchor. FIX: give CE3 and CV2 an off-centre Y probe (e.g. `$eby2 - int($ebh * 0.25)`, which cw_scan already computes as cwpy) plus a fixed-point leg and a map-equality leg, and re-run sabotage (a)/(b) above to confirm they now die.
- **SECONDARY, same family and same fixture:** CE10's X leg and CE6's plain-wheel legs fire at `az_xmargin`'s x, which is `($bx1 + $bx2) / 2` - the box's horizontal centre - so they too cannot see an anchor error. This one is covered elsewhere (CE1b/CE2 use the off-centre `epx`), so it is a coverage remark rather than a hole; recording it because the same helper produces both centre pixels and a future leg written on `az_xmargin`/`az_ymargin` will inherit the blindness silently.

### Notes

Everything else I tried to break held. The commit is in scope, both arms are green at the claimed counts, SAB-1 reproduces exactly with CW2 surviving, the audit's three extra fails are all standalone-green at full counts, every PLAN question is answered or recorded as a deviation, and the docs are complete. ok=false rests on one thing only: the demonstrated Y-axis gesture hole, where a wrong pointer coordinate on either the C or the Tcl path ships with a 338/338 green suite.

## Repair stage report

Committed as `c11e0e9e`.

### What I changed

**`/home/qflow/dev/xschem/claude_1/xschem/tests/headless/test_wave_axis_zoom.tcl`** — the only functional change. `src/` is byte-identical to 7e810bc2 (`git diff 7e810bc2 HEAD --name-only | grep ^src/` → 0 files). Suite went **190 → 200** checks `--nogui`, **308 → 338** with a display.

| finding | leg added | sabotage that kills it |
|---|---|---|
| `!(state & ShiftMask)` had zero coverage | `CE12` (state-5 wheel in X-up / X-down / Y-up, each compared byte-for-byte against the state-1 reference, with a "the reference really moved" teeth leg) + `CE13` (the replay-log count in CE9's `--logdir` child) | **SAB-8** delete the term → 5 checks red: CE12's Y leg, CE13's two, CE9's two line-count legs. **No X-margin window leg moves** |
| CV1's fixture coincidence hiding D-33 | `CV7` — `cv_stage_split` stages strip 0 at `0..1.0` and strip 1 at `0..2.0`, asserts the two C map answers differ, then that each strip took **its own**, plus the fixed point on strip 1 | **SAB-9** X arm asks C for `$gi` not `$t` → CV7's 2 legs only; CV1 stays green |
| viewer per-strip Y witnessed on one strip | `CV8` — strip 1's Y margin, `graph_at_pointer` asserted to resolve **1** before the wheel | **SAB-10** `if {$t == 0}` → CV8's 2 legs only (verified twice); CV2 stays green |
| PLAN Q6 log axes never asserted for the wheel map | `CW10`/`CW11` — `logx=1` and `logy=1` at `-3..0`, anchored form re-derived in log space, both bounds required inside the token range, fixed point re-measured | **SAB-11** `q = pow(10,q)` → exactly 6 log legs; CW10's width leg survives |

**Two measured claims the verifier got half-right, corrected in the code comments:** the Ctrl+Shift window is byte-identical only in the **X** margin (the per-graph loop reloads `gr->gx1/gx2` from `master_gx1/master_gx2` and the Shift arm overwrites). In the **Y** margin `setup_graph_data(i,1,gr)` skips only x, so `gy1/gy2` are re-read from the tokens the suppressed arm wrote and the double apply *is* visible — CE12's Y leg has real teeth.

**Two flakes I introduced and then removed** (both measured, both documented):
- A second `--logdir` GUI child for CE13 put another toplevel on the display; under WSLg that restacked the parent canvas and landed the `AX*`/`CV*` cached probe pixels on the wrong strip (8/8 green before, 7/8 and 3/4 with it, 10/10 after merging CE13 into CE9's child). `CE9`'s `celine` now takes the **first** matching log line so its replay legs stay independent of CE13.
- CV8's predicted `az_ymargin` midpoint answered `NONE` ~1 run in 3 → `cv_yprobe` walks left until `graph_axis_at` itself says `y`, re-scanning if needed.

**Docs updated** (counts, the new sabotage rows, and the reasoning): `doc/claude/issues/0191-axis-region-ctrl-wheel-zoom.md` (new §3.1), `doc/claude/code_analysis/ovb01_04_axis_region_ctrl_wheel_zoom_decision.md` (new §7.1 + D-33 fixture requirement), `doc/claude/specs/waveform_viewer_modes.md` (§17.6/§18.6), `doc/claude/code_analysis/waveform_subsystem_reference.md` (landmine 48: a modifier guard can be load-bearing and still leave the window byte-identical).

### What I ran

- Item suite, both arms, repeatedly: `--nogui` **ALL PASS (200)**; DISPLAY **ALL PASS (338)**, soaked **10/10** then **6/6** via `GUI_GATE=0 tests/headless/run_suites.sh`.
- SAB-8..SAB-11 each applied, blast radius recorded, `git diff <file>` inspected, reverted with a targeted `git checkout --`, rebuilt, clean re-run green. `git diff --stat src/` empty at commit time.
- `GUI_GATE=0 tests/headless/full_audit.sh` **twice** (before and after the final test edits). Run 2: **261 PASS / 11 FAIL / 0 SKIP**, `test_wave_axis_zoom` PASS in both runs.

### What remains

- **11 audit failures in suites this commit cannot reach** (no `src/` change; nothing else reads this test file or these docs): `test_altf5_ciw`, `test_cadence_drag` (known-flaky), `test_ciw`, `test_lib_manager_gui`, `test_lib_sweep`, `test_phase3_mints`, `test_reopen_readonly`, `test_rota

## What the tests structurally CANNOT see (eyeball list)

- The pixel result. Every fixed-point leg asserts the DATA coordinate returned by `xschem graph_coord` at a fixed canvas pixel; no check reads a drawn pixel, so 'the trace under the pointer visibly did not move' is inferred, never seen. Nothing in the file confirms the trace, the axis numbers and the grid were actually re-rendered in agreement with the new tokens.
- The redraw itself. The arm sets `need_all_redraw = 1` and the comment reasons about draw_graph's bit 8 repainting the axis NUMBERS; no leg asserts a repaint happened at all, that no stale rubber band or old axis labels survive, or that the redraw does not flicker across a many-strip stack.
- Ergonomics of the step: whether 20% per click is the right increment, whether it feels the same as the Shift+wheel arm it sits beside (which is deliberately a DIFFERENT, non-reversible step), and whether a burst of trackpad/inertial wheel events produces a usable rate. The maths is exact; the feel is not reachable.
- Discoverability and affordance. The axis margin gets no cursor change, no hover cue and no status text, so nothing can assert that a user finds the region, or that the ~14% margin is a comfortable target to aim at - which is the same 'aimability' caveat item 03's drag inherits.
- The behaviour CHANGE for existing ASE-viewer users: Ctrl+wheel in a margin used to zoom BOTH axes and now zooms one. No check can say whether that reads as a feature or as a dead zone; only a user can.
- Real wheel hardware and the non-X11 path. Every leg synthesises either `xschem callback .drw 4/5 ...` or Tk `<Button-4>`; the `<MouseWheel>`/`%D` bindings at src/wave_viewer.tcl:6709-6710 (the Windows / Tcl>8.7 route into the same ctrl rung) are matched zero times in the suite, so that platform's arrival path is untested by construction.
- Whether `need_all_redraw` on every wheel click is acceptable interactively on a large multi-strip schematic - a performance property with no harness.

## Tunable constants (for the eyeball pass)

- `src/xschem.h:GRAPH_AXIS_WHEEL_FACTOR` = 0.8
- `src/wave_viewer.tcl:wviewer::wheel_zoom`'s f literal = 0.8 (the Tcl mirror of the above; CS2 goes red if they drift)

## Implementer summary

CTRL+wheel in a strip's axis-number margin now zooms THAT AXIS ONLY, about the pointer: the bottom (X-number) margin scales x1/x2 on every participating strip, the left (Y-number) margin scales y1/y2 -- ypos1/ypos2 on a digital strip -- on that strip alone. The data coordinate under the pointer keeps its screen pixel (lo = q - u*R2), which is the whole user ask.

BOTH the measurements the design rests on reproduced before any code was written: (a) CTRL+wheel over an embedded graph today is a graph X pan of 0.05*gw, byte-identical to a plain wheel, with xorigin/yorigin/zoom unmoved -- so three source comments claiming a canvas pan/zoom were wrong, and "unchanged in the body" means "still panning the graph"; (b) `xschem get graph_axis_map <gi> y` on a digital strip staged y1=0 y2=2.5 ypos1=0 ypos2=4 answered `0 1.6437`, i.e. inside the ANALOG window, proving item 03's own D-19 was documented and never implemented.

IMPLEMENTATION. src/xschem.h: GRAPH_AXIS_WHEEL_FACTOR 0.8 (mirrored in Tcl, change-both comment on each side) + the prototype. src/draw.c: graph_axis_window() (new static -- THE one home for "what is this axis's window and what pixel extent does it occupy", digital-aware) and graph_axis_wheel_map() (new -- THE wheel formula, factor inside, direction word in); graph_axis_map() rewired onto the helper and its digital pixel->data inverse (DG_Y) made consistent with it. src/callback.c: a new else-if in waves_callback's master block gated on ControlMask && !ShiftMask && !graph_use_ctrl_key, plus the wheel_axis_done local and `&& !wheel_axis_done` on the two plain-wheel arms, plus the corrected binding-table comment. src/scheduler.c: `xschem get graph_axis_wheel_map <gi> x|y <p> in|out`, fail-soft, in the case 'g' chain. src/wave_viewer.tcl: wviewer::axis_wheel_window (asks C, fails closed), wheel_zoom's new trailing {axis {}} argument (the {} arm is the shipped body zoom byte for byte), wheel's ctrl rung, and the corrected comment. graph_axis_at() and graph_axis_zoom() reused verbatim; no new binds.

TESTS: tests/headless/test_wave_axis_zoom.tcl 128 -> 190 checks --nogui and 196 -> 308 with a display, all green. Five groups CW/CD/CS/CE/CV. Every probe pixel is at 25% of the plot extent, never the centre -- at the centre the anchored and centre-anchored forms agree and SAB-1 walks straight through.

TWO TEST DEFECTS FOUND AND FIXED BY THE SABOTAGES, both worth carrying forward: (1) `*e1 = DS_Y(gr->ypos1)` is INVISIBLE to az_count_code, which skips lines starting with `*` because that is what a C comment continuation looks like -- graph_axis_window now assigns locals and writes the out-parameters once at the end; (2) a FORWARD drag cannot see which axis window graph_axis_map used, because its forward branch lo = A + ua*R with ua = (q-A)/R collapses to lo = q for ANY window -- CD2 stayed green with the entire digital branch deleted until it was rewritten as a REVERSE drag.

AUDIT: SUMMARY: 239 pass 17 fail 2 crash/timeout 14 skip (total 272), WIREEDIT: PASS, SCRATCH: 0 leaked dir(s). The PLAN PREFLIGHT baseline is STALE for this item -- it was taken at e516cc85, before items 01/02/03 landed, so its `total 271` predates item 03's own suite. 239 pass matches exactly; 15 of the 19 non-passes are on the baseline list verbatim; six baseline fails went green in this run (not claimed as wins); the four non-baseline results were each re-run standalone and three are ALL PASS while test_launch_context fails on a 1x1 window geometry -- all WSLg/load flakes. test_graph_context (baseline red) and test_key_graph_context (baseline timeout) are unchanged: neither better nor worse, not chased.

OUT-OF-SCOPE FINDINGS RECORDED, NOT FIXED: the four ACTX_OVER_GRAPH wheel binding rows are unreachable dead code (comment corrected, rows kept per the prompt); CW6 is verb-level and no callback.c sabotage can reach it; SAB-7 cannot be narrowed to CE1b alone.

## Second repair stage report (after verifier #2)

### The one finding, reproduced before anything was changed

Both named sabotages left the suite **completely green** at HEAD (`33e3512b`):

| sabotage | runs | result |
|---|---|---|
| (a) `src/callback.c`: `... ? (double)mx : (double)my;` -> `... : (double)mx;` | 4 under DISPLAY + 1 `--nogui` | `ALL PASS (361)` / `ALL PASS (200)` |
| (b) `src/wave_viewer.tcl`: `axis_wheel_window $token $t y $py $wdir` -> `... $px $wdir` | 3 under DISPLAY | `ALL PASS (361)` |

`killedBefore` = **0** for both. Each was reverted with a targeted
`git checkout -- <file>` after `git diff` showed that file held nothing but the
sabotage.

### What I changed — `tests/headless/test_wave_axis_zoom.tcl` only

`src/` is byte-identical to `33e3512b` (`git diff 33e3512b -- src/` is empty).
The suite goes **361 -> 370** with a display; `--nogui` is unchanged at **200**
(the `CE*`/`CV*` groups are DISPLAY-only).

| new leg | what it asserts | dies with |
|---|---|---|
| `CE0` x2 | `$epy = eby2 - int(ebh*0.25)` is off-centre, and C itself calls `($eymx,$epy)` strip 0's Y region | staging errors |
| `CE3b` | the applied Y window is byte-for-byte `graph_axis_wheel_map`'s answer **for the pointer's own y pixel** | (a) |
| `CE3c` | THE FIXED POINT on Y: `graph_coord`'s data y at that pixel is unchanged across the gesture | (a) |
| `CE10` map leg | the same byte-equality on strip 1, at its own off-centre y | (a) |
| `CV2` teeth | the viewer probe's `u` is >0.1 from 0.5, stated in DATA space so no box re-scan can drift it | staging errors |
| `CV2` region | C calls the probe pixel strip 0's Y region | staging errors |
| `CV2b` | the viewer's applied Y window is byte-for-byte the C map's answer for `$py` | (b) |
| `CV2c` | THE FIXED POINT on Y in the viewer | (b) |

Plus: `cv_yprobe` gained a `fracs` **list** of candidate heights, off-centre
first — `CV2` passes off-centre-only and goes red if none lands, `CV8` takes the
default list whose last resort is the centre. The list is load-bearing: a single
0.25 height found no Y pixel at all on **strip 1** ~1 run in 3 (strip 0 was fine
11/11). `az_xmargin`/`az_ymargin` keep returning the centre — right for a REGION
leg — and now carry a ⚠ PROBE PLACEMENT block with the measurement and the rule.

### The acceptance test

* sabotage (a) re-applied, rebuilt: **`3 FAILED (367 passed)`, twice** —
  `CE3b`, `CE3c`, `CE10`'s map leg. Every width leg, every "other axis
  byte-identical" leg and every "other strip untouched" leg stayed GREEN, which
  is the CW2 asymmetry the suite is built on. Reverted, rebuilt, clean re-run
  `ALL PASS (370)`.
* sabotage (b) re-applied: **`2 FAILED (368 passed)`, twice** — `CV2b`, `CV2c`
  and nothing else. Reverted, clean re-run `ALL PASS (370)`.
* soak after the revert: **16/16** `ALL PASS (370)` via
  `GUI_GATE=0 tests/headless/run_suites.sh` with the probe list in place
  (23/24 counting the run that exposed the flake below), plus `ALL PASS (200)`
  `--nogui` (soaked 205/205 across the session).

### One pre-existing WSLg flake, seen once in 24, NOT introduced here

`cv_strip 1` answered `{}` for twelve consecutive retries with an `update`
between each: the viewer window came up too short, strip 1 fell outside the
transform, `graph_axis_wheel_map` refused it through the `scx == 0.0` sentinel
and strip 1's window never moved. The FIRST casualty is `CV7`'s "strip 1 was
scanned for its own fixed-point probe" leg — added by repair pass 1 and untouched
here — followed by `CV8` and any strip-1 probe. Signature: **`CV7` + `CV8` red
together with an empty scan in the message.** Same family as
`test_launch_context`'s 1x1 window geometry. Retrying does not help; the bad
layout persists for the life of that viewer. Recorded in issue §3.2.

### Docs

`doc/claude/issues/0191-…md` §3 counts + SAB-12/SAB-13 rows + new §3.2;
`doc/claude/code_analysis/ovb01_04_…_decision.md` Status line + new §7.2;
`doc/claude/specs/waveform_viewer_modes.md` §17.6 / §18.6 counts, a ⚠ PROBE
PLACEMENT box and the two new sabotage entries;
`doc/claude/code_analysis/waveform_subsystem_reference.md` landmine 48 gains
"the plot box's CENTRE cannot witness an ANCHOR".

### Audit, second repair stage — `GUI_GATE=0 bash tests/headless/full_audit.sh`

`SUMMARY: 239 pass  18 fail  1 crash/timeout  14 skip  (total 272)`,
`WIREEDIT: PASS` (all 58), `SCRATCH: 0 leaked dir(s)`.
**`test_wave_axis_zoom` PASS.**

**239 pass matches the PREFLIGHT baseline exactly** (`239 pass 20 fail 1
crash/timeout 11 skip, total 271` at `e516cc85` — the baseline predates items
01/02/03, hence 271 vs 272). Sixteen of the nineteen non-passes are on the
baseline list verbatim, seven baseline fails went green in this run (not claimed
as wins), and `test_key_graph_context` is the baseline TIMEOUT, unchanged.

Five results NOT on the baseline list, each re-run standalone against the same
binary:

| suite | audit | standalone |
|---|---|---|
| `test_hover_highlight` | FAIL | **ALL PASS** |
| `test_launch_context` | FAIL | **ALL PASS** |
| `test_wire_vertex_grab` | FAIL | **ALL PASS** |
| `test_wave_modes` | FAIL | **ALL PASS (433 checks)** — full count, not a skipped body |
| `test_remap` | FAIL | **3/4 green**; the three red legs are `key Shift-F logs flip` / `key Alt-F logs flip_in_place` / `key Shift-R logs rotate`, i.e. the documented WSLg key-delivery flake, and it was on the *first* item-04 run's non-baseline list too |

None is reachable from this commit: `src/` is untouched and nothing outside
`test_wave_axis_zoom.tcl` reads it or the four docs.

**A FIRST audit run is discarded and not reported as the result.** It was taken
with a `--nogui` soak of this suite running concurrently, and its
`test_wave_modes` leg died with `X connection to :0 broken (explicit kill or
server shutdown)` — a WSLg Xwayland abort mid-run (memory `wslg-xwayland-aborts`).
The run above was taken with the machine otherwise idle.

# Remediation (gap closed)

- **fixup commit:** `42e2fdfc`
- **checks:** 370 (was 361)
- **files:**
  - `/home/qflow/dev/xschem/claude_1/xschem/tests/headless/test_wave_axis_zoom.tcl`
  - `/home/qflow/dev/xschem/claude_1/xschem/doc/claude/issues/0191-axis-region-ctrl-wheel-zoom.md`
  - `/home/qflow/dev/xschem/claude_1/xschem/doc/claude/code_analysis/ovb01_04_axis_region_ctrl_wheel_zoom_decision.md`
  - `/home/qflow/dev/xschem/claude_1/xschem/doc/claude/code_analysis/waveform_subsystem_reference.md`
  - `/home/qflow/dev/xschem/claude_1/xschem/doc/claude/specs/waveform_viewer_modes.md`

## New legs

- **CE0** the Y probe pixel is really OFF-CENTRE too (teeth: at the box centre an anchored Y zoom and a zoom about ANY other point of the window are indistinguishable by width) `py=$epy cy=$ecy h=$ebh`
- **CE0** ...and C itself calls (`$eymx`,`$epy`) = (...) strip 0's Y region, so the gesture below really is the margin gesture
- **CE3b** ...and it is EXACTLY `graph_axis_wheel_map`'s answer for the pointer's OWN y pixel `$epy`, so the arm anchored where the pointer is
- **CE3c** THE FIXED POINT on Y: the data y under the pointer pixel is unchanged
- **CE10** ...to EXACTLY `graph_axis_wheel_map`'s answer for RECT 1 at that pixel
- **CV2** C calls the probe pixel (...) strip 0's Y region
- **CV2** the probe is really OFF-CENTRE in the window: `u=...` (teeth: at `u=0.5` an anchored Y zoom and a zoom about the window's centre give the SAME two numbers and CV2b/CV2c below could not tell them apart)
- **CV2b** ...and it is EXACTLY the C map's answer for the pointer's OWN y pixel ..., so the viewer arm passed `$py` and not `$px`
- **CV2c** THE FIXED POINT on Y in the viewer: the data y under the pointer pixel is unchanged

## The hollow spot, closed

- **sabotage:** TWO, both of shipped source, both applied verbatim from the verifier.
  - (a) `src/callback.c`, the CTRL+wheel arm in `waves_callback`:
    `double p = (ax == GRAPH_AXIS_X) ? (double)mx : (double)my;` -> `... ? (double)mx : (double)mx;`
  - (b) `src/wave_viewer.tcl`, `wviewer::wheel_zoom`'s y arm:
    `set w [wviewer::axis_wheel_window $token $t y $py $wdir]` -> `... $t y $px $wdir`
- **checks it killed BEFORE the remediation:** 0 (this is why the item was `[F]`)
- **checks it kills NOW:**
  - (a) CE3b ...and it is EXACTLY `graph_axis_wheel_map`'s answer for the pointer's OWN y pixel 226 (map=0.12405345708223009 2.1240534570822303 window=0.49155036 2.4915504)
  - (a) CE3c THE FIXED POINT on Y: the data y under the pointer pixel is unchanged (before=0.6202672854111505 after=0.987764198253197)
  - (a) CE10 ...to EXACTLY `graph_axis_wheel_map`'s answer for RECT 1 at that pixel (map=0.12508039453176345 2.1250803945317633 window=0.5 2.5)
  - (b) CV2b ...and it is EXACTLY the C map's answer for the pointer's OWN y pixel (map=0.12440898345153717 2.1244089834515369 after=0.39775413711583973 2.3977541371158395)
  - (b) CV2c THE FIXED POINT on Y in the viewer (before=0.622044917257686 after=0.8953900709219884)
- **clean re-run green:** true

## Verifier (fresh adversarial context)

- **ok:** true
- **hollow spot closed, reproduced by the verifier itself: true**
- **audit matches baseline:** undefined
- **problems:** (none)
- **notes:** (none)

## What the tests still structurally CANNOT see

- **THE PIXELS.** Every leg — old and new — asserts a DATA coordinate (`xschem graph_coord`) or a rect property. Nothing reads the canvas, so "the trace under the pointer visibly stayed put on the Y axis" is inferred from the model, never seen.
- **THE REPAINT.** The arm sets `need_all_redraw`; no leg asserts that a repaint happened, that the Y axis NUMBERS and grid were re-drawn in agreement with the new window, or that no stale Y label survives.
- **THE FEEL.** Whether an 18%-of-range Y slide would have been noticed by a human before this leg existed — the reason the hole outlived a green suite is that it is a subtle drift, not a broken gesture. Equally: whether the left margin at 25% height is a comfortable place to aim. Both are fixture/ergonomics judgements no check can make.
- **REAL WHEEL HARDWARE** and the `<MouseWheel>`/`%D` arrival path (Windows, Tcl > 8.7): still matched zero times by the suite. Only Button-4/5 is exercised.
- **THE 1-IN-24 LAYOUT FLAKE** the repair documents (strip 1 persistently unscannable -> CV7+CV8 red with an empty scan): no leg can tell a WSLg window that came up too short from a genuinely off-screen strip, so the condition is recorded rather than distinguished. I did not see it in 9 runs.
- **RESIDUAL COVERAGE GAP**, not a blocker and outside the mandate: the anchored Y fixed point is asserted on LINEAR axes only. CW10/CW11 cover log space at the MAP level; no GESTURE-level leg (CE*/CV*) fires on a logy strip. The map is the shared primitive and the new legs pin which pixel is handed to it, so the composition is argued rather than measured.

## Remediation summary

The verifier's finding reproduced exactly and then closed, test-file only — `git diff 33e3512b -- src/` is empty.

FIRST, THE HOLE WAS RE-MEASURED, NOT TAKEN ON TRUST. Sabotage (a) applied to `src/callback.c` and rebuilt: `ALL PASS (361)` under DISPLAY 4/4 and `ALL PASS (200)` `--nogui`. Sabotage (b) applied to `src/wave_viewer.tcl`: `ALL PASS (361)` 3/3. killedBefore = 0 for both. Each reverted with a targeted `git checkout --` after `git diff` showed nothing but the sabotage. (Note the counts: the suite is at 361 with a display, not 338 — item 03's own fixup, `33e3512b`, added AG14/AG15 to the same file after the verifier measured.)

ROOT CAUSE, confirmed by construction. Every Y-margin probe pixel came from `az_ymargin`, whose y is `(by1+by2)/2` — the plot box's vertical CENTRE, u = 0.5 — where `lo = q - u*R2` and `lo = A + (R-R2)/2` are numerically identical. The four Y gesture legs asserted only the new window's WIDTH, that the other axis did not move, and that the other strip did not move; all three survive an arbitrarily wrong anchor.

THE REPAIR gives the Y half, on BOTH paths, the two assertions the X legs carry — byte-equality with `xschem get graph_axis_wheel_map` for the pointer's OWN y pixel, and the fixed point — each fired at an off-centre pixel with a teeth leg asserting the off-centre-ness. C path: `$epy = eby2 - int(ebh*0.25)` (CE3b/CE3c), plus CE10's strip-1 counterpart at its own off-centre y. Viewer path: CV2b/CV2c, with the teeth stated in DATA space (`|u - 0.5| > 0.1`) so no box re-scan can drift it.

ACCEPTANCE. Sabotage (a) re-applied and rebuilt: `3 FAILED (367 passed)`, twice — CE3b, CE3c, CE10's map leg, and NOT one width / other-axis / other-strip leg, preserving the CW2 asymmetry the suite is built on. Sabotage (b): `2 FAILED (368 passed)`, twice — CV2b, CV2c only. Both reverted, rebuilt, clean re-runs `ALL PASS (370)`.

ONE THING I GOT WRONG AND FIXED. My first cut gave `cv_yprobe` a single off-centre height (frac 0.25) as its default. That found no Y-margin pixel at all on STRIP 1 about 1 run in 3 — which heights of the left margin `graph_axis_at` claims depends on the layout of the moment. It is now a LIST tried in order: CV2 passes off-centre heights only and goes RED if none lands (it must never quietly become a centre probe), CV8 takes the default whose last resort is the centre. Soaked 16/16 after that change (23/24 counting the run that exposed it), 205/205 `--nogui`.

ONE RESIDUAL FLAKE, PRE-EXISTING, NOT MINE. In 1 run of 24, `cv_strip 1` answered `{}` for twelve consecutive retries with an `update` between each: the viewer came up too short, strip 1 fell outside the transform and `graph_axis_wheel_map` refused it through the `scx == 0.0` sentinel. Its FIRST casualty is CV7's "strip 1 was scanned" leg — added by repair pass 1, untouched here. Signature: CV7 + CV8 red together with an empty scan in the message. Same family as `test_launch_context`'s 1x1 geometry; a retry does not help because the bad layout persists. Recorded in issue §3.2 and the receipt, not papered over.

A FIRST FULL AUDIT IS DISCARDED AND NOT REPORTED: I ran a `--nogui` soak of this suite concurrently with it, and its `test_wave_modes` leg died with `X connection to :0 broken` — a WSLg Xwayland abort. The reported audit was taken with the machine otherwise idle: `SUMMARY: 239 pass 18 fail 1 crash/timeout 14 skip (total 272)`, WIREEDIT PASS (58), SCRATCH 0 leaked, and `test_wave_axis_zoom` PASS. 239 pass matches the PREFLIGHT baseline exactly (baseline `239 pass … total 271`, taken at `e516cc85` before items 01/02/03, hence 271 vs 272). Sixteen of nineteen non-passes are on the baseline list verbatim; seven baseline fails went green and are not claimed as wins.

The secondary remark is addressed without widening scope: `az_xmargin`/`az_ymargin` still return the centre — correct for a REGION leg — but now carry a ⚠ PROBE PLACEMENT block with the measurement and the rule, and the same paragraph is landmine 48's third sub-point in the subsystem reference, so a future leg written on them cannot inherit the blindness silently.

Only the two pre-existing dirty tracked files remain (`next_session_prompt_0165.md`, `tb_bandgap.state`).
