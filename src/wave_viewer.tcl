# wave_viewer.tcl — standalone Waveform Viewer window shell (item 11 of
# doc/claude/ase_l_batch; authoritative contract
# doc/claude/specs/waveform_viewer.md). One viewer window per ASE session
# token ("lib/cell/view", ase::session_key), raise-or-open.
#
# The viewer IS a real xschem editor window created through the
# create_new_window path (`xschem load_new_window -window {}` -> untitled
# buffer in a fresh .xN toplevel), so the C graph engine draws the graph
# rects natively. What makes it a VIEWER:
#   - D1 no-save mechanism = the per-window readonly flag, held for the
#     window's life: actions.c ro_suppress makes `modified` unsettable ->
#     no dirty-save prompt can ever appear (save key quietly skipped).
#     Programmatic mutations go through wviewer::with_edit, which drops
#     readonly, runs the script, clears modified BEFORE restoring readonly,
#     and brackets everything with `set autosave_backup 0` (write_backup DOES
#     back up untitled buffers since issue 0060 — without the bracket a
#     mutation writes untitled-N~.sch into the cwd).
#   - D2 strip = readonly enforcement (quiet core backstop) + a per-window
#     binding SWEEP + filter on THIS window's .drw only: strip_bindings
#     first clears EVERY sequence bound on the canvas except the
#     non-input infrastructure keep-set (more-specific Tk binds pre-empt
#     the generic filter, so user-rc binds cloned by clone_canvas_bindings
#     — e.g. cadence_style_rc `bind .drw <Key-i>` — and set_bindings'
#     Windows-only per-widget Alt/Mod4 arms would otherwise reach editor
#     verbs and their readonly modal), then installs wviewer::key_filter
#     as the generic <KeyPress>/<KeyRelease> handler (allowlist:
#     Escape always; arrows = graph pan (0149); the waves_callback key set only over a graph;
#     Ctrl-W = close; everything else silently swallowed — readonly alone
#     would pop the readonly_block MODAL on every editing key). Button-3 is
#     forwarded only over a graph (kills the schematic context menu, keeps
#     the C engine's graph pan/zoom), double-clicks are swallowed entirely
#     (D9: dbl-click would open graph_edit_properties whose writeback is
#     readonly-rejected; Axes editing is item 12). Button-2 (the canvas PAN
#     gesture) and Shift/Alt+Button-1 are swallowed outright — issue 0149, the
#     graphs OWN the window, no gesture may scroll the canvas. Per-widget binds provably
#     cannot affect other windows. The editor TOOLBAR (the mouse-reachable
#     editing surface pack_widgets shows on every new window) is
#     pack-forgotten per-window in open — see the D2 fixup comment there.
#   - D6 title `Waveforms <design cell> (<state view>)`, re-asserted after
#     every readonly toggle (`xschem set readonly` rewrites the wm title via
#     set_modify(-1)) and on FocusIn. ⚠ A CONTEXT SWITCH INTO THIS WINDOW
#     clobbers the title the same way and for the same reason: the C
#     switch_window (xinit.c) also ends in set_modify(-1), and this buffer is a
#     nameless untitled one, so the title becomes
#     `xschem [N] - untitled.sch (read-only)`. FocusIn was the ONLY repair, so
#     the damage survived until the pointer happened to enter the window
#     (issue 0173 -- the reported "hovering over the viewer fixes the title").
#     Hence wviewer::enter_ctx/leave_ctx: switching into a viewer is a LOAN,
#     verified both ways, and the restore re-asserts this title.
#   - D7 menubar: a NEW menu $top.wvmenubar replaces the editor menubar on
#     this toplevel only; the detached editor $top.menubar widget stays ALIVE
#     (set_modify's catch-guarded entryconfigure calls keep resolving).
#   - D5 window number: the C-assigned editor number (shared counter); the
#     editor FocusIn -> switch_window -> notify_window_active path already
#     logs activation — no explicit notify call here.
#   - D10 ESC is FORWARDED to the C callback (abort pending op + redraw) —
#     it never closes the window.
#
# ---- item 12 (viewer core) ------------------------------------------------
# Trace/graph MODEL (D7): wviewer::layouts maps the session token to
# {sharedx 0|1 graphs {G ...}}; each G = {traces {{expr E name N color C
# vec V} ...} logx . logy . x1 . x2 . y1 . y2 .} ({} range = auto; `height`
# deferred). The model is the SINGLE SOURCE OF TRUTH: wviewer::regenerate
# clears the canvas and recreates every graph rect from it (one honest
# direction, no two-way sync). The one sanctioned reverse write is View >
# Fit (D6): engine fullx/fullyzoom computes the data ranges into the rect
# attrs and fit reads them back into the model like a user edit. Pure
# helpers (headless-checkable, no xschem/Tk calls): graph_props (model ->
# rect prop string, add_graph template order), band_geometry (item 18: equal
# viewport bands, replacing the old fixed graph_geometry slots),
# next_color (D10 palette cycle), validate_rpn (D4 — the C RPN
# evaluator DISCARDS errors, save.c raw_add_vector, so expressions are
# pre-validated Tcl-side against the save.c token table).
# Graph menu (D3/D5/D11/D13): Add Graph, Add Trace... (expression entry +
# raw-vars listbox; RPN exprs materialize as raw vectors via `xschem raw
# add`, D5), Delete... (listbox of graphs+traces — the BULK path; per-trace
# selection is a click, see below), Axes... (ranges + log
# toggles), Shared X Axis.
# ⚠ CORRECTED 2026-07-30 (issue 0175). The old wording here and in
# delete_dialog said "canvas legend click-select has no C hit-test API
# (receipts/11: rect descriptors carry no coordinates)". That was wrong even
# when it was written: the hit test shipped, fused into the ACTION of
# draw.c's edit_wave_attributes() and reachable only from a Button3 press on
# the legend. Issue 0175 extracted it as a pure query, `graph_legend_at`
# (`xschem get graph_legend_at <gi> <px> <py>` -> NODE index or -1, wrapped
# here by wviewer::legend_at), and put an LMB arm on it. Clicking a legend
# entry now selects that trace; Ctrl+click adds/removes it. The Delete
# listbox stays as the bulk path. All dialogs = ase::ui scaffold (ESC-cancel by
# construction) + ase theme.
# Cursors menu (D1/D2/D8/D9): Cursor A/B drive the ENGINE x-cursors
# (`xschem cursor 1|2`, graph_flags bits 2/4, drawn by plain redraw);
# readout = bottom bar with x + per-trace y per enabled cursor,
# eng-formatted via ase::format_value; y interpolated by
# wviewer::interp_value, a Tcl mirror of the C interpolate_yval
# (callback.c) used uniformly for BOTH cursors (the engine only
# interpolates for B). Cursor state is MIRRORED per-window in Tcl (D8):
# there is no `xschem get graph_flags` getter, so the menu checkbutton
# vars are authoritative and key_filter flips them when it forwards a/b
# over a graph.
#
# Graph display seam (D12, reshaped from item 11): wviewer::display_raw is
# a thin model wrapper — ensure graph 0, append the trace, `xschem raw
# read`, regenerate. Honest assertability: raw points/vars/sim_type,
# layer-2 rect count/props, redraw rc, modified-still-0 — actual pixel
# rendering is eyeball-only.
#
# Persistence (item 14): wviewer::snapshot / wviewer::restore serialize the
# layout into / rebuild it from the ASE state's `viewer` key — contract in
# doc/claude/specs/waveform_viewer.md "Item 14 notes (as shipped)".
#
# ---- issue 0151 (plot modes) ----------------------------------------------
# Contract: doc/claude/specs/waveform_viewer_modes.md. Each viewer window
# carries a PLOT MODE (single|multi) and a TARGET STRIP. Signals sent from
# the schematic (Direct Plot / Ctrl-4) land per the mode: single = all of
# them appended into the target strip; multi = one NEW strip per signal,
# appended after the existing stack. The policy itself is the PURE proc
# wviewer::plan_plot; wviewer::plot_signals applies it. Mode + target are
# per-window (arrays keyed by session token, the `sharedx` mirror shape),
# seeded from the config var `wviewer_plot_mode` at open time, persisted in
# the ASE state `viewer` dict, changed by Options > Plot Mode, the Tcl
# commands (plot_mode / set_plot_mode / target_strip / set_target_strip) or
# a canvas click, and logged replayably through wviewer::log_action. When
# more than one strip is up, the target rect carries an `active=1` prop
# token and the C engine paints a dull-yellow bar at its right edge
# (draw.c, gated on draw_graph's on-screen flags bit 16).
#
# ---- issue 0171 (Clear All / Ctrl-D) ---------------------------------------
# `wviewer::clear_all ?token?` deletes every graph and every trace of a viewer
# window and leaves ONE empty strip — "start from scratch". Window OPTIONS are
# deliberately kept: the plot mode (single|multi), Shared X, the cursor mirrors
# and the ATTACHED RAW DATA all survive, so the next pick plots without a
# re-run. The default key is Ctrl-D, bound on the shared `WaveViewer` BINDTAG
# (wviewer::install_default_binds) rather than on the canvas widget, because
# strip_bindings sweeps every widget-level sequence and an rc file must be able
# to remap the key BEFORE any viewer window exists:
#   bind WaveViewer <Control-Key-d> {break}                      ;# drop default
#   bind WaveViewer <Control-Key-r> {wviewer::clear_all_at %W; break}
# The action is logged replayably through the same log_action seam as the mode
# and target commands.
#
# ---- Delete All Markers / Ctrl-E (viewer plan item 4) ----------------------
# `wviewer::delete_all_markers ?token?` removes every waveform marker from
# every strip of a viewer window (doc/claude/specs/graph_markers.md). The
# graphs, the traces and the ranges all survive — this deletes ANNOTATION, not
# content, which is exactly what makes it a different verb from Clear All.
# Default key Ctrl-E on the same `WaveViewer` BINDTAG, remappable the same way.
# One `wviewer::delete_all_markers <token>` log line and nothing else: the C
# core self-logs `xschem graph_marker delete -all -1`, which is NOT replayable
# into a viewer (the arm is readonly-rejected and a sourced log would ABORT on
# the TCL_ERROR), so the C line is suppressed for the duration of the call.
#
# ---- strip drag-to-reorder (2026-07-27) ------------------------------------
# Contract: doc/claude/specs/waveform_viewer_modes.md §12. LMB drags a whole
# STRIP (one graph dict of `layouts` — traces, colors, axes and any `auto 1`
# marker) up or down the stack; the traces INSIDE it never change order. Two
# grab surfaces: the 14-screen-pixel reorder HANDLE at the strip's right edge
# (the C engine draws a grip there from the `reorder_handle` prop token) and
# EMPTY waveform body. A fixed 10-screen-pixel zone around every trace, and any
# press that grabbed a cursor, stay with the C engine — cursor drags, trace
# picking and the wave-bold click are untouched (that seam is reserved for
# future LMB trace-to-strip dragging). >3 px of vertical travel starts the drag,
# crossing another strip's midpoint picks it, release commits, Escape cancels; a
# sub-threshold click and a drop back at the origin do nothing and log nothing.
# The model side is PURE (`reorder_graphs`, `reordered_index`) under ONE
# authoritative mutation, `move_strip`, which first folds the live C-written
# rect state back into the model (`capture_live_graph_state`) so the regenerate
# cannot undo a pan/zoom/bold, remaps the target by IDENTITY, regenerates once
# and writes one replayable line.
# THE GRAPH PAN MOVED FROM LMB TO MMB to make room (callback.c, engine-wide);
# in this window MMB is forwarded by `btn2_filter` instead of swallowed, and it
# still cannot reach the schematic canvas pan (issue 0149's invariant holds).
# Two read-only C verbs back the seam: `xschem get graph_near_wave` (real
# screen-pixel distance to a drawn trace) and `xschem get graph_flags`.
#
# ---- trace drag BETWEEN strips (2026-07-28) --------------------------------
# Contract: doc/claude/specs/waveform_viewer_modes.md §13. The other half of the
# LMB seam: press ON a trace (the 10-px zone the strip reorder refuses), drag,
# release over another strip -> the trace MOVES there, keeping its expression,
# alias, vector and color, and landing at the END of the destination's list. The
# pointer becomes the GRAB HAND (`hand2`) on the press, the destination strip is
# framed while the pointer is over it (`reorder_handle=4`), >3 px of travel in
# either axis starts the drag, and a drop on the source strip / outside every
# strip / a sub-threshold click all commit nothing and log nothing — so the
# issue-0152 wave-bold click still works exactly as before. A press that grabbed
# a CURSOR still wins over the trace grab (a cursor can be parked on a trace).
# Model side is PURE (`node_index_of_trace` / `trace_index_of_node` /
# `node_count` / `remap_hilight_after_trace_move` / `move_trace_in_graphs`) under
# ONE authoritative mutation, `move_trace`, which follows move_strip's ordering
# contract exactly (capture live state -> mutate -> one regenerate -> one log
# line). The source strip stays even when it ends up empty. The C verb behind the
# pick is `xschem get graph_trace_at` (draw.c graph_wave_at), the same engine
# machinery as graph_near_wave with the identity of the trace kept.
#
# ---- undo / redo of viewer edits (2026-07-28) ------------------------------
# `u` undoes and `U` (Shift-u) redoes the model edits above — a strip reorder or
# a trace move — on the shared `WaveViewer` bindtag, remappable from an rc the
# same way Ctrl-D is. NOT the C undo stack: the viewer buffer is readonly and its
# rects are regenerated wholesale from the Tcl model, so the history is a stack
# of MODEL SNAPSHOTS ({graphs target}) pushed by the mutating command itself,
# AFTER capture_live_graph_state so a pan/zoom/bold made with the mouse comes
# back with the undone edit. Window OPTIONS (plot mode, sharedx, cursors, the
# loaded raw) are deliberately outside a snapshot. Any future model mutation
# becomes undoable by calling `wviewer::push_undo` at the same point.
#
# Pure Tcl, procs only at source time (safe under --nogui); ciw_echo only
# under has_x. TIP-278: `variable` declarations, absolute names.

# Initial plot mode of a NEWLY OPENED viewer window (single|multi). Read
# LAZILY (at open time) so a `--script` rc — cadence_style_rc, headless
# tests — can still set it; once a window is open its own per-window mode is
# the authority. Invalid values fall back to `single`.
set_ne wviewer_plot_mode single

# ---- legend text size + weight (viewer plan item 1) ------------------------
# The ASE legend was reported as too small next to the axis numbers. It is NOT
# `txtsizelegend` (that is the VERTICAL legend path, which this viewer never
# enables) but `txtsizelab`, and the numbers come out of setup_graph_data
# (draw.c ~3707-3733) like this, for a strip of container height rh with the
# template's divx/divy = 5:
#
#   marginy    = rh * 0.14
#   txtsizelab = marginy * 0.006 * legendmag  = 8.4e-4 * rh * legendmag
#   txtsizex   = min(w/divx*0.0070, marginy*0.0065) * xlabmag
#              = 9.1e-4 * rh              (the bottom-margin clamp always binds)
#   txtsizey   = min(h/divy*0.0095, marginx*0.004) * ylabmag
#              = 1.368e-3 * rh            (h = rh - 2*marginy = 0.72*rh)
#
# So at legendmag 1.0 the legend is 0.92x the X numbers and only 0.61x the Y
# numbers. WHICH axis numbers "match the axis numbers" means therefore decides
# the value, and the two readings are not close: matching X needs 1.083 —
# an 8% change nobody could see, which cannot be what "too small" asked for —
# while matching Y needs 1.368e-3/8.4e-4 = 1.63. Hence the default below.
#
# ⚠ The match is exact only at the template's divy=5: txtsizey scales as
# 1/divy while txtsizelab does not, so a strip edited to divy=10 in the Graph
# dialog has axis numbers half the size and the legend then overshoots. Making
# it exact for every divy would mean computing txtsizelab FROM txtsizey in C,
# which is the "new C helper" route decision D-G deliberately rejected in
# favour of driving the existing per-rect `legendmag` token from here.
#
# Both are read LAZILY (at strip-template time), so an rc — cadence_style_rc,
# ~/.xschem/xschemrc, a --script test — can still set them. Per-rect tokens,
# so ONLY viewer strips are affected: draw_graph_variables is shared with every
# embedded schematic graph in the tree (~127 of them ship), and decision D-G is
# that they must not move.
set_ne wviewer_legend_textmag 1.63
# 1 = draw EVERY legend entry in the bold face (prop token `legendbold=1`).
#
# DEFAULT 0, BY REVIEW 2026-07-29. The plan's recorded decision was "both size
# and boldness — every legend entry bold", and that is what shipped first. Seen
# on screen the user's verdict was the opposite: *"the legend is always bolded.
# We want same font size as axis, but bolding only when the associated trace is
# selected"*. So the SIZE change stands and the weight goes back to the issue
# 0152 rule — bold marks the SELECTED trace, which is information, where
# bolding everything is just weight.
#
# The knob stays, because the all-bold look is one rc line away for anyone who
# wants it. At 0 the C side takes the pre-existing conditional-bold path
# unchanged (`hilight_wave == wcnt`, upright), so this is byte-identical to
# what shipped before item 1 except for the size. At 1 the bolded wave needs a
# different cue — bold is no longer distinctive — and draw.c gives it bold
# ITALIC.
set_ne wviewer_legend_bold 0

# ---- graph grid density (viewer plan item 2, decision D-B) -----------------
# "The grid is too heavy -- reduce its pixel density by 50%." Three readings
# were possible and they look quite different: halve the LINE COUNT (drop the
# subdivisions), halve the DUTY CYCLE, or dim the COLOUR. D-B chose the duty
# cycle: every grid line stays, in its own colour, but half as many of its
# pixels are lit.
#
# draw.c has always called XSetDashes with a ONE-element dash list, which makes
# the on-run and the off-run equal -- a 50% duty cycle (2-on/2-off at the usual
# zoom). This var is the OFF run against a 1-pixel ON run, so the default 3
# gives 1-on/3-off: the same 4-pixel period, half the lit pixels. 0 restores the
# shipped pattern exactly.
#
# Per-rect token (`griddash`), emitted only by the viewer's own strip generator,
# for the same blast-radius reason as the legend vars above: draw_graph_grid is
# shared with every embedded schematic graph in the tree.
set_ne wviewer_grid_dash_off 3

# Initial grid visibility of a NEWLY OPENED viewer window (viewer plan item 3).
# Ctrl-G toggles it live per window; this is only the starting value, read
# lazily at open time like wviewer_plot_mode. Anything not a boolean -> 1
# (grid shown), the shipped look.
set_ne wviewer_grid_show 1

# Mid-drag shrink preview of the trace being dragged to another strip (viewer
# plan item 6, decision D-E: the TRACE drag, not the strip reorder). The
# vertical scale applied to that one trace while the drag is live, about the
# plot box centre. 0.7 = a 30 % shrink in BOTH axes (review 2026-07-29:
# "shrink in both X and Y, not just Y"; 10 % was too subtle to read); 1.0
# disables the effect
# without disabling the drag. Anything outside (0, 1] falls back to 0.9.
# Not a per-rect token: it is transient CHROME (draw_graph bit 16), never
# written to a rect and never exported.
set_ne wviewer_drag_shrink 0.7

namespace eval wviewer {
  # session token -> {top .xN win_path .xN.drw}
  variable windows [dict create]
  # win_path -> list of graph-rect bboxes {x1 y1 x2 y2} placed by display_raw.
  # NOTE (deviation from the scout hint): `xschem object rect #2,N` returns
  # NO coordinates (scheduler.c object_descriptor: type/index/layer/id/name
  # only), so over_graph tests the pointer against these recorded bboxes —
  # the viewer canvas holds ONLY wviewer-created graph rects, so the registry
  # is authoritative.
  variable graphbb [dict create]
  # keysyms of the waves_callback key set (a b d s m t A B M) — forwarded ONLY
  # over a graph; outside graphs these are editor verbs (m=move, t=text ...)
  # and must do nothing, silently.
  # 100 (`d`) and 77 (`M`) joined for waveform markers
  # (doc/claude/specs/graph_markers.md): `m` now CREATES a marker, `d` creates
  # one with a delta block against the previous marker, and the measurement
  # tooltip moved from `m` to `M`. Delete (65535) is deliberately NOT here —
  # membership means UNCONDITIONAL forwarding, and an unguarded Delete would
  # land on the C canvas delete (readonly_block modal). It gets its own
  # doubly-gated arm in key_filter instead.
  variable graphkeys {97 98 100 115 109 116 65 66 77}
  # Canvas sequences the strip sweep KEEPS, in the canonical spellings `bind`
  # reports (<KeyPress> -> <Key>, <ButtonPress> -> <Button>, <Key-i> -> bare
  # `i`, <Shift-Insert> -> <Shift-Key-Insert> — probe-verified): the
  # non-input plumbing (redraw/resize/enter/leave/motion) plus wheel and
  # generic button press/release (zoom/pan + the C graph engine's own
  # interactions; Button-3 and double-clicks are re-filtered right after
  # the sweep). EVERYTHING else bound on the viewer canvas is cleared
  # before the filters go in.
  variable keepseqs {
    <Expose> <Configure> <Visibility> <Enter> <Leave> <Motion> <Unmap>
    <MouseWheel> <Button> <ButtonRelease>
  }
  # trace/graph MODEL (item 12, D7): session token -> {sharedx 0|1 graphs
  # {G ...}}, each G = {traces {{expr E name N color C vec V} ...} logx .
  # logy . x1 . x2 . y1 . y2 .} ({} range = auto zoom at regenerate;
  # `height` deferred). Single source of truth — rects always regenerated
  # from it; the one reverse write is the View>Fit read-back (D6).
  variable layouts [dict create]
  # trace color auto-cycle (D10): matches shipped graph usage (ne555 uses
  # 4 15 7 12 9); skips layers 0-3 (background/wire/grid/text).
  variable palette {4 5 7 8 9 12 14 15 10 11}
  # per-window cursor/readout/shared-x MIRRORS (D8): there is no
  # `xschem get graph_flags` getter, so the menu checkbutton vars are the
  # authoritative Tcl-side cursor state; key_filter flips them when it
  # forwards a/b over a graph (the only other toggle path). Residual
  # desync risk (documented): a C-side refusal the mirror cannot see —
  # waves_callback gates a/b/s on access_cond, but graph_use_ctrl_key
  # defaults 0 in the shipping profile so the C toggle always runs there.
  variable cva;     array set cva {}
  variable cvb;     array set cvb {}
  variable cvr;     array set cvr {}
  variable sharedx; array set sharedx {}
  # viewer plan item 3: Graph > Grid checkbutton mirror, per window
  variable gridshow; array set gridshow {}
  # issue 0151: per-window PLOT MODE (single|multi) and TARGET STRIP (model
  # graph index). Window properties, not graph properties — hence arrays
  # keyed by session token like the mirrors above, NOT layout-dict keys (the
  # layout dict is rebuilt wholesale by restore/set_graphs). `target` is
  # stored raw and clamped on every read (wviewer::target_index), so
  # deleting a strip can never leave a dangling target.
  variable mode;    array set mode {}
  variable target;  array set target {}
  # per-dialog transient state (D13), cleaned on OK/cancel/forget
  variable axl;     array set axl {}
  variable delmap;  array set delmap {}
  # strip drag-reorder (doc/claude/specs/waveform_viewer_modes.md §12): TRANSIENT
  # per-window gesture state, keyed by session token. Created in open, dropped by
  # forget, NEVER serialized (a half-finished drag is not part of a saved layout).
  #   drag_from   = model index of the strip the press grabbed (-1 = not armed)
  #   drag_to     = prospective destination index while dragging
  #   drag_y0     = press y in canvas pixels (the movement-threshold anchor)
  #   drag_active = 1 once the drag passed the threshold and owns the pointer
  variable drag_from;   array set drag_from {}
  variable drag_to;     array set drag_to {}
  variable drag_y0;     array set drag_y0 {}
  variable drag_active; array set drag_active {}
  # TRACE drag between strips (same spec, §13): TRANSIENT per-window state, same
  # lifetime rules as the strip-drag arrays above. A press can arm AT MOST one of
  # the two gestures — on a trace it arms this one, on empty body space the strip
  # reorder — so the two state sets never both hold a live drag.
  #   tdrag_gi   = model index of the strip the trace was picked up from (-1 = off)
  #   tdrag_ti   = model TRACE index inside that strip
  #   tdrag_to   = prospective destination strip index
  #   tdrag_x0/y0 = press pixel (the movement-threshold anchor)
  #   tdrag_active = 1 once the drag passed the threshold and owns the pointer
  #   tdrag_pairs  = the MOVING SET (issue 0192): MODEL {gi ti} pairs decided at
  #                  PRESS time — the whole selection when the pressed trace is
  #                  in it, else just the pressed trace
  variable tdrag_gi;     array set tdrag_gi {}
  variable tdrag_ti;     array set tdrag_ti {}
  variable tdrag_to;     array set tdrag_to {}
  variable tdrag_x0;     array set tdrag_x0 {}
  variable tdrag_y0;     array set tdrag_y0 {}
  variable tdrag_active; array set tdrag_active {}
  variable tdrag_pairs;  array set tdrag_pairs {}
  # token -> 1 once set_drag_cursor has reported a cursor this X theme cannot
  # supply, so the CIW hears it ONCE per window instead of on every motion
  variable cursor_warned; array set cursor_warned {}
  # UNDO / REDO of viewer model edits (2026-07-28): per-window stacks of MODEL
  # SNAPSHOTS ({graphs target}), newest last. Transient like the drag state —
  # created on open, dropped by forget, NEVER serialized: a saved layout carries
  # the state, not the history that produced it.
  variable undo_hist;   array set undo_hist {}
  variable redo_hist;   array set redo_hist {}
  # how many edits back `u` can go, per window
  variable undo_depth 50
  # NET-HIGHLIGHT STYLES ON WAVEFORM TRACES
  # (doc/claude/specs/wave_trace_hilight.md D4). token -> list of {gi ni style},
  # `ni` a NODE index (landmine 34). Same lifetime class as the drag/undo arrays
  # above: created in open, dropped by forget, NEVER serialized -- it is not a
  # prop token, not part of `layouts`, not in `snapshot` and not in the undo
  # unit. It dies with the window.
  #
  # ⚠ THIS ARRAY IS THE AUTHORITY, and that is not a stylistic choice. The C
  # engine holds the live set (xctx->wave_hilight_*), but `wviewer::regenerate`
  # runs `xschem clear_drawing`, which resets it -- and a plain window RESIZE
  # calls regenerate (landmine 50). A set held only in C would therefore vanish
  # when the user drags the window edge, which reads as a bug. So regenerate
  # re-applies this array to the fresh rects (wviewer::wave_hilight_push).
  variable wavehl;      array set wavehl {}
  # 1 while a plain MMB press was accepted as a GRAPH pan (btn2_filter). The
  # press is what decides; the motions and the release just follow it, so a
  # press the filter refused can never leak a canvas pan mid-gesture.
  variable mmb;         array set mmb {}
  # Button-3 CLICK detection (viewer plan item 7): the press pixel of the
  # in-flight RMB gesture, keyed by CANVAS WIDGET rather than by session token
  # — the press and the release are two events on one widget, and the widget is
  # what both of them carry. Unset again on the release, so a release with no
  # recorded press (a button that went down elsewhere, a replayed lone event)
  # can never be read as a no-travel click.
  variable b3x0;        array set b3x0 {}
  variable b3y0;        array set b3y0 {}
  # ... and whether a MARKER drag was armed when that press landed, which only
  # the press can see (the release's forward to C aborts the arm).
  variable b3mk;        array set b3mk {}
  # issue 0171: 1 once the `WaveViewer` bindtag defaults have been installed
  # (install_default_binds is called on every viewer open and must be a no-op
  # after the first — re-installing would undo an in-session remap).
  variable tagbinds 0
  # item 18 (graph-fills-win): <Configure> refit bookkeeping, per session token.
  # cfgafter = the pending `after idle` id (coalesces resize storms); fillwh =
  # the canvas pixel size {W H} the last regenerate filled at (so on_configure
  # re-fills ONLY when the size actually changed). Cleaned on forget.
  variable cfgafter; array set cfgafter {}
  variable fillwh;   array set fillwh {}
  # issue 0173: how many times wviewer::leave_ctx could NOT put the xschem
  # context back where enter_ctx found it (a `new_schematic switch` refused
  # under a raised semaphore — landmine 17). Diagnostic only: a refused restore
  # is left refused, never retried, because every caller is a status/redraw path
  # that must not break the keystroke it rides on. Non-zero here means some
  # window is holding a semaphore across a viewer refresh, which is worth
  # knowing but is not itself actionable at the call site.
  variable ctx_restore_refused 0
}

# The viewer title (D6): `Waveforms <design cell> (<state view>)`. Cell from
# the session state's design dict, falling back to the token's cell segment
# (ase_window precedent); view = the token's 3rd segment.
proc wviewer::title_for {token} {
  set cell {}
  catch {set cell [dict get [ase::session_state $token] design cell]}
  if {$cell eq {}} { set cell [lindex [split $token /] 1] }
  set view [lindex [split $token /] 2]
  return "Waveforms $cell ($view)"
}

# Re-assert the viewer title. Needed after EVERY `xschem set readonly` toggle
# (set_modify(-1) rewrites the wm title to the editor format — probe-verified)
# and appended to FocusIn.
proc wviewer::retitle {token} {
  variable windows
  if {![dict exists $windows $token top]} { return }
  set top [dict get $windows $token top]
  if {[catch {winfo exists $top} ex] || !$ex} { return }
  wm title $top [wviewer::title_for $token]
}

# The viewer toplevel of `token`, or {} when unknown/dead (test seam).
proc wviewer::window_for {token} {
  variable windows
  if {[dict exists $windows $token top]} {
    set top [dict get $windows $token top]
    if {![catch {winfo exists $top} ex] && $ex} { return $top }
  }
  return {}
}

# Registry win_path -> token reverse lookup ({} when unknown).
proc wviewer::token_for_canvas {wp} {
  variable windows
  dict for {tok rec} $windows {
    if {[dict get $rec win_path] eq $wp} { return $tok }
  }
  return {}
}

# Drop a token's registry entries (close / <Destroy> cleanup). Idempotent.
# The trace/graph model and the cursor mirrors die WITH the window: a fresh
# open starts from an empty layout (persistence across sessions is item 14's
# `viewer` state key, not this registry).
proc wviewer::forget {token} {
  variable windows
  variable graphbb
  variable layouts
  variable cva; variable cvb; variable cvr; variable sharedx
  # `gridshow` was unset below (viewer plan item 3) without ever being declared
  # here, so `unset gridshow($token)` addressed a LOCAL array, failed, and was
  # swallowed by its own `catch` -- the namespace entry survived every close.
  # Benign only by luck: `open` re-seeds it unconditionally, so the stale value
  # was always overwritten before anything read it. Declared now, so `forget`
  # really does leave the token's array family empty (which the tab teardown
  # below relies on being true).
  variable gridshow
  variable mode; variable target
  variable drag_from; variable drag_to; variable drag_y0; variable drag_active
  variable mmb
  variable axl; variable delmap
  variable cfgafter; variable fillwh
  variable b3x0; variable b3y0; variable b3mk
  if {[dict exists $windows $token]} {
    set wp_ [dict get $windows $token win_path]
    # item 7: take down a posted context menu BEFORE the window goes, so its
    # tk_popup grab cannot outlive the widget it was taken on, and drop the
    # widget-keyed press state with the widget it belongs to.
    catch {wviewer::trace_menu_unpost $token}
    catch {wviewer::strip_menu_unpost $token}
    catch {unset b3x0($wp_)}
    catch {unset b3y0($wp_)}
    catch {unset b3mk($wp_)}
    # a destroyed strip must not leave a selected-marker number pointing at
    # nothing (doc/claude/specs/graph_markers.md). graph_marker_sel lives in
    # xctx, i.e. PER WINDOW, and this runs during teardown where the current
    # context is whatever happens to be up — so reset only when the context IS
    # still this viewer, otherwise we would clear an unrelated window's
    # selection. C already fails safe (delete_selected returns 0 when the number
    # does not resolve); this is the tidy-up, not the guarantee.
    catch {
      if {[xschem get current_win_path] eq $wp_} { xschem graph_marker select -none }
    }
    dict unset graphbb $wp_
    dict unset windows $token
  }
  dict unset layouts $token
  catch {unset cva($token)}
  catch {unset cvb($token)}
  catch {unset cvr($token)}
  catch {unset sharedx($token)}
  catch {unset gridshow($token)}
  catch {unset mode($token)}
  catch {unset target($token)}
  catch {unset drag_from($token)}
  catch {unset drag_to($token)}
  catch {unset drag_y0($token)}
  catch {unset drag_active($token)}
  foreach a {tdrag_gi tdrag_ti tdrag_to tdrag_x0 tdrag_y0 tdrag_active tdrag_pairs
             undo_hist redo_hist wavehl cursor_warned} {
    catch {unset ::wviewer::${a}($token)}
  }
  catch {unset mmb($token)}
  array unset axl ${token},*
  catch {unset delmap($token)}
  if {[info exists cfgafter($token)]} { catch {after cancel $cfgafter($token)} }
  catch {unset cfgafter($token)}
  catch {unset fillwh($token)}
  return {}
}

# Raise-or-open the ONE viewer window of ASE session `token`. Returns 1 when
# the viewer is up (raised or freshly built), 0 on an unknown token (ciw_echo
# under has_x, never a throw — ase::open_state style) and 0 headless (the
# window shell is GUI-only; the session bookkeeping stays untouched).
proc wviewer::open {token} {
  variable windows
  variable layouts
  variable cva; variable cvb; variable cvr; variable sharedx; variable gridshow
  variable mode; variable target
  variable drag_from; variable drag_to; variable drag_y0; variable drag_active
  variable mmb
  if {[ase::session_state $token] eq {}} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: unknown ASE session '$token'" error
    }
    return 0
  }
  if {![info exists ::has_x]} { return 0 }
  # re-open: lazily validate the registry entry, then raise (WSLg idiom —
  # bare deiconify/raise is a no-op there, issue 0054)
  if {[dict exists $windows $token]} {
    set top [dict get $windows $token top]
    if {[winfo exists $top]} {
      raise_activate_toplevel $top
      catch {focus $top}
      return 1
    }
    wviewer::forget $token   ;# window died without cleanup: stale entry
  }
  # fresh open (D4): real toplevel + untitled buffer in BOTH window models;
  # the empty file arg always takes the new_schematic("create_window") arm
  # (the pristine-untitled reuse arm only fires for non-empty paths)
  # ⚠ VERIFY THE CONTEXT FOLLOWED, do not assume it (landmine 17, the rule this
  # file applies everywhere else and did not apply here). `-window` always
  # CREATES the toplevel, but the switch to it is a switch_window, which
  # silently no-ops under a raised semaphore — so `current_win_path` comes back
  # as the OLD window perhaps a third of the time (measured: 3 of 10 fresh
  # processes, identical inputs, with `.x1` present in `winfo children .` while
  # the context was still `.drw`). Everything downstream then derived top = "."
  # and built `..wvmenubar`, and `wviewer::open` threw
  # `invalid command name "..wvmenubar"` out of build_menubar.
  set before [xschem get current_win_path]
  set tops0 [winfo children .]
  xschem load_new_window -window {}
  set wp [xschem get current_win_path]
  if {$wp eq $before} {
    # the window exists but the context did not follow: find the toplevel that
    # was not there before and switch to it EXPLICITLY, verifying as we go
    foreach t [winfo children .] {
      if {[lsearch -exact $tops0 $t] >= 0} continue
      if {![winfo exists $t.drw]} continue
      catch {xschem new_schematic switch $t.drw}
      if {[xschem get current_win_path] eq "$t.drw"} { set wp $t.drw; break }
    }
  }
  # derive the toplevel from win_path (.xN.drw -> .xN) rather than
  # `xschem get top_path`, which reports {} under the tabbed interface
  regsub {\.drw$} $wp {} top
  if {$top eq {}} { set top . }
  # A viewer on the ROOT window cannot work: its widgets are `$top.<name>`, and
  # for `.` that concatenates to `..<name>`, which is not a legal Tk path. Rather
  # than throw out of build_menubar, refuse cleanly — the caller already treats
  # 0 as "no viewer" and says so in the CIW.
  if {$top eq {.}} {
    if {[info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: could not give the waveform viewer its own window" error
    }
    return 0
  }
  # ⚠ EVERYTHING BELOW STAMPS PER-CONTEXT C STATE, SO VERIFY THE CONTEXT ONCE
  # MORE HERE (issue 0177 review). The landmine-17 comment above records that the
  # switch is MEASURED to no-op ~3 times in 10 under a raised semaphore, and the
  # recovery loop's own `xschem new_schematic switch` can fail the same way. The
  # only guard until now was `$top eq {.}`, which catches the ROOT window and
  # nothing else — so if the previously-current window was a DETACHED editor
  # `.xN`, all four settings below (readonly, no_grid, no_snap, graph_snap_cursor)
  # would be branded onto a real schematic the user is editing: it would go
  # read-only, lose its grid AND lose its snap. Refusing is strictly better than
  # that, and the caller already treats 0 as "no viewer" and says so in the CIW.
  if {[xschem get current_win_path] ne $wp} {
    if {[info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: the waveform window did not take the context, refusing" error
    }
    return 0
  }
  # D1: readonly for the window's life — modified becomes unsettable, so no
  # save prompt can ever appear on close
  xschem set readonly 1
  # item 18 (D1): grid/origin OFF for THIS window only (per-ctx C flag, NOT the
  # global draw_grid — normal schematic windows keep their grid). Set once and
  # never cleared; alloc_xschem_data zeroes it for every other ctx. The window
  # now reads as a graph, not a schematic.
  xschem set no_grid 1
  # issue 0177: and NO SCHEMATIC SNAP GRID for this window, ever. The viewer is
  # built on a schematic window and had been inheriting the snap machinery
  # piecemeal, patched one code path at a time (0143 did waves_callback). This is
  # the property instead of another override: the C side computes
  # mousex_snap/mousey_snap unsnapped at the SOURCE for this context, and drops
  # the two schematic pointer glyphs (the crosshair, which paints AT the snapped
  # coordinate, and the snap cursor, which snaps to nets and pins the viewer does
  # not have). Same per-ctx shape as no_grid above, and for the same reason:
  # `cadsnap` is a GLOBAL that a waveform canvas has no business sharing.
  catch {xschem set no_snap 1}
  # viewer plan item 9: arm the diamond snap cursor for THIS window only. Per
  # context (the no_grid precedent) because the pick walks every sample of
  # every trace, and graph_point_at is shared with every embedded schematic
  # graph in the tree.
  catch {xschem set graph_snap_cursor 1}
  # issue 0172: and MARK THIS CONTEXT AS A VIEWER, not a schematic. A viewer buffer is
  # indistinguishable from a pristine untitled scratch buffer by shape -- top level,
  # named untitled, no instances, no wires, and `modified` permanently 0 because the D1
  # with_edit contract ends every mutation with `xschem set_modify 0` -- so
  # is_pristine_untitled() offered this live window to the next File>Open as a reuse
  # target and the user's schematic was loaded INTO the viewer, destroying its graph
  # rects while the window kept its WaveViewer bindtag and menubar (Ctrl-D then wipes
  # the document). Same per-ctx shape as the four above; alloc_xschem_data zeroes it for
  # every other context, and it is never cleared -- a viewer stays a viewer.
  catch {xschem set wave_viewer 1}
  dict set windows $token [dict create top $top win_path $wp]
  wviewer::build_menubar $token $top
  wviewer::strip_bindings $wp
  # D2 fixup: the editor TOOLBAR is a second editing-verb surface, reachable
  # by mouse — build_widgets creates $top.toolbar (37 armed buttons: Insert
  # Wire/Symbol/Line/Rect/Polygon, Cut/Copy/Paste/Delete/Move, FileOpen/Save/
  # Reload, Netlist/Simulate/Waves) and pack_widgets packs it on EVERY new
  # window while the global toolbar_visible is 1 (the shipping default,
  # xschem.tcl set_ne toolbar_visible 1). A click there either reaches an
  # editor/simulator flow or throws the readonly rejection into Tk's bgerror
  # stack-trace modal. Per-window `pack forget` hides it for the window's
  # life; toolbar_hide is NOT used — it flips the GLOBAL toolbar_visible off
  # and every future editor window would silently lose its toolbar. Nothing
  # re-shows it here: the View > Show Toolbar checkbutton lives on the
  # detached editor menubar and the fullscreen toggle key never reaches the
  # C callback (key_filter swallows it).
  catch {pack forget $top.toolbar}
  # item 10: and the editor's own status bar. Same per-window reasoning as the
  # toolbar above -- it is a schematic-editor surface (netlisting mode, snap,
  # grid, the selection counter) that means nothing in a waveform window, and
  # the viewer puts its own bar in its place.
  catch {pack forget $top.statusbar}
  # item 12: fresh per-window model + cursor mirrors (forget cleared any
  # previous window's state for this token)
  if {![dict exists $layouts $token]} {
    dict set layouts $token [dict create sharedx 0 graphs {}]
  }
  set cva($token) 0
  set cvb($token) 0
  set cvr($token) 0
  set sharedx($token) 0
  set gridshow($token) [wviewer::default_grid_show]
  # issue 0151: the config var seeds THIS window's mode and nothing else —
  # from here on the per-window value is the authority (restore overwrites
  # both right after, when a state dict carries them)
  set mode($token) [wviewer::default_plot_mode]
  set target($token) 0
  # strip drag-reorder: disarmed
  set drag_from($token) -1
  set drag_to($token) -1
  set drag_y0($token) 0
  set drag_active($token) 0
  # trace drag between strips: disarmed
  wviewer::trace_drag_clear $token
  # a freshly opened window has nothing to undo
  wviewer::clear_history $token
  # ...and nothing highlighted (D4: the set dies with the window)
  wviewer::wave_hilight_clear_set $token
  set mmb($token) 0
  # readout bar (D9): a BOTTOM BAR on the viewer toplevel (not an
  # always-on-top toplevel — WSLg raise/focus pain, receipts/06/11), built
  # hidden; shown automatically when a cursor is enabled and toggled by the
  # Cursors > Readout checkbutton. One line per cursor.
  frame $top.wvreadout -background [ase::theme panel]
  label $top.wvreadout.a -anchor w -font AseEntryFont \
    -background [ase::theme panel] -text {}
  label $top.wvreadout.b -anchor w -font AseEntryFont \
    -background [ase::theme panel] -text {}
  pack $top.wvreadout.a -side top -fill x
  pack $top.wvreadout.b -side top -fill x
  # refresh the readout after any button release on the canvas (the C
  # engine's cursor drags end there). APPEND to the KEPT generic
  # <ButtonRelease> — never bind <ButtonRelease-1>: a more-specific
  # sequence would PREEMPT the kept generic editor bind and break cursor
  # dragging (Tk most-specific-wins; the item-11 sweep exists for exactly
  # this class).
  bind $wp <ButtonRelease> "+[list wviewer::readout_refresh $token]"
  # viewer plan item 10: the window's OWN status bar (plot mode + the snapped
  # sample from item 9). It is a private frame, deliberately NOT the editor's
  # $top.statusbar: statusmsg() and update_statusbar() rewrite that bar's slots
  # from C on EVERY GUI event, addressed by xctx->top_path, so anything written
  # into it here would be silently overwritten on the next mouse move.
  # ase::ui::select_on_design already fought that and pays an 80 ms re-assert
  # pump for it; one of those in the tree is enough.
  frame $top.wvstatus -background [ase::theme panel]
  label $top.wvstatus.l -anchor w -font AseEntryFont \
    -background [ase::theme panel] -text {}
  pack $top.wvstatus.l -side left -fill x -expand 1
  # -before $top.drw is the rule readout_show uses: packed bottom-first the bar
  # takes its height from the canvas instead of squeezing it.
  pack $top.wvstatus -side bottom -fill x -before $top.drw
  # The snapped sample changes on MOTION, which is a C-side event with no Tcl
  # hook — so the bar rides the motion pump. APPEND to the KEPT generic
  # <Motion> (never a more-specific sequence, which would preempt the generic
  # editor bind: the readout's <ButtonRelease> comment applies verbatim).
  bind $wp <Motion> "+[list wviewer::status_refresh $token]"
  wviewer::status_refresh $token
  # item 18: refit the graph(s) to the new viewport on any canvas resize so the
  # graph ALWAYS fills the window. APPEND (never replace) — <Configure> is in
  # keepseqs and the editor's own resize handler (resetwin+draw) MUST keep
  # running; on_configure debounces to `after idle` and re-fills only on a real
  # size change (D6).
  bind $wp <Configure> "+[list wviewer::on_configure $token]"
  wviewer::retitle $token
  bind $top <FocusIn> "+[list wviewer::retitle $token]"
  # WM-close (or any external destroy) must also clean the registry; every
  # descendant's <Destroy> carries the toplevel bindtag, hence the %W guard
  bind $top <Destroy> "+if {{%W} eq {$top}} {[list wviewer::forget $token]}"
  # item 17 (dp-open-race): finish the FRESH open the SAME WSLg-reliable way
  # the RE-OPEN arm above does — a viewer that just opened must come to the
  # FRONT. Pre-fix this arm relied on load_new_window's natural first map, but
  # select_on_design/design_window has just raised the DESIGN window, so under
  # interactive WSLg the fresh viewer mapped BEHIND it and never came forward
  # (raise honored only at map time, issue 0054): the user saw "launch then
  # VANISH", and only the SECOND Direct Plot (this token's RE-OPEN arm) brought
  # it up. raise_activate_toplevel handles both the mapped and not-yet-mapped
  # cases (xschem.tcl), so it is safe on a window load_new_window may have
  # mapped asynchronously; additive for every caller (dp_finish, `~`/
  # open_viewer, auto_plot, restore) — none want a viewer opening behind.
  raise_activate_toplevel $top
  catch {focus $top}
  return 1
}

# Close the viewer of `token` (File > Close / Ctrl-W / D11). No prompt is
# possible: the buffer is readonly, so it can never be modified. Returns 1
# when a window was closed, 0 for an unknown token.
proc wviewer::close {token} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set top [dict get $windows $token top]
  set wp  [dict get $windows $token win_path]
  wviewer::forget $token
  if {[winfo exists $top]} { xschem new_schematic destroy $wp }
  return 1
}

# Run `script` at global level with the viewer's context current, then PUT THE
# CONTEXT BACK where it was (the View menu wrappers — navigation verbs are not
# readonly-gated).
#
# issue 0173: this used to be a bare `new_schematic switch` with no restore, and
# every one of its callers is a refresh or a redraw that has no business moving
# the current context — three `{xschem redraw}` wrappers plus `status_refresh`,
# which after 0173 does not call it at all. When the caller was the SCHEMATIC side
# (`ase::plot_mode_for_current` -> set_plot_mode -> status_refresh -> here) the
# context stayed on the viewer after the keystroke, so the next click in the
# schematic window was dispatched against the viewer's xctx and the viewer's
# title had been rewritten to `xschem [N] - untitled.sch (read-only)` by
# set_modify(-1). enter_ctx/leave_ctx are the save/restore bracket; both halves
# VERIFY, per landmine 17.
#
# Behaviour change worth knowing: a REFUSED switch (semaphore raised) now runs
# nothing and returns {}, where before it ran the script against whatever
# foreign context happened to be current — a `redraw` of the wrong window, a
# `graph_snap` from the wrong window. Callers already treat {} as "no answer".
#
# ⚠ A CALLER THAT WANTS A VALUE OUT MUST TAKE IT THROUGH THE RETURN, never by
# setting a variable inside the script body. The body runs at `uplevel #0` —
# GLOBAL level — so a `set` in there creates a global and the caller's local is
# untouched. (`wviewer::with_edit` uses `uplevel 1` and DOES reach the caller's
# scope, which is the shape the `delete_all_markers` count relies on; the two
# brackets differ and the difference is silent.) Measured symptom of getting it
# wrong: the status bar showed the plot mode and never a coordinate.
proc wviewer::in_ctx {token script} {
  variable windows
  if {![dict exists $windows $token]} { return }
  set ticket [wviewer::enter_ctx $token]
  if {![lindex $ticket 0]} { return }
  set code [catch {uplevel #0 $script} res]
  wviewer::leave_ctx $token $ticket
  if {$code} { return -code error $res }
  return $res
}

# Switch the current context to `token`'s viewer canvas and VERIFY the
# switch took effect (item 13): `new_schematic switch` silently NO-OPS while
# the current ctx's semaphore is raised (xinit.c switch_window) — e.g.
# inside ase::wait's vwait bracket — and proceeding blind would aim
# clear_drawing / raw clear+read / raw add at a FOREIGN schematic
# (probe-verified: a refused switch emptied the ASE design schematic).
# Returns 1 when the viewer ctx is current, else 0; destructive callers
# must bail out on 0.
proc wviewer::switch_ctx {token} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set wp [dict get $windows $token win_path]
  xschem new_schematic switch $wp
  return [expr {[xschem get current_win_path] eq $wp}]
}

# --- issue 0173: switching INTO a viewer is a LOAN, not a move ----------------
# A `new_schematic switch` is not a cheap read: on the window interface
# switch_window (xinit.c ~1784) runs save_ctx/restore_ctx/housekeeping_ctx and
# ends in `set_modify(-1)`, which REWRITES THE TARGET WINDOW'S wm TITLE
# (actions.c ~241) from that buffer's own name — and the viewer's buffer is a
# nameless read-only untitled one, so the viewer's title becomes
# `xschem [N] - untitled.sch (read-only)`. Nothing repairs that except the
# viewer's own `bind $top <FocusIn> +wviewer::retitle` (:703), which is why the
# reported symptom was "hovering over the viewer fixes the title".
#
# So a Tcl helper that has to READ or DRAW something in a viewer must (a) put
# the context back where it found it, and (b) re-assert the viewer's title.
# enter_ctx/leave_ctx are that bracket. `with_edit` (:862) is the mutation
# equivalent and already re-asserts the title; it deliberately does NOT restore
# the context, because its callers are viewer-side gestures that were already
# there — see the audit table in doc/claude/issues/0173-*.md.

# Enter `token`'s viewer context, remembering where the context came from.
# Returns a two-element TICKET {ok prev}:
#   ok   = 1 when the viewer's context is current, 0 when the switch was REFUSED
#          (landmine 17: `new_schematic switch` silently no-ops while the current
#          context's semaphore is raised, so it must be VERIFIED, never assumed).
#   prev = the win_path to restore, or {} when there is nothing to undo — either
#          because the viewer was ALREADY current (the switch never happened, so
#          no title was clobbered) or because the switch was refused.
# Callers must bail out on ok==0 and must hand the whole ticket to leave_ctx.
proc wviewer::enter_ctx {token} {
  variable windows
  if {![dict exists $windows $token]} { return {0 {}} }
  set wp [dict get $windows $token win_path]
  set prev {}
  catch {set prev [xschem get current_win_path]}
  # Cannot read where we are -> REFUSE, do not move. `current_win_path` really can
  # be transiently empty during window alloc/teardown (scheduler.c ~9380 documents
  # exactly that state), and switching with no restore target would clobber the
  # viewer's title with nothing to put back — an irreversible move, which is the
  # one thing this bracket exists to prevent. Skipping one refresh is the cheap
  # side of that trade.
  if {$prev eq {}} { return {0 {}} }
  # already there: switch_window's own `already there` early return (xinit.c
  # ~1797) would no-op anyway, but taking the fast path here also keeps `prev`
  # empty, so leave_ctx knows there is no title to repair.
  if {$prev eq $wp} { return {1 {}} }
  if {![wviewer::switch_ctx $token]} { return {0 {}} }
  return [list 1 $prev]
}

# The other half of enter_ctx: put the context back where the ticket says it came
# from and re-assert the viewer's title. VERIFIED both ways (landmine 17) — a
# restore that assumes success is the same bug in reverse. A refused restore is
# LEFT refused: no retry, no loop, no error. Every caller is a status/redraw path
# riding a keystroke or the motion pump, and throwing there pops bgerror; the
# refusal is counted in wviewer::ctx_restore_refused instead. Returns 1 when the
# context is back where it belongs (including "there was nothing to restore").
proc wviewer::leave_ctx {token ticket} {
  variable ctx_restore_refused
  set prev [lindex $ticket 1]
  if {$prev eq {}} { return 1 }           ;# never switched -> nothing to undo
  set ok 0
  catch {xschem new_schematic switch $prev}
  catch {set ok [expr {[xschem get current_win_path] eq $prev}]}
  # unconditional: the switch INTO the viewer already clobbered its title, and
  # that damage outlives a refused restore.
  wviewer::retitle $token
  if {!$ok} { incr ctx_restore_refused }
  return $ok
}

# Run `script` (caller's scope) against the viewer buffer with editing
# temporarily allowed. Contract (D1): switch to the viewer ctx, readonly 0,
# run, `set_modify 0` BEFORE readonly 1 (so modified can never stick), then
# re-assert the title (the readonly toggles clobber it, probe 2). The whole
# cycle is bracketed with `set autosave_backup 0` — write_backup DOES back up
# untitled buffers (issue 0060), and a with_edit mutation would drop
# untitled-N~.sch into the cwd. The script must not call `update`, so no
# foreign edit can interleave with the bracket. Errors from the script
# propagate AFTER the readonly/title/autosave restore. A REFUSED context
# switch (switch_ctx, item 13) errors out loudly BEFORE any mutation — the
# alternative is clear_drawing on somebody else's schematic.
proc wviewer::with_edit {token script} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  if {![wviewer::switch_ctx $token]} {
    return -code error "wviewer: cannot switch to the viewer window (context busy)"
  }
  set save_ab 1
  if {[info exists ::autosave_backup]} { set save_ab $::autosave_backup }
  set ::autosave_backup 0
  xschem set readonly 0
  set code [catch {uplevel 1 $script} err]
  xschem set_modify 0
  xschem set readonly 1
  set ::autosave_backup $save_ab
  wviewer::retitle $token
  if {$code} { return -code error $err }
  return 1
}

# --- trace/graph model (item 12, D7) -----------------------------------------

# dict-get-with-default (Tcl 8.6 has no `dict getdef`)
proc wviewer::dget {d key def} {
  if {[dict exists $d $key]} { return [dict get $d $key] }
  return $def
}

# A fresh model graph. Spec model fields; `height` (per-graph relative
# height) is DEFERRED — every graph gets an equal viewport band (item 18,
# band_geometry).
proc wviewer::empty_graph {} {
  return [dict create traces {} logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
}

# The layout dict of `token` (default empty layout when none recorded yet).
proc wviewer::layout_for {token} {
  variable layouts
  if {[dict exists $layouts $token]} { return [dict get $layouts $token] }
  return [dict create sharedx 0 graphs {}]
}

# Replace the graph list of `token`'s layout (model write helper; callers
# regenerate afterwards).
proc wviewer::set_graphs {token gs} {
  variable layouts
  set lay [wviewer::layout_for $token]
  dict set lay graphs $gs
  dict set layouts $token $lay
  return {}
}

# --- waveform markers: the `markers` token (doc/claude/specs/graph_markers.md) -
# A marker is durable annotation living in the graph rect's `markers` prop
# token, one record per LINE, nine space-separated ALL-NUMERIC fields:
#
#   <num> <wave> <dset> <point> <x> <y> <prev> <ldx> <ldy>
#
# num   window-wide marker number (the N in "M<N>"), >= 1
# wave  NODE index in this graph's `node` token — the index space every C
#       answer speaks (hilight_wave, graph_trace_at), NOT the model trace index
# dset  real raw dataset;  point  absolute index into raw->values[*][]
# x y   the cached sample, UNSCALED, written by C at %.17g
# prev  partner marker NUMBER for a delta block, 0 = none. It is a NUMBER and
#       not an index because the partner may live in a DIFFERENT strip
# ldx ldy  label offset as a FRACTION of the plot box w/h, C writes %.10g
#
# The alphabet is numeric-only on purpose: subst_token does not escape an
# embedded `"` or `\` (one stray quote silently destroys every token after it),
# and tcl_hook2 EXECUTES any value starting with `tcleval(`. The predicates
# below therefore reject anything outside [-+0-9.eE], which also excludes the
# letters of `nan`/`inf` — C refuses non-finite values at creation, so those can
# only arrive from a hand-edited file.
#
# Everything in this block is PURE (no Tk, no `xschem`) and directly testable.

# PURE: 1 when `v` is one legal field of a marker record. The character class IS
# the safety property — see the block comment. Deliberately NOT `string is
# double`: Tcl accepts "Inf" and "NaN" there.
proc wviewer::markers_num_ok {v} {
  return [regexp {^[-+]?[0-9.][0-9.eE+-]*$} $v]
}

# PURE: the fields of one record line, or {} when the line is not a record.
# THE single splitter — markers_valid and markers_decode share it so they can
# never disagree about the alphabet. Extra spaces are tolerated (C's sscanf
# tolerates them too); a tab is not, because get_tok_value's SPACE() macro
# terminates a value at one and the token would come back truncated.
proc wviewer::markers_line_fields {line} {
  set f {}
  foreach t [split $line { }] {
    if {$t eq {}} { continue }
    if {![wviewer::markers_num_ok $t]} { return {} }
    lappend f $t
  }
  if {[llength $f] < 9} { return {} }
  return $f
}

# PURE: is `s` a structurally valid whole `markers` value?
#
# {} RETURNS 0, and that is load-bearing, not defensive: an empty string has no
# lines, so an "every line is a record" predicate is vacuously TRUE on it, and
# graph_props would then stamp `markers=""` onto every strip that was never
# marked. That also creates two inequivalent spellings of "no markers" — `xschem
# rect … $props` stores props verbatim while subst_token/setprop DELETES a token
# given an empty value.
#
# This is a WHOLE-TOKEN, all-or-nothing predicate because it guards EMISSION
# (graph_props / capture / marker_changed), where the C parser has already
# guaranteed that only well-formed records reached the token. markers_decode is
# the per-record twin used on the TRANSFORM paths.
proc wviewer::markers_valid {s} {
  if {$s eq {}} { return 0 }
  foreach line [split $s "\n"] {
    if {![llength [wviewer::markers_line_fields $line]]} { return 0 }
  }
  return 1
}

# PURE: token -> list of record dicts {num wave dset point x y prev ldx ldy
# extra}. BAD LINES ARE DROPPED, the rest kept — matching the C parser, which
# drops a short record and keeps the others.
#
# x/y/ldx/ldy are kept as the ORIGINAL STRINGS, never converted. Tcl's default
# %g is 6 significant digits and a single round trip through `format`/`expr`
# would truncate C's %.17g sample identity — see the precision contract. The
# five INTEGER fields are normalised through `scan %d` so that later arithmetic
# on them cannot hit Tcl's leading-zero-is-octal rule in `expr`.
# `extra` carries any 10th+ field verbatim (forward tolerance), so
# encode(decode(s)) is byte-identical for every value this accepts.
proc wviewer::markers_decode {s} {
  set out {}
  if {$s eq {}} { return $out }
  foreach line [split $s "\n"] {
    set f [wviewer::markers_line_fields $line]
    if {![llength $f]} { continue }
    set bad 0
    foreach k {0 1 2 3 6} {
      if {![string is integer -strict [lindex $f $k]]} { set bad 1; break }
    }
    if {$bad} { continue }
    lappend out [dict create \
      num   [scan [lindex $f 0] %d] \
      wave  [scan [lindex $f 1] %d] \
      dset  [scan [lindex $f 2] %d] \
      point [scan [lindex $f 3] %d] \
      x     [lindex $f 4] \
      y     [lindex $f 5] \
      prev  [scan [lindex $f 6] %d] \
      ldx   [lindex $f 7] \
      ldy   [lindex $f 8] \
      extra [lrange $f 9 end]]
  }
  return $out
}

# PURE: the inverse. Re-emits x/y/ldx/ldy VERBATIM — no `format`, no `expr` (see
# markers_decode). An empty record list gives {}, i.e. "no token", which is what
# graph_props and setprop both read as "delete it".
proc wviewer::markers_encode {recs} {
  set lines {}
  foreach r $recs {
    set f [list [dict get $r num] [dict get $r wave] [dict get $r dset] \
                [dict get $r point] [dict get $r x] [dict get $r y] \
                [dict get $r prev] [dict get $r ldx] [dict get $r ldy]]
    foreach e [wviewer::dget $r extra {}] { lappend f $e }
    lappend lines [join $f { }]
  }
  return [join $lines "\n"]
}

# PURE: the marker NUMBERS a token carries, in record order. The seam the
# deletion paths use to learn which numbers just disappeared, so they can sweep
# the dangling `prev` links those numbers leave behind on OTHER strips.
proc wviewer::markers_numbers {s} {
  set out {}
  foreach r [wviewer::markers_decode $s] { lappend out [dict get $r num] }
  return $out
}

# PURE: remove record `num` from `s` AND zero every `prev` that pointed at it.
#
# Both halves matter. The C graph_marker_delete clears dangling prev links, but
# NONE of the Tcl deletion paths (delete_ok, clear_graph_traces) go through it —
# they rewrite the token directly. A dangling prev degrades a delta block to a
# plain callout with no indication at all (graph_marker_text simply omits the
# block when the partner does not resolve), so the sweep has to live here too.
proc wviewer::markers_drop_number {s num} {
  if {$s eq {}} { return {} }
  if {![string is integer -strict $num] || $num < 1} { return $s }
  set out {}
  foreach r [wviewer::markers_decode $s] {
    if {[dict get $r num] == $num} { continue }
    if {[dict get $r prev] == $num} { dict set r prev 0 }
    lappend out $r
  }
  return [wviewer::markers_encode $out]
}

# PURE: apply markers_drop_number for every number in `nums` to every graph of
# `gs` — the window-wide `prev` sweep, since a delta partner may live in another
# strip. A graph with no `markers` key is left ALONE (never given an empty one);
# a graph whose token empties out loses the key entirely, keeping "absent means
# absent" true all the way through graph_props.
proc wviewer::markers_sweep_numbers {gs nums} {
  if {![llength $nums]} { return $gs }
  set out {}
  foreach G $gs {
    if {[dict exists $G markers]} {
      set mk [dict get $G markers]
      foreach n $nums { set mk [wviewer::markers_drop_number $mk $n] }
      if {$mk eq {}} {
        set G [dict remove $G markers]
      } else {
        set G [dict replace $G markers $mk]
      }
    }
    lappend out $G
  }
  return $out
}

# PURE: how ONE stored node index survives the deletion of the node indices in
# `doomed`. Returns {} when the node itself is doomed, else the index shifted
# down by however many doomed nodes sat strictly BELOW it. Shared by the marker
# remap and the `hilight_wave` fix in delete_ok.
proc wviewer::remap_node_after_trace_delete {ni doomed} {
  if {![string is integer -strict $ni] || $ni < 0} { return {} }
  set below 0
  foreach d $doomed {
    if {$d == $ni} { return {} }
    if {$d < $ni} { incr below }
  }
  return [expr {$ni - $below}]
}

# PURE: markers of the SOURCE and DESTINATION graphs after the trace at node
# index `moved_ni` moves out of the source and lands at node index `dst_ni` of
# the destination. Returns {new_src_token new_dst_token}.
#
# A marker whose wave IS the moved node MIGRATES with its trace rather than
# dying — the same rule `hilight_wave` follows in move_trace_in_graphs, and the
# reason markers must never live in a strip-index-keyed side table. Its
# dset/point/x/y stay valid: the trace kept its raw column, only the node
# INDEX moved. Markers above the hole shift down by one; markers below are
# untouched; the destination's own markers are untouched because the trace is
# APPENDED. `prev` may now cross strips — already legal, it is a number.
proc wviewer::remap_markers_after_trace_move {src_mk dst_mk moved_ni dst_ni} {
  foreach v [list $moved_ni $dst_ni] {
    if {![string is integer -strict $v] || $v < 0} { return [list $src_mk $dst_mk] }
  }
  set keep {}
  set dst [wviewer::markers_decode $dst_mk]
  foreach r [wviewer::markers_decode $src_mk] {
    set w [dict get $r wave]
    if {$w == $moved_ni} {
      dict set r wave $dst_ni
      lappend dst $r
    } else {
      if {$w > $moved_ni} { dict set r wave [expr {$w - 1}] }
      lappend keep $r
    }
  }
  return [list [wviewer::markers_encode $keep] [wviewer::markers_encode $dst]]
}

# PURE: markers of one graph after the node indices in `doomed_nis` are deleted
# from it. A marker on a doomed trace is DROPPED (unlike a move, nothing is left
# for it to annotate); every survivor shifts down by the number of doomed nodes
# strictly below it. Callers must then sweep the dropped NUMBERS window-wide
# with markers_sweep_numbers — this proc cannot, it only sees one graph.
proc wviewer::remap_markers_after_trace_delete {mk doomed_nis} {
  set doomed {}
  foreach ni $doomed_nis {
    if {[string is integer -strict $ni] && $ni >= 0} { lappend doomed [scan $ni %d] }
  }
  if {![llength $doomed] || $mk eq {}} { return $mk }
  set out {}
  foreach r [wviewer::markers_decode $mk] {
    set w [wviewer::remap_node_after_trace_delete [dict get $r wave] $doomed]
    if {$w eq {}} { continue }
    dict set r wave $w
    lappend out $r
  }
  return [wviewer::markers_encode $out]
}

# --- plot modes (issue 0151) -------------------------------------------------
# doc/claude/specs/waveform_viewer_modes.md. Four PURE procs (no Tk, no
# `xschem` — directly unit-testable): the mode word resolver, the config-var
# reader, the target clamp, and the landing policy itself. Everything with a
# window or a side effect is built on top of these.

# Resolve a requested mode word against the current one. `invert` flips,
# `single`/`multi` set (case-insensitively), ANYTHING ELSE — including {} —
# returns {} so a bad word can never reach storage. Callers treat {} as
# "refused" and report it.
proc wviewer::resolve_mode {cur req} {
  set r [string tolower [string trim $req]]
  switch -exact -- $r {
    single  { return single }
    multi   { return multi }
    invert  { return [expr {$cur eq {multi} ? {single} : {multi}}] }
  }
  return {}
}

# The config var `wviewer_plot_mode` (initial mode of a NEW viewer window),
# validated. Unset / empty / garbage -> single, the shipped default.
proc wviewer::default_plot_mode {} {
  if {![info exists ::wviewer_plot_mode]} { return single }
  set m [wviewer::resolve_mode single $::wviewer_plot_mode]
  if {$m eq {}} { return single }
  return $m
}

# The config var `wviewer_legend_textmag` -> the `legendmag` prop token, CLAMPED
# (viewer plan item 1). Unset / empty / non-numeric / out of range all fall back
# to the 1.63 default, the value that matches the Y-axis numbers at the
# template's divy=5 — see the derivation where the var is defined.
#
# The clamp form is `>=` / `<=` deliberately, NOT `<` / `>`: those are FALSE for
# a NaN, so a NaN would slip through both tests and reach the rect props, where
# atof() would hand setup_graph_data a NaN txtsizelab and the strip would render
# nothing at all. `string is double` accepts "NaN" and "Inf", so it cannot be
# the guard on its own. Same shape as the shipped graph_marker_txtsize clamp.
#
# 0.25 .. 6.0: below 0.25 the text is sub-pixel at any usable strip height,
# above 6.0 one legend entry is wider than its per-node slot and the entries
# overprint each other.
proc wviewer::legend_textmag {} {
  set d 1.63
  if {![info exists ::wviewer_legend_textmag]} { return $d }
  set v [string trim $::wviewer_legend_textmag]
  if {![string is double -strict $v]} { return $d }
  if {!($v >= 0.25) || !($v <= 6.0)} { return $d }
  return $v
}

# The config var `wviewer_legend_bold` -> the `legendbold` prop token, as a
# strict 0/1. Anything unrecognised falls back to the shipped default, 0 —
# which is the CONSERVATIVE direction here: 0 is the long-standing issue-0152
# behaviour (bold marks the selected trace), so a typo in an rc leaves the
# viewer looking the way it always has rather than silently restyling every
# legend entry.
proc wviewer::legend_bold {} {
  if {![info exists ::wviewer_legend_bold]} { return 0 }
  set v [string trim $::wviewer_legend_bold]
  if {[string is boolean -strict $v]} { return [expr {[string is true -strict $v] ? 1 : 0}] }
  return 0
}

# The config var `wviewer_grid_dash_off` -> the `griddash` prop token, as a
# clamped integer. 0 = the shipped 2-on/2-off grid; N>0 = 1-on/N-off.
#
# Clamped 0..32 because a dash-list element is an unsigned char in X and an
# absurd off-run would simply erase the grid -- which is a different feature
# (item 3's on/off toggle), reachable by mistake from a typo here otherwise.
# Anything non-integer falls back to the default rather than to 0: a typo
# should not silently restore the heavy grid the user asked to be rid of.
# PURE (viewer plan item 10): the viewer status-bar text for a plot mode and a
# snapped sample. `x`/`y` {} = nothing snapped. No Tk, no xschem — the whole
# formatting half is assertable headless, which is the point of splitting it
# from the widget.
#
# ⚠ THE LABEL IS "Plot:", NOT "MODE:". The shipped editor status bar already
# carries a field literally labelled `MODE:` (xschem.tcl ~14908) and that one is
# the NETLISTING mode. Two contradictory MODEs in one window is worse than no
# status bar at all.
#
# Values go through ase::format_value, which is the engineering-notation
# formatter the rest of ASE uses (and which returns non-numerics verbatim, so a
# {} or an Inf cannot throw here).
proc wviewer::status_text {mode x y} {
  if {$mode eq {}} { set mode single }
  set out "Plot: $mode"
  if {$x ne {} && $y ne {}} {
    append out "    x: [ase::format_value $x]    y: [ase::format_value $y]"
  }
  return $out
}

# The config var `wviewer_grid_show` -> the INITIAL value of a window's grid
# flag. Not the live state: once a window is open, its own layout key is the
# authority (the default_plot_mode precedent).
proc wviewer::default_grid_show {} {
  if {![info exists ::wviewer_grid_show]} { return 1 }
  set v [string trim $::wviewer_grid_show]
  if {[string is boolean -strict $v]} { return [expr {[string is true -strict $v] ? 1 : 0}] }
  return 1
}

proc wviewer::grid_dash_off {} {
  set d 3
  if {![info exists ::wviewer_grid_dash_off]} { return $d }
  set v [string trim $::wviewer_grid_dash_off]
  if {![string is integer -strict $v]} { return $d }
  if {$v < 0 || $v > 32} { return $d }
  return $v
}

# Clamp a stored target index into a layout of `n` graphs. Out of range, a
# non-integer or an empty layout all collapse to 0 — the target is stored raw
# and clamped on every read, so deleting strips can never dangle it.
proc wviewer::target_clamp {gi n} {
  if {$n <= 0} { return 0 }
  if {![string is integer -strict $gi] || $gi < 0} { return 0 }
  if {$gi >= $n} { return [expr {$n - 1}] }
  return $gi
}

# PURE: is model strip `G` EMPTY? THE one definition of "empty strip", shared by
# every rule that consumes or deletes one: the plot-batch reuse (plan_plot), `e`
# (empty_strips_to_delete), and the two 2026-07-29 gesture reuses
# (reuse_strip_for_trace_move, plan_split).
#
# ⚠ EMPTY MEANS **ZERO MODEL TRACES**, not `node_count == 0`. A strip holding
# only `vec`-less traces reaches no node slot, so it draws nothing — but it is
# NOT empty here, and must not be consumed or deleted: the trace dicts are real
# model state the user can still edit into something drawable. The two counts
# differ exactly there, which is why both gestures test this and not node_count.
#
# Fails CLOSED on anything that is not a well-formed dict: a malformed entry is
# never "an empty strip you may take". (The model is always dicts; the guard
# also lets a test stack carry inert non-dict sentinels either side of the strip
# under test — the SP11-SP14 precedent.)
# ⚠ The well-formedness test has to be EXPLICIT: `dict exists` is lenient, so
# `dget` answers "no traces key" for a non-dict instead of erroring, and a
# fail-open here would have let the split move a trace INTO the malformed entry
# (caught by SP11's sentinels the moment the reuse arm landed).
proc wviewer::graph_is_empty {G} {
  if {[catch {dict size $G}]} { return 0 }
  return [expr {[llength [wviewer::dget $G traces {}]] ? 0 : 1}]
}

# PURE: the indices of the strips a plot batch may REUSE instead of creating a
# new one — the strips that hold NO traces and are not the tool-owned auto-plot
# strip — in index order (issue 0171 follow-up).
proc wviewer::empty_graph_indices {gs {auto -1}} {
  set out {}
  set gi 0
  foreach G $gs {
    if {$gi != $auto && [wviewer::graph_is_empty $G]} { lappend out $gi }
    incr gi
  }
  return $out
}

# THE landing policy. Given the mode, the current strip count, the stored
# target, how many signals one plot gesture carries, the index of the
# tool-owned auto-plot strip (-1 = none) and the REUSABLE empty strips
# (`empty_graph_indices`, {} = none), return
#   {new <how many strips to append> targets {<strip index per signal>}}
# single -> everything into the (clamped) target; a landing strip is needed
#           only when the stack is empty OR the target resolved to the
#           AUTO-PLOT strip, and then an empty strip is REUSED if there is one,
#           else one is APPENDED (bottom).
# multi  -> one strip per signal: the empty strips are reused first, the rest
#           are NEW strips inserted at the TOP of the stack, and the batch reads
#           NEWEST-FIRST — the LAST signal picked takes the topmost landing
#           strip, the first picked the bottom-most (2026-07-27 request).
# Zero signals is a no-op in both modes (an empty Direct Plot gesture must
# leave the raised viewer exactly as it was).
#
# **multi targets are in the POST-INSERT index space.** plan_plot cannot say
# "insert at the top" in its result without changing the dict shape every caller
# and test compares, so it says it in the INDICES: the `new` strips are 0..new-1
# and every strip already on the canvas is +new. `plot_signals` is what actually
# inserts them at the front (and shifts the stored target so the marker stays on
# the strip it was on). A caller that appends instead would scramble the batch.
#
# WHY empty strips are reused (issue 0171 follow-up): Clear All leaves exactly
# one empty strip, and Graph > Add Graph makes one on request. Appending past
# it — what multi-plot used to do unconditionally — left a blank band pinned at
# the top of the window and shrank every real strip for nothing. An empty strip
# is a place to plot, so a plot gesture fills it. Filling is by INDEX order, so
# pick order still reads top-to-bottom.
#
# WHY the auto-plot strip is excluded (both from the target and from the
# reusable set): it is REBUILT (traces cleared and re-added) after every
# successful run — ase::ui::auto_plot, item 13's always-replace contract.
# Landing hand-picked Direct-Plot traces there would silently destroy them at
# the next run, and it would break the shipped invariant that Direct-Plot
# graphs and the auto graph never touch each other
# (doc/claude/specs/waveform_viewer.md, item 13 notes).
proc wviewer::plan_plot {mode ngraphs target n {auto -1} {empties {}}} {
  if {$n <= 0} { return [dict create new 0 targets {}] }
  # defensive: keep only in-range, non-auto, deduped indices, lowest first —
  # the callers derive this list from the model, but plan_plot is the pure
  # policy and a bad index here would silently plot into nothing
  set free {}
  foreach gi $empties {
    if {[string is integer -strict $gi] && $gi >= 0 && $gi < $ngraphs \
        && $gi != $auto && [lsearch -exact $free $gi] < 0} {
      lappend free $gi
    }
  }
  set free [lsort -integer $free]
  if {$mode eq {multi}} {
    # at most n empty strips are reused; the shortfall becomes NEW top strips
    set reuse [lrange $free 0 [expr {$n - 1}]]
    set new [expr {$n - [llength $reuse]}]
    # landing sites in the POST-insert space: the new strips take 0..new-1,
    # every reused strip slides down by `new`
    set sites {}
    for {set k 0} {$k < $new} {incr k} { lappend sites $k }
    foreach gi $reuse { lappend sites [expr {$gi + $new}] }
    set sites [lsort -integer $sites]
    # newest on top: pick k takes the k-th site FROM THE BOTTOM, so the last
    # signal of the gesture ends up topmost and the batch reads newest-first
    set t {}
    set last [expr {[llength $sites] - 1}]
    for {set k 0} {$k < $n} {incr k} {
      lappend t [lindex $sites [expr {$last - $k}]]
    }
    return [dict create new $new targets $t]
  }
  set gi [wviewer::target_clamp $target $ngraphs]
  if {$ngraphs <= 0 || ($auto >= 0 && $gi == $auto)} {
    # the target is unusable: reuse an empty strip if there is one, else append
    if {[llength $free]} {
      set gi [lindex $free 0]
      set new 0
    } else {
      set gi $ngraphs
      set new 1
    }
    set t {}
    for {set k 0} {$k < $n} {incr k} { lappend t $gi }
    return [dict create new $new targets $t]
  }
  set t {}
  for {set k 0} {$k < $n} {incr k} { lappend t $gi }
  return [dict create new 0 targets $t]
}

# --- auto-plot graph (item 13, D4) -------------------------------------------
# The ASE Plot-checkbox auto-plot rebuilds ONE dedicated graph after every
# successful run (v1 always-replace). That graph carries an extra `auto 1`
# key on its model dict — graph_props reads only known keys (dget), so the
# marker never leaks into the rect props, and open dicts round-trip it for
# free (item 14 serialization included). Rebuild = CLEAR the traces, never
# remove the graph: Direct-Plot graph indices stay stable. All three helpers
# are PURE model ops (no Tk/xschem calls — headless-testable); callers
# regenerate.

# Index of the auto-plot graph in `token`'s layout, or -1 when none exists.
proc wviewer::auto_graph_index {token} {
  set gi 0
  foreach G [dict get [wviewer::layout_for $token] graphs] {
    if {[wviewer::dget $G auto 0] eq {1}} { return $gi }
    incr gi
  }
  return -1
}

# Find-or-append the auto-plot graph of `token`; returns its index (no
# regenerate — callers do).
proc wviewer::ensure_auto_graph {token} {
  set gi [wviewer::auto_graph_index $token]
  if {$gi >= 0} { return $gi }
  set gs [dict get [wviewer::layout_for $token] graphs]
  lappend gs [dict merge [wviewer::empty_graph] [dict create auto 1]]
  wviewer::set_graphs $token $gs
  return [expr {[llength $gs] - 1}]
}

# Empty the trace list of model graph `gi` (the graph itself is KEPT —
# clear-not-remove keeps later graph indices stable). Returns 1, 0 on a bad
# index.
proc wviewer::clear_graph_traces {token gi} {
  set gs [dict get [wviewer::layout_for $token] graphs]
  if {![string is integer -strict $gi] || $gi < 0 || $gi >= [llength $gs]} {
    return 0
  }
  set G [lindex $gs $gi]
  # every trace goes, so every node index this strip's markers and its bold-wave
  # marker referred to is gone: drop BOTH keys rather than leave them dangling at
  # indices that no longer exist (`hilight_wave` has never been remapped on this
  # path — a latent bug fixed here alongside the marker rule).
  set gone [wviewer::markers_numbers [wviewer::dget $G markers {}]]
  # `sel_waves` (issue 0175) rides with `hilight_wave` here for the same reason:
  # every node index is gone, so both keys go rather than dangle.
  set G [dict remove [dict replace $G traces {}] markers hilight_wave sel_waves]
  # ...and so does every TRACE HIGHLIGHT on this strip (§8). Same rule as the two
  # keys above: the node indices they name no longer exist, and this proc is the
  # ASE auto-plot rebuild's entry point, so it runs on every simulation run.
  wviewer::wavehl_remap_apply $token \
    [wviewer::wavehl_after_strip_clear [wviewer::wave_hilights $token] $gi]
  set gs [lreplace $gs $gi $gi $G]
  # the numbers that just disappeared may be the `prev` partner of a delta block
  # on ANOTHER strip — markers are numbered window-wide, so the sweep is too
  set gs [wviewer::markers_sweep_numbers $gs $gone]
  wviewer::set_graphs $token $gs
  return 1
}

# GUI: the schematic-coord rect covering the CURRENT visible viewport of the
# viewer canvas `wp` (item 18, D2). Inverts the documented pixel->schematic
# transform (xschem.h X_TO_XSCHEM: px*zoom - xorigin): the canvas pixel box
# [0..W]x[0..H] maps to [-xorigin .. W*zoom-xorigin] x [-yorigin .. H*zoom-
# yorigin]. Switches to the viewer ctx first (zoom/xorigin/yorigin are per
# window). A not-yet-mapped canvas (W<=1 || H<=1) falls back to a sane default
# so the first placement is reasonable — the map-time <Configure> refit
# (on_configure) is the authority that makes the final state exact. NO new
# `xschem get` accessor is warranted (cleanly computable pure-Tcl, D2).
proc wviewer::viewport_rect {wp} {
  xschem new_schematic switch $wp
  set W [winfo width $wp]
  set H [winfo height $wp]
  if {$W <= 1 || $H <= 1} { return {0 0 800 600} }
  set zoom [xschem get zoom]
  set xo   [xschem get xorigin]
  set yo   [xschem get yorigin]
  return [list [expr {-$xo}] [expr {-$yo}] \
               [expr {$W * $zoom - $xo}] [expr {$H * $zoom - $yo}]]
}

# PURE (headless-checkable; no Tk/xschem calls): the schematic-coord rect of
# graph `i` of `n`, tiling the viewport {vx1 vy1 vx2 vy2} into n equal
# full-width vertical bands (xschem y grows downward), replacing the old fixed
# 800x400/i*450 slots (item 18, D3/D5). NO inter-band gap — the engine's 14%
# draw margins (draw.c) already separate adjacent graphs. Boundaries use
# `vy1 + k*span/n` at k=i and k=i+1 (NOT a pre-divided `span/n`): so a whole-
# number viewport tiles to clean integer bands while a fractional GUI viewport
# still tiles exactly (band i's bottom is the SAME expression as band i+1's
# top -> contiguous, no gap/overlap, in int and double alike).
proc wviewer::band_geometry {i n vx1 vy1 vx2 vy2} {
  if {$n < 1} { set n 1 }
  set span [expr {$vy2 - $vy1}]
  set by1 [expr {$vy1 + ($i * $span) / $n}]
  set by2 [expr {$vy1 + (($i + 1) * $span) / $n}]
  return [list $vx1 $by1 $vx2 $by2]
}

# item 18 (D6): the <Configure> refit. Debounced — coalesce a resize storm into
# ONE `after idle` refit; a real re-fill runs only when the canvas pixel size
# changed since the last fill (fillwh), suppressing no-op Configure churn.
proc wviewer::on_configure {token} {
  variable windows
  variable cfgafter
  if {![dict exists $windows $token]} { return }
  if {[info exists cfgafter($token)]} { catch {after cancel $cfgafter($token)} }
  set cfgafter($token) [after idle [list wviewer::configure_apply $token]]
}

proc wviewer::configure_apply {token} {
  variable windows
  variable cfgafter
  variable fillwh
  catch {unset cfgafter($token)}
  if {![dict exists $windows $token]} { return }
  set wp [dict get $windows $token win_path]
  if {[catch {winfo width $wp} w] || $w <= 1} { return }
  set cur [list $w [winfo height $wp]]
  if {[info exists fillwh($token)] && $fillwh($token) eq $cur} { return }
  # issue 0194: a plain RESIZE regenerates, so it destroys the live selection
  # unless it is folded back first — the exposure capture_live_graph_state's
  # header and spec §15.5 both name by this path. skip_ranges keeps the refit
  # semantics a resize is FOR: the axes are not touched at all, so an auto strip
  # still re-autozooms into its new band and a pinned one keeps its own window.
  wviewer::capture_live_view_state $token
  wviewer::regenerate $token
}

# --- trace colors (D10 + issue 0153) ----------------------------------------
# All PURE. The cycle rule: the first palette entry not in `used`, and once the
# palette is exhausted, index by how many are used (the original D10 fallback,
# kept verbatim so a >10-trace graph behaves exactly as it always did).
#
# WHAT `used` CONTAINS is the whole of issue 0153. Before it, the only rule was
# "colors used by the LANDING graph", which is right for single-plot (everything
# stacks in one strip, so per-strip uniqueness IS window uniqueness) but made
# multi-plot paint every trace the same color: multi gives each signal its own
# BRAND-NEW strip, an empty strip has no used colors, so every one of them got
# palette head 4 (#88dd00). Multi-plot therefore seeds `used` from the WHOLE
# window (colors_in_graphs), so no two traces visible in the viewer share a
# color until the palette runs out. Single-plot is unchanged by design.

# The first palette entry not in `used`.
proc wviewer::first_unused_color {used} {
  variable palette
  foreach c $palette {
    if {[lsearch -exact $used $c] < 0} { return $c }
  }
  return [lindex $palette [expr {[llength $used] % [llength $palette]}]]
}

# The colors of one model graph's traces, in trace order (a colorless trace
# contributes {}, exactly as the pre-0153 `used` list did).
proc wviewer::graph_colors {G} {
  set out {}
  foreach tr [wviewer::dget $G traces {}] {
    lappend out [wviewer::dget $tr color {}]
  }
  return $out
}

# Every color in use anywhere in a strip list, deduped, {} dropped.
proc wviewer::colors_in_graphs {gs} {
  set out {}
  foreach G $gs {
    foreach c [wviewer::graph_colors $G] {
      if {$c ne {} && [lsearch -exact $out $c] < 0} { lappend out $c }
    }
  }
  return $out
}

# (D10) next auto-cycled trace color for model graph `G` — unchanged contract,
# used by add_trace and the Add Trace… dialog when no color is dictated.
proc wviewer::next_color {G} {
  return [wviewer::first_unused_color [wviewer::graph_colors $G]]
}

# One color per signal of a plot batch, given the strip list as it is BEFORE the
# batch lands, the plot mode, and the landing index per signal that plan_plot
# produced. Simulates the accumulation, so colors are distinct WITHIN the batch
# as well as against what is already plotted.
#
# Prefix-stable by construction (each signal's color depends only on the state
# and on the signals before it), which is what lets the Direct Plot picker ask
# for the color of click k while click k+1 has not happened yet.
proc wviewer::plan_colors {gs mode targets} {
  set base {}
  if {$mode eq {multi}} { set base [wviewer::colors_in_graphs $gs] }
  array set acc {}
  set out {}
  foreach gi $targets {
    if {![info exists acc($gi)]} {
      # a landing index past the end of `gs` is a strip the plan will CREATE:
      # lindex yields {} and it starts with no colors of its own
      set acc($gi) [concat $base [wviewer::graph_colors [lindex $gs $gi]]]
    }
    set c [wviewer::first_unused_color $acc($gi)]
    lappend acc($gi) $c
    if {$mode eq {multi}} { lappend base $c }
    lappend out $c
  }
  return $out
}

# The colors the NEXT `n` Direct-Plot signals will get in `token`'s viewer, in
# pick order. Impure only in reading the window's live mode/target/layout; the
# policy is plan_plot + plan_colors. Works with NO viewer open yet (the mode
# falls back to the config default and the layout to whatever is recorded, i.e.
# nothing after a close — see forget), because the picker runs before dp_finish
# raises the window.
proc wviewer::predict_colors {token n} {
  if {![string is integer -strict $n] || $n <= 0} { return {} }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set mode [wviewer::plot_mode $token]
  if {$mode eq {}} { set mode [wviewer::default_plot_mode] }
  set auto [wviewer::auto_graph_index $token]
  set plan [wviewer::plan_plot $mode [llength $gs] \
                               [wviewer::target_index $token] $n \
                               $auto [wviewer::empty_graph_indices $gs $auto]]
  return [wviewer::plan_colors $gs $mode [dict get $plan targets]]
}

# PURE: model graph dict -> full graph-rect prop string. Token order +
# defaults mirror the C add_graph template VERBATIM (scheduler.c add_graph);
# model fields override. Blank ({}) ranges keep the template defaults here
# and are resolved by fullx/fullyzoom right after placement when raw data is
# loaded (regenerate). node attr grammar (draw.c draw_graph): newline-
# separated tokens inside node="…"; an alias trace becomes a quoted
# "name;vec" token whose inner quotes are BACKSLASH-escaped (the IN-MEMORY
# prop form — save.c doubles the backslashes on file write); color = space-
# separated per-trace color layer indices, count == trace count.
proc wviewer::graph_props {G {active 0} {grid 1}} {
  set x1 [wviewer::dget $G x1 {}]
  if {$x1 eq {}} { set x1 0 }
  set x2 [wviewer::dget $G x2 {}]
  if {$x2 eq {}} { set x2 10e-6 }
  set y1 [wviewer::dget $G y1 {}]
  if {$y1 eq {}} { set y1 0 }
  set y2 [wviewer::dget $G y2 {}]
  if {$y2 eq {}} { set y2 2 }
  set logx [wviewer::dget $G logx 0]
  set logy [wviewer::dget $G logy 0]
  set ntoks {}
  set ctoks {}
  foreach tr [wviewer::dget $G traces {}] {
    set vec [wviewer::dget $tr vec {}]
    if {$vec eq {}} { continue }
    set nm [wviewer::dget $tr name {}]
    if {$nm ne {} && $nm ne $vec} {
      lappend ntoks "\\\"$nm;$vec\\\""
    } else {
      lappend ntoks $vec
    }
    lappend ctoks [wviewer::dget $tr color 4]
  }
  set node [join $ntoks "\n"]
  set color [join $ctoks { }]
  # issue 0151: `active=1` marks the TARGET strip. The token is written ONLY
  # for the target and ONLY while more than one strip is up (regenerate
  # decides) — the C engine paints a dull-yellow bar at the rect's right edge
  # when it sees it. Absent token = no marker, so single-strip layouts and
  # every non-viewer schematic graph render exactly as before.
  set act {}
  if {[string is true -strict $active] || $active eq {1}} { set act "active=1\n" }
  # The BOLD trace (`hilight_wave`) is written into the rect by the C engine
  # (the LMB wave-bold click, issue 0152) and only reaches the model through
  # capture_live_graph_state. Emit it ONLY when the model actually carries a
  # value: an absent key must stay absent, not become `hilight_wave=-1`, so a
  # graph that was never clicked keeps rendering byte-identically to pre-reorder.
  set hw {}
  set hwv [wviewer::dget $G hilight_wave {}]
  if {$hwv ne {} && [string is integer -strict $hwv]} { set hw "hilight_wave=$hwv\n" }
  # ... and the REST of the selection when there is more than one (issue 0175,
  # Ctrl+click multi-select). Exactly the same deal as `hilight_wave` above —
  # written by the C click arm, folded back by capture_live_graph_state — with
  # one extra rule that is the whole compatibility story: emitted ONLY when the
  # set holds TWO OR MORE. A 0- or 1-trace selection is expressed entirely by
  # `hilight_wave`, so every strip that was never Ctrl-clicked serialises
  # byte-identically to pre-0175 and an older build reading the file bolds the
  # first selected trace instead of choking. The value needs the quotes: it
  # contains spaces, which get_tok_value's SPACE() macro would read as
  # end-of-value.
  set sw {}
  set swv [wviewer::sel_waves_norm [wviewer::dget $G sel_waves {}]]
  if {[llength $swv] >= 2} { set sw "sel_waves=\"[join $swv { }]\"\n" }
  # Waveform markers (doc/claude/specs/graph_markers.md). Same deal as
  # `hilight_wave` above: written into the rect by the C engine and folded back
  # into the model by wviewer::marker_changed (the C push hook). Emitted ONLY
  # when the model carries a NON-EMPTY, STRUCTURALLY VALID value — an absent key
  # must stay absent, so a strip that was never marked renders byte-identically
  # to pre-marker (test_wave_modes M5/M7 pin that shape). The `$mkv ne {}` test
  # is not redundant with markers_valid: see the {}-returns-0 contract there.
  # The value needs no escaping beyond the outer quotes (numeric-only alphabet),
  # and it NEEDS those quotes because it contains spaces and newlines, which
  # get_tok_value's SPACE() macro would otherwise read as end-of-value.
  set mk {}
  set mkv [wviewer::dget $G markers {}]
  if {$mkv ne {} && [wviewer::markers_valid $mkv]} { set mk "markers=\"$mkv\"\n" }
  # The strip drag-reorder GRIP (right margin). Written unconditionally here, so
  # it marks exactly the viewer's own strips — graph_props is the viewer's rect
  # generator and nothing else uses it, which is what "viewer graphs only" means
  # (the 127 shipped schematics with embedded graphs never see the token). The
  # transient values 2/3 (drop-destination bar) are NOT written here: they are
  # setprop'd onto the two affected rects during a drag and cleared on
  # commit/cancel, so a regenerate always lands back on a plain grip.
  # Legend text size + weight (viewer plan item 1). Both are per-rect tokens
  # emitted HERE and nowhere else, which is exactly what confines them to viewer
  # strips (decision D-G: the shared draw_graph_variables must keep rendering
  # the ~127 embedded schematic graphs unchanged). `legendmag` already existed
  # and is what setup_graph_data multiplies txtsizelab by; `legendbold` is new.
  # `legendbold=0` is emitted rather than omitted so an rc that turns the bold
  # OFF takes effect on a regenerate instead of leaving the previous value in
  # the rect — the token is cheap and this is not the "absent means absent"
  # class that hilight_wave/markers belong to.
  set lmag [wviewer::legend_textmag]
  set lbold [wviewer::legend_bold]
  set gdash [wviewer::grid_dash_off]
  set gshow [expr {$grid ? {} : "grid=0\n"}]
  # viewer plan item 3: grid on/off is a WINDOW property, not a strip property,
  # so it arrives as an ARGUMENT (like `active`) rather than being read out of
  # the graph dict -- and explicitly NOT out of a namespace global, which would
  # make this generator impure and is the same objection that shaped the
  # drawline split in item 2.
  # Emitted ONLY when OFF. An absent token means "draw the grid", which is what
  # every non-viewer graph in the tree relies on, and it keeps a grid-on
  # window's rects byte-identical to pre-item-3 (the hilight_wave/markers
  # "absent means absent" rule; unlike legendbold, whose 0 must be written
  # because its default is the non-shipped value).
  return "flags=graph\ny1=$y1\ny2=$y2\nypos1=0\nypos2=2\ndivy=5\nsubdivy=1\nunity=1\nx1=$x1\nx2=$x2\ndivx=5\nsubdivx=1\nxlabmag=1.0\nylabmag=1.0\nlegendmag=$lmag\nlegendbold=$lbold\ngriddash=$gdash\n${gshow}node=\"$node\"\ncolor=\"$color\"\ndataset=-1\nunitx=1\nlogx=$logx\nlogy=$logy\nreorder_handle=1\n$hw$sw$mk$act"
}

# PURE (D4): pre-validate a whitespace-separated RPN expression against the
# raw variable list. Returns {} when every token is (a) an operator/function
# from the C table, (b) a number by the strtod-prefix rule (spice suffixes
# fine: 1k), or (c) a raw variable (case-insensitive, plus the v(tok)
# wrapping get_raw_index applies); else a message naming the bad token.
# WHY Tcl-side: the C evaluator DISCARDS its own error — raw_add_vector
# (save.c) ignores plot_raw_custom_data's -1 and leaves the vector
# uninitialized, so a bad expression would silently plot garbage.
proc wviewer::validate_rpn {rpn varlist} {
  # operator/function tokens verbatim from plot_raw_custom_data
  # (save.c:1855-1939) — case-SENSITIVE like the C strcmp table
  set ops {+ - * / ** == != > < >= <= ?}
  set funcs {atan() cph() asin() acos() tan() sin() cos() abs() sgn()
             sqrt() tanh() cosh() sinh() atanh() acosh() asinh() exp()
             ln() log10() integ() avg() ravg() max() min() im() re()
             pi() k() e() q() del() db20() deriv() deriv0() deriv2()
             deriv20() prev() exch() dup() idx()}
  set lvars {}
  foreach v $varlist { lappend lvars [string tolower $v] }
  set toks [regexp -all -inline {\S+} $rpn]
  if {![llength $toks]} { return "empty expression" }
  foreach t $toks {
    if {[lsearch -exact $ops $t] >= 0} { continue }
    if {[lsearch -exact $funcs $t] >= 0} { continue }
    if {[regexp {^[-+]?(\d|\.\d)} $t]} { continue }
    set lt [string tolower $t]
    if {[lsearch -exact $lvars $lt] >= 0} { continue }
    if {[lsearch -exact $lvars "v($lt)"] >= 0} { continue }
    return "unknown token '$t' (not an operator/function, number or raw variable)"
  }
  return {}
}

# Auto name for an expression trace: the first expr<N> unused both as a
# model vec and as a raw vector name (current ctx must be the viewer's).
proc wviewer::auto_expr_name {token} {
  set used {}
  foreach G [dict get [wviewer::layout_for $token] graphs] {
    foreach tr [dict get $G traces] {
      lappend used [wviewer::dget $tr vec {}]
    }
  }
  for {set n 1} {$n < 1000} {incr n} {
    set nm expr$n
    if {[lsearch -exact $used $nm] >= 0} { continue }
    set idx -1
    catch {set idx [xschem raw index $nm]}
    if {$idx < 0} { return $nm }
  }
  return expr$n
}

# Regenerate the viewer canvas of `token` FROM the model (the one honest
# direction): clear_drawing + one rect per graph (draw=0), auto-resolve
# blank ranges through the engine's fullx/fullyzoom when raw data is
# loaded, REBUILD the graphbb registry (over_graph and the a/b/s key gate
# feed off it — forgetting this breaks the cursor keys), zoom_full + one
# redraw. sharedx: non-master graphs inherit graph-0's x range at
# generation time.
proc wviewer::regenerate {token} {
  variable windows
  variable graphbb
  variable fillwh
  if {![dict exists $windows $token]} { return 0 }
  set wp [dict get $windows $token win_path]
  set lay [wviewer::layout_for $token]
  set gs [dict get $lay graphs]
  if {[wviewer::dget $lay sharedx 0] && [llength $gs] > 1} {
    set g0 [lindex $gs 0]
    set sx1 [wviewer::dget $g0 x1 {}]
    set sx2 [wviewer::dget $g0 x2 {}]
    for {set i 1} {$i < [llength $gs]} {incr i} {
      set gg [dict replace [lindex $gs $i] x1 $sx1 x2 $sx2]
      set gs [lreplace $gs $i $i $gg]
    }
  }
  # item 18: every graph FILLS an equal vertical band of the CURRENT viewport
  # (no fixed slot). viewport_rect switches to the viewer ctx and reads its live
  # zoom/origin + canvas size; band_geometry tiles that viewport.
  set n [llength $gs]
  # issue 0151: the active-strip marker only exists while there is a choice to
  # make — one strip is unambiguous, so no rect gets the `active` token and a
  # single-graph viewer renders byte-identically to pre-0151.
  set act_gi -1
  if {$n > 1} { set act_gi [wviewer::target_index $token] }
  lassign [wviewer::viewport_rect $wp] vx1 vy1 vx2 vy2
  wviewer::with_edit $token {
    xschem clear_drawing
    set gi_ 0
    foreach G_ $gs {
      lassign [wviewer::band_geometry $gi_ $n $vx1 $vy1 $vx2 $vy2] \
        rx1_ ry1_ rx2_ ry2_
      wviewer::place_graph_rect $rx1_ $ry1_ $rx2_ $ry2_ \
        [wviewer::graph_props $G_ [expr {$gi_ == $act_gi}] \
           [wviewer::grid_shown $token]]
      incr gi_
    }
    # blank (auto) ranges: let the ENGINE compute them into the rect attrs
    # (log/expr aware) — the model keeps {} = auto, so every regenerate
    # re-autozooms; readonly-gated, hence inside with_edit
    if {[xschem raw loaded] >= 0} {
      set gi_ 0
      foreach G_ $gs {
        if {[llength [dict get $G_ traces]]} {
          if {[wviewer::dget $G_ x1 {}] eq {} || [wviewer::dget $G_ x2 {}] eq {}} {
            xschem setprop -fast rect 2 $gi_ fullxzoom
          }
          if {[wviewer::dget $G_ y1 {}] eq {} || [wviewer::dget $G_ y2 {}] eq {}} {
            xschem setprop -fast rect 2 $gi_ fullyzoom
          }
        }
        incr gi_
      }
    }
  }
  # graphbb feeds over_graph / the a/b/s key gate — build it from the SAME
  # band rects so it matches the placed graphs exactly (D5)
  set bbs {}
  for {set i 0} {$i < $n} {incr i} {
    lappend bbs [wviewer::band_geometry $i $n $vx1 $vy1 $vx2 $vy2]
  }
  dict set graphbb $wp $bbs
  xschem new_schematic switch $wp
  # THE D4 RE-APPLY BRACKET (doc/claude/specs/wave_trace_hilight.md §4.1). The
  # with_edit block above ran `xschem clear_drawing`, which resets the C
  # engine's trace-highlight set along with everything else bound to a rect
  # index -- and a plain window RESIZE reaches here (landmine 50). The Tcl array
  # is the authority precisely so this line can put the set back on the FRESH
  # rects. It must sit after the rects exist and BEFORE the single `xschem
  # redraw` below, so that one redraw paints the overlay too.
  catch {wviewer::wave_hilight_push $token}
  # item 18 (D4): NO `xschem zoom_full` — the graph fills the viewport by
  # construction, so canvas zoom must NOT re-frame (shrink) it. Just redraw;
  # clear_drawing/redraw never touch zoom/origin, so the viewport stays pinned
  # and only the graph's internal axes change (item 19). View>Fit keeps its own
  # zoom_full (wviewer::fit) — that is item 19, out of scope here.
  xschem redraw
  # record the canvas pixel size just filled, for the <Configure> refit gate
  catch {set fillwh($token) [list [winfo width $wp] [winfo height $wp]]}
  catch {wviewer::readout_refresh $token}
  return 1
}

# --- graph display -----------------------------------------------------------

# Place one graph rect on the viewer canvas (runs inside with_edit; draw=0 —
# regenerate does one redraw at the end).
proc wviewer::place_graph_rect {x1 y1 x2 y2 props} {
  set save [xschem get rectcolor]
  xschem set rectcolor 2
  xschem rect $x1 $y1 $x2 $y2 -1 $props 0
  xschem set rectcolor $save
}

# Display `rawfile` (sim type `sim_type`) in the viewer of `token` — thin
# MODEL wrapper (D12): ensure graph 0 exists, append a trace bound to
# `node`, load the raw file, regenerate. `rawfile` {} (or missing) records
# the trace only. Returns 1, or 0 for an unknown token.
proc wviewer::display_raw {token rawfile sim_type node {color 4}} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set wp [dict get $windows $token win_path]
  # issue 0194: fold FIRST — before the trace append below (the 1:1 rect/model
  # guard would refuse a capture placed after it, silently) and before the `gs`
  # read (capture writes through set_graphs).
  wviewer::capture_live_view_state $token
  set gs [dict get [wviewer::layout_for $token] graphs]
  if {![llength $gs]} { set gs [list [wviewer::empty_graph]] }
  set G [lindex $gs 0]
  set trs [dict get $G traces]
  lappend trs [dict create expr $node name {} vec $node color $color]
  set G [dict replace $G traces $trs]
  wviewer::set_graphs $token [lreplace $gs 0 0 $G]
  if {$rawfile ne {} && [file isfile $rawfile]} {
    xschem new_schematic switch $wp
    xschem raw read $rawfile $sim_type
  }
  wviewer::regenerate $token
  return 1
}

# Attach (or REPLACE) the raw data of `token`'s viewer (item 13, D9): switch
# to the viewer ctx, unload whatever raw the ctx holds, read `rawfile` as
# `sim_type` ({} = let the engine pick the first analysis in the file),
# regenerate. Returns 1; 0 on an unknown token or a missing file (then NO
# clear happens — a stale-but-loaded raw beats an empty viewer). Re-run
# replace goes through this same helper. NOTE: the clear also kills every
# `xschem raw add` vector — ase::ui::auto_plot re-adds its own on rebuild
# (`raw add` of an existing name recalculates it); user-dialog expression
# traces (item 12) go stale-but-CLEAN: the engine draws nothing for an
# unresolved node and redraw keeps rc 0 (test-asserted).
proc wviewer::attach_raw {token rawfile sim_type} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  if {$rawfile eq {} || ![file isfile $rawfile]} { return 0 }
  if {![wviewer::switch_ctx $token]} { return 0 }   ;# never clear a foreign ctx
  # issue 0194: a re-run replaces the DATA, not the plot — the strips, the
  # traces and which of them the user had selected all carry forward, so the
  # regenerate below owes the fold. skip_ranges is what keeps a fresh run
  # autozooming instead of being drawn in the outgoing run's window.
  wviewer::capture_live_view_state $token
  catch {xschem raw clear}
  if {$sim_type ne {}} {
    xschem raw read $rawfile $sim_type
  } else {
    xschem raw read $rawfile
  }
  wviewer::regenerate $token
  return 1
}

# --- persistence (item 14, D5/D8) --------------------------------------------
# The ASE state's `viewer` key (doc/claude/specs/waveform_viewer.md): fixed
# build order `open <0|1> sharedx <0|1> rawfile {} graphs <model graph list>`
# so snapshots serialize byte-deterministically. Graphs go in VERBATIM from
# the model — incl. the `auto 1` marker (dropping it would make post-reload
# runs append a SECOND auto graph, receipts/13). Cursor state (cva/cvb/cvr)
# is NOT persisted: the mirrors die with the window by item-12 design.

# Snapshot of `token`'s viewer for the state dict. Window open -> `open 1` +
# the LIVE layout (sharedx + graphs; rawfile always {} in v1 = "the current
# run's raw" — a non-{} value is the hand-editable saved-results seam the
# restore side honors). Window closed -> the PREVIOUS dict with `open 0` and
# its graphs KEPT (last-known layout: wviewer::forget wiped the live model
# with the window, so the state dict is the only survivor); no previous dict
# -> {} (a session that never opened a viewer keeps a clean `viewer {}`).
proc wviewer::snapshot {token prev} {
  if {[wviewer::window_for $token] ne {}} {
    set lay [wviewer::layout_for $token]
    return [dict create open 1 \
                        sharedx [wviewer::dget $lay sharedx 0] \
                        rawfile {} \
                        graphs  [wviewer::dget $lay graphs {}] \
                        mode    [wviewer::plot_mode $token] \
                        target  [wviewer::target_index $token]]
  }
  if {$prev eq {}} { return {} }
  return [dict replace $prev open 0]
}

# Rebuild `token`'s viewer from a state `viewer` dict (ase::ui::viewer_restore
# orchestrates: raw resolution + the open-1 gate live THERE). Steps: open the
# window (headless returns 0 -> bail, no Tk side effects); OVERWRITE the
# layout from the dict (open zeroed it on a fresh window) + sync the Shared-X
# menu mirror; when a usable rawfile is given, attach it INLINE (raw clear +
# raw read, the attach_raw shape — attach_raw itself is NOT called: it
# regenerates internally and would double-regenerate before the trace
# re-materialize below) and RE-MATERIALIZE every multi-token RPN expression
# trace via `xschem raw add` (the raw clear killed those vectors; without the
# re-add restored traces draw empty and the readout interp throws — the RPNs
# were validated when the traces were created, so the catch is enough); ONE
# regenerate at the end. No usable rawfile -> regenerate alone (safe:
# autozoom only runs when `raw loaded >= 0`, redraw rc 0 on unresolved
# nodes). `sim_type` {} omits the `raw read` type word entirely (absent arg
# != empty arg in the C handler). Returns 1 when the viewer is up.
proc wviewer::restore {token vdict rawfile sim_type} {
  variable layouts
  variable sharedx
  variable mode; variable target
  if {![wviewer::open $token]} { return 0 }
  set sx [wviewer::dget $vdict sharedx 0]
  dict set layouts $token \
    [dict create sharedx $sx graphs [wviewer::dget $vdict graphs {}]]
  set sharedx($token) $sx
  # issue 0151: mode/target round-trip. Absent keys (every state file written
  # before 0151) fall back to the config default and strip 0, so old states
  # load unchanged. A garbage `mode` in a hand-edited state is rejected by
  # resolve_mode the same way a bad command argument is.
  set m [wviewer::resolve_mode single [wviewer::dget $vdict mode {}]]
  if {$m eq {}} { set m [wviewer::default_plot_mode] }
  set mode($token) $m
  set target($token) [wviewer::target_clamp [wviewer::dget $vdict target 0] \
                        [llength [wviewer::dget $vdict graphs {}]]]
  # the model has just been replaced wholesale: any undo point describes a
  # layout this window no longer has
  wviewer::clear_history $token
  # ...and so does any trace highlight, whose (gi, ni) addressed the strips that
  # were just discarded. D4 keeps the set out of the state dict, so there is
  # nothing to restore either -- it dies with the layout that produced it.
  wviewer::wave_hilight_clear_set $token
  if {$rawfile ne {} && [file isfile $rawfile] \
      && [wviewer::switch_ctx $token]} {
    catch {xschem raw clear}
    if {$sim_type ne {}} {
      xschem raw read $rawfile $sim_type
    } else {
      xschem raw read $rawfile
    }
    foreach G [dict get [wviewer::layout_for $token] graphs] {
      foreach tr [wviewer::dget $G traces {}] {
        set ex  [wviewer::dget $tr expr {}]
        set vec [wviewer::dget $tr vec {}]
        if {$vec ne {} \
            && [llength [regexp -all -inline {\S+} $ex]] > 1} {
          catch {xschem raw add $vec $ex}
        }
      }
    }
  }
  wviewer::regenerate $token
  return 1
}

# Append a trace to model graph `gi` of `token` (the Add Trace… core; also
# the scripting/test seam). `rpn` = a raw variable reference (single token)
# or a whitespace-separated RPN expression (D5: materialized as a raw
# vector named `name`/auto expr<N> via `xschem raw add`, so it then plots
# like any var). Returns {} on success or a user-displayable error message
# (never throws): D4 pre-validation, invalid names, missing raw data.
#
# `color` (issue 0153) pins the trace color instead of auto-cycling it. The
# Direct Plot picker uses it so the trace lands in exactly the color it already
# painted the schematic net with — the prediction and the plot then cannot
# disagree, whatever happened to the layout in between.
proc wviewer::add_trace {token gi rpn {name {}} {color {}}} {
  variable windows
  if {![dict exists $windows $token]} { return "unknown viewer window" }
  set rpn [string trim $rpn]
  if {$rpn eq {}} { return "empty expression - type one or pick a raw variable" }
  # issue 0194: fold before the append and before the `gs` read. NOTE for
  # plot_signals, which calls this in a loop: by then the strip count has
  # already grown, so this capture's 1:1 guard refuses and returns 0 — which is
  # exactly why plot_signals captures on its own instead of relying on this one.
  wviewer::capture_live_view_state $token
  set gs [dict get [wviewer::layout_for $token] graphs]
  if {![llength $gs]} { set gs [list [wviewer::empty_graph]] }
  if {![string is integer -strict $gi] || $gi < 0 || $gi >= [llength $gs]} {
    set gi [expr {[llength $gs] - 1}]
  }
  if {![wviewer::switch_ctx $token]} {
    return "viewer window busy - cannot switch context"
  }
  set rawok [expr {[xschem raw loaded] >= 0}]
  set varlist {}
  if {$rawok} { set varlist [split [xschem raw list] "\n"] }
  if {[llength [regexp -all -inline {\S+} $rpn]] > 1} {
    # RPN expression trace (D5)
    if {!$rawok} { return "no raw data loaded - cannot evaluate an expression" }
    set err [wviewer::validate_rpn $rpn $varlist]
    if {$err ne {}} { return $err }
    if {$name eq {}} {
      set name [wviewer::auto_expr_name $token]
    } elseif {![regexp {^[A-Za-z_][A-Za-z0-9_]*$} $name]} {
      return "invalid name '$name' (expression names become raw vector names: letters, digits, _)"
    }
    xschem raw add $name $rpn
    set vec $name
  } else {
    # plain vector reference; validated only when raw data is present (a
    # trace may be recorded before the first run — item 13 wires raws)
    if {$rawok} {
      set err [wviewer::validate_rpn $rpn $varlist]
      if {$err ne {}} { return $err }
    }
    if {[regexp {[";\\]} $name]} {
      return "invalid display name '$name' (quotes, semicolons and backslashes break the node grammar)"
    }
    set vec $rpn
  }
  set G [lindex $gs $gi]
  set trs [dict get $G traces]
  set col $color
  if {$col eq {}} { set col [wviewer::next_color $G] }
  lappend trs [dict create expr $rpn name $name vec $vec color $col]
  set G [dict replace $G traces $trs]
  wviewer::set_graphs $token [lreplace $gs $gi $gi $G]
  wviewer::regenerate $token
  return {}
}

# Graph > Add Graph: append an empty stacked graph (renders as an empty
# grid) + regenerate.
proc wviewer::add_graph {token} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  wviewer::capture_live_view_state $token   ;# issue 0194: before the append
  set gs [dict get [wviewer::layout_for $token] graphs]
  lappend gs [wviewer::empty_graph]
  wviewer::set_graphs $token $gs
  wviewer::regenerate $token
  return 1
}

# --- plot mode / target strip: the window-facing surface (issue 0151) --------
# doc/claude/specs/waveform_viewer_modes.md §7. Every command here is
# CIW-typable, takes an OPTIONAL token (omitted = the viewer window that owns
# the current xschem context) and is honest instead of throwing: {} plus a
# ciw_echo when nothing resolves.

# The replayable-log seam (the slickprop::log_apply pattern): one catch'd
# `xschem log_action`, so a test can rename it and spy. log_action mirrors
# into the CIW pane, which is what "logged replayably in the CIW" means.
proc wviewer::log_action {line} {
  catch {xschem log_action $line}
}

# The viewer token owning the CURRENT xschem context, or {}. The C context —
# not Tk focus — is the source of truth for "the active window" everywhere in
# this tree.
proc wviewer::current_token {} {
  if {[catch {xschem get current_win_path} wp]} { return {} }
  if {$wp eq {}} { return {} }
  return [wviewer::token_for_canvas $wp]
}

# Internal: {} token -> the active viewer window's token.
proc wviewer::resolve_token {token} {
  if {$token ne {}} { return $token }
  return [wviewer::current_token]
}

# Current plot mode of a viewer window (single|multi), or {} when the token
# resolves to no OPEN viewer (mode is per-window state; it does not exist
# before the window does).
proc wviewer::plot_mode {{token {}}} {
  variable mode
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![info exists mode($token)]} { return {} }
  return $mode($token)
}

# Set / flip the plot mode. `req` is single | multi | invert (case-
# insensitive). Returns the RESOLVED mode, or {} when the window or the
# request word is bad. Logs `wviewer::set_plot_mode <resolved> <token>` on an
# actual change only — the resolved word (never `invert`) and the explicit
# token, so replay does not depend on the state or the active window at
# replay time.
proc wviewer::set_plot_mode {req {token {}}} {
  variable mode
  set token [wviewer::resolve_token $token]
  set cur [wviewer::plot_mode $token]
  if {$cur eq {}} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to set the plot mode on" error
    }
    return {}
  }
  set new [wviewer::resolve_mode $cur $req]
  if {$new eq {}} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: bad plot mode '$req' (use single, multi or invert)" error
    }
    return {}
  }
  if {$new eq $cur} { return $cur }
  set mode($token) $new
  # item 10: PUSH the status bar from the ONE mutation site, immediately after
  # the model write. The Options-menu label is pull-only (-postcommand); without
  # this push the status bar would go stale whenever the mode changed by any
  # other route (ase::plot_mode_for_current, state restore, the chord).
  catch {wviewer::status_refresh $token}
  wviewer::log_action [list wviewer::set_plot_mode $new $token]
  return $new
}

# The EFFECTIVE target strip index of `token`: the stored value clamped to the
# live graph count (0 for an empty layout). The only read seam — a strip
# deleted since the target was set can never dangle.
proc wviewer::target_index {token} {
  variable target
  if {$token eq {} || ![info exists target($token)]} { return 0 }
  set n [llength [dict get [wviewer::layout_for $token] graphs]]
  return [wviewer::target_clamp $target($token) $n]
}

# Command form: the target strip of a viewer window, or {} when none resolves.
proc wviewer::target_strip {{token {}}} {
  variable target
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![info exists target($token)]} { return {} }
  return [wviewer::target_index $token]
}

# Move the target strip. Returns the CLAMPED index actually in force, or {}
# when no viewer resolves. Logged like the mode, and for the same reason: a
# plot sequence is only replayable if the target moves are in the log. No
# change -> no log line, so a click that lands on the current target is silent.
#
# The marker is moved by REWRITING THE `active` TOKEN IN PLACE, never by
# regenerate. regenerate re-places every rect from the Tcl MODEL, and the C
# engine writes its own graph state (RMB box-zoom / graph pan ranges, private
# cursors) straight into the rect prop where the model never sees it — so
# regenerating here would silently throw away a zoom the user just made with
# the mouse, on EVERY re-target click. Every other Tcl range mutator avoids
# that by freezing the live ranges first (graph_range/apply_range); a
# marker-only edit does not need the model at all.
proc wviewer::set_target_strip {gi {token {}}} {
  variable target
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![info exists target($token)]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to set the target strip on" error
    }
    return {}
  }
  set n [llength [dict get [wviewer::layout_for $token] graphs]]
  set new [wviewer::target_clamp $gi $n]
  set cur [wviewer::target_index $token]
  set target($token) $new
  if {$new eq $cur} { return $new }
  wviewer::log_action [list wviewer::set_target_strip $new $token]
  wviewer::move_marker $token $cur $new
  return $new
}

# Repaint the active-strip marker after a target move: clear the `active` token
# on `from`, set it on `to`, redraw. Only while more than one strip is up (one
# strip has nothing to disambiguate — same rule regenerate applies). Rect
# writes are readonly-gated, hence with_edit; a refused context switch (raised
# semaphore) just leaves the marker until the next regenerate.
proc wviewer::move_marker {token from to} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set n [llength [dict get [wviewer::layout_for $token] graphs]]
  if {[catch {
    wviewer::with_edit $token {
      if {$n > 1} {
        if {$from ne $to && $from >= 0 && $from < $n} {
          # empty value CLEARS the token (probe-verified), so an inactive strip
          # reads exactly as regenerate would have written it: no `active` at all
          xschem setprop -fast rect 2 $from active {}
        }
        if {$to >= 0 && $to < $n} {
          xschem setprop -fast rect 2 $to active 1
        }
      }
      xschem redraw
    }
  }]} { return 0 }
  return 1
}

# Strip under a CANVAS PIXEL, from the graphbb registry, or -1. Pixel ->
# schematic is the inverse of X_TO_SCREEN (xschem.h): x = px*zoom - xorigin
# (viewport_rect uses the same identity). Deliberately NOT graph_at_pointer:
# that one reads the C-tracked mousex_snap, which a synthetic press without a
# preceding Motion leaves stale.
proc wviewer::strip_at_pixel {wp px py} {
  variable graphbb
  if {![dict exists $graphbb $wp]} { return -1 }
  if {[catch {xschem new_schematic switch $wp}]} { return -1 }
  if {[xschem get current_win_path] ne $wp} { return -1 }
  set zoom [xschem get zoom]
  set mx [expr {$px * $zoom - [xschem get xorigin]}]
  set my [expr {$py * $zoom - [xschem get yorigin]}]
  set gi 0
  foreach bb [dict get $graphbb $wp] {
    lassign $bb bx1 by1 bx2 by2
    if {$mx >= $bx1 && $mx <= $bx2 && $my >= $by1 && $my <= $by2} { return $gi }
    incr gi
  }
  return -1
}

# <ButtonPress-1> on the viewer canvas: the clicked strip becomes the target.
# Silent when the pointer is outside every band or the strip is already the
# target. The C engine's own press handling (cursor grab / graph pan) is
# forwarded by the binding, not by this proc.
proc wviewer::click_target {W px py} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  set gi [wviewer::strip_at_pixel $W $px $py]
  if {$gi < 0} { return {} }
  if {$gi == [wviewer::target_index $token]} { return $gi }
  return [wviewer::set_target_strip $gi $token]
}

# --- strip drag reordering ---------------------------------------------------
# doc/claude/specs/waveform_viewer_modes.md §12. A STRIP is one graph of
# `layouts`, traces and all; reordering it is therefore a list move on the model
# graph list and nothing else. The dictionary carries its traces, colors, axis
# settings, the `auto 1` marker and any future per-graph key for free — never
# rebuild a graph field by field here.
#
# Three layers, deliberately separated so the policy is unit-testable headless:
#   PURE      reorder_graphs / reordered_index  (list math, no window)
#   MODEL     move_strip                        (the ONE authoritative mutation)
#   GESTURE   strip_drag_press/motion/release   (Tk bindings, pixels)

# PURE: move element `from` of `graphs` so that it ENDS UP at index `to`.
#   A B C D, from 1, to 3  ->  A C D B
# `to` is the FINAL index of the moved element, not an insertion slot: the two
# differ whenever the move goes downward, and every caller/test in this tree
# reads it the first way. Out-of-range or non-integer indices return the list
# UNCHANGED (a pure list op has no channel to report an error, and the callers
# validate; move_strip is where a bad index is refused loudly).
proc wviewer::reorder_graphs {graphs from to} {
  set n [llength $graphs]
  if {![string is integer -strict $from] || ![string is integer -strict $to]} {
    return $graphs
  }
  if {$from < 0 || $from >= $n || $to < 0 || $to >= $n || $from == $to} {
    return $graphs
  }
  set el [lindex $graphs $from]
  return [linsert [lreplace $graphs $from $from] $to $el]
}

# PURE: where the graph that sat at `index` BEFORE a `from`->`to` move sits
# AFTER it. This is how the target strip (and any other index-held reference)
# follows graph IDENTITY instead of staying attached to a numeric slot.
#   move 1->3 in {A B C D}: 1->3 (the moved one), 2->1, 3->2, 0->0
proc wviewer::reordered_index {index from to} {
  foreach v [list $index $from $to] {
    if {![string is integer -strict $v]} { return $index }
  }
  if {$index == $from} { return $to }
  if {$from < $to} {
    if {$index > $from && $index <= $to} { return [expr {$index - 1}] }
  } elseif {$from > $to} {
    if {$index >= $to && $index < $from} { return [expr {$index + 1}] }
  }
  return $index
}

# --- strip DELETION, the pure half (viewer plan item 5) ----------------------
# The move-time procs above have deletion twins, and they are genuinely
# different arithmetic: a move preserves the element count, a deletion does not,
# so reordered_index cannot serve here however close it looks.

# PURE: `graphs` with the elements at `indices` removed. Out-of-range and
# non-integer entries are ignored, duplicates are harmless. Removal runs TOP
# DOWN (indices sorted decreasing) so an lreplace can never shift an index that
# has not been used yet — the discipline delete_ok already uses for traces.
proc wviewer::remove_graphs {graphs indices} {
  set n [llength $graphs]
  set kill {}
  foreach i $indices {
    if {[string is integer -strict $i] && $i >= 0 && $i < $n} { lappend kill $i }
  }
  foreach i [lsort -integer -decreasing -unique $kill] {
    set graphs [lreplace $graphs $i $i]
  }
  return $graphs
}

# PURE: where the graph that sat at `index` BEFORE the removal of `removed`
# sits AFTER it — the deletion twin of reordered_index, and how a stored target
# follows graph IDENTITY instead of staying attached to a numeric slot.
#   remove {1 2} from {A B C D}:  0 -> 0,  3 -> 1
# An index that was ITSELF removed answers with the slot the following strip
# now occupies (the strip that took its place), which for the last strip is one
# past the end. That is deliberate and safe: target_index runs every read
# through target_clamp, so "one past the end" resolves to the last survivor
# rather than dangling.
# Duplicates in `removed` are counted ONCE — a doubled index would otherwise
# shift the answer twice and silently move the target up a strip.
proc wviewer::index_after_removal {index removed} {
  if {![string is integer -strict $index]} { return $index }
  set seen {}
  set below 0
  foreach r $removed {
    if {![string is integer -strict $r]} continue
    if {[lsearch -exact $seen $r] >= 0} continue
    lappend seen $r
    if {$r < $index} { incr below }
  }
  return [expr {$index - $below}]
}

# PURE: where the graph that sat at `index` BEFORE `count` strips were inserted
# at `at` sits AFTER — the INSERT twin of index_after_removal above, and
# plot_signals' multi-plot arithmetic (`cur + nnew`, ~3306) generalised to an
# arbitrary insertion point.
#   insert 2 at 1 in {A B C}:  0 -> 0,  1 -> 3,  2 -> 4
# An index EQUAL to `at` shifts, because the inserted strips take that slot and
# push the incumbent down — the opposite convention to index_after_removal's
# "answer with the slot your follower took", and right for the same reason: in
# both cases the answer is where the ORIGINAL graph ended up.
#
# ⚠ Item 7 does NOT use this, though the plan said it would: a single-trace
# separate-strip move makes the DESTINATION the target (move_trace step 6), so
# the shift would be overwritten. Item 8's split has no single destination and
# leaves the target on whatever strip it was on, which is what this is for.
proc wviewer::index_after_insert {index at {count 1}} {
  if {![string is integer -strict $index]} { return $index }
  if {![string is integer -strict $at]} { return $index }
  if {![string is integer -strict $count] || $count <= 0} { return $index }
  if {$index >= $at} { return [expr {$index + $count}] }
  return $index
}

# PURE: the strips `e` deletes — every traceless strip, minus two exceptions.
# Both exceptions are user decisions recorded in
# doc/claude/suggestions/plan_viewer_enhancements_2026-07.md; they live here,
# in a pure proc, so they can be asserted headless with literal lists.
#
# D-D, SPARE THE AUTO-PLOT STRIP: it is REBUILT after every simulation run
# (traces cleared, then re-added — item 13's always-replace contract), so it is
# legitimately traceless BETWEEN runs. Deleting it would destroy tool state the
# user cannot see, and the next run would silently append a fresh one.
# `empty_graph_indices` already takes the exclusion as its `auto` argument;
# callers pass wviewer::auto_graph_index, and -1 means "no auto strip".
#
# D-C, KEEP ONE: right after Ctrl-D the model is exactly ONE empty strip, so a
# literal "delete every empty strip" would empty the window. That would not
# crash — regenerate handles n == 0 and `graphs {}` is the legal fresh-open
# state — but clear_all deliberately maintains a one-strip invariant and `e`
# must not quietly break it. When every strip would go, index 0 is spared: the
# lowest index, which is where clear_all's own survivor sits.
# Consequence, and the intended one: `e` on a window holding a single empty
# strip returns an EMPTY kill list, which the mutating proc treats as a no-op
# and does not log.
proc wviewer::empty_strips_to_delete {gs {auto -1}} {
  set kill [wviewer::empty_graph_indices $gs $auto]
  if {[llength $kill] > 0 && [llength $kill] >= [llength $gs]} {
    set kill [lrange $kill 1 end]
  }
  return $kill
}

# Fold the state the C engine wrote straight into the live rects back into the
# Tcl model, so a regenerate cannot undo it.
#
# WHY this exists: `regenerate` re-places every rect FROM the model, and the C
# waveform engine writes its own results (MMB graph pan, RMB box-zoom, the LMB
# wave-bold) into the rect prop text where the model never sees them. Any Tcl
# op that regenerates must therefore freeze the live values first — the same
# rule graph_range/apply_range follow for zoom, generalized. Without it a
# reorder would silently throw away the pan the user just made.
#
# Reads x1/x2/y1/y2 and hilight_wave. An ABSENT/-1 hilight_wave DELETES the
# model key rather than storing -1, so a strip nobody ever clicked keeps
# generating exactly the props it did before (graph_props emits the token only
# when the key is present). Cursors are NOT captured: the viewer creates its
# graphs with `flags=graph`, not `private_cursor`, so cursor positions are
# global (xctx->graph_cursor1_x/2_x) and survive a rect rebuild untouched — if
# that ever changes, cursor1_x/cursor2_x/hcursor1_y/hcursor2_y join this list.
# Returns 1, or 0 on an unknown token / refused context switch (never read a
# rect prop from an unverified context).
#
# `skip_markers` 1 leaves the markers key alone. marker_changed needs that: it
# wants the LIVE ranges/bold folded in before it takes its undo snapshot, but
# the snapshot must still hold the PRE-change markers, or `u` would restore the
# very marker it was meant to remove.
#
# `skip_ranges` 1 folds the SELECTION (and the markers) and does not touch
# x1/x2/y1/y2 at all (issue 0194). It is what makes this proc usable from the
# regenerate sites that are not content edits, and both halves of that are
# load-bearing:
#
#   * it must not PIN. The ranges do not follow the absent-means-absent rule the
#     other keys do: graph_props always emits a concrete x1/x2/y1/y2
#     (substituting a placeholder for a model `{}`) and regenerate's autozoom
#     overwrites them with the fullx/fullyzoom fit, so `xschem getprop rect 2
#     $gi x1` is NEVER empty. An unconditional capture therefore turns every
#     `{}` axis — "autozoom on every regenerate" — into a frozen number for
#     EVERY strip, empty ones included, and the next Direct Plot into an auto
#     strip lands off-screen. The seven pre-0194 callers are content gestures
#     that accept that (move_trace_in_graphs even re-blanks the destination
#     afterwards because of it); a window option or a resize must not.
#   * it must not REFRESH A PINNED AXIS EITHER, which is subtler and was caught
#     in review. Under `sharedx 1` regenerate writes graph 0's x into every
#     other strip's RECT while the model deliberately keeps each strip's own —
#     that non-destructiveness is the whole point of Shared X. Reading a pinned
#     x back off the rect therefore copies graph 0's window over every other
#     strip's stored one, permanently and with no undo point, so un-sharing
#     would no longer reveal the per-strip ranges. Ranges are a separate class
#     with its own documented lifetime (spec §17.4): a C-written pan/zoom the
#     model never saw is discarded by the next regenerate, exactly as before
#     this issue. 0194 changes what happens to the SELECTION and nothing else.
proc wviewer::capture_live_graph_state {token {skip_markers 0} {skip_ranges 0}} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  if {![wviewer::switch_ctx $token]} { return 0 }
  set gs [dict get [wviewer::layout_for $token] graphs]
  # Same 1:1 rect/model guard marker_changed carries, and for a stronger reason:
  # this path also DELETES (an absent token takes the `dict remove` branch), so a
  # count desync would attach one strip's state to another model graph AND wipe
  # the keys of every model graph past the last rect.
  set nrect -1
  catch {set nrect [xschem get graph_rects]}
  if {[string is integer -strict $nrect] && $nrect != [llength $gs]} { return 0 }
  set out {}
  set gi 0
  foreach G $gs {
    foreach tok {x1 x2 y1 y2} {
      # issue 0194: the ranges are the CONTENT-gesture half of this proc. See
      # the header for why a selection fold must not write them at all — an
      # auto axis would be pinned, and a pinned one would be overwritten with
      # graph 0's window whenever Shared X is on.
      if {$skip_ranges} { continue }
      set v {}
      catch {set v [xschem getprop rect 2 $gi $tok]}
      if {[string is double -strict $v]} { dict set G $tok $v }
    }
    set hw {}
    catch {set hw [xschem getprop rect 2 $gi hilight_wave]}
    if {[string is integer -strict $hw] && $hw >= 0} {
      dict set G hilight_wave $hw
    } elseif {[dict exists $G hilight_wave]} {
      set G [dict remove $G hilight_wave]
    }
    # the REST of the selection (issue 0175), same absent-means-absent shape.
    # It must be captured or a multi-select would silently collapse to one trace
    # on the next regenerate — and regenerate runs on a plain window RESIZE.
    # (`hilight_wave` has always had that same exposure on the ~15 regenerate
    # sites that do NOT capture first; selection is view state, landmine 19, so
    # this deliberately does not grow a C push hook the way markers needed one.)
    set sw {}
    catch {set sw [xschem getprop rect 2 $gi sel_waves]}
    set swl [wviewer::sel_waves_norm $sw]
    if {[llength $swl] >= 2} {
      dict set G sel_waves $swl
    } elseif {[dict exists $G sel_waves]} {
      set G [dict remove $G sel_waves]
    }
    # markers (doc/claude/specs/graph_markers.md), same absent-means-absent
    # shape as hilight_wave right above. The guard is STRUCTURAL
    # (markers_valid), not `string is` — the value is a multi-line record list.
    # This is the PULL half; it only runs on the three paths that call this
    # proc, which is exactly why the C engine also PUSHES (marker_changed).
    if {!$skip_markers} {
      set mk {}
      catch {set mk [xschem getprop rect 2 $gi markers]}
      if {$mk ne {} && [wviewer::markers_valid $mk]} {
        dict set G markers $mk
      } elseif {[dict exists $G markers]} {
        set G [dict remove $G markers]
      }
    }
    lappend out $G
    incr gi
  }
  wviewer::set_graphs $token $out
  return 1
}

# THE FOLD EVERY NON-STRUCTURAL REGENERATE OWES (issue 0194).
#
# The rule, stated once so the next window option does not have to rediscover
# it: regenerate does `xschem clear_drawing` and re-places every rect purely
# from the Tcl model, so ANY state the C engine wrote straight into a rect —
# the selection (`hilight_wave` + `sel_waves`, issue 0175), an MMB pan, an RMB
# box zoom — dies unless it was folded back first. A command that means to
# CARRY FORWARD the strips currently on the canvas must therefore capture,
# whatever else it is: a window OPTION (grid, Shared X), a pure repaint
# (configure_apply, i.e. a plain window RESIZE), a range edit or a trace/strip
# addition. "It is only a window option, not model content" is a valid reason
# to skip `push_undo` — window options stay outside the undo stack, spec
# waveform_viewer_modes.md §14 — and NEVER a reason to skip the capture: the
# capture is about surviving clear_drawing, not about undo.
# The three exemptions are the procs that REPLACE the model wholesale and would
# fold the outgoing window's rects on top of the incoming model: `restore`,
# `state_apply` (its caller history_step captures) and `clear_all`. Plus
# `delete_all_markers`, which must not regenerate at all.
#
# The `skip_ranges` form is what makes this safe here (see the header above):
# it folds the SELECTION and leaves every axis exactly as it was, so nothing
# about range lifetime changes — an auto axis is not pinned, and a pinned one is
# not overwritten with graph 0's window under Shared X.
#
# Ordering, and it is mechanical: call this AFTER any `switch_ctx` guard, BEFORE
# any structural mutation (its 1:1 rect-vs-model guard fails SILENTLY, so a
# capture placed after an add/remove is a no-op that looks installed), and
# BEFORE reading `$gs`/`$lay` — it writes through set_graphs, so a list read
# earlier is stale and writing it back would revert the capture.
proc wviewer::capture_live_view_state {token} {
  return [wviewer::capture_live_graph_state $token 0 1]
}


# --- the C -> Tcl marker push hook -------------------------------------------

# Called by draw.c graph_marker_notify() after every marker create / delete /
# drag-COMMIT — never per motion event. A GLOBAL proc because the C side calls
# it through tcleval() with no namespace context; the body is one delegation.
# Return codes, which C logs when they are neither 1 nor 2:
#   1 model updated   2 not a viewer window (nothing to do)
#   0 bailed          -1 a Tcl error was caught here
# A silent bail resurfaces much later as "my markers vanished on resize" with no
# diagnostic anywhere, so every non-success is reported.
proc graph_marker_changed {} {
  set r 0
  if {[catch {set r [wviewer::marker_changed]} e]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      catch {ciw_echo "wviewer: marker push failed: $e" error}
    }
    return -1
  }
  return $r
}

# Fold every graph rect's live `markers` token back into the model.
#
# WHY A PUSH AND NOT A PULL. wviewer::regenerate does `xschem clear_drawing` and
# re-places every rect from graph_props, and it is called from ~18 sites —
# including configure_apply, i.e. a plain WINDOW RESIZE. Only three of those
# first call capture_live_graph_state. A pull-only design therefore loses every
# marker the moment the user resizes the window, with no action that reads as
# destructive. Pushing on change keeps the model current at all times.
#
# READ-ONLY on the schematic side (getprop only), so it needs no with_edit: it
# writes nothing into the rects, only into the Tcl model.
proc wviewer::marker_changed {} {
  set wp {}
  catch {set wp [xschem get current_win_path]}
  if {$wp eq {}} { return 0 }
  set token [wviewer::token_for_canvas $wp]
  if {$token eq {}} { return 2 }        ;# not a viewer window: legitimately nothing to do
  set gs [dict get [wviewer::layout_for $token] graphs]
  # index-space safety: the rects and the model must be 1:1 right now. They
  # always are at hook time (no regenerate is in flight), but a mismatch has to
  # BAIL rather than attach strip 0's markers to a different model graph.
  # `graph_rects` counts GRAPH rects — deliberately not `xschem get rects 2`,
  # which is every layer-2 rect, so one stray non-graph rect would permanently
  # disable the hook.
  set nrect -1
  catch {set nrect [xschem get graph_rects]}
  if {$nrect != [llength $gs]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      catch {ciw_echo "wviewer: marker push skipped (rects=$nrect model=[llength $gs])" error}
    }
    return 0
  }
  # Fold the live rect state (MMB pan / RMB box-zoom ranges, the wave-bold) into
  # the model FIRST, exactly as move_strip and move_trace do, so the undo
  # snapshot below is "what the user was looking at" and one `u` does not also
  # revert an unrelated pan. `skip_markers 1`: the markers are the change being
  # recorded, and capturing them here would put them INSIDE the restore point.
  wviewer::capture_live_graph_state $token 1
  set gs [dict get [wviewer::layout_for $token] graphs]
  set out {}
  set gi 0
  set changed 0
  foreach G $gs {
    set mk {}
    catch {set mk [xschem getprop rect 2 $gi markers]}
    if {$mk ne {} && [wviewer::markers_valid $mk]} {
      if {[wviewer::dget $G markers {}] ne $mk} { set changed 1 }
      dict set G markers $mk
    } elseif {[dict exists $G markers]} {
      set G [dict remove $G markers]
      set changed 1
    }
    lappend out $G
    incr gi
  }
  if {!$changed} { return 1 }          ;# no phantom undo point for a no-op notify
  # UNDO POINT FIRST. push_undo records the CURRENT state as the restore point
  # ("called by a mutating command BEFORE it changes anything") and history_step
  # pops that snapshot and applies it. Snapshotting AFTER set_graphs would store
  # the POST-marker model, so `u` would restore the very marker it was meant to
  # remove. Shipped order: move_strip, move_trace.
  wviewer::push_undo $token
  wviewer::set_graphs $token $out
  return 1
}

# THE authoritative strip move. `to` is the FINAL index the strip ends up at.
# Returns that index, or {} on failure (unknown viewer, bad index, busy ctx).
#
# Steps, in this order and for these reasons:
#   1. resolve + validate both indices against the LIVE graph count
#   2. from == to -> return without mutating and WITHOUT logging (a drop back
#      where it started is not a state change; a replay must not contain it)
#   3. verify the context switch (capture reads rect props; switch_ctx silently
#      no-ops under a raised semaphore — landmine 17)
#   4. capture the live C-written state, so the regenerate below cannot undo a
#      pan/zoom/bold made with the mouse
#   5. reorder the graph list — one list move, dictionary carried whole
#   6. remap the stored TARGET with reordered_index, in place. NOT through
#      set_target_strip: that would emit a SECOND replay-log line for an index
#      change that is an internal consequence of this one command
#   7. exactly ONE regenerate (which re-places the rects and repaints `active=1`
#      on the reordered target)
#   8. exactly ONE fully-resolved log line
# The `auto 1` marker rides along inside the moved dictionary — the auto-plot
# graph is an ordinary strip as far as ordering is concerned.
proc wviewer::move_strip {from to {token {}}} {
  variable windows
  variable target
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to reorder strips in" error
    }
    return {}
  }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set n [llength $gs]
  foreach v [list $from $to] {
    if {![string is integer -strict $v] || $v < 0 || $v >= $n} {
      if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
        ciw_echo "wviewer: bad strip index '$v' (0..[expr {$n - 1}])" error
      }
      return {}
    }
  }
  if {$from == $to} { return $to }
  if {![wviewer::switch_ctx $token]} { return {} }
  wviewer::capture_live_graph_state $token
  wviewer::push_undo $token           ;# AFTER the capture: `u` restores the view
  set gs [dict get [wviewer::layout_for $token] graphs]
  wviewer::set_graphs $token [wviewer::reorder_graphs $gs $from $to]
  if {[info exists target($token)]} {
    set target($token) \
      [wviewer::reordered_index [wviewer::target_index $token] $from $to]
  }
  # the trace highlights are keyed by (gi, ni) and `gi` just moved (§8). Remapped
  # IN PLACE, never through set_wave_hilights, for the same reason the target is:
  # that proc emits its own replay line, and this is an internal consequence of
  # the reorder, not a second user action.
  wviewer::wavehl_remap_apply $token \
    [wviewer::wavehl_after_strip_move [wviewer::wave_hilights $token] $from $to]
  wviewer::regenerate $token
  wviewer::log_action [list wviewer::move_strip $from $to $token]
  return $to
}

# --- drag hit testing (canvas PIXELS) ----------------------------------------
# All of these take the EVENT's own %x/%y. graph_at_pointer is deliberately NOT
# used: it reads the C mouse-position mirror, which is stale for a press that
# had no preceding Motion (the strip_at_pixel precedent, issue 0151).

# The graphbb bands of viewer canvas `wp` as CANVAS PIXEL rects
# {px1 py1 px2 py2}, in model order. Inverts X_TO_SCREEN (xschem.h):
# pixel = (schematic + origin) / zoom. {} on an unknown canvas / refused switch.
proc wviewer::strip_bands_px {wp} {
  variable graphbb
  if {![dict exists $graphbb $wp]} { return {} }
  if {[catch {xschem new_schematic switch $wp}]} { return {} }
  if {[xschem get current_win_path] ne $wp} { return {} }
  set zoom [xschem get zoom]
  if {$zoom == 0} { return {} }
  set xo [xschem get xorigin]
  set yo [xschem get yorigin]
  set out {}
  foreach bb [dict get $graphbb $wp] {
    lassign $bb bx1 by1 bx2 by2
    lappend out [list [expr {($bx1 + $xo) / $zoom}] [expr {($by1 + $yo) / $zoom}] \
                      [expr {($bx2 + $xo) / $zoom}] [expr {($by2 + $yo) / $zoom}]]
  }
  return $out
}

# Index of the strip whose REORDER HANDLE is under canvas pixel (px,py), else -1.
# The handle is the rightmost GRAPH_REORDER_HANDLE_W = 14 SCREEN PIXELS of the
# band, full band height — a fixed pixel width (not a fraction of the strip) so
# the target stays the same size at any canvas zoom. MIRRORED IN C: draw.c draws
# the grip inside this zone from the same constant in xschem.h; change both.
# Index of the strip containing canvas pixel (px,py) with `inset` screen pixels
# trimmed off every side, else -1. The inset is what keeps the MMB graph pan off
# the seam: waves_selected (callback.c) hit-tests the graph rect with a 5-pixel
# inner border, so a press in that outermost band is NOT graph-routed and would
# reach the schematic canvas pan instead — the exact gesture issue 0149 removed
# from this window. 8 px covers the 5-pixel border at tk scaling 1.5.
proc wviewer::strip_at_pixel_inset {canvas px py {inset 8}} {
  set gi 0
  foreach bb [wviewer::strip_bands_px $canvas] {
    lassign $bb bx1 by1 bx2 by2
    if {$px >= $bx1 + $inset && $px <= $bx2 - $inset && \
        $py >= $by1 + $inset && $py <= $by2 - $inset} { return $gi }
    incr gi
  }
  return -1
}

proc wviewer::strip_handle_at_pixel {canvas px py} {
  set gi 0
  foreach bb [wviewer::strip_bands_px $canvas] {
    lassign $bb bx1 by1 bx2 by2
    if {$py >= $by1 && $py <= $by2 && $px >= $bx2 - 14 && $px <= $bx2} { return $gi }
    incr gi
  }
  return -1
}

# The prospective DESTINATION index for a drag whose pointer is at canvas pixel
# row `py`. Band MIDPOINTS are the boundaries: dragging DOWN, the destination
# becomes strip k once the pointer passes k's midpoint; dragging UP, likewise in
# the other direction. Dragging past the top or the bottom of the stack clamps
# to the first / last strip.
#
# `from` (the grabbed strip) makes the rule SYMMETRIC — without it "the last
# midpoint crossed" is biased downward and an upward drag would propose a move
# one strip too early. Omitted (-1, the pure form) it falls back to "the band
# whose midpoint is nearest", which is what a caller with no gesture context
# wants. -1 when the canvas has no bands.
proc wviewer::strip_drop_index {canvas py {from -1}} {
  set mids {}
  foreach bb [wviewer::strip_bands_px $canvas] {
    lassign $bb bx1 by1 bx2 by2
    lappend mids [expr {($by1 + $by2) / 2.0}]
  }
  set n [llength $mids]
  if {$n <= 0} { return -1 }
  if {![string is integer -strict $from] || $from < 0 || $from >= $n} {
    set best 0
    set bd {}
    for {set k 0} {$k < $n} {incr k} {
      set d [expr {abs($py - [lindex $mids $k])}]
      if {$bd eq {} || $d < $bd} { set bd $d; set best $k }
    }
    return $best
  }
  if {$py < [lindex $mids $from]} {
    for {set k 0} {$k < $n} {incr k} {
      if {[lindex $mids $k] >= $py} { return $k }
    }
    return [expr {$n - 1}]
  }
  for {set k [expr {$n - 1}]} {$k >= 0} {incr k -1} {
    if {[lindex $mids $k] <= $py} { return $k }
  }
  return 0
}

# 1 when canvas pixel (px,py) is within `tol` screen pixels of a drawn trace of
# strip `gi` — the TRACE EXCLUSION ZONE. Answered by the C engine
# (`xschem get graph_near_wave`, draw.c) off its own transform and the raw data:
# approximating it in Tcl from the strip geometry would drift the moment
# margins, log axes or ranges change. Fails CLOSED (0 = "empty space") so a
# missing verb or an errored query cannot lock the user out of reordering.
# ⚠ the default MIRRORS GRAPH_TRACE_PICK_TOL (src/xschem.h, 10 screen px) --
# the single tolerance the wave-bold click, the trace menu, the trace drag and
# the strip-menu gate all share. Change both or the surfaces drift apart.
proc wviewer::near_wave_at {wp gi px py {tol 10}} {
  if {[catch {xschem new_schematic switch $wp}]} { return 0 }
  set r 0
  catch {set r [xschem get graph_near_wave $gi $px $py $tol]}
  if {$r eq {} || ![string is integer -strict $r]} { return 0 }
  return [expr {$r ? 1 : 0}]
}

# 1 when the press just handed to C armed a CURSOR move (graph_flags bits 16/32
# = x-cursor A/B grabbed, 512/1024 = y-cursor 1/2 grabbed). A cursor grab is a
# precise LMB interaction that can start anywhere in the strip, including far
# from every trace, so the trace exclusion zone alone would steal it.
proc wviewer::cursor_grabbed {wp} {
  if {[catch {xschem new_schematic switch $wp}]} { return 0 }
  set f 0
  catch {set f [xschem get graph_flags]}
  if {![string is integer -strict $f]} { return 0 }
  return [expr {($f & (16 | 32 | 512 | 1024)) ? 1 : 0}]
}

# 1 when the press just handed to C armed a MARKER drag (1 = the anchor slides
# along its trace, 2 = the label moves). The cursor_grabbed twin, and read the
# same way: `xschem get graph_marker_drag` answers for the CURRENT xctx, so with
# two viewer/editor windows open an unswitched read answers for the wrong one —
# hence the switch first. Fails CLOSED (0 = "no marker here") so a missing verb
# or an errored query degrades to the pre-marker behaviour.
proc wviewer::marker_grabbed {wp} {
  if {[catch {xschem new_schematic switch $wp}]} { return 0 }
  set d 0
  catch {set d [xschem get graph_marker_drag]}
  if {![string is integer -strict $d]} { return 0 }
  return [expr {$d ? 1 : 0}]
}

# 1 when the press just handed to C armed an AXIS-REGION DRAG ZOOM (issue 0190,
# doc/claude/specs/waveform_viewer_modes.md §17): an LMB drag in the bottom
# (X-number) or left (Y-number) margin of a strip. The marker_grabbed twin, in
# shape and in reason — switch ctx first (the query answers for the CURRENT
# xctx), fail CLOSED so a missing verb degrades to the pre-0190 behaviour.
#
# ⚠ The viewer deliberately does NOT hit-test the axis margins itself (D-22).
# C already decided, on the press this proc's caller forwarded to it, and asking
# is the whole point: a Tcl copy of the plot-box geometry would be a second
# source of truth for the 14% margins and the three different top-edge formulas.
# Contrast GRAPH_REORDER_HANDLE_W, which IS mirrored and carries a "change both"
# warning for exactly that reason.
proc wviewer::axis_grabbed {wp} {
  if {[catch {xschem new_schematic switch $wp}]} { return 0 }
  set a {}
  catch {set a [xschem get graph_axis_drag]}
  return [expr {($a eq {x} || $a eq {y}) ? 1 : 0}]
}

# The window-wide number of the SELECTED marker, or -1 for none / any error.
# Same context rule and same fail-closed rule as marker_grabbed above: -1 means
# "nothing selected", which is what the Delete gate in key_filter must conclude
# when it cannot get a trustworthy answer.
proc wviewer::marker_selected {wp} {
  if {[catch {xschem new_schematic switch $wp}]} { return -1 }
  set n -1
  catch {set n [xschem get graph_marker_sel]}
  if {![string is integer -strict $n]} { return -1 }
  return $n
}

# The WHOLE marker selection as a list of numbers, HEAD FIRST, or {} for none /
# any error (issue 0189). marker_selected above is its head and keeps its own
# meaning — the Delete SCOPE gate is still decided on the head, this is only
# what that gate then hands to delete_items. Same context rule and same
# fail-closed rule: {} means "nothing to delete", never "locked out".
proc wviewer::marker_selection {wp} {
  if {[catch {xschem new_schematic switch $wp}]} { return {} }
  set l {}
  catch {set l [xschem get graph_marker_sel_set]}
  if {[catch {llength $l}]} { return {} }
  set out {}
  foreach n $l { if {[string is integer -strict $n] && $n > 0} { lappend out $n } }
  return $out
}

# LMB DOUBLE-CLICK (issue 0189). On a marker: select it and, when it is a
# difference marker whose reference resolves, that reference too — the C policy
# `graph_marker select -pair` decides, so the viewer and the on-canvas graph
# cannot disagree about what a double-click means. Returns 1 when a marker was
# hit, 0 otherwise; the CALLER breaks unconditionally either way, because D9
# (no graph-properties dialog over a read-only viewer) must survive for every
# non-marker double-click.
#
# NO with_edit bracket, deliberately, unlike every neighbouring marker seam:
# `select` writes no token, pushes no undo point and sets no modify flag, and it
# is one of the three sub-verbs scheduler.c exempts from the readonly reject.
# Bracketing it would push a context switch plus four state writes onto a click
# AND hide the fact that this path is not a mutation.
# The token comes from %W, never the current ctx (the clear_all_at rule).
proc wviewer::marker_dblclick_at {W px py} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return 0 }
  if {[catch {xschem new_schematic switch $W}]} { return 0 }
  set gi [wviewer::strip_at_pixel $W $px $py]
  if {![string is integer -strict $gi] || $gi < 0} { set gi 0 }
  set hit {}
  catch {set hit [xschem get graph_marker_at $gi $px $py]}
  set num [lindex $hit 0]
  set part [lindex $hit 1]
  if {![string is integer -strict $num] || $num <= 0} { return 0 }
  if {$part ne {anchor} && $part ne {label}} { return 0 }
  catch {xschem graph_marker select -pair $num $gi}
  # the repaint the Tcl wrapper owes (the delete_all_markers_at precedent): the
  # partner may be on ANOTHER strip, so it is the whole window, not one rect
  catch {xschem redraw}
  return 1
}

# --- drag feedback (transient, on-screen only) -------------------------------

# Paint the prospective destination: clear the bar on `old`, put one on `new`.
# The bar rides on the SAME `reorder_handle` prop token as the grip (2 = bar on
# the strip's TOP edge, 3 = on its BOTTOM edge — the edge the dragged strip will
# arrive at, so the result reads off the screen), rewritten IN PLACE on the two
# affected rects and redrawn. Never a regenerate: regenerate re-places every rect
# from the model and would undo a live pan/zoom on every Motion (the
# move_marker argument, issue 0151), and mutating the stack mid-drag is exactly
# what the spec forbids. `new == from` means "back where it started" -> no bar.
proc wviewer::drag_feedback {token old new from} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set n [llength [dict get [wviewer::layout_for $token] graphs]]
  if {[catch {
    wviewer::with_edit $token {
      if {$old >= 0 && $old < $n} {
        xschem setprop -fast rect 2 $old reorder_handle 1
      }
      if {$new >= 0 && $new < $n && $new != $from} {
        xschem setprop -fast rect 2 $new reorder_handle \
          [expr {$new < $from ? 2 : 3}]
      }
      xschem redraw
    }
  }]} { return 0 }
  return 1
}

# Disarm: clear any drop bar, restore the pointer, forget the gesture. Safe to
# call when nothing is armed (every exit path funnels through it).
proc wviewer::strip_drag_reset {token} {
  variable windows
  variable drag_from; variable drag_to; variable drag_y0; variable drag_active
  set had 0
  if {[info exists drag_from($token)] && $drag_from($token) >= 0} { set had 1 }
  if {$had && [info exists drag_to($token)] && $drag_to($token) >= 0} {
    wviewer::drag_feedback $token $drag_to($token) -1 $drag_from($token)
  }
  set drag_from($token) -1
  set drag_to($token) -1
  set drag_y0($token) 0
  set drag_active($token) 0
  if {[dict exists $windows $token]} {
    catch {[dict get $windows $token win_path] configure -cursor {}}
  }
  return $had
}

# --- gesture seams (Tk bindings) ---------------------------------------------
# Each returns 1 when it CONSUMED the event (the binding then only `break`s) and
# 0 when it did not (the binding falls back to the pre-existing behaviour —
# target change, focus, C callback, break — byte for byte).

# <ButtonPress-1>. Resolves the strip from the event's own pixel, makes it the
# target, hands the press to the C engine VERBATIM, and then decides whether
# this press also arms a reorder:
#   - on the reorder HANDLE (right margin): always arms;
#   - elsewhere in the strip: arms only when the press landed on EMPTY waveform
#     space — not within the trace exclusion zone, and not on a press that just
#     grabbed a cursor. Those keep belonging to the C engine, so cursor drags,
#     cursor moves, trace picking and the wave-bold click are unchanged.
# The press is forwarded in BOTH cases, so the C engine's own bookkeeping
# (GRAPHPAN, the click anchor graph_press_x/y) stays consistent with what the
# matching release will do; the handle sits in the graph's right MARGIN, outside
# the plot body, so that forward can never produce a stray wave-bold.
# Modified presses (Shift/Ctrl/Alt) are not ours: Shift/Alt+B1 are swallowed by
# strip_bindings and Ctrl+B1 is the C engine's graph_use_ctrl_key arm.
proc wviewer::strip_drag_press {W px py state} {
  variable drag_from; variable drag_to; variable drag_y0; variable drag_active
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return 0 }
  if {$state & 13} { return 0 }                       ;# Shift|Control|Mod1
  set gi [wviewer::strip_at_pixel $W $px $py]
  if {$gi < 0} { return 0 }
  wviewer::strip_drag_reset $token                    ;# a stale arm must never survive
  wviewer::trace_drag_reset $token
  catch {focus $W}
  wviewer::set_target_strip $gi $token
  xschem callback $W 4 $px $py 0 1 0 $state
  if {[wviewer::strip_handle_at_pixel $W $px $py] != $gi} {
    # A press that armed a MARKER drag belongs to C for the WHOLE gesture, and
    # it must arm NEITHER Tcl gesture. This is not optional
    # (doc/claude/specs/graph_markers.md): a marker ANCHOR sits ON a trace by
    # construction, so trace_at below would return >= 0 and a >3 px drag would
    # move the TRACE to another strip instead of sliding the marker; a marker
    # LABEL sits in empty waveform space, where trace_at misses and
    # cursor_grabbed is 0, so the STRIP REORDER would arm and a >3 px vertical
    # drag would reorder the whole stack. Both failures are silent.
    #
    # It sits INSIDE the handle test, not before it, so the reorder GRIP keeps
    # unconditional first refusal — graph_marker_press declines the grip column
    # itself, so marker_grabbed can never be 1 for a press the grip owns.
    # Marker before cursor (below) is deliberate: an anchor is a smaller, more
    # intentional target than a full-height cursor line.
    if {[wviewer::marker_grabbed $W]} { return 1 }
    # An axis-region drag zoom (issue 0190) is C's for the whole gesture, for the
    # same reason the marker drag above is: the press has already been forwarded
    # to C, C armed it, and a >3 px drag here must zoom the axis rather than
    # reorder the stack. This is the ONLY place the viewer learns about the axis
    # regions — there is deliberately no Tcl hit test to drift (D-22). It sits
    # inside the handle test with the marker rung, so the reorder GRIP keeps
    # unconditional first refusal (graph_axis_at declines that column itself).
    # NO with_edit, unlike every neighbouring marker seam: a range write is view
    # state the engine has always been allowed to put in a read-only rect
    # (landmine 17 names the box zoom), so there is nothing to defeat.
    if {[wviewer::axis_grabbed $W]} { return 1 }
    # inside the trace zone the press is NOT a reorder. It is either a cursor
    # grab (the C engine's, and it wins — a cursor can be parked on top of a
    # trace) or a grab of the trace itself, which arms the trace drag.
    set ni [wviewer::trace_at $W $gi $px $py]
    set curs [wviewer::cursor_grabbed $W]
    if {$ni >= 0} {
      if {!$curs} { wviewer::trace_drag_arm $W $token $gi $px $py $ni }
      return 1
    }
    if {$curs} { return 1 }
  }
  set drag_from($token) $gi
  set drag_to($token) $gi
  set drag_y0($token) $py
  set drag_active($token) 0
  return 1
}

# <B1-Motion>. Below the 3-pixel vertical threshold the motion still belongs to
# the C engine (hover measurement, an in-flight cursor drag), so it is NOT
# consumed. Past the threshold the drag owns the pointer: the motion is
# swallowed, the pointer becomes a vertical-move cursor, and the prospective
# destination is repainted ONLY when it actually changes — never a model
# mutation, never a regenerate, per Motion event.
proc wviewer::strip_drag_motion {W px py state} {
  variable drag_from; variable drag_to; variable drag_y0; variable drag_active
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return 0 }
  # a press arms EITHER a trace drag or a strip reorder, never both; the trace
  # one is asked first because it is the more specific gesture
  if {[wviewer::trace_drag_motion $W $px $py $state]} { return 1 }
  if {![info exists drag_from($token)] || $drag_from($token) < 0} { return 0 }
  set from $drag_from($token)
  if {!$drag_active($token)} {
    if {abs($py - $drag_y0($token)) <= 3} { return 0 }
    set drag_active($token) 1
    wviewer::set_drag_cursor $W sb_v_double_arrow
  }
  set to [wviewer::strip_drop_index $W $py $from]
  if {$to < 0} { set to $from }
  if {$to != $drag_to($token)} {
    set old $drag_to($token)
    set drag_to($token) $to
    wviewer::drag_feedback $token $old $to $from
  }
  return 1
}

# <ButtonRelease-1>. Always hands the release to C (it is what clears GRAPHPAN
# and any armed cursor grab, and what completes a no-travel wave-bold click) and
# always refreshes the readout — this binding pre-empts the generic
# <ButtonRelease> that used to do both. A drag that PASSED the threshold and
# landed somewhere else then commits exactly one move_strip; a drop back on the
# origin, a sub-threshold press-release and a press that never armed all commit
# nothing and log nothing.
proc wviewer::strip_drag_release {W px py state} {
  variable drag_from; variable drag_to; variable drag_active
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return 0 }
  set armed [expr {[info exists drag_from($token)] && $drag_from($token) >= 0}]
  set active 0
  set from -1
  set to -1
  if {$armed} {
    set active $drag_active($token)
    set from $drag_from($token)
    set to $drag_to($token)
  }
  wviewer::strip_drag_reset $token
  # A MARKER drag commits on this release, and a marker is durable content that
  # the C ops refuse to write into a read-only buffer — which this window is,
  # for its whole life. So the release is forwarded inside with_edit whenever a
  # marker gesture is armed, exactly as key_filter does for m / d / Delete.
  # Only then: with_edit is a context switch plus four state writes, far too
  # heavy for every mouse release, and every OTHER thing this release does
  # (cursor drop, wave-bold, box-zoom, the pan) writes view state that the
  # engine has always been allowed to put in a read-only rect.
  # A plain marker CLICK (select) does not mutate, but it comes through the same
  # armed flag and the bracket is harmless there.
  set mk 0
  catch {set mk [xschem get graph_marker_drag]}
  if {[string is integer -strict $mk] && $mk > 0} {
    if {[catch {wviewer::with_edit $token {xschem callback $W 5 $px $py 0 1 0 $state}} emk]} {
      if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
        catch {ciw_echo "wviewer: marker drag refused: $emk" error}
      }
    }
  } else {
    xschem callback $W 5 $px $py 0 1 0 $state
  }
  # the trace drop reads (and clears) its own state; it is a no-op unless this
  # press armed a trace drag that passed the threshold
  wviewer::trace_drag_drop $W
  if {$active && $to >= 0 && $to != $from} {
    # catch: move_strip regenerates, and with_edit ERRORS on a refused context
    # switch (raised semaphore). Inside a Tk binding that would pop bgerror's
    # stack-trace modal over the viewer; a refused reorder must just not happen.
    catch {wviewer::move_strip $from $to $token}
  }
  catch {wviewer::readout_refresh $token}
  return 1
}

# Escape while dragging: abandon the move, restore the pointer and the drop-bar
# feedback, keep the stack exactly as it was. Returns 1 when a drag was armed.
proc wviewer::strip_drag_cancel {W} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return 0 }
  set a [wviewer::strip_drag_reset $token]
  set b [wviewer::trace_drag_reset $token]
  return [expr {$a || $b}]
}

# --- the pointer a live Tcl drag owns ----------------------------------------
# doc/claude/specs/waveform_viewer_modes.md §13. The gesture cursors (`hand2`
# for a trace drag, `sb_v_double_arrow` for a strip reorder) used to be ONE-SHOT
# writes made at the moment the gesture engaged — and the canvas has other
# writers, all of which run AFTER them and none of which knows a Tcl drag is in
# flight. Two are measured:
#
#   * the SUB-THRESHOLD MOTIONS. Below the 3-pixel tolerance the seam
#     deliberately declines the event (trace_drag_motion below, strip_drag_motion
#     above) because it still belongs to the C engine — the hover readout, an
#     in-flight cursor drag, a press that may still turn out to be a wave-bold
#     click. So the binding forwards it, waves_selected() finds the pointer
#     inside a graph rect and writes `.drw configure -cursor tcross`
#     (src/callback.c:201), landing on top of the grab hand trace_drag_arm set on
#     the press. Measured 3x per drag; at 125 Hz the first lands ~8 ms after the
#     press, so the press-time affordance trace_drag_arm's own header promises
#     was effectively invisible.
#   * LEAVING THE CANVAS MID-DRAG. `<Leave>`/`<Enter>` are in `keepseqs`, so they
#     still reach C: callback.c:8637 writes `-cursor {}` UNCONDITIONALLY on
#     LeaveNotify and handle_enter_notify (callback.c:5566) writes `{}` again on
#     the way back in (the viewer is `no_snap`, so the crosshair arm is dead
#     here). During the implicit button grab the pointer still displays THIS
#     widget's cursor, so a drag that crosses the canvas edge — toward the top
#     strip, over the readout bar, an overshoot — lost its pointer for the rest
#     of the gesture and never got it back.
#
# So the cursor is a MAINTAINED INVARIANT now, re-asserted from the binding after
# every B1 motion, rather than a write made once and hoped for. That is one
# `cget` per motion and it is clobber-source agnostic: it repairs the two above
# and any third one without having to enumerate it.
#
# ⚠ IT RE-ASSERTS ONLY WHAT AN ARMED TCL GESTURE OWNS. The arms are what is
# tested, never the widget: a press that armed nothing — a C-owned cursor grab, a
# marker drag, an axis-region zoom, a plain click, a press outside every strip —
# leaves the pointer entirely to C and keeps `tcross`, which is the shipped
# affordance for a graph. Returns the cursor the armed gesture owns, {} when
# nothing is armed.
proc wviewer::drag_cursor_reassert {W} {
  variable tdrag_gi
  variable drag_from; variable drag_active
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  set c {}
  if {[info exists tdrag_gi($token)] && $tdrag_gi($token) >= 0} {
    # owned from the PRESS, not from the threshold (trace_drag_arm)
    set c hand2
  } elseif {[info exists drag_from($token)] && $drag_from($token) >= 0 &&
            [info exists drag_active($token)] && $drag_active($token)} {
    # the reorder owns no cursor until the threshold: an empty-space press is not
    # yet a reorder, and flashing the arrow on every click would be a lie
    set c sb_v_double_arrow
  }
  if {$c eq {}} { return {} }
  # `cget` first: on the motions nobody clobbered this is a read and no write
  if {![catch {$W cget -cursor} cur] && $cur eq $c} { return $c }
  wviewer::set_drag_cursor $W $c
  return $c
}

# The ONE cursor write, so a failure is heard ONCE instead of never.
#
# Every gesture cursor used to be written as a bare `catch {$W configure -cursor
# hand2}`. `catch` is right — a cursor is cosmetic and must never abort a drag —
# but it also means that on a box whose cursor theme lacks `hand2` or
# `sb_v_double_arrow` the pointer silently never changes while every other part
# of the gesture works perfectly, which is indistinguishable from a logic bug and
# costs a session to diagnose. Now it says so, once per window per session (the
# guard is per token, so a broken theme does not spam the CIW on every motion).
proc wviewer::set_drag_cursor {W c} {
  variable cursor_warned
  if {![catch {$W configure -cursor $c}]} { return 1 }
  set tok [wviewer::token_for_canvas $W]
  if {$tok eq {}} { set tok $W }
  if {![info exists cursor_warned($tok)]} {
    set cursor_warned($tok) 1
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: this X cursor theme has no \"$c\" — drag pointer shapes\
                are unavailable in this window (the drag itself is unaffected)" error
    }
  }
  return 0
}

# --- trace drag BETWEEN strips -----------------------------------------------
# doc/claude/specs/waveform_viewer_modes.md §13. Press ON a trace, drag, release
# over another strip: the trace moves there, keeping its expression, alias,
# vector and color. It is the twin of the strip drag above and reuses its whole
# shape — PURE model math, ONE authoritative mutation, a gesture layer that only
# ever speaks pixels — and it owns the seam the strip drag deliberately refused
# (the 10-px zone around every trace). The two can never both be armed: the press
# arms exactly one of them, by where it landed.
#
# The source strip is left in place even when it ends up empty (deleting it would
# renumber the stack behind the user's back and lose its axis settings), and the
# trace lands at the END of the destination's list.

# PURE: the NODE index of model trace `ti` of graph dict `G` — its position in
# the `node` prop token, which is what the C engine counts (hilight_wave,
# find_closest_wave, graph_wave_at). The two differ whenever a trace carries an
# empty `vec`: graph_props SKIPS those when it builds the token, so they occupy a
# model slot and no node slot. -1 when `ti` is out of range or is itself such a
# trace.
proc wviewer::node_index_of_trace {G ti} {
  if {![string is integer -strict $ti] || $ti < 0} { return -1 }
  set trs [wviewer::dget $G traces {}]
  if {$ti >= [llength $trs]} { return -1 }
  if {[wviewer::dget [lindex $trs $ti] vec {}] eq {}} { return -1 }
  set ni 0
  for {set k 0} {$k < $ti} {incr k} {
    if {[wviewer::dget [lindex $trs $k] vec {}] ne {}} { incr ni }
  }
  return $ni
}

# PURE: how many of `G`'s traces reach the `node` prop token (i.e. carry a
# non-empty `vec`) — the length of the C-side index space, hence the node index
# an appended trace will occupy.
proc wviewer::node_count {G} {
  set n 0
  foreach tr [wviewer::dget $G traces {}] {
    if {[wviewer::dget $tr vec {}] ne {}} { incr n }
  }
  return $n
}

# PURE: the name the LEGEND shows for trace dict `tr` — the alias when it has a
# distinct one, else the vector. Deliberately the SAME rule graph_props applies
# when it builds the `node` token (the `$nm ne {} && $nm ne $vec` test), so the
# context menu names a trace exactly the way its own strip labels it. {} for a
# trace that reaches no node slot at all.
proc wviewer::trace_label {tr} {
  set vec [wviewer::dget $tr vec {}]
  set nm  [wviewer::dget $tr name {}]
  if {$nm ne {} && $nm ne $vec} { return $nm }
  return $vec
}

# PURE: the inverse — model trace index of NODE index `ni` of graph dict `G`,
# or -1. This is the mapping a C answer (graph_trace_at, hilight_wave) must go
# through before it indexes the model.
proc wviewer::trace_index_of_node {G ni} {
  if {![string is integer -strict $ni] || $ni < 0} { return -1 }
  set n 0
  set ti 0
  foreach tr [wviewer::dget $G traces {}] {
    if {[wviewer::dget $tr vec {}] ne {}} {
      if {$n == $ni} { return $ti }
      incr n
    }
    incr ti
  }
  return -1
}

# PURE: how a graph's stored `hilight_wave` (a NODE index) must be rewritten when
# the trace at node index `moved_ni` leaves that graph. Returns the new value, or
# {} when the graph must lose its highlight entirely (the bold trace is the one
# that left — the destination picks the highlight up instead). `hw` {} in, {} out.
proc wviewer::remap_hilight_after_trace_move {hw moved_ni} {
  if {![string is integer -strict $hw]} { return {} }
  if {![string is integer -strict $moved_ni] || $moved_ni < 0} { return $hw }
  if {$hw == $moved_ni} { return {} }
  if {$hw > $moved_ni} { return [expr {$hw - 1}] }
  return $hw
}

# --- the SELECTION as a SET, in the model (issue 0175) -----------------------
# The model stores the selection in the same two keys the rect does — the whole
# set in `sel_waves` when it holds two or more, the head in `hilight_wave`
# always — so these two are the model-side mirror of draw.c's
# graph_sel_waves_get/set and the ONLY place that pair is composed/decomposed.
# Everything structural below then works on a plain list.

# PURE: the effective selection of model graph dict `G`, as a NODE-index list.
proc wviewer::model_sel {G} {
  set l [wviewer::sel_waves_norm [wviewer::dget $G sel_waves {}]]
  if {[llength $l]} { return $l }
  set hw [wviewer::dget $G hilight_wave {}]
  if {[string is integer -strict $hw] && $hw >= 0} { return [list $hw] }
  return {}
}

# PURE: write selection `sel` back into `G`. An EMPTY selection drops BOTH keys
# rather than storing -1/"" (the absent-means-absent rule graph_props relies on),
# and a 1-element one drops `sel_waves` so a strip that is back to a single
# selected trace serialises byte-identically to pre-0175.
proc wviewer::model_sel_set {G sel} {
  set sel [wviewer::sel_waves_norm $sel]
  if {![llength $sel]} { return [dict remove $G hilight_wave sel_waves] }
  set G [dict replace $G hilight_wave [lindex $sel 0]]
  if {[llength $sel] >= 2} { return [dict replace $G sel_waves $sel] }
  return [dict remove $G sel_waves]
}

# PURE: how a SET of selected node indices is rewritten when the trace at node
# index `moved_ni` leaves the graph — per element, through the scalar rule above,
# dropping the one that left. The caller decides whether the destination picks it
# up (it does, at its new node index).
proc wviewer::remap_sel_after_trace_move {sel moved_ni} {
  set out {}
  foreach v $sel {
    set n [wviewer::remap_hilight_after_trace_move $v $moved_ni]
    if {$n ne {}} { lappend out $n }
  }
  return $out
}

# PURE: the same for a DELETE of the node indices in `doomed` — per element
# through remap_node_after_trace_delete, dropping every index that died.
# Without this a multi-selection would keep stale indices after a delete and
# bold the WRONG traces, which is strictly worse than losing the selection.
proc wviewer::remap_sel_after_trace_delete {sel doomed} {
  set out {}
  foreach v $sel {
    set n [wviewer::remap_node_after_trace_delete $v $doomed]
    if {$n ne {}} { lappend out $n }
  }
  return $out
}

# PURE: move trace `from_ti` of graph `from_gi` to the END of graph `to_gi`'s
# trace list. Returns the new graph list; an out-of-range index, a non-integer or
# from_gi == to_gi returns the list UNCHANGED (a pure list op has no error
# channel — move_trace is where a bad index is refused loudly).
#
# The trace DICTIONARY is carried whole, exactly like reorder_graphs carries a
# graph dict: expr, name, vec, color and any future per-trace key ride along and
# nothing is rebuilt field by field. The SELECTION (`hilight_wave` + `sel_waves`,
# the C-written bold markers, issue 0175) is remapped on BOTH graphs, because it
# is stored per graph in node-index space and both index spaces shift.
proc wviewer::move_trace_in_graphs {graphs from_gi from_ti to_gi} {
  set n [llength $graphs]
  foreach v [list $from_gi $from_ti $to_gi] {
    if {![string is integer -strict $v]} { return $graphs }
  }
  if {$from_gi < 0 || $from_gi >= $n || $to_gi < 0 || $to_gi >= $n} { return $graphs }
  if {$from_gi == $to_gi} { return $graphs }
  set S [lindex $graphs $from_gi]
  set D [lindex $graphs $to_gi]
  set strs [wviewer::dget $S traces {}]
  if {$from_ti < 0 || $from_ti >= [llength $strs]} { return $graphs }
  set tr [lindex $strs $from_ti]
  # node indices measured BEFORE the move, on the graphs as they stand
  set moved_ni [wviewer::node_index_of_trace $S $from_ti]
  set dst_ni [wviewer::node_count $D]        ;# where the appended trace lands
  # The selection is a SET since issue 0175, so the hand-off is per element:
  # every selected node index that STAYS shifts down past the hole, the one that
  # LEFT is dropped here and re-added to the destination below. For a
  # single-trace selection this is exactly what the scalar rule always did.
  set src_sel [wviewer::model_sel $S]
  # markers are stored per graph in the SAME node-index space, so both index
  # spaces shifting means both marker tokens have to be rewritten. A marker on
  # the moved trace MIGRATES with it (doc/claude/specs/graph_markers.md) —
  # measured off the graphs as they stand, i.e. BEFORE the trace list edits
  # below, exactly like moved_ni/dst_ni above.
  lassign [wviewer::remap_markers_after_trace_move \
             [wviewer::dget $S markers {}] [wviewer::dget $D markers {}] \
             $moved_ni $dst_ni] src_mk dst_mk
  # was the trace that is leaving one of the SELECTED ones? Only then does the
  # destination pick it up — a source whose selection did not include it just
  # shifts its remaining indices past the hole.
  set moved_was_bold [expr {$moved_ni >= 0 && [lsearch -exact $src_sel $moved_ni] >= 0}]
  set S [dict replace $S traces [lreplace $strs $from_ti $from_ti]]
  # a destination that was EMPTY gets its ranges blanked, i.e. put back to
  # `auto`: an empty strip's stored x1/x2/y1/y2 are whatever the last fit left
  # (capture_live_graph_state freezes the live rect, so they are never blank by
  # the time we get here), and a µA trace dropped into a 0..2 V window is drawn
  # off-screen — the user sees an empty strip and thinks the drop failed.
  # regenerate re-autozooms every blank range, which is exactly what a trace
  # landing in a fresh strip gets from add_trace/plot_signals.
  if {![llength [wviewer::dget $D traces {}]]} {
    set D [dict replace $D x1 {} x2 {} y1 {} y2 {}]
  }
  set D [dict replace $D traces [linsert [wviewer::dget $D traces {}] end $tr]]
  set S [wviewer::model_sel_set $S [wviewer::remap_sel_after_trace_move $src_sel $moved_ni]]
  # the destination ADDS the migrating trace to whatever it already had selected
  # rather than replacing it: a selection has been window-wide since issue 0174
  # and multi-trace since 0175, so an unrelated highlight on the destination has
  # no reason to die because something landed next to it. `dst_ni` is the node
  # count taken BEFORE the append, so no existing destination index shifts.
  if {$moved_was_bold} {
    set D [wviewer::model_sel_set $D [concat [wviewer::model_sel $D] [list $dst_ni]]]
  }
  # absent-means-absent on both sides: an emptied token drops the key rather
  # than storing "", so graph_props keeps emitting nothing for that strip
  if {$src_mk eq {}} {
    set S [dict remove $S markers]
  } else {
    set S [dict replace $S markers $src_mk]
  }
  if {$dst_mk eq {}} {
    set D [dict remove $D markers]
  } else {
    set D [dict replace $D markers $dst_mk]
  }
  set graphs [lreplace $graphs $from_gi $from_gi $S]
  return [lreplace $graphs $to_gi $to_gi $D]
}

# THE authoritative trace move. Returns the trace's index in the DESTINATION, or
# {} on failure (unknown viewer, bad index, busy ctx).
#
# Same ordering contract as move_strip, for the same reasons:
#   1. resolve + validate every index against the LIVE model
#   2. from_gi == to_gi -> return without mutating and WITHOUT logging (dropping
#      a trace back on its own strip is not a state change)
#   3. verify the context switch (capture reads rect props; switch_ctx silently
#      no-ops under a raised semaphore — landmine 17)
#   4. capture the live C-written state FIRST, so the regenerate below cannot
#      undo a pan/zoom/bold made with the mouse
#   5. the pure move, dictionary carried whole
#   6. the DESTINATION becomes the target strip, set IN PLACE — not through
#      set_target_strip, which would emit a second replay-log line for what is an
#      internal consequence of this one command
#   7. exactly ONE regenerate, exactly ONE fully-resolved log line
proc wviewer::move_trace {from_gi from_ti to_gi {token {}}} {
  variable windows
  variable target
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to move a trace in" error
    }
    return {}
  }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set n [llength $gs]
  foreach v [list $from_gi $to_gi] {
    if {![string is integer -strict $v] || $v < 0 || $v >= $n} {
      if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
        ciw_echo "wviewer: bad strip index '$v' (0..[expr {$n - 1}])" error
      }
      return {}
    }
  }
  set nt [llength [wviewer::dget [lindex $gs $from_gi] traces {}]]
  if {![string is integer -strict $from_ti] || $from_ti < 0 || $from_ti >= $nt} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: bad trace index '$from_ti' on strip $from_gi (0..[expr {$nt - 1}])" error
    }
    return {}
  }
  if {$from_gi == $to_gi} { return $from_ti }
  if {![wviewer::switch_ctx $token]} { return {} }
  wviewer::capture_live_graph_state $token
  wviewer::push_undo $token           ;# AFTER the capture: `u` restores the view
  set gs [dict get [wviewer::layout_for $token] graphs]
  # the two NODE indices the highlight remap needs, measured BEFORE the edit --
  # exactly where move_trace_in_graphs measures its own (landmine 34)
  set hl_moved [wviewer::node_index_of_trace [lindex $gs $from_gi] $from_ti]
  set hl_dst   [wviewer::node_count [lindex $gs $to_gi]]
  wviewer::set_graphs $token \
    [wviewer::move_trace_in_graphs $gs $from_gi $from_ti $to_gi]
  if {$hl_moved >= 0} {
    wviewer::wavehl_remap_apply $token \
      [wviewer::wavehl_after_trace_move [wviewer::wave_hilights $token] \
         $from_gi $hl_moved $to_gi $hl_dst]
  }
  set target($token) $to_gi
  wviewer::regenerate $token
  wviewer::log_action [list wviewer::move_trace $from_gi $from_ti $to_gi $token]
  set dgs [dict get [wviewer::layout_for $token] graphs]
  return [expr {[llength [wviewer::dget [lindex $dgs $to_gi] traces {}]] - 1}]
}

# PURE: move the MODEL {gi ti} `pairs` to strip `to_gi`, all of them, as one
# operation (issue 0192, doc/claude/specs/waveform_viewer_modes.md §19). A FOLD
# over the shipped single-trace primitive above — nothing about a trace dict, a
# marker, the selection hand-off or the empty-destination range blanking is
# reimplemented here, which is what keeps a multi-trace drag an extension rather
# than a second implementation.
#
# NORMALISATION comes first and is the thing the caller logs: integers, in range,
# de-duplicated, ascending by (gi, ti), and every pair already ON the destination
# DROPPED (D-44: those traces are there, and re-appending them would silently
# reorder a strip the user did not ask to reorder). A pure list op has no error
# channel, so any invalid pair returns the list UNCHANGED — move_traces refuses
# loudly on the caller's behalf.
#
# ⚠ THE ONE PIECE OF NEW ARITHMETIC, and the only thing a naive loop gets wrong:
# each step removes a trace from its source, so every LATER pair from that SAME
# source has shifted down by one. `- $done($gi)` is that term. Moving indices
# 0 and 1 cannot see it (0 then 1-1=0 removes the right two either way); moving
# 0 and 2 of four can, which is what MV8 drives and what SAB-4 kills.
#
# Three properties fall out of the ascending fold order, and all three are
# asserted rather than assumed:
#   * destination order = SOURCE order, because every step APPENDS at the end;
#   * the empty-destination range blanking fires EXACTLY ONCE — on the first
#     step, after which the destination is no longer empty;
#   * the destination's selection grows by one appended node index per moved
#     trace, because each step recomputes `dst_ni = node_count $D` before it
#     appends.
proc wviewer::move_traces_in_graphs {graphs pairs to_gi} {
  set n [llength $graphs]
  if {![string is integer -strict $to_gi]} { return $graphs }
  if {$to_gi < 0 || $to_gi >= $n} { return $graphs }
  set norm {}
  foreach p $pairs {
    if {[llength $p] != 2} { return $graphs }
    lassign $p gi ti
    if {![string is integer -strict $gi] || ![string is integer -strict $ti]} { return $graphs }
    if {$gi < 0 || $gi >= $n} { return $graphs }
    if {$ti < 0 || $ti >= [llength [wviewer::dget [lindex $graphs $gi] traces {}]]} {
      return $graphs
    }
    if {$gi == $to_gi} { continue }        ;# already there (D-44)
    set k [list $gi $ti]
    # a repeated pair would lreplace twice and take an innocent neighbour with
    # it — the delete_items rule, for the same reason
    if {[lsearch -exact $norm $k] >= 0} { continue }
    lappend norm $k
  }
  # ascending by (gi, ti): lsort is STABLE, so sorting on ti and then on gi gives
  # the composite order without a custom comparator
  set norm [lsort -integer -index 0 [lsort -integer -index 1 $norm]]
  set done [dict create]
  foreach p $norm {
    lassign $p gi ti
    set d 0
    if {[dict exists $done $gi]} { set d [dict get $done $gi] }
    set graphs [wviewer::move_trace_in_graphs $graphs $gi [expr {$ti - $d}] $to_gi]
    dict set done $gi [expr {$d + 1}]
  }
  return $graphs
}

# THE authoritative MULTI-trace move (issue 0192). Returns how many traces were
# moved (0 when the normalised list is empty), or {} on failure.
#
# Modelled on delete_items (the N-object template) over move_trace's ordering
# contract, and it owes exactly ONE of everything the way that one does:
#   1. validate LOUDLY against the LIVE model — a bad index is a caller bug, and
#      silently dropping one would move a DIFFERENT trace on a replay
#   2. normalise, then: nothing left to move -> return WITHOUT mutating and
#      WITHOUT logging (move_trace's `from_gi == to_gi` rule, applied per pair)
#   3. verify the context switch (capture reads rect props; switch_ctx silently
#      no-ops under a raised semaphore — landmine 17)
#   4. capture the live C-written state FIRST, so the regenerate below cannot
#      undo a pan/zoom/bold made with the mouse
#   5. ONE push_undo, after the capture, so three traces are a single `u` (D-54).
#      The fold runs on the PURE layer, so no intermediate state is snapshotted
#   6. the DESTINATION becomes the target strip, set IN PLACE — not through
#      set_target_strip, which would emit a second replay-log line for what is an
#      internal consequence of this one command
#   7. exactly ONE regenerate, exactly ONE log line, and the line carries the
#      NORMALISED pairs (D-57) so replaying it reproduces exactly this run
proc wviewer::move_traces {pairs to_gi {token {}}} {
  variable windows
  variable target
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to move traces in" error
    }
    return {}
  }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set n [llength $gs]
  if {![string is integer -strict $to_gi] || $to_gi < 0 || $to_gi >= $n} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: bad strip index '$to_gi' (0..[expr {$n - 1}])" error
    }
    return {}
  }
  set norm {}
  foreach p $pairs {
    if {[llength $p] != 2} {
      if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
        ciw_echo "wviewer: bad trace pair '$p' (expected {gi ti})" error
      }
      return {}
    }
    lassign $p gi ti
    if {![string is integer -strict $gi] || $gi < 0 || $gi >= $n} {
      if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
        ciw_echo "wviewer: bad strip index '$gi' (0..[expr {$n - 1}])" error
      }
      return {}
    }
    set cnt [llength [wviewer::dget [lindex $gs $gi] traces {}]]
    if {![string is integer -strict $ti] || $ti < 0 || $ti >= $cnt} {
      if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
        ciw_echo "wviewer: bad trace index '$ti' on strip $gi (0..[expr {$cnt - 1}])" error
      }
      return {}
    }
    if {$gi == $to_gi} { continue }
    if {[lsearch -exact $norm [list $gi $ti]] >= 0} { continue }
    lappend norm [list $gi $ti]
  }
  set norm [lsort -integer -index 0 [lsort -integer -index 1 $norm]]
  # No-op discipline, move_trace's `from == to` rule: a drop where every selected
  # trace is already on the destination is not a state change, so no undo point,
  # no repaint and NO log line for a replay to re-run.
  if {![llength $norm]} { return 0 }
  if {![wviewer::switch_ctx $token]} { return {} }
  wviewer::capture_live_graph_state $token
  wviewer::push_undo $token           ;# AFTER the capture: `u` restores the view
  set gs [dict get [wviewer::layout_for $token] graphs]
  # the highlight set follows the traces, folded in the SAME order and with the
  # SAME per-SOURCE index adjustment move_traces_in_graphs uses (landmine 49(a)).
  # It is a second fold rather than a term inside that one because the pure fold
  # only ever sees `graphs`, and the highlight set is not in the model.
  wviewer::wavehl_remap_apply $token \
    [wviewer::wavehl_after_traces_move [wviewer::wave_hilights $token] $gs $norm $to_gi]
  wviewer::set_graphs $token [wviewer::move_traces_in_graphs $gs $norm $to_gi]
  set target($token) $to_gi
  wviewer::regenerate $token
  wviewer::log_action [list wviewer::move_traces $norm $to_gi $token]
  return [llength $norm]
}

# PURE: the highlight-set half of move_traces_in_graphs. Walks the SAME
# normalised pairs in the SAME order, applies the SAME `- $done($gi)` per-source
# adjustment, and remaps the set one step at a time — so the two folds cannot
# disagree about which trace moved where. `graphs` is the PRE-move model and is
# advanced step by step alongside, because each step's destination node index is
# `node_count` of the destination AS IT IS AT THAT STEP.
proc wviewer::wavehl_after_traces_move {set graphs pairs to_gi} {
  set done [dict create]
  foreach p $pairs {
    if {[llength $p] != 2} { continue }
    lassign $p gi ti
    set d 0
    if {[dict exists $done $gi]} { set d [dict get $done $gi] }
    set sti [expr {$ti - $d}]
    set moved_ni [wviewer::node_index_of_trace [lindex $graphs $gi] $sti]
    set dst_ni [wviewer::node_count [lindex $graphs $to_gi]]
    if {$moved_ni >= 0} {
      set set [wviewer::wavehl_after_trace_move $set $gi $moved_ni $to_gi $dst_ni]
    }
    set graphs [wviewer::move_trace_in_graphs $graphs $gi $sti $to_gi]
    dict set done $gi [expr {$d + 1}]
  }
  return $set
}

# --- give one trace a strip of its own (viewer plan item 7) -------------------
# doc/claude/specs/waveform_viewer.md. The payload behind the RMB context menu
# below, and a CIW-typable command in its own right.
#
# REUSE BEFORE CREATE (2026-07-29 request, decisions D1/D2). An empty strip is a
# place to put a trace, so this gesture FILLS one when the stack already has one
# instead of inserting a second blank band beside it — the same reasoning
# `plan_plot` records for plot batches (issue 0171's follow-up, see its header):
# appending past an existing empty strip pinned a blank band on the window and
# shrank every real strip for nothing. Only when there is no reusable empty
# strip is one inserted, and then still directly below the source (D-F).
#
# D1, WHICH empty strip when several are free: the NEAREST one BELOW the source,
# else — only when none is below — the nearest one ABOVE. "Below" is D-F's
# reading-order direction and matches where an inserted strip would have gone;
# "nearest" keeps the trace close to where it was picked up. The direction
# preference is STRICT: an empty strip below wins even when one above is nearer.
#
# D2, distance: a far empty strip IS taken (the user's request, and consistent
# with `e`, which treats every empty strip alike wherever it sits). The optional
# cap below exists for the "the trace teleported" reading and is OFF by default.
proc wviewer::reuse_max_distance {} {
  if {![info exists ::wviewer_reuse_max_distance]} { return 0 }
  set v [string trim $::wviewer_reuse_max_distance]
  if {![string is integer -strict $v] || $v < 0} { return 0 }
  return $v
}

# PURE: the index of the existing empty strip a single-trace separate-strip move
# should CONSUME, or -1 when there is none and one must be inserted. `auto` is
# the tool-owned auto-plot strip (`auto_graph_index`, -1 = none), which is never
# consumable — see the D-D note on empty_strips_to_delete: it is traceless
# BETWEEN runs and item 13 rebuilds it after every one, so a trace parked there
# is silently destroyed at the next run.
#
# `maxdist` > 0 caps |candidate - from_gi| (D2's optional cap); 0 = no cap, the
# default. The cap is applied BEFORE D1's below-then-above preference, so a
# capped-out strip below does not block a reachable one above.
proc wviewer::reuse_strip_for_trace_move {gs from_gi {auto -1} {maxdist 0}} {
  if {![string is integer -strict $from_gi]} { return -1 }
  if {![string is integer -strict $maxdist] || $maxdist < 0} { set maxdist 0 }
  set below -1
  set above -1
  # empty_graph_indices is ascending, so the FIRST candidate past the source is
  # the nearest below it and the LAST one before it is the nearest above
  foreach gi [wviewer::empty_graph_indices $gs $auto] {
    if {$gi == $from_gi} continue        ;# the source has traces; belt and braces
    if {$maxdist > 0 && abs($gi - $from_gi) > $maxdist} continue
    if {$gi > $from_gi} {
      if {$below < 0} { set below $gi }
    } else {
      set above $gi
    }
  }
  if {$below >= 0} { return $below }
  return $above
}

# It is `move_trace` with ONE extra step — a `linsert` of an `empty_graph`, and
# only when no empty strip was there to reuse — and it deliberately does NOT
# call `add_graph`: add_graph regenerates on the spot and takes neither an undo
# point nor a log line, so a strip created that way would land between this
# command's capture and its mutation and split one gesture into two half-states
# (the very failure the move_strip ordering contract exists to prevent).
#
# An INSERTED strip goes DIRECTLY BELOW the source, which is decision D-F's
# reading-order rule (the same one item 8's split follows). The move itself
# is the shipped PURE `move_trace_in_graphs`, which is where marker migration,
# the `hilight_wave` hand-off and the empty-destination range blanking come
# from — nothing here does index math on markers. That blanking is also what
# makes REUSE free: a reused strip's stale x1/x2/y1/y2 go back to `auto`, so
# regenerate re-autozooms it exactly as it does a fresh one.
#
# Same ordering contract as move_strip / move_trace, for the same reasons:
#   1. resolve + validate every index against the LIVE model
#   2. REFUSE, without mutating and without logging, when the strip carries
#      fewer than two DRAWN traces: a lone trace already has a strip to itself,
#      and "separating" it would only leave an empty strip behind. This is the
#      authoritative half of the menu gate, so a hand-typed call is refused too
#   3. verify the context switch (capture reads rect props; switch_ctx silently
#      no-ops under a raised semaphore — landmine 17)
#   4. capture the live C-written state FIRST, so the regenerate below cannot
#      undo a pan/zoom/bold made with the mouse
#   5. pick the empty strip to REUSE (pure, D1/D2) and insert one only when
#      there is none, then the pure move, dictionary carried whole
#   6. the DESTINATION becomes the target strip, set IN PLACE — move_trace step 6
#      verbatim (the destination is the target, reused or new), and not through
#      set_target_strip, which would emit a second replay-log line for what is
#      an internal consequence of this one command
#   7. exactly ONE regenerate, exactly ONE fully-resolved log line
#
# ⚠ PLAN DEVIATION (recorded in plan_viewer_enhancements_2026-07.md): the plan
# asked for the stored target to be SHIFTED through the insert with
# plot_signals' arithmetic. That shift is unreachable here — step 6 overwrites
# the target with the destination index, exactly as the twin command does — so
# the shift helper is left for item 8, whose multi-strip split does not adopt a
# single destination. Shifting AND overwriting would be dead code. (The reuse
# arm needs no shift at all: nothing is inserted, so no index moves.)
#
# REPLAY DETERMINISM: the log line carries the source indices only, never the
# resolved destination — so a replay recomputes the reuse decision. That is
# sound because the decision is a PURE function of the model
# (reuse_strip_for_trace_move + auto_graph_index) and a replay reaches the same
# model, and it is asserted, not assumed (TG17: undo, replay the logged line,
# compare strip identities).
#
# Returns the index of the DESTINATION strip — an existing empty strip when one
# was reused, otherwise the newly inserted one — or {} on failure/refusal.
proc wviewer::move_trace_to_new_strip {from_gi from_ti {token {}}} {
  variable windows
  variable target
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to move a trace in" error
    }
    return {}
  }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set n [llength $gs]
  if {![string is integer -strict $from_gi] || $from_gi < 0 || $from_gi >= $n} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: bad strip index '$from_gi' (0..[expr {$n - 1}])" error
    }
    return {}
  }
  set G [lindex $gs $from_gi]
  set nt [llength [wviewer::dget $G traces {}]]
  if {![string is integer -strict $from_ti] || $from_ti < 0 || $from_ti >= $nt} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: bad trace index '$from_ti' on strip $from_gi (0..[expr {$nt - 1}])" error
    }
    return {}
  }
  if {[wviewer::node_count $G] < 2} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: strip $from_gi has nothing to separate (one drawn trace)" error
    }
    return {}
  }
  if {![wviewer::switch_ctx $token]} { return {} }
  wviewer::capture_live_graph_state $token
  wviewer::push_undo $token           ;# AFTER the capture: `u` restores the view
  # re-read: the capture writes the live ranges back into the model, and the
  # insert below must not be applied to the pre-capture list
  set gs [dict get [wviewer::layout_for $token] graphs]
  # D1/D2: consume an existing empty strip when the stack has one (never the
  # auto-plot strip — D-D), else insert one
  set at [wviewer::reuse_strip_for_trace_move $gs $from_gi \
            [wviewer::auto_graph_index $token] [wviewer::reuse_max_distance]]
  set inserted 0
  if {$at < 0} {
    set at [expr {$from_gi + 1}]
    # the insert is BELOW the source, so `from_gi` still addresses the source
    # afterwards and no source-side index needs remapping
    set gs [linsert $gs $at [wviewer::empty_graph]]
    set inserted 1
  }
  # §8: the highlight set is keyed by (gi, ni), so an INSERT shifts every entry
  # at or below `at` down one, and the moved trace then follows its own trace.
  # Measured BEFORE the model edit, like the two node indices below it.
  set hlset [wviewer::wave_hilights $token]
  if {$inserted} {
    set shifted {}
    foreach e $hlset {
      lassign $e egi eni est
      if {$egi >= $at} { lappend shifted [list [expr {$egi + 1}] $eni $est] } \
      else { lappend shifted $e }
    }
    set hlset $shifted
  }
  set hl_moved [wviewer::node_index_of_trace [lindex $gs $from_gi] $from_ti]
  set hl_dst   [wviewer::node_count [lindex $gs $at]]
  if {$hl_moved >= 0} {
    set hlset [wviewer::wavehl_after_trace_move $hlset $from_gi $hl_moved $at $hl_dst]
  }
  wviewer::set_graphs $token \
    [wviewer::move_trace_in_graphs $gs $from_gi $from_ti $at]
  # AFTER set_graphs: wavehl_remap_apply validates `gi` against the LIVE strip
  # count, and this command can have just GROWN it — applying first would drop
  # the entry that moved onto the brand-new strip.
  wviewer::wavehl_remap_apply $token $hlset
  set target($token) $at
  wviewer::regenerate $token
  wviewer::log_action \
    [list wviewer::move_trace_to_new_strip $from_gi $from_ti $token]
  return $at
}

# --- split one strip into one strip per trace (viewer plan item 8) ------------
# doc/claude/specs/waveform_viewer.md. The payload behind the RMB context menu
# on EMPTY waveform space, and a CIW-typable command in its own right.
#
# PURE: strip `gi` of `graphs` becomes N strips, one per DRAWN trace.
# Decision D-F: node 0 KEEPS the original strip and the remaining traces get
# strips directly BELOW it, in order — so a strip reading a, b, c becomes three
# strips reading a, b, c top to bottom. A full split, not a one-trace peel-off.
# Those strips are inserted, EXCEPT that an empty strip already sitting at
# `gi + 1` is consumed instead of adding one beside it (D3/D4, plan_split).
# Returns the list UNCHANGED for a bad index or a strip with fewer than two drawn
# traces (a pure list op has no error channel; split_strip is where a refusal is
# reported).
#
# Implemented as a LOOP OVER THE SHIPPED move_trace_in_graphs rather than as
# fresh index math, which is the whole point: every iteration gets the marker
# migration, the hilight_wave hand-off and the empty-destination range blanking
# for free, and graph_markers.md §9's obligations are discharged BY
# CONSTRUCTION. Nothing here touches a marker record.
#
# Two ordering rules make that safe:
#   - every destination strip is IN PLACE FIRST (inserted, or reused where an
#     empty strip already sat — D4), so the destination index of node k is
#     simply gi + k and never moves under the loop;
#   - the traces are moved DESCENDING, from the last node to node 1. Removing
#     node k renumbers only the nodes ABOVE k — which are already placed — so
#     the node indices still to come stay valid. Ascending would renumber the
#     remaining work on every step.
#
# Traces carrying an empty `vec` reach no node slot and are left in the source
# strip: they are invisible, so "one strip per trace" can only mean per DRAWN
# trace, and node_count is the count that matters everywhere else too.
#
# REUSE BEFORE CREATE (2026-07-29 request), the same rationale plan_plot's header
# records for plot batches: an empty strip is a place to put a trace, so the split
# fills one rather than adding a blank band beside it.
#
# ⚠ D3 REVISED, SAME DAY, after the first cut was driven for real. v1 could only
# consume the strip at EXACTLY `gi + 1` ("adjacency in place"), and that turns out
# to almost never fire. The reported repro: three strips of one trace each, drag
# strip 1's trace down onto strip 2 (so strip 1 goes empty), then split strip 2 —
# strip 2 is bottom-most, so `gi + 1` does not exist, the free strip sits ABOVE,
# and the split inserted a fourth strip next to a blank one. In-place adjacency
# only helps when the empty strip happens to be in exactly the right slot.
#
# D3 (v2): the split takes the NEAREST empty strip in the WHOLE stack — D1's
# order, nearest below first, then nearest above — and **RELOCATES** it into the
# destination run instead of filling it where it lies. That is what reconciles
# the two constraints that made v1 narrow:
#   - D-F's reading order is preserved because the strip is MOVED to below the
#     split strip; nothing ends up above node 0. (Filling an empty strip above
#     in place is what would break it, and that is what stays forbidden.)
#   - the strip COUNT does not grow while any empty strip exists, which is the
#     whole point of the request.
# Relocation preserves the relative order of every OTHER strip: lifting an empty
# strip out and re-inserting it lower down moves only itself.
#
# D4: a split needs `nc - 1` destination strips. As many as are available are
# relocated (nearest first) and only the SHORTFALL is created — plan_plot's
# `reuse`/`new` arithmetic. Zero shortfall is normal: `nc == 2` with one empty
# strip anywhere creates NOTHING, and split_strip then returns 0, which is a
# success (it mutates, logs and takes an undo point — see there).
#
# D2's optional distance cap applies here too (`reuse_max_distance`, OFF by
# default): one config for both gestures, since both now travel.
#
# The auto-plot strip is never taken (D-D): item 13 rebuilds it after every run.
#
# `plan_split` is the whole decision, PURE and assertable with literal lists:
#   ok    0 = refuse (bad index, or fewer than two drawn traces)
#   take  source indices of the empty strips to relocate, in SLOT order
#   src   where the split strip sits AFTER those removals
#   at    src + 1, the insertion point of the whole destination block
#   block how many strips that block holds (always nc - 1)
#   new   how many of them are freshly created (block - [llength take])
# split_strip calls it too, so the model op and the target arithmetic cannot
# disagree about what moved where.
proc wviewer::plan_split {gs gi {auto -1} {maxdist 0}} {
  set none [dict create ok 0 take {} src 0 at 0 block 0 new 0]
  if {![string is integer -strict $gi]} { return $none }
  set n [llength $gs]
  if {$gi < 0 || $gi >= $n} { return $none }
  set nc [wviewer::node_count [lindex $gs $gi]]
  if {$nc < 2} { return $none }
  if {![string is integer -strict $maxdist] || $maxdist < 0} { set maxdist 0 }
  set need [expr {$nc - 1}]
  # D1's preference order, reused verbatim: every empty strip BELOW the source
  # nearest-first, then every one ABOVE nearest-first. empty_graph_indices is
  # ascending and already carries the auto exclusion.
  set below {}
  set above {}
  foreach ci [wviewer::empty_graph_indices $gs $auto] {
    if {$ci == $gi} continue
    if {$maxdist > 0 && abs($ci - $gi) > $maxdist} continue
    if {$ci > $gi} { lappend below $ci } else { set above [linsert $above 0 $ci] }
  }
  set take {}
  foreach ci [concat $below $above] {
    if {[llength $take] >= $need} break
    lappend take $ci
  }
  # the split strip slides up by however many relocated strips sat above it
  set src [wviewer::index_after_removal $gi $take]
  return [dict create ok 1 take $take src $src at [expr {$src + 1}] \
                      block $need new [expr {$need - [llength $take]}]]
}

# PURE: where the stored target strip ends up once `plan` has been applied — the
# remove-then-insert twin of the single index_after_insert the in-place v1 needed.
# A target that IS one of the relocated strips follows it into its slot in the
# block (identity, not arithmetic); everything else goes through the removal and
# then the insertion, in that order.
proc wviewer::target_after_split {target plan} {
  if {![string is integer -strict $target]} { return $target }
  if {![dict get $plan ok]} { return $target }
  set take [dict get $plan take]
  set pos [lsearch -exact $take $target]
  if {$pos >= 0} { return [expr {[dict get $plan at] + $pos}] }
  return [wviewer::index_after_insert \
            [wviewer::index_after_removal $target $take] \
            [dict get $plan at] [dict get $plan block]]
}

proc wviewer::split_graph_in_graphs {graphs gi {auto -1} {maxdist 0}} {
  set plan [wviewer::plan_split $graphs $gi $auto $maxdist]
  if {![dict get $plan ok]} { return $graphs }
  set nc [wviewer::node_count [lindex $graphs $gi]]
  # 1. lift the relocated strips out. The DICTS are collected in slot order
  # first, then removed DESCENDING so no index shifts under the removal — the
  # same rule the trace loop below follows, for the same reason.
  set take [dict get $plan take]
  set block {}
  foreach ci $take { lappend block [lindex $graphs $ci] }
  foreach ci [lsort -integer -decreasing $take] {
    set graphs [lreplace $graphs $ci $ci]
  }
  # 2. the destination block: the relocated strips take the slots NEAREST the
  # source, in the order they were chosen, and the shortfall is created after
  # them. All of them are empty, so the split reads the same either way; fixing
  # the order keeps the result assertable by strip identity.
  for {set k 0} {$k < [dict get $plan new]} {incr k} {
    lappend block [wviewer::empty_graph]
  }
  set at [dict get $plan at]
  for {set k [expr {[llength $block] - 1}]} {$k >= 0} {incr k -1} {
    set graphs [linsert $graphs $at [lindex $block $k]]
  }
  # 3. the traces, from the split strip's POST-removal index
  set src [dict get $plan src]
  for {set k [expr {$nc - 1}]} {$k >= 1} {incr k -1} {
    set ti [wviewer::trace_index_of_node [lindex $graphs $src] $k]
    if {$ti < 0} { continue }
    set graphs [wviewer::move_trace_in_graphs $graphs $src $ti [expr {$src + $k}]]
  }
  return $graphs
}

# THE authoritative strip split. Returns the NUMBER of NEW strips created, or
# {} on failure/refusal.
#
# ⚠ **0 IS A SUCCESS, not a refusal** (D4). A two-trace strip with an empty strip
# already below it splits by CONSUMING that strip and inserting nothing, so the
# count of new strips is zero while a real state change happened: it mutates, it
# takes an undo point and it LOGS. Only `{}` means "nothing happened". Callers
# testing the return must test for {} — `if {!$n}` would read a legitimate split
# as a failure.
#
# Same ordering contract as move_strip / move_trace / move_trace_to_new_strip:
#   1. resolve + validate the index against the LIVE model
#   2. REFUSE, without mutating and without logging, a strip with fewer than two
#      drawn traces — it is already split. The menu gate mirrors this
#   3. verified switch_ctx  4. capture  5. push_undo  6. the pure split, whose
#      reuse decision comes from the PURE plan_split (D3/D4) — called here too,
#      on the same graph list, so the target arithmetic below and the model op
#      cannot disagree about what moved where
#   7. remap the stored TARGET through the plan, IN PLACE, with the PURE
#      target_after_split — a split has no single destination to adopt, so the
#      target keeps pointing at the strip it was on, and the split strip itself
#      does not move relative to its own traces, so a target that WAS the split
#      strip stays with node 0.
#      ⚠ The remap is a REMOVAL then an insertion, never a bare
#      index_after_insert: relocating an empty strip from above the split lifts
#      every strip below it up one slot before the destination block goes in, and
#      a target that IS the relocated strip follows it by identity
#   8. exactly ONE regenerate, exactly ONE fully-resolved log line
#
# REPLAY DETERMINISM: the logged line is `split_strip <gi> <token>` — unchanged,
# carrying no reuse decision — and that stays correct because plan_split is a
# pure function of the model a replay reproduces. Asserted (SG16), not assumed.
proc wviewer::split_strip {gi {token {}}} {
  variable windows
  variable target
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to split a strip in" error
    }
    return {}
  }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set n [llength $gs]
  if {![string is integer -strict $gi] || $gi < 0 || $gi >= $n} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: bad strip index '$gi' (0..[expr {$n - 1}])" error
    }
    return {}
  }
  set nc [wviewer::node_count [lindex $gs $gi]]
  if {$nc < 2} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: strip $gi is already split (one drawn trace)" error
    }
    return {}
  }
  if {![wviewer::switch_ctx $token]} { return {} }
  wviewer::capture_live_graph_state $token
  wviewer::push_undo $token           ;# AFTER the capture: `u` restores the view
  set gs [dict get [wviewer::layout_for $token] graphs]
  set auto [wviewer::auto_graph_index $token]
  set maxdist [wviewer::reuse_max_distance]
  set plan [wviewer::plan_split $gs $gi $auto $maxdist]
  # the target is read BEFORE the mutation: the remap is expressed in the
  # PRE-split index space (the plan's `take` indices are), and target_index
  # clamps against the live strip count
  set tgt [wviewer::target_index $token]
  # §8: the highlight set is read in the SAME pre-split index space, for the same
  # reason, and applied after set_graphs because a split GROWS the strip count
  set hlset [wviewer::wave_hilights $token]
  wviewer::set_graphs $token \
    [wviewer::split_graph_in_graphs $gs $gi $auto $maxdist]
  wviewer::wavehl_remap_apply $token [wviewer::wavehl_after_split $hlset $plan $gi]
  if {[info exists target($token)]} {
    set target($token) [wviewer::target_after_split $tgt $plan]
  }
  wviewer::regenerate $token
  wviewer::log_action [list wviewer::split_strip $gi $token]
  return [dict get $plan new]
}

# The menubar twin's payload: split the TARGET strip. Unlike item 7 — whose
# operation needs a trace under the pointer and so has no menubar form — a
# split acts on a whole strip, and the target IS the window's current strip
# (issue 0151: it carries the dull-yellow active bar, so the user can see which
# one this will act on). Logs the RESOLVED index through split_strip, so a
# replay does not depend on where the target happened to be.
proc wviewer::split_target_strip {{token {}}} {
  set token [wviewer::resolve_token $token]
  if {$token eq {}} { return {} }
  return [wviewer::split_strip [wviewer::target_index $token] $token]
}

# --- undo / redo of viewer model edits ---------------------------------------
# `u` undoes, `U` (Shift-u) redoes, bound on the shared `WaveViewer` bindtag
# like Clear All (issue 0171) — NOT on the canvas, which strip_bindings sweeps.
#
# A viewer edit is a change to the TCL MODEL (the `layouts` graph list + the
# target strip), not a schematic edit: the viewer buffer is readonly, its rects
# are regenerated wholesale from that model, and the C undo stack is about
# schematic objects. So the history here is a stack of MODEL SNAPSHOTS taken by
# the mutating command itself, and undo is "put that snapshot back and
# regenerate". Nothing else can be layered on the C undo without making the
# readonly buffer editable.
#
# What is (and is not) in a snapshot: the graph list carries traces, colors,
# axis ranges, `auto`, `hilight_wave` — everything durable — plus the target
# index. The window OPTIONS (plot mode, sharedx, cursor mirrors, the loaded raw)
# are deliberately outside it: they are not edits of the plot content, and an
# undo that silently flipped the plot mode would be a surprise.
#
# Snapshots are taken AFTER capture_live_graph_state, so "what the user was
# looking at" (a mouse pan/zoom, the bold trace) is what comes back.

# The undoable state of `token`: {graphs target}.
proc wviewer::state_snapshot {token} {
  return [list [dict get [wviewer::layout_for $token] graphs] \
               [wviewer::target_index $token]]
}

# Put a snapshot back and redraw. One regenerate, like every other model write.
proc wviewer::state_apply {token snap} {
  variable target
  lassign $snap gs tgt
  wviewer::set_graphs $token $gs
  if {[string is integer -strict $tgt]} { set target($token) $tgt }
  wviewer::regenerate $token
  return 1
}

# Record the CURRENT state as an undo point. Called by a mutating command after
# capture_live_graph_state and before it changes anything; a new edit drops the
# redo branch, the usual linear-history rule. Returns 1 when a point was pushed.
proc wviewer::push_undo {token} {
  variable windows
  variable undo_hist; variable redo_hist; variable undo_depth
  if {![dict exists $windows $token]} { return 0 }
  lappend undo_hist($token) [wviewer::state_snapshot $token]
  if {[llength $undo_hist($token)] > $undo_depth} {
    set undo_hist($token) \
      [lrange $undo_hist($token) end-[expr {$undo_depth - 1}] end]
  }
  set redo_hist($token) {}
  return 1
}

# Drop both stacks (open / forget / any point where the history would describe
# a model the window no longer has).
proc wviewer::clear_history {token} {
  variable undo_hist; variable redo_hist
  set undo_hist($token) {}
  set redo_hist($token) {}
  return {}
}

# How many steps are available, as {undo redo} — the test/UI seam.
proc wviewer::history_depth {{token {}}} {
  variable undo_hist; variable redo_hist
  set token [wviewer::resolve_token $token]
  if {$token eq {}} { return {0 0} }
  set u 0; set r 0
  if {[info exists undo_hist($token)]} { set u [llength $undo_hist($token)] }
  if {[info exists redo_hist($token)]} { set r [llength $redo_hist($token)] }
  return [list $u $r]
}

# Shared body of undo/redo: `dir` is `undo` or `redo`. Pops one snapshot off its
# own stack, pushes the CURRENT state onto the other one (so the pair is
# symmetric and repeatable), applies it, logs one resolved line. Returns 1, or
# {} when there is nothing to do / no viewer / a busy ctx.
proc wviewer::history_step {dir token} {
  variable windows
  variable undo_hist; variable redo_hist
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to $dir in" error
    }
    return {}
  }
  if {$dir eq {undo}} {
    upvar #0 ::wviewer::undo_hist from ::wviewer::redo_hist to
  } else {
    upvar #0 ::wviewer::redo_hist from ::wviewer::undo_hist to
  }
  if {![info exists from($token)] || ![llength $from($token)]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: nothing to $dir"
    }
    return {}
  }
  if {![wviewer::switch_ctx $token]} { return {} }
  # freeze what the mouse wrote into the rects first, so the state pushed on the
  # opposite stack is the one the user is actually looking at
  wviewer::capture_live_graph_state $token
  set snap [lindex $from($token) end]
  set from($token) [lrange $from($token) 0 end-1]
  lappend to($token) [wviewer::state_snapshot $token]
  # THE TRACE HIGHLIGHTS GO (doc/claude/specs/wave_trace_hilight.md D4). The set
  # is deliberately NOT in the undo unit -- it is view state, like the plot mode
  # and the cursors, and spec §14 keeps window state out of a snapshot. But the
  # snapshot about to be applied is a DIFFERENT graph list, and a (gi, ni) that
  # addressed the old one would come back pointing at some other strip's other
  # trace. Losing a highlight across an undo is a cosmetic annoyance; painting
  # the WRONG trace is a lie. Same call `restore` makes, for the same reason.
  wviewer::wave_hilight_clear_set $token
  wviewer::state_apply $token $snap
  wviewer::log_action [list wviewer::$dir $token]
  return 1
}

# Undo / redo the last viewer model edit (strip reorder, trace move). Optional
# token like every other viewer command; {} when there is nothing to do.
proc wviewer::undo {{token {}}} { return [wviewer::history_step undo $token] }
proc wviewer::redo {{token {}}} { return [wviewer::history_step redo $token] }

# %W-resolving wrappers for the WaveViewer bindtag (the clear_all_at pattern:
# resolve the window the KEY went to, never the current xschem ctx).
proc wviewer::undo_at {W} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  return [wviewer::undo $token]
}
proc wviewer::redo_at {W} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  return [wviewer::redo $token]
}

# The NODE index of the trace of strip `gi` under canvas pixel (px,py), or -1 —
# the C engine's own answer (`xschem get graph_trace_at`, draw.c graph_wave_at),
# measured in screen pixels through the engine's transform. Fails CLOSED (-1 =
# "no trace here") so a missing verb or an errored query degrades to the previous
# behaviour instead of grabbing something.
# 1 when canvas pixel (px,py) is inside strip `gi`'s PLOT BOX — the rectangle
# between the axes, NOT the whole band: the legend/label margins answer 0. The
# engine's own answer (`xschem get graph_plotbox_at`, draw.c graph_plotbox_at,
# the item-9 snap-cursor gate), because the margins come out of the engine's
# transform and Tcl re-deriving them would drift the moment they change.
#
# Fails CLOSED (0 = "not in the box") so a missing verb or an errored query
# degrades to no menu rather than to a menu over the wave labels. It inherits
# the C refusals wholesale: an off-screen graph, no loaded data and — the one
# that shows — a DIGITAL or bus strip all answer 0.
proc wviewer::plotbox_at {wp gi px py} {
  if {[catch {xschem new_schematic switch $wp}]} { return 0 }
  set r 0
  catch {set r [xschem get graph_plotbox_at $gi $px $py]}
  if {![string is integer -strict $r]} { return 0 }
  return [expr {$r ? 1 : 0}]
}

# ⚠ the default MIRRORS GRAPH_TRACE_PICK_TOL (src/xschem.h, 10 screen px). Since
# issue 0174 the C-side LMB wave-bold click picks with the SAME number, so this
# proc and that arm agree about "close enough" by construction; three picking
# surfaces on one strip disagreeing is the next bug report.
proc wviewer::trace_at {wp gi px py {tol 10}} {
  if {[catch {xschem new_schematic switch $wp}]} { return -1 }
  set r -1
  catch {set r [xschem get graph_trace_at $gi $px $py $tol]}
  if {![string is integer -strict $r]} { return -1 }
  return $r
}

# Which LEGEND entry of strip `gi` is under canvas pixel (px,py)? NODE index
# (landmine 34) or -1. The legend's counterpart to trace_at, and the same
# fail-closed contract: a missing verb, an errored query or a non-integer answer
# all read as "no entry there", never as "locked out".
#
# ⚠ The legend and the plot body are DIFFERENT picking surfaces of one strip and
# they do not overlap: inside the plot box this answers -1 and trace_at does the
# work; in the legend band it is the other way round. Nothing needs to choose
# between them — the C click arm asks whichever one owns the pixel.
proc wviewer::legend_at {wp gi px py} {
  if {[catch {xschem new_schematic switch $wp}]} { return -1 }
  set r -1
  catch {set r [xschem get graph_legend_at $gi $px $py]}
  if {![string is integer -strict $r]} { return -1 }
  return $r
}

# PURE: normalise a `sel_waves` token value (issue 0175) to a clean ascending
# list of NODE indices — the Tcl mirror of draw.c's graph_sel_waves_get parse, so
# the model and the engine agree on what a selection IS. Garbage, negatives and
# duplicates are dropped rather than passed on; {} in, {} out.
proc wviewer::sel_waves_norm {v} {
  set out {}
  foreach t [split [string map {"\n" { } "\t" { }} $v] { }] {
    if {$t eq {}} { continue }
    if {![string is integer -strict $t]} { continue }
    if {$t < 0} { continue }
    if {[lsearch -exact $out $t] >= 0} { continue }
    lappend out $t
  }
  return [lsort -integer $out]
}

# The whole selection of strip `gi` as a NODE-index list, read off the RECT.
# {} when nothing is selected. Composes the two tokens the way the engine does:
# `sel_waves` when it carries two or more, else `hilight_wave` when it is >= 0.
# An ABSENT hilight_wave is NOT node 0 (a bare atoi("") would say it is).
proc wviewer::selected_waves {wp gi} {
  if {[catch {xschem new_schematic switch $wp}]} { return {} }
  set sw {}
  catch {set sw [xschem getprop rect 2 $gi sel_waves]}
  set l [wviewer::sel_waves_norm $sw]
  if {[llength $l]} { return $l }
  set hw {}
  catch {set hw [xschem getprop rect 2 $gi hilight_wave]}
  if {[string is integer -strict $hw] && $hw >= 0} { return [list $hw] }
  return {}
}

# THE window-wide selection as MODEL {gi ti} pairs, ascending — the ONE place
# that folds `selected_waves` across every strip (issue 0192 D-53). Both
# consumers go through it: the DEL key (delete_selection_at) and the multi-trace
# drag arm (trace_drag_arm).
#
# ⚠ One fold, deliberately. Two copies of this loop would drift — landmine
# 43/46(a) is the same lesson from the draw side — and the drift is invisible to
# any test that exercises only one of the two paths: with a single-trace
# selection every plausible variant of this loop gives the same answer.
#
# The mapping is landmine 34's: `selected_waves` answers in NODE space (what the
# rect stores), the model indexes TRACES, and a vec-less trace occupies a model
# slot and no node slot. `trace_index_of_node` is the crossing, and a node that
# maps nowhere is dropped rather than guessed at.
proc wviewer::selection_pairs {W} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  set out {}
  set gi 0
  foreach G [dict get [wviewer::layout_for $token] graphs] {
    foreach ni [wviewer::selected_waves $W $gi] {
      set ti [wviewer::trace_index_of_node $G $ni]
      if {$ti >= 0} { lappend out [list $gi $ti] }
    }
    incr gi
  }
  return $out
}

# PURE: the subset of MODEL {gi ti} `pairs` that a drop on strip `to_gi` would
# actually MOVE — D-44, and THE one place the rule is expressed. A carried trace
# that is already on the destination stays exactly where it is (re-appending it
# would silently reorder a strip the user did not ask to reorder), so the
# destination being one of the SOURCE strips — including the strip the press
# itself landed on — is not a refusal: the traces that are elsewhere still move
# in. It is only when this comes back EMPTY that the drop is a no-op.
#
# Malformed pairs and a bad `to_gi` are dropped here rather than diagnosed: this
# is the gesture layer's "would anything happen" question. `move_traces` still
# validates every surviving pair LOUDLY against the live model.
proc wviewer::movable_pairs {pairs to_gi} {
  if {![string is integer -strict $to_gi] || $to_gi < 0} { return {} }
  set out {}
  foreach p $pairs {
    if {[llength $p] != 2} { continue }
    if {[lindex $p 0] == $to_gi} { continue }
    lappend out $p
  }
  return $out
}

# Paint the prospective destination strip of a trace drag: clear the frame on
# `old`, put one on `new`. Rides the SAME `reorder_handle` prop token as the grip
# and the strip drop bar (value 4 = frame around the whole strip — the target is
# the strip, not one of its edges), rewritten IN PLACE on the affected rects and
# redrawn. Never a regenerate (it would undo a live pan/zoom on every Motion) and
# never a model mutation.
#
# `pairs` is the MODEL {gi ti} set the gesture is carrying, and the frame appears
# exactly when dropping HERE would commit something — i.e. when `movable_pairs`
# is non-empty. That is the same predicate the drop itself uses, so the frame can
# never promise a move that the release then refuses, nor stay dark for one it
# performs. For the single-trace drag it reduces to the shipped rule ("back where
# it started -> no frame"); for a selection spanning several strips the pressed
# strip DOES get framed, because the traces from the other strips move into it.
proc wviewer::trace_drag_feedback {token old new pairs} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set n [llength [dict get [wviewer::layout_for $token] graphs]]
  set moves [llength [wviewer::movable_pairs $pairs $new]]
  if {[catch {
    wviewer::with_edit $token {
      if {$old >= 0 && $old < $n} {
        xschem setprop -fast rect 2 $old reorder_handle 1
      }
      if {$new >= 0 && $new < $n && $moves} {
        xschem setprop -fast rect 2 $new reorder_handle 4
      }
      xschem redraw
    }
  }]} { return 0 }
  return 1
}

# Zero the transient state (no feedback, no cursor work) — the initializer.
proc wviewer::trace_drag_clear {token} {
  variable tdrag_gi; variable tdrag_ti; variable tdrag_to
  variable tdrag_x0; variable tdrag_y0; variable tdrag_active
  variable tdrag_pairs
  set tdrag_gi($token) -1
  set tdrag_ti($token) -1
  set tdrag_to($token) -1
  set tdrag_x0($token) 0
  set tdrag_y0($token) 0
  set tdrag_active($token) 0
  set tdrag_pairs($token) {}    ;# issue 0192: the moving SET dies with the gesture
  return {}
}

# Disarm: clear any drop frame, restore the pointer, forget the gesture. Safe to
# call when nothing is armed (every exit path funnels through it). Returns 1 when
# a drag WAS armed.
proc wviewer::trace_drag_reset {token} {
  variable windows
  variable tdrag_gi; variable tdrag_to
  set had 0
  if {[info exists tdrag_gi($token)] && $tdrag_gi($token) >= 0} { set had 1 }
  # item 6: take the shrink preview down FIRST, so the single redraw inside
  # trace_drag_feedback below already paints the trace at full size. Doing it
  # after would leave a shrunk trace on screen until the next repaint on the
  # paths where no feedback frame was ever painted.
  if {$had} { catch {wviewer::drag_preview_clear $token} }
  if {$had && [info exists tdrag_to($token)] && $tdrag_to($token) >= 0} {
    # `new` is -1 here, so no frame is ever painted and the carried set is
    # irrelevant to this call — {} says so rather than passing a stale one
    wviewer::trace_drag_feedback $token $tdrag_to($token) -1 {}
  }
  wviewer::trace_drag_clear $token
  if {[dict exists $windows $token]} {
    catch {[dict get $windows $token win_path] configure -cursor {}}
  }
  return $had
}

# Arm a trace drag from a press that landed ON a trace of strip `gi`. Called by
# strip_drag_press (which has already re-targeted and forwarded the press to C)
# for exactly the presses the strip reorder refuses. Returns 1 when a trace was
# picked up.
#
# The pointer becomes the GRAB HAND right here, on the press — not at the drag
# threshold — because that is the affordance: pressing a trace means you are
# holding it (the Acrobat pan-hand precedent). A press that turns out to be a
# plain click (the wave-bold toggle) restores it on release, unchanged.
#
# THE MOVING SET is decided HERE, on the press (issue 0192, D-41): if the pressed
# trace is in the live selection the whole window-wide selection travels;
# otherwise just this trace does. A press on an UNSELECTED trace neither extends
# nor collapses nor clears the selection — the gesture simply ignores it, which
# is the rule issue 0174 D3 already settled for clicks.
#
# Press time, not drop time, and both reasons are load-bearing:
#   * the shrink preview arms at the 3-px threshold and needs the set then;
#   * strip_drag_release forwards the release to C BEFORE trace_drag_drop runs,
#     and a no-travel release COLLAPSES the selection to the clicked trace
#     (measured). Reading at drop time would work only because the drag
#     travelled — a coincidence, not a contract.
proc wviewer::trace_drag_arm {W token gi px py {ni {}}} {
  variable windows
  variable tdrag_gi; variable tdrag_ti; variable tdrag_to
  variable tdrag_x0; variable tdrag_y0; variable tdrag_active
  variable tdrag_pairs
  if {![string is integer -strict $ni]} { set ni [wviewer::trace_at $W $gi $px $py] }
  if {$ni < 0} { return 0 }
  set gs [dict get [wviewer::layout_for $token] graphs]
  if {$gi < 0 || $gi >= [llength $gs]} { return 0 }
  set ti [wviewer::trace_index_of_node [lindex $gs $gi] $ni]
  if {$ti < 0} { return 0 }
  set tdrag_pairs($token) [list [list $gi $ti]]
  set sel [wviewer::selection_pairs $W]
  if {[lsearch -exact $sel [list $gi $ti]] >= 0} { set tdrag_pairs($token) $sel }
  set tdrag_gi($token) $gi
  set tdrag_ti($token) $ti
  # -1 = "no destination decided yet", the same value trace_drag_clear uses. It
  # used to be `$gi`, which made the first motion inside the PRESSED strip look
  # like "nothing changed" and so skipped the feedback call — invisible while a
  # drop on that strip was refused outright, wrong once it can commit (D-44).
  set tdrag_to($token) -1
  set tdrag_x0($token) $px
  set tdrag_y0($token) $py
  set tdrag_active($token) 0
  wviewer::set_drag_cursor $W hand2
  return 1
}

# <B1-Motion> while a trace drag is armed. Below the 3-pixel click tolerance the
# motion still belongs to the C engine (hover measurement), so it is NOT consumed
# — a press that ends up being a click behaves exactly as before. Past it the drag
# owns the pointer: the motion is swallowed, the pointer stays the grab hand and
# the prospective destination is repainted ONLY when it actually changes.
# Returns 1 when the event was consumed.
# --- mid-drag shrink preview (viewer plan item 6) -----------------------------
# doc/claude/specs/waveform_viewer.md. While a trace is being dragged to another
# strip it is drawn vertically shrunk, so the pointer visibly carries something.
#
# It is RENDER STATE ONLY — three numbers in xctx, no prop token, no model
# write, no undo point, and draw_graph applies it only for `flags & 16`, so no
# export ever sees a shrunk trace. That is the marker-scratch idea
# (graph_markers.md §3.5) applied to a polyline: a motion event costs nothing.

# The shrink factor. rc-overridable; 0.9 = the requested 10 %.
# Out-of-range or unparseable values fall back to the default rather than
# arming something silly (0 would disarm, a negative would mirror the trace).
proc wviewer::drag_shrink {} {
  set d 0.7
  if {![info exists ::wviewer_drag_shrink]} { return $d }
  set v [string trim $::wviewer_drag_shrink]
  if {![string is double -strict $v]} { return $d }
  if {$v <= 0.0 || $v > 1.0} { return $d }
  return $v
}

# Arm the preview for the MODEL {gi ti} `pairs` a multi-trace drag is carrying,
# and repaint (issue 0192). ONE `xschem set graph_preview` for the whole set, so
# one motion event is one C call and one redraw however many traces travel.
#
# The C side speaks NODE indices (the hilight_wave / graph_trace_at space), so
# every model index goes through node_index_of_trace first — mixing the two would
# shrink a different trace whenever any trace carries an empty `vec` (landmine
# 34). A pair that maps to -1 is a vec-less trace: it draws nothing, so it is
# dropped rather than refused. Nothing left to preview -> no arm at all.
# Returns 1 when a preview was armed.
proc wviewer::drag_preview_arm_set {token pairs} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set n [llength $gs]
  set flat {}
  foreach p $pairs {
    if {[llength $p] != 2} { continue }
    lassign $p gi ti
    if {![string is integer -strict $gi] || $gi < 0 || $gi >= $n} { continue }
    set ni [wviewer::node_index_of_trace [lindex $gs $gi] $ti]
    if {$ni < 0} { continue }                  ;# a vec-less trace draws nothing
    lappend flat $gi $ni
  }
  if {![llength $flat]} { return 0 }
  if {![wviewer::switch_ctx $token]} { return 0 }
  # head first, then the trailing pairs: the C head keeps its pre-0192 meaning
  set cmd [list xschem set graph_preview [lindex $flat 0] [lindex $flat 1] \
             [wviewer::drag_shrink]]
  foreach v [lrange $flat 2 end] { lappend cmd $v }
  if {[catch {eval $cmd}]} { return 0 }
  catch {xschem redraw}
  return 1
}

# The SINGLE-trace arm: a one-line wrapper over the plural form above, so there
# is one implementation and the shipped signature/return contract are unchanged.
proc wviewer::drag_preview_arm {token gi ti} {
  return [wviewer::drag_preview_arm_set $token [list [list $gi $ti]]]
}

# Disarm and repaint. Idempotent, and cheap enough to call on every teardown
# path — `set graph_preview 0` on an unarmed context is a no-op. The redraw is
# what puts the trace back at full size, so it must not be skipped.
proc wviewer::drag_preview_clear {token} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  if {![wviewer::switch_ctx $token]} { return 0 }
  if {[catch {xschem set graph_preview 0}]} { return 0 }
  catch {xschem redraw}
  return 1
}

proc wviewer::trace_drag_motion {W px py state} {
  variable tdrag_gi; variable tdrag_to; variable tdrag_ti
  variable tdrag_x0; variable tdrag_y0; variable tdrag_active
  variable tdrag_pairs
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return 0 }
  if {![info exists tdrag_gi($token)] || $tdrag_gi($token) < 0} { return 0 }
  set from $tdrag_gi($token)
  # the MODEL set this gesture is carrying, decided at press time. Both the
  # shrink preview and the drop-target frame read it, so it is resolved ONCE
  # here — a second reconstruction would be a second copy of the fallback.
  set pset [list [list $from $tdrag_ti($token)]]
  if {[info exists tdrag_pairs($token)] && [llength $tdrag_pairs($token)]} {
    set pset $tdrag_pairs($token)
  }
  if {!$tdrag_active($token)} {
    if {abs($px - $tdrag_x0($token)) <= 3 && abs($py - $tdrag_y0($token)) <= 3} {
      return 0
    }
    set tdrag_active($token) 1
    wviewer::set_drag_cursor $W hand2
    # viewer plan item 6 (decision D-E: the TRACE drag, not the strip reorder):
    # the moment the gesture becomes a drag, the trace being carried is drawn
    # vertically shrunk, so it reads as "picked up" and stops being confusable
    # with the traces it is passing over. Armed ONCE, here, not on every motion:
    # it is pure render state and nothing about it changes as the pointer moves.
    # issue 0192: EVERY carried trace shrinks, so the arm takes the whole moving
    # set decided at press time — one trace when the press was not on a selected
    # one, which is the shipped single-trace case with n = 1.
    wviewer::drag_preview_arm_set $token $pset
  }
  # the destination simply FOLLOWS THE POINTER: the strip it is over, or (outside
  # every band) none, which the release reads as "cancel"
  set to [wviewer::strip_at_pixel $W $px $py]
  if {$to != $tdrag_to($token)} {
    set old $tdrag_to($token)
    set tdrag_to($token) $to
    wviewer::trace_drag_feedback $token $old $to $pset
  }
  return 1
}

# <ButtonRelease-1> while a trace drag is armed. The caller (strip_drag_release)
# has already handed the release to C — the wave-bold click and any cursor
# bookkeeping are untouched. A drag that PASSED the threshold and ended over a
# strip commits the traces that are not already on that strip; a drop outside
# every strip, a sub-threshold click and a drop where NOTHING would move commit
# nothing and log nothing. Returns the destination trace index when a move
# happened, else {}.
#
# ⚠ THE DESTINATION MAY BE THE PRESSED STRIP. `movable_pairs` decides, not
# `to == from`: with a selection spanning several strips, a drop back on the
# strip the press landed on moves the OTHER strips' traces in and leaves the
# pressed one where it is (D-44). Refusing on `to == from` — which is what
# 5648fe6f shipped — short-circuits that whole gesture, and the single-strip
# selection it was meant to cover is already a no-op through the empty
# `movable`. The other two terms (`!$active`, `$to < 0`) still refuse outright.
proc wviewer::trace_drag_drop {W} {
  variable tdrag_gi; variable tdrag_ti; variable tdrag_to; variable tdrag_active
  variable tdrag_pairs
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  if {![info exists tdrag_gi($token)] || $tdrag_gi($token) < 0} { return {} }
  set from $tdrag_gi($token)
  set ti $tdrag_ti($token)
  set to $tdrag_to($token)
  set active $tdrag_active($token)
  set pairs [list [list $from $ti]]
  if {[info exists tdrag_pairs($token)] && [llength $tdrag_pairs($token)]} {
    set pairs $tdrag_pairs($token)
  }
  wviewer::trace_drag_reset $token          ;# reads before it clears
  if {!$active || $to < 0} { return {} }
  # issue 0192: what actually MOVES is the carried set minus whatever is already
  # on the destination (D-44) — a trace that is there does not move, and a drop
  # where nothing would move commits nothing and logs nothing.
  set movable [wviewer::movable_pairs $pairs $to]
  if {![llength $movable]} { return {} }
  # catch: both mutations regenerate, and with_edit ERRORS on a refused context
  # switch (raised semaphore). Inside a Tk binding that would pop bgerror's
  # stack-trace modal over the viewer; a refused move must just not happen.
  set r {}
  if {[llength $movable] == 1 && [lindex $movable 0] eq [list $from $ti]} {
    # D-42: the single-trace gesture keeps calling the SHIPPED mutation, because
    # `wviewer::move_trace <gi> <ti> <to> <tok>` is a REPLAY CONTRACT — it is what
    # TD1/TD2/TD7 assert verbatim and what every action log already on disk says.
    catch {set r [wviewer::move_trace $from $ti $to $token]}
  } else {
    catch {set r [wviewer::move_traces $movable $to $token]}
  }
  return $r
}

# Plain MIDDLE-button press / drag / release: the GRAPH pan.
#
# MMB used to be swallowed outright in this window (issue 0149) because it was
# the schematic CANVAS pan and panning the canvas slides the whole tiled graph
# stack around and exposes blank space. It now IS the graph pan (callback.c:
# waves_selected no longer skips Button2, and the pan motion arm moved from
# Button1Mask to Button2Mask), which pans the DATA RANGES and leaves the canvas
# pinned — so it is forwarded instead.
#
# The PRESS decides, and only the press: it is accepted only when it lands
# `inset` pixels inside a strip, so it cannot fall in the seam where
# waves_selected refuses to graph-route and start_pan_logged would take over.
# The motions and the release then follow that decision, so a refused press can
# never leak a half-canvas-pan. Ctrl+MMB (the pin-type edit chord, a mutating
# action) and Alt+MMB stay swallowed.
proc wviewer::btn2_filter {W T px py state} {
  variable mmb
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return }
  if {$T == 4} {
    set mmb($token) 0
    if {$state & 12} { return }                       ;# Control | Mod1
    if {[wviewer::strip_at_pixel_inset $W $px $py] < 0} { return }
    set mmb($token) 1
    catch {focus $W}
  }
  if {![info exists mmb($token)] || !$mmb($token)} { return }
  if {$T == 6} {
    xschem callback $W $T $px $py 0 0 0 $state        ;# Motion: no button arg
  } else {
    xschem callback $W $T $px $py 0 2 0 $state
  }
  if {$T == 5} {
    set mmb($token) 0
    catch {wviewer::readout_refresh $token}
  }
}

# Land a batch of signals sent from the schematic (Direct Plot / Ctrl-4) per
# the window's plot mode — the ONE seam ase::ui::dp_finish calls. Creates the
# strips plan_plot asks for, then appends one trace per signal at its planned
# index. Returns a list of {expr error} pairs for the signals that failed
# (add_trace returns a message, never throws); {} = every signal landed.
#
# `colors` (issue 0153) pins one color per signal, in the same order. The Direct
# Plot picker passes the colors it already painted the schematic nets with. When
# it is {} the colors are derived here from the same policy (plan_colors), which
# is what makes multi-plot cycle colors instead of giving every fresh strip the
# palette head — so any caller gets that fix, not just the picker.
proc wviewer::plot_signals {token exprs {colors {}}} {
  variable windows
  if {![dict exists $windows $token]} {
    return [list [list {} "unknown viewer window"]]
  }
  # issue 0194: the ONE capture for the whole batch, before any strip is
  # created. add_trace's own capture cannot serve here — it runs after the
  # strips were added, where the 1:1 rect/model guard refuses it.
  wviewer::capture_live_view_state $token
  set gs [dict get [wviewer::layout_for $token] graphs]
  set mode [wviewer::plot_mode $token]
  set auto [wviewer::auto_graph_index $token]
  set plan [wviewer::plan_plot $mode [llength $gs] \
                               [wviewer::target_index $token] [llength $exprs] \
                               $auto [wviewer::empty_graph_indices $gs $auto]]
  if {![llength $colors]} {
    # `gs` is the PRE-batch strip list, which is what plan_colors expects
    set colors [wviewer::plan_colors $gs $mode [dict get $plan targets]]
  }
  # create the strips the plan asked for. WHERE they go is mode-dependent and is
  # the other half of plan_plot's index contract: multi-plot puts new strips at
  # the TOP (newest first, 2026-07-27 request) — which renumbers everything
  # already on the canvas, so the stored target is shifted by the same amount to
  # keep the marker on the strip it was on. single-plot appends at the bottom,
  # where its own targets say it does.
  set nnew [dict get $plan new]
  if {$nnew > 0} {
    set fresh {}
    for {set k 0} {$k < $nnew} {incr k} { lappend fresh [wviewer::empty_graph] }
    if {$mode eq {multi}} {
      variable target
      set cur [wviewer::target_index $token]
      wviewer::set_graphs $token [concat $fresh $gs]
      if {[llength $gs]} { set target($token) [expr {$cur + $nnew}] }
      # §8: a FRONT insert renumbers every strip already on the canvas, so the
      # highlight set owes the identical +nnew shift the target just took --
      # otherwise a batch plotted into a window with a highlighted trace moves
      # the highlight onto a different strip. After set_graphs, because the
      # remap validates `gi` against the LIVE strip count.
      if {[llength $gs]} {
        wviewer::wavehl_remap_apply $token \
          [wviewer::wavehl_after_prepend [wviewer::wave_hilights $token] $nnew]
      }
    } else {
      wviewer::set_graphs $token [concat $gs $fresh]
    }
  }
  # single-plot: the strip the batch actually landed in becomes the target, so
  # the next gesture accumulates there. This matters whenever the stored target
  # was unusable and plan_plot resolved elsewhere — a strip it CREATED (empty
  # stack / target was the tool-owned auto strip) or, since the 0171 follow-up,
  # an empty strip it REUSED. Idempotent otherwise: set_target_strip is a no-op
  # (and logs nothing) when the index does not change. multi-plot never moves
  # the target (spec §3.3).
  if {$mode ne {multi} && [llength [dict get $plan targets]]} {
    wviewer::set_target_strip [lindex [dict get $plan targets] 0] $token
  }
  set errs {}
  foreach ex $exprs gi [dict get $plan targets] col $colors {
    set err [wviewer::add_trace $token $gi $ex {} $col]
    if {$err ne {}} { lappend errs [list $ex $err] }
  }
  # every add_trace regenerates on success, so the canvas normally already
  # matches the model; when the whole batch failed (bad exprs, no raw) the
  # strips created above would otherwise exist only in the model
  if {$nnew > 0 && [llength $errs] == [llength $exprs]} {
    wviewer::regenerate $token
  }
  return $errs
}

# --- Clear All (issue 0171) --------------------------------------------------

# Delete EVERYTHING in the viewer of `token` and start from scratch: one empty
# strip remains, so the window still reads as a graph window and the next
# Direct Plot has somewhere to land (plan_plot's empty-stack arm would create
# one anyway — leaving zero strips would just render a blank canvas until the
# next gesture).
#
# KEPT, by design — a clear is about CONTENT, not about the window's setup:
#   - the plot mode (single|multi): explicitly retained, so a user working in
#     multi-plot keeps working in multi-plot after a clear;
#   - Shared X and the cursor/readout mirrors (window options, same argument);
#   - the ATTACHED RAW DATA. `xschem raw clear` would also kill every `raw add`
#     expression vector and force a re-run before anything could be plotted
#     again; the point of a clear is to re-pick signals from the SAME results.
# GONE: every graph, every trace, and the `auto 1` marker with them — the next
# auto-plot run then APPENDS its own strip (ensure_auto_graph) instead of
# adopting the survivor. Keeping the marker on the survivor would make the one
# visible strip tool-owned, and item 13's always-replace rebuild would silently
# wipe anything the user hand-picked into it (plan_plot excludes exactly that
# strip for the same reason).
#
# The target strip resets to 0 — the only strip there is.
#
# Optional token like every other command in this section ({} = the viewer
# window owning the current xschem context). Returns 1, or {} plus a CIW error
# when no viewer resolves. Logged replayably on EVERY successful call, unlike
# set_plot_mode/set_target_strip's change-only rule: a clear is a destructive
# gesture, and a replay that skipped a "redundant" one would rebuild a
# different window whenever the gesture was not in fact redundant.
proc wviewer::clear_all {{token {}}} {
  variable windows
  variable layouts
  variable target
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to clear" error
    }
    return {}
  }
  set lay [wviewer::layout_for $token]
  dict set lay graphs [list [wviewer::empty_graph]]
  dict set layouts $token $lay
  set target($token) 0
  # §8: every strip is gone, so the whole highlight set goes with it. Dropped
  # here rather than remapped, and WITHOUT its own log line -- clear_all logs one
  # line for the whole destruction and a replay of it re-runs this.
  wviewer::wave_hilight_clear_set $token
  wviewer::regenerate $token
  # every strip is gone, so a selected marker number now points at nothing.
  # `empty_graph` has no `markers` key, so the markers themselves die by
  # construction; only the UI selection (xctx state, not content) needs the
  # explicit reset. regenerate left the viewer as the current context.
  catch {xschem graph_marker select -none}
  wviewer::log_action [list wviewer::clear_all $token]
  return 1
}

# --- grid on/off (viewer plan item 3) ----------------------------------------

# The live grid flag of `token`'s window: 1 = the dashed grid lines are drawn.
# A layout that predates item 3 has no `grid` key, so an ABSENT key reads as
# the rc default rather than as 0 -- a restored saved state must not come back
# with its grid mysteriously off.
proc wviewer::grid_shown {token} {
  if {$token eq {}} { return 1 }
  set lay [wviewer::layout_for $token]
  if {![dict exists $lay grid]} { return [wviewer::default_grid_show] }
  return [expr {[dict get $lay grid] ? 1 : 0}]
}

# Toggle (or set) the grid of a viewer window. `want` {} = invert, else 0/1.
# Returns the NEW state, or {} plus a CIW error when no viewer resolves.
#
# Lighter than move_strip's contract on purpose, and the difference is
# principled: this changes a WINDOW OPTION, not the model's content. Window
# options (plot mode, sharedx, cursors, the loaded raw) are deliberately
# OUTSIDE the undo snapshot -- see the undo/redo header -- so there is no
# push_undo here, exactly as sharedx_toggle and set_plot_mode do it.
#
# ⚠ CORRECTED 2026-08-01 (issue 0194). This paragraph used to end "...so there
# is no push_undo AND NO CAPTURE here", and that second half was the bug: the
# user reported that Ctrl-G deselected the selected trace. The two are separate
# questions. push_undo is about the undo STACK, which a window option stays out
# of. capture_live_graph_state is about surviving `clear_drawing`: this command
# regenerates, regenerate re-places every rect from the MODEL, and the selection
# lives in the RECT until something folds it back. So it captures -- in the
# skip_ranges form, which folds the selection and leaves every axis alone -- and
# still takes no undo point. (set_plot_mode needs neither: it does not
# regenerate at all.) What it does share with move_strip:
# refuse-a-no-op-without-logging, verified switch_ctx, ONE regenerate, ONE log
# line.
proc wviewer::grid_toggle {{want {}} {token {}}} {
  variable windows
  variable layouts
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to toggle the grid in" error
    }
    return {}
  }
  set cur [wviewer::grid_shown $token]
  if {$want eq {}} {
    set new [expr {$cur ? 0 : 1}]
  } elseif {[string is boolean -strict $want]} {
    set new [expr {[string is true -strict $want] ? 1 : 0}]
  } else {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: bad grid state '$want' (expected 0/1 or {})" error
    }
    return {}
  }
  # no-op discipline: set_plot_mode's change-only rule (this is a window
  # option, not a destructive gesture like clear_all, so a redundant call is
  # not worth a replay line).
  if {$new == $cur} { return $cur }
  if {![wviewer::switch_ctx $token]} { return {} }
  # issue 0194: BEFORE the `lay` read below — capture writes through set_graphs,
  # so reading the layout first and writing it back after would revert the fold.
  wviewer::capture_live_view_state $token
  set lay [wviewer::layout_for $token]
  dict set lay grid $new
  dict set layouts $token $lay
  wviewer::sync_grid_mirror $token
  wviewer::regenerate $token
  wviewer::log_action [list wviewer::grid_toggle $new $token]
  return $new
}

# Keep the Graph-menu checkbutton's variable in step with the model, so the
# menu is right however the state last changed (key, command, state restore) --
# the plot_mode_menu_post problem, solved by pushing instead of polling.
proc wviewer::sync_grid_mirror {token} {
  variable gridshow
  set gridshow($token) [wviewer::grid_shown $token]
}

# Graph > Grid checkbutton -command. Tk has ALREADY written the new value into
# the mirror variable by the time this runs, so it must SET that value -- a
# plain toggle here would invert twice and the menu would appear dead.
proc wviewer::grid_toggle_from_menu {token} {
  variable gridshow
  set want [expr {[info exists gridshow($token)] && $gridshow($token) ? 1 : 0}]
  set r [wviewer::grid_toggle $want $token]
  # a refused toggle (busy context) must not leave the checkbutton lying
  if {$r eq {}} { wviewer::sync_grid_mirror $token }
  return $r
}

# The Ctrl-G binding body — the clear_all_at pattern (resolve the window the
# KEY went to, never the current xschem ctx).
proc wviewer::grid_toggle_at {W} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  return [wviewer::grid_toggle {} $token]
}

# The Ctrl-D binding body (issue 0171). Resolves the token from the EVENT's
# canvas (%W), not from the current xschem context: a key can arrive on a
# viewer Tk has focused before the C side switched context to it, and clearing
# "whatever context is current" would then wipe the wrong window. Silent (no
# CIW error) on a foreign canvas — the tag only ever sits on viewer canvases,
# but a stale registry entry must not turn a keystroke into an error message.
proc wviewer::clear_all_at {W} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  return [wviewer::clear_all $token]
}

# Delete every waveform marker in a viewer window (viewer plan item 4,
# doc/claude/specs/graph_markers.md). Returns the NUMBER deleted, 0 when there
# was nothing to delete, or {} plus a CIW error when no viewer resolves.
#
# Everything except the log line comes for free from the C verb:
#   * the MODEL is rewritten by the push hook (graph_marker_notify ->
#     graph_marker_changed -> wviewer::marker_changed), which takes its
#     `dict remove $G markers` branch on every emptied strip — so this proc
#     must NOT write the model itself;
#   * the UNDO POINT is pushed by that same hook, exactly once for the whole
#     sweep (the C side notifies once, not per strip) — so this proc must NOT
#     call push_undo/capture_live_graph_state either, or `u` would need two
#     presses to undo one gesture.
# It does have to REPAINT: graph_marker_delete_all() only rewrites the props
# and notifies (the C key path in callback.c:6720 does its own draw()), and the
# hook's set_graphs is a pure model write. No regenerate — the rects are already
# right, and a regenerate would throw away a live pan/zoom.
#
# THE LOG. The core self-logs `xschem graph_marker delete -all -1`, and that
# line is not replayable into a viewer: scheduler.c readonly-rejects the arm and
# returns TCL_ERROR, which ABORTS a sourced action log rather than warning. So
# the C line is suppressed and ONE `wviewer::delete_all_markers <token>` is
# emitted instead — the clear_all/set_plot_mode pattern. The `pop` is
# UNCONDITIONAL: with_edit THROWS on a refused context switch, and a leaked
# push would leave the global depth counter raised and silently kill the action
# log for the rest of the session.
proc wviewer::delete_all_markers {{token {}}} {
  variable windows
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to delete markers in" error
    }
    return {}
  }
  set cnt 0
  xschem log_action -suppress push
  # with_edit's own result is always 1 ("the bracket ran"), so the count has to
  # come back through a variable in THIS scope (the MR1v idiom).
  set code [catch {
    wviewer::with_edit $token {set cnt [xschem graph_marker delete -all]}
  } err]
  xschem log_action -suppress pop
  if {$code} { return -code error $err }
  if {![string is integer -strict $cnt]} { set cnt 0 }
  # no-op discipline (the move_strip `from == to` rule): nothing was deleted, so
  # nothing changed — no repaint, and NO log line for a replay to re-run.
  if {$cnt <= 0} { return 0 }
  # PROBE-MEASURED (`-d 1`, which makes draw() log itself): 0 draw() calls
  # across the whole delete without this line, 1 with it. graph_marker_delete_all
  # only rewrites the props + notifies (the C key path in callback.c:6720 calls
  # draw() itself), and the hook's set_graphs is a pure model write — so without
  # this the deleted markers stay painted until something else redraws.
  wviewer::in_ctx $token {xschem redraw}
  wviewer::log_action [list wviewer::delete_all_markers $token]
  return $cnt
}

# The Ctrl-E binding body — the clear_all_at pattern (resolve the window the KEY
# went to, never the current xschem ctx). CAUGHT, unlike clear_all_at: this one
# can propagate a with_edit "context busy" error, and an error escaping a Tk
# binding pops a bgerror dialog over a read-only viewer. Reported the same way
# key_filter reports a refused marker key.
proc wviewer::delete_all_markers_at {W} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  if {[catch {wviewer::delete_all_markers $token} res]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      catch {ciw_echo "wviewer: delete all markers refused: $res" error}
    }
    return {}
  }
  return $res
}

# --- Delete Empty Strips (viewer plan item 5) --------------------------------

# Delete every EMPTY strip in a viewer window. Returns the NUMBER deleted, 0
# when there was nothing to delete, or {} plus a CIW error when no viewer
# resolves.
#
# "Empty" = holds no traces, is not the tool-owned auto-plot strip (decision
# D-D) and is not the last strip standing (decision D-C). Both exceptions live
# in the PURE `empty_strips_to_delete`, where they are assertable headless.
#
# A strip is just a dict in the layout's `graphs` list, so this is a LIST REMOVE
# plus a regenerate — never a schematic delete of the rect. regenerate re-places
# every rect from the model, and the surplus rects go with it.
#
# ORDERING — move_strip's contract verbatim (read its header for the why):
#   validate -> refuse a no-op WITHOUT mutating and WITHOUT logging -> verified
#   switch_ctx -> capture the live C-written state -> push_undo -> mutate ->
#   remap the stored target IN PLACE -> exactly ONE regenerate -> exactly ONE
#   log line.
# Snapshot-after-mutate is the shipped bug class this order exists to prevent:
# it makes `u` restore the very thing it was meant to undo. The target is
# remapped in place rather than through set_target_strip because that would
# emit a SECOND replay-log line for an index change that is an internal
# consequence of this one command.
#
# MARKERS (doc/claude/specs/graph_markers.md §9): a traceless strip should hold
# no markers, but the model is not its only writer, so this does not trust that
# — it reuses delete_ok's bookkeeping. The marker numbers on the doomed strips
# are collected and swept out of the SURVIVORS' `prev` links, because a delta
# block whose partner number is gone degrades to a plain callout with no
# indication at all.
#
# No `with_edit`: unlike delete_all_markers this calls no C mutation verb that
# the read-only viewer would refuse — it is a Tcl model edit plus a regenerate,
# exactly like move_strip, which is also bare.
proc wviewer::delete_empty_strips {{token {}}} {
  variable windows
  variable target
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to delete empty strips in" error
    }
    return {}
  }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set kill [wviewer::empty_strips_to_delete $gs [wviewer::auto_graph_index $token]]
  # No-op discipline, move_strip's `from == to` rule: nothing to delete means no
  # mutation, no undo point, no repaint and NO log line for a replay to re-run.
  # This is also the D-C answer for a window holding one empty strip.
  if {![llength $kill]} { return 0 }
  if {![wviewer::switch_ctx $token]} { return {} }
  # capture only rewrites per-graph VALUES (ranges, bold, markers) and carries a
  # 1:1 rect/model guard — it never adds or removes a graph, so the indices in
  # `kill` survive it. Re-read the list anyway, as move_strip does, so the
  # dictionaries below are the captured ones.
  wviewer::capture_live_graph_state $token
  wviewer::push_undo $token           ;# AFTER the capture: `u` restores the view
  set gs [dict get [wviewer::layout_for $token] graphs]
  set gone {}
  foreach gi $kill {
    foreach n [wviewer::markers_numbers [wviewer::dget [lindex $gs $gi] markers {}]] {
      lappend gone $n
    }
  }
  # the target is read BEFORE the mutation — split_strip's rule, and it matters
  # for the same reason it matters in delete_items: `target_index` clamps its
  # answer against the LIVE strip count, so reading it after `set_graphs` shrinks
  # a target sitting at or past the new end TWICE (once by the clamp, once by
  # `index_after_removal`) and the target lands one strip too low. This proc had
  # the read on the wrong side of the mutation until issue 0176 found the same
  # mistake in its own new code — see that issue's "second incidental repair".
  set tgt {}
  if {[info exists target($token)]} {
    set tgt [wviewer::index_after_removal [wviewer::target_index $token] $kill]
  }
  # §8: entries on a doomed strip are DROPPED and the rest shift down, through
  # the same PURE index_after_removal the target above just went through.
  wviewer::wavehl_remap_apply $token \
    [wviewer::wavehl_after_strip_removal [wviewer::wave_hilights $token] $kill]
  wviewer::set_graphs $token \
    [wviewer::markers_sweep_numbers [wviewer::remove_graphs $gs $kill] $gone]
  if {$tgt ne {}} { set target($token) $tgt }
  wviewer::regenerate $token
  # A selected marker that lived on a doomed strip now points at nothing —
  # clear_all's reset, narrowed to the only case that can actually dangle.
  # regenerate left the viewer as the current context.
  if {[llength $gone]} { catch {xschem graph_marker select -none} }
  wviewer::log_action [list wviewer::delete_empty_strips $token]
  return [llength $kill]
}

# The bare-`e` binding body — the clear_all_at pattern: resolve the token from
# the EVENT's canvas (%W), never from the current xschem context, because a key
# can arrive on a viewer Tk has focused before the C side switched context to
# it, and deleting strips in "whatever context is current" would then edit the
# wrong window. Silent on a foreign canvas.
proc wviewer::delete_empty_strips_at {W} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  return [wviewer::delete_empty_strips $token]
}

# --- deleting traces, strips and markers (issue 0176) ------------------------
# doc/claude/issues/0176-del-deletes-selection.md.
#
# Until 0176 the ONLY code in this tree that deleted an individual trace was
# `delete_ok`, welded to the Delete dialog's listbox — and it carried NO
# push_undo, NO log_action and no target remap, so a dialog delete was neither
# undoable nor replayable. The DEL key needs exactly that machinery, and writing
# a second deleter is how the two drift apart, so the body was lifted out whole:
# `delete_in_graphs` is the pure list + marker + selection math, `delete_items`
# is the ONE authoritative mutation, and both the dialog and the key go through
# it. The dialog is repaired as a consequence — see the issue file.

# PURE: the graph list after removing the WHOLE graphs whose indices are in
# `delg` and, per surviving graph, the MODEL trace indices in `delt` (a dict
# gi -> {ti ...}). Returns `{newgraphs gone}`, where `gone` lists the marker
# NUMBERS that disappeared: the caller must sweep those window-wide with
# `markers_sweep_numbers`, because a delta block's `prev` partner may live in a
# strip this proc left alone and this proc only ever sees one graph at a time.
#
# Every index is read in the PRE-deletion space: the walk keeps its own `gi`
# counter over the ORIGINAL list, and the per-graph trace removal is
# highest-index-first, so no caller has to compensate for its own deletions
# (issue 0176 D6 — the property that makes the logged pairs replayable).
#
# A trace delete has THREE index consequences and all three are here:
#   1. a marker ON a doomed trace is DROPPED — unlike a move, nothing is left
#      for it to annotate (`remap_markers_after_trace_delete`);
#   2. every marker and every SELECTED node in the same graph that sat above a
#      doomed node shifts DOWN by the number of doomed nodes strictly below it —
#      a stale index annotates/bolds the WRONG trace, which is worse than losing
#      the marker or the selection;
#   3. the dropped marker NUMBERS have to be swept window-wide (the caller).
proc wviewer::delete_in_graphs {gs delg delt} {
  set out {}
  set gone {}
  set gi 0
  foreach G $gs {
    if {[lsearch -exact $delg $gi] >= 0} {
      foreach n [wviewer::markers_numbers [wviewer::dget $G markers {}]] {
        lappend gone $n
      }
      incr gi
      continue
    }
    if {[dict exists $delt $gi]} {
      set trs [dict get $G traces]
      # NODE indices of the doomed traces, measured on the graph as it stands —
      # they are what markers and the selection are stored in, and they must be
      # taken BEFORE any trace leaves the list (landmine 34: a vec-less trace
      # occupies a model slot and no node slot, so the two spaces differ)
      set doomed {}
      foreach ti [dict get $delt $gi] {
        set ni [wviewer::node_index_of_trace $G $ti]
        if {$ni >= 0} { lappend doomed $ni }
      }
      foreach ti [lsort -integer -decreasing [dict get $delt $gi]] {
        set trs [lreplace $trs $ti $ti]
      }
      set G [dict replace $G traces $trs]
      if {[llength $doomed]} {
        set mk [wviewer::dget $G markers {}]
        if {$mk ne {}} {
          set nmk [wviewer::remap_markers_after_trace_delete $mk $doomed]
          set kept [wviewer::markers_numbers $nmk]
          foreach n [wviewer::markers_numbers $mk] {
            if {[lsearch -exact $kept $n] < 0} { lappend gone $n }
          }
          if {$nmk eq {}} {
            set G [dict remove $G markers]
          } else {
            set G [dict replace $G markers $nmk]
          }
        }
        # the SELECTION is a SET since issue 0175, so the remap runs per element
        # and a selected trace that was deleted simply leaves the set
        set sel [wviewer::model_sel $G]
        if {[llength $sel]} {
          set G [wviewer::model_sel_set $G \
                   [wviewer::remap_sel_after_trace_delete $sel $doomed]]
        }
      }
    }
    lappend out $G
    incr gi
  }
  return [list $out $gone]
}

# THE authoritative delete — the Delete dialog's OK button and the DEL key are
# its only callers. Returns the NUMBER of things removed (strips + traces +
# markers), 0 for a no-op, or {} plus a CIW message when it refuses.
#
#   graphs   strip indices to remove WHOLE   (the dialog's; DEL always passes {})
#   pairs    {gi ti} MODEL index pairs       (the traces)
#   markers  marker NUMBERS to remove too    (DEL's marker arm; {} otherwise)
#   token    the viewer window, {} = the active one
#
# ORDERING — move_strip's contract verbatim (read its header for the why):
#   validate LOUDLY -> refuse a no-op WITHOUT mutating and WITHOUT logging ->
#   verified switch_ctx -> capture the live C-written state -> push_undo ->
#   mutate -> remap the stored target IN PLACE -> exactly ONE regenerate ->
#   exactly ONE log line.
# Snapshot-after-mutate is the shipped bug class that order exists to prevent:
# it makes `u` restore the very thing it was meant to undo. The capture is what
# puts the live markers and the mouse-written pan/zoom INSIDE the restore point,
# so one `u` brings the traces and their markers back together.
#
# ONE undo point and ONE log line per GESTURE, not per trace (D5): three
# selected traces are one `u` and one replayable line.
#
# WHY THE MARKER HALF IS A MODEL EDIT AND NOT THE C `graph_marker delete` VERB.
# Every other Tcl deletion path in this file (delete_ok, clear_graph_traces,
# delete_empty_strips) already rewrites the token directly, and
# `markers_drop_number` reproduces both of `graph_marker_delete`'s effects
# exactly: the record goes, and every surviving `prev` that pointed at it is
# zeroed (a dangling `prev` degrades a delta block to a plain callout with NO
# indication at all). Routing through the verb instead would cost four things
# and buy none: it is readonly-rejected so it would need `with_edit`; it
# self-logs `xschem graph_marker delete N`, which is readonly-rejected AGAIN on
# replay and aborts the whole `source` (exactly why delete_all_markers brackets
# it in `log_action -suppress`); it pushes a C undo point onto a read-only
# scratch buffer; and it reaches the Tcl model ONLY through the `has_x`-gated
# notify hook (landmine 41), so under --nogui the rect would lose the marker,
# the model would not, and the `set_graphs` + `regenerate` below would put it
# straight back. Behaviour is unchanged, the mechanism is the shipped one.
#
# No `with_edit` for the same reason as delete_empty_strips: nothing here calls
# a C mutation verb that the read-only viewer buffer would refuse.
proc wviewer::delete_items {graphs pairs {markers {}} {token {}}} {
  variable windows
  variable target
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to delete in" error
    }
    return {}
  }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set n [llength $gs]
  # Validate LOUDLY, the move_trace rule: a bad index is a caller bug, and
  # silently dropping one would delete a DIFFERENT trace on a replay.
  set delg {}
  foreach gi $graphs {
    if {![string is integer -strict $gi] || $gi < 0 || $gi >= $n} {
      if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
        ciw_echo "wviewer: bad strip index '$gi' (0..[expr {$n - 1}])" error
      }
      return {}
    }
    if {[lsearch -exact $delg $gi] < 0} { lappend delg $gi }
  }
  set delt [dict create]
  set ntr 0
  foreach p $pairs {
    if {[llength $p] != 2} {
      if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
        ciw_echo "wviewer: bad trace pair '$p' (expected {gi ti})" error
      }
      return {}
    }
    lassign $p gi ti
    if {![string is integer -strict $gi] || $gi < 0 || $gi >= $n} {
      if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
        ciw_echo "wviewer: bad strip index '$gi' (0..[expr {$n - 1}])" error
      }
      return {}
    }
    set cnt [llength [wviewer::dget [lindex $gs $gi] traces {}]]
    if {![string is integer -strict $ti] || $ti < 0 || $ti >= $cnt} {
      if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
        ciw_echo "wviewer: bad trace index '$ti' on strip $gi (0..[expr {$cnt - 1}])" error
      }
      return {}
    }
    # a trace inside a strip that is going WHOLE is already covered, and a
    # duplicate pair would lreplace twice and take an innocent neighbour with it
    if {[lsearch -exact $delg $gi] >= 0} { continue }
    if {[dict exists $delt $gi] && [lsearch -exact [dict get $delt $gi] $ti] >= 0} { continue }
    dict lappend delt $gi $ti
    incr ntr
  }
  # Marker numbers are kept only when they exist RIGHT NOW, so a stale number
  # can neither inflate the count nor put a phantom line in the replay log. The
  # model is the reference because the C push hook keeps it current at all times
  # (that is what marker_changed is for); a number the hook never delivered is
  # left alone rather than guessed at.
  set live {}
  foreach G $gs {
    foreach nm [wviewer::markers_numbers [wviewer::dget $G markers {}]] { lappend live $nm }
  }
  set delm {}
  foreach nm $markers {
    if {![string is integer -strict $nm]} { continue }
    if {[lsearch -exact $live $nm] < 0} { continue }
    if {[lsearch -exact $delm $nm] < 0} { lappend delm $nm }
  }
  # the pairs as they will actually be applied — normalised, deduped, with the
  # strip-swallowed ones dropped. This, not the caller's raw list, is what gets
  # logged, so replaying the line reproduces this run exactly.
  set dpairs {}
  foreach gi [lsort -integer [dict keys $delt]] {
    foreach ti [lsort -integer [dict get $delt $gi]] { lappend dpairs [list $gi $ti] }
  }
  set nitems [expr {[llength $delg] + $ntr + [llength $delm]}]
  # No-op discipline, move_strip's `from == to` rule: nothing to delete means no
  # mutation, no undo point, no repaint and NO log line for a replay to re-run.
  if {$nitems == 0} { return 0 }
  if {![wviewer::switch_ctx $token]} { return {} }
  # capture only rewrites per-graph VALUES (ranges, the selection, markers) and
  # carries a 1:1 rect/model guard — it never adds or removes a graph or a
  # trace, so every index validated above survives it. Re-read the list anyway,
  # as move_strip and delete_empty_strips do, so the dictionaries below are the
  # captured ones.
  wviewer::capture_live_graph_state $token
  wviewer::push_undo $token           ;# AFTER the capture: `u` restores the view
  set gs [dict get [wviewer::layout_for $token] graphs]
  # THE TARGET IS READ BEFORE THE MUTATION — `split_strip`'s rule, and this is
  # the one place move_strip's contract must NOT be copied literally. move_strip
  # remaps after mutating, which is safe there because a reorder never changes
  # the graph COUNT; a delete does, and `target_index` clamps its answer against
  # the LIVE count. Read after `set_graphs` and a target sitting at or past the
  # new end is shrunk twice — once by the clamp, once by `index_after_removal` —
  # so deleting strip 0 of a 3-strip stack targeted at strip 2 lands the target
  # on 0 instead of 1, and the active bar plus the next single-plot signal go to
  # the wrong strip. The remap is expressed in the PRE-deletion index space,
  # which is what `delg` speaks.
  set tgt {}
  if {[llength $delg] && [info exists target($token)]} {
    set tgt [wviewer::index_after_removal [wviewer::target_index $token] $delg]
  }
  # §8: the highlight set, in the SAME pre-deletion index space `delg`/`delt`
  # speak. The TRACE half runs first, per source strip and in NODE indices
  # measured before any trace leaves (landmine 34, exactly as delete_in_graphs
  # measures its own `doomed`); the STRIP half then drops whole strips and shifts
  # the rest, through the same PURE index_after_removal the target used.
  set hlset [wviewer::wave_hilights $token]
  foreach dgi [lsort -integer [dict keys $delt]] {
    set doomed {}
    foreach ti [dict get $delt $dgi] {
      set ni [wviewer::node_index_of_trace [lindex $gs $dgi] $ti]
      if {$ni >= 0} { lappend doomed $ni }
    }
    if {[llength $doomed]} {
      set hlset [wviewer::wavehl_after_trace_delete $hlset $dgi $doomed]
    }
  }
  if {[llength $delg]} {
    set hlset [wviewer::wavehl_after_strip_removal $hlset $delg]
  }
  wviewer::wavehl_remap_apply $token $hlset
  lassign [wviewer::delete_in_graphs $gs $delg $delt] out gone
  foreach nm $delm { lappend gone $nm }
  # ONE sweep does both jobs: markers_drop_number REMOVES the record whose
  # number is in `gone` (that is the marker arm) and zeroes every surviving
  # `prev` that pointed at one (that is the window-wide dangling-link sweep the
  # per-graph remap above cannot do).
  wviewer::set_graphs $token [wviewer::markers_sweep_numbers $out $gone]
  # the stored TARGET is written in place, never through set_target_strip: that
  # would emit a SECOND replay line for an index change that is an internal
  # consequence of this one command. delete_ok never remapped at all — a strip
  # deleted below the target left the target pointing one strip too high.
  if {$tgt ne {}} { set target($token) $tgt }
  wviewer::regenerate $token
  # A selected marker that just died points at nothing — clear_all's reset,
  # narrowed to the only case that can dangle. regenerate left the viewer as the
  # current context.
  if {[llength $gone]} { catch {xschem graph_marker select -none} }
  wviewer::log_action [list wviewer::delete_items $delg $dpairs $delm $token]
  return $nitems
}

# The graph rect whose `markers` token carries number `num`, or -1 — the Tcl
# mirror of C's `graph_marker_find`, and read off the RECTS rather than the
# model for the same reason C re-resolves it: it is the live truth. Used only to
# reproduce the Delete key's strip-scope test. Fails CLOSED (-1 = "nowhere"), so
# an errored query reads as "no marker to delete here".
proc wviewer::marker_graph_at {wp num} {
  if {![string is integer -strict $num] || $num < 1} { return -1 }
  if {[catch {xschem new_schematic switch $wp}]} { return -1 }
  set n -1
  catch {set n [xschem get graph_rects]}
  if {![string is integer -strict $n]} { return -1 }
  for {set gi 0} {$gi < $n} {incr gi} {
    set mk {}
    catch {set mk [xschem getprop rect 2 $gi markers]}
    if {[lsearch -exact [wviewer::markers_numbers $mk] $num] >= 0} { return $gi }
  }
  return -1
}

# The DEL-key body (issue 0176): delete WHATEVER is selected on viewer canvas
# `W` — the selected marker, the selected traces, or BOTH — as ONE gesture, one
# undo point and one log line. `px`/`py` are the KeyPress pointer position and
# are needed only to reproduce the C Delete arm's strip-scope test on the marker.
#
# Returns the number of things deleted, 0 when nothing was selected, or {} on a
# foreign canvas / a refused context. The 0 case is load-bearing: key_filter
# must NOT forward a Delete that deletes nothing, because C's `case XK_Delete`
# falls through to the canvas delete verb — `readonly_block()` and a modal
# dialog over a read-only viewer (D2).
#
# The token is resolved from the EVENT's canvas (%W), never from the current
# xschem context — the clear_all_at pattern: a key can arrive on a viewer Tk has
# focused before the C side switched context to it.
proc wviewer::delete_selection_at {W px py} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  # THE TRACES: the live selection, read off the rects the way every other
  # selection consumer does (it is view state the C engine owns), mapped from
  # NODE index to MODEL trace index — landmine 34, they are different spaces.
  # That fold is `selection_pairs`, shared with the multi-trace drag arm since
  # issue 0192: two copies of it would drift, and the drift would be invisible to
  # any test that drives only one of the two gestures (D-53).
  set pairs [wviewer::selection_pairs $W]
  # THE MARKER: C's own gate, reproduced rather than loosened — a marker is
  # selected AND the pointer is over the strip that OWNS it (callback.c
  # `case XK_Delete`: `graph_marker_find(sel, &sgi, NULL) && sgi == graph_master`,
  # where waves_selected has just set graph_master from the pointer). Both
  # queries fail CLOSED, so an untrustworthy answer reads as "nothing to delete".
  # The gate stays on the HEAD (0189 D-9): when the head is in scope the WHOLE
  # set goes, partners on other strips included — delete_items already dedupes,
  # filters to live numbers and gives ONE undo point and ONE log line.
  set marks {}
  set msel [wviewer::marker_selected $W]
  if {$msel >= 0} {
    set mg [wviewer::marker_graph_at $W $msel]
    if {$mg >= 0 && $mg == [wviewer::strip_at_pixel $W $px $py]} {
      set marks [wviewer::marker_selection $W]
      if {![llength $marks]} { set marks [list $msel] }
    }
  }
  # D2: nothing selected -> nothing happens, and in particular nothing reaches C
  if {![llength $pairs] && ![llength $marks]} { return 0 }
  # D4: whole-strip delete is not DEL's job — `graphs` is always empty here.
  return [wviewer::delete_items {} $pairs $marks $token]
}

# ============================================================================
# NET-HIGHLIGHT STYLES ON WAVEFORM TRACES
# doc/claude/specs/wave_trace_hilight.md
#
# A trace is a polyline with no junctions and no direction, so the whole
# net-highlight vocabulary — colour, width, dash pattern, blink, marching ants —
# applies to it unchanged, from the SAME `net_hilight_style` table and the SAME
# current-style cursor the schematic `9` uses (D1). The highlight is an OVERLAY
# stroked on top of the trace (D2), so the palette colour still identifies the
# curve in the legend.
#
# THE SET IS SESSION-ONLY VIEW STATE (D4): `wavehl($token)`, a list of
# {gi ni style} in NODE index space. Not a prop token, not in `layouts`, not in
# `snapshot`, not an undo point. It is pushed into the C engine
# (xctx->wave_hilight_*) and re-pushed by `regenerate`, which is what keeps it
# alive across the `xschem clear_drawing` a plain window RESIZE performs
# (landmine 50).
#
# `9`/`8` act on the SELECTION (D5), never on a pick: the viewer already has a
# first-class trace selection (§7 of the guide), so there is no pick mode and no
# modal — with nothing selected they refuse with one ciw_echo line and change
# nothing.
# ============================================================================

# Drop this window's whole set, in Tcl AND in C. The clear_history shape: called
# from open (a fresh window highlights nothing), from restore (the model was
# replaced wholesale) and from clear_all (every strip is gone). Never logs — its
# callers own their own replay line.
proc wviewer::wave_hilight_clear_set {token} {
  variable wavehl
  set wavehl($token) {}
  catch {wviewer::in_ctx $token {xschem wave_hilight -clear}}
  return 1
}

# The current set of `token`, as {gi ni style} sublists. The read a test drives
# and the read `regenerate` re-applies. Fails soft: an unknown token is {}.
proc wviewer::wave_hilights {{token {}}} {
  variable wavehl
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![info exists wavehl($token)]} { return {} }
  return $wavehl($token)
}

# PURE: normalise a caller's {gi ni style} list against a strip count — integers
# only, in range, style >= 0, de-duplicated on (gi, ni) with the LAST style
# winning, and capped at GRAPH_MAX_HILIGHT_WAVES. The C writer applies the same
# rules; doing it here too is what lets the LOG LINE carry the pairs that were
# actually applied rather than the caller's raw list, so a replay cannot
# re-derive a different set (the move_traces rule).
proc wviewer::wave_hilight_norm {set ngraphs} {
  set out {}
  foreach e $set {
    if {[llength $e] != 3} { continue }
    lassign $e gi ni st
    if {![string is integer -strict $gi] || $gi < 0} { continue }
    if {$ngraphs >= 0 && $gi >= $ngraphs} { continue }
    if {![string is integer -strict $ni] || $ni < 0} { continue }
    if {![string is integer -strict $st] || $st < 0} { continue }
    set hit -1
    for {set k 0} {$k < [llength $out]} {incr k} {
      lassign [lindex $out $k] ogi oni
      if {$ogi == $gi && $oni == $ni} { set hit $k; break }
    }
    if {$hit >= 0} { set out [lreplace $out $hit $hit [list $gi $ni $st]] } \
    else { lappend out [list $gi $ni $st] }
  }
  if {[llength $out] > [wviewer::wave_hilight_cap]} {
    set out [lrange $out 0 [expr {[wviewer::wave_hilight_cap] - 1}]]
  }
  return $out
}

# GRAPH_MAX_HILIGHT_WAVES, read out of src/xschem.h rather than frozen as a
# literal here — landmine 45(a): a constant copied to a second seam drifts
# silently, and the refusal message and the C cap must agree. Falls back to the
# shipped 16 if the header cannot be read (an installed tree without sources).
proc wviewer::wave_hilight_cap {} {
  variable wavehl_cap
  if {[info exists wavehl_cap]} { return $wavehl_cap }
  set wavehl_cap 16
  set h [file join $::XSCHEM_SHAREDIR xschem.h]
  if {[file isfile $h] && ![catch {open $h r} fh]} {
    set src [read $fh]
    close $fh
    if {[regexp {#define\s+GRAPH_MAX_HILIGHT_WAVES\s+(\d+)} $src -> v]} { set wavehl_cap $v }
  }
  return $wavehl_cap
}

# Push `wavehl($token)` into the C engine. THE re-apply half of D4: regenerate
# has just run `xschem clear_drawing`, which reset the C set, so without this a
# window RESIZE would silently drop every highlight. Silent, unlogged and
# non-mutating from the model's point of view; the caller owns the redraw.
proc wviewer::wave_hilight_push {token} {
  variable wavehl
  if {![info exists wavehl($token)]} { return 0 }
  set n 0
  catch {xschem wave_hilight -clear}
  foreach e $wavehl($token) {
    lassign $e gi ni st
    if {[catch {xschem wave_hilight $gi $ni $st} r]} { continue }
    # `string is integer` before the boolean test, not because the verb lies but
    # because a THROW here would abandon the rest of the set half-pushed and the
    # window would come back from a resize with only some of its highlights.
    # (Measured: it really happened, when net_hilight_anim_update's Tcl fan-out
    # was clobbering the verb's result under a DISPLAY.)
    if {[string is integer -strict $r] && $r} { incr n }
  }
  return $n
}

# THE ONE MUTATION, and the replay form every key routes through: set this
# window's highlight set to exactly `pairs` ({gi ni style} sublists).
#
# No `push_undo` and no `capture_live_graph_state` (D4): the set is neither in
# the model nor in the undo unit, and this command does not regenerate — it
# repaints with a single `xschem redraw`, the delete_all_markers shape. A
# no-op (the set is already exactly this) refuses WITHOUT logging, the
# move_strip `from == to` rule.
proc wviewer::set_wave_hilights {pairs {token {}}} {
  variable windows
  variable wavehl
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to highlight traces in" error
    }
    return {}
  }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set norm [wviewer::wave_hilight_norm $pairs [llength $gs]]
  set cur {}
  if {[info exists wavehl($token)]} { set cur $wavehl($token) }
  if {$norm eq $cur} { return [llength $norm] }
  if {![wviewer::switch_ctx $token]} { return {} }
  set wavehl($token) $norm
  wviewer::wave_hilight_push $token
  catch {xschem redraw}
  wviewer::log_action [list wviewer::set_wave_hilights $norm $token]
  return [llength $norm]
}

# The SELECTION of every strip, as {gi ni} pairs in NODE space. selection_pairs'
# sibling: that one crosses into MODEL space for the delete/drag commands, this
# one does not, because everything about a highlight — the C set, `hilight_wave`,
# `graph_trace_at` — speaks NODE (landmine 34).
proc wviewer::selected_node_pairs {token} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  set wp [dict get $windows $token win_path]
  set out {}
  set gi 0
  foreach G [dict get [wviewer::layout_for $token] graphs] {
    foreach ni [wviewer::selected_waves $wp $gi] { lappend out [list $gi $ni] }
    incr gi
  }
  return $out
}

# Is NODE `ni` of model graph `G` something this feature can stroke? D8: analog
# polyline traces only in v1. A BUS entry (`a,b,c` in its vec) renders as a
# ribbon of rails and hex labels, and a DIGITAL strip renders as bands — neither
# is a polyline, and `graph_wave_at` already answers -1 across their whole body
# (landmine 33). Returns {} when it is fine, else the reason for the CIW line.
proc wviewer::wave_hilight_refusal {G ni} {
  if {[wviewer::dget $G digital 0]} { return "a digital strip" }
  set ti [wviewer::trace_index_of_node $G $ni]
  if {$ti < 0} { return {} }
  set tr [lindex [wviewer::dget $G traces {}] $ti]
  if {[string first , [wviewer::dget $tr vec {}]] >= 0} { return "a bus trace" }
  return {}
}

# `9` — apply a style to the SELECTED traces of every strip.
#
# `style` defaults to the CURRENT STYLE CURSOR, the same one the schematic `9`
# uses and the same one Alt+- / the style editor move (D1). After applying, the
# cursor advances ONCE — not once per trace: a multi-trace selection is one user
# act, and rainbowing it would be a surprise, while never advancing would make
# two successive highlights indistinguishable (which is the thing the schematic
# `9` deliberately avoids).
proc wviewer::hilight_traces {{style {}} {token {}}} {
  variable windows
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to highlight traces in" error
    }
    return {}
  }
  if {![wviewer::switch_ctx $token]} { return {} }
  set sel [wviewer::selected_node_pairs $token]
  if {![llength $sel]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: select a trace first (click it, or its legend name)" error
    }
    return 0
  }
  set advance 0
  if {$style eq {}} {
    set style 0
    catch {set style [xschem get hilight_color]}
    if {![string is integer -strict $style] || $style < 0} { set style 0 }
    set advance 1
  }
  if {![string is integer -strict $style] || $style < 0} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: bad highlight style '$style'" error
    }
    return {}
  }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set add {}
  set refused {}
  foreach p $sel {
    lassign $p gi ni
    set why [wviewer::wave_hilight_refusal [lindex $gs $gi] $ni]
    if {$why ne {}} { lappend refused [list $gi $ni $why]; continue }
    lappend add [list $gi $ni $style]
  }
  # the analog members are still highlighted — a refusal is per trace, never
  # per gesture (§9 of the spec)
  foreach r $refused {
    lassign $r gi ni why
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      set nm [wviewer::trace_label \
                [lindex [wviewer::dget [lindex $gs $gi] traces {}] \
                        [wviewer::trace_index_of_node [lindex $gs $gi] $ni]]]
      if {$nm eq {}} { set nm "trace $ni" }
      ciw_echo "wviewer: $nm is $why — highlighting is analog-only" error
    }
  }
  if {![llength $add]} { return 0 }
  # the cap is on the WINDOW, so it is the merged set that has to fit
  set merged [wviewer::wave_hilight_merge [wviewer::wave_hilights $token] $add]
  if {[llength $merged] > [wviewer::wave_hilight_cap] &&
      [info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
    ciw_echo "wviewer: at most [wviewer::wave_hilight_cap] highlighted traces" error
  }
  set r [wviewer::set_wave_hilights $merged $token]
  if {$advance} { catch {xschem incr_hilight_color} }
  return $r
}

# PURE: `add` applied over `base`, LAST style winning per (gi, ni). Kept apart
# from wave_hilight_norm so the cap refusal can see the pre-cap length.
proc wviewer::wave_hilight_merge {base add} {
  set out $base
  foreach e $add {
    lassign $e gi ni st
    set hit -1
    for {set k 0} {$k < [llength $out]} {incr k} {
      lassign [lindex $out $k] ogi oni
      if {$ogi == $gi && $oni == $ni} { set hit $k; break }
    }
    if {$hit >= 0} { set out [lreplace $out $hit $hit [list $gi $ni $st]] } \
    else { lappend out [list $gi $ni $st] }
  }
  return $out
}

# `8` — drop the highlight from the SELECTED traces. Same selection and the same
# refusal-with-no-selection as `9`; a selected trace that carries no highlight is
# simply not in the set to begin with, so it costs nothing.
proc wviewer::unhilight_traces {{token {}}} {
  variable windows
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to un-highlight traces in" error
    }
    return {}
  }
  if {![wviewer::switch_ctx $token]} { return {} }
  set sel [wviewer::selected_node_pairs $token]
  if {![llength $sel]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: select a trace first (click it, or its legend name)" error
    }
    return 0
  }
  set out {}
  foreach e [wviewer::wave_hilights $token] {
    lassign $e gi ni st
    set drop 0
    foreach p $sel { if {[lindex $p 0] == $gi && [lindex $p 1] == $ni} { set drop 1; break } }
    if {!$drop} { lappend out $e }
  }
  return [wviewer::set_wave_hilights $out $token]
}

# `0` — drop EVERY trace highlight in this window. Unlike `8` it needs no
# selection, and unlike wave_hilight_clear_set it goes through the one mutation,
# so it logs its replay line like any other user-visible change.
proc wviewer::unhilight_all {{token {}}} {
  variable windows
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to un-highlight traces in" error
    }
    return {}
  }
  return [wviewer::set_wave_hilights {} $token]
}

# The AD-HOC style form, exactly as it already works for nets:
#   wviewer::apply_style_traces_at %W {color purple thickness 3 pattern {20 20}}
# `aphl::parse` accepts all three shapes (named key=value, native dict,
# positional row); `net_hilight_apply`'s dedup-or-append installs it once and
# hands back a table INDEX — so an ad-hoc style is just an index like any other
# and nothing new is stored.
#
# ⚠ It calls `net_hilight_style_index_for`, the INSTALL-AND-RETURN-THE-INDEX half
# factored out of net_hilight_apply, NOT net_hilight_apply itself: that proc's
# no-trailing-args arm applies the style to the SCHEMATIC selection through
# `xschem set hilight_color`, which CLAMPS any index >= cadlayers to 4 — and an
# ad-hoc style always lands past cadlayers, because the default table already has
# one row per active layer.
proc wviewer::apply_style_traces {styledef {token {}}} {
  set token [wviewer::resolve_token $token]
  if {$token eq {}} { return {} }
  # utils/apply_hilight.tcl is sourced by an rc (cadence_style_rc does), not by
  # the core, so say which file is missing rather than leaking Tcl's
  # "invalid command name".
  if {[info commands ::aphl::parse] eq {}} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: ad-hoc styles need utils/apply_hilight.tcl sourced (see cadence_style_rc)" error
    }
    return {}
  }
  if {[catch {aphl::parse $styledef} row]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: cannot parse highlight style: $row" error
    }
    return {}
  }
  if {![wviewer::switch_ctx $token]} { return {} }
  if {[catch {net_hilight_style_index_for $row} idx]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: cannot install highlight style: $idx" error
    }
    return {}
  }
  # REPLAY FIDELITY. set_wave_hilights logs style INDICES, which is the right
  # shape for a table row that exists -- but an ad-hoc style is INSTALLED by this
  # call, so on a replay the index would name whatever row happened to sit there
  # and the trace would come back in a different style. Log the install first,
  # exactly as apply_hilight does for nets (`xschem log_action [list
  # net_hilight_apply $row]`): the two lines then replay in order and the index
  # resolves to the same row it did here. `_index_for` is idempotent -- an
  # identical row is reused, never appended twice.
  wviewer::log_action [list net_hilight_style_index_for $row]
  return [wviewer::hilight_traces $idx $token]
}

# --- the `_at` wrappers: resolve the token from the EVENT's canvas (%W), never
# from the current xschem ctx (the clear_all_at rule), and `catch` so no error
# can escape a Tk binding and pop bgerror over a read-only plot window.
proc wviewer::hilight_traces_at {W} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  if {[catch {wviewer::hilight_traces {} $token} e]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      catch {ciw_echo "wviewer: highlight refused: $e" error}
    }
    return {}
  }
  return $e
}

proc wviewer::unhilight_traces_at {W} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  if {[catch {wviewer::unhilight_traces $token} e]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      catch {ciw_echo "wviewer: un-highlight refused: $e" error}
    }
    return {}
  }
  return $e
}

proc wviewer::unhilight_all_at {W} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  if {[catch {wviewer::unhilight_all $token} e]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      catch {ciw_echo "wviewer: un-highlight refused: $e" error}
    }
    return {}
  }
  return $e
}

proc wviewer::apply_style_traces_at {W styledef} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  if {[catch {wviewer::apply_style_traces $styledef $token} e]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      catch {ciw_echo "wviewer: highlight refused: $e" error}
    }
    return {}
  }
  return $e
}

# --- INDEX REMAPS (§8) ------------------------------------------------------
# The set is keyed by (gi, ni) and BOTH spaces move under ordinary editing. Each
# adapter below delegates the arithmetic to the SHIPPED pure helper that already
# remaps the model selection for the same event — `reordered_index`,
# `index_after_removal`, `remap_hilight_after_trace_move`,
# `remap_node_after_trace_delete` — so the highlight set and the selection can
# never disagree about where a trace went. All PURE.

# A strip REORDER: only `gi` moves, by exactly the rule the target index moves.
proc wviewer::wavehl_after_strip_move {set from to} {
  set out {}
  foreach e $set {
    lassign $e gi ni st
    lappend out [list [wviewer::reordered_index $gi $from $to] $ni $st]
  }
  return $out
}

# Strips DELETED: entries on them are dropped, the rest shift down.
proc wviewer::wavehl_after_strip_removal {set removed} {
  set out {}
  foreach e $set {
    lassign $e gi ni st
    if {[lsearch -exact $removed $gi] >= 0} { continue }
    lappend out [list [wviewer::index_after_removal $gi $removed] $ni $st]
  }
  return $out
}

# A TRACE moved from strip `from_gi` (node `moved_ni`) to strip `to_gi`, where it
# lands at node `dst_ni`: the entry FOLLOWS its trace, and every entry above the
# hole in the SOURCE strip shifts down — the same two halves
# `remap_sel_after_trace_move` performs on the selection.
proc wviewer::wavehl_after_trace_move {set from_gi moved_ni to_gi dst_ni} {
  set out {}
  foreach e $set {
    lassign $e gi ni st
    if {$gi != $from_gi} { lappend out $e; continue }
    if {$ni == $moved_ni} { lappend out [list $to_gi $dst_ni $st]; continue }
    set n [wviewer::remap_hilight_after_trace_move $ni $moved_ni]
    if {$n eq {}} { continue }
    lappend out [list $gi $n $st]
  }
  return $out
}

# TRACES deleted from strip `gi` at node indices `doomed`: the entries on them
# go, every entry above a hole shifts down.
proc wviewer::wavehl_after_trace_delete {set gi doomed} {
  set out {}
  foreach e $set {
    lassign $e egi ni st
    if {$egi != $gi} { lappend out $e; continue }
    set n [wviewer::remap_node_after_trace_delete $ni $doomed]
    if {$n eq {}} { continue }
    lappend out [list $egi $n $st]
  }
  return $out
}

# A strip SPLIT into one strip per drawn trace. Entries follow their traces into
# the new strips: strip `gi`'s node k lands on strip `src + k` — alone, hence at
# node 0 — while every OTHER strip's index goes through the SHIPPED PURE
# `target_after_split`, which is the same removal-then-insertion the stored
# target strip goes through, so the two can never disagree about what moved
# where. `plan` is plan_split's own output, computed once by the caller.
proc wviewer::wavehl_after_split {set plan gi} {
  if {![dict exists $plan ok] || ![dict get $plan ok]} { return $set }
  set src [dict get $plan src]
  set out {}
  foreach e $set {
    lassign $e egi eni est
    if {$egi == $gi} {
      # node 0 stays on the (now single-trace) source strip, also at node 0
      lappend out [list [expr {$src + $eni}] 0 $est]
    } else {
      lappend out [list [wviewer::target_after_split $egi $plan] $eni $est]
    }
  }
  return $out
}

# A strip EMPTIED in place (clear_graph_traces, i.e. the ASE auto-plot rebuild
# on every simulation run). The strip stays, so no index shifts; every node
# index ON it is gone, so its entries go — the same rule that drops the strip's
# `hilight_wave` / `sel_waves` / `markers` keys in that proc.
proc wviewer::wavehl_after_strip_clear {set gi} {
  set out {}
  foreach e $set {
    if {[lindex $e 0] == $gi} { continue }
    lappend out $e
  }
  return $out
}

# Strips INSERTED at the FRONT (multi-plot prepends its fresh strips, so every
# existing index moves by the same amount — plot_signals shifts the stored target
# by exactly this and the highlight set owes the identical shift).
proc wviewer::wavehl_after_prepend {set count} {
  if {![string is integer -strict $count] || $count <= 0} { return $set }
  set out {}
  foreach e $set {
    lassign $e gi ni st
    lappend out [list [expr {$gi + $count}] $ni $st]
  }
  return $out
}

# Apply a remapped set to `token` WITHOUT a log line: the caller is a command
# that already logs its own (one gesture, one line — landmine 49(b)), and the
# remap is an internal consequence of it, not a second user action.
proc wviewer::wavehl_remap_apply {token new} {
  variable wavehl
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  if {![info exists wavehl($token)]} { return 0 }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set new [wviewer::wave_hilight_norm $new [llength $gs]]
  if {$new eq $wavehl($token)} { return 0 }
  set wavehl($token) $new
  return 1
}

# Install the viewer's default key bindings on the shared `WaveViewer` BINDTAG
# (issue 0171). Not on the canvas widget: strip_bindings sweeps every
# widget-level sequence on a viewer canvas (including anything
# clone_canvas_bindings copied from the main `.drw`), and a tag is the one
# binding table an rc file can reach before any viewer window exists. The tag
# is inserted right after the widget in bindtags, so key_filter keeps first
# refusal; key_filter never `break`s, so the tag binding still fires for keys
# it swallows.
#
# Remapping from an rc file (~/.xschem/xschemrc, cadence_style_rc, --script):
#   bind WaveViewer <Control-Key-d> {break}                      ;# drop default
#   bind WaveViewer <Control-Key-r> {wviewer::clear_all_at %W; break}
#   bind WaveViewer <Control-Key-e> {break}                      ;# item 4 too
#   bind WaveViewer <Key-e> {break}                              ;# item 5 too
# An rc that binds a sequence itself WINS: defaults are installed once, at the
# first viewer open, and only for a sequence nothing has bound yet. Disable
# with `{break}`, NOT `{}` — an empty script DELETES the binding, which reads
# exactly like "never bound" and would be re-defaulted here.
proc wviewer::install_default_binds {} {
  variable tagbinds
  if {$tagbinds} { return 0 }
  set tagbinds 1
  if {[bind WaveViewer <Control-Key-d>] eq {}} {
    bind WaveViewer <Control-Key-d> {wviewer::clear_all_at %W; break}
  }
  # Delete All Markers (viewer plan item 4). Ctrl-E is the schematic's
  # `go_back` in the legacy C switch (callback.c case 'e') and in
  # cadence_style_rc (`bind .drw <Control-Key-e> {cadence::return_one_level}`,
  # cloned onto every new canvas by clone_canvas_bindings) — but neither reaches
  # a viewer: strip_bindings sweeps the cloned widget-level bind, and key_filter
  # forwards nothing for keysym 101, so the C dispatcher never sees it either.
  # The `break` keeps it that way whatever the tags below this one carry.
  if {[bind WaveViewer <Control-Key-e>] eq {}} {
    bind WaveViewer <Control-Key-e> {wviewer::delete_all_markers_at %W; break}
  }
  # Delete Empty Strips (viewer plan item 5). Bare `e`, and the collision check
  # is clean on all three of the paths a key can reach this window by:
  #   * keysym 101 is NOT in `graphkeys` {97 98 100 115 109 116 65 66 77}, so
  #     key_filter forwards nothing and the C dispatcher never sees it — in the
  #     SCHEMATIC bare `e` is descend_schematic (callback.c case 'e',
  #     rstate == 0), which must not happen in a viewer;
  #   * no rc binds <Key-e> on .drw, so clone_canvas_bindings has nothing to
  #     copy onto a viewer canvas (unlike Ctrl-E above, which it does clone and
  #     strip_bindings has to sweep);
  #   * the `break` keeps it that way whatever the tags below this one carry.
  if {[bind WaveViewer <Key-e>] eq {}} {
    bind WaveViewer <Key-e> {wviewer::delete_empty_strips_at %W; break}
  }
  # Grid on/off (viewer plan item 3). COLLISION CHECK: Ctrl-G in the SCHEMATIC
  # toggles the global `draw_grid` (src/cadence_style_rc), but that is a
  # `bind .drw` -- a WaveViewer bindtag binding cannot reach it, the viewer
  # canvas does not carry .drw's bindings (strip_bindings sweeps the clones),
  # and the global draw_grid is irrelevant here anyway: the viewer sets
  # `no_grid 1` on its context for life, so the schematic dot grid was never
  # drawn in this window. The `break` keeps the key from travelling further.
  if {[bind WaveViewer <Control-Key-g>] eq {}} {
    bind WaveViewer <Control-Key-g> {wviewer::grid_toggle_at %W; break}
  }
  # undo / redo of viewer model edits (2026-07-28). `u` and Shift-u are inert in
  # this window otherwise: key_filter forwards only the waves_callback key set
  # (a b s m t A B), so nothing is being taken away from the C engine.
  if {[bind WaveViewer <Key-u>] eq {}} {
    bind WaveViewer <Key-u> {wviewer::undo_at %W; break}
  }
  if {[bind WaveViewer <Key-U>] eq {}} {
    bind WaveViewer <Key-U> {wviewer::redo_at %W; break}
  }
  # NET-HIGHLIGHT STYLES ON WAVEFORM TRACES
  # (doc/claude/specs/wave_trace_hilight.md §7.3): the schematic's own three
  # keys, on the selection instead of on a pick.
  #   9 apply the current style to the selected trace(s)
  #   8 remove it from them
  #   0 remove every trace highlight in this window
  # COLLISION CHECK, done and clean on all three paths a key can reach this
  # window by:
  #   * keysyms 57/56/48 are NOT in `graphkeys` {97 98 100 115 109 116 65 66 77},
  #     so key_filter forwards nothing and the C dispatcher never sees them --
  #     which matters, because bare `0` in the C dispatcher toggles pin logic
  #     level and would be nonsense here;
  #   * cadence_style_rc DOES `bind .drw <Key-9|8|0>` (the schematic net
  #     highlighting), and clone_canvas_bindings copies those onto every new
  #     canvas -- but strip_bindings sweeps every widget-level sequence off a
  #     viewer canvas, so the clones cannot reach this window;
  #   * the `break` keeps it that way whatever the tags below this one carry.
  if {[bind WaveViewer <Key-9>] eq {}} {
    bind WaveViewer <Key-9> {wviewer::hilight_traces_at %W; break}
  }
  if {[bind WaveViewer <Key-8>] eq {}} {
    bind WaveViewer <Key-8> {wviewer::unhilight_traces_at %W; break}
  }
  if {[bind WaveViewer <Key-0>] eq {}} {
    bind WaveViewer <Key-0> {wviewer::unhilight_all_at %W; break}
  }
  return 1
}

# Options > Plot Mode -postcommand: relabel the single entry with the mode it
# would switch TO, so the label is right however the mode last changed (menu,
# command, chord, state restore). The edit_menu_post pattern.
proc wviewer::plot_mode_menu_post {token m} {
  if {![winfo exists $m]} { return }
  set cur [wviewer::plot_mode $token]
  if {$cur eq {}} { set cur single }
  set lab [expr {$cur eq {multi} ? {Set Single-plot Mode} : {Set Multi-plot Mode}}]
  catch {$m entryconfigure 0 -label $lab}
}

# Graph > Shared X Axis checkbutton: mirror -> model + regenerate.
proc wviewer::sharedx_toggle {token} {
  variable windows
  variable layouts
  variable sharedx
  if {![dict exists $windows $token]} { return }
  # issue 0194, same as grid_toggle: a window option regenerates, so it owes the
  # fold, and it owes it BEFORE the `lay` read (capture writes through
  # set_graphs). capture_live_view_state does its own verified switch_ctx.
  wviewer::capture_live_view_state $token
  set lay [wviewer::layout_for $token]
  dict set lay sharedx \
    [expr {[info exists sharedx($token)] && $sharedx($token) ? 1 : 0}]
  dict set layouts $token $lay
  wviewer::regenerate $token
}

# --- cursors + readout (item 12, D1/D2/D8/D9) --------------------------------

# Cursors > Cursor A/B checkbutton command (`which` 1=A 2=B): drive the
# ENGINE x-cursors absolutely from the Tcl mirror. `xschem cursor` sets/
# clears graph_flags bit 2/4 and RESETS the position to 0.0 on enable, so
# re-park the cursor at the mid of graph-0's current x range; plain redraw
# draws them (draw() calls draw_graph_all with the cursor bits).
proc wviewer::cursor_toggle {token which} {
  variable windows
  variable cva; variable cvb
  if {![dict exists $windows $token]} { return }
  set wp [dict get $windows $token win_path]
  if {$which == 1} {
    set on [expr {[info exists cva($token)] && $cva($token) ? 1 : 0}]
  } else {
    set on [expr {[info exists cvb($token)] && $cvb($token) ? 1 : 0}]
  }
  xschem new_schematic switch $wp
  xschem cursor $which $on
  if {$on} {
    set mid 0
    catch {
      set gx1 [xschem getprop rect 2 0 x1]
      set gx2 [xschem getprop rect 2 0 x2]
      if {[string is double -strict $gx1] && [string is double -strict $gx2]} {
        set mid [expr {($gx1 + $gx2) / 2.0}]
      }
    }
    xschem set cursor${which}_x $mid
    wviewer::readout_auto_show $token
  }
  xschem redraw
  wviewer::readout_refresh $token
}

# key_filter tail (D8): the C waves_callback just toggled cursor A ('a'),
# cursor B ('b') or swapped them ('s') — flip the Tcl mirror and refresh
# the readout. Residual desync risk: a C-side access_cond refusal the
# mirror cannot see (graph_use_ctrl_key defaults 0 in the shipping
# profile, so the C toggle always runs there).
proc wviewer::key_cursor_tail {W N} {
  variable cva; variable cvb
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return }
  if {$N == 97} {
    set cva($token) [expr {[info exists cva($token)] && $cva($token) ? 0 : 1}]
    if {$cva($token)} { wviewer::readout_auto_show $token }
  } elseif {$N == 98} {
    set cvb($token) [expr {[info exists cvb($token)] && $cvb($token) ? 0 : 1}]
    if {$cvb($token)} { wviewer::readout_auto_show $token }
  }
  wviewer::readout_refresh $token
}

# Tcl mirror of the C interpolate_yval (callback.c) — ONE honest uniform
# interpolation path for BOTH cursors (the engine only interpolates for
# cursor B into cursor_b_val). Runs in the CURRENT ctx (callers switch to
# the viewer's), throws when no raw data is loaded (callers catch).
# sweepvar = first raw vector; pos from the engine's binary search
# (raw pos_at, floor side), clamped to the nearest end when x is outside
# the sweep range. v1 simplification (documented): dataset-0 semantics —
# pos_at searches dataset 0 and `raw value` indexes allpoints, identical
# for single-dataset raws.
proc wviewer::interp_value {var x} {
  set names [split [xschem raw list] "\n"]
  set sweep [lindex $names 0]
  set n [xschem raw points]
  set pos [xschem raw pos_at $sweep $x]
  if {$pos < 0} {
    set s0 [xschem raw value $sweep 0]
    set sl [xschem raw value $sweep [expr {$n - 1}]]
    if {abs($x - $s0) <= abs($x - $sl)} {
      return [xschem raw value $var 0]
    }
    return [xschem raw value $var [expr {$n - 1}]]
  }
  if {$pos >= $n - 1} { return [xschem raw value $var [expr {$n - 1}]] }
  set xa [xschem raw value $sweep $pos]
  set xb [xschem raw value $sweep [expr {$pos + 1}]]
  set ya [xschem raw value $var $pos]
  set yb [xschem raw value $var [expr {$pos + 1}]]
  if {$xb == $xa} { return $ya }
  return [expr {$ya + ($yb - $ya) * ($x - $xa) / ($xb - $xa)}]
}

# Enable + show the readout bar (cursor enable path: the bar appears
# automatically, D9).
proc wviewer::readout_auto_show {token} {
  variable cvr
  set cvr($token) 1
  wviewer::readout_show $token
}

# Cursors > Readout checkbutton: pack/unpack the bottom bar per the mirror.
# `-before $top.drw` slots the bar ahead of the expanding canvas in the
# packing order (a plain -side bottom after the canvas would get squeezed
# to zero height).
proc wviewer::readout_show {token} {
  variable windows
  variable cvr
  if {![dict exists $windows $token]} { return }
  set top [dict get $windows $token top]
  set bar $top.wvreadout
  if {[catch {winfo exists $bar} e] || !$e} { return }
  if {[info exists cvr($token)] && $cvr($token)} {
    if {[catch {pack info $bar}]} {
      pack $bar -side bottom -fill x -before $top.drw
    }
    wviewer::readout_refresh $token
  } else {
    catch {pack forget $bar}
  }
}

# Refresh the readout bar (test seam, D9): per enabled cursor one line
# `A: x=905m  v(g)=905m  ...` — the cursor x plus the interpolated y of
# every model trace (dedup by vec), eng-formatted via ase::format_value.
# MUST never throw: it is appended to the canvas <ButtonRelease> bind
# (an error there would pop Tk's bgerror modal), hence the catches.
# Write the item-10 status bar. NEVER THROWS: it rides the motion pump, and an
# error there would pop a bgerror dialog on every mouse move (readout_refresh's
# discipline, and the reason every widget touch below is guarded).
#
# The snapped sample is READ from item 9's published contract
# (`xschem get graph_snap` -> "gi wave x y", "" when nothing is snapped). Item
# 10 does not compute a position: item 9 owns that.
proc wviewer::status_refresh {token} {
  variable windows
  if {![dict exists $windows $token]} { return }
  set top [dict get $windows $token top]
  set w $top.wvstatus.l
  if {[catch {winfo exists $w} e] || !$e} { return }
  set m [wviewer::plot_mode $token]
  if {$m eq {}} { set m [wviewer::default_plot_mode] }
  set x {}; set y {}
  # The snap is READ ONLY WHEN THIS VIEWER'S CONTEXT IS ALREADY CURRENT — issue
  # 0173. It used to go through `wviewer::in_ctx`, which switched the context to
  # the viewer, and (pre-0173) never switched back; the Ctrl-Shift-4 path
  # (ase::plot_mode_for_current -> set_plot_mode -> here) therefore left the C
  # context on the viewer while the user was still in the schematic. in_ctx now
  # restores, but the right answer on this path is to not switch AT ALL:
  #   - the snap is per-context state that describes where the POINTER is. The
  #     pointer is over this viewer exactly when the motion pump inside it is
  #     what called us — and by then the C canvas <Motion> handler (bound before
  #     our `+` handler) has already made this viewer current. So the
  #     already-current test is not a restriction, it IS the "pointer is here"
  #     test.
  #   - on every OTHER caller (set_plot_mode's push, the open-time seed) the
  #     pointer is elsewhere, the snap would be stale or foreign, and the switch
  #     would buy a title rewrite plus a save_ctx/restore_ctx round trip for a
  #     value we then throw away.
  # The MODE half of the status bar needs no context at all: wviewer::plot_mode
  # is a plain Tcl array read, so the item-10 PUSH contract still holds from any
  # window. Only x/y go blank when we are not the current context, which is what
  # the pre-0173 code effectively displayed anyway (measured then: the status bar
  # showed the mode and never a coordinate).
  set snap {}
  set cur {}
  catch {set cur [xschem get current_win_path]}
  if {$cur ne {} && $cur eq [dict get $windows $token win_path]} {
    catch {set snap [xschem get graph_snap]}
  }
  if {[llength $snap] == 4} { set x [lindex $snap 2]; set y [lindex $snap 3] }
  set txt [wviewer::status_text $m $x $y]
  # only touch Tk when the string actually changed: this runs on every motion
  # event, and a -text configure is not free.
  if {[catch {$w cget -text} cur] || $cur ne $txt} { catch {$w configure -text $txt} }
}

proc wviewer::readout_refresh {token} {
  variable windows
  variable cva; variable cvb
  if {![dict exists $windows $token]} { return }
  set top [dict get $windows $token top]
  set bar $top.wvreadout
  if {[catch {winfo exists $bar} e] || !$e} { return }
  # issue 0173: this really does need the viewer's context (`xschem get
  # cursorN_x` and interp_value's `xschem raw` reads are both per-context), so
  # unlike status_refresh it cannot just decline to switch — it BORROWS the
  # context and gives it back. Same defect as in_ctx before the fix: the bare
  # `new_schematic switch $wp` here left the context on the viewer, and
  # readout_refresh is reachable from the schematic side through the regenerate
  # tail that Direct Plot drives. A refused switch means the readout goes
  # unrefreshed for one gesture, which is strictly better than reading another
  # window's cursors.
  set ticket [wviewer::enter_ctx $token]
  if {![lindex $ticket 0]} { return }
  # the body is BRACKETED: the restore has to run even if something in it throws.
  # This proc is appended to a <ButtonRelease> bind and is documented never to
  # throw, and a body that escaped past leave_ctx would leak the context — which
  # is issue 0173 all over again, from a path nobody would think to look at.
  # `catch` evaluates in this scope, so the locals and `variable`s below still
  # resolve normally.
  catch {
    set vecs {}
    set disps {}
    foreach G [dict get [wviewer::layout_for $token] graphs] {
      foreach tr [dict get $G traces] {
        set vec [wviewer::dget $tr vec {}]
        if {$vec eq {} || [lsearch -exact $vecs $vec] >= 0} { continue }
        lappend vecs $vec
        set nm [wviewer::dget $tr name {}]
        if {$nm eq {}} { set nm $vec }
        lappend disps $nm
      }
    }
    foreach {which letter} {1 a 2 b} {
      if {$which == 1} {
        set on [expr {[info exists cva($token)] && $cva($token)}]
      } else {
        set on [expr {[info exists cvb($token)] && $cvb($token)}]
      }
      set line {}
      if {$on} {
        set x {}
        catch {set x [xschem get cursor${which}_x]}
        if {$x ne {}} {
          set line "[string toupper $letter]: x=[ase::format_value $x]"
          foreach vec $vecs disp $disps {
            set y {}
            catch {set y [wviewer::interp_value $vec $x]}
            if {$y ne {}} { append line "   $disp=[ase::format_value $y]" }
          }
        }
      }
      catch {$bar.$letter configure -text $line}
    }
  }
  wviewer::leave_ctx $token $ticket
  return {}
}

# View > Fit (D6): engine autozoom + read-back — for every graph with
# traces run the engine's fullx/fullyzoom (computes the data range INTO the
# rect attrs, log/expr aware) and read the resulting ranges back into the
# model (the ONE sanctioned model write from engine-computed values; rect
# generation stays one-directional). Then a plain redraw — item 19 (D5)
# dropped the trailing `xschem zoom_full`: Fit reframes the GRAPH data range
# (fullx/fullyzoom), never the canvas viewport. item-18 pins the canvas so the
# graph already fills the window; a zoom_full here would SHRINK the graph (the
# very bug item 19 fixes). The graph-not-canvas invariant: canvas xorigin/
# yorigin/zoom are UNCHANGED by Fit.
proc wviewer::fit {token} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set rawok 0
  wviewer::with_edit $token {
    set rawok [expr {[xschem raw loaded] >= 0}]
    if {$rawok} {
      set gi_ 0
      foreach G_ $gs {
        if {[llength [dict get $G_ traces]]} {
          xschem setprop -fast rect 2 $gi_ fullxzoom
          xschem setprop -fast rect 2 $gi_ fullyzoom
        }
        incr gi_
      }
    }
  }
  if {$rawok} {
    set out {}
    set gi 0
    foreach G $gs {
      if {[llength [dict get $G traces]]} {
        foreach t {x1 x2 y1 y2} {
          catch {set G [dict replace $G $t [xschem getprop rect 2 $gi $t]]}
        }
      }
      lappend out $G
      incr gi
    }
    wviewer::set_graphs $token $out
  }
  wviewer::in_ctx $token {xschem redraw}
  wviewer::readout_refresh $token
  return 1
}

# --- graph interaction: wheel / zoom (item 19 graph-interact) -----------------
# The viewer wheel MIRRORS the cadence_style_rc canvas wheel scheme (plain =
# vertical scroll, Shift = horizontal, Ctrl = zoom) but applies it to GRAPH
# content, NOT the canvas: every pan/zoom edits the graph rect's range tokens
# (x1/x2/y1/y2) via the model + regenerate, leaving canvas xorigin/yorigin/zoom
# untouched (item-18 pins them). Forwarding the wheel to the C waveform handler
# was rejected (D1): plain wheel there is a HORIZONTAL body pan, which
# contradicts the user's ask. Pure Tcl setprop/getprop keeps it deterministic
# (item-17 lesson: witness a synchronous state write, not a gesture). RMB stays
# on the C engine (btn3_filter) — the engine already does graph x-zoom-to-box and
# leaves the canvas pinned.
#
# ⚠ CORRECTED 2026-08-01 (issue 0191). This used to say "Ctrl+wheel is
# hard-pinned to CANVAS zoom (callback.c:4417)". Wrong twice over: the cited line
# no longer exists, and over a GRAPH Ctrl+wheel is neither the canvas nor a zoom.
# MEASURED: it reaches waves_callback and is a graph X PAN of 0.05*gw,
# byte-identical to a plain wheel, with xorigin/yorigin/zoom untouched — because
# handle_button_press's inline waves_selected guard pre-empts handle_mouse_wheel
# for every wheel press over a strip (landmine 48). What that means for THIS
# proc: forwarding was still the wrong call, but the reason is the pan, not a
# canvas zoom.

# Index of the graph band under the viewer pointer (mousex_snap/mousey_snap),
# iterating graphbb($wp) exactly like over_graph; fallback 0 when there is
# none/one graph (the wheel acts on the pointed graph; a lone graph is always
# the target regardless of pointer position).
proc wviewer::graph_at_pointer {wp} {
  variable graphbb
  if {![dict exists $graphbb $wp]} { return 0 }
  set bbs [dict get $graphbb $wp]
  set n [llength $bbs]
  if {$n <= 1} { return 0 }
  xschem new_schematic switch $wp
  if {[xschem get current_win_path] ne $wp} { return 0 }
  set mx [xschem get mousex_snap]
  set my [xschem get mousey_snap]
  for {set gi 0} {$gi < $n} {incr gi} {
    lassign [lindex $bbs $gi] bx1 by1 bx2 by2
    if {$mx >= $bx1 && $mx <= $bx2 && $my >= $by1 && $my <= $by2} { return $gi }
  }
  return 0
}

# Current DRAWN range of model graph `gi`: switch to the viewer ctx and read
# `{x1 x2 y1 y2}` from `xschem getprop rect 2 $gi <tok>`. Each element is `{}`
# when the token is empty or not a finite number (concrete after regenerate's
# autozoom, but stay defensive). Returns four `{}` on an unknown token / a
# refused context switch.
proc wviewer::graph_range {token gi} {
  variable windows
  if {![dict exists $windows $token]} { return {{} {} {} {}} }
  if {![wviewer::switch_ctx $token]} { return {{} {} {} {}} }
  set out {}
  foreach tok {x1 x2 y1 y2} {
    set v {}
    catch {set v [xschem getprop rect 2 $gi $tok]}
    if {![string is double -strict $v]} { set v {} }
    lappend out $v
  }
  return $out
}

# Write the four concrete range values into model graph `gi` (any `{}` axis is
# left unchanged) + set_graphs, then re-render through regenerate — item-18
# canvas-safe (no zoom_full), keeps model<->rect in sync, never touches the
# canvas origin/zoom. D7: callers pass ALL FOUR concrete (the read-back values
# for untouched axes) so regenerate never re-autozooms and wipes a prior
# pan/zoom on the other axis.
proc wviewer::apply_range {token gi x1 x2 y1 y2} {
  set gs [dict get [wviewer::layout_for $token] graphs]
  if {![string is integer -strict $gi] || $gi < 0 || $gi >= [llength $gs]} {
    return 0
  }
  # issue 0194: the D7 freeze this proc performs covers the RANGES and nothing
  # else — it regenerates, so the selection needs the fold too. AFTER the
  # validation above (a refused call must stay the pure no-op it always was:
  # capture mutates the model and switches the xschem context) and BEFORE the
  # `gs` re-read below, since capture writes through set_graphs.
  wviewer::capture_live_view_state $token
  set gs [dict get [wviewer::layout_for $token] graphs]
  set G [lindex $gs $gi]
  foreach {k v} [list x1 $x1 x2 $x2 y1 $y1 y2 $y2] {
    if {$v ne {}} { dict set G $k $v }
  }
  wviewer::set_graphs $token [lreplace $gs $gi $gi $G]
  wviewer::regenerate $token
  return 1
}

# Scale the range [lo,hi] by factor `f` keeping the data coordinate `a` at the
# SAME relative position — the point under the cursor does not move (issue 0146).
# `a` empty or outside [lo,hi] falls back to / clamps to the range, so an anchor
# in a plot margin pins the nearest edge instead of flinging the window. Pure:
# returns the new {lo hi}. Zoom-about-centre is just a == the midpoint.
proc wviewer::zoom_about {lo hi a f} {
  if {$a eq {} || ![string is double -strict $a]} {
    set a [expr {($lo + $hi) / 2.0}]
  } elseif {$a < $lo} { set a $lo } elseif {$a > $hi} { set a $hi }
  return [list [expr {$a - ($a - $lo) * $f}] [expr {$a + ($hi - $a) * $f}]]
}

# ONE CTRL+wheel click's new window for strip `gi`'s `axis` (x|y), anchored at
# canvas pixel `p`, `dir` in in|out — straight from C (issue 0191, §18).
#
# The viewer computes NOTHING here: the anchored map, the plot-box geometry and
# the step size all live in graph_axis_wheel_map() (src/draw.c), so the ASE
# viewer's margin zoom and an embedded schematic graph's cannot disagree. The
# same rule as wviewer::axis_grabbed (D-22): ask C, never re-derive the 14%
# margins in Tcl.
# Fails CLOSED to {}: a missing verb, a refused ctx switch, a strip with no
# transform. The caller must then leave that strip COMPLETELY unchanged rather
# than fall back to a second formula.
proc wviewer::axis_wheel_window {token gi axis p dir} {
  if {$p eq {} || ![string is double -strict $p]} { return {} }
  if {![wviewer::switch_ctx $token]} { return {} }
  set w {}
  catch {set w [xschem get graph_axis_wheel_map $gi $axis $p $dir]}
  if {[llength $w] != 2} { return {} }
  foreach v $w {
    if {![string is double -strict $v] || [string match -nocase {*inf*} $v] ||
        [string match -nocase {*nan*} $v]} { return {} }
  }
  return $w
}

# Ctrl+wheel zoom (D1, REVISED by issue 0144 — was X-only on the pointed graph).
# Zoom about center by 0.8 (in) / 1/0.8 (out): the X window on EVERY graph, so
# the stacked strips stay time-aligned; the Y window ONLY on graph `gi`, the
# strip under the pointer. Y is deliberately per-strip — each carries its own
# signal scale, so zooming Y on all of them at once would fight the user's
# intent; the other strips "only match the X zoom".
# Every axis is re-frozen at its read-back value BEFORE zooming (D7) so
# regenerate cannot re-autozoom an untouched axis away. ONE set_graphs +
# regenerate for the whole sweep. Also fixes X under `sharedx 1`: regenerate
# makes non-master graphs inherit graph-0's x range, so zooming the pointed
# graph alone was clobbered — zooming every graph by the same factor is
# consistent under sharedx 0 and 1. Separate from `wviewer::wheel` as the
# synchronous-write seam tests drive directly (item-17 lesson).
# Returns 1 when anything was written, else 0.
#
# `axis` (issue 0191, §18) narrows the gesture to ONE axis when the pointer is in
# a strip's axis-number margin:
#   {}  the shipped BODY zoom, byte for byte: X on every strip and Y on `gi`,
#       both through wviewer::zoom_about. Every pre-0191 caller passes nothing
#       (wviewer::wheel's body case, wviewer::graph_zoom for the View menu / Z /
#       Ctrl-z) and is untouched.
#   x   X only, on every strip, each strip's new window taken from C.
#   y   Y only, on `gi` only, same source.
# The axis arms take their window from `xschem get graph_axis_wheel_map`
# (D-25/D-28) so the viewer and the embedded-graph gesture cannot drift apart:
# ONE anchored formula, in C, with GRAPH_AXIS_WHEEL_FACTOR as its only step. The
# body arm deliberately keeps zoom_about — changing shipped behaviour is out of
# this item's scope — and the two agree numerically, which the suite's CS3 leg
# asserts against wviewer::zoom_about directly.
# A strip the verb answers {} for is left COMPLETELY unchanged; it never falls
# back to zoom_about, which would be a second formula answering for one gesture.
proc wviewer::wheel_zoom {token dir gi {px {}} {py {}} {axis {}}} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  # issue 0194: the per-strip range read-back below is a RANGE capture only, so
  # a zoom still dropped the selection on its regenerate. Fold at the top,
  # before the `gs` read (capture writes through set_graphs).
  wviewer::capture_live_view_state $token
  set gs [dict get [wviewer::layout_for $token] graphs]
  set n [llength $gs]
  # ⚠ MIRRORED IN C: src/xschem.h GRAPH_AXIS_WHEEL_FACTOR carries this same 0.8,
  # because the axis arms below take their window from the C formula while this
  # body arm computes its own with zoom_about. Change BOTH — test_wave_axis_zoom's
  # CS2 leg reads the two out of source and asserts they are equal.
  set f [expr {($dir eq {up} || $dir eq {in}) ? 0.8 : 1 / 0.8}]
  set wdir [expr {($dir eq {up} || $dir eq {in}) ? {in} : {out}}]
  # ANCHOR (issue 0146): the data point under the pointer must stay put, like the
  # schematic's view_zoom. `graph_coord` (C) inverts the draw transform for the
  # POINTED strip — Tcl must not re-derive the plot box's margins. The x anchor
  # (a time) is reused by every strip: they share the axis, so anchoring them all
  # at the cursor's time keeps the stack aligned AND pinned under the cursor.
  # Anything unavailable (no pixel given — e.g. the View menu — bad index, refused
  # ctx switch, non-numeric) falls back to that axis's CENTRE.
  set anx {} ; set any {}
  if {$px ne {} && $py ne {} && [wviewer::switch_ctx $token]} {
    set a {}
    catch {set a [xschem graph_coord $gi $px $py]}
    if {[llength $a] == 2} {
      lassign $a a0 a1
      # finite only: `string is double` ACCEPTS Inf/NaN, and a non-finite anchor
      # would clamp to an edge instead of falling back to centre. The C verb
      # already refuses an untransformed (off-screen) graph — this is the
      # belt-and-braces check on the value crossing the C->Tcl boundary.
      foreach {v_ n_} [list $a0 anx $a1 any] {
        if {[string is double -strict $v_] && ![string match -nocase {*inf*} $v_]
            && ![string match -nocase {*nan*} $v_]} { set $n_ $v_ }
      }
    }
  }
  set changed 0
  for {set t 0} {$t < $n} {incr t} {
    lassign [wviewer::graph_range $token $t] ax1 ax2 ay1 ay2
    set G [lindex $gs $t]
    # D7: freeze every concrete axis first, then zoom the ones this gesture owns
    foreach {k v} [list x1 $ax1 x2 $ax2 y1 $ay1 y2 $ay2] {
      if {$v ne {}} { dict set G $k $v }
    }
    if {$axis eq {x}} {
      # issue 0191: X only, on every strip, anchored at $px. Per STRIP, so each
      # is anchored in its OWN window at the same pointer pixel — the same answer
      # when the windows agree and the right one when they do not (D-33).
      set w [wviewer::axis_wheel_window $token $t x $px $wdir]
      if {[llength $w] == 2} {
        dict set G x1 [lindex $w 0]
        dict set G x2 [lindex $w 1]
        set changed 1
      }
    } elseif {$axis eq {y}} {
      if {$t == $gi} {
        set w [wviewer::axis_wheel_window $token $t y $py $wdir]
        if {[llength $w] == 2} {
          dict set G y1 [lindex $w 0]
          dict set G y2 [lindex $w 1]
          set changed 1
        }
      }
    } else {
      if {$ax1 ne {} && $ax2 ne {}} {
        lassign [wviewer::zoom_about $ax1 $ax2 $anx $f] nx1 nx2
        dict set G x1 $nx1
        dict set G x2 $nx2
        set changed 1
      }
      if {$t == $gi && $ay1 ne {} && $ay2 ne {}} {
        lassign [wviewer::zoom_about $ay1 $ay2 $any $f] ny1 ny2
        dict set G y1 $ny1
        dict set G y2 $ny2
        set changed 1
      }
    }
    set gs [lreplace $gs $t $t $G]
  }
  if {$changed} {
    wviewer::set_graphs $token $gs
    wviewer::regenerate $token
  }
  return $changed
}

# Horizontal (X) pan of the WHOLE stack — issue 0150. The X axis is shared: the
# strips are time-aligned, so any x change must hit EVERY graph, or one strip
# slides out of step with the rest (the user-reported Shift+wheel bug; the same
# rule already governs zoom, wheel_zoom's X arm, 0144). Y is the opposite — each
# strip carries its own signal scale and pans independently.
# Each strip shifts by 5% of ITS OWN span (identical motion in the normal
# shared-range case, proportional when the ranges differ), `dir` up|right = toward
# larger x. Every axis is re-frozen at its read-back value first (D7) so
# regenerate cannot autozoom an untouched axis away; ONE set_graphs + regenerate
# for the whole sweep. Returns 1 when anything was written.
proc wviewer::pan_x {token dir} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  wviewer::capture_live_view_state $token   ;# issue 0194, as wheel_zoom
  set gs [dict get [wviewer::layout_for $token] graphs]
  set n [llength $gs]
  set changed 0
  for {set t 0} {$t < $n} {incr t} {
    lassign [wviewer::graph_range $token $t] ax1 ax2 ay1 ay2
    set G [lindex $gs $t]
    foreach {k v} [list x1 $ax1 x2 $ax2 y1 $ay1 y2 $ay2] {
      if {$v ne {}} { dict set G $k $v }
    }
    if {$ax1 ne {} && $ax2 ne {}} {
      set d [expr {0.05 * ($ax2 - $ax1)}]
      if {$dir eq {down} || $dir eq {left}} { set d [expr {-$d}] }
      dict set G x1 [expr {$ax1 + $d}]
      dict set G x2 [expr {$ax2 + $d}]
      set changed 1
    }
    set gs [lreplace $gs $t $t $G]
  }
  if {$changed} {
    wviewer::set_graphs $token $gs
    wviewer::regenerate $token
  }
  return $changed
}

# Viewer wheel handler (D1/D3/D7). `dir` in up|down, `mods` in 0|shift|ctrl:
#   0     (plain) -> GRAPH vertical pan: shift y1/y2 by +-5% of the y span
#                    (up = toward larger y / view moves up; down = opposite).
#   shift          -> GRAPH horizontal pan: shift x1/x2 by +-5% of the x span,
#                    on EVERY strip (issue 0150 — X is the shared axis).
#   ctrl           -> GRAPH zoom (wviewer::wheel_zoom), anchored at the pointer:
#                    X on every graph, Y on the POINTED graph only (issue 0144)
#                    — EXCEPT in a strip's axis-number MARGIN, where it zooms
#                    THAT AXIS ONLY (issue 0191, §18); C decides the region.
# Acts on the pointed graph (graph_at_pointer). Reads the concrete range, applies
# the delta, freezes ALL FOUR (D7). A `{}` target axis (nothing to pan/zoom) is
# a no-op.
proc wviewer::wheel {token wp dir mods {px {}} {py {}}} {
  variable windows
  if {![dict exists $windows $token]} { return }
  set gi [wviewer::graph_at_pointer $wp]
  lassign [wviewer::graph_range $token $gi] x1 x2 y1 y2
  switch -- $mods {
    shift {
      # issue 0150: X is the SHARED axis of the stack — pan it on EVERY strip
      # (wviewer::pan_x), never just the pointed one, exactly like the X arm of
      # wheel_zoom (0144). Y stays per-strip (the `default` arm below).
      return [wviewer::pan_x $token $dir]
    }
    ctrl {
      # X on every graph + Y on the pointed one, anchored at the pointer pixel
      # (0146); writes + regenerates itself.
      #
      # issue 0191: in a strip's AXIS-NUMBER margin, Ctrl+wheel zooms THAT AXIS
      # ONLY, still anchored at the pointer. C owns the geometry — the viewer
      # hit-tests nothing (D-22/D-38), and a stale mouse mirror can only make
      # this answer {} and degrade to the shipped both-axes zoom, never pick the
      # wrong strip. %x/%y (the EVENT's own pixels) go to C, not mousex_snap.
      set ax {}
      if {[wviewer::switch_ctx $token]} {
        catch {set ax [xschem get graph_axis_at $gi $px $py]}
      }
      if {$ax ne {x} && $ax ne {y}} { set ax {} }
      wviewer::wheel_zoom $token $dir $gi $px $py $ax
      return
    }
    default {
      if {$y1 eq {} || $y2 eq {}} { return }
      set d [expr {0.05 * ($y2 - $y1)}]
      if {$dir eq {down}} { set d [expr {-$d}] }
      set y1 [expr {$y1 + $d}]
      set y2 [expr {$y2 + $d}]
    }
  }
  wviewer::apply_range $token $gi $x1 $x2 $y1 $y2
}

# View menu Zoom In/Out + the Z / Ctrl-z keys (D6, REVISED by issue 0145 — was
# X-only on every graph). Now identical to Ctrl+wheel (issue 0144): X on EVERY
# strip, Y on the strip under the pointer, via wviewer::wheel_zoom. `dir` is
# in|out (wheel_zoom takes in/up and out/down alike). `gi all` (every caller's
# default) resolves the pointed strip with graph_at_pointer — accurate for the
# keys, and for the menu it is the LAST strip the pointer was over (the click
# leaves the canvas but mousex_snap keeps the last canvas position; it falls back
# to strip 0 when the pointer was never over one). An explicit `gi` names the Y
# target directly (scripting/tests). `px`/`py` (canvas pixels) anchor the zoom at
# the pointer (0146) — the Z / Ctrl-z keys pass the KeyPress %x/%y; the View menu
# passes none (its click is off-canvas), so it zooms about centre.
# Returns wheel_zoom's changed flag.
proc wviewer::graph_zoom {token dir {gi all} {px {}} {py {}}} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  if {$gi eq {all}} {
    set gi [wviewer::graph_at_pointer [dict get $windows $token win_path]]
  }
  return [wviewer::wheel_zoom $token $dir $gi $px $py]
}

# Wheel binding shim: resolve the session token from the canvas at EVENT time
# (never capture a stale token at bind time — strip_bindings only has `wp`).
# `px`/`py` are the event's %x/%y — the zoom anchor (0146).
proc wviewer::wheel_bind {wp dir mods {px {}} {py {}}} {
  set token [wviewer::token_for_canvas $wp]
  if {$token eq {}} { return }
  wviewer::wheel $token $wp $dir $mods $px $py
}

# Arrow keys (issue 0149): pan the GRAPH in the arrow's direction, exactly the
# wheel pan (`wviewer::wheel`, ±5% of the span) — Left/Right = the horizontal
# (Shift+wheel) pan, on EVERY strip (0150: X is shared); Up/Down = the vertical
# (plain wheel) pan, on the pointed strip only (Y is per-strip).
# They are handled here and NEVER forwarded to the C canvas: the graphs own the
# viewer window, so no gesture in it may scroll the canvas and expose blank space.
# `s` is the event state mask: ANY of Shift(1)/Ctrl(4)/Alt(8) is SWALLOWED (0
# returned) — those chords are canvas-only in C (SET_MODMASK makes waves_selected
# skip, so they reach the hard-coded origin pan; Ctrl+Left/Right is tab switch)
# and have no graph meaning. This deliberately replaces item 19's "arrows forward
# to the C over_graph graph.forward" (whose Up/Down was an X zoom): zoom already
# has four affordances (Ctrl+wheel, View menu, Z, Ctrl-z, all -> wheel_zoom), and
# 4-way pan is what an arrow key means. Returns 1 when a pan was applied.
proc wviewer::arrow_pan {token wp N s} {
  if {$s & 13} { return 0 }                           ;# Shift|Control|Mod1
  # NO trailing `;#` comments inside the switch body: its braced argument is a
  # pattern/body WORD LIST, not a script — a comment there silently shifts every
  # later pair (Right/Down fell through to `default` when this was first written).
  # 65361 Left = view left, 65363 Right = view right (both the Shift+wheel
  # horizontal pan); 65362 Up / 65364 Down = the plain-wheel vertical pan.
  switch -- $N {
    65361 { wviewer::wheel $token $wp down shift }
    65363 { wviewer::wheel $token $wp up   shift }
    65362 { wviewer::wheel $token $wp up   0 }
    65364 { wviewer::wheel $token $wp down 0 }
    default { return 0 }
  }
  return 1
}

# --- Graph menu dialogs (item 12, D3/D11/D13) --------------------------------
# All dialogs: ase::ui scaffold (dialog_frame/dialog_row/dialog_buttons —
# ESC = the cancel path by construction, item 10), ase theme, Return = OK,
# widget paths under the viewer toplevel, transient state cleaned on
# OK/cancel. Modeless (no grab) — test-drivable.

# Graph > Add Trace… (D11): expression entry + pick-from-raw-vars listbox
# + optional name + target-graph combobox (default LAST graph; hidden when
# fewer than 2 graphs). Double-click on a var copies it into the
# expression entry; OK with an empty entry uses the listbox selection.
# Bad expressions surface in the in-dialog error label (D4) — the dialog
# stays up, nothing is added.
proc wviewer::add_trace_dialog {token} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  set top [dict get $windows $token top]
  set wp  [dict get $windows $token win_path]
  set w [ase::ui::dialog_frame $top.wvadd {Add Trace}]
  set gcount [llength [dict get [wviewer::layout_for $token] graphs]]
  label $w.lgraph -text Graph: -font AseLabelFont -anchor w
  ttk::combobox $w.graph -state readonly -width 6
  if {$gcount > 1} {
    set vals {}
    for {set i 0} {$i < $gcount} {incr i} { lappend vals $i }
    $w.graph configure -values $vals
    $w.graph set [expr {$gcount - 1}]
    grid $w.lgraph -row 0 -column 0 -sticky w -padx {8 6} -pady 2
    grid $w.graph  -row 0 -column 1 -sticky w -padx {0 8} -pady 2
  } else {
    $w.graph configure -values 0
    $w.graph set [expr {$gcount > 0 ? $gcount - 1 : 0}]
  }
  set ee [ase::ui::dialog_row $w 1 Expression: expr]
  set ne [ase::ui::dialog_row $w 2 {Name (optional):} name]
  label $w.lvars -text {Raw variables (double-click to use):} \
    -font AseLabelFont -anchor w
  listbox $w.vars -height 8 -font AseEntryFont -exportselection 0 \
    -background [ase::theme table] -yscrollcommand [list $w.vsb set]
  scrollbar $w.vsb -command [list $w.vars yview]
  grid $w.lvars -row 3 -column 0 -columnspan 2 -sticky w -padx 8 -pady {6 0}
  grid $w.vars  -row 4 -column 0 -columnspan 2 -sticky nsew -padx {8 0}
  grid $w.vsb   -row 4 -column 2 -sticky ns -padx {0 8}
  grid rowconfigure $w 4 -weight 1
  label $w.err -text {} -font AseLabelFont -anchor w
  grid $w.err -row 5 -column 0 -columnspan 3 -sticky we -padx 8
  set rawnote {}
  xschem new_schematic switch $wp
  if {[catch {xschem raw list} rl]} {
    set rawnote {no raw data loaded - variable list unavailable}
  } else {
    foreach v [split $rl "\n"] { $w.vars insert end $v }
  }
  bind $w.vars <Double-Button-1> [list wviewer::add_trace_pick $token]
  ase::ui::dialog_buttons $w 6 [list wviewer::add_trace_ok $token] \
    [list destroy $w]
  bind $ee <Return> [list wviewer::add_trace_ok $token]
  bind $ne <Return> [list wviewer::add_trace_ok $token]
  ase::ui::apply_theme $w
  $w.err configure -foreground [ase::theme accent]
  if {$rawnote ne {}} { $w.err configure -text $rawnote }
  focus $ee
  return $w
}

# Double-click in the raw-vars listbox: copy the picked var into the
# expression entry.
proc wviewer::add_trace_pick {token} {
  variable windows
  if {![dict exists $windows $token]} { return }
  set w [dict get $windows $token top].wvadd
  if {![winfo exists $w]} { return }
  set sel [$w.vars curselection]
  if {$sel eq {}} { return }
  $w.expr delete 0 end
  $w.expr insert 0 [$w.vars get [lindex $sel 0]]
}

proc wviewer::add_trace_ok {token} {
  variable windows
  if {![dict exists $windows $token]} { return }
  set w [dict get $windows $token top].wvadd
  if {![winfo exists $w]} { return }
  set gi [$w.graph get]
  set rpn [string trim [$w.expr get]]
  if {$rpn eq {}} {
    set sel [$w.vars curselection]
    if {$sel ne {}} { set rpn [$w.vars get [lindex $sel 0]] }
  }
  set name [string trim [$w.name get]]
  set err [wviewer::add_trace $token $gi $rpn $name]
  if {$err ne {}} {
    $w.err configure -text $err
    return
  }
  destroy $w
}

# Graph > Delete… (D3): ONE listbox with a row per graph ("graph N") and
# per trace ("graph N: name (expr)"), extended selection; OK deletes the
# selected traces and/or whole graphs from the model + regenerate.
# ⚠ CORRECTED 2026-07-30 (issue 0175). This used to justify the listbox with
# "canvas-legend click-select has no C hit-test API (receipts/11: rect
# descriptors carry no coordinates)". The engine DID have the hit test — it
# was fused into edit_wave_attributes()' Button3 action, with no standalone
# query — and 0175 extracted it as `xschem get graph_legend_at` and gave it
# an LMB arm, so a trace IS click-selectable now (Ctrl+click for several).
# The listbox survives as the BULK path: it can reach whole graphs and
# vec-less traces, neither of which has a clickable legend entry.
proc wviewer::delete_dialog {token} {
  variable windows
  variable delmap
  if {![dict exists $windows $token]} { return {} }
  set top [dict get $windows $token top]
  set w [ase::ui::dialog_frame $top.wvdel {Delete Traces / Graphs}]
  label $w.litems -text {Select traces or graphs to delete:} \
    -font AseLabelFont -anchor w
  listbox $w.items -height 10 -selectmode extended -font AseEntryFont \
    -exportselection 0 -background [ase::theme table] \
    -yscrollcommand [list $w.dsb set]
  scrollbar $w.dsb -command [list $w.items yview]
  grid $w.litems -row 0 -column 0 -columnspan 2 -sticky w -padx 8 -pady {6 0}
  grid $w.items  -row 1 -column 0 -columnspan 2 -sticky nsew -padx {8 0}
  grid $w.dsb    -row 1 -column 2 -sticky ns -padx {0 8}
  grid rowconfigure $w 1 -weight 1
  set map {}
  set gi 0
  foreach G [dict get [wviewer::layout_for $token] graphs] {
    $w.items insert end "graph $gi"
    lappend map [list graph $gi]
    set ti 0
    foreach tr [dict get $G traces] {
      set nm [wviewer::dget $tr name {}]
      if {$nm eq {}} { set nm [wviewer::dget $tr vec {}] }
      $w.items insert end "graph $gi: $nm ([wviewer::dget $tr expr {}])"
      lappend map [list trace $gi $ti]
      incr ti
    }
    incr gi
  }
  set delmap($token) $map
  ase::ui::dialog_buttons $w 2 [list wviewer::delete_ok $token] \
    [list wviewer::delete_cancel $token]
  ase::ui::apply_theme $w
  focus $w.items
  return $w
}

proc wviewer::delete_cancel {token} {
  variable windows
  variable delmap
  catch {unset delmap($token)}
  if {[dict exists $windows $token]} {
    catch {destroy [dict get $windows $token top].wvdel}
  }
}

# The OK button. Since issue 0176 this is only a DECODER: it turns the listbox
# selection into the `{graph gi}` / `{trace gi ti}` entries `delmap` recorded and
# hands them to `wviewer::delete_items`, which owns the whole mutation — the
# capture, the undo point, the marker cascade, the window-wide number sweep, the
# target remap, the single regenerate and the single replayable log line.
#
# All of that except the cascade and the sweep is NEW here: this path had never
# pushed an undo point and had never logged, so deleting traces through the
# dialog was neither undoable nor replayable. That was a pre-existing defect,
# repaired on the way — doc/claude/issues/0176-del-deletes-selection.md.
#
# The dialog is destroyed BEFORE the mutation so it cannot sit over the repaint.
proc wviewer::delete_ok {token} {
  variable windows
  variable delmap
  if {![dict exists $windows $token]} { return }
  set w [dict get $windows $token top].wvdel
  if {![winfo exists $w]} { return }
  set map {}
  if {[info exists delmap($token)]} { set map $delmap($token) }
  set delg {}
  set pairs {}
  foreach idx [$w.items curselection] {
    set ent [lindex $map $idx]
    if {[lindex $ent 0] eq {graph}} {
      lappend delg [lindex $ent 1]
    } elseif {[lindex $ent 0] eq {trace}} {
      lappend pairs [list [lindex $ent 1] [lindex $ent 2]]
    }
  }
  catch {unset delmap($token)}
  destroy $w
  return [wviewer::delete_items $delg $pairs {} $token]
}

# Graph > Axes… (D13): per-graph x/y min/max entries (blank = auto) +
# logx/logy checkbuttons -> model -> regenerate.
proc wviewer::axes_dialog {token} {
  variable windows
  variable axl
  if {![dict exists $windows $token]} { return {} }
  set top [dict get $windows $token top]
  set w [ase::ui::dialog_frame $top.wvaxes {Axes}]
  set gcount [llength [dict get [wviewer::layout_for $token] graphs]]
  set vals {}
  for {set i 0} {$i < $gcount} {incr i} { lappend vals $i }
  label $w.lgraph -text Graph: -font AseLabelFont -anchor w
  ttk::combobox $w.graph -state readonly -width 6 -values $vals
  if {$gcount > 0} { $w.graph set 0 }
  grid $w.lgraph -row 0 -column 0 -sticky w -padx {8 6} -pady 2
  grid $w.graph  -row 0 -column 1 -sticky w -padx {0 8} -pady 2
  ase::ui::dialog_row $w 1 {X min (blank=auto):} x1
  ase::ui::dialog_row $w 2 {X max (blank=auto):} x2
  ase::ui::dialog_row $w 3 {Y min (blank=auto):} y1
  ase::ui::dialog_row $w 4 {Y max (blank=auto):} y2
  checkbutton $w.logx -text {Log X} -variable ::wviewer::axl($token,x) \
    -font AseLabelFont -anchor w
  checkbutton $w.logy -text {Log Y} -variable ::wviewer::axl($token,y) \
    -font AseLabelFont -anchor w
  grid $w.logx -row 5 -column 0 -sticky w -padx 8
  grid $w.logy -row 5 -column 1 -sticky w
  label $w.err -text {} -font AseLabelFont -anchor w
  grid $w.err -row 6 -column 0 -columnspan 2 -sticky we -padx 8
  bind $w.graph <<ComboboxSelected>> [list wviewer::axes_load $token]
  ase::ui::dialog_buttons $w 7 [list wviewer::axes_ok $token] \
    [list wviewer::axes_cancel $token]
  foreach en {x1 x2 y1 y2} {
    bind $w.$en <Return> [list wviewer::axes_ok $token]
  }
  ase::ui::apply_theme $w
  $w.err configure -foreground [ase::theme accent]
  wviewer::axes_load $token
  focus $w.x1
  return $w
}

# Fill the Axes… fields from the model graph the combobox selects.
proc wviewer::axes_load {token} {
  variable windows
  variable axl
  if {![dict exists $windows $token]} { return }
  set w [dict get $windows $token top].wvaxes
  if {![winfo exists $w]} { return }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set gi [$w.graph get]
  if {![string is integer -strict $gi] || $gi < 0 || $gi >= [llength $gs]} {
    return
  }
  set G [lindex $gs $gi]
  foreach en {x1 x2 y1 y2} {
    $w.$en delete 0 end
    $w.$en insert 0 [wviewer::dget $G $en {}]
  }
  set axl($token,x) [wviewer::dget $G logx 0]
  set axl($token,y) [wviewer::dget $G logy 0]
}

proc wviewer::axes_cancel {token} {
  variable windows
  variable axl
  array unset axl ${token},*
  if {[dict exists $windows $token]} {
    catch {destroy [dict get $windows $token top].wvaxes}
  }
}

proc wviewer::axes_ok {token} {
  variable windows
  variable axl
  if {![dict exists $windows $token]} { return }
  set w [dict get $windows $token top].wvaxes
  if {![winfo exists $w]} { return }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set gi [$w.graph get]
  if {![string is integer -strict $gi] || $gi < 0 || $gi >= [llength $gs]} {
    $w.err configure -text "no such graph '$gi'"
    return
  }
  # every entry is validated BEFORE anything is written, so a typo leaves the
  # dialog up with nothing changed. The capture below must sit on the same side
  # of that line: it mutates the model and moves the xschem context, and this
  # error path was a pure no-op before issue 0194.
  set vals {}
  foreach en {x1 x2 y1 y2} {
    set v [string trim [$w.$en get]]
    if {$v ne {} && ![string is double -strict $v]} {
      $w.err configure -text "not a number: $en '$v' (blank = auto)"
      return
    }
    lappend vals $v
  }
  # issue 0194: the dialog edits ONE strip's axes; every other strip's selection
  # must survive the regenerate. skip_ranges is load-bearing here — a blank
  # entry means auto, and a fold that wrote ranges would pin every OTHER strip's
  # auto axes, quietly turning this dialog into a window-wide freeze.
  wviewer::capture_live_view_state $token
  set gs [dict get [wviewer::layout_for $token] graphs]
  set G [lindex $gs $gi]
  foreach en {x1 x2 y1 y2} v $vals {
    set G [dict replace $G $en $v]
  }
  set G [dict replace $G \
    logx [expr {[info exists axl($token,x)] && $axl($token,x) ? 1 : 0}] \
    logy [expr {[info exists axl($token,y)] && $axl($token,y) ? 1 : 0}]]
  wviewer::set_graphs $token [lreplace $gs $gi $gi $G]
  array unset axl ${token},*
  destroy $w
  wviewer::regenerate $token
}

# 1 when the pointer (last snapped position of the viewer ctx) sits inside a
# graph rect of viewer canvas `wp` — the gate for graph-context keys/Button-3.
proc wviewer::over_graph {wp} {
  variable graphbb
  if {![dict exists $graphbb $wp]} { return 0 }
  if {[xschem get current_win_path] ne $wp} { return 0 }
  set mx [xschem get mousex_snap]
  set my [xschem get mousey_snap]
  foreach bb [dict get $graphbb $wp] {
    lassign $bb bx1 by1 bx2 by2
    if {$mx >= $bx1 && $mx <= $bx2 && $my >= $by1 && $my <= $by2} { return 1 }
  }
  return 0
}

# --- binding strip (D2) ------------------------------------------------------

# The viewer's generic key handler, replacing the editor <KeyPress>/
# <KeyRelease> binds on the viewer .drw ONLY. Allowlist:
#   intercepted to the GRAPH (item 19, D4 — NOT forwarded to the C canvas-zoom
#     keys): f = fit (x+y), Z = graph zoom in (X), Ctrl-z = graph zoom out (X);
#     arrows = 4-way graph pan (issue 0149 — modified arrows swallowed);
#   always forwarded: Escape (abort+redraw — NEVER closes, D10);
#   over a graph only: a b s m t A B (+ctrl) — the waves_callback key set;
#   Delete: intercepted to the SELECTION over a graph, never forwarded
#     (issue 0176 — the marker, the traces, or both);
#   Ctrl-W: close the viewer (handled Tcl-side, swallowed);
#   everything else: swallowed silently (readonly backstops any miss).
proc wviewer::key_filter {W T x y N K s} {
  variable graphkeys
  if {($s & 4) && ($N == 119 || $N == 87)} {          ;# Ctrl-W / Ctrl-Shift-W
    if {$T == 2} { wviewer::close [wviewer::token_for_canvas $W] }
    return
  }
  # item 19 (D4): f / Z / Ctrl-z act on the GRAPH, not the canvas. Intercept
  # them here (act on KeyPress, T==2; swallow the matching KeyRelease) instead
  # of forwarding to the C canvas-zoom keys. `f` = FIT (full x+y = wviewer::fit,
  # the only path that fits BOTH axes); `Z`/`Ctrl-z` = graph zoom in/out like
  # View>Zoom — X on every strip, Y on the pointed strip (0145), anchored at the
  # KeyPress pointer %x/%y (0146, like the schematic's view_zoom).
  # token {} (unknown canvas) falls through to the old forward.
  set tok19 [wviewer::token_for_canvas $W]
  if {$tok19 ne {}} {
    if {$N == 102} {                                  ;# f = fit (x+y)
      if {$T == 2} { wviewer::fit $tok19 }
      return
    } elseif {$N == 90} {                             ;# Z = graph zoom in (X)
      if {$T == 2} { wviewer::graph_zoom $tok19 in all $x $y }
      return
    } elseif {$N == 122 && ($s & 4)} {                ;# Ctrl-z = graph zoom out
      if {$T == 2} { wviewer::graph_zoom $tok19 out all $x $y }
      return
    } elseif {$N >= 65361 && $N <= 65364} {           ;# Left Up Right Down
      # issue 0149: the arrows PAN THE GRAPH and are never forwarded. Forwarding
      # them let the C canvas own the gesture in three ways, all of which scroll
      # the CANVAS and expose blank space around the graphs: off a graph the
      # data-driven bare arrow is ACTX_CANVAS -> view.scroll_* ; ANY modifier
      # makes waves_selected skip (SET_MODMASK) so Alt/Shift+arrow hit the
      # hard-coded xorigin/yorigin pan (callback.c XK_Left..XK_Up); and
      # Ctrl+Left/Right is prev_tab/next_tab. arrow_pan swallows every modified
      # arrow and pans the graph for the bare ones.
      if {$T == 2} { wviewer::arrow_pan $tok19 $W $N $s }
      return
    }
  }
  set fwd 0
  if {$K eq {Escape}} {
    # abandon an in-flight strip drag BEFORE the normal forward (D10 keeps ESC
    # forwarded to C for its abort+redraw; the cancel is additive)
    if {$T == 2} { wviewer::strip_drag_cancel $W }
    catch {destroy .ctxmenu}                          ;# mirror the editor bind
    set fwd 1
  } elseif {$N == 102 || $N == 90 || ($N == 122 && ($s & 4))} {
    set fwd 1
  } elseif {[lsearch -exact $graphkeys $N] >= 0 && [wviewer::over_graph $W]} {
    # graphkeys membership is otherwise unconditional on modifiers, which is
    # right for a/b/s (Ctrl+a, Ctrl+b, Ctrl+s are real ctx=graph rows in
    # keybindings.csv). `d` is the one member with a live collision: Ctrl-D is
    # the viewer's Clear All on the WaveViewer bindtag, and there is NO ctx=graph
    # row for Ctrl+d — so a forward falls through to the schematic `case 'd'`,
    # whose ControlMask branch is delete_files(), a MODAL FILE DIALOG over a
    # readonly viewer. Refusing the forward leaves the tag binding to clear.
    set fwd [expr {!($N == 100 && ($s & 4))}]
  }
  # Delete deletes WHATEVER is selected — the selected marker, the selected
  # traces, or both (issue 0176, doc/claude/issues/0176-del-deletes-selection.md).
  # It is handled ENTIRELY Tcl-side and is NEVER forwarded, which is a
  # strengthening of the rule the old marker-only arm already lived by:
  # Delete is deliberately not a `graphkeys` member (membership means
  # UNCONDITIONAL forwarding), because a Delete that reaches C with nothing to
  # delete lands on the canvas delete verb — `readonly_block()` and a modal
  # dialog over a read-only viewer. The old arm forwarded when a marker was
  # selected ANYWHERE in the window and let C's own strip-scope test decide; a
  # marker selected on a DIFFERENT strip therefore fell straight through to that
  # modal. `delete_selection_at` reproduces the scope test in Tcl and the
  # fall-through is now unreachable.
  if {$N == 65535 && [wviewer::over_graph $W]} {
    if {$T == 2} {
      # an error must not escape a Tk binding (it pops bgerror over a read-only
      # viewer) — the delete_all_markers_at pattern
      if {[catch {wviewer::delete_selection_at $W $x $y} edel]} {
        if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
          catch {ciw_echo "wviewer: delete refused: $edel" error}
        }
      }
    }
    return
  }
  if {$fwd} {
    # m / d are the MUTATING graph keys that still reach C (waveform markers are
    # durable content, doc/claude/specs/graph_markers.md), and the C arms refuse
    # them in a read-only buffer — which this window is, for its whole life.
    # Forward them inside with_edit, the same bracket every other viewer
    # mutation uses: readonly 0, run, set_modify 0, readonly 1. Everything else
    # (a b s M t A B, cursors and the tooltip) writes only view state and is
    # forwarded raw, exactly as before. KeyPress only: KeyRelease is a no-op in
    # the C dispatcher, and a second with_edit cycle per keystroke is waste.
    # ⚠ Delete (65535) used to be the third member and is NOT one any more: it
    # never reaches C at all since issue 0176 (the block just above owns it).
    set tokm [wviewer::token_for_canvas $W]
    if {$T == 2 && $tokm ne {} && ($N == 109 || $N == 100)} {
      # with_edit ERRORS OUT loudly on a refused context switch; inside a Tk
      # binding that must not propagate, so it is caught and reported.
      if {[catch {wviewer::with_edit $tokm {xschem callback $W $T $x $y $N 0 0 $s}} emk]} {
        if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
          catch {ciw_echo "wviewer: marker key refused: $emk" error}
        }
      }
    } else {
      xschem callback $W $T $x $y $N 0 0 $s
    }
    # item 12 (D8): a/b/s reached the C waves_callback (they are forwarded
    # only over a graph) — flip the Tcl cursor mirror + refresh the readout
    if {$T == 2 && ($N == 97 || $N == 98 || $N == 115)} {
      wviewer::key_cursor_tail $W $N
    }
  }
}

# Button-3 filter (item 19, D2): forward Button-3 press+release EVERYWHERE in
# the viewer. Since item-18 tiling makes the graph FILL the window, the pointer
# is always inside a graph, so the C engine's over-graph path (GRAPHPAN start ->
# release zoom-x-to-box, callback.c:1000/:1454) always fires and view.zoom_rect
# (the canvas zoom box) is never reached — press-drag-release zooms the GRAPH
# x-range and leaves the canvas pinned. The old `over_graph` early-return is
# dropped: it would swallow RMB whenever the mouse-position mirror lagged the
# tiling, and there is no longer any off-graph region to protect (the schematic
# context menu is already killed by the sweep). Never swallow RMB here.
# --- RMB context menu on a trace (viewer plan item 7) -------------------------
# doc/claude/specs/waveform_viewer.md. A right-click that does NOT travel, on a
# trace inside the plot body, posts a small menu whose one entry gives that
# trace a strip of its own.
#
# WHY A CLICK AND NOT A HOLD (the recon of every Button-3 site in this window,
# plan_viewer_enhancements_2026-07.md item 7): a bare RMB click in the plot body
# is MEASURED to be a no-op today — with no motion `graph_rubber_active` stays 0
# and no zoom is committed — so a click-menu is a pure addition rather than a
# replacement. Posting it on the RELEASE, after btn3_filter has already handed
# that release to C, dissolves the three hazards the plan worried about instead
# of mitigating them: no grab exists during press->release so GRAPHPAN clears on
# its normal path; the box-zoom rubber rectangle is erased by the same release
# (callback.c ~1460) BEFORE the menu appears; and the modal numeric-cursor
# input_line is on the PRESS (callback.c ~1097), which this design never touches.
#
# Known boundary, recorded rather than desired: an RMB press within 10 px of a
# drawn cursor AND on a trace opens that modal first; the menu then posts when
# it is dismissed. Escape closes it. Closing this would need a C-side
# cursor-proximity query (the graph_near_wave precedent) and the press path is
# unchanged either way, so it is left out of this item.

# The Button-3 click travel tolerance, in CANVAS PIXELS: ZERO.
#
# ⚠ NOT GRAPH_CLICK_TOL, and the difference is load-bearing. That constant
# (callback.c:34, 3 px) gates the Button-1 wave-bold click, and Button1 has no
# box zoom to collide with. Button3 does, and the engine's gate on it is EXACT
# EQUALITY: `xmoved = (xctx->mx_double_save != xctx->mousex_snap)`
# (callback.c ~1871), where `mousex_snap` is the RAW pointer, because graph
# interaction deliberately disables the snap grid (callback.c ~810, issue
# 0143). So a release even ONE pixel from its press commits a box zoom — and a
# menu posted on a 1-3 px "click" would appear on top of one.
#
# Zero makes the two mutually exclusive by construction: the menu posts exactly
# when the release changed nothing, which is the case the item-7 recon
# measured. Probe-verified rather than reasoned: a 2-pixel wobble posted no
# menu because the engine had already zoomed the x range out from under the
# gate, and the trace was no longer where the pointer was.
proc wviewer::b3_click_tol {} { return 0 }

# 1 when the Button-3 press of the gesture in flight on canvas `W` landed while
# a MARKER drag was armed. Recorded on the press and read on the release,
# because the release's forward to C aborts that arm (callback.c ~866: a
# non-Button1 release calls graph_marker_drag_abort) and by gate time the
# engine would answer 0. Absent record -> 0, like every other predicate here.
proc wviewer::b3_marker_armed {W} {
  variable b3mk
  if {![info exists b3mk($W)]} { return 0 }
  return [expr {$b3mk($W) ? 1 : 0}]
}

# The GATE. Which trace, if any, an RMB click at canvas pixel (px,py) is
# offering a menu for: {gi ti} in MODEL index space, or {-1 -1} for "no menu
# here". Every predicate fails CLOSED, so a missing verb or a refused context
# switch degrades to the pre-item-7 behaviour (no menu) rather than to a menu
# aimed at the wrong trace.
#
# Three refusals, in cost order:
#   - not inside a strip at all (the bands tile the window, so this is rare,
#     but a click during a resize storm can land outside every band);
#   - the strip carries fewer than two DRAWN traces — mirrors
#     move_trace_to_new_strip's own refusal, because a menu that posts an entry
#     the command will refuse is worse than no menu;
#   - no trace within `graph_trace_at`'s tolerance of the pointer AND no LEGEND
#     entry there either. Between them these keep the menu off empty waveform
#     space, which item 8 will claim.
#
# ⚠ DIGITAL AND BUS STRIPS: NO MENU IN THE BODY, BUT ONE ON THE LEGEND (issue
# 0178 corrected this entry, which used to say they had no menu at all).
# `graph_wave_at` documents "digital strips and bus traces answer -1 (their
# rendering is a band/ribbon, not a polyline)" (draw.c), so `trace_at` misses
# across their whole body and the body half of this gate refuses — the same limit
# the LMB trace drag lives with, and the two must not diverge. (Landmine 33
# states the consequence for the OTHER gate: near-wave is 0 across such a body,
# so the whole body reads as empty waveform space, item 8's territory.)
# The LEGEND half is different by design: `graph_legend_at` deliberately does NOT
# refuse digital strips, and has its own digital layout, precisely because there
# the legend is the ONLY way to name a trace at all (the same reasoning that gave
# the legend its LMB select in 0175). So a digital or bus strip with >= 2 traces
# now DOES get "Move to Separate Strip" from its legend, and
# `move_trace_to_new_strip` has no digital refusal, so the entry works.
proc wviewer::trace_menu_pick {W px py} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {-1 -1} }
  # NOTE: the marker-drag refusal is NOT here. A marker gesture owns its whole
  # sequence (doc/claude/specs/graph_markers.md) and a non-Button1 release
  # ABORTS an armed marker drag, so a menu posted on that release would be a
  # side effect of cancelling something else — but that is a fact about the
  # PRESS, which only the gesture layer sees. btn3_filter records it and
  # refuses there; this gate stays a question about geometry alone, answerable
  # from a pixel with no gesture in flight.
  set gi [wviewer::strip_at_pixel $W $px $py]
  if {$gi < 0} { return {-1 -1} }
  set gs [dict get [wviewer::layout_for $token] graphs]
  if {$gi >= [llength $gs]} { return {-1 -1} }
  set G [lindex $gs $gi]
  if {[wviewer::node_count $G] < 2} { return {-1 -1} }
  set ni [wviewer::trace_at $W $gi $px $py]
  # THE LEGEND IS THE SECOND WAY IN (issue 0178). A trace has two picking
  # surfaces -- its stroke in the body and its name in the legend -- and every
  # other gesture already honours both (LMB click selects from either since
  # 0175). RMB did not: on the legend it fell through to the C engine, whose
  # Button3-outside-the-plot-box arm TOGGLES the trace's selection. That made the
  # legend the only place in the viewer where RMB was not a context menu, and it
  # is what the 0177 eyeball reported.
  #
  # Ordered stroke-first so a legend that ever overlapped a drawn trace would
  # resolve to the trace, matching the LMB arm in callback.c (which tests
  # `on_body` first for the same reason). They do not overlap today -- the legend
  # sits outside the plot box by construction -- so this is an ordering that
  # cannot currently be observed, kept because the alternative is a silent
  # ambiguity if the layout ever changes.
  if {$ni < 0} { set ni [wviewer::legend_at $W $gi $px $py] }
  if {$ni < 0} { return {-1 -1} }
  set ti [wviewer::trace_index_of_node $G $ni]
  if {$ti < 0} { return {-1 -1} }
  return [list $gi $ti]
}

# Which strip/NODE a canvas pixel's LEGEND ENTRY names, as {gi ni}, or {-1 -1}.
#
# The gate btn3_filter uses to decide that the VIEWER claims an RMB press rather
# than letting it reach the C engine (issue 0178). Deliberately NOT
# trace_menu_pick: this question is "is this pixel a legend entry at all", with
# no `node_count >= 2` rung. A single-trace strip has a legend the C engine would
# still toggle on, and the viewer has to claim that press too -- otherwise RMB on
# the legend would keep toggling on exactly the strips where no menu can post,
# which is the inconsistency being removed, just moved somewhere harder to see.
proc wviewer::legend_slot_at {W px py} {
  set gi [wviewer::strip_at_pixel $W $px $py]
  if {$gi < 0} { return {-1 -1} }
  set ni [wviewer::legend_at $W $gi $px $py]
  if {$ni < 0} { return {-1 -1} }
  return [list $gi $ni]
}

# A fresh, empty, ASE-themed context menu called `name` on the viewer TOPLEVEL
# of `token`, or {} when there is no window to hang it on. Shared by the trace
# menu (item 7) and the strip menu (item 8).
#
# It lives on the TOPLEVEL, not on the canvas: strip_bindings sweeps the
# canvas's bindings wholesale and a menu child there would be one more thing to
# reason about, while a toplevel child is torn down by Tk with the window.
proc wviewer::ctx_menu_widget {token name} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  set top [dict get $windows $token top]
  if {![winfo exists $top]} { return {} }
  set m $top.$name
  # `menu` ERRORS on an existing path, so the destroy is not tidiness: without
  # it the second post would fail and the caller would return {} for ever.
  catch {destroy $m}
  catch {ase::theme}                                  ;# ensure named fonts
  if {[catch {menu $m -tearoff 0 -takefocus 0}]} { return {} }
  # the ASE look is applied SEPARATELY and catch'd on its own: a menu with the
  # wrong palette is still a working menu, and configure keeps the theme values
  # out of an `eval` (a colour or font name with a space would re-parse).
  catch {
    $m configure -font AseLabelFont -background [ase::theme panel] \
                 -activebackground [ase::theme header]
  }
  return $m
}

# Take a context menu down and drop the grab tk_popup took. Idempotent, and safe
# when nothing was ever posted. Returns 1 when a widget was there to remove.
proc wviewer::ctx_menu_drop {token name} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set m [dict get $windows $token top].$name
  if {![winfo exists $m]} { return 0 }
  catch {$m unpost}
  catch {grab release $m}
  catch {destroy $m}
  return 1
}

# Post `m` for a click at canvas pixel (px,py) of `W`, at ROOT pixel (rx,ry) —
# the event's %X/%Y; when they are not supplied they are derived from the canvas
# origin. Returns 1 when Tk posted it.
proc wviewer::ctx_menu_popup {W m px py rx ry} {
  if {$m eq {} || ![winfo exists $m]} { return 0 }
  if {$rx < 0 || $ry < 0} {
    if {[catch {
      set rx [expr {[winfo rootx $W] + $px}]
      set ry [expr {[winfo rooty $W] + $py}]
    }]} { return 0 }
  }
  if {[catch {tk_popup $m $rx $ry}]} { return 0 }
  return 1
}

# Build (do not post) the context menu for trace `ti` of strip `gi`. Returns the
# menu widget path, or {} when there is no window to hang it on.
#
# REBUILT on every post. The entries carry THIS click's indices, and an entry
# left over from the previous click would move the wrong trace — the same
# argument that makes the drag feedback re-read the model on every motion.
# The first entry is a disabled header naming the trace the gate picked, using
# the legend's own naming rule: a click near two traces resolves to the nearest,
# and the user is entitled to see which one that was before invoking anything.
proc wviewer::trace_menu_build {token gi ti} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  set top [dict get $windows $token top]
  if {![winfo exists $top]} { return {} }
  set gs [dict get [wviewer::layout_for $token] graphs]
  if {$gi < 0 || $gi >= [llength $gs]} { return {} }
  set trs [wviewer::dget [lindex $gs $gi] traces {}]
  if {$ti < 0 || $ti >= [llength $trs]} { return {} }
  set lab [wviewer::trace_label [lindex $trs $ti]]
  set m [wviewer::ctx_menu_widget $token wvtracemenu]
  if {$m eq {}} { return {} }
  if {$lab ne {}} {
    $m add command -label $lab -state disabled
    $m add separator
  }
  $m add command -label {Move to Separate Strip} \
    -command [list wviewer::move_trace_to_new_strip $gi $ti $token]
  return $m
}

# Post the menu for an RMB click at canvas pixel (px,py), at ROOT pixel
# (rx,ry) — the event's %X/%Y; when they are not supplied they are derived from
# the canvas origin. Returns 1 when a menu was posted, 0 when the gate refused
# or Tk could not post: the seam a test drives instead of a real button.
proc wviewer::trace_menu_post {W px py {rx -1} {ry -1}} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return 0 }
  lassign [wviewer::trace_menu_pick $W $px $py] gi ti
  if {$gi < 0} { return 0 }
  return [wviewer::ctx_menu_popup $W \
            [wviewer::trace_menu_build $token $gi $ti] $px $py $rx $ry]
}

# Take the trace menu down. Idempotent, safe when nothing was ever posted.
proc wviewer::trace_menu_unpost {token} {
  return [wviewer::ctx_menu_drop $token wvtracemenu]
}

# --- RMB context menu on EMPTY strip space -> Split Strip (item 8) ------------
# The twin of the trace menu above, sharing 100 % of its gesture plumbing: the
# same no-travel ButtonRelease-3, the same modifier and marker-arm refusals, the
# same press record. Only the gate and the payload differ.
#
# The two menus PARTITION the strip body: the trace menu claims the fixed pixel
# band around every drawn trace, this one claims everything else — exactly the
# split the LMB gestures already make, where a press on a trace drags the trace
# and a press on empty waveform space reorders the strip.
#
# ⚠ ON A DIGITAL OR BUS STRIP THIS MENU OWNS THE WHOLE BODY, and that is
# landmine 33 working FOR us rather than against: the engine answers "no trace
# here" everywhere on such a strip (`graph_wave_at` returns -1 for a band/ribbon
# rendering, draw.c ~4711), so the trace menu never fires there and this one
# always does. Splitting is meaningful for a digital strip — one bus per strip
# is exactly what a user wants — so the pair still serves the whole strip
# between them. Stated in the spec, not silently inherited.

# The GATE: the strip an RMB click at canvas pixel (px,py) is offering to split,
# or -1. Fails closed at every rung, like trace_menu_pick.
#   - inside a strip;
#   - NO trace under the pointer (that is the trace menu's, and asking it first
#     is what keeps the two mutually exclusive);
#   - at least two drawn traces, mirroring split_strip's own refusal — a strip
#     with one trace is already split.
proc wviewer::strip_menu_pick {W px py} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return -1 }
  set gi [wviewer::strip_at_pixel $W $px $py]
  if {$gi < 0} { return -1 }
  if {![wviewer::plotbox_at $W $gi $px $py]} { return -1 }
  set gs [dict get [wviewer::layout_for $token] graphs]
  if {$gi >= [llength $gs]} { return -1 }
  if {[wviewer::node_count [lindex $gs $gi]] < 2} { return -1 }
  if {[wviewer::trace_at $W $gi $px $py] >= 0} { return -1 }
  return $gi
}

# Build (do not post) the context menu for strip `gi`. Same rebuild-per-post
# rule and same disabled-header convention as the trace menu; the header counts
# the traces, because "Split Strip" on a strip you cannot see the whole of
# should say how many strips you are about to get.
proc wviewer::strip_menu_build {token gi} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  set gs [dict get [wviewer::layout_for $token] graphs]
  if {$gi < 0 || $gi >= [llength $gs]} { return {} }
  set nc [wviewer::node_count [lindex $gs $gi]]
  set m [wviewer::ctx_menu_widget $token wvstripmenu]
  if {$m eq {}} { return {} }
  $m add command -label "Strip [expr {$gi + 1}] — $nc traces" -state disabled
  $m add separator
  $m add command -label {Split Strip} \
    -command [list wviewer::split_strip $gi $token]
  return $m
}

# Post the strip menu for an RMB click. Same contract and same test seam as
# trace_menu_post: 1 when posted, 0 when the gate refused.
proc wviewer::strip_menu_post {W px py {rx -1} {ry -1}} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return 0 }
  set gi [wviewer::strip_menu_pick $W $px $py]
  if {$gi < 0} { return 0 }
  return [wviewer::ctx_menu_popup $W \
            [wviewer::strip_menu_build $token $gi] $px $py $rx $ry]
}

proc wviewer::strip_menu_unpost {token} {
  return [wviewer::ctx_menu_drop $token wvstripmenu]
}

# The ONE context-menu entry point of the RMB click. Returns 1 when either menu
# posted.
#
# The two gates still PARTITION the pointer, now over TWO regions rather than
# one (issue 0178). Inside the PLOT BODY it is the original split: the strip gate
# refuses any pixel the trace gate accepts, by asking `trace_at` itself. Over the
# LEGEND BAND the trace gate accepts (via `legend_at`) and the strip gate cannot
# compete at all, because it requires `plotbox_at` and the legend is outside the
# plot box by construction. So the two are disjoint on both regions, by two
# different mechanisms — check BOTH when touching either gate.
#
# This ordering is therefore a second line of defence rather than the thing that
# separates them, and sabotaging it green-lights nothing (probe-verified:
# reversing the two lines leaves the suite green). The partition itself is what
# SG8 pins. Asking the more specific menu first is kept anyway, because a future
# rung that widened the strip gate would otherwise silently start swallowing
# trace clicks.
proc wviewer::ctx_menu_post {W px py {rx -1} {ry -1}} {
  if {[wviewer::trace_menu_post $W $px $py $rx $ry]} { return 1 }
  return [wviewer::strip_menu_post $W $px $py $rx $ry]
}

proc wviewer::btn3_filter {W T x y b s {rx -1} {ry -1}} {
  variable b3x0; variable b3y0; variable b3mk
  if {$T == 4} {                                      ;# ButtonPress focuses
    catch {focus $W}
    set b3x0($W) $x
    set b3y0($W) $y
    # BEFORE the forward below, which aborts an armed marker drag
    set b3mk($W) [wviewer::marker_grabbed $W]
  }
  # C FIRST — this is what makes the menu safe (see the block comment above): by
  # the time the gate below runs, the engine has already erased any rubber
  # rectangle and cleared GRAPHPAN on its normal release path.
  #
  # ⚠ ONE EXCEPTION, AND ONLY ON THE PRESS (issue 0178): a press on a LEGEND
  # ENTRY is the viewer's, not the engine's. C's Button3 arm for a press outside
  # the plot box TOGGLES that trace's selection membership
  # (`edit_wave_attributes(2, ...)`, callback.c), which is a second button for
  # Ctrl+LMB and made the legend the only region of the viewer where RMB was not
  # a context menu. Swallowing the press here is how the viewer claims it —
  # exactly what strip_drag_press already does for LMB — and it leaves the C
  # engine untouched, so on-canvas SCHEMATIC graphs (which have no context menus
  # of their own) keep the toggle they have always had.
  #
  # ⚠ EVERY MODIFIER STATE, NOT JUST THE UNMODIFIED PRESS. The first cut copied
  # the `$s & 13` refusal from the menu gate below, and that left the whole
  # reported defect alive under a modifier: neither C's Button3 routing
  # (`waves_selected`, which ignores modifiers for Button3) nor the toggle arm
  # itself tests `state`, so Ctrl+RMB and Shift+RMB on a legend name went on
  # selecting and deselecting it — silently, because the release gate then
  # refuses to post a menu for exactly those modifiers. A modified RMB on the
  # legend is now simply INERT, which is what "a modified RMB belongs to whatever
  # else claims it" means when nothing claims it.
  #
  # WHY SKIPPING THE PRESS IS SAFE — and NOT for the reason first written here.
  # It is NOT "the press is outside the plot box so it arms no GRAPHPAN": the
  # GRAPHPAN latch (callback.c) has no plot-box test at all, and `graph_top`
  # suppresses it only for the band ABOVE the plot box — the `vlegend` and
  # `digital` legend layouts sit to the LEFT of it, where `graph_top` is 0 and a
  # Button3 press WOULD latch. What actually kept the old press inert on a legend
  # HIT is the `return 0` C takes as soon as `edit_wave_attributes` succeeds,
  # before the latch. So on a legend hit the engine only ever did the toggle, and
  # not forwarding is equivalent to it having done nothing. ⚠ THE COROLLARY:
  # do NOT widen this swallow to the axis margins on the same argument — there
  # `edit_wave_attributes` misses, the latch DOES fire, mx/my_double_save is
  # written, and the still-forwarded release would commit a box zoom.
  #
  # The release is always forwarded, and the press record above is written either
  # way, so the no-travel click test is unaffected.
  #
  # FAIL-OPEN, deliberately: `legend_slot_at` answers -1 when the band registry
  # is empty or the context switch is refused, and the press is then forwarded —
  # i.e. it degrades to the old toggle rather than swallowing a press that might
  # have been a box zoom. Failing closed would break RMB box-zoom on the body,
  # which is the more costly mistake.
  set b3own 0
  if {$T == 4 && [lindex [wviewer::legend_slot_at $W $x $y] 0] >= 0} { set b3own 1 }
  if {!$b3own} { xschem callback $W $T $x $y 0 $b 0 $s }
  if {$T != 5} { return }
  set had [info exists b3x0($W)]
  set x0 0; set y0 0
  if {$had} { set x0 $b3x0($W); set y0 $b3y0($W) }
  set armed [wviewer::b3_marker_armed $W]
  # the record is dropped HERE, on the release, whatever happens next: a second
  # release with no press of its own (the <Double-Button-3> `{break}` swallows
  # the second PRESS but not the second release) must not read as a click
  unset -nocomplain b3x0($W) b3y0($W) b3mk($W)
  if {!$had || $armed} { return }
  # `s` on a ButtonRelease reports the state BEFORE the release, so Button3Mask
  # is set here; 13 = Shift|Control|Mod1 only, the same modifier refusal the
  # strip drag-reorder press applies. A modified RMB belongs to whatever else
  # claims it, never to this menu.
  if {$s & 13} { return }
  set tol [wviewer::b3_click_tol]
  if {abs($x - $x0) > $tol || abs($y - $y0) > $tol} { return }
  # a menu is a mutation surface, and this runs inside a Tk binding: an error
  # here would pop bgerror's stack trace over the viewer
  catch {wviewer::ctx_menu_post $W $x $y $rx $ry}
}

# Replace/override the editor bindings on the viewer canvas `wp` (per-widget:
# other windows keep their full binding set by construction). Two steps:
#   1. SWEEP: clear every sequence bound on the canvas except the keepseqs
#      infrastructure. The generic <Key>/<KeyRelease>/Button-3/double binds
#      are re-installed as filters below, but the canvas also carries MORE
#      SPECIFIC binds that Tk fires INSTEAD of the generic filter (most
#      specific match wins): user-rc binds cloned by clone_canvas_bindings
#      (xinit.c create_new_window — e.g. cadence_style_rc `bind .drw <Key-i>
#      {xschem create_instance; break}` reached create_instance and its
#      readonly modal in the viewer), replace_key remaps
#      (set_replace_key_binding), set_bindings' own <Control-Shift-Key-P>/
#      hi_descend binds, and set_bindings' Windows-only per-widget Alt/Mod4
#      key/button arms. The sweep clears them ALL whatever their spelling —
#      no enumerated blocklist to fall out of date. (The former explicit
#      palette/hi_descend `{break}` binds are subsumed: those keysyms now
#      reach key_filter, which swallows them.)
#   2. install the filters — afterwards they are the ONLY key/button
#      handlers on the canvas.
proc wviewer::strip_bindings {wp} {
  variable keepseqs
  foreach seq [bind $wp] {
    if {[lsearch -exact $keepseqs $seq] < 0} { bind $wp $seq {} }
  }
  # issue 0171: the viewer's OWN key defaults (Ctrl-D = Clear All) live on the
  # shared `WaveViewer` bindtag, which the sweep above cannot reach and an rc
  # file can bind before any viewer exists. Inserted at index 1 — right after
  # the widget itself — so the widget-level filters below keep first refusal
  # and the Canvas class bindings still come last.
  wviewer::install_default_binds
  if {[lsearch -exact [bindtags $wp] WaveViewer] < 0} {
    bindtags $wp [linsert [bindtags $wp] 1 WaveViewer]
  }
  bind $wp <KeyPress>   {wviewer::key_filter %W %T %x %y %N %K %s}
  bind $wp <KeyRelease> {wviewer::key_filter %W %T %x %y %N %K %s}
  # %X/%Y (ROOT pixels) are passed for the item-7 context menu, which tk_popup
  # places in root coordinates. They are trailing OPTIONAL arguments so the
  # six-argument call shape stays valid — test_wave_viewer drives btn3_filter
  # directly with it.
  bind $wp <ButtonPress-3>   {wviewer::btn3_filter %W %T %x %y 3 %s %X %Y}
  bind $wp <ButtonRelease-3> {wviewer::btn3_filter %W %T %x %y 3 %s %X %Y}
  # issue 0151: clicking a strip makes it the TARGET (where signals sent from
  # the schematic land in single-plot mode). <ButtonPress-1> is MORE SPECIFIC
  # than the kept generic <Button>, so binding it would otherwise swallow the
  # C engine's press (cursor grab / graph pan) — hence the manual forward,
  # byte-for-byte the generic body from set_bindings (xschem.tcl), and the
  # trailing `break`: exactly one forward whether the generic binding lives on
  # this widget's tag or the toplevel's. The re-target runs FIRST so a press
  # that starts a cursor drag still lands on the strip it was aimed at.
  # strip drag-reorder: the press seam runs FIRST and reports whether it took
  # the event. When it did it has already done the re-target, the focus and the
  # C forward itself; when it did not (no strip under the pointer, a modified
  # press, a foreign canvas) the pre-existing issue-0151 body runs verbatim.
  bind $wp <ButtonPress-1> {
    if {![wviewer::strip_drag_press %W %x %y %s]} {
      wviewer::click_target %W %x %y
      focus %W
      xschem callback %W %T %x %y 0 %b 0 %s
    }
    break
  }
  # <B1-Motion> and <ButtonRelease-1> are MORE SPECIFIC than the kept generic
  # <Motion>/<ButtonRelease>, so binding them pre-empts those — every non-drag
  # path here must forward the original event to C exactly once (and the release
  # must also do the readout refresh that was appended to the generic bind).
  # The re-assert is UNCONDITIONAL, outside the seam test, because both known
  # clobbers live on different sides of it: the declined sub-threshold motion
  # forwards to C (waves_selected -> tcross), and a `<Leave>`/`<Enter>` pair
  # mid-drag writes `{}` from C while the seam is happily CONSUMING every motion.
  # One `cget` per motion buys a maintained invariant instead of a one-shot.
  bind $wp <B1-Motion> {
    if {![wviewer::strip_drag_motion %W %x %y %s]} {
      xschem callback %W %T %x %y 0 0 0 %s
    }
    wviewer::drag_cursor_reassert %W
    break
  }
  bind $wp <ButtonRelease-1> {
    if {![wviewer::strip_drag_release %W %x %y %s]} {
      xschem callback %W %T %x %y 0 %b 0 %s
      wviewer::readout_refresh [wviewer::token_for_canvas %W]
    }
    break
  }
  # D9: no graph props dlg. Since issue 0189 a double-click ON A MARKER also
  # pair-selects it; everything else is still swallowed. The `break` is
  # UNCONDITIONAL — D9 must hold for every non-marker double-click, and
  # forwarding -3 to C from here would let a Tcl/C hit-test disagreement open
  # .graphdialog over a read-only viewer.
  bind $wp <Double-Button-1> {wviewer::marker_dblclick_at %W %x %y; break}
  bind $wp <Double-Button-2> {break}
  bind $wp <Double-Button-3> {break}
  # issue 0149: kill the canvas-only mouse gestures. Shift+B1 and Alt+B1 are
  # canvas-only (waves_selected skips Shift+B1; Alt sets SET_MODMASK) and mean
  # rubber-band/copy-drag and unselect-at-pointer — pure schematic-object
  # gestures with no graph counterpart, so they stay swallowed. The bands tile
  # the whole viewport (band_geometry), so a plain click always lands on a graph.
  foreach seq {<Shift-ButtonPress-1> <Shift-ButtonRelease-1> <Shift-B1-Motion>
               <Alt-ButtonPress-1> <Alt-ButtonRelease-1> <Alt-B1-Motion>} {
    bind $wp $seq {break}
  }
  # Button-2 (MMB) is no longer swallowed: it IS the graph pan now (the C pan
  # moved off LMB, which the strip drag-reorder seam needs). btn2_filter accepts
  # the press only well inside a strip, so it can still never reach
  # start_pan_logged and slide the canvas. Ctrl/Alt+MMB remain inert (the
  # pin-type edit chord is a mutating action, i.e. a readonly modal).
  bind $wp <ButtonPress-2>   {wviewer::btn2_filter %W %T %x %y %s; break}
  bind $wp <B2-Motion>       {wviewer::btn2_filter %W %T %x %y %s; break}
  bind $wp <ButtonRelease-2> {wviewer::btn2_filter %W %T %x %y %s; break}
  # item 19 (D-B): wheel = GRAPH pan/zoom, mirroring cadence_style_rc on graph
  # content. On Tcl 8.6 / X11 the wheel arrives as Button-4 (up) / Button-5
  # (down); these more-specific binds PRE-EMPT the kept generic <Button> (which
  # forwarded X11 wheel to the C waveform-wheel = horizontal pan, wrong per D1).
  # plain = vertical pan, Shift = horizontal pan, Ctrl = X zoom. Each `break`s so
  # the kept generic wheel binds never also fire. `wheel_bind` resolves the token
  # from %W at event time (no stale capture).
  bind $wp <Button-4>          {wviewer::wheel_bind %W up 0 %x %y;      break}
  bind $wp <Button-5>          {wviewer::wheel_bind %W down 0 %x %y;    break}
  bind $wp <Shift-Button-4>    {wviewer::wheel_bind %W up shift %x %y;  break}
  bind $wp <Shift-Button-5>    {wviewer::wheel_bind %W down shift %x %y; break}
  bind $wp <Control-Button-4>  {wviewer::wheel_bind %W up ctrl %x %y;   break}
  bind $wp <Control-Button-5>  {wviewer::wheel_bind %W down ctrl %x %y; break}
  # portability (Tcl > 8.7 / non-X11): <MouseWheel> carries a signed %D. Tests
  # run on 8.6/X11 where this never fires, but keep the viewer wheel correct
  # everywhere. Overwrites the kept generic <MouseWheel> on THIS canvas only.
  bind $wp <MouseWheel>         {wviewer::wheel_bind %W [expr {%D > 0 ? "up" : "down"}] 0 %x %y;     break}
  bind $wp <Shift-MouseWheel>   {wviewer::wheel_bind %W [expr {%D > 0 ? "up" : "down"}] shift %x %y; break}
  bind $wp <Control-MouseWheel> {wviewer::wheel_bind %W [expr {%D > 0 ? "up" : "down"}] ctrl %x %y;  break}
}

# --- menubar (D7) ------------------------------------------------------------

# Build the viewer menubar $top.wvmenubar and attach it (replacing the editor
# menubar on THIS toplevel only; the detached $top.menubar widget stays alive
# so set_modify's catch-guarded entryconfigure calls keep resolving). ASE
# theme applied (locked palette + named fonts, ase::theme).
proc wviewer::build_menubar {token top} {
  ase::theme                                          ;# ensure named fonts
  set panel  [ase::theme panel]
  set header [ase::theme header]
  set mb $top.wvmenubar
  catch {destroy $mb}
  menu $mb -tearoff 0 -borderwidth 0 -takefocus 0 \
    -font AseLabelFont -background $panel -activebackground $header
  foreach {label sub} {File file View view Graph graph Cursors cursors
                       Options options} {
    $mb add cascade -label $label -menu $mb.$sub
    menu $mb.$sub -tearoff 0 -takefocus 0 \
      -font AseLabelFont -background $panel -activebackground $header
  }
  $mb.file add command -label Close -accelerator Ctrl+W \
    -command [list wviewer::close $token]
  # View menu (item 19, D6): Fit / Zoom In / Zoom Out all act on the GRAPH data
  # range, never the canvas viewport (item-18 pins the canvas, so canvas zoom
  # would SHRINK the graph). Fit = fullx/fullyzoom + model read-back (de-canvased
  # in wviewer::fit, D5); Zoom In/Out = graph X zoom about center on every graph
  # (wviewer::graph_zoom, D6). Redraw stays a plain canvas redraw (canvas-safe:
  # never touches zoom/origin).
  $mb.view add command -label Fit \
    -command [list wviewer::fit $token]
  $mb.view add command -label {Zoom In} \
    -command [list wviewer::graph_zoom $token in]
  $mb.view add command -label {Zoom Out} \
    -command [list wviewer::graph_zoom $token out]
  $mb.view add command -label Redraw \
    -command [list wviewer::in_ctx $token {xschem redraw}]
  # Graph menu (item 12, live): model editing, always through regenerate
  $mb.graph add command -label {Add Graph} \
    -command [list wviewer::add_graph $token]
  $mb.graph add command -label {Add Trace...} \
    -command [list wviewer::add_trace_dialog $token]
  $mb.graph add command -label {Delete...} \
    -command [list wviewer::delete_dialog $token]
  $mb.graph add command -label {Axes...} \
    -command [list wviewer::axes_dialog $token]
  # issue 0171: the menu twin of the Ctrl-D bindtag default. The accelerator
  # LABEL is static text (Tk does not dispatch it) — an rc that remaps the tag
  # binding changes the key, not this label.
  $mb.graph add command -label {Clear All} -accelerator Ctrl+D \
    -command [list wviewer::clear_all $token]
  # viewer plan item 4: the menu twin of the Ctrl-E bindtag default. Deletes
  # the ANNOTATION only — every graph, trace and range survives, which is what
  # separates it from Clear All right above.
  $mb.graph add command -label {Delete All Markers} -accelerator Ctrl+E \
    -command [list wviewer::delete_all_markers $token]
  # viewer plan item 5: the menu twin of the bare-`e` bindtag default. Removes
  # empty STRIPS only — every trace survives by definition, and neither the
  # auto-plot strip (D-D) nor the last strip standing (D-C) is a candidate.
  $mb.graph add command -label {Delete Empty Strips} -accelerator e \
    -command [list wviewer::delete_empty_strips $token]
  # viewer plan item 8: the menubar twin of the RMB-on-empty-space entry. It
  # acts on the TARGET strip — the one carrying the active bar — because a
  # menubar entry has no pointer position to resolve. No accelerator: the
  # gesture is a right-click, not a key.
  $mb.graph add command -label {Split Strip} \
    -command [list wviewer::split_target_strip $token]
  $mb.graph add checkbutton -label {Shared X Axis} \
    -variable ::wviewer::sharedx($token) \
    -command [list wviewer::sharedx_toggle $token]
  # viewer plan item 3: the menu twin of the Ctrl-G bindtag default. A
  # checkbutton, not a command, because unlike Clear All this is a STATE --
  # and its variable is PUSHED by sync_grid_mirror on every change rather than
  # polled by a -postcommand, so it cannot go stale when the key is used.
  $mb.graph add checkbutton -label {Grid} -accelerator Ctrl+G \
    -variable ::wviewer::gridshow($token) \
    -command [list wviewer::grid_toggle_from_menu $token]
  # Cursors menu (item 12, live): engine x-cursors driven absolutely from
  # the Tcl mirrors (D1/D8)
  $mb.cursors add checkbutton -label {Cursor A} \
    -variable ::wviewer::cva($token) \
    -command [list wviewer::cursor_toggle $token 1]
  $mb.cursors add checkbutton -label {Cursor B} \
    -variable ::wviewer::cvb($token) \
    -command [list wviewer::cursor_toggle $token 2]
  $mb.cursors add checkbutton -label Readout \
    -variable ::wviewer::cvr($token) \
    -command [list wviewer::readout_show $token]
  # Options > Plot Mode (issue 0151): ONE dynamic entry offering the OTHER
  # mode. The label is rebuilt by the submenu's -postcommand, so it stays
  # correct however the mode last changed (this menu, the Tcl commands, the
  # Ctrl-Shift-4 chord on the design window, or a state restore). Invoking it
  # goes through set_plot_mode, which writes the replayable log line.
  menu $mb.options.plotmode -tearoff 0 -takefocus 0 \
    -font AseLabelFont -background $panel -activebackground $header \
    -postcommand [list wviewer::plot_mode_menu_post $token $mb.options.plotmode]
  $mb.options.plotmode add command -label {Set Multi-plot Mode} \
    -command [list wviewer::set_plot_mode invert $token]
  $mb.options add cascade -label {Plot Mode} -menu $mb.options.plotmode
  $top configure -menu $mb
}
