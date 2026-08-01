# Item 03 axis-region-drag-zoom

- commit: `6d401fee` (+ a fixup commit from the repair stage — see git log)
- files changed:
  - `src/xschem.h`
  - `src/draw.c`
  - `src/callback.c`
  - `src/scheduler.c`
  - `src/actions.c`
  - `src/xinit.c`
  - `src/wave_viewer.tcl`
  - `tests/headless/test_wave_axis_zoom.tcl`
  - `doc/claude/specs/waveform_viewer_modes.md`
  - `doc/claude/code_analysis/waveform_subsystem_reference.md`
  - `doc/claude/code_analysis/ovb01_03_axis_region_drag_zoom_decision.md`
  - `doc/claude/overnight_batch_2026_08_01/prompts/03_axis-region-drag-zoom.md`
  - `doc/claude/issues/0190-axis-region-drag-zoom.md`
- tests: `tests/headless/test_wave_axis_zoom.tcl` — 173 checks
- non-baseline audit fails claimed:
  - `test_launch_context` — audit run only; PASSES standalone on re-run. Its first leg is "main window has a usable size (geom=1x1+0+0)", the signature of a WSLg/WM sizing event during the audit; nothing in this item touches window creation.
  - `test_wave_grid` — audit run only (2 key-logging legs); PASSES standalone, 80 checks. WSLg key-delivery flake (memory `wslg-key-delivery-flakes`).
  - `test_wave_legend` — TIMEOUT in the audit only; PASSES standalone, 77 checks.
  - `test_wave_trace_menu` — audit run only, and the failing leg is TG9 "posted in ROOT coordinates", the documented 4-in-10 WSLg flake; PASSES standalone, 323 checks.
  - `test_wire_vertex_grab` — audit run only; PASSES standalone. Wire editing, entirely outside this item's turf.
- docs updated:
  - `doc/claude/specs/waveform_viewer_modes.md`
  - `doc/claude/code_analysis/waveform_subsystem_reference.md`
  - `doc/claude/code_analysis/ovb01_03_axis_region_drag_zoom_decision.md`
  - `doc/claude/issues/0190-axis-region-drag-zoom.md`
- decision doc: /home/qflow/dev/xschem/claude_1/xschem/doc/claude/code_analysis/ovb01_03_axis_region_drag_zoom_decision.md
- implementation prompt: /home/qflow/dev/xschem/claude_1/xschem/doc/claude/overnight_batch_2026_08_01/prompts/03_axis-region-drag-zoom.md

## Spec holes resolved (SURFACE THESE TO THE USER)

### 1. D-1. What exactly is 'the axis region'?
**Decision:** The strip's BOTTOM margin (below the plot box) owns the X axis; its LEFT margin (left of the plot box) owns the Y axis. Both are derived from the engine's own plot box (gr->x1/x2/y1/y2) and container rect (gr->rx1/ry1/rx2/ry2), never from marginx/marginy.

**Why:** PLAN's recommendation, with two corrections source forces. Deriving from the margin widths is wrong: the right edge is rx2 - 0.35*marginx and the TOP edge has three different formulas depending on digital/vlegend (draw.c:4001-4005), so a margin-based region re-implements three special cases and will drift. And the region must additionally exclude the reorder grip and any pixel the legend owns (see D-4, D-6).

**Rejected:** Deriving the regions from marginx/marginy as PLAN suggested; treating the whole non-plot-box area of the rect as 'the axis region' (that would swallow the legend and the grip).

### 2. D-2. Which existing gestures does this collide with, and is any of them actually given up?
**Decision:** In the C engine: none -- an LMB margin drag is a verified no-op today. In the ASE viewer: the strip drag-reorder currently arms in the axis margins, and it gives them up. It keeps the reorder grip, the empty plot body and the legend band.

**Why:** wviewer::strip_drag_press resolves the strip with strip_at_pixel (wave_viewer.tcl:2283), which tests the WHOLE band from graphbb -- margins included -- so the margins were in the reorder zone by permissiveness, not by design. The spec's own definition of the zone is 'the reorder handle (always) or empty waveform body' (waveform_viewer_modes.md 12.1). The margins are neither.

**Rejected:** Keeping the margins for the strip reorder and putting the axis zoom on a modifier (contradicts the user's plain-LMB request); DEFERring on the grounds that a committed gesture is taken (the taken zone was never claimed by the spec).

### 3. D-3. A press in the margin that also grabs an x/y CURSOR -- who wins?
**Decision:** The CURSOR wins. The axis drag arms only when the same press grabbed no cursor (!(graph_flags & (16|32|512|1024))).

**Why:** This collision is missing from PLAN's list and it is the one that shapes the design. The cursor grab tests have no plot-box confinement at all (callback.c:1240/1250/1269/1288), and more importantly the cursor is VISIBLE in the margin: draw_cursor draws its line across the full rect height and its numeric readout label at gr->ry2-1, i.e. IN the bottom margin (draw.c:4077/4082); draw_hcursor draws rx1+10..rx2-10 and labels at rx1+5, i.e. IN the left margin (draw.c:4139/4146). A press on a drawn, labelled cursor must still grab it. This is also the shipped rule for the two other LMB gestures ('a press that grabbed a cursor still wins', waveform_viewer_modes.md 12.1/13.1).

**Rejected:** Axis-drag-wins in the margin (would make a visible, labelled cursor ungrabbable at exactly its own readout).

### 4. D-4. The reorder grip column overlaps the bottom margin's right 14 px. Who wins?
**Decision:** The GRIP, unconditionally, refused inside graph_axis_at itself so both C and Tcl agree by construction.

**Why:** graph_marker_press already gives the grip unconditional first refusal for exactly this overlap (callback.c:605-606), and wviewer::strip_drag_press tests the grip before anything else (:2966). Making the C region query decline the column is what lets the viewer's new rung sit inside the existing handle test without a second geometry rule.

**Rejected:** Letting the axis region take the bottom-right 14 px (a silent, invisible split of the grip that no user could predict).

### 5. D-5. A press on a MARKER anchor or callout near a margin -- who wins?
**Decision:** The MARKER, with no code change: the new arm sits inside the else-branch of the existing `mkpress > 0` test (callback.c:1224-1232).

**Why:** A callout is clamped inside the plot box but graph_marker_at's 8-px tolerance can reach out of it, and the marker gesture has owned first refusal on Button1 since it shipped (graph_markers.md 7.2/7.3).

**Rejected:** Testing the axis region before the marker press.

### 6. D-6. The VERTICAL and DIGITAL legends live in the left margin. Who wins there?
**Decision:** The LEGEND: graph_axis_at answers 'none' wherever graph_legend_at(i,px,py) >= 0.

**Why:** Also missing from PLAN's collision list, which says only that 'the top of the rect is the legend'. That is true of the HORIZONTAL layout alone. legend_slot_hit places vlegend slots at rx1+5 .. x1-5 (draw.c:4501-4502) and digital slots at rx1 .. x1-20*txtsizelab (:4508-4509) -- i.e. the left margin. The ASE viewer never emits vlegend (wave_viewer.tcl:1770) so viewer strips are unaffected, but ~127 shipped schematics carry embedded graphs and not all are horizontal-legend.

**Rejected:** Refusing vlegend/digital strips wholesale (would also kill their X axis, which has no conflict at all).

### 7. D-7. The bottom-LEFT corner is in both margins. X or Y?
**Decision:** Y.

**Why:** Matches the shipped RMB arm exactly: its Y branch tests `graph_left && !graph_top` and never consults graph_bottom (callback.c:2129). One precedence rule in the file rather than two.

**Rejected:** X-wins; refusing the corner outright (a dead ~14x14 hole users would find and report).

### 8. D-8. Does an X zoom apply to one strip or to the whole stack?
**Decision:** To every PARTICIPATING strip, using the shipped predicate `r->sel || (same_sim_type && !(r->flags & 2)) || i == master` evaluated inside graph_axis_zoom. A Y zoom is always the one strip.

**Why:** PLAN's answer is right but its mechanism is wrong (see planClaimsRefuted). The C engine cannot see the viewer's `sharedx` at all; propagation is the same participation test MMB pan, RMB box zoom and the arrow-key pans already use, and same_sim_type additionally requires the master rect to be locked (callback.c:1697-1702). Since wviewer::graph_props emits `flags=graph` and never `unlocked`, X propagates to every same-sim_type strip in the viewer whatever sharedx is set to -- which is already true of every existing range gesture.

**Rejected:** Consulting the Tcl `sharedx` flag from C (a window option C has no access to); applying X to the dragged strip only (would desynchronise a time-aligned stack).

### 9. D-9. Click-vs-drag threshold?
**Decision:** GRAPH_CLICK_TOL (3.0) screen pixels, measured on the DRAGGED AXIS's own component, tested inside graph_axis_map. Below it: nothing written, nothing logged.

**Why:** The same constant the strip drag, the trace drag and the wave-bold click already use. The axis's own component because a Y drag has no meaningful X travel and vice versa. It also keeps a sub-threshold margin press exactly as harmless as it is today (the wave-bold arm already finds no body and no legend entry there).

**Rejected:** A new constant; testing both components jointly (a pure X drag with 4 px of hand tremor in Y would then be judged on the wrong axis); moving GRAPH_CLICK_TOL into xschem.h (landmine 20 explains why it is deliberately file-private and must not be confused with GRAPH_TRACE_PICK_TOL).

### 10. D-10. Rubber-band preview during the drag?
**Decision:** Yes -- a band drawn with drawtemprect (gctiled erase, gc[SELLAYER] draw) reusing xctx->graph_rubber_x/y/active, spanning the plot box across the un-dragged axis. NOT a prop token, NOT under draw_graph flags bit 16.

**Why:** PLAN recommended the bit-16 route; source refutes it (see planClaimsRefuted). The C-side live rubber has never gone through draw_graph -- callback.c:1642-1681 is the shipped mechanism, complete with the erase bookkeeping, the clamp-to-plot-box, and a free no-op under --nogui because drawtemprect does nothing when !has_x. reorder_handle=2/3/4 is the TCL-driven feedback path, and there is no Tcl in this gesture's loop.

**Rejected:** A fifth reorder_handle value drawn under draw_graph bit 16 (would require a Tcl token rewrite per motion event from a layer that is not running).

### 11. D-11. Release outside the strip / outside the plot box?
**Decision:** Clamp the release position to the plot-box extent and COMMIT.

**Why:** PLAN Q10, and it matches what the shipped RMB rubber already does with its moving corner (callback.c:1652-1653). GRAPHPAN is the routing latch (landmine 36), so the release does arrive at the graph even after the pointer leaves it.

**Rejected:** Cancelling on an out-of-bounds release (a drag that overshoots the axis by 2 px would silently do nothing).

### 12. D-12. Degenerate or explosive zoom-out (drag span approaching zero)?
**Decision:** Clamp the zoom-out factor at GRAPH_AXIS_ZOOM_MAX_FACTOR = 1000.0 (new #define in xschem.h, not mirrored in Tcl), plus the shipped `hi == lo => hi += 1e-6` guard.

**Why:** Never divide by zero -- an inf written into x1/x2 is permanent and unrecoverable by any gesture. In practice D-9's 3-px threshold binds first (the reachable maximum is about plot_width/3), so this is a backstop rather than a policy knob.

**Rejected:** No clamp; a small cap like 100 (would silently truncate a legitimate 4-px-drag zoom-out on a narrow strip).

### 13. D-13. Is the gesture / verb refused in a read-only buffer?
**Decision:** No. Neither the primitive nor the new `xschem graph_axis_zoom` verb is readonly-rejected.

**Why:** A range write is view state the engine has always been allowed to put in a read-only rect -- landmine 17 names the box zoom by name in exactly this list. The ASE viewer is read-only for its whole life and its MMB pan and RMB box zoom already write there. Rejecting would break the viewer's own gesture AND abort any replay of the logged line. This is the opposite of the marker verbs, and deliberately so: a marker is durable CONTENT, a zoom is not.

**Rejected:** Mirroring graph_marker's scheduler_readonly_reject; wrapping the viewer's release in wviewer::with_edit (a context switch plus four state writes on every mouse release, for a non-mutation).

### 14. D-14. Does it set the dirty flag or push a C undo point?
**Decision:** Neither.

**Why:** Landmine 19, re-verified today: the whole of waves_callback (callback.c:816-2196) contains zero set_modify(1) and zero push_undo(), and graph_fullxzoom/graph_fullyzoom contain no set_modify either. Copying the marker discipline here would dirty the read-only viewer buffer on every zoom.

**Rejected:** Copying the waveform-marker discipline (markers deliberately DO dirty and push undo, because they are content that would otherwise be lost on close with no prompt).

### 15. D-15. Does it push a viewer undo point (u/U)?
**Decision:** No.

**Why:** PLAN Q8. Window VIEW state -- plot mode, sharedx, cursors, the loaded raw, and the axis ranges the mouse writes -- is deliberately outside a wviewer::push_undo snapshot (waveform_viewer_modes.md 14.1). The existing zoom affordance, wviewer::wheel_zoom, pushes nothing either.

**Rejected:** Pushing an undo point (a `u` after a zoom would revert an unrelated model edit -- the exact surprise 14.1 was written to prevent).

### 16. D-16. Does it need capture_live_graph_state first?
**Decision:** No.

**Why:** PLAN Q12 said yes 'if it goes through any path that can regenerate'. A C-side gesture goes through NO regenerate. capture_live_graph_state (wave_viewer.tcl:2481) is what a LATER Tcl model mutation runs to fold C-written x1/x2/y1/y2 back out of the rects -- it exists BECAUSE C writes ranges behind the model's back. This gesture is one more producer for it, not a consumer. (Consequence, identical to MMB pan and RMB box zoom and stated in the spec: a plain window resize regenerates from the model and discards an axis zoom the model never saw.)

**Rejected:** Calling capture_live_graph_state from C (it is Tcl, and calling it would mean a context switch on a mouse release).

### 17. D-17. Does it log for replay?
**Decision:** Yes -- exactly one line per commit, emitted by graph_axis_zoom(): `xschem graph_axis_zoom <gi> x|y <lo> <hi>` at %.17g. Numeric bounds only, never pixels.

**Why:** PLAN Q9. There is precedent in C for logging a view change (`xschem pan` callback.c:2464, `xschem zoom_box` :2502), even though no graph gesture logs today. Logging the VERB form means the replay reproduces the whole propagation, and it gives the suite a free, exact, assertable seam -- the same relationship `graph_marker add_at` has to the `m` key.

**Rejected:** No logging (would match the box zoom, but throws away a replayable and assertable seam for nothing); logging the raw pixels (they do not exist at replay time).

### 18. D-18. Log-scale axes (logx / logy)?
**Decision:** Nothing special: run the whole map in `gr` space, which IS the axis's own log space when logx/logy is set. Do not read logx off the rect and do not apply pow(10,.).

**Why:** PLAN warned that setup_graph_data returns early before parsing logx. True in general (landmine 37a) but not applicable here, and following the warning would introduce a bug: the shipped box zoom writes dtoa(G_X(...)) straight into x1/x2 with NO pow(10,.) (callback.c:1630-1640, :2091-2093), while the cursor arms DO apply it (:1186) -- because cursor1_x is stored linear and x1/x2 are not. The map is therefore uniform in log space for free, and the off-screen case is caught by the gr->scx == 0.0 || gr->scy == 0.0 sentinel, which is landmine 37's own prescription for callers that need the transform.

**Rejected:** Reading logx from the rect and converting (would double-apply the log -- landmine 35's mistake arriving from the other side).

### 19. D-19. Digital strips?
**Decision:** Supported. X writes x1/x2 as usual; Y writes ypos1/ypos2 through DG_Y. graph_axis_at does NOT refuse digital.

**Why:** Mirrors callback.c:2151-2157 line for line -- the RMB left-margin arm already has exactly this branch. And because the digital legend occupies most of a digital strip's left margin, D-6's legend refusal already removes the Y region there without a special case.

**Rejected:** Copying graph_plotbox_at's blanket digital refusal (draw.c:5049) -- it would also lose the digital X axis, which has no conflict.

### 20. D-20. No raw loaded / empty strip?
**Decision:** Allowed. graph_axis_at does NOT require a loaded raw.

**Why:** It is a pure geometry question, and setup_graph_data produces a valid transform from the tokens alone (defaults gx1=0, gx2=1e-6, draw.c:3868-3876). Zooming an empty strip's axis is harmless and is what the arrow keys and `f` already permit. Copying graph_plotbox_at's raw gate (draw.c:5043) would make the whole region silently dead before the first simulation.

**Rejected:** Requiring a loaded raw, as graph_plotbox_at does; refusing an empty strip (PLAN did not ask this for item 03 but item 01 answered the analogous marker question the other way -- for a marker there is no sample to bind to, for a zoom there is nothing to bind to at all).

### 21. D-21. Where does the zoom FORMULA live?
**Decision:** In one function, graph_axis_map(), called by the release arm and exposed as `xschem get graph_axis_map <gi> x|y <p0> <p1>` so the suite drives it headlessly in both arms. A source-level leg (AS1) asserts it appears exactly once.

**Why:** The graph_marker_label_box doctrine -- one function owns one geometry -- and landmine 45(a): a feature whose feedback path and whose commit path each compute the same thing will drift, and no behavioural leg can see it while they still agree. Exposing it as a query is also what makes it possible to assert BOTH endpoints of a zoom-out numerically without replaying a Tk gesture.

**Rejected:** Computing the map inline in the release arm and again in the verb; asserting the maths only through a full press/motion/release gesture (DISPLAY-only, and it would leave the formula unassertable under --nogui).

### 22. D-22. How does the ASE viewer keep out of the way?
**Decision:** It ASKS C what the press armed -- a new wviewer::axis_grabbed reading `xschem get graph_axis_drag` -- and adds one rung to strip_drag_press. It does NOT hit-test the axis margins in Tcl.

**Why:** strip_drag_press already forwards the press to C unconditionally (wave_viewer.tcl:2965) and then consults C for the marker case (:2982). Copying that shape means there is no Tcl geometry to drift, and every corner case (cursor grabbed, grip column, legend entry, off-screen strip) keeps its current owner automatically, because C simply declines to arm. Contrast GRAPH_REORDER_HANDLE_W, which IS mirrored in Tcl and carries a permanent 'change both' warning.

**Rejected:** A Tcl wviewer::axis_at wrapper doing its own margin arithmetic (a second source of truth for the plot box -- the documented desync trap of section 8 of the subsystem reference).

### 23. D-23. Return shapes of the two new getters?
**Decision:** Both `xschem get graph_axis_at` and `xschem get graph_axis_drag` answer "" | x | y. Fail soft, never an error. The C-internal field stays an int enum (GRAPH_AXIS_NONE/_X/_Y).

**Why:** One vocabulary for the whole feature, and "" is the same 'nothing there' sentinel graph_marker_at already uses. The ASE viewer wraps these in catch and must read a missing or erroring verb as 'nothing there', never as 'locked out'.

**Rejected:** 0/1/2 integers to match graph_marker_drag's shape (would give one small feature two vocabularies, one per getter).

### 24. D-24. Which suite owns this?
**Decision:** A NEW suite, tests/headless/test_wave_axis_zoom.tcl, with a --logdir CHILD PROCESS for the action-log legs. No registration needed.

**Why:** No existing suite owns axis geometry, and test_wave_markers is already this batch's shared red-leg risk (items 01 and 02 both extend it). full_audit.sh auto-discovers test_*.tcl (:118), so a new file is picked up for free; logdir_tests registration is only for suites needing --logdir in the PARENT, and the child-process pattern (test_wave_markers.tcl:1767-1799) is the only honest way to assert a C self-logged line from a --nolog suite.

**Rejected:** Extending test_wave_viewer.tcl (its TD/SD groups own the LMB plot-BODY seam, not the margins); registering the new suite in full_audit.sh's logdir_tests (unnecessary given the child).

## PLAN.md claims refuted by source

- **Q5** -- 'a rubber-band preview drawn under draw_graph flags bit 16 (UI chrome), same transient rules as reorder_handle values 2/3/4'. REFUTED. The C-side live rubber for the RMB box zoom never goes near draw_graph: it is drawtemprect(xctx->gctiled | xctx->gc[SELLAYER], NOW, ...) at callback.c:1642-1681, with state in xctx->graph_rubber_x/y/active (xschem.h:1684-1685), and it writes no token. reorder_handle=2/3/4 is the TCL-driven feedback path -- Tcl rewrites the token on the two affected rects when the destination changes (waveform_viewer_modes.md 12.6). A C-owned drag has no Tcl in the loop, so bit 16 would mean a token write per motion event from a layer that is not running. Use drawtemprect; it also gets the erase bookkeeping and the !has_x no-op for free.
- **Q12** -- 'does it need capture_live_graph_state first? -> yes, if it goes through any path that can regenerate'. REFUTED for a C-side implementation, which reaches no regenerate at all. capture_live_graph_state (wave_viewer.tcl:2481) is what a LATER Tcl model mutation (move_strip, move_trace, delete_items) runs to fold C-written x1/x2/y1/y2/hilight_wave back out of the rects. It exists BECAUSE C writes ranges behind the model's back; this gesture is one more producer for it, not a consumer of it.
- **Q7** -- 'Beware: setup_graph_data returns early for an off-screen graph before parsing logx -- read the token off the rect.' TRUE IN GENERAL (landmine 37a) BUT NOT APPLICABLE, and following it would introduce a bug. gr->gx1/gx2/gy1/gy2 and therefore G_X/G_Y are ALREADY log-space when logx/logy is set: the shipped box-zoom arm writes dtoa(G_X(mx_double_save)) straight into x1/x2 with no pow(10,.) (callback.c:1630-1640, :2091-2093), while the cursor arms DO apply pow(10,.) (:1186) because cursor1_x is stored linear and x1/x2 are not. So the map is uniform in log space for free, and applying the conversion would double-convert. The off-screen case is correctly detected by gr->scx == 0.0 || gr->scy == 0.0, which is landmine 37's own prescription.
- **Q3** -- 'sharedx stacks: does an X zoom apply to one strip or all? -> all, since that is what sharedx means'. RIGHT ANSWER, WRONG MECHANISM. The C engine cannot see the viewer's sharedx. Propagation comes from the shipped participation test r->sel || (same_sim_type && !(r->flags & 2)) || i == graph_master (callback.c:2088), whose same_sim_type term additionally requires the MASTER rect not to be 'unlocked' (:1697-1702). wviewer::graph_props emits flags=graph and never unlocked (wave_viewer.tcl:1770), so in the viewer X already propagates to every strip of the same sim_type WHATEVER sharedx is set to -- exactly as MMB pan and RMB box zoom already do. sharedx only affects regenerate, which forces graph 0's stored range onto the others (:1840-1848).
- **Q2's collision list is INCOMPLETE** in the one direction that matters. (a) It omits the x/y CURSORS. Their grab tests have no plot-box confinement at all (callback.c:1240, :1250, :1269, :1288) and, decisively, the cursors are DRAWN in the margins: draw_cursor's line spans gr->ry1..gr->ry2 and its numeric readout label is placed at gr->ry2-1, i.e. in the bottom X-number margin (draw.c:4077, :4082); draw_hcursor's line spans rx1+10..rx2-10 and its label sits at gr->rx1+5, i.e. in the left Y-number margin (draw.c:4139, :4146). This is the collision that actually shapes the design (D-3). (b) It omits the VERTICAL and DIGITAL legends. PLAN says 'the top of the rect is the legend (legend_slot_hit starts at gr->ry1)' -- that is the HORIZONTAL layout only; vlegend slots are rx1+5 .. x1-5 (draw.c:4501-4502) and digital slots rx1 .. x1-20*txtsizelab (:4508-4509), i.e. the LEFT MARGIN (D-6). (c) Its note that 'waves_selected insets each strip by border = 5.0*tk_scaling*xctx->zoom and a press inside that seam never reaches the graph at all' is true but incomplete: the Button3 press/release arm hit-tests the FULL rect (callback.c:150-153), so the inset is LMB/motion-only.
- **Q1** -- 'Take the geometry from Graph_ctx, do not hardcode.' Correct in spirit, but the fields matter: use the plot box (gr->x1/x2/y1/y2) and the container (gr->rx1/ry1/rx2/ry2), NOT marginx/marginy. gr->x2 is rx2 - 0.35*marginx (not rx2 - marginx), and the top edge is one of three formulas depending on digital / vlegend (draw.c:4001-4005). Deriving the regions from the margin widths re-implements those special cases and will drift from the drawn box.
- **CONFIRMED, not refuted**, and worth recording because the whole design rests on it: 'Button3-drag XY box-zoom (issue 0142: interior drag zooms x1/x2 across participating graphs + y1/y2 on the master, with a live rubber rect via drawtemprect/gctiled; left-margin drag = Y-only)' is exactly right -- callback.c:2082-2126 and :2128-2160, including a digital branch writing ypos1/ypos2 through DG_Y. It is the closest precedent this item has.

## Sabotage

### SAB-1 invert the direction test in graph_axis_map (every drag treated as zoom-in)
- target: AM2, AM3, AM4, AM6, AG8
- failed exactly: **true**
- note: Killed exactly 11 legs: AM2 (lo, hi, 'really zoomed out'), AM3 (lo, hi), AM4 (lo, hi), AM6 (lo, hi, 'really zoomed out'), AG8 ('really zoomed OUT'). AM1, AM5, AM7-AM11, all AZ*, AV*, AL*, AS* stayed green. FIRST RUN also killed AM8, whose leg mixed the clamp question with an ordering assertion (hi > lo); AM8 was rewritten to ask only about finiteness and the bound (direction is AM2/AM4/AM6's job) and the sabotage re-run confirmed the corrected list. AG7/AG8's lo/hi legs correctly do NOT die: they assert the gesture commits what `xschem get graph_axis_map` answers, i.e. gesture-vs-verb consistency, and correctness is asserted against the Tcl closed form in AM*.

### SAB-2 drop the anchoring term in the zoom-out branch (zlo = A; width right, position wrong)
- target: AM2, AM4, AM6, AG8 -- and AM3 must stay GREEN
- failed exactly: **true**
- note: Killed exactly AM2 (lo, hi), AM4 (lo, hi), AM6 (lo, hi), AG8 ('really zoomed OUT'), plus the AS1 source leg that counts the expression it deletes. **AM3 stayed GREEN**, as the prompt requires -- a full-extent reverse drag has ub = 0, so the anchor term vanishes there. AM2's 'the reverse drag really ZOOMED OUT' leg also stayed green (the width is right), which is exactly the width-only-passes trap both endpoints exist to catch.

### SAB-3 widen graph_axis_at to answer x inside the plot box
- target: AZ1, AG3, AX4
- failed exactly: **true**
- note: Killed AZ1, AG3, AX4 (2 legs: 'a plot-BODY press still arms the strip reorder' and 'armed no axis drag') AND AZ10's 'the plot box is still not an axis region'. The extra kill is the SAME assertion in the no-raw fixture, i.e. a second witness of the one fact the sabotage breaks -- not a leg coupled to something else. Everything else stayed green.

### SAB-4 drop the participation loop from graph_axis_zoom (write only rect i)
- target: AV1, AG11's X half, AL4
- failed exactly: **true**
- note: FIRST RUN killed AV1 (2 legs) and AG11's X half but NOT AL4 -- AL4 was a pure CONSISTENCY leg (original child and replay child would agree that nothing propagated). A teeth leg was added ('the zoom really PROPAGATED to rect 1 in that child'), and the re-run killed exactly AV1 (2), AL4 (1) and AG11's X half (1). AV2-AV8, all AM*, all AZ* stayed green.

### SAB-5 arm the axis drag before the cursor grab (remove the !(graph_flags & (16|32|512|1024)) guard)
- target: AG6 only
- failed exactly: **true**
- note: Killed exactly one leg: 'AG6 a press on the y-cursor arms NO axis drag'. AG6's two companion legs (the cursor's pixel row was located; graph_flags & 512 really was set) stayed green, which is what stops the leg from passing when nothing happened at all. 172 of 173 passed.

### SAB-6 give the release arm its own inline copy of the map instead of calling graph_axis_map
- target: AS1 only
- failed exactly: **true**
- note: Killed exactly AS1's two callback.c legs ('callback.c carries NO copy of it' and 'graph_axis_map is CALLED from callback.c exactly once'). EVERY behavioural leg stayed green -- which is the point: a duplicated formula that still agrees today is invisible to behaviour and only a source-level tripwire can see it (landmine 45(a)).

## Verifier (fresh adversarial context, not the implementer)

- ok: **false**
- sabotage reproduced independently: true
- audit matches baseline: true
- audit detail: [object Object]

### Problems

HOLLOW SPOT, and it is on the item's own headline claim. `src/callback.c:1714` — the GRAPHPAN routing-latch term `|| xctx->graph_axis_drag` — has ZERO test coverage. I deleted it (leaving `(!xctx->graph_top || xctx->graph_marker_drag)`), rebuilt, and the suite printed `RESULT: ALL PASS (196 checks)`. That term is not decoration: the commit message headlines it as the first of 'TWO PROMPT CLAIMS SOURCE REFUTED', the decision doc's Status block calls it 'correction 1', the issue file records it in §3, and waveform_subsystem_reference.md's new landmine says 'One thing it DOES owe: the GRAPHPAN routing latch (landmine 36)'. I then PROVED by probe that it is load-bearing exactly as documented: fixture = one graph rect with a loaded raw and NO `node` token (so graph_legend_at claims nothing), press at the TOP-LEFT corner (`xschem get graph_axis_at 0 83 270` -> `y`, above the plot box so graph_top is already 1), drag+release LEFT of the rect (px=2) at 1/4 box height. CLEAN binary: `armed -> {y}`, `before=0 2.5 after=-7.5252641 2.5`, `COMMITTED = 1`. SABOTAGED binary, same script: `armed -> {y}`, `before=0 2.5 after=0 2.5`, `COMMITTED = 0`. So a real, reachable gesture silently stops committing and 196 checks stay green. (The AG/AX legs never see it because every one of them releases INSIDE the strip, where graph_master is still set and the release arrives without the latch — AG10's ESC probe and my first probe both committed under the sabotage for that reason.) Two aggravating factors: (a) this is precisely the line a future 'simplify the guard' pass will delete, which is what the sabotage discipline exists to prevent; (b) `callback.c:207`'s `if(!is_inside)` branch calls `graph_marker_drag_abort()` but NOT `graph_axis_drag_abort()` — today unreachable for an axis drag ONLY because this untested latch always fires, so the untested line is load-bearing twice. Fix is one leg: press in the top-left corner of a legend-less strip, release outside the rect, assert the window moved (my probe script is a ready-made recipe).

### Notes

(none)

## Repair stage report

Repair complete. Fixup commit `826e1b60` on `fluid-editing` (item 03's commit `6d401fee` left untouched).

### What changed

**Files (explicit stage list):** `src/callback.c`, `src/scheduler.c`, `src/xschem.h`, `tests/headless/test_wave_axis_zoom.tcl`, `doc/claude/code_analysis/ovb01_03_axis_region_drag_zoom_decision.md`, `doc/claude/code_analysis/waveform_subsystem_reference.md`, `doc/claude/issues/0190-axis-region-drag-zoom.md`, `doc/claude/specs/waveform_viewer_modes.md`. 420 insertions, 50 deletions.

**1. BLOCKING flake — fixed, and a second one found.** `tests/headless/test_wave_axis_zoom.tcl:1231` now sends ESC through a new `ax_send_key` (the `test_wave_markers` `send_key` shape: deiconify/raise, synthetic `<FocusIn>`, `focus -force` toplevel+widget, generate, retry, gated on the caller-scope predicate `[wviewer::axis_grabbed $::vdrw] == 0`), and a new leg asserts the return value so a swallowed probe cannot read as a pass. **Re-soaking exposed a second, independent flake the review did not see:** my own 12-run soak of the *pristine* suite went red once on `AX0` — `node -> {v_a v_a}`, `readonly -> 0` — which is the C context sitting on the main editor, not the viewer: every `xschem new_schematic switch $vdrw` in the AX group was unconfirmed and a stray `EnterNotify` during any `update` reverted it. All nine switch sites now go through `ax_ctx`, which confirms `current_win_path` and retries. Post-fix soak: **30/30 `ALL PASS (196 checks)`** via `run_suites.sh -n 30`.

**2. Threshold duplication — one home.** `callback.c` gained `double graph_click_tol(void)` (declared in `xschem.h`); `scheduler.c:3966` now passes `graph_click_tol()` instead of the literal `3.0`. The `#define` stays file-private (landmine 20 — `AS2` still asserts it). New `AS3` (5 legs) counts the seam; `AM7`/`AM8` now take their boundary pixels from the `#define` parsed out of `callback.c` by the new `az_define`, so a value disagreement is behaviourally visible.

**3. D-9 deviation — recorded.** Decision-doc Status now says "**Three** corrections", correction 3 states the code is right and the row was wrong (`p0`/`p1` are pixels; PLAN Q4 says "3 screen px"), and the D-9 row itself is rewritten. Issue file gained §3 item 3 and a §3.1 "Post-review repair". The two-spaces hazard is named at the `#define`, at the accessor, at `callback.c:1851` (the call site), in spec §17's threshold row, and in `waveform_subsystem_reference.md` landmine 20.

**4. Coverage gap — closed.** New `AG13` drives press→arm→release on **strip 1**: the Y half is decisive (Y never propagates, so "rect 1 moved, rect 0 did not" can only mean the arm followed the pressed strip); the X half asserts rect 0 follows off a non-zero master.

**5. Minor — fixed.** Both tunables are read from source (`az_define`); `AM8`'s bound is `R * $az_maxf`; new `AM12` makes the clamp **actually bind** (a graph rect sized off the live zoom so the plot box is ~32 000 px wide → unclamped factor ≈ 8110×) and asserts the span equals `R * GRAPH_AXIS_ZOOM_MAX_FACTOR` on both sides. Before this leg the clamp line was never executed by any test.

### What I ran

- Sabotage-verify, 4 named, each failing **exactly** its target: getter gets its own literal `6.0` → 7 red (AM7×2, AM8×2, AM12, AS3×2); delete the clamp in `draw.c` → **1** red (AM12 only — AM8 alone was blind to it, confirming the review's point); `graph_axis_draggraph = 0` → **1** red (AG13's Y commit); viewer stops forwarding ESC → **3** red (all AX7, proving the retry loop is not a tautology). Reverts were byte-identical restores from scratch-dir backups verified with `cmp`, not `git checkout` — the tree held live repair work on three of those files.
- Suite: `196` checks display / `128` `--nogui` (was 173/119). 30/30 soak.
- `GUI_GATE=0 tests/headless/full_audit.sh` on the final binary: **`SUMMARY: 260 pass  12 fail  0 crash/timeout  0 skip (total 272)`, `WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)`**; `test_wave_axis_zoom` PASS.
- Tracked-dirty set after

## What the tests structurally CANNOT see (eyeball list)

- The rubber band's PIXELS. The motion branch in callback.c:1826 does execute during AG7/AG8/AG13 (ag_gesture sends two Button1Mask MotionNotify events), so it is crash-tested — but no check can see that the band spans the plot box across the un-dragged axis, that the previous outline is erased cleanly by the gctiled pass, or that it is painted in gc[SELLAYER]. Delete every drawtemprect call in that branch and the suite stays green.
- The band's ABSENCE after a commit or an ESC: graph_rubber_active is reset but no check reads the canvas, so a band left painted on screen is invisible to the suite.
- Drag FEEL: whether 3 screen px is the right click-vs-drag travel for a margin gesture (it is compared in pixels here but in world units at callback.c:710/1047 — the two spaces now differ inside one file), and whether a 4-px reverse drag's zoom-out rate is comfortable.
- Tick-label legibility after a zoom — whether the resulting divx/divy produce readable, non-overlapping axis numbers.
- The deliberate ABSENCE of a pointer-cursor change during an axis drag (the strip reorder sets sb_v_double_arrow, the trace drag sets hand2, this sets nothing). Deliberate, unverifiable, and possibly wrong for the user.
- Whether losing the two axis margins from the ASE viewer's strip drag-reorder is noticeable in use. AX4/AX5 prove the reorder still arms on the body and on the grip; nothing proves the remaining grab area feels sufficient.
- That a schematic-embedded graph looks right after an axis zoom — AG* asserts tokens through `xschem callback`, never pixels.
- The GRAPHPAN latch term at callback.c:1714 is NOT on this list — I proved it IS assertable (see problems[0]). It is simply not asserted.

## Tunable constants (for the eyeball pass)

- `src/xschem.h:GRAPH_AXIS_ZOOM_MAX_FACTOR=1000.0` -- the cap on how far ONE reverse drag may zoom out. It is a backstop against 1/0, not a policy: the 3-px click threshold normally binds first (max factor ~ plot_width/3, i.e. ~160 on a 488-px box). Lower it if a 4-px reverse drag on a wide strip feels like it throws the window away.
- `src/callback.c:GRAPH_CLICK_TOL=3.0` -- reused UNCHANGED as the axis drag's travel threshold, but here it is compared in SCREEN PIXELS (the map's p0/p1 are pixels) rather than in world units as the wave-bold click does. 3 px may be too twitchy for a margin gesture; it is passed into graph_axis_map() as a parameter, so raising it for the axis drag alone is a one-line change that does not touch the click/bold path.
- `src/draw.c:graph_axis_map hi==lo guard=1e-6` -- the shipped box-zoom idiom, copied verbatim.

## Implementer summary

Item 03 implemented in full and committed as 6d401fee. An LMB press-drag in a waveform strip's bottom (X-number) or left (Y-number) axis margin now zooms that axis only; forward = zoom in to exactly the press/release data coordinates, reverse = the anchored zoom-out R2 = R/|s|, lo = A - ub*R2.

SHAPE (as decided, not re-litigated): three new draw.c functions -- graph_axis_at() (which margin a canvas pixel is in), graph_axis_map() (THE formula, one home) and graph_axis_zoom() (THE apply, shared by the gesture and by the new replayable verb). callback.c arms at the END of the cursor-grab block, paints a drawtemprect band on motion beside the Button3 rubber, and commits on the release; abort_operation() drops it on ESC. Three fail-soft getters (graph_axis_at / graph_axis_map / graph_axis_drag) in xschem_cmds_g's get case 'g', one fail-loud top-level verb `xschem graph_axis_zoom` in the same function, NOT readonly-rejected (D-13). wave_viewer.tcl gained exactly one 6-line proc (wviewer::axis_grabbed) and one rung in strip_drag_press -- no geometry, no with_edit. No set_modify, no push_undo, no wviewer::push_undo, no capture_live_graph_state. XSCHEM_FILE_VERSION untouched; nothing MIRRORED IN TCL added.

TWO PROMPT CLAIMS SOURCE REFUTED (both measured, both recorded in the issue file §3 and in the decision doc's Status block):
1. The GRAPHPAN latch DID need `|| xctx->graph_axis_drag`. The prompt said to verify it needed no change. It does: graph_axis_at's Y region is "left of the plot box, anywhere in the container", so a press in the TOP-LEFT corner of a strip owning no legend entry there (legend=0, or no `node` token yet) arms a Y drag with graph_top already 1, and landmine 36 then eats the release silently.
2. graph_axis_zoom() must read `digital` straight off the rect with get_tok_value, NOT from a scratch Graph_ctx as the decision doc §3.2 implied -- setup_graph_data parses `digital` below its off-screen early return (landmine 37a), so an off-screen digital strip answered 0 and the Y write landed in y1/y2. Caught red by the AV5 leg.

OTHER ANCHOR NOTES: the prompt's `finish:` line number was off by ~40 and the cursor-grab block ends at :1292 not :1291; graph_axis_at must use gr->sx1..sy2 for the container (the prompt wrote S_X(rx1..rx2), which mixes graph space with xschem space); drawtemprect takes XSCHEM coordinates, so the band helper converts the stored screen press position. All other anchors re-verified and correct.

TESTS: new suite tests/headless/test_wave_axis_zoom.tcl, auto-discovered by full_audit.sh (confirmed at :118, `ls test_*.tcl` -- no logdir_tests registration needed, the log leg spawns its own --logdir child). 173 checks with a display, 119 under --nogui, both ALL PASS. Groups AZ (region query incl. no-raw, digital, vlegend, grip, corner), AM (the map, every expectation computed in Tcl from the closed form with `xschem graph_coord` as an independent pixel->data transform), AV (the apply, witnessing EVERY rect), AL (the log line + a replay in a second child), AS (source-level one-formula-one-home tripwire), AG (the real C gesture), AX (the ASE viewer seam through the shipped bindings, with an inert sdid strip witness). Every pixel is scanned from the engine's own answers (graph_plotbox_at + the engine's zoom/origin, and wviewer::strip_bands_px in the viewer), never predicted from 0.14*rh, and re-scanned after anything that zooms.

SABOTAGE: all six named sabotages applied, built, run, reverted from byte-identical pristine copies (verified with diff -q, since the feature itself is uncommitted at that point so `git checkout` would have wiped it), rebuilt and re-run green. Two of them found real test defects, which were fixed and the sabotages re-run: AM8 was mixing the clamp question with a direction assertion (SAB-1), and AL4 was a pure consistency leg blind to SAB-4 until a propagation teeth leg was added. SAB-2 leaves AM3 green exactly as required.

SUITES: baseline before any edit -- test_wave_viewer 368, test_wave_modes 433, test_wave_markers 979, test_wave_trace_menu 323, test_wave_snap 90, all ALL PASS (note: PREFLIGHT recorded test_wave_markers RED at MF1; it was GREEN at 979 on this machine today, both before and after). After: those five plus test_wave_legend 77, test_wave_clear_all 75, test_wave_grid 80, test_wave_drag_preview 46, test_wave_split_strip 221, test_wave_empty_strips 98 -- 11/11 PASS.

FULL AUDIT: `SUMMARY: 244 pass 17 fail 2 crash/timeout 9 skip (total 272)` (+1 total = the new suite), WIREEDIT PASS, SCRATCH 0 leaked. Against PREFLIGHT's 20-name list, 14 of the 20 still fail, SIX went green on their own (test_ase_unnamed_net, test_deselect_mode, test_nh_anim_rearm, test_pristine_untitled_viewer_0172, test_readonly_action_dispatch, test_verb_noun_copy_move, test_wave_markers), and FIVE non-baseline suites failed. All five were re-run standalone and ALL FIVE PASS -- the audit run hit a WSLg window-sizing event (test_launch_context's first leg reports geom=1x1+0+0), which is the documented whole-run-poisoning class. test_graph_context is red with the same five wheel/key legs as baseline and test_key_graph_context still TIMEOUTs: neither got worse, and an LMB arm should not touch them.

PRE-EXISTING DEFECTS NOTICED, NOT FIXED (out of scope): `xschem graph_coord` (scheduler.c) still lacks the landmine-37 graph_flags & (128|256) bracket; the four cursor-grab tolerances in waves_callback are `< 10` in XSCHEM UNITS, not screen pixels (~37 screen px at viewer zoom -- the same class landmine 44 fixed for the waves_selected border, and the reason D-3 was designed to be correct either way); find_closest_wave's two open extra_rawfile defects (landmine 40).

# Remediation (gap closed)

- **fixup commit:** `33e3512b8c31c3779d5582d3e24abc29cfe9a36d`
- **files:**
  - `/home/qflow/dev/xschem/claude_1/xschem/src/callback.c`
  - `/home/qflow/dev/xschem/claude_1/xschem/tests/headless/test_wave_axis_zoom.tcl`
  - `/home/qflow/dev/xschem/claude_1/xschem/doc/claude/code_analysis/ovb01_03_axis_region_drag_zoom_decision.md`
  - `/home/qflow/dev/xschem/claude_1/xschem/doc/claude/code_analysis/waveform_subsystem_reference.md`
  - `/home/qflow/dev/xschem/claude_1/xschem/doc/claude/issues/0190-axis-region-drag-zoom.md`
- **checks:** 361 (was 338)
- **new legs:**
  - AG14 the legend-less third strip scanned: band=... box=... press=(...) release=(...)
  - AG14 that strip really owns no legend entry at the corner (teeth: with a `node` token the horizontal legend claims the whole top band and this is {})
  - AG14 the TOP-LEFT corner is the strip's Y region
  - AG14 ...and it is ABOVE the plot box, so the press latches graph_top = 1 (press y=..., plot-box top=...)
  - AG14 the release pixel is LEFT of the container band, i.e. OUTSIDE the strip (... < ...)
  - AG14 ...and no strip of the fixture claims it
  - AG14 the corner press arms the Y axis drag
  - AG14 ...and it LATCHED GRAPHPAN even though graph_top is already 1 -- THE ROUTING-LATCH TERM ITSELF (ui_state=..., bit 15)
  - AG14 a release OUTSIDE the strip still COMMITTED the map's lo (map=... got=...)
  - AG14 ...and its hi
  - AG14 ...and it really zoomed OUT (y1 went negative)
  - AG14 ...and the arm is back to nothing
  - AG14 ...and the other two strips are byte-identical (Y never propagates)
  - AG15 the staging pixel is strip 2's left margin (teeth)
  - AG15 ...and the body pixel is NOT an axis region (teeth)
  - AG15 the margin press armed the Y axis drag (teeth)
  - AG15 ...and latched GRAPHPAN (teeth)
  - AG15 the Shift+B1 motion really took waves_selected's SKIP route -- GRAPHPAN is gone, so the !is_inside branch ran (teeth)
  - AG15 ...and the ABANDONED axis arm went with it
  - AG15 the release after the abandon commits nothing
  - AG15 a following PLOT-BODY press arms nothing (a stale arm would still read `y` here)
  - AG15 ...and the plot-BODY drag commits NO zoom on any strip (before the abort it committed the abandoned press's)
  - AG15 ...and none of it dirtied the buffer

## The hollow spot, closed

- **sabotage:** `src/callback.c`, the GRAPHPAN routing latch:
  `(!xctx->graph_top || xctx->graph_marker_drag || xctx->graph_axis_drag)` -> `(!xctx->graph_top || xctx->graph_marker_drag)`
  (delete the `|| xctx->graph_axis_drag` term). Applied to the committed source, rebuilt, suite re-run;
  `git diff src/callback.c` then showed ONLY that one-line change and it was reverted with
  `git checkout -- src/callback.c`, rebuilt, green.
- **checks it killed BEFORE the remediation:** 0 (this is why the item was `[F]`)
- **checks it kills NOW:**
  - `AG14 ...and it LATCHED GRAPHPAN even though graph_top is already 1 -- THE ROUTING-LATCH TERM ITSELF (ui_state=0, bit 15) -> {0} (exp {1})`
  - `AG14 a release OUTSIDE the strip still COMMITTED the map's lo (map=-7.3510193812043632 2.5000000000000089 got=0 2.5) -> {0} (exp {1})`
  - `AG14 ...and it really zoomed OUT (y1 went negative) -> {0} (exp {1})`
- **clean re-run green:** true

## Verifier (fresh adversarial context)

- ok: true
- **hollow spot closed, reproduced by the verifier itself: true**
- audit matches baseline: undefined
- problems: (none)
- notes: (none)

## What the tests still structurally CANNOT see

- The rubber band's PIXELS during an axis drag: that it spans the plot box across the un-dragged axis, that `gc[SELLAYER]` is the colour, and that the `gctiled` pass erases the previous outline cleanly. No check reads the canvas. Unchanged by this repair.
- The band's ABSENCE after a commit or an ESC — `graph_rubber_active` is reset but nothing samples pixels.
- INTRODUCED BY THIS REPAIR, and I confirmed it in source: `graph_axis_drag_abort()` clears `graph_rubber_active` WITHOUT erasing an already-painted band (unlike the release path at `callback.c:1917`, which calls `drawtemprect(gctiled)` first). The new call site in `waves_selected()`'s `!is_inside` branch has no guaranteed redraw of its own. AG15 proves the STATE is dropped; nothing proves a stale outline is not left on screen until the next full redraw. In the measured path the schematic canvas immediately paints its own selection rectangle, so it was not visible — but that is an eyeball, not a check.
- Drag FEEL: whether 3 screen px is the right click-vs-drag travel for a margin gesture, and whether the anchored zoom-out rate of a short reverse drag is comfortable.
- Tick-label legibility after a zoom (the resulting `divx`/`divy`).
- The deliberate ABSENCE of a pointer-cursor change while an axis drag is armed.
- DISCOVERABILITY: the axis-number margins carry no hover affordance, so nothing tells a user the gesture exists. No check can reach that.
- Whether losing the two axis margins from the ASE viewer's strip drag-reorder seam is noticeable in use.
- That a schematic-EMBEDDED graph looks right after an axis zoom — AG*/AX* assert tokens and numbers, never pixels.

## Remediation summary

MANDATE MET. Deleting `|| xctx->graph_axis_drag` from the GRAPHPAN routing latch (`src/callback.c:1777`) now takes `tests/headless/test_wave_axis_zoom.tcl` RED — 3 failed / 358 passed, exit 1, all three named legs in the new AG14 group. It killed 0 before.

THE LEG. AG14 needed both halves of the disagreement the verifier identified, because every pre-existing AG*/AX* leg releases INSIDE the strip, where `waves_selected`'s POINTINSIDE arm re-finds the graph on its own and the latched and un-latched engines behave identically. (a) `graph_top` must ALREADY be 1 at the press or the latch fires on its `!graph_top` term regardless — so the press is in the TOP-LEFT corner, which `graph_axis_at` calls Y ("left of the plot box, ANYWHERE in the container") and which sits above the box. That only answers `y` on a strip owning no legend entry there, so the AG fixture grew a THIRD graph rect with NO `node` token (with one, `legend_slot_hit`'s horizontal slot 0 spans `rx1+2..rx1+rw/n` across the whole top band); a teeth leg asserts `graph_legend_at 2 px py` is -1. (b) The release must LEAVE the strip so nothing but the latch can route it back: left of the container band, at 1/4 of the plot box's height, with a teeth leg asserting no strip of the fixture claims that pixel. AG14 then asserts `ui_state & 32768` immediately after the press (the term itself), the committed lo against `xschem get graph_axis_map`, and that y1 really went negative. Clean `0 2.5` -> `-7.519 2.5`; sabotaged `0 2.5` -> `0 2.5`. Worth recording: the "...and its hi" leg does NOT die (the map's hi is 2.5 and the untouched y2 is 2.5 too), which is why the lo endpoint and the zoomed-OUT leg carry the assertion.

THE SECONDARY: FIXED, NOT RECORDED — because it is one line AND witnessable, and because probing it turned up a real, user-reachable defect. The verifier said the `if(!is_inside)` branch is unreachable for an axis drag "only because this untested latch always fires". That is true of the GEOMETRY route, but every `skip = 1` clause in `waves_selected` jumps the rect loop entirely, leaving `is_inside` 0 with GRAPHPAN still set. Measured on the shipped binary: press LMB in a margin (Y drag armed) -> add Shift mid-drag (`MotionNotify && Button1Mask && ShiftMask` skips) -> the branch clears GRAPHPAN and aborts the marker drag but LEAVES THE AXIS ARM UP -> the release is swallowed by the same skip -> `graph_axis_press_arm()` returns early rather than clearing when the next press is not in a margin -> a following plain LMB press-drag in the PLOT BODY, which owns no axis gesture at all, COMMITTED A ZOOM from the abandoned press position: y1/y2 `0..2.5` -> `1.2537228..2.3920389`. Fix: `graph_axis_drag_abort();` beside `graph_marker_drag_abort();`. AG15 drives the whole sequence with NO ESC anywhere (`abort_operation()` would mask it), with GRAPHPAN-is-gone as its teeth that the branch really ran. Second sabotage (delete that one line) kills exactly 3 AG15 legs, including the body-drag commit at `1.26..2.24`.

SUITE: 361 checks with a display / 200 `--nogui` (was 338 / 188-equivalent; both new groups are DISPLAY-only). Green on 3/3 re-runs after the acceptance revert, and 6/6 + nogui before the commit. All 12 wave suites green standalone on the final binary: test_wave_viewer 368, test_wave_modes 433, test_wave_markers 979, test_wave_trace_menu 323, test_wave_snap 90, test_wave_legend 77, test_wave_clear_all 75, test_wave_grid 80, test_wave_drag_preview 46, test_wave_split_strip 221, test_wave_empty_strips 98, test_wave_axis_zoom 361.

FULL AUDIT (`GUI_GATE=0`): `SUMMARY: 242 pass 17 fail 0 crash/timeout 13 skip (total 272)`; WIREEDIT: PASS; SCRATCH: 0 leaked dir(s); test_wave_axis_zoom PASS. Against PLAN.md's PREFLIGHT contract (239/20/1/11 of 271): 13 of the 20 baseline names still fail, SEVEN went green on their own (test_deselect_mode, test_nh_anim_rearm, test_pristine_untitled_viewer_0172, test_readonly_action_dispatch, test_rotate_stretch_short_0104, test_verb_noun_copy_move, test_wave_markers) and the baseline TIMEOUT test_key_graph_context no longer times out. Four non-baseline fails, all re-run standalone and all PASS — see nonBaselineFails.

DOCS: decision-doc Status block rewritten (correction 1 is now WATCHED, second repair named) plus two new invariants (18, 19) in §7; issue file §3.2 records the closed gap, the probe-placement reason the old legs were blind, the measured defect and both sabotage kill lists; `waveform_subsystem_reference.md`'s axis-drag landmine gained the two ⚠⚠ paragraphs — "this term is almost untestable by accident, here is the only probe placement that sees it" and "the same line is load-bearing twice, and the second job hid a real bug".

TREE: fixup commit `33e3512b`, explicit 5-file stage list, no push. The only dirty tracked files are the two PREFLIGHT-recorded ones. No untracked scratch/log dir was touched.
